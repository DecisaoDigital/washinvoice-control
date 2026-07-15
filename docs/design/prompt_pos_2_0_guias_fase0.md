# Prompt POS 2.0 — Guias de Transporte, Fase 0 (Investigação)

> Cola numa sessão nova do Claude Code aberta em `D:\WashFactura\`.
> Branch: **`feature/guias-transporte-investigacao`** a partir de master.
> Alvo: **não escrever código nesta fase.** Só investigar, mapear e propor plano.

---

## Contexto estratégico

- WashInvoice actual (v1.6.x) vai à AT no dia 20 **só com Facturação**. Não atrasar.
- Guias de Transporte serão adicionadas em **v2.0**, submetidas à AT em **adenda à certificação** já emitida.
- Enquanto a AT analisa a submissão inicial (2-3 meses típicos), constrói-se a v2.0 em paralelo.
- Estimativa realista de esforço total (aprender + implementar + certificar): 8-11 semanas.
- **50% do mercado alvo** (lavandarias/engomadorias que fazem entregas ao domicílio ou recolhas) precisa disto.

Zero código de Guias no POS actual — começamos do nada.

---

## Objectivo desta Fase 0

Devolver ao Cesar um documento (`docs/guias_transporte_plano.md`) com:

1. Estudo do quadro legal e técnico da AT para Guias de Transporte.
2. Mapa do que já existe no POS que pode ser reutilizado.
3. Plano de implementação em sprints com estimativas concretas por sprint.
4. Riscos identificados e alternativas.

**Não escrever nenhum código nesta fase.** É estudo + planeamento.

---

## Fase 0.1 — Enquadramento legal e técnico

Lê e resume:

1. **Portaria n.º 363/2010** (regime das facturas e documentos electrónicos) — que artigos aplicam a Guias de Transporte? Especificamente:
   - Documentos abrangidos: GT (Guia de Transporte), GR (Guia de Remessa), DT (Documento de Transporte), GA (Guia de Activos Próprios).
   - Obrigação de comunicação prévia à AT.
   - Hash chaining por série.
   - ATCUD e QR Code obrigatórios (Portaria n.º 195/2020).

2. **Ofícios circulados da AT** relevantes:
   - Ofício-circulado 30248/2022 (transportes)
   - Regime de documentos de transporte 2013 em diante.
   - Casos em que a comunicação prévia é dispensada (empresas com facturação abaixo de X, mercadorias específicas).

3. **Webservice AT — Guias/Documentos de Transporte**:
   - Endpoint e WSDL (procurar em https://info.portaldasfinancas.gov.pt/pt/servicos/documentos_transporte/).
   - Autenticação (certificado digital do contribuinte).
   - Estrutura de request/response (campos obrigatórios).
   - Códigos de erro típicos e como tratar.
   - Diferenças webservice de produção vs testes.
   - Tempo de resposta e disponibilidade (SLA).

4. **SAF-T-PT e MovementOfGoods** — que blocos XML novos aparecem quando há guias?
   - `<StockMovement>` no SAF-T.
   - Relação com facturação (uma guia pode ou não gerar factura depois).

Se algum documento da AT for inacessível via web fetch, sinalizar e pedir ao Cesar para descarregar.

---

## Fase 0.2 — Mapa do POS actual (reutilização)

Investiga o código actual em `D:\WashFactura\lib/` e mapeia o que já existe e pode ser reutilizado:

1. **Hash chaining para facturas** — como está implementado? (Provavelmente em `lib/services/fiscal/` ou similar.) Podemos criar séries de guias que herdam a mesma infraestrutura?
2. **ATCUD e QR Code** — o código de geração está factorizado para múltiplos tipos de documento, ou é específico de facturas?
3. **PDF/A das facturas** — que biblioteca é usada? Suporta o layout que a AT exige para guias (com campos de transporte)?
4. **SAF-T exportação** — está desenhado com secção `<StockMovement>` sequer preparada, mesmo vazia?
5. **Modelo de dados** (`lib/data/db/tables.dart`) — que estrutura tem `documentos_fiscais` hoje? Cabe uma discriminação por tipo (`tipo = 'FT' | 'GT' | 'GR' | 'DT'`)?
6. **Séries fiscais** — tabela `series` como está? Suporta série por tipo?
7. **Edge Function `assinar-documento`** (no Supabase) — assina qualquer texto ou é específica de facturas? Podemos reutilizar para guias sem tocar?
8. **Certificado digital do contribuinte** — está guardado onde? A AT exige certificado válido para webservice.

Devolve secção **"Reutilização possível"** com % estimada de reuso.

---

## Fase 0.3 — Plano de implementação em sprints

Propõe divisão em sprints de 1-2 semanas cada. Para cada sprint:

- Objectivo (o que fica pronto e testável)
- Ficheiros a criar/tocar (aproximado)
- Testes fiscais que devem passar
- Riscos específicos

Estrutura sugerida (adaptar conforme investigação):

| # | Sprint | Duração |
|---|---|---|
| S1 | Modelos + DB (tabelas `guias`, `guias_itens`, tipo em séries) | 1 semana |
| S2 | Ecrãs UI de emissão (formulário GT com matrícula/moradas/motorista) | 1 semana |
| S3 | Hash chaining + ATCUD para guias (reutilizando infra facturas) | 1 semana |
| S4 | PDF/A layout AT para guias | 1 semana |
| S5 | SAF-T MovementOfGoods | 1 semana |
| S6 | Webservice SOAP AT (comunicação prévia) | 2-3 semanas |
| S7 | Testes fiscais + dossier certificação em adenda | 1-2 semanas |

---

## Fase 0.4 — Riscos e alternativas

Devolve lista dos riscos que identificares durante a investigação, com mitigação sugerida:

- **Webservice SOAP AT indisponível** — cache local? retry? em quanto tempo se pode fazer offline?
- **Certificado digital do contribuinte** — como o cliente instala? UI para importar?
- **PDF/A não bate com o layout AT** — plano B?
- **SAF-T não valida contra XSD da AT** — como testar antes de submeter?
- **Tempo de investigação pode revelar que 8-11 semanas é optimista** — sinal precoce se sim.

---

## Fase 0.5 — Documento entregável

Cria `docs/guias_transporte_plano.md` no repo POS com:

- Sumário executivo (1 página).
- Enquadramento legal (2-3 páginas).
- Mapa do código actual reutilizável.
- Plano de sprints.
- Riscos.
- Anexos: links úteis, WSDL, PDF/A samples se encontrares.

Depois de o entregares, o Cesar valida e definimos por onde arrancar (provavelmente S1).

---

## NÃO TOCAR EM

- **Qualquer código do POS.** Esta fase é só investigação.
- Nada da submissão AT actual (v1.6.x) — vai à AT no dia 20 tal como está.
- Edge Functions no Supabase.
- Nada no Control.

---

## Regras

- Português europeu no documento entregável.
- Evidence-based: cita fontes (URLs de docs AT, referências a ficheiros do repo).
- Se não conseguires aceder a um documento AT online, reporta claramente em vez de assumir.
- Sê realista nas estimativas — se descobrires que S6 é mais 3-4 semanas em vez de 2-3, di-lo.

---

## Entrega

- Commit único: `docs: plano Guias de Transporte v2.0 (Fase 0)`.
- Sem alterações a código produtivo.
- Reporta o SHA e o path do `guias_transporte_plano.md`.

Não avanças para Sprint 1 até o Cesar validar o plano. Um plano bom vale semanas de código refeito.
