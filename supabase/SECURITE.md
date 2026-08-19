# Sécurité de la base — état et scripts

Suivi des corrections issues de l'audit RGPD / sécurité du 19 août 2026.

## Scripts

| Fichier | Rôle | Statut |
|---|---|---|
| `securite-lot1.sql` | Ferme les accès anonymes, rend l'effacement possible | à exécuter dans SQL Editor |
| `securite-lot1-optionnel.sql` | Supprime la colonne morte `access_token` | après le lot 1, au choix |
| `schema.sql` | Tables Polar | **non déployé** — l'intégration Polar n'est pas active |

## Ce que le lot 1 corrige

1. **`get_athlete_space_by_token`** — fonction `SECURITY DEFINER` exécutable par
   `anon`, créée pour le lien d'accès personnel (commit `0a0e3a1`) puis abandonnée
   côté code (commit `9d1fc7c`) sans être retirée de la base. Elle contournait la
   RLS et renvoyait la fiche complète d'un athlète à qui possédait la clé
   publiable — laquelle est dans le HTML public. Supprimée.
2. **`meal_plans`** — `INSERT` / `SELECT` / `UPDATE` ouverts à `anon` avec
   `qual = true`. Table vide, mais l'écriture libre permettait de saturer la base
   du projet (plan gratuit) et d'emporter l'espace athlète. Policies retirées.
3. **Fonctions de billetterie** (`incr_/decr_inscrits_*`) — appelables par `anon`
   via `/rest/v1/rpc/`, de quoi afficher toutes les sessions comme complètes ou
   remettre les compteurs à zéro. `EXECUTE` réservé à `service_role`, qui est le
   seul rôle dont le webhook Stripe a besoin.
4. **`search_path`** figé sur ces mêmes fonctions.
5. **Policies `DELETE`** ajoutées sur `redlab_state` et `athlete_spaces` : aucune
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

- **Authentication → Sessions** : expiration après **30 jours d'inactivité**.
- **2FA** à activer sur le compte Supabase **et** sur le compte GitHub — c'est
  GitHub qui publie `coach.reding-running.fr`.

## Reste à traiter

- Suppression d'un athlète : `deleteAthlete()` ne vide que le `localStorage`,
  sans toucher `athlete_spaces` ni le bucket `fiches`.
- Export de ses données par l'athlète (portabilité, art. 20).
- Mentions RGPD absentes de RedLab et de l'espace athlète.
