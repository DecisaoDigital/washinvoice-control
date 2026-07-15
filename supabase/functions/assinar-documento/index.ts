// ============================================================================
// WashInvoice — Edge Function: assinar-documento
// ----------------------------------------------------------------------------
// Assina a string fiscal (Portaria 363/2010, Art. 6.º) com a chave privada RSA
// que vive APENAS como secret desta função (RSA_PRIVATE_KEY). A chave nunca é
// devolvida, nunca é registada, e nunca chega ao cliente.
//
// Fluxo:
//   1. Recebe { machine_id, texto } (POST JSON).
//   2. Valida a licença na tabela `licencas` usando a SERVICE_ROLE_KEY (acesso
//      privilegiado só-servidor, ignora RLS): machine_id existe, activa=true e
//      validade não expirada. Falha qualquer condição → NÃO assina.
//   3. Assina `texto` com RSA + SHA-1 + PKCS#1 v1.5 (mesmo algoritmo que o
//      cliente verifica com pointycastle).
//   4. Devolve { assinatura: "<base64>" }.
//   5. Regista o pedido (metadado: machine_id, timestamp, sucesso/erro) — NUNCA
//      o conteúdo do documento — em `assinaturas_log` (best-effort).
//
// Segurança: a anon key NÃO dá acesso a `licencas` (RLS só permite
// `authenticated`); a validação usa a SUPABASE_SERVICE_ROLE_KEY, que o runtime
// injecta automaticamente e nunca é exposta ao cliente.
//
// Deploy/segredos: ver README.md nesta pasta.
// ============================================================================

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { assinarComPem } from "./assinatura.ts";

/** Resposta JSON com status. */
function json(corpo: unknown, status: number): Response {
  return new Response(JSON.stringify(corpo), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** Registo de auditoria (só metadados). Best-effort: nunca falha o pedido. */
async function registarPedido(
  // deno-lint-ignore no-explicit-any
  supabase: any,
  machineId: string,
  sucesso: boolean,
  erro: string | null,
): Promise<void> {
  try {
    await supabase.from("assinaturas_log").insert({
      machine_id: machineId,
      sucesso,
      erro,
    });
  } catch (_) {
    // Log é best-effort — a assinatura não depende dele.
  }
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ erro: "Método não permitido." }, 405);
  }

  // 1. Corpo.
  let corpo: { machine_id?: unknown; texto?: unknown };
  try {
    corpo = await req.json();
  } catch {
    return json({ erro: "JSON inválido." }, 400);
  }
  const machineId = corpo.machine_id;
  const texto = corpo.texto;
  if (typeof machineId !== "string" || !machineId ||
      typeof texto !== "string" || !texto) {
    return json({ erro: "Campos obrigatórios: machine_id, texto." }, 400);
  }

  // 2. Cliente com SERVICE ROLE (só-servidor; ignora RLS). Estas variáveis são
  //    injectadas automaticamente pelo runtime das Edge Functions.
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Validar a licença deste terminal.
  const { data: lic, error } = await supabase
    .from("licencas")
    .select("activa, validade")
    .eq("machine_id", machineId)
    .maybeSingle();

  if (error) {
    return json({ erro: "Erro a validar a licença." }, 500);
  }
  if (!lic) {
    return json({ erro: "Licença não encontrada para este terminal." }, 403);
  }
  if (lic.activa !== true) {
    return json({ erro: "Licença inactiva." }, 403);
  }
  // `validade` é DATE ("YYYY-MM-DD"); expira no fim desse dia.
  const hoje = new Date().toISOString().slice(0, 10);
  if (typeof lic.validade === "string" && lic.validade < hoje) {
    return json({ erro: "Licença expirada." }, 403);
  }

  // 3-4. Assinar.
  const pem = Deno.env.get("RSA_PRIVATE_KEY");
  if (!pem) {
    // Não revelar detalhes de configuração ao cliente.
    return json({ erro: "Serviço de assinatura indisponível." }, 500);
  }
  let assinatura: string;
  try {
    assinatura = await assinarComPem(texto, pem);
  } catch (_) {
    // NUNCA incluir a chave nem o texto no log/erro.
    await registarPedido(supabase, machineId, false, "falha_assinatura");
    return json({ erro: "Falha ao assinar." }, 500);
  }

  // 5. Log de metadados (best-effort).
  await registarPedido(supabase, machineId, true, null);

  return json({ assinatura }, 200);
});
