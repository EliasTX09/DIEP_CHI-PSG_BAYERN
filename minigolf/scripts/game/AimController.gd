class_name AimController
extends Node2D
## Drag-and-Release: Finger/Maus irgendwo hinunterdruecken, nach hinten ziehen = Zielrichtung ist
## entgegengesetzt, Zuglaenge = Kraft. Zeichnet Pfeil + Flugbahn-Vorschau. Spin kommt vom HUD-Slider.

signal shot(dir: Vector2, power: float, curve: float)

const MAX_DRAG := 220.0     # px (Bahn-Raum) fuer 100 % Kraft
const MIN_DRAG := 18.0      # darunter = Abbruch (Fehlberuehrung)

var ball: Ball = null
var enabled: bool = false
var curve: float = 0.0      # -1..1 vom HUD
var _dragging: bool = false
var _start: Vector2
var _cur: Vector2
var _preview: PackedVector2Array = PackedVector2Array()
var power_changed: Callable = Callable()   # optional: HUD-Callback (0..1)

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or ball == null or not ball.can_shoot():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			_start = get_local_mouse_position()
			_cur = _start
		elif _dragging:
			_dragging = false
			_release()
	elif event is InputEventMouseMotion and _dragging:
		_cur = get_local_mouse_position()
		_update_preview()

func _aim() -> Dictionary:
	var pull := _start - _cur                    # Zug nach hinten
	var power := clampf(pull.length() / MAX_DRAG, 0.0, 1.0)
	return {"dir": pull.normalized() if pull.length() > 0.1 else Vector2.ZERO, "power": power, "len": pull.length()}

func _update_preview() -> void:
	var a := _aim()
	if a["len"] < MIN_DRAG:
		_preview = PackedVector2Array()
	else:
		_preview = ball.predict(a["dir"], a["power"], curve)
	if power_changed.is_valid():
		power_changed.call(a["power"])
	queue_redraw()

func _release() -> void:
	var a := _aim()
	_preview = PackedVector2Array()
	queue_redraw()
	if power_changed.is_valid():
		power_changed.call(0.0)
	if a["len"] >= MIN_DRAG:
		shot.emit(a["dir"], a["power"], curve)

func cancel() -> void:
	_dragging = false
	_preview = PackedVector2Array()
	queue_redraw()

func _draw() -> void:
	if not _dragging or ball == null:
		return
	var a := _aim()
	var pw: float = a["power"]
	var col := Color(0.4 + 0.6 * pw, 1.0 - 0.7 * pw, 0.2)
	# Gummiband vom Ball nach hinten
	draw_line(ball.position, ball.position - a["dir"] * a["len"] * 0.6, Color(1, 1, 1, 0.5), 3.0)
	if _preview.size() > 1:
		for i in range(0, _preview.size() - 1, 2):
			draw_line(_preview[i], _preview[i + 1], col, 4.0)
		draw_circle(_preview[_preview.size() - 1], 6.0, Color(col, 0.7))
