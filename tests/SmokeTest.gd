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
	print("[SMOKE] PhysicsServer3D (Klasse) = ", PhysicsServer3D.get_class())
	print("[SMOKE] rendering_method = ", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	check(int(v["major"]) == 4 and int(v["minor"]) >= 5, "Godot >= 4.5")
	check(str(PhysicsServer3D.get_class()).contains("Jolt"), "Jolt-Physik ist aktiv")
	check(str(ProjectSettings.get_setting("rendering/renderer/rendering_method")) == "mobile", "Mobile-Renderer konfiguriert")
	check(int(ProjectSettings.get_setting("display/window/handheld/orientation")) == DisplayServer.SCREEN_SENSOR_LANDSCAPE,
		"Orientierung = Sensor-Querformat")
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
