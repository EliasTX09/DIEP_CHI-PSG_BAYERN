class_name GhostRecorder
extends RefCounted
## Zeichnet pro Bahn die Ballposition (10 Hz) auf -> Ghost-Lauf. samples = flach [t,x,y, t,x,y, ...]

const SAMPLE_DT := 0.1

var course_id: String = ""
var samples: PackedFloat32Array = PackedFloat32Array()
var strokes: int = 0
var duration: float = 0.0
var _acc: float = 0.0

func start(cid: String, start_pos: Vector2) -> void:
	course_id = cid
	samples = PackedFloat32Array()
	strokes = 0; duration = 0.0; _acc = 0.0
	_push(0.0, start_pos)

func tick(delta: float, t: float, pos: Vector2) -> void:
	_acc += delta
	if _acc >= SAMPLE_DT:
		_acc = 0.0
		_push(t, pos)

func finish(final_strokes: int, t: float, pos: Vector2) -> void:
	strokes = final_strokes
	duration = t
	_push(t, pos)

func _push(t: float, p: Vector2) -> void:
	samples.append(snappedf(t, 0.01)); samples.append(snappedf(p.x, 0.1)); samples.append(snappedf(p.y, 0.1))

func to_dict() -> Dictionary:
	return {"course_id": course_id, "strokes": strokes, "duration": duration, "samples": Array(samples)}

## Position zum Zeitpunkt t (lineare Interpolation). Gibt (-1,-1) wenn leer.
static func position_at(data: PackedFloat32Array, t: float) -> Vector2:
	var n := data.size() / 3
	if n == 0:
		return Vector2(-1, -1)
	if t <= data[0]:
		return Vector2(data[1], data[2])
	for i in range(1, n):
		var t1: float = data[i * 3]
		if t <= t1:
			var t0: float = data[(i - 1) * 3]
			var a := Vector2(data[(i - 1) * 3 + 1], data[(i - 1) * 3 + 2])
			var b := Vector2(data[i * 3 + 1], data[i * 3 + 2])
			return a.lerp(b, inverse_lerp(t0, t1, t))
	return Vector2(data[(n - 1) * 3 + 1], data[(n - 1) * 3 + 2])

## Lokaler Fallback-Speicher + Upload (Supabase, wenn eingeloggt).
func save_and_upload() -> void:
	var d := to_dict()
	DirAccess.make_dir_recursive_absolute("user://ghosts")
	var path := "user://ghosts/%s.json" % course_id
	var best: Dictionary = {}
	if FileAccess.file_exists(path):
		var old = JSON.parse_string(FileAccess.get_file_as_string(path))
		if old is Dictionary:
			best = old
	if best.is_empty() or int(d["strokes"]) < int(best.get("strokes", 99)) \
			or (int(d["strokes"]) == int(best.get("strokes", 99)) and float(d["duration"]) < float(best.get("duration", 1e9))):
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(d))
		if Supa.is_logged_in():
			d["owner_id"] = Supa.user_id
			Supa.rest_insert("ghosts", d)

static func load_local(cid: String) -> Dictionary:
	var path := "user://ghosts/%s.json" % cid
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		if d is Dictionary:
			return d
	return {}

## Bester Ghost eines Freundes fuer eine Bahn (RLS laesst nur Freunde/eigene durch).
static func fetch_friend_ghost(cid: String) -> Dictionary:
	var r: Dictionary = await Supa.rest_get(
		"ghosts?course_id=eq.%s&owner_id=neq.%s&order=strokes.asc,duration.asc&limit=1&select=*,profiles(username)" % [cid, Supa.user_id])
	if r.ok and r.data is Array and r.data.size() > 0:
		return r.data[0]
	return {}
