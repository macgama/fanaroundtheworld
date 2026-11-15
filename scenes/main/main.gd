extends Control
## Écran titre : nom du jeu, bouton Jouer, état des données réelles.

var _etat: Label


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Ui.BLEU
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var v := Ui.vbox(26)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH
	v.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(v)
	var rang := Ui.hbox(-30)
	rang.alignment = BoxContainer.ALIGNMENT_CENTER
	for z in Game.fanzzy.slice(0, 6):
		var t := TextureRect.new()
		t.texture = Game.texture_fanzzy(z["id"])
		t.custom_minimum_size = Vector2(130, 240)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rang.add_child(t)
		_sautiller(t, randf() * 0.6)
	v.add_child(rang)
	var titre := Ui.label("FanAroundTheWorld", 110, Ui.JAUNE, true, 18)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(titre)
	var st := Ui.label("Suis les vrais matchs, tamponne les stades, gagne les duels d'ambiance", 28, Ui.BLANC, true, 8)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var jouer := Ui.bouton("JOUER", Ui.JAUNE, 56)
	Ui.colorer_bouton(jouer, Ui.JAUNE, true)
	jouer.custom_minimum_size = Vector2(420, 120)
	jouer.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	jouer.pressed.connect(func(): Game.aller(Game.SCENE_CARTE if Game.club_cree() else Game.SCENE_CREATION_CLUB))
	v.add_child(jouer)
	_etat = Ui.label("", 20, Ui.BLANC)
	_etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_etat)
	var bas := Ui.label("v%s · prototype · noms de clubs fictifs · %s" % [Game.VERSION, Donnees.attribution], 18, Color(1, 1, 1, 0.7))
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_top = -44
	bas.offset_left = 24
	add_child(bas)
	Donnees.mis_a_jour.connect(_maj)
	_maj()


func _maj() -> void:
	var n := Donnees.matchs().size()
	var d := Donnees.matchs().filter(func(m): return Donnees.en_direct(m)).size()
	_etat.text = "%d vrais matchs cette semaine · %d en direct · source : %s" % [n, d, Donnees.source]


func _sautiller(n: Control, delai: float) -> void:
	await get_tree().create_timer(delai).timeout
	if not is_instance_valid(n):
		return
	var t := n.create_tween().set_loops()
	t.tween_property(n, "position:y", -18.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT).as_relative()
	t.tween_property(n, "position:y", 18.0, 0.32).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).as_relative()
