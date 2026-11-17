extends Node
## Ligue des tribunes contre un vrai Worker (local), deux joueurs A et B :
## inscription, poule, duel en ligne « à confirmer » chez A, confirmé par le résultat de B.
##   cd worker && npx wrangler dev --var DECALAGE_TEST_S:<secondes jusqu'au samedi choisi>   (dépôt fanaroundtheworld-data)
##   godot --headless --path . res://tests/test_ligue_reseau.tscn -- --classement-url=http://localhost:8787/classement/ --maintenant=2026-11-21T15:00:00
## Sans --classement-url, ou hors d'une journée, le test ne fait rien.
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


## Nouveau joueur : identité neuve, envoyée au classement, puis inscrit à la Ligue.
func _joueur(nom: Array) -> Dictionary:
	EnLigne.identite = ClassementFans.identite_neuve(EnLigne._rng())
	EnLigne.moi = {}
	Game.ligue = Ligue.vide()
	Game.actualiser_ligue()
	EnLigne.envoyer(true)
	_v(await _attendre(func(): return not EnLigne.moi.is_empty()), "fan créé sur le serveur")
	_v(Game.inscrire_ligue(nom, [1, 2]), "inscription locale")
	EnLigne.synchroniser_ligue()
	_v(await _attendre(func(): return bool(Game.ligue["inscrit_serveur"])), "inscription sur le serveur")
	return EnLigne.identite.duplicate()


func _ready() -> void:
	await get_tree().process_frame
	var c := Ligue.calendrier(Game.maintenant())
	if EnLigne.desactive or EnLigne.url == ClassementFans.URL or c["etat"] != "journee":
		print("Tests ligue (réseau) : ignorés (pas de Worker local ou pas de journée en cours)")
		get_tree().quit(0)
		return
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var ident := EnLigne.identite.duplicate()
	Game.reinitialiser()
	Game.creer_club("Les Testeurs", FanClub.COULEURS[0], FanClub.COULEURS[3])
	var m := {"id": "test:%d" % randi(), "status": "LIVE", "competition": {"id": "fr.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(int(c["journee"]["debut"]) + 3600) + ".000Z",
		"home": {"id": "af:85"}, "away": {"id": "af:81"}, "score": {"current": null}}
	var code := Ligue.nouveau_code(EnLigne._rng())

	var a := await _joueur([4, 5])
	_v(int(Game.ligue["division"]) == Ligue.DIVISIONS, "A en Ligue Espoir")
	EnLigne.rafraichir_ligue()
	_v(await _attendre(func(): return (EnLigne.ligue_poule.get("clubs", []) as Array).size() == Ligue.TAILLE_POULE), "poule de 10 reçue")
	# A gagne le duel en ligne contre B (B n'existe pas encore : son identité est tirée d'avance).
	var id_b := ClassementFans.identite_neuve(EnLigne._rng())
	Game.params = {"en_ligne": true, "code_ligue": code}
	Reseau.adversaire = {"nom": "Les Voisins", "fan": id_b["id"], "ligue_nom": [6, 7]}
	var da := Game.noter_duel_ligue(m, 1)
	_v(da.get("etat", "") == "attente" and int(da["pts"]) == 4, "A : victoire en direct à confirmer")
	_v(await _attendre(func(): return bool(da.get("envoye", false))), "A : résultat envoyé")
	_v(da["etat"] == "attente", "A : en attente de B")
	var ligue_a: Dictionary = Game.ligue

	# B : même code, il a perdu.
	EnLigne.identite = id_b
	EnLigne.moi = {}
	Game.ligue = Ligue.vide()
	Game.actualiser_ligue()
	EnLigne.envoyer(true)
	_v(await _attendre(func(): return not EnLigne.moi.is_empty()), "B créé sur le serveur")
	Game.inscrire_ligue([6, 7], [3, 4])
	Game.params = {"en_ligne": true, "code_ligue": code}
	Reseau.adversaire = {"nom": "Les Testeurs", "fan": a["id"], "ligue_nom": [4, 5]}
	var db := Game.noter_duel_ligue(m, -1)
	EnLigne.synchroniser_ligue()
	_v(await _attendre(func(): return db.get("etat", "") == "compte"), "B : duel confirmé tout de suite (%s)" % db.get("etat", ""))
	_v(int(db["pts"]) == 2 and Ligue.points(Game.ligue) == 2, "B : défaite en direct, 2 points")

	# Retour chez A : le serveur confirme son duel.
	EnLigne.identite = a
	Game.ligue = ligue_a
	EnLigne.synchroniser_ligue()
	_v(await _attendre(func(): return da["etat"] == "compte"), "A : duel confirmé")
	_v(Ligue.points(Game.ligue) == 4, "A : 4 points d'après le serveur")
	# Un club du jeu de la poule.
	Game.params = {"ligue_bot": 0}
	Reseau.adversaire = {}
	await get_tree().create_timer(21.0).timeout  # un résultat toutes les 20 s
	var dbot := Game.noter_duel_ligue(m, 1)
	_v(await _attendre(func(): return dbot.get("etat", "") == "compte"), "club du jeu : compté par le serveur")
	_v(Ligue.points(Game.ligue) == 8, "A : 8 points")
	EnLigne.rafraichir_ligue()
	await get_tree().create_timer(2.0).timeout
	var moi := {}
	for x in EnLigne.ligue_poule.get("clubs", []):
		if x["id"] == a["id"]:
			moi = x
	_v(int(moi.get("points", 0)) == 8 and Tournoi.nom_valide(moi.get("nom")) == [4, 5], "A dans sa poule avec 8 points")
	Game.params = {}
	print("Tests ligue (réseau) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	EnLigne.identite = ident
	EnLigne._sauver()
	if sauvegarde != "":
		FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE).store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	get_tree().quit(1 if _echecs > 0 else 0)
