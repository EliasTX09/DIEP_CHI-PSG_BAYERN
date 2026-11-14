class_name SmartBotController
extends RefCounted
## Adaptive Bots: duenne Steuer-Schicht ueber BotBrain (die Physik-KI selbst bleibt unveraendert).
## BotBrain plant jeden Schlag mit der echten Flugbahn-Simulation (ShotSim gegen die Jolt-Kollision);
## dieser Controller legt nur fest, WIE gut der Bot das umsetzt und ob er Abkuerzungen nutzt:
## - Grundkoennen kommt aus der Gesamt-Trophaeenzahl (GameManager.make_bot_entry).
## - Je mehr Trophaeen der Spieler auf der aktuellen Bahn hat, desto praeziser zielen die Bots dort
##   und desto oefter wagen sie die riskante Abkuerzung (Schanze durchs Felsentor).
## Neue Spieler treffen also auf Bots, die den langen Weg gehen; Profis auf ihrer Lieblingsbahn auf Bots,
## die jede Abkuerzung kennen.

## Ab so vielen Bahn-Trophaeen beginnen Bots, die Abkuerzung zu nutzen
const SHORTCUT_FROM := 20
## Ab so vielen Bahn-Trophaeen nutzen sie sie bei jeder passenden Gelegenheit
const SHORTCUT_FULL := 160
## Maximaler Koennens-Bonus durch Bahn-Trophaeen
const SKILL_BONUS := 0.15

## Wahrscheinlichkeit pro Schlag, dass ein Bot die Abkuerzung in Betracht zieht.
static func shortcut_chance(course_trophies: int) -> float:
	return clampf(float(course_trophies - SHORTCUT_FROM) / float(SHORTCUT_FULL - SHORTCUT_FROM), 0.0, 1.0)

## Koennens-Bonus fuer diese Bahn (0 .. SKILL_BONUS).
static func skill_bonus(course_trophies: int) -> float:
	return SKILL_BONUS * clampf(float(course_trophies) / 300.0, 0.0, 1.0)

## Stellt einen Bot auf die Bahn-Trophaeen des Spielers ein.
static func configure(brain: BotBrain, course_trophies: int) -> void:
	if brain == null:
		return
	brain.skill = clampf(brain.skill + skill_bonus(course_trophies), 0.05, 0.97)
	brain.shortcut_chance = shortcut_chance(course_trophies)

## Kurzbeschreibung fuer die Oberflaeche ("Bots hier: ...").
static func describe(course_trophies: int) -> String:
	var c: float = shortcut_chance(course_trophies)
	if c <= 0.0:
		return "Bots nehmen hier den langen Weg"
	if c >= 1.0:
		return "Bots kennen hier jede Abkürzung"
	return "Bots wagen hier manchmal die Abkürzung"
