-- RLS policies for listing_images
-- Run this in Supabase SQL Editor.

alter table public.listing_images enable row level security;

drop policy if exists "Anyone can read listing images" on public.listing_images;
create policy "Anyone can read listing images"
on public.listing_images
for select
to anon, authenticated
using (true);

drop policy if exists "Owners can manage listing images" on public.listing_images;
create policy "Owners can manage listing images"
on public.listing_images
for all
to authenticated
using (
  exists (
    select 1
    from public.listings l
    where l.id = listing_images.listing_id
      and (
        l.owner_id = auth.uid()
        or exists (
          select 1
          from public.users u
          where u.id = auth.uid()
            and u.role = 'super_admin'
        )
      )
  )
)
with check (
  exists (
    select 1
    from public.listings l
    where l.id = listing_images.listing_id
      and (
        l.owner_id = auth.uid()
        or exists (
          select 1
          from public.users u
          where u.id = auth.uid()
            and u.role = 'super_admin'
        )
      )
  )
);
