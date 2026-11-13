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
