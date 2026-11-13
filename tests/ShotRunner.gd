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
	if _wanted("sheet"):
		await _course_sheet()
	for id in Catalog.all_course_ids():
		if _filter.has(id):
			await _shot_course(id)
	if _filter.has("daily"):
		await _shot_course("daily")

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
