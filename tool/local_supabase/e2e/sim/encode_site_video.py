#!/usr/bin/env python3
"""Trim real native scenes, add event-derived vector click cues, encode <=256KiB.

Reads only [MEDIA_EVENT] JSON records from the native log. It does not construct
application screens or accelerate footage. All outputs stay in the repository's
build/native_site_media/final directory; no landing assets or deploy are touched.
"""
import argparse
from datetime import datetime, timezone
import json
import math
import os
from pathlib import Path
import subprocess

from record_site_video import MEDIA_ROOT, MediaError, sha256


WIDTH, HEIGHT, FPS, LIMIT = 540, 1170, 24, 262144
SCENES = {'timer', 'marathon'}
MARKER = '[MEDIA_EVENT]'
CRFS = [32, 34, 36, 38, 40, 42]


def utc(value):
    if not isinstance(value, str):
        raise MediaError('Event UTC timestamp must be a string')
    try:
        result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    except ValueError:
        raise MediaError('Invalid event UTC timestamp') from None
    if result.tzinfo is None or result.utcoffset().total_seconds() != 0:
        raise MediaError('Explicit UTC timestamps are required')
    return result.astimezone(timezone.utc)


def number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise MediaError('Finite numeric event coordinates are required')
    return float(value)


def parse_events(text):
    scenes, active, previous = {}, None, None
    for line in text.splitlines():
        if MARKER not in line:
            continue
        try:
            event = json.loads(line.split(MARKER, 1)[1].strip())
        except (ValueError, TypeError):
            raise MediaError('Malformed MEDIA_EVENT JSON') from None
        if not isinstance(event, dict):
            raise MediaError('MEDIA_EVENT must be an object')
        kind, scene = event.get('kind'), event.get('scene')
        if kind not in {'scene_start', 'tap', 'scene_end'} or scene not in SCENES:
            raise MediaError('Unknown event kind or scene')
        at = utc(event.get('at'))
        if previous is not None and at < previous:
            raise MediaError('MEDIA_EVENT timestamps must be monotonic')
        previous = at
        expected_keys = {'kind', 'scene', 'at'}
        if kind == 'tap':
            expected_keys |= {'x', 'y', 'width', 'height'}
        if set(event) != expected_keys:
            raise MediaError('Unexpected MEDIA_EVENT fields')
        if kind == 'scene_start':
            if active is not None or scene in scenes:
                raise MediaError('Scenes cannot overlap or repeat')
            active = scene
            scenes[scene] = {'scene': scene, 'start': at, 'taps': []}
        elif active != scene:
            raise MediaError('Tap/end must belong to the currently open scene')
        elif kind == 'scene_end':
            duration = (at - scenes[scene]['start']).total_seconds()
            if not 1 <= duration <= 120:
                raise MediaError('Each scene must last 1–120 seconds')
            scenes[scene]['end'] = at
            active = None
        else:
            x, y, width, height = (number(event[key]) for key in ('x', 'y', 'width', 'height'))
            if not (1 <= width <= 10000 and 1 <= height <= 10000
                    and 0 <= x < width and 0 <= y < height):
                raise MediaError('Tap is outside the logical viewport')
            scenes[scene]['taps'].append({'at': at, 'x': x, 'y': y,
                                         'width': width, 'height': height})
    if active is not None or set(scenes) != SCENES:
        raise MediaError('Exactly one complete timer and marathon scene is required')
    if any(not scene['taps'] for scene in scenes.values()):
        raise MediaError('Each scene needs at least one real logged tap')
    return list(scenes.values())


def run(command, *, cwd=None, timeout=120, stage='media command'):
    try:
        result = subprocess.run(command, cwd=cwd, capture_output=True, text=True, timeout=timeout)
    except (OSError, subprocess.TimeoutExpired):
        raise MediaError(f'{stage} failed or timed out') from None
    if result.returncode:
        raise MediaError(f'{stage} returned exit {result.returncode}; no output was accepted')
    return result.stdout


def probe(path):
    try:
        data = json.loads(run(['ffprobe', '-v', 'error', '-show_streams', '-show_format',
                               '-of', 'json', str(path)], timeout=20))
        video = [stream for stream in data['streams'] if stream['codec_type'] == 'video']
        if len(video) != 1:
            raise MediaError('One video stream is required')
        stream = video[0]
        duration = float(data['format'].get('duration', stream.get('duration', 0)))
        if not math.isfinite(duration) or not 0 < duration <= 3600:
            raise MediaError('Invalid video duration')
        width, height = int(stream['width']), int(stream['height'])
        if width <= 0 or height <= 0:
            raise MediaError('Invalid video dimensions')
        return {'width': width, 'height': height,
                'duration': duration, 'codec': stream['codec_name'],
                'pixel_format': stream.get('pix_fmt'), 'fps': stream.get('avg_frame_rate'),
                'has_audio': any(s['codec_type'] == 'audio' for s in data['streams'])}
    except (KeyError, TypeError, ValueError):
        raise MediaError('Invalid ffprobe result') from None


def ass_time(seconds):
    centiseconds = max(0, round(seconds * 100))
    return f'{centiseconds // 360000}:{centiseconds // 6000 % 60:02}:{centiseconds // 100 % 60:02}.{centiseconds % 100:02}'


def transform(raw, tap):
    if raw['width'] <= 0 or raw['height'] <= 0:
        raise MediaError('Invalid source dimensions')
    if abs(tap['width'] / tap['height'] - raw['width'] / raw['height']) > .03:
        raise MediaError('Logical viewport and recorded video aspect ratios do not match')
    scale = min(WIDTH / raw['width'], HEIGHT / raw['height'])
    scaled_width = max(2, round(raw['width'] * scale / 2) * 2)
    scaled_height = max(2, round(raw['height'] * scale / 2) * 2)
    return (scaled_width, scaled_height,
            (WIDTH - scaled_width) / 2 + tap['x'] / tap['width'] * scaled_width,
            (HEIGHT - scaled_height) / 2 + tap['y'] / tap['height'] * scaled_height)


def write_ass(path, scene, raw):
    duration = (scene['end'] - scene['start']).total_seconds()
    lines = [
        '[Script Info]', 'ScriptType: v4.00+', f'PlayResX: {WIDTH}', f'PlayResY: {HEIGHT}',
        'ScaledBorderAndShadow: yes', 'WrapStyle: 2', '', '[V4+ Styles]',
        'Format: Name,Fontname,Fontsize,PrimaryColour,SecondaryColour,OutlineColour,BackColour,Bold,Italic,Underline,StrikeOut,ScaleX,ScaleY,Spacing,Angle,BorderStyle,Outline,Shadow,Alignment,MarginL,MarginR,MarginV,Encoding',
        'Style: Cue,Arial,20,&H00FFFFFF,&H00FFFFFF,&H00111111,&H50000000,0,0,0,0,100,100,0,0,1,1.5,0.5,7,0,0,0,1',
        '', '[Events]', 'Format: Layer,Start,End,Style,Name,MarginL,MarginR,MarginV,Effect,Text',
    ]
    taps = []
    for index, tap in enumerate(scene['taps']):
        at = (tap['at'] - scene['start']).total_seconds()
        _, _, x, y = transform(raw, tap)
        next_at = ((scene['taps'][index + 1]['at'] - scene['start']).total_seconds()
                   if index + 1 < len(scene['taps']) else duration + 1)
        start, end = max(0, at - .12), min(duration, at + .8, next_at - .12)
        if end <= start:
            raise MediaError('Tap events are too close for an unambiguous cursor')
        cursor = (f'{{\\an7\\pos({x:.2f},{y:.2f})\\p1\\fad(60,120)}}'
                  'm 0 0 l 0 26 6 20 11 30 16 27 12 18 22 18 0 0')
        lines.append(f'Dialogue: 2,{ass_time(start)},{ass_time(end)},Cue,,0,0,0,,{cursor}')
        ring_end = min(duration, at + .42)
        if ring_end > at:
            ring = (f'{{\\an5\\pos({x:.2f},{y:.2f})\\p1\\bord1.4\\shad0.5\\1a&HFF&'
                    '\\3a&H55&\\fscx100\\fscy100\\t(0,420,\\fscx210\\fscy210)\\fad(0,350)}'
                    'm 20 10 b 20 15.52 15.52 20 10 20 b 4.48 20 0 15.52 0 10 '
                    'b 0 4.48 4.48 0 10 0 b 15.52 0 20 4.48 20 10')
            lines.append(f'Dialogue: 1,{ass_time(at)},{ass_time(ring_end)},Cue,,0,0,0,,{ring}')
        taps.append({'at': tap['at'].isoformat(), 'seconds_in_scene': at,
                     'logical': {key: tap[key] for key in ('x', 'y', 'width', 'height')},
                     'video_x': x, 'video_y': y})
    path.write_text('\n'.join(lines) + '\n')
    return taps


def poster_time(scene):
    if scene['scene'] != 'marathon':
        return .5
    # The fourth real tap selects four sessions while the planner is open.
    # Smaller valid event sets fall back to their second/first actual tap.
    tap_index = 3 if len(scene['taps']) >= 4 else 1 if len(scene['taps']) >= 2 else 0
    tap = scene['taps'][tap_index]
    after_tap = (tap['at'] - scene['start']).total_seconds() + .5
    duration = (scene['end'] - scene['start']).total_seconds()
    return max(0, min(after_tap, duration - 1 / FPS))


def encode_scene(raw_path, raw_info, scene, record_start, sync_offset, out, overwrite):
    name = scene['scene']
    video, poster, subtitles = out / f'{name}.mp4', out / f'{name}.webp', out / f'{name}_cursor.ass'
    if not overwrite and any(path.exists() for path in (video, poster, subtitles)):
        raise MediaError('Existing final media is preserved; use --overwrite explicitly')
    start = (scene['start'] - record_start).total_seconds() + sync_offset
    duration = (scene['end'] - scene['start']).total_seconds()
    if start < 0 or start + duration > raw_info['duration'] + .1:
        raise MediaError('Scene falls outside the real recorded video')
    taps = write_ass(subtitles, scene, raw_info)
    scaled_width, scaled_height, _, _ = transform(raw_info, scene['taps'][0])
    filters = (f'scale={scaled_width}:{scaled_height},'
               f'pad={WIDTH}:{HEIGHT}:(ow-iw)/2:(oh-ih)/2,setsar=1,fps={FPS},ass={subtitles.name}')
    attempts, candidate = [], out / f'.{name}-candidate.mp4'
    try:
        for crf in CRFS:
            print(f'ENCODING {name} crf={crf}', flush=True)
            run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', f'{start:.6f}', '-threads', '2',
                 '-i', str(raw_path), '-t', f'{duration:.6f}', '-map', '0:v:0', '-an', '-sn',
                 '-vf', filters, '-filter_threads', '2', '-c:v', 'libx264', '-preset', 'slow',
                 '-crf', str(crf), '-threads', '2', '-pix_fmt', 'yuv420p', '-movflags', '+faststart',
                 str(candidate)], cwd=out, timeout=600, stage=f'{name} video CRF {crf}')
            size = candidate.stat().st_size
            attempts.append({'crf': crf, 'bytes': size})
            if 0 < size <= LIMIT:
                break
        else:
            raise MediaError('Scene exceeds 262144 bytes at CRF 42; shorten the captured scene and review it instead of lowering quality further')
        encoded = probe(candidate)
        if (encoded['width'], encoded['height'], encoded['codec'], encoded['pixel_format'], encoded['fps']) != (
                WIDTH, HEIGHT, 'h264', 'yuv420p', '24/1') or encoded['has_audio']:
            raise MediaError('Encoded stream does not match the required format')
        if abs(encoded['duration'] - duration) > 1 / 12:
            raise MediaError('Encoded duration changed; no speed adjustment is allowed')
        poster_tmp = out / f'.{name}-poster.webp'
        poster_at = poster_time(scene)
        run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', f'{poster_at:.6f}', '-threads', '2', '-i', str(candidate),
             '-frames:v', '1', '-an', '-c:v', 'libwebp', '-quality', '82', '-threads', '2', str(poster_tmp)],
            cwd=out, timeout=60, stage=f'{name} poster at {poster_at:.6f} seconds')
        if not poster_tmp.is_file() or not poster_tmp.stat().st_size:
            raise MediaError('Poster frame was not written')
        os.replace(candidate, video)
        os.replace(poster_tmp, poster)
        return {'scene': name, 'video': video.name, 'poster': poster.name,
                'video_sha256': sha256(video), 'poster_sha256': sha256(poster),
                'bytes': video.stat().st_size, 'crf': crf, 'attempts': attempts,
                'poster_at_seconds': poster_at,
                'trim_start_seconds': start, 'duration_seconds': duration,
                'scene_started_at': scene['start'].isoformat(), 'scene_ended_at': scene['end'].isoformat(),
                'taps': taps, 'fps': FPS, 'width': WIDTH, 'height': HEIGHT,
                'codec': 'h264', 'pixel_format': 'yuv420p', 'audio': False}
    finally:
        candidate.unlink(missing_ok=True)
        (out / f'.{name}-poster.webp').unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--raw', type=Path, required=True)
    parser.add_argument('--meta', type=Path, required=True)
    parser.add_argument('--events', type=Path, required=True)
    parser.add_argument('--sync-offset', type=float, default=0,
                        help='Observed seconds added to event-to-video mapping, bounded -1..1 (default 0)')
    parser.add_argument('--overwrite', action='store_true')
    args = parser.parse_args()
    if not math.isfinite(args.sync_offset) or not -1 <= args.sync_offset <= 1:
        raise MediaError('Synchronization offset must be between -1 and 1 second')
    raw_path, meta_path, event_path = (path.expanduser().resolve() for path in (args.raw, args.meta, args.events))
    if not raw_path.is_relative_to(MEDIA_ROOT.resolve()) or not meta_path.is_relative_to(MEDIA_ROOT.resolve()):
        raise MediaError('Raw video and recording metadata must stay below build/native_site_media')
    if raw_path.suffix != '.mov' or meta_path.suffix != '.json' or event_path.suffix != '.log':
        raise MediaError('Expected raw MOV, recording JSON, and native LOG inputs')
    metadata = json.loads(meta_path.read_text())
    if not isinstance(metadata, dict) or metadata.get('schema_version') != 1 or metadata.get('status') != 'complete':
        raise MediaError('A completed recorder metadata file is required')
    if metadata.get('raw_file') != raw_path.name:
        raise MediaError('Recording metadata names a different source file')
    record_start = utc(metadata.get('started_at'))
    record_end = utc(metadata.get('stopped_at'))
    if record_end <= record_start:
        raise MediaError('Recording stop must follow its start')
    raw_hash = sha256(raw_path)
    if metadata.get('raw_sha256') != raw_hash or metadata.get('bytes') != raw_path.stat().st_size:
        raise MediaError('Raw video no longer matches its recording provenance')
    if event_path.stat().st_size > 32 * 1024 * 1024:
        raise MediaError('Native event log is unexpectedly large')
    scenes = parse_events(event_path.read_text())
    raw_info = probe(raw_path)
    if raw_info['codec'] != 'h264':
        raise MediaError('Expected the native H264 recording')
    out = (MEDIA_ROOT / 'final').resolve()
    if not out.is_relative_to(MEDIA_ROOT.resolve()):
        raise MediaError('Final output directory cannot escape the media root')
    out.mkdir(parents=True, exist_ok=True)
    manifest_path = out / 'manifest.json'
    if manifest_path.exists() and not args.overwrite:
        raise MediaError('Existing manifest is preserved; use --overwrite explicitly')
    encoded = [encode_scene(raw_path, raw_info, scene, record_start, args.sync_offset, out, args.overwrite)
               for scene in scenes]
    manifest = {
        'schema_version': 1, 'source': 'real native PomoSprint QA simulator video',
        'raw_sha256': raw_hash, 'metadata_sha256': sha256(meta_path), 'event_log_sha256': sha256(event_path),
        'recorded_at': metadata['started_at'], 'recorded_until': metadata.get('stopped_at'),
        'sync_offset_seconds': args.sync_offset, 'speed_changed': False,
        'source_dimensions': {'width': raw_info['width'], 'height': raw_info['height']},
        'dimension_policy': 'Aspect-preserving scale with padding; no crop or stretch.',
        'quality_policy': {'crf_candidates': CRFS, 'maximum_crf': max(CRFS), 'maximum_video_bytes': LIMIT},
        'editorial_overlay': 'White/black ASS vector cursor and fading click ring derived only from logged real native tap coordinates/timestamps; underlying UI is recorded footage.',
        'scenes': encoded,
    }
    temporary = manifest_path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    os.replace(temporary, manifest_path)
    print('DONE ' + str(manifest_path.relative_to(MEDIA_ROOT.parent.parent)), flush=True)


if __name__ == '__main__':
    try:
        main()
    except MediaError as error:
        raise SystemExit('FAILED: ' + str(error)) from None
    except (OSError, ValueError, TypeError):
        raise SystemExit('Media encoding failed. No source video or website file was changed.') from None
