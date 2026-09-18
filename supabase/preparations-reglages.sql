-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Le tableau des préparations : tout se règle dedans
--  À exécuter dans SQL Editor, APRÈS la mise en ligne du site. Une fois.
--
--  Jusqu'ici, certaines choses n'étaient pas dans le tableau : les dates de
--  début et de fin, la liste « Ce qui est inclus », le minimum de
--  participants, et le fait qu'une préparation n'avait droit qu'à un seul
--  rendez-vous par semaine. Elles étaient ailleurs — dans une autre table,
--  ou écrites dans la page. Il fallait passer par moi.
--
--  Elles deviennent des cases. Une case laissée vide = ce que le site
--  affichait jusqu'à présent.
--
--  Ce fichier ne suppose rien : il ajoute ce qui manque, reprend ce qui
--  existe quelle qu'en soit la forme, et ne touche pas à ce qui est déjà
--  en place. Le relancer deux fois ne change rien.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1) Les cases ──────────────────────────────────────────────────────
alter table public.preparations
  add column if not exists date_debut date,
  add column if not exists date_fin   date,
  add column if not exists heure      text,
  add column if not exists duree      text,
  add column if not exists jours      text[],
  add column if not exists inclus     text[],
  add column if not exists sous_titre text,
  add column if not exists mini       int;

-- ── 2) Reprendre le calendrier, quelle qu'en soit la forme ────────────
--     Selon l'ancienneté de la base, les dates sont dans une colonne
--     « dates », dans la table « preparation_seances », ou nulle part.
--     On prend ce qu'on trouve, et on ne se plaint pas du reste.
do $$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'preparations'
                and column_name = 'dates') then
    execute $q$
      update public.preparations
         set date_debut = coalesce(date_debut, dates[1]),
             date_fin   = coalesce(date_fin,   dates[array_length(dates, 1)])
       where dates is not null and array_length(dates, 1) > 0
    $q$;
  end if;

  if exists (select 1 from information_schema.tables
              where table_schema = 'public' and table_name = 'preparation_seances') then
    execute $q$
      update public.preparations p
         set date_debut = coalesce(p.date_debut, s.premiere),
             date_fin   = coalesce(p.date_fin,   s.derniere),
             heure      = coalesce(nullif(p.heure, ''), s.heure),
             duree      = coalesce(nullif(p.duree, ''), s.duree)
        from (
          select preparation_id,
                 min(date)                           as premiere,
                 max(date)                           as derniere,
                 (array_agg(heure order by date))[1] as heure,
                 (array_agg(duree order by date))[1] as duree
            from public.preparation_seances
           where actif is not false
           group by preparation_id
        ) s
       where s.preparation_id = p.id
    $q$;
  end if;

  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'preparations'
                and column_name = 'duree_prepa') then
    execute $q$
      update public.preparations
         set sous_titre = duree_prepa
       where sous_titre is null and nullif(btrim(duree_prepa), '') is not null
    $q$;
  end if;
end $$;

-- ── 3) L'heure, écrite pareil partout ─────────────────────────────────
--     « 09h30 » et « 9h30 » cohabitaient. La page lit les deux, mais la
--     liste des rendez-vous les affichait tels quels.
update public.preparations set heure = regexp_replace(heure, '^0(\d)h', '\1h') where heure ~ '^0\dh';
update public.sessions      set heure = regexp_replace(heure, '^0(\d)h', '\1h') where heure ~ '^0\dh';

-- ── 4) Ce que dit chaque colonne ──────────────────────────────────────
--     Ces descriptions s'affichent dans Table Editor, au survol du nom de
--     la colonne. Plus besoin de se souvenir de ce qu'on y met. Une
--     colonne absente est simplement sautée.
do $$
declare r record;
begin
  for r in
    select * from (values
      ('preparations', 'id', 'L''identifiant, repris tel quel par Stripe : lettres, chiffres, tiret, souligné. Ni accent ni espace. Ex. VESINET-10K-2027.'),
      ('preparations', 'evenement', 'Le nom de la course, en gros titre sur la page. Sans la date : elle a sa colonne.'),
      ('preparations', 'sous_titre', 'La petite ligne sous le titre. Ex. PRÉPARATION 10K. Vide = « Préparation 10k — 12 semaines ».'),
      ('preparations', 'date_course', 'Le jour de la course visée. Affiché en toutes lettres sous le titre.'),
      ('preparations', 'date_debut', 'Le jour de la première séance.'),
      ('preparations', 'date_fin', 'Le jour de la dernière séance. Rien n''est engendré au-delà.'),
      ('preparations', 'jours', 'Les rendez-vous de la semaine, un par ligne : « jeudi 19h00 1h ». Horaire et durée facultatifs. Vide = un par semaine, le jour de la date de début.'),
      ('preparations', 'heure', 'L''heure de rendez-vous, quand « jours » ne la précise pas. Ex. 9h30.'),
      ('preparations', 'duree', 'La durée d''une séance. Ex. 1h15.'),
      ('preparations', 'lieu', 'La ville et le lieu. Ex. Le Vésinet — Stade des Merlettes.'),
      ('preparations', 'sous_lieu', 'Le point de rendez-vous exact. Ex. Devant les vestiaires.'),
      ('preparations', 'prix', 'Le prix de la préparation entière, écrit comme il doit s''afficher. Ex. 135€.'),
      ('preparations', 'stripe', 'Le lien de paiement Stripe de CETTE préparation. Le montant du lien doit correspondre au prix.'),
      ('preparations', 'ancv', 'Le lien de règlement en Chèques-Vacances, s''il y en a un. Attention : un règlement ANCV n''incrémente pas « inscrits » tout seul.'),
      ('preparations', 'places', 'Le nombre de places. 10 par défaut.'),
      ('preparations', 'inscrits', 'Le nombre d''inscrits. Monte tout seul à chaque paiement Stripe.'),
      ('preparations', 'mini', 'Le nombre d''inscrits à partir duquel la préparation est confirmée. Vide = 5. Mettre 0 n''affiche aucun minimum.'),
      ('preparations', 'inclus', 'La liste « Ce qui est inclus », un point par ligne : « Titre | explication ». L''explication est facultative.'),
      ('preparations', 'lien_course', 'L''adresse du site officiel de la course.'),
      ('preparations', 'actif', 'Décoche pour retirer la préparation du site sans la supprimer.')
    ) as t(tbl, col, txt)
  loop
    if exists (select 1 from information_schema.columns
                where table_schema = 'public'
                  and table_name = r.tbl and column_name = r.col) then
      execute format('comment on column public.%I.%I is %L', r.tbl, r.col, r.txt);
    end if;
  end loop;
end $$;

-- ── 5) Comment remplir les deux listes ────────────────────────────────
--
--  JOURS — un rendez-vous par ligne : le jour, l'heure, puis la durée si
--  elle diffère de la colonne « duree ». Majuscules et accents indifférents.
--
--      jeudi 19h00 1h
--      samedi 9h30
--
--  INCLUS — un point par ligne : le titre, une barre verticale, puis
--  l'explication. Cinq raccourcis s'écrivent tout seuls :
--
--      {{SEANCES}}   le nombre de séances       {{SEMAINES}}  la durée en semaines
--      {{PLACES}}    le nombre de places        {{DUREE}}     la durée d'une séance
--      {{HORAIRE}}   l'horaire, « 9h30 à 10h45 »
--
--      12 séances encadrées | Le samedi de {{HORAIRE}}, en petit groupe.
--      Un plan sur {{SEMAINES}} semaines | Progressif, jusqu'au jour J.
--
--  Depuis Table Editor : cliquer la case, puis « Add item », une ligne
--  par entrée. Depuis SQL Editor :
--
-- update public.preparations
--    set jours  = array['jeudi 19h00 1h', 'samedi 9h30'],
--        inclus = array['{{SEANCES}} séances encadrées | Le samedi de {{HORAIRE}}.',
--                       'Un test de VMA | Pour caler tes allures.',
--                       'Un plan sur {{SEMAINES}} semaines']
--  where id = 'VESINET-10K-2027';

-- ── 6) Les séances à l'unité, réglées pareil ──────────────────────────
--     Même minimum, même description de chaque colonne : les deux tableaux
--     se remplissent de la même façon.
alter table public.sessions
  add column if not exists mini int;

do $$
declare r record;
begin
  for r in
    select * from (values
      ('sessions', 'id', 'L''identifiant, repris tel quel par Stripe : lettres, chiffres, tiret, souligné. Ni accent ni espace.'),
      ('sessions', 'evenement', 'Le nom affiché au-dessus du groupe de séances. Ex. Le Vésinet.'),
      ('sessions', 'titre', 'Le nom de la séance sur sa carte. Ex. VMA, Endurance, Seuil.'),
      ('sessions', 'sous_titre', 'Une précision sous le titre de la carte. Facultatif.'),
      ('sessions', 'description', 'Le détail de la séance, une ligne par point.'),
      ('sessions', 'date', 'Le jour de la séance.'),
      ('sessions', 'heure', 'L''heure de rendez-vous. Ex. 9h30.'),
      ('sessions', 'duree', 'La durée de la séance. Ex. 1h15.'),
      ('sessions', 'lieu', 'La ville et le lieu. Ex. Le Vésinet — Stade des Merlettes.'),
      ('sessions', 'sous_lieu', 'Le point de rendez-vous exact.'),
      ('sessions', 'prix_unitaire', 'Le prix de la séance, écrit comme il doit s''afficher. Ex. 13€.'),
      ('sessions', 'stripe', 'Le lien de paiement Stripe de CETTE séance. Sans lien, pas de bouton de règlement : la demande arrive par mail.'),
      ('sessions', 'ancv', 'Le lien de règlement en Chèques-Vacances, s''il y en a un. Il n''incrémente pas « inscrits » tout seul.'),
      ('sessions', 'places', 'Le nombre de places. 10 par défaut.'),
      ('sessions', 'inscrits', 'Le nombre d''inscrits. Monte tout seul à chaque paiement Stripe.'),
      ('sessions', 'mini', 'Le nombre d''inscrits à partir duquel la séance est confirmée. Vide = 5. Mettre 0 n''affiche aucun minimum.'),
      ('sessions', 'actif', 'Décoche pour retirer la séance du site sans la supprimer.')
    ) as t(tbl, col, txt)
  loop
    if exists (select 1 from information_schema.columns
                where table_schema = 'public'
                  and table_name = r.tbl and column_name = r.col) then
      execute format('comment on column public.%I.%I is %L', r.tbl, r.col, r.txt);
    end if;
  end loop;
end $$;

-- ── Vérification ──────────────────────────────────────────────────────
--  « semaines » est la durée qui s'affichera dans « Ce qui est inclus ».
--  Le nombre exact de séances dépend du jour où tombent le début et la
--  fin : c'est la page qui fait foi.
select id,
       evenement,
       sous_titre,
       date_debut,
       date_fin,
       to_char(date_debut, 'TMDay')        as jour_de_debut,
       jours,
       heure, duree,
       ((date_fin - date_debut) / 7 + 1)   as semaines,
       prix, places, inscrits,
       coalesce(mini, 5)                   as minimum,
       coalesce(array_length(inclus, 1), 0) as points_inclus,
       date_course,
       actif
  from public.preparations
 order by date_course nulls last;

-- ── 7) Ce qui ne sert plus, quand tout le reste est vérifié ───────────
--  À lancer séparément, plus tard, une fois la page regardée et les dates
--  contrôlées ci-dessus. Enlève les deux tirets du début de la ligne.
--
--  « duree_prepa » a été recopiée dans « sous_titre ». « dates » et la
--  table « preparation_seances » ne sont plus lues : le calendrier tient
--  dans la date de début, la date de fin et les jours.
--
-- alter table public.preparations drop column if exists duree_prepa;
-- alter table public.preparations drop column if exists dates;
-- drop table if exists public.preparation_seances;
