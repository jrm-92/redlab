// server.js — petite interface locale pour déployer les séances vers Nolio.
// Sélection des séances + date par séance + choix de l'athlète.
// Le token/secret restent côté serveur ; le navigateur ne voit que localhost.
import http from 'http';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { config } from './src/config.js';
import { getAccessToken } from './src/auth.js';
import { apiGet, apiPost } from './src/api.js';
import { toPlannedTraining } from './src/mapper.js';
import { log } from './src/logger.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const PORT = 8730;

let workouts = JSON.parse(fs.readFileSync(path.join(ROOT, config.workoutsFile), 'utf8'));

const json = (res, code, data) => {
  res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(data));
};

async function readBody(req) {
  const chunks = [];
  for await (const c of req) chunks.push(c);
  return chunks.length ? JSON.parse(Buffer.concat(chunks).toString()) : {};
}

// Normalise la réponse /get/athletes/ (formes possibles variées).
function normAthletes(raw) {
  const arr = Array.isArray(raw) ? raw : raw?.athletes || raw?.results || [];
  return arr.map((a) => ({
    id: a.id ?? a.athlete_id ?? a.user_id ?? a.nolio_id,
    name: a.name || [a.first_name, a.last_name].filter(Boolean).join(' ') || a.email || `Athlète ${a.id ?? ''}`,
  })).filter((a) => a.id != null);
}

const server = http.createServer(async (req, res) => {
  try {
    // Autorise RedLab (page ouverte en fichier local, origine "null") à appeler l'outil.
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
    if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

    const url = new URL(req.url, `http://localhost:${PORT}`);

    if (req.method === 'POST' && url.pathname === '/api/import') {
      const body = await readBody(req);
      const arr = Array.isArray(body) ? body : body.sessions;
      if (!Array.isArray(arr) || !arr.length) return json(res, 400, { error: 'format invalide' });
      fs.writeFileSync(path.join(ROOT, config.workoutsFile), JSON.stringify(arr, null, 2));
      workouts = arr;
      log.ok(`Import depuis RedLab : ${arr.length} séances.`);
      return json(res, 200, { count: arr.length });
    }

    if (req.method === 'GET' && url.pathname === '/') {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(fs.readFileSync(path.join(ROOT, 'public', 'index.html')));
      return;
    }

    if (req.method === 'GET' && url.pathname === '/api/config') {
      return json(res, 200, { vma: config.vma, count: workouts.length, sportId: config.sportId, paceMode: config.paceMode });
    }

    if (req.method === 'GET' && url.pathname === '/api/sessions') {
      return json(res, 200, workouts.map((w, i) => ({
        index: i, title: w.title, category: w.category, objective: w.objective,
        description: w.description || '', content: w.content || '',
        phase: w.phase || null, order: w.order || null, date: w.date || null,
      })));
    }

    if (req.method === 'GET' && url.pathname === '/api/athletes') {
      try {
        const token = await getAccessToken();
        const raw = await apiGet('/get/athletes/?limit=300', token);
        return json(res, 200, normAthletes(raw));
      } catch (e) {
        log.skip('athletes indisponibles: ' + e.message);
        return json(res, 200, []); // pas d'athlètes / pas coach → uniquement "Moi"
      }
    }

    if (req.method === 'POST' && url.pathname === '/api/deploy') {
      const { athleteId, vma, items } = await readBody(req);
      const token = await getAccessToken();
      const useVma = Number(vma) || config.vma;
      const results = [];
      for (const it of items || []) {
        const w = workouts[it.index];
        if (!w) { results.push({ title: `#${it.index}`, ok: false, error: 'introuvable' }); continue; }
        const payload = toPlannedTraining(w, {
          vma: useVma, sportId: config.sportId,
          athleteId: athleteId || null, date: it.date,
          percent: config.paceMode === 'percent',
        });
        try {
          await apiPost('/create/planned/training/', payload, token);
          results.push({ title: w.title, date: it.date, ok: true });
          log.ok(`${it.date} — ${w.title}`);
        } catch (e) {
          const already = e.status === 400 && /exist/i.test(e.detail || '');
          results.push({ title: w.title, date: it.date, ok: false, skipped: already, error: e.message });
          (already ? log.skip : log.err)(`${it.date} — ${w.title}${already ? ' (déjà présente)' : ' → ' + e.message}`);
        }
        await new Promise((r) => setTimeout(r, 250));
      }
      return json(res, 200, { results });
    }

    res.writeHead(404); res.end('Not found');
  } catch (e) {
    json(res, 500, { error: e.message });
  }
});

server.listen(PORT, () => {
  const link = `http://localhost:${PORT}/`;
  log.info(`Interface de déploiement Nolio : ${link}`);
  log.info('Ouvre ce lien dans ton navigateur. (Ctrl+C pour arrêter.)');
  // Tentative d'ouverture auto (Windows/Mac/Linux)
  const cmd = process.platform === 'win32' ? 'start ""' : process.platform === 'darwin' ? 'open' : 'xdg-open';
  import('child_process').then(({ exec }) => exec(`${cmd} ${link}`)).catch(() => {});
});
