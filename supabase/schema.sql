-- ══════════════════════════════════════════════════════════════════════════
--  RedLab — le schéma complet, en une seule fois
--
--  À COLLER TEL QUEL dans Supabase → SQL Editor → New query → Run.
--
--  Sans danger si tu l'as déjà passé : chaque table est créée « if not
--  exists » et chaque règle d'accès est remplacée par sa version à jour.
--  Rien n'est effacé, aucune donnée existante n'est touchée.
--
--  La dernière requête du fichier affiche un tableau de contrôle : c'est lui
--  qu'il faut lire pour savoir si tout est en place.
-- ══════════════════════════════════════════════════════════════════════════

-- Demandes d'autorisation en cours. Le « state » OAuth est un jeton aléatoire
-- à usage unique : il relie le retour de Polar au coach et à l'athlète qui ont
-- lancé la connexion, sans que cette information transite par l'URL.
create table if not exists public.polar_pending (
  state       text primary key,
  coach_id    uuid not null references auth.users(id) on delete cascade,
  athlete_key text not null,
  created_at  timestamptz not null default now()
);

-- Lien établi : ce que le coach a le droit de consulter.
create table if not exists public.polar_links (
  coach_id      uuid not null references auth.users(id) on delete cascade,
  athlete_key   text not null,
  polar_user_id bigint not null,
  member_id     text  not null,
  linked_at     timestamptz not null default now(),
  primary key (coach_id, athlete_key)
);

-- Jetons d'accès, dans une table séparée et volontairement inaccessible.
-- Un jeton n'a aucune raison d'atteindre le navigateur : les tables portent
-- la même clé, mais celle-ci n'aura jamais la moindre politique RLS, donc
-- seule la clé de service (les Edge Functions) peut la lire.
create table if not exists public.polar_tokens (
  coach_id     uuid not null references auth.users(id) on delete cascade,
  athlete_key  text not null,
  access_token text not null,
  updated_at   timestamptz not null default now(),
  primary key (coach_id, athlete_key)
);

alter table public.polar_pending enable row level security;
alter table public.polar_links   enable row level security;
alter table public.polar_tokens  enable row level security;

-- Le coach ouvre lui-même une demande d'autorisation depuis RedLab.
drop policy if exists "coach ouvre sa demande" on public.polar_pending;
create policy "coach ouvre sa demande" on public.polar_pending
  for insert to authenticated with check (auth.uid() = coach_id);

drop policy if exists "coach voit ses demandes" on public.polar_pending;
create policy "coach voit ses demandes" on public.polar_pending
  for select to authenticated using (auth.uid() = coach_id);

-- Le coach voit et peut rompre ses propres liens.
drop policy if exists "coach voit ses liens" on public.polar_links;
create policy "coach voit ses liens" on public.polar_links
  for select to authenticated using (auth.uid() = coach_id);

drop policy if exists "coach supprime ses liens" on public.polar_links;
create policy "coach supprime ses liens" on public.polar_links
  for delete to authenticated using (auth.uid() = coach_id);

-- polar_tokens : aucune politique ici. C'est délibéré — voir le bloc de
-- contrôle en fin de fichier, et securite-lot3.sql qui n'ouvre que le DELETE.

-- Ménage des demandes jamais abouties (l'athlète a fermé l'onglet).
create index if not exists polar_pending_created_idx on public.polar_pending(created_at);

-- ══════════════════════════════════════════════════════════════════════════
--  Séances réalisées, remontées depuis la montre.
--
--  AccessLink livre les séances par « transactions » qui détruisent ce
--  qu'elles délivrent : une fois la transaction validée, les séances ne sont
--  plus jamais reproposées. On écrit donc ici AVANT de valider. La clé
--  primaire porte l'identifiant Polar : si une transaction est rejouée après
--  un incident, la même séance retombe sur la même ligne au lieu de créer un
--  doublon.
-- ══════════════════════════════════════════════════════════════════════════
create table if not exists public.polar_exercises (
  coach_id    uuid not null references auth.users(id) on delete cascade,
  athlete_key text not null,
  polar_id    text not null,
  start_time  timestamptz,
  duration_s  integer,
  distance_m  numeric,
  hr_avg      integer,
  hr_max      integer,
  sport       text,
  calories    integer,
  -- La réponse brute de Polar. Les champs ci-dessus servent l'affichage ;
  -- celui-ci garde ce qu'on n'a pas su lire, car la séance ne sera jamais
  -- reproposée par AccessLink.
  detail      jsonb,
  imported_at timestamptz not null default now(),
  primary key (coach_id, athlete_key, polar_id)
);

create index if not exists polar_exercises_athlete_idx
  on public.polar_exercises(coach_id, athlete_key, start_time desc);

alter table public.polar_exercises enable row level security;

-- Lecture et suppression par le coach concerné. Pas d'insert ni d'update :
-- ces lignes viennent de Polar via la fonction polar-pull, jamais du
-- navigateur — rien ne doit pouvoir fabriquer une séance réalisée.
drop policy if exists "coach voit les seances de ses athletes" on public.polar_exercises;
create policy "coach voit les seances de ses athletes" on public.polar_exercises
  for select to authenticated using (auth.uid() = coach_id);

drop policy if exists "coach supprime les seances de ses athletes" on public.polar_exercises;
create policy "coach supprime les seances de ses athletes" on public.polar_exercises
  for delete to authenticated using (auth.uid() = coach_id);


-- ═══════════════════════════════════════════════════════════════════════
-- CHARGES DE MUSCULATION
--
-- L'athlète note la charge qu'il a réellement mise sur chaque exercice.
-- Ce n'est pas une donnée du coach : c'est son carnet à lui, qu'il relit
-- à la séance suivante. Une ligne par exercice, écrasée à chaque fois —
-- on garde le dernier repère, pas l'historique complet.
--
-- La clé est l'e-mail : c'est ce que l'athlète prouve en se connectant par
-- lien magique, et c'est déjà la clé de sa fiche dans athlete_spaces.
-- ═══════════════════════════════════════════════════════════════════════
create table if not exists public.muscu_charges (
  email     text        not null,
  exercice  text        not null,       -- nom normalisé (minuscules, sans accent)
  libelle   text,                       -- nom tel qu'il s'affiche
  charge    text        not null,       -- ce que l'athlète a noté, tel quel
  seance    text,                       -- titre de la séance, pour le contexte
  fait_le   date,
  maj       timestamptz not null default now(),
  primary key (email, exercice)
);

alter table public.muscu_charges enable row level security;

-- L'athlète, et lui seul, lit et écrit ses propres charges. La comparaison
-- porte sur l'e-mail du jeton, en minuscules : c'est la seule identité qu'il
-- ait prouvée, et athlete_spaces l'utilise déjà de la même façon.
drop policy if exists "athlete lit ses charges" on public.muscu_charges;
create policy "athlete lit ses charges" on public.muscu_charges
  for select to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "athlete note ses charges" on public.muscu_charges;
create policy "athlete note ses charges" on public.muscu_charges
  for insert to authenticated
  with check (lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "athlete corrige ses charges" on public.muscu_charges;
create policy "athlete corrige ses charges" on public.muscu_charges
  for update to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email'))
  with check (lower(email) = lower(auth.jwt() ->> 'email'));

drop policy if exists "athlete efface ses charges" on public.muscu_charges;
create policy "athlete efface ses charges" on public.muscu_charges
  for delete to authenticated
  using (lower(email) = lower(auth.jwt() ->> 'email'));


-- ══════════════════════════════════════════════════════════════════════════
--  CONTRÔLE — ce qui doit s'afficher après le Run
--
--  Cinq lignes, rls_actif = true partout, et ceci :
--
--    table             regles  operations
--    muscu_charges       4     DELETE, INSERT, SELECT, UPDATE
--    polar_exercises     2     DELETE, SELECT
--    polar_links         2     DELETE, SELECT
--    polar_pending       2     INSERT, SELECT
--    polar_tokens        1     DELETE          ← et DELETE seulement
--
--  Ce que fait ce fichier seul donnerait ZÉRO règle à polar_tokens : un jeton
--  d'accès Polar n'a aucune raison d'atteindre un navigateur, il n'est lu que
--  par les Edge Functions, côté serveur.
--
--  securite-lot3.sql ouvre ensuite le DELETE, et lui seul, pour que la
--  suppression d'un athlète emporte son jeton — sans quoi un identifiant
--  vivant vers ses données chez un tiers survivrait à son effacement
--  (RGPD, droit à l'effacement). Le coach peut donc détruire le jeton de son
--  athlète ; il ne peut toujours pas le lire.
--
--  Ce qu'il faut surveiller, ce n'est donc pas le nombre mais l'opération :
--  un SELECT ou un UPDATE qui apparaîtrait sur polar_tokens serait la faille.
-- ══════════════════════════════════════════════════════════════════════════
select
  c.relname        as table_name,
  c.relrowsecurity as rls_actif,
  (select count(*) from pg_policies p
    where p.schemaname = 'public' and p.tablename = c.relname) as regles,
  (select string_agg(distinct p.cmd, ', ' order by p.cmd) from pg_policies p
    where p.schemaname = 'public' and p.tablename = c.relname) as operations
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
  and c.relname in ('polar_pending','polar_links','polar_tokens',
                    'polar_exercises','muscu_charges')
order by c.relname;
