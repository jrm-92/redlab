-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Polar : rendre l'effacement possible
--  À exécuter APRÈS schema.sql, dans SQL Editor.
--
--  schema.sql donne au coach la lecture et la suppression de ses liens,
--  mais polar_tokens n'a délibérément aucune politique : un jeton n'a
--  aucune raison d'atteindre un navigateur.
--
--  Conséquence non voulue : la suppression d'un athlète, qui se fait
--  depuis RedLab, ne pouvait pas emporter son jeton. Un identifiant vivant
--  vers ses données chez un tiers serait resté en base après son effacement.
--
--  On ouvre donc le DELETE, et lui seul. Le SELECT reste fermé : le coach
--  peut détruire le jeton de son athlète, il ne peut toujours pas le lire.
--  La garantie structurelle est préservée.
-- ═══════════════════════════════════════════════════════════════════════

drop policy if exists "coach supprime ses jetons" on public.polar_tokens;
create policy "coach supprime ses jetons" on public.polar_tokens
  for delete to authenticated
  using (coach_id = auth.uid());

-- Vérification — doit lister UNE seule ligne pour polar_tokens, en DELETE.
select tablename, policyname, cmd, roles::text
  from pg_policies
 where schemaname = 'public' and tablename like 'polar%'
 order by tablename, cmd;
