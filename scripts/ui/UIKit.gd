class_name UIKit
extends RefCounted
## UI-Baukasten fuer das Arcade-Interface: Farben, Theme, grosse Touch-Buttons mit Klick-Sound und
## Druck-Animation, Panels, Modale Dialoge, Toasts, Avatar und Safe-Area-Raender (Notch/Punch-Hole).

const BG := Color(0.05, 0.08, 0.15)
const PANEL := Color(0.09, 0.13, 0.25, 0.94)
const PANEL_LIGHT := Color(0.15, 0.2, 0.36, 0.96)
const GOLD := Color(1.0, 0.78, 0.18)
const BLUE := Color(0.18, 0.56, 1.0)
const GREEN := Color(0.25, 0.8, 0.38)
const RED := Color(0.95, 0.28, 0.33)
const PURPLE := Color(0.62, 0.36, 1.0)
const GREY := Color(0.36, 0.4, 0.5)
const TEXT := Color(1, 1, 1)
const TEXT_DIM := Color(0.72, 0.78, 0.9)

static var _theme: Theme = null

# ================================================================ Styles

static func box(color: Color, radius: int = 16, border: Color = Color(0, 0, 0, 0), border_width: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	if border_width > 0:
		s.border_color = border
		s.set_border_width_all(border_width)
	s.content_margin_left = 14.0
	s.content_margin_right = 14.0
	s.content_margin_top = 8.0
	s.content_margin_bottom = 8.0
	s.anti_aliasing = true
	return s

## Button-Stil mit "3D-Kante" unten.
static func button_box(color: Color, pressed: bool, radius: int = 16) -> StyleBoxFlat:
	var s := box(color.darkened(0.12) if pressed else color, radius)
	s.border_color = color.darkened(0.45)
	s.border_width_bottom = 2 if pressed else 6
	s.content_margin_top = 12.0 if pressed else 8.0
	s.content_margin_bottom = 8.0 if pressed else 12.0
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 0 if pressed else 4
	s.shadow_offset = Vector2(0, 3)
	return s

static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0.02, 0.04, 0.1))
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_focus_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.5))
	t.set_color("font_outline_color", "Button", Color(0.02, 0.04, 0.1))
	t.set_constant("outline_size", "Button", 5)
	t.set_font_size("font_size", "Button", 24)
	t.set_stylebox("normal", "Button", button_box(BLUE, false))
	t.set_stylebox("hover", "Button", button_box(BLUE.lightened(0.08), false))
	t.set_stylebox("pressed", "Button", button_box(BLUE, true))
	t.set_stylebox("disabled", "Button", button_box(GREY, false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 18, Color(0.3, 0.4, 0.7, 0.6), 2))
	t.set_stylebox("panel", "Panel", box(PANEL, 18))
	t.set_stylebox("normal", "LineEdit", box(Color(0.04, 0.06, 0.12), 12, Color(0.3, 0.4, 0.7), 2))
	t.set_stylebox("focus", "LineEdit", box(Color(0.04, 0.06, 0.12), 12, GOLD, 2))
	t.set_font_size("font_size", "LineEdit", 24)
	t.set_stylebox("background", "ProgressBar", box(Color(0.03, 0.05, 0.1), 8))
	t.set_stylebox("fill", "ProgressBar", box(GREEN, 8))
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("separation", "HBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.35)
	grab.set_corner_radius_all(4)
	t.set_stylebox("grabber", "VScrollBar", grab)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)
	_theme = t
	return t

# ================================================================ Bausteine

static func label(text: String, size: int = 22, color: Color = TEXT, align_center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("outline_size", maxi(3, size / 5))
	if align_center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func wrap_label(text: String, size: int = 20, color: Color = TEXT_DIM, align_center: bool = false) -> Label:
	var l := label(text, size, color, align_center)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

## Grosser Arcade-Button. `on_press` wird beim Antippen aufgerufen (mit Klick-Sound + Druck-Animation).
static func button(text: String, color: Color = BLUE, on_press: Callable = Callable(), min_size: Vector2 = Vector2(150, 62), font_size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	set_button_color(b, color)
	b.pressed.connect(func() -> void: SoundManager.play("click"))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	return b

static func set_button_color(b: Button, color: Color) -> void:
	b.add_theme_stylebox_override("normal", button_box(color, false))
	b.add_theme_stylebox_override("hover", button_box(color.lightened(0.08), false))
	b.add_theme_stylebox_override("pressed", button_box(color, true))
	b.add_theme_stylebox_override("disabled", button_box(GREY, false))

## Quadratischer Icon-Button.
static func icon_button(icon_kind: String, color: Color = BLUE, on_press: Callable = Callable(), size: float = 64.0, tint: Color = Color.WHITE) -> Button:
	var b := button("", color, on_press, Vector2(size, size))
	var ic := UIIcon.new(icon_kind, size * 0.5, tint)
	ic.name = "Icon"
	ic.size = Vector2(size * 0.5, size * 0.5)
	ic.position = Vector2(size * 0.25, size * 0.2)
	b.add_child(ic)
	return b

static func panel(color: Color = PANEL, radius: int = 18, border: Color = Color(0.3, 0.4, 0.7, 0.6), border_width: int = 2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", box(color, radius, border, border_width))
	return p

static func hbox(separation: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h

static func vbox(separation: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v

static func spacer(expand: bool = true, min_size: Vector2 = Vector2.ZERO) -> Control:
	var c := Control.new()
	c.custom_minimum_size = min_size
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

static func margin(child: Control, left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_bottom", bottom)
	m.add_child(child)
	return m

## Waehrungs-Pille: Icon + Zahl.
static func currency_pill(icon_kind: String, value: int) -> PanelContainer:
	var p := panel(Color(0.03, 0.05, 0.12, 0.85), 22, Color(1, 1, 1, 0.15), 2)
	var h := hbox(8)
	h.add_child(UIIcon.new(icon_kind, 30.0))
	var l := label(format_number(value), 24, TEXT)
	l.name = "Value"
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	p.add_child(h)
	return p

static func format_number(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "." + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out

static func format_time(seconds: float) -> String:
	var s: int = int(ceil(maxf(0.0, seconds)))
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s / 60) % 60, s % 60]
	return "%d:%02d" % [s / 60, s % 60]

## Fortschrittsbalken (0..1) mit Farbe.
static func bar(value: float, color: Color = GREEN, min_size: Vector2 = Vector2(160, 18)) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.min_value = 0.0
	pb.max_value = 1.0
	pb.value = clampf(value, 0.0, 1.0)
	pb.show_percentage = false
	pb.custom_minimum_size = min_size
	pb.add_theme_stylebox_override("fill", box(color, 8))
	pb.add_theme_stylebox_override("background", box(Color(0.03, 0.05, 0.1), 8))
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb

# ================================================================ Dialoge & Toasts

## Modaler Dialog: abgedunkelter Hintergrund + zentriertes Panel mit Titel und Schliessen-Button.
## Rueckgabe: {root: Control, body: VBoxContainer, close: Button, panel: PanelContainer}
static func modal(host: Control, title: String, size: Vector2 = Vector2(820, 560), closable: bool = true) -> Dictionary:
	var root := Control.new()
	root.name = "Modal"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	host.add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var p := panel(PANEL, 22, Color(0.35, 0.5, 0.9, 0.8), 3)
	p.custom_minimum_size = size
	center.add_child(p)
	var outer := vbox(10)
	p.add_child(outer)
	var head := hbox(10)
	outer.add_child(head)
	var tl := label(title, 30, GOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var close_btn := icon_button("close", RED, Callable(), 52.0)
	close_btn.visible = closable
	close_btn.pressed.connect(root.queue_free)
	head.add_child(close_btn)
	var body := vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	# Einblend-Animation
	p.pivot_offset = size * 0.5
	p.scale = Vector2(0.88, 0.88)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(root, "modulate:a", 1.0, 0.15)
	tw.tween_property(p, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return {"root": root, "body": body, "close": close_btn, "panel": p}

## Scroll-Bereich mit vertikaler Liste. Rueckgabe: der innere VBoxContainer.
static func scroll_list(parent: Control, min_height: float = 360.0) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, min_height)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v

## Kurze Einblendung am oberen Bildschirmrand.
static func toast(host: Control, text: String, color: Color = PANEL_LIGHT) -> void:
	var p := panel(color, 18, Color(1, 1, 1, 0.3), 2)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(label(text, 22, TEXT, true))
	p.z_index = 50
	host.add_child(p)
	p.set_anchors_preset(Control.PRESET_CENTER_TOP)
	p.position.y = 90.0
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.7)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(p.queue_free)

# ================================================================ Safe Area

## Raender (links, oben, rechts, unten) in UI-Einheiten, die Notch/Kamera-Loch/Gestenleiste frei lassen.
static func safe_margins(viewport_size: Vector2) -> Vector4:
	var win: Vector2i = DisplayServer.window_get_size()
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if win.x <= 0 or win.y <= 0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var sx: float = viewport_size.x / float(win.x)
	var sy: float = viewport_size.y / float(win.y)
	var l: float = clampf(float(safe.position.x) * sx, 0.0, viewport_size.x * 0.12)
	var t: float = clampf(float(safe.position.y) * sy, 0.0, viewport_size.y * 0.12)
	var r: float = clampf(float(win.x - safe.end.x) * sx, 0.0, viewport_size.x * 0.12)
	var b: float = clampf(float(win.y - safe.end.y) * sy, 0.0, viewport_size.y * 0.12)
	return Vector4(l, t, r, b)

## Setzt die Raender eines MarginContainers auf Grundabstand + Safe Area.
static func apply_safe_area(m: MarginContainer, base: int = 14) -> void:
	var vp: Vector2 = m.get_viewport_rect().size if m.is_inside_tree() else Vector2(1280, 720)
	var s := safe_margins(vp)
	m.add_theme_constant_override("margin_left", base + int(s.x))
	m.add_theme_constant_override("margin_top", base + int(s.y))
	m.add_theme_constant_override("margin_right", base + int(s.z))
	m.add_theme_constant_override("margin_bottom", base + int(s.w))
