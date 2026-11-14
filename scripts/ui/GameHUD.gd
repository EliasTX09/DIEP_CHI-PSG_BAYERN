class_name GameHUD
extends CanvasLayer
## Spiel-HUD im Hochformat (Safe-Area-bewusst, einhaendig):
## - oben: Bahn-Info + Timer + Vogelperspektive/Verlassen in einer Zeile, darunter die Live-Rangliste als Chips,
##   darunter die Status-Pille (Warten / Replay) - alles in einer Spalte, nichts ueberlappt.
## - unten (Daumenzone): Emote-Knopf links, Hinweis + Kraftanzeige in der Mitte, Schlagart + Spin-Regler rechts.
## - Banner/Style-Popups in der Bildmitte, Bahn- und Match-Ergebnis als Fenster.
## Die Touch-Steuerung der 3D-Ansicht (Zielen, Kamera) liegt in Match3D; das HUD faengt nur seine eigenen Widgets ab.

signal top_view_toggled(enabled: bool)
signal emote_chosen(emote_id: String)
signal exit_requested
signal continue_pressed
signal skip_pressed

## Spin-Auswahl: x = Side (-1 links .. +1 rechts), y = Top (+1) / Back (-1).
var spin: Vector2 = Vector2.ZERO
## true = Chip (hoher Schlag), false = Rollen (Putt).
var chip_mode: bool = false

var _root: Control
var _safe: MarginContainer
var _board: HFlowContainer
var _top_box: VBoxContainer
var _bottom_box: HBoxContainer
var _exit_btn: Button
var _emote_btn: Button
var _info_title: Label
var _info_sub: Label
var _timer: Label
var _top_btn: Button
var _mode_btn: Button
var _mode_icon: UIIcon
var _spin_pad: SpinPad
var _power_panel: PanelContainer
var _power_bar: ProgressBar
var _power_label: Label
var _hint: Label
var _banner: Label
var _banner_sub: Label
var _status_pill: PanelContainer
var _status_label: Label
var _emote_wheel: PanelContainer
var _overlay: Control = null
var _top_on: bool = false
var _banner_tween: Tween = null
## Aktuelle Meldung (immer nur eine, direkt unter der oberen Leiste - nie ueber Rangliste oder Kraftanzeige)
var _toast: PanelContainer = null

# ================================================================ Spin-Selector

## Runder Spin-Regler: Punkt verschieben = Effet waehlen (oben Topspin, unten Backspin, seitlich Side-Spin).
class SpinPad extends Control:
	signal changed(value: Vector2)
	var value: Vector2 = Vector2.ZERO
	var _dragging: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2(132, 132)
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_value(v: Vector2) -> void:
		value = v.limit_length(1.0)
		queue_redraw()
		changed.emit(value)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_dragging = (event as InputEventMouseButton).pressed
			if _dragging:
				_update((event as InputEventMouseButton).position)
			accept_event()
		elif event is InputEventMouseMotion and _dragging:
			_update((event as InputEventMouseMotion).position)
			accept_event()

	func _update(local: Vector2) -> void:
		var r: float = minf(size.x, size.y) * 0.5 - 14.0
		var v: Vector2 = (local - size * 0.5) / maxf(1.0, r)
		v.y = -v.y
		if v.length() < 0.16:
			v = Vector2.ZERO
		set_value(v)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 4.0
		draw_circle(c, r, Color(0.03, 0.05, 0.12, 0.85))
		draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(c, r * 0.62, Color(0.95, 0.95, 0.97))
		draw_line(c + Vector2(-r * 0.62, 0), c + Vector2(r * 0.62, 0), Color(0, 0, 0, 0.12), 1.5)
		draw_line(c + Vector2(0, -r * 0.62), c + Vector2(0, r * 0.62), Color(0, 0, 0, 0.12), 1.5)
		var font: Font = get_theme_default_font()
		draw_string(font, c + Vector2(-20, -r + 15), "TOP", HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color(1, 1, 1, 0.8))
		draw_string(font, c + Vector2(-22, r - 5), "BACK", HORIZONTAL_ALIGNMENT_CENTER, 44, 11, Color(1, 1, 1, 0.8))
		var dot: Vector2 = c + Vector2(value.x, -value.y) * (r - 10.0)
		var col := Color(1.0, 0.3, 0.3) if value != Vector2.ZERO else Color(0.3, 0.45, 0.7)
		draw_circle(dot, 11.0, Color(0, 0, 0, 0.35))
		draw_circle(dot, 9.0, col)

# ================================================================ Aufbau

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIKit.theme()
	add_child(_root)
	_safe = MarginContainer.new()
	_safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	_safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_safe)
	UIKit.apply_safe_area(_safe, 12)
	get_viewport().size_changed.connect(func() -> void: UIKit.apply_safe_area(_safe, 12))
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_safe.add_child(area)
	_build_top(area)
	_build_bottom(area)
	_build_center(area)

## Obere Spalte: Info-Zeile, Rangliste, Status.
func _build_top(area: Control) -> void:
	_top_box = UIKit.vbox(6)
	_top_box.name = "TopBox"
	_top_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_top_box)
	_top_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var row := UIKit.hbox(8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top_box.add_child(row)
	var p := UIKit.panel(Color(0.04, 0.06, 0.14, 0.82), 16, Color(1, 1, 1, 0.12), 1)
	p.name = "InfoPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(p)
	var h := UIKit.hbox(8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(UIKit.margin(h, 8, 2, 8, 2))
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_info_title = UIKit.label("", 19, UIKit.TEXT)
	_info_title.clip_text = true
	_info_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(_info_title)
	_info_sub = UIKit.label("", 16, UIKit.TEXT_DIM)
	v.add_child(_info_sub)
	h.add_child(UIIcon.new("timer", 24.0, UIKit.GOLD))
	_timer = UIKit.label("0:00", 28, UIKit.GOLD)
	_timer.custom_minimum_size = Vector2(66, 0)
	h.add_child(_timer)
	_top_btn = UIKit.icon_button("eye", UIKit.PURPLE, _on_top_pressed, 60.0)
	_top_btn.name = "TopViewButton"
	row.add_child(_top_btn)
	_exit_btn = UIKit.icon_button("exit", UIKit.RED, confirm_exit, 60.0)
	_exit_btn.name = "ExitButton"
	row.add_child(_exit_btn)
	# Live-Rangliste: Chips, 2 pro Zeile
	_board = HFlowContainer.new()
	_board.name = "Board"
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.add_theme_constant_override("h_separation", 6)
	_board.add_theme_constant_override("v_separation", 6)
	_top_box.add_child(_board)
	# Status-Pille (Warten / Replay)
	_status_pill = UIKit.panel(Color(0.6, 0.35, 0.05, 0.9), 16, Color(1, 1, 1, 0.25), 1)
	_status_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status_pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status_pill.visible = false
	_top_box.add_child(_status_pill)
	_status_label = UIKit.label("", 20, UIKit.TEXT, true)
	_status_pill.add_child(UIKit.margin(_status_label, 12, 2, 12, 2))

## Untere Zeile (Daumenzone): Emotes | Hinweis + Kraft | Schlagart + Spin.
func _build_bottom(area: Control) -> void:
	_bottom_box = UIKit.hbox(10)
	_bottom_box.name = "BottomBox"
	_bottom_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_bottom_box)
	_bottom_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom_box.alignment = BoxContainer.ALIGNMENT_END
	# Emote-Knopf unten links
	var left := UIKit.vbox(0)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.alignment = BoxContainer.ALIGNMENT_END
	_bottom_box.add_child(left)
	_emote_btn = UIKit.icon_button("emote", UIKit.GOLD.darkened(0.15), _toggle_emotes, 72.0)
	_emote_btn.name = "EmoteButton"
	left.add_child(_emote_btn)
	# Mitte: Hinweis + Kraftanzeige
	var mid := UIKit.vbox(6)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.alignment = BoxContainer.ALIGNMENT_END
	_bottom_box.add_child(mid)
	_power_panel = UIKit.panel(Color(0.04, 0.06, 0.14, 0.85), 14, Color(1, 1, 1, 0.15), 1)
	_power_panel.name = "PowerPanel"
	_power_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_power_panel.visible = false
	var ph := UIKit.hbox(8)
	_power_panel.add_child(UIKit.margin(ph, 6, 4, 6, 4))
	ph.add_child(UIIcon.new("bolt", 24.0, UIKit.GOLD))
	_power_bar = UIKit.bar(0.0, UIKit.GREEN, Vector2(0, 22))
	_power_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ph.add_child(_power_bar)
	_power_label = UIKit.label("0%", 22, UIKit.TEXT)
	_power_label.custom_minimum_size = Vector2(58, 0)
	ph.add_child(_power_label)
	mid.add_child(_power_panel)
	_hint = UIKit.wrap_label("", 19, UIKit.TEXT, true)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	mid.add_child(_hint)
	# Rechts: Schlagart + Spin
	var right := UIKit.vbox(8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_END
	_bottom_box.add_child(right)
	_mode_btn = UIKit.button("   ROLLEN", UIKit.GREEN, _on_mode_pressed, Vector2(150, 62), 20)
	_mode_btn.name = "ModeButton"
	_mode_icon = UIIcon.new("putt", 30.0)
	_mode_icon.size = Vector2(30, 30)
	_mode_icon.position = Vector2(12, 16)
	_mode_btn.add_child(_mode_icon)
	right.add_child(_mode_btn)
	var sp := UIKit.panel(Color(0.04, 0.06, 0.14, 0.7), 16, Color(1, 1, 1, 0.12), 1)
	sp.name = "SpinPanel"
	var sv := UIKit.vbox(2)
	sp.add_child(sv)
	sv.add_child(UIKit.label("SPIN", 16, UIKit.TEXT_DIM, true))
	_spin_pad = SpinPad.new()
	_spin_pad.changed.connect(func(val: Vector2) -> void: spin = val)
	sv.add_child(_spin_pad)
	right.add_child(sp)
	# Emote-Rad ueber dem Emote-Knopf
	_emote_wheel = UIKit.panel(Color(0.04, 0.06, 0.14, 0.94), 18, Color(1, 1, 1, 0.2), 2)
	_emote_wheel.name = "EmoteWheel"
	_emote_wheel.visible = false
	area.add_child(_emote_wheel)
	_emote_wheel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_emote_wheel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_emote_wheel.offset_top = -86.0
	_emote_wheel.offset_bottom = -86.0
	var grid := GridContainer.new()
	grid.columns = 3
	_emote_wheel.add_child(grid)
	for e in Catalog.EMOTES:
		var id: String = str(e["id"])
		var b := UIKit.button(str(e["text"]), UIKit.PANEL_LIGHT, _on_emote.bind(id), Vector2(128, 64), 18)
		if str(e["icon"]) != "":
			var tr := TextureRect.new()
			tr.texture = Icons.emote(str(e["icon"]))
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.size = Vector2(44, 44)
			tr.position = Vector2(42, 6)
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(tr)
		grid.add_child(b)

func _build_center(area: Control) -> void:
	var v := UIKit.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(v)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	v.offset_top = -110.0
	v.offset_bottom = -110.0
	_banner = UIKit.wrap_label("", 58, UIKit.GOLD, true)
	_banner.custom_minimum_size = Vector2(640, 0)
	_banner.add_theme_constant_override("outline_size", 14)
	_banner.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.0))
	_banner.modulate.a = 0.0
	v.add_child(_banner)
	_banner_sub = UIKit.wrap_label("", 28, UIKit.TEXT, true)
	_banner_sub.custom_minimum_size = Vector2(640, 0)
	_banner_sub.modulate.a = 0.0
	v.add_child(_banner_sub)

# ================================================================ Aktionen der Widgets

func _on_top_pressed() -> void:
	set_top_view(not _top_on)
	top_view_toggled.emit(_top_on)

## Zustand des Vogelperspektive-Buttons setzen (ohne Signal).
func set_top_view(on: bool) -> void:
	_top_on = on
	UIKit.set_button_color(_top_btn, UIKit.GOLD.darkened(0.1) if on else UIKit.PURPLE)

func _on_mode_pressed() -> void:
	set_chip_mode(not chip_mode)

func set_chip_mode(on: bool) -> void:
	chip_mode = on
	_mode_btn.text = "   CHIP" if on else "   ROLLEN"
	_mode_icon.set_kind("chip" if on else "putt")
	UIKit.set_button_color(_mode_btn, UIKit.BLUE if on else UIKit.GREEN)

func reset_spin() -> void:
	_spin_pad.set_value(Vector2.ZERO)

func _toggle_emotes() -> void:
	_emote_wheel.visible = not _emote_wheel.visible

func _on_emote(id: String) -> void:
	_emote_wheel.visible = false
	SoundManager.play("pop")
	emote_chosen.emit(id)

## Liegt der Bildschirmpunkt auf einem HUD-Widget? (Match3D startet dort keine Kamera-/Ziel-Geste.)
func is_over_widget(screen_pos: Vector2) -> bool:
	if _overlay != null and is_instance_valid(_overlay):
		return true
	for c: Control in [_mode_btn, _spin_pad, _top_btn, _exit_btn, _emote_btn, _emote_wheel]:
		if c != null and c.is_visible_in_tree() and c.get_global_rect().grow(8.0).has_point(screen_pos):
			return true
	return false

# ================================================================ Anzeigen (von Match3D aufgerufen)

func setup_hole(index: int, total: int, title: String, par: int) -> void:
	_info_title.text = "Bahn %d/%d · %s" % [index + 1, total, title]
	_info_sub.text = "Par %d" % par
	hide_overlay()
	set_status("")
	reset_spin()

func set_strokes(strokes: int, par: int) -> void:
	_info_sub.text = "Par %d · Schlag %d" % [par, strokes]

func set_time(seconds: float) -> void:
	_timer.text = UIKit.format_time(seconds)
	_timer.add_theme_color_override("font_color", UIKit.RED if seconds < 10.0 else UIKit.GOLD)

## rows: [{name, color: Color, strokes: int, total: int, holed: bool, local: bool, done: bool}]
func set_leaderboard(rows: Array) -> void:
	while _board.get_child_count() > rows.size():
		var last := _board.get_child(_board.get_child_count() - 1)
		_board.remove_child(last)
		last.queue_free()
	while _board.get_child_count() < rows.size():
		var chip := UIKit.panel(Color(0.04, 0.06, 0.14, 0.8), 12, Color(1, 1, 1, 0.12), 1)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.custom_minimum_size = Vector2(342, 0)
		var h := UIKit.hbox(6)
		h.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(UIKit.margin(h, 4, 1, 6, 1))
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 22)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(dot)
		var nm := UIKit.label("", 17)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nm.clip_text = true
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(nm)
		var st := UIKit.label("", 17, UIKit.TEXT_DIM)
		st.custom_minimum_size = Vector2(62, 0)
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(st)
		_board.add_child(chip)
	for i in rows.size():
		var row: Dictionary = rows[i]
		var h2 := _board.get_child(i).get_child(0).get_child(0) as HBoxContainer
		(h2.get_child(0) as ColorRect).color = row.get("color", Color.WHITE)
		var nm2 := h2.get_child(1) as Label
		nm2.text = "%d. %s" % [i + 1, str(row.get("name", "?"))]
		nm2.add_theme_color_override("font_color", UIKit.GOLD if bool(row.get("local", false)) else UIKit.TEXT)
		var st2 := h2.get_child(2) as Label
		if bool(row.get("done", false)) and not bool(row.get("holed", false)):
			st2.text = "DNF (%d)" % int(row.get("total", 0))
		else:
			st2.text = "%d (%d)" % [int(row.get("strokes", 0)), int(row.get("total", 0))]
		st2.add_theme_color_override("font_color", UIKit.GREEN if bool(row.get("holed", false)) else UIKit.TEXT_DIM)

func set_power(power: float, shown: bool) -> void:
	_power_panel.visible = shown
	if not shown:
		return
	_power_bar.value = power
	_power_label.text = "%d%%" % int(round(power * 100.0))
	var col: Color = UIKit.GREEN.lerp(UIKit.GOLD, clampf(power * 2.0, 0.0, 1.0)).lerp(UIKit.RED, clampf(power * 2.0 - 1.0, 0.0, 1.0))
	_power_bar.add_theme_stylebox_override("fill", UIKit.box(col, 8))

func set_hint(text: String) -> void:
	_hint.text = text

func set_status(text: String) -> void:
	_status_pill.visible = text != ""
	_status_label.text = text

## Grosser Banner in der Bildmitte (z.B. "LOS!", "EINGELOCHT!").
func show_banner(text: String, sub: String = "", seconds: float = 1.6, color: Color = UIKit.GOLD) -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_banner_sub.text = sub
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	_banner_tween = create_tween()
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 0.4)

## Style-Bonus-Popup ("AIR TIME! +60"), steigt auf und verblasst.
func popup_style(text: String, color: Color = Color(0.4, 1.0, 0.9)) -> void:
	var l := UIKit.label(text, 34, color, true)
	_root.add_child(l)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.position += Vector2(randf_range(-60.0, 60.0), 40.0 + randf_range(-20.0, 20.0))
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y - 90.0, 1.3).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.3).set_delay(0.4)
	tw.tween_callback(l.queue_free)

## Kurze Meldung in einer eigenen Zeile unter Rangliste/Status. Eine neue Meldung ersetzt die alte,
## damit sich nichts stapelt oder ueberlappt.
func toast(text: String) -> void:
	if _toast != null and is_instance_valid(_toast):
		_root.remove_child(_toast)
		_toast.queue_free()
	var p := UIKit.panel(Color(0.04, 0.06, 0.14, 0.86), 14, Color(1, 1, 1, 0.16), 1)
	p.name = "Toast"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var avail: float = _root.size.x if _root.size.x > 1.0 else get_viewport().get_visible_rect().size.x
	var l := UIKit.wrap_label(text, 19, UIKit.TEXT, true)
	l.custom_minimum_size.x = minf(avail - 48.0, maxf(220.0, float(text.length()) * 9.5))
	p.add_child(UIKit.margin(l, 10, 3, 10, 3))
	p.z_index = 40
	_root.add_child(p)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast = p
	_place_toast()
	_place_toast.call_deferred()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)

func _place_toast() -> void:
	if _toast == null or not is_instance_valid(_toast):
		return
	_toast.position.y = _top_box.get_global_rect().end.y - _root.get_global_rect().position.y + 8.0

func _process(_delta: float) -> void:
	# Die obere Leiste waechst, wenn Spieler dazukommen -> Meldung bleibt darunter
	if _toast != null and is_instance_valid(_toast):
		_place_toast()

# ================================================================ Overlays

func hide_overlay() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null

func _open_overlay(title: String, size: Vector2) -> Dictionary:
	hide_overlay()
	var m: Dictionary = UIKit.modal(_root, title, size, false)
	_overlay = m["root"]
	return m

func _result_row(rank: int, row: Dictionary, right_text: String) -> Control:
	var p := UIKit.panel(UIKit.PANEL_LIGHT if bool(row.get("local", false)) else Color(0.05, 0.08, 0.18, 0.9), 12, Color(1, 1, 1, 0.1), 1)
	var h := UIKit.hbox(12)
	p.add_child(h)
	var medal: Color = [UIKit.GOLD, Color(0.8, 0.84, 0.9), Color(0.8, 0.5, 0.25)][rank - 1] if rank <= 3 else UIKit.GREY
	var rl := UIKit.label(str(rank), 26, medal)
	rl.custom_minimum_size = Vector2(34, 0)
	h.add_child(rl)
	var dot := ColorRect.new()
	dot.color = row.get("color", Color.WHITE)
	dot.custom_minimum_size = Vector2(10, 30)
	h.add_child(dot)
	var nm := UIKit.label(str(row.get("name", "?")), 22, UIKit.GOLD if bool(row.get("local", false)) else UIKit.TEXT)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.clip_text = true
	h.add_child(nm)
	h.add_child(UIKit.label(right_text, 22, UIKit.TEXT))
	return p

## Ergebnis einer Bahn. rows: [{name, color, local, hole_text, total}] (bereits sortiert).
func show_hole_results(rows: Array, title: String, can_skip: bool) -> void:
	var m := _open_overlay(title, Vector2(640, 120 + 56 * rows.size()))
	var body: VBoxContainer = m["body"]
	for i in rows.size():
		var row: Dictionary = rows[i]
		body.add_child(_result_row(i + 1, row, "%s   Ges. %d" % [str(row.get("hole_text", "")), int(row.get("total", 0))]))
	if can_skip:
		var b := UIKit.button("WEITER", UIKit.GREEN, func() -> void: skip_pressed.emit(), Vector2(200, 60))
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(b)

## Endergebnis. rows: [{name, color, local, total}], rewards: Ergebnis von GameManager.finish_match().
func show_match_results(rows: Array, rewards: Dictionary, headline: String) -> void:
	var m := _open_overlay(headline, Vector2(680, 1040))
	var body: VBoxContainer = m["body"]
	var list := UIKit.vbox(8)
	body.add_child(list)
	for i in rows.size():
		var row: Dictionary = rows[i]
		list.add_child(_result_row(i + 1, row, "%d Schläge" % int(row.get("total", 0))))
	var right_panel := UIKit.panel(Color(0.04, 0.06, 0.14, 0.9), 16, Color(1, 0.8, 0.2, 0.5), 2)
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(right_panel)
	var right := UIKit.vbox(10)
	right_panel.add_child(UIKit.margin(right, 12, 8, 12, 8))
	right.add_child(UIKit.label("BELOHNUNGEN", 24, UIKit.GOLD, true))
	_reward_lines(right, rewards)
	var b := UIKit.button("WEITER", UIKit.GREEN, func() -> void: continue_pressed.emit(), Vector2(0, 76), 30)
	b.name = "ContinueButton"
	body.add_child(b)

func _reward_lines(box: VBoxContainer, rewards: Dictionary) -> void:
	if rewards.has("trophies") and int(rewards["trophies"]) != 0:
		box.add_child(_reward_line("trophy", "%+d Trophäen" % int(rewards["trophies"]), UIKit.GOLD if int(rewards["trophies"]) > 0 else UIKit.RED))
	if int(rewards.get("coins", 0)) > 0:
		box.add_child(_reward_line("coin", "+%d Coins" % int(rewards["coins"]), UIKit.TEXT))
	if int(rewards.get("style_coins", 0)) > 0:
		box.add_child(_reward_line("star", "davon %d Style-Bonus" % int(rewards["style_coins"]), Color(0.4, 1.0, 0.9)))
	if int(rewards.get("gems", 0)) > 0:
		box.add_child(_reward_line("gem", "+%d Gems" % int(rewards["gems"]), UIKit.TEXT))
	if str(rewards.get("chest", "")) != "":
		var chest: Dictionary = Catalog.CHESTS[str(rewards["chest"])]
		var line := _reward_line("chest", str(chest["name"]) + "!", UIKit.TEXT)
		(line.get_child(0) as UIIcon).set_kind("chest", chest["color"])
		box.add_child(line)
	if int(rewards.get("pass_xp", 0)) > 0:
		box.add_child(_reward_line("star", "+%d Pass-XP · Stufe %d" % [int(rewards["pass_xp"]), GameManager.pass_tier()], Color(0.75, 0.55, 1.0)))
	if bool(rewards.get("league_up", false)):
		box.add_child(_reward_line("star", "Aufstieg: Liga %s!" % str(rewards.get("league", "")), UIKit.GOLD))
	if str(rewards.get("label", "")) != "":
		box.add_child(UIKit.wrap_label(str(rewards["label"]), 22, UIKit.GOLD, true))

func _reward_line(icon_kind: String, text: String, color: Color) -> HBoxContainer:
	var h := UIKit.hbox(10)
	h.add_child(UIIcon.new(icon_kind, 34.0))
	var l := UIKit.wrap_label(text, 22, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	return h

## Ergebnis des Golden Shot.
func show_daily_result(distance: float, holed: bool, rewards: Dictionary) -> void:
	var m := _open_overlay("GOLDEN SHOT", Vector2(640, 560))
	var body: VBoxContainer = m["body"]
	var head: String = "HOLE IN ONE!" if holed else "%.2f m bis zur Fahne" % distance
	body.add_child(UIKit.label(head, 40, UIKit.GOLD, true))
	var box := UIKit.vbox(8)
	body.add_child(box)
	_reward_lines(box, rewards)
	body.add_child(UIKit.spacer())
	var b := UIKit.button("WEITER", UIKit.GREEN, func() -> void: continue_pressed.emit(), Vector2(0, 76), 30)
	body.add_child(b)

## Sicherheitsabfrage "Match verlassen?".
func confirm_exit() -> void:
	if _overlay != null and is_instance_valid(_overlay):
		return
	var m := _open_overlay("Match verlassen?", Vector2(600, 280))
	var body: VBoxContainer = m["body"]
	body.add_child(UIKit.wrap_label("Dein Fortschritt in diesem Match geht verloren.", 20, UIKit.TEXT_DIM, true))
	var h := UIKit.hbox(16)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(h)
	var stay := UIKit.button("BLEIBEN", UIKit.GREEN, hide_overlay, Vector2(0, 68))
	stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(stay)
	var leave := UIKit.button("VERLASSEN", UIKit.RED, func() -> void: exit_requested.emit(), Vector2(0, 68))
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(leave)

func has_overlay() -> bool:
	return _overlay != null and is_instance_valid(_overlay)
