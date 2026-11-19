-- Armazena os JWTs encerrados para que o logout tenha efeito imediato.
-- Execute no SQL Editor do Supabase antes de publicar a nova API.
create table if not exists public.tokens_revogados (
    jti text primary key,
    usuario_id bigint not null,
    expira_em timestamptz not null,
    criado_em timestamptz not null default now()
);

create index if not exists tokens_revogados_expira_em_idx
    on public.tokens_revogados (expira_em);

-- Apenas a API com a chave service_role pode consultar e gravar esta tabela.
alter table public.tokens_revogados enable row level security;

-- Limpeza opcional (pode ser feita periodicamente):
-- delete from public.tokens_revogados where expira_em < now();
