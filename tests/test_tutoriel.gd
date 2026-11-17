extends Node
## Le tutoriel joué de bout en bout, dans le vrai jeu (autoloads chargés) :
## godot --headless --path . res://tests/test_tutoriel.tscn -- --hors-ligne
## Avec un écran (xvfb-run), « --captures=dossier » enregistre une image par étape.
## La sauvegarde du joueur et l'état du tutoriel sont remis en place à la fin.

var _echecs := 0
var _captures := ""


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _ready() -> void:
	# La scène de test est remplacée à chaque écran : le pilote vit à côté.
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteTutoriel"
		get_tree().root.add_child.call_deferred(pilote)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_captures = a.trim_prefix("--captures=")
	await _attendre(0.3)
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var tuto := FileAccess.get_file_as_string(Tutoriel.CHEMIN)
	Game.reinitialiser()
	Tutoriel.effacer()
	_verifier(not Tutoriel.actif(), "pas de tutoriel avant d'appuyer sur Jouer")

	# Écran d'accueil → JOUER : nouveau joueur, le tutoriel démarre
	Game.aller(Game.SCENE_TITRE)
	await _attendre(1.0)
	await _capture("0-accueil")
	var accueil := get_tree().current_scene
	accueil._ouvrir_options()
	await _attendre(0.3)
	await _capture("0-options")
	_verifier(Tutoriel._trouver("Revoir le tutoriel") != null, "options : revoir le tutoriel")
	accueil._confirmer_raz()
	await _attendre(0.3)
	await _capture("0-raz")
	_appuyer("Non, je garde tout")
	accueil._options.queue_free()
	await _attendre(0.2)
	_appuyer("JOUER")
	await _attendre(0.5)
	_verifier(Tutoriel.etape == "club", "1re étape : fonder le club (%s)" % Tutoriel.etape)
	_verifier(_bulle_visible(), "bulle visible à la création du club")
	await _capture("1-club")
	var champ := Tutoriel._trouver("LineEdit") as LineEdit
	_verifier(champ != null, "champ du nom trouvé")
	champ.text = "Les Tests Joyeux"
	champ.text_changed.emit(champ.text)
	await _attendre(0.2)
	_appuyer("FONDER")
	await _attendre(0.5)
	_verifier(Game.club_cree() and Tutoriel.etape == "qg", "club fondé, étape QG (%s)" % Tutoriel.etape)
	_verifier(_bulle_visible(), "bulle visible au QG")
	await _capture("2-qg")
	Tutoriel._bouton.pressed.emit()
	await _attendre(0.5)
	_verifier(Tutoriel.etape == "favoris" and _scene() == Game.SCENE_FAVORIS, "étape équipes favorites")
	await _capture("3-favoris")
	Tutoriel._bouton.pressed.emit()  # « Plus tard » : vers la carte
	await _attendre(0.8)
	_verifier(Tutoriel.etape == "match" and _scene() == Game.SCENE_CARTE, "étape choix du match (%s)" % Tutoriel.etape)
	await _capture("4-match")

	# Ouvrir un match à venir dans la fiche
	var id := ""
	for m in Donnees.matchs():
		if Game.peut_pronostiquer(m) == "":
			id = str(m["id"])
			break
	_verifier(id != "", "un match à venir dans les données")
	get_tree().current_scene._choisir_match(id)
	await _attendre(0.5)
	_verifier(Tutoriel.etape == "prono", "étape prono (%s)" % Tutoriel.etape)
	await _capture("5-prono")
	_appuyer("Valider mon prono")
	await _attendre(0.5)
	_verifier(Game.pronos.has(id), "prono enregistré")
	_verifier(Tutoriel.etape == "lieu", "étape lieu (%s)" % Tutoriel.etape)
	await _capture("6-lieu")
	Game.jetons = 999  # le stade peut coûter cher : on veut voir le voyage
	_appuyer("C'EST PARTI")
	await _attendre(0.5)
	_verifier(Tutoriel.etape in ["deplacement", "voyage", "tribune"], "étape déplacement, voyage ou tribune (%s)" % Tutoriel.etape)
	if Tutoriel.etape == "deplacement":
		await _capture("7-deplacement")
		_appuyer("EN ROUTE")
		# en route : premier choix possible à chaque événement, jusqu'à l'arrivée
		for _i in 160:
			if _scene() == Game.SCENE_VOYAGE:
				break
			var choix := Tutoriel._trouver("1. ") as Button
			if choix and not choix.disabled:
				choix.pressed.emit()
			await _attendre(0.25)
		_verifier(Tutoriel.etape == "voyage", "étape voyage après le déplacement (%s)" % Tutoriel.etape)
	if Tutoriel.etape == "voyage":
		for _i in 40:
			if Tutoriel._trouver("ENTRER DANS LE STADE"):
				break
			await _attendre(0.25)
		await _capture("7-voyage")
		_appuyer("ENTRER DANS LE STADE")
		await _attendre(0.5)
	_verifier(Tutoriel.etape == "tribune", "étape tribune (%s)" % Tutoriel.etape)
	await _capture("8-tribune")
	_appuyer("DUEL D'AMBIANCE")
	await _attendre(1.0)
	_verifier(Tutoriel.etape == "duel" and _scene() == Game.SCENE_DUEL, "étape duel (%s)" % Tutoriel.etape)
	await _capture("9-duel")
	# fin de duel simulée (le vrai dure 90 s)
	get_tree().current_scene._finir()
	await _attendre(0.5)
	_verifier(Tutoriel.etape == "bravo", "étape bravo (%s)" % Tutoriel.etape)
	_verifier(_bulle_visible(), "bulle de fin visible")
	await _capture("10-bravo")
	var avant := Game.jetons
	Tutoriel._bouton.pressed.emit()
	_verifier(Game.jetons == avant + Tutoriel.RECOMPENSE, "cadeau de bienvenue versé")
	_verifier(not Tutoriel.actif() and Tutoriel.fini, "tutoriel terminé")
	_verifier(Tutoriel.terminer() == 0, "cadeau versé une seule fois")

	# Retour à la carte en plein tutoriel : on reprend au choix du match
	Tutoriel.demarrer()
	Tutoriel._aller_a("duel")
	Game.aller(Game.SCENE_CARTE)
	await _attendre(0.5)
	_verifier(Tutoriel.etape == "match", "duel abandonné : retour au choix du match (%s)" % Tutoriel.etape)
	Tutoriel.passer()
	_verifier(not Tutoriel.actif() and not _bulle_visible(), "tutoriel passé, bulle cachée")

	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	_restaurer(Tutoriel.CHEMIN, tuto)
	print("Tests tutoriel : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)


func _scene() -> String:
	var sc := get_tree().current_scene
	return sc.scene_file_path if sc else ""


func _bulle_visible() -> bool:
	return Tutoriel._bulle.visible


func _appuyer(debut: String) -> void:
	var b := Tutoriel._trouver(debut) as Button
	_verifier(b != null and not b.disabled, "bouton « %s » trouvé et actif" % debut)
	if b and not b.disabled:
		b.pressed.emit()


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _capture(nom: String) -> void:
	if _captures == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [_captures, nom])


func _restaurer(chemin: String, contenu: String) -> void:
	if contenu != "":
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_string(contenu)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
