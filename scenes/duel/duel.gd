class_name Duel
extends Control
## Duel d'ambiance : ta tribune contre la tribune adverse, pendant 90 secondes
## (une seconde = une minute de match).
##   Chant (ESPACE ou clic) : appuie quand la note arrive dans le cercle.
##   Tifo (T) : se charge avec les bons chants, puis gros boost.
##   Ola (O) : prête toutes les 20 s, enchaîne 4 flèches à temps.
## Si le fan club a composé son chant (créateur de chants, ChantClub), la
## piste suit ce chant, à son tempo, avec ses paroles façon karaoké ; chaque
## couplet sans erreur charge le tifo. Sinon, des motifs au hasard.
## La jauge d'ambiance dit qui domine. Le vrai score du match donne un bonus,
## et un vrai but pendant le duel fait exploser la tribune.
## Touches de test : B = simuler un but pour toi, N = but adverse.
## En ligne (Game.params["en_ligne"]) : l'adversaire est un vrai joueur. Chacun joue sa
## piste chez lui, et la jauge est partagée (l'hôte fait foi, voir Protocole.JaugePartagee).

const DUREE := 90.0
const BPM := 112.0
const TRAJET_NOTE := 1.7      # secondes entre l'apparition d'une note et le cercle
const FENETRE_BIEN := 0.13
const FENETRE_PARFAIT := 0.055
const OLA_PERIODE := 20.0
const MOTIFS := [[1, 1, 1, 1], [1, 0, 1, 0], [1, 1, 0, 1], [1, 0, 1, 1], [0, 1, 1, 1], [1, 1, 1, 0], [1, 0, 0, 1]]
const FLECHES := ["ui_left", "ui_up", "ui_right", "ui_down"]

var fiche: Dictionary
var camp := "home"
var mode := "stade"

# état du duel
var temps := 0.0
var jauge := 0.0             # -100 (adversaire) … +100 (toi)
var points := 0
var combo := 0
var combo_max := 0
var parfaits := 0
var biens := 0
var rates := 0
var charge_tifo := 0.0
var tifos := 0
var olas := 0
var termine := false
var pret := false

var _notes: Array = []        # temps (s) des notes à jouer
var _prochaine_mesure := 0.0
var _beat := 60.0 / BPM
var _dernier_beat := -1
var _ola_prete_a := OLA_PERIODE * 0.6
var _ola_sequence: Array = []
var _ola_index := 0
var _ola_fin := 0.0
var _chant_adverse_fin := -1.0
var _prochain_chant_adverse := 12.0
var _bonus_score := 1.0
var _score_vu := Vector2i(-1, -1)

# chant du club (vide : motifs au hasard)
var _chant_club: Array = []            # ChantClub.programme
var _chant_nom := ""
var _mesure_chant := 0            # mesures préparées depuis le début
var _frappes_chant: Array = []    # [{t, voix, force}] à jouer
var _lignes: Array = []           # [{t0, t1, i, cycle, appuis}] pour le karaoké
var _fins_couplet := {}           # instant de la dernière note d'un couplet -> n° du couplet
var _couplets_rates := {}         # n° du couplet -> true dès une erreur
var couplets_parfaits := 0
var _sons_chant: Node
var _paroles: RichTextLabel

# bonus des FANZZY (multiplicatifs)
var mods := {}

# --- en ligne
var en_ligne := false
var _jp: Protocole.JaugePartagee
var _adv_pret := false
var _moi_pret := false
var _t_etat := 0.0
var _attente_fin := false
var _forfait := false
var _depart_envoye := false

# nœuds
var _decor: Decor
var _piste: Piste
var _fanzzy: Array = []       # Marionnette
var _jauge_barre: Control
var _lbl_temps: Label
var _lbl_score_reel: Label
var _lbl_minute_reelle: Label
var _lbl_combo: Label
var _lbl_combo_sous: Label
var _lbl_info: Label
var _btn_chant: Button
var _btn_tifo: Button
var _btn_ola: Button
var _barre_tifo: ProgressBar
var _panneau_ola: PanelContainer
var _fleches_ola: HBoxContainer
var _banniere: Control
var _sons: Dictionary = {}


func _ready() -> void:
	var p: Dictionary = Game.params
	en_ligne = bool(p.get("en_ligne", false)) and Reseau.connecte()
	var m: Dictionary = p.get("match", {}) if en_ligne else Donnees.match_par_id(str(p.get("match_id", "")))
	if m.is_empty():
		Game.aller(Game.SCENE_CARTE)
		return
	fiche = FicheMatch.de(m)
	camp = p.get("camp", "home")
	mode = p.get("mode", "stade")
	mods = Duel.mods_equipe()
	_preparer_chant()
	_preparer_sons()
	_construire()
	_calculer_bonus_score(true)
	Donnees.mis_a_jour.connect(func(): _calculer_bonus_score(false))
	if en_ligne:
		_preparer_en_ligne()
	else:
		_compte_a_rebours()


# ------------------------------------------------------------------ FANZZY

static func mods_equipe() -> Dictionary:
	var res := {"tempoWindow": 1.0, "perfectBonus": 1.0, "mashBonus": 1.0, "parryBonus": 1.0,  # sans_traduction
		"holdBonus": 1.0, "breathBonus": 1.0, "refundBonus": 1.0, "backfire": false}  # sans_traduction
	for id in Game.equipe:
		var z := Game.fanzzy_par_id(str(id))
		for k in z.get("mods", {}):
			if not res.has(k):
				continue
			if k == "backfire":
				res[k] = res[k] or bool(z["mods"][k])
			else:
				res[k] *= float(z["mods"][k])
	return res


static func effets_texte(z: Dictionary) -> Array:
	var noms := {
		"tempoWindow": "rythme plus tolérant", "perfectBonus": "points des « parfait »",
		"mashBonus": "points de chant", "parryBonus": "charge du tifo", "holdBonus": "résistance à l'adversaire",
		"breathBonus": "temps pour l'ola", "refundBonus": "combo gardé après une erreur",
	}
	var res: Array = []
	for k in z.get("mods", {}):
		var v: Variant = z["mods"][k]
		if k == "backfire":
			if v:
				res.append(Trad.t("risqué : un raté coûte plus cher"))
		elif noms.has(k):
			var pct := int(round((float(v) - 1.0) * 100.0))
			if pct != 0:
				res.append("%s %s%d %%" % [Trad.t(noms[k]), "+" if pct > 0 else "", pct])
	return res


# ------------------------------------------------------------------ construction

func _construire() -> void:
	_decor = Decor.new()
	_decor.duel = self
	_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # supporters réduits proprement
	add_child(_decor)
	var dom: Dictionary = fiche["dom"]
	var ext: Dictionary = fiche["ext"]
	var nous: Dictionary = dom if camp == "home" else ext
	var eux: Dictionary = ext if camp == "home" else dom
	_decor.c_nous = Duel._vive(nous["c1"], nous["c2"], Ui.BLEU)
	_decor.c_nous2 = nous["c2"]
	_decor.c_eux = Duel._vive(eux["c1"], eux["c2"], Ui.ROUGE)
	if _decor.c_eux.is_equal_approx(_decor.c_nous):
		_decor.c_eux = Ui.ROUGE if not _decor.c_nous.is_equal_approx(Ui.ROUGE) else Ui.JAUNE
	_decor.c_eux2 = eux["c2"]
	_decor.mode = mode
	_decor.texte_tifo = Game.fan_club_nom.to_upper()

	# FANZZY de la tribune, au premier plan
	for i in 3:
		var mar := Marionnette.new()
		mar.texture = Game.texture_fanzzy(str(Game.equipe[i]))
		mar.fanzzy_id = Game.skin_de(str(Game.equipe[i]))
		mar.couleurs = PackedColorArray([_decor.c_nous, Color(_decor.c_nous2)])
		mar.action_fond = [&"chanter", &"agiter_echarpe", &"encourager"][i]
		mar.position = Vector2(560 + i * 300, 1090)
		mar.hauteur = 430.0 if i == 1 else 390.0
		mar.phase = i * 0.9
		add_child(mar)
		_fanzzy.append(mar)

	# piste de rythme
	_piste = Piste.new()
	_piste.duel = self
	_piste.position = Vector2(380, 560)
	_piste.size = Vector2(1160, 110)
	_piste.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_piste)

	# paroles du chant du club, au-dessus de la piste
	_paroles = RichTextLabel.new()
	_paroles.bbcode_enabled = true
	_paroles.scroll_active = false
	_paroles.autowrap_mode = TextServer.AUTOWRAP_OFF
	_paroles.position = Vector2(380, 488)
	_paroles.size = Vector2(1160, 64)
	_paroles.add_theme_font_override("normal_font", Ui.police_titre())
	_paroles.add_theme_font_size_override("normal_font_size", 40)
	_paroles.add_theme_constant_override("outline_size", 10)
	_paroles.add_theme_color_override("font_outline_color", Ui.CONTOUR)
	_paroles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paroles.visible = not _chant_club.is_empty()
	add_child(_paroles)

	# --- jauge en haut
	var hj := Ui.vbox(4)
	hj.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hj.offset_left = -560
	hj.offset_right = 560
	hj.offset_top = 22
	add_child(hj)
	var noms := Ui.hbox(10)
	var n1 := Ui.label(Game.fan_club_nom.to_upper(), 30, Ui.BLANC, true, 8)
	n1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n1.clip_text = true
	n1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	noms.add_child(n1)
	noms.add_child(Ui.label("DUEL D'AMBIANCE", 40, Ui.JAUNE, true, 10))
	var nom_eux: String = Reseau.adversaire.get("nom", eux["nom"]) if en_ligne else FinDuel.nom_adverse(fiche["m"], eux["nom"])
	var n2 := Ui.label(nom_eux.to_upper(), 30, Ui.BLANC, true, 8)
	n2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n2.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	n2.clip_text = true
	# Sans « … », un nom long aligné à droite perdait son début sous le titre.
	n2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	noms.add_child(n2)
	hj.add_child(noms)
	_jauge_barre = Jauge.new()
	(_jauge_barre as Jauge).duel = self
	_jauge_barre.custom_minimum_size = Vector2(1120, 48)
	hj.add_child(_jauge_barre)

	# --- match réel (en haut à droite)
	var mr := Ui.panneau(Ui.NUIT, 22, 5)
	mr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mr.offset_left = -330
	mr.offset_right = -24
	mr.offset_top = 22
	add_child(mr)
	var vmr := Ui.vbox(0)
	mr.add_child(vmr)
	_lbl_minute_reelle = Ui.label("MATCH RÉEL", 18, Ui.GRIS, true)
	_lbl_minute_reelle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vmr.add_child(_lbl_minute_reelle)
	_lbl_score_reel = Ui.label("", 40, Ui.BLANC, true, 6)
	_lbl_score_reel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vmr.add_child(_lbl_score_reel)

	# --- chrono et info (en haut à gauche)
	var ch := Ui.panneau(Ui.NUIT, 22, 5)
	ch.set_anchors_preset(Control.PRESET_TOP_LEFT)
	ch.offset_left = 24
	ch.offset_top = 22
	ch.offset_right = 330
	add_child(ch)
	var vch := Ui.vbox(0)
	ch.add_child(vch)
	_lbl_temps = Ui.label("0'", 44, Ui.JAUNE, true, 8)
	vch.add_child(_lbl_temps)
	_lbl_info = Ui.label("", 16, Ui.BLANC)
	_lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_info.custom_minimum_size = Vector2(270, 0)
	vch.add_child(_lbl_info)

	# --- combo (en bas à gauche)
	var cb := Ui.panneau(Ui.NUIT, 22, 5)
	cb.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	cb.offset_left = 24
	cb.offset_right = 420
	cb.offset_top = -130
	cb.offset_bottom = -24
	add_child(cb)
	var vcb := Ui.vbox(0)
	cb.add_child(vcb)
	_lbl_combo = Ui.label("COMBO x0", 36, Ui.BLANC, true, 8)
	vcb.add_child(_lbl_combo)
	var cri: String = Game.fanzzy_par_id(str(Game.equipe[0])).get("cri", {}).get("label", "Allez allez")
	_lbl_combo_sous = Ui.label(tr("Appuie en rythme · chant « %s »") % (_chant_nom if not _chant_club.is_empty() else tr(cri).capitalize()), 17, Ui.GRIS)
	_lbl_combo_sous.clip_text = true
	vcb.add_child(_lbl_combo_sous)

	# --- boutons d'action (en bas à droite)
	var ba := Ui.hbox(14)
	ba.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	ba.offset_left = -640
	ba.offset_right = -24
	ba.offset_top = -124
	ba.offset_bottom = -24
	ba.alignment = BoxContainer.ALIGNMENT_END
	add_child(ba)
	_btn_chant = Ui.bouton("Chant", Ui.BLEU, 34)
	_btn_chant.custom_minimum_size = Vector2(200, 96)
	_btn_chant.button_down.connect(func(): _chant())
	_btn_chant.focus_mode = Control.FOCUS_NONE
	ba.add_child(_btn_chant)
	var vt := Ui.vbox(4)
	_btn_tifo = Ui.bouton("Tifo", Ui.ROSE, 34)
	_btn_tifo.custom_minimum_size = Vector2(200, 78)
	_btn_tifo.focus_mode = Control.FOCUS_NONE
	_btn_tifo.pressed.connect(_tifo)
	vt.add_child(_btn_tifo)
	_barre_tifo = ProgressBar.new()
	_barre_tifo.show_percentage = false
	_barre_tifo.custom_minimum_size = Vector2(200, 14)
	_barre_tifo.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 7, 3))
	_barre_tifo.add_theme_stylebox_override("fill", Ui.boite(Ui.ROSE, 7, 0))
	vt.add_child(_barre_tifo)
	ba.add_child(vt)
	_btn_ola = Ui.bouton("Ola", Ui.JAUNE, 34)
	Ui.colorer_bouton(_btn_ola, Ui.JAUNE, true)
	_btn_ola.custom_minimum_size = Vector2(200, 96)
	_btn_ola.focus_mode = Control.FOCUS_NONE
	_btn_ola.pressed.connect(_ola_lancer)
	ba.add_child(_btn_ola)

	# --- panneau de l'ola (séquence de flèches)
	_panneau_ola = Ui.panneau(Ui.NUIT, 26, 6)
	_panneau_ola.set_anchors_preset(Control.PRESET_CENTER)
	_panneau_ola.offset_left = -330
	_panneau_ola.offset_right = 330
	_panneau_ola.offset_top = -250
	_panneau_ola.offset_bottom = -60
	_panneau_ola.visible = false
	add_child(_panneau_ola)
	var vo := Ui.vbox(10)
	_panneau_ola.add_child(vo)
	var to := Ui.label("OLA ! Tape les flèches dans l'ordre", 28, Ui.JAUNE, true, 6)
	to.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vo.add_child(to)
	_fleches_ola = Ui.hbox(14)
	_fleches_ola.alignment = BoxContainer.ALIGNMENT_CENTER
	vo.add_child(_fleches_ola)

	# --- bannière de tifo
	_banniere = Banniere.new()
	_banniere.texte = Game.fan_club_nom.to_upper()
	_banniere.sous = Game.fanzzy_par_id(str(Game.equipe[1])).get("cri", {}).get("label", "")
	_banniere.sous = tr(_banniere.sous)
	_banniere.couleur = _decor.c_nous
	_banniere.couleur2 = _decor.c_nous2
	_banniere.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banniere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banniere.visible = false
	add_child(_banniere)
	_maj_score_reel()


## Une couleur de club lisible sur la jauge (ni presque noire, ni presque blanche).
static func _vive(c1: Color, c2: Color, defaut: Color) -> Color:
	for c in [c1, c2]:
		if c.get_luminance() > 0.12 and c.get_luminance() < 0.85:
			return c
	return defaut


func _compte_a_rebours() -> void:
	var l := Ui.label("3", 220, Ui.JAUNE, true, 24)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(l)
	for t in ["3", "2", "1", "ALLEZ !"]:
		l.text = t
		Ui.ajuster_taille(l, 220, get_viewport_rect().size.x - 120)
		l.pivot_offset = l.size / 2.0
		Ui.pop(l, 1.4, 0.3)
		_jouer("tambour")
		await get_tree().create_timer(0.7).timeout
		if not is_inside_tree():
			return  # écran quitté pendant le compte à rebours
	l.queue_free()
	_prochaine_mesure = 0.4
	pret = true


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_decor.queue_redraw()
	_piste.queue_redraw()
	_jauge_barre.queue_redraw()
	if not pret or termine:
		return
	temps += delta
	_lbl_temps.text = "%d'" % mini(90, int(temps * 90.0 / DUREE))

	# notes : une mesure de 4 temps à la fois, sauf pendant l'ola
	while _prochaine_mesure < temps + TRAJET_NOTE and _prochaine_mesure < DUREE - 1.0:
		if not _chant_club.is_empty():
			_preparer_mesure_chant(_prochaine_mesure)
		else:
			var motif: Array = MOTIFS[randi() % MOTIFS.size()] if _prochaine_mesure > 4.0 else [1, 0, 1, 0]
			for i in 4:
				var t := _prochaine_mesure + i * _beat
				if motif[i] == 1 and not _pendant_ola(t):
					_notes.append(t)
		_prochaine_mesure += 4 * _beat
	# notes ratées (passées sans appui)
	while not _notes.is_empty() and _notes[0] < temps - FENETRE_BIEN * mods["tempoWindow"]:
		_noter_faute(_notes.pop_front())
		_rate(false)

	if _chant_club.is_empty():
		# tambour de la tribune sur chaque temps
		var b := int(temps / _beat)
		if b != _dernier_beat:
			_dernier_beat = b
			_jouer("tambour", -12.0)
			for mar in _fanzzy:
				mar.battement(60.0 / _beat)
	else:
		_jouer_chant()

	if en_ligne:
		_tick_en_ligne(delta)
	else:
		_pression_ia(delta)

	# ola
	if temps >= _ola_prete_a and _ola_sequence.is_empty():
		_btn_ola.disabled = false
		_btn_ola.text = "Ola (O)"
	else:
		_btn_ola.disabled = true
		_btn_ola.text = "Ola" if _ola_sequence.is_empty() else "Ola…"
	if not _ola_sequence.is_empty() and temps > _ola_fin:
		_ola_finir(false)

	_barre_tifo.value = charge_tifo
	_btn_tifo.disabled = charge_tifo < 100.0
	_btn_tifo.text = "Tifo (T)" if charge_tifo >= 100.0 else "Tifo"

	if auto:
		_jouer_tout_seul()
	if temps >= DUREE:
		if en_ligne and not Reseau.hote:
			_attendre_fin()
		else:
			_finir()


## Hors ligne : la tribune d'en face (IA) pousse en continu, plus fort quand elle chante.
func _pression_ia(delta: float) -> void:
	var pression := 0.95 + 0.06 * FicheMatch.ambiance_prevue(fiche)
	if temps > _prochain_chant_adverse and _chant_adverse_fin < temps:
		_chant_adverse_fin = temps + 3.5
		_prochain_chant_adverse = temps + randf_range(10.0, 15.0)
		_annonce("Ils lancent un chant ! Réponds plus fort !", Ui.ROUGE)
		_decor.secousse_eux = 1.0
	if temps < _chant_adverse_fin:
		pression *= 3.0
	jauge -= pression * delta * 1.6 / float(mods["holdBonus"])  # sans_traduction
	jauge = clampf(jauge, -100.0, 100.0)


## Mode démo / test (option « --auto ») : la tribune joue toute seule, avec quelques erreurs.
var auto := "--auto" in OS.get_cmdline_user_args() or bool(Game.params.get("auto", false))


func _jouer_tout_seul() -> void:
	if not _notes.is_empty() and temps >= _notes[0] - 0.02:
		if randf() < 0.85:
			_chant()
	if charge_tifo >= 100.0:
		_tifo()
	if temps >= _ola_prete_a and _ola_sequence.is_empty():
		_ola_lancer()
	elif not _ola_sequence.is_empty() and randf() < 0.05:
		_ola_touche(_ola_sequence[_ola_index])


func _pendant_ola(t: float) -> bool:
	return not _ola_sequence.is_empty() and t < _ola_fin + 0.3


func _unhandled_input(ev: InputEvent) -> void:
	if termine or not pret:
		return
	if ev.is_action_pressed("ui_cancel"):
		FinDuel.pause(self, en_ligne)
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		if not _ola_sequence.is_empty():
			for i in FLECHES.size():
				if ev.is_action(FLECHES[i]):
					_ola_touche(i)
					get_viewport().set_input_as_handled()
					return
		match k:
			KEY_SPACE, KEY_J, KEY_F:
				_chant()
			KEY_T:
				_tifo()
			KEY_O:
				_ola_lancer()
			KEY_B:
				_but(true)
			KEY_N:
				_but(false)
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ actions

func _chant() -> void:
	if termine or not pret:
		return
	Ui.pop(_btn_chant, 1.08, 0.12)
	if _notes.is_empty():
		_noter_faute(temps)
		_rate(true)
		return
	var ecart := absf(_notes[0] - temps)
	var tw: float = mods["tempoWindow"]  # sans_traduction
	if ecart > FENETRE_BIEN * tw:
		# trop tôt : on ne mange pas la note, petite pénalité
		if ecart < FENETRE_BIEN * tw * 2.2:
			_noter_faute(_notes[0])
			_rate(true)
		return
	var t_note: float = _notes.pop_front()
	combo += 1
	combo_max = maxi(combo_max, combo)
	var mult := (1.0 + minf(combo, 40) / 20.0) * _bonus_score * float(mods["mashBonus"])
	if not _chant_club.is_empty():
		mult *= ChantClub.BONUS_POINTS
	var gain := 1.0
	if ecart <= FENETRE_PARFAIT * tw:
		parfaits += 1
		gain = 2.0 * float(mods["perfectBonus"])  # sans_traduction
		_piste.eclat(tr("PARFAIT !"), Ui.JAUNE)
		_jouer("clap", 0.0, 1.15)
	else:
		biens += 1
		_piste.eclat(tr("BIEN"), Ui.VERT)
		_jouer("clap", -4.0)
	_pousser(gain * mult * 0.9)
	points += int(gain * mult * 10.0)
	charge_tifo = minf(100.0, charge_tifo + 3.2 * float(mods["parryBonus"]))  # sans_traduction
	_fanzzy[0].sauter(0.9)
	if combo % 10 == 0:
		_signaler("combo")
		_decor.confettis(40)
		_fanzzy[1].sauter(1.0)
		_fanzzy[2].sauter(1.0)
		_fanzzy[1].geste(&"applaudir", 1.6)
		_fanzzy[2].geste(&"applaudir", 1.6)
	_maj_combo()
	if _fins_couplet.has(t_note):
		_fin_de_couplet(int(_fins_couplet[t_note]))


func _rate(appui: bool) -> void:
	rates += 1
	var garde := clampf(float(mods["refundBonus"]) - 1.0, 0.0, 0.6)  # sans_traduction
	combo = int(combo * garde)
	var cout := 1.0 if appui else 1.4
	if mods["backfire"]:
		cout *= 1.5
	_pousser(-cout)
	_piste.eclat(tr("RATÉ"), Ui.ROUGE)
	_fanzzy[0].trembler()
	_maj_combo()


func _maj_combo() -> void:
	_lbl_combo.text = tr("COMBO x%d%s") % [combo, " !" if combo >= 10 else ""]
	if combo > 0 and combo % 5 == 0:
		_lbl_combo.pivot_offset = _lbl_combo.size / 2.0
		Ui.pop(_lbl_combo, 1.2)


func _tifo() -> void:
	if charge_tifo < 100.0 or termine:
		return
	charge_tifo = 0.0
	tifos += 1
	var gain := 14.0 * _bonus_score
	_pousser(gain)
	_signaler("tifo")
	points += int(gain * 25)
	_jouer("foule", 0.0)
	_banniere.deployer()
	_decor.confettis(120)
	for mar in _fanzzy:
		mar.sauter(1.3)
		mar.geste(&"agiter_echarpe", 3.0)
	_annonce(tr("TIFO DÉPLOYÉ ! +%d") % int(gain), Ui.ROSE)


func _ola_lancer() -> void:
	if termine or temps < _ola_prete_a or not _ola_sequence.is_empty():
		return
	_ola_sequence = []
	for i in 4:
		_ola_sequence.append(randi() % 4)
	_ola_index = 0
	_ola_fin = temps + 3.2 * float(mods["breathBonus"])  # sans_traduction
	_notes = _notes.filter(func(t): return t < temps + 0.2 or t > _ola_fin + 0.3)
	for c in _fleches_ola.get_children():
		c.queue_free()
	for d in _ola_sequence:
		var f := Fleche.new()
		f.direction = d
		f.custom_minimum_size = Vector2(96, 96)
		f.mouse_filter = Control.MOUSE_FILTER_STOP
		var dd: int = d
		f.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed:
				_ola_touche(dd))
		_fleches_ola.add_child(f)
	_panneau_ola.visible = true
	Ui.pop(_panneau_ola, 1.08)


func _ola_touche(d: int) -> void:
	if _ola_sequence.is_empty():
		return
	if d == _ola_sequence[_ola_index]:
		var f: Fleche = _fleches_ola.get_child(_ola_index)
		f.validee = true
		f.queue_redraw()
		Ui.pop(f, 1.25)
		_jouer("clap", -6.0, 1.3 + _ola_index * 0.1)
		_ola_index += 1
		if _ola_index >= _ola_sequence.size():
			_ola_finir(true)
	else:
		_ola_finir(false)


func _ola_finir(reussie: bool) -> void:
	_ola_sequence = []
	_panneau_ola.visible = false
	_ola_prete_a = temps + OLA_PERIODE
	if reussie:
		olas += 1
		var gain := 12.0 * _bonus_score
		_pousser(gain)
		_signaler("ola")
		points += int(gain * 25)
		_decor.lancer_ola()
		_jouer("foule", -3.0)
		for i in _fanzzy.size():
			_fanzzy[i].sauter(1.2, i * 0.12)
			_fanzzy[i].geste(&"lever_bras", 1.4, i * 0.12)
		_annonce(tr("OLA RÉUSSIE ! +%d") % int(gain), Ui.JAUNE)
	else:
		_signaler("ola_ratee")
		_annonce("Ola ratée… la tribune s'est emmêlée", Ui.GRIS)
		for mar in _fanzzy:
			mar.trembler()


func _but(pour_nous: bool) -> void:
	if pour_nous:
		_pousser(15.0)
		_annonce("BUT !!! La tribune explose", Ui.VERT)
		_decor.confettis(200)
		_jouer("foule", 3.0)
		for mar in _fanzzy:
			mar.sauter(1.6)
			mar.geste(&"celebrer", 2.5)
	else:
		_pousser(-10.0)
		_annonce("But adverse… relance la tribune !", Ui.ROUGE)
		_decor.secousse_eux = 1.0
		for mar in _fanzzy:
			mar.geste(&"depit", 2.2)


func _annonce(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 46, couleur, true, 12)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -700
	l.offset_right = 700
	l.offset_top = 160
	l.offset_bottom = 230
	l.pivot_offset = Vector2(700, 35)
	add_child(l)
	Ui.pop(l, 1.3, 0.3)
	var t := l.create_tween()
	t.tween_interval(1.4)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_callback(l.queue_free)


# ------------------------------------------------------------------ vrai score

func _buts(m: Dictionary) -> Vector2i:
	var sc: Variant = m.get("score", {}).get("current")
	if not sc is Dictionary:
		return Vector2i(-1, -1)
	var h := int(sc.get("home", 0))
	var a := int(sc.get("away", 0))
	return Vector2i(h, a) if camp == "home" else Vector2i(a, h)


func _calculer_bonus_score(debut: bool) -> void:
	var m := Donnees.match_par_id(fiche["id"])
	if m.is_empty():
		return
	fiche["m"] = m
	var b := _buts(m)
	if b.x >= 0:
		if not debut and _score_vu.x >= 0 and pret and not termine:
			if b.x > _score_vu.x:
				_but(true)
			if b.y > _score_vu.y:
				_but(false)
		_score_vu = b
		_bonus_score = clampf(1.0 + 0.08 * (b.x - b.y), 0.76, 1.24)
		var pct := int(round((_bonus_score - 1.0) * 100))
		if pct > 0:
			_lbl_info.text = tr("Ton équipe mène %d–%d : +%d %% d'ambiance") % [b.x, b.y, pct]
		elif pct < 0:
			_lbl_info.text = tr("Ton équipe est menée %d–%d : %d %% d'ambiance") % [b.x, b.y, pct]
		else:
			_lbl_info.text = tr("Égalité %d–%d : pas de bonus") % [b.x, b.y]
	else:
		_bonus_score = 1.0
		_lbl_info.text = "Match pas encore commencé : pas de bonus de score"
	_maj_score_reel()


func _maj_score_reel() -> void:
	var m: Dictionary = fiche["m"]
	_lbl_minute_reelle.text = tr("MATCH RÉEL · ") + FicheMatch.statut_court(fiche)
	var sc := Donnees.score_texte(m) if m.get("score", {}).get("current") is Dictionary else "–"
	_lbl_score_reel.text = "%s %s %s" % [fiche["dom"]["sigle"], sc, fiche["ext"]["sigle"]]


# ------------------------------------------------------------------ en ligne

func _pousser(d: float) -> void:
	if en_ligne:
		if termine or _attente_fin:
			return
		var m := _jp.local(d)
		jauge = _jp.jauge
		if not m.is_empty():
			Reseau.envoyer(m)
	else:
		jauge = clampf(jauge + d, -100.0, 100.0)


## Montre chez l'adversaire ce que ta tribune vient de faire.
func _signaler(e: String) -> void:
	if en_ligne and not termine:
		Reseau.envoyer(Protocole.msg("evt", {"e": e}))


func _preparer_en_ligne() -> void:
	_jp = Protocole.JaugePartagee.new(Reseau.hote)
	Reseau.message.connect(_sur_message)
	Reseau.adversaire_parti.connect(_sur_adversaire_parti)
	_lbl_info.text = tr("En attente de %s…") % Reseau.adversaire.get("nom", tr("l'adversaire"))
	_moi_pret = true
	Reseau.envoyer(Protocole.msg("pret"))
	_verifier_depart()


func _verifier_depart() -> void:
	# l'hôte lance quand les deux écrans sont prêts ; l'invité attend « depart »
	if Reseau.hote and _moi_pret and _adv_pret and not _depart_envoye:
		_depart_envoye = true
		Reseau.envoyer(Protocole.msg("depart"))
		_lbl_info.text = tr("Duel contre %s : chante plus fort qu'eux !") % Reseau.adversaire.get("nom", tr("un vrai joueur"))
		_calculer_bonus_score(true)
		_compte_a_rebours()


func _sur_message(m: Dictionary) -> void:
	match m["t"]:
		"pret":
			_adv_pret = true
			if not Reseau.hote:
				Reseau.envoyer(Protocole.msg("pret"))  # l'hôte est arrivé après : on le redit
			_verifier_depart()
		"depart":
			if not Reseau.hote and not _depart_envoye:
				_depart_envoye = true
				_lbl_info.text = tr("Duel contre %s : chante plus fort qu'eux !") % Reseau.adversaire.get("nom", tr("un vrai joueur"))
				_calculer_bonus_score(true)
				_compte_a_rebours()
		"pousse":
			if Reseau.hote and not termine:
				_jp.distant(m)
				jauge = _jp.jauge
		"etat":
			if not Reseau.hote and not termine:
				_jp.recaler(m)
				jauge = _jp.jauge
		"fin":
			if not Reseau.hote:
				jauge = _jp.finale(m)
				_attente_fin = false
				_finir()
		"evt":
			_effet_adverse(str(m["e"]))


func _effet_adverse(e: String) -> void:
	if termine:
		return
	var nom: String = Reseau.adversaire.get("nom", "En face")
	match e:
		"tifo":
			_annonce(tr("%s déploie son tifo !") % nom, Ui.ROUGE)
			_decor.secousse_eux = 1.0
		"ola":
			_annonce(tr("%s réussit une ola !") % nom, Ui.ROUGE)
			_decor.secousse_eux = 1.0
		"combo":
			_decor.secousse_eux = 0.6
		"ola_ratee":
			_annonce("En face, l'ola s'emmêle !", Ui.VERT)


## Toutes les 0,1 s, l'hôte envoie la jauge (et le dernier geste reçu) à l'invité.
func _tick_en_ligne(delta: float) -> void:
	if not Reseau.hote:
		return
	_t_etat -= delta
	if _t_etat <= 0.0:
		_t_etat = 0.1
		Reseau.envoyer_vite(_jp.etat(temps))


## Invité : son temps est écoulé, il attend la jauge finale de l'hôte (3 s au plus).
func _attendre_fin() -> void:
	if _attente_fin or termine:
		return
	_attente_fin = true
	_lbl_info.text = "Coup de sifflet… on compte les voix"
	await get_tree().create_timer(3.0).timeout
	if not termine:
		_finir()


func _sur_adversaire_parti() -> void:
	if termine:
		return
	_annonce("L'adversaire a quitté le duel", Ui.JAUNE)
	_forfait = pret  # parti avant le coup d'envoi : pas de victoire
	if not pret:
		Game.aller(Game.SCENE_SALON, Game.params)
		return
	_finir()


# ------------------------------------------------------------------ fin

func _finir() -> void:
	if termine:
		return
	termine = true
	_notes.clear()
	_panneau_ola.visible = false
	if en_ligne and Reseau.hote and not _forfait:
		Reseau.envoyer(Protocole.msg("fin", {"j": _jp.jauge}))
	var gagne := jauge > 0.0 or _forfait
	var b := _buts(fiche["m"])
	var equipe_gagne := b.x >= 0 and b.x > b.y and str(fiche["m"].get("status", "")) in ["LIVE", "HALFTIME", "FINISHED"]  # sans_traduction
	var gain_mode: float = Game.MODES_SUIVI.get(mode, {}).get("gain", 1.0)
	var jetons := int(round((10.0 + points / 60.0 + (15.0 if gagne else 0.0)) * gain_mode * (1.3 if equipe_gagne else 1.0)))
	var part := Game.noter_duel_match(str(fiche.get("id", fiche["m"].get("id", ""))))
	jetons = int(round(jetons * part))  # même match rejoué : 100 %, 50 %, 25 %, puis rien
	var mult_depl := Game.bonus_deplacement(str(fiche.get("id", fiche["m"].get("id", ""))))
	var bonus_depl := int(round(jetons * (mult_depl - 1.0)))
	var xp := 40 + points / 40 + (40 if gagne else 0)
	Game.duels_joues += 1
	if gagne:
		Game.duels_gagnes += 1
	Game.noter_duel_club()  # l'après-match fait tourner la buvette
	var pop := Game.noter_duel_favori(fiche["m"], camp, gagne, mode)
	Game.gagner_jetons(jetons + bonus_depl)  # + ferveur du déplacement fait aujourd'hui pour ce match
	Game.ajouter_xp(xp)
	var xp_pass := Game.xp_pass_duel(gagne, clampf(points / 2400.0, 0.0, 1.0), part)
	var ev := Game.recompense_evenement(fiche["m"], jetons)
	var tour := {} if en_ligne else Game.noter_duel_tournoi(fiche["m"], gagne, mode)
	# Ligue des tribunes : pas sur un forfait (l'adversaire parti n'enverra pas son résultat).
	var lig := {} if _forfait else Game.noter_duel_ligue(fiche["m"], 1 if gagne else -1)
	if gagne:
		_decor.confettis(300)
		for mar in _fanzzy:
			mar.sauter(1.5)
			mar.geste(&"celebrer", 30.0)
		_jouer("foule", 2.0)
	else:
		for mar in _fanzzy:
			mar.geste(&"depit", 30.0)

	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.65, 0.4)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -460
	pan.offset_right = 460
	var demi_h := 330 + 24 * maxi(0, FinDuel.lignes_evenement(ev).size() + (1 if pop > 0 else 0) + FinDuel.ligne_tournoi(tour).size() + FinDuel.ligne_ligue(lig).size() + FinDuel.ligne_deplacement(mult_depl, bonus_depl).size() - 1)
	pan.offset_top = -demi_h
	pan.offset_bottom = demi_h
	add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var titre_fin := "VICTOIRE D'AMBIANCE !" if gagne else "LA TRIBUNE D'EN FACE A GAGNÉ…"
	if _forfait:
		titre_fin = "VICTOIRE : L'ADVERSAIRE EST PARTI"
	elif en_ligne and not gagne:
		titre_fin = tr("%s A GAGNÉ…") % str(Reseau.adversaire.get("nom", tr("L'ADVERSAIRE"))).to_upper()
	var t := Ui.label(titre_fin, 50 if gagne else 38, Ui.JAUNE if gagne else Ui.ROSE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var lignes := [
		["Points d'ambiance", str(points)],
		["Parfaits / Biens / Ratés", "%d / %d / %d" % [parfaits, biens, rates]],
		["Meilleur combo", "x%d" % combo_max],
		["Tifos / Olas", "%d / %d" % [tifos, olas]],
		["Bonus « ton équipe gagne vraiment »", "x1,3" if equipe_gagne else "non"],
		[Game.libelle_rejeu(part), "+%d" % jetons],
		["XP du fan club", "+%d" % xp],
		["XP du PASS", "+%d" % xp_pass],
	] + FinDuel.ligne_deplacement(mult_depl, bonus_depl) + FinDuel.ligne_popularite({"popularite": pop, "equipe": (fiche["dom"] if camp == "home" else fiche["ext"])["nom"]}) + FinDuel.lignes_evenement(ev) + FinDuel.ligne_tournoi(tour) + FinDuel.ligne_ligue(lig)
	for l in lignes:
		var h := Ui.hbox(10)
		var a := Ui.label(l[0], 24, Ui.BLANC)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Ui.label(l[1], 26, Ui.JAUNE, true))
		v.add_child(h)
	var hb := Ui.hbox(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var retour := Ui.bouton("Retour à la carte", Ui.BLEU, 30)
	retour.custom_minimum_size = Vector2(380, 90)
	var p: Dictionary = Game.params
	retour.pressed.connect(func():
		if en_ligne:
			Reseau.quitter()
		Game.aller(Game.SCENE_CARTE, {"niveau": p.get("niveau", "monde"), "continent": p.get("continent", ""), "pays": p.get("pays", "")}))
	hb.add_child(retour)
	var rejouer := Ui.bouton("Revanche" if en_ligne else "Rejouer", Ui.VERT, 30)
	Ui.colorer_bouton(rejouer, Ui.VERT, true)
	rejouer.custom_minimum_size = Vector2(260, 90)
	if en_ligne:
		# retour au salon, toujours connecté : l'hôte relance quand les deux sont prêts
		rejouer.disabled = not Reseau.connecte()
		rejouer.pressed.connect(func(): Game.aller(Game.SCENE_SALON, {"match_id": p.get("match_id", ""), "camp": p.get("camp", "home"), "mode": p.get("mode", "stade")}))
	else:
		rejouer.pressed.connect(func(): Game.aller(Game.SCENE_DUEL, p))
	hb.add_child(rejouer)
	v.add_child(hb)
	if "--quitter" in OS.get_cmdline_user_args():
		# test automatique : on écrit le résultat puis on ferme
		print("RESULTAT duel en_ligne=%s hote=%s jauge=%.2f gagne=%s forfait=%s" % [en_ligne, Reseau.hote if en_ligne else false, jauge, gagne, _forfait])  # sans_traduction
		get_tree().create_timer(1.5).timeout.connect(func(): get_tree().quit())
	pan.pivot_offset = Vector2(460, demi_h)
	pan.scale = Vector2.ONE * 0.6
	pan.create_tween().tween_property(pan, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ sons (générés, aucun fichier)

# ------------------------------------------------------------------ chant du club

const SonsScript := preload("res://scripts/audio/sons.gd")


func _preparer_chant() -> void:
	# Game.params["chant"] : un chant à essayer (tests, démo) à la place de celui du club.
	var c: Dictionary = Game.params.get("chant", Game.chant_club())
	if c.is_empty():
		return
	_chant_club = ChantClub.programme(c, Game.fan_club_nom)
	_chant_nom = tr(String(c.get("nom", "")))
	_beat = 60.0 / ChantClub.bpm(c)
	_sons_chant = SonsScript.new()
	_sons_chant.name = "SonsChant"  # sans_traduction
	add_child(_sons_chant)


## Prépare la mesure suivante du chant, qui commence à `t0` : ses notes, ses
## frappes d'accompagnement et sa ligne de paroles.
func _preparer_mesure_chant(t0: float) -> void:
	var n := _chant_club.size()
	var i := _mesure_chant % n
	var cycle := _mesure_chant / n
	var m: Dictionary = _chant_club[i]
	var pas := _beat * ChantClub.TEMPS / ChantClub.PAS
	var appuis_t: Array = []
	for p in m["appuis"]:
		var t: float = t0 + int(p) * pas
		appuis_t.append(t)
		if not _pendant_ola(t):
			_notes.append(t)
	if i == n - 1 and not appuis_t.is_empty():
		_fins_couplet[appuis_t[-1]] = cycle
	for f in m["frappes"]:
		_frappes_chant.append({"t": t0 + int(f["pas"]) * pas, "voix": f["voix"], "force": f["force"]})
	_frappes_chant.sort_custom(func(a, b): return a["t"] < b["t"])
	_lignes.append({"t0": t0, "t1": t0 + ChantClub.TEMPS * _beat, "i": i, "cycle": cycle, "appuis": appuis_t})
	_mesure_chant += 1


## Joue l'accompagnement dû, fait battre la tribune et avance le karaoké.
func _jouer_chant() -> void:
	while not _frappes_chant.is_empty() and _frappes_chant[0]["t"] <= temps:
		var f: Dictionary = _frappes_chant.pop_front()
		if temps - float(f["t"]) > 0.1:
			continue  # trop en retard (image lente) : on se tait
		var groupe := BanqueSons.son_de_voix(String(f["voix"]))
		if groupe != "":
			_sons_chant.jouer(groupe, {"volume_db": linear_to_db(maxf(float(f["force"]), 0.05)) - 4.0})
		if f["voix"] == "T" and float(f["force"]) >= 0.9:
			for mar in _fanzzy:
				mar.battement(60.0 / _beat)
	while _lignes.size() > 1 and _lignes[0]["t1"] < temps:
		_lignes.pop_front()
	if _lignes.is_empty() or _lignes[0]["t0"] > temps:
		_paroles.text = ""
		return
	var l: Dictionary = _lignes[0]
	var mots: Array = _chant_club[int(l["i"])]["mots"]
	var en_cours := -1
	for k in l["appuis"].size():
		if float(l["appuis"][k]) <= temps + 0.05:
			en_cours = k
	var parts: Array = []
	for k in mots.size():
		if String(mots[k]) == "":
			continue
		var c := "#ffd23f" if k == en_cours else ("#ffffff" if k < en_cours else "#b9b5e0")
		parts.append(tr("[color=%s]%s[/color]") % [c, mots[k]])  # sans_traduction
	_paroles.text = tr("[center]%s[/center]") % " ".join(parts)  # sans_traduction


## Une erreur (note manquée ou appui à côté) vers l'instant `t` : le couplet
## en cours n'est plus « sans faute ».
func _noter_faute(t: float) -> void:
	if _chant_club.is_empty():
		return
	for l in _lignes:
		if t >= float(l["t0"]) - 0.2 and t < float(l["t1"]):
			_couplets_rates[int(l["cycle"])] = true
			return


func _fin_de_couplet(cycle: int) -> void:
	if _couplets_rates.has(cycle):
		return
	couplets_parfaits += 1
	charge_tifo = minf(100.0, charge_tifo + ChantClub.BONUS_COUPLET_TIFO * float(mods["parryBonus"]))
	points += ChantClub.BONUS_COUPLET_POINTS
	_pousser(2.0)
	_decor.confettis(30)
	_annonce(tr("COUPLET SANS FAUTE ! « %s »") % _chant_nom, Ui.JAUNE)


func _preparer_sons() -> void:
	_sons["tambour"] = _son(func(t): return sin(TAU * (55.0 + 90.0 * exp(-t * 30.0)) * t) * exp(-t * 9.0), 0.35)
	_sons["clap"] = _son(func(t): return randf_range(-1, 1) * exp(-t * 28.0) * 0.8, 0.2)
	_sons["foule"] = _son(func(t): return randf_range(-1, 1) * 0.35 * sin(PI * t / 1.6) * (0.6 + 0.4 * sin(TAU * 3.0 * t)), 1.6)
	for i in 6:
		var lecteur := AudioStreamPlayer.new()
		lecteur.name = "Son%d" % i  # sans_traduction
		add_child(lecteur)


func _son(f: Callable, duree: float) -> AudioStreamWAV:
	var freq := 22050
	var n := int(duree * freq)
	var data := PackedByteArray()
	data.resize(n * 2)
	var precedent := 0.0
	for i in n:
		var v: float = f.call(float(i) / freq)
		precedent = lerpf(precedent, v, 0.6)  # petit filtre pour adoucir le bruit
		data.encode_s16(i * 2, int(clampf(precedent, -1.0, 1.0) * 26000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = freq
	s.data = data
	return s


func _jouer(nom: String, volume := 0.0, hauteur := 1.0) -> void:
	if not _sons.has(nom):
		return
	for i in 6:
		var l := get_node_or_null("Son%d" % i) as AudioStreamPlayer  # sans_traduction
		if l and not l.playing:
			l.stream = _sons[nom]
			l.volume_db = volume
			l.pitch_scale = hauteur
			l.play()
			return


# ================================================================== éléments dessinés

## Un FANZZY de notre tribune, au premier plan : FanzzyAnime (expressions,
## bras, squelette) plus le « jus » (élastique sur le temps, bonds, impacts).
## Il chante en fond et réagit aux temps forts du duel.
class Marionnette extends Node2D:
	var texture: Texture2D           # image de secours si le FANZZY n'a pas d'expressions
	var fanzzy_id := ""
	var couleurs := PackedColorArray([Color("1e6bff"), Color.WHITE])
	var hauteur := 400.0
	var phase := 0.0
	var action_fond := &"chanter"   # geste en boucle quand il ne se passe rien
	var corps: FanzzyAnime

	func _ready() -> void:
		corps = FanzzyAnime.creer(fanzzy_id) if fanzzy_id != "" else FanzzyAnime.new()
		if corps.texture == null and texture:
			corps.texture = texture
		if corps.texture == null:
			return
		corps.couleurs_echarpe = couleurs
		corps.couleur_trainee = couleurs[0]
		corps.decalage = phase * 0.07
		add_child(corps)
		corps.scale = Vector2.ONE * hauteur / maxf(corps._rect.size.y, 1.0)
		corps.jouer(action_fond)
		corps.action_terminee.connect(func(_a: StringName) -> void:
			if corps.action == &"repos":
				corps.jouer(action_fond))

	## Sur chaque temps du tambour : petit coup d'élastique, tempo partagé.
	func battement(bpm := 0.0) -> void:
		if corps == null:
			return
		if bpm > 0.0:
			corps.bpm = bpm
		corps.pop(0.35)

	func sauter(force := 1.0, delai := 0.0) -> void:
		if corps:
			corps.rebondir(force, delai)

	## Raté : il encaisse (éclair rouge, recul) et râle un instant.
	func trembler() -> void:
		if corps:
			corps.impact(Vector2.INF, 0.6, Color("ff7b7b"))
			corps.jouer(&"huer", 1.0)

	## Un geste pour un temps (célébrer, dépit, lever les bras...), puis retour au chant.
	func geste(action: StringName, duree := -1.0, delai := 0.0) -> void:
		if corps:
			corps.jouer(action, duree, delai)


## Le décor : ciel, tribune adverse, terrain (ou écran), notre tribune, confettis.
class Decor extends Control:
	## Le duel, ou tout écran qui expose `jauge` (-100…100) et `fiche` (soir de match).
	var duel  # Duel ou SoireeEcran (pas de type : les deux conviennent)
	var mode := "stade"
	var c_nous := Ui.BLEU
	var c_nous2 := Ui.BLANC
	var c_eux := Ui.ROUGE
	var c_eux2 := Ui.BLANC
	var texte_tifo := ""
	var secousse_eux := 0.0
	var _t := 0.0
	var _confettis: Array = []
	var _ola_t := -10.0
	var _graine := 12345

	func confettis(n: int) -> void:
		var cols := [Ui.JAUNE, Ui.ROSE, Ui.BLEU, Ui.VERT, Ui.VIOLET, c_nous]
		for i in n:
			_confettis.append({"p": Vector2(randf() * 1920.0, randf_range(-200, 0)), "v": Vector2(randf_range(-60, 60), randf_range(150, 380)),
				"c": cols[randi() % cols.size()], "r": randf() * TAU, "vr": randf_range(-8, 8)})

	func lancer_ola() -> void:
		_ola_t = _t

	func _process(delta: float) -> void:
		_t += delta
		secousse_eux = maxf(0.0, secousse_eux - delta * 0.4)
		for c in _confettis:
			c["p"] += c["v"] * delta
			c["r"] += c["vr"] * delta
		_confettis = _confettis.filter(func(c): return c["p"].y < 1150)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var ferveur_nous := 0.35 + 0.65 * clampf((duel.jauge + 100.0) / 200.0, 0.0, 1.0)
		var ferveur_eux := 0.35 + 0.65 * clampf((100.0 - duel.jauge) / 200.0, 0.0, 1.0) + secousse_eux * 0.5
		match mode:
			"stade":
				_ciel(Color("#3b1c8f"), Color("#e0507f"))
				# toit
				draw_rect(Rect2(0, 120, w, 16), Color("#ff6f9c"))
				for x in range(60, int(w), 240):
					draw_rect(Rect2(x, 0, 10, 130), Color(1, 1, 1, 0.4))
				_foule(Rect2(0, 150, w, 270), c_eux, c_eux2, ferveur_eux, 14.0, false)
				_terrain(Rect2(0, 420, w, 230))
			"ecran":
				_ciel(Color("#0d0a2e"), Color("#3a2a7a"))
				_ecran_geant(Rect2(w / 2 - 420, 110, 840, 330))
				_foule(Rect2(0, 300, w / 2 - 440, 200), c_eux, c_eux2, ferveur_eux, 13.0, false)
				_foule(Rect2(w / 2 + 440, 300, w / 2 - 440, 200), c_eux, c_eux2, ferveur_eux, 13.0, false)
				draw_rect(Rect2(0, 470, w, 190), Color("#2a2550"))
			"pub":
				_ciel(Color("#5a3416"), Color("#8a5a2b"))
				for x in range(0, int(w), 90):
					draw_rect(Rect2(x, 0, 6, 520), Color(0, 0, 0, 0.15))
				_ecran_geant(Rect2(w / 2 - 260, 90, 520, 260))
				draw_rect(Rect2(0, 430, w, 60), Color("#3d2210"))  # comptoir
				_foule(Rect2(w * 0.55, 260, w * 0.45, 200), c_eux, c_eux2, ferveur_eux, 16.0, false)
				draw_rect(Rect2(0, 480, w, 180), Color("#6b4423"))
			"maison":
				_ciel(Color("#f6d7a7"), Color("#f0b98a"))
				draw_rect(Rect2(0, 420, w, 240), Color("#c98d5a"))
				_ecran_geant(Rect2(w / 2 - 300, 120, 600, 300))
				_foule(Rect2(w * 0.72, 300, w * 0.28, 140), c_eux, c_eux2, ferveur_eux, 18.0, false)
		# notre tribune
		_foule(Rect2(0, 650, w, 430), c_nous, c_nous2, ferveur_nous, 18.0, true)
		# confettis
		for c in _confettis:
			draw_set_transform(c["p"], c["r"], Vector2.ONE)
			draw_rect(Rect2(-6, -3, 12, 6), c["c"])
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

	func _ciel(haut: Color, bas: Color) -> void:
		var pts := PackedVector2Array([Vector2(0, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(0, size.y)])
		draw_polygon(pts, PackedColorArray([haut, haut, bas, bas]))

	func _terrain(r: Rect2, panneaux := true) -> void:
		draw_rect(r, Color("#3fb950"))
		for i in 6:
			if i % 2 == 0:
				draw_rect(Rect2(r.position.x + i * r.size.x / 6.0, r.position.y, r.size.x / 6.0, r.size.y), Color("#46c357"))
		var lig := Color(1, 1, 1, 0.8)
		draw_line(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), lig, 4)
		draw_arc(r.get_center(), 70, 0, TAU, 48, lig, 4, true)
		draw_rect(Rect2(r.position.x + 40, r.position.y + 30, 160, r.size.y - 60), lig, false, 4)
		draw_rect(Rect2(r.end.x - 200, r.position.y + 30, 160, r.size.y - 60), lig, false, 4)
		if not panneaux:
			return
		# panneaux publicitaires fictifs
		var pubs := ["FANAROUNDTHEWORLD", "PASS SAISON", "ULTRAS", "GO GO GO", "FANZZY"]
		var f := Ui.police_titre()
		var x := 0.0
		var i := 0
		while x < size.x:
			var col: Color = [Ui.ROSE, Ui.JAUNE, Ui.BLEU, Ui.VERT, Ui.VIOLET][i % 5]
			draw_rect(Rect2(x, r.position.y - 26, 300, 26), col)
			draw_string(f, Vector2(x + 14, r.position.y - 6), tr(pubs[i % pubs.size()]), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.CONTOUR if col == Ui.JAUNE else Ui.BLANC)
			x += 300
			i += 1

	func _ecran_geant(r: Rect2) -> void:
		draw_rect(r.grow(14), Ui.CONTOUR)
		draw_rect(r, Color("#123a1c"))
		_terrain(Rect2(r.position + Vector2(0, 40), Vector2(r.size.x, r.size.y - 40)), false)
		var f := Ui.police_titre()
		var m: Dictionary = duel.fiche["m"]
		var txt := "%s %s %s · %s" % [duel.fiche["dom"]["sigle"], Donnees.score_texte(m), duel.fiche["ext"]["sigle"], FicheMatch.statut_court(duel.fiche)]
		draw_rect(Rect2(r.position, Vector2(r.size.x, 40)), Ui.NUIT)
		draw_string(f, r.position + Vector2(16, 30), txt, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, 26, Ui.BLANC)

	func _foule(r: Rect2, c1: Color, c2: Color, ferveur: float, rayon: float, devant: bool) -> void:
		## Des rangées de supporters (têtes + corps) qui sautent selon la ferveur.
		var rng := RandomNumberGenerator.new()
		rng.seed = _graine + int(r.position.y)
		var peaux := [Color("#f2c9a0"), Color("#d9a273"), Color("#a86b3c"), Color("#6b4226"), Color("#ffe0bd")]
		var sprites := FouleSprites.disponible()
		var pas := rayon * (2.6 if sprites else 2.3)
		var rangs := int(r.size.y / (rayon * 2.6))
		for j in rangs:
			var y := r.position.y + j * rayon * 2.6 + rayon * 1.2
			var echelle := 1.0 + (float(j) / maxf(1, rangs - 1)) * (0.5 if devant else 0.2)
			var x := r.position.x + (pas / 2.0 if j % 2 == 1 else 0.0)
			while x < r.end.x:
				var ph := rng.randf() * TAU
				if sprites:
					# supporters Quaternius : geste d'ambiance, ola quand la vague passe
					var corps2: Color = c1 if rng.randf() < 0.75 else c2
					var peau2: Color = FouleSprites.PEAUX[rng.randi() % FouleSprites.PEAUX.size()]
					var variante := rng.randi() % 3
					var rr2 := rayon * echelle
					var ga := FouleSprites.geste_ambiance(ferveur, ph / TAU, _t)
					if devant and _t - _ola_t < 3.0:
						var dans := _t - _ola_t - x / (size.x * 0.8) + 0.3
						if dans >= 0.0 and dans < FouleSprites.duree(&"ola"):
							ga = [&"ola", dans]
					var autre: Color = c2 if corps2 == c1 else c1
					FouleSprites.dessiner(self, Vector2(x, y + rr2 * 4.2), rr2 * 5.2, ga[0], ga[1], corps2, autre, peau2, variante)
					x += pas * echelle
					continue
				var actif := rng.randf() < ferveur
				var saut := 0.0
				if actif:
					saut = maxf(0.0, sin(_t * 9.0 + ph)) * rayon * 0.9 * ferveur
				if devant and _t - _ola_t < 2.0:
					var front := (_t - _ola_t) * size.x * 0.8
					saut += maxf(0.0, 1.0 - absf(x - front) / 180.0) * rayon * 3.0
				var corps: Color = c1 if rng.randf() < 0.75 else c2
				var p := Vector2(x, y - saut)
				var rr := rayon * echelle
				draw_rect(Rect2(p + Vector2(-rr * 0.9, rr * 0.4), Vector2(rr * 1.8, rr * 1.8)), corps.darkened(0.1 if j % 2 == 0 else 0.0))
				draw_circle(p, rr * 0.75, peaux[rng.randi() % peaux.size()])
				if actif and saut > rayon * 0.3:
					# bras levés
					draw_line(p + Vector2(-rr * 0.8, rr * 0.6), p + Vector2(-rr * 1.3, -rr * 0.6), corps, rr * 0.4)
					draw_line(p + Vector2(rr * 0.8, rr * 0.6), p + Vector2(rr * 1.3, -rr * 0.6), corps, rr * 0.4)
				x += pas * echelle
			if sprites:
				# la marche de tribune devant ce rang cache le bas des jambes
				var rr3 := rayon * echelle
				var marche := Rect2(r.position.x, y + rr3 * 1.9, r.size.x, rr3 * 2.8)
				draw_rect(marche, Color("#2a2357", 0.92))
				draw_rect(Rect2(marche.position, Vector2(marche.size.x, rr3 * 0.35)), Color("#8b7dff", 0.9))


## La piste de rythme : les notes glissent vers le cercle de gauche.
class Piste extends Control:
	var duel: Duel
	var _eclat_txt := ""
	var _eclat_col := Ui.BLANC
	var _eclat_t := 0.0

	func eclat(t: String, c: Color) -> void:
		_eclat_txt = t
		_eclat_col = c
		_eclat_t = 0.6

	func _process(delta: float) -> void:
		_eclat_t = maxf(0.0, _eclat_t - delta)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Ui.boite(Color(0.08, 0.06, 0.2, 0.75), 50, 5), r)
		var cible := Vector2(90, size.y / 2.0)
		var tw: float = duel.mods.get("tempoWindow", 1.0)  # sans_traduction
		draw_circle(cible, 46, Ui.CONTOUR)
		draw_circle(cible, 40, Ui.BLANC.darkened(0.1) if _eclat_t <= 0 else _eclat_col)
		draw_circle(cible, 40 * clampf(tw * 0.55, 0.3, 0.95), Color(0, 0, 0, 0.15))
		var vitesse := (size.x - cible.x - 40) / Duel.TRAJET_NOTE
		for t in duel._notes:
			var x: float = cible.x + (t - duel.temps) * vitesse
			if x > size.x - 20:
				continue
			draw_circle(Vector2(x, cible.y), 34, Ui.CONTOUR)
			draw_circle(Vector2(x, cible.y), 28, Ui.BLEU)
			draw_circle(Vector2(x - 8, cible.y - 8), 8, Color(1, 1, 1, 0.6))
		if _eclat_t > 0:
			var f := Ui.police_titre()
			var a := _eclat_t / 0.6
			draw_string_outline(f, cible + Vector2(70, 18 - (1.0 - a) * 20), _eclat_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, 10, Color(Ui.CONTOUR, a))
			draw_string(f, cible + Vector2(70, 18 - (1.0 - a) * 20), _eclat_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(_eclat_col, a))


## Jauge d'ambiance : bleu (toi) contre rouge (eux).
class Jauge extends Control:
	var duel: Duel
	var _affichee := 0.0

	func _draw() -> void:
		_affichee = lerpf(_affichee, duel.jauge, 0.15)
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Ui.boite(Ui.CONTOUR, 24, 0), r)
		var inner := r.grow(-6)
		var part := clampf((_affichee + 100.0) / 200.0, 0.02, 0.98)
		var g := Rect2(inner.position, Vector2(inner.size.x * part, inner.size.y))
		var d := Rect2(inner.position + Vector2(inner.size.x * part, 0), Vector2(inner.size.x * (1.0 - part), inner.size.y))
		var sg := Ui.boite(duel._decor.c_nous if duel._decor else Ui.BLEU, 18, 0)
		sg.corner_radius_top_right = 0
		sg.corner_radius_bottom_right = 0
		var sd := Ui.boite(duel._decor.c_eux if duel._decor else Ui.ROUGE, 18, 0)
		sd.corner_radius_top_left = 0
		sd.corner_radius_bottom_left = 0
		draw_style_box(sg, g)
		draw_style_box(sd, d)
		draw_rect(Rect2(inner.position + Vector2(0, 4), Vector2(inner.size.x, 8)), Color(1, 1, 1, 0.25))
		var x := inner.position.x + inner.size.x * part
		draw_line(Vector2(x, 0), Vector2(x, size.y), Ui.BLANC, 6)
		draw_line(Vector2(size.x / 2.0, size.y - 10), Vector2(size.x / 2.0, size.y), Ui.BLANC, 3)


## Bannière géante du tifo qui monte sur l'écran.
class Banniere extends Control:
	var texte := ""
	var sous := ""
	var couleur := Ui.BLEU
	var couleur2 := Ui.JAUNE
	var _y := 1.0

	func deployer() -> void:
		visible = true
		_y = 1.0
		var tw := create_tween()
		tw.tween_property(self, "_y", 0.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.6)
		tw.tween_property(self, "_y", 1.2, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func(): visible = false)

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(80, 180 + _y * 900), Vector2(size.x - 160, 560))
		draw_set_transform(Vector2.ZERO, -0.03, Vector2.ONE)
		draw_rect(r.grow(10), Ui.CONTOUR)
		draw_rect(r, couleur)
		for i in 6:
			draw_rect(Rect2(r.position.x, r.position.y + i * r.size.y / 6.0, r.size.x, r.size.y / 12.0), Color(couleur2, 0.18))
		var f := Ui.police_titre()
		var fs := 140 if texte.length() < 14 else 100
		var w := f.get_string_size(texte, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var p := r.get_center() + Vector2(-w / 2.0, 10)
		draw_string_outline(f, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 24, Ui.CONTOUR)
		draw_string(f, p, texte, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.JAUNE)
		var w2 := f.get_string_size(sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 60).x
		draw_string_outline(f, r.get_center() + Vector2(-w2 / 2.0, 120), sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, 14, Ui.CONTOUR)
		draw_string(f, r.get_center() + Vector2(-w2 / 2.0, 120), sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Ui.ROSE)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)


## Flèche de l'ola (0 gauche, 1 haut, 2 droite, 3 bas).
class Fleche extends Control:
	var direction := 0
	var validee := false

	func _draw() -> void:
		var c := size / 2.0
		var s := minf(size.x, size.y)
		draw_style_box(Ui.boite(Ui.VERT if validee else Ui.NUIT_CLAIR, 18, 5), Rect2(Vector2.ZERO, size))
		var pts := PackedVector2Array([Vector2(0, -0.32), Vector2(0.3, 0.05), Vector2(0.12, 0.05), Vector2(0.12, 0.32),
			Vector2(-0.12, 0.32), Vector2(-0.12, 0.05), Vector2(-0.3, 0.05)])
		var angle: float = [-PI / 2.0, 0.0, PI / 2.0, PI][direction]
		var out := PackedVector2Array()
		for q in pts:
			out.append(c + (q * s).rotated(angle))
		draw_colored_polygon(out, Ui.JAUNE if not validee else Ui.BLANC)
		out.append(out[0])
		draw_polyline(out, Ui.CONTOUR, 4, true)
