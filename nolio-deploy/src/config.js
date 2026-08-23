// config.js — charge et valide config.json.
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');

function load() {
  const file = path.join(ROOT, 'config.json');
  if (!fs.existsSync(file)) {
    throw new Error('config.json introuvable. Copie config.example.json en config.json et remplis-le.');
  }
  const cfg = JSON.parse(fs.readFileSync(file, 'utf8'));

  const missing = ['clientId', 'clientSecret', 'redirectUri'].filter(
    (k) => !cfg[k] || String(cfg[k]).startsWith('TON_'),
  );
  if (missing.length) throw new Error('config.json incomplet : ' + missing.join(', '));

  return {
    clientId: cfg.clientId,
    clientSecret: cfg.clientSecret,
    redirectUri: cfg.redirectUri,
    sportId: cfg.sportId ?? 2, // 2 = Running (voir Sport map Nolio)
    vma: Number(cfg.vma) || 16,
    athleteId: cfg.athleteId || null,
    startDate: cfg.startDate || null,
    intervalDays: Number(cfg.intervalDays) || 1,
    workoutsFile: cfg.workoutsFile || 'data/workouts.json',
    // "absolute" = allures figées (VMA saisie) ; "percent" = %VMA, Nolio applique la VMA du profil athlète.
    paceMode: cfg.paceMode === 'percent' ? 'percent' : 'absolute',
    root: ROOT,
  };
}

export const config = load();
export const API_BASE = 'https://www.nolio.io/api';
