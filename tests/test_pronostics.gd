extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_pronostics.gd
## Règles des pronostics sans mise : récompenses fixes, série, premier but, annulations.

var _echecs := 0
const T0 := 1_800_000_000  # « maintenant » fictif


func _init() -> void:
	_tester_ouverture()
	_tester_coherence_premier_but()
	_tester_recompenses()
	_tester_serie()
	_tester_premier_but()
	_tester_annulations()
	print("Tests pronostics : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _match(statut: String, dom := -1, ext := -1, decalage := 3600) -> Dictionary:
	var m := {
		"id": "af:1", "status": statut,
		"kickoff_utc": Time.get_datetime_string_from_unix_time(T0 + decalage) + ".000Z",
		"competition": {"id": "fr.1"}, "home": {"id": "af:85"}, "away": {"id": "af:81"},
		"score": {"current": null},
	}
	if dom >= 0:
		m["score"]["current"] = {"home": dom, "away": ext}
	return m


func _prono(dom: int, ext: int, pb := "home") -> Dictionary:
	return Pronostics.creer(_match("SCHEDULED"), dom, ext, pb, T0)


func _tester_ouverture() -> void:
	_verifier(Pronostics.ouvert(_match("SCHEDULED"), T0), "ouvert avant le coup d'envoi")
	_verifier(not Pronostics.ouvert(_match("SCHEDULED", -1, -1, -60), T0), "fermé après l'heure du coup d'envoi")
	_verifier(not Pronostics.ouvert(_match("LIVE", 0, 0, -60), T0), "fermé pendant le match")
	_verifier(Pronostics.creer(_match("SCHEDULED"), 15, -2, "home", T0)["dom"] == Pronostics.SCORE_MAX, "score borné")


func _tester_coherence_premier_but() -> void:
	_verifier(_prono(0, 0, "home")["premier_but"] == "aucun", "0-0 => aucun but")
	_verifier(_prono(2, 0, "away")["premier_but"] == "home", "2-0 => domicile marque en premier")
	_verifier(_prono(0, 1, "home")["premier_but"] == "away", "0-1 => extérieur")
	_verifier(_prono(2, 1, "away")["premier_but"] == "away", "2-1 : choix libre gardé")


func _tester_recompenses() -> void:
	var r := Pronostics.resoudre(_prono(2, 1, "home"), _match("FINISHED", 2, 1), 0, T0)
	var tout := Pronostics.RECOMPENSE_RESULTAT + Pronostics.RECOMPENSE_SCORE + Pronostics.RECOMPENSE_PREMIER_BUT
	# 2-1 sans info de premier but : inconnu, donc pas de bonus premier but
	_verifier(r["fini"] and r["etat"] == "gagne", "match terminé => résolu")
	_verifier(r["jetons"] == tout - Pronostics.RECOMPENSE_PREMIER_BUT, "premier but inconnu => pas de bonus (%d)" % r["jetons"])
	var m := _match("FINISHED", 2, 1)
	m["first_goal"] = {"team": "home", "minute": 12}
	_verifier(Pronostics.resoudre(_prono(2, 1, "home"), m, 0, T0)["jetons"] == tout, "tout juste")
	r = Pronostics.resoudre(_prono(1, 0), _match("FINISHED", 3, 0), 0, T0)
	_verifier(r["jetons"] == Pronostics.RECOMPENSE_RESULTAT + Pronostics.RECOMPENSE_PREMIER_BUT, "bon résultat + premier but déduit du 3-0")
	r = Pronostics.resoudre(_prono(1, 0), _match("FINISHED", 0, 2), 0, T0)
	_verifier(r["etat"] == "perdu" and r["jetons"] == 0, "raté = 0 Jeton, jamais négatif")
	r = Pronostics.resoudre(_prono(0, 0), _match("FINISHED", 0, 0), 0, T0)
	_verifier(r["jetons"] == tout, "0-0 exact + aucun but")
	_verifier(not Pronostics.resoudre(_prono(1, 0), _match("LIVE", 1, 0), 0, T0)["fini"], "pas résolu pendant le match")
	_verifier(not Pronostics.resoudre(_prono(1, 0), _match("FINISHED"), 0, T0)["fini"], "terminé sans score => on attend")


func _tester_serie() -> void:
	_verifier(Pronostics.multiplicateur(0) == 1.0, "pas de série = ×1")
	_verifier(Pronostics.multiplicateur(2) == 1.5, "série de 2 = ×1.5")
	_verifier(Pronostics.multiplicateur(50) == Pronostics.MULTI_MAX, "multiplicateur plafonné")
	var r := Pronostics.resoudre(_prono(1, 0), _match("FINISHED", 2, 0), 4, T0)
	_verifier(r["serie"] == 5, "bon résultat => série +1")
	_verifier(r["jetons"] == (Pronostics.RECOMPENSE_RESULTAT + Pronostics.RECOMPENSE_PREMIER_BUT) * 2, "gains doublés en série")
	r = Pronostics.resoudre(_prono(1, 0), _match("FINISHED", 1, 1), 4, T0)
	_verifier(r["serie"] == 0, "mauvais résultat => série à zéro")


func _tester_premier_but() -> void:
	var p := _prono(1, 1, "away")
	Pronostics.observer(p, _match("LIVE", 0, 0))
	Pronostics.observer(p, _match("LIVE", 0, 1))
	Pronostics.observer(p, _match("LIVE", 1, 1))
	_verifier(p.get("premier_but_vu") == "away", "premier but vu en direct")
	var r := Pronostics.resoudre(p, _match("FINISHED", 1, 1), 0, T0)
	_verifier(r["premier_but_ok"], "premier but vu en direct compté")
	# Le relais l'emporte sur l'observation locale.
	var m := _match("FINISHED", 1, 1)
	m["first_goal"] = {"team": "home"}
	_verifier(not Pronostics.resoudre(p, m, 0, T0)["premier_but_ok"], "first_goal du relais prioritaire")
	# Arrivé en cours de match à 1-1 : impossible de savoir.
	var q := _prono(1, 1, "home")
	Pronostics.observer(q, _match("LIVE", 1, 1))
	_verifier(not q.has("premier_but_vu"), "pas de déduction sans voir le 0-0")


func _tester_annulations() -> void:
	var r := Pronostics.resoudre(_prono(1, 0), _match("POSTPONED"), 3, T0)
	_verifier(r["fini"] and r["etat"] == "annule" and r["serie"] == 3 and r["jetons"] == 0, "reporté : annulé, série intacte")
	_verifier(not Pronostics.resoudre(_prono(1, 0), {}, 0, T0)["fini"], "match absent juste après : on attend")
	_verifier(Pronostics.resoudre(_prono(1, 0), {}, 0, T0 + 4 * 86400)["etat"] == "annule", "match absent 4 jours après : annulé")
