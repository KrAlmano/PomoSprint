-- t4-09: İstemci çapraz kontrolü için fixture. Odalar kurulur, her odada
-- bir üyenin gördüğü get_my_league_ranking satırları (istemcinin aldığı JSON)
-- alınır, process_weekly_leagues çalıştırılır ve her üyenin GERÇEK sonucu
-- (kademe önce/sonra, ödüller) eklenir. Çıktı tek JSON. TAMAMI ROLLBACK.
--   psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -qAt \
--     -f tool/local_supabase/e2e/t4_league_avatar/09_capture_league_fixture.sql \
--     > tool/local_supabase/e2e/t4_league_avatar/league_fixture.json
-- (psql'i bu klasörde çalıştırın ya da \i yolunu düzeltin.)
\set ON_ERROR_STOP on
\o /dev/null
begin;
\i _helpers.sql

create temp table t4_u(tag text primary key, id uuid, room text) on commit drop;
create temp table t4_rows(room text, rows jsonb) on commit drop;
grant select on t4_u to authenticated;
grant insert on t4_rows to authenticated;
create temp table t4_e as
select (date_trunc('week', (now() at time zone 'Europe/Istanbul')::date::timestamp) - interval '1 second')
         at time zone 'Europe/Istanbul' as e;

do $$
declare
  e timestamptz := (select e from t4_e);
  spec record; l uuid; u uuid; i int; k int := 0;
begin
  for spec in
    select * from (values
      ('A', 1, array[12,0,0,0]),
      ('B', 2, array[50,30,30,20,10,10,5,5,5,0,0,0]),
      ('C', 3, array(select 100 - 2 * g from generate_series(1,22) g)),
      ('D', 4, array[5]),
      ('E', 5, array[40,40] || array_fill(0, array[28])),
      ('F', 2, array[0,0,0]),
      ('G', 3, array[9,8,7,6,5,4,3,2,1,0])
    ) s(room, tier, pts)
  loop
    k := k + 1;
    l := pg_temp.t4_league(spec.tier, '2000-01-01'::timestamptz + make_interval(days => k), e);
    for i in 1..array_length(spec.pts, 1) loop
      u := pg_temp.t4_user(lower(spec.room) || i, spec.tier);
      insert into t4_u values (lower(spec.room) || i, u, spec.room);
      perform pg_temp.t4_member(l, u, spec.pts[i], '2026-01-01'::timestamptz + make_interval(mins => i));
    end loop;
  end loop;
end $$;

-- Her odanın 1. üyesinin gözünden (istemcinin çağırdığı RPC)
do $$
declare r record;
begin
  for r in select room, id from t4_u where tag ~ '^[a-z]1$' order by room loop
    perform pg_temp.t4_as(r.id);
    set local role authenticated;
    insert into t4_rows select r.room, coalesce(jsonb_agg(to_jsonb(x)), '[]') from public.get_my_league_ranking() x;
    reset role;
  end loop;
end $$;

create temp table t4_before as select u.tag, p.name, p.league_tier from t4_u u join public.profiles p on p.id = u.id;
select public.process_weekly_leagues();

\o
select jsonb_pretty(jsonb_build_object(
  'captured_at', now(),
  'rooms', (select jsonb_object_agg(room, rows) from t4_rows),
  'outcomes', (select jsonb_object_agg(b.name, jsonb_build_object(
                  'tier_before', b.league_tier,
                  'tier_after', p.league_tier,
                  'awards', coalesce((select jsonb_agg(avatar_id order by avatar_id) from public.avatar_unlocks a
                                      where a.user_id = u.id and a.unlock_type = 'league_award'), '[]')))
               from t4_before b join t4_u u using (tag) join public.profiles p on p.id = u.id)));
rollback;
