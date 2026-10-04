-- t4-04: varsayılan avatarlar, purchase_avatar, set_equipped_avatar, doğrudan
-- tablo yazma yetkileri. TAMAMI ROLLBACK.
-- psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f 04_avatars.sql
\set ON_ERROR_STOP on
\pset pager off
begin;
\i _helpers.sql
\o /dev/null

create temp table t4_u(tag text primary key, id uuid) on commit drop;
grant select on t4_u to authenticated;

-- RPC'yi authenticated olarak çağırır; hata metnini döndürür (null = başarı).
create function pg_temp.t4_try(p_tag text, p_sql text, out ok boolean, out result text, out err text)
language plpgsql as $$
begin
  perform pg_temp.t4_as((select id from t4_u where tag = p_tag));
  set local role authenticated;
  begin
    execute p_sql into result;
    ok := true;
  exception when others then
    ok := false; err := sqlstate || ': ' || sqlerrm;
  end;
  reset role;
end $$;

create function pg_temp.coins(p_tag text) returns int language sql as $$
  select coins from public.profiles where id = (select id from t4_u where tag = p_tag) $$;
create function pg_temp.owns(p_tag text, p_avatar text) returns text language sql as $$
  select unlock_type || '/' || coins_spent from public.avatar_unlocks
  where user_id = (select id from t4_u where tag = p_tag) and avatar_id = p_avatar $$;

-- 1) Kayıt: varsayılan avatarlar + istenen avatarın doğrulanması
do $$
declare u uuid;
begin
  u := pg_temp.t4_user('buyer', 1); insert into t4_u values ('buyer', u);
  u := pg_temp.t4_user('prem', 1);  insert into t4_u values ('prem', u);
  update public.profiles set is_premium = true where id = u;
  -- kayıt metadata'sında ücretli avatar isteyen
  u := gen_random_uuid();
  insert into auth.users(id, email, aud, role, raw_user_meta_data)
  values (u, 't4-paidmeta-' || left(u::text, 8) || '@pomosprint.local', 'authenticated', 'authenticated',
          '{"name":"t4-paidmeta","avatar_id":"avatar_1_gamer"}');
  insert into t4_u values ('paidmeta', u);
  u := gen_random_uuid();
  insert into auth.users(id, email, aud, role, raw_user_meta_data)
  values (u, 't4-flower-' || left(u::text, 8) || '@pomosprint.local', 'authenticated', 'authenticated',
          '{"name":"t4-flower","avatar_id":"avatar_5_flower"}');
  insert into t4_u values ('flower', u);
end $$;

select pg_temp.t4_check('Kayıt: 7 varsayılan avatar açıldı (unlock_type=default), pasif tomato_basic yok',
  (select string_agg(avatar_id, ',' order by avatar_id) from public.avatar_unlocks where user_id = (select id from t4_u where tag='buyer'))
  = (select string_agg(id, ',' order by id) from public.avatars where is_default and is_active)
  and (select count(*) from public.avatar_unlocks where user_id = (select id from t4_u where tag='buyer')) = 7
  and (select bool_and(unlock_type = 'default' and coins_spent = 0) from public.avatar_unlocks where user_id = (select id from t4_u where tag='buyer')),
  (select string_agg(avatar_id, ',' order by avatar_id) from public.avatar_unlocks where user_id = (select id from t4_u where tag='buyer')));
select pg_temp.t4_check('Kayıt: metadata''da ücretli avatar → avatar_16_basic; varsayılan (flower) korunur',
  (select avatar_id from public.profiles where id = (select id from t4_u where tag='paidmeta')) = 'avatar_16_basic'
  and (select avatar_id from public.profiles where id = (select id from t4_u where tag='flower')) = 'avatar_5_flower', null);
select pg_temp.t4_check('Kayıt: başlangıç kum = 0, varsayılan avatar = avatar_16_basic',
  pg_temp.coins('buyer') = 0 and (select avatar_id from public.profiles where id = (select id from t4_u where tag='buyer')) = 'avatar_16_basic', null);

-- 2) Satın alma
update public.profiles set coins = 250 where id = (select id from t4_u where tag = 'buyer');
create temp table t4_p as select 'buy-gamer' k, * from pg_temp.t4_try('buyer', $q$select public.purchase_avatar('avatar_1_gamer')$q$);
select pg_temp.t4_check('Satın alma (250 kum, 200''lük): yeni bakiye 50 döner, unlock coins/200',
  (select ok and result = '50' from t4_p where k = 'buy-gamer') and pg_temp.coins('buyer') = 50
  and pg_temp.owns('buyer', 'avatar_1_gamer') = 'coins/200',
  (select coalesce(result, err) from t4_p where k = 'buy-gamer'));

insert into t4_p select 'buy-again', * from pg_temp.t4_try('buyer', $q$select public.purchase_avatar('avatar_1_gamer')$q$);
select pg_temp.t4_check('Sahip olunanı tekrar satın alma: bakiye değişmez, mevcut bakiye döner',
  (select ok and result = '50' from t4_p where k = 'buy-again') and pg_temp.coins('buyer') = 50
  and (select count(*) from public.avatar_unlocks where user_id = (select id from t4_u where tag='buyer') and avatar_id = 'avatar_1_gamer') = 1,
  (select coalesce(result, err) from t4_p where k = 'buy-again'));

insert into t4_p select 'buy-poor', * from pg_temp.t4_try('buyer', $q$select public.purchase_avatar('avatar_4_bowtie')$q$);
select pg_temp.t4_check('Yetersiz bakiye (50 < 200): hata, bakiye ve sahiplik değişmez',
  (select not ok and err like '%Yetersiz bakiye%' from t4_p where k = 'buy-poor') and pg_temp.coins('buyer') = 50
  and pg_temp.owns('buyer', 'avatar_4_bowtie') is null,
  (select err from t4_p where k = 'buy-poor'));

insert into t4_p select 'buy-premium-np', * from pg_temp.t4_try('buyer', $q$select public.purchase_avatar('avatar_11_doctor')$q$);
select pg_temp.t4_check('Premium avatar (Premium olmayan): reddedilir',
  (select not ok and err like '%Premium%' from t4_p where k = 'buy-premium-np') and pg_temp.owns('buyer', 'avatar_11_doctor') is null,
  (select err from t4_p where k = 'buy-premium-np'));

insert into t4_p select 'buy-premium-p', * from pg_temp.t4_try('prem', $q$select public.purchase_avatar('avatar_11_doctor')$q$);
select pg_temp.t4_check('Premium avatar (Premium kullanıcı): ücretsiz açılır (premium/0), bakiye aynı',
  (select ok and result = '0' from t4_p where k = 'buy-premium-p') and pg_temp.owns('prem', 'avatar_11_doctor') = 'premium/0',
  (select coalesce(result, err) from t4_p where k = 'buy-premium-p'));

insert into t4_p select 'buy-award', * from pg_temp.t4_try('buyer', $q$select public.purchase_avatar('league_gold_monthly')$q$);
insert into t4_p select 'buy-award-p', * from pg_temp.t4_try('prem', $q$select public.purchase_avatar('league_gold_weekly')$q$);
select pg_temp.t4_check('Lig ödülü avatarı satın alınamaz (normal ve Premium)',
  (select bool_and(not ok and err like '%satın alınamaz%') from t4_p where k in ('buy-award','buy-award-p'))
  and pg_temp.owns('buyer', 'league_gold_monthly') is null and pg_temp.owns('prem', 'league_gold_weekly') is null,
  (select string_agg(err, ' | ') from t4_p where k in ('buy-award','buy-award-p')));

insert into t4_p select 'buy-inactive', * from pg_temp.t4_try('buyer', $q$select public.purchase_avatar('tomato_basic')$q$);
insert into t4_p select 'buy-missing', * from pg_temp.t4_try('buyer', $q$select public.purchase_avatar('yok_boyle_avatar')$q$);
select pg_temp.t4_check('Pasif / olmayan avatar: bulunamadı',
  (select bool_and(not ok and err like '%bulunamadı%') from t4_p where k in ('buy-inactive','buy-missing')),
  (select string_agg(err, ' | ') from t4_p where k in ('buy-inactive','buy-missing')));

-- 3) Kuşanma
insert into t4_p select 'eq-owned', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('avatar_1_gamer')::text$q$);
select pg_temp.t4_check('Satın alınanı kuşan: true, profiles.avatar_id güncellenir',
  (select ok and result = 'true' from t4_p where k = 'eq-owned')
  and (select avatar_id from public.profiles where id = (select id from t4_u where tag='buyer')) = 'avatar_1_gamer', null);
insert into t4_p select 'eq-default', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('avatar_7_scholar')::text$q$);
select pg_temp.t4_check('Varsayılan avatarı kuşan: true', (select ok from t4_p where k = 'eq-default'), null);
insert into t4_p select 'eq-locked', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('avatar_9_viking')::text$q$);
insert into t4_p select 'eq-award', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('league_gold_monthly')::text$q$);
insert into t4_p select 'eq-premium', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('avatar_11_doctor')::text$q$);
select pg_temp.t4_check('Sahip olunmayan (ücretli / lig ödülü / Premium) kuşanılamaz: "Bu avatar kilitli."',
  (select bool_and(not ok and err like '%kilitli%') from t4_p where k in ('eq-locked','eq-award','eq-premium'))
  and (select avatar_id from public.profiles where id = (select id from t4_u where tag='buyer')) = 'avatar_7_scholar',
  (select string_agg(k || '→' || err, ' | ') from t4_p where k in ('eq-locked','eq-award','eq-premium')));
-- ödül kazanılınca (process_weekly_leagues'in eklediği satır) kuşanılabilir
insert into public.avatar_unlocks(user_id, avatar_id, unlock_type, coins_spent)
values ((select id from t4_u where tag='buyer'), 'league_gold_monthly', 'league_award', 0);
insert into t4_p select 'eq-award-won', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('league_gold_monthly')::text$q$);
select pg_temp.t4_check('Kazanılan lig ödülü kuşanılabilir', (select ok from t4_p where k = 'eq-award-won'), null);
-- pasif ama sahip olunan avatar
insert into public.avatar_unlocks(user_id, avatar_id, unlock_type, coins_spent)
values ((select id from t4_u where tag='buyer'), 'tomato_basic', 'default', 0);
insert into t4_p select 'eq-inactive', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('tomato_basic')::text$q$);
select pg_temp.t4_check('BİLGİ: pasif (is_active=false) avatar sahibi tarafından kuşanılabiliyor mu',
  true, (select case when ok then 'EVET kuşanıldı' else err end from t4_p where k = 'eq-inactive'));

-- 4) Oturumsuz
select set_config('request.jwt.claims', '', true);
set local role authenticated;
do $$
begin
  perform public.purchase_avatar('avatar_1_gamer');
  perform pg_temp.t4_check('Oturumsuz purchase_avatar: Not authenticated', false, 'geçti');
exception when others then
  perform pg_temp.t4_check('Oturumsuz purchase_avatar: Not authenticated', sqlerrm = 'Not authenticated', sqlerrm);
end $$;
reset role;

-- 5) Doğrudan tablo yazma (RPC'yi atlama) reddedilir
create temp table t4_w(k text, err text) on commit drop;
grant insert on t4_w to authenticated;
select pg_temp.t4_as((select id from t4_u where tag='buyer'));
set local role authenticated;
do $$ begin
  insert into public.avatar_unlocks(user_id, avatar_id, unlock_type) values (auth.uid(), 'avatar_9_viking', 'coins');
  insert into t4_w values ('unlock-insert', 'GEÇTİ');
exception when others then insert into t4_w values ('unlock-insert', sqlstate || ' ' || sqlerrm); end $$;
do $$ begin
  update public.profiles set coins = 99999 where id = auth.uid();
  insert into t4_w values ('coins-update', 'GEÇTİ');
exception when others then insert into t4_w values ('coins-update', sqlstate || ' ' || sqlerrm); end $$;
do $$ begin
  update public.profiles set avatar_id = 'avatar_9_viking' where id = auth.uid();
  insert into t4_w values ('avatar-update', 'GEÇTİ');
exception when others then insert into t4_w values ('avatar-update', sqlstate || ' ' || sqlerrm); end $$;
do $$ begin
  update public.profiles set league_tier = 5 where id = auth.uid();
  insert into t4_w values ('tier-update', 'GEÇTİ');
exception when others then insert into t4_w values ('tier-update', sqlstate || ' ' || sqlerrm); end $$;
do $$ begin
  update public.league_memberships set weekly_points = 9999 where user_id = auth.uid();
  insert into t4_w values ('weekly-update', 'GEÇTİ');
exception when others then insert into t4_w values ('weekly-update', sqlstate || ' ' || sqlerrm); end $$;
reset role;
select pg_temp.t4_check('authenticated: avatar_unlocks INSERT, profiles coins/avatar_id/league_tier UPDATE, league_memberships UPDATE reddedilir',
  (select bool_and(err like '42501%') from t4_w) and (select count(*) from t4_w) = 5,
  (select string_agg(k || ': ' || err, ' | ') from t4_w));

-- 6) Katalog sonradan yeni bir is_default avatar alırsa (eski kullanıcıda unlock yok)
insert into public.avatars(id, name_tr, name_en, asset_key, cost_coins, is_default, sort_order)
values ('t4_new_default', 'T4', 'T4', 'assets/avatars/avatar_16_basic.png', 0, true, 99);
insert into t4_p select 'eq-new-default', * from pg_temp.t4_try('buyer', $q$select public.set_equipped_avatar('t4_new_default')::text$q$);
select pg_temp.t4_check('BİLGİ: sonradan eklenen varsayılan avatar eski kullanıcıda (istemci isFree=sahip sayar) kuşanılabiliyor mu',
  (select ok from t4_p where k = 'eq-new-default'), (select coalesce(result, err) from t4_p where k = 'eq-new-default'));

\o
\echo '=== t4-04 sonuçlar ==='
select seq, case when ok then 'OK ' else 'FAIL' end as st, name, detail from t4_results order by seq;
rollback;
