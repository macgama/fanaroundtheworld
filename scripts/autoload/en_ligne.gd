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
## Tournoi des fan clubs : classement du tournoi en cours (top des clubs) et état des échanges.
var tournoi_classement: Dictionary = {}
var _tournoi_en_cours := false
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
	te.timeout.connect(synchroniser_tournoi)
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


func _requete(chemin: String, rappel: Callable, corps: Variant = null, base := "") -> void:
	if base == "":
		base = url
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
		err = r.request(base + chemin, ["Accept: application/json"])
	else:
		err = r.request(base + chemin, ["Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(corps))
	if err != OK:
		r.queue_free()
		rappel.call(0, null)


# ------------------------------------------------------------------ tournoi des fan clubs
## Routes /tournoi/… du même Worker (src/tournoi.js). Le fan doit exister côté
## classement (premier envoi fait 8 s après le lancement) : sinon 403 « fan_inconnu »
## et on réessaie au tour suivant. Ordre : inscription, résultats en attente,
## tirage du prochain adversaire, puis rang du club.

func _url_tournoi() -> String:
	return url.replace("/classement/", "/tournoi/")


func _requete_tournoi(chemin: String, rappel: Callable, corps: Variant = null) -> void:
	_requete(chemin, rappel, corps, _url_tournoi())


func _corps_tournoi(extra: Dictionary) -> Dictionary:
	var c := {"v": 1, "id": identite["id"], "cle": identite["cle"], "tournoi": Game.tournoi["id"]}
	c.merge(extra, true)
	return c


func synchroniser_tournoi() -> void:
	if desactive or _tournoi_en_cours:
		return
	var f := Game.actualiser_tournoi()
	var t: Dictionary = Game.tournoi
	# Tournoi fini pas encore réclamé : on relit le rang final avant la récompense.
	var ar: Dictionary = t["a_reclamer"]
	if not ar.is_empty() and not bool(ar.get("verifie", false)):
		_tournoi_en_cours = true
		_requete_tournoi("club?id=%s&tournoi=%s" % [identite["id"], ar["id"]], func(code: int, d: Variant):
			_tournoi_en_cours = false
			if code == 200 and d is Dictionary:
				ar["rang"] = int(d.get("rang", 0))
				ar["clubs"] = int(d.get("clubs", 0))
				ar["points"] = maxi(int(ar["points"]), int(d.get("points", 0)))
				ar["verifie"] = true
				Game.sauver()
				mis_a_jour.emit()
				synchroniser_tournoi()
			elif code == 404:
				ar["verifie"] = true  # inconnu du serveur : récompense des paliers seulement
				Game.sauver())
		return
	if f["etat"] != "actif" or not bool(t["inscrit"]):
		return
	_tournoi_en_cours = true
	if not bool(t["inscrit_serveur"]):
		_requete_tournoi("inscription", func(code: int, d: Variant):
			_tournoi_en_cours = false
			if code == 200 and d is Dictionary and d.get("ok", false):
				t["inscrit_serveur"] = true
				_lire_club(d.get("moi"))
				Game.sauver()
				synchroniser_tournoi()
			elif code == 403 and d is Dictionary and d.get("erreur", "") == "fan_inconnu":
				envoyer(true)  # le serveur ne connaît pas encore ce fan
		, _corps_tournoi({"nom": t["nom"], "couleurs": t["couleurs"], "niveau": Game.niveau()}))
		return
	var file := Tournoi.a_envoyer(t)
	if not file.is_empty():
		var d0: Dictionary = file[0]
		_requete_tournoi("resultat", func(code: int, d: Variant):
			_tournoi_en_cours = false
			if code == 200 or code == 400 or code == 409:
				# accepté, ou refusé pour de bon (hors règles, déjà compté) : on ne le renvoie pas
				d0["envoye"] = true
				if code == 200 and d is Dictionary:
					_lire_club(d.get("moi"))
				Game.sauver()
				synchroniser_tournoi()
		, _corps_tournoi({"adversaire": d0["adv"], "match": d0["match"], "gagne": d0["gagne"],
			"stade": d0["stade"], "evenement": d0["evenement"], "t": int(d0["t"])}))
		return
	if (t["adversaire"] as Dictionary).is_empty() and (t["duels"] as Array).size() < Tournoi.DUELS_MAX:
		_requete_tournoi("adversaire", func(code: int, d: Variant):
			_tournoi_en_cours = false
			if code == 200 and d is Dictionary:
				var a: Variant = d.get("adversaire")
				if a is Dictionary and not Tournoi.deja_affronte(t, str(a.get("id", ""))):
					t["adversaire"] = {"id": str(a["id"]), "nom": Tournoi.nom_valide(a.get("nom")),
						"couleurs": a.get("couleurs", [0, 7]), "niveau": int(a.get("niveau", 1)), "bot": false}
				else:
					t["adversaire"] = Tournoi.prochain_bot(t)  # aucun club libre : un club du jeu
				Game.sauver()
				mis_a_jour.emit()
		, _corps_tournoi({"niveau": Game.niveau()}))
		return
	_requete_tournoi("club?id=%s&tournoi=%s" % [identite["id"], t["id"]], func(code: int, d: Variant):
		_tournoi_en_cours = false
		if code == 200:
			_lire_club(d)
			Game.sauver())


func _lire_club(m: Variant) -> void:
	if not m is Dictionary:
		return
	var t: Dictionary = Game.tournoi
	t["defense"] = int(m.get("defense", t["defense"]))
	t["rang"] = int(m.get("rang", 0))
	t["clubs"] = int(m.get("clubs", 0))
	mis_a_jour.emit()


func rafraichir_tournoi() -> void:
	if desactive:
		return
	synchroniser_tournoi()
	_requete_tournoi("classement.json?tournoi=" + str(Tournoi.fenetre(Game.maintenant())["id"]), func(code: int, d: Variant):
		if code == 200 and d is Dictionary and d.get("clubs") is Array:
			tournoi_classement = d
			mis_a_jour.emit())


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
