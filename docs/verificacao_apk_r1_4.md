# Verificação APK — Redesign v1.4.0 (Fase 10)

> Checklist a correr no telemóvel do Cesar com o APK release da branch
> `feature/redesign-visual`. **Desinstalar a versão anterior primeiro.**
> Build: `flutter build apk --release`.
>
> Marcar cada item: ✅ ok · ⚠️ com nota · ❌ falha. Registar observações à frente.

## 0. Build & instalação
- [ ] `flutter build apk --release` termina sem erros.
- [ ] Versão anterior desinstalada; APK novo instala e abre.

## 1. Login
- [ ] Fundo azul-900 (escuro), bloco identidade "WashInvoice / CONTROL".
- [ ] Botão "Entrar" em azul-700, contraste correcto, seta visível.
- [ ] Toggle de visibilidade da password funciona.
- [ ] "v1.4.0" no fundo.

## 2. Dashboard
- [ ] AppBar azul-900 com wordmark (ícone máquina + WashInvoice + CONTROL).
- [ ] 4 KPI cards alinhados numa linha, sem partir "A expirar".
- [ ] Início de actividade: fundo azul-pálido + borda esquerda azul (se houver dados).
- [ ] Pedidos de ajuda: borda esquerda laranja (se houver dados demo); tap no
      telefone liga; tap no card/chevron abre o ecrã.
- [ ] Sugestões: secção roxa aparece se houver por ler; chevron abre o ecrã.
- [ ] Actividade recente: card único com 4-5 linhas, nome·T<n>, localidade, versão.
- [ ] Rodapé "WashInvoice Control · v1.4.0 · cesarmendes78@gmail.com".

## 3. Instalações
- [ ] SearchBar branca raio 12.
- [ ] Chips: "Activas" activo por defeito; menus Versões/Localidades/Sem ping.
      Borda dos chips inactivos bem visível (100% opacidade).
- [ ] Cards: barra vertical colorida + nome cliente + T<n> só quando ≥2.
- [ ] Linha com ícone de sinal (GPS/wifi/off) + "Sinal − Localidade · há X".
- [ ] Card expirada com opacidade reduzida.

## 4. DetalheCliente
- [ ] AppBar: nome + "Terminal X de Y"/"Terminal único" + badge estado.
- [ ] 3 cards com ícones semânticos (Licença, Último acesso, Termos).
- [ ] Machine ID truncado + botão copiar funciona (cola no clipboard).
- [ ] "Sinal diz" (cidade) vs "Loja" (localidade) em linhas separadas.
- [ ] Botões Renovar / gerar licença / suspender funcionam.
- [ ] "Ver todos os acessos" abre modal com histórico.

## 5. Pedidos de Ajuda
- [ ] Toggle Abertos/Histórico alterna.
- [ ] Botão "Ligar" abre a app de telefone com o número certo.
- [ ] Botão "Resolvido" move o pedido para o histórico.

## 6. Sugestões
- [ ] Toggle Por ler/Arquivo alterna.
- [ ] "Marcar" alterna a estrela laranja.
- [ ] "Arquivar" move para o arquivo (e some de "por ler").

## 7. Sobre / Sistema
- [ ] Bloco identidade no topo com "GESTOR DE LICENÇAS".
- [ ] Versão 1.4.0 (build 14).
- [ ] Email e telefone clicáveis (abrem app de email / telefone).

## 8. Mapa
- [ ] Abre sem crash.
- [ ] Markers coloridos por estado (hues nativos — assets PNG ainda TODO).
- [ ] InfoWindow mostra nome (+T<n>) e "Sinal − Localidade · vX".

---

## Resultado

- Data da verificação: __________
- Resultado global: __________
- Notas / bloqueios: __________
