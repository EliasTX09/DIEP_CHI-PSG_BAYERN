class_name BallTag
extends Node3D
## 3D-Namensschild ueber einem Ball (immer zur Kamera gedreht) + aufploppende Emotes/Quick-Chat.

## Alle aktiven Schilder (zum Stapeln, wenn mehrere Baelle dicht beieinander liegen).
static var _all: Array[BallTag] = []

var target: Node3D = null
var height: float = 0.85
var _stack: float = 0.0
var _name_label: Label3D
var _emote_root: Node3D
var _emote_sprite: Sprite3D
var _emote_label: Label3D
var _emote_time: float = 0.0

func _init(display_name: String = "", color: Color = Color.WHITE, is_local: bool = false) -> void:
	_name_label = Label3D.new()
	_name_label.text = display_name
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.fixed_size = true
	_name_label.pixel_size = 0.0011
	_name_label.font_size = 40
	_name_label.outline_size = 12
	_name_label.modulate = color.lightened(0.35) if not is_local else Color(1.0, 0.95, 0.5)
	_name_label.outline_modulate = Color(0.02, 0.03, 0.08, 0.9)
	_name_label.render_priority = 5
	add_child(_name_label)
	_emote_root = Node3D.new()
	_emote_root.position = Vector3(0.0, 0.75, 0.0)
	_emote_root.visible = false
	add_child(_emote_root)
	_emote_sprite = Sprite3D.new()
	_emote_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_emote_sprite.no_depth_test = true
	_emote_sprite.fixed_size = true
	_emote_sprite.pixel_size = 0.0016
	_emote_sprite.render_priority = 6
	_emote_root.add_child(_emote_sprite)
	_emote_label = Label3D.new()
	_emote_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_emote_label.no_depth_test = true
	_emote_label.fixed_size = true
	_emote_label.pixel_size = 0.0012
	_emote_label.font_size = 56
	_emote_label.outline_size = 16
	_emote_label.modulate = Color(1.0, 0.95, 0.4)
	_emote_label.outline_modulate = Color(0.1, 0.05, 0.0)
	_emote_label.render_priority = 6
	_emote_root.add_child(_emote_label)

func _enter_tree() -> void:
	if not _all.has(self):
		_all.append(self)

func _exit_tree() -> void:
	_all.erase(self)

## Wie viele frueher angelegte, sichtbare Schilder liegen fast an derselben Stelle? -> so hoch stapeln.
func _stack_level() -> int:
	var level := 0
	var my_pos: Vector3 = target.global_position
	for other in _all:
		if other == self:
			break
		if other.target == null or not is_instance_valid(other.target) or not other.target.visible:
			continue
		if other.target.global_position.distance_to(my_pos) < 3.0:
			level += 1
	return level

func set_tag_visible(v: bool) -> void:
	_name_label.visible = v

## Zeigt ein Emote (ID aus Catalog.EMOTES) fuer ~2,5 Sekunden.
func show_emote(emote_id: String) -> void:
	var e: Dictionary = Catalog.emote_by_id(emote_id)
	var icon: String = str(e.get("icon", ""))
	if icon != "":
		_emote_sprite.texture = Icons.emote(icon)
		_emote_sprite.visible = true
		_emote_label.visible = false
	else:
		_emote_label.text = str(e.get("text", ""))
		_emote_label.visible = true
		_emote_sprite.visible = false
	_emote_root.visible = true
	_emote_root.scale = Vector3.ONE * 0.2
	_emote_time = 2.5
	var tw := create_tween()
	tw.tween_property(_emote_root, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var cam := get_viewport().get_camera_3d()
		var dist: float = 10.0
		if cam != null:
			dist = cam.global_position.distance_to(target.global_position)
		# Feste Bildschirmgroesse -> Stapelabstand waechst mit der Kameradistanz.
		var want: float = float(_stack_level()) * maxf(0.3, dist * 0.052)
		_stack = lerpf(_stack, want, clampf(delta * 8.0, 0.0, 1.0))
		global_position = target.global_position + Vector3.UP * (height + _stack)
		visible = target.visible
	if _emote_time > 0.0:
		_emote_time -= delta
		_emote_root.position.y = 0.75 + (2.5 - _emote_time) * 0.12
		if _emote_time <= 0.0:
			_emote_root.visible = false
