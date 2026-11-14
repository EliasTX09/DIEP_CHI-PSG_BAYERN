class_name Preview3D
extends SubViewportContainer
## Kleine 3D-Vorschau fuer Shop, Tasche und Pass: Ball, Schlaeger oder Trail in einer eigenen, isolierten 3D-Welt.
## - live = false: wird genau einmal gerendert und danach als Bild angezeigt (guenstig, fuer Karten-Raster).
## - live = true: dreht sich laufend; Trails fliegen dabei im Kreis, damit der Schweif sichtbar wird.
## Wischen dreht das Objekt (nur live).

var kind: String = "ball"
var item_id: String = "standard"
var live: bool = false

var _viewport: SubViewport
var _pivot: Node3D
var _mover: Node3D
var _time: float = 0.0
var _spin: float = 0.0
var _spin_velocity: float = 0.0
var _dragging: bool = false
## Standbild: so viele Frames rendern (CSG-Koepfe und Shader sind dann sicher fertig), danach anhalten
var _frames_left: int = 4

func _init(p_kind: String = "ball", p_id: String = "standard", p_size: float = 120.0, p_live: bool = false) -> void:
	kind = p_kind
	item_id = p_id
	live = p_live
	stretch = false
	custom_minimum_size = Vector2(p_size, p_size)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_PASS if p_live else Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.size = Vector2i(int(p_size), int(p_size))
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE if p_live else SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_build_scene()

func _build_scene() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.8, 0.95)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = 0.6
	env.environment = e
	_viewport.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	sun.light_energy = 1.3
	_viewport.add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(-1.2, 0.8, -1.0)
	rim.light_color = Color(0.6, 0.75, 1.0)
	rim.light_energy = 1.2
	rim.omni_range = 4.0
	_viewport.add_child(rim)
	var cam := Camera3D.new()
	cam.fov = 32.0
	cam.current = true
	_viewport.add_child(cam)
	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	match kind:
		"club":
			var club := ClubModel.make(item_id)
			club.rotation = Vector3(0.0, 0.0, deg_to_rad(-28.0))
			_pivot.add_child(club)
			_pivot.rotation.y = 0.6
			cam.position = Vector3(0.0, 0.0, 2.55)
		"trail":
			_mover = Node3D.new()
			_pivot.add_child(_mover)
			_mover.add_child(BallFX.make_ball("standard", 0.16, GameManager.avatar_color()))
			var trail := BallFX.make_trail(item_id)
			if trail != null:
				trail.scale = Vector3.ONE * 0.45
				_mover.add_child(trail)
			_mover.position = Vector3(0.42, 0.0, 0.0)
			cam.position = Vector3(0.0, 0.75, 1.7)
			cam.look_at_from_position(cam.position, Vector3.ZERO, Vector3.UP)
		_:
			_pivot.add_child(BallFX.make_ball(item_id, 0.42, GameManager.avatar_color()))
			_pivot.rotation = Vector3(0.35, 0.5, 0.0)
			cam.position = Vector3(0.0, 0.0, 2.1)

## Neu rendern (z.B. nachdem sich die Spielerfarbe geaendert hat).
func render_again() -> void:
	if not live:
		_frames_left = 4
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		set_process(true)

func _process(delta: float) -> void:
	if not live:
		_frames_left -= 1
		if _frames_left <= 0:
			_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			set_process(false)
		return
	_time += delta
	if not _dragging:
		_spin_velocity = lerpf(_spin_velocity, 0.9, clampf(delta * 2.0, 0.0, 1.0))
	_spin += _spin_velocity * delta
	if kind == "trail" and _mover != null:
		var a: float = _time * 2.4
		_mover.position = Vector3(cos(a) * 0.42, sin(_time * 1.3) * 0.08, sin(a) * 0.42)
	else:
		_pivot.rotation.y = _spin

func _gui_input(event: InputEvent) -> void:
	if not live:
		return
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		_dragging = event.is_pressed()
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		if _dragging:
			var rel: Vector2 = event.get("relative")
			_spin += rel.x * 0.015
			_spin_velocity = clampf(rel.x * 0.6, -12.0, 12.0)
