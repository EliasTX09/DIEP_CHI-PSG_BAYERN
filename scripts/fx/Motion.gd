class_name Motion
extends Node3D
## Mini-Animator fuer Deko: dreht und/oder laesst den Knoten schweben (rein optisch).

var spin_axis: Vector3 = Vector3.UP
var spin_speed: float = 0.0
var bob_height: float = 0.0
var bob_speed: float = 1.0
var swing_axis: Vector3 = Vector3.FORWARD
var swing_amp: float = 0.0
var swing_speed: float = 1.0
var _base_basis: Basis = Basis.IDENTITY
var _base_y: float = 0.0
var _t: float = 0.0
var _started: bool = false

static func spinner(axis: Vector3, speed: float) -> Motion:
	var m := Motion.new()
	m.spin_axis = axis.normalized()
	m.spin_speed = speed
	return m

static func bobber(height: float, speed: float, phase: float = 0.0) -> Motion:
	var m := Motion.new()
	m.bob_height = height
	m.bob_speed = speed
	m._t = phase
	return m

## Pendel (z.B. Lianen): schwingt um `axis` mit `amplitude` (rad).
static func swinger(axis: Vector3, amplitude: float, speed: float, phase: float = 0.0) -> Motion:
	var m := Motion.new()
	m.swing_axis = axis.normalized()
	m.swing_amp = amplitude
	m.swing_speed = speed
	m._t = phase
	return m

func _process(delta: float) -> void:
	if not _started:
		_started = true
		_base_y = position.y
		_base_basis = basis
	_t += delta
	if spin_speed != 0.0:
		rotate_object_local(spin_axis, spin_speed * delta)
	if bob_height != 0.0:
		position.y = _base_y + sin(_t * bob_speed) * bob_height
	if swing_amp != 0.0:
		basis = _base_basis * Basis(swing_axis, sin(_t * swing_speed) * swing_amp + sin(_t * swing_speed * 2.3) * swing_amp * 0.25)
