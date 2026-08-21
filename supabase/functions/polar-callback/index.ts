// ══════════════════════════════════════════════════════════════════════════
//  RedLab × Polar AccessLink — retour d'autorisation
//
//  Polar renvoie ici l'athlète après qu'il a accepté. On échange le code
//  contre un jeton, on enregistre l'utilisateur auprès d'AccessLink, puis on
//  range le lien. Cette fonction existe parce que RedLab est une page
//  statique : le Client Secret ne peut pas y figurer, tout le monde le
//  lirait. L'échange doit donc se faire côté serveur.
// ══════════════════════════════════════════════════════════════════════════

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Adresses AccessLink. Regroupées ici pour être vérifiables d'un coup d'œil
// contre la documentation Polar en cas de changement.
const TOKEN_URL = 'https://polarremote.com/v2/oauth2/token';
const USERS_URL = 'https://www.polaraccesslink.com/v3/users';

// Où l'athlète atterrit une fois l'opération finie.
const RETOUR = 'https://coach.reding-running.fr/polar.html';

const CLIENT_ID     = Deno.env.get('POLAR_CLIENT_ID')!;
const CLIENT_SECRET = Deno.env.get('POLAR_CLIENT_SECRET')!;
const SUPA_URL      = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY   = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

/** Renvoie l'athlète vers une page lisible plutôt que du JSON brut.
 *  Le détail est court et destiné à l'athlète : la réponse brute de Polar ou
 *  de PostgreSQL ne lui apprend rien et l'inquiète pour rien. Le diagnostic
 *  complet part dans les journaux de la fonction, où le coach peut le lire. */
function retour(etat: string, detail = ''): Response {
  const u = new URL(RETOUR);
  u.searchParams.set('etat', etat);
  if (detail) u.searchParams.set('detail', detail.slice(0, 200));
  return new Response(null, { status: 302, headers: { Location: u.toString() } });
}

Deno.serve(async (req) => {
  const url = new URL(req.url);

  // Polar signale un refus par ?error= plutôt que par un code d'erreur HTTP.
  const refus = url.searchParams.get('error');
  if (refus) return retour('refus', refus);

  const code  = url.searchParams.get('code');
  const state = url.searchParams.get('state');
  if (!code || !state) return retour('erreur', 'code ou state manquant');

  const sb = createClient(SUPA_URL, SERVICE_KEY, { auth: { persistSession: false } });

  // 1. À qui appartient cette autorisation ? Le state est à usage unique :
  //    on le consomme immédiatement pour qu'il ne puisse pas être rejoué.
  const { data: pending } = await sb
    .from('polar_pending').select('coach_id, athlete_key').eq('state', state).maybeSingle();
  if (!pending) return retour('erreur', 'demande inconnue ou déjà utilisée');
  await sb.from('polar_pending').delete().eq('state', state);

  // 2. Le code contre un jeton. Polar attend l'authentification du client en
  //    Basic, pas dans le corps de la requête.
  //
  //    Le redirect_uri est obligatoire ici (RFC 6749 §4.1.3) dès lors qu'il
  //    figurait dans la demande d'autorisation — c'est notre cas. Son absence
  //    fait répondre « invalid_grant », ce qui ressemble à s'y méprendre à un
  //    code périmé ou à un secret erroné. Il doit être identique au caractère
  //    près à celui déclaré chez Polar.
  const basic = btoa(`${CLIENT_ID}:${CLIENT_SECRET}`);
  const REDIRECT_URI = `${SUPA_URL}/functions/v1/polar-callback`;
  const tokRes = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Basic ${basic}`,
      'Content-Type': 'application/x-www-form-urlencoded',
      'Accept': 'application/json',
    },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: REDIRECT_URI,
    }),
  });
  if (!tokRes.ok) {
    const corps = await tokRes.text();
    // Tout le diagnostic va dans les journaux : c'est là que le coach le lira.
    console.error('polar token — statut', tokRes.status,
                  '| redirect_uri envoyé:', REDIRECT_URI,
                  '| réponse:', corps);
    return retour('erreur', "Polar a refusé l'autorisation. Redemande un lien à ton coach.");
  }
  const tok = await tokRes.json();
  const accessToken: string = tok.access_token;
  const polarUserId: number = Number(tok.x_user_id);
  if (!accessToken || !polarUserId) {
    console.error('polar token: réponse inattendue', JSON.stringify(tok));
    return retour('erreur', "Réponse inattendue de Polar. Préviens ton coach.");
  }

  // 3. Déclarer l'utilisateur à AccessLink. Sans cette étape, les appels de
  //    données répondent 403. Le member-id est NOTRE identifiant de l'athlète.
  const memberId = `${pending.coach_id}:${pending.athlete_key}`;
  const regRes = await fetch(USERS_URL, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: JSON.stringify({ 'member-id': memberId }),
  });
  // 409 = déjà enregistré : c'est le cas d'une reconnexion, pas une erreur.
  if (!regRes.ok && regRes.status !== 409) {
    console.error('polar users', regRes.status, await regRes.text());
    return retour('erreur', "Polar n'a pas accepté l'enregistrement. Préviens ton coach.");
  }

  // 4. Ranger. Le jeton part dans sa table à part, hors de portée du navigateur.
  const lien = { coach_id: pending.coach_id, athlete_key: pending.athlete_key,
                 polar_user_id: polarUserId, member_id: memberId, linked_at: new Date().toISOString() };
  const e1 = await sb.from('polar_links').upsert(lien, { onConflict: 'coach_id,athlete_key' });
  if (e1.error) { console.error('polar_links', e1.error); return retour('erreur', 'Enregistrement du lien impossible. Préviens ton coach.'); }

  const e2 = await sb.from('polar_tokens').upsert(
    { coach_id: pending.coach_id, athlete_key: pending.athlete_key,
      access_token: accessToken, updated_at: new Date().toISOString() },
    { onConflict: 'coach_id,athlete_key' });
  if (e2.error) { console.error('polar_tokens', e2.error); return retour('erreur', 'Enregistrement du lien impossible. Préviens ton coach.'); }

  return retour('ok');
});
