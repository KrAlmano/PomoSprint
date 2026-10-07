SELECT p.oid::regprocedure::text AS signature,
       md5(pg_get_functiondef(p.oid)) AS definition_hash,
       p.prosecdef AS security_definer,
       p.proconfig::text AS function_settings,
       has_function_privilege('anon',p.oid,'EXECUTE') AS anon_execute,
       has_function_privilege('authenticated',p.oid,'EXECUTE') AS authenticated_execute
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='ops'
 ORDER BY 1;
