class_name Gadget
extends Node3D
## Basisklasse aller "Feld"-Gadgets (Boost, Wind, Sand, Teleporter, Looping, Kanone, Laser, Kill-Zone).
## Gadgets sind analytische Volumen: affect() prueft per Mathe, ob der Ball betroffen ist.

## Wirkt auf den Ballzustand. Wird fuer jeden Ball pro Physik-Tick und in ShotSim aufgerufen.
func affect(_st: SimState, _dt: float) -> void:
	pass

## Bewegt einen Ball entlang einer Schiene (nur Gadgets, die st.rail setzen).
func rail_advance(_st: SimState, _dt: float) -> void:
	pass

## Gibt einen festgehaltenen Ball frei (nur Gadgets, die st.held setzen).
func release(_st: SimState) -> void:
	pass

## Punkt im lokalen Raum des Gadgets.
func to_local_point(p: Vector3) -> Vector3:
	return global_transform.affine_inverse() * p

## Liegt p in einer lokalen, achsparallelen Box (Mittelpunkt 0, halbe Kantenlaengen `half`)?
func in_local_box(p: Vector3, half: Vector3) -> bool:
	var l := to_local_point(p)
	return absf(l.x) <= half.x and absf(l.y) <= half.y and absf(l.z) <= half.z
