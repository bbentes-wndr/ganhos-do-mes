-- Ganhos do Mês: rode isto no SQL Editor do Supabase (pode rodar de novo sem problema).
-- O e-mail do admin (linha logo abaixo) é o seu e-mail do Google; troque se for outro.

-- 1) Quem administra o site (você). Admin entra aprovado e vê a página de usuários.
create table if not exists public.admins (email text primary key);
insert into public.admins(email) values ('billwender001@gmail.com') on conflict do nothing;

-- 2) Perfil de cada pessoa que entra: começa "pendente" até você aprovar.
create table if not exists public.perfis (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  email      text,
  nome       text,
  status     text not null default 'pendente' check (status in ('pendente','aprovado','bloqueado')),
  plano      text not null default 'gratis',        -- pra assinatura no futuro
  validade   date,                                   -- até quando o plano vale (vazio = sem prazo)
  criado_em  timestamptz not null default now(),
  visto_em   timestamptz
);
alter table public.perfis enable row level security;

create or replace function public.eh_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from admins a join auth.users u on lower(u.email)=lower(a.email)
                where u.id = auth.uid() and u.email_confirmed_at is not null);
$$;
create or replace function public.liberado() returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from perfis p where p.user_id = auth.uid() and p.status = 'aprovado'
                and (p.validade is null or p.validade >= current_date));
$$;

-- cria o perfil sozinho no primeiro login (ninguém consegue se auto-aprovar)
create or replace function public.novo_perfil() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into perfis(user_id,email,nome,status)
  values (new.id, new.email, coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name'),
          case when new.email_confirmed_at is not null
                and exists(select 1 from admins where lower(email)=lower(new.email)) then 'aprovado' else 'pendente' end)
  on conflict (user_id) do nothing;
  return new;
end $$;
drop trigger if exists ao_criar_usuario on auth.users;
create trigger ao_criar_usuario after insert on auth.users for each row execute function public.novo_perfil();
-- quem já tinha entrado antes deste script também ganha perfil
insert into public.perfis(user_id,email,nome,status)
select u.id,u.email,coalesce(u.raw_user_meta_data->>'full_name',u.raw_user_meta_data->>'name'),
       case when u.email_confirmed_at is not null
                 and exists(select 1 from public.admins a where lower(a.email)=lower(u.email)) then 'aprovado' else 'pendente' end
from auth.users u on conflict (user_id) do nothing;

drop policy if exists "perfis: ver o meu"      on public.perfis;
drop policy if exists "perfis: admin vê todos" on public.perfis;
drop policy if exists "perfis: admin altera"   on public.perfis;
create policy "perfis: ver o meu"      on public.perfis for select using (auth.uid() = user_id);
create policy "perfis: admin vê todos" on public.perfis for select using (public.eh_admin());
create policy "perfis: admin altera"   on public.perfis for update using (public.eh_admin()) with check (public.eh_admin());

-- registra o último acesso (a própria pessoa só consegue mexer nesse campo)
create or replace function public.marcar_visto() returns void language sql security definer set search_path = public as $$
  update perfis set visto_em = now() where user_id = auth.uid();
$$;

-- 3) Dados: cada pessoa só enxerga e mexe nos próprios, e só se estiver aprovada.
create table if not exists public.docs (
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  colecao    text not null check (colecao in ('jobs','tipos','ignorados')),
  id         text not null,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, colecao, id)
);
alter table public.docs enable row level security;

drop policy if exists "docs: ler os meus"    on public.docs;
drop policy if exists "docs: criar os meus"  on public.docs;
drop policy if exists "docs: mudar os meus"  on public.docs;
drop policy if exists "docs: apagar os meus" on public.docs;
create policy "docs: ler os meus"    on public.docs for select using (auth.uid() = user_id and public.liberado());
create policy "docs: criar os meus"  on public.docs for insert with check (auth.uid() = user_id and public.liberado());
create policy "docs: mudar os meus"  on public.docs for update using (auth.uid() = user_id and public.liberado()) with check (auth.uid() = user_id);
create policy "docs: apagar os meus" on public.docs for delete using (auth.uid() = user_id and public.liberado());

-- 4) Atualização ao vivo entre aparelhos.
do $$ begin
  begin alter publication supabase_realtime add table public.docs; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.perfis; exception when duplicate_object then null; end;
end $$;

-- 5) Permissões: visitante não logado (anon) não mexe em nada; o logado só no que o site usa (RLS decide as linhas).
revoke all on public.docs, public.perfis, public.admins from anon;
revoke truncate, references, trigger on public.docs, public.perfis from authenticated;
revoke insert, delete on public.perfis from authenticated;
revoke all on public.admins from authenticated;

-- 6) Aviso de pedido por e-mail: NÃO é criado por este arquivo.
-- Fica em Database → Webhooks: "avisar_pedido", tabela perfis, evento INSERT, chamando a Edge Function Avisar-Pedido
-- com o cabeçalho Authorization: Bearer <chave service_role>. Nunca cole essa chave no repositório.
-- A função recusa qualquer outra chave (inclusive a pública do config.js).
