extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_deplacement.gd
## Déplacements du fan club : transports, prix, cagnotte, ferveur, événements, bilan.

var _echecs := 0


func _init() -> void:
	_tester_transports()
	_tester_prix()
	_tester_ferveur()
	_tester_evenements()
	_tester_choix()
	_tester_bilan()
	_tester_etape()
	_tester_contenu()
	print("Tests déplacements : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_transports() -> void:
	_verifier(Deplacement.transports(400.0) == ["car", "train"], "400 km : car et train, pas d'avion")
	_verifier(Deplacement.transports(1500.0) == ["car", "train", "avion"], "1 500 km : les trois")
	_verifier(Deplacement.transports(6000.0) == ["avion"], "6 000 km : avion seulement")
	_verifier(Deplacement.itineraires("avion") == ["direct"], "l'avion ne fait que du direct")
	_verifier(Deplacement.itineraires("car") == ["direct", "eco", "balade"], "trois itinéraires en car")
	_verifier(Deplacement.titre_itineraire("eco", "train") == "Trains régionaux", "titre selon le transport")


func _tester_prix() -> void:
	_verifier(Deplacement.cout(10.0, "car", "direct", 3) == 0, "sur place : gratuit")
	var car := Deplacement.cout(600.0, "car", "direct", 3)
	var train := Deplacement.cout(600.0, "train", "direct", 3)
	var eco := Deplacement.cout(600.0, "car", "eco", 3)
	var balade := Deplacement.cout(600.0, "car", "balade", 3)
	_verifier(eco < car and car < train, "éco < car < train (%d, %d, %d)" % [eco, car, train])
	_verifier(balade > car, "la balade coûte un peu plus que le direct")
	_verifier(Deplacement.cout(600.0, "car", "direct", 13) < car, "la cagnotte du club allège le prix")
	_verifier(is_equal_approx(Deplacement.reduction(3), 0.0) and is_equal_approx(Deplacement.reduction(30), Deplacement.REDUCTION_MAX), "réduction de 0 à 30 %")
	_verifier(Deplacement.cout(40.0, "car", "eco", 30) >= Deplacement.PRIX_MIN, "prix minimum")
	_verifier(Deplacement.cout_min(600.0, 3) == eco, "le prix « dès » est le moins cher")
	_verifier(Deplacement.cout_base(600.0) == 13 and Deplacement.cout_base(20000.0) == Deplacement.COUT_BASE_MAX, "barème de base (600 km : 13, plafond %d)" % Deplacement.COUT_BASE_MAX)
	_verifier(Deplacement.duree(600.0, "train", "direct") < Deplacement.duree(600.0, "car", "direct"), "le train est plus rapide")
	_verifier(Deplacement.duree(600.0, "car", "eco") > Deplacement.duree(600.0, "car", "direct"), "les petites routes sont plus longues")
	_verifier(Deplacement.duree_texte(45) == "45 min" and Deplacement.duree_texte(120) == "2 h" and Deplacement.duree_texte(95) == "1 h 35", "durées lisibles")


func _tester_ferveur() -> void:
	var base := Deplacement.ferveur_depart("train", ["voix", "tifo", "pyro"], false)
	_verifier(base == Deplacement.FERVEUR_BASE + 5 + 9, "ferveur de base (%d)" % base)
	_verifier(Deplacement.ferveur_depart("car", ["voix", "tifo", "pyro"], false) > base, "le car met plus d'ambiance")
	_verifier(Deplacement.ferveur_depart("train", ["voix", "tifo", "pyro"], true) == base + Deplacement.FERVEUR_EXTERIEUR, "bonus à l'extérieur")
	_verifier(Deplacement.ferveur_depart("train", ["depl", "tifo", "pyro"], false) == base + Deplacement.FERVEUR_PAR_DEPL, "bonus famille Déplacement")
	var gros: Array = []
	for i in 40:
		gros.append("depl")
	_verifier(Deplacement.ferveur_depart("car", gros, true) <= 100, "ferveur plafonnée à 100")


func _tester_evenements() -> void:
	for t in Deplacement.ORDRE_TRANSPORTS:
		for i in Deplacement.itineraires(t):
			var ev := Deplacement.tirer(42, t, i, "Lyon")
			_verifier(ev.size() == Deplacement.nb_evenements(t, i), "%s/%s : %d événements" % [t, i, ev.size()])
			var ids := {}
			for e in ev:
				_verifier(e["id"] == "etape" or t in e["pour"], "%s : événement %s adapté au transport" % [t, e["id"]])
				_verifier(not ids.has(e["id"]), "%s/%s : pas de doublon" % [t, i])
				ids[e["id"]] = true
			_verifier((i == "balade") == ids.has("etape"), "%s/%s : étape seulement en balade" % [t, i])
	_verifier(Deplacement.tirer(7, "car", "eco") == Deplacement.tirer(7, "car", "eco"), "même graine, mêmes événements")
	var differents := false
	for g in 10:
		if Deplacement.tirer(g, "car", "direct") != Deplacement.tirer(g + 100, "car", "direct"):
			differents = true
	_verifier(differents, "les graines changent les événements")
	var e_etape: Dictionary = Deplacement.tirer(1, "car", "balade", "Lyon").filter(func(e): return e["id"] == "etape")[0]
	_verifier(Deplacement.titre_evenement(e_etape) == "Étape : Lyon", "titre de l'étape")


func _tester_choix() -> void:
	var c := {"texte": "x", "famille": "perc", "ferveur": 10}
	_verifier(not Deplacement.choix_possible(c, ["voix"]), "choix bloqué sans la famille")
	_verifier(Deplacement.choix_possible(c, ["voix", "perc"]), "choix possible avec la famille")
	var pari := {"texte": "x", "chance": 0.5, "ferveur": 6, "retard": 5, "res": "ok", "rate": {"ferveur": -4, "retard": 40, "res": "raté"}}
	var ok := Deplacement.resultat(pari, 0.2)
	var rate := Deplacement.resultat(pari, 0.8)
	_verifier(ok["reussi"] and ok["ferveur"] == 6 and ok["retard"] == 5, "pari réussi")
	_verifier(not rate["reussi"] and rate["ferveur"] == -4 and rate["retard"] == 40 and rate["res"] == "raté", "pari raté")
	var etat := Deplacement.nouvel_etat(95)
	Deplacement.appliquer(etat, {"id": "a", "titre": "A"}, {"ferveur": 20, "jetons": 5, "retard": 10, "res": ""})
	_verifier(etat["ferveur"] == 100 and etat["jetons"] == 5 and etat["retard"] == 10 and etat["journal"].size() == 1, "application d'un choix")
	Deplacement.appliquer(etat, {"id": "a", "titre": "A"}, {"ferveur": -150, "jetons": 0, "retard": 0, "res": ""})
	_verifier(etat["ferveur"] == 0, "ferveur jamais négative")


func _tester_bilan() -> void:
	var e := Deplacement.nouvel_etat(80)
	e["retard"] = 30
	e["jetons"] = 10
	var b := Deplacement.bilan(e)
	_verifier(b["a_l_heure"] and b["ferveur"] == 80, "à l'heure : pas de malus")
	_verifier(b["jetons"] == 30 and b["xp_pass"] == 80, "prime : jetons des événements + ferveur / 4")
	_verifier(is_equal_approx(b["mult"], 1.16), "bonus duel ×1,16 (%s)" % str(b["mult"]))
	e["retard"] = Deplacement.MARGE_RETARD + 5
	b = Deplacement.bilan(e)
	_verifier(not b["a_l_heure"] and b["ferveur"] == 80 - Deplacement.MALUS_RETARD, "en retard : malus de ferveur")
	_verifier(is_equal_approx(Deplacement.multiplicateur(0), 1.0) and is_equal_approx(Deplacement.multiplicateur(100), 1.2), "bonus de ×1 à ×1,2")


func _tester_etape() -> void:
	var a := Vector2(2.35, 48.86)   # Paris
	var b := Vector2(5.37, 43.3)    # Marseille
	var cands := [
		{"nom": "Loin", "pos": Vector2(20.0, 50.0)},
		{"nom": "Départ", "pos": Vector2(2.4, 48.7)},
		{"nom": "Milieu", "pos": Vector2(4.85, 45.76)},
		{"nom": "Pile sur la route", "pos": Vector2(3.86, 46.08)},
	]
	_verifier(Deplacement.etape(a, b, cands).get("nom", "") == "Milieu", "étape au milieu, un peu à côté de la route")
	_verifier(Deplacement.etape(a, b, [cands[0]]).is_empty(), "pas d'étape trop loin")
	var tr_eco := Deplacement.trace(a, b, "eco")
	_verifier(tr_eco.size() == 4 and tr_eco[0] == a and tr_eco[3] == b, "trace éco : départ, 2 crochets, arrivée")
	_verifier(Deplacement.trace(a, b, "balade", Vector2(4.85, 45.76)).size() == 3, "trace balade passe par l'étape")


## Chaque événement a au moins deux choix, dont un toujours possible, et des familles connues.
func _tester_contenu() -> void:
	var familles := ["voix", "perc", "tifo", "fide", "pyro", "depl"]
	for e in Deplacement.EVENEMENTS + [Deplacement.EVENEMENT_ETAPE]:
		_verifier(e["choix"].size() >= 2 and e["choix"].size() <= 3, "%s : 2 ou 3 choix" % e["id"])
		var libre := false
		for c in e["choix"]:
			if not c.has("famille"):
				libre = true
			else:
				_verifier(c["famille"] in familles, "%s : famille connue" % e["id"])
			_verifier(not c.has("chance") or c.has("rate"), "%s : un pari a son échec" % e["id"])
			_verifier(int(c.get("jetons", 0)) >= 0, "%s : jamais de Jetons perdus" % e["id"])
		_verifier(libre, "%s : un choix possible pour tous les convois" % e["id"])
	for t in Deplacement.ORDRE_TRANSPORTS:
		for i in Deplacement.itineraires(t):
			var pool := Deplacement.EVENEMENTS.filter(func(e): return t in e["pour"] and (not e.has("itin") or i in e["itin"]))
			_verifier(pool.size() >= Deplacement.nb_evenements(t, i), "%s/%s : assez d'événements (%d)" % [t, i, pool.size()])
