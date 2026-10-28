#!/usr/bin/env python3
"""Read-only parity against the reviewed 27/28/29 LOCAL candidate, not live.

No capture/update-reference command is provided. Updating this reference needs
review of the SQL, rollback and QA results, not an automatic new baseline.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REFERENCE = HERE / "parity/reviewed_night_20261028.json"
ATOMIC_REFERENCE = HERE / "parity/reviewed_night_20261028_start_atomic.json"
MARATHON_REFERENCE = HERE / "parity/reviewed_night_20261028_marathon_anchor.json"
LOCAL_URL = "postgresql://postgres:postgres@127.0.0.1:54322/postgres"


def local_url():
    value = os.environ.get("LOCAL_DB_URL", LOCAL_URL)
    if value != LOCAL_URL:
        raise ValueError("reviewed parity only accepts the fixed local database on 127.0.0.1:54322")
    return value


def sql(body):
    process = subprocess.run(
        ["psql", local_url(), "-XqAt", "-F", "\t", "-v", "ON_ERROR_STOP=1", "-c", body],
        text=True, capture_output=True, timeout=20,
        env={**os.environ, "PGOPTIONS": "-c default_transaction_read_only=on", "PGTZ": "UTC"},
    )
    if process.returncode:
        raise ValueError("local read-only parity query failed")
    return process.stdout.strip()


def differences(reference, observed):
    return [name for name in sorted(set(reference) | set(observed)) if reference.get(name) != observed.get(name)]


def reference_for(arguments):
    if arguments == []:
        return REFERENCE, "reviewed-local-night-20261028", "27/28/29"
    if arguments == ["--with-session-start-atomic"]:
        return ATOMIC_REFERENCE, "reviewed-local-night-20261028-start-atomic", "27/28/29 + 30"
    if arguments == ["--with-marathon-anchor"]:
        return MARATHON_REFERENCE, "reviewed-local-night-20261028-marathon-anchor", "27/28/29 + 30 + 31 (unpaused anchor; paused limitation remains)"
    raise ValueError("unknown reviewed parity mode")


def verify_sources(reference):
    observed = {}
    for name in reference["sources_sha256"]:
        path = ROOT / name
        observed[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    return differences(reference["sources_sha256"], observed)


def observe():
    source = (HERE / "parity/fingerprint_lines.sql").read_text()
    cte = source.rsplit("select k, replace", 1)[0]
    summary = sql(cte + "select k,count(*),md5(string_agg(line,E'\\n' order by line collate \"C\")) from lines group by k order by k;")
    schema = {row.split("\t")[0]: row.split("\t")[1:] for row in summary.splitlines()}
    migrations = sql("select version||'|'||name from supabase_migrations.schema_migrations order by version;").splitlines()
    catalog = {
        "avatars": sql("select count(*)||'|'||md5(string_agg(format('%L,%L,%L,%L,%s,%s,%s,%s,%s,%L,%s', id,name_tr,name_en,asset_key,cost_coins,is_premium_only,is_default,sort_order,is_active,created_at,is_league_award),E'\\n' order by id collate \"C\")) from public.avatars;"),
        "exam_catalog": sql("select count(*)||'|'||md5(string_agg(id||':'||definition::text||':'||enabled::text,E'\\n' order by id)) from public.exam_catalog;"),
        "competition_avatar_rewards": sql("select count(*)||'|'||md5(string_agg(kind||':'||tier||':'||rank_position||':'||coalesce(avatar_id,'<null>'),E'\\n' order by kind,tier,rank_position)) from public.competition_avatar_rewards;"),
    }
    safe_mail = sql("select tgenabled from pg_trigger where tgname='after_insert_marketing_subscribers' and tgrelid='public.marketing_subscribers'::regclass;")
    return {"schema": schema, "migrations": migrations, "catalog": catalog, "mail_trigger": safe_mail}


def main():
    local_url()  # Validate before any subprocess or database request.
    path, reference_id, packages = reference_for(sys.argv[1:])
    reference = json.loads(path.read_text())
    if reference.get("reference_id") != reference_id:
        raise ValueError("unrecognized reviewed reference")
    changed = verify_sources(reference)
    if changed:
        for name in changed:
            print("FAIL reviewed SQL/source hash:", name)
        return 1
    print("PASS reviewed SQL/source SHA-256")
    observed = observe()
    changed = differences(reference["expected"], observed)
    for name in reference["expected"]:
        print(("FAIL" if name in changed else "PASS") + " reviewed local " + name)
        if name == "schema" and name in changed:
            print("Changed schema categories:", ", ".join(differences(reference["expected"]["schema"], observed["schema"])))
    if changed:
        print("FAIL: local candidate differs from reviewed " + packages + " reference")
        return 1
    print("PASS: reviewed local " + packages + " candidate; this is NOT live parity")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired):
        print("FAIL: reviewed local parity could not be validated", file=sys.stderr)
        sys.exit(2)
