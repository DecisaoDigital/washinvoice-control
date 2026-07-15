-- Redesign v1.4 — Fase 4.1
-- Localidade humana da loja, preenchida pelo admin no Control.
-- Distinta de pings.cidade (automática por geolocalização).

alter table public.clientes
  add column if not exists localidade text;

comment on column public.clientes.localidade is
  'Localidade humana da loja, preenchida pelo admin (ex: "Pinhal Novo").';
