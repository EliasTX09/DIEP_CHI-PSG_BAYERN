class_name MenuPages
extends RefCounted
## Alle Seiten des Hauptmenues (Hochformat, 720 px breit).
## - Tab-Seiten (Tasche, Pass, Freunde, Shop) fuellen den Inhaltsbereich zwischen Kopfleiste und Tab-Leiste.
## - Overlays (Spielen, Lobby, Profil/Einstellungen, Trophaeen) und Dialoge liegen als Fenster ueber allem.
## open(page_id) baut eine Seite; refresh() baut die oberste Seite neu auf (z.B. nach Kauf, Lobby-Update).

## Wird gesendet, wenn sich die Tab-Seite aendert ("" = Startseite).
signal page_changed(page_id: String)

const PAGES := {
	"play": {"title": "Spielen", "tab": "", "size": Vector2(680, 980)},
	"lobby": {"title": "Private Lobby", "tab": "", "size": Vector2(680, 1100)},
	"settings": {"title": "Profil & Einstellungen", "tab": "", "size": Vector2(680, 1180)},
	"trophies": {"title": "Trophäen & Ligen", "tab": "", "size": Vector2(680, 1100)},
	"clubs": {"title": "Schläger & Tasche", "tab": "bag"},
	"cosmetics": {"title": "Schläger & Tasche", "tab": "bag"},
	"pass": {"title": "Battle Pass", "tab": "pass"},
	"friends": {"title": "Freunde", "tab": "social"},
	"leaderboard": {"title": "Freunde", "tab": "social"},
	"shop": {"title": "Shop", "tab": "shop"},
}
## Unterreiter der Tab-Seiten: [page_id, Beschriftung]
const SUBTABS := {
	"bag": [["clubs", "Schläger"], ["cosmetics", "Bälle & FX"]],
	"social": [["friends", "Freunde"], ["leaderboard", "Rangliste"]],
}
## Gem -> Coin Tauschangebote: [gems, coins]
const EXCHANGE: Array[Vector2i] = [Vector2i(10, 250), Vector2i(50, 1400), Vector2i(120, 3600)]
const STAT_COLORS := {"power": Color(1.0, 0.45, 0.25), "accuracy": Color(0.3, 0.75, 1.0), "spin": Color(0.75, 0.45, 1.0), "guide": Color(0.35, 0.9, 0.5)}

## Auswahl fuer das Spielen (bleibt waehrend der Sitzung erhalten)
static var sel_world: String = "emerald"
static var sel_rounds: int = 3
static var sel_bots: int = 3

var menu: Node
## Fenster und Dialoge
var host: Control
## Inhaltsbereich fuer Tab-Seiten
var content: Control

## Oberste offene Seite (Overlay vor Tab-Seite); "" wenn keine.
var page: String:
	get:
		return str(_top().get("id", ""))
## {"id", "root", "body"} der obersten Seite (leer, wenn keine offen ist).
var modal: Dictionary:
	get:
		return _top()

var _tab: Dictionary = {}
var _overlay: Dictionary = {}
var _sel_club: String = ""
var _sel_kind: String = "ball"
var _search_results: Array = []
var _search_text: String = ""
var _busy: bool = false

func _init(p_menu: Node, p_host: Control, p_content: Control = null) -> void:
	menu = p_menu
	host = p_host
	content = p_content if p_content != null else p_host
	NetworkManager.lobby_updated.connect(_on_net_update.bind("lobby"))
	NetworkManager.lobby_left.connect(func(_reason: String) -> void: _on_net_update("lobby"))
	NetworkManager.friends_updated.connect(_on_net_update.bind("friends"))
	NetworkManager.invites_updated.connect(_on_net_update.bind("friends"))
	NetworkManager.leaderboard_updated.connect(_on_net_update.bind("leaderboard"))
	AuthManager.auth_changed.connect(func() -> void:
		_on_net_update("settings")
		_on_net_update("friends"))
	GameManager.currency_changed.connect(_on_data_changed)
	GameManager.inventory_changed.connect(_on_data_changed)
	GameManager.pass_changed.connect(_on_net_update.bind("pass"))

# ================================================================ Verwaltung

static func _valid(slot: Dictionary) -> bool:
	return not slot.is_empty() and is_instance_valid(slot["root"]) and not (slot["root"] as Node).is_queued_for_deletion()

func _top() -> Dictionary:
	if _valid(_overlay):
		return _overlay
	if _valid(_tab):
		return _tab
	return {}

## Tab der gerade offenen Tab-Seite ("" = Startseite).
func current_tab() -> String:
	if _valid(_tab):
		return str(PAGES[str(_tab["id"])]["tab"])
	return ""

func is_open() -> bool:
	return not _top().is_empty()

## Irgendein Fenster offen (Overlay-Seite, Belohnung, Rueckfrage)?
func any_modal_open() -> bool:
	for c in host.get_children():
		if c.has_meta("modal") and not c.is_queued_for_deletion():
			return true
	return false

func open(page_id: String) -> void:
	if not PAGES.has(page_id):
		return
	var def: Dictionary = PAGES[page_id]
	SoundManager.play("tab")
	match page_id:
		"friends":
			NetworkManager.refresh_friends()
			NetworkManager.refresh_invites()
		"leaderboard":
			NetworkManager.refresh_leaderboard()
	if str(def["tab"]) != "":
		_close_overlay()
		_close_tab(false)
		_tab = _make_tab_page(page_id)
		_build(_tab)
		page_changed.emit(page_id)
	else:
		_close_overlay()
		var m: Dictionary = UIKit.modal(host, str(def["title"]), def["size"])
		var root: Control = m["root"]
		root.set_meta("modal", "page")
		root.name = "Page_" + page_id
		root.tree_exited.connect(_on_overlay_closed.bind(root))
		_overlay = {"id": page_id, "root": root, "body": m["body"]}
		_build(_overlay)

## Tab-Seite: Hintergrundflaeche im Inhaltsbereich, Titel, Unterreiter und Inhalt.
func _make_tab_page(page_id: String) -> Dictionary:
	var def: Dictionary = PAGES[page_id]
	var tab: String = str(def["tab"])
	var root := Control.new()
	root.name = "Page_" + page_id
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	content.add_child(root)
	var bg := UIKit.panel(Color(0.06, 0.09, 0.19, 0.95), 24, Color(0.35, 0.5, 0.9, 0.55), 2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var outer := UIKit.vbox(10)
	bg.add_child(UIKit.margin(outer, 14, 12, 14, 12))
	var head := UIKit.hbox(10)
	outer.add_child(head)
	var tl := UIKit.label(str(def["title"]), 30, UIKit.GOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	if SUBTABS.has(tab):
		var row := UIKit.hbox(8)
		outer.add_child(row)
		for st in (SUBTABS[tab] as Array):
			var sid: String = str(st[0])
			var b := UIKit.button(str(st[1]), UIKit.BLUE if sid == page_id else UIKit.PANEL_LIGHT, func() -> void:
				if sid != page:
					open(sid), Vector2(0, 52), 21)
			b.name = "Sub_" + sid
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.add_child(b)
	var body := UIKit.vbox(10)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	root.modulate.a = 0.0
	var tw := root.create_tween()
	tw.tween_property(root, "modulate:a", 1.0, 0.12)
	return {"id": page_id, "root": root, "body": body}

func _close_overlay() -> void:
	if _valid(_overlay):
		(_overlay["root"] as Control).queue_free()
	_overlay = {}

func _close_tab(notify: bool = true) -> void:
	var had: bool = _valid(_tab)
	if had:
		(_tab["root"] as Control).queue_free()
	_tab = {}
	if had and notify:
		page_changed.emit("")

## Schliesst die oberste Seite (Overlay vor Tab-Seite).
func close() -> void:
	if _valid(_overlay):
		_close_overlay()
	else:
		_close_tab()

## Schliesst alle Seiten und kehrt zur Startseite zurueck.
func close_all() -> void:
	_close_overlay()
	_close_tab()

## Schliesst das oberste Fenster bzw. die Tab-Seite (Android-Zurueck-Taste). false, wenn nichts offen war.
func close_top() -> bool:
	var children := host.get_children()
	for i in range(children.size() - 1, -1, -1):
		var c: Node = children[i]
		if c.has_meta("modal") and not c.is_queued_for_deletion():
			c.queue_free()
			return true
	if _valid(_tab):
		_close_tab()
		return true
	return false

func _on_overlay_closed(root: Control) -> void:
	if not _overlay.is_empty() and _overlay["root"] == root:
		_overlay = {}

## Baut die oberste Seite neu auf.
func refresh() -> void:
	var top: Dictionary = _top()
	if not top.is_empty():
		_rebuild(top)

func _rebuild(slot: Dictionary) -> void:
	var body: VBoxContainer = slot["body"]
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	_build(slot)

func _on_net_update(which: String) -> void:
	if not is_instance_valid(host):
		return
	for slot in [_tab, _overlay]:
		if _valid(slot) and str(slot["id"]) == which:
			_rebuild(slot)

func _on_data_changed() -> void:
	if not is_instance_valid(host) or _busy:
		return
	for slot in [_tab, _overlay]:
		if _valid(slot) and str(slot["id"]) in ["clubs", "cosmetics", "shop", "trophies", "settings", "pass"]:
			_rebuild(slot)

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

func _build(slot: Dictionary) -> void:
	var body: VBoxContainer = slot["body"]
	match str(slot["id"]):
		"play":
			_page_play(body)
		"lobby":
			_page_lobby(body)
		"clubs":
			_page_clubs(body)
		"cosmetics":
			_page_cosmetics(body)
		"pass":
			_page_pass(body)
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

## Reihe von Auswahl-Buttons; der aktive ist gold. expand: Buttons teilen sich die Breite.
func _choice_row(options: Array, current: Variant, on_pick: Callable, min_size: Vector2 = Vector2(120, 56), font_size: int = 22, expand: bool = false) -> HBoxContainer:
	var row := UIKit.hbox(8)
	for opt in options:
		var value: Variant = opt[0]
		var b := UIKit.button(str(opt[1]), UIKit.GOLD.darkened(0.15) if value == current else UIKit.PANEL_LIGHT,
			func() -> void: on_pick.call(value), min_size, font_size)
		if expand:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	var h := UIKit.hbox(10)
	p.add_child(UIKit.margin(h, 10, 6, 10, 6))
	return h

## Label, das sich die Restbreite nimmt und zu lange Namen mit "…" kuerzt.
func _fill_label(text: String, size: int = 21, color: Color = UIKit.TEXT) -> Label:
	var l := UIKit.label(text, size, color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return l

## Scrollbereich, der die Restflaeche fuellt. Rueckgabe: innere Liste.
func _scroll(parent: Control, min_height: float = 200.0, separation: int = 10) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, min_height)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := UIKit.vbox(separation)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v

func _grid(parent: Control, columns: int, sep: int = 10) -> GridContainer:
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", sep)
	g.add_theme_constant_override("v_separation", sep)
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g

func _offline_note(parent: Control, what: String) -> void:
	var t: String = "%s brauchen eine Internetverbindung und ein eingetragenes Supabase-Backend (config/backend.cfg, siehe README)." % what
	if NetworkManager.is_configured():
		t = "%s: Verbindung zum Server wird aufgebaut ... (%s)" % [what, AuthManager.status]
	parent.add_child(UIKit.wrap_label(t, 21, UIKit.TEXT_DIM))

static func _days_text(seconds: float) -> String:
	var s: int = int(ceil(maxf(0.0, seconds)))
	if s >= 86400:
		return "%d T %d h" % [s / 86400, (s / 3600) % 24]
	return UIKit.format_time(float(s))

# ================================================================ Overlay: Spielen

func _page_play(body: VBoxContainer) -> void:
	_section(body, "Arena (danach geht es auf Welttour)")
	var worlds := _grid(body, 2)
	for w in Catalog.WORLDS:
		var id: String = w["id"]
		var col: Color = w["color"]
		var b := UIKit.button("%s\n%d Bahnen" % [str(w["name"]), (w["courses"] as Array).size()],
			col.darkened(0.2) if id == sel_world else col.darkened(0.7), func() -> void:
				if menu != null and menu.has_method("select_world"):
					menu.call("select_world", id)
				else:
					sel_world = id
				refresh(), Vector2(0, 92), 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if id == sel_world:
			b.add_theme_stylebox_override("normal", UIKit.box(col.darkened(0.2), 16, Color.WHITE, 4))
		b.name = "World_" + id
		worlds.add_child(b)
	body.add_child(UIKit.wrap_label(str(Catalog.world_by_id(sel_world).get("desc", "")), 19, UIKit.TEXT_DIM))
	_section(body, "Runden")
	var round_opts: Array = []
	for r in Catalog.ROUND_OPTIONS:
		round_opts.append([r, str(r)])
	body.add_child(_choice_row(round_opts, sel_rounds, func(v: Variant) -> void:
		sel_rounds = int(v)
		_sync_menu()
		refresh(), Vector2(0, 58), 24, true))
	_section(body, "Bots (Offline-Modus)")
	var bot_opts: Array = []
	for n in range(1, Catalog.MAX_PLAYERS):
		bot_opts.append([n, str(n)])
	body.add_child(_choice_row(bot_opts, sel_bots, func(v: Variant) -> void:
		sel_bots = int(v)
		_sync_menu()
		refresh(), Vector2(0, 58), 24, true))
	body.add_child(UIKit.spacer(true))
	var bots := UIKit.button("GEGEN BOTS", UIKit.GREEN, func() -> void:
		close_all()
		NetworkManager.start_bot_match(sel_world, sel_rounds, sel_bots), Vector2(0, 84), 30)
	bots.name = "StartBots"
	body.add_child(bots)
	body.add_child(UIKit.button("ONLINE-SCHNELLSPIEL", UIKit.BLUE, func() -> void:
		if not NetworkManager.is_online():
			_toast("Offline – du spielst gegen Bots.")
			close_all()
			NetworkManager.start_bot_match(sel_world, sel_rounds, sel_bots)
			return
		NetworkManager.quick_match(sel_world, sel_rounds)
		open("lobby"), Vector2(0, 76), 26))
	body.add_child(UIKit.button("PRIVATE LOBBY", UIKit.PURPLE, func() -> void: open("lobby"), Vector2(0, 76), 26))
	var hint: String = "Online: bis zu 6 Spieler gleichzeitig, freie Plätze werden mit Bots aufgefüllt." if NetworkManager.is_online() \
		else "Ohne Server-Verbindung spielst du gegen Bots – Fortschritt und Belohnungen zählen trotzdem."
	body.add_child(UIKit.wrap_label(hint, 18, UIKit.TEXT_DIM, true))

func _sync_menu() -> void:
	if menu != null and menu.has_method("refresh_play_info"):
		menu.call("refresh_play_info")

# ================================================================ Overlay: Lobby

func _page_lobby(body: VBoxContainer) -> void:
	if not NetworkManager.is_online():
		_offline_note(body, "Private Lobbys")
		body.add_child(UIKit.spacer(true))
		body.add_child(UIKit.button("Stattdessen gegen Bots spielen", UIKit.GREEN, func() -> void:
			close_all()
			NetworkManager.start_bot_match(sel_world, sel_rounds, sel_bots), Vector2(0, 76), 24))
		return
	if not NetworkManager.in_lobby():
		_section(body, "Neue Lobby mit Raum-Code (%s, %d Runden)" % [str(Catalog.world_by_id(sel_world)["name"]), sel_rounds])
		body.add_child(UIKit.button("LOBBY ERSTELLEN", UIKit.GREEN, func() -> void:
			NetworkManager.create_lobby(sel_world, sel_rounds, false), Vector2(0, 76), 26))
		_section(body, "Oder mit 4-stelligem Code beitreten")
		var row := UIKit.hbox(10)
		body.add_child(row)
		var edit := LineEdit.new()
		edit.name = "CodeEdit"
		edit.placeholder_text = "CODE"
		edit.max_length = 4
		edit.custom_minimum_size = Vector2(0, 70)
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit.add_theme_font_size_override("font_size", 34)
		edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
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
				h.add_child(_fill_label("%s – Raum %s" % [str(inv["from_name"]), str(inv["code"])], 21))
				var code: String = str(inv["code"])
				var inv_id: Variant = inv["id"]
				h.add_child(UIKit.button("Beitreten", UIKit.GREEN, func() -> void:
					NetworkManager.dismiss_invite(inv_id)
					NetworkManager.join_lobby(code), Vector2(150, 52), 20))
		return
	# --- in einer Lobby
	var lobby: Dictionary = NetworkManager.lobby
	var host_me: bool = NetworkManager.is_host()
	var head := UIKit.hbox(12)
	body.add_child(head)
	head.add_child(UIKit.label("Raum-Code:", 24, UIKit.TEXT_DIM))
	var code_label := UIKit.label(str(lobby["code"]), 44, UIKit.GOLD)
	code_label.name = "RoomCode"
	head.add_child(code_label)
	head.add_child(UIKit.spacer(true))
	head.add_child(UIKit.label("%d/%d" % [NetworkManager.roster.size(), Catalog.MAX_PLAYERS], 24))
	_section(body, "Spieler")
	var list := _scroll(body, 230, 8)
	for p in NetworkManager.roster:
		var me: bool = str(p["id"]) == NetworkManager.local_id()
		var h := _row_panel(list, me)
		h.add_child(UIAvatar.new(str(p.get("name", "?")), int(p.get("color", 0)), str(p.get("frame", "bronze")), 44.0))
		h.add_child(_fill_label(str(p.get("name", "Spieler")) + (" (du)" if me else ""), 21))
		if str(p["id"]) == str(lobby.get("host_id", "")):
			h.add_child(UIKit.label("HOST", 18, UIKit.GOLD))
		h.add_child(UIIcon.new("trophy", 22.0))
		h.add_child(UIKit.label(str(int(p.get("trophies", 0))), 20, UIKit.GOLD))
	if host_me:
		_section(body, "Arena")
		var wopts: Array = []
		for w in Catalog.WORLDS:
			wopts.append([str(w["id"]), str(w["name"]).get_slice(" ", 0)])
		body.add_child(_choice_row(wopts, str(lobby.get("world", "emerald")), func(v: Variant) -> void:
			NetworkManager.set_lobby_settings(str(v), int(lobby.get("rounds", 3))), Vector2(0, 52), 19, true))
		_section(body, "Runden")
		var ropts: Array = []
		for r in Catalog.ROUND_OPTIONS:
			ropts.append([r, str(r)])
		body.add_child(_choice_row(ropts, int(lobby.get("rounds", 3)), func(v: Variant) -> void:
			NetworkManager.set_lobby_settings(str(lobby.get("world", "emerald")), int(v)), Vector2(0, 52), 21, true))
		var fill := CheckBox.new()
		fill.text = "Freie Plätze mit Bots auffüllen (bis 4)"
		fill.button_pressed = NetworkManager.fill_bots
		fill.focus_mode = Control.FOCUS_NONE
		fill.add_theme_font_size_override("font_size", 20)
		fill.toggled.connect(func(on: bool) -> void: NetworkManager.fill_bots = on)
		body.add_child(fill)
	else:
		body.add_child(UIKit.wrap_label("Arena: %s · %d Runden\nWarte, bis der Host das Match startet ..." % [
			str(Catalog.world_by_id(str(lobby.get("world", "emerald")))["name"]), int(lobby.get("rounds", 3))], 21, UIKit.TEXT))
	_section(body, "Freunde einladen")
	var flist := _scroll(body, 150, 8)
	var any_friend := false
	for f in NetworkManager.friends:
		if str(f["state"]) != "accepted":
			continue
		any_friend = true
		var h := _row_panel(flist)
		h.add_child(UIKit.label("•", 30, UIKit.GREEN if bool(f["online"]) else UIKit.GREY))
		h.add_child(_fill_label(str(f["name"]), 20))
		var fid: String = str(f["id"])
		h.add_child(UIKit.button("Einladen", UIKit.BLUE, func() -> void: _invite(fid), Vector2(130, 46), 18))
	if not any_friend:
		flist.add_child(UIKit.wrap_label("Noch keine Freunde – füge sie im Freunde-Tab hinzu.", 18, UIKit.TEXT_DIM))
	var actions := UIKit.hbox(10)
	body.add_child(actions)
	if host_me:
		var start := UIKit.button("MATCH STARTEN", UIKit.GREEN, func() -> void:
			close_all()
			NetworkManager.start_lobby_match(), Vector2(0, 74), 26)
		start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(start)
	var leave := UIKit.button("Verlassen", UIKit.RED, func() -> void: NetworkManager.leave_lobby(), Vector2(200, 74), 22)
	if not host_me:
		leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(leave)

func _invite(friend_id: String) -> void:
	var r: Dictionary = await NetworkManager.invite_friend(friend_id)
	_toast(str(r["message"]), UIKit.GREEN.darkened(0.4) if bool(r["ok"]) else UIKit.RED.darkened(0.3))

# ================================================================ Tab Tasche: Schlaeger

func _page_clubs(body: VBoxContainer) -> void:
	var eq: String = GameManager.equipped_club()
	var info := _row_panel(body)
	var pv := Preview3D.new("club", eq, 64.0)
	info.add_child(pv)
	var iv := UIKit.vbox(0)
	iv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(iv)
	iv.add_child(UIKit.label("Ausgerüstet: %s · Lv %d" % [Catalog.club_name(eq), GameManager.club_level(eq)], 21,
		Catalog.RARITY_COLORS.get(Catalog.club_rarity(eq), Color.WHITE)))
	iv.add_child(UIKit.label("Tippe auf eine Karte für Details & Upgrade", 17, UIKit.TEXT_DIM))
	var list := _scroll(body, 300, 6)
	for cat in Catalog.CATEGORIES:
		list.add_child(UIKit.label(str(Catalog.CATEGORY_NAMES[cat]), 20, UIKit.TEXT_DIM))
		var row := _grid(list, 4, 8)
		for rar in Catalog.RARITIES:
			row.add_child(_club_card("%s_%s" % [cat, rar]))

func _club_card(id: String) -> Button:
	var rar: String = Catalog.club_rarity(id)
	var col: Color = Catalog.RARITY_COLORS.get(rar, Color.WHITE)
	var owned: bool = GameManager.owns_club(id)
	var b := Button.new()
	b.name = "Club_" + id
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 172)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg: Color = col.darkened(0.55) if owned else Color(0.1, 0.11, 0.16)
	var border: Color = UIKit.GREEN if id == GameManager.equipped_club() else col.darkened(0.15)
	b.add_theme_stylebox_override("normal", UIKit.box(bg, 14, border, 3))
	b.add_theme_stylebox_override("hover", UIKit.box(bg.lightened(0.08), 14, border, 3))
	b.add_theme_stylebox_override("pressed", UIKit.box(bg.darkened(0.1), 14, Color.WHITE, 3))
	b.pressed.connect(func() -> void:
		SoundManager.play("click")
		open_club_detail(id))
	var v := UIKit.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	b.add_child(v)
	var pv := Preview3D.new("club", id, 92.0)
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pv.modulate = Color.WHITE if owned else Color(0.45, 0.45, 0.5, 0.8)
	v.add_child(pv)
	var name_l := UIKit.label(Catalog.club_name(id), 16, UIKit.TEXT, true)
	name_l.clip_text = true
	name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(name_l)
	var lvl: String = ("Lv %d" % GameManager.club_level(id)) if owned else "gesperrt"
	if owned and GameManager.can_upgrade_club(id):
		lvl += "  UP!"
	v.add_child(UIKit.label(lvl, 16, UIKit.GREEN if owned and GameManager.can_upgrade_club(id) else (col if owned else UIKit.TEXT_DIM), true))
	return b

## Detail-Fenster eines Schlaegers mit drehbarer 3D-Vorschau, Werten, Upgrade und Ausruesten.
func open_club_detail(id: String) -> void:
	_sel_club = id
	var m: Dictionary = UIKit.modal(host, Catalog.club_name(id), Vector2(660, 1000))
	var root: Control = m["root"]
	root.set_meta("modal", "club")
	root.name = "ClubDetail"
	var dv: VBoxContainer = m["body"]
	var rar: String = Catalog.club_rarity(id)
	var cat: String = Catalog.club_category(id)
	var col: Color = Catalog.RARITY_COLORS.get(rar, Color.WHITE)
	var pv := Preview3D.new("club", id, 230.0, true)
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dv.add_child(pv)
	dv.add_child(UIKit.label("%s · %s" % [str(Catalog.CATEGORY_NAMES[cat]), str(Catalog.RARITY_NAMES[rar])], 21, col, true))
	dv.add_child(UIKit.wrap_label(str(Catalog.CATEGORY_HINTS[cat]), 18, UIKit.TEXT_DIM, true))
	var owned: bool = GameManager.owns_club(id)
	var lvl: int = maxi(1, GameManager.club_level(id))
	var maxed: bool = GameManager.club_is_max(id)
	var stats: Dictionary = Catalog.club_stats(id, lvl)
	var next: Dictionary = Catalog.club_stats(id, mini(lvl + 1, Catalog.club_max_level(id)))
	dv.add_child(UIKit.label("Stufe %d / %d" % [lvl, Catalog.club_max_level(id)], 22, UIKit.TEXT, true))
	for k in Catalog.STAT_KEYS:
		var row := UIKit.hbox(8)
		dv.add_child(row)
		var name_l := UIKit.label(str(Catalog.STAT_NAMES[k]), 19)
		name_l.custom_minimum_size = Vector2(130, 0)
		row.add_child(name_l)
		var bar := UIKit.bar(float(stats[k]) / 100.0, STAT_COLORS[k], Vector2(0, 18))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
		var gain: float = float(next[k]) - float(stats[k])
		var vt: String = str(int(stats[k]))
		if owned and not maxed and gain > 0.0:
			vt += " +%d" % int(gain)
		var vl := UIKit.label(vt, 19, UIKit.GREEN if owned and not maxed and gain > 0.0 else UIKit.TEXT)
		vl.custom_minimum_size = Vector2(80, 0)
		row.add_child(vl)
	dv.add_child(UIKit.spacer(true))
	if not owned:
		dv.add_child(UIKit.wrap_label("Noch nicht freigeschaltet. Die erste Karte aus einer Truhe schaltet diesen Schläger frei.", 19, UIKit.TEXT_DIM, true))
		return
	if maxed:
		dv.add_child(UIKit.label("Maximale Stufe erreicht!", 22, UIKit.GOLD, true))
	else:
		var need: int = Catalog.upgrade_card_cost(id, lvl)
		var have: int = GameManager.club_cards(id)
		var ch := UIKit.hbox(8)
		dv.add_child(ch)
		ch.add_child(UIIcon.new("cards", 26.0))
		var cb := UIKit.bar(float(have) / float(need), UIKit.BLUE, Vector2(0, 20))
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ch.add_child(cb)
		ch.add_child(UIKit.label("%d/%d" % [have, need], 19))
		var cost: int = Catalog.upgrade_coin_cost(id, lvl)
		var up := UIKit.button("UPGRADE  %s Coins" % UIKit.format_number(cost), UIKit.GREEN, func() -> void:
			if GameManager.upgrade_club(id):
				SoundManager.play("upgrade")
				_toast("%s ist jetzt Stufe %d!" % [Catalog.club_name(id), GameManager.club_level(id)], UIKit.GREEN.darkened(0.4))
				root.queue_free()
				open_club_detail(id)
			else:
				SoundManager.play("error"), Vector2(0, 66), 24)
		up.name = "UpgradeButton"
		up.disabled = not GameManager.can_upgrade_club(id)
		dv.add_child(up)
	if id == GameManager.equipped_club():
		dv.add_child(UIKit.label("Ausgerüstet", 22, UIKit.GREEN, true))
	else:
		var eqb := UIKit.button("AUSRÜSTEN", UIKit.BLUE, func() -> void:
			GameManager.equip_club(id)
			SoundManager.play("pop")
			root.queue_free(), Vector2(0, 66), 24)
		eqb.name = "EquipButton"
		dv.add_child(eqb)

# ================================================================ Tab Tasche: Baelle, Trails, Explosionen, Rahmen

func _page_cosmetics(body: VBoxContainer) -> void:
	var kinds: Array = [["ball", "Bälle"], ["trail", "Trails"], ["explosion", "Explosion"], ["frame", "Rahmen"]]
	body.add_child(_choice_row(kinds, _sel_kind, func(v: Variant) -> void:
		_sel_kind = str(v)
		refresh(), Vector2(0, 52), 19, true))
	var list := _scroll(body, 300, 10)
	var grid := _grid(list, 2, 10)
	var table: Dictionary = Catalog.item_table(_sel_kind)
	for id in Catalog.item_order(_sel_kind):
		grid.add_child(_item_card(_sel_kind, id, table[id]))

func _item_card(kind: String, id: String, def: Dictionary) -> PanelContainer:
	var owned: bool = GameManager.owns(kind, id)
	var equipped: bool = (GameManager.avatar_frame() == id) if kind == "frame" else (GameManager.equipped(kind) == id)
	var p := UIKit.panel(UIKit.PANEL_LIGHT, 16, UIKit.GREEN if equipped else Color(1, 1, 1, 0.12), 3 if equipped else 2)
	p.custom_minimum_size = Vector2(0, 280)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.name = "Item_%s_%s" % [kind, id]
	var v := UIKit.vbox(4)
	p.add_child(UIKit.margin(v, 10, 8, 10, 8))
	var preview: Control
	match kind:
		"frame":
			var av := UIAvatar.new(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), id, 110.0)
			av.set_picture(ProfileManager.avatar_texture)
			preview = av
		"ball":
			preview = Preview3D.new("ball", id, 120.0)
		"trail":
			preview = Preview3D.new("trail", id, 120.0, id != "none") if id != "none" else Preview3D.new("ball", GameManager.equipped("ball"), 120.0)
		_:
			var ic := UIIcon.new("star", 96.0, _explosion_color(id))
			preview = ic
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not owned and not equipped:
		preview.modulate = Color(1, 1, 1, 0.7)
	v.add_child(preview)
	var tl := UIKit.label(str(def["name"]), 21, UIKit.TEXT, true)
	tl.clip_text = true
	tl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(tl)
	var info: String = str(def.get("desc", ""))
	if kind == "frame" and str(def.get("league", "")) != "":
		info = "Liga: %s" % str(Catalog.league_for(_league_min(str(def["league"])))["name"])
	elif kind == "frame" and bool(def.get("pass", false)):
		info = "Nur im Battle Pass"
	if info != "":
		var il := UIKit.label(info, 16, UIKit.TEXT_DIM, true)
		il.clip_text = true
		il.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(il)
	v.add_child(UIKit.spacer(true))
	var actions := UIKit.hbox(6)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(actions)
	if equipped:
		actions.add_child(UIKit.label("Ausgerüstet", 20, UIKit.GREEN))
	elif owned:
		var eb := UIKit.button("Ausrüsten", UIKit.BLUE, func() -> void:
			GameManager.equip(kind, id)
			SoundManager.play("pop"), Vector2(0, 50), 19)
		eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(eb)
	elif GameManager.item_buyable(kind, id):
		var price: Vector2i = GameManager.item_price(kind, id)
		var buy := UIKit.button(_price_text(price), UIKit.PURPLE if price.y > 0 else UIKit.GOLD.darkened(0.2), func() -> void:
			if GameManager.buy_item(kind, id):
				SoundManager.play("coin")
				GameManager.equip(kind, id)
				_toast("„%s“ gekauft!" % str(def["name"]), UIKit.GREEN.darkened(0.4))
			else:
				SoundManager.play("error")
				_toast("Nicht genug %s." % ("Gems" if price.y > 0 else "Coins"), UIKit.RED.darkened(0.3)), Vector2(0, 50), 19)
		buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buy.disabled = not GameManager.can_afford(price.x, price.y)
		actions.add_child(buy)
	else:
		actions.add_child(UIKit.label("Gesperrt", 19, UIKit.TEXT_DIM))
	if kind == "explosion":
		actions.add_child(UIKit.icon_button("eye", UIKit.GREY, func() -> void: _preview_explosion(id), 50.0))
	return p

func _league_min(league_id: String) -> int:
	for l in Catalog.LEAGUES:
		if str(l["id"]) == league_id:
			return int(l["min"])
	return 0

func _explosion_color(id: String) -> Color:
	match id:
		"lightning":
			return Color(0.5, 0.75, 1.0)
		"blackhole":
			return Color(0.65, 0.35, 1.0)
		"volcano":
			return Color(1.0, 0.45, 0.15)
		"fireworks":
			return Color(1.0, 0.35, 0.6)
	return UIKit.GOLD

## Spielt die Loch-Explosion vor der Menue-Kamera ab (die Seite wird dafuer kurz ausgeblendet).
func _preview_explosion(id: String) -> void:
	var top: Dictionary = _top()
	if top.is_empty():
		return
	var root: Control = top["root"]
	root.visible = false
	var cam: Camera3D = menu.get("camera")
	var pos: Vector3 = cam.global_transform * Vector3(0.0, -0.6, -7.0)
	var shake: float = BallFX.hole_explosion(menu as Node3D, id, pos)
	SoundManager.play("holed")
	SoundManager.play("bass", clampf(shake, 0.3, 1.0))
	await menu.get_tree().create_timer(2.6).timeout
	if is_instance_valid(root):
		root.visible = true

# ================================================================ Tab Battle Pass

func _page_pass(body: VBoxContainer) -> void:
	var season: int = GameManager.pass_season()
	var tier: int = GameManager.pass_tier()
	var total: int = Catalog.PASS_TIERS.size()
	var head := UIKit.panel(Color(0.22, 0.12, 0.4, 0.96), 18, Color(0.75, 0.55, 1.0), 2)
	body.add_child(head)
	var hv := UIKit.vbox(6)
	head.add_child(UIKit.margin(hv, 14, 10, 14, 10))
	var hr := UIKit.hbox(10)
	hv.add_child(hr)
	hr.add_child(UIIcon.new("star", 44.0, UIKit.GOLD))
	var tv := UIKit.vbox(0)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(tv)
	tv.add_child(UIKit.label("Saison %d: %s" % [season, Catalog.pass_season_name(season)], 24, UIKit.GOLD))
	tv.add_child(UIKit.label("Endet in " + _days_text(GameManager.pass_seconds_left()), 18, UIKit.TEXT_DIM))
	var tier_l := UIKit.label("%d/%d" % [tier, total], 30, UIKit.TEXT)
	tier_l.name = "PassTier"
	hr.add_child(tier_l)
	var br := UIKit.hbox(10)
	hv.add_child(br)
	var bar := UIKit.bar(GameManager.pass_tier_progress(), Color(0.75, 0.55, 1.0), Vector2(0, 24))
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	br.add_child(bar)
	var xp_text: String = "MAX" if tier >= total else "%d/%d XP" % [GameManager.pass_xp() % Catalog.PASS_XP_PER_TIER, Catalog.PASS_XP_PER_TIER]
	br.add_child(UIKit.label(xp_text, 19, UIKit.TEXT))
	hv.add_child(UIKit.wrap_label("XP: Match +%d · Sieg +%d · Hole-in-One +%d · Golden Shot +%d" % [
		Catalog.PASS_XP_MATCH, Catalog.PASS_XP_RANK[0], Catalog.PASS_XP_HOLE_IN_ONE, Catalog.PASS_XP_DAILY], 16, UIKit.TEXT_DIM))
	var claimable: Array[int] = GameManager.pass_claimable()
	if claimable.size() > 1:
		var all := UIKit.button("ALLE ABHOLEN (%d)" % claimable.size(), UIKit.GREEN, _claim_all_pass, Vector2(0, 62), 24)
		all.name = "PassClaimAll"
		body.add_child(all)
	var list := _scroll(body, 300, 8)
	var focus: Control = null
	for i in total:
		var row := _pass_row(i)
		list.add_child(row)
		if focus == null and (not GameManager.pass_claimed(i)) and (GameManager.pass_tier_unlocked(i) or i == tier):
			focus = row
	if focus != null:
		var sc := list.get_parent() as ScrollContainer
		sc.ensure_control_visible.call_deferred(focus)

func _pass_row(i: int) -> PanelContainer:
	var unlocked: bool = GameManager.pass_tier_unlocked(i)
	var claimed: bool = GameManager.pass_claimed(i)
	var ready: bool = unlocked and not claimed
	var p := UIKit.panel(Color(0.32, 0.26, 0.08, 0.96) if ready else UIKit.PANEL_LIGHT, 14,
		UIKit.GOLD if ready else Color(1, 1, 1, 0.1), 2)
	p.name = "PassTier_%d" % (i + 1)
	var h := UIKit.hbox(10)
	p.add_child(UIKit.margin(h, 10, 6, 10, 6))
	var badge := UIKit.label(str(i + 1), 24, UIKit.TEXT, true)
	badge.custom_minimum_size = Vector2(52, 52)
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_theme_stylebox_override("normal", UIKit.box(Color(0.6, 0.4, 0.95) if unlocked else Color(0.2, 0.22, 0.3), 26))
	h.add_child(badge)
	var e: Dictionary = Catalog.PASS_TIERS[i]
	var icon: Control
	if e.has("item") and str((e["item"] as Array)[0]) == "ball":
		icon = Preview3D.new("ball", str((e["item"] as Array)[1]), 56.0)
	elif e.has("item") and str((e["item"] as Array)[0]) == "frame":
		icon = UIAvatar.new(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), str((e["item"] as Array)[1]), 52.0)
	elif e.has("chest"):
		icon = UIIcon.new("chest", 48.0, (Catalog.CHESTS[str(e["chest"])]["color"] as Color).lightened(0.2))
	else:
		icon = UIIcon.new(Catalog.pass_reward_icon(i), 46.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(icon)
	var tl := UIKit.wrap_label(Catalog.pass_reward_text(i), 19, UIKit.TEXT if unlocked else UIKit.TEXT_DIM)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(tl)
	if claimed:
		h.add_child(UIIcon.new("check", 34.0, UIKit.GREEN))
	elif unlocked:
		var b := UIKit.button("Abholen", UIKit.GREEN, func() -> void:
			var r: Dictionary = GameManager.pass_claim(i)
			if not r.is_empty():
				show_rewards("Pass-Stufe %d" % (i + 1), r)
			else:
				SoundManager.play("error"), Vector2(140, 52), 20)
		b.name = "PassClaim_%d" % (i + 1)
		h.add_child(b)
	else:
		h.add_child(UIIcon.new("lock", 30.0, Color(1, 1, 1, 0.4)))
	return p

func _claim_all_pass() -> void:
	var lines := PackedStringArray()
	var chest_type := ""
	_busy = true
	for i in GameManager.pass_claimable():
		var r: Dictionary = GameManager.pass_claim(i)
		if r.is_empty():
			continue
		lines.append_array(GameManager.describe_rewards(r))
		if str(r.get("chest", "")) != "":
			chest_type = str(r["chest"])
	_busy = false
	if lines.is_empty():
		SoundManager.play("error")
		return
	show_rewards("Battle Pass", {"chest_type": chest_type}, lines)
	_on_net_update("pass")

# ================================================================ Tab Freunde

func _page_friends(body: VBoxContainer) -> void:
	body.add_child(UIKit.button("PRIVATE LOBBY · FREUNDE EINLADEN", UIKit.PURPLE, func() -> void: open("lobby"), Vector2(0, 62), 21))
	if not NetworkManager.is_online():
		_offline_note(body, "Freunde")
		return
	var head := UIKit.hbox(10)
	body.add_child(head)
	head.add_child(UIKit.label("Dein Code:", 21, UIKit.TEXT_DIM))
	var code := UIKit.label(NetworkManager.friend_code if NetworkManager.friend_code != "" else "...", 30, UIKit.GOLD)
	code.name = "FriendCode"
	code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(code)
	head.add_child(UIKit.icon_button("spin", UIKit.GREY, func() -> void:
		NetworkManager.refresh_friends()
		NetworkManager.refresh_invites(), 52.0))
	var search := UIKit.hbox(8)
	body.add_child(search)
	var edit := LineEdit.new()
	edit.placeholder_text = "Name oder Freundes-Code"
	edit.text = _search_text
	edit.custom_minimum_size = Vector2(0, 58)
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.add_theme_font_size_override("font_size", 22)
	search.add_child(edit)
	search.add_child(UIKit.button("Suchen", UIKit.BLUE, func() -> void: _search(edit.text), Vector2(140, 58), 22))
	edit.text_submitted.connect(func(t: String) -> void: _search(t))
	var list := _scroll(body, 300, 8)
	if not _search_results.is_empty():
		list.add_child(UIKit.label("Suchergebnisse", 19, UIKit.TEXT_DIM))
		for p in _search_results:
			var h := _row_panel(list)
			h.add_child(UIAvatar.new(str(p["name"]), int(p["color"]), str(p["frame"]), 44.0))
			var v := UIKit.vbox(0)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(_fill_label(str(p["name"]), 21))
			v.add_child(UIKit.label("#%s · %d Trophäen" % [str(p["code"]), int(p["trophies"])], 16, UIKit.TEXT_DIM))
			var pid: String = str(p["id"])
			h.add_child(UIKit.button("Hinzufügen", UIKit.GREEN, func() -> void: _add_friend(pid), Vector2(150, 48), 19))
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
			h.add_child(_fill_label(str(f["name"]), 21))
			var rid: Variant = f["row_id"]
			h.add_child(UIKit.button("Annehmen", UIKit.GREEN, func() -> void: NetworkManager.accept_friend(rid), Vector2(140, 48), 19))
			h.add_child(UIKit.icon_button("close", UIKit.RED, func() -> void: NetworkManager.remove_friend(rid), 48.0))
	list.add_child(UIKit.label("Freunde (%d)" % accepted.size(), 19, UIKit.TEXT_DIM))
	if accepted.is_empty():
		list.add_child(UIKit.wrap_label("Noch keine Freunde. Suche nach Namen, teile deinen Freundes-Code oder nutze das Web-Portal (Profil → Account verknüpfen).", 19, UIKit.TEXT_DIM))
	for f in accepted:
		var h := _row_panel(list)
		h.add_child(UIAvatar.new(str(f["name"]), int(f["color"]), str(f["frame"]), 44.0))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_fill_label(str(f["name"]), 21))
		v.add_child(UIKit.label(("online" if bool(f["online"]) else "offline") + " · %d Trophäen" % int(f["trophies"]), 16,
			UIKit.GREEN if bool(f["online"]) else UIKit.TEXT_DIM))
		var fid: String = str(f["id"])
		var rid2: Variant = f["row_id"]
		if NetworkManager.in_lobby():
			h.add_child(UIKit.button("Einladen", UIKit.BLUE, func() -> void: _invite(fid), Vector2(130, 48), 18))
		h.add_child(UIKit.icon_button("close", UIKit.GREY, func() -> void: _confirm("Freund entfernen?", "%s wirklich entfernen?" % str(f["name"]),
			func() -> void: NetworkManager.remove_friend(rid2)), 48.0))
	if not outgoing.is_empty():
		list.add_child(UIKit.label("Gesendete Anfragen", 19, UIKit.TEXT_DIM))
		for f in outgoing:
			var h := _row_panel(list)
			h.add_child(_fill_label(str(f["name"]) + " (wartet)", 20, UIKit.TEXT_DIM))
			var rid3: Variant = f["row_id"]
			h.add_child(UIKit.button("Zurückziehen", UIKit.GREY, func() -> void: NetworkManager.remove_friend(rid3), Vector2(170, 46), 18))

func _search(text: String) -> void:
	_search_text = text
	if text.strip_edges().length() < 2:
		_toast("Mindestens 2 Zeichen eingeben.")
		return
	_search_results = await NetworkManager.search_players(text)
	if _search_results.is_empty():
		_toast("Niemand gefunden.")
	_on_net_update("friends")

func _add_friend(pid: String) -> void:
	var r: Dictionary = await NetworkManager.send_friend_request(pid)
	_toast(str(r["message"]), UIKit.GREEN.darkened(0.4) if bool(r["ok"]) else UIKit.RED.darkened(0.3))
	_search_results = _search_results.filter(func(p: Dictionary) -> bool: return str(p["id"]) != pid)
	_on_net_update("friends")

# ================================================================ Tab Freunde: Rangliste

func _page_leaderboard(body: VBoxContainer) -> void:
	var info: String = "Weltweite Rangliste nach Trophäen" if NetworkManager.is_online() else "Offline-Rangliste (mit Backend: echte Weltrangliste)"
	body.add_child(UIKit.label(info, 18, UIKit.TEXT_DIM))
	var list := _scroll(body, 300, 8)
	if NetworkManager.leaderboard.is_empty():
		list.add_child(UIKit.label("Lade ...", 22, UIKit.TEXT_DIM))
		return
	var rank := 0
	for row in NetworkManager.leaderboard:
		rank += 1
		var me: bool = bool(row.get("me", false))
		var h := _row_panel(list, me)
		var rl := UIKit.label("%d." % rank, 24, UIKit.GOLD if rank <= 3 else UIKit.TEXT)
		rl.custom_minimum_size = Vector2(50, 0)
		h.add_child(rl)
		h.add_child(UIAvatar.new(str(row["name"]), int(row.get("color", 0)), str(row.get("frame", "bronze")), 44.0))
		var lg: Dictionary = Catalog.league_for(int(row["trophies"]))
		var v := UIKit.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(_fill_label(str(row["name"]) + ("  (du)" if me else ""), 21))
		v.add_child(UIKit.label(str(lg["name"]), 16, lg["color"]))
		h.add_child(UIIcon.new("trophy", 24.0))
		var tl := UIKit.label(UIKit.format_number(int(row["trophies"])), 22, UIKit.GOLD)
		tl.custom_minimum_size = Vector2(76, 0)
		h.add_child(tl)

# ================================================================ Tab Shop

func _page_shop(body: VBoxContainer) -> void:
	var list := _scroll(body, 300, 12)
	# Tagesgeschenk
	var gift := UIKit.panel(Color(0.12, 0.35, 0.2, 0.95), 16, UIKit.GREEN, 2)
	list.add_child(gift)
	var gh := UIKit.hbox(10)
	gift.add_child(UIKit.margin(gh, 12, 8, 12, 8))
	gh.add_child(UIIcon.new("gift", 52.0))
	var gv := UIKit.vbox(0)
	gv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(gv)
	gv.add_child(UIKit.label("Tagesgeschenk", 24))
	if GameManager.gift_available():
		gv.add_child(UIKit.label("Coins und mit Glück Gems – jeden Tag neu", 16, UIKit.TEXT_DIM))
		var gb := UIKit.button("ABHOLEN", UIKit.GREEN, func() -> void:
			var r: Dictionary = GameManager.claim_gift()
			if not r.is_empty():
				show_rewards("Tagesgeschenk", r), Vector2(170, 60), 24)
		gb.name = "GiftButton"
		gh.add_child(gb)
	else:
		gv.add_child(UIKit.label("Morgen gibt es ein neues Geschenk!", 17, UIKit.TEXT_DIM))
	# Truhen
	list.add_child(UIKit.label("Truhen (sofort öffnen)", 22, UIKit.TEXT_DIM))
	var chests := _grid(list, 2, 10)
	for type in Catalog.CHEST_ORDER:
		var def: Dictionary = Catalog.CHESTS[type]
		var col: Color = def["color"]
		var p := UIKit.panel(col.darkened(0.6), 16, col, 3)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chests.add_child(p)
		var v := UIKit.vbox(6)
		p.add_child(UIKit.margin(v, 10, 8, 10, 8))
		var icon := UIIcon.new("chest", 72.0, col.lightened(0.2))
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(icon)
		v.add_child(UIKit.label(str(def["name"]), 21, UIKit.TEXT, true))
		var coins_range: Array = def["coins"]
		v.add_child(UIKit.label("%d-%d Coins · %d Karten" % [int(coins_range[0]), int(coins_range[1]), int(def["cards"])], 15, UIKit.TEXT_DIM, true))
		var t: String = type
		var price: int = int(def["gem_price"])
		var buy := UIKit.button("%d Gems" % price, UIKit.PURPLE, func() -> void:
			_busy = true
			var r: Dictionary = GameManager.buy_chest(t)
			_busy = false
			if not r.is_empty():
				show_rewards(str(Catalog.CHESTS[t]["name"]), r)
				_on_net_update("shop"), Vector2(0, 54), 21)
		buy.disabled = GameManager.gems() < price
		v.add_child(buy)
	# Gem -> Coin Tausch
	list.add_child(UIKit.label("Gems in Coins tauschen", 22, UIKit.TEXT_DIM))
	var er := UIKit.hbox(10)
	list.add_child(er)
	for offer in EXCHANGE:
		var g: int = offer.x
		var c: int = offer.y
		var b := UIKit.button("%s Coins\nfür %d Gems" % [UIKit.format_number(c), g], UIKit.GOLD.darkened(0.35), func() -> void:
			if GameManager.exchange_gems(g, c):
				SoundManager.play("coin")
				_toast("+%s Coins" % UIKit.format_number(c), UIKit.GREEN.darkened(0.4))
			else:
				SoundManager.play("error")
				_toast("Nicht genug Gems.", UIKit.RED.darkened(0.3)), Vector2(0, 92), 19)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = GameManager.gems() < g
		er.add_child(b)
	list.add_child(UIKit.wrap_label("Gems gibt es in Truhen, im Battle Pass, im Trophäen-Pfad, beim Golden Shot und mit dem Tagesgeschenk. Es gibt keine Echtgeld-Käufe.", 16, UIKit.TEXT_DIM))

# ================================================================ Overlay: Trophaeen & Ligen

func _page_trophies(body: VBoxContainer) -> void:
	var t: int = GameManager.trophies()
	var lg: Dictionary = GameManager.league()
	var li: int = Catalog.league_index(t)
	var head := UIKit.hbox(12)
	body.add_child(head)
	head.add_child(UIIcon.new("trophy", 56.0))
	var hv := UIKit.vbox(2)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	hv.add_child(UIKit.label("%s Trophäen" % UIKit.format_number(t), 30, UIKit.GOLD))
	hv.add_child(UIKit.label("Liga: %s" % str(lg["name"]), 22, lg["color"]))
	if li < Catalog.LEAGUES.size() - 1:
		var nxt: Dictionary = Catalog.LEAGUES[li + 1]
		var lo: int = int(lg["min"])
		var hi: int = int(nxt["min"])
		body.add_child(UIKit.label("Nächste Liga: %s (%d)" % [str(nxt["name"]), hi], 19, nxt["color"]))
		var bar := UIKit.bar(float(t - lo) / float(maxi(1, hi - lo)), nxt["color"], Vector2(0, 22))
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.add_child(bar)
	else:
		body.add_child(UIKit.label("Höchste Liga erreicht!", 21, UIKit.GOLD))
	var leagues := UIKit.hbox(6)
	body.add_child(leagues)
	for i in Catalog.LEAGUES.size():
		var l: Dictionary = Catalog.LEAGUES[i]
		var p := UIKit.panel((l["color"] as Color).darkened(0.65 if i != li else 0.3), 12, l["color"], 3 if i == li else 1)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.add_child(UIKit.label("%s\n%d" % [str(l["name"]), int(l["min"])], 16, UIKit.TEXT, true))
		leagues.add_child(p)
	body.add_child(UIKit.label("Trophäen-Pfad (nach Rekord-Trophäen)", 19, UIKit.TEXT_DIM))
	var list := _scroll(body, 300, 8)
	var best: int = int(GameManager.data.get("best_trophies", 0))
	for i in Catalog.TROPHY_ROAD.size():
		var e: Dictionary = Catalog.TROPHY_ROAD[i]
		var reached: bool = best >= int(e["at"])
		var claimed: bool = GameManager.road_claimed(i)
		var h := _row_panel(list, reached and not claimed)
		h.add_child(UIIcon.new("trophy", 22.0, Color.WHITE if reached else Color(1, 1, 1, 0.35)))
		var al := UIKit.label(str(int(e["at"])), 22, UIKit.GOLD if reached else UIKit.TEXT_DIM)
		al.custom_minimum_size = Vector2(64, 0)
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
		var rl := UIKit.wrap_label(" + ".join(parts), 19, UIKit.TEXT if reached else UIKit.TEXT_DIM)
		rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(rl)
		if claimed:
			h.add_child(UIIcon.new("check", 30.0, UIKit.GREEN))
		elif reached:
			var idx: int = i
			h.add_child(UIKit.button("Abholen", UIKit.GREEN, func() -> void:
				var r: Dictionary = GameManager.claim_road(idx)
				if not r.is_empty():
					show_rewards("Trophäen-Pfad", r), Vector2(130, 48), 19))
		else:
			h.add_child(UIIcon.new("lock", 28.0, Color(1, 1, 1, 0.4)))
	var st: Dictionary = GameManager.data["stats"]
	body.add_child(UIKit.wrap_label("Matches %d · Siege %d · Hole-in-One %d · Bester Style %d" % [int(st.get("matches", 0)), int(st.get("wins", 0)),
		int(st.get("holes_in_one", 0)), int(st.get("best_style", 0))], 17, UIKit.TEXT_DIM, true))

# ================================================================ Overlay: Profil & Einstellungen

func _page_settings(body: VBoxContainer) -> void:
	var col := _scroll(body, 300, 8)
	# --- Profil
	_section(col, "Spielername (3-16 Zeichen)")
	var nr := UIKit.hbox(8)
	col.add_child(nr)
	var name_edit := LineEdit.new()
	name_edit.name = "NameEdit"
	name_edit.text = GameManager.player_name()
	name_edit.max_length = 16
	name_edit.custom_minimum_size = Vector2(0, 56)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 22)
	nr.add_child(name_edit)
	nr.add_child(UIKit.button("Speichern", UIKit.GREEN, func() -> void:
		if GameManager.set_player_name(name_edit.text):
			_toast("Name gespeichert.", UIKit.GREEN.darkened(0.4))
		else:
			_toast("Der Name braucht 3 bis 16 Zeichen.", UIKit.RED.darkened(0.3)), Vector2(160, 56), 20))
	_section(col, "Avatar-Farbe")
	var colors := HFlowContainer.new()
	colors.add_theme_constant_override("h_separation", 8)
	colors.add_theme_constant_override("v_separation", 8)
	col.add_child(colors)
	for i in Catalog.AVATAR_COLORS.size():
		var idx: int = i
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 56)
		var sel: bool = int(GameManager.data.get("avatar_color", 0)) == i
		b.add_theme_stylebox_override("normal", UIKit.box(Catalog.AVATAR_COLORS[i], 28, Color.WHITE if sel else Color(0, 0, 0, 0.4), 4 if sel else 2))
		b.add_theme_stylebox_override("hover", UIKit.box(Catalog.AVATAR_COLORS[i].lightened(0.1), 28, Color.WHITE, 2))
		b.add_theme_stylebox_override("pressed", UIKit.box(Catalog.AVATAR_COLORS[i].darkened(0.1), 28, Color.WHITE, 4))
		b.pressed.connect(func() -> void:
			SoundManager.play("click")
			GameManager.set_avatar_color(idx)
			refresh())
		colors.add_child(b)
	_section(col, "Avatar-Rahmen")
	var frames := HFlowContainer.new()
	frames.add_theme_constant_override("h_separation", 8)
	frames.add_theme_constant_override("v_separation", 8)
	col.add_child(frames)
	for fid in Catalog.FRAME_ORDER:
		var owned: bool = GameManager.owns("frame", fid)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(66, 66)
		var sel: bool = GameManager.avatar_frame() == fid
		b.add_theme_stylebox_override("normal", UIKit.box(UIKit.PANEL_LIGHT, 12, UIKit.GREEN if sel else Color(1, 1, 1, 0.1), 3 if sel else 1))
		b.add_theme_stylebox_override("pressed", UIKit.box(UIKit.PANEL, 12, UIKit.GREEN, 3))
		b.add_theme_stylebox_override("hover", UIKit.box(UIKit.PANEL_LIGHT, 12, Color.WHITE, 1))
		var av := UIAvatar.new(GameManager.player_name(), int(GameManager.data.get("avatar_color", 0)), fid, 54.0)
		av.position = Vector2(6, 6)
		av.size = Vector2(54, 54)
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
	_section(col, "Soundeffekte")
	col.add_child(_slider(float(GameManager.setting("sfx", 0.8)), 0.0, 1.0, func(v: float) -> void: GameManager.set_setting("sfx", v)))
	_section(col, "Kamera-Empfindlichkeit")
	col.add_child(_slider(float(GameManager.setting("camera_sens", 1.0)), 0.4, 2.0, func(v: float) -> void: GameManager.set_setting("camera_sens", v)))
	var vib := CheckBox.new()
	vib.text = "Vibration"
	vib.focus_mode = Control.FOCUS_NONE
	vib.add_theme_font_size_override("font_size", 21)
	vib.button_pressed = bool(GameManager.setting("vibration", true))
	vib.toggled.connect(func(on: bool) -> void:
		_busy = true
		GameManager.set_setting("vibration", on)
		_busy = false)
	col.add_child(vib)
	# --- Account
	col.add_child(UIKit.label("Account", 26, UIKit.GOLD))
	if not AuthManager.is_configured():
		col.add_child(UIKit.wrap_label("Kein Backend eingetragen – du spielst im Offline-Modus. Trage Supabase-URL und Anon-Key in config/backend.cfg ein (siehe README), um Freunde, Online-Matches und Cloud-Speicherstand zu nutzen.", 19, UIKit.TEXT_DIM))
	else:
		var acc: String = "Status: %s" % AuthManager.status
		if AuthManager.is_online():
			acc += "\n" + ("Gast-Account (nur auf diesem Gerät)" if AuthManager.is_anonymous else "Verknüpft mit " + AuthManager.email)
		col.add_child(UIKit.wrap_label(acc, 19, UIKit.TEXT))
		# Web-Portal: Registrieren, Profilbild, Freunde - und dort einen Spiel-Code erzeugen
		var portal := UIKit.button("Account verknüpfen / Registrieren", UIKit.PURPLE, func() -> void:
			if not AuthManager.open_portal():
				_toast("Keine Web-Portal-Adresse eingetragen (config/backend.cfg, Abschnitt [web]).", UIKit.RED.darkened(0.3)), Vector2(0, 60), 21)
		portal.name = "PortalButton"
		portal.disabled = not AuthManager.has_portal()
		col.add_child(portal)
		_section(col, "Spiel-Code von der Website")
		var cr := UIKit.hbox(8)
		col.add_child(cr)
		var code_edit := LineEdit.new()
		code_edit.name = "WebCodeEdit"
		code_edit.placeholder_text = "XXXX-XXXX"
		code_edit.max_length = AuthManager.CODE_LENGTH + 2
		code_edit.custom_minimum_size = Vector2(0, 56)
		code_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		code_edit.add_theme_font_size_override("font_size", 24)
		cr.add_child(code_edit)
		cr.add_child(UIKit.button("Einlösen", UIKit.GREEN, func() -> void: _redeem_code(code_edit.text), Vector2(150, 56), 20))
		_section(col, "Oder direkt im Spiel anmelden")
		var mail := LineEdit.new()
		mail.name = "MailEdit"
		mail.placeholder_text = "E-Mail"
		mail.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		mail.custom_minimum_size = Vector2(0, 52)
		mail.add_theme_font_size_override("font_size", 20)
		col.add_child(mail)
		var pw := LineEdit.new()
		pw.name = "PasswordEdit"
		pw.placeholder_text = "Passwort (mind. 6 Zeichen)"
		pw.secret = true
		pw.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_PASSWORD
		pw.custom_minimum_size = Vector2(0, 52)
		pw.add_theme_font_size_override("font_size", 20)
		col.add_child(pw)
		var ar := UIKit.hbox(8)
		col.add_child(ar)
		var buttons: Array[Button] = []
		if AuthManager.is_online() and AuthManager.is_anonymous:
			buttons.append(UIKit.button("Gast verknüpfen", UIKit.GREEN, func() -> void: _account_action("link", mail.text, pw.text), Vector2(0, 54), 18))
		buttons.append(UIKit.button("Anmelden", UIKit.BLUE, func() -> void: _account_action("login", mail.text, pw.text), Vector2(0, 54), 18))
		if AuthManager.is_online():
			buttons.append(UIKit.button("Abmelden", UIKit.GREY, func() -> void:
				_confirm("Abmelden?", "Du spielst danach als neuer Gast weiter. Dein Account bleibt auf dem Server erhalten.", func() -> void:
					AuthManager.sign_out(true)), Vector2(0, 54), 18))
		for b in buttons:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			ar.add_child(b)
	col.add_child(UIKit.label("Geräte-ID: " + GameManager.device_id().substr(0, 8), 16, UIKit.TEXT_DIM))
	col.add_child(UIKit.button("Fortschritt zurücksetzen", UIKit.RED.darkened(0.2), func() -> void:
		_confirm("Wirklich zurücksetzen?", "Alle Coins, Gems, Schläger und Trophäen auf diesem Gerät werden gelöscht.", func() -> void:
			GameManager.reset_progress()
			menu.call("refresh_showcase")
			refresh()), Vector2(0, 54), 19))

func _slider(value: float, lo: float, hi: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(0, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_NONE
	s.value_changed.connect(func(v: float) -> void:
		_busy = true
		on_change.call(v)
		_busy = false)
	return s

func _redeem_code(text: String) -> void:
	if AuthManager.normalize_code(text) == "":
		_toast("Der Spiel-Code hat %d Zeichen – du findest ihn im Web-Portal unter „Spiel verbinden“." % AuthManager.CODE_LENGTH, UIKit.RED.darkened(0.3))
		return
	var r: Dictionary = await AuthManager.redeem_web_code(text)
	_toast(str(r["message"]), UIKit.GREEN.darkened(0.4) if bool(r["ok"]) else UIKit.RED.darkened(0.3))
	_on_net_update("settings")

func _account_action(action: String, mail: String, password: String) -> void:
	if not AuthManager.is_valid_email(mail) or password.length() < 6:
		_toast("Bitte gültige E-Mail und ein Passwort mit mind. 6 Zeichen eingeben.", UIKit.RED.darkened(0.3))
		return
	var r: Dictionary
	if action == "link":
		r = await AuthManager.link_email(mail, password)
	else:
		r = await AuthManager.sign_in_email(mail, password)
	_toast(str(r["message"]), UIKit.GREEN.darkened(0.4) if bool(r["ok"]) else UIKit.RED.darkened(0.3))
	_on_net_update("settings")

# ================================================================ Dialoge: Rueckfrage, Truhe, Belohnungen, Beenden

func _confirm(title: String, text: String, on_yes: Callable) -> void:
	var m: Dictionary = UIKit.modal(host, title, Vector2(620, 320))
	var root: Control = m["root"]
	root.set_meta("modal", "confirm")
	var body: VBoxContainer = m["body"]
	body.add_child(UIKit.wrap_label(text, 22, UIKit.TEXT, true))
	body.add_child(UIKit.spacer(true))
	var row := UIKit.hbox(12)
	body.add_child(row)
	var no := UIKit.button("Abbrechen", UIKit.GREY, root.queue_free, Vector2(0, 64), 22)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(no)
	var yes := UIKit.button("Ja", UIKit.RED, func() -> void:
		root.queue_free()
		on_yes.call(), Vector2(0, 64), 22)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(yes)

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
	var m: Dictionary = UIKit.modal(host, str(def["name"]), Vector2(640, 520))
	var root: Control = m["root"]
	root.set_meta("modal", "chest")
	var body: VBoxContainer = m["body"]
	var icon := UIIcon.new("chest", 120.0, col.lightened(0.2))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(icon)
	var coins_range: Array = def["coins"]
	body.add_child(UIKit.label("%d-%d Coins · %d Schläger-Karten" % [int(coins_range[0]), int(coins_range[1]), int(def["cards"])], 21, UIKit.TEXT_DIM, true))
	var state: String = GameManager.chest_state(slot)
	var remaining: float = GameManager.chest_remaining(slot)
	var info := UIKit.label("", 28, UIKit.GOLD, true)
	body.add_child(info)
	info.text = ("Öffnet in " if state == "unlocking" else "Dauer: ") + UIKit.format_time(remaining)
	root.set_meta("chest_slot", slot)
	root.set_meta("info_label", info)
	body.add_child(UIKit.spacer(true))
	if state == "locked":
		var other: int = GameManager.unlocking_slot()
		var start := UIKit.button("Timer starten", UIKit.GREEN, func() -> void:
			if GameManager.start_unlock(slot):
				SoundManager.play("beep")
			root.queue_free(), Vector2(0, 68), 24)
		start.disabled = other >= 0
		body.add_child(start)
		if other >= 0:
			body.add_child(UIKit.label("Es läuft schon ein Truhen-Timer.", 18, UIKit.TEXT_DIM, true))
	var cost: int = GameManager.chest_gem_cost(slot)
	var instant := UIKit.button("Sofort öffnen: %d Gems" % cost, UIKit.PURPLE, func() -> void:
		var r: Dictionary = GameManager.open_chest(slot, true)
		root.queue_free()
		if not r.is_empty():
			show_rewards(str(def["name"]), r), Vector2(0, 68), 24)
	instant.disabled = GameManager.gems() < cost
	body.add_child(instant)

## Belohnungs-Fenster mit Truhen-Animation und nacheinander aufploppenden Zeilen.
## lines: optional fertige Zeilen (sonst aus `rewards` beschrieben).
func show_rewards(title: String, rewards: Dictionary, lines: PackedStringArray = PackedStringArray()) -> void:
	var m: Dictionary = UIKit.modal(host, title, Vector2(640, 640))
	var root: Control = m["root"]
	root.set_meta("modal", "rewards")
	root.name = "Rewards"
	var body: VBoxContainer = m["body"]
	var chest_type: String = str(rewards.get("chest_type", rewards.get("chest", "")))
	var col: Color = UIKit.GOLD
	if Catalog.CHESTS.has(chest_type):
		col = Catalog.CHESTS[chest_type]["color"]
	var icon := UIIcon.new("chest" if chest_type != "" else "gift", 110.0, col.lightened(0.2))
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.pivot_offset = Vector2(55, 55)
	body.add_child(icon)
	SoundManager.play("chest_open")
	var tw := icon.create_tween()
	tw.tween_property(icon, "rotation", 0.25, 0.08)
	tw.tween_property(icon, "rotation", -0.25, 0.08)
	tw.tween_property(icon, "rotation", 0.15, 0.08)
	tw.tween_property(icon, "rotation", 0.0, 0.08)
	tw.tween_property(icon, "scale", Vector2(1.25, 1.25), 0.12)
	tw.tween_property(icon, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK)
	var list := _scroll(body, 200, 6)
	if lines.is_empty():
		lines = GameManager.describe_rewards(rewards)
	if lines.is_empty():
		lines.append("Nichts – Pech gehabt!")
	var delay: float = 0.5
	for line in lines:
		var l := UIKit.wrap_label(line, 24, UIKit.TEXT, true)
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
	var ok := UIKit.button("SUPER!", UIKit.GREEN, root.queue_free, Vector2(0, 68), 28)
	body.add_child(ok)
	menu.call("refresh_showcase")
