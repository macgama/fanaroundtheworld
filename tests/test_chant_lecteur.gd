extends SceneTree
## Test en temps réel du lecteur de chants (environ 6 s) :
## godot --headless --path . --script tests/test_chant_lecteur.gd
## Un joueur parfait frappe sur chaque note qu'il entend : tout doit être
## « parfait » ou « bien », aucune note manquée, et le chant doit finir.

var _chant: ChantLecteur
var _sons: Node
var _notes := {}
var _frappes := 0
var _manquees := 0
var _fini := false
var _prochaine := 0
var _hors := ""


func _initialize() -> void:
	AudioServer.set_bus_layout(load("res://default_bus_layout.tres"))
	_sons = load("res://scripts/audio/sons.gd").new()
	root.add_child(_sons)
	_chant = ChantLecteur.new()
	root.add_child(_chant)
	_chant.frappe.connect(func(_v, _f, _t): _frappes += 1)
	_chant.appui_juge.connect(func(r): _notes[r["note"]] = int(_notes.get(r["note"], 0)) + 1)
	_chant.note_manquee.connect(func(_i, _t): _manquees += 1)
	_chant.fini.connect(func(): _fini = true)
	_chant.lancer("contretemps", 150.0, 3, 0.3)
	# Un appui hors de toute note ne doit rien consommer.
	var r := _chant.juger_appui()
	_hors = String(r["note"])


var _premier := true


func _process(_delta: float) -> bool:
	if _premier:  # Sons est dans l'arbre : on lui fait tout jouer une fois
		_premier = false
		_sons.jouer("tambour")
		_sons.jouer("clameur_but", {"volume_db": -6})
		_sons.ambiance("pub", 1, 0.2)
		_sons.ambiance("stade", 2, 0.2)
		_sons.musique("accueil", 0.1)
		_sons.regler_volume("Musique", 0.5)
	if _chant.en_cours and _prochaine < _chant.notes.size() \
			and _chant.temps_entendu() >= _chant.notes[_prochaine]:
		_chant.juger_appui()
		_prochaine += 1
	if _fini or _chant.temps() > 10.0:
		_conclure()
		return true
	return false


func _conclure() -> void:
	var echecs := 0
	var bons := int(_notes.get("parfait", 0)) + int(_notes.get("bien", 0))
	var attendu := 12  # 3 mesures × 4 contretemps
	for c in [[_hors == "hors", "un appui avant le chant est « hors »"],
			[_fini, "le chant finit"],
			[bons == attendu, "toutes les notes réussies (%d/%d, %s)" % [bons, attendu, str(_notes)]],
			[_manquees == 0, "aucune note manquée (%d)" % _manquees],
			[_frappes == 24, "toutes les frappes jouées (%d/24)" % _frappes]]:
		if not c[0]:
			echecs += 1
			printerr("ÉCHEC : " + c[1])
	print("Test lecteur de chants : %s %s" % ["OK" if echecs == 0 else "%d ÉCHEC(S)" % echecs, str(_notes)])
	quit(1 if echecs > 0 else 0)
