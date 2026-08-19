# Registre des activités de traitement

**Reding Running — Jérémy Reding**
Version 1 · 19 août 2026

---

## Pourquoi ce registre est obligatoire

L'article 30.5 du RGPD dispense les organismes de moins de 250 salariés de tenir
un registre. Trois exceptions annulent cette dispense, et il suffit qu'une seule
s'applique :

- le traitement n'est pas occasionnel ;
- il porte sur des **catégories particulières de données** (article 9) ;
- il est susceptible de comporter un risque pour les personnes.

L'activité de coaching coche les deux premières : le suivi est continu, et les
blessures, douleurs et contre-indications que les athlètes signalent sont des
données de santé. **La dispense ne s'applique donc pas.**

Ce registre est un document interne. Il n'est pas publié : il est tenu à jour et
communiqué à la CNIL sur demande.

---

## 1. Responsable du traitement

| | |
|---|---|
| **Nom** | Jérémy Reding |
| **Statut** | Entrepreneur individuel (micro-entrepreneur) |
| **Activité** | Coaching sportif — course à pied |
| **SIRET** | *à compléter* |
| **Adresse** | *à compléter* |
| **Contact** | contact@reding-running.fr |
| **Délégué à la protection des données** | Aucun — sa désignation n'est pas obligatoire ici (art. 37) |

Aucun DPO n'est requis : l'activité principale ne consiste ni en un suivi
systématique à grande échelle, ni en un traitement à grande échelle de données
sensibles. Le responsable du traitement assume directement les demandes
d'exercice des droits, à l'adresse ci-dessus.

---

## 2. Traitements

### T1 — Demandes de renseignement et prospection

| | |
|---|---|
| **Finalité** | Répondre aux demandes reçues par les formulaires du site, proposer un entretien téléphonique, qualifier le besoin |
| **Base légale** | Consentement (art. 6.1.a), recueilli par une case à cocher obligatoire |
| **Personnes concernées** | Toute personne remplissant un formulaire sur reding-running.fr |
| **Catégories de données** | Prénom, nom, email, téléphone, objectif sportif, course visée et sa date, chrono visé, meilleur temps récent, disponibilités pour un appel, message libre |
| **Destinataires** | Le responsable du traitement ; Web3Forms (acheminement) |
| **Transferts hors UE** | Web3Forms — localisation *à vérifier* |
| **Durée de conservation** | 3 ans à compter du dernier contact si aucune relation ne se noue |
| **Sécurité** | HTTPS, honeypot anti-robot, aucune donnée stockée sur le site |

> Les formulaires ne sollicitent aucune information de santé. Le champ libre peut
> toutefois en recevoir spontanément ; le cas échéant, ces informations relèvent
> de T2 dès l'engagement du suivi, et sont supprimées avec la demande sinon.

### T2 — Suivi d'entraînement des clients

| | |
|---|---|
| **Finalité** | Construire, ajuster et suivre un plan d'entraînement individualisé |
| **Base légale** | Exécution du contrat (art. 6.1.b) — et, pour les données de santé, **consentement explicite** (art. 9.2.a) |
| **Personnes concernées** | Clients en suivi à distance ou en coaching terrain |
| **Catégories de données** | Identité et coordonnées ; VMA, chronos, records, objectifs, plan ; séances réalisées (allures, distances, durées, fréquence cardiaque, dénivelé, tracé GPS) issues des fichiers `.fit` / `.tcx` **ou du compte Polar Flow lorsque l'athlète l'a relié** ; jeton d'accès Polar ; ressentis et échanges ; **données de santé** : blessures, douleurs, contre-indications signalées |
| **Destinataires** | Le responsable du traitement ; Supabase (hébergement) ; Nolio (plateforme d'entraînement) ; WhatsApp / Meta (échanges) ; Polar Electro (source des séances, si connexion autorisée) |
| **Transferts hors UE** | Supabase : **non** — hébergement en Europe de l'Ouest. WhatsApp / Meta et Nolio : *à vérifier* |
| **Durée de conservation** | Pendant toute la durée du suivi, puis 3 ans à compter du dernier contact. **Données de santé** : supprimées à la fin du suivi, ou avant sur demande. **Jeton Polar** : tant que la connexion est active ; supprimé à sa révocation ou avec le profil |
| **Sécurité** | Voir § 4 |

### T3 — Espace athlète

| | |
|---|---|
| **Finalité** | Mettre à disposition de chaque athlète ses propres données : repères, zones, allures cibles, objectif, plan |
| **Base légale** | Exécution du contrat (art. 6.1.b) |
| **Personnes concernées** | Clients disposant d'un accès à l'espace |
| **Catégories de données** | Email de connexion ; fiche rendue (mêmes données que T2) ; charge utile structurée permettant l'export |
| **Destinataires** | L'athlète lui-même et le responsable du traitement, exclusivement |
| **Transferts hors UE** | Non — Supabase, Europe de l'Ouest |
| **Durée de conservation** | Tant que le suivi est actif ; la fiche est supprimée avec le profil de l'athlète |
| **Sécurité** | Connexion par lien à usage unique envoyé par email, sans mot de passe ; cloisonnement par athlète appliqué en base (`lower(email) = lower(auth.jwt() ->> 'email')`), pas dans la page |

### T4 — Inscriptions aux sessions collectives et paiements

| | |
|---|---|
| **Finalité** | Enregistrer les réservations, encaisser, suivre le nombre de places |
| **Base légale** | Exécution du contrat (art. 6.1.b) |
| **Personnes concernées** | Participants aux sessions collectives |
| **Catégories de données** | Prénom, nom, email, téléphone, session choisie, date et lieu ; référence du paiement |
| **Destinataires** | Le responsable du traitement ; Web3Forms ; Stripe |
| **Transferts hors UE** | Stripe et Web3Forms — *à vérifier* |
| **Durée de conservation** | Durée de la prestation, puis 3 ans ; les pièces comptables suivent T5 |
| **Sécurité** | Aucune coordonnée bancaire n'est vue ni stockée : la saisie a lieu chez Stripe. Le webhook vérifie la signature HMAC de chaque événement et refuse les rejeux |

> Le compteur de places (`public.sessions`) est public en lecture. Il ne contient
> aucune donnée personnelle : titre, date, heure, lieu, prix, nombre d'inscrits.

### T5 — Comptabilité et facturation

| | |
|---|---|
| **Finalité** | Émettre les factures, tenir la comptabilité, répondre à un contrôle |
| **Base légale** | Obligation légale (art. 6.1.c) |
| **Personnes concernées** | Clients |
| **Catégories de données** | Identité, coordonnées, montant, date, objet de la prestation |
| **Destinataires** | Le responsable du traitement ; Stripe ; l'administration fiscale sur demande |
| **Durée de conservation** | **10 ans** (art. L123-22 du code de commerce) |
| **Sécurité** | — |

> C'est la seule catégorie qui échappe au droit à l'effacement. Une demande de
> suppression portant sur une facture doit être refusée par écrit, en citant
> cette obligation.

---

## 3. Sous-traitants et prestataires

| Prestataire | Rôle | Hors UE | Contrat de sous-traitance (art. 28) |
|---|---|---|---|
| **Supabase** | Base de données de l'espace athlète | Non — Europe de l'Ouest | *à vérifier / accepter* |
| **GitHub, Inc.** | Hébergement des pages (site, RedLab, espace athlète) | Oui — États-Unis | *à vérifier* |
| **Stripe** | Encaissement | *à vérifier* | *à vérifier* |
| **Web3Forms** | Acheminement des formulaires | *à vérifier* | *à vérifier* |
| **Meta (WhatsApp)** | Échanges avec les clients | *à vérifier* | Sans objet — usage grand public |
| **Nolio** | Plateforme d'entraînement | *à vérifier* | *à vérifier* |
| **Polar Electro** | Source des séances, sur autorisation de l'athlète | *à vérifier* | *à vérifier* |

Les mentions *à vérifier* ne sont pas des oublis : ce sont des points ouverts à
instruire, et à remplacer par une réponse datée. Ne rien y écrire vaut mieux
qu'y écrire une supposition.

---

## 4. Mesures de sécurité

**Techniques**

- HTTPS sur l'ensemble des pages et des échanges.
- Accès à RedLab réservé au coach authentifié (email et mot de passe).
- Accès à l'espace athlète par lien à usage unique envoyé par email, sans mot de
  passe stocké ni transmis.
- Cloisonnement en base par *row-level security*, active sur toutes les tables :
  chaque athlète ne lit que sa fiche, le coach ne lit que les siennes. La règle
  est appliquée par le serveur, jamais par la page.
- Aucune clé secrète dans le code publié : seule la clé publiable, dont les
  droits sont bornés par la RLS, figure dans les pages.
- Aucun cookie, aucun traceur, aucune mesure d'audience.
- Expiration de session après 30 jours d'inactivité, appliquée à l'ouverture de
  l'outil et de l'espace athlète (le réglage serveur équivalent relève d'un plan
  d'hébergement supérieur).
- Fichiers de montre (`.fit`, `.tcx`) lus dans le navigateur, jamais téléversés.
- Connexion Polar : autorisation donnée par l'athlète lui-même, en lecture seule,
  révocable à tout moment. Le jeton d'accès est rangé dans une table dont aucune
  politique n'autorise la lecture — seul le serveur y accède, jamais une page web.
  La suppression d'un athlète emporte son lien et son jeton.

**Organisationnelles**

- Une seule personne accède aux données.
- Suppression d'un athlète en un geste, qui efface la fiche publiée avant les
  données locales, et signale tout échec au lieu de le taire.
- Export de ses données par l'athlète, depuis son espace.
- Registre tenu à jour à chaque évolution de l'outil.

---

## 5. Violation de données

En cas de violation — accès non autorisé, perte, divulgation :

1. Consigner les faits : date, nature, données et personnes concernées, mesures prises.
2. Notifier la CNIL **dans les 72 heures** dès lors qu'un risque pour les
   personnes existe (art. 33).
3. Informer les personnes concernées si le risque est élevé (art. 34).
4. Conserver la trace de l'incident et du traitement qui en a été fait, y compris
   lorsqu'aucune notification n'était requise.

---

## 6. Journal des mises à jour

| Date | Modification |
|---|---|
| 19 août 2026 | Création du registre, à l'issue de l'audit RGPD et sécurité |
| 19 août 2026 | Durcissement de la base appliqué ; double authentification active sur Supabase et GitHub ; expiration de session après 30 jours d'inactivité |
| 19 août 2026 | Connexion Polar AccessLink : Polar Electro ajouté aux destinataires (T2), jeton d'accès déclaré, durée de conservation précisée |

---

## 7. Points ouverts

- [ ] SIRET et adresse du siège
- [ ] Adhésion à un médiateur de la consommation (art. L612-1 code de la consommation)
- [ ] Contrats de sous-traitance : Supabase, Stripe, Web3Forms, Nolio
- [ ] Localisation des données chez Stripe, Web3Forms, Nolio et Polar
- [ ] Mise en place effective des suppressions à échéance (T1, T2)
