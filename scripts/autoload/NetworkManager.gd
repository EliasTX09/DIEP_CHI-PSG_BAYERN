extends Node
## Autoload "NetworkManager": Supabase-Anbindung (Auth + REST + Realtime-WebSocket) und Bot-Fallback.
##
##  - Account: sofortiger Gast-Login beim ersten Start (anonyme Supabase-Session + lokale Geraete-ID),
##    spaeter mit E-Mail/Passwort verknuepfbar; Profil, Schlaeger und Inventar werden synchronisiert.
##  - Freunde: Suche per Name oder Freundes-Code, Anfragen, Online-Status, Lobby-Einladungen.
##  - Lobbys: private Raeume mit 4-stelligem Code oder oeffentliches Schnellspiel, bis zu 6 Spieler,
##    Welt + Rundenzahl waehlbar, Echtzeit-Sync ueber Supabase Realtime (Broadcast + Presence).
##  - Ohne Internet/Backend: alles laeuft offline gegen Bots weiter.
##
## WICHTIG: Der Supabase-Teil ist nach der offiziellen Doku geschrieben, konnte aber nicht gegen ein
## echtes Projekt getestet werden. Das Realtime-Protokoll ist bewusst in einem Block gekapselt (unten).

signal auth_changed
signal status_changed(text: String)
signal lobby_updated
signal lobby_joined(code: String)
signal lobby_left(reason: String)
signal lobby_error(message: String)
signal match_starting(config: Dictionary)
signal game_event(event: String, payload: Dictionary)
signal friends_updated
signal invites_updated
signal leaderboard_updated

const CONFIG_PATH := "res://config/backend.cfg"
const LOCAL_CONFIG_PATH := "res://config/backend.local.cfg"
const SESSION_PATH := "user://session.json"
const HEARTBEAT_SECONDS := 25.0
const PRESENCE_PING_SECONDS := 60.0
const ONLINE_WINDOW_SECONDS := 150.0
const QUICK_MATCH_WAIT := 12.0
const CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

var url: String = ""
var anon_key: String = ""
var user_id: String = ""
var access_token: String = ""
var refresh_token: String = ""
var email: String = ""
var is_anonymous: bool = true
var friend_code: String = ""
var status: String = "Offline"

## Freunde: [{row_id, id, name, trophies, frame, color, online, state: "accepted"|"incoming"|"outgoing"}]
var friends: Array = []
## Lobby-Einladungen an mich: [{id, code, from_id, from_name}]
var invites: Array = []
## Rangliste: [{name, trophies, frame, color, me}]
var leaderboard: Array = []

## Aktuelle Lobby ({} = keine): {code, host_id, world, rounds, is_public}
var lobby: Dictionary = {}
## Spieler in der Lobby (inkl. mir): [{id, name, frame, color, trophies, ball, trail, explosion}]
var roster: Array = []
## Freie Plaetze beim Start mit Bots auffuellen (bis 4 Spieler).
var fill_bots: bool = true

var _busy_login: bool = false
var _push_timer: float = -1.0
var _push_inventory: bool = true
var _ping_timer: float = 0.0
var _quick_timer: float = -1.0
var _rng := RandomNumberGenerator.new()

# Realtime
var _ws: WebSocketPeer = null
var _ws_open: bool = false
var _joined: bool = false
var _join_sent: bool = false
var _ref: int = 0
var _heartbeat: float = 0.0
var _topic: String = ""
var _presence: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_load_config()
	GameManager.save_changed.connect(_on_save_changed)
	GameManager.inventory_changed.connect(func() -> void: _push_inventory = true)
	if is_configured():
		auto_login()
	else:
		_set_status("Offline-Modus (kein Backend eingetragen)")

func _load_config() -> void:
	var cf := ConfigFile.new()
	var path: String = LOCAL_CONFIG_PATH if FileAccess.file_exists(LOCAL_CONFIG_PATH) else CONFIG_PATH
	if cf.load(path) != OK:
		return
	url = str(cf.get_value("supabase", "url", "")).strip_edges().trim_suffix("/")
	anon_key = str(cf.get_value("supabase", "anon_key", "")).strip_edges()

## true, wenn echte Supabase-Zugangsdaten eingetragen sind (keine Platzhalter).
func is_configured() -> bool:
	return url.begins_with("https://") and not url.contains("DEIN-PROJEKT") and anon_key.length() > 20 and not anon_key.begins_with("DEIN_")

## true, wenn eingeloggt (Gast oder E-Mail) und damit online-faehig.
func is_online() -> bool:
	return is_configured() and user_id != "" and access_token != ""

## Netzwerk-ID des lokalen Spielers.
func local_id() -> String:
	return user_id if user_id != "" else "local"

func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)

func _process(delta: float) -> void:
	if _push_timer >= 0.0:
		_push_timer -= delta
		if _push_timer < 0.0:
			push_profile()
	if is_online():
		_ping_timer += delta
		if _ping_timer >= PRESENCE_PING_SECONDS:
			_ping_timer = 0.0
			_ping_presence()
	if _quick_timer >= 0.0 and in_lobby():
		_quick_timer -= delta
		if (_quick_timer < 0.0 or roster.size() >= Catalog.MAX_PLAYERS) and is_host():
			_quick_timer = -1.0
			start_lobby_match()
	_poll_socket(delta)

# ================================================================ HTTP

## Fuehrt einen Request gegen Supabase aus. Rueckgabe: {ok, code, data, message}
func _req(method: int, path: String, body: Variant = null, auth: bool = true, extra_headers: Array = [], allow_refresh: bool = true) -> Dictionary:
	if not is_configured():
		return {"ok": false, "code": 0, "data": null, "message": "Kein Backend konfiguriert."}
	var req := HTTPRequest.new()
	req.timeout = 12.0
	add_child(req)
	var headers := PackedStringArray(["apikey: " + anon_key, "Content-Type: application/json"])
	var token: String = access_token if auth and access_token != "" else anon_key
	headers.append("Authorization: Bearer " + token)
	for h in extra_headers:
		headers.append(str(h))
	var payload: String = "" if body == null else JSON.stringify(body)
	var err: int = req.request(url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "data": null, "message": "Keine Verbindung (Fehler %d)." % err}
	var res: Array = await req.request_completed
	req.queue_free()
	var code: int = int(res[1])
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = null
	if text != "":
		parsed = JSON.parse_string(text)
	var ok: bool = int(res[0]) == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	if not ok and code == 401 and auth and allow_refresh and refresh_token != "":
		if await _refresh_session():
			return await _req(method, path, body, auth, extra_headers, false)
	var message := ""
	if not ok:
		if int(res[0]) != HTTPRequest.RESULT_SUCCESS:
			message = "Keine Verbindung zum Server."
		elif parsed is Dictionary:
			var d: Dictionary = parsed
			message = str(d.get("msg", d.get("message", d.get("error_description", d.get("error", "Fehler %d" % code)))))
		else:
			message = "Fehler %d" % code
	return {"ok": ok, "code": code, "data": parsed, "message": message}

func _api_get(path: String) -> Dictionary:
	return await _req(HTTPClient.METHOD_GET, path)

func _api_post(path: String, body: Variant, prefer: String = "return=representation") -> Dictionary:
	return await _req(HTTPClient.METHOD_POST, path, body, true, ["Prefer: " + prefer])

func _api_patch(path: String, body: Variant) -> Dictionary:
	return await _req(HTTPClient.METHOD_PATCH, path, body, true, ["Prefer: return=minimal"])

func _api_delete(path: String) -> Dictionary:
	return await _req(HTTPClient.METHOD_DELETE, path)

static func _now_iso() -> String:
	return Time.get_datetime_string_from_system(true) + "Z"

# ================================================================ Auth

## Beim Start: gespeicherte Session erneuern, sonst sofort als Gast anmelden.
func auto_login() -> void:
	if _busy_login or not is_configured():
		return
	_busy_login = true
	_set_status("Verbinde …")
	var ok := false
	if FileAccess.file_exists(SESSION_PATH):
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
		if saved is Dictionary:
			refresh_token = str((saved as Dictionary).get("rt", ""))
			if refresh_token != "":
				ok = await _refresh_session()
	if not ok:
		ok = await _sign_in_guest()
	_busy_login = false
	if ok:
		await _after_login()
	else:
		_set_status("Offline-Modus (Server nicht erreichbar)")
	auth_changed.emit()

## Anonyme Supabase-Session (im Dashboard: Authentication -> Sign In / Providers -> "Allow anonymous sign-ins").
func _sign_in_guest() -> bool:
	var body := {"data": {"device_id": GameManager.device_id(), "name": GameManager.player_name()}}
	var r: Dictionary = await _req(HTTPClient.METHOD_POST, "/auth/v1/signup", body, false, [], false)
	return _apply_session(r)

func _refresh_session() -> bool:
	if refresh_token == "":
		return false
	var r: Dictionary = await _req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false, [], false)
	return _apply_session(r)

func _apply_session(r: Dictionary) -> bool:
	if not bool(r.get("ok", false)) or not (r.get("data") is Dictionary):
		return false
	var d: Dictionary = r["data"]
	if not d.has("access_token"):
		return false
	access_token = str(d.get("access_token", ""))
	refresh_token = str(d.get("refresh_token", ""))
	var u: Dictionary = d.get("user", {}) if d.get("user") is Dictionary else {}
	user_id = str(u.get("id", ""))
	email = str(u.get("email", "")) if u.get("email") != null else ""
	is_anonymous = bool(u.get("is_anonymous", email == ""))
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"rt": refresh_token}))
		f.close()
	return user_id != ""

func _after_login() -> void:
	_set_status("Online als Gast" if is_anonymous else "Online: " + email)
	await _pull_profile()
	refresh_friends()
	refresh_invites()

## Verknuepft den Gast-Account mit E-Mail + Passwort (User-ID und Fortschritt bleiben erhalten).
func link_email(mail: String, password: String) -> Dictionary:
	if not is_online():
		return {"ok": false, "message": "Nicht verbunden."}
	var r: Dictionary = await _req(HTTPClient.METHOD_PUT, "/auth/v1/user", {"email": mail, "password": password})
	if bool(r["ok"]):
		email = mail
		is_anonymous = false
		_set_status("Online: " + email)
		auth_changed.emit()
		return {"ok": true, "message": "Account verknüpft. Falls E-Mail-Bestätigung aktiv ist: bitte Postfach prüfen."}
	return {"ok": false, "message": str(r["message"])}

## Meldet sich mit einem bestehenden E-Mail-Account an (z.B. auf einem neuen Geraet) und laedt dessen Spielstand.
func sign_in_email(mail: String, password: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "message": "Kein Backend konfiguriert."}
	leave_lobby()
	var r: Dictionary = await _req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": mail, "password": password}, false, [], false)
	if not _apply_session(r):
		return {"ok": false, "message": str(r.get("message", "Anmeldung fehlgeschlagen."))}
	await _after_login()
	auth_changed.emit()
	return {"ok": true, "message": "Angemeldet."}

## Abmelden: Session verwerfen und als neuer Gast weitermachen.
func sign_out() -> void:
	leave_lobby()
	access_token = ""
	refresh_token = ""
	user_id = ""
	email = ""
	friend_code = ""
	is_anonymous = true
	friends.clear()
	invites.clear()
	if FileAccess.file_exists(SESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	_set_status("Abgemeldet")
	auth_changed.emit()
	friends_updated.emit()
	invites_updated.emit()

# ================================================================ Profil-Sync

func _on_save_changed() -> void:
	if is_online():
		_push_timer = 3.0

func _profile_row() -> Dictionary:
	var d: Dictionary = GameManager.data
	return {
		"id": user_id,
		"username": GameManager.player_name(),
		"avatar_frame": GameManager.avatar_frame(),
		"avatar_color": int(d.get("avatar_color", 0)),
		"trophies": GameManager.trophies(),
		"coins": GameManager.coins(),
		"gems": GameManager.gems(),
		"equipped": d.get("equipped", {}),
		"save": d,
		"revision": int(d.get("revision", 0)),
		"device_id": GameManager.device_id(),
		"last_seen": _now_iso(),
	}

func _pull_profile() -> void:
	var r: Dictionary = await _api_get("/rest/v1/profiles?id=eq.%s&select=*" % user_id)
	if bool(r["ok"]) and r["data"] is Array and (r["data"] as Array).size() > 0:
		var row: Dictionary = (r["data"] as Array)[0]
		friend_code = str(row.get("friend_code", ""))
		var remote: Variant = row.get("save")
		if remote is Dictionary and not (remote as Dictionary).is_empty():
			if GameManager.apply_remote_save(remote):
				return
	_push_inventory = true
	await push_profile()

## Schreibt Profil (+ bei Bedarf Schlaeger und Inventar) nach Supabase.
func push_profile() -> void:
	_push_timer = -1.0
	if not is_online():
		return
	var r: Dictionary = await _api_post("/rest/v1/profiles?on_conflict=id", _profile_row(), "resolution=merge-duplicates,return=representation")
	if bool(r["ok"]) and r["data"] is Array and (r["data"] as Array).size() > 0:
		friend_code = str(((r["data"] as Array)[0] as Dictionary).get("friend_code", friend_code))
	if not _push_inventory:
		return
	_push_inventory = false
	var clubs: Array = []
	var owned_clubs: Dictionary = GameManager.data.get("clubs", {})
	for id in owned_clubs.keys():
		var c: Dictionary = owned_clubs[id]
		clubs.append({"user_id": user_id, "club_id": str(id), "level": int(c.get("level", 1)), "cards": int(c.get("cards", 0)),
			"equipped": str(id) == GameManager.equipped_club()})
	if clubs.size() > 0:
		await _api_post("/rest/v1/clubs?on_conflict=user_id,club_id", clubs, "resolution=merge-duplicates,return=minimal")
	var items: Array = []
	var owned: Dictionary = GameManager.data.get("owned", {})
	for kind in owned.keys():
		for item_id in (owned[kind] as Array):
			var eq: bool = GameManager.equipped(str(kind)) == str(item_id) or (str(kind) == "frame" and GameManager.avatar_frame() == str(item_id))
			items.append({"user_id": user_id, "item_type": str(kind), "item_id": str(item_id), "equipped": eq})
	if items.size() > 0:
		await _api_post("/rest/v1/inventory?on_conflict=user_id,item_type,item_id", items, "resolution=merge-duplicates,return=minimal")

func _ping_presence() -> void:
	_api_patch("/rest/v1/profiles?id=eq.%s" % user_id, {"last_seen": _now_iso()})

## Traegt ein beendetes Online-Match in match_results ein.
func report_match_result(summary: Dictionary, rewards: Dictionary, config: Dictionary) -> void:
	if not is_online():
		return
	_api_post("/rest/v1/match_results", {
		"user_id": user_id,
		"lobby_code": str(lobby.get("code", "")),
		"mode": str(config.get("mode", "quick")),
		"world": str(config.get("world", "")),
		"rounds": int(config.get("rounds", 0)),
		"rank": int(summary.get("rank", 0)),
		"players": int(summary.get("players", 0)),
		"strokes": int(summary.get("strokes", 0)),
		"style_points": int(summary.get("style_points", 0)),
		"trophies_delta": int(rewards.get("trophies", 0)),
		"coins": int(rewards.get("coins", 0)),
	}, "return=minimal")

# ================================================================ Freunde, Einladungen, Rangliste

static func _is_recent(iso: String) -> bool:
	if iso == "":
		return false
	var t: int = Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	return absf(Time.get_unix_time_from_system() - float(t)) < ONLINE_WINDOW_SECONDS

func refresh_friends() -> void:
	if not is_online():
		friends.clear()
		friends_updated.emit()
		return
	var r: Dictionary = await _api_get("/rest/v1/friends?select=id,user_id,friend_id,status&or=(user_id.eq.%s,friend_id.eq.%s)" % [user_id, user_id])
	if not bool(r["ok"]) or not (r["data"] is Array):
		return
	var rows: Array = r["data"]
	var ids := PackedStringArray()
	for row in rows:
		var other: String = str(row["friend_id"]) if str(row["user_id"]) == user_id else str(row["user_id"])
		if not ids.has(other):
			ids.append(other)
	var profiles := {}
	if ids.size() > 0:
		var pr: Dictionary = await _api_get("/rest/v1/public_profiles?select=id,username,trophies,avatar_frame,avatar_color,last_seen&id=in.(%s)" % ",".join(ids))
		if bool(pr["ok"]) and pr["data"] is Array:
			for p in (pr["data"] as Array):
				profiles[str(p["id"])] = p
	var out: Array = []
	for row in rows:
		var mine: bool = str(row["user_id"]) == user_id
		var other_id: String = str(row["friend_id"]) if mine else str(row["user_id"])
		var p: Dictionary = profiles.get(other_id, {})
		var state: String = "accepted" if str(row["status"]) == "accepted" else ("outgoing" if mine else "incoming")
		out.append({
			"row_id": row["id"], "id": other_id, "name": str(p.get("username", "Spieler")), "trophies": int(p.get("trophies", 0)),
			"frame": str(p.get("avatar_frame", "bronze")), "color": int(p.get("avatar_color", 0)),
			"online": _is_recent(str(p.get("last_seen", ""))) if p.get("last_seen") != null else false, "state": state,
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if bool(a["online"]) != bool(b["online"]):
			return bool(a["online"])
		return str(a["name"]).to_lower() < str(b["name"]).to_lower())
	friends = out
	friends_updated.emit()

## Sucht Spieler per Name (Teilstring) oder Freundes-Code. Rueckgabe: [{id, name, trophies, frame, color, code}]
func search_players(query: String) -> Array:
	var q: String = query.strip_edges()
	if not is_online() or q.length() < 2:
		return []
	var enc: String = q.uri_encode()
	var r: Dictionary = await _api_get("/rest/v1/public_profiles?select=id,username,trophies,avatar_frame,avatar_color,friend_code&or=(username.ilike.*%s*,friend_code.eq.%s)&id=neq.%s&limit=12" % [enc, q.to_upper().uri_encode(), user_id])
	var out: Array = []
	if bool(r["ok"]) and r["data"] is Array:
		for p in (r["data"] as Array):
			out.append({"id": str(p["id"]), "name": str(p.get("username", "Spieler")), "trophies": int(p.get("trophies", 0)),
				"frame": str(p.get("avatar_frame", "bronze")), "color": int(p.get("avatar_color", 0)), "code": str(p.get("friend_code", ""))})
	return out

func send_friend_request(other_id: String) -> Dictionary:
	if not is_online() or other_id == user_id:
		return {"ok": false, "message": "Nicht möglich."}
	var r: Dictionary = await _api_post("/rest/v1/friends", {"user_id": user_id, "friend_id": other_id, "status": "pending"}, "return=minimal")
	refresh_friends()
	return {"ok": bool(r["ok"]), "message": "Anfrage gesendet." if bool(r["ok"]) else "Bereits befreundet oder angefragt."}

func accept_friend(row_id: Variant) -> void:
	await _api_patch("/rest/v1/friends?id=eq.%s" % str(row_id), {"status": "accepted"})
	refresh_friends()

func remove_friend(row_id: Variant) -> void:
	await _api_delete("/rest/v1/friends?id=eq.%s" % str(row_id))
	refresh_friends()

## Laedt einen Freund in die aktuelle Lobby ein.
func invite_friend(friend_id: String) -> Dictionary:
	if not in_lobby() or not is_online():
		return {"ok": false, "message": "Erstelle zuerst eine Lobby."}
	var r: Dictionary = await _api_post("/rest/v1/lobby_invites", {"from_id": user_id, "to_id": friend_id, "code": str(lobby["code"])}, "return=minimal")
	return {"ok": bool(r["ok"]), "message": "Einladung gesendet." if bool(r["ok"]) else str(r["message"])}

func refresh_invites() -> void:
	if not is_online():
		invites.clear()
		invites_updated.emit()
		return
	var r: Dictionary = await _api_get("/rest/v1/lobby_invites?select=id,code,from_id,created_at&to_id=eq.%s&order=created_at.desc&limit=5" % user_id)
	if not bool(r["ok"]) or not (r["data"] is Array):
		return
	var out: Array = []
	for row in (r["data"] as Array):
		if not _is_recent(str(row.get("created_at", ""))) and Time.get_unix_time_from_system() - float(Time.get_unix_time_from_datetime_string(str(row.get("created_at", "")).substr(0, 19))) > 900.0:
			continue
		var from_name := "Freund"
		for f in friends:
			if str(f["id"]) == str(row["from_id"]):
				from_name = str(f["name"])
		out.append({"id": row["id"], "code": str(row["code"]), "from_id": str(row["from_id"]), "from_name": from_name})
	invites = out
	invites_updated.emit()

func dismiss_invite(invite_id: Variant) -> void:
	await _api_delete("/rest/v1/lobby_invites?id=eq.%s" % str(invite_id))
	refresh_invites()

## Rangliste nach Trophaeen. Offline: lokale Liste aus Bot-Namen + eigenem Stand.
func refresh_leaderboard() -> void:
	var out: Array = []
	if is_online():
		var r: Dictionary = await _api_get("/rest/v1/public_profiles?select=id,username,trophies,avatar_frame,avatar_color&order=trophies.desc&limit=50")
		if bool(r["ok"]) and r["data"] is Array:
			for p in (r["data"] as Array):
				out.append({"name": str(p.get("username", "Spieler")), "trophies": int(p.get("trophies", 0)),
					"frame": str(p.get("avatar_frame", "bronze")), "color": int(p.get("avatar_color", 0)), "me": str(p["id"]) == user_id})
	if out.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 20240607
		for i in Catalog.BOT_NAMES.size():
			var t: int = 2400 - i * 190 + rng.randi_range(-60, 60)
			out.append({"name": Catalog.BOT_NAMES[i], "trophies": maxi(0, t), "frame": str(Catalog.league_for(maxi(0, t))["id"]),
				"color": i % Catalog.AVATAR_COLORS.size(), "me": false})
		out.append({"name": GameManager.player_name(), "trophies": GameManager.trophies(), "frame": GameManager.avatar_frame(),
			"color": int(GameManager.data.get("avatar_color", 0)), "me": true})
		out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["trophies"]) > int(b["trophies"]))
	leaderboard = out
	leaderboard_updated.emit()

# ================================================================ Lobbys

func in_lobby() -> bool:
	return not lobby.is_empty()

## Host ist der Ersteller; ist er weg, uebernimmt die kleinste User-ID im Raum.
func is_host() -> bool:
	if not in_lobby():
		return true
	var host: String = str(lobby.get("host_id", ""))
	var smallest: String = user_id
	var host_present: bool = host == user_id
	for p in roster:
		var pid: String = str(p["id"])
		if pid == host:
			host_present = true
		if pid < smallest:
			smallest = pid
	if host_present:
		return host == user_id
	return smallest == user_id

func _random_code() -> String:
	var s := ""
	for i in 4:
		s += CODE_CHARS[_rng.randi_range(0, CODE_CHARS.length() - 1)]
	return s

func _my_roster_entry() -> Dictionary:
	var p: Dictionary = GameManager.public_profile()
	p["id"] = user_id
	return p

## Erstellt eine Lobby (privat mit Raum-Code oder oeffentlich fuers Schnellspiel).
func create_lobby(world_id: String, rounds: int, is_public: bool = false) -> void:
	if not is_online():
		lobby_error.emit("Online-Lobbys brauchen eine Internetverbindung und ein eingetragenes Backend.")
		return
	leave_lobby()
	var code: String = _random_code()
	var row := {"code": code, "host_id": user_id, "world": world_id, "rounds": rounds, "is_public": is_public, "status": "open", "player_count": 1}
	var r: Dictionary = await _api_post("/rest/v1/lobbies", row, "return=minimal")
	if not bool(r["ok"]):
		lobby_error.emit("Lobby konnte nicht erstellt werden: " + str(r["message"]))
		return
	lobby = {"code": code, "host_id": user_id, "world": world_id, "rounds": rounds, "is_public": is_public}
	_open_channel(code)

## Tritt einer Lobby per 4-stelligem Raum-Code bei.
func join_lobby(code_in: String) -> void:
	var code: String = code_in.strip_edges().to_upper()
	if not is_online():
		lobby_error.emit("Online-Lobbys brauchen eine Internetverbindung und ein eingetragenes Backend.")
		return
	if code.length() != 4:
		lobby_error.emit("Der Raum-Code hat 4 Zeichen.")
		return
	leave_lobby()
	var r: Dictionary = await _api_get("/rest/v1/lobbies?code=eq.%s&select=*" % code.uri_encode())
	if not bool(r["ok"]) or not (r["data"] is Array) or (r["data"] as Array).is_empty():
		lobby_error.emit("Lobby %s nicht gefunden." % code)
		return
	var row: Dictionary = (r["data"] as Array)[0]
	if str(row.get("status", "open")) != "open":
		lobby_error.emit("Diese Lobby spielt bereits.")
		return
	if int(row.get("player_count", 0)) >= Catalog.MAX_PLAYERS:
		lobby_error.emit("Die Lobby ist voll (6 Spieler).")
		return
	lobby = {"code": code, "host_id": str(row.get("host_id", "")), "world": str(row.get("world", "emerald")),
		"rounds": int(row.get("rounds", 3)), "is_public": bool(row.get("is_public", false))}
	_open_channel(code)

## Schnellspiel: offene oeffentliche Lobby suchen, sonst eine erstellen; nach kurzer Wartezeit startet der Host
## und fuellt mit Bots auf. Ohne Internet/Backend: sofort ein Bot-Match.
func quick_match(world_id: String, rounds: int) -> void:
	if not is_online():
		start_bot_match(world_id, rounds)
		return
	# nur frische Lobbys (juenger als 5 Minuten), damit niemand in einem verwaisten Raum landet
	var fresh: String = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) - 300) + "Z"
	var r: Dictionary = await _api_get("/rest/v1/lobbies?is_public=eq.true&status=eq.open&player_count=lt.%d&world=eq.%s&rounds=eq.%d&created_at=gt.%s&order=created_at.desc&limit=1" % [Catalog.MAX_PLAYERS, world_id.uri_encode(), rounds, fresh])
	if bool(r["ok"]) and r["data"] is Array and (r["data"] as Array).size() > 0:
		var row: Dictionary = (r["data"] as Array)[0]
		lobby = {"code": str(row["code"]), "host_id": str(row.get("host_id", "")), "world": world_id, "rounds": rounds, "is_public": true}
		_open_channel(str(row["code"]))
		return
	if not bool(r["ok"]):
		start_bot_match(world_id, rounds)
		return
	await create_lobby(world_id, rounds, true)
	if in_lobby():
		_quick_timer = QUICK_MATCH_WAIT
	else:
		start_bot_match(world_id, rounds)

## Offline-Bot-Modus (auch als Rueckfall, wenn der Server nicht erreichbar ist).
func start_bot_match(world_id: String, rounds: int, bots: int = 3) -> void:
	var config: Dictionary = GameManager.make_bot_match(world_id, rounds, bots)
	match_starting.emit(config)
	GameManager.start_match(config)

## Host: Welt/Runden aendern.
func set_lobby_settings(world_id: String, rounds: int) -> void:
	if not in_lobby() or not is_host():
		return
	lobby["world"] = world_id
	lobby["rounds"] = rounds
	_broadcast("settings", {"world": world_id, "rounds": rounds})
	_api_patch("/rest/v1/lobbies?code=eq.%s" % str(lobby["code"]), {"world": world_id, "rounds": rounds})
	lobby_updated.emit()

## Host: startet das Match fuer alle in der Lobby.
func start_lobby_match() -> void:
	if not in_lobby() or not is_host():
		return
	var entries: Array = []
	var sorted_roster: Array = roster.duplicate()
	sorted_roster.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	for i in mini(sorted_roster.size(), Catalog.MAX_PLAYERS):
		var p: Dictionary = sorted_roster[i]
		entries.append({"id": str(p["id"]), "name": str(p.get("name", "Spieler")), "kind": "human", "color": i,
			"ball": str(p.get("ball", "standard")), "trail": str(p.get("trail", "none")), "explosion": str(p.get("explosion", "confetti")),
			"frame": str(p.get("frame", "bronze")), "skill": 1.0, "trophies": int(p.get("trophies", 0))})
	if fill_bots:
		var names: Array = Catalog.BOT_NAMES.duplicate()
		names.shuffle()
		var tier: float = clampf(float(GameManager.trophies()) / 1500.0, 0.0, 1.0)
		var n := 0
		while entries.size() < 4:
			var bot: Dictionary = GameManager.make_bot_entry("bot_%s_%d" % [str(lobby["code"]), n], str(names[n % names.size()]), entries.size(), tier)
			entries.append(bot)
			n += 1
	var seed_value: int = int(_rng.randi() & 0x7fffffff)
	var mode: String = "quick" if bool(lobby.get("is_public", false)) else "private"
	var config: Dictionary = GameManager.make_match_config(mode, str(lobby["world"]), int(lobby["rounds"]), entries, seed_value, true)
	_broadcast("start", {"config": config})
	_api_patch("/rest/v1/lobbies?code=eq.%s" % str(lobby["code"]), {"status": "started"})
	_begin_match(config)

## Setzt je Client die Rollen: eigener Spieler = "local", Bots simuliert der Host, alle anderen sind "remote".
func _begin_match(config_in: Dictionary) -> void:
	var config: Dictionary = config_in.duplicate(true)
	var host: bool = is_host()
	var players: Array = config.get("players", [])
	for p in players:
		var pid: String = str(p.get("id", ""))
		if pid == user_id:
			p["kind"] = "local"
		elif str(p.get("kind", "")) == "bot":
			p["kind"] = "bot" if host else "remote"
		else:
			p["kind"] = "remote"
	config["courses"] = Array(config.get("courses", []))
	config["online"] = true
	_quick_timer = -1.0
	match_starting.emit(config)
	GameManager.start_match(config)

func leave_lobby() -> void:
	if not in_lobby():
		return
	var code: String = str(lobby.get("code", ""))
	var was_host: bool = str(lobby.get("host_id", "")) == user_id
	_close_channel()
	lobby = {}
	roster.clear()
	_quick_timer = -1.0
	if was_host and is_online():
		_api_delete("/rest/v1/lobbies?code=eq.%s" % code)
	lobby_left.emit("")
	lobby_updated.emit()

## Sendet ein Spiel-Ereignis an alle anderen in der Lobby (Position, Schlag, Emote ...).
func send_game_event(event: String, payload: Dictionary) -> void:
	if _joined:
		_broadcast("g", {"e": event, "d": payload})

# ================================================================ Realtime (Phoenix-Channels ueber WebSocket)
# Protokoll (vsn 1.0.0): JSON-Nachrichten {topic, event, payload, ref}.
#   Beitritt:   event "phx_join" mit config {broadcast:{self:false}, presence:{key}} + access_token
#   Herzschlag: topic "phoenix", event "heartbeat" alle 25 s
#   Broadcast:  event "broadcast", payload {type:"broadcast", event:<name>, payload:{...}}
#   Presence:   event "presence", payload {type:"presence", event:"track", payload:{...}}

func _open_channel(code: String) -> void:
	_close_channel()
	_topic = "realtime:golf-lobby-" + code
	_presence.clear()
	_ws = WebSocketPeer.new()
	var ws_url: String = "%s/realtime/v1/websocket?apikey=%s&vsn=1.0.0" % [url.replace("https://", "wss://"), anon_key]
	if _ws.connect_to_url(ws_url) != OK:
		_ws = null
		lobby = {}
		lobby_error.emit("Echtzeit-Verbindung fehlgeschlagen.")
		return
	_join_sent = false
	_joined = false
	_ws_open = false
	_heartbeat = 0.0

func _close_channel() -> void:
	if _ws != null:
		if _joined:
			_send(_topic, "phx_leave", {})
		_ws.close()
	_ws = null
	_ws_open = false
	_joined = false
	_join_sent = false
	_presence.clear()

func _send(topic: String, event: String, payload: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		return
	_ref += 1
	_ws.send_text(JSON.stringify({"topic": topic, "event": event, "payload": payload, "ref": str(_ref), "join_ref": "1"}))

func _broadcast(event: String, payload: Dictionary) -> void:
	_send(_topic, "broadcast", {"type": "broadcast", "event": event, "payload": payload})

func _poll_socket(delta: float) -> void:
	if _ws == null:
		return
	_ws.poll()
	var state: int = _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_ws_open = true
		if not _join_sent:
			_join_sent = true
			_send(_topic, "phx_join", {
				"config": {"broadcast": {"ack": false, "self": false}, "presence": {"key": user_id}, "postgres_changes": [], "private": false},
				"access_token": access_token,
			})
		_heartbeat += delta
		if _heartbeat >= HEARTBEAT_SECONDS:
			_heartbeat = 0.0
			_send("phoenix", "heartbeat", {})
		while _ws != null and _ws.get_available_packet_count() > 0:
			_on_socket_message(_ws.get_packet().get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		var was_joined: bool = _joined
		_ws = null
		_ws_open = false
		_joined = false
		if in_lobby():
			lobby = {}
			roster.clear()
			if was_joined:
				lobby_left.emit("Verbindung zur Lobby verloren.")
			else:
				lobby_error.emit("Lobby-Verbindung konnte nicht aufgebaut werden.")
			lobby_updated.emit()

func _on_socket_message(text: String) -> void:
	var msg: Variant = JSON.parse_string(text)
	if not (msg is Dictionary):
		return
	var m: Dictionary = msg
	var event: String = str(m.get("event", ""))
	var payload: Dictionary = m.get("payload", {}) if m.get("payload") is Dictionary else {}
	match event:
		"phx_reply":
			if str(m.get("topic", "")) == _topic and not _joined:
				if str(payload.get("status", "")) == "ok":
					_joined = true
					_send(_topic, "presence", {"type": "presence", "event": "track", "payload": _my_roster_entry()})
					_rebuild_roster()
					lobby_joined.emit(str(lobby.get("code", "")))
				else:
					_close_channel()
					lobby = {}
					lobby_error.emit("Beitritt abgelehnt.")
		"presence_state":
			_presence.clear()
			for key in payload.keys():
				_merge_presence(str(key), payload[key])
			_rebuild_roster()
		"presence_diff":
			var joins: Dictionary = payload.get("joins", {}) if payload.get("joins") is Dictionary else {}
			var leaves: Dictionary = payload.get("leaves", {}) if payload.get("leaves") is Dictionary else {}
			for key in leaves.keys():
				_presence.erase(str(key))
			for key in joins.keys():
				_merge_presence(str(key), joins[key])
			_rebuild_roster()
		"broadcast":
			_on_broadcast(str(payload.get("event", "")), payload.get("payload", {}) if payload.get("payload") is Dictionary else {})
		"phx_error", "phx_close":
			if str(m.get("topic", "")) == _topic:
				_close_channel()
				lobby = {}
				roster.clear()
				lobby_left.emit("Lobby geschlossen.")
				lobby_updated.emit()

func _merge_presence(key: String, entry: Variant) -> void:
	if not (entry is Dictionary):
		return
	var metas: Variant = (entry as Dictionary).get("metas", [])
	if metas is Array and (metas as Array).size() > 0 and (metas as Array)[0] is Dictionary:
		var meta: Dictionary = ((metas as Array)[0] as Dictionary).duplicate()
		meta["id"] = key
		_presence[key] = meta

func _rebuild_roster() -> void:
	var out: Array = []
	var me: Dictionary = _my_roster_entry()
	out.append(me)
	for key in _presence.keys():
		if str(key) == user_id:
			continue
		out.append(_presence[key])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"]))
	roster = out
	if is_host() and is_online() and in_lobby():
		_api_patch("/rest/v1/lobbies?code=eq.%s" % str(lobby["code"]), {"player_count": roster.size(), "host_id": user_id})
		lobby["host_id"] = user_id
	lobby_updated.emit()

func _on_broadcast(event: String, data: Dictionary) -> void:
	match event:
		"g":
			var inner: Dictionary = data.get("d", {}) if data.get("d") is Dictionary else {}
			game_event.emit(str(data.get("e", "")), inner)
		"settings":
			lobby["world"] = str(data.get("world", lobby.get("world", "emerald")))
			lobby["rounds"] = int(data.get("rounds", lobby.get("rounds", 3)))
			lobby_updated.emit()
		"start":
			if data.get("config") is Dictionary:
				_begin_match(data["config"])
