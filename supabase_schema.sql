-- =====================================================================================
-- Golf Battle 3D - Supabase-Schema
-- Einrichten: Supabase-Dashboard -> SQL Editor -> New query -> alles einfuegen -> Run.
-- Das Skript ist wiederholbar (legt nur an, was fehlt, und ersetzt Policies/Funktionen).
--
-- Tabellen: profiles, clubs, inventory, friends, lobbies, lobby_invites, match_results, game_link_codes
-- Speicher: Bucket "avatars" (Profilbilder aus dem Web-Portal)
-- Sicht:    public_profiles (oeffentliche Profil-Infos fuer Freunde, Suche, Rangliste)
-- Alle Tabellen sind per Row Level Security geschuetzt: jeder sieht/aendert nur, was er darf.
-- =====================================================================================

-- ------------------------------------------------------------------------------- profiles
create table if not exists public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  username      text        not null default 'Gast',
  friend_code   text        not null unique default upper(substr(md5(random()::text || clock_timestamp()::text), 1, 8)),
  avatar_frame  text        not null default 'bronze',
  avatar_color  int         not null default 0,
  trophies      int         not null default 0 check (trophies >= 0),
  coins         int         not null default 0 check (coins >= 0),
  gems          int         not null default 0 check (gems >= 0),
  equipped      jsonb       not null default '{}'::jsonb,
  save          jsonb       not null default '{}'::jsonb,   -- kompletter Spielstand (Geraete-Sync)
  revision      int         not null default 0,
  device_id     text,
  last_seen     timestamptz not null default now(),
  created_at    timestamptz not null default now(),
  constraint username_length check (char_length(username) between 3 and 16)
);
create index if not exists profiles_trophies_idx on public.profiles (trophies desc);
create index if not exists profiles_username_idx on public.profiles (lower(username));

-- Profil automatisch anlegen, sobald sich jemand registriert (auch Gast-/Anonym-Login).
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  wanted text;
begin
  wanted := coalesce(nullif(trim(new.raw_user_meta_data ->> 'name'), ''), 'Gast' || substr(replace(new.id::text, '-', ''), 1, 4));
  if char_length(wanted) < 3 or char_length(wanted) > 16 then
    wanted := 'Gast' || substr(replace(new.id::text, '-', ''), 1, 4);
  end if;
  insert into public.profiles (id, username, device_id)
  values (new.id, wanted, new.raw_user_meta_data ->> 'device_id')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Profilbild: Pfad im Storage-Bucket "avatars", nur im eigenen Ordner: "<user-id>/avatar-<zahl>.<png|jpg|jpeg|webp>"
alter table public.profiles add column if not exists avatar_path text;
alter table public.profiles drop constraint if exists avatar_path_format;
alter table public.profiles add constraint avatar_path_format check (
  avatar_path is null
  or avatar_path ~ ('^' || id::text || '/avatar-[0-9]{1,16}\.(png|jpg|jpeg|webp)$')
);

-- Oeffentliche Profil-Infos (ohne Spielstand, Coins, Geraete-ID). Die Sicht laeuft mit den Rechten
-- des Besitzers und umgeht damit bewusst die strenge RLS der Tabelle - sie zeigt nur harmlose Spalten.
create or replace view public.public_profiles as
  select id, username, friend_code, avatar_frame, avatar_color, trophies, last_seen, avatar_path
  from public.profiles;

-- ------------------------------------------------------------------------------- clubs
create table if not exists public.clubs (
  user_id    uuid        not null references public.profiles (id) on delete cascade,
  club_id    text        not null,
  level      int         not null default 1 check (level between 1 and 12),
  cards      int         not null default 0 check (cards >= 0),
  equipped   boolean     not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, club_id)
);

-- ------------------------------------------------------------------------------- inventory
-- item_type: 'ball' | 'trail' | 'explosion' | 'frame'
create table if not exists public.inventory (
  user_id    uuid        not null references public.profiles (id) on delete cascade,
  item_type  text        not null check (item_type in ('ball', 'trail', 'explosion', 'frame')),
  item_id    text        not null,
  equipped   boolean     not null default false,
  created_at timestamptz not null default now(),
  primary key (user_id, item_type, item_id)
);

-- ------------------------------------------------------------------------------- friends
create table if not exists public.friends (
  id         bigint generated always as identity primary key,
  user_id    uuid        not null references public.profiles (id) on delete cascade,   -- hat die Anfrage gesendet
  friend_id  uuid        not null references public.profiles (id) on delete cascade,   -- hat sie erhalten
  status     text        not null default 'pending' check (status in ('pending', 'accepted')),
  created_at timestamptz not null default now(),
  constraint friends_not_self check (user_id <> friend_id)
);
-- Pro Paar nur eine Zeile, egal wer wen angefragt hat.
create unique index if not exists friends_pair_idx
  on public.friends (least(user_id, friend_id), greatest(user_id, friend_id));

create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friends f
    where f.status = 'accepted'
      and ((f.user_id = a and f.friend_id = b) or (f.user_id = b and f.friend_id = a))
  );
$$;

-- ------------------------------------------------------------------------------- lobbies
create table if not exists public.lobbies (
  code         text        primary key check (code ~ '^[A-Z0-9]{4}$'),
  host_id      uuid        not null references public.profiles (id) on delete cascade,
  world        text        not null default 'emerald',
  rounds       int         not null default 3 check (rounds in (3, 5, 9)),
  is_public    boolean     not null default false,
  status       text        not null default 'open' check (status in ('open', 'started', 'closed')),
  player_count int         not null default 1 check (player_count between 0 and 6),
  created_at   timestamptz not null default now()
);
create index if not exists lobbies_public_idx on public.lobbies (is_public, status, created_at desc);

-- ------------------------------------------------------------------------------- lobby_invites
create table if not exists public.lobby_invites (
  id         bigint generated always as identity primary key,
  from_id    uuid        not null references public.profiles (id) on delete cascade,
  to_id      uuid        not null references public.profiles (id) on delete cascade,
  code       text        not null,
  created_at timestamptz not null default now()
);
create index if not exists lobby_invites_to_idx on public.lobby_invites (to_id, created_at desc);

-- Alte Lobbys aufraeumen (optional per pg_cron: select cron.schedule('lobby-cleanup', '*/15 * * * *', 'select public.cleanup_lobbies()');)
create or replace function public.cleanup_lobbies()
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.lobbies where created_at < now() - interval '3 hours';
  delete from public.lobby_invites where created_at < now() - interval '1 hour';
$$;

-- ------------------------------------------------------------------------------- match_results
create table if not exists public.match_results (
  id             bigint generated always as identity primary key,
  user_id        uuid        not null references public.profiles (id) on delete cascade,
  lobby_code     text        not null default '',
  mode           text        not null default 'quick',
  world          text        not null default '',
  rounds         int         not null default 0,
  rank           int         not null default 0,
  players        int         not null default 0,
  strokes        int         not null default 0,
  style_points   int         not null default 0,
  trophies_delta int         not null default 0,
  coins          int         not null default 0,
  created_at     timestamptz not null default now()
);
create index if not exists match_results_user_idx on public.match_results (user_id, created_at desc);

-- ------------------------------------------------------------------------------- game_link_codes
-- Spiel-Codes aus dem Web-Portal: Die Website meldet sich fuer das Spiel EIGENS an (separater Passwort-Login,
-- unabhaengig von ihrer Browser-Sitzung) und legt das Refresh-Token dieser neuen Sitzung unter einem
-- 8-stelligen Code ab. Das Spiel loest den Code genau einmal ein (10 Minuten gueltig) und bekommt so eine eigene
-- Sitzung. Kein direkter Tabellenzugriff fuer Clients (RLS ohne Policies) - nur ueber die zwei Funktionen.
create table if not exists public.game_link_codes (
  code          text        primary key check (code ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$'),
  user_id       uuid        not null references auth.users (id) on delete cascade,
  refresh_token text        not null check (char_length(refresh_token) between 8 and 2048),
  created_at    timestamptz not null default now(),
  expires_at    timestamptz not null default (now() + interval '10 minutes')
);
create index if not exists game_link_codes_user_idx on public.game_link_codes (user_id);

-- Website (eingeloggt, kein Gast): Code fuer die uebergebene, eigens erzeugte Sitzung anlegen.
-- Pro Account gibt es hoechstens einen gueltigen Code.
create or replace function public.create_game_link_code(p_refresh_token text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  raw bytea;
  new_code text;
  i int;
  tries int := 0;
begin
  if uid is null then
    raise exception 'not signed in' using errcode = '28000';
  end if;
  if coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) then
    raise exception 'guest accounts cannot create game codes' using errcode = '28000';
  end if;
  if p_refresh_token is null or char_length(p_refresh_token) < 8 or char_length(p_refresh_token) > 2048 then
    raise exception 'invalid token' using errcode = '22023';
  end if;
  delete from public.game_link_codes where user_id = uid or expires_at < now();
  loop
    tries := tries + 1;
    -- gen_random_uuid() nutzt einen kryptografisch sicheren Zufallsgenerator
    raw := decode(replace(gen_random_uuid()::text, '-', ''), 'hex');
    new_code := '';
    for i in 0..7 loop
      new_code := new_code || substr(alphabet, (get_byte(raw, i) % 31) + 1, 1);
    end loop;
    begin
      insert into public.game_link_codes (code, user_id, refresh_token) values (new_code, uid, p_refresh_token);
      return new_code;
    exception when unique_violation then
      if tries > 5 then
        raise;
      end if;
    end;
  end loop;
end;
$$;

-- Spiel (auch ohne Anmeldung): Code genau einmal einloesen -> Refresh-Token der eigens erzeugten Sitzung.
create or replace function public.redeem_game_link_code(p_code text)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  tok text;
begin
  delete from public.game_link_codes where expires_at < now();
  delete from public.game_link_codes
    where code = upper(replace(replace(coalesce(p_code, ''), '-', ''), ' ', ''))
    returning refresh_token into tok;
  if tok is null then
    raise exception 'invalid or expired code' using errcode = 'P0001';
  end if;
  return tok;
end;
$$;

-- =====================================================================================
-- Row Level Security
-- =====================================================================================
alter table public.profiles      enable row level security;
alter table public.clubs         enable row level security;
alter table public.inventory     enable row level security;
alter table public.friends       enable row level security;
alter table public.lobbies       enable row level security;
alter table public.lobby_invites enable row level security;
alter table public.match_results enable row level security;
alter table public.game_link_codes enable row level security;   -- bewusst ohne Policies: nur ueber die Funktionen

-- profiles: nur die eigene Zeile (oeffentliche Infos anderer gibt es ueber public_profiles)
drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles for select to authenticated using (id = auth.uid());
drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- clubs / inventory: nur eigene Zeilen
drop policy if exists "clubs_own" on public.clubs;
create policy "clubs_own" on public.clubs for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "inventory_own" on public.inventory;
create policy "inventory_own" on public.inventory for all to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- friends: beide Seiten sehen die Zeile; anfragen darf man nur im eigenen Namen; annehmen nur der Empfaenger
drop policy if exists "friends_select" on public.friends;
create policy "friends_select" on public.friends for select to authenticated using (user_id = auth.uid() or friend_id = auth.uid());
drop policy if exists "friends_request" on public.friends;
create policy "friends_request" on public.friends for insert to authenticated with check (user_id = auth.uid() and status = 'pending');
drop policy if exists "friends_accept" on public.friends;
create policy "friends_accept" on public.friends for update to authenticated using (friend_id = auth.uid()) with check (friend_id = auth.uid());
drop policy if exists "friends_remove" on public.friends;
create policy "friends_remove" on public.friends for delete to authenticated using (user_id = auth.uid() or friend_id = auth.uid());

-- lobbies: jeder Eingeloggte darf sie finden (Raum-Code / Schnellspiel); anlegen/aendern/loeschen nur der Host
drop policy if exists "lobbies_select" on public.lobbies;
create policy "lobbies_select" on public.lobbies for select to authenticated using (true);
drop policy if exists "lobbies_insert" on public.lobbies;
create policy "lobbies_insert" on public.lobbies for insert to authenticated with check (host_id = auth.uid());
drop policy if exists "lobbies_update" on public.lobbies;
create policy "lobbies_update" on public.lobbies for update to authenticated using (host_id = auth.uid()) with check (host_id = auth.uid());
drop policy if exists "lobbies_delete" on public.lobbies;
create policy "lobbies_delete" on public.lobbies for delete to authenticated using (host_id = auth.uid());

-- lobby_invites: einladen darf man nur Freunde; sehen/loeschen duerfen Absender und Empfaenger
drop policy if exists "invites_select" on public.lobby_invites;
create policy "invites_select" on public.lobby_invites for select to authenticated using (to_id = auth.uid() or from_id = auth.uid());
drop policy if exists "invites_insert" on public.lobby_invites;
create policy "invites_insert" on public.lobby_invites for insert to authenticated
  with check (from_id = auth.uid() and public.are_friends(from_id, to_id));
drop policy if exists "invites_delete" on public.lobby_invites;
create policy "invites_delete" on public.lobby_invites for delete to authenticated using (to_id = auth.uid() or from_id = auth.uid());

-- match_results: eigene Ergebnisse eintragen und lesen
drop policy if exists "results_select_own" on public.match_results;
create policy "results_select_own" on public.match_results for select to authenticated using (user_id = auth.uid());
drop policy if exists "results_insert_own" on public.match_results;
create policy "results_insert_own" on public.match_results for insert to authenticated with check (user_id = auth.uid());

-- =====================================================================================
-- Rechte fuer die API-Rollen
-- =====================================================================================
grant usage on schema public to anon, authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select on public.public_profiles to authenticated;
grant select, insert, update, delete on public.clubs, public.inventory, public.friends, public.lobbies, public.lobby_invites to authenticated;
grant select, insert on public.match_results to authenticated;
grant execute on function public.are_friends(uuid, uuid) to authenticated;
revoke all on function public.cleanup_lobbies() from public, anon, authenticated;
revoke all on public.game_link_codes from public, anon, authenticated;
revoke all on function public.create_game_link_code(text) from public, anon;
grant execute on function public.create_game_link_code(text) to authenticated;
revoke all on function public.redeem_game_link_code(text) from public;
grant execute on function public.redeem_game_link_code(text) to anon, authenticated;

-- =====================================================================================
-- Storage: Profilbilder (Bucket "avatars", oeffentlich lesbar, max. 512 KB, nur PNG/JPEG/WebP)
-- Schreiben/Loeschen nur im eigenen Ordner "<user-id>/" und nicht als Gast.
-- =====================================================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 524288, array['image/png', 'image/jpeg', 'image/webp'])
on conflict (id) do update
  set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars_insert_own" on storage.objects;
create policy "avatars_insert_own" on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
              and not coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false));
drop policy if exists "avatars_update_own" on storage.objects;
create policy "avatars_update_own" on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text)
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_delete_own" on storage.objects;
create policy "avatars_delete_own" on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "avatars_select_own" on storage.objects;
create policy "avatars_select_own" on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- Hinweis zur Sicherheit: Coins, Gems, Trophaeen und der Spielstand werden vom Client geschrieben.
-- Das reicht fuer Spiele unter Freunden; fuer einen oeffentlichen Release sollten Belohnungen und
-- Kaeufe serverseitig (RPC / Edge Function) vergeben und die Spalten fuer Clients gesperrt werden.
