class_name CourseBuilder3D
extends RefCounted
## Baut alle Bahnen des Spiels aus dem TrackKit-Baukasten:
## 15 Bahnen in 4 Welten + den taeglichen "Golden Shot"-Parcours.
##   Emerald Valley (e1-e5) · Volcano Canyon (v1-v4) · Cyber Neon City (n1-n3) · Pirate Cove (p1-p3)
## Aufruf: CourseBuilder3D.build("e1") -> Course3D (enthaelt Mesh, Kollision, Gadgets, Hindernisse, Umgebung).

const INFO := {
	"e1": {"title": "Erster Abschlag", "par": 2},
	"e2": {"title": "Windmühlen-Wiese", "par": 3},
	"e3": {"title": "Holzbrücke", "par": 3},
	"e4": {"title": "Wasserfall-Sprung", "par": 3},
	"e5": {"title": "Tal der Mühlen", "par": 4},
	"v1": {"title": "Lavasprung", "par": 3},
	"v2": {"title": "Schmelzofen", "par": 3},
	"v3": {"title": "Hammerwerk", "par": 4},
	"v4": {"title": "Vulkanschlund", "par": 4},
	"n1": {"title": "Neon-Looping", "par": 3},
	"n2": {"title": "Portalsprung", "par": 3},
	"n3": {"title": "Hyper-Schleife", "par": 4},
	"p1": {"title": "Planken-Pfad", "par": 3},
	"p2": {"title": "Kanonendeck", "par": 3},
	"p3": {"title": "Schwebende Ruinen", "par": 4},
	"daily": {"title": "Golden Shot", "par": 1},
}

static func course_title(course_id: String) -> String:
	if INFO.has(course_id):
		return str(INFO[course_id]["title"])
	return course_id

static func course_par(course_id: String) -> int:
	if INFO.has(course_id):
		return int(INFO[course_id]["par"])
	return 3

## Bahnen ohne Abkuerzung: e1 (gerade Einsteiger-Bahn, Par 2) und der Golden Shot (nur ein Schlag).
const NO_SHORTCUT: Array[String] = ["e1", "daily"]
const LANE_LEN := 7.0
const LANE_WIDTH := 2.0
const OPENING_LEN := 4.8
## Diagnose der letzten Abkuerzungs-Suche: Anzahl verworfener Kandidaten je Grund (fuer den Smoke-Test).
static var plan_stats: Dictionary = {}

## Baut eine Bahn. Fuer "daily" bestimmt `rng_seed` den Tages-Parcours.
## Abkuerzung: erst wird die Bahn probeweise gebaut und die beste Stelle fuer eine Bande-Oeffnung gesucht,
## dann wird sie mit Oeffnung, schmalem Steg, Felsentor, Sprungschanze und Landezone auf dem Gruen gebaut.
static func build(course_id: String, rng_seed: int = 0, with_environment: bool = true) -> Course3D:
	var id: String = course_id if INFO.has(course_id) else "e1"
	var plan: Dictionary = {}
	if not NO_SHORTCUT.has(id):
		var probe: Array = _assemble(id, rng_seed, [])
		plan = _plan_shortcut(probe[0], probe[1])
		(probe[0] as Course3D).free()
	var built: Array = _assemble(id, rng_seed, plan.get("openings", []))
	var c: Course3D = built[0]
	var k: TrackKit = built[1]
	var th: WorldTheme = built[2]
	if not plan.is_empty() and not k.built_openings.is_empty():
		_build_shortcut(c, k, th, plan)
	k.commit(th.materials)
	# Feine Putt-Ringe rund ums Loch
	var gm := th.materials[TrackKit.S_GREEN] as ShaderMaterial
	if gm != null:
		gm.set_shader_parameter("ring_center", Vector2(c.hole_pos.x, c.hole_pos.z))
		gm.set_shader_parameter("ring_strength", 0.5)
	_flag(c, th)
	th.dress_course(c, k.supports, with_environment)
	if with_environment:
		th.build_environment(c)
	return c

## Fuehrt das Bahn-Rezept aus (ohne Commit). Rueckgabe [Course3D, TrackKit, WorldTheme].
static func _assemble(id: String, rng_seed: int, openings: Array) -> Array:
	var c := Course3D.new()
	c.name = "Course_" + id
	c.course_id = id
	c.title = course_title(id)
	c.par = course_par(id)
	c.time_limit = 45.0 + 15.0 * float(c.par)
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	if id == "daily":
		c.world = Catalog.world_ids()[rng.randi_range(0, Catalog.WORLDS.size() - 1)]
	else:
		c.world = Catalog.world_of_course(id)
	var th := WorldTheme.create(c.world)
	var k := TrackKit.new(c)
	for o in openings:
		k.openings.append((o as Dictionary).duplicate())
	k.start(Transform3D.IDENTITY)
	match id:
		"e1":
			_e1(c, k, th)
		"e2":
			_e2(c, k, th)
		"e3":
			_e3(c, k, th)
		"e4":
			_e4(c, k, th)
		"e5":
			_e5(c, k, th)
		"v1":
			_v1(c, k, th)
		"v2":
			_v2(c, k, th)
		"v3":
			_v3(c, k, th)
		"v4":
			_v4(c, k, th)
		"n1":
			_n1(c, k, th)
		"n2":
			_n2(c, k, th)
		"n3":
			_n3(c, k, th)
		"p1":
			_p1(c, k, th)
		"p2":
			_p2(c, k, th)
		"p3":
			_p3(c, k, th)
		"daily":
			_daily(c, k, th, rng)
	return [c, k, th]

# ================================================================ Abkuerzung

## Sucht die Stelle fuer die Abkuerzung: ein gerades Stueck mit Bande, von dem aus ein Steg (7 m) und ein Sprung
## direkt zur Landezone auf dem Gruen fuehren. Bedingungen: der Hauptweg ist mindestens 12 m laenger,
## Steg und Flugbahn kreuzen keine anderen Bahnteile (Flug hoch genug ueber Banden/Hindernissen).
static func _plan_shortcut(c: Course3D, k: TrackKit) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = -INF
	var total: float = c.total_length()
	plan_stats = {"straights": k.straights.size()}
	# Landeziele: das Gruen (bevorzugt) oder ein spaeteres, beidseitig umbandetes Fairway-Stueck
	var targets: Array[Dictionary] = [{"green": true, "xf": k.green_xf, "size": k.green_size, "d": total, "zone": 3.0}]
	for t in k.straights:
		var txf: Transform3D = t["xf"]
		if float(t["dist"]) < 8.0 or float(t["length"]) < 6.0 or not bool(t["wall_l"]) or not bool(t["wall_r"]) or float(t["width"]) < 4.5 or txf.basis.y.y < 0.98:
			continue
		targets.append({"green": false, "xf": txf, "size": Vector2(float(t["width"]), float(t["length"])),
			"d": float(t["dist"]) + float(t["length"]) * 0.5, "zone": minf(2.2, float(t["width"]) * 0.5 - 0.3),
			"land": txf * Vector3(0.0, 0.0, -float(t["length"]) * 0.5)})
	# Belag-Proben in ein 4-m-Raster sortieren (schnelle Nachbarschafts-Abfragen)
	var grid: Dictionary = {}
	for i in c.surface_pts.size():
		var q: Vector3 = c.surface_pts[i]
		var key := Vector2i(int(floor(q.x / GRID_CELL)), int(floor(q.z / GRID_CELL)))
		if not grid.has(key):
			grid[key] = PackedInt32Array()
		var arr: PackedInt32Array = grid[key]
		arr.append(i)
		grid[key] = arr
	for st in k.straights:
		var length: float = float(st["length"])
		var xf0: Transform3D = st["xf"]
		if float(st["dist"]) < 1.0 or length < OPENING_LEN + 0.6 or xf0.basis.y.y < 0.98:
			continue
		var half: float = float(st["width"]) * 0.5
		for side: int in [-1, 1]:
			if (side < 0 and not bool(st["wall_l"])) or (side > 0 and not bool(st["wall_r"])):
				continue
			var u: float = OPENING_LEN * 0.5 + 0.2
			while u <= length - OPENING_LEN * 0.5 - 0.2:
				for lane_len: float in [7.0, 5.0, 9.5]:
					var cand: Dictionary = {}
					for tg in targets:
						var cnd: Dictionary = _eval_gate(c, k, grid, xf0, half, u, side, total, lane_len, tg)
						if not cnd.is_empty() and (cand.is_empty() or float(cnd["score"]) > float(cand["score"])):
							cand = cnd
					if not cand.is_empty() and float(cand["score"]) > best_score:
						best_score = float(cand["score"])
						cand["openings"] = [{"d0": float(st["dist"]) + u - OPENING_LEN * 0.5, "d1": float(st["dist"]) + u + OPENING_LEN * 0.5, "side": side}]
						best = cand
				u += 1.1
	return best

const GRID_CELL := 4.0

## Indizes der Belag-Proben in Rasterzellen, die die Strecke a-b (+ Rand) beruehren.
static func _near_samples(grid: Dictionary, a: Vector2, b: Vector2, margin: float) -> PackedInt32Array:
	var out := PackedInt32Array()
	var x0: int = int(floor((minf(a.x, b.x) - margin) / GRID_CELL))
	var x1: int = int(floor((maxf(a.x, b.x) + margin) / GRID_CELL))
	var z0: int = int(floor((minf(a.y, b.y) - margin) / GRID_CELL))
	var z1: int = int(floor((maxf(a.y, b.y) + margin) / GRID_CELL))
	for zi in range(z0, z1 + 1):
		for xi in range(x0, x1 + 1):
			var key := Vector2i(xi, zi)
			if grid.has(key):
				out.append_array(grid[key])
	return out

## Landepunkt auf dem Gruen: 2.2 m vor dem Loch, von der Abkuerzung aus gesehen; mit Abstand zu den Banden.
static func _landing_point(k: TrackKit, hole: Vector3, from: Vector3) -> Vector3:
	var inv: Transform3D = k.green_xf.affine_inverse()
	var gl: Vector3 = inv * from
	var hl: Vector3 = inv * hole
	var dl := Vector2(gl.x - hl.x, gl.z - hl.z)
	dl = dl.normalized() if dl.length() > 0.01 else Vector2(0.0, 1.0)
	var ll := Vector2(hl.x, hl.z) + dl * 2.2
	ll.x = clampf(ll.x, -k.green_size.x * 0.5 + 2.0, k.green_size.x * 0.5 - 2.0)
	ll.y = clampf(ll.y, -k.green_size.y + 2.0, -2.0)
	return k.green_xf * Vector3(ll.x, 0.0, ll.y)

static func _reject(reason: String) -> Dictionary:
	plan_stats[reason] = int(plan_stats.get(reason, 0)) + 1
	return {}

static func _eval_gate(c: Course3D, k: TrackKit, grid: Dictionary, xf0: Transform3D, half: float, u: float, side: int, total: float, lane_len: float, tg: Dictionary) -> Dictionary:
	var g: Vector3 = xf0 * Vector3(float(side) * half, 0.0, -u)
	var nrm: Vector3 = Vector3(xf0.basis.x.x, 0.0, xf0.basis.x.z).normalized() * float(side)
	var green: bool = bool(tg["green"])
	var land: Vector3 = _landing_point(k, c.hole_pos, g) if green else tg["land"]
	var rect_xf: Transform3D = tg["xf"]
	var rect_size: Vector2 = tg["size"]
	var flat := Vector3(land.x - g.x, 0.0, land.z - g.z)
	if flat.length() < 1.0:
		return {}
	var to_target: Vector3 = flat.normalized()
	# Steg zeigt moeglichst Richtung Ziel, aber immer deutlich von der Hauptbahn weg;
	# das Sprungpad am Ende schiesst den Ball dann in jede Richtung zum Ziel.
	var dir: Vector3 = to_target
	if to_target.dot(nrm) < 0.6:
		var tang: Vector3 = to_target - nrm * to_target.dot(nrm)
		if tang.length() < 0.001:
			dir = nrm
		else:
			dir = (nrm * 0.6 + tang.normalized() * 0.8).normalized()
	var lip: Vector3 = g + dir * lane_len
	var fly_vec := Vector3(land.x - lip.x, 0.0, land.z - lip.z)
	var fly: float = fly_vec.length()
	if fly < 1.0 or fly_vec.normalized().dot(dir) < 0.1:
		return _reject("winkel")
	var dist_h: float = lane_len + fly
	var dh: float = land.y - lip.y
	if fly < 6.0 or fly > 44.0:
		return _reject("flugweite")
	if dh < -16.0 or dh > 8.0:
		return _reject("hoehe")
	for bl in c.blockers:
		if Vector2(bl.x - g.x, bl.z - g.z).length() < 4.5:
			return _reject("hindernis")
	for bl in c.blockers:
		if Vector2(bl.x - land.x, bl.z - land.z).length() < 4.0:
			return _reject("ziel_hindernis")
	var gate_d: float = c.path_dist[c.nearest_path_index(g)]
	var remaining: float = float(tg["d"]) - gate_d
	if remaining < dist_h + (6.0 if green else 10.0):
		return _reject("ersparnis")
	var g2 := Vector2(g.x, g.z)
	var lip2 := Vector2(lip.x, lip.z)
	var land2 := Vector2(land.x, land.z)
	# Steg: kein anderer Bahnteil daneben
	for i in _near_samples(grid, g2, lip2, LANE_WIDTH * 0.5 + 1.4):
		var q: Vector3 = c.surface_pts[i]
		var q2 := Vector2(q.x, q.z)
		if q2.distance_to(g2) < 3.8:
			continue
		if _seg_dist(q2, g2, lip2) < LANE_WIDTH * 0.5 + 1.2:
			return _reject("steg")
	# Flug: niedrigster Abschusswinkel, der ueber alles hinweg reicht
	var inv: Transform3D = rect_xf.affine_inverse()
	var near_flight: PackedInt32Array = _near_samples(grid, lip2, land2, 3.6)
	for elev: float in [38.0, 46.0, 54.0, 62.0, 70.0]:
		var tn: float = tan(deg_to_rad(elev))
		if fly * tn < dh + 1.0:
			continue
		var clear := true
		for i in near_flight:
			var q: Vector3 = c.surface_pts[i]
			var q2 := Vector2(q.x, q.z)
			var ab: Vector2 = land2 - lip2
			var t: float = clampf((q2 - lip2).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
			if q2.distance_to(lip2 + ab * t) > 3.5:
				continue
			var arc_y: float = lip.y + t * fly * tn - t * t * (fly * tn - dh)
			var ql: Vector3 = inv * q
			var on_green: bool = absf(ql.x) <= rect_size.x * 0.5 + 0.1 and ql.z <= 0.1 and ql.z >= -rect_size.y - 0.1
			if on_green:
				# Im Landefeld zaehlen nur die Banden am Rand
				var edge: float = minf(rect_size.x * 0.5 - absf(ql.x), minf(-ql.z, rect_size.y + ql.z))
				if edge > 0.6:
					continue
			var need: float = q.y + (1.0 if on_green else 4.8)
			if arc_y < need:
				clear = false
				break
		if clear:
			var score: float = remaining - dist_h + dir.dot(nrm) * 4.0 - (elev - 38.0) * 0.15 - absf(lane_len - 7.0) * 0.5 + (12.0 if green else 0.0)
			return {"score": score, "landing": land, "elev": elev, "fly": fly, "lane": lane_len, "remaining": remaining, "direct": dist_h, "lane_dir": dir,
				"green": green, "zone": float(tg["zone"]), "target_d": float(tg["d"])}
	return _reject("flugbahn")

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Baut Steg, Felsentor, Schanze, Landezone und Schlucht-Korridor fuer die geplante Abkuerzung.
static func _build_shortcut(c: Course3D, k: TrackKit, th: WorldTheme, plan: Dictionary) -> void:
	var o: Dictionary = k.built_openings[0]
	var xf0: Transform3D = o["xf"]
	var side: int = int(o["side"])
	var half: float = float(o["width"]) * 0.5
	var g: Vector3 = xf0 * Vector3(float(side) * half, 0.0, -OPENING_LEN * 0.5)
	var land: Vector3 = plan["landing"]
	var dir: Vector3 = plan.get("lane_dir", Vector3(land.x - g.x, 0.0, land.z - g.z).normalized())
	var perp: Vector3 = dir.cross(Vector3.UP).normalized()
	var back_off: float = 2.6
	var start: Vector3 = g - dir * back_off + Vector3(0.0, -0.012, 0.0)
	# Steg (schmal, ohne Banden) - zaehlt nicht zur Mittellinie
	var saved: Dictionary = k.push_state()
	k.branch = true
	k.start(Transform3D(Basis.looking_at(dir, Vector3.UP), start))
	k.set_width(LANE_WIDTH)
	k.set_walls(false, false)
	k.set_surface(TrackKit.S_ALT)
	var lane_len: float = float(plan.get("lane", LANE_LEN))
	k.straight(back_off + lane_len)
	k.end_run()
	k.branch = false
	k.pop_state(saved)
	var lip: Vector3 = g + dir * lane_len
	var n_sup: int = int(lane_len / 2.5)
	for i in n_sup:
		k.supports.append(g + dir * (2.0 + 2.5 * float(i)))
	# Felsentor: zwei Felssaeulen (mit Kollision) + Querbalken, knapp breiter als der Steg
	# Tor so weit draussen, dass keine Saeule auf der Hauptbahn steht (schraeger Steg -> weiter hinaus)
	var nrm0: Vector3 = Vector3(xf0.basis.x.x, 0.0, xf0.basis.x.z).normalized() * float(side)
	var dn: float = clampf(dir.dot(nrm0), 0.3, 1.0)
	var gate_along: float = clampf((1.48 * sqrt(1.0 - dn * dn) + 0.7) / dn, 2.6, lane_len - 0.4)
	var gate_pos: Vector3 = g + dir * gate_along
	var rock_mat := Mat.flat({"volcano": Color(0.2, 0.15, 0.13), "pirate": Color(0.62, 0.55, 0.45), "neon": Color(0.16, 0.16, 0.24)}.get(th.id, Color(0.42, 0.4, 0.37)), 0.95)
	var body := StaticBody3D.new()
	body.name = "ShortcutGate"
	body.collision_layer = 1
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.0
	body.physics_material_override = pm
	for sgn: float in [-1.0, 1.0]:
		var p: Vector3 = gate_pos + perp * (sgn * (LANE_WIDTH * 0.5 + 0.48))
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = 0.45
		shape.height = 4.0
		cs.shape = shape
		cs.position = p + Vector3(0.0, 1.4, 0.0)
		body.add_child(cs)
		var rock := MeshInstance3D.new()
		rock.mesh = Flora.boulder()
		rock.material_override = rock_mat
		rock.scale = Vector3(0.62, 6.0, 0.62)
		rock.position = p + Vector3(0.0, -1.5, 0.0)
		body.add_child(rock)
	var lintel := MeshInstance3D.new()
	lintel.mesh = Flora.boulder()
	lintel.material_override = rock_mat
	lintel.basis = Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3((LANE_WIDTH + 2.6) * 0.5, 0.5, 0.6))
	lintel.position = gate_pos + Vector3(0.0, 3.5, 0.0)
	body.add_child(lintel)
	var sign := Label3D.new()
	sign.text = "ABKÜRZUNG"
	sign.font_size = 72
	sign.outline_size = 18
	sign.modulate = Color(1.0, 0.86, 0.25)
	sign.outline_modulate = Color(0.1, 0.06, 0.02)
	sign.pixel_size = 0.009
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = false
	sign.position = gate_pos + Vector3(0.0, 4.6, 0.0)
	body.add_child(sign)
	c.add_child(body)
	# Sprungschanze am Steg-Ende und Landezone auf dem Gruen
	# Schanze wirkt nur mitten auf dem Steg (wer am Rand entlangrollt, faellt vorher herunter)
	var launcher := Gadgets.Launcher.new(Vector3(LANE_WIDTH - 0.3, 2.0, 1.8), land, float(plan["elev"]), 3.0, th.boost_color)
	launcher.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), lip - dir * 0.9)
	var zone := Gadgets.LandingZone.new(float(plan.get("zone", 3.0)), th.boost_color)
	zone.transform = Transform3D(Basis.IDENTITY, land)
	launcher.catcher = zone
	c.add_gadget(launcher)
	c.add_gadget(zone)
	# Schlucht unter Steg und Flug (endet vor dem Gruen)
	var fly_dir := Vector3(land.x - lip.x, 0.0, land.z - lip.z)
	var fly_len: float = fly_dir.length()
	if fly_len > 10.0:
		c.add_corridor(lip, lip + fly_dir / fly_len * (fly_len - 8.0), 2.5, 7.5)
	var nrm: Vector3 = Vector3(xf0.basis.x.x, 0.0, xf0.basis.x.z).normalized() * float(side)
	c.shortcut = {"gate": g, "dir": dir, "normal": nrm, "lane_start": g + dir * 0.6, "lip": lip, "landing": land, "elev": float(plan["elev"]),
		"remaining": float(plan["remaining"]), "direct": float(plan["direct"]), "green": bool(plan.get("green", true)),
		"target_d": float(plan.get("target_d", c.total_length()))}

# ================================================================ Platzierungs-Helfer

## Boost-Pad, das genau an der aktuellen Turtle-Position endet (also auf dem zuletzt gebauten Stueck liegt).
static func _boost_here(c: Course3D, k: TrackKit, th: WorldTheme, target_speed: float, pad_length: float = 3.5) -> void:
	var pad := Gadgets.BoostPad.new(k.width - 0.6, pad_length, target_speed, th.boost_color)
	pad.transform = k.frame(Vector3(0.0, 0.0, pad_length * 0.5))
	c.add_gadget(pad)

static func _sand(c: Course3D, k: TrackKit, local: Vector3, size: Vector2, decel_factor: float = 4.5) -> void:
	var s := Gadgets.SandTrap.new(size, decel_factor)
	s.transform = k.frame(local)
	c.add_gadget(s)

static func _windmill(c: Course3D, k: TrackKit, ahead: float, speed: float = 1.4, phase: float = 0.0) -> void:
	var w := Obstacles.Windmill.new(speed, phase)
	w.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_obstacle(w)
	c.blockers.append(w.transform.origin)

static func _hammer(c: Course3D, k: TrackKit, ahead: float, period: float = 2.6, phase: float = 0.0) -> void:
	var h := Obstacles.Hammer.new(55.0, period, phase)
	h.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_obstacle(h)
	c.blockers.append(h.transform.origin)

static func _block(c: Course3D, k: TrackKit, ahead: float, period: float = 3.0, phase: float = 0.0) -> void:
	var b := Obstacles.SlidingBlock.new(Vector3(1.6, 1.4, 1.6), k.width * 0.5 - 0.9, period, phase)
	b.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_obstacle(b)
	c.blockers.append(b.transform.origin)

static func _laser(c: Course3D, k: TrackKit, th: WorldTheme, ahead: float, period: float, duty: float, phase: float) -> void:
	var l := Gadgets.LaserGate.new(k.width, period, duty, phase, Color(1.0, 0.15, 0.3) if th.id == "neon" else Color(1.0, 0.5, 0.1))
	l.course = c
	l.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_gadget(l)
	c.blockers.append(l.transform.origin)

## Tiefes Gras (Rough) am Rand: local = Mittelpunkt relativ zur Turtle, size = (quer, laengs).
static func _rough(c: Course3D, k: TrackKit, th: WorldTheme, local: Vector3, size: Vector2) -> void:
	var col: Color = Color(0.16, 0.4, 0.14)
	if th.id == "pirate":
		col = Color(0.2, 0.45, 0.16)
	var r := Gadgets.RoughZone.new(size, 2.3, col)
	r.transform = k.frame(local)
	c.add_gadget(r)

## Bach quer ueber die Bahn `ahead` Meter vor der Turtle, mit Holzsteg in der Mitte.
static func _creek(c: Course3D, k: TrackKit, ahead: float, bridge_width: float = 2.2) -> void:
	var cr := Gadgets.Creek.new(k.width, 1.4, bridge_width)
	cr.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_gadget(cr)
	for sgn: float in [-1.0, 1.0]:
		c.blockers.append(k.at(Vector3(sgn * k.width * 0.5, 0.0, -ahead)))

## Baumstamm von der Bande (side -1 links / +1 rechts) quer bis kurz vor die Bahnmitte.
static func _log(c: Course3D, k: TrackKit, ahead: float, side: float, dead: bool = false) -> void:
	var length: float = k.width * 0.5 - 0.5
	var lg := Obstacles.log_obstacle(length, 0.32, dead)
	lg.transform = k.frame(Vector3(side * (k.width * 0.5 - length * 0.5 + 0.1), 0.0, -ahead), side * 8.0)
	c.add_child(lg)
	c.blockers.append(k.at(Vector3(side * k.width * 0.5, 0.0, -ahead)))

## Felsbrocken an der Bande.
static func _rock(c: Course3D, k: TrackKit, th: WorldTheme, local: Vector3, radius: float) -> void:
	var tint := Color(0.55, 0.52, 0.48)
	if th.id == "volcano":
		tint = Color(0.24, 0.18, 0.16)
	elif th.id == "pirate":
		tint = Color(0.68, 0.6, 0.48)
	var b := Obstacles.boulder(radius, tint)
	b.transform = k.frame(local)
	c.add_child(b)
	c.blockers.append(k.at(local))

## Lianen-Bogen ueber der Bahn (rein optisch).
static func _vines(c: Course3D, k: TrackKit, ahead: float) -> void:
	var root := Node3D.new()
	root.name = "Vines"
	root.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	var wood := Mat.flat(Color(0.36, 0.24, 0.13), 0.9)
	var leaf := Mat.flat(Color(0.2, 0.52, 0.2), 0.9)
	var hw: float = k.width * 0.5 + TrackKit.WALL_T + 0.35
	for sgn: float in [-1.0, 1.0]:
		root.add_child(Mat.cylinder(0.17, 0.24, 4.4, wood, Vector3(sgn * hw, 1.6, 0.0), 8))
	var beam := Mat.cylinder(0.14, 0.14, hw * 2.0 + 0.6, wood, Vector3(0.0, 3.7, 0.0), 8)
	beam.rotation.z = PI * 0.5
	root.add_child(beam)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(k.dist) * 100.0)
	for i in 9:
		var x: float = lerpf(-hw + 0.4, hw - 0.4, float(i) / 8.0) + rng.randf_range(-0.15, 0.15)
		var vlen: float = rng.randf_range(0.9, 1.9)
		var vine := Mat.cylinder(0.025, 0.035, vlen, leaf, Vector3(x, 3.7 - vlen * 0.5, rng.randf_range(-0.1, 0.1)), 5)
		vine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(vine)
		for j in 3:
			var lf := Mat.sphere(0.11, leaf, Vector3(x + rng.randf_range(-0.06, 0.06), 3.7 - vlen * (0.25 + 0.3 * float(j)), 0.0), 6)
			lf.scale = Vector3(1.0, 0.5, 1.4)
			lf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(lf)
	c.add_child(root)

static func _post(c: Course3D, k: TrackKit, local: Vector3, radius: float, height: float, material: Material) -> void:
	var p := Obstacles.static_post(radius, height, material)
	p.transform = k.frame(local)
	c.add_child(p)

## Ventilator am linken (side = -1) oder rechten (side = +1) Rand, der quer ueber die Bahn blaest.
static func _fan(c: Course3D, k: TrackKit, ahead: float, side: float, reach: float, zone_width: float, accel: float) -> void:
	var f := Gadgets.WindZone.new(Vector3(zone_width, 3.0, reach), accel)
	f.transform = k.frame(Vector3(side * (k.width * 0.5 + 1.0), 0.0, -ahead), 90.0 * side)
	c.add_gadget(f)

## Looping inkl. Fuehrungsschiene.
static func _loop(c: Course3D, k: TrackKit, radius: float) -> void:
	var info: Dictionary = k.loop(radius)
	var rail := Gadgets.LoopRail.new(info)
	c.add_gadget(rail)

## Teleporter `back` Meter vor dem aktuellen Bahn-Ende (also auf dem zuletzt gebauten Stueck) mit Ausgang exit_xf.
static func _portal(c: Course3D, k: TrackKit, th: WorldTheme, back: float, exit_xf: Transform3D) -> void:
	var t := Gadgets.Teleporter.new(exit_xf, th.accent, th.boost_color)
	t.transform = k.frame(Vector3(0.0, 0.0, back))
	c.add_gadget(t)

## Kanone `back` Meter vor dem aktuellen Bahn-Ende, die auf `target` (Weltpunkt) schiesst.
static func _cannon(c: Course3D, k: TrackKit, back: float, target: Vector3, elevation: float = 55.0) -> void:
	var base: Vector3 = k.at(Vector3(0.0, 0.0, back))
	var v: Vector3 = Gadgets.ballistic_velocity(base + Vector3.UP * 0.9, target, elevation)
	var muzzle: Vector3 = base + Vector3.UP * 0.9 + v.normalized() * 2.4
	v = Gadgets.ballistic_velocity(muzzle, target, elevation)
	var cn := Gadgets.Cannon.new(v)
	cn.transform = Transform3D(Basis.IDENTITY, base)
	c.add_gadget(cn)
	# Unter der Flugbahn liegt eine Schlucht (das Gelaende darf den Flug nicht schneiden)
	c.add_corridor(base, target, 3.0)

static func _flag(c: Course3D, th: WorldTheme) -> void:
	var root := Node3D.new()
	root.name = "Flag"
	root.position = c.hole_pos
	root.add_child(Mat.cylinder(0.045, 0.045, 3.4, Mat.flat(Color(0.95, 0.95, 0.95), 0.4), Vector3(0.0, 1.7, 0.0), 8))
	root.add_child(Mat.vplane(Vector2(1.3, 0.8), Mat.shader("flag", {"color": Color(0.95, 0.15, 0.15) if th.id != "volcano" else Color(1.0, 0.85, 0.2)}), Vector3(0.67, 2.95, 0.0)))
	c.add_child(root)
	c.set_meta("flag", root)

# ================================================================ Welt 1: Emerald Valley

static func _e1(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(14.0)
	k.slope(8.0, 1.2)
	k.straight(3.0)
	_sand(c, k, Vector3(-1.5, 0.0, -1.5), Vector2(1.6, 2.2))
	k.straight(3.0)
	k.green(12.0, 9.0)

static func _e2(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(10.0)
	_windmill(c, k, 4.0, 1.3)
	_log(c, k, 8.5, -1.0)
	k.straight(12.0)
	k.turn(90.0, 7.0)
	k.straight(5.0)
	_sand(c, k, Vector3(1.3, 0.0, -3.0), Vector2(2.0, 3.0))
	k.straight(5.0)
	_rough(c, k, th, Vector3(-1.75, 0.0, -2.2), Vector2(1.4, 4.0))
	k.straight(3.0)
	k.green(12.0, 9.0)

static func _e3(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
	_creek(c, k, 9.5)
	k.straight(12.0)
	k.set_surface(TrackKit.S_ALT)
	k.hill(16.0, 2.4)
	k.set_surface(TrackKit.S_FLOOR)
	k.straight(4.0)
	k.turn(-90.0, 7.0)
	k.slope(10.0, -1.6)
	k.turn(-60.0, 8.0)
	_vines(c, k, 3.0)
	k.straight(6.0)
	k.green(12.0, 9.0, 8.0, 1.5)

static func _e4(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(9.0)
	_boost_here(c, k, th, 26.0)
	k.kicker(5.0, 16.0)
	k.gap(9.5, 0.6)
	k.set_width(7.0)
	k.set_wall_height(0.9)
	_rock(c, k, th, Vector3(2.7, 0.0, -7.0), 0.75)
	k.straight(12.0)
	k.taper(5.0, 5.0)
	k.turn(70.0, 9.0, 12.0)
	k.set_wall_height(TrackKit.WALL_H)
	k.straight(6.0)
	k.green(12.0, 9.0)

static func _e5(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	_rough(c, k, th, Vector3(1.75, 0.0, -3.5), Vector2(1.4, 4.5))
	k.straight(7.0)
	k.turn(-90.0, 7.0)
	k.slope(9.0, 1.5)
	_windmill(c, k, 5.0, 1.6, 0.8)
	k.straight(12.0)
	k.turn(90.0, 7.0, 10.0)
	k.set_surface(TrackKit.S_ALT)
	k.hill(12.0, 1.6)
	k.set_surface(TrackKit.S_FLOOR)
	k.set_walls(true, false)
	_fan(c, k, 5.5, -1.0, 7.5, 8.0, 6.0)
	k.straight(11.0)
	k.set_walls(true, true)
	k.turn(90.0, 7.0)
	k.straight(3.0)
	_sand(c, k, Vector3(-1.2, 0.0, -1.0), Vector2(1.8, 2.4))
	k.straight(3.0)
	k.green(12.0, 9.0, 7.0, -1.2)

# ================================================================ Welt 2: Volcano Canyon

static func _v1(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(8.0)
	_boost_here(c, k, th, 27.0)
	k.kicker(6.0, 20.0)
	k.gap(12.0, 1.0)
	k.set_width(7.0)
	k.set_wall_height(0.9)
	_rock(c, k, th, Vector3(-2.7, 0.0, -5.0), 0.8)
	_rock(c, k, th, Vector3(2.75, 0.0, -10.5), 0.7)
	k.straight(14.0)
	k.taper(4.0, 5.0)
	k.set_wall_height(TrackKit.WALL_H)
	# Knick nach rechts: die Abkuerzung springt quer ueber die Lava direkt aufs Gruen
	k.turn(-90.0, 7.0)
	_block(c, k, 4.5, 3.0)
	k.straight(9.0)
	k.green(12.0, 9.0)

static func _v2(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(6.0)
	k.slope(12.0, -3.0)
	k.set_wall_height(1.0)
	k.turn(-180.0, 8.0, 20.0)
	k.set_wall_height(TrackKit.WALL_H)
	k.straight(5.0)
	_boost_here(c, k, th, 26.0)
	k.slope(14.0, 3.5)
	_block(c, k, 3.5, 3.2, 0.0)
	_block(c, k, 8.5, 3.2, PI)
	k.straight(12.0)
	k.green(12.0, 9.0)

static func _v3(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	_log(c, k, 5.5, 1.0, true)
	k.straight(9.0)
	_hammer(c, k, 4.5, 2.6, 0.0)
	k.straight(9.0)
	_hammer(c, k, 4.5, 2.6, PI * 0.5)
	k.straight(9.0)
	k.turn(90.0, 7.0)
	k.set_walls(false, false)
	k.taper(3.0, 3.6)
	k.straight(12.0)
	k.taper(3.0, 5.0)
	k.set_walls(true, true)
	k.straight(4.0)
	_boost_here(c, k, th, 21.0, 3.0)
	k.kicker(4.0, 15.0)
	k.gap(6.0, 0.4)
	k.set_width(6.5)
	k.set_wall_height(0.9)
	k.straight(9.0)
	k.taper(3.0, 5.0)
	k.set_wall_height(TrackKit.WALL_H)
	k.turn(-90.0, 7.0)
	k.straight(4.0)
	k.green(12.0, 9.0)

static func _v4(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(6.0)
	_boost_here(c, k, th, 17.0, 3.0)
	k.set_wall_height(1.0)
	k.spiral(180.0, 9.0, -3.0, 16.0)
	_boost_here(c, k, th, 17.0, 3.0)
	k.spiral(180.0, 9.0, -3.0, 16.0)
	k.set_wall_height(TrackKit.WALL_H)
	k.straight(5.0)
	_boost_here(c, k, th, 27.0)
	k.kicker(5.0, 18.0)
	k.gap(11.0, 1.5)
	k.cross_wall(false, 0.5)
	k.set_wall_height(0.9)
	k.green(14.0, 11.0)

# ================================================================ Welt 3: Cyber Neon City

static func _n1(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(8.0)
	_boost_here(c, k, th, 27.0)
	k.straight(2.0)
	_loop(c, k, 4.0)
	k.straight(10.0)
	k.turn(90.0, 8.0)
	_laser(c, k, th, 5.0, 3.0, 0.5, 0.0)
	k.straight(10.0)
	k.green(12.0, 9.0)

static func _n2(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(12.0)
	k.turn(-45.0, 8.0)
	k.straight(6.0)
	# Zweite, hoehere Plattform - erreichbar nur durch das Portal
	var exit_xf := Transform3D(Basis.IDENTITY, Vector3(-8.0, 4.0, -31.0))
	_portal(c, k, th, 1.6, exit_xf)
	k.cross_wall(true, 1.6)
	k.start(Transform3D(Basis.IDENTITY, Vector3(-8.0, 4.0, -30.0)))
	k.cross_wall(false)
	k.straight(9.0)
	_laser(c, k, th, 3.0, 2.6, 0.5, 0.0)
	k.straight(7.0)
	_laser(c, k, th, 1.0, 2.6, 0.5, 1.3)
	k.straight(5.0)
	k.turn(-90.0, 7.0)
	k.straight(4.0)
	k.green(12.0, 9.0)

static func _n3(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(5.0)
	k.slope(8.0, -2.0)
	k.straight(3.0)
	_boost_here(c, k, th, 28.0, 3.0)
	k.straight(2.0)
	_loop(c, k, 4.0)
	# Bremsfeld: nach dem Looping ist der Ball sehr schnell (~27 m/s) - erst abbremsen, dann die Steilkurve
	_sand(c, k, Vector3(0.0, 0.0, -4.5), Vector2(k.width - 0.3, 8.0), 3.5)
	k.straight(9.0)
	# Steilkurve nach dem Looping: hohe Banden, damit schnelle Baelle nicht hinausfliegen
	k.set_wall_height(2.2)
	k.turn(180.0, 8.0, 22.0)
	k.set_wall_height(1.2)
	k.straight(6.0)
	k.set_wall_height(TrackKit.WALL_H)
	_boost_here(c, k, th, 26.0)
	k.kicker(5.0, 18.0)
	k.gap(11.0, 0.5)
	k.set_width(7.0)
	k.set_wall_height(0.9)
	k.set_surface(TrackKit.S_ALT)
	k.straight(6.0)
	# Trichter zum Portal
	k.taper(6.0, 2.6)
	# Portal am Ende der Plattform fuehrt zum schwebenden Ziel-Gruen
	var green_start := Transform3D(Basis.IDENTITY, Vector3(16.0, 5.0, -46.0))
	_portal(c, k, th, 1.6, green_start.translated_local(Vector3(0.0, 0.0, -1.0)))
	k.cross_wall(true, 1.6)
	k.set_width(TrackKit.WIDTH)
	k.set_surface(TrackKit.S_FLOOR)
	k.start(green_start)
	k.cross_wall(false)
	k.green(14.0, 11.0)

# ================================================================ Welt 4: Pirate Cove

static func _p1(c: Course3D, k: TrackKit, th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(6.0)
	k.set_walls(false, false)
	k.taper(3.0, 3.2)
	k.straight(12.0)
	k.turn(60.0, 9.0)
	k.straight(6.0)
	k.taper(3.0, 5.0)
	k.set_walls(true, true)
	_rough(c, k, th, Vector3(1.75, 0.0, -2.0), Vector2(1.4, 3.6))
	k.straight(4.0)
	var barrel := Mat.flat(Color(0.5, 0.3, 0.14), 0.9)
	_post(c, k, Vector3(-1.2, 0.0, -2.0), 0.55, 1.2, barrel)
	_post(c, k, Vector3(1.3, 0.0, -4.5), 0.55, 1.2, barrel)
	_post(c, k, Vector3(-0.6, 0.0, -6.6), 0.55, 1.2, barrel)
	k.straight(8.0)
	_vines(c, k, 1.5)
	k.slope(8.0, 1.5)
	k.green(12.0, 9.0)

static func _p2(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
	_creek(c, k, 6.5)
	k.straight(12.0)
	k.turn(-30.0, 10.0)
	k.straight(6.0)
	# Kanone schiesst den Ball auf die Sandbank der zweiten Insel
	var island: Transform3D = k.xf.translated_local(Vector3(0.0, 3.0, -36.0))
	var target: Vector3 = island * Vector3(0.0, 0.4, -5.0)
	_cannon(c, k, 2.2, target, 55.0)
	k.cross_wall(true, 1.2)
	k.start(island)
	k.set_width(8.0)
	k.set_wall_height(0.9)
	k.cross_wall(false)
	_sand(c, k, Vector3(0.0, 0.0, -5.5), Vector2(7.2, 9.0))
	k.straight(12.0)
	k.taper(4.0, 5.0)
	k.set_wall_height(TrackKit.WALL_H)
	k.turn(-90.0, 7.0)
	k.straight(4.0)
	k.green(12.0, 9.0)

static func _p3(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(7.0)
	# Faehr-Plattform ueber die Luecke
	var ferry := Obstacles.MovingPlatform.new(Vector3(5.0, 0.5, 5.0), Vector3(0.0, 0.0, -2.7), Vector3(0.0, 0.0, -9.3), 7.0)
	ferry.transform = k.frame()
	c.add_obstacle(ferry)
	k.gap(12.0)
	k.set_surface(TrackKit.S_ALT)
	k.straight(8.0)
	_hammer(c, k, 4.0, 3.0, 0.0)
	k.straight(8.0)
	k.turn(90.0, 7.0)
	k.straight(6.0)
	var island: Transform3D = k.xf.translated_local(Vector3(0.0, 4.0, -30.0))
	var target: Vector3 = island * Vector3(0.0, 0.4, -4.0)
	_cannon(c, k, 2.2, target, 58.0)
	k.cross_wall(true, 1.2)
	k.set_surface(TrackKit.S_FLOOR)
	k.start(island)
	k.set_wall_height(0.9)
	k.cross_wall(false)
	_sand(c, k, Vector3(0.0, 0.0, -4.0), Vector2(8.0, 6.5))
	k.green(15.0, 11.0, 11.0)

# ================================================================ Daily Challenge: Golden Shot

## Ein Schlag von einer hohen Plattform auf ein Insel-Gruen. Entfernung, Hoehe, Versatz und Wind haengen vom Tages-Seed ab.
static func _daily(c: Course3D, k: TrackKit, _th: WorldTheme, rng: RandomNumberGenerator) -> void:
	c.one_shot = true
	c.time_limit = 45.0
	var distance: float = rng.randf_range(20.0, 28.0)
	var drop: float = rng.randf_range(4.0, 8.0)
	var side: float = rng.randf_range(-6.0, 6.0)
	k.tee_box(5.0)
	k.straight(3.0)
	var wind_side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var wind := Gadgets.WindZone.new(Vector3(distance, 14.0, 16.0), rng.randf_range(2.0, 5.0))
	wind.transform = k.frame(Vector3(wind_side * 8.0, -drop, -distance * 0.5 - 2.0), 90.0 * wind_side)
	c.add_gadget(wind)
	k.gap(distance, drop, side)
	k.cross_wall(false, 0.5)
	k.set_wall_height(0.7)
	# Zielringe rund ums Loch
	var gl: float = 16.0
	var gw: float = 14.0
	for i in 3:
		var ring := Mat.torus(1.8 + 2.0 * float(i), 1.95 + 2.0 * float(i), Mat.glow(Color(1.0, 0.85, 0.2), 1.5),
			k.at(Vector3(0.0, 0.03, -gl * 0.5)))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.add_child(ring)
	k.green(gl, gw, gl * 0.5)
