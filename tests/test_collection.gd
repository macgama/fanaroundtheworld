extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_collection.gd
## Vérifie la collection : album (FANZZY vus en duel, skins portés), paliers du
## carnet de voyage, championnat complet, primes réclamées une seule fois.

var _echecs := 0


func _init() -> void:
	_tester_album()
	_tester_carnet()
	_tester_primes()
	_tester_reparer()
	print("Tests collection : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
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


const CATALOGUE := [
	{"id": "A1", "famille": "voix", "serie": "TR", "skins": [{"id": "A1"}, {"id": "A1B"}]},
	{"id": "A2", "famille": "voix", "serie": "AN", "skins": [{"id": "A2"}]},
	{"id": "B1", "famille": "pyro", "serie": "TR", "skins": [{"id": "B1"}]},
]
const FAMILLES := {"voix": {"nom": "Voix", "couleur": "#F5C33B"}, "pyro": {"nom": "Pyro", "couleur": "#E0402C"}}
const SERIES := {"TR": {"nom": "La Tribune"}}


func _tester_album() -> void:
	var c := Collection.vide()
	var n := Collection.noter_duel(c, ["A1", "B1"], ["A1B", "B1"], "2026-11-15")
	_verifier(n == ["A1", "B1"], "deux nouveaux FANZZY")
	_verifier(Collection.noter_duel(c, ["A1"], ["A1"], "2026-11-16").is_empty(), "déjà dans l'album")
	_verifier(Collection.a_skin(c, "A1B") and Collection.a_skin(c, "A1"), "skins portés notés")
	_verifier(c["fanzzy"]["A1"] == "2026-11-15", "date de la première fois gardée")
	var s := Collection.series_album(c, CATALOGUE, FAMILLES, SERIES)
	_verifier(_par_id(s, "famille:pyro")["complete"], "famille Pyro complète")
	_verifier(not _par_id(s, "famille:voix")["complete"] and _par_id(s, "famille:voix")["fait"] == 1, "famille Voix 1/2")
	_verifier(_par_id(s, "serie:TR")["complete"] and _par_id(s, "serie:TR")["titre"] == "La Tribune", "série TR complète")
	_verifier(_par_id(s, "serie:AN")["titre"] == "Série AN", "nom de série par défaut")
	_verifier(_par_id(s, "album")["fait"] == 2 and _par_id(s, "album")["total"] == 3, "album 2/3")


func _tampons(n: int, pays: String, continent := "Europe", debut := 0) -> Dictionary:
	var t := {}
	for i in n:
		t["stade:%d" % (debut + i)] = {"nom": "S%d" % i, "pays": pays, "continent": continent}
	return t


func _tester_carnet() -> void:
	var c := Collection.vide()
	var t := _tampons(4, "france")
	t.merge(_tampons(1, "", "", 100))  # vieux tampon sans pays : retrouvé par le club
	var pays_equipes := {"100": "brazil"}
	var continent_de := func(p): return {"brazil": "South America", "france": "Europe"}.get(p, "World")
	var lieux := Collection.lieux_visites(t, pays_equipes, continent_de)
	_verifier(lieux["pays"].size() == 2 and lieux["continents"].size() == 2, "2 pays, 2 continents")
	var champ := {"fr.1": {"titre": "Ligue Hexagone", "clubs": ["0", "1", "2", "3"]}, "es.1": {"titre": "Liga", "clubs": ["50", "51"]}}
	var s := Collection.series_carnet(c, t, lieux, champ)
	_verifier(_par_id(s, "stades:1")["complete"] and _par_id(s, "stades:1")["titre"] == "1 stade", "palier 1 stade")
	_verifier(_par_id(s, "stades:5")["complete"], "palier 5 stades (5 tampons)")
	_verifier(not _par_id(s, "stades:10")["complete"] and _par_id(s, "stades:10")["fait"] == 5, "palier suivant en cours")
	_verifier(_par_id(s, "stades:25").is_empty(), "paliers lointains cachés")
	_verifier(_par_id(s, "pays:2")["complete"] and _par_id(s, "continents:2")["complete"], "paliers pays et continents")
	var fr := _par_id(s, "ligue:fr.1")
	_verifier(fr["complete"] and fr["prime"] == 4 * Collection.PRIME_PAR_STADE_LIGUE, "championnat complet, prime par stade")
	_verifier(_par_id(s, "ligue:es.1").is_empty(), "ligue jamais visitée non listée")


func _tester_primes() -> void:
	var c := Collection.vide()
	var t := _tampons(1, "france")
	var s := Collection.series_carnet(c, t, Collection.lieux_visites(t, {}, func(p): return "Europe"), {})
	var pretes := Collection.pretes(s)
	_verifier(pretes.size() == 1 and pretes[0]["id"] == "stades:1", "une prime prête")
	_verifier(Collection.reclamer(c, pretes[0], "2026-11-15") == 20, "prime versée")
	_verifier(Collection.reclamer(c, pretes[0], "2026-11-15") == 0, "pas deux fois")
	var pas_finie := _par_id(s, "stades:5")
	_verifier(Collection.reclamer(c, pas_finie, "2026-11-15") == 0, "série incomplète : rien")
	s = Collection.series_carnet(c, t, Collection.lieux_visites(t, {}, func(p): return "Europe"), {})
	_verifier(Collection.pretes(s).is_empty() and _par_id(s, "stades:1")["reclamee"], "prime marquée reçue")


func _tester_reparer() -> void:
	_verifier(Collection.reparer(null) == Collection.vide(), "sauvegarde sans collection")
	var r := Collection.reparer({"fanzzy": {"A1": "x"}, "primes": []})
	_verifier(r["fanzzy"].has("A1") and r["primes"] is Dictionary and r["skins"] is Dictionary, "sauvegarde abîmée réparée")
