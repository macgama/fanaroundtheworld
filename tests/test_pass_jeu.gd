extends Node
## Test du PASS branché dans le jeu (autoloads chargés) :
## godot --headless --path . res://tests/test_pass_jeu.tscn -- --hors-ligne
## Recrues jouables après récupération, skins dans la tribune, XP des duels et
## des stades, sauvegarde. La sauvegarde du joueur est remise en état à la fin.

var _echecs := 0


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _ready() -> void:
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	Game.reinitialiser()
	_verifier(not Game.pass_data.is_empty(), "paliers de la saison chargés")
	var recrue := str(Game.pass_data["paliers"][0]["gratuit"]["fanzzy"])
	_verifier(not Game.fanzzy_par_id(recrue).is_empty(), "la recrue existe dans le catalogue")
	_verifier(not Game.fanzzy.any(func(z): return z["id"] == recrue), "recrue bloquée au départ")
	var nb := Game.fanzzy.size()

	# Palier 1 gratuit : la recrue devient jouable.
	var g := Game.recuperer_pass(1, "gratuit")
	_verifier(recrue in g.get("fanzzy", []), "recrue récupérée")
	_verifier(Game.fanzzy.size() == nb + 1 and Game.fanzzy.any(func(z): return z["id"] == recrue), "recrue jouable")
	_verifier(Game.recuperer_pass(1, "premium").is_empty(), "Premium bloqué")

	# Premium (simulé) : skin doré de la recrue, choisi dans la tribune.
	Game.etat_pass["premium"] = true
	g = Game.recuperer_pass(1, "premium")
	_verifier(g.get("skins", []).size() == 1, "skin doré du palier 1")
	var z := Game.fanzzy_par_id(recrue)
	var skins := Game.skins_possibles(z)
	_verifier(skins.size() == z["skins"].size() + 1, "skin du PASS proposé dans la tribune")
	var dore: String = skins[-1]["id"]
	Game.skins[recrue] = dore
	_verifier(Game.texture_fanzzy(recrue) != null and Game.texture_fanzzy(recrue, true) != null, "images du skin doré")

	# Sources d'XP de PASS.
	var xp := Game.xp_pass
	Game.tamponner("stade:test-pass", {"nom": "Test"})
	_verifier(Game.xp_pass == xp + PassSaison.XP_NOUVEAU_STADE, "premier tampon : XP de PASS")
	xp = Game.xp_pass
	var gd := FinDuel.enregistrer(true, 1.0, {"id": "test:pass", "m": {}}, "home", "pub")
	_verifier(int(gd["xp_pass"]) == PassSaison.xp_duel(true, 1.0) and Game.xp_pass == xp + int(gd["xp_pass"]), "duel : XP de PASS (%s)" % str(gd.get("xp_pass")))

	# Tout récupérer jusqu'au palier atteint, puis sauvegarde.
	Game.xp_pass = 30_000
	var avant := Game.jetons
	g = Game.recuperer_pass()
	_verifier(Game.pass_a_recuperer() == 0 and Game.jetons == avant + int(g["jetons"]) and int(g["jetons"]) > 0, "tout récupérer (%s)" % PassSaison.resume(g))
	_verifier(Game.fanzzy.size() == nb + 2, "recrue du palier 25 jouable")
	Game.sauver()
	Game.charger()
	_verifier(Game.etat_pass["premium"] and Game.etat_pass["recus"]["gratuit"].size() > 10 and Game.skins.get(recrue) == dore, "sauvegardé")
	_verifier(Game.fanzzy.size() == nb + 2, "recrues relues")

	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	Game.charger()
	print("Tests PASS (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)
