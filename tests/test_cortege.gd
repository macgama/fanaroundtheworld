extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_cortege.gd
## Vérifie les règles du kop (Kop), des rencontres de FANZZY (Rencontres) et
## du cortège jusqu'au stade (Cortege).

const T0 := 1_800_000_000

var _echecs := 0


func _init() -> void:
	_tester_kop()
	_tester_rencontres()
	_tester_cortege()
	print("Tests kop et cortège : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_kop() -> void:
	var c := FanClub.nouveau(["A", "B", "C"], "#1e6bff", "#ffffff", T0)
	_verifier(Kop.valeur(c) == Kop.DEPART, "kop de départ")
	_verifier(Kop.ajouter(c, 30) == 30 and Kop.valeur(c) == Kop.DEPART + 30, "ajout au kop")
	_verifier(Kop.ajouter(c, -50) == 0 and Kop.valeur(c) == Kop.DEPART + 30, "le kop ne baisse jamais")
	_verifier(Kop.renommee(0) == "Petit groupe" and Kop.renommee(50) == "Bande de potes", "renommée des petits kops")
	_verifier(Kop.renommee(9999) == "Virage plein" and Kop.renommee(10000) == "Légende du virage", "renommée des grands kops")
	_verifier(Kop.bonus_jauge(0) == 0 and Kop.bonus_jauge(10000) == 8, "bonus de jauge par palier")
	_verifier(Kop.prochain(100) == [200, "Club de quartier"] and Kop.prochain(20000).is_empty(), "prochain palier")
	_verifier(Kop.facteur(1000) == 2.0, "bouche-à-oreille")
	_verifier(Kop.recrues(5.0, 0) == 5 and Kop.recrues(5.0, 1000) == 10 and Kop.recrues(0.0, 5000) == 0, "recrues avec bouche-à-oreille")
	# un duel gagné au stade rapporte plus qu'un duel perdu à la maison ; un match rejoué 3 fois, rien
	_verifier(Kop.base_duel(true, 1.0, "stade") > Kop.base_duel(false, 1.0, "maison"), "duel gagné au stade")
	_verifier(Kop.base_duel(true, 0.0, "stade") == 0.0, "match déjà joué 3 fois : pas de supporters")
	_verifier(Kop.base_deplacement(72) == 7.0, "déplacement : ferveur / 10")
	_verifier(is_equal_approx(Kop.remplissage(0), Kop.REMPLISSAGE_MIN) and Kop.remplissage(3000) == 1.0, "remplissage de la tribune")
	_verifier(Kop.remplissage(200) > Kop.remplissage(50), "la tribune se remplit avec le kop")
	_verifier(Kop.texte(12345) == "12 345" and Kop.texte(999) == "999", "milliers")


func _tester_rencontres() -> void:
	var fanzzy := [
		{"id": "V1", "famille": "voix"}, {"id": "P1", "famille": "perc"}, {"id": "T1", "famille": "tifo"},
		{"id": "F1", "famille": "fide", "rarete": "legendaire"}, {"id": "Y1", "famille": "pyro"}, {"id": "D1", "famille": "depl"},
		{"id": "PASS1", "famille": "voix", "pass": 10},
	]
	var c := FanClub.nouveau(["V1"], "#1e6bff", "#ffffff", T0)
	var cands := Rencontres.candidats(c, fanzzy)
	_verifier(cands.size() == 5, "candidats : pas les membres ni les recrues du PASS (%d)" % cands.size())
	# au cortège, les familles du lieu sortent plus souvent
	var vus := {}
	for i in 100:
		var z := Rencontres.tirer(c, fanzzy, "cortege", i / 100.0)
		vus[z["famille"]] = int(vus.get(z["famille"], 0)) + 1
	_verifier(int(vus.get("perc", 0)) > int(vus.get("tifo", 0)), "familles du lieu favorisées")
	_verifier(Rencontres.ajouter(c, "P1", "cortege", T0), "rencontre ajoutée")
	_verifier(not Rencontres.ajouter(c, "P1", "cortege", T0), "pas deux fois")
	_verifier(not Rencontres.ajouter(c, "V1", "stade", T0), "pas un membre")
	Rencontres.ajouter(c, "T1", "stade", T0)
	Rencontres.ajouter(c, "D1", "deplacement", T0)
	_verifier(not Rencontres.ajouter(c, "Y1", "stade", T0) and Rencontres.tirer(c, fanzzy, "stade", 0.5).is_empty(), "liste pleine")
	# défis selon la famille, un coup de plus pour un légendaire
	_verifier(Rencontres.defi("voix") == "rythme" and Rencontres.defi("tifo") == "memoire" and Rencontres.defi("pyro") == "precision", "défi par famille")
	_verifier(Rencontres.objectif({"famille": "fide"}) == [3, 5] and Rencontres.objectif(fanzzy[3]) == [4, 5], "objectif légendaire")
	_verifier(Rencontres.reussi({"famille": "voix"}, 6) and not Rencontres.reussi({"famille": "voix"}, 5), "réussite du rythme")
	# raté : il revient plus tard
	Rencontres.noter_echec(c, "T1", T0)
	_verifier(Rencontres.attente(c, "T1", T0 + 60) == Rencontres.ATTENTE_APRES_ECHEC - 60, "attente après un échec")
	_verifier(Rencontres.attente(c, "T1", T0 + Rencontres.ATTENTE_APRES_ECHEC) == 0, "on peut retenter")
	Rencontres.retirer(c, "T1")
	_verifier(not Rencontres.en_attente(c, "T1") and Rencontres.liste(c).size() == 2, "retrait")
	# sauvegarde abîmée : doublons, membres et FANZZY inconnus enlevés
	c["rencontres"] = [{"id": "P1"}, {"id": "P1"}, {"id": "V1"}, {"id": "ZZ"}, "n'importe quoi", {"id": "D1", "lieu": "deplacement"}]
	Rencontres.reparer(c, func(id): return id != "ZZ")
	_verifier(Rencontres.liste(c).size() == 2 and Rencontres.entree(c, "D1")["lieu"] == "deplacement", "réparation des rencontres")
	_verifier(Rencontres.sans_defi(fanzzy[6]) and not Rencontres.sans_defi(fanzzy[0]), "recrues du PASS sans défi")


func _tester_cortege() -> void:
	# départ
	_verifier(Cortege.lieu(true) == "exterieur" and Cortege.lieu(false) == "domicile", "lieu du cortège")
	_verifier(Cortege.ferveur_depart(3, 0) == Cortege.FERVEUR_BASE + 9, "ferveur de départ à domicile")
	_verifier(Cortege.ferveur_depart(12, 2) == Cortege.FERVEUR_BASE + Cortege.FERVEUR_MEMBRES_MAX + 4, "ferveur plafonnée par les membres + kop")
	_verifier(Cortege.ferveur_depart(3, 0, 77) == 77, "la ferveur du déplacement continue")
	# tirage stable, filtré par lieu, rencontre en plus
	var a := Cortege.tirer(42, "domicile")
	_verifier(a.size() == 3 and a == Cortege.tirer(42, "domicile"), "tirage stable de 3 arrêts")
	for g in 60:
		for e in Cortege.tirer(g, "exterieur"):
			_verifier(not e.has("pour") or "exterieur" in e["pour"], "arrêt « %s » hors de son lieu" % e["id"])
	var avec := 0
	for g in 200:
		var l := Cortege.tirer(g, "domicile", "Le Gamin")
		if l.size() == 4:
			avec += 1
			var r: Array = l.filter(func(e): return e["id"] == "rencontre")
			_verifier(r.size() == 1 and Cortege.texte_evenement(r[0]).contains("Le Gamin"), "arrêt rencontre nommé")
	_verifier(avec > 80 and avec < 160, "un FANZZY marche avec vous environ 6 fois sur 10 (%d / 200)" % avec)
	# tous les arrêts ont au moins un choix possible pour tout le monde, et des choix valides
	for e in Cortege.EVENEMENTS + [Cortege.EVENEMENT_RENCONTRE]:
		var libre := false
		for ch in e["choix"]:
			if Cortege.choix_possible(ch, []):
				libre = true
			if ch.has("famille"):
				_verifier(str(ch["famille"]) in Rencontres.DEFIS, "famille inconnue dans « %s »" % e["id"])
			_verifier(int(ch.get("recrues", 0)) >= 0, "recrues négatives dans « %s »" % e["id"])
		_verifier(libre, "« %s » : un choix sans FANZZY particulier" % e["id"])
	# choix, chance, application
	var ch_chance: Dictionary = Cortege.EVENEMENTS.filter(func(e): return e["id"] == "cafe")[0]["choix"][2]
	_verifier(Cortege.resultat(ch_chance, 0.1)["reussi"] and not Cortege.resultat(ch_chance, 0.9)["reussi"], "choix à la chance")
	var etat := Cortege.nouvel_etat(40)
	_verifier(Cortege.marge(etat) == Cortege.MINUTES - Cortege.MARCHE, "temps de marche compté")
	Cortege.appliquer(etat, {"id": "x"}, {"ferveur": 16, "recrues": 3, "minutes": 0, "chambre": true, "rencontre": false, "res": ""})
	Cortege.appliquer(etat, {"id": "y"}, {"ferveur": -2, "recrues": 0, "minutes": -5, "chambre": false, "rencontre": true, "res": ""})
	_verifier(etat["ferveur"] == 54 and etat["recrues"] == 3 and etat["chambre"] and etat["rencontre"], "effets des choix")
	_verifier(Cortege.marge(etat) == Cortege.MINUTES - Cortege.MARCHE + 5, "minutes gagnées")
	# rythme
	_verifier(Cortege.rythme(8, 0)["ferveur"] == Cortege.RYTHME_FERVEUR_MAX and Cortege.rythme(8, 0)["recrues"] == 4, "rythme parfait")
	_verifier(Cortege.rythme(2, 2)["ferveur"] == 3 and Cortege.rythme(0, 0)["ferveur"] == 0, "rythme moyen")
	# bilan à l'heure / en retard
	var b := Cortege.bilan(etat, 0)
	_verifier(b["a_l_heure"] and b["bonus"] == 5 and b["recrues"] == 3 and b["chambre"], "bilan à l'heure (%s)" % str(b))
	etat["minutes"] = Cortege.MINUTES + 10
	var r := Cortege.bilan(etat, 1000)
	_verifier(not r["a_l_heure"] and r["bonus"] == 0 and r["ferveur"] == 54 - Cortege.MALUS_RETARD, "bilan en retard")
	_verifier(r["recrues"] == 6, "recrues du cortège avec bouche-à-oreille")
	_verifier(Cortege.bonus_jauge(100) == 10 and Cortege.bonus_jauge(0) == 0, "bonus de jauge du cortège")
