extends Control
## Hub du fan club : les membres (FANZZY), le recrutement, et la caisse
## (cotisations, buvette, atelier d'écharpes). Les recettes grossissent avec
## la taille du club ; on les récolte en Jetons.

var _jetons: Label
var _infos: VBoxContainer
var _membres: GridContainer
var _caisse: VBoxContainer
var _recolter: Button
var _lbl_cot: Label
var _lbl_buv: Label
var _lbl_ech: Label
var _vendre: Button
var _recrutement: Control
var _message: Label


func _ready() -> void:
	var cc := Game.couleurs_club()
	var fond := ColorRect.new()
	fond.color = Color("#f6b26b")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var sol := ColorRect.new()
	sol.color = Color("#b8662e")
	sol.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sol.offset_top = -400
	add_child(sol)

	var racine := Ui.vbox(18)
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.offset_left = 32
	racine.offset_right = -32
	racine.offset_top = 22
	racine.offset_bottom = -22
	add_child(racine)

	# --- haut : écusson, nom, niveau, Jetons
	var haut := Ui.hbox(18)
	racine.add_child(haut)
	haut.add_child(Ui.ecusson(FanClub.sigle(Game.fan_club_nom), cc[0], cc[1], 92))
	var banniere := Ui.panneau(cc[0], 22, 6)
	banniere.add_theme_stylebox_override("panel", Ui.boite(cc[0], 22, 6, 8, cc[1] if cc[1] != cc[0] else Ui.CONTOUR))
	banniere.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb := Ui.hbox(16)
	banniere.add_child(hb)
	var nom := Ui.label(Game.fan_club_nom.to_upper(), 54, Ui.BLANC, true, 12)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(nom)
	var modif := Ui.bouton("Modifier", Ui.NUIT, 20)
	modif.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	modif.tooltip_text = "Changer le nom ou les couleurs"
	modif.pressed.connect(func(): Game.aller(Game.SCENE_CREATION_CLUB))
	hb.add_child(modif)
	haut.add_child(banniere)
	var jet := Ui.panneau(Ui.NUIT, 20, 5)
	jet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 44))
	_jetons = Ui.label("", 36, Ui.JAUNE, true, 6)
	hj.add_child(_jetons)
	jet.add_child(hj)
	jet.tooltip_text = "Jetons : gagnés en jouant, ils payent billets, trajets et le local du club."
	haut.add_child(jet)

	# --- milieu : infos | membres | caisse
	var milieu := Ui.hbox(22)
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(milieu)

	var p_infos := Ui.panneau()
	p_infos.custom_minimum_size = Vector2(440, 0)
	milieu.add_child(p_infos)
	_infos = Ui.vbox(10)
	p_infos.add_child(_infos)

	var p_membres := Ui.panneau(Color(0.16, 0.13, 0.4, 0.92))
	p_membres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milieu.add_child(p_membres)
	var vm := Ui.vbox(10)
	p_membres.add_child(vm)
	var hm := Ui.hbox(12)
	vm.add_child(hm)
	hm.add_child(Ui.label("LES MEMBRES", 36, Ui.JAUNE, true, 8))
	var aide := Ui.label("Chaque membre cotise, et plus le club est grand, plus tout rapporte.", 18, Ui.GRIS)
	aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	aide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hm.add_child(aide)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vm.add_child(sc)
	_membres = GridContainer.new()
	_membres.columns = 4
	_membres.add_theme_constant_override("h_separation", 14)
	_membres.add_theme_constant_override("v_separation", 14)
	_membres.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_membres)

	var p_caisse := Ui.panneau()
	p_caisse.custom_minimum_size = Vector2(500, 0)
	milieu.add_child(p_caisse)
	_caisse = Ui.vbox(12)
	p_caisse.add_child(_caisse)

	# --- bas : navigation
	var bas := Ui.hbox(18)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var b_carte := Ui.bouton("Carte", Ui.BLEU, 30)
	b_carte.custom_minimum_size = Vector2(210, 88)
	b_carte.pressed.connect(func(): Game.aller(Game.SCENE_CARTE))
	bas.add_child(b_carte)
	var b_club := Ui.bouton("Fan Club", Ui.JAUNE, 30)
	Ui.colorer_bouton(b_club, Ui.JAUNE, true)
	b_club.custom_minimum_size = Vector2(210, 88)
	bas.add_child(b_club)
	var b_tribune := Ui.bouton("FANZZY", Ui.VIOLET, 30)
	b_tribune.custom_minimum_size = Vector2(210, 88)
	b_tribune.tooltip_text = "Choisir les FANZZY de ta tribune et leurs skins"
	b_tribune.pressed.connect(func(): Game.aller(Game.SCENE_TRIBUNE, {"retour": "club"}))
	bas.add_child(b_tribune)
	var b_chant := Ui.bouton("Chant", Ui.VERT, 30)
	Ui.colorer_bouton(b_chant, Ui.VERT, true)
	b_chant.custom_minimum_size = Vector2(210, 88)
	b_chant.tooltip_text = "Composer le chant que ta tribune chante en duel"
	b_chant.pressed.connect(func(): Game.aller(Game.SCENE_CHANT))
	bas.add_child(b_chant)
	var b_tournoi := Ui.bouton("Tournoi", Ui.ROSE, 30)
	b_tournoi.custom_minimum_size = Vector2(210, 88)
	b_tournoi.tooltip_text = "Tournoi des fan clubs du week-end"
	b_tournoi.pressed.connect(func(): Game.aller(Game.SCENE_TOURNOI))
	bas.add_child(b_tournoi)
	var b_pass := Ui.bouton("PASS", Ui.NUIT_CLAIR, 30)
	b_pass.custom_minimum_size = Vector2(210, 88)
	Game.preparer_bouton_pass(b_pass, {"retour": "club"})
	bas.add_child(b_pass)

	_message = Ui.label("", 30, Ui.BLANC, true, 8)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.offset_top = 150
	_message.offset_left = -500
	_message.offset_right = 500
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.modulate.a = 0.0
	add_child(_message)

	_construire_caisse()
	_construire()
	var t := Timer.new()
	t.wait_time = 1.0
	t.autostart = true
	t.timeout.connect(_maj_caisse)
	add_child(t)


func _construire() -> void:
	FanClub.avancer(Game.club, Game.maintenant())
	_construire_infos()
	_construire_membres()
	_maj_caisse()


# ------------------------------------------------------------------ infos

func _construire_infos() -> void:
	for c in _infos.get_children():
		c.queue_free()
	var n := FanClub.nb_membres(Game.club)
	_infos.add_child(Ui.label("MON FAN CLUB", 34, Ui.JAUNE, true, 8))
	var places := FanClub.places(Game.niveau())
	var lignes := [
		["Niveau du club", "%d" % Game.niveau()],
		["Membres", tr("%d / %d places") % [n, places]],
		["Renommée", FanClub.renommee(n)],
		["Bonus de taille", "+%d %%" % int(round((FanClub.multiplicateur_taille(n) - 1.0) * 100.0))],
		["Stades visités", "%d" % Game.tampons.size()],
		["Duels gagnés", "%d / %d" % [Game.duels_gagnes, Game.duels_joues]],
		["Gagné par le club", tr("%d Jetons") % int(Game.club.get("total_gagne", 0))],
		["Chant du club", String(Game.chant_club().get("nom", "à composer"))],
	]
	for l in lignes:
		var h := Ui.hbox(8)
		var a := Ui.label(l[0], 21, Ui.BLANC)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Ui.label(l[1], 21, Ui.JAUNE, true))
		_infos.add_child(h)
		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.12)
		sep.custom_minimum_size = Vector2(0, 2)
		_infos.add_child(sep)
	_infos.add_child(Ui.espace())
	var prochain := Ui.label(tr("Niveau %d : +%d places pour recruter.") % [Game.niveau() + 1, FanClub.PLACES_PAR_NIVEAU], 18, Ui.GRIS)
	prochain.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_infos.add_child(prochain)
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(0, 18)
	barre.show_percentage = false
	barre.max_value = 1.0
	barre.value = Game.xp_dans_niveau()
	barre.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 8, 3))
	barre.add_theme_stylebox_override("fill", Ui.boite(Ui.BLEU, 8, 0))
	_infos.add_child(barre)
	var xp := Ui.label("L'XP se gagne en duel d'ambiance.", 16, Ui.GRIS)
	_infos.add_child(xp)


# ------------------------------------------------------------------ membres

func _construire_membres() -> void:
	for c in _membres.get_children():
		c.queue_free()
	for id in Game.club["membres"]:
		var z := Game.fanzzy_par_id(str(id))
		if not z.is_empty():
			_membres.add_child(_carte_membre(z))
	if FanClub.peut_recruter(Game.club, Game.niveau()):
		var b := Button.new()
		b.custom_minimum_size = Vector2(180, 250)
		b.text = "+\nRecruter"
		b.add_theme_font_size_override("font_size", 30)
		b.add_theme_color_override("font_color", Ui.CONTOUR)
		b.add_theme_color_override("font_hover_color", Ui.CONTOUR)
		b.add_theme_constant_override("outline_size", 0)
		b.add_theme_stylebox_override("normal", Ui.boite(Color(1, 1, 1, 0.55), 22, 4, 0, Color(1, 1, 1, 0.9)))
		b.add_theme_stylebox_override("hover", Ui.boite(Color(1, 1, 1, 0.8), 22, 4, 0, Ui.JAUNE))
		b.add_theme_stylebox_override("pressed", Ui.boite(Ui.JAUNE, 22, 4, 0))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.pressed.connect(_ouvrir_recrutement)
		_membres.add_child(b)
	else:
		var plein := Ui.panneau(Color(0, 0, 0, 0.25), 22, 3)
		plein.custom_minimum_size = Vector2(180, 250)
		var l := Ui.label("Club plein.\nMonte de niveau pour ouvrir des places.", 18, Ui.BLANC, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.size_flags_vertical = Control.SIZE_EXPAND_FILL
		plein.add_child(l)
		_membres.add_child(plein)


func _carte_membre(z: Dictionary) -> Control:
	var fam: String = z["famille"]
	var p := Ui.panneau(Game.couleur_famille(fam).darkened(0.35), 22, 4)
	p.custom_minimum_size = Vector2(180, 250)
	var v := Ui.vbox(4)
	p.add_child(v)
	var t := TextureRect.new()
	t.texture = Game.texture_fanzzy(z["id"])
	t.custom_minimum_size = Vector2(150, 150)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(t)
	var n := Ui.label(z["nom"], 16, Ui.BLANC, true, 4)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(150, 0)
	v.add_child(n)
	var hp := Ui.hbox(4)
	hp.alignment = BoxContainer.ALIGNMENT_CENTER
	hp.add_child(Ui.pastille(Game.nom_famille(fam), Game.couleur_famille(fam), 14, fam in ["voix", "fide"]))
	if z["id"] in Game.equipe:
		var tri := Ui.pastille("Tribune", Ui.JAUNE, 14, true)
		tri.tooltip_text = "Dans ta tribune de duel"
		hp.add_child(tri)
	v.add_child(hp)
	p.tooltip_text = tr("%s\nCotise %s Jeton/h") % [tr(z.get("histoire", "")), _nombre(FanClub.COTISATION_HEURE)]
	if FanClub.nb_membres(Game.club) > 1 and not z["id"] in Game.equipe:
		var x := Ui.bouton("x", Ui.ROUGE, 16)
		x.tooltip_text = "Renvoyer du club"
		x.custom_minimum_size = Vector2(34, 30)
		var id: String = z["id"]
		x.pressed.connect(func(): _confirmer_renvoi(id, z["nom"]))
		hp.add_child(x)
	return p


func _confirmer_renvoi(id: String, nom: String) -> void:
	var d := ConfirmationDialog.new()
	d.title = "Renvoyer"
	d.dialog_text = tr("Renvoyer %s du club ?\nIl ne paiera plus sa cotisation.") % nom
	d.ok_button_text = "Renvoyer"
	d.cancel_button_text = "Garder"
	d.confirmed.connect(func():
		if Game.renvoyer(id):
			_annoncer(tr("%s a quitté le club.") % nom, Ui.BLANC)
			_construire())
	add_child(d)
	d.popup_centered()


# ------------------------------------------------------------------ recrutement

func _ouvrir_recrutement() -> void:
	if _recrutement:
		_recrutement.queue_free()
	_recrutement = Control.new()
	_recrutement.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_recrutement)
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.6)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_recrutement.add_child(voile)
	var p := Ui.panneau()
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	p.offset_left = 140
	p.offset_right = -140
	p.offset_top = 90
	p.offset_bottom = -90
	_recrutement.add_child(p)
	var v := Ui.vbox(14)
	p.add_child(v)
	var h := Ui.hbox(14)
	v.add_child(h)
	h.add_child(Ui.label("RECRUTER", 46, Ui.JAUNE, true, 10))
	var libres := FanClub.places(Game.niveau()) - FanClub.nb_membres(Game.club)
	var st := Ui.label((tr("%d places libres. Recruter est gratuit : c'est la taille du club qui compte.") if libres > 1 else tr("%d place libre. Recruter est gratuit : c'est la taille du club qui compte.")) % libres, 20, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(st)
	var fermer := Ui.bouton("Fermer", Ui.NUIT_CLAIR, 24)
	fermer.pressed.connect(func(): _recrutement.queue_free(); _recrutement = null)
	h.add_child(fermer)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	var g := GridContainer.new()
	g.columns = 6
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	sc.add_child(g)
	var candidats := Game.fanzzy.filter(func(z): return not FanClub.est_membre(Game.club, z["id"]))
	if candidats.is_empty():
		v.add_child(Ui.label("Tous les FANZZY connus sont déjà membres !", 24, Ui.BLANC, true))
	for z in candidats:
		g.add_child(_carte_candidat(z))


func _carte_candidat(z: Dictionary) -> Control:
	var fam: String = z["famille"]
	var p := Ui.panneau(Game.couleur_famille(fam).darkened(0.35), 22, 4)
	p.custom_minimum_size = Vector2(240, 0)
	var v := Ui.vbox(6)
	p.add_child(v)
	var t := TextureRect.new()
	t.texture = Game.texture_fanzzy(z["id"])
	t.custom_minimum_size = Vector2(200, 170)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(t)
	var n := Ui.label(z["nom"], 18, Ui.BLANC, true, 4)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.custom_minimum_size = Vector2(200, 48)
	v.add_child(n)
	var pf := Ui.pastille(Game.nom_famille(fam), Game.couleur_famille(fam), 14, fam in ["voix", "fide"])
	pf.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(pf)
	var b := Ui.bouton("Recruter", Ui.VERT, 22)
	Ui.colorer_bouton(b, Ui.VERT, true)
	var id: String = z["id"]
	b.pressed.connect(func():
		if Game.recruter(id):
			_annoncer(tr("%s rejoint le club !") % z["nom"], Ui.VERT)
			_construire()
			if FanClub.peut_recruter(Game.club, Game.niveau()):
				_ouvrir_recrutement()
			else:
				_recrutement.queue_free()
				_recrutement = null)
	v.add_child(b)
	p.tooltip_text = z.get("histoire", "")
	return p


# ------------------------------------------------------------------ caisse

func _construire_caisse() -> void:
	_caisse.add_child(Ui.label("LA CAISSE DU CLUB", 34, Ui.JAUNE, true, 8))
	var note := Ui.label(tr("La caisse garde %d h de recettes : passe récolter !") % int(FanClub.HEURES_CAISSE), 17, Ui.GRIS)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caisse.add_child(note)

	# Cotisations
	var pc := _bloc("Cotisations", Ui.BLEU)
	_lbl_cot = Ui.label("", 19, Ui.BLANC)
	_lbl_cot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(_lbl_cot)

	# Buvette
	var pb := _bloc("Buvette", Ui.ROSE)
	_lbl_buv = Ui.label("", 19, Ui.BLANC)
	_lbl_buv.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pb.add_child(_lbl_buv)
	pb.add_child(_bouton_amelioration("buvette"))

	# Atelier d'écharpes
	var pe := _bloc("Atelier d'écharpes", Ui.VIOLET)
	_lbl_ech = Ui.label("", 19, Ui.BLANC)
	_lbl_ech.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pe.add_child(_lbl_ech)
	var he := Ui.hbox(10)
	pe.add_child(he)
	_vendre = Ui.bouton("Vendre", Ui.VERT, 22)
	Ui.colorer_bouton(_vendre, Ui.VERT, true)
	_vendre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vendre.pressed.connect(func():
		var g := Game.vendre_echarpes()
		if g > 0:
			_annoncer(tr("Écharpes vendues : +%d Jetons") % g, Ui.JAUNE)
		_construire())
	he.add_child(_vendre)
	var am := _bouton_amelioration("atelier")
	am.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	he.add_child(am)

	_caisse.add_child(Ui.espace())
	_recolter = Ui.bouton("", Ui.JAUNE, 34)
	Ui.colorer_bouton(_recolter, Ui.JAUNE, true)
	_recolter.custom_minimum_size = Vector2(0, 90)
	_recolter.pressed.connect(func():
		var g := Game.recolter_caisse()
		if g > 0:
			_annoncer(tr("Caisse récoltée : +%d Jetons") % g, Ui.JAUNE)
			Ui.pop(_jetons, 1.3)
		_construire())
	_caisse.add_child(_recolter)


func _bloc(titre: String, couleur: Color) -> VBoxContainer:
	var p := Ui.panneau(Ui.NUIT_CLAIR, 18, 4)
	_caisse.add_child(p)
	var v := Ui.vbox(6)
	p.add_child(v)
	var h := Ui.hbox(8)
	var pastille := ColorRect.new()
	pastille.color = couleur
	pastille.custom_minimum_size = Vector2(14, 14)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(pastille)
	h.add_child(Ui.label(titre, 26, Ui.BLANC, true, 6))
	v.add_child(h)
	return v


func _bouton_amelioration(type: String) -> Button:
	var b := Ui.bouton("", Ui.BLEU, 20)
	b.set_meta("type", type)
	b.pressed.connect(func():
		if Game.ameliorer_local(type):
			_annoncer(tr("%s : niveau %d !") % [tr(FanClub.LOCAL[type]["titre"]), Game.club[type]], Ui.VERT)
		_construire())
	return b


func _maj_caisse() -> void:
	var c := Game.club
	var now := Game.maintenant()
	FanClub.avancer(c, now)
	var n := FanClub.nb_membres(c)
	_jetons.text = "%d" % Game.jetons
	_lbl_cot.text = tr("%d membres · %s Jetons/h (bonus de taille compris)\nEn caisse : %d") % [
		n, _nombre(FanClub.cotisations_heure(c)), int(c["caisse_cotisations"])]
	if c["buvette"] == 0:
		_lbl_buv.text = "Fermée. Ouvre-la pour vendre à boire aux supporters."
	else:
		var boost := FanClub.apres_match(c, now)
		_lbl_buv.text = tr("Niveau %d · %s Jetons/h%s\nEn caisse : %d") % [
			c["buvette"], _nombre(FanClub.buvette_heure(c) * (2.0 if boost else 1.0)),
			" · après-match x2 !" if boost else "", int(c["caisse_buvette"])]
		_lbl_buv.tooltip_text = "La buvette rapporte double pendant 3 h après chaque duel."
	if c["atelier"] == 0:
		_lbl_ech.text = "Fermé. Ouvre-le pour tricoter des écharpes aux couleurs du club."
	else:
		_lbl_ech.text = tr("Niveau %d · %d écharpe%s/h · %d Jetons pièce\nStock : %d / %d") % [
			c["atelier"], int(FanClub.echarpes_heure(c)), "s" if FanClub.echarpes_heure(c) > 1 else "",
			FanClub.prix_echarpe(c), int(c["echarpes"]), FanClub.stock_max(c)]
	var stock := int(c["echarpes"])
	_vendre.text = tr("Vendre (+%d)") % (stock * FanClub.prix_echarpe(c)) if stock > 0 else tr("Rien à vendre")
	_vendre.disabled = stock <= 0
	for b in _boutons_amelioration():
		var type: String = b.get_meta("type")
		var cout := FanClub.cout_amelioration(c, type)
		var ouvrir: bool = c[type] == 0
		if cout < 0:
			b.text = "Niveau max"
			b.disabled = true
		else:
			b.text = "%s · %d J" % [tr("Ouvrir") if ouvrir else tr("Améliorer"), cout]
			b.disabled = cout > Game.jetons
			b.tooltip_text = tr("Il te faut %d Jetons") % cout if cout > Game.jetons else ""
	var total := FanClub.en_caisse(c)
	_recolter.text = tr("RÉCOLTER +%d") % total if total > 0 else tr("CAISSE VIDE")
	_recolter.disabled = total <= 0


func _nombre(x: float) -> String:
	## « 9,1 » ou « 3 » : virgule française, pas de « .0 » inutile.
	var s := str(snappedf(x, 0.1))
	return s.trim_suffix(".0").replace(".", ",")


func _boutons_amelioration() -> Array:
	var r: Array = []
	for b in _caisse.find_children("*", "Button", true, false):  # sans_traduction
		if b.has_meta("type"):
			r.append(b)
	return r


func _annoncer(texte: String, couleur: Color) -> void:
	_message.text = texte
	_message.add_theme_color_override("font_color", couleur)
	_message.modulate.a = 1.0
	var t := _message.create_tween()
	t.tween_interval(1.6)
	t.tween_property(_message, "modulate:a", 0.0, 0.5)
