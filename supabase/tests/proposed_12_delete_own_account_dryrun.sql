-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/12_delete_own_account.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Öneri + 14
-- senaryo sentetik kullanıcılarla (@example.invalid) çalışır, en sonda
-- bilinçli bir hata (DRYRUN_RESULT) fırlatılır ve tüm işlem geri alınır.
-- Hata mesajındaki her satırın sonu 'true' olmalı.
--
-- Not: marketing_subscribers INSERT trigger'ı (invoke_send_welcome_email)
-- pg_net kuyruğuna istek yazar; kuyruk da işlemle birlikte geri alınır,
-- e-posta gönderilmez (adresler zaten .invalid).
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- Öneri (supabase/proposed/12_delete_own_account.sql ile aynı gövde)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.delete_own_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  select lower(btrim(u.email)) into v_email
    from auth.users u
   where u.id = v_uid and u.email_confirmed_at is not null;

  if v_email is not null and v_email <> '' then
    delete from public.waitlist where lower(btrim(email)) = v_email;
    delete from public.marketing_subscribers where user_id is null and lower(btrim(email)) = v_email;
  end if;

  delete from auth.users where id = v_uid;
end;
$function$;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated, service_role;

DO $dry$
DECLARE
  u1 uuid := gen_random_uuid();   -- doğrulanmış, verisi olan kullanıcı
  u2 uuid := gen_random_uuid();   -- doğrulanmamış
  u3 uuid := gen_random_uuid();   -- doğrulanmış, user_id'siz abonelik satırı
  e1 text; e2 text; e3 text; e_other text;
  v_cat uuid; v_code text; v_int int; v_int2 int; v_bool boolean; v_txt text;
  res text[] := '{}';
BEGIN
  e1 := 'dryrun12-a-' || u1 || '@example.invalid';
  e2 := 'dryrun12-b-' || u2 || '@example.invalid';
  e3 := 'dryrun12-c-' || u3 || '@example.invalid';
  e_other := 'dryrun12-other-' || gen_random_uuid() || '@example.invalid';

  -- Yetkiler
  SELECT has_function_privilege('anon', 'public.delete_own_account()', 'execute') INTO v_bool;
  res := res || ('T01 anon çağıramaz: ' || (NOT v_bool)::text);
  SELECT has_function_privilege('authenticated', 'public.delete_own_account()', 'execute') INTO v_bool;
  res := res || ('T02 authenticated çağırabilir: ' || v_bool::text);
  SELECT array_to_string(proconfig, ',') INTO v_txt FROM pg_proc WHERE oid = 'public.delete_own_account()'::regprocedure;
  res := res || ('T03 search_path pg_temp içerir (' || coalesce(v_txt, '') || '): ' || coalesce((v_txt LIKE '%pg_temp%')::text, 'false'));

  -- Sentetik kullanıcılar (handle_new_user profilleri oluşturur)
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role, email_confirmed_at)
  VALUES (u1, e1, '{"name":"Dry Silinecek","newsletter":true}', 'authenticated', 'authenticated', now()),
         (u2, e2, '{"name":"Dry Onaysiz"}', 'authenticated', 'authenticated', NULL),
         (u3, e3, '{"name":"Dry Arkadas"}', 'authenticated', 'authenticated', now());

  INSERT INTO public.waitlist (email) VALUES (upper(e1)), (e2), (e3), (e_other);
  INSERT INTO public.marketing_subscribers (user_id, email) VALUES (u1, e1), (NULL, e3);

  -- u1 veri üretir: kategori, seans (lig üyeliği), arkadaşlık (u3)
  SELECT friend_code INTO v_code FROM public.profiles WHERE id = u3;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_cat := public.create_category('Dry Silme', '#FF0000', 'book');
  PERFORM public.complete_study_session(gen_random_uuid(), v_cat, 25, false, 1500, now() - interval '2 hours');
  PERFORM public.add_friend_by_code(v_code);
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u3, 'role', 'authenticated')::text, true);
  PERFORM public.respond_friend_request(u1, true);
  EXECUTE 'RESET ROLE';

  SELECT (SELECT count(*) FROM public.profiles WHERE id = u1)
       + (SELECT count(*) FROM public.study_sessions WHERE user_id = u1)
       + (SELECT count(*) FROM public.categories WHERE user_id = u1)
       + (SELECT count(*) FROM public.friendships WHERE user_id = u1 OR friend_id = u1)
       + (SELECT count(*) FROM public.league_memberships WHERE user_id = u1)
       + (SELECT count(*) FROM public.avatar_unlocks WHERE user_id = u1)
       + (SELECT count(*) FROM public.marketing_subscribers WHERE user_id = u1)
    INTO v_int;
  res := res || ('T04 silmeden önce u1 verisi var (' || v_int || ' satır): ' || (v_int >= 7)::text);

  -- u1 hesabını siler
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u1, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.delete_own_account();
  EXECUTE 'RESET ROLE';

  SELECT count(*) INTO v_int FROM auth.users WHERE id = u1;
  res := res || ('T05 auth.users satırı silindi: ' || (v_int = 0)::text);

  SELECT (SELECT count(*) FROM public.profiles WHERE id = u1)
       + (SELECT count(*) FROM public.study_sessions WHERE user_id = u1)
       + (SELECT count(*) FROM public.categories WHERE user_id = u1)
       + (SELECT count(*) FROM public.friendships WHERE user_id = u1 OR friend_id = u1)
       + (SELECT count(*) FROM public.league_memberships WHERE user_id = u1)
       + (SELECT count(*) FROM public.activity_feed WHERE user_id = u1)
       + (SELECT count(*) FROM public.avatar_unlocks WHERE user_id = u1)
       + (SELECT count(*) FROM public.marketing_subscribers WHERE user_id = u1 OR lower(email) = e1)
    INTO v_int;
  res := res || ('T06 u1 kişisel verisi kalmadı (' || v_int || '): ' || (v_int = 0)::text);

  SELECT count(*) INTO v_int FROM public.waitlist WHERE lower(email) = e1;
  res := res || ('T07 bekleme listesi kaydı (büyük harfli) silindi: ' || (v_int = 0)::text);

  SELECT count(*) INTO v_int FROM public.friendships WHERE user_id = u3 OR friend_id = u3;
  res := res || ('T08 arkadaşın tarafındaki kayıt da silindi: ' || (v_int = 0)::text);

  SELECT count(*) INTO v_int FROM public.profiles WHERE id = u3;
  res := res || ('T09 diğer kullanıcının profili duruyor: ' || (v_int = 1)::text);

  SELECT count(*) INTO v_int FROM public.waitlist WHERE email IN (e_other, e2, e3);
  res := res || ('T10 başka e-postaların bekleme kaydı duruyor: ' || (v_int = 3)::text);

  -- u3: user_id'siz abonelik satırı e-postayla silinir
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u3, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.delete_own_account();
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_int FROM public.marketing_subscribers WHERE lower(email) = e3;
  res := res || ('T11 user_id''siz abonelik satırı silindi: ' || (v_int = 0)::text);
  SELECT count(*) INTO v_int FROM public.waitlist WHERE email = e3;
  res := res || ('T12 u3 bekleme kaydı silindi: ' || (v_int = 0)::text);

  -- u2: doğrulanmamış e-posta, bekleme listesi kaydına dokunulmaz
  PERFORM set_config('request.jwt.claims', json_build_object('sub', u2, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.delete_own_account();
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_int FROM auth.users WHERE id = u2;
  SELECT count(*) INTO v_int2 FROM public.waitlist WHERE email = e2;
  res := res || ('T13 onaysız hesap silinir, başkasının olabilecek bekleme kaydı kalır: '
                 || (v_int = 0 AND v_int2 = 1)::text);

  -- Oturumsuz çağrı
  PERFORM set_config('request.jwt.claims', '', true);
  BEGIN
    PERFORM public.delete_own_account();
    res := res || 'T14 oturumsuz çağrı reddedilir: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T14 oturumsuz çağrı reddedilir: ' || (SQLERRM = 'Not authenticated')::text);
  END;

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
