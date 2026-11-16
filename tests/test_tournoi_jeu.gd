extends Node
## Tournoi branché dans le jeu (autoloads chargés) :
## godot --headless --path . res://tests/test_tournoi_jeu.tscn -- --hors-ligne
## Inscription, duel compté (une seule fois par match), duel en ligne ignoré,
## mission, sauvegarde, puis récompense après le week-end.
## Hors du week-end (lundi midi → vendredi), vérifie seulement que rien ne compte.
## La sauvegarde du joueur est remise en état à la fin.

var _echecs := 0


func _v(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _match(id: String, t: int) -> Dictionary:
	return {
		"id": id, "status": "SCHEDULED", "competition": {"id": "fr.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(t) + ".000Z",
		"home": {"id": "af:85"}, "away": {"id": "af:81"}, "score": {"current": null},
	}


func _ready() -> void:
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	Game.reinitialiser()
	var f := Game.actualiser_tournoi()
	_v(not Game.inscrire_tournoi([1, 2], [0, 3]), "pas de fan club : pas d'inscription")
	Game.creer_club("Les Testeurs", FanClub.COULEURS[0], FanClub.COULEURS[3])
	var dedans := _match("test:t1", int(f["debut"]) + 3600)
	if f["etat"] == "actif":
		_v(Game.inscrire_tournoi([1, 2], [0, 3]), "inscription")
		Game.actualiser_missions()
		Game.missions["de_la_semaine"][0] = Missions._nouvelle(Missions._modele(Missions.SEMAINE, "s_tournoi3"))
		var adv := Game.adversaire_tournoi(dedans)
		_v(not adv.is_empty() and str(adv["id"]).begins_with("bot:"), "hors ligne : adversaire club du jeu")
		_v(FinDuel.nom_adverse(dedans, "X") == Tournoi.nom_texte(adv["nom"]), "nom du club adverse affiché en duel")
		var d := Game.noter_duel_tournoi(dedans, true, "pub")
		_v(int(d.get("pts", 0)) == Tournoi.POINTS_VICTOIRE, "victoire : 3 points")
		_v(Game.noter_duel_tournoi(dedans, true, "pub").is_empty(), "match rejoué : pas de point")
		_v(FinDuel.nom_adverse(dedans, "X") == "Tribune X", "match déjà joué : tribune normale")
		Game.params = {"en_ligne": true}
		_v(Game.noter_duel_tournoi(_match("test:t2", int(f["debut"]) + 7200), true, "stade").is_empty(), "duel en ligne ignoré")
		Game.params = {}
		var d2 := Game.noter_duel_tournoi(_match("test:t3", int(f["debut"]) + 7200), false, "stade")
		_v(int(d2.get("pts", 0)) == 2, "défaite au stade : 2 points")
		_v(int(Game.missions["de_la_semaine"][0]["progres"]) == 2, "mission « Esprit de compétition » : 2/3")
		Game.charger()
		_v((Game.tournoi["duels"] as Array).size() == 2, "duels relus de la sauvegarde")
		# Le week-end passe : la récompense attend.
		Tournoi.actualiser(Game.tournoi, int(f["fin"]) + 60)
		Game.tournoi["duels"] = []
		_v(int(Game.tournoi["a_reclamer"].get("points", 0)) == 5, "5 points à réclamer")
		var j := Game.jetons
		var g := Game.reclamer_tournoi()
		_v(int(g.get("jetons", 0)) == 30 and Game.jetons == j + 30, "palier « Tribune engagée » versé")
	else:
		_v(not Game.inscrire_tournoi([1, 2], [0, 3]), "pas de tournoi en semaine")
		_v(Game.noter_duel_tournoi(dedans, true, "pub").is_empty(), "rien ne compte en semaine")
	print("Tests tournoi (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	if sauvegarde != "":
		var fi := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		fi.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	get_tree().quit(1 if _echecs > 0 else 0)
