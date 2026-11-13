extends Node3D
## Vorlaeufiges Geruest - wird in einem der naechsten Commits durch das komplette 3D-Hauptmenue ersetzt.

func _ready() -> void:
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 8)
	add_child(cam)
	cam.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	add_child(light)
	var mesh := MeshInstance3D.new()
	mesh.mesh = SphereMesh.new()
	add_child(mesh)
