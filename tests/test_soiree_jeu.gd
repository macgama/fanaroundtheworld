extends Node
## Soir de match branché dans le jeu (autoloads chargés) :
## godot --headless --path . res://tests/test_soiree_jeu.tscn -- --hors-ligne
## Un faux live (Donnees.injecter_live) fait marquer des buts : la tribune les
## voit, les mini-ambiances (tifo, ola, chant) paient une seule fois par but,
## un but annulé puis redonné ne repaie pas, la fin du match verse la prime.
## Avec « --captures=dossier » (et un écran, xvfb-run), enregistre des captures.
## La sauvegarde du joueur est remise en état à la fin.

const ID := "test:soiree"
var _echecs := 0
var _dossier := ""
var _minute := 10


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _live(dom: int, ext: int, statut := "LIVE") -> void:
	var t := int(Time.get_unix_time_from_system()) - _minute * 60
	Donnees.injecter_live({"matches": [{
		"id": ID, "status": statut, "minute": _minute, "competition": {"id": "fr.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(t) + ".000Z",
		"home": {"id": "af:85"}, "away": {"id": "af:81"},
		"score": {"current": {"home": dom, "away": ext}},
	}]})


func _capture(nom: String) -> void:
	if _dossier == "":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_dossier.path_join(nom + ".png"))


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	if get_tree().current_scene == self:
		# l'écran testé remplace la scène courante : le test tourne à côté, sous la racine
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteSoiree"
		get_tree().root.add_child.call_deferred(pilote)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--captures="):
			_dossier = a.trim_prefix("--captures=")
	await get_tree().process_frame
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	Game.reinitialiser()
	Game.actualiser_missions()
	Game.missions["de_la_semaine"][0] = Missions._nouvelle(Missions._modele(Missions.SEMAINE, "s_soiree3"))
	var source := Donnees.source
	Donnees.source = "en ligne"  # pas la démo : de vrais gains
	_live(0, 0)

	Game.aller(Game.SCENE_SOIREE, {"match_id": ID, "camp": "home", "mode": "stade", "cout": 0})
	await _attendre(1.0)
	var s: SoireeEcran = get_tree().current_scene
	_verifier(s is SoireeEcran and not s.simule, "écran du soir de match ouvert, pas en démo")
	_verifier(s.etat == "attente", "en attente du premier but")
	s._reagir("allez")
	s._reagir("echarpe")
	await _capture("1-attente")

	# 1-0 : tifo parfait
	_minute = 23
	_live(1, 0)
	_verifier(s.etat == "celebration", "but vu : la tribune célèbre (%s)" % s.etat)
	await _attendre(0.5)
	await _capture("2-but")
	await _attendre(2.4)
	_verifier(s.etat == "choix", "choix de la mini-ambiance")
	await _capture("3-choix")
	var jetons := Game.jetons
	s._lancer_ambiance("tifo")
	_verifier(s.etat == "tifo", "tifo lancé")
	for i in SoireeMatch.PANS_TIFO:
		s._tifo_tenir(true)
		s._tifo.valeur = float(s._tifo.cibles[i]) + 0.02
		if i == 1:
			await _attendre(0.1)
			await _capture("4-tifo")
		s._tifo_tenir(false)
	await _attendre(0.2)
	_verifier(s.etat == "resultat", "tifo fini (%s)" % s.etat)
	await _attendre(0.3)
	await _capture("5-resultat-tifo")
	_verifier(Game.jetons > jetons, "le tifo rapporte des Jetons (%d → %d)" % [jetons, Game.jetons])
	_verifier("1-0" in Game.soiree_de(ID)["buts"], "but 1-0 noté")
	await _attendre(3.0)
	_verifier(s.etat == "attente", "retour au calme")

	# le relais relit le même score : rien
	_live(1, 0)
	_verifier(s.etat == "attente", "même score : pas de but")

	# 2-0 : ola
	_minute = 51
	_live(2, 0)
	await _attendre(2.8)
	jetons = Game.jetons
	s._lancer_ambiance("ola")
	s._ola_touche(s._ola_seq[0])
	s._ola_touche(s._ola_seq[1])
	await _capture("6-ola")
	for i in range(2, s._ola_seq.size()):
		s._ola_touche(s._ola_seq[i])
	_verifier(s.etat == "resultat" and Game.jetons > jetons, "ola réussie et payée")
	await _attendre(3.2)

	# 2-1 : but adverse, chant (moitié des gains)
	_minute = 67
	_live(2, 1)
	_verifier(s.etat == "celebration" and not s._but["pour_nous"], "but adverse vu")
	await _attendre(2.8)
	jetons = Game.jetons
	s._lancer_ambiance("chant")
	_verifier(s.etat == "chant" and s._chant_stats["total"] > 0, "chant lancé avec ses notes")
	await _attendre(2.2)
	await _capture("7-chant")
	s._finir_ambiance(1.0)
	var attendu: int = SoireeMatch.recompense(1.0, false, Game.gain_suivi("stade"), s.ferveur - 25.0)["jetons"]
	_verifier(Game.jetons - jetons >= attendu - 1 and Game.jetons - jetons <= attendu + 1, "but adverse : gains réduits (%d, attendu ≈ %d)" % [Game.jetons - jetons, attendu])
	await _attendre(3.2)

	# arbitrage vidéo : 2-1 annulé puis redonné : vu, mais pas repayé
	_live(2, 0)
	_verifier(s.etat == "attente", "but annulé : pas de mini-ambiance")
	_live(2, 1)
	await _attendre(2.8)
	jetons = Game.jetons
	s._lancer_ambiance("ola")
	for d in s._ola_seq:
		s._ola_touche(d)
	_verifier(Game.jetons == jetons, "but redonné : pas payé deux fois")
	await _attendre(3.2)
	_verifier(Game.missions["de_la_semaine"][0]["progres"] == 3, "mission Soirs de match : 3/3 (%s)" % str(Game.missions["de_la_semaine"][0]["progres"]))
	_verifier((Game.soiree_de(ID)["fil"] as Array).size() == 4, "fil : 4 buts vus")

	# coup de sifflet final : prime une seule fois
	Game.soiree_de(ID)["debut"] -= 3600
	jetons = Game.jetons
	_minute = 94
	_live(2, 1, "FINISHED")
	_verifier(s.etat == "fin", "fin du match")
	_verifier(Game.jetons == jetons + SoireeMatch.prime_fin(1.5)["jetons"], "prime de fin versée")
	await _attendre(0.6)
	await _capture("8-fin")
	_verifier(Game.prime_fin_soiree(Donnees.match_par_id(ID), "stade").is_empty(), "prime une seule fois")

	Game.charger()
	_verifier((Game.soiree_de(ID)["buts"] as Array).size() == 3, "sauvegardé : 3 buts payés")

	# démo : buts simulés, rien de payé
	Donnees.source = "exemple"
	_minute = 30
	_live(0, 0)
	Game.aller(Game.SCENE_SOIREE, {"match_id": ID, "camp": "away", "mode": "pub", "cout": 0})
	await _attendre(0.8)
	s = get_tree().current_scene
	_verifier(s.simule, "démo : buts simulés")
	jetons = Game.jetons
	s._simuler_but(true)
	await _attendre(2.8)
	s._lancer_ambiance("tifo")
	for i in SoireeMatch.PANS_TIFO:
		s._tifo_tenir(true)
		s._tifo.valeur = float(s._tifo.cibles[i])
		s._tifo_tenir(false)
	await _attendre(0.2)
	_verifier(s.etat == "resultat" and Game.jetons == jetons, "démo : pas de Jetons")
	Donnees.source = source

	Game.reinitialiser()
	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.CHEMIN_SAUVEGARDE))
	print("Tests soir de match (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)
