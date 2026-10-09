// WashInvoice Control — gerir-licenca
// Mutações de licença feitas a partir do Control: prolongar validade, suspender,
// reactivar, cancelar e mudar o nível comercial (tier).
//
// Porque existe: hoje o Control escreve em `licencas` com a anon key + JWT do
// Cesar, o que obriga a policy de `licencas` a estar aberta. Passando toda a
// mutação por aqui (service_role), o dia em que a RLS fechar o Control continua
// a funcionar sem tocar em código.
//
// Autorização em DUAS camadas — não colapsar numa só:
//   1. Cliente com a ANON key + o header Authorization do caller, para correr
//      `getUser()` e `is_admin()`. É esta que valida QUEM está a chamar.
//      `is_admin()` lê `auth.uid()` internamente, por isso TEM de correr no
//      contexto do utilizador. Chamada a partir do cliente service_role
//      devolveria sempre false (auth.uid() nulo).
//   2. Só depois, cliente service_role para a mutação em si.
//
// NÃO toca em `licencas.plano`: é a *duração* e entra na base da assinatura
// HMAC do licenca.json do POS
// (`nif|machine_id|validade|plano[|serie][|<serie ou vazio>|chave_mestre]`).
// Alterá-la invalidaria a licença instalada no terminal. O nível comercial
// vive em `licencas.tier`, fora da assinatura.
//
// `atribuir_chave_mestre` é a excepção que confirma a regra: escreve um campo
// QUE ENTRA na assinatura. Por isso não chega correr a acção — é preciso gerar
// e instalar o `licenca.json` novo a seguir, senão a base assinada no ficheiro
// do terminal deixa de bater com a da base de dados. O Control faz as duas
// coisas no mesmo gesto (ver `detalhe_cliente_screen.dart`).

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

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

type Accao =
  | 'prolongar'
  | 'definir_validade'
  | 'suspender'
  | 'reactivar'
  | 'cancelar'
  | 'mudar_tier'
  | 'atribuir_chave_mestre'
  | 'configurar';

const ACCOES: Accao[] = [
  'prolongar',
  'definir_validade',
  'suspender',
  'reactivar',
  'cancelar',
  'mudar_tier',
  'atribuir_chave_mestre',
  'configurar',
];

/** Prefixo legível da chave mestre, tirado do nome da máquina. Decoração para
 *  se reconhecer a linha e a ler ao telefone — não tem significado técnico e a
 *  chave não deriva dele. */
function prefixoDeHost(infoHost: unknown): string | null {
  if (typeof infoHost !== 'object' || infoHost === null) return null;
  const h = (infoHost as Record<string, unknown>).hostname;
  if (typeof h !== 'string') return null;
  const letras = h.replace(/[^A-Za-z]/g, '').toUpperCase().slice(0, 6);
  return letras.length === 0 ? null : letras;
}

/** `YYYY-MM-DD` válido? */
function dataValida(v: unknown): v is string {
  if (typeof v !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(v)) return false;
  const d = new Date(`${v}T00:00:00Z`);
  return !isNaN(d.getTime()) && d.toISOString().slice(0, 10) === v;
}

const DIAS_PERMITIDOS = [5, 15, 30];

/** `YYYY-MM-DD` de hoje em UTC. */
function hoje(): string {
  return new Date().toISOString().slice(0, 10);
}

/** Soma dias a uma data `YYYY-MM-DD`, devolvendo `YYYY-MM-DD`. */
function somarDias(data: string, dias: number): string {
  const d = new Date(`${data}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + dias);
  return d.toISOString().slice(0, 10);
}

/** Campos que mudaram entre dois retratos da licença. */
function camposAlterados(
  antes: Record<string, unknown>,
  depois: Record<string, unknown>,
): string[] {
  return Object.keys(depois).filter(
    (k) => JSON.stringify(antes[k]) !== JSON.stringify(depois[k]),
  );
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { ok: false, erro: 'method not allowed' });
  }

  // ── Camada 1: quem és tu? ────────────────────────────────────────────────
  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json(401, { ok: false, erro: 'não autenticado' });
  }

  const clienteUtilizador = createClient(SUPABASE_URL, ANON_KEY, {
    auth: { persistSession: false },
    global: { headers: { Authorization: authHeader } },
  });

  // O token TEM de ir como argumento. `getUser()` sem argumentos lê a sessão
  // guardada no próprio cliente — e este cliente nunca fez login
  // (`persistSession: false`), portanto devolveria sempre null e o pedido
  // seria rejeitado mesmo vindo de um admin. O header em `global.headers`
  // serve o PostgREST (o `rpc` abaixo), não o módulo de auth.
  const token = authHeader.replace(/^Bearer\s+/i, '').trim();
  if (token.length === 0) {
    return json(401, { ok: false, erro: 'não autenticado' });
  }

  const { data: dadosUtilizador, error: erroUtilizador } =
    await clienteUtilizador.auth.getUser(token);
  const utilizador = dadosUtilizador?.user;
  if (erroUtilizador || !utilizador) {
    return json(401, { ok: false, erro: 'não autenticado' });
  }

  // `is_admin()` corre no contexto deste utilizador e lê `auth.uid()`.
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
  let body: {
    acao?: string;
    machine_id?: string;
    parametros?: Record<string, unknown>;
  };
  try {
    body = await req.json();
  } catch {
    return json(400, { ok: false, erro: 'body inválido' });
  }

  const acao = body.acao as Accao | undefined;
  if (!acao || !ACCOES.includes(acao)) {
    return json(400, { ok: false, erro: `acção desconhecida: ${body.acao}` });
  }

  const machineId = body.machine_id;
  if (!machineId || typeof machineId !== 'string' || machineId.length < 4) {
    return json(400, { ok: false, erro: 'machine_id obrigatório' });
  }

  const parametros = body.parametros ?? {};

  // ── Camada 2: mutação com service_role ───────────────────────────────────
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

  const antes = linhas[0];
  const patch: Record<string, unknown> = {};

  switch (acao) {
    case 'prolongar': {
      const dias = parametros.dias;
      if (typeof dias !== 'number' || !DIAS_PERMITIDOS.includes(dias)) {
        return json(400, {
          ok: false,
          erro: `dias tem de ser um de ${DIAS_PERMITIDOS.join(', ')}`,
        });
      }
      // A partir de hoje quando a licença já expirou — senão prolongar uma
      // licença caducada há um mês daria uma validade ainda no passado.
      const base = antes.validade > hoje() ? antes.validade : hoje();
      patch.validade = somarDias(base, dias);
      break;
    }
    case 'definir_validade': {
      // Renovação com data escolhida à mão (o `prolongar` só cobre 5/15/30).
      // Reactiva também: renovar uma licença suspensa sem a reactivar deixava
      // o terminal bloqueado apesar de pago.
      const validade = parametros.validade;
      if (!dataValida(validade)) {
        return json(400, { ok: false, erro: 'validade tem de ser YYYY-MM-DD' });
      }
      patch.validade = validade;
      patch.activa = true;
      break;
    }
    case 'suspender':
      patch.activa = false;
      break;
    case 'reactivar':
      patch.activa = true;
      break;
    case 'cancelar':
      // Não se apaga a linha: o histórico do terminal tem de sobreviver.
      patch.activa = false;
      patch.validade = hoje();
      break;
    case 'mudar_tier': {
      const tier = parametros.tier;
      if (tier !== 'base' && tier !== 'pro') {
        return json(400, { ok: false, erro: 'tier tem de ser base ou pro' });
      }
      // Ao descer para base NÃO se limpa `preferencias_features`: os
      // interruptores ficam guardados para retomar num upgrade futuro.
      patch.tier = tier;
      break;
    }
    case 'configurar': {
      // Ficha comercial de uma licença acabada de criar (Activar): plano,
      // nome, cliente, oferta e NIF. Só grava o que vier, e só valores
      // conhecidos. A validade segue por `definir_validade`.
      const PLANOS = ['trimestral', 'semestral', 'anual', 'personalizado'];
      if (parametros.plano !== undefined) {
        if (typeof parametros.plano !== 'string' || !PLANOS.includes(parametros.plano)) {
          return json(400, { ok: false, erro: `plano tem de ser um de ${PLANOS.join(', ')}` });
        }
        patch.plano = parametros.plano;
      }
      if (typeof parametros.nome === 'string' && parametros.nome.trim()) {
        patch.nome = parametros.nome.trim().slice(0, 120);
      }
      if (typeof parametros.cliente_id === 'string' &&
          /^[0-9a-f-]{36}$/i.test(parametros.cliente_id)) {
        patch.cliente_id = parametros.cliente_id;
      }
      if (typeof parametros.oferta === 'boolean') patch.oferta = parametros.oferta;
      if (typeof parametros.nif === 'string' && /^\d{9}$/.test(parametros.nif) &&
          parametros.nif !== '000000000') {
        patch.nif = parametros.nif;
      }
      if (Object.keys(patch).length === 0) {
        return json(400, { ok: false, erro: 'nada para configurar' });
      }
      break;
    }
    case 'atribuir_chave_mestre': {
      // A chave é da EMPRESA, não do terminal: a RPC devolve a que já existe
      // para este NIF e só cria uma se não houver nenhuma. É isso que faz o
      // segundo terminal do mesmo cliente entrar na mesma empresa em vez de
      // fundar outra — e é por isso que se chama sempre, mesmo que a linha já
      // tenha `chave_mestre` (assim uma linha dessincronizada corrige-se
      // sozinha).
      const prefixo = typeof parametros.prefixo === 'string'
        ? parametros.prefixo
        : prefixoDeHost(antes.info_host);

      const { data: chave, error: erroChave } = await supabase.rpc(
        'obter_ou_criar_chave_mestre',
        {
          p_nif: antes.nif,
          p_machine_id: machineId,
          p_app: antes.app,
          p_nome: antes.nome,
          p_prefixo: prefixo,
        },
      );

      if (erroChave || typeof chave !== 'string' || chave.length === 0) {
        console.error('erro obter_ou_criar_chave_mestre', erroChave);
        return json(500, {
          ok: false,
          erro: erroChave?.message ?? 'não foi possível obter a chave mestre',
        });
      }

      patch.chave_mestre = chave;
      break;
    }
  }

  const { data: actualizadas, error: erroUpdate } = await supabase
    .from('licencas')
    .update(patch)
    .eq('machine_id', machineId)
    .select('*');

  if (erroUpdate) {
    console.error('erro update licencas', erroUpdate);
    return json(500, { ok: false, erro: erroUpdate.message });
  }

  const depois = actualizadas && actualizadas.length > 0
    ? actualizadas[0]
    : { ...antes, ...patch };

  // ── Auditoria ────────────────────────────────────────────────────────────
  // O trigger `registar_audit_licenca` já grava uma linha por este UPDATE, mas
  // com `actor_uid` nulo (corremos como service_role, não há `auth.uid()`).
  // Esta linha explícita é a que responde a "quem fez o quê": traz o utilizador
  // verificado na camada 1, a acção lógica e os parâmetros. O modal de
  // historial filtra por `acao is not null` para mostrar só estas.
  const { error: erroAudit } = await supabase.from('licencas_audit').insert({
    licenca_id: antes.id,
    operacao: 'UPDATE',
    actor_uid: utilizador.id,
    actor_role: 'admin',
    antes,
    depois,
    campos_alterados: camposAlterados(antes, depois),
    acao,
    parametros,
  });

  if (erroAudit) {
    // Não se desfaz a mutação por causa do registo: a licença já mudou e o
    // trigger deixou rasto. Fica o log para investigação.
    console.error('erro insert licencas_audit', erroAudit);
  }

  return json(200, {
    ok: true,
    acao,
    machine_id: machineId,
    licenca_actualizada: {
      activa: depois.activa,
      validade: depois.validade,
      tier: depois.tier,
      plano: depois.plano,
      chave_mestre: depois.chave_mestre ?? null,
      preferencias_features: depois.preferencias_features ?? {},
    },
  });
});
