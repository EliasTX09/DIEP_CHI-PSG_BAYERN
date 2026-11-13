extends Node
## Autoload "Progression": Waehrung, Besitz, Upgrades, Ausruestung. Lokal gespeichert,
## bei Login nach Supabase (profiles.save) synchronisiert.
## ACHTUNG: Client-seitig = manipulierbar. Fuer Release: Kaeufe/Belohnungen per RPC/Edge Function.

signal changed

const SAVE_PATH := "user://progress.json"

var coins: int = 200
var gems: int = 5
var owned: Dictionary = {"club": ["rookie"], "ball": ["white"], "trail": ["none"], "fx": ["confetti"]}
var club_levels: Dictionary = {"rookie": 0}
var equipped: Dictionary = {"club": "rookie", "ball": "white", "trail": "none", "fx": "confetti"}

func _ready() -> void:
	load_local()
	Supa.auth_changed.connect(_on_auth)

func _on_auth(ok: bool) -> void:
	if ok:
		pull_remote()

# ---- Shop-Logik ----
func owns(kind: String, id: String) -> bool:
	return id in owned.get(kind, [])

func price(kind: String, id: String) -> int:
	return int(Catalog.table(kind)[id]["price"])

func buy(kind: String, id: String) -> bool:
	if owns(kind, id) or coins < price(kind, id):
		return false
	coins -= price(kind, id)
	owned[kind].append(id)
	if kind == "club":
		club_levels[id] = 0
	_commit()
	return true

func upgrade_club(id: String) -> bool:
	var lvl: int = int(club_levels.get(id, 0))
	if not owns("club", id) or lvl >= Catalog.MAX_LEVEL:
		return false
	var cost := Catalog.upgrade_cost(id, lvl)
	if coins < cost:
		return false
	coins -= cost
	club_levels[id] = lvl + 1
	_commit()
	return true

func equip(kind: String, id: String) -> void:
	if owns(kind, id):
		equipped[kind] = id
		_commit()

func add_coins(n: int) -> void:
	coins += n
	_commit()

func current_club_stats() -> Dictionary:
	var id: String = equipped["club"]
	return Catalog.club_stats(id, int(club_levels.get(id, 0)))

# ---- Persistenz ----
func to_dict() -> Dictionary:
	return {"coins": coins, "gems": gems, "owned": owned, "club_levels": club_levels, "equipped": equipped}

func from_dict(d: Dictionary) -> void:
	coins = int(d.get("coins", coins))
	gems = int(d.get("gems", gems))
	owned = d.get("owned", owned)
	club_levels = d.get("club_levels", club_levels)
	equipped = d.get("equipped", equipped)

func _commit() -> void:
	save_local()
	changed.emit()
	push_remote()

func save_local() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))

func load_local() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary:
			from_dict(d)

func push_remote() -> void:
	if Supa.is_logged_in():
		Supa.rest_patch("profiles?id=eq." + Supa.user_id, {"coins": coins, "gems": gems, "save": to_dict()})

func pull_remote() -> void:
	var r: Dictionary = await Supa.rest_get("profiles?id=eq.%s&select=username,save" % Supa.user_id)
	if r.ok and r.data is Array and r.data.size() > 0:
		var row: Dictionary = r.data[0]
		Supa.username = str(row.get("username", ""))
		var s = row.get("save")
		if s is Dictionary and not s.is_empty():
			from_dict(s)
			save_local()
		else:
			push_remote()   # neues Profil: lokalen Stand hochladen
		changed.emit()
