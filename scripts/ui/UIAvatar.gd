class_name UIAvatar
extends Control
## Avatar: farbiger Kreis mit Anfangsbuchstabe + Avatar-Rahmen (Bronze ... Champion, Neon, Flamme).

var display_name: String = "?"
var color_index: int = 0
var frame_id: String = "bronze"

func _init(p_name: String = "?", p_color: int = 0, p_frame: String = "bronze", p_size: float = 56.0) -> void:
	display_name = p_name
	color_index = p_color
	frame_id = p_frame
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_player(p_name: String, p_color: int, p_frame: String) -> void:
	display_name = p_name
	color_index = p_color
	frame_id = p_frame
	queue_redraw()

func _draw() -> void:
	var c: Vector2 = size * 0.5
	var r: float = minf(size.x, size.y) * 0.5
	var frame: Dictionary = Catalog.FRAMES.get(frame_id, Catalog.FRAMES["bronze"])
	var fc: Color = frame["color"]
	var bg: Color = Catalog.AVATAR_COLORS[clampi(color_index, 0, Catalog.AVATAR_COLORS.size() - 1)]
	draw_circle(c, r, fc.darkened(0.45))
	draw_circle(c, r * 0.94, fc)
	draw_circle(c, r * 0.8, bg.darkened(0.25))
	draw_circle(c + Vector2(0, -r * 0.06), r * 0.74, bg)
	var letter: String = display_name.substr(0, 1).to_upper() if display_name.length() > 0 else "?"
	var font: Font = get_theme_default_font()
	var fs: int = int(r * 0.95)
	var ts: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
	draw_string_outline(font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0, 0, 0, 0.55))
	draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.32), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	match frame_id:
		"neon":
			draw_arc(c, r * 1.0, 0.0, TAU, 40, Color(1.0, 0.3, 0.9), r * 0.06)
		"flame":
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				var tip: Vector2 = c + Vector2(cos(a), sin(a)) * r * 1.12
				var l: Vector2 = c + Vector2(cos(a - 0.2), sin(a - 0.2)) * r * 0.92
				var rr: Vector2 = c + Vector2(cos(a + 0.2), sin(a + 0.2)) * r * 0.92
				draw_colored_polygon(PackedVector2Array([tip, l, rr]), Color(1.0, 0.8, 0.2))
		"champion", "diamond":
			var pts := PackedVector2Array()
			for i in 10:
				var a2: float = -PI * 0.5 + TAU * float(i) / 10.0
				var rad: float = r * (0.3 if i % 2 == 0 else 0.13)
				pts.append(c + Vector2(0, -r * 0.92) + Vector2(cos(a2), sin(a2)) * rad)
			draw_colored_polygon(pts, Color.WHITE)
