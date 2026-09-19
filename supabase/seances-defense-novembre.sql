-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Les séances de La Défense, novembre 2026
--  À exécuter dans SQL Editor. Une seule fois.
--
--  Deux créneaux le même jour, la même séance donnée deux fois : le midi
--  de 12h00 à 13h15, le soir de 18h00 à 19h15. Le déroulé est celui des
--  cinq séances du Vésinet, repris à l'identique et remis dans l'ordre à
--  chaque cycle.
--
--  ── LA SEULE LIGNE À CHANGER ────────────────────────────────────────
--  « jours_voulus » dit quels jours de la semaine. 1 = lundi, 2 = mardi,
--  3 = mercredi, 4 = jeudi, 5 = vendredi, 6 = samedi, 7 = dimanche.
--
--      array[4]     → les jeudis :  5, 12, 19 et 26 novembre
--      array[2]     → les mardis :  3, 10, 17 et 24 novembre
--      array[2, 4]  → les deux, soit huit jours et seize séances
--
--  ⚠ Le mercredi 11 novembre est férié. Si tu choisis le mercredi,
--    enlève cette date à la main après coup.
--
--  Relancer ce fichier deux fois n'ajoute rien : les identifiants sont
--  construits sur la date, et une ligne déjà présente est ignorée.
-- ═══════════════════════════════════════════════════════════════════════

do $$
declare
  jours_voulus int[] := array[4];          -- ← les jours de la semaine

  premier date := date '2026-11-01';
  dernier date := date '2026-11-30';

  evenement_  text := 'La Défense';        -- le titre au-dessus des cartes
  lieu_       text := 'Départ et Retour';
  sous_lieu_  text := 'Le Parvis';
  sous_titre_ text := 'Tous niveaux';
  prix_       text := '13';
  stripe_     text := 'https://buy.stripe.com/bJefZibZ5fYdfvT6mO8bS06';
  duree_      text := '1h15';
begin
  insert into public.sessions
    (id, evenement, titre, sous_titre, date, heure, duree,
     lieu, sous_lieu, prix_unitaire, stripe, description)
  select
    'DEFENSE-' || to_char(j.jour, 'YYYY-MM-DD') || '-' || c.suffixe,
    evenement_, s.titre, sous_titre_, j.jour, c.heure, duree_,
    lieu_, sous_lieu_, prix_, stripe_, s.contenu
  from (
    -- Les jours retenus du mois, numérotés dans l'ordre.
    select d::date                       as jour,
           row_number() over (order by d) as rang
      from generate_series(premier, dernier, interval '1 day') d
     where extract(isodow from d)::int = any (jours_voulus)
  ) j
  -- Les deux créneaux de la journée.
  cross join (values ('MIDI', '12h00'), ('SOIR', '18h00')) as c(suffixe, heure)
  -- Les cinq séances du Vésinet, reprises en boucle.
  join (values
    (1, 'Séance mixte',
        E'- Échauffement\n- Gammes et exercices spécifiques\n- Circuit training alternance course et renfo\n- Retour au calme'),
    (2, 'Cardio - Fractionné',
        E'- Échauffement\n- Gammes et exercices spécifiques\n- Fractionné court\n- Retour au calme'),
    (3, 'Vitesse & Technique',
        E'- Échauffement\n- Gammes et exercices spécifiques\n- Atelier pour optimiser la technique de course\n- Travail de la vitesse\n- Retour au calme'),
    (4, 'Endurance',
        E'- Échauffement\n- Gammes et exercices spécifiques\n- Apprendre à tenir une allure, travail de capacité\n- Retour au calme'),
    (5, 'Cardio - Fractionné en côtes',
        E'- Échauffement\n- Gammes et exercices spécifiques en côtes\n- Fractionné en côtes\n- Retour au calme')
  ) as s(rang, titre, contenu)
    on s.rang = ((j.rang - 1) % 5) + 1
  on conflict (id) do nothing;
end $$;

-- ── Vérification ──────────────────────────────────────────────────────
--  Une ligne par séance créée, dans l'ordre où elles s'afficheront.
select id,
       to_char(date, 'TMDay DD/MM') as jour,
       heure, duree, titre, prix_unitaire, places, inscrits, actif
  from public.sessions
 where evenement = 'La Défense'
 order by date, heure;

-- ── Les Chèques-Vacances, quand le conventionnement sera fait ─────────
--  La colonne « ancv » de chaque séance porte le lien de règlement. Tant
--  qu'elle est vide, le bouton ne s'affiche pas. Pour les poser toutes
--  d'un coup, enlève les deux tirets et colle ton lien :
--
-- update public.sessions
--    set ancv = 'COLLE-ICI-TON-LIEN-ANCV'
--  where evenement = 'La Défense';
--
--  ⚠ Un règlement en Chèques-Vacances ne passe pas par Stripe : le
--    compteur « inscrits » ne monte pas tout seul. Ajoute 1 à la main
--    après chaque paiement en chèques.
