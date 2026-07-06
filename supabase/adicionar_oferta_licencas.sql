-- WashInvoice Control — campo Oferta/Paga nas licenças
-- Correr uma vez no SQL Editor do Supabase.
-- Acrescenta a coluna `oferta` à tabela `licencas`:
--   false (default) = licença paga (fluxo normal)
--   true            = licença oferecida gratuitamente
-- Retrocompatível: licenças antigas ficam como pagas (false).

alter table public.licencas
  add column if not exists oferta boolean not null default false;
