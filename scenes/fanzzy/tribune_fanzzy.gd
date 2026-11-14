class_name TribuneFanzzy
extends Node2D
## Une tribune de FANZZY animés, posés sur des gradins aux couleurs du club.
## Origine = milieu du bord avant de la tribune (sous la première rangée).
##
##     var t := TribuneFanzzy.new()
##     t.fanzzy_ids = ["MT14", "TR32", "AN2"]   # répétés pour remplir
##     t.couleurs = [Color("1e6bff"), Color("ffffff")]
##     add_child(t)
##     t.reagir(&"but")                          # toute la tribune célèbre
##     t.ola()                                   # vague de gauche à droite

## Événements du match (ou du duel) auxquels la tribune sait réagir.
const REACTIONS := {
	&"but": {"action": &"celebrer", "dispersion": 0.35},
	&"but_adverse": {"action": &"depit", "dispersion": 0.6},
	&"occasion": {"action": &"applaudir", "dispersion": 0.25, "duree": 2.5},
	&"faute": {"action": &"huer", "dispersion": 0.3},
	&"chant": {"action": &"chanter", "dispersion": 0.0},
	&"tifo": {"action": &"agiter_echarpe", "dispersion": 0.15},
	&"pression": {"action": &"encourager", "dispersion": 0.1},
}

@export var fanzzy_ids: PackedStringArray = []
@export var couleurs: PackedColorArray = [Color("1e6bff"), Color("ffffff")]
@export_range(1, 8) var rangees := 3
@export_range(1, 20) var places_par_rangee := 6
@export var largeur := 900.0
@export var hauteur_rangee := 120.0
## Taille à l'écran d'un FANZZY de la première rangée, en pixels.
@export var taille_fanzzy := 210.0
@export_range(60, 200) var bpm := 120.0:
	set(v):
		bpm = v
		for f in fanzzy:
			f.bpm = v
## 0 = calme, 1 = bouillante : amplitude des gestes et part de la tribune qui suit.
@export_range(0.0, 1.5) var energie := 1.0:
	set(v):
		energie = v
		for f in fanzzy:
			f.energie = v

var fanzzy: Array[FanzzyAnime] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	construire()


## (Re)crée les FANZZY. À rappeler après avoir changé fanzzy_ids ou la taille.
func construire() -> void:
	for f in fanzzy:
		f.queue_free()
	fanzzy.clear()
	if fanzzy_ids.is_empty():
		return
	var n := 0
	# du fond vers l'avant, pour que l'avant soit dessiné par-dessus
	for r in range(rangees - 1, -1, -1):
		var echelle := 1.0 - 0.1 * r
		var y := -r * hauteur_rangee - 8.0
		var places := places_par_rangee
		for i in places:
			var id := fanzzy_ids[(n * 7 + r * 3) % fanzzy_ids.size()]
			n += 1
			var f := FanzzyAnime.creer(id)
			if f.texture == null:
				push_warning("TribuneFanzzy : image introuvable pour %s" % id)
				continue
			var decal := 0.5 if r % 2 == 1 else 0.0
			var x := ((i + 0.5 + decal * 0.5) / places - 0.5) * largeur * echelle
			x += _rng.randf_range(-0.12, 0.12) * largeur / places
			f.position = Vector2(x, y)
			var s := taille_fanzzy * echelle / f._rect.size.y
			f.scale = Vector2(s, s)
			f.couleurs_echarpe = couleurs
			f.bpm = bpm
			f.energie = energie
			f.decalage = _rng.randf_range(0.0, 0.15)
			f.modulate = Color(1, 1, 1).darkened(0.07 * r)
			add_child(f)
			fanzzy.append(f)
	queue_redraw()


## Fait jouer la même action à toute la tribune, avec un léger désordre.
func jouer_tous(action: StringName, duree := -1.0, dispersion := 0.15) -> void:
	for f in fanzzy:
		f.jouer(action, duree, _rng.randf_range(0.0, dispersion))


## Vague de gauche à droite (ou l'inverse avec `vers_la_droite = false`).
func ola(action: StringName = &"celebrer", duree_par_fan := 0.9, traversee := 2.0, vers_la_droite := true) -> void:
	for f in fanzzy:
		var u := (f.position.x / largeur) + 0.5
		if not vers_la_droite:
			u = 1.0 - u
		f.jouer(action, duree_par_fan, clampf(u, 0.0, 1.0) * traversee)


## Réaction à un événement (voir REACTIONS). Avec une énergie basse,
## une partie de la tribune ne suit pas et reste au repos.
func reagir(evenement: StringName) -> void:
	if not REACTIONS.has(evenement):
		push_warning("TribuneFanzzy : événement inconnu « %s »" % evenement)
		return
	var r: Dictionary = REACTIONS[evenement]
	for f in fanzzy:
		if _rng.randf() > clampf(energie, 0.25, 1.0):
			f.jouer(&"repos")
			continue
		f.jouer(r.action, r.get("duree", -1.0), _rng.randf_range(0.0, r.dispersion))


func _draw() -> void:
	var fonce := couleurs[0].darkened(0.55) if couleurs.size() > 0 else Color(0.1, 0.1, 0.2)
	var clair := couleurs[0].darkened(0.3) if couleurs.size() > 0 else Color(0.2, 0.2, 0.3)
	for r in range(rangees - 1, -1, -1):
		var echelle := 1.0 - 0.1 * r
		var w := largeur * echelle + 80.0
		var y := -r * hauteur_rangee
		draw_rect(Rect2(-w * 0.5, y - hauteur_rangee * 0.55, w, hauteur_rangee * 0.55 + 4), fonce if r % 2 == 0 else clair)
		draw_rect(Rect2(-w * 0.5, y - 6, w, 10), Color(0, 0, 0, 0.35))
	# bandeau du club sur le devant
	if couleurs.size() > 1:
		var w := largeur + 80.0
		var nb := 16
		for i in nb:
			draw_rect(Rect2(-w * 0.5 + w * i / nb, 4, w / nb + 1, 26), couleurs[i % 2])
		draw_rect(Rect2(-w * 0.5, 4, w, 26), Color(0.05, 0.04, 0.1), false, 4.0)
