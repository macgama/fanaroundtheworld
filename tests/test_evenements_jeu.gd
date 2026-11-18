extends Node
## Événements branchés dans le jeu (autoloads chargés) :
## godot --headless --path . res://tests/test_evenements_jeu.tscn -- --hors-ligne
## Derby en cours : bonus de Jetons à chaque duel, prime d'XP de PASS une seule
## fois, mission « Soirs de fête », sauvegarde ; match lointain : pas de bonus.
## La sauvegarde du joueur est remise en état à la fin.

var _echecs := 0


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _match(id: String, decalage_h: float, dom := "af:489", ext := "af:505") -> Dictionary:
	var t := int(Time.get_unix_time_from_system() + decalage_h * 3600.0)
	return {
		"id": id, "status": "SCHEDULED", "competition": {"id": "it.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(t) + ".000Z",
		"home": {"id": dom}, "away": {"id": ext}, "score": {"current": null},
	}


func _ready() -> void:
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	Game.reinitialiser()
	Game.actualiser_missions()
	Game.missions["de_la_semaine"][0] = Missions._nouvelle(Missions._modele(Missions.SEMAINE, "s_fete2"))

	var derby := _match("test:derby", 2.0)
	var ev := Game.evenement_de(derby)
	_verifier(ev.get("type") == "derby" and ev.get("titre") == "Derby de Milan", "derby repéré : %s" % str(ev.get("titre")))
	_verifier(Game.etat_evenement(derby) == "actif", "derby dans 2 h : fête en cours")

	var jetons := Game.jetons
	var r := Game.recompense_evenement(derby, 30)
	_verifier(int(r.get("bonus", -1)) == 15, "bonus ×1,5 sur 30 Jetons : +15 (%s)" % str(r.get("bonus")))
	_verifier(int(r.get("prime_xp", 0)) == 125 and int(r.get("prime_jetons", 0)) == 30, "prime du premier duel")
	_verifier(Game.jetons == jetons + 45 and Game.xp_pass == 125, "Jetons et XP de PASS versés")
	_verifier(Game.prime_evenement_gagnee("test:derby"), "prime notée")
	var lignes := FinDuel.lignes_evenement(r)
	_verifier(lignes.size() == 2 and "Derby de Milan" in str(lignes[0][0]), "lignes du panneau de fin : %s" % str(lignes))

	var r2 := Game.recompense_evenement(derby, 30)
	_verifier(int(r2.get("bonus", 0)) == 15 and int(r2.get("prime_xp", -1)) == 0, "deuxième duel : bonus, pas de prime")
	_verifier(FinDuel.lignes_evenement(r2).size() == 1, "une seule ligne sans prime")
	_verifier(Game.missions["de_la_semaine"][0]["progres"] == 2, "mission Soirs de fête : 2/2")

	var loin := _match("test:loin", 72.0)
	_verifier(Game.etat_evenement(loin) == "a_venir", "derby dans 3 jours : à venir")
	_verifier(Game.recompense_evenement(loin, 30).is_empty(), "pas de bonus avant la fête")
	_verifier(Game.recompense_evenement(_match("test:banal", 1.0, "af:9001", "af:9002"), 30).is_empty(), "match banal : rien")

	Game.charger()
	_verifier(Game.prime_evenement_gagnee("test:derby") and Game.xp_pass == 125, "sauvegardé")
	Game.reinitialiser()
	_verifier(not Game.prime_evenement_gagnee("test:derby"), "remis à zéro")

	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	print("Tests événements (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)
