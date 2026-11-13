# Golf Battle 3D – Architektur & interne Schnittstellen

Dieses Dokument beschreibt, wie die Skripte zusammenarbeiten. Es ist die Referenz für alle,
die am Projekt weiterbauen.

## Eckdaten
- **Engine:** Godot 4.5.x, Mobile-Renderer (Vulkan, fällt bei Bedarf auf OpenGL zurück), **Jolt-Physik**, 120 Physik-Ticks/s.
- **Format:** Querformat (`display/window/handheld/orientation=4` = Sensor Landscape), Basisauflösung 1280×720, Stretch `canvas_items` + `expand`.
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
MainMenu3D  --GameManager.start_match(config)-->  Game.tscn (Match3D)
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
- `MainMenu3D` – Hintergrund ist die echte Bahn „Tal der Mühlen“ plus schwebende Inseln, Windmühlen, Glitzer und
  brennende Golfbälle. Kamera fliegt auf einer geschlossenen `Curve3D`; Ball und Schläger hängen als Kind der Kamera
  im Vordergrund (Wischen dreht mit Schwung). UI: Profil, Coins/Gems, SPIELEN, Golden Shot, Lobby, 4 Truhen-Slots, Reiter.
- `MenuPages` – alle Seiten als modale Fenster (`open(page_id)`, `refresh()`): play, lobby, clubs, cosmetics, friends,
  leaderboard, shop, trophies, settings; dazu Truhen-Dialog, Belohnungsfenster und Rückfragen.

## Netzwerk
Jeder Client simuliert nur seine eigenen Bälle (der Host zusätzlich die Bots) und sendet Position/Schläge
per Supabase-Realtime-Broadcast; fremde Bälle werden interpoliert (`RemoteBall3D`).

## Tests
- `tests/SmokeTest.gd` – Headless-Test in der CI (Einstellungen, Kompilieren aller Skripte, Logik, Physik, Bots, Menüs).
- `tests/ShotRunner.gd` – rendert Szenen mit Software-Vulkan (kompiliert alle Shader) und legt Screenshots ab.
