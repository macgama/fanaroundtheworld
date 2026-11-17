class_name CommandesTactiles
extends Control
## Commandes au doigt pour téléphone : un joystick (en bas à gauche) et des
## boutons ronds (en bas à droite). Plusieurs doigts à la fois : on peut bouger
## et tirer en même temps. Un doigt posé ailleurs envoie `toucher_libre`.
##
## Les boutons Godot ne suivent que le premier doigt ; ici chaque doigt est
## suivi par son numéro (InputEventScreenTouch.index).

signal appui(id: String)
signal relache(id: String)
signal toucher_libre(position: Vector2)

const RAYON_JOYSTICK := 130.0
const RAYON_BOUTON := 74.0
const MARGE := 40.0

## Direction du joystick (longueur 0 à 1).
var direction := Vector2.ZERO
var avec_joystick := true

## id -> {texte, couleur, rayon, decalage (depuis le coin bas-droit), remplissage, actif}
var boutons: Dictionary = {}
var _doigts: Dictionary = {}   # index du doigt -> "joystick" ou id de bouton
var _pouce := Vector2.ZERO     # position du pouce sur le joystick (relative au centre)


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Ajoute un bouton rond. `decalage` : position du centre depuis le coin en bas à droite.
func ajouter_bouton(id: String, texte: String, couleur: Color, decalage: Vector2, rayon := RAYON_BOUTON) -> void:
	boutons[id] = {"texte": texte, "couleur": couleur, "rayon": rayon, "decalage": decalage, "remplissage": 1.0, "actif": true}
	queue_redraw()


## Bouton grisé (`actif` faux) ou en train de se recharger (`remplissage` < 1).
func regler_bouton(id: String, actif: bool, remplissage := 1.0) -> void:
	if not boutons.has(id):
		return
	var b: Dictionary = boutons[id]
	if b["actif"] != actif or not is_equal_approx(b["remplissage"], remplissage):
		b["actif"] = actif
		b["remplissage"] = remplissage
		queue_redraw()


func centre_joystick() -> Vector2:
	return Vector2(MARGE + RAYON_JOYSTICK + 30.0, size.y - RAYON_JOYSTICK - 150.0)


func centre_bouton(id: String) -> Vector2:
	return size - Vector2(MARGE, MARGE) + Vector2(boutons[id]["decalage"])


func _bouton_sous(p: Vector2) -> String:
	for id in boutons:
		if p.distance_to(centre_bouton(id)) <= float(boutons[id]["rayon"]) * 1.15:
			return id
	return ""


func _input(ev: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if ev is InputEventScreenTouch:
		var t := ev as InputEventScreenTouch
		var p := get_global_transform_with_canvas().affine_inverse() * t.position
		if t.pressed:
			var id := _bouton_sous(p)
			if id != "":
				_doigts[t.index] = id
				appui.emit(id)
			elif avec_joystick and p.x < size.x * 0.4 and p.y > size.y * 0.45:
				_doigts[t.index] = "joystick"
				_bouger_pouce(p)
			else:
				toucher_libre.emit(p)
				return
			get_viewport().set_input_as_handled()
		elif _doigts.has(t.index):
			var id: String = _doigts[t.index]
			_doigts.erase(t.index)
			if id == "joystick":
				_pouce = Vector2.ZERO
				direction = Vector2.ZERO
				queue_redraw()
			else:
				relache.emit(id)
			get_viewport().set_input_as_handled()
	elif ev is InputEventScreenDrag:
		var d := ev as InputEventScreenDrag
		if _doigts.get(d.index, "") == "joystick":
			_bouger_pouce(get_global_transform_with_canvas().affine_inverse() * d.position)
			get_viewport().set_input_as_handled()


func _bouger_pouce(p: Vector2) -> void:
	_pouce = (p - centre_joystick()).limit_length(RAYON_JOYSTICK)
	direction = _pouce / RAYON_JOYSTICK
	if direction.length() < 0.2:
		direction = Vector2.ZERO  # petite zone morte
	queue_redraw()


## Lâche tous les doigts (fin de partie, pause).
func relacher_tout() -> void:
	for i in _doigts:
		if _doigts[i] != "joystick":
			relache.emit(_doigts[i])
	_doigts.clear()
	_pouce = Vector2.ZERO
	direction = Vector2.ZERO
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var police := Ui.police_titre()
	if avec_joystick:
		var c := centre_joystick()
		draw_circle(c, RAYON_JOYSTICK, Color(Ui.NUIT, 0.35))
		draw_arc(c, RAYON_JOYSTICK, 0, TAU, 64, Color(1, 1, 1, 0.45), 5.0, true)
		draw_circle(c + _pouce, 58.0, Color(1, 1, 1, 0.55))
		draw_arc(c + _pouce, 58.0, 0, TAU, 48, Color(Ui.CONTOUR, 0.6), 4.0, true)
	for id in boutons:
		var b: Dictionary = boutons[id]
		var c := centre_bouton(id)
		var r: float = b["rayon"]
		var coul: Color = b["couleur"]
		var actif: bool = b["actif"]
		draw_circle(c, r, Color(coul if actif else Ui.GRIS.darkened(0.3), 0.75 if actif else 0.4))
		var rempli: float = b["remplissage"]
		if rempli < 1.0:
			draw_arc(c, r - 6.0, -PI / 2.0, -PI / 2.0 + TAU * rempli, 48, Color(1, 1, 1, 0.9), 8.0, true)
		draw_arc(c, r, 0, TAU, 48, Color(Ui.CONTOUR, 0.8), 5.0, true)
		var taille := 30 if r >= RAYON_BOUTON else 24
		var texte: String = tr(b["texte"])
		var l := police.get_string_size(texte, HORIZONTAL_ALIGNMENT_CENTER, -1, taille)
		draw_string_outline(police, c + Vector2(-l.x / 2.0, taille * 0.35), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, Ui.CONTOUR)
		draw_string(police, c + Vector2(-l.x / 2.0, taille * 0.35), texte, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Ui.BLANC)
