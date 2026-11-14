class_name BallFX
extends RefCounted
## Optik rund um den Ball: Skins (Shader), Partikel-Trails, Loch-Explosionen, Wasser-/Lava-Spritzer.
## Alles wird per Code erzeugt.

const RAINBOW: Array[Color] = [
	Color(1.0, 0.2, 0.2), Color(1.0, 0.6, 0.1), Color(1.0, 0.95, 0.2), Color(0.3, 0.9, 0.3),
	Color(0.2, 0.85, 1.0), Color(0.35, 0.4, 1.0), Color(0.75, 0.3, 1.0),
]

# ================================================================ Ball-Skins

static func ball_material(skin: String, player_color: Color = Color(0.2, 0.6, 1.0)) -> Material:
	match skin:
		"magma":
			return Mat.shader("ball_noise", {"mode": 0, "base_color": Color(0.09, 0.05, 0.05), "glow_color": Color(1.0, 0.45, 0.08), "glow": 3.2})
		"holo":
			return Mat.shader("hologram", {})
		"gold":
			return Mat.shader("ball_standard", {"base_color": Color(1.0, 0.78, 0.25), "stripe_color": Color(1.0, 0.92, 0.55),
				"surface_metallic": 1.0, "surface_roughness": 0.22})
		"lightning":
			return Mat.shader("ball_noise", {"mode": 1, "base_color": Color(0.04, 0.07, 0.2), "glow_color": Color(0.4, 0.75, 1.0), "glow": 3.0})
		"soccer":
			return Mat.shader("soccer_ball", {})
	return Mat.shader("ball_standard", {"stripe_color": player_color})

## Ball-Mesh (Kugel) mit Skin. Die Blitz-Kugel bekommt zusaetzlich ein kleines Licht.
static func make_ball(skin: String, radius: float, player_color: Color = Color(0.2, 0.6, 1.0)) -> Node3D:
	var mi := Mat.sphere(radius, ball_material(skin, player_color), Vector3.ZERO, 28)
	mi.name = "BallMesh"
	if skin == "lightning" or skin == "magma":
		var light := OmniLight3D.new()
		light.light_color = Color(0.4, 0.7, 1.0) if skin == "lightning" else Color(1.0, 0.5, 0.15)
		light.light_energy = 1.2
		light.omni_range = 3.0
		light.shadow_enabled = false
		mi.add_child(light)
	return mi

# ================================================================ Trails

static func make_trail(trail_id: String) -> GPUParticles3D:
	match trail_id:
		"fire":
			return Mat.particles({"amount": 40, "lifetime": 0.6, "direction": Vector3.UP, "spread": 25.0, "speed": Vector2(0.3, 1.2),
				"gravity": Vector3(0, 2.5, 0), "size": 0.5, "scale": Vector2(0.5, 1.2),
				"colors": [Color(1.0, 0.9, 0.3, 0.9), Color(1.0, 0.4, 0.05, 0.7), Color(0.4, 0.0, 0.0, 0.0)]})
		"lightning":
			return Mat.particles({"amount": 30, "lifetime": 0.35, "spread": 180.0, "speed": Vector2(1.0, 4.0), "gravity": Vector3.ZERO,
				"size": 0.22, "scale": Vector2(0.4, 1.3), "colors": [Color(1, 1, 1, 1), Color(0.4, 0.7, 1.0, 0.9), Color(0.2, 0.3, 1.0, 0.0)]})
		"rainbow":
			var cols: Array = RAINBOW.duplicate()
			cols.append(Color(0.75, 0.3, 1.0, 0.0))
			return Mat.particles({"amount": 64, "lifetime": 0.9, "spread": 180.0, "speed": Vector2(0.0, 0.2), "gravity": Vector3.ZERO,
				"size": 0.42, "scale": Vector2(0.8, 1.0), "additive": false, "colors": cols})
		"matrix":
			var qm := QuadMesh.new()
			qm.size = Vector2(0.1, 0.36)
			qm.material = Mat.particle(true)
			return Mat.particles({"amount": 36, "lifetime": 1.0, "direction": Vector3.DOWN, "spread": 6.0, "speed": Vector2(1.5, 3.5),
				"gravity": Vector3(0, -2.0, 0), "scale": Vector2(0.6, 1.6), "emission_radius": 0.25, "mesh": qm,
				"colors": [Color(0.7, 1.0, 0.7, 1.0), Color(0.1, 0.9, 0.2, 0.8), Color(0.0, 0.4, 0.05, 0.0)]})
		"ice":
			var pm := PrismMesh.new()
			pm.size = Vector3(0.14, 0.24, 0.14)
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.emission_enabled = true
			mat.emission = Color(0.4, 0.7, 1.0)
			mat.emission_energy_multiplier = 0.8
			mat.roughness = 0.1
			pm.material = mat
			return Mat.particles({"amount": 28, "lifetime": 1.1, "spread": 180.0, "speed": Vector2(0.3, 1.2), "gravity": Vector3(0, -1.5, 0),
				"scale": Vector2(0.5, 1.3), "mesh": pm, "angular_velocity": Vector2(-200.0, 200.0),
				"colors": [Color(1, 1, 1, 1), Color(0.6, 0.9, 1.0, 0.85), Color(0.4, 0.7, 1.0, 0.0)]})
	return null

# ================================================================ Effekte

static func _autofree(node: Node, seconds: float) -> void:
	node.get_tree().create_timer(seconds).timeout.connect(node.queue_free)

static func _burst(parent: Node3D, pos: Vector3, opts: Dictionary, keep: float) -> GPUParticles3D:
	opts["one_shot"] = true
	if not opts.has("explosiveness"):
		opts["explosiveness"] = 0.95
	var p := Mat.particles(opts)
	parent.add_child(p)
	p.global_position = pos
	p.restart()
	p.emitting = true
	_autofree(p, keep)
	return p

static func _flash(parent: Node3D, pos: Vector3, color: Color, energy: float, light_range: float, seconds: float) -> void:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	parent.add_child(light)
	light.global_position = pos
	var tw := light.create_tween()
	tw.tween_property(light, "light_energy", 0.0, seconds)
	tw.tween_callback(light.queue_free)

## Wasser-/Lava-Spritzer an der Stelle, an der ein Ball versinkt.
static func splash(parent: Node3D, pos: Vector3, kind: String) -> void:
	if kind == "lava":
		_burst(parent, pos, {"amount": 50, "lifetime": 1.1, "direction": Vector3.UP, "spread": 35.0, "speed": Vector2(4.0, 9.0),
			"gravity": Vector3(0, -14, 0), "size": 0.35, "colors": [Color(1, 0.9, 0.3, 1), Color(1, 0.4, 0.05, 0.9), Color(0.3, 0, 0, 0)]}, 2.0)
		_flash(parent, pos + Vector3.UP, Color(1.0, 0.5, 0.1), 5.0, 9.0, 0.6)
	elif kind == "water":
		_burst(parent, pos, {"amount": 50, "lifetime": 1.0, "direction": Vector3.UP, "spread": 30.0, "speed": Vector2(4.0, 8.0),
			"gravity": Vector3(0, -15, 0), "size": 0.3, "additive": false,
			"colors": [Color(1, 1, 1, 0.95), Color(0.7, 0.9, 1.0, 0.8), Color(0.6, 0.85, 1.0, 0.0)]}, 2.0)
	elif kind == "ob":
		# Aus: Erd- und Grasbrocken spritzen auf
		_burst(parent, pos, {"amount": 40, "lifetime": 0.9, "direction": Vector3.UP, "spread": 50.0, "speed": Vector2(3.0, 7.0),
			"gravity": Vector3(0, -16, 0), "size": 0.22, "additive": false,
			"colors": [Color(0.45, 0.32, 0.2, 1.0), Color(0.3, 0.5, 0.2, 0.9), Color(0.35, 0.3, 0.2, 0.0)]}, 1.8)
	else:
		_burst(parent, pos, {"amount": 30, "lifetime": 0.6, "spread": 180.0, "speed": Vector2(2.0, 6.0), "gravity": Vector3.ZERO,
			"size": 0.25, "colors": [Color(1, 0.3, 0.4, 1), Color(1, 0.2, 0.8, 0.0)]}, 1.5)

## Loch-Explosion des Spielers. Liefert die empfohlene Kamerawackel-Staerke (0..1).
static func hole_explosion(parent: Node3D, kind: String, pos: Vector3) -> float:
	match kind:
		"lightning":
			_fx_lightning(parent, pos)
			return 1.0
		"blackhole":
			_fx_blackhole(parent, pos)
			return 0.8
		"volcano":
			_fx_volcano(parent, pos)
			return 0.9
		"fireworks":
			_fx_fireworks(parent, pos)
			return 0.6
	_fx_confetti(parent, pos)
	return 0.5

static func _fx_confetti(parent: Node3D, pos: Vector3) -> void:
	SoundManager.play("pop", 1.0, 0.8)
	for i in 2:
		var opts := {"amount": 110, "lifetime": 2.4, "direction": Vector3(0.25 * (float(i) * 2.0 - 1.0), 1.0, 0.0), "spread": 28.0,
			"speed": Vector2(8.0, 14.0), "gravity": Vector3(0, -11, 0), "size": 0.24, "scale": Vector2(0.6, 1.3), "additive": false,
			"random_color": true, "colors": RAINBOW, "angular_velocity": Vector2(-500.0, 500.0), "damping": Vector2(1.0, 3.0)}
		_burst(parent, pos + Vector3(0, 0.3, 0), opts, 3.5)
	_flash(parent, pos + Vector3.UP * 1.5, Color(1.0, 0.95, 0.7), 4.0, 10.0, 0.5)

static func _fx_lightning(parent: Node3D, pos: Vector3) -> void:
	SoundManager.play("thunder")
	var bolt := Node3D.new()
	parent.add_child(bolt)
	bolt.global_position = pos
	var mat := Mat.glow(Color(0.7, 0.85, 1.0), 8.0, Color(0.8, 0.9, 1.0))
	var prev := Vector3.ZERO
	var height := 34.0
	var segments := 10
	for i in range(1, segments + 1):
		var y: float = height * float(i) / float(segments)
		var jitter: float = 1.6 if i < segments else 0.0
		var next := Vector3(randf_range(-jitter, jitter), y, randf_range(-jitter, jitter))
		var seg := Mat.box(Vector3(0.22, prev.distance_to(next), 0.22), mat, (prev + next) * 0.5)
		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bolt.add_child(seg)
		var dir: Vector3 = (next - prev).normalized()
		var axis: Vector3 = Vector3.UP.cross(dir)
		if axis.length() > 0.001:
			seg.transform.basis = Basis(axis.normalized(), Vector3.UP.angle_to(dir))
		prev = next
	var tw := bolt.create_tween()
	for i in 3:
		tw.tween_property(bolt, "visible", false, 0.0).set_delay(0.07)
		tw.tween_property(bolt, "visible", true, 0.0).set_delay(0.05)
	tw.tween_interval(0.12)
	tw.tween_callback(bolt.queue_free)
	_flash(parent, pos + Vector3.UP * 2.0, Color(0.7, 0.85, 1.0), 14.0, 30.0, 0.7)
	_burst(parent, pos + Vector3(0, 0.2, 0), {"amount": 90, "lifetime": 0.8, "direction": Vector3.UP, "spread": 75.0, "speed": Vector2(6.0, 16.0),
		"gravity": Vector3(0, -18, 0), "size": 0.18, "colors": [Color(1, 1, 1, 1), Color(0.5, 0.75, 1.0, 0.9), Color(0.2, 0.3, 1.0, 0.0)]}, 2.0)

static func _fx_blackhole(parent: Node3D, pos: Vector3) -> void:
	SoundManager.play("blackhole")
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 1.4, 0)
	var core := Mat.sphere(1.0, Mat.unlit(Color(0, 0, 0), false, false), Vector3.ZERO, 20)
	core.scale = Vector3.ONE * 0.05
	root.add_child(core)
	var disc := Mat.plane(Vector2(7.0, 7.0), Mat.shader("portal", {"color_a": Color(0.7, 0.3, 1.0), "color_b": Color(1.0, 0.5, 0.2),
		"core_dark": 1.0, "spin": 9.0, "intensity": 1.6}))
	disc.scale = Vector3.ONE * 0.05
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(disc)
	var suck := Mat.particles({"amount": 110, "lifetime": 1.0, "spread": 180.0, "speed": Vector2(0.0, 0.5), "gravity": Vector3.ZERO,
		"emission_ring": Vector2(7.0, 3.0), "radial_accel": -34.0, "tangential_accel": 14.0, "size": 0.2, "local": true,
		"colors": [Color(0.8, 0.5, 1.0, 0.0), Color(0.8, 0.4, 1.0, 1.0), Color(1.0, 0.8, 0.5, 1.0)]})
	root.add_child(suck)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(core, "scale", Vector3.ONE * 1.3, 1.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(disc, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.set_parallel(false)
	tw.tween_interval(0.15)
	tw.tween_callback(func() -> void: suck.emitting = false)
	tw.set_parallel(true)
	tw.tween_property(core, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	tw.tween_property(disc, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
	tw.set_parallel(false)
	tw.tween_callback(func() -> void:
		SoundManager.play("bass")
		BallFX._flash(parent, pos + Vector3.UP * 1.4, Color(0.8, 0.5, 1.0), 12.0, 22.0, 0.6)
		BallFX._burst(parent, pos + Vector3.UP * 1.4, {"amount": 120, "lifetime": 1.0, "spread": 180.0, "speed": Vector2(8.0, 18.0),
			"gravity": Vector3.ZERO, "damping": Vector2(6.0, 10.0), "size": 0.22,
			"colors": [Color(1, 1, 1, 1), Color(0.8, 0.4, 1.0, 0.9), Color(0.3, 0.1, 0.6, 0.0)]}, 2.0)
		root.queue_free())

static func _fx_volcano(parent: Node3D, pos: Vector3) -> void:
	SoundManager.play("bass")
	SoundManager.play("splash_lava", 1.0, 0.8)
	var cone := Mat.cylinder(0.5, 1.7, 1.6, Mat.flat(Color(0.2, 0.13, 0.1), 0.95), Vector3.ZERO, 10)
	parent.add_child(cone)
	cone.global_position = pos + Vector3(0, -1.0, 0)
	var tw := cone.create_tween()
	tw.tween_property(cone, "global_position", pos + Vector3(0, 0.75, 0), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.2)
	tw.tween_property(cone, "global_position", pos + Vector3(0, -1.2, 0), 0.4)
	tw.tween_callback(cone.queue_free)
	_burst(parent, pos + Vector3(0, 1.5, 0), {"amount": 150, "lifetime": 2.0, "explosiveness": 0.35, "direction": Vector3.UP, "spread": 15.0,
		"speed": Vector2(11.0, 19.0), "gravity": Vector3(0, -17, 0), "size": 0.4, "scale": Vector2(0.5, 1.4),
		"colors": [Color(1, 0.95, 0.4, 1), Color(1, 0.45, 0.05, 1), Color(0.5, 0.05, 0.0, 0.0)]}, 3.5)
	_burst(parent, pos + Vector3(0, 2.0, 0), {"amount": 26, "lifetime": 2.6, "explosiveness": 0.5, "direction": Vector3.UP, "spread": 25.0,
		"speed": Vector2(2.0, 5.0), "gravity": Vector3(0, 1.0, 0), "size": 2.6, "additive": false,
		"colors": [Color(0.3, 0.2, 0.2, 0.0), Color(0.2, 0.18, 0.18, 0.7), Color(0.1, 0.1, 0.1, 0.0)]}, 3.5)
	_flash(parent, pos + Vector3.UP * 2.0, Color(1.0, 0.5, 0.1), 10.0, 20.0, 1.6)

static func _fx_fireworks(parent: Node3D, pos: Vector3) -> void:
	var tree := parent.get_tree()
	for i in 5:
		var delay: float = 0.05 + 0.32 * float(i)
		var at: Vector3 = pos + Vector3(randf_range(-5.0, 5.0), randf_range(6.0, 12.0), randf_range(-5.0, 5.0))
		var col: Color = RAINBOW[randi() % RAINBOW.size()]
		tree.create_timer(delay).timeout.connect(func() -> void:
			if not is_instance_valid(parent):
				return
			SoundManager.play("firework", 1.0, randf_range(0.9, 1.2), 0.8)
			BallFX._flash(parent, at, col, 6.0, 18.0, 0.5)
			BallFX._burst(parent, at, {"amount": 80, "lifetime": 1.4, "spread": 180.0, "speed": Vector2(5.0, 9.0), "gravity": Vector3(0, -4, 0),
				"damping": Vector2(2.0, 4.0), "size": 0.24, "colors": [Color(1, 1, 1, 1), col, Color(col, 0.0)]}, 2.5))
	_burst(parent, pos + Vector3(0, 0.3, 0), {"amount": 40, "lifetime": 0.9, "direction": Vector3.UP, "spread": 20.0, "speed": Vector2(6.0, 12.0),
		"gravity": Vector3(0, -10, 0), "size": 0.18, "colors": [Color(1, 1, 0.8, 1), Color(1, 0.7, 0.2, 0.0)]}, 2.0)
