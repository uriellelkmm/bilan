-- Bilan trading : à coller une seule fois dans Supabase, menu SQL Editor, puis Run.
create table if not exists public.docs (
  path text primary key,
  parent text not null,
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null default now(),
  constraint docs_parent check (parent = regexp_replace(path, '/[^/]+$', '')),
  constraint docs_taille check (pg_column_size(data) < 300000)
);
create index if not exists docs_parent_idx on public.docs (parent);
alter table public.docs enable row level security;
grant select, insert, update, delete on public.docs to authenticated;

drop policy if exists "lire" on public.docs;
create policy "lire" on public.docs for select to authenticated
  using (owner = (select auth.uid()) or parent in ('partage', 'defis', 'profils'));

drop policy if exists "ajouter" on public.docs;
create policy "ajouter" on public.docs for insert to authenticated
  with check (owner = (select auth.uid()) and (
    starts_with(path, 'data/users/' || (select auth.uid())::text || '/')
    or path in ('partage/' || (select auth.uid())::text, 'defis/' || (select auth.uid())::text, 'profils/' || (select auth.uid())::text)));

drop policy if exists "modifier" on public.docs;
create policy "modifier" on public.docs for update to authenticated
  using (owner = (select auth.uid()))
  with check (owner = (select auth.uid()) and (
    starts_with(path, 'data/users/' || (select auth.uid())::text || '/')
    or path in ('partage/' || (select auth.uid())::text, 'defis/' || (select auth.uid())::text, 'profils/' || (select auth.uid())::text)));

drop policy if exists "supprimer" on public.docs;
create policy "supprimer" on public.docs for delete to authenticated
  using (owner = (select auth.uid()));

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('captures', 'captures', true, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'image/gif'])
on conflict (id) do nothing;

drop policy if exists "captures ajout" on storage.objects;
create policy "captures ajout" on storage.objects for insert to authenticated
  with check (bucket_id = 'captures' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "captures lecture" on storage.objects;
create policy "captures lecture" on storage.objects for select to authenticated
  using (bucket_id = 'captures' and (storage.foldername(name))[1] = (select auth.uid())::text);
drop policy if exists "captures suppression" on storage.objects;
create policy "captures suppression" on storage.objects for delete to authenticated
  using (bucket_id = 'captures' and (storage.foldername(name))[1] = (select auth.uid())::text);
