# `gerir-licenca`

Mutações de licença a partir do Control. Corre com service_role, mas **só depois
de confirmar que o caller é administrador**.

## Porque existe

O Control escrevia em `licencas` com a anon key + JWT, o que obriga a policy de
`licencas` a ficar aberta. Com toda a mutação a passar por aqui, o dia em que a
RLS fechar o Control continua a funcionar sem alterações de código.

## Autorização — duas camadas

`verify_jwt: true` garante que há um JWT válido, mas **não** diz que é o Cesar:
a anon key também produz JWTs válidos. Daí a segunda camada:

1. Cliente com a **anon key + o header `Authorization` do caller** → `getUser()`
   e `is_admin()`.
2. Só depois, cliente **service_role** para a mutação.

`public.is_admin()` **não aceita argumentos** — lê `auth.uid()` internamente.
Por isso tem de correr no contexto do utilizador: chamado a partir do cliente
service_role, `auth.uid()` é nulo e devolveria sempre `false`.

Respostas: `401` sem JWT ou JWT inválido; `403` autenticado mas fora de
`public.admins`.

## Endpoint

`POST /functions/v1/gerir-licenca`

```json
{
  "acao": "prolongar",
  "machine_id": "<hash>",
  "parametros": { "dias": 5 }
}
```

## Acções

| Acção              | Parâmetros                  | Efeito                                                |
| ------------------ | --------------------------- | ----------------------------------------------------- |
| `prolongar`        | `{ "dias": 5\|15\|30 }`     | `validade = max(validade, hoje) + dias`               |
| `definir_validade` | `{ "validade": "AAAA-MM-DD" }` | `validade = <data>` **e** `activa = true`          |
| `suspender`        | —                           | `activa = false`                                       |
| `reactivar`        | —                           | `activa = true`                                        |
| `cancelar`         | —                           | `activa = false`, `validade = hoje` (não apaga linha)  |
| `mudar_tier`       | `{ "tier": "base"\|"pro" }` | `tier = <valor>`                                       |

`definir_validade` é a renovação com data escolhida à mão (o `prolongar` só
cobre 5/15/30). Reactiva também: renovar uma licença suspensa sem a reactivar
deixaria o terminal bloqueado apesar de pago.

`prolongar` parte de **hoje** quando a licença já expirou — senão prolongar uma
licença caducada há um mês daria uma validade ainda no passado.

`mudar_tier` para `base` **não** limpa `preferencias_features`: os interruptores
ficam guardados para retomar num upgrade futuro.

### `plano` não se toca

`licencas.plano` é a **duração** (`mensal`, `trimestral`, `trial`…) e entra na
base da assinatura HMAC do `licenca.json` do POS
(`nif|machine_id|validade|plano[|serie]`). Alterá-la invalidaria a licença
instalada no terminal, sem erro visível até o POS recusar assinar. O nível
comercial vive em `licencas.tier`, fora da assinatura.

## Resposta

```json
{
  "ok": true,
  "acao": "prolongar",
  "machine_id": "<hash>",
  "licenca_actualizada": {
    "activa": true,
    "validade": "2026-08-21",
    "tier": "pro",
    "plano": "anual",
    "preferencias_features": { "guias": true }
  }
}
```

Erros: `400` acção ou parâmetros inválidos; `401` não autenticado; `403` não
admin; `404` `machine_id` inexistente; `405` método errado; `500` erro de BD.
Todos com `{ "ok": false, "erro": "..." }`.

## Auditoria

Escreve em **`public.licencas_audit`** (não há tabela `audit_licencas`).

Cada acção produz **duas** linhas:

| Origem                       | `acao`   | `actor_uid`             |
| ---------------------------- | -------- | ----------------------- |
| Trigger `registar_audit_licenca` | `null`   | `null` (service_role)   |
| Insert explícito da function | preenchida | utilizador verificado |

O trigger não sabe quem é o caller — corremos como service_role, não há
`auth.uid()`. A linha explícita é a que responde a "quem fez o quê". O modal de
historial no Control filtra por **`acao is not null`** para mostrar só estas; a
linha do trigger fica como rede de segurança para escritas directas em SQL.

## Exemplos

```bash
# prolongar 15 dias
curl -X POST 'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/gerir-licenca' \
  -H "Authorization: Bearer $JWT_ADMIN" -H 'Content-Type: application/json' \
  -d '{"acao":"prolongar","machine_id":"abc123","parametros":{"dias":15}}'

# suspender
curl -X POST '.../gerir-licenca' -H "Authorization: Bearer $JWT_ADMIN" \
  -H 'Content-Type: application/json' \
  -d '{"acao":"suspender","machine_id":"abc123","parametros":{}}'

# promover a Pro
curl -X POST '.../gerir-licenca' -H "Authorization: Bearer $JWT_ADMIN" \
  -H 'Content-Type: application/json' \
  -d '{"acao":"mudar_tier","machine_id":"abc123","parametros":{"tier":"pro"}}'
```

`$JWT_ADMIN` é o `access_token` de uma sessão iniciada com a conta do Cesar —
a anon key sozinha devolve `403`.
