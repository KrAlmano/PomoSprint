#!/usr/bin/env python3
"""Read-only parity for the reviewed isolated32 database; never selects main DB.

There is deliberately no capture/update mode and no URL/database override.
The ordinary27-30 parity checker remains unchanged.
"""
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
REFERENCE = HERE / 'parity/reviewed_exam32_dus_20261028.json'
DATABASE = 'pomosprint_review32_dus'
PROFILE_DATABASES = {'review': 'pomosprint_review32_dus', 'site': 'pomosprint_site32_dus'}
REFERENCE_ID = 'reviewed-isolated-exam32-dus-20261028-proportional'


def sql(statement):
    psql = shutil.which('psql')
    if not psql:
        raise ValueError('psql unavailable')
    dsn = ('host=127.0.0.1 port=54322 user=postgres password=postgres '
           f'dbname={DATABASE} connect_timeout=5 sslmode=disable')
    result = subprocess.run(
        [psql, dsn, '-XqAt', '-F', '\t', '-v', 'ON_ERROR_STOP=1'],
        input="BEGIN READ ONLY; SET LOCAL statement_timeout='15s'; " + statement + '; COMMIT;',
        env={'PATH': str(Path(psql).parent) + ':/usr/bin:/bin', 'PGPASSFILE': '/dev/null', 'PGTZ': 'UTC'},
        text=True, capture_output=True, timeout=20,
    )
    if result.returncode:
        raise ValueError('isolated32 read-only query failed')
    return result.stdout.strip()


def differences(expected, observed):
    return sorted(key for key in set(expected) | set(observed) if expected.get(key) != observed.get(key))


def verify_sources(reference):
    observed = {}
    for name in reference['sources_sha256']:
        path = ROOT / name
        observed[name] = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None
    return differences(reference['sources_sha256'], observed)


def observe():
    source = (HERE / 'parity/fingerprint_lines.sql').read_text()
    cte = source.rsplit('select k, replace', 1)[0]
    summary = sql(cte + 'select k,count(*),md5(string_agg(line,E\'\\n\' order by line collate "C")) from lines group by k order by k')
    schema = {row.split('\t')[0]: row.split('\t')[1:] for row in summary.splitlines()}
    migrations = sql("select version||'|'||name from supabase_migrations.schema_migrations order by version").splitlines()
    catalog = {
        'avatars': sql("select count(*)||'|'||md5(string_agg(format('%L,%L,%L,%L,%s,%s,%s,%s,%s,%L,%s',id,name_tr,name_en,asset_key,cost_coins,is_premium_only,is_default,sort_order,is_active,created_at,is_league_award),E'\\n' order by id collate \"C\")) from public.avatars"),
        'exam_catalog': sql("select count(*)||'|'||md5(string_agg(id||':'||definition::text||':'||enabled::text,E'\\n' order by id)) from public.exam_catalog"),
        'competition_avatar_rewards': sql("select count(*)||'|'||md5(string_agg(kind||':'||tier||':'||rank_position||':'||coalesce(avatar_id,'<null>'),E'\\n' order by kind,tier,rank_position)) from public.competition_avatar_rewards"),
    }
    return {
        'schema': schema, 'migrations': migrations, 'catalog': catalog,
        'mail_trigger': sql("select tgenabled from pg_trigger where tgname='after_insert_marketing_subscribers' and tgrelid='public.marketing_subscribers'::regclass"),
        'policy': json.loads(sql('select jsonb_build_array(early_enabled,early_coin_mode) from public.exam_extension_policy where singleton')),
    }


def main(arguments=None):
    if arguments is None:
        arguments = sys.argv[1:]
    global DATABASE
    if arguments == []:
        profile = 'review'
    elif len(arguments)==2 and arguments[0]=='--profile' and arguments[1] in PROFILE_DATABASES:
        profile = arguments[1]
    else:
        raise ValueError('isolated32 parity accepts only explicit review/site profiles')
    DATABASE = PROFILE_DATABASES[profile]
    reference = json.loads(REFERENCE.read_text())
    if reference.get('reference_id') != REFERENCE_ID or reference.get('database') != PROFILE_DATABASES['review']:
        raise ValueError('unrecognized isolated32 reference')
    changed = verify_sources(reference)
    if changed:
        print('FAIL isolated32 source hashes: ' + ', '.join(changed))
        return 1
    observed = observe()
    changed = differences(reference['expected'], observed)
    for name in reference['expected']:
        print(('FAIL ' if name in changed else 'PASS ') + 'isolated32 ' + name)
    return 1 if changed else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.TimeoutExpired):
        print('FAIL isolated32 parity could not be validated', file=sys.stderr)
        sys.exit(2)
