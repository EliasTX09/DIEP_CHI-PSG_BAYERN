class_name Course3D
extends Node3D
## Eine fertig gebaute 3D-Bahn: Geometrie + Kollision, Tee, Loch, Mittellinie, Gadgets, Hindernisse.
## Wird von CourseBuilder3D erzeugt.

const HOLE_RADIUS := 0.75
const CUP_DEPTH := 0.55

var course_id: String = ""
var title: String = ""
var world: String = "emerald"
var par: int = 3
## Abschlag: Ursprung = Ballposition (Mittelpunkt), -Z = Spielrichtung.
var tee: Transform3D = Transform3D.IDENTITY
## Mittelpunkt der Lochoeffnung auf Gruen-Hoehe.
var hole_pos: Vector3 = Vector3.ZERO
var hole_radius: float = HOLE_RADIUS
## Mittellinie der Bahn (fuer Bot-KI, Fortschritt, Kamera).
var path_points: PackedVector3Array = PackedVector3Array()
var path_dist: PackedFloat32Array = PackedFloat32Array()
var gadgets: Array[Gadget] = []
## Bewegliche Hindernisse mit update_time(t).
var obstacles: Array[Node] = []
## Unterhalb dieser Hoehe ist der Ball "out".
var kill_y: float = -10.0
## Was liegt unter der Bahn? "water" | "lava" | "void"
var hazard: String = "water"
## Material-Klang der Bahn fuer Abpraller: "wood" | "stone" | "metal"
var surface_sound: String = "wood"
var floor_body: StaticBody3D
var wall_body: StaticBody3D
var bounds: AABB = AABB()
## Bahn-Uhr (Sekunden seit Bahnstart) - treibt alle Hindernisse deterministisch an.
var time: float = 0.0
var clock_running: bool = true
## Daily Challenge: nur ein Schlag.
var one_shot: bool = false
## Zeitlimit der Bahn in Sekunden.
var time_limit: float = 75.0

func _physics_process(delta: float) -> void:
	if clock_running:
		time += delta
	for o in obstacles:
		o.call("update_time", time)

func add_gadget(g: Gadget) -> void:
	gadgets.append(g)
	if g.get_parent() == null:
		add_child(g)

func add_obstacle(o: Node) -> void:
	obstacles.append(o)
	if o.get_parent() == null:
		add_child(o)
	o.call("update_time", time)

func set_time(t: float) -> void:
	time = t
	for o in obstacles:
		o.call("update_time", time)

# ---------------------------------------------------------------- Mittellinie

func add_path_point(p: Vector3) -> void:
	if path_points.size() > 0:
		var last: Vector3 = path_points[path_points.size() - 1]
		var d: float = last.distance_to(p)
		if d < 0.05:
			return
		path_dist.append(path_dist[path_dist.size() - 1] + d)
	else:
		path_dist.append(0.0)
	path_points.append(p)

func total_length() -> float:
	if path_dist.is_empty():
		return 0.0
	return path_dist[path_dist.size() - 1]

## Index des naechstgelegenen Mittellinien-Punkts.
func nearest_path_index(p: Vector3) -> int:
	var best := 0
	var best_d := INF
	for i in path_points.size():
		var d: float = path_points[i].distance_squared_to(p)
		if d < best_d:
			best_d = d
			best = i
	return best

## Fortschritt entlang der Bahn in Metern (0 = Tee, total_length() = Loch).
func progress_at(p: Vector3) -> float:
	if path_points.is_empty():
		return 0.0
	return path_dist[nearest_path_index(p)]

## Punkt auf der Mittellinie bei Distanz d (linear interpoliert).
func point_at_distance(d: float) -> Vector3:
	if path_points.is_empty():
		return hole_pos
	if d <= 0.0:
		return path_points[0]
	var n := path_points.size()
	if d >= path_dist[n - 1]:
		return path_points[n - 1]
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) >> 1
		if path_dist[mid] <= d:
			lo = mid
		else:
			hi = mid
	var span: float = path_dist[hi] - path_dist[lo]
	var t: float = 0.0 if span <= 0.0001 else (d - path_dist[lo]) / span
	return path_points[lo].lerp(path_points[hi], t)

func expand_bounds(p: Vector3) -> void:
	if bounds.size == Vector3.ZERO and bounds.position == Vector3.ZERO:
		bounds = AABB(p, Vector3.ZERO)
	else:
		bounds = bounds.expand(p)

## Liegt der Punkt (Ballmittelpunkt) im Loch?
func is_in_cup(p: Vector3) -> bool:
	var dx: float = p.x - hole_pos.x
	var dz: float = p.z - hole_pos.z
	return dx * dx + dz * dz < hole_radius * hole_radius and p.y < hole_pos.y + 0.12 and p.y > hole_pos.y - CUP_DEPTH - 0.6
