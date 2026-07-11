# Verificação em APK — Ronda R1 (melhorias Control)

Verificação no **caminho real da UI** das 6 melhorias da ronda R1. Regra
washinvoice: um item só fecha quando confirmado no APK real, não em teste/curl.

> **Estado:** ⏳ pendente de validação no telemóvel do Cesar. O Code compila o
> APK (prova que o build passa) mas **não instala nem opera** o dispositivo —
> os passos de UI abaixo são do Cesar. Registar data e resultado em cada linha.

## Como compilar e instalar

```bash
flutter build apk --release
# APK em: build/app/outputs/flutter-apk/app-release.apk
# Instalar: adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Estado automático (já verificado pelo Code)

- `flutter analyze` → só 1 aviso **pré-existente** (`anonKey` deprecated em
  `main.dart`, fora do âmbito desta ronda). ✅
- `flutter test` → **27/27** (8 datas + 4 modelos + 4 email acolhimento + 1
  widget navegação + 10 emissão intactos). ✅
- `flutter build apk --release` → **passou** — `app-release.apk` (23.4 MB). ✅
  (Aviso do Kotlin `different roots C:↔D:` é do compilador incremental por o
  projeto estar em `D:` e a cache do pub em `C:` — harmless, não falha o build.)

## Checklist de UI (Cesar, no APK)

| # | Passo | Esperado | Resultado | Data |
|---|-------|----------|-----------|------|
| 1 | AppBar do Dashboard → ícone **info** → Sobre/Sistema | Mostra nome+versão da app, **bloco Contactos** (nome/email/telefone), projeto/URL Supabase, email do utilizador, último ping. Terminar sessão funciona. | ☐ | |
| 2 | Emitir nova licença com duração que caia em fim de mês (ex.: hoje dia 31, +1 mês) | Validade cai no **último dia** do mês de destino, **não** salta para o mês seguinte | ☐ | |
| 3 | Abrir Detalhe de um NIF com **duas** licenças (dois terminais) | Abre a licença **do terminal que se clicou** (por `machine_id`), não erro nem a errada | ☐ | |
| 4 | **Renovar** licença ("Marcar como pago e renovar") | Guarda sem erro de `id`/`created_at` no UPDATE; validade atualizada | ☐ | |
| 5a | Instalações → pesquisar por NIF / nome / machine_id | Filtra a lista correctamente | ☐ | |
| 5b | Instalações → filtros: estado, versão, cidade, "sem ping há N dias" (3/7/14) | Cada filtro (e combinações) devolve o esperado; "Limpar" repõe tudo | ☐ | |
| 6 | Preencher email → "Enviar email de acolhimento" | Abre o email com assunto "Bem-vindo e próximos passos"; corpo valoriza o produto e termina com os contactos de `Config` (nome/email/telefone); **sem** IBAN nem instruções de pagamento | ☐ | |

## Notas

- **Item 4 (revisto):** substituiu o passo original "editar cliente" — não há
  ecrã de edição de cliente nesta ronda (fica para outra frente). O sintoma
  (`id`/`created_at` no UPDATE) testa-se no call site real, que é a renovação de
  licença. O `toUpdateJson` de `cliente.dart` ficou na mesma pronto para quando
  existir esse ecrã.
- **Item 6 (revisto):** o modelo comercial mudou — o cliente contacta primeiro
  e o IBAN sai por canal directo. O antigo email de "instruções de pagamento"
  (com IBAN) foi substituído por um **email de acolhimento** que valoriza o
  produto e remete para os contactos. `Config.iban` foi **removido**. O
  parágrafo da landing page (`Config.urlPagamento`) está preparado mas inactivo
  (vazio) — aparece automaticamente quando a URL for preenchida.
- **Pesquisa/filtros** vivem na aba **Instalações** (não no Dashboard, que fica
  como resumo) — foi a decisão desta ronda.
