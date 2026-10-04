#!/usr/bin/env bash
# t4 (lig + madalya/avatar) testlerinin hepsi. Yalnızca YEREL kopya.
# SQL betikleri tamamen ROLLBACK; 05/06 kendi t4- hesabını açıp sonda siler.
# FAIL satırları bulgudur (beklenen davranışı sınar).
set -uo pipefail
PG=postgresql://postgres:postgres@127.0.0.1:54322/postgres
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
cd "$HERE"
for f in 01_zones_ranking.sql 02_process_weekly_leagues.sql 03_league_placement_points.sql 04_avatars.sql 07_period_alignment.sql; do
  psql "$PG" -q -f "$f" 2>&1 | sed -n '/=== t4-/,$p'
done
python3 05_client_contract.py
./06_purchase_race.sh
./08_room_race.sh
psql "$PG" -qAt -f 09_capture_league_fixture.sql > league_fixture.json
cd "$ROOT" && flutter test tool/local_supabase/e2e/t4_league_avatar/t4_league_client_test.dart
