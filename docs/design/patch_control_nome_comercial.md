# Patch Control — mostrar nome_comercial + designacao_social no DetalheClienteScreen

> Adição pequena. Meter no mesmo branch `feature/painel-controlo-remoto` (ainda sem merge, à espera do fix do 401 já feito localmente pelo Cesar).

## Contexto

Migration já aplicada em produção:
- `licencas.nome_comercial text nullable`
- `clientes.nome_comercial text nullable`

O modelo `Licenca` (em `lib/models/licenca.dart`) e/ou `Cliente` precisa de campo `nomeComercial`. O ecrã `DetalheClienteScreen` deve mostrar os dois nomes no cabeçalho — nome comercial em destaque (é como o cliente é conhecido), designação social em subtítulo pequeno (é o legal).

## O que muda

### 1) Modelo

Em `lib/models/licenca.dart` (e `lib/models/cliente.dart` se existir), adicionar `nomeComercial: String?`. `fromMap` lê `nome_comercial`. `toMap` inclui-o.

### 2) Repositório

`licencas_repository.dart` e/ou `clientes_repository.dart` — os `select()` já trazem `*` ou explicitam colunas. Se explicitam, adicionar `nome_comercial`.

### 3) UI — `DetalheClienteScreen`

No cabeçalho actual (título + `WiBadgeEstado`), passar a mostrar:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      licenca.nomeComercial?.isNotEmpty == true
          ? licenca.nomeComercial!
          : (licenca.nome ?? 'Sem nome'),
      style: theme.textTheme.titleLarge,
      overflow: TextOverflow.ellipsis,
    ),
    if (licenca.nomeComercial?.isNotEmpty == true && licenca.nome?.isNotEmpty == true)
      Text(
        licenca.nome!,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        overflow: TextOverflow.ellipsis,
      ),
  ],
)
```

Regra:
- Se ambos preenchidos → título grande = nome_comercial, subtítulo pequeno = designacao_social.
- Se só designacao_social → título grande = designacao_social, sem subtítulo.
- Se ambos vazios → placeholder "Sem nome".

Aplicar o mesmo padrão em `InstalacoesScreen` na `_CartaoInstalacao` — nome comercial em destaque, designação em pequeno.

### 4) Testes

- `test/models/licenca_test.dart` — `fromMap` lê `nome_comercial`.
- `test/features/instalacoes/detalhe_cliente_widget_test.dart` — 3 cenários: só designacao, ambos, ambos vazios.

### 5) Reconciliação

Fecha o task #85.

## Commit sugerido

`detalhe_cliente: mostra nome_comercial + designacao_social`

Aproveita este ciclo — este patch + o fix do 401 num só rebuild APK.
