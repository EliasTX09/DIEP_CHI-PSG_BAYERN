class_name Catalog
extends RefCounted
## Statische Spieldaten: Schlaeger, Baelle, Trails, Loch-Explosionen, Truhen, Ligen,
## Trophaeen-Pfad, Welten, Emotes. Reine Daten + kleine Rechenhelfer (keine Nodes).

# ---------------------------------------------------------------- Seltenheiten
const RARITIES: Array[String] = ["common", "rare", "epic", "legendary"]
const RARITY_NAMES := {"common": "Gewöhnlich", "rare": "Selten", "epic": "Episch", "legendary": "Legendär"}
const RARITY_COLORS := {
	"common": Color(0.62, 0.7, 0.8),
	"rare": Color(0.25, 0.6, 1.0),
	"epic": Color(0.75, 0.35, 1.0),
	"legendary": Color(1.0, 0.75, 0.15),
}
const RARITY_BONUS := {"common": 0, "rare": 8, "epic": 16, "legendary": 24}
const RARITY_MAX_LEVEL := {"common": 12, "rare": 10, "epic": 8, "legendary": 6}
const RARITY_COIN_MULT := {"common": 1.0, "rare": 1.5, "epic": 2.5, "legendary": 4.0}
const RARITY_CARD_MULT := {"common": 1.0, "rare": 0.6, "epic": 0.3, "legendary": 0.12}

# ---------------------------------------------------------------- Schlaeger
const CATEGORIES: Array[String] = ["allround", "driver", "iron", "wedge"]
const CATEGORY_NAMES := {
	"allround": "Allrounder",
	"driver": "Power-Driver",
	"iron": "Präzisions-Eisen",
	"wedge": "Trickshot-Wedge",
}
const CATEGORY_HINTS := {
	"allround": "Ausgewogen in allen Werten.",
	"driver": "Maximale Schlagkraft, dafür mehr Streuung.",
	"iron": "Sehr genau, lange Flugbahn-Vorschau.",
	"wedge": "Starker Spin und hoher Chip für Trickshots.",
}
## Basiswerte (0..100) fuer Stufe 1 / Gewoehnlich.
const CATEGORY_BASE := {
	"allround": {"power": 40, "accuracy": 45, "spin": 35, "guide": 40},
	"driver": {"power": 62, "accuracy": 25, "spin": 22, "guide": 30},
	"iron": {"power": 34, "accuracy": 64, "spin": 30, "guide": 55},
	"wedge": {"power": 30, "accuracy": 40, "spin": 66, "guide": 38},
}
## Hauptwert je Kategorie bekommt pro Stufe +1 extra.
const CATEGORY_MAIN := {"allround": "guide", "driver": "power", "iron": "accuracy", "wedge": "spin"}
## Chip-Abschlagwinkel in Grad je Kategorie.
const CATEGORY_LOFT := {"allround": 36.0, "driver": 30.0, "iron": 34.0, "wedge": 46.0}
const CLUB_NAMES := {
	"allround_common": "Fairway-Freund", "allround_rare": "Grüner Baron",
	"allround_epic": "Sturmfalke", "allround_legendary": "Excalibur",
	"driver_common": "Holzhammer", "driver_rare": "Donnerkeil",
	"driver_epic": "Vulkanfaust", "driver_legendary": "Mjölnir",
	"iron_common": "Kompassnadel", "iron_rare": "Silberpfeil",
	"iron_epic": "Adlerauge", "iron_legendary": "Laserlanze",
	"wedge_common": "Trickser", "wedge_rare": "Zauberlöffel",
	"wedge_epic": "Wirbelwind", "wedge_legendary": "Schwarze Magie",
}
const STAT_KEYS: Array[String] = ["power", "accuracy", "spin", "guide"]
const STAT_NAMES := {"power": "Power", "accuracy": "Accuracy", "spin": "Spin", "guide": "Guide"}
const STAT_HINTS := {
	"power": "Schlagkraft",
	"accuracy": "Genauigkeit / weniger Streuung",
	"spin": "Effet-Stärke",
	"guide": "Länge der Flugbahn-Vorschau",
}
const UPGRADE_CARDS: Array[int] = [2, 4, 8, 15, 25, 40, 60, 90, 130, 180, 250]
const UPGRADE_COINS: Array[int] = [50, 120, 250, 450, 800, 1300, 2000, 3000, 4500, 6500, 9000]
const START_CLUB := "allround_common"

static func club_ids() -> Array[String]:
	var out: Array[String] = []
	for c in CATEGORIES:
		for r in RARITIES:
			out.append("%s_%s" % [c, r])
	return out

static func club_category(id: String) -> String:
	return id.get_slice("_", 0)

static func club_rarity(id: String) -> String:
	return id.get_slice("_", 1)

static func club_name(id: String) -> String:
	return str(CLUB_NAMES.get(id, id))

static func club_max_level(id: String) -> int:
	return int(RARITY_MAX_LEVEL.get(club_rarity(id), 6))

## Werte (0..100) eines Schlaegers auf einer Stufe (1..max).
static func club_stats(id: String, level: int) -> Dictionary:
	var cat := club_category(id)
	var rar := club_rarity(id)
	var base: Dictionary = CATEGORY_BASE.get(cat, CATEGORY_BASE["allround"])
	var lvl: int = clampi(level, 1, club_max_level(id))
	var out := {}
	for k in STAT_KEYS:
		var v: float = float(base[k]) + float(RARITY_BONUS.get(rar, 0)) + 2.0 * float(lvl - 1)
		if str(CATEGORY_MAIN.get(cat, "")) == k:
			v += float(lvl - 1)
		out[k] = clampf(v, 0.0, 100.0)
	return out

## Karten, die fuer das Upgrade von `level` auf `level + 1` noetig sind.
static func upgrade_card_cost(id: String, level: int) -> int:
	var i: int = clampi(level - 1, 0, UPGRADE_CARDS.size() - 1)
	return maxi(1, int(round(float(UPGRADE_CARDS[i]) * float(RARITY_CARD_MULT.get(club_rarity(id), 1.0)))))

static func upgrade_coin_cost(id: String, level: int) -> int:
	var i: int = clampi(level - 1, 0, UPGRADE_COINS.size() - 1)
	return int(round(float(UPGRADE_COINS[i]) * float(RARITY_COIN_MULT.get(club_rarity(id), 1.0))))

# --- Umrechnung der Werte (0..100) in Spielphysik ---
static func power_factor(power: float) -> float:
	return 0.85 + 0.45 * power / 100.0

## Maximale Streuung in Grad bei voller Kraft.
static func scatter_degrees(accuracy: float) -> float:
	return lerpf(4.0, 0.25, accuracy / 100.0)

static func spin_factor(spin: float) -> float:
	return 0.3 + 0.9 * spin / 100.0

## Laenge der Flugbahn-Vorschau in Sekunden.
static func guide_seconds(guide: float) -> float:
	return lerpf(0.55, 2.6, guide / 100.0)

# ---------------------------------------------------------------- Baelle
const BALLS := {
	"standard": {"name": "Standard", "coins": 0, "gems": 0, "bonus": {}, "desc": "Der Klassiker."},
	"magma": {"name": "Magma-Kern", "coins": 1500, "gems": 0, "bonus": {"power": 0.03}, "desc": "+3% Schlagkraft"},
	"holo": {"name": "Cyber-Hologramm", "coins": 2500, "gems": 0, "bonus": {"wind_resist": 0.15}, "desc": "+15% Windresistenz"},
	"gold": {"name": "Goldbarren", "coins": 0, "gems": 120, "bonus": {"coins": 0.10}, "desc": "+10% Münzen pro Match"},
	"lightning": {"name": "Blitz-Kugel", "coins": 0, "gems": 200, "bonus": {"roll": 0.06}, "desc": "Rollt 6% weiter"},
	"soccer": {"name": "Fußball", "coins": 4000, "gems": 0, "bonus": {"bounce": 0.10}, "desc": "Mehr Bounce"},
}
const BALL_ORDER: Array[String] = ["standard", "magma", "holo", "gold", "lightning", "soccer"]

# ---------------------------------------------------------------- Trails
const TRAILS := {
	"none": {"name": "Kein Trail", "coins": 0, "gems": 0},
	"fire": {"name": "Feuer", "coins": 800, "gems": 0},
	"lightning": {"name": "Blitze", "coins": 0, "gems": 60},
	"rainbow": {"name": "Regenbogen", "coins": 1500, "gems": 0},
	"matrix": {"name": "Matrix-Code", "coins": 0, "gems": 90},
	"ice": {"name": "Eis-Kristalle", "coins": 1200, "gems": 0},
}
const TRAIL_ORDER: Array[String] = ["none", "fire", "lightning", "rainbow", "matrix", "ice"]

# ---------------------------------------------------------------- Loch-Explosionen
const EXPLOSIONS := {
	"confetti": {"name": "Konfetti-Kanone", "coins": 0, "gems": 0},
	"lightning": {"name": "Blitzschlag", "coins": 1000, "gems": 0},
	"blackhole": {"name": "Schwarzes Loch", "coins": 0, "gems": 150},
	"volcano": {"name": "Vulkan-Ausbruch", "coins": 2500, "gems": 0},
	"fireworks": {"name": "Feuerwerk", "coins": 0, "gems": 80},
}
const EXPLOSION_ORDER: Array[String] = ["confetti", "lightning", "blackhole", "volcano", "fireworks"]

# ---------------------------------------------------------------- Avatar-Rahmen
const FRAMES := {
	"bronze": {"name": "Bronze", "color": Color(0.8, 0.5, 0.25), "coins": 0, "gems": 0, "league": "bronze"},
	"silver": {"name": "Silber", "color": Color(0.8, 0.84, 0.9), "coins": 0, "gems": 0, "league": "silver"},
	"gold": {"name": "Gold", "color": Color(1.0, 0.8, 0.2), "coins": 0, "gems": 0, "league": "gold"},
	"diamond": {"name": "Diamant", "color": Color(0.45, 0.9, 1.0), "coins": 0, "gems": 0, "league": "diamond"},
	"champion": {"name": "Champion", "color": Color(1.0, 0.3, 0.45), "coins": 0, "gems": 0, "league": "champion"},
	"neon": {"name": "Neon", "color": Color(0.3, 1.0, 0.8), "coins": 0, "gems": 100, "league": ""},
	"flame": {"name": "Flamme", "color": Color(1.0, 0.45, 0.1), "coins": 3000, "gems": 0, "league": ""},
	# Nur im Battle Pass erhaeltlich (kein Preis, keine Liga)
	"summit": {"name": "Gipfelstürmer", "color": Color(0.55, 0.8, 1.0), "coins": 0, "gems": 0, "league": "", "pass": true},
	"peak": {"name": "Saison-Krone", "color": Color(1.0, 0.62, 0.95), "coins": 0, "gems": 0, "league": "", "pass": true},
}
const FRAME_ORDER: Array[String] = ["bronze", "silver", "gold", "diamond", "champion", "neon", "flame", "summit", "peak"]
const AVATAR_COLORS: Array[Color] = [
	Color(0.2, 0.6, 1.0), Color(1.0, 0.45, 0.25), Color(0.4, 0.85, 0.35), Color(0.85, 0.35, 0.9),
	Color(1.0, 0.8, 0.2), Color(0.25, 0.85, 0.8), Color(1.0, 0.35, 0.5), Color(0.6, 0.6, 0.7),
]

static func item_table(kind: String) -> Dictionary:
	match kind:
		"ball":
			return BALLS
		"trail":
			return TRAILS
		"explosion":
			return EXPLOSIONS
		"frame":
			return FRAMES
	return {}

static func item_order(kind: String) -> Array[String]:
	match kind:
		"ball":
			return BALL_ORDER
		"trail":
			return TRAIL_ORDER
		"explosion":
			return EXPLOSION_ORDER
		"frame":
			return FRAME_ORDER
	var empty: Array[String] = []
	return empty

static func item_name(kind: String, id: String) -> String:
	var t := item_table(kind)
	if t.has(id):
		return str(t[id]["name"])
	return id

static func kind_name(kind: String) -> String:
	match kind:
		"ball":
			return "Ball"
		"trail":
			return "Trail"
		"explosion":
			return "Loch-Explosion"
		"frame":
			return "Avatar-Rahmen"
		"club":
			return "Schläger"
	return kind

# ---------------------------------------------------------------- Truhen
const CHESTS := {
	"wood": {
		"name": "Holztruhe", "seconds": 900, "coins": [60, 120], "gems": [0, 2], "cards": 6,
		"weights": [85.0, 14.0, 1.0, 0.0], "item_chance": 0.0, "color": Color(0.62, 0.42, 0.22), "gem_price": 15,
	},
	"silver": {
		"name": "Silbertruhe", "seconds": 3600, "coins": [150, 300], "gems": [2, 5], "cards": 14,
		"weights": [70.0, 25.0, 4.5, 0.5], "item_chance": 0.04, "color": Color(0.78, 0.82, 0.9), "gem_price": 40,
	},
	"gold": {
		"name": "Goldtruhe", "seconds": 10800, "coins": [400, 700], "gems": [5, 12], "cards": 30,
		"weights": [55.0, 33.0, 10.0, 2.0], "item_chance": 0.15, "color": Color(1.0, 0.78, 0.2), "gem_price": 90,
	},
	"magic": {
		"name": "Super-Magie-Truhe", "seconds": 28800, "coins": [900, 1500], "gems": [15, 30], "cards": 60,
		"weights": [40.0, 38.0, 17.0, 5.0], "item_chance": 0.5, "color": Color(0.75, 0.35, 1.0), "gem_price": 220,
	},
}
const CHEST_ORDER: Array[String] = ["wood", "silver", "gold", "magic"]
const CHEST_SLOTS := 4

## Gems, um eine Truhe mit `remaining` Sekunden Restzeit sofort zu oeffnen.
static func chest_skip_cost(remaining: float) -> int:
	if remaining <= 0.0:
		return 0
	return 1 + int(ceil(remaining / 600.0))

# ---------------------------------------------------------------- Ligen & Trophaeen-Pfad
const LEAGUES: Array[Dictionary] = [
	{"id": "bronze", "name": "Bronze", "min": 0, "color": Color(0.8, 0.5, 0.25)},
	{"id": "silver", "name": "Silber", "min": 300, "color": Color(0.8, 0.84, 0.9)},
	{"id": "gold", "name": "Gold", "min": 700, "color": Color(1.0, 0.8, 0.2)},
	{"id": "diamond", "name": "Diamant", "min": 1300, "color": Color(0.45, 0.9, 1.0)},
	{"id": "champion", "name": "Champion", "min": 2200, "color": Color(1.0, 0.3, 0.45)},
]

static func league_for(trophies: int) -> Dictionary:
	var out: Dictionary = LEAGUES[0]
	for l in LEAGUES:
		if trophies >= int(l["min"]):
			out = l
	return out

static func league_index(trophies: int) -> int:
	var idx := 0
	for i in LEAGUES.size():
		if trophies >= int(LEAGUES[i]["min"]):
			idx = i
	return idx

## Belohnungen: coins / gems / chest (Typ) / frame (Rahmen-ID) / item ([kind, id]).
const TROPHY_ROAD: Array[Dictionary] = [
	{"at": 50, "coins": 150},
	{"at": 100, "chest": "wood"},
	{"at": 200, "gems": 10},
	{"at": 300, "chest": "silver", "frame": "silver"},
	{"at": 450, "coins": 600},
	{"at": 600, "item": ["trail", "fire"]},
	{"at": 700, "chest": "gold", "frame": "gold"},
	{"at": 900, "gems": 40},
	{"at": 1100, "coins": 1500},
	{"at": 1300, "chest": "magic", "frame": "diamond"},
	{"at": 1600, "gems": 80},
	{"at": 1900, "coins": 4000},
	{"at": 2200, "chest": "magic", "frame": "champion", "gems": 150},
]

# ---------------------------------------------------------------- Battle Pass (kostenlos, Saisons zu 28 Tagen)
## Saison 1 beginnt am Montag, 5. Januar 2026 (00:00 UTC). Danach startet alle 28 Tage eine neue Saison.
const PASS_EPOCH_UNIX := 1767571200
const PASS_SEASON_DAYS := 28
const PASS_XP_PER_TIER := 150
const PASS_SEASON_NAMES: Array[String] = ["Gipfelsturm", "Lavaglut", "Neonnacht", "Piratengold", "Eiskante", "Canyonfieber"]
## XP-Quellen
const PASS_XP_MATCH := 40
const PASS_XP_RANK: Array[int] = [40, 25, 15, 5, 0, 0]
const PASS_XP_HOLE_IN_ONE := 20
const PASS_XP_STYLE_CAP := 30
const PASS_XP_PRACTICE := 15
const PASS_XP_DAILY := 30
## Eine Belohnung pro Stufe (30 Stufen). Bereits besessene Gegenstaende werden in Coins umgewandelt (PASS_DUPLICATE_COINS).
const PASS_DUPLICATE_COINS := 300
const PASS_TIERS: Array[Dictionary] = [
	{"coins": 100}, {"chest": "wood"}, {"gems": 5}, {"coins": 150}, {"item": ["trail", "fire"]},
	{"coins": 200}, {"chest": "silver"}, {"gems": 10}, {"coins": 250}, {"item": ["frame", "summit"]},
	{"coins": 300}, {"chest": "silver"}, {"gems": 12}, {"item": ["explosion", "lightning"]}, {"coins": 350},
	{"chest": "gold"}, {"gems": 15}, {"coins": 400}, {"item": ["trail", "ice"]}, {"coins": 450},
	{"chest": "gold"}, {"gems": 20}, {"item": ["ball", "magma"]}, {"coins": 500}, {"chest": "gold"},
	{"gems": 25}, {"item": ["trail", "rainbow"]}, {"coins": 750}, {"gems": 40}, {"chest": "magic", "item": ["frame", "peak"]},
]

## Saison-Nummer (ab 1) fuer einen Unix-Zeitpunkt.
static func pass_season_at(unix: float) -> int:
	var days: int = int(floor((unix - float(PASS_EPOCH_UNIX)) / 86400.0))
	return maxi(1, int(floor(float(days) / float(PASS_SEASON_DAYS))) + 1)

static func pass_season_end(season: int) -> float:
	return float(PASS_EPOCH_UNIX) + float(season * PASS_SEASON_DAYS) * 86400.0

static func pass_season_name(season: int) -> String:
	return PASS_SEASON_NAMES[(maxi(1, season) - 1) % PASS_SEASON_NAMES.size()]

static func pass_max_xp() -> int:
	return PASS_TIERS.size() * PASS_XP_PER_TIER

## Pass-XP fuer ein beendetes Match.
static func pass_xp_for_match(rank: int, player_count: int, style_points: int, holes_in_one: int, practice: bool) -> int:
	if practice or player_count <= 1:
		return PASS_XP_PRACTICE
	var xp: int = PASS_XP_MATCH + PASS_XP_RANK[clampi(rank - 1, 0, PASS_XP_RANK.size() - 1)]
	xp += mini(PASS_XP_STYLE_CAP, int(style_points / 10))
	xp += PASS_XP_HOLE_IN_ONE * maxi(0, holes_in_one)
	return xp

## Kurztext einer Pass-Belohnung, z.B. "250 Coins" oder "Goldtruhe".
static func pass_reward_text(tier_index: int) -> String:
	if tier_index < 0 or tier_index >= PASS_TIERS.size():
		return ""
	var e: Dictionary = PASS_TIERS[tier_index]
	var parts := PackedStringArray()
	if e.has("coins"):
		parts.append("%d Coins" % int(e["coins"]))
	if e.has("gems"):
		parts.append("%d Gems" % int(e["gems"]))
	if e.has("chest"):
		parts.append(str(CHESTS[str(e["chest"])]["name"]))
	if e.has("item"):
		var it: Array = e["item"]
		parts.append("%s „%s“" % [kind_name(str(it[0])), item_name(str(it[0]), str(it[1]))])
	return " + ".join(parts)

## Symbol einer Pass-Belohnung fuer die UI (UIIcon-Art).
static func pass_reward_icon(tier_index: int) -> String:
	var e: Dictionary = PASS_TIERS[clampi(tier_index, 0, PASS_TIERS.size() - 1)]
	if e.has("item"):
		var kind: String = str((e["item"] as Array)[0])
		return "ball" if kind == "ball" else ("star" if kind == "frame" else "gift")
	if e.has("chest"):
		return "chest"
	if e.has("gems"):
		return "gem"
	return "coin"

# ---------------------------------------------------------------- Match-Belohnungen
const RANK_COINS: Array[int] = [120, 80, 55, 40, 30, 20]

static func trophies_for_rank(rank: int, player_count: int) -> int:
	if player_count <= 1:
		return 0
	var p: float = float(rank - 1) / float(player_count - 1)
	return int(round(lerpf(30.0, -16.0, p)))

static func coins_for_rank(rank: int) -> int:
	return RANK_COINS[clampi(rank - 1, 0, RANK_COINS.size() - 1)]

# ---------------------------------------------------------------- Welten & Bahnen
const WORLDS: Array[Dictionary] = [
	{"id": "emerald", "name": "Emerald Valley", "courses": ["e1", "e2", "e3", "e4", "e5"],
		"desc": "Grüne Hügel, Holzbrücken, Windmühlen", "color": Color(0.25, 0.75, 0.35)},
	{"id": "volcano", "name": "Volcano Canyon", "courses": ["v1", "v2", "v3", "v4"],
		"desc": "Lava, Sprungschanzen, Speed-Booster", "color": Color(0.95, 0.4, 0.15)},
	{"id": "neon", "name": "Cyber Neon City", "courses": ["n1", "n2", "n3"],
		"desc": "Loopings, Laser, Teleporter", "color": Color(0.2, 0.9, 1.0)},
	{"id": "pirate", "name": "Pirate Cove", "courses": ["p1", "p2", "p3"],
		"desc": "Planken, Kanonen, Plattformen", "color": Color(0.95, 0.75, 0.35)},
]
const ROUND_OPTIONS: Array[int] = [3, 5, 9]
const MAX_PLAYERS := 6

static func world_ids() -> Array[String]:
	var out: Array[String] = []
	for w in WORLDS:
		out.append(str(w["id"]))
	return out

static func world_by_id(id: String) -> Dictionary:
	for w in WORLDS:
		if str(w["id"]) == id:
			return w
	return WORLDS[0]

static func world_of_course(course_id: String) -> String:
	for w in WORLDS:
		if course_id in (w["courses"] as Array):
			return str(w["id"])
	if course_id.begins_with("daily"):
		return "emerald"
	return "emerald"

static func all_course_ids() -> Array[String]:
	var out: Array[String] = []
	for w in WORLDS:
		for c in (w["courses"] as Array):
			out.append(str(c))
	return out

## Bahnliste fuer ein Match: zuerst die Bahnen der gewaehlten Welt (gemischt per Seed),
## danach "Welt-Tour" durch die folgenden Welten, bis `rounds` erreicht ist.
static func build_course_list(world_id: String, rounds: int, rng_seed: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var order: Array[String] = world_ids()
	var start: int = maxi(0, order.find(world_id))
	var out: Array[String] = []
	var guard := 0
	while out.size() < rounds and guard < 16:
		var w: Dictionary = world_by_id(order[(start + guard) % order.size()])
		var list: Array = (w["courses"] as Array).duplicate()
		# Fisher-Yates mit eigenem RNG (deterministisch fuer alle Clients)
		for i in range(list.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: Variant = list[i]
			list[i] = list[j]
			list[j] = tmp
		for c in list:
			if out.size() < rounds:
				out.append(str(c))
		guard += 1
	return out

# ---------------------------------------------------------------- Emotes
const EMOTES: Array[Dictionary] = [
	{"id": "nice", "text": "Nice Shot!", "icon": ""},
	{"id": "oops", "text": "Oops!", "icon": ""},
	{"id": "fire", "text": "", "icon": "fire"},
	{"id": "laugh", "text": "", "icon": "laugh"},
	{"id": "gg", "text": "GG!", "icon": ""},
	{"id": "wow", "text": "Wow!", "icon": ""},
]

static func emote_by_id(id: String) -> Dictionary:
	for e in EMOTES:
		if str(e["id"]) == id:
			return e
	return EMOTES[0]

# ---------------------------------------------------------------- Bots
const BOT_NAMES: Array[String] = [
	"PuttPirat", "BirdieBen", "LochLisa", "TeeRex", "GreenGoblin", "AlbatrosAnna",
	"CaddyCarl", "SandySam", "FlopFritz", "EagleEmma", "BogeyBoris", "DriverDana",
]
const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.65, 1.0), Color(1.0, 0.5, 0.25), Color(0.9, 0.35, 0.9),
	Color(1.0, 0.9, 0.25), Color(0.35, 0.95, 0.55), Color(1.0, 0.4, 0.5),
]

# ---------------------------------------------------------------- Style-Punkte
const STYLE_AIR_TIME := 60       # ab 1.0 s Flugzeit
const STYLE_BANK_SHOT := 40      # pro Bande (max. 3 pro Schlag)
const STYLE_CLOSE_CALL := 80
const STYLE_HOLE_IN_ONE := 300
const STYLE_LONG_PUTT := 100     # eingelocht aus > 20 m
const STYLE_SHORTCUT := 120      # Abkuerzung gesprungen und auf dem Gruen gelandet
const STYLE_TO_COINS := 0.1      # 10 Style-Punkte = 1 Coin

# ---------------------------------------------------------------- Daily Challenge
static func daily_rewards(distance: float, holed: bool) -> Dictionary:
	if holed:
		return {"coins": 500, "gems": 15, "chest": "gold", "label": "HOLE IN ONE!"}
	if distance < 1.0:
		return {"coins": 300, "gems": 8, "label": "Zentimeterarbeit!"}
	if distance < 3.0:
		return {"coins": 200, "gems": 4, "label": "Ganz nah dran!"}
	if distance < 6.0:
		return {"coins": 120, "label": "Guter Schuss!"}
	if distance < 12.0:
		return {"coins": 60, "label": "Solide."}
	return {"coins": 25, "label": "Morgen klappt's besser."}
