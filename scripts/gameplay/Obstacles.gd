class_name Obstacles
extends RefCounted
## Bewegliche, physische Hindernisse (AnimatableBody3D). Alle werden ueber die Bahn-Uhr
## angetrieben: update_time(t) setzt die Pose deterministisch -> gleiche Bewegung auf allen Geraeten.

const LAYER_OBSTACLE := 4   # Layer 3 "hindernisse": Windmuehle, Hammer, Schiebeblock
const LAYER_PLATFORM := 8   # Layer 4 "plattformen": fahrende Plattformen (zaehlen als Boden)

static func _body(bounce: float = 0.3) -> AnimatableBody3D:
	var b := AnimatableBody3D.new()
	b.collision_layer = LAYER_OBSTACLE
	b.collision_mask = 0
	b.sync_to_physics = false
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = bounce
	b.physics_material_override = pm
	return b

static func _add_box(body: Node3D, size: Vector3, pos: Vector3, material: Material) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	body.add_child(Mat.box(size, material, pos))

## Statischer Quader mit Kollision (Layer Welt) - z.B. Turm-Pfeiler, Felsen, Poller.
static func static_box(size: Vector3, material: Material, bounce: float = 0.3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = bounce
	b.physics_material_override = pm
	_add_box(b, size, Vector3.ZERO, material)
	return b

## Statischer Zylinder-Poller (Bumper) mit Kollision.
static func static_post(radius: float, height: float, material: Material, bounce: float = 0.45) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = bounce
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	cs.position = Vector3(0.0, height * 0.5, 0.0)
	b.add_child(cs)
	b.add_child(Mat.cylinder(radius, radius, height, material, Vector3(0.0, height * 0.5, 0.0), 16))
	return b

## Baumstamm, der quer ueber einen Teil der Bahn liegt (Kollision: liegender Zylinder). length = Laenge in m.
static func log_obstacle(length: float, radius: float = 0.32, dead: bool = false) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.35
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = length
	cs.shape = shape
	cs.position = Vector3(0.0, radius, 0.0)
	cs.rotation.z = PI * 0.5
	b.add_child(cs)
	var bark := Mat.flat(Color(0.16, 0.12, 0.1) if dead else Color(0.38, 0.25, 0.14), 0.95)
	var trunk := Mat.cylinder(radius, radius * 1.05, length, bark, Vector3(0.0, radius, 0.0), 12)
	trunk.rotation.z = PI * 0.5
	b.add_child(trunk)
	var cut := Mat.flat(Color(0.3, 0.2, 0.12) if dead else Color(0.82, 0.66, 0.42), 0.9)
	for sgn: float in [-1.0, 1.0]:
		var ring := Mat.cylinder(radius * 0.92, radius * 0.92, 0.02, cut, Vector3(sgn * length * 0.5, radius, 0.0), 12)
		ring.rotation.z = PI * 0.5
		b.add_child(ring)
	# Moos-Flecken und ein abgebrochener Ast
	if not dead:
		b.add_child(Mat.sphere(radius * 0.55, Mat.flat(Color(0.25, 0.5, 0.2), 0.95), Vector3(length * 0.2, radius * 1.75, 0.0), 8))
	var branch := Mat.cylinder(0.04, 0.08, 0.7, bark, Vector3(-length * 0.15, radius * 1.6, 0.1), 6)
	branch.rotation = Vector3(0.4, 0.0, -0.6)
	b.add_child(branch)
	return b

## Felsbrocken mit Kugel-Kollision (halb im Boden).
static func boulder(radius: float, tint: Color = Color(0.55, 0.52, 0.48)) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var pm := PhysicsMaterial.new()
	pm.friction = 0.0
	pm.bounce = 0.4
	b.physics_material_override = pm
	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	cs.shape = shape
	cs.position = Vector3(0.0, radius * 0.45, 0.0)
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	mi.mesh = Flora.boulder()
	var m := StandardMaterial3D.new()
	m.albedo_color = tint
	m.roughness = 0.95
	mi.material_override = m
	mi.scale = Vector3(radius * 1.08, radius * 1.15, radius * 1.08)
	mi.position = Vector3(0.0, radius * 0.45, 0.0)
	b.add_child(mi)
	return b

# ================================================================ Windmuehle

## Windmuehle ueber der Bahn: Turm mit Durchfahrt, vier Fluegel drehen sich quer durch die Durchfahrt.
## Lokales -Z = Bahnrichtung. Die Fluegel sperren die Durchfahrt periodisch.
class Windmill extends Node3D:
	var speed: float
	var phase: float
	var _rotor: AnimatableBody3D

	func _init(rot_speed: float = 1.4, start_phase: float = 0.0, tower_color: Color = Color(0.86, 0.8, 0.68), blade_color: Color = Color(0.75, 0.25, 0.2), gate_half: float = 1.3) -> void:
		speed = rot_speed
		phase = start_phase
		var stone := Mat.flat(tower_color, 0.9)
		var roof := Mat.flat(blade_color.darkened(0.2), 0.8)
		# Zwei Pfeiler links/rechts der Durchfahrt + Sturz darueber
		for sx: float in [-1.0, 1.0]:
			var pillar := Obstacles.static_box(Vector3(1.2, 3.2, 1.6), stone)
			pillar.position = Vector3(sx * (gate_half + 0.6), 1.6, 0.0)
			add_child(pillar)
		var lintel := Obstacles.static_box(Vector3(gate_half * 2.0 + 2.4, 1.4, 1.6), stone)
		lintel.position = Vector3(0.0, 3.9, 0.0)
		add_child(lintel)
		var cap := Mat.cylinder(0.0, 1.9, 1.8, roof, Vector3(0.0, 5.5, 0.0), 4)
		cap.rotation.y = PI * 0.25
		add_child(cap)
		# Rotor mit vier Fluegeln (dreht um die Bahnachse, vor dem Turm)
		_rotor = Obstacles._body(0.35)
		_rotor.position = Vector3(0.0, 3.0, 1.05)
		add_child(_rotor)
		var wood := Mat.flat(blade_color, 0.8)
		for i in 4:
			var arm := Node3D.new()
			arm.rotation.z = TAU * float(i) / 4.0
			_rotor.add_child(arm)
			var cs := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.7, 2.7, 0.25)
			cs.shape = shape
			cs.transform = Transform3D(Basis(Vector3.BACK, TAU * float(i) / 4.0), Basis(Vector3.BACK, TAU * float(i) / 4.0) * Vector3(0.0, -1.55, 0.0))
			_rotor.add_child(cs)
			arm.add_child(Mat.box(Vector3(0.7, 2.7, 0.12), wood, Vector3(0.0, -1.55, 0.0)))
		_rotor.add_child(Mat.cylinder(0.3, 0.3, 0.5, Mat.flat(Color(0.3, 0.2, 0.15)), Vector3.ZERO, 10))

	func update_time(t: float) -> void:
		_rotor.rotation.z = speed * t + phase

# ================================================================ Hammer

## Pendel-Hammer: schwingt quer ueber die Bahn (um die Bahnachse), Aufhaengung an einem Galgen.
class Hammer extends Node3D:
	var amplitude: float
	var omega: float
	var phase: float
	var _arm: AnimatableBody3D

	func _init(swing_degrees: float = 55.0, period: float = 2.6, start_phase: float = 0.0, pivot_height: float = 4.2, color: Color = Color(0.5, 0.5, 0.55)) -> void:
		amplitude = deg_to_rad(swing_degrees)
		omega = TAU / maxf(0.2, period)
		phase = start_phase
		var frame_mat := Mat.flat(Color(0.3, 0.22, 0.16), 0.9)
		for sx: float in [-1.0, 1.0]:
			add_child(Mat.box(Vector3(0.3, pivot_height + 0.3, 0.3), frame_mat, Vector3(sx * 3.3, (pivot_height + 0.3) * 0.5, 0.0)))
		add_child(Mat.box(Vector3(6.9, 0.3, 0.3), frame_mat, Vector3(0.0, pivot_height + 0.15, 0.0)))
		_arm = Obstacles._body(0.4)
		_arm.position = Vector3(0.0, pivot_height, 0.0)
		add_child(_arm)
		var head_y: float = -(pivot_height - 0.75)
		_arm.add_child(Mat.box(Vector3(0.18, pivot_height - 1.2, 0.18), frame_mat, Vector3(0.0, head_y * 0.5 + 0.2, 0.0)))
		Obstacles._add_box(_arm, Vector3(1.5, 1.1, 1.1), Vector3(0.0, head_y, 0.0), Mat.flat(color, 0.35, 0.8))

	func update_time(t: float) -> void:
		_arm.rotation.z = amplitude * sin(omega * t + phase)

# ================================================================ Schiebe-Block

## Steinblock, der quer (lokale X-Achse) ueber die Bahn hin- und herfaehrt.
class SlidingBlock extends Node3D:
	var travel: float
	var omega: float
	var phase: float
	var _block: AnimatableBody3D

	func _init(size: Vector3 = Vector3(1.6, 1.4, 1.6), half_travel: float = 1.6, period: float = 3.0, start_phase: float = 0.0, color: Color = Color(0.32, 0.28, 0.27)) -> void:
		travel = half_travel
		omega = TAU / maxf(0.2, period)
		phase = start_phase
		_block = Obstacles._body(0.35)
		add_child(_block)
		Obstacles._add_box(_block, size, Vector3(0.0, size.y * 0.5, 0.0), Mat.flat(color, 0.9))
		var glow_strip := Mat.box(Vector3(size.x * 1.02, 0.12, size.z * 1.02), Mat.glow(Color(1.0, 0.45, 0.1), 2.0), Vector3(0.0, size.y * 0.55, 0.0))
		_block.add_child(glow_strip)

	func update_time(t: float) -> void:
		_block.position.x = travel * sin(omega * t + phase)

# ================================================================ Bewegliche Plattform

## Plattform, die zwischen zwei lokalen Punkten pendelt. Baelle fahren darauf mit.
class MovingPlatform extends Node3D:
	var point_a: Vector3
	var point_b: Vector3
	var omega: float
	var phase: float
	var body: AnimatableBody3D

	func _init(size: Vector3 = Vector3(5.0, 0.5, 5.0), from: Vector3 = Vector3.ZERO, to: Vector3 = Vector3(0, 0, -8), period: float = 6.0, start_phase: float = 0.0, material: Material = null, rails: bool = true) -> void:
		point_a = from
		point_b = to
		omega = TAU / maxf(0.5, period)
		phase = start_phase
		body = Obstacles._body(0.0)
		body.collision_layer = Obstacles.LAYER_PLATFORM
		body.add_to_group("moving_floor")
		add_child(body)
		var mat: Material = material if material != null else Mat.flat(Color(0.55, 0.38, 0.22), 0.85)
		Obstacles._add_box(body, size, Vector3(0.0, -size.y * 0.5, 0.0), mat)
		if rails:
			var rail_mat := Mat.flat(Color(0.3, 0.2, 0.12), 0.9)
			for sx: float in [-1.0, 1.0]:
				Obstacles._add_box(body, Vector3(0.25, 0.5, size.z), Vector3(sx * (size.x * 0.5 - 0.125), 0.25, 0.0), rail_mat)

	func pose(t: float) -> Vector3:
		var k: float = 0.5 - 0.5 * cos(omega * t + phase)
		return point_a.lerp(point_b, k)

	func update_time(t: float) -> void:
		body.position = pose(t)
