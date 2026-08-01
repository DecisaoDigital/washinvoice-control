// WashInvoice Control — assinar-licenca
//
// Assina o `licenca.json` de um terminal com **Ed25519**, com a chave privada
// guardada no secret `LICENCA_ED25519_PRIVATE_KEY`. É a peça que tira a
// capacidade de assinar de dentro das apps.
//
// ## O problema que resolve
//
// Até aqui a assinatura era HMAC-SHA256 com chave **simétrica** — a mesma que
// assina e verifica. Uma chave dessas tem de viver no binário do POS para ele
// poder validar, e quem extraísse o executável passava a **emitir** licenças
// válidas. Estava assinalado no contrato das apps como "teatro de segurança".
//
// Com Ed25519 as duas metades separam-se: o POS leva só a **pública**, que
// chega para verificar e não serve para assinar. A privada nunca sai daqui.
//
// ## Porque é que o servidor NÃO aceita a base já montada
//
// Seria mais simples receber a string e assiná-la. Mas então um Control
// comprometido — ou qualquer um com o token do Cesar — mandava assinar o que
// quisesse, e a chave privada no servidor não valia mais do que a antiga no
// binário. Aqui **o servidor lê a licença da base de dados e assina o que lá
// está**. O cliente diz *qual* terminal, nunca *o quê*.
//
// A única coisa que o cliente escolhe é a série, e só porque é definida no acto
// de gerar a licença — e mesmo essa é gravada na linha antes de ser assinada,
// para que o que fica assinado e o que fica na base de dados sejam a mesma
// coisa.
//
// Autorização em duas camadas, igual à `gerir-licenca`: anon key + JWT do
// caller para saber QUEM é (`is_admin()` precisa de correr no contexto dele), e
// só depois service_role para ler e escrever.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

/** PKCS#8 em base64 (o corpo do PEM, sem cabeçalho nem rodapé). */
const PRIVADA_B64 = Deno.env.get('LICENCA_ED25519_PRIVATE_KEY') ?? '';

/// A pública correspondente, a mesma que está embutida no POS
/// (`licenca_assinatura.dart::kChavePublicaLicencas`). Aqui serve só para a
/// auto-verificação abaixo: se o secret for trocado por uma chave de outro par,
/// esta constante deixa de bater e a função recusa-se a emitir, em vez de
/// produzir licenças que nenhum terminal aceita.
const CHAVE_PUBLICA_B64 = 'byD2dw54dszQlIA66aE09+aasLbglsXqxWjpUsatX7w=';

/** Versão de assinatura que esta função emite. O POS lê-a em
 *  `versao_assinatura` para saber com que algoritmo verificar. */
const VERSAO_ASSINATURA = 2;

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

function b64ParaBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function bytesParaB64(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

/// A MESMA base que o POS e o Control montam
/// (`licenca_assinatura.dart::baseAssinatura`). Se as duas divergirem, as
/// licenças novas passam a ser recusadas em silêncio pelos terminais — por isso
/// há um teste dos dois lados a fixar exemplos idênticos.
///
/// `nif|machine_id|validade|plano[|serie][|<serie ou vazio>|chave_mestre]`
///
/// A série ganha lugar fixo quando há chave mestre: sem isso, `serie=ABC` sem
/// chave produzia a mesma base que `chave=ABC` sem série.
function baseAssinatura(
  nif: string | null,
  machineId: string,
  validade: string,
  plano: string | null,
  serie: string | null,
  chaveMestre: string | null,
): string {
  const base = `${nif ?? ''}|${machineId}|${validade}|${plano ?? ''}`;
  const temSerie = serie !== null && serie !== '';
  const temChave = chaveMestre !== null && chaveMestre !== '';
  if (temChave) return `${base}|${serie ?? ''}|${chaveMestre}`;
  return temSerie ? `${base}|${serie}` : base;
}

/** `YYYY-MM-DD` — a validade entra na assinatura neste formato exacto. */
function ymd(v: unknown): string | null {
  if (typeof v !== 'string') return null;
  const m = v.match(/^(\d{4}-\d{2}-\d{2})/);
  return m ? m[1] : null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { ok: false, erro: 'method not allowed' });
  }

  if (PRIVADA_B64 === '') {
    console.error('LICENCA_ED25519_PRIVATE_KEY em falta');
    return json(500, {
      ok: false,
      erro: 'chave de assinatura não configurada no servidor',
    });
  }

  // ── Camada 1: quem és tu? ────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json(401, { ok: false, erro: 'não autenticado' });

  const clienteUtilizador = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (token.length === 0) return json(401, { ok: false, erro: 'não autenticado' });

  const { data: dadosUtilizador, error: erroUtilizador } =
    await clienteUtilizador.auth.getUser(token);
  const utilizador = dadosUtilizador?.user;
  if (erroUtilizador || !utilizador) {
    return json(401, { ok: false, erro: 'não autenticado' });
  }

  const { data: ehAdmin, error: erroAdmin } =
    await clienteUtilizador.rpc('is_admin');
  if (erroAdmin) {
    console.error('erro is_admin', erroAdmin);
    return json(500, { ok: false, erro: erroAdmin.message });
  }
  if (ehAdmin !== true) {
    return json(403, { ok: false, erro: 'sem permissões de administrador' });
  }

  // ── Body ─────────────────────────────────────────────────────────────────
  let body: { machine_id?: string; serie?: string };
  try {
    body = await req.json();
  } catch {
    return json(400, { ok: false, erro: 'body inválido' });
  }

  const machineId = body.machine_id;
  if (!machineId || typeof machineId !== 'string' || machineId.length < 4) {
    return json(400, { ok: false, erro: 'machine_id obrigatório' });
  }

  const serie =
    typeof body.serie === 'string' && body.serie.trim() !== ''
      ? body.serie.trim()
      : null;

  // ── Camada 2: ler a verdade da base de dados ─────────────────────────────
  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const { data: linhas, error: erroLeitura } = await supabase
    .from('licencas')
    .select('*')
    .eq('machine_id', machineId)
    .order('validade', { ascending: false })
    .limit(1);

  if (erroLeitura) {
    console.error('erro leitura licencas', erroLeitura);
    return json(500, { ok: false, erro: erroLeitura.message });
  }
  if (!linhas || linhas.length === 0) {
    return json(404, { ok: false, erro: 'machine_id não existe' });
  }

  const l = linhas[0];

  // A série é o único campo que vem de fora, e é gravada ANTES de assinar: o
  // que fica assinado tem de ser o que fica na base de dados, senão o Control
  // mostra uma coisa e o terminal tem outra.
  if (serie !== null && serie !== l.serie) {
    const { error: erroSerie } = await supabase
      .from('licencas')
      .update({ serie })
      .eq('machine_id', machineId);
    if (erroSerie) {
      console.error('erro update serie', erroSerie);
      return json(500, { ok: false, erro: erroSerie.message });
    }
    l.serie = serie;
  }

  const validade = ymd(l.validade);
  if (validade === null) {
    return json(500, { ok: false, erro: 'validade inválida na base de dados' });
  }

  const base = baseAssinatura(
    l.nif ?? null,
    machineId,
    validade,
    l.plano ?? null,
    l.serie ?? null,
    l.chave_mestre ?? null,
  );

  // ── Assinar ──────────────────────────────────────────────────────────────
  let assinatura: string;
  try {
    const chavePrivada = await crypto.subtle.importKey(
      'pkcs8',
      b64ParaBytes(PRIVADA_B64),
      { name: 'Ed25519' },
      false,
      ['sign'],
    );
    const bytes = new Uint8Array(
      await crypto.subtle.sign(
        { name: 'Ed25519' },
        chavePrivada,
        new TextEncoder().encode(base),
      ),
    );
    assinatura = bytesParaB64(bytes);
  } catch (e) {
    console.error('erro a assinar', e);
    return json(500, { ok: false, erro: 'falha a assinar a licença' });
  }

  // Auto-verificação antes de entregar. Se a cripto estiver mal configurada,
  // esta função tem de falhar aqui e agora — e não emitir uma licença que
  // nenhum terminal aceita e que só se descobre no cliente, ao balcão.
  try {
    const publica = await crypto.subtle.importKey(
      'raw',
      b64ParaBytes(CHAVE_PUBLICA_B64),
      { name: 'Ed25519' },
      false,
      ['verify'],
    );
    const ok = await crypto.subtle.verify(
      { name: 'Ed25519' },
      publica,
      b64ParaBytes(assinatura),
      new TextEncoder().encode(base),
    );
    if (!ok) {
      console.error('auto-verificação falhou: par de chaves inconsistente');
      return json(500, {
        ok: false,
        erro: 'assinatura gerada não verifica — chave mal configurada',
      });
    }
  } catch (e) {
    console.error('erro na auto-verificação', e);
    return json(500, { ok: false, erro: 'falha a verificar a assinatura' });
  }

  // Rasto de quem assinou o quê. Não guarda a base nem a assinatura: guarda o
  // suficiente para responder "quem emitiu a licença deste terminal, e quando".
  const { error: erroAudit } = await supabase.from('licencas_audit').insert({
    licenca_id: l.id,
    operacao: 'UPDATE',
    actor_uid: utilizador.id,
    actor_role: 'admin',
    antes: l,
    depois: l,
    campos_alterados: [],
    acao: 'assinar_licenca',
    parametros: { versao_assinatura: VERSAO_ASSINATURA, serie: l.serie },
  });
  if (erroAudit) {
    console.error('erro insert licencas_audit', erroAudit);
  }

  // Devolve os campos EXACTOS que foram assinados. O Control escreve o
  // `licenca.json` a partir daqui e não de cópias suas — se montasse o ficheiro
  // com valores próprios e um deles diferisse, a assinatura não batia.
  return json(200, {
    ok: true,
    versao_assinatura: VERSAO_ASSINATURA,
    assinatura,
    campos: {
      nif: l.nif,
      nome: l.nome,
      chave_mestre: l.chave_mestre ?? null,
      machine_id: machineId,
      plano: l.plano,
      validade,
      serie: l.serie ?? null,
    },
  });
});
