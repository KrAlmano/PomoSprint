-- t4-07: dönem hizası. (a) Terfi eden, dönemi YARIYA gelmiş (1 hafta kalmış)
-- üst kademe odasına 0 puanla girer → hemen düşme bölgesinde. (b) Dönem
-- sınırından önce biten ama cron'dan sonra gönderilen seans yeni döneme
-- yazılır. TAMAMI ROLLBACK.
-- psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f 07_period_alignment.sql
\set ON_ERROR_STOP on
\pset pager off
begin;
\i _helpers.sql
\o /dev/null

create temp table t4_u(tag text primary key, id uuid, cat uuid) on commit drop;
grant select on t4_u to authenticated;
create temp table t4_l(tag text primary key, id uuid) on commit drop;
create temp table t4_e as
-- Use a just-closed synthetic period so the late session remains inside
-- complete_study_session's 24h acceptance window on every weekday.
select now() - interval '1 minute' as e;

do $$
declare e timestamptz := (select e from t4_e); l uuid; u uuid; i int;
begin
  -- T2: tier-2 odası, bitişine 1 hafta var (öbür hafta paritesinde açılmış), 12 üye 10..120 puan
  l := pg_temp.t4_league(2, '2000-01-01', e + interval '7 days'); insert into t4_l values ('T2', l);
  for i in 1..12 loop
    u := pg_temp.t4_user('t' || i, 2);
    perform pg_temp.t4_member(l, u, 10 * i, now() - interval '7 days' + make_interval(mins => i));
  end loop;
  -- T1: tier-1 odası, şimdi biten; 3 aktif üye → n=3 terfi 2 (p1, p2)
  l := pg_temp.t4_league(1, '2000-01-01', e); insert into t4_l values ('T1', l);
  for i in 1..3 loop
    u := pg_temp.t4_user('p' || i, 1);
    insert into t4_u values ('p' || i, u, pg_temp.t4_category(u));
    perform pg_temp.t4_member(l, u, 30 - i, now() - interval '13 days');
  end loop;
end $$;

select public.process_weekly_leagues();

select pg_temp.t4_as((select id from t4_u where tag = 'p1'));
set local role authenticated;
create temp table t4_rank as select row_number() over () pos, r.* from public.get_my_league_ranking() r;
reset role;
select pg_temp.t4_check('(a) Terfi eden p1 yeni (tier 2) odasında tam 14 günlük dönemle başlamalı',
  (select end_date from t4_rank limit 1) - now() > interval '13 days',
  (select format('oda bitişi %s TR (kalan %s); p1 sıra %s/%s, 0 puan; bölge promo<=%s demo>=%s → istemci: %s',
     (end_date at time zone 'Europe/Istanbul')::text, date_trunc('minute', end_date - now()), pos, member_count, promotion_zone_end,
     demotion_zone_start, case when pos >= demotion_zone_start then 'DÜŞME BÖLGESİ' else 'güvenli' end)
   from t4_rank where is_me));

-- (b) Sınırdan önce biten seans, cron'dan sonra gönderiliyor (çevrimdışı kuyruk)
do $$
declare r jsonb; u record; before int; after int; e timestamptz := (select e from t4_e);
begin
  select * into u from t4_u where tag = 'p3';
  before := pg_temp.t4_points_of(u.id);
  perform pg_temp.t4_as(u.id);
  set local role authenticated;
  r := public.complete_study_session(gen_random_uuid(), u.cat, 25, false, 0, e - interval '35 minutes');
  reset role;
  after := pg_temp.t4_points_of(u.id);
  perform pg_temp.t4_check('(b) Önceki dönemde biten seans yeni döneme lig puanı yazmamalı',
    after = before,
    format('seans bitişi %s TR, yeni dönem puanı %s → %s; yanıt %s',
      ((e - interval '10 minutes') at time zone 'Europe/Istanbul')::text, before, after, r));
end $$;

\o
\echo '=== t4-07 sonuçlar ==='
select seq, case when ok then 'OK ' else 'FAIL' end as st, name, detail from t4_results order by seq;
rollback;
