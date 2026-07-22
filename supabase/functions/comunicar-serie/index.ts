// WashInvoice Control — comunicar-serie
// Comunica séries de facturação à AT via webservice (operação `registarSerie`),
// a partir do Control. Substitui a comunicação manual no Portal das Finanças.
//
// DUAS acções (função nova; NÃO toca em gerir-licenca, por restrição do sprint):
//   acao: "guardar_credenciais" — grava at_username + password (AES-GCM) na licenca.
//   acao: "comunicar"           — lê credenciais da licenca, monta o envelope SOAP
//                                 com WS-Security AT, fala com a AT por mTLS, e
//                                 devolve o codValidacaoSerie (ATCUD-CV).
//
// Arquitectura mTLS (validada 22/07/2026): o runtime da Supabase NÃO apresenta o
// cert de cliente via Deno.createHttpClient. FUNCIONA via Deno.connectTls +
// HTTP/1.1 escrito à mão. A AT fecha com Connection: close sem TLS close_notify,
// por isso o read tem de tolerar o UnexpectedEof e devolver o que já veio.
//
// Segredos no Supabase Vault (lidos via RPC ler_secret_at, security definer):
//   at_cert_teste_pfx_b64   — .pfx do produtor (mTLS), base64
//   at_cert_teste_password  — password do .pfx
//   at_chave_publica_b64    — chave pública AT (.cer PEM), base64 — cifra o Nonce
//   at_cred_enc_key         — chave AES-GCM do servidor (cifra as passwords AT)
//
// Auth: duas camadas (anon+is_admin -> service_role), padrão de gerir-licenca.
// TESTE: header x-probe-token salta a camada de utilizador (corre service_role)
//        e aceita credenciais no body. REMOVER/DESACTIVAR antes de produção.

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import forge from 'https://esm.sh/node-forge@1.3.1';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;

// TESTE apenas — enquanto não há sub-utilizador de produção. Desactivar depois.
const PROBE_TOKEN = 'probe-9f3a1c7e-at-series';

const AT_HOST = 'servicos.portaldasfinancas.gov.pt';
const AT_PORT = 722;
const AT_PATH = '/SeriesWSService/SeriesWS';
const AT_NS = 'http://at.gov.pt/';
// AT usa o namespace WS-Security ANTIGO (2002/12), com Created no MESMO namespace
// wss: (não wsu:) e sem mustUnderstand. Confirmado na impl. de referência
// hestiatechnology/security.go. Byte-a-byte importa: o DataPower rejeita o resto.
const WSSE_NS = 'http://schemas.xmlsoap.org/ws/2002/12/secext';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, x-probe-token',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function xmlEscape(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

// ───────────────────────── Vault ─────────────────────────
async function lerSecret(sb: SupabaseClient, nome: string): Promise<string> {
  const { data, error } = await sb.rpc('ler_secret_at', { p_nome: nome });
  if (error) throw new Error(`vault ${nome}: ${error.message}`);
  if (!data || typeof data !== 'string') throw new Error(`vault ${nome}: vazio`);
  return data;
}

// ─────────────────── AES-GCM (armazenamento) ───────────────────
async function importarChaveGcm(b64: string): Promise<CryptoKey> {
  const raw = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
}

async function gcmCifrar(plain: string, key: CryptoKey): Promise<string> {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const ct = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, new TextEncoder().encode(plain)));
  const out = new Uint8Array(iv.length + ct.length);
  out.set(iv, 0);
  out.set(ct, iv.length);
  return btoa(String.fromCharCode(...out));
}

async function gcmDecifrar(b64: string, key: CryptoKey): Promise<string> {
  const all = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const iv = all.slice(0, 12);
  const ct = all.slice(12);
  const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ct);
  return new TextDecoder().decode(pt);
}

// ─────────────────── Cert do produtor (.pfx) ───────────────────
function pfxParaCertKey(pfxB64: string, pass: string): { certPem: string; keyPem: string } {
  const der = forge.util.decode64(pfxB64.replace(/\s+/g, ''));
  const p12 = forge.pkcs12.pkcs12FromAsn1(forge.asn1.fromDer(der), pass);
  let keyObj = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0]?.key;
  if (!keyObj) keyObj = p12.getBags({ bagType: forge.pki.oids.keyBag })[forge.pki.oids.keyBag]?.[0]?.key;
  if (!keyObj) throw new Error('chave privada nao encontrada no pfx');
  const keyPem = forge.pki.privateKeyToPem(keyObj);
  const certBags = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag] ?? [];
  const leaf = certBags.find((b: any) => (b.cert?.subject?.getField('CN')?.value || '').includes('TesteWebservices')) ?? certBags[0];
  if (!leaf) throw new Error('cert nao encontrado no pfx');
  return { certPem: forge.pki.certificateToPem(leaf.cert), keyPem };
}

// ─────────────────── WS-Security AT (por pedido) ───────────────────
function aesEcbBase64(symKeyBin: string, plaintext: string): string {
  const cipher = forge.cipher.createCipher('AES-ECB', symKeyBin);
  cipher.start();
  cipher.update(forge.util.createBuffer(forge.util.encodeUtf8(plaintext)));
  cipher.finish();
  return forge.util.encode64(cipher.output.getBytes());
}

interface EnvelopeParams {
  cerPem: string;
  username: string;
  passwordPlain: string;
  serie: string;
  tipoSerie: string;
  classeDoc: string;
  tipoDoc: string;
  numInicialSeq: number;
  dataInicio: string; // YYYY-MM-DD
  numCert: number;
  meioProc: string;
}

function construirEnvelope(p: EnvelopeParams): { envelope: string; created: string } {
  const symKey = forge.random.getBytesSync(16); // AES-128, chave simétrica do pedido
  const pubKey = (forge.pki.certificateFromPem(p.cerPem) as any).publicKey;
  const nonceCifrado = forge.util.encode64(pubKey.encrypt(symKey, 'RSAES-PKCS1-V1_5'));
  const created = new Date().toISOString();
  const passwordCifrada = aesEcbBase64(symKey, p.passwordPlain);
  const createdCifrado = aesEcbBase64(symKey, created);

  const envelope =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    `<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:at="${AT_NS}">` +
    '<soapenv:Header>' +
    `<wss:Security xmlns:wss="${WSSE_NS}">` +
    '<wss:UsernameToken>' +
    `<wss:Username>${xmlEscape(p.username)}</wss:Username>` +
    `<wss:Password>${passwordCifrada}</wss:Password>` +
    `<wss:Nonce>${nonceCifrado}</wss:Nonce>` +
    `<wss:Created>${createdCifrado}</wss:Created>` +
    '</wss:UsernameToken>' +
    '</wss:Security>' +
    '</soapenv:Header>' +
    '<soapenv:Body>' +
    '<at:registarSerie>' +
    `<serie>${xmlEscape(p.serie)}</serie>` +
    `<tipoSerie>${p.tipoSerie}</tipoSerie>` +
    `<classeDoc>${p.classeDoc}</classeDoc>` +
    `<tipoDoc>${p.tipoDoc}</tipoDoc>` +
    `<numInicialSeq>${p.numInicialSeq}</numInicialSeq>` +
    `<dataInicioPrevUtiliz>${p.dataInicio}</dataInicioPrevUtiliz>` +
    `<numCertSWFatur>${p.numCert}</numCertSWFatur>` +
    `<meioProcessamento>${p.meioProc}</meioProcessamento>` +
    '</at:registarSerie>' +
    '</soapenv:Body>' +
    '</soapenv:Envelope>';
  return { envelope, created };
}

// ─────────────────── Transporte mTLS (connectTls) ───────────────────
async function enviarAt(envelope: string, certPem: string, keyPem: string): Promise<{ status: number; body: string; raw: string }> {
  // @ts-ignore cert/key options
  const conn: Deno.Conn = await Deno.connectTls({ hostname: AT_HOST, port: AT_PORT, cert: certPem, key: keyPem });
  const enc = new TextEncoder();
  const bodyBytes = enc.encode(envelope);
  const req =
    `POST ${AT_PATH} HTTP/1.1\r\n` +
    `Host: ${AT_HOST}:${AT_PORT}\r\n` +
    'Content-Type: text/xml; charset=utf-8\r\n' +
    "SOAPAction: ''\r\n" +
    `Content-Length: ${bodyBytes.length}\r\n` +
    'Connection: close\r\n\r\n';
  try {
    await conn.write(enc.encode(req));
    await conn.write(bodyBytes);
    const chunks: Uint8Array[] = [];
    const buf = new Uint8Array(16384);
    try {
      while (true) {
        const n = await conn.read(buf);
        if (n === null) break;
        chunks.push(buf.slice(0, n));
        if (chunks.reduce((a, c) => a + c.length, 0) > 65536) break;
      }
    } catch (_e) {
      // rustls UnexpectedEof depois dos dados (Connection: close sem close_notify).
    }
    const total = new Uint8Array(chunks.reduce((a, c) => a + c.length, 0));
    let off = 0;
    for (const c of chunks) {
      total.set(c, off);
      off += c.length;
    }
    const raw = new TextDecoder().decode(total);
    const sep = raw.indexOf('\r\n\r\n');
    const headSect = sep >= 0 ? raw.slice(0, sep) : raw;
    const body = sep >= 0 ? raw.slice(sep + 4) : '';
    const statusMatch = headSect.match(/^HTTP\/\d\.\d (\d+)/);
    return { status: statusMatch ? parseInt(statusMatch[1], 10) : 0, body, raw };
  } finally {
    try {
      conn.close();
    } catch { /* já fechado */ }
  }
}

function extrair(tag: string, xml: string): string | null {
  const m = xml.match(new RegExp(`<(?:\\w+:)?${tag}[^>]*>([\\s\\S]*?)</(?:\\w+:)?${tag}>`, 'i'));
  return m ? m[1].trim() : null;
}

// ───────────────────────── Handler ─────────────────────────
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { ok: false, erro: 'method not allowed' });

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json(400, { ok: false, erro: 'body inválido' });
  }

  const modoTeste = req.headers.get('x-probe-token') === PROBE_TOKEN;

  // service_role para tudo o que é mutação/leitura de secrets
  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

  // ── Auth (excepto modo teste) ──
  let actor = 'teste';
  if (!modoTeste) {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) return json(401, { ok: false, erro: 'não autenticado' });
    const token = authHeader.replace(/^Bearer\s+/i, '').trim();
    if (!token) return json(401, { ok: false, erro: 'não autenticado' });
    const userClient = createClient(SUPABASE_URL, ANON_KEY, {
      auth: { persistSession: false },
      global: { headers: { Authorization: authHeader } },
    });
    const { data: ud, error: ue } = await userClient.auth.getUser(token);
    if (ue || !ud?.user) return json(401, { ok: false, erro: 'não autenticado' });
    const { data: ehAdmin, error: ae } = await userClient.rpc('is_admin');
    if (ae) return json(500, { ok: false, erro: ae.message });
    if (ehAdmin !== true) return json(403, { ok: false, erro: 'sem permissões de administrador' });
    actor = ud.user.email ?? ud.user.id;
  }

  const acao = body.acao as string | undefined;
  const machineId = body.machine_id as string | undefined;
  if (!machineId || typeof machineId !== 'string' || machineId.length < 4) {
    return json(400, { ok: false, erro: 'machine_id obrigatório' });
  }

  const { data: licLinhas, error: licErro } = await admin
    .from('licencas')
    .select('*')
    .eq('machine_id', machineId)
    .order('validade', { ascending: false })
    .limit(1);
  if (licErro) return json(500, { ok: false, erro: licErro.message });
  if (!licLinhas || licLinhas.length === 0) return json(404, { ok: false, erro: 'machine_id não existe' });
  const licenca = licLinhas[0];

  try {
    // ══════════════ acao: guardar_credenciais ══════════════
    if (acao === 'guardar_credenciais') {
      const username = (body.at_username as string || '').trim();
      const password = (body.at_password as string || '');
      if (!username || !password) return json(400, { ok: false, erro: 'at_username e at_password obrigatórios' });
      const gcmKey = await importarChaveGcm(await lerSecret(admin, 'at_cred_enc_key'));
      const cifrada = await gcmCifrar(password, gcmKey);
      const { error: upErro } = await admin.from('licencas')
        .update({ at_username: username, at_password_cifrada: cifrada })
        .eq('machine_id', machineId);
      if (upErro) return json(500, { ok: false, erro: upErro.message });
      return json(200, { ok: true, acao, at_username: username, configurado: true });
    }

    // ══════════════ acao: comunicar ══════════════
    if (acao === 'comunicar') {
      // Credenciais: da licenca (produção) ou, em modo teste, do Vault / body.
      let username: string;
      let password: string;
      if (modoTeste && body.usar_vault_teste) {
        username = await lerSecret(admin, 'at_ws_username_teste');
        password = await lerSecret(admin, 'at_ws_password_teste');
      } else if (modoTeste && body.test_username && body.test_password) {
        username = String(body.test_username);
        password = String(body.test_password);
      } else {
        if (!licenca.at_username || !licenca.at_password_cifrada) {
          return json(400, { ok: false, erro: 'acesso AT não configurado para esta licença' });
        }
        const gcmKey = await importarChaveGcm(await lerSecret(admin, 'at_cred_enc_key'));
        username = licenca.at_username;
        password = await gcmDecifrar(licenca.at_password_cifrada, gcmKey);
      }

      const serie = String(body.serie ?? '').trim();
      const tipoDoc = String(body.tipo_doc ?? '').trim();
      if (!serie || !tipoDoc) return json(400, { ok: false, erro: 'serie e tipo_doc obrigatórios' });

      const params: EnvelopeParams = {
        cerPem: atob(await lerSecret(admin, 'at_chave_publica_b64')),
        username,
        passwordPlain: password,
        serie,
        tipoSerie: String(body.tipo_serie ?? 'N'),
        classeDoc: String(body.classe_doc ?? 'SI'),
        tipoDoc,
        numInicialSeq: Number(body.numero_inicial ?? 1),
        dataInicio: String(body.data_inicio ?? new Date().toISOString().slice(0, 10)),
        numCert: Number(body.num_cert ?? 0),
        meioProc: String(body.meio_processamento ?? 'PF'),
      };

      const pfxB64 = await lerSecret(admin, 'at_cert_teste_pfx_b64');
      const pfxPass = await lerSecret(admin, 'at_cert_teste_password');
      const { certPem, keyPem } = pfxParaCertKey(pfxB64, pfxPass);

      const { envelope } = construirEnvelope(params);
      const resp = await enviarAt(envelope, certPem, keyPem);

      const codValidacao = extrair('codValidacaoSerie', resp.body);
      const faultString = extrair('faultstring', resp.body);
      const codResultOper = extrair('codResultOper', resp.body) ?? extrair('codResultOperacao', resp.body);
      const msgResultOper = extrair('msgResultOper', resp.body) ?? extrair('msgResultOperacao', resp.body);

      const sucesso = !!codValidacao;

      // Audit (sempre).
      await admin.from('series_comunicadas').insert({
        licenca_id: licenca.id,
        machine_id: machineId,
        serie,
        tipo_doc: tipoDoc,
        numero_inicial: params.numInicialSeq,
        data_inicio: params.dataInicio,
        codigo_validacao: codValidacao,
        resposta_at_raw: { status: resp.status, body: resp.body.slice(0, 4000) },
        erro: sucesso ? null : (faultString || msgResultOper || `HTTP ${resp.status}`),
        ambiente: 'testes',
        feito_por: actor,
      });

      if (sucesso) {
        await admin.from('licencas')
          .update({ codigo_validacao_at: codValidacao, data_comunicacao_serie: new Date().toISOString() })
          .eq('machine_id', machineId);
        return json(200, { ok: true, codigo_validacao: codValidacao, http_status: resp.status });
      }
      return json(200, {
        ok: false,
        erro: faultString || msgResultOper || 'AT não devolveu codValidacaoSerie',
        http_status: resp.status,
        cod_result_oper: codResultOper,
        resposta_at: resp.body.slice(0, 2000),
      });
    }

    return json(400, { ok: false, erro: `acção desconhecida: ${acao}` });
  } catch (e) {
    console.error('comunicar-serie erro', e);
    return json(500, { ok: false, erro: String((e as Error).message ?? e) });
  }
});
