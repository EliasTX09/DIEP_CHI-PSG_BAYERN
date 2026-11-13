class_name ClubModel
extends RefCounted
## Prozedurales 3D-Modell eines Golfschlaegers (Schaft, Griff, Kopf per CSG) je Kategorie und Seltenheit.
## Laenge ca. 1 Einheit; Ursprung in der Mitte des Schafts.

static func head_material(rarity: String) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.metallic = 0.85
	m.roughness = 0.28
	match rarity:
		"rare":
			m.albedo_color = Color(0.35, 0.6, 1.0)
		"epic":
			m.albedo_color = Color(0.7, 0.4, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.6, 0.3, 1.0)
			m.emission_energy_multiplier = 0.5
		"legendary":
			m.albedo_color = Color(1.0, 0.78, 0.25)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.7, 0.2)
			m.emission_energy_multiplier = 0.7
		_:
			m.albedo_color = Color(0.78, 0.8, 0.85)
	return m

static func make(club_id: String) -> Node3D:
	var category: String = Catalog.club_category(club_id)
	var rarity: String = Catalog.club_rarity(club_id)
	var root := Node3D.new()
	root.name = "Club"
	var shaft_mat := Mat.flat(Color(0.75, 0.78, 0.82), 0.3, 0.9)
	var accent: Color = Catalog.RARITY_COLORS.get(rarity, Color.WHITE)
	root.add_child(Mat.cylinder(0.011, 0.014, 0.86, shaft_mat, Vector3(0.0, 0.02, 0.0), 10))
	root.add_child(Mat.cylinder(0.02, 0.017, 0.26, Mat.flat(Color(0.08, 0.08, 0.1), 0.9), Vector3(0.0, 0.36, 0.0), 10))
	var ring := Mat.torus(0.014, 0.024, Mat.glow(accent, 1.6), Vector3(0.0, 0.21, 0.0))
	root.add_child(ring)
	var head := CSGCombiner3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, -0.43, 0.0)
	var mat := head_material(rarity)
	match category:
		"driver":
			var body := CSGSphere3D.new()
			body.radius = 0.1
			body.radial_segments = 16
			body.rings = 10
			body.material = mat
			head.add_child(body)
			head.scale = Vector3(1.25, 0.72, 1.0)
			var face := CSGBox3D.new()
			face.operation = CSGShape3D.OPERATION_SUBTRACTION
			face.size = Vector3(0.3, 0.3, 0.1)
			face.position = Vector3(0.0, 0.0, -0.12)
			head.add_child(face)
			head.position += Vector3(0.07, -0.01, 0.0)
		"iron":
			var blade := CSGBox3D.new()
			blade.size = Vector3(0.17, 0.09, 0.03)
			blade.material = mat
			head.add_child(blade)
			var cavity := CSGBox3D.new()
			cavity.operation = CSGShape3D.OPERATION_SUBTRACTION
			cavity.size = Vector3(0.12, 0.05, 0.03)
			cavity.position = Vector3(0.0, 0.0, 0.022)
			head.add_child(cavity)
			head.rotation = Vector3(deg_to_rad(-18.0), 0.0, 0.0)
			head.position += Vector3(0.07, 0.0, 0.0)
		"wedge":
			var plate := CSGBox3D.new()
			plate.size = Vector3(0.17, 0.11, 0.025)
			plate.material = mat
			head.add_child(plate)
			var sole := CSGCylinder3D.new()
			sole.radius = 0.035
			sole.height = 0.17
			sole.sides = 12
			sole.material = mat
			sole.rotation.z = PI * 0.5
			sole.position = Vector3(0.0, -0.05, 0.012)
			head.add_child(sole)
			head.rotation = Vector3(deg_to_rad(-42.0), 0.0, 0.0)
			head.position += Vector3(0.07, 0.01, 0.0)
		_:
			var putter := CSGBox3D.new()
			putter.size = Vector3(0.2, 0.05, 0.065)
			putter.material = mat
			head.add_child(putter)
			var notch := CSGBox3D.new()
			notch.operation = CSGShape3D.OPERATION_SUBTRACTION
			notch.size = Vector3(0.012, 0.03, 0.05)
			notch.position = Vector3(0.0, 0.025, 0.012)
			head.add_child(notch)
			head.position += Vector3(0.06, 0.0, 0.0)
	root.add_child(head)
	return root
