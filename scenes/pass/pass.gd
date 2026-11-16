extends Control
## « PASS » : la saison en 100 paliers. Piste gratuite en haut, piste Premium
## en bas, palier et XP en cours, achat du Premium (DLC Steam, en euros).
## Cliquer une récompense prête la récupère ; « Tout récupérer » prend tout.

const LARGEUR_COL := 172
const H_CARTE := 290
const COULEUR_GRATUIT := Color("#4b4596")
const COULEUR_PREMIUM := Color("#ffb627")
const COULEUR_SKIN := Color("#ff5d9e")
const COULEUR_RECRUE := Color("#8b5cff")
## Couleur de chaque thème de chapitre (cartes et icônes).
const COULEURS_THEMES := {
	"halloween": Color("#ff8a2b"), "prehistorique": Color("#8fd3ff"),
	"apocalyptique": Color("#9be15d"), "dore": Color("#ffd23f"),
}

var _data: Dictionary
var _defile: ScrollContainer
var _piste: HBoxContainer
var _annonce: Label
var _b_tout: Button
var _haut: HBoxContainer
var _gauche: Control


func _ready() -> void:
	Game.actualiser_pass()
	_data = Game.pass_data
	var fond := TextureRect.new()
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color("#ff8a3d"), Color("#ff4f8b"), Color("#7b4dff")])
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill_from = Vector2(0, 0)
	tex.fill_to = Vector2(1, 1)
	fond.texture = tex
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var racine := Ui.vbox(16)
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.offset_left = 36
	racine.offset_right = -36
	racine.offset_top = 24
	racine.offset_bottom = -24
	add_child(racine)

	if _data.is_empty():
		_saison_absente(racine)
		return

	_haut = Ui.hbox(18)
	racine.add_child(_haut)
	_annonce = Ui.label("", 22, Ui.BLANC, true, 6)
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_annonce.custom_minimum_size.y = 30
	racine.add_child(_annonce)

	var milieu := Ui.hbox(22)
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(milieu)
	_gauche = Control.new()
	milieu.add_child(_gauche)
	var cadre := Ui.panneau(Ui.NUIT, 28, 6)
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milieu.add_child(cadre)
	var hp := Ui.hbox(10)
	cadre.add_child(hp)
	var etiquettes := Ui.vbox(10)
	etiquettes.add_child(_entete_vide())
	etiquettes.add_child(_etiquette_piste("GRATUIT", COULEUR_GRATUIT, Ui.BLANC))
	etiquettes.add_child(_etiquette_piste("PREMIUM", COULEUR_PREMIUM, Ui.CONTOUR))
	hp.add_child(etiquettes)
	_defile = ScrollContainer.new()
	_defile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	hp.add_child(_defile)
	_piste = Ui.hbox(10)
	_defile.add_child(_piste)

	var bas := Ui.hbox(16)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(220, 80)
	retour.pressed.connect(_retour)
	bas.add_child(retour)
	for c in _data["chapitres"].size():
		var ch: Dictionary = _data["chapitres"][c]
		var b := Ui.bouton(tr("Ch. %d · %s") % [c + 1, ch["nom"]], Ui.NUIT_CLAIR, 20)
		b.custom_minimum_size = Vector2(0, 64)
		b.tooltip_text = tr("Paliers %d à %d · thème %s") % [int(ch["premier"]), int(ch["premier"]) + 24, ch["theme_nom"]]
		b.pressed.connect(_aller_palier.bind(int(ch["premier"])))
		bas.add_child(b)
	_b_tout = Ui.bouton("", Ui.JAUNE, 28)
	_b_tout.custom_minimum_size = Vector2(320, 80)
	_b_tout.pressed.connect(_tout_recuperer)
	bas.add_child(_b_tout)

	_remplir()
	_aller_palier.call_deferred(PassSaison.palier(Game.xp_pass) - 1)


func _unhandled_input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed or _defile == null:
		return
	if ev.keycode in [KEY_LEFT, KEY_RIGHT, KEY_ESCAPE]:
		get_viewport().set_input_as_handled()
	match ev.keycode:
		KEY_LEFT:
			_defile.scroll_horizontal -= LARGEUR_COL + 10
		KEY_RIGHT:
			_defile.scroll_horizontal += LARGEUR_COL + 10
		KEY_ESCAPE:
			_retour()


func _retour() -> void:
	if Game.params.get("retour", "") == "club":
		Game.aller(Game.SCENE_CLUB)
	else:
		Game.aller(Game.SCENE_CARTE, Game.params)


func _aller_palier(p: int) -> void:
	if _defile:
		_defile.scroll_horizontal = maxi(0, (p - 1) * (LARGEUR_COL + 10))


# ---------------------------------------------------------------- haut de l'écran

func _remplir() -> void:
	var t := Game.heure_locale()
	var xp := Game.xp_pass
	var pal := PassSaison.palier(xp)
	for c in _haut.get_children():
		c.queue_free()
	var titre := Ui.vbox(2)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre.add_child(Ui.label(tr("SAISON %d") % int(_data["numero"]), 72, Ui.BLANC, true, 12))
	var ch: Dictionary = _data["chapitres"][PassSaison.chapitre_du_jour(_data, t)]
	var sous := tr("Suit la vraie saison de foot · fin dans %d j") % PassSaison.jours_restants(_data, t)
	if PassSaison.en_intersaison(_data, t):
		sous = tr("Intersaison : ton XP est mise de côté pour la prochaine saison (%d / %d)") % [int(Game.etat_pass["report"]), PassSaison.REPORT_MAX]
	titre.add_child(Ui.label(sous, 24, Ui.BLANC, true, 6))
	titre.add_child(Ui.label(tr("Chapitre %d · %s (thème %s)") % [_data["chapitres"].find(ch) + 1, ch["nom"], ch["theme_nom"]], 20, Ui.JAUNE, true, 5))
	_haut.add_child(titre)

	var bp := Ui.panneau(Ui.NUIT, 24, 6)
	bp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var vp := Ui.vbox(0)
	bp.add_child(vp)
	var l1 := Ui.label("PALIER", 22, Ui.BLANC, true)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vp.add_child(l1)
	var hn := Ui.hbox(4)
	hn.alignment = BoxContainer.ALIGNMENT_CENTER
	hn.add_child(Ui.label(str(pal), 64, Ui.JAUNE, true, 10))
	var sur := Ui.label("/ %d" % PassSaison.PALIERS, 30, Ui.BLANC, true, 6)
	sur.size_flags_vertical = Control.SIZE_SHRINK_END
	hn.add_child(sur)
	vp.add_child(hn)
	if PassSaison.paliers_bonus(xp) > 0:
		var lb := Ui.label(tr("+ %d bonus") % PassSaison.paliers_bonus(xp), 18, Ui.VERT, true)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vp.add_child(lb)
	_haut.add_child(bp)

	var bx := Ui.panneau(Ui.NUIT, 24, 6)
	bx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bx.custom_minimum_size.x = 420
	var vx := Ui.vbox(6)
	bx.add_child(vx)
	var vers := tr("XP vers le palier %d") % (pal + 1) if pal < PassSaison.PALIERS else tr("XP vers le palier bonus %d") % (PassSaison.paliers_bonus(xp) + 1)
	vx.add_child(Ui.label(vers, 22, Ui.BLANC, true))
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(380, 22)
	barre.show_percentage = false
	barre.max_value = PassSaison.XP_PAR_PALIER
	barre.value = PassSaison.xp_dans_palier(xp) if pal < PassSaison.PALIERS else (xp - (PassSaison.PALIERS - 1) * PassSaison.XP_PAR_PALIER) % PassSaison.XP_PAR_PALIER
	barre.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 10, 3))
	barre.add_theme_stylebox_override("fill", Ui.boite(COULEUR_PREMIUM, 10, 0))
	vx.add_child(barre)
	vx.add_child(Ui.label(tr("%d / %d · Missions, duels, stades, pronostics") % [int(barre.value), PassSaison.XP_PAR_PALIER], 18, Ui.BLANC, true))
	if Game.rattrapage_pass():
		var r := Ui.label(tr("Rattrapage : missions à double XP (rythme : palier %d)") % PassSaison.palier_attendu(_data, t), 17, Ui.VERT, true, 4)
		r.tooltip_text = "Tu es en retard sur le rythme de la saison : tes missions rapportent double XP jusqu'à ce que tu rattrapes."
		r.mouse_filter = Control.MOUSE_FILTER_PASS
		vx.add_child(r)
	_haut.add_child(bx)

	var bj := Ui.panneau(Ui.NUIT, 24, 6)
	bj.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 40))
	hj.add_child(Ui.label(str(Game.jetons), 32, Ui.JAUNE, true, 6))
	bj.add_child(hj)
	_haut.add_child(bj)

	_remplir_premium()
	_remplir_piste()
	var n := Game.pass_a_recuperer()
	_b_tout.text = tr("Tout récupérer · %d") % n if n > 0 else tr("Rien à récupérer")
	_b_tout.disabled = n == 0
	Ui.colorer_bouton(_b_tout, Ui.JAUNE if n > 0 else Ui.NUIT_CLAIR, n > 0)


# ---------------------------------------------------------------- panneau Premium

func _remplir_premium() -> void:
	var parent := _gauche.get_parent()
	var idx := _gauche.get_index()
	_gauche.queue_free()
	var pan := Ui.panneau(Ui.NUIT, 28, 6)
	pan.custom_minimum_size.x = 430
	parent.add_child(pan)
	parent.move_child(pan, idx)
	_gauche = pan
	var v := Ui.vbox(8)
	pan.add_child(v)
	var l1 := Ui.label("PASS PREMIUM", 30, Ui.JAUNE, true, 6)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Ui.label(str(_data["titre"]).to_upper(), 48, Ui.BLANC, true, 10)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	var img := TextureRect.new()
	var dernier := PassSaison.recompense(_data, PassSaison.PALIERS, "premium")
	var skins_dernier: Array = dernier.get("skins", [])
	img.texture = Game.texture_skin(str(skins_dernier[0]["skin"]) if skins_dernier.size() > 0 else "")
	img.custom_minimum_size = Vector2(0, 250)
	img.size_flags_vertical = Control.SIZE_EXPAND_FILL
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.tooltip_text = tr("Palier 100 Premium : %s") % dernier.get("nom", "")
	v.add_child(img)
	for ligne in [
		[true, "100 paliers de récompenses"],
		[true, "40 skins de FANZZY + le légendaire doré"],
		[true, "Écharpes, drapeaux, émotes, tifos, décors"],
		[true, "Paliers déjà atteints débloqués tout de suite"],
		[false, "Aucun bonus en duel : 100 % cosmétique"],
	]:
		var h := Ui.hbox(8)
		h.add_child(_Icone.creer("ok" if ligne[0] else "non", 24, Ui.VERT if ligne[0] else Ui.JAUNE))
		var l := Ui.label(ligne[1], 19, Ui.BLANC if ligne[0] else Ui.JAUNE, true)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)
	if bool(Game.etat_pass["premium"]):
		var ok := Ui.pastille("PREMIUM ACTIF", Ui.VERT, 28, true)
		ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ok)
	else:
		var b := Ui.bouton(tr("ACHETER · %s") % PassSaison.PRIX, Ui.JAUNE, 32)
		Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.custom_minimum_size = Vector2(0, 78)
		b.tooltip_text = "Vendu sur Steam comme un DLC, payé en euros. Pas de monnaie virtuelle, pas de paliers à acheter."
		b.pressed.connect(_acheter)
		v.add_child(b)
	var note := Ui.label("Personne n'achète de paliers : tout le monde avance au même rythme.", 15, Ui.GRIS)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(note)


func _acheter() -> void:
	if Game.acheter_premium():
		_annoncer("Achat dans Steam : le Premium s'active dès que Steam confirme.")
	else:
		_annoncer(tr("Le PASS Premium sera vendu sur Steam (DLC à %s) à la sortie du jeu.") % PassSaison.PRIX)


# ---------------------------------------------------------------- piste des paliers

func _entete_vide() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, 44)
	return c


func _etiquette_piste(texte: String, couleur: Color, couleur_texte: Color) -> Control:
	var p := Ui.panneau(couleur, 18, 5)
	p.custom_minimum_size = Vector2(130, H_CARTE)
	var l := Ui.label(texte, 24, couleur_texte, true, 4 if couleur_texte == Ui.BLANC else 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


func _remplir_piste() -> void:
	var defile := _defile.scroll_horizontal
	for c in _piste.get_children():
		c.queue_free()
	var pal := PassSaison.palier(Game.xp_pass)
	for p in range(1, PassSaison.PALIERS + 1):
		_piste.add_child(_colonne(p, pal))
	_piste.add_child(_colonne_bonus())
	_defile.set_deferred("scroll_horizontal", defile)


func _colonne(p: int, pal: int) -> Control:
	var v := Ui.vbox(10)
	v.custom_minimum_size.x = LARGEUR_COL
	var atteint := p <= pal
	var couleur_entete := Ui.VERT if p < pal else (Ui.JAUNE if p == pal else Ui.NUIT_CLAIR)
	var ent := Ui.pastille(("%d ◀" % p) if p == pal else str(p), couleur_entete, 24, p <= pal)
	ent.custom_minimum_size = Vector2(LARGEUR_COL, 44)
	if p % 25 == 1:
		var ch: Dictionary = _data["chapitres"][PassSaison.chapitre_du_palier(p)]
		ent.tooltip_text = tr("Chapitre %d · %s") % [PassSaison.chapitre_du_palier(p) + 1, ch["nom"]]
	v.add_child(ent)
	for piste in ["gratuit", "premium"]:
		v.add_child(_carte(p, piste, atteint))
	return v


func _carte(p: int, piste: String, atteint: bool) -> Control:
	var r := PassSaison.recompense(_data, p, piste)
	var b := Button.new()
	b.custom_minimum_size = Vector2(LARGEUR_COL, H_CARTE)
	b.focus_mode = Control.FOCUS_NONE
	if r.is_empty():
		b.disabled = true
		var st := Ui.boite(Color(0.1, 0.08, 0.3, 0.35), 18, 0)
		for e in ["normal", "disabled", "hover", "pressed"]:
			b.add_theme_stylebox_override(e, st)
		return b
	var premium := piste == "premium"
	var recue := PassSaison.recue(Game.etat_pass, p, piste)
	var dispo := PassSaison.disponible(_data, Game.etat_pass, Game.xp_pass, p, piste)
	var bloque := premium and not bool(Game.etat_pass["premium"])
	var type := str(r["type"])
	var fond := COULEUR_PREMIUM if premium else COULEUR_GRATUIT
	if type in ["skin", "tribune"]:
		fond = COULEUR_SKIN if not premium else COULEUR_PREMIUM.lerp(COULEUR_SKIN, 0.45)
	elif type == "recrue":
		fond = COULEUR_RECRUE
	if not atteint:
		fond = fond.darkened(0.25)
	var contour := Ui.JAUNE if dispo else Ui.CONTOUR
	var largeur_contour := 6 if dispo else 4
	b.add_theme_stylebox_override("normal", Ui.boite(fond, 18, largeur_contour, 4, contour))
	b.add_theme_stylebox_override("hover", Ui.boite(fond.lightened(0.12), 18, largeur_contour, 4, contour))
	b.add_theme_stylebox_override("pressed", Ui.boite(fond.darkened(0.1), 18, largeur_contour, 1, contour))
	b.add_theme_stylebox_override("disabled", Ui.boite(fond, 18, largeur_contour, 4, contour))
	b.tooltip_text = _info(r, p, piste, dispo, recue, bloque)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(_cliquer.bind(p, piste))

	var v := Ui.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 8
	v.offset_right = -8
	v.offset_top = 10
	v.offset_bottom = -8
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var theme := str(_data["chapitres"][PassSaison.chapitre_du_palier(p)]["theme"])
	var visuel := _visuel(r, theme)
	visuel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(visuel)
	var sombre := premium and type not in ["skin", "tribune", "recrue"]
	var nom := Ui.label(_titre_carte(r), 17, Ui.CONTOUR if sombre else Ui.BLANC, true, 0 if sombre else 4)
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.max_lines_visible = 3
	nom.add_theme_font_size_override("font_size", 19)
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nom)

	if recue:
		b.add_child(_badge("ok", Ui.VERT))
	elif bloque:
		b.add_child(_badge("cadenas", Ui.CONTOUR))
	elif dispo:
		var l := Ui.pastille("Récupérer", Ui.JAUNE, 15, true)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		l.set_anchors_preset(Control.PRESET_CENTER_TOP)
		l.position = Vector2(LARGEUR_COL / 2.0 - 52, -12)
		b.add_child(l)
	if recue or (not atteint):
		v.modulate = Color(1, 1, 1, 0.75 if recue else 0.85)
	return b


func _badge(type: String, couleur: Color) -> Control:
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2(LARGEUR_COL - 44, 8)
	c.custom_minimum_size = Vector2(36, 36)
	c.size = Vector2(36, 36)
	var fond := Panel.new()
	fond.add_theme_stylebox_override("panel", Ui.boite(couleur if type == "ok" else Ui.BLANC, 18, 3))
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(fond)
	var i := _Icone.creer(type, 36, Ui.BLANC if type == "ok" else couleur)
	i.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(i)
	return c


func _colonne_bonus() -> Control:
	var v := Ui.vbox(10)
	v.custom_minimum_size.x = LARGEUR_COL
	var ent := Ui.pastille("100 +", Ui.VIOLET, 24)
	ent.custom_minimum_size = Vector2(LARGEUR_COL, 44)
	v.add_child(ent)
	var p := Ui.panneau(Ui.VIOLET.darkened(0.2), 18, 4)
	p.custom_minimum_size = Vector2(LARGEUR_COL, H_CARTE * 2 + 10)
	var vv := Ui.vbox(8)
	vv.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(vv)
	var ic := Ui.icone("jeton", 70)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vv.add_child(ic)
	var l := Ui.label(tr("Paliers bonus\n+%d Jetons\ntous les %d XP") % [PassSaison.JETONS_PALIER_BONUS, PassSaison.XP_PAR_PALIER], 18, Ui.BLANC, true, 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vv.add_child(l)
	v.add_child(p)
	return v


## Image d'une récompense.
func _visuel(r: Dictionary, theme: String) -> Control:
	var type := str(r["type"])
	if type in ["skin", "recrue", "tribune"]:
		var ids: Array = []
		match type:
			"skin":
				ids = [r["skin"]]
			"recrue":
				ids = [r["fanzzy"]]
			"tribune":
				ids = r["skins"].slice(0, 3).map(func(s): return s["skin"])
		var h := Ui.hbox(-30 if ids.size() > 1 else 0)
		h.alignment = BoxContainer.ALIGNMENT_CENTER
		h.custom_minimum_size.y = 160
		for id in ids:
			var t := TextureRect.new()
			t.texture = Game.texture_skin(str(id), true)
			t.custom_minimum_size = Vector2(160 if ids.size() == 1 else 96, 160 if ids.size() == 1 else 120)
			t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			t.mouse_filter = Control.MOUSE_FILTER_IGNORE
			h.add_child(t)
		if type == "recrue":
			var z := Game.fanzzy_par_id(str(r["fanzzy"]))
			if z.get("rarete", "") == "legendaire":
				h.modulate = Color(1.0, 0.95, 0.75)
		return h
	if type == "jetons":
		var c := CenterContainer.new()
		c.custom_minimum_size.y = 160
		c.add_child(Ui.icone("jeton", 110))
		return c
	var c2 := CenterContainer.new()
	c2.custom_minimum_size.y = 160
	c2.add_child(_Icone.creer(type, 116, COULEURS_THEMES.get(theme, Ui.ROSE)))
	return c2


func _titre_carte(r: Dictionary) -> String:
	match str(r["type"]):
		"jetons":
			return tr("%d Jetons") % int(r["n"])
		"recrue":
			var z := Game.fanzzy_par_id(str(r["fanzzy"]))
			return tr("Recrue%s\n%s") % [tr(" légendaire") if z.get("rarete", "") == "legendaire" else "", r["nom"]]
	return str(r["nom"])


func _info(r: Dictionary, p: int, piste: String, dispo: bool, recue: bool, bloque: bool) -> String:
	var t := tr("Palier %d · %s\n") % [p, tr("piste Premium") if piste == "premium" else tr("piste gratuite")]
	match str(r["type"]):
		"jetons":
			t += tr("%d Jetons pour tes billets et trajets.") % int(r["n"])
		"recrue":
			var z := Game.fanzzy_par_id(str(r["fanzzy"]))
			t += tr("Nouveau FANZZY jouable : %s (%s).\n%s") % [r["nom"], Game.nom_famille(z.get("famille", "")), z.get("histoire", "")]
		"skin":
			t += tr("Skin (cosmétique) : %s.") % r["nom"]
		"tribune":
			t += "%s : %s." % [r["nom"], ", ".join(r["skins"].map(func(s): return s["nom"]))]
		var type:
			t += tr("%s : %s.\nObjet d'apparence, à retrouver bientôt dans ton local et ta tribune.") % [PassSaison.TYPES_OBJETS.get(type, tr("Objet")), r["nom"]]
	if recue:
		t += "\nDéjà récupéré."
	elif bloque:
		t += "\nAvec le PASS Premium."
	elif dispo:
		t += "\nClique pour récupérer."
	else:
		t += tr("\nEncore %d XP.") % maxi(0, (p - 1) * PassSaison.XP_PAR_PALIER - Game.xp_pass)
	return t


func _cliquer(p: int, piste: String) -> void:
	var r := PassSaison.recompense(_data, p, piste)
	if PassSaison.disponible(_data, Game.etat_pass, Game.xp_pass, p, piste):
		var g := Game.recuperer_pass(p, piste)
		_annoncer_gain(g)
		_remplir()
	elif PassSaison.recue(Game.etat_pass, p, piste):
		_annoncer(tr("%s : déjà récupéré.") % _titre_carte(r).replace("\n", " "))
	elif piste == "premium" and not bool(Game.etat_pass["premium"]):
		_annoncer(tr("Palier %d Premium : %s. Avec le PASS Premium (%s).") % [p, _titre_carte(r).replace("\n", " "), PassSaison.PRIX])
	else:
		_annoncer(tr("Palier %d : encore %d XP.") % [p, maxi(0, (p - 1) * PassSaison.XP_PAR_PALIER - Game.xp_pass)])


func _tout_recuperer() -> void:
	var g := Game.recuperer_pass()
	if g.is_empty() or PassSaison.resume(g) == "":
		_annoncer("Rien à récupérer pour l'instant.")
		return
	_annoncer_gain(g)
	_remplir()


func _annoncer_gain(g: Dictionary) -> void:
	if g.is_empty():
		return
	var txt := tr("Récupéré : ") + PassSaison.resume(g)
	if g["skins"].size() > 0:
		txt += " · à choisir dans « FANZZY »"
	elif g["fanzzy"].size() > 0:
		txt += " · rejoint ta tribune possible"
	_annoncer(txt)


func _annoncer(txt: String) -> void:
	if _annonce == null:
		return
	_annonce.text = txt
	Ui.pop(_annonce, 1.08)


func _saison_absente(racine: Control) -> void:
	racine.add_child(Ui.espace())
	var l := Ui.label("PASS", 80, Ui.BLANC, true, 12)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(l)
	var t := Ui.label("La prochaine saison du PASS se prépare. Ton XP est gardée en attendant.", 30, Ui.BLANC, true, 6)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(t)
	racine.add_child(Ui.espace())
	var b := Ui.bouton("Retour", Ui.NUIT, 28)
	b.custom_minimum_size = Vector2(260, 80)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(_retour)
	racine.add_child(b)


## Petites icônes dessinées des objets d'apparence (pas d'emoji).
class _Icone extends Control:
	var type := ""
	var couleur := Color.WHITE

	static func creer(t: String, taille: int, c: Color) -> Control:
		var i := _Icone.new()
		i.type = t
		i.couleur = c
		i.custom_minimum_size = Vector2(taille, taille)
		i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		i.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return i

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size / 2.0
		var lw := maxf(2.0, s * 0.08)
		var noir := Ui.CONTOUR
		match type:
			"ok":
				draw_polyline(PackedVector2Array([c + Vector2(-s * 0.26, 0), c + Vector2(-s * 0.06, s * 0.2), c + Vector2(s * 0.28, -s * 0.2)]), couleur, s * 0.14, true)
			"non":
				draw_line(c + Vector2(-s * 0.22, -s * 0.22), c + Vector2(s * 0.22, s * 0.22), couleur, s * 0.14, true)
				draw_line(c + Vector2(s * 0.22, -s * 0.22), c + Vector2(-s * 0.22, s * 0.22), couleur, s * 0.14, true)
			"cadenas":
				draw_arc(c + Vector2(0, -s * 0.06), s * 0.17, PI, TAU, 16, couleur, s * 0.08, true)
				draw_rect(Rect2(c + Vector2(-s * 0.24, -s * 0.06), Vector2(s * 0.48, s * 0.34)), couleur)
			"echarpe":
				var r := Rect2(c + Vector2(-s * 0.44, -s * 0.16), Vector2(s * 0.88, s * 0.32))
				draw_rect(r.grow(lw * 0.5), noir)
				for k in 6:
					draw_rect(Rect2(r.position + Vector2(k * r.size.x / 6.0, 0), Vector2(r.size.x / 6.0, r.size.y)), couleur if k % 2 == 0 else Ui.BLANC)
				for k in 4:
					draw_line(r.position + Vector2(-k * s * 0.03, r.size.y), r.position + Vector2(-k * s * 0.03 + s * 0.02, r.size.y + s * 0.14), couleur, lw * 0.6)
			"drapeau":
				draw_line(c + Vector2(-s * 0.3, -s * 0.44), c + Vector2(-s * 0.3, s * 0.44), noir, lw * 1.4)
				var pts := PackedVector2Array([c + Vector2(-s * 0.28, -s * 0.42), c + Vector2(s * 0.42, -s * 0.28), c + Vector2(-s * 0.28, -s * 0.02)])
				draw_colored_polygon(pts, couleur)
				draw_polyline(pts + PackedVector2Array([pts[0]]), noir, lw * 0.7, true)
			"tifo":
				var cases := [couleur, Ui.BLANC, Ui.ROSE, Ui.BLEU]
				for x in 4:
					for y in 3:
						draw_rect(Rect2(c + Vector2(-s * 0.44 + x * s * 0.22, -s * 0.33 + y * s * 0.22), Vector2(s * 0.2, s * 0.2)), cases[(x + y) % 4])
			"decor":
				var base := Rect2(c + Vector2(-s * 0.32, -s * 0.04), Vector2(s * 0.64, s * 0.42))
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.42, 0), c + Vector2(0, -s * 0.4), c + Vector2(s * 0.42, 0)]), couleur)
				draw_rect(base, Ui.BLANC)
				draw_rect(Rect2(c + Vector2(-s * 0.08, s * 0.14), Vector2(s * 0.16, s * 0.24)), couleur.darkened(0.3))
			"emote":
				draw_circle(c, s * 0.42, noir)
				draw_circle(c, s * 0.36, couleur)
				draw_circle(c + Vector2(-s * 0.13, -s * 0.08), s * 0.05, noir)
				draw_circle(c + Vector2(s * 0.13, -s * 0.08), s * 0.05, noir)
				draw_arc(c + Vector2(0, s * 0.04), s * 0.18, 0.2, PI - 0.2, 12, noir, lw, true)
			"son":
				draw_circle(c + Vector2(-s * 0.18, s * 0.26), s * 0.13, couleur)
				draw_circle(c + Vector2(s * 0.24, s * 0.16), s * 0.13, couleur)
				draw_line(c + Vector2(-s * 0.06, s * 0.26), c + Vector2(-s * 0.06, -s * 0.36), couleur, lw * 1.3)
				draw_line(c + Vector2(s * 0.36, s * 0.16), c + Vector2(s * 0.36, -s * 0.44), couleur, lw * 1.3)
				draw_line(c + Vector2(-s * 0.06, -s * 0.36), c + Vector2(s * 0.36, -s * 0.44), couleur, lw * 2.2)
			"couverture":
				var r2 := Rect2(c + Vector2(-s * 0.3, -s * 0.4), Vector2(s * 0.6, s * 0.8))
				draw_rect(r2.grow(lw * 0.5), noir)
				draw_rect(r2, couleur)
				draw_rect(Rect2(r2.position, Vector2(s * 0.1, r2.size.y)), couleur.darkened(0.35))
				draw_circle(c + Vector2(s * 0.05, 0), s * 0.12, Ui.BLANC)
			"titre":
				var pts2 := PackedVector2Array([c + Vector2(-s * 0.46, -s * 0.14), c + Vector2(s * 0.46, -s * 0.14), c + Vector2(s * 0.36, 0),
					c + Vector2(s * 0.46, s * 0.14), c + Vector2(-s * 0.46, s * 0.14), c + Vector2(-s * 0.36, 0)])
				draw_colored_polygon(pts2, couleur)
				draw_polyline(pts2 + PackedVector2Array([pts2[0]]), noir, lw * 0.7, true)
				draw_circle(c + Vector2(0, -s * 0.3), s * 0.12, Ui.JAUNE)
			_:
				draw_circle(c, s * 0.4, couleur)
