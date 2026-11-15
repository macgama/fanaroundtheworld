extends Node
## Classement en ligne dans le jeu (autoloads chargés) :
## godot --headless --path . res://tests/test_classement_jeu.tscn -- --hors-ligne
## Données injectées comme si le serveur avait répondu : écran Classement (fans,
## clubs, sélections, semaine/total), pseudo, et écran Mes équipes branché sur le serveur.
## Avec un Worker de test (cd worker && npx wrangler dev, dépôt fanaroundtheworld-data) :
## ... -- --classement-url=http://localhost:8787/classement/ : vrai envoi, vrai rang.
## Avec un écran (xvfb-run), « --captures=dossier » enregistre les écrans.
## La sauvegarde et l'identité du joueur sont remises en état à la fin.

var _echecs := 0
var _captures := ""


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


## Attend qu'une condition soit vraie (10 s au plus) : les réponses du serveur arrivent dans le désordre.
func _attendre_que(cond: Callable) -> void:
	for i in 100:
		if cond.call():
			return
		await _attendre(0.1)


func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_captures, nom])


func _textes(n: Node, out: Array = []) -> Array:
	if n is Label or n is Button:
		out.append(n.text)
	for c in n.get_children():
		_textes(c, out)
	return out


func _contient(n: Node, texte: String) -> bool:
	return _textes(n).any(func(t: String): return t.contains(texte))


func _ready() -> void:
	# La scène de test est remplacée à chaque écran : le pilote vit à côté.
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteClassement"
		get_tree().root.add_child.call_deferred(pilote)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_captures = a.trim_prefix("--captures=")
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var identite := EnLigne.identite.duplicate(true)
	Game.reinitialiser()
	Game.creer_club("Les Tests Joyeux", "#1e6bff", "#ffd23f")
	var t := Game.maintenant()
	Game.choisir_club_favori("france", "af:85")
	Game.choisir_nation_favorite("france")

	if EnLigne.url != ClassementFans.URL:
		await _tester_serveur()
	else:
		await _tester_ecrans(t)

	Game.reinitialiser()
	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	Game.charger()
	EnLigne.identite = identite
	EnLigne._sauver()
	print("Tests classement (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)


func _tester_ecrans(t: int) -> void:
	_verifier(EnLigne.desactive, "--hors-ligne : rien n'est envoyé")
	EnLigne.identite["pseudo"] = [0, 0, 42]
	var mon_id: String = EnLigne.identite["id"]
	Game.supporters["points"] = {"af:85": 60}
	Game.supporters["envoye"] = {"af:85": 60}
	EnLigne.injecter(
		{"af:85": {"p": 5260, "s": 410, "f": 37}, "af:81": {"p": 6120, "s": 380, "f": 52}, "af:80": {"p": 900, "s": 0, "f": 8},
			"nation:france": {"p": 3000, "s": 220, "f": 40}, "nation:brazil": {"p": 4100, "s": 260, "f": 61}},
		{"semaine": [
			{"rang": 1, "id": "1111111111111111", "pseudo": [16, 3, 7], "points": 640, "equipe": "af:81"},
			{"rang": 2, "id": "2222222222222222", "pseudo": [5, 14, 12], "points": 515, "equipe": "nation:brazil"},
			{"rang": 3, "id": mon_id, "pseudo": [0, 0, 42], "points": 410, "equipe": "af:85"},
			{"rang": 4, "id": "4444444444444444", "pseudo": [21, 8, 99], "points": 260, "equipe": "af:80"}],
		 "total": [{"rang": 1, "id": "1111111111111111", "pseudo": [16, 3, 7], "points": 5400, "equipe": "af:81"}]},
		{"id": mon_id, "pseudo": [0, 0, 42], "points_semaine": 410, "points_total": 1260, "rang_semaine": 3, "rang_total": 12, "fans": 1834, "equipe": "af:85"})

	Game.aller(Game.SCENE_CLASSEMENT)
	await _attendre(0.6)
	var sc := get_tree().current_scene
	_verifier(sc.name == "Classement", "écran Classement ouvert")
	_verifier(_contient(sc, "Tambour Joyeux 42"), "ton pseudo affiché")
	_verifier(_contient(sc, "Lion Infatigable 7"), "meilleur fan de la semaine")
	_verifier(_contient(sc, "3e"), "ton rang de la semaine")
	_verifier(_contient(sc, "mode test"), "hors ligne (test) : signalé sur la carte de fan")
	await _capture("classement-fans")

	sc._periode = "total"
	sc._remplir_droite()
	await _attendre(0.2)
	_verifier(_contient(sc, "…"), "total : tu es hors du top, ta ligne est ajoutée en bas")
	_verifier(_contient(sc, "12e"), "ton rang depuis le début")

	sc._onglet = "clubs"
	sc._periode = "semaine"
	sc._remplir_droite()
	await _attendre(0.2)
	var nom85: String = sc.Favoris.info("af:85")["nom"]
	_verifier(_contient(sc, "★ " + nom85), "ton club favori marqué")
	_verifier(_contient(sc, "37 fans"), "nombre de fans du club")
	_verifier(not _contient(sc, sc.Favoris.info("nation:brazil")["nom"]), "les sélections ne sont pas dans les clubs")
	await _capture("classement-clubs")

	sc._onglet = "nations"
	sc._remplir_droite()
	await _attendre(0.2)
	_verifier(_contient(sc, "61 fans"), "sélections")

	# Changer de nom : deux mots des listes, sauvegardé à part.
	sc._pseudo(3, 4, 5)
	await _attendre(0.1)
	_verifier(EnLigne.pseudo() == "Supporter Magique 5", "nouveau pseudo (%s)" % EnLigne.pseudo())
	_verifier(ClassementFans.reparer(JSON.parse_string(FileAccess.get_file_as_string(EnLigne.CHEMIN)))["pseudo"] == [3, 4, 5], "pseudo sauvegardé")

	# Mes équipes : les autres supporters viennent du serveur.
	Game.aller(Game.SCENE_FAVORIS)
	await _attendre(0.6)
	var fav := get_tree().current_scene
	_verifier(_contient(fav, "classement en ligne"), "Mes équipes : note « en ligne »")
	var lignes: Array = fav._classement([fav.info("af:85"), fav.info("af:81")])
	_verifier(lignes[0]["cle"] == "af:81" and lignes[1]["points"] == 5260, "Mes équipes : points du serveur, les tiens pas comptés deux fois")
	await _capture("mes-equipes")

	# Carte : bouton avec ton rang.
	Game.aller(Game.SCENE_CARTE)
	await _attendre(0.8)
	_verifier(_contient(get_tree().current_scene, "Classement · n° 3"), "bouton Classement de la carte")


## Vrai Worker (local) : envoi des points, rang, top des fans, équipes.
func _tester_serveur() -> void:
	EnLigne.identite = ClassementFans.identite_neuve(EnLigne._rng())
	EnLigne.moi = {}
	var m := {"id": "test:classement", "competition": {"id": "fr.1"}, "home": {"id": "af:85"}, "away": {"id": "af:81"}}
	Game.noter_duel_favori(m, "home", true, "stade")  # 30 points
	_verifier(Game.supporters["a_envoyer"].size() == 1, "un gain à envoyer")
	EnLigne.envoyer()
	await _attendre_que(func(): return Game.supporters["a_envoyer"].is_empty())
	_verifier(Game.supporters["a_envoyer"].is_empty(), "file vidée après l'envoi")
	_verifier(int(Game.supporters["envoye"].get("af:85", 0)) == 30, "30 points comptés par le serveur")
	_verifier(int(EnLigne.moi.get("points_semaine", 0)) == 30 and EnLigne.moi.get("rang_semaine") != null, "rang reçu : %s" % str(EnLigne.moi))
	EnLigne.fans.clear()
	EnLigne.rafraichir_fans("semaine")
	await _attendre_que(func(): return EnLigne.fans.has("semaine"))
	var dedans: bool = (EnLigne.fans.get("semaine", []) as Array).any(func(f): return f["id"] == EnLigne.identite["id"])
	_verifier(dedans, "dans le top des fans de la semaine")
	await _attendre(61.0)  # cache d'une minute du serveur
	EnLigne.equipes.clear()
	EnLigne.rafraichir_equipes()
	await _attendre_que(func(): return not EnLigne.equipes.is_empty())
	_verifier(int(EnLigne.equipes.get("af:85", {}).get("p", 0)) >= 30, "points du club sur le serveur")
	_verifier(int(EnLigne.communaute().get("af:85", -1)) >= 0, "communauté calculée")
