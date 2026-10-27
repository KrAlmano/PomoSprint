#!/usr/bin/env python3
"""Prepare ONLY the explicitly named local Docker database; no remote credentials.

This uses the checked-in snapshot and individually reviewed historical packages.
It deliberately applies only waitlist package 19A, not the unshipped 19B policy.
No .env file is opened. Never use this against a hosted database.
"""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
CONTAINER = "supabase_db_pomosprint-local"
PACKAGES = [
    "supabase/proposed/12_delete_own_account.sql",
    "supabase/proposed/15_monthly_leaderboard_study_month.sql",
    "supabase/proposed/16_categories_order_and_privileges.sql",
    "supabase/proposed/19_waitlist_consent_token.sql",
    "supabase/proposed/13_sunucu_butunluk.sql",
    "supabase/proposed/14_gizlilik_sosyal.sql",
    *[f"supabase/proposed/{name}.sql" for name in (
        "20_lig_donemi", "21_seans_kilit_gec_bonus", "22_avatar_satin_alma",
        "23_kategori_butunluk", "24_onboarding_profil", "25_sosyal_erisim",
        "26_segment_genisletme")],
    "supabase/migrations/20261007150000_marathon_break_presence.sql",
    "supabase/migrations/20261007160000_marathon_rewards.sql",
    "supabase/migrations/20261007170000_marathon_presence_confirmation.sql",
    "supabase/migrations/20261007110000_report_submission_lock.sql",
    "supabase/migrations/20261008190000_league_launch_policy.sql",
    "supabase/migrations/20261009190000_special_avatar_catalog.sql",
    "supabase/migrations/20261009233000_remove_unowned_ronin.sql",
]

def sql(body: str) -> str:
    result = subprocess.run(["docker", "exec", "-i", CONTAINER, "psql", "-U",
        "postgres", "-d", "postgres", "-XqAt", "-v", "ON_ERROR_STOP=1"],
        input=body, text=True, capture_output=True)
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()

def main() -> None:
    label = subprocess.check_output(["docker", "inspect", "--format",
        '{{ index .Config.Labels "com.supabase.cli.project" }}', CONTAINER], text=True).strip()
    if label != "pomosprint-local":
        raise SystemExit("Refusing non-PomoSprint-local Docker database")
    if sql("select count(*) from auth.users") != "0":
        raise SystemExit("Fresh baseline required: existing local accounts are preserved")
    if sql("select to_regclass('public.league_competition_state') is not null") == "t":
        raise SystemExit("Baseline already prepared; do not reapply historical packages")
    for relative in PACKAGES:
        if relative.endswith("20261009233000_remove_unowned_ronin.sql"):
            # The public catalog fixture uses the historical installation time
            # so the reviewed deletion guard is exercised without weakening it.
            sql("UPDATE public.avatars SET created_at='2026-10-09T19:25:05.402775+00:00' WHERE id LIKE 'special_%';")
        text = (ROOT / relative).read_text()
        text = "\n".join(line for line in text.splitlines() if not line.startswith("\\"))
        if relative.endswith("19_waitlist_consent_token.sql"):
            text = text.split("-- B) Yalnızca onaylı kayıt")[0]
        sql(text)
        print("Applied local package:", relative, flush=True)
    print("Local baseline ready:", sql("select jsonb_build_object('avatars',(select count(*) from public.avatars),'users',(select count(*) from auth.users),'sessions',(select count(*) from public.study_sessions))"))

if __name__ == "__main__":
    main()
