extends Node
## Autoload "Net": Echtzeit-Raeume ueber Supabase Realtime (Phoenix-Channels-Protokoll v1 per WebSocket).
## - Broadcast: Schuesse/Positionen (kein DB-Roundtrip)  - Presence: wer ist im Raum
## HINWEIS: Protokoll-Details sind gegen die Supabase-Doku geschrieben, aber NICHT live getestet.
## Alles Realtime-spezifische ist in dieser einen Datei gekapselt.

signal room_joined(code: String)
signal room_failed(reason: String)
signal peers_changed(peers: Dictionary)           # id -> {name, color}
signal event_received(event: String, payload: Dictionary)
signal disconnected

const HEARTBEAT := 25.0

var room_code: String = ""
var in_room: bool = false
var peers: Dictionary = {}

var _ws := WebSocketPeer.new()
var _active: bool = false
var _joined_sent: bool = false
var _ref: int = 0
var _hb: float = 0.0
var _topic: String = ""
var _my_meta: Dictionary = {}

static func random_code() -> String:
	var chars := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var s := ""
	for i in 4:
		s += chars[randi() % chars.length()]
	return s

func is_offline() -> bool:
	return not Cfg.is_online_capable() or not Supa.is_logged_in()

## Raum betreten/erstellen (gleicher Code = gleicher Raum).
func join_room(code: String, display_name: String, color: Color) -> void:
	leave_room()
	room_code = code.to_upper()
	_topic = "realtime:minigolf_" + room_code
	_my_meta = {"id": Supa.user_id, "name": display_name, "color": color.to_html()}
	if is_offline():
		in_room = true
		peers = {}
		room_joined.emit(room_code)
		return
	var url := "%s/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % [Cfg.ws_base(), Cfg.anon_key]
	if _ws.connect_to_url(url) != OK:
		room_failed.emit("WebSocket-Verbindung fehlgeschlagen")
		return
	_active = true
	_joined_sent = false
	_hb = 0.0

func leave_room() -> void:
	if _active:
		_ws.close()
	_active = false
	in_room = false
	peers.clear()
	room_code = ""
	_ws = WebSocketPeer.new()

## Event an alle anderen im Raum (nicht an sich selbst).
func send_event(event: String, payload: Dictionary) -> void:
	if not in_room or is_offline():
		return
	_send(_topic, "broadcast", {"type": "broadcast", "event": event, "payload": payload})

func is_host() -> bool:
	## Deterministisch: kleinste User-ID im Raum ist Host.
	var ids: Array = peers.keys()
	ids.append(Supa.user_id)
	ids.sort()
	return ids[0] == Supa.user_id

# ------------------------------------------------------------------ intern

func _process(delta: float) -> void:
	if not _active:
		return
	_ws.poll()
	var st := _ws.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _joined_sent:
			_joined_sent = true
			_send(_topic, "phx_join", {
				"config": {
					"broadcast": {"self": false, "ack": false},
					"presence": {"key": Supa.user_id},
					"postgres_changes": [],
				},
				"access_token": Supa.access_token,
			})
		_hb += delta
		if _hb >= HEARTBEAT:
			_hb = 0.0
			_send("phoenix", "heartbeat", {})
		while _ws.get_available_packet_count() > 0:
			_on_message(_ws.get_packet().get_string_from_utf8())
	elif st == WebSocketPeer.STATE_CLOSED:
		_active = false
		var was_in := in_room
		in_room = false
		if was_in:
			disconnected.emit()
		else:
			room_failed.emit("Verbindung geschlossen (%d)" % _ws.get_close_code())

func _send(topic: String, event: String, payload: Dictionary) -> void:
	_ref += 1
	_ws.send_text(JSON.stringify({"topic": topic, "event": event, "payload": payload, "ref": str(_ref)}))

func _on_message(text: String) -> void:
	var msg = JSON.parse_string(text)
	if not (msg is Dictionary):
		return
	var ev: String = str(msg.get("event", ""))
	var payload: Dictionary = msg.get("payload", {}) if msg.get("payload") is Dictionary else {}
	match ev:
		"phx_reply":
			if msg.get("topic") == _topic and not in_room:
				if payload.get("status") == "ok":
					in_room = true
					_send(_topic, "presence", {"type": "presence", "event": "track", "payload": _my_meta})
					room_joined.emit(room_code)
				else:
					room_failed.emit(str(payload.get("response", "Beitritt abgelehnt")))
		"presence_state":
			peers.clear()
			for key in payload:
				_merge_presence(str(key), payload[key])
			peers_changed.emit(peers)
		"presence_diff":
			var joins: Dictionary = payload.get("joins", {})
			var leaves: Dictionary = payload.get("leaves", {})
			for key in joins:
				_merge_presence(str(key), joins[key])
			for key in leaves:
				peers.erase(str(key))
			peers_changed.emit(peers)
		"broadcast":
			event_received.emit(str(payload.get("event", "")), payload.get("payload", {}))
		"phx_close", "phx_error":
			room_failed.emit("Kanalfehler")

func _merge_presence(key: String, entry: Variant) -> void:
	if key == Supa.user_id or not (entry is Dictionary):
		return
	var metas: Array = entry.get("metas", [])
	if metas.size() > 0 and metas[0] is Dictionary:
		var m: Dictionary = metas[0]
		peers[key] = {"name": str(m.get("name", "?")), "color": Color.html(str(m.get("color", "#ffffff")))}
