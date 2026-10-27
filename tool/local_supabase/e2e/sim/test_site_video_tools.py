#!/usr/bin/env python3
"""Small offline tests: no simulator, media command, or network is started."""
from datetime import timedelta
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import encode_site_video as encoder
import record_site_video as recorder


UDID = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'


def inventory(**values):
    device = {'udid': UDID, 'name': 'PomoSprint QA media',
              'isAvailable': True, 'state': 'Booted'}
    device.update(values)
    return {'devices': {'com.apple.CoreSimulator.SimRuntime.iOS-18-6': [device]}}


def events():
    return [
        {'kind': 'scene_start', 'scene': 'timer', 'at': '2026-10-28T00:00:01Z'},
        {'kind': 'tap', 'scene': 'timer', 'at': '2026-10-28T00:00:02Z',
         'x': 196.5, 'y': 720, 'width': 393, 'height': 852},
        {'kind': 'scene_end', 'scene': 'timer', 'at': '2026-10-28T00:00:05Z'},
        {'kind': 'scene_start', 'scene': 'marathon', 'at': '2026-10-28T00:00:06Z'},
        {'kind': 'tap', 'scene': 'marathon', 'at': '2026-10-28T00:00:07Z',
         'x': 200, 'y': 400, 'width': 393, 'height': 852},
        {'kind': 'scene_end', 'scene': 'marathon', 'at': '2026-10-28T00:00:12Z'},
    ]


def log(rows):
    return 'unrelated native diagnostic\n' + '\n'.join(
        '00:03 +1: [MEDIA_EVENT] ' + json.dumps(row) for row in rows)


class RecorderGuardsTest(unittest.TestCase):
    def test_only_explicit_available_booted_qa_device(self):
        recorder.validate_device(UDID, inventory())
        for data in (inventory(name='iPhone 16'), inventory(state='Shutdown'),
                     inventory(isAvailable=False), inventory(name=None)):
            with self.subTest(data=data), self.assertRaises(recorder.MediaError):
                recorder.validate_device(UDID, data)

    def test_protected_udid_is_rejected_even_if_renamed(self):
        protected = '2CF00000-BBBB-CCCC-DDDD-EEEEEEEEEEEE'
        with self.assertRaises(recorder.MediaError):
            recorder.validate_device(protected, inventory(udid=protected))

    def test_missing_duplicate_or_malformed_inventory_is_rejected(self):
        duplicate = inventory()
        duplicate['devices']['com.apple.CoreSimulator.SimRuntime.iOS-18-6'] *= 2
        wrong_platform = {'devices': {'com.apple.CoreSimulator.SimRuntime.tvOS-18-6':
                                     next(iter(inventory()['devices'].values()))}}
        for data in ({}, {'devices': {'x': None}}, {'devices': {'x': [None]}},
                     inventory(udid='different'), duplicate, wrong_platform):
            with self.subTest(data=data), self.assertRaises(recorder.MediaError):
                recorder.validate_device(UDID, data)

    def test_output_cannot_leave_media_root_or_replace_final(self):
        with tempfile.TemporaryDirectory() as temporary:
            base = Path(temporary) / 'media'
            base.mkdir()
            with patch.object(recorder, 'MEDIA_ROOT', base):
                self.assertEqual(recorder.output_directory(base / 'run'), (base / 'run').resolve())
                for path in (base, base.parent, base / 'final', base / 'final' / 'run'):
                    with self.subTest(path=path), self.assertRaises(recorder.MediaError):
                        recorder.output_directory(path)
                (base / 'escape').symlink_to(base.parent, target_is_directory=True)
                with self.assertRaises(recorder.MediaError):
                    recorder.output_directory(base / 'escape' / 'run')


class EventParsingTest(unittest.TestCase):
    def test_accepts_prefixed_native_log_with_exact_two_scenes(self):
        result = encoder.parse_events(log(events()))
        self.assertEqual([scene['scene'] for scene in result], ['timer', 'marathon'])
        self.assertEqual(result[0]['taps'][0]['x'], 196.5)

    def test_rejects_non_utc_or_backward_time(self):
        for timestamp in ('2026-10-28T00:00:02', '2026-10-28T03:00:02+03:00',
                          'not-a-date', '2026-10-28T00:00:00Z'):
            rows = events()
            rows[1]['at'] = timestamp
            with self.subTest(timestamp=timestamp), self.assertRaises(recorder.MediaError):
                encoder.parse_events(log(rows))

    def test_rejects_missing_scene_end_or_real_tap(self):
        for rows in (events()[:-1], events()[:3],
                     [event for event in events() if event['kind'] != 'tap']):
            with self.subTest(rows=rows), self.assertRaises(recorder.MediaError):
                encoder.parse_events(log(rows))

    def test_rejects_overlapping_or_repeated_scenes(self):
        rows = events()
        rows[2] = {'kind': 'scene_start', 'scene': 'marathon', 'at': rows[2]['at']}
        with self.assertRaises(recorder.MediaError):
            encoder.parse_events(log(rows))
        rows = events()
        rows[3]['scene'] = 'timer'
        with self.assertRaises(recorder.MediaError):
            encoder.parse_events(log(rows))

    def test_rejects_unknown_fields_malformed_json_and_nonobjects(self):
        rows = events()
        rows[1]['email'] = 'must-not-be-accepted'
        for text in (log(rows), '[MEDIA_EVENT] {broken', '[MEDIA_EVENT] []'):
            with self.subTest(text=text), self.assertRaises(recorder.MediaError):
                encoder.parse_events(text)

    def test_rejects_outside_nonfinite_and_boolean_coordinates(self):
        for key, value in (('x', -1), ('y', 852), ('width', 0), ('height', 10001),
                           ('x', float('nan')), ('x', True), ('y', '12')):
            rows = events()
            rows[1][key] = value
            with self.subTest(key=key, value=value), self.assertRaises(recorder.MediaError):
                encoder.parse_events(log(rows))

    def test_rejects_overlong_scenes(self):
        rows = events()[:3]
        rows[2]['at'] = '2026-10-28T00:03:05Z'
        with self.assertRaises(recorder.MediaError):
            encoder.parse_events(log(rows))


class EncodingGuardsTest(unittest.TestCase):
    def test_aspect_preserved_and_coordinates_mapped(self):
        raw = {'width': 1179, 'height': 2556}
        tap = {'x': 196.5, 'y': 426, 'width': 393, 'height': 852}
        width, height, x, y = encoder.transform(raw, tap)
        self.assertEqual((width, height), (540, 1170))
        self.assertAlmostEqual(x, 270)
        self.assertAlmostEqual(y, 585)
        with self.assertRaises(recorder.MediaError):
            encoder.transform(raw, dict(tap, width=852, height=393))

    def test_ass_is_vector_overlay_from_exact_logged_taps(self):
        scene = encoder.parse_events(log(events()))[0]
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'cursor.ass'
            taps = encoder.write_ass(path, scene, {'width': 1179, 'height': 2556})
            source = path.read_text()
        self.assertIn('PlayResX: 540', source)
        self.assertIn('\\p1', source)
        self.assertIn('\\pos(270.00,988.73)', source)
        self.assertEqual(taps[0]['seconds_in_scene'], 1)

    def test_coincident_taps_fail_without_inventing_timing(self):
        scene = encoder.parse_events(log(events()))[0]
        scene['taps'].append(dict(scene['taps'][0]))
        with tempfile.TemporaryDirectory() as temporary, self.assertRaises(recorder.MediaError):
            encoder.write_ass(Path(temporary) / 'cursor.ass', scene, {'width': 1179, 'height': 2556})

    def test_scene_outside_recording_never_runs_encoder(self):
        scene = encoder.parse_events(log(events()))[0]
        with tempfile.TemporaryDirectory() as temporary, patch.object(encoder, 'run') as run:
            with self.assertRaises(recorder.MediaError):
                encoder.encode_scene(Path('unused.mov'), {'duration': 1}, scene,
                                     scene['start'], 0, Path(temporary), False)
            run.assert_not_called()

    def test_oversize_stops_at_crf42_and_accepts_no_video(self):
        scene = encoder.parse_events(log(events()))[0]
        raw = {'width': 1179, 'height': 2556, 'duration': 30}
        with tempfile.TemporaryDirectory() as temporary:
            out = Path(temporary)
            calls = []

            def fake_run(command, **_kwargs):
                calls.append(command)
                Path(command[-1]).write_bytes(b'x' * (encoder.LIMIT + 1))
                return ''

            with patch.object(encoder, 'run', side_effect=fake_run), self.assertRaisesRegex(
                    recorder.MediaError, 'CRF 42'):
                encoder.encode_scene(Path('unused.mov'), raw, scene, scene['start'], 0, out, False)
            self.assertEqual([int(call[call.index('-crf') + 1]) for call in calls],
                             [32, 34, 36, 38, 40, 42])
            self.assertFalse((out / 'timer.mp4').exists())
            self.assertFalse((out / '.timer-candidate.mp4').exists())

    def test_poster_uses_ffmpeg_compatible_duration_and_bounded_threads(self):
        scene = encoder.parse_events(log(events()))[0]
        raw = {'width': 1179, 'height': 2556, 'duration': 30}
        encoded = {'width': 540, 'height': 1170, 'duration': 4,
                   'codec': 'h264', 'pixel_format': 'yuv420p', 'fps': '24/1', 'has_audio': False}
        with tempfile.TemporaryDirectory() as temporary:
            calls = []

            def fake_run(command, **_kwargs):
                calls.append(command)
                Path(command[-1]).write_bytes(b'valid-placeholder-for-command-test')
                return ''

            with patch.object(encoder, 'run', side_effect=fake_run), patch.object(encoder, 'probe', return_value=encoded):
                result = encoder.encode_scene(Path('unused.mov'), raw, scene, scene['start'], 0, Path(temporary), False)
            poster = calls[1]
            self.assertEqual(poster[poster.index('-ss') + 1], '0.500000')
            self.assertLess(poster.index('-threads'), poster.index('-i'))
            self.assertEqual(result['duration_seconds'], 4)
            self.assertEqual(result['poster_at_seconds'], .5)

    def test_marathon_poster_uses_fourth_real_tap_and_stays_in_video(self):
        scene = encoder.parse_events(log(events()))[1]
        base = scene['taps'][0]
        scene['taps'] = [dict(base, at=base['at'] + timedelta(seconds=i))
                         for i in range(4)]
        self.assertEqual(encoder.poster_time(scene), 4.5)
        scene['end'] = scene['taps'][-1]['at']
        self.assertLess(encoder.poster_time(scene), (scene['end'] - scene['start']).total_seconds())


if __name__ == '__main__':
    unittest.main()
