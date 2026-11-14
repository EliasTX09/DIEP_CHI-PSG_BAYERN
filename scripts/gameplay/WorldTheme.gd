class_name WorldTheme
extends RefCounted
## Themenwelt: Materialien/Shader der Bahn, Himmel, Licht, Nebel und die Landschaft rund um die Bahn.
## Jede Bahn liegt in einem Tal (Terrain3D): Randstreifen, Wiesen-Boeschungen, Felsklippen, Bergruecken,
## Waelder; unter Spruengen klaffen Schluchten mit Wasser bzw. Lava.
## Vier Welten: emerald (Smaragd-Tal), volcano (Vulkan-Canyon), neon (Neon-Stadt), pirate (Piraten-Bucht).

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
## Landschaft: Berghoehe, Klippen-Stufe, Schneegrenze (ueber Bahn-Mittel), Shader-Farben, Wald-Art.
var land: Dictionary = {}

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
					"line_color": Color(1.0, 0.45, 0.08), "line_strength": 0.8, "emission_strength": 1.6, "surface_roughness": 0.85, "grass_detail": 0.0}),
				Mat.flat(Color(0.19, 0.15, 0.14), 0.9),
				Mat.shader("track_floor", {"color_a": Color(0.36, 0.5, 0.24), "color_b": Color(0.42, 0.57, 0.28), "stripe_length": 1.5, "half_width": 99.0}),
				Mat.shader("track_floor", {"color_a": Color(0.2, 0.2, 0.22), "color_b": Color(0.26, 0.26, 0.29), "stripe_length": 0.6,
					"checker": 1.0, "surface_roughness": 0.4, "surface_metallic": 0.7, "grass_detail": 0.0}),
				Mat.flat(Color(0.07, 0.05, 0.05), 1.0),
			]
			t.pillar_material = Mat.flat(Color(0.16, 0.12, 0.11), 0.95)
			t.land = {"height": 34.0, "terrace": 6.0, "snow": 9999.0, "far": 62.0, "forest": "dead",
				"shader": {"rough_color": Color(0.2, 0.15, 0.13), "grass_a": Color(0.25, 0.18, 0.15), "grass_b": Color(0.33, 0.23, 0.18),
					"rock_color": Color(0.32, 0.23, 0.2), "rock_dark": Color(0.13, 0.09, 0.08), "wet_color": Color(0.22, 0.1, 0.05),
					"crack_strength": 2.6, "rock_slope": 0.45}}
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
					"surface_roughness": 0.3, "surface_metallic": 0.5, "grass_detail": 0.0}),
				trim,
				Mat.shader("track_floor", {"color_a": Color(0.03, 0.3, 0.3), "color_b": Color(0.05, 0.4, 0.38), "checker": 1.0,
					"stripe_length": 1.0, "half_width": 99.0, "emission_strength": 2.0, "surface_roughness": 0.35, "grass_detail": 0.0}),
				Mat.shader("track_floor", {"color_a": Color(0.2, 0.06, 0.3), "color_b": Color(0.28, 0.08, 0.4), "checker": 1.0,
					"stripe_length": 1.0, "line_color": Color(1.0, 0.3, 0.9), "line_strength": 1.0, "emission_strength": 3.0, "surface_roughness": 0.3, "grass_detail": 0.0}),
				Mat.flat(Color(0.02, 0.02, 0.05), 0.6),
			]
			t.pillar_material = Mat.glow(Color(0.2, 0.9, 1.0), 0.5, Color(0.05, 0.06, 0.12))
			t.land = {"height": 9.0, "terrace": 3.0, "snow": 9999.0, "far": 0.0, "forest": "towers",
				"shader": {"rough_color": Color(0.05, 0.06, 0.12), "grass_a": Color(0.06, 0.07, 0.15), "grass_b": Color(0.09, 0.08, 0.2),
					"rock_color": Color(0.12, 0.12, 0.2), "rock_dark": Color(0.04, 0.04, 0.09), "wet_color": Color(0.05, 0.03, 0.1),
					"grid_strength": 1.8, "grid_color": Color(0.2, 0.85, 1.0), "rock_slope": 0.4}}
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
				Mat.shader("track_floor", {"color_a": Color(0.6, 0.6, 0.56), "color_b": Color(0.68, 0.67, 0.62), "checker": 1.0, "stripe_length": 1.6, "grass_detail": 0.0}),
				Mat.flat(Color(0.2, 0.13, 0.07), 1.0),
			]
			t.pillar_material = Mat.flat(Color(0.3, 0.2, 0.1), 0.95)
			t.land = {"height": 24.0, "terrace": 5.0, "snow": 9999.0, "far": 40.0, "forest": "jungle", "sea": true,
				"shader": {"rough_color": Color(0.18, 0.43, 0.17), "grass_a": Color(0.17, 0.48, 0.19), "grass_b": Color(0.33, 0.6, 0.22),
					"rock_color": Color(0.66, 0.58, 0.46), "rock_dark": Color(0.44, 0.37, 0.3), "wet_color": Color(0.9, 0.81, 0.58),
					"rock_slope": 0.5}}
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
			t.land = {"height": 30.0, "terrace": 7.0, "snow": 34.0, "far": 75.0, "forest": "pine",
				"shader": {"rough_color": Color(0.15, 0.38, 0.14), "grass_a": Color(0.22, 0.5, 0.19), "grass_b": Color(0.44, 0.62, 0.24),
					"rock_color": Color(0.55, 0.53, 0.5), "rock_dark": Color(0.32, 0.31, 0.3), "wet_color": Color(0.3, 0.29, 0.25),
					"rock_slope": 0.52}}
	return t

# ================================================================ Umgebung

## Himmel, Sonne mit weichen Schatten, Tiefen- und Talnebel, Bloom. Liefert den WorldEnvironment-Knoten (an `root` gehaengt).
func build_environment(root: Node3D) -> WorldEnvironment:
	var env := Environment.new()
	var sky_params := {}
	var sun_color := Color(1.0, 0.96, 0.86)
	var sun_energy := 1.5
	var sun_rot := Vector3(-50.0, 35.0, 0.0)
	var ambient := Color(0.55, 0.62, 0.7)
	var ambient_energy := 0.7
	var fog_color := Color(0.66, 0.78, 0.9)
	var fog_density := 0.0042
	var glow_intensity := 0.6
	var valley_mist := 0.05
	match id:
		"volcano":
			sky_params = {"top_color": Color(0.1, 0.03, 0.05), "horizon_color": Color(0.75, 0.25, 0.08), "bottom_color": Color(0.3, 0.06, 0.02),
				"sun_color": Color(1.0, 0.6, 0.3), "cloud_color": Color(0.25, 0.1, 0.08), "cloud_amount": 0.6, "star_amount": 0.3}
			sun_color = Color(1.0, 0.62, 0.4)
			sun_energy = 1.1
			sun_rot = Vector3(-40.0, -40.0, 0.0)
			ambient = Color(0.6, 0.35, 0.28)
			ambient_energy = 0.8
			fog_color = Color(0.45, 0.17, 0.08)
			fog_density = 0.0065
			glow_intensity = 0.95
			valley_mist = 0.08
		"neon":
			sky_params = {"top_color": Color(0.01, 0.01, 0.06), "horizon_color": Color(0.3, 0.05, 0.4), "bottom_color": Color(0.02, 0.02, 0.08),
				"sun_color": Color(0.7, 0.8, 1.0), "cloud_amount": 0.0, "star_amount": 1.0, "sun_size": 0.06}
			sun_color = Color(0.6, 0.7, 1.0)
			sun_energy = 0.75
			sun_rot = Vector3(-55.0, 20.0, 0.0)
			ambient = Color(0.35, 0.3, 0.55)
			ambient_energy = 1.0
			fog_color = Color(0.14, 0.04, 0.24)
			fog_density = 0.0055
			glow_intensity = 1.2
			valley_mist = 0.06
		"pirate":
			sky_params = {"top_color": Color(0.12, 0.35, 0.6), "horizon_color": Color(1.0, 0.68, 0.4), "bottom_color": Color(0.15, 0.3, 0.42),
				"sun_color": Color(1.0, 0.85, 0.6), "cloud_color": Color(1.0, 0.86, 0.75), "cloud_amount": 0.5, "sun_size": 0.07}
			sun_color = Color(1.0, 0.82, 0.62)
			sun_energy = 1.35
			sun_rot = Vector3(-34.0, 60.0, 0.0)
			ambient = Color(0.62, 0.58, 0.6)
			fog_color = Color(0.86, 0.76, 0.68)
			fog_density = 0.0036
		_:
			sky_params = {"top_color": Color(0.14, 0.42, 0.88), "horizon_color": Color(0.7, 0.85, 0.97), "bottom_color": Color(0.3, 0.5, 0.6),
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
	env.tonemap_white = 6.0
	# Tiefen-Nebel: ferne Berge verschwimmen im Dunst; Talnebel sammelt sich in den Schluchten
	env.fog_enabled = true
	env.fog_light_color = fog_color
	env.fog_density = fog_density
	env.fog_aerial_perspective = 0.35
	env.fog_sky_affect = 0.5
	var course := root as Course3D
	if course != null and course.terrain != null:
		env.fog_height = course.terrain.base_y - 3.0
		env.fog_height_density = valley_mist
	# Bloom auf Wasser-Glanz, Lava, Neon und glaenzenden Baellen
	env.glow_enabled = true
	env.glow_intensity = glow_intensity
	env.glow_strength = 1.05
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 0.85
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.12
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
	sun.shadow_blur = 1.6
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 75.0
	sun.directional_shadow_fade_start = 0.85
	sun.shadow_bias = 0.06
	root.add_child(sun)
	return we

# ================================================================ Landschaft

## Gelaende-Tal + Aus-Grenze (immer) und die sichtbare Landschaft (nur mit `full`).
## Kill-Hoehe und Abgrund-Art (Wasser/Lava/Leere) gelten fuer Schluchten.
func dress_course(course: Course3D, supports: PackedVector3Array, full: bool = true) -> void:
	var b: AABB = course.bounds
	var low: float = b.position.y
	var hazard_y: float = low - hazard_depth
	course.hazard = hazard
	course.surface_sound = sound
	course.kill_y = hazard_y + (2.0 if id == "neon" else 0.9)
	var deep: float = hazard_y - (24.0 if id == "neon" else 2.0)
	var sea := Vector2.ZERO
	if bool(land.get("sea", false)):
		var a: float = float(absi(hash(course.course_id)) % 360) * PI / 180.0
		sea = Vector2(cos(a), sin(a))
	var terr := Terrain3D.build(course, {"deep": deep, "height": float(land.get("height", 26.0)),
		"terrace": float(land.get("terrace", 0.0)), "sea_dir": sea, "seed": absi(hash(course.course_id)) % 100000})
	course.terrain = terr
	course.add_gadget(Gadgets.TerrainBounds.new(terr, course.hole_pos, course.hole_radius))
	if not full:
		return
	rng.seed = absi(hash(course.course_id + "|decor"))
	var decor := Node3D.new()
	decor.name = "Decor"
	course.add_child(decor)
	var params: Dictionary = (land.get("shader", {}) as Dictionary).duplicate()
	params["snow_height"] = terr.base_y + float(land.get("snow", 9999.0))
	decor.add_child(terr.make_mesh(Mat.shader("landscape", params)))
	_far_ring(decor, terr, sea, params)
	_hazard_plane(decor, terr, hazard_y)
	match str(land.get("forest", "pine")):
		"dead":
			_forest(decor, terr, [Flora.dead_tree()], [1.0], 0.12, Vector2(0.8, 1.5))
			_rock_field(decor, terr, 160, Color(0.2, 0.15, 0.14), true)
			_volcano_extras(decor, course, terr, hazard_y)
		"towers":
			_neon_extras(decor, course, terr, hazard_y)
		"jungle":
			_forest(decor, terr, [Flora.palm(), Flora.broadleaf()], [0.45, 0.55], 0.32, Vector2(0.9, 1.5))
			_rock_field(decor, terr, 70, Color(0.62, 0.55, 0.45), false)
			_pirate_extras(decor, course, terr, hazard_y, sea)
		_:
			_forest(decor, terr, [Flora.pine(), Flora.broadleaf()], [0.78, 0.22], 0.42, Vector2(0.85, 1.7))
			_rock_field(decor, terr, 90, Color(0.52, 0.5, 0.48), false)
			_emerald_extras(decor, course, terr)
	_build_supports(decor, supports, terr, hazard_y)

## Wasser / Lava / Neon-Tiefe: sichtbar in Schluchten und an der Kueste.
func _hazard_plane(decor: Node3D, terr: Terrain3D, hazard_y: float) -> void:
	var c: Vector3 = terr.center()
	var size: float = terr.half_extent() * 5.0
	var mi: MeshInstance3D
	match id:
		"volcano":
			mi = Mat.plane(Vector2(size, size), Mat.shader("lava", {}), Vector3(c.x, hazard_y, c.z))
		"neon":
			mi = Mat.plane(Vector2(size, size), Mat.shader("track_floor", {"color_a": Color(0.01, 0.01, 0.04), "color_b": Color(0.03, 0.02, 0.09),
				"checker": 1.0, "stripe_length": 9.0, "half_width": 9999.0, "emission_strength": 1.5, "grass_detail": 0.0}), Vector3(c.x, hazard_y - 20.0, c.z))
		"pirate":
			mi = Mat.plane(Vector2(size, size), Mat.shader("water", {"shallow": Color(0.1, 0.55, 0.65), "deep": Color(0.02, 0.17, 0.36),
				"wave_height": 0.3, "wave_scale": 0.22}), Vector3(c.x, hazard_y, c.z), 64)
		_:
			mi = Mat.plane(Vector2(size, size), Mat.shader("water", {}), Vector3(c.x, hazard_y, c.z), 48)
	mi.name = "Hazard"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mi)

## Bergkranz hinter dem Tal (nur Optik, verschwimmt im Nebel). Zur Meerseite hin flach.
func _far_ring(decor: Node3D, terr: Terrain3D, sea: Vector2, params: Dictionary) -> void:
	var far_h: float = float(land.get("far", 60.0))
	if far_h <= 0.0:
		return
	var c: Vector3 = terr.center()
	var r0: float = minf(float(terr.nx), float(terr.nz)) * Terrain3D.CELL * 0.5 * 0.97
	var radii: Array[float] = [r0, r0 * 1.18, r0 * 1.45, r0 * 1.85, r0 * 2.5, r0 * 3.4]
	var shape: Array[float] = [0.0, 0.5, 0.85, 1.0, 0.85, 0.5]
	var seg: int = 90
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 1.6
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	var grid: Array = []
	for k in radii.size():
		var row := PackedVector3Array()
		for i in seg:
			var a: float = TAU * float(i) / float(seg)
			var dir := Vector2(cos(a), sin(a))
			var p := Vector2(c.x, c.z) + dir * radii[k]
			var y: float
			if k == 0:
				y = terr.height_at(p.x, p.y) - 3.0
			else:
				var nv: float = noise.get_noise_2d(cos(a) * 1.3 + float(k) * 0.37, sin(a) * 1.3) * 0.5 + 0.5
				var edge: float = terr.height_at(Vector2(c.x, c.z).x + dir.x * r0, c.z + dir.y * r0)
				var lift: float = far_h * shape[k] * (0.35 + 0.95 * nv)
				if sea != Vector2.ZERO:
					lift *= 1.0 - smoothstep(-0.2, 0.45, dir.dot(sea))
				y = maxf(edge, terr.base_y) + lift
				if sea != Vector2.ZERO and dir.dot(sea) > 0.3:
					y = minf(y, terr.deep_y - 1.0 + lift)
			row.append(Vector3(p.x, y, p.y))
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_color(Color(1.0, 0.0, 0.0))
	for k in radii.size() - 1:
		var r_in: PackedVector3Array = grid[k]
		var r_out: PackedVector3Array = grid[k + 1]
		for i in seg:
			var j: int = (i + 1) % seg
			_up_tri(st, r_in[i], r_in[j], r_out[j])
			_up_tri(st, r_in[i], r_out[j], r_out[i])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "FarMountains"
	mi.mesh = st.commit()
	mi.material_override = Mat.shader("landscape", params)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mi)

## Dreieck mit Vorderseite nach oben (Godot: Uhrzeigersinn von vorn gesehen).
static func _up_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (c - a).cross(b - a).y < 0.0:
		var t: Vector3 = b
		b = c
		c = t
	st.set_color(Color(1.0, 0.0, 0.0))
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

## Wald auf den Hangen: dicht nahe am Tal, lichter weiter oben; keine Baeume an Klippen, Ufern und im Schnee.
func _forest(decor: Node3D, terr: Terrain3D, meshes: Array, weights: Array, density: float, size_range: Vector2) -> void:
	var near_lists: Array = []
	var far_lists: Array = []
	for m in meshes:
		near_lists.append([])
		far_lists.append([])
	var snow_y: float = terr.base_y + float(land.get("snow", 9999.0)) - 4.0
	var count := 0
	for iz in terr.nz:
		for ix in terr.nx:
			var c: int = iz * terr.nx + ix
			var d: float = terr.track_dist[c]
			if d < Terrain3D.SHOULDER + 2.5 or d > 80.0 or terr.wet[c] > 0.25:
				continue
			var nrm: Vector3 = terr.normal_at_index(ix, iz)
			if nrm.y < 0.8:
				continue
			var p: float = density * (1.0 - 0.65 * smoothstep(30.0, 80.0, d))
			if rng.randf() > p:
				continue
			var pos: Vector3 = terr.world_pos(ix, iz) + Vector3(rng.randf_range(-1.1, 1.1), 0.0, rng.randf_range(-1.1, 1.1))
			pos.y = terr.height_at(pos.x, pos.z) - 0.2
			if pos.y > snow_y:
				continue
			var pick: float = rng.randf()
			var which := 0
			var acc := 0.0
			for w in weights.size():
				acc += float(weights[w])
				if pick <= acc:
					which = w
					break
			var sc: float = rng.randf_range(size_range.x, size_range.y) * (1.0 + 0.25 * smoothstep(20.0, 60.0, d))
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.9, 1.15), sc)), pos)
			if d < 22.0:
				(near_lists[which] as Array).append(xf)
			else:
				(far_lists[which] as Array).append(xf)
			count += 1
			if count >= 1500:
				break
		if count >= 1500:
			break
	for i in meshes.size():
		_flora_multimesh(decor, meshes[i], near_lists[i], true)
		_flora_multimesh(decor, meshes[i], far_lists[i], false)

func _flora_multimesh(decor: Node3D, mesh: Mesh, xfs: Array, shadows: bool) -> void:
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		var tint: float = rng.randf_range(0.82, 1.12)
		mm.set_instance_color(i, Color(tint, tint * rng.randf_range(0.95, 1.05), tint * 0.95))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Flora.material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mmi)

## Felsbrocken (bzw. Felsnadeln) auf den Hangen.
func _rock_field(decor: Node3D, terr: Terrain3D, count: int, color: Color, spires: bool) -> void:
	var xfs: Array[Transform3D] = []
	var tries := 0
	while xfs.size() < count and tries < count * 8:
		tries += 1
		var ix: int = rng.randi_range(0, terr.nx - 1)
		var iz: int = rng.randi_range(0, terr.nz - 1)
		var d: float = terr.track_dist[iz * terr.nx + ix]
		if d < Terrain3D.SHOULDER + 1.5 or d > 70.0:
			continue
		var pos: Vector3 = terr.world_pos(ix, iz)
		var sc: float = rng.randf_range(0.6, 2.4) * (1.0 + smoothstep(15.0, 60.0, d))
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.3, 0.3))
		if spires:
			b = b.scaled(Vector3(sc, sc * rng.randf_range(2.0, 4.0), sc))
		else:
			b = b.scaled(Vector3(sc * rng.randf_range(0.9, 1.4), sc * rng.randf_range(0.55, 0.9), sc))
		xfs.append(Transform3D(b, pos + Vector3(0.0, -0.25 * sc, 0.0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Flora.boulder()
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
		mm.set_instance_color(i, color.lightened(rng.randf_range(-0.1, 0.25)) * Color(2.0, 2.0, 2.0))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Flora.material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mmi)

## Stuetzpfeiler nur dort, wo die Bahn hoch ueber dem Gelaende liegt (Bruecken ueber Schluchten).
func _build_supports(decor: Node3D, supports: PackedVector3Array, terr: Terrain3D, hazard_y: float) -> void:
	var xfs: Array[Transform3D] = []
	for s in supports:
		var top: float = s.y - TrackKit.SLAB
		var ground: float = maxf(terr.height_at(s.x, s.z), hazard_y - 1.0)
		var h: float = top - ground + 0.5
		if h < 1.6:
			continue
		xfs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, h, 1.0)), Vector3(s.x, top - h * 0.5, s.z)))
	if xfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.45
	mesh.bottom_radius = 0.7
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = pillar_material
	decor.add_child(mmi)

func _clouds(decor: Node3D, center: Vector3, extent: float, count: int, color: Color, height: float) -> void:
	var xs: Array[Transform3D] = []
	for i in count:
		var ang: float = rng.randf() * TAU
		var dist: float = rng.randf_range(extent * 0.5, extent * 1.4)
		var sc: float = rng.randf_range(8.0, 18.0)
		xs.append(Transform3D(Basis.IDENTITY.scaled(Vector3(sc * 1.9, sc * 0.4, sc)), center + Vector3(cos(ang) * dist, height + rng.randf_range(-6.0, 12.0), sin(ang) * dist)))
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 6
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mat.unlit(color, false, false)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mmi)

## Sucht einen Hangpunkt (Abstand zur Bahn in [d_min, d_max], moeglichst hoch ueber dem Tal) fuer Kulissen-Elemente.
func _slope_spot(terr: Terrain3D, d_min: float, d_max: float, min_rise: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_score := -INF
	for k in 600:
		var ix: int = rng.randi_range(1, terr.nx - 2)
		var iz: int = rng.randi_range(1, terr.nz - 2)
		var c: int = iz * terr.nx + ix
		var d: float = terr.track_dist[c]
		if d < d_min or d > d_max or terr.wet[c] > 0.2:
			continue
		var rise: float = terr.heights[c] - terr.base_y
		if rise < min_rise:
			continue
		var score: float = rise - absf(d - (d_min + d_max) * 0.5) * 0.3
		if score > best_score:
			best_score = score
			best = Vector2i(ix, iz)
	return best

## Folgt dem Gelaende bergab Richtung Bahn (absteigender Bahn-Abstand), bis zum Randstreifen.
func _downhill_path(terr: Terrain3D, start: Vector2i, stop_dist: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var p := Vector2(terr.origin.x + float(start.x) * Terrain3D.CELL, terr.origin.y + float(start.y) * Terrain3D.CELL)
	for i in 60:
		out.append(Vector3(p.x, terr.height_at(p.x, p.y), p.y))
		var d: float = terr.distance_at(p.x, p.y)
		if d <= stop_dist:
			break
		var e: float = Terrain3D.CELL
		var gx: float = terr.distance_at(p.x + e, p.y) - terr.distance_at(p.x - e, p.y)
		var gz: float = terr.distance_at(p.x, p.y + e) - terr.distance_at(p.x, p.y - e)
		var g := Vector2(gx, gz)
		if g.length() < 0.001:
			break
		p -= g.normalized() * 1.6
	return out

## Wasserlauf (Kaskade) als Band, das dem Hang folgt.
func _cascade(decor: Node3D, terr: Terrain3D, path: PackedVector3Array, width: float, material: Material) -> void:
	if path.size() < 3:
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var dir := Vector3(b.x - a.x, 0.0, b.z - a.z).normalized()
		var side: Vector3 = dir.cross(Vector3.UP) * (width * 0.5)
		var a0: Vector3 = a - side + Vector3.UP * 0.3
		var a1: Vector3 = a + side + Vector3.UP * 0.3
		var b0: Vector3 = b - side + Vector3.UP * 0.3
		var b1: Vector3 = b + side + Vector3.UP * 0.3
		var seg_len: float = a.distance_to(b)
		var v0: float = acc / 6.0
		var v1: float = (acc + seg_len) / 6.0
		acc += seg_len
		for v in [[a0, Vector2(0.0, v0)], [b0, Vector2(0.0, v1)], [b1, Vector2(1.0, v1)], [a0, Vector2(0.0, v0)], [b1, Vector2(1.0, v1)], [a1, Vector2(1.0, v0)]]:
			st.set_uv(v[1])
			st.set_normal(Vector3.UP)
			st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mi)

# ---------------------------------------------------------------- Smaragd-Tal

func _emerald_extras(decor: Node3D, course: Course3D, terr: Terrain3D) -> void:
	# Wasserfall-Kaskade vom Hang bis ins Tal, unten Gischt
	var spot := _slope_spot(terr, 20.0, 34.0, 10.0)
	if spot.x >= 0:
		var path := _downhill_path(terr, spot, Terrain3D.SHOULDER + 2.0)
		_cascade(decor, terr, path, 3.2, Mat.shader("waterfall", {"speed": 1.2}))
		if path.size() > 2:
			var foot: Vector3 = path[path.size() - 1]
			var pool := Mat.cylinder(2.6, 2.6, 0.05, Mat.shader("water", {"wave_height": 0.03}), foot + Vector3(0.0, 0.28, 0.0), 20)
			pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			decor.add_child(pool)
			var mist := Mat.particles({"amount": 24, "lifetime": 1.6, "direction": Vector3.UP, "spread": 60.0, "speed": Vector2(0.8, 2.4),
				"gravity": Vector3(0, -1.5, 0), "size": 1.2, "additive": false, "emission_box": Vector3(1.6, 0.2, 1.6),
				"colors": [Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.0)]})
			mist.position = foot + Vector3(0.0, 0.5, 0.0)
			decor.add_child(mist)
	_clouds(decor, terr.center(), terr.half_extent(), 9, Color(1.0, 1.0, 1.0), terr.base_y + 70.0)
	var pollen := Mat.particles({"amount": 40, "lifetime": 6.0, "direction": Vector3(1, 0.3, 0), "spread": 180.0, "speed": Vector2(0.2, 0.8),
		"gravity": Vector3(0.15, 0.05, 0.0), "size": 0.12, "emission_box": Vector3(course.bounds.size.x * 0.5 + 6.0, 4.0, course.bounds.size.z * 0.5 + 6.0),
		"colors": [Color(1, 1, 0.7, 0.0), Color(1, 1, 0.7, 0.8), Color(1, 1, 0.7, 0.0)]})
	pollen.position = course.bounds.get_center() + Vector3(0.0, 3.0, 0.0)
	decor.add_child(pollen)

# ---------------------------------------------------------------- Vulkan-Canyon

func _volcano_extras(decor: Node3D, course: Course3D, terr: Terrain3D, hazard_y: float) -> void:
	# Lavastrom den Hang hinab
	var spot := _slope_spot(terr, 18.0, 32.0, 8.0)
	if spot.x >= 0:
		_cascade(decor, terr, _downhill_path(terr, spot, Terrain3D.SHOULDER + 3.0), 2.6,
			Mat.shader("waterfall", {"color": Color(1.0, 0.35, 0.05), "streak": Color(1.0, 0.85, 0.3), "speed": 0.45, "emission_strength": 2.4}))
	# Vulkan hinter dem Bergkranz mit gluehendem Krater und Rauch
	var c: Vector3 = terr.center()
	var ang: float = rng.randf() * TAU
	var r: float = terr.half_extent() * 1.55
	var vp := Vector3(c.x + cos(ang) * r, terr.base_y, c.z + sin(ang) * r)
	var vh: float = 120.0
	var cone := Mat.cylinder(14.0, 70.0, vh, Mat.shader("terrain", {"low_color": Color(0.2, 0.1, 0.08), "mid_color": Color(0.16, 0.12, 0.11),
		"high_color": Color(0.5, 0.2, 0.08), "mid_height": -20.0, "high_height": 55.0, "emission_strength": 0.08}), vp + Vector3(0.0, vh * 0.5 - 4.0, 0.0), 18)
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(cone)
	var crater := Mat.cylinder(13.2, 13.2, 0.6, Mat.shader("lava", {"scale": 0.3, "glow": 4.0}), vp + Vector3(0.0, vh - 4.2, 0.0), 18)
	decor.add_child(crater)
	var smoke := Mat.particles({"amount": 30, "lifetime": 8.0, "direction": Vector3.UP, "spread": 18.0, "speed": Vector2(5.0, 9.0),
		"gravity": Vector3(0.8, 0.5, 0.0), "size": 14.0, "scale": Vector2(0.6, 1.6), "additive": false, "emission_radius": 8.0,
		"colors": [Color(0.5, 0.2, 0.1, 0.0), Color(0.2, 0.15, 0.15, 0.6), Color(0.1, 0.1, 0.1, 0.0)]})
	smoke.position = vp + Vector3(0.0, vh - 3.0, 0.0)
	smoke.visibility_aabb = AABB(Vector3(-80, -10, -80), Vector3(160, 160, 160))
	decor.add_child(smoke)
	var embers := Mat.particles({"amount": 70, "lifetime": 4.5, "direction": Vector3.UP, "spread": 25.0, "speed": Vector2(1.5, 4.0),
		"gravity": Vector3(0.3, 0.6, 0.0), "size": 0.16, "scale": Vector2(0.5, 1.5),
		"emission_box": Vector3(course.bounds.size.x * 0.5 + 10.0, 0.3, course.bounds.size.z * 0.5 + 10.0),
		"colors": [Color(1.0, 0.9, 0.3, 0.0), Color(1.0, 0.5, 0.1, 1.0), Color(1.0, 0.2, 0.0, 0.0)]})
	embers.position = Vector3(course.bounds.get_center().x, hazard_y + 0.4, course.bounds.get_center().z)
	decor.add_child(embers)
	var lava_light := OmniLight3D.new()
	lava_light.light_color = Color(1.0, 0.4, 0.1)
	lava_light.light_energy = 1.6
	lava_light.omni_range = terr.half_extent()
	lava_light.position = Vector3(c.x, hazard_y + 3.0, c.z)
	decor.add_child(lava_light)

# ---------------------------------------------------------------- Neon-Stadt

func _neon_extras(decor: Node3D, course: Course3D, terr: Terrain3D, hazard_y: float) -> void:
	# Hochhaus-Schluchten: Tuerme stehen dicht an dicht auf den Hangen und bilden die Talwaende
	var towers: Array[Transform3D] = []
	var tries := 0
	while towers.size() < 150 and tries < 2000:
		tries += 1
		var ix: int = rng.randi_range(0, terr.nx - 1)
		var iz: int = rng.randi_range(0, terr.nz - 1)
		var c: int = iz * terr.nx + ix
		var d: float = terr.track_dist[c]
		if d < Terrain3D.SHOULDER + 8.0 or d > 90.0 or terr.wet[c] > 0.3:
			continue
		var pos: Vector3 = terr.world_pos(ix, iz)
		var w: float = rng.randf_range(6.0, 13.0)
		var dd: float = rng.randf_range(6.0, 13.0)
		var h: float = rng.randf_range(14.0, 34.0) + smoothstep(14.0, 70.0, d) * rng.randf_range(20.0, 70.0)
		var bottom: float = pos.y - 6.0
		towers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w, h, dd)), Vector3(pos.x, bottom + h * 0.5, pos.z)))
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bm
	mm.instance_count = towers.size()
	for i in towers.size():
		mm.set_instance_transform(i, towers[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Mat.shader("building", {})
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	decor.add_child(mmi)
	# Schwebende Neon-Ringe ueber den Daechern
	var ring_colors: Array[Color] = [Color(0.2, 0.95, 1.0), Color(1.0, 0.2, 0.85), Color(0.6, 0.3, 1.0), Color(1.0, 0.85, 0.2)]
	for i in 6:
		var spot := _slope_spot(terr, 16.0, 40.0, -999.0)
		if spot.x < 0:
			continue
		var holder := Motion.spinner(Vector3(0.3, 1.0, 0.2), rng.randf_range(0.2, 0.6))
		holder.position = terr.world_pos(spot.x, spot.y) + Vector3(0.0, rng.randf_range(10.0, 22.0), 0.0)
		var r: float = rng.randf_range(2.5, 6.0)
		var ring := Mat.torus(r * 0.93, r, Mat.glow(ring_colors[i % ring_colors.size()], 3.5))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation.x = rng.randf_range(0.3, 1.4)
		holder.add_child(ring)
		decor.add_child(holder)
	var rain := Mat.particles({"amount": 60, "lifetime": 5.0, "direction": Vector3.DOWN, "spread": 2.0, "speed": Vector2(4.0, 9.0),
		"gravity": Vector3.ZERO, "size": 0.14, "scale": Vector2(0.6, 1.4),
		"emission_box": Vector3(course.bounds.size.x * 0.5 + 18.0, 0.5, course.bounds.size.z * 0.5 + 18.0),
		"colors": [Color(0.2, 1.0, 0.9, 0.0), Color(0.2, 1.0, 0.9, 0.8), Color(0.9, 0.2, 1.0, 0.0)]})
	rain.position = Vector3(course.bounds.get_center().x, course.bounds.end.y + 14.0, course.bounds.get_center().z)
	decor.add_child(rain)

# ---------------------------------------------------------------- Piraten-Bucht

func _pirate_extras(decor: Node3D, course: Course3D, terr: Terrain3D, hazard_y: float, sea: Vector2) -> void:
	_clouds(decor, terr.center(), terr.half_extent(), 8, Color(1.0, 0.88, 0.78), terr.base_y + 55.0)
	# Piratenschiff vor Anker in der Bucht
	if sea != Vector2.ZERO:
		var c: Vector3 = terr.center()
		var dist: float = terr.half_extent() * 0.85
		var ship := _ship()
		ship.position = Vector3(c.x + sea.x * dist, hazard_y + 0.2, c.z + sea.y * dist)
		ship.rotation.y = rng.randf() * TAU
		decor.add_child(ship)
	# Ruinen-Saeulen auf einem Hang (stehen fest im Boden)
	var spot := _slope_spot(terr, 12.0, 26.0, 2.0)
	if spot.x >= 0:
		var base: Vector3 = terr.world_pos(spot.x, spot.y)
		var col_mat := Mat.flat(Color(0.82, 0.8, 0.72), 0.85)
		for i in 4:
			var ang: float = TAU * float(i) / 4.0 + 0.4
			var p := base + Vector3(cos(ang) * 3.0, 0.0, sin(ang) * 3.0)
			p.y = terr.height_at(p.x, p.z) - 0.3
			var ch: float = rng.randf_range(2.0, 5.0)
			decor.add_child(Mat.cylinder(0.38, 0.44, ch, col_mat, p + Vector3(0.0, ch * 0.5, 0.0), 10))

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
