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
	var hvp := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
	var topr: Rect2 = m.hud._top_box.get_global_rect()
	var botr: Rect2 = m.hud._bottom_box.get_global_rect()
	if not hvp.grow(1.0).encloses(topr) or not hvp.grow(1.0).encloses(botr) or topr.end.y >= botr.position.y:
		print("[SHOTS][FAIL] HUD-Layout: oben ", topr, " unten ", botr, " Bild ", hvp)
	else:
		print("[SHOTS] HUD-Layout geprueft: oben ", topr, " unten ", botr)
	# Rangliste: schmale Liste in der Ecke links oben, unter der Info-Zeile, weit ueber der Bedienung
	var br: Rect2 = m.hud.board_rect()
	if br.size.x <= 0.0 or br.position.x > 24.0 or br.end.x > hvp.size.x * 0.34 or br.position.y < topr.end.y or br.end.y > hvp.size.y * 0.3:
		print("[SHOTS][FAIL] Rangliste nicht in der Ecke links oben: ", br, " (Leiste ", topr, ")")
	else:
		print("[SHOTS] Rangliste links oben: ", br, " mit ", m.hud._board.get_child_count(), " Plaetzen")
	var screen: Vector2 = m.rig.target_screen_pos()
	# Top-Down-Blick im echten Hochformat: steil von oben, Ball im unteren Teil des Bildes
	var depression: float = m.rig.view_depression_deg()
	if screen == Vector2.INF or screen.y < hvp.size.y * 0.55 or depression < 35.0:
		print("[SHOTS][FAIL] Kamera: Ball bei %s, Blick %.0f Grad nach unten (erwartet: unteres Bild, >= 35 Grad)" % [screen, depression])
	else:
		print("[SHOTS] Kamera: Ball bei %.0f %% der Bildhoehe, Blick %.0f Grad nach unten" % [screen.y / hvp.size.y * 100.0, depression])
	if screen != Vector2.INF:
		m._touch_down(0, screen)
		m._touch_move(0, screen + Vector2(40.0, 260.0), Vector2(40.0, 260.0))
		# Ziel-Zoom und Tiefenunschaerfe einfahren lassen
		for i in 40:
			await get_tree().process_frame
		await _capture("game_aim")
		_check_aim_layout(m, hvp)
		# Chip: Punkte entlang des Flugbogens (Billboards) + Schatten am Boden + Aufsetz-Ring
		m.hud.set_chip_mode(true)
		for i in 30:
			await get_tree().process_frame
		await _capture("game_aim_chip")
		m.hud.set_chip_mode(false)
		m._cancel_aim()
	# Nahaufnahme des eigenen Balls: sind die Dellen (Dimples) und der Klarlack zu sehen?
	if m.local != null and m.local.ball != null:
		var bp: Vector3 = m.local.ball.global_position
		var close := Camera3D.new()
		close.fov = 30.0
		close.near = 0.02
		m.add_child(close)
		close.global_position = bp + Vector3(0.75, 0.45, 1.0)
		close.look_at(bp, Vector3.UP)
		close.current = true
		for i in 6:
			await get_tree().process_frame
		await _capture("ball_closeup")
		close.queue_free()
		m.rig.camera.current = true
	# Mitten auf der Bahn: Ball rollt geradeaus ein Stueck (unter den ersten Aesten durch), dann die echte
	# Spielkamera. Baumkronen sind reine Optik (kein Strahl-Test moeglich) -> Bild ansehen.
	if m.local != null and m.local.ball != null and m._can_aim():
		var fwd: Vector3 = -m.course.tee.basis.z
		m.local.ball.shoot(Vector3(fwd.x, 0.0, fwd.z).normalized(), 0.55, false, Vector2.ZERO)
		for i in 900:
			await get_tree().process_frame
			if i > 20 and m.local.ball.state != Ball3D.State.MOVING:
				break
		# Kamera prueft die Sicht nach ~0,8 s Ruhe und gleitet dann ~1 s zur freien Neigung
		for i in 110:
			await get_tree().process_frame
		await _capture("game_follow")
		var cam_p: Vector3 = m.rig.camera.global_position
		var bp2: Vector3 = m.local.ball.global_position
		var ex: Array[RID] = [m.local.ball.get_rid()]
		var q := PhysicsRayQueryParameters3D.create(cam_p, bp2, CameraManager3D.VIEW_MASK, ex)
		var hit2: Dictionary = m.get_world_3d().direct_space_state.intersect_ray(q)
		var bs: Vector2 = m.rig.camera.unproject_position(bp2)
		var info: String = "Ball %.1f m vom Abschlag, am Bildschirm %s (%.0f %% Hoehe), Zustand %d, Neigung %.2f (Spieler %.2f), Strahl Kamera->Ball %s" % [
			bp2.distance_to(m.course.tee.origin), bs, bs.y / hvp.size.y * 100.0, m.local.ball.state, m.rig.effective_pitch(), m.rig.pitch,
			"frei" if hit2.is_empty() else "trifft %s bei %s" % [(hit2["collider"] as Node).name, hit2["position"]]]
		if hit2.is_empty() and hvp.has_point(bs):
			print("[SHOTS] Mitten auf der Bahn: " + info)
		else:
			print("[SHOTS][FAIL] Mitten auf der Bahn ist der ruhende Ball verdeckt oder nicht im Bild: " + info)
	m.rig.set_top(true)
	for i in 50:
		await get_tree().process_frame
	await _capture("game_top")
	m.queue_free()
	await get_tree().process_frame

## Beim Zielen im echten Hochformat: Griff des Zug-Pfeils bei VOLLER Kraft (gerader Zug) im Bild und ueber dem Hinweis,
## Kraft-Anzeige sichtbar, ganz im Bild und direkt am Ball, kein Kraftbalken am unteren Rand.
func _check_aim_layout(m: Match3D, hvp: Rect2) -> void:
	var cam: Camera3D = m.rig.camera
	var ball_pos: Vector3 = m.local.ball.global_position
	var back := Vector3(-m._aim_dir.x, 0.0, -m._aim_dir.z).normalized()
	var tail: Vector3 = ball_pos + Vector3(0.0, -Ball3D.RADIUS + 0.05, 0.0) + back * Match3D.BAND_MAX
	var tail_s: Vector2 = cam.unproject_position(tail)
	var hint_top: float = m.hud._hint.get_global_rect().position.y if m.hud._hint.text != "" else hvp.size.y
	var ok_tail: bool = not cam.is_position_behind(tail) and hvp.grow(-4.0).has_point(tail_s) and tail_s.y < hint_top
	var chip: Rect2 = m.hud._power_chip.get_global_rect()
	var ball_s: Vector2 = cam.unproject_position(ball_pos)
	var ok_chip: bool = m.hud._power_chip.visible and hvp.encloses(chip) and chip.get_center().distance_to(ball_s) < hvp.size.y * 0.12
	var no_bar: bool = m.hud._root.find_child("PowerPanel", true, false) == null
	# Schraeger Zug (+-40 Grad): wo landet der Griff bei voller Kraft? (nur Hinweis - dort liegt ohnehin der Finger)
	for ang in [-40.0, 40.0]:
		var bd: Vector3 = back.rotated(Vector3.UP, deg_to_rad(ang))
		var ts: Vector2 = cam.unproject_position(ball_pos + Vector3(0.0, -Ball3D.RADIUS + 0.05, 0.0) + bd * Match3D.BAND_MAX)
		var under: Array = []
		for c: Control in [m.hud._mode_btn, m.hud._spin_pad, m.hud._emote_btn]:
			if c.get_global_rect().has_point(ts):
				under.append(c.name)
		print("[SHOTS] Zielen schraeg %+.0f Grad: Pfeil-Griff bei voller Kraft bei %s, im Bild=%s, unter %s" % [ang, ts, hvp.has_point(ts), under])
	if ok_tail and ok_chip and no_bar:
		print("[SHOTS] Zielen: Pfeil-Griff (volle Kraft) bei %s ueber dem Hinweis (%.0f), Kraft-Anzeige %s am Ball %s" % [tail_s, hint_top, chip, ball_s])
	else:
		print("[SHOTS][FAIL] Zielen: Pfeil-Griff %s (Hinweis ab %.0f), Kraft-Anzeige %s sichtbar=%s, Ball %s, Kraftbalken weg=%s" % [tail_s, hint_top,
			chip, m.hud._power_chip.visible, ball_s, no_bar])

func _course_camera(c: Course3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.far = 800.0
	add_child(cam)
	var center: Vector3 = c.bounds.get_center()
	var ext: float = maxf(c.bounds.size.x, c.bounds.size.z) * 0.5 + 8.0
	var pos: Vector3 = center + Vector3(ext * 0.75, ext * 1.0 + 6.0, ext * 1.05)
	pos.y = maxf(pos.y, c.ground_height(pos.x, pos.z) + 8.0)
	cam.global_position = pos
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
	# Spielersicht vom Abschlag: genau der Standard-Blick der Spielkamera (steil von oben, Blick voraus)
	var tee: Transform3D = c.tee
	var ball_p: Vector3 = tee.origin + Vector3.UP * Ball3D.RADIUS
	var pose: Dictionary = CameraManager3D.default_pose(ball_p, -tee.basis.z)
	var eye: Vector3 = pose["pos"]
	eye.y = maxf(eye.y, c.ground_height(eye.x, eye.z) + 2.2)
	cam.global_position = eye
	cam.look_at(pose["look"], Vector3.UP)
	cam.fov = float(pose["fov"])
	for i in 6:
		await get_tree().process_frame
	# Verdeckt etwas (Ast, Tor, Fels) den Ball aus der steilen Sicht? (nur Hinweis, kein Fehler)
	var ray := PhysicsRayQueryParameters3D.create(eye, ball_p)
	var hit: Dictionary = c.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty() and (hit["position"] as Vector3).distance_to(ball_p) > Ball3D.RADIUS * 2.5:
		print("[SHOTS] Hinweis: Abschlag %s - Sicht auf den Ball verdeckt bei %s" % [id, hit["position"]])
	await _capture("tee_" + id)
	# Abkuerzung: vom Tor ueber den Steg Richtung Gruen
	if not c.shortcut.is_empty():
		var g: Vector3 = c.shortcut["gate"]
		var d: Vector3 = c.shortcut["dir"]
		cam.global_position = g - d * 5.0 + Vector3.UP * 4.0
		cam.look_at((c.shortcut["landing"] as Vector3).lerp(g, 0.35), Vector3.UP)
		for i in 6:
			await get_tree().process_frame
		await _capture("shortcut_" + id)
	# Kulisse aus der Naehe: Ruine (falls vorhanden) mit Wald dahinter
	var ruin: Node3D = c.find_child("Ruin1", true, false) as Node3D
	if ruin != null and ruin.get_child_count() > 0:
		var rp: Vector3 = (ruin.get_child(0) as Node3D).global_position
		var from: Vector3 = rp + (c.bounds.get_center() - rp).normalized() * 11.0
		from.y = c.ground_height(from.x, from.z) + 3.0
		cam.global_position = from
		cam.look_at(rp + Vector3.UP * 2.0, Vector3.UP)
		cam.fov = 60.0
		for i in 6:
			await get_tree().process_frame
		await _capture("ruin_" + id)
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
	# Trails (live 3D-Vorschau mit Partikeln) und Avatar-Rahmen
	GameManager.grant({"items": [{"kind": "trail", "id": "fire"}, {"kind": "trail", "id": "rainbow"}]})
	for kind in ["trail", "frame"]:
		menu.pages._sel_kind = kind
		menu.pages.open("cosmetics")
		for i in 40:
			await get_tree().process_frame
		await _capture("page_cosmetics_" + kind)
	menu.pages._sel_kind = "ball"
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
