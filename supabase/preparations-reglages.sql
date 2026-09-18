-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Le tableau des préparations : tout se règle dedans
--  À exécuter dans SQL Editor, APRÈS la mise en ligne du site. Une fois.
--
--  Jusqu'ici, certaines choses n'étaient pas dans le tableau : la liste
--  « Ce qui est inclus », le minimum de participants, et le fait qu'une
--  préparation n'avait droit qu'à un seul rendez-vous par semaine. Elles
--  étaient écrites dans la page, donc il fallait passer par moi.
--
--  Quatre cases de plus, et tout se règle depuis Table Editor.
--  Une case laissée vide = ce que le site affichait jusqu'à présent.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1) Les quatre nouvelles cases ─────────────────────────────────────
alter table public.preparations
  add column if not exists jours      text[],
  add column if not exists inclus     text[],
  add column if not exists sous_titre text,
  add column if not exists mini       int;

-- ── 2) Reprendre la ligne qui existait déjà sous le titre ─────────────
update public.preparations
   set sous_titre = duree_prepa
 where sous_titre is null and nullif(btrim(duree_prepa), '') is not null;

-- ── 3) Ce que dit chaque colonne ──────────────────────────────────────
--     Ces descriptions s'affichent dans Table Editor, au survol du nom de
--     la colonne. Plus besoin de se souvenir de ce qu'on y met.

comment on column public.preparations.id is
  'L''identifiant, repris tel quel par Stripe : lettres, chiffres, tiret, souligné. Ni accent ni espace. Ex. VESINET-10K-2027.';
comment on column public.preparations.evenement is
  'Le nom de la course, en gros titre sur la page. Sans la date : elle a sa colonne.';
comment on column public.preparations.sous_titre is
  'La petite ligne sous le titre. Ex. PRÉPARATION 10K. Vide = « Préparation 10k — 12 semaines ».';
comment on column public.preparations.date_course is
  'Le jour de la course visée. Affiché en toutes lettres sous le titre.';
comment on column public.preparations.date_debut is
  'Le jour de la première séance.';
comment on column public.preparations.date_fin is
  'Le jour de la dernière séance. Rien n''est engendré au-delà.';
comment on column public.preparations.jours is
  'Les rendez-vous de la semaine, un par ligne : « jeudi 19h00 1h ». Horaire et durée facultatifs. Vide = un par semaine, le jour de la date de début.';
comment on column public.preparations.heure is
  'L''heure de rendez-vous, quand « jours » ne la précise pas. Ex. 9h30.';
comment on column public.preparations.duree is
  'La durée d''une séance. Ex. 1h15.';
comment on column public.preparations.lieu is
  'La ville et le lieu. Ex. Le Vésinet — Stade des Merlettes.';
comment on column public.preparations.sous_lieu is
  'Le point de rendez-vous exact. Ex. Devant les vestiaires.';
comment on column public.preparations.prix is
  'Le prix de la préparation entière, écrit comme il doit s''afficher. Ex. 135€.';
comment on column public.preparations.stripe is
  'Le lien de paiement Stripe de CETTE préparation. Le montant du lien doit correspondre au prix.';
comment on column public.preparations.ancv is
  'Le lien de règlement en Chèques-Vacances, s''il y en a un. Attention : un règlement ANCV n''incrémente pas « inscrits » tout seul.';
comment on column public.preparations.places is
  'Le nombre de places. 10 par défaut.';
comment on column public.preparations.inscrits is
  'Le nombre d''inscrits. Monte tout seul à chaque paiement Stripe.';
comment on column public.preparations.mini is
  'Le nombre d''inscrits à partir duquel la préparation est confirmée. Vide = 5. Mettre 0 n''affiche aucun minimum.';
comment on column public.preparations.inclus is
  'La liste « Ce qui est inclus », un point par ligne : « Titre | explication ». L''explication est facultative.';
comment on column public.preparations.lien_course is
  'L''adresse du site officiel de la course.';
comment on column public.preparations.actif is
  'Décoche pour retirer la préparation du site sans la supprimer.';

-- ── 4) Comment remplir les deux listes ────────────────────────────────
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

-- ── 5) Les séances à l'unité, réglées pareil ──────────────────────────
--     Même minimum, même explication de chaque colonne : les deux tableaux
--     se remplissent de la même façon.
alter table public.sessions
  add column if not exists mini int;

comment on column public.sessions.id is
  'L''identifiant, repris tel quel par Stripe : lettres, chiffres, tiret, souligné. Ni accent ni espace.';
comment on column public.sessions.evenement is
  'Le nom affiché au-dessus du groupe de séances. Ex. Le Vésinet.';
comment on column public.sessions.titre is
  'Le nom de la séance sur sa carte. Ex. VMA, Endurance, Seuil.';
comment on column public.sessions.sous_titre is
  'Une précision sous le titre de la carte. Facultatif.';
comment on column public.sessions.description is
  'Le détail de la séance, une ligne par point.';
comment on column public.sessions.date is
  'Le jour de la séance.';
comment on column public.sessions.heure is
  'L''heure de rendez-vous. Ex. 9h30.';
comment on column public.sessions.duree is
  'La durée de la séance. Ex. 1h15.';
comment on column public.sessions.lieu is
  'La ville et le lieu. Ex. Le Vésinet — Stade des Merlettes.';
comment on column public.sessions.sous_lieu is
  'Le point de rendez-vous exact.';
comment on column public.sessions.prix_unitaire is
  'Le prix de la séance, écrit comme il doit s''afficher. Ex. 13€.';
comment on column public.sessions.stripe is
  'Le lien de paiement Stripe de CETTE séance. Sans lien, pas de bouton de règlement : la demande arrive par mail.';
comment on column public.sessions.ancv is
  'Le lien de règlement en Chèques-Vacances, s''il y en a un. Il n''incrémente pas « inscrits » tout seul.';
comment on column public.sessions.places is
  'Le nombre de places. 10 par défaut.';
comment on column public.sessions.inscrits is
  'Le nombre d''inscrits. Monte tout seul à chaque paiement Stripe.';
comment on column public.sessions.mini is
  'Le nombre d''inscrits à partir duquel la séance est confirmée. Vide = 5. Mettre 0 n''affiche aucun minimum.';
comment on column public.sessions.actif is
  'Décoche pour retirer la séance du site sans la supprimer.';

-- ── 6) Ce qui ne sert plus, quand tout le reste est vérifié ───────────
--  À lancer séparément, plus tard, une fois la page regardée.
--
-- alter table public.preparations drop column if exists duree_prepa;
