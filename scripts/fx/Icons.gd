class_name Icons
extends RefCounted
## Prozedural gezeichnete Emote-Bilder (Lach-Emoji, Feuer-Emoji) als Texturen - ohne Bilddateien.
## Die Formen werden per Code in ein Image gerastert (2x2-Supersampling fuer glatte Kanten).

const SIZE := 64
static var _cache: Dictionary = {}

static func emote(icon: String) -> ImageTexture:
	if _cache.has(icon):
		return _cache[icon]
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	if icon == "fire":
		_draw_fire(img)
	else:
		_draw_laugh(img)
	var tex := ImageTexture.create_from_image(img)
	_cache[icon] = tex
	return tex

## Fuellt alle Pixel, fuer die `inside` wahr ist (Callable: Vector2 -> bool), mit Kantenglaettung.
static func _fill(img: Image, rect: Rect2i, color: Color, inside: Callable) -> void:
	var offs: Array[Vector2] = [Vector2(0.25, 0.25), Vector2(0.75, 0.25), Vector2(0.25, 0.75), Vector2(0.75, 0.75)]
	var r: Rect2i = rect.intersection(Rect2i(0, 0, SIZE, SIZE))
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var hits := 0
			for o in offs:
				if inside.call(Vector2(float(x), float(y)) + o):
					hits += 1
			if hits == 0:
				continue
			var a: float = color.a * float(hits) / 4.0
			var old: Color = img.get_pixel(x, y)
			var out_a: float = a + old.a * (1.0 - a)
			var rgb: Color = (color * a + old * (old.a * (1.0 - a))) / maxf(out_a, 0.0001)
			img.set_pixel(x, y, Color(rgb.r, rgb.g, rgb.b, out_a))

static func _disc(img: Image, c: Vector2, radius: float, color: Color) -> void:
	var rect := Rect2i(int(c.x - radius) - 1, int(c.y - radius) - 1, int(radius * 2.0) + 3, int(radius * 2.0) + 3)
	_fill(img, rect, color, func(p: Vector2) -> bool: return p.distance_squared_to(c) <= radius * radius)

static func _ellipse(img: Image, c: Vector2, rx: float, ry: float, color: Color, min_y: float = -INF, max_y: float = INF) -> void:
	var rect := Rect2i(int(c.x - rx) - 1, int(c.y - ry) - 1, int(rx * 2.0) + 3, int(ry * 2.0) + 3)
	_fill(img, rect, color, func(p: Vector2) -> bool:
		var dx: float = (p.x - c.x) / rx
		var dy: float = (p.y - c.y) / ry
		return dx * dx + dy * dy <= 1.0 and p.y >= min_y and p.y <= max_y)

static func _poly(img: Image, pts: PackedVector2Array, color: Color) -> void:
	_fill(img, Rect2i(0, 0, SIZE, SIZE), color, func(p: Vector2) -> bool: return Geometry2D.is_point_in_polygon(p, pts))

static func _scaled(pts: PackedVector2Array, around: Vector2, f: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(around + (p - around) * f)
	return out

static func _draw_laugh(img: Image) -> void:
	var c := Vector2(32, 32)
	_disc(img, c, 30.5, Color(0.85, 0.5, 0.05))
	_disc(img, c, 28.5, Color(1.0, 0.84, 0.22))
	# Lachende, geschlossene Augen (Boegen)
	for ex: float in [21.0, 43.0]:
		var ec := Vector2(ex, 27.0)
		_fill(img, Rect2i(int(ex) - 9, 17, 18, 12), Color(0.25, 0.14, 0.05), func(p: Vector2) -> bool:
			return absf(p.distance_to(ec) - 6.0) < 1.7 and p.y < 27.5)
	# Offener Mund mit Zaehnen und Zunge
	_ellipse(img, Vector2(32, 36), 15.0, 15.0, Color(0.45, 0.08, 0.08), 36.0)
	_ellipse(img, Vector2(32, 36), 15.0, 15.0, Color(1, 1, 1), 36.0, 40.0)
	_ellipse(img, Vector2(32, 49), 8.0, 5.0, Color(0.95, 0.45, 0.5), 44.0)
	# Freudentraenen
	_ellipse(img, Vector2(9, 33), 4.0, 6.5, Color(0.35, 0.75, 1.0))
	_ellipse(img, Vector2(55, 33), 4.0, 6.5, Color(0.35, 0.75, 1.0))

static func _draw_fire(img: Image) -> void:
	var flame := PackedVector2Array([
		Vector2(32, 3), Vector2(40, 14), Vector2(44, 24), Vector2(52, 19), Vector2(55, 34), Vector2(52, 48), Vector2(42, 59),
		Vector2(32, 62), Vector2(22, 59), Vector2(12, 48), Vector2(9, 34), Vector2(14, 22), Vector2(20, 28), Vector2(24, 15),
	])
	_poly(img, flame, Color(1.0, 0.32, 0.08))
	_poly(img, _scaled(flame, Vector2(32, 46), 0.68), Color(1.0, 0.62, 0.12))
	_poly(img, _scaled(flame, Vector2(32, 52), 0.38), Color(1.0, 0.93, 0.45))
