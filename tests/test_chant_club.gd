extends SceneTree
## Tests sans écran du créateur de chants (ChantClub) :
##   godot --headless --path . --script tests/test_chant_club.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_catalogue()
	_tester_defaut()
	_tester_erreurs()
	_tester_reparer()
	_tester_fiche()
	_tester_programme()
	_tester_paroles()
	print("Tests chant du club : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_catalogue() -> void:
	var ids := {}
	for mo in ChantClub.morceaux():
		var id := String(mo["id"])
		_verifier(not ids.has(id), "morceau en double : %s" % id)
		ids[id] = true
		var p: Dictionary = mo["pistes"]
		_verifier(p.has("J") and ChantClub.appuis(id).size() > 0, "%s : au moins un clap" % id)
		for v in p:
			_verifier(String(v) in ["T", "S", "H", "G", "J"], "%s : voix inconnue %s" % [id, v])
			_verifier(String(p[v]).length() == ChantClub.PAS, "%s/%s : %d pas" % [id, v, ChantClub.PAS])
			if v != "J":
				_verifier(BanqueSons.son_de_voix(String(v)) != "", "%s : voix %s sans son" % [id, v])
		_verifier(int(mo["difficulte"]) >= 1 and int(mo["difficulte"]) <= 3, "%s : difficulté 1 à 3" % id)
	_verifier(ids.size() >= 8, "assez de morceaux")
	var ouverts := ChantClub.morceaux().filter(func(x): return ChantClub.debloque(x, 1))
	_verifier(ouverts.size() >= 3, "au moins 3 morceaux au niveau 1")
	for pa in ChantClub.paroles():
		_verifier(String(pa["texte"]).length() <= 32, "parole courte : %s" % pa["texte"])
	for t in ChantClub.tempos():
		_verifier(float(t["bpm"]) >= 90 and float(t["bpm"]) <= 130, "tempo raisonnable")


func _tester_defaut() -> void:
	var c := ChantClub.par_defaut()
	_verifier(ChantClub.erreurs(c, 1).is_empty(), "le chant par défaut est valide au niveau 1 (%s)" % str(ChantClub.erreurs(c, 1)))
	_verifier(ChantClub.etoiles(c) == 1, "chant par défaut : 1 étoile (%d)" % ChantClub.etoiles(c))
	_verifier(is_equal_approx(ChantClub.duree(c), 4 * 4 * 60.0 / 112.0), "durée d'un couplet")


func _tester_erreurs() -> void:
	var c := ChantClub.par_defaut()
	c["nom"] = "  "
	_verifier(not ChantClub.erreurs(c, 1).is_empty(), "nom vide refusé")
	c = ChantClub.par_defaut()
	c["mesures"].resize(3)
	_verifier(not ChantClub.erreurs(c, 1).is_empty(), "moins de 4 mesures refusé")
	c = ChantClub.par_defaut()
	for i in 6:
		c["mesures"].append({"morceau": "marche", "parole": ""})
	_verifier(not ChantClub.erreurs(c, 9).is_empty(), "plus de 8 mesures refusé")
	c = ChantClub.par_defaut()
	c["mesures"][0]["morceau"] = "grand_final"
	_verifier(not ChantClub.erreurs(c, 1).is_empty(), "morceau verrouillé refusé au niveau 1")
	_verifier(ChantClub.erreurs(c, 6).is_empty(), "morceau ouvert au niveau 6")
	c = ChantClub.par_defaut()
	c["tempo"] = "endiable"
	_verifier(not ChantClub.erreurs(c, 1).is_empty(), "tempo verrouillé refusé")
	_verifier(ChantClub.erreurs(c, 3).is_empty(), "tempo endiablé ouvert au niveau 3")
	_verifier(ChantClub.etoiles(c) > 1, "plus vite, plus dur")
	c = ChantClub.par_defaut()
	c["mesures"][1]["parole"] = "nuit_entiere"
	_verifier(not ChantClub.erreurs(c, 1).is_empty(), "parole verrouillée refusée")
	c["mesures"][1]["parole"] = ""
	_verifier(ChantClub.erreurs(c, 1).is_empty(), "mesure sans parole acceptée")
	var dur := {"nom": "Dur", "tempo": "endiable", "mesures": []}
	for i in 8:
		dur["mesures"].append({"morceau": "cascade", "parole": ""})
	_verifier(ChantClub.etoiles(dur) == 5, "8 cascades endiablées : 5 étoiles (%d)" % ChantClub.etoiles(dur))


func _tester_reparer() -> void:
	_verifier(ChantClub.reparer(null).is_empty(), "rien -> pas de chant")
	_verifier(ChantClub.reparer({"mesures": "x"}).is_empty(), "mauvaise forme -> pas de chant")
	var c := ChantClub.par_defaut()
	c["mesures"].append({"morceau": "inconnu", "parole": "allez_club"})
	c["mesures"][0]["parole"] = "inconnue"
	c["tempo"] = "turbo"
	var r := ChantClub.reparer(c)
	_verifier(r["mesures"].size() == 4, "morceau inconnu retiré")
	_verifier(r["mesures"][0]["parole"] == "", "parole inconnue effacée")
	_verifier(r["tempo"] == "entrainant", "tempo inconnu remplacé")
	var club := FanClub.reparer({"cree": true})
	_verifier(club.has("chant") and club["chant"].is_empty(), "ancienne sauvegarde : pas de chant")
	club = FanClub.reparer({"cree": true, "chant": ChantClub.par_defaut()})
	_verifier(club["chant"]["mesures"].size() == 4, "chant gardé dans la sauvegarde")


func _tester_fiche() -> void:
	var c := ChantClub.par_defaut()
	var f := ChantClub.vers_fiche(c, true)
	_verifier(int(f["temps_par_mesure"]) == 16 and int(f["pas_par_temps"]) == 2, "un couplet = une grande mesure")
	_verifier(String(f["pistes"]["C"]) == String(f["pistes"]["J"]), "la tribune claque les appuis à l'écoute")
	_verifier(String(f["pistes"]["T"]).length() == 32, "tambour sur tout le couplet")
	_verifier(not ChantClub.vers_fiche(c, false)["pistes"].has("C"), "sans claps en duel")
	var r := Rythme.depuis_chant(f)
	_verifier(r.notes_joueur(1).size() == ChantClub.nb_appuis(c), "Rythme lit les appuis du chant (%d)" % r.notes_joueur(1).size())


func _tester_programme() -> void:
	var c := ChantClub.par_defaut()
	var p := ChantClub.programme(c, "Les Ultras")
	_verifier(p.size() == 4, "4 mesures au programme")
	_verifier(p[0]["appuis"] == [0, 2, 4, 6], "quatre temps : claps sur les temps")
	_verifier(p[0]["mots"].size() == p[0]["appuis"].size(), "un mot par clap")
	_verifier(p[0]["texte"] == "Allez Les Ultras !", "nom du club dans la parole (%s)" % p[0]["texte"])
	var tambour: Array = p[0]["frappes"].filter(func(f): return f["voix"] == "T")
	_verifier(tambour.size() == 4, "4 coups de tambour")


func _tester_paroles() -> void:
	_verifier(ChantClub.nom_crie("Les Supporters du Grand Nord") == FanClub.sigle("Les Supporters du Grand Nord"), "nom long -> sigle")
	_verifier(ChantClub.mots_sur_appuis("Allez UC !", 4) == ["Allez", "UC", "!", ""], "mots répartis")
	_verifier(ChantClub.mots_sur_appuis("Un, deux, trois, on y croit !", 2) == ["Un,", "deux, trois, on y croit !"], "mots regroupés")
	_verifier(ChantClub.mots_sur_appuis("", 2) == ["", ""], "sans parole")
