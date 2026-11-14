class_name Flora
extends RefCounted
## Prozedurale Natur-Modelle: Laubbaeume und Tannen aus dickem Stamm + 3-5 klumpigen Kronen-Clustern,
## Palmen, tote Baeume, Wurzeln, Grasbueschel, Steine, Saeulen-Truemmer und Eisberge.
## Jedes Modell ist EIN Mesh mit Vertex-Farben (passt in eine MultiMesh-Instanz: hunderte Baeume in einem Draw-Call).
## Vertex-Farbe rgb = Farbe mit eingebackenem Kronen-Schatten (innen/unten dunkler), a = Materialart fuer
## shaders/flora.gdshader: LEAF (Laub, wiegt im Wind), WOOD (Rinde mit Furchen), STONE (Stein, optional Moos).
## Jedes Modell gibt es in einer Nah-Version und einer sparsamen Fern-Version (low = true).

const LEAF := 1.0
const WOOD := 0.5
const STONE := 0.0
## Anzahl Varianten pro Baumart (verschiedene Kronenformen)
const VARIANTS := {"broadleaf": 3, "pine": 3, "palm": 2, "dead": 2}

static var _cache: Dictionary = {}

## Material fuer alle Flora-Meshes (Wind + optional Moos auf Steinen).
static func material(moss: float = 0.0, wind: float = 1.0) -> ShaderMaterial:
	var key := "mat_%.2f_%.2f" % [moss, wind]
	if _cache.has(key):
		return _cache[key]
	var m := Mat.shader("flora", {"moss": moss, "wind_strength": wind})
	_cache[key] = m
	return m

## Material fuer einzelne Steine/Felsen mit eigener Toenung.
static func stone_material(color: Color, moss: float = 0.0) -> ShaderMaterial:
	return Mat.shader("flora", {"moss": moss, "wind_strength": 0.0, "tint": Color(color.r * 2.0, color.g * 2.0, color.b * 2.0)})

## Baum nach Art ("broadleaf" | "pine" | "palm" | "dead"), Variante und Detailstufe.
static func tree(kind: String, variant: int = 0, low: bool = false) -> ArrayMesh:
	var v: int = posmod(variant, int(VARIANTS.get(kind, 1)))
	var key := "%s_%d_%s" % [kind, v, "lo" if low else "hi"]
	if _cache.has(key):
		return _cache[key]
	var parts: Array
	match kind:
		"pine":
			parts = _pine_parts(v, low)
		"palm":
			parts = _palm_parts(v, low)
		"dead":
			parts = _dead_parts(v, low)
		_:
			parts = _broadleaf_parts(v, low)
	var mesh := _merge(parts)
	_cache[key] = mesh
	return mesh

## Kompatibilitaet: Standard-Varianten
static func pine() -> ArrayMesh:
	return tree("pine")

static func broadleaf() -> ArrayMesh:
	return tree("broadleaf")

static func palm() -> ArrayMesh:
	return tree("palm")

static func dead_tree() -> ArrayMesh:
	return tree("dead")

# ---------------------------------------------------------------- Baumarten

## Laubbaum: dicker Stamm mit Wurzelansatz, zwei Hauptaeste, 3-5 ueberlappende Kronen-Klumpen. Hoehe ~5.5 m.
static func _broadleaf_parts(v: int, low: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + v * 77
	var bark := Color(0.33, 0.23, 0.15)
	var segs: int = 6 if low else 10
	var parts: Array = []
	parts.append(_part(_cyl(0.2, 0.34, 3.2, segs), Vector3(0.0, 1.6, 0.0), bark, WOOD, bark.lightened(0.15)))
	if not low:
		parts.append(_part(_cyl(0.34, 0.62, 0.5, segs), Vector3(0.0, 0.2, 0.0), bark.darkened(0.15), WOOD))
	var crown := Vector3(0.0, 4.1, 0.0)
	var clusters: int = 3 + v % 3
	if low:
		clusters = 3
	var dark := Color(0.12, 0.3, 0.11)
	var light := Color(0.34, 0.6, 0.2)
	var hue: float = rng.randf_range(-0.03, 0.03)
	for k in clusters:
		var c: Vector3
		var r: float
		if k == 0:
			c = crown + Vector3(0.0, 0.3, 0.0)
			r = 1.65
		else:
			var a: float = TAU * float(k) / float(clusters - 1) + rng.randf_range(-0.4, 0.4)
			c = crown + Vector3(cos(a) * rng.randf_range(0.95, 1.35), rng.randf_range(-0.6, 0.5), sin(a) * rng.randf_range(0.95, 1.35))
			r = rng.randf_range(1.0, 1.35)
			if not low and k <= 2:
				# Ast vom Stamm zum Klumpen
				var from := Vector3(0.0, 2.6 + float(k) * 0.3, 0.0)
				parts.append(_branch(from, c * 0.85 + from * 0.15, 0.13, 0.07, bark, segs))
		var dk := Color.from_hsv(fposmod(dark.h + hue + rng.randf_range(-0.02, 0.02), 1.0), dark.s, dark.v)
		var lt := Color.from_hsv(fposmod(light.h + hue + rng.randf_range(-0.02, 0.02), 1.0), light.s, light.v * rng.randf_range(0.92, 1.08))
		var blob: Array = _blob(r, Vector3(1.0, 0.82, 1.0), 31 + v * 13 + k, 0.2, 7 if low else 11, 4 if low else 7)
		parts.append(_part(blob, c, dk, LEAF, lt, crown, 2.6))
	return parts

## Tanne: Stamm + 4-5 uebereinander gestapelte, nach oben schmaler werdende Nadel-Klumpen (gezackte Silhouette).
static func _pine_parts(v: int, low: bool) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000 + v * 91
	var bark := Color(0.3, 0.2, 0.13)
	var segs: int = 6 if low else 9
	var parts: Array = []
	parts.append(_part(_cyl(0.13, 0.3, 2.4, segs), Vector3(0.0, 1.2, 0.0), bark, WOOD, bark.lightened(0.1)))
	var tiers: int = 3 if low else 4 + v % 2
	var dark := Color(0.06, 0.22, 0.11)
	var light := Color(0.15, 0.42, 0.21)
	var y := 1.9
	for k in tiers:
		var t: float = float(k) / float(maxi(1, tiers - 1))
		var r: float = lerpf(1.75, 0.55, t) * rng.randf_range(0.92, 1.08)
		var c := Vector3(rng.randf_range(-0.12, 0.12), y + r * 0.55, rng.randf_range(-0.12, 0.12))
		var blob: Array = _blob(r, Vector3(1.0, 0.95, 1.0), 57 + v * 7 + k, 0.3, 7 if low else 12, 4 if low else 7)
		parts.append(_part(blob, c, dark.lerp(light, t * 0.4), LEAF, light.lerp(Color(0.22, 0.5, 0.26), t * 0.3), Vector3(0.0, 3.6, 0.0), 2.4))
		y += r * 0.95
	# Spitze
	parts.append(_part(_cyl(0.0, 0.4, 1.2, segs), Vector3(0.0, y + 0.35, 0.0), light, LEAF))
	return parts

## Palme: gebogener Ringel-Stamm, Kokosnuesse und Wedel.
static func _palm_parts(v: int, low: bool) -> Array:
	var parts: Array = []
	var top := Vector3.ZERO
	var lean: float = 0.12 + 0.08 * float(v)
	var segs: int = 5 if low else 8
	for i in 6:
		var seg := Vector3(float(i * i) * lean * 0.12, float(i) * 1.0 + 0.5, 0.0)
		var col := Color(0.5, 0.37, 0.22).darkened(float(i % 2) * 0.12)
		parts.append(_part(_cyl(0.16 - float(i) * 0.012, 0.21 - float(i) * 0.012, 1.05, segs), seg, col, WOOD))
		top = seg + Vector3(0.0, 0.55, 0.0)
	if not low:
		for k in 3:
			var a: float = TAU * float(k) / 3.0
			parts.append(_part(_sph(0.17, 1.0, 7, 4), top + Vector3(cos(a) * 0.22, -0.25, sin(a) * 0.22), Color(0.3, 0.22, 0.1), WOOD))
	var fronds: int = 6 if low else 8
	for k in fronds:
		var a: float = TAU * float(k) / float(fronds) + float(v) * 0.3
		var leaf := _sph(1.0, 1.0, 6, 3)
		var b := Basis(Vector3.UP, a) * Basis(Vector3.BACK, -0.45 - 0.1 * float(k % 2)) * Basis.from_scale(Vector3(1.75, 0.08, 0.45))
		parts.append(_part(leaf, Transform3D(b, top + Basis(Vector3.UP, a) * Vector3(1.35, -0.25, 0.0)),
			Color(0.13, 0.36, 0.13), LEAF, Color(0.3, 0.6, 0.22)))
	return parts

## Verkohlter, toter Baum (Vulkan): dicker Stamm + drei bis vier knorrige Aeste.
static func _dead_parts(v: int, low: bool) -> Array:
	var dark := Color(0.12, 0.09, 0.08)
	var segs: int = 5 if low else 8
	var parts: Array = [
		_part(_cyl(0.12, 0.3, 3.8, segs), Vector3(0.0, 1.9, 0.0), dark, WOOD, dark.lightened(0.1)),
	]
	if not low:
		parts.append(_part(_cyl(0.3, 0.52, 0.45, segs), Vector3(0.0, 0.2, 0.0), dark.darkened(0.2), WOOD))
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000 + v * 17
	for k in (2 if low else 4):
		var a: float = TAU * float(k) / 4.0 + rng.randf_range(-0.4, 0.4)
		var from := Vector3(0.0, 2.2 + float(k) * 0.45, 0.0)
		var to := from + Vector3(cos(a) * rng.randf_range(0.9, 1.5), rng.randf_range(0.5, 1.1), sin(a) * rng.randf_range(0.9, 1.5))
		parts.append(_branch(from, to, 0.1, 0.03, dark, segs))
	return parts

# ---------------------------------------------------------------- Kleinkram und Kulissen

## Felsbrocken: verbeulte Kugel (fester Seed, damit alle gleich aussehen). Vertex-Grau 0.5 (Toenung per Instanz).
static func boulder() -> ArrayMesh:
	if _cache.has("boulder"):
		return _cache["boulder"]
	var blob: Array = _blob(1.0, Vector3(1.0, 0.8, 1.0), 11, 0.28, 9, 5)
	var out := _merge([_part(blob, Vector3.ZERO, Color(0.36, 0.34, 0.32), STONE, Color(0.52, 0.5, 0.47))])
	_cache["boulder"] = out
	return out

## Knorrige Wurzel: gebogene, sich verjuengende Roehre, liegt flach (Laenge entlang +X, Wurzelansatz bei 0).
static func root(variant: int = 0) -> ArrayMesh:
	var key := "root_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 4000 + variant * 13
	var parts: Array = []
	var p := Vector3(0.0, 0.18, 0.0)
	var r: float = 0.24
	for i in 5:
		var next := p + Vector3(0.55, -0.04 + rng.randf_range(-0.03, 0.03), rng.randf_range(-0.18, 0.18))
		parts.append(_branch(p, next, r, r * 0.8, Color(0.3, 0.21, 0.13), 7))
		p = next
		r *= 0.8
	var out := _merge(parts)
	_cache[key] = out
	return out

## Grasbueschel: sieben duenne Halme (echte 3D-Kegel), wiegen im Wind.
static func tuft(variant: int = 0) -> ArrayMesh:
	var key := "tuft_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + variant
	var parts: Array = []
	for i in 7:
		var a: float = TAU * float(i) / 7.0 + rng.randf_range(-0.3, 0.3)
		var h: float = rng.randf_range(0.28, 0.5)
		var tilt := Basis(Vector3(cos(a + PI * 0.5), 0.0, sin(a + PI * 0.5)), rng.randf_range(0.15, 0.45))
		parts.append(_part(_cyl(0.0, 0.025, h, 3), Transform3D(tilt, tilt * Vector3(0.0, h * 0.5, 0.0) + Vector3(cos(a), 0.0, sin(a)) * 0.05),
			Color(0.16, 0.38, 0.12), LEAF, Color(0.42, 0.62, 0.24)))
	var out := _merge(parts)
	_cache[key] = out
	return out

## Antike Saeule: Basis, kannelierter Schaft (abgebrochen, wenn broken), Kapitell. Hoehe ~4.5 m (Stein, Moos).
static func column(broken: bool, variant: int = 0) -> ArrayMesh:
	var key := "col_%s_%d" % [str(broken), variant]
	if _cache.has(key):
		return _cache[key]
	var stone := Color(0.42, 0.4, 0.36)
	var parts: Array = [_part(_cyl(0.62, 0.7, 0.35, 12), Vector3(0.0, 0.17, 0.0), stone.darkened(0.1), STONE, stone)]
	var shaft_h: float = 4.0 if not broken else 1.4 + 0.6 * float(variant % 3)
	parts.append(_part(_cyl(0.42, 0.48, shaft_h, 12), Vector3(0.0, 0.35 + shaft_h * 0.5, 0.0), stone, STONE, stone.lightened(0.1)))
	if not broken:
		parts.append(_part(_cyl(0.68, 0.45, 0.3, 12), Vector3(0.0, 0.35 + shaft_h + 0.15, 0.0), stone, STONE))
		parts.append(_part(_box(Vector3(1.5, 0.28, 1.5)), Vector3(0.0, 0.35 + shaft_h + 0.44, 0.0), stone.darkened(0.05), STONE))
	else:
		# Bruchkante: schraege, verbeulte Kappe
		var cap: Array = _blob(0.47, Vector3(1.0, 0.35, 1.0), 71 + variant, 0.35, 10, 5)
		parts.append(_part(cap, Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(0.0, 0.35 + shaft_h, 0.0)), stone, STONE))
	var out := _merge(parts)
	_cache[key] = out
	return out

## Gefallene Saeulen-Trommel / Mauerblock (liegt am Boden).
static func ruin_block(variant: int = 0) -> ArrayMesh:
	var key := "block_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var stone := Color(0.4, 0.38, 0.34)
	var parts: Array
	if variant % 2 == 0:
		parts = [_part(_cyl(0.46, 0.46, 1.4, 12), Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(0.0, 0.46, 0.0)), stone, STONE, stone.lightened(0.1))]
	else:
		parts = [_part(_box(Vector3(1.6, 0.8, 0.9)), Vector3(0.0, 0.4, 0.0), stone.darkened(0.05), STONE, stone),
			_part(_box(Vector3(1.1, 0.6, 0.8)), Transform3D(Basis(Vector3.UP, 0.3), Vector3(0.3, 1.1, 0.05)), stone, STONE, stone.lightened(0.08))]
	var out := _merge(parts)
	_cache[key] = out
	return out

## Randbaum (Tree-Space: Stamm bei x = 0, +X zeigt zur Bahn). Mit `reach` > 0 waechst ein dicker Ast
## waagerecht ueber die Bahn: von (0, attach_h) bis (reach, end_h), am Ende ein Laub-Buschel.
## kind: "broadleaf" | "dead" | "jungle". trunk_h = Stammhoehe bis zur Krone.
static func edge_tree(kind: String, trunk_h: float, reach: float, attach_h: float, end_h: float, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + variant * 31
	var dead: bool = kind == "dead"
	var bark := Color(0.12, 0.09, 0.08) if dead else Color(0.32, 0.22, 0.14)
	var parts: Array = []
	parts.append(_part(_cyl(0.3, 0.46, trunk_h, 10), Vector3(0.0, trunk_h * 0.5, 0.0), bark, WOOD, bark.lightened(0.12)))
	parts.append(_part(_cyl(0.46, 0.85, 0.6, 10), Vector3(0.0, 0.25, 0.0), bark.darkened(0.15), WOOD))
	var dark := Color(0.12, 0.3, 0.11) if kind != "jungle" else Color(0.1, 0.33, 0.14)
	var light := Color(0.34, 0.6, 0.2) if kind != "jungle" else Color(0.3, 0.62, 0.24)
	if reach > 0.0:
		# der grosse Ast ueber die Bahn (zweiteilig, leicht durchhaengend) + Seitenzweig
		var a := Vector3(0.1, attach_h, 0.0)
		var m := Vector3(reach * 0.55, lerpf(attach_h, end_h, 0.45) + 0.12, rng.randf_range(-0.2, 0.2))
		var e := Vector3(reach, end_h, rng.randf_range(-0.25, 0.25))
		parts.append(_branch(a, m, 0.26, 0.19, bark, 9))
		parts.append(_branch(m, e, 0.19, 0.11, bark, 8))
		parts.append(_branch(m, m + Vector3(0.7, 0.9, 0.5), 0.1, 0.04, bark, 6))
		if not dead:
			for k in 2:
				var c: Vector3 = e + Vector3(-0.3 * float(k), 0.75 + 0.25 * float(k), (float(k) - 0.5) * 0.7)
				parts.append(_part(_blob(0.75 - 0.15 * float(k), Vector3(1.2, 0.7, 1.0), 400 + variant * 3 + k, 0.25, 9, 6), c, dark, LEAF, light, e + Vector3(0.0, 0.8, 0.0), 1.2))
	if dead:
		for k in 3:
			var ang: float = TAU * float(k) / 3.0 + 1.2
			var from := Vector3(0.0, trunk_h * (0.6 + 0.12 * float(k)), 0.0)
			parts.append(_branch(from, from + Vector3(cos(ang) * 1.2, 0.9, sin(ang) * 1.2), 0.12, 0.04, bark, 6))
	else:
		var crown := Vector3(-0.3, trunk_h + 0.9, 0.0)
		for k in 4:
			var c: Vector3
			var r: float
			if k == 0:
				c = crown + Vector3(0.0, 0.4, 0.0)
				r = 1.9
			else:
				var ang: float = TAU * float(k) / 3.0 + rng.randf_range(-0.3, 0.3)
				c = crown + Vector3(cos(ang) * 1.3, rng.randf_range(-0.5, 0.4), sin(ang) * 1.3)
				r = rng.randf_range(1.2, 1.5)
			parts.append(_part(_blob(r, Vector3(1.0, 0.8, 1.0), 450 + variant * 7 + k, 0.22, 11, 7), c, dark, LEAF, light, crown, 2.8))
	return _merge(parts)

## Liane: duenne Ranke (nach unten, Laenge len) mit Blaettern, Aufhaengepunkt bei y = 0.
static func liana(length: float, variant: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 8000 + variant
	var parts: Array = [_part(_cyl(0.03, 0.04, length, 5), Vector3(0.0, -length * 0.5, 0.0), Color(0.22, 0.32, 0.12), LEAF, Color(0.3, 0.4, 0.15))]
	var n: int = int(length / 0.3)
	for i in n:
		var y: float = -0.2 - float(i) * 0.3
		var lf := _blob(0.13, Vector3(1.4, 0.45, 0.8), 900 + variant * 11 + i, 0.2, 6, 4)
		parts.append(_part(lf, Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(rng.randf_range(-0.07, 0.07), y, rng.randf_range(-0.07, 0.07))),
			Color(0.14, 0.38, 0.13), LEAF, Color(0.3, 0.58, 0.2)))
	return _merge(parts)

## Architrav-Balken (liegt auf zwei Saeulen), 1.6 m lang entlang X.
static func beam() -> ArrayMesh:
	if _cache.has("beam"):
		return _cache["beam"]
	var stone := Color(0.42, 0.4, 0.36)
	var out := _merge([_part(_box(Vector3(1.6, 0.5, 0.8)), Vector3.ZERO, stone.darkened(0.08), STONE, stone.lightened(0.05))])
	_cache["beam"] = out
	return out

## Eisberg: zerkluefteter, kantiger Block (weiss-blau). Hoehe ~1 (wird skaliert).
static func iceberg(variant: int = 0) -> ArrayMesh:
	var key := "ice_%d" % variant
	if _cache.has(key):
		return _cache[key]
	var blob: Array = _blob(1.0, Vector3(1.0, 1.25, 0.85), 91 + variant * 5, 0.45, 7, 5)
	var out := _merge([_part(blob, Vector3(0.0, 0.6, 0.0), Color(0.5, 0.72, 0.85), STONE, Color(0.97, 0.99, 1.0))])
	_cache[key] = out
	return out

# ---------------------------------------------------------------- Helfer

## Ein Bauteil: mesh = Mesh oder [verts, norms, idx]; xf = Vector3 | Transform3D; col = Farbe unten, col_top = oben;
## kind = Materialart; ao_center/ao_radius: Mittelpunkt der Krone -> innen/unten liegende Punkte werden dunkler.
static func _part(mesh: Variant, xf: Variant, col: Color, kind: float, col_top: Color = Color(-1, 0, 0),
		ao_center: Vector3 = Vector3.INF, ao_radius: float = 0.0) -> Dictionary:
	return {"mesh": mesh, "xf": xf if xf is Transform3D else Transform3D(Basis.IDENTITY, xf), "col": col,
		"top": col if col_top.r < 0.0 else col_top, "kind": kind, "ao_c": ao_center, "ao_r": ao_radius}

## Ast/Wurzel als schraeger, sich verjuengender Zylinder von `from` nach `to`.
static func _branch(from: Vector3, to: Vector3, r0: float, r1: float, col: Color, segs: int) -> Dictionary:
	var d: Vector3 = to - from
	var seg_len: float = d.length()
	var up: Vector3 = d / maxf(seg_len, 0.001)
	var side: Vector3 = up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd: Vector3 = side.cross(up)
	var b := Basis(side, up, fwd)
	return _part(_cyl(r1, r0, seg_len, segs), Transform3D(b, from + d * 0.5), col, WOOD, col.lightened(0.08))

## Verbeulte Kugel/Ellipsoid als [verts, norms, idx]: Rauschen verschiebt die Oberflaeche (Silhouette),
## die Normalen bleiben weich (Ellipsoid-Normale) - die Feinstruktur macht der Shader.
static func _blob(radius: float, stretch: Vector3, noise_seed: int, lump: float, segs: int, rings: int) -> Array:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = segs
	sm.rings = rings
	var arrays: Array = sm.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms := PackedVector3Array()
	norms.resize(verts.size())
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 1.1
	for i in verts.size():
		var v: Vector3 = verts[i]
		var bump: float = 1.0 + lump * noise.get_noise_3dv(v * 1.4)
		verts[i] = Vector3(v.x * stretch.x, v.y * stretch.y, v.z * stretch.z) * radius * bump
		norms[i] = Vector3(v.x / stretch.x, v.y / stretch.y, v.z / stretch.z).normalized()
	return [verts, norms, arrays[Mesh.ARRAY_INDEX]]

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

static func _box(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m

## parts: Array von _part()-Dictionaries -> ein Mesh mit Vertex-Farben (Verlauf unten->oben + Kronen-Schatten).
static func _merge(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	for part: Dictionary in parts:
		var v: PackedVector3Array
		var nn: PackedVector3Array
		var ii: PackedInt32Array
		if part["mesh"] is Mesh:
			var arrays: Array = (part["mesh"] as Mesh).surface_get_arrays(0)
			v = arrays[Mesh.ARRAY_VERTEX]
			nn = arrays[Mesh.ARRAY_NORMAL]
			ii = arrays[Mesh.ARRAY_INDEX]
		else:
			v = part["mesh"][0]
			nn = part["mesh"][1]
			ii = part["mesh"][2]
		var xf: Transform3D = part["xf"]
		var nb: Basis = xf.basis.inverse().transposed()
		var col: Color = part["col"]
		var top: Color = part["top"]
		var kind: float = part["kind"]
		var ao_c: Vector3 = part["ao_c"]
		var ao_r: float = part["ao_r"]
		# Hoehenbereich des Teils fuer den Farbverlauf
		var y0 := INF
		var y1 := -INF
		for k in v.size():
			y0 = minf(y0, v[k].y)
			y1 = maxf(y1, v[k].y)
		var base: int = verts.size()
		for k in v.size():
			var p: Vector3 = xf * v[k]
			var n: Vector3 = (nb * nn[k]).normalized()
			var t: float = clampf((v[k].y - y0) / maxf(0.001, y1 - y0), 0.0, 1.0)
			var c: Color = col.lerp(top, t)
			if ao_c != Vector3.INF:
				# Kronen-Schatten: zur Kronenmitte zeigende und tief liegende Punkte dunkler
				var out_dir: Vector3 = (p - ao_c).normalized()
				var facing: float = clampf(n.dot(out_dir) * 0.5 + 0.5, 0.0, 1.0)
				var low: float = clampf((ao_c.y - p.y) / maxf(0.1, ao_r), 0.0, 1.0)
				var dist: float = clampf((p - ao_c).length() / maxf(0.1, ao_r), 0.0, 1.0)
				var ao: float = lerpf(0.5, 1.0, facing) * lerpf(1.0, 0.72, low) * lerpf(0.8, 1.0, dist)
				c = Color(c.r * ao, c.g * ao, c.b * ao)
			c.a = kind
			verts.append(p)
			norms.append(n)
			cols.append(c)
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
