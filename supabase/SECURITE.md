# Sécurité de la base — état et scripts

Suivi des corrections issues de l'audit RGPD / sécurité du 19 août 2026.

## Scripts

| Fichier | Rôle | Statut |
|---|---|---|
| `securite-lot1.sql` | Ferme les accès anonymes, rend l'effacement possible | exécuté le 19/08/2026 |
| `securite-lot2.sql` | Supprime la table `meal_plans`, devenue sans objet | à exécuter dans SQL Editor |
| `securite-lot1-optionnel.sql` | Supprime la colonne morte `access_token` | après le lot 1, au choix |
| `schema.sql` | Tables Polar | **non déployé** — l'intégration Polar n'est pas active |

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

## État vérifié le 19 août 2026

| Point | État |
|---|---|
| RLS active sur les 5 tables | ✅ |
| `with_check` des `INSERT` cadrés sur `auth.uid()` | ✅ |
| Isolation athlète : `lower(email) = lower(auth.jwt() ->> 'email')` | ✅ |
| Bucket `fiches` privé (`public = false`) | ✅ |
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
  et les documents du bucket avant de vider le `localStorage`. La policy
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

- SIRET, adresse et médiateur de la consommation dans les pages légales
  (dépôt `reding-coaching`, branche `claude/rgpd-pages-legales`).
- Les points ouverts listés en fin de registre.

## Journal

| Date | Fait |
|---|---|
| 19 août 2026 | Audit. `securite-lot1.sql` exécuté : fonction orpheline supprimée, billetterie réservée à `service_role`, `search_path` figé, policies `DELETE` créées. 2FA GitHub activée. |
| 19 août 2026 | Table `meal_plans` supprimée (`securite-lot2.sql`) : l'outil de suivi des repas qu'elle servait est abandonné. Elle était vide, et ses trois policies ouvertes à `anon` avaient déjà été retirées. |
