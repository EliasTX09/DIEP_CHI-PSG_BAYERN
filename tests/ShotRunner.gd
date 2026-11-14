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
		await _shot_menu()
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
	# Kacheln im Seitenverhaeltnis des Fensters (Hochformat: 180 x 320), 4 x 4 Raster
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var tile := Vector2i(180, 320) if vp.y >= vp.x else Vector2i(320, 180)
	var sheet := Image.create(tile.x * 4, tile.y * 4, false, Image.FORMAT_RGB8)
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
			img.resize(tile.x, tile.y, Image.INTERPOLATE_BILINEAR)
			sheet.blit_rect(img, Rect2i(Vector2i.ZERO, tile), Vector2i((idx % 4) * tile.x, (idx / 4) * tile.y))
		print("[SHOTS] Bahn ", id, " gerendert")
		idx += 1
		cam.queue_free()
		c.queue_free()
		await get_tree().process_frame
	var file := ProjectSettings.globalize_path(OUT_DIR.path_join("sheet_courses.jpg"))
	print("[SHOTS] sheet_courses -> ", file, " (", sheet.save_jpg(file, 0.85), ")")

## Hauptmenue im Hochformat: normales Handy (720 x 1280) und hohes Handy (720 x 1600), jeweils mit Layout-Pruefung.
func _shot_menu() -> void:
	var menu := (load("res://scenes/MainMenuView.tscn") as PackedScene).instantiate() as MainMenuView
	add_child(menu)
	for i in 40:
		await get_tree().process_frame
	_check_menu_layout(menu, "720x1280")
	await _capture("menu")
	var win := get_window()
	var old: Vector2i = win.size
	win.size = Vector2i(720, 1600)
	for i in 20:
		await get_tree().process_frame
	print("[SHOTS] Hohes Handy: Viewport ", get_viewport().get_visible_rect().size)
	_check_menu_layout(menu, "720x1600")
	await _capture("menu_tall")
	win.size = old
	for i in 10:
		await get_tree().process_frame
	menu.select_world("volcano")
	for i in 40:
		await get_tree().process_frame
	await _capture("menu_volcano")
	menu.select_world("emerald")
	menu.queue_free()
	await get_tree().process_frame

## Prueft, dass alle Bausteine im Bild liegen und sich nicht ueberlappen; Fehler -> [SHOTS][FAIL] (laesst die CI scheitern).
func _check_menu_layout(menu: MainMenuView, tag: String) -> void:
	var vp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var names: Array[String] = ["TopBar", "ArenaBanner", "ShowcaseSlot", "PlayButton", "ChestRow", "NavBar"]
	var rects: Array[Rect2] = []
	for n in names:
		var c := menu.ui.find_child(n, true, false) as Control
		if c == null:
			print("[SHOTS][FAIL] ", tag, ": ", n, " fehlt")
			return
		var r: Rect2 = c.get_global_rect()
		rects.append(r)
		if not vp.grow(1.0).encloses(r):
			print("[SHOTS][FAIL] ", tag, ": ", n, " ragt aus dem Bild ", r, " / ", vp)
	for i in range(1, rects.size()):
		if rects[i - 1].end.y > rects[i].position.y + 0.5:
			print("[SHOTS][FAIL] ", tag, ": ", names[i - 1], " ueberlappt ", names[i])
	if rects[0].position.y < 0.0 or rects[5].end.y > vp.size.y + 0.5:
		print("[SHOTS][FAIL] ", tag, ": Leisten ausserhalb")
	if rects[3].position.y < vp.size.y * 0.5:
		print("[SHOTS][FAIL] ", tag, ": SPIELEN nicht in der unteren Haelfte")
	if rects[2].size.y < 200.0:
		print("[SHOTS][FAIL] ", tag, ": zu wenig Platz fuer die Vitrine (", rects[2].size.y, ")")
	print("[SHOTS] Layout ", tag, " geprueft: Vitrine ", rects[2])

## Menue-Seiten (Tabs und Fenster) nacheinander oeffnen, Breite pruefen und abfotografieren.
func _shot_pages() -> void:
	var menu := (load("res://scenes/MainMenuView.tscn") as PackedScene).instantiate() as MainMenuView
	add_child(menu)
	for i in 20:
		await get_tree().process_frame
	GameManager.add_chest("silver")
	GameManager.add_chest("wood")
	GameManager.start_unlock(0)
	GameManager.add_pass_xp(4 * Catalog.PASS_XP_PER_TIER + 60)
	GameManager.pass_claim(0)
	var vw: float = get_viewport().get_visible_rect().size.x
	for page_id in ["play", "clubs", "cosmetics", "pass", "shop", "trophies", "settings", "friends", "leaderboard", "lobby"]:
		menu.pages.open(page_id)
		for i in 14:
			await get_tree().process_frame
		var root := menu.pages.modal["root"] as Control
		for c in root.find_children("*", "Control", true, false):
			var cc := c as Control
			if cc.is_visible_in_tree() and cc.get_global_rect().end.x > vw + 1.0 and not _inside_scroll(cc):
				print("[SHOTS][FAIL] Seite ", page_id, ": ", cc.name, " ragt rechts hinaus ", cc.get_global_rect())
				break
		await _capture("page_" + page_id)
	menu.pages.close_all()
	menu.pages.open("clubs")
	for i in 6:
		await get_tree().process_frame
	menu.pages.open_club_detail(Catalog.START_CLUB)
	for i in 20:
		await get_tree().process_frame
	await _capture("page_club_detail")
	menu.pages.close_all()
	while menu.pages.any_modal_open():
		menu.pages.close_top()
		await get_tree().process_frame
	menu.pages.show_rewards("Silbertruhe", GameManager.roll_chest("silver"))
	for i in 50:
		await get_tree().process_frame
	await _capture("page_rewards")
	menu.queue_free()
	await get_tree().process_frame

func _inside_scroll(c: Control) -> bool:
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return false if (p as ScrollContainer).get_global_rect().end.x <= get_viewport().get_visible_rect().size.x + 1.0 else true
		p = p.get_parent()
	return false

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
	# Seitenverhaeltnis beibehalten (Hochformat: 540 x 960)
	var target_h: int = 960 if img.get_height() >= img.get_width() else 540
	img.resize(int(round(float(img.get_width()) * float(target_h) / float(img.get_height()))), target_h, Image.INTERPOLATE_BILINEAR)
	var file := ProjectSettings.globalize_path(OUT_DIR.path_join(shot_name + ".jpg"))
	var err := img.save_jpg(file, 0.8)
	print("[SHOTS] ", shot_name, " -> ", file, " (", err, ")")
