extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_materiel.gd
## Vérifie le matériel de tribune : prix par niveau, niveau max, Jetons dépensés,
## objet rangé ou installé, vieille sauvegarde réparée, et AUCUN effet sur le duel.

var _echecs := 0


func _init() -> void:
	await process_frame
	_tester_regles()
	_tester_jeu()
	await _tester_duel()
	print("Tests matériel : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_regles() -> void:
	var e := {}
	_verifier(Materiel.prix_suivant(e, "drapeaux") == 200 and Materiel.prix_suivant(e, "inconnu") == -1, "prix du niveau 1")
	Materiel.monter(e, "drapeaux")
	_verifier(Materiel.niveau(e, "drapeaux") == 1 and Materiel.actif(e, "drapeaux"), "acheté et installé")
	_verifier(Materiel.prix_suivant(e, "drapeaux") == 500, "prix du niveau 2")
	Materiel.monter(e, "drapeaux")
	Materiel.monter(e, "drapeaux")
	Materiel.monter(e, "drapeaux")
	_verifier(Materiel.niveau(e, "drapeaux") == Materiel.NIVEAU_MAX and Materiel.prix_suivant(e, "drapeaux") == -1, "niveau max")
	_verifier(Materiel.valeur(e) == 1900, "valeur du matériel (%d)" % Materiel.valeur(e))
	Materiel.basculer(e, "drapeaux")
	_verifier(not Materiel.actif(e, "drapeaux") and Materiel.affiche(e).is_empty(), "rangé : plus affiché")
	Materiel.basculer(e, "tambours")
	_verifier(not e.has("tambours"), "on ne range pas ce qu'on n'a pas")
	var r := Materiel.reparer({"bache": {"niveau": 9}, "jetpack": {"niveau": 1}, "echarpes": 3, "tambours": {"niveau": 0}})
	_verifier(r.size() == 1 and Materiel.niveau(r, "bache") == 3 and Materiel.actif(r, "bache"), "sauvegarde réparée")
	_verifier(Materiel.reparer(null).is_empty(), "pas de sauvegarde")


func _tester_jeu() -> void:
	var Game: Node = root.get_node("/root/Game")
	Game.materiel = {}
	Game.jetons = 300
	_verifier(Game.acheter_materiel("echarpes") and Game.jetons == 150, "achat : 150 Jetons dépensés")
	_verifier(not Game.acheter_materiel("echarpes") and Game.jetons == 150, "pas assez pour le niveau 2")
	_verifier(not Game.acheter_materiel("inconnu"), "objet inconnu")
	Game.basculer_materiel("echarpes")
	_verifier(not Materiel.actif(Game.materiel, "echarpes"), "rangé depuis le jeu")
	Game.jetons = 1000
	_verifier(Game.acheter_materiel("echarpes") and Materiel.actif(Game.materiel, "echarpes"), "amélioré : réinstallé")


## Même duel, même partie : la jauge et les points ne dépendent pas du matériel.
func _tester_duel() -> void:
	var Game: Node = root.get_node("/root/Game")
	var res := []
	for avec in [false, true]:
		Game.materiel = {}
		if avec:
			for id in Materiel.ids():
				for i in Materiel.NIVEAU_MAX:
					Materiel.monter(Game.materiel, id)
		Game.params = {"match_id": "ex:1", "camp": "home", "mode": "stade", "cout": 0}
		seed(42)
		var sc: Node = load(Game.SCENE_DUEL).instantiate()
		root.add_child(sc)
		for i in 5:
			await process_frame
		_verifier(sc._decor.materiel.size() == (Materiel.ids().size() if avec else 0), "décor du duel : matériel transmis")
		var avant: float = sc.jauge
		res.append([avant, sc.charge_tifo])
		sc.queue_free()
		await process_frame
	_verifier(res[0] == res[1], "aucun effet sur la jauge (%s)" % str(res))
