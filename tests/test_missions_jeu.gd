extends Node
## Test des missions branchées dans le jeu (autoloads chargés) :
## godot --headless --path . res://tests/test_missions_jeu.tscn -- --hors-ligne
## Match suivi, stade tamponné, buvette, pronostic, duel : les missions avancent,
## la récompense est versée une fois et la partie est sauvegardée.
## La sauvegarde du joueur est remise en état à la fin.

var _echecs := 0


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _mission(periode: String, id: String) -> Dictionary:
	var modeles: Array = Missions.JOUR if periode == "jour" else Missions.SEMAINE
	return Missions._nouvelle(Missions._modele(modeles, id))


func _ready() -> void:
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	Game.reinitialiser()
	Game.actualiser_missions()
	_verifier(Game.missions["du_jour"].size() == 3 and Game.missions["de_la_semaine"].size() == 3, "missions tirées")
	# Missions connues pour le test (même jour et même semaine que le tirage).
	Game.missions["du_jour"] = [_mission("jour", "j_suivre1"), _mission("jour", "j_prono2"), _mission("jour", "j_ambiance")]
	Game.missions["de_la_semaine"] = [_mission("semaine", "s_stade"), _mission("semaine", "s_buvette5"), _mission("semaine", "s_pays3")]
	var terminees: Array = []
	Game.missions_terminees.connect(func(l): terminees.append_array(l.map(func(m): return m["id"])))

	var t := int(Time.get_unix_time_from_system()) + 7200
	var m := {
		"id": "test:mission", "status": "SCHEDULED", "competition": {"id": "fr.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(t) + ".000Z",
		"home": {"id": "af:85"}, "away": {"id": "af:81"}, "score": {"current": null},
	}
	Game.noter_suivi_favori(m, "home", "stade")
	_verifier("j_suivre1" in terminees, "match suivi")
	_verifier(Game.missions["de_la_semaine"][2]["vus"] == ["france"], "pays du match noté (%s)" % str(Game.missions["de_la_semaine"][2]["vus"]))
	_verifier(Game.tamponner("stade:test-mission", {"nom": "Test"}), "premier tampon")
	_verifier("s_stade" in terminees, "nouveau stade")
	Game.tamponner("stade:test-mission", {"nom": "Test"})
	Game.pronostiquer(m, 1, 0, "home")
	Game.pronostiquer(m, 2, 0, "home")  # modification : ne compte pas
	_verifier(Game.missions["du_jour"][1]["progres"] == 1, "un prono, une modification")
	Game.finir_service_buvette(5)
	_verifier(Game.missions["de_la_semaine"][1]["progres"] == 1, "service de buvette")
	Game.noter_duel_favori(m, "home", true, "stade")
	_verifier("j_ambiance" in terminees, "duel d'ambiance joué")

	var jetons := Game.jetons
	var g := Game.recuperer_mission("jour", 0)
	_verifier(Game.jetons == jetons + 15 and Game.xp_pass == 50 and g.get("xp_pass") == 50, "récompense versée")
	_verifier(Game.recuperer_mission("jour", 0).is_empty() and Game.jetons == jetons + 15, "une seule fois")
	Game.charger()
	_verifier(Game.xp_pass == 50 and Game.missions["du_jour"][0]["recuperee"], "sauvegardé")
	_verifier(Missions.a_recuperer(Game.missions) == 2, "encore 2 récompenses à récupérer")

	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	print("Tests missions (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)
