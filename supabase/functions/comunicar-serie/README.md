# comunicar-serie

Edge Function que comunica **séries de facturação à AT** por webservice
(operação `registarSerie` do `SeriesWSService`), a partir do Control. Substitui
a comunicação manual no Portal das Finanças.

## Duas acções

Corre com `verify_jwt` + `is_admin()` (mesmo padrão do `gerir-licenca`), depois
com `service_role`. Não toca nas Edge Functions existentes.

### `guardar_credenciais`
Grava (cifradas) as credenciais do sub-utilizador AT do cliente. Uma vez, no setup.
```json
{ "acao": "guardar_credenciais", "machine_id": "<hash>",
  "at_username": "515307548/1", "at_password": "<password AT>" }
```
A password é cifrada com **AES-GCM** usando a chave do servidor `at_cred_enc_key`
(Supabase Vault) e guardada em `licencas.at_password_cifrada`. Nunca em plaintext,
nunca na UI, nunca cifrada com a chave pública AT (seria irreversível do nosso lado).

### `comunicar`
Comunica uma série e devolve o ATCUD-CV.
```json
{ "acao": "comunicar", "machine_id": "<hash>", "serie": "FTA2026",
  "tipo_doc": "FT", "classe_doc": "SI", "tipo_serie": "N",
  "numero_inicial": 1, "data_inicio": "2026-07-22", "meio_processamento": "OM" }
```
Resposta: `{ "ok": true, "codigo_validacao": "J6SHZMK5" }` ou
`{ "ok": false, "erro": "...", "resposta_at": "..." }`.

## Como fala com a AT (notas técnicas)

- **mTLS**: `Deno.connectTls({ cert, key })` + HTTP/1.1 escrito à mão. O
  `Deno.createHttpClient` **não** apresenta o cert de cliente no runtime da
  Supabase — só o `connectTls` funciona. A AT fecha com `Connection: close` sem
  TLS close_notify, por isso o read tolera o `UnexpectedEof` e devolve o que já veio.
- **WS-Security** (namespace antigo `http://schemas.xmlsoap.org/ws/2002/12/secext`):
  chave simétrica AES-128 aleatória por pedido → `Nonce`=RSA-PKCS1(chavePúblicaAT,Ks),
  `Password`/`Created`=AES-ECB-PKCS5(Ks, …), base64. Endpoint testes
  `:722/SeriesWSService/SeriesWS`, produção `:422`.
- Secrets no **Vault** (lidos via RPC `ler_secret_at`): `at_cert_teste_pfx_b64`,
  `at_cert_teste_password`, `at_chave_publica_b64`, `at_cred_enc_key`,
  e (só testes) `at_ws_username_teste`/`at_ws_password_teste`.

## curl (teste)

Precisa de um JWT de admin no `Authorization`:
```bash
curl -X POST "$SUPABASE_URL/functions/v1/comunicar-serie" \
  -H "Authorization: Bearer $ADMIN_JWT" -H "apikey: $ANON" \
  -H "Content-Type: application/json" \
  -d '{"acao":"comunicar","machine_id":"<hash>","serie":"FTA2026","tipo_doc":"FT","meio_processamento":"OM"}'
```

## Estado (2026-07-22)

Arquitectura mTLS provada e envelope validado contra a implementação de
referência (`hestiatechnology/autoridadetributaria`). O teste end-to-end está
**bloqueado do lado da AT**: o gateway (IBM DataPower) devolve `Internal Error`
mascarado para tudo (incl. paths inexistentes) enquanto o certificado/NIF produtor
não estiver aderido ao serviço de Comunicação de Séries de testes. Duas
implementações independentes (Deno+forge e Node nativo) dão o mesmo erro → não é
o código. Aguarda adesão/provisão da AT.

> **Antes de produção:** pôr `verify_jwt: true` e **remover o `PROBE_TOKEN`**
> (bypass de teste que salta a camada de utilizador).
