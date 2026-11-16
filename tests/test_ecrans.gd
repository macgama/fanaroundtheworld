extends Node
## Tour de tous les écrans, dans le vrai jeu (autoloads chargés) :
##   godot --headless --path . res://tests/test_ecrans.tscn -- --hors-ligne
## Pour chaque écran : on l'ouvre, puis on appuie sur chacun de ses boutons
## (l'écran est rouvert avant chaque bouton) et on joue quelques secondes au
## clavier et à la souris. Toute erreur de script compte comme un échec.
## Options : « --ecran=nom » pour un seul écran, « --boutons=N » (30 par défaut).
## La sauvegarde du joueur est remise en place à la fin.

class Compteur extends Logger:
	var erreurs: Array = []
	var _m := Mutex.new()

	func _log_error(fonction: String, fichier: String, ligne: int, code: String, texte: String,
			_editeur: bool, type: int, _pile: Array[ScriptBacktrace]) -> void:
		if type == ERROR_TYPE_WARNING:
			return
		var t := "%s (%s:%d %s)" % [texte if texte != "" else code, fichier, ligne, fonction]
		_m.lock()
		erreurs.append(t)
		_m.unlock()

	func vider() -> Array:
		_m.lock()
		var e := erreurs.duplicate()
		erreurs.clear()
		_m.unlock()
		return e


## Écrans testés : nom → [scène, paramètres, touches à presser pendant le jeu].
var _ecrans := {
	"titre": [Game.SCENE_TITRE, {}, []],
	"carte": [Game.SCENE_CARTE, {}, []],
	"carte_pays": [Game.SCENE_CARTE, {"niveau": "pays", "pays": "France", "continent": "Europe"}, []],
	"voyage": [Game.SCENE_VOYAGE, {"match_id": "ex:1", "camp": "home", "mode": "stade", "cout": 0}, []],
	"tribune": [Game.SCENE_TRIBUNE, {"match_id": "ex:1", "camp": "home", "mode": "stade", "cout": 0}, []],
	"duel": [Game.SCENE_DUEL, {"match_id": "ex:1", "camp": "home", "mode": "pub", "cout": 0},
		[KEY_SPACE, KEY_T, KEY_O, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_B, KEY_N, KEY_ESCAPE]],
	"arene": [Game.SCENE_ARENE, {"match_id": "ex:1", "camp": "home", "mode": "pub", "cout": 0},
		[KEY_Z, KEY_Q, KEY_S, KEY_D, KEY_E, KEY_TAB, KEY_SPACE, KEY_SHIFT, KEY_ESCAPE]],
	"poussee": [Game.SCENE_POUSSEE, {"match_id": "ex:1", "camp": "home", "mode": "pub", "cout": 0},
		[KEY_1, KEY_2, KEY_3, KEY_4, KEY_ESCAPE]],
	"buvette": [Game.SCENE_BUVETTE, {}, [KEY_1, KEY_2, KEY_3, KEY_4, KEY_ENTER, KEY_SPACE, KEY_BACKSPACE, KEY_ESCAPE]],
	"boulots": [Game.SCENE_BOULOTS, {}, []],
	"speaker": [Game.SCENE_SPEAKER, {}, [KEY_1, KEY_2, KEY_3, KEY_4, KEY_ESCAPE]],
	"echarpes": ["res://scenes/echarpes/echarpes.tscn", {}, [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_R, KEY_ESCAPE]],
	"pronos": [Game.SCENE_PRONOS, {}, []],
	"missions": [Game.SCENE_MISSIONS, {}, []],
	"favoris": [Game.SCENE_FAVORIS, {}, []],
	"club": [Game.SCENE_CLUB, {}, []],
	"creation": [Game.SCENE_CREATION_CLUB, {}, []],
	"collection": [Game.SCENE_COLLECTION, {}, []],
	"album": [Game.SCENE_COLLECTION, {"onglet": "album"}, []],
	"salon": [Game.SCENE_SALON, {}, []],
	"classement": [Game.SCENE_CLASSEMENT, {}, []],
}

var _compteur := Compteur.new()
var _echecs := 0
var _max_boutons := 30


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteEcrans"
		pilote.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(pilote)
		return
	OS.add_logger(_compteur)
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ecran="):
			seul = a.trim_prefix("--ecran=")
		if a.begins_with("--boutons="):
			_max_boutons = int(a.trim_prefix("--boutons="))
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var tuto := FileAccess.get_file_as_string(Tutoriel.CHEMIN)
	Tutoriel.passer()
	Game.jetons = 5000
	for nom in _ecrans:
		if seul != "" and nom != seul:
			continue
		await _tester(nom)
	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	_restaurer(Tutoriel.CHEMIN, tuto)
	print("Tests écrans : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs else 0)


func _tester(nom: String) -> void:
	var e: Array = _ecrans[nom]
	await _ouvrir(e)
	_noter(nom, "ouverture")
	var textes := _boutons_visibles().map(func(b: Button) -> String: return _nom_bouton(b))
	print("[%s] %d boutons : %s" % [nom, textes.size(), ", ".join(textes.slice(0, _max_boutons))])
	for i in mini(textes.size(), _max_boutons):
		await _ouvrir(e)
		var bs := _boutons_visibles()
		if i >= bs.size():
			continue
		var b: Button = bs[i]
		if b.disabled:
			continue
		var t := _nom_bouton(b)
		if t in ["QUITTER", "Quitter"]:
			continue
		if b.toggle_mode:
			b.button_pressed = not b.button_pressed
		b.pressed.emit()
		await _attendre(0.5)
		_noter(nom, "bouton « %s »" % t)
		# un second niveau : la fenêtre ouverte par ce bouton
		var bs2 := _boutons_visibles()
		for b2 in bs2.slice(0, 12):
			if not is_instance_valid(b2) or b2.disabled or not b2.is_visible_in_tree():
				continue
			if b2 in bs or _nom_bouton(b2) in ["QUITTER", "Quitter"]:
				continue
			var t2 := _nom_bouton(b2)
			b2.pressed.emit()
			await _attendre(0.25)
			_noter(nom, "bouton « %s » puis « %s »" % [t, t2])
			break
	var touches: Array = e[2]
	if nom in ["duel", "arene", "poussee"]:
		await _tester_pause(nom, e)
	if not touches.is_empty():
		await _ouvrir(e)
		await _jouer(touches, 12.0)
		_noter(nom, "partie au clavier")


## Échap : pause (Reprendre / Abandonner), Échap à nouveau pour reprendre.
func _tester_pause(nom: String, e: Array) -> void:
	await _ouvrir(e)
	await _attendre(5.0)  # compte à rebours
	var sc := get_tree().current_scene
	_touche(KEY_ESCAPE, true)
	await _attendre(0.1)
	_touche(KEY_ESCAPE, false)
	_verifier_ici(get_tree().paused and sc.get_node_or_null("PausePartie") != null, nom, "Échap met en pause")
	_touche(KEY_ESCAPE, true)
	await _attendre(0.1)
	_touche(KEY_ESCAPE, false)
	await _attendre(0.1)
	_verifier_ici(not get_tree().paused and sc.get_node_or_null("PausePartie") == null, nom, "Échap reprend")
	_touche(KEY_ESCAPE, true)
	await _attendre(0.1)
	_touche(KEY_ESCAPE, false)
	var ab: Button = null
	for b in _boutons_visibles():
		if b is Button and (b as Button).text == "Abandonner":
			ab = b
	_verifier_ici(ab != null, nom, "bouton Abandonner")
	if ab:
		var jetons := Game.jetons
		ab.pressed.emit()
		await _attendre(0.6)
		_verifier_ici(not get_tree().paused and get_tree().current_scene.scene_file_path == Game.SCENE_CARTE, nom, "Abandonner ramène à la carte")
		_verifier_ici(Game.jetons == jetons, nom, "abandon sans gains")
	get_tree().paused = false
	_noter(nom, "pause")


func _verifier_ici(cond: bool, ecran: String, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC [%s] %s" % [ecran, msg])


func _ouvrir(e: Array) -> void:
	Game.aller(e[0], (e[1] as Dictionary).duplicate(true))
	await _attendre(0.6)


func _jouer(touches: Array, duree: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t := 0.0
	var vp := get_viewport().get_visible_rect().size
	while t < duree:
		var k: int = touches[rng.randi() % touches.size()]
		if k == KEY_ESCAPE and rng.randf() < 0.9:
			k = touches[0]
		_touche(k, true)
		await _attendre(0.05)
		_touche(k, false)
		var pos := Vector2(rng.randf() * vp.x, rng.randf() * vp.y)
		var m := InputEventMouseMotion.new()
		m.position = pos
		m.global_position = pos
		Input.parse_input_event(m)
		var c := InputEventMouseButton.new()
		c.button_index = MOUSE_BUTTON_LEFT if rng.randf() < 0.8 else MOUSE_BUTTON_RIGHT
		c.position = pos
		c.global_position = pos
		c.pressed = true
		Input.parse_input_event(c)
		await _attendre(0.03)
		c = c.duplicate()
		c.pressed = false
		Input.parse_input_event(c)
		await _attendre(0.07)
		t += 0.15


func _touche(k: int, appui: bool) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = appui
	Input.parse_input_event(ev)


func _boutons_visibles() -> Array:
	var r: Array = []
	_collecter(get_tree().root, r)
	return r


func _collecter(n: Node, r: Array) -> void:
	if n == self:
		return
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return
	if n is BaseButton:
		r.append(n)
	for c in n.get_children():
		_collecter(c, r)


func _nom_bouton(b: BaseButton) -> String:
	if b is Button and (b as Button).text != "":
		return (b as Button).text.replace("\n", " ")
	return "%s" % b.name


func _noter(ecran: String, quoi: String) -> void:
	for err in _compteur.vider():
		var t := str(err)
		if "Steam" in t or "steam" in t:
			continue
		_echecs += 1
		printerr("ÉCHEC [%s] %s : %s" % [ecran, quoi, t])


func _attendre(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _restaurer(chemin: String, contenu: String) -> void:
	if contenu != "":
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_string(contenu)
	elif FileAccess.file_exists(chemin):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
