#!/usr/bin/env python3
"""Record only an explicitly selected, booted PomoSprint QA iOS simulator.

No app interaction, production request, or website write is performed. Stop
with Ctrl+C (SIGINT); the owned simctl process gets SIGINT so it saves the MOV.
"""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import queue
import re
import signal
import subprocess
import threading
import time


ROOT = Path(__file__).resolve().parents[4]
MEDIA_ROOT = ROOT / 'build/native_site_media'


class MediaError(Exception):
    pass


def utc_now():
    return datetime.now(timezone.utc).isoformat(timespec='microseconds').replace('+00:00', 'Z')


def sha256(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b''):
            result.update(chunk)
    return result.hexdigest()


def output_directory(value):
    directory = Path(value).expanduser().resolve()
    base = MEDIA_ROOT.resolve()
    if directory == base or not directory.is_relative_to(base):
        raise MediaError('Output must be a run directory below build/native_site_media')
    if directory == (base / 'final') or directory.is_relative_to(base / 'final'):
        raise MediaError('The final directory is reserved for encoded media')
    return directory


def validate_device(udid, inventory):
    if not re.fullmatch(r'[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}', udid):
        raise MediaError('An explicit simulator UUID is required')
    # The user's protected simulator is excluded even if someone renames it.
    if udid.upper().startswith('2CF'):
        raise MediaError('Protected simulator is not allowed')
    if not isinstance(inventory, dict) or not isinstance(inventory.get('devices'), dict):
        raise MediaError('Malformed simulator inventory')
    rows = []
    for runtime, devices in inventory['devices'].items():
        if not isinstance(devices, list):
            raise MediaError('Malformed simulator inventory')
        for device in devices:
            if not isinstance(device, dict) or not isinstance(device.get('udid'), str):
                raise MediaError('Malformed simulator inventory')
            if device['udid'].lower() == udid.lower():
                if not isinstance(runtime, str) or not runtime.startswith('com.apple.CoreSimulator.SimRuntime.iOS-'):
                    raise MediaError('Only iOS simulator recordings are allowed')
                rows.append(device)
    if len(rows) != 1:
        raise MediaError('Simulator was not uniquely found')
    device = rows[0]
    if (not isinstance(device.get('name'), str)
            or not device['name'].startswith('PomoSprint QA ')
            or device.get('state') != 'Booted'
            or device.get('isAvailable') is not True):
        raise MediaError('Only an available, booted PomoSprint QA simulator may be recorded')


def write_metadata(path, data):
    temporary = path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    os.replace(temporary, path)


def signal_owned_process(process, signum):
    try:
        os.killpg(process.pid, signum)
    except ProcessLookupError:
        # A process may exit between poll() and signalling its owned group.
        pass


def record(udid, directory, ready_timeout):
    inventory = subprocess.run(['xcrun', 'simctl', 'list', 'devices', '--json'],
                               check=True, capture_output=True, text=True, timeout=10)
    validate_device(udid, json.loads(inventory.stdout))
    directory = output_directory(directory)
    directory.mkdir(parents=True, exist_ok=True)
    raw, meta = directory / 'raw.mov', directory / 'recording.json'
    if raw.exists() or meta.exists():
        raise MediaError('Existing recording is preserved; choose a new run directory')
    process = subprocess.Popen(
        ['xcrun', 'simctl', 'io', udid, 'recordVideo', '--codec=h264', '--force', str(raw)],
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1,
        start_new_session=True,
    )
    lines = queue.Queue()
    stop_requested = threading.Event()
    sent_stop = False

    def read_output():
        try:
            for line in process.stdout:
                lines.put(line)
        except (OSError, ValueError):
            # The owning thread can close the pipe after terminating simctl.
            pass

    def request_stop(_signum, _frame):
        stop_requested.set()

    previous_handlers = {sig: signal.getsignal(sig) for sig in (signal.SIGINT, signal.SIGTERM)}
    for sig in previous_handlers:
        signal.signal(sig, request_stop)
    reader = threading.Thread(target=read_output, daemon=True)
    reader.start()
    metadata = None
    try:
        deadline = time.monotonic() + ready_timeout
        while True:
            if stop_requested.is_set():
                raise MediaError('Recording was stopped before readiness')
            if process.poll() is not None:
                raise MediaError('Recorder exited before readiness')
            if time.monotonic() >= deadline:
                raise MediaError('Recorder readiness timed out')
            try:
                line = lines.get(timeout=.1)
            except queue.Empty:
                continue
            if 'recording started' in line.lower():
                metadata = {
                    'schema_version': 1, 'status': 'recording',
                    'started_at': utc_now(), 'raw_file': raw.name,
                    'codec_requested': 'h264',
                    'clock_reference': 'UTC receipt of simctl Recording started; observed sync offset may be applied later',
                    'source': 'real PomoSprint QA simulator recording',
                }
                write_metadata(meta, metadata)
                print('READY ' + json.dumps({'started_at': metadata['started_at'],
                      'metadata': str(meta.relative_to(ROOT))}), flush=True)
                break
        # The reader drains diagnostic output but never logs private device
        # data or paths. Only the owned child process is interrupted.
        while process.poll() is None and not stop_requested.wait(.1):
            pass
        if process.poll() is None:
            signal_owned_process(process, signal.SIGINT)
            sent_stop = True
        try:
            code = process.wait(timeout=20)
        except subprocess.TimeoutExpired:
            signal_owned_process(process, signal.SIGKILL)
            process.wait(timeout=5)
            raise MediaError('Recorder did not finalize after SIGINT') from None
        if not stop_requested.is_set() or code not in (0, 130, -signal.SIGINT):
            raise MediaError('Recorder exited unexpectedly')
        if not raw.is_file() or raw.stat().st_size == 0:
            raise MediaError('Recorder did not save a nonempty MOV')
        metadata.update(status='complete', stopped_at=utc_now(),
                        bytes=raw.stat().st_size, raw_sha256=sha256(raw), exit_code=code)
        write_metadata(meta, metadata)
        print('SAVED ' + json.dumps({'bytes': metadata['bytes'], 'raw_sha256': metadata['raw_sha256']}), flush=True)
    finally:
        if process.poll() is None:
            if not sent_stop:
                signal_owned_process(process, signal.SIGINT)
            try:
                process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                signal_owned_process(process, signal.SIGKILL)
                process.wait(timeout=5)
        for sig, handler in previous_handlers.items():
            signal.signal(sig, handler)
        process.stdout.close()
        reader.join(timeout=1)
        if metadata is not None and metadata['status'] != 'complete':
            metadata.update(status='failed', stopped_at=utc_now())
            write_metadata(meta, metadata)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--udid', required=True)
    parser.add_argument('--out-dir', required=True)
    parser.add_argument('--ready-timeout', type=float, default=20)
    args = parser.parse_args()
    if not 1 <= args.ready_timeout <= 60:
        raise MediaError('Readiness timeout must be 1–60 seconds')
    record(args.udid, args.out_dir, args.ready_timeout)


if __name__ == '__main__':
    try:
        main()
    except MediaError as error:
        raise SystemExit('FAILED: ' + str(error)) from None
    except (OSError, ValueError, subprocess.SubprocessError):
        raise SystemExit('Recording failed safely; inspect the local recording metadata. No device output was logged.') from None
