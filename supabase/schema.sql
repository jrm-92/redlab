-- ══════════════════════════════════════════════════════════════════════════
--  RedLab × Polar AccessLink — schéma
--  À exécuter dans l'éditeur SQL de Supabase.
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

-- polar_tokens : aucune politique. C'est délibéré.

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
