class_name MockSupabase
extends Node
## Minimaler Schein-Supabase-Server fuer den Smoke-Test (nur 127.0.0.1).
## Bildet die Endpunkte nach, die AuthManager/NetworkManager/ProfileManager benutzen - so wie sie in der
## Supabase-Doku beschrieben sind. Er prueft den Ablauf im Spiel, NICHT das Verhalten des echten Servers.

const GUEST_ID := "11111111-1111-4111-8111-111111111111"
const WEB_ID := "22222222-2222-4222-8222-222222222222"
const VALID_CODE := "ABCD2345"
const WEB_EMAIL := "spieler@example.com"

var port: int = 0
## Protokoll: ["POST /auth/v1/signup", ...]
var requests_log: PackedStringArray = PackedStringArray()
var web_save: Dictionary = {}
var avatar_png: PackedByteArray = PackedByteArray()

var _server := TCPServer.new()
var _clients: Array[Dictionary] = []

func start() -> bool:
	for p in range(54321, 54400):
		if _server.listen(p, "127.0.0.1") == OK:
			port = p
			break
	if port == 0:
		return false
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.3, 0.2))
	avatar_png = img.save_png_to_buffer()
	web_save = GameManager.default_save()
	web_save["name"] = "WebHeld"
	web_save["trophies"] = 777
	web_save["best_trophies"] = 777
	web_save["coins"] = 4321
	web_save["revision"] = 5
	web_save["pass"] = {"season": GameManager.pass_season(), "xp": 450, "claimed": [0]}
	return true

func base_url() -> String:
	return "http://127.0.0.1:%d" % port

func _process(_delta: float) -> void:
	while _server.is_connection_available():
		_clients.append({"peer": _server.take_connection(), "buf": PackedByteArray()})
	for c in _clients.duplicate():
		var peer: StreamPeerTCP = c["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_clients.erase(c)
			continue
		var avail: int = peer.get_available_bytes()
		if avail > 0:
			var got: Array = peer.get_partial_data(avail)
			if int(got[0]) == OK:
				var b: PackedByteArray = c["buf"]
				b.append_array(got[1])
				c["buf"] = b
		var req: Dictionary = _parse(c["buf"])
		if req.is_empty():
			continue
		var resp: Array = _route(str(req["method"]), str(req["path"]), str(req["body"]))
		_send(peer, int(resp[0]), resp[1], str(resp[2]) if resp.size() > 2 else "application/json")
		peer.disconnect_from_host()
		_clients.erase(c)

## Zerlegt einen vollstaendigen HTTP-Request. Leeres Dictionary = noch nicht komplett.
func _parse(buf: PackedByteArray) -> Dictionary:
	var text: String = buf.get_string_from_utf8()
	var head_end: int = text.find("\r\n\r\n")
	if head_end < 0:
		return {}
	var head: String = text.substr(0, head_end)
	var lines: PackedStringArray = head.split("\r\n")
	var first: PackedStringArray = lines[0].split(" ")
	if first.size() < 2:
		return {}
	var length := 0
	for l in lines:
		if l.to_lower().begins_with("content-length:"):
			length = int(l.substr(15).strip_edges())
	var body_bytes: int = buf.size() - (head_end + 4)
	if body_bytes < length:
		return {}
	var body: String = buf.slice(head_end + 4, head_end + 4 + length).get_string_from_utf8()
	return {"method": first[0], "path": first[1], "body": body}

func _send(peer: StreamPeerTCP, code: int, payload: Variant, content_type: String) -> void:
	var bytes: PackedByteArray
	if payload is PackedByteArray:
		bytes = payload
	elif payload == null:
		bytes = PackedByteArray()
	else:
		bytes = JSON.stringify(payload).to_utf8_buffer()
	var reason: String = {200: "OK", 201: "Created", 204: "No Content", 400: "Bad Request", 401: "Unauthorized", 404: "Not Found"}.get(code, "OK")
	var head: String = "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" % [code, reason, content_type, bytes.size()]
	peer.put_data(head.to_utf8_buffer())
	if bytes.size() > 0:
		peer.put_data(bytes)

static func _session(id: String, mail: String, anonymous: bool, rt: String) -> Dictionary:
	return {"access_token": "at-" + rt, "token_type": "bearer", "expires_in": 3600, "refresh_token": rt,
		"user": {"id": id, "email": mail if mail != "" else null, "is_anonymous": anonymous}}

## Rueckgabe: [status, payload(, content-type)]
func _route(method: String, path: String, body: String) -> Array:
	requests_log.append(method + " " + path)
	var data: Variant = JSON.parse_string(body) if body != "" else null
	var d: Dictionary = data if data is Dictionary else {}
	if method == "POST" and path == "/auth/v1/signup":
		return [200, _session(GUEST_ID, "", true, "rt-guest")]
	if method == "POST" and path.begins_with("/auth/v1/token?grant_type=refresh_token"):
		match str(d.get("refresh_token", "")):
			"rt-guest":
				return [200, _session(GUEST_ID, "", true, "rt-guest")]
			"rt-web-code", "rt-web":
				return [200, _session(WEB_ID, WEB_EMAIL, false, "rt-web")]
		return [400, {"error": "invalid_grant", "error_description": "Invalid Refresh Token"}]
	if method == "POST" and path.begins_with("/auth/v1/logout"):
		return [204, null]
	if method == "POST" and path == "/rest/v1/rpc/redeem_game_link_code":
		if str(d.get("p_code", "")) == VALID_CODE:
			return [200, "rt-web-code"]
		return [400, {"message": "invalid or expired code"}]
	if method == "GET" and path.begins_with("/rest/v1/profiles?id=eq." + WEB_ID):
		return [200, [{"id": WEB_ID, "username": "WebHeld", "friend_code": "WEBFRND1", "save": web_save,
			"avatar_path": WEB_ID + "/avatar-1700000000.png"}]]
	if method == "GET" and path.begins_with("/rest/v1/profiles"):
		return [200, []]
	if method == "POST" and path.begins_with("/rest/v1/profiles"):
		return [201, [{"friend_code": "GASTFRND"}]]
	if method == "GET" and path.begins_with("/storage/v1/object/public/avatars/" + WEB_ID + "/"):
		return [200, avatar_png, "image/png"]
	if method == "GET":
		return [200, []]
	if method == "PATCH" or method == "DELETE":
		return [204, null]
	if method == "POST":
		return [201, []]
	return [404, {"message": "not found"}]
