class_name MenuPages
extends RefCounted
## Alle Seiten des Hauptmenues als modale Fenster ueber der 3D-Szene.
## open(page_id) baut eine Seite; refresh() baut die offene Seite neu auf (z.B. nach Kauf, Lobby-Update).
## Seiten: play, lobby, clubs, cosmetics, friends, leaderboard, shop, trophies, settings.

const PAGES := {
	"play": {"title": "Spielen", "size": Vector2(1060, 600)},
	"lobby": {"title": "Private Lobby", "size": Vector2(1060, 610)},
	"clubs": {"title": "Schlägertasche", "size": Vector2(1120, 620)},
	"cosmetics": {"title": "Bälle, Trails & Effekte", "size": Vector2(1100, 610)},
	"friends": {"title": "Freunde", "size": Vector2(1000, 610)},
	"leaderboard": {"title": "Rangliste", "size": Vector2(860, 610)},
	"shop": {"title": "Shop", "size": Vector2(1100, 610)},
	"trophies": {"title": "Trophäen & Ligen", "size": Vector2(1000, 610)},
	"settings": {"title": "Profil & Einstellungen", "size": Vector2(1060, 620)},
}
## Gem -> Coin Tauschangebote: [gems, coins]
const EXCHANGE: Array[Vector2i] = [Vector2i(10, 250), Vector2i(50, 1400), Vector2i(120, 3600)]
## Gem-Pakete (Demo ohne echte Zahlung): [gems, label]
const STAT_COLORS := {"power": Color(1.0, 0.45, 0.25), "accuracy": Color(0.3, 0.75, 1.0), "spin": Color(0.75, 0.45, 1.0), "guide": Color(0.35, 0.9, 0.5)}

## Auswahl im Spielen-Dialog (bleibt waehrend der Sitzung erhalten)
static var sel_world: String = "emerald"
static var sel_rounds: int = 3
static var sel_bots: int = 3

var menu: Node
var host: Control
var page: String = ""
var modal: Dictionary = {}

var _sel_club: String = ""
var _sel_kind: String = "ball"
var _search_results: Array = []
var _search_text: String = ""
var _busy: bool = false

func _init(p_menu: Node, p_host: Control) -> void:
	menu = p_menu
	host = p_host
	NetworkManager.lobby_updated.connect(_on_net_update.bind("lobby"))
	NetworkManager.lobby_left.connect(func(_reason: String) -> void: _on_net_update("lobby"))
	NetworkManager.friends_updated.connect(_on_net_update.bind("friends"))
	NetworkManager.invites_updated.connect(_on_net_update.bind("friends"))
	NetworkManager.leaderboard_updated.connect(_on_net_update.bind("leaderboard"))
	NetworkManager.auth_changed.connect(func() -> void:
		_on_net_update("settings")
		_on_net_update("friends"))
	GameManager.currency_changed.connect(_on_data_changed)
	GameManager.inventory_changed.connect(_on_data_changed)

# ================================================================ Verwaltung

func is_open() -> bool:
	return not modal.is_empty() and is_instance_valid(modal["root"])

## Irgendein modales Fenster offen (Seite, Belohnung, Rueckfrage)?
func any_modal_open() -> bool:
	for c in host.get_children():
		if c.has_meta("modal"):
			return true
	return false

func open(page_id: String) -> void:
	if not PAGES.has(page_id):
		return
	close()
	page = page_id
	var def: Dictionary = PAGES[page_id]
	modal = UIKit.modal(host, str(def["title"]), def["size"])
	var root: Control = modal["root"]
	root.set_meta("modal", "page")
	root.name = "Page_" + page_id
	root.tree_exited.connect(_on_modal_closed.bind(root))
	SoundManager.play("tab")
	match page_id:
		"friends":
			NetworkManager.refresh_friends()
			NetworkManager.refresh_invites()
		"leaderboard":
			NetworkManager.refresh_leaderboard()
	_build()

func close() -> void:
	if is_open():
		(modal["root"] as Control).queue_free()
	modal = {}
	page = ""

## Schliesst das oberste Fenster (Android-Zurueck-Taste). false, wenn keins offen war.
func close_top() -> bool:
	var children := host.get_children()
	for i in range(children.size() - 1, -1, -1):
		var c: Node = children[i]
		if c.has_meta("modal") and not c.is_queued_for_deletion():
			c.queue_free()
			return true
	return false

func _on_modal_closed(root: Control) -> void:
	if not modal.is_empty() and modal["root"] == root:
		modal = {}
		page = ""

func refresh() -> void:
	if not is_open():
		return
	var body: VBoxContainer = modal["body"]
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	_build()

func _on_net_update(which: String) -> void:
	if not is_instance_valid(host):
		return
	if page == which:
		refresh()

func _on_data_changed() -> void:
	if not is_instance_valid(host):
		return
	if page in ["clubs", "cosmetics", "shop", "trophies", "settings"] and not _busy:
		refresh()

## Einmal pro Sekunde vom Menue aufgerufen: Truhen-Dialog-Timer aktualisieren.
func tick() -> void:
	if not is_instance_valid(host):
		return
	for c in host.get_children():
		if c.has_meta("chest_slot") and not c.is_queued_for_deletion():
			var info: Label = c.get_meta("info_label")
			var slot: int = int(c.get_meta("chest_slot"))
			if is_instance_valid(info):
				if GameManager.chest_state(slot) == "ready":
					info.text = "Bereit!"
				else:
					info.text = ("Öffnet in " if GameManager.chest_state(slot) == "unlocking" else "Dauer: ") + UIKit.format_time(GameManager.chest_remaining(slot))

func _build() -> void:
	var body: VBoxContainer = modal["body"]
	match page:
		"play":
			_page_play(body)
		"lobby":
			_page_lobby(body)
		"clubs":
			_page_clubs(body)
		"cosmetics":
			_page_cosmetics(body)
		"friends":
			_page_friends(body)
		"leaderboard":
			_page_leaderboard(body)
		"shop":
			_page_shop(body)
		"trophies":
			_page_trophies(body)
		"settings":
			_page_settings(body)

func _toast(text: String, color: Color = UIKit.PANEL_LIGHT) -> void:
	UIKit.toast(host, text, color)

# ================================================================ Bausteine

## Reihe von Auswahl-Buttons; der aktive ist gold.
func _choice_row(options: Array, current: Variant, on_pick: Callable, min_size: Vector2 = Vector2(120, 56), font_size: int = 22) -> HBoxContainer:
	var row := UIKit.hbox(10)
	for opt in options:
		var value: Variant = opt[0]
		var b := UIKit.button(str(opt[1]), UIKit.GOLD.darkened(0.15) if value == current else UIKit.PANEL_LIGHT,
			func() -> void: on_pick.call(value), min_size, font_size)
		row.add_child(b)
	return row

func _section(parent: Control, text: String) -> void:
	parent.add_child(UIKit.label(text, 20, UIKit.TEXT_DIM))

func _price_text(p: Vector2i) -> String:
	if p.y > 0:
		return "%s Gems" % UIKit.format_number(p.y)
	if p.x > 0:
		return "%s Coins" % UIKit.format_number(p.x)
	return "Gratis"

func _row_panel(parent: Control, highlight: bool = false) -> HBoxContainer:
	var p := UIKit.panel(UIKit.PANEL_LIGHT if not highlight else Color(0.35, 0.3, 0.1, 0.95), 14,
		Color(1, 1, 1, 0.12) if not highlight else UIKit.GOLD, 2)
	parent.add_child(p)
	var h := UIKit.hbox(12)
	p.add_child(UIKit.margin(h, 10, 6, 10, 6))
	return h

func _offline_note(parent: Control, what: String) -> void:
	var t: String = "%s brauchen eine Internetverbindung und ein eingetragenes Supabase-Backend (config/backend.cfg, siehe README)." % what
	if NetworkManager.is_configured():
		t = "%s: Verbindung zum Server wird aufgebaut ... (%s)" % [what, NetworkManager.status]
	parent.add_child(UIKit.wrap_label(t, 21, UIKit.TEXT_DIM))

# ================================================================ Seite: Spielen

func _page_play(body: VBoxContainer) -> void:
	_section(body, "Welt (erste Bahn kommt aus dieser Welt, danach geht es auf Welttour)")
	var worlds := UIKit.hbox(12)
	body.add_child(worlds)
	for w in Catalog.WORLDS:
		var id: String = w["id"]
		var col: Color = w["color"]
		var b := UIKit.button("%s\n%d Bahnen" % [str(w["name"]), (w["courses"] as Array).size()],
			col.darkened(0.2) if id == sel_world else col.darkened(0.7), func() -> void:
				sel_world = id
				refresh(), Vector2(246, 92), 22)
		if id == sel_world:
			b.add_theme_stylebox_override("normal", UIKit.box(col.darkened(0.2), 16, Color.WHITE, 4))
		b.name = "World_" + id
		worlds.add_child(b)
	var desc: String = str(Catalog.world_by_id(sel_world).get("desc", ""))
	body.add_child(UIKit.label(desc, 19, UIKit.TEXT_DIM))
	var settings := UIKit.hbox(40)
	body.add_child(settings)
	var rv := UIKit.vbox(6)
	settings.add_child(rv)
	_section(rv, "Runden")
	var round_opts: Array = []
	for r in Catalog.ROUND_OPTIONS:
		round_opts.append([r, str(r)])
	rv.add_child(_choice_row(round_opts, sel_rounds, func(v: Variant) -> void:
		sel_rounds = int(v)
		refresh(), Vector2(90, 56)))
	var bv := UIKit.vbox(6)
	settings.add_child(bv)
	_section(bv, "Bots (Offline-Modus)")
	var bot_opts: Array = []
	for n in range(1, Catalog.MAX_PLAYERS):
		bot_opts.append([n, str(n)])
	bv.add_child(_choice_row(bot_opts, sel_bots, func(v: Variant) -> void:
		sel_bots = int(v)
		refresh(), Vector2(70, 56)))
	body.add_child(UIKit.spacer(true))
	var actions := UIKit.hbox(14)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(actions)
	var bots := UIKit.button("GEGEN BOTS", UIKit.GREEN, func() -> void:
		close()
		NetworkManager.start_bot_match(sel_world, sel_rounds, sel_bots), Vector2(300, 84), 28)
	bots.name = "StartBots"
	actions.add_child(bots)
	var online := UIKit.button("ONLINE-SCHNELLSPIEL", UIKit.BLUE, func() -> void:
		if not NetworkManager.is_online():
			_toast("Offline – du spielst gegen Bots.")
			close()
			NetworkManager.start_bot_match(sel_world, sel_rounds, sel_bots)
			return
		NetworkManager.quick_match(sel_world, sel_rounds)
		open("lobby"), Vector2(330, 84), 26)
	actions.add_child(online)
	actions.add_child(UIKit.button("PRIVATE LOBBY", UIKit.PURPLE, func() -> void: open("lobby"), Vector2(260, 84), 26))
	var hint: String = "Online: bis zu 6 Spieler gleichzeitig, freie Plätze werden mit Bots aufgefüllt." if NetworkManager.is_online() \
		else "Ohne Server-Verbindung spielst du gegen Bots – Fortschritt und Belohnungen zählen trotzdem."
	body.add_child(UIKit.label(hint, 18, UIKit.TEXT_DIM, true))

# ================================================================ Seite: Lobby

func _page_lobby(body: VBoxContainer) -> void:
	if not NetworkManager.is_online():
		_offline_note(body, "Private Lobbys")
		body.add_child(UIKit.spacer(true))
		body.add_child(UIKit.button("Stattdessen gegen Bots spielen", UIKit.GREEN, func() -> void:
			close()
			NetworkManager.start_bot_match(sel_world, sel_rounds, sel_bots), Vector2(420, 76), 24))
		return
	if not NetworkManager.in_lobby():
		_section(body, "Neue Lobby mit Raum-Code erstellen (Welt %s, %d Runden)" % [str(Catalog.world_by_id(sel_world)["name"]), sel_rounds])
		body.add_child(UIKit.button("LOBBY ERSTELLEN", UIKit.GREEN, func() -> void:
			NetworkManager.create_lobby(sel_world, sel_rounds, false), Vector2(360, 76), 26))
		_section(body, "Oder mit 4-stelligem Code beitreten")
		var row := UIKit.hbox(12)
		body.add_child(row)
		var edit := LineEdit.new()
		edit.name = "CodeEdit"
		edit.placeholder_text = "CODE"
		edit.max_length = 4
		edit.custom_minimum_size = Vector2(200, 70)
		edit.add_theme_font_size_override("font_size", 34)
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
		edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_DEFAULT
		edit.text_changed.connect(func(t: String) -> void:
			var up: String = t.to_upper()
			if up != t:
				var caret: int = edit.caret_column
				edit.text = up
				edit.caret_column = caret)
		row.add_child(edit)
		row.add_child(UIKit.button("BEITRETEN", UIKit.BLUE, func() -> void: NetworkManager.join_lobby(edit.text), Vector2(220, 70), 24))
		if not NetworkManager.invites.is_empty():
			_section(body, "Einladungen")
			for inv in NetworkManager.invites:
				var h := _row_panel(body)
				var l := UIKit.label("%s – Raum %s" % [str(inv["from_name"]), str(inv["code"])], 22)
				l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				h.add_child(l)
				var code: String = str(inv["code"])
				var inv_id: Variant = inv["id"]
				h.add_child(UIKit.button("Beitreten", UIKit.GREEN, func() -> void:
					NetworkManager.dismiss_invite(inv_id)
					NetworkManager.join_lobby(code), Vector2(150, 52), 20))
		return
	# --- in einer Lobby
	var lobby: Dictionary = NetworkManager.lobby
	var host_me: bool = NetworkManager.is_host()
	var head := UIKit.hbox(16)
	body.add_child(head)
	head.add_child(UIKit.label("Raum-Code:", 26, UIKit.TEXT_DIM))
	var code_label := UIKit.label(str(lobby["code"]), 46, UIKit.GOLD)
	code_label.name = "RoomCode"
	head.add_child(code_label)
	head.add_child(UIKit.spacer(true))
	head.add_child(UIKit.label("%d/%d Spieler" % [NetworkManager.roster.size(), Catalog.MAX_PLAYERS], 22))
	var cols := UIKit.hbox(18)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := UIKit.vbox(6)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	_section(left, "Spieler")
	var list := UIKit.scroll_list(left, 250)
	for p in NetworkManager.roster:
		var me: bool = str(p["id"]) == NetworkManager.local_id()
		var h := _row_panel(list, me)
		h.add_child(UIAvatar.new(str(p.get("name", "?")), int(p.get("color", 0)), str(p.get("frame", "bronze")), 44.0))
		var l := UIKit.label(str(p.get("name", "Spieler")) + (" (du)" if me else ""), 22)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		if str(p["id"]) == str(lobby.get("host_id", "")):
			h.add_child(UIKit.label("HOST", 18, UIKit.GOLD))
		h.add_child(UIIcon.new("trophy", 22.0))
		h.add_child(UIKit.label(str(int(p.get("trophies", 0))), 20, UIKit.GOLD))
	var right := UIKit.vbox(8)
	right.custom_minimum_size = Vector2(470, 0)
	cols.add_child(right)
	if host_me:
		_section(right, "Welt")
		var wopts: Array = []
		for w in Catalog.WORLDS:
			wopts.append([str(w["id"]), str(w["name"]).get_slice(" ", 0)])
		right.add_child(_choice_row(wopts, str(lobby.get("world", "emerald")), func(v: Variant) -> void:
			NetworkManager.set_lobby_settings(str(v), int(lobby.get("rounds", 3))), Vector2(108, 50), 18))
		_section(right, "Runden")
		var ropts: Array = []
		for r in Catalog.ROUND_OPTIONS:
			ropts.append([r, str(r)])
		right.add_child(_choice_row(ropts, int(lobby.get("rounds", 3)), func(v: Variant) -> void:
			NetworkManager.set_lobby_settings(str(lobby.get("world", "emerald")), int(v)), Vector2(90, 50), 20))
		var fill := CheckBox.new()
		fill.text = "Freie Plätze mit Bots auffüllen (bis 4)"
		fill.button_pressed = NetworkManager.fill_bots
		fill.focus_mode = Control.FOCUS_NONE
		fill.add_theme_font_size_override("font_size", 20)
		fill.toggled.connect(func(on: bool) -> void: NetworkManager.fill_bots = on)
		right.add_child(fill)
	else:
		right.add_child(UIKit.wrap_label("Welt: %s · %d Runden\nWarte, bis der Host das Match startet ..." % [
			str(Catalog.world_by_id(str(lobby.get("world", "emerald")))["name"]), int(lobby.get("rounds", 3))], 22, UIKit.TEXT))
	_section(right, "Freunde einladen")
	var flist := UIKit.scroll_list(right, 110)
	var any_friend := false
	for f in NetworkManager.friends:
		if str(f["state"]) != "accepted":
			continue
		any_friend = true
		var h := _row_panel(flist)
		var dot := UIKit.label("●", 18, UIKit.GREEN if bool(f["online"]) else UIKit.GREY)
		h.add_child(dot)
		var l := UIKit.label(str(f["name"]), 20)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		var fid: String = str(f["id"])
		h.add_child(UIKit.button("Einladen", UIKit.BLUE, func() -> void: _invite(fid), Vector2(130, 44), 18))
	if not any_friend:
		flist.add_child(UIKit.label("Noch keine Freunde – füge sie im Freunde-Tab hinzu.", 18, UIKit.TEXT_DIM))
	var actions := UIKit.hbox(14)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(actions)
	if host_me:
		actions.add_child(UIKit.button("MATCH STARTEN", UIKit.GREEN, func() -> void:
			close()
			NetworkManager.start_lobby_match(), Vector2(320, 74), 26))
	actions.add_child(UIKit.button("Lobby verlassen", UIKit.RED, func() -> void: NetworkManager.leave_lobby(), Vector2(240, 74), 22))

func _invite(friend_id: String) -> void:
	var r: Dictionary = await NetworkManager.invite_friend(friend_id)
	_toast(str(r["message"]), UIKit.GREEN.darkened(0.4) if bool(r["ok"]) else UIKit.RED.darkened(0.3))

# ================================================================ Seite: Schlaeger

func _page_clubs(body: VBoxContainer) -> void:
	if _sel_club == "" or not Catalog.CLUB_NAMES.has(_sel_club):
		_sel_club = GameManager.equipped_club()
	var cols := UIKit.hbox(16)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	# Links: Raster 4 Kategorien x 4 Seltenheiten
	var sc := ScrollContainer.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cols.add_child(sc)
	var grid_box := UIKit.vbox(8)
	grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(grid_box)
	for cat in Catalog.CATEGORIES:
		grid_box.add_child(UIKit.label(str(Catalog.CATEGORY_NAMES[cat]), 19, UIKit.TEXT_DIM))
		var row := UIKit.hbox(8)
		grid_box.add_child(row)
		for rar in Catalog.RARITIES:
			var id: String = "%s_%s" % [cat, rar]
			row.add_child(_club_card(id))
	# Rechts: Details
	var detail := UIKit.panel(UIKit.PANEL_LIGHT, 16, Catalog.RARITY_COLORS.get(Catalog.club_rarity(_sel_club), Color.WHITE), 3)
	detail.custom_minimum_size = Vector2(420, 0)
	cols.add_child(detail)
	var dv := UIKit.vbox(8)
	detail.add_child(UIKit.margin(dv, 14, 10, 14, 10))
	_club_detail(dv, _sel_club)

func _club_card(id: String) -> Button:
	var rar: String = Catalog.club_rarity(id)
	var col: Color = Catalog.RARITY_COLORS.get(rar, Color.WHITE)
	var owned: bool = GameManager.owns_club(id)
	var text: String = Catalog.club_name(id)
	if owned:
		text += "\nLv %d" % GameManager.club_level(id)
		if GameManager.can_upgrade_club(id):
			text += "  ▲"
	else:
		text += "\ngesperrt"
	var b := UIKit.button(text, col.darkened(0.45) if owned else Color(0.12, 0.13, 0.18), func() -> void:
		_sel_club = id
		refresh(), Vector2(150, 76), 17)
	b.name = "Club_" + id
	var border: Color = Color.WHITE if id == _sel_club else (UIKit.GREEN if id == GameManager.equipped_club() else col.darkened(0.2))
	b.add_theme_stylebox_override("normal", UIKit.box(col.darkened(0.45) if owned else Color(0.12, 0.13, 0.18), 14, border, 4 if id == _sel_club else 2))
	return b

func _club_detail(dv: VBoxContainer, id: String) -> void:
	var rar: String = Catalog.club_rarity(id)
	var cat: String = Catalog.club_category(id)
	var col: Color = Catalog.RARITY_COLORS.get(rar, Color.WHITE)
	dv.add_child(UIKit.label(Catalog.club_name(id), 30, col))
	dv.add_child(UIKit.label("%s · %s" % [str(Catalog.CATEGORY_NAMES[cat]), str(Catalog.RARITY_NAMES[rar])], 19, UIKit.TEXT_DIM))
	dv.add_child(UIKit.wrap_label(str(Catalog.CATEGORY_HINTS[cat]), 18, UIKit.TEXT_DIM))
	var owned: bool = GameManager.owns_club(id)
	var lvl: int = maxi(1, GameManager.club_level(id))
	var maxed: bool = GameManager.club_is_max(id)
	var stats: Dictionary = Catalog.club_stats(id, lvl)
	var next: Dictionary = Catalog.club_stats(id, mini(lvl + 1, Catalog.club_max_level(id)))
	dv.add_child(UIKit.label("Stufe %d / %d" % [lvl, Catalog.club_max_level(id)], 22, UIKit.TEXT))
	for k in Catalog.STAT_KEYS:
		var row := UIKit.hbox(8)
		dv.add_child(row)
		var name_l := UIKit.label(str(Catalog.STAT_NAMES[k]), 19)
		name_l.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_l)
		var bar := UIKit.bar(float(stats[k]) / 100.0, STAT_COLORS[k], Vector2(190, 18))
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var gain: float = float(next[k]) - float(stats[k])
		var vt: String = str(int(stats[k]))
		if owned and not maxed and gain > 0.0:
			vt += "  +%d" % int(gain)
		row.add_child(UIKit.label(vt, 19, UIKit.GREEN if owned and not maxed and gain > 0.0 else UIKit.TEXT))
	if not owned:
		dv.add_child(UIKit.wrap_label("Noch nicht freigeschaltet. Die erste Karte aus einer Truhe schaltet diesen Schläger frei.", 18, UIKit.TEXT_DIM))
		return
	if maxed:
		dv.add_child(UIKit.label("Maximale Stufe erreicht!", 22, UIKit.GOLD))
	else:
		var need: int = Catalog.upgrade_card_cost(id, lvl)
		var have: int = GameManager.club_cards(id)
		var ch := UIKit.hbox(8)
		dv.add_child(ch)
		ch.add_child(UIIcon.new("cards", 24.0))
		var cb := UIKit.bar(float(have) / float(need), UIKit.BLUE, Vector2(220, 20))
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(cb)
		ch.add_child(UIKit.label("%d/%d" % [have, need], 19))
		var cost: int = Catalog.upgrade_coin_cost(id, lvl)
		var up := UIKit.button("UPGRADE  %s Coins" % UIKit.format_number(cost), UIKit.GREEN, func() -> void:
			if GameManager.upgrade_club(id):
				SoundManager.play("upgrade")
				_toast("%s ist jetzt Stufe %d!" % [Catalog.club_name(id), GameManager.club_level(id)], UIKit.GREEN.darkened(0.4))
			else:
				SoundManager.play("error"), Vector2(380, 60), 22)
		up.name = "UpgradeButton"
		up.disabled = not GameManager.can_upgrade_club(id)
		dv.add_child(up)
	if id == GameManager.equipped_club():
		dv.add_child(UIKit.label("Ausgerüstet", 22, UIKit.GREEN))
	else:
		dv.add_child(UIKit.button("AUSRÜSTEN", UIKit.BLUE, func() -> void:
			GameManager.equip_club(id)
			SoundManager.play("pop"), Vector2(380, 60), 22))

# ================================================================ Seite: Baelle, Trails, Explosionen, Rahmen

func _page_cosmetics(body: VBoxContainer) -> void:
	var kinds: Array = [["ball", "Bälle"], ["trail", "Trails"], ["explosion", "Loch-Explosionen"], ["frame", "Avatar-Rahmen"]]
	body.add_child(_choice_row(kinds, _sel_kind, func(v: Variant) -> void:
		_sel_kind = str(v)
		refresh(), Vector2(230, 56), 21))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	sc.add_child(grid)
	var table: Dictionary = Catalog.item_table(_sel_kind)
	for id in Catalog.item_order(_sel_kind):
		grid.add_child(_item_card(_sel_kind, id, table[id]))

func _item_card(kind: String, id: String, def: Dictionary) -> PanelContainer:
	var owned: bool = GameManager.owns(kind, id)
	var equipped: bool = (GameManager.avatar_frame() == id) if kind == "frame" else (GameManager.equipped(kind) == id)
	var p := UIKit.panel(UIKit.PANEL_LIGHT, 16, UIKit.GREEN if equipped else Color(1, 1, 1, 0.12), 3 if equipped else 2)
	p.custom_minimum_size = Vector2(336, 150)
	p.name = "Item_%s_%s" % [kind, id]
	var v := UIKit.vbox(6)
	p.add_child(UIKit.margin(v, 12, 8, 12, 8))
	var head := UIKit.hbox(10)
	v.add_child(head)
	if kind == "frame":
		head.add_child(UIAvatar.new(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), id, 48.0))
	elif kind == "ball":
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(12, 48)
		sw.color = _ball_swatch(id)
		head.add_child(sw)
	var tl := UIKit.label(str(def["name"]), 23, UIKit.TEXT)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var info: String = str(def.get("desc", ""))
	if kind == "frame" and str(def.get("league", "")) != "":
		info = "Liga-Belohnung: %s" % str(Catalog.league_for(_league_min(str(def["league"])))["name"])
	if info != "":
		v.add_child(UIKit.label(info, 17, UIKit.TEXT_DIM))
	v.add_child(UIKit.spacer(true))
	var actions := UIKit.hbox(8)
	v.add_child(actions)
	if equipped:
		actions.add_child(UIKit.label("Ausgerüstet", 21, UIKit.GREEN))
	elif owned:
		actions.add_child(UIKit.button("Ausrüsten", UIKit.BLUE, func() -> void:
			GameManager.equip(kind, id)
			SoundManager.play("pop"), Vector2(170, 50), 20))
	elif GameManager.item_buyable(kind, id):
		var price: Vector2i = GameManager.item_price(kind, id)
		var buy := UIKit.button(_price_text(price), UIKit.PURPLE if price.y > 0 else UIKit.GOLD.darkened(0.2), func() -> void:
			if GameManager.buy_item(kind, id):
				SoundManager.play("coin")
				GameManager.equip(kind, id)
				_toast("„%s“ gekauft!" % str(def["name"]), UIKit.GREEN.darkened(0.4))
			else:
				SoundManager.play("error")
				_toast("Nicht genug %s." % ("Gems" if price.y > 0 else "Coins"), UIKit.RED.darkened(0.3)), Vector2(190, 50), 20)
		buy.disabled = not GameManager.can_afford(price.x, price.y)
		actions.add_child(buy)
	else:
		actions.add_child(UIKit.label("Gesperrt", 20, UIKit.TEXT_DIM))
	if kind == "explosion":
		actions.add_child(UIKit.button("Vorschau", UIKit.GREY, func() -> void: _preview_explosion(id), Vector2(130, 50), 18))
	return p

func _league_min(league_id: String) -> int:
	for l in Catalog.LEAGUES:
		if str(l["id"]) == league_id:
			return int(l["min"])
	return 0

func _ball_swatch(id: String) -> Color:
	match id:
		"magma":
			return Color(1.0, 0.4, 0.1)
		"holo":
			return Color(0.3, 0.9, 1.0)
		"gold":
			return Color(1.0, 0.8, 0.2)
		"lightning":
			return Color(0.45, 0.6, 1.0)
		"soccer":
			return Color(0.95, 0.95, 0.95)
	return GameManager.avatar_color()

## Spielt die Loch-Explosion vor der Vitrine ab (das Fenster wird dafuer kurz ausgeblendet).
func _preview_explosion(id: String) -> void:
	if not is_open():
		return
	var root: Control = modal["root"]
	root.visible = false
	var cam: Camera3D = menu.get("camera")
	var pos: Vector3 = cam.global_transform * Vector3(0.6, -1.2, -7.0)
	var shake: float = BallFX.hole_explosion(menu as Node3D, id, pos)
	SoundManager.play("holed")
	SoundManager.play("bass", clampf(shake, 0.3, 1.0))
	await menu.get_tree().create_timer(2.6).timeout
	if is_instance_valid(root):
		root.visible = true

# ================================================================ Seite: Freunde

func _page_friends(body: VBoxContainer) -> void:
	if not NetworkManager.is_online():
		_offline_note(body, "Freunde")
		return
	var head := UIKit.hbox(12)
	body.add_child(head)
	head.add_child(UIKit.label("Dein Freundes-Code:", 21, UIKit.TEXT_DIM))
	var code := UIKit.label(NetworkManager.friend_code if NetworkManager.friend_code != "" else "...", 30, UIKit.GOLD)
	code.name = "FriendCode"
	head.add_child(code)
	head.add_child(UIKit.spacer(true))
	head.add_child(UIKit.icon_button("plus", UIKit.GREY, func() -> void:
		NetworkManager.refresh_friends()
		NetworkManager.refresh_invites(), 48.0))
	var search := UIKit.hbox(10)
	body.add_child(search)
	var edit := LineEdit.new()
	edit.placeholder_text = "Name oder Freundes-Code suchen"
	edit.text = _search_text
	edit.custom_minimum_size = Vector2(520, 56)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 22)
	search.add_child(edit)
	search.add_child(UIKit.button("Suchen", UIKit.BLUE, func() -> void: _search(edit.text), Vector2(160, 56), 22))
	edit.text_submitted.connect(func(t: String) -> void: _search(t))
	var list := UIKit.scroll_list(body, 330)
	if not _search_results.is_empty():
		list.add_child(UIKit.label("Suchergebnisse", 19, UIKit.TEXT_DIM))
		for p in _search_results:
			var h := _row_panel(list)
			h.add_child(UIAvatar.new(str(p["name"]), int(p["color"]), str(p["frame"]), 44.0))
			var l := UIKit.label("%s  #%s" % [str(p["name"]), str(p["code"])], 21)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
			h.add_child(UIKit.label(str(int(p["trophies"])), 19, UIKit.GOLD))
			var pid: String = str(p["id"])
			h.add_child(UIKit.button("Hinzufügen", UIKit.GREEN, func() -> void: _add_friend(pid), Vector2(160, 46), 19))
	var incoming: Array = []
	var accepted: Array = []
	var outgoing: Array = []
	for f in NetworkManager.friends:
		match str(f["state"]):
			"incoming":
				incoming.append(f)
			"outgoing":
				outgoing.append(f)
			_:
				accepted.append(f)
	if not incoming.is_empty():
		list.add_child(UIKit.label("Anfragen", 19, UIKit.TEXT_DIM))
		for f in incoming:
			var h := _row_panel(list, true)
			h.add_child(UIAvatar.new(str(f["name"]), int(f["color"]), str(f["frame"]), 44.0))
			var l := UIKit.label(str(f["name"]) + " möchte dein Freund sein", 21)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
			var rid: Variant = f["row_id"]
			h.add_child(UIKit.button("Annehmen", UIKit.GREEN, func() -> void: NetworkManager.accept_friend(rid), Vector2(150, 46), 19))
			h.add_child(UIKit.icon_button("close", UIKit.RED, func() -> void: NetworkManager.remove_friend(rid), 46.0))
	list.add_child(UIKit.label("Freunde (%d)" % accepted.size(), 19, UIKit.TEXT_DIM))
	if accepted.is_empty():
		list.add_child(UIKit.wrap_label("Noch keine Freunde. Suche nach Namen oder teile deinen Freundes-Code!", 19, UIKit.TEXT_DIM))
	for f in accepted:
		var h := _row_panel(list)
		h.add_child(UIAvatar.new(str(f["name"]), int(f["color"]), str(f["frame"]), 44.0))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(UIKit.label(str(f["name"]), 21))
		v.add_child(UIKit.label("online" if bool(f["online"]) else "offline", 16, UIKit.GREEN if bool(f["online"]) else UIKit.TEXT_DIM))
		h.add_child(UIIcon.new("trophy", 22.0))
		h.add_child(UIKit.label(str(int(f["trophies"])), 19, UIKit.GOLD))
		var fid: String = str(f["id"])
		var rid2: Variant = f["row_id"]
		if NetworkManager.in_lobby():
			h.add_child(UIKit.button("Einladen", UIKit.BLUE, func() -> void: _invite(fid), Vector2(130, 46), 18))
		h.add_child(UIKit.icon_button("close", UIKit.GREY, func() -> void: _confirm("Freund entfernen?", "%s wirklich entfernen?" % str(f["name"]),
			func() -> void: NetworkManager.remove_friend(rid2)), 46.0))
	if not outgoing.is_empty():
		list.add_child(UIKit.label("Gesendete Anfragen", 19, UIKit.TEXT_DIM))
		for f in outgoing:
			var h := _row_panel(list)
			var l := UIKit.label(str(f["name"]) + " (wartet)", 20, UIKit.TEXT_DIM)
			l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(l)
			var rid3: Variant = f["row_id"]
			h.add_child(UIKit.button("Zurückziehen", UIKit.GREY, func() -> void: NetworkManager.remove_friend(rid3), Vector2(170, 44), 18))

func _search(text: String) -> void:
	_search_text = text
	if text.strip_edges().length() < 2:
		_toast("Mindestens 2 Zeichen eingeben.")
		return
	_search_results = await NetworkManager.search_players(text)
	if _search_results.is_empty():
		_toast("Niemand gefunden.")
	if page == "friends":
		refresh()

func _add_friend(pid: String) -> void:
	var r: Dictionary = await NetworkManager.send_friend_request(pid)
	_toast(str(r["message"]), UIKit.GREEN.darkened(0.4) if bool(r["ok"]) else UIKit.RED.darkened(0.3))
	_search_results = _search_results.filter(func(p: Dictionary) -> bool: return str(p["id"]) != pid)
	if page == "friends":
		refresh()

# ================================================================ Seite: Rangliste

func _page_leaderboard(body: VBoxContainer) -> void:
	var info: String = "Weltweite Rangliste nach Trophäen" if NetworkManager.is_online() else "Offline-Rangliste (verbinde ein Backend für die echte Weltrangliste)"
	body.add_child(UIKit.label(info, 19, UIKit.TEXT_DIM))
	var list := UIKit.scroll_list(body, 460)
	if NetworkManager.leaderboard.is_empty():
		list.add_child(UIKit.label("Lade ...", 22, UIKit.TEXT_DIM))
		return
	var rank := 0
	for row in NetworkManager.leaderboard:
		rank += 1
		var me: bool = bool(row.get("me", false))
		var h := _row_panel(list, me)
		var rl := UIKit.label("%d." % rank, 24, UIKit.GOLD if rank <= 3 else UIKit.TEXT)
		rl.custom_minimum_size = Vector2(56, 0)
		h.add_child(rl)
		h.add_child(UIAvatar.new(str(row["name"]), int(row.get("color", 0)), str(row.get("frame", "bronze")), 44.0))
		var nl := UIKit.label(str(row["name"]) + ("  (du)" if me else ""), 22)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nl)
		var lg: Dictionary = Catalog.league_for(int(row["trophies"]))
		h.add_child(UIKit.label(str(lg["name"]), 19, lg["color"]))
		h.add_child(UIIcon.new("trophy", 24.0))
		var tl := UIKit.label(UIKit.format_number(int(row["trophies"])), 22, UIKit.GOLD)
		tl.custom_minimum_size = Vector2(80, 0)
		h.add_child(tl)

# ================================================================ Seite: Shop

func _page_shop(body: VBoxContainer) -> void:
	var top := UIKit.hbox(14)
	body.add_child(top)
	# Tagesgeschenk
	var gift := UIKit.panel(Color(0.12, 0.35, 0.2, 0.95), 16, UIKit.GREEN, 2)
	gift.custom_minimum_size = Vector2(330, 150)
	top.add_child(gift)
	var gv := UIKit.vbox(6)
	gift.add_child(UIKit.margin(gv, 12, 8, 12, 8))
	var gh := UIKit.hbox(8)
	gv.add_child(gh)
	gh.add_child(UIIcon.new("gift", 40.0))
	gh.add_child(UIKit.label("Tagesgeschenk", 24))
	if GameManager.gift_available():
		gv.add_child(UIKit.button("ABHOLEN", UIKit.GREEN, func() -> void:
			var r: Dictionary = GameManager.claim_gift()
			if not r.is_empty():
				show_rewards("Tagesgeschenk", r), Vector2(300, 60), 24))
	else:
		gv.add_child(UIKit.label("Morgen gibt es ein neues Geschenk!", 18, UIKit.TEXT_DIM))
	# Gem -> Coin Tausch
	var ex := UIKit.panel(UIKit.PANEL_LIGHT, 16, UIKit.GOLD, 2)
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(ex)
	var ev := UIKit.vbox(6)
	ex.add_child(UIKit.margin(ev, 12, 8, 12, 8))
	ev.add_child(UIKit.label("Gems in Coins tauschen", 22, UIKit.GOLD))
	var er := UIKit.hbox(10)
	ev.add_child(er)
	for offer in EXCHANGE:
		var g: int = offer.x
		var c: int = offer.y
		var b := UIKit.button("%s Coins\nfür %d Gems" % [UIKit.format_number(c), g], UIKit.PURPLE, func() -> void:
			if GameManager.exchange_gems(g, c):
				SoundManager.play("coin")
				_toast("+%s Coins" % UIKit.format_number(c), UIKit.GREEN.darkened(0.4))
			else:
				SoundManager.play("error")
				_toast("Nicht genug Gems.", UIKit.RED.darkened(0.3)), Vector2(190, 86), 19)
		b.disabled = GameManager.gems() < g
		er.add_child(b)
	# Truhen
	body.add_child(UIKit.label("Truhen (sofort öffnen)", 22, UIKit.TEXT_DIM))
	var chests := UIKit.hbox(12)
	body.add_child(chests)
	for type in Catalog.CHEST_ORDER:
		var def: Dictionary = Catalog.CHESTS[type]
		var col: Color = def["color"]
		var p := UIKit.panel(col.darkened(0.6), 16, col, 3)
		p.custom_minimum_size = Vector2(250, 220)
		chests.add_child(p)
		var v := UIKit.vbox(6)
		p.add_child(UIKit.margin(v, 10, 8, 10, 8))
		var icon := UIIcon.new("chest", 64.0, col.lightened(0.2))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		v.add_child(UIKit.label(str(def["name"]), 21, UIKit.TEXT, true))
		var coins_range: Array = def["coins"]
		v.add_child(UIKit.label("%d-%d Coins · %d Karten" % [int(coins_range[0]), int(coins_range[1]), int(def["cards"])], 16, UIKit.TEXT_DIM, true))
		var t: String = type
		var price: int = int(def["gem_price"])
		var buy := UIKit.button("%d Gems" % price, UIKit.PURPLE, func() -> void:
			_busy = true
			var r: Dictionary = GameManager.buy_chest(t)
			_busy = false
			if not r.is_empty():
				show_rewards(str(Catalog.CHESTS[t]["name"]), r)
				refresh(), Vector2(220, 54), 21)
		buy.disabled = GameManager.gems() < price
		v.add_child(buy)
	body.add_child(UIKit.label("Hinweis: Gems verdienst du in Truhen, im Trophäen-Pfad, beim Golden Shot und mit dem Tagesgeschenk. Es gibt keine Echtgeld-Käufe.", 16, UIKit.TEXT_DIM))

# ================================================================ Seite: Trophaeen & Ligen

func _page_trophies(body: VBoxContainer) -> void:
	var t: int = GameManager.trophies()
	var lg: Dictionary = GameManager.league()
	var li: int = Catalog.league_index(t)
	var head := UIKit.hbox(14)
	body.add_child(head)
	head.add_child(UIIcon.new("trophy", 56.0))
	var hv := UIKit.vbox(2)
	head.add_child(hv)
	hv.add_child(UIKit.label("%s Trophäen" % UIKit.format_number(t), 30, UIKit.GOLD))
	hv.add_child(UIKit.label("Liga: %s" % str(lg["name"]), 22, lg["color"]))
	head.add_child(UIKit.spacer(true))
	var nv := UIKit.vbox(4)
	head.add_child(nv)
	if li < Catalog.LEAGUES.size() - 1:
		var nxt: Dictionary = Catalog.LEAGUES[li + 1]
		var lo: int = int(lg["min"])
		var hi: int = int(nxt["min"])
		nv.add_child(UIKit.label("Nächste Liga: %s (%d)" % [str(nxt["name"]), hi], 19, nxt["color"]))
		nv.add_child(UIKit.bar(float(t - lo) / float(maxi(1, hi - lo)), nxt["color"], Vector2(320, 22)))
	else:
		nv.add_child(UIKit.label("Höchste Liga erreicht!", 21, UIKit.GOLD))
	var leagues := UIKit.hbox(8)
	body.add_child(leagues)
	for i in Catalog.LEAGUES.size():
		var l: Dictionary = Catalog.LEAGUES[i]
		var p := UIKit.panel((l["color"] as Color).darkened(0.65 if i != li else 0.3), 12, l["color"], 3 if i == li else 1)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_child(UIKit.label("%s\nab %d" % [str(l["name"]), int(l["min"])], 18, UIKit.TEXT, true))
		leagues.add_child(p)
	body.add_child(UIKit.label("Trophäen-Pfad (Belohnungen nach Rekord-Trophäen)", 19, UIKit.TEXT_DIM))
	var list := UIKit.scroll_list(body, 250)
	var best: int = int(GameManager.data.get("best_trophies", 0))
	for i in Catalog.TROPHY_ROAD.size():
		var e: Dictionary = Catalog.TROPHY_ROAD[i]
		var reached: bool = best >= int(e["at"])
		var claimed: bool = GameManager.road_claimed(i)
		var h := _row_panel(list, reached and not claimed)
		var al := UIKit.label(str(int(e["at"])), 22, UIKit.GOLD if reached else UIKit.TEXT_DIM)
		al.custom_minimum_size = Vector2(70, 0)
		h.add_child(UIIcon.new("trophy", 22.0, Color.WHITE if reached else Color(1, 1, 1, 0.35)))
		h.add_child(al)
		var parts := PackedStringArray()
		if e.has("coins"):
			parts.append("%s Coins" % UIKit.format_number(int(e["coins"])))
		if e.has("gems"):
			parts.append("%d Gems" % int(e["gems"]))
		if e.has("chest"):
			parts.append(str(Catalog.CHESTS[str(e["chest"])]["name"]))
		if e.has("frame"):
			parts.append("Rahmen „%s“" % str(Catalog.FRAMES[str(e["frame"])]["name"]))
		if e.has("item"):
			var it: Array = e["item"]
			parts.append("%s „%s“" % [Catalog.kind_name(str(it[0])), Catalog.item_name(str(it[0]), str(it[1]))])
		var rl := UIKit.label(" + ".join(parts), 20, UIKit.TEXT if reached else UIKit.TEXT_DIM)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(rl)
		if claimed:
			h.add_child(UIIcon.new("check", 30.0, UIKit.GREEN))
		elif reached:
			var idx: int = i
			h.add_child(UIKit.button("Abholen", UIKit.GREEN, func() -> void:
				var r: Dictionary = GameManager.claim_road(idx)
				if not r.is_empty():
					show_rewards("Trophäen-Pfad", r), Vector2(140, 46), 19))
		else:
			h.add_child(UIIcon.new("lock", 28.0, Color(1, 1, 1, 0.4)))
	var st: Dictionary = GameManager.data["stats"]
	body.add_child(UIKit.label("Matches %d · Siege %d · Hole-in-One %d · Bester Style %d" % [int(st.get("matches", 0)), int(st.get("wins", 0)),
		int(st.get("holes_in_one", 0)), int(st.get("best_style", 0))], 18, UIKit.TEXT_DIM))

# ================================================================ Seite: Profil & Einstellungen

func _page_settings(body: VBoxContainer) -> void:
	var cols := UIKit.hbox(24)
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(cols)
	var left := UIKit.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := UIKit.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	# --- Profil
	_section(left, "Spielername (3-16 Zeichen)")
	var nr := UIKit.hbox(8)
	left.add_child(nr)
	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.text = GameManager.player_name()
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(300, 54)
	name_edit.add_theme_font_size_override("font_size", 22)
	nr.add_child(name_edit)
	nr.add_child(UIKit.button("Speichern", UIKit.GREEN, func() -> void:
		if GameManager.set_player_name(name_edit.text):
			_toast("Name gespeichert.", UIKit.GREEN.darkened(0.4))
		else:
			_toast("Der Name braucht 3 bis 16 Zeichen.", UIKit.RED.darkened(0.3)), Vector2(150, 54), 20))
	_section(left, "Avatar-Farbe")
	var colors := UIKit.hbox(6)
	left.add_child(colors)
	for i in Catalog.AVATAR_COLORS.size():
		var idx: int = i
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(46, 46)
		var sel: bool = int(GameManager.data.get("avatar_color", 0)) == i
		b.add_theme_stylebox_override("normal", UIKit.box(Catalog.AVATAR_COLORS[i], 23, Color.WHITE if sel else Color(0, 0, 0, 0.4), 4 if sel else 2))
		b.add_theme_stylebox_override("hover", UIKit.box(Catalog.AVATAR_COLORS[i].lightened(0.1), 23, Color.WHITE, 2))
		b.add_theme_stylebox_override("pressed", UIKit.box(Catalog.AVATAR_COLORS[i].darkened(0.1), 23, Color.WHITE, 4))
		b.pressed.connect(func() -> void:
			SoundManager.play("click")
			GameManager.set_avatar_color(idx)
			refresh())
		colors.add_child(b)
	_section(left, "Avatar-Rahmen")
	var frames := HFlowContainer.new()
	frames.add_theme_constant_override("h_separation", 6)
	frames.add_theme_constant_override("v_separation", 6)
	left.add_child(frames)
	for fid in Catalog.FRAME_ORDER:
		var owned: bool = GameManager.owns("frame", fid)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(60, 60)
		var sel: bool = GameManager.avatar_frame() == fid
		b.add_theme_stylebox_override("normal", UIKit.box(UIKit.PANEL_LIGHT, 12, UIKit.GREEN if sel else Color(1, 1, 1, 0.1), 3 if sel else 1))
		b.add_theme_stylebox_override("pressed", UIKit.box(UIKit.PANEL, 12, UIKit.GREEN, 3))
		b.add_theme_stylebox_override("hover", UIKit.box(UIKit.PANEL_LIGHT, 12, Color.WHITE, 1))
		var av := UIAvatar.new(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), fid, 48.0)
		av.position = Vector2(6, 6)
		av.size = Vector2(48, 48)
		av.modulate.a = 1.0 if owned else 0.3
		b.add_child(av)
		var f: String = fid
		b.pressed.connect(func() -> void:
			if GameManager.set_avatar_frame(f):
				SoundManager.play("pop")
				refresh()
			else:
				SoundManager.play("error")
				_toast("Rahmen „%s“ ist noch gesperrt." % str(Catalog.FRAMES[f]["name"])))
		frames.add_child(b)
	# --- Einstellungen
	_section(left, "Soundeffekte")
	left.add_child(_slider(float(GameManager.setting("sfx", 0.8)), 0.0, 1.0, func(v: float) -> void: GameManager.set_setting("sfx", v)))
	_section(left, "Kamera-Empfindlichkeit")
	left.add_child(_slider(float(GameManager.setting("camera_sens", 1.0)), 0.4, 2.0, func(v: float) -> void: GameManager.set_setting("camera_sens", v)))
	var vib := CheckBox.new()
	vib.text = "Vibration"
	vib.focus_mode = Control.FOCUS_NONE
	vib.add_theme_font_size_override("font_size", 21)
	vib.button_pressed = bool(GameManager.setting("vibration", true))
	vib.toggled.connect(func(on: bool) -> void:
		_busy = true
		GameManager.set_setting("vibration", on)
		_busy = false)
	left.add_child(vib)
	# --- Account
	right.add_child(UIKit.label("Account", 24, UIKit.GOLD))
	if not NetworkManager.is_configured():
		right.add_child(UIKit.wrap_label("Kein Backend eingetragen – du spielst im Offline-Modus. Trage Supabase-URL und Anon-Key in config/backend.cfg ein (siehe README), um Freunde, Online-Matches und Cloud-Speicherstand zu nutzen.", 19, UIKit.TEXT_DIM))
	else:
		var acc: String = "Status: %s" % NetworkManager.status
		if NetworkManager.is_online():
			acc += "\n" + ("Gast-Account (nur auf diesem Gerät)" if NetworkManager.is_anonymous else "Verknüpft mit " + NetworkManager.email)
		right.add_child(UIKit.wrap_label(acc, 19, UIKit.TEXT))
		var mail := LineEdit.new()
		mail.name = "MailEdit"
		mail.placeholder_text = "E-Mail"
		mail.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		mail.custom_minimum_size = Vector2(0, 50)
		mail.add_theme_font_size_override("font_size", 20)
		right.add_child(mail)
		var pw := LineEdit.new()
		pw.name = "PasswordEdit"
		pw.placeholder_text = "Passwort (mind. 6 Zeichen)"
		pw.secret = true
		pw.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
		pw.custom_minimum_size = Vector2(0, 50)
		pw.add_theme_font_size_override("font_size", 20)
		right.add_child(pw)
		var ar := UIKit.hbox(8)
		right.add_child(ar)
		if NetworkManager.is_online() and NetworkManager.is_anonymous:
			ar.add_child(UIKit.button("Gast verknüpfen", UIKit.GREEN, func() -> void: _account_action("link", mail.text, pw.text), Vector2(220, 54), 19))
		ar.add_child(UIKit.button("Anmelden", UIKit.BLUE, func() -> void: _account_action("login", mail.text, pw.text), Vector2(160, 54), 19))
		if NetworkManager.is_online():
			right.add_child(UIKit.button("Abmelden", UIKit.GREY, func() -> void:
				_confirm("Abmelden?", "Du spielst danach als neuer Gast weiter. Dein Account bleibt auf dem Server erhalten.", func() -> void:
					NetworkManager.sign_out()
					NetworkManager.auto_login()), Vector2(180, 50), 19))
	right.add_child(UIKit.spacer(true))
	right.add_child(UIKit.label("Geräte-ID: " + GameManager.device_id().substr(0, 8), 16, UIKit.TEXT_DIM))
	right.add_child(UIKit.button("Fortschritt zurücksetzen", UIKit.RED.darkened(0.2), func() -> void:
		_confirm("Wirklich zurücksetzen?", "Alle Coins, Gems, Schläger und Trophäen auf diesem Gerät werden gelöscht.", func() -> void:
			GameManager.reset_progress()
			menu.call("refresh_showcase")
			refresh()), Vector2(300, 50), 19))

func _slider(value: float, lo: float, hi: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(360, 40)
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void:
		_busy = true
		on_change.call(v)
		_busy = false)
	return s

func _account_action(action: String, mail: String, password: String) -> void:
	if not mail.contains("@") or password.length() < 6:
		_toast("Bitte gültige E-Mail und ein Passwort mit mind. 6 Zeichen eingeben.", UIKit.RED.darkened(0.3))
		return
	var r: Dictionary
	if action == "link":
		r = await NetworkManager.link_email(mail, password)
	else:
		r = await NetworkManager.sign_in_email(mail, password)
	_toast(str(r["message"]), UIKit.GREEN.darkened(0.4) if bool(r["ok"]) else UIKit.RED.darkened(0.3))
	if page == "settings":
		refresh()

# ================================================================ Dialoge: Rueckfrage, Truhe, Belohnungen, Beenden

func _confirm(title: String, text: String, on_yes: Callable) -> void:
	var m: Dictionary = UIKit.modal(host, title, Vector2(620, 300))
	var root: Control = m["root"]
	root.set_meta("modal", "confirm")
	var body: VBoxContainer = m["body"]
	body.add_child(UIKit.wrap_label(text, 22, UIKit.TEXT, true))
	body.add_child(UIKit.spacer(true))
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	row.add_child(UIKit.button("Abbrechen", UIKit.GREY, root.queue_free, Vector2(200, 62), 22))
	row.add_child(UIKit.button("Ja", UIKit.RED, func() -> void:
		root.queue_free()
		on_yes.call(), Vector2(200, 62), 22))

func confirm_quit() -> void:
	_confirm("Spiel beenden?", "Bis bald auf dem Grün!", func() -> void:
		GameManager.save_game()
		menu.get_tree().quit())

## Dialog fuer eine noch verschlossene Truhe: Timer starten oder mit Gems sofort oeffnen.
func open_chest_dialog(slot: int) -> void:
	var c: Dictionary = GameManager.chest_slot(slot)
	if c.is_empty():
		return
	var def: Dictionary = Catalog.CHESTS[str(c["type"])]
	var col: Color = def["color"]
	var m: Dictionary = UIKit.modal(host, str(def["name"]), Vector2(640, 420))
	var root: Control = m["root"]
	root.set_meta("modal", "chest")
	var body: VBoxContainer = m["body"]
	var icon := UIIcon.new("chest", 96.0, col.lightened(0.2))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(icon)
	var coins_range: Array = def["coins"]
	body.add_child(UIKit.label("%d-%d Coins · %d Schläger-Karten" % [int(coins_range[0]), int(coins_range[1]), int(def["cards"])], 21, UIKit.TEXT_DIM, true))
	var state: String = GameManager.chest_state(slot)
	var remaining: float = GameManager.chest_remaining(slot)
	var info := UIKit.label("", 26, UIKit.GOLD, true)
	body.add_child(info)
	info.text = ("Öffnet in " if state == "unlocking" else "Dauer: ") + UIKit.format_time(remaining)
	root.set_meta("chest_slot", slot)
	root.set_meta("info_label", info)
	body.add_child(UIKit.spacer(true))
	var row := UIKit.hbox(14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(row)
	if state == "locked":
		var other: int = GameManager.unlocking_slot()
		var start := UIKit.button("Timer starten", UIKit.GREEN, func() -> void:
			if GameManager.start_unlock(slot):
				SoundManager.play("beep")
			root.queue_free(), Vector2(230, 66), 22)
		start.disabled = other >= 0
		row.add_child(start)
		if other >= 0:
			body.add_child(UIKit.label("Es läuft schon ein Truhen-Timer.", 18, UIKit.TEXT_DIM, true))
	var cost: int = GameManager.chest_gem_cost(slot)
	var instant := UIKit.button("Sofort: %d Gems" % cost, UIKit.PURPLE, func() -> void:
		var r: Dictionary = GameManager.open_chest(slot, true)
		root.queue_free()
		if not r.is_empty():
			show_rewards(str(def["name"]), r), Vector2(250, 66), 22)
	instant.disabled = GameManager.gems() < cost
	row.add_child(instant)

## Belohnungs-Fenster mit Truhen-Animation und nacheinander aufploppenden Zeilen.
func show_rewards(title: String, rewards: Dictionary) -> void:
	var m: Dictionary = UIKit.modal(host, title, Vector2(640, 500))
	var root: Control = m["root"]
	root.set_meta("modal", "rewards")
	root.name = "Rewards"
	var body: VBoxContainer = m["body"]
	var chest_type: String = str(rewards.get("chest_type", ""))
	var col: Color = UIKit.GOLD
	if Catalog.CHESTS.has(chest_type):
		col = Catalog.CHESTS[chest_type]["color"]
	var icon := UIIcon.new("chest" if chest_type != "" else "gift", 92.0, col.lightened(0.2))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.pivot_offset = Vector2(46, 46)
	body.add_child(icon)
	SoundManager.play("chest_open")
	var tw := icon.create_tween()
	tw.tween_property(icon, "rotation", 0.25, 0.08)
	tw.tween_property(icon, "rotation", -0.25, 0.08)
	tw.tween_property(icon, "rotation", 0.15, 0.08)
	tw.tween_property(icon, "rotation", 0.0, 0.08)
	tw.tween_property(icon, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	var list := UIKit.vbox(6)
	body.add_child(list)
	var lines: PackedStringArray = GameManager.describe_rewards(rewards)
	if lines.is_empty():
		lines.append("Nichts – Pech gehabt!")
	var delay: float = 0.5
	for line in lines:
		var l := UIKit.label(line, 24, UIKit.TEXT, true)
		if line.begins_with("NEU"):
			l.add_theme_color_override("font_color", UIKit.GOLD)
		l.modulate.a = 0.0
		list.add_child(l)
		var lt := l.create_tween()
		lt.tween_interval(delay)
		lt.tween_property(l, "modulate:a", 1.0, 0.2)
		var snd: String = "coin" if line.contains("Coins") else ("gem" if line.contains("Gems") else "card")
		lt.tween_callback(func() -> void: SoundManager.play(snd))
		delay += 0.28
	body.add_child(UIKit.spacer(true))
	var ok := UIKit.button("SUPER!", UIKit.GREEN, root.queue_free, Vector2(240, 64), 26)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(ok)
	menu.call("refresh_showcase")
