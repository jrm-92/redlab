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
--  QUI LIT — personne, via l'API. La liste se consulte dans le tableau
--  de bord Supabase, qui se connecte en propriétaire de la table et
--  n'est donc pas soumis aux règles RLS. Aucune policy n'est créée : ni
--  le site, ni REDLAB, ni l'espace athlète ne peuvent atteindre ces
--  lignes. Même dispositif que stripe_events.
--
--  QUI ÉCRIT — service_role seul, c'est-à-dire la fonction
--  stripe-webhook. Un navigateur ne peut pas inventer une inscription.
-- ═══════════════════════════════════════════════════════════════════════

create table if not exists public.inscriptions (
  -- identifiant de la session de paiement Stripe (cs_…) : empêche les doublons
  id              text        primary key,

  -- identifiant du paiement (pi_…) : seul lien commun entre l'encaissement
  -- et le remboursement, qui n'arrive pas sous la même forme
  payment_intent  text,

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

-- Ajouts pour une table déjà créée sans ces colonnes
alter table public.inscriptions add column if not exists payment_intent text;

-- Retrouver vite « qui vient à cette séance », et la ligne à annuler
create index if not exists inscriptions_session_idx
  on public.inscriptions (session_id, date_seance);
create index if not exists inscriptions_preparation_idx
  on public.inscriptions (preparation_id, date_seance);
create index if not exists inscriptions_paiement_idx
  on public.inscriptions (payment_intent);

alter table public.inscriptions enable row level security;

-- Aucune règle de lecture : la liste se consulte dans le tableau de bord.
-- Une règle « to authenticated » aurait ouvert la liste aux athlètes de
-- l'espace personnel, qui sont eux aussi des comptes connectés.
drop policy if exists "le coach lit les inscriptions" on public.inscriptions;

-- ── Vérification ───────────────────────────────────────────────────────
--  Ne doit afficher AUCUNE ligne.
select tablename, policyname, cmd, roles::text
  from pg_policies
 where schemaname = 'public' and tablename = 'inscriptions';
