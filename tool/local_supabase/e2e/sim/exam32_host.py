#!/usr/bin/env python3
"""Fixed isolated32 adapter for native screenshots and read-only SQL.

The ordinary host stays fixed to the ordinary local database. This adapter
cannot confirm mail, change passwords, stop shared API services, or invoke its
ordinary-database report oracle. Only the two named QA devices are supported.
"""
import argparse
from pathlib import Path
import sys
import urllib.parse

import e2e_host as host

ROOT = Path(__file__).resolve().parents[4]
DATABASES = {'review': 'pomosprint_review32_dus', 'site': 'pomosprint_site32_dus', 'kpss': 'pomosprint_review32_kpss'}
IOS_UDID = '2CFDB5C8-6CA6-457C-8A6E-864B1849C681'
ANDROID_SERIAL = 'emulator-5554'
PORTS = {'review': {'ios': 54359, 'android': 54369}, 'site': {'ios': 54379}, 'kpss': {'ios': 54409}}


class Handler(host.Handler):
    def do_GET(self):
        path = urllib.parse.urlsplit(self.path).path
        if path not in {'/health', '/shot'}:
            if self._guard_local_client():
                self._reply(403, 'isolated32_route_forbidden', no_store=True)
            return
        super().do_GET()

    def do_POST(self):
        if self.path != '/psql':
            if self._guard_local_client():
                self._reply(403, 'isolated32_route_forbidden', no_store=True)
            return
        super().do_POST()


def output_directory(value):
    path = Path(value).expanduser().absolute()
    # No caller may redirect a native screenshot or SQL log through symlinks.
    if any(parent.is_symlink() for parent in (path, *path.parents)):
        raise ValueError('symlink output refused')
    path = path.resolve()
    if not path.is_relative_to(ROOT / 'build') and not path.is_relative_to(ROOT / 'analiz'):
        raise ValueError('output must be in repository build/ or analiz/')
    return path


def main(arguments=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', choices=PORTS, default='review')
    parser.add_argument('--device', choices={'ios', 'android'}, required=True)
    parser.add_argument('--shot-dir', required=True)
    args = parser.parse_args(arguments)
    if args.device not in PORTS[args.profile]:
        parser.error('site media supports only the named iOS device')
    port = PORTS[args.profile][args.device]
    database = DATABASES[args.profile]
    path = output_directory(args.shot_dir)
    # Verify the complete fixed-database schema/catalog before exposing SQL.
    sys.path.insert(0, str(ROOT / 'tool/local_supabase'))
    import parity_check_exam32
    if parity_check_exam32.main(['--profile', args.profile]):
        raise ValueError('isolated32 parity failed')
    host.DB_URL = f'postgresql://postgres:postgres@127.0.0.1:54322/{database}'
    server = host.ThreadingHTTPServer(('127.0.0.1', port), Handler)
    server.allow_api_outage = False
    server.android_serial = ANDROID_SERIAL if args.device == 'android' else None
    server.udid = IOS_UDID if args.device == 'ios' else None
    server.shot_dir = str(path)
    server.psql_log = str(path.parent / f'psql-{args.device}.log')
    sys.stderr.write(f'[exam32_host] {args.profile}/{args.device} 127.0.0.1:{port} {database}\n')
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError) as error:
        sys.stderr.write(f'isolated32 native host refused: {error}\n')
        sys.exit(2)
