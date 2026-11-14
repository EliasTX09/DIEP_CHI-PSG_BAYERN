# ⛳ Golf Battle 3D – Arcade-Multiplayer-Minigolf für Android (Godot 4)

Echtes 3D-Arcade-Minigolf: 15 Bahnen in 4 Welten, eingebettet in Täler mit Bergen, Klippen, Wäldern und Schluchten,
riskante Abkürzungen, Loopings, Kanonen, Teleporter, Hämmer, Bäche, Lava und Wasser,
bis zu 6 Spieler gleichzeitig, Bots für den Offline-Modus, Schlägertasche mit Upgrades, Truhen, Ligen
und ein täglicher „Golden Shot“. **Alles** – Bahnen, Modelle, Effekte, Shader und Sounds – wird per Code erzeugt.
Es gibt keine `.glb`-, `.fbx`- oder `.wav`-Dateien im Projekt.

> Engine: **Godot 4.5** (GDScript, Mobile-Renderer, Jolt Physics) · Backend: **Supabase** (optional) ·
> Build: **GitHub Actions** → `GolfBattle3D.apk`
> Hochformat (einhändig) · Web-Portal für Accounts in [`webapp/`](webapp) (GitHub Pages)
> Die `index.html` im Repo-Root gehört nicht zum Spiel.

> **Umbau-Stand:** Hochformat-Hauptmenü (Arena-Auswahl mit 3D-Hintergrund, Tab-Leiste Spielen · Tasche · Pass ·
> Freunde · Shop), Hochformat-HUD, kostenloser Battle Pass (28-Tage-Saisons, 30 Stufen), Bahnen in Berg-Tälern
> statt im offenen Wasser, eine riskante Abkürzung pro Bahn, Hindernisse auf der Bahn (Bach, Rough, Baumstämme,
> Felsen) und die neue Ziel-Vorschau (Gummiband + Punkt-Kette) sind fertig.
> Noch offen: Flyover-Vorschau, Trophäen pro Bahn, adaptive Bots, Clans.

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
     Für schnelle Tests kannst du „Confirm email“ ausschalten.
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
1. Im Spiel: **Profil → „Account verknüpfen / Registrieren“** öffnet das Portal im Browser.
2. Dort registrieren bzw. einloggen, Profilbild hochladen, Freunde verwalten.
3. **„Spiel-Code erzeugen“** (Passwort bestätigen) → 8-stelliger Code, 10 Minuten und nur einmal gültig.
4. Code im Spiel unter **Profil → Spiel-Code → Einlösen** eingeben. Das Spiel erhält dabei eine **eigene** Anmeldung
   (die Browser-Sitzung wird nie weitergegeben) und speichert sie verschleiert in `user://auth.json`.
5. Hatte das Spiel schon Fortschritt als Gast und der Web-Account ebenfalls, wird der Stand des Accounts geladen
   und der Gast-Stand als Sicherung (`user://save_backup_*.json`) abgelegt – es geht nichts still verloren.
   Ist der Web-Account neu, übernimmt er den Gast-Fortschritt.

Ein Direkt-Sprung vom Browser zurück ins Spiel (Deep-Link) ist **nicht** eingebaut – dafür bräuchte die APK
einen eigenen Android-Build mit Intent-Filter. Der Code wird deshalb abgetippt.

---

## Steuerung

| Geste | Wirkung |
|---|---|
| Am Ball ziehen und loslassen | Schlag: nach hinten ziehen wie ein Gummiband (das Band spannt sich hinter dem Ball zum Finger), loslassen schießt nach vorn. Vorn zeigt eine Punkt-Kette auf dem Boden, wo der Ball aufkommt, abprallt und ausrollt (echte Simulation). Länge der Kette = Guide-Wert des Schlägers, Größe des Landerings = Accuracy |
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
- **Abkürzungen:** Auf jeder Bahn außer der geraden Einsteiger-Bahn e1 (und dem Golden Shot) gibt es eine Öffnung in
  der Bande: ein schmaler Steg ohne Banden führt über eine Schlucht durch ein Felsentor zu einem Sprungpad, das den
  Ball mit Schwung aufs Grün (bzw. ein späteres Fairway-Stück) schießt. Vom Steg gerollt = Schlucht = Aus, zu
  langsam = der Ball bleibt auf dem Steg; wer seitlich versetzt oder mit falschem Tempo aufs Pad kommt, landet versetzt.
- **Hindernisse:** Bäche quer über die Bahn mit schmalem Holzsteg, tiefes Rough am Rand, Baumstämme und Felsbrocken,
  Lianen-Bögen, Sandbunker.
- **Bahn-Baukasten:** Rampen, Steilkurven, Spiralen, Loopings, Brücken, Lücken, Boost-Pads, Windzonen, Teleporter,
  Kanonen, Laser-Tore, Sandbunker, Windmühlen, Pendel-Hämmer, Schiebeblöcke, fahrende Plattformen.
- **Multiplayer:** Gast-Login per Geräte-ID, Verknüpfen mit E-Mail/Passwort, Spielername, Avatar-Farbe und -Rahmen,
  bis zu 6 Spieler gleichzeitig (alle schlagen parallel), Live-Rangliste, Emotes, Freunde (Suche per Name oder
  Freundes-Code, Anfragen, Online-Status), private Lobby mit 4-stelligem Raum-Code oder Einladung, Welt und 3/5/9 Runden.
- **Progression:** 16 Schläger (4 Kategorien × 4 Seltenheiten, Werte Power/Accuracy/Spin/Guide, Upgrades mit Coins + Karten),
  6 Bälle mit kleinen Boni, 6 Trails, 5 Loch-Explosionen mit Screen-Shake und Bass, 4 Truhen-Slots mit Timern
  (oder sofort per Gems), Trophäen, 5 Ligen und Trophäen-Pfad.
- **Extras:** Style-Punkte („Air Time!“, „Bank Shot!“, „Close Call!“, Hole-in-One) mit Bonus-Coins,
  Golden Shot (ein Schlag pro Tag, Belohnung nach Abstand zur Fahne), Replay des besten Schlags in Zeitlupe.
- **Sound:** prozeduraler Synthesizer (`AudioStreamGenerator`) – Abschlag je nach Kraft, Abpraller auf Holz/Stein/Metall,
  Wind bei hohen Sprüngen, Wasser-/Lava-Platscher, Loch-Sound + Fanfare, UI-Klicks, Truhen-Jingle.

## Projektstruktur

```
project.godot                     Godot 4.5, Mobile-Renderer, Jolt Physics, Hochformat (720 x 1280), MSAA, Schatten
export_presets.cfg                Android-Export (arm64, INTERNET, ACCESS_NETWORK_STATE, VIBRATE)
supabase_schema.sql               Tabellen, RLS-Policies, Trigger, Spiel-Code-Funktionen, Storage-Bucket "avatars"
config/backend.cfg                Supabase-URL + anon-Key + Web-Portal-Adresse (Platzhalter = Offline-Modus)
.github/workflows/build_android.yml   Tests + APK + Schema-Test + Portal-Browsertest
.github/workflows/pages.yml           Web-Portal auf GitHub Pages veröffentlichen (manuell)
webapp/                           Web-Portal: index.html, app.js, style.css, config.js
scenes/                           MainMenuView.tscn, Game.tscn, GameHUD.tscn
shaders/                          17 eigene Shader (Gelände, Gras/Grün, Sand, Wasser, Lava, Himmel, Neon, Portal, Ball-Skins …)
scripts/autoload/                 GameManager (Speicherstand, Wirtschaft, Truhen, Ligen),
                                  AuthManager (Login, Session, Web-Code), ProfileManager (Profilbild),
                                  NetworkManager (Profil-Sync, Freunde, Lobbys, Realtime), SoundManager (Synthesizer)
scripts/data/Catalog.gd           Alle Spieldaten (Schläger, Bälle, Truhen, Ligen, Welten)
scripts/gameplay/                 Ball3D, CameraRig3D, CourseBuilder3D (inkl. Abkürzungs-Planung), TrackKit, Terrain3D (Gelände),
                                  WorldTheme (Landschaft, Licht), Gadgets, Obstacles, ShotSim (Vorhersage), BotBrain (KI),
                                  Match3D (Spielablauf)
scripts/fx/                       Materialien, Partikel, Flora (Bäume, Felsen), Ball-Skins, Explosionen, Schlägermodelle, Emoji-Icons
scripts/ui/                       MainMenu (MainMenuView), MenuPages, Preview3D, GameHUD, UIKit, UIIcon, UIAvatar
tests/                            Smoke-Test, Schein-Supabase-Server, Screenshot-Runner, Physik-Fingerabdruck,
                                  SQL-Tests, web/portal_test.js (Browser-Test)
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
| Supabase-Login, Freunde, Lobbys, Realtime, Portal gegen ein **echtes** Supabase-Projekt | **nicht getestet** |
| Hochformat-HUD | in CI geprüft (Layout oben/unten, Daumenzone) |
| Gelände-Tal | in CI geprüft: liegt auf allen 16 Bahnen überall unter dem Belag, Schluchten unter allen Sprüngen/Flügen, Aus-Grenze greift neben der Bahn; Bau ~40 ms pro Bahn |
| Abkürzungen | in CI geprüft auf allen 14 Bahnen: Vorhersage landet auf dem Grün, seitlich vom Steg = Aus, zu langsam = bleibt auf dem Steg; echter Ball auf e2, v3, n3, p1 landet wie vorhergesagt (≤ 0,1 m Abweichung). Die Ersparnis wird gemessen (11–101 m Weg), nicht pauschal „2 Schläge“ |
| Hindernisse (Bach, Rough, Stamm, Fels) | in CI geprüft (Wirkung + Bots locht weiter auf allen 15 Bahnen ein) |
| Spiel auf einem echten Android-Gerät | **nicht getestet** (Performance, Touch-Gefühl, Safe-Areas bitte selbst prüfen) |
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
