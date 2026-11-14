class_name UIIcon
extends Control
## Vektor-Icons, die per Code gezeichnet werden (keine Bilddateien):
## coin, gem, trophy, chest, club, ball, friends, leader, shop, settings, eye, chip, putt, emote,
## close, play, lock, check, timer, star, flag, cards, plus, back, next, gift, spin, bolt, exit.

var kind: String = "coin"
var tint: Color = Color.WHITE

func _init(p_kind: String = "coin", p_size: float = 32.0, p_tint: Color = Color.WHITE) -> void:
	kind = p_kind
	tint = p_tint
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_kind(p_kind: String, p_tint: Color = Color.WHITE) -> void:
	kind = p_kind
	tint = p_tint
	queue_redraw()

func _p(x: float, y: float) -> Vector2:
	var r: float = minf(size.x, size.y) * 0.5
	return size * 0.5 + Vector2(x, y) * r

func _poly(points: Array, color: Color) -> void:
	var pts := PackedVector2Array()
	for p in points:
		var v: Vector2 = p
		pts.append(_p(v.x, v.y))
	draw_colored_polygon(pts, color)

func _rect(x0: float, y0: float, x1: float, y1: float, color: Color) -> void:
	var a := _p(x0, y0)
	var b := _p(x1, y1)
	draw_rect(Rect2(a, b - a), color)

func _draw() -> void:
	var r: float = minf(size.x, size.y) * 0.5
	var c: Vector2 = size * 0.5
	var dark := Color(0.08, 0.1, 0.16)
	match kind:
		"coin":
			draw_circle(c, r * 0.95, Color(0.85, 0.55, 0.05))
			draw_circle(c, r * 0.82, Color(1.0, 0.8, 0.2))
			draw_arc(c, r * 0.58, 0.0, TAU, 28, Color(1.0, 0.93, 0.55), r * 0.12)
			draw_circle(_p(-0.32, -0.36), r * 0.13, Color(1, 1, 1, 0.75))
		"gem":
			_poly([Vector2(-0.55, -0.78), Vector2(0.55, -0.78), Vector2(0.95, -0.22), Vector2(0, 0.95), Vector2(-0.95, -0.22)], Color(0.15, 0.7, 1.0))
			_poly([Vector2(-0.55, -0.78), Vector2(0.55, -0.78), Vector2(0.95, -0.22), Vector2(-0.95, -0.22)], Color(0.55, 0.92, 1.0))
			_poly([Vector2(-0.3, -0.22), Vector2(0.3, -0.22), Vector2(0, 0.95)], Color(0.35, 0.85, 1.0))
		"trophy":
			var gold := Color(1.0, 0.78, 0.18) if tint == Color.WHITE else tint
			draw_arc(_p(-0.62, -0.42), r * 0.3, PI * 0.5, PI * 1.5, 12, gold, r * 0.13)
			draw_arc(_p(0.62, -0.42), r * 0.3, -PI * 0.5, PI * 0.5, 12, gold, r * 0.13)
			_poly([Vector2(-0.62, -0.85), Vector2(0.62, -0.85), Vector2(0.5, -0.1), Vector2(0.18, 0.28), Vector2(0.18, 0.55),
				Vector2(0.5, 0.6), Vector2(0.5, 0.88), Vector2(-0.5, 0.88), Vector2(-0.5, 0.6), Vector2(-0.18, 0.55),
				Vector2(-0.18, 0.28), Vector2(-0.5, -0.1)], gold)
			_rect(-0.32, -0.7, -0.18, -0.2, Color(1, 1, 1, 0.5))
		"chest":
			_rect(-0.85, -0.1, 0.85, 0.82, tint.darkened(0.15))
			_rect(-0.9, -0.68, 0.9, -0.1, tint)
			_rect(-0.9, -0.16, 0.9, -0.04, tint.darkened(0.45))
			_rect(-0.62, -0.68, -0.45, 0.82, tint.darkened(0.4))
			_rect(0.45, -0.68, 0.62, 0.82, tint.darkened(0.4))
			_rect(-0.14, -0.26, 0.14, 0.16, Color(1.0, 0.85, 0.3))
			draw_circle(_p(0.0, -0.06), r * 0.06, dark)
		"club":
			draw_line(_p(0.55, -0.9), _p(-0.3, 0.55), Color(0.8, 0.83, 0.88), r * 0.13, true)
			_poly([Vector2(-0.22, 0.4), Vector2(-0.9, 0.55), Vector2(-0.85, 0.92), Vector2(-0.2, 0.78)], tint)
			draw_line(_p(0.55, -0.9), _p(0.36, -0.58), dark, r * 0.2, true)
		"ball":
			draw_circle(c, r * 0.85, Color(0.75, 0.78, 0.84))
			draw_circle(_p(-0.06, -0.06), r * 0.78, Color.WHITE)
			for d: Vector2 in [Vector2(-0.2, -0.25), Vector2(0.25, -0.1), Vector2(-0.05, 0.3), Vector2(0.35, 0.35), Vector2(-0.42, 0.15)]:
				draw_circle(_p(d.x, d.y), r * 0.09, Color(0.78, 0.8, 0.86))
		"friends":
			draw_circle(_p(0.42, -0.3), r * 0.26, tint.darkened(0.25))
			_poly([Vector2(0.05, 0.75), Vector2(0.1, 0.25), Vector2(0.42, 0.05), Vector2(0.75, 0.25), Vector2(0.8, 0.75)], tint.darkened(0.25))
			draw_circle(_p(-0.3, -0.38), r * 0.32, tint)
			_poly([Vector2(-0.82, 0.8), Vector2(-0.75, 0.2), Vector2(-0.3, -0.02), Vector2(0.15, 0.2), Vector2(0.22, 0.8)], tint)
		"leader":
			_rect(-0.92, 0.1, -0.34, 0.9, tint.darkened(0.2))
			_rect(-0.3, -0.35, 0.3, 0.9, tint)
			_rect(0.34, 0.35, 0.92, 0.9, tint.darkened(0.35))
			_star(_p(0.0, -0.68), r * 0.26, Color(1.0, 0.85, 0.25))
		"shop":
			draw_arc(_p(0.0, -0.35), r * 0.38, PI, TAU, 14, tint.darkened(0.3), r * 0.12)
			_poly([Vector2(-0.72, -0.35), Vector2(0.72, -0.35), Vector2(0.85, 0.9), Vector2(-0.85, 0.9)], tint)
			_rect(-0.5, -0.1, 0.5, 0.05, Color(1, 1, 1, 0.3))
		"settings":
			for i in 8:
				var a: float = TAU * float(i) / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.5, c + Vector2(cos(a), sin(a)) * r * 0.95, tint, r * 0.26)
			draw_arc(c, r * 0.5, 0.0, TAU, 28, tint, r * 0.32)
		"eye":
			var pts := PackedVector2Array()
			for i in 13:
				var x: float = -0.95 + 1.9 * float(i) / 12.0
				pts.append(_p(x, -0.58 * (1.0 - x * x)))
			for i in range(1, 12):
				var x2: float = 0.95 - 1.9 * float(i) / 12.0
				pts.append(_p(x2, 0.58 * (1.0 - x2 * x2)))
			draw_colored_polygon(pts, tint)
			draw_circle(c, r * 0.3, dark)
			draw_circle(_p(-0.1, -0.1), r * 0.1, Color.WHITE)
		"chip":
			draw_arc(_p(0.0, 0.75), r * 1.0, PI * 1.18, PI * 1.82, 18, tint, r * 0.14)
			draw_circle(_p(0.78, 0.2), r * 0.2, Color.WHITE)
			draw_line(_p(-0.95, 0.82), _p(0.95, 0.82), tint.darkened(0.3), r * 0.1)
		"putt":
			draw_line(_p(-0.9, 0.2), _p(0.35, 0.2), tint, r * 0.16)
			_poly([Vector2(0.3, -0.12), Vector2(0.72, 0.2), Vector2(0.3, 0.52)], tint)
			draw_circle(_p(-0.72, 0.2), r * 0.2, Color.WHITE)
			draw_line(_p(-0.95, 0.62), _p(0.95, 0.62), tint.darkened(0.3), r * 0.1)
		"emote":
			draw_circle(c, r * 0.9, Color(1.0, 0.82, 0.2))
			draw_circle(_p(-0.32, -0.22), r * 0.12, dark)
			draw_circle(_p(0.32, -0.22), r * 0.12, dark)
			draw_arc(_p(0.0, 0.05), r * 0.5, 0.25, PI - 0.25, 14, dark, r * 0.12)
		"close":
			draw_line(_p(-0.6, -0.6), _p(0.6, 0.6), tint, r * 0.24, true)
			draw_line(_p(0.6, -0.6), _p(-0.6, 0.6), tint, r * 0.24, true)
		"exit":
			_rect(-0.8, -0.8, -0.1, 0.8, tint.darkened(0.3))
			draw_line(_p(-0.25, 0.0), _p(0.6, 0.0), tint, r * 0.18)
			_poly([Vector2(0.45, -0.38), Vector2(0.9, 0.0), Vector2(0.45, 0.38)], tint)
		"play":
			_poly([Vector2(-0.5, -0.75), Vector2(0.8, 0.0), Vector2(-0.5, 0.75)], tint)
		"lock":
			draw_arc(_p(0.0, -0.25), r * 0.42, PI, TAU, 14, tint.darkened(0.2), r * 0.16)
			_rect(-0.62, -0.2, 0.62, 0.85, tint)
			draw_circle(_p(0.0, 0.3), r * 0.14, dark)
		"check":
			draw_polyline(PackedVector2Array([_p(-0.7, 0.05), _p(-0.2, 0.55), _p(0.75, -0.55)]), tint, r * 0.26, true)
		"timer":
			draw_arc(c, r * 0.78, 0.0, TAU, 28, tint, r * 0.16)
			draw_line(c, _p(0.0, -0.5), tint, r * 0.14)
			draw_line(c, _p(0.35, 0.15), tint, r * 0.14)
		"star":
			_star(c, r * 0.95, tint)
		"flag":
			draw_line(_p(-0.45, -0.9), _p(-0.45, 0.9), Color(0.9, 0.9, 0.9), r * 0.12)
			_poly([Vector2(-0.4, -0.85), Vector2(0.75, -0.45), Vector2(-0.4, -0.05)], tint)
		"cards":
			_poly([Vector2(-0.2, -0.75), Vector2(0.8, -0.55), Vector2(0.6, 0.75), Vector2(-0.4, 0.55)], tint.darkened(0.35))
			_poly([Vector2(-0.7, -0.7), Vector2(0.3, -0.7), Vector2(0.3, 0.7), Vector2(-0.7, 0.7)], tint)
			_star(_p(-0.2, 0.0), r * 0.3, Color(1, 1, 1, 0.85))
		"plus":
			_rect(-0.14, -0.7, 0.14, 0.7, tint)
			_rect(-0.7, -0.14, 0.7, 0.14, tint)
		"back":
			draw_polyline(PackedVector2Array([_p(0.35, -0.65), _p(-0.4, 0.0), _p(0.35, 0.65)]), tint, r * 0.26, true)
		"next":
			draw_polyline(PackedVector2Array([_p(-0.35, -0.65), _p(0.4, 0.0), _p(-0.35, 0.65)]), tint, r * 0.26, true)
		"gift":
			_rect(-0.75, -0.2, 0.75, 0.85, tint)
			_rect(-0.85, -0.5, 0.85, -0.15, tint.lightened(0.15))
			_rect(-0.13, -0.5, 0.13, 0.85, Color(1.0, 0.85, 0.3))
			draw_arc(_p(-0.25, -0.62), r * 0.22, 0.0, TAU, 12, Color(1.0, 0.85, 0.3), r * 0.1)
			draw_arc(_p(0.25, -0.62), r * 0.22, 0.0, TAU, 12, Color(1.0, 0.85, 0.3), r * 0.1)
		"spin":
			draw_arc(c, r * 0.68, -0.4, PI * 1.35, 20, tint, r * 0.16)
			_poly([Vector2(0.42, -0.72), Vector2(0.95, -0.38), Vector2(0.38, -0.12)], tint)
		"bolt":
			_poly([Vector2(0.25, -0.95), Vector2(-0.55, 0.12), Vector2(-0.02, 0.12), Vector2(-0.3, 0.95), Vector2(0.6, -0.2), Vector2(0.05, -0.2)], tint)
		_:
			draw_circle(c, r * 0.8, tint)

func _star(center: Vector2, radius: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + TAU * float(i) / 10.0
		var rr: float = radius if i % 2 == 0 else radius * 0.45
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, color)
