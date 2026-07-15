-- ============================================================
-- WashInvoice Control — dados de DEMONSTRAÇÃO
-- Cola este script no SQL Editor do Supabase e carrega em "Run".
-- Cria 7 instalações que cobrem todos os estados de licença e de versão.
-- Tudo é identificável por machine_id 'demo-%' e NIF '50000000%'
-- para depois poderes apagar com limpar_demo.sql.
--
-- Datas usam intervalos relativos a now(), por isso os estados
-- (activa / a expirar / expirada) mantêm-se corretos em qualquer dia.
-- Versão de referência = 1.5  ->  1.4 = anterior (laranja), 1.3 = antiga (vermelho)
-- ============================================================

begin;

-- ---------- CLIENTES ----------
insert into clientes (id, nif, nome, email, telemovel, notas) values
  ('11111111-1111-4111-8111-111111111111', '500000001', 'Lavandaria Central',   'central@exemplo.pt',  '912000001', 'Cliente desde 2023'),
  ('22222222-2222-4222-8222-222222222222', '500000002', 'WashPoint Porto',       'porto@exemplo.pt',    '912000002', null),
  ('33333333-3333-4333-8333-333333333333', '500000003', 'CleanExpress Coimbra',  'coimbra@exemplo.pt',  '912000003', 'Pediu fatura mensal'),
  ('44444444-4444-4444-8444-444444444444', '500000004', 'Bolhas & Cia Braga',    'braga@exemplo.pt',    '912000004', null),
  ('55555555-5555-4555-8555-555555555555', '500000005', 'AquaLava Faro',         'faro@exemplo.pt',     '912000005', 'Suspensa por falta de pagamento'),
  ('66666666-6666-4666-8666-666666666666', '500000006', 'Espuma Aveiro',         'aveiro@exemplo.pt',   '912000006', null),
  ('77777777-7777-4777-8777-777777777777', '500000007', 'Lavandaria do Sado',    'setubal@exemplo.pt',  '912000007', 'Setúbal');

-- ---------- LICENÇAS ----------
-- estado depende de (activa, validade):
insert into licencas (cliente_id, machine_id, nif, nome, plano, validade, activa) values
  ('11111111-1111-4111-8111-111111111111', 'demo-001', '500000001', 'Lavandaria Central',  'anual',      now() + interval '250 days', true),  -- ACTIVA
  ('22222222-2222-4222-8222-222222222222', 'demo-002', '500000002', 'WashPoint Porto',      'mensal',     now() + interval '150 days', true),  -- ACTIVA
  ('33333333-3333-4333-8333-333333333333', 'demo-003', '500000003', 'CleanExpress Coimbra', 'trimestral', now() + interval '8 days',   true),  -- A EXPIRAR
  ('44444444-4444-4444-8444-444444444444', 'demo-004', '500000004', 'Bolhas & Cia Braga',   'mensal',     now() - interval '12 days',  true),  -- EXPIRADA
  ('55555555-5555-4555-8555-555555555555', 'demo-005', '500000005', 'AquaLava Faro',         'anual',      now() + interval '100 days', false), -- SUSPENSA
  ('66666666-6666-4666-8666-666666666666', 'demo-006', '500000006', 'Espuma Aveiro',         'trimestral', now() + interval '140 days', true),  -- ACTIVA
  ('77777777-7777-4777-8777-777777777777', 'demo-007', '500000007', 'Lavandaria do Sado',    'mensal',     now() + interval '13 days',  true);  -- A EXPIRAR

-- ---------- PINGS (último acesso de cada máquina) ----------
-- versao: demo-001/002/007 = 1.5 (atual) ; demo-003/006 = 1.4 (anterior) ; demo-005 = 1.3 (antiga)
insert into pings (machine_id, nif, versao, lat, lon, cidade, metodo_geo, created_at) values
  ('demo-001', '500000001', '1.5', 38.7223, -9.1393,  'Lisboa',  'gps', now() - interval '20 minutes'),
  ('demo-002', '500000002', '1.5', 41.1579, -8.6291,  'Porto',   'gps', now() - interval '2 hours'),
  ('demo-003', '500000003', '1.4', 40.2033, -8.4103,  'Coimbra', 'ip',  now() - interval '1 day'),
  ('demo-004', '500000004', '1.4', 41.5454, -8.4265,  'Braga',   'gps', now() - interval '5 days'),
  ('demo-005', '500000005', '1.3', 37.0194, -7.9304,  'Faro',    'ip',  now() - interval '20 days'),
  ('demo-006', '500000006', '1.4', 40.6405, -8.6538,  'Aveiro',  'gps', now() - interval '3 hours'),
  ('demo-007', '500000007', '1.5', 38.5244, -8.8882,  'Setúbal', 'gps', now() - interval '45 minutes');

-- Histórico extra para a instalação de Coimbra (demo-003)
insert into pings (machine_id, nif, versao, lat, lon, cidade, metodo_geo, created_at) values
  ('demo-003', '500000003', '1.4', 40.2033, -8.4103, 'Coimbra', 'ip', now() - interval '3 days'),
  ('demo-003', '500000003', '1.3', 40.2033, -8.4103, 'Coimbra', 'ip', now() - interval '9 days'),
  ('demo-003', '500000003', '1.3', 40.2050, -8.4200, 'Coimbra', 'gps', now() - interval '16 days');

-- ---------- INÍCIO DE ATIVIDADE ----------
-- Máquinas NOVAS: estão a comunicar (pings) mas NÃO têm licença nem cliente.
-- Aparecem no Dashboard em "Início de atividade" para seres tu a ativar.
insert into pings (machine_id, nif, versao, lat, lon, cidade, metodo_geo, created_at) values
  ('demo-100', '500000100', '1.5', 38.7071, -9.1355, 'Lisboa',   'gps', now() - interval '15 minutes'),
  ('demo-101', '500000101', '1.4', 41.3451, -8.5750, 'Famalicão','ip',  now() - interval '3 hours');

-- ---------- PEDIDOS DE RENOVAÇÃO (pendentes) ----------
insert into pedidos_renovacao (machine_id, nif, plano_desejado, estado, created_at) values
  ('demo-004', '500000004', 'mensal',     'pendente', now() - interval '2 days'),   -- a expirada quer renovar
  ('demo-003', '500000003', 'trimestral', 'pendente', now() - interval '6 hours');  -- a que está a expirar

-- ---------- ACEITES DE TERMOS ----------
insert into aceites_termos (machine_id, nif, versao_termos, data_aceite, cidade, ip, created_at) values
  ('demo-001', '500000001', '2024-01', now() - interval '200 days', 'Lisboa', '85.240.10.11',  now() - interval '200 days'),
  ('demo-002', '500000002', '2024-01', now() - interval '90 days',  'Porto',  '188.37.45.200', now() - interval '90 days'),
  ('demo-007', '500000007', '2024-01', now() - interval '30 days',  'Setúbal','94.62.18.30',   now() - interval '30 days');

-- ---------- SUGESTÕES (para testar ecrã de sugestões + backup + pesquisa) ----------
insert into sugestoes (machine_id, nif, cliente_id, texto, criado_em, lida, marcada, arquivada) values
  ('demo-001','500000001','11111111-1111-4111-8111-111111111111','Seria útil poder reimprimir o último talão sem ter de repetir a venda.', now() - interval '2 hours', false, false, false),
  ('demo-003','500000003','33333333-3333-4333-8333-333333333333','Gostava de um relatório mensal automático por email com o total faturado.', now() - interval '1 day', false, true, false),
  ('demo-006','500000006','66666666-6666-4666-8666-666666666666','No ecrã de pagamento, um botão de "valor exacto" ajudava muito.', now() - interval '6 days', true, false, true);

commit;
