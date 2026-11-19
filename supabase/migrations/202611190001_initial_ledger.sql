-- Debt & Client Ledger: schema, ownership policies, and atomic ledger RPCs.
create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  created_at timestamptz not null default now()
);

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name, email)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''), new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

create table public.clients (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  phone text,
  notes text,
  current_balance numeric(14,2) not null default 0,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint clients_id_user_unique unique (id, user_id)
);
create unique index clients_user_name_unique on public.clients (user_id, lower(trim(name)));
create index clients_user_updated_idx on public.clients (user_id, updated_at desc);

create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid not null references public.clients(id) on delete cascade,
  type text not null check (type in ('DEBIT', 'CREDIT')),
  amount numeric(14,2) not null check (amount > 0),
  balance_after numeric(14,2) not null default 0,
  description text,
  transaction_date timestamptz not null default now(),
  created_at timestamptz not null default now(),
  constraint transactions_client_owner_fk foreign key (client_id, user_id) references public.clients(id, user_id) on delete cascade
);
-- The composite FK above requires a unique key on the referenced owner pair.
create index transactions_client_date_idx on public.transactions (client_id, transaction_date, created_at, id);
create index transactions_user_date_idx on public.transactions (user_id, transaction_date desc);

create table public.audit_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  transaction_id uuid,
  action text not null check (action in ('INSERT', 'UPDATE', 'DELETE')),
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);
create index audit_logs_user_created_idx on public.audit_logs (user_id, created_at desc);

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.transactions enable row level security;
alter table public.audit_logs enable row level security;
create policy "Users can read own profile" on public.profiles for select to authenticated using (id = (select auth.uid()));
create policy "Users can update own profile" on public.profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "Users manage own clients" on public.clients for all to authenticated using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));
create policy "Users read own transactions" on public.transactions for select to authenticated using (user_id = (select auth.uid()));
create policy "Users read own audit logs" on public.audit_logs for select to authenticated using (user_id = (select auth.uid()));

-- Prevent browser clients from bypassing the atomic RPCs and leaving balances stale.
revoke insert, update, delete on public.transactions from authenticated;
revoke insert, update, delete on public.audit_logs from authenticated;

create or replace function public.get_or_create_client(p_name text, p_phone text default null, p_notes text default null)
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_id uuid; v_user uuid := auth.uid(); v_name text := trim(p_name);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if v_name is null or v_name = '' then raise exception 'Client name is required'; end if;
  insert into public.clients(user_id, name, phone, notes) values (v_user, v_name, nullif(trim(p_phone), ''), nullif(trim(p_notes), ''))
  on conflict (user_id, lower(trim(name))) do update set
    name = excluded.name,
    phone = coalesce(excluded.phone, clients.phone),
    notes = coalesce(excluded.notes, clients.notes),
    updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.delete_client(p_client_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := auth.uid();
  v_deleted integer;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  delete from public.clients where id = p_client_id and user_id = v_user;
  get diagnostics v_deleted = row_count;
  if v_deleted = 0 then raise exception 'Client not found or not owned by current user'; end if;
end;
$$;

create or replace function public.recalculate_client(p_client uuid, p_user uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare r record; v_balance numeric(14,2) := 0;
begin
  for r in select id, type, amount from public.transactions
    where client_id = p_client and user_id = p_user
    order by transaction_date asc, created_at asc, id asc
  loop
    v_balance := v_balance + case when r.type = 'DEBIT' then r.amount else -r.amount end;
    update public.transactions set balance_after = v_balance where id = r.id;
  end loop;
  update public.clients set current_balance = v_balance, updated_at = now()
  where id = p_client and user_id = p_user;
end;
$$;

create or replace function public.add_transaction(p_client_id uuid, p_type text, p_amount numeric, p_description text default null, p_transaction_date timestamptz default now())
returns uuid language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_id uuid; v_old_balance numeric(14,2);
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_type not in ('DEBIT','CREDIT') or p_amount <= 0 then raise exception 'Invalid transaction'; end if;
  select current_balance into v_old_balance from public.clients where id=p_client_id and user_id=v_user for update;
  if not found then raise exception 'Client not found'; end if;
  insert into public.transactions(user_id,client_id,type,amount,description,transaction_date)
  values(v_user,p_client_id,p_type,p_amount,p_description,coalesce(p_transaction_date,now())) returning id into v_id;
  perform public.recalculate_client(p_client_id,v_user);
  insert into public.audit_logs(user_id,client_id,transaction_id,action,old_data,new_data)
  values(v_user,p_client_id,v_id,'INSERT',null,to_jsonb((select t from public.transactions t where t.id=v_id)));
  return v_id;
end;
$$;

create or replace function public.edit_transaction(p_transaction_id uuid, p_type text, p_amount numeric, p_description text default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_tx public.transactions%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if p_type not in ('DEBIT','CREDIT') or p_amount <= 0 then raise exception 'Invalid transaction'; end if;
  select * into v_tx from public.transactions where id=p_transaction_id and user_id=v_user;
  if not found then raise exception 'Transaction not found'; end if;
  perform 1 from public.clients where id=v_tx.client_id and user_id=v_user for update;
  select * into v_tx from public.transactions where id=p_transaction_id and user_id=v_user for update;
  if not found then raise exception 'Transaction not found'; end if;
  update public.transactions set type=p_type, amount=p_amount, description=p_description where id=v_tx.id;
  perform public.recalculate_client(v_tx.client_id,v_user);
  insert into public.audit_logs(user_id,client_id,transaction_id,action,old_data,new_data)
  values(v_user,v_tx.client_id,v_tx.id,'UPDATE',to_jsonb(v_tx),to_jsonb((select t from public.transactions t where t.id=v_tx.id)));
end;
$$;

create or replace function public.delete_transaction(p_transaction_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid := auth.uid(); v_tx public.transactions%rowtype;
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  select * into v_tx from public.transactions where id=p_transaction_id and user_id=v_user;
  if not found then raise exception 'Transaction not found'; end if;
  perform 1 from public.clients where id=v_tx.client_id and user_id=v_user for update;
  select * into v_tx from public.transactions where id=p_transaction_id and user_id=v_user for update;
  if not found then raise exception 'Transaction not found'; end if;
  delete from public.transactions where id=v_tx.id;
  perform public.recalculate_client(v_tx.client_id,v_user);
  insert into public.audit_logs(user_id,client_id,transaction_id,action,old_data,new_data)
  values(v_user,v_tx.client_id,v_tx.id,'DELETE',to_jsonb(v_tx),null);
end;
$$;

grant execute on function public.get_or_create_client(text,text,text) to authenticated;
grant execute on function public.delete_client(uuid) to authenticated;
grant execute on function public.add_transaction(uuid,text,numeric,text,timestamptz) to authenticated;
grant execute on function public.edit_transaction(uuid,text,numeric,text) to authenticated;
grant execute on function public.delete_transaction(uuid) to authenticated;
revoke all on function public.get_or_create_client(text,text,text) from public, anon;
revoke all on function public.delete_client(uuid) from public, anon;
revoke all on function public.add_transaction(uuid,text,numeric,text,timestamptz) from public, anon;
revoke all on function public.edit_transaction(uuid,text,numeric,text) from public, anon;
revoke all on function public.delete_transaction(uuid) from public, anon;
revoke all on function public.recalculate_client(uuid,uuid) from public, anon, authenticated;
