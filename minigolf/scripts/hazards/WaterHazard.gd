class_name WaterHazard
extends Hazard
## Wasser: Ball faellt hinein -> Strafschlag, zurueck zur letzten Ruheposition.

var poly: PackedVector2Array

func _init(p: PackedVector2Array = PackedVector2Array()) -> void:
	poly = p

func is_deadly(p: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(p, poly)

func _draw() -> void:
	draw_colored_polygon(poly, Color(0.15, 0.4, 0.85, 0.85))
	draw_polyline(poly + PackedVector2Array([poly[0]]), Color(0.7, 0.9, 1.0), 3.0)
