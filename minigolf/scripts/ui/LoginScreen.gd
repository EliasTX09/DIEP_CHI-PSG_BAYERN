class_name LoginScreen
extends Control
## E-Mail/Passwort, Gast-Login, Gast -> Account verknuepfen, Username aendern.

signal back

var _mail: LineEdit
var _pw: LineEdit
var _name: LineEdit
var _status: Label

func _ready() -> void:
	var v := UIKit.screen(self, "Account")
	_status = UIKit.label("", 26, true)
	v.add_child(_status)
	if not Cfg.is_online_capable():
		v.add_child(UIKit.label("Backend nicht konfiguriert. Siehe docs/BACKEND_SETUP.md – bis dahin laeuft das Spiel offline.", 26))
	if Supa.is_logged_in():
		_status.text = "Angemeldet als " + ("Gast" if Supa.is_anonymous else Supa.email)
		_name = UIKit.line_edit("Anzeigename")
		_name.text = Supa.username
		v.add_child(_name)
		v.add_child(UIKit.button("Namen speichern", _save_name))
	_mail = UIKit.line_edit("E-Mail")
	_pw = UIKit.line_edit("Passwort (min. 6 Zeichen)", true)
	v.add_child(_mail)
	v.add_child(_pw)
	if Supa.is_logged_in() and Supa.is_anonymous:
		v.add_child(UIKit.button("Gast-Account mit E-Mail verknuepfen", _link))
	else:
		v.add_child(UIKit.button("Anmelden", _sign_in))
		v.add_child(UIKit.button("Registrieren", _sign_up))
		v.add_child(UIKit.button("Als Gast spielen", _guest))
	if Supa.is_logged_in():
		v.add_child(UIKit.button("Abmelden", func(): Supa.sign_out(); back.emit()))
	v.add_child(UIKit.button("← Zurueck", func(): back.emit()))

func _report(r: Dictionary) -> void:
	if r.ok and Supa.is_logged_in():
		back.emit()
	else:
		_status.text = str(r.get("note", "Fehlgeschlagen (Code %s)" % r.get("code", 0)))

func _sign_in() -> void:
	_status.text = "..."
	_report(await Supa.sign_in(_mail.text.strip_edges(), _pw.text))

func _sign_up() -> void:
	_status.text = "..."
	_report(await Supa.sign_up(_mail.text.strip_edges(), _pw.text))

func _guest() -> void:
	_status.text = "..."
	_report(await Supa.sign_in_guest())

func _link() -> void:
	_status.text = "..."
	var r: Dictionary = await Supa.link_email(_mail.text.strip_edges(), _pw.text)
	_status.text = "Verknuepft! Ggf. E-Mail bestaetigen." if r.ok else str(r.get("note", "Fehler"))

func _save_name() -> void:
	var n := _name.text.strip_edges()
	if n.length() < 3:
		_status.text = "Name zu kurz (min. 3)."
		return
	var r: Dictionary = await Supa.rest_patch("profiles?id=eq." + Supa.user_id, {"username": n})
	if r.ok:
		Supa.username = n
		_status.text = "Gespeichert."
	else:
		_status.text = "Name vergeben oder ungueltig."
