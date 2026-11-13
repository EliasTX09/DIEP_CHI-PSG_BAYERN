-- Verhaltenstest fuer supabase_schema.sql (laeuft in der CI gegen Postgres mit tests/schema_stub.sql).
-- Prueft Trigger, eindeutige Freundes-Paare und vor allem die Row-Level-Security aus Sicht der Rolle "authenticated".

insert into auth.users (id, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', '{"name": "Anna", "device_id": "dev-a"}'),
  ('00000000-0000-0000-0000-00000000000b', '{"name": "Ben"}'),
  ('00000000-0000-0000-0000-00000000000c', '{}');

do $$
begin
  assert (select count(*) from public.profiles) = 3, 'Trigger legt fuer jeden User ein Profil an';
  assert (select username from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = 'Anna', 'Name aus den Metadaten';
  assert (select device_id from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = 'dev-a', 'Geraete-ID uebernommen';
  assert (select username from public.profiles where id = '00000000-0000-0000-0000-00000000000c') like 'Gast%', 'Standardname fuer Gaeste';
  assert (select count(distinct friend_code) from public.profiles) = 3, 'Freundes-Codes eindeutig';
  assert (select min(char_length(friend_code)) from public.profiles) = 8, 'Freundes-Code hat 8 Zeichen';
end $$;

-- ------------------------------------------------------------ als Anna
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
do $$
declare n int;
begin
  select count(*) into n from public.profiles;
  assert n = 1, 'Anna sieht in profiles nur sich selbst';
  select count(*) into n from public.public_profiles;
  assert n = 3, 'Anna sieht alle oeffentlichen Profile';
  update public.profiles set coins = 999 where id = '00000000-0000-0000-0000-00000000000b';
  get diagnostics n = row_count;
  assert n = 0, 'Anna kann Bens Profil nicht aendern';
  -- Upsert wie im Spiel (PostgREST merge-duplicates)
  insert into public.profiles (id, username, coins, trophies, save, revision)
    values ('00000000-0000-0000-0000-00000000000a', 'Anna', 50, 120, '{"revision": 2}', 2)
    on conflict (id) do update set coins = excluded.coins, trophies = excluded.trophies, save = excluded.save, revision = excluded.revision;
  assert (select coins from public.profiles where id = '00000000-0000-0000-0000-00000000000a') = 50, 'Eigenes Profil per Upsert aktualisiert';
  insert into public.clubs (user_id, club_id, level, cards) values ('00000000-0000-0000-0000-00000000000a', 'allround_common', 2, 3)
    on conflict (user_id, club_id) do update set level = excluded.level, cards = excluded.cards;
  insert into public.inventory (user_id, item_type, item_id, equipped) values ('00000000-0000-0000-0000-00000000000a', 'ball', 'magma', true);
  begin
    insert into public.clubs (user_id, club_id) values ('00000000-0000-0000-0000-00000000000b', 'driver_rare');
    raise exception 'FEHLER: Anna konnte einen Schlaeger fuer Ben anlegen';
  exception when insufficient_privilege then null;
  end;
  insert into public.friends (user_id, friend_id) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b');
  update public.friends set status = 'accepted' where user_id = '00000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  assert n = 0, 'Anna kann ihre eigene Anfrage nicht selbst annehmen';
  begin
    insert into public.friends (user_id, friend_id, status) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000c', 'accepted');
    raise exception 'FEHLER: Freundschaft ohne Zustimmung angelegt';
  exception when insufficient_privilege then null;
  end;
  insert into public.lobbies (code, host_id, world, rounds) values ('AB12', '00000000-0000-0000-0000-00000000000a', 'neon', 5);
  begin
    insert into public.lobby_invites (from_id, to_id, code) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'AB12');
    raise exception 'FEHLER: Einladung an Nicht-Freund moeglich';
  exception when insufficient_privilege then null;
  end;
  insert into public.match_results (user_id, mode, world, rounds, rank, players, strokes) values ('00000000-0000-0000-0000-00000000000a', 'private', 'neon', 5, 1, 4, 14);
end $$;
commit;

-- ------------------------------------------------------------ als Ben
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$
declare n int;
begin
  select count(*) into n from public.clubs;
  assert n = 0, 'Ben sieht Annas Schlaeger nicht';
  select count(*) into n from public.inventory;
  assert n = 0, 'Ben sieht Annas Inventar nicht';
  select count(*) into n from public.match_results;
  assert n = 0, 'Ben sieht Annas Ergebnisse nicht';
  select count(*) into n from public.friends;
  assert n = 1, 'Ben sieht die Anfrage von Anna';
  update public.friends set status = 'accepted' where friend_id = '00000000-0000-0000-0000-00000000000b';
  get diagnostics n = row_count;
  assert n = 1, 'Ben nimmt die Anfrage an';
  assert public.are_friends('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b'), 'are_friends = true';
  begin
    insert into public.friends (user_id, friend_id) values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
    raise exception 'FEHLER: doppeltes Freundes-Paar moeglich';
  exception when unique_violation then null;
  end;
  select count(*) into n from public.lobbies where code = 'AB12';
  assert n = 1, 'Ben findet die Lobby per Code';
  delete from public.lobbies where code = 'AB12';
  get diagnostics n = row_count;
  assert n = 0, 'Ben kann Annas Lobby nicht loeschen';
  begin
    insert into public.lobbies (code, host_id) values ('ZZ99', '00000000-0000-0000-0000-00000000000a');
    raise exception 'FEHLER: Lobby im Namen eines anderen angelegt';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into public.lobbies (code, host_id, rounds) values ('QQ11', '00000000-0000-0000-0000-00000000000b', 4);
    raise exception 'FEHLER: ungueltige Rundenzahl akzeptiert';
  exception when check_violation then null;
  end;
end $$;
commit;

-- ------------------------------------------------------------ Anna laedt Ben ein, Ben sieht es, Carl nicht
begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000a';
insert into public.lobby_invites (from_id, to_id, code) values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'AB12');
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000b';
do $$ begin assert (select count(*) from public.lobby_invites) = 1, 'Ben sieht seine Einladung'; end $$;
commit;

begin;
set local role authenticated;
set local request.jwt.claim.sub = '00000000-0000-0000-0000-00000000000c';
do $$
begin
  assert (select count(*) from public.lobby_invites) = 0, 'Carl sieht fremde Einladungen nicht';
  assert (select count(*) from public.friends) = 0, 'Carl sieht fremde Freundschaften nicht';
end $$;
commit;

-- ------------------------------------------------------------ anonym (nicht eingeloggt): kein Zugriff
begin;
set local role anon;
do $$
declare n int;
begin
  begin
    select count(*) into n from public.profiles;
    raise exception 'FEHLER: anon darf profiles lesen';
  exception when insufficient_privilege then null;
  end;
end $$;
commit;

-- ------------------------------------------------------------ Spiel-Codes (Web-Portal -> Spiel)
create temp table test_codes (who text primary key, code text);
grant all on test_codes to anon, authenticated;

begin;
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-00000000000a", "is_anonymous": false}';
do $$
declare c1 text; c2 text; n int;
begin
  c1 := public.create_game_link_code('rt-anna-game-session-1');
  assert c1 ~ '^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{8}$', 'Code hat 8 Zeichen aus dem Code-Alphabet';
  c2 := public.create_game_link_code('rt-anna-game-session-2');
  assert c1 <> c2, 'Neuer Code bei erneutem Erzeugen';
  insert into test_codes values ('anna_old', c1), ('anna', c2);
  begin
    select count(*) into n from public.game_link_codes;
    assert false, 'Website darf die Code-Tabelle nicht direkt lesen';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.create_game_link_code('kurz');
    assert false, 'Zu kurzes Token wird abgelehnt';
  exception when invalid_parameter_value then null;
  end;
end $$;
commit;

begin;
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-00000000000c", "is_anonymous": true}';
do $$
begin
  perform public.create_game_link_code('rt-guest-session-123');
  assert false, 'Gaeste duerfen keine Spiel-Codes erzeugen';
exception when invalid_authorization_specification then null;
end $$;
commit;

do $$
begin
  assert (select count(*) from public.game_link_codes where user_id = '00000000-0000-0000-0000-00000000000a') = 1, 'Hoechstens ein gueltiger Code pro Account';
  insert into public.game_link_codes (code, user_id, refresh_token, expires_at)
    values ('EXPRD234', '00000000-0000-0000-0000-00000000000b', 'rt-ben-expired-xyz', now() - interval '1 minute');
end $$;

-- Einloesen als nicht angemeldetes Spiel (Rolle anon)
begin;
set local role anon;
do $$
declare tok text; c text; n int;
begin
  select code into c from test_codes where who = 'anna';
  tok := public.redeem_game_link_code(lower(substr(c, 1, 4)) || '-' || substr(c, 5));
  assert tok = 'rt-anna-game-session-2', 'Code liefert das Token der eigens erzeugten Sitzung (Kleinschreibung/Bindestrich egal)';
  begin
    perform public.redeem_game_link_code(c);
    assert false, 'Code ist nur einmal gueltig';
  exception when raise_exception then null;
  end;
  select code into c from test_codes where who = 'anna_old';
  begin
    perform public.redeem_game_link_code(c);
    assert false, 'Ersetzter alter Code ist ungueltig';
  exception when raise_exception then null;
  end;
  begin
    perform public.redeem_game_link_code('EXPRD234');
    assert false, 'Abgelaufener Code ist ungueltig';
  exception when raise_exception then null;
  end;
  begin
    perform public.create_game_link_code('rt-anon-session-123');
    assert false, 'anon darf keine Codes erzeugen';
  exception when insufficient_privilege then null;
  end;
  begin
    select count(*) into n from public.game_link_codes;
    assert false, 'anon darf die Code-Tabelle nicht lesen';
  exception when insufficient_privilege then null;
  end;
end $$;
commit;

do $$
begin
  assert (select count(*) from public.game_link_codes) = 0, 'Eingeloeste und abgelaufene Codes sind geloescht';
end $$;

-- ------------------------------------------------------------ Profilbilder
begin;
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-00000000000a", "is_anonymous": false}';
do $$
declare n int;
begin
  update public.profiles set avatar_path = '00000000-0000-0000-0000-00000000000a/avatar-1700000000.png'
    where id = '00000000-0000-0000-0000-00000000000a';
  get diagnostics n = row_count;
  assert n = 1, 'Eigenes Profilbild eintragen';
  begin
    update public.profiles set avatar_path = '00000000-0000-0000-0000-00000000000b/avatar-1.png'
      where id = '00000000-0000-0000-0000-00000000000a';
    assert false, 'Pfad in fremdem Ordner wird abgelehnt';
  exception when check_violation then null;
  end;
  begin
    update public.profiles set avatar_path = 'https://evil.example/x.png' where id = '00000000-0000-0000-0000-00000000000a';
    assert false, 'URL statt Pfad wird abgelehnt';
  exception when check_violation then null;
  end;
  assert (select avatar_path from public.public_profiles where id = '00000000-0000-0000-0000-00000000000a')
    = '00000000-0000-0000-0000-00000000000a/avatar-1700000000.png', 'Profilbild-Pfad ist oeffentlich sichtbar';
  insert into storage.objects (bucket_id, name) values ('avatars', '00000000-0000-0000-0000-00000000000a/avatar-1700000000.png');
  begin
    insert into storage.objects (bucket_id, name) values ('avatars', '00000000-0000-0000-0000-00000000000b/avatar-1.png');
    assert false, 'Upload in fremden Ordner verboten';
  exception when insufficient_privilege then null;
  end;
end $$;
commit;

begin;
set local role authenticated;
set local request.jwt.claims = '{"sub": "00000000-0000-0000-0000-00000000000c", "is_anonymous": true}';
do $$
begin
  insert into storage.objects (bucket_id, name) values ('avatars', '00000000-0000-0000-0000-00000000000c/avatar-1.png');
  assert false, 'Gaeste laden keine Profilbilder hoch';
exception when insufficient_privilege then null;
end $$;
commit;

do $$
begin
  assert (select public and file_size_limit = 524288 from storage.buckets where id = 'avatars'), 'Bucket avatars: oeffentlich, 512 KB';
  assert not exists (select 1 from information_schema.columns where table_name = 'public_profiles' and column_name in ('save', 'coins', 'device_id')),
    'public_profiles zeigt keinen Spielstand';
end $$;

select public.cleanup_lobbies();
select 'SCHEMA TEST: PASS' as result;
