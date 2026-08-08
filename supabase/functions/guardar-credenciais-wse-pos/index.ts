// WashInvoice POS — guardar-credenciais-wse-pos
//
// Grava (upsert) as credenciais WSE de um cliente para um ambiente ('teste' |
// 'producao'), CIFRADAS em repouso com `at_cred_enc_key` (AES-GCM). Só o admin
// do POS abre o ecrã que chama esta função — o gate é local; server-side
// valida a instalação por machine_id + licença activa (padrão do POS, sem
// sessão Supabase por operador → `verify_jwt: false`).

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function lerSecret(sb: SupabaseClient, nome: string): Promise<string> {
  const { data, error } = await sb.rpc('ler_secret_at', { p_nome: nome });
  if (error) throw new Error(`vault ${nome}: ${error.message}`);
  if (!data || typeof data !== 'string') throw new Error(`vault ${nome}: vazio`);
  return data;
}

async function importarChaveGcm(b64: string): Promise<CryptoKey> {
  const raw = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, [
    'encrypt',
    'decrypt',
  ]);
}

async function gcmCifrar(plain: string, key: CryptoKey): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(
    await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key,
      new TextEncoder().encode(plain)),
  );
  const out = new Uint8Array(iv.length + ct.length);
  out.set(iv, 0);
  out.set(ct, iv.length);
  return btoa(String.fromCharCode(...out));
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') {
    return json(405, { sucesso: false, erro: 'method not allowed' });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json(400, { sucesso: false, erro: 'body invalido' });
  }

  const ambiente = body.ambiente as string;
  if (ambiente !== 'teste' && ambiente !== 'producao') {
    return json(400, {
      sucesso: false,
      erro: "Parametro 'ambiente' obrigatorio: 'teste' ou 'producao'.",
    });
  }

  const machineId = body.machine_id as string | undefined;
  const username = String(body.username ?? '').trim();
  const password = String(body.password ?? '');
  if (!machineId || machineId.length < 4) {
    return json(400, { sucesso: false, erro: 'machine_id obrigatorio' });
  }
  if (!username || !password) {
    return json(400, { sucesso: false, erro: 'username e password obrigatorios' });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const { data: licLinhas, error: licErro } = await admin
    .from('licencas')
    .select('id')
    .eq('machine_id', machineId)
    .order('validade', { ascending: false })
    .limit(1);
  if (licErro) return json(500, { sucesso: false, erro: licErro.message });
  const licenca = licLinhas?.[0];
  if (!licenca) {
    return json(403, {
      sucesso: false,
      erro: 'Instalacao sem licenca valida.',
      codigo_erro: 'LICENCA_INVALIDA',
    });
  }

  try {
    const gcmKey = await importarChaveGcm(await lerSecret(admin, 'at_cred_enc_key'));
    const usernameCifrado = await gcmCifrar(username, gcmKey);
    const passwordCifrada = await gcmCifrar(password, gcmKey);

    const { error: upErro } = await admin
      .from('credenciais_wse_cliente')
      .upsert(
        {
          licenca_id: licenca.id,
          ambiente,
          username_cifrado: usernameCifrado,
          password_cifrada: passwordCifrada,
          actualizado_em: new Date().toISOString(),
        },
        { onConflict: 'licenca_id,ambiente' },
      );
    if (upErro) return json(500, { sucesso: false, erro: upErro.message });

    return json(200, { sucesso: true, ambiente, mensagem: 'Credenciais guardadas.' });
  } catch (e) {
    console.error('guardar-credenciais-wse-pos erro', e);
    return json(500, { sucesso: false, erro: String((e as Error).message ?? e) });
  }
});
