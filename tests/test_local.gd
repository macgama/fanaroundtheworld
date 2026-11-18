extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_local.gd
## Vérifie l'agrandissement du local : salles à construire puis agrandir,
## déco seulement dans une salle construite, une seule fois, Jetons dépensés,
## vieille sauvegarde réparée.

var _echecs := 0


func _init() -> void:
	await process_frame
	_tester_regles()
	_tester_jeu()
	print("Tests local : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_regles() -> void:
	var e := LocalClub.vide()
	_verifier(LocalClub.niveau(e, "principale") == 1 and LocalClub.prix_salle(e, "principale") == -1, "salle principale déjà là")
	_verifier(LocalClub.prix_salle(e, "chants") == 300 and LocalClub.prix_salle(e, "inconnue") == -1, "prix de construction")
	_verifier(LocalClub.prix_deco(e, "piano") == -1 and LocalClub.prix_deco(e, "canape") == 250, "déco seulement dans une salle construite")
	LocalClub.construire(e, "chants")
	_verifier(LocalClub.prix_salle(e, "chants") == 2000 and LocalClub.prix_deco(e, "piano") == 900, "salle construite : agrandir, décorer")
	LocalClub.construire(e, "chants")
	LocalClub.construire(e, "chants")
	_verifier(LocalClub.niveau(e, "chants") == LocalClub.NIVEAU_MAX and LocalClub.prix_salle(e, "chants") == -1, "niveau max")
	LocalClub.poser(e, "piano", "2026-11-18")
	_verifier(LocalClub.a(e, "piano") and LocalClub.prix_deco(e, "piano") == -1, "une seule fois")
	_verifier(LocalClub.valeur(e) == 300 + 2000 + 900, "valeur du local (%d)" % LocalClub.valeur(e))
	_verifier(not LocalClub.complet(e), "pas encore complet")
	for s in LocalClub.SALLES:
		for i in 2:
			LocalClub.construire(e, s["id"])
	for o in LocalClub.DECO:
		LocalClub.poser(e, o["id"], "j")
	_verifier(LocalClub.complet(e), "tout construit et décoré")
	var r := LocalClub.reparer({"salles": {"chants": 7, "cave": 1, "principale": 0}, "deco": {"piano": "j", "coupe": "j", "lustre": "j"}})
	_verifier(LocalClub.niveau(r, "chants") == 2 and LocalClub.niveau(r, "principale") == 1 and not r["salles"].has("cave"), "salles réparées")
	_verifier(LocalClub.a(r, "piano") and not LocalClub.a(r, "coupe") and not LocalClub.a(r, "lustre"), "déco réparée (salle des trophées pas construite)")
	_verifier(LocalClub.reparer(null) == LocalClub.vide(), "pas de sauvegarde")


func _tester_jeu() -> void:
	var Game: Node = root.get_node("/root/Game")
	Game.local_club = LocalClub.vide()
	Game.jetons = 400
	_verifier(Game.acheter_salle("chants") and Game.jetons == 100, "salle construite : 300 Jetons")
	_verifier(not Game.acheter_deco("piano") and Game.jetons == 100, "pas assez pour le piano")
	_verifier(Game.acheter_deco("guirlande") and Game.jetons == 0, "guirlande posée")
	_verifier(not Game.acheter_deco("guirlande"), "pas deux fois")
	_verifier(not Game.acheter_salle("trophees") and LocalClub.niveau(Game.local_club, "trophees") == 0, "pas de Jetons, pas de salle")
