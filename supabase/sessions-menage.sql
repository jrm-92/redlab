-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Remettre « sessions » au propre, sans trou
--  À exécuter dans SQL Editor. Une seule fois.
--
--  Tout se fait entre BEGIN et COMMIT : soit tout passe, soit rien ne
--  bouge. Et les vraies séances sont posées AVANT que les séances de
--  test ne soient retirées — la page ne se retrouve jamais vide.
--
--  ⚠ Ce fichier supprime quatre colonnes et cinq lignes. Ni l'une ni
--    l'autre ne se rattrapent. Les cinq séances sont recréées juste
--    au-dessus, à l'identique : mêmes dates, mêmes titres, mêmes
--    contenus, même lien de paiement. Seuls les identifiants changent,
--    de TEST1…TEST5 vers VESINET-2026-01…05.
--
--  CE QUE ÇA NETTOIE, relevé dans l'export du 18 septembre :
--
--   · les cinq séances TEST1 à TEST5, qui s'afficheraient sur le site à
--     côté des vraies ;
--
--   · « Le Vésinet » avec une espace à la fin sur trois lignes, sans sur
--     les deux autres. Le site les regroupe quand même — il coupe les
--     espaces en lisant — mais une valeur qui traîne finit toujours par
--     se retrouver là où personne ne l'a coupée ;
--
--   · quatre colonnes qui ne servent plus : prix_pack, stripe_pack,
--     duree_prepa, lien_course. Elles datent du modèle où « sessions »
--     portait aussi les préparations. Depuis que celles-ci ont leurs
--     deux tables, elles sont vides partout — mais elles s'affichent
--     encore dans le formulaire « Insert row », où elles s'ajoutent aux
--     vraies cases.
--
--     Les retirer ne change rien à l'affichage : le site les lit par la
--     même fonction qui sert aux préparations, et une colonne absente y
--     arrive comme « undefined », que les gardes rendent en chaîne vide.
--     C'est exactement ce qu'elles valent aujourd'hui.
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- ── 1) Les colonnes du modèle d'avant ─────────────────────────────────
alter table public.sessions drop column if exists prix_pack;
alter table public.sessions drop column if exists stripe_pack;
alter table public.sessions drop column if exists duree_prepa;
alter table public.sessions drop column if exists lien_course;

-- ── 2) Les vraies séances, posées avant qu'on retire les tests ────────
with commun as (
  select
    -- Le début de l'identifiant. Le numéro s'ajoute derrière.
    -- Lettres, chiffres, tiret, souligné : il voyage jusqu'à Stripe.
    'VESINET-2026-'::text                                     as prefixe,
    'Le Vésinet'::text                                        as evenement,
    'Tous niveaux'::text                                      as sous_titre,
    'Départ et Retour'::text                                  as lieu,
    'Place du marché'::text                                   as sous_lieu,
    '9h30'::text                                              as heure,
    '1h15'::text                                              as duree,
    '13'::text                                                as prix_unitaire,
    'https://buy.stripe.com/bJefZibZ5fYdfvT6mO8bS06'::text    as stripe
),
-- ── UNE LIGNE PAR SÉANCE : numéro, date, titre, contenu ───────────────
--    Pour en ajouter une sixième, ajoute une ligne. Ne réutilise pas un
--    numéro déjà pris : c'est lui qui fait l'identifiant.
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
insert into public.sessions
  (id, evenement, titre, sous_titre, date, heure, duree,
   lieu, sous_lieu, prix_unitaire, stripe, description)
select c.prefixe || lpad(s.rang::text, 2, '0'),
       c.evenement, s.titre, c.sous_titre, s.jour, c.heure, c.duree,
       c.lieu, c.sous_lieu, c.prix_unitaire, c.stripe, s.contenu
  from commun c, seances s
on conflict (id) do nothing;

-- ── 3) Les séances de test, maintenant que les vraies sont là ─────────
delete from public.sessions where id like 'TEST%';

-- ── 4) Les espaces qui traînent, sur ce qui resterait ─────────────────
update public.sessions set evenement = btrim(evenement)
 where evenement is not null and evenement <> btrim(evenement);
update public.sessions set titre = btrim(titre)
 where titre is not null and titre <> btrim(titre);
update public.sessions set lieu = btrim(lieu)
 where lieu is not null and lieu <> btrim(lieu);

commit;

-- ── Vérification ──────────────────────────────────────────────────────
select id, date, titre, evenement, prix_unitaire, places, inscrits, actif
  from public.sessions
 order by date;
