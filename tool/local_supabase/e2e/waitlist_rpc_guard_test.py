#!/usr/bin/env python3
"""Only localhost QA PostgREST. Requires the isolated candidate DB and cutover.

Never targets a deployed site or user account; creates only example.invalid rows.
"""
import concurrent.futures
import json
import urllib.error
import urllib.request
import uuid

BASE = 'http://127.0.0.1:54517'
VERSION = 'waitlist-2026-10-03'

def post(path, body):
    request = urllib.request.Request(
        BASE + path, json.dumps(body).encode(),
        {'Content-Type': 'application/json', 'Prefer': 'return=minimal'}, method='POST')
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            raw = response.read()
            return response.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as error:
        return error.code, None

def rpc(address, consent=True, version=VERSION):
    return post('/rpc/submit_waitlist', {'p_email': address, 'p_marketing_consent': consent,
                                          'p_consent_text_version': version})

if __name__ == '__main__':
    address = 'waitlist-rpc-' + str(uuid.uuid4()) + '@example.invalid'
    first = rpc(address)
    duplicate = rpc(address.upper())
    assert first == duplicate == (200, {'accepted': True}), (first, duplicate)
    assert rpc('invalid@example.invalid', False) == (200, {'accepted': False, 'reason': 'invalid_input'})
    assert rpc('invalid@example.invalid', True, None) == (200, {'accepted': False, 'reason': 'invalid_input'})
    assert post('/waitlist', {'email': 'bypass@example.invalid', 'marketing_consent': True,
                              'consent_text_version': VERSION})[0] in (401,403)
    assert post('/waitlist', {'email': 'bypass@example.invalid', 'marketing_consent': True,
                              'consent_text_version': VERSION,
                              'unsubscribe_token': str(uuid.uuid4())})[0] in (401,403)
    race_address = 'waitlist-race-' + str(uuid.uuid4()) + '@example.invalid'
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(lambda _: rpc(race_address), range(20)))
    assert all(r == (200, {'accepted': True}) for r in results), results
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
        results = list(executor.map(lambda _: rpc(address), range(110)))
    ok = sum(r == (200, {'accepted': True}) for r in results)
    limited = sum(r == (200, {'accepted': False, 'reason': 'rate_limited'}) for r in results)
    assert (ok, limited) == (98, 12), (ok, limited, results)
    print('Same generic response, consent, direct-insert denial, simultaneous retries, atomic 120/hour budget: PASS')
