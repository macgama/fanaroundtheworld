class_name Speaker
extends Control
## Petit boulot de supporter : speaker du stade (un match d'environ une minute).
##   1 à 4 (ou clic) : annoncer ce joueur, sur le 1er temps de la mesure
## À chaque but des locaux, l'écran géant montre le numéro du buteur. On
## retrouve son nom sur la feuille de match et on l'annonce dans le tempo :
## le speaker crie le prénom, la tribune répond le nom, trois fois.
## But des visiteurs : on reste sobre, aucune annonce.
## Règles dans SpeakerRegles. Option « --auto » (tests, captures) : le match
## se joue tout seul.

const SonsScript := preload("res://scripts/audio/sons.gd")

const ECRAN := Rect2(560, 118, 800, 372)      # l'écran géant du stade
const PISTE_Y := 600.0
const PISTE_X0 := 470.0                        # la cible (le micro)
const PISTE_X1 := 1870.0
const VITESSE := 520.0                         # pixels par seconde sur la piste
const DEPART := 1.2                            # secondes avant le premier but
const ROUGE_VISITEURS := Color("#9aa0b8")

var regles := SpeakerRegles.new()
var auto := "--auto" in OS.get_cmdline_user_args()
var pret := false
var termine := false

var feuille: Array = []
var buts: Array = []
var chronos: Array = []        # par but : SpeakerRegles.chronologie
var appels: Array = []         # [{t, but, note}] dans l'ordre
var score := [0, 0]
var but_courant := -1
var paye_appels := 0
var bonus := 0
var silences := 0
var fautes := 0
var annonces_justes := 0
var buts_annonces := 0
var serie := 0
var serie_max := 0

var _depart_us := 0
var _frappes: Array = []
var _prochaine_frappe := 0
var _prochain_but := 0
var _appel_ouvert := 0
var _reponses: Array = []      # [{t, appel}]
var _prochaine_reponse := 0
var _faute_visiteurs := false
var _auto_appuis: Array = []   # [{t, slot}]
var _sons: Node
var _ids_fanzzy: Array = []
var _bat := 0.0                # dernier temps fort (pour faire sauter la tribune)

var _decor: Decor
var _personnages: Node2D
var _buteur: FanzzyAnime
var _speaker: FanzzyAnime
var _dessus: Dessus
var _boutons: Array = []       # 4 boutons (par place à l'écran)
var _ordre: Array = [0, 1, 2, 3]
var _lbl_score: Label
var _lbl_but: Label
var _lbl_paye: Label
var _lbl_serie: Label
var _bulle_speaker: PanelContainer
var _lbl_speaker: Label
var _bulle_tribune: PanelContainer
var _lbl_tribune: Label
var _lbl_ecran: Label
var _lbl_info: Label


func _ready() -> void:
	_sons = SonsScript.new()
	_sons.name = "Sons"
	add_child(_sons)
	feuille = regles.feuille_de_match()
	buts = regles.programme()
	_ids_fanzzy = Buvette.ids_clients()
	_ids_fanzzy.shuffle()
	_construire()
	_sons.ambiance("stade", 1)
	_compte_a_rebours()


# ------------------------------------------------------------------ construction

func _construire() -> void:
	_decor = Decor.new()
	_decor.jeu = self
	_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_decor)
	_personnages = Node2D.new()
	add_child(_personnages)
	_dessus = Dessus.new()
	_dessus.jeu = self
	_dessus.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dessus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dessus)

	# --- le speaker (le premier FANZZY de ta tribune), micro en main
	var id_speaker: String = str(Game.equipe[0]) if not Game.equipe.is_empty() else ""
	_speaker = FanzzyAnime.creer(id_speaker)
	_personnages.add_child(_speaker)
	_speaker.scale = Vector2.ONE * Buvette.echelle(_speaker, 300.0)
	_speaker.position = Vector2(215, 1050)
	_speaker.couleurs_echarpe = PackedColorArray(Game.couleurs_club())
	_speaker.jouer(&"repos")

	# --- texte de l'écran géant
	_lbl_ecran = Ui.label("", 64, Ui.BLANC, true, 12)
	_lbl_ecran.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_ecran.position = ECRAN.position + Vector2(0, 22)
	_lbl_ecran.size = Vector2(ECRAN.size.x, 80)
	add_child(_lbl_ecran)

	# --- haut : quitter, but n°, score, série, paye
	var haut := Ui.hbox(16)
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 28
	haut.offset_right = -28
	haut.offset_top = 18
	add_child(haut)
	var quitter := Ui.bouton("Quitter", Ui.NUIT_CLAIR, 24)
	quitter.tooltip_text = "Rendre le micro sans finir le match (pas de paye)"
	quitter.custom_minimum_size = Vector2(170, 70)
	quitter.focus_mode = Control.FOCUS_NONE
	quitter.pressed.connect(_retour)
	haut.add_child(quitter)
	var pb := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_but = Ui.label(tr("But 0/%d") % SpeakerRegles.NB_BUTS, 30, Ui.BLANC, true, 6)
	pb.add_child(_lbl_but)
	haut.add_child(pb)
	haut.add_child(Ui.espace())
	var psc := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_score = Ui.label("", 30, Ui.BLANC, true, 6)
	psc.add_child(_lbl_score)
	haut.add_child(psc)
	haut.add_child(Ui.espace())
	var ps := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_serie = Ui.label("Série x0", 30, Ui.BLANC, true, 6)
	ps.add_child(_lbl_serie)
	ps.tooltip_text = "Annonces justes d'affilée"
	haut.add_child(ps)
	var pj := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 40))
	_lbl_paye = Ui.label("0", 34, Ui.JAUNE, true, 6)
	hj.add_child(_lbl_paye)
	pj.add_child(hj)
	pj.tooltip_text = "Paye du match (versée à la fin)"
	haut.add_child(pj)
	_maj_score()

	# --- bulles : le speaker crie le prénom, la tribune répond le nom
	_bulle_speaker = _bulle(Ui.BLANC)
	_bulle_speaker.position = Vector2(40, 420)
	_lbl_speaker = _bulle_speaker.get_child(0)
	_bulle_tribune = _bulle(Ui.JAUNE)
	_bulle_tribune.position = Vector2(1420, 150)
	_lbl_tribune = _bulle_tribune.get_child(0)

	# --- bas : la feuille de match (4 joueurs)
	var titre := Ui.label("FEUILLE DE MATCH  ·  touche 1 à 4 sur le temps du micro", 22, Ui.GRIS, true)
	titre.position = Vector2(470, 690)
	add_child(titre)
	var bas := Ui.hbox(18)
	bas.position = Vector2(470, 730)
	bas.size = Vector2(1400, 230)
	add_child(bas)
	for place in SpeakerRegles.NB_JOUEURS:
		var b := _bouton_joueur(place)
		bas.add_child(b)
		_boutons.append(b)
	_lbl_info = Ui.label("Retrouve le numéro du buteur et annonce-le quand la note touche le micro.", 22, Ui.GRIS)
	_lbl_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_info.offset_left = -500
	_lbl_info.offset_right = 900
	_lbl_info.offset_top = -64
	_lbl_info.offset_bottom = -24
	add_child(_lbl_info)
	_maj_boutons()


func _bulle(fond: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var s := Ui.boite(fond, 26, 6, 8)
	s.content_margin_left = 22
	s.content_margin_right = 22
	p.add_theme_stylebox_override("panel", s)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.visible = false
	var l := Ui.label("", 56, Ui.CONTOUR, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	add_child(p)
	return p


func _bouton_joueur(place: int) -> Button:
	var b := Ui.bouton("", Ui.NUIT_CLAIR, 26)
	b.custom_minimum_size = Vector2(335, 220)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tr("Annoncer ce joueur (touche %d)") % (place + 1)
	b.pressed.connect(annoncer.bind(place))
	var v := Ui.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var num := Ui.label("", 84, Ui.BLANC, true, 12)
	num.name = "Numero"  # sans_traduction
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(num)
	var nom := Ui.label("", 28, Ui.BLANC, true, 6)
	nom.name = "Nom"  # sans_traduction
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nom)
	var touche := Ui.pastille(str(place + 1), Ui.CONTOUR, 18)
	touche.position = Vector2(14, 12)
	touche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(touche)
	return b


func _maj_boutons() -> void:
	var c: Array = Game.couleurs_club()
	for place in _boutons.size():
		var j: Dictionary = feuille[_ordre[place]]
		var b: Button = _boutons[place]
		var num: Label = b.find_child("Numero", true, false)  # sans_traduction
		var nom: Label = b.find_child("Nom", true, false)  # sans_traduction
		num.text = str(j["numero"])
		nom.text = "%s %s" % [j["prenom"], String(j["nom"]).to_upper()]
		Ui.colorer_bouton(b, Color(c[0]).darkened(0.15))


# ------------------------------------------------------------------ déroulé

func _compte_a_rebours() -> void:
	_lbl_ecran.text = "AU MICRO !"
	var l := Ui.label("3", 200, Ui.JAUNE, true, 24)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.offset_top = -80
	add_child(l)
	for t in ["3", "2", "1", "COUP D'ENVOI !"]:
		l.text = t
		l.pivot_offset = l.size / 2.0
		Ui.pop(l, 1.4, 0.3)
		_sons.jouer("ui_decompte_go" if t.length() > 1 else "ui_decompte")
		await get_tree().create_timer(0.7).timeout
	l.queue_free()
	_sons.jouer("sifflet_court")
	_lbl_ecran.text = ""
	_preparer_programme()
	_depart_us = Time.get_ticks_usec()
	pret = true


## Toute la chronologie du match, dès le départ (l'horloge est celle du système).
func _preparer_programme() -> void:
	var t := DEPART
	for i in buts.size():
		var c := SpeakerRegles.chronologie(buts[i], t)
		c["debut"] = t
		chronos.append(c)
		for f in c["frappes"]:
			var f2: Dictionary = f.duplicate()
			f2["but"] = i
			_frappes.append(f2)
		for k in c["appels"].size():
			appels.append({"t": c["appels"][k], "but": i, "note": ""})
			_reponses.append({"t": c["reponses"][k], "appel": appels.size() - 1})
			if auto:
				var juste := randf() > 0.08
				var slot: int = buts[i]["ordre"].find(buts[i]["buteur"])
				if not juste:
					slot = (slot + 1) % SpeakerRegles.NB_JOUEURS
				_auto_appuis.append({"t": c["appels"][k] + randf_range(-0.05, 0.07), "slot": slot})
		t = c["fin"] + SpeakerRegles.PAUSE_ENTRE_BUTS
	_frappes.sort_custom(func(a, b): return a["t"] < b["t"])


func horloge() -> float:
	if not pret:
		return 0.0
	return float(Time.get_ticks_usec() - _depart_us) / 1_000_000.0


## L'instant que le joueur entend (la latence de sortie retranchée).
func horloge_entendue() -> float:
	return horloge() - Rythme.latence_sortie()


func _process(_delta: float) -> void:
	_decor.queue_redraw()
	_dessus.queue_redraw()
	if not pret or termine:
		return
	var t := horloge()
	var te := horloge_entendue()
	# un nouveau but
	while _prochain_but < buts.size() and t >= float(chronos[_prochain_but]["debut"]):
		_debut_but(_prochain_but)
		_prochain_but += 1
	# les sons dus (la réponse de la tribune dépend de l'annonce)
	while _prochaine_frappe < _frappes.size() and _frappes[_prochaine_frappe]["t"] <= t:
		var f: Dictionary = _frappes[_prochaine_frappe]
		_prochaine_frappe += 1
		if t - float(f["t"]) > 0.12:
			continue
		if f["son"] == "cri_groupe":
			continue  # joué par _reponse_tribune
		if f["son"] == "tambour" and f["force"] >= 1.0:
			_bat = t
		_sons.jouer(f["son"], {"volume_db": linear_to_db(maxf(float(f["force"]), 0.05))})
	while _prochaine_reponse < _reponses.size() and _reponses[_prochaine_reponse]["t"] <= t:
		_reponse_tribune(_reponses[_prochaine_reponse]["appel"])
		_prochaine_reponse += 1
	# les appels passés sans annonce
	var limite := Rythme.FENETRE_BIEN
	while _appel_ouvert < appels.size() and appels[_appel_ouvert]["t"] < te - limite:
		if appels[_appel_ouvert]["note"] == "":
			appels[_appel_ouvert]["note"] = "manque"
			_retour_appel("manque", -1)
		_appel_ouvert += 1
	# la fin d'un but
	if but_courant >= 0 and not chronos[but_courant].has("fini") and t >= float(chronos[but_courant]["fin"]):
		_fin_but(but_courant)
	if auto:
		while not _auto_appuis.is_empty() and _auto_appuis[0]["t"] <= te:
			annoncer(_auto_appuis.pop_front()["slot"])
	if _prochain_but >= buts.size() and chronos[-1].has("fini"):
		_finir()


func _debut_but(i: int) -> void:
	but_courant = i
	var b: Dictionary = buts[i]
	_lbl_but.text = tr("But %d/%d") % [i + 1, buts.size()]
	_bulle_tribune.visible = false
	_bulle_speaker.visible = false
	if is_instance_valid(_buteur):
		_buteur.queue_free()
	if b["local"]:
		score[0] += 1
		var j: Dictionary = feuille[b["buteur"]]
		_lbl_ecran.text = "BUUUT !"
		_lbl_ecran.add_theme_color_override("font_color", Ui.JAUNE)
		_buteur = FanzzyAnime.creer(String(_ids_fanzzy[int(b["buteur"]) % maxi(1, _ids_fanzzy.size())]) if not _ids_fanzzy.is_empty() else "")
		_personnages.add_child(_buteur)
		_buteur.scale = Vector2.ONE * Buvette.echelle(_buteur, 250.0)
		_buteur.position = Vector2(ECRAN.position.x + 300, ECRAN.end.y - 14)
		_buteur.couleurs_echarpe = PackedColorArray(Game.couleurs_club())
		_buteur.jouer(&"celebrer", 0.0)
		_speaker.jouer(&"encourager", 0.0)
		_sons.ambiance("stade", 2)
		_lbl_info.text = tr("Le numéro %d a marqué : trouve-le sur la feuille, annonce-le sur le temps du micro !") % j["numero"]
	else:
		score[1] += 1
		_faute_visiteurs = false
		_lbl_ecran.text = "But des visiteurs…"
		_lbl_ecran.add_theme_color_override("font_color", ROUGE_VISITEURS)
		_speaker.jouer(&"depit")
		_sons.ambiance("stade", 0)
		_lbl_info.text = "Les visiteurs ont marqué : on reste sobre, pas d'annonce !"
	_ordre = b["ordre"]
	_maj_boutons()
	_maj_score()
	var e := _lbl_ecran
	e.pivot_offset = e.size / 2.0
	Ui.pop(e, 1.25, 0.3)


func _fin_but(i: int) -> void:
	chronos[i]["fini"] = true
	var b: Dictionary = buts[i]
	if b["local"]:
		var notes: Array = []
		for a in appels:
			if a["but"] == i:
				notes.append(a["note"])
		var p := SpeakerRegles.paye_but(notes)
		if p["justes"] > 0:
			buts_annonces += 1
		if p["bonus"] > 0:
			bonus += p["bonus"]
			_gain_flottant(tr("TRIPLÉ PARFAIT !  +%d") % p["bonus"], Ui.JAUNE, Vector2(760, 420))
			_sons.jouer("ui_combo_%d" % clampi(buts_annonces, 1, 4))
			_sons.jouer("applaudissements", {"volume_db": -8})
		if is_instance_valid(_buteur):
			_buteur.jouer(&"sauter" if p["justes"] > 0 else &"depit")
	else:
		if not _faute_visiteurs:
			silences += 1
			_gain_flottant(tr("Sobre et fair-play  +%d") % SpeakerRegles.PAYE_SILENCE, Ui.VERT, Vector2(760, 420))
			_sons.jouer("ui_bien")
	_speaker.jouer(&"repos")
	_sons.ambiance("stade", 1)
	_lbl_info.text = ""
	_maj_hud()


## Le joueur annonce le joueur du bouton `place`.
func annoncer(place: int) -> void:
	if not pret or termine or place < 0 or place >= SpeakerRegles.NB_JOUEURS:
		return
	var te := horloge_entendue()
	var joueur: Dictionary = feuille[_ordre[place]]
	Ui.pop(_boutons[place], 1.06, 0.15)
	# l'appel le plus proche encore ouvert
	var idx := -1
	var e := INF
	for k in range(_appel_ouvert, appels.size()):
		if appels[k]["t"] > te + 1.0:
			break
		if appels[k]["note"] == "" and absf(appels[k]["t"] - te) < e:
			e = absf(appels[k]["t"] - te)
			idx = k
	var note := "hors"
	if idx >= 0:
		var b: Dictionary = buts[appels[idx]["but"]]
		note = SpeakerRegles.juger(te - float(appels[idx]["t"]), int(_ordre[place]) == int(b["buteur"]))
	if note == "hors":
		if but_courant >= 0 and not buts[but_courant]["local"] and not chronos[but_courant].has("fini"):
			if not _faute_visiteurs:
				_faute_visiteurs = true
				fautes += 1
				serie = 0
				_crier(SpeakerRegles.annonce(joueur)[0])
				_sons.jouer("sifflets_foule", {"volume_db": -6})
				_gain_flottant("Chut ! C'était les visiteurs", Ui.ROUGE, Vector2(700, 420))
				_maj_hud()
		else:
			_sons.jouer("ui_rate", {"volume_db": -10})
			_gain_flottant("Pas encore…", Ui.GRIS, Vector2(PISTE_X0 - 60, PISTE_Y - 140), 34)
		return
	appels[idx]["note"] = note
	_crier(SpeakerRegles.annonce(joueur)[0])
	_retour_appel(note, idx)


func _crier(texte: String) -> void:
	_lbl_speaker.text = texte
	_bulle_speaker.visible = true
	_bulle_speaker.reset_size()
	_bulle_speaker.pivot_offset = _bulle_speaker.size / 2.0
	Ui.pop(_bulle_speaker, 1.15, 0.2)
	_speaker.jouer(&"lever_bras", 0.5)
	_sons.jouer("hey", {"volume_db": -2})


func _retour_appel(note: String, _idx: int) -> void:
	var gain := SpeakerRegles.paye_appel(note)
	paye_appels += gain
	if gain > 0:
		annonces_justes += 1
		serie += 1
		serie_max = maxi(serie_max, serie)
		_sons.jouer("ui_parfait" if note == "parfait" else "ui_bien")
		_gain_flottant("%s  +%d" % [tr("PARFAIT") if note == "parfait" else tr("BIEN"), gain], Ui.JAUNE if note == "parfait" else Ui.VERT, Vector2(PISTE_X0 - 60, PISTE_Y - 140))
	else:
		serie = 0
		var textes := {"faux": "Pas le bon joueur !", "rate": "À côté du tempo", "manque": "Raté !"}
		_sons.jouer("ui_rate")
		_gain_flottant(textes.get(note, "Raté"), Ui.ROUGE, Vector2(PISTE_X0 - 60, PISTE_Y - 140))
	_maj_hud()


## Au 3e temps, la tribune répond… si le speaker a annoncé le bon nom.
func _reponse_tribune(i_appel: int) -> void:
	var a: Dictionary = appels[i_appel]
	var b: Dictionary = buts[a["but"]]
	if SpeakerRegles.PAYE_APPEL.has(String(a["note"])):
		_lbl_tribune.text = SpeakerRegles.annonce(feuille[b["buteur"]])[1]
		_sons.jouer("cri_groupe")
		_sons.jouer("eclat", {"volume_db": -4})
		_bat = horloge()
	else:
		_lbl_tribune.text = "… ?"
		_sons.jouer("deception", {"volume_db": -12})
	_bulle_tribune.visible = true
	_bulle_tribune.reset_size()
	_bulle_tribune.pivot_offset = _bulle_tribune.size / 2.0
	Ui.pop(_bulle_tribune, 1.2, 0.2)
	get_tree().create_timer(0.6).timeout.connect(func():
		if is_instance_valid(_bulle_speaker):
			_bulle_speaker.visible = false)


func _unhandled_input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	var k: int = ev.physical_keycode
	var touches := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_KP_1: 0, KEY_KP_2: 1, KEY_KP_3: 2, KEY_KP_4: 3}
	if touches.has(k):
		get_viewport().set_input_as_handled()
		annoncer(touches[k])
	elif k == KEY_ESCAPE and not termine:
		get_viewport().set_input_as_handled()
		_retour()


func brut() -> int:
	return paye_appels + bonus + silences * SpeakerRegles.PAYE_SILENCE


func _maj_hud() -> void:
	_lbl_paye.text = str(brut())
	Ui.pop(_lbl_paye, 1.25, 0.2)
	_lbl_serie.text = tr("Série x%d") % serie
	_lbl_serie.add_theme_color_override("font_color", Ui.JAUNE if serie >= SpeakerRegles.APPELS_PAR_BUT else Ui.BLANC)


func _maj_score() -> void:
	_lbl_score.text = tr("LOCAUX  %d - %d  VISITEURS") % [score[0], score[1]]


func _gain_flottant(texte: String, couleur: Color, pos: Vector2, taille := 48) -> void:
	var l := Ui.label(texte, taille, couleur, true, 12)
	l.position = pos
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y - 110.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------------ fin

func _finir() -> void:
	termine = true
	_sons.jouer("sifflet_fin")
	_sons.ambiance("stade", 1)
	var b := brut()
	var deja := Game.services_boulot_du_jour("speaker")
	var paye := SpeakerRegles.paye_finale(b, deja)
	var record := paye > Game.record_boulot("speaker") and paye > 0
	var xp := buts_annonces * SpeakerRegles.XP_PAR_BUT
	Game.finir_boulot("speaker", paye)
	Game.ajouter_xp(xp)
	if paye > 0:
		_sons.jouer("applaudissements", {"volume_db": -4})

	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.65, 0.4)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -460
	pan.offset_right = 460
	pan.offset_top = -360
	pan.offset_bottom = 360
	add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label("FIN DU MATCH !", 56, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sc := Ui.label(tr("Locaux %d - %d Visiteurs") % [score[0], score[1]], 28, Ui.BLANC, true)
	sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sc)
	if record:
		var r := Ui.pastille("NOUVEAU RECORD", Ui.ROSE, 22)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	var lignes := [
		["Annonces justes", "%d / %d" % [annonces_justes, appels.size()]],
		["Meilleure série", "x%d" % serie_max],
		["Paye des annonces", "+%d" % paye_appels],
		["Triplés parfaits", "+%d" % bonus],
		["Buts des visiteurs sans annonce", "+%d" % (silences * SpeakerRegles.PAYE_SILENCE)],
	]
	if paye < b:
		lignes.append([tr("Fatigue (%de match du jour)") % (deja + 1), tr("paye ÷ 2")])
	lignes.append(["Jetons gagnés", "+%d" % paye])
	lignes.append(["XP du fan club", "+%d" % xp])
	for l in lignes:
		var h := Ui.hbox(10)
		var a := Ui.label(l[0], 24, Ui.BLANC)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Ui.label(l[1], 26, Ui.JAUNE, true))
		v.add_child(h)
	var hb := Ui.hbox(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var retour := Ui.bouton("Retour", Ui.BLEU, 30)
	retour.custom_minimum_size = Vector2(300, 90)
	retour.pressed.connect(_retour)
	hb.add_child(retour)
	var rejouer := Ui.bouton("Nouveau match", Ui.VERT, 30)
	Ui.colorer_bouton(rejouer, Ui.VERT, true)
	rejouer.custom_minimum_size = Vector2(330, 90)
	var p: Dictionary = Game.params
	rejouer.pressed.connect(func(): Game.aller(Game.SCENE_SPEAKER, p))
	hb.add_child(rejouer)
	v.add_child(hb)
	pan.pivot_offset = Vector2(460, 360)
	pan.scale = Vector2.ONE * 0.6
	pan.create_tween().tween_property(pan, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Retour à l'écran des petits boulots (qui ramène ensuite à la carte).
func _retour() -> void:
	Game.aller(Game.SCENE_BOULOTS, Game.params)


# ================================================================== éléments dessinés

## Le fond : tribune la nuit, projecteurs, l'écran géant, la cabine du speaker.
class Decor extends Control:
	var jeu: Speaker

	func _draw() -> void:
		var w := size.x
		var t := Time.get_ticks_msec() / 1000.0
		draw_rect(Rect2(0, 0, w, size.y), Color("#1c1650"))
		# la tribune : des rangées de supporters qui sautent sur les temps forts
		var saut_fort := 0.0
		if jeu and jeu.pret:
			saut_fort = clampf(1.0 - (jeu.horloge() - jeu._bat) / 0.25, 0.0, 1.0)
		var c: Array = Game.couleurs_club()
		for rang in 6:
			var y := 150.0 + rang * 70.0
			draw_rect(Rect2(0, y + 22, w, 40), Color("#2a2270").lerp(Color("#3d3494"), rang / 6.0))
			var n := 34
			for i in n:
				var x := 20 + i * (w - 40) / (n - 1)
				if Rect2(Speaker.ECRAN.position.x - 30, 0, Speaker.ECRAN.size.x + 60, Speaker.ECRAN.end.y + 30).has_point(Vector2(x, y)):
					continue
				var saut := sin(t * 2.0 + i * 0.7 + rang) * 2.5 + saut_fort * 16.0 * (0.6 + 0.4 * sin(i + rang))
				var col: Color = c[0] if (i + rang) % 3 == 0 else (c[1] if (i + rang) % 3 == 1 else Ui.BLANC)
				draw_circle(Vector2(x, y + 14 - saut), 15, col.darkened(0.1 * rang))
		# l'écran géant
		var e := Speaker.ECRAN
		draw_rect(Rect2(e.position.x + e.size.x / 2.0 - 30, e.end.y, 60, 60), Ui.CONTOUR)
		draw_style_box(Ui.boite(Ui.CONTOUR, 26, 0), e.grow(16))
		var visiteurs: bool = jeu != null and jeu.but_courant >= 0 and not jeu.buts[jeu.but_courant]["local"]
		draw_style_box(Ui.boite(Color("#26214f") if visiteurs else Color("#0f2a5c"), 18, 0), e)
		for i in 18:
			draw_line(Vector2(e.position.x + 10, e.position.y + 10 + i * e.size.y / 18.0), Vector2(e.end.x - 10, e.position.y + 10 + i * e.size.y / 18.0), Color(1, 1, 1, 0.03), 2)
		# pelouse en bas
		draw_rect(Rect2(0, 560, w, size.y - 560), Color("#16123c"))
		# la cabine du speaker
		var cab := Rect2(20, 700, 420, 360)
		draw_style_box(Ui.boite(Color("#3a3290"), 30, 6), cab)
		draw_rect(Rect2(cab.position.x + 20, cab.position.y + 22, cab.size.x - 40, 30), Ui.ROSE)
		var f := Ui.police_titre()
		draw_string(f, Vector2(cab.position.x + 30, cab.position.y + 46), tr("CABINE DU SPEAKER"), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Ui.BLANC)


## Par-dessus les personnages : la piste du tempo, le micro, le numéro du buteur.
class Dessus extends Control:
	var jeu: Speaker

	func _draw() -> void:
		if jeu == null:
			return
		# --- numéro du buteur sur l'écran géant
		var e := Speaker.ECRAN
		if jeu.but_courant >= 0 and jeu.buts[jeu.but_courant]["local"]:
			var j: Dictionary = jeu.feuille[jeu.buts[jeu.but_courant]["buteur"]]
			var c: Array = Game.couleurs_club()
			var centre := Vector2(e.end.x - 190, e.position.y + 220)
			# un maillot dessiné, le numéro dessus
			var m := PackedVector2Array([
				centre + Vector2(-70, -110), centre + Vector2(-20, -120), centre + Vector2(20, -120), centre + Vector2(70, -110),
				centre + Vector2(130, -60), centre + Vector2(100, -20), centre + Vector2(70, -40), centre + Vector2(70, 110),
				centre + Vector2(-70, 110), centre + Vector2(-70, -40), centre + Vector2(-100, -20), centre + Vector2(-130, -60)])
			draw_colored_polygon(m, c[0])
			var ferme := m.duplicate()
			ferme.append(m[0])
			draw_polyline(ferme, Ui.CONTOUR, 8, true)
			var f := Ui.police_titre()
			var txt := str(j["numero"])
			var fs := 120
			var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := centre + Vector2(-tw / 2.0, 50)
			draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 16, Ui.CONTOUR)
			draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c[1] if c[1] != c[0] else Ui.BLANC)
		# --- la piste du tempo
		var y := Speaker.PISTE_Y
		draw_style_box(Ui.boite(Color("#100c30"), 30, 5), Rect2(Speaker.PISTE_X0 - 60, y - 48, Speaker.PISTE_X1 - Speaker.PISTE_X0 + 80, 96))
		if not jeu.pret:
			return
		var te := jeu.horloge_entendue()
		# les temps de la mesure (petits traits), autour du but en cours
		for i in jeu.chronos.size():
			var ch: Dictionary = jeu.chronos[i]
			if float(ch["fin"]) < te - 1.0 or float(ch["debut"]) > te + 3.0:
				continue
			var d := SpeakerRegles.duree_temps(float(jeu.buts[i]["bpm"]))
			var k := 0
			var tt := float(ch["debut"])
			while tt < float(ch["fin"]) - 0.001:
				var x := Speaker.PISTE_X0 + (tt - te) * Speaker.VITESSE
				if x > Speaker.PISTE_X0 - 40 and x < Speaker.PISTE_X1:
					draw_line(Vector2(x, y - (26 if k % 4 == 0 else 14)), Vector2(x, y + (26 if k % 4 == 0 else 14)), Color(1, 1, 1, 0.35 if k % 4 == 0 else 0.15), 4)
				k += 1
				tt += d
		# le micro (la cible)
		var pulse := clampf(1.0 - (jeu.horloge() - jeu._bat) / 0.2, 0.0, 1.0)
		draw_circle(Vector2(Speaker.PISTE_X0, y), 44 + pulse * 6, Ui.CONTOUR)
		draw_circle(Vector2(Speaker.PISTE_X0, y), 38 + pulse * 6, Ui.ROSE)
		_micro(Vector2(Speaker.PISTE_X0, y), 1.0)
		# les appels qui arrivent
		for a in jeu.appels:
			var x := Speaker.PISTE_X0 + (float(a["t"]) - te) * Speaker.VITESSE
			if x < Speaker.PISTE_X0 - 50 or x > Speaker.PISTE_X1:
				continue
			var col := Ui.JAUNE
			match String(a["note"]):
				"parfait", "bien":
					continue
				"faux", "rate", "manque":
					col = Color(0.6, 0.6, 0.7, 0.6)
			draw_circle(Vector2(x, y), 32, Ui.CONTOUR)
			draw_circle(Vector2(x, y), 26, col)
			var j2: Dictionary = jeu.feuille[jeu.buts[a["but"]]["buteur"]]
			var f2 := Ui.police_titre()
			var s := str(j2["numero"])
			var w2 := f2.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			draw_string(f2, Vector2(x - w2 / 2.0, y + 10), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Ui.CONTOUR)

	func _micro(c: Vector2, k: float) -> void:
		draw_rect(Rect2(c + Vector2(-6, 4) * k, Vector2(12, 24) * k), Ui.CONTOUR)
		draw_circle(c + Vector2(0, -6) * k, 14 * k, Ui.CONTOUR)
		draw_circle(c + Vector2(0, -6) * k, 10 * k, Color("#d9d6ee"))
