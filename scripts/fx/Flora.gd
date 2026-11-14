class_name Flora
extends RefCounted
## Low-Poly-Modelle fuer Waelder und Felsen, jeweils als EIN Mesh mit Vertex-Farben
## (passt in eine MultiMesh-Instanz: hunderte Baeume in einem Draw-Call).

static var _cache: Dictionary = {}

## Material fuer alle Flora-Meshes: Vertex-Farbe als Grundfarbe, Instanz-Farbe toent zusaetzlich.
static func material() -> StandardMaterial3D:
	if _cache.has("mat"):
		return _cache["mat"]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	_cache["mat"] = m
	return m

## Tanne: Stamm + vier Nadel-Etagen (dunkel unten, heller oben). Hoehe ~6.3 m.
static func pine() -> ArrayMesh:
	if _cache.has("pine"):
		return _cache["pine"]
	var parts: Array = [
		[_cyl(0.16, 0.26, 1.8, 6), Vector3(0.0, 0.9, 0.0), Color(0.36, 0.24, 0.14)],
		[_cyl(0.0, 1.7, 2.4, 8), Vector3(0.0, 2.1, 0.0), Color(0.09, 0.3, 0.15)],
		[_cyl(0.0, 1.35, 2.1, 8), Vector3(0.0, 3.25, 0.0), Color(0.11, 0.35, 0.17)],
		[_cyl(0.0, 1.0, 1.8, 8), Vector3(0.0, 4.3, 0.0), Color(0.13, 0.4, 0.19)],
		[_cyl(0.0, 0.62, 1.5, 7), Vector3(0.0, 5.3, 0.0), Color(0.16, 0.45, 0.21)],
	]
	_cache["pine"] = _merge(parts)
	return _cache["pine"]

## Laubbaum: Stamm + drei Kronen-Kugeln. Hoehe ~5 m.
static func broadleaf() -> ArrayMesh:
	if _cache.has("broadleaf"):
		return _cache["broadleaf"]
	var parts: Array = [
		[_cyl(0.18, 0.28, 2.4, 6), Vector3(0.0, 1.2, 0.0), Color(0.4, 0.27, 0.15)],
		[_sph(1.5, 1.3), Vector3(0.0, 3.3, 0.0), Color(0.2, 0.5, 0.2)],
		[_sph(1.1, 1.0), Vector3(0.8, 3.0, 0.3), Color(0.24, 0.56, 0.22)],
		[_sph(1.0, 0.9), Vector3(-0.6, 3.9, -0.4), Color(0.28, 0.6, 0.24)],
	]
	_cache["broadleaf"] = _merge(parts)
	return _cache["broadleaf"]

## Palme: gebogener Stamm aus Segmenten + sechs Wedel.
static func palm() -> ArrayMesh:
	if _cache.has("palm"):
		return _cache["palm"]
	var parts: Array = []
	var top := Vector3.ZERO
	for i in 5:
		var seg := Vector3(float(i) * 0.12, float(i) * 1.05 + 0.5, 0.0)
		parts.append([_cyl(0.17 - float(i) * 0.015, 0.21 - float(i) * 0.015, 1.1, 6), seg, Color(0.5, 0.37, 0.22).darkened(float(i % 2) * 0.12)])
		top = seg + Vector3(0.0, 0.55, 0.0)
	for k in 6:
		var a: float = TAU * float(k) / 6.0
		var leaf := _sph(1.0, 1.0, 6, 3)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.BACK, -0.35) * Basis.from_scale(Vector3(1.6, 0.09, 0.42))
		parts.append([leaf, Transform3D(b, top + Basis(Vector3.UP, a) * Vector3(1.25, -0.2, 0.0)), Color(0.2, 0.5, 0.2).lightened(float(k % 2) * 0.12)])
	_cache["palm"] = _merge(parts)
	return _cache["palm"]

## Verkohlter, toter Baum (Vulkan): Stamm + zwei Aeste.
static func dead_tree() -> ArrayMesh:
	if _cache.has("dead"):
		return _cache["dead"]
	var dark := Color(0.12, 0.09, 0.08)
	var parts: Array = [
		[_cyl(0.1, 0.24, 3.6, 6), Vector3(0.0, 1.8, 0.0), dark],
		[_cyl(0.04, 0.1, 1.6, 5), Transform3D(Basis(Vector3.BACK, 0.8), Vector3(0.45, 2.7, 0.0)), dark],
		[_cyl(0.03, 0.08, 1.2, 5), Transform3D(Basis(Vector3.BACK, -0.9) * Basis(Vector3.UP, 0.6), Vector3(-0.35, 3.1, 0.1)), dark],
	]
	_cache["dead"] = _merge(parts)
	return _cache["dead"]

## Felsbrocken: verbeulte Kugel (fester Seed, damit alle gleich aussehen).
static func boulder() -> ArrayMesh:
	if _cache.has("boulder"):
		return _cache["boulder"]
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.6
	sm.radial_segments = 9
	sm.rings = 5
	var arrays: Array = sm.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 1.3
	for i in verts.size():
		var v: Vector3 = verts[i]
		verts[i] = v * (1.0 + 0.28 * noise.get_noise_3dv(v))
	arrays[Mesh.ARRAY_VERTEX] = verts
	var cols := PackedColorArray()
	cols.resize(verts.size())
	for i in verts.size():
		cols[i] = Color(0.5, 0.48, 0.45).darkened(clampf(-verts[i].y * 0.25, 0.0, 0.3))
	arrays[Mesh.ARRAY_COLOR] = cols
	# Die Kugel-Normalen bleiben (weiche Beleuchtung, die Beulen zeigen sich in der Silhouette)
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cache["boulder"] = out
	return out

# ---------------------------------------------------------------- Helfer

static func _cyl(top: float, bottom: float, height: float, segs: int) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segs
	m.rings = 1
	m.cap_top = top > 0.0
	return m

static func _sph(radius: float, height_scale: float, segs: int = 8, rings: int = 5) -> Mesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0 * height_scale
	m.radial_segments = segs
	m.rings = rings
	return m

## parts: [[Mesh, Vector3 | Transform3D, Color], ...] -> ein Mesh mit Vertex-Farben.
static func _merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for part in parts:
		var mesh: Mesh = part[0]
		var xf: Transform3D = part[1] if part[1] is Transform3D else Transform3D(Basis.IDENTITY, part[1])
		var col: Color = part[2]
		var arrays: Array = mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var nn: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var ii: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var base: int = verts.size()
		var nb: Basis = xf.basis.inverse().transposed()
		for k in v.size():
			verts.append(xf * v[k])
			norms.append((nb * nn[k]).normalized())
			cols.append(col)
		for k in ii.size():
			idx.append(base + ii[k])
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = verts
	arrays_out[Mesh.ARRAY_NORMAL] = norms
	arrays_out[Mesh.ARRAY_COLOR] = cols
	arrays_out[Mesh.ARRAY_INDEX] = idx
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_out)
	return out
