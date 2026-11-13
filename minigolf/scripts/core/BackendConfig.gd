extends Node
## Autoload "Cfg": liest die Supabase-Zugangsdaten.
## Reihenfolge: res://config/backend.cfg (lokal / CI-Secret) -> backend.example.cfg (Platzhalter).

var url: String = ""
var anon_key: String = ""

func _ready() -> void:
	var cf := ConfigFile.new()
	var path := "res://config/backend.cfg"
	if cf.load(path) != OK:
		cf.load("res://config/backend.example.cfg")
	url = str(cf.get_value("supabase", "url", "")).strip_edges().trim_suffix("/")
	anon_key = str(cf.get_value("supabase", "anon_key", "")).strip_edges()

## true, wenn echte Werte gesetzt sind (keine Platzhalter).
func is_online_capable() -> bool:
	return url.begins_with("https://") and not url.contains("DEIN-PROJEKT") \
		and anon_key != "" and not anon_key.begins_with("DEIN_")

func ws_base() -> String:
	return url.replace("https://", "wss://")
