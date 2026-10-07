SELECT pg_get_functiondef('public.submit_user_report(uuid,text,text,text)'::regprocedure) AS definition,
       md5(pg_get_functiondef('public.submit_user_report(uuid,text,text,text)'::regprocedure)) AS md5,
       p.prosecdef AS security_definer, p.proconfig, p.proacl::text AS acl
FROM pg_proc p WHERE p.oid='public.submit_user_report(uuid,text,text,text)'::regprocedure;
