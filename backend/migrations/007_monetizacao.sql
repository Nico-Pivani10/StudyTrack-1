-- Execute depois da migration 006.
-- Adiciona o plano de assinatura à conta do estudante. Não apaga dados existentes;
-- toda conta já cadastrada vira 'free' automaticamente pelo valor padrão.
begin;

alter table public.usuarios
  add column if not exists plano text not null default 'free',
  add column if not exists premium_desde timestamptz;

do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'usuarios_plano_chk') then
    alter table public.usuarios
      add constraint usuarios_plano_chk check (plano in ('free', 'premium'));
  end if;
end $$;

notify pgrst, 'reload schema';
commit;
