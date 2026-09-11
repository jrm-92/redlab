-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Contrôle de sécurité de la base
--  À coller dans Supabase → SQL Editor. Ne modifie RIEN, ne fait que lire :
--  seulement le catalogue système (pg_class, pg_policies, pg_proc, pg_extension).
--
--  LANCE-LES UNE PAR UNE. L'éditeur SQL de Supabase n'affiche que le résultat
--  de la DERNIÈRE requête quand on en enchaîne plusieurs — les trois premières
--  passeraient inaperçues.
--
--  À rejouer après toute migration : une table ajoutée sans RLS, ou une policy
--  écrite « to anon » au lieu de « to authenticated », ne se voit pas autrement.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1) Une table sans RLS est ouverte à qui a la clé publique du site ──
--     Doit renvoyer ZÉRO ligne.
select c.relname as table_sans_rls
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity;

-- ── 2) Qui peut faire quoi, table par table ───────────────────────────
--     À lire ligne par ligne. Ce qu'on veut :
--       polar_tokens      → DELETE seulement, JAMAIS de SELECT ni d'UPDATE
--       preparations      → SELECT pour anon, rien d'autre
--       preparation_seances → SELECT pour anon, rien d'autre
--       sessions          → SELECT pour anon, rien d'autre
--       stripe_events     → aucune règle (service_role seul)
--       redlab_state / athlete_spaces / muscu_charges / polar_* → authenticated
select c.relname                as table_,
       c.relrowsecurity         as rls,
       coalesce(p.cmd, '(aucune règle)') as operation,
       p.roles::text            as pour_les_roles,
       p.policyname             as regle
  from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  left join pg_policies p on p.schemaname = 'public' and p.tablename = c.relname
 where n.nspname = 'public' and c.relkind = 'r'
 order by c.relname, p.cmd;

-- ── 3) Les fonctions qui contournent la RLS ───────────────────────────
--     « security definer » = s'exécute avec les droits de son créateur.
--     Aucune ne doit être exécutable par « anon » ou « public ».
--     La colonne « executable_par » doit être vide ou ne citer que service_role.
select p.proname                                   as fonction,
       case when p.prosecdef then 'SECURITY DEFINER' else 'invoker' end as mode,
       coalesce(array_to_string(p.proconfig, ', '), '⚠ search_path non figé') as config,
       (select string_agg(a.grantee, ', ')
          from information_schema.routine_privileges a
         where a.routine_schema = 'public'
           and a.routine_name = p.proname
           and a.grantee in ('anon','public','authenticated')) as executable_par
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prosecdef
 order by p.proname;

-- ── 4) Extensions installées dans public (mauvais emplacement) ────────
select extname, n.nspname as schema_
  from pg_extension e join pg_namespace n on n.oid = e.extnamespace
 where n.nspname = 'public';


-- ── 5) Ce qui est réellement exposé au public ─────────────────────────
--     La requête 2 dit quelles opérations existent, pas POUR QUI. Une table
--     privée dont le SELECT serait ouvert à « anon » y ressemble à une table
--     saine. Celle-ci ne liste que ce qui est exposé.
--     Doit renvoyer EXACTEMENT trois lignes : preparations,
--     preparation_seances et sessions, toutes en SELECT.
select tablename, cmd, roles::text
  from pg_policies
 where schemaname = 'public'
   and (roles::text like '%anon%' or roles::text like '%public%')
 order by tablename, cmd;
