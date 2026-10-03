-- ============================================================================
-- KURU ÇALIŞTIRMA: supabase/proposed/13_sunucu_butunluk.sql
-- (canlıda hiçbir şeyi kalıcı DEĞİŞTİRMEZ)
-- Supabase Dashboard > SQL Editor'e yapıştırıp Run'a basın. Önce sentetik bir
-- "eski" kullanıcı (yasaklı adlı, 45 karakterlik kategorili, lig üyeliği olan)
-- bugünkü tanımlarla oluşturulur; sonra öneri uygulanır ve 50 senaryo
-- sentetik kullanıcılarla (@example.invalid) çalışır. En sonda bilinçli bir
-- hata (DRYRUN_RESULT) fırlatılır ve her şey geri alınır.
-- Hata mesajındaki her satırın sonu 'true' olmalı.
--
-- SIRA: uygulama sırası 12 → 15 → 16 → 19 → 13 → 14; bu DRYRUN 19'dan
-- sonra, 13'ten (ve 14'ten) ÖNCE çalıştırılır. 14 uygulanmışsa öneri gövdesinin
-- ön koşulu 'proposed/13 ön koşulu: ...' hatasıyla durur.
--
-- Notlar:
--  - Sentetik ligler oluşturulur; gerçek liglere ve cron'a dokunulmaz
--    (process_weekly_leagues çağrılmaz, devri aynı UPDATE'lerle taklit eder).
--  - Öneri profiles/categories/leagues/league_memberships/study_sessions
--    tablolarında ALTER yapar: işlem süresince (birkaç saniye) bu tablolar
--    kilitli kalır. Az trafikli bir anda çalıştırın.
--  - Bu dosyanın ortasındaki öneri gövdesi supabase/proposed/13_sunucu_
--    butunluk.sql'den (BEGIN/COMMIT hariç) birebir kopyalanmıştır.
-- ============================================================================
BEGIN;

-- ---------------------------------------------------------------------------
-- Değişiklikten ÖNCE (bugünkü canlı tanımlarla): eski kullanıcı
-- ---------------------------------------------------------------------------
CREATE TEMP TABLE dry13 ON COMMIT DROP AS
SELECT gen_random_uuid() AS u_legacy, gen_random_uuid() AS l_old;

INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
SELECT u_legacy, 'dryrun13-l-' || u_legacy || '@example.invalid', '{"name":"Dry Orospu Eski"}', 'authenticated', 'authenticated'
FROM dry13;
INSERT INTO public.leagues (id, tier, end_date) SELECT l_old, 1, now() + interval '3 days' FROM dry13;
INSERT INTO public.league_memberships (league_id, user_id, weekly_points) SELECT l_old, u_legacy, 7 FROM dry13;
INSERT INTO public.categories (user_id, name, color_hex, icon_name)
SELECT u_legacy, repeat('U', 45), '#EF4444', 'book' FROM dry13;

-- ---------------------------------------------------------------------------
-- Öneri (supabase/proposed/13_sunucu_butunluk.sql, BEGIN/COMMIT hariç)
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- 0) Ön koşul: değiştirilecek canlı gövdeler 3 Ekim 2026'dakiyle aynı mı?
-- ---------------------------------------------------------------------------
-- md5(pg_get_functiondef) canlıdan okundu (ADIMLAR 1'deki tablo). Farklıysa
-- hiçbir şey yapılmadan durulur. Özellikle proposed/14 13'ten ÖNCE
-- uygulanmışsa (handle_new_user ve add_friend_by_code'u değiştirir) 13 onun
-- engel / onay / nötr ad değişikliklerini sessizce ezmesin diye durur.
-- 12, 15, 16 ve 19 bu fonksiyonlara dokunmaz; önce ya da sonra olabilirler.
DO $pre$
DECLARE
    v_expected constant jsonb := '{
        "add_friend_by_code(text)": "d59affef7f113a3072d2de604bb9506f",
        "complete_study_session(uuid,uuid,integer,boolean,integer,timestamp with time zone)": "592ede066173f30b64006f02b5141756",
        "ensure_user_in_league(uuid,integer)": "e5674f687157135f7c5feaba2de56a7e",
        "handle_new_user()": "ae6cedf2e0e0995ec759b69e20ada604",
        "process_weekly_leagues()": "3d547d20a94f32e3cf531a7c3888d536",
        "start_study_session(integer,text)": "706f87a96d7b6d7d6c776aa64ecb3772"
    }';
    r record;
    v_bad text[] := '{}';
BEGIN
    FOR r IN SELECT key, value FROM jsonb_each_text(v_expected) LOOP
        IF to_regprocedure('public.' || r.key) IS NULL
           OR md5(pg_get_functiondef(to_regprocedure('public.' || r.key))) IS DISTINCT FROM r.value THEN
            v_bad := v_bad || r.key;
        END IF;
    END LOOP;
    IF to_regnamespace('ops') IS NOT NULL OR to_regclass('public.user_blocks') IS NOT NULL THEN
        v_bad := v_bad || 'proposed/14 uygulanmış görünüyor (13, 14''ten ÖNCE uygulanmalı; önce 14_down)'::text;
    END IF;
    IF array_length(v_bad, 1) > 0 THEN
        RAISE EXCEPTION 'proposed/13 ön koşulu: canlı tanım beklenenden farklı: %. Dosyayı yeni gövdeye uyarlayın.',
            array_to_string(v_bad, ', ');
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- A) UX-08: app_config + get_app_config
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.app_config (
    key text PRIMARY KEY CHECK (key ~ '^[a-z][a-z0-9_]{0,62}$'),
    value jsonb NOT NULL DEFAULT 'null'::jsonb,
    is_public boolean NOT NULL DEFAULT false,
    description text,
    updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_config FROM PUBLIC, anon, authenticated;

INSERT INTO public.app_config (key, value, is_public, description) VALUES
  ('min_supported_version',
   '{"android": {"version": "1.0.0", "build": 1}, "ios": {"version": "1.0.0", "build": 1}}', true,
   'Bu build numarasının altındaki istemci engelleyen güncelleme ekranı gösterir.'),
  ('latest_version',
   '{"android": {"version": "1.0.0", "build": 1}, "ios": {"version": "1.0.0", "build": 1}}', true,
   'Mağazadaki en yeni sürüm; altındaki istemci kapatılabilir güncelleme bandı gösterir.'),
  ('store_url', '{"android": null, "ios": null}', true,
   'Güncelle butonunun açacağı mağaza adresleri.'),
  ('unverified_session_daily_cap', 'null', true,
   'UX-01: sunucu başlangıç kaydı olmayan seanslardan aynı çalışma gününde ödül alabilecek en fazla sayı. null = sınır yok.'),
  ('friend_code_length', '6', true,
   'KVKK-17: yeni arkadaş kodu uzunluğu (6-8, Crockford base32). İstemci 8 karakter kabul edince 8.'),
  ('friend_code_attempts_per_hour', '20', false,
   'KVKK-17: kullanıcı başına saatlik add_friend_by_code deneme sınırı.')
ON CONFLICT (key) DO NOTHING;

-- Sunucu içi okuma yardımcısı: sayı değilse ya da anahtar yoksa NULL.
CREATE OR REPLACE FUNCTION public.app_config_int(p_key text)
 RETURNS integer
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT CASE WHEN jsonb_typeof(c.value) = 'number'
              THEN floor((c.value #>> '{}')::numeric)::integer END
    FROM public.app_config c
   WHERE c.key = p_key
$function$;

CREATE OR REPLACE FUNCTION public.get_app_config()
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object('server_time', now(), 'config_schema', 1)
      || COALESCE((SELECT jsonb_object_agg(c.key, c.value)
                     FROM public.app_config c
                    WHERE c.is_public), '{}'::jsonb)
$function$;

-- ---------------------------------------------------------------------------
-- B) İÇERİK DOĞRULAMA: yasaklı sözcükler, temizleme, trigger'lar
-- ---------------------------------------------------------------------------
-- İstemcideki lib/utils/name_filter.dart listesinin KÜÇÜK bir alt kümesi,
-- aynı eşleşme türleriyle: istemcinin kabul ettiği bir ad sunucuda
-- reddedilmez. Yanlış pozitif riski olan kısa kökler bilinçli olarak yok.
CREATE TABLE IF NOT EXISTS public.blocked_name_terms (
    term text PRIMARY KEY CHECK (term ~ '^[a-z]{2,40}$'),
    match_kind text NOT NULL CHECK (match_kind IN ('exact', 'prefix', 'contains')),
    created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.blocked_name_terms ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.blocked_name_terms FROM PUBLIC, anon, authenticated;

INSERT INTO public.blocked_name_terms (term, match_kind) VALUES
  ('orospu', 'contains'), ('siktir', 'contains'), ('fuck', 'contains'),
  ('sikeyim', 'prefix'), ('sikerim', 'prefix'), ('amcik', 'prefix'),
  ('aminako', 'prefix'), ('yarrak', 'prefix'), ('dalyarak', 'prefix'),
  ('pezevenk', 'prefix'), ('kahpe', 'prefix'), ('ibne', 'prefix'),
  ('gotveren', 'prefix'), ('cunt', 'prefix'), ('asshole', 'prefix'),
  ('whore', 'prefix'), ('nigger', 'prefix'), ('faggot', 'prefix'),
  ('cocksucker', 'prefix'),
  ('amk', 'exact'), ('nigga', 'exact'), ('niggas', 'exact'), ('hitler', 'exact')
ON CONFLICT (term) DO NOTHING;

-- Saklanacak metin: kontrol, yön (bidi) ve görünmez biçim karakterleri
-- silinir, boşluk dizileri tek boşluğa iner, baş/son boşluk atılır.
-- (ZWJ/ZWNJ emoji ve bazı yazı sistemleri için korunur.)
CREATE OR REPLACE FUNCTION public.clean_display_text(p_text text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT btrim(regexp_replace(
           regexp_replace(p_text,
             '[\u0001-\u0008\u000E-\u001F\u007F-\u009F­؜​‎‏‪-‮⁠-⁤⁦-⁩﻿]',
             '', 'g'),
           '[\s   -     　]+', ' ', 'g'))
$function$;

-- İstemcideki NameFilter.isOffensive ile aynı normalizasyon ve eşleşme:
-- Türkçe İ/I → i, aksanlar ASCII, basit leet (0→o 1→i 3→e 4→a 5→s 7→t
-- @→a $→s !→i |→i €→e), harf harf yazım birleştirilir, tekrar eden harfler
-- ayrıca tek harfe indirgenmiş hâliyle denenir. Eşleşme sözcük düzeyinde.
CREATE OR REPLACE FUNCTION public.display_text_is_allowed(p_text text)
 RETURNS boolean
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_folded text;
    v_chunk text;
    v_word text;
    v_words text[] := '{}';
    v_tokens text[] := '{}';
    v_run text := '';
    v_token text;
    v_collapsed text;
BEGIN
    IF p_text IS NULL OR btrim(p_text) = '' THEN
        RETURN true;
    END IF;

    v_folded := translate(p_text, 'İIÇĞÖŞÜÂÀÁÄÃÅÊÈÉËÎÌÍÏÔÒÓÕÛÙÚÑ', 'iicgosuaaaaaaeeeeiiiioooouuun');
    v_folded := lower(v_folded);
    v_folded := regexp_replace(v_folded, '[̀-ͯ​-‍­﻿]', '', 'g');
    v_folded := translate(v_folded, 'ıçğöşüâàáäãåêèéëîìíïôòóõûùúñÿ', 'icgosuaaaaaaeeeeiiiioooouuuny');
    v_folded := replace(v_folded, 'ß', 'ss');

    FOREACH v_chunk IN ARRAY regexp_split_to_array(v_folded, '[^a-z0-9@$!|€]+') LOOP
        CONTINUE WHEN v_chunk = '' OR v_chunk !~ '[a-z]';
        v_chunk := translate(v_chunk, '013457@$!|€', 'oieastasiie');
        FOREACH v_word IN ARRAY regexp_split_to_array(v_chunk, '[^a-z]+') LOOP
            CONTINUE WHEN v_word = '';
            v_words := v_words || v_word;
        END LOOP;
    END LOOP;

    -- "f u c k", "f.u.c.k" → "fuck"
    FOREACH v_word IN ARRAY v_words LOOP
        IF char_length(v_word) = 1 THEN
            v_run := v_run || v_word;
        ELSE
            IF v_run <> '' THEN
                v_tokens := v_tokens || v_run;
                v_run := '';
            END IF;
            v_tokens := v_tokens || v_word;
        END IF;
    END LOOP;
    IF v_run <> '' THEN
        v_tokens := v_tokens || v_run;
    END IF;

    FOREACH v_token IN ARRAY v_tokens LOOP
        v_collapsed := regexp_replace(v_token, '(.)\1+', '\1', 'g');
        IF EXISTS (
            SELECT 1 FROM public.blocked_name_terms t
             WHERE (t.match_kind = 'exact' AND (v_token = t.term OR v_collapsed = t.term))
                OR (t.match_kind = 'prefix' AND (left(v_token, char_length(t.term)) = t.term OR v_collapsed = t.term))
                OR (t.match_kind = 'contains' AND (strpos(v_token, t.term) > 0 OR strpos(v_collapsed, t.term) > 0))
        ) THEN
            RETURN false;
        END IF;
    END LOOP;

    RETURN true;
END;
$function$;

-- profiles.name: yalnızca ad YAZILIRKEN (INSERT ya da ad değişimi) çalışır;
-- eski bir ad yüzünden diğer kolonların güncellenmesi (puan, seri, ayarlar)
-- engellenmez. Uzunluk mevcut CHECK'te (1..50).
CREATE OR REPLACE FUNCTION public.enforce_profile_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.name IS NOT DISTINCT FROM OLD.name THEN
        RETURN NEW;
    END IF;
    NEW.name := public.clean_display_text(NEW.name);
    IF NEW.name IS NOT NULL AND NOT public.display_text_is_allowed(NEW.name) THEN
        RAISE EXCEPTION 'profile_name_not_allowed'
            USING ERRCODE = 'check_violation',
                  HINT = 'Görünen ad engellenen bir ifade içeriyor.';
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS enforce_profile_name ON public.profiles;
CREATE TRIGGER enforce_profile_name
    BEFORE INSERT OR UPDATE OF name ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.enforce_profile_name();

-- categories.name: tabloya doğrudan INSERT/UPDATE yetkisi olduğu için
-- RPC'ler yerine trigger. Uzunluk istemciyle aynı (kCategoryNameMaxLength
-- = 40). Mevcut uzun adlar yalnızca ad değişirse denetlenir (arşivleme,
-- sıralama gibi güncellemeler etkilenmez); bu yüzden CHECK değil trigger.
CREATE OR REPLACE FUNCTION public.enforce_category_name()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.name IS NOT DISTINCT FROM OLD.name THEN
        RETURN NEW;
    END IF;
    NEW.name := public.clean_display_text(NEW.name);
    IF NEW.name IS NULL OR char_length(NEW.name) < 1 OR char_length(NEW.name) > 40 THEN
        RAISE EXCEPTION 'category_name_invalid_length'
            USING ERRCODE = 'check_violation',
                  HINT = 'Kategori adı 1-40 karakter olmalı.';
    END IF;
    IF NOT public.display_text_is_allowed(NEW.name) THEN
        RAISE EXCEPTION 'category_name_not_allowed'
            USING ERRCODE = 'check_violation',
                  HINT = 'Kategori adı engellenen bir ifade içeriyor.';
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS enforce_category_name ON public.categories;
CREATE TRIGGER enforce_category_name
    BEFORE INSERT OR UPDATE OF name ON public.categories
    FOR EACH ROW EXECUTE FUNCTION public.enforce_category_name();

-- start_study_session: canlı gövde (LANGUAGE sql) + doğrulama. Kategori adı
-- serbest metin olduğu ve arkadaşlara görünür olduğu için temizlenir, 40
-- karaktere kısaltılır, yasaklıysa boş bırakılır. Süre 0..50 (debug build'in
-- kısa sayacında kalan dakika 0 olabilir); dışı 'invalid duration' (istemci
-- bu çağrının hatasını yutuyor, seans etkilenmez).
CREATE OR REPLACE FUNCTION public.start_study_session(p_duration_minutes integer, p_category_name text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_name text;
BEGIN
    IF p_duration_minutes IS NULL OR p_duration_minutes < 0 OR p_duration_minutes > 50 THEN
        RAISE EXCEPTION 'invalid duration: 0..50 minutes allowed';
    END IF;

    v_name := nullif(btrim(left(public.clean_display_text(p_category_name), 40)), '');
    IF v_name IS NOT NULL AND NOT public.display_text_is_allowed(v_name) THEN
        v_name := NULL;
    END IF;

    UPDATE public.profiles
    SET
      active_session_ends_at = now() + (p_duration_minutes * interval '1 minute'),
      active_session_category_name = v_name
    WHERE id = auth.uid();
END;
$function$;

-- ---------------------------------------------------------------------------
-- C) KVKK-20: profiles.email kopyası (1. aşama)
-- ---------------------------------------------------------------------------
-- Okuyan yok; e-postanın tek kaynağı auth.users. Kolon boşaltılır ve her
-- yazımda boş tutulur. Eski istemcinin yedek upsert'ü (id, email, name,
-- avatar_id) kırılmasın diye kolon ve INSERT(email) yetkisi kalır; gönderilen
-- değer trigger'la atılır. 2. aşama dosya sonunda.
ALTER TABLE public.profiles ALTER COLUMN email DROP NOT NULL;

CREATE OR REPLACE FUNCTION public.discard_profile_email()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    NEW.email := NULL;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS discard_profile_email ON public.profiles;
CREATE TRIGGER discard_profile_email
    BEFORE INSERT OR UPDATE OF email ON public.profiles
    FOR EACH ROW EXECUTE FUNCTION public.discard_profile_email();

UPDATE public.profiles SET email = NULL WHERE email IS NOT NULL;

COMMENT ON COLUMN public.profiles.email IS
  'KULLANILMIYOR (proposed/13, KVKK-20): her zaman NULL; e-posta auth.users''ta. 2. aşamada kaldırılacak.';

-- ---------------------------------------------------------------------------
-- D) ARKADAŞ KODU (KVKK-17) ve KAYIT ÇAKIŞMASI
-- ---------------------------------------------------------------------------
-- Crockford base32 (I, L, O, U yok). Rastgelelik gen_random_uuid()'nin
-- (güçlü rastgele) sabit bit içermeyen baytlarından; uzunluk 6..8 (kolon
-- varchar(8)). Mevcut 6 hex kodlar bu alfabenin alt kümesidir, değişmez.
CREATE OR REPLACE FUNCTION public.generate_friend_code(p_length integer DEFAULT 6)
 RETURNS text
 LANGUAGE plpgsql
 VOLATILE
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    c_alphabet constant text := '0123456789ABCDEFGHJKMNPQRSTVWXYZ';
    v_len integer := least(greatest(coalesce(p_length, 6), 6), 8);
    v_bytes bytea := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    v_positions integer[] := ARRAY[0, 1, 2, 3, 4, 5, 9, 10, 11, 12, 13, 14, 15];
    v_code text := '';
BEGIN
    FOR i IN 1..v_len LOOP
        v_code := v_code || substr(c_alphabet, (get_byte(v_bytes, v_positions[i]) % 32) + 1, 1);
    END LOOP;
    RETURN v_code;
END;
$function$;

-- Kullanıcının yazdığı kod: boşluk, tire, alt çizgi, nokta atılır; büyük
-- harf; Crockford eşlemesi O→0, I→1, L→1 (eski hex kodlarda da bu harfler yok).
CREATE OR REPLACE FUNCTION public.normalize_friend_code(p_code text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
  SELECT translate(upper(regexp_replace(coalesce(p_code, ''), '[\s_.-]+', '', 'g')), 'OIL', '011')
$function$;

-- İstemcinin yedek INSERT'ünde (handle_new_user'ı atlayan) varsayılan.
ALTER TABLE public.profiles ALTER COLUMN friend_code SET DEFAULT public.generate_friend_code(6);

-- Saatlik deneme sayacı (sabit pencere, kullanıcı başına tek satır).
CREATE TABLE IF NOT EXISTS public.friend_code_attempts (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    window_started_at timestamptz NOT NULL DEFAULT now(),
    attempts integer NOT NULL DEFAULT 0
);
ALTER TABLE public.friend_code_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.friend_code_attempts FROM PUBLIC, anon, authenticated;

-- handle_new_user: canlı gövde + (1) friend_code çakışmasında yeniden deneme
-- (profiles_friend_code_key ihlali artık auth.users INSERT'ünü düşürmüyor),
-- (2) Crockford kod, (3) görünen ad temizlenir ve yasaklıysa sıradaki adaya
-- düşer (metadata adı → full_name → e-posta yerel kısmı → 'Kullanıcı'),
-- (4) e-posta kopyası yazılmaz (KVKK-20), (5) search_path'e pg_temp.
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_name text;
  v_candidate text;
  v_clean text;
  v_code text;
  v_code_length integer;
  v_constraint text;
begin
  foreach v_candidate in array array[
      new.raw_user_meta_data->>'name',
      new.raw_user_meta_data->>'full_name',
      split_part(new.email, '@', 1)]
  loop
    v_clean := btrim(left(public.clean_display_text(v_candidate), 50));
    if v_clean <> '' and public.display_text_is_allowed(v_clean) then
      v_name := v_clean;
      exit;
    end if;
  end loop;
  v_name := coalesce(v_name, 'Kullanıcı');

  v_code_length := coalesce(public.app_config_int('friend_code_length'), 6);

  for v_attempt in 1..8 loop
    -- Kod alt işlemin dışında üretilir; çakışmada yalnızca INSERT geri alınır.
    v_code := public.generate_friend_code(v_code_length);
    begin
      insert into public.profiles (id, name, avatar_id, total_minutes, lifetime_points, friend_code)
      values (
        new.id,
        v_name,
        -- Yalnızca varsayılan (ücretsiz) avatarlar kayıtta seçilebilir;
        -- önceden 200 kumluk avatar_1_gamer bedava takılıyordu.
        coalesce(
          (select a.id from public.avatars a
            where a.id = new.raw_user_meta_data->>'avatar_id' and a.is_default and a.is_active),
          'avatar_16_basic'),
        0,
        0,
        v_code
      )
      on conflict (id) do update set
        name = coalesce(excluded.name, public.profiles.name);
      return new;
    exception when unique_violation then
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint is distinct from 'profiles_friend_code_key' or v_attempt = 8 then
        raise;
      end if;
    end;
  end loop;
  return new;
end;
$function$;

-- add_friend_by_code: canlı gövde + saatlik deneme sınırı, Crockford
-- normalizasyonu, makine-okunur 'code', bekleyen istekte id yok, pg_temp.
-- Türkçe 'message' metinleri eski istemciler için aynen korunur.
CREATE OR REPLACE FUNCTION public.add_friend_by_code(p_code text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
  v_code text;
  v_target record;
  v_reverse_pending boolean;
  v_limit integer;
  v_attempts integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- Deneme sayacı RAISE ile değil normal dönüşle biter; işlemle birlikte kalıcıdır.
  v_limit := coalesce(public.app_config_int('friend_code_attempts_per_hour'), 20);
  insert into public.friend_code_attempts as a (user_id, window_started_at, attempts)
  values (v_uid, now(), 1)
  on conflict (user_id) do update set
    window_started_at = case when a.window_started_at <= now() - interval '1 hour'
                             then now() else a.window_started_at end,
    attempts = case when a.window_started_at <= now() - interval '1 hour'
                    then 1 else a.attempts + 1 end
  returning a.attempts into v_attempts;

  if v_attempts > v_limit then
    return jsonb_build_object('success', false, 'code', 'rate_limited',
      'message', 'Çok fazla deneme yaptın. Lütfen bir süre sonra tekrar dene.');
  end if;

  v_code := public.normalize_friend_code(p_code);

  select id, name, avatar_id, lifetime_points, total_minutes
    into v_target
    from public.profiles
   where friend_code = v_code;

  if v_target.id is null then
    return jsonb_build_object('success', false, 'code', 'not_found', 'message', 'Bu kod ile bir kullanıcı bulunamadı.');
  end if;

  if v_target.id = v_uid then
    return jsonb_build_object('success', false, 'code', 'self_add', 'message', 'Kendini arkadaş olarak ekleyemezsin.');
  end if;

  if exists (select 1 from public.friendships where user_id = v_uid and friend_id = v_target.id and status = 'accepted') then
    return jsonb_build_object('success', false, 'code', 'already_friends', 'message', 'Bu kullanıcı zaten arkadaşın.');
  end if;

  if exists (select 1 from public.friendships where user_id = v_uid and friend_id = v_target.id and status = 'pending') then
    return jsonb_build_object('success', false, 'code', 'already_pending', 'message', 'Bu kullanıcıya zaten istek gönderdin.');
  end if;

  select exists(
    select 1 from public.friendships where user_id = v_target.id and friend_id = v_uid and status = 'pending'
  ) into v_reverse_pending;

  if v_reverse_pending then
    update public.friendships set status = 'accepted' where user_id = v_target.id and friend_id = v_uid;
    insert into public.friendships (user_id, friend_id, status) values (v_uid, v_target.id, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
    return jsonb_build_object(
      'success', true,
      'code', 'accepted',
      'auto_accepted', true,
      'friend', jsonb_build_object('id', v_target.id, 'name', v_target.name, 'avatar_id', v_target.avatar_id, 'lifetime_points', v_target.lifetime_points, 'total_minutes', v_target.total_minutes)
    );
  end if;

  insert into public.friendships (user_id, friend_id, status) values (v_uid, v_target.id, 'pending')
    on conflict (user_id, friend_id) do update set status = 'pending';

  -- Kabul edilmeden karşı tarafın kimliği dönmez (KVKK-17).
  return jsonb_build_object(
    'success', true,
    'code', 'request_sent',
    'auto_accepted', false,
    'friend', jsonb_build_object('name', v_target.name, 'avatar_id', v_target.avatar_id)
  );
end;
$function$;

-- ---------------------------------------------------------------------------
-- E) UX-01: sunucu başlangıç kaydı
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.session_starts (
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    client_uuid uuid NOT NULL,
    duration_minutes integer NOT NULL CHECK (duration_minutes IN (25, 50)),
    server_started_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, client_uuid)
);
CREATE INDEX IF NOT EXISTS session_starts_user_started_idx
    ON public.session_starts (user_id, server_started_at);
ALTER TABLE public.session_starts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.session_starts FROM PUBLIC, anon, authenticated;

ALTER TABLE public.study_sessions ADD COLUMN IF NOT EXISTS start_verified boolean;
COMMENT ON COLUMN public.study_sessions.start_verified IS
  'proposed/13 (UX-01): true = başlangıç sunucuda kayıtlı ve süre sunucu saatine göre doldu; false = doğrulanmamış; NULL = bu değişiklikten önce.';

CREATE OR REPLACE FUNCTION public.register_session_start(p_client_uuid uuid, p_duration_minutes integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_started timestamptz;
    v_recent integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_client_uuid IS NULL THEN
        RAISE EXCEPTION 'invalid client_uuid';
    END IF;
    IF p_duration_minutes IS NULL OR p_duration_minutes NOT IN (25, 50) THEN
        RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed';
    END IF;

    -- Var olan kayıt değişmez: başlangıç sonradan kaydırılamaz.
    SELECT s.server_started_at INTO v_started
      FROM public.session_starts s
     WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    IF FOUND THEN
        RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                                  'server_now', now(), 'created', false);
    END IF;

    -- Tamamlanmamış / terk edilmiş eski başlangıçlar (seans 24 saatten
    -- eskiyse zaten kabul edilmez).
    DELETE FROM public.session_starts
     WHERE user_id = v_uid AND server_started_at < now() - interval '48 hours';

    SELECT count(*) INTO v_recent
      FROM public.session_starts
     WHERE user_id = v_uid AND server_started_at > now() - interval '24 hours';
    IF v_recent >= 100 THEN
        RAISE EXCEPTION 'too_many_session_starts';
    END IF;

    INSERT INTO public.session_starts (user_id, client_uuid, duration_minutes, server_started_at)
    VALUES (v_uid, p_client_uuid, p_duration_minutes, now())
    ON CONFLICT (user_id, client_uuid) DO NOTHING
    RETURNING server_started_at INTO v_started;

    IF v_started IS NULL THEN
        SELECT s.server_started_at INTO v_started
          FROM public.session_starts s
         WHERE s.user_id = v_uid AND s.client_uuid = p_client_uuid;
    END IF;

    RETURN jsonb_build_object('client_uuid', p_client_uuid, 'server_started_at', v_started,
                              'server_now', now(), 'created', true);
END;
$function$;

-- ---------------------------------------------------------------------------
-- F) LİG DÖNEMİ SINIRI: üyeliğin şimdiki dönem başlangıcı
-- ---------------------------------------------------------------------------
ALTER TABLE public.league_memberships ADD COLUMN IF NOT EXISTS period_started_at timestamptz;
COMMENT ON COLUMN public.league_memberships.period_started_at IS
  'proposed/13: üyeliğin şimdiki lig döneminin başlangıcı. Bitişi bundan önce/eşit olan seans lig puanı almaz.';

-- Ekleme: ligin şimdiki dönemi (end_date - 14 gün). Lig değişimi (yalnızca
-- process_weekly_leagues'te, dönem devrinde): eski ligin end_date'i.
CREATE OR REPLACE FUNCTION public.league_membership_period_start()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_boundary timestamptz;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.period_started_at IS NULL THEN
            SELECT l.end_date - interval '14 days' INTO v_boundary
              FROM public.leagues l WHERE l.id = NEW.league_id;
            NEW.period_started_at := least(coalesce(v_boundary, now()), now());
        END IF;
    ELSIF NEW.league_id IS DISTINCT FROM OLD.league_id THEN
        SELECT l.end_date INTO v_boundary
          FROM public.leagues l WHERE l.id = OLD.league_id;
        NEW.period_started_at := least(coalesce(v_boundary, now()), now());
    END IF;
    RETURN NEW;
END;
$function$;

DROP TRIGGER IF EXISTS league_membership_period_start ON public.league_memberships;
CREATE TRIGGER league_membership_period_start
    BEFORE INSERT OR UPDATE OF league_id ON public.league_memberships
    FOR EACH ROW EXECUTE FUNCTION public.league_membership_period_start();

-- Dönem devri: process_weekly_leagues bitmiş bir ligin end_date'ini ileri
-- aldığında o ligde kalan üyelerin yeni dönemi eski end_date'te başlar.
-- (Bitmemiş bir ligin süresinin elle uzatılması devir sayılmaz.)
CREATE OR REPLACE FUNCTION public.league_period_rollover()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_boundary timestamptz;
BEGIN
    v_boundary := least(OLD.end_date, now());
    UPDATE public.league_memberships
       SET period_started_at = v_boundary
     WHERE league_id = NEW.id
       AND (period_started_at IS NULL OR period_started_at < v_boundary);
    RETURN NULL;
END;
$function$;

DROP TRIGGER IF EXISTS league_period_rollover ON public.leagues;
CREATE TRIGGER league_period_rollover
    AFTER UPDATE OF end_date ON public.leagues
    FOR EACH ROW
    WHEN (NEW.end_date > OLD.end_date AND OLD.end_date <= now() + interval '5 minutes')
    EXECUTE FUNCTION public.league_period_rollover();

-- Mevcut üyelikler: ligin şimdiki dönemi. (Geçmişte farklı dönem takvimli bir
-- lige taşınmış üyede ilk dönem için yaklaşık değerdir.)
UPDATE public.league_memberships lm
   SET period_started_at = least(l.end_date - interval '14 days', now())
  FROM public.leagues l
 WHERE l.id = lm.league_id
   AND lm.period_started_at IS NULL;

-- ---------------------------------------------------------------------------
-- G) complete_study_session: canlı gövde + UX-01 + lig dönemi
-- ---------------------------------------------------------------------------
-- Değişiklikler (canlı gövdeye göre, "proposed/13" yorumlu satırlar):
--  2a. session_starts eşleşmesi → start_verified, started_at sunucudan.
--      Doğrulama/hata sırası ve metinleri AYNI; yalnızca p_started_at yerine
--      v_started_at kullanılır.
--  5b. Doğrulanmamış seans tavanı (app_config, null = kapalı).
--  8.  Lig puanı yalnızca seansın bitişi üyeliğin dönem başlangıcından
--      sonraysa.
--  9.  start_verified yazılır; kullanılan başlangıç kaydı silinir.
--  11. Yanıta start_verified, unverified_limit_reached, league_points,
--      league_period_closed eklenir.
CREATE OR REPLACE FUNCTION public.complete_study_session(p_client_uuid uuid, p_category_id uuid, p_duration_minutes integer, p_was_paused boolean, p_is_verified integer, p_started_at timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid;
    v_base_points integer;
    v_bonus_points integer := 0;
    v_total_points integer;
    v_coins_earned integer := 20;
    v_current_streak integer;
    v_longest_streak integer;
    v_last_study_date date;
    v_user_tz text;
    v_study_day date;
    v_bonus_pct integer := 0;
    v_session_id uuid;
    v_daily_sessions integer;
    v_daily_limit_reached boolean := false;
    v_daily_minutes integer;
    v_top_category text;
    v_existing RECORD;
    v_ends_at timestamptz;
    v_is_late_session boolean := false;
    v_show_in_social_feed boolean;
    -- proposed/13
    v_started_at timestamptz;
    v_server_started_at timestamptz;
    v_start_verified boolean := false;
    v_unverified_cap integer;
    v_unverified_sessions integer;
    v_unverified_limit_reached boolean := false;
    v_period_start timestamptz;
    v_league_period_closed boolean := false;
    v_league_points integer := 0;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    -- 1. IDEMPOTENCY CHECK (client_uuid)
    SELECT * INTO v_existing FROM public.study_sessions
    WHERE client_uuid = p_client_uuid AND user_id = v_uid LIMIT 1;

    IF FOUND THEN
        RETURN jsonb_build_object(
            'base_points', v_existing.base_points,
            'bonus_points', v_existing.bonus_points,
            'total_points', v_existing.base_points + v_existing.bonus_points,
            'coins_earned', 0,
            'streak', (SELECT current_streak FROM public.profiles WHERE id = v_uid),
            'bonus_pct', 0,
            'duplicate', true,
            'daily_limit_reached', false
        );
    END IF;

    -- 2. VALIDATION
    IF p_duration_minutes NOT IN (25, 50) THEN
        RAISE EXCEPTION 'invalid duration: only 25 or 50 allowed';
    END IF;

    -- 2a. proposed/13 (UX-01): sunucu başlangıç kaydı. Aynı client_uuid ve
    -- süreyle kayıt var VE süre sunucu saatine göre dolmuşsa (60 sn pay)
    -- seans doğrulanmıştır; başlangıç sunucudan alınır (completed_at now()'u
    -- geçmesin diye en geç now() - süre). Aksi halde istemcinin
    -- p_started_at'i bugünkü kurallarla değerlendirilir.
    SELECT s.server_started_at INTO v_server_started_at
      FROM public.session_starts s
     WHERE s.user_id = v_uid
       AND s.client_uuid = p_client_uuid
       AND s.duration_minutes = p_duration_minutes;

    IF v_server_started_at IS NOT NULL
       AND now() >= v_server_started_at + make_interval(mins => p_duration_minutes) - interval '60 seconds' THEN
        v_start_verified := true;
        v_started_at := least(v_server_started_at, now() - make_interval(mins => p_duration_minutes));
    ELSE
        v_started_at := p_started_at;
    END IF;

    IF v_started_at IS NULL OR v_started_at > now() THEN
        RAISE EXCEPTION 'started_at cannot be in the future';
    END IF;

    IF v_started_at < now() - interval '24 hours' THEN
        RAISE EXCEPTION 'started_at is older than 24 hours';
    END IF;

    v_ends_at := v_started_at + make_interval(mins => p_duration_minutes);

    -- Seans gerçekten bitmiş olmalı (küçük saat sapması toleransı: 5 dk).
    IF v_ends_at > now() + interval '5 minutes' THEN
        RAISE EXCEPTION 'session_not_finished';
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM public.categories
        WHERE id = p_category_id AND user_id = v_uid
    ) THEN
        RAISE EXCEPTION 'category does not belong to this user';
    END IF;

    -- 3. ÇAKIŞMA: gerçek zaman aralığıyla (completed_at = gerçek bitiş)
    IF EXISTS (
        SELECT 1 FROM public.study_sessions s
        WHERE s.user_id = v_uid
          AND s.started_at IS NOT NULL
          AND s.started_at < v_ends_at
          AND s.completed_at > v_started_at
    ) THEN
        RETURN jsonb_build_object('error', 'overlap');
    END IF;

    -- 4. BASE POINTS & STREAK
    IF p_duration_minutes = 25 THEN
        v_base_points := 5;
    ELSE
        v_base_points := 12;
    END IF;

    IF p_was_paused THEN
        v_base_points := v_base_points - ceil(v_base_points * 0.20);
    END IF;

    SELECT COALESCE(current_streak, 0), longest_streak, last_study_date,
           COALESCE(timezone, 'Europe/Istanbul'), show_in_social_feed
    INTO v_current_streak, v_longest_streak, v_last_study_date, v_user_tz, v_show_in_social_feed
    FROM public.profiles
    WHERE id = v_uid
    FOR UPDATE;

    v_study_day := ((v_started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date;

    IF v_last_study_date IS NOT NULL AND v_study_day < v_last_study_date THEN
        -- Çevrimdışı kuyruktan geç gelen eski seans: seriyi ve son
        -- çalışma gününü geri almaz.
        v_is_late_session := true;
    ELSIF v_last_study_date IS NULL THEN
        v_current_streak := 1;
    ELSIF v_last_study_date = v_study_day THEN
        NULL;
    ELSIF v_last_study_date = v_study_day - 1 THEN
        v_current_streak := v_current_streak + 1;
    ELSE
        v_current_streak := 1;
    END IF;

    IF v_current_streak > COALESCE(v_longest_streak, 0) THEN
        v_longest_streak := v_current_streak;
    END IF;

    -- 5. DAILY CEILING CHECK (16 seans) — lig puanı + lifetime_points + kum
    SELECT count(*) INTO v_daily_sessions
    FROM public.study_sessions
    WHERE user_id = v_uid
      AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

    IF v_daily_sessions >= 16 THEN
        v_daily_limit_reached := true;
    END IF;

    -- 5b. proposed/13 (UX-01): doğrulanmamış seans tavanı. null = kapalı.
    IF NOT v_start_verified THEN
        v_unverified_cap := public.app_config_int('unverified_session_daily_cap');
        IF v_unverified_cap IS NOT NULL THEN
            SELECT count(*) INTO v_unverified_sessions
            FROM public.study_sessions
            WHERE user_id = v_uid
              AND start_verified IS FALSE
              AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

            IF v_unverified_sessions >= greatest(v_unverified_cap, 0) THEN
                v_unverified_limit_reached := true;
            END IF;
        END IF;
    END IF;

    -- 6. STREAK BONUS
    IF v_current_streak >= 14 THEN
        v_bonus_pct := 30;
    ELSIF v_current_streak >= 7 THEN
        v_bonus_pct := 20;
    ELSIF v_current_streak >= 3 THEN
        v_bonus_pct := 10;
    ELSE
        v_bonus_pct := 0;
    END IF;

    v_bonus_points := ceil(v_base_points::numeric * v_bonus_pct / 100.0);
    v_total_points := v_base_points + v_bonus_points;

    IF v_daily_limit_reached OR v_unverified_limit_reached THEN
        v_base_points := 0;
        v_bonus_points := 0;
        v_total_points := 0;
        v_coins_earned := 0;
    END IF;

    -- 7. UPDATE PROFILES
    UPDATE public.profiles
    SET total_minutes = COALESCE(total_minutes, 0) + p_duration_minutes,
        lifetime_points = lifetime_points + v_total_points,
        coins = coins + v_coins_earned,
        current_streak = v_current_streak,
        longest_streak = v_longest_streak,
        last_study_date = CASE WHEN v_is_late_session THEN last_study_date ELSE v_study_day END
    WHERE id = v_uid;

    -- 8. LEAGUE POINTS — proposed/13: kapanmış döneme ait seans lig puanı almaz.
    IF NOT v_daily_limit_reached AND NOT v_unverified_limit_reached THEN
        SELECT COALESCE(lm.period_started_at, l.end_date - interval '14 days')
          INTO v_period_start
          FROM public.league_memberships lm
          JOIN public.leagues l ON l.id = lm.league_id
         WHERE lm.user_id = v_uid AND l.is_active = true
         LIMIT 1;

        IF v_period_start IS NOT NULL AND v_ends_at <= v_period_start THEN
            v_league_period_closed := true;
        ELSE
            PERFORM public.ensure_user_in_league(v_uid, v_total_points);
            v_league_points := v_total_points;
        END IF;
    END IF;

    -- 9. INSERT STUDY SESSION (completed_at = gerçek bitiş)
    INSERT INTO public.study_sessions (
        user_id, category, category_id, duration_minutes,
        base_points, bonus_points, was_paused, is_verified,
        client_uuid, started_at, completed_at, start_verified
    ) VALUES (
        v_uid,
        (SELECT name FROM public.categories WHERE id = p_category_id),
        p_category_id, p_duration_minutes,
        v_base_points, v_bonus_points, p_was_paused, p_is_verified,
        p_client_uuid, v_started_at, v_ends_at, v_start_verified
    )
    RETURNING id INTO v_session_id;

    -- proposed/13: kullanılan başlangıç kaydı artık gereksiz.
    DELETE FROM public.session_starts
     WHERE user_id = v_uid AND client_uuid = p_client_uuid;

    -- 10. ACTIVITY FEED
    IF v_show_in_social_feed THEN
        SELECT SUM(duration_minutes), COUNT(*) INTO v_daily_minutes, v_daily_sessions
        FROM public.study_sessions
        WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day;

        SELECT category INTO v_top_category
        FROM public.study_sessions
        WHERE user_id = v_uid AND ((started_at AT TIME ZONE v_user_tz) - interval '4 hours')::date = v_study_day
        GROUP BY category
        ORDER BY SUM(duration_minutes) DESC
        LIMIT 1;

        INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
        VALUES (
            v_uid,
            'daily_summary',
            v_study_day,
            jsonb_build_object(
                'total_minutes', COALESCE(v_daily_minutes, 0),
                'session_count', COALESCE(v_daily_sessions, 0),
                'top_category', v_top_category
            )
        )
        ON CONFLICT (user_id, activity_type, activity_date)
        DO UPDATE SET
            payload = EXCLUDED.payload,
            updated_at = now();

        IF NOT v_is_late_session
           AND v_current_streak IN (7, 14, 30, 60, 100)
           AND v_last_study_date IS DISTINCT FROM v_study_day THEN
            INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
            VALUES (v_uid, 'streak_milestone', v_study_day, jsonb_build_object('streak', v_current_streak))
            ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
        END IF;

        IF COALESCE(v_daily_minutes, 0) >= 240 THEN
            INSERT INTO public.activity_feed (user_id, activity_type, activity_date, payload)
            VALUES (v_uid, 'daily_4h_milestone', v_study_day, jsonb_build_object('total_minutes', v_daily_minutes))
            ON CONFLICT (user_id, activity_type, activity_date) DO NOTHING;
        END IF;
    END IF;

    -- 11. RETURN RESULT
    RETURN jsonb_build_object(
        'base_points', v_base_points,
        'bonus_points', v_bonus_points,
        'total_points', v_total_points,
        'coins_earned', v_coins_earned,
        'streak', v_current_streak,
        'bonus_pct', v_bonus_pct,
        'duplicate', false,
        'daily_limit_reached', v_daily_limit_reached,
        'start_verified', v_start_verified,
        'unverified_limit_reached', v_unverified_limit_reached,
        'league_points', v_league_points,
        'league_period_closed', v_league_period_closed
    );
END;
$function$;

-- ---------------------------------------------------------------------------
-- H) HİJYEN: search_path'e pg_temp (gövdeye dokunmadan). handle_new_user ve
-- add_friend_by_code yukarıda yeniden yazıldı. delete_own_account: proposed/12
-- (sırada 13'ten önce) gövdeyi zaten pg_temp'li yazar, bu satır o zaman
-- etkisizdir; 12 uygulanmadıysa canlı gövdeye pg_temp ekler (13_down o
-- durumda geri alır). handle_newsletter_subscription ve
-- respond_friend_request'i proposed/14 sonra pg_temp'li gövdeyle yeniden yazar.
-- ---------------------------------------------------------------------------
ALTER FUNCTION public.cleanup_unconfirmed_duplicate_identity(text) SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.delete_own_account() SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.ensure_user_in_league(uuid, integer) SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.get_my_league_ids() SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.handle_newsletter_subscription() SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.purchase_avatar(text) SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.respond_friend_request(uuid, boolean) SET search_path TO 'public', 'pg_temp';
ALTER FUNCTION public.set_equipped_avatar(text) SET search_path TO 'public', 'pg_temp';

-- ---------------------------------------------------------------------------
-- I) YETKİLER. Canlıda public'teki yeni fonksiyonlar varsayılan olarak
-- PUBLIC, anon ve authenticated'a açılıyor (pg_default_acl); hepsi kapatılıp
-- yalnızca gerekene açılır. CREATE OR REPLACE mevcut yetkileri korur; yine
-- de değişen RPC'ler için açıkça yazılır.
-- ---------------------------------------------------------------------------
DO $grants$
DECLARE
    f text;
BEGIN
    FOREACH f IN ARRAY ARRAY[
        'app_config_int(text)', 'get_app_config()', 'clean_display_text(text)',
        'display_text_is_allowed(text)', 'enforce_profile_name()', 'enforce_category_name()',
        'discard_profile_email()', 'generate_friend_code(integer)', 'normalize_friend_code(text)',
        'register_session_start(uuid, integer)', 'league_membership_period_start()',
        'league_period_rollover()',
        'complete_study_session(uuid, uuid, integer, boolean, integer, timestamp with time zone)',
        'start_study_session(integer, text)', 'add_friend_by_code(text)', 'handle_new_user()'
    ]
    LOOP
        EXECUTE format('REVOKE ALL ON FUNCTION public.%s FROM PUBLIC, anon, authenticated', f);
        EXECUTE format('GRANT EXECUTE ON FUNCTION public.%s TO service_role', f);
    END LOOP;
END $grants$;

-- Herkese açık yapılandırma (UX-08): giriş ekranından önce okunur.
GRANT EXECUTE ON FUNCTION public.get_app_config() TO anon, authenticated;
-- Oturum gerektiren RPC'ler.
GRANT EXECUTE ON FUNCTION public.register_session_start(uuid, integer) TO authenticated;
GRANT EXECUTE ON FUNCTION public.complete_study_session(uuid, uuid, integer, boolean, integer, timestamp with time zone) TO authenticated;
GRANT EXECUTE ON FUNCTION public.start_study_session(integer, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.add_friend_by_code(text) TO authenticated;
-- profiles.friend_code varsayılanı istemcinin yedek INSERT'ünde authenticated
-- yetkisiyle değerlendirilir.
GRANT EXECUTE ON FUNCTION public.generate_friend_code(integer) TO authenticated;

-- ---------------------------------------------------------------------------
-- J) MIGRATION GEÇMİŞİ (SQL Editor'den uygulandığında da kaydolsun)
-- ---------------------------------------------------------------------------
DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261004120000', 'sunucu_butunluk')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

-- ---------------------------------------------------------------------------
-- Senaryolar
-- ---------------------------------------------------------------------------
DO $dry$
DECLARE
  d record;
  ua uuid := gen_random_uuid();   -- ad, kategori, arkadaş, doğrulama
  ub uuid := gen_random_uuid();   -- arkadaş hedefi, kontrol karakterli ad
  uc uuid := gen_random_uuid();   -- friend_code çakışması
  ud uuid := gen_random_uuid();   -- yasaklı adla kayıt
  ue uuid := gen_random_uuid();   -- 8 karakterli kod
  uf uuid := gen_random_uuid();   -- deneme sınırı
  ug uuid := gen_random_uuid();   -- doğrulanmamış seans tavanı
  uh uuid := gen_random_uuid();   -- lig dönemi sınırı
  ui uuid := gen_random_uuid();   -- lig değiştiren üye
  uj uuid := gen_random_uuid();   -- istemci yedek INSERT'ü
  l_a uuid := gen_random_uuid(); l_g uuid := gen_random_uuid(); l_h uuid := gen_random_uuid();
  l_i uuid := gen_random_uuid(); l_i2 uuid := gen_random_uuid();
  cat_a uuid; cat_g uuid; cat_h uuid; cat_x uuid;
  cu1 uuid := gen_random_uuid(); cu2 uuid := gen_random_uuid(); cu_g uuid := gen_random_uuid();
  code_a text; code_b text; code_legacy text; v_code text;
  v_res jsonb; v_res2 jsonb; v_res3 jsonb; v_keep jsonb; v_keep2 jsonb;
  v_txt text; v_int int; v_int2 int; v_bool boolean;
  v_ts timestamptz; v_ts2 timestamptz; v_base timestamptz; v_day_start timestamptz;
  res text[] := '{}';
BEGIN
  SELECT * INTO d FROM dry13;

  -- ======================= Yetkiler ve yapılandırma =======================
  res := res || ('T01 get_app_config anon ve authenticated çağırabilir: ' ||
    (has_function_privilege('anon', 'public.get_app_config()', 'execute')
     AND has_function_privilege('authenticated', 'public.get_app_config()', 'execute'))::text);

  EXECUTE 'SET LOCAL ROLE anon';
  v_res := public.get_app_config();
  EXECUTE 'RESET ROLE';
  res := res || ('T02 get_app_config açık anahtarları döndürür, gizliyi döndürmez: ' ||
    (v_res ? 'server_time' AND v_res ? 'min_supported_version' AND v_res ? 'latest_version'
     AND (v_res #>> '{min_supported_version,android,build}') IS NOT NULL
     AND v_res ? 'unverified_session_daily_cap' AND NOT (v_res ? 'friend_code_attempts_per_hour'))::text);

  SELECT bool_and(NOT has_table_privilege(r, t, 'select') AND NOT has_table_privilege(r, t, 'insert')
                  AND NOT has_table_privilege(r, t, 'update') AND NOT has_table_privilege(r, t, 'delete'))
    INTO v_bool
    FROM unnest(ARRAY['anon', 'authenticated']) r,
         unnest(ARRAY['public.app_config', 'public.session_starts', 'public.friend_code_attempts', 'public.blocked_name_terms']) t;
  res := res || ('T03 yeni tablolar API rollerine kapalı: ' || v_bool::text);

  res := res || ('T04 register_session_start yalnızca authenticated: ' ||
    (NOT has_function_privilege('anon', 'public.register_session_start(uuid,integer)', 'execute')
     AND has_function_privilege('authenticated', 'public.register_session_start(uuid,integer)', 'execute'))::text);

  SELECT count(*) INTO v_int FROM pg_proc
   WHERE pronamespace = 'public'::regnamespace AND prosecdef
     AND NOT coalesce(array_to_string(proconfig, ',') LIKE '%pg_temp%', false);
  res := res || ('T05 search_path''inde pg_temp olmayan SECURITY DEFINER kalmadı (' || v_int || '): ' || (v_int = 0)::text);

  SELECT bool_and(NOT has_function_privilege('authenticated', f, 'execute') AND NOT has_function_privilege('anon', f, 'execute'))
    INTO v_bool
    FROM unnest(ARRAY['public.display_text_is_allowed(text)', 'public.clean_display_text(text)',
                      'public.app_config_int(text)', 'public.normalize_friend_code(text)',
                      'public.enforce_profile_name()', 'public.league_period_rollover()']) f;
  res := res || ('T06 yardımcı ve trigger fonksiyonları API rollerine kapalı: ' || v_bool::text);

  -- ======================= Kayıt: friend_code çakışması =======================
  -- generate_friend_code geçici olarak ilk çağrıda VAR OLAN bir kodu döndüren
  -- bir sarmalayıcıyla değiştirilir; kayıt düşmemeli, yeni kodla tekrar denemeli.
  SELECT friend_code INTO code_legacy FROM public.profiles WHERE id = d.u_legacy;
  EXECUTE 'CREATE TEMP SEQUENCE dry13_seq';
  EXECUTE 'ALTER FUNCTION public.generate_friend_code(integer) RENAME TO dry13_gen_real';
  EXECUTE format($f$CREATE FUNCTION public.generate_friend_code(p_length integer DEFAULT 6) RETURNS text
    LANGUAGE plpgsql AS $g$ BEGIN IF nextval('dry13_seq') = 1 THEN RETURN %L; END IF;
    RETURN public.dry13_gen_real(p_length); END $g$$f$, code_legacy);
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES (uc, 'dryrun13-c-' || uc || '@example.invalid', '{"name":"Dry Cakisma"}', 'authenticated', 'authenticated');
  SELECT friend_code INTO v_code FROM public.profiles WHERE id = uc;
  res := res || ('T07 friend_code çakışmasında kayıt düşmez, yeni kodla tekrar dener: ' ||
    coalesce(v_code IS NOT NULL AND v_code <> code_legacy AND currval('dry13_seq') >= 2, false)::text);
  EXECUTE 'DROP FUNCTION public.generate_friend_code(integer)';
  EXECUTE 'ALTER FUNCTION public.dry13_gen_real(integer) RENAME TO generate_friend_code';

  -- ======================= Kayıt: kod biçimi, e-posta, ad =======================
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role) VALUES
    (ua, 'dryrun13-a-' || ua || '@example.invalid', '{"name":"Dry Ayse"}', 'authenticated', 'authenticated'),
    (ub, 'dryrun13-b-' || ub || '@example.invalid', jsonb_build_object('name', E'Dry‮ Bora\t\tB'), 'authenticated', 'authenticated'),
    (ud, 'dryrun13-d-' || ud || '@example.invalid', '{"name":"Fuck You"}', 'authenticated', 'authenticated'),
    (uf, 'dryrun13-f-' || uf || '@example.invalid', '{"name":"Dry Fatma"}', 'authenticated', 'authenticated'),
    (ug, 'dryrun13-g-' || ug || '@example.invalid', '{"name":"Dry Gul"}', 'authenticated', 'authenticated'),
    (uh, 'dryrun13-h-' || uh || '@example.invalid', '{"name":"Dry Hakan"}', 'authenticated', 'authenticated'),
    (ui, 'dryrun13-i-' || ui || '@example.invalid', '{"name":"Dry Irmak"}', 'authenticated', 'authenticated'),
    (uj, 'dryrun13-j-' || uj || '@example.invalid', '{"name":"Dry Jale"}', 'authenticated', 'authenticated');
  SELECT friend_code INTO code_a FROM public.profiles WHERE id = ua;
  SELECT friend_code INTO code_b FROM public.profiles WHERE id = ub;
  res := res || ('T08 yeni kod 6 karakter Crockford base32 (' || code_a || ', ' || code_b || '): ' ||
    coalesce(code_a ~ '^[0-9A-HJKMNP-TV-Z]{6}$' AND code_b ~ '^[0-9A-HJKMNP-TV-Z]{6}$', false)::text);

  SELECT count(*) INTO v_int FROM public.profiles WHERE email IS NOT NULL;
  res := res || ('T09 profiles.email hiçbir satırda tutulmuyor (' || v_int || '): ' || (v_int = 0)::text);

  SELECT name INTO v_txt FROM public.profiles WHERE id = ud;
  res := res || ('T10 yasaklı metadata adı yerine e-posta yerel kısmı: ' || coalesce(v_txt = 'dryrun13-d-' || ud, false)::text);

  SELECT name INTO v_txt FROM public.profiles WHERE id = ub;
  res := res || ('T11 kayıtta ad temizlenir (bidi, sekme): ' || coalesce(v_txt = 'Dry Bora B', false)::text);

  -- ======================= profiles.name trigger'ı =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    UPDATE public.profiles SET name = 'f.u.c.k off' WHERE id = ua;
    res := res || 'T12 yasaklı ad doğrudan UPDATE ile yazılamaz: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T12 yasaklı ad doğrudan UPDATE ile yazılamaz (' || SQLSTATE || ' ' || SQLERRM || '): '
                   || (SQLSTATE = '23514' AND SQLERRM = 'profile_name_not_allowed')::text);
  END;
  UPDATE public.profiles SET name = 'Şikayet Amasya Scunthorpe' WHERE id = ua RETURNING name INTO v_txt;
  res := res || ('T13 masum adlar (Şikayet, Amasya, Scunthorpe) engellenmez: ' || coalesce(v_txt = 'Şikayet Amasya Scunthorpe', false)::text);
  UPDATE public.profiles SET name = E'Ali‮  Veli\u0007' WHERE id = ua RETURNING name INTO v_txt;
  res := res || ('T14 ad güncellemesinde kontrol ve bidi karakterleri temizlenir: ' || coalesce(v_txt = 'Ali Veli', false)::text);
  EXECUTE 'RESET ROLE';

  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_legacy, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  UPDATE public.profiles SET show_in_social_feed = false WHERE id = d.u_legacy;
  GET DIAGNOSTICS v_int = ROW_COUNT;
  UPDATE public.categories SET is_archived = true WHERE user_id = d.u_legacy AND char_length(name) = 45;
  GET DIAGNOSTICS v_int2 = ROW_COUNT;
  EXECUTE 'RESET ROLE';
  res := res || ('T15 eski (yasaklı) adlı profilin diğer alanları güncellenebilir: ' || (v_int = 1)::text);
  res := res || ('T16 eski 45 karakterlik kategori arşivlenebilir: ' || (v_int2 = 1)::text);

  -- ======================= categories.name trigger'ı =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  cat_a := public.create_category('Dry Matematik', '#FF0000', 'book');
  BEGIN
    PERFORM public.create_category('Orospu Cocugu', '#FF0000', 'book');
    res := res || 'T17 yasaklı kategori adı reddedilir: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T17 yasaklı kategori adı reddedilir (' || SQLERRM || '): '
                   || (SQLSTATE = '23514' AND SQLERRM = 'category_name_not_allowed')::text);
  END;
  BEGIN
    PERFORM public.create_category(repeat('K', 41), '#FF0000', 'book');
    res := res || 'T18 41 karakterlik kategori reddedilir, 40 kabul edilir: false'::text;
  EXCEPTION WHEN OTHERS THEN
    v_txt := SQLERRM;
    cat_x := public.create_category(repeat('K', 40), '#FF0000', 'book');
    res := res || ('T18 41 karakterlik kategori reddedilir, 40 kabul edilir: '
                   || (v_txt = 'category_name_invalid_length' AND cat_x IS NOT NULL)::text);
  END;
  INSERT INTO public.categories (user_id, name, color_hex) VALUES (ua, E'Dry\u0007 Fizik  ', '#000000') RETURNING name INTO v_txt;
  res := res || ('T19 doğrudan INSERT''te ad temizlenir: ' || coalesce(v_txt = 'Dry Fizik', false)::text);
  BEGIN
    UPDATE public.categories SET name = 'amk' WHERE id = cat_a;
    res := res || 'T20 doğrudan UPDATE ile yasaklı kategori adı yazılamaz: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T20 doğrudan UPDATE ile yasaklı kategori adı yazılamaz: ' || (SQLERRM = 'category_name_not_allowed')::text);
  END;
  EXECUTE 'RESET ROLE';

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.setup_onboarding_categories(
    '[{"name":"Ders","color_hex":"#111111","icon_name":"book"},{"name":"Kitap","color_hex":"#222222","icon_name":"book"}]'::jsonb);
  EXECUTE 'RESET ROLE';
  SELECT count(*) INTO v_int FROM public.categories WHERE user_id = ub;
  res := res || ('T21 onboarding kategorileri oluşur: ' || (v_int = 2)::text);

  -- ======================= start_study_session =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.start_study_session(25, repeat('K', 60) || E'\u0001');
  EXECUTE 'RESET ROLE';
  SELECT active_session_category_name, active_session_ends_at INTO v_txt, v_ts FROM public.profiles WHERE id = ua;
  res := res || ('T22 canlı kategori adı 40 karaktere kısalır, bitiş yazılır: '
                 || coalesce(v_txt = repeat('K', 40) AND v_ts = now() + interval '25 minutes', false)::text);

  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.start_study_session(25, 'Siktir git');
  EXECUTE 'RESET ROLE';
  SELECT active_session_category_name INTO v_txt FROM public.profiles WHERE id = ua;
  res := res || ('T23 yasaklı canlı kategori adı boş bırakılır: ' || (v_txt IS NULL)::text);

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_int := 0;
  BEGIN
    PERFORM public.start_study_session(-5, 'Ders');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE 'invalid duration%' THEN v_int := v_int + 1; END IF;
  END;
  BEGIN
    PERFORM public.start_study_session(1000000, 'Ders');
  EXCEPTION WHEN OTHERS THEN
    IF SQLERRM LIKE 'invalid duration%' THEN v_int := v_int + 1; END IF;
  END;
  PERFORM public.start_study_session(0, 'Ders');
  EXECUTE 'RESET ROLE';
  res := res || ('T24 geçersiz süre (-5, 1000000) reddedilir, 0 (debug) kabul: ' || (v_int = 2)::text);

  -- ======================= Arkadaş kodu =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.add_friend_by_code(lower(substr(code_b, 1, 3)) || '- ' || lower(substr(code_b, 4)));
  res := res || ('T25 kod normalize edilir; bekleyen istekte id dönmez, ad döner: '
                 || coalesce(v_res->>'success' = 'true' AND v_res->>'code' = 'request_sent'
                             AND NOT ((v_res->'friend') ? 'id') AND v_res #>> '{friend,name}' = 'Dry Bora B', false)::text);
  v_res2 := public.add_friend_by_code(code_a);
  v_res := public.add_friend_by_code(lower(code_legacy));
  EXECUTE 'RESET ROLE';
  res := res || ('T26 eski 6 hex kod (küçük harfle) çalışır; kendini ekleme kodu self_add: '
                 || coalesce(v_res->>'success' = 'true' AND v_res2->>'code' = 'self_add', false)::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', ub, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.add_friend_by_code(code_a);
  v_res2 := public.add_friend_by_code(code_a);
  EXECUTE 'RESET ROLE';
  res := res || ('T27 karşılıklı istek otomatik kabul (id döner), sonra already_friends: '
                 || coalesce(v_res->>'code' = 'accepted' AND (v_res->'friend') ? 'id' AND v_res2->>'code' = 'already_friends', false)::text);
  res := res || ('T28 normalize: boşluk/tire atılır, O→0, I/L→1: ' || (public.normalize_friend_code(' ab-c d oil ') = 'ABCD011')::text);

  PERFORM set_config('request.jwt.claims', json_build_object('sub', uf, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  FOR i IN 1..20 LOOP
    v_res := public.add_friend_by_code('UUUUUU');   -- U alfabede yok: hiçbir zaman geçerli değil
  END LOOP;
  v_res2 := public.add_friend_by_code(code_a);
  EXECUTE 'RESET ROLE';
  SELECT attempts INTO v_int FROM public.friend_code_attempts WHERE user_id = uf;
  res := res || ('T29 saatte 20 denemeden sonra rate_limited (geçerli kodda bile), sayaç kalıcı: '
                 || coalesce(v_res->>'code' = 'not_found' AND v_res2->>'code' = 'rate_limited'
                             AND v_res2->>'success' = 'false' AND v_int = 21, false)::text);
  UPDATE public.friend_code_attempts SET window_started_at = now() - interval '61 minutes' WHERE user_id = uf;
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.add_friend_by_code(code_a);
  EXECUTE 'RESET ROLE';
  SELECT attempts INTO v_int FROM public.friend_code_attempts WHERE user_id = uf;
  res := res || ('T30 pencere dolunca sayaç sıfırlanır: ' || coalesce(v_res->>'success' = 'true' AND v_int = 1, false)::text);

  UPDATE public.app_config SET value = '8' WHERE key = 'friend_code_length';
  INSERT INTO auth.users (id, email, raw_user_meta_data, aud, role)
  VALUES (ue, 'dryrun13-e-' || ue || '@example.invalid', '{"name":"Dry Ece"}', 'authenticated', 'authenticated');
  SELECT friend_code INTO v_code FROM public.profiles WHERE id = ue;
  UPDATE public.app_config SET value = '6' WHERE key = 'friend_code_length';
  res := res || ('T31 friend_code_length = 8 ile yeni kod 8 karakter (' || v_code || '): ' || coalesce(v_code ~ '^[0-9A-HJKMNP-TV-Z]{8}$', false)::text);

  DELETE FROM public.profiles WHERE id = uj;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uj, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  INSERT INTO public.profiles (id, email, name, avatar_id)
  VALUES (uj, 'baskasi@example.invalid', 'Dry Yedek', 'avatar_1_gamer')
  ON CONFLICT (id) DO NOTHING;
  EXECUTE 'RESET ROLE';
  SELECT email IS NULL AND friend_code ~ '^[0-9A-HJKMNP-TV-Z]{6}$' AND avatar_id = 'avatar_16_basic'
    INTO v_bool FROM public.profiles WHERE id = uj;
  res := res || ('T32 istemci yedek INSERT''ü çalışır; e-posta atılır, kod varsayılandan: ' || coalesce(v_bool, false)::text);

  -- ======================= Lig üyelikleri (sentetik ligler) =======================
  INSERT INTO public.leagues (id, tier, end_date) VALUES
    (l_a, 1, now() + interval '7 days'), (l_g, 1, now() + interval '7 days'), (l_h, 1, now() + interval '7 days'),
    (l_i, 1, now() + interval '7 days'), (l_i2, 1, now() + interval '7 days');
  INSERT INTO public.league_memberships (league_id, user_id) VALUES (l_a, ua), (l_g, ug), (l_h, uh), (l_i, ui);
  SELECT period_started_at INTO v_ts FROM public.league_memberships WHERE user_id = ua;
  res := res || ('T33 yeni üyeliğin dönem başlangıcı = ligin bitişi - 14 gün: ' || coalesce(v_ts = now() - interval '7 days', false)::text);
  SELECT lm.period_started_at = l.end_date - interval '14 days' INTO v_bool
    FROM public.league_memberships lm JOIN public.leagues l ON l.id = lm.league_id
   WHERE lm.user_id = d.u_legacy;
  res := res || ('T34 mevcut üyeliklerin dönem başlangıcı geriye dönük dolduruldu: ' || coalesce(v_bool, false)::text);

  -- ======================= UX-01: sunucu başlangıç kaydı =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ua, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.register_session_start(cu1, 25);
  v_res2 := public.register_session_start(cu1, 25);
  EXECUTE 'RESET ROLE';
  res := res || ('T35 register_session_start sunucu saatini yazar, tekrar çağrı aynı kaydı döndürür: '
                 || coalesce((v_res->>'created')::boolean AND NOT (v_res2->>'created')::boolean
                             AND (v_res->>'server_started_at')::timestamptz = now()
                             AND v_res2->>'server_started_at' = v_res->>'server_started_at', false)::text);

  EXECUTE 'SET LOCAL ROLE authenticated';
  BEGIN
    PERFORM public.register_session_start(gen_random_uuid(), 30);
    res := res || 'T36 register_session_start geçersiz süreyi reddeder: false'::text;
  EXCEPTION WHEN OTHERS THEN
    res := res || ('T36 register_session_start geçersiz süreyi reddeder: ' || (SQLERRM = 'invalid duration: only 25 or 50 allowed')::text);
  END;
  EXECUTE 'RESET ROLE';

  -- 26 dk önce başlamış gibi (DRYRUN tek işlemde çalıştığı için saat ilerlemez)
  UPDATE public.session_starts SET server_started_at = now() - interval '26 minutes' WHERE user_id = ua AND client_uuid = cu1;
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_keep := public.complete_study_session(cu1, cat_a, 25, false, 1500, now() - interval '3 hours');
  EXECUTE 'RESET ROLE';
  SELECT started_at, start_verified INTO v_ts, v_bool FROM public.study_sessions WHERE user_id = ua AND client_uuid = cu1;
  SELECT count(*) INTO v_int FROM public.session_starts WHERE user_id = ua AND client_uuid = cu1;
  res := res || ('T37 doğrulanmış seans: başlangıç sunucudan (istemcinin geri kaydırması yok sayılır), kayıt tüketilir: '
                 || coalesce((v_keep->>'start_verified')::boolean AND v_bool AND v_ts = now() - interval '26 minutes'
                             AND (v_keep->>'total_points')::int = 5 AND v_int = 0, false)::text);

  -- Saat ileri alınmış: kayıt var ama sunucuya göre süre dolmadı
  EXECUTE 'SET LOCAL ROLE authenticated';
  PERFORM public.register_session_start(cu2, 25);
  v_res := public.complete_study_session(cu2, cat_a, 25, false, 1500, now() - interval '60 minutes');
  EXECUTE 'RESET ROLE';
  SELECT start_verified INTO v_bool FROM public.study_sessions WHERE user_id = ua AND client_uuid = cu2;
  res := res || ('T38 sunucuya göre bitmemiş seans doğrulanmaz, bugünkü kurallarla kabul (tavan kapalı): '
                 || coalesce(NOT (v_res->>'start_verified')::boolean AND NOT v_bool
                             AND (v_res->>'total_points')::int > 0 AND NOT (v_res->>'unverified_limit_reached')::boolean, false)::text);

  -- Canlı hata metinleri ve çakışma (başlangıç kaydı olmadan)
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_txt := '';
  BEGIN PERFORM public.complete_study_session(gen_random_uuid(), cat_a, 25, false, 0, now() + interval '1 minute');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.complete_study_session(gen_random_uuid(), cat_a, 25, false, 0, now() - interval '25 hours');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.complete_study_session(gen_random_uuid(), cat_a, 30, false, 0, now() - interval '2 hours');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.complete_study_session(gen_random_uuid(), cat_a, 25, false, 0, now() - interval '10 minutes');
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  BEGIN PERFORM public.complete_study_session(gen_random_uuid(), cat_a, 25, false, 0, NULL);
  EXCEPTION WHEN OTHERS THEN v_txt := v_txt || SQLERRM || '|'; END;
  v_res := public.complete_study_session(gen_random_uuid(), cat_a, 25, false, 0, now() - interval '50 minutes');
  v_res2 := public.complete_study_session(cu1, cat_a, 25, false, 0, now() - interval '5 hours');
  EXECUTE 'RESET ROLE';
  res := res || ('T39 canlı hata metinleri ve overlap aynen (' || v_txt || '): '
                 || coalesce(v_txt = 'started_at cannot be in the future|started_at is older than 24 hours|invalid duration: only 25 or 50 allowed|session_not_finished|started_at cannot be in the future|'
                             AND v_res->>'error' = 'overlap', false)::text);
  res := res || ('T40 aynı client_uuid tekrar gönderimi duplicate döner: ' || coalesce((v_res2->>'duplicate')::boolean, false)::text);

  SELECT bool_and(v_keep ? k) INTO v_bool
    FROM unnest(ARRAY['base_points', 'bonus_points', 'total_points', 'coins_earned', 'streak', 'bonus_pct',
                      'duplicate', 'daily_limit_reached', 'start_verified', 'unverified_limit_reached',
                      'league_points', 'league_period_closed']) k;
  SELECT weekly_points INTO v_int FROM public.league_memberships WHERE user_id = ua;
  res := res || ('T41 yanıtta eski ve yeni anahtarlar; lig puanı üyeliğe yazılır (' || v_int || '): '
                 || coalesce(v_bool AND (v_keep->>'league_points')::int = 5 AND NOT (v_keep->>'league_period_closed')::boolean
                             AND v_int = 10, false)::text);

  -- ======================= UX-01: doğrulanmamış seans tavanı =======================
  -- Seanslar tek bir çalışma gününe (Europe/Istanbul, 04:00) ve son 24 saate düşecek şekilde yerleşir.
  v_day_start := (date_trunc('day', (now() AT TIME ZONE 'Europe/Istanbul') - interval '4 hours') + interval '4 hours') AT TIME ZONE 'Europe/Istanbul';
  IF now() - v_day_start >= interval '3 hours' THEN
    v_base := v_day_start + interval '5 minutes';
  ELSE
    v_base := v_day_start - interval '20 hours';
  END IF;
  UPDATE public.app_config SET value = '2' WHERE key = 'unverified_session_daily_cap';
  PERFORM set_config('request.jwt.claims', json_build_object('sub', ug, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  cat_g := public.create_category('Dry Tavan', '#00FF00', 'book');
  v_res := public.complete_study_session(gen_random_uuid(), cat_g, 25, false, 1500, v_base);
  v_res2 := public.complete_study_session(gen_random_uuid(), cat_g, 25, false, 1500, v_base + interval '30 minutes');
  v_keep2 := public.complete_study_session(gen_random_uuid(), cat_g, 25, false, 1500, v_base + interval '60 minutes');
  PERFORM public.register_session_start(cu_g, 25);
  EXECUTE 'RESET ROLE';
  UPDATE public.session_starts SET server_started_at = v_base + interval '90 minutes' WHERE user_id = ug AND client_uuid = cu_g;
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res3 := public.complete_study_session(cu_g, cat_g, 25, false, 1500, now());
  EXECUTE 'RESET ROLE';
  UPDATE public.app_config SET value = 'null' WHERE key = 'unverified_session_daily_cap';
  res := res || ('T42 tavan = 2: ilk 2 doğrulanmamış seans ödül alır, 3. almaz: '
                 || coalesce((v_res->>'total_points')::int > 0 AND (v_res2->>'total_points')::int > 0
                             AND (v_keep2->>'total_points')::int = 0 AND (v_keep2->>'coins_earned')::int = 0
                             AND (v_keep2->>'league_points')::int = 0 AND (v_keep2->>'unverified_limit_reached')::boolean
                             AND NOT (v_keep2->>'daily_limit_reached')::boolean, false)::text);
  res := res || ('T43 doğrulanmış seans tavandan etkilenmez: '
                 || coalesce((v_res3->>'start_verified')::boolean AND (v_res3->>'total_points')::int > 0
                             AND NOT (v_res3->>'unverified_limit_reached')::boolean, false)::text);
  SELECT weekly_points INTO v_int FROM public.league_memberships WHERE user_id = ug;
  SELECT total_minutes INTO v_int2 FROM public.profiles WHERE id = ug;
  res := res || ('T44 lig puanı yalnızca ödüllü seanslardan, dakika hepsinden (' || v_int || ', ' || v_int2 || '): '
                 || coalesce(v_int = (v_res->>'league_points')::int + (v_res2->>'league_points')::int + (v_res3->>'league_points')::int
                             AND v_int2 = 100, false)::text);

  -- ======================= Lig dönemi sınırı =======================
  PERFORM set_config('request.jwt.claims', json_build_object('sub', uh, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  cat_h := public.create_category('Dry Lig', '#0000FF', 'book');
  v_res := public.complete_study_session(gen_random_uuid(), cat_h, 25, false, 1500, now() - interval '3 hours');
  EXECUTE 'RESET ROLE';
  -- process_weekly_leagues'in yaptığı devri taklit et: dönem bitti, puanlar sıfırlandı, bitiş 14 gün ileri.
  UPDATE public.leagues SET end_date = now() - interval '60 minutes' WHERE id = l_h;
  UPDATE public.league_memberships SET weekly_points = 0 WHERE league_id = l_h;
  UPDATE public.leagues SET end_date = end_date + interval '14 days' WHERE id = l_h;
  SELECT period_started_at INTO v_ts FROM public.league_memberships WHERE user_id = uh;
  res := res || ('T45 dönem devrinde ligde kalan üyenin dönemi eski bitişte başlar: '
                 || coalesce(v_ts = now() - interval '60 minutes' AND (v_res->>'league_points')::int = 5, false)::text);

  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.complete_study_session(gen_random_uuid(), cat_h, 25, false, 1500, now() - interval '150 minutes');
  v_res2 := public.complete_study_session(gen_random_uuid(), cat_h, 25, false, 1500, now() - interval '50 minutes');
  EXECUTE 'RESET ROLE';
  SELECT weekly_points INTO v_int FROM public.league_memberships WHERE user_id = uh;
  res := res || ('T46 kapanmış döneme ait geç seans lig puanı almaz, puan/kum alır: '
                 || coalesce((v_res->>'league_period_closed')::boolean AND (v_res->>'league_points')::int = 0
                             AND (v_res->>'total_points')::int > 0 AND (v_res->>'coins_earned')::int = 20, false)::text);
  res := res || ('T47 yeni dönemde biten seans yeni döneme yazılır (' || v_int || '): '
                 || coalesce(NOT (v_res2->>'league_period_closed')::boolean AND (v_res2->>'league_points')::int > 0
                             AND v_int = (v_res2->>'league_points')::int, false)::text);

  UPDATE public.leagues SET end_date = now() - interval '45 minutes' WHERE id = l_i;
  UPDATE public.league_memberships SET league_id = l_i2, weekly_points = 0 WHERE user_id = ui;
  SELECT period_started_at INTO v_ts FROM public.league_memberships WHERE user_id = ui;
  res := res || ('T48 başka lige taşınan üyenin dönemi eski ligin bitişinde başlar: ' || coalesce(v_ts = now() - interval '45 minutes', false)::text);
  UPDATE public.leagues SET end_date = end_date + interval '1 day' WHERE id = l_i2;
  SELECT period_started_at INTO v_ts2 FROM public.league_memberships WHERE user_id = ui;
  res := res || ('T49 bitmemiş ligin süresini uzatmak yeni dönem başlatmaz: ' || coalesce(v_ts2 = v_ts, false)::text);

  -- Eski (yasaklı adlı) kullanıcı: seansı kaydedilir, mevcut üyeliğine yazılır
  SELECT id INTO cat_x FROM public.categories WHERE user_id = d.u_legacy LIMIT 1;
  PERFORM set_config('request.jwt.claims', json_build_object('sub', d.u_legacy, 'role', 'authenticated')::text, true);
  EXECUTE 'SET LOCAL ROLE authenticated';
  v_res := public.complete_study_session(gen_random_uuid(), cat_x, 25, false, 1500, now() - interval '2 hours');
  EXECUTE 'RESET ROLE';
  SELECT weekly_points INTO v_int FROM public.league_memberships WHERE user_id = d.u_legacy;
  res := res || ('T50 eski kullanıcının seansı kaydedilir, mevcut lig üyeliğine eklenir (' || v_int || '): '
                 || coalesce((v_res->>'league_points')::int = 5 AND v_int = 12, false)::text);

  RAISE EXCEPTION 'DRYRUN_RESULT >> %', array_to_string(res, ' || ');
END
$dry$;

ROLLBACK;
