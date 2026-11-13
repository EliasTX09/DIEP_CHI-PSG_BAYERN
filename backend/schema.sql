-- Fairway Clash – Supabase Schema (SQL Editor -> New query -> Run)
-- Enthaelt Tabellen, Row Level Security und Hilfsfunktionen.

create extension if not exists "pgcrypto";

-- ------------------------------------------------------------ Profile
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique,
  coins int not null default 0,
  gems int not null default 0,
  save jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  constraint username_len check (username is null or char_length(username) between 3 and 20)
);

-- Profil automatisch bei Registrierung / Gast-Login anlegen
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, username)
  values (new.id, 'Spieler' || substr(replace(new.id::text, '-', ''), 1, 6))
  on conflict (id) do nothing;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ------------------------------------------------------------ Freunde
create table if not exists public.friendships (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  friend_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','accepted')),
  created_at timestamptz not null default now(),
  check (user_id <> friend_id),
  unique (user_id, friend_id)
);

create or replace function public.are_friends(a uuid, b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.user_id = a and f.friend_id = b) or (f.user_id = b and f.friend_id = a)));
$$;

-- ------------------------------------------------------------ Einladungen
create table if not exists public.invites (
  id bigint generated always as identity primary key,
  from_id uuid not null references public.profiles(id) on delete cascade,
  to_id uuid not null references public.profiles(id) on delete cascade,
  room_code text not null,
  created_at timestamptz not null default now()
);
create index if not exists invites_to_idx on public.invites(to_id, created_at desc);

-- ------------------------------------------------------------ Ghosts
create table if not exists public.ghosts (
  id bigint generated always as identity primary key,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  course_id text not null,
  strokes int not null,
  duration real not null,
  samples jsonb not null,           -- flach: [t,x,y, t,x,y, ...] @ 10 Hz
  created_at timestamptz not null default now()
);
create index if not exists ghosts_course_idx on public.ghosts(course_id, strokes, duration);

-- ------------------------------------------------------------ RLS
alter table public.profiles    enable row level security;
alter table public.friendships enable row level security;
alter table public.invites     enable row level security;
alter table public.ghosts      enable row level security;

-- Profile: Username sichtbar fuer eingeloggte Nutzer (Freunde suchen), schreiben nur eigenes.
create policy "profiles read"   on public.profiles for select to authenticated using (true);
create policy "profiles update" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

create policy "friends read"    on public.friendships for select to authenticated
  using (user_id = auth.uid() or friend_id = auth.uid());
create policy "friends insert"  on public.friendships for insert to authenticated
  with check (user_id = auth.uid() and status = 'pending');
create policy "friends accept"  on public.friendships for update to authenticated
  using (friend_id = auth.uid()) with check (friend_id = auth.uid());
create policy "friends delete"  on public.friendships for delete to authenticated
  using (user_id = auth.uid() or friend_id = auth.uid());

create policy "invites read"    on public.invites for select to authenticated
  using (to_id = auth.uid() or from_id = auth.uid());
create policy "invites insert"  on public.invites for insert to authenticated
  with check (from_id = auth.uid() and public.are_friends(from_id, to_id));
create policy "invites delete"  on public.invites for delete to authenticated
  using (to_id = auth.uid() or from_id = auth.uid());

-- Ghosts: eigene + die von Freunden lesen; nur eigene schreiben.
create policy "ghosts read"     on public.ghosts for select to authenticated
  using (owner_id = auth.uid() or public.are_friends(owner_id, auth.uid()));
create policy "ghosts insert"   on public.ghosts for insert to authenticated
  with check (owner_id = auth.uid());

-- Hinweis: coins/gems/save sind hier clientseitig beschreibbar (Prototyp).
-- Fuer Produktion: UPDATE auf diese Spalten entziehen und Kaeufe/Belohnungen ueber
-- security-definer-RPCs bzw. Edge Functions vergeben.
