extends Node
## Autoload "GameManager": State-Machine des Match-Ablaufs (ohne Szenen-Nodes).
## IDLE -> LOADING_MAP -> SHOT_PHASE -> HOLE_RESULT -> (LOADING_MAP ...) -> [SUDDEN_DEATH] -> MATCH_RESULT
## Alle Spieler spielen gleichzeitig; eine Bahn endet, wenn alle fertig sind oder die Zeit ablaeuft.

enum Mode { QUICK_DM, GHOST, PRACTICE }
enum State { IDLE, LOADING_MAP, SHOT_PHASE, HOLE_RESULT, SUDDEN_DEATH, MATCH_RESULT }

signal state_changed(new_state: int, old_state: int)
signal course_requested(course_id: String, hole_index: int)   # GameScene laedt die Map
signal hole_finished(summary: Array)
signal match_finished(result: Array)
signal players_changed

var mode: int = Mode.PRACTICE
var state: int = State.IDLE
var course_ids: Array = []
var hole_index: int = 0
var players: Dictionary = {}        # id -> {id,name,color,total,strokes,finished,t,is_local,kind,pin_dist}
var local_id: String = "local"
var time_left: float = 0.0
var sudden_death_ids: Array = []
var sd_winner: String = ""
var last_ranking: Array = []

func _process(delta: float) -> void:
	if state == State.SHOT_PHASE or state == State.SUDDEN_DEATH:
		time_left -= delta
		if time_left <= 0.0:
			_end_phase()

# ---------------------------------------------------------------- Steuerung

func start_match(new_mode: int, plist: Array, ids: Array = []) -> void:
	mode = new_mode
	course_ids = ids if not ids.is_empty() else CourseData.match_set()
	players.clear()
	for p in plist:
		players[p["id"]] = {
			"id": p["id"], "name": p.get("name", "?"), "color": p.get("color", Color.WHITE),
			"total": 0, "strokes": 0, "finished": false, "t": 0.0,
			"is_local": p["id"] == local_id, "kind": p.get("kind", "remote"), "pin_dist": INF,
		}
	hole_index = 0
	sd_winner = ""
	sudden_death_ids.clear()
	players_changed.emit()
	_load_hole()

func _load_hole() -> void:
	for p in players.values():
		p["strokes"] = 0; p["finished"] = false; p["t"] = 0.0
	_set_state(State.LOADING_MAP)
	course_requested.emit(course_ids[hole_index], hole_index)

## Von GameScene aufgerufen, sobald die Bahn aufgebaut ist.
func map_ready() -> void:
	if state == State.LOADING_MAP:
		time_left = MatchRules.HOLE_TIME
		_set_state(State.SHOT_PHASE)

func report_shot(id: String) -> void:
	if players.has(id) and not players[id]["finished"]:
		players[id]["strokes"] += 1
		if players[id]["strokes"] >= MatchRules.MAX_STROKES:
			report_sunk(id, false)
		players_changed.emit()

func report_sunk(id: String, success: bool = true) -> void:
	if not players.has(id) or players[id]["finished"] or state != State.SHOT_PHASE:
		return
	var p: Dictionary = players[id]
	p["finished"] = success
	p["t"] = MatchRules.HOLE_TIME - time_left
	if not success:
		p["strokes"] = MatchRules.MAX_STROKES
		p["finished"] = true
		p["dnf"] = true
	players_changed.emit()
	_check_all_done()

## Sudden Death: Ball ist zur Ruhe gekommen, dist = Abstand zum Pin.
func report_pin_result(id: String, dist: float) -> void:
	if state != State.SUDDEN_DEATH or not players.has(id):
		return
	players[id]["pin_dist"] = dist
	players_changed.emit()
	var all_in := true
	for sid in sudden_death_ids:
		if players[sid]["pin_dist"] == INF:
			all_in = false
	if all_in:
		_end_phase()

func _check_all_done() -> void:
	for p in players.values():
		if not p["finished"]:
			return
	_end_phase()

func _end_phase() -> void:
	if state == State.SHOT_PHASE:
		_finish_hole()
	elif state == State.SUDDEN_DEATH:
		_finish_sudden_death()

# ---------------------------------------------------------------- Ablauf

func _finish_hole() -> void:
	var par: int = int(CourseData.get_course(course_ids[hole_index])["par"])
	var summary: Array = []
	for p in players.values():
		var s := MatchRules.hole_score(int(p["strokes"]), bool(p["finished"]) and not p.get("dnf", false), par)
		p["total"] += s
		p["dnf"] = false
		summary.append({"id": p["id"], "name": p["name"], "hole_score": s, "total": p["total"]})
	_set_state(State.HOLE_RESULT)
	hole_finished.emit(summary)
	await get_tree().create_timer(3.0).timeout
	if state != State.HOLE_RESULT:
		return   # Match wurde abgebrochen
	hole_index += 1
	if hole_index < course_ids.size():
		_load_hole()
	else:
		_after_last_hole()

func _after_last_hole() -> void:
	var plist: Array = players.values()
	if mode == Mode.QUICK_DM and MatchRules.needs_sudden_death(plist):
		_start_sudden_death(MatchRules.leaders(plist))
	else:
		_finish_match()

func _start_sudden_death(ids: Array) -> void:
	sudden_death_ids = ids
	for id in ids:
		players[id]["pin_dist"] = INF
	_set_state(State.LOADING_MAP)
	course_requested.emit("pin_shot", course_ids.size())

func map_ready_sudden_death() -> void:
	time_left = MatchRules.SUDDEN_DEATH_TIME
	_set_state(State.SUDDEN_DEATH)

func _finish_sudden_death() -> void:
	var dists := {}
	for id in sudden_death_ids:
		dists[id] = players[id]["pin_dist"]
	var w := MatchRules.pin_winner(dists)
	if w == "" and not _all_inf(dists):
		# echter Gleichstand -> nochmal
		_start_sudden_death(sudden_death_ids)
		return
	if w == "" and _all_inf(dists):
		w = str(sudden_death_ids[0])   # niemand hat geschossen: Fallback
	sd_winner = w
	_finish_match()

func _all_inf(d: Dictionary) -> bool:
	for v in d.values():
		if v != INF:
			return false
	return true

func _finish_match() -> void:
	last_ranking = MatchRules.ranking(players.values(), sd_winner)
	_set_state(State.MATCH_RESULT)
	for r in last_ranking:
		if r["id"] == local_id:
			var reward := MatchRules.coins_for_rank(int(r["rank"]), players.size())
			if mode != Mode.PRACTICE:
				Progression.add_coins(reward)
			r["reward"] = reward
	match_finished.emit(last_ranking)

func abort_match() -> void:
	_set_state(State.IDLE)
	players.clear()

func _set_state(s: int) -> void:
	var old := state
	state = s
	state_changed.emit(s, old)
