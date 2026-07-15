# Verificação APK — 1.4.1 (Fase 4)

> Checklist a correr no telemóvel do Cesar com o APK release da branch
> `feature/1.4.1-fixes`. **Desinstalar a versão anterior primeiro.**
> Build: `flutter build apk --release`.
>
> Marcar: ✅ ok · ⚠️ com nota · ❌ falha.

## 0. Build & instalação
- [ ] Build release sem erros; versão anterior desinstalada; instala e abre.

## 1. Login — autofill (Task 29)
- [ ] Depois do primeiro login, o Google Password Manager oferece **guardar** a palavra-passe.
- [ ] Ao reabrir a app, o teclado/sistema **sugere preencher** email + palavra-passe.

## 2. Dashboard após login — BUG CRÍTICO resolvido
- [ ] Mostra os 4 KPIs (podem estar a 0 se não houver licenças).
- [ ] **"Início de actividade (1)"** aparece (o ping do PC sem licença).
- [ ] **"Pedidos de ajuda (1)"** aparece (o pedido demo `nif=512345678`).
- [ ] **"Actividade recente"** com pelo menos 1 linha.
- [ ] Rodapé **"WashInvoice Control · v1.4.1 · …"**.
- [ ] **Sem espaço branco morto / scroll enorme** — o scroll é proporcional ao conteúdo.

## 3. Push com app aberta no Dashboard (Task 30 + som)
- [ ] SnackBar aparece **com vibração**.
- [ ] O Dashboard **recarrega sozinho** (nova secção/item sem tocar em refresh).

## 4. Push com app noutra tab (Instalações)
- [ ] SnackBar + vibração.
- [ ] Ao voltar ao Dashboard, o novo item **já lá está** (recarregou em segundo plano).

## 5. Push com app em background
- [ ] Notificação Android nativa **com som normal do sistema**.

---

## Resultado
- Data: __________
- Resultado global: __________
- Notas / TODO: __________
