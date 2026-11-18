extends Node
## Gestes de jeu à la vraie souris / au doigt (événements envoyés à la fenêtre) :
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 res://tests/test_gestes_souris.tscn -- --hors-ligne
## Créateur de chant (toucher l'écran = taper le rythme au doigt, Espace après un
## clic sur un bouton), peinture du tifo (glisser), soir de match (clic sur la
## piste du chant, maintien sur le tifo, flèches de l'ola).

var _echecs := 0


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteGestes"
		pilote.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(pilote)
		return
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var tuto := FileAccess.get_file_as_string(Tutoriel.CHEMIN)
	Tutoriel.passer()
	await _chant_au_doigt()
	await _chant_espace_apres_clic()
	await _tifo_peinture()
	await _soiree()
	await _carte()
	await _azerty()
	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	_restaurer(Tutoriel.CHEMIN, tuto)
	print("ÉCHECS : %d" % _echecs)
	get_tree().quit(1 if _echecs > 0 else 0)


func _chant_au_doigt() -> void:
	Mobile.tactile = true
	var sc := await _ouvrir(Game.SCENE_CHANT, {})
	var appuis := [0]
	sc._lecteur.appui_juge.connect(func(_r): appuis[0] += 1)
	sc._ecouter()
	await _attendre(0.3)
	await _cliquer(Vector2(1905, 540))  # marge de droite : rien que le fond
	_verifier(appuis[0] == 1, "chant au doigt : toucher la marge pendant l'écoute = un appui (%d)" % appuis[0])
	for cible in [sc._karaoke, sc._verdict]:
		var n: int = appuis[0]
		await _cliquer((cible as Control).get_global_rect().get_center())
		_verifier(appuis[0] == n + 1, "chant au doigt : toucher %s = un appui" % (cible as Node).name)
	Mobile.tactile = false


func _chant_espace_apres_clic() -> void:
	var sc := await _ouvrir(Game.SCENE_CHANT, {})
	var avant: String = JSON.stringify(sc.compo)
	var hasard: Button = _bouton("Au hasard")
	_verifier(hasard != null, "chant : bouton Au hasard")
	if hasard == null:
		return
	await _cliquer(hasard.get_global_rect().get_center())
	var apres_hasard: String = JSON.stringify(sc.compo)
	_verifier(apres_hasard != avant, "chant : clic sur Au hasard change le chant")
	await _touche(KEY_SPACE)
	_verifier(sc._lecteur.en_cours, "chant : Espace après un clic lance l'écoute")
	_verifier(JSON.stringify(sc.compo) == apres_hasard, "chant : Espace ne réappuie pas sur Au hasard")


func _tifo_peinture() -> void:
	var sc := await _ouvrir(Game.SCENE_TIFO, {})
	await _attendre(4.0)
	_verifier(sc.pret, "tifo : la partie a commencé")
	var g: Control = sc._grille
	var avant: PackedInt32Array = sc.bache.duplicate()
	var r := g.get_global_rect()
	var a := r.position + r.size * Vector2(0.3, 0.5)
	var b := r.position + r.size * Vector2(0.7, 0.5)
	await _bouger(a)
	await _bouton_souris(a, true)
	for k in range(1, 11):
		await _bouger(a.lerp(b, k / 10.0), MOUSE_BUTTON_MASK_LEFT)
	await _bouton_souris(b, false)
	var n := 0
	for i in sc.bache.size():
		if sc.bache[i] != avant[i]:
			n += 1
	_verifier(n >= 5, "tifo : glisser la souris peint une ligne (%d cases)" % n)


func _soiree() -> void:
	var p := {"match_id": "ex:1", "camp": "home", "mode": "ecran", "cout": 0, "simuler": true}
	# chant : une réaction à la souris, puis but : Espace lance le chant
	var sc := await _ouvrir(Game.SCENE_SOIREE, p)
	await _attendre(1.0)
	var allez := _bouton_commence("Allez")
	if allez:
		await _cliquer(allez.get_global_rect().get_center())
	await _touche(KEY_B)
	await _attendre(2.5)
	await _touche(KEY_SPACE)
	_verifier(sc.etat == "chant", "soirée : après un clic sur « Allez ! », Espace lance bien le chant (%s)" % sc.etat)
	# chant : clic sur le bouton puis clics sur la piste
	sc = await _ouvrir(Game.SCENE_SOIREE, p)
	await _attendre(1.0)
	await _touche(KEY_B)
	await _attendre(2.5)
	var b := _bouton_commence("CHANT")
	_verifier(sc.etat == "choix" and b != null, "soirée : après un but, choix de l'ambiance (%s)" % sc.etat)
	if b:
		await _cliquer(b.get_global_rect().get_center())
		_verifier(sc.etat == "chant", "soirée : clic sur CHANT lance le chant (%s)" % sc.etat)
		var appuis := [0]
		sc._lecteur.appui_juge.connect(func(_r): appuis[0] += 1)
		await _cliquer(sc._piste.get_global_rect().get_center())
		_verifier(appuis[0] == 1, "soirée : clic sur la piste = un appui (%d)" % appuis[0])
		await _touche(KEY_SPACE)
		_verifier(appuis[0] == 2, "soirée : Espace après le clic = un appui (%d)" % appuis[0])
	# tifo : maintenir le clic
	sc = await _ouvrir(Game.SCENE_SOIREE, p)
	await _attendre(1.0)
	await _touche(KEY_B)
	await _attendre(2.5)
	b = _bouton_commence("TIFO")
	if b:
		await _cliquer(b.get_global_rect().get_center())
		_verifier(sc.etat == "tifo", "soirée : clic sur TIFO lance le tifo (%s)" % sc.etat)
		await _attendre(0.3)
		var c: Vector2 = sc._tifo.get_global_rect().get_center()
		await _bouger(c)
		await _bouton_souris(c, true)
		await _attendre(0.5)
		await _bouton_souris(c, false)
		_verifier(sc._tifo.ecarts.size() == 1, "soirée : maintenir le clic sur le tifo lève un pan (%d)" % sc._tifo.ecarts.size())
	# ola : clic sur la première flèche
	sc = await _ouvrir(Game.SCENE_SOIREE, p)
	await _attendre(1.0)
	await _touche(KEY_B)
	await _attendre(2.5)
	b = _bouton_commence("OLA")
	if b:
		await _cliquer(b.get_global_rect().get_center())
		_verifier(sc.etat == "ola", "soirée : clic sur OLA lance l'ola (%s)" % sc.etat)
		await _attendre(0.3)
		var fl: Control = sc._ola_fleches[0] if not sc._ola_fleches.is_empty() else null
		_verifier(fl != null, "soirée : flèches de l'ola affichées")
		if fl:
			var avant: int = sc._ola_i + sc._ola_err
			await _cliquer(fl.get_global_rect().get_center())
			var apres: int = sc._ola_i + sc._ola_err
			_verifier(apres == avant + 1, "soirée : clic sur une flèche de l'ola compte (%d -> %d)" % [avant, apres])


func _carte() -> void:
	var sc := await _ouvrir(Game.SCENE_CARTE, {})
	await _attendre(1.5)
	var carte: Control = sc.get("carte")
	_verifier(carte is CarteMonde, "carte : la carte du monde est là")
	if not carte is CarteMonde:
		return
	# glisser : la carte se déplace
	var r := carte.get_global_rect()
	var a := r.get_center()
	var c0: Vector2 = carte._centre
	await _bouger(a)
	await _bouton_souris(a, true)
	for k in range(1, 9):
		await _bouger(a + Vector2(-30 * k, 0), MOUSE_BUTTON_MASK_LEFT)
	await _bouton_souris(a + Vector2(-240, 0), false)
	_verifier(carte._centre.x > c0.x + 50, "carte : glisser la souris déplace la carte (%.0f -> %.0f)" % [c0.x, carte._centre.x])
	# molette : zoom
	var z0: float = carte._zoom
	await _bouger(a)
	for presse in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_WHEEL_UP
		ev.pressed = presse
		ev.position = _ecran(a)
		ev.global_position = _ecran(a)
		Input.parse_input_event(ev)
		await get_tree().process_frame
	_verifier(carte._zoom > z0, "carte : la molette zoome (%.2f -> %.2f)" % [z0, carte._zoom])
	# clic sur une épingle : elle répond
	var vues := [0]
	carte.epingle_cliquee.connect(func(_e): vues[0] += 1)
	var cible := Vector2(-1, -1)
	for i in range(carte.epingles.size() - 1, -1, -1):
		var e: Dictionary = carte.epingles[i]
		var rr := 30.0 if e.get("type", "") != "stade" else 22.0
		var p: Vector2 = carte.vers_ecran(e["pos"]) - Vector2(0, rr * 1.4)
		var g: Vector2 = carte.get_global_transform() * p
		if get_viewport().get_visible_rect().grow(-40).has_point(g):
			await _bouger(g)
			var h := get_viewport().gui_get_hovered_control()
			if h == carte:
				cible = g
				break
	_verifier(cible.x >= 0, "carte : une épingle visible et non recouverte")
	if cible.x >= 0:
		await _cliquer(cible)
		_verifier(vues[0] == 1, "carte : clic sur une épingle (%d)" % vues[0])


## Clavier français : la touche « 1 » sans Maj donne « & » (keycode), mais
## sa touche physique reste KEY_1. Les chiffres doivent marcher quand même.
func _azerty() -> void:
	var sc := await _ouvrir(Game.SCENE_POUSSEE, {"match_id": "ex:1", "camp": "home", "mode": "pub", "cout": 0})
	await _attendre(4.5)
	if sc.get("en_cours") == true:
		sc.selection = -1
		await _touche_fr(KEY_1, KEY_AMPERSAND)
		_verifier(sc.selection == 0, "AZERTY : Poussée, touche 1 (&) choisit la 1re carte (%d)" % sc.selection)
		await _touche_fr(KEY_2, KEY_QUOTEDBL)
		_verifier(sc.selection == 1, "AZERTY : Poussée, touche 2 (é, ici un code ≠ 2) choisit la 2e carte (%d)" % sc.selection)
	sc = await _ouvrir(Game.SCENE_SOIREE, {"match_id": "ex:1", "camp": "home", "mode": "ecran", "cout": 0, "simuler": true})
	await _attendre(1.0)
	if sc.etat == "attente":
		var f0: float = sc.ferveur
		await _touche_fr(KEY_1, KEY_AMPERSAND)
		_verifier(sc._recharges.has("allez"), "AZERTY : soirée, touche 1 (&) = « Allez ! » (ferveur %.0f -> %.0f)" % [f0, sc.ferveur])


func _touche_fr(physique: Key, logique: Key) -> void:
	for appui in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = logique
		ev.physical_keycode = physique
		ev.unicode = logique if logique < 0x10000 else 0
		ev.pressed = appui
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


# ------------------------------------------------------------------ outils

func _ouvrir(scene: String, p: Dictionary) -> Node:
	get_tree().paused = false
	Game.aller(scene, p.duplicate(true))
	await _attendre(0.8)
	return get_tree().current_scene


func _bouton(texte: String) -> Button:
	for b in _boutons(get_tree().root):
		if b.text == texte:
			return b
	return null


func _bouton_commence(texte: String) -> Button:
	for b in _boutons(get_tree().root):
		if b.text.begins_with(texte):
			return b
	return null


func _boutons(n: Node) -> Array:
	var r: Array = []
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return r
	if n is Button:
		r.append(n)
	for c in n.get_children():
		r.append_array(_boutons(c))
	return r


func _ecran(p: Vector2) -> Vector2:
	var vp := get_viewport()
	return vp.get_screen_transform() * vp.get_final_transform() * p


func _bouger(p: Vector2, masque := 0) -> void:
	var s := _ecran(p)
	Input.warp_mouse(s)
	var m := InputEventMouseMotion.new()
	m.position = s
	m.global_position = s
	m.button_mask = masque
	Input.parse_input_event(m)
	await get_tree().process_frame
	await get_tree().process_frame


func _bouton_souris(p: Vector2, presse: bool) -> void:
	var s := _ecran(p)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = presse
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if presse else 0
	ev.position = s
	ev.global_position = s
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _cliquer(p: Vector2) -> void:
	await _bouger(p)
	await _bouton_souris(p, true)
	await _bouton_souris(p, false)


func _touche(k: int) -> void:
	for appui in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = k
		ev.physical_keycode = k
		ev.pressed = appui
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _attendre(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _verifier(ok: bool, texte: String) -> void:
	print(("OK    " if ok else "ÉCHEC ") + texte)
	if not ok:
		_echecs += 1


func _restaurer(chemin: String, contenu: String) -> void:
	if contenu != "":
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_string(contenu)
	elif FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
