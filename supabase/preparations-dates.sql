-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Une préparation : un début, une fin, un rythme
--  À exécuter dans SQL Editor, APRÈS la mise en ligne du site. Une fois.
--
--  Une préparation, c'est trois informations : quand elle commence, quand
--  elle finit, et un rendez-vous par semaine. La troisième est déjà écrite
--  sur la page — « Tous les samedis ». Restent deux cases.
--
--  Elles remplacent la table « preparation_seances », qui portait une ligne
--  par séance : douze lignes pour douze samedis, dont chacune ne disait
--  qu'une date. L'horaire y était recopié douze fois, l'intitulé n'est plus
--  affiché nulle part.
--
--  Les dates s'engendrent de sept en sept, de la première à la dernière
--  incluse. Le site le fait à l'affichage : rien n'est stocké.
--
--  ⚠ Si la date de fin ne tombe pas sur le bon jour de la semaine, la
--    dernière séance engendrée est celle d'AVANT. Le badge de période
--    l'affiche telle quelle : une erreur de saisie se voit tout de suite.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1) Les deux cases ─────────────────────────────────────────────────
alter table public.preparations
  add column if not exists date_debut date,
  add column if not exists date_fin   date,
  add column if not exists heure      text,
  add column if not exists duree      text;

comment on column public.preparations.date_debut is
  'Le jour de la première séance. Les suivantes tombent de sept en sept.';
comment on column public.preparations.date_fin is
  'Le jour de la dernière séance. Le site n''engendre rien au-delà.';

-- ── 2) Reprendre ce qui existe, quelle qu'en soit la forme ────────────
--    D'abord la liste de dates, si elle a déjà été posée…
update public.preparations
   set date_debut = coalesce(date_debut, dates[1]),
       date_fin   = coalesce(date_fin,   dates[array_length(dates, 1)])
 where dates is not null and array_length(dates, 1) > 0;

--    …sinon l'ancienne table de séances.
update public.preparations p
   set date_debut = coalesce(p.date_debut, s.premiere),
       date_fin   = coalesce(p.date_fin,   s.derniere),
       heure      = coalesce(nullif(p.heure, ''), s.heure),
       duree      = coalesce(nullif(p.duree, ''), s.duree)
  from (
    select preparation_id,
           min(date)                              as premiere,
           max(date)                              as derniere,
           (array_agg(heure order by date))[1]    as heure,
           (array_agg(duree order by date))[1]    as duree
      from public.preparation_seances
     where actif is not false
     group by preparation_id
  ) s
 where s.preparation_id = p.id;

-- ── 3) L'heure, écrite pareil partout ─────────────────────────────────
--    « 09h30 » et « 9h30 » cohabitaient. Le site lit les deux, mais la
--    liste des rendez-vous les affichait tels quels.
update public.preparations set heure = regexp_replace(heure, '^0(\d)h', '\1h') where heure ~ '^0\dh';
update public.sessions      set heure = regexp_replace(heure, '^0(\d)h', '\1h') where heure ~ '^0\dh';

-- ── Vérification ──────────────────────────────────────────────────────
--  « nb » est le nombre de séances que le site affichera. Si la date de
--  fin ne tombe pas sur le bon jour, il sera plus petit que prévu.
select id,
       evenement,
       heure, duree,
       date_debut,
       date_fin,
       to_char(date_debut, 'TMDay')                       as jour_de_la_semaine,
       ((date_fin - date_debut) / 7 + 1)                  as nb,
       date_course,
       (date_course - date_fin)                           as jours_avant_la_course
  from public.preparations
 order by date_course nulls last;

-- ── 4) Ce qui ne sert plus, quand tout le reste est vérifié ───────────
--  À lancer séparément, plus tard, une fois le site regardé. Enlève les
--  deux tirets du début.
--
-- alter table public.preparations drop column if exists dates;
-- drop table if exists public.preparation_seances;
