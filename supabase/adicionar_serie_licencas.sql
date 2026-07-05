-- WashInvoice Control — série documental por terminal
-- Correr uma vez no SQL Editor do Supabase.
-- Acrescenta a coluna `serie` à tabela `licencas` (definida quando a licença é
-- gerada, após pagamento). Retrocompatível: licenças antigas ficam com NULL.

alter table public.licencas add column if not exists serie text;

-- Índice para a verificação de colisão (série activa noutro terminal).
create index if not exists licencas_serie_idx
  on public.licencas (serie) where serie is not null;
