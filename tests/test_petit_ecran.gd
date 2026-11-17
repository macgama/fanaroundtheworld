extends Node
## Les écrans tiennent-ils sur un téléphone ? Ouvre chaque écran de
## test_ecrans.gd en mode téléphone et liste les boutons et textes qui sortent
## de l'écran (hors listes qui défilent). Échoue s'il y en a.
##   xvfb-run -a godot --path . --resolution 1920x1080 res://tests/test_petit_ecran.tscn -- --hors-ligne --mobile
## Essayer les deux formats : 1920x1080 (16:9) et 2400x1080 (20:9, la plupart des téléphones).
## « --ecran=nom » pour un seul écran.

var _echecs := 0


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PilotePetitEcran"
		pilote.process_mode = Node.PROCESS_MODE_ALWAYS
		get_tree().root.add_child.call_deferred(pilote)
		return
	if not Mobile.actif:
		print("Lancer avec « -- --mobile »")  # sans_traduction
		get_tree().quit(1)
		return
	var seul := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ecran="):
			seul = a.trim_prefix("--ecran=")
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var tuto := FileAccess.get_file_as_string(Tutoriel.CHEMIN)
	Tutoriel.passer()
	var ecrans: Dictionary = load("res://tests/test_ecrans.gd").new()._ecrans
	for nom in ecrans:
		if seul != "" and nom != seul:
			continue
		var e: Array = ecrans[nom]
		Game.aller(e[0], e[1].duplicate(true))
		for i in 20:
			await get_tree().process_frame
		await get_tree().create_timer(0.6).timeout
		var hors := _hors_ecran(get_tree().current_scene)
		if hors.is_empty():
			print("[%s] OK" % nom)
		else:
			_echecs += 1
			print("[%s] %d élément(s) hors de l'écran : %s" % [nom, hors.size(), ", ".join(hors.slice(0, 8))])  # sans_traduction
	if sauvegarde != "":
		var f := FileAccess.open(Game.CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		f.store_string(sauvegarde)
	if tuto != "":
		var f2 := FileAccess.open(Tutoriel.CHEMIN, FileAccess.WRITE)
		f2.store_string(tuto)
	print("Petit écran : %s" % ("OK" if _echecs == 0 else "%d écran(s) à revoir" % _echecs))  # sans_traduction
	get_tree().quit(1 if _echecs else 0)


## Boutons et textes visibles qui dépassent de l'écran (de plus de 4 pixels).
func _hors_ecran(racine: Node) -> Array:
	var r := []
	if racine == null:
		return r
	var ecran := get_viewport().get_visible_rect().grow(4)
	for n in racine.find_children("*", "Control", true, false):
		var c := n as Control
		if not (c is Button or c is Label or c is LineEdit) or not c.is_visible_in_tree():
			continue
		if c.text.strip_edges() == "" or _dans_un_defilement(c):
			continue
		var rect := c.get_global_rect()
		if rect.size.x < 2 or rect.size.y < 2:
			continue
		if not ecran.encloses(rect):
			r.append("« %s » %s" % [c.text.left(24).replace("\n", " "), str(rect.end.floor())])
	return r


func _dans_un_defilement(c: Node) -> bool:
	var p := c.get_parent()
	while p:
		if p is ScrollContainer:
			return true
		if p is Control and (p as Control).clip_contents:
			return true
		p = p.get_parent()
	return false
