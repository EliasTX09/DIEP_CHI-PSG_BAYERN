class_name Mat
extends RefCounted
## Kleine Fabrik fuer Materialien und Primitive-Meshes (alles per Code, keine Asset-Dateien).

static var _shader_cache: Dictionary = {}
static var _flat_cache: Dictionary = {}
static var _soft_dot: GradientTexture2D = null

## Weicher, runder Punkt (Mitte voll, Rand durchsichtig) fuer Partikel - statt harter Quadrate.
static func soft_dot() -> GradientTexture2D:
	if _soft_dot == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
		_soft_dot = GradientTexture2D.new()
		_soft_dot.gradient = g
		_soft_dot.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot.fill_from = Vector2(0.5, 0.5)
		_soft_dot.fill_to = Vector2(1.0, 0.5)
		_soft_dot.width = 64
		_soft_dot.height = 64
	return _soft_dot

static func flat(color: Color, roughness: float = 0.8, metallic: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), roughness, metallic]
	if _flat_cache.has(key):
		return _flat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flat_cache[key] = m
	return m

## Selbstleuchtendes Material (Neon, Lampen, Laser).
static func glow(color: Color, energy: float = 2.5, base: Color = Color(0.02, 0.02, 0.03)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

## Unbeleuchtet, optional additiv/transparent (Strahlen, Marker, Partikel-Quads).
static func unlit(color: Color, additive: bool = false, double_sided: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	elif color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if double_sided:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Billboard-Material fuer Partikel (nutzt die Partikel-Farbe).
static func particle(additive: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_dot()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func shader(shader_name: String, params: Dictionary = {}) -> ShaderMaterial:
	var path := "res://shaders/%s.gdshader" % shader_name
	if not _shader_cache.has(path):
		_shader_cache[path] = load(path)
	var m := ShaderMaterial.new()
	m.shader = _shader_cache[path]
	for k in params.keys():
		m.set_shader_parameter(str(k), params[k])
	return m

# ---------------------------------------------------------------- Meshes

static func box(size: Vector3, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _instance(mesh, material, pos)

static func cylinder(top_radius: float, bottom_radius: float, height: float, material: Material, pos: Vector3 = Vector3.ZERO, segments: int = 16) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _instance(mesh, material, pos)

static func sphere(radius: float, material: Material, pos: Vector3 = Vector3.ZERO, segments: int = 24) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(6, segments / 2)
	return _instance(mesh, material, pos)

static func torus(inner_radius: float, outer_radius: float, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 32
	mesh.ring_segments = 12
	return _instance(mesh, material, pos)

## Waagerechte Flaeche (Normale +Y).
static func plane(size: Vector2, material: Material, pos: Vector3 = Vector3.ZERO, subdivide: int = 0) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.subdivide_width = subdivide
	mesh.subdivide_depth = subdivide
	return _instance(mesh, material, pos)

## Senkrechte, unterteilte Flaeche in der XY-Ebene (Normale +Z) - fuer Fahnen/Segel mit Vertex-Animation.
static func vplane(size: Vector2, material: Material, pos: Vector3 = Vector3.ZERO, subdivide: int = 6) -> MeshInstance3D:
	var mesh := PlaneMesh.new()
	mesh.size = size
	mesh.orientation = PlaneMesh.FACE_Z
	mesh.subdivide_width = subdivide
	mesh.subdivide_depth = subdivide
	return _instance(mesh, material, pos)

## Senkrechte Flaeche (Normale +Z).
static func quad(size: Vector2, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	return _instance(mesh, material, pos)

static func prism(size: Vector3, material: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = size
	return _instance(mesh, material, pos)

static func _instance(mesh: Mesh, material: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if material != null:
		mi.material_override = material
	mi.position = pos
	return mi

# ---------------------------------------------------------------- Partikel

## Baut ein GPUParticles3D mit Farbverlauf. opts: amount, lifetime, one_shot, explosiveness, direction, spread,
## speed (Vector2 min/max), gravity, scale (Vector2 min/max), size, colors (Array[Color]), emission_radius,
## emission_box (Vector3), emission_ring (Vector2 radius/hoehe), damping (Vector2), radial_accel, tangential_accel,
## angular_velocity (Vector2), additive (bool), local (bool), mesh (Mesh), fade (bool)
static func particles(opts: Dictionary) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = int(opts.get("amount", 32))
	p.lifetime = float(opts.get("lifetime", 1.0))
	p.one_shot = bool(opts.get("one_shot", false))
	p.explosiveness = float(opts.get("explosiveness", 0.0))
	p.local_coords = bool(opts.get("local", false))
	p.fixed_fps = 30
	p.visibility_aabb = AABB(Vector3(-30, -30, -30), Vector3(60, 60, 60))
	var pm := ParticleProcessMaterial.new()
	pm.direction = opts.get("direction", Vector3.UP)
	pm.spread = float(opts.get("spread", 45.0))
	var speed: Vector2 = opts.get("speed", Vector2(1.0, 2.0))
	pm.initial_velocity_min = speed.x
	pm.initial_velocity_max = speed.y
	pm.gravity = opts.get("gravity", Vector3(0.0, -9.8, 0.0))
	var sc: Vector2 = opts.get("scale", Vector2(0.6, 1.2))
	pm.scale_min = sc.x
	pm.scale_max = sc.y
	if opts.has("damping"):
		var dmp: Vector2 = opts["damping"]
		pm.damping_min = dmp.x
		pm.damping_max = dmp.y
	if opts.has("radial_accel"):
		pm.radial_accel_min = float(opts["radial_accel"])
		pm.radial_accel_max = float(opts["radial_accel"])
	if opts.has("tangential_accel"):
		pm.tangential_accel_min = float(opts["tangential_accel"])
		pm.tangential_accel_max = float(opts["tangential_accel"])
	if opts.has("angular_velocity"):
		var av: Vector2 = opts["angular_velocity"]
		pm.angular_velocity_min = av.x
		pm.angular_velocity_max = av.y
	if opts.has("emission_radius"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = float(opts["emission_radius"])
	elif opts.has("emission_box"):
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = opts["emission_box"]
	elif opts.has("emission_ring"):
		var ring: Vector2 = opts["emission_ring"]
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3.UP
		pm.emission_ring_radius = ring.x
		pm.emission_ring_inner_radius = ring.x * 0.85
		pm.emission_ring_height = ring.y
	var colors: Array = opts.get("colors", [Color.WHITE, Color(1, 1, 1, 0)])
	var grad := Gradient.new()
	var offsets := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / maxf(1.0, float(colors.size() - 1)))
		cols.append(colors[i])
	grad.offsets = offsets
	grad.colors = cols
	var tex := GradientTexture1D.new()
	tex.gradient = grad
	tex.width = 64
	if bool(opts.get("random_color", false)):
		pm.color_initial_ramp = tex
	else:
		pm.color_ramp = tex
	p.process_material = pm
	if opts.has("mesh"):
		p.draw_pass_1 = opts["mesh"]
	else:
		var qm := QuadMesh.new()
		var size: float = float(opts.get("size", 0.25))
		qm.size = Vector2(size, size)
		qm.material = particle(bool(opts.get("additive", true)))
		p.draw_pass_1 = qm
	return p
