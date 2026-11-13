extends Node
## Autoload "GameManager": Speicherstand, Coins, Gems, Trophaeen/Ligen, Truhen-Timer,
## Schlaeger-Stats & Upgrades, Inventar, Daily Challenge, Match-Start und Match-Belohnungen.
## Der Speicherstand liegt lokal (user://save.json); NetworkManager synchronisiert ihn
## bei Bedarf mit Supabase (er lauscht auf `save_changed`).

signal currency_changed
signal inventory_changed
signal chests_changed
signal profile_changed
signal settings_changed
signal save_changed
signal toast(message: String)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1
const MENU_SCENE := "res://scenes/MainMenu3D.tscn"
const GAME_SCENE := "res://scenes/Game.tscn"

var data: Dictionary = {}
## Konfiguration des naechsten/aktuellen Matches (siehe make_match_config()).
var match_config: Dictionary = {}
## Ergebnis des letzten Matches (fuer das Menue, z.B. Truhen-Hinweis).
var last_match_rewards: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _save_dirty: bool = false
var _save_timer: float = 0.0
var _chest_tick: float = 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	load_game()

func _process(delta: float) -> void:
	if _save_dirty:
		_save_timer -= delta
		if _save_timer <= 0.0:
			save_game()
	_chest_tick += delta
	if _chest_tick >= 1.0:
		_chest_tick = 0.0
		_update_chest_states()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST \
			or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if _save_dirty:
			save_game()

# ================================================================ Speicherstand

func default_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"device_id": _new_device_id(),
		"name": "Gast%04d" % _rng.randi_range(0, 9999),
		"avatar_frame": "bronze",
		"avatar_color": _rng.randi_range(0, Catalog.AVATAR_COLORS.size() - 1),
		"coins": 500,
		"gems": 30,
		"trophies": 0,
		"best_trophies": 0,
		"clubs": {Catalog.START_CLUB: {"level": 1, "cards": 0}},
		"equipped": {"club": Catalog.START_CLUB, "ball": "standard", "trail": "none", "explosion": "confetti"},
		"owned": {"ball": ["standard"], "trail": ["none"], "explosion": ["confetti"], "frame": ["bronze"]},
		"chests": [null, null, null, null],
		"road_claimed": [],
		"daily": {"date": "", "played": false, "best": -1.0},
		"gift_date": "",
		"stats": {"matches": 0, "wins": 0, "holes_in_one": 0, "best_style": 0, "shots": 0, "holes": 0},
		"settings": {"sfx": 0.8, "vibration": true, "quality": 1, "camera_sens": 1.0},
		"revision": 0,
		"updated_at": 0.0,
		# Account (Supabase-User-ID), mit dem dieser Spielstand zuletzt abgeglichen wurde ("" = nur lokal)
		"account_id": "",
	}

func _new_device_id() -> String:
	# Zufaellige, lokal erzeugte Geraete-ID (UUID-aehnlich) - identifiziert den Gast-Account.
	var bytes := PackedByteArray()
	for i in 16:
		bytes.append(_rng.randi_range(0, 255))
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]

func load_game() -> void:
	var loaded: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var txt := FileAccess.get_file_as_string(SAVE_PATH)
		var parsed: Variant = JSON.parse_string(txt)
		if parsed is Dictionary:
			loaded = parsed
	data = default_save()
	if not loaded.is_empty():
		_merge_into(data, loaded)
	_sanitize()

## Uebernimmt nur bekannte Schluessel (schuetzt vor kaputten/alten Speicherstaenden).
func _merge_into(target: Dictionary, src: Dictionary) -> void:
	for k in src.keys():
		if not target.has(k):
			continue
		var tv: Variant = target[k]
		var sv: Variant = src[k]
		if tv is Dictionary and sv is Dictionary:
			if k == "clubs":
				target[k] = (sv as Dictionary).duplicate(true)
			else:
				_merge_into(tv, sv)
		elif tv is Array and sv is Array:
			target[k] = (sv as Array).duplicate(true)
		elif tv is Dictionary or tv is Array:
			continue
		else:
			target[k] = sv

func _sanitize() -> void:
	data["coins"] = maxi(0, int(data.get("coins", 0)))
	data["gems"] = maxi(0, int(data.get("gems", 0)))
	data["trophies"] = maxi(0, int(data.get("trophies", 0)))
	data["best_trophies"] = maxi(int(data["trophies"]), int(data.get("best_trophies", 0)))
	data["avatar_color"] = clampi(int(data.get("avatar_color", 0)), 0, Catalog.AVATAR_COLORS.size() - 1)
	var clubs: Dictionary = data["clubs"]
	var clean := {}
	for id in clubs.keys():
		if Catalog.CLUB_NAMES.has(id) and clubs[id] is Dictionary:
			var c: Dictionary = clubs[id]
			clean[id] = {
				"level": clampi(int(c.get("level", 1)), 1, Catalog.club_max_level(str(id))),
				"cards": maxi(0, int(c.get("cards", 0))),
			}
	if not clean.has(Catalog.START_CLUB):
		clean[Catalog.START_CLUB] = {"level": 1, "cards": 0}
	data["clubs"] = clean
	var chests: Array = data["chests"]
	while chests.size() < Catalog.CHEST_SLOTS:
		chests.append(null)
	while chests.size() > Catalog.CHEST_SLOTS:
		chests.pop_back()
	for i in chests.size():
		var c: Variant = chests[i]
		if c is Dictionary and Catalog.CHESTS.has(str((c as Dictionary).get("type", ""))):
			continue
		chests[i] = null
	var owned: Dictionary = data["owned"]
	for kind in ["ball", "trail", "explosion", "frame"]:
		if not (owned.get(kind) is Array):
			owned[kind] = []
		var arr: Array = owned[kind]
		var table := Catalog.item_table(kind)
		var filtered: Array = []
		for id in arr:
			if table.has(id) and not filtered.has(id):
				filtered.append(id)
		owned[kind] = filtered
	for pair in [["ball", "standard"], ["trail", "none"], ["explosion", "confetti"], ["frame", "bronze"]]:
		if not (owned[pair[0]] as Array).has(pair[1]):
			(owned[pair[0]] as Array).append(pair[1])
	var eq: Dictionary = data["equipped"]
	if not clean.has(str(eq.get("club", ""))):
		eq["club"] = Catalog.START_CLUB
	for kind in ["ball", "trail", "explosion"]:
		if not (owned[kind] as Array).has(eq.get(kind)):
			eq[kind] = (owned[kind] as Array)[0]
	if not (owned["frame"] as Array).has(data.get("avatar_frame")):
		data["avatar_frame"] = "bronze"
	if str(data.get("name", "")).strip_edges() == "":
		data["name"] = "Gast%04d" % _rng.randi_range(0, 9999)

func save_game() -> void:
	_save_dirty = false
	data["updated_at"] = Time.get_unix_time_from_system()
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))
		f.close()

## Markiert den Stand als geaendert: lokal speichern (leicht verzoegert) + Sync anstossen.
func mark_dirty() -> void:
	data["revision"] = int(data.get("revision", 0)) + 1
	_save_dirty = true
	_save_timer = 0.5
	save_changed.emit()

## Ersetzt den lokalen Stand durch einen Stand vom Server (nur wenn dieser neuer ist).
func apply_remote_save(remote: Dictionary) -> bool:
	if remote.is_empty():
		return false
	if int(remote.get("revision", 0)) <= int(data.get("revision", 0)):
		return false
	var device: String = str(data.get("device_id", ""))
	data = default_save()
	_merge_into(data, remote)
	data["device_id"] = device
	_sanitize()
	_save_dirty = true
	_save_timer = 0.1
	currency_changed.emit()
	inventory_changed.emit()
	chests_changed.emit()
	profile_changed.emit()
	settings_changed.emit()
	return true

## Gleicht den lokalen Spielstand mit dem Stand eines Accounts ab (nach Login/Account-Wechsel).
## Regel - es geht nie still Fortschritt verloren:
##  - Server-Stand leer           -> lokaler Stand gehoert ab jetzt diesem Account ("upload")
##  - gleicher Account wie bisher -> der neuere Stand (Revision) gewinnt ("loaded" bzw. "upload")
##  - anderer Account mit Stand   -> Server-Stand wird geladen; hatte der lokale Stand echten Fortschritt,
##                                   wird er vorher als Sicherungsdatei abgelegt ("loaded_backup")
## Rueckgabe: "upload" (Aufrufer laedt hoch) | "loaded" | "loaded_backup"
func adopt_account_save(account: String, remote: Dictionary) -> String:
	var owner: String = str(data.get("account_id", ""))
	if remote.is_empty():
		data["account_id"] = account
		mark_dirty()
		return "upload"
	if owner == account:
		if apply_remote_save(remote):
			data["account_id"] = account
			return "loaded"
		return "upload"
	var outcome: String = "loaded"
	if has_real_progress():
		backup_save("account-wechsel")
		outcome = "loaded_backup"
	var device: String = str(data.get("device_id", ""))
	data = default_save()
	_merge_into(data, remote)
	data["device_id"] = device
	data["account_id"] = account
	_sanitize()
	_save_dirty = true
	_save_timer = 0.1
	currency_changed.emit()
	inventory_changed.emit()
	chests_changed.emit()
	profile_changed.emit()
	settings_changed.emit()
	if outcome == "loaded_backup":
		toast.emit("Spielstand des Accounts geladen. Dein bisheriger Stand wurde gesichert.")
	return outcome

## Hat der lokale Stand Fortschritt, der nicht verloren gehen darf?
func has_real_progress() -> bool:
	var st: Dictionary = data.get("stats", {})
	return trophies() > 0 or int(st.get("matches", 0)) > 0 or (data.get("clubs", {}) as Dictionary).size() > 1

## Legt eine Kopie des aktuellen Spielstands an (user://save_backup_<zeit>_<grund>.json, max. 5 Stueck).
func backup_save(reason: String) -> String:
	var path: String = "user://save_backup_%d_%s.json" % [int(Time.get_unix_time_from_system()), reason.validate_filename()]
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data))
	f.close()
	var backups: Array[String] = []
	var dir := DirAccess.open("user://")
	if dir != null:
		for file in dir.get_files():
			if file.begins_with("save_backup_") and file.ends_with(".json"):
				backups.append(file)
	backups.sort()
	while backups.size() > 5:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://" + backups.pop_front()))
	return path

func reset_progress() -> void:
	var device: String = str(data.get("device_id", ""))
	var account: String = str(data.get("account_id", ""))
	var revision: int = int(data.get("revision", 0))
	data = default_save()
	if device != "":
		data["device_id"] = device
	# Account und Revision behalten, damit der zurueckgesetzte Stand beim Abgleich als neuester gilt
	data["account_id"] = account
	data["revision"] = revision
	mark_dirty()
	currency_changed.emit()
	inventory_changed.emit()
	chests_changed.emit()
	profile_changed.emit()
	settings_changed.emit()

# ================================================================ Profil

func player_name() -> String:
	return str(data.get("name", "Gast"))

func set_player_name(n: String) -> bool:
	var clean := n.strip_edges()
	if clean.length() < 3 or clean.length() > 16:
		return false
	data["name"] = clean
	mark_dirty()
	profile_changed.emit()
	return true

func avatar_frame() -> String:
	return str(data.get("avatar_frame", "bronze"))

func avatar_color() -> Color:
	return Catalog.AVATAR_COLORS[clampi(int(data.get("avatar_color", 0)), 0, Catalog.AVATAR_COLORS.size() - 1)]

func set_avatar_color(index: int) -> void:
	data["avatar_color"] = clampi(index, 0, Catalog.AVATAR_COLORS.size() - 1)
	mark_dirty()
	profile_changed.emit()

func set_avatar_frame(id: String) -> bool:
	if not owns("frame", id):
		return false
	data["avatar_frame"] = id
	mark_dirty()
	profile_changed.emit()
	return true

func device_id() -> String:
	return str(data.get("device_id", ""))

## Oeffentliche Kurzinfo ueber den lokalen Spieler (fuer Lobby/Netzwerk/Match).
func public_profile() -> Dictionary:
	var eq: Dictionary = data["equipped"]
	return {
		"name": player_name(),
		"frame": avatar_frame(),
		"color": int(data.get("avatar_color", 0)),
		"trophies": trophies(),
		"ball": str(eq.get("ball", "standard")),
		"trail": str(eq.get("trail", "none")),
		"explosion": str(eq.get("explosion", "confetti")),
	}

# ================================================================ Waehrung

func coins() -> int:
	return int(data.get("coins", 0))

func gems() -> int:
	return int(data.get("gems", 0))

func add_coins(n: int) -> void:
	data["coins"] = maxi(0, coins() + n)
	mark_dirty()
	currency_changed.emit()

func add_gems(n: int) -> void:
	data["gems"] = maxi(0, gems() + n)
	mark_dirty()
	currency_changed.emit()

func can_afford(coin_cost: int, gem_cost: int) -> bool:
	return coins() >= coin_cost and gems() >= gem_cost

func spend(coin_cost: int, gem_cost: int) -> bool:
	if not can_afford(coin_cost, gem_cost):
		return false
	data["coins"] = coins() - coin_cost
	data["gems"] = gems() - gem_cost
	mark_dirty()
	currency_changed.emit()
	return true

## Gems in Coins tauschen (Shop).
func exchange_gems(gem_cost: int, coin_gain: int) -> bool:
	if gems() < gem_cost:
		return false
	data["gems"] = gems() - gem_cost
	data["coins"] = coins() + coin_gain
	mark_dirty()
	currency_changed.emit()
	return true

# ================================================================ Trophaeen & Ligen

func trophies() -> int:
	return int(data.get("trophies", 0))

func league() -> Dictionary:
	return Catalog.league_for(trophies())

func add_trophies(delta: int) -> void:
	var t: int = maxi(0, trophies() + delta)
	data["trophies"] = t
	data["best_trophies"] = maxi(t, int(data.get("best_trophies", 0)))
	_unlock_league_frames()
	mark_dirty()
	profile_changed.emit()

func _unlock_league_frames() -> void:
	var best: int = int(data.get("best_trophies", 0))
	var idx: int = Catalog.league_index(best)
	for i in idx + 1:
		var lid: String = str(Catalog.LEAGUES[i]["id"])
		for fid in Catalog.FRAME_ORDER:
			if str(Catalog.FRAMES[fid]["league"]) == lid and not owns("frame", fid):
				(data["owned"]["frame"] as Array).append(fid)

## Indizes der Trophaeen-Pfad-Belohnungen, die erreicht, aber noch nicht abgeholt sind.
func claimable_road() -> Array[int]:
	var out: Array[int] = []
	var best: int = int(data.get("best_trophies", 0))
	var claimed: Array = data["road_claimed"]
	for i in Catalog.TROPHY_ROAD.size():
		if best >= int(Catalog.TROPHY_ROAD[i]["at"]) and not _array_has_int(claimed, i):
			out.append(i)
	return out

func road_claimed(index: int) -> bool:
	return _array_has_int(data["road_claimed"], index)

func _array_has_int(arr: Array, value: int) -> bool:
	for v in arr:
		if int(v) == value:
			return true
	return false

## Holt eine Pfad-Belohnung ab. Liefert die gewaehrten Belohnungen ({} wenn nicht moeglich).
func claim_road(index: int) -> Dictionary:
	if index < 0 or index >= Catalog.TROPHY_ROAD.size() or road_claimed(index):
		return {}
	var entry: Dictionary = Catalog.TROPHY_ROAD[index]
	if int(data.get("best_trophies", 0)) < int(entry["at"]):
		return {}
	if entry.has("chest") and free_chest_slot() < 0:
		toast.emit("Kein freier Truhen-Slot!")
		return {}
	(data["road_claimed"] as Array).append(index)
	var rewards := {}
	if entry.has("coins"):
		rewards["coins"] = int(entry["coins"])
	if entry.has("gems"):
		rewards["gems"] = int(entry["gems"])
	if entry.has("chest"):
		rewards["chest"] = str(entry["chest"])
	var items: Array = []
	if entry.has("frame"):
		items.append({"kind": "frame", "id": str(entry["frame"])})
	if entry.has("item"):
		var it: Array = entry["item"]
		items.append({"kind": str(it[0]), "id": str(it[1])})
	if not items.is_empty():
		rewards["items"] = items
	grant(rewards)
	return rewards

# ================================================================ Schlaeger

func owns_club(id: String) -> bool:
	return (data["clubs"] as Dictionary).has(id)

func club_level(id: String) -> int:
	if not owns_club(id):
		return 0
	return int(data["clubs"][id].get("level", 1))

func club_cards(id: String) -> int:
	if not owns_club(id):
		return 0
	return int(data["clubs"][id].get("cards", 0))

func club_stats(id: String) -> Dictionary:
	return Catalog.club_stats(id, maxi(1, club_level(id)))

func equipped_club() -> String:
	return str(data["equipped"].get("club", Catalog.START_CLUB))

func equipped(kind: String) -> String:
	return str(data["equipped"].get(kind, ""))

## Fertige Schlag-Parameter des ausgeruesteten Schlaegers + Ball-Boni (fuer Ball3D).
func shot_profile() -> Dictionary:
	return make_shot_profile(equipped_club(), maxi(1, club_level(equipped_club())), equipped("ball"))

static func make_shot_profile(club_id: String, level: int, ball_id: String) -> Dictionary:
	var st := Catalog.club_stats(club_id, level)
	var bonus: Dictionary = {}
	if Catalog.BALLS.has(ball_id):
		bonus = Catalog.BALLS[ball_id]["bonus"]
	return {
		"power": Catalog.power_factor(float(st["power"])) * (1.0 + float(bonus.get("power", 0.0))),
		"scatter_deg": Catalog.scatter_degrees(float(st["accuracy"])),
		"spin": Catalog.spin_factor(float(st["spin"])),
		"guide": Catalog.guide_seconds(float(st["guide"])),
		"loft_deg": float(Catalog.CATEGORY_LOFT.get(Catalog.club_category(club_id), 36.0)),
		"wind_resist": float(bonus.get("wind_resist", 0.0)),
		"roll_bonus": float(bonus.get("roll", 0.0)),
		"bounce_bonus": float(bonus.get("bounce", 0.0)),
	}

func add_club_cards(id: String, count: int) -> void:
	if not Catalog.CLUB_NAMES.has(id) or count <= 0:
		return
	var clubs: Dictionary = data["clubs"]
	if not clubs.has(id):
		clubs[id] = {"level": 1, "cards": 0}
		count -= 1   # die erste Karte schaltet den Schlaeger frei
	clubs[id]["cards"] = int(clubs[id].get("cards", 0)) + maxi(0, count)

func club_is_max(id: String) -> bool:
	return club_level(id) >= Catalog.club_max_level(id)

func can_upgrade_club(id: String) -> bool:
	if not owns_club(id) or club_is_max(id):
		return false
	var lvl := club_level(id)
	return club_cards(id) >= Catalog.upgrade_card_cost(id, lvl) and coins() >= Catalog.upgrade_coin_cost(id, lvl)

func upgrade_club(id: String) -> bool:
	if not can_upgrade_club(id):
		return false
	var lvl := club_level(id)
	data["clubs"][id]["cards"] = club_cards(id) - Catalog.upgrade_card_cost(id, lvl)
	data["coins"] = coins() - Catalog.upgrade_coin_cost(id, lvl)
	data["clubs"][id]["level"] = lvl + 1
	mark_dirty()
	currency_changed.emit()
	inventory_changed.emit()
	return true

func equip_club(id: String) -> bool:
	if not owns_club(id):
		return false
	data["equipped"]["club"] = id
	mark_dirty()
	inventory_changed.emit()
	return true

# ================================================================ Inventar (Baelle, Trails, Explosionen, Rahmen)

func owns(kind: String, id: String) -> bool:
	if kind == "club":
		return owns_club(id)
	var owned: Dictionary = data["owned"]
	if not owned.has(kind):
		return false
	return (owned[kind] as Array).has(id)

func item_price(kind: String, id: String) -> Vector2i:
	var t := Catalog.item_table(kind)
	if not t.has(id):
		return Vector2i.ZERO
	return Vector2i(int(t[id].get("coins", 0)), int(t[id].get("gems", 0)))

func item_buyable(kind: String, id: String) -> bool:
	if owns(kind, id):
		return false
	if kind == "frame" and str(Catalog.FRAMES[id].get("league", "")) != "":
		return false   # Liga-Rahmen gibt es nur ueber den Trophaeen-Pfad
	var p := item_price(kind, id)
	return p.x > 0 or p.y > 0

func buy_item(kind: String, id: String) -> bool:
	if not item_buyable(kind, id):
		return false
	var p := item_price(kind, id)
	if not spend(p.x, p.y):
		return false
	(data["owned"][kind] as Array).append(id)
	mark_dirty()
	inventory_changed.emit()
	return true

func equip(kind: String, id: String) -> bool:
	if kind == "club":
		return equip_club(id)
	if kind == "frame":
		return set_avatar_frame(id)
	if not owns(kind, id):
		return false
	data["equipped"][kind] = id
	mark_dirty()
	inventory_changed.emit()
	return true

func _unowned_items() -> Array:
	var out: Array = []
	for kind in ["ball", "trail", "explosion"]:
		for id in Catalog.item_order(kind):
			if not owns(kind, id):
				out.append({"kind": kind, "id": id})
	return out

# ================================================================ Truhen

func chest_slot(slot: int) -> Dictionary:
	var chests: Array = data["chests"]
	if slot < 0 or slot >= chests.size() or chests[slot] == null:
		return {}
	return chests[slot]

func free_chest_slot() -> int:
	var chests: Array = data["chests"]
	for i in chests.size():
		if chests[i] == null:
			return i
	return -1

func add_chest(type: String) -> bool:
	if not Catalog.CHESTS.has(type):
		return false
	var slot := free_chest_slot()
	if slot < 0:
		return false
	(data["chests"] as Array)[slot] = {"type": type, "state": "locked", "unlock_at": 0.0}
	mark_dirty()
	chests_changed.emit()
	return true

## "empty" | "locked" | "unlocking" | "ready"
func chest_state(slot: int) -> String:
	var c := chest_slot(slot)
	if c.is_empty():
		return "empty"
	var st: String = str(c.get("state", "locked"))
	if st == "unlocking" and Time.get_unix_time_from_system() >= float(c.get("unlock_at", 0.0)):
		return "ready"
	return st

func chest_remaining(slot: int) -> float:
	var c := chest_slot(slot)
	if c.is_empty():
		return 0.0
	var st := chest_state(slot)
	if st == "locked":
		return float(Catalog.CHESTS[str(c["type"])]["seconds"])
	if st == "unlocking":
		return maxf(0.0, float(c.get("unlock_at", 0.0)) - Time.get_unix_time_from_system())
	return 0.0

func chest_gem_cost(slot: int) -> int:
	return Catalog.chest_skip_cost(chest_remaining(slot))

func unlocking_slot() -> int:
	for i in Catalog.CHEST_SLOTS:
		if chest_state(i) == "unlocking":
			return i
	return -1

## Startet den Timer einer Truhe (immer nur eine gleichzeitig).
func start_unlock(slot: int) -> bool:
	if chest_state(slot) != "locked" or unlocking_slot() >= 0:
		return false
	var c := chest_slot(slot)
	c["state"] = "unlocking"
	c["unlock_at"] = Time.get_unix_time_from_system() + float(Catalog.CHESTS[str(c["type"])]["seconds"])
	mark_dirty()
	chests_changed.emit()
	return true

## Oeffnet eine Truhe: fertig -> gratis; sonst mit Gems (use_gems). Liefert die Belohnungen.
func open_chest(slot: int, use_gems: bool) -> Dictionary:
	var st := chest_state(slot)
	if st == "empty":
		return {}
	if st != "ready":
		if not use_gems:
			return {}
		var cost := chest_gem_cost(slot)
		if gems() < cost:
			toast.emit("Nicht genug Gems!")
			return {}
		data["gems"] = gems() - cost
	var type: String = str(chest_slot(slot)["type"])
	(data["chests"] as Array)[slot] = null
	var rewards := roll_chest(type)
	grant(rewards)
	chests_changed.emit()
	return rewards

## Kauft eine Truhe im Shop und oeffnet sie sofort.
func buy_chest(type: String) -> Dictionary:
	if not Catalog.CHESTS.has(type):
		return {}
	var price: int = int(Catalog.CHESTS[type]["gem_price"])
	if gems() < price:
		toast.emit("Nicht genug Gems!")
		return {}
	data["gems"] = gems() - price
	var rewards := roll_chest(type)
	grant(rewards)
	return rewards

func _update_chest_states() -> void:
	var changed := false
	var chests: Array = data["chests"]
	for i in chests.size():
		if chests[i] == null:
			continue
		var c: Dictionary = chests[i]
		if str(c.get("state", "")) == "unlocking" and Time.get_unix_time_from_system() >= float(c.get("unlock_at", 0.0)):
			c["state"] = "ready"
			changed = true
	if changed:
		mark_dirty()
		chests_changed.emit()

## Wuerfelt den Inhalt einer Truhe aus: {coins, gems, cards: {club_id: n}, items: [{kind, id}], chest_type}.
func roll_chest(type: String) -> Dictionary:
	var def: Dictionary = Catalog.CHESTS[type]
	var out := {"chest_type": type}
	var coin_range: Array = def["coins"]
	var gem_range: Array = def["gems"]
	out["coins"] = _rng.randi_range(int(coin_range[0]), int(coin_range[1]))
	var g: int = _rng.randi_range(int(gem_range[0]), int(gem_range[1]))
	if g > 0:
		out["gems"] = g
	var cards := {}
	var total: int = int(def["cards"])
	var weights: Array = def["weights"]
	var stacks: int = clampi(int(ceil(float(total) / 5.0)), 2, 6)
	var remaining := total
	for s in stacks:
		var amount: int = remaining if s == stacks - 1 else maxi(1, int(round(float(total) / float(stacks) * _rng.randf_range(0.6, 1.4))))
		amount = mini(amount, remaining - (stacks - 1 - s))
		if amount <= 0:
			continue
		remaining -= amount
		var rar := _pick_rarity(weights)
		# seltenere Karten kommen in kleineren Stapeln
		var scaled: int = maxi(1, int(round(float(amount) * float(Catalog.RARITY_CARD_MULT[rar]))))
		var cat: String = Catalog.CATEGORIES[_rng.randi_range(0, Catalog.CATEGORIES.size() - 1)]
		var id := "%s_%s" % [cat, rar]
		cards[id] = int(cards.get(id, 0)) + scaled
	out["cards"] = cards
	if _rng.randf() < float(def["item_chance"]):
		var pool := _unowned_items()
		if not pool.is_empty():
			out["items"] = [pool[_rng.randi_range(0, pool.size() - 1)]]
		else:
			out["coins"] = int(out["coins"]) + 500
	return out

func _pick_rarity(weights: Array) -> String:
	var total := 0.0
	for w in weights:
		total += float(w)
	var r := _rng.randf() * total
	for i in weights.size():
		r -= float(weights[i])
		if r <= 0.0:
			return Catalog.RARITIES[i]
	return Catalog.RARITIES[0]

## Schreibt Belohnungen gut: coins, gems, cards{}, items[], chest (Typ), trophies.
func grant(rewards: Dictionary) -> void:
	if rewards.has("coins"):
		data["coins"] = coins() + int(rewards["coins"])
	if rewards.has("gems"):
		data["gems"] = gems() + int(rewards["gems"])
	if rewards.has("cards"):
		var cards: Dictionary = rewards["cards"]
		for id in cards.keys():
			add_club_cards(str(id), int(cards[id]))
	if rewards.has("items"):
		for it in (rewards["items"] as Array):
			var kind: String = str(it["kind"])
			var id: String = str(it["id"])
			if not owns(kind, id) and (data["owned"] as Dictionary).has(kind):
				(data["owned"][kind] as Array).append(id)
	if rewards.has("chest") and str(rewards["chest"]) != "":
		add_chest(str(rewards["chest"]))
	if rewards.has("trophies"):
		var t: int = maxi(0, trophies() + int(rewards["trophies"]))
		data["trophies"] = t
		data["best_trophies"] = maxi(t, int(data.get("best_trophies", 0)))
		_unlock_league_frames()
	mark_dirty()
	currency_changed.emit()
	inventory_changed.emit()
	chests_changed.emit()
	profile_changed.emit()

## Kurzer Text fuer eine Belohnungs-Zusammenfassung (UI).
static func describe_rewards(rewards: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	if rewards.has("trophies") and int(rewards["trophies"]) != 0:
		lines.append("%+d Trophäen" % int(rewards["trophies"]))
	if rewards.has("coins") and int(rewards["coins"]) > 0:
		lines.append("+%d Coins" % int(rewards["coins"]))
	if rewards.has("gems") and int(rewards["gems"]) > 0:
		lines.append("+%d Gems" % int(rewards["gems"]))
	if rewards.has("cards"):
		var cards: Dictionary = rewards["cards"]
		for id in cards.keys():
			lines.append("%d× %s (%s)" % [int(cards[id]), Catalog.club_name(str(id)), Catalog.RARITY_NAMES[Catalog.club_rarity(str(id))]])
	if rewards.has("items"):
		for it in (rewards["items"] as Array):
			lines.append("NEU: %s „%s“" % [Catalog.kind_name(str(it["kind"])), Catalog.item_name(str(it["kind"]), str(it["id"]))])
	if rewards.has("chest") and str(rewards["chest"]) != "":
		lines.append("%s erhalten" % str(Catalog.CHESTS[str(rewards["chest"])]["name"]))
	return lines

# ================================================================ Tagesgeschenk & Daily Challenge

func today() -> String:
	return Time.get_date_string_from_system()

func gift_available() -> bool:
	return str(data.get("gift_date", "")) != today()

func claim_gift() -> Dictionary:
	if not gift_available():
		return {}
	data["gift_date"] = today()
	var rewards := {"coins": _rng.randi_range(60, 140)}
	if _rng.randf() < 0.35:
		rewards["gems"] = _rng.randi_range(2, 6)
	grant(rewards)
	return rewards

func daily_available() -> bool:
	var d: Dictionary = data["daily"]
	return str(d.get("date", "")) != today() or not bool(d.get("played", false))

## Fester Seed pro Kalendertag -> alle Spieler bekommen denselben Golden-Shot-Parcours.
func daily_seed() -> int:
	return absi(hash("golden-shot-" + today()))

func daily_best() -> float:
	var d: Dictionary = data["daily"]
	if str(d.get("date", "")) != today():
		return -1.0
	return float(d.get("best", -1.0))

## Schliesst den Golden Shot ab: Entfernung zur Fahne (Meter) bzw. eingelocht.
func finish_daily(distance: float, holed: bool) -> Dictionary:
	var rewards: Dictionary = Catalog.daily_rewards(distance, holed).duplicate(true)
	if rewards.has("chest") and free_chest_slot() < 0:
		rewards.erase("chest")
		rewards["coins"] = int(rewards.get("coins", 0)) + 300
	data["daily"] = {"date": today(), "played": true, "best": 0.0 if holed else distance}
	grant(rewards)
	last_match_rewards = rewards
	return rewards

# ================================================================ Einstellungen

func setting(key: String, fallback: Variant = null) -> Variant:
	return (data["settings"] as Dictionary).get(key, fallback)

func set_setting(key: String, value: Variant) -> void:
	data["settings"][key] = value
	mark_dirty()
	settings_changed.emit()

func vibrate(ms: int) -> void:
	if bool(setting("vibration", true)) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

# ================================================================ Match

## Baut eine Match-Konfiguration.
## mode: "quick" (Bots/Online-Schnellspiel) | "private" (Lobby) | "daily" (Golden Shot) | "practice"
## players: Array von {id, name, kind ("local"|"bot"|"remote"), color, ball, trail, explosion, frame, skill}
func make_match_config(mode: String, world_id: String, rounds: int, players: Array, rng_seed: int, online: bool) -> Dictionary:
	var courses: Array[String] = []
	if mode == "daily":
		courses = ["daily"]
	else:
		courses = Catalog.build_course_list(world_id, rounds, rng_seed)
	return {
		"mode": mode,
		"world": world_id,
		"rounds": courses.size(),
		"courses": courses,
		"players": players,
		"seed": rng_seed,
		"online": online,
	}

## Offline-Match gegen Bots.
func make_bot_match(world_id: String, rounds: int, bot_count: int) -> Dictionary:
	var players: Array = [local_player_entry()]
	var names: Array = Catalog.BOT_NAMES.duplicate()
	names.shuffle()
	var tier: float = clampf(float(trophies()) / 1500.0, 0.0, 1.0)
	for i in clampi(bot_count, 1, Catalog.MAX_PLAYERS - 1):
		players.append(make_bot_entry("bot%d" % i, str(names[i % names.size()]), i + 1, tier))
	return make_match_config("quick", world_id, rounds, players, int(_rng.randi() & 0x7fffffff), false)

func make_bot_entry(id: String, bot_name: String, color_index: int, tier: float) -> Dictionary:
	var balls: Array = Catalog.BALL_ORDER.duplicate()
	var trails: Array = Catalog.TRAIL_ORDER.duplicate()
	var fx: Array = Catalog.EXPLOSION_ORDER.duplicate()
	return {
		"id": id,
		"name": bot_name,
		"kind": "bot",
		"color": color_index % Catalog.PLAYER_COLORS.size(),
		"ball": str(balls[_rng.randi_range(0, balls.size() - 1)]),
		"trail": str(trails[_rng.randi_range(0, trails.size() - 1)]),
		"explosion": str(fx[_rng.randi_range(0, fx.size() - 1)]),
		"frame": str(Catalog.LEAGUES[Catalog.league_index(trophies())]["id"]),
		"skill": clampf(0.35 + 0.5 * tier + _rng.randf_range(-0.12, 0.12), 0.15, 0.95),
		"trophies": maxi(0, trophies() + _rng.randi_range(-80, 80)),
	}

func local_player_entry() -> Dictionary:
	var p := public_profile()
	return {
		"id": "local",
		"name": str(p["name"]),
		"kind": "local",
		"color": 0,
		"ball": str(p["ball"]),
		"trail": str(p["trail"]),
		"explosion": str(p["explosion"]),
		"frame": str(p["frame"]),
		"skill": 1.0,
		"trophies": trophies(),
	}

func start_match(config: Dictionary) -> void:
	match_config = config
	last_match_rewards = {}
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file(GAME_SCENE)

func goto_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)

## Verbucht ein beendetes Match.
## summary: {rank, players, style_points, holes_in_one, strokes, holes}
func finish_match(summary: Dictionary) -> Dictionary:
	var rank: int = int(summary.get("rank", 1))
	var count: int = int(summary.get("players", 1))
	var style: int = int(summary.get("style_points", 0))
	var rewards := {}
	var mode: String = str(match_config.get("mode", "quick"))
	if mode == "practice" or count <= 1:
		rewards["coins"] = 20 + int(float(style) * Catalog.STYLE_TO_COINS)
	else:
		var delta: int = Catalog.trophies_for_rank(rank, count)
		if trophies() + delta < 0:
			delta = -trophies()
		rewards["trophies"] = delta
		var base: int = Catalog.coins_for_rank(rank)
		var style_coins: int = int(float(style) * Catalog.STYLE_TO_COINS)
		var bonus: Dictionary = Catalog.BALLS[equipped("ball")]["bonus"] if Catalog.BALLS.has(equipped("ball")) else {}
		var total: int = int(round(float(base + style_coins) * (1.0 + float(bonus.get("coins", 0.0)))))
		rewards["coins"] = total
		rewards["style_coins"] = style_coins
		var chest := ""
		if free_chest_slot() >= 0:
			var roll := _rng.randf()
			if rank == 1:
				chest = "gold" if roll < 0.25 else "silver"
			elif rank == 2:
				chest = "silver" if roll < 0.4 else "wood"
			elif rank == 3:
				chest = "wood"
		if chest != "":
			rewards["chest"] = chest
	var before: int = Catalog.league_index(trophies())
	var stats: Dictionary = data["stats"]
	stats["matches"] = int(stats.get("matches", 0)) + 1
	if rank == 1 and count > 1:
		stats["wins"] = int(stats.get("wins", 0)) + 1
	stats["holes_in_one"] = int(stats.get("holes_in_one", 0)) + int(summary.get("holes_in_one", 0))
	stats["best_style"] = maxi(int(stats.get("best_style", 0)), style)
	stats["shots"] = int(stats.get("shots", 0)) + int(summary.get("strokes", 0))
	stats["holes"] = int(stats.get("holes", 0)) + int(summary.get("holes", 0))
	grant(rewards)
	rewards["league_up"] = Catalog.league_index(trophies()) > before
	rewards["league"] = str(league()["name"])
	last_match_rewards = rewards
	return rewards
