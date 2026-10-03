-- ============================================================
-- UYARI: CANLIYA UYGULAMADAN ÖNCE OKUYUN
-- ------------------------------------------------------------
-- Bu dosya bir GERİ ALMA (rollback) betiğidir, migration DEĞİLDİR.
-- supabase/migrations/ dışında tutulur; aksi halde `supabase db push`
-- onu aynı sürüm numaralı ileri migration sanıp _up dosyasından ÖNCE
-- uygular. Uygulamadan önce `supabase db dump` ile yedek alın, dosyayı
-- satır satır okuyun ve önce staging/branch üzerinde deneyin.
--
-- Bu dosyaya özel riskler:
--   * Seans doğrulama trigger'ı (validate_study_session_timing) ve
--     kategori limiti trigger'ı kaldırılır: anında puan hilesi ve
--     kategori limiti aşımı yeniden mümkün olur.
--   * 20261003150000_live_audit_fixes uygulanmışsa oradaki
--     'enforce_category_limit_on_unarchive' trigger'ı
--     enforce_category_limit() fonksiyonunu kullanır; bu dosya o
--     fonksiyonu sildiğinde DROP FUNCTION bağımlılık hatası verir (ve
--     transaction geri alınır). Önce o trigger'ı kaldırın.
--
-- Bilinçli olarak GERİ ALINMAYANLAR (güvenlik açığı yeniden açılmasın):
--   * get_league_ranking istemcilere yeniden AÇILMAZ (lig üyelerinin
--     e-postalarını döndürüyor).
--   * get_my_league_ranking SİLİNMEZ (istemci lig ekranında kullanıyor).
--   * study_sessions INSERT/UPDATE/DELETE ve ensure_user_in_league /
--     process_weekly_leagues EXECUTE yetkileri geri VERİLMEZ.
--   * profiles için anon yetkileri ve kolon kısıtsız UPDATE geri VERİLMEZ.
--   * search_path atamaları geri alınmaz (zararsız ve güvenli).
-- ============================================================

BEGIN;

DROP TRIGGER IF EXISTS study_sessions_validate_timing ON public.study_sessions;
DROP FUNCTION IF EXISTS public.validate_study_session_timing();
DROP INDEX IF EXISTS public.study_sessions_user_started_at_idx;

DROP TRIGGER IF EXISTS categories_enforce_limit ON public.categories;
DROP FUNCTION IF EXISTS public.enforce_category_limit();

COMMIT;
