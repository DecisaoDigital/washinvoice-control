// ============================================================================
// WashInvoice — Edge Function: enviar-push (multi-app)
// ----------------------------------------------------------------------------
// Envia notificações FCM para os dispositivos registados de um admin.
// v8: aceita `body.app` opcional ('pos' | 'punho'). Se presente, prefixa o
// título com `[POS] ` ou `[FIST] ` — assim o prefixo aparece na barra de
// notificações do SO em background (não só com a app aberta).
//
// Autenticação: header Authorization: Bearer <EDGE_INVOKE_SECRET>.
// ============================================================================

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const ADMIN_USER_ID_FALLBACK = "9e1bfae1-b932-430d-ad41-055cf894ff7f";

function json(corpo: unknown, status: number): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

function b64url(input: Uint8Array | string): string {
  const raw = typeof input === "string"
    ? btoa(input)
    : btoa(String.fromCharCode(...input));
  return raw.replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

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

/** Prefixo por app no título para aparecer na notificação do SO. */
function prefixarTituloPorApp(title: string, app: string | undefined): string {
  if (!app) return title;
  const tag = app === "pos" ? "[POS]" : app === "punho" ? "[FIST]" : null;
  if (!tag) return title;
  // Evitar duplo prefixo se o caller já o incluiu.
  if (title.startsWith(tag)) return title;
  return `${tag} ${title}`;
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ erro: "Método não permitido. Só POST." }, 405);
  }

  const invokeSecret = Deno.env.get("EDGE_INVOKE_SECRET");
  if (!invokeSecret) {
    return json({ erro: "EDGE_INVOKE_SECRET não configurado no servidor." }, 500);
  }
  const auth = req.headers.get("Authorization") ?? "";
  if (auth !== `Bearer ${invokeSecret}`) {
    return json({ erro: "Não autorizado." }, 401);
  }

  let body: {
    title?: unknown;
    body?: unknown;
    data?: unknown;
    user_id?: unknown;
    app?: unknown;
  };
  try {
    body = await req.json();
  } catch {
    return json({ erro: "JSON inválido." }, 400);
  }
  const rawTitle = typeof body.title === "string" ? body.title : "";
  const bodyText = typeof body.body === "string" ? body.body : "";
  const userId = typeof body.user_id === "string" && body.user_id
    ? body.user_id
    : ADMIN_USER_ID_FALLBACK;
  const app = typeof body.app === "string" ? body.app.toLowerCase() : undefined;
  if (!rawTitle || !bodyText) {
    return json({ erro: "Faltam campos obrigatórios: title, body." }, 400);
  }
  const title = prefixarTituloPorApp(rawTitle, app);

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

  let accessToken: string;
  try {
    accessToken = await obterAccessToken(sa);
  } catch (e) {
    return json({ erro: `Falha OAuth2: ${String(e)}` }, 500);
  }

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

  // Data: FCM exige strings. Injectar `app` também no payload data para o
  // client-side (foreground handler) reconhecer.
  const rawData = (body.data && typeof body.data === "object")
    ? body.data as Record<string, unknown>
    : {};
  const data: Record<string, string> = {};
  for (const [k, v] of Object.entries(rawData)) {
    data[k] = typeof v === "string" ? v : JSON.stringify(v);
  }
  if (app && !data.app) data.app = app;

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
