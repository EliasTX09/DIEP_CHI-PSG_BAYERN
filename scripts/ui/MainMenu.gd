class_name MainMenuView
extends Node3D
## Hauptmenue im Hochformat (720 x 1280, waechst auf hohen Handys nach unten mit).
## - Hintergrund: echte 3D-Bahn der gewaehlten Arena (pro Welt eine eigene), Kamera fliegt auf einer Spline um sie herum,
##   dazu schwebende Inseln, Glitzer und brennende Golfbaelle am Himmel.
## - Kopfleiste: Profilbild (aus dem Web-Account), Name, Trophaeen/Liga, Coins, Gems, Einstellungen.
## - Startseite: Arena-Auswahl (Pfeile oder Wischen), drehbare 3D-Vitrine mit Ball + Schlaeger, SPIELEN, Golden Shot,
##   Lobby, 4 Truhen-Slots.
## - Tab-Leiste unten: Spielen · Tasche · Pass · Freunde · Shop (Seiten aus MenuPages).
## Alles ist mit dem Daumen einer Hand erreichbar: die Bedienelemente liegen in der unteren Bildschirmhaelfte.

const CAMERA_LOOP_SECONDS := 80.0
const FIREBALL_COUNT := 3
## Hintergrund-Bahn je Arena
const BACKDROPS := {"emerald": "e5", "volcano": "v4", "neon": "n1", "pirate": "p2"}
## Tabs: id, Icon, Beschriftung, Farbe, Seite beim Antippen
const NAV: Array[Dictionary] = [
	{"id": "home", "icon": "flag", "text": "Spielen", "color": Color(0.25, 0.8, 0.38), "page": ""},
	{"id": "bag", "icon": "club", "text": "Tasche", "color": Color(0.95, 0.55, 0.2), "page": "clubs"},
	{"id": "pass", "icon": "star", "text": "Pass", "color": Color(0.65, 0.4, 1.0), "page": "pass"},
	{"id": "social", "icon": "friends", "text": "Freunde", "color": Color(0.18, 0.56, 1.0), "page": "friends"},
	{"id": "shop", "icon": "shop", "text": "Shop", "color": Color(0.95, 0.3, 0.45), "page": "shop"},
]
## Abstand der Vitrine vor der Kamera
const SHOWCASE_DEPTH := 3.6

var course: Course3D
var camera: Camera3D
var showcase: Node3D
var pages: MenuPages
var ui: Control
var current_tab: String = "home"

var _world_root: Node3D
var _curve: Curve3D
var _center: Vector3 = Vector3.ZERO
var _cam_offset: float = 0.0
var _time: float = 0.0
var _decor_windmills: Array[Node] = []
var _fireballs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _backdrop_id: String = ""
var _switching: bool = false

# Vitrine (Ball + Schlaeger)
var _ball_pivot: Node3D
var _club_pivot: Node3D
var _ball_node: Node3D
var _club_node: Node3D
var _trail_node: GPUParticles3D
var _spin_velocity: float = 0.0
var _spin_angle: float = 0.0
var _dragging: bool = false
var _drag_index: int = -1
var _idle: float = 0.0

# UI
var _content: Control
var _home: Control
var _showcase_slot: Control
var _fade: ColorRect
var _avatar: UIAvatar
var _name_label: Label
var _league_label: Label
var _trophy_label: Label
var _coin_pill: PanelContainer
var _gem_pill: PanelContainer
var _status_label: Label
var _arena_panel: PanelContainer
var _arena_name: Label
var _arena_index: Label
var _arena_desc: Label
var _arena_info: Label
var _mode_button: Button
var _daily_button: Button
var _chest_buttons: Array[Button] = []
var _invite_bar: PanelContainer
var _showcase_label: Label
var _nav_buttons: Dictionary = {}
var _nav_badges: Dictionary = {}
var _ui_tick: float = 0.0
var _arena_swipe_start: Vector2 = Vector2.INF

func _ready() -> void:
	_rng.seed = int(Time.get_ticks_usec())
	Engine.time_scale = 1.0
	get_tree().paused = false
	if not BACKDROPS.has(MenuPages.sel_world):
		MenuPages.sel_world = "emerald"
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.far = 900.0
	camera.current = true
	add_child(camera)
	_build_world(MenuPages.sel_world)
	_build_showcase()
	for i in FIREBALL_COUNT:
		_spawn_fireball(float(i) * 1.7)
	_build_ui()
	pages = MenuPages.new(self, ui, _content)
	pages.page_changed.connect(_on_page_changed)
	GameManager.currency_changed.connect(_refresh_top)
	GameManager.profile_changed.connect(_refresh_top)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.chests_changed.connect(_refresh_chests)
	GameManager.pass_changed.connect(_refresh_badges)
	GameManager.toast.connect(func(msg: String) -> void: UIKit.toast(ui, msg))
	AuthManager.status_changed.connect(func(_t: String) -> void: _refresh_top())
	AuthManager.auth_changed.connect(_refresh_top)
	ProfileManager.avatar_changed.connect(_refresh_top)
	NetworkManager.invites_updated.connect(_refresh_invites)
	NetworkManager.friends_updated.connect(_refresh_invites)
	NetworkManager.lobby_error.connect(func(msg: String) -> void: UIKit.toast(ui, msg, UIKit.RED.darkened(0.3)))
	NetworkManager.lobby_joined.connect(func(_code: String) -> void:
		if pages.page != "lobby":
			pages.open("lobby"))
	get_viewport().size_changed.connect(_place_showcase)
	_refresh_top()
	_refresh_arena()
	_refresh_chests()
	_refresh_invites()
	_refresh_badges()
	NetworkManager.refresh_invites()
	NetworkManager.refresh_friends()
	_show_last_match_rewards()

# ================================================================ 3D-Welt (Arena)

func _build_world(world_id: String) -> void:
	_world_root = Node3D.new()
	_world_root.name = "World"
	add_child(_world_root)
	_decor_windmills.clear()
	_backdrop_id = str(BACKDROPS.get(world_id, "e5"))
	course = CourseBuilder3D.build(_backdrop_id, 7, true)
	course.name = "Backdrop_" + _backdrop_id
	_world_root.add_child(course)
	var b: AABB = course.bounds
	if b.size == Vector3.ZERO:
		b = AABB(Vector3(-30, -2, -60), Vector3(60, 8, 60))
	_center = b.get_center()
	_center.y = maxf(_center.y, 0.0)
	var radius: float = maxf(b.size.x, b.size.z) * 0.5
	# Schwebende Inseln (gruene Welten) rund um die Bahn
	if world_id in ["emerald", "pirate"]:
		for i in 6:
			var ang: float = TAU * float(i) / 6.0 + _rng.randf_range(-0.25, 0.25)
			var dist: float = radius + _rng.randf_range(16.0, 30.0)
			var pos := _center + Vector3(sin(ang) * dist, _rng.randf_range(7.0, 15.0), cos(ang) * dist)
			var island := _make_floating_island(_rng.randf_range(3.0, 5.5), i % 2 == 0)
			island.position = pos
			_world_root.add_child(island)
	# Glitzer bzw. Glut-Partikel ueber der ganzen Szene
	var warm: bool = world_id == "volcano"
	var sparkle := Mat.particles({"amount": 90, "lifetime": 7.0, "spread": 180.0, "speed": Vector2(0.1, 0.4),
		"gravity": Vector3(0.0, 0.12, 0.0), "size": 0.22, "scale": Vector2(0.4, 1.0),
		"emission_box": Vector3(radius + 20.0, 5.0, radius + 20.0),
		"colors": [Color(1.0, 0.6, 0.2, 0.0), Color(1.0, 0.45, 0.1, 0.9), Color(1.0, 0.2, 0.05, 0.0)] if warm else
			[Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.9, 0.5, 0.9), Color(0.6, 1.0, 0.8, 0.0)]})
	sparkle.visibility_aabb = AABB(Vector3(-200, -40, -200), Vector3(400, 80, 400))
	sparkle.position = _center + Vector3(0.0, 6.0, 0.0)
	_world_root.add_child(sparkle)
	_build_curve()

func _make_floating_island(r: float, with_windmill: bool) -> Node3D:
	var root := Node3D.new()
	var bob := Motion.bobber(_rng.randf_range(0.4, 0.9), _rng.randf_range(0.35, 0.6), _rng.randf_range(0.0, TAU))
	root.add_child(bob)
	var holder := Node3D.new()
	bob.add_child(holder)
	var grass := Mat.shader("terrain", {"slope_strength": 0.0})
	holder.add_child(Mat.cylinder(r, r * 0.92, 0.9, grass, Vector3(0.0, 0.0, 0.0), 20))
	holder.add_child(Mat.cylinder(r * 0.9, 0.35, r * 1.7, Mat.flat(Color(0.45, 0.36, 0.3), 0.95), Vector3(0.0, -r * 0.85 - 0.45, 0.0), 9))
	holder.add_child(Mat.cylinder(r * 0.5, 0.2, r * 0.9, Mat.flat(Color(0.38, 0.3, 0.26), 0.95), Vector3(r * 0.3, -r * 1.6, 0.2), 7))
	var trunk := Mat.flat(Color(0.42, 0.28, 0.16), 0.9)
	var leaves := Mat.flat(Color(0.22, 0.62, 0.28), 0.8)
	for t in _rng.randi_range(1, 3):
		var a: float = _rng.randf_range(0.0, TAU)
		var d: float = _rng.randf_range(r * 0.25, r * 0.7)
		var tp := Vector3(sin(a) * d, 0.45, cos(a) * d)
		holder.add_child(Mat.cylinder(0.15, 0.22, 1.6, trunk, tp + Vector3(0.0, 0.8, 0.0), 8))
		holder.add_child(Mat.sphere(_rng.randf_range(0.8, 1.2), leaves, tp + Vector3(0.0, 2.0, 0.0), 12))
	if with_windmill:
		var wm := Obstacles.Windmill.new(_rng.randf_range(0.6, 1.1), _rng.randf_range(0.0, TAU), Color(0.92, 0.88, 0.78), Color(0.8, 0.28, 0.22), 0.8)
		wm.scale = Vector3.ONE * 0.55
		wm.position = Vector3(0.0, 0.45, 0.0)
		wm.rotation.y = _rng.randf_range(0.0, TAU)
		holder.add_child(wm)
		_decor_windmills.append(wm)
	if _rng.randf() < 0.6:
		var fall := Mat.vplane(Vector2(1.2, r * 2.2), Mat.shader("waterfall"), Vector3(r * 0.95, -r * 1.1, 0.0), 6)
		fall.rotation.y = PI * 0.5
		holder.add_child(fall)
	return root

## Wechselt die Arena: Hintergrund-Bahn wird mit kurzer Abblende neu aufgebaut.
func select_world(world_id: String) -> void:
	if not BACKDROPS.has(world_id):
		return
	MenuPages.sel_world = world_id
	_refresh_arena()
	if str(BACKDROPS[world_id]) == _backdrop_id or _switching:
		return
	_switching = true
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 1.0, 0.15)
	await tw.finished
	_world_root.queue_free()
	_build_world(world_id)
	_cam_offset = 0.0
	_update_camera(0.0)
	var tw2 := create_tween()
	tw2.tween_property(_fade, "color:a", 0.0, 0.3)
	_switching = false
	# Falls waehrend der Abblende noch einmal gewechselt wurde
	if str(BACKDROPS.get(MenuPages.sel_world, "")) != _backdrop_id:
		select_world(MenuPages.sel_world)

func _step_world(dir: int) -> void:
	var ids: Array[String] = Catalog.world_ids()
	var i: int = maxi(0, ids.find(MenuPages.sel_world))
	SoundManager.play("tab")
	select_world(ids[(i + dir + ids.size()) % ids.size()])

## Ein brennender Golfball fliegt auf einer Parabel ueber die Szene; danach startet er neu.
func _spawn_fireball(delay: float) -> void:
	var node := Node3D.new()
	add_child(node)
	node.add_child(BallFX.make_ball("magma", 0.55))
	var trail := BallFX.make_trail("fire")
	if trail != null:
		trail.amount = 70
		trail.lifetime = 0.9
		trail.scale = Vector3.ONE * 2.2
		node.add_child(trail)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 2.0
	light.omni_range = 7.0
	node.add_child(light)
	var fb := {"node": node, "t": -delay, "duration": 1.0, "from": Vector3.ZERO, "to": Vector3.ZERO, "arc": 10.0}
	_reset_fireball(fb)
	fb["t"] = -delay
	node.visible = false
	_fireballs.append(fb)

func _reset_fireball(fb: Dictionary) -> void:
	var b: AABB = course.bounds
	var radius: float = maxf(b.size.x, b.size.z) * 0.5 + 25.0
	var a: float = _rng.randf_range(0.0, TAU)
	var spread: float = _rng.randf_range(2.2, 3.4)
	fb["from"] = _center + Vector3(sin(a) * radius, _rng.randf_range(4.0, 12.0), cos(a) * radius)
	fb["to"] = _center + Vector3(sin(a + spread) * radius, _rng.randf_range(2.0, 10.0), cos(a + spread) * radius)
	fb["arc"] = _rng.randf_range(10.0, 22.0)
	fb["duration"] = _rng.randf_range(3.5, 5.5)
	fb["t"] = -_rng.randf_range(0.5, 3.0)

func _update_fireballs(delta: float) -> void:
	for fb in _fireballs:
		fb["t"] = float(fb["t"]) + delta
		var node: Node3D = fb["node"]
		var t: float = float(fb["t"])
		if t < 0.0:
			node.visible = false
			continue
		var k: float = t / float(fb["duration"])
		if k >= 1.0:
			_reset_fireball(fb)
			node.visible = false
			continue
		node.visible = true
		var from: Vector3 = fb["from"]
		var to: Vector3 = fb["to"]
		var p: Vector3 = from.lerp(to, k)
		p.y += 4.0 * float(fb["arc"]) * k * (1.0 - k)
		node.global_position = p

# ================================================================ Kamera (Spline-Flug)

func _build_curve() -> void:
	var b: AABB = course.bounds
	var r: float = maxf(b.size.x, b.size.z) * 0.5 + 12.0
	_curve = Curve3D.new()
	var pts: Array[Vector3] = []
	var n := 8
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var rr: float = r * (1.0 + 0.18 * sin(a * 2.0 + 0.7))
		var h: float = 14.0 + 6.0 * sin(a * 3.0 + 1.3)
		pts.append(_center + Vector3(sin(a) * rr, h, cos(a) * rr))
	pts.append(pts[0])
	for i in pts.size():
		var prev: Vector3 = pts[(i - 1 + n) % n] if i > 0 else pts[n - 1]
		var next: Vector3 = pts[(i + 1) % n]
		var tangent: Vector3 = (next - prev) * 0.25
		_curve.add_point(pts[i], -tangent, tangent)
	_curve.bake_interval = 0.5
	_update_camera(0.0)

func _update_camera(delta: float) -> void:
	var length: float = _curve.get_baked_length()
	if length <= 0.0:
		return
	_cam_offset = fmod(_cam_offset + delta * length / CAMERA_LOOP_SECONDS, length)
	camera.global_position = _curve.sample_baked(_cam_offset, true)
	var look: Vector3 = _center + Vector3(sin(_time * 0.11) * 6.0, 1.5, cos(_time * 0.09) * 6.0)
	camera.look_at(look, Vector3.UP)

# ================================================================ Vitrine: Ball + Schlaeger

func _build_showcase() -> void:
	showcase = Node3D.new()
	showcase.name = "Showcase"
	camera.add_child(showcase)
	showcase.position = Vector3(0.0, -0.3, -SHOWCASE_DEPTH)
	var key := OmniLight3D.new()
	key.position = Vector3(-0.4, 1.4, 1.6)
	key.light_energy = 1.6
	key.omni_range = 6.0
	key.light_color = Color(1.0, 0.95, 0.88)
	showcase.add_child(key)
	_ball_pivot = Node3D.new()
	_ball_pivot.position = Vector3(-0.42, -0.12, 0.0)
	showcase.add_child(_ball_pivot)
	_club_pivot = Node3D.new()
	_club_pivot.position = Vector3(0.42, 0.05, 0.0)
	showcase.add_child(_club_pivot)
	var ring := Mat.torus(0.48, 0.56, Mat.glow(Color(1.0, 0.8, 0.2), 1.8), Vector3(0.0, -0.55, 0.0))
	ring.add_child(Motion.spinner(Vector3.UP, 0.8))
	_ball_pivot.add_child(ring)
	var glow := Mat.particles({"amount": 24, "lifetime": 1.6, "spread": 25.0, "speed": Vector2(0.15, 0.45), "gravity": Vector3(0.0, 0.25, 0.0),
		"size": 0.08, "emission_ring": Vector2(0.5, 0.02), "local": true,
		"colors": [Color(1.0, 0.85, 0.3, 0.9), Color(1.0, 0.6, 0.2, 0.0)]})
	glow.position = Vector3(0.0, -0.55, 0.0)
	_ball_pivot.add_child(glow)
	refresh_showcase()

## Baut Ball, Trail und Schlaeger nach der aktuellen Ausruestung neu.
func refresh_showcase() -> void:
	if _ball_node != null:
		_ball_node.queue_free()
	if _trail_node != null:
		_trail_node.queue_free()
		_trail_node = null
	if _club_node != null:
		_club_node.queue_free()
	_ball_node = BallFX.make_ball(GameManager.equipped("ball"), 0.36, GameManager.avatar_color())
	_ball_pivot.add_child(_ball_node)
	var trail := BallFX.make_trail(GameManager.equipped("trail"))
	if trail != null:
		trail.local_coords = true
		_ball_pivot.add_child(trail)
		_trail_node = trail
	_club_node = ClubModel.make(GameManager.equipped_club())
	_club_node.scale = Vector3.ONE * 1.25
	_club_node.rotation = Vector3(0.0, 0.0, deg_to_rad(-18.0))
	_club_pivot.add_child(_club_node)
	if _showcase_label != null:
		var club: String = GameManager.equipped_club()
		_showcase_label.text = "%s · Lv %d · %s" % [Catalog.club_name(club), GameManager.club_level(club),
			Catalog.item_name("ball", GameManager.equipped("ball"))]
		_showcase_label.add_theme_color_override("font_color", Catalog.RARITY_COLORS.get(Catalog.club_rarity(club), Color.WHITE))

## Setzt die Vitrine mittig in den freien Bereich der Startseite und skaliert sie passend (jedes Seitenverhaeltnis).
func _place_showcase() -> void:
	if showcase == null or _showcase_slot == null or not _showcase_slot.is_inside_tree():
		return
	var rect: Rect2 = _showcase_slot.get_global_rect()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	showcase.visible = current_tab == "home" and rect.size.y > 60.0 and _home.visible
	if not showcase.visible or vp.y <= 0.0:
		return
	var hh: float = SHOWCASE_DEPTH * tan(deg_to_rad(camera.fov * 0.5))
	var hw: float = hh * vp.x / vp.y
	var c: Vector2 = rect.get_center()
	var ndc := Vector2(c.x / vp.x * 2.0 - 1.0, 1.0 - c.y / vp.y * 2.0)
	var unit: float = 2.0 * hh / vp.y
	# Schlaeger (ca. 1.35 hoch) fuellt ~60% der Hoehe, beides zusammen (ca. 1.4 breit) hoechstens ~65% der Breite;
	# so bleibt rundherum die Arena sichtbar
	var s: float = minf(rect.size.y * 0.6 * unit / 1.35, rect.size.x * 0.65 * unit / 1.4)
	showcase.position = Vector3(ndc.x * hw, ndc.y * hh, -SHOWCASE_DEPTH)
	showcase.scale = Vector3.ONE * clampf(s, 0.25, 2.0)

func _update_showcase(delta: float) -> void:
	_idle += delta
	if not _dragging:
		_spin_velocity = lerpf(_spin_velocity, 0.6 if _idle > 1.5 else 0.0, clampf(delta * 1.8, 0.0, 1.0))
	_spin_angle += _spin_velocity * delta
	_ball_pivot.rotation.y = _spin_angle
	if _ball_node != null:
		_ball_node.rotation.x += delta * 0.4
	_club_pivot.rotation.y = _spin_angle * 0.8 + 0.4
	var bob: float = sin(_time * 1.3) * 0.06
	_ball_pivot.position.y = -0.12 + bob
	_club_pivot.position.y = 0.05 - bob * 0.7

## true, wenn eine Bildschirmposition in der Vitrine liegt (nur auf der Startseite).
func _in_showcase_area(pos: Vector2) -> bool:
	return current_tab == "home" and _showcase_slot != null and _showcase_slot.get_global_rect().has_point(pos)

func _unhandled_input(event: InputEvent) -> void:
	if pages != null and pages.any_modal_open():
		return
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _drag_index < 0 and _in_showcase_area(st.position):
			_drag_index = st.index
			_dragging = true
			_idle = 0.0
		elif not st.pressed and st.index == _drag_index:
			_drag_index = -1
			_dragging = false
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _drag_index:
			_spin_velocity = clampf(sd.relative.x * 0.012 / maxf(0.008, get_process_delta_time()), -14.0, 14.0)
			_spin_angle += sd.relative.x * 0.012
			_idle = 0.0
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and _in_showcase_area(mb.position):
				_dragging = true
				_idle = 0.0
			elif not mb.pressed:
				_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		_spin_velocity = clampf(mm.relative.x * 0.012 / maxf(0.008, get_process_delta_time()), -14.0, 14.0)
		_spin_angle += mm.relative.x * 0.012
		_idle = 0.0

# ================================================================ UI-Aufbau

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	ui = Control.new()
	ui.name = "UI"
	ui.theme = UIKit.theme()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.08, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_fade)
	var safe := MarginContainer.new()
	safe.name = "Safe"
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(safe)
	UIKit.apply_safe_area(safe, 10)
	var col := UIKit.vbox(8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(col)
	_build_top_bar(col)
	_status_label = UIKit.label("", 15, UIKit.TEXT_DIM, true)
	_status_label.name = "Status"
	_status_label.clip_text = true
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_status_label.add_theme_constant_override("outline_size", 6)
	_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	col.add_child(_status_label)
	_content = Control.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_content)
	_build_home(_content)
	_build_nav(col)
	_invite_bar = UIKit.panel(Color(0.35, 0.15, 0.6, 0.96), 18, Color(1, 1, 1, 0.4), 2)
	_invite_bar.name = "InviteBar"
	_invite_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_invite_bar.offset_left = 12.0
	_invite_bar.offset_right = -12.0
	_invite_bar.offset_top = 4.0
	_invite_bar.visible = false
	_content.add_child(_invite_bar)

func _build_top_bar(parent: Control) -> void:
	var bar := UIKit.hbox(8)
	bar.name = "TopBar"
	bar.custom_minimum_size = Vector2(0, 76)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bar)
	# Profil-Karte: tippen -> Profil & Einstellungen, Trophaeen -> Trophaeen-Pfad
	var profile := Button.new()
	profile.name = "ProfileButton"
	profile.focus_mode = Control.FOCUS_NONE
	profile.custom_minimum_size = Vector2(0, 76)
	profile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.set_button_color(profile, Color(0.03, 0.05, 0.12, 0.88))
	profile.pressed.connect(func() -> void:
		SoundManager.play("click")
		pages.open("settings"))
	bar.add_child(profile)
	var ph := UIKit.hbox(8)
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.offset_left = 6.0
	ph.offset_right = -6.0
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile.add_child(ph)
	_avatar = UIAvatar.new(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), GameManager.avatar_frame(), 62.0)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_avatar)
	var pv := UIKit.vbox(0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(pv)
	_name_label = UIKit.label(GameManager.player_name(), 22, UIKit.TEXT)
	_name_label.clip_text = true
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	pv.add_child(_name_label)
	var lh := UIKit.hbox(4)
	lh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(lh)
	lh.add_child(UIIcon.new("trophy", 20.0))
	_trophy_label = UIKit.label("0", 18, UIKit.GOLD)
	lh.add_child(_trophy_label)
	_league_label = UIKit.label("", 16, UIKit.TEXT_DIM)
	_league_label.clip_text = true
	lh.add_child(_league_label)
	var trophy_btn := UIKit.icon_button("trophy", Color(0.55, 0.42, 0.08), func() -> void: pages.open("trophies"), 60.0)
	trophy_btn.name = "TrophyButton"
	trophy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(trophy_btn)
	var money := UIKit.vbox(4)
	money.mouse_filter = Control.MOUSE_FILTER_IGNORE
	money.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(money)
	_coin_pill = _pill("coin", GameManager.coins(), func() -> void: _set_tab("shop"))
	money.add_child(_coin_pill)
	_gem_pill = _pill("gem", GameManager.gems(), func() -> void: _set_tab("shop"))
	money.add_child(_gem_pill)
	var settings := UIKit.icon_button("settings", UIKit.GREY, func() -> void: pages.open("settings"), 60.0)
	settings.name = "SettingsButton"
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(settings)

## Kompakte Waehrungs-Pille (tippbar -> Shop).
func _pill(icon_kind: String, value: int, on_press: Callable) -> PanelContainer:
	var p := UIKit.panel(Color(0.03, 0.05, 0.12, 0.88), 16, Color(1, 1, 1, 0.15), 2)
	p.custom_minimum_size = Vector2(150, 34)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	p.gui_input.connect(func(ev: InputEvent) -> void:
		if (ev is InputEventMouseButton or ev is InputEventScreenTouch) and ev.is_pressed():
			SoundManager.play("click")
			on_press.call())
	var h := UIKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(UIIcon.new(icon_kind, 24.0))
	var l := UIKit.label(UIKit.format_number(value), 20, UIKit.TEXT)
	l.name = "Value"
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(l)
	p.add_child(UIKit.margin(h, 6, 0, 8, 0))
	return p

func _build_home(parent: Control) -> void:
	_home = UIKit.vbox(10)
	_home.name = "Home"
	_home.set_anchors_preset(Control.PRESET_FULL_RECT)
	_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(_home)
	_build_arena_banner(_home)
	_showcase_slot = Control.new()
	_showcase_slot.name = "ShowcaseSlot"
	_showcase_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_showcase_slot.custom_minimum_size = Vector2(0, 120)
	_showcase_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home.add_child(_showcase_slot)
	_showcase_slot.resized.connect(_place_showcase)
	_showcase_label = UIKit.label("", 19, UIKit.TEXT, true)
	_showcase_label.add_theme_constant_override("outline_size", 8)
	_showcase_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	_home.add_child(_showcase_label)
	refresh_showcase()
	_build_play_area(_home)
	_build_chest_row(_home)

func _build_arena_banner(parent: Control) -> void:
	_arena_panel = UIKit.panel(Color(0.03, 0.05, 0.12, 0.78), 22, Color(1, 1, 1, 0.3), 3)
	_arena_panel.name = "ArenaBanner"
	_arena_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_arena_panel.gui_input.connect(_on_arena_input)
	parent.add_child(_arena_panel)
	var h := UIKit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arena_panel.add_child(UIKit.margin(h, 8, 8, 8, 8))
	var prev := UIKit.icon_button("back", UIKit.BLUE, func() -> void: _step_world(-1), 64.0)
	prev.name = "ArenaPrev"
	prev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(prev)
	var v := UIKit.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	_arena_index = UIKit.label("", 16, UIKit.TEXT_DIM, true)
	v.add_child(_arena_index)
	_arena_name = UIKit.label("", 34, UIKit.GOLD, true)
	_arena_name.name = "ArenaName"
	_arena_name.add_theme_constant_override("outline_size", 12)
	_arena_name.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.0))
	v.add_child(_arena_name)
	_arena_desc = UIKit.label("", 17, UIKit.TEXT, true)
	_arena_desc.clip_text = true
	_arena_desc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_arena_desc)
	_arena_info = UIKit.label("", 16, UIKit.TEXT_DIM, true)
	v.add_child(_arena_info)
	var next := UIKit.icon_button("next", UIKit.BLUE, func() -> void: _step_world(1), 64.0)
	next.name = "ArenaNext"
	next.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(next)

## Wischen ueber das Arena-Banner wechselt die Arena.
func _on_arena_input(ev: InputEvent) -> void:
	if (ev is InputEventScreenTouch or ev is InputEventMouseButton):
		if ev.is_pressed():
			_arena_swipe_start = ev.get("position")
		elif _arena_swipe_start != Vector2.INF:
			var d: Vector2 = ev.get("position") - _arena_swipe_start
			_arena_swipe_start = Vector2.INF
			if absf(d.x) > 80.0 and absf(d.x) > absf(d.y) * 1.5:
				_step_world(-1 if d.x > 0.0 else 1)

func _build_play_area(parent: Control) -> void:
	_mode_button = UIKit.button("", Color(0.03, 0.05, 0.12, 0.8), func() -> void: pages.open("play"), Vector2(0, 46), 18)
	_mode_button.name = "ModeButton"
	_mode_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_mode_button.custom_minimum_size = Vector2(420, 46)
	parent.add_child(_mode_button)
	var row := UIKit.hbox(10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	_daily_button = UIKit.button("GOLDEN\nSHOT", Color(0.85, 0.6, 0.1), _start_daily, Vector2(150, 108), 20)
	_daily_button.name = "DailyButton"
	row.add_child(_daily_button)
	var play := UIKit.button("SPIELEN", UIKit.GREEN, _quick_play, Vector2(0, 108), 44)
	play.name = "PlayButton"
	play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play.add_theme_constant_override("outline_size", 10)
	play.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.08))
	row.add_child(play)
	play.resized.connect(func() -> void: play.pivot_offset = play.size * 0.5)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	var lobby := UIKit.button("LOBBY", UIKit.PURPLE, func() -> void: pages.open("lobby"), Vector2(150, 108), 22)
	lobby.name = "LobbyButton"
	row.add_child(lobby)

func _build_chest_row(parent: Control) -> void:
	var row := UIKit.hbox(8)
	row.name = "ChestRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)
	_chest_buttons.clear()
	for i in Catalog.CHEST_SLOTS:
		var slot: int = i
		var b := Button.new()
		b.name = "Chest%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(0, 124)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			SoundManager.play("click")
			_on_chest_pressed(slot))
		var v := UIKit.vbox(0)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var icon := UIIcon.new("chest", 56.0)
		icon.name = "Icon"
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var title := UIKit.label("", 16, UIKit.TEXT, true)
		title.name = "Title"
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(title)
		var info := UIKit.label("", 16, UIKit.GOLD, true)
		info.name = "Info"
		info.clip_text = true
		v.add_child(info)
		row.add_child(b)
		_chest_buttons.append(b)

func _build_nav(parent: Control) -> void:
	var bar := UIKit.panel(Color(0.03, 0.05, 0.12, 0.94), 22, Color(1, 1, 1, 0.14), 2)
	bar.name = "NavBar"
	bar.custom_minimum_size = Vector2(0, 104)
	parent.add_child(bar)
	var h := UIKit.hbox(6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(UIKit.margin(h, 6, 6, 6, 6))
	for tab in NAV:
		var id: String = tab["id"]
		var b := Button.new()
		b.name = "Nav_" + id
		b.focus_mode = Control.FOCUS_NONE
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 90)
		b.pressed.connect(func() -> void:
			SoundManager.play("click")
			_set_tab(id))
		var v := UIKit.vbox(2)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var icon := UIIcon.new(str(tab["icon"]), 42.0)
		icon.name = "Icon"
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		var cap := UIKit.label(str(tab["text"]), 17, UIKit.TEXT, true)
		cap.name = "Caption"
		v.add_child(cap)
		var badge := UIKit.label("", 15, UIKit.TEXT, true)
		badge.add_theme_stylebox_override("normal", UIKit.box(UIKit.RED, 12))
		badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		badge.offset_left = -38.0
		badge.offset_top = 2.0
		badge.offset_right = -4.0
		badge.offset_bottom = 26.0
		badge.visible = false
		b.add_child(badge)
		h.add_child(b)
		_nav_buttons[id] = b
		_nav_badges[id] = badge
	_style_nav()

func _style_nav() -> void:
	for tab in NAV:
		var id: String = tab["id"]
		var b: Button = _nav_buttons[id]
		var col: Color = tab["color"]
		var active: bool = id == current_tab
		var base: Color = col if active else Color(0.1, 0.14, 0.27)
		b.add_theme_stylebox_override("normal", UIKit.button_box(base, false))
		b.add_theme_stylebox_override("hover", UIKit.button_box(base.lightened(0.08), false))
		b.add_theme_stylebox_override("pressed", UIKit.button_box(base, true))
		var icon := b.find_child("Icon", true, false) as UIIcon
		icon.set_kind(str(tab["icon"]), Color.WHITE if active else Color(0.72, 0.78, 0.9))
		var cap := b.find_child("Caption", true, false) as Label
		cap.add_theme_color_override("font_color", Color.WHITE if active else UIKit.TEXT_DIM)

# ================================================================ Tabs

func _set_tab(tab: String) -> void:
	if tab == "home":
		pages.close_all()
		_on_page_changed("")
		return
	for t in NAV:
		if str(t["id"]) == tab:
			pages.open(str(t["page"]))
			return

func _on_page_changed(page_id: String) -> void:
	var tab := "home"
	if page_id != "" and MenuPages.PAGES.has(page_id):
		tab = str(MenuPages.PAGES[page_id]["tab"])
	current_tab = tab
	_home.visible = tab == "home"
	_style_nav()
	_place_showcase()

# ================================================================ UI-Aktualisierung

func _refresh_top() -> void:
	if _avatar == null:
		return
	_avatar.set_player(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), GameManager.avatar_frame())
	_avatar.set_picture(ProfileManager.avatar_texture)
	_name_label.text = GameManager.player_name()
	_trophy_label.text = UIKit.format_number(GameManager.trophies())
	var lg: Dictionary = GameManager.league()
	_league_label.text = "· " + str(lg["name"])
	_league_label.add_theme_color_override("font_color", lg["color"])
	(_coin_pill.find_child("Value", true, false) as Label).text = UIKit.format_number(GameManager.coins())
	(_gem_pill.find_child("Value", true, false) as Label).text = UIKit.format_number(GameManager.gems())
	var st: String = AuthManager.status
	if not NetworkManager.is_configured():
		st = "Offline-Modus (Bots) · Backend in config/backend.cfg eintragen"
	_status_label.text = st
	_status_label.add_theme_color_override("font_color", UIKit.GREEN if NetworkManager.is_online() else UIKit.TEXT_DIM)
	if GameManager.daily_available():
		_daily_button.text = "GOLDEN\nSHOT"
		UIKit.set_button_color(_daily_button, Color(0.85, 0.6, 0.1))
	else:
		var best: float = GameManager.daily_best()
		_daily_button.text = "MORGEN\nWIEDER" if best < 0.0 else ("BEST\n%.1f m" % best if best > 0.0 else "EIN-\nGELOCHT!")
		UIKit.set_button_color(_daily_button, UIKit.GREY)
	refresh_play_info()
	_refresh_badges()

## Arena-Banner: Name, Beschreibung, Bahnen.
func _refresh_arena() -> void:
	if _arena_name == null:
		return
	var w: Dictionary = Catalog.world_by_id(MenuPages.sel_world)
	var ids: Array[String] = Catalog.world_ids()
	var col: Color = w["color"]
	_arena_index.text = "ARENA %d / %d" % [ids.find(str(w["id"])) + 1, ids.size()]
	_arena_name.text = str(w["name"]).to_upper()
	_arena_name.add_theme_color_override("font_color", col.lightened(0.35))
	_arena_desc.text = str(w.get("desc", ""))
	_arena_info.text = "%d Bahnen · im Bild: %s" % [(w["courses"] as Array).size(), CourseBuilder3D.course_title(str(BACKDROPS[str(w["id"])]))]
	_arena_panel.add_theme_stylebox_override("panel", UIKit.box(Color(0.03, 0.05, 0.12, 0.78), 22, col, 3))
	refresh_play_info()

## Zeile ueber SPIELEN: was ein Tipp auf SPIELEN startet.
func refresh_play_info() -> void:
	if _mode_button == null:
		return
	var w: String = str(Catalog.world_by_id(MenuPages.sel_world)["name"])
	if NetworkManager.is_online():
		_mode_button.text = "Online · %s · %d Runden · ändern" % [w, MenuPages.sel_rounds]
	else:
		_mode_button.text = "%d Bots · %s · %d Runden · ändern" % [MenuPages.sel_bots, w, MenuPages.sel_rounds]

func _refresh_badges() -> void:
	if _nav_badges.is_empty():
		return
	var incoming := 0
	for f in NetworkManager.friends:
		if str(f.get("state", "")) == "incoming":
			incoming += 1
	_set_badge("social", incoming + NetworkManager.invites.size())
	_set_badge("pass", GameManager.pass_claimable().size())
	_set_badge("shop", 1 if GameManager.gift_available() else 0)

func _set_badge(id: String, n: int) -> void:
	var badge: Label = _nav_badges[id]
	badge.visible = n > 0
	badge.text = str(n) if n < 100 else "99+"

func _refresh_chests() -> void:
	for i in _chest_buttons.size():
		var b: Button = _chest_buttons[i]
		var state: String = GameManager.chest_state(i)
		var title := b.find_child("Title", true, false) as Label
		var info := b.find_child("Info", true, false) as Label
		var icon := b.find_child("Icon", true, false) as UIIcon
		match state:
			"empty":
				UIKit.set_button_color(b, Color(0.05, 0.08, 0.16, 0.72))
				title.text = "Freier Slot"
				info.text = "Matches gewinnen"
				info.add_theme_color_override("font_color", UIKit.TEXT_DIM)
				icon.set_kind("chest", Color(1, 1, 1, 0.25))
			_:
				var c: Dictionary = GameManager.chest_slot(i)
				var def: Dictionary = Catalog.CHESTS[str(c["type"])]
				var col: Color = def["color"]
				UIKit.set_button_color(b, col.darkened(0.55))
				title.text = str(def["name"])
				icon.set_kind("chest", col.lightened(0.2))
				match state:
					"locked":
						info.text = UIKit.format_time(GameManager.chest_remaining(i))
						info.add_theme_color_override("font_color", UIKit.TEXT)
					"unlocking":
						info.text = UIKit.format_time(GameManager.chest_remaining(i))
						info.add_theme_color_override("font_color", UIKit.GOLD)
					"ready":
						info.text = "ÖFFNEN!"
						info.add_theme_color_override("font_color", UIKit.GREEN)
						UIKit.set_button_color(b, col.darkened(0.25))

func _refresh_invites() -> void:
	_refresh_badges()
	for c in _invite_bar.get_children():
		_invite_bar.remove_child(c)
		c.queue_free()
	if NetworkManager.invites.is_empty() or NetworkManager.in_lobby():
		_invite_bar.visible = false
		return
	var inv: Dictionary = NetworkManager.invites[0]
	var h := UIKit.hbox(8)
	var l := UIKit.label("%s lädt dich ein (Raum %s)" % [str(inv["from_name"]), str(inv["code"])], 19, UIKit.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(l)
	h.add_child(UIKit.button("Beitreten", UIKit.GREEN, func() -> void:
		NetworkManager.dismiss_invite(inv["id"])
		NetworkManager.join_lobby(str(inv["code"]))
		pages.open("lobby"), Vector2(140, 52), 19))
	h.add_child(UIKit.icon_button("close", UIKit.RED, func() -> void: NetworkManager.dismiss_invite(inv["id"]), 52.0))
	_invite_bar.add_child(UIKit.margin(h, 10, 6, 10, 6))
	_invite_bar.visible = true

func _on_inventory_changed() -> void:
	refresh_showcase()

# ================================================================ Aktionen

## SPIELEN: online ein Schnellspiel, sonst sofort ein Bot-Match mit den gewaehlten Einstellungen.
func _quick_play() -> void:
	if NetworkManager.is_online():
		NetworkManager.quick_match(MenuPages.sel_world, MenuPages.sel_rounds)
		pages.open("lobby")
		return
	NetworkManager.start_bot_match(MenuPages.sel_world, MenuPages.sel_rounds, MenuPages.sel_bots)

func _on_chest_pressed(slot: int) -> void:
	match GameManager.chest_state(slot):
		"empty":
			UIKit.toast(ui, "Truhen gibt es für Platz 1-3 in Matches, im Battle Pass, im Trophäen-Pfad und im Shop.")
		"ready":
			var rewards: Dictionary = GameManager.open_chest(slot, false)
			if not rewards.is_empty():
				pages.show_rewards("Truhe geöffnet!", rewards)
		_:
			pages.open_chest_dialog(slot)

func _start_daily() -> void:
	if not GameManager.daily_available():
		UIKit.toast(ui, "Den Golden Shot gibt es einmal pro Tag. Morgen wartet ein neuer Parcours!")
		return
	var cfg: Dictionary = GameManager.make_match_config("daily", "emerald", 1, [GameManager.local_player_entry()], GameManager.daily_seed(), false)
	GameManager.start_match(cfg)

func _show_last_match_rewards() -> void:
	var r: Dictionary = GameManager.last_match_rewards
	if r.is_empty():
		return
	GameManager.last_match_rewards = {}
	if bool(r.get("league_up", false)):
		UIKit.toast(ui, "Neue Liga erreicht: %s!" % str(r.get("league", "")), UIKit.GOLD.darkened(0.4))
		SoundManager.play("fanfare")
	elif not GameManager.pass_claimable().is_empty():
		UIKit.toast(ui, "Neue Battle-Pass-Belohnung bereit!", Color(0.4, 0.25, 0.7))

# ================================================================ Schleife

func _process(delta: float) -> void:
	_time += delta
	_update_camera(delta)
	_update_fireballs(delta)
	if showcase.visible:
		_update_showcase(delta)
	for wm in _decor_windmills:
		if is_instance_valid(wm):
			wm.call("update_time", _time)
	_ui_tick -= delta
	if _ui_tick <= 0.0:
		_ui_tick = 1.0
		_refresh_chests()
		_place_showcase()
		if pages != null:
			pages.tick()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if pages == null:
			return
		if pages.close_top():
			return
		pages.confirm_quit()
