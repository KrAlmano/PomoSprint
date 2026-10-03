-- ============================================================
-- ÖNERİ 10: Tek seferlik veri düzeltmeleri              ÖNCELİK: P3
-- ============================================================
-- Bulgular: SOCIAL-15 / AUTH-21 / DATA-25 (Google/Apple ile kaydolan
-- kullanıcılar sahip olmadıkları 200 coin'lik avatarla başladı),
-- SOCIAL-27 (tomato_basic görseli yok), LANDING-08 / BACKEND-23
-- (abone e-postaları büyük/küçük harf karışık olabilir).
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit). Her bölümü önce SAYIM sorgusuyla kontrol edin,
-- sonra düzeltmeyi çalıştırın. Bunlar kullanıcıya görünen değişikliklerdir
-- (ör. avatarı değişen kullanıcılar); ürün kararıyla uygulayın.
-- ============================================================

\echo 'supabase/proposed/10: doğrudan çalıştırılmaz, dosya başındaki açıklamaya bakın.'
\quit

-- ------------------------------------------------------------
-- 1) Sahip olunmayan ücretli/premium/lig ödülü avatar (SOCIAL-15)
-- ------------------------------------------------------------
-- NOT: 20261003150000_live_audit_fixes bu kullanıcılara takılı avatarın
-- kilidini AÇARAK çözüyor (avatar_unlocks INSERT). O migration
-- uygulanırsa aşağıdaki sayım boş döner ve bu bölüm gereksizdir. İkisinden
-- yalnızca biri seçilmeli: kilidi açmak (kullanıcı avatarını korur) ya da
-- varsayılana çekmek (aşağıdaki UPDATE).
-- Sayım:
SELECT p.avatar_id, count(*)
FROM public.profiles p
LEFT JOIN public.avatars a ON a.id = p.avatar_id
WHERE (a.id IS NULL OR NOT a.is_default)
  AND NOT EXISTS (
      SELECT 1 FROM public.avatar_unlocks u
      WHERE u.user_id = p.id AND u.avatar_id = p.avatar_id
  )
GROUP BY p.avatar_id
ORDER BY 2 DESC;

-- Düzeltme (varsayılan avatar 20261003120000'deki trigger ile aynı):
BEGIN;
UPDATE public.profiles p
SET avatar_id = 'avatar_16_basic',
    equipped_avatar_id = 'avatar_16_basic'
FROM (
    SELECT p2.id
    FROM public.profiles p2
    LEFT JOIN public.avatars a ON a.id = p2.avatar_id
    WHERE (a.id IS NULL OR NOT a.is_default)
      AND NOT EXISTS (
          SELECT 1 FROM public.avatar_unlocks u
          WHERE u.user_id = p2.id AND u.avatar_id = p2.avatar_id
      )
) bad
WHERE p.id = bad.id;
COMMIT;

-- equipped_avatar_id ile avatar_id ayrışmışsa (give_default_avatars'ın
-- etkisiz ataması nedeniyle equipped NULL kalmış olabilir):
UPDATE public.profiles
SET equipped_avatar_id = avatar_id
WHERE equipped_avatar_id IS DISTINCT FROM avatar_id
  AND avatar_id IN (SELECT id FROM public.avatars);

-- ------------------------------------------------------------
-- 2) Görseli olmayan avatar (SOCIAL-27)
-- ------------------------------------------------------------
-- Önce kontrol: select id, asset_key, is_active from public.avatars where id = 'tomato_basic';
-- assets/avatars/tomato_basic.png uygulamada yoksa katalogdan gizleyin:
UPDATE public.avatars SET is_active = false WHERE id = 'tomato_basic';

-- ------------------------------------------------------------
-- 3) Abone e-postalarını küçük harfe indir (BACKEND-23, LANDING-08)
-- ------------------------------------------------------------
-- unsubscribe fonksiyonu tam eşleşme kullanır (küçük harf + linkteki özgün
-- yazım). Kayıtlar küçük harfe indirilirse eşleşme garanti olur.
-- Sayım (aynı adresin farklı yazımları):
SELECT lower(btrim(email)) AS email, count(*)
FROM public.marketing_subscribers
GROUP BY 1 HAVING count(*) > 1;

-- Düzeltme: tablonun birincil anahtarına göre yinelenenleri silip
-- (ctid ile, en eski kalır) kalanları normalize edin. Tablo şeması repoda
-- yok; çalıştırmadan önce \d public.marketing_subscribers ile kontrol edin.
BEGIN;
DELETE FROM public.marketing_subscribers m
USING (
    SELECT ctid,
           row_number() OVER (PARTITION BY lower(btrim(email)) ORDER BY ctid) AS rn
    FROM public.marketing_subscribers
) d
WHERE m.ctid = d.ctid AND d.rn > 1;
UPDATE public.marketing_subscribers SET email = lower(btrim(email)) WHERE email <> lower(btrim(email));
CREATE UNIQUE INDEX IF NOT EXISTS marketing_subscribers_email_lower_key
    ON public.marketing_subscribers (lower(email));
COMMIT;
-- waitlist için aynısı (landing formu zaten küçük harf yazıyor).
