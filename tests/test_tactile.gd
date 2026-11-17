extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_tactile.gd
## Commandes au doigt du téléphone (CommandesTactiles) : joystick, boutons,
## plusieurs doigts à la fois, toucher libre.

var _echecs := 0
var _appuis: Array = []
var _relaches: Array = []
var _libres: Array = []
var _c: CommandesTactiles


func _init() -> void:
	var c := CommandesTactiles.new()
	_c = c
	root.add_child(c)
	await process_frame
	c.set_anchors_preset(Control.PRESET_TOP_LEFT)
	c.position = Vector2.ZERO
	c.size = Vector2(1920, 1080)
	c.ajouter_bouton("tir", "Tir", Color.YELLOW, Vector2(-110, -130), 100.0)
	c.ajouter_bouton("super", "Super", Color.PINK, Vector2(-310, -80))
	c.appui.connect(func(id): _appuis.append(id))
	c.relache.connect(func(id): _relaches.append(id))
	c.toucher_libre.connect(func(p): _libres.append(p))
	await process_frame

	# doigt 0 sur le joystick, poussé vers la droite
	var cj := c.centre_joystick()
	_toucher(0, cj, true)
	_glisser(0, cj + Vector2(200, 0))
	_verifier(c.direction.is_equal_approx(Vector2.RIGHT), "joystick poussé à droite : direction (1, 0) (%s)" % c.direction)
	# doigt 1 sur Tir pendant que le joystick est tenu
	_toucher(1, c.centre_bouton("tir"), true)
	_verifier(_appuis == ["tir"], "Tir appuyé avec un second doigt")
	_verifier(c.direction.is_equal_approx(Vector2.RIGHT), "le joystick reste tenu")
	_toucher(1, c.centre_bouton("tir"), false)
	_verifier(_relaches == ["tir"], "Tir relâché")
	# petite poussée : zone morte
	_glisser(0, cj + Vector2(10, 0))
	_verifier(c.direction == Vector2.ZERO, "zone morte au centre du joystick")
	_toucher(0, cj, false)
	_verifier(c.direction == Vector2.ZERO, "joystick lâché : plus de direction")
	# doigt posé sur le terrain
	_toucher(2, Vector2(960, 300), true)
	_verifier(_libres.size() == 1 and _libres[0] == Vector2(960, 300), "toucher libre au milieu de l'écran")
	# bouton grisé : toujours touchable (la partie décide), mais affiché grisé
	c.regler_bouton("super", false, 0.4)
	_verifier(not c.boutons["super"]["actif"] and is_equal_approx(c.boutons["super"]["remplissage"], 0.4), "Super grisé et en charge")
	# lâcher tout (pause)
	_toucher(3, c.centre_bouton("super"), true)
	c.relacher_tout()
	_verifier(_relaches == ["tir", "super"], "pause : les boutons tenus sont relâchés")

	print("Tests tactile : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs else 0)


func _toucher(index: int, p: Vector2, presse: bool) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = p
	ev.pressed = presse
	_c._input(ev)  # directement : la fenêtre sans écran fausse les positions


func _glisser(index: int, p: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	ev.position = p
	_c._input(ev)  # directement : la fenêtre sans écran fausse les positions


func _verifier(ok: bool, texte: String) -> void:
	if ok:
		print("  ok  ", texte)
	else:
		_echecs += 1
		print("ÉCHEC ", texte)
