# versao-mais-recente

Diz a uma instalação se há build novo disponível. Usada pelo auto-update do
Control e do Fist (e, no futuro, do POS — reutiliza esta mesma function e a
tabela `versoes_apps`).

- **Método:** `POST /functions/v1/versao-mais-recente`
- **Auth:** `verify_jwt: true`. Precisa de um JWT válido no header `Authorization`
  (o do utilizador com sessão). Sem gate de admin — qualquer instalação
  autenticada pode perguntar. A leitura é feita com service_role.
- **Não muta nada.** Só lê `versoes_apps`.

## Pedido

```json
{
  "app": "control",
  "build_number_local": 23
}
```

`app` ∈ `{ "control", "pos", "punho" }`. `build_number_local` é o `buildNumber`
do `PackageInfo` (o número depois do `+` no `pubspec.yaml`).

## Resposta — há actualização

```json
{
  "actualizacao_disponivel": true,
  "versao_actual": "1.7.0",
  "build_number": 24,
  "url_download": "https://github.com/CesarM78/washinvoice-releases/releases/download/control-1.7.0/WashInvoiceControl_v1.7.0.apk",
  "obrigatoria": false,
  "notas_lancamento": "...",
  "sha256": "fb95759c1937fb0adeb7b16bb89a8d355be1691a9abfa9377f391560b98de987"
}
```

`sha256` vem directo da coluna `versoes_apps.sha256` e pode ser `null` — uma
versão catalogada sem hash publicado. É o que o instalador automático (Control
e Fist) usa para confirmar o APK descarregado antes de o instalar; sem ele o
cliente cai sempre para o browser.

## Resposta — já actualizado

```json
{ "actualizacao_disponivel": false }
```

Devolve `actualizacao_disponivel: false` também quando não há nenhuma versão
activa catalogada para a app.

## Erros

- `400 { "erro": "app inválida" }` — `app` fora de `{control, pos}`.
- `400 { "erro": "build_number_local tem de ser um número" }`.
- `500 { "erro": "..." }` — falha a ler a tabela.

## Exemplo curl

```bash
curl -X POST \
  'https://oefqbkhioncakojipqyx.supabase.co/functions/v1/versao-mais-recente' \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"app":"control","build_number_local":23}'
```

`$ACCESS_TOKEN` é o `access_token` de uma sessão autenticada (não a anon key).

## Comparação

A decisão é sempre por `build_number` (inteiro monotónico), nunca pela string de
versão. O Android também exige `versionCode` estritamente maior para actualizar,
por isso as duas coisas andam a par.
