# Sécurité de la base — état et scripts

Suivi des corrections issues de l'audit RGPD / sécurité du 19 août 2026.

## Scripts

| Fichier | Rôle | Statut |
|---|---|---|
| `securite-lot1.sql` | Ferme les accès anonymes, rend l'effacement possible | exécuté le 19/08/2026 |
| `securite-lot2.sql` | Supprime la table `meal_plans`, devenue sans objet | **exécuté le 19/08/2026** — le relevé du 11/09 ne trouve plus la table |
| `securite-lot1-optionnel.sql` | Supprime la colonne morte `access_token` | **à vérifier** — voir « Reste à traiter » |
| `schema.sql` | Tables Polar + `muscu_charges` | **déployé** — les quatre tables `polar_*` et `muscu_charges` existent |
| `securite-lot3.sql` | Ouvre le `DELETE`, et lui seul, sur `polar_tokens` | **exécuté** — confirmé par le relevé du 11/09 |

Ce tableau a dit pendant trois semaines que le lot 2 restait à exécuter et que
Polar n'était pas déployé, alors que le journal enregistrait le contraire et que
la base disait autre chose encore. Un document de sécurité qui se contredit ne
protège de rien : d'où le relevé ci-dessous, qui vient de la base et non de la
mémoire.

## Ce que le lot 1 corrige

1. **`get_athlete_space_by_token`** — fonction `SECURITY DEFINER` exécutable par
   `anon`, créée pour le lien d'accès personnel (commit `0a0e3a1`) puis abandonnée
   côté code (commit `9d1fc7c`) sans être retirée de la base. Elle contournait la
   RLS et renvoyait la fiche complète d'un athlète à qui possédait la clé
   publiable — laquelle est dans le HTML public. Supprimée.
2. **Fonctions de billetterie** (`incr_/decr_inscrits_*`) — appelables par `anon`
   via `/rest/v1/rpc/`, de quoi afficher toutes les sessions comme complètes ou
   remettre les compteurs à zéro. `EXECUTE` réservé à `service_role`, qui est le
   seul rôle dont le webhook Stripe a besoin.
3. **`search_path`** figé sur ces mêmes fonctions.
4. **Policies `DELETE`** ajoutées sur `redlab_state` et `athlete_spaces` : aucune
   n'existait, l'effacement RGPD (art. 17) était techniquement impossible.

## État relevé dans la base le 11 septembre 2026

Quatre requêtes de contrôle, passées dans SQL Editor. Elles ne lisent que le
catalogue système : `pg_class`, `pg_policies`, `pg_proc`, `pg_extension`.

| Contrôle | Résultat |
|---|---|
| Tables sans RLS | **aucune** — les onze tables ont `relrowsecurity = true` |
| `polar_tokens` | **`DELETE` seul** — ni `SELECT` ni `UPDATE` : le jeton se détruit, il ne se lit pas |
| `stripe_events` | aucune règle — `service_role` seul |
| Exposé à `anon` | **trois lignes exactement** : `preparations`, `preparation_seances`, `sessions`, toutes en `SELECT` |
| Fonctions `SECURITY DEFINER` | huit, **aucune** exécutable par `anon`, `public` ni `authenticated` |
| `search_path` | figé sur les huit, `pg_temp` en dernier depuis le 11/09 |

Les quatre requêtes sont à rejouer après toute migration : une table ajoutée
sans RLS, ou une policy écrite `to anon` au lieu de `to authenticated`, ne se
voit pas autrement. L'éditeur SQL de Supabase n'affiche que le résultat de la
**dernière** requête — les lancer une par une.

## Corrections de code du 11 septembre 2026

**Huit fonctions d'échappement, chacune incomplète autrement.** Laquelle
s'appliquait dépendait de l'endroit du fichier où l'on écrivait : quatre ne
traitaient que le guillemet (donc une balise passait en contexte texte), une
traitait `& " <` mais pas `>`, une `& <`, une `<` seul, et celle d'`espace.html`
`& < >` mais pas le guillemet — or elle servait dans `value="…"` et `href="…"`.
Remplacées par **une seule**, dans `UTILS`, qui échappe `& < > "` et
l'apostrophe. Elle ne suffirait pas dans un gestionnaire `on…="…"` : il n'en
existe aucun qui l'utilise, et il ne faut pas en créer.

Une donnée **tierce** entrait sans filtre : dans la veille PubMed, `it.id`
venait de l'API NCBI et partait brut dans un `href`. NCBI ne renvoie que des
identifiants numériques, donc rien n'est arrivé — c'était le seul endroit de
RedLab où une donnée extérieure atteignait le DOM sans échappement.

**Une CSP sur `index.html`, `espace.html` et `polar.html`.** Elle n'empêche pas
une injection : `'unsafe-inline'` est indispensable tant qu'`index.html` porte
ses 302 gestionnaires `on…=` en attribut. Elle empêche la **suite** — charger un
script tiers, et surtout exfiltrer, `connect-src` étant une liste close.

Deux réglages à ne pas casser :

- `upgrade-insecure-requests` est **volontairement absente**. Le pont
  nolio-deploy appelle `http://localhost:8730` en clair, ce qui est normal pour
  la machine du coach ; la directive l'aurait basculé en https et rompu en
  silence.
- `frame-src 'self'` : le Dashboard affiche `espace.html` en cadre.

Toute nouvelle origine appelée par le code doit être ajoutée à `connect-src`,
faute de quoi l'appel échoue **sans message visible**.

Vérifié en servant les CDN à leurs vraies URL, pour que la CSP les juge : les
bibliothèques chargent, un script depuis une origine interdite est bloqué, un
`fetch` d'exfiltration aussi. Sans ce dernier contrôle, une CSP malformée aurait
été ignorée sans que rien ne le signale.

## État vérifié le 19 août 2026

| Point | État |
|---|---|
| RLS active sur les 5 tables | ✅ |
| `with_check` des `INSERT` cadrés sur `auth.uid()` | ✅ |
| Isolation athlète : `lower(email) = lower(auth.jwt() ->> 'email')` | ✅ |
| Bucket `fiches` | supprimé — il n'a jamais rien contenu |
| Aucune clé secrète ni `service_role` côté client | ✅ |
| Webhook Stripe : signature HMAC vérifiée, anti-rejeu, zéro donnée bancaire | ✅ |
| Security Advisor | aucune erreur |
| `sessions` lisible par `anon` | ✅ voulu — catalogue public, aucune donnée personnelle |

## Réglages du tableau de bord (hors SQL)

- **2FA** — active sur le compte Supabase et sur le compte GitHub. ✅
- **Authentication → Sessions** — `Time-box user sessions` et `Inactivity
  timeout` sont **réservés au plan Pro**, et le projet est en plan gratuit : une
  session reste donc valide indéfiniment côté serveur. La règle des 30 jours est
  appliquée côté application, dans `espace.html` et `index.html` (voir plus bas).
  Le jour d'un passage au plan Pro, remettre le réglage serveur : il couvre aussi
  ce que le garde-fou navigateur ne peut pas couvrir.
- **Refresh Tokens** — « Detect and revoke potentially compromised refresh
  tokens » est actif. ✅

## Droits des personnes — ce que l'outil sait faire

- **Effacement (art. 17)** — `deleteAthlete()` supprime la ligne `athlete_spaces`
  avant de vider le `localStorage`. La policy
  `as_delete` limite la portée aux fiches du coach connecté : le filtre par
  email de la requête est doublé côté serveur par `coach_id = auth.uid()`.
  Si le nettoyage distant échoue, rien n'est supprimé en silence — le coach voit
  l'erreur et choisit.
- **Portabilité (art. 20)** — la fiche publiée embarque une charge utile
  structurée (`data.profil`) ; l'espace athlète propose « ⤓ Mes données », qui
  télécharge un JSON lisible. Les fiches publiées avant cet ajout n'ont pas la
  charge utile : l'export le signale et invite à republier.
- **Information** — liens vers la politique de confidentialité et les mentions
  légales dans la barre latérale de RedLab et le pied de l'espace athlète.
- **Expiration après inactivité (30 jours)** — appliquée à l'ouverture, côté
  athlète (`rl_derniere_visite`) comme côté coach (`rl_coach_derniere_visite`).
  Garde-fou navigateur : il couvre le scénario réel — téléphone ou ordinateur
  perdu, revendu, prêté — sans prétendre arrêter quelqu'un capable de lire le
  stockage local.

## Registre des traitements

`docs/registre-des-traitements.md` — document interne, non publié, à présenter
à la CNIL sur demande. Il est obligatoire ici : la dispense de l'article 30.5
ne joue pas, le suivi n'étant pas occasionnel et portant sur des données de
santé.

## Reste à traiter

- **`athlete_spaces.access_token`** — le lot 1 optionnel n'a jamais été
  confirmé. Le relevé du 11/09 porte sur les tables et les policies, pas sur les
  colonnes. À vérifier :
  `select column_name from information_schema.columns where table_name='athlete_spaces' and column_name='access_token';`
  Si la ligne sort, la colonne ne contient que des secrets dormants : plus rien
  ne la lit depuis la suppression de `get_athlete_space_by_token`.
- **Médiateur de la consommation** — quatre `[À COMPLÉTER]` dans `cgv.html` du
  dépôt `reding-coaching`, plus le nom de la préparation au § tarif.
- **Expiration de session côté serveur** — réservée au plan Pro. La règle des
  30 jours reste appliquée dans le navigateur : c'est un garde-fou, pas une
  serrure. À reprendre le jour d'un passage au plan Pro.
- Les points ouverts listés en fin de registre.

## Journal

| Date | Fait |
|---|---|
| 19 août 2026 | Audit. `securite-lot1.sql` exécuté : fonction orpheline supprimée, billetterie réservée à `service_role`, `search_path` figé, policies `DELETE` créées. 2FA GitHub activée. |
| 19 août 2026 | Table `meal_plans` supprimée (`securite-lot2.sql`) : l'outil de suivi des repas qu'elle servait est abandonné. Elle était vide, et ses trois policies ouvertes à `anon` avaient déjà été retirées. |
| 11 sept. 2026 | Relevé complet dans la base : onze tables, RLS partout, `polar_tokens` en `DELETE` seul, trois tables exposées à `anon` en `SELECT`, huit fonctions `SECURITY DEFINER` dont aucune appelable par `anon`. Aucune anomalie. |
| 11 sept. 2026 | `pg_temp` forcé en dernier sur les quatre fonctions de comptage du modèle à trois tables : elles n'avaient que `search_path = public`, rompant la convention du lot 1. Non vulnérables (requêtes qualifiées `public.…`), mais la protection ne dépend plus d'un préfixe. |
| 11 sept. 2026 | Huit fonctions d'échappement fondues en une seule, correcte en contexte texte comme en attribut. `it.id` de l'API NCBI échappé : seule donnée tierce qui atteignait le DOM sans filtre. |
| 11 sept. 2026 | CSP posée sur les trois pages de RedLab. Vérifiée active : origine étrangère bloquée en entrée comme en sortie. |
| 19 août 2026 | `shareFicheCloud()` et `ficheLinkModal()` retirés d'`index.html`, bucket `fiches` supprimé. Le partage de fiche par lien signé n'était relié à aucun bouton : du code mort portant un chemin d'envoi vers le stockage. |
