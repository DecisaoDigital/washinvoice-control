// WashInvoice — versao-mais-recente
// Responde à pergunta "há build novo para esta app?". O cliente envia a sua app
// e o build local; a function devolve a versão activa com build_number mais alto
// e diz se há actualização.
//
// Separada de propósito de `validar-licenca` e das outras functions: o
// auto-update é ortogonal ao licenciamento e não deve depender dele nem tocá-lo.
//
// Autorização: `verify_jwt: true` (a plataforma valida o JWT antes de entrar
// aqui). Não há gate de admin — qualquer instalação autenticada pode perguntar
// se está desactualizada. A leitura faz-se com service_role para não depender da
// RLS de `versoes_apps`. Não há mutações: só leitura.
//
// Preparada também para o POS (app: 'pos') — o sprint do POS reutiliza esta
// mesma function e tabela, sem alterações aqui.

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

const APPS = ['pos', 'control', 'punho'];
const PLATFORMS = ['all', 'windows', 'android', 'ios'];

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json(405, { erro: 'method not allowed' });
  }

  // verify_jwt já garantiu um JWT válido; aqui só validamos o body.
  let body: { app?: string; plataforma?: string; build_number_local?: number };
  try {
    body = await req.json();
  } catch {
    return json(400, { erro: 'body inválido' });
  }

  const app = body.app;
  const plataforma = body.plataforma ?? 'all';
  if (typeof plataforma !== 'string' || !PLATFORMS.includes(plataforma)) {
    return json(400, { erro: 'plataforma invalida' });
  }
  if (typeof app !== 'string' || !APPS.includes(app)) {
    return json(400, { erro: 'app inválida' });
  }

  const buildLocal = body.build_number_local;
  if (typeof buildLocal !== 'number' || !Number.isFinite(buildLocal)) {
    return json(400, { erro: 'build_number_local tem de ser um número' });
  }

  const supabase = createClient(SUPABASE_URL, SERVICE_ROLE, {
    auth: { persistSession: false },
  });

  const { data: v, error } = await supabase
    .from('versoes_apps')
    .select('versao, build_number, url_download, obrigatoria, notas_lancamento')
    .eq('app', app)
    .eq('activa', true)
    .in('plataforma', [plataforma, 'all'])
    .order('build_number', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) {
    console.error('erro leitura versoes_apps', error);
    return json(500, { erro: error.message });
  }

  // Sem versão catalogada ou já na mais recente → nada a fazer.
  if (!v || buildLocal >= v.build_number) {
    return json(200, { actualizacao_disponivel: false });
  }

  return json(200, {
    actualizacao_disponivel: true,
    versao_actual: v.versao,
    build_number: v.build_number,
    url_download: v.url_download,
    obrigatoria: v.obrigatoria,
    notas_lancamento: v.notas_lancamento,
  });
});
