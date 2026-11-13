class_name Catalog
extends RefCounted
## Statischer Item-Katalog: Schlaeger (Upgrades), Baelle, Trails, Loch-Effekte.

const CLUBS := {
	"rookie":  {"name": "Anfaenger-Putter", "power": 1.00, "guidance": 0.00, "spin": 0.20, "price": 0,   "up_cost": 40},
	"striker": {"name": "Striker",          "power": 1.10, "guidance": 0.15, "spin": 0.35, "price": 300, "up_cost": 80},
	"curver":  {"name": "Curver",           "power": 1.00, "guidance": 0.10, "spin": 0.80, "price": 450, "up_cost": 90},
	"titan":   {"name": "Titan",            "power": 1.30, "guidance": 0.30, "spin": 0.40, "price": 900, "up_cost": 150},
}
const MAX_LEVEL := 5
const LEVEL_BONUS := 0.06   # +6 % pro Level auf jeden Stat

const BALLS := {
	"white":  {"name": "Weiss",  "color": Color.WHITE,  "price": 0,   "bounce": 0.00},
	"orange": {"name": "Orange", "color": Color(1.0, 0.6, 0.1), "price": 150, "bounce": 0.02},
	"cyan":   {"name": "Cyan",   "color": Color(0.2, 0.9, 1.0), "price": 250, "bounce": 0.04},
	"pink":   {"name": "Pink",   "color": Color(1.0, 0.4, 0.8), "price": 400, "bounce": 0.06},
}

const TRAILS := {
	"none":    {"name": "Kein Trail", "price": 0,   "colors": []},
	"fire":    {"name": "Feuer",      "price": 350, "colors": [Color(1, 0.9, 0.2), Color(1, 0.3, 0.0), Color(0.4, 0, 0, 0)]},
	"ice":     {"name": "Eis",        "price": 350, "colors": [Color(0.8, 1, 1), Color(0.3, 0.6, 1), Color(0, 0.2, 0.6, 0)]},
	"rainbow": {"name": "Regenbogen", "price": 700, "colors": [Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN, Color(0.5, 0.2, 1, 0)]},
}

const HOLE_FX := {
	"confetti": {"name": "Konfetti", "price": 0,   "colors": [Color.RED, Color.YELLOW, Color.GREEN, Color.CYAN]},
	"stars":    {"name": "Sterne",   "price": 400, "colors": [Color(1, 0.95, 0.4), Color.WHITE]},
	"firework": {"name": "Feuerwerk","price": 800, "colors": [Color(1, 0.3, 0.2), Color(1, 0.8, 0.2), Color(0.5, 0.3, 1)]},
}

## Effektive Schlaeger-Stats inkl. Upgrade-Level (0..MAX_LEVEL).
static func club_stats(id: String, level: int) -> Dictionary:
	var c: Dictionary = CLUBS.get(id, CLUBS["rookie"])
	var m: float = 1.0 + LEVEL_BONUS * clampi(level, 0, MAX_LEVEL)
	return {
		"power": float(c["power"]) * m,
		"guidance": minf(float(c["guidance"]) * m + 0.02 * level, 0.9),
		"spin": float(c["spin"]) * m,
	}

static func upgrade_cost(id: String, level: int) -> int:
	return int(CLUBS[id]["up_cost"]) * (level + 1)

static func table(kind: String) -> Dictionary:
	match kind:
		"club": return CLUBS
		"ball": return BALLS
		"trail": return TRAILS
		"fx": return HOLE_FX
	return {}
