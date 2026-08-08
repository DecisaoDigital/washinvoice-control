// WashInvoice POS — sincronizar-empresa
// Chamada pelo POS no arranque e quando o admin grava os dados da empresa ou
// muda as preferências de features. Actualiza `licencas` (nome, nome_comercial,
// nif, cliente_id, preferencias_features) e faz upsert em `clientes` por NIF.
//
// NÃO toca em `tier` nem em `plano`:
//   - `tier` é decisão comercial do Cesar (só o Control o muda);
//   - `plano` é a duração e entra na assinatura HMAC do licenca.json.
// Um POS não pode promover-se a si próprio.
//
// Corre com service_role (contorna RLS).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

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

interface Empresa {
  nif?: string;
  designacao_social?: string;
  nome_comercial?: string;
  morada?: string;
  cp?: string;
  localidade?: string;
  telefone?: string;
  email?: string;
}

/** Só aceita as três chaves conhecidas, e só booleanos. */
function limparPreferencias(v: unknown): Record<string, boolean> {
  const out: Record<string, boolean> = {};
  if (!v || typeof v !== 'object') return out;
  for (const chave of ['guias', 'gestao', 'graficos']) {
    const valor = (v as Record<string, unknown>)[chave];
    if (typeof valor === 'boolean') out[chave] = valor;
  }
  return out;
}

/** Trim + string vazia → undefined (não sobrescreve com vazio). */
function texto(v: unknown): string | undefined {
  if (typeof v !== 'string') return undefined;
  const t = v.trim();
  return t.length > 0 ? t : undefined;
}

/**
 * Placeholders conhecidos que o POS mete como valor default em `dados de
 * empresa` antes de o admin editar. NUNCA devem ser gravados como se fossem
 * dados reais — o Control fica a mostrar o placeholder em vez do hostname.
 * Comparação case-insensitive, com trim.
 */
const PLACEHOLDERS_NOME = new Set(
  [
    'Passa&Engoma',
    'Passa&Engoma, Lda.',
    'Passa&Engoma, Lda',
    'Lavandaria Sol Lda',
    'Lavandaria Sol Lda.',
    'Lavandaria da Esposa (placeholder)',
    'Lavandaria da Esposa',
  ].map((s) => s.trim().toLowerCase()),
);

function ehPlaceholder(v: string | undefined): boolean {
  if (!v) return false;
  return PLACEHOLDERS_NOME.has(v.trim().toLowerCase());
}

/** Se for placeholder, devolve undefined — para não sobrescrever com "lixo". */
function textoReal(v: unknown): string | undefined {
  const t = texto(v);
  return t && !ehPlaceholder(t) ? t : undefined;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { erro: 'method not allowed' });
  }

  let body: {
    machine_id?: string;
    empresa?: Empresa;
    preferencias_features?: unknown;
  };
  try {
    body = await req.json();
  } catch {
    return json(400, { erro: 'body inválido' });
  }

  const machineId = body.machine_id;
  if (!machineId || typeof machineId !== 'string' || machineId.length < 4) {
    return json(400, { erro: 'machine_id obrigatório' });
  }

  const empresa = body.empresa ?? {};
  const preferencias = limparPreferencias(body.preferencias_features);

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const { data: licencas, error: erroLeitura } = await supabase
    .from('licencas')
    .select('id')
    .eq('machine_id', machineId)
    .limit(1);

  if (erroLeitura) {
    console.error('erro leitura licencas', erroLeitura);
    return json(500, { erro: erroLeitura.message });
  }
  if (!licencas || licencas.length === 0) {
    return json(404, { erro: 'terminal desconhecido' });
  }

  const designacao = textoReal(empresa.designacao_social);
  const comercial = textoReal(empresa.nome_comercial);
  const nif = texto(empresa.nif);

  let clienteId: string | null = null;
  if (nif && nif !== '000000000') {
    const patchCliente: Record<string, unknown> = { nif };
    if (designacao) patchCliente.nome = designacao;
    patchCliente.nome_comercial = comercial ?? null;
    const localidade = texto(empresa.localidade);
    const email = texto(empresa.email);
    const telefone = texto(empresa.telefone);
    if (localidade) patchCliente.localidade = localidade;
    if (email) patchCliente.email = email;
    if (telefone) patchCliente.telemovel = telefone;

    const { data: clienteRow, error: erroCliente } = await supabase
      .from('clientes')
      .upsert(patchCliente, { onConflict: 'nif' })
      .select('id')
      .single();

    if (erroCliente) {
      console.error('erro upsert clientes', erroCliente);
      return json(500, { erro: erroCliente.message });
    }
    clienteId = clienteRow?.id ?? null;
  }

  const patchLicenca: Record<string, unknown> = {
    preferencias_features: preferencias,
  };
  patchLicenca.nome = designacao ?? null;
  patchLicenca.nome_comercial = comercial ?? null;
  if (nif) patchLicenca.nif = nif;
  if (clienteId) patchLicenca.cliente_id = clienteId;

  const { error: erroUpdate } = await supabase
    .from('licencas')
    .update(patchLicenca)
    .eq('machine_id', machineId);

  if (erroUpdate) {
    console.error('erro update licencas', erroUpdate);
    return json(500, { erro: erroUpdate.message });
  }

  return json(200, {
    sincronizado: true,
    machine_id: machineId,
    cliente_id: clienteId,
  });
});