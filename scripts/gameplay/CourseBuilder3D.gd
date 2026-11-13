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

## Baut eine Bahn. Fuer "daily" bestimmt `rng_seed` den Tages-Parcours.
static func build(course_id: String, rng_seed: int = 0, with_environment: bool = true) -> Course3D:
	var id: String = course_id if INFO.has(course_id) else "e1"
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
	k.commit(th.materials)
	_flag(c, th)
	th.dress_course(c, k.supports)
	if with_environment:
		th.build_environment(c)
	return c

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

static func _hammer(c: Course3D, k: TrackKit, ahead: float, period: float = 2.6, phase: float = 0.0) -> void:
	var h := Obstacles.Hammer.new(55.0, period, phase)
	h.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_obstacle(h)

static func _block(c: Course3D, k: TrackKit, ahead: float, period: float = 3.0, phase: float = 0.0) -> void:
	var b := Obstacles.SlidingBlock.new(Vector3(1.6, 1.4, 1.6), k.width * 0.5 - 0.9, period, phase)
	b.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_obstacle(b)

static func _laser(c: Course3D, k: TrackKit, th: WorldTheme, ahead: float, period: float, duty: float, phase: float) -> void:
	var l := Gadgets.LaserGate.new(k.width, period, duty, phase, Color(1.0, 0.15, 0.3) if th.id == "neon" else Color(1.0, 0.5, 0.1))
	l.course = c
	l.transform = k.frame(Vector3(0.0, 0.0, -ahead))
	c.add_gadget(l)

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

static func _e2(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(10.0)
	_windmill(c, k, 4.0, 1.3)
	k.straight(12.0)
	k.turn(90.0, 7.0)
	k.straight(5.0)
	_sand(c, k, Vector3(1.3, 0.0, -3.0), Vector2(2.0, 3.0))
	k.straight(8.0)
	k.green(12.0, 9.0)

static func _e3(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(8.0)
	k.set_surface(TrackKit.S_ALT)
	k.hill(16.0, 2.4)
	k.set_surface(TrackKit.S_FLOOR)
	k.straight(4.0)
	k.turn(-90.0, 7.0)
	k.slope(10.0, -1.6)
	k.turn(-60.0, 8.0)
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
	k.straight(12.0)
	k.taper(5.0, 5.0)
	k.turn(70.0, 9.0, 12.0)
	k.set_wall_height(TrackKit.WALL_H)
	k.straight(6.0)
	k.green(12.0, 9.0)

static func _e5(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
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
	k.straight(14.0)
	k.taper(4.0, 5.0)
	k.set_wall_height(TrackKit.WALL_H)
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
	k.straight(5.0)
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
	k.straight(12.0)
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

static func _p1(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
	k.straight(4.0)
	k.set_walls(false, false)
	k.taper(3.0, 3.2)
	k.straight(12.0)
	k.turn(60.0, 9.0)
	k.straight(6.0)
	k.taper(3.0, 5.0)
	k.set_walls(true, true)
	k.straight(4.0)
	var barrel := Mat.flat(Color(0.5, 0.3, 0.14), 0.9)
	_post(c, k, Vector3(-1.2, 0.0, -2.0), 0.55, 1.2, barrel)
	_post(c, k, Vector3(1.3, 0.0, -4.5), 0.55, 1.2, barrel)
	_post(c, k, Vector3(-0.6, 0.0, -6.6), 0.55, 1.2, barrel)
	k.straight(8.0)
	k.slope(8.0, 1.5)
	k.green(12.0, 9.0)

static func _p2(c: Course3D, k: TrackKit, _th: WorldTheme) -> void:
	k.tee_box(5.0)
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
