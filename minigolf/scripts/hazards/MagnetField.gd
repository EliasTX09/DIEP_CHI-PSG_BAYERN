class_name MagnetField
extends Hazard
## Magnetfeld: zieht den Ball an (strength > 0) oder stoesst ihn ab (< 0). Staerker nahe am Zentrum.

var center: Vector2
var radius: float
var strength: float
var _t: float = 0.0

func _init(c: Vector2 = Vector2.ZERO, r: float = 120.0, s: float = 400.0) -> void:
	center = c; radius = r; strength = s

func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()

func apply(ball: Ball, _delta: float) -> void:
	var to := center - ball.position
	var d := to.length()
	if d < radius and d > 4.0:
		ball.add_accel(to / d * strength * (1.0 - d / radius) * (1.0 - ball.guidance * 0.5))

func _draw() -> void:
	var col := Color(0.8, 0.3, 1.0) if strength > 0 else Color(1.0, 0.4, 0.3)
	for i in 3:
		var k := fmod(_t * 0.8 + i / 3.0, 1.0)
		var r := radius * (1.0 - k if strength > 0 else k)
		draw_arc(center, r, 0, TAU, 48, Color(col, 0.5 * (1.0 - k)), 3.0)
	draw_circle(center, 8.0, col)
