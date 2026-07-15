-- Redesign v1.4 — Fase 4.4
-- Retenção de pings: mantém no máximo 120 pings por máquina. A cada INSERT,
-- apaga os pings mais antigos dessa máquina que excedam os 120 mais recentes.
--
-- ATENÇÃO: trigger destrutivo (DELETE) em produção partilhada com o POS.
-- 120 pings a cada 6 h ≈ 30 dias de histórico por terminal.

create or replace function public.limitar_pings_por_maquina()
returns trigger language plpgsql security definer as $$
begin
  delete from public.pings
  where machine_id = new.machine_id
    and id not in (
      select id from public.pings
      where machine_id = new.machine_id
      order by created_at desc
      limit 120
    );
  return new;
end;
$$;

drop trigger if exists trg_limitar_pings on public.pings;
create trigger trg_limitar_pings
after insert on public.pings
for each row execute function public.limitar_pings_por_maquina();
