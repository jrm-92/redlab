-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Qui vient aux prochaines séances
--  À coller dans SQL Editor, lancer, puis SAVE pour la garder en favori.
--
--  Le Table Editor montre une ligne par inscrit, avec des identifiants de
--  séance qui ne disent rien et des colonnes qu'il faut aller chercher en
--  faisant défiler. Sur un téléphone, c'est illisible.
--
--  Ici : UNE ligne par séance, avec le nombre d'inscrits, leurs noms, et
--  leurs adresses regroupées — prêtes à coller dans un mail au groupe.
--
--  Les séances à l'unité et les préparations sortent dans la même liste :
--  la date d'une préparation est celle de sa première séance.
--
--  Les inscriptions remboursées ne comptent plus. Une inscription sans
--  rattachement (« lien mal réglé ») apparaît quand même, sans date, en
--  haut de la liste : c'est le signe qu'un lien de paiement Stripe ne
--  porte pas le bon identifiant.
--
--  Pour voir aussi les séances passées, enlève la ligne « where jour is
--  null or jour >= current_date - 1 ».
-- ═══════════════════════════════════════════════════════════════════════

with lignes as (
  select i.nom,
         i.email,
         coalesce(s.date,
                  (select min(ps.date)
                     from public.preparation_seances ps
                    where ps.preparation_id = i.preparation_id))            as jour,
         coalesce(s.titre, p.evenement, '⚠ lien de paiement mal réglé')     as libelle,
         case when i.preparation_id is not null
              then 'préparation' else 'séance' end                          as genre
    from public.inscriptions i
    left join public.sessions     s on s.id = i.session_id
    left join public.preparations p on p.id = i.preparation_id
   where i.annule_le is null
)
select jour                                                as date,
       genre,
       libelle                                             as seance,
       count(*)                                            as inscrits,
       string_agg(coalesce(nom, '(sans nom)'), ', ' order by nom)   as qui,
       string_agg(coalesce(email, ''), ', ' order by nom)           as emails
  from lignes
 where jour is null or jour >= current_date - 1
 group by jour, genre, libelle
 order by jour nulls first;
