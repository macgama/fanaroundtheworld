extends Control
## « Missions » : 3 missions du jour et 3 de la semaine, qui rapportent des
## Jetons et de l'XP de PASS. Une mission du jour peut être changée chaque jour.

const FOND := Color("#178f7a")

var _jetons: Label
var _palier: Label
var _barre_pass: ProgressBar
var _col_jour: VBoxContainer
var _col_semaine: VBoxContainer
var _annonce: Label


func _ready() -> void:
	var verse := Game.actualiser_missions()
	var fond := ColorRect.new()
	fond.color = FOND
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var racine := Ui.vbox(18)
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.offset_left = 40
	racine.offset_right = -40
	racine.offset_top = 26
	racine.offset_bottom = -26
	add_child(racine)

	var haut := Ui.hbox(16)
	racine.add_child(haut)
	haut.add_child(Ui.label("MISSIONS", 60, Ui.JAUNE, true, 10))
	var st := Ui.label("Des petits défis pour ta tribune : Jetons et XP de PASS à la clé.", 22, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(st)
	# PASS : palier et progression
	var pass_p := Ui.panneau(Ui.NUIT, 20, 5)
	pass_p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pass_p.tooltip_text = tr("XP du PASS saisonnier : %d paliers de %d XP") % [Missions.PALIERS, Missions.XP_PAR_PALIER]
	var vp := Ui.vbox(4)
	pass_p.add_child(vp)
	_palier = Ui.label("", 20, Ui.JAUNE, true)
	vp.add_child(_palier)
	_barre_pass = ProgressBar.new()
	_barre_pass.custom_minimum_size = Vector2(240, 16)
	_barre_pass.show_percentage = false
	_barre_pass.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 8, 3))
	_barre_pass.add_theme_stylebox_override("fill", Ui.boite(Ui.VIOLET, 8, 0))
	vp.add_child(_barre_pass)
	haut.add_child(pass_p)
	var jet := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 36))
	_jetons = Ui.label("", 28, Ui.JAUNE, true, 6)
	hj.add_child(_jetons)
	jet.add_child(hj)
	jet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(jet)

	_annonce = Ui.label("", 22, Ui.BLANC, true, 6)
	_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(_annonce)
	if int(verse["jetons"]) > 0 or int(verse["xp_pass"]) > 0:
		_annoncer(tr("Missions terminées la dernière fois, versées pour toi : +%d Jetons · +%d XP PASS") % [verse["jetons"], verse["xp_pass"]])

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)
	_col_jour = _colonne(corps)
	_col_semaine = _colonne(corps)

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CARTE, Game.params))
	bas.add_child(retour)

	_remplir()


func _colonne(parent: Control) -> VBoxContainer:
	var p := Ui.panneau()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(p)
	var v := Ui.vbox(14)
	p.add_child(v)
	return v


func _remplir() -> void:
	_jetons.text = "%d" % Game.jetons
	var pal := Missions.palier(Game.xp_pass)
	_palier.text = tr("PASS · palier %d") % pal
	_barre_pass.value = 100.0 * Missions.xp_dans_palier(Game.xp_pass) / Missions.XP_PAR_PALIER
	var t := Game.heure_locale()
	_remplir_colonne(_col_jour, "jour", "Du jour", tr("Nouvelles missions dans %s") % _duree(Missions.avant_renouvellement(t, "jour")))
	_remplir_colonne(_col_semaine, "semaine", "De la semaine", tr("Nouvelles missions dans %s") % _duree(Missions.avant_renouvellement(t, "semaine")))


func _remplir_colonne(v: VBoxContainer, periode: String, titre: String, sous_titre: String) -> void:
	for c in v.get_children():
		c.queue_free()
	var h := Ui.hbox(12)
	h.add_child(Ui.label(titre, 34, Ui.BLANC, true, 6))
	var st := Ui.label(sous_titre, 18, Ui.GRIS)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(st)
	v.add_child(h)
	var liste: Array = Game.missions["du_jour" if periode == "jour" else "de_la_semaine"]
	for i in liste.size():
		v.add_child(_carte(periode, i, liste[i]))
	var bonus: Dictionary = Missions.BONUS[periode]
	var pris := bool(Game.missions["bonus_" + periode])
	var txt_bonus := "Bonus récupéré : bravo !"
	if not pris:
		txt_bonus = tr("Les %d récupérées : +%d Jetons · +%d XP PASS en bonus") % [liste.size(), bonus["jetons"], bonus["xp_pass"]]
	var b := Ui.label(txt_bonus, 18, Ui.JAUNE if pris else Ui.GRIS)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(b)
	if periode == "jour":
		var regle := Ui.label("Pas besoin de revenir chaque jour : une mission terminée et oubliée est versée automatiquement.", 16, Ui.GRIS)
		regle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(regle)


func _carte(periode: String, i: int, m: Dictionary) -> Control:
	var finie := Missions.terminee(m)
	var prise := bool(m["recuperee"])
	var couleur := Ui.NUIT_CLAIR
	if prise:
		couleur = Color("#3a3560")
	elif finie:
		couleur = Color("#2e7d5b")
	var cadre := Ui.panneau(couleur, 18, 4)
	var h := Ui.hbox(14)
	cadre.add_child(h)
	h.add_child(Ui.icone("cible", 44))
	var v := Ui.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Ui.label(m["titre"], 24, Ui.BLANC, true))
	var t := Ui.label(m["texte"], 17, Ui.GRIS)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var hp := Ui.hbox(10)
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(220, 16)
	barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barre.show_percentage = false
	barre.max_value = int(m["n"])
	barre.value = int(m["progres"])
	barre.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 8, 3))
	barre.add_theme_stylebox_override("fill", Ui.boite(Ui.VERT if finie else Ui.BLEU, 8, 0))
	hp.add_child(barre)
	hp.add_child(Ui.label("%d / %d" % [int(m["progres"]), int(m["n"])], 18, Ui.BLANC, true))
	v.add_child(hp)
	# récompense + action
	var d := Ui.vbox(6)
	d.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(d)
	var hr := Ui.hbox(6)
	hr.alignment = BoxContainer.ALIGNMENT_END
	hr.add_child(Ui.icone("jeton", 26))
	hr.add_child(Ui.label("+%d" % int(m["jetons"]), 22, Ui.JAUNE, true, 5))
	hr.add_child(Ui.label(tr("· +%d XP PASS") % int(m["xp_pass"]), 18, Ui.BLANC, true))
	d.add_child(hr)
	if prise:
		var ok := Ui.label("Récupérée", 20, Ui.GRIS, true)
		ok.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		d.add_child(ok)
	elif finie:
		var b := Ui.bouton("Récupérer", Ui.JAUNE, 22)
		Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.custom_minimum_size = Vector2(200, 56)
		b.pressed.connect(_recuperer.bind(periode, i))
		d.add_child(b)
	elif periode == "jour" and Missions.peut_changer(Game.missions, i):
		var b := Ui.bouton("Changer", Ui.NUIT, 18)
		b.custom_minimum_size = Vector2(160, 46)
		b.tooltip_text = "Une mission du jour peut être changée une fois par jour"
		b.pressed.connect(_changer.bind(i))
		d.add_child(b)
	return cadre


func _recuperer(periode: String, i: int) -> void:
	var g := Game.recuperer_mission(periode, i)
	if g.is_empty():
		return
	var txt := tr("+%d Jetons · +%d XP PASS") % [g["jetons"], g["xp_pass"]]
	if g["bonus"]:
		txt += tr(" (bonus compris !)")
	_annoncer(txt)
	_remplir()


func _changer(i: int) -> void:
	if Game.changer_mission(i):
		_annoncer("Nouvelle mission du jour !")
		_remplir()


func _annoncer(txt: String) -> void:
	_annonce.text = txt
	Ui.pop(_annonce, 1.1)


static func _duree(s: int) -> String:
	if s >= 86400:
		var j := s / 86400
		return Trad.t("%d jour%s") % [j, "s" if j > 1 else ""]
	if s >= 3600:
		return "%d h" % (s / 3600)
	return Trad.t("%d min") % maxi(1, s / 60)
