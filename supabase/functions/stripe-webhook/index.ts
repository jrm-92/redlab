// ═══════════════════════════════════════════════════════════════════════
//  Fonction Edge Supabase : « stripe-webhook »  (sans dépendance externe)
//  Reçoit les paiements Stripe → vérifie la signature → enregistre
//  l'inscription (nom, email) et met à jour le compteur de LA séance payée.
//
//  À déployer dans Supabase → Edge Functions → nom « stripe-webhook ».
//  IMPORTANT : « Verify JWT » doit rester DÉSACTIVÉ (Stripe n'envoie pas
//  de jeton Supabase). Un seul secret à définir : STRIPE_WEBHOOK_SECRET.
//
//  ── Comment on sait quelle séance a été payée ──────────────────
//  RIEN à saisir dans Stripe. La page courir-en-groupe.html ajoute
//  elle-même l'identifiant à l'URL du lien de paiement au moment de
//  l'ouvrir (paramètre client_reference_id, voir avecReference()), et
//  Stripe le recopie dans la session de paiement. Une séance créée
//  aujourd'hui est donc comptée correctement aujourd'hui.
//
//  Cet identifiant désigne soit une séance, soit une préparation — il ne
//  dit pas laquelle des deux. On cherche donc dans « sessions », puis
//  dans « preparations ». Les métadonnées session_id / preparation_id
//  restent acceptées en secours, si un lien devait un jour être réglé à
//  la main.
//
//  Sans identifiant reconnu, le paiement est quand même enregistré — nom
//  compris — mais aucun compteur ne bouge. Mieux vaut un compteur
//  immobile qu'un compteur faux. La ligne apparaît alors dans la table
//  « inscriptions » avec ses deux colonnes de rattachement vides.
//
//  ⚠ Les identifiants doivent rester en lettres, chiffres, tiret et
//    souligné : Stripe n'accepte rien d'autre dans client_reference_id,
//    et la page remplace le reste par un tiret.
//
//  ── Ce que cette version corrige ─────────────────────────────────────
//  1. Le compteur. L'ancienne version appelait incr_inscrits_evenement,
//     qui incrémente TOUTES les séances portant le même nom d'événement.
//     Les cinq séances du Vésinet montaient ensemble à chaque paiement.
//     On appelle maintenant incr_inscrits_session(id) : une ligne, une.
//  2. Les préparations. incr_inscrits_pack() écrivait dans la table des
//     séances, alors que le bloc d'une préparation affiche le compteur
//     de la table des préparations : une vente ne se voyait pas.
//  3. Les remboursements. Un remboursement n'arrive pas sous la même
//     forme qu'un encaissement et ne porte pas les métadonnées du lien.
//     L'ancienne version n'y trouvait donc jamais d'événement et
//     décrémentait les préparations, quelle que soit la séance
//     remboursée. On retrouve désormais l'inscription par son numéro de
//     paiement, et on décrémente ce qu'elle dit.
//  4. Les noms. Ils arrivaient à chaque paiement et étaient jetés.
// ═══════════════════════════════════════════════════════════════════════

const WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

// Appel de l'API REST Supabase avec la clé service (fournie automatiquement).
function rest(path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`${SUPABASE_URL}/rest/v1/${path}`, {
    ...init,
    headers: {
      "apikey": SERVICE_KEY,
      "Authorization": `Bearer ${SERVICE_KEY}`,
      "Content-Type": "application/json",
      ...(init.headers ?? {}),
    },
  });
}

async function rpc(fn: string, args: Record<string, unknown>): Promise<void> {
  const r = await rest(`rpc/${fn}`, { method: "POST", body: JSON.stringify(args) });
  if (!r.ok) console.error(`rpc ${fn} a échoué :`, r.status, await r.text());
}

// Première ligne d'une requête REST, ou null.
async function premiere(path: string): Promise<any> {
  const r = await rest(path);
  if (!r.ok) {
    console.error("lecture échouée :", path, r.status, await r.text());
    return null;
  }
  const lignes = await r.json();
  return Array.isArray(lignes) && lignes.length ? lignes[0] : null;
}

// À quoi se rattache ce paiement, et à quelle date.
//
// L'identifiant arrive par client_reference_id, que la page a ajouté à
// l'URL du lien de paiement. Il désigne une séance OU une préparation :
// on cherche dans l'une, puis dans l'autre.
//
// La date retenue est celle de la séance, ou celle de la DERNIÈRE séance
// d'une préparation — c'est à partir de là que courent les six mois de
// conservation.
type Rattachement = {
  sessionId: string | null;
  preparationId: string | null;
  date: string | null;
};

async function rattachement(obj: any): Promise<Rattachement> {
  const meta = obj.metadata ?? {};
  const ref: string | null =
    obj.client_reference_id || meta.session_id || meta.preparation_id || null;
  const vide: Rattachement = { sessionId: null, preparationId: null, date: null };
  if (!ref) return vide;

  const s = await premiere(`sessions?id=eq.${encodeURIComponent(ref)}&select=date&limit=1`);
  if (s) return { sessionId: ref, preparationId: null, date: s.date ?? null };

  const p = await premiere(`preparations?id=eq.${encodeURIComponent(ref)}&select=id&limit=1`);
  if (p) {
    const d = await premiere(
      `preparation_seances?preparation_id=eq.${encodeURIComponent(ref)}` +
        `&select=date&order=date.desc&limit=1`,
    );
    return { sessionId: null, preparationId: ref, date: d?.date ?? null };
  }

  console.error("identifiant de paiement inconnu en base :", ref);
  return vide;
}

// Vérifie la signature Stripe (HMAC-SHA256) sans dépendre du SDK Stripe.
async function verifierStripe(rawBody: string, sigHeader: string): Promise<any> {
  const parts: Record<string, string> = {};
  for (const p of sigHeader.split(",")) {
    const [k, v] = p.split("=");
    if (k && v) parts[k.trim()] = v.trim();
  }
  const t = parts["t"];
  const v1 = parts["v1"];
  if (!t || !v1) throw new Error("En-tête de signature invalide");

  const signedPayload = `${t}.${rawBody}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(WEBHOOK_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sigBuf = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signedPayload));
  const expected = [...new Uint8Array(sigBuf)].map((b) => b.toString(16).padStart(2, "0")).join("");

  if (expected.length !== v1.length) throw new Error("Signature non concordante");
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ v1.charCodeAt(i);
  if (diff !== 0) throw new Error("Signature non concordante");

  return JSON.parse(rawBody);
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const sig = req.headers.get("stripe-signature") ?? "";
  const rawBody = await req.text();

  let event: any;
  try {
    event = await verifierStripe(rawBody, sig);
  } catch (e) {
    return new Response("Signature refusée : " + (e as Error).message, { status: 400 });
  }

  // Anti-doublon : on n'enregistre chaque événement Stripe qu'une fois
  const ins = await rest("stripe_events", { method: "POST", body: JSON.stringify({ id: event.id }) });
  if (ins.status === 409) return new Response("déjà traité", { status: 200 });
  if (!ins.ok) return new Response("Erreur base : " + (await ins.text()), { status: 500 });

  const obj = event.data?.object ?? {};

  // ── Paiement réussi ──────────────────────────────────────────────────
  //  Seul checkout.session.completed est écouté : c'est le seul moment
  //  où Stripe garantit à la fois la place payée et l'identité du payeur.
  if (event.type === "checkout.session.completed") {
    const ou = await rattachement(obj);
    const sessionId = ou.sessionId;
    const preparationId = ou.preparationId;
    const client = obj.customer_details ?? {};

    // La ligne est posée avant le compteur : si le compteur échoue, le nom
    // est déjà là. La clé primaire est l'identifiant de la session de
    // paiement, donc un renvoi de Stripe ne crée pas de doublon.
    const ligne = {
      id: obj.id,
      payment_intent: obj.payment_intent ?? null,
      session_id: sessionId,
      preparation_id: preparationId,
      date_seance: ou.date,
      nom: client.name ?? null,
      email: client.email ?? null,
      telephone: client.phone ?? null,
      montant_centimes: obj.amount_total ?? null,
      devise: obj.currency ?? null,
    };
    const rIns = await rest("inscriptions", {
      method: "POST",
      headers: { "Prefer": "resolution=merge-duplicates" },
      body: JSON.stringify(ligne),
    });
    if (!rIns.ok) console.error("inscription non enregistrée :", rIns.status, await rIns.text());

    if (sessionId) await rpc("incr_inscrits_session", { p_id: sessionId });
    else if (preparationId) await rpc("incr_inscrits_preparation", { p_id: preparationId });
    else console.error("paiement sans rattachement, compteur inchangé :", obj.id);
  } // ── Remboursement TOTAL : la place se rouvre ─────────────────────────
  //  Le remboursement ne porte pas les métadonnées du lien. On retrouve
  //  l'inscription par son numéro de paiement, et c'est elle qui dit quel
  //  compteur décrémenter.
  else if (event.type === "charge.refunded") {
    const rembTotal = (obj.amount_refunded ?? 0) >= (obj.amount ?? 0);
    const pi: string | null = obj.payment_intent ?? null;
    if (rembTotal && pi) {
      const insc = await premiere(
        `inscriptions?payment_intent=eq.${encodeURIComponent(pi)}` +
          `&select=id,session_id,preparation_id,annule_le&limit=1`,
      );
      if (!insc) {
        console.error("remboursement sans inscription connue :", pi);
      } else if (insc.annule_le) {
        // déjà annulée : ne pas décrémenter deux fois
      } else {
        const rUpd = await rest(`inscriptions?id=eq.${encodeURIComponent(insc.id)}`, {
          method: "PATCH",
          body: JSON.stringify({ annule_le: new Date().toISOString() }),
        });
        if (!rUpd.ok) console.error("annulation non enregistrée :", rUpd.status, await rUpd.text());

        if (insc.session_id) await rpc("decr_inscrits_session", { p_id: insc.session_id });
        else if (insc.preparation_id) await rpc("decr_inscrits_preparation", { p_id: insc.preparation_id });
      }
    }
  }

  return new Response("ok", { status: 200 });
});
