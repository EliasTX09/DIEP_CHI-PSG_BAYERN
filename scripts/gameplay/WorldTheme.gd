class_name WorldTheme
extends RefCounted
## Themenwelt: Materialien/Shader der Bahn, Himmel, Licht, Nebel, Abgrund (Wasser/Lava/Leere) und Deko.
## Vier Welten: emerald (Emerald Valley), volcano (Volcano Canyon), neon (Cyber Neon City), pirate (Pirate Cove).

var id: String = "emerald"
## Materialien in der Reihenfolge der TrackKit-Surfaces (S_FLOOR, S_TRIM, S_GREEN, S_ALT, S_DARK).
var materials: Array = []
var sound: String = "wood"
var hazard: String = "water"
var hazard_depth: float = 6.0
var accent: Color = Color(0.2, 0.9, 1.0)
var boost_color: Color = Color(0.2, 0.9, 1.0)
var pillar_material: Material
var rng := RandomNumberGenerator.new()

static func create(world_id: String) -> WorldTheme:
	var t := WorldTheme.new()
	t.id = world_id
	t.rng.seed = hash(world_id)
	match world_id:
		"volcano":
			t.sound = "stone"
			t.hazard = "lava"
			t.hazard_depth = 7.0
			t.accent = Color(1.0, 0.5, 0.1)
			t.boost_color = Color(1.0, 0.75, 0.15)
			t.materials = [
				Mat.shader("track_floor", {"color_a": Color(0.27, 0.22, 0.21), "color_b": Color(0.33, 0.27, 0.25),
					"line_color": Color(1.0, 0.45, 0.08), "line_strength": 0.8, "emission_strength": 1.6, "surface_roughness": 0.85}),
				Mat.flat(Color(0.19, 0.15, 0.14), 0.9),
				Mat.shader("track_floor", {"color_a": Color(0.36, 0.5, 0.24), "color_b": Color(0.42, 0.57, 0.28), "stripe_length": 1.5, "half_width": 99.0}),
				Mat.shader("track_floor", {"color_a": Color(0.2, 0.2, 0.22), "color_b": Color(0.26, 0.26, 0.29), "stripe_length": 0.6,
					"checker": 1.0, "surface_roughness": 0.4, "surface_metallic": 0.7}),
				Mat.flat(Color(0.07, 0.05, 0.05), 1.0),
			]
			t.pillar_material = Mat.flat(Color(0.16, 0.12, 0.11), 0.95)
		"neon":
			t.sound = "metal"
			t.hazard = "void"
			t.hazard_depth = 14.0
			t.accent = Color(0.2, 0.95, 1.0)
			t.boost_color = Color(1.0, 0.2, 0.85)
			var trim := Mat.glow(Color(0.95, 0.15, 0.8), 0.75, Color(0.06, 0.05, 0.12))
			trim.metallic = 0.6
			trim.roughness = 0.35
			t.materials = [
				Mat.shader("track_floor", {"color_a": Color(0.05, 0.07, 0.16), "color_b": Color(0.08, 0.11, 0.24), "checker": 1.0,
					"stripe_length": 1.25, "line_color": Color(0.2, 0.95, 1.0), "line_strength": 1.0, "emission_strength": 3.0,
					"surface_roughness": 0.3, "surface_metallic": 0.5}),
				trim,
				Mat.shader("track_floor", {"color_a": Color(0.03, 0.3, 0.3), "color_b": Color(0.05, 0.4, 0.38), "checker": 1.0,
					"stripe_length": 1.0, "half_width": 99.0, "emission_strength": 2.0, "surface_roughness": 0.35}),
				Mat.shader("track_floor", {"color_a": Color(0.2, 0.06, 0.3), "color_b": Color(0.28, 0.08, 0.4), "checker": 1.0,
					"stripe_length": 1.0, "line_color": Color(1.0, 0.3, 0.9), "line_strength": 1.0, "emission_strength": 3.0, "surface_roughness": 0.3}),
				Mat.flat(Color(0.02, 0.02, 0.05), 0.6),
			]
			t.pillar_material = Mat.glow(Color(0.2, 0.9, 1.0), 0.5, Color(0.05, 0.06, 0.12))
		"pirate":
			t.sound = "wood"
			t.hazard = "water"
			t.hazard_depth = 7.0
			t.accent = Color(1.0, 0.8, 0.3)
			t.boost_color = Color(1.0, 0.85, 0.2)
			t.materials = [
				Mat.shader("wood_planks", {"color_a": Color(0.62, 0.45, 0.26), "color_b": Color(0.74, 0.56, 0.33)}),
				Mat.flat(Color(0.36, 0.23, 0.12), 0.9),
				Mat.shader("track_floor", {"color_a": Color(0.25, 0.62, 0.3), "color_b": Color(0.3, 0.7, 0.35), "stripe_length": 1.5, "half_width": 99.0}),
				Mat.shader("track_floor", {"color_a": Color(0.6, 0.6, 0.56), "color_b": Color(0.68, 0.67, 0.62), "checker": 1.0, "stripe_length": 1.6}),
				Mat.flat(Color(0.2, 0.13, 0.07), 1.0),
			]
			t.pillar_material = Mat.flat(Color(0.3, 0.2, 0.1), 0.95)
		_:
			t.id = "emerald"
			t.sound = "wood"
			t.hazard = "water"
			t.hazard_depth = 5.0
			t.accent = Color(0.3, 0.9, 0.4)
			t.boost_color = Color(0.2, 0.9, 1.0)
			t.materials = [
				Mat.shader("track_floor", {"color_a": Color(0.2, 0.6, 0.26), "color_b": Color(0.26, 0.69, 0.31)}),
				Mat.flat(Color(0.5, 0.33, 0.18), 0.85),
				Mat.shader("track_floor", {"color_a": Color(0.3, 0.74, 0.34), "color_b": Color(0.36, 0.82, 0.4), "stripe_length": 1.5, "half_width": 99.0}),
				Mat.shader("wood_planks", {}),
				Mat.flat(Color(0.22, 0.15, 0.09), 1.0),
			]
			t.pillar_material = Mat.flat(Color(0.45, 0.3, 0.17), 0.9)
	return t

# ================================================================ Umgebung

## Himmel, Sonne, Nebel, Glow. Liefert den WorldEnvironment-Knoten (bereits an `root` gehaengt).
func build_environment(root: Node3D) -> WorldEnvironment:
	var env := Environment.new()
	var sky_params := {}
	var sun_color := Color(1.0, 0.96, 0.86)
	var sun_energy := 1.25
	var sun_rot := Vector3(-48.0, 35.0, 0.0)
	var ambient := Color(0.55, 0.62, 0.7)
	var ambient_energy := 0.9
	var fog_color := Color(0.7, 0.82, 0.92)
	var fog_density := 0.0035
	var glow_intensity := 0.55
	match id:
		"volcano":
			sky_params = {"top_color": Color(0.1, 0.03, 0.05), "horizon_color": Color(0.75, 0.25, 0.08), "bottom_color": Color(0.3, 0.06, 0.02),
				"sun_color": Color(1.0, 0.6, 0.3), "cloud_color": Color(0.25, 0.1, 0.08), "cloud_amount": 0.6, "star_amount": 0.3}
			sun_color = Color(1.0, 0.62, 0.4)
			sun_energy = 1.0
			sun_rot = Vector3(-35.0, -40.0, 0.0)
			ambient = Color(0.6, 0.35, 0.28)
			ambient_energy = 0.8
			fog_color = Color(0.5, 0.18, 0.08)
			fog_density = 0.006
			glow_intensity = 0.9
		"neon":
			sky_params = {"top_color": Color(0.01, 0.01, 0.06), "horizon_color": Color(0.3, 0.05, 0.4), "bottom_color": Color(0.02, 0.02, 0.08),
				"sun_color": Color(0.7, 0.8, 1.0), "cloud_amount": 0.0, "star_amount": 1.0, "sun_size": 0.06}
			sun_color = Color(0.6, 0.7, 1.0)
			sun_energy = 0.7
			sun_rot = Vector3(-55.0, 20.0, 0.0)
			ambient = Color(0.35, 0.3, 0.55)
			ambient_energy = 1.0
			fog_color = Color(0.12, 0.03, 0.2)
			fog_density = 0.004
			glow_intensity = 1.2
		"pirate":
			sky_params = {"top_color": Color(0.12, 0.35, 0.6), "horizon_color": Color(1.0, 0.68, 0.4), "bottom_color": Color(0.15, 0.3, 0.42),
				"sun_color": Color(1.0, 0.85, 0.6), "cloud_color": Color(1.0, 0.86, 0.75), "cloud_amount": 0.5, "sun_size": 0.07}
			sun_color = Color(1.0, 0.82, 0.62)
			sun_energy = 1.3
			sun_rot = Vector3(-28.0, 60.0, 0.0)
			ambient = Color(0.62, 0.58, 0.6)
			fog_color = Color(0.95, 0.72, 0.52)
			fog_density = 0.003
		_:
			sky_params = {"top_color": Color(0.14, 0.42, 0.88), "horizon_color": Color(0.66, 0.84, 0.97), "bottom_color": Color(0.3, 0.5, 0.6),
				"cloud_amount": 0.45}
	var sky := Sky.new()
	sky.sky_material = Mat.shader("sky", sky_params)
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_sky_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = sun_color
	sun.light_energy = sun_energy
	sun.rotation_degrees = sun_rot
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_bias = 0.06
	root.add_child(sun)
	return we

## Abgrund-Flaeche (Wasser/Lava) bzw. Stadt in der Tiefe + Kill-Hoehe + Stuetzen + Deko rund um die Bahn.
func dress_course(course: Course3D, supports: PackedVector3Array) -> void:
	var b: AABB = course.bounds
	var center: Vector3 = b.get_center()
	var low: float = b.position.y
	var hazard_y: float = low - hazard_depth
	course.hazard = hazard
	course.surface_sound = sound
	course.kill_y = hazard_y + 0.9
	var decor := Node3D.new()
	decor.name = "Decor"
	course.add_child(decor)
	var extent: float = maxf(b.size.x, b.size.z) * 0.5 + 60.0
	match id:
		"volcano":
			var lava := Mat.plane(Vector2(extent * 4.0, extent * 4.0), Mat.shader("lava", {}), Vector3(center.x, hazard_y, center.z))
			lava.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			decor.add_child(lava)
			_volcano_decor(decor, course, center, hazard_y, extent)
		"neon":
			course.kill_y = hazard_y + 2.0
			_neon_decor(decor, course, center, hazard_y, extent)
		"pirate":
			var sea := Mat.plane(Vector2(extent * 5.0, extent * 5.0), Mat.shader("water", {"shallow": Color(0.1, 0.5, 0.65),
				"deep": Color(0.02, 0.15, 0.35), "wave_height": 0.3, "wave_scale": 0.22}), Vector3(center.x, hazard_y, center.z), 48)
			sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			decor.add_child(sea)
			_pirate_decor(decor, course, center, hazard_y, extent)
		_:
			var water := Mat.plane(Vector2(extent * 4.0, extent * 4.0), Mat.shader("water", {}), Vector3(center.x, hazard_y, center.z), 48)
			water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			decor.add_child(water)
			_emerald_decor(decor, course, center, hazard_y, extent)
	_build_supports(decor, supports, hazard_y)

func _build_supports(decor: Node3D, supports: PackedVector3Array, hazard_y: float) -> void:
	if supports.is_empty() or id == "neon":
		# Neon-Plattformen schweben: stattdessen leuchtende Triebwerks-Kegel
		for p in supports:
			var cone := Mat.cylinder(0.9, 0.0, 1.6, pillar_material, p + Vector3(0.0, -TrackKit.SLAB - 0.8, 0.0), 10)
			cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			decor.add_child(cone)
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.6
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	mm.mesh = mesh
	mm.instance_count = supports.size()
	for i in supports.size():
		var top: float = supports[i].y - TrackKit.SLAB
		var h: float = maxf(0.5, top - hazard_y + 1.5)
		var t := Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)), Vector3(supports[i].x, top - h * 0.5, supports[i].z))
		mm.set_instance_transform(i, t)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = pillar_material
	decor.add_child(mmi)

# ---------------------------------------------------------------- Platzierungs-Helfer

## true, wenn (x, z) mindestens `min_dist` von der Bahn-Mittellinie entfernt ist.
func _clear_of_track(course: Course3D, x: float, z: float, min_dist: float) -> bool:
	var md2: float = min_dist * min_dist
	for p in course.path_points:
		var dx: float = p.x - x
		var dz: float = p.z - z
		if dx * dx + dz * dz < md2:
			return false
	return true

## Zufaellige Punkte in einem Ring um die Bahn, die die Bahn nicht beruehren.
func _scatter(course: Course3D, center: Vector3, extent: float, count: int, min_dist: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var tries := 0
	while out.size() < count and tries < count * 12:
		tries += 1
		var x: float = center.x + rng.randf_range(-extent, extent)
		var z: float = center.z + rng.randf_range(-extent, extent)
		if _clear_of_track(course, x, z, min_dist):
			out.append(Vector3(x, 0.0, z))
	return out

func _multimesh(decor: Node3D, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material
	decor.add_child(mmi)

func _island(decor: Node3D, pos: Vector3, radius: float, height: float, material: Material) -> void:
	var hill := Mat.sphere(1.0, material, pos, 20)
	hill.scale = Vector3(radius, height, radius)
	decor.add_child(hill)

func _trees(decor: Node3D, spots: PackedVector3Array, ground_y: Callable, crown_color: Color, cone: bool) -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	for s in spots:
		var y: float = ground_y.call(s)
		var sc: float = rng.randf_range(0.8, 1.6)
		var base := Vector3(s.x, y, s.z)
		trunks.append(Transform3D(Basis.IDENTITY.scaled(Vector3(sc, sc, sc)), base + Vector3(0.0, 1.0 * sc, 0.0)))
		crowns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), base + Vector3(0.0, 3.3 * sc, 0.0)))
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.32
	trunk_mesh.height = 2.0
	trunk_mesh.radial_segments = 6
	trunk_mesh.rings = 1
	_multimesh(decor, trunk_mesh, Mat.flat(Color(0.42, 0.27, 0.14), 0.95), trunks)
	if cone:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 1.5
		cm.height = 3.6
		cm.radial_segments = 8
		cm.rings = 1
		_multimesh(decor, cm, Mat.flat(crown_color, 0.9), crowns)
	else:
		var sm := SphereMesh.new()
		sm.radius = 1.6
		sm.height = 2.8
		sm.radial_segments = 8
		sm.rings = 5
		_multimesh(decor, sm, Mat.flat(crown_color, 0.9), crowns)

func _rocks(decor: Node3D, spots: PackedVector3Array, base_y: float, color: Color, size: Vector2, spire: bool) -> void:
	var xs: Array[Transform3D] = []
	for s in spots:
		var sc: float = rng.randf_range(size.x, size.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU)
		if spire:
			b = b.scaled(Vector3(sc, sc * rng.randf_range(2.0, 4.5), sc))
		else:
			b = b.scaled(Vector3(sc * rng.randf_range(0.8, 1.4), sc * rng.randf_range(0.5, 0.9), sc))
		xs.append(Transform3D(b, Vector3(s.x, base_y, s.z)))
	if spire:
		var cm := CylinderMesh.new()
		cm.top_radius = 0.15
		cm.bottom_radius = 1.0
		cm.height = 2.0
		cm.radial_segments = 6
		cm.rings = 1
		_multimesh(decor, cm, Mat.flat(color, 0.95), xs)
	else:
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 1.6
		sm.radial_segments = 7
		sm.rings = 4
		_multimesh(decor, sm, Mat.flat(color, 0.95), xs)

func _clouds(decor: Node3D, center: Vector3, extent: float, count: int, color: Color, height: float) -> void:
	var xs: Array[Transform3D] = []
	for i in count:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(extent * 0.6, extent * 1.6)
		var sc: float = rng.randf_range(6.0, 14.0)
		xs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(sc * 1.8, sc * 0.45, sc)), center + Vector3(cos(ang) * dist, height + rng.randf_range(-6.0, 10.0), sin(ang) * dist)))
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 6
	var mat := Mat.unlit(color, false, false)
	_multimesh(decor, sm, mat, xs)

# ---------------------------------------------------------------- Emerald Valley

func _emerald_decor(decor: Node3D, course: Course3D, center: Vector3, hazard_y: float, extent: float) -> void:
	var ground := Mat.shader("terrain", {"low_color": Color(0.86, 0.8, 0.55), "mid_color": Color(0.27, 0.62, 0.3),
		"high_color": Color(0.5, 0.47, 0.42), "mid_height": 0.25, "high_height": 0.92})
	# Inseln als (x, z, Radius, Hoehe)
	var islands: Array[Vector4] = []
	for p in _scatter(course, center, extent * 0.8, 7, 16.0):
		var r: float = rng.randf_range(9.0, 20.0)
		var h: float = rng.randf_range(2.5, 6.0)
		_island(decor, Vector3(p.x, hazard_y - h * 0.25, p.z), r, h, ground)
		islands.append(Vector4(p.x, p.z, r, h))
	# Baeume auf den Inseln
	var spots := PackedVector3Array()
	for isl in islands:
		for i in 5:
			var ang: float = rng.randf() * TAU
			var d: float = rng.randf_range(0.0, isl.z * 0.55)
			spots.append(Vector3(isl.x + cos(ang) * d, 0.0, isl.y + sin(ang) * d))
	var isl_list := islands
	var hy := hazard_y
	var ground_fn := func(s: Vector3) -> float:
		var best: float = hy
		for it in isl_list:
			var dx: float = s.x - it.x
			var dz: float = s.z - it.y
			var k: float = 1.0 - (dx * dx + dz * dz) / (it.z * it.z)
			if k > 0.0:
				best = maxf(best, hy - it.w * 0.25 + it.w * sqrt(k) - 0.15)
		return best
	_trees(decor, spots, ground_fn, Color(0.16, 0.5, 0.22), rng.randf() < 0.5)
	_rocks(decor, _scatter(course, center, extent * 0.7, 14, 9.0), hazard_y + 0.2, Color(0.5, 0.5, 0.5), Vector2(0.8, 2.2), false)
	_clouds(decor, center, extent, 9, Color(1.0, 1.0, 1.0), 45.0)
	# Klippe mit Wasserfall
	var cliff_spots := _scatter(course, center, extent * 0.55, 1, 22.0)
	if cliff_spots.size() > 0:
		var cp: Vector3 = cliff_spots[0]
		var cliff_h: float = 16.0
		var cliff := Mat.box(Vector3(14.0, cliff_h, 9.0), Mat.flat(Color(0.45, 0.42, 0.38), 0.95), Vector3(cp.x, hazard_y + cliff_h * 0.5 - 1.0, cp.z))
		decor.add_child(cliff)
		var top := Mat.box(Vector3(14.6, 0.8, 9.6), Mat.flat(Color(0.27, 0.62, 0.3), 0.9), Vector3(cp.x, hazard_y + cliff_h - 0.8, cp.z))
		decor.add_child(top)
		var to_center := Vector3(center.x - cp.x, 0.0, center.z - cp.z).normalized()
		var fall := Mat.quad(Vector2(5.0, cliff_h), Mat.shader("waterfall", {}), Vector3.ZERO)
		fall.position = Vector3(cp.x, hazard_y + cliff_h * 0.5 - 1.0, cp.z) + to_center * 4.6
		fall.rotation.y = atan2(to_center.x, to_center.z)
		fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		decor.add_child(fall)
		var mist := Mat.particles({"amount": 24, "lifetime": 1.6, "direction": Vector3.UP, "spread": 60.0, "speed": Vector2(1.0, 3.0),
			"gravity": Vector3(0, -2.0, 0), "size": 1.4, "additive": false, "emission_box": Vector3(2.4, 0.2, 0.6),
			"colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0.0)]})
		mist.position = Vector3(cp.x, hazard_y + 0.5, cp.z) + to_center * 5.0
		decor.add_child(mist)
	# Schwebende Pollen
	var pollen := Mat.particles({"amount": 40, "lifetime": 6.0, "direction": Vector3(1, 0.3, 0), "spread": 180.0, "speed": Vector2(0.2, 0.8),
		"gravity": Vector3(0.15, 0.05, 0.0), "size": 0.12, "emission_box": Vector3(course.bounds.size.x * 0.5 + 6.0, 4.0, course.bounds.size.z * 0.5 + 6.0),
		"colors": [Color(1, 1, 0.7, 0.0), Color(1, 1, 0.7, 0.8), Color(1, 1, 0.7, 0.0)]})
	pollen.position = center + Vector3(0.0, 3.0, 0.0)
	decor.add_child(pollen)

# ---------------------------------------------------------------- Volcano Canyon

func _volcano_decor(decor: Node3D, course: Course3D, center: Vector3, hazard_y: float, extent: float) -> void:
	_rocks(decor, _scatter(course, center, extent * 0.9, 26, 10.0), hazard_y - 0.5, Color(0.17, 0.13, 0.12), Vector2(2.0, 5.0), true)
	_rocks(decor, _scatter(course, center, extent * 0.8, 16, 8.0), hazard_y + 0.1, Color(0.2, 0.15, 0.14), Vector2(1.0, 3.0), false)
	# Vulkan im Hintergrund mit gluehendem Krater und Lavafall
	var vspots := _scatter(course, center, extent * 0.9, 1, 55.0)
	var vp: Vector3 = vspots[0] if vspots.size() > 0 else Vector3(center.x + extent, 0.0, center.z - extent)
	var vh: float = 46.0
	var cone := Mat.cylinder(7.0, 34.0, vh, Mat.shader("terrain", {"low_color": Color(0.2, 0.1, 0.08), "mid_color": Color(0.16, 0.12, 0.11),
		"high_color": Color(0.5, 0.2, 0.08), "mid_height": -10.0, "high_height": 22.0, "emission_strength": 0.08}), Vector3(vp.x, hazard_y + vh * 0.5 - 1.0, vp.z), 14)
	decor.add_child(cone)
	var crater := Mat.cylinder(6.6, 6.6, 0.4, Mat.shader("lava", {"scale": 0.3, "glow": 4.0}), Vector3(vp.x, hazard_y + vh - 1.1, vp.z), 14)
	decor.add_child(crater)
	var to_center := Vector3(center.x - vp.x, 0.0, center.z - vp.z).normalized()
	var fall := Mat.quad(Vector2(5.0, vh * 1.08), Mat.shader("waterfall", {"color": Color(1.0, 0.35, 0.05), "streak": Color(1.0, 0.85, 0.3),
		"speed": 0.5, "emission_strength": 2.2}), Vector3.ZERO)
	fall.position = Vector3(vp.x, hazard_y + vh * 0.5 - 1.0, vp.z) + to_center * 20.8
	fall.rotation.y = atan2(to_center.x, to_center.z)
	fall.rotation.x = -atan2(27.0, vh)
	fall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(fall)
	var smoke := Mat.particles({"amount": 30, "lifetime": 7.0, "direction": Vector3.UP, "spread": 18.0, "speed": Vector2(3.0, 6.0),
		"gravity": Vector3(0.6, 0.4, 0.0), "size": 7.0, "scale": Vector2(0.6, 1.6), "additive": false, "emission_radius": 4.0,
		"colors": [Color(0.5, 0.2, 0.1, 0.0), Color(0.2, 0.15, 0.15, 0.6), Color(0.1, 0.1, 0.1, 0.0)]})
	smoke.position = Vector3(vp.x, hazard_y + vh, vp.z)
	decor.add_child(smoke)
	# Funkenflug ueber der Lava rund um die Bahn
	var embers := Mat.particles({"amount": 70, "lifetime": 4.5, "direction": Vector3.UP, "spread": 25.0, "speed": Vector2(1.5, 4.0),
		"gravity": Vector3(0.3, 0.6, 0.0), "size": 0.16, "scale": Vector2(0.5, 1.5),
		"emission_box": Vector3(course.bounds.size.x * 0.5 + 10.0, 0.3, course.bounds.size.z * 0.5 + 10.0),
		"colors": [Color(1.0, 0.9, 0.3, 0.0), Color(1.0, 0.5, 0.1, 1.0), Color(1.0, 0.2, 0.0, 0.0)]})
	embers.position = Vector3(center.x, hazard_y + 0.4, center.z)
	decor.add_child(embers)
	var lava_light := OmniLight3D.new()
	lava_light.light_color = Color(1.0, 0.4, 0.1)
	lava_light.light_energy = 2.0
	lava_light.omni_range = extent
	lava_light.position = Vector3(center.x, hazard_y + 3.0, center.z)
	decor.add_child(lava_light)

# ---------------------------------------------------------------- Cyber Neon City

func _neon_decor(decor: Node3D, course: Course3D, center: Vector3, hazard_y: float, extent: float) -> void:
	# Hochhaeuser, die aus der Tiefe ragen
	var towers: Array[Transform3D] = []
	for p in _scatter(course, center, extent * 1.1, 46, 11.0):
		var w: float = rng.randf_range(7.0, 15.0)
		var d: float = rng.randf_range(7.0, 15.0)
		var top: float = hazard_y + rng.randf_range(-6.0, 26.0)
		var bottom: float = hazard_y - 70.0
		var h: float = top - bottom
		towers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w, h, d)), Vector3(p.x, bottom + h * 0.5, p.z)))
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	_multimesh(decor, bm, Mat.shader("building", {}), towers)
	# Leuchtender Boden-Raster tief unten
	var grid := Mat.plane(Vector2(extent * 5.0, extent * 5.0), Mat.shader("track_floor", {"color_a": Color(0.01, 0.01, 0.04), "color_b": Color(0.03, 0.02, 0.09),
		"checker": 1.0, "stripe_length": 9.0, "half_width": 9999.0, "emission_strength": 1.5}), Vector3(center.x, hazard_y - 70.0, center.z))
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(grid)
	# Schwebende Neon-Ringe
	var ring_colors: Array[Color] = [Color(0.2, 0.95, 1.0), Color(1.0, 0.2, 0.85), Color(0.6, 0.3, 1.0), Color(1.0, 0.85, 0.2)]
	var ring_spots := _scatter(course, center, extent * 0.6, 7, 13.0)
	for i in ring_spots.size():
		var holder := Motion.spinner(Vector3(0.3, 1.0, 0.2), rng.randf_range(0.2, 0.6))
		holder.position = Vector3(ring_spots[i].x, course.bounds.position.y + rng.randf_range(2.0, 14.0), ring_spots[i].z)
		var r: float = rng.randf_range(2.5, 6.0)
		var ring := Mat.torus(r * 0.93, r, Mat.glow(ring_colors[i % ring_colors.size()], 3.5))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation.x = rng.randf_range(0.3, 1.4)
		holder.add_child(ring)
		decor.add_child(holder)
	# Daten-"Regen"
	var rain := Mat.particles({"amount": 60, "lifetime": 5.0, "direction": Vector3.DOWN, "spread": 2.0, "speed": Vector2(4.0, 9.0),
		"gravity": Vector3.ZERO, "size": 0.14, "scale": Vector2(0.6, 1.4),
		"emission_box": Vector3(course.bounds.size.x * 0.5 + 18.0, 0.5, course.bounds.size.z * 0.5 + 18.0),
		"colors": [Color(0.2, 1.0, 0.9, 0.0), Color(0.2, 1.0, 0.9, 0.8), Color(0.9, 0.2, 1.0, 0.0)]})
	rain.position = Vector3(center.x, course.bounds.end.y + 14.0, center.z)
	decor.add_child(rain)

# ---------------------------------------------------------------- Pirate Cove

func _pirate_decor(decor: Node3D, course: Course3D, center: Vector3, hazard_y: float, extent: float) -> void:
	var sand := Mat.shader("terrain", {"low_color": Color(0.93, 0.85, 0.6), "mid_color": Color(0.9, 0.8, 0.52),
		"high_color": Color(0.35, 0.6, 0.3), "mid_height": 0.2, "high_height": 0.85})
	var palm_spots := PackedVector3Array()
	for p in _scatter(course, center, extent * 0.8, 6, 15.0):
		var r: float = rng.randf_range(7.0, 14.0)
		_island(decor, Vector3(p.x, hazard_y - 1.0, p.z), r, 3.4, sand)
		for i in 3:
			var ang: float = rng.randf() * TAU
			palm_spots.append(Vector3(p.x + cos(ang) * r * 0.35, hazard_y + 1.7, p.z + sin(ang) * r * 0.35))
	for s in palm_spots:
		decor.add_child(_palm(s))
	_rocks(decor, _scatter(course, center, extent * 0.8, 12, 9.0), hazard_y + 0.3, Color(0.42, 0.4, 0.38), Vector2(1.0, 3.0), false)
	_clouds(decor, center, extent, 8, Color(1.0, 0.88, 0.78), 40.0)
	# Schwebende Ruinen-Inseln
	for p in _scatter(course, center, extent * 0.7, 4, 16.0):
		var holder := Motion.bobber(0.6, rng.randf_range(0.4, 0.8), rng.randf() * TAU)
		holder.position = Vector3(p.x, course.bounds.position.y + rng.randf_range(3.0, 12.0), p.z)
		var r2: float = rng.randf_range(3.0, 6.0)
		holder.add_child(Mat.cylinder(r2, 0.3, r2 * 1.5, Mat.flat(Color(0.45, 0.4, 0.36), 0.95), Vector3(0.0, -r2 * 0.75, 0.0), 9))
		holder.add_child(Mat.cylinder(r2 * 1.03, r2 * 1.03, 0.5, Mat.flat(Color(0.3, 0.62, 0.3), 0.9), Vector3(0.0, 0.2, 0.0), 9))
		var col_mat := Mat.flat(Color(0.82, 0.8, 0.72), 0.85)
		for i in 3:
			var ang2: float = TAU * float(i) / 3.0 + 0.4
			var ch: float = rng.randf_range(1.5, 4.0)
			holder.add_child(Mat.cylinder(0.32, 0.36, ch, col_mat, Vector3(cos(ang2) * r2 * 0.55, 0.45 + ch * 0.5, sin(ang2) * r2 * 0.55), 8))
		decor.add_child(holder)
	# Piratenschiff
	var ship_spots := _scatter(course, center, extent * 0.6, 1, 24.0)
	if ship_spots.size() > 0:
		var ship := _ship()
		ship.position = Vector3(ship_spots[0].x, hazard_y + 0.2, ship_spots[0].z)
		ship.rotation.y = rng.randf() * TAU
		decor.add_child(ship)

func _palm(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = rng.randf() * TAU
	var lean: float = rng.randf_range(0.1, 0.3)
	var h: float = rng.randf_range(4.0, 6.5)
	var trunk := Mat.cylinder(0.16, 0.26, h, Mat.flat(Color(0.5, 0.36, 0.2), 0.95), Vector3(0.0, h * 0.5, 0.0), 6)
	var pivot := Node3D.new()
	pivot.rotation.z = lean
	pivot.add_child(trunk)
	root.add_child(pivot)
	var leaf_mat := Mat.flat(Color(0.2, 0.55, 0.22), 0.9)
	for i in 6:
		var leaf := Mat.sphere(1.0, leaf_mat, Vector3.ZERO, 6)
		leaf.scale = Vector3(1.5, 0.08, 0.38)
		var arm := Node3D.new()
		arm.position = Vector3(0.0, h, 0.0)
		arm.rotation = Vector3(0.0, TAU * float(i) / 6.0, -0.45)
		leaf.position = Vector3(1.3, 0.0, 0.0)
		arm.add_child(leaf)
		pivot.add_child(arm)
	return root

## Piratenschiff aus CSG-Koerpern (Rumpf = Quader minus Hohlraum, Bug = Prisma).
func _ship() -> Node3D:
	var root := Motion.bobber(0.25, 0.9)
	var hull := CSGCombiner3D.new()
	hull.use_collision = false
	var body := CSGBox3D.new()
	body.size = Vector3(5.0, 3.0, 13.0)
	body.material = Mat.flat(Color(0.33, 0.2, 0.1), 0.9)
	hull.add_child(body)
	var hollow := CSGBox3D.new()
	hollow.operation = CSGShape3D.OPERATION_SUBTRACTION
	hollow.size = Vector3(4.2, 2.0, 12.0)
	hollow.position = Vector3(0.0, 1.0, 0.0)
	hull.add_child(hollow)
	var keel := CSGCylinder3D.new()
	keel.operation = CSGShape3D.OPERATION_SUBTRACTION
	keel.radius = 2.6
	keel.height = 6.0
	keel.sides = 12
	keel.position = Vector3(0.0, -1.2, 7.8)
	keel.rotation.z = PI * 0.5
	hull.add_child(keel)
	hull.position = Vector3(0.0, 1.0, 0.0)
	root.add_child(hull)
	var bow := Mat.prism(Vector3(5.0, 4.0, 3.0), Mat.flat(Color(0.33, 0.2, 0.1), 0.9), Vector3(0.0, 1.0, -8.5))
	bow.rotation.x = -PI * 0.5
	root.add_child(bow)
	var mast_mat := Mat.flat(Color(0.4, 0.28, 0.15), 0.9)
	var sail_mat := Mat.shader("flag", {"color": Color(0.95, 0.92, 0.82)})
	for mz: float in [-3.0, 2.5]:
		root.add_child(Mat.cylinder(0.18, 0.24, 12.0, mast_mat, Vector3(0.0, 7.5, mz), 8))
		root.add_child(Mat.vplane(Vector2(5.5, 6.0), sail_mat, Vector3(0.0, 8.5, mz - 0.3)))
	root.add_child(Mat.vplane(Vector2(1.6, 1.0), Mat.shader("flag", {"color": Color(0.08, 0.08, 0.1)}), Vector3(0.8, 13.8, -3.0)))
	return root
