class_name GameScene
extends Node2D
## Spiel-Szene: verbindet GameManager (Regeln) mit Course/Ball/Netz/Ghosts/Bots/HUD.

signal exit_requested

const COURSE_SIZE := Vector2(720, 960)

var world: Node2D
var course: Course
var ball: Ball
var aim: AimController
var hud: Hud
var remotes: Dictionary = {}          # id -> RemoteBall (Netz-Spieler, Ghosts, Bots)
var ghost_tracks: Dictionary = {}     # id -> PackedFloat32Array (aktuelle Bahn)
var ghost_sink_time: Dictionary = {}  # id -> Sekunden
var ghost_strokes: Dictionary = {}    # id -> Schlaege
var bots: Dictionary = {}             # id -> {timer, strokes_left}
var recorder := GhostRecorder.new()
var _t: float = 0.0
var _net_acc: float = 0.0
var _sudden_death: bool = false
var _pending_hole_fx: CPUParticles2D = null

func _ready() -> void:
	world = Node2D.new()
	add_child(world)
	course = Course.new()
	world.add_child(course)
	ball = Ball.new()
	ball.z_index = 3
	world.add_child(ball)
	aim = AimController.new()
	aim.ball = ball
	world.add_child(aim)
	hud = Hud.new()
	add_child(hud)
	hud.spin_changed.connect(func(v: float): aim.curve = v)
	hud.exit_pressed.connect(func(): GameManager.abort_match(); exit_requested.emit())
	hud.continue_pressed.connect(func(): GameManager.abort_match(); exit_requested.emit())
	aim.shot.connect(_on_local_shot)
	aim.power_changed = hud.set_power
	ball.sunk.connect(_on_local_sunk)
	ball.stopped.connect(_on_local_stopped)
	ball.fell_in_water.connect(func(): _local_stroke(); hud.toast("Wasser! +1 Schlag"))
	get_viewport().size_changed.connect(_layout)
	GameManager.course_requested.connect(_on_course_requested)
	GameManager.state_changed.connect(_on_state)
	GameManager.hole_finished.connect(hud.show_hole_summary)
	GameManager.match_finished.connect(hud.show_match_result)
	GameManager.players_changed.connect(func(): hud.refresh_players())
	Net.event_received.connect(_on_net_event)
	_layout()

func _exit_tree() -> void:
	for sig in [GameManager.course_requested, GameManager.state_changed, GameManager.hole_finished,
			GameManager.match_finished]:
		for c in sig.get_connections():
			if c["callable"].get_object() == self or c["callable"].get_object() == hud:
				sig.disconnect(c["callable"])
	if Net.event_received.is_connected(_on_net_event):
		Net.event_received.disconnect(_on_net_event)

func _layout() -> void:
	var vp := get_viewport_rect().size
	var s := minf(vp.x / COURSE_SIZE.x, (vp.y - 300.0) / COURSE_SIZE.y)
	world.scale = Vector2(s, s)
	world.position = Vector2((vp.x - COURSE_SIZE.x * s) * 0.5, 130.0)

# ------------------------------------------------------------------ Ablauf

func _on_course_requested(course_id: String, index: int) -> void:
	_sudden_death = course_id == "pin_shot"
	course.build(CourseData.get_course(course_id))
	_clear_remotes()
	_t = 0.0
	# lokaler Ball
	var inv := Progression
	ball.color = Catalog.BALLS[inv.equipped["ball"]]["color"]
	ball.apply_stats(inv.current_club_stats())
	ball.setup(course, course.tee_pos)
	_setup_trail()
	aim.enabled = false
	# Gegner (Netz / Bots / Ghosts)
	for id in GameManager.players:
		var p: Dictionary = GameManager.players[id]
		if p["is_local"]:
			continue
		if _sudden_death and not (id in GameManager.sudden_death_ids):
			continue
		var rb := RemoteBall.new()
		world.add_child(rb)
		rb.setup(id, p["name"], p["color"], p["kind"] == "ghost", course.tee_pos)
		remotes[id] = rb
		if p["kind"] == "bot":
			bots[id] = {"timer": randf_range(1.0, 2.5), "left": randi_range(2, 4)}
		elif p["kind"] == "ghost":
			_load_ghost_track(id, course_id)
	recorder.start(course_id, course.tee_pos)
	hud.setup_hole(course_id, index, course.par, _sudden_death)
	if _sudden_death:
		GameManager.map_ready_sudden_death()
	else:
		GameManager.map_ready()

func _on_state(new_state: int, _old: int) -> void:
	aim.enabled = new_state == GameManager.State.SHOT_PHASE or new_state == GameManager.State.SUDDEN_DEATH
	hud.on_state(new_state)
	if not aim.enabled:
		aim.cancel()

func _clear_remotes() -> void:
	for rb in remotes.values():
		rb.queue_free()
	remotes.clear(); bots.clear(); ghost_tracks.clear(); ghost_sink_time.clear(); ghost_strokes.clear()

func _setup_trail() -> void:
	if ball.trail:
		ball.trail.queue_free()
		ball.trail = null
	var tr := Cosmetics.make_trail(Progression.equipped["trail"])
	if tr:
		ball.add_child(tr)
		ball.trail = tr

# ------------------------------------------------------------------ Lokaler Spieler

func _on_local_shot(dir: Vector2, power: float, curve: float) -> void:
	if not ball.can_shoot():
		return
	ball.shoot(dir, power, curve)
	GameManager.report_shot(GameManager.local_id)
	Net.send_event("shot", {"id": Supa.user_id, "x": ball.position.x, "y": ball.position.y})

func _local_stroke() -> void:
	GameManager.report_shot(GameManager.local_id)

func _on_local_sunk() -> void:
	var fx := Cosmetics.make_hole_fx(Progression.equipped["fx"], course.hole_pos)
	world.add_child(fx)
	get_tree().create_timer(2.0).timeout.connect(fx.queue_free)
	hud.toast("Eingelocht!")
	var local: Dictionary = GameManager.players[GameManager.local_id]
	recorder.finish(int(local["strokes"]), _t, course.hole_pos)
	recorder.save_and_upload()
	GameManager.report_sunk(GameManager.local_id)
	Net.send_event("sunk", {"id": Supa.user_id, "t": _t, "strokes": local["strokes"]})

func _on_local_stopped(pos: Vector2) -> void:
	if _sudden_death:
		var d := pos.distance_to(course.hole_pos)
		GameManager.report_pin_result(GameManager.local_id, d)
		Net.send_event("pin", {"id": Supa.user_id, "d": d})

# ------------------------------------------------------------------ Frame

func _process(delta: float) -> void:
	var st := GameManager.state
	if st != GameManager.State.SHOT_PHASE and st != GameManager.State.SUDDEN_DEATH:
		return
	_t += delta
	if ball.trail:
		ball.trail.add_point(ball.global_position)
		while ball.trail.get_point_count() > 24:
			ball.trail.remove_point(0)
	recorder.tick(delta, _t, ball.position)
	_net_acc += delta
	if _net_acc >= 0.1:
		_net_acc = 0.0
		Net.send_event("pos", {"id": Supa.user_id, "x": snappedf(ball.position.x, 0.1), "y": snappedf(ball.position.y, 0.1)})
	_update_ghosts()
	_update_bots(delta)
	hud.set_time(GameManager.time_left)

func _update_ghosts() -> void:
	for id in ghost_tracks:
		var rb: RemoteBall = remotes.get(id)
		if rb == null:
			continue
		rb.set_target(GhostRecorder.position_at(ghost_tracks[id], _t))
		if not rb.finished and _t >= float(ghost_sink_time[id]) and GameManager.state == GameManager.State.SHOT_PHASE:
			rb.finished = true
			GameManager.players[id]["strokes"] = ghost_strokes[id]
			GameManager.report_sunk(id)

func _load_ghost_track(id: String, course_id: String) -> void:
	var g: Dictionary = GhostRecorder.load_local(course_id) if id == "ghost_self" else GameManager.players[id].get("ghost", {}).get(course_id, {})
	if g.is_empty():
		# Kein Ghost vorhanden -> Platzhalter-Lauf: gerade Linie vom Tee zum Loch in ~par*6 s
		var dur := float(course.par) * 6.0
		g = {"samples": [0.0, course.tee_pos.x, course.tee_pos.y, dur, course.hole_pos.x, course.hole_pos.y],
			"strokes": course.par, "duration": dur}
	ghost_tracks[id] = PackedFloat32Array(g["samples"])
	ghost_sink_time[id] = float(g["duration"])
	ghost_strokes[id] = int(g["strokes"])

func _update_bots(delta: float) -> void:
	if _sudden_death:
		_update_bots_pin(delta)
		return
	for id in bots:
		var b: Dictionary = bots[id]
		var rb: RemoteBall = remotes[id]
		if GameManager.players[id]["finished"]:
			continue
		b["timer"] -= delta
		if b["timer"] <= 0.0:
			b["timer"] = randf_range(1.4, 2.6)
			b["left"] -= 1
			GameManager.report_shot(id)
			if b["left"] <= 0:
				rb.set_target(course.hole_pos)
				GameManager.report_sunk(id)
			else:
				rb.set_target(rb._target.lerp(course.hole_pos, randf_range(0.35, 0.6)))

func _update_bots_pin(delta: float) -> void:
	for id in bots:
		var b: Dictionary = bots[id]
		b["timer"] -= delta
		if b["timer"] <= 0.0 and GameManager.players[id]["pin_dist"] == INF:
			var d := randf_range(10.0, 160.0)
			remotes[id].set_target(course.hole_pos + Vector2.from_angle(randf() * TAU) * d)
			GameManager.report_pin_result(id, d)

# ------------------------------------------------------------------ Netz

func _on_net_event(event: String, p: Dictionary) -> void:
	var id: String = str(p.get("id", ""))
	if not remotes.has(id):
		return
	match event:
		"pos":
			remotes[id].set_target(Vector2(float(p["x"]), float(p["y"])))
		"shot":
			GameManager.report_shot(id)
		"sunk":
			remotes[id].set_target(course.hole_pos)
			GameManager.players[id]["strokes"] = int(p.get("strokes", 1))
			GameManager.report_sunk(id)
		"pin":
			GameManager.report_pin_result(id, float(p.get("d", INF)))
