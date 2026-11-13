class_name BotBrain
extends RefCounted
## KI fuer einen Bot-Ball: denkt wie ein Spieler mit Flugbahn-Vorschau.
## Der Bot erzeugt Kandidaten-Schlaege (Richtungen entlang der Bahn + direkt aufs Loch, mehrere
## Staerken, Putt und Chip), simuliert sie mit ShotSim und waehlt den besten. Je nach Skill
## kommen Ziel- und Kraftfehler dazu. Die Simulationen laufen zeitscheibenweise (think()),
## damit das Spiel fluessig bleibt.

enum Phase { WAIT, DELAY, SEARCH, AIMED }

## Rechenzeit pro Aufruf von think() in Mikrosekunden (Tests setzen das hoch).
static var time_budget_usec: int = 2500

var ball: Ball3D
var course: Course3D
var skill: float = 0.6
var phase: int = Phase.WAIT
## Wird gesetzt, sobald der Bot geschossen hat (fuer Emotes o.ae.).
var shots_taken: int = 0

var _rng := RandomNumberGenerator.new()
var _timer: float = 0.0
var _candidates: Array[Dictionary] = []
var _index: int = 0
var _sim: ShotSim = null
var _best: Dictionary = {}
var _best_score: float = -INF
var _start_progress: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _stuck: int = 0

func _init(p_ball: Ball3D, p_course: Course3D, p_skill: float, rng_seed: int) -> void:
	ball = p_ball
	course = p_course
	skill = clampf(p_skill, 0.05, 1.0)
	_rng.seed = rng_seed

## true, wenn der Bot gerade rechnen moechte (Match3D verteilt die Rechenzeit reihum).
func wants_cpu() -> bool:
	return phase == Phase.SEARCH

## Zeitsteuerung; einmal pro Frame aufrufen.
func update(delta: float) -> void:
	if ball == null or not is_instance_valid(ball):
		return
	if not ball.can_shoot():
		if phase != Phase.WAIT:
			phase = Phase.WAIT
			_sim = null
		return
	match phase:
		Phase.WAIT:
			phase = Phase.DELAY
			_timer = lerpf(2.2, 0.8, skill) + _rng.randf_range(0.0, 1.2)
		Phase.DELAY:
			_timer -= delta
			if _timer <= 0.0:
				_build_candidates()
				phase = Phase.SEARCH
		Phase.AIMED:
			_timer -= delta
			if _timer <= 0.0:
				_shoot()

## Rechnet an den Kandidaten weiter (hoechstens time_budget_usec lang).
func think(space: PhysicsDirectSpaceState3D) -> void:
	if phase != Phase.SEARCH or space == null:
		return
	var t_start: int = Time.get_ticks_usec()
	while phase == Phase.SEARCH:
		if _sim == null:
			if _index >= _candidates.size():
				phase = Phase.AIMED
				_timer = 0.25
				return
			var cand: Dictionary = _candidates[_index]
			var v: Vector3 = Ball3D.launch_velocity(cand["dir"], float(cand["power"]), bool(cand["chip"]), ball.profile, ball.ground_normal)
			_sim = ShotSim.new()
			_sim.begin(course, space, ball.global_position, v, {"max_time": 9.0, "dt": 1.0 / 40.0, "chip": bool(cand["chip"]),
				"profile": ball.profile, "sample": 100000})
		if _sim.advance(24):
			var sc: float = _score(_sim.result)
			if sc > _best_score:
				_best_score = sc
				_best = _candidates[_index]
			_sim = null
			_index += 1
		if Time.get_ticks_usec() - t_start > time_budget_usec:
			return

# ================================================================ Kandidaten

## Kraft (0..1), mit der ein Putt auf ebener Flaeche etwa `dist` Meter weit rollt.
func power_for_distance(dist: float) -> float:
	var a: float = Ball3D.ROLL_DECEL
	var k: float = Ball3D.ROLL_DAMP
	var lo := 0.0
	var hi := 80.0
	for i in 18:
		var v0: float = (lo + hi) * 0.5
		var t_stop: float = log(1.0 + k * v0 / a) / k
		var d: float = (v0 - a * t_stop) / k
		if d < dist:
			lo = v0
		else:
			hi = v0
	var vmax: float = Ball3D.MAX_SPEED * float(ball.profile.get("power", 1.0))
	return clampf(hi / vmax, 0.05, 1.0)

func _build_candidates() -> void:
	_candidates.clear()
	_index = 0
	_sim = null
	_best = {}
	_best_score = -INF
	var pos: Vector3 = ball.global_position
	_start_progress = course.progress_at(pos)
	var total: float = course.total_length()
	# Steckt der Bot fest (gleiche Stelle wie zuvor)? Dann breiter streuen.
	if _last_pos != Vector3.INF and _last_pos.distance_to(pos) < 1.0:
		_stuck += 1
	else:
		_stuck = 0
	_last_pos = pos
	var dirs: Array[Vector3] = []
	var dists: Array[float] = []
	var to_hole := Vector3(course.hole_pos.x - pos.x, 0.0, course.hole_pos.z - pos.z)
	if to_hole.length() > 0.3:
		dirs.append(to_hole.normalized())
		dists.append(to_hole.length())
	for ahead: float in [6.0, 10.0, 15.0, 21.0, 28.0, 37.0, 48.0]:
		var target: Vector3 = course.point_at_distance(minf(_start_progress + ahead, total))
		var d := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
		if d.length() < 1.0:
			continue
		var dn: Vector3 = d.normalized()
		var dup := false
		for other in dirs:
			if other.dot(dn) > 0.9994:
				dup = true
				break
		if not dup:
			dirs.append(dn)
			dists.append(d.length())
	if _stuck > 0:
		for i in 6:
			var ang: float = TAU * float(i) / 6.0 + float(_stuck) * 0.4
			dirs.append(Vector3(sin(ang), 0.0, cos(ang)))
			dists.append(8.0)
	for i in dirs.size():
		var base: float = power_for_distance(dists[i])
		for mul: float in [0.85, 1.0, 1.18, 1.45]:
			var p: float = clampf(base * mul, 0.06, 1.0)
			_candidates.append({"dir": dirs[i], "power": p, "chip": false})
		if dists[i] > 9.0 and i < 4:
			for cp: float in [0.55, 0.8, 1.0]:
				_candidates.append({"dir": dirs[i], "power": cp, "chip": true})

func _score(res: Dictionary) -> float:
	if bool(res.get("holed", false)):
		return 100000.0 - float(res.get("time", 0.0))
	if bool(res.get("out", false)):
		return -500.0
	var end_pos: Vector3 = res["end_pos"]
	var total: float = course.total_length()
	var progress: float = course.progress_at(end_pos)
	var off_path: float = end_pos.distance_to(course.path_points[course.nearest_path_index(end_pos)])
	var to_hole: float = end_pos.distance_to(course.hole_pos)
	var score: float = -(total - progress) - 0.35 * minf(to_hole, 40.0) - 0.5 * maxf(0.0, off_path - 2.0)
	if not bool(res.get("stopped", false)):
		score -= 6.0
	return score

func _shoot() -> void:
	phase = Phase.WAIT
	if _best.is_empty():
		# Notfall: einfach Richtung Loch
		var d := Vector3(course.hole_pos.x - ball.global_position.x, 0.0, course.hole_pos.z - ball.global_position.z)
		_best = {"dir": d.normalized() if d.length() > 0.1 else Vector3.FORWARD, "power": 0.4, "chip": false}
	var dir: Vector3 = _best["dir"]
	var power: float = float(_best["power"])
	# Skill-abhaengige Fehler: Zielwinkel und Kraft
	var err: float = 1.0 - skill
	dir = dir.rotated(Vector3.UP, deg_to_rad(_rng.randfn(0.0, 0.25 + 3.2 * err)))
	power = clampf(power * (1.0 + _rng.randfn(0.0, 0.015 + 0.09 * err)), 0.05, 1.0)
	if ball.shoot(dir, power, bool(_best["chip"]), Vector2.ZERO):
		shots_taken += 1
