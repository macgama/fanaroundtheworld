extends Node
## Le son du jeu, en un seul point. À déclarer en autoload sous le nom « Sons »
## (project.godot, section [autoload]) :
##
##   Sons="*res://scripts/audio/sons.gd"
##
##   Sons.jouer("clameur_but")
##   Sons.jouer("tambour", {"volume_db": -3})     # un groupe : tirage au hasard
##   Sons.ambiance("pub", 1)                      # lieu, intensité 0..2
##   Sons.musique("accueil")
##   Sons.regler_volume("Musique", 0.5)           # curseur 0..1 des options
##
## Bus (default_bus_layout.tres) : Musique, Ambiance, Chants, Effets,
## Interface, tous vers Master qui porte un limiteur.
## Les chants rythmés passent par un ChantLecteur, pas par ici.

const PISTES := 16
const FONDU_AMBIANCE := 1.5
const FONDU_MUSIQUE := 1.0

var _pistes: Array[AudioStreamPlayer] = []
var _suivante := 0
var _amb: Array[AudioStreamPlayer] = []
var _amb_active := 0
var _amb_id := ""
var _musique: AudioStreamPlayer
var _musique_id := ""
var _tweens: Dictionary = {}


## Les lecteurs naissent avec le nœud, pas à son entrée dans l'arbre : on
## peut appeler Sons avant son _ready (depuis un autre autoload, un test).
func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in PISTES:
		var p := AudioStreamPlayer.new()
		p.name = "Piste%d" % i  # sans_traduction
		add_child(p)
		_pistes.append(p)
	for i in 2:
		var a := AudioStreamPlayer.new()
		a.name = "Ambiance%d" % i  # sans_traduction
		a.bus = BanqueSons.bus("Ambiance")  # sans_traduction
		a.volume_db = -80.0
		add_child(a)
		_amb.append(a)
	_musique = AudioStreamPlayer.new()
	_musique.name = "Musique"  # sans_traduction
	_musique.bus = BanqueSons.bus("Musique")  # sans_traduction
	add_child(_musique)


## Joue un son ou un groupe du catalogue. Options : volume_db (ajouté à
## celui du catalogue), hauteur (pitch), bus. Rend le lecteur, ou null.
func jouer(id: String, options := {}) -> AudioStreamPlayer:
	var f := BanqueSons.fiche(id)
	if f.is_empty():
		push_warning("Sons : son inconnu « %s »" % id)  # sans_traduction
		return null
	var s := BanqueSons.flux(String(f["fichier"]))
	if s == null:
		return null
	var p := _pistes[_suivante]
	_suivante = (_suivante + 1) % _pistes.size()
	p.stop()
	p.stream = s
	p.bus = BanqueSons.bus(String(options.get("bus", f.get("bus", "Effets"))))  # sans_traduction
	p.volume_db = float(f.get("volume_db", 0.0)) + float(options.get("volume_db", 0.0))
	var v := float(f.get("variation_hauteur", 0.0))
	p.pitch_scale = float(options.get("hauteur", 1.0)) * (1.0 + randf_range(-v, v))
	p.play()
	return p


## L'ambiance d'un lieu (« stade », « pub », « maison », « ecran_geant »), à
## une intensité de 0 (calme) à 2 (ferveur). Fondu enchaîné entre deux
## boucles ; changer seulement d'intensité au pub ne fait que monter le volume.
func ambiance(lieu: String, intensite := 1, fondu := FONDU_AMBIANCE) -> void:
	var a := BanqueSons.ambiance_du_lieu(lieu, intensite)
	if a.is_empty():
		push_warning("Sons : lieu inconnu « %s »" % lieu)  # sans_traduction
		return
	var fiche := BanqueSons.fiche_ambiance(String(a["id"]))
	var cible := float(fiche.get("volume_db", 0.0)) + float(a["volume_db"])
	if String(a["id"]) == _amb_id:
		_fondre(_amb[_amb_active], cible, fondu)
		return
	var s := BanqueSons.flux(String(fiche.get("fichier", "")), true)
	if s == null:
		return
	var ancienne := _amb[_amb_active]
	_amb_active = 1 - _amb_active
	var nouvelle := _amb[_amb_active]
	nouvelle.stream = s
	nouvelle.bus = BanqueSons.bus("Ambiance")  # sans_traduction
	nouvelle.volume_db = -60.0
	# Repartir d'un point au hasard : deux visites n'entendent pas la même seconde.
	nouvelle.play(randf() * maxf(0.0, s.get_length() - 1.0))
	_fondre(nouvelle, cible, fondu)
	_fondre(ancienne, -80.0, fondu, true)
	_amb_id = String(a["id"])


func couper_ambiance(fondu := FONDU_AMBIANCE) -> void:
	for a in _amb:
		_fondre(a, -80.0, fondu, true)
	_amb_id = ""


func musique(id: String, fondu := FONDU_MUSIQUE) -> void:
	if id == _musique_id and _musique.playing:
		return
	var f := BanqueSons.fiche_musique(id)
	if f.is_empty():
		push_warning("Sons : musique inconnue « %s »" % id)  # sans_traduction
		return
	var s := BanqueSons.flux(String(f["fichier"]), bool(f.get("boucle", false)))
	if s == null:
		return
	_musique.stream = s
	_musique.bus = BanqueSons.bus("Musique")  # sans_traduction
	_musique.volume_db = -60.0
	_musique.play()
	_fondre(_musique, float(f.get("volume_db", 0.0)), fondu)
	_musique_id = id


func arreter_musique(fondu := FONDU_MUSIQUE) -> void:
	_fondre(_musique, -80.0, fondu, true)
	_musique_id = ""


## Volume d'un bus, de 0 à 1 (au carré : un curseur à mi-course sonne à
## mi-course, −12 dB, comme dans TheBestFan).
func regler_volume(bus: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return
	v = clampf(v, 0.0, 1.0)
	AudioServer.set_bus_mute(i, v <= 0.001)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v * v, 0.0001)))


func volume(bus: String) -> float:
	var i := AudioServer.get_bus_index(bus)
	if i < 0:
		return 0.0
	if AudioServer.is_bus_mute(i):
		return 0.0
	return sqrt(db_to_linear(AudioServer.get_bus_volume_db(i)))


## Le mode calme : tout se tait d'un coup (le joueur, un stade réel autour).
func calme(oui: bool) -> void:
	AudioServer.set_bus_mute(0, oui)


func _fondre(p: AudioStreamPlayer, db: float, duree: float, arreter_apres := false) -> void:
	if not is_inside_tree():
		duree = 0.0
	if _tweens.has(p) and _tweens[p] is Tween and (_tweens[p] as Tween).is_valid():
		(_tweens[p] as Tween).kill()
	if duree <= 0.0:
		p.volume_db = db
		if arreter_apres:
			p.stop()
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", db, duree).set_trans(Tween.TRANS_SINE)
	if arreter_apres:
		tw.tween_callback(p.stop)
	_tweens[p] = tw
