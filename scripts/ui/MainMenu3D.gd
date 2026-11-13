class_name MainMenu3D
extends Node3D
## Kinoreifer 3D-Startbildschirm.
## - Hintergrund: echte Bahn "Die grosse Muehle" (Emerald Valley) mit animiertem Wasser-Shader, dazu schwebende
##   Inseln, Windmuehlen, Glitzer-Partikel und brennende Golfbaelle, die ueber den Himmel fliegen.
## - Kamera: fliegt endlos auf einer geschlossenen Spline (Curve3D) um die Insel.
## - Vordergrund: ausgeruesteter Ball + Schlaeger schweben links im Bild und drehen sich per Wischgeste (mit Schwung).
## - UI: Profil, Coins/Gems, SPIELEN, Golden Shot, Lobby, 4 Truhen-Slots, Reiter fuer alle Menue-Seiten (MenuPages).

const BACKDROP_COURSE := "e5"
const CAMERA_LOOP_SECONDS := 80.0
const FIREBALL_COUNT := 3
const TABS: Array[Dictionary] = [
	{"id": "clubs", "icon": "club", "text": "Schläger", "color": Color(0.95, 0.55, 0.2)},
	{"id": "cosmetics", "icon": "ball", "text": "Bälle & FX", "color": Color(0.62, 0.36, 1.0)},
	{"id": "friends", "icon": "friends", "text": "Freunde", "color": Color(0.18, 0.56, 1.0)},
	{"id": "leaderboard", "icon": "leader", "text": "Rangliste", "color": Color(0.25, 0.75, 0.6)},
	{"id": "shop", "icon": "shop", "text": "Shop", "color": Color(0.95, 0.3, 0.45)},
	{"id": "trophies", "icon": "trophy", "text": "Trophäen", "color": Color(0.9, 0.7, 0.15)},
]

var course: Course3D
var camera: Camera3D
var showcase: Node3D
var pages: MenuPages
var ui: Control

var _curve: Curve3D
var _center: Vector3 = Vector3.ZERO
var _cam_offset: float = 0.0
var _time: float = 0.0
var _decor_windmills: Array[Node] = []
var _fireballs: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

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

# UI-Elemente, die aktualisiert werden
var _avatar: UIAvatar
var _name_label: Label
var _league_label: Label
var _trophy_label: Label
var _coin_pill: PanelContainer
var _gem_pill: PanelContainer
var _status_label: Label
var _daily_button: Button
var _chest_buttons: Array[Button] = []
var _invite_bar: PanelContainer
var _friends_badge: Label
var _showcase_label: Label
var _ui_tick: float = 0.0

func _ready() -> void:
	_rng.seed = int(Time.get_ticks_usec())
	Engine.time_scale = 1.0
	get_tree().paused = false
	_build_world()
	_build_camera()
	_build_showcase()
	_build_ui()
	pages = MenuPages.new(self, ui)
	GameManager.currency_changed.connect(_refresh_top)
	GameManager.profile_changed.connect(_refresh_top)
	GameManager.inventory_changed.connect(_on_inventory_changed)
	GameManager.chests_changed.connect(_refresh_chests)
	GameManager.toast.connect(func(msg: String) -> void: UIKit.toast(ui, msg))
	NetworkManager.status_changed.connect(func(_t: String) -> void: _refresh_top())
	NetworkManager.auth_changed.connect(_refresh_top)
	NetworkManager.invites_updated.connect(_refresh_invites)
	NetworkManager.friends_updated.connect(_refresh_invites)
	NetworkManager.lobby_error.connect(func(msg: String) -> void: UIKit.toast(ui, msg, UIKit.RED.darkened(0.3)))
	NetworkManager.lobby_joined.connect(func(_code: String) -> void:
		if pages.page != "lobby":
			pages.open("lobby"))
	_refresh_top()
	_refresh_chests()
	_refresh_invites()
	NetworkManager.refresh_invites()
	NetworkManager.refresh_friends()
	_show_last_match_rewards()

# ================================================================ 3D-Welt

func _build_world() -> void:
	course = CourseBuilder3D.build(BACKDROP_COURSE, 7, true)
	course.name = "BackdropCourse"
	add_child(course)
	var b: AABB = course.bounds
	if b.size == Vector3.ZERO:
		b = AABB(Vector3(-30, -2, -60), Vector3(60, 8, 60))
	_center = b.get_center()
	_center.y = maxf(_center.y, 0.0)
	var radius: float = maxf(b.size.x, b.size.z) * 0.5
	# Schwebende Inseln rund um die Bahn
	for i in 6:
		var ang: float = TAU * float(i) / 6.0 + _rng.randf_range(-0.25, 0.25)
		var dist: float = radius + _rng.randf_range(16.0, 30.0)
		var pos := _center + Vector3(sin(ang) * dist, _rng.randf_range(7.0, 15.0), cos(ang) * dist)
		var island := _make_floating_island(_rng.randf_range(3.0, 5.5), i % 2 == 0)
		island.position = pos
		add_child(island)
	# Glitzer-Partikel ueber der ganzen Szene
	var sparkle := Mat.particles({"amount": 90, "lifetime": 7.0, "spread": 180.0, "speed": Vector2(0.1, 0.4),
		"gravity": Vector3(0.0, 0.12, 0.0), "size": 0.22, "scale": Vector2(0.4, 1.0),
		"emission_box": Vector3(radius + 20.0, 5.0, radius + 20.0),
		"colors": [Color(1.0, 0.95, 0.6, 0.0), Color(1.0, 0.9, 0.5, 0.9), Color(0.6, 1.0, 0.8, 0.0)]})
	sparkle.visibility_aabb = AABB(Vector3(-200, -40, -200), Vector3(400, 80, 400))
	sparkle.position = _center + Vector3(0.0, 6.0, 0.0)
	add_child(sparkle)
	# Brennende Golfbaelle am Himmel
	for i in FIREBALL_COUNT:
		_spawn_fireball(float(i) * 1.7)

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
	# kleiner Wasserfall an einer Kante
	if _rng.randf() < 0.6:
		var fall := Mat.vplane(Vector2(1.2, r * 2.2), Mat.shader("waterfall"), Vector3(r * 0.95, -r * 1.1, 0.0), 6)
		fall.rotation.y = PI * 0.5
		holder.add_child(fall)
	return root

## Ein brennender Golfball fliegt auf einer Parabel ueber die Szene; danach startet er neu.
func _spawn_fireball(delay: float) -> void:
	var node := Node3D.new()
	add_child(node)
	var ball := BallFX.make_ball("magma", 0.55)
	node.add_child(ball)
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

func _build_camera() -> void:
	camera = Camera3D.new()
	camera.fov = 55.0
	camera.far = 900.0
	camera.current = true
	add_child(camera)
	var b: AABB = course.bounds
	var r: float = maxf(b.size.x, b.size.z) * 0.5 + 14.0
	_curve = Curve3D.new()
	var pts: Array[Vector3] = []
	var n := 8
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var rr: float = r * (1.0 + 0.18 * sin(a * 2.0 + 0.7))
		var h: float = 11.0 + 6.0 * sin(a * 3.0 + 1.3)
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
	var pos: Vector3 = _curve.sample_baked(_cam_offset, true)
	camera.global_position = pos
	var look: Vector3 = _center + Vector3(sin(_time * 0.11) * 6.0, 1.5, cos(_time * 0.09) * 6.0)
	camera.look_at(look, Vector3.UP)
	# leichter Versatz nach rechts, damit links Platz fuer die Vitrine bleibt
	camera.rotate_object_local(Vector3.UP, deg_to_rad(9.0))

# ================================================================ Vitrine: Ball + Schlaeger

func _build_showcase() -> void:
	showcase = Node3D.new()
	showcase.name = "Showcase"
	camera.add_child(showcase)
	# eigenes Licht, damit die Objekte unabhaengig von der Kameraposition gut ausgeleuchtet sind
	var key := OmniLight3D.new()
	key.position = Vector3(-0.6, 1.2, -1.6)
	key.light_energy = 1.6
	key.omni_range = 6.0
	key.light_color = Color(1.0, 0.95, 0.88)
	showcase.add_child(key)
	_ball_pivot = Node3D.new()
	_ball_pivot.position = Vector3(-1.75, -0.42, -3.6)
	showcase.add_child(_ball_pivot)
	_club_pivot = Node3D.new()
	_club_pivot.position = Vector3(-0.95, -0.25, -3.6)
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
		trail.position = Vector3(0.0, 0.0, 0.0)
		_ball_pivot.add_child(trail)
		_trail_node = trail
	_club_node = ClubModel.make(GameManager.equipped_club())
	_club_node.scale = Vector3.ONE * 1.25
	_club_node.rotation = Vector3(0.0, 0.0, deg_to_rad(-18.0))
	_club_pivot.add_child(_club_node)
	if _showcase_label != null:
		var club: String = GameManager.equipped_club()
		_showcase_label.text = "%s · Lv %d\n%s" % [Catalog.club_name(club), GameManager.club_level(club),
			Catalog.item_name("ball", GameManager.equipped("ball"))]
		_showcase_label.add_theme_color_override("font_color", Catalog.RARITY_COLORS.get(Catalog.club_rarity(club), Color.WHITE))

func _update_showcase(delta: float) -> void:
	_idle += delta
	if not _dragging:
		# Schwung abbauen, danach langsam von selbst weiterdrehen
		_spin_velocity = lerpf(_spin_velocity, 0.6 if _idle > 1.5 else 0.0, clampf(delta * 1.8, 0.0, 1.0))
	_spin_angle += _spin_velocity * delta
	_ball_pivot.rotation.y = _spin_angle
	if _ball_node != null:
		_ball_node.rotation.x += delta * 0.4
	_club_pivot.rotation.y = _spin_angle * 0.8 + 0.4
	var bob: float = sin(_time * 1.3) * 0.06
	_ball_pivot.position.y = -0.42 + bob
	_club_pivot.position.y = -0.25 - bob * 0.7

## true, wenn eine Bildschirmposition im Bereich der Vitrine (linke Bildhaelfte, Mitte) liegt.
func _in_showcase_area(pos: Vector2) -> bool:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	return pos.x < vp.x * 0.5 and pos.y > vp.y * 0.18 and pos.y < vp.y * 0.8

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

# ================================================================ UI

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
	var safe := MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(safe)
	UIKit.apply_safe_area(safe, 14)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe.add_child(frame)
	_build_top_bar(frame)
	_build_tabs(frame)
	_build_play_column(frame)
	_build_chest_row(frame)
	_build_showcase_caption(frame)
	_build_invite_bar(frame)
	_status_label = UIKit.label("", 16, UIKit.TEXT_DIM)
	# Verbindungsstatus klein unter der Waehrungsleiste
	_status_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_status_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.offset_left = -620.0
	_status_label.offset_top = 70.0
	_status_label.offset_right = 0.0
	_status_label.offset_bottom = 92.0
	_status_label.add_theme_constant_override("outline_size", 6)
	_status_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	frame.add_child(_status_label)

func _build_top_bar(frame: Control) -> void:
	var bar := UIKit.hbox(12)
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 70.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bar)
	# Profil-Karte (tippen -> Einstellungen/Account)
	var profile := Button.new()
	profile.focus_mode = Control.FOCUS_NONE
	profile.custom_minimum_size = Vector2(330, 68)
	UIKit.set_button_color(profile, Color(0.03, 0.05, 0.12, 0.85))
	profile.pressed.connect(func() -> void:
		SoundManager.play("click")
		pages.open("settings"))
	bar.add_child(profile)
	var ph := UIKit.hbox(10)
	ph.set_anchors_preset(Control.PRESET_FULL_RECT)
	ph.offset_left = 8.0
	ph.offset_right = -8.0
	ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	profile.add_child(ph)
	_avatar = UIAvatar.new(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), GameManager.avatar_frame(), 56.0)
	_avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_avatar)
	var pv := UIKit.vbox(0)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ph.add_child(pv)
	_name_label = UIKit.label(GameManager.player_name(), 22, UIKit.TEXT)
	pv.add_child(_name_label)
	var lh := UIKit.hbox(6)
	lh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(lh)
	lh.add_child(UIIcon.new("trophy", 20.0))
	_trophy_label = UIKit.label("0", 18, UIKit.GOLD)
	lh.add_child(_trophy_label)
	_league_label = UIKit.label("", 18, UIKit.TEXT_DIM)
	lh.add_child(_league_label)
	bar.add_child(UIKit.spacer(true))
	_coin_pill = UIKit.currency_pill("coin", GameManager.coins())
	_coin_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_coin_pill)
	_gem_pill = UIKit.currency_pill("gem", GameManager.gems())
	_gem_pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_gem_pill)
	var shop_plus := UIKit.icon_button("plus", UIKit.GREEN, func() -> void: pages.open("shop"), 52.0)
	shop_plus.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(shop_plus)
	var settings := UIKit.icon_button("settings", UIKit.GREY, func() -> void: pages.open("settings"), 60.0)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(settings)

func _build_tabs(frame: Control) -> void:
	var col := UIKit.vbox(8)
	col.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	col.offset_top = 84.0
	col.offset_bottom = -4.0
	col.offset_right = 104.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(col)
	for tab in TABS:
		var id: String = tab["id"]
		var b := UIKit.button("", tab["color"], func() -> void: pages.open(id), Vector2(104, 82))
		b.name = "Tab_" + id
		var icon := UIIcon.new(str(tab["icon"]), 38.0)
		icon.position = Vector2(33, 8)
		icon.size = Vector2(38, 38)
		b.add_child(icon)
		var cap := UIKit.label(str(tab["text"]), 15, UIKit.TEXT, true)
		cap.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		cap.offset_top = -30.0
		cap.offset_bottom = -6.0
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cap)
		if id == "friends":
			_friends_badge = UIKit.label("", 15, UIKit.TEXT, true)
			_friends_badge.add_theme_stylebox_override("normal", UIKit.box(UIKit.RED, 12))
			_friends_badge.position = Vector2(74, -6)
			_friends_badge.size = Vector2(32, 24)
			_friends_badge.visible = false
			b.add_child(_friends_badge)
		col.add_child(b)

func _build_play_column(frame: Control) -> void:
	var col := UIKit.vbox(14)
	col.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	col.offset_left = -450.0
	col.offset_top = 88.0
	col.offset_bottom = -150.0
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(col)
	var title := UIKit.label("GOLF BATTLE 3D", 50, UIKit.GOLD, true)
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.08, 0.0))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.5))
	title.add_theme_constant_override("shadow_offset_y", 5)
	col.add_child(title)
	var sub := UIKit.label("Arcade-Minigolf · bis zu 6 Spieler", 22, UIKit.TEXT, true)
	sub.add_theme_constant_override("outline_size", 8)
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	col.add_child(sub)
	var play := UIKit.button("SPIELEN", UIKit.GREEN, func() -> void: pages.open("play"), Vector2(420, 112), 46)
	play.name = "PlayButton"
	play.add_theme_constant_override("outline_size", 10)
	play.add_theme_color_override("font_outline_color", Color(0.05, 0.25, 0.08))
	col.add_child(play)
	play.pivot_offset = Vector2(210, 56)
	var pulse := play.create_tween().set_loops()
	pulse.tween_property(play, "scale", Vector2(1.04, 1.04), 0.7).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(play, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
	var row := UIKit.hbox(12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(row)
	_daily_button = UIKit.button("GOLDEN SHOT", Color(0.85, 0.6, 0.1), _start_daily, Vector2(204, 76), 22)
	_daily_button.name = "DailyButton"
	row.add_child(_daily_button)
	var lobby := UIKit.button("LOBBY", UIKit.PURPLE, func() -> void: pages.open("lobby"), Vector2(204, 76), 24)
	lobby.name = "LobbyButton"
	row.add_child(lobby)

func _build_chest_row(frame: Control) -> void:
	var row := UIKit.hbox(12)
	row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	row.grow_horizontal = Control.GROW_DIRECTION_BOTH
	row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	row.offset_left = -250.0
	row.offset_right = 550.0
	row.offset_top = -124.0
	row.offset_bottom = -4.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(row)
	_chest_buttons.clear()
	for i in Catalog.CHEST_SLOTS:
		var slot: int = i
		var b := Button.new()
		b.name = "Chest%d" % i
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(184, 118)
		b.pressed.connect(func() -> void:
			SoundManager.play("click")
			_on_chest_pressed(slot))
		var icon := UIIcon.new("chest", 54.0)
		icon.name = "Icon"
		icon.position = Vector2(65, 6)
		icon.size = Vector2(54, 54)
		b.add_child(icon)
		var title := UIKit.label("", 17, UIKit.TEXT, true)
		title.name = "Title"
		title.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		title.offset_top = -56.0
		title.offset_bottom = -32.0
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(title)
		var info := UIKit.label("", 17, UIKit.GOLD, true)
		info.name = "Info"
		info.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		info.offset_top = -30.0
		info.offset_bottom = -6.0
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(info)
		row.add_child(b)
		_chest_buttons.append(b)

func _build_showcase_caption(frame: Control) -> void:
	_showcase_label = UIKit.label("", 19, UIKit.TEXT, true)
	_showcase_label.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_showcase_label.offset_left = 150.0
	_showcase_label.offset_right = 520.0
	_showcase_label.offset_top = 150.0
	_showcase_label.offset_bottom = 205.0
	_showcase_label.add_theme_constant_override("outline_size", 8)
	_showcase_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	frame.add_child(_showcase_label)
	var hint := UIKit.label("Wischen zum Drehen", 15, UIKit.TEXT_DIM, true)
	hint.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	hint.offset_left = 150.0
	hint.offset_right = 520.0
	hint.offset_top = 205.0
	hint.offset_bottom = 227.0
	hint.add_theme_constant_override("outline_size", 6)
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	frame.add_child(hint)
	refresh_showcase()

func _build_invite_bar(frame: Control) -> void:
	_invite_bar = UIKit.panel(Color(0.35, 0.15, 0.6, 0.95), 18, Color(1, 1, 1, 0.4), 2)
	_invite_bar.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_invite_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_invite_bar.offset_top = 84.0
	_invite_bar.visible = false
	frame.add_child(_invite_bar)

# ================================================================ UI-Aktualisierung

func _refresh_top() -> void:
	if _avatar == null:
		return
	_avatar.set_player(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), GameManager.avatar_frame())
	_name_label.text = GameManager.player_name()
	_trophy_label.text = UIKit.format_number(GameManager.trophies())
	var lg: Dictionary = GameManager.league()
	_league_label.text = "· " + str(lg["name"])
	_league_label.add_theme_color_override("font_color", lg["color"])
	(_coin_pill.find_child("Value", true, false) as Label).text = UIKit.format_number(GameManager.coins())
	(_gem_pill.find_child("Value", true, false) as Label).text = UIKit.format_number(GameManager.gems())
	var st: String = NetworkManager.status
	if not NetworkManager.is_configured():
		st = "Offline-Modus (Bots) · Backend in config/backend.cfg eintragen"
	_status_label.text = st
	_status_label.add_theme_color_override("font_color", UIKit.GREEN if NetworkManager.is_online() else UIKit.TEXT_DIM)
	if GameManager.daily_available():
		_daily_button.text = "GOLDEN SHOT"
		UIKit.set_button_color(_daily_button, Color(0.85, 0.6, 0.1))
	else:
		var best: float = GameManager.daily_best()
		_daily_button.text = "MORGEN WIEDER" if best < 0.0 else ("BESTWERT %.1f m" % best if best > 0.0 else "EINGELOCHT!")
		UIKit.set_button_color(_daily_button, UIKit.GREY)

func _refresh_chests() -> void:
	for i in _chest_buttons.size():
		var b: Button = _chest_buttons[i]
		var state: String = GameManager.chest_state(i)
		var title := b.get_node("Title") as Label
		var info := b.get_node("Info") as Label
		var icon := b.get_node("Icon") as UIIcon
		match state:
			"empty":
				UIKit.set_button_color(b, Color(0.05, 0.08, 0.16, 0.7))
				title.text = "Freier Slot"
				info.text = "Gewinne Matches"
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
						info.text = "Öffnen: " + UIKit.format_time(GameManager.chest_remaining(i))
						info.add_theme_color_override("font_color", UIKit.TEXT)
					"unlocking":
						info.text = UIKit.format_time(GameManager.chest_remaining(i))
						info.add_theme_color_override("font_color", UIKit.GOLD)
					"ready":
						info.text = "ÖFFNEN!"
						info.add_theme_color_override("font_color", UIKit.GREEN)
						UIKit.set_button_color(b, col.darkened(0.25))

func _refresh_invites() -> void:
	var incoming := 0
	for f in NetworkManager.friends:
		if str(f.get("state", "")) == "incoming":
			incoming += 1
	var total: int = incoming + NetworkManager.invites.size()
	if _friends_badge != null:
		_friends_badge.visible = total > 0
		_friends_badge.text = str(total)
	for c in _invite_bar.get_children():
		_invite_bar.remove_child(c)
		c.queue_free()
	if NetworkManager.invites.is_empty() or NetworkManager.in_lobby():
		_invite_bar.visible = false
		return
	var inv: Dictionary = NetworkManager.invites[0]
	var h := UIKit.hbox(12)
	h.add_child(UIKit.label("%s lädt dich ein (Raum %s)" % [str(inv["from_name"]), str(inv["code"])], 22, UIKit.TEXT))
	h.add_child(UIKit.button("Beitreten", UIKit.GREEN, func() -> void:
		NetworkManager.dismiss_invite(inv["id"])
		NetworkManager.join_lobby(str(inv["code"]))
		pages.open("lobby"), Vector2(150, 52), 20))
	h.add_child(UIKit.icon_button("close", UIKit.RED, func() -> void: NetworkManager.dismiss_invite(inv["id"]), 52.0))
	_invite_bar.add_child(UIKit.margin(h, 12, 6, 12, 6))
	_invite_bar.visible = true

func _on_inventory_changed() -> void:
	refresh_showcase()

# ================================================================ Aktionen

func _on_chest_pressed(slot: int) -> void:
	match GameManager.chest_state(slot):
		"empty":
			UIKit.toast(ui, "Truhen gibt es für Platz 1-3 in Matches, im Trophäen-Pfad und im Shop.")
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

# ================================================================ Schleife

func _process(delta: float) -> void:
	_time += delta
	_update_camera(delta)
	_update_fireballs(delta)
	_update_showcase(delta)
	for wm in _decor_windmills:
		wm.call("update_time", _time)
	_ui_tick -= delta
	if _ui_tick <= 0.0:
		_ui_tick = 1.0
		_refresh_chests()
		if pages != null:
			pages.tick()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if pages == null:
			return
		if pages.close_top():
			return
		pages.confirm_quit()
