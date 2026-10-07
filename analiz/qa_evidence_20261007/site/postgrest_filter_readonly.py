#!/usr/bin/env python3
"""Local API GET-only proof; never outputs keys, emails or response rows."""
import json
import re
import subprocess
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
status = subprocess.run(
    ["supabase", "status", "--workdir", "tool/local_supabase", "--output", "json"],
    cwd=ROOT, capture_output=True, text=True, check=True,
)
config = json.loads(status.stdout)
base = config["API_URL"]
assert base.startswith("http://127.0.0.1:") or base.startswith("http://localhost:"), "local API only"
key = config["SERVICE_ROLE_KEY"]

def read(query):
    url = base + "/rest/v1/marketing_subscribers?" + urllib.parse.urlencode(query)
    req = urllib.request.Request(url, headers={
        "apikey": key, "Authorization": "Bearer " + key, "Prefer": "count=exact",
    }, method="GET")
    with urllib.request.urlopen(req, timeout=10) as res:
        count = int(res.headers["Content-Range"].rsplit("/", 1)[1])
        return {"status": res.status, "count": count}, json.load(res)

def literal_regex(value):
    return "^" + re.sub(r"[.*+?^${}()|\[\]\\]", lambda m: "\\" + m.group(), value) + "$"

results = {}
results["all_rows"], rows = read({"select": "email", "limit": "1"})
assert results["all_rows"]["count"] > 0, "need an existing local QA subscriber"
results["ilike_star_alias"], _ = read({"select": "id", "email": "ilike.*", "limit": "0"})
results["imatch_literal_star"], _ = read({"select": "id", "email": "imatch." + literal_regex("*"), "limit": "0"})
results["imatch_literal_metacharacters"], _ = read({
    "select": "id", "email": "imatch." + literal_regex("qa_%*+[x]\\@example.invalid"), "limit": "0",
})
results["imatch_existing_case_variant"], _ = read({
    "select": "id", "email": "imatch." + literal_regex(rows[0]["email"].swapcase()), "limit": "0",
})
assert results["ilike_star_alias"]["count"] == results["all_rows"]["count"]
assert results["imatch_literal_star"]["count"] == 0
assert results["imatch_literal_metacharacters"]["count"] == 0
assert results["imatch_existing_case_variant"]["count"] == 1
results["method"] = "GET only; no mutations or mail"
results["result"] = "pass"
output = Path(__file__).with_suffix(".json")
output.write_text(json.dumps(results, indent=2) + "\n")
print(json.dumps(results))
