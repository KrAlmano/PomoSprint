-- t4 (lig + avatar) ortak yardımcıları. Her betik BEGIN'den SONRA \i ile
-- yükler; hepsi pg_temp'te ve transaction ROLLBACK ile birlikte yok olur.
-- Yalnızca YEREL kopya: postgresql://postgres:postgres@127.0.0.1:54322/postgres

create temp table t4_results(seq serial, name text, ok boolean, detail text) on commit drop;

-- Sonuç kaydı (authenticated rolündeyken de yazabilsin diye SECURITY DEFINER).
create function pg_temp.t4_check(p_name text, p_ok boolean, p_detail text default null)
returns void language sql security definer as $$
  insert into t4_results(name, ok, detail) values (p_name, coalesce(p_ok, false), p_detail)
$$;

-- Kullanıcı taklidi: auth.uid() = p_uid (rol değişmez; rol için SET LOCAL ROLE).
create function pg_temp.t4_as(p_uid uuid) returns void language sql as $$
  select set_config('request.jwt.claims',
                    json_build_object('sub', p_uid, 'role', 'authenticated')::text, true)
$$;

-- Transaction içinde auth.users satırı → handle_new_user (profil) +
-- give_default_avatars (varsayılan avatarlar) tetiklenir. E-posta t4- önekli.
create function pg_temp.t4_user(p_tag text, p_tier int default 1) returns uuid
language plpgsql as $$
declare v uuid := gen_random_uuid();
begin
  insert into auth.users(id, email, aud, role, raw_user_meta_data, created_at)
  values (v, 't4-' || p_tag || '-' || left(v::text, 8) || '@pomosprint.local',
          'authenticated', 'authenticated',
          jsonb_build_object('name', 't4-' || p_tag, 'avatar_id', 'avatar_16_basic'), now());
  update public.profiles set league_tier = p_tier where id = v;
  return v;
end $$;

create function pg_temp.t4_league(p_tier int, p_start timestamptz, p_end timestamptz) returns uuid
language sql as $$
  insert into public.leagues(tier, start_date, end_date) values (p_tier, p_start, p_end) returning id
$$;

create function pg_temp.t4_member(p_league uuid, p_user uuid, p_points int, p_joined timestamptz)
returns void language sql as $$
  insert into public.league_memberships(league_id, user_id, weekly_points, joined_at)
  values (p_league, p_user, p_points, p_joined)
$$;

-- Kullanıcının (tek) aktif üyeliği
create function pg_temp.t4_league_of(p_user uuid) returns uuid language sql as $$
  select lm.league_id from public.league_memberships lm
  join public.leagues l on l.id = lm.league_id and l.is_active
  where lm.user_id = p_user
$$;

create function pg_temp.t4_points_of(p_user uuid) returns int language sql as $$
  select lm.weekly_points from public.league_memberships lm where lm.user_id = p_user
$$;

create function pg_temp.t4_tier_of(p_user uuid) returns int language sql as $$
  select league_tier from public.profiles where id = p_user
$$;

create function pg_temp.t4_awards_of(p_user uuid) returns text language sql as $$
  select coalesce(string_agg(avatar_id, ',' order by avatar_id), '')
  from public.avatar_unlocks where user_id = p_user and unlock_type = 'league_award'
$$;

-- Bir kategori açar (postgres olarak; RLS/limit trigger'ı yine çalışır).
create function pg_temp.t4_category(p_user uuid) returns uuid language sql as $$
  insert into public.categories(user_id, name, color_hex) values (p_user, 't4-ders', '#FF0000') returning id
$$;
