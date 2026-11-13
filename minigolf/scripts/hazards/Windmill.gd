class_name Windmill
extends Hazard
## Rotierende Windmuehle: zwei gekreuzte Fluegel als bewegliche Kollisionssegmente.

var center: Vector2
var length: float
var speed: float
var angle: float = 0.0
const THICKNESS := 14.0

func _init(c: Vector2 = Vector2.ZERO, l: float = 120.0, s: float = 1.5) -> void:
	center = c; length = l; speed = s

func _physics_process(delta: float) -> void:
	angle += speed * delta
	queue_redraw()

func get_segments() -> Array:
	var d := Vector2.from_angle(angle) * length
	var e := Vector2.from_angle(angle + PI * 0.5) * length
	return [[center - d, center + d, THICKNESS], [center - e, center + e, THICKNESS]]

func _draw() -> void:
	for s in get_segments():
		draw_line(s[0], s[1], Color(0.85, 0.7, 0.5), THICKNESS)
	draw_circle(center, 12.0, Color(0.5, 0.3, 0.2))
