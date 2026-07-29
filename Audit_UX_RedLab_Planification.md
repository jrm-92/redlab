# Audit UX/UI — RedLab · Écran de Planification

*Audit produit destiné à faire de RedLab une référence pour les coachs de course à pied. Ton volontairement critique et sans complaisance. Chaque point : ce qui marche / ce qui ne marche pas / pourquoi / comment le corriger concrètement.*

---

## Diagnostic global en une phrase

RedLab est aujourd'hui un **excellent configurateur de macrocycle** (phases + volume hebdo en 3:1, affûtage sourcé Bosquet) mais **s'arrête là où le travail d'un coach commence** : il ne génère aucune séance, ne quantifie pas la charge de façon actionnable, et surtout **il demande sans expliquer**. C'est un formulaire qui dessine une courbe. L'objectif doit être un **assistant qui raisonne à voix haute**.

Le vrai levier de différenciation n'est pas esthétique : c'est de transformer chaque champ saisi en **justification en temps réel**, et chaque courbe en **décision d'entraînement**.

---

## 1. Hiérarchie visuelle

**Ce qui attire l'œil aujourd'hui**, dans l'ordre : (1) l'histogramme de périodisation (grande surface colorée, en bas), (2) le bloc « Préparation idéale », (3) le questionnaire. Les **contrôles réellement actionnables** (répartition des phases, dates) sont visuellement **secondaires**, alors que ce sont eux qui construisent le plan.

**Ce qui ne fonctionne pas :**
- La hiérarchie est **inversée par rapport à la valeur**. L'histogramme, joli mais passif (on ne peut rien y faire directement), domine. Les steppers +/- des phases, eux, sont petits et sous la ligne de flottaison.
- Le bloc « Préparation idéale » est mis en avant… mais il est **passif** depuis qu'on a retiré « Générer ». Un utilisateur ne sait plus s'il doit cliquer dessus ou l'ignorer.
- Trois zones se disputent l'attention sans parcours clair : Questionnaire → Préparation idéale → Ajuster la prépa → Graphe. L'œil ne sait pas **par où commencer ni où finir**.

**Pourquoi c'est un problème :** un coach scanne une interface en < 3 s. Si l'élément le plus gros n'est pas celui qui décide, il perd du temps à chercher « où est le bouton qui fait le plan ».

**Comment améliorer :**
- Adopter un **parcours en 3 étapes numérotées et linéaires** : `1. Profil coureur → 2. Recommandation justifiée → 3. Plan (ajustable + généré)`. Une seule colonne, du haut vers le bas, pas de zones qui se concurrencent.
- **Rendre l'histogramme interactif** (cliquer/glisser une phase modifie sa durée) pour justifier sa taille — ou le réduire tant qu'il est passif.
- Transformer « Préparation idéale » en **carte d'assistant vivante** (voir §3) avec une action claire « Appliquer cette structure ».
- **Un seul call-to-action principal** visible en permanence : `Générer le plan` (sticky en bas).

---

## 2. Questionnaire

Champs actuels : *Temps visé (h/m/s) · Historique (Déjà entraîné / Reprise) · Volume actuel (km/sem) · Séances/sem · Dont qualité · Blessure récente ? · Course préparatoire ?*

**Ce qui fonctionne :** les bons piliers sont là (volume, fréquence, intensité, historique, blessure). C'est déjà plus fin que la majorité des générateurs grand public.

**Ce qui ne fonctionne pas / manque :**
- **Ordre contre-intuitif.** « Temps visé » en premier alors que c'est l'info la moins fiable pour un coach en début de saison. On devrait partir du **coureur**, pas du chrono.
- **Manque : la performance de référence.** Un coach ne construit rien sans une **course/test récent** (dernier 10 km, VMA, allure seuil). RedLab a ces données côté profil/dashboard mais **ne les rappelle pas ici** → rupture.
- **Manque : la sortie longue actuelle** (durée du footing le plus long récent) — critique pour marathon et pour juger le point de départ.
- **Manque : jours disponibles / contraintes** (quels jours ? week-end libre ?) — indispensable pour un vrai plan.
- **« Dont qualité » est trop expert** pour un onboarding rapide et peu utilisé ensuite. À déduire automatiquement du niveau.
- **« Blessure récente ? » en oui/non est trop pauvre** : un coach veut *quoi, quand, guéri ou pas*.
- **« Historique (Déjà entraîné / Reprise) » recoupe** le volume + fréquence. Redondant.

**Regroupements & dynamique (objectif < 30 s) :**
- **Bloc A — Objectif** : distance (déjà via l'onglet) + date de course + chrono visé (optionnel, avec bouton « estimer à partir de mon niveau »).
- **Bloc B — État actuel** : volume actuel, fréquence, sortie longue actuelle. Trois curseurs, pas des champs.
- **Bloc C — Contraintes** (repliable, apparaît seulement si pertinent) : blessure (→ si « oui », déplier *zone / il y a combien de temps / douleur résiduelle*), jours dispo.
- **Champs dynamiques** : « Course préparatoire » ne s'affiche que si la durée du plan ≥ 8 semaines. « Dont qualité » disparaît (déduit). « Chrono visé » propose une **fourchette calculée** dès que la perf de référence est connue.

**Cible réaliste :** 5 curseurs + 1 date = réponse en ~20 s.

---

## 3. Préparation idéale

Aujourd'hui : un encart affiche `X semaines` + `2 base · 5 dev · 7 spé · 2 affûtage`. C'est calculé (`plRecoWeeks` + `plPhases`) mais **présenté comme un résultat figé, sans justification**.

**Ce qui ne fonctionne pas :** aucune **explication du pourquoi**. Le coach voit « 16 semaines » sans savoir si c'est parce que le volume est faible, l'objectif long, ou la reprise. Il ne peut donc **ni faire confiance, ni contester intelligemment**.

**Comment la rendre pertinente et inspirer confiance (le cœur de la vision « assistant ») :**
- **Justifier chaque nombre en langage naturel**, en citant les entrées :
  > « **16 semaines recommandées** — volume actuel faible (35 km), objectif marathon, aucune course préparatoire. Une base plus longue sécurise la montée en charge. »
- **Justifier la répartition** de la même façon :
  > « Bloc spécifique long (7 sem) car marathon : l'endurance à allure course est le facteur limitant. Base courte car tu es déjà entraîné. »
- Afficher **3 indicateurs de confiance** à côté de la reco : *Faisabilité du chrono* (vert/orange/rouge), *Risque de charge* (ACWR projeté), *Marge de temps* (semaines dispo vs recommandées).
- Bouton clair **« Utiliser cette structure »** qui pré-remplit l'éditeur — l'utilisateur reste libre d'ajuster ensuite.
- Rendre la reco **réactive** : si l'utilisateur change une entrée, la justification se réécrit en direct (« +2 semaines car tu as ajouté une blessure récente »).

C'est ce point qui distingue RedLab d'un simple générateur : **il montre son raisonnement**.

---

## 4. Ajustement manuel (dates + phases)

Aujourd'hui : dates (début / course / course prépa), durée totale (dérivée), et **steppers +/- par phase** (le total = la durée), bouton « Auto ».

**Ce qui fonctionne :** le principe « la course prime, on remonte depuis le jour J » est juste et pro. Le fait que modifier une phase recalcule tout est bon.

**Ce qui ne fonctionne pas :**
- Les **+/- sont laborieux** : passer une phase de 2 à 7 = 5 clics. Et chaque clic change le total, ce qui **déplace toutes les dates** — désorientant.
- **Pas de vision d'ensemble** : on édite 4 nombres sans voir leur poids relatif ni les dates de bascule de phase.
- Le lien **durée ↔ dates ↔ phases** est puissant mais **opaque** (on l'a vu, source de bugs et de confusion).

**Meilleure façon de modifier les phases :**
- **Une barre de timeline horizontale segmentée** (Base | Dév | Spé | Affûtage), chaque segment proportionnel à sa durée, avec des **poignées de séparation à glisser**. Glisser une frontière transfère des semaines d'une phase à l'autre **à total constant** — exactement le geste mental du coach.
- Afficher **sur la timeline les dates de bascule** (« Spé commence le 25/08 ») et les jalons (course prépa, jour J).
- Deux modes explicites : **« total fixe »** (les frontières redistribuent) et **« ajouter/retirer »** (change la durée). Aujourd'hui les deux sont mélangés dans le stepper.
- Saisie directe possible : un champ nombre éditable dans chaque segment pour les précis.

---

## 5. Périodisation (le graphique)

Aujourd'hui : histogramme du **volume km/sem**, barres colorées par phase, décharge 3:1 en teinte claire, label « JOUR J », valeurs au-dessus.

**Est-il utile ? Partiellement.** Il montre bien **une** dimension (le volume) et le rythme 3:1 est lisible. Mais un plan d'entraînement, ce n'est **pas que du volume**.

**Ce qui ne fonctionne pas :**
- **Le volume seul est trompeur.** Une semaine à 60 km facile ≠ 60 km avec deux VMA. La *charge* dépend du volume **× intensité**. Le graphe actuel peut afficher une montée de volume alors que la charge réelle explose (ou l'inverse en spécifique).
- Aucune notion de **charge cumulée / fraîcheur** (le fameux CTL/ATL/TSB de TrainingPeaks), alors que RedLab **connaît déjà l'ACWR** (il est documenté dans l'onglet Connaissances) — occasion manquée.
- Pas de **repère de risque** (zone ACWR > 1,5).

**Alternatives de représentation (par ordre d'ambition) :**
1. **Barres empilées EF / Seuil / VMA / Spécifique** au lieu d'une barre monochrome par phase : on voit *comment* le volume se compose et l'intensité monter. (Quick win moyen.)
2. **Double axe** : barres = volume, **courbe superposée = charge (unités arbitraires = volume × intensité moyenne de la semaine)**. C'est ce que cherche un coach.
3. **Graphe Forme/Fatigue** (type PMC) : courbe de charge chronique (fitness), charge aiguë (fatigue), et fraîcheur (fitness − fatigue) qui doit remonter en affûtage. C'est LA vue premium.
4. **Bande ACWR colorée** sous le graphe (vert 0,8–1,3 / rouge > 1,5) semaine par semaine.
5. **Toggle** « Volume | Charge | Fraîcheur » pour ne pas surcharger.

Recommandation : garder l'histogramme comme vue par défaut, **ajouter le toggle Charge/Fraîcheur** et la **bande de risque ACWR**.

---

## 6. Informations qu'un coach veut voir AVANT de générer

Aucune n'est affichée en synthèse aujourd'hui. Un bandeau récapitulatif devrait montrer :
- **Volume cible / pic** (ex. 60 km, +20 % vs actuel) et **volume de départ**.
- **Semaine la plus chargée** (date + km + charge) → « ta grosse semaine tombe le 14/09 ».
- **Progression hebdo moyenne** (%/sem) avec alerte si > ~10 %.
- **Nombre et placement des semaines de récupération**.
- **Kilométrage total du cycle** et **temps d'entraînement hebdo estimé**.
- **Indicateur de risque** (ACWR projeté, densité de séances qualité).
- **Cohérence objectif** : « chrono visé 3h30 → cohérent avec ton volume ? » (feu tricolore).
- **Marge calendaire** : semaines disponibles vs recommandées, et ce qu'on sacrifie si on comprime.

Tout ça, RedLab peut le calculer **immédiatement** à partir de ce qu'il a déjà.

---

## 7. Génération du plan — le workflow idéal

Aujourd'hui l'outil **s'arrête à la périodisation** : il donne des phases et un volume, mais **aucune séance**. C'est le **plus gros écart** avec les concurrents. Voici l'expérience cible après clic sur **« Générer le plan »** :

1. **Écran de validation (0,5 s)** : récap animé — « Marathon · 16 sem · pic 60 km · risque modéré ». Confirmation.
2. **Génération des séances** semaine par semaine, dérivées des phases + du volume + des allures du profil :
   - chaque semaine = EF / sortie longue / séance(s) qualité (seuil, VMA, allure spécifique) selon la phase, avec **volume et allures personnalisés** (via VMA/VC du profil).
   - respect des **délais de récupération** (déjà dans Connaissances : VMA 48 h, etc.).
3. **Vue calendrier** éditable (glisser-déposer une séance, la permuter, la marquer faite).
4. **Chaque séance justifiée** : « Séance spécifique 3×3 km à 4:59/km car J-28, allure marathon à ancrer. »
5. **Export** : .ICS calendrier, envoi montre (Garmin/Coros), PDF, et **partage fiche** (déjà en place).
6. **Boucle d'adaptation** : après coup, si l'athlète rate/ajoute une séance, le plan se **réajuste** (report de charge, pas de simple décalage).

Même une **v1 « séances-types par phase »** (sans IA) serait déjà un saut énorme.

---

## 8. Ergonomie — ce qui coince

- **Prend trop de place / passif** : l'histogramme pleine largeur alors qu'on ne peut rien y faire ; le bloc « Préparation idéale » depuis qu'il n'a plus d'action.
- **Trop de clics** : steppers de phase (5 clics pour +5), pas de saisie directe, pas de glisser.
- **Lisibilité** : le lien dates↔durée↔phases n'est pas expliqué à l'écran (mémoire de l'utilisateur sollicitée). La « course prépa » a un rôle flou.
- **Mal organisé** : questionnaire et ajustement sont deux îlots séparés ; on remonte/descend pour voir l'effet d'un changement.
- **À automatiser** : déduire « dont qualité » du niveau ; pré-remplir le volume/allures depuis le profil ; recalculer la reco en direct ; proposer les dates depuis la course sélectionnée.
- **Feedback manquant** : aucun état « plan modifié / non enregistré » ; le bouton « Ajouter au dashboard » est la seule sortie, peu explicite sur ce qu'il fait.

---

## 9. Fonctionnalités premium (25 idées)

1. **Justification en langage naturel** de chaque recommandation (le cœur « assistant »).
2. **Détection de plan irréaliste** : « 12 sem pour passer de 30 à 70 km = risque élevé ».
3. **Score de faisabilité du chrono** (à partir de VMA/VC + volume + temps dispo).
4. **Probabilité de réussite de l'objectif** (%) avec les 2-3 leviers pour l'augmenter.
5. **Projection ACWR / risque de blessure** semaine par semaine.
6. **Estimation de fatigue accumulée** (courbe Forme/Fatigue prédictive).
7. **Adaptation blessure** : régénère le plan autour d'une zone (remplace impacts par vélo/renfo).
8. **Replanification automatique** après séances ratées (report intelligent de charge).
9. **Historique intelligent** : apprend du volume réellement tenu vs prévu et recalibre.
10. **Prédicteur de performance** multi-distances (Riegel/VDOT/CV) intégré au plan.
11. **Détection de surentraînement** (dérive charge / ressenti / FC repos si dispo).
12. **Simulateur « et si »** : « et si je passe à 5 séances ? » → impact chiffré instantané.
13. **Optimiseur d'affûtage** (durée/réduction optimale selon profil, Bosquet paramétré).
14. **Placement auto des courses préparatoires** (semi à J-21 du marathon, etc.).
15. **Météo/terrain** : ajuste allures cibles (chaleur, dénivelé) — déjà des corrections FC dans Connaissances.
16. **Coach vocal / résumé hebdo** : « cette semaine : 2 qualité, grosse SL dimanche, attention récup ».
17. **Bibliothèque de séances liée aux phases** (déjà un onglet Bibliothèque → à connecter au plan).
18. **Comparaison de scénarios de plan** côte à côte (conservateur vs ambitieux).
19. **Bandeau de cohérence** temps réel objectif ↔ moyens.
20. **Nutrition périodisée** (glucides en course, recharge) — la carte existe déjà dans Connaissances.
21. **Renforcement/PPG** intégré au calendrier (interférences muscu/aérobie déjà documentées).
22. **Détection de monotonie** (indice de Foster) et alerte variété.
23. **Multi-athlètes** : générer et suivre plusieurs plans (RedLab a déjà « Athlètes »).
24. **Journal de ressenti (RPE)** post-séance qui nourrit l'adaptation.
25. **Mode « expliquer au client »** : version simplifiée du plan + pourquoi, à envoyer à l'athlète.

---

## 10. Benchmark

**TrainingPeaks** — *Le mieux : la quantification de charge.* PMC (CTL/ATL/TSB), TSS, plan annuel (ATP), builder de séances structurées, analytics profondes. **À reprendre :** la vue Forme/Fatigue et un équivalent de « charge » (volume × intensité), plus une synthèse chiffrée du cycle.

**Final Surge** — *Le mieux : la simplicité et la relation coach-athlète.* Calendrier épuré, communication, bibliothèque de séances, exécution fluide. **À reprendre :** la clarté du calendrier et le workflow coach → athlète sans friction.

**Nolio** — *Le mieux : le builder de séances et l'export montre.* Répétitions de blocs, métriques personnalisées (VMA, FC, RPE), zones auto par athlète, envoi Garmin/Coros/Suunto/Polar, marketplace de coachs. **À reprendre :** le builder de séances structurées et l'export vers montre — indispensables si RedLab veut générer de vraies séances.

**Campus Coach** — *Le mieux : l'adaptation temps réel grand public.* Plans course/trail 12+ sem qui s'ajustent aux données, méthode validée sur large base, communauté, envoi montre. **À reprendre :** la boucle d'adaptation après chaque séance et le ton « accompagnement ».

**V.O2 (RunSmart / Optimum)** — *Le mieux : automatisation adaptative et pédagogie VMA.* Entraînement auto, hautement adaptatif, méthodologie « olympique » validée, tests VMA pilotés, calcul d'allures. **À reprendre :** l'automatisation du plan et le pilotage par VMA/allures — RedLab a déjà la donnée VMA/VC, il faut la brancher sur des séances.

**Humango** — *Le mieux : l'IA adaptative continue.* Coach « Hugo » qui analyse séances, FC, sommeil, fatigue, agenda et **réajuste seul** (séance ratée, voyage, fatigue), multi-sport, intégrations wearables. **À reprendre :** l'adaptation continue et le fait que le plan est vivant, pas figé.

**Positionnement RedLab :** aucun de ces outils ne **justifie ses choix de façon transparente et pédagogique** comme un vrai coach le ferait. **C'est le créneau à occuper** : le plan qui explique *pourquoi*, sourcé (FFA, INSEP, Bosquet). RedLab a déjà la matière méthodologique (onglet Connaissances) — personne n'exploite ça aussi bien.

---

## Synthèse actionnable

### A. Les 20 améliorations les plus impactantes (par priorité)

1. **Justification en langage naturel** de la reco (semaines + phases). *Différenciateur n°1.*
2. **Générer de vraies séances** par semaine (v1 : séances-types par phase + allures du profil).
3. **Bandeau de synthèse pré-génération** (volume cible, semaine la plus dure, progression %, récup, risque).
4. **Toggle Volume / Charge / Fraîcheur** sur le graphe + bande ACWR.
5. **Timeline de phases à poignées** (glisser à total constant) remplaçant les steppers.
6. **Score de faisabilité + probabilité de réussite** du chrono.
7. **Détection de plan irréaliste** (progression, ACWR, écart volume).
8. **Parcours linéaire en 3 étapes** avec CTA unique « Générer le plan » sticky.
9. **Pré-remplissage depuis le profil** (VMA/VC, perf de référence, allures).
10. **Reco réactive** qui se réécrit à chaque changement d'entrée.
11. **Champ perf/test de référence** + **sortie longue actuelle** dans le questionnaire.
12. **Placement auto des courses préparatoires**.
13. **Vue calendrier éditable** (glisser-déposer les séances).
14. **Export .ICS + montre** (Garmin/Coros).
15. **Replanification après séance ratée/ajoutée**.
16. **Barres empilées par intensité** (EF/Seuil/VMA/Spé).
17. **Adaptation blessure** (remplacement d'impacts).
18. **Simulateur « et si »** (fréquence, durée, volume).
19. **Journal RPE + recalibrage** sur le tenu réel.
20. **Mode « expliquer au client »** (plan simplifié + pourquoi).

### B. Quick wins (< 2 h chacun)

- Réécrire « Préparation idéale » en **phrase justifiée** (données déjà disponibles).
- Ajouter le **bandeau de synthèse** (km total, pic, semaine la plus dure, % progression, nb récup) — pur calcul sur les données existantes.
- **Bande / badge ACWR** de risque sous le graphe.
- **Réordonner et regrouper** le questionnaire (Objectif / État / Contraintes) + replier « Contraintes ».
- Rendre « Dont qualité » **auto-déduit** et masquer le champ.
- Champ **« sortie longue actuelle »** + pré-remplissage volume/allures depuis le profil.
- **CTA unique sticky** « Générer le plan ».
- Clarifier le rôle de **« course prépa »** (libellé + tooltip + placement auto suggéré).
- **Saisie directe** du nombre de semaines par phase (input éditable) en plus des +/-.

### C. Nécessite un vrai développement

- **Moteur de génération de séances** (le gros morceau) + bibliothèque connectée aux phases et aux allures.
- **Modèle de charge/fraîcheur** (CTL/ATL/TSB simplifié) et projection ACWR.
- **Timeline de phases drag-and-drop**.
- **Boucle d'adaptation** (replanification sur exécution réelle, RPE, blessures).
- **Vue calendrier éditable** + exports montre/.ICS.
- **Scores prédictifs** (faisabilité, probabilité de réussite, risque de blessure).

---

## Maquette textuelle de la page idéale

```
┌───────────────────────────────────────────────────────────────┐
│  PLANIFICATION — Marathon · Run in Lyon · 04/10/2026 · J-74    │
├───────────────────────────────────────────────────────────────┤
│  ① PROFIL COUREUR                          [pré-rempli ✎]       │
│   Objectif : Marathon  ·  Chrono visé : 3h30 (fourchette 3h25–3h40)│
│   Volume actuel  [====●====] 45 km/sem                          │
│   Séances/sem    [===●=====] 4      Sortie longue  [==●===] 1h30 │
│   Contraintes ▸ (blessure ? jours dispo ?)         [replié]     │
├───────────────────────────────────────────────────────────────┤
│  ② RECOMMANDATION DE L'ASSISTANT                                │
│   « 16 semaines recommandées — volume moyen, marathon visé,     │
│     pas de course préparatoire. Base courte (tu es entraîné),   │
│     bloc spécifique long (l'allure marathon est le facteur clé).»│
│   Faisabilité 3h30 : ●●●○ Solide   Risque charge : ●●○ Modéré    │
│   Marge : 15 sem dispo / 16 conseillées                         │
│                                   [ Utiliser cette structure ]  │
├───────────────────────────────────────────────────────────────┤
│  ③ AJUSTER LA PRÉPA                                             │
│   Début 06/07 ───────────────────────────────► Course 04/10 🏁  │
│   [ Base ██ | Développement █████ | Spécifique ███████ | Aff ██ ]│
│        ↕ glisse les frontières (total constant) · +/- durée      │
├───────────────────────────────────────────────────────────────┤
│  SYNTHÈSE   Total 720 km · Pic 60 km (14/09) · +9 %/sem ·       │
│             3 sem récup · Fraîcheur max à J-3   [Volume|Charge|Forme]│
│   ▁▂▃▅▂▃▅▆▂▅▆█▃▂   (histogramme + courbe charge + bande ACWR)   │
├───────────────────────────────────────────────────────────────┤
│                    ▛▀▀ GÉNÉRER LE PLAN ▀▀▜   (sticky)           │
└───────────────────────────────────────────────────────────────┘
        → puis : calendrier de séances justifiées, éditable, exportable
```

**Principe directeur :** on ne remplit plus un formulaire, on **dialogue avec un assistant** qui, à chaque geste, recalcule, justifie et alerte. C'est ce fil rouge — *« montrer le raisonnement d'un coach »* — qui doit guider toutes les décisions de design.
