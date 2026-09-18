-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Créer plusieurs séances collectives d'un coup
--  À coller dans SQL Editor.
--
--  Une séance collective, c'est une ligne dans « sessions ». Cinq séances,
--  cinq lignes — et dans ces cinq lignes, treize colonnes sur quinze
--  portent la même valeur : le même lieu, la même heure, la même durée,
--  le même prix, le même lien de paiement, le même intitulé d'événement.
--  Seuls la date, le titre et le contenu changent vraiment.
--
--  Ce bloc sépare les deux. En haut, ce qui est commun, écrit une fois.
--  En dessous, une ligne par séance : sa date, son titre, son contenu.
--  Ajouter une sixième séance, c'est ajouter une ligne.
--
--  places, inscrits et actif ne sont pas listés : ils se remplissent
--  d'eux-mêmes (10, 0, vrai).
--
--  Relancer le bloc ne crée pas de doublon. Pour corriger une valeur
--  déjà posée, il faut passer par le Table Editor.
-- ═══════════════════════════════════════════════════════════════════════

-- ── Ménage, à ne lancer qu'une fois ───────────────────────────────────
--  Trois des cinq séances de test portent « Le Vésinet » avec une espace
--  à la fin, deux non. Le site les regroupe quand même — il coupe les
--  espaces en lisant — mais une valeur qui traîne finit toujours par se
--  retrouver quelque part où personne ne l'a coupée.
update public.sessions
   set evenement = btrim(evenement)
 where evenement is not null and evenement <> btrim(evenement);

-- ── Les séances ───────────────────────────────────────────────────────
with commun as (
  select
    -- Le début de l'identifiant. Lettres, chiffres, tiret, souligné
    -- UNIQUEMENT : il voyage jusqu'à Stripe et revient avec le paiement.
    -- Le numéro de la séance s'ajoute derrière : VESINET-2026-01, -02…
    'VESINET-2026-'::text                     as prefixe,

    -- Le grand titre qui coiffe le groupe de cartes, avec l'épingle.
    'Le Vésinet'::text                        as evenement,

    'Tous niveaux'::text                      as sous_titre,
    'Départ et Retour'::text                  as lieu,
    'Place du marché'::text                   as sous_lieu,
    '9h30'::text                              as heure,
    '1h15'::text                              as duree,
    '13'::text                                as prix_unitaire,
    'https://buy.stripe.com/CHANGE-MOI'::text as stripe
),
-- ── UNE LIGNE PAR SÉANCE ──────────────────────────────────────────────
--    numéro, date, titre, contenu.
--    Le numéro sert à fabriquer l'identifiant : ne le réutilise pas.
seances (rang, jour, titre, contenu) as (values
  (1, date '2026-10-17', 'Séance mixte',
      E'- Échauffement\n- Gammes et exercices spécifiques\n- Circuit training alternance course et renfo\n- Retour au calme'),
  (2, date '2026-10-24', 'Cardio - Fractionné',
      E'- Échauffement\n- Gammes et exercices spécifiques\n- Fractionné court\n- Retour au calme'),
  (3, date '2026-10-31', 'Vitesse & Technique',
      E'- Échauffement\n- Gammes et exercices spécifiques\n- Atelier pour optimiser la technique de course\n- Travail de la vitesse\n- Retour au calme'),
  (4, date '2026-11-07', 'Endurance',
      E'- Échauffement\n- Gammes et exercices spécifiques\n- Apprendre à tenir une allure, travail de capacité\n- Retour au calme'),
  (5, date '2026-11-14', 'Cardio - Fractionné en côtes',
      E'- Échauffement\n- Gammes et exercices spécifiques en côtes\n- Fractionné en côtes\n- Retour au calme')
)
-- ══════════════════ FIN DE CE QU'IL Y A À REMPLIR ═════════════════════
insert into public.sessions
  (id, evenement, titre, sous_titre, date, heure, duree,
   lieu, sous_lieu, prix_unitaire, stripe, description)
select c.prefixe || lpad(s.rang::text, 2, '0'),
       c.evenement, s.titre, c.sous_titre, s.jour, c.heure, c.duree,
       c.lieu, c.sous_lieu, c.prix_unitaire, c.stripe, s.contenu
  from commun c, seances s
on conflict (id) do nothing;

-- ── Vérification ──────────────────────────────────────────────────────
select id, date, titre, evenement, prix_unitaire, places, inscrits, actif
  from public.sessions
 where id like 'VESINET-2026-%'          -- ← le même préfixe qu'en haut
 order by date;
