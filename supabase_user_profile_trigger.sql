-- Run this in Supabase Dashboard > SQL Editor.
-- It creates a profile row in public.users whenever a Supabase Auth user is created.

alter table public.users enable row level security;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.users (id, email, full_name, phone, role)
    values (
        new.id,
        new.email,
        coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', new.email, ''),
        null,
        coalesce(new.raw_user_meta_data->>'role', 'estudiante')
    )
    on conflict (id) do nothing;

    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

insert into public.users (id, email, full_name, phone, role)
select
    auth.users.id,
    auth.users.email,
    coalesce(auth.users.raw_user_meta_data->>'full_name', auth.users.raw_user_meta_data->>'name', auth.users.email, ''),
    null,
    coalesce(auth.users.raw_user_meta_data->>'role', 'estudiante')
from auth.users
where not exists (
    select 1
    from public.users
    where public.users.id = auth.users.id
);

drop policy if exists "Users can read own profile" on public.users;
create policy "Users can read own profile"
on public.users
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "Users can update own profile" on public.users;
create policy "Users can update own profile"
on public.users
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);
