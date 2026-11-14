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
## Proben der Belag-Oberflaeche (vom TrackKit) - daraus wird das Gelaende geformt.
var surface_pts: PackedVector3Array = PackedVector3Array()
## 1 = Probe liegt an einer Kante ohne Bande (dort faellt das Gelaende in eine Schlucht ab).
var surface_open: PackedByteArray = PackedByteArray()
## Flug-Korridore (Spruenge, Kanonen, Abkuerzungen): {a, b, half} - darunter liegt eine Schlucht.
var corridors: Array[Dictionary] = []
## Gelaende-Hoehenfeld (Aus-Grenze, Kamera-Boden) oder null.
var terrain: Terrain3D = null
## Abkuerzung (leer = keine): gate, dir, lane_start, lip, landing, elev, remaining (Hauptweg ab Tor), direct (Steg + Flug)
var shortcut: Dictionary = {}

# Schatten-Physikraum fuer Vorhersagen mit beweglichen Teilen (statische Kopien aller Bahn-Kollisionen)
var _shadow_space: RID = RID()
var _shadow_rids: Array[RID] = []
var _shadow_moving: Array[Dictionary] = []

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

# ---------------------------------------------------------------- Gelaende

func add_surface_sample(p: Vector3, open_edge: bool) -> void:
	surface_pts.append(p)
	surface_open.append(1 if open_edge else 0)

## Flug-Korridor von a nach b (halbe Breite in m): das Gelaende darunter wird zur Schlucht.
func add_corridor(a: Vector3, b: Vector3, half_width: float, reach: float = -1.0) -> void:
	corridors.append({"a": a, "b": b, "half": half_width, "reach": reach if reach > 0.0 else half_width + 9.0})

## Gelaendehoehe (oder -INF ohne Gelaende).
func ground_height(x: float, z: float) -> float:
	if terrain == null:
		return -INF
	return terrain.height_at(x, z)

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

# ---------------------------------------------------------------- Schatten-Physikraum

## true, wenn die Bahn bewegliche Hindernisse oder Plattformen hat.
func has_moving_parts() -> bool:
	return not obstacles.is_empty()

## Physik-Abfragen im Schattenraum (wird beim ersten Aufruf aufgebaut).
## Dort sind alle Koerper statisch und lassen sich ohne Verzoegerung auf jeden Zeitpunkt stellen -
## so kann die Flugbahn-Vorschau/Bot-KI Hammer, Windmuehlen und Faehren "in der Zukunft" beruecksichtigen.
func shadow_state() -> PhysicsDirectSpaceState3D:
	if not _shadow_space.is_valid():
		_build_shadow()
	return PhysicsServer3D.space_get_direct_state(_shadow_space)

func _build_shadow() -> void:
	_shadow_space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(_shadow_space, true)
	for node in find_children("*", "StaticBody3D", true, false):
		var body := node as StaticBody3D
		if body == null or not body.is_inside_tree():
			continue
		var rid: RID = PhysicsServer3D.body_create()
		PhysicsServer3D.body_set_mode(rid, PhysicsServer3D.BODY_MODE_STATIC)
		PhysicsServer3D.body_set_collision_layer(rid, body.collision_layer)
		PhysicsServer3D.body_set_collision_mask(rid, 0)
		for owner_id in body.get_shape_owners():
			if body.is_shape_owner_disabled(owner_id):
				continue
			var local_xf: Transform3D = body.shape_owner_get_transform(owner_id)
			for i in body.shape_owner_get_shape_count(owner_id):
				var shape: Shape3D = body.shape_owner_get_shape(owner_id, i)
				if shape != null:
					PhysicsServer3D.body_add_shape(rid, shape.get_rid(), local_xf)
		PhysicsServer3D.body_set_space(rid, _shadow_space)
		PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, body.global_transform)
		_shadow_rids.append(rid)
		if body is AnimatableBody3D:
			_shadow_moving.append({"rid": rid, "body": body})

## Stellt alle beweglichen Teile im Schattenraum auf die Bahn-Uhrzeit t.
func shadow_pose(t: float) -> void:
	if _shadow_moving.is_empty():
		return
	for o in obstacles:
		o.call("update_time", t)
	for e in _shadow_moving:
		var b: Node3D = e["body"]
		if is_instance_valid(b):
			PhysicsServer3D.body_set_state(e["rid"], PhysicsServer3D.BODY_STATE_TRANSFORM, b.global_transform)

## Setzt die echten Hindernisse wieder auf die aktuelle Bahn-Uhrzeit.
func shadow_restore() -> void:
	for o in obstacles:
		o.call("update_time", time)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for rid in _shadow_rids:
			PhysicsServer3D.free_rid(rid)
		_shadow_rids.clear()
		if _shadow_space.is_valid():
			PhysicsServer3D.free_rid(_shadow_space)
			_shadow_space = RID()
