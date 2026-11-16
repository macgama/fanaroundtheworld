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
	# Le même match suivi une 2e fois (même gratuit, à la maison) ne fait pas avancer « Suis 3 matchs ».
	var suivre3 := _mission("jour", "j_suivre3")
	Game.missions["du_jour"].append(suivre3)
	Game.noter_suivi_favori(m, "home", "maison")
	_verifier(suivre3["progres"] == 0, "un même match ne compte qu'une fois (%d)" % suivre3["progres"])
	Game.missions["du_jour"].erase(suivre3)
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

	_verifier(Game.xp_pass == PassSaison.XP_NOUVEAU_STADE, "XP de PASS du premier tampon (%d)" % Game.xp_pass)
	var jetons := Game.jetons
	var xp_avant := Game.xp_pass
	var g := Game.recuperer_mission("jour", 0)
	# 50 XP, ou 100 pendant le rattrapage du PASS (joueur en retard sur la saison).
	var xp_mission := 100 if Game.rattrapage_pass() else 50
	_verifier(Game.jetons == jetons + 15 and g.get("xp_pass") == xp_mission and Game.xp_pass == xp_avant + xp_mission, "récompense versée (%s)" % str(g))
	_verifier(Game.recuperer_mission("jour", 0).is_empty() and Game.jetons == jetons + 15, "une seule fois")
	Game.charger()
	_verifier(Game.xp_pass == xp_avant + xp_mission and Game.missions["du_jour"][0]["recuperee"], "sauvegardé")
	_verifier(Missions.a_recuperer(Game.missions) == 2, "encore 2 récompenses à récupérer")

	# Rejouer le même match le même jour : 100 %, 50 %, 25 %, puis rien.
	var facteurs := []
	for i in 5:
		facteurs.append(Game.noter_duel_match("test:rejeu"))
	_verifier(facteurs == [1.0, 0.5, 0.25, 0.0, 0.0], "rejouer le même match (%s)" % str(facteurs))
	_verifier(Game.noter_duel_match("test:autre") == 1.0, "un autre match repart à plein tarif")
	Game.duels_par_match["test:rejeu"]["jour"] = "2000-01-01"
	_verifier(Game.noter_duel_match("test:rejeu") == 1.0, "le lendemain, plein tarif")
	Game.duels_par_match["test:vieux"] = 4  # ancienne sauvegarde (nombre seul)
	_verifier(Game.noter_duel_match("test:vieux") == 1.0, "ancienne sauvegarde lue")
	var g1 := FinDuel.enregistrer(true, 1.0, {"id": "test:rejeu", "m": m}, "home", "pub")
	_verifier(g1["part"] == 0.5 and g1["jetons"] == int(round(FinDuel.gains(true, 1.0, "pub", g1["equipe_gagne"])["jetons"] * 0.5)), "Arène/Poussée : gains réduits (%s)" % str(g1))
	_verifier(Game.libelle_rejeu(0.25).contains("25 %") and Game.libelle_rejeu(0.0).contains("3 fois"), "libellés")

	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	print("Tests missions (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)
