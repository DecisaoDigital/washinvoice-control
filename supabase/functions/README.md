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

### `gerir-licenca/`

Mutações de licença a partir do **Control** (prolongar, definir validade,
suspender, reactivar, cancelar, mudar tier). Corre com service_role depois de
confirmar `is_admin()`. Ver o README próprio da função.

`verify_jwt: true` **+ verificação de admin** — o Control chama com o session
token do utilizador, injectado explicitamente (ver abaixo).

## Quem chama com que credencial

| Origem        | Credencial no `Authorization`                   | Como |
| ------------- | ----------------------------------------------- | ---- |
| POS           | JWT anon / publishable key                      | auto-injectada pelo `supabase_flutter` |
| Control       | **session token do utilizador** (`accessToken`) | injectado **explicitamente** pelo cliente Flutter |
| Triggers/curl | `EDGE_INVOKE_SECRET`                            | header à mão (só `enviar-push`) |

A distinção importa: `verify_jwt: true` só garante que **existe** um JWT válido
— e a anon key produz um. Uma função que precise de saber **quem** chama (o
caso de `gerir-licenca`, que verifica `is_admin()`) tem de receber o token da
sessão. Com a anon key, o `getUser()` dentro da função não encontra utilizador
e devolve 401.

Por isso o `GerirLicencaService` do Control passa o header à mão:

```dart
final sessao = supabase.auth.currentSession;   // null → erro claro ao utilizador
supabase.functions.invoke('gerir-licenca', body: body,
    headers: {'Authorization': 'Bearer ${sessao.accessToken}'});
```

## Deploy

Via Supabase MCP (`deploy_edge_function`), Supabase CLI (`supabase functions deploy`), ou dashboard.

Os secrets são geridos separadamente (Dashboard → Edge Functions → Secrets):

- `FCM_SERVICE_ACCOUNT_JSON` (para `enviar-push`)
- `EDGE_INVOKE_SECRET` (para `enviar-push`)
- `RSA_PRIVATE_KEY` (para `assinar-documento`)

`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` são auto-injectados pelo runtime.

## Regra dourada

Se editares uma função aqui, **redeploya no Supabase**. Se editares na consola web do Supabase, **actualiza aqui**. Nunca deixar as duas versões divergir.
