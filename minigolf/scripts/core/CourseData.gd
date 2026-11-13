class_name CourseData
extends RefCounted
## Bahn-Definitionen als reine Daten. Koordinaten: Bahn-Raum 0..720 x 0..960 (Hochformat).
## hazards: wind / boost / windmill / magnet / water.

static func all() -> Dictionary:
	return {
		"meadow": {
			"name": "Wiese", "par": 2,
			"bounds": PackedVector2Array([Vector2(60, 60), Vector2(660, 60), Vector2(660, 900), Vector2(60, 900)]),
			"obstacles": [],
			"tee": Vector2(360, 830), "hole": Vector2(360, 140),
			"hazards": [],
		},
		"zigzag": {
			"name": "Zickzack", "par": 3,
			"bounds": PackedVector2Array([Vector2(60, 60), Vector2(660, 60), Vector2(660, 900), Vector2(60, 900)]),
			"obstacles": [
				PackedVector2Array([Vector2(60, 640), Vector2(470, 640), Vector2(470, 680), Vector2(60, 680)]),
				PackedVector2Array([Vector2(250, 380), Vector2(660, 380), Vector2(660, 420), Vector2(250, 420)]),
			],
			"tee": Vector2(150, 830), "hole": Vector2(150, 140),
			"hazards": [
				{"type": "boost", "pos": Vector2(540, 760), "size": Vector2(70, 40), "dir": Vector2(0, -1), "power": 420.0},
			],
		},
		"windmill": {
			"name": "Windmuehle", "par": 3,
			"bounds": PackedVector2Array([Vector2(60, 60), Vector2(660, 60), Vector2(660, 900), Vector2(60, 900)]),
			"obstacles": [
				PackedVector2Array([Vector2(60, 470), Vector2(250, 470), Vector2(250, 500), Vector2(60, 500)]),
				PackedVector2Array([Vector2(470, 470), Vector2(660, 470), Vector2(660, 500), Vector2(470, 500)]),
			],
			"tee": Vector2(360, 840), "hole": Vector2(360, 140),
			"hazards": [
				{"type": "windmill", "pos": Vector2(360, 485), "length": 130.0, "speed": 1.6},
				{"type": "wind", "rect": Rect2(60, 600, 600, 200), "force": Vector2(160, 0), "gusty": true},
				{"type": "water", "poly": PackedVector2Array([Vector2(480, 240), Vector2(640, 240), Vector2(640, 320), Vector2(480, 320)])},
				{"type": "magnet", "pos": Vector2(250, 250), "radius": 130.0, "strength": 520.0},
			],
		},
		# Sudden-Death-Gruen: nur Tee + Pin, kein Loch -> Entfernung zum Pin entscheidet.
		"pin_shot": {
			"name": "Nearest to the Pin", "par": 1, "pin_only": true,
			"bounds": PackedVector2Array([Vector2(60, 60), Vector2(660, 60), Vector2(660, 900), Vector2(60, 900)]),
			"obstacles": [],
			"tee": Vector2(360, 830), "hole": Vector2(360, 260),
			"hazards": [],
		},
	}

static func get_course(id: String) -> Dictionary:
	var d: Dictionary = all()
	return d[id] if d.has(id) else d["meadow"]

static func match_set() -> Array:
	return ["meadow", "zigzag", "windmill"]
