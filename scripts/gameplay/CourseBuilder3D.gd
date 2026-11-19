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
## Hoechstens so viele Abkuerzungen pro Bahn (jede an einer eigenen Bande-Oeffnung).
const MAX_SHORTCUTS := 3
const LANE_LEN := 7.0
const LANE_WIDTH := 2.4
const OPENING_LEN := 5.4
## Rampe am Steg-Ende (TrackKit.kicker): Bogenlaenge und moegliche Absprungwinkel in Grad.
const KICK_LEN := 4.0
## (nicht zu steil: wer steil landet, springt beim Aufprall ueber die Bande des Ziels)
const KICK_ANGLES: Array[float] = [20.0, 27.0, 34.0, 40.0]
## Tempo-Klassen, gemessen am Tor (Einfahrt in den Steg), fuer den vorderen Rand des Landefensters, in m/s.
## Zum Vergleich: der Startschlaeger schafft bei voller Kraft rund 31 m/s, Schlaeger mit Schlagkraft 70 rund 35,
## die staerksten knapp 39 (Ball3D.MAX_SPEED * power_factor).
## Normale Abkuerzung: hoechstens V_EASY - mit jedem Schlaeger machbar (je knapper, desto naeher muss man ran).
## Power-Abkuerzung: V_POWER_MIN..V_POWER_MAX - vom Fairway aus (ein paar Meter vor dem Tor) reicht der
## Startschlaeger nicht, starke Schlaeger schaffen es.
const V_EASY := 29.5
## Hoechstes waagerechtes Lande-Tempo (m/s) fuer Rampen aufs Gruen.
const GREEN_MAX_VH := 21.0
## ... oder hoechstes senkrechtes Lande-Tempo (m/s): Abprall 0.45 -> der Ball springt dann weniger als 0.5 m hoch.
const GREEN_MAX_VY := 10.5
const V_POWER_MIN := 30.5
const V_POWER_MAX := 38.5
## Diagnose der letzten Abkuerzungs-Suche: Anzahl verworfener Kandidaten je Grund (fuer den Smoke-Test).
static var plan_stats: Dictionary = {}

## Baut eine Bahn. Fuer "daily" bestimmt `rng_seed` den Tages-Parcours.
## Abkuerzungen: erst wird die Bahn probeweise gebaut und nach Stellen fuer Bande-Oeffnungen gesucht (_plan_shortcuts),
## dann wird sie mit Oeffnungen gebaut, und an jede kommt ein schmaler Steg mit Rampe (_build_shortcut).
static func build(course_id: String, rng_seed: int = 0, with_environment: bool = true) -> Course3D:
	var id: String = course_id if INFO.has(course_id) else "e1"
	var plans: Array[Dictionary] = []
	if not NO_SHORTCUT.has(id):
		var probe: Array = _assemble(id, rng_seed, [])
		plans = _plan_shortcuts(probe[0], probe[1])
		(probe[0] as Course3D).free()
	var openings: Array = []
	for pl in plans:
		openings.append(pl["opening"])
	var built: Array = _assemble(id, rng_seed, openings)
	var c: Course3D = built[0]
	var k: TrackKit = built[1]
	var th: WorldTheme = built[2]
	for pl in plans:
		for o in k.built_openings:
			if absf(float(o.get("d0", -99.0)) - float(pl["opening"]["d0"])) < 0.01:
				_build_shortcut(c, k, th, pl, o)
				break
	k.commit(th.materials)
	# Feine Putt-Ringe rund ums Loch
	var gm := th.materials[TrackKit.S_GREEN] as ShaderMaterial
	if gm != null:
		gm.set_shader_parameter("ring_center", Vector2(c.hole_pos.x, c.hole_pos.z))
		gm.set_shader_parameter("ring_strength", 0.5)
	_flag(c, th)
	th.dress_course(c, k.supports, with_environment)
	# Natur mit Kollision am Bahnrand: immer (auch ohne Umgebung) und NUR aus der Bahn-ID (wie das Gelaende),
	# damit jedes Match, alle Mitspieler und die Tests exakt dieselbe Bahn spielen
	if id != "daily":
		_edge_nature(c, k, th, absi(hash(id + "|edge")))
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

# ================================================================ Abkuerzungen (Rampen)

## Sucht Stellen fuer Abkuerzungen: ein gerades Stueck mit Bande, von dem ein schmaler Steg ohne Banden zu einer Rampe
## fuehrt. Von der Rampe fliegt der Ball rein physikalisch weiter - geradeaus in Steg-Richtung -, also muss das Ziel
## (Gruen oder ein spaeteres, beidseitig umbandetes Fairway-Stueck) genau in dieser Richtung liegen. Wie weit der Ball
## fliegt, haengt nur vom Tempo ab, mit dem er die Rampe hinauffaehrt.
## Rueckgabe: bis zu MAX_SHORTCUTS Plaene (zuerst die beste normale, dann die beste Power-Abkuerzung, dann weitere).
static func _plan_shortcuts(c: Course3D, k: TrackKit) -> Array[Dictionary]:
	var total: float = c.total_length()
	plan_stats = {"straights": k.straights.size()}
	# Landeziele: das Gruen und spaetere, beidseitig umbandete, waagerechte Fairway-Stuecke
	# Je Ziel mehrere Zielpunkte (der Steg zeigt genau auf einen davon): Gruen = Loch, Mitte, vorderes Drittel;
	# Fairway-Stueck = Anfang, Mitte, Ende der Mittellinie
	var gxf: Transform3D = k.green_xf
	var targets: Array[Dictionary] = [{"green": true, "xf": gxf, "size": k.green_size, "d": total,
		"aims": [c.hole_pos, gxf * Vector3(0.0, 0.0, -k.green_size.y * 0.5), gxf * Vector3(0.0, 0.0, -k.green_size.y * 0.3)]}]
	for t in k.straights:
		var txf: Transform3D = t["xf"]
		if float(t["dist"]) < 8.0 or float(t["length"]) < 5.0 or not bool(t["wall_l"]) or not bool(t["wall_r"]) or float(t["width"]) < 4.0 or txf.basis.y.y < 0.98:
			continue
		var tl: float = float(t["length"])
		targets.append({"green": false, "xf": txf, "size": Vector2(float(t["width"]), tl), "d": float(t["dist"]) + tl * 0.5,
			"aims": [txf * Vector3(0.0, 0.0, -minf(2.5, tl * 0.3)), txf * Vector3(0.0, 0.0, -tl * 0.5), txf * Vector3(0.0, 0.0, -maxf(tl - 2.5, tl * 0.7))]})
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
	var cands: Array[Dictionary] = []
	for si in k.straights.size():
		var st: Dictionary = k.straights[si]
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
				# lange Stege kosten unterwegs viel Tempo -> dort reicht oft nur ein starker Schlaeger (Power-Rampe)
				for lane_len: float in [4.0, 6.0, 8.5, 14.0, 20.0]:
					for tg in targets:
						for cnd in _eval_ramp(c, grid, xf0, half, u, side, lane_len, tg):
							cnd["straight"] = si
							cnd["opening"] = {"d0": float(st["dist"]) + u - OPENING_LEN * 0.5, "d1": float(st["dist"]) + u + OPENING_LEN * 0.5, "side": side}
							cands.append(cnd)
				u += 1.1
	plan_stats["kandidaten"] = cands.size()
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x["score"]) > float(y["score"]))
	var out: Array[Dictionary] = []
	for want: String in ["easy", "power", ""]:
		for cd in cands:
			if out.size() >= MAX_SHORTCUTS:
				break
			if want != "" and str(cd["cls"]) != want:
				continue
			if _shortcut_fits(cd, out):
				out.append(cd)
				if want != "":
					break
	return out

## Vertraegt sich die Abkuerzung mit den schon gewaehlten? Oeffnungen auf derselben Seite eines geraden Stuecks
## ueberlappen nicht (1 m Abstand), Tore mindestens 4.5 m auseinander (links/rechts gegenueber geht),
## Steg + Flug mindestens 4 m von Steg + Flug der anderen entfernt.
static func _shortcut_fits(cd: Dictionary, chosen: Array[Dictionary]) -> bool:
	for o in chosen:
		if int(o["straight"]) == int(cd["straight"]):
			var oo: Dictionary = o["opening"]
			var co: Dictionary = cd["opening"]
			if int(oo["side"]) == int(co["side"]) and float(co["d0"]) < float(oo["d1"]) + 1.0 and float(co["d1"]) > float(oo["d0"]) - 1.0:
				return false
		var g1: Vector3 = cd["gate"]
		var g2: Vector3 = o["gate"]
		if Vector2(g1.x - g2.x, g1.z - g2.z).length() < 4.5:
			return false
		var segs1: Array = [[cd["gate"], cd["lip"]], [cd["lip"], cd["land_mid"]]]
		var segs2: Array = [[o["gate"], o["lip"]], [o["lip"], o["land_mid"]]]
		for s1: Array in segs1:
			for s2: Array in segs2:
				var a1: Vector3 = s1[0]
				var b1: Vector3 = s1[1]
				var a2: Vector3 = s2[0]
				var b2: Vector3 = s2[1]
				var pts: PackedVector2Array = Geometry2D.get_closest_points_between_segments(Vector2(a1.x, a1.z), Vector2(b1.x, b1.z),
					Vector2(a2.x, a2.z), Vector2(b2.x, b2.z))
				if pts[0].distance_to(pts[1]) < 4.0:
					return false
	return true

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

static func _reject(reason: String) -> Array[Dictionary]:
	plan_stats[reason] = int(plan_stats.get(reason, 0)) + 1
	return []

## Absprung-Tempo an der Rampenkante, um `d` Meter weiter und `dh` Meter hoeher (negativ: tiefer) zu landen
## (Winkel th in rad). Mit kleinem Aufschlag fuer den Luftwiderstand (Ball3D.AIR_DAMP). INF = unmoeglich.
static func takeoff_speed(d: float, dh: float, th: float) -> float:
	var denom: float = 2.0 * cos(th) * cos(th) * (d * tan(th) - dh)
	if denom <= 0.01:
		return INF
	var v: float = sqrt(Gadgets.gravity() * d * d / denom)
	var t: float = d / maxf(1.0, v * cos(th))
	return v * (1.0 + Ball3D.AIR_DAMP * t * 0.5)

## Tempo, mit dem der Ball am Tor in den Steg rollen muss, damit er mit v_lip von der Rampe abspringt:
## rueckwaerts ueber Rampe (Steigung waechst bis th) und Steg integriert, mit Rollwiderstand wie in Ball3D.
static func gate_speed(v_lip: float, lane_len: float, th: float) -> float:
	if v_lip == INF:
		return INF
	var g: float = Gadgets.gravity()
	var v: float = v_lip
	var n := 16
	var ds: float = KICK_LEN / float(n)
	for i in n:
		var phi: float = th * (1.0 - (float(i) + 0.5) / float(n))
		v = sqrt(v * v + 2.0 * (Ball3D.ROLL_DECEL + Ball3D.ROLL_DAMP * v + g * sin(phi)) * ds)
	ds = lane_len / float(n)
	for i in n:
		v = sqrt(v * v + 2.0 * (Ball3D.ROLL_DECEL + Ball3D.ROLL_DAMP * v) * ds)
	return v

## Schlagkraft-Wert (0..100), mit dem ein Ball bei voller Kraft direkt am Tor `v_gate` erreicht.
static func power_needed(v_gate: float) -> int:
	var factor: float = v_gate / Ball3D.MAX_SPEED
	return clampi(int(ceil((factor - 0.85) / 0.45 * 100.0)), 0, 100)

## Bewertet eine Abkuerzung: Tor an Position u des geraden Stuecks, Steg lane_len, Ziel tg. Probiert die Rampenwinkel
## durch und liefert die beste normale und die beste Power-Variante (je hoechstens eine).
static func _eval_ramp(c: Course3D, grid: Dictionary, xf0: Transform3D, half: float, u: float, side: int, lane_len: float, tg: Dictionary) -> Array[Dictionary]:
	var g: Vector3 = xf0 * Vector3(float(side) * half, 0.0, -u)
	var nrm: Vector3 = Vector3(xf0.basis.x.x, 0.0, xf0.basis.x.z).normalized() * float(side)
	var green: bool = bool(tg["green"])
	for bl in c.blockers:
		if Vector2(bl.x - g.x, bl.z - g.z).length() < 3.0:
			return _reject("hindernis")
	var gate_d: float = c.path_dist[c.nearest_path_index(g)]
	var remaining: float = float(tg["d"]) - gate_d
	if remaining < lane_len + KICK_LEN + 8.0:
		return _reject("ersparnis")
	var fwd_t: Vector3 = -rect_fwd(tg["xf"])
	var g2 := Vector2(g.x, g.z)
	var rect_xf: Transform3D = tg["xf"]
	var rect_size: Vector2 = tg["size"]
	var inv: Transform3D = rect_xf.affine_inverse()
	var by_cls: Dictionary = {}
	for aim: Vector3 in tg["aims"]:
		var flat := Vector3(aim.x - g.x, 0.0, aim.z - g.z)
		if flat.length() < 6.0:
			_stat("nah")
			continue
		var dir: Vector3 = flat.normalized()
		# Steg muss deutlich von der Hauptbahn weg zeigen (und schraeg noch durch die Oeffnung passen);
		# das Felsentor muss auf dem Steg stehen, nicht auf der Hauptbahn
		if dir.dot(nrm) < 0.48:
			_stat("winkel")
			continue
		if gate_along(dir.dot(nrm)) > lane_len - 0.4:
			_stat("tor")
			continue
		var lane_end: Vector3 = g + dir * lane_len
		# Steg + Rampe: kein anderer Bahnteil daneben
		var ramp_end2 := Vector2(lane_end.x, lane_end.z) + Vector2(dir.x, dir.z) * KICK_LEN
		var lane_free := true
		for i in _near_samples(grid, g2, ramp_end2, LANE_WIDTH * 0.5 + 1.4):
			var q: Vector3 = c.surface_pts[i]
			var q2 := Vector2(q.x, q.z)
			if q2.distance_to(g2) < 3.8:
				continue
			if _seg_dist(q2, g2, ramp_end2) < LANE_WIDTH * 0.5 + 1.2:
				lane_free = false
				break
		if not lane_free:
			_stat("steg")
			continue
		for kick_deg: float in KICK_ANGLES:
			var th: float = deg_to_rad(kick_deg)
			var rr: float = KICK_LEN / th
			var lip: Vector3 = lane_end + dir * (rr * sin(th)) + Vector3.UP * (rr * (1.0 - cos(th)))
			# Landefenster: Abschnitt der Fluglinie, der im Ziel liegt (1 m Abstand zu den Banden)
			var s_in := -1.0
			var s_out := -1.0
			var sd := 2.0
			while sd <= 46.0:
				var pt: Vector3 = lip + dir * sd
				var ql: Vector3 = inv * Vector3(pt.x, rect_xf.origin.y, pt.z)
				var inside: bool = absf(ql.x) <= rect_size.x * 0.5 - 1.0 and ql.z <= -1.0 and ql.z >= -rect_size.y + 1.0
				if inside:
					if s_in < 0.0:
						s_in = sd
					s_out = sd
				elif s_in >= 0.0:
					break
				sd += 0.5
			# Landefenster nicht zu knapp (sonst klappt es nur mit genau einem Tempo)
			if s_in < 0.0 or s_out - s_in < 3.0:
				_stat("ziel")
				continue
			var d_near: float = s_in + 0.5
			var d_mid: float = (s_in + s_out) * 0.5
			var dh: float = rect_xf.origin.y - lip.y
			var v_lip_mid: float = takeoff_speed(d_mid, dh, th)
			var v_near: float = gate_speed(takeoff_speed(d_near, dh, th), lane_len, th)
			var v_mid: float = gate_speed(v_lip_mid, lane_len, th)
			# Gruen ist klein und rundum umbandet: Der Ball darf entweder nicht zu schnell ankommen oder muss so flach
			# landen, dass er niedrig abprallt (dann haelt ihn die Bande; flache, schnelle Spruenge = Power-Rampen)
			if green and v_lip_mid * cos(th) > GREEN_MAX_VH and v_lip_mid * sin(th) > GREEN_MAX_VY:
				_stat("landung")
				continue
			var cls := ""
			if v_near <= V_EASY:
				cls = "easy"
			elif v_near >= V_POWER_MIN and v_near <= V_POWER_MAX:
				cls = "power"
			else:
				_stat("tempo")
				continue
			if not _flight_clear(c, grid, lip, dir, d_near, dh, th, inv, rect_size) or not _flight_clear(c, grid, lip, dir, d_mid, dh, th, inv, rect_size):
				_stat("flugbahn")
				continue
			var direct: float = lane_len + KICK_LEN + d_mid
			var saving: float = remaining - direct
			if saving < (5.0 if green else 6.0):
				_stat("ersparnis")
				continue
			# lieber in Fahrtrichtung des Ziels landen (der Ball rollt dann weiter Richtung Loch)
			var score: float = saving + dir.dot(nrm) * 3.0 - absf(lane_len - 6.0) * 0.5 + (4.0 if green else 0.0) + dir.dot(fwd_t) * 5.0 \
				+ (s_out - s_in) * 0.6
			if by_cls.has(cls) and float((by_cls[cls] as Dictionary)["score"]) >= score:
				continue
			var land_y: float = rect_xf.origin.y
			by_cls[cls] = {"score": score, "cls": cls, "gate": g, "lip": lip, "lane": lane_len, "lane_dir": dir, "kick_deg": kick_deg,
				"land_mid": Vector3(lip.x, land_y, lip.z) + dir * d_mid, "land_near": Vector3(lip.x, land_y, lip.z) + dir * d_near,
				"land_far": Vector3(lip.x, land_y, lip.z) + dir * (s_out - 0.5), "d_mid": d_mid, "v_near": v_near, "v_mid": v_mid,
				"remaining": remaining, "direct": direct, "green": green, "target_d": float(tg["d"]), "gate_d": gate_d}
	var out: Array[Dictionary] = []
	for key in by_cls.keys():
		out.append(by_cls[key])
	return out

## Wie weit hinter dem Tor das Felsentor steht (m), damit keine Saeule auf der Hauptbahn steht
## (dn = Kosinus zwischen Steg-Richtung und Banden-Normale; schraeger Steg -> weiter hinaus).
static func gate_along(dn: float) -> float:
	var d: float = clampf(dn, 0.3, 1.0)
	return maxf(2.6, (1.68 * sqrt(1.0 - d * d) + 0.7) / d)

## Waagerechte Rueckwaerts-Richtung (+z) eines Ziel-Rechtecks (die Bahn laeuft in -z).
static func rect_fwd(xf: Transform3D) -> Vector3:
	var z: Vector3 = xf.basis.z
	return Vector3(z.x, 0.0, z.z).normalized()

static func _stat(reason: String) -> void:
	plan_stats[reason] = int(plan_stats.get(reason, 0)) + 1

## Fliegt der Ball (Abschuss unter th von der Kante lip, Landung nach d Metern dh tiefer/hoeher) frei? Ueber anderen
## Bahnteilen braucht er Abstand zu den Banden, im Ziel nur ueber den Rand-Banden.
static func _flight_clear(c: Course3D, grid: Dictionary, lip: Vector3, dir: Vector3, d: float, dh: float, th: float, inv: Transform3D, rect_size: Vector2) -> bool:
	var lip2 := Vector2(lip.x, lip.z)
	var land2: Vector2 = lip2 + Vector2(dir.x, dir.z) * d
	var tn: float = tan(th)
	for i in _near_samples(grid, lip2, land2, 3.6):
		var q: Vector3 = c.surface_pts[i]
		var q2 := Vector2(q.x, q.z)
		var ab: Vector2 = land2 - lip2
		var t: float = (q2 - lip2).dot(ab) / maxf(0.0001, ab.length_squared())
		if t < 0.0 or t > 1.0:
			continue
		if q2.distance_to(lip2 + ab * t) > 3.0:
			continue
		var x: float = t * d
		var arc_y: float = lip.y + x * tn - t * t * (d * tn - dh)
		var ql: Vector3 = inv * q
		var on_target: bool = absf(ql.x) <= rect_size.x * 0.5 + 0.1 and ql.z <= 0.1 and ql.z >= -rect_size.y - 0.1
		if on_target:
			var edge: float = minf(rect_size.x * 0.5 - absf(ql.x), minf(-ql.z, rect_size.y + ql.z))
			if edge > 0.6:
				continue
		# Ballmitte ~0.3 ueber der Bogenlinie: am Ziel-Rand ueber die Bande (0.55), sonst mit etwas mehr Luft
		if arc_y < q.y + (0.75 if on_target else 1.0):
			return false
	return true

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab: Vector2 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)

## Baut Steg, Rampe, Felsentor und die Schlucht unter dem Flug fuer eine geplante Abkuerzung.
static func _build_shortcut(c: Course3D, k: TrackKit, th: WorldTheme, plan: Dictionary, o: Dictionary) -> void:
	var xf0: Transform3D = o["xf"]
	var side: int = int(o["side"])
	var half: float = float(o["width"]) * 0.5
	var g: Vector3 = xf0 * Vector3(float(side) * half, 0.0, -OPENING_LEN * 0.5)
	var dir: Vector3 = plan["lane_dir"]
	var perp: Vector3 = dir.cross(Vector3.UP).normalized()
	var back_off: float = 2.6
	var start: Vector3 = g - dir * back_off + Vector3(0.0, -0.012, 0.0)
	var lane_len: float = float(plan.get("lane", LANE_LEN))
	var kick_deg: float = float(plan["kick_deg"])
	# Steg (schmal, ohne Banden) und Rampe - zaehlen nicht zur Mittellinie
	var saved: Dictionary = k.push_state()
	k.branch = true
	k.start(Transform3D(Basis.looking_at(dir, Vector3.UP), start))
	k.set_width(LANE_WIDTH)
	k.set_walls(false, false)
	k.set_surface(TrackKit.S_ALT)
	k.straight(back_off + lane_len)
	k.arc_step_deg = 1.0
	k.kicker(KICK_LEN, kick_deg)
	k.arc_step_deg = 3.0
	var lip: Vector3 = k.xf.origin
	k.cap_without_collision = true
	k.end_run()
	k.cap_without_collision = false
	k.branch = false
	k.pop_state(saved)
	var n_sup: int = int((lane_len + KICK_LEN) / 2.5)
	for i in n_sup:
		k.supports.append(g + dir * (2.0 + 2.5 * float(i)))
	var power: bool = str(plan["cls"]) == "power"
	_gate_arch(c, th, g, dir, perp, xf0, side, lane_len, power)
	# Kante der Rampe markieren (nur Erkennung, kein Boost)
	var tag := Gadgets.RampTag.new(LANE_WIDTH)
	tag.transform = Transform3D(Basis.looking_at(dir, Vector3.UP), lip)
	c.add_gadget(tag)
	# Schlucht unter dem ganzen Flug bis kurz vor den Rand des Ziels (sonst steht dort Gelaende im Weg)
	var d_mid: float = float(plan["d_mid"])
	var near_flat := Vector3((plan["land_near"] as Vector3).x, lip.y, (plan["land_near"] as Vector3).z)
	var reach_len: float = lip.distance_to(near_flat) - 1.6
	if reach_len > 1.0:
		c.add_corridor(lip, lip + dir * reach_len, 2.5, 7.5)
	var nrm: Vector3 = Vector3(xf0.basis.x.x, 0.0, xf0.basis.x.z).normalized() * float(side)
	var land_y: float = (plan["land_mid"] as Vector3).y
	var flat_lip := Vector3(lip.x, land_y, lip.z)
	# Bereitstellung: Punkt auf der Hauptbahn in Verlaengerung des Stegs - von dort geht es geradeaus ueber Steg und Rampe
	var stage: Vector3 = g - dir * 2.0 + Vector3.UP * TrackKit.BALL_R
	c.shortcuts.append({"gate": g, "gate_d": float(plan["gate_d"]), "dir": dir, "normal": nrm, "lane_start": g + dir * 0.6, "lip": lip, "stage": stage,
		"landing": flat_lip + dir * d_mid, "land_near": plan["land_near"], "land_far": plan["land_far"], "kick_deg": kick_deg,
		"v_gate": float(plan["v_mid"]), "v_gate_min": float(plan["v_near"]), "power": power, "need_power": power_needed(float(plan["v_near"])),
		"remaining": float(plan["remaining"]), "direct": float(plan["direct"]), "green": bool(plan["green"]), "target_d": float(plan["target_d"])})

## Felsentor am Steg-Anfang (zwei Saeulen mit Kollision + Querbalken). Power-Abkuerzungen erkennt man an
## gluehenden roten Baendern - ohne Schrift.
static func _gate_arch(c: Course3D, th: WorldTheme, g: Vector3, dir: Vector3, perp: Vector3, xf0: Transform3D, side: int, lane_len: float, power: bool) -> void:
	# Tor so weit draussen, dass keine Saeule auf der Hauptbahn steht (schraeger Steg -> weiter hinaus)
	var nrm0: Vector3 = Vector3(xf0.basis.x.x, 0.0, xf0.basis.x.z).normalized() * float(side)
	var gate_pos: Vector3 = g + dir * minf(gate_along(dir.dot(nrm0)), lane_len - 0.4)
	var rock_mat := Flora.stone_material({"volcano": Color(0.2, 0.15, 0.13), "pirate": Color(0.62, 0.55, 0.45), "neon": Color(0.16, 0.16, 0.24)}.get(th.id, Color(0.42, 0.4, 0.37)),
		float(th.land.get("moss", 0.0)))
	var body := StaticBody3D.new()
	body.name = "ShortcutGate"
	body.collision_layer = 1
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.3
	pm.friction = 0.0
	body.physics_material_override = pm
	var glow := Mat.glow(Color(1.0, 0.25, 0.12), 2.4)
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
		if power:
			for hgt: float in [1.2, 2.2]:
				var band := Mat.torus(0.62, 0.74, glow, p + Vector3(0.0, hgt, 0.0))
				band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				body.add_child(band)
	var lintel := MeshInstance3D.new()
	lintel.mesh = Flora.boulder()
	lintel.material_override = rock_mat
	lintel.basis = Basis.looking_at(dir, Vector3.UP) * Basis.from_scale(Vector3((LANE_WIDTH + 2.6) * 0.5, 0.5, 0.6))
	lintel.position = gate_pos + Vector3(0.0, 3.5, 0.0)
	body.add_child(lintel)
	if power:
		var strip := Mat.box(Vector3(LANE_WIDTH + 1.6, 0.16, 0.16), glow)
		strip.basis = Basis.looking_at(dir, Vector3.UP)
		strip.position = gate_pos + Vector3(0.0, 3.05, 0.0) - dir * 0.55
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(strip)
	c.add_child(body)

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
	var b := Obstacles.boulder(radius, tint, float(th.land.get("moss", 0.0)))
	b.transform = k.frame(local)
	c.add_child(b)
	c.blockers.append(k.at(local))

# ================================================================ Natur am Bahnrand

## Max. Anzahl je Bahn
const EDGE_TREES := 6
const EDGE_ROOTS := 2
const EDGE_ROCKS := 2
## Mindestanteil der Randbaeume mit Ast ueber der Bahn
const BRANCH_SHARE := 0.4
## Unterkante der Aeste ueber dem Belag (rollende Baelle passen immer drunter durch)
const BRANCH_CLEAR := 2.55

## Diagnose der letzten Rand-Natur-Platzierung: verworfene Stellen je Grund (fuer den Smoke-Test).
static var edge_stats: Dictionary = {}

## Randbaeume (ein Teil mit dickem Ast quer ueber die Bahn), Wurzeln und Felsen, die von der Bande in die Bahn ragen.
## Platziert auf geraden Stuecken der Hauptbahn; frei bleiben Abschlag, Gruen, Abkuerzung (Oeffnung, Tor, Flug),
## Fluege ueber Luecken/Kanonen (Korridore), Gadgets und bestehende Hindernisse.
static func _edge_nature(c: Course3D, k: TrackKit, th: WorldTheme, nature_seed: int) -> void:
	if th.id == "neon":
		return
	edge_stats = {}
	var rng := RandomNumberGenerator.new()
	rng.seed = nature_seed
	var kind: String = {"volcano": "dead", "pirate": "jungle"}.get(th.id, "broadleaf")
	var moss: float = float(th.land.get("moss", 0.0))
	var easy: bool = c.course_id == "e1"
	# Lange Par-4-Bahnen sind schon schwer genug: dort nur Randbaeume (mit Ast), keine Wurzeln/Felsen auf der Bahn
	var trees_only: bool = easy or c.par >= 4
	var avoid: Array[Vector3] = []
	for g in c.gadgets:
		if g.get_parent() == c and not (g is Gadgets.TerrainBounds):
			avoid.append(g.position)
	for p in c.blockers:
		avoid.append(p)
	# bewegliche Hindernisse (Windmuehle, Hammer, Faehre) mit mehr Abstand
	var movers: Array[Vector3] = []
	for o in c.obstacles:
		if o is Node3D:
			movers.append((o as Node3D).position)
	var trees := 0
	var branches := 0
	var roots := 0
	var rocks := 0
	var cycle: Array[String] = ["tree", "rock", "tree", "root", "tree", "tree", "rock", "root", "tree", "tree"]
	var turn := 0
	var flip := 1.0
	var next_d: float = -INF
	for fr: Dictionary in k.edge_frames:
		var d_along: float = float(fr["dist"])
		if d_along < next_d:
			continue
		var xf: Transform3D = fr["xf"]
		var half: float = float(fr["half"])
		# nur ebene Querschnitte (keine Steilkurven/Loopings): Belag quer zur Bahn waagerecht
		if absf(xf.basis.x.normalized().y) > 0.08 or xf.basis.y.normalized().y < 0.9:
			_edge_stat("schraeg")
			next_d = d_along + 1.0
			continue
		# Seiten abwechseln (beide Bahnraender bekommen Natur)
		flip = -flip
		var side: float = flip
		if not bool(fr["wall_l" if side < 0.0 else "wall_r"]):
			side = -side
		if not bool(fr["wall_l" if side < 0.0 else "wall_r"]):
			_edge_stat("ohne_bande")
			next_d = d_along + 1.5
			continue
		var center: Vector3 = xf.origin
		var edge: Vector3 = xf * Vector3(side * half, 0.0, 0.0)
		var what: String = cycle[turn % cycle.size()]
		if trees_only and what != "tree":
			what = "tree"
		if (what == "root" and roots >= EDGE_ROOTS) or (what == "rock" and rocks >= EDGE_ROCKS):
			what = "tree"
		if what == "tree" and trees >= EDGE_TREES:
			what = "root" if roots < EDGE_ROOTS and not trees_only else ("rock" if rocks < EDGE_ROCKS and not trees_only else "")
		if what == "":
			break
		var why: String = _edge_blocked(c, center, edge, avoid, movers, what != "tree")
		if why != "":
			_edge_stat(why)
			next_d = d_along + 1.5
			continue
		turn += 1
		# Rahmen am Bahnrand: +X zeigt in die Bahn, Z entlang der Bahn
		var inward: Vector3 = (center - edge).normalized()
		var along: Vector3 = -xf.basis.z.normalized()
		var up: Vector3 = inward.cross(along).normalized() * -1.0
		if up.y < 0.0:
			up = -up
		var frame_b := Basis(inward, up, inward.cross(up).normalized())
		if what == "tree":
			var base: Vector3 = edge - inward * (TrackKit.WALL_T + 1.55)
			var ground: float = c.ground_height(base.x, base.z)
			if ground == -INF or ground < edge.y - 9.0 or ground > edge.y + 0.5:
				_edge_stat("gelaende")
				next_d = d_along + 1.5
				continue
			# Hoehen im Baum-Raum (Ursprung = Stammfuss, 0.15 m eingegraben): Belag liegt bei floor_l
			var drop: float = edge.y - ground
			var floor_l: float = drop + 0.15
			var want_branch: bool = float(branches) < BRANCH_SHARE * float(trees + 1) or rng.randf() < 0.35
			# kein Ast ueber Rampen/steilen Stuecken (dort koennte der Ball abheben)
			want_branch = want_branch and absf(xf.basis.z.normalized().y) < 0.1
			var reach: float = 0.0
			var attach_h: float = floor_l + BRANCH_CLEAR + 0.9
			# Ast-Ende: Unterkante der Kollisions-Kapsel (Radius 0.17) genau BRANCH_CLEAR ueber dem Belag
			var end_h: float = floor_l + BRANCH_CLEAR + 0.17
			if want_branch:
				var near_all: Array[Vector3] = avoid.duplicate()
				near_all.append_array(movers)
				# erst ein Ast ueber die ganze Bahn, sonst ein kuerzerer bis knapp vor die Mitte
				reach = 0.0
				for frac: float in ([1.25, 0.75] if not easy else [0.7]):
					var try_reach: float = TrackKit.WALL_T + 1.55 + half * frac
					var tip: Vector3 = base + inward * try_reach
					if _floor_below(c, tip, edge.y) and _branch_free(c, base + Vector3.UP * BRANCH_CLEAR, tip + Vector3.UP * BRANCH_CLEAR, near_all):
						reach = try_reach
						break
				if reach <= 0.0:
					_edge_stat("ast_frei")
			# Quote halten: ein Baum ohne Ast nur, wenn danach noch >= BRANCH_SHARE der Randbaeume einen Ast haben
			if reach <= 0.0 and float(branches) < BRANCH_SHARE * float(trees + 1):
				_edge_stat("quote")
				next_d = d_along + 1.5
				continue
			var trunk_h: float = floor_l + (BRANCH_CLEAR + 2.0 if reach > 0.0 else rng.randf_range(3.4, 4.6))
			var tree := Obstacles.edge_tree(kind, trunk_h, reach, attach_h, end_h, trees + nature_seed % 7, moss)
			tree.transform = Transform3D(Basis(Vector3.UP, atan2(-inward.z, inward.x)), Vector3(base.x, ground - 0.15, base.z))
			c.add_child(tree)
			if reach > 0.0 and kind != "dead":
				_lianas(tree, reach, attach_h, end_h, floor_l, rng)
			trees += 1
			if reach > 0.0:
				branches += 1
			c.edge_items.append({"kind": "tree", "pos": tree.position, "branch": reach > 0.0,
				"clearance": end_h - floor_l - 0.17 if reach > 0.0 else 0.0, "reach": reach,
				"tip": tree.transform * Vector3(reach, end_h, 0.0), "floor_y": edge.y})
		elif what == "root":
			var protrude: float = rng.randf_range(0.6, 0.95)
			var length_r: float = TrackKit.WALL_T + 1.0 + protrude
			var root := Obstacles.root_obstacle(length_r, roots)
			var start: Vector3 = edge - inward * (TrackKit.WALL_T + 1.0)
			root.transform = Transform3D(frame_b, start)
			c.add_child(root)
			roots += 1
			c.edge_items.append({"kind": "root", "pos": edge + inward * protrude, "branch": false, "clearance": 0.0})
		else:
			var r: float = rng.randf_range(0.55, 0.75)
			var tint := Color(0.55, 0.52, 0.48)
			if th.id == "volcano":
				tint = Color(0.24, 0.18, 0.16)
			elif th.id == "pirate":
				tint = Color(0.68, 0.6, 0.48)
			var rock := Obstacles.boulder(r, tint, moss)
			rock.transform = Transform3D(frame_b, edge - inward * 0.2)
			c.add_child(rock)
			rocks += 1
			c.edge_items.append({"kind": "rock", "pos": rock.position, "branch": false, "clearance": 0.0})
		avoid.append(edge)
		next_d = d_along + rng.randf_range(4.0, 6.0)

static func _edge_stat(reason: String) -> void:
	edge_stats[reason] = int(edge_stats.get(reason, 0)) + 1

## Grund, warum die Stelle nicht frei ist ("" = frei): Abschlag, Loch, Abkuerzung, Gadgets/Hindernisse, bewegliche
## Hindernisse; Dinge AUF der Bahn (Wurzel, Fels) zusaetzlich nicht unter Fluegen/Spruengen (Korridore).
static func _edge_blocked(c: Course3D, center: Vector3, edge: Vector3, avoid: Array[Vector3], movers: Array[Vector3], on_track: bool) -> String:
	if center.distance_to(c.tee.origin) < 5.0:
		return "abschlag"
	if center.distance_to(c.hole_pos) < 6.5:
		return "loch"
	for p in avoid:
		if p.distance_to(edge) < 3.2 or p.distance_to(center) < 3.2:
			return "hindernis"
	for p in movers:
		if Vector2(p.x - center.x, p.z - center.z).length() < (7.0 if on_track else 4.5):
			return "beweglich"
	for sc in c.shortcuts:
		for key in ["gate", "lane_start", "lip"]:
			if (sc[key] as Vector3).distance_to(center) < 5.0:
				return "abkuerzung"
		if (sc["landing"] as Vector3).distance_to(center) < 6.0 or _near_flight(sc, center, 4.0):
			return "abkuerzung"
	if on_track:
		for cor in c.corridors:
			var q: Vector3 = Geometry3D.get_closest_point_to_segment(center, cor["a"], cor["b"])
			if Vector2(q.x - center.x, q.z - center.z).length() < float(cor["half"]) + 1.5:
				return "korridor"
	return ""

## Liegt senkrecht unter p Bahnbelag auf Hoehe floor_y (+-0.25)? Geprueft ueber die Belag-Proben im Umkreis
## von 1.4 m (sie liegen hoechstens ~1.8 m quer und 2.5 m laengs auseinander).
static func _floor_below(c: Course3D, p: Vector3, floor_y: float) -> bool:
	for q in c.surface_pts:
		if absf(q.y - floor_y) < 0.25 and Vector2(q.x - p.x, q.z - p.z).length() < 1.4:
			return true
	return false

## Liegt p (waagerecht) naeher als `margin` an Steg oder Fluglinie einer Abkuerzung?
static func _near_flight(sc: Dictionary, p: Vector3, margin: float) -> bool:
	var p2 := Vector2(p.x, p.z)
	var g: Vector3 = sc["gate"]
	var lip: Vector3 = sc["lip"]
	var land: Vector3 = sc["landing"]
	return _seg_dist(p2, Vector2(g.x, g.z), Vector2(lip.x, lip.z)) < margin or _seg_dist(p2, Vector2(lip.x, lip.z), Vector2(land.x, land.z)) < margin

## Liegt der Ast (Strecke a-b in Weltkoordinaten) frei von Flug-Korridoren und den Abkuerzungen?
static func _branch_free(c: Course3D, a: Vector3, b: Vector3, avoid: Array[Vector3]) -> bool:
	for i in 5:
		var p: Vector3 = a.lerp(b, float(i) / 4.0)
		for cor in c.corridors:
			var q: Vector3 = Geometry3D.get_closest_point_to_segment(p, cor["a"], cor["b"])
			if Vector2(q.x - p.x, q.z - p.z).length() < float(cor["half"]) + 2.5:
				return false
		for sc in c.shortcuts:
			if (sc["landing"] as Vector3).distance_to(p) < 8.0 or _near_flight(sc, p, 4.0):
				return false
		for o in avoid:
			if Vector2(o.x - p.x, o.z - p.z).length() < 3.0:
				return false
	return true

## Lianen vom Ast herab (nur Optik, schwingen sanft; enden hoch genug ueber dem Belag).
static func _lianas(tree: Node3D, reach: float, attach_h: float, end_h: float, floor_l: float, rng: RandomNumberGenerator) -> void:
	for t: float in [0.45, 0.7, 0.92]:
		var x: float = reach * t
		var y: float = lerpf(attach_h, end_h, t) - 0.15
		var bottom: float = floor_l + 1.3
		var length: float = clampf(y - bottom, 0.4, 1.6) * rng.randf_range(0.75, 1.0)
		var pivot := Motion.swinger(Vector3.RIGHT, 0.1, rng.randf_range(1.0, 1.6), rng.randf() * TAU)
		pivot.position = Vector3(x, y, rng.randf_range(-0.15, 0.15))
		var mi := MeshInstance3D.new()
		mi.mesh = Flora.liana(length, int(x * 10.0))
		mi.material_override = Flora.material(0.0, 0.6)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(mi)
		tree.add_child(pivot)

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
