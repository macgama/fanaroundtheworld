class_name SoireeEcran
extends Control
## Soir de match : on vit un vrai match en direct, au stade, devant l'écran
## géant, au pub ou à la maison (le mode de suivi choisi sur la carte).
##
## Le score arrive du relais chaque minute (Donnees, live.json). À chaque but,
## la tribune explose (ou encaisse), puis le joueur lance une mini-ambiance :
##   ESPACE : le début du chant du club, en rythme, avec les paroles ;
##   T      : le tifo en 3 pans, à relâcher dans la zone dorée ;
##   O      : l'ola, 6 flèches à enchaîner.
## Entre les buts, les réactions (1, 2, 3) entretiennent la ferveur, qui
## multiplie les gains du prochain but. Règles et gains : SoireeMatch.
## Démo hors ligne (matchs d'exemple) ou --simuler : des buts simulés, sans gains ;
## B / N y simulent un but pour toi / pour l'adversaire.

const SonsScript := preload("res://scripts/audio/sons.gd")
const LIEUX_SON := {"stade": "stade", "ecran": "ecran_geant", "pub": "pub", "maison": "maison"}  # sans_traduction
const FLECHES := ["ui_left", "ui_up", "ui_right", "ui_down"]

var fiche: Dictionary
var camp := "home"
var mode := "maison"
## Pour le décor du duel (Duel.Decor) : -100…100, tiré de la ferveur.
var jauge := 0.0
var ferveur := SoireeMatch.FERVEUR_DEPART
var simule := false
## attente, celebration, choix, chant, tifo, ola, resultat, fin
var etat := "attente"

var _id := ""
var _score_vu := Vector2i(-1, -1)
var _file: Array = []           # buts qui attendent leur mini-ambiance
var _but: Dictionary = {}       # le but dont on joue la mini-ambiance
var _recharges: Dictionary = {}
var _t_etat := 0.0
var _t_minute := 0.0
var _prochain_simule := 0.0
var _rng := RandomNumberGenerator.new()
var _gains := {"jetons": 0, "xp": 0, "xp_pass": 0}
var _nb_ambiances := 0
var _statut_vu := ""
var _intensite_son := -1

var _decor: Control
var _fanzzy: Array = []
var _sons: Node
var _lbl_score: Label
var _lbl_minute: Label
var _pastille_minute: PanelContainer
var _barre_ferveur: ProgressBar
var _lbl_ferveur: Label
var _fil: VBoxContainer
var _boutons_reac: Dictionary = {}
var _centre: Control
var _lbl_aide: Label
var _banniere: Control
var _pause: Control

# mini-ambiance : chant
var _lecteur: ChantLecteur
var _programme: Array = []
var _chant_stats := {"parfaits": 0, "biens": 0, "total": 0}
var _karaoke: RichTextLabel
var _piste: PisteChant
# tifo
var _tifo: JaugeTifo
# ola
var _ola_seq: Array = []
var _ola_i := 0
var _ola_err := 0
var _ola_reste := 0.0
var _ola_fleches: Array = []
var _barre_temps: ProgressBar


func _ready() -> void:
	_rng.randomize()
	var p: Dictionary = Game.params
	var m := Donnees.match_par_id(str(p.get("match_id", "")))
	if m.is_empty():
		Game.aller(Game.SCENE_CARTE)
		return
	_id = str(m.get("id", ""))
	fiche = FicheMatch.de(m)
	camp = str(p.get("camp", "home"))
	mode = str(p.get("mode", "maison"))
	if not Game.MODES_SUIVI.has(mode):
		mode = "maison"
	simule = bool(p.get("simuler", false)) or Donnees.source == "exemple"
	if p.get("suivi_a_noter", false):
		p.erase("suivi_a_noter")
		Game.noter_suivi_favori(m, camp, mode)
	if simule:
		fiche["m"] = m.duplicate(true)
		_prochain_simule = _rng.randf_range(6.0, 12.0)
	else:
		Game.soiree_de(_id)  # l'heure d'arrivée compte pour la prime de fin
	_score_vu = SoireeMatch.score_de(fiche["m"])
	_statut_vu = str(fiche["m"].get("status", ""))
	_sons = SonsScript.new()
	_sons.name = "SonsSoiree"  # sans_traduction
	add_child(_sons)
	_lecteur = ChantLecteur.new()
	_lecteur.voix_muettes = ["J"]  # sans_traduction
	add_child(_lecteur)
	_lecteur.appui_juge.connect(_sur_appui_chant)
	_lecteur.fini.connect(func():
		if etat == "chant":
			_finir_ambiance(SoireeMatch.perf_chant(_chant_stats["parfaits"], _chant_stats["biens"], _chant_stats["total"])))
	_construire()
	_remplir_fil()
	_maj_score()
	Donnees.mis_a_jour.connect(_sur_donnees)
	_maj_son()
	if SoireeMatch.finie(fiche["m"]):
		_fin_du_match.call_deferred()


# ------------------------------------------------------------------ construction

func _construire() -> void:
	var dom: Dictionary = fiche["dom"]
	var ext: Dictionary = fiche["ext"]
	var nous: Dictionary = dom if camp == "home" else ext
	var eux: Dictionary = ext if camp == "home" else dom
	_decor = Duel.Decor.new()
	_decor.duel = self
	_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.c_nous = Duel._vive(nous["c1"], nous["c2"], Ui.BLEU)
	_decor.c_nous2 = nous["c2"]
	_decor.c_eux = Duel._vive(eux["c1"], eux["c2"], Ui.ROUGE)
	if _decor.c_eux.is_equal_approx(_decor.c_nous):
		_decor.c_eux = Ui.ROUGE if not _decor.c_nous.is_equal_approx(Ui.ROUGE) else Ui.JAUNE
	_decor.c_eux2 = eux["c2"]
	_decor.mode = mode
	_decor.texte_tifo = Game.fan_club_nom.to_upper()
	_decor.materiel = Materiel.affiche(Game.materiel)
	add_child(_decor)

	for i in 3:
		var mar := Duel.Marionnette.new()
		mar.texture = Game.texture_fanzzy(str(Game.equipe[i]))
		mar.fanzzy_id = Game.skin_de(str(Game.equipe[i]))
		mar.couleurs = PackedColorArray([_decor.c_nous, Color(_decor.c_nous2)])
		mar.action_fond = [&"encourager", &"agiter_echarpe", &"applaudir"][i]
		mar.position = Vector2(560 + i * 400, 1090)
		mar.hauteur = 400.0 if i == 1 else 360.0
		mar.phase = i * 0.9
		add_child(mar)
		_fanzzy.append(mar)

	_banniere = Duel.Banniere.new()
	_banniere.texte = Game.fan_club_nom.to_upper()
	_banniere.sous = tr("BUT !")
	_banniere.couleur = _decor.c_nous
	_banniere.couleur2 = _decor.c_nous2
	_banniere.set_anchors_preset(Control.PRESET_FULL_RECT)
	_banniere.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banniere.visible = false

	# en haut à gauche : le lieu et la ferveur
	var gauche := Ui.panneau(Ui.NUIT, 22, 5)
	gauche.position = Vector2(30, 20)
	gauche.custom_minimum_size = Vector2(470, 0)
	add_child(gauche)
	var vg := Ui.vbox(6)
	gauche.add_child(vg)
	vg.add_child(Ui.label("SOIR DE MATCH", 40, Ui.JAUNE, true, 8))
	var info: Dictionary = Game.MODES_SUIVI[mode]
	vg.add_child(Ui.label("%s · %s" % [tr(info["titre"]), tr(info["texte"])], 18, Ui.BLANC))
	var hf := Ui.hbox(8)
	hf.add_child(Ui.icone("feu", 26))
	_barre_ferveur = ProgressBar.new()
	_barre_ferveur.max_value = 100.0
	_barre_ferveur.show_percentage = false
	_barre_ferveur.custom_minimum_size = Vector2(250, 22)
	_barre_ferveur.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barre_ferveur.add_theme_stylebox_override("background", Ui.boite(Ui.CONTOUR, 11, 0))
	_barre_ferveur.add_theme_stylebox_override("fill", Ui.boite(Ui.ROSE, 11, 0))
	hf.add_child(_barre_ferveur)
	_lbl_ferveur = Ui.label("", 18, Ui.GRIS, true)
	hf.add_child(_lbl_ferveur)
	vg.add_child(hf)
	if simule:
		vg.add_child(Ui.pastille("Démo : buts simulés, sans Jetons", Ui.VIOLET, 15))

	# en haut au centre : le tableau d'affichage
	var tableau := Ui.panneau(Ui.NUIT, 26, 6)
	tableau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	tableau.offset_left = -330
	tableau.offset_right = 330
	tableau.offset_top = 18
	tableau.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(tableau)
	var vt := Ui.vbox(4)
	tableau.add_child(vt)
	var comp := Ui.label(fiche["competition"], 16, Ui.GRIS)
	comp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vt.add_child(comp)
	var ht := Ui.hbox(14)
	ht.alignment = BoxContainer.ALIGNMENT_CENTER
	vt.add_child(ht)
	ht.add_child(_equipe_tableau(dom, camp == "home"))
	_lbl_score = Ui.label("", 64, Ui.JAUNE, true, 10)
	_lbl_score.custom_minimum_size = Vector2(190, 0)
	_lbl_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ht.add_child(_lbl_score)
	ht.add_child(_equipe_tableau(ext, camp == "away"))
	var hm := Ui.hbox(8)
	hm.alignment = BoxContainer.ALIGNMENT_CENTER
	_pastille_minute = Ui.pastille("", Ui.ROUGE, 18)
	_lbl_minute = _pastille_minute.get_child(0) as Label
	hm.add_child(_pastille_minute)
	vt.add_child(hm)

	var quitter := Ui.bouton("Quitter", Ui.NUIT_CLAIR, 22)
	quitter.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quitter.offset_left = -190
	quitter.offset_right = -30
	quitter.offset_top = 24
	quitter.offset_bottom = 84
	quitter.pressed.connect(_ouvrir_pause)
	add_child(quitter)

	# à gauche : les réactions
	var reac := Ui.panneau(Ui.NUIT, 22, 5)
	reac.position = Vector2(30, 330)
	reac.custom_minimum_size = Vector2(300, 0)
	add_child(reac)
	var vr := Ui.vbox(10)
	reac.add_child(vr)
	vr.add_child(Ui.label("Réactions", 24, Ui.BLANC, true))
	for r in SoireeMatch.REACTIONS:
		var b := Ui.bouton("%s   [%s]" % [tr(r["titre"]), r["touche"]], Ui.BLEU, 24)
		b.custom_minimum_size = Vector2(270, 66)
		b.focus_mode = Control.FOCUS_NONE  # sinon Espace (le chant) réappuierait dessus
		var id: String = r["id"]
		b.pressed.connect(func(): _reagir(id))
		vr.add_child(b)
		_boutons_reac[id] = b
	var aide := Ui.label("Entretiens la ferveur : elle multiplie les gains du prochain but.", 15, Ui.GRIS)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.custom_minimum_size = Vector2(270, 0)
	vr.add_child(aide)

	# à droite : le fil des buts
	var droite := Ui.panneau(Ui.NUIT, 22, 5)
	droite.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	droite.offset_left = -330
	droite.offset_right = -30
	droite.offset_top = 330
	droite.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(droite)
	var vd := Ui.vbox(8)
	vd.custom_minimum_size = Vector2(270, 0)
	droite.add_child(vd)
	vd.add_child(Ui.label("Buts de la soirée", 24, Ui.BLANC, true))
	_fil = Ui.vbox(6)
	vd.add_child(_fil)

	# au centre : ce qui se passe (attente, but, mini-ambiance)
	_centre = Control.new()
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_centre)
	_lbl_aide = Ui.label("", 30, Ui.BLANC, true, 10)
	_lbl_aide.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_aide.offset_left = -520
	_lbl_aide.offset_right = 520
	_lbl_aide.offset_top = -60
	_lbl_aide.offset_bottom = 40
	add_child(_lbl_aide)
	add_child(_banniere)
	_maj_aide()


func _equipe_tableau(e: Dictionary, nous: bool) -> Control:
	var v := Ui.vbox(2)
	v.custom_minimum_size = Vector2(150, 0)
	var ec := Ui.ecusson(e["sigle"], e["c1"], e["c2"], 58)
	ec.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ec)
	var n := Ui.label(e["nom"], 17, Ui.JAUNE if nous else Ui.BLANC, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size = Vector2(150, 0)
	v.add_child(n)
	return v


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	var m: Dictionary = fiche["m"]
	var mi_temps := str(m.get("status", "")) == "HALFTIME"  # sans_traduction
	if etat != "fin":
		ferveur = SoireeMatch.ferveur_apres(ferveur, delta, mi_temps or str(m.get("status", "")) == "SCHEDULED")  # sans_traduction
	jauge = ferveur * 2.0 - 100.0
	_barre_ferveur.value = ferveur
	_lbl_ferveur.text = "x%.2f" % SoireeMatch.mult_ferveur(ferveur)
	for id in _recharges.keys():
		_recharges[id] -= delta
		var b: Button = _boutons_reac[id]
		if _recharges[id] <= 0.0:
			_recharges.erase(id)
			b.disabled = false
	_t_minute += delta
	if _t_minute >= 1.0:
		_t_minute = 0.0
		_maj_score()
		_maj_son()
	if simule and etat != "fin" and str(m.get("status", "")) == "LIVE":  # sans_traduction
		_prochain_simule -= delta
		if _prochain_simule <= 0.0:
			_prochain_simule = _rng.randf_range(25.0, 45.0)
			_simuler_but(_rng.randf() < 0.62)
	_t_etat += delta
	match etat:
		"celebration":
			if _t_etat >= 2.6:
				_ouvrir_choix()
		"choix":
			if _barre_temps:
				_barre_temps.value = maxf(0.0, SoireeMatch.DUREE_CHOIX - _t_etat)
			if _t_etat >= SoireeMatch.DUREE_CHOIX:
				_annonce("Trop tard : la tribune s'est calmée", Ui.GRIS)
				_suivant()
		"chant":
			_maj_karaoke()
			if _piste:
				_piste.queue_redraw()
		"tifo":
			_tifo.avancer(delta)
			if _tifo.termine():
				_finir_ambiance(SoireeMatch.perf_tifo(_tifo.ecarts))
		"ola":
			_ola_reste -= delta
			if _barre_temps:
				_barre_temps.value = maxf(0.0, _ola_reste)
			if _ola_reste <= 0.0:
				_finir_ola()
		"resultat":
			if _t_etat >= 3.0:
				_suivant()
	_decor.queue_redraw()


func _changer_etat(e: String) -> void:
	etat = e
	_t_etat = 0.0
	_maj_aide()


func _maj_aide() -> void:
	if _lbl_aide == null:
		return
	var m: Dictionary = fiche["m"]
	var s := str(m.get("status", ""))
	_lbl_aide.visible = etat == "attente"
	if s == "SCHEDULED":  # sans_traduction
		var reste := int(fiche["t"]) - Game.maintenant()
		_lbl_aide.text = tr("Avant-match : coup d'envoi dans %d min. Chauffe la tribune !") % maxi(1, reste / 60) if reste > 0 else tr("Coup d'envoi imminent…")
	elif s == "HALFTIME":  # sans_traduction
		_lbl_aide.text = tr("MI-TEMPS · la tribune reprend son souffle")
	else:
		_lbl_aide.text = tr("Le match est en direct. Au prochain but, lance l'ambiance !")


# ------------------------------------------------------------------ données

func _sur_donnees() -> void:
	if simule or etat == "fin":
		return
	var m := Donnees.match_par_id(_id)
	if m.is_empty():
		return
	fiche["m"] = m
	var sc := SoireeMatch.score_de(m)
	var cur := _score_vu
	for b in SoireeMatch.detecter(_score_vu, sc):
		if b["annule"]:
			_annonce("But annulé après vérification vidéo", Ui.GRIS)
			continue
		cur += Vector2i(1, 0) if b["cote"] == "home" else Vector2i(0, 1)
		_sur_but(str(b["cote"]), cur)
	if sc.x >= 0:
		_score_vu = sc
	var s := str(m.get("status", ""))
	if s != _statut_vu:
		if s == "HALFTIME":  # sans_traduction
			_annonce("MI-TEMPS", Ui.JAUNE)
		elif _statut_vu == "HALFTIME" and s == "LIVE":  # sans_traduction
			_annonce("C'est reparti : seconde période !", Ui.VERT)
		_statut_vu = s
	_maj_score()
	if SoireeMatch.finie(m):
		_fin_du_match()


func _simuler_but(pour_nous: bool) -> void:
	var m: Dictionary = fiche["m"]
	var sc := SoireeMatch.score_de(m)
	if sc.x < 0:
		sc = Vector2i.ZERO
	var cote := camp if pour_nous else ("away" if camp == "home" else "home")
	sc += Vector2i(1, 0) if cote == "home" else Vector2i(0, 1)
	m["score"] = {"current": {"home": sc.x, "away": sc.y}}
	if m.get("minute") != null:
		m["minute"] = mini(90, int(m["minute"]) + _rng.randi_range(3, 9))
	_score_vu = sc
	_sur_but(cote, sc)
	_maj_score()


func _maj_score() -> void:
	var m: Dictionary = fiche["m"]
	var sc := SoireeMatch.score_de(m)
	_lbl_score.text = "%d – %d" % [sc.x, sc.y] if sc.x >= 0 else "– : –"
	var s := str(m.get("status", ""))
	var mi := SoireeMatch.minute(m, Time.get_unix_time_from_system() - Donnees.derniere_maj_live)
	if s == "LIVE" and mi >= 0:  # sans_traduction
		_lbl_minute.text = tr("EN DIRECT %d'") % mi
	else:
		_lbl_minute.text = FicheMatch.statut_court(fiche)
	var boite := Ui.boite(Ui.ROUGE if s in SoireeMatch.STATUTS_EN_JEU else Color("#6b6699"), 12, 3)
	boite.content_margin_left = 10
	boite.content_margin_right = 10
	_pastille_minute.add_theme_stylebox_override("panel", boite)
	if etat == "attente":
		_maj_aide()


func _maj_son() -> void:
	var i := 0 if ferveur < 35.0 else (1 if ferveur < 70.0 else 2)
	if i != _intensite_son:
		_intensite_son = i
		_sons.ambiance(LIEUX_SON.get(mode, "maison"), i)


# ------------------------------------------------------------------ buts

func _sur_but(cote: String, score: Vector2i) -> void:
	var pour_nous := cote == camp
	var m: Dictionary = fiche["m"]
	var mi := SoireeMatch.minute(m, Time.get_unix_time_from_system() - Donnees.derniere_maj_live)
	var entree := {"minute": mi, "cote": cote, "score": SoireeMatch.cle_but(score)}
	if not simule:
		var e := Game.soiree_de(_id)
		e["fil"].append(entree)
		e["fil"] = (e["fil"] as Array).slice(-20)
		Game.sauver()
	_ajouter_fil(entree)
	var nom: String = (fiche["dom"] if cote == "home" else fiche["ext"])["nom"]
	ferveur = clampf(ferveur + (SoireeMatch.FERVEUR_BUT if pour_nous else SoireeMatch.FERVEUR_BUT_ADVERSE), 0.0, 100.0)
	if pour_nous:
		_decor.confettis(260)
		_sons.jouer("clameur_but")
		_sons.jouer("corne", {"volume_db": -4.0})
		for mar in _fanzzy:
			mar.sauter(1.6, _rng.randf() * 0.2)
			mar.geste(&"celebrer", 2.6)
		_annoncer_but(tr("BUT !!! %s") % nom.to_upper(), score, Ui.JAUNE)
	else:
		_decor.secousse_eux = 1.0
		_sons.jouer("deception")
		for mar in _fanzzy:
			mar.geste(&"depit", 2.4)
		_annoncer_but(tr("But de %s…") % nom, score, Ui.ROSE)
	var but := {"cote": cote, "pour_nous": pour_nous, "cle": SoireeMatch.cle_but(score)}
	if etat == "fin":
		return
	if etat == "attente":
		_but = but
		_changer_etat("celebration")
	else:
		_file.append(but)


## Grand titre au centre quand rien ne s'y joue ; sinon un bandeau, pour ne pas
## couper la mini-ambiance en cours (le but attendra son tour).
func _annoncer_but(titre: String, score: Vector2i, couleur: Color) -> void:
	var sous := "%s %s %s" % [fiche["dom"]["sigle"], _lbl_score_texte(score), fiche["ext"]["sigle"]]
	if etat == "attente":
		_grande_annonce(titre, sous, couleur)
	else:
		_annonce("%s  %s" % [titre, sous], couleur)


static func _lbl_score_texte(sc: Vector2i) -> String:
	return "%d – %d" % [sc.x, sc.y]


## Après une mini-ambiance (ou un choix raté) : le but suivant en attente, ou le calme.
func _suivant() -> void:
	_vider_centre()
	if not _file.is_empty():
		_but = _file.pop_front()
		_ouvrir_choix()
		return
	_but = {}
	_changer_etat("attente")


func _vider_centre() -> void:
	for c in _centre.get_children():
		c.queue_free()
	_piste = null
	_karaoke = null
	_tifo = null
	_barre_temps = null
	_ola_fleches.clear()


func _panneau_centre(largeur := 1000.0, hauteur := 340.0) -> VBoxContainer:
	_vider_centre()
	var pan := Ui.panneau(Ui.NUIT, 28, 6)
	pan.position = Vector2(960 - largeur / 2.0, 250)
	pan.size = Vector2(largeur, hauteur)
	pan.custom_minimum_size = Vector2(largeur, hauteur)
	_centre.add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	Ui.pop(pan, 1.08)
	return v


func _ouvrir_choix() -> void:
	_changer_etat("choix")
	var v := _panneau_centre(1060, 360)
	var pour_nous: bool = _but.get("pour_nous", true)
	var t := Ui.label("À toi de lancer l'ambiance !" if pour_nous else "Relève la tribune !", 44, Ui.JAUNE if pour_nous else Ui.ROSE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := Ui.label(_texte_gains_possibles(), 19, Ui.GRIS)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(st)
	var h := Ui.hbox(18)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	var couleurs := [Ui.JAUNE, Ui.ROSE, Ui.VERT]
	for i in SoireeMatch.AMBIANCES.size():
		var a: Dictionary = SoireeMatch.AMBIANCES[i]
		var b := Ui.bouton("%s\n[%s]" % [tr(a["titre"]).to_upper(), a["touche"]], couleurs[i], 28)
		Ui.colorer_bouton(b, couleurs[i], true)
		b.custom_minimum_size = Vector2(310, 110)
		b.focus_mode = Control.FOCUS_NONE
		b.tooltip_text = tr(a["texte"])
		var id: String = a["id"]
		b.pressed.connect(func(): _lancer_ambiance(id))
		h.add_child(b)
	_barre_temps = _barre(SoireeMatch.DUREE_CHOIX, Ui.JAUNE)
	v.add_child(_barre_temps)


func _texte_gains_possibles() -> String:
	if simule:
		return tr("Démo : pour le plaisir, sans Jetons")
	if not SoireeMatch.peut_recompenser(Game.soiree_de(_id), str(_but.get("cle", ""))):
		return tr("Ce but a déjà rapporté (ou 6 buts récompensés) : pour le plaisir")
	return tr("Réussis-la pour gagner des Jetons · ferveur x%.2f") % SoireeMatch.mult_ferveur(ferveur)


func _barre(maxi_v: float, couleur: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.max_value = maxi_v
	b.value = maxi_v
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, 16)
	b.add_theme_stylebox_override("background", Ui.boite(Ui.CONTOUR, 8, 0))
	b.add_theme_stylebox_override("fill", Ui.boite(couleur, 8, 0))
	return b


func _lancer_ambiance(id: String) -> void:
	if etat != "choix":
		return
	_sons.jouer("ui_clic")
	match id:
		"chant":
			_lancer_chant()
		"tifo":
			_lancer_tifo()
		"ola":
			_lancer_ola()


func _finir_ambiance(perf: float) -> void:
	if not etat in ["chant", "tifo", "ola"]:
		return
	var type := etat
	_lecteur.arreter()
	_changer_etat("resultat")
	_nb_ambiances += 1
	perf = clampf(perf, 0.0, 1.0)
	var pour_nous: bool = _but.get("pour_nous", true)
	var r: Dictionary = {}
	if not simule:
		r = Game.recompenser_but_soiree(fiche["m"], str(_but.get("cle", "")), perf, pour_nous, mode, ferveur)
		for k in _gains:
			_gains[k] += int(r.get(k, 0))
	ferveur = clampf(ferveur + 25.0 * perf, 0.0, 100.0)
	var etoiles := SoireeMatch.etoiles(perf)
	# la tribune suit
	match type:
		"tifo":
			if etoiles > 0:
				_banniere.sous = tr("BUT !") if pour_nous else tr("ON Y CROIT !")
				_banniere.deployer()
				_sons.jouer("tifo")
		"ola":
			if etoiles > 0:
				_decor.lancer_ola()
				_sons.jouer("ola")
		"chant":
			if etoiles > 0:
				_sons.jouer("applaudissements")
	for mar in _fanzzy:
		mar.geste(&"celebrer" if etoiles >= 2 else (&"lever_bras" if etoiles == 1 else &"depit"), 2.5)
	if etoiles >= 2:
		_decor.confettis(80 * etoiles)

	var v := _panneau_centre(820, 300)
	var titres := ["Raté… la tribune n'a pas suivi", "Pas mal !", "Belle ambiance !", "TRIBUNE EN FEU !"]
	var t := Ui.label(titres[etoiles], 44, Ui.JAUNE if etoiles >= 2 else Ui.BLANC, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var e := Ui.label("★".repeat(etoiles) + "☆".repeat(3 - etoiles), 54, Ui.JAUNE, true, 8)  # sans_traduction
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(e)
	var g := Ui.hbox(18)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	if r.is_empty():
		g.add_child(Ui.label("Pour le plaisir" if not simule else "Démo : sans Jetons", 24, Ui.GRIS, true))
	else:
		g.add_child(Ui.icone("jeton", 30))
		g.add_child(Ui.label("+%d" % int(r["jetons"]), 30, Ui.JAUNE, true))
		g.add_child(Ui.label(tr("XP +%d") % int(r["xp"]), 24, Ui.BLANC, true))
		g.add_child(Ui.label(tr("PASS +%d") % int(r["xp_pass"]), 24, Ui.VERT, true))
	v.add_child(g)


# ------------------------------------------------------------------ chant

func _lancer_chant() -> void:
	_changer_etat("chant")
	var c: Dictionary = Game.params.get("chant", Game.chant_club())
	if c.is_empty():
		c = ChantClub.par_defaut()
	var court := c.duplicate(true)
	court["mesures"] = (c.get("mesures", []) as Array).slice(0, SoireeMatch.MESURES_CHANT)
	_programme = ChantClub.programme(court, Game.fan_club_nom)
	_lecteur.lancer(ChantClub.vers_fiche(court, false), 0.0, 1, 1.4)
	_chant_stats = {"parfaits": 0, "biens": 0, "total": _lecteur.notes.size()}
	var v := _panneau_centre(1100, 330)
	var t := Ui.label(tr("Chant : « %s »") % tr(String(c.get("nom", ""))), 30, Ui.JAUNE, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_karaoke = RichTextLabel.new()
	_karaoke.bbcode_enabled = true
	_karaoke.scroll_active = false
	_karaoke.fit_content = true
	_karaoke.autowrap_mode = TextServer.AUTOWRAP_OFF
	_karaoke.custom_minimum_size = Vector2(1040, 60)
	_karaoke.add_theme_font_override("normal_font", Ui.police_titre())
	_karaoke.add_theme_font_size_override("normal_font_size", 40)
	_karaoke.add_theme_constant_override("outline_size", 10)
	_karaoke.add_theme_color_override("font_outline_color", Ui.CONTOUR)
	_karaoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_karaoke)
	_piste = PisteChant.new()
	_piste.lecteur = _lecteur
	_piste.custom_minimum_size = Vector2(1040, 110)
	_piste.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.is_pressed() and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_lecteur.juger_appui())
	v.add_child(_piste)
	var aide := Ui.label("ESPACE (ou clic) quand la note arrive dans le cercle", 18, Ui.GRIS)
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(aide)
	for mar in _fanzzy:
		mar.geste(&"chanter", 30.0)


func _sur_appui_chant(r: Dictionary) -> void:
	if etat != "chant":
		return
	match String(r["note"]):
		"parfait":
			_chant_stats["parfaits"] += 1
			_sons.jouer("clap")
			if _piste:
				_piste.eclat(tr("PARFAIT"), Ui.JAUNE)
		"bien":
			_chant_stats["biens"] += 1
			_sons.jouer("clap", {"volume_db": -4.0})
			if _piste:
				_piste.eclat(tr("BIEN"), Ui.VERT)
		_:
			if _piste:
				_piste.eclat(tr("RATÉ"), Ui.ROUGE)


func _maj_karaoke() -> void:
	if _karaoke == null or _programme.is_empty():
		return
	var t := _lecteur.temps_entendu()
	var n := 0
	var mesure := 0
	var en_cours := -1
	# la note en cours (la dernière passée), et la mesure qui la contient
	for k in _lecteur.notes.size():
		if _lecteur.notes[k] <= t + 0.05:
			en_cours = k
	var debut := 0
	for i in _programme.size():
		var nb: int = (_programme[i]["appuis"] as Array).size()
		if en_cours < n + nb or i == _programme.size() - 1:
			mesure = i
			debut = n
			break
		n += nb
	var mots: Array = _programme[mesure]["mots"]
	var parts: Array = []
	for k in mots.size():
		if String(mots[k]) == "":
			continue
		var c := "#ffd23f" if debut + k == en_cours else ("#ffffff" if debut + k < en_cours else "#b9b5e0")
		parts.append("[color=%s]%s[/color]" % [c, mots[k]])  # sans_traduction
	_karaoke.text = "[center]%s[/center]" % " ".join(parts)  # sans_traduction


# ------------------------------------------------------------------ tifo

func _lancer_tifo() -> void:
	_changer_etat("tifo")
	var v := _panneau_centre(900, 360)
	var t := Ui.label("Tifo : maintiens T, relâche dans la zone dorée", 30, Ui.JAUNE, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_tifo = JaugeTifo.new()
	_tifo.couleurs = [_decor.c_nous, Color(_decor.c_nous2)]
	_tifo.custom_minimum_size = Vector2(840, 220)
	_tifo.preparer(_rng)
	_tifo.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			_tifo_tenir(ev.is_pressed()))
	v.add_child(_tifo)
	var aide := Ui.label("ou maintiens le clic sur le tifo", 18, Ui.GRIS)
	aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(aide)


func _tifo_tenir(oui: bool) -> void:
	if etat != "tifo" or _tifo == null:
		return
	var avant := _tifo.ecarts.size()
	_tifo.tenir(oui)
	if _tifo.ecarts.size() > avant:
		var e: float = absf(float(_tifo.ecarts[-1]))
		if e < 0.08:
			_sons.jouer("ui_parfait")
			_fanzzy[1].sauter(1.0)
		elif e < 0.3:
			_sons.jouer("ui_bien")
		else:
			_sons.jouer("ui_rate")


# ------------------------------------------------------------------ ola

func _lancer_ola() -> void:
	_changer_etat("ola")
	_ola_seq.clear()
	for i in SoireeMatch.FLECHES_OLA:
		_ola_seq.append(_rng.randi() % 4)
	_ola_i = 0
	_ola_err = 0
	_ola_reste = SoireeMatch.DUREE_OLA
	var v := _panneau_centre(900, 320)
	var t := Ui.label("Ola : enchaîne les flèches !", 34, Ui.JAUNE, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := Ui.hbox(14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	for d in _ola_seq:
		var f := Duel.Fleche.new()
		f.direction = d
		f.custom_minimum_size = Vector2(110, 110)
		# au doigt ou à la souris : toucher une flèche = sa direction (comme en duel)
		f.mouse_filter = Control.MOUSE_FILTER_STOP
		var dd: int = d
		f.gui_input.connect(func(e: InputEvent):
			if e is InputEventMouseButton and e.pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
				_ola_touche(dd))
		h.add_child(f)
		_ola_fleches.append(f)
	_barre_temps = _barre(SoireeMatch.DUREE_OLA, Ui.VERT)
	v.add_child(_barre_temps)


func _ola_touche(d: int) -> void:
	if etat != "ola" or _ola_i >= _ola_seq.size():
		return
	if d == _ola_seq[_ola_i]:
		var f: Control = _ola_fleches[_ola_i]
		f.validee = true
		f.queue_redraw()
		Ui.pop(f, 1.2)
		_sons.jouer("ui_bien")
		_ola_i += 1
		if _ola_i >= _ola_seq.size():
			_finir_ola()
	else:
		_ola_err += 1
		_sons.jouer("ui_rate")


func _finir_ola() -> void:
	_finir_ambiance(SoireeMatch.perf_ola(_ola_i, _ola_err, _ola_reste))


# ------------------------------------------------------------------ réactions

func _reagir(id: String) -> void:
	if etat == "fin" or _recharges.has(id):
		return
	for r in SoireeMatch.REACTIONS:
		if r["id"] != id:
			continue
		ferveur = clampf(ferveur + float(r["ferveur"]), 0.0, 100.0)
		_recharges[id] = float(r["recharge"])
		(_boutons_reac[id] as Button).disabled = true
		_sons.jouer(String(r["son"]), {"volume_db": -3.0})
		for i in _fanzzy.size():
			_fanzzy[i].geste(r["action"], 1.8, i * 0.08)
		if id == "allez":
			for mar in _fanzzy:
				mar.sauter(0.6, _rng.randf() * 0.15)


# ------------------------------------------------------------------ fil des buts

func _remplir_fil() -> void:
	for c in _fil.get_children():
		c.queue_free()
	var fil: Array = [] if simule else Game.soiree_de(_id)["fil"]
	if fil.is_empty():
		_fil.add_child(_vide_fil())
	for e in fil:
		_ajouter_fil(e)


func _vide_fil() -> Label:
	var l := Ui.label("Pas encore de but vécu ce soir.", 17, Ui.GRIS)
	l.name = "Vide"  # sans_traduction
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	return l


func _ajouter_fil(e: Dictionary) -> void:
	var vide := _fil.get_node_or_null("Vide")  # sans_traduction
	if vide:
		vide.free()
	var cote := str(e.get("cote", "home"))
	var pour_nous := cote == camp
	var eq: Dictionary = fiche["dom"] if cote == "home" else fiche["ext"]
	var h := Ui.hbox(8)
	var mi := int(e.get("minute", -1))
	h.add_child(Ui.pastille("%d'" % mi if mi >= 0 else "–", Ui.VERT if pour_nous else Ui.ROUGE, 16, pour_nous))
	var l := Ui.label("%s · %s" % [eq["sigle"], str(e.get("score", "")).replace("-", " – ")], 20, Ui.BLANC, true)
	h.add_child(l)
	_fil.add_child(h)
	while _fil.get_child_count() > 9:
		_fil.get_child(0).free()


# ------------------------------------------------------------------ annonces

func _annonce(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 38, couleur, true, 10)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -700
	l.offset_right = 700
	l.offset_top = 196
	l.offset_bottom = 246
	l.pivot_offset = Vector2(700, 25)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	Ui.pop(l, 1.2, 0.25)
	var t := l.create_tween()
	t.tween_interval(2.2)
	t.tween_property(l, "modulate:a", 0.0, 0.4)
	t.tween_callback(l.queue_free)


func _grande_annonce(titre: String, sous: String, couleur: Color) -> void:
	_vider_centre()
	var v := Ui.vbox(4)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.offset_left = -800
	v.offset_right = 800
	v.offset_top = -200
	v.offset_bottom = 40
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.pivot_offset = Vector2(800, 120)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_centre.add_child(v)
	var t := Ui.label(titre, 96, couleur, true, 18)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Ui.label(sous, 52, Ui.BLANC, true, 12)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	v.scale = Vector2.ONE * 0.3
	var tw := v.create_tween()
	tw.tween_property(v, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ fin

func _fin_du_match() -> void:
	if etat == "fin":
		return
	_lecteur.arreter()
	_file.clear()
	_changer_etat("fin")
	_sons.jouer("sifflet_fin")
	var prime: Dictionary = {} if simule else Game.prime_fin_soiree(fiche["m"], mode)
	for k in _gains:
		_gains[k] += int(prime.get(k, 0))
	var sc := SoireeMatch.score_de(fiche["m"])
	var b := sc if camp == "home" else Vector2i(sc.y, sc.x)
	var gagne := b.x > b.y
	for mar in _fanzzy:
		mar.geste(&"celebrer" if gagne else (&"applaudir" if b.x == b.y else &"depit"), 30.0)
	if gagne:
		_decor.confettis(300)
	var v := _panneau_centre(860, 470)
	var t := Ui.label("COUP DE SIFFLET FINAL", 46, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var s := Ui.label("%s %s %s" % [fiche["dom"]["sigle"], _lbl_score_texte(sc) if sc.x >= 0 else "–", fiche["ext"]["sigle"]], 40, Ui.BLANC, true, 8)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(s)
	var nb_buts: int = 0 if simule else (Game.soiree_de(_id)["fil"] as Array).size()
	var lignes := [
		["Buts vécus en direct", str(nb_buts)],
		["Mini-ambiances lancées", str(_nb_ambiances)],
		["Jetons gagnés ce soir", "+%d" % _gains["jetons"]],
		["XP du fan club", "+%d" % _gains["xp"]],
		["XP du PASS", "+%d" % _gains["xp_pass"]],
	]
	if not prime.is_empty():
		lignes.append(["Prime « soirée complète » comprise", "+%d" % int(prime["jetons"])])
	for l in lignes:
		var h := Ui.hbox(10)
		var a := Ui.label(l[0], 22, Ui.BLANC)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Ui.label(l[1], 24, Ui.JAUNE, true))
		v.add_child(h)
	var retour := Ui.bouton("Retour à la carte", Ui.BLEU, 28)
	retour.custom_minimum_size = Vector2(380, 80)
	retour.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retour.pressed.connect(_retour_carte)
	v.add_child(retour)


func _retour_carte() -> void:
	var p: Dictionary = Game.params
	Game.aller(Game.SCENE_CARTE, {"niveau": p.get("niveau", "monde"), "continent": p.get("continent", ""), "pays": p.get("pays", "")})


func _ouvrir_pause() -> void:
	if _pause:
		_pause.queue_free()
		_pause = null
		return
	if etat == "fin":
		_retour_carte()
		return
	_pause = ColorRect.new()
	(_pause as ColorRect).color = Color(0.05, 0.03, 0.15, 0.6)
	_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_pause)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -380
	pan.offset_right = 380
	pan.offset_top = -160
	pan.offset_bottom = 160
	_pause.add_child(pan)
	var v := Ui.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label("Quitter la soirée ?", 44, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := Ui.label("Le match continue. Les Jetons déjà gagnés restent à toi.", 22, Ui.BLANC)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(st)
	var hb := Ui.hbox(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var rester := Ui.bouton("Rester", Ui.VERT, 30)
	Ui.colorer_bouton(rester, Ui.VERT, true)
	rester.custom_minimum_size = Vector2(260, 84)
	rester.pressed.connect(_ouvrir_pause)
	hb.add_child(rester)
	var partir := Ui.bouton("Quitter", Ui.ROSE, 30)
	partir.custom_minimum_size = Vector2(260, 84)
	partir.pressed.connect(_retour_carte)
	hb.add_child(partir)
	v.add_child(hb)
	rester.grab_focus.call_deferred()


# ------------------------------------------------------------------ clavier

func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		_ouvrir_pause()
		get_viewport().set_input_as_handled()
		return
	if _pause:
		return
	if not ev is InputEventKey or ev.is_echo():
		return
	var k := (ev as InputEventKey).keycode
	if etat == "tifo" and k == KEY_T:
		_tifo_tenir(ev.is_pressed())
		get_viewport().set_input_as_handled()
		return
	if not ev.is_pressed():
		return
	if etat == "ola":
		for i in FLECHES.size():
			if ev.is_action(FLECHES[i]):
				_ola_touche(i)
				get_viewport().set_input_as_handled()
				return
	match etat:
		"choix":
			match k:
				KEY_SPACE:
					_lancer_ambiance("chant")
				KEY_T:
					_lancer_ambiance("tifo")
				KEY_O:
					_lancer_ambiance("ola")
		"chant":
			if k in [KEY_SPACE, KEY_J, KEY_F]:
				_lecteur.juger_appui()
		"attente":
			# chiffres : touche physique (en AZERTY, « 1 » sans Maj donne « & »)
			match (ev as InputEventKey).physical_keycode:
				KEY_1, KEY_KP_1:
					_reagir("allez")
				KEY_2, KEY_KP_2:
					_reagir("applaudir")
				KEY_3, KEY_KP_3:
					_reagir("echarpe")
	if simule and etat != "fin":
		if k == KEY_B:
			_simuler_but(true)
		elif k == KEY_N:
			_simuler_but(false)
	get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ dessins

## La piste du chant : les notes du lecteur glissent vers le cercle.
class PisteChant extends Control:
	const HORIZON := 1.8
	var lecteur: ChantLecteur
	var _eclat_txt := ""
	var _eclat_col := Ui.BLANC
	var _eclat_fin := 0

	func eclat(t: String, c: Color) -> void:
		_eclat_txt = t
		_eclat_col = c
		_eclat_fin = Time.get_ticks_msec() + 500

	func _draw() -> void:
		draw_style_box(Ui.boite(Color(0.08, 0.06, 0.2, 0.8), 50, 5), Rect2(Vector2.ZERO, size))
		var cible := Vector2(90, size.y / 2.0)
		var allume := Time.get_ticks_msec() < _eclat_fin
		draw_circle(cible, 46, Ui.CONTOUR)
		draw_circle(cible, 40, _eclat_col if allume else Ui.BLANC.darkened(0.1))
		if lecteur == null or not lecteur.en_cours:
			return
		var t := lecteur.temps_entendu()
		var vitesse := (size.x - cible.x - 40) / HORIZON
		for n in lecteur.notes_a_venir(HORIZON):
			var x: float = cible.x + (float(n["t"]) - t) * vitesse
			draw_circle(Vector2(x, cible.y), 34, Ui.CONTOUR)
			draw_circle(Vector2(x, cible.y), 28, Ui.ROSE)
			draw_circle(Vector2(x - 8, cible.y - 8), 8, Color(1, 1, 1, 0.6))
		if allume:
			var f := Ui.police_titre()
			draw_string_outline(f, cible + Vector2(70, 16), _eclat_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, 10, Ui.CONTOUR)
			draw_string(f, cible + Vector2(70, 16), _eclat_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 40, _eclat_col)


## Le tifo en 3 pans : on maintient pour lever le pan, on relâche dans la zone dorée.
class JaugeTifo extends Control:
	const VITESSE := 0.62        # hauteur (0..1) gagnée par seconde tenue
	const DUREE_MAX := 14.0      # au-delà, les pans restants sont ratés
	var couleurs: Array = [Ui.BLEU, Ui.BLANC]
	var cibles: Array = []
	var ecarts: Array = []
	var valeur := 0.0
	var tenu := false
	var _t := 0.0

	func preparer(rng: RandomNumberGenerator) -> void:
		cibles.clear()
		for i in SoireeMatch.PANS_TIFO:
			cibles.append(rng.randf_range(0.6, 0.86))

	func pan() -> int:
		return ecarts.size()

	func termine() -> bool:
		return ecarts.size() >= SoireeMatch.PANS_TIFO

	func tenir(oui: bool) -> void:
		if termine():
			return
		if oui:
			tenu = true
		elif tenu:
			tenu = false
			_juger()

	func _juger() -> void:
		ecarts.append(valeur - float(cibles[pan()]))
		valeur = 0.0

	func avancer(delta: float) -> void:
		_t += delta
		if termine():
			return
		if _t > DUREE_MAX:
			while not termine():
				ecarts.append(1.0)
			return
		if tenu:
			valeur += VITESSE * delta
			if valeur >= 1.0:
				valeur = 1.0
				tenu = false
				_juger()  # trop haut : le pan s'emmêle
		queue_redraw()

	func _draw() -> void:
		var n := SoireeMatch.PANS_TIFO
		var l := size.x / n
		for i in n:
			var r := Rect2(Vector2(i * l + 14, 0), Vector2(l - 28, size.y))
			draw_style_box(Ui.boite(Ui.CONTOUR, 16, 0), r)
			var interieur := r.grow(-6)
			var c: float = cibles[i] if i < cibles.size() else 0.75
			# zone dorée
			var zh := interieur.size.y * 0.16
			var zy := interieur.end.y - interieur.size.y * c - zh / 2.0
			draw_rect(Rect2(interieur.position.x, zy, interieur.size.x, zh), Color(Ui.JAUNE, 0.35))
			draw_line(Vector2(interieur.position.x, zy + zh / 2.0), Vector2(interieur.end.x, zy + zh / 2.0), Ui.JAUNE, 3)
			var h := 0.0
			if i < ecarts.size():
				h = clampf(c + float(ecarts[i]), 0.0, 1.0)
			elif i == ecarts.size():
				h = valeur
			if h > 0.0:
				var fr := Rect2(interieur.position.x, interieur.end.y - interieur.size.y * h, interieur.size.x, interieur.size.y * h)
				draw_rect(fr, couleurs[i % 2])
				for k in 4:
					draw_rect(Rect2(fr.position.x, fr.position.y + k * fr.size.y / 4.0, fr.size.x, fr.size.y / 8.0), Color(couleurs[(i + 1) % 2], 0.25))
			if i < ecarts.size():
				var e := absf(float(ecarts[i]))
				var txt := Trad.t("PILE !") if e < 0.08 else (Trad.t("BIEN") if e < 0.3 else Trad.t("RATÉ"))
				var f := Ui.police_titre()
				var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
				var p := Vector2(r.get_center().x - w / 2.0, r.position.y + 40)
				draw_string_outline(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, 8, Ui.CONTOUR)
				draw_string(f, p, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Ui.JAUNE if e < 0.08 else (Ui.VERT if e < 0.3 else Ui.ROUGE))
