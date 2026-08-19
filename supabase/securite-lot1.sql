-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Durcissement sécurité, lot 1
--  Issu de l'audit RGPD / sécurité du 19 août 2026.
--  À coller dans Supabase → SQL Editor → New query → Run.
--
--  Ce script ne supprime AUCUNE donnée d'athlète. Il ferme des accès
--  ouverts et rend l'effacement RGPD techniquement possible.
--  Chaque bloc est indépendant et rejouable sans effet de bord.
-- ═══════════════════════════════════════════════════════════════════════


-- ───────────────────────────────────────────────────────────────────────
-- 1) FONCTION ORPHELINE : get_athlete_space_by_token
--
--    Créée le 14/08 pour le lien d'accès personnel « espace.html?a=<jeton> »
--    (commit 0a0e3a1), puis abandonnée côté code le 16/08 (commit 9d1fc7c).
--    Elle est restée en base : SECURITY DEFINER, exécutable par « anon »,
--    donc elle contourne la RLS et renvoie la fiche complète d'un athlète
--    à quiconque possède la clé publiable (qui est dans le HTML public).
--
--    Plus aucune ligne de code ne l'appelle → on la supprime.
--    La boucle gère la signature quelle qu'elle soit.
-- ───────────────────────────────────────────────────────────────────────
do $$
declare r record;
begin
  for r in
    select p.oid::regprocedure as sig
      from pg_proc p
      join pg_namespace n on n.oid = p.pronamespace
     where n.nspname = 'public'
       and p.proname = 'get_athlete_space_by_token'
  loop
    execute 'drop function ' || r.sig;
    raise notice 'Fonction supprimée : %', r.sig;
  end loop;
end $$;


-- ───────────────────────────────────────────────────────────────────────
-- 2) (bloc retiré) — la table meal_plans a été supprimée depuis, l'outil
--    de suivi des repas ayant été abandonné. Voir securite-lot2.sql.
-- ───────────────────────────────────────────────────────────────────────


-- ───────────────────────────────────────────────────────────────────────
-- 3) BILLETTERIE : seul le webhook Stripe peut toucher aux compteurs
--
--    Les 4 fonctions sont SECURITY DEFINER et PostgreSQL accorde EXECUTE
--    à PUBLIC par défaut → elles étaient appelables via /rest/v1/rpc/...
--    par n'importe qui. incr_inscrits_pack() en boucle affiche toutes les
--    sessions comme complètes ; decr_inscrits_pack() remet les compteurs
--    à zéro alors que les places sont payées.
--
--    ⚠️ Les GRANT à service_role sont indispensables : sans eux, le
--       webhook stripe-webhook cesse de compter les inscriptions.
-- ───────────────────────────────────────────────────────────────────────
revoke execute on function public.incr_inscrits_evenement(text) from public, anon, authenticated;
revoke execute on function public.incr_inscrits_pack()          from public, anon, authenticated;
revoke execute on function public.decr_inscrits_evenement(text) from public, anon, authenticated;
revoke execute on function public.decr_inscrits_pack()          from public, anon, authenticated;

grant execute on function public.incr_inscrits_evenement(text) to service_role;
grant execute on function public.incr_inscrits_pack()          to service_role;
grant execute on function public.decr_inscrits_evenement(text) to service_role;
grant execute on function public.decr_inscrits_pack()          to service_role;


-- ───────────────────────────────────────────────────────────────────────
-- 4) search_path figé sur les SECURITY DEFINER
--
--    Durcissement standard : sans search_path explicite, un objet créé
--    dans un schéma prioritaire peut détourner l'exécution d'une fonction
--    qui tourne avec les droits de son propriétaire.
-- ───────────────────────────────────────────────────────────────────────
alter function public.incr_inscrits_evenement(text) set search_path = public, pg_temp;
alter function public.incr_inscrits_pack()          set search_path = public, pg_temp;
alter function public.decr_inscrits_evenement(text) set search_path = public, pg_temp;
alter function public.decr_inscrits_pack()          set search_path = public, pg_temp;


-- ───────────────────────────────────────────────────────────────────────
-- 5) DROIT À L'EFFACEMENT (RGPD art. 17)
--
--    Aucune policy DELETE n'existait sur aucune table : la suppression
--    des données d'un athlète était techniquement impossible via l'API.
--    On l'autorise, strictement cadrée sur le propriétaire de la ligne.
-- ───────────────────────────────────────────────────────────────────────
drop policy if exists rs_delete on public.redlab_state;
create policy rs_delete on public.redlab_state
  for delete to authenticated
  using (user_id = auth.uid());

drop policy if exists as_delete on public.athlete_spaces;
create policy as_delete on public.athlete_spaces
  for delete to authenticated
  using (coach_id = auth.uid());


-- ───────────────────────────────────────────────────────────────────────
-- VÉRIFICATION — à lancer après coup, doit confirmer :
--   · une ligne DELETE pour redlab_state et pour athlete_spaces
--   · anon_peut = false sur les 4 fonctions de billetterie
--   · get_athlete_space_by_token absente
-- ───────────────────────────────────────────────────────────────────────
-- select tablename, policyname, cmd, roles::text
--   from pg_policies where schemaname = 'public' order by tablename, cmd;
--
-- select p.proname,
--        has_function_privilege('anon', p.oid, 'execute') as anon_peut
--   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
--  where n.nspname = 'public';
