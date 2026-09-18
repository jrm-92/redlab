-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Les dates d'une préparation passent sur la préparation
--  À exécuter dans SQL Editor, APRÈS la mise en ligne du site qui sait les
--  lire. Une seule fois.
--
--  Une préparation, c'est un produit et un calendrier. Le calendrier
--  tenait dans une table à part, « preparation_seances » : une ligne par
--  séance, douze lignes pour douze samedis. Chacune portait une date, un
--  horaire et un intitulé — et l'horaire était le même sur les douze,
--  l'intitulé n'est plus affiché nulle part.
--
--  Il ne reste donc qu'une information par ligne : la date. Une liste de
--  douze dates n'a pas besoin d'une table, elle tient dans une colonne.
--
--  Après ce fichier, la table peut être supprimée — la dernière commande
--  est là, en commentaire. Ne la lance qu'une fois le reste vérifié.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1) Les trois colonnes qui manquaient ──────────────────────────────
alter table public.preparations
  add column if not exists dates date[],
  add column if not exists heure text,
  add column if not exists duree text;

comment on column public.preparations.dates is
  'Les dates des séances, dans l''ordre. Le site en tire la période, le jour de la semaine et la liste des rendez-vous.';

-- ── 2) Reprendre ce que la table de séances contenait ─────────────────
update public.preparations p
   set dates = coalesce(p.dates, s.jours),
       heure = coalesce(nullif(p.heure, ''), s.heure),
       duree = coalesce(nullif(p.duree, ''), s.duree)
  from (
    select preparation_id,
           array_agg(date order by date)          as jours,
           (array_agg(heure order by date))[1]    as heure,
           (array_agg(duree order by date))[1]    as duree
      from public.preparation_seances
     where actif is not false
     group by preparation_id
  ) s
 where s.preparation_id = p.id;

-- ── Vérification ──────────────────────────────────────────────────────
--  Chaque préparation doit avoir sa liste de dates, son heure, sa durée.
--  « nb » doit valoir le nombre de semaines annoncé.
select id,
       evenement,
       heure,
       duree,
       array_length(dates, 1)  as nb,
       dates[1]                as premiere,
       dates[array_length(dates, 1)] as derniere,
       date_course
  from public.preparations
 order by date_course nulls last;

-- ── 3) La table, quand tout le reste est vérifié ──────────────────────
--  À lancer séparément, plus tard, une fois que le site affiche bien tes
--  préparations. Enlève les deux tirets du début pour l'exécuter.
--
-- drop table if exists public.preparation_seances;
