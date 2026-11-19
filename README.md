# ⛳ Golf Battle 3D – Arcade-Multiplayer-Minigolf für Android (Godot 4)

Echtes 3D-Arcade-Minigolf: 15 Bahnen in 4 Welten, eingebettet in Täler mit Bergen, Klippen, Wäldern und Schluchten,
Abkürzungs-Rampen, Loopings, Kanonen, Teleporter, Hämmer, Bäche, Lava und Wasser,
immer 5 Spieler pro Match (freie Plätze füllen Bots), Einsatz pro Welt, Schlägertasche mit Upgrades, Truhen, Ligen
und ein täglicher „Golden Shot“. **Alles** – Bahnen, Modelle, Effekte, Shader und Sounds – wird per Code erzeugt.
Es gibt keine `.glb`-, `.fbx`- oder `.wav`-Dateien im Projekt.

> Engine: **Godot 4.5** (GDScript, Mobile-Renderer, Jolt Physics) · Backend: **Supabase** (optional) ·
> Build: **GitHub Actions** → `GolfBattle3D.apk`
> Hochformat (einhändig) · Web-Portal für Accounts in [`webapp/`](webapp) (GitHub Pages)
> Die `index.html` im Repo-Root gehört nicht zum Spiel.

> **Umbau-Stand:** Hochformat-Hauptmenü (Arena-Auswahl mit 3D-Hintergrund, Tab-Leiste Spielen · Tasche · Pass ·
> Freunde · Shop, Account-Knopf), Hochformat-HUD, kostenloser Battle Pass (28-Tage-Saisons, 30 Stufen), Bahnen in
> Berg-Tälern, Abkürzungs-Rampen (mehrere pro Bahn, teils nur mit starkem Schläger), Hindernisse auf der Bahn, Randbäume mit Ästen über der Bahn,
> Wurzeln und Felsen, neue Bäume (Stamm + Kronen-Cluster), Ruinen, Golfball mit Dellen, Squash & Stretch,
> federndes Gummiband, Trophäen pro Bahn, Arena-Sperren, adaptive Bots und Mehrfach-Einladungen sind fertig.
> Ziel-Kamera mit Tiefenunschärfe und Feder-Führung, leuchtende Punkt-Kette entlang des Flugbogens und
> Kontaktschatten unter den Bällen sind ebenfalls fertig.
> Neu: steiler Top-Down-Blick (Ball im unteren Drittel, Rasen füllt das Bild), knalligeres Schachbrett mit
> pixelscharfen Kanten, dünner Neon-Zug-Pfeil hinter dem Ball mit Kraft in Prozent direkt am Ball (kein Kraftbalken
> mehr unten), flache obere Leiste auf abgedunkeltem Verlauf.
> Noch offen: Flyover-Vorschau, Eis-Welt, Clans.

---

## Schnellstart in 4 Schritten

### 1. Supabase einrichten (optional – ohne Backend läuft das Spiel offline mit Bots)

1. Auf [supabase.com](https://supabase.com) ein kostenloses Projekt anlegen.
2. **SQL Editor → New query**: den kompletten Inhalt von [`supabase_schema.sql`](supabase_schema.sql) einfügen
   und **Run** drücken. Das Skript ist wiederholbar (zweimal ausführen schadet nicht) und legt an:
   `profiles`, `clubs`, `inventory`, `friends`, `lobbies`, `lobby_invites`, `match_results`, `game_link_codes`
   inklusive Row-Level-Security, dazu den Storage-Bucket **`avatars`** für Profilbilder (öffentlich lesbar, max. 512 KB).
3. **Authentication → Sign In / Providers**:
   - **„Allow anonymous sign-ins“ einschalten** (für den Sofort-Gast-Login per Geräte-ID).
   - **Email** aktiviert lassen (zum Verknüpfen des Gast-Accounts mit E-Mail + Passwort).
   - **„Confirm email“:** Ohne eigenen Mail-Server (SMTP) verschickt Supabase Bestätigungs-Mails nur
     eingeschränkt (Mengenlimit; je nach Projekt evtl. nur an Mitglieder deines Supabase-Teams). Kommen bei
     der Registrierung im Portal keine Mails an, entweder unter **Authentication → Emails → SMTP Settings**
     einen eigenen Mail-Server eintragen oder „Confirm email“ ausschalten (dann sind Konten ohne Bestätigung
     sofort aktiv). Der Gast-Login im Spiel braucht keine Mail.
4. **Authentication → URL Configuration**: als **Site URL** und unter **Redirect URLs** die Adresse deines
   Web-Portals eintragen (z.B. `https://<dein-name>.github.io/<repo>/`), damit Bestätigungs- und
   Passwort-Mails zurück aufs Portal führen.
5. **Project Settings → API**: die **Project URL** und den **anon public**-Key kopieren.
   ⚠️ **Niemals** den `service_role`-Key verwenden – der gehört nie in eine App.

### 2. Zugangsdaten eintragen – eine der beiden Varianten

**Variante A (empfohlen): GitHub Secrets** – dann stehen die Werte nicht im Repository.
GitHub → dein Repo → **Settings → Secrets and variables → Actions → New repository secret**:

| Name | Wert |
|---|---|
| `SUPABASE_URL` | `https://xxxx.supabase.co` |
| `SUPABASE_ANON_KEY` | dein anon public Key |
| `WEB_PORTAL_URL` (optional) | Adresse des Web-Portals; ohne Angabe: `https://<besitzer>.github.io/<repo>/` |

Der Workflow schreibt sie beim Build in `config/backend.cfg`.

**Variante B:** direkt in [`config/backend.cfg`](config/backend.cfg) eintragen:

```ini
[supabase]
url="https://xxxx.supabase.co"
anon_key="eyJhbGciOi..."
```

Solange dort die Platzhalter stehen, startet das Spiel im **Offline-Modus** (Bots, lokaler Speicherstand).
Beide Werte sind öffentlich (sie stecken ohnehin in der APK und im Portal) – geschützt wird alles durch die
RLS-Regeln im Schema. Das Web-Portal nimmt dieselben Werte, wenn keine Secrets gesetzt sind.

Die automatischen Tests laufen auch mit eingetragenem Backend immer **offline** (CI legt dafür eine
`config/backend.local.cfg` mit Platzhaltern an und löscht sie vor dem APK-Export) – normale Pushes legen also
keine Test-Accounts in deinem Projekt an.

### 2b. Live-Backend prüfen (ein Klick)

**Actions → Build Android APK → Run workflow → Haken bei „backend_check“ → Run.** Das prüft das echte Projekt
genau so, wie das Spiel es benutzt: Gast-Login, automatisch angelegtes Profil, RLS (fremde Spielstände bleiben
privat), Lobby anlegen und per Code finden, Echtzeit-Kanal mit Spielerliste (Presence) und Nachrichten
(Broadcast), Spiel-Code-Funktion und Profilbild-Speicher. Bei Fehlern steht im Log, was im Dashboard fehlt.
Jeder Lauf legt zwei Gast-Accounts „CI Test A/B“ an (unter Authentication → Users löschbar).

Hinweis: Kostenlose Supabase-Projekte werden nach etwa einer Woche ohne Nutzung pausiert – dann im Dashboard
auf „Restore“ klicken.

### 3. Auf GitHub pushen

Der Workflow [`.github/workflows/build_android.yml`](.github/workflows/build_android.yml) läuft bei jedem Push auf
`main` (und auf Entwicklungs-Branches `ccr-*`) sowie manuell über **Actions → Build Android APK → Run workflow**.
Er

1. nutzt Godot 4.5.2 mit Export-Templates, Android-SDK und Java 17 (Docker-Image `barichello/godot-ci:4.5.2`),
2. erzeugt einen Debug-Keystore,
3. importiert das Projekt und bricht bei jedem Skriptfehler ab,
4. beweist, dass wirklich **Jolt Physics** rechnet (Physik-Fingerabdruck),
5. führt einen Headless-Smoke-Test aus (Logik, Physik, alle Bahnen, Bots, komplette Partie, Touch-Gesten, Menü),
6. exportiert **`GolfBattle3D.apk`** und lädt sie als **Artifact** hoch,
7. veröffentlicht sie bei Pushes auf `main` zusätzlich als **GitHub Release** (`build-<Nummer>`).

Parallel laufen ein Shader-Check mit Software-Rendering (inkl. Screenshots) und ein Test des SQL-Schemas
gegen eine echte PostgreSQL-Datenbank.

### 4. APK herunterladen und installieren

1. GitHub → **Actions** → letzter grüner Lauf von „Build Android APK“ → unten bei **Artifacts** auf
   **GolfBattle3D-apk** klicken (ZIP entpacken) – oder bei Builds von `main` unter **Releases** die APK laden.
2. APK aufs Handy kopieren (oder direkt am Handy herunterladen) und antippen.
3. Android fragt nach **„Installation aus unbekannten Quellen“** → für den Browser/Dateimanager erlauben.
4. Installieren, starten – fertig. Das Spiel läuft im Hochformat.

Voraussetzungen am Gerät: Android 7+ mit **arm64** (praktisch alle Geräte seit ca. 2017).
Der Mobile-Renderer nutzt Vulkan; auf Geräten ohne Vulkan wechselt Godot automatisch auf OpenGL.

### 5. Web-Portal veröffentlichen (Account, Profilbild, Freunde)

Das Portal liegt in [`webapp/`](webapp) – reines HTML/CSS/JavaScript ohne externe Bibliotheken.

1. GitHub → **Settings → Pages → Source: „GitHub Actions“** (falls auf GitHub Pages dieses Repositorys schon
   eine andere Seite läuft: Achtung, das Portal ersetzt sie – dann lieber ein eigenes Repository dafür nutzen).
2. Die Secrets `SUPABASE_URL` und `SUPABASE_ANON_KEY` setzen (wie oben).
3. **Actions → „Web-Portal veröffentlichen“ → Run workflow** (läuft bewusst nur manuell und vom Standard-Branch).

**So verbindet man das Spiel mit dem Web-Account:**
1. Im Spiel: **„Account verknüpfen / Anmelden“** auf dem Startbildschirm (oder Profil → „Account verknüpfen /
   Registrieren“) öffnet das Portal im Browser.
2. Dort registrieren bzw. einloggen, Profilbild hochladen, Freunde verwalten.
3. **„Spiel-Code erzeugen“** (Passwort bestätigen) → 8-stelliger Code, 10 Minuten und nur einmal gültig.
4. Code im Spiel unter **Profil → Spiel-Code → Einlösen** eingeben. Das Spiel erhält dabei eine **eigene** Anmeldung
   (die Browser-Sitzung wird nie weitergegeben) und speichert nur das Refresh-Token verschleiert in `user://auth.save`
   (nie E-Mail oder Passwort).
5. Hatte das Spiel schon Fortschritt als Gast und der Web-Account ebenfalls, wird der Stand des Accounts geladen
   und der Gast-Stand als Sicherung (`user://save_backup_*.json`) abgelegt – es geht nichts still verloren.
   Ist der Web-Account neu, übernimmt er den Gast-Fortschritt.

Ein Direkt-Sprung vom Browser zurück ins Spiel (Deep-Link) ist **nicht** eingebaut – dafür bräuchte die APK
einen eigenen Android-Build mit Intent-Filter. Der Code wird deshalb abgetippt.

---

## Steuerung

| Geste | Wirkung |
|---|---|
| Am Ball ziehen und loslassen | Schlag: nach hinten ziehen – ein dünner Neon-Pfeil spannt sich hinter dem Ball (Spitze zeigt in Schussrichtung, weißer Rand; er federt, schwingt nach und schnellt beim Loslassen zurück), die Kraft steht in Prozent als kleine Anzeige direkt neben dem Ball, loslassen schießt nach vorn. Sobald du den Ball berührst, verschwinden alle Namen, die Kamera fährt näher heran und der Hintergrund verschwimmt. Vorn zeigt eine leuchtende Punkt-Kette den Flugbogen, wo der Ball aufkommt, abprallt und ausrollt (echte Simulation, Spin wird live eingerechnet), am Ende ein pulsierender Zielkreis. Länge der Kette = Guide-Wert des Schlägers, Größe des Landerings = Accuracy |
| Ein Finger irgendwo sonst | Kamera 360° drehen und neigen |
| Zwei Finger | Pinch-Zoom |
| Auge-Button | Vogelperspektive |
| „ROLLEN / CHIP“ | Putt am Boden oder Chip-Schlag in die Luft |
| Spin-Widget | Topspin, Backspin, Seiten-Effet |
| Smiley-Button | Emotes & Quick-Chat („Nice Shot!“, „Oops!“, 🔥, 😂 …) |
| Android-Zurück | schließt Fenster bzw. fragt vor dem Beenden |

## Inhalte

- **Welten & Bahnen (15 + Daily):** Emerald Valley (5), Volcano Canyon (4), Cyber Neon City (3), Pirate Cove / Sky Ruins (3),
  jede Welt mit eigenem Himmel, Licht, Nebel und Shadern (Wasser, Lava, Neon-Hologramm, Holzplanken, Wasserfall …).
- **Landschaft:** Jede Bahn liegt in einem Tal: Randstreifen, Wiesen-Böschungen, Felsterrassen und Klippen,
  Bergrücken mit Schnee, ein Bergkranz im Nebel, Tannen-/Laub-/Palmenwälder bzw. tote Bäume und Hochhäuser (Neon),
  Wasserfall-Kaskade oder Lavastrom, Piratenbucht mit Meer und Schiff. Unter Sprüngen und Stücken ohne Bande klafft
  eine Schlucht. Wer das Gelände neben der Bahn berührt, ist **aus** (+1 Strafschlag).
- **Abkürzungen (Rampen):** Bis zu drei pro Bahn (nicht auf der geraden Einsteiger-Bahn e1 und im Golden Shot; der
  Planer baut nur dort welche, wo ein rein physikalischer Sprung sicher landen kann), jede an einer eigenen Öffnung in
  der Bande: ein schmaler Steg ohne Banden führt durch ein Felsentor zu einer **Rampe**.
  Es gibt keinen Boost und kein Zielflug – wie weit der Ball fliegt, ergibt sich nur aus dem Tempo, mit dem er die
  Rampe hinauffährt, und geflogen wird geradeaus in Rampen-Richtung. Zu langsam = zu kurz (Schlucht = Aus), zu
  schnell = zu weit, schräg angespielt = vom Steg gerollt. **Power-Rampen** (rot glühende Bänder am Tor) brauchen mehr
  Tempo, als der Startschläger hergibt – die schafft man nur mit einem Schläger mit hoher Schlagkraft.
- **Hindernisse:** Bäche quer über die Bahn mit schmalem Holzsteg, tiefes Rough am Rand, Baumstämme und Felsbrocken,
  Lianen-Bögen, Sandbunker (geschwungener Umriss, gerechte Rillen, dunklerer Rand). Am Bahnrand stehen Bäume, von denen mindestens 40 % einen dicken Ast quer über die Bahn
  strecken (2,55 m hoch: gerollte Bälle passen drunter durch, hohe Chips prallen ab), knorrige Wurzeln und Felsen
  ragen in die Bahn (echte Kollision, der Ball hüpft drüber oder prallt ab). Laub, Lianen, Grasbüschel und lose Steine
  sind nur Optik.
- **Grafik:** Bäume aus dickem Stamm mit Rinden-Struktur und 3–5 Kronen-Clustern (Wind, Durchscheinen),
  bemooste Felsen und Säulen-Ruinen, satter Rasen mit kräftigem dunkel-/hellgrünem Schachbrett (pixelscharfe Kanten),
  feinem Glanz und
  Kontaktschatten an den Banden, weicher Kontaktschatten unter jedem Ball, Tiefenunschärfe beim Zielen, Wasser mit
  Gerstner-Wellen, Golfball mit ~330 Dellen und Klarlack, Squash & Stretch, Staubwolke + Kamerawackeln bei harten
  Abprallern, weiche Schatten („Soft High“), Kantenglättung SMAA. SSAO und volumetrischer Nebel gibt es im Mobile-Renderer
  nicht (siehe Ehrlicher Status).
- **Spielen & Einsatz:** SPIELEN öffnet das Lobby-Menü mit allen Welten. Jede Welt hat ihren eigenen Einsatz
  (Emerald 100 · Volcano 250 · Neon 500 · Pirate 1000 Coins), der beim Start eingezahlt wird. Es spielen immer
  5 Spieler. Auszahlung nach Platz: 1. doppelter Einsatz · 2. 1,5-fach · 3. 1,25-fach · 4. Einsatz zurück ·
  5. nichts. Trophäen: +9 / +5 / +3 / 0 / −3. **Mit Freunden** (Lobby mit Raum-Code) geht es nur um Coins, nicht um
  Trophäen, und spielbar sind nur Welten, die alle im Raum freigeschaltet haben.
- **Lochende:** Alle starten an derselben Stelle. Sobald der Erste eingelocht hat, haben alle anderen noch
  20 Sekunden. Wer dann nicht im Loch ist, bekommt die Schläge des schlechtesten Eingelochten + 2.
- **Arenen & Trophäen:** Arena 1 ist offen, die weiteren ab 150 / 400 / 800 Trophäen (beste erreichte Zahl).
  Jede Bahn führt eigene Trophäen (Aufteilung der Match-Trophäen nach deiner Platzierung auf der Bahn).
- **Bots:** keine manuelle Auswahl – immer so viele, dass 5 Spieler am Start sind. Sie planen jeden Schlag mit der
  echten Physik-Simulation (kurze Bedenkzeit); je mehr Trophäen du auf einer Bahn hast, desto genauer spielen sie
  dort und desto öfter nehmen sie eine Abkürzungs-Rampe (unter 6 Bahn-Trophäen nie).
- **Bahn-Baukasten:** Rampen, Steilkurven, Spiralen, Loopings, Brücken, Lücken, Boost-Pads, Windzonen, Teleporter,
  Kanonen, Laser-Tore, Sandbunker, Windmühlen, Pendel-Hämmer, Schiebeblöcke, fahrende Plattformen.
- **Multiplayer:** Gast-Login per Geräte-ID, Verknüpfen mit E-Mail/Passwort, Spielername, Avatar-Farbe und -Rahmen,
  5 Spieler pro Match (alle schlagen parallel, freie Plätze füllen Bots), Live-Rangliste, Emotes, Freunde (Suche per Name oder
  Freundes-Code, Anfragen, Online-Status), private Lobby mit 4-stelligem Raum-Code oder Einladung (mehrere Freunde
  auf einmal ankreuzen), Welt und 3/5/9 Runden.
- **Progression:** 16 Schläger (4 Kategorien × 4 Seltenheiten, Werte Power/Accuracy/Spin/Guide, Upgrades mit Coins + Karten),
  6 Bälle mit kleinen Boni, 6 Trails, 5 Loch-Explosionen mit Screen-Shake und Bass, 4 Truhen-Slots mit Timern
  (oder sofort per Gems), Trophäen, 5 Ligen und Trophäen-Pfad.
- **Extras:** Style-Punkte („Air Time!“, „Bank Shot!“, „Close Call!“, Hole-in-One) für Pass-XP,
  Golden Shot (ein Schlag pro Tag, Belohnung nach Abstand zur Fahne), Replay des besten Schlags in Zeitlupe.
- **Sound:** prozeduraler Synthesizer (`AudioStreamGenerator`) – Abschlag je nach Kraft, Abpraller auf Holz/Stein/Metall,
  Wind bei hohen Sprüngen, Wasser-/Lava-Platscher, Loch-Sound + Fanfare, UI-Klicks, Truhen-Jingle.

## Projektstruktur

```
project.godot                     Godot 4.5, Mobile-Renderer, Jolt Physics, Hochformat (720 x 1280), SMAA, Schatten
export_presets.cfg                Android-Export (arm64, INTERNET, ACCESS_NETWORK_STATE, VIBRATE)
supabase_schema.sql               Tabellen, RLS-Policies, Trigger, Spiel-Code-Funktionen, Storage-Bucket "avatars"
config/backend.cfg                Supabase-URL + anon-Key + Web-Portal-Adresse (Platzhalter = Offline-Modus)
.github/workflows/build_android.yml   Tests + APK + Schema-Test + Portal-Browsertest
.github/workflows/pages.yml           Web-Portal auf GitHub Pages veröffentlichen (manuell)
webapp/                           Web-Portal: index.html, app.js, style.css, config.js
scenes/                           MainMenuView.tscn, Game.tscn, GameHUD.tscn
shaders/                          22 eigene Shader (Gelände, Rasen grass_fairway, Flora, Sand, Wasser water_realistic, Lava,
                                  Himmel, Neon, Portal, Golfball golfball_dimples, Ball-Skins, Zug-Pfeil aim_band,
                                  Punkte/Ringe aim_marker, Kontaktschatten contact_shadow …)
scripts/autoload/                 GameManager (Speicherstand, Wirtschaft, Truhen, Ligen),
                                  AuthManager (Login, Session, Web-Code), ProfileManager (Profilbild),
                                  NetworkManager (Profil-Sync, Freunde, Lobbys, Realtime), SoundManager (Synthesizer)
scripts/data/Catalog.gd           Alle Spieldaten (Schläger, Bälle, Truhen, Ligen, Welten)
scripts/gameplay/                 Ball3D, CameraManager3D, CourseBuilder3D (inkl. Abkürzungs-Planung und Rand-Natur), TrackKit,
                                  Terrain3D (Gelände), WorldTheme (Landschaft, Licht), Gadgets, Obstacles, ShotSim (Vorhersage),
                                  BotBrain (Physik-KI), SmartBotController (adaptive Bots), Match3D (Spielablauf, Ziel-Vorschau)
scripts/fx/                       Materialien, Partikel, Flora (Bäume, Felsen), Ball-Skins, Explosionen, Schlägermodelle, Emoji-Icons
scripts/ui/                       MainMenu (MainMenuView), MenuPages, Preview3D, GameHUD, UIKit, UIIcon, UIAvatar
tests/                            Smoke-Test, Schein-Supabase-Server, Screenshot-Runner, Physik-Fingerabdruck,
                                  SQL-Tests, web/portal_test.js (Browser-Test), live/backend_check.mjs (echtes Projekt)
docs/ARCHITECTURE.md              Architektur und Schnittstellen
```

## Ehrlicher Status

| Bereich | Stand |
|---|---|
| Import, alle Skripte und Shader kompilieren | in CI geprüft |
| Jolt Physics aktiv | in CI per Physik-Fingerabdruck nachgewiesen |
| Ball-Physik vs. Vorhersage, Out-of-Bounds, Einlochen auf allen Bahnen | in CI geprüft (Smoke-Test) |
| Bots spielen alle 15 Bahnen | in CI geprüft |
| Komplette Partie mit Bots inkl. Belohnungen, Golden Shot, Touch-Gesten | in CI geprüft |
| Hochformat-Menü, alle Seiten, Battle Pass | in CI geprüft (Aufbau, Kernaktionen, Layout: alles im Bild, keine Überlappung, Mindestbreite ≤ 720 px); Freunde/Lobby im Online-Zustand mit Testdaten gegen den Schein-Server |
| Battle-Pass-Stand im Cloud-Spielstand | gegen den Schein-Server geprüft; Saisons richten sich nach der Geräte-Uhr |
| Darstellung aller Welten, HUD und Menü | per Software-Rendering in CI gerendert (720×1280 und 720×1600) und angesehen |
| SQL-Schema + RLS-Regeln | in CI gegen PostgreSQL 16 getestet |
| Login-Ablauf im Spiel (Gast, Web-Code, Profil-Abgleich, Profilbild) | in CI gegen einen **lokalen Schein-Server** getestet – prüft das Spiel, nicht den echten Supabase-Server |
| Spiel-Codes, Profilbild-Pfade, Storage-Regeln | in CI gegen PostgreSQL 16 getestet (Supabase-Storage nachgebildet) |
| Web-Portal (Registrieren, Profilbild, Freunde, Spiel-Code, XSS-Schutz, Handy-Breite) | in CI im Browser (Chromium) gegen simulierte Supabase-Antworten getestet |
| Echtes Supabase-Projekt (eingetragen in `config/backend.cfg`) | „backend_check“ (Abschnitt 2b) **bestanden**: Gast-Login, Profil per Trigger, RLS (fremde Spielstände privat, ohne Login nichts lesbar), Lobby anlegen/finden, Echtzeit-Kanal mit Presence und Broadcast, Spiel-Code-Funktion, Bucket `avatars`. Der Test spricht dasselbe Protokoll wie das Spiel, ist aber ein Node-Skript – das Spiel selbst gegen den echten Server, Freundesliste/Einladungen, Spiel-Code erzeugen und die Registrierung im Portal sind **nicht getestet**. E-Mail-Bestätigung ist im Projekt eingeschaltet |
| Hochformat-HUD | in CI geprüft (Layout oben/unten, Daumenzone) |
| Gelände-Tal | in CI geprüft: liegt auf allen 16 Bahnen überall unter dem Belag, Schluchten unter allen Sprüngen/Flügen, Aus-Grenze greift neben der Bahn; Bau ~40 ms pro Bahn |
| Abkürzungen (Rampen) | in CI geprüft (Vorhersage + echter Jolt-Ball): 10 der 14 Bahnen haben Rampen, 11 insgesamt; e5 hat zwei, p3 eine Power-Rampe (Schlagkraft ~89: vom Fairway schafft es nur ein starker Schläger). Für jede Rampe gibt es laut Vorhersage ein Tempo, mit dem sie im Ziel landet; halbes Tempo landet nicht, seitlich vom Steg = Aus. Echter Ball: landet auf e4 und beiden e5-Rampen im Ziel, auf e3 **nicht** (er fliegt an Rampen ein paar Prozent weiter als die Vorschau). Heikel (nur 1–2 Tempi treffen): e2, n1, p3. Keine Rampe auf v4, n2, n3, p1. Bots legen sich den Ball zurecht und springen (Profi-Bots auf e2 und e5) |
| Hindernisse (Bach, Rough, Stamm, Fels) | in CI geprüft (Wirkung + Bots locht weiter auf allen 15 Bahnen ein) |
| Randbäume mit Ästen über der Bahn, Wurzeln, Randfelsen | in CI geprüft (Platzierung hängt nur von der Bahn ab – im Match identisch): 36 Randbäume, davon 20 mit Ast über der Bahn, 9 Wurzeln, 10 Felsen; Äste auf 10 der 12 Natur-Bahnen (v4 und p1 haben keine Randbäume: zu viele Steilstücke bzw. Planken ohne Bande). Unter jeder Astspitze liegt nachweislich Bahnbelag, eine Ball-Kugel passt rollend darunter durch, die Äste haben Kollision. Abkürzungen weiter 14/14, Bots weiter 15/15. Auf Par-4-Bahnen nur Bäume (keine Wurzeln/Felsen auf der Bahn) |
| Trophäen pro Bahn, Arena-Sperren | in CI geprüft (Aufteilung summiert exakt, Freischaltung nach bester Trophäenzahl, sperrt nicht wieder zu, Welttour nur durch offene Arenen) |
| Einsatz-Lobby, Auszahlung, 5 Spieler | in CI geprüft: jede Welt hat ihren Einsatz (100/250/500/1000), er wird genau einmal eingezahlt, Auszahlung 2×/1,5×/1,25×/1×/0, Trophäen +9/+5/+3/0/−3, Freunde-Lobby ohne Trophäen, zu wenig Coins = es wird nur eingezahlt, was da ist; Bot-Matches immer mit 5 Spielern. Nicht automatisch geprüft: Freunde-Lobby mit echten Mitspielern online (nur gemeinsam offene Welten) |
| Gleicher Abschlag, 20 s Nachziehen | Code fertig, die komplette Partie läuft in CI durch; die 20-Sekunden-Regel und die Wertung „schlechtester Eingelochter + 2“ sind nicht einzeln als Test abgedeckt |
| Adaptive Bots (SmartBotController) | in CI geprüft: ohne Bahn-Trophäen plant kein Bot die Abkürzung (rollt er durch einen Zielfehler doch auf die Schanze, wird das nur protokolliert – kam auf n2 vor). Bots mit Können 0,7 ohne Abkürzung: 12 von 15 Bahnen im Schlaglimit (e5, v3, v4 nicht). Echte Einsteiger-Bots (Können 0,35, wie für neue Spieler) in Arena 1: 4 von 5 (e5 nicht) – im Match gilt das als „nicht beendet“. Profi-Bots mit vielen Bahn-Trophäen nutzen die Schanze. Die Bot-Tests laufen mit festem Zufalls-Seed für die Abschlag-Streuung |
| Squash & Stretch, federnder Zug-Pfeil, Spin live in der Vorschau, Zielkreis | in CI geprüft (Logik); wie es sich anfühlt, nur auf dem Gerät beurteilbar |
| Top-Down-Kamera | in CI geprüft: Blick mindestens 35° nach unten, Ball im unteren Bildteil (Smoke-Test und echtes Hochformat 720 × 1280); Abschlag-Screenshots nutzen dieselbe Kamera-Pose. **Freie Sicht:** Kommt der Ball hinter einem Tor oder Ast zur Ruhe, sucht die Kamera einmal eine freie Neigung (Smoke-Test mit künstlicher Wand; Screenshot `game_follow`: Ball hinter dem Tor von e2 muss frei zu sehen sein, sonst schlägt der Lauf fehl). Baumkronen sind nur Optik und werden nicht erkannt; mitten auf den anderen 14 Bahnen nicht geprüft |
| Ziel-Kamera, Tiefenunschärfe, Feder-Kamera | in CI geprüft: beim Berühren des Balls fährt die Kamera heran (Abstand × 0,78, 52° statt 62°), Unschärfe nur beim Zielen, scharf bis hinter das Ende der Punkt-Kette, nach dem Schlag wieder aus; Feder ohne Überschwingen. Per Screenshot angesehen: Ball, Band und Punkte scharf, Hintergrund weich. **Voraussetzung:** Kantenglättung SMAA statt MSAA – mit MSAA verwischt Godot 4.5 im Mobile-Renderer das ganze Bild |
| Neon-Zug-Pfeil, Kraft am Ball, leuchtende Punkt-Kette, Kontaktschatten, flache Leiste | in CI geprüft (Pfeil gebaut und orange/rot, Griff bei voller Kraft im echten Hochformat im Bild und über dem Hinweis bei geradem Zug, bei ±40° im Bild und unter keinem Knopf, Kraft-Anzeige am Ball und ganz im Bild, kein Kraftbalken unten, keine Punkte auf dem Ball, Schatten unter dem Ball, Leiste ≤ 120 px mit Chips in einer Zeile, Verlauf dahinter, Knöpfe ≥ 48 px, Namen beim Zielen sofort aus); Aussehen per Screenshot |
| Vorschaubilder in Tasche, Shop und Pass | Bälle, Schläger und Trails als echte 3D-Vorschau, Rahmen als Avatar; **Loch-Explosionen** haben in der Liste weiter ein Symbol (Vorschau über den Augen-Knopf live in 3D) |
| Golfball-Dellen, Bäume, Ruinen, Rasen-, Wasser-, Flora-Shader | Shader kompilieren im CI-Rendering; Aussehen per Screenshot angesehen (Software-Rendering, nicht Handy-GPU) |
| SSAO, volumetrischer Nebel | **nicht vorhanden** – der Mobile-Renderer unterstützt beides nicht (nur Forward+); Ersatz: eingebackene Schatten, Kontaktschatten, Tiefen-/Höhennebel |
| Mehrfach-Einladung, Account-Knopf, `auth.save` | Oberfläche und Datei-Migration in CI geprüft; das Versenden gegen ein echtes Supabase-Projekt **nicht getestet** |
| Spiel auf einem echten Android-Gerät | **nicht getestet** (Performance, Touch-Gefühl, Safe-Areas bitte selbst prüfen). Besonders die Bildrate: weiche Schatten „Soft High“, SMAA, Tiefenunschärfe beim Zielen, mehr schattenwerfende Bäume und die neuen Shader kosten GPU-Zeit – das kann die CI nicht messen. Hinweis: Das Software-Rendering der CI-Screenshots dauert seit diesem Umbau ~17 statt ~7 Minuten |
| APK-Export + Artifact `GolfBattle3D-apk` | in CI gebaut (Entwicklungs-Branch) |
| GitHub-Release-Schritt | läuft nur auf `main` – **erst nach dem Merge geprüft** |

Bekannte Warnung: Jolt meldet in der CI gelegentlich „job system exceeded the maximum number of jobs“ (Godot-interne Meldung, bisher ohne erkennbare Auswirkung auf die Tests).

Bekannte Grenzen: Online-Matches sind „Client-autoritativ“ (jeder meldet seine eigenen Schläge) – für ein Spiel unter
Freunden okay, gegen Cheater nicht abgesichert. Es gibt keine Echtgeld-Käufe; Gems verdient man im Spiel.

## Hinweise

- **Name:** „Golf Battle“ ist der Name eines existierenden kommerziellen Spiels. Für eine Veröffentlichung im
  Play Store solltest du einen eigenen Namen wählen (`config/name` in `project.godot`, Paketname in `export_presets.cfg`).
- **Release-Build:** Die CI baut eine Debug-APK mit Debug-Keystore. Für den Play Store brauchst du einen eigenen
  Release-Keystore (als GitHub Secret) und ein AAB.
- **Lokal entwickeln:** Ordner in Godot 4.5 öffnen, `res://scenes/MainMenuView.tscn` ist die Startszene.
  Tests: `godot --headless --fixed-fps 60 res://tests/Smoke.tscn`.
