-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Remettre la table « sessions » au propre
--  À exécuter dans SQL Editor. Une seule fois.
--
--  ⚠ CE FICHIER EFFACE DES CHOSES. Il supprime les cinq séances de test
--    et quatre colonnes. Ni l'un ni l'autre ne se rattrapent. Lis avant
--    de lancer.
--
--  TROIS SALETÉS, RELEVÉES DANS L'EXPORT DU 18 SEPTEMBRE.
--
--  1. Les cinq séances TEST1 à TEST5. Elles s'affichent sur le site à
--     côté des vraies. Tant qu'il n'y avait qu'elles, ça allait.
--
--  2. « Le Vésinet » avec une espace à la fin sur trois des cinq, sans
--     sur les deux autres. Le site les regroupe quand même — il coupe
--     les espaces en lisant — mais une valeur qui traîne finit toujours
--     par se retrouver là où personne ne l'a coupée.
--
--  3. Quatre colonnes qui ne servent plus : prix_pack, stripe_pack,
--     duree_prepa, lien_course. Elles datent du modèle où « sessions »
--     portait aussi les préparations. Depuis que celles-ci ont leurs
--     deux tables, elles sont vides sur toutes les lignes — mais elles
--     restent affichées dans le formulaire « Insert row », où elles
--     s'ajoutent aux vraies cases et font hésiter.
--
--     Le site continue de les lire, par la même fonction qui sert aux
--     préparations. Une colonne absente y arrive comme « undefined »,
--     que les gardes convertissent en chaîne vide — exactement ce
--     qu'elles valent aujourd'hui. Rien ne change à l'affichage.
-- ═══════════════════════════════════════════════════════════════════════

-- ── 1) Les séances de test ────────────────────────────────────────────
delete from public.sessions where id like 'TEST%';

-- ── 2) Les espaces qui traînent ───────────────────────────────────────
update public.sessions
   set evenement = btrim(evenement)
 where evenement is not null and evenement <> btrim(evenement);
update public.sessions
   set titre = btrim(titre)
 where titre is not null and titre <> btrim(titre);
update public.sessions
   set lieu = btrim(lieu)
 where lieu is not null and lieu <> btrim(lieu);

-- ── 3) Les colonnes du modèle d'avant ─────────────────────────────────
alter table public.sessions drop column if exists prix_pack;
alter table public.sessions drop column if exists stripe_pack;
alter table public.sessions drop column if exists duree_prepa;
alter table public.sessions drop column if exists lien_course;

-- ── Vérification ──────────────────────────────────────────────────────
--  Ce qu'il reste à remplir dans « Insert row », dans l'ordre. Douze
--  cases, dont trois qui se remplissent d'elles-mêmes.
select column_name        as colonne,
       data_type          as type,
       column_default     as valeur_par_defaut
  from information_schema.columns
 where table_schema = 'public' and table_name = 'sessions'
 order by ordinal_position;
