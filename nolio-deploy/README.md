# RedLab → Nolio (déploiement calendrier via l'API)

Pousse les séances générées par **RedLab** dans le **calendrier Nolio** comme
séances **planifiées structurées** (échauffement, séries, récup, retour au calme),
via l'**API officielle Nolio** (OAuth 2.0).

> Pourquoi l'API et pas un robot qui clique ? Parce qu'une API officielle ne casse
> pas quand l'interface de Nolio change. C'est la solution durable.

> ⚠️ L'API ne permet **pas** d'alimenter la « banque de modèles » réutilisables
> (sans date). Elle crée des séances **datées** sur le calendrier (d'un athlète ou
> du coach). Ce projet fait donc du **déploiement de plan** : une séance par date.

---

## 1. Pré-requis

- **Node.js 18+** installé (https://nodejs.org). Vérifie : `node --version`.
- Un compte **Nolio**.

## 2. Obtenir tes accès API (une fois)

1. Va sur **https://www.nolio.io/api** → *Obtenir l'accès* / *S'inscrire*.
2. Déclare ton app. Renseigne le **redirect_uri** exactement : `http://localhost:8721/callback`.
3. Récupère ton **client_id** et **client_secret**.

## 3. Configurer

```bash
cd nolio-deploy
cp config.example.json config.json
```

Édite `config.json` :

| Champ         | À mettre |
|---------------|----------|
| `clientId` / `clientSecret` | fournis par le portail Nolio |
| `redirectUri` | `http://localhost:8721/callback` (identique au portail) |
| `sportId`     | `2` = Running (24 = Tapis, 52 = Trail) |
| `vma`         | la VMA de l'athlète (km/h) — sert à convertir les % VMA en allures |
| `athleteId`   | `null` = pour toi ; sinon l'id Nolio d'un de tes athlètes |
| `startDate`   | date de la 1re séance (`YYYY-MM-DD`) |
| `intervalDays`| espacement entre séances (2 = une séance tous les 2 jours) |

`config.json` et `.tokens.json` ne doivent **jamais** être partagés (déjà dans `.gitignore`).

## 4. Fournir les séances

Dans RedLab → **Bibliothèque → ⬇ Exporter (JSON)**. Place le fichier téléchargé ici :

```
nolio-deploy/data/workouts.json
```

Astuce : garde dans ce fichier **uniquement les séances que tu veux déployer**, dans
l'ordre voulu. Tu peux aussi ajouter `"date": "2026-09-03"` à une séance pour forcer
sa date (sinon les dates sont calculées depuis `startDate`).

## 5. Lancer

```bash
node index.js --auth      # 1re fois : autorise l'accès (ouvre l'URL affichée, connecté à Nolio)
node index.js --dry-run   # vérifie le mapping : écrit out/payloads.json, N'ENVOIE RIEN
node index.js             # crée les séances dans le calendrier Nolio
node index.js --limit=3   # ne traite que les 3 premières (pour tester en réel)
```

Chaque exécution écrit un journal dans `logs/`.

### Interface graphique (recommandé)

Plutôt que de déployer en vrac, lance l'interface locale :

```
node server.js
```

Ça ouvre une page dans ton navigateur (http://localhost:8730) où tu peux :
- **cocher** les séances voulues (filtre de recherche dispo) ;
- mettre une **date** pour chacune (une par une) ;
- choisir l'**athlète** (menu déroulant, récupéré depuis ton compte Nolio ; « Moi » = ton calendrier) ;
- ajuster la **VMA** utilisée pour convertir les allures ;
- cliquer **Envoyer la sélection vers Nolio**.

Le secret reste côté serveur : le navigateur ne parle qu'à `localhost`.
Il faut avoir fait `node index.js --auth` au moins une fois avant.

---

## Comment marche la conversion

- Les allures RedLab sont en **% VMA**. Le mapper les convertit en **allure absolue**
  (m/s, le format `pace` de Nolio) à partir de la `vma` du `config.json`.
  → change la `vma` et relance pour un autre athlète.
- Une fraction `6 × 1000 m` devient une **répétition** Nolio ; les séries imbriquées
  (ex. 2 × (8 × 30/30)) sont gérées ; les fractions à segments (ex. 800 m allure 10K +
  200 m allure 5K) deviennent des steps successifs.
- Échauffement / retour au calme deviennent des steps `warmup` / `cooldown` à durée
  ouverte, avec le texte d'origine en commentaire.
- `id_partner` est un hash stable du titre : relancer **met à jour** au lieu de créer
  des doublons (Nolio renvoie « Training already exists » → la séance est ignorée).

## Limites connues

- Pas de banque de modèles via l'API (voir plus haut).
- Les récups exprimées en distance (« 1 km à allure marathon ») sont mises en
  commentaire, pas en step chiffré.
- Durée/distance affichées sur le calendrier sont **estimées** depuis la VMA.

## Architecture

```
index.js            orchestration (auth, mapping, envoi, logs)
src/config.js       lecture/validation de config.json
src/auth.js         OAuth2 (autorisation + refresh avec rotation)
src/api.js          appels HTTP (erreurs texte/JSON, retry 429)
src/mapper.js       séance RedLab → séance planifiée + workout structuré
src/logger.js       journal console + fichier
data/workouts.json  séances exportées depuis RedLab (à toi de le déposer)
```

Docs API Nolio : https://github.com/NolioApp/NolioAPI-Documentation/wiki
