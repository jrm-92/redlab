-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Nettoyage complémentaire (facultatif)
--  À lancer APRÈS securite-lot1.sql, et seulement si tu es d'accord.
-- ═══════════════════════════════════════════════════════════════════════

-- La colonne athlete_spaces.access_token servait au lien d'accès personnel
-- « espace.html?a=<jeton> », abandonné côté code le 16/08 (commit 9d1fc7c).
-- Une fois get_athlete_space_by_token supprimée (lot 1, bloc 1), plus rien
-- ne lit ni n'écrit cette colonne : ce ne sont que des secrets dormants.
--
-- 1) Regarde d'abord ce qu'elle contient :
--
--    select email, (access_token is not null) as a_un_jeton
--      from public.athlete_spaces;
--
-- 2) Si aucun athlète n'utilise encore un vieux lien « ?a=... »
--    (ce qui est le cas : le bouton qui les générait n'existe plus),
--    supprime la colonne :

alter table public.athlete_spaces drop column if exists access_token;
