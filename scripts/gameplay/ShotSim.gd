class_name ShotSim
extends RefCounted
## Flugbahn-Simulation: rechnet einen Schlag mit denselben Regeln wie Ball3D voraus
## (Schwerkraft, Abpraller an Boden/Banden, Rollen ueber Rampen, Spin, Gadgets wie Boost,
## Wind, Teleporter, Looping-Schiene, Kanone). Genutzt fuer die 3D-Vorschau beim Zielen und
## fuer die Bot-KI (Bewertung von Kandidaten-Schlaegen).
##
## Die Simulation ist stueckweise ausfuehrbar (begin() + advance()), damit die Bot-KI sie
## ueber mehrere Frames verteilen kann. ShotSim.run() rechnet alles auf einmal.

const R := 0.3

var done: bool = true
## Ergebnis: points, end_pos, end_vel, holed, out, out_kind, stopped, time, bounces, banks, first_impact, max_air, grounded
var result: Dictionary = {}

var _course: Course3D
var _space: PhysicsDirectSpaceState3D
var _dt: float = 1.0 / 60.0
var _spin: Vector2 = Vector2.ZERO
var _chip: bool = false
var _sample: int = 2
var _roll_bonus: float = 1.0
var _e_floor: float = 0.45
var _e_wall: float = 0.75
var _gravity: Vector3 = Vector3(0, -20, 0)
var _query := PhysicsShapeQueryParameters3D.new()
var _rest_query := PhysicsShapeQueryParameters3D.new()
var _ray := PhysicsRayQueryParameters3D.new()
var _st := SimState.new()
var _p: Vector3
var _v: Vector3
var _n: Vector3 = Vector3.UP
var _grounded: bool = true
var _roll_mul: float = 1.0
var _landed: bool = false
var _air: float = 0.0
var _max_air: float = 0.0
var _t: float = 0.0
var _t0: float = 0.0
var _timed: bool = false
var _step: int = 0
var _steps: int = 0
var _stop_timer: float = 0.0
var _points: PackedVector3Array = PackedVector3Array()

## Startet eine Simulation.
## opts: max_time (s), dt (s), spin (Vector2, bereits mit Schlaeger-Spin skaliert), chip (bool),
##       profile (Schlagprofil), sample (jeder n-te Schritt wird als Punkt gespeichert), ignore_moving (bool),
##       timed (bool): bewegliche Hindernisse/Plattformen werden fuer jeden Schritt auf ihre Stellung zum Zeitpunkt
##             start_time + t gesetzt (im Schatten-Physikraum der Bahn, die echte Physik bleibt unberuehrt),
##       start_time (float): Bahn-Uhrzeit, zu der der Schlag ausgefuehrt wird (Standard: jetzt)
func begin(course: Course3D, space: PhysicsDirectSpaceState3D, start: Vector3, velocity: Vector3, opts: Dictionary = {}) -> void:
	_course = course
	_space = space
	_timed = bool(opts.get("timed", false)) and course.has_moving_parts()
	if _timed:
		_space = course.shadow_state()
	var max_time: float = float(opts.get("max_time", 6.0))
	_dt = float(opts.get("dt", 1.0 / 60.0))
	_spin = opts.get("spin", Vector2.ZERO)
	_chip = bool(opts.get("chip", false))
	var prof: Dictionary = opts.get("profile", {})
	_sample = maxi(1, int(opts.get("sample", 2)))
	# Welt (1) + fahrende Plattformen (8) immer; bewegliche Hindernisse (4) nur, wenn gewuenscht
	var mask: int = (1 | 8) if bool(opts.get("ignore_moving", false)) else (1 | 4 | 8)
	_roll_bonus = 1.0 - float(prof.get("roll_bonus", 0.0))
	_e_floor = Ball3D.BOUNCE_FLOOR + float(prof.get("bounce_bonus", 0.0))
	_e_wall = minf(0.95, Ball3D.BOUNCE_WALL + float(prof.get("bounce_bonus", 0.0)))
	_gravity = Vector3(0.0, -Gadgets.gravity(), 0.0)
	var shape := SphereShape3D.new()
	shape.radius = R * 0.93
	_query.shape = shape
	_query.collision_mask = mask
	var rest_shape := SphereShape3D.new()
	rest_shape.radius = R * 1.08
	_rest_query.shape = rest_shape
	_rest_query.collision_mask = mask
	_ray.collision_mask = mask
	_st.reset()
	_st.is_sim = true
	_st.wind_resist = float(prof.get("wind_resist", 0.0))
	_p = start
	_v = velocity
	_n = Vector3.UP
	_grounded = not _chip
	_roll_mul = Ball3D.roll_multiplier(_spin.y, false) * _roll_bonus
	_landed = false
	_air = 0.0
	_max_air = 0.0
	_t = 0.0
	_t0 = float(opts.get("start_time", course.time))
	_step = 0
	_steps = int(max_time / _dt)
	_stop_timer = 0.0
	_points = PackedVector3Array([start])
	result = {"holed": false, "out": false, "out_kind": "", "stopped": false, "bounces": 0, "banks": 0,
		"first_impact": Vector3.INF, "max_air": 0.0}
	done = false

## Rechnet bis zu `max_steps` Schritte weiter. Liefert true, wenn die Simulation fertig ist.
func advance(max_steps: int) -> bool:
	var budget: int = max_steps
	while not done and budget > 0:
		budget -= 1
		if _timed:
			_course.shadow_pose(_t0 + _t + _dt)
		if _step >= _steps or _one_step():
			_finish()
		_step += 1
	if _timed:
		_course.shadow_restore()
	return done

func _finish() -> void:
	done = true
	_points.append(_p)
	result["points"] = _points
	result["end_pos"] = _p
	result["end_vel"] = _v
	result["time"] = _t
	result["max_air"] = _max_air
	result["grounded"] = _grounded

## Ein Simulationsschritt. Liefert true, wenn der Schlag zu Ende ist (Loch, Out, Stillstand).
func _one_step() -> bool:
	var dt: float = _dt
	_t += dt
	var record: bool = _step % _sample == 0
	# --- Gadgets ---
	_st.begin_tick(_p, _v, _grounded, _t0 + _t, dt)
	if _st.rail != null:
		_st.rail.rail_advance(_st, dt)
		_p = _st.pos
		_v = _st.vel
		_grounded = true
		_n = Vector3.UP
		if record:
			_points.append(_p)
		return false
	for g in _course.gadgets:
		g.affect(_st, dt)
	if _st.events.has("launch"):
		_spin = Vector2.ZERO
	if _st.out_kind != "":
		result["out"] = true
		result["out_kind"] = _st.out_kind
		return true
	_p = _st.pos
	_v = _st.vel
	if _st.held:
		return false
	if _st.teleported:
		_grounded = _st.grounded
		_air = 0.0
		if record:
			_points.append(_p)
		return false

	# --- Side-Spin ---
	if absf(_spin.x) > 0.01 and _t < Ball3D.SPIN_FADE:
		var vh := Vector3(_v.x, 0.0, _v.z)
		var hs: float = vh.length()
		if hs > 1.0:
			var k: float = Ball3D.SIDE_ACCEL * _spin.x * clampf(hs / 12.0, 0.0, 1.0) * (1.0 - _t / Ball3D.SPIN_FADE)
			if _grounded:
				k *= 0.45
			_v += vh.normalized().cross(Vector3.UP) * (k * dt)

	if _grounded:
		_step_ground(dt)
	else:
		_step_air(dt)

	if record:
		_points.append(_p)
	# --- Loch / Out / Stillstand ---
	if _cup_capture(_course, _p, _v, _grounded):
		result["holed"] = true
		_p = _course.hole_pos
		return true
	if _p.y < _course.kill_y:
		result["out"] = true
		result["out_kind"] = _course.hazard
		return true
	if _grounded and _v.length() < Ball3D.STOP_SPEED and _n.y > 0.9:
		_stop_timer += dt
		if _stop_timer >= 0.15:
			result["stopped"] = true
			return true
	else:
		_stop_timer = 0.0
	return false

## Rollen auf der Flaeche: Hangabtrieb, Rollwiderstand, Banden-Abpraller, Boden folgen.
func _step_ground(dt: float) -> void:
	var n: Vector3 = _n
	var g_t: Vector3 = _gravity - n * _gravity.dot(n)
	_v += g_t * dt
	_v -= n * _v.dot(n)
	var sp: float = _v.length()
	if sp > 0.0001:
		var decel: float = (Ball3D.ROLL_DECEL + Ball3D.ROLL_DAMP * sp) * _roll_mul * _st.decel_mul
		_v *= maxf(0.0, sp - decel * dt) / sp
	var motion: Vector3 = _v * dt
	var lifted: Vector3 = _p + n * 0.03
	if motion.length() > 0.00001:
		_query.transform = Transform3D(Basis.IDENTITY, lifted)
		_query.motion = motion
		var res: PackedFloat32Array = _space.cast_motion(_query)
		if res.size() == 2 and res[0] < 0.999:
			var hit_pos: Vector3 = lifted + motion * res[0]
			var hn: Vector3 = _contact_normal(hit_pos + motion.normalized() * 0.05, n)
			if hn.y < 0.55:
				# Bande: abprallen
				var vn: float = _v.dot(hn)
				if vn < 0.0:
					var e: float = _e_wall if -vn > Ball3D.BOUNCE_MIN_SPEED else 0.0
					_v -= hn * ((1.0 + e) * vn)
					if -vn > 3.0:
						result["banks"] = int(result["banks"]) + 1
					if result["first_impact"] == Vector3.INF:
						result["first_impact"] = hit_pos
				_p = hit_pos - n * 0.03
			else:
				_p += motion
		else:
			_p += motion
	# Boden suchen (Rampen folgen, Kanten erkennen)
	_ray.from = _p + n * 0.2
	_ray.to = _p - n * (R + 0.2 + maxf(0.12, _v.length() * dt * 0.8))
	var hit: Dictionary = _space.intersect_ray(_ray)
	if hit.is_empty():
		_grounded = false
		_air = 0.0
		return
	var gnew: Vector3 = hit["normal"]
	var target: Vector3 = (hit["position"] as Vector3) + gnew * R
	# Abstand des Balls ueber der Flaeche: faellt der Boden schneller weg, als die Schwerkraft folgen kann -> Flug
	var gap_dist: float = (_p - target).dot(gnew)
	if gnew.y < 0.3 or gap_dist > 0.5 * _gravity.length() * dt * dt + 0.02:
		_grounded = false
		_air = 0.0
		return
	_p = target
	if gnew.dot(n) < 0.9995:
		var spd: float = _v.length()
		var vt: Vector3 = _v - gnew * _v.dot(gnew)
		if vt.length() > 0.001:
			_v = vt.normalized() * spd
	_n = gnew

## Flug: Schwerkraft, Luftwiderstand, Aufprall (Landen oder Abprallen).
func _step_air(dt: float) -> void:
	_v += _gravity * dt
	_v *= maxf(0.0, 1.0 - Ball3D.AIR_DAMP * dt)
	_air += dt
	_max_air = maxf(_max_air, _air)
	var motion: Vector3 = _v * dt
	if motion.length() < 0.00001:
		return
	_query.transform = Transform3D(Basis.IDENTITY, _p)
	_query.motion = motion
	var res: PackedFloat32Array = _space.cast_motion(_query)
	if res.size() != 2 or res[0] >= 0.999:
		_p += motion
		return
	var hit_pos: Vector3 = _p + motion * res[0]
	var hn: Vector3 = _contact_normal(hit_pos + motion.normalized() * 0.05, -motion.normalized())
	var vn: float = _v.dot(hn)
	_p = hit_pos
	if result["first_impact"] == Vector3.INF:
		result["first_impact"] = hit_pos
	if vn >= 0.0:
		return
	var floor_like: bool = hn.y > 0.55
	if floor_like and not _landed and _air > 0.25:
		_landed = true
		if _chip:
			var f: float = Ball3D.landing_factor(_spin.y)
			_v = Vector3(_v.x * f, _v.y, _v.z * f)
			vn = _v.dot(hn)
			_roll_mul = Ball3D.roll_multiplier(_spin.y, true) * _roll_bonus
	var bouncy: bool = -vn > Ball3D.BOUNCE_MIN_SPEED
	if floor_like:
		if bouncy:
			_v -= hn * ((1.0 + _e_floor) * vn)
			result["bounces"] = int(result["bounces"]) + 1
		else:
			_v -= hn * vn
			_grounded = true
			_n = hn
		_air = 0.0
	else:
		var e2: float = _e_wall if bouncy else 0.0
		_v -= hn * ((1.0 + e2) * vn)
		if -vn > 3.0:
			result["banks"] = int(result["banks"]) + 1

## Normale am Kontaktpunkt (zeigt vom Hindernis zur Kugel).
func _contact_normal(center: Vector3, fallback: Vector3) -> Vector3:
	_rest_query.transform = Transform3D(Basis.IDENTITY, center)
	var info: Dictionary = _space.get_rest_info(_rest_query)
	if info.is_empty():
		return fallback.normalized()
	var d: Vector3 = center - (info["point"] as Vector3)
	var n_out: Vector3
	if d.length() > 0.01:
		n_out = d.normalized()
	else:
		var nn: Vector3 = info["normal"]
		n_out = nn.normalized() if nn.length() > 0.01 else fallback.normalized()
	# Beruehrung mit beweglichem Hindernis (Hammer, Windmuehle, Schiebeblock) oder der Seite einer Faehre:
	# in echt wird der Ball dabei weggeschleudert - das kann die Vorhersage nicht exakt, also markieren.
	var rid: RID = info.get("rid", RID())
	if rid.is_valid():
		var layer: int = PhysicsServer3D.body_get_collision_layer(rid)
		if (layer & Obstacles.LAYER_OBSTACLE) != 0 or ((layer & Obstacles.LAYER_PLATFORM) != 0 and n_out.y < 0.55):
			result["obstacle_hit"] = true
	return n_out

## Faellt der Ball ins Loch? (Naeherung der echten Becher-Physik: nah genug an der Lochmitte und nicht zu schnell.)
static func _cup_capture(course: Course3D, p: Vector3, v: Vector3, grounded: bool) -> bool:
	var dx: float = p.x - course.hole_pos.x
	var dz: float = p.z - course.hole_pos.z
	var d2: float = dx * dx + dz * dz
	var r: float = course.hole_radius
	if d2 > r * r or absf(p.y - course.hole_pos.y - R) > 0.5:
		return false
	if not grounded and v.y > 0.0:
		return false
	# Je mittiger der Ball das Loch trifft, desto schneller darf er sein.
	var chord: float = 2.0 * sqrt(maxf(0.0, r * r - d2))
	var hs: float = Vector2(v.x, v.z).length()
	return hs < 8.5 * chord / (2.0 * r) + 1.0

## Rechnet einen Schlag komplett durch.
static func run(course: Course3D, space: PhysicsDirectSpaceState3D, start: Vector3, velocity: Vector3, opts: Dictionary = {}) -> Dictionary:
	var s := ShotSim.new()
	s.begin(course, space, start, velocity, opts)
	while not s.advance(4096):
		pass
	return s.result

## Bequemer Helfer: komplette Vorhersage fuer einen Schlag aus Richtung/Kraft.
static func predict_shot(course: Course3D, space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, power: float, chip: bool,
		spin_raw: Vector2, prof: Dictionary, max_time: float, ground_n: Vector3 = Vector3.UP, sample: int = 2) -> Dictionary:
	var v: Vector3 = Ball3D.launch_velocity(dir, power, chip, prof, ground_n)
	var spin: Vector2 = Vector2(clampf(spin_raw.x, -1.0, 1.0), clampf(spin_raw.y, -1.0, 1.0)) * float(prof.get("spin", 0.6))
	return run(course, space, from, v, {"max_time": max_time, "spin": spin, "chip": chip, "profile": prof, "sample": sample})
