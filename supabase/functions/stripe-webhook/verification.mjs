// ════════════════════════════════════════════════════════════════════════
//  Vérification de la fonction stripe-webhook, hors ligne.
//
//  Elle ne touche ni Stripe ni Supabase : une fausse base répond à la
//  place de PostgREST et note tout ce qu'on lui demande, et les
//  événements Stripe sont signés avec un secret de test.
//
//  Pour la lancer, depuis ce dossier :
//      npx tsc index.ts --target ES2022 --lib ES2022,DOM --module esnext --outDir out
//      node verification.mjs
//
//  Neuf scénarios : séance payée, événement renvoyé deux fois,
//  préparation payée, lien mal réglé, remboursement total, remboursement
//  partiel, remboursement renvoyé deux fois, signature invalide, requête
//  GET. Chacun doit afficher ✔.
// ════════════════════════════════════════════════════════════════════════

import { readFileSync } from 'node:fs';

const SECRET = 'whsec_test_abc';
const BASE = 'https://exemple.supabase.co';

// ── Fausse base : un PostgREST minimal, qui note tout ce qu'on lui demande
let journal = [];
let inscriptions = new Map();      // id -> ligne
let evenementsVus = new Set();
const SESSIONS = { TEST1: { date: '2026-10-17' }, TEST4: { date: '2026-11-14' } };
const PREP_SEANCES = { P1: ['2026-11-07', '2027-01-30'] };

function json(body, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
}

globalThis.fetch = async (url, init = {}) => {
  const u = new URL(url);
  const chemin = u.pathname.replace('/rest/v1/', '');
  const methode = (init.method || 'GET').toUpperCase();
  const corps = init.body ? JSON.parse(init.body) : null;
  journal.push({ methode, chemin, requete: u.search, corps });

  if (chemin === 'stripe_events' && methode === 'POST') {
    if (evenementsVus.has(corps.id)) return new Response('conflict', { status: 409 });
    evenementsVus.add(corps.id);
    return new Response('', { status: 201 });
  }
  if (chemin === 'sessions' && methode === 'GET') {
    const id = decodeURIComponent((u.searchParams.get('id') || '').replace('eq.', ''));
    return json(SESSIONS[id] ? [{ date: SESSIONS[id].date }] : []);
  }
  if (chemin === 'preparation_seances' && methode === 'GET') {
    const id = decodeURIComponent((u.searchParams.get('preparation_id') || '').replace('eq.', ''));
    const d = PREP_SEANCES[id];
    if (!d) return json([]);
    const tri = [...d].sort().reverse();       // order=date.desc
    return json([{ date: tri[0] }]);
  }
  if (chemin === 'inscriptions' && methode === 'POST') {
    inscriptions.set(corps.id, { ...corps, annule_le: null });
    return new Response('', { status: 201 });
  }
  if (chemin === 'inscriptions' && methode === 'GET') {
    const pi = decodeURIComponent((u.searchParams.get('payment_intent') || '').replace('eq.', ''));
    const trouve = [...inscriptions.values()].filter(l => l.payment_intent === pi);
    return json(trouve.map(l => ({ id: l.id, session_id: l.session_id, preparation_id: l.preparation_id, annule_le: l.annule_le })));
  }
  if (chemin === 'inscriptions' && methode === 'PATCH') {
    const id = decodeURIComponent((u.searchParams.get('id') || '').replace('eq.', ''));
    if (inscriptions.has(id)) Object.assign(inscriptions.get(id), corps);
    return new Response(null, { status: 204 });
  }
  if (chemin.startsWith('rpc/')) return new Response(null, { status: 204 });
  return new Response('non géré : ' + chemin, { status: 500 });
};

// ── Faux Deno
let handler = null;
globalThis.Deno = {
  env: { get: (k) => ({ STRIPE_WEBHOOK_SECRET: SECRET, SUPABASE_URL: BASE, SUPABASE_SERVICE_ROLE_KEY: 'sk_service' })[k] },
  serve: (h) => { handler = h; },
};

const src = readFileSync('./out/f.js', 'utf8');
new Function(src)();   // exécute le fichier transpilé, qui appelle Deno.serve

async function signer(corps) {
  const t = Math.floor(Date.now() / 1000);
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(SECRET),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const buf = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(`${t}.${corps}`));
  const v1 = [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');
  return `t=${t},v1=${v1}`;
}

async function envoyer(evenement, opts = {}) {
  const corps = JSON.stringify(evenement);
  const sig = opts.mauvaiseSignature ? 't=1,v1=00' : await signer(corps);
  journal = [];
  const methode = opts.methode || 'POST';
  const init = { method: methode, headers: { 'stripe-signature': sig } };
  if (methode !== 'GET' && methode !== 'HEAD') init.body = corps;
  const rep = await handler(new Request(BASE + '/stripe-webhook', init));
  return { statut: rep.status, texte: await rep.text(), journal: [...journal] };
}

const rpcs = (j) => j.filter(x => x.chemin.startsWith('rpc/')).map(x => x.chemin.replace('rpc/', '') + '(' + JSON.stringify(x.corps) + ')');
const ok = (c, m) => console.log((c ? '  ✔ ' : '  ✘ ÉCHEC ') + m);

console.log('\n── 1. Séance à l\'unité payée ───────────────────────────────');
let r = await envoyer({
  id: 'evt_1', type: 'checkout.session.completed',
  data: { object: { id: 'cs_1', payment_intent: 'pi_1', amount_total: 1300, currency: 'eur',
    metadata: { session_id: 'TEST1' },
    customer_details: { name: 'Marie Dupont', email: 'marie@exemple.fr', phone: null } } },
});
console.log('  réponse :', r.statut, r.texte, '| appels :', rpcs(r.journal).join(', ') || 'aucun');
let l = inscriptions.get('cs_1');
console.log('  ligne écrite :', JSON.stringify(l));
ok(r.statut === 200, 'répond 200');
ok(l && l.nom === 'Marie Dupont' && l.email === 'marie@exemple.fr', 'nom et email enregistrés');
ok(l && l.session_id === 'TEST1' && l.preparation_id === null, 'rattachée à TEST1, pas à une préparation');
ok(l && l.date_seance === '2026-10-17', 'date de la séance recopiée');
ok(l && l.payment_intent === 'pi_1', 'numéro de paiement gardé');
ok(rpcs(r.journal).join() === 'incr_inscrits_session({"p_id":"TEST1"})', 'une seule séance incrémentée');

console.log('\n── 2. Le même événement renvoyé par Stripe ──────────────────');
r = await envoyer({ id: 'evt_1', type: 'checkout.session.completed', data: { object: { id: 'cs_1' } } });
console.log('  réponse :', r.statut, r.texte);
ok(r.texte === 'déjà traité' && rpcs(r.journal).length === 0, 'ignoré, aucun compteur touché');

console.log('\n── 3. Préparation payée ─────────────────────────────────────');
r = await envoyer({
  id: 'evt_2', type: 'checkout.session.completed',
  data: { object: { id: 'cs_2', payment_intent: 'pi_2', amount_total: 12000, currency: 'eur',
    metadata: { preparation_id: 'P1' },
    customer_details: { name: 'Paul Martin', email: 'paul@exemple.fr', phone: '0612345678' } } },
});
l = inscriptions.get('cs_2');
console.log('  ligne écrite :', JSON.stringify(l));
console.log('  appels :', rpcs(r.journal).join(', '));
ok(l.preparation_id === 'P1' && l.session_id === null, 'rattachée à la préparation');
ok(l.date_seance === '2027-01-30', 'date de la DERNIÈRE séance de la préparation');
ok(l.telephone === '0612345678', 'téléphone gardé quand Stripe le fournit');
ok(rpcs(r.journal).join() === 'incr_inscrits_preparation({"p_id":"P1"})', 'compteur de la préparation');

console.log('\n── 4. Lien de paiement mal réglé (aucune étiquette) ─────────');
r = await envoyer({
  id: 'evt_3', type: 'checkout.session.completed',
  data: { object: { id: 'cs_3', payment_intent: 'pi_3', amount_total: 1300, currency: 'eur',
    metadata: {}, customer_details: { name: 'Léa Bernard', email: 'lea@exemple.fr' } } },
});
l = inscriptions.get('cs_3');
console.log('  ligne écrite :', JSON.stringify(l));
ok(l.nom === 'Léa Bernard', 'le nom est quand même enregistré');
ok(l.session_id === null && l.preparation_id === null, 'colonnes vides : le lien est à corriger');
ok(rpcs(r.journal).length === 0, 'aucun compteur touché');

console.log('\n── 5. Remboursement total de la séance de Marie ─────────────');
r = await envoyer({
  id: 'evt_4', type: 'charge.refunded',
  data: { object: { id: 'ch_1', payment_intent: 'pi_1', amount: 1300, amount_refunded: 1300 } },
});
l = inscriptions.get('cs_1');
console.log('  ligne après :', JSON.stringify(l));
console.log('  appels :', rpcs(r.journal).join(', '));
ok(!!l.annule_le, 'la ligne est marquée annulée, pas effacée');
ok(l.nom === 'Marie Dupont', 'le nom reste');
ok(rpcs(r.journal).join() === 'decr_inscrits_session({"p_id":"TEST1"})', 'la BONNE séance est décrémentée');

console.log('\n── 6. Remboursement PARTIEL ─────────────────────────────────');
r = await envoyer({
  id: 'evt_5', type: 'charge.refunded',
  data: { object: { id: 'ch_2', payment_intent: 'pi_2', amount: 12000, amount_refunded: 3000 } },
});
ok(rpcs(r.journal).length === 0 && !inscriptions.get('cs_2').annule_le, 'rien n\'est annulé, la place reste prise');

console.log('\n── 7. Remboursement renvoyé deux fois ───────────────────────');
r = await envoyer({
  id: 'evt_6', type: 'charge.refunded',
  data: { object: { id: 'ch_1', payment_intent: 'pi_1', amount: 1300, amount_refunded: 1300 } },
});
ok(rpcs(r.journal).length === 0, 'déjà annulée : pas de second décompte');

console.log('\n── 8. Signature invalide ────────────────────────────────────');
r = await envoyer({ id: 'evt_7', type: 'checkout.session.completed', data: { object: { id: 'cs_9' } } },
  { mauvaiseSignature: true });
console.log('  réponse :', r.statut, r.texte);
ok(r.statut === 400 && r.journal.length === 0, 'refusée avant d\'atteindre la base');

console.log('\n── 9. Requête GET (quelqu\'un ouvre l\'adresse) ───────────────');
r = await envoyer({ id: 'evt_8' }, { methode: 'GET' });
ok(r.statut === 405, 'refusée');

console.log('\n── État final de la table inscriptions ──────────────────────');
for (const [id, v] of inscriptions) {
  console.log('  ' + id + ' | ' + (v.session_id || v.preparation_id || '(non rattachée)') +
    ' | ' + v.date_seance + ' | ' + v.nom + ' | ' + (v.annule_le ? 'ANNULÉE' : 'active'));
}
