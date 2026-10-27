#!/usr/bin/env python3
"""Direct cross-target Global assertions in a disposable local schema clone.

No Auth/user data is copied. Only the reviewed local schema and an explicit
catalog/config allowlist are read from pomosprint_night_backend. All fixture
writes target a newly created, fixed-name clone which is removed afterwards.
Historical full-duration rows are fixtures, not natural elapsed-time evidence.
"""
from __future__ import annotations

import json
from pathlib import Path
import subprocess
import tempfile
import uuid


ROOT = Path(__file__).resolve().parents[3]
SOURCE_DB = "pomosprint_night_backend"
CLONE_DB = "pomosprint_night_global_scope"
BASE = "postgresql://postgres:postgres@127.0.0.1:54322/"
CONTAINER = "supabase_db_pomosprint-local"
CATALOG_TABLES = (
    "public.avatars", "public.app_config", "public.exam_catalog",
    "public.competition_policy", "public.competition_avatar_rewards",
    "public.marathon_presence_settings", "public.league_competition_state",
)
SNAPSHOT_TABLES = (
    "profiles", "study_sessions", "session_starts", "exam_attempts",
    "exam_subject_results", "exam_wallets", "avatar_unlocks",
    "competition_profiles", "competition_rooms", "competition_memberships",
    "competition_events", "competition_results", "competition_periods",
    "competition_target_history", "competition_avatar_rewards",
    "competition_policy", "marathon_runs", "marathon_run_sessions",
)
CHECKS: list[dict] = []


def command(args: list[str], **kwargs) -> subprocess.CompletedProcess:
    result = subprocess.run(args, text=True, capture_output=True, **kwargs)
    if result.returncode:
        raise RuntimeError(f"{args[0]} failed: {result.stderr.strip()}")
    return result


def query(database: str, body: str) -> str:
    if database not in {SOURCE_DB, CLONE_DB, "postgres"}:
        raise RuntimeError("Database is outside the fixed local allowlist")
    return command(
        ["psql", BASE + database, "-XqAt", "-v", "ON_ERROR_STOP=1"],
        input=body,
    ).stdout.strip()


def literal(value: str) -> str:
    return "'" + value.replace("'", "''") + "'"


def check(name: str, passed: bool) -> None:
    CHECKS.append({"name": name, "ok": bool(passed)})
    print(("PASS " if passed else "FAIL ") + name, flush=True)
    if not passed:
        raise AssertionError(name)


def rpc(owner: str, name: str, args: str) -> dict:
    if name not in {"complete_study_session", "start_exam_attempt",
                    "complete_exam_attempt", "get_monthly_league_ranking"}:
        raise RuntimeError("RPC outside this test's fixed allowlist")
    claims = json.dumps({"sub": owner, "role": "authenticated"})
    return json.loads(query(
        CLONE_DB,
        "begin; set local request.jwt.claims=" + literal(claims)
        + "; set local role authenticated; select public."
        + name + "(" + args + "); commit;",
    ))


def economy_snapshot() -> dict:
    return {
        table: query(
            CLONE_DB,
            "select md5(coalesce(jsonb_agg(to_jsonb(r) order by "
            "to_jsonb(r)::text)::text,'[]')) from public."
            + table + " r;",
        )
        for table in SNAPSHOT_TABLES
    }


def create_fixture(segment: str, index: int) -> str:
    owner, category = str(uuid.uuid4()), str(uuid.uuid4())
    query(CLONE_DB, f"""
        insert into auth.users(id,email,aud,role,raw_user_meta_data,created_at)
        values('{owner}','global-scope-{owner}@pomosprint.local',
               'authenticated','authenticated',
               jsonb_build_object('name','Global {segment} {index}'),now());
        update public.profiles
        set user_segment={literal(segment)},timezone='Europe/Istanbul',
            show_in_social_feed=true where id='{owner}';
        insert into public.categories(id,user_id,name,color_hex)
        values('{category}','{owner}','Matematik','#FF0000');
    """)
    normal = rpc(owner, "complete_study_session",
                 f"'{uuid.uuid4()}','{category}',25,false,0,now()-interval '3 hours'")
    check(f"{segment}_{index}_normal_fixture_accepted", normal["total_points"] == 5)
    exam_id = "lgs_verbal" if segment == "lgs" else "tus_basic"
    attempt = rpc(owner, "start_exam_attempt", f"'{uuid.uuid4()}','{exam_id}'")["attempt"]
    # Local fixture time only. Catalog and global clock are never changed.
    query(CLONE_DB, f"""
        update public.exam_attempts
        set started_at=clock_timestamp()
              -make_interval(secs=>(definition->>'duration_seconds')::integer)
              -interval '1 second',
            ends_at=clock_timestamp()-interval '1 second'
        where id='{attempt['id']}' and user_id='{owner}';
    """)
    completed = rpc(owner, "complete_exam_attempt", f"'{attempt['id']}'")["attempt"]
    check(f"{segment}_{index}_exam_fixture_accepted",
          completed["status"] == "completed" and completed["points_earned"] > 0)
    return owner


def run_checks() -> None:
    check("fixed_local_clone_guard", query(CLONE_DB, "select current_database()") == CLONE_DB)
    check("no_user_data_copied", query(CLONE_DB, "select count(*) from auth.users") == "0")
    cohorts = {segment: {create_fixture(segment, i) for i in range(2)}
               for segment in ("lgs", "tus")}
    all_owners = set().union(*cohorts.values())
    check("four_fresh_accounts_only", query(CLONE_DB, "select count(*) from auth.users") == "4")
    before = economy_snapshot()
    for kind in ("study", "exam"):
        for segment, expected_owners in cohorts.items():
            other_owners = all_owners - expected_owners
            for index, owner in enumerate(sorted(expected_owners)):
                scoped = rpc(owner, "get_monthly_league_ranking", f"'{kind}','segment'")
                scoped_ids = {row["id"] for row in scoped["rows"]}
                check(f"{kind}_{segment}_{index}_segment_exact_owners",
                      scoped["segment"] == segment and scoped_ids == expected_owners
                      and not scoped_ids.intersection(other_owners))
                global_result = rpc(owner, "get_monthly_league_ranking", f"'{kind}','global'")
                global_ids = {row["id"] for row in global_result["rows"]}
                check(f"{kind}_{segment}_{index}_global_contains_both_targets",
                      global_ids == all_owners and other_owners.issubset(global_ids))
                check(f"{kind}_{segment}_{index}_global_no_eligibility",
                      all(not row[flag] for row in global_result["rows"]
                          for flag in ("promotion_eligible", "award_eligible", "demotion_eligible")))
                check(f"{kind}_{segment}_{index}_reads_do_not_mutate_economy",
                      economy_snapshot() == before)
    check("all_reads_preserve_all_economy_and_competition_rows", economy_snapshot() == before)


def main() -> None:
    created = False
    completed = False
    output = ROOT / "build/overnight_backend/global_scope_results.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    if query("postgres", f"select count(*) from pg_database where datname={literal(CLONE_DB)}") != "0":
        raise RuntimeError("Clone already exists; refusing to replace or drop it")
    check("source_is_named_disposable_review_db",
          query(SOURCE_DB, "select current_database()") == SOURCE_DB)
    try:
        with tempfile.TemporaryDirectory(prefix="pomosprint-global-scope-") as directory:
            folder = Path(directory)
            schema = folder / "schema.sql"
            catalogs = folder / "catalogs.sql"
            # Use the server container's matching pg_dump version (host brew
            # may be older). Plain SQL crosses no Docker filesystem boundary.
            dump = ["docker", "exec", CONTAINER, "pg_dump", "-U", "postgres",
                    "-d", SOURCE_DB]
            schema_text = command([*dump, "--schema-only",
                                   "--schema=public", "--schema=auth", "--schema=ops",
                                   "--schema=supabase_migrations", "--schema=cron",
                                   "--schema=extensions"]).stdout
            schema.write_text("\n".join(line for line in schema_text.splitlines()
                                        if line not in {"CREATE SCHEMA public;", "CREATE SCHEMA extensions;"}) + "\n")
            catalogs.write_text(command([*dump, "--data-only",
                                          *["--table=" + table for table in CATALOG_TABLES]]).stdout)
            query("postgres", f'create database "{CLONE_DB}" owner postgres')
            created = True
            # Preserve original definer owners/ACLs using the container's local
            # administrator; do not weaken schema permissions for the test.
            restore = ["docker", "exec", "-i", CONTAINER, "psql", "-U",
                       "supabase_admin", "-d", CLONE_DB, "-XqAt", "-v", "ON_ERROR_STOP=1"]
            command(restore, input='CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions;')
            command(restore, input=schema.read_text())
            command(restore, input=catalogs.read_text())
            # This test sends no mail; do not execute the unrelated newsletter hook.
            command(restore, input="alter table auth.users disable trigger on_auth_user_confirmed_newsletter")
            run_checks()
            completed = True
    finally:
        if created:
            # No FORCE: only a clone created by this invocation can be dropped.
            query("postgres", f'drop database "{CLONE_DB}"')
            check("owned_clone_removed", query("postgres", f"select count(*) from pg_database where datname={literal(CLONE_DB)}") == "0")
        result = {
            "source": SOURCE_DB, "clone": CLONE_DB,
            "completed": completed,
            "copied_user_data": False, "scope": "Local schema clone; four new accounts; historical standard-duration fixtures; no natural elapsed-time claim",
            "checks": CHECKS, "passed": sum(item["ok"] for item in CHECKS),
            "total": len(CHECKS),
        }
        output.write_text(json.dumps(result, indent=2) + "\n")
    print(f"RESULT {sum(item['ok'] for item in CHECKS)}/{len(CHECKS)}", flush=True)


if __name__ == "__main__":
    main()
