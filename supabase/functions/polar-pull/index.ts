// ══════════════════════════════════════════════════════════════════════════
//  RedLab × Polar AccessLink — récupération des séances réalisées
//
//  Appelée par le navigateur du coach, avec son jeton Supabase. Elle parcourt
//  les athlètes reliés, demande à Polar ce qu'il a de neuf et range les
//  séances dans polar_exercises.
//
//  Le point délicat tient à AccessLink : les séances sont livrées dans une
//  « transaction » qui les DÉTRUIT une fois validée. Polar ne les proposera
//  plus jamais. L'ordre des opérations n'est donc pas négociable —
//  on enregistre d'abord, on valide ensuite. Si l'enregistrement échoue, on
//  ne valide pas : la transaction expirera d'elle-même et les mêmes séances
//  reviendront au prochain passage.
// ══════════════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const API = 'https://www.polaraccesslink.com/v3';

const SUPA_URL    = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY    = Deno.env.get('SUPABASE_ANON_KEY')!;

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status, headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/** Polar exprime les durées en ISO 8601 (« PT1H10M30.5S »). */
function dureeEnSecondes(iso: unknown): number | null {
  if (typeof iso !== 'string') return null;
  const m = iso.match(/^PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?$/);
  if (!m) return null;
  const s = (+(m[1] ?? 0)) * 3600 + (+(m[2] ?? 0)) * 60 + (+(m[3] ?? 0));
  return Number.isFinite(s) ? Math.round(s) : null;
}

/** L'heure de début est locale ; le décalage est fourni à part, en minutes. */
function debutUtc(ex: Record<string, unknown>): string | null {
  const brut = ex['start-time'];
  if (typeof brut !== 'string') return null;
  const dec = ex['start-time-utc-offset'];
  const suffixe = typeof dec === 'number'
    ? (dec >= 0 ? '+' : '-') +
      String(Math.floor(Math.abs(dec) / 60)).padStart(2, '0') + ':' +
      String(Math.abs(dec) % 60).padStart(2, '0')
    : 'Z';
  const t = Date.parse(brut + suffixe);
  return Number.isFinite(t) ? new Date(t).toISOString() : null;
}

function entier(v: unknown): number | null {
  const n = Number(v);
  return Number.isFinite(n) ? Math.round(n) : null;
}

/** Un athlète, une transaction. Renvoie ce qui a été importé, ou le motif
 *  du renoncement — jamais une exception : un athlète en échec ne doit pas
 *  empêcher les autres d'être traités. */
async function tirerPourAthlete(
  sb: ReturnType<typeof createClient>,
  coachId: string,
  lien: { athlete_key: string; polar_user_id: number },
): Promise<{ cle: string; importees: number; motif?: string }> {
  const cle = lien.athlete_key;

  const { data: tok } = await sb.from('polar_tokens')
    .select('access_token').eq('coach_id', coachId).eq('athlete_key', cle).maybeSingle();
  if (!tok?.access_token) return { cle, importees: 0, motif: 'aucun jeton — le lien est à refaire' };

  const entetes = { 'Authorization': `Bearer ${tok.access_token}`, 'Accept': 'application/json' };
  const uid = lien.polar_user_id;

  // 1. Ouvrir une transaction. 204 = rien de neuf, ce qui est le cas courant.
  const ouv = await fetch(`${API}/users/${uid}/exercise-transactions`, { method: 'POST', headers: entetes });
  if (ouv.status === 204) return { cle, importees: 0 };
  if (ouv.status === 401 || ouv.status === 403) {
    return { cle, importees: 0, motif: "Polar refuse l'accès — l'athlète a probablement révoqué l'autorisation" };
  }
  if (!ouv.ok) {
    console.error('polar-pull ouverture', cle, ouv.status, await ouv.text());
    return { cle, importees: 0, motif: `Polar a répondu ${ouv.status} à l'ouverture` };
  }
  const { 'transaction-id': tid } = await ouv.json();
  if (!tid) return { cle, importees: 0, motif: 'transaction sans identifiant' };

  const base = `${API}/users/${uid}/exercise-transactions/${tid}`;

  // 2. La liste des séances de la transaction.
  const liste = await fetch(base, { headers: entetes });
  if (liste.status === 204) {
    await fetch(base, { method: 'PUT', headers: entetes });   // transaction vide : on la referme
    return { cle, importees: 0 };
  }
  if (!liste.ok) {
    console.error('polar-pull liste', cle, liste.status, await liste.text());
    return { cle, importees: 0, motif: `Polar a répondu ${liste.status} à la liste` };
  }
  const uris: string[] = (await liste.json())?.exercises ?? [];
  if (!uris.length) {
    await fetch(base, { method: 'PUT', headers: entetes });
    return { cle, importees: 0 };
  }

  // 3. Chaque séance, une par une.
  const lignes: Record<string, unknown>[] = [];
  for (const uri of uris) {
    const r = await fetch(uri, { headers: entetes });
    if (!r.ok) {
      // Une seule séance illisible suffit à renoncer : valider maintenant la
      // ferait disparaître définitivement. On laisse la transaction expirer.
      console.error('polar-pull séance', cle, uri, r.status, await r.text());
      return { cle, importees: 0, motif: 'une séance est illisible — nouvelle tentative au prochain passage' };
    }
    const ex = await r.json();
    const fc = ex['heart-rate'] ?? {};
    lignes.push({
      coach_id: coachId,
      athlete_key: cle,
      polar_id: String(ex.id ?? uri.split('/').pop()),
      start_time: debutUtc(ex),
      duration_s: dureeEnSecondes(ex.duration),
      distance_m: Number.isFinite(Number(ex.distance)) ? Number(ex.distance) : null,
      hr_avg: entier(fc.average),
      hr_max: entier(fc.maximum),
      sport: ex['detailed-sport-info'] ?? ex.sport ?? null,
      calories: entier(ex.calories),
      detail: ex,
      imported_at: new Date().toISOString(),
    });
  }

  // 4. Enregistrer AVANT de valider. C'est tout l'enjeu de cette fonction.
  const ins = await sb.from('polar_exercises')
    .upsert(lignes, { onConflict: 'coach_id,athlete_key,polar_id' });
  if (ins.error) {
    console.error('polar-pull enregistrement', cle, ins.error);
    return { cle, importees: 0, motif: "enregistrement impossible — les séances restent chez Polar" };
  }

  // 5. Valider : Polar peut oublier ces séances, nous les avons.
  const fin = await fetch(base, { method: 'PUT', headers: entetes });
  if (!fin.ok) {
    // Les séances sont en base ; la transaction non validée les reproposera.
    // La clé primaire fera retomber les doublons sur les mêmes lignes.
    console.error('polar-pull validation', cle, fin.status, await fin.text());
  }
  return { cle, importees: lignes.length };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return json({ erreur: 'méthode non autorisée' }, 405);

  // Qui appelle ? Le jeton du coach, vérifié par Supabase — c'est lui qui
  // délimite les athlètes visibles, jamais un identifiant passé dans le corps.
  const jwt = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!jwt) return json({ erreur: 'authentification requise' }, 401);
  const sbUser = createClient(SUPA_URL, ANON_KEY, { auth: { persistSession: false } });
  const { data: { user }, error: errUser } = await sbUser.auth.getUser(jwt);
  if (errUser || !user) return json({ erreur: 'session invalide' }, 401);

  let cible: string | null = null;
  try { cible = (await req.json())?.athlete_key ?? null; } catch { /* corps vide : tous les athlètes */ }

  const sb = createClient(SUPA_URL, SERVICE_KEY, { auth: { persistSession: false } });
  let q = sb.from('polar_links').select('athlete_key, polar_user_id').eq('coach_id', user.id);
  if (cible) q = q.eq('athlete_key', String(cible));
  const { data: liens, error: errLiens } = await q;
  if (errLiens) { console.error('polar-pull liens', errLiens); return json({ erreur: 'lecture des liens impossible' }, 500); }
  if (!liens?.length) return json({ athletes: [], total: 0 });

  const resultats = [];
  for (const lien of liens) {
    resultats.push(await tirerPourAthlete(sb, user.id, lien as { athlete_key: string; polar_user_id: number }));
  }
  return json({ athletes: resultats, total: resultats.reduce((n, r) => n + r.importees, 0) });
});
