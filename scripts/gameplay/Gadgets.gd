class_name Gadgets
extends RefCounted
## Alle Feld-Gadgets der Bahnen als innere Klassen. Jedes Gadget baut seine Optik selbst
## und wirkt ueber affect() identisch auf echte Baelle und auf die Flugbahn-Simulation.

const BALL_R := 0.3

static func gravity() -> float:
	return float(ProjectSettings.get_setting("physics/3d/default_gravity", 20.0))

# ================================================================ Boost-Pad

## Speed-Booster: setzt die Geschwindigkeit in Pfeilrichtung (-Z des Gadgets) auf mindestens `speed`.
class BoostPad extends Gadget:
	var half: Vector3
	var speed: float

	func _init(pad_width: float = 3.0, pad_length: float = 3.0, target_speed: float = 24.0, color: Color = Color(0.2, 0.9, 1.0)) -> void:
		half = Vector3(pad_width * 0.5, 0.9, pad_length * 0.5)
		speed = target_speed
		var mat := Mat.shader("booster", {"arrow": color, "base": color.darkened(0.85)})
		var mi := Mat.plane(Vector2(pad_width, pad_length), mat, Vector3(0.0, 0.03, 0.0))
		mi.rotation.y = PI
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	func affect(st: SimState, _dt: float) -> void:
		if st.on_cooldown(self):
			return
		var l := to_local_point(st.pos)
		if absf(l.x) > half.x or absf(l.z) > half.z or l.y < 0.0 or l.y > half.y:
			return
		var dir: Vector3 = -global_transform.basis.z
		var along: float = st.vel.dot(dir)
		st.vel = dir * maxf(speed, along)
		st.set_cooldown(self, 0.6)
		st.events.append("boost")

# ================================================================ Windzone / Ventilator

## Ventilator: beschleunigt Baelle im Quader vor dem Ventilator in Blasrichtung (-Z).
class WindZone extends Gadget:
	var half: Vector3
	var strength: float
	var _rotor: Node3D

	## zone = Breite, Hoehe, Laenge (Laenge in Blasrichtung, beginnt am Ventilator).
	func _init(zone: Vector3 = Vector3(5.0, 3.0, 10.0), accel: float = 14.0, color: Color = Color(0.8, 0.95, 1.0)) -> void:
		half = zone * 0.5
		strength = accel
		var metal := Mat.flat(Color(0.35, 0.38, 0.42), 0.4, 0.7)
		var housing := Mat.torus(0.95, 1.2, metal, Vector3(0.0, 1.4, 0.0))
		housing.rotation.x = PI * 0.5
		add_child(housing)
		add_child(Mat.box(Vector3(0.25, 1.4, 0.25), metal, Vector3(0.0, 0.2, 0.0)))
		_rotor = Node3D.new()
		_rotor.position = Vector3(0.0, 1.4, 0.0)
		add_child(_rotor)
		for i in 3:
			var blade := Mat.box(Vector3(0.9, 0.22, 0.05), Mat.flat(Color(0.85, 0.85, 0.9), 0.3, 0.6), Vector3(0.5, 0.0, 0.0))
			var arm := Node3D.new()
			arm.rotation.z = TAU * float(i) / 3.0
			arm.add_child(blade)
			_rotor.add_child(arm)
		var streaks := Mat.particles({
			"amount": 28, "lifetime": zone.z / maxf(8.0, accel * 0.8), "direction": Vector3(0, 0, -1), "spread": 4.0,
			"speed": Vector2(maxf(8.0, accel * 0.8), maxf(10.0, accel)), "gravity": Vector3.ZERO, "size": 0.12,
			"scale": Vector2(0.5, 1.4), "emission_box": Vector3(half.x * 0.8, half.y * 0.6, 0.2), "local": true,
			"colors": [Color(color, 0.0), Color(color, 0.55), Color(color, 0.0)],
		})
		streaks.position = Vector3(0.0, half.y, -0.5)
		add_child(streaks)

	func _process(delta: float) -> void:
		_rotor.rotation.z += delta * 14.0

	func affect(st: SimState, dt: float) -> void:
		var l := to_local_point(st.pos)
		if absf(l.x) > half.x or l.y < -0.2 or l.y > half.y * 2.0 or l.z > 0.0 or l.z < -half.z * 2.0:
			return
		st.vel += -global_transform.basis.z * (strength * (1.0 - st.wind_resist) * dt)

# ================================================================ Sandbunker

class SandTrap extends Gadget:
	var half: Vector2
	var drag: float

	func _init(size: Vector2 = Vector2(3.0, 3.0), decel_factor: float = 4.5) -> void:
		half = size * 0.5
		drag = decel_factor
		# Sandflaeche mit Koernung und Rippeln, leicht gewoelbt, darum eine weiche Gras-Lippe
		var mat := Mat.shader("sand", {})
		var bowl := _bowl(28, 5)
		var mi := MeshInstance3D.new()
		mi.mesh = bowl
		mi.material_override = mat
		mi.scale = Vector3(half.x, 1.0, half.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var lip := Mat.torus(0.97, 1.09, Mat.flat(Color(0.3, 0.55, 0.22), 0.95), Vector3(0.0, 0.035, 0.0))
		lip.scale = Vector3(half.x, 0.55, half.y)
		lip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(lip)

	## Flache Schale: Rand auf Hoehe 0.05, Mitte etwas tiefer (rein optisch; die Kollision bleibt der Bahnboden).
	static func _bowl(segments: int, rings: int) -> ArrayMesh:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for r in rings:
			var r0: float = float(r) / float(rings)
			var r1: float = float(r + 1) / float(rings)
			var y0: float = 0.05 - 0.035 * (1.0 - r0 * r0)
			var y1: float = 0.05 - 0.035 * (1.0 - r1 * r1)
			for i in segments:
				var a0: float = TAU * float(i) / float(segments)
				var a1: float = TAU * float(i + 1) / float(segments)
				var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
				var p01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
				var p10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
				var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
				for v in [p00, p10, p11, p00, p11, p01]:
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(v.x, v.z))
					st.add_vertex(v)
		return st.commit()

	func affect(st: SimState, _dt: float) -> void:
		var l := to_local_point(st.pos)
		if l.y < -0.2 or l.y > 0.48:
			return
		var ex: float = l.x / half.x
		var ez: float = l.z / half.y
		if ex * ex + ez * ez > 1.0:
			return
		st.decel_mul = maxf(st.decel_mul, drag)
		# Aufsetzer im Sand: kein Abprall, der Ball bleibt fast liegen
		if st.vel.y > 0.6:
			st.vel = Vector3(st.vel.x * 0.5, 0.0, st.vel.z * 0.5)

# ================================================================ Rough (tiefes Gras)

## Tiefes Gras am Bahnrand: bremst rollende Baelle deutlich (schwaecher als Sand).
class RoughZone extends Gadget:
	var half: Vector2
	var drag: float

	func _init(size: Vector2 = Vector2(1.6, 4.0), decel_factor: float = 2.3, color: Color = Color(0.16, 0.4, 0.14)) -> void:
		half = size * 0.5
		drag = decel_factor
		var base := Mat.plane(size, Mat.flat(color.darkened(0.1), 1.0), Vector3(0.0, 0.015, 0.0))
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(base)
		# Grashalme (eine MultiMesh-Instanz)
		var blade := PrismMesh.new()
		blade.size = Vector3(0.07, 0.26, 0.02)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = blade
		var n: int = int(size.x * size.y * 22.0)
		mm.instance_count = n
		var rng := RandomNumberGenerator.new()
		rng.seed = int(size.x * 1000.0 + size.y * 37.0)
		for i in n:
			var p := Vector3(rng.randf_range(-half.x, half.x), 0.12, rng.randf_range(-half.y, half.y))
			var sc: float = rng.randf_range(0.7, 1.4)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.25, 0.25))
			mm.set_instance_transform(i, Transform3D(b.scaled(Vector3(1.0, sc, 1.0)), p + Vector3(0.0, 0.13 * (sc - 1.0), 0.0)))
			mm.set_instance_color(i, color.lightened(rng.randf_range(0.0, 0.35)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var bm := StandardMaterial3D.new()
		bm.vertex_color_use_as_albedo = true
		bm.roughness = 1.0
		bm.cull_mode = BaseMaterial3D.CULL_DISABLED
		mmi.material_override = bm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)

	func affect(st: SimState, _dt: float) -> void:
		var l := to_local_point(st.pos)
		if l.y < -0.2 or l.y > 0.5 or absf(l.x) > half.x or absf(l.z) > half.y:
			return
		st.decel_mul = maxf(st.decel_mul, drag)

# ================================================================ Bach quer ueber die Bahn

## Wasserlauf quer ueber die Bahn mit schmalem Holzsteg in der Mitte: wer seitlich hineinrollt, ist im Wasser.
## Darueber hinweg chippen geht immer (nur rollende/flache Baelle fallen hinein).
class Creek extends Gadget:
	var half_w: float
	var half_d: float
	var bridge_half: float
	var kind: String

	func _init(track_width: float = 5.0, depth: float = 1.4, bridge_width: float = 2.2, out_kind: String = "water") -> void:
		half_w = track_width * 0.5
		half_d = depth * 0.5
		bridge_half = bridge_width * 0.5
		kind = out_kind
		var water_mat: Material = Mat.shader("lava", {}) if kind == "lava" else Mat.shader("water", {"wave_height": 0.02, "wave_scale": 1.2, "speed": 2.0})
		var bank := Mat.flat(Color(0.36, 0.3, 0.24), 0.95)
		var side_w: float = half_w - bridge_half
		for sgn: float in [-1.0, 1.0]:
			var cx: float = sgn * (bridge_half + side_w * 0.5)
			var w := Mat.plane(Vector2(side_w, depth), water_mat, Vector3(cx, 0.03, 0.0))
			w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(w)
			for ez: float in [-1.0, 1.0]:
				var edge := Mat.box(Vector3(side_w, 0.05, 0.12), bank, Vector3(cx, 0.025, ez * (half_d + 0.03)))
				edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(edge)
			# ein paar Kiesel am Ufer
			for k in 3:
				var st := Mat.sphere(0.09 + 0.04 * float(k), Mat.flat(Color(0.6, 0.58, 0.55), 0.9), Vector3(cx + (float(k) - 1.0) * side_w * 0.3, 0.05, (half_d + 0.12) * (1.0 if k % 2 == 0 else -1.0)), 6)
				st.scale = Vector3(1.0, 0.55, 1.0)
				add_child(st)
		# Holzsteg (flach, rein optisch - der Bahnboden traegt)
		var plank := Mat.flat(Color(0.55, 0.38, 0.2), 0.85)
		for i in 5:
			var z: float = -half_d - 0.15 + (depth + 0.3) * float(i) / 4.0
			add_child(Mat.box(Vector3(bridge_half * 2.0, 0.05, 0.3), plank, Vector3(0.0, 0.03, z)))
		for sgn: float in [-1.0, 1.0]:
			add_child(Mat.box(Vector3(0.08, 0.06, depth + 0.5), plank.duplicate(), Vector3(sgn * (bridge_half - 0.04), 0.06, 0.0)))

	func affect(st: SimState, _dt: float) -> void:
		var l := to_local_point(st.pos)
		if l.y > 0.42 or l.y < -0.4 or absf(l.z) > half_d or absf(l.x) > half_w or absf(l.x) < bridge_half:
			return
		st.out_kind = kind

# ================================================================ Teleporter

## Portal: Ball, der den Eingang beruehrt, erscheint am Ausgang und fliegt in dessen -Z-Richtung weiter.
class Teleporter extends Gadget:
	var exit_xf: Transform3D
	var radius: float

	func _init(exit_transform: Transform3D = Transform3D.IDENTITY, color_a: Color = Color(0.2, 0.9, 1.0), color_b: Color = Color(0.9, 0.2, 1.0), portal_radius: float = 1.1) -> void:
		exit_xf = exit_transform
		radius = portal_radius
		add_child(_make_portal(color_a, color_b, portal_radius))

	func _ready() -> void:
		# Ausgangs-Portal (rein optisch) als Geschwister-Knoten im Weltraum platzieren
		var exit_node := _make_portal(Color(1.0, 0.6, 0.2), Color(1.0, 0.9, 0.3), radius)
		exit_node.top_level = true
		add_child(exit_node)
		exit_node.global_transform = exit_xf

	func _make_portal(color_a: Color, color_b: Color, r: float) -> Node3D:
		var root := Node3D.new()
		var ring := Mat.torus(r * 0.92, r * 1.08, Mat.glow(color_a, 3.0), Vector3(0.0, r, 0.0))
		ring.rotation.x = PI * 0.5
		root.add_child(ring)
		var disc := Mat.quad(Vector2(r * 2.0, r * 2.0), Mat.shader("portal", {"color_a": color_a, "color_b": color_b}), Vector3(0.0, r, 0.0))
		disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(disc)
		return root

	func affect(st: SimState, _dt: float) -> void:
		if st.on_cooldown(self):
			return
		var l := to_local_point(st.pos)
		# Fangzone: so breit und hoch wie der Portal-Ring (ein rollender Ball muss nicht exakt die Mitte treffen)
		if absf(l.z) > 0.45 or l.y < -0.2 or l.y > radius * 2.0 or absf(l.x) > radius:
			return
		var spd: float = maxf(st.vel.length(), 7.0)
		st.pos = exit_xf.origin + exit_xf.basis.y * (BALL_R + 0.05) - exit_xf.basis.z * 0.6
		st.vel = -exit_xf.basis.z * spd
		st.teleported = true
		st.set_cooldown(self, 1.0)
		st.events.append("teleport")

# ================================================================ Looping-Schiene

## Fuehrt den Ball sicher durch einen Looping (siehe TrackKit.loop). Bedingung: genug Tempo.
class LoopRail extends Gadget:
	var start_xf: Transform3D
	var radius: float
	var shift: float
	var half_width: float
	var min_speed: float

	func _init(info: Dictionary = {}) -> void:
		start_xf = info.get("start", Transform3D.IDENTITY)
		radius = float(info.get("radius", 4.0))
		shift = float(info.get("shift", 7.0))
		half_width = float(info.get("width", 5.0)) * 0.5
		min_speed = sqrt(5.0 * Gadgets.gravity() * radius) * 1.02

	func affect(st: SimState, _dt: float) -> void:
		if st.rail != null or st.on_cooldown(self):
			return
		var l: Vector3 = start_xf.affine_inverse() * st.pos
		if absf(l.x) > half_width or l.y < 0.0 or l.y > 1.2 or l.z > 1.5 or l.z < -1.0:
			return
		var fwd: Vector3 = -start_xf.basis.z
		if st.vel.dot(fwd) < min_speed:
			return
		st.rail = self
		st.rail_s = 0.0
		st.rail_speed = st.vel.length()
		st.events.append("rail_in")

	func rail_advance(st: SimState, dt: float) -> void:
		var g: float = Gadgets.gravity()
		var h: float = radius * (1.0 - cos(st.rail_s))
		var v: float = sqrt(maxf(st.rail_speed * st.rail_speed - 2.0 * g * h, g * radius))
		st.rail_s += v * dt / radius
		if st.rail_s >= TAU:
			var end_frame: Transform3D = TrackKit.loop_frame(start_xf, radius, shift, TAU)
			st.pos = end_frame.origin + end_frame.basis.y * BALL_R - end_frame.basis.z * 0.3
			st.vel = -end_frame.basis.z * (st.rail_speed * 0.97)
			st.rail = null
			st.grounded = true
			st.set_cooldown(self, 1.5)
			st.events.append("rail_out")
			return
		var f: Transform3D = TrackKit.loop_frame(start_xf, radius, shift, st.rail_s)
		st.pos = f.origin + f.basis.y * BALL_R
		st.vel = -f.basis.z * v
		st.grounded = true

# ================================================================ Kanone

## Kanonen-Katapult: faengt den Ball, zielt kurz und schiesst ihn mit fester Geschwindigkeit ab.
class Cannon extends Gadget:
	var launch_velocity: Vector3
	var capture_radius: float = 1.25
	var hold_time: float = 0.7
	var _barrel: Node3D

	## launch = Abschuss-Geschwindigkeit im Weltraum (siehe Gadgets.ballistic_velocity()).
	func _init(launch: Vector3 = Vector3(0, 12, -12)) -> void:
		launch_velocity = launch
		var dark := Mat.flat(Color(0.14, 0.14, 0.16), 0.45, 0.8)
		var wood := Mat.flat(Color(0.45, 0.28, 0.14), 0.9)
		add_child(Mat.box(Vector3(1.9, 0.5, 2.2), wood, Vector3(0.0, 0.25, 0.0)))
		for sx: float in [-1.0, 1.0]:
			var wheel := Mat.cylinder(0.55, 0.55, 0.25, wood, Vector3(sx * 1.05, 0.55, 0.3), 14)
			wheel.rotation.z = PI * 0.5
			add_child(wheel)
		_barrel = Node3D.new()
		_barrel.position = Vector3(0.0, 0.9, 0.0)
		add_child(_barrel)
		var tube := Mat.cylinder(0.62, 0.78, 2.8, dark, Vector3(0.0, 0.0, -0.9), 18)
		tube.rotation.x = -PI * 0.5
		_barrel.add_child(tube)
		var ring := Mat.torus(0.6, 0.82, Mat.flat(Color(0.75, 0.6, 0.2), 0.3, 0.9), Vector3(0.0, 0.0, -2.25))
		ring.rotation.x = PI * 0.5
		_barrel.add_child(ring)

	func _ready() -> void:
		# Rohr auf die Schussrichtung ausrichten
		var dir: Vector3 = launch_velocity.normalized()
		if dir.length() > 0.5:
			_barrel.look_at(_barrel.global_position + dir, Vector3.UP)

	func muzzle() -> Vector3:
		return global_position + Vector3.UP * 0.9 + launch_velocity.normalized() * 2.4

	func affect(st: SimState, dt: float) -> void:
		if st.held:
			if st.holder != self:
				return
			st.hold_left -= dt
			st.pos = global_position + Vector3.UP * 0.9
			st.vel = Vector3.ZERO
			if st.hold_left <= 0.0:
				release(st)
			return
		if st.on_cooldown(self):
			return
		if st.pos.distance_to(global_position + Vector3.UP * 0.5) > capture_radius:
			return
		st.held = true
		st.holder = self
		st.hold_left = hold_time
		st.pos = global_position + Vector3.UP * 0.9
		st.vel = Vector3.ZERO
		st.events.append("cannon_in")

	func release(st: SimState) -> void:
		st.held = false
		st.holder = null
		st.pos = muzzle()
		st.vel = launch_velocity
		st.teleported = true
		st.grounded = false
		st.set_cooldown(self, 2.0)
		st.events.append("cannon")

# ================================================================ Laser-Barriere

## Laser quer ueber die Bahn (entlang lokaler X-Achse). Periodisch an/aus; Beruehrung = zurueck zum letzten Ort.
class LaserGate extends Gadget:
	var half_span: float
	var period: float
	var duty: float
	var phase: float
	var course: Course3D
	var _beams: Array[MeshInstance3D] = []
	var _heights: Array[float] = [0.3, 0.75]

	func _init(span: float = 5.0, cycle: float = 3.0, on_fraction: float = 0.5, offset: float = 0.0, color: Color = Color(1.0, 0.15, 0.25)) -> void:
		half_span = span * 0.5
		period = cycle
		duty = on_fraction
		phase = offset
		var post_mat := Mat.flat(Color(0.12, 0.13, 0.18), 0.4, 0.8)
		for sx: float in [-1.0, 1.0]:
			add_child(Mat.box(Vector3(0.3, 1.3, 0.3), post_mat, Vector3(sx * (half_span + 0.15), 0.65, 0.0)))
			add_child(Mat.sphere(0.14, Mat.glow(color, 3.0), Vector3(sx * (half_span + 0.15), 1.4, 0.0), 10))
		for h in _heights:
			var beam := Mat.cylinder(0.05, 0.05, span, Mat.glow(color, 5.0, color), Vector3(0.0, h, 0.0), 8)
			beam.rotation.z = PI * 0.5
			beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(beam)
			_beams.append(beam)

	func is_on(t: float) -> bool:
		return fposmod(t + phase, period) < period * duty

	func _process(_delta: float) -> void:
		if course == null:
			return
		var on: bool = is_on(course.time)
		for b in _beams:
			b.visible = on

	func affect(st: SimState, _dt: float) -> void:
		if not is_on(st.time):
			return
		var l := to_local_point(st.pos)
		if absf(l.x) > half_span or absf(l.z) > BALL_R + 0.06:
			return
		if l.y < _heights[_heights.size() - 1] + BALL_R + 0.05 and l.y > -0.2:
			st.out_kind = "laser"

# ================================================================ Kill-Zone

## Quader, in dem der Ball sofort "out" ist (z.B. Lava-Becken auf der Bahn).
class KillBox extends Gadget:
	var half: Vector3
	var kind: String

	func _init(size: Vector3 = Vector3(4, 2, 4), out_kind: String = "lava") -> void:
		half = size * 0.5
		kind = out_kind

	func affect(st: SimState, _dt: float) -> void:
		if in_local_box(st.pos, half):
			st.out_kind = kind

# ================================================================ Abkuerzung: Sprungschanze + Landezone

## Sprungschanze am Ende eines Abkuerzungs-Stegs: Ein Ball, der mit Schwung (>= min_speed in Steg-Richtung)
## ankommt, fliegt auf einer festen Parabel zur Landezone auf dem Gruen. Zu langsam: er rollt ueber die Kante (Aus).
class Launcher extends Gadget:
	var half: Vector3
	var target: Vector3
	var elevation: float
	var min_speed: float
	var catcher: Gadget = null

	func _init(zone: Vector3 = Vector3(2.2, 2.0, 1.8), target_pos: Vector3 = Vector3.ZERO, elevation_deg: float = 42.0, need_speed: float = 3.0, color: Color = Color(1.0, 0.8, 0.2)) -> void:
		half = zone * 0.5
		target = target_pos
		elevation = elevation_deg
		min_speed = need_speed
		# Optik: rundes Sprungpad (Feder-Pilz) mit leuchtendem Ring und Pfeilen - schiesst in jede Richtung
		var base_mat := Mat.flat(Color(0.3, 0.22, 0.14), 0.8)
		add_child(Mat.cylinder(0.95, 1.05, 0.14, base_mat, Vector3(0.0, 0.07, 0.0), 20))
		var ring := Mat.torus(0.82, 0.95, Mat.glow(color, 2.2))
		ring.position = Vector3(0.0, 0.15, 0.0)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		var pad := Mat.plane(Vector2(1.3, 1.3), Mat.shader("booster", {"arrow": color, "base": color.darkened(0.85)}), Vector3(0.0, 0.16, 0.0))
		pad.rotation.y = PI
		pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pad)
		for i in 4:
			var a: float = TAU * float(i) / 4.0 + PI * 0.25
			add_child(Mat.cylinder(0.05, 0.05, 0.3, Mat.flat(Color(0.75, 0.75, 0.8), 0.3, 0.8), Vector3(cos(a) * 0.7, -0.05, sin(a) * 0.7), 6))

	func affect(st: SimState, _dt: float) -> void:
		if st.on_cooldown(self):
			return
		var l := to_local_point(st.pos)
		if absf(l.x) > half.x or absf(l.z) > half.z or l.y < -0.2 or l.y > half.y:
			return
		var dir: Vector3 = -global_transform.basis.z
		if st.vel.dot(dir) < min_speed:
			return
		st.pos += Vector3.UP * 0.04
		var v: Vector3 = Gadgets.ballistic_velocity(st.pos, target + Vector3.UP * BALL_R, elevation)
		# Luftwiderstand ausgleichen (Ball3D/ShotSim daempfen im Flug um AIR_DAMP pro Sekunde)
		var hs: float = Vector2(v.x, v.z).length()
		var flight_t: float = Vector2(target.x - st.pos.x, target.z - st.pos.z).length() / maxf(1.0, hs)
		st.vel = v * (1.0 + Ball3D.AIR_DAMP * flight_t * 0.5)
		# ab jetzt Flug (wie bei der Kanone): Vorhersage und echter Ball rechnen in der Luft weiter
		st.teleported = true
		st.grounded = false
		st.set_cooldown(self, 1.0)
		if catcher != null:
			st.set_cooldown(catcher, 6.0)
		st.events.append("launch")

## Landezone auf dem Gruen: faengt einen von der Schanze kommenden Ball weich ab (wie starker Backspin),
## damit er auf dem Gruen bleibt. Wirkt nur, wenn die Schanze sie "scharf" geschaltet hat.
class LandingZone extends Gadget:
	var radius: float

	func _init(zone_radius: float = 4.0, color: Color = Color(1.0, 0.85, 0.2)) -> void:
		radius = zone_radius
		for i in 2:
			var ring := Mat.torus(radius * (0.55 + 0.4 * float(i)), radius * (0.55 + 0.4 * float(i)) + 0.09, Mat.glow(color, 1.2))
			ring.position = Vector3(0.0, 0.03, 0.0)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(ring)

	func affect(st: SimState, _dt: float) -> void:
		if not st.on_cooldown(self):
			return
		var l := to_local_point(st.pos)
		if l.x * l.x + l.z * l.z > radius * radius or l.y > 0.75 or l.y < -0.6 or st.vel.y > 0.0:
			return
		st.vel = Vector3(st.vel.x * 0.28, minf(st.vel.y, 0.0) * 0.2, st.vel.z * 0.28)
		st.cooldowns.erase(get_instance_id())
		st.events.append("land")

# ================================================================ Gelaende-Grenze (Aus)

## Beruehrt der Ball das Gelaende neben der Bahn (Randstreifen, Hang, Schlucht), ist er "aus".
## Analytisch ueber das Hoehenfeld - wirkt identisch fuer echte Baelle, Vorschau und Bots.
class TerrainBounds extends Gadget:
	var terrain: Terrain3D
	var hole: Vector3
	var hole_r2: float

	func _init(p_terrain: Terrain3D = null, hole_pos: Vector3 = Vector3.ZERO, hole_radius: float = 0.75) -> void:
		terrain = p_terrain
		hole = hole_pos
		hole_r2 = (hole_radius + 0.4) * (hole_radius + 0.4)

	func affect(st: SimState, _dt: float) -> void:
		if terrain == null:
			return
		if st.pos.y >= terrain.height_at(st.pos.x, st.pos.z) + 0.15:
			return
		var dx: float = st.pos.x - hole.x
		var dz: float = st.pos.z - hole.z
		if dx * dx + dz * dz < hole_r2:
			return
		st.out_kind = "ob"

# ================================================================ Helfer

## Geschwindigkeit, um von `from` nach `to` mit Abschusswinkel `elevation_deg` zu fliegen (ohne Luftwiderstand).
static func ballistic_velocity(from: Vector3, to: Vector3, elevation_deg: float) -> Vector3:
	var g: float = gravity()
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var d: float = flat.length()
	if d < 0.01:
		return Vector3.UP * 10.0
	var dy: float = to.y - from.y
	var th: float = deg_to_rad(elevation_deg)
	var denom: float = 2.0 * cos(th) * cos(th) * (d * tan(th) - dy)
	if denom <= 0.001:
		th = deg_to_rad(60.0)
		denom = maxf(0.001, 2.0 * cos(th) * cos(th) * (d * tan(th) - dy))
	var v: float = sqrt(g * d * d / denom)
	return flat.normalized() * (v * cos(th)) + Vector3.UP * (v * sin(th))
