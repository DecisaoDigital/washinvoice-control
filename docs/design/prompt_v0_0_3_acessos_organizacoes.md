# v0.0.3 — Organizações, utilizadores e aprovações manuais

## Objetivo

Transformar a autenticação atual numa gestão multi-organização segura. Cada
conta pertence a uma única organização e só pode ver dados dessa organização.
Nenhuma conta obtém acesso automaticamente: todas aguardam validação manual no
DesignDigital Control central.

Esta é uma evolução da versão oficial **v0.0.2**. Não alterar a numeração
oficial sem indicação explícita.

## Perfis

- **Admin global DesignDigital**: é o proprietário do Control. Vê todas as
  organizações, todos os pedidos e pode aprovar, recusar e revogar acessos.
- **Gerente da organização**: aprovado pelo admin global; vê dados apenas da
  sua organização e pode gerar convites para pessoas dessa organização.
- **Funcionário**: aprovado pelo admin global; vê e trabalha apenas nos dados
  da sua organização; não gere utilizadores nem convites.

## Registo

No ecrã de entrada deve existir `Criar conta`, com:

1. Nome.
2. Email.
3. Palavra-passe escolhida pelo utilizador.
4. Organização indicada.
5. Cargo pretendido: `Administrador` ou `Funcionário`.
6. Código de convite opcional.

Usar `Supabase.auth.signUp`. Nunca guardar passwords na base de dados da app;
o Supabase Auth trata do hash em `auth.users`.

O pedido de acesso deve ser criado por trigger a partir de `auth.users`, não
por uma chamada posterior da app: assim funciona quando a confirmação de email
está ligada e o utilizador ainda não tem sessão.

## Origem de entrada

Cada pedido tem obrigatoriamente uma das duas origens:

- `livre`: utilizador preenche a organização; não fica associado a nenhuma
  organização até o admin global decidir.
- `convite`: código válido emitido por um gerente; o pedido é associado à
  organização do convite, mas fica igualmente pendente da aprovação global.

O Control deve exibir claramente `Pedido livre` ou `Por convite`.

## Aprovação manual no Control

Criar o separador **Acessos** para o admin global. Para cada pedido pendente,
mostrar nome, email, organização indicada, cargo, origem, data e ocupação da
organização (`ativos / limite`).

Permitir:

- **Aprovar**: para pedido livre, escolher uma organização existente ou criar
  uma nova; para convite, conservar a organização do convite.
- **Recusar**: mantém histórico e não concede acesso.
- **Revogar**: disponível para utilizadores já aprovados; remove o acesso de
  imediato e liberta uma vaga.

O admin global confirma por telefone/email com o empresário antes de aprovar.
Não integrar pagamentos ou aprovação automática nesta versão.

## Limites de utilizadores

Cada organização tem `limite_utilizadores` e a contagem de contas aprovadas.
O sistema nunca aprova automaticamente acima do limite. O Control mostra o
aviso e o admin global decide depois de tratar comercialmente da vaga extra.

## Convites de gerente

Para um gerente aprovado, o separador **Acessos** abre a página
`Convidar funcionário`, não a gestão global.

O gerente indica email e cargo. O sistema cria um código aleatório, válido por
14 dias, vinculado ao email, cargo e organização do gerente. O gerente partilha
o código por email/WhatsApp; o envio automático de emails não faz parte desta
versão.

Um convite usado, expirado ou revogado não pode ser reutilizado.

## Base de dados e RLS

Criar/usar estas tabelas:

- `organizacoes`: `id`, `nome`, `limite_utilizadores`, datas.
- `pedidos_acesso`: `user_id`, `email`, `nome`, `organizacao_indicada`,
  `organizacao_id`, `cargo`, `origem`, `convite_id`, `estado`, datas e decisor.
- `convites_organizacao`: organização, código, email alvo, cargo, expiração,
  revogação e utilizador que o consumiu.

Todas as tabelas operacionais relevantes recebem `organizacao_id`, pelo menos
`clientes`, `licencas`, `pings`, `aceites_termos` e `pedidos_renovacao`.

Regras obrigatórias de RLS:

1. Admin global vê/escreve tudo que já podia gerir.
2. Conta aprovada só pode selecionar, inserir ou atualizar linhas cujo
   `organizacao_id` seja o da sua própria organização.
3. Não criar policies `DELETE` permissivas.
4. Trigger de inserção preenche `organizacao_id` para contas de organização.
5. Dados existentes ficam sem organização até migração manual; só o admin
   global os vê. Nunca associar ou expor dados antigos por suposição.
6. Funções `SECURITY DEFINER` devem definir `search_path = public`, validar
   `auth.uid()`/perfil e revogar `execute` de `public` antes de conceder apenas
   a `authenticated`.

## Arranque da app

Ter sessão Supabase não basta. No arranque consultar o estado do pedido:

- `aprovado` → abre a app.
- `pendente` → ecrã “Pedido em análise”.
- `recusado`/`revogado` → ecrã “Acesso indisponível”.

Esses ecrãs incluem terminar sessão. Não navegar diretamente para o HomeShell
logo após `signInWithPassword`; deixar o gate de sessão decidir.

## Migração e segurança

Entregar um SQL idempotente separado, a executar depois de `rls_policies.sql`.
Não alterar silenciosamente `auth.users` nem apagar dados. Documentar o passo
de bootstrap: o primeiro utilizador do proprietário tem de ser inserido em
`public.admins` para poder usar o Control global.

## Critérios de aceitação

1. Novo utilizador consegue criar conta com email e password próprios.
2. Surge um pedido pendente com origem correta.
3. Conta pendente não abre dados após login.
4. Admin global aprova pedido livre numa organização nova ou existente.
5. Gerente gera convite; registo com o código fica ligado à organização certa,
   mas continua pendente.
6. Ao aprovar duas contas da mesma organização, ambas veem os mesmos dados.
7. Uma conta de outra organização não consegue ler, escrever nem inferir esses
   dados por UI, REST ou RPC.
8. Revogar uma conta bloqueia o acesso no próximo arranque e liberta uma vaga.
9. O limite de utilizadores bloqueia aprovação até o admin global o aumentar.
10. Testes automatizados cobrem registo, estados de acesso, convite e RLS; a
    app compila e é testada num telemóvel antes de publicar.
