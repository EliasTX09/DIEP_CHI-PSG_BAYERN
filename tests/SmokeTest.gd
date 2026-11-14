extends Node
## Headless-Smoke-Test fuer die CI:
##   godot --headless --fixed-fps 60 res://tests/Smoke.tscn
## Prueft Projekt-Einstellungen, kompiliert alle Skripte/Shader und testet die Spiel-Logik.
## Ergebniszeile: "SMOKE RESULT: PASS" bzw. "SMOKE RESULT: FAIL"; Exit-Code 0/1.

var _fails: PackedStringArray = PackedStringArray()
var _checks: int = 0

func _ready() -> void:
	await get_tree().process_frame
	print("[SMOKE] Start")
	_stage_environment()
	_stage_compile_all()
	_stage_catalog()
	_stage_game_manager()
	_stage_sound()
	await _stage_jolt_probe()
	await _stage_courses()
	await _stage_shortcuts()
	await _stage_hazards()
	await _stage_physics()
	await _stage_shadow_space()
	await _stage_bots()
	await _stage_match()
	await _stage_input()
	await _stage_daily()
	_stage_battle_pass()
	_stage_network_offline()
	_stage_auth_offline()
	await _stage_auth_mock()
	await _stage_menu()
	_finish()

func check(cond: bool, label: String) -> void:
	_checks += 1
	if not cond:
		_fails.append(label)
		print("[SMOKE][FAIL] ", label)

func _finish() -> void:
	if _fails.is_empty():
		print("SMOKE RESULT: PASS (%d Checks)" % _checks)
	else:
		print("SMOKE RESULT: FAIL (%d von %d Checks fehlgeschlagen)" % [_fails.size(), _checks])
		for f in _fails:
			print("  - ", f)
	get_tree().quit(0 if _fails.is_empty() else 1)

# ---------------------------------------------------------------- Umgebung

func _stage_environment() -> void:
	print("[SMOKE] Stage: Umgebung")
	var v := Engine.get_version_info()
	print("[SMOKE] Godot ", v["string"])
	print("[SMOKE] physics_engine (Setting) = ", ProjectSettings.get_setting("physics/3d/physics_engine"))
	print("[SMOKE] rendering_method = ", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	check(int(v["major"]) == 4 and int(v["minor"]) >= 5, "Godot >= 4.5")
	check(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "mobile", "Mobile-Renderer konfiguriert")
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR_PORTRAIT,
		"Orientierung = Sensor-Hochformat")
	check(int(ProjectSettings.get_setting("display/window/size/viewport_width")) < int(ProjectSettings.get_setting("display/window/size/viewport_height")),
		"Basis-Aufloesung ist hochkant")
	check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")) >= 1, "MSAA aktiv")
	check(Engine.physics_ticks_per_second == 120, "Physik-Takt 120 Hz")

# ---------------------------------------------------------------- Kompilieren

func _collect(dir_path: String, ext: String, out: PackedStringArray) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_collect(dir_path.path_join(f), ext, out)
		elif f.ends_with(ext):
			out.append(dir_path.path_join(f))
		f = d.get_next()
	d.list_dir_end()

func _stage_compile_all() -> void:
	print("[SMOKE] Stage: Skripte & Shader laden")
	var scripts := PackedStringArray()
	_collect("res://scripts", ".gd", scripts)
	_collect("res://tests", ".gd", scripts)
	check(scripts.size() >= 4, "Skripte gefunden")
	for p in scripts:
		var res: Resource = load(p)
		check(res is GDScript and (res as GDScript).can_instantiate(), "Skript kompiliert: " + p)
	var shaders := PackedStringArray()
	_collect("res://shaders", ".gdshader", shaders)
	for p in shaders:
		var sh: Resource = load(p)
		check(sh is Shader, "Shader geladen: " + p)
	var scenes := PackedStringArray()
	_collect("res://scenes", ".tscn", scenes)
	for p in scenes:
		var ps: Resource = load(p)
		check(ps is PackedScene, "Szene geladen: " + p)
	print("[SMOKE] %d Skripte, %d Shader, %d Szenen" % [scripts.size(), shaders.size(), scenes.size()])

# ---------------------------------------------------------------- Katalog

func _stage_catalog() -> void:
	print("[SMOKE] Stage: Katalog")
	var clubs := Catalog.club_ids()
	check(clubs.size() == 16, "16 Schlaeger (4 Kategorien x 4 Seltenheiten)")
	for id in clubs:
		check(Catalog.CLUB_NAMES.has(id), "Schlaeger hat Namen: " + id)
		var s1 := Catalog.club_stats(id, 1)
		var s2 := Catalog.club_stats(id, Catalog.club_max_level(id))
		for k in Catalog.STAT_KEYS:
			check(float(s2[k]) >= float(s1[k]) and float(s2[k]) <= 100.0, "Stat waechst mit Stufe: %s/%s" % [id, k])
	check(Catalog.BALL_ORDER.size() == 6 and Catalog.TRAIL_ORDER.size() == 6 and Catalog.EXPLOSION_ORDER.size() == 5,
		"6 Baelle, 6 Trails (inkl. 'kein'), 5 Loch-Explosionen")
	var all := Catalog.all_course_ids()
	check(all.size() == 15, "15 Bahnen im Katalog")
	var split: Array[int] = []
	for w in Catalog.WORLDS:
		split.append((w["courses"] as Array).size())
	check(split == [5, 4, 3, 3], "Bahnen verteilt 5/4/3/3 auf 4 Welten")
	for rounds in Catalog.ROUND_OPTIONS:
		for w in Catalog.world_ids():
			var list := Catalog.build_course_list(w, rounds, 1234)
			var uniq := {}
			for c in list:
				uniq[c] = true
			check(list.size() == rounds and uniq.size() == rounds, "Bahnliste %s/%d eindeutig" % [w, rounds])
			check(Catalog.world_of_course(list[0]) == w, "Bahnliste startet in gewaehlter Welt: " + w)
	check(Catalog.build_course_list("neon", 9, 5) == Catalog.build_course_list("neon", 9, 5), "Bahnliste deterministisch per Seed")
	check(Catalog.trophies_for_rank(1, 6) > 0 and Catalog.trophies_for_rank(6, 6) < 0, "Trophaeen: Sieg plus, Letzter minus")
	check(Catalog.league_for(0)["id"] == "bronze" and Catalog.league_for(2500)["id"] == "champion", "Ligen-Grenzen")

# ---------------------------------------------------------------- GameManager

func _stage_game_manager() -> void:
	print("[SMOKE] Stage: GameManager")
	var gm := GameManager
	gm.reset_progress()
	check(gm.coins() == 500 and gm.gems() == 30, "Startguthaben")
	check(gm.device_id().length() == 36, "Geraete-ID erzeugt")
	check(gm.owns_club(Catalog.START_CLUB) and gm.club_level(Catalog.START_CLUB) == 1, "Start-Schlaeger vorhanden")
	var prof := gm.shot_profile()
	for k in ["power", "scatter_deg", "spin", "guide", "loft_deg", "wind_resist", "roll_bonus", "bounce_bonus"]:
		check(prof.has(k), "Schlagprofil enthaelt " + k)
	# Upgrade
	gm.add_club_cards(Catalog.START_CLUB, 10)
	check(gm.can_upgrade_club(Catalog.START_CLUB), "Upgrade moeglich mit Karten + Coins")
	var before := gm.club_stats(Catalog.START_CLUB)
	check(gm.upgrade_club(Catalog.START_CLUB) and gm.club_level(Catalog.START_CLUB) == 2, "Upgrade auf Stufe 2")
	check(float(gm.club_stats(Catalog.START_CLUB)["power"]) > float(before["power"]), "Upgrade erhoeht Power")
	check(gm.coins() == 450, "Upgrade kostet Coins")
	# Neue Schlaeger ueber Karten
	gm.add_club_cards("driver_rare", 3)
	check(gm.owns_club("driver_rare") and gm.club_cards("driver_rare") == 2, "Erste Karte schaltet Schlaeger frei")
	check(gm.equip_club("driver_rare") and gm.equipped_club() == "driver_rare", "Schlaeger ausruesten")
	# Items
	gm.add_coins(5000)
	check(gm.buy_item("ball", "magma") and gm.owns("ball", "magma"), "Ball kaufen")
	check(gm.equip("ball", "magma") and gm.equipped("ball") == "magma", "Ball ausruesten")
	check(not gm.buy_item("ball", "magma"), "Doppelkauf verhindert")
	check(not gm.buy_item("explosion", "blackhole"), "Kauf ohne genug Gems verhindert")
	# Truhen
	check(gm.add_chest("wood") and gm.chest_state(0) == "locked", "Truhe in Slot 0")
	check(gm.add_chest("gold") and gm.chest_state(1) == "locked", "Truhe in Slot 1")
	check(gm.start_unlock(0) and gm.chest_state(0) == "unlocking", "Truhen-Timer startet")
	check(not gm.start_unlock(1), "Nur eine Truhe gleichzeitig entsperren")
	check(gm.chest_remaining(0) > 800.0 and gm.chest_gem_cost(0) >= 2, "Restzeit und Gem-Kosten")
	var gems_before := gm.gems()
	var loot := gm.open_chest(0, true)
	check(not loot.is_empty() and loot.has("coins") and loot.has("cards"), "Truhe mit Gems sofort geoeffnet")
	check(gm.gems() < gems_before + int(loot.get("gems", 0)) + 1 and gm.chest_state(0) == "empty", "Gems abgezogen, Slot frei")
	check(gm.open_chest(1, false).is_empty(), "Gesperrte Truhe oeffnet nicht gratis")
	for t in Catalog.CHEST_ORDER:
		var r := gm.roll_chest(t)
		var n := 0
		for id in (r["cards"] as Dictionary).keys():
			check(Catalog.CLUB_NAMES.has(id), "Truhen-Karte ist gueltiger Schlaeger")
			n += int(r["cards"][id])
		check(n > 0 and int(r["coins"]) > 0, "Truhe %s enthaelt Karten und Coins" % t)
	# Match-Belohnungen
	var cfg := gm.make_bot_match("emerald", 3, 3)
	check((cfg["players"] as Array).size() == 4 and (cfg["courses"] as Array).size() == 3, "Bot-Match-Konfiguration")
	gm.match_config = cfg
	var t0 := gm.trophies()
	var rew := gm.finish_match({"rank": 1, "players": 4, "style_points": 250, "holes_in_one": 1, "strokes": 7, "holes": 3})
	check(gm.trophies() == t0 + 30 and int(rew["coins"]) >= 120, "Sieg: +30 Trophaeen, Coins")
	var rew2 := gm.finish_match({"rank": 4, "players": 4, "style_points": 0, "strokes": 12, "holes": 3})
	check(int(rew2["trophies"]) < 0 and gm.trophies() >= 0, "Letzter Platz: Trophaeen-Abzug, nie negativ")
	# Trophaeen-Pfad
	gm.add_trophies(120)
	var claim := gm.claimable_road()
	check(claim.size() >= 1, "Trophaeen-Pfad: Belohnung abholbar")
	if claim.size() >= 1:
		var c0 := gm.coins()
		var got := gm.claim_road(claim[0])
		check(not got.is_empty() and gm.road_claimed(claim[0]) and gm.coins() >= c0, "Pfad-Belohnung abgeholt")
		check(gm.claim_road(claim[0]).is_empty(), "Pfad-Belohnung nur einmal")
	gm.add_trophies(400)
	check(gm.owns("frame", "silver"), "Liga-Rahmen freigeschaltet")
	# Daily
	check(gm.daily_available(), "Daily Challenge verfuegbar")
	var d := gm.finish_daily(2.0, false)
	check(int(d["coins"]) == 200 and not gm.daily_available(), "Daily abgeschlossen, heute gesperrt")
	check(gm.daily_seed() == gm.daily_seed(), "Daily-Seed stabil")
	check(gm.gift_available() and not gm.claim_gift().is_empty() and not gm.gift_available(), "Tagesgeschenk einmal pro Tag")
	# Speichern / Laden
	var coins_now := gm.coins()
	var lvl_now := gm.club_level(Catalog.START_CLUB)
	gm.save_game()
	gm.load_game()
	check(gm.coins() == coins_now and gm.club_level(Catalog.START_CLUB) == lvl_now and gm.owns("ball", "magma"),
		"Speicherstand uebersteht Speichern/Laden")
	check(gm.set_player_name("Testspieler") and gm.player_name() == "Testspieler" and not gm.set_player_name("x"), "Spielername setzen/validieren")
	gm.reset_progress()

# ---------------------------------------------------------------- Sound

func _stage_sound() -> void:
	print("[SMOKE] Stage: SoundManager")
	check(SoundManager.SOUNDS.size() >= 25, "Mindestens 25 prozedurale Sounds")
	check(SoundManager.self_test() == 0, "Alle Sounds synthetisierbar (Pegel plausibel)")
	for s in ["hit", "bounce_wood", "bounce_stone", "bounce_metal", "splash_water", "splash_lava", "holed", "fanfare", "click", "chest_open"]:
		SoundManager.play(s, 0.7)
	SoundManager.set_wind(0.8)
	check(true, "Sounds abgespielt")

# ---------------------------------------------------------------- Bahnen

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _test_profile() -> Dictionary:
	var prof: Dictionary = GameManager.make_shot_profile(Catalog.START_CLUB, 1, "standard")
	prof["scatter_deg"] = 0.0
	return prof

func _new_ball(c: Course3D) -> Ball3D:
	var ball := Ball3D.new()
	c.add_child(ball)
	ball.setup(c, "test", _test_profile(), "standard", "none", false)
	ball.sound_gain = 0.0
	return ball

## Wartet, bis der Ball nicht mehr rollt/fliegt (oder max_seconds Spielzeit um sind).
func _wait_ball(ball: Ball3D, max_seconds: float) -> void:
	var ticks: int = int(max_seconds * 60.0)
	await _frames(3)
	for i in ticks:
		if ball.state != Ball3D.State.MOVING and ball.state != Ball3D.State.OUT:
			return
		await get_tree().physics_frame

func _stage_courses() -> void:
	print("[SMOKE] Stage: Bahnen bauen")
	var ids: Array[String] = Catalog.all_course_ids()
	ids.append("daily")
	for id in ids:
		var t_build: int = Time.get_ticks_usec()
		var c: Course3D = CourseBuilder3D.build(id, 4242, false)
		t_build = Time.get_ticks_usec() - t_build
		add_child(c)
		await _frames(3)
		check(c.path_points.size() > 8 and c.total_length() > 15.0, "%s: Mittellinie vorhanden" % id)
		_check_terrain(c, id, t_build)
		check(c.floor_body != null and c.floor_body.get_child_count() > 0, "%s: Boden-Kollision" % id)
		check(c.par >= 1 and c.par <= 5 and c.title != "", "%s: Titel/Par" % id)
		var space := c.get_world_3d().direct_space_state
		var q := PhysicsRayQueryParameters3D.create(c.tee.origin, c.tee.origin + Vector3.DOWN * 2.0, 1)
		var hit: Dictionary = space.intersect_ray(q)
		check(not hit.is_empty() and absf((hit["position"] as Vector3).y - (c.tee.origin.y - 0.32)) < 0.08, "%s: Tee steht auf dem Boden" % id)
		var q2 := PhysicsRayQueryParameters3D.create(c.hole_pos + Vector3.UP, c.hole_pos + Vector3.DOWN * 2.0, 1)
		var hh: Dictionary = space.intersect_ray(q2)
		check(not hh.is_empty() and absf((hh["position"] as Vector3).y - (c.hole_pos.y - Course3D.CUP_DEPTH)) < 0.08, "%s: Loch ist offen (Becherboden)" % id)
		var q3 := PhysicsRayQueryParameters3D.create(c.hole_pos + Vector3(1.2, 1.0, 0.0), c.hole_pos + Vector3(1.2, -2.0, 0.0), 1)
		var hg: Dictionary = space.intersect_ray(q3)
		check(not hg.is_empty() and absf((hg["position"] as Vector3).y - c.hole_pos.y) < 0.05, "%s: Gruen rund ums Loch" % id)
		check(c.kill_y < c.bounds.position.y - 1.0, "%s: Kill-Hoehe unter der Bahn" % id)
		# Ball direkt ueber dem Loch fallen lassen -> muss "eingelocht" melden
		var ball := _new_ball(c)
		ball.place_on_tee(Transform3D(Basis.IDENTITY, c.hole_pos + Vector3(0.15, 0.6, 0.0)))
		await _frames(2)
		ball.unfreeze()
		ball.shoot(Vector3.FORWARD, 0.02, false, Vector2.ZERO)
		await _wait_ball(ball, 3.0)
		check(ball.state == Ball3D.State.HOLED, "%s: Ball faellt ins Loch -> HOLED (State %d)" % [id, ball.state])
		print("[SMOKE] %s '%s' Par %d, Laenge %.0f m, %d Gadgets, %d Hindernisse" % [id, c.title, c.par, c.total_length(), c.gadgets.size(), c.obstacles.size()])
		c.queue_free()
		await _frames(2)

## Gelaende-Tal: liegt ueberall unter dem Belag, Schluchten unter Spruengen/Fluegen, Aus-Grenze greift neben der Bahn.
func _check_terrain(c: Course3D, id: String, build_usec: int) -> void:
	check(c.terrain != null, "%s: Gelaende vorhanden" % id)
	if c.terrain == null:
		return
	var t: Terrain3D = c.terrain
	var bad := 0
	for i in c.surface_pts.size():
		var sp: Vector3 = c.surface_pts[i]
		var gap: float = sp.y - t.height_at(sp.x, sp.z)
		if gap < 0.15:
			bad += 1
			if bad <= 4:
				print("[SMOKE]   %s: Gelaende zu hoch bei (%.1f, %.1f, %.1f): nur %.2f m unter dem Belag" % [id, sp.x, sp.y, sp.z, gap])
	check(bad == 0, "%s: Gelaende liegt unter dem ganzen Belag (%d Proben, %d zu hoch)" % [id, c.surface_pts.size(), bad])
	var bad_cor := 0
	for cor in c.corridors:
		var a: Vector3 = cor["a"]
		var b: Vector3 = cor["b"]
		for k in range(1, 10):
			var p: Vector3 = a.lerp(b, float(k) / 10.0)
			if t.height_at(p.x, p.z) > minf(a.y, b.y) - 1.0:
				bad_cor += 1
				if bad_cor <= 3:
					print("[SMOKE]   %s: Schlucht zu flach bei (%.1f, %.1f): Gelaende %.1f m" % [id, p.x, p.z, t.height_at(p.x, p.z)])
	check(bad_cor == 0, "%s: Schluchten unter %d Spruengen/Fluegen" % [id, c.corridors.size()])
	var bounds: Gadget = null
	for g in c.gadgets:
		if g is Gadgets.TerrainBounds:
			bounds = g
	check(bounds != null, "%s: Aus-Grenze (Gelaende) aktiv" % id)
	if bounds != null:
		var st := SimState.new()
		st.begin_tick(c.tee.origin, Vector3.ZERO, true, 0.0, 1.0 / 60.0)
		bounds.affect(st, 1.0 / 60.0)
		var on_tee: String = st.out_kind
		var side: Vector3 = c.tee.origin + c.tee.basis.x * (TrackKit.WIDTH * 0.5 + 4.5)
		side.y = t.height_at(side.x, side.z) + 0.05
		st.begin_tick(side, Vector3.ZERO, true, 0.0, 1.0 / 60.0)
		bounds.affect(st, 1.0 / 60.0)
		check(on_tee == "" and st.out_kind == "ob", "%s: Ball auf dem Tee im Spiel, auf dem Hang daneben aus ('%s'/'%s')" % [id, on_tee, st.out_kind])
	var ridge: float = -INF
	for iz in range(0, t.nz, 4):
		for ix in range(0, t.nx, 4):
			ridge = maxf(ridge, t.heights[iz * t.nx + ix] - t.base_y)
	print("[SMOKE] %s Gelaende: %dx%d Punkte, Berge bis %.0f m ueber der Bahn, %d Schluchten, Bau %.0f ms" % [id, t.nx, t.nz, ridge, c.corridors.size(), float(build_usec) / 1000.0])

# ---------------------------------------------------------------- Abkuerzungen

## Jede Bahn ausser e1 (gerade Einsteiger-Bahn) und dem Golden Shot hat eine Abkuerzung:
## ein Ball mit Schwung auf dem Steg landet per Schanze auf dem Gruen (Vorhersage und echter Ball),
## ein Ball, der seitlich vom Steg rollt, ist aus. Die Ersparnis wird gemessen, nicht angenommen.
func _stage_shortcuts() -> void:
	print("[SMOKE] Stage: Abkuerzungen")
	var missing := PackedStringArray()
	var found := 0
	for id in Catalog.all_course_ids():
		var c: Course3D = CourseBuilder3D.build(id, 4242, false)
		add_child(c)
		await _frames(3)
		if c.shortcut.is_empty():
			print("[SMOKE] %s: keine Abkuerzung (verworfen: %s)" % [id, str(CourseBuilder3D.plan_stats)])
			if id != "e1":
				missing.append(id)
			c.queue_free()
			await _frames(2)
			continue
		found += 1
		var sc: Dictionary = c.shortcut
		var dir: Vector3 = sc["dir"]
		var start: Vector3 = (sc["gate"] as Vector3) + dir * 1.2 + Vector3.UP * (Ball3D.RADIUS + 0.01)
		var space := c.get_world_3d().direct_space_state
		var prof := _test_profile()
		var res: Dictionary = ShotSim.run(c, space, start, dir * 9.0, {"max_time": 12.0, "profile": prof})
		var end: Vector3 = res["end_pos"]
		var on_green: bool = bool(res["holed"]) or (not bool(res["out"]) and end.distance_to(c.hole_pos) < 8.5 and absf(end.y - c.hole_pos.y) < 0.6)
		var perp: Vector3 = dir.cross(Vector3.UP).normalized()
		if perp.dot(sc["normal"]) < 0.0:
			perp = -perp
		var miss: Dictionary = ShotSim.run(c, space, start + dir * 3.0, dir * 1.5 + perp * 6.0, {"max_time": 8.0, "profile": prof})
		var weak: Dictionary = ShotSim.run(c, space, start + dir * 3.0, dir * 3.6, {"max_time": 8.0, "profile": prof})
		var main_len: float = float(sc["remaining"])
		var direct: float = float(sc["direct"])
		print("[SMOKE] %s Abkuerzung: Hauptweg ab Tor %.0f m, Steg+Flug %.0f m (spart %.0f m), Abschuss %.0f Grad -> Vorhersage %s (%.1f m vom Loch), Fehlschuss %s, zu langsam %s" % [
			id, main_len, direct, main_len - direct, float(sc["elev"]),
			"Loch" if bool(res["holed"]) else ("AUS/" + str(res["out_kind"]) if bool(res["out"]) else "liegt"), end.distance_to(c.hole_pos),
			"aus" if bool(miss["out"]) else "NICHT aus", "aus" if bool(weak["out"]) else ("bleibt auf dem Steg" if not bool(weak["out"]) else "")])
		check(on_green, "%s: Abkuerzung landet auf dem Gruen (Vorhersage)" % id)
		check(bool(miss["out"]), "%s: seitlich vom Steg = aus" % id)
		if id in ["e2", "v3", "p1"]:
			var ball := _new_ball(c)
			ball.place_on_tee(Transform3D(Basis.looking_at(dir, Vector3.UP), start))
			await _frames(3)
			ball.unfreeze()
			var power: float = 9.0 / (Ball3D.MAX_SPEED * float(prof.get("power", 1.0)))
			ball.shoot(dir, power, false, Vector2.ZERO)
			await _wait_ball(ball, 16.0)
			var bp: Vector3 = ball.global_position
			var real_ok: bool = ball.state == Ball3D.State.HOLED or (ball.state == Ball3D.State.IDLE and bp.distance_to(c.hole_pos) < 8.5 and absf(bp.y - c.hole_pos.y) < 0.6)
			print("[SMOKE] %s Abkuerzung echter Ball: State %d, %.1f m vom Loch (Vorhersage %.1f m)" % [id, ball.state, bp.distance_to(c.hole_pos), end.distance_to(c.hole_pos)])
			check(real_ok, "%s: echter Ball landet ueber die Abkuerzung auf dem Gruen" % id)
			ball.queue_free()
		c.queue_free()
		await _frames(2)
	print("[SMOKE] Abkuerzungen: %d von 15 Bahnen; ohne: e1 (gerade Einsteiger-Bahn)%s" % [found, (", " + ", ".join(missing)) if not missing.is_empty() else ""])
	check(missing.is_empty(), "Jede Bahn ausser e1 hat eine Abkuerzung (fehlt: %s)" % ", ".join(missing))

## Hindernisse auf der Bahn: Bach (seitlich = Wasser, Steg = frei, darueber = frei), Rough bremst,
## Baumstamm/Felsen haben Kollision.
func _stage_hazards() -> void:
	print("[SMOKE] Stage: Hindernisse auf der Bahn")
	var c: Course3D = CourseBuilder3D.build("e3", 4242, false)
	add_child(c)
	await _frames(3)
	var creek: Gadget = null
	for g in c.gadgets:
		if g is Gadgets.Creek:
			creek = g
	check(creek != null, "e3: Bach quer ueber die Bahn")
	if creek != null:
		var st := SimState.new()
		var results := PackedStringArray()
		for lp: Vector3 in [Vector3(1.8, 0.3, 0.0), Vector3(0.0, 0.3, 0.0), Vector3(1.8, 1.2, 0.0)]:
			st.begin_tick(creek.global_transform * lp, Vector3.ZERO, true, 0.0, 1.0 / 60.0)
			creek.affect(st, 1.0 / 60.0)
			results.append(st.out_kind)
		check(results[0] == "water" and results[1] == "" and results[2] == "", "Bach: seitlich rollend = Wasser, ueber den Steg = frei, darueber geflogen = frei (%s)" % ", ".join(results))
	c.queue_free()
	await _frames(2)
	c = CourseBuilder3D.build("e2", 4242, false)
	add_child(c)
	await _frames(3)
	var rough: Gadget = null
	for g in c.gadgets:
		if g is Gadgets.RoughZone:
			rough = g
	check(rough != null, "e2: Rough am Rand")
	if rough != null:
		var st2 := SimState.new()
		st2.begin_tick(rough.global_transform * Vector3(0.0, 0.3, 0.0), Vector3.ZERO, true, 0.0, 1.0 / 60.0)
		rough.affect(st2, 1.0 / 60.0)
		check(st2.decel_mul > 1.5, "Rough bremst rollende Baelle (Faktor %.1f)" % st2.decel_mul)
	var solid := 0
	for n in c.find_children("*", "StaticBody3D", true, false):
		if n != c.floor_body and n != c.wall_body:
			solid += 1
	check(solid >= 1, "e2: Baumstamm mit Kollision (%d feste Hindernisse)" % solid)
	print("[SMOKE] Hindernisse: e2 %d feste Koerper, %d Blocker fuer die Abkuerzung" % [solid, c.blockers.size()])
	c.queue_free()
	await _frames(2)

# ---------------------------------------------------------------- Physik: Vorhersage gegen echten Ball

func _shot_case(c: Course3D, label: String, dir: Vector3, power: float, chip: bool, spin: Vector2, tolerance: float) -> void:
	var prof := _test_profile()
	var ball := _new_ball(c)
	ball.place_on_tee(c.tee)
	await _frames(3)
	ball.unfreeze()
	var space := c.get_world_3d().direct_space_state
	var pred: Dictionary = ShotSim.predict_shot(c, space, ball.global_position, dir, power, chip, spin, prof, 12.0)
	var ok: bool = ball.shoot(dir, power, chip, spin)
	check(ok, label + ": Schlag ausgeloest")
	await _wait_ball(ball, 16.0)
	check(ball.state == Ball3D.State.IDLE or ball.state == Ball3D.State.HOLED, label + ": Schlag endet (State %d)" % ball.state)
	var end_real: Vector3 = ball.global_position
	var end_pred: Vector3 = pred["end_pos"]
	var err: float = end_real.distance_to(end_pred)
	var travelled: float = end_real.distance_to(c.tee.origin)
	var predicted: float = end_pred.distance_to(c.tee.origin)
	print("[SMOKE] %s: echt %.1f m, vorhergesagt %.1f m, Abweichung %.2f m (holed=%s/%s, Zeit %.1f s)" % [label, travelled, predicted, err, ball.state == Ball3D.State.HOLED, pred["holed"], float(pred["time"])])
	check(travelled > 1.0, label + ": Ball hat sich bewegt")
	check(err < tolerance, label + ": Vorhersage stimmt (%.2f m < %.1f m)" % [err, tolerance])
	ball.queue_free()
	await _frames(2)

## Schatten-Physikraum: bewegliche Teile lassen sich fuer Vorhersagen sofort auf jeden Zeitpunkt stellen.
func _stage_shadow_space() -> void:
	print("[SMOKE] Stage: Schatten-Physikraum")
	var c: Course3D = CourseBuilder3D.build("p3", 0, false)
	add_child(c)
	await _frames(3)
	check(c.has_moving_parts(), "p3 hat bewegliche Teile")
	var ferry: Obstacles.MovingPlatform = null
	for o in c.obstacles:
		if o is Obstacles.MovingPlatform:
			ferry = o
	check(ferry != null, "p3 hat eine Faehre")
	if ferry != null:
		var st: PhysicsDirectSpaceState3D = c.shadow_state()
		var hits := 0
		for t in [0.0, 3.5]:
			c.shadow_pose(t)
			var top: Vector3 = ferry.global_transform * ferry.pose(t)
			var q := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 2.0, top + Vector3.DOWN * 2.0, Obstacles.LAYER_PLATFORM)
			if not st.intersect_ray(q).is_empty():
				hits += 1
		c.shadow_restore()
		check(hits == 2, "Schattenraum: Faehre ist zu jedem Zeitpunkt sofort abfragbar (%d/2)" % hits)
		# Gegenprobe: an der Stelle t=0 ist bei t=3.5 keine Faehre mehr
		var p0: Vector3 = ferry.global_transform * ferry.pose(0.0)
		c.shadow_pose(3.5)
		var q2 := PhysicsRayQueryParameters3D.create(p0 + Vector3.UP * 2.0, p0 + Vector3.DOWN * 2.0, Obstacles.LAYER_PLATFORM)
		check(st.intersect_ray(q2).is_empty(), "Schattenraum: Faehre ist wirklich weitergefahren")
		c.shadow_restore()
	c.queue_free()
	await _frames(2)

func _stage_physics() -> void:
	print("[SMOKE] Stage: Ball-Physik")
	var c: Course3D = CourseBuilder3D.build("e1", 0, false)
	add_child(c)
	await _frames(3)
	var fwd: Vector3 = -c.tee.basis.z
	await _shot_case(c, "Putt 40%", fwd, 0.4, false, Vector2.ZERO, 2.0)
	await _shot_case(c, "Putt 70% schraeg", fwd.rotated(Vector3.UP, 0.12), 0.7, false, Vector2.ZERO, 4.0)
	await _shot_case(c, "Chip 60%", fwd, 0.6, true, Vector2.ZERO, 5.0)
	await _shot_case(c, "Chip 60% Backspin", fwd, 0.6, true, Vector2(0.0, -1.0), 5.0)
	await _shot_case(c, "Putt 50% Sidespin", fwd, 0.5, false, Vector2(1.0, 0.0), 4.0)
	# Out-of-Bounds: seitlich ueber die Bande chippen -> Strafschlag + Respawn auf dem Tee
	var ball := _new_ball(c)
	ball.place_on_tee(c.tee)
	await _frames(3)
	ball.unfreeze()
	ball.shoot(c.tee.basis.x, 0.9, true, Vector2.ZERO)
	await _frames(20)
	await _wait_ball(ball, 14.0)
	check(ball.state == Ball3D.State.IDLE and ball.strokes == 2, "Out: Strafschlag (Schlaege=%d, State %d)" % [ball.strokes, ball.state])
	check(ball.global_position.distance_to(c.tee.origin) < 0.5, "Out: Respawn an letzter sicherer Position")
	c.queue_free()
	await _frames(2)

# ---------------------------------------------------------------- Jolt-Nachweis

## Kleine Physik-Probe (Area3D-Ueberlappungen). Der eigentliche Nachweis, dass wirklich Jolt rechnet, ist der
## Physik-Fingerabdruck in der CI (tests/PhysicsProbe.gd laeuft dort einmal mit Jolt und einmal mit GodotPhysics).
func _stage_jolt_probe() -> void:
	print("[SMOKE] Stage: Jolt-Nachweis")
	var root := Node3D.new()
	root.position = Vector3(0.0, 500.0, 0.0)
	add_child(root)
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1 << 10
	var acs := CollisionShape3D.new()
	var ash := SphereShape3D.new()
	ash.radius = 1.0
	acs.shape = ash
	area.add_child(acs)
	root.add_child(area)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1 << 10
	sb.collision_mask = 0
	var scs := CollisionShape3D.new()
	var sbox := BoxShape3D.new()
	sbox.size = Vector3(0.5, 0.5, 0.5)
	scs.shape = sbox
	sb.add_child(scs)
	root.add_child(sb)
	var rb := RigidBody3D.new()
	rb.collision_layer = 1 << 10
	rb.collision_mask = 0
	rb.gravity_scale = 0.0
	var rcs := CollisionShape3D.new()
	var rsh := SphereShape3D.new()
	rsh.radius = 0.2
	rcs.shape = rsh
	rb.add_child(rcs)
	rb.position = Vector3(0.4, 0.0, 0.0)
	root.add_child(rb)
	await _frames(6)
	var statics := 0
	var rigids := 0
	for b in area.get_overlapping_bodies():
		if b is StaticBody3D:
			statics += 1
		elif b is RigidBody3D:
			rigids += 1
	print("[SMOKE] Area3D sieht %d RigidBody, %d StaticBody" % [rigids, statics])
	check(rigids == 1, "Area3D erkennt RigidBody")
	check(str(ProjectSettings.get_setting("physics/3d/physics_engine")) == "Jolt Physics", "Projekt ist auf Jolt-Physik eingestellt")
	root.queue_free()
	await _frames(2)

# ---------------------------------------------------------------- Bots spielen alle Bahnen

func _process_frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

## Laesst einen Bot die Bahn spielen. Rueckgabe: {holed, strokes, time, ...}; schreibt pro Schlag eine Diagnosezeile.
func _bot_playthrough(id: String, verbose: bool) -> Dictionary:
	var c: Course3D = CourseBuilder3D.build(id, 4242, false)
	add_child(c)
	await _frames(3)
	var ball := _new_ball(c)
	ball.place_on_tee(c.tee)
	await _frames(3)
	ball.unfreeze()
	var brain := BotBrain.new(ball, c, 0.92, 777)
	var t := 0.0
	var space := c.get_world_3d().direct_space_state
	var seen_shots := 0
	var shot_from := Vector3.ZERO
	var strokes_before := 0
	var pending := false
	var track := PackedStringArray()
	var frame_no := 0
	while t < 240.0 and ball.state != Ball3D.State.HOLED and ball.strokes < Ball3D.MAX_STROKES:
		brain.update(1.0 / 60.0)
		if brain.wants_cpu():
			brain.think(space)
		if brain.shots_taken > seen_shots:
			seen_shots = brain.shots_taken
			shot_from = brain._shot_from
			strokes_before = ball.strokes - 1
			pending = true
			track.clear()
		elif pending and ball.state != Ball3D.State.MOVING and ball.state != Ball3D.State.OUT:
			pending = false
			if verbose:
				_log_bot_shot(id, c, ball, brain, shot_from, strokes_before)
				if ball.strokes - strokes_before >= 2:
					print("[SMOKE]     Flugbahn bis OUT: ", " ".join(track))
		if pending and ball.state == Ball3D.State.MOVING and frame_no % 15 == 0 and track.size() < 40:
			var bp: Vector3 = ball.global_position
			track.append("(%.1f,%.1f,%.1f|%.0f)" % [bp.x, bp.y, bp.z, ball.linear_velocity.length()])
		frame_no += 1
		await get_tree().process_frame
		t += 1.0 / 60.0
	if ball.state == Ball3D.State.MOVING or ball.state == Ball3D.State.OUT:
		await _wait_ball(ball, 16.0)
	if pending and verbose:
		_log_bot_shot(id, c, ball, brain, shot_from, strokes_before)
	var out := {"holed": ball.state == Ball3D.State.HOLED, "strokes": ball.strokes, "time": t, "par": c.par,
		"progress": c.progress_at(ball.global_position), "length": c.total_length()}
	c.queue_free()
	await _frames(2)
	return out

func _log_bot_shot(id: String, c: Course3D, ball: Ball3D, brain: BotBrain, from: Vector3, strokes_before: int) -> void:
	var ch: Dictionary = brain.last_choice
	var went_out: bool = ball.strokes - strokes_before >= 2
	var pred_end: Vector3 = ch.get("pred_end", Vector3.ZERO)
	var pred_txt: String = "Loch" if bool(ch.get("pred_holed", false)) else ("OUT" if bool(ch.get("pred_out", false)) else "%.0f m" % c.progress_at(pred_end))
	var real_txt: String = "Loch" if ball.state == Ball3D.State.HOLED else ("OUT bei %.0f m (%.1f/%.1f/%.1f)" % [c.progress_at(ball.out_pos), ball.out_pos.x, ball.out_pos.y, ball.out_pos.z] if went_out else "%.0f m" % c.progress_at(ball.global_position))
	print("[SMOKE]   %s Schlag %d: ab %.0f m, %s %.0f%% (Zeitfenster +%.1f s) -> vorhergesagt %s, echt %s" % [id, strokes_before + 1, c.progress_at(from),
		"Chip" if bool(ch.get("chip", false)) else "Putt", float(ch.get("power", 0.0)) * 100.0, float(ch.get("dt", 0.0)), pred_txt, real_txt])

func _stage_bots() -> void:
	print("[SMOKE] Stage: Bots spielen jede Bahn")
	BotBrain.time_budget_usec = 400000
	var holed := 0
	var failed := PackedStringArray()
	for id in Catalog.all_course_ids():
		var r: Dictionary = await _bot_playthrough(id, true)
		print("[SMOKE] Bot auf %s: %s nach %d Schlaegen (Par %d, %.0f s, Fortschritt %.0f/%.0f m)" % [id,
			"EINGELOCHT" if bool(r["holed"]) else "NICHT eingelocht", int(r["strokes"]), int(r["par"]), float(r["time"]),
			float(r["progress"]), float(r["length"])])
		if bool(r["holed"]):
			holed += 1
		else:
			failed.append(id)
	print("[SMOKE] Bots: %d von 15 Bahnen eingelocht; offen: %s" % [holed, ", ".join(failed)])
	check(holed == 15, "Bot locht auf allen 15 Bahnen ein (offen: %s)" % ", ".join(failed))

# ---------------------------------------------------------------- Komplette Partie (Match3D + HUD + Bots)

func _run_match(config: Dictionary, auto: bool, max_seconds: float) -> Match3D:
	GameManager.match_config = config
	var scene: PackedScene = load("res://scenes/Game.tscn")
	var m := scene.instantiate() as Match3D
	m.auto_play = auto
	add_child(m)
	var t := 0.0
	while auto and not m.finished and t < max_seconds:
		await get_tree().process_frame
		t += 1.0 / 60.0
	return m

func _stage_match() -> void:
	print("[SMOKE] Stage: komplette Partie")
	GameManager.reset_progress()
	var cfg: Dictionary = GameManager.make_bot_match("emerald", 3, 2)
	cfg["courses"] = ["e1", "n1"]
	cfg["rounds"] = 2
	var trophies_before := GameManager.trophies()
	BotBrain.time_budget_usec = 2500   # Produktions-Rechenbudget
	var m: Match3D = await _run_match(cfg, true, 420.0)
	check(m.finished, "Partie ueber 2 Bahnen laeuft bis zum Ende")
	check(m.final_ranking.size() == 3, "Endrangliste mit 3 Spielern")
	check(m.result_rewards.has("coins") and int(m.result_rewards["coins"]) > 0, "Match-Belohnung (Coins) vergeben")
	check(GameManager.trophies() != trophies_before or int(m.result_rewards.get("trophies", 0)) == 0, "Trophaeen verbucht")
	var totals := PackedStringArray()
	for row in m.final_ranking:
		totals.append("%s=%d" % [str(row["name"]), int(row["total"])])
	print("[SMOKE] Endstand: ", ", ".join(totals), " | Belohnung: ", m.result_rewards)
	check(m.hud.has_overlay(), "Ergebnis-Screen wird angezeigt")
	check(m.hud._root.find_child("ContinueButton", true, false) != null, "Ergebnis-Screen mit WEITER")
	check(int(m.result_rewards.get("pass_xp", 0)) > 0, "Match gibt Pass-XP")
	# HUD-Layout im Hochformat: oben Info + Rangliste, unten Bedienung, nichts ueberlappt
	var hvp := Rect2(Vector2.ZERO, m.get_viewport().get_visible_rect().size)
	var topr: Rect2 = m.hud._top_box.get_global_rect()
	var botr: Rect2 = m.hud._bottom_box.get_global_rect()
	check(hvp.grow(1.0).encloses(topr) and hvp.grow(1.0).encloses(botr), "HUD-Leisten im Bild")
	check(topr.end.y < botr.position.y, "HUD oben und unten ueberlappen nicht")
	check(m.hud._board.get_child_count() == 3 and m.hud._board.get_global_rect().position.y >= m.hud._info_title.get_global_rect().end.y,
		"Rangliste unter der Bahn-Info (3 Chips)")
	check(m.hud._mode_btn.get_global_rect().position.y > hvp.size.y * 0.5 and m.hud._spin_pad.get_global_rect().position.y > hvp.size.y * 0.5,
		"Schlagart und Spin in der Daumenzone")
	# HUD-Funktionen einmal durchlaufen
	m.hud.popup_style("AIR TIME! +60")
	m.hud.toast("Test")
	m.hud.set_status("REPLAY")
	m.hud.set_power(0.7, true)
	m.hud.set_chip_mode(true)
	m.hud.show_banner("BIRDIE!", "2 Schlaege")
	m.hud.hide_overlay()
	m.hud.confirm_exit()
	check(m.hud.has_overlay(), "Verlassen-Dialog oeffnet")
	m.hud.hide_overlay()
	m.hud.show_daily_result(1.5, false, {"coins": 200, "gems": 4, "label": "Ganz nah dran!"})
	await _process_frames(3)
	m.queue_free()
	await _process_frames(3)
	# Partie auf Bahnen mit Hammer, Faehre und Schiebebloecken: 4 Bots mit echtem Rechenbudget
	print("[SMOKE] Stage: Partie mit beweglichen Hindernissen (4 Bots, Budget 2,5 ms)")
	var cfg2: Dictionary = GameManager.make_bot_match("pirate", 3, 4)
	cfg2["courses"] = ["p3", "v3"]
	cfg2["rounds"] = 2
	var m2: Match3D = await _run_match(cfg2, true, 600.0)
	check(m2.finished, "Partie auf p3 + v3 mit 5 Spielern laeuft bis zum Ende")
	for rec in m2.players:
		if rec.brain != null:
			print("[SMOKE]   %s: Schlaege gesamt %d, letzte Suche %.2f s Bahn-Zeit, verpasste Zeitfenster %d" % [rec.name,
				rec.total, rec.brain.last_search_time, rec.brain.total_misses])
	var totals2 := PackedStringArray()
	for row in m2.final_ranking:
		totals2.append("%s=%d" % [str(row["name"]), int(row["total"])])
	print("[SMOKE] Endstand p3+v3: ", ", ".join(totals2))
	var best_total := 999
	for row in m2.final_ranking:
		best_total = mini(best_total, int(row["total"]))
	check(best_total <= 14, "Bester Bot schafft p3 + v3 (Par 8) in hoechstens 14 Schlaegen (%d)" % best_total)
	m2.queue_free()
	await _process_frames(3)
	BotBrain.time_budget_usec = 400000

# ---------------------------------------------------------------- Touch-Eingabe (Zielen, Drehen, Pinch)

## Testkoordinaten sind Viewport-Koordinaten (1280 breit); echte Touch-Events kommen in Fensterkoordinaten.
## Headless ist das Fenster winzig (64 px) -> umrechnen, wie es das Betriebssystem liefern wuerde.
func _to_window(pos: Vector2) -> Vector2:
	return get_viewport().get_final_transform() * pos

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = _to_window(pos)
	ev.pressed = pressed
	Input.parse_input_event(ev)

func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = _to_window(pos)
	ev.relative = get_viewport().get_final_transform().basis_xform(rel)
	Input.parse_input_event(ev)

func _stage_input() -> void:
	print("[SMOKE] Stage: Touch-Eingabe")
	var cfg: Dictionary = GameManager.make_bot_match("emerald", 3, 1)
	cfg["courses"] = ["e1"]
	var m: Match3D = await _run_match(cfg, false, 0.0)
	var t := 0.0
	while m.phase != Match3D.Phase.PLAY and t < 10.0:
		await get_tree().process_frame
		t += 1.0 / 60.0
	check(m.phase == Match3D.Phase.PLAY, "Bahn startet nach dem Intro")
	await _process_frames(40)
	var ball: Ball3D = m.local.ball
	var screen: Vector2 = m.rig.target_screen_pos()
	check(screen != Vector2.INF, "Ball ist im Bild")
	# 1) Kamera drehen: Finger weit weg vom Ball ziehen
	var yaw_before: float = m.rig.yaw
	var far: Vector2 = Vector2(120.0, 360.0)
	_touch(0, far, true)
	await _process_frames(2)
	for i in 6:
		_drag(0, far + Vector2(20.0 * float(i + 1), 0.0), Vector2(20.0, 0.0))
		await _process_frames(1)
	_touch(0, far + Vector2(120.0, 0.0), false)
	await _process_frames(2)
	check(absf(m.rig.yaw - yaw_before) > 0.1, "Ein-Finger-Wischen dreht die Kamera")
	check(ball.strokes == 0, "Kamera-Geste loest keinen Schlag aus")
	# 2) Pinch-to-Zoom mit zwei Fingern
	var dist_before: float = m.rig.distance
	_touch(0, Vector2(300, 300), true)
	_touch(1, Vector2(400, 300), true)
	await _process_frames(2)
	for i in 6:
		_drag(1, Vector2(400.0 + 30.0 * float(i + 1), 300.0), Vector2(30.0, 0.0))
		await _process_frames(1)
	_touch(1, Vector2(580, 300), false)
	_touch(0, Vector2(300, 300), false)
	await _process_frames(2)
	check(m.rig.distance < dist_before - 0.5, "Pinch (Finger auseinander) zoomt heran")
	# 3) Zielen: am Ball ziehen und loslassen
	m.rig.aim_at(-m.course.tee.basis.z, true)
	await _process_frames(20)
	screen = m.rig.target_screen_pos()
	print("[SMOKE] Zielen: Ball am Bildschirm %s, Viewport %s, can_aim=%s, ueber Widget=%s, offene Touches=%d, Ball-State=%d" % [screen,
		m.get_viewport().get_visible_rect().size, m._can_aim(), m.hud.is_over_widget(screen), m._touches.size(), ball.state])
	_touch(0, screen, true)
	await _process_frames(2)
	print("[SMOKE] Zielen nach Touch-Down: aiming=%s, Touches=%s" % [m._aiming, m._touches])
	# Headless ist der Viewport quadratisch (1280 x 1280) -> weiter ziehen als auf einem 16:9-Handy
	for i in 8:
		_drag(0, screen + Vector2(0.0, 40.0 * float(i + 1)), Vector2(0.0, 40.0))
		await _process_frames(1)
	check(m._aiming and m._aim_power > 0.3, "Ziehen am Ball spannt den Schlag (Kraft %.2f)" % m._aim_power)
	check(m._dots.visible and m._arrow.visible, "Kraftpfeil und Flugbahn-Vorschau sichtbar")
	_touch(0, screen + Vector2(0.0, 320.0), false)
	await _process_frames(4)
	check(ball.strokes == 1 and ball.state == Ball3D.State.MOVING, "Loslassen fuehrt den Schlag aus")
	await _wait_ball(ball, 16.0)
	var fwd: Vector3 = -m.course.tee.basis.z
	var moved: Vector3 = ball.global_position - m.course.tee.origin
	check(moved.dot(fwd) > 3.0, "Slingshot: nach unten ziehen schiesst nach vorn (%.1f m)" % moved.dot(fwd))
	# 4) Vogelperspektive und Emote
	m.hud._on_top_pressed()
	await _process_frames(5)
	check(m.rig.is_top(), "Vogelperspektive-Button schaltet um")
	m.hud._on_top_pressed()
	m.hud._on_emote("laugh")
	m.hud._on_emote("nice")
	await _process_frames(5)
	m.queue_free()
	await _process_frames(3)

# ---------------------------------------------------------------- Daily Challenge

func _stage_daily() -> void:
	print("[SMOKE] Stage: Golden Shot")
	GameManager.reset_progress()
	var cfg: Dictionary = GameManager.make_match_config("daily", "emerald", 1, [GameManager.local_player_entry()], GameManager.daily_seed(), false)
	check((cfg["courses"] as Array) == ["daily"], "Daily-Konfiguration")
	var m: Match3D = await _run_match(cfg, true, 120.0)
	check(m.finished, "Golden Shot endet nach einem Schlag")
	check(not GameManager.daily_available(), "Daily als gespielt markiert")
	check(int(m.result_rewards.get("coins", 0)) > 0, "Daily-Belohnung vergeben")
	print("[SMOKE] Golden Shot: ", m.result_rewards)
	m.queue_free()
	await _process_frames(3)
	# Loesbarkeit: gibt es mit dem Start-Schlaeger einen Chip, der nah an der Fahne liegen bleibt?
	for seed_value in [11, 222, 3333, GameManager.daily_seed()]:
		var c: Course3D = CourseBuilder3D.build("daily", seed_value, false)
		add_child(c)
		await _frames(3)
		var prof := _test_profile()
		var space := c.get_world_3d().direct_space_state
		var best := 999.0
		var to_hole := Vector3(c.hole_pos.x - c.tee.origin.x, 0.0, c.hole_pos.z - c.tee.origin.z).normalized()
		# wie ein Spieler: Richtung, Kraft und Backspin variieren
		for a in range(-14, 15):
			for pw in range(16, 41):
				for back in [0.0, -1.0]:
					var res: Dictionary = ShotSim.predict_shot(c, space, c.tee.origin, to_hole.rotated(Vector3.UP, deg_to_rad(float(a))),
						float(pw) / 40.0, true, Vector2(0.0, back), prof, 12.0, Vector3.UP, 1000)
					if bool(res["holed"]):
						best = 0.0
					elif not bool(res["out"]):
						var e: Vector3 = res["end_pos"]
						if absf(e.y - c.hole_pos.y) < 1.0:
							best = minf(best, Vector2(e.x - c.hole_pos.x, e.z - c.hole_pos.z).length())
		print("[SMOKE] Golden Shot Seed %d (%s): bester Chip landet %.1f m vom Loch" % [seed_value, c.world, best])
		check(best < 4.0, "Golden Shot ist mit dem Start-Schlaeger erreichbar (Seed %d: %.1f m)" % [seed_value, best])
		c.queue_free()
		await _frames(2)

# ---------------------------------------------------------------- Netzwerk (nur Offline-Pfade)

func _stage_network_offline() -> void:
	print("[SMOKE] Stage: NetworkManager (offline)")
	check(not NetworkManager.is_configured(), "Platzhalter-Config gilt als 'nicht konfiguriert'")
	check(not NetworkManager.is_online() and NetworkManager.local_id() == "local", "Offline: lokale ID")
	check(NetworkManager.is_host(), "Ohne Lobby gilt der Client als Host")
	NetworkManager.send_game_event("pos", {"id": "x"})
	NetworkManager.refresh_leaderboard()
	check(NetworkManager.leaderboard.size() > 5, "Offline-Rangliste gefuellt")
	NetworkManager.refresh_friends()
	check(NetworkManager.friends.is_empty(), "Offline: keine Freunde")

# ---------------------------------------------------------------- Battle Pass

func _stage_battle_pass() -> void:
	print("[SMOKE] Stage: Battle Pass")
	GameManager.reset_progress()
	check(Catalog.PASS_TIERS.size() == 30, "Pass hat 30 Stufen")
	check(Catalog.pass_season_at(float(Catalog.PASS_EPOCH_UNIX)) == 1, "Saison 1 beginnt am Stichtag")
	check(Catalog.pass_season_at(float(Catalog.PASS_EPOCH_UNIX) + 28.0 * 86400.0) == 2, "Nach 28 Tagen Saison 2")
	check(Catalog.pass_season_at(float(Catalog.PASS_EPOCH_UNIX) + 27.9 * 86400.0) == 1, "Tag 27 noch Saison 1")
	for i in Catalog.PASS_TIERS.size():
		var e: Dictionary = Catalog.PASS_TIERS[i]
		if e.has("item"):
			var it: Array = e["item"]
			check(Catalog.item_table(str(it[0])).has(str(it[1])), "Pass-Gegenstand existiert: %s" % str(it[1]))
		if e.has("chest"):
			check(Catalog.CHESTS.has(str(e["chest"])), "Pass-Truhe existiert: %s" % str(e["chest"]))
		check(Catalog.pass_reward_text(i) != "", "Pass-Stufe %d hat einen Text" % (i + 1))
	check(not GameManager.item_buyable("frame", "summit"), "Pass-Rahmen ist nicht kaufbar")
	check(GameManager.pass_xp() == 0 and GameManager.pass_tier() == 0, "Pass startet bei 0")
	check(GameManager.pass_season() >= 1, "Laufende Saison bestimmt")
	check(GameManager.pass_seconds_left() > 0.0 and GameManager.pass_seconds_left() <= 28.0 * 86400.0, "Saison-Restzeit plausibel")
	GameManager.add_pass_xp(Catalog.PASS_XP_PER_TIER - 1)
	check(GameManager.pass_tier() == 0 and GameManager.pass_claimable().is_empty(), "Knapp unter Stufe 1: nichts abholbar")
	check(GameManager.add_pass_xp(1) == 1, "Stufe 1 erreicht")
	check(GameManager.pass_claimable() == [0], "Stufe 1 abholbar")
	var c0: int = GameManager.coins()
	var r0: Dictionary = GameManager.pass_claim(0)
	check(int(r0.get("coins", 0)) == 100 and GameManager.coins() == c0 + 100, "Stufe 1 gibt 100 Coins")
	check(GameManager.pass_claim(0).is_empty(), "Stufe nur einmal abholbar")
	check(GameManager.pass_claim(5).is_empty(), "Nicht erreichte Stufe nicht abholbar")
	# Truhe ohne freien Slot bleibt offen
	GameManager.add_pass_xp(Catalog.PASS_XP_PER_TIER)
	for i in Catalog.CHEST_SLOTS:
		GameManager.add_chest("wood")
	check(GameManager.pass_claim(1).is_empty() and not GameManager.pass_claimed(1), "Pass-Truhe wartet auf freien Slot")
	GameManager.data["chests"] = [null, null, null, null]
	check(str(GameManager.pass_claim(1).get("chest", "")) == "wood" and GameManager.chest_state(0) != "empty", "Pass-Truhe landet im Slot")
	# Doppelter Gegenstand wird zu Coins
	GameManager.add_pass_xp(Catalog.pass_max_xp())
	check(GameManager.pass_tier() == Catalog.PASS_TIERS.size() and GameManager.pass_tier_progress() == 1.0, "Pass-XP gedeckelt, alle Stufen")
	var r4: Dictionary = GameManager.pass_claim(4)
	check(GameManager.owns("trail", "fire") and r4.has("items"), "Pass schaltet Feuer-Trail frei")
	GameManager.grant({"items": [{"kind": "trail", "id": "ice"}]})
	var r18: Dictionary = GameManager.pass_claim(18)
	check(not r18.has("items") and int(r18.get("coins", 0)) == Catalog.PASS_DUPLICATE_COINS, "Doppelter Pass-Gegenstand wird zu Coins")
	var r9: Dictionary = GameManager.pass_claim(9)
	check(r9.has("items") and GameManager.owns("frame", "summit") and GameManager.set_avatar_frame("summit"), "Pass-Rahmen freigeschaltet und nutzbar")
	# Saisonwechsel: offene Belohnungen werden gutgeschrieben, XP startet neu
	GameManager.reset_progress()
	GameManager.data["pass"] = {"season": GameManager.pass_season() - 1, "xp": 3 * Catalog.PASS_XP_PER_TIER, "claimed": [0]}
	var c1: int = GameManager.coins()
	var g1: int = GameManager.gems()
	check(GameManager.pass_xp() == 0, "Neue Saison beginnt bei 0 XP")
	check(GameManager.coins() == c1 + 120 and GameManager.gems() == g1 + 5, "Offene Stufen der alten Saison gutgeschrieben (Truhe als Coins)")
	check(GameManager.pass_claimable().is_empty(), "Nach Saisonwechsel nichts offen")
	# Match und Golden Shot geben Pass-XP
	GameManager.match_config = {"mode": "quick"}
	var mr: Dictionary = GameManager.finish_match({"rank": 1, "players": 4, "style_points": 120, "holes_in_one": 1, "strokes": 9, "holes": 3})
	check(int(mr.get("pass_xp", 0)) == 40 + 40 + 12 + 20 and GameManager.pass_xp() == 112, "Sieg gibt 112 Pass-XP")
	check(GameManager.describe_rewards(mr).has("+112 Pass-XP"), "Pass-XP in der Belohnungsliste")
	GameManager.match_config = {"mode": "practice"}
	check(int(GameManager.finish_match({"rank": 1, "players": 1}).get("pass_xp", 0)) == Catalog.PASS_XP_PRACTICE, "Training gibt wenig Pass-XP")
	GameManager.last_match_rewards = {}
	# Kaputter Speicherstand wird repariert
	GameManager.data["pass"] = "kaputt"
	GameManager._sanitize()
	check(GameManager.data["pass"] is Dictionary and GameManager.pass_xp() == 0, "Kaputter Pass-Stand repariert")
	GameManager.data["pass"] = {"season": GameManager.pass_season(), "xp": 99999999, "claimed": [0, 0, -3, 77, "2"]}
	GameManager._sanitize()
	check(GameManager.pass_xp() == Catalog.pass_max_xp() and GameManager.data["pass"]["claimed"] == [0, 2], "Pass-Werte begrenzt und bereinigt")
	GameManager.reset_progress()

# ---------------------------------------------------------------- Hauptmenue

func _stage_menu() -> void:
	print("[SMOKE] Stage: Hochformat-Hauptmenue + alle Seiten")
	GameManager.reset_progress()
	var ps: PackedScene = load("res://scenes/MainMenuView.tscn")
	check(ps != null, "MainMenuView.tscn laedt")
	if ps == null:
		return
	check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/MainMenuView.tscn", "Startszene ist MainMenuView")
	var menu := ps.instantiate() as MainMenuView
	check(menu != null, "MainMenuView hat das Menue-Skript")
	if menu == null:
		return
	add_child(menu)
	await _process_frames(10)
	check(menu.camera != null and menu.camera.current, "Menue-Kamera aktiv")
	var p0: Vector3 = menu.camera.global_position
	await _process_frames(30)
	check(menu.camera.global_position.distance_to(p0) > 0.05, "Kamera fliegt auf der Spline")
	check(menu.course != null and menu.course.obstacles.size() > 0, "Arena-Hintergrund mit Hindernissen gebaut")
	check(menu.showcase != null and menu.showcase.get_child_count() >= 3, "Vitrine mit Ball und Schlaeger")
	# Layout: alles im Bild, Kopfleiste / Inhalt / Tab-Leiste ueberlappen nicht
	var vp_rect := Rect2(Vector2.ZERO, menu.get_viewport().get_visible_rect().size)
	var top := menu.ui.find_child("TopBar", true, false) as Control
	var nav := menu.ui.find_child("NavBar", true, false) as Control
	var play := menu.ui.find_child("PlayButton", true, false) as Control
	var chests := menu.ui.find_child("ChestRow", true, false) as Control
	var arena := menu.ui.find_child("ArenaBanner", true, false) as Control
	check(top != null and nav != null and play != null and chests != null and arena != null, "Menue-Bausteine vorhanden")
	if top != null and nav != null and play != null and chests != null and arena != null:
		for c in [top, nav, play, chests, arena, menu._showcase_slot]:
			var r: Rect2 = (c as Control).get_global_rect()
			check(vp_rect.grow(1.0).encloses(r), "Im Bild: %s %s" % [str((c as Control).name), str(r)])
		check(top.get_global_rect().end.y <= arena.get_global_rect().position.y, "Kopfleiste ueber Arena-Banner")
		check(arena.get_global_rect().end.y <= menu._showcase_slot.get_global_rect().position.y + 0.5, "Arena-Banner ueber Vitrine")
		check(play.get_global_rect().end.y <= chests.get_global_rect().position.y, "SPIELEN ueber den Truhen")
		check(chests.get_global_rect().end.y <= nav.get_global_rect().position.y, "Truhen ueber der Tab-Leiste")
		check(play.get_global_rect().position.y > vp_rect.size.y * 0.5, "SPIELEN in der unteren Haelfte (Daumen)")
		check(nav.get_global_rect().end.y >= vp_rect.size.y - 60.0, "Tab-Leiste am unteren Rand")
	check(menu.showcase.visible, "Vitrine auf der Startseite sichtbar")
	# Einladungs-Leiste
	NetworkManager.invites = [{"id": 9, "code": "QX42", "from_id": "f9", "from_name": "Einlader"}]
	menu._refresh_invites()
	check(menu._invite_bar.visible and _min_width(menu._invite_bar) <= 700.0, "Einladungs-Leiste sichtbar und passt auf 720 px")
	check((menu._nav_badges["social"] as Label).visible, "Freunde-Abzeichen zeigt Einladung")
	NetworkManager.invites = []
	menu._refresh_invites()
	check(not menu._invite_bar.visible, "Einladungs-Leiste verschwindet")
	# Wischen dreht die Vitrine
	var start: Vector2 = menu._showcase_slot.get_global_rect().get_center()
	var ang0: float = menu._spin_angle
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = start
	t.pressed = true
	menu._unhandled_input(t)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = start + Vector2(80, 0)
	d.relative = Vector2(80, 0)
	menu._unhandled_input(d)
	t = t.duplicate() as InputEventScreenTouch
	t.pressed = false
	menu._unhandled_input(t)
	check(absf(menu._spin_angle - ang0) > 0.5, "Wischen dreht Ball/Schlaeger")
	# Arena wechseln baut den Hintergrund neu
	var bd0: String = menu.course.course_id
	menu._step_world(1)
	await _process_frames(40)
	check(MenuPages.sel_world == "volcano" and menu.course.course_id == "v4" and menu.course.course_id != bd0, "Arena-Wechsel baut Vulkan-Hintergrund")
	menu.select_world("emerald")
	await _process_frames(40)
	check(menu.course.course_id == "e5", "Zurueck zur Emerald-Arena")
	# Tab-Leiste
	for tab in ["bag", "pass", "social", "shop"]:
		menu._set_tab(tab)
		await _process_frames(3)
		check(menu.current_tab == tab and menu.pages.current_tab() == tab and not menu._home.visible, "Tab '%s' oeffnet" % tab)
		check(not menu.showcase.visible, "Vitrine aus auf Tab '%s'" % tab)
		var pr: Rect2 = (menu.pages.modal["root"] as Control).get_global_rect()
		check(pr.position.y >= top.get_global_rect().end.y - 0.5 and pr.end.y <= nav.get_global_rect().position.y + 0.5, "Tab-Seite zwischen Kopf- und Tab-Leiste: %s" % tab)
	menu._set_tab("home")
	await _process_frames(3)
	check(menu.current_tab == "home" and menu._home.visible and not menu.pages.is_open(), "Zurueck zur Startseite")
	# Alle Seiten oeffnen (Tab-Seiten und Overlays), jede passt in die Bildschirmbreite
	for page_id in MenuPages.PAGES.keys():
		menu.pages.open(str(page_id))
		await _process_frames(3)
		var ok: bool = menu.pages.is_open() and menu.pages.page == str(page_id) and (menu.pages.modal["body"] as Control).get_child_count() > 0
		check(ok, "Menue-Seite '%s' baut sich auf" % str(page_id))
		if ok:
			# Mindestbreite aller Bausteine muss auf ein 720 px breites Handy passen (minus Raender)
			var root := menu.pages.modal["root"] as Control
			var widest := _min_width(root)
			check(widest <= 700.0, "Seite '%s' passt auf 720 px (Mindestbreite %.0f px)" % [str(page_id), widest])
		menu.pages.refresh()
		await _process_frames(1)
	menu.pages.close_all()
	await _process_frames(2)
	check(not menu.pages.is_open() and menu.current_tab == "home", "Alle Seiten schliessen")
	# Zurueck-Taste: Tab-Seite -> Startseite
	menu._set_tab("shop")
	await _process_frames(2)
	check(menu.pages.close_top() and menu.current_tab == "home", "Zurueck-Taste fuehrt von Tab zur Startseite")
	await _process_frames(2)
	# Kaufen + Ausruesten aktualisiert Vitrine
	GameManager.add_coins(5000)
	menu.pages.open("cosmetics")
	await _process_frames(1)
	check(GameManager.buy_item("ball", "magma") and GameManager.equip("ball", "magma"), "Ball kaufen + ausruesten")
	await _process_frames(2)
	check(menu._ball_node != null and is_instance_valid(menu._ball_node), "Vitrine zeigt neuen Ball")
	check(menu.pages.modal["root"].find_child("Item_ball_magma", true, false) != null, "Kosmetik-Karte mit Vorschau")
	# Schlaeger: Karte -> Detail-Fenster mit 3D-Vorschau und Upgrade
	GameManager.add_club_cards(Catalog.START_CLUB, 10)
	menu.pages.open("clubs")
	await _process_frames(2)
	var card := menu.pages.modal["root"].find_child("Club_" + Catalog.START_CLUB, true, false) as Button
	check(card != null, "Schlaeger-Karte vorhanden")
	if card != null:
		card.pressed.emit()
	await _process_frames(2)
	var detail := menu.ui.find_child("ClubDetail", true, false) as Control
	check(detail != null and detail.find_child("*", true, false) != null, "Schlaeger-Detail oeffnet")
	var up: Button = null
	if detail != null:
		up = detail.find_child("UpgradeButton", true, false) as Button
		check(_count_type(detail, "SubViewportContainer") >= 1, "Schlaeger-Detail mit 3D-Vorschau")
	check(up != null and not up.disabled, "Upgrade-Button aktiv bei genug Karten/Coins")
	if up != null:
		up.pressed.emit()
	await _process_frames(2)
	check(GameManager.club_level(Catalog.START_CLUB) == 2, "Upgrade ueber das Menue")
	while menu.pages.any_modal_open():
		menu.pages.close_top()
		await _process_frames(1)
	menu.pages.close_all()
	# Battle Pass im Menue abholen
	GameManager.add_pass_xp(2 * Catalog.PASS_XP_PER_TIER)
	menu._refresh_badges()
	check((menu._nav_badges["pass"] as Label).visible and (menu._nav_badges["pass"] as Label).text == "2", "Pass-Abzeichen zeigt 2")
	menu._set_tab("pass")
	await _process_frames(3)
	var claim_all := menu.pages.modal["root"].find_child("PassClaimAll", true, false) as Button
	check(claim_all != null, "Pass: Alle abholen")
	var coins_before: int = GameManager.coins()
	if claim_all != null:
		claim_all.pressed.emit()
	await _process_frames(3)
	check(GameManager.pass_claimed(0) and GameManager.pass_claimed(1) and GameManager.coins() == coins_before + 100, "Pass-Stufen 1+2 abgeholt")
	check(menu.ui.find_child("Rewards", true, false) != null, "Pass-Belohnungsfenster")
	while menu.pages.any_modal_open():
		menu.pages.close_top()
		await _process_frames(1)
	menu.pages.close_all()
	# Truhen-Slots: Timer starten, mit Gems oeffnen, Belohnungsfenster
	GameManager.data["chests"] = [null, null, null, null]
	GameManager.add_chest("wood")
	GameManager.add_gems(200)
	await _process_frames(2)
	menu._on_chest_pressed(0)
	await _process_frames(2)
	check(menu.pages.any_modal_open(), "Truhen-Dialog oeffnet")
	menu.pages.close_top()
	await _process_frames(2)
	check(GameManager.start_unlock(0), "Truhen-Timer startet")
	var r: Dictionary = GameManager.open_chest(0, true)
	check(not r.is_empty(), "Truhe mit Gems sofort geoeffnet")
	menu.pages.show_rewards("Holztruhe", r)
	await _process_frames(5)
	check(menu.ui.find_child("Rewards", true, false) != null, "Belohnungsfenster sichtbar")
	check(menu.pages.close_top() and true, "Zurueck-Taste schliesst oberstes Fenster")
	await _process_frames(2)
	# Tagesgeschenk
	menu._set_tab("shop")
	await _process_frames(1)
	var gift: Dictionary = GameManager.claim_gift()
	check(not gift.is_empty() and not GameManager.gift_available(), "Tagesgeschenk einmal pro Tag")
	menu._set_tab("home")
	# Trophaeen-Pfad
	GameManager.grant({"trophies": 120})
	var road: Dictionary = GameManager.claim_road(0)
	check(int(road.get("coins", 0)) == 150, "Trophaeen-Pfad: erste Belohnung")
	(menu.ui.find_child("TrophyButton", true, false) as Button).pressed.emit()
	await _process_frames(2)
	check(menu.pages.page == "trophies", "Trophaeen-Knopf oeffnet Trophaeen-Seite")
	menu.pages.close_all()
	# Profil-Knopf oeffnet Einstellungen mit Account-Bereich
	(menu.ui.find_child("ProfileButton", true, false) as Button).pressed.emit()
	await _process_frames(2)
	check(menu.pages.page == "settings", "Profil oeffnet Einstellungen")
	menu.pages.close_all()
	# Lobby/Freunde offline zeigen Hinweis statt Absturz
	menu.pages.open("lobby")
	await _process_frames(1)
	check(menu.pages.is_open(), "Lobby-Seite offline")
	menu.pages.close_all()
	await _process_frames(30)
	menu.queue_free()
	await _process_frames(3)
	GameManager.reset_progress()
	MenuPages.sel_world = "emerald"

## Groesste Mindestbreite unterhalb von root (so breit wird die Seite mindestens, egal wie gross der Bildschirm ist).
func _min_width(root: Control) -> float:
	var w: float = root.get_combined_minimum_size().x
	if root is ScrollContainer:
		return w
	for c in root.get_children():
		if c is Control and (c as Control).visible:
			w = maxf(w, _min_width(c as Control))
	return w

func _count_avatars(root: Node) -> int:
	var n: int = 1 if root is UIAvatar else 0
	for c in root.get_children():
		n += _count_avatars(c)
	return n

func _count_type(root: Node, type_name: String) -> int:
	var n: int = 1 if root.is_class(type_name) else 0
	for c in root.get_children():
		n += _count_type(c, type_name)
	return n

# ---------------------------------------------------------------- Anmeldung, Spielstand-Regel, Profilbild

func _wait_until(cond: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await get_tree().process_frame
	return bool(cond.call())

func _stage_auth_offline() -> void:
	print("[SMOKE] Stage: AuthManager/ProfileManager (offline)")
	check(AuthManager.normalize_code("abcd-2345") == "ABCD2345", "Spiel-Code wird normalisiert")
	check(AuthManager.normalize_code("ABCD 23 45") == "ABCD2345", "Leerzeichen im Code erlaubt")
	check(AuthManager.normalize_code("ABC") == "" and AuthManager.normalize_code("ABCD234O") == "", "Ungueltige Codes abgelehnt (Laenge, O/0)")
	check(AuthManager.is_valid_email("a.b@example.com") and not AuthManager.is_valid_email("kein-at") and not AuthManager.is_valid_email("a@b"), "E-Mail-Pruefung")
	check(not AuthManager.is_configured() and AuthManager.local_id() == "local", "Ohne Backend: offline, lokale ID")
	check(NetworkManager.user_id == AuthManager.user_id and NetworkManager.url == AuthManager.url, "NetworkManager liest die Anmeldung nur beim AuthManager")
	# Lokale Speicherung: verschluesselt, Migration der alten session.json, kaputte Datei = keine Session
	AuthManager.clear_saved_session()
	AuthManager.save_refresh_token("tok-123")
	check(AuthManager.load_saved_refresh_token() == "tok-123", "auth.json: Token wird gespeichert und gelesen")
	var raw: String = FileAccess.get_file_as_bytes(AuthManager.AUTH_PATH).get_string_from_ascii()
	check(not raw.contains("tok-123"), "auth.json enthaelt das Token nicht im Klartext")
	# (Godot meldet beim Lesen der absichtlich kaputten Datei einen ERROR "magic" - das ist erwartet)
	var f := FileAccess.open(AuthManager.AUTH_PATH, FileAccess.WRITE)
	f.store_string("kaputt")
	f.close()
	check(AuthManager.load_saved_refresh_token() == "", "Unlesbare auth.json = keine Session")
	var lf := FileAccess.open(AuthManager.LEGACY_SESSION_PATH, FileAccess.WRITE)
	lf.store_string(JSON.stringify({"rt": "legacy-rt"}))
	lf.close()
	check(AuthManager.load_saved_refresh_token() == "legacy-rt" and not FileAccess.file_exists(AuthManager.LEGACY_SESSION_PATH), "Alte session.json wird uebernommen und geloescht")
	check(AuthManager.load_saved_refresh_token() == "legacy-rt", "Uebernommenes Token liegt danach in auth.json")
	AuthManager.clear_saved_session()
	check(not FileAccess.file_exists(AuthManager.AUTH_PATH), "Abmelden loescht auth.json")
	# Profilbild: nur gueltige Pfade, Bild-Dekodierung robust
	var uid := "22222222-2222-4222-8222-222222222222"
	check(ProfileManager.is_valid_path(uid + "/avatar-17.png", uid), "Gueltiger Avatar-Pfad")
	check(not ProfileManager.is_valid_path("../" + uid + "/avatar-17.png") and not ProfileManager.is_valid_path(uid + "/avatar-17.svg")
		and not ProfileManager.is_valid_path(uid + "/avatar-17.png", "33333333-3333-4333-8333-333333333333")
		and not ProfileManager.is_valid_path("https://evil.example/x.png"), "Fremde/ungueltige Avatar-Pfade abgelehnt")
	var img := Image.create(40, 40, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE)
	check(ProfileManager.decode_image(img.save_png_to_buffer()) != null, "PNG-Profilbild wird dekodiert")
	check(ProfileManager.decode_image(img.save_jpg_to_buffer()) != null, "JPEG-Profilbild wird dekodiert")
	check(ProfileManager.decode_image("<html>kein bild</html>".to_utf8_buffer()) == null, "Kein Bild -> verworfen")
	var big := PackedByteArray()
	big.resize(ProfileManager.MAX_AVATAR_BYTES + 10)
	check(ProfileManager.decode_image(big) == null, "Zu grosse Datei -> verworfen")
	var large := Image.create(1024, 700, false, Image.FORMAT_RGB8)
	var dec: Image = ProfileManager.decode_image(large.save_png_to_buffer())
	check(dec != null and maxi(dec.get_width(), dec.get_height()) <= ProfileManager.MAX_SIDE, "Grosses Bild wird verkleinert")
	# Spielstand-Regel beim Account-Wechsel
	GameManager.reset_progress()
	GameManager.data["account_id"] = ""
	check(GameManager.adopt_account_save("acc-a", {}) == "upload" and str(GameManager.data["account_id"]) == "acc-a", "Leerer Server-Stand: lokaler Stand gehoert dem Account")
	var newer: Dictionary = GameManager.data.duplicate(true)
	newer["revision"] = int(GameManager.data["revision"]) + 10
	newer["coins"] = 999
	check(GameManager.adopt_account_save("acc-a", newer) == "loaded" and GameManager.coins() == 999, "Gleicher Account: neuerer Server-Stand wird geladen")
	var older: Dictionary = GameManager.data.duplicate(true)
	older["revision"] = 1
	older["coins"] = 5
	check(GameManager.adopt_account_save("acc-a", older) == "upload" and GameManager.coins() == 999, "Gleicher Account: aelterer Server-Stand ueberschreibt nichts")
	GameManager.grant({"trophies": 40})
	var other: Dictionary = GameManager.default_save()
	other["trophies"] = 500
	other["revision"] = 2
	var before := _count_backups()
	check(GameManager.adopt_account_save("acc-b", other) == "loaded_backup", "Anderer Account mit Stand: Laden mit Sicherung")
	check(GameManager.trophies() == 500 and str(GameManager.data["account_id"]) == "acc-b", "Server-Stand des neuen Accounts aktiv")
	check(_count_backups() > before, "Bisheriger Fortschritt als Sicherungsdatei abgelegt")
	GameManager.reset_progress()
	check(not GameManager.has_real_progress() and GameManager.adopt_account_save("acc-c", other) == "loaded", "Frischer lokaler Stand: ohne Sicherung geladen")
	GameManager.reset_progress()
	GameManager.data["account_id"] = ""

func _count_backups() -> int:
	var n := 0
	var dir := DirAccess.open("user://")
	if dir != null:
		for file in dir.get_files():
			if file.begins_with("save_backup_"):
				n += 1
	return n

## Kompletter Ablauf gegen einen lokalen Schein-Server: Gast-Login, Web-Code einloesen, Profil + Profilbild.
## Freunde- und Lobby-Seite im Online-Zustand (mit Testdaten): bauen sich auf und passen auf 720 px.
func _check_online_pages() -> void:
	check(NetworkManager.is_online(), "Online fuer Seiten-Test")
	var host := Control.new()
	host.size = Vector2(720, 1280)
	add_child(host)
	var pg := MenuPages.new(null, host, host)
	var me: String = AuthManager.user_id
	var friends_data: Array = [
		{"row_id": 1, "id": "f1", "name": "Kumpel", "trophies": 420, "frame": "silver", "color": 2, "online": true, "state": "accepted"},
		{"row_id": 2, "id": "f2", "name": "Sehr langer Name", "trophies": 12, "frame": "bronze", "color": 3, "online": false, "state": "incoming"},
		{"row_id": 3, "id": "f3", "name": "Wartender", "trophies": 99, "frame": "gold", "color": 4, "online": false, "state": "outgoing"},
	]
	var invites_data: Array = [{"id": 7, "code": "AB12", "from_id": "f1", "from_name": "Kumpel"}]
	pg.open("friends")
	await _process_frames(1)
	NetworkManager.friends = friends_data.duplicate(true)
	NetworkManager.invites = invites_data.duplicate(true)
	pg._search_results = [{"id": "s1", "name": "Gesucht", "code": "SUCH1234", "trophies": 5, "color": 1, "frame": "bronze"}]
	pg.refresh()
	var froot := pg.modal["root"] as Control
	check(froot.find_child("FriendCode", true, false) != null and _count_avatars(froot) >= 3, "Freunde online: Code, Suche, Anfragen, Freunde")
	check(_min_width(froot) <= 700.0, "Freunde-Seite online passt auf 720 px (%.0f)" % _min_width(froot))
	pg.open("lobby")
	await _process_frames(1)
	NetworkManager.friends = friends_data.duplicate(true)
	NetworkManager.invites = invites_data.duplicate(true)
	pg.refresh()
	var lroot := pg.modal["root"] as Control
	check(lroot.find_child("CodeEdit", true, false) != null, "Lobby online: Erstellen / Beitreten mit Code")
	check(_min_width(lroot) <= 700.0, "Lobby-Start online passt auf 720 px (%.0f)" % _min_width(lroot))
	NetworkManager.lobby = {"code": "AB12", "host_id": me, "world": "volcano", "rounds": 5}
	NetworkManager.roster = [
		{"id": me, "name": "WebHeld", "color": 1, "frame": "gold", "trophies": 777},
		{"id": "f1", "name": "Kumpel", "color": 2, "frame": "silver", "trophies": 420},
	]
	pg.refresh()
	lroot = pg.modal["root"] as Control
	check(lroot.find_child("RoomCode", true, false) != null and _count_avatars(lroot) >= 2, "Lobby online: Raum mit Spielern")
	check(_min_width(lroot) <= 700.0, "Lobby-Raum (Host) passt auf 720 px (%.0f)" % _min_width(lroot))
	NetworkManager.lobby["host_id"] = "f1"
	pg.refresh()
	check(_min_width(pg.modal["root"] as Control) <= 700.0, "Lobby-Raum (Gast) passt auf 720 px")
	NetworkManager.lobby = {}
	NetworkManager.roster = []
	NetworkManager.friends = []
	NetworkManager.invites = []
	pg.close_all()
	host.queue_free()
	await _process_frames(2)

func _stage_auth_mock() -> void:
	print("[SMOKE] Stage: Anmelde-Ablauf gegen lokalen Schein-Server")
	var mock := MockSupabase.new()
	add_child(mock)
	check(mock.start(), "Schein-Server startet auf 127.0.0.1")
	if mock.port == 0:
		return
	var saved_url: String = AuthManager.url
	var saved_key: String = AuthManager.anon_key
	AuthManager.clear_saved_session()
	GameManager.reset_progress()
	GameManager.data["account_id"] = ""
	AuthManager.url = mock.base_url()
	AuthManager.anon_key = "test-anon-key-0123456789abcdef"
	check(AuthManager.is_configured(), "Test-Server gilt als konfiguriert")
	await AuthManager.auto_login()
	check(AuthManager.user_id == MockSupabase.GUEST_ID and AuthManager.is_anonymous, "Gast-Login (anonyme Session)")
	check(AuthManager.load_saved_refresh_token() == "rt-guest", "Gast-Session gespeichert")
	var ok_guest: bool = await _wait_until(func() -> bool: return str(GameManager.data.get("account_id", "")) == MockSupabase.GUEST_ID, 240)
	check(ok_guest, "Gast-Spielstand dem Gast-Account zugeordnet")
	var ok_code: bool = await _wait_until(func() -> bool: return NetworkManager.friend_code == "GASTFRND", 240)
	check(ok_code, "Freundes-Code aus dem Profil")
	# Fortschritt als Gast, dann Web-Account per Code
	GameManager.grant({"trophies": 50})
	var bad: Dictionary = await AuthManager.redeem_web_code("ZZZZ9999")
	check(not bool(bad["ok"]) and AuthManager.user_id == MockSupabase.GUEST_ID, "Falscher Code: bleibt Gast")
	var r: Dictionary = await AuthManager.redeem_web_code("abcd-2345")
	print("[SMOKE] Code einloesen: ", r)
	check(bool(r["ok"]) and AuthManager.user_id == MockSupabase.WEB_ID and not AuthManager.is_anonymous, "Web-Code: mit Web-Account angemeldet")
	check(AuthManager.email == MockSupabase.WEB_EMAIL and AuthManager.load_saved_refresh_token() == "rt-web", "Eigene Session des Spiels gespeichert")
	var ok_web: bool = await _wait_until(func() -> bool: return GameManager.trophies() == 777, 240)
	check(ok_web and str(GameManager.data["account_id"]) == MockSupabase.WEB_ID, "Spielstand des Web-Accounts geladen")
	check(GameManager.player_name() == "WebHeld", "Name aus dem Web-Portal uebernommen")
	check(GameManager.pass_xp() == 450 and GameManager.pass_claimed(0) and not GameManager.pass_claimed(1), "Battle-Pass-Stand aus dem Cloud-Spielstand")
	check(_count_backups() > 0, "Gast-Fortschritt vor dem Wechsel gesichert")
	var ok_pic: bool = await _wait_until(func() -> bool: return ProfileManager.avatar_texture != null, 240)
	check(ok_pic and ProfileManager.avatar_path.begins_with(MockSupabase.WEB_ID + "/"), "Profilbild vom Server geladen")
	check(mock.requests_log.has("POST /rest/v1/rpc/redeem_game_link_code"), "Code wurde per RPC eingeloest")
	await _check_online_pages()
	# Abmelden ohne Gast-Neustart
	AuthManager.sign_out(false)
	check(AuthManager.user_id == "" and not FileAccess.file_exists(AuthManager.AUTH_PATH), "Abmelden verwirft die Session")
	print("[SMOKE] Server-Aufrufe: ", ", ".join(mock.requests_log))
	await _process_frames(5)
	AuthManager.url = saved_url
	AuthManager.anon_key = saved_key
	ProfileManager.clear_avatar()
	GameManager.reset_progress()
	GameManager.data["account_id"] = ""
	mock.queue_free()
	await _process_frames(2)
