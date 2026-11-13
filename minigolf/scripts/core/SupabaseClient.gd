extends Node
## Autoload "Supa": Auth (E-Mail, Gast, Upgrade) + REST (PostgREST) ueber HTTPRequest.
## Alle Aufrufe sind awaitable und liefern {ok: bool, code: int, data: Variant}.

signal auth_changed(logged_in: bool)

const SESSION_PATH := "user://session.json"

var access_token: String = ""
var refresh_token: String = ""
var user_id: String = ""
var email: String = ""
var is_anonymous: bool = false
var username: String = ""

func _ready() -> void:
	_load_session()

func is_logged_in() -> bool:
	return user_id != "" and access_token != ""

# ---------------------------------------------------------------- Auth

func sign_up(mail: String, password: String) -> Dictionary:
	var r := await _req(HTTPClient.METHOD_POST, "/auth/v1/signup", {"email": mail, "password": password})
	return _handle_auth(r)

func sign_in(mail: String, password: String) -> Dictionary:
	var r := await _req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": mail, "password": password})
	return _handle_auth(r)

## Gast-Account (in Supabase: Authentication > Providers > "Allow anonymous sign-ins" aktivieren).
func sign_in_guest() -> Dictionary:
	var r := await _req(HTTPClient.METHOD_POST, "/auth/v1/signup", {})
	return _handle_auth(r)

## Gast -> echter Account (behaelt user_id, Fortschritt, Freunde).
func link_email(mail: String, password: String) -> Dictionary:
	var r := await _req(HTTPClient.METHOD_PUT, "/auth/v1/user", {"email": mail, "password": password})
	if r.ok:
		email = mail
		is_anonymous = false
		_save_session()
	return r

func refresh() -> bool:
	if refresh_token == "":
		return false
	var r := await _req(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false)
	return _handle_auth(r).ok

func sign_out() -> void:
	access_token = ""; refresh_token = ""; user_id = ""; email = ""; username = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_PATH))
	auth_changed.emit(false)

func _handle_auth(r: Dictionary) -> Dictionary:
	if r.ok and r.data is Dictionary and r.data.has("access_token"):
		var d: Dictionary = r.data
		access_token = str(d.get("access_token", ""))
		refresh_token = str(d.get("refresh_token", ""))
		var u: Dictionary = d.get("user", {})
		user_id = str(u.get("id", ""))
		email = str(u.get("email", ""))
		is_anonymous = bool(u.get("is_anonymous", email == ""))
		_save_session()
		auth_changed.emit(true)
	elif r.ok:
		# z.B. E-Mail-Bestaetigung noetig -> kein Token
		r["note"] = "Bitte bestaetige zuerst deine E-Mail."
	return r

func _save_session() -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"rt": refresh_token}))

func _load_session() -> void:
	if not FileAccess.file_exists(SESSION_PATH) or not Cfg.is_online_capable():
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SESSION_PATH))
	if d is Dictionary:
		refresh_token = str(d.get("rt", ""))
		refresh()   # fire-and-forget; auth_changed meldet das Ergebnis

# ---------------------------------------------------------------- REST

func rest_get(table_and_query: String) -> Dictionary:
	return await _req(HTTPClient.METHOD_GET, "/rest/v1/" + table_and_query)

func rest_insert(table: String, row: Dictionary, upsert: bool = false) -> Dictionary:
	var prefer := "return=representation" + (",resolution=merge-duplicates" if upsert else "")
	return await _req(HTTPClient.METHOD_POST, "/rest/v1/" + table, row, true, ["Prefer: " + prefer])

func rest_patch(table_and_query: String, patch: Dictionary) -> Dictionary:
	return await _req(HTTPClient.METHOD_PATCH, "/rest/v1/" + table_and_query, patch, true, ["Prefer: return=representation"])

func rest_delete(table_and_query: String) -> Dictionary:
	return await _req(HTTPClient.METHOD_DELETE, "/rest/v1/" + table_and_query)

# ---------------------------------------------------------------- intern

func _req(method: int, path: String, body: Variant = null, auth: bool = true, extra: Array = []) -> Dictionary:
	if not Cfg.is_online_capable():
		return {"ok": false, "code": 0, "data": null, "note": "Backend nicht konfiguriert (Offline-Modus)."}
	var req := HTTPRequest.new()
	req.timeout = 15.0
	add_child(req)
	var headers: PackedStringArray = ["apikey: " + Cfg.anon_key, "Content-Type: application/json"]
	headers.append("Authorization: Bearer " + (access_token if auth and access_token != "" else Cfg.anon_key))
	for h in extra:
		headers.append(str(h))
	var payload := "" if body == null else JSON.stringify(body)
	var err := req.request(Cfg.url + path, headers, method, payload)
	if err != OK:
		req.queue_free()
		return {"ok": false, "code": 0, "data": null, "note": "Request-Fehler %d" % err}
	var res: Array = await req.request_completed   # [result, code, headers, body]
	req.queue_free()
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	var code: int = res[1]
	var ok: bool = res[0] == HTTPRequest.RESULT_SUCCESS and code >= 200 and code < 300
	var out := {"ok": ok, "code": code, "data": parsed}
	if not ok and parsed is Dictionary:
		out["note"] = str(parsed.get("msg", parsed.get("message", parsed.get("error_description", ""))))
	return out
