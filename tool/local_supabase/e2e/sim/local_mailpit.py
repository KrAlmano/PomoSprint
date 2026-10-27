"""Strictly local Auth confirmation for simulator integration tests.

This helper never accepts a server URL from its caller, never follows redirects,
and never includes mail contents or tokens in an error message.
"""

import html
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser

MAILPIT_URL = "http://127.0.0.1:54324"
VERIFY_URL = "http://127.0.0.1:54321/auth/v1/verify"
EMAIL_RE = re.compile(r"^[a-z0-9][a-z0-9._+-]{0,120}@pomosprint\.local$")
MESSAGE_ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,100}$")
TOKEN_RE = re.compile(r"^[A-Za-z0-9_-]{16,512}$")
MAX_RESPONSE = 2 * 1024 * 1024


class ConfirmationError(Exception):
    """A fixed, token-free error code safe for a local test log."""


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def normalize_email(email):
    if not isinstance(email, str) or not EMAIL_RE.fullmatch(email):
        raise ConfirmationError("invalid_local_recipient")
    return email


def _is_recipient(message, email):
    recipients = message.get("To")
    return isinstance(recipients, list) and any(
        isinstance(item, dict)
        and isinstance(item.get("Address"), str)
        and item["Address"].casefold() == email.casefold()
        for item in recipients
    )


def _safe_return_url(url):
    parsed = urllib.parse.urlsplit(url)
    return (
        parsed.scheme == "http"
        and parsed.netloc == "127.0.0.1:3000"
        and parsed.path in ("", "/", "/confirmed")
        and not parsed.username
        and not parsed.password
    )


def validate_verify_url(url):
    """Validate a mail link and return a canonical local-only request URL."""
    if not isinstance(url, str) or len(url) > 4096 or any(ord(c) < 32 for c in url):
        raise ConfirmationError("invalid_confirmation_link")
    try:
        parsed = urllib.parse.urlsplit(html.unescape(url))
        query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True, strict_parsing=True)
    except (ValueError, TypeError):
        raise ConfirmationError("invalid_confirmation_link") from None
    if (
        parsed.scheme != "http"
        or parsed.netloc != "127.0.0.1:54321"
        or parsed.path != "/auth/v1/verify"
        or parsed.fragment
        or parsed.username
        or parsed.password
        or set(query) - {"token", "type", "redirect_to"}
        or query.get("type") != ["signup"]
        or len(query.get("token", [])) != 1
        or not TOKEN_RE.fullmatch(query["token"][0])
        or ("redirect_to" in query and (
            len(query["redirect_to"]) != 1 or not _safe_return_url(query["redirect_to"][0])
        ))
    ):
        raise ConfirmationError("invalid_confirmation_link")
    # A token can only be sent to this literal address, regardless of mail input.
    return VERIFY_URL + "?" + urllib.parse.urlencode({k: v[0] for k, v in query.items()})


class _Links(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.links = []

    def handle_starttag(self, tag, attrs):
        if tag == "a":
            self.links.extend(value for key, value in attrs if key == "href" and value)


def confirmation_link(message, email):
    """Never use another recipient's message, even when the list was filtered."""
    normalize_email(email)
    if not isinstance(message, dict) or not _is_recipient(message, email):
        raise ConfirmationError("recipient_mismatch")
    parser = _Links()
    try:
        parser.feed(message.get("HTML") or "")
    except (TypeError, ValueError):
        raise ConfirmationError("invalid_mail_content") from None
    text = message.get("Text") or ""
    links = parser.links + (re.findall(r"https?://[^\s<>\"']+", text) if isinstance(text, str) else [])
    for link in links:
        try:
            return validate_verify_url(link)
        except ConfirmationError:
            continue
    raise ConfirmationError("confirmation_link_not_found")


def _open_json(url, timeout):
    opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))
    try:
        with opener.open(url, timeout=timeout) as response:
            raw = response.read(MAX_RESPONSE + 1)
            if len(raw) > MAX_RESPONSE:
                raise ConfirmationError("mailpit_response_too_large")
            return json.loads(raw)
    except ConfirmationError:
        raise
    except (OSError, ValueError, urllib.error.HTTPError):
        raise ConfirmationError("mailpit_unavailable") from None


def _verify(link, timeout):
    # Do not permit proxy environment settings or an external redirect request.
    opener = urllib.request.build_opener(_NoRedirect(), urllib.request.ProxyHandler({}))
    try:
        with opener.open(validate_verify_url(link), timeout=timeout):
            raise ConfirmationError("unexpected_confirmation_response")
    except urllib.error.HTTPError as response:
        try:
            location = response.headers.get("Location", "")
            if response.code not in (302, 303) or not _safe_return_url(location):
                raise ConfirmationError("confirmation_rejected")
            parsed = urllib.parse.urlsplit(location)
            query = urllib.parse.parse_qs(parsed.query)
            fragment = urllib.parse.parse_qs(parsed.fragment)
            if "error" in query or "error" in fragment or not fragment.get("access_token"):
                raise ConfirmationError("confirmation_rejected")
            return True
        finally:
            response.close()
    except ConfirmationError:
        raise
    except (OSError, ValueError):
        raise ConfirmationError("confirmation_unavailable") from None


def confirm_local_email(email, timeout=15.0):
    email = normalize_email(email)
    # Even internal callers cannot turn this into an unbounded mailbox poll.
    deadline = time.monotonic() + min(max(float(timeout), 0.1), 15.0)
    while time.monotonic() < deadline:
        remaining = deadline - time.monotonic()
        listing = _open_json(MAILPIT_URL + "/api/v1/messages?limit=100", min(2.0, remaining))
        messages = listing.get("messages", []) if isinstance(listing, dict) else []
        if not isinstance(messages, list):
            raise ConfirmationError("invalid_mailpit_response")
        for message in messages:
            if not isinstance(message, dict) or not _is_recipient(message, email):
                continue
            message_id = message.get("ID")
            if not isinstance(message_id, str) or not MESSAGE_ID_RE.fullmatch(message_id):
                continue
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            detail = _open_json(MAILPIT_URL + "/api/v1/message/" + message_id, min(2.0, remaining))
            try:
                link = confirmation_link(detail, email)
            except ConfirmationError:
                continue
            return _verify(link, min(3.0, max(0.1, deadline - time.monotonic())))
        time.sleep(min(0.2, max(0.0, deadline - time.monotonic())))
    raise ConfirmationError("confirmation_mail_timeout")
