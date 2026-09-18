-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — La table des préparations, plus facile à remplir
--  À exécuter dans SQL Editor, APRÈS la mise en ligne du site qui sait
--  lire la nouvelle colonne. Une seule fois.
--
--  Trois gênes, trois réponses.
--
--  1. LA DATE DE LA COURSE était collée à la fin du nom de l'événement
--     — « 10k Chatou - Saint-Germain-en-Laye 09/05/2027 ». Le site la
--     décollait au passage, avec une expression régulière, pour éviter
--     qu'elle se retrouve seule sur une deuxième ligne. Une date écrite
--     à la main dans un nom ne se trie pas, ne se compare pas, et une
--     faute de frappe ne se voit pas. Elle a maintenant sa colonne.
--
--  2. TROIS COLONNES SE REMPLISSAIENT TOUJOURS PAREIL : places à 10,
--     inscrits à 0, actif à vrai. Elles prennent ces valeurs d'office.
--     Une préparation créée dans le Table Editor n'a plus que son nom,
--     sa date, son prix et son lien à saisir.
--
--  3. UN IDENTIFIANT MAL FORMÉ ne se voyait qu'au premier paiement : il
--     voyage jusqu'à Stripe par client_reference_id, et Stripe n'accepte
--     que lettres, chiffres, tiret et souligné. Un accent ou une espace,
--     et le paiement revenait sans être rattachable. La base le refuse
--     désormais à l'écriture.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1) La date de la course, dans sa propre colonne ───────────────────
alter table public.preparations
  add column if not exists date_course date;

comment on column public.preparations.date_course is
  'Le jour de la course visée. Le site l''affiche en toutes lettres sous le titre.';

--    Récupérer les dates déjà écrites à la fin du nom…
update public.preparations
   set date_course = to_date(substring(evenement from '(\d{1,2}/\d{1,2}/\d{4})$'), 'DD/MM/YYYY')
 where date_course is null
   and evenement ~ '\d{1,2}/\d{1,2}/\d{4}\s*$';

--    …puis les retirer du nom, maintenant qu'elles ont leur place.
update public.preparations
   set evenement = btrim(regexp_replace(evenement, '\s*\d{1,2}/\d{1,2}/\d{4}\s*$', ''))
 where date_course is not null
   and evenement ~ '\d{1,2}/\d{1,2}/\d{4}\s*$';

-- ── 2) Ce qui se remplit toujours pareil se remplit tout seul ─────────
alter table public.preparations
  alter column places   set default 10,
  alter column inscrits set default 0,
  alter column actif    set default true;

alter table public.sessions
  alter column places   set default 10,
  alter column inscrits set default 0,
  alter column actif    set default true;

-- ── 3) Un identifiant que Stripe saura rendre ─────────────────────────
--     Lettres, chiffres, tiret, souligné. Rien d'autre.
alter table public.preparations
  drop constraint if exists preparations_id_utilisable;
alter table public.preparations
  add constraint preparations_id_utilisable check (id ~ '^[A-Za-z0-9_-]+$');

alter table public.sessions
  drop constraint if exists sessions_id_utilisable;
alter table public.sessions
  add constraint sessions_id_utilisable check (id ~ '^[A-Za-z0-9_-]+$');

-- ── Vérification ──────────────────────────────────────────────────────
--  Le nom doit être propre, la date dans sa colonne.
select id, evenement, date_course, duree_prepa, prix, places, inscrits, actif
  from public.preparations
 order by date_course nulls last;
