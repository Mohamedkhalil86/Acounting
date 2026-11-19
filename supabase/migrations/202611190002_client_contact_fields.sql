-- Extend the idempotent client lookup RPC with optional contact details.
drop function if exists public.get_or_create_client(text);

create or replace function public.get_or_create_client(
  p_name text,
  p_phone text default null,
  p_notes text default null
)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_id uuid;
  v_user uuid := auth.uid();
  v_name text := trim(p_name);
  v_phone text := nullif(trim(p_phone), '');
  v_notes text := nullif(trim(p_notes), '');
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if v_name is null or v_name = '' then raise exception 'Client name is required'; end if;

  insert into public.clients(user_id, name, phone, notes)
  values (v_user, v_name, v_phone, v_notes)
  on conflict (user_id, lower(trim(name))) do update set
    name = excluded.name,
    phone = coalesce(excluded.phone, clients.phone),
    notes = coalesce(excluded.notes, clients.notes),
    updated_at = now()
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.get_or_create_client(text,text,text) from public, anon;
grant execute on function public.get_or_create_client(text,text,text) to authenticated;
