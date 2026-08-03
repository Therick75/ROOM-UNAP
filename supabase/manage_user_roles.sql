-- Role management for ROOM-UNAP
-- Run this in Supabase SQL Editor after confirming the users table already exists.

alter table public.users enable row level security;

drop policy if exists "Users can read profiles" on public.users;
create policy "Users can read profiles"
on public.users
for select
to authenticated
using (true);

drop policy if exists "Users can update own profile" on public.users;
create policy "Users can update own profile"
on public.users
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());

drop policy if exists "Users can insert their own profile" on public.users;
create policy "Users can insert their own profile"
on public.users
for insert
to authenticated
with check (id = auth.uid());

create or replace function public.set_user_role(
  target_user_id uuid,
  new_role text
)
returns public.users
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_user public.users;
begin
  if not exists (
    select 1
    from public.users u
    where u.id = auth.uid()
      and u.role = 'super_admin'
  ) then
    raise exception 'forbidden';
  end if;

  if new_role not in ('estudiante', 'arrendador', 'super_admin') then
    raise exception 'invalid role';
  end if;

  update public.users
  set role = new_role
  where id = target_user_id
  returning * into updated_user;

  if not found then
    raise exception 'user not found';
  end if;

  return updated_user;
end;
$$;

revoke all on function public.set_user_role(uuid, text) from public;
grant execute on function public.set_user_role(uuid, text) to authenticated;
