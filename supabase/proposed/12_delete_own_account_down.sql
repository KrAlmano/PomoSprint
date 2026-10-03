-- ============================================================
-- GERİ ALMA: ÖNERİ 12 (delete_own_account)
-- ============================================================
-- 3 Ekim 2026 canlı gövdesine döner (pg_get_functiondef ile okundu).
-- Geri alma zincirinin SON adımı (14_down → 13_down → 19_down → 16_down →
-- 15_down → 12_down). 13 hâlâ uygulanmışken çalıştırılırsa fonksiyon
-- 13'ün eklediği pg_temp'i de kaybeder; önce 13_down.
-- Veri geri gelmez: öneri uygulandığı sürede silinen hesapların bekleme
-- listesi / abonelik kayıtları kalıcı olarak silinmiştir.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ (\quit). Gerekirse
-- \echo/\quit satırları olmadan SQL Editor'de çalıştırın.
-- ============================================================

\echo 'supabase/proposed/12_down: doğrudan çalıştırılmaz.'
\quit

BEGIN;

CREATE OR REPLACE FUNCTION public.delete_own_account()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  if auth.uid() is null then
    raise exception 'Not authenticated';
  end if;

  delete from auth.users where id = auth.uid();
end;
$function$;

REVOKE ALL ON FUNCTION public.delete_own_account() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.delete_own_account() TO authenticated, service_role;

COMMIT;
