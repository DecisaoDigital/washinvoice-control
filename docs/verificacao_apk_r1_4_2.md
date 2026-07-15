# Verificação APK — 1.4.2 (Fase 4)

> APK release da branch `feature/1.4.2-conteudo`. **Desinstalar a versão anterior primeiro.**
> Marcar: ✅ ok · ⚠️ nota · ❌ falha.

## 0. Build & instalação
- [ ] Build release ok; instala e abre.

## 1. Dashboard → Início de actividade
- [ ] Card mostra **"Sem NIF ainda"** (o PC ainda não tem NIF), não "NIF —".
- [ ] Localidade em **"Lisboa"** (não "Lisbon").

## 2. Dashboard → Actividade recente
- [ ] Linha mostra **"Terminal sem identificação"** (ou "NIF X" se houver NIF).
- [ ] **Não aparece "8a0f8c93.."** (hash) em lado nenhum.

## 3. Dashboard → Pedidos de ajuda
- [ ] Card mostra o nome/NIF na linha 1 + **preview das notas** na linha 2
      ("A impressora térmica…"). **Sem "? −"**.
- [ ] Tap no card abre o **DetalhePedidoAjuda**: notas completas, cliente/terminal,
      último ping (ou "Sem pings deste terminal"), botões Ligar/Email/Resolver.
- [ ] "Marcar como resolvido" fecha o pedido (some dos abertos).

## 4. Instalações
- [ ] "Sinal − Localidade" mostra **"Lisboa − …"** (não Lisbon).
- [ ] Ícone de sinal barrado (cinza) quando `metodo_geo` é null.

## 5. DetalheCliente
- [ ] "Sinal diz" mostra **"Lisboa"**.

## 6. Rodapé do Dashboard
- [ ] Mostra só **"WashInvoice Control · v1.4.2"** (sem email).

## 7. Sem regressões da 1.4.1
- [ ] Autofill, auto-refresh em push, vibração, Dashboard sem espaço morto.

---
- Data: __________ · Resultado: __________ · Notas: __________
