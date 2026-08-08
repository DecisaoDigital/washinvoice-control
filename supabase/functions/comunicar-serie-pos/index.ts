// WashInvoice POS — comunicar-serie-pos
// Comunica uma serie fiscal ao webservice AT (registarSerie), a partir do POS.
// Nucleo SOAP + mTLS + cifra reutilizado da comunicar-serie v16 (provado contra
// a sandbox). Auth: verify_jwt=false; valida instalacao por machine_id +
// licenca activa (o gate de perfil e local no POS). Dispatcher de ambiente
// (teste/producao). Credenciais WSE por cliente, cifradas com at_cred_enc_key.
// PRODUCAO assume envelope/cifra identicos a sandbox (nao validado; task #120).

import { createClient, SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2.39.0';
import forge from 'https://esm.sh/node-forge@1.3.1';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_ROLE = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const AT_HOST = 'servicos.portaldasfinancas.gov.pt';
const AT_PATH = '/SeriesWSService/SeriesWS';
const AT_PORT_TESTE = 722;
const AT_PORT_PRODUCAO = 422;
const AT_NS = 'http://at.gov.pt/';
const WSSE_NS = 'http://schemas.xmlsoap.org/ws/2002/12/secext';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function json(status: number, data: unknown) {
  return new Response(JSON.stringify(data), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

function xmlEscape(s: string): string {
  return s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

async function lerSecret(sb: SupabaseClient, nome: string): Promise<string> {
  const { data, error } = await sb.rpc('ler_secret_at', { p_nome: nome });
  if (error) throw new Error(`vault ${nome}: ${error.message}`);
  if (!data || typeof data !== 'string') throw new Error(`vault ${nome}: vazio`);
  return data;
}

async function importarChaveGcm(b64: string): Promise<CryptoKey> {
  const raw = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  return crypto.subtle.importKey('raw', raw, { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
}

async function gcmDecifrar(b64: string, key: CryptoKey): Promise<string> {
  const all = Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));
  const iv = all.slice(0, 12);
  const ct = all.slice(12);
  const pt = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, ct);
  return new TextDecoder().decode(pt);
}

function pfxParaCertKey(pfxB64: string, pass: string): { certPem: string; keyPem: string } {
  const der = forge.util.decode64(pfxB64.replace(/\s+/g, ''));
  const p12 = forge.pkcs12.pkcs12FromAsn1(forge.asn1.fromDer(der), pass);
  let keyObj = p12.getBags({ bagType: forge.pki.oids.pkcs8ShroudedKeyBag })[forge.pki.oids.pkcs8ShroudedKeyBag]?.[0]?.key;
  if (!keyObj) keyObj = p12.getBags({ bagType: forge.pki.oids.keyBag })[forge.pki.oids.keyBag]?.[0]?.key;
  if (!keyObj) throw new Error('chave privada nao encontrada no PFX');
  const keyPem = forge.pki.privateKeyToPem(keyObj);
  const certBags = p12.getBags({ bagType: forge.pki.oids.certBag })[forge.pki.oids.certBag] ?? [];
  const leaf = certBags.find((b: any) => (b.cert?.subject?.getField('CN')?.value || '').includes('TesteWebservices')) ?? certBags[0];
  if (!leaf) throw new Error('cert nao encontrado no PFX');
  return { certPem: forge.pki.certificateToPem(leaf.cert), keyPem };
}

function carregarPublicKey(pem: string): any {
  try {
    return (forge.pki.certificateFromPem(pem) as any).publicKey;
  } catch (_) {
    return forge.pki.publicKeyFromPem(pem);
  }
}

function aesEcbBase64(symKeyBin: string, plaintext: string): string {
  const cipher = forge.cipher.createCipher('AES-ECB', symKeyBin);
  cipher.start();
  cipher.update(forge.util.createBuffer(forge.util.encodeUtf8(plaintext)));
  cipher.finish();
  return forge.util.encode64(cipher.output.getBytes());
}

interface EnvelopeParams {
  cifraPublicaPem: string; username: string; passwordPlain: string; serie: string;
  tipoSerie: string; classeDoc: string; tipoDoc: string; numInicialSeq: number;
  dataInicio: string; numCert: string; meioProc: string;
}

function construirEnvelope(p: EnvelopeParams): { envelope: string } {
  const symKey = forge.random.getBytesSync(16);
  const pubKey = carregarPublicKey(p.cifraPublicaPem);
  const nonceCifrado = forge.util.encode64(pubKey.encrypt(symKey, 'RSAES-PKCS1-V1_5'));
  const created = new Date().toISOString();
  const passwordCifrada = aesEcbBase64(symKey, p.passwordPlain);
  const createdCifrado = aesEcbBase64(symKey, created);
  const envelope = '<?xml version="1.0" encoding="UTF-8"?>' +
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
  return { envelope };
}

async function enviarAt(envelope: string, certPem: string, keyPem: string, port: number): Promise<{ status: number; body: string }> {
  // @ts-ignore
  const conn: Deno.Conn = await Deno.connectTls({ hostname: AT_HOST, port, cert: certPem, key: keyPem });
  const enc = new TextEncoder();
  const bodyBytes = enc.encode(envelope);
  const req = `POST ${AT_PATH} HTTP/1.1\r\nHost: ${AT_HOST}:${port}\r\nContent-Type: text/xml; charset=utf-8\r\nSOAPAction: ''\r\nContent-Length: ${bodyBytes.length}\r\nConnection: close\r\n\r\n`;
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
    } catch (_e) { /* UnexpectedEof */ }
    const total = new Uint8Array(chunks.reduce((a, c) => a + c.length, 0));
    let off = 0;
    for (const c of chunks) { total.set(c, off); off += c.length; }
    const raw = new TextDecoder().decode(total);
    const sep = raw.indexOf('\r\n\r\n');
    const headSect = sep >= 0 ? raw.slice(0, sep) : raw;
    const bodyR = sep >= 0 ? raw.slice(sep + 4) : '';
    const sm = headSect.match(/^HTTP\/\d\.\d (\d+)/);
    return { status: sm ? parseInt(sm[1], 10) : 0, body: bodyR };
  } finally {
    try { conn.close(); } catch { /* */ }
  }
}

function extrair(tag: string, xml: string): string | null {
  const m = xml.match(new RegExp(`<(?:\\w+:)?${tag}[^>]*>([\\s\\S]*?)</(?:\\w+:)?${tag}>`, 'i'));
  return m ? m[1].trim() : null;
}

async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return Array.from(new Uint8Array(buf)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

async function carregarTeste(sb: SupabaseClient) {
  const pfxB64 = await lerSecret(sb, 'at_cert_teste_pfx_b64');
  const pfxPass = await lerSecret(sb, 'at_cert_teste_password');
  const { certPem, keyPem } = pfxParaCertKey(pfxB64, pfxPass);
  const cifraPem = atob(await lerSecret(sb, 'at_chave_publica_b64'));
  return { certPem, keyPem, cifraPem, port: AT_PORT_TESTE };
}

async function carregarProducao(sb: SupabaseClient) {
  const leaf = await lerSecret(sb, 'at_prod_cert_pem');
  const ca2 = await lerSecret(sb, 'at_prod_ca2_pem');
  const root = await lerSecret(sb, 'at_prod_root_ca_pem');
  const certPem = [leaf, ca2, root].map((s) => s.trim()).join('\n');
  const keyPem = await lerSecret(sb, 'at_prod_private_key_pem');
  const cifraPem = await lerSecret(sb, 'at_prod_cifra_publica_pem');
  return { certPem, keyPem, cifraPem, port: AT_PORT_PRODUCAO };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json(405, { sucesso: false, erro: 'method not allowed' });

  let body: any;
  try { body = await req.json(); } catch { return json(400, { sucesso: false, erro: 'body invalido' }); }

  const ambiente = body.ambiente as string;
  if (ambiente !== 'teste' && ambiente !== 'producao') {
    return json(400, { sucesso: false, erro: "Parametro 'ambiente' obrigatorio: 'teste' ou 'producao'.", codigo_erro: 'AMBIENTE_INVALIDO' });
  }

  const machineId = body.machine_id as string | undefined;
  if (!machineId || typeof machineId !== 'string' || machineId.length < 4) {
    return json(400, { sucesso: false, erro: 'machine_id obrigatorio', ambiente });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE, { auth: { persistSession: false } });

  const { data: licLinhas, error: licErro } = await admin.from('licencas').select('*').eq('machine_id', machineId).order('validade', { ascending: false }).limit(1);
  if (licErro) return json(500, { sucesso: false, erro: licErro.message, ambiente });
  const licenca = licLinhas?.[0];
  if (!licenca) return json(403, { sucesso: false, erro: 'Instalacao sem licenca valida.', codigo_erro: 'LICENCA_INVALIDA', ambiente });

  const serie = String(body.serie ?? '').trim();
  const tipoDoc = String(body.tipo_doc ?? '').trim();
  if (!serie || !tipoDoc) return json(400, { sucesso: false, erro: 'serie e tipo_doc obrigatorios', ambiente });

  const operadorId = typeof body.operador_id === 'number' ? body.operador_id : null;
  const operadorNome = typeof body.operador_nome === 'string' ? body.operador_nome : null;

  try {
    const { data: cred, error: credErro } = await admin.from('credenciais_wse_cliente').select('username_cifrado, password_cifrada').eq('licenca_id', licenca.id).eq('ambiente', ambiente).maybeSingle();
    if (credErro) return json(500, { sucesso: false, erro: credErro.message, ambiente });
    if (!cred) return json(200, { sucesso: false, erro: `Sem credenciais WSE para ambiente '${ambiente}'. O admin tem de as introduzir primeiro.`, codigo_erro: 'SEM_CREDENCIAIS', ambiente });

    const gcmKey = await importarChaveGcm(await lerSecret(admin, 'at_cred_enc_key'));
    const username = await gcmDecifrar(cred.username_cifrado, gcmKey);
    const password = await gcmDecifrar(cred.password_cifrada, gcmKey);

    const amb = ambiente === 'producao' ? await carregarProducao(admin) : await carregarTeste(admin);

    const params: EnvelopeParams = {
      cifraPublicaPem: amb.cifraPem, username, passwordPlain: password, serie,
      tipoSerie: String(body.tipo_serie ?? 'N'), classeDoc: String(body.classe_doc ?? 'SI'), tipoDoc,
      numInicialSeq: Number(body.numero_inicial ?? 1),
      dataInicio: String(body.data_inicio ?? new Date().toISOString().slice(0, 10)),
      numCert: String(body.num_cert ?? '0'), meioProc: String(body.meio_processamento ?? 'PF'),
    };
    const { envelope } = construirEnvelope(params);
    const requestHash = await sha256Hex(envelope);
    const resp = await enviarAt(envelope, amb.certPem, amb.keyPem, amb.port);

    const codValidacao = extrair('codValidacaoSerie', resp.body);
    const faultString = extrair('faultstring', resp.body);
    const msgResultOper = extrair('msgResultOper', resp.body);
    const sucesso = !!codValidacao;

    await admin.from('series_comunicadas').insert({
      licenca_id: licenca.id, machine_id: machineId, ambiente, serie, tipo_doc: tipoDoc,
      numero_inicial: params.numInicialSeq, data_inicio: params.dataInicio,
      codigo_validacao: codValidacao,
      resposta_at_raw: { status: resp.status, body: resp.body.slice(0, 4000) },
      erro: sucesso ? null : (faultString || msgResultOper || `HTTP ${resp.status}`),
      operador_id: operadorId, operador_nome: operadorNome, request_hash: requestHash,
      feito_por: operadorNome ?? 'pos',
    });

    if (sucesso) return json(200, { sucesso: true, codigo_at: codValidacao, ambiente, mensagem: 'Serie comunicada.' });
    return json(200, { sucesso: false, erro: faultString || msgResultOper || 'AT nao devolveu codValidacaoSerie', codigo_erro: faultString ? 'SOAP_FAULT' : 'AT_REJEITOU', ambiente });
  } catch (e) {
    console.error('comunicar-serie-pos erro', e);
    return json(500, { sucesso: false, erro: String((e as Error).message ?? e), codigo_erro: 'REDE', ambiente });
  }
});
