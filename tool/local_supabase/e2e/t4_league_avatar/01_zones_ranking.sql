-- t4-01: get_league_zones sınırları, get_league_ranking / get_my_league_ranking
-- sıralama + eşitlik bozucu + bölgeler + yetki. Hepsi ROLLBACK.
-- psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f 01_zones_ranking.sql
\set ON_ERROR_STOP on
\pset pager off
begin;
\i _helpers.sql

-- 1) Bölge tablosu (AGENTS §6.4): <10 → terfi ceil(n/2) en çok 3, düşme yok;
--    10–19 → ilk 3 / son 3; 20+ → ilk 7 / son 7.
do $$
declare n int; z record; exp_p int; exp_d int;
begin
  foreach n in array array[0,1,2,3,4,5,6,9,10,11,12,19,20,21,22,29,30,31] loop
    select * into z from public.get_league_zones(n);
    if n < 10 then exp_p := least(3, greatest(1, ceil(greatest(n,1)/2.0)::int)); exp_d := 999;
    elsif n < 20 then exp_p := 3; exp_d := n - 2;
    else exp_p := 7; exp_d := n - 6; end if;
    perform pg_temp.t4_check('zones n=' || n,
      z.promotion_zone_end = exp_p and z.demotion_zone_start = exp_d,
      format('got promo=%s demo_start=%s, expected %s/%s, demoted count=%s',
             z.promotion_zone_end, z.demotion_zone_start, exp_p, exp_d,
             case when z.demotion_zone_start > n then 0 else n - z.demotion_zone_start + 1 end));
  end loop;
end $$;

-- 2) 12 kişilik tier-2 odası: eşitlik bozucu weekly_points DESC, joined_at ASC, user_id.
create temp table t4_u(tag text primary key, id uuid) on commit drop;
grant select on t4_u to authenticated;
do $$
declare l uuid; i int; pts int[] := array[50,30,30,20,10,10,5,5,5,0,0,0]; u uuid;
begin
  l := pg_temp.t4_league(2, '2000-01-01', now() + interval '3 days');
  for i in 1..12 loop
    u := pg_temp.t4_user('r' || i, 2);
    insert into t4_u values ('r' || i, u);
    perform pg_temp.t4_member(l, u, pts[i], timestamptz '2026-01-01' + make_interval(mins => i));
  end loop;
  -- r3 ile r2 eşit (30): r2 daha önce katıldı → 2., r3 → 3.
  -- r5/r6 eşit (10): r5 önce. r10..r12 0 puan.
end $$;

select pg_temp.t4_as((select id from t4_u where tag = 'r6'));
set local role authenticated;
create temp table t4_rank as select row_number() over () as pos, r.* from public.get_my_league_ranking() r;
reset role;

select pg_temp.t4_check('ranking: 12 satır, member_count=12',
  (select count(*) from t4_rank) = 12 and (select bool_and(member_count = 12) from t4_rank),
  (select string_agg(pos || ':' || name || '=' || weekly_points, ' ' order by pos) from t4_rank));
select pg_temp.t4_check('ranking: eşitlikte erken katılan önde (r2 > r3, r5 > r6)',
  (select name from t4_rank where pos = 2) = 't4-r2' and (select name from t4_rank where pos = 3) = 't4-r3'
  and (select name from t4_rank where pos = 5) = 't4-r5' and (select name from t4_rank where pos = 6) = 't4-r6',
  (select string_agg(pos || ':' || name, ' ' order by pos) from t4_rank where pos <= 6));
select pg_temp.t4_check('ranking: bölgeler n=12 → promo 3, demo_start 10',
  (select bool_and(promotion_zone_end = 3 and demotion_zone_start = 10 and tier = 2) from t4_rank),
  (select format('promo=%s demo=%s tier=%s', max(promotion_zone_end), max(demotion_zone_start), max(tier)) from t4_rank));
select pg_temp.t4_check('ranking: is_me yalnızca r6 satırında',
  (select count(*) from t4_rank where is_me) = 1 and (select name from t4_rank where is_me) = 't4-r6', null);
select pg_temp.t4_check('ranking: ilk 3 (puanlı) lig ödülü avatarıyla gösterilir (silver_monthly / silver_weekly)',
  (select avatar_id from t4_rank where pos = 1) = 'league_silver_monthly'
  and (select avatar_id from t4_rank where pos = 2) = 'league_silver_weekly'
  and (select avatar_id from t4_rank where pos = 3) = 'league_silver_weekly'
  and (select avatar_id from t4_rank where pos = 4) = 'avatar_16_basic',
  (select string_agg(pos || ':' || avatar_id, ' ' order by pos) from t4_rank where pos <= 4));
select pg_temp.t4_check('ranking: profiles.avatar_id değişmez (yalnızca görünüm)',
  (select avatar_id from public.profiles where id = (select id from t4_u where tag = 'r1')) = 'avatar_16_basic', null);

-- 3) 0 puanlı ilk 3 ödül avatarıyla görünmez: 3 kişilik odada [7,0,0]
do $$
declare l uuid; u uuid; i int; pts int[] := array[7,0,0];
begin
  l := pg_temp.t4_league(4, '2000-01-01', now() + interval '3 days');
  for i in 1..3 loop
    u := pg_temp.t4_user('z' || i, 4);
    insert into t4_u values ('z' || i, u);
    perform pg_temp.t4_member(l, u, pts[i], timestamptz '2026-01-01' + make_interval(mins => i));
  end loop;
end $$;
select pg_temp.t4_as((select id from t4_u where tag = 'z2'));
set local role authenticated;
create temp table t4_rank3 as select row_number() over () as pos, r.* from public.get_my_league_ranking() r;
reset role;
select pg_temp.t4_check('ranking n=3: promo 2, düşme yok (999); 0 puanlılar ödül avatarı görmez',
  (select bool_and(promotion_zone_end = 2 and demotion_zone_start = 999) from t4_rank3)
  and (select avatar_id from t4_rank3 where pos = 1) = 'league_sapphire_monthly'
  and (select avatar_id from t4_rank3 where pos = 2) = 'avatar_16_basic'
  and (select avatar_id from t4_rank3 where pos = 3) = 'avatar_16_basic',
  (select string_agg(pos || ':' || avatar_id || '/' || weekly_points, ' ' order by pos) from t4_rank3));

-- 4) Ligi olmayan kullanıcı: tek satır, 0 puan, member_count 0, bölge 1/999,
--    end_date = bu haftanın Pazartesi'si (TR) + 13 gün 23:59:59 TR.
do $$ declare u uuid; begin u := pg_temp.t4_user('nol', 3); insert into t4_u values ('nol', u); end $$;
select pg_temp.t4_as((select id from t4_u where tag = 'nol'));
set local role authenticated;
create temp table t4_rank_none as select * from public.get_my_league_ranking();
reset role;
select pg_temp.t4_check('ligsiz kullanıcı: tek satır (is_me, 0, tier=profil, n=0, 1/999)',
  (select count(*) from t4_rank_none) = 1
  and (select is_me and weekly_points = 0 and tier = 3 and member_count = 0
              and promotion_zone_end = 1 and demotion_zone_start = 999 from t4_rank_none),
  (select format('%s', row_to_json(t)) from t4_rank_none t));
select pg_temp.t4_check('ligsiz kullanıcı: end_date bir sonraki haftanın Pazar 23:59:59 TR',
  (select end_date from t4_rank_none) =
  ((date_trunc('week', (now() at time zone 'Europe/Istanbul')::date::timestamp) + interval '13 days' + time '23:59:59') at time zone 'Europe/Istanbul'),
  (select end_date::text from t4_rank_none));

-- 5) Yetki: başkasının id'si ile get_league_ranking → not authorized; anon
--    get_my_league_ranking → 0 satır / yetki yok; anon get_league_zones OK.
select pg_temp.t4_as((select id from t4_u where tag = 'r1'));
set local role authenticated;
do $$
begin
  perform * from public.get_league_ranking((select id from t4_u where tag = 'r2'));
  perform pg_temp.t4_check('get_league_ranking(başkası) reddedilir', false, 'reddedilmedi');
exception when others then
  perform pg_temp.t4_check('get_league_ranking(başkası) reddedilir', sqlerrm = 'not authorized', sqlerrm);
end $$;
do $$
begin
  perform public.ensure_user_in_league((select id from t4_u where tag = 'r1'), 1000);
  perform pg_temp.t4_check('authenticated ensure_user_in_league çağıramaz (puan şişirme yok)', false, 'çağrılabildi!');
exception when insufficient_privilege then
  perform pg_temp.t4_check('authenticated ensure_user_in_league çağıramaz (puan şişirme yok)', true, sqlerrm);
end $$;
do $$
begin
  perform public.process_weekly_leagues();
  perform pg_temp.t4_check('authenticated process_weekly_leagues çağıramaz', false, 'çağrılabildi!');
exception when insufficient_privilege then
  perform pg_temp.t4_check('authenticated process_weekly_leagues çağıramaz', true, sqlerrm);
end $$;
reset role;
select set_config('request.jwt.claims', '', true);
set local role anon;
do $$
begin
  perform * from public.get_my_league_ranking();
  perform pg_temp.t4_check('anon get_my_league_ranking yetkisiz', false, 'çağrılabildi');
exception when insufficient_privilege then
  perform pg_temp.t4_check('anon get_my_league_ranking yetkisiz', true, sqlerrm);
end $$;
do $$
declare z record;
begin
  select * into z from public.get_league_zones(25);
  perform pg_temp.t4_check('anon get_league_zones ve league_award_avatar_id çağırabilir',
    z.promotion_zone_end = 7 and public.league_award_avatar_id(3, 1) = 'league_gold_monthly'
    and public.league_award_avatar_id(3, 4) is null and public.league_award_avatar_id(6, 1) is null,
    format('zones(25)=%s/%s', z.promotion_zone_end, z.demotion_zone_start));
end $$;
reset role;

-- 6) Ödül eşlemesi (5 kademe × sıra 1..4)
select pg_temp.t4_check('league_award_avatar_id eşlemesi tam ve katalogda var',
  (select bool_and(case when r = 1 then a = 'league_' || t || '_monthly'
                        when r in (2,3) then a = 'league_' || t || '_weekly'
                        else a is null end
                   and (a is null or exists (select 1 from public.avatars v where v.id = a and v.is_league_award and v.is_active)))
   from (select tn.t, r, public.league_award_avatar_id(tn.k, r) a
         from (values (1,'bronze'),(2,'silver'),(3,'gold'),(4,'sapphire'),(5,'diamond')) tn(k,t),
              generate_series(1,4) r) x), null);

\echo '=== t4-01 sonuçlar ==='
select seq, case when ok then 'OK ' else 'FAIL' end as st, name, detail from t4_results order by seq;
rollback;
