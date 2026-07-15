// ============================================================================
// WashInvoice — Edge Function: enviar-push
// ----------------------------------------------------------------------------
// Envia notificações FCM para os dispositivos registados de um admin.
//
// Autenticação: header Authorization: Bearer <EDGE_INVOKE_SECRET>. A anon key
// e JWTs de utilizadores normais NÃO passam — só quem tem o secret partilhado
// (o trigger DB e curls do Cesar).
//
// Payload esperado:
//   { title: string, body: string, data?: object, user_id?: uuid }
// Se user_id não vier, usa ADMIN_USER_ID (fallback abaixo).
//
// Secrets necessários no Supabase:
//   FCM_SERVICE_ACCOUNT_JSON — o JSON completo da chave da service account.
//   EDGE_INVOKE_SECRET       — string aleatória partilhada.
// Auto-injectados pelo runtime: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY.
// ============================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

// Admin do Control (Cesar). Hardcoded para não obrigar a mais um secret.
const ADMIN_USER_ID_FALLBACK = "9e1bfae1-b932-430d-ad41-055cf894ff7f";

/** JSON com Content-Type. */
function json(corpo: unknown, status: number): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** base64url sem padding. */
function b64url(input: Uint8Array | string): string {
  const raw = typeof input === "string"
    ? btoa(input)
    : btoa(String.fromCharCode(...input));
  return raw.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

/** PEM PKCS#8 → CryptoKey (RS256). */
async function importarChavePem(pem: string): Promise<CryptoKey> {
  const corpo = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const bytes = Uint8Array.from(atob(corpo), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey(
    "pkcs8",
    bytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
}

/** Gera JWT OAuth2 e troca por access_token do Google. */
async function obterAccessToken(sa: {
  client_email: string;
  private_key: string;
}): Promise<string> {
  const iat = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp: iat + 3600,
  };
  const h = b64url(JSON.stringify(header));
  const p = b64url(JSON.stringify(payload));
  const chave = await importarChavePem(sa.private_key);
  const sigBytes = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    chave,
    new TextEncoder().encode(`${h}.${p}`),
  );
  const jwt = `${h}.${p}.${b64url(new Uint8Array(sigBytes))}`;

  const r = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  if (!r.ok) {
    throw new Error(`OAuth2 recusou: HTTP ${r.status} — ${await r.text()}`);
  }
  const j = await r.json() as { access_token: string };
  return j.access_token;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ erro: "Método não permitido. Só POST." }, 405);
  }

  // Auth: secret partilhado.
  const invokeSecret = Deno.env.get("EDGE_INVOKE_SECRET");
  if (!invokeSecret) {
    return json({ erro: "EDGE_INVOKE_SECRET não configurado no servidor." }, 500);
  }
  const auth = req.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${invokeSecret}`) {
    return json({ erro: "Não autorizado." }, 401);
  }

  // Body.
  let body: {
    title?: unknown;
    body?: unknown;
    data?: unknown;
    user_id?: unknown;
  };
  try {
    body = await req.json();
  } catch {
    return json({ erro: "JSON inválido." }, 400);
  }
  const title = typeof body.title === "string" ? body.title : "";
  const bodyText = typeof body.body === "string" ? body.body : "";
  const userId = typeof body.user_id === "string" && body.user_id
    ? body.user_id
    : ADMIN_USER_ID_FALLBACK;
  if (!title || !bodyText) {
    return json({ erro: "Faltam campos obrigatórios: title, body." }, 400);
  }

  // Service account JSON.
  const saRaw = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON");
  if (!saRaw) {
    return json({ erro: "FCM_SERVICE_ACCOUNT_JSON não configurado." }, 500);
  }
  let sa: {
    project_id: string;
    client_email: string;
    private_key: string;
  };
  try {
    sa = JSON.parse(saRaw);
  } catch {
    return json({ erro: "FCM_SERVICE_ACCOUNT_JSON não é JSON válido." }, 500);
  }
  if (!sa.project_id || !sa.client_email || !sa.private_key) {
    return json({ erro: "FCM_SERVICE_ACCOUNT_JSON incompleto." }, 500);
  }

  // Access token.
  let accessToken: string;
  try {
    accessToken = await obterAccessToken(sa);
  } catch (e) {
    return json({ erro: `Falha OAuth2: ${String(e)}` }, 500);
  }

  // Tokens do dispositivo (service_role ignora RLS).
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
  const { data: dispositivos, error: errDisp } = await supabase
    .from("admin_dispositivos")
    .select("fcm_token, plataforma")
    .eq("user_id", userId);
  if (errDisp) {
    return json({ erro: `Base: ${errDisp.message}` }, 500);
  }
  if (!dispositivos || dispositivos.length === 0) {
    return json({
      ok: true,
      enviados: 0,
      aviso: `Nenhum dispositivo registado para user_id ${userId}.`,
    }, 200);
  }

  // Data: FCM exige valores string.
  const rawData = (body.data && typeof body.data === "object")
    ? body.data as Record<string, unknown>
    : {};
  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(rawData)) {
    data[k] = typeof v === "string" ? v : JSON.stringify(v);
  }

  // Enviar para cada token.
  const url = `https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`;
  const resultados: Array<Record<string, unknown>> = [];
  for (const d of dispositivos) {
    const message = {
      message: {
        token: d.fcm_token,
        notification: { title, body: bodyText },
        data,
      },
    };
    try {
      const r = await fetch(url, {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify(message),
      });
      const resposta = await r.json().catch(() => ({}));
      resultados.push({
        token_prefix: d.fcm_token.slice(0, 12),
        plataforma: d.plataforma,
        status: r.status,
        resposta,
      });
    } catch (e) {
      resultados.push({
        token_prefix: d.fcm_token.slice(0, 12),
        plataforma: d.plataforma,
        erro: String(e),
      });
    }
  }

  return json({ ok: true, enviados: dispositivos.length, resultados }, 200);
});
