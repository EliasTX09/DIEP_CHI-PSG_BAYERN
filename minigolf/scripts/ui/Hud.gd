class_name Hud
extends CanvasLayer
## Responsives Touch-HUD: oben Bahn/Par/Timer/Schlaege, Spielerliste, unten Kraft-Anzeige + Spin-Slider.

signal spin_changed(value: float)
signal exit_pressed
signal continue_pressed

var _top: Label
var _timer: Label
var _players: Label
var _toast: Label
var _power: ProgressBar
var _spin: HSlider
var _overlay: PanelContainer
var _overlay_text: Label
var _overlay_btn: Button
var _course_name: String = ""
var _index: int = 0
var _par: int = 3
var _sd: bool = false

func _ready() -> void:
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIKit.make_theme()
	add_child(root)

	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 16; top.offset_right = -16; top.offset_top = 12
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	_top = UIKit.label("", 28)
	_top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_top)
	_timer = UIKit.label("45", 40)
	top.add_child(_timer)
	var exit := UIKit.button("✕", func(): exit_pressed.emit())
	exit.custom_minimum_size = Vector2(72, 64)
	exit.size_flags_horizontal = Control.SIZE_SHRINK_END
	top.add_child(exit)

	_players = UIKit.label("", 24)
	_players.position = Vector2(16, 80)
	_players.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_players)

	_toast = UIKit.label("", 44, true)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 220; _toast.offset_left = -300; _toast.offset_right = 300
	_toast.modulate.a = 0.0
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24; bottom.offset_right = -24; bottom.offset_bottom = -24; bottom.offset_top = -170
	root.add_child(bottom)
	_power = ProgressBar.new()
	_power.max_value = 1.0
	_power.custom_minimum_size = Vector2(0, 34)
	_power.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(_power)
	var row := HBoxContainer.new()
	bottom.add_child(row)
	row.add_child(UIKit.label("Spin", 26))
	_spin = HSlider.new()
	_spin.min_value = -1.0; _spin.max_value = 1.0; _spin.step = 0.05; _spin.value = 0.0
	_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spin.custom_minimum_size = Vector2(0, 64)
	_spin.value_changed.connect(func(v: float): spin_changed.emit(v))
	row.add_child(_spin)
	var rst := UIKit.button("0", func(): _spin.value = 0.0)
	rst.custom_minimum_size = Vector2(72, 64)
	rst.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(rst)

	_overlay = PanelContainer.new()
	_overlay.set_anchors_preset(Control.PRESET_CENTER)
	_overlay.offset_left = -300; _overlay.offset_right = 300; _overlay.offset_top = -260; _overlay.offset_bottom = 260
	_overlay.visible = false
	var ov := VBoxContainer.new()
	_overlay.add_child(ov)
	_overlay_text = UIKit.label("", 30, true)
	_overlay_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ov.add_child(_overlay_text)
	_overlay_btn = UIKit.button("Weiter", func(): continue_pressed.emit())
	_overlay_btn.visible = false
	ov.add_child(_overlay_btn)
	root.add_child(_overlay)

func setup_hole(course_id: String, index: int, par: int, sudden_death: bool) -> void:
	_course_name = CourseData.get_course(course_id)["name"]
	_index = index; _par = par; _sd = sudden_death
	_overlay.visible = false
	_spin.value = 0.0
	refresh_players()

func on_state(s: int) -> void:
	if s == GameManager.State.SHOT_PHASE or s == GameManager.State.SUDDEN_DEATH:
		_overlay.visible = false
		toast("Sudden Death!" if s == GameManager.State.SUDDEN_DEATH else "Los!")

func set_time(t: float) -> void:
	_timer.text = str(maxi(0, ceili(t)))

func set_power(p: float) -> void:
	_power.value = p

func refresh_players() -> void:
	var local: Dictionary = GameManager.players.get(GameManager.local_id, {"strokes": 0})
	_top.text = ("Sudden Death – Pin-Schuss" if _sd else "Bahn %d/%d  %s  (Par %d)" % [_index + 1, GameManager.course_ids.size(), _course_name, _par]) \
		+ "\nSchlaege: %d" % int(local["strokes"])
	var lines: PackedStringArray = []
	for p in GameManager.players.values():
		var mark := "✔" if p["finished"] else "·"
		lines.append("%s %s  %d (Σ %d)" % [mark, p["name"], p["strokes"], p["total"]])
	_players.text = "\n".join(lines)

func toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)

func show_hole_summary(summary: Array) -> void:
	var s := "Ergebnis Bahn %d\n\n" % (_index + 1)
	for e in summary:
		s += "%s: %d Schlaege (gesamt %d)\n" % [e["name"], e["hole_score"], e["total"]]
	_overlay_text.text = s
	_overlay_btn.visible = false
	_overlay.visible = true

func show_match_result(ranking: Array) -> void:
	var s := "MATCH VORBEI\n\n"
	for r in ranking:
		var p: Dictionary = GameManager.players[r["id"]]
		s += "%d. %s – %d Schlaege" % [r["rank"], p["name"], r["total"]]
		if r["id"] == GameManager.sd_winner:
			s += "  (Sudden Death)"
		if r.has("reward"):
			s += "  +%d 🪙" % r["reward"]
		s += "\n"
	_overlay_text.text = s
	_overlay_btn.visible = true
	_overlay.visible = true
