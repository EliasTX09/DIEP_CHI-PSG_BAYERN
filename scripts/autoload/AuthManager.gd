extends Node
## Anmeldung und Supabase-Verbindung (einziger Besitzer von User-ID und Tokens).
##
## Wege zum Account:
##  1. Sofort-Gast: anonyme Supabase-Session beim ersten Start (Geraete-ID im Profil).
##  2. Web-Portal (GitHub Pages, Ordner webapp/): Registrieren/Einloggen im Browser, dort "Spiel-Code" erzeugen
##     und im Spiel eingeben -> redeem_web_code(). Die Website legt dafuer eine eigene, unabhaengige Anmeldung an
##     (separater Passwort-Login); ihre eigene Browser-Sitzung wird nie weitergegeben.
##  3. Direkt im Spiel: Gast mit E-Mail/Passwort verknuepfen oder mit E-Mail/Passwort anmelden.
##
## Gespeichert wird nur das Refresh-Token in user://auth.json, verschluesselt mit einem geraetebezogenen Schluessel.
## Das ist eine Verschleierung gegen Mitlesen, kein Schutz gegen jemanden mit vollem Zugriff auf das Geraet.

signal auth_changed
signal status_changed(text: String)
## Wird VOR einem Account-Wechsel/Abmelden gesendet (z.B. um eine Lobby sauber zu verlassen).
signal account_changing

const CONFIG_PATH := "res://config/backend.cfg"
const LOCAL_CONFIG_PATH := "res://config/backend.local.cfg"
const AUTH_PATH := "user://auth.json"
const LEGACY_SESSION_PATH := "user://session.json"
## Zeichen der Spiel-Codes (ohne 0/O/1/I/L - nicht verwechselbar) und ihre Laenge.
const CODE_CHARS := "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
const CODE_LENGTH := 8
const REQUEST_TIMEOUT := 12.0

var url: String = ""
var anon_key: String = ""
## Adresse des Web-Portals (GitHub Pages), z.B. https://name.github.io/repo/
var portal_url: String = ""

var user_id: String = ""
var access_token: String = ""
var refresh_token: String = ""
var email: String = ""
var is_anonymous: bool = true
var status: String = "Offline"

var _busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	if is_configured():
		auto_login.call_deferred()
	else:
		_set_status("Offline-Modus (kein Backend eingetragen)")

func _load_config() -> void:
	var cf := ConfigFile.new()
	var path: String = LOCAL_CONFIG_PATH if FileAccess.file_exists(LOCAL_CONFIG_PATH) else CONFIG_PATH
	if cf.load(path) != OK:
		return
	url = str(cf.get_value("supabase", "url", "")).strip_edges().trim_suffix("/")
	anon_key = str(cf.get_value("supabase", "anon_key", "")).strip_edges()
	portal_url = str(cf.get_value("web", "portal_url", "")).strip_edges()

## true, wenn echte Supabase-Zugangsdaten eingetragen sind (keine Platzhalter).
## Unverschluesseltes http ist nur fuer einen lokalen Testserver (127.0.0.1) erlaubt.
func is_configured() -> bool:
	return (url.begins_with("https://") or url.begins_with("http://127.0.0.1:")) and not url.contains("DEIN-PROJEKT") and anon_key.length() > 20 and not anon_key.begins_with("DEIN_")

## true, wenn eine Web-Portal-Adresse eingetragen ist.
func has_portal() -> bool:
	return portal_url.begins_with("https://") and not portal_url.contains("DEINNAME")

## true, wenn eingeloggt (Gast oder Account) und damit online-faehig.
func is_online() -> bool:
	return is_configured() and user_id != "" and access_token != ""

## Netzwerk-ID des lokalen Spielers.
func local_id() -> String:
	return user_id if user_id != "" else "local"

func _set_status(text: String) -> void:
	status = text
	status_changed.emit(text)

# ================================================================ HTTP

## Fuehrt einen Request gegen Supabase aus. Rueckgabe: {ok, code, data, message}
## Bei 401 wird die Session einmal erneuert und der Request wiederholt.
func request(method: int, path: String, body: Variant = null, auth: bool = true, extra_headers: Array = [], allow_refresh: bool = true) -> Dictionary:
	if not is_configured():
		return {"ok": false, "code": 0, "data": null, "message": "Kein Backend konfiguriert."}
	var req := HTTPRequest.new()
	req.timeout = REQUEST_TIMEOUT
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
			return await request(method, path, body, auth, extra_headers, false)
	return {"ok": ok, "code": code, "data": parsed, "message": "" if ok else error_message(int(res[0]), code, parsed)}

## Lesbare Fehlermeldung aus einer Supabase-Antwort.
static func error_message(result: int, code: int, parsed: Variant) -> String:
	if result != HTTPRequest.RESULT_SUCCESS:
		return "Keine Verbindung zum Server."
	if parsed is Dictionary:
		var d: Dictionary = parsed
		return str(d.get("msg", d.get("message", d.get("error_description", d.get("error", "Fehler %d" % code)))))
	return "Fehler %d" % code

# ================================================================ Session

## Beim Start: gespeicherte Session erneuern, sonst sofort als Gast anmelden.
func auto_login() -> void:
	if _busy or not is_configured():
		return
	_busy = true
	_set_status("Verbinde …")
	var ok := false
	refresh_token = load_saved_refresh_token()
	if refresh_token != "":
		ok = await _refresh_session()
	if not ok:
		ok = await _sign_in_guest()
	_busy = false
	if ok:
		_set_status(_online_text())
	else:
		_set_status("Offline-Modus (Server nicht erreichbar)")
	auth_changed.emit()

func _online_text() -> String:
	return "Online als Gast" if is_anonymous else "Online: " + email

## Anonyme Supabase-Session (Dashboard: Authentication -> Sign In / Providers -> "Allow anonymous sign-ins").
func _sign_in_guest() -> bool:
	var body := {"data": {"device_id": GameManager.device_id(), "name": GameManager.player_name()}}
	var r: Dictionary = await request(HTTPClient.METHOD_POST, "/auth/v1/signup", body, false, [], false)
	return _apply_session(r)

func _refresh_session() -> bool:
	if refresh_token == "":
		return false
	var r: Dictionary = await request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=refresh_token", {"refresh_token": refresh_token}, false, [], false)
	return _apply_session(r)

## Uebernimmt eine Token-Antwort von GoTrue ({access_token, refresh_token, user}).
func _apply_session(r: Dictionary) -> bool:
	if not bool(r.get("ok", false)) or not (r.get("data") is Dictionary):
		return false
	var d: Dictionary = r["data"]
	if not d.has("access_token") or not d.has("refresh_token"):
		return false
	var u: Dictionary = d.get("user", {}) if d.get("user") is Dictionary else {}
	var new_id: String = str(u.get("id", ""))
	if new_id == "":
		return false
	access_token = str(d["access_token"])
	refresh_token = str(d["refresh_token"])
	user_id = new_id
	email = str(u.get("email", "")) if u.get("email") != null else ""
	is_anonymous = bool(u.get("is_anonymous", email == ""))
	save_refresh_token(refresh_token)
	return true

## Verknuepft den Gast-Account mit E-Mail + Passwort (User-ID und Fortschritt bleiben erhalten).
func link_email(mail: String, password: String) -> Dictionary:
	if not is_online():
		return {"ok": false, "message": "Nicht verbunden."}
	if not is_valid_email(mail) or password.length() < 6:
		return {"ok": false, "message": "Bitte gültige E-Mail und ein Passwort mit mind. 6 Zeichen eingeben."}
	var r: Dictionary = await request(HTTPClient.METHOD_PUT, "/auth/v1/user", {"email": mail, "password": password})
	if bool(r["ok"]):
		email = mail
		is_anonymous = false
		_set_status(_online_text())
		auth_changed.emit()
		return {"ok": true, "message": "Account verknüpft. Falls E-Mail-Bestätigung aktiv ist: bitte Postfach prüfen."}
	return {"ok": false, "message": str(r["message"])}

## Meldet sich mit einem bestehenden E-Mail-Account an (z.B. auf einem neuen Geraet).
func sign_in_email(mail: String, password: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "message": "Kein Backend konfiguriert."}
	if not is_valid_email(mail) or password.length() < 6:
		return {"ok": false, "message": "Bitte gültige E-Mail und ein Passwort mit mind. 6 Zeichen eingeben."}
	account_changing.emit()
	var r: Dictionary = await request(HTTPClient.METHOD_POST, "/auth/v1/token?grant_type=password", {"email": mail, "password": password}, false, [], false)
	if not _apply_session(r):
		return {"ok": false, "message": str(r.get("message", "Anmeldung fehlgeschlagen."))}
	_set_status(_online_text())
	auth_changed.emit()
	return {"ok": true, "message": "Angemeldet."}

## Abmelden: Session verwerfen; danach (optional) sofort als neuer Gast weiter.
func sign_out(continue_as_guest: bool = true) -> void:
	account_changing.emit()
	if is_online():
		# Session serverseitig beenden (Fehler sind egal - lokal wird sie in jedem Fall verworfen)
		request(HTTPClient.METHOD_POST, "/auth/v1/logout?scope=local", {}, true, [], false)
	access_token = ""
	refresh_token = ""
	user_id = ""
	email = ""
	is_anonymous = true
	clear_saved_session()
	_set_status("Abgemeldet")
	auth_changed.emit()
	if continue_as_guest and is_configured():
		auto_login()

# ================================================================ Web-Portal

## Oeffnet das Web-Portal (Registrieren, Profilbild, Freunde, Spiel-Code) im Browser.
func open_portal() -> bool:
	if not has_portal():
		return false
	return OS.shell_open(portal_url) == OK

## Normalisiert eine Code-Eingabe ("abcd-2345" -> "ABCD2345"). Leerer String = ungueltig.
static func normalize_code(text: String) -> String:
	var out := ""
	for ch in text.to_upper():
		if ch == " " or ch == "-":
			continue
		if not CODE_CHARS.contains(ch):
			return ""
		out += ch
	return out if out.length() == CODE_LENGTH else ""

static func is_valid_email(mail: String) -> bool:
	var at: int = mail.find("@")
	return at > 0 and mail.find(".", at) > at + 1 and not mail.contains(" ") and mail.length() <= 254

## Loest einen auf der Website erzeugten Spiel-Code ein und meldet das Spiel mit dem Web-Account an.
## Der Code gilt 10 Minuten und nur einmal; die Datenbank gibt dafuer eine eigens erzeugte Anmeldung heraus.
func redeem_web_code(code_input: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "message": "Kein Backend konfiguriert."}
	var code: String = normalize_code(code_input)
	if code == "":
		return {"ok": false, "message": "Der Code hat %d Zeichen (Buchstaben und Ziffern)." % CODE_LENGTH}
	var r: Dictionary = await request(HTTPClient.METHOD_POST, "/rest/v1/rpc/redeem_game_link_code", {"p_code": code}, false, [], false)
	if not bool(r["ok"]):
		return {"ok": false, "message": "Code ungültig oder abgelaufen."}
	var token: String = ""
	if r["data"] is String:
		token = str(r["data"])
	elif r["data"] is Dictionary:
		token = str((r["data"] as Dictionary).get("refresh_token", ""))
	if token == "":
		return {"ok": false, "message": "Code ungültig oder abgelaufen."}
	account_changing.emit()
	var old_refresh: String = refresh_token
	refresh_token = token
	if not await _refresh_session():
		refresh_token = old_refresh
		return {"ok": false, "message": "Anmeldung mit dem Code fehlgeschlagen. Bitte neuen Code erzeugen."}
	_set_status(_online_text())
	auth_changed.emit()
	return {"ok": true, "message": "Mit Web-Account verbunden: " + (email if email != "" else "Account")}

# ================================================================ Lokale Speicherung

## Schluessel fuer die lokale Verschluesselung (geraetebezogen; Verschleierung, kein echter Schutz).
static func _storage_key() -> String:
	return "golfbattle3d-auth|" + OS.get_unique_id()

static func save_refresh_token(token: String) -> void:
	var f := FileAccess.open_encrypted_with_pass(AUTH_PATH, FileAccess.WRITE, _storage_key())
	if f == null:
		return
	f.store_string(JSON.stringify({"v": 1, "rt": token, "saved": Time.get_unix_time_from_system()}))
	f.close()

## Liest das gespeicherte Refresh-Token. Unlesbare Datei = keine Session (dann Gast-Login).
## Uebernimmt einmalig die alte unverschluesselte session.json.
static func load_saved_refresh_token() -> String:
	if FileAccess.file_exists(LEGACY_SESSION_PATH):
		var legacy: Variant = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_SESSION_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(LEGACY_SESSION_PATH))
		if legacy is Dictionary and str((legacy as Dictionary).get("rt", "")) != "":
			var token: String = str((legacy as Dictionary)["rt"])
			save_refresh_token(token)
			return token
	if not FileAccess.file_exists(AUTH_PATH):
		return ""
	var f := FileAccess.open_encrypted_with_pass(AUTH_PATH, FileAccess.READ, _storage_key())
	if f == null:
		return ""
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		return str((parsed as Dictionary).get("rt", ""))
	return ""

static func clear_saved_session() -> void:
	for p in [AUTH_PATH, LEGACY_SESSION_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
