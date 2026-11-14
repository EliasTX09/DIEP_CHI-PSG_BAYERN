class_name Ball3D
extends RigidBody3D
## Der Golfball: RigidBody3D (Jolt) als reibungsfreie Kugel. Kollisionen und Abpraller rechnet die
## Engine; Rollwiderstand, Luftwiderstand, Spin (Top/Back/Side), Gadget-Effekte, Stillstand,
## Loch- und Out-Erkennung passieren in _integrate_forces. Dieselben Formeln nutzt ShotSim
## fuer die Flugbahn-Vorschau und die Bot-KI.

signal shot_fired(strokes: int)
signal stopped
signal holed
signal fell_out(kind: String)
signal respawned
signal style_event(kind: String, points: int)

enum State { FROZEN, IDLE, MOVING, HOLED, OUT }

const RADIUS := 0.3
const MAX_SPEED := 30.0             # m/s bei voller Kraft und Power-Faktor 1.0
const CHIP_SPEED_FACTOR := 0.82
const ROLL_DECEL := 3.2             # m/s^2 konstanter Rollwiderstand
const ROLL_DAMP := 0.42             # 1/s geschwindigkeitsabhaengiger Anteil
const AIR_DAMP := 0.04
const BOUNCE_FLOOR := 0.45
const BOUNCE_WALL := 0.75
const BOUNCE_MIN_SPEED := 1.2       # darunter kein Abprall (wie Jolt-Schwelle)
const STOP_SPEED := 0.35
const STOP_TIME := 0.3
const SIDE_ACCEL := 9.0             # m/s^2 Querbeschleunigung bei vollem Side-Spin
const SPIN_FADE := 2.5              # s, bis der Side-Spin abgeklungen ist
const MAX_STROKES := 10
const MAX_SHOT_TIME := 16.0
const OUT_DELAY := 0.9

var course: Course3D
var player_id: String = ""
var is_local: bool = false
var state: int = State.FROZEN
var strokes: int = 0
var profile: Dictionary = {}
var skin_id: String = "standard"
var trail_id: String = "none"
var sound_gain: float = 1.0
var sim := SimState.new()
## Letzte sichere Ruheposition (Respawn nach Out).
var last_rest: Vector3 = Vector3.ZERO
var shot_start: Vector3 = Vector3.ZERO
var grounded: bool = false
var ground_normal: Vector3 = Vector3.UP
var air_time: float = 0.0
## Aufzeichnung des letzten Schlags (Positionen pro Physik-Tick, fuer Replay).
var record: PackedVector3Array = PackedVector3Array()

var _spin: Vector2 = Vector2.ZERO
var _spin_time: float = 0.0
var _roll_mul: float = 1.0
var _chip: bool = false
var _landed: bool = false
var _max_air: float = 0.0
var _bank_hits: int = 0
var _last_bank_ms: int = 0
var _close_call: bool = false
## Ball hat in diesem Schlag die Abkuerzungs-Schanze genommen
var _shortcut: bool = false
var _close_tick: float = 0.0
var _shot_time: float = 0.0
var _stop_timer: float = 0.0
var _prev_vel: Vector3 = Vector3.ZERO
var _last_impact_ms: int = 0
var _launch: bool = false
var _launch_vel: Vector3 = Vector3.ZERO
var _teleport: bool = false
var _teleport_pos: Vector3 = Vector3.ZERO
var _pin_pos: Vector3 = Vector3.ZERO
var _pin_body: Node3D = null
var _pin_local: Vector3 = Vector3.ZERO
var _out_timer: float = 0.0
## Stelle, an der der Ball zuletzt "out" ging (fuer Effekte und Diagnose).
var out_pos: Vector3 = Vector3.ZERO
var _mesh: Node3D
var _trail: GPUParticles3D
var _ray := PhysicsRayQueryParameters3D.new()

# ================================================================ Aufbau

func setup(p_course: Course3D, p_id: String, shot_profile: Dictionary, p_skin: String, p_trail: String, local: bool) -> void:
	course = p_course
	player_id = p_id
	profile = shot_profile
	skin_id = p_skin
	trail_id = p_trail
	is_local = local
	sound_gain = 1.0 if local else 0.35
	collision_layer = 2
	collision_mask = 1 | 4 | 8
	mass = 1.0
	gravity_scale = 1.0
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 6
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.4
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = BOUNCE_FLOOR + float(profile.get("bounce_bonus", 0.0))
	physics_material_override = pm
	if get_child_count() == 0:
		var cs := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = RADIUS
		cs.shape = shape
		add_child(cs)
		_mesh = BallFX.make_ball(skin_id, RADIUS)
		add_child(_mesh)
		_trail = BallFX.make_trail(trail_id)
		if _trail != null:
			_trail.top_level = true
			_trail.emitting = false
			add_child(_trail)
	_ray.collision_mask = 1 | 4 | 8
	sim.wind_resist = float(profile.get("wind_resist", 0.0))

## Setzt den Ball auf den Abschlag (neue Bahn).
func place_on_tee(tee: Transform3D) -> void:
	strokes = 0
	sim.reset()
	last_rest = tee.origin
	_set_rest(tee.origin, null)
	state = State.FROZEN
	visible = true
	if _mesh != null:
		_mesh.scale = Vector3.ONE

## Gibt den Ball frei (Bahn gestartet).
func unfreeze() -> void:
	if state == State.FROZEN:
		state = State.IDLE

func freeze_ball() -> void:
	if state == State.IDLE or state == State.MOVING:
		_set_rest(global_position, null)
		state = State.FROZEN

func can_shoot() -> bool:
	return state == State.IDLE and strokes < MAX_STROKES

func speed() -> float:
	return linear_velocity.length()

# ================================================================ Schlag

## Abschuss-Geschwindigkeit fuer Richtung/Kraft (ohne Streuung). Wird auch von der Vorschau benutzt.
static func launch_velocity(dir: Vector3, power: float, chip: bool, prof: Dictionary, ground_n: Vector3 = Vector3.UP) -> Vector3:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.0001:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var spd: float = MAX_SPEED * clampf(power, 0.02, 1.0) * float(prof.get("power", 1.0))
	if chip:
		spd *= CHIP_SPEED_FACTOR
		var loft: float = deg_to_rad(float(prof.get("loft_deg", 36.0)))
		return flat * (spd * cos(loft)) + Vector3.UP * (spd * sin(loft))
	# Putt: entlang der Bodenflaeche (wichtig auf Rampen)
	var along: Vector3 = flat - ground_n * flat.dot(ground_n)
	if along.length() < 0.001:
		along = flat
	return along.normalized() * spd

## Rollwiderstands-Faktor durch Top-/Backspin (spin_y > 0 = Topspin).
static func roll_multiplier(spin_y: float, landed_from_flight: bool) -> float:
	var top: float = maxf(0.0, spin_y)
	var back: float = maxf(0.0, -spin_y)
	if landed_from_flight:
		return maxf(0.4, 1.0 - 0.3 * top + 2.5 * back)
	return maxf(0.4, 1.0 - 0.28 * top + 0.9 * back)

## Faktor auf die Horizontalgeschwindigkeit bei der ersten Landung nach einem Flug.
static func landing_factor(spin_y: float) -> float:
	var top: float = maxf(0.0, spin_y)
	var back: float = maxf(0.0, -spin_y)
	return clampf(1.0 + 0.4 * top - 0.7 * back, 0.15, 1.5)

## Fuehrt einen Schlag aus. dir = Richtung (waagerecht), power 0..1, chip = hoher Schlag,
## spin = (Side -1..1, Top(+)/Back(-) -1..1) vor Skalierung mit dem Schlaeger-Spin.
func shoot(dir: Vector3, power: float, chip: bool, spin: Vector2) -> bool:
	if not can_shoot():
		return false
	var v: Vector3 = launch_velocity(dir, power, chip, profile, ground_normal)
	# Streuung je nach Accuracy: wirkt staerker bei voller Kraft
	var scatter: float = deg_to_rad(float(profile.get("scatter_deg", 1.0))) * (0.35 + 0.65 * power)
	v = v.rotated(Vector3.UP, clampf(randfn(0.0, 0.45), -1.0, 1.0) * scatter)
	var spin_scale: float = float(profile.get("spin", 0.6))
	_spin = Vector2(clampf(spin.x, -1.0, 1.0), clampf(spin.y, -1.0, 1.0)) * spin_scale
	_spin_time = 0.0
	_chip = chip
	_landed = false
	_roll_mul = roll_multiplier(_spin.y, false) * (1.0 - float(profile.get("roll_bonus", 0.0)))
	_max_air = 0.0
	air_time = 0.0
	_bank_hits = 0
	_close_call = false
	_shortcut = false
	_shot_time = 0.0
	_stop_timer = 0.0
	shot_start = global_position
	record = PackedVector3Array()
	strokes += 1
	_pin_body = null
	_launch_vel = v
	_launch = true
	state = State.MOVING
	SoundManager.play("hit", power, randf_range(0.95, 1.05), sound_gain)
	if is_local:
		GameManager.vibrate(20 + int(power * 40.0))
	shot_fired.emit(strokes)
	return true

# ================================================================ Physik

func _integrate_forces(body_state: PhysicsDirectBodyState3D) -> void:
	var dt: float = body_state.step
	if _teleport:
		_teleport = false
		body_state.transform = Transform3D(body_state.transform.basis, _teleport_pos)
		body_state.linear_velocity = Vector3.ZERO
		body_state.angular_velocity = Vector3.ZERO
		_prev_vel = Vector3.ZERO
		return
	if state != State.MOVING:
		_hold_rest(body_state)
		return
	if _launch:
		_launch = false
		body_state.linear_velocity = _launch_vel
		_prev_vel = _launch_vel
		return
	var pos: Vector3 = body_state.transform.origin
	var vel: Vector3 = body_state.linear_velocity
	_shot_time += dt
	_spin_time += dt
	record.append(pos)

	# --- Kontakte auswerten: Boden, Banden, Aufprallstaerke ---
	var on_ground := false
	var gn := Vector3.UP
	var best_y := 0.55
	var ground_vel := Vector3.ZERO
	var ground_obj: Object = null
	var contacts: int = body_state.get_contact_count()
	for i in contacts:
		var cp: Vector3 = body_state.get_contact_local_position(i)
		var n: Vector3 = pos - cp
		if n.length_squared() < 0.0001:
			n = body_state.get_contact_local_normal(i)
		n = n.normalized()
		var closing: float = -_prev_vel.dot(n)
		if n.y > best_y:
			best_y = n.y
			on_ground = true
			gn = n
			ground_vel = body_state.get_contact_collider_velocity_at_position(i)
			ground_obj = body_state.get_contact_collider_object(i)
		if closing > 2.2:
			_on_impact(closing, n.y < 0.5)
	# Ohne gemeldeten Kontakt: knapp ueber dem Boden gilt der Ball trotzdem als rollend
	# (beim Rollen ueber Dreieckskanten meldet die Physik nicht in jedem Tick einen Kontakt).
	if not on_ground and vel.y < 1.5:
		var space_state: PhysicsDirectSpaceState3D = body_state.get_space_state()
		if space_state != null:
			_ray.from = pos
			_ray.to = pos + Vector3.DOWN * (RADIUS + 0.06)
			var ground_hit: Dictionary = space_state.intersect_ray(_ray)
			if not ground_hit.is_empty() and (ground_hit["normal"] as Vector3).y > 0.55:
				on_ground = true
				gn = ground_hit["normal"]
				ground_obj = ground_hit.get("collider")

	# --- Flugzeit / Landung ---
	if on_ground:
		if air_time > 0.25 and not _landed:
			_landed = true
			if _chip:
				var f: float = landing_factor(_spin.y)
				vel = Vector3(vel.x * f, vel.y, vel.z * f)
				_roll_mul = roll_multiplier(_spin.y, true) * (1.0 - float(profile.get("roll_bonus", 0.0)))
		_max_air = maxf(_max_air, air_time)
		air_time = 0.0
	elif contacts == 0:
		air_time += dt
		_max_air = maxf(_max_air, air_time)
	grounded = on_ground
	ground_normal = gn

	# --- Gadgets (Boost, Wind, Sand, Teleporter, Looping, Kanone, Laser) ---
	sim.begin_tick(pos, vel, on_ground, course.time, dt)
	if sim.rail != null:
		sim.rail.rail_advance(sim, dt)
		body_state.transform = Transform3D(body_state.transform.basis, sim.pos)
		body_state.linear_velocity = sim.vel
		body_state.angular_velocity = sim.vel.cross(Vector3.UP) / RADIUS * -1.0
		_prev_vel = sim.vel
		_emit_events()
		return
	for g in course.gadgets:
		g.affect(sim, dt)
	_emit_events()
	if sim.out_kind != "":
		_go_out(sim.out_kind)
		body_state.linear_velocity = Vector3.ZERO
		return
	if sim.held or sim.teleported:
		body_state.transform = Transform3D(body_state.transform.basis, sim.pos)
		body_state.linear_velocity = sim.vel
		_prev_vel = sim.vel
		if sim.teleported:
			air_time = 0.0
		return
	vel = sim.vel

	# --- Eigene Kraefte ---
	if on_ground:
		var rel: Vector3 = vel - ground_vel
		var rel_n: float = rel.dot(gn)
		var rel_t: Vector3 = rel - gn * rel_n
		var sp: float = rel_t.length()
		if sp > 0.0001:
			var decel: float = (ROLL_DECEL + ROLL_DAMP * sp) * _roll_mul * sim.decel_mul
			var new_sp: float = maxf(0.0, sp - decel * dt)
			rel_t *= new_sp / sp
		vel = ground_vel + rel_t + gn * rel_n
		body_state.angular_velocity = gn.cross(rel_t) / RADIUS
	else:
		vel *= maxf(0.0, 1.0 - AIR_DAMP * dt)
	if absf(_spin.x) > 0.01 and _spin_time < SPIN_FADE:
		var vh := Vector3(vel.x, 0.0, vel.z)
		var hs: float = vh.length()
		if hs > 1.0:
			var right: Vector3 = vh.normalized().cross(Vector3.UP)
			var k: float = SIDE_ACCEL * _spin.x * clampf(hs / 12.0, 0.0, 1.0) * (1.0 - _spin_time / SPIN_FADE)
			if on_ground:
				k *= 0.45
			vel += right * (k * dt)

	# --- Loch / Out ---
	if course.is_in_cup(pos):
		body_state.linear_velocity = Vector3.ZERO
		_enter_hole()
		return
	if pos.y < course.kill_y:
		body_state.linear_velocity = Vector3.ZERO
		_go_out(course.hazard)
		return

	# --- "Close Call": knapp am Abgrund entlang ---
	if on_ground and not _close_call and vel.length() > 3.0:
		_close_tick += dt
		if _close_tick > 0.12:
			_close_tick = 0.0
			_check_close_call(body_state.get_space_state(), pos, vel)

	# --- Stillstand ---
	var rel_speed: float = (vel - ground_vel).length()
	if on_ground and rel_speed < STOP_SPEED and gn.y > 0.9:
		_stop_timer += dt
	else:
		_stop_timer = 0.0
	var force_stop: bool = _shot_time > MAX_SHOT_TIME and on_ground and rel_speed < 2.5
	if _stop_timer >= STOP_TIME or force_stop:
		body_state.linear_velocity = ground_vel
		body_state.angular_velocity = Vector3.ZERO
		_come_to_rest(pos, ground_obj)
		return
	body_state.linear_velocity = vel
	_prev_vel = vel

func _hold_rest(body_state: PhysicsDirectBodyState3D) -> void:
	var target: Vector3 = _pin_pos
	if _pin_body != null and is_instance_valid(_pin_body):
		target = _pin_body.global_transform * _pin_local
		_pin_pos = target
	body_state.transform = Transform3D(body_state.transform.basis, target)
	body_state.linear_velocity = Vector3.ZERO
	body_state.angular_velocity = Vector3.ZERO
	_prev_vel = Vector3.ZERO

func _set_rest(pos: Vector3, platform: Object) -> void:
	_pin_pos = pos
	_pin_body = null
	if platform != null and platform is Node3D and (platform as Node3D).is_in_group("moving_floor"):
		_pin_body = platform as Node3D
		_pin_local = _pin_body.global_transform.affine_inverse() * pos
	_teleport_pos = pos
	_teleport = true
	if is_inside_tree():
		global_position = pos
	else:
		position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	grounded = true
	ground_normal = Vector3.UP

func _emit_events() -> void:
	for e in sim.events:
		match e:
			"boost":
				SoundManager.play("boost", 1.0, 1.0, sound_gain)
			"teleport":
				SoundManager.play("teleport", 1.0, 1.0, sound_gain)
			"cannon":
				SoundManager.play("cannon", 1.0, 1.0, sound_gain)
			"cannon_in":
				SoundManager.play("pop", 1.0, 0.7, sound_gain)
			"rail_in":
				SoundManager.play("whoosh", 1.0, 1.2, sound_gain)
			"launch":
				# Abkuerzungs-Schanze: fester Flug, kein Spin-Einfluss mehr
				_spin = Vector2.ZERO
				_shortcut = true
				SoundManager.play("boost", 1.0, 0.8, sound_gain)
			"land":
				SoundManager.play("pop", 1.0, 0.9, sound_gain)

func _on_impact(closing_speed: float, wall: bool) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_impact_ms > 70:
		_last_impact_ms = now
		SoundManager.play_bounce(course.surface_sound, clampf(closing_speed / 16.0, 0.05, 1.0) * sound_gain)
	if wall and closing_speed > 3.0 and now - _last_bank_ms > 250:
		_last_bank_ms = now
		_bank_hits += 1

func _check_close_call(space: PhysicsDirectSpaceState3D, pos: Vector3, vel: Vector3) -> void:
	var vh := Vector3(vel.x, 0.0, vel.z)
	if vh.length() < 0.5 or space == null:
		return
	var right: Vector3 = vh.normalized().cross(Vector3.UP)
	for sgn: float in [-1.0, 1.0]:
		var from: Vector3 = pos + right * (sgn * 1.0)
		_ray.from = from
		_ray.to = from + Vector3.DOWN * 3.0
		if space.intersect_ray(_ray).is_empty():
			_close_call = true
			return

func _come_to_rest(pos: Vector3, platform: Object) -> void:
	state = State.IDLE
	_pin_pos = pos
	_pin_body = null
	if platform != null and platform is Node3D and (platform as Node3D).is_in_group("moving_floor"):
		_pin_body = platform as Node3D
		_pin_local = _pin_body.global_transform.affine_inverse() * pos
	else:
		last_rest = pos
	_award_style(false)
	_notify(&"stopped")

func _enter_hole() -> void:
	state = State.HOLED
	_pin_body = null
	_pin_pos = course.hole_pos + Vector3(0.0, -Course3D.CUP_DEPTH + RADIUS, 0.0)
	_teleport_pos = _pin_pos
	_teleport = true
	SoundManager.play("holed", 1.0, 1.0, sound_gain)
	if is_local:
		GameManager.vibrate(120)
	_award_style(true)
	_notify(&"holed")

func _award_style(in_hole: bool) -> void:
	if _max_air >= 1.0:
		_notify(&"style_event", "air", Catalog.STYLE_AIR_TIME + int(minf(_max_air - 1.0, 2.0) * 40.0))
	if _bank_hits > 0:
		_notify(&"style_event", "bank", Catalog.STYLE_BANK_SHOT * mini(_bank_hits, 3))
	if _close_call:
		_notify(&"style_event", "close", Catalog.STYLE_CLOSE_CALL)
	if _shortcut:
		_shortcut = false
		_notify(&"style_event", "shortcut", Catalog.STYLE_SHORTCUT)
	if in_hole:
		if strokes == 1:
			_notify(&"style_event", "hio", Catalog.STYLE_HOLE_IN_ONE)
		elif shot_start.distance_to(course.hole_pos) > 20.0:
			_notify(&"style_event", "long", Catalog.STYLE_LONG_PUTT)

## Signale aus dem Physik-Callback heraus erst am Frame-Ende senden (keine Seiteneffekte mitten im Physikschritt).
func _notify(sig: StringName, a: Variant = null, b: Variant = null) -> void:
	if b != null:
		call_deferred("emit_signal", sig, a, b)
	elif a != null:
		call_deferred("emit_signal", sig, a)
	else:
		call_deferred("emit_signal", sig)

func _go_out(kind: String) -> void:
	if state == State.OUT:
		return
	state = State.OUT
	out_pos = global_position
	_out_timer = OUT_DELAY
	_pin_body = null
	_pin_pos = global_position
	sim.reset()
	sim.wind_resist = float(profile.get("wind_resist", 0.0))
	if kind == "lava":
		SoundManager.play("splash_lava", 1.0, 1.0, sound_gain)
	elif kind == "laser":
		SoundManager.play("laser", 1.0, 1.0, sound_gain)
	elif kind == "water":
		SoundManager.play("splash_water", 1.0, 1.0, sound_gain)
	elif kind == "ob":
		SoundManager.play_bounce("stone", 0.6 * sound_gain)
	else:
		SoundManager.play("whoosh", 1.0, 0.6, sound_gain)
	visible = kind == "laser"
	_notify(&"fell_out", kind)

func _physics_process(delta: float) -> void:
	if state == State.OUT:
		_out_timer -= delta
		if _out_timer <= 0.0:
			# Strafschlag und zurueck zur letzten sicheren Position
			strokes = mini(strokes + 1, MAX_STROKES)
			_set_rest(last_rest, null)
			visible = true
			state = State.IDLE
			respawned.emit()

func _process(_delta: float) -> void:
	if _trail != null:
		_trail.global_position = global_position
		_trail.emitting = state == State.MOVING and linear_velocity.length() > 1.5
	if state == State.HOLED and _mesh != null and _mesh.scale.x > 0.02:
		_mesh.scale = _mesh.scale * 0.9

## Erzwingt das Ende der Bahn fuer diesen Ball (Zeit abgelaufen / Schlaglimit).
func give_up() -> void:
	if state == State.HOLED:
		return
	sim.reset()
	_set_rest(global_position if state != State.OUT else last_rest, null)
	state = State.FROZEN
