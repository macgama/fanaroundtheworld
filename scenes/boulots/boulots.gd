extends Control
## « Petits boulots » : la liste des mini-jeux qui rapportent des Jetons
## (vendeur à la buvette, etc.). La liste vient de ListeBoulots.LISTE.

const FOND := Color("#5a3fc0")


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var racine := Ui.vbox(24)
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.offset_left = 60
	racine.offset_right = -60
	racine.offset_top = 30
	racine.offset_bottom = -30
	add_child(racine)

	var haut := Ui.hbox(16)
	racine.add_child(haut)
	haut.add_child(Ui.label("PETITS BOULOTS", 60, Ui.JAUNE, true, 10))
	var st := Ui.label("Donne un coup de main au stade et gagne des Jetons pour tes billets et tes trajets.", 22, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haut.add_child(st)
	var jet := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 36))
	hj.add_child(Ui.label(str(Game.jetons), 28, Ui.JAUNE, true, 6))
	jet.add_child(hj)
	jet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(jet)

	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	racine.add_child(sc)
	var grille := GridContainer.new()
	grille.columns = 3
	grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grille.add_theme_constant_override("h_separation", 28)
	grille.add_theme_constant_override("v_separation", 28)
	sc.add_child(grille)
	for b in ListeBoulots.LISTE:
		grille.add_child(_carte(b))

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(_retour)
	bas.add_child(retour)


func _carte(b: Dictionary) -> Control:
	var c := Color(str(b.get("couleur", "#1e6bff")))
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Ui.boite(Ui.NUIT, 28, 6, 8))
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.custom_minimum_size = Vector2(0, 330)
	var v := Ui.vbox(14)
	p.add_child(Ui.marge(v, 26, 22, 26, 22))
	var bande := Ui.pastille(tr(str(b["titre"])).to_upper(), c, 26)
	bande.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(bande)
	var t := Ui.label(str(b["texte"]), 24, Ui.BLANC)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(t)
	var id := str(b["id"])
	var n := Game.services_boulot_du_jour(id)
	var info := tr("Record : %d Jetons") % Game.record_boulot(id)
	if n > 0:
		info += tr("  ·  %d partie%s aujourd'hui") % [n, "s" if n > 1 else ""]
	v.add_child(Ui.label(info, 20, Ui.GRIS))
	var jouer := Ui.bouton("Y aller", c, 30)
	Ui.colorer_bouton(jouer, c)
	jouer.custom_minimum_size = Vector2(0, 84)
	jouer.tooltip_text = str(b["titre"])
	var scene := str(b["scene"])
	jouer.pressed.connect(func(): Game.aller(scene, Game.params))
	v.add_child(jouer)
	return p


func _retour() -> void:
	var p: Dictionary = Game.params
	Game.aller(Game.SCENE_CARTE, {"niveau": p.get("niveau", "monde"), "continent": p.get("continent", ""), "pays": p.get("pays", "")})


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo and ev.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_retour()
