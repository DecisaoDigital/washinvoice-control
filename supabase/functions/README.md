# Edge Functions — WashInvoice

Cópias versionadas das Edge Functions deployadas no Supabase `oefqbkhioncakojipqyx`. Este directório é a **fonte de verdade** para o código das funções — se o Supabase perder a função, redeployamos a partir daqui.

## Funções

### `enviar-push/`

Push notifications FCM para o admin. Chamada por:

- Triggers DB (`trg_notificar_inicio` em `pings`, `trg_notificar_pedido_ajuda` em `pedidos_ajuda`)
- Curl manual do Cesar (para testes / notificações ad-hoc)

Autenticação: `Authorization: Bearer <EDGE_INVOKE_SECRET>` (secret partilhado, guardado nos Edge Function Secrets e no `supabase_vault` para uso dos triggers).

`verify_jwt: false` — usa auth custom via secret.

### `assinar-documento/`

Assinatura fiscal RSA (Portaria 363/2010, Art. 6.º) para o POS WashFactura. Chamada apenas pelo POS via `Supabase.instance.client.functions.invoke('assinar-documento')`.

Chave privada em secret `RSA_PRIVATE_KEY` (nunca no cliente).

`verify_jwt: true` — POS chama com JWT anon (auto-injectado pelo supabase_flutter).

## Deploy

Via Supabase MCP (`deploy_edge_function`), Supabase CLI (`supabase functions deploy`), ou dashboard.

Os secrets são geridos separadamente (Dashboard → Edge Functions → Secrets):

- `FCM_SERVICE_ACCOUNT_JSON` (para `enviar-push`)
- `EDGE_INVOKE_SECRET` (para `enviar-push`)
- `RSA_PRIVATE_KEY` (para `assinar-documento`)

`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` são auto-injectados pelo runtime.

## Regra dourada

Se editares uma função aqui, **redeploya no Supabase**. Se editares na consola web do Supabase, **actualiza aqui**. Nunca deixar as duas versões divergir.
