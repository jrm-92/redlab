-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Ménage : les quatre fonctions de comptage périmées
--  À exécuter dans SQL Editor, APRÈS le déploiement de la nouvelle
--  fonction stripe-webhook. Une seule fois.
--
--  Ces quatre fonctions datent du modèle où la table « sessions » portait
--  tout. Elles comptent faux depuis la réorganisation en trois tables :
--
--    incr_inscrits_evenement(text)  « update sessions … where evenement =
--                                   p_evenement » — incrémente TOUTES les
--                                   séances portant le même nom
--                                   d'événement. Les cinq séances du
--                                   Vésinet montaient ensemble.
--
--    incr_inscrits_pack()           écrit dans « sessions », alors que le
--                                   bloc d'une préparation affiche
--                                   « preparations.inscrits » : une vente
--                                   ne se voyait pas.
--
--  Et leurs jumelles decr_. Plus rien ne les appelle : la nouvelle
--  fonction stripe-webhook utilise incr_inscrits_session(id) et
--  incr_inscrits_preparation(id), précises à la ligne près.
--
--  On les supprime pour qu'aucun code futur ne puisse les rappeler par
--  erreur — une fonction qui compte faux et qui reste disponible finira
--  par resservir.
--
--  ⚠ NE PAS LANCER tant que l'ancienne fonction stripe-webhook est
--     déployée : elle les appelle, et les paiements tomberaient en
--     erreur.
-- ═══════════════════════════════════════════════════════════════════════

drop function if exists public.incr_inscrits_evenement(text);
drop function if exists public.decr_inscrits_evenement(text);
drop function if exists public.incr_inscrits_pack();
drop function if exists public.decr_inscrits_pack();

-- ── Vérification ───────────────────────────────────────────────────────
--  Doit afficher EXACTEMENT quatre lignes :
--    decr_inscrits_preparation
--    decr_inscrits_session
--    incr_inscrits_preparation
--    incr_inscrits_session
select p.proname
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname like '%inscrits%'
 order by p.proname;
