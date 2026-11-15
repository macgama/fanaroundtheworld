extends Control
## Banc d'écoute : tous les sons, les ambiances, et chaque chant à jouer en
## rythme (Espace ou clic sur « Frapper »). Lancer cette scène seule (F6).
## Ne dépend pas de l'autoload Sons : elle crée le sien.

const SONS := preload("res://scripts/audio/sons.gd")

var _sons: Node
var _chant: ChantLecteur
var _resultat: Label
var _pulsation: ColorRect
var _bpm: SpinBox
var _score := {"parfait": 0, "bien": 0, "rate": 0, "manquee": 0}


func _ready() -> void:
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	if layout and AudioServer.get_bus_index("Chants") < 0:
		AudioServer.set_bus_layout(layout)
	_sons = SONS.new()
	add_child(_sons)
	_chant = ChantLecteur.new()
	add_child(_chant)
	_chant.frappe.connect(_sur_frappe)
	_chant.appui_juge.connect(_sur_appui)
	_chant.note_manquee.connect(func(_i, _t): _compter("manquee"))
	_chant.fini.connect(func(): _resultat.text = "Fini. " + _bilan())

	var fond := ColorRect.new()
	fond.color = Color("1e2a4a")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var defile := ScrollContainer.new()
	defile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(defile)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 12)
	defile.add_child(col)

	_titre(col, "Chants rythmés : Espace pour frapper")
	var ligne := HBoxContainer.new()
	col.add_child(ligne)
	ligne.add_child(_lbl("BPM (0 = celui du chant)"))
	_bpm = SpinBox.new()
	_bpm.max_value = 200
	ligne.add_child(_bpm)
	var frapper := Button.new()
	frapper.text = "Frapper"
	frapper.pressed.connect(func(): _chant.juger_appui())
	ligne.add_child(frapper)
	var stop := Button.new()
	stop.text = "Arrêter"
	stop.pressed.connect(_chant.arreter)
	ligne.add_child(stop)
	_pulsation = ColorRect.new()
	_pulsation.custom_minimum_size = Vector2(40, 40)
	_pulsation.color = Color("ffd23f")
	ligne.add_child(_pulsation)
	_resultat = _lbl("Choisis un chant.")
	col.add_child(_resultat)
	var g := _grille(col)
	var chants := Rythme.chants()
	for id in chants:
		var c: Dictionary = chants[id]
		var b := Button.new()
		b.text = "%s (%d BPM)" % [c.get("nom", id), int(c.get("bpm", 0))]
		b.tooltip_text = String(c.get("description", ""))
		b.pressed.connect(_lancer.bind(String(id)))
		g.add_child(b)

	_titre(col, "Ambiances")
	g = _grille(col)
	for lieu in ["stade", "pub", "maison", "ecran_geant"]:
		for i in 3:
			if lieu != "stade" and i != 1:
				continue
			var b := Button.new()
			b.text = "%s %s" % [lieu, ["calme", "chaud", "ferveur"][i]] if lieu == "stade" else lieu
			b.pressed.connect(_sons.ambiance.bind(lieu, i))
			g.add_child(b)
	var couper := Button.new()
	couper.text = "Couper l'ambiance"
	couper.pressed.connect(_sons.couper_ambiance)
	g.add_child(couper)

	_titre(col, "Musique (« The Final Turn », Gaël)")
	g = _grille(col)
	for id in ["accueil", "victoire"]:
		var b := Button.new()
		b.text = id
		b.pressed.connect(_sons.musique.bind(id))
		g.add_child(b)
	var sm := Button.new()
	sm.text = "Arrêter la musique"
	sm.pressed.connect(_sons.arreter_musique)
	g.add_child(sm)

	_titre(col, "Sons")
	g = _grille(col)
	for id in BanqueSons.catalogue().get("sons", {}):
		var b := Button.new()
		b.text = String(id)
		b.tooltip_text = String(BanqueSons.catalogue()["sons"][id].get("description", ""))
		b.pressed.connect(_sons.jouer.bind(String(id)))
		g.add_child(b)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and (e as InputEventKey).keycode == KEY_SPACE:
		_chant.juger_appui()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_pulsation.modulate.a = maxf(0.15, _pulsation.modulate.a - delta * 4.0)


func _lancer(id: String) -> void:
	for k in _score:
		_score[k] = 0
	_chant.lancer(id, _bpm.value, 8, 1.5)
	_resultat.text = "C'est parti : %s" % id


func _sur_frappe(voix: String, _force: float, _t: float) -> void:
	if voix in ["T", "G"]:
		_pulsation.modulate.a = 1.0


func _sur_appui(r: Dictionary) -> void:
	if r["note"] == "hors":
		return
	_compter(r["note"])
	_sons.jouer({"parfait": "ui_parfait", "bien": "ui_bien", "rate": "ui_rate"}[r["note"]])
	_resultat.text = "%s (%+d ms) · %s" % [String(r["note"]).to_upper(), int(r["ecart"] * 1000), _bilan()]


func _compter(n: String) -> void:
	_score[n] = int(_score.get(n, 0)) + 1


func _bilan() -> String:
	return "parfaits %d · biens %d · ratés %d · manquées %d" % [_score.parfait, _score.bien, _score.rate, _score.manquee]


func _titre(parent: Node, t: String) -> void:
	var l := _lbl(t)
	l.add_theme_font_size_override("font_size", 28)
	parent.add_child(l)


func _lbl(t: String) -> Label:
	var l := Label.new()
	l.text = t
	return l


func _grille(parent: Node) -> GridContainer:
	var g := GridContainer.new()
	g.columns = 5
	parent.add_child(g)
	return g
