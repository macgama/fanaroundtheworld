extends Node
## Test des succès et de la sauvegarde dans le jeu (autoloads chargés), sans Steam :
## godot --headless --path . res://tests/test_succes_jeu.tscn -- --hors-ligne
## Des actions débloquent les succès, ils sont gardés dans la sauvegarde locale
## (avec sa date) et relus. La sauvegarde du joueur est remise en état à la fin.

var _echecs := 0


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _ready() -> void:
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	Game.reinitialiser()
	_verifier(Game.succes.is_empty() and Game.stats.is_empty(), "nouvelle partie sans succès")
	_verifier(not Plateforme.steam_ok and not Plateforme.cloud_actif(), "sans Steam dans le test")
	_verifier(Plateforme.texte_sauvegarde().contains("sur ce PC"), "options : sauvegarde locale")
	var recus: Array = []
	Game.succes_gagnes.connect(func(l): recus.append_array(l.map(func(s): return s["id"])))

	Game.creer_club("Test Club", "#1e6bff", "#ffffff")
	_verifier(Game.succes.has("CLUB_CREE"), "fonder le club : succès")
	_verifier("CLUB_CREE" in recus, "signal succes_gagnes")

	Game.tamponner("test-stade", {"nom": "Stade test", "ville": "Paris", "date": "2026-11-16"})
	_verifier(Game.succes.has("STADE_1"), "premier stade : succès")

	Game.duels_joues += 1
	Game.duels_gagnes += 1
	Game.noter_mission("duel_gagne", "arene")
	_verifier(Game.succes.has("PREMIER_DUEL") and Game.succes.has("PREMIERE_VICTOIRE") and Game.succes.has("ARENE_VICTOIRE"), "duel gagné dans l'Arène : 3 succès (%s)" % str(Game.succes.keys()))
	_verifier(not Game.succes.has("POUSSEE_VICTOIRE"), "pas de succès Poussée")

	for b in ListeBoulots.LISTE:
		Game.finir_boulot(b["id"], 5)
	_verifier(Game.succes.has("BOULOTS_TOUS"), "tous les petits boulots : succès")

	for m in Game.ORDRE_MODES:
		Game.noter_mission("suivre", m)
	_verifier(Game.succes.has("SUIVI_PARTOUT"), "suivre de 4 façons : succès")

	# Sauvegarde : succès, compteurs et date relus.
	var date := Game.sauve_le
	_verifier(date > 0, "sauvegarde datée")
	var n := Game.succes.size()
	Game.succes = {}
	Game.stats = {}
	Game.charger()
	_verifier(Game.succes.size() == n and Game.succes.has("ARENE_VICTOIRE"), "succès relus (%d)" % Game.succes.size())
	_verifier(int(Game.stats.get("duel_gagne:arene", 0)) == 1, "compteurs relus")
	_verifier(Game.sauve_le == date, "date relue")
	var etat := Game.etat_succes()
	_verifier(int(etat["stades"]) == 1 and int(etat["club_cree"]) == 1 and int(etat["modes_suivi"]) == 4, "état des succès (%s)" % str(etat))

	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	print("Tests succès (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)
