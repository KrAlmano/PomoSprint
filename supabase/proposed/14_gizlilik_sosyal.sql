-- ============================================================
-- ÖNERİ 14: Gizlilik ve sosyal güvenlik (sunucu)     ÖNCELİK: P1 / P2
-- ============================================================
-- Bulgular: PLAY-04 (sunucuda engelleme / arkadaşlıktan çıkarma yok),
-- PLAY-05 (bildirim kaydı ve operatör aracı yok), ACC-06 (e-postadan ad
-- türetme, tek kelimelik ad maskelenmiyor), KVKK-01 (görünürlük varsayılan
-- açık; sunucu kısmı), KVKK-03 (anon sıralamalar 100 kişi, alltime
-- is_premium), KVKK-06 (activity_feed), KVKK-10 (onay ispat kaydı),
-- ACC-13 (saklama süresi otomasyonu), KVKK-09 (bülten onayını sonradan
-- verme / geri alma RPC'leri; sunucu kısmı).
--
-- 3 Ekim 2026'da CANLI tanımlar okunarak yazıldı (pg_get_functiondef,
-- pg_policies, information_schema yetkileri, pg_default_acl, cron.job,
-- pg_trigger; canlı PostgreSQL 17.6) ve proposed/13 UYGULANMIŞ duruma göre
-- yeniden temellendirildi: handle_new_user ve add_friend_by_code 13'ün
-- gövdesi üzerine kurulur (13'ün değişiklikleri korunur, 14'ünkiler
-- eklenir); handle_newsletter_subscription ve respond_friend_request'in
-- yeni gövdeleri 13'ün eklediği pg_temp'i taşır. Değiştirilen her
-- fonksiyonun 13 uygulanmış hâldeki gövdesi 14_gizlilik_sosyal_down.sql
-- içinde birebir duruyor. Dosyanın ilk adımı 13'ün uygulandığını ve
-- gövdelerin md5'ini denetler: 13 yoksa ya da araya başka bir değişiklik
-- girdiyse hiçbir şey yapmadan hata verir.
--
-- UYGULAMA SIRASI: 12 → 15 → 16 → 19 → 13 → 14 (supabase/proposed/README.md
-- "Dosyalar ve uygulama sırası"). Geri alma ters sırada; 14_down 13
-- uygulanmış hâle döner.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır; 13 uygulandıktan SONRA)
--  1. Kuru çalıştırma: supabase/tests/proposed_14_gizlilik_sosyal_dryrun.sql
--     Sonda DRYRUN_RESULT hatası beklenir; her satır 'true' olmalı. 13
--     uygulanmamışsa 'proposed/14 ön koşulu: önce proposed/13 ...' hatası.
--  2. Ürün kararlarını verin (aşağıda ÜRÜN ETKİSİ ve İSTEMCİ ÖN KOŞULU).
--     Karar 'hayır' olan bölümü çıkarın ya da down dosyasındaki karşılığıyla
--     değiştirin (o zaman DRYRUN'u da aynı biçimde düzeltip yeniden koşun).
--  3. Bu dosyanın \echo ve \quit satırlarını silip SQL Editor'de çalıştırın
--     (ya da gövdeyi supabase/migrations/20261003194000_privacy_social.sql
--     olarak kopyalayın). Sondaki DO bloğu migration geçmişine yazar.
--  4. Doğrulama: AGENTS.md §2.3 sorguları + `select * from cron.job;`
--  5. Geri alma: supabase/proposed/14_gizlilik_sosyal_down.sql
--  6. İstemci bağlantısı (ayrı iş, 14 canlıya uygulandıktan SONRA):
--     sözleşme supabase/proposed/README.md "Öneri 14" bölümünde.
--
-- İSTEMCİ ÖN KOŞULU (ACC-06, Apple ile giriş)
--  Apple id_token'ında ad yok; 14'ten sonra Apple ile ilk girişte profil adı
--  'Pomo 1234' biçiminde nötr ad olur. Bugünkü istemcinin
--  providerFirstNameUpdate'i yalnızca e-posta yerel kısmını "varsayılan ad"
--  sayıyor; nötr adı görünce credential.givenName'i YAZMAZ (Apple adı yalnızca
--  ilk girişte verir, sonradan alınamaz). Bu yüzden 14'ten ÖNCE istemcide
--  '^Pomo \d{4}$' kalıbı da varsayılan sayılmalı (canlı sunucuya bağımlı
--  olmayan, bugün yayınlanabilecek bir değişiklik). Google etkilenmez
--  (ilk ad sunucuda yazılır).
--
-- ÜRÜN ETKİSİ (uygulamadan önce okuyun)
--  * KVKK-01: profiles.show_in_social_feed varsayılanı FALSE olur. Yeni
--    kullanıcılar Profil > "Sosyal Listede Görün"ü açana kadar aylık
--    sıralamada, sitedeki herkese açık listede ve arkadaşların "Şu An
--    Çalışanlar" listesinde görünmez; Shell start_study_session'ı
--    çağırmaz. Lig odası ve arkadaş listesi etkilenmez. Mevcut
--    kullanıcıların değeri DEĞİŞMEZ (hukukçuyla karar). Kayıt metadata'sında
--    show_in_social_feed=true gönderen istemci (ileride onboarding'deki
--    açık seçim) varsayılanı aşar. Aylık liste ve site listesi zamanla
--    seyrekleşir; onboarding'e bir "Sıralamalarda görün" adımı önerilir.
--  * ACC-06: Yeni hesaplarda görünen ad e-postanın yerel kısmından
--    türetilmez; ad yoksa (ya da proposed/13'ün listesindeki yasaklı bir
--    ifadeyi içeriyorsa ya da istemcinin boş ad yedeği olan e-posta
--    yerel kısmıyla birebir aynıysa) 'Pomo 1234' biçiminde nötr bir ad
--    yazılır (arkadaş kodundan türetilmez; kod gizli kalır). Google/Apple'da
--    adın yalnızca ilk kelimesi alınır. Mevcut kullanıcıların adları
--    DEĞİŞMEZ; isteğe bağlı `select ops.neutralize_email_derived_names();`
--    (ürün kararı). Herkese açık (oturumsuz) listede tek kelimelik ad 'Ahm…'
--    biçiminde kısaltılır: privacy §4 metni ("tek kelimelik bir ad olduğu
--    gibi") ve terms §4 güncellenmeli.
--  * KVKK-03: Oturumsuz aylık sıralama en çok 10 satır döner (site zaten
--    10 istiyor). get_public_alltime_leaderboard anon'a kapanır ve
--    is_premium döndürmez (istemci ve site çağırmıyor).
--  * PLAY-04: get_my_league_ranking / get_league_ranking ve
--    get_public_monthly_leaderboard dönüşüne `id` ve `is_blocked`
--    kolonları EKLENİR (DROP + CREATE; mevcut kolonlar ve sırası aynı).
--    Mevcut istemci `id`'yi zaten okuyor (RankingEntry.userId): bildirim
--    e-postasına kimlik girer, gizleme kimlikle eşlenir. Oturum açmış
--    kullanıcı lig odasındaki ve aylık listedeki kişilerin kimliğini görür
--    (engelleme/bildirim için gerekli; kimlikle başka bir veri okunamaz).
--    Oturumsuz çağrıda id NULL. Engellenen kullanıcının satırı silinmez
--    (sıra ve lig bölgeleri bozulmasın); ad ve avatar NULL döner.
--  * KVKK-06: activity_feed'e yazım varsayılan olarak DURUR
--    (ops.activity_feed_enabled() = false; arayüzü yok). Görünürlüğü
--    kapalı kullanıcıların mevcut kayıtları bu migration'da silinir; diğer
--    kayıtlar canlıdaki cleanup_activity_feed_job ile 30 günde biter.
--    Özellik gelince o fonksiyonu true döndürecek şekilde değiştirin; o
--    zaman da yalnızca görünürlüğü açık kullanıcıların kayıtları yazılır ve
--    görünürlük kapatılınca eski kayıtlar silinir. authenticated'ın tabloyu
--    doğrudan okuma yetkisi kalkar (istemci okumuyor).
--  * KVKK-10: Onay kayıt defteri (public.consents). Hesap silinince kayıt
--    silinmez; user_id NULL olur, e-posta özeti (sha256) ile 1 yıl
--    saklanır (ops.run_privacy_retention; süre hukukçuyla doğrulanmalı).
--    privacy §6 ve §10 ("onay kayıtlarınız ... silinir") güncellenmeli.
--  * ACC-13: Günlük pg_cron işi 'privacy_retention_daily': 7 günden eski
--    onaysız kayıtlar, 12 aydan eski bekleme listesi kayıtları, süresi
--    dolan onay / bildirim / ret kayıtları silinir. privacy §7 ve §10'a
--    saklama süreleri yazılmalı.
--
-- İLİŞKİLER (diğer öneriler)
--  * proposed/13 (sunucu bütünlüğü): ZORUNLU ön koşul, 14'ten ÖNCE. 14
--    13'ün yardımcılarını kullanır ve iki fonksiyonunu onun üzerine kurar.
--    13 14'ten sonra uygulanamaz (13'ün ön koşulu durur); 13_down da 14
--    yerindeyken durur (önce 14_down).
--  * proposed/15 (aylık sıralama = çalışma ayı): 14 hem canlı hem 15
--    uygulanmış gövdeyi tanır ve aylık sıralamayı o ay kuralıyla kurar.
--    Sırada 14'ten ÖNCE; 14'ten SONRA uygulanamaz (dönüş tipi farklı,
--    CREATE OR REPLACE hata verir) ve gerekmez.
--  * proposed/16 ve 19: çakışma yok (kategoriler / bekleme listesi
--    kolonları); sırada 13'ten önce.
--  * proposed/11 §2 (arkadaş RPC'leri): remove_friend, cancel_friend_request,
--    get_outgoing_friend_requests burada CANLIYA UYUMLU gövdeyle (my_friend_ids
--    gerekmeden, engel filtresiyle) ve 11 ile AYNI yanıt sözleşmesiyle
--    tanımlanır. 14, 11 §2'yi kapsar ve geçersiz kılar: 11'in o bölümü
--    14'ten önce uygulanmışsa 14 ön koşul denetiminde durur; sonra
--    uygulanırsa engel filtresini geri alır. 11 §2'yi UYGULAMAYIN.
--  * proposed/07: A (activity_feed RLS), B (get_live_friends tekilleştirme)
--    ve E (makine-okunur 'code') burada karşılanır; 07'nin bu bölümleri ve
--    get_friends_feed/get_live_friends gövdeleri 14'ten sonra uygulanırsa
--    engel filtresini kaldırır. UYGULAMAYIN.
--  * proposed/03: aylık sıralama ve maskeleme REFERANS gövdesi; 14 kapsar.
--  * proposed/12 (delete_own_account): çakışma yok; 14 delete_own_account'a
--    dokunmaz (sırada 12 ilk adım). Bekleme listesinin hesap silmede
--    temizlenmesi (ACC-13'ün o kısmı) 12'de. 12 ile user_id'siz abonelik
--    satırının silinmesi onay kaydına 'unsubscribe_or_admin' kaynağıyla
--    düşer; istenirse 12'deki o DELETE'ten önce
--    `PERFORM set_config('pomosprint.consent_source', 'account_deleted', true);`
--    eklenebilir. Hesaba bağlı abonelik satırı cascade ile silinince kaynak
--    zaten 'account_deleted' olur.
-- ============================================================

\echo 'supabase/proposed/14: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ============================================================
-- 0) Ön koşul: proposed/13 uygulanmış mı, değiştirilecek gövdeler
--    beklenen hâlde mi?
-- ============================================================
-- Uygulama sırası 12 → 15 → 16 → 19 → 13 → 14. Bu dosya handle_new_user ve
-- add_friend_by_code'u 13'ün gövdesi üzerine kurar ve 13'ün yardımcılarını
-- (clean_display_text, display_text_is_allowed, generate_friend_code,
-- normalize_friend_code, app_config_int, friend_code_attempts) kullanır.
-- md5(pg_get_functiondef) değerleri: dört fonksiyon için 13 UYGULANMIŞ hâl
-- (handle_new_user ve add_friend_by_code 13'ün gövdesi;
-- handle_newsletter_subscription ve respond_friend_request canlı gövde +
-- 13'ün ALTER ... SET search_path 'public','pg_temp'i), diğerleri canlı
-- (3 Ekim 2026; 12, 16, 19 ve 13 onlara dokunmaz). Farklıysa hiçbir şey
-- yapılmadan durulur. Aylık sıralama canlı ya da proposed/15 uygulanmış
-- hâlde olabilir (E bölümü ikisini de tanır).
DO $pre$
DECLARE
    v_expected constant jsonb := '{
        "add_friend_by_code(text)": "eab30b000bbd223a3eef0af8e9900b30",
        "respond_friend_request(uuid,boolean)": "785731c7b2c628d65a5f9e84a60be5d5",
        "get_my_friends()": "c914de18b0e6f080c7b3fe4f4fead8b2",
        "get_incoming_friend_requests()": "de9f1fd811b87172bd7f59aff204bf66",
        "get_live_friends()": "174841fa81aff71912908ebcfe0935ff",
        "mask_public_name(text)": "124a0ddc389a4d352c65f4b554b12d7f",
        "get_league_ranking(uuid)": "81232005815cf301aa8ce29e882d5139",
        "get_my_league_ranking()": "cdcb245dd779a9eb7b651ec5a27426c5",
        "get_public_alltime_leaderboard(integer)": "60aac1f74b39ab6af9c5399cf285c607",
        "handle_new_user()": "92dcc142fbec96ca2fb79a7aa3d14289",
        "handle_newsletter_subscription()": "ecf943e2d250d60989ca04bd79e90152",
        "sanitize_profile_insert()": "c1eab282e0d125d278be390a2a187ea9"
    }';
    v_monthly_ok constant text[] := ARRAY[
        '801f6f83e6dbe4cf1394f7c1751a407d',   -- canlı (completed_at, İstanbul ayı)
        '3865c94b1bdb69161d576354ffcff6c2'    -- proposed/15 uygulanmış (çalışma ayı)
    ];
    r record;
    v_bad text[] := '{}';
BEGIN
    IF to_regclass('public.app_config') IS NULL
       OR to_regclass('public.friend_code_attempts') IS NULL
       OR to_regprocedure('public.clean_display_text(text)') IS NULL
       OR to_regprocedure('public.display_text_is_allowed(text)') IS NULL
       OR to_regprocedure('public.generate_friend_code(integer)') IS NULL
       OR to_regprocedure('public.normalize_friend_code(text)') IS NULL
       OR to_regprocedure('public.app_config_int(text)') IS NULL THEN
        RAISE EXCEPTION 'proposed/14 ön koşulu: önce proposed/13_sunucu_butunluk.sql uygulanmalı (sıra: 12 → 15 → 16 → 19 → 13 → 14).';
    END IF;
    FOR r IN SELECT key, value FROM jsonb_each_text(v_expected) LOOP
        IF md5(pg_get_functiondef(to_regprocedure('public.' || r.key))) IS DISTINCT FROM r.value THEN
            v_bad := v_bad || r.key;
        END IF;
    END LOOP;
    IF to_regprocedure('public.get_public_monthly_leaderboard(integer)') IS NULL
       OR NOT md5(pg_get_functiondef('public.get_public_monthly_leaderboard(integer)'::regprocedure)) = ANY (v_monthly_ok) THEN
        v_bad := v_bad || 'get_public_monthly_leaderboard(integer)'::text;
    END IF;
    IF to_regprocedure('public.remove_friend(uuid)') IS NOT NULL
       OR to_regprocedure('public.cancel_friend_request(uuid)') IS NOT NULL
       OR to_regprocedure('public.get_outgoing_friend_requests()') IS NOT NULL THEN
        v_bad := v_bad || 'remove_friend/cancel_friend_request/get_outgoing_friend_requests zaten var (proposed/11?)'::text;
    END IF;
    IF array_length(v_bad, 1) > 0 THEN
        RAISE EXCEPTION 'proposed/14 ön koşulu: canlı tanım beklenenden farklı: %. Dosyayı yeni gövdeye uyarlayın.',
            array_to_string(v_bad, ', ');
    END IF;
END
$pre$;

-- ============================================================
-- A) ops şeması ve iç yardımcılar
-- ============================================================
-- Operatör araçları ve iç yardımcılar PostgREST'e açık olmayan ayrı bir
-- şemada durur. Settings > API > Exposed schemas'a 'ops' EKLEMEYİN.
CREATE SCHEMA ops;
REVOKE ALL ON SCHEMA ops FROM PUBLIC;
COMMENT ON SCHEMA ops IS
  'PomoSprint operatör araçları (SQL Editor) ve iç yardımcılar. API''ye açılmaz.';

-- Nötr görünen ad: 'Pomo 0427'. Arkadaş kodundan bağımsız (kod gizli kalır).
CREATE FUNCTION ops.neutral_display_name()
 RETURNS text
 LANGUAGE sql
 VOLATILE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT 'Pomo ' || lpad((floor(random() * 10000))::integer::text, 4, '0');
$function$;

-- Onay kaydında e-posta yerine saklanan özet (küçük harf, kırpılmış).
CREATE FUNCTION ops.email_hash(p_email text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT CASE
        WHEN nullif(btrim(p_email), '') IS NULL THEN NULL
        ELSE encode(sha256(convert_to(lower(btrim(p_email)), 'UTF8')), 'hex')
    END;
$function$;

-- İstemcinin gönderdiği zaman metnini güvenle çevirir (bozuksa NULL).
CREATE FUNCTION ops.try_timestamptz(p_value text)
 RETURNS timestamptz
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
        RETURN NULL;
    END IF;
    RETURN btrim(p_value)::timestamptz;
EXCEPTION WHEN others THEN
    RETURN NULL;
END;
$function$;

-- ============================================================
-- B) KVKK-10: onay kayıt defteri (consents)
-- ============================================================
-- Yalnızca sunucu yazar (istemcinin tablo yetkisi yok). Kayıt eklenir,
-- değiştirilmez; tek istisna hesap silinince ON DELETE SET NULL'ın
-- user_id'yi boşaltması (unlinked_at o an yazılır). Saklama:
-- ops.purge_old_consents (H bölümü).
CREATE TABLE public.consents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    email_hash text CHECK (email_hash IS NULL OR email_hash ~ '^[0-9a-f]{64}$'),
    kind text NOT NULL CHECK (kind IN ('terms', 'privacy_notice', 'marketing_email')),
    granted boolean NOT NULL,
    document_version text CHECK (document_version IS NULL OR char_length(document_version) <= 32),
    source text NOT NULL CHECK (source IN (
        'signup',                 -- kayıt formu (handle_new_user, metadata)
        'signup_email_confirmed', -- e-posta onayıyla bülten aboneliği açıldı
        'app_settings',           -- set_marketing_consent
        'app_legal_acceptance',   -- accept_legal_documents (Google/Apple)
        'app_direct',             -- istemcinin kendi abonelik satırını silmesi
        'unsubscribe_or_admin',   -- abonelikten çıkma bağlantısı / panel
        'admin',                  -- panelden / service role ile ekleme
        'account_deleted',        -- hesap silinirken abonelik kalktı
        'backfill'                -- bu migration'daki tek seferlik aktarım
    )),
    occurred_at timestamptz,      -- istemcinin bildirdiği an (terms_accepted_at) ya da eski kaydın zamanı
    -- Sunucu zamanı. now() değil: aynı işlemdeki kayıtlar (kayıt + onay
    -- gibi) ayrı anlara sahip olsun; 'son kayıt' sırası seq ile kesinleşir.
    recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    seq bigint GENERATED ALWAYS AS IDENTITY,
    unlinked_at timestamptz       -- kaydın hesapla bağı koptuğu an (saklama süresinin başlangıcı)
);
CREATE INDEX consents_user_kind_idx ON public.consents (user_id, kind, seq DESC);
CREATE INDEX consents_email_hash_idx ON public.consents (email_hash);
CREATE INDEX consents_unlinked_idx ON public.consents (unlinked_at) WHERE user_id IS NULL;
ALTER TABLE public.consents ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.consents FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.consents IS
  'KVKK/ETK onay ve ret ispat kaydı. Yalnızca sunucu yazar; hesap silinince user_id NULL, email_hash ile ops.purge_old_consents süresi kadar saklanır.';

CREATE FUNCTION public.consents_append_only()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    -- Yalnızca hesap silinince ON DELETE SET NULL'ın yaptığı güncelleme.
    IF OLD.user_id IS NOT NULL AND NEW.user_id IS NULL
       AND (NEW.id, NEW.email_hash, NEW.kind, NEW.granted, NEW.document_version,
            NEW.source, NEW.occurred_at, NEW.recorded_at, NEW.seq)
           IS NOT DISTINCT FROM
           (OLD.id, OLD.email_hash, OLD.kind, OLD.granted, OLD.document_version,
            OLD.source, OLD.occurred_at, OLD.recorded_at, OLD.seq) THEN
        NEW.unlinked_at := now();
        RETURN NEW;
    END IF;
    RAISE EXCEPTION 'consents is append-only' USING ERRCODE = '42501';
END;
$function$;
REVOKE ALL ON FUNCTION public.consents_append_only() FROM PUBLIC, anon, authenticated;

CREATE TRIGGER consents_append_only
    BEFORE UPDATE ON public.consents
    FOR EACH ROW EXECUTE FUNCTION public.consents_append_only();

CREATE FUNCTION ops.log_consent(
    p_user_id uuid,
    p_email text,
    p_kind text,
    p_granted boolean,
    p_version text,
    p_source text,
    p_occurred_at timestamptz DEFAULT NULL
)
 RETURNS void
 LANGUAGE sql
 VOLATILE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    INSERT INTO public.consents (user_id, email_hash, kind, granted, document_version,
                                 source, occurred_at, unlinked_at)
    VALUES (p_user_id, ops.email_hash(p_email), p_kind, p_granted,
            left(nullif(btrim(p_version), ''), 32), p_source, p_occurred_at,
            CASE WHEN p_user_id IS NULL THEN now() END);
$function$;

-- Bülten aboneliğinin her açılışı / kapanışı onay kaydına düşer (abonelikten
-- çıkma Edge Function'ı, istemcinin doğrudan silmesi, hesap silme cascade'i
-- ve aşağıdaki RPC'ler dahil). Kaynak, çağıranın işlem içi ayarından
-- (pomosprint.consent_source) okunur. Kayıt yazılamazsa asıl işlem
-- (e-posta onayı, abonelikten çıkma) BOZULMAZ; uyarı loglanır.
CREATE FUNCTION public.log_marketing_subscription_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_user uuid;
    v_email text;
    v_source text := nullif(current_setting('pomosprint.consent_source', true), '');
    v_version text := nullif(current_setting('pomosprint.consent_version', true), '');
BEGIN
    IF TG_OP = 'INSERT' THEN
        v_user := NEW.user_id;
        v_email := NEW.email;
    ELSE
        v_user := OLD.user_id;
        v_email := OLD.email;
    END IF;

    -- Hesap silinirken (auth.users satırı gitmiş, cascade) kayıt hesaptan ayrılır.
    IF v_user IS NOT NULL AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = v_user) THEN
        v_user := NULL;
        v_source := 'account_deleted';
    END IF;

    IF v_source IS NULL THEN
        v_source := CASE
            WHEN TG_OP = 'DELETE' AND v_user IS NOT NULL AND auth.uid() = v_user THEN 'app_direct'
            WHEN TG_OP = 'DELETE' THEN 'unsubscribe_or_admin'
            ELSE 'admin'
        END;
    END IF;

    BEGIN
        PERFORM ops.log_consent(v_user, v_email, 'marketing_email', TG_OP = 'INSERT', v_version, v_source);
    EXCEPTION WHEN others THEN
        RAISE WARNING 'log_marketing_subscription_change: onay kaydı yazılamadı: %', SQLERRM;
    END;
    RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION public.log_marketing_subscription_change() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.log_marketing_subscription_change() TO service_role;

CREATE TRIGGER log_marketing_subscription_change
    AFTER INSERT OR DELETE ON public.marketing_subscribers
    FOR EACH ROW EXECUTE FUNCTION public.log_marketing_subscription_change();

-- Canlı gövde (proposed/13 yalnızca search_path'ine pg_temp eklemişti) +
-- kaynak/sürüm bilgisi. Sözleşme aynı: yalnızca 'newsletter' = 'true' okunur.
CREATE OR REPLACE FUNCTION public.handle_newsletter_subscription()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
  -- Check if email_confirmed_at changed from NULL to NOT NULL
  IF (OLD.email_confirmed_at IS NULL AND NEW.email_confirmed_at IS NOT NULL) THEN
    -- Check if raw_user_meta_data contains "newsletter": true
    IF (NEW.raw_user_meta_data->>'newsletter' = 'true') THEN
      PERFORM set_config('pomosprint.consent_source', 'signup_email_confirmed', true);
      PERFORM set_config('pomosprint.consent_version',
                         coalesce(left(nullif(btrim(NEW.raw_user_meta_data->>'terms_version'), ''), 32), ''), true);
      INSERT INTO public.marketing_subscribers (user_id, email)
      VALUES (NEW.id, NEW.email)
      ON CONFLICT DO NOTHING;
      PERFORM set_config('pomosprint.consent_source', '', true);
      PERFORM set_config('pomosprint.consent_version', '', true);
    END IF;
  END IF;
  RETURN NEW;
END;
$function$;

-- ------------------------------------------------------------
-- KVKK-09: bülten onayını uygulamadan verme / geri alma
-- ------------------------------------------------------------
-- Google/Apple kullanıcıları dahil (e-postası onaylı herkes). Açınca
-- marketing_subscribers satırı eklenir (daha önce abone olmuş birine ikinci
-- hoş geldin e-postası gitmez), kapatınca satır ve aynı e-postanın bekleme
-- listesi kaydı silinir. Her değişiklik consents'e düşer. Metadata'daki
-- 'newsletter' / 'marketing_consent' de güncellenir (tutarlılık için).
CREATE FUNCTION public.set_marketing_consent(p_enabled boolean, p_text_version text DEFAULT NULL)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_email text;
    v_confirmed boolean;
    v_changes integer;
    v_subscribed boolean;
    v_deleted integer := 0;
    v_prev boolean;
    v_version text := left(nullif(btrim(p_text_version), ''), 32);
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_enabled IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_input');
    END IF;

    SELECT lower(btrim(u.email)), u.email_confirmed_at IS NOT NULL
      INTO v_email, v_confirmed
      FROM auth.users u
     WHERE u.id = v_uid;
    v_confirmed := coalesce(v_confirmed, false) AND coalesce(v_email, '') <> '';

    v_subscribed := EXISTS (
        SELECT 1 FROM public.marketing_subscribers ms
         WHERE ms.user_id = v_uid
            OR (v_confirmed AND ms.user_id IS NULL AND lower(ms.email) = v_email)
    );

    -- Hız sınırı: 24 saatte en çok 20 değişiklik (hoş geldin e-postası
    -- ve kayıt şişmesine karşı).
    SELECT count(*) INTO v_changes
      FROM public.consents c
     WHERE c.user_id = v_uid AND c.kind = 'marketing_email'
       AND c.source = 'app_settings' AND c.recorded_at > now() - interval '24 hours';
    IF v_changes >= 20 THEN
        RETURN jsonb_build_object('success', false, 'code', 'rate_limited', 'subscribed', v_subscribed);
    END IF;

    IF p_enabled THEN
        IF NOT v_confirmed THEN
            RETURN jsonb_build_object('success', false, 'code', 'email_not_confirmed', 'subscribed', false);
        END IF;
        -- Aynı adresin hesaba bağlı olmayan (site / eski) satırı hesaba bağlanır;
        -- hesap silinince cascade ile gider.
        UPDATE public.marketing_subscribers ms
           SET user_id = v_uid
         WHERE ms.user_id IS NULL AND lower(ms.email) = v_email;
        IF FOUND THEN
            PERFORM ops.log_consent(v_uid, v_email, 'marketing_email', true, v_version, 'app_settings');
        ELSIF NOT EXISTS (SELECT 1 FROM public.marketing_subscribers ms WHERE ms.user_id = v_uid) THEN
            IF EXISTS (SELECT 1 FROM public.marketing_subscribers ms WHERE lower(ms.email) = v_email) THEN
                -- Aynı adres başka bir hesaba bağlı (e-posta değişikliği sonrası).
                RETURN jsonb_build_object('success', false, 'code', 'email_in_use', 'subscribed', false);
            END IF;
            PERFORM set_config('pomosprint.consent_source', 'app_settings', true);
            PERFORM set_config('pomosprint.consent_version', coalesce(v_version, ''), true);
            INSERT INTO public.marketing_subscribers (user_id, email, welcome_sent_at)
            VALUES (
                v_uid,
                v_email,
                -- Daha önce gerçekten abone olmuşsa hoş geldin e-postası tekrar gitmez.
                CASE WHEN EXISTS (
                    SELECT 1 FROM public.consents c
                     WHERE c.user_id = v_uid AND c.kind = 'marketing_email'
                       AND c.granted AND c.source <> 'signup'
                ) THEN now() END
            );
            PERFORM set_config('pomosprint.consent_source', '', true);
            PERFORM set_config('pomosprint.consent_version', '', true);
        END IF;
    ELSE
        PERFORM set_config('pomosprint.consent_source', 'app_settings', true);
        PERFORM set_config('pomosprint.consent_version', coalesce(v_version, ''), true);
        DELETE FROM public.marketing_subscribers ms
         WHERE ms.user_id = v_uid
            OR (v_confirmed AND ms.user_id IS NULL AND lower(ms.email) = v_email);
        GET DIAGNOSTICS v_deleted = ROW_COUNT;
        PERFORM set_config('pomosprint.consent_source', '', true);
        PERFORM set_config('pomosprint.consent_version', '', true);
        IF v_confirmed THEN
            DELETE FROM public.waitlist w WHERE lower(w.email) = v_email;
        END IF;
        IF v_deleted = 0 THEN
            -- Abonelik yoktu: ret beyanını (son kayıt zaten ret değilse) yaz.
            SELECT c.granted INTO v_prev
              FROM public.consents c
             WHERE c.user_id = v_uid AND c.kind = 'marketing_email'
             ORDER BY c.seq DESC
             LIMIT 1;
            IF v_prev IS DISTINCT FROM false THEN
                PERFORM ops.log_consent(v_uid, v_email, 'marketing_email', false, v_version, 'app_settings');
            END IF;
        END IF;
    END IF;

    UPDATE auth.users u
       SET raw_user_meta_data = coalesce(u.raw_user_meta_data, '{}'::jsonb)
                                || jsonb_build_object('newsletter', p_enabled, 'marketing_consent', p_enabled)
     WHERE u.id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'code', CASE WHEN p_enabled THEN 'subscribed' ELSE 'unsubscribed' END,
        'subscribed', p_enabled
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.set_marketing_consent(boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_marketing_consent(boolean, text) TO authenticated, service_role;

CREATE FUNCTION public.get_my_marketing_consent()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_email text;
    v_confirmed boolean;
    v_since timestamptz;
    v_found boolean := false;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    SELECT lower(btrim(u.email)), u.email_confirmed_at IS NOT NULL
      INTO v_email, v_confirmed
      FROM auth.users u
     WHERE u.id = v_uid;
    v_confirmed := coalesce(v_confirmed, false) AND coalesce(v_email, '') <> '';

    SELECT ms.subscribed_at, true INTO v_since, v_found
      FROM public.marketing_subscribers ms
     WHERE ms.user_id = v_uid
        OR (v_confirmed AND ms.user_id IS NULL AND lower(ms.email) = v_email)
     ORDER BY (ms.user_id IS NOT NULL) DESC
     LIMIT 1;

    RETURN jsonb_build_object(
        'subscribed', coalesce(v_found, false),
        'subscribed_at', v_since,
        'email_confirmed', v_confirmed
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.get_my_marketing_consent() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_marketing_consent() TO authenticated, service_role;

-- Google/Apple ile ilk girişte (kayıt formu yok) ya da yasal metin sürümü
-- değişince istemcinin gösterdiği metinlerin kabulünü kaydeder. Aynı sürüm
-- tekrar gönderilirse yeni kayıt yazılmaz.
CREATE FUNCTION public.accept_legal_documents(p_terms_version text, p_privacy_version text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_email text;
    v_terms text := left(nullif(btrim(p_terms_version), ''), 32);
    v_privacy text := left(nullif(btrim(p_privacy_version), ''), 32);
    v_recent integer;
    v_written integer := 0;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF v_terms IS NULL AND v_privacy IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_input');
    END IF;

    SELECT count(*) INTO v_recent
      FROM public.consents c
     WHERE c.user_id = v_uid AND c.source = 'app_legal_acceptance'
       AND c.recorded_at > now() - interval '24 hours';
    IF v_recent >= 20 THEN
        RETURN jsonb_build_object('success', false, 'code', 'rate_limited');
    END IF;

    SELECT u.email INTO v_email FROM auth.users u WHERE u.id = v_uid;

    IF v_terms IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM (
            SELECT c.document_version, c.granted FROM public.consents c
             WHERE c.user_id = v_uid AND c.kind = 'terms'
             ORDER BY c.seq DESC LIMIT 1
        ) last WHERE last.granted AND last.document_version = v_terms
    ) THEN
        PERFORM ops.log_consent(v_uid, v_email, 'terms', true, v_terms, 'app_legal_acceptance');
        v_written := v_written + 1;
    END IF;

    IF v_privacy IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM (
            SELECT c.document_version, c.granted FROM public.consents c
             WHERE c.user_id = v_uid AND c.kind = 'privacy_notice'
             ORDER BY c.seq DESC LIMIT 1
        ) last WHERE last.granted AND last.document_version = v_privacy
    ) THEN
        PERFORM ops.log_consent(v_uid, v_email, 'privacy_notice', true, v_privacy, 'app_legal_acceptance');
        v_written := v_written + 1;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'code', CASE WHEN v_written > 0 THEN 'recorded' ELSE 'unchanged' END,
        'terms_version', v_terms,
        'privacy_version', v_privacy
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.accept_legal_documents(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_legal_documents(text, text) TO authenticated, service_role;

-- Tek seferlik aktarım: mevcut abonelikler ve kayıt metadata'sındaki
-- onay sürümleri (kanıtın başlangıç noktası; recorded_at = bu migration).
INSERT INTO public.consents (user_id, email_hash, kind, granted, source, occurred_at, unlinked_at)
SELECT ms.user_id, ops.email_hash(ms.email), 'marketing_email', true, 'backfill', ms.subscribed_at,
       CASE WHEN ms.user_id IS NULL THEN now() END
  FROM public.marketing_subscribers ms;

INSERT INTO public.consents (user_id, email_hash, kind, granted, document_version, source, occurred_at)
SELECT u.id, ops.email_hash(u.email), k.kind, true,
       left(btrim(u.raw_user_meta_data->>k.meta_key), 32), 'backfill',
       ops.try_timestamptz(u.raw_user_meta_data->>'terms_accepted_at')
  FROM auth.users u
 CROSS JOIN (VALUES ('terms', 'terms_version'), ('privacy_notice', 'privacy_version')) AS k(kind, meta_key)
 WHERE nullif(btrim(u.raw_user_meta_data->>k.meta_key), '') IS NOT NULL;

-- ============================================================
-- C) ACC-06 + KVKK-01: yeni profil adı ve görünürlük varsayılanı
-- ============================================================
ALTER TABLE public.profiles ALTER COLUMN show_in_social_feed SET DEFAULT false;

-- proposed/13'ün gövdesi üzerine kurulur; 13'ten KORUNANLAR: friend_code
-- çakışmasında yeniden deneme (8 deneme), Crockford kod
-- (generate_friend_code, uzunluk app_config'ten), adın temizlenmesi
-- (clean_display_text) ve yasaklıysa sıradaki adaya düşülmesi
-- (display_text_is_allowed), e-posta kopyası yazılmaması (KVKK-20),
-- search_path'te pg_temp. 14'ün EKLEDİKLERİ: ad e-postadan türetilmez
-- (ACC-06; aday yoksa nötr ad), Google/Apple'da yalnızca ilk kelime,
-- görünürlük yalnızca açık seçimle (KVKK-01), kayıt onaylarının deftere
-- yazılması (KVKK-10).
CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_meta jsonb := coalesce(new.raw_user_meta_data, '{}'::jsonb);
  v_provider text := coalesce(nullif(new.raw_app_meta_data->>'provider', ''), 'email');
  v_local text := lower(split_part(btrim(coalesce(new.email, '')), '@', 1));
  v_candidates text[];
  v_candidate text;
  v_clean text;
  v_name text;
  v_code text;
  v_code_length integer;
  v_constraint text;
  v_terms text;
  v_privacy text;
  v_marketing boolean;
  v_occurred timestamptz;
begin
  -- Görünen ad (ACC-06): e-postadan TÜRETİLMEZ. E-posta kaydında formdaki
  -- ad (name, full_name); Google/Apple'da yalnızca ilk kelime (given_name,
  -- full_name, name). Her aday temizlenir ve 50 karaktere kısaltılır
  -- (proposed/13); boşsa, yasaklı bir ifade içeriyorsa ya da istemcinin
  -- boş ad yedeği olan e-posta yerel kısmıyla birebir aynıysa sıradaki
  -- adaya geçilir. Hiçbiri uygun değilse nötr ad ('Pomo 1234').
  if v_provider = 'email' then
    v_candidates := array[v_meta->>'name', v_meta->>'full_name'];
  else
    v_candidates := array[v_meta->>'given_name', v_meta->>'full_name', v_meta->>'name'];
  end if;
  foreach v_candidate in array v_candidates loop
    v_clean := public.clean_display_text(v_candidate);
    if v_provider <> 'email' then
      v_clean := (regexp_split_to_array(coalesce(v_clean, ''), '\s+'))[1];
    end if;
    v_clean := btrim(left(v_clean, 50));
    if v_clean <> '' and v_clean <> v_local and public.display_text_is_allowed(v_clean) then
      v_name := v_clean;
      exit;
    end if;
  end loop;
  v_name := coalesce(v_name, ops.neutral_display_name());

  v_code_length := coalesce(public.app_config_int('friend_code_length'), 6);

  for v_attempt in 1..8 loop
    -- Kod alt işlemin dışında üretilir; çakışmada yalnızca INSERT geri alınır.
    v_code := public.generate_friend_code(v_code_length);
    begin
      insert into public.profiles (id, name, avatar_id, total_minutes, lifetime_points, friend_code,
                                   show_in_social_feed)
      values (
        new.id,
        v_name,
        -- Yalnızca varsayılan (ücretsiz) avatarlar kayıtta seçilebilir;
        -- önceden 200 kumluk avatar_1_gamer bedava takılıyordu.
        coalesce(
          (select a.id from public.avatars a
            where a.id = v_meta->>'avatar_id' and a.is_default and a.is_active),
          'avatar_16_basic'),
        0,
        0,
        v_code,
        -- KVKK-01: herkese açık görünürlük yalnızca açık seçimle.
        coalesce(v_meta->>'show_in_social_feed', '') = 'true'
      )
      on conflict (id) do update set
        name = coalesce(excluded.name, public.profiles.name);
      exit;
    exception when unique_violation then
      get stacked diagnostics v_constraint = constraint_name;
      if v_constraint is distinct from 'profiles_friend_code_key' or v_attempt = 8 then
        raise;
      end if;
    end;
  end loop;

  -- KVKK-10: kayıt formundaki onaylar. Kayıt yazılamazsa kayıt BOZULMAZ.
  begin
    v_terms := left(nullif(btrim(v_meta->>'terms_version'), ''), 32);
    v_privacy := left(nullif(btrim(v_meta->>'privacy_version'), ''), 32);
    v_marketing := case
      when v_meta ? 'marketing_consent' then (v_meta->>'marketing_consent') = 'true'
      when v_meta ? 'newsletter' then (v_meta->>'newsletter') = 'true'
    end;
    v_occurred := ops.try_timestamptz(v_meta->>'terms_accepted_at');
    if v_terms is not null then
      perform ops.log_consent(new.id, new.email, 'terms', true, v_terms, 'signup', v_occurred);
    end if;
    if v_privacy is not null then
      perform ops.log_consent(new.id, new.email, 'privacy_notice', true, v_privacy, 'signup', v_occurred);
    end if;
    if v_marketing is not null then
      perform ops.log_consent(new.id, new.email, 'marketing_email', v_marketing,
                              coalesce(v_terms, v_privacy), 'signup', v_occurred);
    end if;
  exception when others then
    raise warning 'handle_new_user: onay kaydı yazılamadı: %', sqlerrm;
  end;

  return new;
end;
$function$;

-- İstemcinin yedek profil oluşturma yolu (normalde handle_new_user yazar):
-- e-postanın yerel kısmı ad olarak kabul edilmez. E-posta, isteğin JWT'sinden
-- okunur: proposed/13'ün discard_profile_email trigger'ı (adı alfabetik
-- olarak önce, yani önce çalışır) NEW.email'i zaten boşaltır ve KVKK-20'nin
-- 2. aşamasında kolon kalkar. Trigger SECURITY DEFINER değil; authenticated
-- auth.users'ı okuyamaz, JWT'deki 'email' talebini okuyabilir.
CREATE OR REPLACE FUNCTION public.sanitize_profile_insert()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_email text;
BEGIN
    IF current_user IN ('authenticated', 'anon') THEN
        IF NEW.avatar_id IS NULL OR NOT EXISTS (
            SELECT 1 FROM public.avatars a
            WHERE a.id = NEW.avatar_id AND a.is_default AND a.is_active
        ) THEN
            NEW.avatar_id := 'avatar_16_basic';
        END IF;
        v_email := btrim(coalesce(auth.jwt() ->> 'email', ''));
        IF NEW.name IS NOT NULL AND v_email <> ''
           AND btrim(NEW.name) = lower(split_part(v_email, '@', 1)) THEN
            NEW.name := 'Pomo ' || lpad((floor(random() * 10000))::integer::text, 4, '0');
        END IF;
    END IF;
    RETURN NEW;
END;
$function$;

-- İsteğe bağlı, ÜRÜN KARARIYLA (kullanıcıya görünür): adı e-postasının
-- yerel kısmıyla birebir aynı olan (canlı handle_new_user'ın ya da istemci
-- yedeğinin ürettiği) mevcut profillere nötr ad verir. Büyük harfle
-- yazılmış ad ('Ahmet' / ahmet@...) kullanıcının seçimi sayılır, dokunulmaz.
-- E-posta auth.users'tan okunur (proposed/13 sonrası profiles.email boş).
-- Önizleme: select count(*) from public.profiles p join auth.users u on u.id = p.id
--           where p.name in (left(split_part(btrim(u.email), '@', 1), 50),
--                            left(lower(split_part(btrim(u.email), '@', 1)), 50));
CREATE FUNCTION ops.neutralize_email_derived_names()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_count integer;
BEGIN
    UPDATE public.profiles p
       SET name = ops.neutral_display_name()
      FROM auth.users u
     WHERE u.id = p.id
       AND p.name IN (left(split_part(btrim(u.email), '@', 1), 50),
                      left(lower(split_part(btrim(u.email), '@', 1)), 50));
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$function$;

-- ============================================================
-- D) PLAY-04: engelleme, arkadaşlıktan çıkarma, istek yönetimi
-- ============================================================
CREATE TABLE public.user_blocks (
    blocker_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (blocker_id, blocked_id),
    CONSTRAINT user_blocks_not_self CHECK (blocker_id <> blocked_id)
);
CREATE INDEX user_blocks_blocked_idx ON public.user_blocks (blocked_id);
ALTER TABLE public.user_blocks ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_blocks FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.user_blocks IS
  'Kullanıcı engelleri. Yalnızca block_user / unblock_user / get_my_blocks RPC''leriyle erişilir.';

-- Reddedilen istekten sonra aynı kişiye 7 gün yeni istek gönderilemez.
CREATE TABLE public.friend_request_rejections (
    requester_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    target_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rejected_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (requester_id, target_id)
);
ALTER TABLE public.friend_request_rejections ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.friend_request_rejections FROM PUBLIC, anon, authenticated;

-- proposed/13'ün gövdesi üzerine kurulur; 13'ten KORUNANLAR: saatlik deneme
-- sınırı (friend_code_attempts, app_config), Crockford normalizasyonu
-- (normalize_friend_code), makine-okunur 'code', kabul edilmeden yanıtta
-- karşı tarafın id'si dönmemesi (KVKK-17). 14'ün EKLEDİKLERİ: engel (seni
-- engelleyen 'not_found' görür, engellediğin 'blocked'), iki yönlü
-- 'already_friends', ret sonrası 7 gün bekleme ('cooldown'), saatte 20
-- bekleyen istek ('rate_limited'). İstemci friends_sheet.dart bu kodları
-- tanıyor; tanımadığı kodda Türkçe arayüzde 'message' gösterir.
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
  v_recent integer;
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  -- proposed/13: deneme sayacı RAISE ile değil normal dönüşle biter; işlemle birlikte kalıcıdır.
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

  -- proposed/13: boşluk, tire, alt çizgi, nokta atılır; O→0, I/L→1.
  v_code := public.normalize_friend_code(p_code);

  select id, name, avatar_id, lifetime_points, total_minutes
    into v_target
    from public.profiles
   where v_code <> '' and friend_code = v_code;

  -- Hedef seni engellediyse "bulunamadı" ile aynı yanıt: engel bilgisi sızmaz.
  if v_target.id is null
     or exists (select 1 from public.user_blocks b
                 where b.blocker_id = v_target.id and b.blocked_id = v_uid) then
    return jsonb_build_object('success', false, 'code', 'not_found',
                              'message', 'Bu kod ile bir kullanıcı bulunamadı.');
  end if;

  if v_target.id = v_uid then
    return jsonb_build_object('success', false, 'code', 'self_add',
                              'message', 'Kendini arkadaş olarak ekleyemezsin.');
  end if;

  if exists (select 1 from public.user_blocks b
              where b.blocker_id = v_uid and b.blocked_id = v_target.id) then
    return jsonb_build_object('success', false, 'code', 'blocked',
                              'message', 'Bu kullanıcıyı engelledin. Arkadaş eklemek için önce engeli kaldır.');
  end if;

  if exists (select 1 from public.friendships f
              where f.status = 'accepted'
                and ((f.user_id = v_uid and f.friend_id = v_target.id)
                     or (f.user_id = v_target.id and f.friend_id = v_uid))) then
    return jsonb_build_object('success', false, 'code', 'already_friends',
                              'message', 'Bu kullanıcı zaten arkadaşın.');
  end if;

  if exists (select 1 from public.friendships f
              where f.user_id = v_uid and f.friend_id = v_target.id and f.status = 'pending') then
    return jsonb_build_object('success', false, 'code', 'already_pending',
                              'message', 'Bu kullanıcıya zaten istek gönderdin.');
  end if;

  select exists(
    select 1 from public.friendships f
     where f.user_id = v_target.id and f.friend_id = v_uid and f.status = 'pending'
  ) into v_reverse_pending;

  if v_reverse_pending then
    update public.friendships set status = 'accepted' where user_id = v_target.id and friend_id = v_uid;
    insert into public.friendships (user_id, friend_id, status) values (v_uid, v_target.id, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
    delete from public.friend_request_rejections r
     where (r.requester_id = v_uid and r.target_id = v_target.id)
        or (r.requester_id = v_target.id and r.target_id = v_uid);
    return jsonb_build_object(
      'success', true,
      'code', 'accepted',
      'auto_accepted', true,
      'friend', jsonb_build_object('id', v_target.id, 'name', v_target.name, 'avatar_id', v_target.avatar_id, 'lifetime_points', v_target.lifetime_points, 'total_minutes', v_target.total_minutes)
    );
  end if;

  if exists (select 1 from public.friend_request_rejections r
              where r.requester_id = v_uid and r.target_id = v_target.id
                and r.rejected_at > now() - interval '7 days') then
    return jsonb_build_object('success', false, 'code', 'cooldown',
                              'message', 'Bu kullanıcıya şu anda istek gönderemezsin. Daha sonra tekrar dene.');
  end if;

  select count(*) into v_recent
    from public.friendships f
   where f.user_id = v_uid and f.status = 'pending' and f.created_at > now() - interval '1 hour';
  if v_recent >= 20 then
    return jsonb_build_object('success', false, 'code', 'rate_limited',
                              'message', 'Çok fazla arkadaşlık isteği gönderdin. Biraz sonra tekrar dene.');
  end if;

  insert into public.friendships (user_id, friend_id, status) values (v_uid, v_target.id, 'pending')
    on conflict (user_id, friend_id) do update set status = 'pending';

  -- proposed/13: kabul edilmeden karşı tarafın kimliği dönmez (KVKK-17).
  return jsonb_build_object(
    'success', true,
    'code', 'request_sent',
    'auto_accepted', false,
    'friend', jsonb_build_object('name', v_target.name, 'avatar_id', v_target.avatar_id)
  );
end;
$function$;
REVOKE ALL ON FUNCTION public.add_friend_by_code(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.add_friend_by_code(text) TO authenticated, service_role;

-- Canlı gövde (proposed/13 yalnızca search_path'ine pg_temp eklemişti) +
-- engel kontrolü, makine-okunur 'code', ret kaydı (cooldown için).
CREATE OR REPLACE FUNCTION public.respond_friend_request(p_from_user_id uuid, p_accept boolean)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'not authenticated';
  end if;

  if not exists (
    select 1 from public.friendships
     where user_id = p_from_user_id and friend_id = v_uid and status = 'pending'
  ) or exists (
    select 1 from public.user_blocks b
     where (b.blocker_id = v_uid and b.blocked_id = p_from_user_id)
        or (b.blocker_id = p_from_user_id and b.blocked_id = v_uid)
  ) then
    return jsonb_build_object('success', false, 'code', 'not_found', 'message', 'Bekleyen bir istek bulunamadı.');
  end if;

  if p_accept then
    update public.friendships set status = 'accepted'
     where user_id = p_from_user_id and friend_id = v_uid;
    insert into public.friendships (user_id, friend_id, status) values (v_uid, p_from_user_id, 'accepted')
      on conflict (user_id, friend_id) do update set status = 'accepted';
    delete from public.friend_request_rejections r
     where (r.requester_id = p_from_user_id and r.target_id = v_uid)
        or (r.requester_id = v_uid and r.target_id = p_from_user_id);
    return jsonb_build_object('success', true, 'code', 'accepted');
  end if;

  delete from public.friendships where user_id = p_from_user_id and friend_id = v_uid;
  insert into public.friend_request_rejections (requester_id, target_id, rejected_at)
  values (p_from_user_id, v_uid, now())
  on conflict (requester_id, target_id) do update set rejected_at = excluded.rejected_at;
  return jsonb_build_object('success', true, 'code', 'rejected');
end;
$function$;
REVOKE ALL ON FUNCTION public.respond_friend_request(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.respond_friend_request(uuid, boolean) TO authenticated, service_role;

-- Okuma RPC'leri: canlı gövde + iki yönlü engel filtresi (engel arkadaşlığı
-- zaten siler; bu filtre savunma amaçlı).
CREATE OR REPLACE FUNCTION public.get_my_friends()
 RETURNS TABLE(id uuid, name text, avatar_id text, lifetime_points integer, total_minutes integer)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, p.lifetime_points, COALESCE(p.total_minutes, 0)
    FROM public.profiles p
    WHERE auth.uid() IS NOT NULL
      AND p.id <> auth.uid()
      AND p.id IN (
          SELECT CASE WHEN f.user_id = auth.uid() THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = auth.uid() OR f.friend_id = auth.uid())
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks b
          WHERE (b.blocker_id = auth.uid() AND b.blocked_id = p.id)
             OR (b.blocker_id = p.id AND b.blocked_id = auth.uid())
      )
    ORDER BY p.lifetime_points DESC, p.name;
$function$;

CREATE OR REPLACE FUNCTION public.get_incoming_friend_requests()
 RETURNS TABLE(id uuid, name text, avatar_id text, lifetime_points integer, total_minutes integer, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, p.lifetime_points, COALESCE(p.total_minutes, 0), f.created_at
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.user_id
    WHERE auth.uid() IS NOT NULL
      AND f.friend_id = auth.uid()
      AND f.status = 'pending'
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks b
          WHERE (b.blocker_id = auth.uid() AND b.blocked_id = p.id)
             OR (b.blocker_id = p.id AND b.blocked_id = auth.uid())
      )
    ORDER BY f.created_at DESC;
$function$;

CREATE OR REPLACE FUNCTION public.get_live_friends()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_result jsonb;
BEGIN
    IF v_uid IS NULL THEN
        RETURN '[]'::jsonb;
    END IF;

    -- Kabul edilen arkadaşlıklar iki yönlü satırla tutuluyor; önceki
    -- OR-join her arkadaşı iki kez döndürüyordu.
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', p.id,
            'name', p.name,
            'avatar_id', p.avatar_id,
            'category_name', p.active_session_category_name,
            'ends_at', p.active_session_ends_at
        ) ORDER BY p.active_session_ends_at
    ), '[]'::jsonb)
    INTO v_result
    FROM public.profiles p
    WHERE p.id <> v_uid
      AND p.id IN (
          SELECT CASE WHEN f.user_id = v_uid THEN f.friend_id ELSE f.user_id END
          FROM public.friendships f
          WHERE f.status = 'accepted' AND (f.user_id = v_uid OR f.friend_id = v_uid)
      )
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks b
          WHERE (b.blocker_id = v_uid AND b.blocked_id = p.id)
             OR (b.blocker_id = p.id AND b.blocked_id = v_uid)
      )
      AND p.show_in_social_feed = true
      AND p.active_session_ends_at > now();

    RETURN v_result;
END;
$function$;

-- Arkadaşlığı (ve aradaki bekleyen istekleri) iki yönde siler.
CREATE FUNCTION public.remove_friend(p_friend_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    DELETE FROM public.friendships f
     WHERE (f.user_id = v_uid AND f.friend_id = p_friend_id)
        OR (f.user_id = p_friend_id AND f.friend_id = v_uid);
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', v_count > 0,
        'code', CASE WHEN v_count > 0 THEN 'removed' ELSE 'not_friends' END
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.remove_friend(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.remove_friend(uuid) TO authenticated, service_role;

-- Gönderilen, henüz yanıtlanmamış isteği geri çeker.
CREATE FUNCTION public.cancel_friend_request(p_to_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    DELETE FROM public.friendships f
     WHERE f.user_id = v_uid AND f.friend_id = p_to_user_id AND f.status = 'pending';
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', v_count > 0,
        'code', CASE WHEN v_count > 0 THEN 'cancelled' ELSE 'not_found' END
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.cancel_friend_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_friend_request(uuid) TO authenticated, service_role;

CREATE FUNCTION public.get_outgoing_friend_requests()
 RETURNS TABLE(id uuid, name text, avatar_id text, created_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, f.created_at
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.friend_id
    WHERE auth.uid() IS NOT NULL
      AND f.user_id = auth.uid()
      AND f.status = 'pending'
      AND NOT EXISTS (
          SELECT 1 FROM public.user_blocks b
          WHERE (b.blocker_id = auth.uid() AND b.blocked_id = p.id)
             OR (b.blocker_id = p.id AND b.blocked_id = auth.uid())
      )
    ORDER BY f.created_at DESC;
$function$;
REVOKE ALL ON FUNCTION public.get_outgoing_friend_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_outgoing_friend_requests() TO authenticated, service_role;

-- Engel: arkadaşlığı ve bekleyen istekleri iki yönde siler; engellenen kişi
-- istek gönderemez (add_friend_by_code 'not_found' görür), engelleyenin
-- canlı akışında ve arkadaş listelerinde görünmez, sıralamalarda adı ve
-- avatarı gizlenir. Engellenene bildirim gitmez.
CREATE FUNCTION public.block_user(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
    v_removed integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF p_user_id IS NULL OR NOT EXISTS (SELECT 1 FROM public.profiles p WHERE p.id = p_user_id) THEN
        RETURN jsonb_build_object('success', false, 'code', 'not_found');
    END IF;
    IF p_user_id = v_uid THEN
        RETURN jsonb_build_object('success', false, 'code', 'self');
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.user_blocks b WHERE b.blocker_id = v_uid AND b.blocked_id = p_user_id) THEN
        SELECT count(*) INTO v_count FROM public.user_blocks b WHERE b.blocker_id = v_uid;
        IF v_count >= 1000 THEN
            RETURN jsonb_build_object('success', false, 'code', 'limit_reached');
        END IF;
        INSERT INTO public.user_blocks (blocker_id, blocked_id) VALUES (v_uid, p_user_id)
        ON CONFLICT DO NOTHING;
    END IF;

    DELETE FROM public.friendships f
     WHERE (f.user_id = v_uid AND f.friend_id = p_user_id)
        OR (f.user_id = p_user_id AND f.friend_id = v_uid);
    GET DIAGNOSTICS v_removed = ROW_COUNT;

    RETURN jsonb_build_object('success', true, 'code', 'blocked', 'removed_friendship', v_removed > 0);
END;
$function$;
REVOKE ALL ON FUNCTION public.block_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated, service_role;

-- Engeli kaldırır; arkadaşlık geri gelmez.
CREATE FUNCTION public.unblock_user(p_user_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_count integer;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    DELETE FROM public.user_blocks b WHERE b.blocker_id = v_uid AND b.blocked_id = p_user_id;
    GET DIAGNOSTICS v_count = ROW_COUNT;

    RETURN jsonb_build_object(
        'success', v_count > 0,
        'code', CASE WHEN v_count > 0 THEN 'unblocked' ELSE 'not_blocked' END
    );
END;
$function$;
REVOKE ALL ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated, service_role;

CREATE FUNCTION public.get_my_blocks()
 RETURNS TABLE(id uuid, name text, avatar_id text, blocked_at timestamp with time zone)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT p.id, p.name, p.avatar_id, b.created_at
    FROM public.user_blocks b
    JOIN public.profiles p ON p.id = b.blocked_id
    WHERE auth.uid() IS NOT NULL
      AND b.blocker_id = auth.uid()
    ORDER BY b.created_at DESC;
$function$;
REVOKE ALL ON FUNCTION public.get_my_blocks() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_blocks() TO authenticated, service_role;

-- ============================================================
-- E) Sıralamalar: engel (PLAY-04), maskeleme (ACC-06), anon sınırı (KVKK-03)
-- ============================================================
-- Tek kelimelik ad oturumsuz listede de kısaltılır: 'Ahmet' -> 'Ahm…',
-- 'Ali' -> 'Al…'. Çok kelimeli ad canlıdaki gibi: 'Ahmet Yılmaz' -> 'Ahmet Y.'.
CREATE OR REPLACE FUNCTION public.mask_public_name(p_name text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT CASE
        WHEN p_name IS NULL OR btrim(p_name) = '' THEN NULL
        WHEN array_length(regexp_split_to_array(btrim(p_name), '\s+'), 1) = 1 THEN
            left(btrim(p_name), GREATEST(1, LEAST(3, char_length(btrim(p_name)) - 1))) || '…'
        ELSE (regexp_split_to_array(btrim(p_name), '\s+'))[1] || ' '
             || upper(left((regexp_split_to_array(btrim(p_name), '\s+'))[2], 1)) || '.'
    END;
$function$;

-- Lig: dönüşe id ve is_blocked eklenir (dönüş tipi değiştiği için DROP).
-- Engellenenin satırı silinmez (sıra/bölge bozulmasın); ad ve avatar NULL.
DROP FUNCTION public.get_my_league_ranking();
DROP FUNCTION public.get_league_ranking(uuid);

CREATE FUNCTION public.get_league_ranking(p_user_id uuid)
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer, id uuid, is_blocked boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_league_id UUID;
    v_tier INTEGER;
    v_end_date TIMESTAMPTZ;
    v_member_count INTEGER;
    v_promo_end INTEGER;
    v_demo_start INTEGER;
BEGIN
    -- Yalnızca kendi ligini görebilirsin (önceden herhangi bir kullanıcı id'si
    -- ile, oturumsuz bile çağrılabiliyordu).
    IF p_user_id IS NULL OR p_user_id IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION 'not authorized';
    END IF;

    SELECT l.id, l.tier, l.end_date
    INTO v_league_id, v_tier, v_end_date
    FROM public.league_memberships lm
    JOIN public.leagues l ON l.id = lm.league_id
    WHERE lm.user_id = p_user_id AND l.is_active = true
    LIMIT 1;

    IF v_league_id IS NULL THEN
        SELECT pr.league_tier INTO v_tier FROM public.profiles pr WHERE pr.id = p_user_id;
        -- ensure_user_in_league ile aynı 14 günlük dönem sonu
        v_end_date := ((date_trunc('week', (current_timestamp AT TIME ZONE 'Europe/Istanbul')::date::timestamp) + interval '13 days') + time '23:59:59') AT TIME ZONE 'Europe/Istanbul';
        RETURN QUERY
        SELECT
            p.name, p.avatar_id, 0, v_tier, v_end_date, true, 1, 999, 1, p.id, false
        FROM public.profiles p WHERE p.id = p_user_id;
        RETURN;
    END IF;

    SELECT count(*) INTO v_member_count FROM public.league_memberships lm2 WHERE lm2.league_id = v_league_id;

    SELECT z.promotion_zone_end, z.demotion_zone_start
    INTO v_promo_end, v_demo_start
    FROM public.get_league_zones(v_member_count) z;

    -- İlk 3'teki (ve puanı olan) üyeler bu ekranda lig ödülü avatarıyla
    -- görünür; profiles.avatar_id'ye dokunulmaz. Sıralama, dönem sonu
    -- işlemiyle (process_weekly_leagues) birebir aynı kuraldır.
    RETURN QUERY
    SELECT
        CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.name END,
        CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE
            COALESCE(
                CASE WHEN ranked.weekly_points > 0
                     THEN public.league_award_avatar_id(v_tier, ranked.rnk::integer) END,
                p.avatar_id)
        END,
        ranked.weekly_points,
        v_tier,
        v_end_date,
        (ranked.user_id = p_user_id),
        v_promo_end,
        v_demo_start,
        v_member_count,
        ranked.user_id,
        (b.blocked_id IS NOT NULL)
    FROM (
        SELECT lm.user_id, lm.weekly_points, lm.joined_at,
               row_number() OVER (ORDER BY lm.weekly_points DESC, lm.joined_at ASC, lm.user_id) AS rnk
        FROM public.league_memberships lm
        WHERE lm.league_id = v_league_id
    ) ranked
    JOIN public.profiles p ON p.id = ranked.user_id
    LEFT JOIN public.user_blocks b ON b.blocker_id = p_user_id AND b.blocked_id = ranked.user_id
    ORDER BY ranked.rnk ASC;
END;
$function$;
REVOKE ALL ON FUNCTION public.get_league_ranking(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_league_ranking(uuid) TO authenticated, service_role;

CREATE FUNCTION public.get_my_league_ranking()
 RETURNS TABLE(name text, avatar_id text, weekly_points integer, tier integer, end_date timestamp with time zone, is_me boolean, promotion_zone_end integer, demotion_zone_start integer, member_count integer, id uuid, is_blocked boolean)
 LANGUAGE sql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT r.name, r.avatar_id, r.weekly_points, r.tier, r.end_date,
           r.is_me, r.promotion_zone_end, r.demotion_zone_start, r.member_count,
           r.id, r.is_blocked
    FROM public.get_league_ranking(auth.uid()) AS r
    WHERE auth.uid() IS NOT NULL;
$function$;
REVOKE ALL ON FUNCTION public.get_my_league_ranking() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_league_ranking() TO authenticated, service_role;

-- Aylık: oturumsuz çağrı en çok 10 satır (politikadaki 'ilk 10') ve id
-- döndürmez; oturum açıkken engellenenin adı/avatarı gizlenir. Ay kuralı
-- mevcut gövdeden korunur: canlıdaki (completed_at, İstanbul ayı) ya da
-- proposed/15 uygulanmışsa çalışma ayı (started_at, profil dilimi, 04:00).
-- Gövdenin geri kalanı iki durumda da aynı.
DO $monthly$
DECLARE
    v_month text;
BEGIN
    IF md5(pg_get_functiondef('public.get_public_monthly_leaderboard(integer)'::regprocedure))
       = '3865c94b1bdb69161d576354ffcff6c2' THEN
        v_month := $w$ss.started_at IS NOT NULL
      AND ss.started_at >= (
            (date_trunc('month', (now() AT TIME ZONE p.timezone) - interval '4 hours') + interval '4 hours')
            AT TIME ZONE p.timezone
          )$w$;
    ELSE
        v_month := $w$ss.completed_at >= (date_trunc('month', now() AT TIME ZONE 'Europe/Istanbul') AT TIME ZONE 'Europe/Istanbul')$w$;
    END IF;

    DROP FUNCTION public.get_public_monthly_leaderboard(integer);

    EXECUTE format($f$
CREATE FUNCTION public.get_public_monthly_leaderboard(p_limit integer DEFAULT 10)
 RETURNS TABLE(name text, avatar_id text, total_points integer, total_minutes integer, is_me boolean, id uuid, is_blocked boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT
        CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name)
             WHEN b.blocked_id IS NOT NULL THEN NULL
             ELSE p.name END,
        CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.avatar_id END,
        SUM(ss.base_points + ss.bonus_points)::integer AS total_points,
        SUM(ss.duration_minutes)::integer AS total_minutes,
        COALESCE(p.id = auth.uid(), false) AS is_me,
        CASE WHEN auth.uid() IS NULL THEN NULL ELSE p.id END AS id,
        (b.blocked_id IS NOT NULL) AS is_blocked
    FROM public.study_sessions ss
    JOIN public.profiles p ON p.id = ss.user_id
    LEFT JOIN public.user_blocks b ON b.blocker_id = auth.uid() AND b.blocked_id = p.id
    WHERE %s
      AND p.show_in_social_feed = true
    GROUP BY p.id, p.name, p.avatar_id, b.blocked_id
    ORDER BY 3 DESC, 4 DESC, p.id
    LIMIT CASE WHEN auth.uid() IS NULL THEN LEAST(GREATEST(COALESCE(p_limit, 10), 0), 10)
               ELSE LEAST(GREATEST(COALESCE(p_limit, 10), 0), 100) END;
$function$
$f$, v_month);
END
$monthly$;
-- Site oturumsuz çağırıyor: anon yetkisi bilinçli.
REVOKE ALL ON FUNCTION public.get_public_monthly_leaderboard(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_monthly_leaderboard(integer) TO anon, authenticated, service_role;

-- Tüm zamanlar: kullanılmıyor. anon'a kapanır, is_premium çıkar.
DROP FUNCTION public.get_public_alltime_leaderboard(integer);

CREATE FUNCTION public.get_public_alltime_leaderboard(p_limit integer DEFAULT 50)
 RETURNS TABLE(name text, avatar_id text, total_minutes integer, lifetime_points integer, is_me boolean)
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT
        CASE WHEN auth.uid() IS NULL THEN public.mask_public_name(p.name)
             WHEN b.blocked_id IS NOT NULL THEN NULL
             ELSE p.name END,
        CASE WHEN b.blocked_id IS NOT NULL THEN NULL ELSE p.avatar_id END,
        COALESCE(p.total_minutes, 0),
        p.lifetime_points,
        COALESCE(p.id = auth.uid(), false) AS is_me
    FROM public.profiles p
    LEFT JOIN public.user_blocks b ON b.blocker_id = auth.uid() AND b.blocked_id = p.id
    WHERE p.show_in_social_feed = true
    ORDER BY p.lifetime_points DESC, COALESCE(p.total_minutes, 0) DESC, p.id
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 0), 100);
$function$;
REVOKE ALL ON FUNCTION public.get_public_alltime_leaderboard(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_public_alltime_leaderboard(integer) TO authenticated, service_role;

-- ============================================================
-- F) PLAY-05: kullanıcı bildirimleri ve operatör araçları
-- ============================================================
CREATE TABLE public.user_reports (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    target_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
    place text NOT NULL CHECK (place IN ('league', 'monthly', 'friends_ranking', 'live_feed',
                                         'friends_list', 'friend_request', 'other')),
    reason text NOT NULL CHECK (reason IN ('offensive_name', 'offensive_content', 'harassment',
                                           'spam', 'impersonation', 'other')),
    details text CHECK (details IS NULL OR char_length(details) <= 500),
    target_name_snapshot text,      -- bildirim anındaki görünen ad
    target_content_snapshot text,   -- canlı akışta görünen ders adı (yalnızca live_feed)
    status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'actioned', 'dismissed')),
    handled_at timestamptz,
    handler_note text CHECK (handler_note IS NULL OR char_length(handler_note) <= 500),
    created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX user_reports_open_idx ON public.user_reports (created_at) WHERE status = 'open';
CREATE INDEX user_reports_reporter_idx ON public.user_reports (reporter_id, created_at DESC);
CREATE INDEX user_reports_target_idx ON public.user_reports (target_user_id, created_at DESC);
ALTER TABLE public.user_reports ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_reports FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.user_reports IS
  'Uygulama içi kullanıcı bildirimleri. İstemci yalnızca submit_user_report ile yazar; operatör ops.open_user_reports ile okur.';

-- Hız sınırı: 24 saatte 10 bildirim; aynı kişiye 24 saat içinde açık
-- bildirim varsa yenisi yazılmaz, mevcut kayıt döner (duplicate=true).
CREATE FUNCTION public.submit_user_report(
    p_target_user_id uuid,
    p_place text,
    p_reason text,
    p_details text DEFAULT NULL
)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_place text := lower(btrim(coalesce(p_place, '')));
    v_reason text := lower(btrim(coalesce(p_reason, '')));
    v_details text := nullif(left(btrim(coalesce(p_details, '')), 500), '');
    v_existing uuid;
    v_recent integer;
    v_name text;
    v_content text;
    v_id uuid;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;
    IF v_place NOT IN ('league', 'monthly', 'friends_ranking', 'live_feed', 'friends_list', 'friend_request', 'other') THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_place');
    END IF;
    IF v_reason NOT IN ('offensive_name', 'offensive_content', 'harassment', 'spam', 'impersonation', 'other') THEN
        RETURN jsonb_build_object('success', false, 'code', 'invalid_reason');
    END IF;
    IF p_target_user_id IS NULL THEN
        RETURN jsonb_build_object('success', false, 'code', 'not_found');
    END IF;
    IF p_target_user_id = v_uid THEN
        RETURN jsonb_build_object('success', false, 'code', 'self');
    END IF;

    SELECT p.name, p.active_session_category_name INTO v_name, v_content
      FROM public.profiles p WHERE p.id = p_target_user_id;
    IF NOT FOUND THEN
        RETURN jsonb_build_object('success', false, 'code', 'not_found');
    END IF;

    SELECT r.id INTO v_existing
      FROM public.user_reports r
     WHERE r.reporter_id = v_uid AND r.target_user_id = p_target_user_id
       AND r.status = 'open' AND r.created_at > now() - interval '24 hours'
     ORDER BY r.created_at DESC
     LIMIT 1;
    IF v_existing IS NOT NULL THEN
        RETURN jsonb_build_object('success', true, 'code', 'duplicate', 'duplicate', true, 'report_id', v_existing);
    END IF;

    SELECT count(*) INTO v_recent
      FROM public.user_reports r
     WHERE r.reporter_id = v_uid AND r.created_at > now() - interval '24 hours';
    IF v_recent >= 10 THEN
        RETURN jsonb_build_object('success', false, 'code', 'rate_limited');
    END IF;

    INSERT INTO public.user_reports (reporter_id, target_user_id, place, reason, details,
                                     target_name_snapshot, target_content_snapshot)
    VALUES (v_uid, p_target_user_id, v_place, v_reason, v_details,
            v_name, CASE WHEN v_place = 'live_feed' THEN v_content END)
    RETURNING id INTO v_id;

    RETURN jsonb_build_object('success', true, 'code', 'reported', 'duplicate', false, 'report_id', v_id);
END;
$function$;
REVOKE ALL ON FUNCTION public.submit_user_report(uuid, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_user_report(uuid, text, text, text) TO authenticated, service_role;

-- Operatör (SQL Editor):
--   select * from ops.open_user_reports;                       -- açık bildirimler, en eski önce
--   select ops.reset_display_name('<hedef uuid>');             -- uygunsuz adı nötr adla değiştir
--   select ops.resolve_user_report('<bildirim uuid>', 'actioned', 'ad sıfırlandı');
--   select ops.resolve_user_report('<bildirim uuid>', 'dismissed', 'ihlal yok');
-- Hesabı askıya alma: Dashboard > Authentication > Users > kullanıcı > Ban.
CREATE VIEW ops.open_user_reports AS
SELECT r.id,
       r.created_at,
       r.place,
       r.reason,
       r.details,
       r.target_user_id,
       r.target_name_snapshot,
       tp.name AS target_current_name,
       r.target_content_snapshot,
       (SELECT count(*) FROM public.user_reports r2
         WHERE r2.target_user_id = r.target_user_id
           AND r2.created_at > now() - interval '30 days') AS target_reports_30d,
       (SELECT count(DISTINCT r3.reporter_id) FROM public.user_reports r3
         WHERE r3.target_user_id = r.target_user_id
           AND r3.created_at > now() - interval '30 days') AS target_distinct_reporters_30d,
       r.reporter_id
  FROM public.user_reports r
  LEFT JOIN public.profiles tp ON tp.id = r.target_user_id
 WHERE r.status = 'open'
 ORDER BY r.created_at;
REVOKE ALL ON ops.open_user_reports FROM PUBLIC;

CREATE FUNCTION ops.resolve_user_report(p_report_id uuid, p_status text, p_note text DEFAULT NULL)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF p_status NOT IN ('actioned', 'dismissed') THEN
        RAISE EXCEPTION 'status must be actioned or dismissed' USING ERRCODE = '22023';
    END IF;
    UPDATE public.user_reports
       SET status = p_status,
           handled_at = now(),
           handler_note = left(nullif(btrim(p_note), ''), 500)
     WHERE id = p_report_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'report not found' USING ERRCODE = 'P0002';
    END IF;
END;
$function$;

CREATE FUNCTION ops.reset_display_name(p_user_id uuid)
 RETURNS text
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_name text;
BEGIN
    UPDATE public.profiles
       SET name = ops.neutral_display_name()
     WHERE id = p_user_id
    RETURNING name INTO v_name;
    IF v_name IS NULL THEN
        RAISE EXCEPTION 'profile not found' USING ERRCODE = 'P0002';
    END IF;
    RETURN v_name;
END;
$function$;

-- ============================================================
-- G) KVKK-06: activity_feed
-- ============================================================
-- Arayüzü olmayan akış kayıtları üretilmez. Özellik gelince bu fonksiyonu
-- 'SELECT true' döndürecek şekilde değiştirin.
CREATE FUNCTION ops.activity_feed_enabled()
 RETURNS boolean
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT false;
$function$;

-- Her yazım (complete_study_session özetleri, process_weekly_leagues
-- league_promotion dahil) buradan geçer: özellik kapalıysa ya da kullanıcı
-- sosyal görünürlüğü kapattıysa kayıt yazılmaz.
CREATE FUNCTION public.activity_feed_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    IF NOT ops.activity_feed_enabled() THEN
        RETURN NULL;
    END IF;
    IF NOT COALESCE((SELECT p.show_in_social_feed FROM public.profiles p WHERE p.id = NEW.user_id), false) THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$function$;
REVOKE ALL ON FUNCTION public.activity_feed_guard() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.activity_feed_guard() TO service_role;

CREATE TRIGGER activity_feed_guard
    BEFORE INSERT OR UPDATE ON public.activity_feed
    FOR EACH ROW EXECUTE FUNCTION public.activity_feed_guard();

-- Görünürlük kapatılınca kullanıcının akış kayıtları silinir.
CREATE FUNCTION public.activity_feed_on_visibility_off()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
BEGIN
    DELETE FROM public.activity_feed a WHERE a.user_id = NEW.id;
    RETURN NULL;
END;
$function$;
REVOKE ALL ON FUNCTION public.activity_feed_on_visibility_off() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.activity_feed_on_visibility_off() TO service_role;

CREATE TRIGGER activity_feed_on_visibility_off
    AFTER UPDATE OF show_in_social_feed ON public.profiles
    FOR EACH ROW
    WHEN (OLD.show_in_social_feed AND NOT NEW.show_in_social_feed)
    EXECUTE FUNCTION public.activity_feed_on_visibility_off();

-- Görünürlüğü şu an kapalı kullanıcıların eski kayıtları (kapatmadan önce
-- yazılmış özetler, görünürlüğe bakılmadan yazılan league_promotion).
DELETE FROM public.activity_feed a
 USING public.profiles p
 WHERE p.id = a.user_id AND NOT p.show_in_social_feed;

-- İstemci tabloyu okumuyor; arkadaş akışı (gelirse) get_friends_feed ile
-- okunur (o RPC zaten görünürlüğe bakıyor). Arkadaşların kayıtlarını REST
-- ile okuyabilen politika kalkar; yetki de geri alınır. Yetki bir gün
-- yeniden verilirse yalnızca kendi satırı okunur.
REVOKE SELECT ON public.activity_feed FROM authenticated;
DROP POLICY "Users can see their own and friends activity feed" ON public.activity_feed;
CREATE POLICY "Users can see their own activity feed"
    ON public.activity_feed FOR SELECT TO authenticated
    USING (user_id = (SELECT auth.uid()));

-- ============================================================
-- H) ACC-13: saklama süreleri (pg_cron)
-- ============================================================
-- E-postasını 7 günde onaylamayan kayıtlar (profil + onay kayıtları dahil).
-- Onaylı, giriş yapmış ya da seansı olan hesaba dokunulmaz. Önizleme:
--   select u.id, u.created_at from auth.users u
--    where u.id in (select ops.unconfirmed_signups_due());
CREATE FUNCTION ops.unconfirmed_signups_due(p_older_than interval DEFAULT interval '7 days')
 RETURNS SETOF uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'public', 'pg_temp'
AS $function$
    SELECT u.id
      FROM auth.users u
     WHERE u.email_confirmed_at IS NULL
       AND u.phone_confirmed_at IS NULL
       AND u.last_sign_in_at IS NULL
       AND u.invited_at IS NULL
       AND coalesce(u.is_anonymous, false) = false
       AND u.created_at < now() - p_older_than
       AND NOT EXISTS (SELECT 1 FROM public.study_sessions s WHERE s.user_id = u.id)
     ORDER BY u.created_at
     LIMIT 5000;
$function$;

-- p_only: yalnızca bu kimliklerle sınırla (operatörün tek tek silmesi ve
-- kuru çalıştırma için); kimlik yine yukarıdaki koşulları sağlamalı.
CREATE FUNCTION ops.purge_unconfirmed_signups(
    p_older_than interval DEFAULT interval '7 days',
    p_only uuid[] DEFAULT NULL
)
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_ids uuid[];
    v_count integer;
BEGIN
    SELECT coalesce(array_agg(d.id), '{}') INTO v_ids
      FROM ops.unconfirmed_signups_due(p_older_than) AS d(id)
     WHERE p_only IS NULL OR d.id = ANY (p_only);

    -- Hiç onaylanmamış adresin onay kayıtlarının ispat değeri yok.
    DELETE FROM public.consents c WHERE c.user_id = ANY (v_ids);
    DELETE FROM auth.users u WHERE u.id = ANY (v_ids);
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$function$;

-- Bekleme listesi yalnızca lansman duyurusu için tutulur. Varsayılan üst
-- sınır 12 ay; lansman e-postası gönderildikten sonra daha kısa bir süreyle
-- elle çalıştırın: select ops.purge_expired_waitlist(interval '30 days');
CREATE FUNCTION ops.purge_expired_waitlist(p_older_than interval DEFAULT interval '12 months')
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_count integer;
BEGIN
    DELETE FROM public.waitlist w WHERE w.created_at < now() - p_older_than;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$function$;

-- Hesaptan ayrılmış (hesap silinmiş ya da hiç hesaba bağlı olmamış) onay
-- kayıtları. Süre hukukçuyla doğrulanmalı (ETK onay ispatı).
CREATE FUNCTION ops.purge_old_consents(p_after interval DEFAULT interval '1 year')
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_count integer;
BEGIN
    DELETE FROM public.consents c
     WHERE c.user_id IS NULL
       AND coalesce(c.unlinked_at, c.recorded_at) < now() - p_after;
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$function$;

-- Sonuçlanan bildirimler 1 yıl, hedefi silinmiş bildirimler 90 gün.
CREATE FUNCTION ops.purge_old_user_reports()
 RETURNS integer
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_count integer;
BEGIN
    DELETE FROM public.user_reports r
     WHERE (r.status <> 'open' AND r.handled_at < now() - interval '1 year')
        OR (r.target_user_id IS NULL AND r.created_at < now() - interval '90 days');
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$function$;

CREATE FUNCTION ops.run_privacy_retention()
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_rejections integer;
BEGIN
    DELETE FROM public.friend_request_rejections r WHERE r.rejected_at < now() - interval '30 days';
    GET DIAGNOSTICS v_rejections = ROW_COUNT;
    RETURN jsonb_build_object(
        'unconfirmed_signups', ops.purge_unconfirmed_signups(),
        'waitlist', ops.purge_expired_waitlist(),
        'consents', ops.purge_old_consents(),
        'user_reports', ops.purge_old_user_reports(),
        'friend_request_rejections', v_rejections
    );
END;
$function$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA ops FROM PUBLIC;

-- 03:17 UTC (06:17 TR); cleanup_activity_feed_job (03:00) ile çakışmaz.
-- Aynı adla yeniden çalıştırılırsa pg_cron işi günceller.
SELECT cron.schedule('privacy_retention_daily', '17 3 * * *', 'SELECT ops.run_privacy_retention()');

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261003194000', 'privacy_social')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

COMMIT;
