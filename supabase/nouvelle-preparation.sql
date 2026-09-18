-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Créer une préparation et ses séances hebdomadaires
--  À coller dans SQL Editor. Tout ce qu'il y a à remplir est en haut,
--  entre les deux lignes « À REMPLIR ». Le reste ne se touche pas.
--
--  Le bloc pose la préparation, puis génère une séance par semaine à la
--  même heure et au même endroit, à partir de la date de la première.
--
--  Deux préparations ne peuvent pas porter le même identifiant. Si celui
--  qu'on donne est déjà pris, le bloc s'arrête et le dit — il ne crée rien
--  à moitié. Pour corriger une valeur après coup, il faut la modifier dans
--  le Table Editor, pas relancer le bloc.
--
--  Pour DEUX séances par semaine (le mardi ET le samedi, par exemple) :
--  lancer le bloc une première fois tel quel, puis une seconde fois en
--  changeant seulement la date de la première séance, l'heure, le titre,
--  et en ajoutant « -B » à la fin du préfixe des séances.
-- ═══════════════════════════════════════════════════════════════════════

do $$
declare
  -- ══════════════════ À REMPLIR ══════════════════════════════════════

  -- L'identifiant de la préparation. Lettres, chiffres, tiret et
  -- souligné UNIQUEMENT : c'est lui qui voyage jusqu'à Stripe, et
  -- Stripe n'accepte rien d'autre. Pas d'espace, pas d'accent.
  v_id            text := 'PREPA-10K-2026';

  -- Le grand titre affiché au-dessus des cartes, avec l'épingle.
  v_evenement     text := '10k Chatou - Saint-Germain-en-Laye';

  -- La ligne grise sous le titre.
  v_duree_prepa   text := 'PRÉPARATION 10K - 12 SEMAINES';

  v_prix          text := '120';          -- en euros, sans le symbole
  v_places        int  := 10;             -- le maximum de participants

  v_lieu          text := 'Départ et Retour';
  v_sous_lieu     text := 'Place du marché';

  v_stripe        text := '';             -- le lien de paiement Stripe
  v_ancv          text := '';             -- le lien Chèques-Vacances, ou vide
  v_lien_course   text := '';             -- la page officielle de la course, ou vide

  -- ── Les séances, toutes identiques d'une semaine à l'autre ──
  v_nb_semaines   int  := 12;
  v_premiere      date := date '2026-10-03';   -- AAAA-MM-JJ, le jour de la 1re
  v_heure         text := '9h30';
  v_duree         text := '1h15';
  v_titre         text := 'Séance 10k';
  v_sous_titre    text := 'Tous niveaux';
  v_description   text := E'Échauffement\nCorps de séance\nRetour au calme';

  -- ══════════════════ FIN DE CE QU'IL Y A À REMPLIR ══════════════════

  i int;
begin
  if v_id !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'L''identifiant « % » contient autre chose que des lettres, chiffres, tiret ou souligné. Stripe le refuserait.', v_id;
  end if;

  -- Deux préparations ne peuvent pas porter le même identifiant : c'est lui
  -- qui revient de Stripe à chaque paiement, et il désigne UNE préparation.
  -- Le partager ferait compter les inscrits de l'une sur l'autre. On refuse
  -- bruyamment plutôt que de ne rien faire en silence — sans ça, un second
  -- passage avec le même identifiant semblerait réussir sans rien créer.
  if exists (select 1 from public.preparations where id = v_id) then
    raise exception 'Une préparation porte déjà l''identifiant « % ». Choisis-en un autre, par exemple en y mettant l''année.', v_id;
  end if;

  insert into public.preparations
    (id, evenement, duree_prepa, prix, places, inscrits,
     lieu, sous_lieu, stripe, ancv, lien_course, actif)
  values
    (v_id, v_evenement, v_duree_prepa, v_prix, v_places, 0,
     v_lieu, v_sous_lieu, nullif(v_stripe,''), nullif(v_ancv,''),
     nullif(v_lien_course,''), true);

  for i in 1..v_nb_semaines loop
    insert into public.preparation_seances
      (id, preparation_id, date, heure, duree, titre, sous_titre, description, actif)
    values
      (v_id || '-S' || lpad(i::text, 2, '0'),
       v_id,
       v_premiere + (i - 1) * 7,
       v_heure, v_duree, v_titre, v_sous_titre, nullif(v_description,''), true)
    on conflict (id) do nothing;
  end loop;
end $$;

-- ── Vérification : la préparation et ses séances, telles qu'elles sont ──
select ps.date, ps.heure, ps.titre, p.evenement, p.places, p.inscrits, p.actif
  from public.preparation_seances ps
  join public.preparations p on p.id = ps.preparation_id
 where p.id = 'PREPA-10K-2026'          -- ← remets ici le même identifiant
 order by ps.date;
