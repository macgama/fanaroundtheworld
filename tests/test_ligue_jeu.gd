extends Node
## Ligue des tribunes branchée dans le jeu (autoloads chargés), un samedi de journée :
## godot --headless --path . res://tests/test_ligue_jeu.tscn -- --hors-ligne --maintenant=2026-11-21T15:00:00
## (sans --maintenant, en semaine : seulement les vérifications « rien ne compte »).
## Inscription, duel contre un club du jeu (et pas compté au tournoi), duel en ligne
## « à confirmer », plafonds, sauvegarde, puis fin de saison et récompense.
## La sauvegarde du joueur est remise en état à la fin.

var _echecs := 0


func _v(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _match(id: String, t: int, statut := "SCHEDULED") -> Dictionary:
	return {
		"id": id, "status": statut, "competition": {"id": "fr.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(t) + ".000Z",
		"home": {"id": "af:85"}, "away": {"id": "af:81"}, "score": {"current": null},
	}


func _ready() -> void:
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	Game.reinitialiser()
	var c := Game.actualiser_ligue()
	_v(not Game.inscrire_ligue(), "pas de fan club : pas d'inscription")
	Game.creer_club("Les Testeurs", FanClub.COULEURS[0], FanClub.COULEURS[3])
	if c["etat"] != "journee":
		# En semaine : on peut entrer dans la Ligue, mais aucun duel ne compte.
		print("Pas de journée en ce moment : tests réduits (ajouter --maintenant=2026-11-21T15:00:00 pour tout tester)")
		_v(Game.inscrire_ligue(), "inscription en semaine")
		Game.params = {"ligue_bot": 0}
		var p := c["prochaine"] as int
		_v(Game.noter_duel_ligue(_match("test:l9", p + 3600), 1).is_empty(), "rien ne compte en semaine")
		Game.params = {}
	else:
		var j: Dictionary = c["journee"]
		var m1 := _match("test:l1", int(j["debut"]) + 3600, "LIVE")
		var m2 := _match("test:l2", int(j["debut"]) + 7200)
		var jeudi := _match("test:l3", int(j["debut"]) - 3600)
		# Contre un club du jeu de la poule (depuis l'écran de la Ligue).
		Game.params = {"ligue_bot": 2, "match_id": "test:l1"}
		var b := Game.bot_ligue()
		_v(str(b.get("id", "")) == "bot:2", "club du jeu de la poule")
		_v(FinDuel.nom_adverse(m1, "X") == Tournoi.nom_texte(b["nom"]), "son nom en haut du duel")
		_v(Game.adversaire_tournoi(m1).is_empty(), "un duel de Ligue ne compte pas au tournoi")
		var d := Game.noter_duel_ligue(m1, 1)
		_v(bool(Game.ligue["inscrit"]), "inscription automatique au premier duel")
		_v(int(d.get("pts", 0)) == Ligue.POINTS_VICTOIRE + Ligue.BONUS_DIRECT and d["etat"] == "local", "victoire en direct : 4 points")
		_v(Game.noter_duel_ligue(jeudi, 1).is_empty(), "match du jeudi : rien")
		Game.noter_duel_ligue(m2, -1)
		_v(Game.noter_duel_ligue(m2, 1).is_empty(), "2 duels au plus contre le même club")
		# En ligne : l'adversaire envoie son identité, l'hôte le code du duel.
		Game.params = {"en_ligne": true, "code_ligue": "00000000000000ab"}
		Reseau.adversaire = {"nom": "Les Voisins", "fan": "abcdef0123456789", "ligue_nom": [3, 4]}
		var e := Game.noter_duel_ligue(m2, 1)
		_v(e.get("etat", "") == "attente" and e.get("nom_texte", "") == "Les Voisins", "duel en ligne : à confirmer")
		_v(FinDuel.ligne_ligue(e)[0][1].contains("confirmer"), "ligne de fin : à confirmer")
		Game.params = {"en_ligne": true, "code_ligue": "pas-un-code"}
		_v(Game.noter_duel_ligue(m2, 1).is_empty(), "code invalide : rien")
		Game.params = {"en_ligne": true, "code_ligue": "00000000000000ac"}
		Reseau.adversaire = {"nom": "Sans identité"}
		_v(Game.noter_duel_ligue(m2, 1).is_empty(), "adversaire sans identité : rien")
		Reseau.adversaire = {}
		Game.params = {}
		_v(Ligue.points(Game.ligue) == 4 + 1 + 3, "points de la journée")
		Game.charger()
		_v((Game.ligue["duels"] as Array).size() == 3, "duels relus de la sauvegarde")
		# La saison passe : la récompense attend (le duel en ligne n'a jamais été confirmé).
		for k in 3:
			Game.ligue["duels"].append({"code": "%016x" % (900 + k), "adv": "bot:%d" % (5 + k), "nom_adv": [0, 0], "bot": true,
				"gagne": true, "direct": false, "match": "test:x%d" % k, "journee": "autre", "t": 0, "envoye": true, "etat": "local", "pts": 3})
		Ligue.actualiser(Game.ligue, int(c["fin_saison"]) + 7 * 86400)
		var r: Dictionary = Game.ligue["a_reclamer"]
		_v(str(r.get("saison", "")) == str(c["saison"]) and int(r.get("duels", 0)) == 5, "saison finie à réclamer")
		var jet := Game.jetons
		var g := Game.reclamer_ligue()
		_v(int(g.get("jetons", 0)) >= Ligue.RECOMPENSES[-1]["jetons"] and Game.jetons == jet + int(g["jetons"]), "récompense versée")
		_v(Game.reclamer_ligue().is_empty(), "une seule fois")
	print("Tests ligue (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	if sauvegarde != "":
		var fi := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		fi.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	get_tree().quit(1 if _echecs > 0 else 0)
