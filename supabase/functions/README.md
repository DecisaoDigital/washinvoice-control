# Edge Functions — WashInvoice

Cópias versionadas das Edge Functions deployadas no Supabase `oefqbkhioncakojipqyx`. Este directório **quer ser** a fonte de verdade para o código das funções — se o Supabase perder a função, redeployamos a partir daqui.

> **Não era, até 8 de Agosto de 2026.** Um levantamento contra o projecto
> encontrou catorze funções em produção e sete sem ficheiro em repositório
> nenhum; e das que cá estavam, **duas estavam desactualizadas** —
> `versao-mais-recente` (sem `punho_op` na lista de apps: um redeploy daqui
> teria partido o auto-update do Punho OP) e `enviar-push` (anterior à v8, sem
> o prefixo `[POS]`/`[PUNHO]` no título). As três do POS que faltavam —
> `sincronizar-empresa`, `guardar-credenciais-wse-pos`, `comunicar-serie-pos` —
> foram recuperadas de produção e estão agora aqui.
>
> O inventário completo das catorze, com quem serve cada uma e onde vive o
> código, está em `punho/supabase/functions/README.md`. As funções multi-app
> (`validar-licenca`, `registar-terminal`, `enviar-sugestao`) vivem no
> repositório do Punho, não neste.

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

A regra estava escrita e mesmo assim divergiram — porque uma divergência não
dá erro nenhum, só espera. Para a apanhar, comparar a data de publicação com
a do último commit:

```bash
# updated_at de cada função (list_edge_functions) vs git log da pasta
for d in supabase/functions/*/; do
  echo "$(basename $d): $(git log -1 --format=%ad --date=short -- $d)"
done
```

Publicação mais recente que o commit = alguém editou fora daqui, e um
`deploy` a partir do repositório vai reverter produção sem deixar rasto.
