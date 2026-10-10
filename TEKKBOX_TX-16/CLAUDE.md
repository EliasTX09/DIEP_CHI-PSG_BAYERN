# TEKKBOX TX-16 – Projektstand für Claude Code

Diese Datei wird beim Start von Claude Code in diesem Ordner automatisch gelesen. Sie enthält alles, um nahtlos weiterzumachen,
als wäre es derselbe Chat. Der vollständige lesbare Verlauf liegt in `docs/Chatverlauf.md` (bei Fragen zu früheren Entscheidungen dort nachschlagen).

Stand: **Rev 2.0** der spielbaren App (Layout nach dem Plan `Notes_261010` vom 2026-10-10, Panel 60 × 42 cm). Letzte Änderung 2026-10-10: Layout-Feinschliff nach dem Plan (siehe Abschnitt 9).

---

## 1. Der Nutzer und wie die Zusammenarbeit läuft

- Schreibt locker auf Deutsch (Jugendsprache, Tippfehler normal). **Antworten auf Deutsch, einfache Sprache, kurz.**
- **Will Tempo:** direkt umsetzen, kurze Statusmeldungen zwischendurch, keine langen Pläne oder Rückfragen bei klaren Aufträgen.
  Hat mehrfach unterbrochen, wenn zu viel erklärt wurde („bisschen schneller bitte“).
- Hat Elektronik-/Löterfahrung und Werkzeug („ist nicht mein erstes Projekt“): Teilelisten nur Hauptteile mit Teilenummer, keine Anfänger-Tipps.
- Hardtekk-Fan. Freunde: **Paulotekk** (bekannt in der Szene, iOHM) und **Bischtekk**; ein „Kumpel“ gibt oft Klang-Feedback.
- Schickt Feedback meist als **Liste mit Spiegelstrichen** (oft eingefügt) und manchmal Bildschirmvideos (Spectacle nimmt KEINEN Ton auf –
  für Ton: OBS mit stummem Mikro oder `pw-record -P '{ stream.capture.sink=true }' ~/tx16.wav`) oder exportierte Pattern-JSONs.
- Testet die App lokal in **Chromium** (`chromium TX-16_Live.html`). **Firefox ist egal** (dort gibt es einen Pegel-Bug, bewusst nicht verfolgt).
- Vorbild ist die **Korg Electribe 2 (blau)**: Bedienlogik, Menüs, Begriffe wie dort. Referenz: `docs/Korg_electribe_Parameter_Guide.pdf`.
  Gleichzeitig soll es **nicht nach Korg klingen** (eigener Charakter: Röhre, TX CHARACTER, Analog Drift, Hardtekk-Brett).
- Ehrlich bleiben: Claude kann nicht hören, nur messen. Bei Klangfragen messen (siehe Abschnitt 6) und sagen, was gemessen statt gehört wurde.

## 2. Das Projekt

**TEKKBOX TX-16**: eigene Hardtekk-Groovebox, Fusion aus Korg Electribe Sampler 2 und EMX, mit echten Röhren (ECC82).
16 Sequencer-Parts + 8 Live-Pads, 8 Takte, Sample oder Oszillator pro Part, Filter, Modulation, 5 Insert-FX pro Part, Master-FX-Touchpad,
7-Zoll-Touch-Display, Panel 52 × 36 cm. Ziel: echtes Gerät bauen (Raspberry Pi + Platinen) – die Browser-App ist der spielbare Prototyp.

## 3. Ordner und Dateien

| Pfad | Inhalt |
|---|---|
| `TX-16_Live.html` | **Die spielbare App** (eine Datei, im Browser öffnen). Wird aus `src/` gebaut. |
| `src/a.html` | Seite, CSS, Hilfetext, alle Listen (Samples, OSCs, Filter, MODS, FXLIB=IFX, MFXL=MFX, Skalen, Grooves, Gate-Arp …), Bedienfeld-Layout (`kd()` = Regler, `bd()` = Taste, Koordinaten in cm) |
| `src/b.js` | Zustand (`G` global, `ui`, `cur` = aktuelles Pattern), Pattern-Format + Migrationen, Audio-Engine (Web Audio), Effekte `makeFX`, Oszillatoren, Filter, Stimmen `voice()` |
| `src/c.js` | Sequencer (`doStep`, `schedule`), Roll, MIDI, Bedienlogik (`act`, `func`, `padPress`), Regler↔Parameter, Undo, **Menü `MENU`** |
| `src/d.js` | Pixel-Display (`SCR.*`), OLED, Touchpad-Grafik, Aufbau der Oberfläche, Maus/Touch/Tastatur, Touch-Display, Import/Export, Einschalten, Anzeige-Loop |
| `tools/build.py` | `python3 tools/build.py` baut die App (`--backup` sichert die alte nach `versionen/`), `--test` baut `tools/test.html` mit Test-Hook |
| `tools/serve.py` | lokaler Server `http://127.0.0.1:8765/` für Browser-Tests |
| `tools/testkit.js` | Test-Helfer (Tasten drücken, Regler drehen, Pads, Import, Audio aufnehmen) |
| `versionen/` | alte App-Stände (nicht in der Übergabe-ZIP, entsteht neu durch `build.py --backup`) |
| `patterns/` | vom Nutzer exportierte Patterns (JSON) |
| `docs/Chatverlauf.md` | kompletter lesbarer Chat seit 2026-10-04 |
| `docs/Plan_Notes_261010.pdf` | handgezeichneter Layout-Plan des Nutzers (Rev 2.0) |
| `docs/Korg_electribe_Parameter_Guide.pdf` | offizielle Korg-Referenz (Menüs, 72 Mod-Typen, Skalen, Grooves, IFX/MFX-Listen) |
| `TEKKBOX_TX-16.html` | 3D-Modell (noch **Rev 0.4**-Layout) |
| `Bauplan_TX-16.html` | Bauplan (Hardware-Konzept) |
| `Platinen/` | KiCad-Platinen M1–M4 (Encoder-Spalte, Tasten-Leiste, Pad-Leiste, Controller), `erzeugen.py`, `LIESMICH.md` |
| `Teileliste_TX-16_final.csv` | Teileliste (Hauptteile) |

**Arbeitsweise:** nur in `src/` ändern, dann `python3 tools/build.py --backup`. Nie die gebaute HTML von Hand editieren.
Nach jeder Änderung testen (Abschnitt 6), dann App bauen und das Artifact aktualisieren (Abschnitt 7).

## 4. Aufbau der App (das Wichtigste für Änderungen)

- **Pattern-Format** (`patternToObj`/`patternFromObj` in b.js): JSON mit `tx16:'1.1'`, `parts[24]`, Arrays `steps/notes/vel/gate/rat`
  (16 × 128), `motion`, plus `PATKEYS` (bpm, key, scale, last, level, beat, swing, chordSet, gateArp, alt2122, alt2324, chainTo, chainRep,
  mfx, rollType, mutes, xn, name, glue). Ältere Versionen werden beim Laden **migriert** (`ver<…`-Blöcke) – bei Formatänderungen
  immer eine Migration ergänzen und `tx16` hochzählen.
- **WICHTIG: neue IFX/MFX/Listeneinträge immer ANS ENDE hängen.** Gespeicherte Patterns speichern Indizes; Einfügen in der Mitte
  verschiebt Nummern (ist einmal passiert, Migration `ver<1.1`: IFX ≥97 +11, MFX ≥24 +3).
- Parts: 0–15 sequenziert (Pads 1–16), 16–23 Live-Pads (17–24). `NSEQ=16`. Part-Felder siehe `newPart()` in b.js.
- Signalweg pro Part: Stimme (Sample/OSC → Filter → Amp-EG) → IFX 1–5 → EQ+Drive → Low Cut → Level → Sidechain → Röhre (2 Stufen, DC-Filter)
  → Pan → Wege: MFX-Send / trocken, jeweils mit oder ohne **Roll-Send** (Looper vor dem MFX) oder **BASS GLUE** (Part-Vorstufe GLUE DRIVE →
  gemeinsamer Glue-Bus: HP, Drive, asym. Sättigung, DC, −3 dB 260 Hz, Biss 2,2 kHz, LP, Kompressor, Auto-Pegel) → MFX 1(+2) → Summe →
  Pattern Level → **TX CHARACTER** (OFF/TUBE/TAPE/HARDTEKK, pegelausgeglichen) → Limiter → Master.
- Oversampelte WaveShaper verzögern 128/192 Samples (`SHL`, kalibriert) – parallele trockene Wege brauchen dieselbe Verzögerung
  (`shDelay`), sonst Kammfilter („Bass schwingt lauter/leiser“).
- Asymmetrische Sättigung braucht danach einen DC-Filter (sonst Wummern im Tiefbass).
- Filter-Resonanz im Tiefbass: `RING` begrenzt die Ausschwingzeit, Grenze folgt dem Filter-EG. FILTER TRACK (SHIFT + FILTER TYPE)
  legt die Resonanz auf den Grundton des Samples.
- Modulation: alle 72 Korg-Typen = 12 Quellen × 6 Ziele (`MOD_SRC`, `MOD_DST`, `modInfo`). LFOs pro Part, EGs pro Ton, IFX-Ziel mit Steuerrate.
- Touchpad wie E2: MASTER FX / GATE ARP (X = Tempo, Y = Länge, gehaltene Pads) / TOUCH SCALE. Gate-Arp-Muster und Chord-Sets sind
  **eigene Inhalte** (die Korg-Listen stehen nicht im Guide).
- Undo/Redo: 60 Schritte, schnelle Änderungen werden gebündelt (`dirty()`/`pushUndo()` in c.js). **SHIFT + <PAGE = UNDO, SHIFT + PAGE> = REDO**
  (keine extra Taste – Nutzerwunsch). Die UNDO-Funktionstaste in der Pad-Reihe gibt es noch (Nutzer gefragt, ob sie weg soll – offen).

## 5. Festgelegte Entscheidungen (nicht wieder ändern ohne Auftrag)

- Look: modern/dunkel im Korg/Elektron-Stil (frühere Kritik: „DDR-Radio“-Look).
- Panel 52 × 36 cm, Regler 27 mm Raster. 7"-Touch-Display oben links mit Softkeys HOME/SOUND/IFX/MFX/MENU.
- Menütasten: oben `<PAGE` `PAGE>` nebeneinander, darunter MENU/ENTER, EXIT/SHIFT. VALUE blättert, ENTER = Ändern. PATTERN-Rad unter VALUE.
- Links: Transport (PLAY/STOP/REC), darunter MASTER FX · ROLL (FX TYPE, ROLL TYPE, MASTER FX / GATE ARP / TOUCH SCALE, HOLD, ROLL), unten das MFX-Touchpad.
- Pads: links 8 × 2 (Parts/Steps 1–16), Lücke, rechts 4 × 2 (Pads 17–24: Takte im Sequencer, Live-Samples im Trigger-Modus).
  Funktionsreihe: TRIGGER, SEQUENCER, KEYBOARD, CHORD, MUTE, ERASE, COPY, UNDO, FILL, DROP, OCT −, OCT +.
- Alle Part-Regler = Endlos-Encoder mit LED-Ring (kein Zeiger); nur MASTER/PHONES echte Potis. VALUE, PATTERN, FX/IFX TYPE ohne Ring.
- Sound-Bereich: SAMPLE, OSC (getrennt, der zuletzt gedrehte spielt), PITCH, OSC EDIT (bei Samples = PUNCH); SMP EDIT, STEP EDIT, REVERSE, STRETCH.
- Röhre pro Part: DRIVE A/B (2 Trioden), TUBE MIX, TUBE ON. MIX: SIDECHAIN, MFX SEND, ROLL SEND, BASS GLUE, GLUE DRIVE (pro Part).
- Einmal-Einstellungen gehören ins Menü (weniger Regler = Platz/Geld). Menü-Struktur wie Electribe 2.
- Bedienung: MUTE halten + Pad = Solo, TRIGGER halten + Pad = nur auswählen, Sequencer bleibt beim Spielen auf der gewählten Bar,
  FILL mit Quell-/Ziel-Bars, COPY über Patterns, REC + Ton = Sofortstart, SHIFT + TAP = Metronom, KEYBOARD: OCT −/+ = ±4 Oktaven.
- Alle Listen zeigen Nummern groß vorne (Nutzer will wissen, auf welcher Nummer er ist).
- Pads ohne Velocity (außer TRG.PAD VELOCITY im Menü).

### Layout Rev 2.0 (Plan vom 2026-10-10, gilt vor älteren Angaben oben)

- Display oben links, darunter PARAMETRIC EQ (LOW MID HIGH · FREQ MIX · BW), FILTER, AMP EG (ADSR, SHIFT = Pegel).
- Mitte: VALUE/PATTERN + Menütasten, darunter SYNTH OSCILLATOR (blauer EMX-Block), rechts daneben **SAMPLE · PITCH** (Plan), darüber ADD-ON SLOT.
- Rechts oben: TUBE · OUTPUT (T.MIX, A, B, MASTER, PHONES, T.ON), Röhrenhaube mit 3 Röhren, MODULATION, AMP (MONO/POLY, LEVEL, PAN).
- MIX: SIDECHAIN, GLUE DRIVE, BASS GLUE / MFX SEND / ROLL SEND, darunter **OKT. SEND** (Plan). INSERT FX: TYPE, EDIT, −/+, 1–5.
- Unten links: TAP, REC/STOP/PLAY, ROLL + SHIFT, TEMP. LOCK, SOLO. Touchpad mit GATE ARP / T.SCALE / MFX / HOLD.
- Pads: Funktionsreihe <P P> MUTE ERASE TRIGGER SEQU. KEYB. CHORD STEP JUMP. Rechts ◁ ▷ (Bars, blaue LEDs), rote LEDs = Oktave des Parts,
  **OKT − / OKT +** über dem rechten Pad-Block (= Oktave des aktuellen Parts, KEYB./CHORD = Tastatur, SOLO/OKT. SEND halten = deren Parts, SHIFT = Halbton).
- Zwischen allen Reglern mind. 1,5 cm (Kappe zu Kappe) – nach jeder Layoutänderung nachprüfen.

## 6. Testen (Claude kann nicht hören – messen!)

1. `python3 tools/build.py --test` und `python3 tools/serve.py` (Hintergrund).
2. Im Browser `http://127.0.0.1:8765/tools/test.html` öffnen, dann per JavaScript:
   `eval(await (await fetch('/tools/testkit.js')).text()); await T.power();` – danach `T.press('PLAY/PAUSE')`, `T.turn('CUTOFF',5)`,
   `T.pad(1)`, `await T.shift(()=>T.press('PAGE zurück'))`, `T.importObj(json)`, `T.capture(2, ()=>T.press('PLAY/PAUSE'))` …
   Zugriff auf Interna über `window.__tx` (cur, E, ctx, ui, MENU …).
3. Fehler sammeln: `window.addEventListener('error', …)` vor dem Test. Bewährt: Rundumtest = alle Tasten 2×, alle Regler ±, alle Pads,
   alle Menüpunkte (adj + enter, außer Dateidialoge/Factory Reset), Touch-Display.
4. Klang messen: Pegel/RMS/Peak, Limiter-Reduktion (`E.limiter.reduction`), Frequenzbänder per FFT, Hüllkurven, Obertöne.
   Aufnahme mit AudioWorklet (ScriptProcessor verliert Blöcke).
5. Aria-Labels der Tasten: `<PAGE` = „PAGE zurück“, `PAGE>` = „PAGE weiter“, `<PART` = „PART zurück“ usw.

## 7. Artifacts (claude.ai, privat, gleicher Account)

- **TX-16 Live (spielbare App):** https://claude.ai/artifact/VPXdu5jC8WU6Ye8SMwcZPk – aktuell Version 15 (Rev 1.1).
  Aktualisieren: Artifact-Tool `publish` mit `url` = dieser Link und `file_path` = `TX-16_Live.html` (vorher einmal `read`, falls nötig).
  Im Artifact funktionieren Export/Downloads nicht (Viewer erlaubt keine Downloads) – der Nutzer testet die lokale Datei.
- 3D-Modell: https://claude.ai/artifact/QEiLRkM4d8VyLGoke3czWs (noch Rev 0.4-Layout!)
- Bauplan: https://claude.ai/artifact/KsUA43BwuLHrNQPiX6EAaG

## 8. Offene Punkte / nächste Schritte

- Nutzer-Feedback abwarten zu: neue Distortion, TX CHARACTER + ANALOG DRIFT („klingt nach Korg“ – Kumpel fragen, was genau),
  BASS GLUE mit seinem Pattern (Kick 1, Bass 2, „Baselinetone“ 10).
- UNDO-Funktionstaste in der Pad-Reihe: behalten oder Platz freimachen? (gefragt, keine Antwort)
- **3D-Modell** auf das aktuelle Layout bringen (seit Rev 0.4 nicht nachgezogen).
- **Platinen + Teileliste** nachziehen: 27-mm-Raster, Endlos-Encoder mit LED-Ring, Pad-Taster, Röhre pro Part (realistisch: 4 Röhrenkanäle
  mit je ECC82, Parts dynamisch zugeteilt, Drive per Digitalpoti, Mix digital), DAC8x, Touch-Display 7".
- Hardware-Idee Röhren-Kalibrierung (Auto-Kalibrierung, Röhren tauschbar) wurde besprochen (siehe Chatverlauf).

## 9. Versionsgeschichte (Kurzfassung, Details im Chatverlauf)

- **Rev 0.4–0.6:** Grundgerät, 24 Pads, 7"-Display, 109 IFX/42 MFX, EQ+Drive, BASS GLUE-Taste, FILL.
- **Rev 0.7:** 8+4-Pad-Layout, Live-Pads 17–24, LOOP EVERY, Bass-Kammfilter-Bug (WaveShaper-Latenz) gefixt, CUT ITSELF, FILTER TRACK.
- **Rev 0.8:** MUTE-Solo, TRIGGER-Auswahl, FILL-Auswahl, Encoder mit LED-Ring, Röhre pro Pad, EG INT wie Korg.
- **Rev 0.9:** Electribe-2-Menüs, eigener OSC-Regler (88 OSCs), 36 Filter, Voice Assign, Pattern-Wechsel lädt alles, COPY über Patterns.
- **Rev 1.0:** Korg Parameter Guide als Referenz: 72 Mods, 35 Skalen, 25 Grooves, Touchpad 3 Modi, CLEAR SEQUENCE, Global/Data Utility,
  Export Audio (WAV), BASS GLUE seriell, Distortion-Effekte, Import speichert ins Pattern.
- **Rev 1.0.1:** Glue-Bus wie Hardtekk-Brett mit Auto-Pegel, DC-Filter, Effekt-Nummern-Migration.
- **Rev 1.1:** GLUE DRIVE pro Part, ROLL SEND pro Part + Triolen-Roll-Fix, PAGE-Tasten nebeneinander, Keyboard ±4 Oktaven,
  Undo/Redo 60 Schritte (SHIFT + PAGE), REC-Sofortstart, 12 Metronom-Klänge mit Vorhören, TX CHARACTER, ANALOG DRIFT,
  neue Distortion, +13 IFX / +20 MFX (Electribe-2-Liste ergänzt).
- **Rev 2.0:** Layout nach dem handgezeichneten Plan (60 × 42 cm, EMX-Oszillator-Block, 3 Röhren, SOLO, TEMP. LOCK, OKT. SEND, BW, EQ-Presets,
  Menü bleibt bis EXIT, Welle beim Anschlagen). Feinschliff 2026-10-10: OKT −/+ über den rechten Pads ergänzt, OKT. SEND in den MIX-Block,
  SAMPLE · PITCH neben den Oszillator, ◁ ▷ nur noch Bars, ADD-ON SLOT im Raster.
