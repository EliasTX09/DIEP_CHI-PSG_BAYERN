class_name ShopScreen
extends Control
## Shop: Schlaeger kaufen/upgraden, Baelle, Trails, Loch-Effekte kaufen & ausruesten.

signal back

var _list: VBoxContainer
var _coins: Label
var _kind: String = "club"

func _ready() -> void:
	_list = UIKit.screen(self, "Shop")
	Progression.changed.connect(_rebuild)
	_rebuild()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_coins = UIKit.label("🪙 %d" % Progression.coins, 36, true)
	_list.add_child(_coins)
	var tabs := HBoxContainer.new()
	for t in [["club", "Schlaeger"], ["ball", "Baelle"], ["trail", "Trails"], ["fx", "Loch-FX"]]:
		var b := UIKit.button(t[1], func(): _kind = t[0]; _rebuild())
		b.disabled = _kind == t[0]
		b.add_theme_font_size_override("font_size", 24)
		tabs.add_child(b)
	_list.add_child(tabs)
	var table := Catalog.table(_kind)
	for id in table:
		_list.add_child(_row(id, table[id]))
	_list.add_child(UIKit.button("← Zurueck", func(): back.emit()))

func _row(id: String, item: Dictionary) -> Control:
	var box := VBoxContainer.new()
	var owned := Progression.owns(_kind, id)
	var title := str(item["name"])
	if _kind == "club":
		var lvl: int = int(Progression.club_levels.get(id, 0))
		var st := Catalog.club_stats(id, lvl)
		title += "  (Lv %d/%d)\nKraft %.2f · Fuehrung %.2f · Spin %.2f" % [lvl, Catalog.MAX_LEVEL, st["power"], st["guidance"], st["spin"]]
	box.add_child(UIKit.label(title, 26))
	var row := HBoxContainer.new()
	if not owned:
		var b := UIKit.button("Kaufen  🪙 %d" % Progression.price(_kind, id), func(): Progression.buy(_kind, id))
		b.disabled = Progression.coins < Progression.price(_kind, id)
		row.add_child(b)
	else:
		var eq: bool = Progression.equipped[_kind] == id
		var b := UIKit.button("Ausgeruestet ✔" if eq else "Ausruesten", func(): Progression.equip(_kind, id))
		b.disabled = eq
		row.add_child(b)
		if _kind == "club":
			var lvl2: int = int(Progression.club_levels.get(id, 0))
			if lvl2 < Catalog.MAX_LEVEL:
				var cost := Catalog.upgrade_cost(id, lvl2)
				var u := UIKit.button("Upgrade 🪙 %d" % cost, func(): Progression.upgrade_club(id))
				u.disabled = Progression.coins < cost
				row.add_child(u)
	box.add_child(row)
	return box
