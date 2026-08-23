# REDING RUNNING — Refonte UI/UX

Basé sur le design system réel de l'app (tokens `:root`, classes `.mode-card`, `.zb`, `.mh-menu`, `.profile-hero`…). Le CSS proposé est *drop‑in* : mêmes noms de variables, tu remplaces les blocs concernés.

---

## 1. Diagnostic — écran par écran

**Fond & thème général.** La base bleu‑nuit est bonne, mais l'orange est utilisé partout (eyebrows, bordures de cartes, icônes, titres de section, badges, sliders). Résultat : plus rien ne ressort, l'orange perd sa valeur de signal. Règle à tenir : *l'orange = action + VMA, uniquement*. Tout le reste (titres, séparateurs, icônes neutres) passe en gris/bleu.

**Saisie (cartes de mode + VMA).** Les cartes de choix ont à la fois une bordure active **et** un faux radio (`.mode-check`) : redondance. Le radio doit disparaître au profit d'une seule affordance — bordure + halo. Le chiffre VMA manque d'un vrai composant KPI hiérarchisé (valeur énorme / unité discrète / méta en dessous).

**Dashboard — histogramme de charge.** Les labels de km sont posés juste au‑dessus des barres sans marge → ils se chevauchent avec le haut des barres et entre eux quand les valeurs sont proches. Il manque du *headroom* en haut de l'axe Y et un `padding` de layout. La légende (Base / Développement / Spécifique / Affûtage) est collée, à aérer.

**Dashboard — graphe de performance.** Prédiction et records sont deux natures différentes tracées de la même façon → illisible. Il faut séparer les *rôles visuels* : records = points pleins (verts, réalité mesurée), prédiction = ligne pointillée (orange/violet, modèle).

**Bibliothèque — cartes de séance.** Structure à clarifier : badge de zone en haut‑gauche, puis trois blocs nettement séparés — Échauffement (discret), Corps de séance (accentué), Retour au calme (discret). Aujourd'hui le corps ne ressort pas assez.

**Navigation mobile.** `.mh-btn { min-width:58px }` + labels longs → « Planifica… » tronqué. Solution : icône + label court fixe (Plan, Séances…), items en `flex:1` égaux, plus de troncature.

---

## 2. Palette recommandée (HEX + HSL)

Sémantique stricte : chaque couleur a **un** rôle.

### Fonds (échelle nocturne)

| Rôle | Variable | HEX | HSL |
|---|---|---|---|
| App (plus profond) | `--bg` | `#0F1729` | `hsl(222 47% 11%)` |
| Surface 1 | `--bg2` | `#16203A` | `hsl(222 45% 16%)` |
| Surface 2 | `--bg3` | `#1C2840` | `hsl(222 39% 18%)` |
| Carte | `--card` | `#212E4A` | `hsl(223 38% 21%)` |
| Carte survol / élevé | `--card2` | `#2A3852` | `hsl(222 32% 25%)` |
| Bordure | `--border` | `rgba(255,255,255,.07)` | — |
| Bordure forte | `--border2` | `rgba(255,255,255,.13)` | — |

### Texte

| Rôle | Variable | HEX | HSL |
|---|---|---|---|
| Principal | `--text` | `#F1F5F9` | `hsl(210 40% 96%)` |
| Secondaire | `--text2` | `#CBD5E1` | `hsl(213 27% 84%)` |
| Discret | `--muted` | `#94A3B8` | `hsl(215 20% 65%)` |
| Très discret | `--muted2` | `#64748B` | `hsl(215 16% 47%)` |

### Accents sémantiques (un rôle chacun)

| Rôle | Variable | HEX | HSL |
|---|---|---|---|
| **CTA + VMA** (orange) | `--accent` | `#FF6B1A` | `hsl(22 100% 55%)` |
| Orange survol | `--accent-600` | `#E55A0C` | `hsl(25 90% 47%)` |
| **Validation / records** (vert) | `--success` | `#10B981` | `hsl(160 84% 39%)` |
| Vert clair (texte/badge) | `--success-300` | `#34D399` | `hsl(158 64% 52%)` |
| **Métrique secondaire** (bleu) | `--info` | `#3B82F6` | `hsl(217 91% 60%)` |
| Bleu clair | `--info-300` | `#60A5FA` | `hsl(213 94% 68%)` |
| **Métrique tertiaire / prédiction** (violet) | `--tertiary` | `#8B5CF6` | `hsl(258 90% 66%)` |
| Violet clair | `--tertiary-300` | `#A78BFA` | `hsl(255 92% 76%)` |
| **Erreur / alerte** | `--danger` | `#EF4444` | `hsl(0 84% 60%)` |
| Rouge clair | `--danger-300` | `#F87171` | `hsl(0 91% 71%)` |

```css
:root{
  --bg:#0F1729; --bg2:#16203A; --bg3:#1C2840; --card:#212E4A; --card2:#2A3852;
  --border:rgba(255,255,255,.07); --border2:rgba(255,255,255,.13);
  --text:#F1F5F9; --text2:#CBD5E1; --muted:#94A3B8; --muted2:#64748B;
  --accent:#FF6B1A; --accent-600:#E55A0C; --accent-soft:rgba(255,107,26,.12);
  --success:#10B981; --success-300:#34D399; --success-soft:rgba(16,185,129,.13);
  --info:#3B82F6; --info-300:#60A5FA; --info-soft:rgba(59,130,246,.13);
  --tertiary:#8B5CF6; --tertiary-300:#A78BFA; --tertiary-soft:rgba(139,92,246,.13);
  --danger:#EF4444; --danger-300:#F87171;
  /* rayons & espacements rationalisés */
  --r-lg:16px; --r:12px; --r-sm:9px; --r-pill:999px;
  --sp-1:6px; --sp-2:10px; --sp-3:14px; --sp-4:20px; --sp-5:28px;
}
```

> Règle de rayons : cartes `--r-lg` (16), sous‑éléments/inputs `--r` (12), petits chips `--r-sm` (9), pilules `--r-pill`. Plus de valeurs intermédiaires.

---

## 3. Typographie unifiée

Une seule famille UI (**Manrope**). **Barlow Condensed** réservé aux gros nombres d'affichage (chronos, KPI) et aux eyebrows. On supprime les mélanges MAJUSCULES/Title‑Case : les MAJUSCULES ne servent plus qu'aux *eyebrows* et *labels* (11px). Les titres de carte passent en casse normale.

```css
:root{ --font:'Manrope','Inter',system-ui,sans-serif; --font-display:'Barlow Condensed',sans-serif; }

/* Échelle */
.t-display{ font:900 clamp(34px,6vw,52px)/1 var(--font-display); letter-spacing:-.5px; }
.t-h1     { font:800 20px/1.2 var(--font); letter-spacing:-.2px; color:var(--text); }
.t-card   { font:700 15px/1.3 var(--font); color:var(--text); }        /* titre de carte, casse normale */
.t-body   { font:500 14px/1.6 var(--font); color:var(--text2); }
.t-cap    { font:500 12px/1.5 var(--font); color:var(--muted); }
.t-eyebrow{ font:700 11px/1 var(--font); letter-spacing:1.6px; text-transform:uppercase; color:var(--muted2); } /* seul usage des majuscules */
```

---

## 4. Composants — code drop‑in (CSS standard)

### 4.1 Cartes de choix (mode) — halo, sans radio

Retire l'élément `.mode-check` du HTML. Une seule affordance : bordure + halo animé.

```css
.opt-cards{ display:grid; grid-template-columns:1fr 1fr; gap:12px; }
.opt-card{
  position:relative; text-align:left; cursor:pointer;
  background:var(--card); border:1.5px solid var(--border);
  border-radius:var(--r-lg); padding:18px; transition:border-color .18s, box-shadow .18s, background .18s;
  font-family:var(--font);
}
.opt-card:hover{ border-color:var(--border2); background:var(--card2); }
.opt-card.is-active{
  border-color:var(--accent);
  background:linear-gradient(180deg,var(--accent-soft),transparent 70%);
  box-shadow:0 0 0 3px rgba(255,107,26,.16), 0 8px 28px rgba(255,107,26,.10);
}
.opt-card__icon{
  width:34px;height:34px;border-radius:var(--r-sm);display:flex;align-items:center;justify-content:center;
  background:rgba(255,255,255,.05); border:1px solid var(--border); margin-bottom:12px; color:var(--muted);
  transition:color .18s,background .18s,border-color .18s;
}
.opt-card.is-active .opt-card__icon{ color:var(--accent); background:var(--accent-soft); border-color:rgba(255,107,26,.35); }
.opt-card__title{ display:block; font:800 14px/1.2 var(--font); color:var(--text); margin-bottom:4px; }
.opt-card__desc { display:block; font:500 12.5px/1.5 var(--font); color:var(--muted); }
/* coche discrète en haut-droite, remplace le radio */
.opt-card.is-active::after{
  content:''; position:absolute; top:14px; right:14px; width:18px; height:18px; border-radius:50%;
  background:var(--accent) url("data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='white' stroke-width='3' stroke-linecap='round' stroke-linejoin='round'><polyline points='20 6 9 17 4 12'/></svg>") center/11px no-repeat;
}
```

```html
<div class="opt-cards">
  <button class="opt-card is-active" aria-pressed="true">
    <span class="opt-card__icon"><!-- svg --></span>
    <span class="opt-card__title">Test terrain</span>
    <span class="opt-card__desc">Demi‑Cooper, VMA courte, 6 min…</span>
  </button>
  <button class="opt-card" aria-pressed="false">
    <span class="opt-card__icon"><!-- svg --></span>
    <span class="opt-card__title">Chronos course</span>
    <span class="opt-card__desc">5 km, 10 km, semi… estimation VMA</span>
  </button>
</div>
```

### 4.2 KPI VMA épuré

```css
.kpi{ display:flex; flex-direction:column; gap:4px; }
.kpi__label{ font:700 11px/1 var(--font); letter-spacing:1.6px; text-transform:uppercase; color:var(--muted2); }
.kpi__value{ font:900 clamp(40px,7vw,54px)/1 var(--font-display); color:var(--accent); letter-spacing:-1px; display:flex; align-items:baseline; gap:8px; }
.kpi__value small{ font:600 15px/1 var(--font); color:var(--muted); letter-spacing:0; }
.kpi__meta{ font:500 13px/1.5 var(--font); color:var(--text2); }
.kpi__meta b{ color:var(--text); font-weight:800; }
```

```html
<div class="kpi">
  <span class="kpi__label">VMA</span>
  <span class="kpi__value">18.5<small>km/h</small></span>
  <span class="kpi__meta">≈ <b>3'14</b>/km · VO₂max <b>64.8</b></span>
</div>
```

> KPI secondaires (VO₂max, seuil, FC) : même composant mais `--info`/`--tertiary` au lieu de `--accent`, et taille `t-display` réduite (28–32px). Ça hiérarchise : la VMA en orange domine, les dérivées en bleu/violet.

### 4.3 Badges de zone

Un composant, cinq variantes, casse normale (pas de MAJUSCULES criardes) :

```css
.badge{
  display:inline-flex; align-items:center; gap:5px;
  font:800 11.5px/1 var(--font); padding:4px 9px; border-radius:var(--r-pill);
  border:1px solid transparent; white-space:nowrap;
}
.badge--endurance{ color:var(--muted);        background:rgba(148,163,184,.14); border-color:rgba(148,163,184,.28); }
.badge--seuil    { color:var(--info-300);      background:var(--info-soft);      border-color:rgba(59,130,246,.30); }
.badge--vo2      { color:var(--accent);         background:var(--accent-soft);    border-color:rgba(255,107,26,.32); }
.badge--spe      { color:var(--tertiary-300);   background:var(--tertiary-soft);  border-color:rgba(139,92,246,.30); }
.badge--record   { color:var(--success-300);    background:var(--success-soft);   border-color:rgba(16,185,129,.30); }
```

> Mapping conseillé vs tes `.z1…z5` actuels : `z1`→endurance (slate), `z2`→seuil (bleu), `z4`→vo2 (orange), z « spé »→violet, records/PB→vert. L'orange ne sort plus que sur la VO2max, cohérent avec « orange = intensité/VMA ».

### 4.4 Carte de séance (Bibliothèque)

Badge en haut‑gauche, 3 blocs, corps accentué :

```css
.session-card{ background:var(--card); border:1px solid var(--border); border-radius:var(--r-lg); padding:18px; }
.session-card__head{ display:flex; align-items:center; gap:10px; margin-bottom:14px; }
.session-card__head h3{ font:700 16px/1.2 var(--font); color:var(--text); margin:0; }

.session-blocks{ list-style:none; margin:0; padding:0; display:flex; flex-direction:column; gap:8px; }
.sblock{ border-radius:var(--r); padding:11px 13px; border:1px solid var(--border); }
.sblock__t{ font:700 11px/1 var(--font); letter-spacing:1.2px; text-transform:uppercase; color:var(--muted2); margin-bottom:4px; display:block; }
.sblock__c{ font:600 13.5px/1.5 var(--font); color:var(--text2); }

/* Échauffement / retour au calme : discrets */
.sblock--warm, .sblock--cool{ background:rgba(255,255,255,.02); }
/* Corps de séance : accentué */
.sblock--core{
  background:linear-gradient(180deg,var(--accent-soft),transparent 120%);
  border-color:rgba(255,107,26,.28); border-left:3px solid var(--accent);
}
.sblock--core .sblock__t{ color:var(--accent); }
.sblock--core .sblock__c{ color:var(--text); font-weight:700; }
```

```html
<article class="session-card">
  <header class="session-card__head">
    <span class="badge badge--vo2">VO₂max</span>
    <h3>10 × 400 m</h3>
  </header>
  <ol class="session-blocks">
    <li class="sblock sblock--warm"><span class="sblock__t">Échauffement</span><span class="sblock__c">20 min footing + 4 lignes droites</span></li>
    <li class="sblock sblock--core"><span class="sblock__t">Corps de séance</span><span class="sblock__c">10 × 400 m @ 105 % VMA · récup 1'</span></li>
    <li class="sblock sblock--cool"><span class="sblock__t">Retour au calme</span><span class="sblock__c">10 min footing lent</span></li>
  </ol>
</article>
```

### 4.5 Bottom navigation (mobile) — icônes + labels courts

Plus de troncature : labels fixes courts, items égaux, ellipsis interdit.

```css
.tabbar{
  position:fixed; left:0; right:0; bottom:0; z-index:300; display:flex;
  padding:6px 4px calc(6px + env(safe-area-inset-bottom,0));
  background:rgba(15,23,41,.96); backdrop-filter:blur(12px); border-top:1px solid var(--border2);
}
.tab{
  flex:1 1 0; min-width:0; display:flex; flex-direction:column; align-items:center; gap:3px;
  padding:6px 2px; border-radius:12px; text-decoration:none; color:var(--muted2);
  font:700 10px/1 var(--font); transition:color .15s, background .15s;
}
.tab svg{ width:20px; height:20px; stroke:currentColor; fill:none; stroke-width:2; }
.tab span{ max-width:100%; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; } /* garde-fou */
.tab.is-active{ color:var(--accent); background:var(--accent-soft); }
```

```html
<nav class="tabbar">
  <a class="tab is-active"><!--svg--><span>Accueil</span></a>
  <a class="tab"><!--svg--><span>Saisie</span></a>
  <a class="tab"><!--svg--><span>Dashboard</span></a>
  <a class="tab"><!--svg--><span>Séances</span></a>
  <a class="tab"><!--svg--><span>Plan</span></a>
  <a class="tab"><!--svg--><span>Infos</span></a>
</nav>
```

> Labels courts recommandés : **Accueil, Saisie, Dashboard, Séances, Plan, Extrapo, Infos**. Si 7 items serrent trop sur petit écran, regroupe Extrapolation + Connaissances sous un « Outils » ou garde 6 items max visibles.

---

## 5. Charts (Chart.js)

### 5.1 Histogramme de charge — labels lisibles

Le chevauchement vient d'un manque de headroom + labels sans marge. Corrections :

```js
options:{
  layout:{ padding:{ top:26 } },              // espace pour les labels au-dessus des barres
  plugins:{
    legend:{ position:'top', align:'center',
      labels:{ boxWidth:10, boxHeight:10, padding:18, usePointStyle:true,
               font:{ family:'Manrope', size:12, weight:'600' }, color:'#94A3B8' } },
    datalabels:{                               // plugin chartjs-plugin-datalabels
      anchor:'end', align:'end', offset:4, clamp:true,
      color:'#CBD5E1', font:{ family:'Manrope', weight:'700', size:11 },
      formatter:v=> v+' km' }
  },
  scales:{
    y:{ grace:'12%', beginAtZero:true,         // 12% d'air en haut → plus de collision
        grid:{ color:'rgba(255,255,255,.05)' }, ticks:{ color:'#64748B' } },
    x:{ grid:{ display:false }, ticks:{ color:'#94A3B8', font:{ weight:'600' } } }
  },
  datasets:[{ maxBarThickness:34, borderRadius:6, borderSkipped:false }]
}
```

Couleurs de barres par phase (cohérence palette) : Base `#64748B`, Développement `#FB923C`, Spécifique `#34D399`, Affûtage `#A78BFA`. Si tu ne veux pas ajouter le plugin datalabels, remplace‑le par un `grace:'15%'` + labels de km affichés seulement 1 barre sur 2, ou dans le tooltip.

### 5.2 Graphe de performance — records vs prédiction

Sépare les rôles visuels dans un chart mixte :

```js
data:{ datasets:[
  { type:'scatter', label:'Records',    data:records,
    borderColor:'#10B981', backgroundColor:'#34D399',
    pointRadius:5, pointHoverRadius:7, pointStyle:'circle' },
  { type:'line',    label:'Prédiction', data:prediction,
    borderColor:'#FF6B1A', borderDash:[6,5], borderWidth:2,
    pointRadius:0, tension:.25, fill:false }
]},
options:{ plugins:{ legend:{ labels:{ usePointStyle:true } },
  tooltip:{ callbacks:{ label:c=> `${c.dataset.label} · ${c.formattedValue}` } } } }
```

Lecture immédiate : **points verts pleins = réel mesuré**, **ligne pointillée orange = modèle prédictif**. Le pointillé dit « estimation » sans légende à lire.

---

## 6. Ordre de mise en œuvre suggéré

1. Poser les variables `:root` (palette + rayons + espacements) — impact immédiat, faible risque.
2. Typo : introduire `.t-*` et purger les MAJUSCULES hors eyebrows/labels.
3. Composants un par un : `.opt-card` → `.kpi` → `.badge` → `.session-card` → `.tabbar`.
4. Charts en dernier (options isolées, testables séparément).

Chaque étape est indépendante : tu peux valider visuellement avant de passer à la suivante.
