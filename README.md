# WashInvoice Control

Aplicação Flutter de administração do WashInvoice. Serve para acompanhar instalações, licenças, pedidos de renovação, últimos acessos, versões instaladas, localização das máquinas e emissão manual do `licenca.json`.

## Funcionalidades principais

- Login com Supabase Auth.
- Dashboard com licenças ativas, a expirar, expiradas e pedidos pendentes.
- Deteção de novas instalações através de pings sem licença associada.
- Ativação de instalações e criação de clientes/licenças.
- Renovação, suspensão e reativação de licenças.
- Geração manual do `licenca.json` assinado, com verificação de colisão de série por terminal.
- Histórico de acessos, versão instalada e estado dos Termos & Condições.

## Estrutura

```text
lib/
  core/          Configuração, tema, datas, versões e tratamento de erros
  features/      Ecrãs por área funcional
  models/        Modelos de domínio
  repositories/  Acesso ao Supabase
  services/      Emissão e assinatura de licenças
supabase/        Scripts SQL auxiliares
test/            Testes de compatibilidade da emissão de licenças
```

## Requisitos

- Flutter com Dart compatível com o SDK definido em `pubspec.yaml`.
- Projeto Supabase configurado.
- Android Studio/SDK ou outro alvo Flutter suportado.

## Configuração

1. Instalar dependências:

   ```bash
   flutter pub get
   ```

2. Confirmar a configuração do Supabase em:

   ```text
   lib/core/supabase_config.dart
   ```

   A `anonKey` é pública e pode estar no cliente desde que as políticas RLS estejam corretas. Nunca colocar a chave `service_role` na app.

3. Aplicar no Supabase os scripts necessários, conforme o estado da base de dados:

   ```text
   supabase/adicionar_serie_licencas.sql
   supabase/adicionar_oferta_licencas.sql
   supabase/rls_policies.sql            # RLS — ver "Segurança da base de dados"
   ```

4. Opcionalmente carregar dados de demonstração:

   ```text
   supabase/seed_demo.sql
   ```

   Para limpar os dados demo:

   ```text
   supabase/limpar_demo.sql
   ```

## Desenvolvimento

Executar a app:

```bash
flutter run
```

Analisar o código:

```bash
flutter analyze
```

Correr testes:

```bash
flutter test
```

Os testes em `test/licenca_emissao_test.dart` protegem a compatibilidade entre o Control e a emissão/validação de licenças do WashFactura. Se estes testes falharem, uma licença gerada por uma app pode deixar de ser aceite pela outra.

## Notas operacionais

- A emissão do `licenca.json` é uma ação manual: deve ser usada depois de confirmar o pagamento ou marcar a licença como oferta.
- Cada terminal deve ter a sua própria série documental.
- Antes de produção, rever a estratégia de assinatura das licenças. Uma chave HMAC simétrica embutida no cliente é adequada para beta controlado, mas não é ideal contra extração do binário.
- Artefactos locais/exportados, como `*.zip`, estão ignorados pelo Git.

## Segurança da base de dados

> ⚠️ **Sem o `supabase/rls_policies.sql` aplicado, a base está ABERTA.** A
> `anonKey` está embutida no binário Android; qualquer pessoa que a extraia
> consegue ler/escrever tudo enquanto o Row Level Security (RLS) não estiver
> ligado. Aplicar as policies é obrigatório antes de expor a app a terceiros.

O modelo de acesso (ver [`supabase/rls_policies.sql`](supabase/rls_policies.sql)):

- **`anon`** (chave pública): sem acesso a tabelas de dados. O único caminho é o
  RPC `registar_ping_inicial(...)`, para máquinas novas ainda sem licença.
- **POS autenticado**: lê só a sua licença (`user_id = auth.uid()`) e insere
  pings/aceites/pedidos da própria máquina.
- **Admin Control** (utilizador em `public.admins`): acesso total, sem DELETE.

### Aplicar as policies num Supabase novo

1. Correr `supabase/rls_policies.sql` no SQL Editor (é idempotente).
2. Confirmar `rowsecurity = true` nas 5 tabelas (queries no topo do
   `supabase/rls_verificacao.md`).
3. Correr o protocolo de verificação em `supabase/rls_verificacao.md`.

### Criar o utilizador admin inicial

1. Supabase Dashboard → Authentication → Users → criar utilizador (email+password).
2. Copiar o UUID e inseri-lo na tabela `admins`:

   ```sql
   insert into public.admins (user_id) values ('<uuid-do-utilizador>')
   on conflict (user_id) do nothing;
   ```

3. Sem este passo, `is_admin()` devolve `false` para todos e o Control
   autenticado fica sem acesso a nenhuma tabela.

### Provisionar um terminal (POS) — manual, nesta fase

Para os primeiros clientes o provisionamento é manual:

1. Criar um utilizador Auth para o terminal (Authentication → Users).
2. Ao emitir a licença no Control, colar o **UUID** desse utilizador no campo
   *«User ID do terminal»* → fica gravado em `licencas.user_id`.
3. Entregar o email+password ao terminal **fora do `licenca.json`** (o
   `licenca.json` é assinado e não deve transportar credenciais).

### Roadmap de segurança (rondas seguintes)

- Automatizar o provisionamento (Edge Function com `service_role` a criar o
  utilizador Auth e a ligar `licencas.user_id`) — remove o passo manual.
- Migrar a assinatura das licenças de HMAC simétrico para **Ed25519**
  (chave privada fora do cliente).
- Rate-limit por IP no `registar_ping_inicial(...)` contra flood de pings anónimos.
- Migrar o WashFactura POS de leitura anónima por `machine_id` para leitura
  autenticada por `auth.uid()` (pré-requisito para terminais em produção — ver
  `supabase/rls_verificacao.md`).
