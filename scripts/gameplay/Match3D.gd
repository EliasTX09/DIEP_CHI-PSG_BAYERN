class_name Match3D
extends Node3D
## Spiel-Szene (Game.tscn): steuert ein komplettes Match ueber mehrere Bahnen.
##  - baut pro Bahn den Kurs, setzt alle Baelle aufs Tee (lokaler Spieler, Bots, Online-Gegner)
##  - Touch-Steuerung: am Ball ziehen = zielen (3D-Kraftpfeil + Flugbahn-Vorschau), sonst Kamera drehen, Pinch = Zoom
##  - alle spielen gleichzeitig; Bahn endet, wenn alle fertig sind oder die Zeit ablaeuft
##  - Style-Punkte, Zeitlupen-Kamera am Loch, Replay, Loch-Explosionen, Emotes
##  - Online: eigene Baelle senden Position/Schlaege per NetworkManager, fremde werden interpoliert

enum Phase { LOADING, INTRO, PLAY, HOLE_END, MATCH_END }

const INTRO_TIME := 2.6
const HOLE_END_TIME := 5.5
const NET_INTERVAL := 0.1
const PREVIEW_DOTS := 64

## Laufzeit-Daten eines Spielers.
class PlayerRec:
	var id: String = ""
	var name: String = ""
	var kind: String = "local"
	var color: Color = Color.WHITE
	var entry: Dictionary = {}
	var ball: Ball3D = null
	var remote: RemoteBall3D = null
	var brain: BotBrain = null
	var tag: BallTag = null
	var strokes: int = 0
	var total: int = 0
	var holed: bool = false
	var done: bool = false
	var hole_time: float = 0.0
	var total_time: float = 0.0
	var style: int = 0
	var holes_in_one: int = 0
	var net_acc: float = 0.0
	var last_sent: Vector3 = Vector3.INF

	func node() -> Node3D:
		if ball != null:
			return ball
		return remote

var config: Dictionary = {}
var course: Course3D = null
var hole_index: int = -1
var players: Array[PlayerRec] = []
var local: PlayerRec = null
var rig: CameraManager3D
var hud: GameHUD
var phase: int = Phase.LOADING
var phase_time: float = 0.0
var time_left: float = 0.0
var online: bool = false
var mode: String = "quick"
## Tests: der lokale Spieler wird von einer KI gesteuert, Ergebnis-Screens laufen automatisch weiter.
var auto_play: bool = false
var finished: bool = false
var result_rewards: Dictionary = {}
var final_ranking: Array = []

var _touches: Dictionary = {}
var _aiming: bool = false
var _aim_index: int = -1
var _aim_start: Vector2 = Vector2.ZERO
var _aim_drag: Vector2 = Vector2.ZERO
var _aim_power: float = 0.0
var _aim_dir: Vector3 = Vector3.FORWARD
var _pinch_dist: float = 0.0
var _preview_dirty: bool = false
var _preview_cool: float = 0.0
## Gummiband: Wurzel-Knoten (am Ball, +z zeigt nach hinten), leuchtendes Band (jedes Bild neu gebaut) + Griff
var _arrow: Node3D
var _band_mesh: MeshInstance3D
var _band_im: ImmediateMesh
var _band_mat: ShaderMaterial
var _knob_mat: ShaderMaterial
## Punkt-Kette: Punkte am Boden (Rollen/Aufsetzen), Punkte entlang des Flugbogens und deren Bodenschatten
var _dots: MultiMeshInstance3D
var _arc_dots: MultiMeshInstance3D
var _air_dots: MultiMeshInstance3D
## true = die Vorschau endet im Aus (Kette rot)
var _dots_out: bool = false
var _landing: MeshInstance3D
## Zielkreis am vorhergesagten Ende des Schlags
var _target_ring: MeshInstance3D
## Gummiband als gedaempfte Feder: Knauf folgt dem Finger mit Nachschwingen, beim Loslassen schnellt er zurueck
const BAND_K := 230.0
const BAND_DAMP := 17.0
var _band_knob: Vector3 = Vector3.INF
var _band_knob_v: Vector3 = Vector3.ZERO
var _band_release: float = 0.0
var _preview_spin: Vector2 = Vector2.ZERO
## Letzter Boden-Punkt der Kette (Zielkreis; auch fuer Tests - der Renderer wird dafuer nicht ausgelesen)
var _preview_end: Vector3 = Vector3.INF
var _preview_chip: bool = false
var _slowmo: bool = false
var _slowmo_used: bool = false
var _slowmo_timer: float = 0.0
var _slowmo_check: float = 0.0
var _bot_turn: int = 0
var _local_brain: BotBrain = null
var _replay_ghost: Node3D = null
var _replay_points: PackedVector3Array = PackedVector3Array()
var _replay_pos: float = 0.0
var _replay_delay: float = -1.0
var _board_timer: float = 0.0
var _flag_raise: float = 0.0
var _rng := RandomNumberGenerator.new()
var _intro_follow_done: bool = false
var _hole_start_received: int = -1

# ================================================================ Start

func _ready() -> void:
	config = GameManager.match_config
	if config.is_empty() or not config.has("courses"):
		config = GameManager.make_bot_match("emerald", 3, 3)
		GameManager.match_config = config
	mode = str(config.get("mode", "quick"))
	online = bool(config.get("online", false))
	_rng.seed = int(config.get("seed", 1))
	rig = CameraManager3D.new()
	rig.name = "CameraRig"
	add_child(rig)
	var hud_scene: PackedScene = load("res://scenes/GameHUD.tscn")
	hud = hud_scene.instantiate() as GameHUD
	add_child(hud)
	hud.top_view_toggled.connect(func(on: bool) -> void: rig.set_top(on))
	hud.emote_chosen.connect(_on_local_emote)
	hud.exit_requested.connect(leave_match)
	hud.continue_pressed.connect(leave_match)
	hud.skip_pressed.connect(_skip_hole_end)
	_build_aim_visuals()
	_build_players()
	if online:
		NetworkManager.game_event.connect(_on_game_event)
	_start_hole(0)

func _exit_tree() -> void:
	Engine.time_scale = 1.0
	BallTag.hide_names = false
	SoundManager.set_wind(0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and hud != null and phase != Phase.MATCH_END:
		hud.confirm_exit()

func _build_players() -> void:
	players.clear()
	var list: Array = config.get("players", [])
	for i in mini(list.size(), Catalog.MAX_PLAYERS):
		var e: Dictionary = list[i]
		var rec := PlayerRec.new()
		rec.id = str(e.get("id", "p%d" % i))
		rec.name = str(e.get("name", "Spieler"))
		rec.kind = str(e.get("kind", "bot"))
		rec.color = Catalog.PLAYER_COLORS[int(e.get("color", i)) % Catalog.PLAYER_COLORS.size()]
		rec.entry = e
		players.append(rec)
		if rec.kind == "local":
			local = rec
	if local == null and players.size() > 0:
		local = players[0]
		local.kind = "local"

func _profile_for(rec: PlayerRec) -> Dictionary:
	if rec.kind == "local":
		return GameManager.shot_profile()
	var skill: float = float(rec.entry.get("skill", 0.5))
	var ball_id: String = str(rec.entry.get("ball", "standard"))
	if skill < 0.4:
		return GameManager.make_shot_profile("allround_common", 1, ball_id)
	if skill < 0.7:
		return GameManager.make_shot_profile("allround_rare", 3, ball_id)
	return GameManager.make_shot_profile("iron_epic", 4, ball_id)

# ================================================================ Bahn starten

func _start_hole(index: int) -> void:
	hole_index = index
	phase = Phase.LOADING
	_cancel_aim()
	_end_slowmo()
	_stop_replay()
	_replay_delay = -1.0
	for rec in players:
		if rec.ball != null:
			rec.ball.queue_free()
			rec.ball = null
		if rec.remote != null:
			rec.remote.queue_free()
			rec.remote = null
		if rec.tag != null:
			rec.tag.queue_free()
			rec.tag = null
		rec.brain = null
		rec.strokes = 0
		rec.holed = false
		rec.done = false
		rec.hole_time = 0.0
		rec.last_sent = Vector3.INF
	if course != null:
		course.queue_free()
		course = null
	var courses: Array = config.get("courses", ["e1"])
	var course_id: String = str(courses[clampi(index, 0, courses.size() - 1)])
	var seed_value: int = GameManager.daily_seed() if course_id == "daily" else int(config.get("seed", 0)) + index
	course = CourseBuilder3D.build(course_id, seed_value)
	course.clock_running = false
	add_child(course)
	rig.course = course
	time_left = course.time_limit
	var n: int = players.size()
	for i in n:
		var rec: PlayerRec = players[i]
		var offset: float = clampf((float(i) - float(n - 1) * 0.5) * 0.62, -1.9, 1.9)
		var tee: Transform3D = course.tee.translated_local(Vector3(offset, 0.0, 0.0))
		if rec.kind == "remote":
			rec.remote = RemoteBall3D.new()
			course.add_child(rec.remote)
			rec.remote.setup(rec.id, str(rec.entry.get("ball", "standard")), str(rec.entry.get("trail", "none")), rec.color, tee.origin)
		else:
			rec.ball = Ball3D.new()
			rec.ball.name = "Ball_" + rec.id
			course.add_child(rec.ball)
			rec.ball.setup(course, rec.id, _profile_for(rec), str(rec.entry.get("ball", "standard")), str(rec.entry.get("trail", "none")), rec == local)
			rec.ball.place_on_tee(tee)
			rec.ball.shot_fired.connect(_on_ball_shot.bind(rec))
			rec.ball.stopped.connect(_on_ball_stopped.bind(rec))
			rec.ball.holed.connect(_on_ball_holed.bind(rec))
			rec.ball.fell_out.connect(_on_ball_out.bind(rec))
			rec.ball.respawned.connect(_on_ball_respawned.bind(rec))
			rec.ball.style_event.connect(_on_ball_style.bind(rec))
			rec.ball.impacted.connect(_on_ball_impact.bind(rec))
			if rec.kind == "bot":
				rec.brain = BotBrain.new(rec.ball, course, float(rec.entry.get("skill", 0.5)), _rng.randi())
				# Adaptiv: je mehr Trophaeen der Spieler auf DIESER Bahn hat, desto genauer und abkuerzungsfreudiger
				SmartBotController.configure(rec.brain, GameManager.course_trophies(course.course_id))
		rec.tag = BallTag.new(rec.name, rec.color, rec == local)
		rec.tag.target = rec.node()
		course.add_child(rec.tag)
	_local_brain = null
	if auto_play and local != null and local.ball != null:
		_local_brain = BotBrain.new(local.ball, course, 0.8, _rng.randi())
	var fwd: Vector3 = -course.tee.basis.z
	rig.set_overview(course.bounds, fwd)
	rig.distance = 11.0
	rig.pitch = 0.45
	rig.follow(local.node(), true)
	rig.aim_at(fwd, true)
	rig.set_top(true)
	hud.set_top_view(true)
	hud.setup_hole(index, courses.size(), course.title, course.par)
	hud.set_strokes(0, course.par)
	hud.set_time(time_left)
	hud.set_hint("")
	hud.set_chip_mode(course.one_shot)
	hud.show_banner(course.title, "Bahn %d · Par %d" % [index + 1, course.par], INTRO_TIME - 0.6)
	_refresh_board()
	_intro_follow_done = false
	phase = Phase.INTRO
	phase_time = 0.0
	if online and NetworkManager.is_host():
		NetworkManager.send_game_event("hole_start", {"i": index})

func _begin_play() -> void:
	phase = Phase.PLAY
	phase_time = 0.0
	course.set_time(0.0)
	course.clock_running = true
	for rec in players:
		if rec.ball != null:
			rec.ball.unfreeze()
	hud.show_banner("LOS!", "", 0.7, UIKit.GREEN)
	hud.set_hint("Ziehe am Ball, um zu zielen" if not auto_play else "")
	SoundManager.play("go")
	if not course.shortcut.is_empty() and not auto_play and not course.one_shot:
		hud.toast("Abkürzung: durchs Felsentor auf die Schanze – spart Schläge, daneben ist Aus!")

# ================================================================ Frame-Logik

func _process(delta: float) -> void:
	var real_dt: float = delta / maxf(0.05, Engine.time_scale)
	phase_time += delta
	match phase:
		Phase.INTRO:
			if not _intro_follow_done and phase_time > INTRO_TIME * 0.6:
				_intro_follow_done = true
				rig.set_top(false)
				hud.set_top_view(false)
			if phase_time >= INTRO_TIME:
				_begin_play()
		Phase.PLAY:
			_update_play(delta, real_dt)
		Phase.HOLE_END:
			var wait: float = 2.0 if auto_play else HOLE_END_TIME
			var host_drives: bool = online and not NetworkManager.is_host()
			if host_drives:
				# Nicht-Hosts warten auf das Startsignal des Hosts (mit Sicherheitsfrist)
				if _hole_start_received > hole_index or phase_time >= wait + 4.0:
					_advance_after_hole()
			elif phase_time >= wait:
				_advance_after_hole()
		_:
			pass
	_update_flag(real_dt)

func _update_play(delta: float, real_dt: float) -> void:
	time_left -= delta
	hud.set_time(time_left)
	_board_timer -= real_dt
	if _board_timer <= 0.0:
		_board_timer = 0.3
		_refresh_board()
	# Bots: Zeitsteuerung fuer alle, Rechenzeit reihum fuer einen
	var thinkers: Array[BotBrain] = []
	for rec in players:
		if rec.brain != null and not rec.done:
			rec.brain.update(delta)
			if rec.brain.wants_cpu():
				thinkers.append(rec.brain)
	if _local_brain != null and not local.done:
		_local_brain.update(delta)
		if _local_brain.wants_cpu():
			thinkers.append(_local_brain)
	if thinkers.size() > 0:
		_bot_turn = (_bot_turn + 1) % thinkers.size()
		thinkers[_bot_turn].think(get_world_3d().direct_space_state)
	# Zielen: Vorschau aktualisieren (auch wenn Spin oder Schlagart waehrend des Zielens geaendert werden)
	if _aiming and (hud.spin != _preview_spin or hud.chip_mode != _preview_chip):
		_preview_dirty = true
	if _aiming or _band_release > 0.0:
		_update_band(real_dt)
	if _aiming:
		_preview_cool -= real_dt
		if _preview_dirty and _preview_cool <= 0.0:
			_preview_dirty = false
			_preview_cool = 0.035
			_update_preview()
	# Windrauschen bei Fluegen
	if local != null and local.ball != null and local.ball.state == Ball3D.State.MOVING and local.ball.air_time > 0.2:
		SoundManager.set_wind(clampf(local.ball.speed() / 26.0, 0.0, 1.0))
	else:
		SoundManager.set_wind(0.0)
	_update_slowmo(real_dt)
	_update_replay(real_dt)
	if online:
		_net_tick(real_dt)
	# Bahn-Ende
	if time_left <= 0.0:
		_end_hole()

func _update_flag(dt: float) -> void:
	if course == null or not course.has_meta("flag"):
		return
	var near := false
	for rec in players:
		var n: Node3D = rec.node()
		if n != null and not rec.holed and n.global_position.distance_to(course.hole_pos) < 3.5:
			near = true
			break
	_flag_raise = move_toward(_flag_raise, 1.0 if near else 0.0, dt * 3.0)
	var flag: Node3D = course.get_meta("flag")
	if is_instance_valid(flag):
		flag.position.y = course.hole_pos.y + _flag_raise * 2.6

func _refresh_board() -> void:
	var rows: Array = []
	for rec in players:
		rows.append({"name": rec.name, "color": rec.color, "strokes": rec.strokes, "total": rec.total + rec.strokes,
			"holed": rec.holed, "done": rec.done, "local": rec == local})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["total"]) != int(b["total"]):
			return int(a["total"]) < int(b["total"])
		return str(a["name"]) < str(b["name"]))
	hud.set_leaderboard(rows)

# ================================================================ Eingabe: Zielen / Kamera

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_down(t.index, t.position)
		else:
			_touch_up(t.index)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		_touch_move(d.index, d.position, d.relative)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			rig.zoom(0.9)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			rig.zoom(1.1)

func _can_aim() -> bool:
	return phase == Phase.PLAY and not auto_play and local != null and local.ball != null and local.ball.can_shoot() and not local.done

func _touch_down(index: int, pos: Vector2) -> void:
	if hud.is_over_widget(pos):
		return
	_touches[index] = pos
	if _touches.size() == 1:
		var vh: float = get_viewport().get_visible_rect().size.y
		var ball_screen: Vector2 = rig.target_screen_pos()
		if _can_aim() and ball_screen != Vector2.INF and pos.distance_to(ball_screen) < vh * 0.17:
			_aiming = true
			_aim_index = index
			_aim_start = pos
			_aim_drag = Vector2.ZERO
			_aim_power = 0.0
			# Sobald der Ball beruehrt wird: alle Namen sofort aus, Kamera faehrt naeher heran (Hintergrund unscharf)
			BallTag.hide_names = true
			rig.set_aiming(true)
			hud.set_hint("Zurückziehen = Kraft · Loslassen = Schlag")
	elif _touches.size() == 2:
		_cancel_aim()
		var keys: Array = _touches.keys()
		_pinch_dist = (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])

func _touch_move(index: int, pos: Vector2, relative: Vector2) -> void:
	if not _touches.has(index):
		return
	_touches[index] = pos
	if _aiming and index == _aim_index:
		var vh: float = get_viewport().get_visible_rect().size.y
		_aim_drag = pos - _aim_start
		var length: float = _aim_drag.length()
		_aim_power = 0.0 if length < vh * 0.035 else clampf((length - vh * 0.035) / (vh * 0.32), 0.0, 1.0)
		_aim_dir = rig.aim_direction(_aim_drag)
		_preview_dirty = true
		hud.set_power(_aim_power, true)
	elif _touches.size() >= 2:
		var keys: Array = _touches.keys()
		var dist: float = (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]])
		if _pinch_dist > 10.0 and dist > 10.0:
			rig.zoom(_pinch_dist / dist)
		_pinch_dist = dist
	else:
		rig.orbit(relative)

func _touch_up(index: int) -> void:
	if not _touches.has(index):
		return
	_touches.erase(index)
	if _aiming and index == _aim_index:
		var power: float = _aim_power
		var dir: Vector3 = _aim_dir
		if power >= 0.05 and _can_aim():
			# Band schnellt nach vorn zurueck (kurze Feder-Animation, dann aus)
			_band_release = 0.18
		_cancel_aim()
		if power >= 0.05 and _can_aim():
			local.ball.shoot(dir, power, hud.chip_mode, hud.spin)
	_pinch_dist = 0.0

func _cancel_aim() -> void:
	_aiming = false
	_aim_index = -1
	BallTag.hide_names = false
	if rig != null:
		rig.set_aiming(false)
	_aim_power = 0.0
	if _arrow != null:
		if _band_release <= 0.0:
			_arrow.visible = false
			_band_knob = Vector3.INF
		_dots.visible = false
		_arc_dots.visible = false
		_air_dots.visible = false
		_landing.visible = false
		_target_ring.visible = false
	if hud != null:
		hud.set_power(0.0, false)
		if phase == Phase.PLAY and not auto_play:
			hud.set_hint("Ziehe am Ball, um zu zielen" if _can_aim() else "")

## Ziel-Optik: leuchtendes Gummiband HINTER dem Ball (spannt sich Richtung Finger) und eine Punkt-Kette VOR dem Ball,
## die der Kruemmung der Flugbahn folgt (Punkte im Bogen + deren Schatten am Boden, Rollen als Punkte am Boden).
func _build_aim_visuals() -> void:
	# --- Gummiband: Band (Neon-Kern, weisser Rand) + Griff am Fingerende ---
	_arrow = Node3D.new()
	_arrow.name = "AimBand"
	_arrow.visible = false
	add_child(_arrow)
	_band_mat = Mat.shader("aim_band", {"core_color": GameHUD.power_color(0.0)})
	_band_mat.render_priority = 4
	_band_im = ImmediateMesh.new()
	_band_mesh = MeshInstance3D.new()
	_band_mesh.name = "Band"
	_band_mesh.mesh = _band_im
	_band_mesh.material_override = _band_mat
	_band_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Das Band wird jedes Bild neu gebaut -> grosszuegige Grenzen, damit es nie weggeschnitten wird
	_band_mesh.custom_aabb = AABB(Vector3(-6.0, -2.0, -6.0), Vector3(12.0, 4.0, 12.0))
	_arrow.add_child(_band_mesh)
	_knob_mat = Mat.shader("aim_marker", {"core_color": GameHUD.power_color(0.0), "rim_color": Color(1.0, 1.0, 1.0),
		"rim_width": 0.34, "glow": 1.6})
	_knob_mat.render_priority = 5
	var knob := _marker_quad(0.5, _knob_mat)
	knob.name = "Knob"
	_arrow.add_child(knob)
	# --- Punkt-Kette: Boden-Punkte (weiss-gelb), Bogen-Punkte (Billboards im Flug), Bodenschatten des Bogens ---
	_dots = _make_dot_layer(0.27, false, {"glow": 1.3}, 3)
	_arc_dots = _make_dot_layer(0.24, true, {"glow": 1.4, "rim_width": 0.36}, 4)
	_air_dots = _make_dot_layer(0.18, false, {"core_color": Color(0.02, 0.05, 0.02), "rim_color": Color(0.02, 0.05, 0.02),
		"glow": 1.0, "opacity": 0.34}, 1)
	_set_dots_out(false)
	# Aufsetz-Ring eines Chips (Groesse = Streuung des Schlaegers)
	_landing = _marker_quad(1.0, Mat.shader("aim_marker", {"shape": 1, "ring_inner": 0.8, "core_color": Color(1.0, 0.92, 0.45, 0.95),
		"rim_color": Color(1.0, 0.62, 0.12), "glow": 1.3}))
	_landing.name = "LandingRing"
	_landing.visible = false
	add_child(_landing)
	# Zielkreis am Ende der Kette: pulsiert dezent
	_target_ring = _marker_quad(0.66, Mat.shader("aim_marker", {"shape": 1, "ring_inner": 0.58, "core_color": Color(1.0, 1.0, 1.0),
		"rim_color": Color(1.0, 0.85, 0.3), "glow": 1.45, "pulse": 1.0}))
	_target_ring.name = "TargetRing"
	(_target_ring.material_override as ShaderMaterial).render_priority = 5
	_target_ring.visible = false
	add_child(_target_ring)

## Flaches Quad (liegt auf dem Boden, Normale +Y) mit Marker-Material.
func _marker_quad(size: float, mat: ShaderMaterial) -> MeshInstance3D:
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _make_dot_layer(size: float, billboard: bool, params: Dictionary, priority: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	if billboard:
		var quad := QuadMesh.new()
		quad.size = Vector2(size, size)
		mm.mesh = quad
	else:
		var plane := PlaneMesh.new()
		plane.size = Vector2(size, size)
		mm.mesh = plane
	mm.instance_count = PREVIEW_DOTS
	mm.visible_instance_count = 0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var p: Dictionary = params.duplicate()
	p["billboard"] = billboard
	var mat := Mat.shader("aim_marker", p)
	mat.render_priority = priority
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Punkte liegen ueberall auf der Bahn -> nie wegschneiden
	mmi.custom_aabb = AABB(Vector3(-2000.0, -500.0, -2000.0), Vector3(4000.0, 1000.0, 4000.0))
	mmi.visible = false
	add_child(mmi)
	return mmi

## Punkt-Kette weiss-gelb (normal) oder rot (Vorschau endet im Aus).
func _set_dots_out(out: bool) -> void:
	_dots_out = out
	var core: Color = Color(1.0, 0.42, 0.36) if out else Color(1.0, 0.98, 0.86)
	var rim: Color = Color(0.95, 0.12, 0.1) if out else Color(1.0, 0.8, 0.22)
	for layer: MultiMeshInstance3D in [_dots, _arc_dots]:
		var m := layer.material_override as ShaderMaterial
		m.set_shader_parameter("core_color", core)
		m.set_shader_parameter("rim_color", rim)

## Breite des Bands am Ball und am Griff (m) und Zahl der Abschnitte
const BAND_W_BALL := 0.58
const BAND_W_KNOB := 0.2
const BAND_SEGMENTS := 18
## Laenge des Bands bei voller Kraft (m): kurz genug, dass der Griff auch im Ziel-Zoom ueber der Bedienleiste bleibt
const BAND_MAX := 2.4

## Gummiband + Punkt-Kette (echte Simulation inkl. Abprallern, Rampen und Gadgets).
## Laenge der Kette = Guide-Wert des Schlaegers, Groesse des Landerings = Streuung (Accuracy).
## Gummiband hinter dem Ball, jedes Bild neu: Der Griff haengt an einer gedaempften Feder (schwingt nach, wenn der
## Finger die Richtung wechselt). Das Band biegt sich mit dem Nachschwingen, wird gespannt schmaler und locker
## breiter. Nach dem Loslassen schnellt der Griff zum Ball zurueck.
func _update_band(dt: float) -> void:
	if local == null or local.ball == null or _arrow == null:
		return
	var origin: Vector3 = local.ball.global_position + Vector3(0.0, -Ball3D.RADIUS + 0.05, 0.0)
	var back := Vector3(-_aim_dir.x, 0.0, -_aim_dir.z).normalized()
	if back == Vector3.ZERO:
		back = Vector3.BACK
	var power: float = _aim_power
	if _band_release > 0.0:
		_band_release -= dt
		power = 0.0
		if _band_release <= 0.0:
			_arrow.visible = false
			_band_knob = Vector3.INF
			return
	elif power < 0.02:
		_arrow.visible = false
		return
	var want_len: float = 0.0 if _band_release > 0.0 else 0.55 + (BAND_MAX - 0.55) * power
	var want: Vector3 = origin + back * want_len
	if _band_knob == Vector3.INF:
		_band_knob = origin + back * 0.3
		_band_knob_v = Vector3.ZERO
	var left: float = minf(dt, 0.1)
	var k: float = BAND_K * (4.0 if _band_release > 0.0 else 1.0)
	while left > 0.0:
		var h: float = minf(left, 1.0 / 120.0)
		_band_knob_v += ((want - _band_knob) * k - _band_knob_v * BAND_DAMP) * h
		_band_knob += _band_knob_v * h
		left -= h
	_band_knob.y = origin.y
	if _band_release <= 0.0:
		var col: Color = GameHUD.power_color(power)
		_band_mat.set_shader_parameter("core_color", col)
		_band_mat.set_shader_parameter("tension", power)
		_knob_mat.set_shader_parameter("core_color", col)
	_arrow.visible = true
	_arrow.global_position = origin
	_arrow.global_basis = Basis.looking_at(-back, Vector3.UP)
	# Griff im Band-Rahmen (z = nach hinten), Nachschwingen quer zum Band
	var tip: Vector3 = _arrow.global_transform.affine_inverse() * _band_knob
	var side_v: float = (_arrow.global_basis.inverse() * _band_knob_v).x
	var slack: float = clampf(1.0 - tip.length() / maxf(0.3, want_len), 0.0, 1.0) if want_len > 0.0 else 0.0
	_build_band(tip, clampf(-side_v * 0.05, -0.6, 0.6), slack)
	(_arrow.get_node("Knob") as Node3D).position = tip + Vector3(0.0, 0.004, 0.0)

## Baut das Band als Streifen entlang einer Bezier-Kurve vom Ball zum Griff.
## bend = seitliche Auslenkung der Mitte (Nachschwingen), slack = wie locker das Band noch ist (0 = gespannt).
func _build_band(tip: Vector3, bend: float, slack: float) -> void:
	_band_im.clear_surfaces()
	var length: float = tip.length()
	if length < 0.06:
		_band_mesh.visible = false
		return
	_band_mesh.visible = true
	var dir: Vector3 = tip / length
	var lateral: Vector3 = Vector3.UP.cross(dir).normalized()
	var p0 := Vector3.ZERO
	var p1: Vector3 = tip * 0.5 + lateral * bend
	# gespannt = schmaler (das Gummi wird duenn), locker = breiter
	var stretch: float = clampf(length / BAND_MAX, 0.0, 1.0)
	var width_mul: float = lerpf(1.12, 0.78, stretch) * (1.0 + 0.25 * slack)
	_band_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in BAND_SEGMENTS + 1:
		var t: float = float(i) / float(BAND_SEGMENTS)
		var c: Vector3 = p0.lerp(p1, t).lerp(p1.lerp(tip, t), t)
		var tangent: Vector3 = (p1 - p0) * (2.0 * (1.0 - t)) + (tip - p1) * (2.0 * t)
		var side: Vector3 = Vector3.UP.cross(tangent.normalized()) if tangent.length() > 0.0001 else lateral
		var w: float = lerpf(BAND_W_BALL, BAND_W_KNOB, sqrt(t)) * width_mul * 0.5
		_band_im.surface_set_uv(Vector2(0.0, t))
		_band_im.surface_add_vertex(c - side * w)
		_band_im.surface_set_uv(Vector2(1.0, t))
		_band_im.surface_add_vertex(c + side * w)
	_band_im.surface_end()

func _update_preview() -> void:
	if local == null or local.ball == null or not _aiming:
		return
	var ball: Ball3D = local.ball
	if _aim_power < 0.02:
		_dots.visible = false
		_arc_dots.visible = false
		_air_dots.visible = false
		_landing.visible = false
		_target_ring.visible = false
		rig.set_aim_focus(Vector3.INF)
		return
	var origin: Vector3 = ball.global_position
	# Punkt-Kette
	var prof: Dictionary = ball.profile
	var guide: float = float(prof.get("guide", 1.0))
	var space := get_world_3d().direct_space_state
	_preview_spin = hud.spin
	_preview_chip = hud.chip_mode
	var res: Dictionary = ShotSim.predict_shot(course, space, origin, _aim_dir, _aim_power,
		hud.chip_mode, hud.spin, prof, guide, ball.ground_normal, 2)
	var pts: PackedVector3Array = res["points"]
	var max_dots: int = clampi(int(guide * 18.0), 8, PREVIEW_DOTS)
	var ground_mm: MultiMesh = _dots.multimesh
	var arc_mm: MultiMesh = _arc_dots.multimesh
	var air_mm: MultiMesh = _air_dots.multimesh
	var n_ground := 0
	var n_air := 0
	var last_ground := Transform3D()
	var spacing: float = 0.6
	var acc: float = spacing * 0.6
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = 1 | 4 | 8
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var seg: float = a.distance_to(b)
		while acc <= seg and n_ground + n_air < max_dots:
			var p: Vector3 = a.lerp(b, acc / maxf(seg, 0.0001))
			acc += spacing
			ray.from = p + Vector3.UP * 0.05
			ray.to = p + Vector3.DOWN * 40.0
			var hit: Dictionary = space.intersect_ray(ray)
			if hit.is_empty():
				continue
			var gp: Vector3 = hit["position"]
			var gn: Vector3 = hit["normal"]
			var b2: Basis = _basis_from_up(gn)
			# nach hinten kleiner werden (Tiefe), aber nie unter 55 %
			var s: float = 1.0 - 0.45 * float(n_ground + n_air) / float(max_dots)
			if p.y - gp.y > Ball3D.RADIUS + 0.25:
				# im Flug: leuchtender Punkt genau auf dem Bogen (Mitte der Kugel) + Schatten darunter am Boden
				arc_mm.set_instance_transform(n_air, Transform3D(Basis.IDENTITY.scaled(Vector3(s, s, s)), p))
				air_mm.set_instance_transform(n_air, Transform3D(b2.scaled(Vector3(s, 1.0, s)), gp + gn * 0.03))
				n_air += 1
			else:
				ground_mm.set_instance_transform(n_ground, Transform3D(b2.scaled(Vector3(s, 1.0, s)), gp + gn * 0.035))
				last_ground = Transform3D(b2, gp + gn * 0.035)
				n_ground += 1
		acc -= seg
		if n_ground + n_air >= max_dots:
			break
	ground_mm.visible_instance_count = n_ground
	arc_mm.visible_instance_count = n_air
	air_mm.visible_instance_count = n_air
	_dots.visible = n_ground > 0 or n_air > 0
	_arc_dots.visible = n_air > 0
	_air_dots.visible = n_air > 0
	var out: bool = bool(res.get("out", false))
	if out != _dots_out:
		_set_dots_out(out)
	# Zielkreis am Ende der Kette (dort, wo die Vorhersage den Ball liegen sieht)
	_target_ring.visible = n_ground > 0 and not out
	_preview_end = last_ground.origin if n_ground > 0 else Vector3.INF
	if _target_ring.visible:
		var last: Transform3D = last_ground
		var ring_s: float = 1.0 + 0.6 * float(prof.get("scatter_deg", 1.0)) / 3.0
		_target_ring.global_transform = Transform3D(last.basis.orthonormalized().scaled(Vector3(ring_s, 1.0, ring_s)), last.origin + Vector3(0.0, 0.01, 0.0))
	# Landering: Aufsetzpunkt eines Chips; Groesse = moegliche Streuung des Schlaegers
	var impact: Vector3 = res["first_impact"]
	if impact != Vector3.INF:
		_landing.visible = true
		_landing.global_position = impact + Vector3(0.0, -Ball3D.RADIUS + 0.05, 0.0)
		var flat: float = Vector2(impact.x - origin.x, impact.z - origin.z).length()
		var scatter: float = deg_to_rad(float(prof.get("scatter_deg", 1.0))) * (0.35 + 0.65 * _aim_power)
		var r: float = clampf(flat * tan(scatter) * 1.6, 0.45, 3.2)
		_landing.scale = Vector3(r / 0.44, 1.0, r / 0.44)
	else:
		_landing.visible = false
	# Kamera: alles bis zum weitesten Punkt der Vorschau bleibt scharf, dahinter Tiefenunschaerfe
	var focus_pt: Vector3 = _preview_end
	if impact != Vector3.INF and (focus_pt == Vector3.INF or impact.distance_to(origin) > focus_pt.distance_to(origin)):
		focus_pt = impact
	rig.set_aim_focus(focus_pt)

static func _basis_from_up(up: Vector3) -> Basis:
	var u: Vector3 = up.normalized()
	var ref: Vector3 = Vector3.FORWARD if absf(u.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
	var x: Vector3 = ref.cross(u).normalized()
	var z: Vector3 = x.cross(u).normalized()
	return Basis(x, u, z)

# ================================================================ Ball-Ereignisse

func _on_ball_shot(strokes: int, rec: PlayerRec) -> void:
	rec.strokes = strokes
	if rec == local:
		hud.set_strokes(strokes, course.par)
		hud.reset_spin()
		hud.set_hint("")
		_slowmo_used = false
		if rig.is_top():
			rig.set_top(false)
			hud.set_top_view(false)
	if online:
		NetworkManager.send_game_event("shot", {"id": rec.id, "n": strokes})

func _on_ball_stopped(rec: PlayerRec) -> void:
	if rec.ball == null or rec.done:
		return
	rec.strokes = rec.ball.strokes
	if rec == local:
		_end_slowmo()
		hud.set_strokes(rec.strokes, course.par)
	if course.one_shot or rec.strokes >= Ball3D.MAX_STROKES:
		_finish_player(rec, false)
		return
	if rec == local and phase == Phase.PLAY:
		if rig.idle_time > 1.2:
			rig.aim_at(_suggest_direction(rec.ball.global_position))
		if not auto_play:
			hud.set_hint("Ziehe am Ball, um zu zielen")

func _on_ball_respawned(rec: PlayerRec) -> void:
	if rec.ball == null or rec.done:
		return
	rec.strokes = rec.ball.strokes
	if rec == local:
		hud.set_strokes(rec.strokes, course.par)
		rig.follow(rec.ball, true)
	if course.one_shot or rec.strokes >= Ball3D.MAX_STROKES:
		_finish_player(rec, false)

## Harter Aufprall: Staubwolke an der Kontaktstelle, beim eigenen Ball zusaetzlich kurzes Kamerawackeln.
func _on_ball_impact(strength: float, pos: Vector3, normal: Vector3, rec: PlayerRec) -> void:
	if course == null or not is_instance_valid(course):
		return
	var tint: Color = {"volcano": Color(0.32, 0.27, 0.24), "neon": Color(0.45, 0.9, 1.0), "pirate": Color(0.78, 0.68, 0.5)}.get(
		Catalog.world_of_course(course.course_id), Color(0.58, 0.52, 0.42))
	BallFX.impact_dust(course, pos, normal, strength, tint)
	if rec == local and not auto_play:
		rig.shake(clampf((strength - Ball3D.IMPACT_FX_SPEED) * 0.018, 0.05, 0.22))

func _on_ball_out(kind: String, rec: PlayerRec) -> void:
	if rec.ball == null:
		return
	BallFX.splash(course, rec.ball.global_position, kind)
	if rec == local:
		_end_slowmo()
		rig.shake(0.3)
		var what: String = {"lava": "Lava!", "laser": "Laser!", "water": "Wasser!", "ob": "Aus!"}.get(kind, "Abgrund!")
		hud.toast(what + " +1 Strafschlag")
	elif rec.kind == "bot" and rec.tag != null and _rng.randf() < 0.3:
		_emote(rec, "oops")
	if online:
		var p: Vector3 = rec.ball.global_position
		NetworkManager.send_game_event("out", {"id": rec.id, "k": kind, "x": p.x, "y": p.y, "z": p.z})

func _on_ball_style(kind: String, points: int, rec: PlayerRec) -> void:
	rec.style += points
	if kind == "hio":
		rec.holes_in_one += 1
	if rec != local:
		return
	var text := ""
	match kind:
		"air":
			text = "AIR TIME!"
		"bank":
			text = "BANK SHOT!"
		"close":
			text = "CLOSE CALL!"
		"hio":
			text = "HOLE IN ONE!"
		"long":
			text = "LONG PUTT!"
		"shortcut":
			text = "ABKÜRZUNG!"
	hud.popup_style("%s +%d" % [text, points])
	SoundManager.play("style")

func _on_ball_holed(rec: PlayerRec) -> void:
	if rec.done:
		return
	rec.strokes = rec.ball.strokes if rec.ball != null else rec.strokes
	_finish_player(rec, true)
	var shake_amount: float = BallFX.hole_explosion(course, str(rec.entry.get("explosion", "confetti")), course.hole_pos)
	if rec == local:
		rig.shake(shake_amount)
		SoundManager.play("fanfare")
		SoundManager.play("bass", 1.0, 1.0, 0.7)
		hud.show_banner(_score_name(rec.strokes, course.par), "%d Schläge" % rec.strokes if rec.strokes != 1 else "1 Schlag", 2.0)
		hud.set_hint("")
		_replay_delay = 1.6
	else:
		rig.shake(shake_amount * 0.3)
		if rec.kind == "bot" and _rng.randf() < 0.4:
			_emote(rec, "nice" if rec.strokes <= course.par else "gg")

static func _score_name(strokes: int, par: int) -> String:
	if strokes == 1:
		return "HOLE IN ONE!"
	var diff: int = strokes - par
	if diff <= -3:
		return "ALBATROSS!"
	if diff == -2:
		return "EAGLE!"
	if diff == -1:
		return "BIRDIE!"
	if diff == 0:
		return "PAR"
	if diff == 1:
		return "BOGEY"
	return "EINGELOCHT"

func _finish_player(rec: PlayerRec, in_hole: bool) -> void:
	if rec.done:
		return
	rec.done = true
	rec.holed = in_hole
	rec.hole_time = course.time_limit - time_left
	if not in_hole:
		if not course.one_shot:
			rec.strokes = mini(maxi(rec.strokes, course.par) + 3, Ball3D.MAX_STROKES + 2)
		if rec.ball != null:
			rec.ball.give_up()
	if rec == local:
		_cancel_aim()
		if not in_hole and not course.one_shot:
			hud.show_banner("LIMIT ERREICHT", "", 1.6, UIKit.RED)
	if online and rec.ball != null:
		NetworkManager.send_game_event("done", {"id": rec.id, "n": rec.strokes, "h": in_hole, "t": rec.hole_time})
	_refresh_board()
	_check_hole_end()

func _check_hole_end() -> void:
	if phase != Phase.PLAY:
		return
	for rec in players:
		if not rec.done:
			if rec == local or local == null or not local.done:
				return
			# lokaler Spieler ist fertig: Hinweis, dass auf andere gewartet wird
			hud.set_status("Warte auf Mitspieler …")
			return
	_end_hole()

func _suggest_direction(from: Vector3) -> Vector3:
	var prog: float = course.progress_at(from)
	var target: Vector3 = course.point_at_distance(minf(prog + 12.0, course.total_length()))
	if from.distance_to(course.hole_pos) < 14.0:
		target = course.hole_pos
	var d := Vector3(target.x - from.x, 0.0, target.z - from.z)
	if d.length() < 0.5:
		d = Vector3(course.hole_pos.x - from.x, 0.0, course.hole_pos.z - from.z)
	return d.normalized() if d.length() > 0.01 else Vector3.FORWARD

# ================================================================ Bahn-/Match-Ende

func _end_hole() -> void:
	if phase != Phase.PLAY:
		return
	phase = Phase.HOLE_END
	phase_time = 0.0
	course.clock_running = false
	_cancel_aim()
	_end_slowmo()
	_stop_replay()
	_replay_delay = -1.0
	SoundManager.set_wind(0.0)
	for rec in players:
		if not rec.done:
			rec.done = true
			rec.holed = false
			rec.hole_time = course.time_limit
			if not course.one_shot:
				rec.strokes = mini(maxi(rec.strokes, course.par) + 3, Ball3D.MAX_STROKES + 2)
		if rec.ball != null and not rec.holed:
			rec.ball.freeze_ball()
		rec.total += rec.strokes
		rec.total_time += rec.hole_time
	if online and NetworkManager.is_host():
		NetworkManager.send_game_event("hole_end", {"i": hole_index})
	hud.set_status("")
	hud.set_hint("")
	if mode == "daily":
		_finish_daily()
		return
	var rows: Array = []
	for rec in players:
		var txt: String = ("%d" % rec.strokes) if rec.holed else ("%d (DNF)" % rec.strokes)
		rows.append({"name": rec.name, "color": rec.color, "local": rec == local, "hole_text": txt, "total": rec.total, "time": rec.total_time})
	rows.sort_custom(_rank_less)
	var courses: Array = config.get("courses", [])
	var last: bool = hole_index >= courses.size() - 1
	hud.show_hole_results(rows, "Bahn %d · %s" % [hole_index + 1, course.title], not online and not last and not auto_play)
	rig.set_top(true)
	hud.set_top_view(true)
	_strokes_in_match += local.strokes if local != null else 0
	# Platz des Spielers auf dieser Bahn (fuer die Bahn-Trophaeen); Gleichstand = bester gemeinsamer Platz
	if local != null:
		var better := 0
		for rec in players:
			if rec != local and rec.strokes < local.strokes:
				better += 1
		_course_ranks.append({"course": course.course_id, "rank": better + 1})

var _strokes_in_match: int = 0
var _course_ranks: Array = []

static func _rank_less(a: Dictionary, b: Dictionary) -> bool:
	if int(a["total"]) != int(b["total"]):
		return int(a["total"]) < int(b["total"])
	return float(a.get("time", 0.0)) < float(b.get("time", 0.0))

func _skip_hole_end() -> void:
	if phase == Phase.HOLE_END and not online:
		_advance_after_hole()

func _advance_after_hole() -> void:
	if phase != Phase.HOLE_END:
		return
	var courses: Array = config.get("courses", [])
	if hole_index + 1 < courses.size():
		_start_hole(hole_index + 1)
	else:
		_finish_match()

func _finish_match() -> void:
	phase = Phase.MATCH_END
	phase_time = 0.0
	hud.hide_overlay()
	var rows: Array = []
	for rec in players:
		rows.append({"id": rec.id, "name": rec.name, "color": rec.color, "local": rec == local, "total": rec.total, "time": rec.total_time})
	rows.sort_custom(_rank_less)
	final_ranking = rows
	var rank: int = 1
	for i in rows.size():
		if bool(rows[i]["local"]):
			rank = i + 1
	var summary := {
		"rank": rank, "players": players.size(), "style_points": local.style if local != null else 0,
		"holes_in_one": local.holes_in_one if local != null else 0, "strokes": local.total if local != null else 0,
		"holes": (config.get("courses", []) as Array).size(), "course_ranks": _course_ranks,
	}
	result_rewards = GameManager.finish_match(summary)
	if online:
		NetworkManager.report_match_result(summary, result_rewards, config)
	var headline: String = "SIEG!" if rank == 1 and players.size() > 1 else ("PLATZ %d" % rank if players.size() > 1 else "RUNDE BEENDET")
	hud.show_match_results(rows, result_rewards, headline)
	SoundManager.play("win" if rank == 1 else "lose")
	finished = true

func _finish_daily() -> void:
	phase = Phase.MATCH_END
	var holed_in: bool = local != null and local.holed
	var dist: float = 99.0
	if local != null and local.ball != null and local.ball.state != Ball3D.State.OUT and local.ball.global_position.y > course.kill_y:
		var p: Vector3 = local.ball.global_position
		dist = Vector2(p.x - course.hole_pos.x, p.z - course.hole_pos.z).length()
		if absf(p.y - course.hole_pos.y) > 3.0:
			dist = 99.0
	result_rewards = GameManager.finish_daily(dist, holed_in)
	hud.show_daily_result(dist, holed_in, result_rewards)
	SoundManager.play("win" if holed_in or dist < 3.0 else "coin")
	finished = true

## Zurueck ins Hauptmenue (verlaesst ggf. die Online-Lobby).
func leave_match() -> void:
	Engine.time_scale = 1.0
	if online:
		NetworkManager.leave_lobby()
	GameManager.goto_menu()

# ================================================================ Zeitlupe (Best-Shot-Kamera) & Replay

func _update_slowmo(real_dt: float) -> void:
	if local == null or local.ball == null:
		return
	var ball: Ball3D = local.ball
	if _slowmo:
		_slowmo_timer -= real_dt
		if _slowmo_timer <= 0.0 or ball.state != Ball3D.State.MOVING:
			_end_slowmo()
		return
	if _slowmo_used or ball.state != Ball3D.State.MOVING or auto_play:
		return
	_slowmo_check -= real_dt
	if _slowmo_check > 0.0:
		return
	_slowmo_check = 0.12
	var pos: Vector3 = ball.global_position
	var to_hole := Vector3(course.hole_pos.x - pos.x, 0.0, course.hole_pos.z - pos.z)
	var d: float = to_hole.length()
	var sp: float = ball.speed()
	if d > 7.0 or d < 1.3 or sp < 1.0 or sp > 12.0:
		return
	if ball.linear_velocity.normalized().dot(to_hole.normalized()) < 0.9:
		return
	# Nur ausloesen, wenn die Vorhersage sagt: der geht rein
	var res: Dictionary = ShotSim.run(course, get_world_3d().direct_space_state, pos, ball.linear_velocity,
		{"max_time": 2.5, "profile": ball.profile, "chip": not ball.grounded, "sample": 1000})
	if not bool(res.get("holed", false)):
		return
	_slowmo = true
	_slowmo_used = true
	_slowmo_timer = 3.2
	if not online:
		Engine.time_scale = 0.33
	rig.hole_cam(course.hole_pos, pos)

func _end_slowmo() -> void:
	if not _slowmo:
		return
	_slowmo = false
	Engine.time_scale = 1.0
	rig.end_hole_cam()

func _update_replay(real_dt: float) -> void:
	if _replay_delay > 0.0:
		_replay_delay -= real_dt
		if _replay_delay <= 0.0:
			_start_replay()
	if _replay_ghost == null:
		return
	_replay_pos += real_dt * 120.0 * 0.5
	var idx: int = int(_replay_pos)
	if idx >= _replay_points.size() - 1:
		_stop_replay()
		if phase == Phase.PLAY:
			rig.set_top(true)
			hud.set_top_view(true)
			_check_hole_end()
		return
	var a: Vector3 = _replay_points[idx]
	var b: Vector3 = _replay_points[idx + 1]
	var prev: Vector3 = _replay_ghost.global_position
	_replay_ghost.global_position = a.lerp(b, _replay_pos - float(idx))
	var moved: Vector3 = _replay_ghost.global_position - prev
	var flat := Vector3(moved.x, 0.0, moved.z)
	if flat.length() > 0.0005:
		var axis: Vector3 = Vector3.UP.cross(flat.normalized())
		if axis.length() > 0.01:
			_replay_ghost.rotate(axis.normalized(), flat.length() / Ball3D.RADIUS)

func _start_replay() -> void:
	if local == null or local.ball == null or phase != Phase.PLAY or auto_play:
		return
	var rec_pts: PackedVector3Array = local.ball.record
	if rec_pts.size() < 40:
		rig.set_top(true)
		hud.set_top_view(true)
		return
	var start: int = maxi(0, rec_pts.size() - 360)
	_replay_points = rec_pts.slice(start)
	_replay_points.append(course.hole_pos + Vector3(0.0, -0.2, 0.0))
	_replay_pos = 0.0
	_replay_ghost = BallFX.make_ball(str(local.entry.get("ball", "standard")), Ball3D.RADIUS, local.color)
	course.add_child(_replay_ghost)
	_replay_ghost.global_position = _replay_points[0]
	rig.replay_at(course.hole_pos)
	hud.set_status("REPLAY")

func _stop_replay() -> void:
	if _replay_ghost != null:
		if is_instance_valid(_replay_ghost):
			_replay_ghost.queue_free()
		_replay_ghost = null
		if hud != null:
			hud.set_status("")
		if rig != null and rig.mode == CameraManager3D.Mode.REPLAY:
			rig.mode = CameraManager3D.Mode.FOLLOW

# ================================================================ Emotes

func _on_local_emote(emote_id: String) -> void:
	if local == null:
		return
	_emote(local, emote_id)
	if online:
		NetworkManager.send_game_event("emote", {"id": local.id, "e": emote_id})

func _emote(rec: PlayerRec, emote_id: String) -> void:
	if rec.tag != null and is_instance_valid(rec.tag):
		rec.tag.show_emote(emote_id)

# ================================================================ Netzwerk

func _find(id: String) -> PlayerRec:
	for rec in players:
		if rec.id == id:
			return rec
	return null

func _net_tick(real_dt: float) -> void:
	for rec in players:
		if rec.ball == null:
			continue
		rec.net_acc += real_dt
		if rec.net_acc < NET_INTERVAL:
			continue
		var p: Vector3 = rec.ball.global_position
		if rec.last_sent != Vector3.INF and rec.last_sent.distance_to(p) < 0.02 and rec.net_acc < 1.0:
			continue
		rec.net_acc = 0.0
		rec.last_sent = p
		NetworkManager.send_game_event("pos", {"id": rec.id, "x": snappedf(p.x, 0.01), "y": snappedf(p.y, 0.01), "z": snappedf(p.z, 0.01),
			"v": rec.ball.visible})

func _on_game_event(event: String, data: Dictionary) -> void:
	if event == "hole_start":
		_hole_start_received = int(data.get("i", -1))
		return
	if event == "hole_end":
		if phase == Phase.PLAY and int(data.get("i", -1)) == hole_index:
			_end_hole()
		return
	var rec: PlayerRec = _find(str(data.get("id", "")))
	if rec == null or rec.remote == null or course == null:
		return
	match event:
		"pos":
			rec.remote.push_position(Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0))))
			rec.remote.set_hidden(not bool(data.get("v", true)))
		"shot":
			rec.strokes = int(data.get("n", rec.strokes + 1))
		"out":
			BallFX.splash(course, Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0))), str(data.get("k", "water")))
		"emote":
			_emote(rec, str(data.get("e", "nice")))
		"done":
			if rec.done or phase != Phase.PLAY:
				return
			rec.done = true
			rec.holed = bool(data.get("h", false))
			rec.strokes = int(data.get("n", rec.strokes))
			rec.hole_time = float(data.get("t", course.time_limit - time_left))
			if rec.holed:
				rec.remote.push_position(course.hole_pos + Vector3(0.0, -0.25, 0.0))
				rec.remote.set_holed()
				rig.shake(BallFX.hole_explosion(course, str(rec.entry.get("explosion", "confetti")), course.hole_pos) * 0.3)
			_refresh_board()
			_check_hole_end()
