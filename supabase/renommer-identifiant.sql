-- ═══════════════════════════════════════════════════════════════════════
--  REDING RUNNING — Renommer l'identifiant d'une préparation
--  À exécuter dans SQL Editor. Réutilisable : il n'y a que les deux
--  premières lignes à changer.
--
--  L'identifiant voyage jusqu'à Stripe à chaque paiement : c'est lui qui
--  dit à quelle préparation rattacher l'argent reçu. Le changer d'un côté
--  sans l'autre casserait ce lien, donc tout se change en même temps —
--  la préparation, et tout ce qui la désigne.
--
--  ⚠ À faire à un moment calme. Un paiement lancé juste avant et réglé
--    juste après arriverait avec l'ancien identifiant : il faudrait le
--    rattacher à la main. Dans la pratique, la fenêtre est de quelques
--    minutes.
--
--  Rien à remettre en ligne : la page lit l'identifiant en direct.
-- ═══════════════════════════════════════════════════════════════════════
do $$
declare
  ancien text := 'adidas-10k-paris-2026';
  nouveau text := 'course-adidas-10k-paris-23-05-2027';
begin
  if not exists (select 1 from public.preparations where id = ancien) then
    raise exception 'Aucune préparation ne porte l''identifiant « % »', ancien;
  end if;
  if exists (select 1 from public.preparations where id = nouveau) then
    raise exception 'L''identifiant « % » est déjà pris', nouveau;
  end if;
  if nouveau !~ '^[A-Za-z0-9_-]+$' then
    raise exception 'Stripe n''accepte que lettres, chiffres, tiret et souligné : « % »', nouveau;
  end if;

  update public.preparations set id = nouveau where id = ancien;

  --  Tout ce qui désigne la préparation ailleurs, quand la table existe.
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'inscriptions'
                and column_name = 'preparation_id') then
    execute format('update public.inscriptions set preparation_id = %L where preparation_id = %L', nouveau, ancien);
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'sessions'
                and column_name = 'preparation_id') then
    execute format('update public.sessions set preparation_id = %L where preparation_id = %L', nouveau, ancien);
  end if;
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'preparation_seances'
                and column_name = 'preparation_id') then
    execute format('update public.preparation_seances set preparation_id = %L where preparation_id = %L', nouveau, ancien);
  end if;
end $$;

-- ── Vérification ──────────────────────────────────────────────────────
select id, evenement, date_debut, date_fin, date_course, prix, inscrits, actif
  from public.preparations
 order by date_course nulls last;
