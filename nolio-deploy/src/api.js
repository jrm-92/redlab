// api.js — appels HTTP vers l'API Nolio, avec gestion d'erreurs et rate limit.
import { API_BASE } from './config.js';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// Les erreurs 4xx "métier" renvoient du texte brut ; 401/403/429 du JSON DRF.
async function readError(res) {
  const ct = res.headers.get('content-type') || '';
  if (ct.includes('application/json')) {
    const j = await res.json().catch(() => ({}));
    return j.detail || JSON.stringify(j);
  }
  return (await res.text().catch(() => '')) || res.statusText;
}

// POST JSON avec Bearer, retry auto sur 429 (respecte Retry-After).
export async function apiPost(pathname, body, accessToken, attempt = 0) {
  const res = await fetch(`${API_BASE}${pathname}`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });

  if (res.status === 429 && attempt < 5) {
    const wait = (Number(res.headers.get('retry-after')) || 2 ** attempt) * 1000;
    await sleep(wait);
    return apiPost(pathname, body, accessToken, attempt + 1);
  }

  if (!res.ok) {
    const detail = await readError(res);
    const e = new Error(`${res.status}: ${detail}`);
    e.status = res.status;
    e.detail = detail;
    throw e;
  }
  return res.json().catch(() => ({}));
}

export async function apiGet(pathname, accessToken) {
  const res = await fetch(`${API_BASE}${pathname}`, {
    headers: { Authorization: `Bearer ${accessToken}` },
  });
  if (!res.ok) throw new Error(`${res.status}: ${await readError(res)}`);
  return res.json();
}
