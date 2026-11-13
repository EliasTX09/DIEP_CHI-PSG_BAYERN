class_name Ball
extends Node2D
## Arcade-Ball: eigene kinematische Physik (kein RigidBody) -> deterministisch, schnell und
## identisch fuer Flugbahn-Vorschau, Ghost-Aufnahme und Netzwerk-Sync.
##
## Modell: Geschwindigkeit v (px/s). Pro Frame: externe Beschleunigung (Wind/Magnet) + Spin-Kurve,
## Luftwiderstand (exponentiell) + Rollreibung (konstant), Kollision Kreis<->Liniensegment (Substeps),
## Einlochen wenn nahe am Loch und langsam genug.

signal shot_fired(dir: Vector2, power: float, curve: float)
signal stopped(pos: Vector2)
signal sunk
signal fell_in_water
signal bounced(speed: float)
signal boosted

enum State { IDLE, ROLLING, SUNK }

const RADIUS := 10.0
const HOLE_RADIUS := 17.0
const MAX_SPEED := 1500.0           # px/s bei Power 1.0 und Stat 1.0
const DRAG := 0.9                   # 1/s  (Luft/Gras, exponentiell)
const ROLL_DECEL := 170.0           # px/s^2 (konstant)
const STOP_SPEED := 14.0
const SINK_SPEED := 620.0           # schneller = ueberrollt das Loch
const RESTITUTION := 0.86
const CURVE_ACCEL := 520.0          # px/s^2 maximale Spin-Querbeschleunigung (bei curve=1, spin=1)

var state: int = State.IDLE
var velocity: Vector2 = Vector2.ZERO
var color: Color = Color.WHITE
# Schlaeger-Stats (aus Progression)
var power_mult: float = 1.0
var guidance: float = 0.0           # 0..0.9: Wind-Resistenz + leichte Zielhilfe
var spin_stat: float = 0.2
var bounce_bonus: float = 0.0       # vom Ball-Item

var course: Course = null
var last_rest: Vector2 = Vector2.ZERO
var _curve: float = 0.0
var _accel: Vector2 = Vector2.ZERO
var trail: Line2D = null

func setup(c: Course, start: Vector2) -> void:
	course = c
	position = start
	last_rest = start
	velocity = Vector2.ZERO
	state = State.IDLE
	_curve = 0.0
	queue_redraw()

func apply_stats(stats: Dictionary) -> void:
	power_mult = stats.get("power", 1.0)
	guidance = stats.get("guidance", 0.0)
	spin_stat = stats.get("spin", 0.2)

func add_accel(a: Vector2) -> void:
	_accel += a

func can_shoot() -> bool:
	return state == State.IDLE

func speed() -> float:
	return velocity.length()

# ------------------------------------------------------------------ Schlag

## dir: Zielrichtung, power 0..1, curve -1..1 (Spin, skaliert mit spin_stat).
func shoot(dir: Vector2, power: float, curve: float = 0.0) -> void:
	if not can_shoot():
		return
	var d := aim_assist(dir.normalized(), power)
	velocity = d * clampf(power, 0.0, 1.0) * MAX_SPEED * power_mult
	_curve = clampf(curve, -1.0, 1.0) * spin_stat
	last_rest = position
	state = State.ROLLING
	shot_fired.emit(d, power, curve)

## "Richtungs-Fuehrung": zieht die Richtung leicht zum Loch, wenn der Winkel klein ist.
func aim_assist(dir: Vector2, _power: float) -> Vector2:
	if guidance <= 0.0 or course == null:
		return dir
	var to_hole := (course.hole_pos - position).normalized()
	var ang := dir.angle_to(to_hole)
	if absf(ang) < deg_to_rad(8.0):
		return dir.rotated(ang * guidance * 0.6)
	return dir

# ------------------------------------------------------------------ Physik

func _physics_process(delta: float) -> void:
	if state != State.ROLLING or course == null:
		return
	_accel = Vector2.ZERO
	for h in course.hazards:
		h.apply(self, delta)
	for h in course.hazards:
		if h.is_deadly(position):
			_fall_in_water()
			return
	var segs: Array = course.get_segments()
	var res := Ball.step(position, velocity, delta, segs, _accel, _curve)
	position = res["pos"]
	velocity = res["vel"]
	if res["hit"] > 0.0:
		bounced.emit(res["hit"])
	if course.hole_enabled and _check_sink():
		return
	if velocity.length() < STOP_SPEED:
		velocity = Vector2.ZERO
		state = State.IDLE
		last_rest = position
		stopped.emit(position)

func _check_sink() -> bool:
	var d := position.distance_to(course.hole_pos)
	if d < HOLE_RADIUS and velocity.length() < SINK_SPEED:
		state = State.SUNK
		velocity = Vector2.ZERO
		position = course.hole_pos
		sunk.emit()
		return true
	if d < HOLE_RADIUS * 1.6 and velocity.length() < SINK_SPEED * 1.6:
		# Kanten-Sog: leichte Anziehung ins Loch
		velocity += (course.hole_pos - position).normalized() * 900.0 * get_physics_process_delta_time()
	return false

func _fall_in_water() -> void:
	state = State.IDLE
	velocity = Vector2.ZERO
	position = last_rest
	fell_in_water.emit()

## Reiner Integrationsschritt (statisch -> auch fuer die Vorschau nutzbar).
## Rueckgabe: {pos, vel, hit} (hit = Aufprallgeschwindigkeit des staerksten Wandkontakts, sonst 0).
static func step(p: Vector2, v: Vector2, delta: float, segs: Array, accel: Vector2, curve: float) -> Dictionary:
	var hit := 0.0
	var spd := v.length()
	# Beschleunigungen
	v += accel * delta
	if absf(curve) > 0.001 and spd > 1.0:
		var fade := clampf(spd / (MAX_SPEED * 0.5), 0.0, 1.0)
		v += v.orthogonal().normalized() * curve * CURVE_ACCEL * fade * delta
	# Reibung
	v *= maxf(0.0, 1.0 - DRAG * delta)
	var sp := v.length()
	if sp > 0.0:
		v = v / sp * maxf(0.0, sp - ROLL_DECEL * delta)
	# Bewegung in Substeps (Tunneling verhindern)
	var dist := v.length() * delta
	var n := maxi(1, ceili(dist / (RADIUS * 0.5)))
	var sub := delta / float(n)
	for i in n:
		p += v * sub
		for s in segs:
			var a: Vector2 = s[0]
			var b: Vector2 = s[1]
			var th: float = s[2] if s.size() > 2 else 0.0
			var cp := Geometry2D.get_closest_point_to_segment(p, a, b)
			var off := p - cp
			var dd := off.length()
			var minr := RADIUS + th * 0.5
			if dd < minr:
				var nrm := off / dd if dd > 0.001 else (b - a).orthogonal().normalized()
				p = cp + nrm * minr
				var vn := v.dot(nrm)
				if vn < 0.0:
					hit = maxf(hit, -vn)
					v = v.bounce(nrm) * RESTITUTION
	return {"pos": p, "vel": v, "hit": hit}

## Flugbahn-Vorschau: simuliert den Schlag ueber `max_time` Sekunden (statische Waende + aktuelle Segmente).
func predict(dir: Vector2, power: float, curve: float, max_time: float = 1.2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if course == null:
		return pts
	var d := aim_assist(dir.normalized(), power)
	var v := d * clampf(power, 0.0, 1.0) * MAX_SPEED * power_mult
	var p := position
	var c := clampf(curve, -1.0, 1.0) * spin_stat
	var segs: Array = course.get_segments()
	var dt := 1.0 / 60.0
	var t := 0.0
	var i := 0
	pts.append(p)
	while t < max_time and v.length() > STOP_SPEED:
		var r := Ball.step(p, v, dt, segs, Vector2.ZERO, c)
		p = r["pos"]; v = r["vel"]
		t += dt
		i += 1
		if i % 3 == 0:
			pts.append(p)
	return pts

# ------------------------------------------------------------------ Darstellung

func _draw() -> void:
	if state == State.SUNK:
		return
	draw_circle(Vector2(2, 3), RADIUS, Color(0, 0, 0, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, color)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 20, Color(0, 0, 0, 0.5), 1.5)
