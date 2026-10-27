#!/usr/bin/env python3
"""Safe parser/host checks; --live also proves local signup → Mailpit → login."""

import io
import json
from contextlib import redirect_stderr
from pathlib import Path
import subprocess
import sys
import threading
import unittest
import urllib.error
import urllib.parse
import urllib.request
from unittest.mock import patch
from uuid import uuid4

import e2e_host
import local_mailpit as mail

LIVE = "--live" in sys.argv
if LIVE:
    sys.argv.remove("--live")
TOKEN = "a" * 64
LINK = mail.VERIFY_URL + "?token=" + TOKEN + "&type=signup&redirect_to=http%3A%2F%2F127.0.0.1%3A3000"
EMAIL = "qa-mailpit-unit@pomosprint.local"


def message(email=EMAIL, link=LINK):
    return {"To": [{"Address": email}], "HTML": '<a href="' + link.replace("&", "&amp;") + '">Confirm</a>'}


class LinkTests(unittest.TestCase):
    def test_local_html_link(self):
        self.assertEqual(mail.confirmation_link(message(), EMAIL), LINK)

    def test_plain_text_link(self):
        self.assertEqual(mail.confirmation_link({"To": [{"Address": EMAIL}], "Text": LINK}, EMAIL), LINK)

    def test_wrong_recipient(self):
        with self.assertRaisesRegex(mail.ConfirmationError, "recipient_mismatch"):
            mail.confirmation_link(message("other@pomosprint.local"), EMAIL)

    def test_nonlocal_recipient(self):
        for email in ("user@example.com", "a@pomosprint.local.evil", "a\n@pomosprint.local", None):
            with self.subTest(email=email), self.assertRaises(mail.ConfirmationError):
                mail.normalize_email(email)

    def test_wrong_origin_or_path(self):
        for url in (
            LINK.replace("127.0.0.1", "localhost", 1),
            LINK.replace("127.0.0.1:54321", "example.com"),
            LINK.replace("http:", "https:", 1),
            LINK.replace(":54321", ":54322", 1),
            LINK.replace("/auth/v1/verify", "/auth/v1/../verify"),
            LINK.replace("/auth/v1/verify", "/auth/v1/verify/"),
            LINK.replace("127.0.0.1:54321", "user@127.0.0.1:54321"),
            LINK.replace("127.0.0.1:54321", "127.0.0.1:54321.evil"),
        ):
            with self.subTest(origin=url.split("?")[0]), self.assertRaises(mail.ConfirmationError):
                mail.validate_verify_url(url)

    def test_wrong_query_or_remote_return(self):
        for url in (
            LINK.replace("type=signup", "type=recovery"),
            LINK + "&token=" + TOKEN,
            LINK + "&type=signup",
            LINK + "&unknown=x",
            LINK + "#fragment",
            LINK.replace("127.0.0.1%3A3000", "example.com"),
            LINK.replace(TOKEN, "x"),
        ):
            with self.subTest(case=url.replace(TOKEN, "[redacted]")), self.assertRaises(mail.ConfirmationError):
                mail.validate_verify_url(url)

    def test_redirect_is_not_followed(self):
        self.assertIsNone(mail._NoRedirect().redirect_request(None, None, 302, "", {}, "https://example.com"))

    def test_success_redirect_does_not_expose_token(self):
        location = "http://127.0.0.1:3000/#access_token=do-not-log&token_type=bearer&type=signup"
        error = urllib.error.HTTPError(LINK, 302, "Found", {"Location": location}, io.BytesIO())
        with patch.object(urllib.request, "build_opener") as opener:
            opener.return_value.open.side_effect = error
            self.assertTrue(mail._verify(LINK, 1))
            self.assertEqual(opener.return_value.open.call_count, 1)

    def test_external_or_error_redirect_rejected(self):
        for location in ("https://example.com/#access_token=x", "http://127.0.0.1:3000/#error=expired", ""):
            error = urllib.error.HTTPError(LINK, 302, "Found", {"Location": location}, io.BytesIO())
            with self.subTest(location=location), patch.object(urllib.request, "build_opener") as opener:
                opener.return_value.open.side_effect = error
                with self.assertRaisesRegex(mail.ConfirmationError, "confirmation_rejected"):
                    mail._verify(LINK, 1)
                self.assertEqual(opener.return_value.open.call_count, 1)

    def test_polls_only_matching_recipient(self):
        with patch.object(mail, "_open_json", side_effect=[
            {"messages": [{"ID": "skip", "To": [{"Address": "other@pomosprint.local"}]},
                          {"ID": "safe-id", "To": [{"Address": EMAIL}]}]}, message()
        ]) as fetch, patch.object(mail, "_verify", return_value=True) as verify:
            self.assertTrue(mail.confirm_local_email(EMAIL))
            self.assertEqual(fetch.call_count, 2)
            self.assertEqual(fetch.call_args_list[1].args[0], mail.MAILPIT_URL + "/api/v1/message/safe-id")
            self.assertEqual(verify.call_count, 1)

    def test_malformed_message_id_never_requested(self):
        with patch.object(mail, "_open_json", return_value={"messages": [
            {"ID": "../../remote", "To": [{"Address": EMAIL}]}
        ]}) as fetch:
            with self.assertRaisesRegex(mail.ConfirmationError, "confirmation_mail_timeout"):
                mail.confirm_local_email(EMAIL, timeout=.1)
            self.assertTrue(all(call.args[0] == mail.MAILPIT_URL + "/api/v1/messages?limit=100" for call in fetch.call_args_list))


class HostTests(unittest.TestCase):
    def setUp(self):
        self.server = e2e_host.ThreadingHTTPServer(("127.0.0.1", 0), e2e_host.Handler)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.url = "http://127.0.0.1:" + str(self.server.server_port) + "/confirm-email"

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()

    def post(self, body, suffix="", content_type="application/json"):
        request = urllib.request.Request(self.url + suffix, data=body, headers={"Content-Type": content_type})
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                return response.status, json.load(response)
        except urllib.error.HTTPError as response:
            return response.code, json.load(response)

    def test_only_email_json_body(self):
        with patch.object(e2e_host, "confirm_local_email", return_value=True) as confirm:
            status, result = self.post(json.dumps({"email": EMAIL}).encode())
            self.assertEqual((status, result), (200, {"confirmed": True}))
            confirm.assert_called_once_with(EMAIL)

    def test_bad_body_never_calls_mailpit(self):
        with patch.object(e2e_host, "confirm_local_email") as confirm:
            for body, suffix, mime in (
                (b"{}", "", "application/json"),
                (b"{bad}", "", "application/json"),
                (b"[]", "", "application/json"),
                (json.dumps({"email": EMAIL, "url": LINK}).encode(), "", "application/json"),
                (json.dumps({"email": EMAIL}).encode(), "?token=redacted", "application/json"),
                (json.dumps({"email": EMAIL}).encode(), "", "text/plain"),
                (b"x" * 513, "", "application/json"),
            ):
                with self.subTest(mime=mime, suffix=suffix):
                    status, result = self.post(body, suffix, mime)
                    self.assertEqual(status, 400)
                    self.assertFalse(result["confirmed"])
            confirm.assert_not_called()

    def test_device_selection_required(self):
        script = str(Path(e2e_host.__file__).resolve())
        for args in ([], ["--udid", "bad"], ["--android-serial", "physical-id"],
                     ["--udid", str(uuid4()), "--android-serial", "emulator-5554"]):
            with self.subTest(args=args):
                process = subprocess.run([sys.executable, script, *args], capture_output=True, timeout=5)
                self.assertEqual(process.returncode, 2)

    def test_query_token_is_never_logged(self):
        captured = io.StringIO()
        with redirect_stderr(captured):
            status, result = self.post(json.dumps({"email": EMAIL}).encode(), "?token=secret-query-token")
        self.assertEqual(status, 400)
        self.assertNotIn("secret-query-token", captured.getvalue())
        self.assertNotIn("secret-query-token", json.dumps(result))


@unittest.skipUnless(LIVE, "Use --live for local Supabase/Mailpit integration")
class RealMailpitTests(HostTests):
    # Do not repeat unit checks through inheritance.
    test_only_email_json_body = None
    test_bad_body_never_calls_mailpit = None
    test_device_selection_required = None
    test_query_token_is_never_logged = None

    def test_real_signup_confirm_login(self):
        sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
        import local_api as api
        self.assertEqual(api.API_URL, "http://127.0.0.1:54321")
        email = "qa-mailpit-" + uuid4().hex + "@pomosprint.local"
        uid = None
        account = None
        try:
            response = api.sign_up(email, "QA Mailpit")
            uid = (response.get("user") or response)["id"]
            self.assertFalse(response.get("access_token"))
            with self.assertRaises(api.ApiError) as denied:
                api.sign_in(email)
            self.assertEqual(denied.exception.body["error_code"], "email_not_confirmed")
            status, response = self.post(json.dumps({"email": email}).encode())
            self.assertEqual((status, response), (200, {"confirmed": True}))
            account = api.sign_in(email)
            self.assertEqual(account["user"]["id"], uid)
            self.assertIsNotNone(account["user"]["email_confirmed_at"])
        finally:
            if account:
                api.rpc("delete_own_account", token=account["access_token"])
            elif uid:
                # Only this newly-created local fixture, never an existing user.
                canonical_uid = str(__import__("uuid").UUID(uid))
                subprocess.run(["docker", "exec", "supabase_db_pomosprint-local", "psql", "-U", "postgres", "-d", "postgres", "-v", "ON_ERROR_STOP=1", "-c",
                    "delete from auth.users where id='" + canonical_uid + "'::uuid;"], check=True, capture_output=True, timeout=10)


if __name__ == "__main__":
    suite = unittest.defaultTestLoader.loadTestsFromModule(sys.modules[__name__])
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    target = Path(e2e_host.ROOT) / "build/overnight_backend/mailpit_helper_results.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps({
        "tests_run": result.testsRun,
        "failures": len(result.failures),
        "errors": len(result.errors),
        "skipped": len(result.skipped),
        "local_signup_confirm_login": LIVE,
        "successful": result.wasSuccessful(),
    }, indent=2) + "\n")
    sys.exit(0 if result.wasSuccessful() else 1)
