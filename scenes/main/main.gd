extends Control
## Écran d'accueil : stade animé, titre, et le menu Jouer / En ligne /
## Options / Quitter. Un nouveau joueur qui appuie sur Jouer part dans le
## tutoriel (scripts/autoload/tutoriel.gd).

var _etat: Label
var _options: Control
var _confirmation: Control
var _foule: Array[FanzzyAnime] = []

const GESTES_FOULE: Array[StringName] = [&"chanter", &"agiter_echarpe", &"sauter", &"applaudir", &"encourager", &"lever_bras"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Reglages.appliquer()
	var decor := DecorStade.new()
	decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(decor)
	_construire_foule()
	_construire_titre()
	_construire_menu()
	var bas := Ui.label(tr("v%s · %s · noms de clubs fictifs · %s") % [Game.VERSION, tr("démo") if Demo.actif() else tr("prototype"), tr(Donnees.attribution)], 18, Color(1, 1, 1, 0.8), false, 5)
	bas.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bas.offset_top = -40
	bas.offset_left = 24
	add_child(bas)
	Donnees.mis_a_jour.connect(_maj)
	_maj()


# ---------------------------------------------------------------- décor

func _construire_titre() -> void:
	var logo := Control.new()
	logo.position = Vector2(110, 70)
	logo.size = Vector2(980, 520)
	logo.pivot_offset = logo.size / 2.0
	logo.rotation_degrees = -4.0
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(logo)
	var fan := Ui.label("FAN", 210, Ui.JAUNE, true, 30)  # sans_traduction
	fan.position = Vector2(0, -10)
	logo.add_child(fan)
	var ruban := Ui.panneau(Ui.ROSE, 18, 6)
	ruban.position = Vector2(370, 70)
	ruban.rotation_degrees = 3.0
	var autour := Ui.label("AROUND THE", 82, Ui.BLANC, true, 16)  # sans_traduction
	ruban.add_child(autour)
	logo.add_child(ruban)
	var monde := Ui.hbox(4)
	monde.position = Vector2(0, 205)
	monde.add_child(Ui.label("W", 210, Ui.JAUNE, true, 30))
	var globe := Ui.icone("monde", 150)
	globe.custom_minimum_size = Vector2(150, 150)
	globe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	monde.add_child(globe)
	monde.add_child(Ui.label("RLD", 210, Ui.JAUNE, true, 30))  # sans_traduction
	logo.add_child(monde)
	var tourne := globe.create_tween().set_loops()
	globe.pivot_offset = Vector2(75, 75)
	tourne.tween_property(globe, "rotation", TAU, 8.0).from(0.0)
	var bandeau := Ui.panneau(Ui.CONTOUR, 22, 0)
	bandeau.position = Vector2(30, 450)
	bandeau.add_child(Ui.label("Suis les vrais matchs, tamponne les stades,\ngagne les duels d'ambiance !", 32, Ui.BLANC, true))
	logo.add_child(bandeau)
	# entrée en rebond
	logo.scale = Vector2(0.6, 0.6)
	logo.modulate.a = 0.0
	var t := logo.create_tween().set_parallel()
	t.tween_property(logo, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(logo, "modulate:a", 1.0, 0.3)


## La foule de l'accueil : tes FANZZY d'abord, puis d'autres du catalogue.
## Chacun chante ou s'agite en rythme, saute à sa place à l'arrivée, et
## fait la fête quand on clique dessus.
func _construire_foule() -> void:
	var liste: Array = []
	for id in Game.equipe:
		if not str(id) in liste:
			liste.append(str(id))
	for z in Game.fanzzy:
		if liste.size() >= 9:
			break
		if not str(z["id"]) in liste:
			liste.append(str(z["id"]))
	var cc: Array = Game.couleurs_club() if Game.club_cree() else [Ui.BLEU, Ui.BLANC]
	for i in liste.size():
		var id: String = liste[i]
		var f := FanzzyAnime.creer(Game.skin_de(id))
		if f.texture == null:
			f.texture = Game.texture_fanzzy(id)
		if f.texture == null:
			continue
		# pieds au même endroit que l'ancienne vignette (170 x 300)
		var pieds := Vector2(20 + i * 212 + 85, 730 + (i % 2) * 26 + 300)
		var geste: StringName = GESTES_FOULE[i % GESTES_FOULE.size()]
		f.position = pieds
		f.couleurs_echarpe = PackedColorArray([Color(cc[0]), Color(cc[1])])
		f.couleur_trainee = Color(cc[0])
		f.bpm = 124.0
		f.energie = 0.8
		f.decalage = i * 0.05
		add_child(f)
		f.scale = Vector2.ONE * 290.0 / maxf(f._rect.size.y, 1.0)
		f.jouer(geste)
		f.action_terminee.connect(func(_a: StringName) -> void:
			if f.action == &"repos":
				f.jouer(geste))
		# entrée en scène : chacun saute à sa place, l'un après l'autre
		f.rebondir(1.2, 0.15 + i * 0.08)
		# clic sur un FANZZY : il saute de joie
		var zone := Control.new()
		zone.position = pieds - Vector2(85, 290)
		zone.size = Vector2(170, 290)
		zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		zone.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				f.rebondir(1.4)
				f.jouer(&"celebrer", 1.6))
		add_child(zone)
		_foule.append(f)
	_relancer_foule()


## De temps en temps, un FANZZY de la foule fait un bond ou un coup d'élastique.
func _relancer_foule() -> void:
	while is_inside_tree():
		await get_tree().create_timer(randf_range(1.2, 2.6)).timeout
		if _foule.is_empty() or not is_inside_tree():
			return
		var f: FanzzyAnime = _foule[randi() % _foule.size()]
		if is_instance_valid(f) and f.action != &"celebrer":
			if randf() < 0.6:
				f.rebondir(randf_range(0.7, 1.1))
			else:
				f.pop(-1.2)


# ---------------------------------------------------------------- menu

func _construire_menu() -> void:
	var p := Ui.panneau(Color(Ui.NUIT, 0.94), 32, 6)
	p.position = Vector2(1240, 150)
	p.custom_minimum_size = Vector2(580, 0)
	add_child(p)
	var v := Ui.vbox(18)
	p.add_child(Ui.marge(v, 14, 14, 14, 14))
	if Game.club_cree():
		var h := Ui.hbox(16)
		var cc := Game.couleurs_club()
		h.add_child(Ui.ecusson(FanClub.sigle(Game.fan_club_nom), Color(cc[0]), Color(cc[1]), 70))
		var vv := Ui.vbox(2)
		var nom := Ui.label(Game.fan_club_nom.to_upper(), 30, Ui.BLANC, true, 6)
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nom.custom_minimum_size.x = 380
		vv.add_child(nom)
		var infos := Ui.hbox(8)
		infos.add_child(Ui.label(tr("NIV. %d") % Game.niveau(), 22, Ui.JAUNE, true))
		infos.add_child(Ui.icone("jeton", 26))
		infos.add_child(Ui.label(str(Game.jetons), 22, Ui.JAUNE, true))
		infos.add_child(Ui.icone("tampon", 26))
		infos.add_child(Ui.label(str(Game.tampons.size()), 22, Ui.BLANC, true))
		vv.add_child(infos)
		h.add_child(vv)
		v.add_child(h)
	else:
		var bienvenue := Ui.label("Bienvenue, supporter !", 34, Ui.JAUNE, true, 6)
		bienvenue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(bienvenue)
	var jouer := _bouton(v, "CONTINUER" if Game.club_cree() else "JOUER", Ui.JAUNE, 60, 130, true)
	jouer.pressed.connect(_jouer)
	_focus_plus_tard(jouer)
	_pulser(jouer)
	if Demo.actif():
		v.add_child(Demo.ruban_accueil())
	var ligne := _bouton(v, "EN LIGNE", Ui.BLEU, 38, 90)
	ligne.tooltip_text = "Défie un ami ou un autre joueur"
	ligne.pressed.connect(_en_ligne)
	var h2 := Ui.hbox(14)
	v.add_child(h2)
	var opt := _bouton(h2, "OPTIONS", Ui.VIOLET, 32, 80)
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.pressed.connect(_ouvrir_options)
	var quitter := _bouton(h2, "QUITTER", Ui.NUIT_CLAIR, 32, 80)
	quitter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quitter.pressed.connect(func(): get_tree().quit())
	_etat = Ui.label("", 19, Ui.GRIS)
	_etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_etat)
	# le menu glisse depuis la droite
	p.position.x += 700
	p.create_tween().tween_property(p, "position:x", 1240.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)


func _bouton(parent: Control, texte: String, couleur: Color, taille: int, haut: int, sombre := false) -> Button:
	var b := Ui.bouton(texte, couleur, taille)
	if sombre:
		Ui.colorer_bouton(b, couleur, true)
	b.custom_minimum_size.y = haut
	b.mouse_entered.connect(func(): Ui.pop(b, 1.04))
	b.resized.connect(func(): b.pivot_offset = b.size / 2.0)
	parent.add_child(b)
	return b


func _pulser(b: Control) -> void:
	var t := b.create_tween().set_loops()
	t.tween_property(b, "scale", Vector2.ONE * 1.04, 0.7).set_trans(Tween.TRANS_SINE)
	t.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)


func _maj() -> void:
	var n := Donnees.matchs().size()
	var d := Donnees.matchs().filter(func(m): return Donnees.en_direct(m)).size()
	_etat.text = tr("%d vrais matchs cette semaine · %d en direct") % [n, d]


func _jouer() -> void:
	if not Game.club_cree():
		# Nouveau joueur : le tutoriel l'accompagne (sauf s'il l'a déjà passé).
		if not Tutoriel.fini:
			Tutoriel.demarrer()
		Game.aller(Game.SCENE_CREATION_CLUB)
		return
	Game.aller(Game.SCENE_CARTE)


func _en_ligne() -> void:
	Game.aller(Game.SCENE_SALON)


# ---------------------------------------------------------------- options

func _ouvrir_options() -> void:
	if _options:
		_options.queue_free()
	_options = _fenetre("Options")
	var v: VBoxContainer = _options.get_meta("contenu")
	for ligne in Reglages.VOLUMES:
		var h := Ui.hbox(16)
		var l := Ui.label(ligne[1], 24, Ui.BLANC, true)
		l.custom_minimum_size.x = 270
		h.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Reglages.volume(ligne[0])
		s.custom_minimum_size = Vector2(340, 40)
		s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var pc := Ui.label("%d %%" % roundi(s.value * 100), 22, Ui.JAUNE, true)
		pc.custom_minimum_size.x = 80
		var cle: String = ligne[0]
		s.value_changed.connect(func(x: float):
			Reglages.regler_volume(cle, x)
			pc.text = "%d %%" % roundi(x * 100))
		h.add_child(s)
		h.add_child(pc)
		v.add_child(h)
	var pe := CheckButton.new()
	pe.text = "Plein écran"
	pe.add_theme_font_override("font", Ui.police_titre())
	pe.add_theme_font_size_override("font_size", 24)
	for k in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		pe.add_theme_stylebox_override(k, StyleBoxEmpty.new())
	pe.button_pressed = Reglages.plein_ecran()
	pe.toggled.connect(Reglages.regler_plein_ecran)
	if Mobile.actif:
		pe.queue_free()  # toujours plein écran sur téléphone
	else:
		v.add_child(pe)
	# langue : un bouton par langue proposée (data/langues/<code>/)
	var hl := Ui.hbox(14)
	var ll := Ui.label("Langue", 24, Ui.BLANC, true)
	ll.custom_minimum_size.x = 270
	hl.add_child(ll)
	var actuelle := TranslationServer.get_locale().left(2)
	for code in Langue.disponibles():
		var bl := Ui.bouton(Langue.nom(code), Ui.VIOLET if code == actuelle else Color("#55507f"), 22)
		bl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # chaque langue garde son nom
		bl.pressed.connect(func():
			if code != TranslationServer.get_locale().left(2):
				Langue.changer(code)
				get_tree().reload_current_scene())
		hl.add_child(bl)
	v.add_child(hl)
	v.add_child(Ui.label("Partie", 26, Ui.JAUNE, true))
	var sauv := Ui.label(Plateforme.texte_sauvegarde(), 18, Ui.GRIS)
	sauv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sauv.custom_minimum_size.x = 700
	v.add_child(sauv)
	var h2 := Ui.hbox(14)
	v.add_child(h2)
	var tuto := Ui.bouton("Revoir le tutoriel", Ui.VERT, 24)
	tuto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tuto.tooltip_text = "Ton FANZZY te guide à nouveau pas à pas"
	tuto.pressed.connect(func():
		Tutoriel.demarrer()
		Game.aller(Game.SCENE_CLUB if Game.club_cree() else Game.SCENE_CREATION_CLUB))
	h2.add_child(tuto)
	var raz := Ui.bouton("Recommencer à zéro", Ui.ROUGE, 24)
	raz.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	raz.pressed.connect(_confirmer_raz)
	h2.add_child(raz)


func _confirmer_raz() -> void:
	_confirmation = _fenetre("Tout recommencer ?")
	var v: VBoxContainer = _confirmation.get_meta("contenu")
	var l := Ui.label("Ton fan club, tes Jetons, tes tampons et tes FANZZY seront effacés. Impossible de revenir en arrière !", 24, Ui.BLANC)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 640
	v.add_child(l)
	var h := Ui.hbox(14)
	v.add_child(h)
	var non := Ui.bouton("Non, je garde tout", Ui.VERT, 26)
	non.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	non.pressed.connect(func(): _confirmation.queue_free())
	h.add_child(non)
	var oui := Ui.bouton("Oui, tout effacer", Ui.ROUGE, 26)
	oui.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	oui.pressed.connect(func():
		Game.reinitialiser()
		Tutoriel.effacer()
		Game.aller(Game.SCENE_TITRE))
	h.add_child(oui)


## Fenêtre au centre sur un voile sombre, avec titre et bouton Fermer.
func _fenetre(titre: String) -> Control:
	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.7)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(voile)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(c)
	var p := Ui.panneau(Ui.NUIT, 32, 6)
	c.add_child(p)
	var v := Ui.vbox(18)
	p.add_child(Ui.marge(v, 20, 12, 20, 12))
	var h := Ui.hbox(12)
	var t := Ui.label(titre, 44, Ui.JAUNE, true, 8)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var fermer := Ui.bouton("X", Ui.NUIT_CLAIR, 24)
	fermer.custom_minimum_size = Vector2(60, 60)
	fermer.pressed.connect(func(): voile.queue_free())
	h.add_child(fermer)
	v.add_child(h)
	var contenu := Ui.vbox(18)
	v.add_child(contenu)
	voile.set_meta("contenu", contenu)
	Ui.pop(p, 1.05)
	return voile


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		for f in [_confirmation, _options]:
			if f and is_instance_valid(f) and not f.is_queued_for_deletion():
				f.queue_free()
				get_viewport().set_input_as_handled()
				return


## Focus clavier sur JOUER, sauf si l'écran a déjà été quitté (tests, raccourcis).
func _focus_plus_tard(b: Control) -> void:
	get_tree().process_frame.connect(func():
		if is_instance_valid(b) and b.is_inside_tree():
			b.grab_focus(), CONNECT_ONE_SHOT)
