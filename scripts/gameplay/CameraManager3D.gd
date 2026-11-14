class_name CameraManager3D
extends Node3D
## 3D-Kamera fuer das Spiel (Hochformat):
##  - FOLLOW: Orbit um den Ball (ein Finger dreht 360 Grad + neigt, Pinch zoomt). Die Kamera haengt an einer
##    kritisch gedaempften Feder (Spring-Arm): Beim Schuss beschleunigt sie weich, gleitet dem Ball mit sauberem
##    Abstand hinterher und bremst ohne Nachschwingen.
##  - Zielen (set_aiming): Kamera faehrt naeher an den Ball und verengt den Blickwinkel, damit Ball, Gummiband und
##    Punkt-Kette das Bild beherrschen. Dazu echte Tiefenunschaerfe (Depth of Field): alles bis zum Ende der
##    Punkt-Kette bleibt scharf, der Hintergrund verschwimmt weich. Ausserhalb des Zielens ist die Unschaerfe aus.
##  - TOP: Vogelperspektive ueber der ganzen Bahn (verschieben + zoomen)
##  - HOLE_CAM: dramatischer Zeitlupen-Winkel am Loch (Best-Shot-Kamera)
##  - REPLAY: umkreist einen frei gesetzten Punkt
## Dazu Screen-Shake (shake()) und Hilfen fuers Zielen (aim_direction()).

enum Mode { FOLLOW, TOP, HOLE_CAM, REPLAY }

const PITCH_MIN := 0.1
const PITCH_MAX := 1.4
const DIST_MIN := 3.5
const DIST_MAX := 60.0
## Beim Zielen: Abstand x AIM_DIST, Blickwinkel AIM_FOV Grad
const AIM_DIST := 0.74
const AIM_FOV := 50.0
## Wie schnell der Ziel-Zoom ein- und ausfaehrt (1/s)
const AIM_EASE := 7.0
## Staerke der Hintergrund-Unschaerfe beim Zielen und die Zone hinter dem scharfen Bereich, in der sie einsetzt (m)
const DOF_AMOUNT := 0.11
const DOF_MARGIN := 3.5
const DOF_TRANSITION := 9.0
## Federn (Eigenfrequenz in 1/s, kritisch gedaempft): Blickpunkt folgt dem Ball, Kamera folgt dem Blickpunkt.
## Ruhender Ball -> straff (Drehen mit dem Finger reagiert sofort), fliegender Ball -> weicher Nachlauf.
const FOCUS_W_IDLE := 18.0
const FOCUS_W_MOVING := 10.0
const ARM_W_IDLE := 16.0
const ARM_W_MOVING := 7.5
const LOOK_W := 14.0

var camera: Camera3D
var mode: int = Mode.FOLLOW
var target: Node3D = null
var yaw: float = 0.0
var pitch: float = 0.5
var distance: float = 11.0
var sensitivity: float = 1.0
## Sekunden seit der letzten manuellen Drehung (fuer automatisches Ausrichten).
var idle_time: float = 99.0
## Tiefenunschaerfe (eigene Kamera-Attribute; ueberschreiben die der Welt-Umgebung nur fuer diese Kamera)
var attributes: CameraAttributesPractical

var _focus: Vector3 = Vector3.ZERO
var _focus_v: Vector3 = Vector3.ZERO
var _cam_v: Vector3 = Vector3.ZERO
var _look_v: Vector3 = Vector3.ZERO
var _target_prev: Vector3 = Vector3.INF
var _target_speed: float = 0.0
var _look: Vector3 = Vector3.ZERO
var _trauma: float = 0.0
var _shake_t: float = 0.0
var _top_center: Vector3 = Vector3.ZERO
var _top_height: float = 60.0
var _top_forward: Vector3 = Vector3.FORWARD
var _top_pan: Vector3 = Vector3.ZERO
var _cam_pos: Vector3 = Vector3.ZERO
var _cam_look: Vector3 = Vector3.ZERO
var _replay_point: Vector3 = Vector3.ZERO
var _replay_angle: float = 0.0
var _snap: bool = true
## Bahn mit Gelaende: die Kamera bleibt immer ueber den Hangen (nie in einem Berg).
var course: Course3D = null
var _base_fov: float = 62.0
var _want_fov: float = 62.0
var _aiming: bool = false
## 0 = normal, 1 = voll im Ziel-Zoom (weich ueberblendet)
var _aim_t: float = 0.0
## Weitester Punkt, der beim Zielen scharf bleiben soll (Ende der Punkt-Kette); INF = nur der Ball
var _aim_focus: Vector3 = Vector3.INF

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = _base_fov
	camera.near = 0.15
	camera.far = 900.0
	attributes = CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = false
	attributes.dof_blur_near_enabled = false
	attributes.dof_blur_amount = 0.0
	camera.attributes = attributes
	add_child(camera)
	camera.current = true
	sensitivity = float(GameManager.setting("camera_sens", 1.0))

# ================================================================ Steuerung

func follow(node: Node3D, snap: bool = false) -> void:
	target = node
	mode = Mode.FOLLOW
	_want_fov = _base_fov
	_target_prev = Vector3.INF
	if snap and node != null:
		_focus = node.global_position
		_snap = true

## Richtet die Kamera hinter dem Ball in Blickrichtung `dir` aus.
func aim_at(dir: Vector3, instant: bool = false) -> void:
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		return
	flat = flat.normalized()
	yaw = atan2(-flat.x, -flat.z)
	if instant:
		_snap = true

## Zielen an/aus: Kamera faehrt naeher heran, Blickwinkel enger, Hintergrund verschwimmt.
## Dreht die Kamera dabei nie (aim_direction() liest die Kamera-Ausrichtung).
func set_aiming(on: bool) -> void:
	# Der scharfe Bereich (Ende der Punkt-Kette) bleibt stehen, bis die Unschaerfe ausgeblendet ist -
	# sonst wuerde die Bahn vor dem Ball beim Loslassen kurz unscharf aufblitzen.
	_aiming = on

func is_aiming() -> bool:
	return _aiming

## 0..1: wie weit der Ziel-Zoom gerade eingefahren ist (Tests, HUD).
func aim_blend() -> float:
	return _aim_t

## Punkt, bis zu dem beim Zielen alles scharf bleibt (Ende der Punkt-Kette). INF = nur der Ball.
func set_aim_focus(point: Vector3) -> void:
	_aim_focus = point

## Aktueller Abstand des Balls zur Kamera (wirksam, inkl. Ziel-Zoom).
func effective_distance() -> float:
	return distance * lerpf(1.0, AIM_DIST, _aim_t)

## Ein-Finger-Wischen: dreht/neigt (FOLLOW) bzw. verschiebt (TOP).
func orbit(drag: Vector2) -> void:
	idle_time = 0.0
	if mode == Mode.TOP:
		var scale_f: float = _top_height / 620.0
		var right: Vector3 = _top_forward.cross(Vector3.UP).normalized()
		_top_pan += (-right * drag.x + _top_forward * drag.y) * scale_f
		_top_pan = _top_pan.limit_length(_top_height * 1.2)
		return
	yaw -= drag.x * 0.0065 * sensitivity
	pitch = clampf(pitch + drag.y * 0.0045 * sensitivity, PITCH_MIN, PITCH_MAX)

## Pinch/Mausrad: factor > 1 = weiter weg.
func zoom(factor: float) -> void:
	idle_time = 0.0
	if mode == Mode.TOP:
		_top_height = clampf(_top_height * factor, 12.0, 220.0)
	else:
		distance = clampf(distance * factor, DIST_MIN, DIST_MAX)

## Legt fest, was die Vogelperspektive zeigt.
func set_overview(bounds: AABB, forward: Vector3) -> void:
	_top_center = bounds.get_center()
	var f := Vector3(forward.x, 0.0, forward.z)
	_top_forward = f.normalized() if f.length() > 0.01 else Vector3.FORWARD
	var vp: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var aspect: float = vp.x / maxf(1.0, vp.y)
	var right: Vector3 = _top_forward.cross(Vector3.UP).normalized()
	# Ausdehnung der Bahn entlang Blick-"oben" und -"rechts"
	var half_f: float = 0.0
	var half_r: float = 0.0
	for i in 8:
		var corner: Vector3 = bounds.get_endpoint(i) - _top_center
		half_f = maxf(half_f, absf(corner.dot(_top_forward)))
		half_r = maxf(half_r, absf(corner.dot(right)))
	var t: float = tan(deg_to_rad(_base_fov * 0.5))
	_top_height = clampf(maxf((half_f + 5.0) / t, (half_r + 5.0) / (t * aspect)) + bounds.size.y * 0.5, 20.0, 220.0)
	_top_pan = Vector3.ZERO

func set_top(enabled: bool) -> void:
	if enabled:
		mode = Mode.TOP
		_top_pan = Vector3.ZERO
	elif mode == Mode.TOP:
		mode = Mode.FOLLOW
		_target_prev = Vector3.INF
	_want_fov = _base_fov

func is_top() -> bool:
	return mode == Mode.TOP

## Best-Shot-Kamera: tiefer Winkel neben dem Loch, Blick auf den heranrollenden Ball.
func hole_cam(hole_pos: Vector3, ball_pos: Vector3) -> void:
	mode = Mode.HOLE_CAM
	var to_ball := Vector3(ball_pos.x - hole_pos.x, 0.0, ball_pos.z - hole_pos.z)
	if to_ball.length() < 0.1:
		to_ball = Vector3.BACK
	var side: Vector3 = to_ball.normalized().rotated(Vector3.UP, deg_to_rad(125.0))
	_replay_point = hole_pos
	_cam_pos = hole_pos + side * 4.2 + Vector3.UP * 1.3
	_want_fov = 42.0

func end_hole_cam() -> void:
	if mode == Mode.HOLE_CAM:
		mode = Mode.FOLLOW
		_want_fov = _base_fov
		_target_prev = Vector3.INF

## Replay: umkreist den Punkt langsam.
func replay_at(point: Vector3) -> void:
	mode = Mode.REPLAY
	_replay_point = point
	_replay_angle = yaw
	_want_fov = 48.0

func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

# ================================================================ Zielen

## Bildschirm-Position des verfolgten Balls (INF, wenn hinter der Kamera).
func target_screen_pos() -> Vector2:
	if target == null or camera.is_position_behind(target.global_position):
		return Vector2.INF
	return camera.unproject_position(target.global_position)

## Slingshot: Zieh-Vektor auf dem Bildschirm -> Schussrichtung in der Welt (waagerecht).
## Nach unten ziehen schiesst von der Kamera weg, nach links ziehen schiesst nach rechts.
func aim_direction(drag: Vector2) -> Vector3:
	var basis_cam: Basis = camera.global_transform.basis
	var fwd := Vector3(-basis_cam.z.x, 0.0, -basis_cam.z.z)
	if fwd.length() < 0.25:
		fwd = Vector3(basis_cam.y.x, 0.0, basis_cam.y.z)
	fwd = fwd.normalized()
	var right := Vector3(basis_cam.x.x, 0.0, basis_cam.x.z).normalized()
	var dir: Vector3 = fwd * drag.y - right * drag.x
	if dir.length() < 0.0001:
		return fwd
	return dir.normalized()

# ================================================================ Update

## Kritisch gedaempfte Feder in kleinen, festen Schritten (stabil auch bei Rucklern und in der Zeitlupe).
## Gibt [Position, Geschwindigkeit] zurueck.
static func spring_step(x: Vector3, v: Vector3, goal: Vector3, omega: float, dt: float) -> Array:
	var left: float = minf(dt, 0.1)
	while left > 0.0:
		var h: float = minf(left, 1.0 / 120.0)
		v += ((goal - x) * omega * omega - v * (2.0 * omega)) * h
		x += v * h
		left -= h
	return [x, v]

func _process(delta: float) -> void:
	# Kamera laeuft in Echtzeit, auch waehrend der Zeitlupe
	var dt: float = delta / maxf(0.05, Engine.time_scale)
	idle_time += dt
	var aim_goal: float = 1.0 if (_aiming and mode == Mode.FOLLOW) else 0.0
	_aim_t = lerpf(_aim_t, aim_goal, 1.0 - exp(-AIM_EASE * dt))
	if absf(_aim_t - aim_goal) < 0.002:
		_aim_t = aim_goal
	if not _aiming and _aim_t <= 0.0:
		_aim_focus = Vector3.INF
	var want_pos: Vector3 = _cam_pos
	var want_look: Vector3 = _cam_look
	var up := Vector3.UP
	var k_pos: float = 10.0
	var use_spring := false
	var arm_w: float = ARM_W_IDLE
	match mode:
		Mode.FOLLOW:
			use_spring = true
			if target != null and is_instance_valid(target):
				var tp: Vector3 = target.global_position
				if _target_prev != Vector3.INF and dt > 0.0:
					_target_speed = lerpf(_target_speed, tp.distance_to(_target_prev) / dt, 1.0 - exp(-8.0 * dt))
				_target_prev = tp
				# schneller Ball -> weicher Nachlauf, ruhender Ball -> straff
				var moving: float = clampf(_target_speed / 6.0, 0.0, 1.0)
				arm_w = lerpf(ARM_W_IDLE, ARM_W_MOVING, moving)
				if _snap:
					_focus = tp
					_focus_v = Vector3.ZERO
				else:
					var fs: Array = spring_step(_focus, _focus_v, tp, lerpf(FOCUS_W_IDLE, FOCUS_W_MOVING, moving), dt)
					_focus = fs[0]
					_focus_v = fs[1]
			var dist: float = effective_distance()
			var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			want_pos = _focus + dir * dist
			want_look = _focus + Vector3.UP * 0.5
		Mode.TOP:
			var c: Vector3 = _top_center + _top_pan
			want_pos = c + Vector3.UP * _top_height - _top_forward * 0.5
			want_look = c
			up = _top_forward
			k_pos = 5.0
		Mode.HOLE_CAM:
			want_pos = _cam_pos
			var bp: Vector3 = target.global_position if target != null and is_instance_valid(target) else _replay_point
			want_look = _replay_point.lerp(bp, 0.45) + Vector3.UP * 0.2
			k_pos = 6.0
		Mode.REPLAY:
			_replay_angle += dt * 0.5
			want_pos = _replay_point + Vector3(sin(_replay_angle) * 7.0, 3.2, cos(_replay_angle) * 7.0)
			want_look = _replay_point + Vector3.UP * 0.3
			k_pos = 4.0
	if course != null and mode != Mode.TOP:
		want_pos.y = maxf(want_pos.y, course.ground_height(want_pos.x, want_pos.z) + 2.2)
	if _snap:
		_snap = false
		_cam_pos = want_pos
		_look = want_look
		_cam_v = Vector3.ZERO
		_look_v = Vector3.ZERO
		camera.global_position = want_pos
	elif use_spring:
		var cs: Array = spring_step(camera.global_position, _cam_v, want_pos, arm_w, dt)
		camera.global_position = cs[0]
		_cam_v = cs[1]
		var ls: Array = spring_step(_look, _look_v, want_look, LOOK_W, dt)
		_look = ls[0]
		_look_v = ls[1]
	else:
		_cam_v = Vector3.ZERO
		_look_v = Vector3.ZERO
		camera.global_position = camera.global_position.lerp(want_pos, 1.0 - exp(-k_pos * dt))
		_look = _look.lerp(want_look, 1.0 - exp(-12.0 * dt))
	if course != null and mode != Mode.TOP:
		var floor_y: float = course.ground_height(camera.global_position.x, camera.global_position.z) + 1.6
		if camera.global_position.y < floor_y:
			camera.global_position.y = floor_y
			_cam_v.y = maxf(_cam_v.y, 0.0)
	if mode != Mode.HOLE_CAM:
		_cam_pos = camera.global_position
	var to_look: Vector3 = _look - camera.global_position
	if to_look.length() > 0.05:
		if absf(to_look.normalized().dot(up)) > 0.995:
			up = _top_forward if absf(_top_forward.dot(to_look.normalized())) < 0.99 else Vector3.FORWARD
		camera.look_at(_look, up)
	var fov_goal: float = lerpf(_want_fov, AIM_FOV, _aim_t) if mode == Mode.FOLLOW else _want_fov
	camera.fov = fov_goal if absf(camera.fov - fov_goal) < 0.01 else lerpf(camera.fov, fov_goal, 1.0 - exp(-8.0 * dt))
	_update_dof()
	# Screen-Shake
	if _trauma > 0.001:
		_shake_t += dt * 38.0
		var s: float = _trauma * _trauma
		camera.h_offset = sin(_shake_t * 1.3) * cos(_shake_t * 0.7) * 0.35 * s
		camera.v_offset = sin(_shake_t * 1.7 + 1.0) * 0.3 * s
		camera.rotate_object_local(Vector3.BACK, sin(_shake_t * 2.1) * 0.03 * s)
		_trauma = maxf(0.0, _trauma - dt * 1.4)
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0

## Tiefenunschaerfe nur beim Zielen: scharf bis hinter Ball UND Ende der Punkt-Kette, dahinter weich unscharf.
## Keine Nah-Unschaerfe (das Gummiband liegt zwischen Kamera und Ball).
## Wichtig: Das Projekt glaettet Kanten mit SMAA statt MSAA. Mit MSAA rendert der Mobile-Renderer in einen eigenen
## Tiefenpuffer, die Unschaerfe saehe nur "unendlich weit" und wuerde das ganze Bild verwischen.
func _update_dof() -> void:
	if attributes == null:
		return
	var amount: float = DOF_AMOUNT * _aim_t if mode == Mode.FOLLOW else 0.0
	if amount < 0.004:
		if attributes.dof_blur_far_enabled:
			attributes.dof_blur_far_enabled = false
			attributes.dof_blur_amount = 0.0
		return
	var cam_p: Vector3 = camera.global_position
	var sharp: float = cam_p.distance_to(_focus)
	if target != null and is_instance_valid(target):
		sharp = maxf(sharp, cam_p.distance_to(target.global_position))
	if _aim_focus != Vector3.INF:
		sharp = maxf(sharp, cam_p.distance_to(_aim_focus))
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = sharp + DOF_MARGIN
	attributes.dof_blur_far_transition = DOF_TRANSITION
	attributes.dof_blur_amount = amount

## Wirksame Unschaerfe (Tests): 0 = aus
func dof_amount() -> float:
	return attributes.dof_blur_amount if attributes != null and attributes.dof_blur_far_enabled else 0.0
