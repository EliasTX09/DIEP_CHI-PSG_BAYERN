class_name Hazard
extends Node2D
## Basisklasse fuer Hindernisse/Hazard-Zonen. Alle Koordinaten sind Bahn-Raum.

## Wirkt pro Physik-Frame auf den Ball (Beschleunigung ueber ball.add_accel, Impulse ueber ball.velocity).
func apply(_ball: Ball, _delta: float) -> void:
	pass

## Bewegliche Kollisionssegmente: Array von [Vector2 a, Vector2 b, float dicke].
func get_segments() -> Array:
	return []

## true, wenn der Punkt "tot" ist (Wasser) -> Strafschlag + Reset.
func is_deadly(_p: Vector2) -> bool:
	return false
