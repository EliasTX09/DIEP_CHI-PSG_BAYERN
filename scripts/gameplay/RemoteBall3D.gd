class_name RemoteBall3D
extends Node3D
## Ball eines Online-Gegners: rein optisch, wird aus empfangenen Positionen interpoliert
## (inklusive Skin, Trail und Roll-Animation). Keine Physik, keine Kollision.

var player_id: String = ""
var holed: bool = false
var _mesh: Node3D
var _trail: GPUParticles3D
var _target: Vector3 = Vector3.ZERO
var _prev: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _speed: float = 0.0

func setup(p_id: String, skin: String, trail_id: String, color: Color, start: Vector3) -> void:
	player_id = p_id
	_mesh = BallFX.make_ball(skin, Ball3D.RADIUS, color)
	add_child(_mesh)
	_trail = BallFX.make_trail(trail_id)
	if _trail != null:
		_trail.top_level = true
		_trail.emitting = false
		add_child(_trail)
	reset_to(start)

func reset_to(pos: Vector3) -> void:
	position = pos
	_target = pos
	_prev = pos
	_has_target = false
	holed = false
	visible = true
	if _mesh != null:
		_mesh.scale = Vector3.ONE

## Neue Position vom Netzwerk.
func push_position(pos: Vector3) -> void:
	_target = pos
	_has_target = true
	if position.distance_to(pos) > 25.0:
		position = pos   # Teleport/Respawn: nicht quer ueber die Bahn gleiten

func set_holed() -> void:
	holed = true

func set_hidden(hidden: bool) -> void:
	visible = not hidden

func _process(delta: float) -> void:
	_prev = position
	if _has_target:
		position = position.lerp(_target, 1.0 - exp(-11.0 * delta))
	var moved: Vector3 = position - _prev
	_speed = moved.length() / maxf(delta, 0.0001)
	if _mesh != null:
		var flat := Vector3(moved.x, 0.0, moved.z)
		if flat.length() > 0.0005:
			var axis: Vector3 = Vector3.UP.cross(flat.normalized())
			if axis.length() > 0.01:
				_mesh.rotate(axis.normalized(), flat.length() / Ball3D.RADIUS)
		if holed and _mesh.scale.x > 0.02:
			_mesh.scale = _mesh.scale * 0.9
	if _trail != null:
		_trail.global_position = global_position
		_trail.emitting = _speed > 1.5 and not holed and visible
