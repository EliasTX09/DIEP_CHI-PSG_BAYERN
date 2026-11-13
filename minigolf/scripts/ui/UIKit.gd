class_name UIKit
extends RefCounted
## Kleine Helfer fuer code-gebaute, touch-taugliche UI (grosse Buttons, einheitliches Theme).

const BTN_H := 84.0

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	var normal := _box(Color(0.16, 0.45, 0.24))
	var hover := _box(Color(0.2, 0.55, 0.3))
	var pressed := _box(Color(0.1, 0.32, 0.17))
	var disabled := _box(Color(0.3, 0.3, 0.3))
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("normal", "LineEdit", _box(Color(0.12, 0.14, 0.12), 12))
	t.set_font_size("font_size", "Button", 32)
	t.set_constant("separation", "VBoxContainer", 16)
	t.set_constant("separation", "HBoxContainer", 12)
	return t

static func _box(c: Color, r: int = 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(r)
	s.content_margin_left = 20; s.content_margin_right = 20
	s.content_margin_top = 12; s.content_margin_bottom = 12
	return s

static func button(text: String, cb: Callable = Callable()) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, BTN_H)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if cb.is_valid():
		b.pressed.connect(cb)
	return b

static func label(text: String, size: int = 30, center: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func line_edit(placeholder: String, secret: bool = false) -> LineEdit:
	var e := LineEdit.new()
	e.placeholder_text = placeholder
	e.secret = secret
	e.custom_minimum_size = Vector2(0, 76)
	return e

## Vollflaechiger Screen mit Rand und scrollbarem VBox. Liefert den VBox.
static func screen(parent: Control, title: String) -> VBoxContainer:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.12, 0.09)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 32)
	bg.add_child(m)
	var outer := VBoxContainer.new()
	m.add_child(outer)
	outer.add_child(label(title, 48, true))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v
