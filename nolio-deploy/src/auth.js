// auth.js — OAuth 2.0 (authorization code) contre l'API Nolio.
// Stocke les tokens dans .tokens.json (à ne pas partager). Le refresh_token est
// ROTÉ à chaque refresh : on stocke toujours le nouveau.
import http from 'http';
import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { config, API_BASE } from './config.js';
import { log } from './logger.js';

const TOKEN_FILE = path.join(config.root, '.tokens.json');
const basicAuth = 'Basic ' + Buffer.from(`${config.clientId}:${config.clientSecret}`).toString('base64');

const readTokens = () => (fs.existsSync(TOKEN_FILE) ? JSON.parse(fs.readFileSync(TOKEN_FILE, 'utf8')) : null);
function saveTokens(t) {
  const data = { ...t, expires_at: Date.now() + (t.expires_in ?? 86400) * 1000 };
  fs.writeFileSync(TOKEN_FILE, JSON.stringify(data, null, 2));
  return data;
}

async function exchange(params) {
  const res = await fetch(`${API_BASE}/token/`, {
    method: 'POST',
    headers: { Authorization: basicAuth, 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams(params),
  });
  if (!res.ok) throw new Error(`token ${res.status}: ${await res.text()}`);
  return res.json();
}

// Flow interactif : ouvre l'URL d'autorisation, capte le code sur un serveur local.
async function authorize() {
  const state = crypto.randomBytes(24).toString('hex');
  const url =
    `${API_BASE}/authorize/?` +
    new URLSearchParams({
      client_id: config.clientId,
      response_type: 'code',
      redirect_uri: config.redirectUri,
      state,
    });

  const { port, pathname } = new URL(config.redirectUri);

  const code = await new Promise((resolve, reject) => {
    const server = http.createServer((req, res) => {
      const u = new URL(req.url, config.redirectUri);
      if (u.pathname !== pathname) { res.writeHead(404); res.end(); return; }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      if (u.searchParams.get('state') !== state) {
        res.end('<h2>État invalide (CSRF). Recommence.</h2>');
        server.close(); reject(new Error('state mismatch')); return;
      }
      const c = u.searchParams.get('code');
      res.end('<h2>Autorisation reçue. Tu peux fermer cet onglet et revenir au terminal.</h2>');
      server.close(); resolve(c);
    });
    server.listen(Number(port) || 80, () => {
      log.info('Ouvre cette URL dans ton navigateur (connecté à Nolio) pour autoriser :');
      log.info('  ' + url);
    });
  });

  const tokens = await exchange({ grant_type: 'authorization_code', code, redirect_uri: config.redirectUri });
  log.ok('Autorisation OK, tokens enregistrés.');
  return saveTokens(tokens);
}

async function refresh(refresh_token) {
  const tokens = await exchange({ grant_type: 'refresh_token', refresh_token });
  return saveTokens(tokens); // stocke le NOUVEAU refresh_token (rotation)
}

// Renvoie un access_token valide (refresh ou flow complet si nécessaire).
export async function getAccessToken({ forceAuth = false } = {}) {
  let t = readTokens();
  if (forceAuth || !t) return (await authorize()).access_token;
  if (t.expires_at && t.expires_at > Date.now() + 60_000) return t.access_token;
  try {
    log.info('Token expiré, refresh…');
    return (await refresh(t.refresh_token)).access_token;
  } catch {
    log.skip('Refresh échoué (révoqué ?), nouvelle autorisation.');
    return (await authorize()).access_token;
  }
}
