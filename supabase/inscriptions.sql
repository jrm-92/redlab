-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — La liste des personnes inscrites
--  À exécuter dans Supabase → SQL Editor. Une seule fois.
--
--  Jusqu'ici, une inscription payée ne laissait qu'un nombre : « inscrits
--  = 5 ». Le nom du payeur arrivait pourtant bien de Stripe, à chaque
--  paiement — la fonction stripe-webhook le recevait et le jetait.
--
--  Cette table le garde. Une ligne par paiement, rattachée soit à une
--  séance à l'unité, soit à une préparation. La clé est l'identifiant du
--  paiement Stripe : si Stripe renvoie deux fois le même événement, la
--  ligne ne se duplique pas.
--
--  Un remboursement total n'efface rien : il pose une date dans
--  « annule_le ». La place se rouvre, la trace reste.
--
--  Qui peut lire : le coach, et lui seul. Les athlètes de l'espace
--  personnel sont eux aussi « authenticated » — une règle ouverte à tout
--  le monde connecté leur donnerait le nom et l'email de chaque
--  participant. La règle est donc nominative.
--
--  Qui peut écrire : personne, sauf service_role — c'est-à-dire la
--  fonction stripe-webhook, et rien d'autre. Aucune règle INSERT,
--  UPDATE ou DELETE n'est créée : un navigateur ne peut pas inventer
--  une inscription.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.inscriptions (
  -- identifiant du paiement chez Stripe (cs_…) : empêche les doublons
  id              text        primary key,

  -- l'un OU l'autre, jamais les deux
  session_id      text,                   -- public.sessions.id
  preparation_id  text,                   -- public.preparations.id

  -- recopiée à l'inscription : sert à effacer la ligne six mois après,
  -- même si la séance a été supprimée entre-temps
  date_seance     date,

  nom             text,
  email           text,
  telephone       text,                   -- seulement si Stripe le demande

  montant_centimes integer,               -- 1300 = 13,00 €
  devise           text,

  paye_le         timestamptz not null default now(),
  annule_le       timestamptz             -- remboursement total
);

-- Retrouver vite « qui vient à cette séance »
create index if not exists inscriptions_session_idx
  on public.inscriptions (session_id, date_seance);
create index if not exists inscriptions_preparation_idx
  on public.inscriptions (preparation_id, date_seance);

alter table public.inscriptions enable row level security;

-- ── Lecture : le coach seul ────────────────────────────────────────────
--  Remplace l'adresse ci-dessous si tu te connectes à REDLAB avec une
--  autre. C'est la seule ligne à adapter de tout ce fichier.
drop policy if exists "le coach lit les inscriptions" on public.inscriptions;
create policy "le coach lit les inscriptions" on public.inscriptions
  for select to authenticated
  using (lower(coalesce(auth.jwt() ->> 'email', '')) = lower('jeremy.reding@outlook.fr'));

-- ── Vérification ───────────────────────────────────────────────────────
--  Doit afficher UNE seule ligne : inscriptions / SELECT / {authenticated}
select tablename, policyname, cmd, roles::text
  from pg_policies
 where schemaname = 'public' and tablename = 'inscriptions';
