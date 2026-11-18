extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_souvenirs.gd
## Vérifie la boutique souvenirs et la vitrine du club : prix sur place et par
## correspondance, achat possible seulement pour un stade tamponné, une seule
## fois par souvenir, Jetons dépensés, séries et primes de la vitrine.

var _echecs := 0


func _init() -> void:
	await process_frame
	_tester_regles()
	_tester_jeu()
	_tester_billets()
	print("Tests souvenirs : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _par_id(series: Array, id: String) -> Dictionary:
	for s in series:
		if s["id"] == id:
			return s
	return {}


func _tester_regles() -> void:
	var c := Collection.vide()
	var tampons := {"stade:1": {"nom": "Stade Un"}}
	_verifier(Souvenirs.prix("fanion", true) == 15 and Souvenirs.prix("maquette", true) == 120, "prix de la boutique")
	_verifier(Souvenirs.prix("fanion", false) == 25 and Souvenirs.prix("maquette", false) == 180, "par correspondance ×1,5 arrondi à 5")
	_verifier(not Souvenirs.achetable(c, tampons, "stade:2", "fanion"), "stade pas tamponné : pas de boutique")
	_verifier(not Souvenirs.achetable(c, tampons, "stade:1", "inconnu"), "souvenir inconnu")
	_verifier(Souvenirs.achetable(c, tampons, "stade:1", "fanion"), "fanion achetable")
	Souvenirs.ajouter(c, "stade:1", "fanion", "2026-11-18")
	_verifier(not Souvenirs.achetable(c, tampons, "stade:1", "fanion") and Souvenirs.nombre(c) == 1, "un seul fanion par stade")
	var s := Souvenirs.series(c, tampons)
	_verifier(_par_id(s, "vitrine:stade:1").get("fait") == 1 and _par_id(s, "souvenirs:5").get("fait") == 1, "séries de la vitrine")
	for t in Souvenirs.ids():
		Souvenirs.ajouter(c, "stade:1", t, "2026-11-18")
	s = Souvenirs.series(c, tampons)
	_verifier(Souvenirs.stade_complet(c, "stade:1") and _par_id(s, "vitrine:stade:1").get("complete"), "stade complet")
	_verifier(_par_id(s, "souvenirs:5").get("complete") and not _par_id(s, "souvenirs:15").get("complete"), "palier de 5 souvenirs")
	_verifier(Collection.reparer({"fanzzy": {}}).has("souvenirs"), "vieille sauvegarde réparée")


func _tester_jeu() -> void:
	var Game: Node = root.get_node("/root/Game")
	Game.tampons = {"stade:42": {"nom": "Stade Test", "club": "Club Test"}}
	Game.collection = Collection.vide()
	Game.stade_du_jour = {}
	Game.jetons = 100
	_verifier(Game.prix_souvenir("stade:42", "ballon") == 60, "pas au stade : par correspondance")
	Game.noter_arrivee_stade("stade:42")
	_verifier(Game.au_stade("stade:42") and Game.prix_souvenir("stade:42", "ballon") == 40, "au stade : prix boutique")
	_verifier(Game.acheter_souvenir("stade:42", "ballon") and Game.jetons == 60, "achat : 40 Jetons dépensés")
	_verifier(not Game.acheter_souvenir("stade:42", "ballon") and Game.jetons == 60, "pas deux fois le même")
	_verifier(not Game.acheter_souvenir("stade:42", "maquette") and Game.jetons == 60, "pas assez de Jetons : rien ne change")
	_verifier(not Game.acheter_souvenir("stade:7", "fanion"), "stade jamais visité")
	Game.stade_du_jour = {"cle": "stade:42", "jour": "2000-01-01"}
	_verifier(not Game.au_stade("stade:42"), "le lendemain, plus sur place")
	Game.jetons = 1000
	for t in Souvenirs.ids():
		Game.acheter_souvenir("stade:42", t)
	var avant: int = Game.jetons
	_verifier(Game.reclamer_prime("vitrine:stade:42") == Souvenirs.PRIME_STADE_COMPLET and Game.jetons == avant + Souvenirs.PRIME_STADE_COMPLET, "prime du stade complet")
	_verifier(Game.reclamer_prime("vitrine:stade:42") == 0, "prime une seule fois")


## Billets selon l'importance du match (même fichier : les deux nouveautés de Jetons).
func _tester_billets() -> void:
	_verifier(Evenements.facteur_billet({}, "pays") == 1.0, "championnat : billet normal")
	_verifier(is_equal_approx(Evenements.facteur_billet({"type": "derby"}, "pays"), 2.4), "derby ×2,4")
	_verifier(Evenements.facteur_billet({"type": "finale"}, "pays") == 6.0 and Evenements.facteur_billet({"type": "finale"}, "monde") == 12.0, "finales ×6 à ×12")
	_verifier(is_equal_approx(Evenements.facteur_billet({}, "continent"), 1.6), "coupe continentale ×1,6")
	_verifier(is_equal_approx(Evenements.facteur_billet({"type": "quart"}, "monde"), 2.4), "le facteur le plus fort compte")
	var Game: Node = root.get_node("/root/Game")
	_verifier(Game.billet("stade") == 25 and Game.billet("pub") == 4 and Game.billet("maison") == 0, "billets sans match")
	var m := {"id": "t:1", "competition": {"id": "inconnue"}, "home": {"id": "af:1"}, "away": {"id": "af:2"}}
	_verifier(Game.billet("stade", m) == 25, "compétition inconnue : prix normal (%d)" % Game.billet("stade", m))
