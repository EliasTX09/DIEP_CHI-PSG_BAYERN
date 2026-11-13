class_name BoostPad
extends Hazard
## Boost-Pad: beschleunigt den Ball beim Ueberfahren in Pfeilrichtung.

var pos: Vector2
var size: Vector2
var dir: Vector2
var power: float
var _inside: bool = false

func _init(p: Vector2 = Vector2.ZERO, s: Vector2 = Vector2(60, 40), d: Vector2 = Vector2.UP, pw: float = 400.0) -> void:
	pos = p; size = s; dir = d.normalized(); power = pw

func apply(ball: Ball, _delta: float) -> void:
	var inside := Rect2(pos - size * 0.5, size).has_point(ball.position)
	if inside and not _inside:
		ball.velocity += dir * power     # einmaliger Impuls beim Eintritt
		ball.boosted.emit()
	_inside = inside

func _draw() -> void:
	draw_rect(Rect2(pos - size * 0.5, size), Color(1.0, 0.85, 0.1, 0.5))
	var perp := dir.orthogonal()
	var tip := pos + dir * 16.0
	draw_colored_polygon(PackedVector2Array([tip, pos - dir * 8 + perp * 12, pos - dir * 8 - perp * 12]), Color(0.9, 0.4, 0.0))
