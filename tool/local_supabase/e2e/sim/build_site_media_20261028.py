#!/usr/bin/env python3
"""Package a completed bilingual native site capture; never capture or deploy.

Default `plan` writes nothing. `build --apply --status-bar-confirmed` requires a
fully completed capture and recorder, creates reviewable staging files, then
publishes only the exact30 PNG/4 MP4/4 WebP outputs and their native evidence.
No screenshot UI is generated; resizing is aspect-preserving with minimal pad.
The original MOV remains ignored under build/. Source clips use stream copy and
are matched to the original packet hashes and relative PTS (no speed change).
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import math
from pathlib import Path
import re
import shutil
import struct
import subprocess
import sys
import zlib

import encode_site_video as encoder
from record_site_video import MEDIA_ROOT, MediaError, ROOT, sha256

DATE = '20261028'
DEVICE_ID = '8D0EFF44-5AF3-42E6-9F59-92CDFF8C9E5C'
DEVICE_NAME = 'PomoSprint QA iPhone 16 (18.6)'
DATABASE = 'pomosprint_site32_dus'
LOCALES = ('tr', 'en')
SCENES = ('timer', 'marathon-plan', 'exam-catalog', 'exam-running',
          'exam-history', 'exam-results', 'exam-insights', 'reports-daily',
          'reports-weekly', 'reports-monthly', 'league-category', 'league-global',
          'league-exam', 'social', 'avatar-collection')
MAX_BLOB = 50_000_000
WIDTH, HEIGHT = 540, 1170


def checked_path(path, base, *, exists=True):
    path, base = Path(path).absolute(), Path(base).resolve()
    if '..' in path.parts or not path.is_relative_to(base):
        raise MediaError('Path is outside its fixed task root')
    cursor = path
    while cursor != base:
        if cursor.is_symlink():
            raise MediaError('Symlink input/output is not permitted')
        cursor = cursor.parent
    if exists and not path.is_file():
        raise MediaError('Required completed input file is missing')
    return path


def read_json(path, limit=2 * 1024 * 1024):
    if path.stat().st_size > limit:
        raise MediaError('JSON input exceeds its bound')
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise MediaError('JSON input must be an object')
    return value


def png_dimensions(path):
    if path.stat().st_size >= MAX_BLOB:
        raise MediaError('Native PNG exceeds the per-file archive bound')
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        raise MediaError('Invalid PNG signature')
    offset, dimensions, has_data = 8, None, False
    while offset + 12 <= len(data):
        size = struct.unpack_from('>I', data, offset)[0]
        kind = data[offset + 4:offset + 8]
        end = offset + 12 + size
        if end > len(data):
            break
        content = data[offset + 8:offset + 8 + size]
        crc = struct.unpack_from('>I', data, offset + 8 + size)[0]
        if zlib.crc32(kind + content) & 0xffffffff != crc:
            raise MediaError('PNG checksum mismatch')
        if dimensions is None:
            if kind != b'IHDR' or size != 13:
                raise MediaError('PNG IHDR is missing')
            dimensions = struct.unpack_from('>II', content)
        if kind == b'IDAT':
            has_data = has_data or bool(content)
        if kind == b'IEND' and size == 0 and end == len(data) and has_data:
            return dimensions
        offset = end
    raise MediaError('PNG is truncated or malformed')


def parse_capture(text):
    screenshots, locale_events, active = {}, {lang: [] for lang in LOCALES}, None
    begun = set()
    completed = 0
    for raw in text.splitlines():
        line = re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', raw)
        if '[SITE_CAPTURE_COMPLETE]' in line:
            completed += 1
        if '[SITE_CAPTURE_LOCALE]' in line:
            item = json.loads(line.split('[SITE_CAPTURE_LOCALE]', 1)[1].strip())
            lang, kind = item.get('language'), item.get('kind')
            if lang not in LOCALES or kind not in {'begin', 'end'}:
                raise MediaError('Unknown locale capture marker')
            if kind == 'begin':
                if active is not None or lang in begun:
                    raise MediaError('Overlapping/repeated locale recordings')
                begun.add(lang)
                active = lang
            elif active == lang:
                active = None
            else:
                raise MediaError('Locale recording closed out of order')
        if '[MEDIA_EVENT]' in line:
            if active not in LOCALES:
                raise MediaError('Video event outside its locale section')
            item = json.loads(line.split('[MEDIA_EVENT]', 1)[1].strip())
            locale_events[active].append('[MEDIA_EVENT] ' + json.dumps(item, ensure_ascii=False))
        if '[SITE_CAPTURE]' in line:
            item = json.loads(line.split('[SITE_CAPTURE]', 1)[1].strip())
            key = (item.get('language'), item.get('name'))
            if key[0] not in LOCALES or key[1] not in SCENES or key in screenshots:
                raise MediaError('Unknown or repeated native screenshot marker')
            if not item.get('visible_label'):
                raise MediaError('Screenshot has no verified visible locale anchor')
            encoder.utc(item.get('at'))
            screenshots[key] = item
    if active is not None or begun != set(LOCALES) or completed != 1 or 'All tests passed!' not in text:
        raise MediaError('Native capture is not fully completed and passing')
    if set(screenshots) != {(lang, scene) for lang in LOCALES for scene in SCENES}:
        raise MediaError('Exactly30 verified screenshot markers are required')
    for lang in LOCALES:
        encoder.parse_events('\n'.join(locale_events[lang]))
    return screenshots, locale_events


def packets(path):
    data = json.loads(encoder.run([
        'ffprobe', '-v', 'error', '-select_streams', 'v:0', '-show_packets',
        '-show_data_hash', 'sha256', '-show_entries', 'packet=pts_time,duration_time,data_hash',
        '-of', 'json', str(path)], timeout=90, stage='packet provenance probe'))
    rows = data.get('packets')
    if not isinstance(rows, list) or not rows:
        raise MediaError('Video has no packet provenance')
    for row in rows:
        if not isinstance(row.get('data_hash'), str) or not row['data_hash'].startswith('SHA256:'):
            raise MediaError('Packet hash is missing')
        row['pts_time'] = float(row['pts_time'])
        if not math.isfinite(row['pts_time']):
            raise MediaError('Packet PTS is not finite')
    return rows


def match_packet_copy(original, clipped):
    candidates = [i for i, row in enumerate(original) if row['data_hash'] == clipped[0]['data_hash']]
    for offset in candidates:
        source = original[offset:offset + len(clipped)]
        if len(source) != len(clipped):
            continue
        if [r['data_hash'] for r in source] != [r['data_hash'] for r in clipped]:
            continue
        shift = clipped[0]['pts_time'] - source[0]['pts_time']
        if all(abs((c['pts_time'] - s['pts_time']) - shift) <= 0.0002 for s, c in zip(source, clipped)):
            return {'verified': True, 'packet_count': len(clipped),
                    'source_first_packet_index': offset,
                    'source_first_pts': source[0]['pts_time'],
                    'clip_first_pts': clipped[0]['pts_time'],
                    'constant_pts_shift': shift,
                    'packet_hash_algorithm': 'sha256', 'relative_pts_unchanged': True}
    raise MediaError('Native source clip differs from original packet content/timing')


def verify_device():
    data = json.loads(encoder.run(['xcrun', 'simctl', 'list', 'devices', '--json'],
                                 timeout=15, stage='fixed simulator inventory'))
    matches = [(runtime, row) for runtime, rows in data.get('devices', {}).items()
               for row in rows if row.get('udid') == DEVICE_ID]
    if len(matches) != 1 or matches[0][0] != 'com.apple.CoreSimulator.SimRuntime.iOS-18-6' or matches[0][1].get('name') != DEVICE_NAME:
        raise MediaError('The exact native capture device/runtime is required')
    return {'name': DEVICE_NAME, 'ios': '18.6', 'udid': DEVICE_ID}


def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def publish_file(source, destination, replace):
    checked_path(destination, ROOT, exists=False)
    if source.stat().st_size >= MAX_BLOB:
        raise MediaError('Archived/published file exceeds50MB')
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() and not replace:
        raise MediaError('Existing outputs are preserved; explicit replacement required')
    temporary = destination.with_name('.' + destination.name + '.site-new')
    if temporary.exists() or temporary.is_symlink():
        raise MediaError('Unexpected existing publication tempfile')
    try:
        shutil.copyfile(source, temporary)
        if sha256(temporary) != sha256(source):
            raise MediaError('Publication copy hash differs')
        temporary.replace(destination)
    finally:
        temporary.unlink(missing_ok=True)


def build(args):
    if not args.apply or not args.status_bar_confirmed:
        raise MediaError('Build requires --apply and explicit --status-bar-confirmed after visual review')
    run = checked_path(ROOT / args.capture_run, MEDIA_ROOT, exists=False)
    if not run.is_dir():
        raise MediaError('Completed capture run directory is required')
    native_log = checked_path(run / 'native.log', MEDIA_ROOT)
    if native_log.stat().st_size > 32 * 1024 * 1024:
        raise MediaError('Native log exceeds32MiB')
    shots, events = parse_capture(native_log.read_text())
    fixture_path = checked_path(ROOT / 'build/verification_20261028/site_demo_site-oct28-ui.json', ROOT / 'build')
    fixture = read_json(fixture_path)
    if fixture.get('ready') is not True or fixture.get('database') != DATABASE or fixture.get('api_url') != 'http://127.0.0.1:54361':
        raise MediaError('The completed isolated site fixture is required')
    if fixture.get('expected', {}).get('exam_sand') != 260:
        raise MediaError('The current reward-policy fixture must contain260 exam sand')
    accounts = fixture.get('accounts', [])
    if [a.get('label') for a in accounts] != ['Deniz', 'Ece', 'Mert', 'Ada', 'Arda', 'Duru', 'Can']:
        raise MediaError('Exact fictional seven-owner capture fixture is required')
    owner = {'id': accounts[0]['id'], 'display_name': 'Deniz'}
    if not re.fullmatch(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}', owner['id']):
        raise MediaError('Noncanonical demo owner')
    device = verify_device()
    raw = checked_path(run / 'recording/raw.mov', MEDIA_ROOT)
    meta_path = checked_path(run / 'recording/recording.json', MEDIA_ROOT)
    meta = read_json(meta_path)
    if meta.get('status') != 'complete' or meta.get('raw_file') != raw.name or meta.get('bytes') != raw.stat().st_size or meta.get('raw_sha256') != sha256(raw):
        raise MediaError('Recorder is incomplete or raw provenance changed')
    record_start = encoder.utc(meta.get('started_at'))
    encoder.utc(meta.get('stopped_at'))
    raw_info = encoder.probe(raw)
    if raw_info['codec'] != 'h264' or raw_info['has_audio']:
        raise MediaError('Expected silent native H264 capture')
    screenshot_dir = checked_path(ROOT / args.screenshot_dir, MEDIA_ROOT, exists=False)
    expected_names = {f'e2e-site-{DATE}-{lang}-{scene}.png' for lang in LOCALES for scene in SCENES}
    if {p.name for p in screenshot_dir.glob(f'e2e-site-{DATE}-*.png')} != expected_names:
        raise MediaError('Screenshot directory is not the exact30-source batch')
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    stage = MEDIA_ROOT / ('site-package-' + stamp)
    checked_path(stage, MEDIA_ROOT, exists=False)
    stage.mkdir()
    publications, screen_rows = [], []
    common_size = None
    proof_base = Path('analiz/ekran_site_2026-10-28')
    status_bar = {'time': '09:41', 'battery_level': 100, 'wifi_bars': 3,
                  'cellular_bars': 4, 'verified_by': 'root visual review and native override'}
    for lang in LOCALES:
        for scene in SCENES:
            source = checked_path(screenshot_dir / f'e2e-site-{DATE}-{lang}-{scene}.png', MEDIA_ROOT)
            size = png_dimensions(source)
            if common_size is None:
                common_size = size
            if size != common_size or size[0] < WIDTH or size[1] < HEIGHT:
                raise MediaError('Source PNG dimensions differ or are too small')
            raw_rel = proof_base / 'native' / f'{scene}-{lang}.png'
            raw_stage = stage / f'raw-{scene}-{lang}.png'
            shutil.copyfile(source, raw_stage)
            output = stage / f'{scene}-{lang}.png'
            encoder.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-n', '-threads', '2',
                         '-i', str(source), '-vf',
                         'scale=540:1170:force_original_aspect_ratio=decrease:flags=lanczos,pad=540:1170:(ow-iw)/2:(oh-ih)/2:color=0xF8F9FA,setsar=1',
                         '-filter_threads', '2', '-frames:v', '1', '-threads', '2', str(output)],
                        timeout=60, stage='native PNG resize/pad')
            if png_dimensions(output) != (WIDTH, HEIGHT):
                raise MediaError('Web PNG dimensions differ')
            row = {'scene': scene, 'locale': lang, 'file': f'{DATE}/{scene}-{lang}.png',
                   'width': WIDTH, 'height': HEIGHT, 'sha256': sha256(output),
                   'owner_id': owner['id'], 'status_bar_time': '09:41',
                   'captured_at': shots[(lang, scene)]['at'],
                   'visible_locale_anchor': shots[(lang, scene)]['visible_label'],
                   'source': {'path': raw_rel.as_posix(), 'width': size[0], 'height': size[1],
                              'sha256': sha256(source), 'locale': lang},
                   'transform': 'Aspect-preserving Lanczos resize with minimal centered padding; no crop or UI editing'}
            screen_rows.append(row)
            publications += [(raw_stage, ROOT / raw_rel), (output, ROOT / 'landing/screenshots' / row['file'])]
    original_packets = packets(raw)
    video_rows = []
    for lang in LOCALES:
        out = stage / lang
        out.mkdir()
        event_path = out / f'events-{lang}.log'
        event_path.write_text('\n'.join(events[lang]) + '\n')
        event_rel = proof_base / 'video' / event_path.name
        publications.append((event_path, ROOT / event_rel))
        for scene in encoder.parse_events(event_path.read_text()):
            duration = (scene['end'] - scene['start']).total_seconds()
            if not 1 < duration <= 60:
                raise MediaError('Published scene must be1–60 real-time seconds')
            info = encoder.encode_scene(raw, raw_info, scene, record_start, args.sync_offset, out, False)
            start = info['trim_start_seconds']
            source_clip = out / f'native-{scene["scene"]}-{lang}.mp4'
            encoder.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-n',
                         '-ss', f'{max(0, start - 2):.6f}', '-i', str(raw),
                         '-t', f'{duration + min(2, start) + 2:.6f}', '-map', '0:v:0',
                         '-an', '-sn', '-c:v', 'copy', '-movflags', '+faststart', str(source_clip)],
                        timeout=90, stage='native packet-copy source clip')
            if source_clip.stat().st_size >= MAX_BLOB:
                raise MediaError('Packet-copy native source clip exceeds50MB; do not archive full MOV')
            copy_proof = match_packet_copy(original_packets, packets(source_clip))
            source_info = encoder.probe(source_clip)
            source_rel = proof_base / 'video' / source_clip.name
            video_name, poster_name = f'{scene["scene"]}-{lang}.mp4', f'{scene["scene"]}-{lang}.webp'
            info.update({'locale': lang, 'video': f'{DATE}/{video_name}', 'poster': f'{DATE}/{poster_name}',
                         'owner_id': owner['id'], 'status_bar_time': '09:41', 'speed_changed': False,
                         'source': {'path': source_rel.as_posix(), 'width': source_info['width'],
                                    'height': source_info['height'], 'sha256': sha256(source_clip),
                                    'locale': lang, 'packet_copy': copy_proof},
                         'event_log': {'path': event_rel.as_posix(), 'sha256': sha256(event_path)},
                         'encoded_duration_seconds': encoder.probe(out / f'{scene["scene"]}.mp4')['duration']})
            video_rows.append(info)
            publications += [(source_clip, ROOT / source_rel),
                             (out / f'{scene["scene"]}.mp4', ROOT / 'landing/videos' / info['video']),
                             (out / f'{scene["scene"]}.webp', ROOT / 'landing/videos' / info['poster'])]
    common = {'schema_version': 1, 'date': '2026-10-28', 'device': device,
              'status_bar': status_bar, 'demo_owner': owner,
              'fixture_manifest_sha256': sha256(fixture_path), 'native_log_sha256': sha256(native_log),
              'capture_scope': 'Real current native app with fictional isolated local data; no elapsed-time test claim'}
    screens_manifest = {**common, 'scenes': screen_rows}
    videos_manifest = {**common, 'speed_changed': False,
                       'editorial_overlay': 'White/black cursor and click ring derived only from real native tap coordinates/timestamps; underlying UI is recorded footage.',
                       'raw_sha256': sha256(raw), 'raw_bytes': raw.stat().st_size,
                       'metadata_sha256': sha256(meta_path), 'recorded_at': meta['started_at'],
                       'recorded_until': meta['stopped_at'], 'sync_offset_seconds': args.sync_offset,
                       'source_dimensions': {'width': raw_info['width'], 'height': raw_info['height']},
                       'dimension_policy': 'Aspect-preserving scale and minimal padding, without crop/stretch.',
                       'quality_policy': {'crf_candidates': encoder.CRFS, 'maximum_crf': max(encoder.CRFS),
                                          'maximum_video_bytes': encoder.LIMIT}, 'scenes': video_rows}
    screen_manifest_file, video_manifest_file = stage / 'screenshots-manifest.json', stage / 'videos-manifest.json'
    write_json(screen_manifest_file, screens_manifest)
    write_json(video_manifest_file, videos_manifest)
    publications += [(screen_manifest_file, ROOT / f'landing/screenshots/manifest-{DATE}.json'),
                     (video_manifest_file, ROOT / f'landing/videos/manifest-{DATE}.json')]
    # Finish all conversion/provenance checks before touching published files.
    for source, target in publications:
        checked_path(target, ROOT, exists=False)
        if source.stat().st_size >= MAX_BLOB or (target.exists() and not args.replace_existing):
            raise MediaError('Publication preflight failed; staged files are preserved for review')
    for source, target in publications:
        publish_file(source, target, args.replace_existing)
    summary = {'status': 'PACKAGED_NOT_DEPLOYED', 'screenshots': len(screen_rows),
               'videos': len(video_rows), 'publications': len(publications),
               'staging': str(stage.relative_to(ROOT)), 'demo_owner': owner,
               'old_assets_deleted': False, 'native_source_packet_copies_verified': True}
    write_json(stage / 'summary.json', summary)
    print(json.dumps(summary, ensure_ascii=False))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['plan', 'build'], default='plan', nargs='?')
    parser.add_argument('--capture-run', default='build/native_site_media/site-oct28-ui-a1')
    parser.add_argument('--screenshot-dir', default='build/native_site_media/site-oct28-ui/screenshots')
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--status-bar-confirmed', action='store_true')
    parser.add_argument('--replace-existing', action='store_true')
    parser.add_argument('--sync-offset', type=float, default=0)
    args = parser.parse_args()
    if not math.isfinite(args.sync_offset) or not -1 <= args.sync_offset <= 1:
        raise MediaError('Sync offset must be an observed finite value between-1 and1')
    if args.action == 'plan':
        if args.apply:
            raise MediaError('Plan does not accept --apply')
        print(json.dumps({'status': 'PLAN_ONLY_NO_READ_COPY_ENCODE_DELETE', 'screenshots': 30,
                          'videos': 4, 'posters': 4, 'source_proof': 'analiz/ekran_site_2026-10-28/',
                          'capture_run': args.capture_run, 'screenshot_dir': args.screenshot_dir,
                          'required': 'completed passing capture, complete recorder, visual09:41/status-bar confirmation',
                          'deletes': False}, ensure_ascii=False, indent=2))
    else:
        build(args)


if __name__ == '__main__':
    try:
        main()
    except (MediaError, OSError, ValueError, TypeError, KeyError) as error:
        print('Site packaging stopped safely: ' + str(error), file=sys.stderr)
        raise SystemExit(1) from None
