extends Node
## Profilbild des Spielers (im Web-Portal hochgeladen, liegt im Supabase-Storage-Bucket "avatars").
##
## Sicherheit: Es wird nur ein Pfad der Form "<user-id>/avatar-<zahl>.<png|jpg|webp>" akzeptiert und
## ausschliesslich vom eingetragenen Supabase-Server geladen. Groesse ist begrenzt, kaputte Bilder werden verworfen.
## Das letzte Bild wird lokal zwischengespeichert, damit es auch offline sichtbar ist.

signal avatar_changed

const BUCKET := "avatars"
const MAX_AVATAR_BYTES := 512 * 1024
const MAX_SIDE := 512
const CACHE_PATH := "user://avatar_cache.bin"
const CACHE_META_PATH := "user://avatar_cache.json"

## Aktuelles Profilbild (null = keins -> Initiale im Avatar-Kreis)
var avatar_texture: Texture2D = null
var avatar_path: String = ""
var _loading: String = ""

func _ready() -> void:
	_load_cache()
	AuthManager.auth_changed.connect(_on_auth_changed)

func _on_auth_changed() -> void:
	if not AuthManager.is_online():
		return
	# Falls der Pfad zu einem anderen Account gehoert, zuruecksetzen (das Profil wird danach neu geladen)
	if avatar_path != "" and not avatar_path.begins_with(AuthManager.user_id + "/"):
		clear_avatar()

## Prueft einen Speicherpfad: "<uuid>/avatar-<ziffern>.<png|jpg|jpeg|webp>"
static func is_valid_path(path: String, owner_id: String = "") -> bool:
	var re := RegEx.new()
	re.compile("^([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/avatar-[0-9]{1,16}\\.(png|jpg|jpeg|webp)$")
	var m := re.search(path)
	if m == null:
		return false
	return owner_id == "" or m.get_string(1) == owner_id

## Oeffentliche URL eines Profilbilds (nur auf dem eingetragenen Supabase-Server).
static func public_url(base_url: String, path: String) -> String:
	return "%s/storage/v1/object/public/%s/%s" % [base_url, BUCKET, path]

## Wird vom NetworkManager mit dem avatar_path aus dem Profil aufgerufen.
func set_avatar_path(path: String) -> void:
	var p: String = path.strip_edges()
	if p == "":
		clear_avatar()
		return
	if not is_valid_path(p, AuthManager.user_id):
		return
	if p == avatar_path and avatar_texture != null:
		return
	_download(p)

func clear_avatar() -> void:
	avatar_path = ""
	avatar_texture = null
	for f in [CACHE_PATH, CACHE_META_PATH]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	avatar_changed.emit()

func _download(path: String) -> void:
	if _loading == path or not AuthManager.is_configured():
		return
	_loading = path
	var req := HTTPRequest.new()
	req.timeout = 15.0
	req.body_size_limit = MAX_AVATAR_BYTES
	add_child(req)
	var err: int = req.request(public_url(AuthManager.url, path), PackedStringArray(["apikey: " + AuthManager.anon_key]))
	if err != OK:
		req.queue_free()
		_loading = ""
		return
	var res: Array = await req.request_completed
	req.queue_free()
	_loading = ""
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or int(res[1]) != 200:
		return
	var bytes: PackedByteArray = res[3]
	var img: Image = decode_image(bytes)
	if img == null:
		return
	avatar_path = path
	avatar_texture = ImageTexture.create_from_image(img)
	_save_cache(path, bytes)
	avatar_changed.emit()

## Erkennt das Format an den ersten Bytes (PNG, JPEG, WebP) und dekodiert es.
## Liefert null bei unbekanntem/kaputtem Bild oder zu grosser Datei. Zu grosse Bilder werden verkleinert.
static func decode_image(bytes: PackedByteArray) -> Image:
	if bytes.size() < 12 or bytes.size() > MAX_AVATAR_BYTES:
		return null
	var img := Image.new()
	var err: int = ERR_FILE_UNRECOGNIZED
	if bytes[0] == 0x89 and bytes[1] == 0x50 and bytes[2] == 0x4E and bytes[3] == 0x47:
		err = img.load_png_from_buffer(bytes)
	elif bytes[0] == 0xFF and bytes[1] == 0xD8:
		err = img.load_jpg_from_buffer(bytes)
	elif bytes.slice(0, 4).get_string_from_ascii() == "RIFF" and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		err = img.load_webp_from_buffer(bytes)
	if err != OK or img.is_empty() or img.get_width() < 8 or img.get_height() < 8:
		return null
	if img.get_width() > MAX_SIDE or img.get_height() > MAX_SIDE:
		var s: float = float(MAX_SIDE) / float(maxi(img.get_width(), img.get_height()))
		img.resize(maxi(8, int(img.get_width() * s)), maxi(8, int(img.get_height() * s)), Image.INTERPOLATE_BILINEAR)
	return img

func _save_cache(path: String, bytes: PackedByteArray) -> void:
	var f := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_buffer(bytes)
	f.close()
	var m := FileAccess.open(CACHE_META_PATH, FileAccess.WRITE)
	if m != null:
		m.store_string(JSON.stringify({"path": path}))
		m.close()

func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH) or not FileAccess.file_exists(CACHE_META_PATH):
		return
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(CACHE_META_PATH))
	if not (meta is Dictionary):
		return
	var path: String = str((meta as Dictionary).get("path", ""))
	if not is_valid_path(path):
		return
	var img: Image = decode_image(FileAccess.get_file_as_bytes(CACHE_PATH))
	if img == null:
		return
	avatar_path = path
	avatar_texture = ImageTexture.create_from_image(img)
