// Helpers puros de assinatura (sem efeitos) — partilhados pelo handler
// (index.ts) e pelo teste (index.test.ts). RSA + SHA-1 + PKCS#1 v1.5, o mesmo
// algoritmo que o cliente verifica com pointycastle.

/** PEM (PKCS#8) → DER (bytes). Aceita "-----BEGIN PRIVATE KEY-----". */
export function pemParaDer(pem: string): Uint8Array {
  const b64 = pem
    .replace(/-----BEGIN [^-]+-----/g, "")
    .replace(/-----END [^-]+-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

/** Bytes → base64. */
export function base64DeBytes(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

/**
 * Assina `texto` com uma chave privada RSA em PEM **PKCS#8**, usando
 * RSASSA-PKCS1-v1_5 + SHA-1 (Portaria 363/2010). Devolve a assinatura em base64.
 */
export async function assinarComPem(texto: string, pemPkcs8: string): Promise<string> {
  // `texto` é assinado TAL COMO É RECEBIDO — a função nunca reconstrói a string
  // do Art. 6.º (isso é do cliente, _stringParaAssinar), para não duplicar a
  // formatação em Dart e em Deno e arriscar divergência silenciosa.
  //
  // O Web Crypto só importa PKCS#8. Se vier PKCS#1 (openssl genrsa), falhar cedo
  // com instrução clara em vez de um erro críptico de importKey.
  if (/BEGIN RSA PRIVATE KEY/.test(pemPkcs8)) {
    throw new Error(
      "Chave em PKCS#1. Converter para PKCS#8: " +
        "openssl pkcs8 -topk8 -nocrypt -in priv.pem -out priv_pkcs8.pem",
    );
  }
  const chave = await crypto.subtle.importKey(
    "pkcs8",
    pemParaDer(pemPkcs8),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-1" },
    false,
    ["sign"],
  );
  const assinatura = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    chave,
    new TextEncoder().encode(texto),
  );
  return base64DeBytes(new Uint8Array(assinatura));
}
