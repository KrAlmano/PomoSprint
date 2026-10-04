-- PomoSprint şema parmak izi: canlı ve yerel kopyada AYNI metinle çalışır.
-- Yalnızca katalog okur (pg_catalog, pg_policies, cron.job); kullanıcı satırı
-- okumaz. Her satır bir nesnenin kanonik tanımıdır.
--
--   Ayrıntı : bu dosya olduğu gibi -> (k, line) satırları (satır içindeki
--             yeni satırlar '\n' olarak yazılır)
--   Özet    : son satır yerine
--             select k, count(*) n, md5(string_agg(line, E'\n' order by line collate "C")) h from lines group by k order by k;
--             (parity_check.sh --print-summary-sql bu sürümü basar)
--   Canlıda : SQL Editor ya da MCP execute_sql (salt okuma); yerelde
--             tool/local_supabase/parity_check.sh.
--
-- Kapsam: public şeması (tablolar, kolonlar, kısıtlar, index'ler, RLS,
-- politikalar, tablo/kolon/fonksiyon yetkileri, fonksiyon gövdeleri md5),
-- public ve auth tablolarındaki trigger'lar, cron.job, extension'lar,
-- public şeması yetkisi ve varsayılan yetkiler, yayınlar (publication).
-- Sıralama kanonik: ACL girdileri sıralanır, OID kullanılmaz.
with lines(k, line) as (
  -- Extension'lar (sürüm ayrı satırda: imaj farkı bilgi amaçlı)
  select 'ext', e.extname || ' schema=' || e.extnamespace::regnamespace::text
    from pg_extension e
  union all
  select 'extver', e.extname || ' ' || e.extversion
    from pg_extension e
  -- public şeması yetkisi
  union all
  select 'schema', n.nspname || ' owner=' || pg_get_userbyid(n.nspowner) || ' acl='
         || coalesce((select string_agg(x::text, ',' order by x::text collate "C") from unnest(n.nspacl) x), '')
    from pg_namespace n where n.nspname = 'public'
  -- public için varsayılan yetkiler
  union all
  select 'defacl', pg_get_userbyid(d.defaclrole) || ' ' || d.defaclobjtype::text || ' '
         || coalesce((select string_agg(x::text, ',' order by x::text collate "C") from unnest(d.defaclacl) x), '')
    from pg_default_acl d where d.defaclnamespace = 'public'::regnamespace
  -- Fonksiyonlar: imza, gövde md5, SECURITY DEFINER, sahip, yetki, yorum
  union all
  select 'func', p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')'
         || ' md5=' || md5(pg_get_functiondef(p.oid))
         || ' secdef=' || p.prosecdef::text
         || ' owner=' || pg_get_userbyid(p.proowner)
         || ' acl=' || coalesce((select string_agg(x::text, ',' order by x::text collate "C") from unnest(p.proacl) x), '<default>')
         || ' comment=' || coalesce(obj_description(p.oid, 'pg_proc'), '')
    from pg_proc p where p.pronamespace = 'public'::regnamespace
  -- Tablolar / view'lar / diziler
  union all
  select 'rel', c.relname || ' kind=' || c.relkind::text
         || ' rls=' || c.relrowsecurity::text || ' force=' || c.relforcerowsecurity::text
         || ' owner=' || pg_get_userbyid(c.relowner)
         || ' acl=' || coalesce((select string_agg(x::text, ',' order by x::text collate "C") from unnest(c.relacl) x), '<default>')
         || ' comment=' || coalesce(obj_description(c.oid, 'pg_class'), '')
         || case when c.relkind in ('v', 'm') then ' viewmd5=' || md5(pg_get_viewdef(c.oid)) else '' end
    from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'p', 'f', 'S')
  -- Kolonlar
  union all
  select 'col', c.relname || '.' || a.attname || ' ' || format_type(a.atttypid, a.atttypmod)
         || ' notnull=' || a.attnotnull::text
         || ' default=' || coalesce(pg_get_expr(d.adbin, d.adrelid), '')
         || ' identity=' || a.attidentity::text || ' generated=' || a.attgenerated::text
         || ' collation=' || coalesce((select collname from pg_collation where oid = a.attcollation and a.attcollation <> 100), '')
         || ' acl=' || coalesce((select string_agg(x::text, ',' order by x::text collate "C") from unnest(a.attacl) x), '')
         || ' comment=' || coalesce(col_description(c.oid, a.attnum), '')
    from pg_class c
    join pg_attribute a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
    left join pg_attrdef d on d.adrelid = c.oid and d.adnum = a.attnum
   where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'v', 'm', 'p', 'f')
  -- Kısıtlar
  union all
  select 'con', c.relname || ' ' || con.conname || ' ' || con.contype::text || ' ' || pg_get_constraintdef(con.oid)
         || ' deferrable=' || con.condeferrable::text || ' validated=' || con.convalidated::text
    from pg_constraint con join pg_class c on c.oid = con.conrelid
   where con.connamespace = 'public'::regnamespace
  -- Index'ler
  union all
  select 'idx', pg_get_indexdef(i.indexrelid)
    from pg_index i join pg_class c on c.oid = i.indrelid
   where c.relnamespace = 'public'::regnamespace
  -- RLS politikaları
  union all
  select 'pol', tablename || ' "' || policyname || '" ' || permissive || ' ' || cmd || ' roles=' || roles::text
         || ' using=' || coalesce(qual, '') || ' check=' || coalesce(with_check, '')
    from pg_policies where schemaname = 'public'
  -- Trigger'lar (public ve auth tabloları; etkinlik durumu dahil)
  union all
  select 'trg', c.relnamespace::regnamespace::text || '.' || c.relname || ' ' || t.tgname
         || ' enabled=' || t.tgenabled::text || ' ' || pg_get_triggerdef(t.oid)
    from pg_trigger t join pg_class c on c.oid = t.tgrelid
   where not t.tgisinternal and c.relnamespace in ('public'::regnamespace, 'auth'::regnamespace)
  -- pg_cron işleri
  union all
  select 'cron', j.jobname || ' ' || j.schedule || ' cmd_md5=' || md5(j.command)
         || ' active=' || j.active::text || ' user=' || j.username || ' db=' || j.database
    from cron.job j
  -- Yayınlar (Realtime)
  union all
  select 'pub', p.pubname || ' all=' || p.puballtables::text || ' tables='
         || coalesce((select string_agg(pr.prrelid::regclass::text, ',' order by pr.prrelid::regclass::text collate "C")
                        from pg_publication_rel pr where pr.prpubid = p.oid), '')
    from pg_publication p
)
select k, replace(line, E'\n', '\n') as line from lines order by k, replace(line, E'\n', '\n') collate "C";
