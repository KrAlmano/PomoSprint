-- t4-03: complete_study_session → ensure_user_in_league: odaya yerleşme
-- (kapasite 30, kademe), haftalık puan birikimi, tekrar gönderim, günlük
-- tavan, dönem sınırı (bitmiş ama işlenmemiş oda). TAMAMI ROLLBACK.
-- psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f 03_league_placement_points.sql
\set ON_ERROR_STOP on
\pset pager off
begin;
\i _helpers.sql
\o /dev/null

create temp table t4_u(tag text primary key, id uuid, cat uuid) on commit drop;
grant select on t4_u to authenticated;
create temp table t4_l(tag text primary key, id uuid) on commit drop;
create temp table t4_foreign as
  select tier, count(*) n from public.leagues where is_active group by tier;

-- Oturum gibi RPC çağrısı (authenticated rolü + JWT claim'i).
create function pg_temp.t4_session(p_tag text, p_minutes int, p_paused boolean, p_started timestamptz,
                                   p_uuid uuid default gen_random_uuid())
returns jsonb language plpgsql as $$
declare r jsonb; u record;
begin
  select * into u from t4_u where tag = p_tag;
  perform pg_temp.t4_as(u.id);
  set local role authenticated;
  r := public.complete_study_session(p_uuid, u.cat, p_minutes, p_paused, 0, p_started);
  reset role;
  return r;
end $$;

-- R3: tier-3 odası, 29 üye (en eski start_date → ensure önce bunu seçer)
do $$
declare l uuid; u uuid; i int;
begin
  l := pg_temp.t4_league(3, '2000-01-01', now() + interval '10 days'); insert into t4_l values ('R3', l);
  for i in 1..29 loop
    u := pg_temp.t4_user('m' || i, 3);
    perform pg_temp.t4_member(l, u, i, '2026-01-01');
  end loop;
  foreach i in array array[1,2,3,4] loop
    u := pg_temp.t4_user('n' || i, 3);
    insert into t4_u values ('n' || i, u, pg_temp.t4_category(u));
  end loop;
end $$;

-- A) Yeni kullanıcı n1 (tier 3, odasız) ilk seans → R3 (29 → 30)
create temp table t4_r as select 'n1-s1' k, pg_temp.t4_session('n1', 25, false, now() - interval '26 minutes') r;
select pg_temp.t4_check('A: odasız tier-3 kullanıcı ilk seansla en eski boş tier-3 odasına (R3) girer',
  pg_temp.t4_league_of((select id from t4_u where tag='n1')) = (select id from t4_l where tag='R3')
  and (select count(*) from public.league_memberships where league_id = (select id from t4_l where tag='R3')) = 30,
  (select r::text from t4_r where k = 'n1-s1'));

-- B) n2: R3 dolu (30) → YENİ tier-3 odası; bitiş = ensure formülü
insert into t4_r select 'n2-s1', pg_temp.t4_session('n2', 25, false, now() - interval '26 minutes');
select pg_temp.t4_check('B: oda 30 iken yeni gelen yeni odaya (R3 31 olmaz)',
  pg_temp.t4_league_of((select id from t4_u where tag='n2')) <> (select id from t4_l where tag='R3')
  and (select count(*) from public.league_memberships where league_id = (select id from t4_l where tag='R3')) = 30
  and (select tier from public.leagues where id = pg_temp.t4_league_of((select id from t4_u where tag='n2'))) = 3,
  format('önceden yabancı tier-3 oda: %s', coalesce((select n from t4_foreign where tier = 3), 0)));
select pg_temp.t4_check('B: yeni odanın bitişi = bu haftanın Pazartesi''si + 13 gün 23:59:59 TR (7–14 gün arası)',
  (select end_date from public.leagues where id = pg_temp.t4_league_of((select id from t4_u where tag='n2'))) =
  ((date_trunc('week', (now() at time zone 'Europe/Istanbul')::date::timestamp) + interval '13 days' + time '23:59:59') at time zone 'Europe/Istanbul'),
  (select (end_date at time zone 'Europe/Istanbul')::text from public.leagues where id = pg_temp.t4_league_of((select id from t4_u where tag='n2'))));

-- C) Birikim: n1 → +12 (50 dk) +4 (25 dk duraklatılmış) → 5+12+4 = 21
insert into t4_r select 'n1-s2', pg_temp.t4_session('n1', 50, false, now() - interval '80 minutes');
insert into t4_r select 'n1-s3', pg_temp.t4_session('n1', 25, true, now() - interval '120 minutes');
select pg_temp.t4_check('C: weekly_points = RPC total_points toplamı (5+12+4=21) = lifetime_points',
  pg_temp.t4_points_of((select id from t4_u where tag='n1')) = 21
  and (select sum((r->>'total_points')::int) from t4_r where k like 'n1-%') = 21
  and (select lifetime_points from public.profiles where id = (select id from t4_u where tag='n1')) = 21,
  (select string_agg(k || '=' || (r->>'total_points'), ' ' order by k) from t4_r where k like 'n1-%')
  || ' weekly=' || pg_temp.t4_points_of((select id from t4_u where tag='n1')));

-- D) Aynı client_uuid ile tekrar → duplicate, lig puanı artmaz
do $$
declare v uuid := gen_random_uuid(); r1 jsonb; r2 jsonb; before int; after int;
begin
  r1 := pg_temp.t4_session('n2', 25, false, now() - interval '200 minutes', v);
  before := pg_temp.t4_points_of((select id from t4_u where tag='n2'));
  r2 := pg_temp.t4_session('n2', 25, false, now() - interval '200 minutes', v);
  after := pg_temp.t4_points_of((select id from t4_u where tag='n2'));
  perform pg_temp.t4_check('D: tekrar gönderim (aynı client_uuid) lig puanını artırmaz',
    (r2->>'duplicate')::boolean and before = after, format('r2=%s before=%s after=%s', r2, before, after));
end $$;

-- E) Günlük tavan: 16 seans dolu kullanıcı (odasız) → 17. seans 0 puan, odaya da yerleşmez
do $$
declare u uuid := (select id from t4_u where tag='n3'); c uuid := (select cat from t4_u where tag='n3');
        i int; r jsonb; v_start timestamptz := now() - interval '26 minutes'; v_day_start timestamptz;
begin
  -- Keep all 17 intervals in one study day without overlap at any run hour.
  -- Early in a study day there is not yet room for 16 real intervals;
  -- use the previous day's last completed interval (still inside 24h).
  v_day_start := (((v_start at time zone 'Europe/Istanbul') - interval '4 hours')::date
                  + time '04:00') at time zone 'Europe/Istanbul';
  if v_start - v_day_start < interval '416 minutes' then
    v_start := v_day_start - interval '30 minutes';
  end if;
  for i in 1..16 loop
    insert into public.study_sessions(user_id, category, category_id, duration_minutes, base_points, bonus_points,
                                      was_paused, is_verified, client_uuid, started_at, completed_at)
    values (u, 't4-ders', c, 25, 5, 0, false, 0, gen_random_uuid(),
            v_start - make_interval(mins => 26 * (17-i)),
            v_start - make_interval(mins => 26 * (17-i)) + interval '25 minutes');
  end loop;
  r := pg_temp.t4_session('n3', 25, false, v_start);
  perform pg_temp.t4_check('E: 16 seans sonrası 17. seans: daily_limit_reached, 0 puan, lig üyeliği açılmaz',
    (r->>'daily_limit_reached')::boolean and (r->>'total_points')::int = 0 and pg_temp.t4_league_of(u) is null,
    format('r=%s league=%s (16 seansın ilki %s TR)', r, pg_temp.t4_league_of(u),
           ((v_start - interval '416 minutes') at time zone 'Europe/Istanbul')::text));
end $$;

-- F) Dönem sınırı: bitişi 30 sn önce geçmiş, cron'un henüz işlemediği oda
do $$
declare l uuid; x uuid; y uuid;
begin
  l := pg_temp.t4_league(4, '2000-01-01', now() - interval '30 seconds'); insert into t4_l values ('RG', l);
  x := pg_temp.t4_user('x', 4); insert into t4_u values ('x', x, pg_temp.t4_category(x));
  y := pg_temp.t4_user('y', 4); insert into t4_u values ('y', y, pg_temp.t4_category(y));
  perform pg_temp.t4_member(l, x, 0, '2026-01-01');
  perform pg_temp.t4_member(l, y, 0, '2026-01-02');
  -- z: tier 4, odasız
  x := pg_temp.t4_user('z', 4); insert into t4_u values ('z', x, pg_temp.t4_category(x));
end $$;
-- x ve z seanslarını oda bitişinden SONRA tamamlıyor (seans başlangıcı bitişten önce de olsa
-- completed_at = now()-1dk > end_date olacak şekilde)
insert into t4_r select 'x-s1', pg_temp.t4_session('x', 25, false, now() - interval '25 minutes 10 seconds');
insert into t4_r select 'z-s1', pg_temp.t4_session('z', 25, false, now() - interval '25 minutes 10 seconds');
select pg_temp.t4_check('F: bitmiş odanın eski dönem puanı artmaz; 5 puan carry olur; odasız z açık odaya yerleşir',
  pg_temp.t4_points_of((select id from t4_u where tag='x')) = 0
  and (select carry_points from public.league_memberships where user_id = (select id from t4_u where tag='x')) = 5
  and pg_temp.t4_league_of((select id from t4_u where tag='z')) <> (select id from t4_l where tag='RG'),
  format('oda bitişi=%s, seans bitişi=%s', (select end_date from public.leagues where id=(select id from t4_l where tag='RG')),
         (select max(completed_at) from public.study_sessions where user_id = (select id from t4_u where tag='x'))));
select public.process_weekly_leagues();
select pg_temp.t4_check('F: dönem devrinde x tier4 kalır, ödül yok; yeni dönem carry 5 puanla başlar',
  pg_temp.t4_tier_of((select id from t4_u where tag='x')) = 4
  and pg_temp.t4_awards_of((select id from t4_u where tag='x')) = ''
  and pg_temp.t4_points_of((select id from t4_u where tag='x')) = 5,
  format('x tier=%s awards=%s weekly=%s; z tier=%s awards=%s weekly=%s',
    pg_temp.t4_tier_of((select id from t4_u where tag='x')), pg_temp.t4_awards_of((select id from t4_u where tag='x')),
    pg_temp.t4_points_of((select id from t4_u where tag='x')),
    pg_temp.t4_tier_of((select id from t4_u where tag='z')), pg_temp.t4_awards_of((select id from t4_u where tag='z')),
    pg_temp.t4_points_of((select id from t4_u where tag='z'))));

-- G) İstemcinin okuduğu: seans sonrası get_my_league_ranking n1 satırı
select pg_temp.t4_as((select id from t4_u where tag='n1'));
set local role authenticated;
create temp table t4_rank as select * from public.get_my_league_ranking();
reset role;
select pg_temp.t4_check('G: get_my_league_ranking n1: 30 satır, n1 is_me, weekly 21, n=30 → 7/24',
  (select count(*) from t4_rank) = 30 and (select weekly_points from t4_rank where is_me) = 21
  and (select bool_and(promotion_zone_end = 7 and demotion_zone_start = 24 and member_count = 30) from t4_rank), null);

\o
\echo '=== t4-03 sonuçlar ==='
select seq, case when ok then 'OK ' else 'FAIL' end as st, name, detail from t4_results order by seq;
rollback;
