class_name Tifo
extends Control
## Petit boulot de supporter : peintre de tifo (60 secondes).
##   clic gauche (glisser) : peindre avec l'outil choisi · clic droit : seau
##   1 à 5 : choisir la peinture · P : pinceau · S : seau · TAB : changer d'outil
##   flèches + ESPACE : peindre au clavier · ENTRÉE : présenter la bâche au capo
## Le capo montre un modèle ; le joueur peint la grande bâche pour qu'elle lui
## ressemble, puis la présente : acceptée, elle est hissée en tribune et payée
## en Jetons selon sa ressemblance. Règles dans TifoRegles.
## Option « --auto » (tests, captures) : le service se joue tout seul.

const SonsScript := preload("res://scripts/audio/sons.gd")

const ZONE_BACHE := Rect2(560, 128, 1320, 660)
const ZONE_MODELE := Rect2(52, 190, 440, 250)
const PIEDS_CAPO := Vector2(272, 812)
const HAUTEUR_CAPO := 330.0

var regles := TifoRegles.new()
var temps := 0.0
var pret := false
var termine := false
var auto := "--auto" in OS.get_cmdline_user_args()

var modele := {}
var bache := PackedInt32Array()
var numero := 0                 # bâches commencées (la courante comprise)
var peinture := 1
var outil := "pinceau"          # ou "seau"
var curseur := Vector2i.ZERO
var hissees: Array = []         # [{cases, w, h, ressemblance}] bâches acceptées
var refus := 0
var parfaites := 0
var serie := 0
var serie_max := 0
var salaire := 0
var bonus := 0

var _auto_prochain := 0.0
var _auto_erreurs := 0
var _sons: Node
var _capo: FanzzyAnime
var _peint_son := 0.0
var _en_transition := false

var _grille: Grille
var _mini: Grille
var _lbl_temps: Label
var _lbl_paye: Label
var _lbl_bache: Label
var _lbl_resse: Label
var _lbl_capo: Label
var _pots: Array = []
var _btn_pinceau: Button
var _btn_seau: Button
var _btn_valider: Button


func _ready() -> void:
	_sons = SonsScript.new()
	_sons.name = "Sons"
	add_child(_sons)
	_construire()
	_sons.ambiance("stade", 0)
	_nouvelle_bache()
	_compte_a_rebours()


# ------------------------------------------------------------------ construction

func _construire() -> void:
	var fond := Atelier.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)

	# --- le capo (le FANZZY « tifo » de ta tribune) et son modèle
	var pm := Ui.panneau(Ui.NUIT, 24, 5)
	pm.position = ZONE_MODELE.position - Vector2(18, 74)
	pm.custom_minimum_size = ZONE_MODELE.size + Vector2(36, 92)
	pm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pm)
	var vm := Ui.vbox(6)
	pm.add_child(vm)
	var tm := Ui.label("Modèle du capo", 26, Ui.JAUNE, true, 6)
	tm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vm.add_child(tm)
	_mini = Grille.new()
	_mini.custom_minimum_size = ZONE_MODELE.size
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vm.add_child(_mini)

	var ids: Array = Game.equipe if Game.equipe.size() >= 2 else []
	var id_capo: String = str(ids[1]) if ids.size() >= 2 else (Buvette.ids_clients()[0] if not Buvette.ids_clients().is_empty() else "")
	_capo = FanzzyAnime.creer(id_capo, "e1", str(Game.skins.get(id_capo, "base")))
	_capo.couleurs_echarpe = PackedColorArray([Ui.ROSE, Ui.BLANC])
	add_child(_capo)
	_capo.scale = Vector2.ONE * Buvette.echelle(_capo, HAUTEUR_CAPO)
	_capo.position = PIEDS_CAPO
	_capo.jouer(&"repos")
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", Ui.boite(Ui.BLANC, 22, 5, 6))
	pc.position = Vector2(40, 470)
	pc.custom_minimum_size = Vector2(470, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pc)
	_lbl_capo = Ui.label("", 24, Ui.CONTOUR, true)
	_lbl_capo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_capo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pc.add_child(_lbl_capo)

	# --- la bâche
	_grille = Grille.new()
	_grille.tifo = self
	_grille.interactive = true
	_grille.position = ZONE_BACHE.position
	_grille.size = ZONE_BACHE.size
	_grille.pivot_offset = ZONE_BACHE.size / 2.0
	add_child(_grille)

	# --- haut : quitter, temps, bâche, ressemblance, paye
	var haut := Ui.hbox(16)
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 28
	haut.offset_right = -28
	haut.offset_top = 18
	add_child(haut)
	var quitter := Ui.bouton("Quitter", Ui.NUIT_CLAIR, 24)
	quitter.tooltip_text = "Rentrer sans finir le service (pas de paye)"
	quitter.custom_minimum_size = Vector2(170, 70)
	quitter.focus_mode = Control.FOCUS_NONE
	quitter.pressed.connect(_retour_carte)
	haut.add_child(quitter)
	var pt := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_temps = Ui.label("1:00", 40, Ui.BLANC, true, 6)
	_lbl_temps.custom_minimum_size = Vector2(110, 0)
	_lbl_temps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt.add_child(_lbl_temps)
	haut.add_child(pt)
	haut.add_child(Ui.espace())
	var pb := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_bache = Ui.label("", 30, Ui.BLANC, true, 6)
	pb.add_child(_lbl_bache)
	haut.add_child(pb)
	var pr := Ui.panneau(Ui.NUIT, 20, 5)
	pr.tooltip_text = tr("Ressemblance avec le modèle : le capo accepte à partir de %d %%") % int(TifoRegles.SEUIL_REFUS * 100)
	_lbl_resse = Ui.label("", 30, Ui.BLANC, true, 6)
	_lbl_resse.custom_minimum_size = Vector2(250, 0)
	_lbl_resse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pr.add_child(_lbl_resse)
	haut.add_child(pr)
	var pj := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 40))
	_lbl_paye = Ui.label("0", 34, Ui.JAUNE, true, 6)
	hj.add_child(_lbl_paye)
	pj.add_child(hj)
	pj.tooltip_text = "Paye du service (versée à la fin)"
	haut.add_child(pj)

	# --- bas : peintures, outils, présenter
	var bas := Ui.hbox(18)
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.offset_left = -900
	bas.offset_right = 900
	bas.offset_top = -262
	bas.offset_bottom = -58
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bas)
	for i in TifoRegles.PEINTURES.size():
		var b := _bouton_pot(i)
		bas.add_child(b)
		_pots.append(b)
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(14, 0)
	bas.add_child(sep)
	var vo := Ui.vbox(12)
	vo.alignment = BoxContainer.ALIGNMENT_CENTER
	bas.add_child(vo)
	_btn_pinceau = Ui.bouton("Pinceau (P)", Ui.NUIT_CLAIR, 26)
	_btn_pinceau.custom_minimum_size = Vector2(250, 84)
	_btn_pinceau.focus_mode = Control.FOCUS_NONE
	_btn_pinceau.tooltip_text = "Une case à la fois : clique ou glisse sur la bâche"
	_btn_pinceau.pressed.connect(choisir_outil.bind("pinceau"))
	vo.add_child(_btn_pinceau)
	_btn_seau = Ui.bouton("Seau (S)", Ui.NUIT_CLAIR, 26)
	_btn_seau.custom_minimum_size = Vector2(250, 84)
	_btn_seau.focus_mode = Control.FOCUS_NONE
	_btn_seau.tooltip_text = "Toute la zone de la même couleur d'un coup (aussi : clic droit)"
	_btn_seau.pressed.connect(choisir_outil.bind("seau"))
	vo.add_child(_btn_seau)
	var sep2 := Control.new()
	sep2.custom_minimum_size = Vector2(14, 0)
	bas.add_child(sep2)
	_btn_valider = Ui.bouton("PRÉSENTER", Ui.VERT, 40)
	Ui.colorer_bouton(_btn_valider, Ui.VERT, true)
	_btn_valider.custom_minimum_size = Vector2(330, 180)
	_btn_valider.focus_mode = Control.FOCUS_NONE
	_btn_valider.tooltip_text = "Montrer la bâche au capo (ENTRÉE)"
	_btn_valider.pressed.connect(presenter)
	bas.add_child(_btn_valider)

	var info := Ui.label("Glisse pour peindre  ·  1 à 5 : peinture  ·  clic droit ou S : seau  ·  flèches + ESPACE au clavier  ·  ENTRÉE : présenter", 20, Ui.GRIS)
	info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.offset_left = -900
	info.offset_right = 900
	info.offset_top = -46
	info.offset_bottom = -14
	add_child(info)
	_maj_outils()


func _bouton_pot(i: int) -> Button:
	var c := TifoRegles.couleur(i)
	var b := Ui.bouton("", c, 26)
	Ui.colorer_bouton(b, c, i in [0, 3])
	b.custom_minimum_size = Vector2(170, 196)
	b.pivot_offset = Vector2(85, 98)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tr("%s (touche %d)") % [TifoRegles.PEINTURES[i]["nom"], i + 1]
	b.pressed.connect(choisir_peinture.bind(i))
	var v := Ui.vbox(4)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var pot := Pot.new()
	pot.couleur = c
	pot.custom_minimum_size = Vector2(96, 96)
	pot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pot)
	var l := Ui.label(TifoRegles.PEINTURES[i]["nom"], 26, Ui.CONTOUR if i in [0, 3] else Ui.BLANC, true, 0 if i in [0, 3] else 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var touche := Ui.pastille(str(i + 1), Ui.CONTOUR, 18)
	touche.position = Vector2(12, 10)
	touche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(touche)
	return b


# ------------------------------------------------------------------ déroulé

func _compte_a_rebours() -> void:
	var l := Ui.label("3", 200, Ui.JAUNE, true, 24)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.offset_top = -160
	add_child(l)
	for t in ["3", "2", "1", "À VOS PINCEAUX !"]:
		l.text = t
		Ui.ajuster_taille(l, 200, get_viewport_rect().size.x - 120)
		l.pivot_offset = l.size / 2.0
		Ui.pop(l, 1.4, 0.3)
		_sons.jouer("ui_decompte_go" if t.length() > 1 else "ui_decompte")
		await get_tree().create_timer(0.7).timeout
	l.queue_free()
	pret = true
	_auto_prochain = 0.6


func _nouvelle_bache() -> void:
	modele = regles.modele(numero)
	numero += 1
	bache = TifoRegles.bache_vierge(modele["w"], modele["h"])
	curseur = Vector2i(modele["w"] / 2, modele["h"] / 2)
	_mini.regler(modele["cases"], modele["w"], modele["h"])
	_grille.regler(bache, modele["w"], modele["h"])
	_lbl_bache.text = tr("Bâche n° %d · %s") % [numero, tr(modele["nom"])]
	_dire(tr(["Peins-moi « %s » !", "Celle-là, c'est « %s ».", "Allez, « %s » maintenant !"][mini(numero - 1, 2) if numero <= 3 else randi() % 3]) % tr(modele["nom"]).to_lower())
	_auto_erreurs = 0
	_maj_resse()


func _dire(texte: String) -> void:
	_lbl_capo.text = texte
	Ui.pop(_lbl_capo.get_parent(), 1.06, 0.2)


func _process(delta: float) -> void:
	if not pret or termine:
		return
	temps += delta
	_peint_son = maxf(0.0, _peint_son - delta)
	var reste := maxf(0.0, TifoRegles.DUREE - temps)
	_lbl_temps.text = "%d:%02d" % [int(ceil(reste)) / 60, int(ceil(reste)) % 60]
	_lbl_temps.add_theme_color_override("font_color", Ui.ROUGE if reste < 10.0 else Ui.BLANC)
	if auto and not _en_transition:
		_jouer_tout_seul(delta)
	if temps >= TifoRegles.DUREE:
		_finir()


## Le robot des tests : un coup de seau pour le fond, puis case par case
## (avec quelques fautes de pinceau), et il présente quand c'est parfait.
func _jouer_tout_seul(delta: float) -> void:
	_auto_prochain -= delta
	if _auto_prochain > 0.0:
		return
	_auto_prochain = randf_range(0.13, 0.2)
	var w: int = modele["w"]
	var cible: PackedInt32Array = modele["cases"]
	if TifoRegles.VIERGE in bache:
		# la couleur de modèle la plus fréquente sous les cases vierges
		var compte := {}
		for i in bache.size():
			if bache[i] == TifoRegles.VIERGE:
				compte[cible[i]] = int(compte.get(cible[i], 0)) + 1
		var meilleure: int = compte.keys()[0]
		for k in compte:
			if compte[k] > compte[meilleure]:
				meilleure = k
		for i in bache.size():
			if bache[i] == TifoRegles.VIERGE and cible[i] == meilleure:
				choisir_peinture(meilleure)
				curseur = Vector2i(i % w, i / w)
				appliquer("seau", curseur)
				return
	for i in bache.size():
		if bache[i] != cible[i]:
			var p := cible[i]
			if randf() < 0.04:
				p = (p + 1) % TifoRegles.PEINTURES.size()
			choisir_peinture(p)
			curseur = Vector2i(i % w, i / w)
			appliquer("pinceau", curseur)
			return
	presenter()


func _unhandled_input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed:
		return
	var k: int = ev.physical_keycode
	var dirs := {KEY_LEFT: Vector2i.LEFT, KEY_RIGHT: Vector2i.RIGHT, KEY_UP: Vector2i.UP, KEY_DOWN: Vector2i.DOWN}
	if dirs.has(k):
		bouger_curseur(dirs[k])
	elif ev.echo:
		return
	elif k >= KEY_1 and k <= KEY_5:
		choisir_peinture(k - KEY_1)
	elif k >= KEY_KP_1 and k <= KEY_KP_5:
		choisir_peinture(k - KEY_KP_1)
	elif k == KEY_P:
		choisir_outil("pinceau")
	elif k == KEY_S:
		choisir_outil("seau")
	elif k == KEY_TAB:
		choisir_outil("seau" if outil == "pinceau" else "pinceau")
	elif k == KEY_SPACE:
		appliquer(outil, curseur)
	elif k in [KEY_ENTER, KEY_KP_ENTER]:
		presenter()
	else:
		return
	get_viewport().set_input_as_handled()


func bouger_curseur(d: Vector2i) -> void:
	if modele.is_empty():
		return
	curseur = Vector2i(clampi(curseur.x + d.x, 0, modele["w"] - 1), clampi(curseur.y + d.y, 0, modele["h"] - 1))
	_grille.clavier = true
	_grille.queue_redraw()


func choisir_peinture(i: int) -> void:
	if i < 0 or i >= TifoRegles.PEINTURES.size():
		return
	if i != peinture and not auto:
		_sons.jouer("ui_clic", {"hauteur": 1.2})
	peinture = i
	_maj_outils()


func choisir_outil(o: String) -> void:
	if o != outil and not auto:
		_sons.jouer("ui_clic", {"hauteur": 0.9})
	outil = o
	_maj_outils()


## Peint la case `c` de la bâche avec l'outil `o` et la peinture choisie.
func appliquer(o: String, c: Vector2i) -> void:
	if not pret or termine or _en_transition or modele.is_empty():
		return
	var w: int = modele["w"]
	var h: int = modele["h"]
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return
	var n := 0
	if o == "seau":
		n = TifoRegles.seau(bache, w, h, c.x, c.y, peinture)
		if n > 0:
			_sons.jouer("fumigene", {"volume_db": -12, "hauteur": 1.6})
			_grille.eclabousser(c, n)
	elif bache[c.y * w + c.x] != peinture:
		bache[c.y * w + c.x] = peinture
		n = 1
		if _peint_son <= 0.0:
			_peint_son = 0.08
			_sons.jouer("ui_clic", {"volume_db": -14, "hauteur": randf_range(0.8, 1.3)})
	if n > 0:
		_grille.regler(bache, w, h)
		_maj_resse()


## Montre la bâche au capo : refusée (on continue) ou hissée et payée.
func presenter() -> void:
	if not pret or termine or _en_transition or modele.is_empty():
		return
	var r := TifoRegles.ressemblance(bache, modele["cases"])
	var parfaite := r >= 0.99999
	var p := TifoRegles.paye(modele["w"] * modele["h"], r, serie + 1 if parfaite else 0)
	if not p["accepte"]:
		refus += 1
		_sons.jouer("ui_rate")
		_dire(tr("Pas encore ! Il faut au moins %d %% de ressemblance.") % int(TifoRegles.SEUIL_REFUS * 100))
		_capo.jouer(&"huer", 0.8)
		Ui.pop(_lbl_resse.get_parent(), 1.15, 0.25)
		return
	if parfaite:
		serie += 1
		parfaites += 1
	else:
		serie = 0
	serie_max = maxi(serie_max, serie)
	salaire += p["salaire"]
	bonus += p["bonus"]
	hissees.append({"cases": bache.duplicate(), "w": modele["w"], "h": modele["h"], "ressemblance": r})
	_lbl_paye.text = str(salaire + bonus)
	Ui.pop(_lbl_paye, 1.25, 0.2)
	_dire(TifoRegles.appreciation(r) + (tr(" Série de %d !") % serie if serie >= 2 else ""))
	_gain_flottant("+%d" % p["total"] if p["bonus"] == 0 else "+%d  %s" % [p["total"], TifoRegles.appreciation(r)], Ui.JAUNE)
	_sons.jouer("ui_parfait" if parfaite else "ui_bien")
	_sons.jouer("tifo", {"volume_db": -4})
	if parfaite and serie >= TifoRegles.SERIE_BONUS:
		_sons.jouer("ui_combo_%d" % clampi(serie / TifoRegles.SERIE_BONUS, 1, 4))
	_capo.jouer(&"celebrer" if parfaite else &"applaudir", 1.4)
	_hisser()


## La bâche finie monte vers la tribune, une nouvelle arrive.
func _hisser() -> void:
	_en_transition = true
	var copie := Grille.new()
	copie.regler(bache.duplicate(), modele["w"], modele["h"])
	copie.position = _grille.position
	copie.size = _grille.size
	copie.pivot_offset = _grille.size / 2.0
	copie.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(copie)
	move_child(copie, _grille.get_index() + 1)
	_grille.visible = false
	var tw := copie.create_tween().set_parallel()
	tw.tween_property(copie, "position:y", -copie.size.y - 40, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.25)
	tw.tween_property(copie, "scale", Vector2.ONE * 0.6, 0.7).set_delay(0.25)
	tw.chain().tween_callback(copie.queue_free)
	_sons.jouer("applaudissements", {"volume_db": -10})
	await get_tree().create_timer(0.55).timeout
	if termine:
		return
	_nouvelle_bache()
	_grille.visible = true
	_grille.position.y = ZONE_BACHE.position.y + 700
	var t2 := _grille.create_tween()
	t2.tween_property(_grille, "position:y", ZONE_BACHE.position.y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await t2.finished
	_en_transition = false
	_auto_prochain = 0.4


func _maj_resse() -> void:
	var r := TifoRegles.ressemblance(bache, modele["cases"])
	_lbl_resse.text = tr("Ressemblance %d %%") % int(floor(r * 100.0 + 0.0001))
	_lbl_resse.add_theme_color_override("font_color", Ui.VERT if r >= 0.99999 else (Ui.JAUNE if r >= TifoRegles.SEUIL_REFUS else Ui.BLANC))


func _maj_outils() -> void:
	for i in _pots.size():
		var b: Button = _pots[i]
		b.scale = Vector2.ONE * (1.08 if i == peinture else 0.92)
		b.modulate = Color.WHITE if i == peinture else Color(0.8, 0.8, 0.85)
	if _btn_pinceau:
		Ui.colorer_bouton(_btn_pinceau, Ui.BLEU if outil == "pinceau" else Ui.NUIT_CLAIR)
		Ui.colorer_bouton(_btn_seau, Ui.BLEU if outil == "seau" else Ui.NUIT_CLAIR)
	if _grille:
		_grille.queue_redraw()


func _gain_flottant(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 60, couleur, true, 12)
	l.position = Vector2(ZONE_BACHE.get_center().x - 160, ZONE_BACHE.get_center().y - 40)
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 160.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------------ fin

func _finir() -> void:
	termine = true
	_en_transition = true
	_sons.jouer("sifflet_fin")
	_sons.ambiance("stade", 1)
	var brut := salaire + bonus
	var deja := Game.services_boulot_du_jour("tifo")
	var paye := TifoRegles.paye_finale(brut, deja)
	var record := paye > Game.record_boulot("tifo") and paye > 0
	var xp := hissees.size() * TifoRegles.XP_PAR_TIFO
	Game.finir_boulot("tifo", paye)
	Game.ajouter_xp(xp)
	if paye > 0:
		_sons.jouer("applaudissements", {"volume_db": -4})
		_capo.jouer(&"sauter")
	else:
		_capo.jouer(&"depit")

	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.65, 0.4)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -520
	pan.offset_right = 520
	pan.offset_top = -420
	pan.offset_bottom = 420
	add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label("LES TIFOS SONT PRÊTS !" if not hissees.is_empty() else "FIN DU TEMPS !", 52, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if record:
		var r := Ui.pastille("NOUVEAU RECORD", Ui.ROSE, 22)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	# les bâches hissées, en miniature
	if not hissees.is_empty():
		var hm := Ui.hbox(12)
		hm.alignment = BoxContainer.ALIGNMENT_CENTER
		for b in hissees.slice(-6):
			var g := Grille.new()
			g.regler(b["cases"], b["w"], b["h"])
			g.custom_minimum_size = Vector2(150, 90)
			g.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hm.add_child(g)
		v.add_child(hm)
	var lignes := [
		["Bâches hissées", str(hissees.size())],
		["Parfaites", str(parfaites)],
		["Refusées par le capo", str(refus)],
		["Meilleure série de parfaites", "x%d" % serie_max],
		["Salaire", "+%d" % salaire],
		["Bonus", "+%d" % bonus],
	]
	if paye < brut:
		lignes.append([tr("Fatigue (%de service du jour)") % (deja + 1), tr("paye ÷ 2")])
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
	var retour := Ui.bouton("Petits boulots", Ui.BLEU, 30)
	retour.custom_minimum_size = Vector2(380, 90)
	retour.pressed.connect(_retour_carte)
	hb.add_child(retour)
	var rejouer := Ui.bouton("Nouveau service", Ui.VERT, 30)
	Ui.colorer_bouton(rejouer, Ui.VERT, true)
	rejouer.custom_minimum_size = Vector2(330, 90)
	var pp: Dictionary = Game.params
	rejouer.pressed.connect(func(): Game.aller(Game.SCENE_TIFO, pp))
	hb.add_child(rejouer)
	v.add_child(hb)
	pan.pivot_offset = Vector2(520, 420)
	pan.scale = Vector2.ONE * 0.6
	pan.create_tween().tween_property(pan, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _retour_carte() -> void:
	Game.aller(Game.SCENE_BOULOTS, Game.params)


# ================================================================== éléments dessinés

## Une bâche (grande et peinte à la souris, ou miniature du modèle).
class Grille extends Control:
	var tifo: Tifo
	var interactive := false
	var clavier := false
	var cases := PackedInt32Array()
	var w := 1
	var h := 1
	var _peint := false
	var _survol := Vector2i(-1, -1)
	var _taches: Array = []     # [centre, rayon, couleur, âge]

	func regler(c: PackedInt32Array, largeur: int, hauteur: int) -> void:
		cases = c
		w = largeur
		h = hauteur
		queue_redraw()

	## Rectangle de la toile dans le contrôle, cases carrées et centrées.
	func toile() -> Rect2:
		var marge := 26.0 if interactive else 6.0
		var cote := minf((size.x - 2 * marge) / w, (size.y - 2 * marge) / h)
		var t := Vector2(cote * w, cote * h)
		return Rect2((size - t) / 2.0, t)

	func case_sous(p: Vector2) -> Vector2i:
		var t := toile()
		if not t.has_point(p):
			return Vector2i(-1, -1)
		var cote := t.size.x / w
		return Vector2i(clampi(int((p.x - t.position.x) / cote), 0, w - 1), clampi(int((p.y - t.position.y) / cote), 0, h - 1))

	func eclabousser(c: Vector2i, n: int) -> void:
		var t := toile()
		var cote := t.size.x / w
		_taches.append([t.position + (Vector2(c) + Vector2(0.5, 0.5)) * cote, cote * (1.0 + sqrt(n) * 0.5), TifoRegles.couleur(tifo.peinture), 0.0])

	func _process(delta: float) -> void:
		if _taches.is_empty():
			return
		for tc in _taches:
			tc[3] += delta
		_taches = _taches.filter(func(tc): return tc[3] < 0.35)
		queue_redraw()

	func _gui_input(ev: InputEvent) -> void:
		if not interactive or tifo == null:
			return
		if ev is InputEventMouseButton:
			var c := case_sous(ev.position)
			if ev.button_index == MOUSE_BUTTON_LEFT:
				_peint = ev.pressed and tifo.outil == "pinceau"
				if ev.pressed and c.x >= 0:
					tifo.curseur = c
					tifo.appliquer(tifo.outil, c)
			elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed and c.x >= 0:
				tifo.curseur = c
				tifo.appliquer("seau", c)
			accept_event()
		elif ev is InputEventMouseMotion:
			var c2 := case_sous(ev.position)
			clavier = false
			if c2 != _survol:
				_survol = c2
				queue_redraw()
			if _peint and c2.x >= 0 and ev.button_mask & MOUSE_BUTTON_MASK_LEFT:
				tifo.curseur = c2
				tifo.appliquer("pinceau", c2)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			_survol = Vector2i(-1, -1)
			_peint = false
			queue_redraw()

	func _draw() -> void:
		var t := toile()
		if cases.size() != w * h:
			return
		var cote := t.size.x / w
		if interactive:
			# cordes qui tiennent la bâche, ombre et ourlet
			draw_line(t.position + Vector2(10, 4), Vector2(t.position.x - 30, -30), Color("#c9a66b"), 6)
			draw_line(Vector2(t.end.x - 10, t.position.y + 4), Vector2(t.end.x + 30, -30), Color("#c9a66b"), 6)
			draw_rect(Rect2(t.position + Vector2(10, 14), t.size), Color(0, 0, 0, 0.3))
		draw_rect(t.grow(4 if interactive else 3), Ui.CONTOUR)
		for j in h:
			for i in w:
				var v := cases[j * w + i]
				var r := Rect2(t.position + Vector2(i, j) * cote, Vector2(cote, cote))
				var col := TifoRegles.couleur(v)
				if v != TifoRegles.VIERGE and interactive:
					col = col.darkened(0.04 * ((i * 7 + j * 3) % 3))  # coups de pinceau
				draw_rect(r, col)
				if v == TifoRegles.VIERGE and interactive:
					# toile écrue : petit point de couture au centre
					draw_circle(r.get_center(), maxf(1.5, cote * 0.04), Color("#d6c9a8"))
		if interactive:
			# trame légère pour repérer les cases
			for i in range(1, w):
				draw_line(t.position + Vector2(i * cote, 0), t.position + Vector2(i * cote, t.size.y), Color(0, 0, 0, 0.1), 1.0)
			for j in range(1, h):
				draw_line(t.position + Vector2(0, j * cote), t.position + Vector2(t.size.x, j * cote), Color(0, 0, 0, 0.1), 1.0)
			# œillets aux coins
			for p in [t.position, Vector2(t.end.x, t.position.y), Vector2(t.position.x, t.end.y), t.end]:
				draw_circle(p, 9, Ui.CONTOUR)
				draw_circle(p, 5, Color("#c9a66b"))
			for tc in _taches:
				var a: float = 1.0 - tc[3] / 0.35
				draw_circle(tc[0], tc[1] * (0.6 + tc[3] * 2.0), Color(tc[2], 0.35 * a))
			if tifo:
				var c := tifo.curseur if clavier or tifo.auto else _survol
				if c.x >= 0:
					var r2 := Rect2(t.position + Vector2(c) * cote, Vector2(cote, cote))
					draw_rect(r2.grow(3), Ui.CONTOUR, false, 6)
					draw_rect(r2.grow(1), TifoRegles.couleur(tifo.peinture), false, 3)


## Pot de peinture dessiné.
class Pot extends Control:
	var couleur := Color.WHITE

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) / 2.0
		var lw := maxf(3.0, s * 0.05)
		var corps := PackedVector2Array([o + Vector2(s * 0.18, s * 0.3), o + Vector2(s * 0.82, s * 0.3), o + Vector2(s * 0.76, s * 0.94), o + Vector2(s * 0.24, s * 0.94)])
		draw_colored_polygon(corps, Color("#d9d6ee"))
		var ferme := corps.duplicate()
		ferme.append(corps[0])
		draw_polyline(ferme, Ui.CONTOUR, lw, true)
		draw_rect(Rect2(o + Vector2(s * 0.21, s * 0.5), Vector2(s * 0.58, s * 0.2)), couleur)
		# coulure de peinture sur le bord
		draw_rect(Rect2(o + Vector2(s * 0.14, s * 0.22), Vector2(s * 0.72, s * 0.12)), Ui.CONTOUR)
		draw_rect(Rect2(o + Vector2(s * 0.17, s * 0.24), Vector2(s * 0.66, s * 0.08)), couleur)
		draw_circle(o + Vector2(s * 0.3, s * 0.4), s * 0.06, couleur)
		draw_rect(Rect2(o + Vector2(s * 0.27, s * 0.32), Vector2(s * 0.06, s * 0.08)), couleur)
		# anse
		draw_arc(o + Vector2(s * 0.5, s * 0.3), s * 0.3, PI, TAU, 16, Ui.CONTOUR, lw)


## L'atelier sous la tribune : mur de béton peint, bâches en attente, projecteurs.
class Atelier extends Control:
	func _draw() -> void:
		var w := size.x
		var hh := size.y
		draw_rect(Rect2(0, 0, w, hh), Color("#2d2670"))
		# rangées de la tribune vues par en dessous (marches en biais)
		for i in 9:
			var y := 104.0 + i * 26.0
			draw_rect(Rect2(0, y, w, 14), Color("#3a3290").lerp(Color("#241e5c"), i / 9.0))
		# sol de l'atelier
		draw_rect(Rect2(0, 800, w, hh - 800), Color("#1a1640"))
		draw_line(Vector2(0, 800), Vector2(w, 800), Ui.CONTOUR, 6)
		# taches de peinture au sol
		var taches := [[Vector2(120, 960), 38, Ui.ROSE], [Vector2(1760, 1000), 44, Ui.BLEU], [Vector2(980, 840), 22, Ui.JAUNE], [Vector2(1500, 860), 28, Ui.VIOLET], [Vector2(420, 1040), 30, Ui.BLANC]]
		for t in taches:
			draw_circle(t[0], t[1], Color(t[2], 0.35))
			draw_circle(t[0] + Vector2(t[1] * 0.9, -t[1] * 0.4), t[1] * 0.3, Color(t[2], 0.35))
