extends Node
## Classement en ligne (autoload « EnLigne »).
##
## - envoie au serveur, toutes les 90 s, les points de popularité en attente
##   (Game.supporters.a_envoyer) ;
## - relit toutes les 5 min les points de toutes les équipes (equipes.json) ;
## - relit les meilleurs fans quand l'écran Classement le demande.
## Règles et format : scripts/jeu/classement_fans.gd. Sans réseau, rien ne bloque :
## la file attend et les écrans gardent les supporters simulés.
## L'identité (id public, clé secrète, pseudo) est dans user://classement.json,
## à part de la sauvegarde pour survivre à « Recommencer ».

signal mis_a_jour

const CHEMIN := "user://classement.json"
const PERIODE_ENVOI := 90.0
const PERIODE_EQUIPES := 300.0

var identite: Dictionary = ClassementFans.vide()
## equipes.json : {cle: {p, s, f}}, vide tant que le serveur n'a pas répondu.
var equipes: Dictionary = {}
var semaine := ""
## Meilleurs fans par période ("semaine", "total") : liste du serveur.
var fans: Dictionary = {}
## Ton rang et tes points d'après le serveur (vide avant le premier échange).
var moi: Dictionary = {}
var joignable := false     # dernier échange réussi
var desactive := false     # tests (--hors-ligne)

var _envoi_en_cours := false
## Adresse du serveur ; « -- --classement-url=http://localhost:8787/classement/ » pour un Worker de test.
var url := ClassementFans.URL


func _ready() -> void:
	_charger()
	desactive = OS.has_feature("hors_ligne") or "--hors-ligne" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--classement-url="):
			url = a.trim_prefix("--classement-url=")
			desactive = false
	if desactive:
		return
	var te := Timer.new()
	te.wait_time = PERIODE_ENVOI
	te.autostart = true
	te.timeout.connect(envoyer)
	add_child(te)
	var tq := Timer.new()
	tq.wait_time = PERIODE_EQUIPES
	tq.autostart = true
	tq.timeout.connect(rafraichir_equipes)
	add_child(tq)
	rafraichir_equipes()
	# Premier envoi peu après le lancement (le temps que la sauvegarde soit chargée).
	get_tree().create_timer(8.0).timeout.connect(envoyer)


func a_des_donnees() -> bool:
	return joignable or not equipes.is_empty()


func pseudo() -> String:
	return ClassementFans.pseudo_texte(identite["pseudo"])


## Points des autres supporters pour l'écran Mes équipes (vide = pas de données).
func communaute() -> Dictionary:
	if equipes.is_empty():
		return {}
	return ClassementFans.communaute(equipes, Game.supporters.get("envoye", {}))


func changer_pseudo(nom: int, qualite: int, nombre: int) -> void:
	identite["pseudo"] = [clampi(nom, 0, ClassementFans.NOMS.size() - 1),
		clampi(qualite, 0, ClassementFans.QUALITES.size() - 1), clampi(nombre, 0, 99)]
	_sauver()
	_forcer_envoi()


func changer_visible(v: bool) -> void:
	identite["visible"] = v
	_sauver()
	_forcer_envoi()


## Pseudo ou visibilité changés : un envoi (même sans points) met le serveur à jour.
func _forcer_envoi() -> void:
	if desactive:
		return
	envoyer(true)
	fans.clear()


# ------------------------------------------------------------------ réseau

func envoyer(meme_vide := false) -> void:
	if desactive or _envoi_en_cours:
		return
	var env := ClassementFans.preparer_envoi(Game.supporters, identite)
	if env["n"] == 0 and not meme_vide and not moi.is_empty():
		return
	_envoi_en_cours = true
	_requete("envoi", func(code: int, d: Variant):
		_envoi_en_cours = false
		if code == 200 and d is Dictionary and d.get("ok", false):
			ClassementFans.appliquer_reponse(Game.supporters, int(env["n"]), d.get("acceptes", {}))
			Game.sauver()
			if d.get("moi") is Dictionary:
				moi = d["moi"]
			mis_a_jour.emit()
		elif code == 400:
			# Envoi refusé en bloc (ancienne version du jeu ?) : on ne le renvoie pas en boucle.
			ClassementFans.appliquer_reponse(Game.supporters, int(env["n"]), {})
			Game.sauver()
		elif code == 403:
			push_warning("Classement : clé refusée, nouvelle identité")
			var p: Array = identite["pseudo"]
			identite = ClassementFans.identite_neuve(_rng())
			identite["pseudo"] = p
			_sauver()
	, env["corps"])


func rafraichir_equipes() -> void:
	if desactive:
		return
	_requete("equipes.json", func(code: int, d: Variant):
		if code == 200 and d is Dictionary and d.get("equipes") is Dictionary:
			equipes = d["equipes"]
			semaine = str(d.get("semaine", ""))
			mis_a_jour.emit())


func rafraichir_fans(periode: String) -> void:
	if desactive:
		return
	_requete("fans.json?periode=" + periode, func(code: int, d: Variant):
		if code == 200 and d is Dictionary and d.get("fans") is Array:
			fans[periode] = d["fans"]
			mis_a_jour.emit())
	if moi.is_empty() and identite_connue():
		_requete("fan?id=" + str(identite["id"]), func(code: int, d: Variant):
			if code == 200 and d is Dictionary:
				moi = d
				mis_a_jour.emit())


func identite_connue() -> bool:
	return ClassementFans.identite_valide(identite)


## Pour les tests : données comme si le serveur avait répondu.
func injecter(eq: Dictionary, f: Dictionary, m: Dictionary) -> void:
	equipes = eq
	fans = f
	moi = m
	joignable = true
	mis_a_jour.emit()


func _requete(chemin: String, rappel: Callable, corps: Variant = null) -> void:
	var r := HTTPRequest.new()
	r.timeout = 20.0
	add_child(r)
	r.request_completed.connect(func(res: int, code: int, _h: PackedStringArray, octets: PackedByteArray):
		r.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS:
			joignable = false
			rappel.call(0, null)
			return
		joignable = true
		rappel.call(code, JSON.parse_string(octets.get_string_from_utf8())))
	var err: int
	if corps == null:
		err = r.request(url + chemin, ["Accept: application/json"])
	else:
		err = r.request(url + chemin, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(corps))
	if err != OK:
		r.queue_free()
		rappel.call(0, null)


# ------------------------------------------------------------------ fichier

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng


func _charger() -> void:
	if FileAccess.file_exists(CHEMIN):
		var f := FileAccess.open(CHEMIN, FileAccess.READ)
		identite = ClassementFans.reparer(JSON.parse_string(f.get_as_text()))
	if not identite_connue():
		identite = ClassementFans.identite_neuve(_rng())
		_sauver()


func _sauver() -> void:
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(identite, "\t"))
