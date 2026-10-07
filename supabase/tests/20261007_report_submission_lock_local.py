"""Two-connection report RPC races against an isolated local PostgREST clone.

Create with CHAIN_DB=pomosprint_report_qa_20261007 UNTIL=0 KEEP_DB=1
REST_PORT=54351 tool/local_supabase/proposed_chain_check.sh.
Copy the main local ops schema definitions into the clone too (handle_new_user
references ops.neutral_display_name; the generic clone helper excludes ops).
Run --expect baseline, apply the prepared migration only to this clone,
then run --expect fixed. The main local database and production are never used.
A temporary SHARE lock holds both INSERTs to force the problematic interleaving.
No sleeps are added to the product function and JWTs are never printed.
"""

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import hmac
import json
from pathlib import Path
import subprocess
import threading
import time
import urllib.error
import urllib.request
import uuid

DB_NAME = "pomosprint_report_qa_20261007"
DB = "postgresql://postgres:postgres@127.0.0.1:54322/" + DB_NAME
REST = "http://127.0.0.1:54351"
CONTAINER = DB_NAME + "_rest"


def sql(query):
    return subprocess.check_output(
        ["psql", DB, "-XAtq", "-v", "ON_ERROR_STOP=1", "-c", query], text=True
    ).strip()


env = json.loads(subprocess.check_output(["docker", "inspect", CONTAINER]))[0]["Config"]["Env"]
secret = next(value.split("=", 1)[1] for value in env if value.startswith("PGRST_JWT_SECRET="))
header = {"alg": "HS256", "typ": "JWT"}
if secret.startswith("{"):
    key = next(key for key in json.loads(secret)["keys"] if key["kty"] == "oct")
    secret_bytes = base64.urlsafe_b64decode(key["k"] + "=" * (-len(key["k"]) % 4))
    if key.get("kid"):
        header["kid"] = key["kid"]
else:
    secret_bytes = secret.encode()


def jwt(owner=None, role="authenticated"):
    def encode(value):
        return base64.urlsafe_b64encode(value).rstrip(b"=")
    claims = {"role": role, "exp": int(time.time()) + 3600}
    if owner is not None:
        claims["sub"] = owner
    payload = encode(json.dumps(header).encode()) + b"." + encode(json.dumps(claims).encode())
    signature = hmac.new(secret_bytes, payload, hashlib.sha256).digest()
    return (payload + b"." + encode(signature)).decode()


def report(owner, target, role="authenticated"):
    request = urllib.request.Request(
        REST + "/rpc/submit_user_report", method="POST",
        data=json.dumps({"p_target_user_id": target, "p_place": "other", "p_reason": "spam", "p_details": "Local concurrent QA"}).encode(),
        headers={"Authorization": "Bearer " + jwt(owner, role), "Content-Type": "application/json"},
    )
    try:
        response = urllib.request.urlopen(request, timeout=15)
    except urllib.error.HTTPError as error:
        response = error
    with response:
        return {"status": response.status, "body": json.loads(response.read())}


def parallel_reports(owners, targets):
    holder = subprocess.Popen(
        ["psql", DB, "-XAtq", "-v", "ON_ERROR_STOP=1"], stdin=subprocess.PIPE,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    )
    holder.stdin.write("BEGIN; LOCK TABLE public.user_reports IN SHARE MODE; SELECT 'locked';\n")
    holder.stdin.flush()
    assert holder.stdout.readline().strip() == "locked"
    barrier = threading.Barrier(2)
    waits = []

    def call(owner, target):
        barrier.wait(timeout=5)
        return report(owner, target)

    with ThreadPoolExecutor(max_workers=2) as pool:
        futures = [pool.submit(call, owner, target) for owner, target in zip(owners, targets)]
        try:
            deadline = time.monotonic() + 5
            while time.monotonic() < deadline:
                waits = json.loads(sql(
                    "SELECT coalesce(json_agg(wait_event), '[]'::json) FROM pg_stat_activity "
                    f"WHERE datname='{DB_NAME}' AND wait_event_type='Lock' "
                    "AND backend_type='client backend'"
                ))
                if len(waits) == 2:
                    break
                time.sleep(0.05)
            assert len(waits) == 2, "Both real HTTP requests must reach the controlled lock barrier"
        finally:
            holder.stdin.write("COMMIT;\n")
            holder.stdin.flush()
            holder.stdin.close()
            holder.wait(timeout=5)
        responses = [future.result(timeout=15) for future in futures]
    assert holder.returncode == 0
    return responses, sorted(waits)


def count(owner):
    return int(sql(f"SELECT count(*) FROM public.user_reports WHERE reporter_id='{owner}'"))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--expect", choices=["baseline", "fixed"], required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    fixed = args.expect == "fixed"
    owners = [str(uuid.uuid4()) for _ in range(4)]
    targets = [str(uuid.uuid4()) for _ in range(12)]
    users = owners + targets
    values = ",".join(
        f"('{owner}','report-race-{owner}@example.invalid','authenticated','authenticated','{{\"name\":\"Report race QA\"}}'::jsonb)"
        for owner in users
    )
    sql("INSERT INTO auth.users(id,email,aud,role,raw_user_meta_data) VALUES " + values)
    checks = []

    def check(name, ok, observation):
        checks.append({"name": name, "passed": bool(ok), "observation": observation})
        assert ok, name + ": " + json.dumps(observation)

    responses, waits = parallel_reports([owners[0]] * 2, [targets[0]] * 2)
    ids = {r["body"].get("report_id") for r in responses}
    codes = sorted(r["body"].get("code") for r in responses)
    check("same-target concurrent duplicate", count(owners[0]) == (1 if fixed else 2)
          and len(ids) == (1 if fixed else 2) and codes == (["duplicate", "reported"] if fixed else ["reported"] * 2),
          {"rows": count(owners[0]), "unique_response_ids": len(ids), "codes": codes, "wait_events": waits})

    sql("INSERT INTO public.user_reports(reporter_id,target_user_id,place,reason,target_name_snapshot) VALUES " +
        ",".join(f"('{owners[1]}','{target}','other','spam','QA seed')" for target in targets[:9]))
    responses, waits = parallel_reports([owners[1]] * 2, targets[9:11])
    codes = sorted(r["body"].get("code") for r in responses)
    check("nine reports plus two concurrent distinct targets", count(owners[1]) == (10 if fixed else 11)
          and codes == (["rate_limited", "reported"] if fixed else ["reported"] * 2),
          {"rows": count(owners[1]), "codes": codes, "wait_events": waits})

    duplicate = report(owners[1], targets[0])
    check("existing duplicate accepted even at daily cap", duplicate["body"].get("code") == "duplicate"
          and count(owners[1]) == (10 if fixed else 11), {"code": duplicate["body"].get("code")})

    responses, waits = parallel_reports(owners[2:4], [targets[11]] * 2)
    check("different reporters remain independent", all(r["body"].get("code") == "reported" for r in responses)
          and "advisory" not in waits and all(count(owner) == 1 for owner in owners[2:4]),
          {"codes": [r["body"].get("code") for r in responses], "wait_events": waits})

    own = report(owners[0], owners[0])
    check("self report unchanged", own["body"].get("code") == "self", {"code": own["body"].get("code")})
    anon = report(None, targets[0], "anon")
    check("anonymous execute forbidden", anon["status"] in (401, 403) and anon["body"].get("code") == "42501",
          {"status": anon["status"], "code": anon["body"].get("code")})
    no_owner = report(None, targets[0])
    check("authenticated role without uid still rejected", no_owner["status"] == 400
          and no_owner["body"].get("message") == "not authenticated",
          {"status": no_owner["status"], "message": no_owner["body"].get("message")})
    result = {"expect": args.expect, "database": DB_NAME, "real_http": True,
              "controlled_insert_barrier": "Temporary SHARE table lock in isolated QA only",
              "checks": checks, "passed": len(checks), "failed": 0}
    Path(args.output).write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
