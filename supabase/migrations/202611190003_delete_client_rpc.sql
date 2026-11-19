-- Delete one owned client and cascade its transaction rows through a scoped RPC.
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

revoke all on function public.delete_client(uuid) from public, anon;
grant execute on function public.delete_client(uuid) to authenticated;
