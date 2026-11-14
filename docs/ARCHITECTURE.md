# Golf Battle 3D – Architektur & interne Schnittstellen

Dieses Dokument beschreibt, wie die Skripte zusammenarbeiten. Es ist die Referenz für alle,
die am Projekt weiterbauen.

## Eckdaten
- **Engine:** Godot 4.5.x, Mobile-Renderer (Vulkan, fällt bei Bedarf auf OpenGL zurück), **Jolt-Physik**, 120 Physik-Ticks/s.
- **Format:** Hochformat (`display/window/handheld/orientation=5` = Sensor Portrait), Basisauflösung 720×1280, Stretch `canvas_items` + `expand` (hohe Handys bekommen mehr Höhe, z.B. 720×1600).
- **Alles prozedural:** Meshes, Shader, Partikel und Sounds entstehen per Code – es gibt keine importierten Modelle/Audiodateien.
- **Einheiten:** Meter. Ball-Radius 0,30 m · Bahnbreite 5 m · Lochradius 0,75 m · Schwerkraft 20 m/s².
- **Kollisions-Layer:** 1 = Welt (statisch), 2 = Bälle, 3 = bewegliche Hindernisse. Bälle kollidieren nicht miteinander.

## Autoloads
| Name | Datei | Aufgabe |
|---|---|---|
| `GameManager` | `scripts/autoload/GameManager.gd` | Speicherstand, Coins/Gems, Trophäen/Ligen, Truhen, Schläger, Inventar, Daily, Match-Start/-Belohnung |
| `NetworkManager` | `scripts/autoload/NetworkManager.gd` | Supabase Auth/REST, Realtime-Lobby, Freunde, Rangliste, Bot-Fallback |
| `SoundManager` | `scripts/autoload/SoundManager.gd` | Prozeduraler Synthesizer (`AudioStreamGenerator`) |

`GameManager` kennt `NetworkManager` nicht – der Netzwerk-Teil lauscht auf `GameManager.save_changed`.

## Daten
`scripts/data/Catalog.gd` (`class_name Catalog`, nur statische Daten/Funktionen): Schläger (4 Kategorien × 4 Seltenheiten),
Bälle, Trails, Loch-Explosionen, Avatar-Rahmen, Truhen, Ligen, Trophäen-Pfad, Welten/Bahnlisten, Emotes, Style-Punkte.

## Spielablauf
```
MainMenuView  --GameManager.start_match(config)-->  Game.tscn (Match3D)
Match3D: pro Bahn  CourseBuilder3D.build(id) -> Course3D
         Ball3D je Spieler (lokal + Bots), RemoteBall3D für Online-Gegner
         CameraRig3D, GameHUD, ShotSim (Vorschau + Bot-KI)
Ende:    GameManager.finish_match(summary) -> Belohnungen -> GameManager.goto_menu()
```

### Match-Konfiguration (`GameManager.match_config`)
```
{ mode: "quick"|"private"|"daily"|"practice", world, rounds, courses: [ids], seed, online: bool,
  players: [ {id, name, kind: "local"|"bot"|"remote", color, ball, trail, explosion, frame, skill, trophies} ] }
```

## Physik-Modell des Balls (`Ball3D`, `RigidBody3D`)
- Kugel ohne Reibung (Reibung 0), Rollen ist rein visuell. Rollwiderstand, Luftwiderstand, Spin und alle
  Feld-Effekte werden in `_integrate_forces` berechnet – identisch zur Vorhersage in `ShotSim`.
- Abprallen: Boden 0,45 · Banden 0,75 (zwei getrennte StaticBodies: `floor_body`, `wall_body`).
- **Gadgets** (Boost, Wind, Sand, Teleporter, Looping-Schiene, Kanone, Laser, Kill-Zonen) sind analytische Volumen
  mit `affect(state, dt)`. Der echte Ball und die Simulation rufen dieselbe Funktion auf.
- Loopings sind „Schienen“: Ist der Ball schnell genug, wird er entlang der Looping-Kurve geführt (energieerhaltend).
- Bewegliche Hindernisse (Windmühle, Hammer, Schiebeblock, Fähre) sind `AnimatableBody3D`, die nur von der Bahn-Uhr
  (`Course3D.time`) gesteuert werden. Jolt übernimmt neue Posen kinematischer Körper erst im nächsten Physik-Schritt,
  deshalb hat jede Bahn einen **Schatten-Physikraum** (`Course3D.shadow_state()`): statische Kopien aller
  Kollisionsformen, die `ShotSim` mit `timed: true` für jeden Simulationsschritt auf die zukünftige Stellung setzt.
  Die Bots planen damit einen Abschlag-Zeitpunkt und prüfen mehrere Zeitfenster (Hammer/Fähre abpassen).

## Bahn-Baukasten
- `TrackKit` – „Turtle“, die Querschnitte entlang eines Pfades extrudiert (Gerade, Rampe, Hügel, Steilkurve, Sprung, Looping, Grün mit Loch).
- `CourseBuilder3D` – definiert die 15 Bahnen + Daily-Parcours und liefert ein `Course3D`.
- `Course3D` – Tee-Transform, Loch-Position, Par, Mittellinie (`path_points`), Gadgets, Kill-Höhe, Kollisions-Körper.

## Hauptmenü
- `MainMenuView` (`scenes/MainMenuView.tscn`, `scripts/ui/MainMenu.gd`) – Hochformat, einhändig bedienbar:
  - Hintergrund ist die echte 3D-Bahn der gewählten Arena (je Welt eine, `BACKDROPS`), Kamera fliegt auf einer
    geschlossenen `Curve3D`; dazu schwebende Inseln, Glitzer/Glut und brennende Golfbälle. Arena-Wechsel per Pfeil
    oder Wischen baut den Hintergrund mit kurzer Abblende neu.
  - Kopfleiste: Profilbild (Web-Account) / Name / Trophäen → Profil, Trophäen-Knopf, Coins, Gems, Einstellungen.
  - Startseite (VBox): Arena-Banner, freier Platz für die Vitrine (Ball + Schläger als Kind der Kamera; Position und
    Größe werden aus dem freien Platz berechnet – passt auf jedes Seitenverhältnis), Modus-Zeile, Golden Shot /
    SPIELEN / Lobby, 4 Truhen-Slots. Alle Bedienelemente liegen in der unteren Hälfte.
  - Tab-Leiste: Spielen · Tasche · Pass · Freunde · Shop, mit Abzeichen (Anfragen, abholbare Pass-Stufen, Geschenk).
- `MenuPages` – Tab-Seiten im Inhaltsbereich (clubs/cosmetics, pass, friends/leaderboard, shop) und Overlays
  (play, lobby, settings, trophies) über `open(page_id)`; dazu Schläger-Detail mit drehbarer 3D-Vorschau,
  Truhen-Dialog, Belohnungsfenster und Rückfragen. `page`/`modal` zeigen immer die oberste Seite.
- `Preview3D` – kleine 3D-Vorschau in einem eigenen `SubViewport` (eigene Welt): Bälle und Schläger als einmal
  gerenderte Bilder, Trails und das Schläger-Detail live.

## Battle Pass
- Kostenlos, Saisons zu 28 Tagen ab 05.01.2026 (`Catalog.pass_season_at`), 30 Stufen à 150 XP (`Catalog.PASS_TIERS`).
- XP: Match 40 + Platz (40/25/15/5) + Style/10 (max. 30) + 20 je Hole-in-One, Training 15, Golden Shot 30
  (`GameManager.finish_match` / `finish_daily` → `grant({"pass_xp": …})`).
- Speicherstand `pass = {season, xp, claimed}`. Saisonwechsel schreibt erreichte, nicht abgeholte Stufen gut
  (Truhen als Coins), danach beginnt die Saison bei 0 XP. Doppelte Gegenstände werden zu 300 Coins.

## Anmeldung (AuthManager, ProfileManager, Web-Portal)
- `AuthManager` ist der einzige Besitzer von `user_id`, Access-/Refresh-Token und E-Mail und führt alle
  Supabase-HTTP-Aufrufe aus (`request()`, erneuert die Session bei 401 einmal). `NetworkManager` liest diese Werte
  nur über Getter. Signale: `auth_changed`, `status_changed`, `account_changing` (vor einem Wechsel → Lobby verlassen).
- Session-Speicher: nur das Refresh-Token, in `user://auth.json`, verschlüsselt mit einem geräte­bezogenen Schlüssel
  (Verschleierung). Alte `session.json` wird übernommen und gelöscht; eine unlesbare Datei gilt als „keine Session“.
- Web-Code-Ablauf: Portal → eigener Passwort-Login nur für das Spiel → `create_game_link_code(refresh_token)` →
  Code (8 Zeichen, 10 min, einmalig) → Spiel `redeem_game_link_code(code)` (als anon) → Refresh-Token →
  `grant_type=refresh_token` → eigene Spiel-Session. Die Tabelle `game_link_codes` hat RLS ohne Policies.
- Spielstand beim Account-Wechsel: `GameManager.adopt_account_save(account, remote)` – Server leer → Upload;
  gleicher Account → neuere Revision gewinnt; anderer Account mit Stand → laden, lokalen Fortschritt vorher sichern.
- `ProfileManager` lädt das Profilbild nur über `<supabase-url>/storage/v1/object/public/avatars/<uid>/avatar-<n>.<ext>`
  (Pfad per Regex und DB-Constraint geprüft, max. 512 KB, PNG/JPEG/WebP nach Magic-Bytes) und cacht es lokal.

## Netzwerk
Jeder Client simuliert nur seine eigenen Bälle (der Host zusätzlich die Bots) und sendet Position/Schläge
per Supabase-Realtime-Broadcast; fremde Bälle werden interpoliert (`RemoteBall3D`).

## Tests
- `tests/SmokeTest.gd` – Headless-Test in der CI (Einstellungen, Kompilieren aller Skripte, Logik, Physik, Bots, Menüs).
- `tests/ShotRunner.gd` – rendert Szenen mit Software-Vulkan (kompiliert alle Shader) und legt Screenshots ab.
