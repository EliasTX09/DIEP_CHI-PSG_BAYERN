class_name WindZone
extends Hazard
## Windboeen: Zone, in der eine (pulsierende) Kraft auf den Ball wirkt.

var rect: Rect2
var force: Vector2
var gusty: bool
var _t: float = 0.0

func _init(r: Rect2 = Rect2(), f: Vector2 = Vector2.ZERO, g: bool = false) -> void:
	rect = r; force = f; gusty = g

func strength() -> float:
	if not gusty:
		return 1.0
	# Boeen: Grundwind 0.3 + Sinus-Puls
	return 0.3 + 0.7 * maxf(0.0, sin(_t * 1.4))

func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()

func apply(ball: Ball, _delta: float) -> void:
	if rect.has_point(ball.position):
		ball.add_accel(force * strength() * (1.0 - ball.guidance))

func _draw() -> void:
	var a := 0.10 + 0.12 * strength()
	draw_rect(rect, Color(0.6, 0.85, 1.0, a))
	var step := 80.0
	var dir := force.normalized()
	var y := rect.position.y + 30.0
	while y < rect.end.y:
		var x := rect.position.x + 30.0 + fmod(_t * 60.0 * strength(), step)
		while x < rect.end.x - 30.0:
			var c := Vector2(x, y)
			draw_line(c - dir * 14, c + dir * 14, Color(1, 1, 1, 0.35), 3.0)
			x += step
		y += step
