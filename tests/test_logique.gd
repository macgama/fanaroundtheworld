extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_logique.gd
## Vérifie les noms fictifs et le placement des matchs sur la carte.

var _echecs := 0


func _init() -> void:
	_tester_noms()
	_tester_geo()
	_tester_selections()
	_tester_statuts()
	print("Tests : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_noms() -> void:
	var a := Fiction.equipe({"id": "af:12345", "name": "Vrai Nom FC"})
	var b := Fiction.equipe({"id": "af:12345", "name": "Vrai Nom FC"})
	_verifier(a["nom"] == b["nom"], "le nom fictif doit être stable")
	_verifier(a["nom"] != "Vrai Nom FC", "le vrai nom ne doit jamais apparaître")
	_verifier(Fiction.equipe({"id": "af:85", "name": "x"})["nom"] == "Paris Capitale", "table des noms choisis")
	_verifier(Fiction.equipe({"id": "af:2", "name": "France"}, true)["nom"] == "France", "sélection = nom du pays")
	_verifier(Fiction.competition({"id": "fr.1"}) == "Ligue Hexagone", "ligue fictive connue")
	_verifier(Fiction.competition({"id": "el-salvador.1"}).begins_with("D1 · "), "ligue générique")
	var noms := {}
	for i in 300:
		noms[Fiction.equipe({"id": "af:%d" % (1000 + i)})["nom"]] = true
	_verifier(noms.size() > 250, "assez de noms différents (%d/300)" % noms.size())


func _tester_geo() -> void:
	var m := {"id": "t1", "competition": {"id": "fr.1"}, "home": {"id": "af:85", "name": "x"}, "away": {"id": "af:81"}}
	var l := Geo.lieu_match(m)
	_verifier(l["niveau"] == "pays" and l["pays"] == "france", "championnat de France placé en France")
	_verifier(Geo.continent_de("france") == "Europe", "France en Europe")
	_verifier(Geo.continent_de("brazil") == "South America", "Brésil en Amérique du Sud")
	var p := Vector2(l["lon"], l["lat"])
	var dedans := false
	for poly in Geo.forme_pays("france"):
		if Geometry2D.is_point_in_polygon(p, poly):
			dedans = true
	_verifier(dedans, "stade placé à l'intérieur de la France")
	_verifier(Geo.niveau_competition("ucl") == "continent", "coupe d'Europe = niveau continent")
	_verifier(Geo.niveau_competition("world-cup") == "monde", "Mondial = niveau monde")
	_verifier(Geo.info_competition("af-536").get("region") == "North America", "Ligue des nations CONCACAF en Amérique du Nord")
	var sel := Geo.lieu_match({"competition": {"id": "friendlies"}, "home": {"id": "af:2", "name": "France"}})
	_verifier(sel["pays"] == "france", "sélection placée dans son pays")
	var d := Geo.distance_km(Vector2(2.35, 48.86), Vector2(-3.70, 40.42))
	_verifier(d > 1000 and d < 1100, "distance Paris-Madrid (%d km)" % int(d))
	var sans_pays := 0
	for id in ["en.1", "sco.1", "us.1", "congo-dr.1", "macedonia.1", "kosovo.1"]:
		var info := Geo.info_competition(id)
		if not info.has("pays") or Geo.forme_pays(info["pays"]).is_empty():
			sans_pays += 1
			printerr("  pas de forme pour " + id)
	_verifier(sans_pays == 0, "chaque D1 a un pays dessiné")


func _tester_selections() -> void:
	# Noms du flux API-Football : jeunes, abréviations, accents.
	for cas in [["France U20", "france"], ["Denmark U20", "denmark"], ["Korea Republic U21", "south korea"],
			["Türkiye", "turkey"], ["Rep. Of Ireland", "ireland"], ["Guinea-Bissau", "guinea-bissau"],
			["Bosnia & Herzegovina", "bosnia and herzegovina"], ["St. Lucia", "saint lucia"],
			["Cape Verde Islands", "cape verde"], ["USA U21", "united states"], ["Czechia U18", "czech republic"]]:
		_verifier(Geo.cle_pays(cas[0]) == cas[1], "sélection « %s » -> %s (reçu « %s »)" % [cas[0], cas[1], Geo.cle_pays(cas[0])])
	_verifier(Geo.nom_pays_fr("Denmark U20") == "Danemark U20", "nom français gardé avec U20 (%s)" % Geo.nom_pays_fr("Denmark U20"))
	var l := Geo.lieu_match({"competition": {"id": "friendlies"}, "home": {"id": "af:9", "name": "France U20"}})
	_verifier(l["pays"] == "france", "sélection de jeunes placée dans son pays")


func _tester_statuts() -> void:
	var D := load("res://scripts/autoload/donnees.gd")
	var maintenant := int(Time.get_unix_time_from_system())
	var il_y_a := func(h: float) -> String:
		return Time.get_datetime_string_from_unix_time(maintenant - int(h * 3600)) + ".000Z"
	var vieux_live := {"id": "a", "status": "LIVE", "kickoff_utc": il_y_a.call(9)}
	var live_recent := {"id": "b", "status": "HALFTIME", "kickoff_utc": il_y_a.call(0.8)}
	var prevu_passe := {"id": "c", "status": "SCHEDULED", "kickoff_utc": il_y_a.call(5)}
	var prevu := {"id": "d", "status": "SCHEDULED", "kickoff_utc": il_y_a.call(-2)}
	_verifier(D._corriger_statut(vieux_live, false, maintenant)["status"] == "UNKNOWN", "live du calendrier vieux de 9 h = plus en direct")
	_verifier(D._corriger_statut(live_recent, false, maintenant)["status"] == "HALFTIME", "sans live frais, on garde la mi-temps récente")
	_verifier(D._corriger_statut(live_recent, true, maintenant)["status"] == "UNKNOWN", "absent du live frais = plus en direct")
	_verifier(D._corriger_statut(prevu_passe, true, maintenant)["status"] == "UNKNOWN", "« à venir » 5 h après le coup d'envoi = inconnu")
	_verifier(D._corriger_statut(prevu, true, maintenant)["status"] == "SCHEDULED", "match à venir inchangé")
	_verifier(vieux_live["status"] == "LIVE", "le calendrier d'origine n'est pas modifié")
