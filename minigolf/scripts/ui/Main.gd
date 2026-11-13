extends Control
## Wurzel-Szene: Screen-Router (Menue / Login / Shop / Lobby / Spiel) + Match-Start-Helfer.

const PLAYER_COLORS := [Color(0.3, 0.7, 1.0), Color(1.0, 0.5, 0.3), Color(0.9, 0.3, 0.9), Color(1.0, 0.9, 0.2)]

var _current: Control = null
var _game: Node = null

func _ready() -> void:
	theme = UIKit.make_theme()
	DisplayServer.screen_set_keep_on(true)
	show_menu()

func _clear() -> void:
	if _current:
		_current.queue_free()
		_current = null
	if _game:
		_game.queue_free()
		_game = null

func _show(screen: Control) -> void:
	_clear()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
	_current = screen

func show_menu() -> void:
	var s := MainMenu.new()
	s.go_shop.connect(show_shop)
	s.go_lobby.connect(show_lobby)
	s.go_login.connect(show_login)
	s.start_practice.connect(start_practice)
	s.start_ghost.connect(start_ghost)
	_show(s)

func show_shop() -> void:
	var s := ShopScreen.new()
	s.back.connect(show_menu)
	_show(s)

func show_login() -> void:
	var s := LoginScreen.new()
	s.back.connect(show_menu)
	_show(s)

func show_lobby() -> void:
	var s := LobbyScreen.new()
	s.back.connect(show_menu)
	s.start_online.connect(start_online)
	_show(s)

# ---------------------------------------------------------------- Match-Start

func _begin(mode: int, plist: Array) -> void:
	_clear()
	GameManager.local_id = "local"
	var g: GameScene = load("res://scenes/Game.tscn").instantiate()
	g.exit_requested.connect(show_menu)
	add_child(g)
	_game = g
	GameManager.start_match(mode, plist)

func _me(color_idx: int = 0) -> Dictionary:
	var nm := Supa.username if Supa.username != "" else "Du"
	return {"id": "local", "name": nm, "color": Catalog.BALLS[Progression.equipped["ball"]]["color"], "kind": "local"}

func start_practice() -> void:
	var plist: Array = [_me()]
	for i in 3:
		plist.append({"id": "bot%d" % i, "name": "Bot %d" % (i + 1), "color": PLAYER_COLORS[i], "kind": "bot"})
	_begin(GameManager.Mode.QUICK_DM, plist)

## Ghost-Challenge: eigener Bestlauf + (falls vorhanden) bester Freundes-Ghost je Bahn.
func start_ghost() -> void:
	var plist: Array = [_me()]
	plist.append({"id": "ghost_self", "name": "Dein Geist", "color": Color(0.8, 0.8, 1.0), "kind": "ghost"})
	if Supa.is_logged_in():
		var friend_ghosts := {}
		var fname := ""
		for cid in CourseData.match_set():
			var g: Dictionary = await GhostRecorder.fetch_friend_ghost(cid)
			if not g.is_empty():
				friend_ghosts[cid] = g
				var prof = g.get("profiles")
				if prof is Dictionary:
					fname = str(prof.get("username", ""))
		if not friend_ghosts.is_empty():
			plist.append({"id": "ghost_friend", "name": (fname if fname != "" else "Freund"), "color": Color(1, 0.8, 0.5),
				"kind": "ghost", "ghost": friend_ghosts})
	_begin(GameManager.Mode.GHOST, plist)

## Aus der Lobby: players = [{id,name,color}] fuer ALLE (identisch bei jedem Client).
func start_online(players: Array) -> void:
	var plist: Array = []
	for p in players:
		var is_me: bool = p["id"] == Supa.user_id
		plist.append({
			"id": "local" if is_me else p["id"], "name": p["name"],
			"color": Color.html(str(p["color"])) if p["color"] is String else p["color"],
			"kind": "local" if is_me else "remote"})
	_begin(GameManager.Mode.QUICK_DM, plist)
