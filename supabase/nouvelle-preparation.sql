-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Les séances hebdomadaires d'une préparation
--
--  En deux temps, chacun là où il est le plus simple.
--
--  ÉTAPE 1 — la préparation, à la main dans le Table Editor.
--    Table Editor → preparations → bouton vert « Insert » → « Insert row ».
--    Il n'y a que sept cases à remplir :
--
--      id            course-chatou-saint-germain-en-laye-2027
--                    lettres, chiffres, tiret, souligné. RIEN d'autre :
--                    cet identifiant voyage jusqu'à Stripe et revient
--                    avec le paiement. Mets l'année, tu pourras refaire
--                    la même course l'an prochain.
--      evenement     10k Chatou - Saint-Germain-en-Laye
--                    sans la date : elle a sa propre case maintenant.
--      date_course   2027-05-09
--      duree_prepa   Préparation 10k - 12 semaines
--      prix          135€
--      stripe        le lien de paiement
--      lieu          Le Vésinet
--      sous_lieu     Les ibis
--
--    places, inscrits et actif se remplissent tout seuls. ancv et
--    lien_course se laissent vides tant qu'ils ne servent pas.
--
--  ÉTAPE 2 — ses séances, avec le bloc ci-dessous.
--    Douze lignes saisies à la main, c'est douze fois la même chose et
--    des dates à compter de sept en sept dans sa tête. Le bloc les pose
--    d'un coup.
--
--  POUR DEUX SÉANCES PAR SEMAINE — le mardi ET le samedi — relance le
--  bloc une seconde fois en changeant la date de la première, l'heure,
--  le titre, et en mettant '-B' dans v_suffixe.
-- ═══════════════════════════════════════════════════════════════════════

do $$
declare
  -- ══════════════════ À REMPLIR ══════════════════════════════════════

  -- L'identifiant de la préparation, tel que tu l'as saisi à l'étape 1.
  v_prep_id       text := 'course-chatou-saint-germain-en-laye-2027';

  v_nb_semaines   int  := 12;
  v_premiere      date := date '2027-02-13';   -- AAAA-MM-JJ, jour de la 1re séance
  v_heure         text := '9h30';
  v_duree         text := '1h15';
  v_titre         text := 'Séance 10k';
  v_sous_titre    text := 'Tous niveaux';
  v_description   text := E'Échauffement\nCorps de séance\nRetour au calme';

  -- Vide pour la séance de la semaine. '-B' pour en ajouter une seconde
  -- le même jour de semaine, sans écraser la première.
  v_suffixe       text := '';

  -- ══════════════════ FIN DE CE QU'IL Y A À REMPLIR ══════════════════

  i int;
  v_posees int := 0;
begin
  if not exists (select 1 from public.preparations where id = v_prep_id) then
    raise exception 'Aucune préparation ne porte l''identifiant « % ». Crée-la d''abord dans le Table Editor, ou vérifie l''orthographe.', v_prep_id;
  end if;

  for i in 1..v_nb_semaines loop
    insert into public.preparation_seances
      (id, preparation_id, date, heure, duree, titre, sous_titre, description, actif)
    values
      (v_prep_id || '-S' || lpad(i::text, 2, '0') || v_suffixe,
       v_prep_id,
       v_premiere + (i - 1) * 7,
       v_heure, v_duree, v_titre, v_sous_titre, nullif(v_description,''), true)
    on conflict (id) do nothing;
    v_posees := v_posees + 1;
  end loop;

  raise notice '% séances demandées pour « % », de % à %.',
    v_posees, v_prep_id, v_premiere, v_premiere + (v_nb_semaines - 1) * 7;
end $$;

-- ── Vérification ──────────────────────────────────────────────────────
--  Les séances posées, et la date de la course en regard : la dernière
--  doit tomber avant, et pas trop loin.
select ps.date       as date_seance,
       ps.heure,
       ps.titre,
       p.date_course,
       (p.date_course - ps.date) as jours_avant_la_course
  from public.preparation_seances ps
  join public.preparations p on p.id = ps.preparation_id
 where p.id = 'course-chatou-saint-germain-en-laye-2027'   -- ← le même qu'en haut
 order by ps.date;
