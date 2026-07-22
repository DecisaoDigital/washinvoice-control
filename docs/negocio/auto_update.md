# Auto-update — processo de lançamento (Control)

> Task #100 (parte Control). O POS tem sprint próprio a seguir, que reutiliza
> esta mesma infra (tabela `versoes_apps` + Edge Function `versao-mais-recente`).

## Como funciona (visão de 30 segundos)

1. O Control, ao arrancar e depois a cada 6 horas, pergunta à Edge Function
   `versao-mais-recente`: "para a app `control`, há build mais alto que o meu?".
2. A function responde a partir da tabela `versoes_apps` (versão `activa` com
   `build_number` mais alto).
3. Se houver, o Control mostra um **banner amarelo** no topo com botão
   **Descarregar**, que abre o URL do APK no browser Android. O Android trata do
   download e da instalação (não há auto-install — Play Store fica para o futuro).
4. Se a versão for marcada **obrigatória**, em vez do banner aparece um **modal
   bloqueante** sem X: usar só para bug fiscal/segurança crítico.

A comparação é sempre por `build_number` (inteiro), nunca pela string de versão.
O Android também exige `versionCode` estritamente maior para actualizar.

## Lançar uma versão nova do Control — passo a passo

Sempre que compilares um APK novo para distribuir:

1. **Compilar** com a versão bumpada no `pubspec.yaml` (ex.: `1.7.1+25`). O
   número depois do `+` é o `build_number` — tem de ser **sempre maior** que o
   anterior.
2. **Criar o release no GitHub** no repo público `CesarM78/washinvoice-releases`
   (só cliques, sem código):
   - "Create new release" → tag `control-1.7.1` (por convenção `control-<versão>`).
   - Anexar o APK compilado (nome `WashInvoiceControl_v1.7.1.apk`).
   - Publicar. Copiar o URL do asset (botão direito → copiar link).
3. **Registar na base de dados** (via MCP ou SQL Editor do Supabase):
   ```sql
   insert into versoes_apps (app, versao, build_number, url_download, obrigatoria, activa)
   values ('control', '1.7.1', 25,
           'https://github.com/CesarM78/washinvoice-releases/releases/download/control-1.7.1/WashInvoiceControl_v1.7.1.apk',
           false, true);
   ```
   - `obrigatoria = true` só para correcção crítica (fiscal/segurança).
   - Deixar `activa = true`. A function escolhe sempre a activa com build mais alto.

A partir daí, qualquer Control com build inferior mostra o banner no próximo
arranque (ou dentro de 6 h).

## Nota importante sobre o seed 1.7.0

O primeiro registo (`1.7.0`, build **24**) foi semeado com um **URL placeholder**.
Antes de o APK 1.7.0 chegar às mãos de clientes, o Cesar tem de:

1. Criar o release `control-1.7.0` no GitHub e anexar o APK 1.7.0.
2. Actualizar o URL real:
   ```sql
   update versoes_apps set url_download = '<URL_real_do_asset>'
   where app = 'control' and build_number = 24;
   ```

(O build é **24** e não 23 porque a release anterior, 1.6.3, já tinha ocupado o
build 23. O Android nunca deixaria actualizar de 23 para 23.)

## Desligar ou corrigir uma versão

- Enganaste-te num URL ou notas: `update versoes_apps set url_download = '...' where build_number = N;`
- Retirar uma versão de circulação: `update versoes_apps set activa = false where build_number = N;`
  (a function volta a apontar para a activa seguinte mais alta).

## Testar (exercício manual)

1. Instalar o APK 1.7.0 (build 24). Não mostra banner (local == remoto).
2. Simular update disponível, inserindo uma versão fake mais alta:
   ```sql
   insert into versoes_apps (app, versao, build_number, url_download, obrigatoria, activa)
   values ('control', '1.7.1', 25, '<mesmo URL do 1.7.0>', false, true);
   ```
3. Fechar e reabrir o Control (ou esperar 6 h) → **banner amarelo** "Nova versão
   1.7.1 disponível".
4. Carregar **Descarregar** → abre o browser → começa o download.
5. Testar obrigatória: `update versoes_apps set obrigatoria = true where build_number = 25;`
   Reabrir → passa a **modal bloqueante**.
6. Limpar o fake: `delete from versoes_apps where build_number = 25;`

## O que fica para o POS (sprint próprio)

O POS (Windows) usará a mesma tabela (`app = 'pos'`) e a mesma function. Muda o
cliente: em Windows o "descarregar" e o "instalar" são diferentes (não há browser
Android a tratar do APK). Esse sprint arranca depois de o Control estar validado.
