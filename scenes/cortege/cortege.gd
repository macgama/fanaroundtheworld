extends Control
## Le cortège : la marche du fan club jusqu'au stade (règles dans Cortege).
##  1. Départ : du local du club, ou de la gare / du parking après un déplacement.
##  2. En marche : les FANZZY ouvrent la marche avec la banderole, le kop suit.
##     Marche en rythme (en option) : taper au tempo (ESPACE, clic ou doigt).
##  3. Arrêts : 2 ou 3 choix (touches 1, 2, 3 ou clic).
##  4. Arrivée : ferveur, nouveaux supporters, bonus de départ, puis Ta tribune.

const EcranDeplacement := preload("res://scenes/deplacement/deplacement.gd")

const BPM := 100.0
const FENETRE_PARFAIT := 0.09
const FENETRE_BIEN := 0.18
const DUREE_SEGMENT := 2.2   # marche sans le rythme (secondes)

var _p: Dictionary
var _fiche: Dictionary
var _match_id := ""
var _lieu := "domicile"
var _transport := "domicile"
var _familles: Array = []
var _convoi: Array = []
var _kop_avant := 0
var _rencontre: Dictionary = {}   # le FANZZY qui peut marcher avec vous
var _evenements: Array = []
var _etat: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _auto := false
var _rythme_actif := true
var _en_route := false

var _rue: Rue
var _fanzzy: Array = []           # FanzzyAnime en tête du cortège
var _intro: PanelContainer
var _bandeau: PanelContainer
var _jauge: Control
var _lbl_temps: Label
var _lbl_recrues: Label
var _progres: Progres
var _carte_evt: PanelContainer
var _choix_boutons: Array = []
var _evt_courant: Dictionary = {}
var _attente_choix := false

# marche en rythme
var _pas: Array = []              # instants des pas à taper
var _juges: Array = []            # true quand le pas est jugé
var _t := 0.0
var _parfaits := 0
var _biens := 0
var _cible: Cible
var _lbl_rythme: Label


func _ready() -> void:
	_p = Game.params.duplicate()
	var m := Donnees.match_par_id(str(_p.get("match_id", "")))
	if m.is_empty():
		Game.aller(Game.SCENE_CARTE)
		return
	_fiche = FicheMatch.de(m)
	_match_id = str(_fiche["id"])
	_auto = bool(_p.get("auto", false)) or "--auto" in OS.get_cmdline_user_args()
	var depl := Game.deplacement_du_jour(_match_id)
	_lieu = Cortege.lieu(not depl.is_empty())
	_transport = str(depl.get("transport", "car")) if not depl.is_empty() else "domicile"
	_convoi = Game.convoi()
	_familles = Game.familles_convoi()
	_kop_avant = Game.kop()
	_rencontre = Rencontres.tirer(Game.club, Game.fanzzy, "cortege", randf())
	_rythme_actif = Reglages.marche_rythme()
	var graine := Fiction.graine("%s|cortege|%s" % [_match_id, Time.get_date_string_from_system()])  # sans_traduction
	_rng.seed = graine
	_evenements = Cortege.tirer(graine, _lieu, tr(str(_rencontre.get("nom", ""))))
	_etat = Cortege.nouvel_etat(Cortege.ferveur_depart(_convoi.size(), Kop.palier(_kop_avant), int(depl.get("ferveur", -1))))

	_rue = Rue.new()
	_rue.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rue.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var cc := Game.couleurs_club()
	_rue.c1 = cc[0]
	_rue.c2 = cc[1]
	_rue.nom_club = Game.fan_club_nom.to_upper()
	_rue.nb_kop = clampi(8 + _kop_avant / 25, 8, 44)
	_rue.ferveur = float(_etat["ferveur"]) / 100.0
	_rue.exterieur = _lieu == "exterieur"
	add_child(_rue)
	_poser_fanzzy()
	_construire_bandeau()
	_construire_intro()
	if _auto:
		get_tree().create_timer(0.8).timeout.connect(func():
			if is_instance_valid(_intro) and not _en_route:
				_partir())


func _process(delta: float) -> void:
	_t += delta
	_rue.ferveur = lerpf(_rue.ferveur, float(_etat["ferveur"]) / 100.0, delta * 2.0)
	if not _pas.is_empty():
		_suivre_rythme()


# ------------------------------------------------------------------ construction

func _poser_fanzzy() -> void:
	# l'équipe de la tribune d'abord, puis d'autres membres : 5 au plus en tête
	var ids: Array = []
	for id in Game.equipe + _convoi:
		if not str(id) in ids and not Game.fanzzy_par_id(str(id)).is_empty():
			ids.append(str(id))
	ids = ids.slice(0, 5)
	var cc := Game.couleurs_club()
	for i in ids.size():
		var f := FanzzyAnime.creer(ids[i])
		f.couleurs_echarpe = PackedColorArray([cc[0], cc[1]])
		f.scale = Vector2.ONE * Buvette.echelle(f, 190.0 - i * 8.0)
		f.position = Vector2(1480 - i * 150, 905 - (i % 2) * 26)
		f.bpm = BPM
		f.decalage = i * 0.13
		_rue.add_child(f)
		f.jouer(&"chanter" if i % 2 == 0 else &"agiter_echarpe")
		_fanzzy.append(f)
	_rue.x_banderole = Vector2(1480 - (ids.size() - 1) * 150 - 40, 1520) if ids.size() > 1 else Vector2(1380, 1560)


func _construire_bandeau() -> void:
	_bandeau = Ui.panneau()
	_bandeau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_bandeau.offset_left = -620
	_bandeau.offset_right = 620
	_bandeau.offset_top = 22
	add_child(_bandeau)
	var v := Ui.vbox(6)
	_bandeau.add_child(v)
	var t := Ui.label(tr("Cortège vers %s") % _fiche["stade"]["nom"], 34, Ui.JAUNE, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(t)
	var h := Ui.hbox(12)
	h.add_child(Ui.label("Ferveur", 20, Ui.BLANC, true))
	_jauge = EcranDeplacement.Jauge.new()
	_jauge.custom_minimum_size = Vector2(0, 30)
	_jauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_jauge)
	_lbl_recrues = Ui.label("", 18, Ui.VERT, true)
	_lbl_recrues.custom_minimum_size = Vector2(250, 0)
	h.add_child(_lbl_recrues)
	_lbl_temps = Ui.label("", 18, Ui.GRIS)
	_lbl_temps.custom_minimum_size = Vector2(270, 0)
	h.add_child(_lbl_temps)
	v.add_child(h)
	_progres = Progres.new()
	_progres.custom_minimum_size = Vector2(0, 34)
	_progres.arrets = _evenements.size()
	v.add_child(_progres)
	_maj_bandeau()


func _maj_bandeau() -> void:
	_jauge.set("valeur", int(_etat["ferveur"]))
	_jauge.queue_redraw()
	var marge := Cortege.marge(_etat)
	_lbl_temps.text = tr("Coup d'envoi dans %d min") % marge if marge >= 0 else tr("En retard de %d min !") % -marge
	_lbl_temps.add_theme_color_override("font_color", Ui.GRIS if marge >= 10 else (Ui.JAUNE if marge >= 0 else Ui.ROUGE))
	_lbl_recrues.text = tr("+%d passants nous suivent") % int(_etat["recrues"]) if int(_etat["recrues"]) > 0 else tr("Kop : %s") % Kop.texte(_kop_avant)


func _construire_intro() -> void:
	_intro = Ui.panneau(Ui.NUIT, 28, 6)
	_intro.set_anchors_preset(Control.PRESET_CENTER)
	_intro.offset_left = -520
	_intro.offset_right = 520
	_intro.offset_top = -230
	_intro.offset_bottom = 150
	add_child(_intro)
	var v := Ui.vbox(14)
	_intro.add_child(v)
	var t := Ui.label("LE CORTÈGE", 54, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var dep := tr("Départ : %s. Le kop marche jusqu'au stade derrière la banderole du club.") % Cortege.depart_texte(_transport)
	var l := Ui.label(dep, 22, Ui.BLANC)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var l2 := Ui.label(tr("%d arrêts en route. Une bonne ferveur donne de l'ambiance au coup d'envoi, mais attention à l'heure !") % _evenements.size(), 19, Ui.GRIS)
	l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	var cb := CheckButton.new()
	cb.text = "Marche en rythme (tape au tempo entre les arrêts)"
	cb.button_pressed = _rythme_actif
	cb.add_theme_font_size_override("font_size", 20)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cb.toggled.connect(func(oui: bool):
		_rythme_actif = oui
		Reglages.regler_marche_rythme(oui))
	v.add_child(cb)
	var h := Ui.hbox(18)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var go := Ui.bouton("C'EST PARTI !", Ui.VERT, 32)
	Ui.colorer_bouton(go, Ui.VERT, true)
	go.custom_minimum_size = Vector2(380, 88)
	go.pressed.connect(_partir)
	h.add_child(go)
	var direct := Ui.bouton("Direct en tribune", Ui.NUIT_CLAIR, 22)
	direct.custom_minimum_size = Vector2(0, 88)
	direct.tooltip_text = "Pas de cortège pour ce match : ni bonus, ni nouveaux supporters"
	direct.pressed.connect(func(): Game.aller(Game.SCENE_TRIBUNE, _p))
	h.add_child(direct)
	v.add_child(h)
	Ui.pop(_intro, 1.05)


# ------------------------------------------------------------------ en marche

func _partir() -> void:
	if _en_route:
		return
	_en_route = true
	var intro := _intro
	_intro = null
	var tw := create_tween()
	tw.tween_property(intro, "modulate:a", 0.0, 0.2)
	tw.tween_callback(intro.queue_free)
	tw.tween_callback(func(): _marcher(0))


## Marche jusqu'à l'arrêt i (ou jusqu'au stade quand il n'y en a plus).
func _marcher(i: int) -> void:
	var n := _evenements.size()
	var cible := float(i + 1) / float(n + 1) if i < n else 1.0
	var fin := func():
		if i < n:
			_montrer_evenement(i)
		else:
			_arriver()
	var avec_rythme := _rythme_actif
	var duree := DUREE_SEGMENT
	if avec_rythme:
		duree = (Cortege.PAS_RYTHME + 1) * 60.0 / BPM
		_lancer_rythme()
	_rue.marche = true
	for f in _fanzzy:
		f.energie = 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_progres, "avance", cible, duree)
	tw.tween_property(_rue, "avance", _rue.avance + 1900.0 * duree / DUREE_SEGMENT * 0.6, duree)
	tw.tween_method(func(_a: float): _progres.queue_redraw(), 0.0, 1.0, duree)
	tw.chain().tween_callback(func():
		_rue.marche = false
		if avec_rythme:
			_finir_rythme()
		fin.call())


func _lancer_rythme() -> void:
	var periode := 60.0 / BPM
	_pas.clear()
	_juges.clear()
	_parfaits = 0
	_biens = 0
	for k in Cortege.PAS_RYTHME:
		_pas.append(_t + periode * (k + 1))
		_juges.append(false)
	_cible = Cible.new()
	_cible.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_cible.offset_left = -90
	_cible.offset_right = 90
	_cible.offset_top = -330
	_cible.offset_bottom = -150
	_cible.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cible.couleur = Game.couleurs_club()[0]
	add_child(_cible)
	_lbl_rythme = Ui.label("Tape au tempo : ESPACE ou clic", 26, Ui.BLANC, true, 6)
	_lbl_rythme.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_rythme.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_rythme.offset_left = -500
	_lbl_rythme.offset_right = 500
	_lbl_rythme.offset_top = -130
	_lbl_rythme.offset_bottom = -90
	_lbl_rythme.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl_rythme)


func _suivre_rythme() -> void:
	# prochain pas à venir : la cible se resserre vers lui
	var prochain := -1
	for k in _pas.size():
		if not _juges[k] and _t > float(_pas[k]) + FENETRE_BIEN:
			_juges[k] = true
			_retour_pas("Raté", Ui.ROSE)
		if prochain < 0 and not _juges[k]:
			prochain = k
	if is_instance_valid(_cible):
		var periode := 60.0 / BPM
		_cible.phase = 1.0 - clampf((float(_pas[prochain]) - _t) / periode, 0.0, 1.0) if prochain >= 0 else 0.0
		_cible.queue_redraw()
	if _auto and prochain >= 0 and absf(float(_pas[prochain]) - _t) < 0.02:
		_taper()


func _taper() -> void:
	var meilleur := -1
	var ecart := INF
	for k in _pas.size():
		if _juges[k]:
			continue
		var d := absf(_t - float(_pas[k]))
		if d < ecart:
			ecart = d
			meilleur = k
	if meilleur < 0 or ecart > 60.0 / BPM * 0.5:
		return
	_juges[meilleur] = true
	for f in _fanzzy:
		f.rebondir(0.5)
	if ecart <= FENETRE_PARFAIT:
		_parfaits += 1
		_retour_pas("PARFAIT !", Ui.JAUNE)
		_rue.secousse = 1.0
	elif ecart <= FENETRE_BIEN:
		_biens += 1
		_retour_pas("Bien", Ui.VERT)
	else:
		_retour_pas("Raté", Ui.ROSE)


func _retour_pas(texte: String, couleur: Color) -> void:
	if not is_instance_valid(_lbl_rythme):
		return
	_lbl_rythme.text = texte
	_lbl_rythme.add_theme_color_override("font_color", couleur)
	Ui.pop(_lbl_rythme, 1.2, 0.12)


func _finir_rythme() -> void:
	var r := Cortege.rythme(_parfaits, _biens)
	Cortege.appliquer_rythme(_etat, r)
	_pas.clear()
	_juges.clear()
	if is_instance_valid(_cible):
		_cible.queue_free()
	if is_instance_valid(_lbl_rythme):
		var l := _lbl_rythme
		l.text = tr("Marche : %d parfaits, %d biens · %+d ferveur") % [_parfaits, _biens, int(r["ferveur"])]
		l.add_theme_color_override("font_color", Ui.JAUNE)
		var tw := l.create_tween()
		tw.tween_interval(1.2)
		tw.tween_property(l, "modulate:a", 0.0, 0.3)
		tw.tween_callback(l.queue_free)
	_maj_bandeau()


# ------------------------------------------------------------------ arrêts

func _montrer_evenement(i: int) -> void:
	_evt_courant = _evenements[i]
	for f in _fanzzy:
		f.jouer(&"encourager")
	_carte_evt = Ui.panneau(Ui.NUIT, 26, 6)
	_carte_evt.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_carte_evt.offset_left = -600
	_carte_evt.offset_right = 600
	_carte_evt.offset_top = 210
	_carte_evt.offset_bottom = 210
	add_child(_carte_evt)
	var v := Ui.vbox(10)
	_carte_evt.add_child(v)
	var h := Ui.hbox(10)
	h.add_child(Ui.pastille(tr("Arrêt %d / %d") % [i + 1, _evenements.size()], Ui.ROSE, 15))
	var t := Ui.label(tr(str(_evt_courant["titre"])), 30, Ui.JAUNE, true, 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(t)
	v.add_child(h)
	if _evt_courant.get("id", "") == "rencontre" and not _rencontre.is_empty():
		var hr := Ui.hbox(14)
		var tex := TextureRect.new()
		tex.texture = Game.texture_fanzzy(str(_rencontre["id"]), true)
		tex.custom_minimum_size = Vector2(110, 110)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hr.add_child(tex)
		var tx := Ui.label(Cortege.texte_evenement(_evt_courant), 20, Ui.BLANC)
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		tx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tx.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hr.add_child(tx)
		v.add_child(hr)
	else:
		var tx := Ui.label(Cortege.texte_evenement(_evt_courant), 20, Ui.BLANC)
		tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(tx)
	_choix_boutons = []
	var k := 0
	for c in _evt_courant["choix"]:
		var ok := Cortege.choix_possible(c, _familles)
		var libelle := "%d. %s" % [k + 1, tr(str(c["texte"]))]
		if c.has("famille"):
			libelle += tr("  (FANZZY %s)") % Game.nom_famille(str(c["famille"]))
		var b := Ui.bouton(libelle, Ui.BLEU if ok else Ui.NUIT_CLAIR, 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 58)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not ok
		b.tooltip_text = _apercu(c)
		if c.has("famille"):
			b.tooltip_text += "\n" + (tr("Il faut un FANZZY %s au club") % Game.nom_famille(str(c["famille"])) if not ok else tr("Grâce à un FANZZY %s du club") % Game.nom_famille(str(c["famille"])))
			if ok:
				Ui.colorer_bouton(b, Game.couleur_famille(str(c["famille"])).darkened(0.25))
		var cc: Dictionary = c
		b.pressed.connect(func(): _choisir(i, cc))
		v.add_child(b)
		_choix_boutons.append(b)
		k += 1
	Ui.pop(_carte_evt, 1.05)
	_attente_choix = true
	if _auto:
		var meilleur := -1
		for j in _choix_boutons.size():
			if not _choix_boutons[j].disabled and (meilleur < 0 or int(_evt_courant["choix"][j].get("ferveur", 0)) > int(_evt_courant["choix"][meilleur].get("ferveur", 0))):
				meilleur = j
		var bouton: Button = _choix_boutons[meilleur]
		get_tree().create_timer(1.2).timeout.connect(func(): bouton.pressed.emit())


## Ce que l'on sait d'un choix avant de le faire : le temps qu'il prend.
func _apercu(c: Dictionary) -> String:
	var mn := int(c.get("minutes", 0))
	if mn > 0:
		return tr("Prend %d min") % mn
	if mn < 0:
		return tr("Fait gagner %d min") % -mn
	return tr("Ne prend pas de temps")


func _choisir(i: int, c: Dictionary) -> void:
	if not _attente_choix:
		return
	_attente_choix = false
	var r := Cortege.resultat(c, _rng.randf())
	Cortege.appliquer(_etat, _evt_courant, r)
	_maj_bandeau()
	for b in _choix_boutons:
		b.disabled = true
	for f in _fanzzy:
		f.jouer(&"celebrer" if int(r["ferveur"]) >= 8 else &"applaudir", 1.6)
	if int(r["recrues"]) > 0:
		_rue.nb_kop = mini(_rue.nb_kop + 2, 52)
	var v: VBoxContainer = _carte_evt.get_child(0)
	var effets: Array = []
	if int(r["ferveur"]) != 0:
		effets.append(tr("%+d ferveur") % int(r["ferveur"]))
	if int(r["recrues"]) > 0:
		effets.append(tr("+%d passants") % int(r["recrues"]))
	if int(r["minutes"]) > 0:
		effets.append(tr("+%d min") % int(r["minutes"]))
	elif int(r["minutes"]) < 0:
		effets.append(tr("%d min gagnées") % -int(r["minutes"]))
	if r["chambre"]:
		effets.append(tr("tribune d'en face remontée"))
	var lr := Ui.label(tr(str(r["res"])) + ("   " + " · ".join(effets) if not effets.is_empty() else ""), 22, Ui.VERT if r["ferveur"] >= 0 else Ui.ROSE, true, 5)
	lr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lr)
	var carte_evt := _carte_evt
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(carte_evt, "modulate:a", 0.0, 0.25)
	tw.tween_callback(carte_evt.queue_free)
	tw.tween_callback(func():
		for f in _fanzzy:
			f.jouer(&"chanter")
		_marcher(i + 1))


func _unhandled_input(ev: InputEvent) -> void:
	if not _pas.is_empty():
		var tape := false
		if ev is InputEventKey and ev.pressed and not ev.echo and (ev as InputEventKey).physical_keycode in [KEY_SPACE, KEY_ENTER]:
			tape = true
		elif ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			tape = true
		elif ev is InputEventScreenTouch and ev.pressed:
			tape = true
		if tape:
			_taper()
			get_viewport().set_input_as_handled()
			return
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if _attente_choix:
		var idx := -1
		# touche physique : en AZERTY, « 1 » sans Maj donne « & »
		match (ev as InputEventKey).physical_keycode:
			KEY_1, KEY_KP_1:
				idx = 0
			KEY_2, KEY_KP_2:
				idx = 1
			KEY_3, KEY_KP_3:
				idx = 2
		if idx >= 0 and idx < _choix_boutons.size() and not _choix_boutons[idx].disabled:
			_choix_boutons[idx].pressed.emit()
			get_viewport().set_input_as_handled()
	elif not _en_route and (ev as InputEventKey).keycode == KEY_ESCAPE:
		Game.aller(Game.SCENE_TRIBUNE, _p)


# ------------------------------------------------------------------ arrivée

func _arriver() -> void:
	_rue.stade_visible = true
	for f in _fanzzy:
		f.jouer(&"celebrer", 3.0)
	var b := Cortege.bilan(_etat, _kop_avant)
	var r := Game.finir_cortege(_match_id, b, str(_rencontre.get("id", "")))
	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.55, 0.4)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -480
	pan.offset_right = 480
	pan.offset_top = -300
	pan.offset_bottom = 300
	add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label("ARRIVÉS AU STADE !" if b["a_l_heure"] else "ARRIVÉS… APRÈS L'ÉCHAUFFEMENT", 46 if b["a_l_heure"] else 34, Ui.JAUNE if b["a_l_heure"] else Ui.ROSE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var lignes := [
		["Ferveur du cortège", "%d / 100" % int(b["ferveur"]) + ("" if b["a_l_heure"] else tr(" (-%d retard)") % Cortege.MALUS_RETARD)],
		["Nouveaux supporters au kop", "+%s" % Kop.texte(int(r["kop"]))],
		["Kop", tr("%s supporters") % Kop.texte(Game.kop())],
		["Ambiance au coup d'envoi", tr("+%d (cortège) +%d (kop)") % [int(b["bonus"]), Kop.bonus_jauge(Game.kop())]],
		["Prime du cortège", tr("+%d Jetons · +%d XP PASS") % [int(b["jetons"]), int(r["xp_pass"])]],
	]
	if b["chambre"]:
		lignes.append(["Tribune d'en face", tr("chambrée : elle poussera plus fort")])
	if str(r.get("rencontre", "")) != "":
		lignes.append([tr("Rencontre : %s") % tr(str(Game.fanzzy_par_id(str(r["rencontre"])).get("nom", ""))), tr("à convaincre au Fan club")])
	for l in lignes:
		var h := Ui.hbox(10)
		var a := Ui.label(l[0], 23, Ui.BLANC)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Ui.label(l[1], 24, Ui.JAUNE, true))
		v.add_child(h)
	var go := Ui.bouton("ENTRER EN TRIBUNE", Ui.VERT, 32)
	Ui.colorer_bouton(go, Ui.VERT, true)
	go.custom_minimum_size = Vector2(480, 90)
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func(): Game.aller(Game.SCENE_TRIBUNE, _p))
	v.add_child(go)
	Ui.pop(pan, 1.05)
	if "--quitter" in OS.get_cmdline_user_args():
		print("RESULTAT cortege ferveur=%d recrues=%d bonus=%d a_l_heure=%s" % [int(b["ferveur"]), int(r["kop"]), int(b["bonus"]), b["a_l_heure"]])  # sans_traduction
		get_tree().create_timer(1.5).timeout.connect(func(): get_tree().quit())


## La rue qui défile : immeubles, trottoir, le kop derrière la banderole, le stade au bout.
class Rue extends Control:
	var avance := 0.0         # pixels parcourus
	var marche := false
	var ferveur := 0.5
	var c1 := Ui.BLEU
	var c2 := Ui.BLANC
	var nom_club := ""
	var nb_kop := 12
	var exterieur := false
	var stade_visible := false
	var secousse := 0.0
	var x_banderole := Vector2(900, 1500)
	var _t := 0.0
	var _stade := 0.0

	func _process(delta: float) -> void:
		_t += delta
		secousse = maxf(0.0, secousse - delta * 3.0)
		_stade = move_toward(_stade, 1.0 if stade_visible else 0.0, delta * 0.8)
		queue_redraw()

	func _draw() -> void:
		var w := size.x
		var h := size.y
		# ciel de fin d'après-midi
		var haut := Color("#5b8dff") if not exterieur else Color("#6a5bd6")
		var bas := Color("#ffc27a")
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h), Vector2(0, h)]), PackedColorArray([haut, haut, bas, bas]))
		# le stade au loin, qui grandit à l'arrivée
		if _stade > 0.0:
			var sw := 900.0 * (0.6 + 0.4 * _stade)
			var sx := w - sw * 0.75
			var sy := 640.0
			draw_rect(Rect2(sx, sy - 220.0 * _stade, sw, 220.0 * _stade), Color("#d9d4ff", _stade))
			draw_rect(Rect2(sx, sy - 220.0 * _stade, sw, 26), Color(c1, _stade))
			for k in 6:
				draw_rect(Rect2(sx + 40 + k * (sw - 80) / 5.0, sy - 260.0 * _stade, 8, 50), Color(1, 1, 1, _stade))
		# immeubles au loin (lents) puis devant (rapides)
		_immeubles(avance * 0.35, 560.0, 0.55, 7)
		_immeubles(avance, 700.0, 1.0, 13)
		# trottoir et route
		draw_rect(Rect2(0, 700, w, 60), Color("#c9c2b4"))
		draw_rect(Rect2(0, 760, w, h - 760), Color("#4d4a5e"))
		var d := fposmod(avance * 1.2, 240.0)
		var x := -d
		while x < w:
			draw_rect(Rect2(x, 1000, 120, 12), Color(1, 1, 1, 0.5))
			x += 240.0
		# le kop : des supporters qui marchent derrière les FANZZY
		var rng := RandomNumberGenerator.new()
		rng.seed = 777
		var sprites := FouleSprites.disponible()
		for k in nb_kop:
			var rang := k % 3
			var col := k / 3
			var px := x_banderole.x - 40.0 - col * 92.0 - rang * 30.0 + rng.randf_range(-12, 12)
			var py := 800.0 + rang * 34.0
			var ph := rng.randf()
			var corps: Color = c1 if rng.randf() < 0.7 else c2
			var autre: Color = c2 if corps == c1 else c1
			var peau: Color = FouleSprites.PEAUX[rng.randi() % FouleSprites.PEAUX.size()]
			var hauteur := 120.0 + rang * 10.0
			var rebond := absf(sin(_t * 5.2 + ph * TAU)) * (8.0 if marche else 2.0) + secousse * 6.0
			if sprites:
				var ga := FouleSprites.geste_ambiance(clampf(ferveur + 0.2, 0.0, 1.0), ph, _t)
				if marche and ga[0] == &"repos":
					ga = [&"echarpe", _t + ph * 3.0]
				FouleSprites.dessiner(self, Vector2(px, py - rebond), hauteur, ga[0], ga[1], corps, autre, peau, rng.randi() % 3)
			else:
				draw_rect(Rect2(px - 14, py - 70 - rebond, 28, 50), corps)
				draw_circle(Vector2(px, py - 86 - rebond), 14, peau)
		# drapeaux au-dessus du kop
		for k in clampi(nb_kop / 7, 1, 5):
			var fx := x_banderole.x - 160.0 - k * 260.0
			var fy := 640.0 + sin(_t * 2.0 + k) * 6.0
			draw_line(Vector2(fx, fy), Vector2(fx, fy + 150), Color("#3a2a1a"), 5)
			var ond := sin(_t * 6.0 + k) * 10.0
			draw_polygon(PackedVector2Array([Vector2(fx, fy), Vector2(fx + 110, fy + 10 + ond), Vector2(fx + 110, fy + 60 + ond), Vector2(fx, fy + 54)]),
				PackedColorArray([c1, c1, c1, c1]))
			draw_rect(Rect2(fx, fy + 22, 110, 12), c2)
		_banderole()

	## La banderole du club, portée par les FANZZY (qui sont dessinés devant).
	func _banderole() -> void:
		var x0 := x_banderole.x
		var x1 := x_banderole.y
		var y := 760.0 + sin(_t * 3.0) * 4.0
		var pts := PackedVector2Array()
		var n := 16
		for k in n + 1:
			var x := lerpf(x0, x1, float(k) / n)
			pts.append(Vector2(x, y + sin(_t * 4.0 + k * 0.7) * 5.0))
		for k in n:
			var a := pts[k]
			var b := pts[k + 1]
			draw_polygon(PackedVector2Array([a, b, b + Vector2(0, 92), a + Vector2(0, 92)]), PackedColorArray([c1, c1, c1, c1]))
		draw_polyline(pts, c2, 10)
		var bas := PackedVector2Array()
		for q in pts:
			bas.append(q + Vector2(0, 92))
		draw_polyline(bas, c2, 10)
		var f := Ui.police_titre()
		var fs := 50
		var txt := nom_club
		while fs > 22 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > (x1 - x0) - 60:
			fs -= 2
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2((x0 + x1) / 2.0 - tw / 2.0, y + 46 + fs * 0.35)
		var texte_c := c2 if c2.get_luminance() > 0.5 or c1.get_luminance() < 0.5 else Ui.CONTOUR
		draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Ui.CONTOUR if texte_c != Ui.CONTOUR else Ui.BLANC)
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, texte_c)

	func _immeubles(decalage: float, sol: float, echelle: float, graine: int) -> void:
		var rng := RandomNumberGenerator.new()
		var largeur_bloc := 260.0 * echelle
		var premier := int(floor(decalage / largeur_bloc))
		var x0 := -fposmod(decalage, largeur_bloc)
		var couleurs := [Color("#e88d67"), Color("#f2c57c"), Color("#8fb3a8"), Color("#c98bb9"), Color("#9aa6e8"), Color("#e3a75f")]
		for k in int(size.x / largeur_bloc) + 2:
			rng.seed = graine * 1000 + premier + k
			var hb := rng.randf_range(200.0, 380.0) * echelle
			var lb := largeur_bloc - rng.randf_range(8.0, 30.0) * echelle
			var x := x0 + k * largeur_bloc
			var col: Color = couleurs[rng.randi() % couleurs.size()]
			if echelle < 1.0:
				col = col.lerp(Color("#b9b0e8"), 0.45)
			draw_rect(Rect2(x, sol - hb, lb, hb), col)
			draw_rect(Rect2(x - 6 * echelle, sol - hb - 12 * echelle, lb + 12 * echelle, 14 * echelle), col.darkened(0.25))
			# fenêtres
			var fen := Color("#fff4c8") if echelle >= 1.0 else Color(1, 1, 1, 0.25)
			var cols := 3
			for r in int(hb / (70.0 * echelle)):
				for c in cols:
					draw_rect(Rect2(x + 22 * echelle + c * (lb - 44 * echelle) / cols, sol - hb + 30 * echelle + r * 70.0 * echelle, 34 * echelle, 40 * echelle), fen.darkened(0.15 * float((r + c) % 2)))
			# fanions aux couleurs du club entre les immeubles de devant
			if echelle >= 1.0 and rng.randf() < 0.5:
				for f in 6:
					var fx := x + lb * (f + 0.5) / 6.0
					draw_polygon(PackedVector2Array([Vector2(fx - 14, sol - hb + 10), Vector2(fx + 14, sol - hb + 10), Vector2(fx, sol - hb + 40)]),
						PackedColorArray([c1 if f % 2 == 0 else c2, c1 if f % 2 == 0 else c2, c1 if f % 2 == 0 else c2]))


## Avancée du cortège : du départ au stade, avec les arrêts.
class Progres extends Control:
	var avance := 0.0
	var arrets := 3

	func _draw() -> void:
		var y := size.y / 2.0
		draw_line(Vector2(20, y), Vector2(size.x - 20, y), Color(1, 1, 1, 0.25), 8, true)
		draw_line(Vector2(20, y), Vector2(20 + (size.x - 40) * avance, y), Ui.JAUNE, 8, true)
		for k in arrets:
			var f := float(k + 1) / float(arrets + 1)
			var p := Vector2(20 + (size.x - 40) * f, y)
			draw_circle(p, 10, Ui.ROSE if avance + 0.001 >= f else Ui.NUIT_CLAIR)
			draw_arc(p, 10, 0, TAU, 24, Ui.CONTOUR, 3, true)
		var fin := Vector2(size.x - 20, y)
		draw_circle(fin, 14, Ui.VERT if avance >= 0.999 else Ui.BLANC)
		draw_arc(fin, 14, 0, TAU, 24, Ui.CONTOUR, 3, true)
		var tete := Vector2(20 + (size.x - 40) * avance, y)
		draw_circle(tete, 9, Ui.BLANC)


## La cible du rythme : un anneau qui se resserre jusqu'au pas à taper.
class Cible extends Control:
	var phase := 0.0
	var couleur := Ui.BLEU

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x * 0.32
		draw_circle(c, r, Color(couleur, 0.85))
		draw_arc(c, r, 0, TAU, 48, Ui.CONTOUR, 6, true)
		var rr := lerpf(size.x * 0.5, r, phase)
		draw_arc(c, rr, 0, TAU, 48, Ui.JAUNE, 8, true)
		var f := Ui.police_titre()
		var txt := "♪"
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 54).x
		draw_string(f, c + Vector2(-tw / 2.0, 18), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Ui.BLANC)
