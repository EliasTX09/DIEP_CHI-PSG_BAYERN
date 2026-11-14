class_name TrackKit
extends RefCounted
## Parametrischer 3D-Bahn-Baukasten ("Turtle"): extrudiert einen Bahn-Querschnitt (Belag, Banden,
## Unterbau) entlang eines Pfades und erzeugt daraus Mesh + Kollision.
## Bausteine: straight, slope, hill, kicker/crest, turn (mit Steilkurve), taper, gap (Sprung),
## loop (360-Grad-Looping), green (Gruen mit echtem Loch), box (freie Quader).
##
## Konvention der Turtle `xf`: Ursprung auf der Belag-Oberflaeche in Bahnmitte, -Z = Fahrtrichtung, +Y = oben.

const WIDTH := 5.0
const WALL_H := 0.55
const WALL_T := 0.35
const SLAB := 0.6
const BALL_R := 0.3
const HOLE_TILE := 1.5          # halbe Kantenlaenge der Loch-Kachel
const HOLE_SEGMENTS := 32

enum { S_FLOOR, S_TRIM, S_GREEN, S_ALT, S_DARK, S_COUNT }
enum { C_NONE, C_FLOOR, C_WALL }
enum { E_SIDE, E_WALLTOP, E_WALLIN, E_FLOOR, E_UNDER }

var course: Course3D
var xf: Transform3D = Transform3D.IDENTITY
var width: float = WIDTH
var wall_l: bool = true
var wall_r: bool = true
var wall_h: float = WALL_H
var dist: float = 0.0
var floor_surface: int = S_FLOOR

var _verts: Array[PackedVector3Array] = []
var _norms: Array[PackedVector3Array] = []
var _uvs: Array[PackedVector2Array] = []
var _col_floor: PackedVector3Array = PackedVector3Array()
var _col_wall: PackedVector3Array = PackedVector3Array()
var _in_run: bool = false
## Stellen, an denen die Deko Stuetzpfeiler unter die Bahn setzen darf.
var supports: PackedVector3Array = PackedVector3Array()
var _support_acc: float = 6.0
## Nebenstrang (z.B. Abkuerzung): erweitert weder Mittellinie noch Stuetzen/Bounds der Bahn.
var branch: bool = false

func _init(target: Course3D) -> void:
	course = target
	for i in S_COUNT:
		_verts.append(PackedVector3Array())
		_norms.append(PackedVector3Array())
		_uvs.append(PackedVector2Array())

# ================================================================ Dreiecke

## Dreieck mit automatischer Ausrichtung: `n` ist die gewuenschte Aussen-Normale.
func tri(surface: int, col: int, a: Vector3, b: Vector3, c: Vector3, n: Vector3,
		uva: Vector2 = Vector2.ZERO, uvb: Vector2 = Vector2.ZERO, uvc: Vector2 = Vector2.ZERO,
		na: Vector3 = Vector3.ZERO, nb: Vector3 = Vector3.ZERO, nc: Vector3 = Vector3.ZERO) -> void:
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
	# Godot: Vorderseite = Uhrzeigersinn. (c-a)x(b-a) zeigt dann zum Betrachter.
	if (c - a).cross(b - a).dot(n) < 0.0:
		var tp: Vector3 = b
		b = c
		c = tp
		var tu: Vector2 = uvb
		uvb = uvc
		uvc = tu
		var tn: Vector3 = nb
		nb = nc
		nc = tn
	if surface >= 0:
		var v: PackedVector3Array = _verts[surface]
		v.append(a)
		v.append(b)
		v.append(c)
		_verts[surface] = v
		var nn: PackedVector3Array = _norms[surface]
		nn.append(na)
		nn.append(nb)
		nn.append(nc)
		_norms[surface] = nn
		var uu: PackedVector2Array = _uvs[surface]
		uu.append(uva)
		uu.append(uvb)
		uu.append(uvc)
		_uvs[surface] = uu
	if col == C_FLOOR:
		_col_floor.append(a)
		_col_floor.append(b)
		_col_floor.append(c)
	elif col == C_WALL:
		_col_wall.append(a)
		_col_wall.append(b)
		_col_wall.append(c)

func quad(surface: int, col: int, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
		uva: Vector2 = Vector2.ZERO, uvb: Vector2 = Vector2.ZERO, uvc: Vector2 = Vector2.ZERO, uvd: Vector2 = Vector2.ZERO,
		na: Vector3 = Vector3.ZERO, nb: Vector3 = Vector3.ZERO, nc: Vector3 = Vector3.ZERO, nd: Vector3 = Vector3.ZERO) -> void:
	if na == Vector3.ZERO:
		na = n
		nb = n
		nc = n
		nd = n
	tri(surface, col, a, b, c, n, uva, uvb, uvc, na, nb, nc)
	tri(surface, col, a, c, d, n, uva, uvc, uvd, na, nc, nd)

## Quader im Weltraum (T = Mittelpunkt + Ausrichtung).
func box_world(t: Transform3D, size: Vector3, surface: int = S_TRIM, col: int = C_WALL) -> void:
	var h := size * 0.5
	var axes: Array[Vector3] = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for axis in 3:
		for sgn: float in [-1.0, 1.0]:
			var nrm: Vector3 = axes[axis] * sgn
			var u: Vector3 = axes[(axis + 1) % 3]
			var w: Vector3 = axes[(axis + 2) % 3]
			var hu: float = h[(axis + 1) % 3]
			var hw: float = h[(axis + 2) % 3]
			var center: Vector3 = nrm * h[axis]
			var p0: Vector3 = t * (center - u * hu - w * hw)
			var p1: Vector3 = t * (center + u * hu - w * hw)
			var p2: Vector3 = t * (center + u * hu + w * hw)
			var p3: Vector3 = t * (center - u * hu + w * hw)
			quad(surface, col, p0, p1, p2, p3, t.basis * nrm,
				Vector2(-hu, -hw), Vector2(hu, -hw), Vector2(hu, hw), Vector2(-hu, hw))

## Quader relativ zur Turtle (local = Mittelpunkt im Turtle-Raum).
func box(local: Transform3D, size: Vector3, surface: int = S_TRIM, col: int = C_WALL) -> void:
	box_world(xf * local, size, surface, col)

# ================================================================ Querschnitt

func _profile(half: float) -> Array:
	var pts := PackedVector2Array()
	var kinds := PackedInt32Array()
	if wall_l:
		pts.append(Vector2(-half - WALL_T, -SLAB))
		kinds.append(E_SIDE)
		pts.append(Vector2(-half - WALL_T, wall_h))
		kinds.append(E_WALLTOP)
		pts.append(Vector2(-half, wall_h))
		kinds.append(E_WALLIN)
	else:
		pts.append(Vector2(-half, -SLAB))
		kinds.append(E_SIDE)
	pts.append(Vector2(-half, 0.0))
	kinds.append(E_FLOOR)
	pts.append(Vector2(half, 0.0))
	if wall_r:
		kinds.append(E_WALLIN)
		pts.append(Vector2(half, wall_h))
		kinds.append(E_WALLTOP)
		pts.append(Vector2(half + WALL_T, wall_h))
		kinds.append(E_SIDE)
		pts.append(Vector2(half + WALL_T, -SLAB))
	else:
		kinds.append(E_SIDE)
		pts.append(Vector2(half, -SLAB))
	kinds.append(E_UNDER)
	return [pts, kinds]

## Belag-Proben quer ueber die Bahn (Grundlage fuer das Gelaende; Kanten ohne Bande werden markiert).
func _sample_frame(f: Transform3D, half: float) -> void:
	var n: int = maxi(1, int(ceil(half * 2.0 / 1.8)))
	for j in n + 1:
		var x: float = -half + half * 2.0 * float(j) / float(n)
		var open_edge: bool = (j == 0 and not wall_l) or (j == n and not wall_r) or (j > 0 and j < n and not wall_l and not wall_r)
		course.add_surface_sample(f * Vector3(x, 0.0, 0.0), open_edge)

func _emit_ribbon(frames: Array[Transform3D], dists: PackedFloat32Array, widths: PackedFloat32Array = PackedFloat32Array()) -> void:
	for i in frames.size():
		_sample_frame(frames[i], (widths[i] if widths.size() > i else width) * 0.5)
	for i in frames.size() - 1:
		var fa: Transform3D = frames[i]
		var fb: Transform3D = frames[i + 1]
		var ha: float = (widths[i] if widths.size() > i else width) * 0.5
		var hb: float = (widths[i + 1] if widths.size() > i + 1 else width) * 0.5
		var pa: Array = _profile(ha)
		var pb: Array = _profile(hb)
		var pts_a: PackedVector2Array = pa[0]
		var pts_b: PackedVector2Array = pb[0]
		var kinds: PackedInt32Array = pa[1]
		var n: int = pts_a.size()
		for e in n:
			var a0: Vector2 = pts_a[e]
			var a1: Vector2 = pts_a[(e + 1) % n]
			var b0: Vector2 = pts_b[e]
			var b1: Vector2 = pts_b[(e + 1) % n]
			var d2: Vector2 = a1 - a0
			var n2: Vector2 = Vector2(-d2.y, d2.x).normalized()
			var va0: Vector3 = fa * Vector3(a0.x, a0.y, 0.0)
			var va1: Vector3 = fa * Vector3(a1.x, a1.y, 0.0)
			var vb0: Vector3 = fb * Vector3(b0.x, b0.y, 0.0)
			var vb1: Vector3 = fb * Vector3(b1.x, b1.y, 0.0)
			var na: Vector3 = fa.basis * Vector3(n2.x, n2.y, 0.0)
			var nb: Vector3 = fb.basis * Vector3(n2.x, n2.y, 0.0)
			var surface: int = S_TRIM
			var col: int = C_FLOOR
			var kind: int = kinds[e]
			if kind == E_FLOOR:
				surface = floor_surface
			elif kind == E_WALLIN or kind == E_WALLTOP:
				col = C_WALL
			elif kind == E_UNDER:
				surface = S_DARK
			var ua0 := Vector2(a0.x, dists[i])
			var ua1 := Vector2(a1.x, dists[i])
			var ub0 := Vector2(b0.x, dists[i + 1])
			var ub1 := Vector2(b1.x, dists[i + 1])
			if kind != E_FLOOR:
				ua0.x = a0.x + a0.y
				ua1.x = a1.x + a1.y
				ub0.x = b0.x + b0.y
				ub1.x = b1.x + b1.y
			quad(surface, col, va0, vb0, vb1, va1, (na + nb) * 0.5, ua0, ub0, ub1, ua1, na, nb, nb, na)

func _emit_cap(f: Transform3D, half: float, facing_back: bool) -> void:
	var prof: Array = _profile(half)
	var pts: PackedVector2Array = prof[0]
	var idx: PackedInt32Array = Geometry2D.triangulate_polygon(pts)
	var nrm: Vector3 = f.basis.z if facing_back else -f.basis.z
	for i in range(0, idx.size() - 2, 3):
		var p0: Vector2 = pts[idx[i]]
		var p1: Vector2 = pts[idx[i + 1]]
		var p2: Vector2 = pts[idx[i + 2]]
		tri(S_TRIM, C_WALL, f * Vector3(p0.x, p0.y, 0.0), f * Vector3(p1.x, p1.y, 0.0), f * Vector3(p2.x, p2.y, 0.0), nrm, p0, p1, p2)

func _begin_run() -> void:
	if not _in_run:
		_in_run = true
		_emit_cap(xf, width * 0.5, true)

## Beendet den laufenden Bahn-Strang (setzt eine Abschlussflaeche).
func end_run() -> void:
	if _in_run:
		_in_run = false
		_emit_cap(xf, width * 0.5, false)

func _add_path(frames: Array[Transform3D], with_supports: bool = true) -> void:
	if branch:
		return
	var prev: Vector3 = frames[0].origin if frames.size() > 0 else Vector3.ZERO
	for f in frames:
		var p: Vector3 = f.origin + f.basis.y * BALL_R
		course.add_path_point(p)
		_support_acc += f.origin.distance_to(prev)
		prev = f.origin
		if with_supports and _support_acc >= 11.0 and f.basis.y.y > 0.97:
			_support_acc = 0.0
			supports.append(f.origin)
		course.expand_bounds(f.origin + f.basis.x * (width * 0.5 + 1.0))
		course.expand_bounds(f.origin - f.basis.x * (width * 0.5 + 1.0))
		course.expand_bounds(f.origin + Vector3.UP * 2.0)

# ================================================================ Profil-Einstellungen

func set_walls(left: bool, right: bool) -> TrackKit:
	if left != wall_l or right != wall_r:
		end_run()
		wall_l = left
		wall_r = right
	return self

func set_width(w: float) -> TrackKit:
	if absf(w - width) > 0.001:
		end_run()
		width = w
	return self

func set_wall_height(h: float) -> TrackKit:
	if absf(h - wall_h) > 0.001:
		end_run()
		wall_h = h
	return self

## Querwand hinter der Turtle (Bahn-Anfang) bzw. vor der Turtle (Sackgasse), je nach `ahead`.
func cross_wall(ahead: bool = true, height: float = -1.0) -> TrackKit:
	var h: float = height if height > 0.0 else wall_h
	var z: float = -WALL_T * 0.5 if ahead else WALL_T * 0.5
	if ahead:
		end_run()
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, (h - SLAB) * 0.5, z)), Vector3(width + WALL_T * 2.0, h + SLAB, WALL_T), S_TRIM, C_WALL)
	return self

func set_surface(surface: int) -> TrackKit:
	floor_surface = surface
	return self

# ================================================================ Bausteine

func start(t: Transform3D) -> TrackKit:
	end_run()
	xf = t.orthonormalized()
	return self

## Abschlag-Box: kurzes gerades Stueck mit Rueckwand; setzt course.tee.
func tee_box(length: float = 5.0) -> TrackKit:
	var back := Transform3D(Basis.IDENTITY, Vector3(0.0, (wall_h - SLAB) * 0.5, WALL_T * 0.5))
	box(back, Vector3(width + WALL_T * 2.0, wall_h + SLAB, WALL_T), S_TRIM, C_WALL)
	var tee_origin: Vector3 = xf * Vector3(0.0, BALL_R + 0.02, -length * 0.45)
	course.tee = Transform3D(xf.basis, tee_origin)
	straight(length)
	return self

func straight(length: float) -> TrackKit:
	if length <= 0.0:
		return self
	_begin_run()
	var frames: Array[Transform3D] = [xf]
	var dists := PackedFloat32Array([dist])
	var n: int = maxi(1, int(ceil(length / 2.5)))
	for i in range(1, n + 1):
		var s: float = length * float(i) / float(n)
		frames.append(xf.translated_local(Vector3(0.0, 0.0, -s)))
		dists.append(dist + s)
	_emit_ribbon(frames, dists)
	xf = frames[n]
	dist += length
	_add_path(frames)
	return self

## Weiche Rampe (S-Kurve): `rise` Meter hoch (negativ = bergab) auf `length` Metern.
func slope(length: float, rise: float) -> TrackKit:
	_begin_run()
	var frames: Array[Transform3D] = [xf]
	var dists := PackedFloat32Array([dist])
	var n: int = maxi(4, int(ceil(length / 0.8)))
	var prev: Vector3 = Vector3.ZERO
	var d: float = dist
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		var y: float = rise * (3.0 * t * t - 2.0 * t * t * t)
		var grade: float = rise * 6.0 * t * (1.0 - t) / length
		var local := Vector3(0.0, y, -length * t)
		d += local.distance_to(prev)
		prev = local
		frames.append(xf * Transform3D(Basis(Vector3.RIGHT, atan(grade)), local))
		dists.append(d)
	_emit_ribbon(frames, dists)
	xf = xf.translated_local(Vector3(0.0, rise, -length))
	dist = d
	_add_path(frames)
	return self

## Huegel/Bruecken-Bogen: geht `height` hoch und wieder zurueck.
func hill(length: float, height: float) -> TrackKit:
	_begin_run()
	var frames: Array[Transform3D] = [xf]
	var dists := PackedFloat32Array([dist])
	var n: int = maxi(6, int(ceil(length / 0.8)))
	var prev: Vector3 = Vector3.ZERO
	var d: float = dist
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		var sn: float = sin(PI * t)
		var y: float = height * sn * sn
		var grade: float = height * PI * sin(TAU * t) / length
		var local := Vector3(0.0, y, -length * t)
		d += local.distance_to(prev)
		prev = local
		frames.append(xf * Transform3D(Basis(Vector3.RIGHT, atan(grade)), local))
		dists.append(d)
	_emit_ribbon(frames, dists)
	xf = xf.translated_local(Vector3(0.0, 0.0, -length))
	dist = d
	_add_path(frames)
	return self

func _advance(ds: float, dyaw: float, dpitch: float) -> void:
	var ang: float = dyaw if absf(dyaw) > absf(dpitch) else dpitch
	var chord: float = ds
	if absf(ang) > 0.00001:
		chord = 2.0 * (ds / absf(ang)) * sin(absf(ang) * 0.5)
	var half := Basis(Vector3.UP, dyaw * 0.5) * Basis(Vector3.RIGHT, dpitch * 0.5)
	xf.basis = (xf.basis * half).orthonormalized()
	xf.origin += xf.basis * Vector3(0.0, 0.0, -chord)
	xf.basis = (xf.basis * half).orthonormalized()

func _arc(length: float, yaw: float, pitch: float, bank: float) -> void:
	_begin_run()
	var total: float = maxf(absf(yaw), absf(pitch))
	var n: int = maxi(2, int(ceil(maxf(rad_to_deg(total) / 3.0, length / 1.0))))
	var frames: Array[Transform3D] = [xf]
	var dists := PackedFloat32Array([dist])
	for i in range(1, n + 1):
		_advance(length / float(n), yaw / float(n), pitch / float(n))
		var t: float = float(i) / float(n)
		var roll: float = bank * smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(0.7, 1.0, t))
		frames.append(Transform3D(xf.basis * Basis(Vector3.BACK, roll), xf.origin))
		dists.append(dist + length * t)
	_emit_ribbon(frames, dists)
	dist += length
	_add_path(frames)

## Kurve: degrees > 0 = links, < 0 = rechts. bank_degrees neigt die Bahn zur Steilkurve.
func turn(degrees: float, radius: float, bank_degrees: float = 0.0) -> TrackKit:
	var yaw: float = deg_to_rad(degrees)
	_arc(absf(yaw) * radius, yaw, 0.0, signf(degrees) * deg_to_rad(bank_degrees))
	return self

## Wendel (Helix): Kurve um `degrees` (links > 0) mit Radius, die dabei `rise` Meter steigt (negativ = faellt).
## Die Turtle muss waagerecht stehen.
func spiral(degrees: float, radius: float, rise: float, bank_degrees: float = 0.0) -> TrackKit:
	_begin_run()
	var total: float = deg_to_rad(absf(degrees))
	var sgn: float = signf(degrees)
	var arc: float = total * radius
	var pitch: float = atan2(rise, arc)
	var n: int = maxi(4, int(ceil(absf(degrees) / 3.0)))
	var base: Transform3D = xf
	var center: Vector3 = base.origin - base.basis.x * (sgn * radius)
	var frames: Array[Transform3D] = [xf]
	var dists := PackedFloat32Array([dist])
	var length: float = sqrt(arc * arc + rise * rise)
	var bank: float = sgn * deg_to_rad(bank_degrees)
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		var th: float = total * t
		var pos: Vector3 = center + base.basis.x * (sgn * radius * cos(th)) - base.basis.z * (radius * sin(th)) + base.basis.y * (rise * t)
		var roll: float = bank * smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.85, 1.0, t))
		var pitch_now: float = pitch * smoothstep(0.0, 0.08, t) * (1.0 - smoothstep(0.92, 1.0, t))
		var b: Basis = base.basis * Basis(Vector3.UP, sgn * th) * Basis(Vector3.RIGHT, pitch_now) * Basis(Vector3.BACK, roll)
		frames.append(Transform3D(b, pos))
		dists.append(dist + length * t)
	_emit_ribbon(frames, dists)
	xf = Transform3D(base.basis * Basis(Vector3.UP, sgn * total), frames[n].origin)
	dist += length
	_add_path(frames, absf(rise) < 0.5)
	return self

## Schanze: die Bahn kruemmt sich um `degrees` nach oben (negativ: Kuppe nach unten).
func kicker(length: float, degrees: float) -> TrackKit:
	_arc(length, 0.0, deg_to_rad(degrees), 0.0)
	return self

## Trichter: Breite aendert sich fliessend.
func taper(length: float, new_width: float) -> TrackKit:
	_begin_run()
	var n: int = maxi(2, int(ceil(length / 1.5)))
	var frames: Array[Transform3D] = [xf]
	var dists := PackedFloat32Array([dist])
	var widths := PackedFloat32Array([width])
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		frames.append(xf.translated_local(Vector3(0.0, 0.0, -length * t)))
		dists.append(dist + length * t)
		widths.append(lerpf(width, new_width, t))
	_emit_ribbon(frames, dists, widths)
	xf = frames[n]
	dist += length
	width = new_width
	_add_path(frames)
	return self

## Richtet die Turtle waagerecht aus (z.B. nach einer Schanze).
func level() -> TrackKit:
	end_run()
	var fwd: Vector3 = -xf.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.001:
		fwd = Vector3.FORWARD
	xf.basis = Basis.looking_at(fwd.normalized(), Vector3.UP)
	return self

## Luecke (Sprung): beendet den Strang und setzt `length` Meter weiter vorn (und `drop` tiefer) neu an.
func gap(length: float, drop: float = 0.0, side: float = 0.0) -> TrackKit:
	var from: Vector3 = xf.origin + xf.basis.y * BALL_R
	level()
	xf.origin += xf.basis * Vector3(side, -drop, -length)
	var to: Vector3 = xf.origin + Vector3.UP * BALL_R
	course.add_corridor(from, to, width * 0.5 + 1.0)
	# Mittellinie ueber die Luecke als flacher Bogen (fuer Fortschritt/Bots)
	for i in range(1, 5):
		var t: float = float(i) / 5.0
		course.add_path_point(from.lerp(to, t) + Vector3.UP * (sin(PI * t) * length * 0.12))
	dist += length
	return self

## 360-Grad-Looping (Radius in m). Die Bahn versetzt sich dabei seitlich um `shift` (Standard: rechts).
## Der Ball wird per LoopRail-Gadget sicher durch den Looping gefuehrt, wenn er schnell genug ist.
func loop(radius: float, shift: float = 0.0) -> Dictionary:
	end_run()
	var was_l := wall_l
	var was_r := wall_r
	wall_l = true
	wall_r = true
	if absf(shift) < 0.01:
		shift = (width + WALL_T * 2.0) / 0.84 + 0.3
	var start_xf: Transform3D = xf
	_begin_run()
	var n: int = 96
	var frames: Array[Transform3D] = []
	var dists := PackedFloat32Array()
	var d: float = dist
	var prev: Vector3 = xf.origin
	for i in n + 1:
		var f: Transform3D = loop_frame(start_xf, radius, shift, TAU * float(i) / float(n))
		d += f.origin.distance_to(prev)
		prev = f.origin
		frames.append(f)
		dists.append(d)
	_emit_ribbon(frames, dists)
	xf = start_xf.translated_local(Vector3(shift, 0.0, 0.0))
	dist = d
	_add_path(frames, false)
	course.expand_bounds(start_xf * Vector3(0.0, radius * 2.0 + 1.0, 0.0))
	_in_run = true
	end_run()
	wall_l = was_l
	wall_r = was_r
	return {"start": start_xf, "radius": radius, "shift": shift, "width": width}

## Querschnitts-Rahmen des Loopings beim Winkel phi (0..TAU). Auch von LoopRail benutzt.
static func loop_frame(start_xf: Transform3D, radius: float, shift: float, phi: float) -> Transform3D:
	var f: Vector3 = -start_xf.basis.z
	var u: Vector3 = start_xf.basis.y
	var r: Vector3 = start_xf.basis.x
	var k: float = smoothstep(PI * 0.25, PI * 1.25, phi)
	var dk: float = 0.0
	if phi > PI * 0.25 and phi < PI * 1.25:
		var x: float = (phi - PI * 0.25) / PI
		dk = 6.0 * x * (1.0 - x) / PI
	var pos: Vector3 = start_xf.origin + f * (radius * sin(phi)) + u * (radius * (1.0 - cos(phi))) + r * (shift * k)
	var tangent: Vector3 = (f * (radius * cos(phi)) + u * (radius * sin(phi)) + r * (shift * dk)).normalized()
	var up: Vector3 = (-f * sin(phi) + u * cos(phi))
	up = (up - tangent * up.dot(tangent)).normalized()
	var right: Vector3 = tangent.cross(up).normalized()
	return Transform3D(Basis(right, up, -tangent), pos)

## Gruen mit echtem Loch (Becher). hole_dist = Abstand des Lochs vom Gruen-Anfang, hole_side = seitlicher Versatz.
func green(length: float = 12.0, gwidth: float = 9.0, hole_dist: float = -1.0, hole_side: float = 0.0) -> TrackKit:
	end_run()
	var hz: float = hole_dist if hole_dist > 0.0 else length * 0.62
	hz = clampf(hz, HOLE_TILE + 0.2, length - HOLE_TILE - 0.2)
	var hw: float = gwidth * 0.5
	var hx: float = clampf(hole_side, -hw + HOLE_TILE + 0.2, hw - HOLE_TILE - 0.2)
	var up: Vector3 = xf.basis.y
	var xs: Array[float] = [-hw, hx - HOLE_TILE, hx + HOLE_TILE, hw]
	var zs: Array[float] = [0.0, hz - HOLE_TILE, hz + HOLE_TILE, length]
	for ix in 3:
		for iz in 3:
			if ix == 1 and iz == 1:
				continue
			var x0: float = xs[ix]
			var x1: float = xs[ix + 1]
			var z0: float = zs[iz]
			var z1: float = zs[iz + 1]
			quad(S_GREEN, C_FLOOR,
				xf * Vector3(x0, 0.0, -z0), xf * Vector3(x0, 0.0, -z1), xf * Vector3(x1, 0.0, -z1), xf * Vector3(x1, 0.0, -z0), up,
				Vector2(x0, dist + z0), Vector2(x0, dist + z1), Vector2(x1, dist + z1), Vector2(x1, dist + z0))
	# Loch-Kachel: Ring zwischen Lochkreis und Quadrat
	var c := Vector3(hx, 0.0, -hz)
	var r: float = Course3D.HOLE_RADIUS
	var depth: float = Course3D.CUP_DEPTH
	for i in HOLE_SEGMENTS:
		var a0: float = TAU * float(i) / float(HOLE_SEGMENTS)
		var a1: float = TAU * float(i + 1) / float(HOLE_SEGMENTS)
		var d0 := Vector3(cos(a0), 0.0, sin(a0))
		var d1 := Vector3(cos(a1), 0.0, sin(a1))
		var o0: Vector3 = d0 / maxf(absf(d0.x), absf(d0.z)) * HOLE_TILE
		var o1: Vector3 = d1 / maxf(absf(d1.x), absf(d1.z)) * HOLE_TILE
		var i0: Vector3 = c + d0 * r
		var i1: Vector3 = c + d1 * r
		quad(S_GREEN, C_FLOOR, xf * i0, xf * (c + o0), xf * (c + o1), xf * i1, up,
			Vector2(i0.x, dist - i0.z), Vector2(c.x + o0.x, dist - c.z - o0.z), Vector2(c.x + o1.x, dist - c.z - o1.z), Vector2(i1.x, dist - i1.z))
		# Becherwand (Normale zeigt zur Lochachse) und Becherboden
		var down := Vector3(0.0, -depth, 0.0)
		var inward: Vector3 = xf.basis * (-(d0 + d1).normalized())
		quad(S_DARK, C_FLOOR, xf * i0, xf * i1, xf * (i1 + down), xf * (i0 + down), inward)
		tri(S_DARK, C_FLOOR, xf * (c + down), xf * (i0 + down), xf * (i1 + down), up)
	# Unterbau: Boden + Stirnseite (Seiten/Rueckseite verdecken die Banden)
	var sd: float = SLAB + 0.25
	quad(S_DARK, C_FLOOR, xf * Vector3(-hw, -sd, 0.0), xf * Vector3(hw, -sd, 0.0), xf * Vector3(hw, -sd, -length), xf * Vector3(-hw, -sd, -length), -up)
	quad(S_TRIM, C_FLOOR, xf * Vector3(-hw, -sd, 0.0), xf * Vector3(hw, -sd, 0.0), xf * Vector3(hw, 0.0, 0.0), xf * Vector3(-hw, 0.0, 0.0), xf.basis.z)
	# Banden rund ums Gruen
	var wh: float = wall_h + sd
	var wy: float = (wall_h - sd) * 0.5
	box(Transform3D(Basis.IDENTITY, Vector3(-hw - WALL_T * 0.5, wy, -length * 0.5)), Vector3(WALL_T, wh, length), S_TRIM, C_WALL)
	box(Transform3D(Basis.IDENTITY, Vector3(hw + WALL_T * 0.5, wy, -length * 0.5)), Vector3(WALL_T, wh, length), S_TRIM, C_WALL)
	box(Transform3D(Basis.IDENTITY, Vector3(0.0, wy, -length - WALL_T * 0.5)), Vector3(gwidth + WALL_T * 2.0, wh, WALL_T), S_TRIM, C_WALL)
	var open_half: float = width * 0.5 + WALL_T
	if hw - open_half > 0.05:
		var seg: float = hw - open_half
		var fy: float = wall_h * 0.5
		box(Transform3D(Basis.IDENTITY, Vector3(-open_half - seg * 0.5, fy, -WALL_T * 0.5)), Vector3(seg, wall_h, WALL_T), S_TRIM, C_WALL)
		box(Transform3D(Basis.IDENTITY, Vector3(open_half + seg * 0.5, fy, -WALL_T * 0.5)), Vector3(seg, wall_h, WALL_T), S_TRIM, C_WALL)
	# Belag-Proben ueber das ganze Gruen (fuer das Gelaende darunter)
	var gnx: int = int(ceil(gwidth / 1.5))
	var gnz: int = int(ceil(length / 1.5))
	for ix in gnx + 1:
		for iz in gnz + 1:
			course.add_surface_sample(xf * Vector3(-hw + gwidth * float(ix) / float(gnx), 0.0, -length * float(iz) / float(gnz)), false)
	course.hole_pos = xf * c
	course.hole_radius = r
	course.add_path_point(xf * Vector3(0.0, BALL_R, 0.0))
	course.add_path_point(xf * Vector3(hx * 0.5, BALL_R, -hz * 0.5))
	course.add_path_point(xf * Vector3(hx, BALL_R, -hz))
	for corner in [Vector3(-hw - 1.0, 0.0, 0.0), Vector3(hw + 1.0, 3.5, -length - 1.0)]:
		course.expand_bounds(xf * corner)
	xf = xf.translated_local(Vector3(0.0, 0.0, -length))
	dist += length
	return self

# ================================================================ Helfer fuer Platzierung

## Weltposition eines Punktes relativ zur Turtle.
func at(local: Vector3) -> Vector3:
	return xf * local

## Welt-Transform relativ zur Turtle.
func frame(local: Vector3 = Vector3.ZERO, yaw_degrees: float = 0.0) -> Transform3D:
	return xf * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), local)

func push_state() -> Dictionary:
	return {"xf": xf, "width": width, "wall_l": wall_l, "wall_r": wall_r, "dist": dist, "surface": floor_surface}

func pop_state(s: Dictionary) -> TrackKit:
	end_run()
	xf = s["xf"]
	width = float(s["width"])
	wall_l = bool(s["wall_l"])
	wall_r = bool(s["wall_r"])
	dist = float(s["dist"])
	floor_surface = int(s["surface"])
	return self

# ================================================================ Abschluss

## Erzeugt MeshInstance3D + Kollisionskoerper im Course3D. materials: Array[Material] mit S_COUNT Eintraegen.
func commit(materials: Array) -> void:
	end_run()
	var mesh := ArrayMesh.new()
	for s in S_COUNT:
		if _verts[s].is_empty():
			continue
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _verts[s]
		arrays[Mesh.ARRAY_NORMAL] = _norms[s]
		arrays[Mesh.ARRAY_TEX_UV] = _uvs[s]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mat: Material = materials[s] if s < materials.size() else null
		if mat != null:
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var mi := MeshInstance3D.new()
	mi.name = "TrackMesh"
	mi.mesh = mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	course.add_child(mi)
	course.floor_body = _make_body("FloorBody", _col_floor, 0.0)
	course.wall_body = _make_body("WallBody", _col_wall, 0.3)

func _make_body(body_name: String, faces: PackedVector3Array, bounce: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	body.collision_layer = 1
	body.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = bounce
	body.physics_material_override = pm
	if faces.size() >= 3:
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	course.add_child(body)
	return body
