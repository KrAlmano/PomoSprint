-- ============================================================
-- ÖNERİ 12: delete_own_account — e-postaya bağlı kayıtlar     ÖNCELİK: P1 (KVKK)
-- ============================================================
-- 3 Ekim 2026'da canlı tanım (pg_get_functiondef) ve yabancı anahtarlar
-- okunarak yazıldı. Canlı gövde:
--
--   CREATE OR REPLACE FUNCTION public.delete_own_account() RETURNS void
--    LANGUAGE plpgsql SECURITY DEFINER SET search_path TO 'public'
--   AS $function$ begin
--     if auth.uid() is null then raise exception 'Not authenticated'; end if;
--     delete from auth.users where id = auth.uid();
--   end; $function$
--
-- Canlıda doğru olanlar: auth.users silinince profiles, study_sessions,
-- friendships (iki yön), marketing_subscribers (user_id) auth.users'a;
-- categories, league_memberships, activity_feed, avatar_unlocks profiles'a
-- ON DELETE CASCADE ile bağlı; hepsi siliniyor. auth.identities/sessions
-- da cascade. Storage bucket'ı yok. EXECUTE yalnızca authenticated'da.
--
-- AÇIKLAR (bu öneri kapatır):
--  1. public.waitlist (landing bekleme listesi) e-postayla tutuluyor,
--     yabancı anahtar yok: hesap silinince aynı e-postanın bekleme listesi
--     kaydı kalıyor.
--  2. public.marketing_subscribers'ta user_id'si boş (eski / landing
--     kaynaklı) satır varsa cascade onu silmiyor.
--  3. search_path'te pg_temp yok (AGENTS.md §4.6 kuralı).
-- E-postaya göre silme yalnızca e-postası DOĞRULANMIŞ hesapta yapılır:
-- başkasının e-postasıyla açılmış, doğrulanmamış bir hesap o kişinin
-- bekleme listesi kaydını silemez.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR
--  1. Canlı gövdenin hâlâ yukarıdakiyle aynı olduğunu doğrulayın:
--       select pg_get_functiondef('public.delete_own_account()'::regprocedure);
--  2. SQL Editor'de önce kuru çalıştırma:
--       supabase/tests/proposed_12_delete_own_account_dryrun.sql
--     Sonda DRYRUN_RESULT hatası beklenir; her satır 'true' olmalı.
--  3. Bu dosyayı \echo/\quit satırları olmadan
--     supabase/migrations/<zaman damgası>_delete_own_account_email_data.sql
--     olarak kopyalayıp SQL Editor'de çalıştırın.
--  4. Geri alma: supabase/proposed/12_delete_own_account_down.sql
-- ============================================================

\echo 'supabase/proposed/12: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

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

  -- Yalnızca doğrulanmış e-posta: başkasının adresiyle açılmış onaysız bir
  -- hesap o kişinin kayıtlarını silemesin.
  select lower(btrim(u.email)) into v_email
    from auth.users u
   where u.id = v_uid and u.email_confirmed_at is not null;

  if v_email is not null and v_email <> '' then
    -- Yabancı anahtarı olmayan, e-postaya bağlı kişisel veriler.
    delete from public.waitlist where lower(btrim(email)) = v_email;
    delete from public.marketing_subscribers where user_id is null and lower(btrim(email)) = v_email;
  end if;

  -- profiles, study_sessions, categories, friendships, league_memberships,
  -- activity_feed, avatar_unlocks, marketing_subscribers(user_id),
  -- auth.identities/sessions ON DELETE CASCADE ile silinir.
  delete from auth.users where id = v_uid;
end;
$function$;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated, service_role;

COMMIT;
