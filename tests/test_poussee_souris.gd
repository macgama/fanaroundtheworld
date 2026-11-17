extends Node
## Poussée à la vraie souris (événements envoyés à la fenêtre, comme un joueur) :
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##     --resolution 1920x1080 res://tests/test_poussee_souris.tscn -- --hors-ligne
## Poussée : clic sur une carte, puis clic dans sa moitié : un FANZZY est posé.
## Arène : clic gauche sur le terrain : tir. Ramasseur : clic sur le terrain.

var _echecs := 0


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PilotePoussee"
		get_tree().root.add_child.call_deferred(pilote)
		return
	Game.aller(Game.SCENE_POUSSEE, {"match_id": "ex:1", "camp": "home", "mode": "pub", "cout": 0})
	await get_tree().create_timer(5.0).timeout  # compte à rebours
	var sc := get_tree().current_scene
	_verifier(sc != null and sc.get("en_cours") == true, "la partie a commencé")
	if sc == null:
		get_tree().quit(1)
		return
	sc.ferveur[0] = 10.0
	sc._maj_main()
	await get_tree().process_frame
	await get_tree().process_frame
	# clic sur la carte la moins chère
	var main: Control = sc._main
	var pile: Array = sc.piles[0]
	var i_min := 0
	for i in main.get_child_count():
		if PousseeRegles.CARTES[pile[i]]["cout"] < PousseeRegles.CARTES[pile[i_min]]["cout"]:
			i_min = i
	var carte: Control = main.get_child(i_min)
	await _cliquer(carte.get_global_rect().get_center())
	_verifier(sc.selection == i_min, "clic sur la carte : elle est choisie (%d)" % sc.selection)
	var avant: int = sc.posees[0]
	var cle: String = pile[i_min]
	var ou := Vector2(sc.TERRAIN.position.x + sc.TERRAIN.size.x * 0.3, sc.TERRAIN.get_center().y)
	if PousseeRegles.CARTES[cle]["type"] == "effet":
		ou = sc.TERRAIN.get_center()
	await _cliquer(ou)
	_verifier(sc.posees[0] == avant + 1, "clic dans ma moitié : FANZZY posé (%d -> %d)" % [avant, sc.posees[0]])
	_verifier(sc.selection == -1, "la carte n'est plus choisie après la pose")
	# Arène : un clic gauche sur le terrain tire (une munition en moins)
	Game.aller(Game.SCENE_ARENE, {"match_id": "ex:1", "camp": "home", "mode": "pub", "cout": 0})
	await get_tree().create_timer(5.0).timeout
	var ar := get_tree().current_scene
	_verifier(ar != null and ar.get("en_cours") == true, "arène : la partie a commencé")
	if ar != null:
		var j = ar.controle
		var mun: float = j.munitions
		await _cliquer(j.position + Vector2(200, 0))
		_verifier(j.munitions < mun, "arène : clic gauche = tir (%.1f -> %.1f)" % [mun, j.munitions])
	# Ramasseur de balles : clic sur le terrain = le ramasseur court vers ce point
	Game.aller(Game.SCENE_RAMASSEUR, {})
	await get_tree().create_timer(4.0).timeout
	var ra := get_tree().current_scene
	if ra != null:
		ra.set("en_main", false)
		await _appuyer(Vector2(1400, 700))
		_verifier(float(ra.get("_cible_souris")) >= 0.0, "ramasseur : clic sur le terrain = course vers la souris")
	print("ÉCHECS : %d" % _echecs)
	get_tree().quit(1 if _echecs > 0 else 0)


## Appuie sans relâcher (le ramasseur suit le bouton tenu).
func _appuyer(p: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	ev.global_position = p
	Input.warp_mouse(p)
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame


func _cliquer(p: Vector2) -> void:
	var vp := get_viewport()
	var ecran := vp.get_screen_transform() * vp.get_final_transform() * p
	for presse in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = presse
		ev.position = ecran
		ev.global_position = ecran
		Input.warp_mouse(ecran)
		Input.parse_input_event(ev)
		await get_tree().process_frame
		await get_tree().process_frame


func _verifier(ok: bool, texte: String) -> void:
	print(("OK    " if ok else "ÉCHEC ") + texte)
	if not ok:
		_echecs += 1
