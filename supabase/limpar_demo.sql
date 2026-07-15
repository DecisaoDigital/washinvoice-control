-- ============================================================
-- WashInvoice Control — remover os dados de DEMONSTRAÇÃO
-- Apaga apenas o que foi criado por seed_demo.sql.
-- ============================================================

begin;

delete from pings             where machine_id like 'demo-%';
delete from pedidos_renovacao where machine_id like 'demo-%';
delete from pedidos_ajuda     where machine_id like 'demo-%';
delete from sugestoes         where machine_id like 'demo-%';
delete from aceites_termos    where machine_id like 'demo-%';
delete from licencas          where machine_id like 'demo-%';
delete from clientes          where nif like '500000%';

commit;
