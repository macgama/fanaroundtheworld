extends Node
## Tous les écrans à la vraie souris (événements envoyés à la fenêtre) :
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 res://tests/test_souris_ecrans.tscn -- --hors-ligne
## Pour chaque écran de test_ecrans : la souris passe au centre de chaque bouton
## visible ; le bouton doit s'allumer (survol). Sinon, quelque chose le recouvre
## et avale les clics (fond, panneau, voile invisible…). Puis un vrai clic sur
## chaque bouton (écran rouvert avant chaque clic) doit déclencher « pressed ».
## Option : « --ecran=nom ».

var _echecs := 0
var _ecrans: Dictionary
var _bilan: Array = []


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteSouris"
		pilote.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(pilote)
		return
	var ref: Node = load("res://tests/test_ecrans.gd").new()
	_ecrans = ref._ecrans
	ref.free()
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ecran="):
			seul = a.trim_prefix("--ecran=")
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var tuto := FileAccess.get_file_as_string(Tutoriel.CHEMIN)
	var options := FileAccess.get_file_as_string(Reglages.CHEMIN)
	Tutoriel.passer()
	Game.jetons = 5000
	for nom in _ecrans:
		if seul != "" and nom != seul:
			continue
		await _tester(nom)
	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	_restaurer(Tutoriel.CHEMIN, tuto)
	_restaurer(Reglages.CHEMIN, options)
	for l in _bilan:
		print(l)
	print("Tests souris : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs else 0)


func _tester(nom: String) -> void:
	var e: Array = _ecrans[nom]
	await _ouvrir(e)
	var bs := _boutons_cliquables()
	var n := bs.size()
	var ko := 0
	for b in bs:
		if not is_instance_valid(b) or not b.is_visible_in_tree():
			continue
		var c := (b as Control).get_global_rect().get_center()
		await _bouger(c)
		if not (b as BaseButton).is_hovered():
			ko += 1
			_echec(nom, "« %s » ne réagit pas à la souris (recouvert par %s)" % [_nom(b), _dessus(c)])
	# zones cliquables hors boutons (toile du tifo, piste de chant, FANZZY…),
	# à l'ouverture puis après le compte à rebours
	var nz := 0
	for passe in 2:
		if passe == 1:
			await get_tree().create_timer(5.0, true, false, true).timeout
		var zs := _zones()
		nz = maxi(nz, zs.size())
		for z in zs:
			if not is_instance_valid(z) or not z.is_visible_in_tree():
				continue
			var cz := (z as Control).get_global_rect().get_center()
			await _bouger(cz)
			var h := get_viewport().gui_get_hovered_control()
			if h == null or not (h == z or z.is_ancestor_of(h)):
				ko += 1
				_echec(nom, "zone %s recouverte par %s" % [z.get_path(), h.get_path() if h else "rien"])
	# vrais clics, écran rouvert à chaque fois
	for i in n:
		await _ouvrir(e)
		var bs2 := _boutons_cliquables()
		if i >= bs2.size():
			break
		var b: BaseButton = bs2[i]
		if _nom(b) in ["QUITTER", "Quitter"]:
			continue
		var recu := [false]
		var f := func() -> void: recu[0] = true
		b.pressed.connect(f)
		await _cliquer(b.get_global_rect().get_center())
		if is_instance_valid(b):
			if b.pressed.is_connected(f):
				b.pressed.disconnect(f)
		if not recu[0] and b.is_hovered():
			_echec(nom, "clic sur « %s » sans effet" % _nom(b))
		# un jeu au clavier : après un clic, Espace/Entrée doivent revenir au jeu,
		# pas réappuyer sur le bouton cliqué (focus resté dessus)
		var touches: Array = e[2]
		if (KEY_SPACE in touches or KEY_ENTER in touches) and not get_tree().paused:
			var fo := get_viewport().gui_get_focus_owner()
			if fo is BaseButton and fo.is_visible_in_tree() and get_tree().current_scene.scene_file_path == e[0]:
				_echec(nom, "après un clic, « %s » garde le focus : Espace/Entrée appuierait dessus au lieu de jouer" % _nom(fo))
	get_tree().paused = false
	_bilan.append("[%s] %d boutons, %d zones, %d recouverts" % [nom, n, nz, ko])


## Boutons visibles, actifs, dont le centre est à l'écran et non coupé par un
## conteneur à défilement.
func _boutons_cliquables() -> Array:
	var r: Array = []
	_collecter(get_tree().root, r)
	var vis := get_viewport().get_visible_rect()
	return r.filter(func(b: BaseButton) -> bool:
		if b.disabled or b.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return false
		var c := b.get_global_rect().get_center()
		if not vis.has_point(c):
			return false
		var p := b.get_parent()
		while p != null:
			if p is ScrollContainer and not (p as Control).get_global_rect().has_point(c):
				return false
			p = p.get_parent()
		return true)


## Controls qui lisent la souris eux-mêmes (_gui_input ou signal gui_input).
func _zones() -> Array:
	var tous: Array = []
	_tous_controles(get_tree().root, tous)
	var vis := get_viewport().get_visible_rect()
	return tous.filter(func(c: Control) -> bool:
		if c is BaseButton or c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			return false
		if c is LineEdit or c is TextEdit or c is ScrollBar or c is Slider or c is ScrollContainer:
			return false
		if c.get("interactive") == false:  # carte décorative (voyage)
			return false
		if c.size.x < 4 or c.size.y < 4 or not vis.has_point(c.get_global_rect().get_center()):
			return false
		var lit := not c.get_signal_connection_list("gui_input").is_empty()
		var sc: Script = c.get_script()
		while not lit and sc != null:
			for m in sc.get_script_method_list():
				if m["name"] == "_gui_input":
					lit = true
			sc = sc.get_base_script()
		return lit)


func _collecter(n: Node, r: Array) -> void:
	if n == self:
		return
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is BaseButton:
		r.append(n)
	for c in n.get_children():
		_collecter(c, r)


## Le Control le plus haut qui prend la souris à ce point (pour le message).
func _dessus(p: Vector2) -> String:
	var meilleur: Control = null
	var tous: Array = []
	_tous_controles(get_tree().root, tous)
	for c in tous:
		var ctl := c as Control
		if ctl.mouse_filter == Control.MOUSE_FILTER_IGNORE or not ctl.get_global_rect().has_point(p):
			continue
		meilleur = ctl  # ordre de l'arbre ≈ ordre d'affichage
	return str(meilleur.get_path()) if meilleur else "?"


func _tous_controles(n: Node, r: Array) -> void:
	if n == self:
		return
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is Control:
		r.append(n)
	for c in n.get_children():
		_tous_controles(c, r)


func _nom(b: Node) -> String:
	if b is Button and (b as Button).text != "":
		return (b as Button).text.replace("\n", " ")
	return str(b.get_path())


func _ecran(p: Vector2) -> Vector2:
	var vp := get_viewport()
	return vp.get_screen_transform() * vp.get_final_transform() * p


func _bouger(p: Vector2) -> void:
	var s := _ecran(p)
	Input.warp_mouse(s)
	var m := InputEventMouseMotion.new()
	m.position = s
	m.global_position = s
	Input.parse_input_event(m)
	await get_tree().process_frame
	await get_tree().process_frame


func _cliquer(p: Vector2) -> void:
	await _bouger(p)
	var s := _ecran(p)
	for presse in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = presse
		ev.position = s
		ev.global_position = s
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _ouvrir(e: Array) -> void:
	get_tree().paused = false
	Game.aller(e[0], (e[1] as Dictionary).duplicate(true))
	await get_tree().create_timer(0.7, true, false, true).timeout


func _echec(ecran: String, msg: String) -> void:
	_echecs += 1
	printerr("ÉCHEC [%s] %s" % [ecran, msg])


func _restaurer(chemin: String, contenu: String) -> void:
	if contenu != "":
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_string(contenu)
	elif FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
