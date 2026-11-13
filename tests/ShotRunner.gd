extends Node
## Screenshot-Runner fuer die CI (Software-Rendering unter Xvfb):
##   godot --rendering-driver vulkan --fixed-fps 30 res://tests/Shots.tscn -- --shots=menu,e1
## Kompiliert dabei alle Shader wirklich (headless tut das nicht) und legt JPEGs in ci_out/shots ab.

const OUT_DIR := "res://ci_out/shots"
var _filter: PackedStringArray = PackedStringArray()

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			var list := a.trim_prefix("--shots=")
			if list != "" and list != "all":
				_filter = list.split(",", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	print("[SHOTS] Adapter: ", RenderingServer.get_video_adapter_name(), " | API: ", RenderingServer.get_video_adapter_api_version(),
		" | RenderingDevice: ", RenderingServer.get_rendering_device() != null)
	await _run()
	print("[SHOTS] DONE")
	get_tree().quit(0)

func _wanted(shot_name: String) -> bool:
	return _filter.is_empty() or _filter.has(shot_name)

func _run() -> void:
	if _wanted("menu"):
		await _shot_scene("menu", "res://scenes/MainMenu3D.tscn", 30)
	if _wanted("pages"):
		await _shot_pages()
	if _wanted("sheet"):
		await _course_sheet()
	for id in Catalog.all_course_ids():
		if _filter.has(id):
			await _shot_course(id)
	if _filter.has("daily"):
		await _shot_course("daily")
	if _wanted("game"):
		await _shot_game()

## Spielszene mit HUD: einmal normal, einmal waehrend des Zielens (Kraftpfeil + Vorschau).
func _shot_game() -> void:
	var cfg: Dictionary = GameManager.make_bot_match("emerald", 3, 3)
	cfg["courses"] = ["e2"]
	GameManager.match_config = cfg
	var scene: PackedScene = load("res://scenes/Game.tscn")
	var m := scene.instantiate() as Match3D
	add_child(m)
	for i in 400:
		await get_tree().process_frame
		if m.phase == Match3D.Phase.PLAY and m.phase_time > 1.2:
			break
	await _capture("game_hud")
	var screen: Vector2 = m.rig.target_screen_pos()
	if screen != Vector2.INF:
		m._touch_down(0, screen)
		m._touch_move(0, screen + Vector2(30.0, 150.0), Vector2(30.0, 150.0))
		for i in 6:
			await get_tree().process_frame
		await _capture("game_aim")
		m._cancel_aim()
	m.rig.set_top(true)
	for i in 50:
		await get_tree().process_frame
	await _capture("game_top")
	m.queue_free()
	await get_tree().process_frame

func _course_camera(c: Course3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 800.0
	add_child(cam)
	var center: Vector3 = c.bounds.get_center()
	var ext: float = maxf(c.bounds.size.x, c.bounds.size.z) * 0.5 + 8.0
	cam.global_position = center + Vector3(ext * 0.75, ext * 1.0 + 6.0, ext * 1.05)
	cam.look_at(center, Vector3.UP)
	cam.current = true
	return cam

func _shot_course(id: String) -> void:
	var c: Course3D = CourseBuilder3D.build(id, 4242, true)
	add_child(c)
	var cam := _course_camera(c)
	for i in 14:
		await get_tree().process_frame
	await _capture("course_" + id)
	cam.queue_free()
	c.queue_free()
	await get_tree().process_frame

## Alle Bahnen als Kontaktbogen (4 x 4 Kacheln) in einem Bild.
func _course_sheet() -> void:
	var ids: Array[String] = Catalog.all_course_ids()
	ids.append("daily")
	var sheet := Image.create(1280, 720, false, Image.FORMAT_RGB8)
	var idx := 0
	for id in ids:
		var c: Course3D = CourseBuilder3D.build(id, 4242, true)
		add_child(c)
		var cam := _course_camera(c)
		for i in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		if img != null and not img.is_empty():
			img.convert(Image.FORMAT_RGB8)
			img.resize(320, 180, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(0, 0, 320, 180), Vector2i((idx % 4) * 320, (idx / 4) * 180))
		print("[SHOTS] Bahn ", id, " gerendert")
		idx += 1
		cam.queue_free()
		c.queue_free()
		await get_tree().process_frame
	var file := ProjectSettings.globalize_path(OUT_DIR.path_join("sheet_courses.jpg"))
	print("[SHOTS] sheet_courses -> ", file, " (", sheet.save_jpg(file, 0.85), ")")

## Menue-Seiten nacheinander oeffnen und abfotografieren.
func _shot_pages() -> void:
	var ps: PackedScene = load("res://scenes/MainMenu3D.tscn")
	var menu := ps.instantiate() as MainMenu3D
	add_child(menu)
	for i in 20:
		await get_tree().process_frame
	GameManager.add_chest("silver")
	GameManager.add_chest("wood")
	GameManager.start_unlock(0)
	for page_id in ["play", "clubs", "cosmetics", "shop", "trophies", "settings", "friends", "leaderboard"]:
		menu.pages.open(page_id)
		for i in 12:
			await get_tree().process_frame
		await _capture("page_" + page_id)
	menu.pages.close()
	menu.pages.show_rewards("Silbertruhe", GameManager.roll_chest("silver"))
	for i in 50:
		await get_tree().process_frame
	await _capture("page_rewards")
	menu.queue_free()
	await get_tree().process_frame

func _shot_scene(shot_name: String, path: String, frames: int) -> void:
	var ps: PackedScene = load(path)
	if ps == null:
		print("[SHOTS][FAIL] Szene fehlt: ", path)
		return
	var inst := ps.instantiate()
	add_child(inst)
	for i in frames:
		await get_tree().process_frame
	await _capture(shot_name)
	inst.queue_free()
	await get_tree().process_frame

func _capture(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		print("[SHOTS][FAIL] Kein Bild fuer ", shot_name)
		return
	img.resize(960, 540, Image.INTERPOLATE_BILINEAR)
	var file := ProjectSettings.globalize_path(OUT_DIR.path_join(shot_name + ".jpg"))
	var err := img.save_jpg(file, 0.8)
	print("[SHOTS] ", shot_name, " -> ", file, " (", err, ")")
