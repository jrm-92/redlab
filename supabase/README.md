# RedLab × Polar AccessLink

Ce dossier contient ce qui ne peut pas vivre dans `index.html` : RedLab est une
page statique servie par GitHub Pages, donc **publique**. Le Client Secret Polar
et les jetons d'accès des athlètes n'y ont pas leur place — n'importe qui peut
lire le fichier. L'échange OAuth se fait donc dans une Edge Function Supabase.

## Ce que Polar permet, et ce qu'il ne permet pas

AccessLink donne accès aux **séances réalisées** (`Exercise data`) et aux
**données physiques** (`Physical information data`). Il n'expose aucun moyen de
**pousser** une séance vers la montre : la console de création de client ne
propose que ces types de données, sans équivalent d'un « training target ».

Autrement dit, Polar couvre le sens montre → RedLab. Le sens RedLab → montre
reste le fichier `.fit` téléchargé depuis la bibliothèque ou le calendrier.

## Mise en place

### 1. Le schéma

Exécuter `schema.sql` dans l'éditeur SQL de Supabase. Il crée trois tables :

| Table | Rôle | Qui peut lire |
|---|---|---|
| `polar_pending` | demandes d'autorisation en cours | le coach, les siennes |
| `polar_links` | liens établis (id Polar, date) | le coach, les siens |
| `polar_tokens` | jetons d'accès | **personne** — clé de service uniquement |

Les jetons sont dans une table à part, sans la moindre politique RLS. C'est
délibéré : un jeton n'a aucune raison d'atteindre un navigateur, et les
séparer rend cette garantie structurelle plutôt que déclarative.

### 2. Les secrets

```
supabase secrets set POLAR_CLIENT_ID=xxxxxxxx
supabase secrets set POLAR_CLIENT_SECRET=xxxxxxxx
```

`SUPABASE_URL` et `SUPABASE_SERVICE_ROLE_KEY` sont fournis automatiquement aux
Edge Functions, rien à faire pour eux.

### 3. Le déploiement

```
supabase functions deploy polar-callback --no-verify-jwt
```

`--no-verify-jwt` est **indispensable** : c'est Polar qui appelle cette adresse,
pas un utilisateur connecté. Sans ce drapeau, Supabase rejetterait l'appel faute
de jeton d'authentification et l'athlète verrait une erreur.

L'adresse obtenue doit correspondre exactement à celle déclarée chez Polar :

```
https://<ref-du-projet>.supabase.co/functions/v1/polar-callback
```

### 4. Le déclenchement, côté RedLab

Le `client_id` n'est pas un secret : RedLab peut construire l'URL d'autorisation
lui-même. Avant de rediriger, il insère une ligne dans `polar_pending` avec un
`state` aléatoire — c'est lui qui, au retour, dira à quel athlète rattacher le
compte, sans que cette information circule dans l'URL.

```
https://flow.polar.com/oauth2/authorization
  ?response_type=code
  &client_id=<client id>
  &redirect_uri=<l'adresse ci-dessus, encodée>
  &state=<aléatoire>
```

## Points de vigilance

**Le `state` est à usage unique.** La fonction le supprime dès qu'elle l'a lu,
avant même d'échanger le code. Un lien d'autorisation rejoué ne peut donc pas
rattacher un compte Polar à un autre athlète.

**Le code 409 à l'enregistrement n'est pas une erreur.** `POST /v3/users` répond
409 si l'utilisateur est déjà connu d'AccessLink, ce qui arrive à chaque
reconnexion. La fonction le traite comme un succès.

**Les transactions AccessLink détruisent ce qu'elles livrent.** Pour la
récupération des séances (à venir), AccessLink fonctionne par transactions :
on ouvre, on liste, on récupère, on valide. Une fois validée, **les séances ne
sont plus jamais reproposées**. Il faudra donc enregistrer d'abord et ne valider
qu'ensuite — sinon une panne au mauvais moment perd les données définitivement.

## État

La fonction n'a pas pu être testée contre l'API réelle : l'environnement de
développement utilisé n'a pas d'accès réseau vers Polar ni vers Supabase. La
syntaxe est vérifiée, la logique OAuth est standard, mais les adresses
AccessLink et la forme exacte des réponses sont à confirmer au premier essai.
Elles sont regroupées en tête de `polar-callback/index.ts` pour être corrigées
d'un seul endroit.
