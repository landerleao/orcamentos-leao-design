-- Painel de projetos: um projeto por orçamento aprovado
create table public.projects (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  data jsonb not null,
  share_token text unique,           -- link secreto da página do cliente (null = link desativado)
  updated_at timestamptz not null default now()
);

alter table public.projects enable row level security;

create policy "somente o dono" on public.projects for all to authenticated
  using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

grant select, insert, update, delete on public.projects to authenticated;

-- Página do cliente: devolve um único projeto pelo link secreto, sem as anotações internas,
-- junto com a marca e os contatos para montar a página. Visitantes não acessam a tabela direto.
create or replace function public.projeto_compartilhado(token text)
returns jsonb
language sql
security definer
set search_path = public
stable
as $$
  select jsonb_build_object(
    'project', p.data - 'internalNotes',
    'brand', s.data -> 'settings' -> 'brand',
    'company', s.data -> 'settings' -> 'company'
  )
  from projects p
  join settings s on s.user_id = p.user_id
  where length(token) >= 24 and p.share_token = token
$$;

revoke all on function public.projeto_compartilhado(text) from public;
grant execute on function public.projeto_compartilhado(text) to anon, authenticated;
