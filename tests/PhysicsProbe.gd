extends SceneTree
## Physik-Fingerabdruck fuer die CI:  godot --headless --script res://tests/PhysicsProbe.gd
## Laesst eine Kugel auf eine schraege Platte fallen und gibt nach 180 Ticks ihre Position aus.
## Jolt und GodotPhysics liefern unterschiedliche Nachkommastellen - damit laesst sich beweisen,
## welche Engine mit der Projekt-Einstellung wirklich rechnet.

var _root_node: Node3D
var _ball: RigidBody3D
var _ticks: int = 0

func _initialize() -> void:
	_root_node = Node3D.new()
	root.add_child(_root_node)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20.0, 1.0, 20.0)
	fs.shape = box
	floor_body.add_child(fs)
	floor_body.rotation = Vector3(0.21, 0.0, 0.13)
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.4
	pm.friction = 0.3
	floor_body.physics_material_override = pm
	_root_node.add_child(floor_body)
	_ball = RigidBody3D.new()
	var bs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.3
	bs.shape = sphere
	_ball.add_child(bs)
	_ball.position = Vector3(0.4, 4.0, -0.3)
	var bm := PhysicsMaterial.new()
	bm.bounce = 0.5
	bm.friction = 0.4
	_ball.physics_material_override = bm
	_root_node.add_child(_ball)
	_ball.linear_velocity = Vector3(1.5, 0.0, -2.0)

func _physics_process(_delta: float) -> bool:
	_ticks += 1
	if _ticks >= 180:
		var p: Vector3 = _ball.global_position
		print("PHYSICS ENGINE SETTING: ", ProjectSettings.get_setting("physics/3d/physics_engine"))
		print("PHYSICS FINGERPRINT: %.5f %.5f %.5f" % [p.x, p.y, p.z])
		return true
	return false
