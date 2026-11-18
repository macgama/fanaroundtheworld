extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_grand_tour.gd
## Vérifie le Grand Tour : étapes pas encore tamponnées, itinéraire au plus proche,
## prix, minimum 2 stades, tampons sans XP de PASS, un seul par jour, boutiques
## souvenirs au prix sur place dans chaque stade visité.

var _echecs := 0


func _init() -> void:
	await process_frame
	_tester_regles()
	_tester_jeu()
	print("Tests Grand Tour : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _clubs(n: int) -> Array:
	var r: Array = []
	for i in n:
		r.append({"id": "t%d" % (900 + i)})
	return r


func _tester_regles() -> void:
	# itinéraire glouton sur des points connus
	var c := [{"cle": "a", "pos": Vector2(10, 0)}, {"cle": "b", "pos": Vector2(1, 0)}, {"cle": "c", "pos": Vector2(5, 0)}]
	var it := GrandTour.itineraire(c, Vector2.ZERO, 3)
	_verifier(it.map(func(e): return e["cle"]) == ["b", "c", "a"], "au plus proche à chaque étape")
	_verifier(GrandTour.itineraire(c, Vector2.ZERO, 2).size() == 2, "nombre d'étapes")
	var p := GrandTour.prix(Vector2.ZERO, it, 3)
	var trajets := 0
	for km in GrandTour.troncons(Vector2.ZERO, it):
		trajets += Deplacement.cout_min(km, 3)
	_verifier(p == GrandTour.FORFAIT + 3 * GrandTour.PAR_ETAPE + trajets, "prix = forfait + visites + trajets (%d)" % p)

	var clubs := _clubs(6)
	var depart := Geo.centre_pays("france")
	var w := GrandTour.proposer("france", clubs, {}, depart, "weekend", 3)
	_verifier(w["etapes"].size() == 3 and w["prix"] >= GrandTour.FORFAIT + 3 * GrandTour.PAR_ETAPE, "week-end : 3 stades")
	var b := GrandTour.proposer("france", clubs, {}, depart, "boucle", 3)
	_verifier(b["etapes"].size() == 5 and b["prix"] > w["prix"], "grande boucle : 5 stades, plus chère")
	var tampons := {}
	for e in clubs.slice(0, 5):
		tampons["stade:" + e["id"]] = {}
	_verifier(GrandTour.proposer("france", clubs, tampons, depart, "weekend", 3).is_empty(), "moins de 2 stades à tamponner : pas de Grand Tour")
	tampons.erase("stade:t900")
	var t2 := GrandTour.proposer("france", clubs, tampons, depart, "boucle", 3)
	_verifier(t2["etapes"].size() == 2 and not t2["etapes"].any(func(e): return tampons.has(e["cle"])), "seulement des stades pas encore tamponnés")
	_verifier(GrandTour.a_tamponner("france", clubs, tampons) == 2, "stades à tamponner")
	_verifier(GrandTour.proposer("france", clubs, {}, depart, "inconnu", 3).is_empty(), "taille inconnue")


func _tester_jeu() -> void:
	var Game: Node = root.get_node("/root/Game")
	Game.tampons = {}
	Game.grand_tour = {}
	Game.stade_du_jour = {}
	Game.collection = Collection.vide()
	var tour := GrandTour.proposer("france", _clubs(4), {}, Geo.centre_pays("france"), "weekend", 3)
	Game.jetons = tour["prix"] - 1
	_verifier(Game.partir_grand_tour(tour).is_empty() and Game.tampons.is_empty() and not Game.grand_tour_fait_aujourdhui(), "pas assez de Jetons")
	Game.jetons = tour["prix"] + 10
	var xp_avant := JSON.stringify(Game.etat_pass)
	var n: Array = Game.partir_grand_tour(tour)
	_verifier(n.size() == 3 and Game.tampons.size() == 3 and Game.jetons == 10, "3 tampons, Jetons payés")
	_verifier(JSON.stringify(Game.etat_pass) == xp_avant, "pas d'XP de PASS achetée en Jetons")
	_verifier(Game.grand_tour_fait_aujourdhui(), "noté pour aujourd'hui")
	Game.jetons = 10000
	_verifier(Game.partir_grand_tour(tour).is_empty() and Game.jetons == 10000, "un seul Grand Tour par jour")
	var tous: bool = tour["etapes"].all(func(e): return Game.au_stade(e["cle"]))
	_verifier(tous and Game.prix_souvenir(tour["etapes"][0]["cle"], "fanion") == Souvenirs.prix("fanion", true), "boutiques au prix sur place")
	var fin: Dictionary = tour["etapes"][2]
	_verifier(is_equal_approx(float(Game.position_club["lon"]), fin["pos"].x), "le fan club finit à la dernière étape")
	# arrivée à un stade normal le même jour : les boutiques du tour restent au prix sur place
	Game.noter_arrivee_stade("stade:autre")
	_verifier(Game.au_stade("stade:autre") and Game.au_stade(tour["etapes"][0]["cle"]), "plusieurs stades le même jour")
