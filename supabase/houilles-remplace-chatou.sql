-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — La Corrida de Houilles remplace Chatou
--  À exécuter dans SQL Editor. Une seule fois.
--
--  La nouvelle préparation est une copie de l'ancienne : même prix, même
--  lien de paiement, même lieu, même horaire, même liste « Ce qui est
--  inclus ». Seuls changent le nom, les trois dates et le compteur.
--
--  Copier plutôt que retaper évite d'oublier une case en route — et si tu
--  avais retouché quelque chose sur Chatou, ça suit.
--
--   · dernier entraînement   dimanche 20 décembre 2026
--   · jour de course         dimanche 27 décembre 2026
--   · début, 12 séances plus tôt   dimanche 4 octobre 2026
--
--  ⚠ La préparation passe du samedi au dimanche, puisque le 20 décembre
--    tombe un dimanche. La ligne « Une séance par semaine… Le samedi »
--    de « Ce qui est inclus » est corrigée en conséquence.
--
--  ⚠ Chatou est supprimée. Elle n'avait aucun inscrit et aucun paiement.
--    Pour la garder de côté plutôt que l'effacer, remplace le « delete »
--    de la fin par la ligne commentée juste en dessous.
--
--  Tout se fait entre BEGIN et COMMIT : soit tout passe, soit rien ne bouge.
-- ═══════════════════════════════════════════════════════════════════════

begin;

-- ── 1) Une copie de Chatou, mise de côté le temps de la modifier ──────
create temporary table _nouvelle on commit drop as
  select * from public.preparations
   where id = 'course-chatou-saint-germain-en-laye-09-05-2027';

-- ── 2) Ce qui change ──────────────────────────────────────────────────
update _nouvelle set
  id          = 'course-corrida-de-houilles-27-12-2026',
  evenement   = '10k 54e Corrida de Houilles',
  date_course = date '2026-12-27',
  date_debut  = date '2026-10-04',
  date_fin    = date '2026-12-20',
  inscrits    = 8,
  -- L'ancienne liste de dates ne sert plus à rien : le calendrier se
  -- déduit du début et de la fin.
  dates       = null,
  -- « Le samedi de 9h30 à 10h45 » devient « Le dimanche ».
  inclus      = array(select replace(x, 'samedi', 'dimanche') from unnest(inclus) as x);

-- ── 3) Elle entre en base ─────────────────────────────────────────────
insert into public.preparations select * from _nouvelle;

-- ── 4) Chatou s'en va ─────────────────────────────────────────────────
delete from public.preparations
 where id = 'course-chatou-saint-germain-en-laye-09-05-2027';

-- Pour la garder sans l'afficher, mets le delete ci-dessus en commentaire
-- et enlève les deux tirets de la ligne suivante :
-- update public.preparations set actif = false
--  where id = 'course-chatou-saint-germain-en-laye-09-05-2027';

commit;

-- ── Vérification ──────────────────────────────────────────────────────
select id,
       evenement,
       sous_titre,
       date_debut,
       date_fin,
       ((date_fin - date_debut) / 7 + 1) as seances,
       heure, duree,
       prix, places, inscrits,
       (places - inscrits)               as places_restantes,
       date_course,
       actif
  from public.preparations
 order by date_course;
