// WashInvoice — respostas-sugestoes
// O POS, o Fist e o Fist OP perguntam aqui se o César respondeu às sugestões
// que o terminal enviou. Corpo: { machine_id, app, marcar_lidas?: boolean }.
//
// Identidade: só o `machine_id` + `app` que existam em `licencas` (o mesmo
// critério do trigger `identificar_por_terminal` ao gravar a sugestão). Nunca
// se confia em nif/empresa vindos do pedido. Só devolve respostas a sugestões
// DESTE terminal. `verify_jwt: false`: o POS só tem a chave anon.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';

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

const APPS = ['pos', 'punho', 'punho_op'];

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { erro: 'método não suportado' });

  let corpo: { machine_id?: string; app?: string; marcar_lidas?: boolean };
  try {
    corpo = await req.json();
  } catch {
    return json(400, { erro: 'json inválido' });
  }
  const machineId = (corpo.machine_id ?? '').trim();
  const app = (corpo.app ?? '').trim();
  if (machineId === '' || !APPS.includes(app)) {
    return json(400, { erro: 'machine_id e app válidos são obrigatórios' });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
  );

  const { data: lic, error: eLic } = await supabase
    .from('licencas')
    .select('machine_id')
    .eq('machine_id', machineId)
    .eq('app', app)
    .limit(1);
  if (eLic) return json(500, { erro: eLic.message });
  if (!lic || lic.length === 0) return json(403, { erro: 'terminal desconhecido' });

  const { data: sugs, error: eSug } = await supabase
    .from('sugestoes')
    .select('id, texto')
    .eq('machine_id', machineId)
    .eq('app', app);
  if (eSug) return json(500, { erro: eSug.message });
  const textoDe = new Map((sugs ?? []).map((s) => [s.id, s.texto]));
  if (textoDe.size === 0) return json(200, { respostas: [] });

  const { data: resps, error: eResp } = await supabase
    .from('sugestoes_respostas')
    .select('id, sugestao_id, texto, criado_em, lida_pelo_cliente')
    .in('sugestao_id', [...textoDe.keys()])
    .order('criado_em', { ascending: false });
  if (eResp) return json(500, { erro: eResp.message });

  if (corpo.marcar_lidas === true) {
    const ids = (resps ?? []).filter((r) => !r.lida_pelo_cliente).map((r) => r.id);
    if (ids.length > 0) {
      const { error } = await supabase
        .from('sugestoes_respostas')
        .update({ lida_pelo_cliente: true })
        .in('id', ids);
      if (error) return json(500, { erro: error.message });
    }
  }

  return json(200, {
    respostas: (resps ?? []).map((r) => ({
      id: r.id,
      sugestao: textoDe.get(r.sugestao_id) ?? '',
      texto: r.texto,
      criado_em: r.criado_em,
      lida: r.lida_pelo_cliente,
    })),
  });
});
