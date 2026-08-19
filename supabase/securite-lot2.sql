-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Suppression de la table meal_plans
--  À coller dans Supabase → SQL Editor → New query → Run.
--
--  meal_plans servait un outil de suivi des repas, abandonné.
--  Au moment de l'audit du 19/08/2026 elle était vide (0 ligne), et ses
--  trois policies ouvertes au rôle « anon » ont été retirées par
--  securite-lot1.sql. Il ne reste qu'une table vide et inutilisée.
--
--  Aucun code de RedLab ni du site ne la référence : vérifié par recherche
--  dans les deux dépôts.
-- ═══════════════════════════════════════════════════════════════════════

-- 1) Dernier contrôle avant de supprimer — doit renvoyer 0.
--    Si ce n'est pas le cas, ARRÊTE-TOI ici et exporte d'abord le contenu.
select count(*) as lignes_restantes from public.meal_plans;

-- 2) Suppression.
drop table if exists public.meal_plans;

-- 3) Vérification — meal_plans ne doit plus apparaître.
select c.relname as table_name, c.relrowsecurity as rls_active
  from pg_class c join pg_namespace n on n.oid = c.relnamespace
 where n.nspname = 'public' and c.relkind = 'r'
 order by c.relname;
