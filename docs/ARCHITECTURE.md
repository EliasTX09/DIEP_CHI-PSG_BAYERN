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
         CameraManager3D, GameHUD, ShotSim (Vorschau + Bot-KI)
Ende:    GameManager.finish_match(summary) -> Belohnungen -> GameManager.goto_menu()
```

### Match-Konfiguration (`GameManager.match_config`)
```
{ mode: "quick"|"private"|"daily"|"practice", world, rounds, courses: [ids], seed, online: bool,
  fee: Einsatz der Arena (nur quick/private), stake: tatsaechlich eingezahlt (setzt GameManager.pay_stake beim Start),
  players: [ {id, name, kind: "local"|"bot"|"remote", color, ball, trail, explosion, frame, skill, trophies} ] }
```

## Physik-Modell des Balls (`Ball3D`, `RigidBody3D`)
- Kugel ohne Reibung (Reibung 0), Rollen ist rein visuell. Rollwiderstand, Luftwiderstand, Spin und alle
  Feld-Effekte werden in `_integrate_forces` berechnet – identisch zur Vorhersage in `ShotSim`.
- Abprallen: Boden 0,45 · Banden 0,75 (zwei getrennte StaticBodies: `floor_body`, `wall_body`).
- **Gadgets** (Boost, Wind, Sand, Rough, Bach, Teleporter, Looping-Schiene, Kanone, Laser, Kill-Zonen,
  Abkürzungs-Rampen-Markierung `RampTag`, Gelände-Grenze) sind analytische Volumen mit `affect(state, dt)`.
  Der echte Ball und die Simulation rufen dieselbe Funktion auf.
- **Aus (Out of Bounds):** `Gadgets.TerrainBounds` prüft gegen das Höhenfeld des Geländes: berührt der Ball den
  Randstreifen, einen Hang oder eine Schlucht neben der Bahn, ist er „aus“ (Strafschlag, zurück zur letzten Ruhelage).
  Wasser/Lava/Leere unten in den Schluchten lösen weiter über die Kill-Höhe aus.
- Loopings sind „Schienen“: Ist der Ball schnell genug, wird er entlang der Looping-Kurve geführt (energieerhaltend).
- Bewegliche Hindernisse (Windmühle, Hammer, Schiebeblock, Fähre) sind `AnimatableBody3D`, die nur von der Bahn-Uhr
  (`Course3D.time`) gesteuert werden. Jolt übernimmt neue Posen kinematischer Körper erst im nächsten Physik-Schritt,
  deshalb hat jede Bahn einen **Schatten-Physikraum** (`Course3D.shadow_state()`): statische Kopien aller
  Kollisionsformen, die `ShotSim` mit `timed: true` für jeden Simulationsschritt auf die zukünftige Stellung setzt.
  Die Bots planen damit einen Abschlag-Zeitpunkt und prüfen mehrere Zeitfenster (Hammer/Fähre abpassen).

## Bahn-Baukasten
- `TrackKit` – „Turtle“, die Querschnitte entlang eines Pfades extrudiert (Gerade, Rampe, Hügel, Steilkurve, Sprung,
  Looping, Grün mit Loch). Zeichnet dabei Belag-Proben auf (Grundlage fürs Gelände; Kanten ohne Bande markiert),
  Flug-Korridore unter Sprüngen, alle geraden Stücke und kann Banden-Öffnungen aussparen. Im `branch`-Modus baut er
  Nebenstränge (Abkürzungs-Steg), ohne Mittellinie, Stützen oder Bounds der Bahn zu verändern.
- `CourseBuilder3D` – definiert die 15 Bahnen + Daily-Parcours und liefert ein `Course3D`. Baut jede Bahn zweimal:
  ein Probelauf sucht Stellen für bis zu drei **Abkürzungs-Rampen** (`_plan_shortcuts`), der zweite Lauf baut sie.
  Eine Abkürzung = Banden-Öffnung in einem geraden Stück, schmaler Steg ohne Banden (5–9,5 m), Felsentor mit
  Kollision, am Ende eine echte Rampe (`TrackKit.kicker`, 4 m Bogen, 20/26/32° Absprung) und eine Schlucht unter dem
  Flug. Kein Boost, keine Landezone: Der Ball fliegt rein physikalisch geradeaus in Steg-Richtung weiter, also muss das
  Ziel (Grün oder ein späteres, beidseitig umbandetes Fairway-Stück) genau in dieser Richtung liegen. Der Planer
  berechnet das Landefenster entlang der Fluglinie, das nötige Absprung-Tempo (`takeoff_speed`, Wurfparabel + Aufschlag
  für Luftwiderstand) und rechnet es rückwärts über Rampe und Steg auf das Tempo am Tor zurück (`gate_speed`, gleicher
  Rollwiderstand wie `Ball3D`). Klassen: normal (Landemitte mit ≤ 28 m/s am Tor) und **Power** (schon der vordere
  Landerand braucht 31,5–37 m/s – mehr als der Startschläger mit ~31 m/s; `need_power` = nötige Schlagkraft direkt am
  Tor). Gewählt wird die beste normale, die beste Power-Rampe, dann weitere, jede an einem eigenen geraden Stück und
  mit Abstand zu den anderen. Power-Tore tragen rot glühende Bänder, Schrift gibt es keine. `Gadgets.RampTag` an der
  Rampenkante verändert den Ball nicht, sondern meldet nur „launch“ (Style-Punkte, Statistik, Bot-Planung). Ohne
  Abkürzung: e1 (gerade Einsteiger-Bahn) und der Golden Shot. Hindernisse auf der Bahn: Bach mit Holzsteg (`Gadgets.Creek`), Rough (`Gadgets.RoughZone`),
  Baumstämme und Felsbrocken (`Obstacles.log_obstacle/boulder`), Lianen-Bögen (Deko).
  **Natur am Bahnrand** (`CourseBuilder3D._edge_nature`, nach dem Gelände, immer gebaut, Seed nur aus der Bahn-ID →
  in jedem Match und im Test identisch): entlang aller ebenen Querschnitte der Hauptbahn mit Bande stehen Randbäume (`Obstacles.edge_tree`), mindestens 40 % davon mit einem dicken Ast quer
  über die Bahn (Kollision: Stamm-Zylinder + zwei Ast-Kapseln, Unterkante 2,55 m über dem Belag → rollende Bälle passen
  drunter durch, hohe Schläge prallen ab), dazu Wurzeln (`Obstacles.root_obstacle`, flache Kapsel, ragt 0,6–0,95 m in
  die Bahn) und Randfelsen. Frei bleiben Abschlag, Grün, Abkürzung (Öffnung, Tor, Flug), Flug-Korridore, Gadgets und
  Hindernisse. Laub, Lianen (`Motion.swinger`), Grasbüschel und lose Steine sind reine Optik. Neon-Welt und Golden
  Shot haben keine Rand-Natur, Par-4-Bahnen nur Bäume (keine Wurzeln/Felsen auf der Bahn). Der Smoke-Test prüft Quote,
  Höhe (Ball-Kugel passt drunter durch), Kollision der Äste und dass unter jeder Astspitze Bahnbelag liegt.
- `Course3D` – Tee-Transform, Loch-Position, Par, Mittellinie (`path_points`), Gadgets, Kill-Höhe, Kollisions-Körper,
  Belag-Proben, Flug-Korridore, Gelände (`terrain`) und Abkürzungen (`shortcuts`, `shortcut` = die erste).
- `Terrain3D` – Höhenfeld (2,5-m-Raster, 80 m Rand) um die Bahn: Abstandsfeld zur Bahn (Chamfer), flacher Randstreifen
  knapp unter dem Belag, Böschungen, Felsterrassen (Klippen), Bergrücken, Schluchten unter Korridoren und Stücken ohne
  Bande, Küstenseite (Piratenbucht). Hängt nur von der Bahn-Geometrie und einem festen Seed ab (für alle Spieler gleich).
  Der Smoke-Test prüft, dass es auf allen 16 Bahnen überall unter dem Belag liegt.
- `WorldTheme` – Materialien, Himmel, Sonne mit weichen Schatten (Filter „Soft High“, überblendete Kaskaden),
  Tiefen- und Talnebel, Bloom; kleidet die Bahn ein: Gelände-Mesh (`landscape.gdshader`: Rough, Wiese mit Farbverlauf,
  Fels an Steilhängen, Schnee, Ufer), Bergkranz, Wald, Felsen mit Moos, bemooste Säulenhallen-Ruinen, Grasbüschel und
  Steine am Rand, Wasserfall-Kaskade bzw. Lavastrom, Neon-Hochhäuser, Piratenschiff in der Bucht. Kameras (Spiel,
  Menü, Screenshots) bleiben über dem Gelände.
- `Flora` – alle Natur-Modelle als ein Mesh mit Vertex-Farben (MultiMesh-tauglich): Laubbaum = dicker Stamm mit
  Wurzelansatz + Äste + 3–5 klumpige, überlappende Kronen-Ellipsoide (Farbverlauf unten→oben, eingebackener
  Kronen-Schatten), Tanne = 4–5 gestapelte Nadel-Klumpen, Palme, toter Baum, Wurzel, Grasbüschel, Säule, Block,
  Architrav, Randbaum mit Ast, Liane; je Baumart 2–3 Varianten und eine sparsame Fern-Version. Shader `flora.gdshader`:
  Vertex-Farbe a = Materialart (Laub/Rinde/Stein), Rinden-Furchen, Blatt-Klumpen und Stein-Körnung als Bump-Map
  ohne Tangenten, Wind (Wiegen + Flattern), Durchscheinen des Laubs, Moos auf Stein-Oberseiten.
- **Renderer-Grenzen:** Der Mobile-Renderer unterstützt laut Godot-Doku **kein SSAO und keinen volumetrischen Nebel**
  (nur Forward+). Ersatz: eingebackener Kronen-Schatten (Flora), Kontaktschatten an den Banden (`grass_fairway`,
  UV2 aus `TrackKit`) und unter den Bällen (`contact_shadow`), Dellen-AO im Ball-Shader, Tiefen- und Höhennebel des
  Environments. Tiefenunschärfe dagegen gibt es im Mobile-Renderer (nur beim Zielen eingeschaltet).
- **Rasen** (`grass_fairway.gdshader`): Schachbrett aus dunkel- und hellgrünen Feldern (Länge `stripe_length`, Breite
  `checker_width`, Kanten mit `fwidth` auf genau ein Pixel geglättet, in der Ferne zum Mittelwert ausgeblendet),
  Sättigung nach Körnung und Flecken angehoben (`saturation`, Vulkan zurückhaltender), leichter Halm-Glanz je nach
  Blickrichtung, glattere helle Felder spiegeln den Himmel (an streifenden Winkeln gedämpft, damit es nicht milchig
  wird), Halm-Körnung als Bump-Map, Putt-Ringe ums Loch.

## Hauptmenü
- `MainMenuView` (`scenes/MainMenuView.tscn`, `scripts/ui/MainMenu.gd`) – Hochformat, einhändig bedienbar:
  - Hintergrund ist die echte 3D-Bahn der gewählten Arena (je Welt eine, `BACKDROPS`), Kamera fliegt auf einer
    geschlossenen `Curve3D` (Ellipse knapp außerhalb der Bahn, über dem Gelände); dazu Glitzer/Glut und brennende Golfbälle. Arena-Wechsel per Pfeil
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

## Ball-Optik
- `BallFX.make_ball`: Kugel mit 64 Segmenten / 32 Ringen. Standard- und Gold-Ball nutzen `golfball_dimples.gdshader`
  (≈330 Dellen aus einem fast regelmäßigen Punktgitter auf der Kugel als prozedurale Normalen, Dellen-AO,
  Klarlack-Schicht, Detail blendet mit der Entfernung aus).
- `Ball3D._update_visual`: Squash & Stretch als gedämpfte Feder (Abschlag streckt in Flugrichtung, Aufprall staucht
  entlang der Normale) und Rollen der Optik; nur das Mesh wird verformt, die Kollisionskugel nie.
- Harter Aufprall (> 5,5 m/s) → Signal `impacted` → `BallFX.impact_dust` (Staubwolke) + kurzes Kamerawackeln beim
  eigenen Ball.
- Kontaktschatten (`BallFX.make_contact_shadow` / `place_contact_shadow`, Shader `contact_shadow.gdshader`): weicher
  dunkler Fleck direkt unter jedem Ball (auch Online-Gegner), per Strahl auf den Boden gelegt, mit der Flughöhe
  größer und blasser, aus bei Aus/Respawn/eingelocht.

## Zielen
- Am Ball ziehen = Zug-Pfeil: ein dünner Neon-Pfeil spannt sich vom Ball **nach hinten** Richtung Finger
  (Griff 0,95–1,7 m hinter der Ballmitte), die Spitze sitzt knapp hinter der Kugel und zeigt in Schussrichtung
  (`ARROW_HEAD_AT_BALL`, umschaltbar). Länge und Farbe zeigen die Kraft. Loslassen schießt in die Gegenrichtung.
  Der Pfeil ist **ein** `ImmediateMesh`-Streifen entlang einer Bezier-Kurve (`Match3D._build_band`, jedes Bild neu):
  Spitze (Breite 0 → 0,46 m), Schulter, Schaft (0,17 → 0,09 m). UV.x = seitlicher Abstand in Metern (an der Spitze
  sauber interpoliert), UV2 = halbe Breite und Abstand zur Spitze. Shader `aim_band.gdshader`: leuchtender
  Neon-Kern (Gold → Orange → Rot, `GameHUD.power_color`), heiße helle Mittellinie, scharfer weißer Rand auch an den
  Schultern, Energie-Pulse laufen zur Spitze. Der Griff hängt an einer gedämpften Feder (`Match3D._update_band`): er
  schwingt nach, der Schaft biegt sich mit, wird gespannt schmaler und locker breiter, beim Loslassen schnellt er
  zurück.
- Kraft in Prozent: kleine Pille (`GameHUD._power_chip`, Blitz + Zahl, Rand in der Pfeil-Farbe) schräg über dem Ball
  (`Ball3D.indicator_anchor`), auf der Seite, auf der weder Pfeil noch Punkt-Kette liegen; `Match3D._place_power_chip`
  setzt sie jedes Bild (die Kamera fährt beim Zielen), `GameHUD.place_power` hält sie ganz im Bild. Fängt keine
  Berührung ab. Einen Kraftbalken am unteren Rand gibt es nicht mehr. Ändert sich Spin oder Schlagart während des Zielens, wird die Vorschau sofort neu
  gerechnet.
- Nach vorn eine **Punkt-Kette** aus der echten Simulation (`ShotSim`, inkl. Banden, Rampen, Gadgets), Shader
  `aim_marker.gdshader` (Form aus den UVs, Kanten mit `fwidth` geglättet, leicht über 1.0 für feinen Bloom):
  Rollen und Aufsetzen als weiß-gelbe Punkte am Boden, der Flugabschnitt als Punkte **genau auf dem Flugbogen**
  (Billboards in einem MultiMesh) plus dunkle Schatten-Punkte senkrecht darunter. Am Ende ein dezent pulsierender
  Zielkreis. Die Länge der Kette kommt vom **Guide**-Wert des Schlägers, die Größe des Landerings von der
  **Accuracy** (mögliche Streuung). Endet der Schlag im Aus, wird die Kette rot.
- Kamera beim Zielen (`CameraManager3D.set_aiming`, gesetzt beim Berühren des Balls, wie das Ausblenden aller
  Namensschilder): Abstand × 0,78 und Blickwinkel 62° → 52°, Blickpunkt rückt näher an den Ball (der Pfeil bleibt
  bei geradem Zug im Bild und über dem Hinweis – im Screenshot-Lauf gemessen, auch ±40° liegen im Bild und unter
  keinem Knopf), weich überblendet; die Kamera dreht sich dabei nie seitlich (sonst würde die Zielrichtung
  unter dem Finger wandern). Dazu Tiefenunschärfe (`CameraAttributesPractical`,
  nur Fern-Unschärfe, im Mobile-Renderer unterstützt): scharf bis zum weitesten Punkt der Vorschau + 3,5 m, dahinter
  verschwimmt die Umgebung. Außerhalb des Zielens und in der Vogelperspektive ist die Unschärfe aus.
  Kantenglättung deshalb per **SMAA statt MSAA**: Mit MSAA rendert der Mobile-Renderer (Godot 4.5) in einen eigenen
  Mehrfach-Tiefenpuffer und reicht der Unschärfe nur einen leeren Tiefenpuffer weiter – sie verwischte das ganze Bild.
- Standard-Blick (`CameraManager3D.DEFAULT_PITCH` 0,95 rad ≈ 54°, `DEFAULT_DISTANCE` 10 m, `default_pose`): steil von
  oben hinter dem Ball, Blickpunkt `LOOK_AHEAD` × Abstand vor dem Ball → der Ball steht bei rund zwei Dritteln der
  Bildhöhe, das Schachbrett füllt das Bild, kein Horizont. Die Kamera-Position hängt nur von Ball, Neigung und
  Abstand ab (Folge-Test und Schussrichtung bleiben gleich), verschoben wird nur der Blickpunkt. Der Spieler kann
  per Wischen weiter neigen. Abschlag-Screenshots bauen ihre Kamera mit `default_pose`.
- Kamera-Führung: kritisch gedämpfte Federn (`CameraManager3D.spring_step`, feste 1/120-s-Schritte) für Blickpunkt,
  Kameraposition und Blickziel – weicher Start beim Schuss, sauberer Nachlauf, kein Nachschwingen; bei ruhendem Ball
  straffer, damit Drehen mit dem Finger direkt reagiert. Keine Kollisions-Verkürzung entlang des Arms (die Äste über
  der Bahn würden die Kamera springen lassen; hinter einem Tor landete sie im Tor).
- Freie Sicht auf den ruhenden Ball (`CameraManager3D._update_view_check`, `view_free`, `clear_pitch`): Der steile
  Blick sah auf e2 nach dem Durchrollen über den Torbogen hinweg – der Ball lag dahinter verdeckt. Deshalb prüft die
  Kamera **einmal pro Ruhephase** (Ball schussbereit, 0,3 s Ruhe, nicht beim Zielen, nicht direkt nach dem Drehen)
  mit zwei Strahlen (Ballmitte, Oberkante; Ebenen Welt/Hindernisse/Plattformen, Bälle zählen nicht), ob der Ball
  aus dem aktuellen Blick zu sehen ist. Wenn nicht, sucht sie die nächste freie Neigung in 0,07-rad-Schritten
  (zuerst steiler, dann flacher, 0,25–1,38 rad) und gleitet als eigener Zusatz (`_view_offset`) dorthin; `pitch`
  des Spielers bleibt unverändert, rollt der Ball wieder, geht es zurück zum Standard-Blick. Greift der Spieler die
  Kamera, übernimmt er den gerade sichtbaren Winkel. Baumkronen sind reine Optik und werden nicht erkannt.

## Trophäen, Arenen, adaptive Bots
- Gesamt-Trophäen (Ligen, Cloud-Profil) bleiben eine Zahl. `GameManager.split_course_trophies` teilt das Match-Delta
  nach der Platzierung auf jeder gespielten Bahn auf (`summary.course_ranks` aus `Match3D._end_hole`); die Aufteilung
  eines Matches summiert exakt zum Delta. Gespeichert in `course_trophies` im Spielstand (kein neues SQL-Feld); jede
  Bahn bleibt ≥ 0 und bestehende Spielstände starten dort bei 0, daher ist die Summe aller Bahn-Trophäen nicht
  zwingend gleich der Gesamtzahl.
- Arenen öffnen ab `Catalog.WORLDS[].unlock` (0 / 150 / 400 / 800) – gemessen an `best_trophies`, damit sich nichts
  wieder sperrt und bestehende Spielstände nichts verlieren. Gesperrt ist nur das Starten (Bots, Schnellspiel, eigene
  Lobby); Einladungen in Lobbys anderer bleiben möglich. Die Welttour bei vielen Runden läuft offline nur durch offene
  Arenen.
- Keine Bot-Auswahl mehr: `GameManager.auto_bot_count()` = 4 (jedes Match hat `Catalog.MAX_PLAYERS` = 5 Spieler).
  `SmartBotController` ist eine dünne Steuerschicht über `BotBrain`: Bahn-Trophäen des Spielers → Können-Bonus (bis
  +0,15 ab 100) und Wahrscheinlichkeit, mit der ein Bot pro Schlag eine Abkürzung in Betracht zieht (0 unter 6, 1 ab 50
  Bahn-Trophäen). Erlaubt: zusätzliche Kandidaten geradeaus auf die Kante jeder Rampe vor dem Ball (4 Kräfte); nicht
  erlaubt: `BotBrain._score` wertet jede Vorhersage mit Rampen-Absprung (`ShotSim.result.launched`) wie einen
  Fehlschlag. Bedenkzeit 0,3–1,2 s; alle rechnenden Bots teilen sich ein Budget von 4 ms pro Bild (`Match3D`
  reicht den Rest weiter, wenn einer fertig ist).

## Einsatz, Auszahlung, Lochende
- Jede Arena hat einen Einsatz (`Catalog.WORLDS[].fee`: 100 / 250 / 500 / 1000). `GameManager.make_match_config`
  setzt `fee` für „quick“ und „private“, `start_match` → `pay_stake` zieht ihn genau einmal ab (wer online nach einem
  Arena-Wechsel zu wenig hat, zahlt, was er hat; `stake` = tatsächlich eingezahlt). Die Menüs starten nur, wenn das Geld
  reicht (`can_pay_fee`).
- `finish_match`: Auszahlung `Catalog.payout_for_rank(rank, stake)` = Einsatz × 2 / 1,5 / 1,25 / 1 / 0 (plus Ball-Bonus
  „+x % Coins“), Trophäen `Catalog.RANK_TROPHIES` = +9 / +5 / +3 / 0 / −3 – im Modus „private“ (Freunde-Lobby) keine.
  Style-Punkte geben Pass-XP, aber keine Match-Coins mehr.
- Freunde-Lobby: `NetworkManager.common_worlds()` = Arenen, die alle im Raum offen haben (Presence trägt `best`, die
  beste Trophäenzahl); der Host kann nur diese wählen, beim Beitritt eines Spielers ohne die Arena wechselt er
  automatisch auf die höchste gemeinsame. Freie Plätze füllen immer Bots auf 5.
- Lochende (`Match3D`): Alle Bälle starten auf demselben Abschlag-Punkt (Bälle kollidieren nicht miteinander). Locht
  der Erste ein (`_on_holed_first`, auch für Online-Gegner), sinkt die Restzeit auf `FOLLOW_UP_TIME` = 20 s. Wer bis
  zum Bahn-Ende nicht eingelocht hat, bekommt `_missed_strokes` = Schläge des schlechtesten Eingelochten + 2 (nie
  weniger als die eigenen); hat niemand eingelocht, gilt weiter Par + 3. Online sendet „done“ zusätzlich die
  tatsächlich gespielten Schläge („r“), damit jeder Client gleich rechnet.

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
- Session-Speicher: nur das Refresh-Token (nie E-Mail oder Passwort), in `user://auth.save`, verschlüsselt mit einem
  geräte­bezogenen Schlüssel (Verschleierung). Alte `session.json` wird übernommen und gelöscht, ein altes `auth.json`
  wird umbenannt; eine unlesbare Datei gilt als „keine Session“.
- Startbildschirm: Knopf „Account verknüpfen / Anmelden“ (nur ohne verknüpften Web-Account) öffnet das Portal im
  Browser und die Profil-Seite mit dem Feld für den Spiel-Code.
- Lobby: Freunde ankreuzen und mit einem Knopf alle gleichzeitig einladen (bzw. „Alle online“), begrenzt auf freie Plätze.
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
