-- Bilan trading, mise à jour 2 : communauté, discussions des défis, administration, connexion MT5.
-- À coller dans Supabase, menu SQL Editor, puis Run. Le script peut être relancé sans risque.

-- 1. Administrateur et membres bloqués
create table if not exists public.admins (email text primary key);
alter table public.admins enable row level security;
create table if not exists public.bannis (email text primary key, depuis timestamptz not null default now());
alter table public.bannis enable row level security;

create or replace function public.est_admin() returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.admins a where a.email = (auth.jwt() ->> 'email'))
$$;
create or replace function public.est_banni() returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.bannis b where b.email = (auth.jwt() ->> 'email'))
$$;
-- Le premier compte créé sur le site devient administrateur.
insert into public.admins (email) select u.email from auth.users u where u.email is not null order by u.created_at limit 1 on conflict do nothing;

create or replace function public.devenir_admin() returns boolean language plpgsql security definer set search_path = '' as $$
begin
  if exists (select 1 from public.admins) then return public.est_admin(); end if;
  insert into public.admins (email) values (auth.jwt() ->> 'email');
  return true;
end $$;

-- 2. Données de l'appli : on ajoute le blocage des membres retirés
drop policy if exists "ajouter" on public.docs;
create policy "ajouter" on public.docs for insert to authenticated
  with check (owner = (select auth.uid()) and not (select public.est_banni()) and (
    starts_with(path, 'data/users/' || (select auth.uid())::text || '/')
    or path in ('partage/' || (select auth.uid())::text, 'defis/' || (select auth.uid())::text, 'profils/' || (select auth.uid())::text)));
drop policy if exists "modifier" on public.docs;
create policy "modifier" on public.docs for update to authenticated
  using (owner = (select auth.uid()))
  with check (owner = (select auth.uid()) and not (select public.est_banni()) and (
    starts_with(path, 'data/users/' || (select auth.uid())::text || '/')
    or path in ('partage/' || (select auth.uid())::text, 'defis/' || (select auth.uid())::text, 'profils/' || (select auth.uid())::text)));
drop policy if exists "supprimer" on public.docs;
create policy "supprimer" on public.docs for delete to authenticated
  using (owner = (select auth.uid()) or (select public.est_admin()));

-- 3. Communauté : publications, stories, j'aime, commentaires
create table if not exists public.posts (
  id uuid primary key default gen_random_uuid(),
  auteur uuid not null default auth.uid() references auth.users (id) on delete cascade,
  type text not null default 'libre' check (type in ('libre', 'semaine', 'strategie', 'evolution', 'story')),
  texte text not null default '' check (char_length(texte) <= 4000),
  images text[] not null default '{}' check (cardinality(images) <= 10),
  stats jsonb check (stats is null or pg_column_size(stats) < 60000),
  cree timestamptz not null default now(),
  expire timestamptz,
  constraint posts_story check ((type = 'story') = (expire is not null) and (expire is null or expire <= cree + interval '25 hours'))
);
create index if not exists posts_cree_idx on public.posts (cree desc);
create index if not exists posts_auteur_idx on public.posts (auteur, cree desc);
alter table public.posts enable row level security;
grant select, insert, update, delete on public.posts to authenticated;
drop policy if exists "posts lire" on public.posts;
create policy "posts lire" on public.posts for select to authenticated using (expire is null or expire > now() or auteur = (select auth.uid()));
drop policy if exists "posts ajouter" on public.posts;
create policy "posts ajouter" on public.posts for insert to authenticated with check (auteur = (select auth.uid()) and not (select public.est_banni()));
drop policy if exists "posts modifier" on public.posts;
create policy "posts modifier" on public.posts for update to authenticated using (auteur = (select auth.uid())) with check (auteur = (select auth.uid()));
drop policy if exists "posts supprimer" on public.posts;
create policy "posts supprimer" on public.posts for delete to authenticated using (auteur = (select auth.uid()) or (select public.est_admin()));

create table if not exists public.likes (
  post uuid not null references public.posts (id) on delete cascade,
  auteur uuid not null default auth.uid() references auth.users (id) on delete cascade,
  cree timestamptz not null default now(),
  primary key (post, auteur)
);
alter table public.likes enable row level security;
grant select, insert, delete on public.likes to authenticated;
drop policy if exists "likes lire" on public.likes;
create policy "likes lire" on public.likes for select to authenticated using (true);
drop policy if exists "likes ajouter" on public.likes;
create policy "likes ajouter" on public.likes for insert to authenticated with check (auteur = (select auth.uid()) and not (select public.est_banni()));
drop policy if exists "likes supprimer" on public.likes;
create policy "likes supprimer" on public.likes for delete to authenticated using (auteur = (select auth.uid()));

create table if not exists public.commentaires (
  id uuid primary key default gen_random_uuid(),
  post uuid not null references public.posts (id) on delete cascade,
  auteur uuid not null default auth.uid() references auth.users (id) on delete cascade,
  texte text not null check (char_length(texte) between 1 and 1000),
  cree timestamptz not null default now()
);
create index if not exists commentaires_post_idx on public.commentaires (post, cree);
alter table public.commentaires enable row level security;
grant select, insert, delete on public.commentaires to authenticated;
drop policy if exists "commentaires lire" on public.commentaires;
create policy "commentaires lire" on public.commentaires for select to authenticated using (true);
drop policy if exists "commentaires ajouter" on public.commentaires;
create policy "commentaires ajouter" on public.commentaires for insert to authenticated with check (auteur = (select auth.uid()) and not (select public.est_banni()));
drop policy if exists "commentaires supprimer" on public.commentaires;
create policy "commentaires supprimer" on public.commentaires for delete to authenticated
  using (auteur = (select auth.uid()) or (select public.est_admin()) or exists (select 1 from public.posts p where p.id = post and p.auteur = (select auth.uid())));

-- 4. Discussions des défis (visibles seulement par les participants du défi)
create or replace function public.participe_defi(p_defi text) returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.docs d cross join lateral jsonb_array_elements(case when jsonb_typeof(d.data -> 'crees') = 'array' then d.data -> 'crees' else '[]'::jsonb end) e
    where d.parent = 'defis' and e ->> 'id' = p_defi
      and (d.owner = auth.uid() or e ->> 'adversaire' = auth.uid()::text
           or (jsonb_typeof(e -> 'participants') = 'array' and e -> 'participants' ? auth.uid()::text)))
$$;
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  defi text not null,
  auteur uuid not null default auth.uid() references auth.users (id) on delete cascade,
  texte text not null check (char_length(texte) between 1 and 1000),
  cree timestamptz not null default now()
);
create index if not exists messages_defi_idx on public.messages (defi, cree);
alter table public.messages enable row level security;
grant select, insert, delete on public.messages to authenticated;
drop policy if exists "messages lire" on public.messages;
create policy "messages lire" on public.messages for select to authenticated using (public.participe_defi(defi) or (select public.est_admin()));
drop policy if exists "messages ajouter" on public.messages;
create policy "messages ajouter" on public.messages for insert to authenticated
  with check (auteur = (select auth.uid()) and not (select public.est_banni()) and public.participe_defi(defi));
drop policy if exists "messages supprimer" on public.messages;
create policy "messages supprimer" on public.messages for delete to authenticated using (auteur = (select auth.uid()) or (select public.est_admin()));

-- 5. Connexion MT5 : une clé secrète par compte, utilisée par le robot
create table if not exists public.cles_mt5 (
  cle text primary key check (char_length(cle) >= 32),
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  compte text not null check (compte ~ '^[A-Za-z0-9_-]{1,40}$'),
  cree timestamptz not null default now(),
  dernier timestamptz
);
alter table public.cles_mt5 enable row level security;
grant select, insert, delete on public.cles_mt5 to authenticated;
drop policy if exists "cles lire" on public.cles_mt5;
create policy "cles lire" on public.cles_mt5 for select to authenticated using (owner = (select auth.uid()));
drop policy if exists "cles ajouter" on public.cles_mt5;
create policy "cles ajouter" on public.cles_mt5 for insert to authenticated with check (owner = (select auth.uid()) and not (select public.est_banni()));
drop policy if exists "cles supprimer" on public.cles_mt5;
create policy "cles supprimer" on public.cles_mt5 for delete to authenticated using (owner = (select auth.uid()));

create or replace function public.mt5_trade(p_cle text, p_t jsonb) returns text language plpgsql security definer set search_path = '' as $$
declare
  k public.cles_mt5;
  v_ticket text;
  v_path text;
  v_data jsonb;
  v_old jsonb;
begin
  select * into k from public.cles_mt5 c where c.cle = p_cle;
  if not found then raise exception 'Clé inconnue'; end if;
  if exists (select 1 from public.bannis b join auth.users u on u.email = b.email where u.id = k.owner) then raise exception 'Compte bloqué'; end if;
  v_ticket := regexp_replace(coalesce(p_t ->> 'ticket', ''), '[^0-9]', '', 'g');
  if v_ticket = '' or char_length(v_ticket) > 30 then raise exception 'Ticket manquant'; end if;
  if coalesce(p_t ->> 'date', '') !~ '^\d{4}-\d{2}-\d{2}$' or jsonb_typeof(p_t -> 'resultat') is distinct from 'number' then raise exception 'Trade invalide'; end if;
  v_path := 'data/users/' || k.owner::text || '/journal/trades/mt5-' || v_ticket;
  v_data := jsonb_strip_nulls(jsonb_build_object(
    'compte', k.compte, 'source', 'mt5', 'ticket', v_ticket,
    'date', p_t ->> 'date', 'heure', coalesce(p_t ->> 'heure', ''), 'actif', left(coalesce(p_t ->> 'actif', '—'), 60),
    'sens', case when p_t ->> 'sens' = 'short' then 'short' else 'long' end,
    'entree', p_t -> 'entree', 'sortie', p_t -> 'sortie', 'qte', p_t -> 'qte', 'lots', p_t -> 'lots', 'frais', p_t -> 'frais',
    'stop', p_t -> 'stop', 'tp', p_t -> 'tp', 'risque', p_t -> 'risque', 'resultat', p_t -> 'resultat'));
  select d.data into v_old from public.docs d where d.path = v_path;
  if v_old is not null then
    v_data := v_data || jsonb_strip_nulls(jsonb_build_object('setup', v_old -> 'setup', 'emotion', v_old -> 'emotion', 'plan', v_old -> 'plan',
      'erreurs', v_old -> 'erreurs', 'images', v_old -> 'images', 'note', v_old -> 'note', 'avis', v_old -> 'avis',
      'defisIn', v_old -> 'defisIn', 'defisOut', v_old -> 'defisOut', 'cree', v_old -> 'cree'));
  end if;
  if not (v_data ? 'cree') then v_data := v_data || jsonb_build_object('cree', (extract(epoch from now()) * 1000)::bigint); end if;
  insert into public.docs (path, parent, owner, data, updated_at)
    values (v_path, 'data/users/' || k.owner::text || '/journal/trades', k.owner, v_data, now())
    on conflict (path) do update set data = excluded.data, updated_at = now();
  update public.cles_mt5 c set dernier = now() where c.cle = k.cle;
  return 'ok';
end $$;

-- 6. Outils de l'administrateur
create or replace function public.liste_membres()
returns table (id uuid, email text, pseudo text, inscrit timestamptz, derniere_connexion timestamptz, nb_trades integer, visible boolean, admin boolean, banni boolean)
language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.est_admin() then raise exception 'Réservé à l''administrateur'; end if;
  return query
    select u.id, u.email::text, coalesce(p.data ->> 'nom', ''), u.created_at, u.last_sign_in_at,
      (select count(*)::integer from public.docs t where t.owner = u.id and t.parent = 'data/users/' || u.id::text || '/journal/trades'),
      exists (select 1 from public.docs s where s.path = 'partage/' || u.id::text),
      exists (select 1 from public.admins a where a.email = u.email),
      exists (select 1 from public.bannis b where b.email = u.email)
    from auth.users u left join public.docs p on p.path = 'profils/' || u.id::text
    order by u.created_at;
end $$;

create or replace function public.retirer_membre(p_membre uuid, p_bloquer boolean default false) returns text language plpgsql security definer set search_path = '' as $$
declare v_email text;
begin
  if not public.est_admin() then raise exception 'Réservé à l''administrateur'; end if;
  if p_membre = auth.uid() then raise exception 'Vous ne pouvez pas vous retirer vous-même'; end if;
  select u.email into v_email from auth.users u where u.id = p_membre;
  if v_email is null then return 'introuvable'; end if;
  if p_bloquer then insert into public.bannis (email) values (v_email) on conflict do nothing; end if;
  delete from public.messages m where m.auteur = p_membre;
  delete from public.commentaires c where c.auteur = p_membre;
  delete from public.likes l where l.auteur = p_membre;
  delete from public.posts p where p.auteur = p_membre;
  delete from public.cles_mt5 k where k.owner = p_membre;
  delete from public.docs d where d.owner = p_membre;
  begin
    delete from auth.users u where u.id = p_membre;
  exception when others then
    return 'donnees';
  end;
  return 'ok';
end $$;

create or replace function public.debloquer_membre(p_email text) returns text language plpgsql security definer set search_path = '' as $$
begin
  if not public.est_admin() then raise exception 'Réservé à l''administrateur'; end if;
  delete from public.bannis b where b.email = p_email;
  return 'ok';
end $$;

create or replace function public.liste_bannis() returns table (email text, depuis timestamptz) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.est_admin() then raise exception 'Réservé à l''administrateur'; end if;
  return query select b.email, b.depuis from public.bannis b order by b.depuis desc;
end $$;

revoke execute on function public.devenir_admin(), public.liste_membres(), public.liste_bannis(), public.retirer_membre(uuid, boolean), public.debloquer_membre(text) from public, anon;
grant execute on function public.devenir_admin(), public.liste_membres(), public.liste_bannis(), public.retirer_membre(uuid, boolean), public.debloquer_membre(text) to authenticated;
revoke execute on function public.mt5_trade(text, jsonb) from public;
grant execute on function public.mt5_trade(text, jsonb) to anon, authenticated;
