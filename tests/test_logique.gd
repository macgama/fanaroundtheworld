extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_logique.gd
## Vérifie les noms fictifs et le placement des matchs sur la carte.

var _echecs := 0


func _init() -> void:
	_tester_noms()
	_tester_geo()
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
