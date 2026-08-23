// index.js — déploie les séances RedLab vers le calendrier Nolio.
//
//   node index.js --auth        → autorisation OAuth (une fois)
//   node index.js --dry-run     → mappe et écrit out/payloads.json SANS rien envoyer
//   node index.js               → crée les séances planifiées dans Nolio
//   node index.js --limit=5     → limite le nombre de séances traitées
import fs from 'fs';
import path from 'path';
import { config } from './src/config.js';
import { log } from './src/logger.js';
import { getAccessToken } from './src/auth.js';
import { apiPost } from './src/api.js';
import { toPlannedTraining } from './src/mapper.js';

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const limit = Number((args.find((a) => a.startsWith('--limit=')) || '').split('=')[1]) || Infinity;

const addDays = (iso, n) => {
  const d = new Date(iso + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
};

async function main() {
  if (has('--auth')) { await getAccessToken({ forceAuth: true }); return; }

  const file = path.join(config.root, config.workoutsFile);
  if (!fs.existsSync(file)) throw new Error(`Fichier séances introuvable : ${config.workoutsFile}. Exporte-le depuis RedLab (bouton "Exporter (JSON)").`);
  let workouts = JSON.parse(fs.readFileSync(file, 'utf8'));
  if (limit !== Infinity) workouts = workouts.slice(0, limit);

  const dry = has('--dry-run');
  if (!dry && !config.startDate) throw new Error('startDate manquant dans config.json (date de la 1re séance).');

  // Construit les payloads (une date par séance : startDate + i × intervalDays).
  const payloads = workouts.map((w, i) =>
    toPlannedTraining(w, {
      vma: config.vma,
      sportId: config.sportId,
      athleteId: config.athleteId,
      percent: config.paceMode === 'percent',
      date: w.date || (config.startDate ? addDays(config.startDate, i * config.intervalDays) : null),
    }),
  );

  if (dry) {
    const out = path.join(config.root, 'out');
    fs.mkdirSync(out, { recursive: true });
    fs.writeFileSync(path.join(out, 'payloads.json'), JSON.stringify(payloads, null, 2));
    log.ok(`Dry-run : ${payloads.length} séances mappées → out/payloads.json (aucun envoi).`);
    return;
  }

  const token = await getAccessToken();
  let created = 0, skipped = 0, failed = 0;

  for (const p of payloads) {
    try {
      await apiPost('/create/planned/training/', p, token);
      created++;
      log.ok(`${p.date_start} — ${p.name}`);
    } catch (e) {
      if (e.status === 400 && /exist/i.test(e.detail || '')) {
        skipped++;
        log.skip(`${p.date_start} — ${p.name} (déjà présente)`);
      } else {
        failed++;
        log.err(`${p.name} → ${e.message}`);
      }
    }
    await new Promise((r) => setTimeout(r, 300)); // respiration entre requêtes
  }

  log.info('──────────────────────────────');
  log.info(`Terminé : ${created} créées · ${skipped} ignorées · ${failed} en erreur`);
  log.info(`Journal : ${log.file}`);
}

main().catch((e) => { log.err(e.message); process.exit(1); });
