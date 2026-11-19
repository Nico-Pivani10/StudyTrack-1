-- Segunda-feira = 1 e domingo = 7, conforme ISO 8601.
-- Não recria tabelas nem modifica horários existentes.

do $$
begin
  if exists (select 1 from public.horarios_aula where dia_semana not between 1 and 7) then
    raise exception 'Existem horários com dia_semana fora do padrão ISO (1 a 7). Corrija antes de aplicar a restrição.';
  end if;
  if not exists (
    select 1 from pg_constraint
    where conname = 'horarios_aula_dia_semana_iso_chk'
      and conrelid = 'public.horarios_aula'::regclass
  ) then
    alter table public.horarios_aula
      add constraint horarios_aula_dia_semana_iso_chk check (dia_semana between 1 and 7);
  end if;
end $$;
