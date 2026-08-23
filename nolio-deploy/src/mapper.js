// mapper.js — convertit une séance RedLab (export JSON) en séance planifiée Nolio.
//
// Une séance RedLab = { title, category, objective, description, content,
//   tags, warm, cool, blocks[] }. Les allures sont en % VMA.
// Nolio attend un "structured_workout" : un tableau de steps (warmup / active /
//   rest / cooldown), avec des cibles d'allure exprimées en m/s.
// On convertit donc chaque % VMA en allure absolue à partir d'une VMA fournie.

// ── Conversion % VMA → allure Nolio (target_type "pace", unité m/s) ──
const mps = (vma, pct) => +((vma * pct) / 100 / 3.6).toFixed(2);

function paceTarget(pct, vma, percent) {
  const arr = Array.isArray(pct) ? pct : [pct];
  const lo = Math.min(...arr); // % le plus bas = le plus lent
  const hi = Math.max(...arr); // % le plus haut = le plus rapide
  if (percent) {
    // Mode %VMA : on envoie le pourcentage, Nolio applique la VMA de l'athlète.
    return { target_type: 'pace', step_percent_low: lo, step_percent_high: hi };
  }
  const t = { target_type: 'pace', target_value_max: mps(vma, hi) };
  if (lo !== hi) t.target_value_min = mps(vma, lo); // fourchette [min, max]
  return t;
}

const pctLabel = (pct) => (Array.isArray(pct) ? pct.join('–') : pct) + '% VMA';

// ── Parse une durée texte ("2'30", "90s", "3 min", "1'") en secondes ──
function parseTimeToSec(str) {
  if (!str) return null;
  const s = String(str);
  let m = s.match(/(\d+)\s*['’]\s*(\d{1,2})/); if (m) return +m[1] * 60 + +m[2];
  m = s.match(/(\d+)\s*['’]/);                 if (m) return +m[1] * 60;
  m = s.match(/(\d+)\s*(?:s|")/);              if (m) return +m[1];
  m = s.match(/(\d+)\s*min/);                  if (m) return +m[1] * 60;
  return null;
}

// ── Steps élémentaires ──
function durationFields(b) {
  if (b.d)   return { step_duration_type: 'distance', step_duration_value: Math.round(b.d) };
  if (b.m)   return { step_duration_type: 'duration', step_duration_value: Math.round(b.m * 60) };
  if (b.sec) return { step_duration_type: 'duration', step_duration_value: Math.round(b.sec) };
  return { step_duration_type: 'duration', step_duration_value: 60, open_duration: true };
}

function activeStep(b, vma, percent) {
  return { type: 'step', intensity_type: 'active', ...durationFields(b), ...paceTarget(b.pct, vma, percent), name: pctLabel(b.pct) };
}

function segStep(sg, vma, percent) {
  return {
    type: 'step', intensity_type: 'active',
    step_duration_type: 'distance', step_duration_value: Math.round(sg.d),
    ...paceTarget(sg.pct, vma, percent), name: sg.lbl || pctLabel(sg.pct),
  };
}

function restStep(rec, comment) {
  const sec = parseTimeToSec(rec);
  if (sec == null) return null;
  const s = { type: 'step', intensity_type: 'rest', step_duration_type: 'duration', step_duration_value: sec, target_type: 'no_target' };
  if (comment) s.comment = comment;
  return s;
}

// ── Séance complète → tableau de steps Nolio ──
export function toStructuredWorkout(w, vma, percent) {
  const steps = [];

  if (w.warm && w.warm !== '—') {
    steps.push({
      type: 'step', intensity_type: 'warmup', step_duration_type: 'duration',
      step_duration_value: parseTimeToSec(w.warm) || 1200, open_duration: true,
      target_type: 'no_target', comment: w.warm,
    });
  }

  for (const b of w.blocks || []) {
    // Steps "coeur" du bloc (une fraction, ou plusieurs segments d'allure)
    const core = b.segs ? b.segs.map((sg) => segStep(sg, vma, percent)) : [activeStep(b, vma, percent)];

    // Récup : soit un step "rest" chiffré, soit un commentaire si non chiffrable
    const rest = restStep(b.rec);
    if (rest) core.push(rest);
    else if (b.rec) core[core.length - 1].comment = 'récup ' + b.rec;

    if (b.sets && b.sets > 1) {
      // N séries de (r × coeur), avec récup entre séries
      const inner = b.r && b.r > 1 ? [{ type: 'repetition', value: b.r, steps: core }] : [...core];
      const rs = restStep(b.recSet, 'entre séries');
      if (rs) inner.push(rs);
      steps.push({ type: 'repetition', value: b.sets, steps: inner });
    } else if (b.r && b.r > 1) {
      steps.push({ type: 'repetition', value: b.r, steps: core });
    } else {
      steps.push(...core);
    }
  }

  if (w.cool && w.cool !== '—') {
    steps.push({
      type: 'step', intensity_type: 'cooldown', step_duration_type: 'duration',
      step_duration_value: parseTimeToSec(w.cool) || 600, open_duration: true,
      target_type: 'no_target', comment: w.cool,
    });
  }

  return steps;
}

// ── Estimation durée (s) et distance (km) pour l'affichage calendrier ──
function estimate(steps, vma) {
  const easy = mps(vma, 60); // allure des steps sans cible (échauffement, récup)
  let sec = 0, meters = 0;
  const walk = (arr, mult) => {
    for (const s of arr) {
      if (s.type === 'repetition') { walk(s.steps, mult * s.value); continue; }
      const speed = s.target_value_max || (s.target_value_min) || easy; // m/s
      if (s.step_duration_type === 'distance') {
        meters += s.step_duration_value * mult;
        sec += (s.step_duration_value / speed) * mult;
      } else {
        sec += s.step_duration_value * mult;
        meters += s.step_duration_value * speed * mult;
      }
    }
  };
  walk(steps, 1);
  return { durationSec: Math.round(sec), distanceKm: Math.round(meters / 1000) };
}

// ── Identifiant partenaire stable (clé de déduplication Nolio) ──
function hashId(str) {
  let h = 0;
  for (let i = 0; i < str.length; i++) h = (h * 31 + str.charCodeAt(i)) | 0;
  return Math.abs(h);
}

// ── Séance RedLab → payload /api/create/planned/training/ ──
export function toPlannedTraining(w, { vma, sportId, athleteId, date, percent = false }) {
  const structured_workout = toStructuredWorkout(w, vma, percent);
  const description = [w.objective, w.description, '', w.content].filter(Boolean).join('\n');

  const payload = {
    id_partner: hashId(w.title + '|' + (w.date || date || '')),
    sport_id: sportId,
    name: w.title,
    date_start: w.date || date, // date explicite dans le JSON, sinon planifiée par index.js
    description,
    structured_workout,
  };
  // On n'envoie PAS de distance : Nolio la calcule depuis les allures du workout.
  // En mode %VMA (percent), on ne fige rien : Nolio calcule tout depuis la VMA de
  // l'athlète, donc on n'envoie pas non plus de durée. En mode absolu, on garde
  // la durée estimée (utile pour la planification).
  if (!percent) {
    const { durationSec } = estimate(structured_workout, vma);
    if (durationSec) payload.duration = durationSec;
  }
  if (athleteId) payload.athlete_id = athleteId;
  return payload;
}

export const _internals = { parseTimeToSec, mps, paceTarget, hashId };
