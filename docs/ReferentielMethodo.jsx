/*
 * ReferentielMethodo — référentiel méthodologique pour entraîneur
 * ---------------------------------------------------------------
 * Composant React autonome : React 18+, Tailwind CSS, lucide-react.
 *
 *   npm i lucide-react
 *   import ReferentielMethodo from './ReferentielMethodo';
 *
 * AVERTISSEMENT — RedLab (index.html) est une page unique en JavaScript
 * natif, sans build ni npm : ce fichier NE peut pas y être importé. Il est
 * ici comme référence, pour un éventuel portage React ou React Native.
 * L'écran réellement en service dans RedLab est `renderKnowledge()`, qui
 * applique la même ergonomie en vanilla.
 *
 * Parti pris d'ergonomie : le chiffre d'abord, le raisonnement ensuite.
 * Un entraîneur ouvre cet écran entre deux séries pour trancher une
 * question précise. Les valeurs sont donc en pastilles lisibles à un mètre,
 * et la thèse qui les justifie vit derrière un repli.
 */

import React, { useMemo, useState } from 'react';
import {
  Timer, BarChart3, Dumbbell, BookOpen,
  Search, X, ChevronRight, AlertTriangle, CheckCircle2,
} from 'lucide-react';

/* ══ DONNÉES ══
   Séparées du rendu : ce sont elles que l'entraîneur fait vivre. */

const ONGLETS = [
  { id: 'recup',  libelle: 'Récupération',      Icone: Timer },
  { id: 'zones',  libelle: 'Zones & intensités', Icone: BarChart3 },
  { id: 'renfo',  libelle: 'Renforcement',       Icone: Dumbbell },
  { id: 'fiches', libelle: 'Fiches & méthodes',  Icone: BookOpen },
];

/** ton : 'neutre' | 'ok' | 'alerte' | 'info' */
const REPRISE = [
  { cle: '10 km',             valeur: '3 jours',    ton: 'ok' },
  { cle: 'Semi-marathon',     valeur: '5 jours',    ton: 'ok' },
  { cle: 'Marathon / 100 km', valeur: '2 semaines', ton: 'alerte' },
  { cle: '24 h et plus',      valeur: '3 semaines', ton: 'alerte' },
];

const RECUP_SEANCE = [
  { cle: 'Footing / EF',       valeur: 'Aucun',   ton: 'ok',     note: 'Enchaînable, même quotidien' },
  { cle: 'Sortie longue',      valeur: '24–48 h', ton: 'neutre', note: 'Reconstitution du glycogène musculaire' },
  { cle: 'Seuil (SV1/SV2)',    valeur: '24–48 h', ton: 'neutre', note: 'Charge métabolique modérée' },
  { cle: 'VMA / VO₂max',       valeur: '~48 h',   ton: 'neutre', note: 'Avant une nouvelle séance dure' },
  { cle: 'Vitesse / sprint',   valeur: '48–72 h', ton: 'alerte', note: 'Stress neuromusculaire, le plus long à dissiper' },
];

const METABOLIQUE = [
  { cle: 'Dette d’oxygène',        valeur: '2 à 5 min',     note: 'Phase rapide (souffle)' },
  { cle: 'Créatine phosphate',     valeur: '3 à 5 min',     note: 'Réserves d’explosivité' },
  { cle: 'Lactate musculaire',     valeur: '~1 heure',      note: 'Accéléré par une récup active' },
  { cle: 'Lactate sanguin',        valeur: '1 à 2 heures',  note: 'Normal en 30-60 min si récup active' },
  { cle: 'Glycogène hépatique',    valeur: '6 à 12 heures', note: 'Réduit par un apport glucidique' },
  { cle: 'Glycogène musculaire',   valeur: '24 à 48 heures',note: 'Plusieurs jours sans apport glucidique élevé' },
];

const SPECIFIQUE = [
  { cle: '5 km',     intensite: '90-95 % → 87-92 %', volume: '3 à 5 km',  fractions: '600 m à 2000 m',    recup: '1′ à 3′' },
  { cle: '10 km',    intensite: '85-90 % → 80-85 %', volume: '4 à 6 km',  fractions: '1000 m à 3000 m',   recup: '1′ à 3′' },
  { cle: 'Semi',     intensite: '80-85 % → 75-80 %', volume: '6 à 10 km', fractions: '2000 m à 5000 m',   recup: '1′ à 3′' },
  { cle: 'Marathon', intensite: '75-80 % → 70-75 %', volume: '8 à 15 km', fractions: '3000 m à 10 000 m', recup: '1′30 à 5′' },
];

const DOMAINES = [
  { cle: 'Endurance fondamentale',   intensite: '50-65 %',   format: 'Course continue (footing, récup)',  temps: '45′ à 1h10',   recup: '—' },
  { cle: 'Endurance active (SV1)',   intensite: '70-85 %',   format: 'Fartlek moyen 3′-5′, long 5′-12′',  temps: '30′ à 1h',     recup: 'Continue / courte' },
  { cle: 'Seuil (SV2)',              intensite: '80-90 %',   format: '3×10′, 2×15′, 5×6′, X×400 m',       temps: '30′ à 40′',    recup: '30″ à 2′' },
  { cle: 'VMA extensive',            intensite: '95-100 %',  format: 'Fractions 600-1200 m',              temps: '15′ à 25′',    recup: '1/3 à 2/3 de l’effort' },
  { cle: 'VMA intensive',            intensite: '100-105 %', format: 'Fractions 100-500 m, 36″/36″',      temps: '12′ à 20′',    recup: '≤ temps d’effort' },
  { cle: 'Vitesse / neuromusculaire',intensite: 'Sprint',    format: '30-50 m (< 10″)',                   temps: 'Quelques rép.',recup: 'Complète (5-6′)' },
];

const RENFO = [
  { phase: 'Reprise / Général',   toutes: 'Conditionnement — poids de corps & pliométrie légère' },
  { phase: 'Foncier',             cols: ['Hypertrophie (+ explosivité en demi-fond)', 'Hypertrophie (semi) → explosivité (marathon)', 'Puissance-explosivité', 'Puissance-explosivité'] },
  { phase: 'Spécifique',          cols: ['Puissance-explosivité', 'Endurance de force + explosivité', 'Endurance de force + explosivité (excentrique ++)', 'Endurance de force + explosivité (excentrique ++)'] },
  { phase: 'Compétition',         cols: ['Explosivité, poids de corps & pliométrie', 'Poids de corps & pliométrie légère', 'Poids de corps & pliométrie légère', 'Poids de corps & pliométrie légère'] },
  { phase: 'Affûtage (2 sem.)',   cols: ['S-2 : explosivité + poids de corps · course → OFF', 'S-2 : poids de corps & pliométrie · course → OFF', 'S-2 : poids de corps & pliométrie · course → OFF', 'S-2 : poids de corps & pliométrie · course → OFF'] },
  { phase: 'Post-compétition',    toutes: 'OFF' },
];
const RENFO_COLS = ['Demi-fond · 10 km', 'Semi · Marathon', 'Trail', 'Ultra'];

const AFFUTAGE = [
  { cle: 'S-3', periode: 'J-21 → J-15', volume: '−20 à −30 %', note: '' },
  { cle: 'S-2', periode: 'J-14 → J-8',  volume: '−40 à −50 %', note: '' },
  { cle: 'S-1', periode: 'J-7 → J-0',   volume: '−60 à −70 %', note: 'Fraîcheur maximale, courts rappels d’allure' },
];

/* ══ PRIMITIVES ══ */

const TONS = {
  neutre: 'bg-slate-500/15 text-slate-300',
  ok:     'bg-emerald-500/15 text-emerald-400',
  alerte: 'bg-red-500/15 text-red-400',
  info:   'bg-sky-500/15 text-sky-400',
  accent: 'bg-orange-500/15 text-orange-400',
};

function Pastille({ children, ton = 'accent' }) {
  return (
    <span className={`inline-block whitespace-nowrap rounded-full px-2.5 py-0.5 text-xs font-extrabold ${TONS[ton] || TONS.accent}`}>
      {children}
    </span>
  );
}

function Tuile({ valeur, libelle, ton = 'accent' }) {
  const couleur = { ok: 'text-emerald-400', alerte: 'text-red-400', info: 'text-sky-400', accent: 'text-orange-400' }[ton];
  return (
    <div className="min-w-0 flex-1 basis-32 rounded-xl border border-white/10 bg-white/[0.02] px-3 py-3">
      <div className={`text-lg font-black leading-tight ${couleur}`}>{valeur}</div>
      <div className="mt-1 text-[10px] font-bold uppercase tracking-wide text-slate-400">{libelle}</div>
    </div>
  );
}

function Carte({ titre, sous, children }) {
  return (
    <section className="mb-3.5 rounded-2xl border border-white/10 bg-slate-800/40 p-5">
      <h2 className="text-[11px] font-extrabold uppercase tracking-[0.15em] text-slate-400">{titre}</h2>
      {sous && <p className="mt-1 text-xs text-slate-400">{sous}</p>}
      <div className="mt-3">{children}</div>
    </section>
  );
}

/** Repli. `<details>` natif : accessible au clavier et imprimable, sans état. */
function Repli({ titre, children }) {
  return (
    <details className="group mt-3 border-t border-white/10 pt-2.5">
      <summary className="flex cursor-pointer list-none items-center gap-1.5 py-0.5 text-[11px] font-extrabold uppercase tracking-wide text-slate-400 hover:text-orange-400 [&::-webkit-details-marker]:hidden">
        <ChevronRight className="h-3.5 w-3.5 transition-transform group-open:rotate-90" />
        {titre}
      </summary>
      <div className="py-2 text-xs leading-relaxed text-slate-400">{children}</div>
    </details>
  );
}

/**
 * Tableau qui devient une pile de fiches sous `md`.
 * Une seule source de vérité : chaque colonne porte son rendu, réutilisé
 * dans les deux mises en page. Pas de balisage dupliqué à maintenir.
 */
function TableauResponsive({ colonnes, lignes, cle }) {
  if (!lignes.length) return null;
  return (
    <>
      {/* ≥ md : tableau */}
      <div className="hidden md:block">
        <table className="w-full border-collapse">
          <thead>
            <tr>
              {colonnes.map((c) => (
                <th key={c.id} className="border-b border-white/10 px-2.5 py-2 text-left text-[9.5px] font-extrabold uppercase tracking-wide text-slate-400">
                  {c.titre}
                </th>
              ))}
            </tr>
          </thead>
          <tbody>
            {lignes.map((l, i) => (
              <tr key={cle ? l[cle] : i} className="border-b border-white/10 last:border-0">
                {colonnes.map((c, j) => (
                  <td key={c.id} className={`px-2.5 py-2.5 align-middle text-[12.5px] ${j === 0 ? 'font-extrabold text-slate-100' : 'text-slate-300'}`}>
                    {c.rendu(l)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      {/* < md : fiches */}
      <div className="space-y-2 md:hidden">
        {lignes.map((l, i) => (
          <article key={cle ? l[cle] : i} className="rounded-xl border border-white/10 bg-white/[0.02] px-3.5 py-3">
            <h3 className="border-b border-white/10 pb-1.5 text-sm font-black text-slate-100">{colonnes[0].rendu(l)}</h3>
            <dl className="mt-1.5 space-y-1">
              {colonnes.slice(1).map((c) => {
                const v = c.rendu(l);
                if (v === null || v === undefined || v === '') return null;
                return (
                  <div key={c.id} className="flex items-baseline gap-2.5">
                    <dt className="w-[40%] shrink-0 text-[9.5px] font-extrabold uppercase leading-snug tracking-wide text-slate-400">{c.titre}</dt>
                    <dd className="min-w-0 flex-1 text-[12.5px] text-slate-300">{v}</dd>
                  </div>
                );
              })}
            </dl>
          </article>
        ))}
      </div>
    </>
  );
}

/* ══ RECHERCHE ══
   Sans accent ni casse : personne ne pose un circonflexe sur « affûtage »
   depuis un clavier de téléphone, entre deux séries. */
const norm = (t) =>
  String(t ?? '').toLowerCase().normalize('NFD').replace(/[\u0300-\u036f]/g, '');

const filtrer = (lignes, q) =>
  !q ? lignes : lignes.filter((l) => norm(JSON.stringify(Object.values(l))).includes(q));

/* ══ COMPOSANT ══ */

export default function ReferentielMethodo() {
  const [onglet, setOnglet] = useState('recup');
  const [requete, setRequete] = useState('');

  const q = norm(requete).trim();
  const enRecherche = q.length >= 2;

  const jeux = useMemo(() => ({
    reprise:  filtrer(REPRISE, enRecherche ? q : ''),
    seance:   filtrer(RECUP_SEANCE, enRecherche ? q : ''),
    metab:    filtrer(METABOLIQUE, enRecherche ? q : ''),
    spe:      filtrer(SPECIFIQUE, enRecherche ? q : ''),
    domaines: filtrer(DOMAINES, enRecherche ? q : ''),
    renfo:    filtrer(RENFO.map((r) => ({ ...r, _t: r.toutes || (r.cols || []).join(' ') })), enRecherche ? q : ''),
    affutage: filtrer(AFFUTAGE, enRecherche ? q : ''),
  }), [q, enRecherche]);

  const total = Object.values(jeux).reduce((n, v) => n + v.length, 0);

  // En recherche on traverse les quatre onglets : le coach cherche une
  // réponse, pas une rubrique.
  const visible = (id) => enRecherche || onglet === id;

  return (
    <div className="min-h-screen bg-[#0f172a] px-4 py-5 text-slate-200 antialiased sm:px-6">
      <div className="mx-auto max-w-5xl">

        <header className="mb-4">
          <p className="text-[10px] font-extrabold uppercase tracking-[0.2em] text-orange-400">Outils</p>
          <h1 className="mt-1 text-2xl font-black tracking-tight text-white">Référentiel méthodologique</h1>
          <p className="mt-1.5 max-w-2xl text-sm leading-relaxed text-slate-400">
            Les repères pour trancher vite : délais de récupération, intensités par domaine,
            périodisation du renforcement, fiches de méthode.
          </p>
        </header>

        {/* Barre collante : recherche + onglets */}
        <div className="sticky top-0 z-20 -mx-4 border-b border-white/10 bg-[#0f172a] px-4 pb-3 pt-2.5 sm:-mx-6 sm:px-6">
          <div className="relative mb-2.5">
            <Search className="pointer-events-none absolute left-3.5 top-1/2 h-4 w-4 -translate-y-1/2 text-slate-500" />
            <input
              type="search"
              value={requete}
              onChange={(e) => setRequete(e.target.value)}
              placeholder="Chercher : 10 km, lactate, ACWR, affûtage…"
              aria-label="Rechercher dans le référentiel"
              className="w-full rounded-xl border-[1.5px] border-white/10 bg-white/5 py-2.5 pl-10 pr-10 text-sm font-semibold text-slate-100 outline-none placeholder:font-normal placeholder:text-slate-500 focus:border-orange-500"
            />
            {requete && (
              <button
                type="button"
                onClick={() => setRequete('')}
                aria-label="Effacer la recherche"
                className="absolute right-2 top-1/2 grid h-7 w-7 -translate-y-1/2 place-items-center rounded-lg text-slate-500 hover:bg-white/10 hover:text-slate-200"
              >
                <X className="h-4 w-4" />
              </button>
            )}
          </div>

          <div role="tablist" aria-label="Familles de repères" className="flex gap-1.5 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
            {ONGLETS.map(({ id, libelle, Icone }) => {
              const actif = onglet === id && !enRecherche;
              return (
                <button
                  key={id}
                  role="tab"
                  aria-selected={actif}
                  onClick={() => { setOnglet(id); setRequete(''); }}
                  className={`flex shrink-0 items-center gap-1.5 rounded-full border px-3.5 py-2 text-xs font-bold transition ${
                    actif
                      ? 'border-orange-500 bg-orange-500 text-white'
                      : 'border-white/10 text-slate-400 hover:border-slate-500 hover:text-slate-200'
                  }`}
                >
                  <Icone className="h-3.5 w-3.5" />
                  {libelle}
                </button>
              );
            })}
          </div>

          {enRecherche && (
            <p className="mt-2.5 px-0.5 text-xs text-slate-400">
              {total > 0
                ? `${total} résultat${total > 1 ? 's' : ''} dans tout le référentiel`
                : 'Aucun résultat'}
            </p>
          )}
        </div>

        <main className="pt-4">
          {/* ── RÉCUPÉRATION ── */}
          {visible('recup') && (
            <>
              {!!jeux.reprise.length && (
                <Carte titre="Reprise après compétition" sous="Combien de jours avant de relancer, selon la distance courue.">
                  <TableauResponsive
                    cle="cle"
                    lignes={jeux.reprise}
                    colonnes={[
                      { id: 'ep',  titre: 'Épreuve',         rendu: (l) => l.cle },
                      { id: 'val', titre: 'Repos conseillé', rendu: (l) => <Pastille ton={l.ton}>{l.valeur}</Pastille> },
                    ]}
                  />
                  <Repli titre="La règle 60/30/10">
                    <b className="text-slate-200">60 %</b> de la récupération se fait dans le premier tiers du temps,{' '}
                    <b className="text-slate-200">30 %</b> dans le deuxième :{' '}
                    <b className="text-slate-200">90 % est acquis aux deux tiers</b>. C’est ce qui justifie de
                    reprendre progressivement plutôt que d’attendre le délai complet à l’arrêt. Étirements
                    réintroduits en semaine 2 après un marathon. <i>Source : Livret CQP FFA.</i>
                  </Repli>
                </Carte>
              )}

              {!!jeux.seance.length && (
                <Carte titre="Récupération entre deux séances" sous="Délai à respecter avant la prochaine séance dure.">
                  <TableauResponsive
                    cle="cle"
                    lignes={jeux.seance}
                    colonnes={[
                      { id: 'type', titre: 'Type de séance', rendu: (l) => l.cle },
                      { id: 'val',  titre: 'Avant la prochaine séance dure', rendu: (l) => <Pastille ton={l.ton}>{l.valeur}</Pastille> },
                      { id: 'note', titre: 'Remarque', rendu: (l) => <span className="text-slate-500">{l.note}</span> },
                    ]}
                  />
                  <Repli titre="D’où viennent ces délais">
                    Dérivés des délais métaboliques FFA — le glycogène musculaire demande 24 à 48 h — et de la
                    hiérarchie des stress : <b className="text-slate-200">le neuromusculaire est le plus long à
                    dissiper</b>, d’où les 48 à 72 h après un travail de vitesse, alors même que la fatigue
                    ressentie a disparu.
                  </Repli>
                </Carte>
              )}

              {!!jeux.metab.length && (
                <Carte titre="Restauration métabolique" sous="Ce que le corps reconstitue après un effort maximal, et en combien de temps.">
                  <TableauResponsive
                    cle="cle"
                    lignes={jeux.metab}
                    colonnes={[
                      { id: 'sys',  titre: 'Système',  rendu: (l) => l.cle },
                      { id: 'val',  titre: 'Durée',    rendu: (l) => <Pastille ton="info">{l.valeur}</Pastille> },
                      { id: 'note', titre: 'Remarque', rendu: (l) => <span className="text-slate-500">{l.note}</span> },
                    ]}
                  />
                </Carte>
              )}
            </>
          )}

          {/* ── ZONES & INTENSITÉS ── */}
          {visible('zones') && (
            <>
              {!!jeux.spe.length && (
                <Carte titre="Séance spécifique" sous="Volume à l’allure de course dans la séance pivot — échauffement et récup exclus.">
                  <TableauResponsive
                    cle="cle"
                    lignes={jeux.spe}
                    colonnes={[
                      { id: 'ep',   titre: 'Épreuve',           rendu: (l) => l.cle },
                      { id: 'int',  titre: 'Intensité (% VMA)', rendu: (l) => <Pastille>{l.intensite}</Pastille> },
                      { id: 'vol',  titre: 'Volume global',     rendu: (l) => <Pastille ton="ok">{l.volume}</Pastille> },
                      { id: 'frac', titre: 'Fractions types',   rendu: (l) => l.fractions },
                      { id: 'rec',  titre: 'Récup',             rendu: (l) => l.recup },
                    ]}
                  />
                  <Repli titre="Comment faire progresser la séance">
                    Le « jeu subtil » : <b className="text-slate-200">allonger les fractions</b>, puis{' '}
                    <b className="text-slate-200">augmenter le volume</b>, puis{' '}
                    <b className="text-slate-200">réduire les récups</b> — un levier à la fois. Exemple sur un
                    semi en 1 h 30 : 3×2000 (r 1′30) → 5000 + 3000 + 2000 en récup dégressive.
                  </Repli>
                </Carte>
              )}

              {!!jeux.domaines.length && (
                <Carte titre="Temps de travail par domaine" sous="Durée de travail effectif dans la zone, par séance.">
                  <TableauResponsive
                    cle="cle"
                    lignes={jeux.domaines}
                    colonnes={[
                      { id: 'dom', titre: 'Domaine',                   rendu: (l) => l.cle },
                      { id: 'int', titre: 'Intensité (% VMA)',         rendu: (l) => <Pastille>{l.intensite}</Pastille> },
                      { id: 'fmt', titre: 'Format d’effort',           rendu: (l) => l.format },
                      { id: 'tps', titre: 'Temps de travail effectif', rendu: (l) => <Pastille ton="ok">{l.temps}</Pastille> },
                      { id: 'rec', titre: 'Récup',                     rendu: (l) => l.recup },
                    ]}
                  />
                </Carte>
              )}
            </>
          )}

          {/* ── RENFORCEMENT ── */}
          {visible('renfo') && !!jeux.renfo.length && (
            <Carte titre="Renforcement — périodisation par distance" sous="Type de travail de force selon la phase et la distance objectif.">
              <TableauResponsive
                cle="phase"
                lignes={jeux.renfo}
                colonnes={[
                  { id: 'ph', titre: 'Phase', rendu: (l) => l.phase },
                  ...RENFO_COLS.map((titre, i) => ({
                    id: `c${i}`,
                    titre,
                    rendu: (l) =>
                      l.toutes
                        ? (i === 0 ? <i className="text-slate-400">{l.toutes}</i> : null)
                        : l.cols[i],
                  })),
                ]}
              />
              <Repli titre="Pourquoi ça change avec la distance">
                Plus la distance est longue, plus <b className="text-slate-200">l’endurance de force</b> et{' '}
                <b className="text-slate-200">l’excentrique</b> dominent : c’est la capacité à encaisser des
                milliers d’impacts, pas à en produire un très puissant, qui décide de la fin de course.
              </Repli>
            </Carte>
          )}

          {/* ── FICHES & MÉTHODES ── */}
          {visible('fiches') && (
            <>
              <Carte titre="Marathon — repères de charge">
                <div className="flex flex-wrap gap-2">
                  <Tuile valeur="40 km/sem"     libelle="Minimum pour finir" />
                  <Tuile valeur="60–80 km/sem"  libelle="Cible amateur" ton="ok" />
                  <Tuile valeur="90–130 km/sem" libelle="Élite" />
                  <Tuile valeur="30–32 km"      libelle="Sortie longue max" />
                </div>
                <Repli titre="Sur quoi reposent ces repères">
                  La sortie longue plafonne à <b className="text-slate-200">30–32 km</b>, ou{' '}
                  <b className="text-slate-200">2 h 45 d’effort</b> : au-delà, le coût de récupération dépasse le
                  gain. La régularité et la sortie longue priment sur le pic ponctuel — même si la plus grosse
                  semaine reste un fort prédicteur de performance (<i>Vickers &amp; Vertosick, 2016</i>).
                </Repli>
              </Carte>

              <Carte titre="ACWR — le ratio de fatigue" sous="Rapport entre la charge de la semaine et la charge moyenne du mois.">
                <div className="mx-auto mb-4 max-w-xs text-center font-serif text-base text-slate-100">
                  ACWR ={' '}
                  <span className="ml-1.5 inline-block align-middle">
                    <span className="block border-b border-slate-300 px-2">Volume sur 7 jours</span>
                    <span className="block px-2">Moyenne volume sur 28 jours</span>
                  </span>
                </div>
                <div className="flex flex-wrap gap-2">
                  <div className="min-w-0 flex-1 basis-40 rounded-xl border border-emerald-500/25 bg-emerald-500/[0.07] px-3 py-3">
                    <div className="flex items-center gap-1.5 text-lg font-black text-emerald-400">
                      <CheckCircle2 className="h-4 w-4" /> 0,8 – 1,3
                    </div>
                    <div className="mt-1 text-[10px] font-bold uppercase tracking-wide text-slate-400">Zone sûre · progression optimale</div>
                  </div>
                  <div className="min-w-0 flex-1 basis-40 rounded-xl border border-red-500/25 bg-red-500/[0.07] px-3 py-3">
                    <div className="flex items-center gap-1.5 text-lg font-black text-red-400">
                      <AlertTriangle className="h-4 w-4" /> &gt; 1,5
                    </div>
                    <div className="mt-1 text-[10px] font-bold uppercase tracking-wide text-slate-400">Zone danger · risque décuplé</div>
                  </div>
                </div>
              </Carte>

              {!!jeux.affutage.length && (
                <Carte titre="Affûtage" sous="Réduction de volume par rapport à la plus grosse semaine.">
                  <TableauResponsive
                    cle="cle"
                    lignes={jeux.affutage}
                    colonnes={[
                      { id: 'sem', titre: 'Semaine', rendu: (l) => l.cle },
                      { id: 'per', titre: 'Période', rendu: (l) => l.periode },
                      { id: 'vol', titre: 'Volume',  rendu: (l) => <Pastille ton="alerte">{l.volume}</Pastille> },
                      { id: 'not', titre: 'Note',    rendu: (l) => <span className="text-slate-500">{l.note}</span> },
                    ]}
                  />
                  <Repli titre="Compétition test">
                    Un <b className="text-slate-200">semi-marathon à J-21</b>, avec des portions jouées à allure
                    marathon. Il valide l’allure, l’équipement et la nutrition assez tôt pour qu’il reste le
                    temps de corriger.
                  </Repli>
                </Carte>
              )}
            </>
          )}

          {enRecherche && total === 0 && (
            <p className="px-1 py-8 text-center text-sm leading-relaxed text-slate-400">
              Rien ne correspond à cette recherche.
              <br />
              Essaie « seuil », « glycogène », « affûtage », « 10 km »…
            </p>
          )}
        </main>
      </div>
    </div>
  );
}
