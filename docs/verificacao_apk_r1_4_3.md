# Verificação APK — 1.4.3 (Fase 4)

> APK release da branch `feature/1.4.3-melhorias`. **Desinstalar a versão anterior primeiro.**
> Marcar: ✅ ok · ⚠️ nota · ❌ falha.

## 0. Build & instalação
- [ ] Build release ok; instala e abre.

## 1. Detalhe de sugestão
- [ ] Abrir uma sugestão (por ler ou arquivo) → `DetalheSugestao` com texto completo.
- [ ] "Marcar como importante" troca para estrela/"Desmarcar".
- [ ] "Arquivar" — a sugestão sai da lista "Por ler".

## 2. Instalações — ordenação
- [ ] Chip "Ordenar por" com 4 opções (Último acesso, Nome, Validade, Localidade).
- [ ] Trocar reordena a lista.
- [ ] Fechar e reabrir a app → a ordenação escolhida **persiste**.

## 3. Pesquisa global
- [ ] Ícone de lupa no Dashboard abre o ecrã (campo com foco).
- [ ] Escrever "8a0" (ou parte de um NIF) → resultados agrupados por categoria com contagem.
- [ ] Tap num resultado abre o ecrã correcto (cliente/pedido/sugestão).

## 4. Backup / exportar
- [ ] Sobre/Sistema → "Exportar dados".
- [ ] Cada botão gera ficheiro e abre o picker de partilha (Drive/Downloads/…).
- [ ] "Exportar tudo (ZIP)" gera um zip com os 4 CSV.
- [ ] Abrir um CSV no Excel → acentos correctos (BOM UTF-8), colunas OK, localidades em PT.

## 5. Série duplicada
- [ ] Tentar emitir duas licenças activas com a mesma série → **mensagem clara**
      ("Já existe uma licença activa com essa série…"), não excepção crua.

## 6. Sem regressões (1.4.1 / 1.4.2)
- [ ] Dashboard sem espaço morto; autofill; push com vibração + auto-refresh.
- [ ] Cidades em PT ("Lisboa"); "Sem NIF ainda"; sem hash em listas; rodapé sem email.

---
- Data: __________ · Resultado: __________ · Notas: __________
