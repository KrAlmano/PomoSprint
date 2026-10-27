"""Exact QA recipient recovery against loopback only; no token/body logging."""
from datetime import datetime, timezone, timedelta
import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request

import local_mailpit as mail

EMAIL = re.compile(r'^e2e-sim-recovery-[a-z0-9-]{1,40}@pomosprint\.local$')
JWT = re.compile(r'^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$')
RETURN = 'http://127.0.0.1:3000'


class RecoveryError(Exception):
    pass


def recipient(email):
    if not isinstance(email, str) or not EMAIL.fullmatch(email):
        raise RecoveryError('invalid_recovery_recipient')
    return email


def recovery_link(message, email):
    recipient(email)
    if not isinstance(message, dict) or not mail._is_recipient(message, email):
        raise RecoveryError('recipient_mismatch')
    parser = mail._Links()
    try:
        parser.feed(message.get('HTML') or '')
    except (TypeError, ValueError):
        raise RecoveryError('invalid_recovery_mail') from None
    text = message.get('Text') or ''
    links = parser.links + (re.findall(r'https?://[^\s<>"\']+', text) if isinstance(text, str) else [])
    for link in links:
        if not isinstance(link, str) or len(link) > 4096 or any(ord(c) < 32 for c in link):
            continue
        try:
            parsed = urllib.parse.urlsplit(html.unescape(link))
            query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True, strict_parsing=True)
            redirects = query.get('redirect_to', [])
            if (parsed.scheme != 'http' or parsed.netloc != '127.0.0.1:54321'
                    or parsed.path != '/auth/v1/verify' or parsed.fragment
                    or parsed.username or parsed.password
                    or set(query) - {'type', 'token', 'redirect_to'}
                    or query.get('type') != ['recovery']
                    or len(query.get('token', [])) != 1
                    or not mail.TOKEN_RE.fullmatch(query['token'][0])
                    or len(redirects) > 1
                    or (redirects and redirects[0] not in {
                        'https://pomosprint.app/reset-password.html', RETURN, RETURN + '/'})):
                continue
            # Never request the mail's return location. Use a fixed local
            # return solely to receive GoTrue's response without following it.
            return mail.VERIFY_URL + '?' + urllib.parse.urlencode({
                'type': 'recovery', 'token': query['token'][0], 'redirect_to': RETURN})
        except (ValueError, TypeError):
            continue
    raise RecoveryError('recovery_link_not_found')


def session_from_redirect(location):
    try:
        if not mail._safe_return_url(location):
            raise RecoveryError('recovery_redirect_rejected')
        parsed = urllib.parse.urlsplit(location)
        query = urllib.parse.parse_qs(parsed.query)
        fragment = urllib.parse.parse_qs(parsed.fragment)
        tokens = fragment.get('access_token', [])
        if ('error' in query or 'error' in fragment or fragment.get('type') != ['recovery']
                or len(tokens) != 1 or len(tokens[0]) > 8192 or not JWT.fullmatch(tokens[0])):
            raise RecoveryError('recovery_session_rejected')
        return tokens[0]
    except (ValueError, TypeError):
        raise RecoveryError('recovery_session_rejected') from None


def _verify(link, timeout):
    opener = urllib.request.build_opener(mail._NoRedirect(), urllib.request.ProxyHandler({}))
    try:
        with opener.open(link, timeout=timeout):
            raise RecoveryError('recovery_redirect_missing')
    except urllib.error.HTTPError as response:
        try:
            if response.code not in (302, 303):
                raise RecoveryError('recovery_verify_rejected')
            return session_from_redirect(response.headers.get('Location', ''))
        finally:
            response.close()
    except (OSError, ValueError):
        raise RecoveryError('recovery_verify_unavailable') from None


def _auth(method, token, anon_key, timeout, payload=None):
    request = urllib.request.Request(
        'http://127.0.0.1:54321/auth/v1/user', method=method,
        headers={'apikey': anon_key, 'Authorization': 'Bearer ' + token,
                 'Content-Type': 'application/json'},
        data=None if payload is None else json.dumps(payload).encode())
    opener = urllib.request.build_opener(mail._NoRedirect(), urllib.request.ProxyHandler({}))
    try:
        with opener.open(request, timeout=timeout) as response:
            raw = response.read(mail.MAX_RESPONSE + 1)
            if len(raw) > mail.MAX_RESPONSE:
                raise RecoveryError('recovery_auth_response_too_large')
            data = json.loads(raw)
            if not isinstance(data, dict):
                raise RecoveryError('recovery_auth_response_invalid')
            return data
    except (OSError, ValueError, urllib.error.HTTPError):
        raise RecoveryError('recovery_auth_rejected') from None


def reset_local_password(email, password, anon_key, timeout=20):
    recipient(email)
    if (not isinstance(password, str) or not 8 <= len(password) <= 72
            or not re.search('[a-z]', password) or not re.search('[A-Z]', password)
            or not re.search('[0-9]', password)
            or not isinstance(anon_key, str) or not 20 <= len(anon_key) <= 4096
            or any(ord(c) < 32 for c in anon_key)):
        raise RecoveryError('invalid_recovery_request')
    deadline = time.monotonic() + min(max(float(timeout), .1), 20)

    def remaining():
        value = deadline - time.monotonic()
        if value <= 0:
            raise RecoveryError('recovery_timeout')
        return min(3, value)

    while time.monotonic() < deadline:
        listing = mail._open_json(mail.MAILPIT_URL + '/api/v1/messages?limit=100', remaining())
        messages = listing.get('messages', []) if isinstance(listing, dict) else []
        if not isinstance(messages, list):
            raise RecoveryError('invalid_recovery_mailbox')
        for item in messages:
            if not isinstance(item, dict) or not mail._is_recipient(item, email):
                continue
            message_id = item.get('ID')
            if not isinstance(message_id, str) or not mail.MESSAGE_ID_RE.fullmatch(message_id):
                continue
            detail = mail._open_json(mail.MAILPIT_URL + '/api/v1/message/' + message_id, remaining())
            try:
                link = recovery_link(detail, email)
            except RecoveryError:
                continue
            token = _verify(link, remaining())
            user = _auth('GET', token, anon_key, remaining())
            try:
                created = datetime.fromisoformat(user['created_at'].replace('Z', '+00:00'))
                age = datetime.now(timezone.utc) - created
            except (KeyError, TypeError, ValueError):
                raise RecoveryError('recovery_owner_rejected') from None
            if (not isinstance(user.get('id'), str)
                    or not re.fullmatch(r'[0-9a-f-]{36}', user['id'])
                    or user.get('email') != email
                    or not -timedelta(minutes=1) <= age < timedelta(hours=12)):
                raise RecoveryError('recovery_owner_rejected')
            changed = _auth('PUT', token, anon_key, remaining(), {'password': password})
            if changed.get('id') != user.get('id') or changed.get('email') != email:
                raise RecoveryError('recovery_owner_rejected')
            return True
        time.sleep(min(.2, max(0, deadline - time.monotonic())))
    raise RecoveryError('recovery_mail_timeout')
