class_name ShotSim
extends RefCounted
## Flugbahn-Simulation: rechnet einen Schlag mit denselben Regeln wie Ball3D voraus
## (Schwerkraft, Abpraller an Boden/Banden, Rollen ueber Rampen, Spin, Gadgets wie Boost,
## Wind, Teleporter, Looping-Schiene, Kanone). Genutzt fuer die 3D-Vorschau beim Zielen und
## fuer die Bot-KI (Bewertung von Kandidaten-Schlaegen).

const R := Ball3D.RADIUS

## Simuliert einen Schlag.
## opts: max_time (s), dt (s), spin (Vector2, bereits mit Schlaeger-Spin skaliert), chip (bool),
##       profile (Schlagprofil), sample (jeder n-te Schritt wird als Punkt gespeichert), ignore_moving (bool)
## Ergebnis: points, end_pos, end_vel, holed, out, out_kind, stopped, time, bounces, banks, first_impact, max_air
static func run(course: Course3D, space: PhysicsDirectSpaceState3D, start: Vector3, velocity: Vector3, opts: Dictionary = {}) -> Dictionary:
	var max_time: float = float(opts.get("max_time", 6.0))
	var dt: float = float(opts.get("dt", 1.0 / 60.0))
	var spin: Vector2 = opts.get("spin", Vector2.ZERO)
	var chip: bool = bool(opts.get("chip", false))
	var prof: Dictionary = opts.get("profile", {})
	var sample: int = maxi(1, int(opts.get("sample", 2)))
	var mask: int = 1 if bool(opts.get("ignore_moving", false)) else (1 | 4)
	var roll_bonus: float = 1.0 - float(prof.get("roll_bonus", 0.0))
	var e_floor: float = Ball3D.BOUNCE_FLOOR + float(prof.get("bounce_bonus", 0.0))
	var e_wall: float = minf(0.95, Ball3D.BOUNCE_WALL + float(prof.get("bounce_bonus", 0.0)))
	var gravity := Vector3(0.0, -Gadgets.gravity(), 0.0)

	var shape := SphereShape3D.new()
	shape.radius = R * 0.93
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = mask
	var rest_shape := SphereShape3D.new()
	rest_shape.radius = R * 1.08
	var rest_query := PhysicsShapeQueryParameters3D.new()
	rest_query.shape = rest_shape
	rest_query.collision_mask = mask
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = mask

	var st := SimState.new()
	st.is_sim = true
	st.wind_resist = float(prof.get("wind_resist", 0.0))
	var p: Vector3 = start
	var v: Vector3 = velocity
	var n := Vector3.UP
	var grounded: bool = not chip
	var roll_mul: float = Ball3D.roll_multiplier(spin.y, false) * roll_bonus
	var landed: bool = false
	var air: float = 0.0
	var max_air: float = 0.0
	var t: float = 0.0
	var t0: float = course.time
	var points := PackedVector3Array([p])
	var result := {"holed": false, "out": false, "out_kind": "", "stopped": false, "bounces": 0, "banks": 0,
		"first_impact": Vector3.INF, "max_air": 0.0}
	var steps: int = int(max_time / dt)
	var wall_id: int = course.wall_body.get_instance_id() if course.wall_body != null else 0
	var stop_timer: float = 0.0

	for step in steps:
		t += dt
		# --- Gadgets ---
		st.begin_tick(p, v, grounded, t0 + t, dt)
		if st.rail != null:
			st.rail.rail_advance(st, dt)
			p = st.pos
			v = st.vel
			grounded = true
			n = Vector3.UP
			if step % sample == 0:
				points.append(p)
			continue
		for g in course.gadgets:
			g.affect(st, dt)
		if st.out_kind != "":
			result["out"] = true
			result["out_kind"] = st.out_kind
			break
		p = st.pos
		v = st.vel
		if st.held:
			continue
		if st.teleported:
			grounded = st.grounded
			air = 0.0
			if step % sample == 0:
				points.append(p)
			continue

		# --- Side-Spin ---
		if absf(spin.x) > 0.01 and t < Ball3D.SPIN_FADE:
			var vh := Vector3(v.x, 0.0, v.z)
			var hs: float = vh.length()
			if hs > 1.0:
				var k: float = Ball3D.SIDE_ACCEL * spin.x * clampf(hs / 12.0, 0.0, 1.0) * (1.0 - t / Ball3D.SPIN_FADE)
				if grounded:
					k *= 0.45
				v += vh.normalized().cross(Vector3.UP) * (k * dt)

		if grounded:
			# --- Rollen auf der Flaeche ---
			var g_t: Vector3 = gravity - n * gravity.dot(n)
			v += g_t * dt
			v -= n * v.dot(n)
			var sp: float = v.length()
			if sp > 0.0001:
				var decel: float = (Ball3D.ROLL_DECEL + Ball3D.ROLL_DAMP * sp) * roll_mul * st.decel_mul
				v *= maxf(0.0, sp - decel * dt) / sp
			var motion: Vector3 = v * dt
			var lifted: Vector3 = p + n * 0.03
			if motion.length() > 0.00001:
				query.transform = Transform3D(Basis.IDENTITY, lifted)
				query.motion = motion
				var res: PackedFloat32Array = space.cast_motion(query)
				if res.size() == 2 and res[0] < 0.999:
					var hit_pos: Vector3 = lifted + motion * res[0]
					var hn: Vector3 = _contact_normal(space, rest_query, hit_pos + motion.normalized() * 0.05, n)
					if hn.y < 0.55:
						# Bande: abprallen
						var vn: float = v.dot(hn)
						if vn < 0.0:
							var e: float = e_wall if -vn > Ball3D.BOUNCE_MIN_SPEED else 0.0
							v -= hn * ((1.0 + e) * vn)
							if -vn > 3.0:
								result["banks"] = int(result["banks"]) + 1
							if result["first_impact"] == Vector3.INF:
								result["first_impact"] = hit_pos
						p = hit_pos - n * 0.03
					else:
						p += motion
				else:
					p += motion
			# Boden suchen (Rampen folgen, Kanten erkennen)
			ray.from = p + n * 0.2
			ray.to = p - n * (R + 0.2 + maxf(0.12, v.length() * dt * 0.8))
			var hit: Dictionary = space.intersect_ray(ray)
			if hit.is_empty():
				grounded = false
				air = 0.0
			else:
				var gnew: Vector3 = hit["normal"]
				var target: Vector3 = (hit["position"] as Vector3) + gnew * R
				# Abstand des Balls ueber der Flaeche: faellt der Boden schneller weg, als die Schwerkraft folgen kann -> Flug
				var gap_dist: float = (p - target).dot(gnew)
				if gnew.y < 0.3 or gap_dist > 0.5 * gravity.length() * dt * dt + 0.02:
					grounded = false
					air = 0.0
				else:
					p = target
					if gnew.dot(n) < 0.9995:
						var spd: float = v.length()
						var vt: Vector3 = v - gnew * v.dot(gnew)
						if vt.length() > 0.001:
							v = vt.normalized() * spd
					n = gnew
		else:
			# --- Flug ---
			v += gravity * dt
			v *= maxf(0.0, 1.0 - Ball3D.AIR_DAMP * dt)
			air += dt
			max_air = maxf(max_air, air)
			var motion2: Vector3 = v * dt
			query.transform = Transform3D(Basis.IDENTITY, p)
			query.motion = motion2
			var res2: PackedFloat32Array = space.cast_motion(query)
			if res2.size() == 2 and res2[0] < 0.999:
				var hit_pos2: Vector3 = p + motion2 * res2[0]
				var hn2: Vector3 = _contact_normal(space, rest_query, hit_pos2 + motion2.normalized() * 0.05, -motion2.normalized())
				var vn2: float = v.dot(hn2)
				p = hit_pos2
				if result["first_impact"] == Vector3.INF:
					result["first_impact"] = hit_pos2
				if vn2 < 0.0:
					var floor_like: bool = hn2.y > 0.55
					if floor_like and not landed and air > 0.25:
						landed = true
						if chip:
							var f: float = Ball3D.landing_factor(spin.y)
							v = Vector3(v.x * f, v.y, v.z * f)
							vn2 = v.dot(hn2)
							roll_mul = Ball3D.roll_multiplier(spin.y, true) * roll_bonus
					var bouncy: bool = -vn2 > Ball3D.BOUNCE_MIN_SPEED
					if floor_like:
						if bouncy:
							v -= hn2 * ((1.0 + e_floor) * vn2)
							result["bounces"] = int(result["bounces"]) + 1
						else:
							v -= hn2 * vn2
							grounded = true
							n = hn2
						air = 0.0
					else:
						var e2: float = e_wall if bouncy else 0.0
						v -= hn2 * ((1.0 + e2) * vn2)
						if -vn2 > 3.0:
							result["banks"] = int(result["banks"]) + 1
			else:
				p += motion2

		if step % sample == 0:
			points.append(p)
		# --- Loch / Out / Stillstand ---
		if _cup_capture(course, p, v, grounded):
			result["holed"] = true
			p = course.hole_pos
			break
		if p.y < course.kill_y:
			result["out"] = true
			result["out_kind"] = course.hazard
			break
		if grounded and v.length() < Ball3D.STOP_SPEED and n.y > 0.9:
			stop_timer += dt
			if stop_timer >= 0.15:
				result["stopped"] = true
				break
		else:
			stop_timer = 0.0

	points.append(p)
	result["points"] = points
	result["end_pos"] = p
	result["end_vel"] = v
	result["time"] = t
	result["max_air"] = max_air
	result["grounded"] = grounded
	return result

## Normale am Kontaktpunkt (zeigt vom Hindernis zur Kugel).
static func _contact_normal(space: PhysicsDirectSpaceState3D, rest_query: PhysicsShapeQueryParameters3D, center: Vector3, fallback: Vector3) -> Vector3:
	rest_query.transform = Transform3D(Basis.IDENTITY, center)
	var info: Dictionary = space.get_rest_info(rest_query)
	if info.is_empty():
		return fallback.normalized()
	var d: Vector3 = center - (info["point"] as Vector3)
	if d.length() > 0.01:
		return d.normalized()
	var nn: Vector3 = info["normal"]
	return nn.normalized() if nn.length() > 0.01 else fallback.normalized()

## Faellt der Ball ins Loch? (Naeherung der echten Becher-Physik: nah genug an der Lochmitte und nicht zu schnell.)
static func _cup_capture(course: Course3D, p: Vector3, v: Vector3, grounded: bool) -> bool:
	var dx: float = p.x - course.hole_pos.x
	var dz: float = p.z - course.hole_pos.z
	var d2: float = dx * dx + dz * dz
	var r: float = course.hole_radius
	if d2 > r * r or absf(p.y - course.hole_pos.y - R) > 0.5:
		return false
	if not grounded and v.y > 0.0:
		return false
	# Je mittiger der Ball das Loch trifft, desto schneller darf er sein.
	var chord: float = 2.0 * sqrt(maxf(0.0, r * r - d2))
	var hs: float = Vector2(v.x, v.z).length()
	return hs < 8.5 * chord / (2.0 * r) + 1.0

## Bequemer Helfer: komplette Vorhersage fuer einen Schlag aus Richtung/Kraft.
static func predict_shot(course: Course3D, space: PhysicsDirectSpaceState3D, from: Vector3, dir: Vector3, power: float, chip: bool,
		spin_raw: Vector2, prof: Dictionary, max_time: float, ground_n: Vector3 = Vector3.UP, sample: int = 2) -> Dictionary:
	var v: Vector3 = Ball3D.launch_velocity(dir, power, chip, prof, ground_n)
	var spin: Vector2 = Vector2(clampf(spin_raw.x, -1.0, 1.0), clampf(spin_raw.y, -1.0, 1.0)) * float(prof.get("spin", 0.6))
	return run(course, space, from, v, {"max_time": max_time, "spin": spin, "chip": chip, "profile": prof, "sample": sample})
