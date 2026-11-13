class_name Course
extends Node2D
## Baut eine Bahn aus CourseData: Boden, Waende (Liniensegmente), Loch/Pin, Hazards.

var data: Dictionary = {}
var tee_pos: Vector2
var hole_pos: Vector2
var hole_enabled: bool = true
var par: int = 3
var hazards: Array = []
var bounds: PackedVector2Array
var _static_segs: Array = []
var _obstacles: Array = []

func build(d: Dictionary) -> void:
	data = d
	tee_pos = d["tee"]
	hole_pos = d["hole"]
	par = int(d["par"])
	hole_enabled = not bool(d.get("pin_only", false))
	bounds = d["bounds"]
	_obstacles = d["obstacles"]
	_static_segs.clear()
	_add_poly_segments(bounds)
	for o in _obstacles:
		_add_poly_segments(o)
	for h in hazards:
		h.queue_free()
	hazards.clear()
	for hd in d["hazards"]:
		var hz := _make_hazard(hd)
		if hz:
			add_child(hz)
			hazards.append(hz)
	queue_redraw()

func _add_poly_segments(poly: PackedVector2Array) -> void:
	for i in poly.size():
		_static_segs.append([poly[i], poly[(i + 1) % poly.size()]])

func get_segments() -> Array:
	var out := _static_segs.duplicate()
	for h in hazards:
		out.append_array(h.get_segments())
	return out

func _make_hazard(d: Dictionary) -> Hazard:
	match d["type"]:
		"wind": return WindZone.new(d["rect"], d["force"], bool(d.get("gusty", false)))
		"boost": return BoostPad.new(d["pos"], d["size"], d["dir"], float(d["power"]))
		"windmill": return Windmill.new(d["pos"], float(d["length"]), float(d["speed"]))
		"magnet": return MagnetField.new(d["pos"], float(d["radius"]), float(d["strength"]))
		"water": return WaterHazard.new(d["poly"])
	return null

func _draw() -> void:
	if bounds.is_empty():
		return
	draw_colored_polygon(bounds, Color(0.22, 0.58, 0.28))
	# Rasterstreifen
	var bb := Rect2(bounds[0], Vector2.ZERO)
	for p in bounds:
		bb = bb.expand(p)
	var y := bb.position.y
	var k := 0
	while y < bb.end.y:
		if k % 2 == 0:
			var strip := Geometry2D.intersect_polygons(bounds, PackedVector2Array([
				Vector2(bb.position.x, y), Vector2(bb.end.x, y), Vector2(bb.end.x, y + 60), Vector2(bb.position.x, y + 60)]))
			for sp in strip:
				draw_colored_polygon(sp, Color(0.25, 0.63, 0.31))
		y += 60.0
		k += 1
	for o in _obstacles:
		draw_colored_polygon(o, Color(0.45, 0.3, 0.18))
		draw_polyline(o + PackedVector2Array([o[0]]), Color(0.25, 0.15, 0.08), 4.0)
	draw_polyline(bounds + PackedVector2Array([bounds[0]]), Color(0.9, 0.85, 0.7), 8.0)
	# Tee
	draw_circle(tee_pos, 14.0, Color(1, 1, 1, 0.25))
	# Loch bzw. Pin-Ziel
	if hole_enabled:
		draw_circle(hole_pos, Ball.HOLE_RADIUS, Color(0.05, 0.05, 0.05))
	else:
		for i in 4:
			draw_arc(hole_pos, 30.0 + i * 30.0, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0)
	draw_line(hole_pos, hole_pos + Vector2(0, -60), Color.WHITE, 3.0)
	draw_colored_polygon(PackedVector2Array([hole_pos + Vector2(0, -60), hole_pos + Vector2(34, -48), hole_pos + Vector2(0, -36)]), Color(0.9, 0.2, 0.2))
