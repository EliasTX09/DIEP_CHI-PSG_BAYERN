class_name LobbyScreen
extends Control
## Lobby: Raum erstellen/beitreten (4-stelliger Code), Freundesliste, Einladungen, Match starten.

signal back
signal start_online(players: Array)

var _box: VBoxContainer
var _status: Label
var _code_in: LineEdit
var _friend_in: LineEdit
var _peers_lbl: Label
var _start_btn: Button
var _friends_box: VBoxContainer
var _invites_box: VBoxContainer
var _poll: Timer

func _ready() -> void:
	_box = UIKit.screen(self, "Lobby")
	_status = UIKit.label("", 26, true)
	_box.add_child(_status)
	if Net.is_offline():
		_status.text = "Online-Modus braucht Backend + Login (Account). Siehe Account-Menue."
		_box.add_child(UIKit.button("← Zurueck", func(): back.emit()))
		return
	_box.add_child(UIKit.button("Raum erstellen", _create))
	_code_in = UIKit.line_edit("Raum-Code (z.B. K7QF)")
	_box.add_child(_code_in)
	_box.add_child(UIKit.button("Beitreten", func(): _join(_code_in.text.strip_edges())))
	_peers_lbl = UIKit.label("", 28, true)
	_box.add_child(_peers_lbl)
	_start_btn = UIKit.button("▶ Match starten (Host)", _start)
	_start_btn.visible = false
	_box.add_child(_start_btn)
	_box.add_child(UIKit.label("— Einladungen —", 28, true))
	_invites_box = VBoxContainer.new()
	_box.add_child(_invites_box)
	_box.add_child(UIKit.label("— Freunde —", 28, true))
	_friend_in = UIKit.line_edit("Benutzername hinzufuegen")
	_box.add_child(_friend_in)
	_box.add_child(UIKit.button("Freundschaftsanfrage senden", _add_friend))
	_friends_box = VBoxContainer.new()
	_box.add_child(_friends_box)
	_box.add_child(UIKit.button("← Zurueck", func(): Net.leave_room(); back.emit()))
	Net.room_joined.connect(func(code): _status.text = "Raum %s – warte auf Spieler" % code; _refresh_peers())
	Net.room_failed.connect(func(r): _status.text = "Fehler: " + r)
	Net.peers_changed.connect(func(_p): _refresh_peers())
	Net.event_received.connect(_on_event)
	_poll = Timer.new()
	_poll.wait_time = 6.0
	_poll.autostart = true
	_poll.timeout.connect(_load_invites)
	add_child(_poll)
	_load_friends()
	_load_invites()

func _me_name() -> String:
	return Supa.username if Supa.username != "" else "Spieler"

func _create() -> void:
	_join(Net.random_code())

func _join(code: String) -> void:
	if code.length() < 3:
		return
	_status.text = "Verbinde..."
	Net.join_room(code, _me_name(), Catalog.BALLS[Progression.equipped["ball"]]["color"])

func _refresh_peers() -> void:
	if not Net.in_room:
		return
	var lines: PackedStringArray = ["Raum: %s" % Net.room_code, "• %s (du)" % _me_name()]
	for id in Net.peers:
		lines.append("• " + Net.peers[id]["name"])
	_peers_lbl.text = "\n".join(lines)
	_start_btn.visible = Net.is_host() and Net.peers.size() >= 1

func _roster() -> Array:
	var r: Array = [{"id": Supa.user_id, "name": _me_name(), "color": Catalog.BALLS[Progression.equipped["ball"]]["color"].to_html()}]
	for id in Net.peers:
		r.append({"id": id, "name": Net.peers[id]["name"], "color": (Net.peers[id]["color"] as Color).to_html()})
	r.sort_custom(func(a, b): return a["id"] < b["id"])
	return r

func _start() -> void:
	var roster := _roster()
	Net.send_event("start", {"players": roster})
	start_online.emit(roster)

func _on_event(event: String, payload: Dictionary) -> void:
	if event == "start" and payload.get("players") is Array:
		start_online.emit(payload["players"])

# ---------------------------------------------------------------- Freunde / Einladungen

func _load_friends() -> void:
	var uid := Supa.user_id
	var r: Dictionary = await Supa.rest_get("friendships?select=id,user_id,friend_id,status&or=(user_id.eq.%s,friend_id.eq.%s)" % [uid, uid])
	if not r.ok or not (r.data is Array):
		return
	var ids: Array = []
	for f in r.data:
		ids.append(f["friend_id"] if f["user_id"] == uid else f["user_id"])
	var names := {}
	if not ids.is_empty():
		var pr: Dictionary = await Supa.rest_get("profiles?select=id,username&id=in.(%s)" % ",".join(PackedStringArray(ids)))
		if pr.ok and pr.data is Array:
			for p in pr.data:
				names[p["id"]] = p["username"]
	for c in _friends_box.get_children():
		c.queue_free()
	for f in r.data:
		var other: String = f["friend_id"] if f["user_id"] == uid else f["user_id"]
		var row := HBoxContainer.new()
		row.add_child(UIKit.label(str(names.get(other, "?")) + ("" if f["status"] == "accepted" else " (offen)"), 26))
		row.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if f["status"] == "accepted":
			row.add_child(UIKit.button("Einladen", func(): _invite(other)))
		elif f["friend_id"] == uid:
			row.add_child(UIKit.button("Annehmen", func(): _accept(f["id"])))
		_friends_box.add_child(row)

func _add_friend() -> void:
	var n := _friend_in.text.strip_edges()
	if n == "":
		return
	var r: Dictionary = await Supa.rest_get("profiles?select=id&username=eq." + n.uri_encode())
	if r.ok and r.data is Array and r.data.size() > 0:
		var ins: Dictionary = await Supa.rest_insert("friendships", {"user_id": Supa.user_id, "friend_id": r.data[0]["id"], "status": "pending"})
		_status.text = "Anfrage gesendet." if ins.ok else "Bereits befreundet/angefragt."
		_load_friends()
	else:
		_status.text = "Benutzer nicht gefunden."

func _accept(friendship_id: Variant) -> void:
	await Supa.rest_patch("friendships?id=eq.%s" % str(friendship_id), {"status": "accepted"})
	_load_friends()

func _invite(friend_id: String) -> void:
	if not Net.in_room:
		_status.text = "Erstelle zuerst einen Raum."
		return
	var r: Dictionary = await Supa.rest_insert("invites", {"from_id": Supa.user_id, "to_id": friend_id, "room_code": Net.room_code})
	_status.text = "Einladung gesendet." if r.ok else "Einladung fehlgeschlagen."

func _load_invites() -> void:
	var r: Dictionary = await Supa.rest_get("invites?select=id,room_code,from_id,profiles!invites_from_id_fkey(username)&to_id=eq.%s&order=created_at.desc&limit=5" % Supa.user_id)
	if not r.ok or not (r.data is Array) or _invites_box == null:
		return
	for c in _invites_box.get_children():
		c.queue_free()
	for inv in r.data:
		var prof = inv.get("profiles")
		var who: String = str(prof.get("username", "Freund")) if prof is Dictionary else "Freund"
		_invites_box.add_child(UIKit.button("%s lädt dich ein: %s" % [who, inv["room_code"]], func():
			Supa.rest_delete("invites?id=eq.%s" % str(inv["id"]))
			_join(str(inv["room_code"]))))
