-- ============================================================================
-- ÖNERİ 13: SUNUCU BÜTÜNLÜĞÜ                               ÖNCELİK: P1 (UX-01)
-- ============================================================================
-- ##########################################################################
-- ##  ÜRÜN KARARI GEREKİYOR (UX-01, aşağıda "UX-01 SEÇENEKLERİ").          ##
-- ##  Dosya canlı davranışı DEĞİŞTİRMEDEN uygulanabilir: kararın düğmesi   ##
-- ##  app_config.unverified_session_daily_cap; varsayılanı null (= bugün). ##
-- ##########################################################################
--
-- 3 Ekim 2026'da canlı tanımlar (pg_get_functiondef, pg_policies, kolon /
-- rutin yetkileri, trigger'lar, index'ler) Supabase MCP ile SALT OKUNARAK
-- yazıldı. Değiştirilen her fonksiyonun gövdesi canlı gövdenin üzerine
-- kuruldu; eski gövdeler 13_sunucu_butunluk_down.sql'de birebir duruyor.
--
-- KAPSAM
--  UX-01   Saat sahteciliği: sunucu başlangıç kaydı (register_session_start)
--          ve complete_study_session'da eşleşme; doğrulanmamış seanslar
--          için ayarlanabilir günlük tavan.
--  LİG     Dönem sınırı: önceki (kapanmış) lig dönemine ait geç gelen seans
--          lig puanı ALMAZ, açıkça işaretlenir (league_period_closed);
--          ömür boyu puan, kum, seri ve dakika verilir.
--  KAYIT   handle_new_user friend_code çakışmasında yeniden dener (8 deneme).
--  KVKK-17 Arkadaş kodu: yeni kodlar Crockford base32 (6 karakter = 32^6 ≈
--          1,07 milyar; eski 6 hex ≈ 16,7 milyon), uzunluk app_config ile
--          8'e çıkarılabilir; kullanıcı başına saatlik deneme sınırı;
--          kabul edilmeden yanıtta karşı tarafın id'si dönmez. Mevcut kodlar
--          değişmez ve çalışmaya devam eder.
--  KVKK-20 profiles.email kopyası: okuyan yok (canlı fonksiyonlar, view'lar,
--          istemci ownProfileColumns, Edge Function'lar, scripts/ tarandı).
--          Kolon boşaltılır ve trigger'la boş tutulur; eski istemcinin yedek
--          upsert'ü kırılmasın diye kolon ve INSERT(email) yetkisi 2. aşamaya
--          kadar durur (dosya sonunda yorum olarak).
--  UX-08   app_config tablosu + anon/authenticated okunabilir get_app_config().
--  HİJYEN  search_path'inde pg_temp olmayan 10 SECURITY DEFINER fonksiyon
--          (gövdeye dokunmadan ALTER FUNCTION ... SET search_path).
--  İÇERİK  profiles.name ve categories.name için BEFORE trigger (kontrol /
--          görünmez karakter temizliği, kategori 1..40, küçük yasaklı sözcük
--          tablosu); start_study_session kategori adını 40 karakterle sınırlar,
--          süreyi 0..50 dk ile doğrular.
--
-- ---------------------------------------------------------------------------
-- UX-01 SEÇENEKLERİ (bulgu: cihaz saati ileri alınınca ya da RPC doğrudan
-- çağrılınca sunucu p_started_at'e güveniyor; son 24 saatin boş aralıklarına
-- günde 16 seans yerleştirilebiliyor, dünkü gün doldurulup seri onarılabiliyor)
-- ---------------------------------------------------------------------------
--  A) SUNUCU BAŞLANGIÇ KAYDI + EŞLEŞME  (ÖNERİLEN; bu dosyada)
--     İstemci her seans başında, sosyal görünürlükten bağımsız olarak
--     register_session_start(client_uuid, süre) çağırır; sunucu kendi now()
--     değerini session_starts'a yazar. complete_study_session aynı
--     client_uuid ve süreyle bir kayıt bulur VE sunucu saatine göre süre
--     dolmuşsa (60 sn pay) seans "doğrulanmış" sayılır, started_at sunucu
--     kaydından alınır (istemcinin p_started_at'i yok sayılır; geriye
--     kaydırma, dünkü günü doldurma işe yaramaz). Kayıt yoksa ya da süre
--     sunucu saatine göre dolmamışsa seans "doğrulanmamış"tır ve BUGÜNKÜ
--     canlı kurallarla değerlendirilir (5 dk tolerans, 24 saat, overlap,
--     session_not_finished aynen). Doğrulanmamış seansa ne olacağı ÜRÜN
--     KARARIdır ve tek düğmeyle ayarlanır:
--       A1  unverified_session_daily_cap = null  → bugünkü davranış; yalnızca
--           study_sessions.start_verified ile oran ölçülür. (VARSAYILAN)
--       A2  = 4 (ÖNERİLEN, yeni istemci yayınlanıp min_supported_version
--           yükseltildikten SONRA) → aynı çalışma gününde ilk 4 doğrulanmamış
--           seans tam ödül alır; sonrakiler günlük tavandaki gibi 0 puan,
--           0 kum, 0 lig puanı (dakika ve seri yine sayılır).
--       A3  = 0 → doğrulanmamış seans hiç puan/kum/lig almaz.
--  B) YALNIZCA MAKUL PENCERE KONTROLLERİ (tolerans 5→1 dk, saat başına
--     en fazla ~2 seans vb.): saat ileri almayı ve RPC'yi doğrudan çağırıp
--     son 24 saatin boşluklarını doldurmayı ENGELLEMEZ, yalnızca yavaşlatır.
--     Tek başına yetersiz; A ile birlikte gereksiz.
--  C) İSTEMCİ İMZASI / CİHAZ DOĞRULAMASI (Play Integrity, App Attest,
--     HMAC): doğrudan RPC çağrısını zorlaştırır ama saat ileri almayı
--     engellemez (zaman yine cihazdan gelir); Edge Function + anahtar
--     yönetimi ister. A'dan sonra değerlendirilebilir.
--
--  ÜRÜN ETKİSİ (ÇEVRİMDIŞI KULLANICI):
--   - Seansı ağ yokken BAŞLATAN kullanıcının başlangıç kaydı oluşmaz; seans
--     bitince (ya da kuyruktan sonra) yine KABUL EDİLİR, kaybolmaz.
--   - A1'de hiçbir fark yok. A2'de çevrimdışı başlatılan seansların günde
--     yalnızca ilk 4'ü puan/kum/lig kazandırır (25 dk ile ~1,5-3 saat);
--     uçakta/kampta bütün gün çalışan kullanıcı o günün fazlasında dakika
--     ve seri kazanır, puan kazanmaz. A3 çevrimdışı çalışmayı tamamen
--     ödülsüz bırakır (önerilmez).
--   - Ağ seans başında var, sonunda yoksa: kayıt oluşmuştur; seans kuyrukta
--     bekler ve gönderildiğinde doğrulanmış sayılır (24 saat içinde).
--   - Eski istemciler (register_session_start'ı bilmeyen) tüm seanslarını
--     doğrulanmamış gönderir. Bu yüzden düğme, UX-08 ile minimum sürüm
--     yükseltilmeden açılmamalı. Sözleşme kırılmaz: hiçbir RPC imzası,
--     yanıt anahtarı ya da seans hata metni değişmez veya kaldırılmaz
--     (yanıta yalnızca yeni anahtarlar eklenir).
--
-- ---------------------------------------------------------------------------
-- LİG DÖNEMİ SINIRI (missing_lenses: ensure_user_in_league)
-- ---------------------------------------------------------------------------
--  Canlıda puan, gönderim anındaki aktif üyeliğe yazılıyor: Pazar gecesi biten
--  ya da kuyrukta bekleyen seans cron'dan (Pazar 21:01 UTC) sonra gelirse eski
--  dönemin puanı yeni döneme yazılıyor. Eski dönem kapanmış (terfi/ödül
--  verilmiş, puanlar sıfırlanmış) olduğu için puanı oraya yazmak mümkün değil.
--  KARAR: seansın BİTİŞİ (completed_at = started_at + süre) üyeliğin şimdiki
--  dönem başlangıcından önce ya da ona eşitse lig puanı verilmez; yanıtta
--  league_period_closed = true, league_points = 0. Ömür boyu puan, kum, seri
--  ve dakika verilir (aylık/tüm zamanlar sıralaması completed_at ayına göre
--  zaten doğru döneme yazar).
--  Dönem başlangıcı league_memberships.period_started_at'te tutulur:
--   - üyelik eklenince: ligin end_date - 14 gün;
--   - process_weekly_leagues ligin end_date'ini ileri aldığında (trigger):
--     o ligde kalan üyeler için eski end_date;
--   - üye başka lige taşınınca (terfi/düşme, trigger): eski ligin end_date'i.
--  Trigger tabanlı olduğu için process_weekly_leagues'e dokunulmaz; ileride
--  02 önerisi gibi bir yeniden yazım da (end_date'i güncellediği ve league_id
--  değiştirdiği sürece) bu takibi bozmaz.
--
-- ---------------------------------------------------------------------------
-- İSTEMCİ SÖZLEŞMESİ (CLIENT CONTRACT) — istemci entegrasyonu bu dosyada YOK;
-- AGENTS.md kuralı gereği istemci bu RPC'leri ancak canlıya uygulandıktan
-- sonra çağırabilir.
-- ---------------------------------------------------------------------------
--  1. get_app_config() → jsonb (anon + authenticated, parametresiz):
--       { "server_time": timestamptz, "config_schema": 1,
--         "min_supported_version": {"android": {"version": "1.0.0", "build": 1},
--                                   "ios":     {"version": "1.0.0", "build": 1}},
--         "latest_version":        { aynı biçim },
--         "store_url":             {"android": text|null, "ios": text|null},
--         "unverified_session_daily_cap": int|null,
--         "friend_code_length": int }
--     Karşılaştırma build numarasıyla (PackageInfo.buildNumber) yapılır;
--     "version" yalnızca gösterim içindir. build < min_supported → engelleyen
--     "Güncelle" ekranı; build < latest → kapatılabilir bant. Çağrı başarısızsa
--     uygulama ENGELLENMEZ (fail-open). Bilinmeyen anahtarlar yok sayılır.
--     server_time ilk saat farkı ölçümü için kullanılabilir.
--  2. register_session_start(p_client_uuid uuid, p_duration_minutes int)
--       → {client_uuid, server_started_at, server_now, created}
--     Seans GERÇEKTEN başlarken (3-2-1'den sonra) bir kez, sosyal görünürlükten
--     bağımsız çağrılır; duraklatma/devamda tekrar çağrılmaz (çağrılırsa ilk
--     kayıt döner). Başarısızsa seans yine çalışır, yalnızca doğrulanmamış
--     gider; SONRADAN yeniden denenmez (geç kayıt seansı doğrulatmaz).
--     Hatalar: 'not authenticated', 'invalid duration: only 25 or 50 allowed',
--     'invalid client_uuid', 'too_many_session_starts' (son 24 saatte
--     tamamlanmamış 100 başlangıç; tamamlanan seansın kaydı silinir).
--  3. complete_study_session yanıtına EKLENEN anahtarlar (eskiler aynen):
--       start_verified bool, unverified_limit_reached bool,
--       league_points int (lige gerçekten yazılan), league_period_closed bool.
--     unverified_limit_reached → "çevrimdışı başlatılan seans sınırı" metni;
--     league_period_closed → "seans önceki lig dönemine ait, lig puanı
--     yazılmadı" metni. Yeni HATA metni yok; classifySessionError değişmez.
--  4. add_friend_by_code: yanıtta makine-okunur 'code' alanı: not_found,
--     self_add, already_friends, already_pending, accepted, request_sent ve
--     yeni rate_limited (success=false). Bekleyen istekte friend.id artık yok
--     (istemci yalnızca friend.name'i okuyor). Kod girişi 8 karaktere kadar
--     kabul etmeli (şu an _codeLength = 6); boşluk/tire sunucuda da atılır,
--     O→0, I/L→1 eşlenir. Ardından friend_code_length 8 yapılabilir.
--  5. İçerik: profiles.name / categories.name yazımında SQLSTATE 23514 ve
--     mesaj 'profile_name_not_allowed', 'category_name_not_allowed',
--     'category_name_invalid_length'. Bugünkü istemci 23xxx'i invalidInput'a
--     eşliyor (kırılmaz); yeni istemci bunları nameNotAllowed vb. eşlemeli,
--     kategori diyaloğunda da NameFilter uygulamalı.
--  6. KVKK-20 2. aşama: istemci _ensureOwnProfile upsert'ünden 'email'
--     anahtarını kaldırdıktan ve o sürüm minimum yapıldıktan sonra dosya
--     sonundaki yorumdaki SQL çalıştırılır.
--  7. RPC imzası değişecekse eski imza bir sürüm boyunca overload olarak
--     korunur; minimum sürüm yükseltilmeden kaldırılmaz (UX-08).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- UYGULAMA SIRASI (supabase/proposed/README.md "Dosyalar ve uygulama sırası"):
--   12 → 15 → 16 → 19 → 13 → 14. 13, 14'ten ÖNCE gelir: 14 handle_new_user
--   ve add_friend_by_code'u 13'ün gövdesi üzerine kurar ve ön koşulunda
--   13 uygulanmış md5'leri bekler. Dosyanın ilk adımı (0) aşağıdaki md5'leri
--   kendisi denetler; 14 önce uygulanmışsa hiçbir şey yapmadan durur.
--   Geri alma ters sırada: 14_down → 13_down → 19_down → 16_down → 15_down → 12_down.
--
-- ADIMLAR (SQL Editor, sırayla)
--  0. (Önerilir) Yedek: supabase db dump --schema public -f yedek.sql
--  1. Canlı gövdelerin bu dosya yazılırken okunanlarla aynı olduğunu doğrulayın
--     (dosyanın 0. adımı da aynı denetimi yapar):
--       select p.oid::regprocedure, md5(pg_get_functiondef(p.oid))
--         from pg_proc p where p.pronamespace = 'public'::regnamespace
--          and p.proname in ('complete_study_session','handle_new_user',
--              'add_friend_by_code','start_study_session','ensure_user_in_league',
--              'process_weekly_leagues') order by 1;
--     Beklenen (3 Ekim 2026):
--       add_friend_by_code(text)                d59affef7f113a3072d2de604bb9506f
--       complete_study_session(...)             592ede066173f30b64006f02b5141756
--       ensure_user_in_league(uuid,integer)     e5674f687157135f7c5feaba2de56a7e
--       handle_new_user()                       ae6cedf2e0e0995ec759b69e20ada604
--       process_weekly_leagues()                3d547d20a94f32e3cf531a7c3888d536
--       start_study_session(integer,text)       706f87a96d7b6d7d6c776aa64ecb3772
--     Farklıysa DURUN: bu dosya o gövdelere göre yeniden yazılmalı.
--     (12, 15, 16, 19 bu altı fonksiyona dokunmaz; onlardan sonra da aynıdır.)
--  2. Kuru çalıştırma: supabase/tests/proposed_13_sunucu_butunluk_dryrun.sql
--     (sonda DRYRUN_RESULT hatası beklenir; her satır 'true' olmalı). Birkaç
--     saniye profiles/categories/leagues tablolarını kilitler; az trafikli
--     bir anda çalıştırın.
--  3. Bu dosyayı \echo/\quit satırları olmadan
--     supabase/migrations/20261004120000_sunucu_butunluk.sql olarak kopyalayıp
--     SQL Editor'de çalıştırın (sondaki migration geçmişi kaydı aynı sürümü
--     kullanır; dosya adını değiştirirseniz orayı da değiştirin).
--  4. Doğrulama: select public.get_app_config(); ve 1. adımdaki sorgu
--     (değişen gövdeler artık farklı md5 verir), AGENTS.md §2.3 sorguları.
--  5. Geri alma: supabase/proposed/13_sunucu_butunluk_down.sql (14 uygulandıysa
--     önce 14_gizlilik_sosyal_down.sql; 13_down bunu denetler)
--  6. Ürün kararı sonrası (istemci güncellemesi + minimum sürüm):
--       update public.app_config set value = '4', updated_at = now()
--        where key = 'unverified_session_daily_cap';
--       update public.app_config set value = '8', updated_at = now()
--        where key = 'friend_code_length';
-- ============================================================================

\echo 'supabase/proposed/13: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

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

COMMIT;

-- ============================================================================
-- KVKK-20 — 2. AŞAMA (ŞİMDİ ÇALIŞTIRMAYIN)
-- Ön koşul: istemci _ensureOwnProfile upsert'ünden 'email'i kaldırdı ve o
-- sürüm app_config.min_supported_version yapıldı. Aksi halde eski sürümün
-- yedek profil oluşturma isteği 42501/PGRST204 ile düşer.
--
--   BEGIN;
--   REVOKE INSERT (email) ON public.profiles FROM authenticated;
--   DROP TRIGGER IF EXISTS discard_profile_email ON public.profiles;
--   DROP FUNCTION IF EXISTS public.discard_profile_email();
--   ALTER TABLE public.profiles DROP COLUMN email;
--   COMMIT;
-- ============================================================================
