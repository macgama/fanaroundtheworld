extends Control
## Défi de recrutement : convaincre un FANZZY rencontré de rejoindre le club
## (règles dans Rencontres). Un petit jeu de 15 à 20 s selon sa famille :
##  - rythme (Voix, Percussion) : taper au tempo, 8 temps ;
##  - mémoire (Tifo, Déplacement) : refaire la mosaïque de couleurs, 3 manches ;
##  - précision (Fidélité, Pyro) : arrêter le curseur dans la zone, 5 essais.
## Réussi : il rejoint le club. Raté : il reviendra plus tard. Jamais de Jetons.

const BPM := 96.0
const FENETRE_PARFAIT := 0.1
const FENETRE_BIEN := 0.2
const COULEURS_MEMOIRE := [Color("#ff3d7f"), Color("#ffd23f"), Color("#1e6bff"), Color("#3ddc84")]

var _z: Dictionary
var _id := ""
var _defi := "rythme"
var _objectif: Array = [6, 8]
var _auto := false
var _en_jeu := false
var _fini := false
var _bons := 0
var _essais := 0
var _t := 0.0

var _fanzzy: FanzzyAnime
var _bulle: Label
var _zone: Control
var _score: Label
var _consigne: Label
var _depart: Button

# rythme
var _pas: Array = []
var _juges: Array = []
var _anneau: Anneau
# mémoire
var _sequence: Array = []
var _saisie: Array = []
var _manche := 0
var _tuiles: Array = []
var _montre := false
# précision
var _barre: Barre


func _ready() -> void:
	var p: Dictionary = Game.params
	_id = str(p.get("id", ""))
	_z = Game.fanzzy_par_id(_id)
	_auto = bool(p.get("auto", false)) or "--auto" in OS.get_cmdline_user_args()
	if _z.is_empty() or not Rencontres.en_attente(Game.club, _id):
		Game.aller(Game.SCENE_CLUB if Game.club_cree() else Game.SCENE_CARTE)
		return
	_defi = Rencontres.defi(str(_z["famille"]))
	_objectif = Rencontres.objectif(_z)
	_construire()
	if _auto:
		get_tree().create_timer(0.8).timeout.connect(_commencer)


func _construire() -> void:
	var cc := Game.couleurs_club()
	var fond := ColorRect.new()
	fond.color = Color("#f6b26b")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var sol := ColorRect.new()
	sol.color = Color("#b8662e")
	sol.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	sol.offset_top = -300
	add_child(sol)
	# une banderole du club au mur du local
	var ban := ColorRect.new()
	ban.color = cc[0]
	ban.position = Vector2(0, 150)
	ban.size = Vector2(1920, 70)
	add_child(ban)
	var bl := Ui.label(Game.fan_club_nom.to_upper(), 44, cc[1] if cc[1].get_luminance() > 0.4 else Ui.BLANC, true, 8)
	bl.position = Vector2(0, 150)
	bl.size = Vector2(1920, 70)
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(bl)

	var titre := Ui.label(tr("DÉFI DE RECRUTEMENT · %s") % tr(str(_z["nom"])).to_upper(), 46, Ui.JAUNE, true, 10)
	titre.set_anchors_preset(Control.PRESET_CENTER_TOP)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.offset_left = -900
	titre.offset_right = 900
	titre.offset_top = 40
	titre.offset_bottom = 120
	add_child(titre)
	Ui.ajuster_taille(titre, 46, 1800)

	_fanzzy = FanzzyAnime.creer(_id)
	_fanzzy.couleurs_echarpe = PackedColorArray([cc[0], cc[1]])
	_fanzzy.scale = Vector2.ONE * Buvette.echelle(_fanzzy, 520.0)
	_fanzzy.position = Vector2(420, 960)
	add_child(_fanzzy)
	_fanzzy.jouer(&"repos")

	var bulle := Ui.panneau(Ui.BLANC, 26, 5)
	bulle.position = Vector2(120, 250)
	bulle.custom_minimum_size = Vector2(600, 0)
	add_child(bulle)
	_bulle = Ui.label(Rencontres.PHRASES.get(str(_z["famille"]), ""), 24, Ui.CONTOUR, true)
	_bulle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bulle.custom_minimum_size = Vector2(560, 0)
	bulle.add_child(_bulle)

	var panneau := Ui.panneau(Ui.NUIT, 28, 6)
	panneau.position = Vector2(820, 250)
	panneau.size = Vector2(1020, 760)
	add_child(panneau)
	var v := Ui.vbox(14)
	panneau.add_child(v)
	var h := Ui.hbox(12)
	h.add_child(Ui.pastille(Game.nom_famille(str(_z["famille"])), Game.couleur_famille(str(_z["famille"])), 18, str(_z["famille"]) in ["voix", "fide"]))
	var td := Ui.label(tr(Rencontres.TITRES_DEFI[_defi]), 34, Ui.JAUNE, true, 6)
	td.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(td)
	_score = Ui.label("", 26, Ui.BLANC, true, 4)
	h.add_child(_score)
	v.add_child(h)
	_consigne = Ui.label(_texte_consigne(), 21, Ui.BLANC)
	_consigne.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_consigne)
	_zone = Control.new()
	_zone.custom_minimum_size = Vector2(0, 430)
	_zone.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_zone)
	var hb := Ui.hbox(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var retour := Ui.bouton("Plus tard", Ui.NUIT_CLAIR, 24)
	retour.tooltip_text = "Revenir au fan club sans faire le défi"
	retour.pressed.connect(func():
		if not _en_jeu:
			Game.aller(Game.SCENE_CLUB))
	hb.add_child(retour)
	_depart = Ui.bouton("RELEVER LE DÉFI", Ui.VERT, 30)
	Ui.colorer_bouton(_depart, Ui.VERT, true)
	_depart.custom_minimum_size = Vector2(420, 84)
	_depart.pressed.connect(_commencer)
	hb.add_child(_depart)
	v.add_child(hb)
	_maj_score()


func _texte_consigne() -> String:
	match _defi:
		"memoire":
			return tr("Regarde la mosaïque, puis refais-la dans le même ordre (clic ou touches 1 à 4). Réussis %d manches sur %d.") % [_objectif[0], _objectif[1]]
		"precision":
			return tr("Arrête le curseur dans la zone verte (ESPACE ou clic). Réussis %d essais sur %d.") % [_objectif[0], _objectif[1]]
	return tr("Tape au tempo quand l'anneau touche le cercle (ESPACE ou clic). Réussis %d temps sur %d.") % [_objectif[0], _objectif[1]]


func _maj_score() -> void:
	_score.text = tr("%d réussis (il en faut %d)") % [_bons, int(_objectif[0])]
	_score.add_theme_color_override("font_color", Ui.VERT if _bons >= int(_objectif[0]) else Ui.BLANC)


func _process(delta: float) -> void:
	_t += delta
	if not _en_jeu:
		return
	match _defi:
		"rythme":
			_suivre_rythme()
		"precision":
			if _auto and is_instance_valid(_barre) and _barre.actif and absf(_barre.curseur - _barre.centre) < 0.02:
				_arreter_curseur()


func _commencer() -> void:
	if _en_jeu or _fini:
		return
	_en_jeu = true
	_depart.disabled = true
	_fanzzy.jouer(&"encourager")
	match _defi:
		"rythme":
			_lancer_rythme()
		"memoire":
			_lancer_memoire()
		"precision":
			_lancer_precision()


# ------------------------------------------------------------------ rythme

func _lancer_rythme() -> void:
	_anneau = Anneau.new()
	_anneau.set_anchors_preset(Control.PRESET_FULL_RECT)
	_anneau.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anneau.couleur = Game.couleur_famille(str(_z["famille"]))
	_zone.add_child(_anneau)
	var periode := 60.0 / BPM
	for k in int(_objectif[1]):
		_pas.append(_t + 1.0 + periode * k)
		_juges.append(false)
	_fanzzy.bpm = BPM
	_fanzzy.jouer(&"chanter")


func _suivre_rythme() -> void:
	var prochain := -1
	for k in _pas.size():
		if not _juges[k] and _t > float(_pas[k]) + FENETRE_BIEN:
			_juges[k] = true
			_essais += 1
			_flash("Raté", Ui.ROSE)
		if prochain < 0 and not _juges[k]:
			prochain = k
	if prochain < 0:
		_terminer()
		return
	var periode := 60.0 / BPM
	_anneau.phase = 1.0 - clampf((float(_pas[prochain]) - _t) / periode, 0.0, 1.0)
	_anneau.queue_redraw()
	if _auto and absf(float(_pas[prochain]) - _t) < 0.02:
		_taper_rythme()


func _taper_rythme() -> void:
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
	_essais += 1
	if ecart <= FENETRE_BIEN:
		_bons += 1
		_fanzzy.rebondir(0.6)
		_flash("PARFAIT !" if ecart <= FENETRE_PARFAIT else "Bien", Ui.JAUNE if ecart <= FENETRE_PARFAIT else Ui.VERT)
	else:
		_flash("Raté", Ui.ROSE)
	_maj_score()


# ------------------------------------------------------------------ mémoire

func _lancer_memoire() -> void:
	var g := HBoxContainer.new()
	g.add_theme_constant_override("separation", 22)
	g.alignment = BoxContainer.ALIGNMENT_CENTER
	g.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	g.offset_left = -470
	g.offset_right = 470
	g.offset_top = -200
	g.offset_bottom = -20
	_zone.add_child(g)
	for k in COULEURS_MEMOIRE.size():
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 170)
		b.text = str(k + 1)
		b.add_theme_font_size_override("font_size", 40)
		var col: Color = COULEURS_MEMOIRE[k]
		b.add_theme_stylebox_override("normal", Ui.boite(col.darkened(0.35), 22, 5))
		b.add_theme_stylebox_override("hover", Ui.boite(col.darkened(0.2), 22, 5))
		b.add_theme_stylebox_override("pressed", Ui.boite(col, 22, 5))
		b.add_theme_stylebox_override("disabled", Ui.boite(col.darkened(0.55), 22, 5))
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		b.focus_mode = Control.FOCUS_NONE
		var kk := k
		b.pressed.connect(func(): _saisir(kk))
		g.add_child(b)
		_tuiles.append(b)
	_manche_suivante()


func _manche_suivante() -> void:
	if _manche >= int(_objectif[1]) or _bons >= int(_objectif[0]) or (int(_objectif[1]) - _manche) < (int(_objectif[0]) - _bons):
		_terminer()
		return
	var n := 3 + _manche
	_manche += 1
	_sequence.clear()
	_saisie.clear()
	for k in n:
		_sequence.append(randi() % COULEURS_MEMOIRE.size())
	_montrer_sequence()


func _montrer_sequence() -> void:
	_montre = true
	for b in _tuiles:
		b.disabled = true
	_consigne.text = tr("Manche %d : regarde bien…") % _manche
	var tw := create_tween()
	tw.tween_interval(0.6)
	for c in _sequence:
		var b: Button = _tuiles[c]
		tw.tween_callback(func(): b.modulate = Color(1.8, 1.8, 1.8))
		tw.tween_interval(0.45)
		tw.tween_callback(func(): b.modulate = Color.WHITE)
		tw.tween_interval(0.15)
	tw.tween_callback(func():
		_montre = false
		for b in _tuiles:
			b.disabled = false
		_consigne.text = tr("À toi ! Refais les %d couleurs.") % _sequence.size()
		if _auto:
			_jouer_auto_memoire())


func _jouer_auto_memoire() -> void:
	var tw := create_tween()
	for c in _sequence.duplicate():
		var cc: int = c
		tw.tween_interval(0.3)
		tw.tween_callback(func(): _saisir(cc))


func _saisir(k: int) -> void:
	if _montre or _fini or _defi != "memoire" or _sequence.is_empty():
		return
	_saisie.append(k)
	var i := _saisie.size() - 1
	var b: Button = _tuiles[k]
	b.modulate = Color(1.6, 1.6, 1.6)
	b.create_tween().tween_property(b, "modulate", Color.WHITE, 0.2)
	if _saisie[i] != _sequence[i]:
		_essais += 1
		_flash("Raté", Ui.ROSE)
		_sequence.clear()
		get_tree().create_timer(0.7).timeout.connect(_manche_suivante)
		return
	if _saisie.size() == _sequence.size():
		_essais += 1
		_bons += 1
		_maj_score()
		_fanzzy.rebondir(0.8)
		_flash("Bravo !", Ui.VERT)
		_sequence.clear()
		get_tree().create_timer(0.7).timeout.connect(_manche_suivante)


# ------------------------------------------------------------------ précision

func _lancer_precision() -> void:
	_barre = Barre.new()
	_barre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_barre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone.add_child(_barre)
	_nouvel_essai()


func _nouvel_essai() -> void:
	if _essais >= int(_objectif[1]) or _bons >= int(_objectif[0]) or (int(_objectif[1]) - _essais) < (int(_objectif[0]) - _bons):
		_terminer()
		return
	_barre.largeur = 0.16 - 0.015 * _essais
	_barre.centre = randf_range(0.2, 0.8)
	_barre.vitesse = 0.9 + 0.12 * _essais
	_barre.actif = true


func _arreter_curseur() -> void:
	if not _barre.actif:
		return
	_barre.actif = false
	_essais += 1
	if absf(_barre.curseur - _barre.centre) <= _barre.largeur / 2.0:
		_bons += 1
		_fanzzy.rebondir(0.8)
		_flash("En plein dedans !", Ui.VERT)
	else:
		_flash("Raté", Ui.ROSE)
	_maj_score()
	get_tree().create_timer(0.6).timeout.connect(_nouvel_essai)


# ------------------------------------------------------------------ entrées et fin

func _unhandled_input(ev: InputEvent) -> void:
	var tape := false
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).physical_keycode
		if k == KEY_ESCAPE and not _en_jeu:
			Game.aller(Game.SCENE_CLUB)
			return
		if k in [KEY_SPACE, KEY_ENTER]:
			tape = true
		if _defi == "memoire" and _en_jeu:
			var i := [KEY_1, KEY_2, KEY_3, KEY_4].find(k)
			if i < 0:
				i = [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4].find(k)
			if i >= 0:
				_saisir(i)
				get_viewport().set_input_as_handled()
				return
	elif ev is InputEventMouseButton and ev.pressed and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		tape = true
	elif ev is InputEventScreenTouch and ev.pressed:
		tape = true
	if not tape or not _en_jeu or _fini:
		return
	if _defi == "rythme":
		_taper_rythme()
		get_viewport().set_input_as_handled()
	elif _defi == "precision" and is_instance_valid(_barre):
		_arreter_curseur()
		get_viewport().set_input_as_handled()


func _flash(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 44, couleur, true, 10)
	l.set_anchors_preset(Control.PRESET_CENTER_TOP)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.offset_left = -400
	l.offset_right = 400
	l.offset_top = 10
	l.offset_bottom = 70
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone.add_child(l)
	Ui.pop(l, 1.2, 0.12)
	var tw := l.create_tween()
	tw.tween_interval(0.4)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)


func _terminer() -> void:
	if _fini:
		return
	_fini = true
	_en_jeu = false
	var gagne := Rencontres.reussi(_z, _bons)
	var rejoint := Game.convaincre(_id, gagne)
	_fanzzy.jouer(&"celebrer" if rejoint else &"depit", 4.0)
	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.5, 0.3)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -480
	pan.offset_right = 480
	pan.offset_top = -170
	pan.offset_bottom = 170
	add_child(pan)
	var v := Ui.vbox(14)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label(tr("%s REJOINT LE CLUB !") % tr(str(_z["nom"])).to_upper() if rejoint else "PAS ENCORE CONVAINCU…", 44, Ui.JAUNE if rejoint else Ui.ROSE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var detail := tr("%d / %d réussis. Bienvenue dans le noyau du club !") % [_bons, int(_objectif[1])] if rejoint else tr("%d / %d réussis. Il reviendra dans %d min : retente ta chance !") % [_bons, int(_objectif[1]), Rencontres.ATTENTE_APRES_ECHEC / 60]
	if gagne and not rejoint:
		detail = tr("Il est convaincu, mais le club est plein : monte de niveau pour lui faire une place.")
	var d := Ui.label(detail, 22, Ui.BLANC)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(d)
	var b := Ui.bouton("Retour au fan club", Ui.VERT if rejoint else Ui.BLEU, 30)
	if rejoint:
		Ui.colorer_bouton(b, Ui.VERT, true)
	b.custom_minimum_size = Vector2(420, 84)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): Game.aller(Game.SCENE_CLUB))
	v.add_child(b)
	Ui.pop(pan, 1.05)
	if "--quitter" in OS.get_cmdline_user_args():
		print("RESULTAT defi %s bons=%d rejoint=%s" % [_defi, _bons, rejoint])  # sans_traduction
		get_tree().create_timer(1.5).timeout.connect(func(): get_tree().quit())


## L'anneau du rythme : il se resserre jusqu'au cercle à chaque temps.
class Anneau extends Control:
	var phase := 0.0
	var couleur := Ui.BLEU

	func _draw() -> void:
		var c := size / 2.0
		var r := 110.0
		draw_circle(c, r, Color(couleur, 0.9))
		draw_arc(c, r, 0, TAU, 64, Ui.CONTOUR, 8, true)
		draw_arc(c, lerpf(210.0, r, phase), 0, TAU, 64, Ui.JAUNE, 10, true)
		var f := Ui.police_titre()
		var tw := f.get_string_size("♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 90).x
		draw_string(f, c + Vector2(-tw / 2.0, 30), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 90, Ui.BLANC)


## La barre de précision : un curseur qui va et vient, une zone verte à viser.
class Barre extends Control:
	var curseur := 0.0
	var centre := 0.5
	var largeur := 0.16
	var vitesse := 0.9
	var actif := false
	var _sens := 1.0

	func _process(delta: float) -> void:
		if actif:
			curseur += _sens * vitesse * delta
			if curseur > 1.0:
				curseur = 1.0
				_sens = -1.0
			elif curseur < 0.0:
				curseur = 0.0
				_sens = 1.0
		queue_redraw()

	func _draw() -> void:
		var r := Rect2(40, size.y / 2.0 - 40, size.x - 80, 80)
		draw_style_box(Ui.boite(Ui.CONTOUR, 40, 0), r)
		var zx := r.position.x + r.size.x * (centre - largeur / 2.0)
		draw_rect(Rect2(zx, r.position.y + 8, r.size.x * largeur, r.size.y - 16), Ui.VERT)
		var cx := r.position.x + r.size.x * curseur
		draw_rect(Rect2(cx - 8, r.position.y - 30, 16, r.size.y + 60), Ui.JAUNE)
		draw_rect(Rect2(cx - 8, r.position.y - 30, 16, r.size.y + 60), Ui.CONTOUR, false, 4)
