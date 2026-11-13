class_name RemoteBall
extends Node2D
## Gegner-/Ghost-Ball: wird aus empfangenen Positionen (Netz) bzw. Ghost-Samples interpoliert.

var player_id: String = ""
var display_name: String = ""
var color: Color = Color.WHITE
var is_ghost: bool = false
var _target: Vector2 = Vector2.ZERO
var finished: bool = false

func setup(id: String, nm: String, col: Color, ghost: bool, start: Vector2) -> void:
	player_id = id; display_name = nm; color = col; is_ghost = ghost
	position = start; _target = start
	finished = false
	z_index = 2
	queue_redraw()

func set_target(p: Vector2) -> void:
	_target = p

func _process(delta: float) -> void:
	position = position.lerp(_target, clampf(delta * 14.0, 0.0, 1.0))

func _draw() -> void:
	var a := 0.45 if is_ghost else 0.9
	draw_circle(Vector2.ZERO, Ball.RADIUS, Color(color, a))
	draw_arc(Vector2.ZERO, Ball.RADIUS, 0, TAU, 20, Color(1, 1, 1, a), 2.0)
	var f := ThemeDB.fallback_font
	draw_string(f, Vector2(-40, -16), ("👻 " if is_ghost else "") + display_name, HORIZONTAL_ALIGNMENT_CENTER, 80.0, 14, Color(1, 1, 1, 0.9))
