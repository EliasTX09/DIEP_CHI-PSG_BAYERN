class_name MainMenu
extends Control

signal go_shop
signal go_lobby
signal go_login
signal start_practice
signal start_ghost

var _info: Label

func _ready() -> void:
	var v := UIKit.screen(self, "FAIRWAY CLASH")
	_info = UIKit.label("", 28, true)
	v.add_child(_info)
	v.add_child(UIKit.button("⚔  Online-Match / Freunde", func(): go_lobby.emit()))
	v.add_child(UIKit.button("🏌  Quick-Deathmatch vs. Bots", func(): start_practice.emit()))
	v.add_child(UIKit.button("👻  Ghost-Challenge", func(): start_ghost.emit()))
	v.add_child(UIKit.button("🛒  Schlaeger & Shop", func(): go_shop.emit()))
	v.add_child(UIKit.button("👤  Account", func(): go_login.emit()))
	Progression.changed.connect(_refresh)
	Supa.auth_changed.connect(func(_ok): _refresh())
	_refresh()

func _refresh() -> void:
	var who := "Offline" if not Cfg.is_online_capable() else ("nicht angemeldet" if not Supa.is_logged_in() \
		else ("Gast" if Supa.is_anonymous else Supa.email))
	_info.text = "🪙 %d   💎 %d\n%s" % [Progression.coins, Progression.gems, who]
