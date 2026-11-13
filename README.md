# ⛳ Fairway Clash – Multiplayer-Minigolf (Android, Godot 4)

Kompetitives Arcade-Minigolf im Stil von *Golf Battle*: Drag-and-Release-Steuerung mit Flugbahn-Vorschau,
Echtzeit-Duelle, Freunde, Upgrades, Ghost-Läufe, Windböen, Boost-Pads, Windmühlen und Magnetfelder.

> Engine: **Godot 4.3** (GDScript, GL-Compatibility-Renderer) · Backend: **Supabase** (optional) · CI: **GitHub Actions**
> Der Code liegt in [`minigolf/`](minigolf). Die `index.html` im Repo-Root gehört nicht zum Spiel.

## Status – was funktioniert, was ist Gerüst?

| Bereich | Stand |
|---|---|
| Ball-Physik, Wände, Reibung, Einlochen, Flugbahn-Vorschau | geschrieben (eigene kinematische Physik) |
| Hazards: Wind/Böen, Boost, Windmühle, Magnet, Wasser | geschrieben |
| Quick-Deathmatch (3 Bahnen, Sudden-Death „Nearest to the Pin“) | geschrieben, State-Machine in `GameManager.gd` |
| Offline-Modus (Bots, lokaler Speicherstand, eigener Ghost) | geschrieben |
| Shop, Schläger-Upgrades, Trails, Loch-FX | geschrieben |
| Account (E-Mail, Gast, Gast→Account), Freunde, Einladungen, Ghosts (Supabase REST) | geschrieben, **nicht gegen ein Live-Projekt getestet** |
| Echtzeit-Multiplayer (Supabase Realtime Broadcast/Presence) | geschrieben, **Protokoll ungetestet** – isoliert in `NetworkManager.gd` |

Die GDScript-Dateien wurden mit einem Parser auf Syntax geprüft, aber **noch nicht in der Godot-Engine ausgeführt**.
Erwarte beim ersten Start Kleinigkeiten (Balancing, Layout, vereinzelte Laufzeitfehler). Ob der CI-Build durchläuft,
siehst du im *Actions*-Tab.

## Projektstruktur

```
.github/workflows/build_android.yml   # CI: exportiert die Debug-APK
backend/schema.sql                    # Supabase-Tabellen + Row-Level-Security
docs/BACKEND_SETUP.md                 # Schritt-für-Schritt Backend-Anbindung
minigolf/
├─ project.godot  export_presets.cfg  icon.svg
├─ config/backend.example.cfg         # Vorlage für Supabase-Zugangsdaten
├─ scenes/                            # Main.tscn, Game.tscn (Nodes werden im Code gebaut)
└─ scripts/
   ├─ core/      BackendConfig · SupabaseClient (Auth+REST) · NetworkManager (Realtime)
   │             GameManager (State-Machine) · Progression · Catalog · MatchRules · CourseData · GhostRecorder
   ├─ game/      Ball · Course · GameScene · AimController · RemoteBall · Cosmetics
   ├─ hazards/   Hazard · WindZone · BoostPad · Windmill · MagnetField · WaterHazard
   └─ ui/        Main (Router) · MainMenu · LoginScreen · ShopScreen · LobbyScreen · Hud · UIKit
```

## Spielprinzip
- **Steuerung:** Finger irgendwo aufsetzen, nach hinten ziehen (Länge = Kraft), loslassen. Die gestrichelte Linie zeigt die Bahn.
  Der **Spin-Slider** unten lässt den Ball kurven (Stärke je nach Schläger).
- **Match:** 3 Bahnen, alle spielen gleichzeitig (45 s pro Bahn; nicht eingelocht = Par + 3). Wenigstens Schläge nach 3 Bahnen gewinnt;
  bei Gleichstand entscheidet ein **Sudden-Death-Pin-Schuss** (wer am nächsten am Pin liegt).
- **Ghost-Challenge:** Du trittst gegen deinen besten Lauf und – eingeloggt – den besten Lauf deiner Freunde an.
- **Progression:** Coins für Platzierungen → Schläger kaufen/upgraden (Kraft, Führung = Windresistenz + Zielhilfe, Spin), Bälle, Trails, Loch-Effekte.

## Lokal einrichten
1. [Godot **4.3**](https://godotengine.org/download/archive/4.3-stable/) installieren (Standard-Version, kein .NET).
2. Repo klonen und das Projekt öffnen:
   ```bash
   git clone https://github.com/EliasTX09/DIEP_CHI-PSG_BAYERN.git
   cd DIEP_CHI-PSG_BAYERN
   # Godot -> Import -> minigolf/project.godot
   ```
3. **F5** startet das Spiel am Desktop (Maus = Touch). Ohne Backend läuft der Offline-Modus.
4. Backend (optional, für Accounts/Freunde/Multiplayer): [`docs/BACKEND_SETUP.md`](docs/BACKEND_SETUP.md).

## Auf ein Android-Gerät bringen

**A) Fertige APK aus GitHub Actions** (einfachster Weg)
1. Push nach GitHub → *Actions* → Workflow **Build Android APK** → Run öffnen → Artifact **FairwayClash-debug-apk** laden.
2. ZIP entpacken, `FairwayClash.apk` aufs Handy kopieren, „Installation aus unbekannten Quellen“ erlauben, installieren.
   Oder per USB: `adb install FairwayClash.apk`.
3. Für Releases: *Release veröffentlichen* → die APK wird automatisch angehängt.
4. Mit Backend: Secrets `SUPABASE_URL` und `SUPABASE_ANON_KEY` anlegen (siehe Backend-Doku).

**B) Direkt aus dem Godot-Editor**
1. *Editor → Editor Settings → Export → Android*: Android SDK Path, JDK Path, Debug-Keystore setzen
   ([offizielle Anleitung](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)).
2. *Project → Install Android Build Template* ist **nicht** nötig (kein Gradle-Build).
3. Handy per USB (USB-Debugging an) verbinden → Button **Remote Deploy** (Android-Symbol oben rechts) oder *Project → Export → Android → Export Project*.

> Der CI-Build ist eine **Debug-APK** (kein Secret nötig). Für den Play Store brauchst du eine Release-Signatur
> (`keystore/release*` in `export_presets.cfg`, Passwörter nur als Secrets / Env-Variablen).

## Architektur in Kürze
- **Ball.gd** – `Ball.step()` ist eine reine statische Funktion (Integration, Reibung, Spin, Kreis-Segment-Kollision in Substeps) und wird von
  Spiel *und* Vorschau genutzt. Einlochen nur unter `SINK_SPEED`, schnelle Bälle springen über das Loch.
- **GameManager.gd** – `IDLE → LOADING_MAP → SHOT_PHASE → HOLE_RESULT → … → [SUDDEN_DEATH] → MATCH_RESULT`; reine Regeln in `MatchRules.gd`.
- **Netzwerk** – jeder Client simuliert seinen eigenen Ball und sendet Schüsse + Position (10 Hz) per Realtime-Broadcast; Gegner werden interpoliert.
  Host = kleinste User-ID im Raum. Kein serverseitiges Anti-Cheat.
- **Neue Bahnen** – einfach einen Eintrag in `CourseData.gd` ergänzen (Polygon-Rand, Hindernisse, Tee, Loch, Hazards).

## Bekannte Grenzen / Nächste Schritte
- Coins/Upgrades werden vom Client vergeben (manipulierbar) → Kaufen/Belohnen über Supabase-RPC/Edge Function absichern.
- Realtime-Protokoll gegen ein echtes Projekt testen; ggf. auf private Channels umstellen.
- Eigene Grafik/Sound, mehr Bahnen, Matchmaking-Queue, Push-Einladungen, Rangliste.
- Der Name „Fairway Clash“ ist ein Platzhalter (`package/unique_name` in `export_presets.cfg` anpassen).
