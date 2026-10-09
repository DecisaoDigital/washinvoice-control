# Council — UI/UX da app Control (2026-10-08, modo rápido: 5 conselheiros, sem revisão cruzada)

Pergunta: conselheiros como utilizadores reais da Control; o que melhorar em UI/UX. Só leitura de código (telemóvel bloqueado, sem capturas, sem métricas de uso).

## Posições
- **Contrariante** — o problema é segurança e feedback das acções destrutivas: Suspender no mesmo bloco que +5/+30 dias (instalacoes/controlo_remoto_widgets.dart ~79-110); confirmações sem cliente/terminal (detalhe_cliente_screen.dart 273-290); «Cancelar licença» com botão «Cancelar»; «Resolvido» sem confirmação, desfazer nem tratamento de erro (pedidos_ajuda_screen.dart:87). Falsa melhoria: redesenhar o Dashboard.
- **Primeiros princípios** — arquitectura por entidade em vez de por acção; FAB «Pedidos Fist» duplica separador; pedidos Fist nem aparecem no Dashboard; selector de app repetido em 5 AppBars. Propõe separador «Agora» (fila única por urgência), 3 separadores, chip de app.
- **Expansionista** — passar de painel a fila de acções: badges nos separadores, «Inbox», acções por swipe e na notificação, resumo diário às 8h.
- **Forasteiro** — jargão (Fist/POS/PRO/Base, «Acessos», «Mapa»), Suspender/Cancelar/Apagar sem diferença explicada, «Pedidos Fist» vs «Pedidos de ajuda».
- **Executor** — contagem de toques: ajuda 4 toques/2 ecrãs; renovar 6-7 toques sem atalho; aprovar 3 toques com diálogo fora da zona do polegar. 1) barra fixa em baixo Ligar/Resolvido com Desfazer; 2) bottom sheet +1 mês/+3 meses/+1 ano; 3) Aprovar/Recusar no cartão.
