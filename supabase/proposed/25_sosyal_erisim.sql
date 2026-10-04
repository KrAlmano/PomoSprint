-- ============================================================================
-- ÖNERİ 25: SOSYAL ERİŞİM (lig tabloları, arkadaş kodu yenileme)
--                                                           ÖNCELİK: P2
-- ============================================================================
-- Test ajanı bulguları (5 Ekim 2026, yerel kopyada yeniden üretildi:
-- supabase/tests/proposed_20_25_bulgu_repro_local.sql):
--  t3-LG5 league_memberships ve leagues doğrudan okunabiliyor: oda
--         arkadaşlarının user_id, joined_at ve weekly_points değerleri
--         (görünürlüğü kapalı olanlar dahil) REST'ten geliyor; ligi olmayan
--         kullanıcı tüm leagues satırlarını görüyor. İstemci bu tabloları
--         okumuyor (lib/ tarandı); tüm lig RPC'leri SECURITY DEFINER.
--  t3-K1  (kalan kısım) Sızan arkadaş kodu değiştirilemiyor
--         (profiles.friend_code için UPDATE yetkisi yok, RPC yok). Hız sınırı,
--         Crockford kod, bekleyen istekte id olmaması proposed/13'te (zincirde
--         doğrulandı); kod uzunluğu 13'ün app_config.friend_code_length
--         düğmesiyle 8'e çıkarılabilir (istemci 8 karakter kabul edince).
--
-- SIRA: zincirden (… → 13 → 14) SONRA (13'ün generate_friend_code ve
-- app_config'i kullanılır); 20–24 ile çakışmaz.
--
-- DEĞİŞİKLİKLER
--  A. REVOKE SELECT ON leagues, league_memberships FROM authenticated (anon'da
--     zaten yok). RLS politikaları yerinde kalır (zararsız). Lig verisi
--     yalnızca RPC'lerle: get_my_league_ranking / get_league_ranking (14'ten
--     sonra kimlik ve engel bilgisiyle), complete_study_session, cron.
--  B. rotate_friend_code() RPC (yeni): kullanıcının kodunu 13'ün üreticisiyle
--     (Crockford, app_config uzunluğu) yeniler, çakışmada yeniden dener;
--     24 saatte bir. Eski kod hemen geçersiz olur; bekleyen istekler ve
--     arkadaşlıklar etkilenmez.
--
-- İSTEMCİ SÖZLEŞMESİ (B; istemci bu RPC'yi ancak canlıya uygulandıktan sonra
-- çağırabilir):
--   rotate_friend_code() → {success:true, code:'rotated', friend_code} ya da
--   {success:false, code:'rate_limited', retry_after, message}.
--   Oturum yoksa 'not authenticated' (P0001). Profil > Arkadaş kodu
--   "Kodu yenile" düğmesi (onaylı) için.
--
-- supabase/proposed/ CLI tarafından UYGULANMAZ; bu dosya doğrudan
-- çalıştırılmaz (\quit).
--
-- ADIMLAR (SQL Editor, kullanıcı çalıştırır)
--  1. supabase/tests/proposed_25_sosyal_erisim_dryrun.sql → sonda
--     DRYRUN_RESULT; her madde 'true'.
--  2. Bu dosya \echo/\quit satırları silinerek (geçmişe 20261005125000
--     sosyal_erisim).
--  3. Doğrulama: select table_name, privilege_type from
--     information_schema.role_table_grants where grantee = 'authenticated'
--     and table_name in ('leagues', 'league_memberships');  -- SELECT yok
--  4. Geri alma: 25_sosyal_erisim_down.sql.
-- ============================================================================

\echo 'supabase/proposed/25: doğrudan çalıştırılmaz, dosya başındaki ADIMLAR bölümüne bakın.'
\quit

BEGIN;

-- ---------------------------------------------------------------------------
-- 0) Ön koşul: 13 uygulanmış (generate_friend_code, app_config_int)
-- ---------------------------------------------------------------------------
DO $pre$
BEGIN
    IF to_regprocedure('public.generate_friend_code(integer)') IS NULL
       OR to_regprocedure('public.app_config_int(text)') IS NULL THEN
        RAISE EXCEPTION 'proposed/25 ön koşulu: önce zincir uygulanmalı (13: generate_friend_code, app_config).';
    END IF;
    IF to_regprocedure('public.rotate_friend_code()') IS NOT NULL THEN
        RAISE EXCEPTION 'proposed/25 ön koşulu: rotate_friend_code zaten var (25 uygulanmış görünüyor).';
    END IF;
END
$pre$;

-- ---------------------------------------------------------------------------
-- A) Lig tabloları yalnızca RPC ile (t3-LG5)
-- ---------------------------------------------------------------------------
REVOKE SELECT ON public.leagues FROM authenticated, anon;
REVOKE SELECT ON public.league_memberships FROM authenticated, anon;

-- ---------------------------------------------------------------------------
-- B) Arkadaş kodunu yenileme (t3-K1)
-- ---------------------------------------------------------------------------
CREATE TABLE public.friend_code_rotations (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    rotated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.friend_code_rotations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.friend_code_rotations FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE public.friend_code_rotations IS
  'proposed/25: kullanıcının arkadaş kodunu son yenilediği an (24 saatte bir). Yalnızca rotate_friend_code.';

CREATE FUNCTION public.rotate_friend_code()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
    v_uid uuid := auth.uid();
    v_last timestamptz;
    v_code text;
    v_length integer;
    v_constraint text;
BEGIN
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    PERFORM 1 FROM public.profiles WHERE id = v_uid FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'not authenticated';
    END IF;

    SELECT r.rotated_at INTO v_last FROM public.friend_code_rotations r WHERE r.user_id = v_uid;
    IF v_last IS NOT NULL AND v_last > now() - interval '24 hours' THEN
        RETURN jsonb_build_object('success', false, 'code', 'rate_limited',
                                  'retry_after', v_last + interval '24 hours',
                                  'message', 'Arkadaş kodunu günde bir kez yenileyebilirsin.');
    END IF;

    v_length := coalesce(public.app_config_int('friend_code_length'), 6);
    FOR v_attempt IN 1..8 LOOP
        v_code := public.generate_friend_code(v_length);
        BEGIN
            UPDATE public.profiles SET friend_code = v_code WHERE id = v_uid;
            EXIT;
        EXCEPTION WHEN unique_violation THEN
            GET STACKED DIAGNOSTICS v_constraint = CONSTRAINT_NAME;
            IF v_constraint IS DISTINCT FROM 'profiles_friend_code_key' OR v_attempt = 8 THEN
                RAISE;
            END IF;
        END;
    END LOOP;

    INSERT INTO public.friend_code_rotations (user_id, rotated_at)
    VALUES (v_uid, now())
    ON CONFLICT (user_id) DO UPDATE SET rotated_at = excluded.rotated_at;

    RETURN jsonb_build_object('success', true, 'code', 'rotated', 'friend_code', v_code);
END;
$function$;
REVOKE ALL ON FUNCTION public.rotate_friend_code() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rotate_friend_code() TO authenticated, service_role;

DO $$
BEGIN
    INSERT INTO supabase_migrations.schema_migrations (version, name)
    VALUES ('20261005125000', 'sosyal_erisim')
    ON CONFLICT (version) DO NOTHING;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'migration geçmişine yazılamadı: %', SQLERRM;
END $$;

COMMIT;
