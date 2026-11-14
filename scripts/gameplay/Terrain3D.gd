class_name Terrain3D
extends RefCounted
## Gelaende rund um eine Bahn: ein Hoehenfeld, in das die Bahn eingebettet ist.
## - Direkt neben der Bahn liegt ein flacher Randstreifen knapp unter dem Belag (die Bahn wirkt eingelassen).
## - Dahinter steigen Boeschungen, Felsterrassen (Klippen) und Bergruecken auf.
## - Unter Spruengen, Kanonen-Fluegen und Stuecken ohne Bande klafft eine tiefe Schlucht (Wasser/Lava unten).
## Das Hoehenfeld ist zugleich die Aus-Grenze: beruehrt der Ball das Gelaende, ist er "aus" (Gadgets.TerrainBounds).
## Es haengt nur von der Bahn-Geometrie und einem festen Seed ab - alle Spieler sehen dasselbe Gelaende.

const CELL := 2.5
const MARGIN := 80.0
## Flacher Randstreifen neben der Bahn (m ab der naechsten Belag-Probe)
const SHOULDER := 6.0
## Unter der Bahn liegt das Gelaende so tief unter dem Belag (Platz fuer Loch-Becher),
const UNDER_DROP := 0.9
## ... auf dem Randstreifen so tief.
const EDGE_DROP := 0.35

var origin := Vector2.ZERO
var nx: int = 0
var nz: int = 0
var heights := PackedFloat32Array()
## Abstand jedes Gitterpunkts zur Bahn (m)
var track_dist := PackedFloat32Array()
## 0..1: Schlucht / Ufer (fuer Farbe und Deko)
var wet := PackedFloat32Array()
var deep_y: float = -10.0
var base_y: float = 0.0

## opts: deep (Schluchtboden-Hoehe), height (Berghoehe), terrace (Klippen-Stufe in m, 0 = aus),
## sea_dir (Vector2, Richtung zum Meer, ZERO = ringsum Berge), seed (int).
static func build(course: Course3D, opts: Dictionary) -> Terrain3D:
	var t := Terrain3D.new()
	t._build(course, opts)
	return t

func index(ix: int, iz: int) -> int:
	return iz * nx + ix

func world_pos(ix: int, iz: int) -> Vector3:
	return Vector3(origin.x + float(ix) * CELL, heights[iz * nx + ix], origin.y + float(iz) * CELL)

func _build(course: Course3D, opts: Dictionary) -> void:
	var pts: PackedVector3Array = course.surface_pts
	var open_flags: PackedByteArray = course.surface_open
	deep_y = float(opts.get("deep", -10.0))
	var mount_h: float = float(opts.get("height", 26.0))
	var terrace: float = float(opts.get("terrace", 0.0))
	var sea_dir: Vector2 = opts.get("sea_dir", Vector2.ZERO)
	# --- Ausdehnung ---
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	var ysum := 0.0
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
		ysum += p.y
	for cor in course.corridors:
		for key in ["a", "b"]:
			var q: Vector3 = cor[key]
			mn = Vector2(minf(mn.x, q.x), minf(mn.y, q.z))
			mx = Vector2(maxf(mx.x, q.x), maxf(mx.y, q.z))
	if pts.is_empty():
		mn = Vector2(-20.0, -20.0)
		mx = Vector2(20.0, 20.0)
	base_y = ysum / float(maxi(1, pts.size()))
	origin = mn - Vector2(MARGIN, MARGIN)
	nx = int(ceil((mx.x - mn.x + MARGIN * 2.0) / CELL)) + 1
	nz = int(ceil((mx.y - mn.y + MARGIN * 2.0) / CELL)) + 1
	var n: int = nx * nz
	var center := (mn + mx) * 0.5
	# --- Saat-Punkte: Belag-Proben auf das Gitter legen ---
	var seed_y := PackedFloat32Array()
	seed_y.resize(n)
	seed_y.fill(INF)
	var seed_closed := PackedByteArray()
	seed_closed.resize(n)
	seed_closed.fill(0)
	var nearest := PackedInt32Array()
	nearest.resize(n)
	nearest.fill(-1)
	track_dist.resize(n)
	track_dist.fill(INF)
	for i in pts.size():
		var p: Vector3 = pts[i]
		var ix: int = clampi(int(round((p.x - origin.x) / CELL)), 0, nx - 1)
		var iz: int = clampi(int(round((p.z - origin.y) / CELL)), 0, nz - 1)
		var c: int = iz * nx + ix
		seed_y[c] = minf(seed_y[c], p.y)
		nearest[c] = c
		track_dist[c] = 0.0
		if i >= open_flags.size() or open_flags[i] == 0:
			seed_closed[c] = 1
	# --- Abstandsfeld (Chamfer, 8 Nachbarn) mit "naechster Saatpunkt" ---
	var diag: float = CELL * 1.41421
	var fwd: Array[Vector3i] = [Vector3i(-1, -1, 1), Vector3i(0, -1, 0), Vector3i(1, -1, 1), Vector3i(-1, 0, 0)]
	var bwd: Array[Vector3i] = [Vector3i(1, 1, 1), Vector3i(0, 1, 0), Vector3i(-1, 1, 1), Vector3i(1, 0, 0)]
	for pass_i in 2:
		var offs: Array[Vector3i] = fwd if pass_i == 0 else bwd
		var z0: int = 0 if pass_i == 0 else nz - 1
		var z1: int = nz if pass_i == 0 else -1
		var st: int = 1 if pass_i == 0 else -1
		var iz: int = z0
		while iz != z1:
			var ix: int = 0 if pass_i == 0 else nx - 1
			var x1: int = nx if pass_i == 0 else -1
			while ix != x1:
				var c: int = iz * nx + ix
				var best: float = track_dist[c]
				for o in offs:
					var jx: int = ix + o.x
					var jz: int = iz + o.y
					if jx < 0 or jz < 0 or jx >= nx or jz >= nz:
						continue
					var j: int = jz * nx + jx
					var dd: float = track_dist[j] + (diag if o.z == 1 else CELL)
					if dd < best:
						best = dd
						nearest[c] = nearest[j]
				track_dist[c] = best
				ix += st
			iz += st
	# --- Kappen: tiefster Belag in der Naehe (Radius 1 bzw. 2 Gitterpunkte) ---
	var cap1: PackedFloat32Array = _min_filter(seed_y, 1)
	var cap2: PackedFloat32Array = _min_filter(seed_y, 2)
	# --- Rauschen (fester Seed: deterministisch fuer alle Spieler) ---
	var noise := FastNoiseLite.new()
	noise.seed = int(opts.get("seed", 1))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.018
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	var ridge := FastNoiseLite.new()
	ridge.seed = int(opts.get("seed", 1)) + 7
	ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX
	ridge.frequency = 0.011
	ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	ridge.fractal_octaves = 3
	# --- Hoehen ---
	heights.resize(n)
	wet.resize(n)
	wet.fill(0.0)
	for iz in nz:
		for ix in nx:
			var c: int = iz * nx + ix
			var x: float = origin.x + float(ix) * CELL
			var z: float = origin.y + float(iz) * CELL
			var d: float = track_dist[c]
			var s: int = nearest[c]
			var base: float = seed_y[s] if s >= 0 else base_y
			var r: float = maxf(0.0, d - SHOULDER)
			var bank: float = 2.2 * smoothstep(0.0, 9.0, r)
			var nv: float = noise.get_noise_2d(x, z)
			var rv: float = ridge.get_noise_2d(x, z)
			var m: float = mount_h * smoothstep(4.0, 46.0, r) * (0.55 + 0.45 * nv + 0.5 * maxf(0.0, rv))
			if terrace > 0.5 and m > 1.0:
				var tm: float = m / terrace
				var fl: float = floor(tm)
				var stepped: float = (fl + smoothstep(0.6, 0.92, tm - fl)) * terrace
				m = lerpf(m, stepped, 0.75)
			var far: float = 0.3 * maxf(0.0, d - 70.0)
			var h: float = base - EDGE_DROP + bank + m + far + nv * 0.6 * smoothstep(2.0, 12.0, r)
			# Kuestenseite (Piratenbucht): Gelaende faellt zum Meer ab
			if sea_dir != Vector2.ZERO:
				var to := Vector2(x, z) - center
				if to.length() > 0.01:
					var side: float = smoothstep(-0.1, 0.55, to.normalized().dot(sea_dir)) * smoothstep(4.0, 26.0, r)
					if side > 0.0:
						h = lerpf(h, deep_y - 1.5, side)
						wet[c] = maxf(wet[c], side)
			# Stueck ohne Bande: daneben geht es in die Tiefe
			if s >= 0 and seed_closed[s] == 0:
				var w: float = 1.0 - smoothstep(3.5, 11.0, d)
				h = lerpf(h, deep_y, w)
				wet[c] = maxf(wet[c], w)
			# Sicherheits-Kappen: das Gelaende bleibt immer unter dem Belag
			if d <= 0.01 and cap1[c] < INF:
				h = minf(h, cap1[c] - UNDER_DROP)
			elif cap2[c] < INF:
				h = minf(h, minf(base, cap2[c]) - EDGE_DROP)
			heights[c] = h
	# --- Schluchten unter Spruengen und Fluegen ---
	for cor in course.corridors:
		_carve(cor)

## Kleinster Wert in einem (2r+1)^2-Fenster (separierbar: erst Zeilen, dann Spalten).
func _min_filter(src: PackedFloat32Array, r: int) -> PackedFloat32Array:
	var tmp := PackedFloat32Array()
	tmp.resize(src.size())
	for iz in nz:
		for ix in nx:
			var m: float = INF
			for k in range(-r, r + 1):
				var jx: int = ix + k
				if jx >= 0 and jx < nx:
					m = minf(m, src[iz * nx + jx])
			tmp[iz * nx + ix] = m
	var out := PackedFloat32Array()
	out.resize(src.size())
	for iz in nz:
		for ix in nx:
			var m: float = INF
			for k in range(-r, r + 1):
				var jz: int = iz + k
				if jz >= 0 and jz < nz:
					m = minf(m, tmp[jz * nx + ix])
			out[iz * nx + ix] = m
	return out

func _carve(cor: Dictionary) -> void:
	var a3: Vector3 = cor["a"]
	var b3: Vector3 = cor["b"]
	var half: float = float(cor.get("half", 3.0))
	var a := Vector2(a3.x, a3.z)
	var b := Vector2(b3.x, b3.z)
	var reach: float = half + 9.0
	var lo := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(reach, reach)
	var hi := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(reach, reach)
	var ix0: int = clampi(int(floor((lo.x - origin.x) / CELL)), 0, nx - 1)
	var ix1: int = clampi(int(ceil((hi.x - origin.x) / CELL)), 0, nx - 1)
	var iz0: int = clampi(int(floor((lo.y - origin.y) / CELL)), 0, nz - 1)
	var iz1: int = clampi(int(ceil((hi.y - origin.y) / CELL)), 0, nz - 1)
	var ab: Vector2 = b - a
	var len2: float = maxf(0.0001, ab.length_squared())
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var p := Vector2(origin.x + float(ix) * CELL, origin.y + float(iz) * CELL)
			var t: float = clampf((p - a).dot(ab) / len2, 0.0, 1.0)
			var dist: float = p.distance_to(a + ab * t)
			var w: float = 1.0 - smoothstep(half, reach, dist)
			if w <= 0.0:
				continue
			var c: int = iz * nx + ix
			heights[c] = minf(heights[c], lerpf(heights[c], deep_y, w))
			wet[c] = maxf(wet[c], w)

# ================================================================ Abfragen

## Gelaendehoehe an (x, z), bilinear. Ausserhalb des Gitters: Randwert.
func height_at(x: float, z: float) -> float:
	var fx: float = clampf((x - origin.x) / CELL, 0.0, float(nx - 1) - 0.001)
	var fz: float = clampf((z - origin.y) / CELL, 0.0, float(nz - 1) - 0.001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var c: int = iz * nx + ix
	var h00: float = heights[c]
	var h10: float = heights[c + 1]
	var h01: float = heights[c + nx]
	var h11: float = heights[c + nx + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)

## Abstand zur Bahn an (x, z) (naechster Gitterpunkt).
func distance_at(x: float, z: float) -> float:
	var ix: int = clampi(int(round((x - origin.x) / CELL)), 0, nx - 1)
	var iz: int = clampi(int(round((z - origin.y) / CELL)), 0, nz - 1)
	return track_dist[iz * nx + ix]

func normal_at_index(ix: int, iz: int) -> Vector3:
	var hl: float = heights[iz * nx + maxi(0, ix - 1)]
	var hr: float = heights[iz * nx + mini(nx - 1, ix + 1)]
	var hd: float = heights[maxi(0, iz - 1) * nx + ix]
	var hu: float = heights[mini(nz - 1, iz + 1) * nx + ix]
	return Vector3(hl - hr, CELL * 2.0, hd - hu).normalized()

func normal_at(x: float, z: float) -> Vector3:
	var ix: int = clampi(int(round((x - origin.x) / CELL)), 0, nx - 1)
	var iz: int = clampi(int(round((z - origin.y) / CELL)), 0, nz - 1)
	return normal_at_index(ix, iz)

func center() -> Vector3:
	return Vector3(origin.x + float(nx - 1) * CELL * 0.5, base_y, origin.y + float(nz - 1) * CELL * 0.5)

func half_extent() -> float:
	return maxf(float(nx), float(nz)) * CELL * 0.5

# ================================================================ Mesh

## Gelaende-Mesh. Vertex-Farbe: r = Abstand zur Bahn (0..1 auf 60 m), g = Schlucht/Ufer.
func make_mesh(material: Material) -> MeshInstance3D:
	var n: int = nx * nz
	var verts := PackedVector3Array()
	verts.resize(n)
	var norms := PackedVector3Array()
	norms.resize(n)
	var cols := PackedColorArray()
	cols.resize(n)
	var uvs := PackedVector2Array()
	uvs.resize(n)
	for iz in nz:
		for ix in nx:
			var c: int = iz * nx + ix
			verts[c] = world_pos(ix, iz)
			norms[c] = normal_at_index(ix, iz)
			cols[c] = Color(clampf(track_dist[c] / 60.0, 0.0, 1.0), wet[c], 0.0)
			uvs[c] = Vector2(verts[c].x, verts[c].z)
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var k: int = 0
	for iz in nz - 1:
		for ix in nx - 1:
			var c: int = iz * nx + ix
			# Diagonale entlang der kleineren Hoehendifferenz (weniger Zacken an Klippen)
			if absf(heights[c] - heights[c + nx + 1]) < absf(heights[c + 1] - heights[c + nx]):
				idx[k] = c
				idx[k + 1] = c + 1
				idx[k + 2] = c + nx + 1
				idx[k + 3] = c
				idx[k + 4] = c + nx + 1
				idx[k + 5] = c + nx
			else:
				idx[k] = c
				idx[k + 1] = c + 1
				idx[k + 2] = c + nx
				idx[k + 3] = c + 1
				idx[k + 4] = c + nx + 1
				idx[k + 5] = c + nx
			k += 6
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	# Das Tal wirft keine Schatten auf die Bahn (Hangschattierung kommt aus dem Licht-Winkel)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
