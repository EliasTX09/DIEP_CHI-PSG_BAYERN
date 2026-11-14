class_name CameraRig3D
extends Node3D
## 3D-Kamera fuer das Spiel:
##  - FOLLOW: Orbit um den Ball (ein Finger dreht 360 Grad + neigt, Pinch zoomt)
##  - TOP: Vogelperspektive ueber der ganzen Bahn (verschieben + zoomen)
##  - HOLE_CAM: dramatischer Zeitlupen-Winkel am Loch (Best-Shot-Kamera)
##  - REPLAY: umkreist einen frei gesetzten Punkt
## Dazu Screen-Shake (shake()) und Hilfen fuers Zielen (aim_direction()).

enum Mode { FOLLOW, TOP, HOLE_CAM, REPLAY }

const PITCH_MIN := 0.1
const PITCH_MAX := 1.4
const DIST_MIN := 3.5
const DIST_MAX := 60.0

var camera: Camera3D
var mode: int = Mode.FOLLOW
var target: Node3D = null
var yaw: float = 0.0
var pitch: float = 0.5
var distance: float = 11.0
var sensitivity: float = 1.0
## Sekunden seit der letzten manuellen Drehung (fuer automatisches Ausrichten).
var idle_time: float = 99.0

var _focus: Vector3 = Vector3.ZERO
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.fov = _base_fov
	camera.near = 0.15
	camera.far = 900.0
	add_child(camera)
	camera.current = true
	sensitivity = float(GameManager.setting("camera_sens", 1.0))

# ================================================================ Steuerung

func follow(node: Node3D, snap: bool = false) -> void:
	target = node
	mode = Mode.FOLLOW
	_want_fov = _base_fov
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

func _process(delta: float) -> void:
	# Kamera laeuft in Echtzeit, auch waehrend der Zeitlupe
	var dt: float = delta / maxf(0.05, Engine.time_scale)
	idle_time += dt
	var want_pos: Vector3 = _cam_pos
	var want_look: Vector3 = _cam_look
	var up := Vector3.UP
	var k_pos: float = 10.0
	match mode:
		Mode.FOLLOW:
			if target != null and is_instance_valid(target):
				var tp: Vector3 = target.global_position
				_focus = tp if _snap else _focus.lerp(tp, 1.0 - exp(-10.0 * dt))
			var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			want_pos = _focus + dir * distance
			want_look = _focus + Vector3.UP * 0.5
			k_pos = 14.0
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
		camera.global_position = want_pos
	else:
		camera.global_position = camera.global_position.lerp(want_pos, 1.0 - exp(-k_pos * dt))
		_look = _look.lerp(want_look, 1.0 - exp(-12.0 * dt))
	if course != null and mode != Mode.TOP:
		var floor_y: float = course.ground_height(camera.global_position.x, camera.global_position.z) + 1.6
		if camera.global_position.y < floor_y:
			camera.global_position.y = floor_y
	if mode != Mode.HOLE_CAM:
		_cam_pos = camera.global_position
	var to_look: Vector3 = _look - camera.global_position
	if to_look.length() > 0.05:
		if absf(to_look.normalized().dot(up)) > 0.995:
			up = _top_forward if absf(_top_forward.dot(to_look.normalized())) < 0.99 else Vector3.FORWARD
		camera.look_at(_look, up)
	camera.fov = lerpf(camera.fov, _want_fov, 1.0 - exp(-6.0 * dt))
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
