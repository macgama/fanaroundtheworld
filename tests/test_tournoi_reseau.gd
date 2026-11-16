extends Node
## Tournoi contre un vrai Worker (local) : inscription, tirage, résultat, rang.
##   cd worker && npx wrangler dev   (dépôt fanaroundtheworld-data)
##   godot --headless --path . res://tests/test_tournoi_reseau.tscn -- --classement-url=http://localhost:8787/classement/
## Sans --classement-url, ou hors du week-end, le test ne fait rien.
## La sauvegarde et l'identité du joueur sont remises en état à la fin.

var _echecs := 0


func _v(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _attendre(cond: Callable, s := 20.0) -> bool:
	var fin := Time.get_ticks_msec() + int(s * 1000)
	while not cond.call() and Time.get_ticks_msec() < fin:
		await get_tree().create_timer(0.25).timeout
	return cond.call()


func _ready() -> void:
	await get_tree().process_frame
	var f := Tournoi.fenetre(Game.maintenant())
	if EnLigne.desactive or EnLigne.url == ClassementFans.URL or f["etat"] != "actif":
		print("Tests tournoi (réseau) : ignorés (pas de Worker local ou pas de tournoi en cours)")
		get_tree().quit(0)
		return
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var ident := EnLigne.identite.duplicate()
	EnLigne.identite = ClassementFans.identite_neuve(EnLigne._rng())
	Game.reinitialiser()
	Game.creer_club("Les Testeurs", FanClub.COULEURS[0], FanClub.COULEURS[3])
	EnLigne.envoyer(true)
	_v(await _attendre(func(): return not EnLigne.moi.is_empty()), "fan créé sur le serveur")
	_v(Game.inscrire_tournoi([4, 5], [1, 2]), "inscription locale")
	EnLigne.synchroniser_tournoi()
	_v(await _attendre(func(): return bool(Game.tournoi["inscrit_serveur"])), "inscription sur le serveur")
	_v(await _attendre(func(): return not (Game.tournoi["adversaire"] as Dictionary).is_empty()), "adversaire tiré")
	var m := {"id": "test:%d" % randi(), "status": "SCHEDULED", "competition": {"id": "fr.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(int(f["debut"]) + 3600) + ".000Z",
		"home": {"id": "af:85"}, "away": {"id": "af:81"}, "score": {"current": null}}
	var d := Game.noter_duel_tournoi(m, true, "stade")
	_v(int(d.get("pts", 0)) == 4, "victoire au stade : 4 points")
	_v(await _attendre(func(): return bool(d.get("envoye", false))), "résultat envoyé")
	_v(await _attendre(func(): return int(Game.tournoi["rang"]) > 0), "rang reçu : %d" % int(Game.tournoi["rang"]))
	EnLigne.rafraichir_tournoi()
	_v(await _attendre(func(): return not EnLigne.tournoi_classement.is_empty()), "classement reçu")
	var dedans := false
	for c in EnLigne.tournoi_classement.get("clubs", []):
		if c["id"] == EnLigne.identite["id"]:
			dedans = int(c["points"]) == 4 and Tournoi.nom_valide(c["nom"]) == [4, 5]
	_v(dedans, "le club est au classement avec 4 points")
	print("Tests tournoi (réseau) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	EnLigne.identite = ident
	EnLigne._sauver()
	if sauvegarde != "":
		FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE).store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	get_tree().quit(1 if _echecs > 0 else 0)
