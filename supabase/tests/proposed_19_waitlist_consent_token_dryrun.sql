-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/19_waitlist_consent_token.sql (A + B)
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Öneri ve 12
-- senaryo sentetik adreslerle (@example.invalid) çalışır, en sonda bilinçli
-- bir hata (DRYRUN_RESULT) fırlatılır ve tüm işlem geri alınır.
-- Hata mesajındaki her satırın sonu 'true' olmalı.
-- Ön koşul (3 Ekim'de okundu): waitlist'te RLS açık, anon'a tablo düzeyinde
-- INSERT, politika "Allow public insert to waitlist" WITH CHECK (true).
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- A bölümü (supabase/proposed/19_waitlist_consent_token.sql ile aynı)
-- ---------------------------------------------------------------------------
ALTER TABLE public.waitlist
  ADD COLUMN IF NOT EXISTS unsubscribe_token uuid NOT NULL DEFAULT gen_random_uuid(),
  ADD COLUMN IF NOT EXISTS marketing_consent boolean,
  ADD COLUMN IF NOT EXISTS consent_text_version text,
  ADD COLUMN IF NOT EXISTS consented_at timestamptz;

CREATE UNIQUE INDEX IF NOT EXISTS waitlist_unsubscribe_token_key
  ON public.waitlist (unsubscribe_token);

ALTER TABLE public.waitlist
  ADD CONSTRAINT waitlist_consent_text_version_check
  CHECK (consent_text_version IS NULL OR length(consent_text_version) BETWEEN 1 AND 64);

CREATE OR REPLACE FUNCTION public.waitlist_set_consent_time()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
begin
  new.consented_at := case when new.marketing_consent is true then now() else null end;
  return new;
end;
$function$;

REVOKE ALL ON FUNCTION public.waitlist_set_consent_time() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS waitlist_set_consent_time ON public.waitlist;
CREATE TRIGGER waitlist_set_consent_time
  BEFORE INSERT ON public.waitlist
  FOR EACH ROW EXECUTE FUNCTION public.waitlist_set_consent_time();

DO $dry$
DECLARE
  e1 text := 'dryrun19-a-' || gen_random_uuid() || '@example.invalid';
  e2 text := 'dryrun19-b-' || gen_random_uuid() || '@example.invalid';
  e3 text := 'dryrun19-c-' || gen_random_uuid() || '@example.invalid';
  e4 text := 'dryrun19-d-' || gen_random_uuid() || '@example.invalid';
  v_int int; v_int2 int; v_bool boolean;
  res text[] := '{}';
BEGIN
  -- T01 mevcut her satıra ayrı token yazıldı
  SELECT count(*), count(DISTINCT unsubscribe_token) INTO v_int, v_int2 FROM public.waitlist;
  res := res || ('T01 mevcut satırlarda benzersiz token (' || v_int || '): ' || (v_int = v_int2)::text);

  -- T02 A: canlı sitenin isteği ({email}) çalışmaya devam eder, onay boş kalır
  EXECUTE 'SET LOCAL ROLE anon';
  INSERT INTO public.waitlist (email) VALUES (e1);
  EXECUTE 'RESET ROLE';
  SELECT marketing_consent IS NULL AND consented_at IS NULL AND unsubscribe_token IS NOT NULL
    INTO v_bool FROM public.waitlist WHERE email = e1;
  res := res || ('T02 A: yalnızca e-postalı kayıt çalışır, onay boş: ' || coalesce(v_bool, false)::text);

  -- T03 A: onaylı kayıtta onay zamanını sunucu yazar (istemcinin değeri yok sayılır)
  EXECUTE 'SET LOCAL ROLE anon';
  INSERT INTO public.waitlist (email, marketing_consent, consent_text_version, consented_at)
    VALUES (e2, true, 'waitlist-2026-10-03', '2000-01-01T00:00:00Z');
  EXECUTE 'RESET ROLE';
  SELECT consented_at = now() INTO v_bool FROM public.waitlist WHERE email = e2;
  res := res || ('T03 A: consented_at sunucuda yazılır: ' || coalesce(v_bool, false)::text);

  -- -------------------------------------------------------------------------
  -- B bölümü (öneri dosyasıyla aynı)
  -- -------------------------------------------------------------------------
  EXECUTE 'REVOKE INSERT ON public.waitlist FROM anon';
  EXECUTE 'GRANT INSERT (email, marketing_consent, consent_text_version) ON public.waitlist TO anon';
  EXECUTE 'ALTER POLICY "Allow public insert to waitlist" ON public.waitlist '
       || 'WITH CHECK (marketing_consent IS TRUE AND consent_text_version IS NOT NULL)';

  -- T04 B: onaysız (yalnızca e-posta) kayıt RLS ile reddedilir
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist (email) VALUES (e3);
    res := res || 'T04 B: onaysız kayıt reddedilir: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T04 B: onaysız kayıt reddedilir: ' || (SQLERRM LIKE '%row-level security%')::text);
  END;
  EXECUTE 'RESET ROLE';

  -- T05 B: marketing_consent = false reddedilir
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist (email, marketing_consent, consent_text_version) VALUES (e3, false, 'waitlist-2026-10-03');
    res := res || 'T05 B: onay false reddedilir: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T05 B: onay false reddedilir: ' || (SQLERRM LIKE '%row-level security%')::text);
  END;
  EXECUTE 'RESET ROLE';

  -- T06 B: onay metni sürümü olmadan reddedilir
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist (email, marketing_consent) VALUES (e3, true);
    res := res || 'T06 B: sürümsüz onay reddedilir: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T06 B: sürümsüz onay reddedilir: ' || (SQLERRM LIKE '%row-level security%')::text);
  END;
  EXECUTE 'RESET ROLE';

  -- T07 B: anon token'ı kendisi belirleyemez
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist (email, marketing_consent, consent_text_version, unsubscribe_token)
      VALUES (e3, true, 'waitlist-2026-10-03', gen_random_uuid());
    res := res || 'T07 B: anon token yazamaz: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T07 B: anon token yazamaz: ' || (SQLERRM LIKE '%permission denied%')::text);
  END;
  EXECUTE 'RESET ROLE';

  -- T08 B: anon onay zamanını yazamaz
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist (email, marketing_consent, consent_text_version, consented_at)
      VALUES (e3, true, 'waitlist-2026-10-03', now());
    res := res || 'T08 B: anon consented_at yazamaz: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T08 B: anon consented_at yazamaz: ' || (SQLERRM LIKE '%permission denied%')::text);
  END;
  EXECUTE 'RESET ROLE';

  SELECT count(*) INTO v_int FROM public.waitlist WHERE email = e3;
  res := res || ('T09 B: reddedilen denemelerden satır kalmadı: ' || (v_int = 0)::text);

  -- T10 B: onaylı kayıt kabul edilir; token ve zaman sunucuda üretilir
  EXECUTE 'SET LOCAL ROLE anon';
  INSERT INTO public.waitlist (email, marketing_consent, consent_text_version) VALUES (e4, true, 'waitlist-2026-10-03');
  EXECUTE 'RESET ROLE';
  SELECT marketing_consent AND consented_at = now() AND unsubscribe_token IS NOT NULL
    INTO v_bool FROM public.waitlist WHERE email = e4;
  res := res || ('T10 B: onaylı kayıt kabul, zaman ve token dolu: ' || coalesce(v_bool, false)::text);

  -- T11 B: aynı adres ikinci kez 23505 verir (site bunu başarı sayar)
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    INSERT INTO public.waitlist (email, marketing_consent, consent_text_version) VALUES (e4, true, 'waitlist-2026-10-03');
    res := res || 'T11 B: yinelenen adres 23505: false'::text;
  EXCEPTION WHEN unique_violation THEN
    res := res || 'T11 B: yinelenen adres 23505: true'::text;
  END;
  EXECUTE 'RESET ROLE';

  -- T12 anon bekleme listesini okuyamaz (değişmedi)
  BEGIN
    EXECUTE 'SET LOCAL ROLE anon';
    PERFORM 1 FROM public.waitlist LIMIT 1;
    res := res || 'T12 anon okuyamaz: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T12 anon okuyamaz: ' || (SQLERRM LIKE '%permission denied%')::text);
  END;
  EXECUTE 'RESET ROLE';

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
