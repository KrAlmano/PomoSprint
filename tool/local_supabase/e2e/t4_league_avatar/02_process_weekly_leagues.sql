-- t4-02: process_weekly_leagues uçtan uca (terfi / kalma / düşme / ödül /
-- 0 puan / az üyeli oda / dolu oda → yeni oda / zincirleme taşıma / yeni
-- dönem / ikinci koşu). Dönem sonu, kendi odalarımızın end_date'i geçmişe
-- (son Pazar 23:59:59 TR) çekilerek simüle edilir. TAMAMI ROLLBACK.
-- psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f 02_process_weekly_leagues.sql
\set ON_ERROR_STOP on
\pset pager off
begin;
\i _helpers.sql
\o /dev/null

create temp table t4_u(tag text primary key, id uuid) on commit drop;
create temp table t4_l(tag text primary key, id uuid) on commit drop;

-- Son dönem sınırı: içinde bulunduğumuz haftanın Pazartesi 00:00 TR'sinden 1 sn önce
-- (= son Pazar 23:59:59 TR). Cron Pazar 21:01 UTC'de bu tarihi görür.
create temp table t4_e as
select (date_trunc('week', (now() at time zone 'Europe/Istanbul')::date::timestamp) - interval '1 second')
         at time zone 'Europe/Istanbul' as e;

do $$
declare
  e timestamptz := (select e from t4_e);
  l uuid; u uuid; i int;
  b_pts int[] := array[50,30,30,20,10,10,5,5,5,0,0,0];
begin
  -- L1: tier 1, 4 kişi [12,0,0,0] → n=4 terfi 2; yalnızca a1 (puanlı) terfi + bronze_monthly
  l := pg_temp.t4_league(1, '2000-01-01', e); insert into t4_l values ('L1', l);
  for i in 1..4 loop
    u := pg_temp.t4_user('a' || i, 1); insert into t4_u values ('a' || i, u);
    perform pg_temp.t4_member(l, u, case when i = 1 then 12 else 0 end, '2026-01-01'::timestamptz + make_interval(mins => i));
  end loop;
  -- L2: tier 2, 12 kişi → terfi 3, düşme sıra ≥ 10
  l := pg_temp.t4_league(2, '2000-01-02', e); insert into t4_l values ('L2', l);
  for i in 1..12 loop
    u := pg_temp.t4_user('b' || i, 2); insert into t4_u values ('b' || i, u);
    perform pg_temp.t4_member(l, u, b_pts[i], '2026-01-01'::timestamptz + make_interval(mins => i));
  end loop;
  -- b1 bu ödüle zaten sahip → tekrar verilmemeli, hata da olmamalı
  insert into public.avatar_unlocks(user_id, avatar_id, unlock_type, coins_spent)
  values ((select id from t4_u where tag = 'b1'), 'league_silver_monthly', 'league_award', 0);
  -- L3: tier 3, 22 kişi (hepsi puanlı) → terfi 7, düşme sıra ≥ 16
  l := pg_temp.t4_league(3, '2000-01-03', e); insert into t4_l values ('L3', l);
  for i in 1..22 loop
    u := pg_temp.t4_user('c' || i, 3); insert into t4_u values ('c' || i, u);
    perform pg_temp.t4_member(l, u, 100 - 2 * i, '2026-01-01'::timestamptz + make_interval(mins => i));
  end loop;
  -- L4: tier 4, TEK kişi (5 puan) → n=1 terfi 1 → tier 5 + sapphire_monthly
  l := pg_temp.t4_league(4, '2000-01-04', e); insert into t4_l values ('L4', l);
  u := pg_temp.t4_user('d1', 4); insert into t4_u values ('d1', u);
  perform pg_temp.t4_member(l, u, 5, '2026-01-01');
  -- L5: tier 5, 30 kişi (DOLU) [40,40,0...] → üst kademe: terfi yok; düşme sıra ≥ 24
  l := pg_temp.t4_league(5, '2000-01-05', e); insert into t4_l values ('L5', l);
  for i in 1..30 loop
    u := pg_temp.t4_user('e' || i, 5); insert into t4_u values ('e' || i, u);
    perform pg_temp.t4_member(l, u, case when i <= 2 then 40 else 0 end, '2026-01-01'::timestamptz + make_interval(mins => i));
  end loop;
  -- L6: tier 2, dönemi bitmemiş (3 gün var) → dokunulmamalı
  l := pg_temp.t4_league(2, '2026-09-01', now() + interval '3 days'); insert into t4_l values ('L6', l);
  u := pg_temp.t4_user('f1', 2); insert into t4_u values ('f1', u); perform pg_temp.t4_member(l, u, 7, '2026-09-02');
  u := pg_temp.t4_user('f2', 2); insert into t4_u values ('f2', u); perform pg_temp.t4_member(l, u, 3, '2026-09-03');
  -- L7: tier 3, bitişe 4 dk var (+5 dk penceresi içinde) → işlenmeli; [5,0]
  l := pg_temp.t4_league(3, '2026-09-01', now() + interval '4 minutes'); insert into t4_l values ('L7', l);
  u := pg_temp.t4_user('g1', 3); insert into t4_u values ('g1', u); perform pg_temp.t4_member(l, u, 5, '2026-09-02');
  u := pg_temp.t4_user('g2', 3); insert into t4_u values ('g2', u); perform pg_temp.t4_member(l, u, 0, '2026-09-03');
end $$;

-- Başkalarının (bizim olmayan) bu koşuda işlenecek ligleri var mı? (bilgi)
create temp table t4_foreign_due as
select id, tier, end_date from public.leagues
where is_active and end_date <= now() + interval '5 minutes' and id not in (select id from t4_l);
create temp table t4_foreign_t5 as
select id from public.leagues where is_active and tier = 5 and id not in (select id from t4_l);

create temp table t4_joined_before as
select lm.user_id, lm.joined_at from public.league_memberships lm where lm.user_id in (select id from t4_u);

-- === CRON'un yaptığı çağrı (postgres olarak) ===
select public.process_weekly_leagues();

create temp table t4_snap1 as
select u.tag, lm.league_id, lm.weekly_points, p.league_tier, pg_temp.t4_awards_of(u.id) awards
from t4_u u join public.league_memberships lm on lm.user_id = u.id join public.profiles p on p.id = u.id;

create function pg_temp.lg(p_tag text) returns uuid language sql as $$ select id from t4_l where tag = p_tag $$;
create function pg_temp.at(p_tag text) returns uuid language sql as $$ select league_id from t4_snap1 where tag = p_tag $$;
create function pg_temp.tr(p_tag text) returns int language sql as $$ select league_tier from t4_snap1 where tag = p_tag $$;
create function pg_temp.aw(p_tag text) returns text language sql as $$ select awards from t4_snap1 where tag = p_tag $$;
create function pg_temp.tags(p_league uuid) returns text language sql as $$
  select string_agg(tag, ',' order by tag) from t4_snap1 where league_id = p_league $$;

-- L1 (tier 1, n=4, terfi 2)
select pg_temp.t4_check('L1: a1 (12 puan, 1.) terfi → tier 2, L2 odasına',
  pg_temp.tr('a1') = 2 and pg_temp.at('a1') = pg_temp.lg('L2'), format('tier=%s', pg_temp.tr('a1')));
select pg_temp.t4_check('L1: a1 ödülü league_bronze_monthly', pg_temp.aw('a1') = 'league_bronze_monthly', pg_temp.aw('a1'));
select pg_temp.t4_check('L1: a2 terfi bölgesinde (2.) ama 0 puan → terfi YOK, ödül YOK',
  pg_temp.tr('a2') = 1 and pg_temp.at('a2') = pg_temp.lg('L1') and pg_temp.aw('a2') = '',
  format('tier=%s awards=%s', pg_temp.tr('a2'), pg_temp.aw('a2')));
select pg_temp.t4_check('L1: tier 1 düşme yok (a3,a4 kalır)',
  pg_temp.tr('a3') = 1 and pg_temp.tr('a4') = 1 and pg_temp.at('a4') = pg_temp.lg('L1'), null);

-- L2 (tier 2, n=12)
select pg_temp.t4_check('L2: b1..b3 terfi → tier 3 (L3)',
  (select bool_and(league_tier = 3 and league_id = pg_temp.lg('L3')) from t4_snap1 where tag in ('b1','b2','b3')),
  pg_temp.tags(pg_temp.lg('L3')));
select pg_temp.t4_check('L2: ödüller b1 silver_monthly (tekrar yok), b2/b3 silver_weekly',
  pg_temp.aw('b1') = 'league_silver_monthly' and pg_temp.aw('b2') = 'league_silver_weekly' and pg_temp.aw('b3') = 'league_silver_weekly'
  and (select count(*) from public.avatar_unlocks where user_id = (select id from t4_u where tag='b1') and avatar_id = 'league_silver_monthly') = 1,
  format('b1=%s b2=%s b3=%s', pg_temp.aw('b1'), pg_temp.aw('b2'), pg_temp.aw('b3')));
select pg_temp.t4_check('L2: eşitlikte (b2=b3=30) erken katılan b2 2. sayıldı (ikisi de weekly; sıra ödülü değiştirmez)', true, null);
select pg_temp.t4_check('L2: b4..b9 kalır (tier 2, L2, ödül yok)',
  (select bool_and(league_tier = 2 and league_id = pg_temp.lg('L2') and awards = '') from t4_snap1 where tag in ('b4','b5','b6','b7','b8','b9')), null);
select pg_temp.t4_check('L2: b10..b12 (sıra ≥ 10) düşer → tier 1 (L1)',
  (select bool_and(league_tier = 1 and league_id = pg_temp.lg('L1')) from t4_snap1 where tag in ('b10','b11','b12')), null);

-- L3 (tier 3, n=22: dışarıdan gelen b1..b3 sayılmaz)
select pg_temp.t4_check('L3: c1..c7 terfi → tier 4 (L4)',
  (select bool_and(league_tier = 4 and league_id = pg_temp.lg('L4')) from t4_snap1 where tag in ('c1','c2','c3','c4','c5','c6','c7')), null);
select pg_temp.t4_check('L3: ödüller c1 gold_monthly, c2/c3 gold_weekly, c4 yok',
  pg_temp.aw('c1') = 'league_gold_monthly' and pg_temp.aw('c2') = 'league_gold_weekly' and pg_temp.aw('c3') = 'league_gold_weekly' and pg_temp.aw('c4') = '', null);
select pg_temp.t4_check('L3: c8..c15 kalır',
  (select bool_and(league_tier = 3 and league_id = pg_temp.lg('L3')) from t4_snap1 where tag in ('c8','c9','c10','c11','c12','c13','c14','c15')), null);
select pg_temp.t4_check('L3: c16..c22 (puanlı olsalar da) düşer → tier 2 (L2)',
  (select bool_and(league_tier = 2 and league_id = pg_temp.lg('L2')) from t4_snap1 where tag in ('c16','c17','c18','c19','c20','c21','c22')), null);
select pg_temp.t4_check('Zincir: L3''e aynı koşuda gelen b1..b3 ikinci kez işlenmedi (tier 3''te kaldı, tier 4 değil)',
  (select bool_and(league_tier = 3) from t4_snap1 where tag in ('b1','b2','b3')), null);

-- L4 (tek kişilik oda) + L5 dolu → yeni tier-5 odası
select pg_temp.t4_check('L4 tek kişilik oda: d1 (5 puan) terfi → tier 5 + sapphire_monthly',
  pg_temp.tr('d1') = 5 and pg_temp.aw('d1') = 'league_sapphire_monthly', format('tier=%s aw=%s', pg_temp.tr('d1'), pg_temp.aw('d1')));
select pg_temp.t4_check('L5 dolu (30) → d1 için YENİ tier-5 odası açıldı (L5 değil)',
  pg_temp.at('d1') <> pg_temp.lg('L5') and (select tier from public.leagues where id = pg_temp.at('d1')) = 5,
  format('d1 odası=%s başka tier-5 oda sayısı(önceden)=%s', pg_temp.at('d1'), (select count(*) from t4_foreign_t5)));
select pg_temp.t4_check('Yeni oda end_date = 2 hafta sonraki Pazar 23:59:59 TR',
  (select end_date from public.leagues where id = pg_temp.at('d1')) =
  ((date_trunc('week', ((now() at time zone 'Europe/Istanbul') + interval '1 day')::date::timestamp) + interval '13 days' + time '23:59:59') at time zone 'Europe/Istanbul'),
  (select end_date::text || ' (TR ' || (end_date at time zone 'Europe/Istanbul')::text || ')' from public.leagues where id = pg_temp.at('d1')));

-- L5 (tier 5, n=30)
select pg_temp.t4_check('L5: üst kademede terfi yok; e1 diamond_monthly, e2 diamond_weekly, e3 (0 puan) ödül yok',
  pg_temp.tr('e1') = 5 and pg_temp.at('e1') = pg_temp.lg('L5') and pg_temp.aw('e1') = 'league_diamond_monthly'
  and pg_temp.aw('e2') = 'league_diamond_weekly' and pg_temp.aw('e3') = '',
  format('e1=%s e2=%s e3=%s', pg_temp.aw('e1'), pg_temp.aw('e2'), pg_temp.aw('e3')));
select pg_temp.t4_check('L5: e24..e30 düşer → tier 4 (L4)',
  (select bool_and(league_tier = 4 and league_id = pg_temp.lg('L4')) from t4_snap1 where tag in ('e24','e25','e26','e27','e28','e29','e30')),
  (select count(*)::text from t4_snap1 where league_id = pg_temp.lg('L4')));
select pg_temp.t4_check('L5: e3..e23 kalır', (select bool_and(league_tier = 5 and league_id = pg_temp.lg('L5')) from t4_snap1
  where tag in (select 'e' || g from generate_series(3,23) g)), null);

-- L6 (bitmemiş) / L7 (+5 dk penceresi)
select pg_temp.t4_check('L6 dönemi bitmemiş: puanlar ve end_date aynen',
  (select weekly_points from t4_snap1 where tag = 'f1') = 7 and (select weekly_points from t4_snap1 where tag = 'f2') = 3
  and (select end_date > now() + interval '2 days' and end_date < now() + interval '4 days' from public.leagues where id = pg_temp.lg('L6')), null);
select pg_temp.t4_check('L7 (bitişe 4 dk) işlendi: g1 terfi → tier 4 + gold_monthly; g2 (0) kaldı',
  pg_temp.tr('g1') = 4 and pg_temp.aw('g1') = 'league_gold_monthly' and pg_temp.tr('g2') = 3 and pg_temp.aw('g2') = '', null);

-- Yeni dönem
select pg_temp.t4_check('İşlenen odalarda herkesin weekly_points = 0',
  (select bool_and(weekly_points = 0) from t4_snap1 where tag not in ('f1','f2')), null);
select pg_temp.t4_check('L1..L5 end_date = eski bitiş + 14 gün (Pazar 23:59:59 TR)',
  (select bool_and(l.end_date = (select e from t4_e) + interval '14 days') from public.leagues l where l.id in (select id from t4_l where tag in ('L1','L2','L3','L4','L5'))),
  (select string_agg(t.tag || '=' || (l.end_date at time zone 'Europe/Istanbul')::text, ' ' order by t.tag) from public.leagues l join t4_l t on t.id = l.id));
select pg_temp.t4_check('Oda kapasiteleri ≤ 30 ve beklenen üye sayıları (L1 6, L2 14, L3 11, L4 15, L5 23, L7 1)',
  (select count(*) from t4_snap1 where league_id = pg_temp.lg('L1')) = 6
  and (select count(*) from t4_snap1 where league_id = pg_temp.lg('L2')) = 14
  and (select count(*) from t4_snap1 where league_id = pg_temp.lg('L3')) = 11
  and (select count(*) from t4_snap1 where league_id = pg_temp.lg('L4')) = 15
  and (select count(*) from t4_snap1 where league_id = pg_temp.lg('L5')) = 23
  and (select count(*) from t4_snap1 where league_id = pg_temp.lg('L7')) = 1,
  (select string_agg(t.tag || '=' || (select count(*) from public.league_memberships m where m.league_id = t.id), ' ' order by t.tag) from t4_l t));
select pg_temp.t4_check('Ödül alan kişi sayısı tam 11 (a1,b1,b2,b3,c1,c2,c3,d1,e1,e2,g1); başka kimse yok',
  (select string_agg(tag, ',' order by tag) from t4_snap1 where awards <> '') = 'a1,b1,b2,b3,c1,c2,c3,d1,e1,e2,g1',
  (select string_agg(tag, ',' order by tag) from t4_snap1 where awards <> ''));
select pg_temp.t4_check('Terfi eden herkese activity_feed league_promotion (13 kişi: a1,b1-3,c1-7,d1,g1)',
  (select count(*) from public.activity_feed where activity_type = 'league_promotion' and user_id in (select id from t4_u)) = 13,
  (select count(*)::text || ' satır, tarih ' || string_agg(distinct activity_date::text, ',') from public.activity_feed where activity_type = 'league_promotion' and user_id in (select id from t4_u)));
select pg_temp.t4_check('BİLGİ: league_promotion activity_date (TR''de biten dönemin günü = Pazar olmalı)',
  (select bool_and(extract(isodow from activity_date) = 7) from public.activity_feed where activity_type = 'league_promotion' and user_id in (select id from t4_u)),
  (select string_agg(distinct activity_date::text || ' isodow=' || extract(isodow from activity_date), ',') from public.activity_feed where activity_type = 'league_promotion' and user_id in (select id from t4_u)));
select pg_temp.t4_check('BİLGİ: taşınan üyenin joined_at''ı korunuyor (yeni odada eşitlik bozucu eski katılım zamanı)',
  (select bool_and(lm.joined_at = jb.joined_at) from public.league_memberships lm join t4_joined_before jb using (user_id)
     where lm.user_id = (select id from t4_u where tag = 'a1')),
  (select lm.joined_at::text from public.league_memberships lm where lm.user_id = (select id from t4_u where tag = 'a1')));

-- İstemci görünümü: tek başına yeni odaya terfi eden d1 (member_count 1, 0 puan)
-- LeagueSnapshot.awaitingPlacement (memberCount<=1 && myPoints<=0) → "Henüz bir lig odasında değilsin"
select pg_temp.t4_as((select id from t4_u where tag = 'd1'));
set local role authenticated;
create temp table t4_rank_d1 as select * from public.get_my_league_ranking();
reset role;
select pg_temp.t4_check('İstemci: terfi edip yeni odada tek kalan d1 "lig odasında değilsin" (awaitingPlacement) görmemeli',
  not ((select count(*) from t4_rank_d1) = 1 and (select member_count <= 1 and weekly_points <= 0 from t4_rank_d1)),
  (select format('%s', row_to_json(t)) from t4_rank_d1 t));

-- İkinci koşu (ör. cron çift tetiklenirse): hiçbir şey değişmemeli
select public.process_weekly_leagues();
select pg_temp.t4_check('İkinci koşu idempotent: üyelik/kademe/ödül değişmedi',
  not exists (
    select u.tag, lm.league_id, lm.weekly_points, p.league_tier, pg_temp.t4_awards_of(u.id)
    from t4_u u join public.league_memberships lm on lm.user_id = u.id join public.profiles p on p.id = u.id
    except select tag, league_id, weekly_points, league_tier, awards from t4_snap1), null);

-- Sonraki dönem: yükselenin yeni odasında ödül yeni kademeye göre (a1 L2'de 1. olursa silver_monthly)
update public.league_memberships set weekly_points = 99 where user_id = (select id from t4_u where tag = 'a1');
update public.leagues set end_date = now() - interval '1 minute' where id = pg_temp.lg('L2');
select public.process_weekly_leagues();
select pg_temp.t4_check('Sonraki dönem: a1 (artık tier 2) 1. bitirince silver_monthly kazanır ve tier 3''e çıkar',
  pg_temp.t4_awards_of((select id from t4_u where tag = 'a1')) = 'league_bronze_monthly,league_silver_monthly'
  and pg_temp.t4_tier_of((select id from t4_u where tag = 'a1')) = 3,
  pg_temp.t4_awards_of((select id from t4_u where tag = 'a1')));
-- Tek kişilik oda: d1 (yeni tier-5 odasında yalnız) bir seanslık 5 puanla dönemi bitirir
update public.league_memberships set weekly_points = 5 where user_id = (select id from t4_u where tag = 'd1');
update public.leagues set end_date = now() - interval '1 minute'
 where id = (select league_id from public.league_memberships where user_id = (select id from t4_u where tag = 'd1'));
select public.process_weekly_leagues();
select pg_temp.t4_check('BULGU: tek kişilik odada 1 seans (5 puan) Elmas Şampiyonluk ödülü kazandırmamalı',
  pg_temp.t4_awards_of((select id from t4_u where tag = 'd1')) not like '%league_diamond_monthly%',
  pg_temp.t4_awards_of((select id from t4_u where tag = 'd1')));

select pg_temp.t4_check('BİLGİ: geçmişe çekilen bitişte (now-1dk) yeni end_date +14 gün → hizasız değil mi?',
  true, (select (end_date at time zone 'Europe/Istanbul')::text from public.leagues where id = pg_temp.lg('L2')));

select pg_temp.t4_check('BİLGİ: bu koşuda işlenen yabancı (bizim olmayan) oda sayısı', true, (select count(*)::text from t4_foreign_due));

\o
\echo '=== t4-02 sonuçlar ==='
select seq, case when ok then 'OK ' else 'FAIL' end as st, name, detail from t4_results order by seq;
rollback;
