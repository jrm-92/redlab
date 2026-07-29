# Veille scientifique running — mise en place autonome

Objectif : recevoir automatiquement les nouvelles études (running, endurance, VMA/VO₂max,
vitesse critique, seuil, périodisation, marathon, affûtage…) **sans dépendre de Cowork**.
Ces canaux tournent sur les serveurs des fournisseurs, en continu.

---

## 1. Alerte e-mail PubMed — recommandé

1. Ouvre la recherche pré-remplie (lien plus bas).
2. Connecte-toi / crée un compte gratuit **My NCBI** (bouton *Log in*, en haut à droite).
3. Sous la barre de recherche, clique **« Create alert »**.
4. Choisis la fréquence (hebdomadaire conseillée), le format, le nombre d'articles → **Save**.

→ PubMed t'enverra les nouveautés par e-mail, automatiquement.

## 2. Flux RSS PubMed — sans compte

1. Même page de recherche pré-remplie.
2. Sous la barre, clique **« Create RSS »** → **Create RSS** → **Copy**.
3. Colle ce lien dans ton lecteur RSS (Feedly, Thunderbird, extension navigateur).

→ Notification à chaque nouvel article, aucune inscription.

## 3. Google Scholar — complément (thèses, prépublications)

1. Va sur https://scholar.google.com
2. Colle la version simplifiée de la requête (plus bas) dans la barre.
3. Menu ☰ → **Créer une alerte** (compte Google requis).

---

## Lien PubMed pré-rempli (à ouvrir)

https://pubmed.ncbi.nlm.nih.gov/?term=%28running%5Btiab%5D%20OR%20runners%5Btiab%5D%20OR%20marathon%5Btiab%5D%20OR%20%22endurance%20training%22%5Btiab%5D%29%20AND%20%28VO2max%5Btiab%5D%20OR%20%22critical%20speed%22%5Btiab%5D%20OR%20%22critical%20power%22%5Btiab%5D%20OR%20%22lactate%20threshold%22%5Btiab%5D%20OR%20%22running%20economy%22%5Btiab%5D%20OR%20periodization%5Btiab%5D%20OR%20%22interval%20training%22%5Btiab%5D%20OR%20%22training%20load%22%5Btiab%5D%20OR%20tapering%5Btiab%5D%20OR%20%22durability%22%5Btiab%5D%29

## Requête PubMed (texte brut, si tu veux la coller/modifier)

```
(running[tiab] OR runners[tiab] OR marathon[tiab] OR "endurance training"[tiab])
AND
(VO2max[tiab] OR "critical speed"[tiab] OR "critical power"[tiab] OR "lactate threshold"[tiab]
 OR "running economy"[tiab] OR periodization[tiab] OR "interval training"[tiab]
 OR "training load"[tiab] OR tapering[tiab] OR "durability"[tiab])
```

## Requête simplifiée (Google Scholar)

```
running OR marathon (VO2max OR "critical speed" OR "lactate threshold"
OR periodization OR "running economy" OR tapering)
```

---

## Notes

- `[tiab]` = terme dans le titre ou le résumé (cible les études pertinentes, limite le bruit).
- Ajuste les mots-clés selon tes besoins (ex. ajouter `strength training`, `heat`, `altitude`,
  `carbohydrate`, `female athletes`).
- La tâche planifiée Cowork (« veille-etudes-running-redlab ») reste utile en complément :
  elle peut, quand l'app tourne, rédiger un résumé prêt à coller dans l'onglet Connaissances.
  Les alertes ci-dessus, elles, ne s'arrêtent jamais.
