class_name Cosmetics
extends RefCounted
## Erzeugt Trail- und Loch-Effekte aus Katalog-IDs.

## Trail als Line2D, der dem Ball folgt (wird in GameScene pro Frame gefuettert).
static func make_trail(trail_id: String) -> Line2D:
	var cols: Array = Catalog.TRAILS.get(trail_id, Catalog.TRAILS["none"])["colors"]
	if cols.is_empty():
		return null
	var l := Line2D.new()
	l.width = 14.0
	l.top_level = true          # Weltkoordinaten, unabhaengig vom Ball-Node
	l.z_index = -1
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[cols.size() - 1 - i])   # Ende (alt) transparent
	g.offsets = offs
	g.colors = cs
	l.gradient = g
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	return l

## Einmaliger Partikel-Burst beim Einlochen.
static func make_hole_fx(fx_id: String, at: Vector2) -> CPUParticles2D:
	var cols: Array = Catalog.HOLE_FX.get(fx_id, Catalog.HOLE_FX["confetti"])["colors"]
	var p := CPUParticles2D.new()
	p.position = at
	p.emitting = true
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.1
	p.amount = 48 if fx_id != "firework" else 90
	p.spread = 180.0
	p.initial_velocity_min = 140.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 260) if fx_id == "confetti" else Vector2.ZERO
	p.damping_min = 30.0 if fx_id != "confetti" else 0.0
	p.damping_max = 90.0 if fx_id != "confetti" else 0.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(1.0, cols.size() - 1.0))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	p.color_initial_ramp = g
	p.z_index = 10
	return p
