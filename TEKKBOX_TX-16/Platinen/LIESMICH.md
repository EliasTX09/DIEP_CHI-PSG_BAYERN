# TEKKBOX TX-16 – Platinen Rev 0.1

Erzeugt mit KiCad 10.0.6. Jede Datei `.kicad_pcb` öffnest du direkt im KiCad-PCB-Editor.

**Stand:** Alle Bauteile sind platziert, alle Verbindungen (Netze) festgelegt, Umriss, Beschriftung und eine GND-Fläche auf der Unterseite sind drin. Der Regelcheck (DRC) zeigt keine Kurzschlüsse und keine Abstandsfehler.
**Was noch fehlt:** die Leiterbahnen. In KiCad siehst du die Verbindungen als dünne „Gummiband“-Linien (Ratsnest). Wie du die ziehst, steht unten.

---

## M1 · Encoder-Spalte – 22,6 × 72 mm – 20 Stück
Zwei Drehregler (EC11) übereinander, Abstand 35 mm, jeder mit einem Ring aus 15 RGB-LEDs (WS2812B-2020).
- **ENC1/ENC2** EC11 mit Druckschalter, um −90° gedreht (Pins oben, Schalter-Pins unten in der Ring-Lücke)
- **SW1/SW2** Taster 6×6 als **Alternative** zum Encoder an derselben Stelle. Pro Position entweder Encoder **oder** Taster bestücken. Die DRC-Warnung „Überlappung“ dort ist gewollt.
- **U1** 74HC165 liest ENC1 A/B/Schalter + ENC2 A/B/Schalter, 2 Eingänge frei (auf 3,3 V)
- **U2** AP2112K-3.3 macht 3,3 V für das Schieberegister
- **R1–R6** 10 kΩ Pull-ups · **C1–C8** Entkopplung
- **J1 (links) Kette IN / J2 (rechts) Kette OUT**, JST-SH 6-polig:
  1 = +5 V · 2 = GND · 3 = SH/LD · 4 = CLK · 5 = Daten (J1: QH → Richtung Controller, J2: SER ← vom nächsten Modul) · 6 = LED-Daten (J1 rein, J2 raus)
- Auf Taster-Positionen leuchten die seitlichen Ring-LEDs die Tastenkappe aus.

## M2 · Tasten-Leiste – 92 × 22 mm – 14 Stück
Vier Taster im 23-mm-Raster, neben jedem eine RGB-LED unter der transparent gedruckten Kappe.
- **SW1–SW4** Taster 6×6 (7,3 mm hoch) · **D1–D4** WS2812B-2020
- **U1** 74HC165 (4 Eingänge frei) · **U2** AP2112K-3.3 · **R1–R4** 10 kΩ
- **J1/J2** wie bei M1, gleiche Kette

## M3 · Pad-Leiste – 112 × 42 mm – 4 Stück
Vier Pads im 28-mm-Raster. Pro Pad ein Drucksensor FSR 402 und zwei RGB-LEDs (WS2812B 5050) unter dem TPU-Pad.
- **FSR** wird mittig auf das Pad-Feld geklebt, das Fähnchen kommt in **J4–J7** (2-polig, 2,54 mm)
- **R1–R4** 10 kΩ nach GND = Spannungsteiler, 0–3,3 V je nach Druck
- **J1** Pads analog, JST-SH 6: 1 = +3,3 V · 2 = GND · 3–6 = Pad 1–4 → zum Controller (J3a–J3d)
- **J2** LED IN / **J3** LED OUT, JST-SH 3: 1 = +5 V · 2 = GND · 3 = Daten

## M4 · Controller – 100 × 85 mm – 1 Stück (selbst löten)
Das Gehirn der Bedienung, verbunden per USB mit dem Raspberry Pi 5.
- **U1** Raspberry Pi Pico 2 (gesockelt) · **D1** SS14 (5 V → VSYS)
- **U2** 74AHCT125: hebt die LED-Daten von 3,3 V auf 5 V, mit 33-Ω-Serienwiderständen (R1, R2)
- **U3** CD74HC4067: 16-fach-Umschalter für die 16 Pad-Sensoren → ADC des Pico
- **U4** 6N138 MIDI IN (R3 220 Ω, D2 1N4148, R4 470 Ω, R5 10 kΩ) · MIDI OUT + THRU nach 3,3-V-MIDI-Norm (R6–R9: 33 Ω / 10 Ω)
- **R10–R13** 4,7 kΩ I²C-Pull-ups · **C3** 470 µF Puffer

| Stecker | Typ | Belegung |
|---|---|---|
| J1 5V IN | JST-VH 2 | +5 V, GND (vom XL4015 für die Bedienung) |
| J9 MIDI | JST-PH 7 | IN Pin 4, IN Pin 5, OUT 4, OUT 5, THRU 4, THRU 5, GND → zu den DIN-Buchsen |
| J2 KETTE | JST-SH 6 | wie M1/M2 J1 (erstes Modul der Kette) |
| J3a–J3d | JST-SH 6 | Pads 1–4 / 5–8 / 9–12 / 13–16 (je ein M3) |
| J4 PAD-LED | JST-SH 3 | +5 V, GND, Daten → erstes M3 |
| J5 / J6 I²C A/B | JST-SH 4 (Qwiic) | GND, 3,3 V, SDA, SCL → OLED + Trill Square von MFX 1 bzw. 2 |
| J7 TM1637 | JST-SH 4 | GND, 3,3 V, CLK, DIO |
| J8 POTIS | JST-SH 4 | GND, 3,3 V, MASTER, PHONES |
| J10 RÖHRE | JST-SH 6 | +5 V, GND, SCK, MOSI, CS, RELAIS → Röhren-Platine M5 |

**Pico-Pins:** GP0 MIDI OUT · GP1 MIDI IN · GP2/GP3 TM1637 · GP4 MIDI THRU · GP5 Relais · GP6 LED-Kette · GP7 Pad-LEDs · GP8/9/20/21 Mux S0–S3 · GP10/11/22 Röhre SPI · GP12/13 I²C A · GP14/15 I²C B · GP16 Kette Daten · GP17 SH/LD · GP18 CLK · GP26 Mux · GP27 MASTER · GP28 PHONES · GP19 frei

---

## Kette (alles in einer Reihe)
Controller J2 → M1 → M1 → … (20×) → M2 → … (14×). Am letzten Modul bleibt J2 frei.
34 Schieberegister = 272 Eingänge, 34 Byte werden am Stück gelesen. Bei ca. 660 LEDs in der Kette schafft die Firmware über 50 Bilder pro Sekunde.

## Hinweise zum Frontplatten-Raster
Damit gleiche Module passen, liegen alle Encoder im Raster **23 mm (waagrecht) × 35 mm (senkrecht)** und alle Tasten im **23-mm-Raster**. Gegenüber dem 3D-Modell rücken dafür die Transport-, PART- und MENU-Tasten ein paar Millimeter.

---

## So machst du weiter
1. **Leiterbahnen ziehen:** KiCad → *Werkzeuge → Plugin and Content Manager* → **Freerouting** installieren. Platine öffnen → Freerouting starten → fertig. Danach *Prüfen → DRC*.
   Vorher in *Platineneinstellungen → Netzklassen* eine Klasse „Power“ (0,5 mm) für +5V und GND anlegen.
2. **Fertigungsdateien:** Plugin **Fabrication Toolkit** installieren → ein Klick erzeugt Gerber, Stückliste (BOM) und Bestückungsdatei (CPL) für JLCPCB.
3. **Bestellen:** Bei JLCPCB M1, M2, M3 mit „PCB Assembly“ (nur Oberseite) bestellen. Encoder, Taster, JST-Buchsen und Pin-Header lötest du selbst. M4 ohne Bestückung bestellen.
4. **M5 Röhren-Platine** folgt separat (Analogteil wird sorgfältig gerechnet).

Einige 3D-Modelle fehlen in der KiCad-Bibliothek (EC11, WS2812B-2020, JST-VH). Deshalb sieht man auf den Bildern dort nur die Lötflächen.
