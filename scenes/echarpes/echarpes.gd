class_name StandEcharpes
extends Control
## Petit boulot de supporter : vendeur au stand d'écharpes, devant le stade (60 s).
##   1 à 6 (ou clic) : tendre l'écharpe de ce crochet au client
##   R : aller chercher le carton (réassort de tous les crochets)
## Les FANZZY font la queue et montrent l'écusson de leur club. Les écharpes
## du portant n'ont que les couleurs : à toi de trouver la bonne, vite.
## À 30 s, l'ouverture des portes : le rush, deux clubs de plus sur le portant.
## Règles dans EcharpesRegles. Option « --auto » : le service se joue tout seul.

const SonsScript := preload("res://scripts/audio/sons.gd")

const COMPTOIR_Y := 650.0
const X_CLIENT := 1180.0
const PIEDS_CLIENT := 760.0
const HAUTEUR_CLIENT := 470.0
const PLACES_FILE := [Vector2(1560, 640), Vector2(1760, 630)]
const HAUTEUR_FILE := 300.0
const TOUCHES := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6]
const TOUCHES_PAVE := [KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5, KEY_KP_6]

var regles := EcharpesRegles.new()
var temps := 0.0
var pret := false
var termine := false
var auto := "--auto" in OS.get_cmdline_user_args()

var clubs: Array = []          # les 6 clubs du portant ({nom, sigle, c1, c2})
var stock: Array = []          # écharpes restantes par crochet
var en_rayon := EcharpesRegles.CLUBS_CALME
var commande := {}
var remises: Array = []        # indices déjà tendus pour la commande en cours
var patience := 0.0
var reassort := 0.0            # temps restant au carton (0 = derrière le stand)
var numero := 0
var serie := 0
var serie_max := 0
var servis := 0
var rates := 0
var vendues := 0
var salaire := 0
var pourboires := 0
var bonus := 0

var _client: FanzzyAnime
var _file: Array = []
var _ids: Array = []
var _rush := false
var _auto_prochain := 0.0
var _sons: Node

var _fond: Decor
var _clients: Node2D
var _comptoir: Decor
var _bulle: PanelContainer
var _bulle_clubs: HBoxContainer
var _barre_patience: ProgressBar
var _sac_box: HBoxContainer
var _lbl_temps: Label
var _lbl_paye: Label
var _lbl_serie: Label
var _crochets: Array = []      # Button par crochet
var _btn_carton: Button


func _ready() -> void:
	_sons = SonsScript.new()
	_sons.name = "Sons"
	add_child(_sons)
	_ids = Buvette.ids_clients()
	_ids.shuffle()
	clubs = regles.portant(EcharpesRegles.clubs_connus())
	for i in clubs.size():
		stock.append(EcharpesRegles.STOCK_CROCHET)
	_construire()
	_sons.ambiance("stade", 0)
	_compte_a_rebours()


# ------------------------------------------------------------------ construction

func _construire() -> void:
	_fond = Decor.new()
	_fond.stand = self
	_fond.couche = 0
	_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fond)
	_clients = Node2D.new()
	_clients.name = "Clients"
	add_child(_clients)
	_comptoir = Decor.new()
	_comptoir.stand = self
	_comptoir.couche = 1
	_comptoir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_comptoir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_comptoir)

	# --- sac posé sur le comptoir : les écharpes déjà tendues au client
	var pl := PanelContainer.new()
	var sp := Ui.boite(Color("#d9d6ee"), 26, 5, 6)
	pl.add_theme_stylebox_override("panel", sp)
	pl.position = Vector2(X_CLIENT - 520, COMPTOIR_Y + 22)
	pl.custom_minimum_size = Vector2(380, 110)
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pl)
	_sac_box = Ui.hbox(14)
	_sac_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pl.add_child(_sac_box)

	# --- bulle : l'écusson (ou les deux écussons) voulu(s)
	_bulle = PanelContainer.new()
	_bulle.add_theme_stylebox_override("panel", Ui.boite(Ui.BLANC, 30, 6, 8))
	_bulle.visible = false
	_bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bulle)
	var vb := Ui.vbox(8)
	_bulle.add_child(vb)
	_bulle_clubs = Ui.hbox(26)
	_bulle_clubs.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_bulle_clubs)
	_barre_patience = ProgressBar.new()
	_barre_patience.custom_minimum_size = Vector2(0, 18)
	_barre_patience.show_percentage = false
	_barre_patience.max_value = 1.0
	_barre_patience.add_theme_stylebox_override("background", Ui.boite(Color("#e4e1f5"), 9, 3))
	vb.add_child(_barre_patience)

	# --- haut : quitter, temps, série, paye
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
	quitter.pressed.connect(_retour)
	haut.add_child(quitter)
	var pt := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_temps = Ui.label("1:00", 40, Ui.BLANC, true, 6)
	_lbl_temps.custom_minimum_size = Vector2(110, 0)
	_lbl_temps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt.add_child(_lbl_temps)
	haut.add_child(pt)
	haut.add_child(Ui.espace())
	var ps := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_serie = Ui.label("Série x0", 30, Ui.BLANC, true, 6)
	ps.add_child(_lbl_serie)
	ps.tooltip_text = tr("Clients bien servis d'affilée : +1 Jeton tous les %d") % EcharpesRegles.SERIE_BONUS
	haut.add_child(ps)
	var pj := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 40))
	_lbl_paye = Ui.label("0", 34, Ui.JAUNE, true, 6)
	hj.add_child(_lbl_paye)
	pj.add_child(hj)
	pj.tooltip_text = "Paye du service (versée à la fin)"
	haut.add_child(pj)

	# --- bas : le portant (6 crochets) et le carton
	var bas := Ui.hbox(16)
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.offset_left = -940
	bas.offset_right = 940
	bas.offset_top = -262
	bas.offset_bottom = -58
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bas)
	for i in clubs.size():
		var b := _bouton_crochet(i)
		bas.add_child(b)
		_crochets.append(b)
		b.visible = i < en_rayon
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(12, 0)
	bas.add_child(sep)
	_btn_carton = Ui.bouton("Carton\n(R)", Ui.JAUNE, 30)
	Ui.colorer_bouton(_btn_carton, Ui.JAUNE, true)
	_btn_carton.custom_minimum_size = Vector2(220, 204)
	_btn_carton.focus_mode = Control.FOCUS_NONE
	_btn_carton.tooltip_text = "Remplir tous les crochets (touche R)"
	_btn_carton.pressed.connect(aller_au_carton)
	bas.add_child(_btn_carton)

	var info := Ui.label("1 à 6 : tendre l'écharpe aux couleurs du club  ·  R : carton", 20, Ui.GRIS)
	info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.offset_left = -600
	info.offset_right = 600
	info.offset_top = -46
	info.offset_bottom = -14
	add_child(info)

	for i in PLACES_FILE.size():
		_file.append(_nouveau_client(PLACES_FILE[i], HAUTEUR_FILE, true))
	_maj_sac()


func _bouton_crochet(i: int) -> Button:
	var b := Ui.bouton("", Ui.NUIT_CLAIR, 26)
	b.custom_minimum_size = Vector2(220, 204)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tr("Écharpe du crochet %d (touche %d)") % [i + 1, i + 1]
	b.pressed.connect(tendre.bind(i))
	var e := Echarpe.new()
	e.c1 = clubs[i]["c1"]
	e.c2 = clubs[i]["c2"]
	e.set_anchors_preset(Control.PRESET_FULL_RECT)
	e.offset_left = 40
	e.offset_right = -40
	e.offset_top = 14
	e.offset_bottom = -34
	e.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(e)
	var touche := Ui.pastille(str(i + 1), Ui.CONTOUR, 18)
	touche.position = Vector2(12, 10)
	touche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(touche)
	var st := Stock.new()
	st.stand = self
	st.indice = i
	st.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	st.offset_top = -32
	st.offset_bottom = -8
	st.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(st)
	return b


func _nouveau_client(place: Vector2, hauteur: float, depuis_dehors: bool) -> FanzzyAnime:
	var id: String = _ids[numero % _ids.size()] if not _ids.is_empty() else ""
	numero += 1
	var f := FanzzyAnime.creer(id)
	_clients.add_child(f)
	_clients.move_child(f, 0)
	f.scale = Vector2.ONE * Buvette.echelle(f, hauteur)
	f.modulate = Color(0.72, 0.7, 0.85)
	f.position = Vector2(2150, place.y) if depuis_dehors else place
	if depuis_dehors:
		f.create_tween().tween_property(f, "position", place, 0.9).set_trans(Tween.TRANS_SINE)
	f.jouer(&"repos")
	return f


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
	for t in ["3", "2", "1", "AU STAND !"]:
		l.text = t
		Ui.ajuster_taille(l, 200, get_viewport_rect().size.x - 120)
		l.pivot_offset = l.size / 2.0
		Ui.pop(l, 1.4, 0.3)
		_sons.jouer("ui_decompte_go" if t.length() > 1 else "ui_decompte")
		await get_tree().create_timer(0.7).timeout
	l.queue_free()
	pret = true
	_client_suivant()


func _client_suivant() -> void:
	if termine:
		return
	var f: FanzzyAnime = _file.pop_front()
	_client = f
	var tw := f.create_tween().set_parallel()
	tw.tween_property(f, "position", Vector2(X_CLIENT, PIEDS_CLIENT), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(f, "scale", Vector2.ONE * Buvette.echelle(f, HAUTEUR_CLIENT), 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_property(f, "modulate", Color.WHITE, 0.45)
	_clients.move_child(f, -1)
	for i in _file.size():
		_file[i].create_tween().tween_property(_file[i], "position", PLACES_FILE[i], 0.5).set_trans(Tween.TRANS_SINE)
	_file.append(_nouveau_client(PLACES_FILE[PLACES_FILE.size() - 1], HAUTEUR_FILE, true))
	await tw.finished
	if termine or not is_instance_valid(f):
		return
	commande = regles.commande(servis + rates, _rush, en_rayon)
	remises.clear()
	patience = commande["patience"]
	_afficher_commande()
	_auto_prochain = randf_range(0.6, 1.6)
	f.jouer(&"encourager", 0.6)


func _afficher_commande() -> void:
	for c in _bulle_clubs.get_children():
		c.queue_free()
	for i in commande["echarpes"]:
		var club: Dictionary = clubs[i]
		var v := Ui.vbox(4)
		var ec := Ui.ecusson(club["sigle"], club["c1"], club["c2"], 104)
		ec.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(ec)
		var l := Ui.label(club["nom"], 22, Ui.CONTOUR, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(l)
		_bulle_clubs.add_child(v)
	_bulle.visible = true
	_bulle.reset_size()
	await get_tree().process_frame
	_bulle.reset_size()
	var t := _bulle.get_combined_minimum_size()
	_bulle.size = t
	_bulle.position = Vector2(X_CLIENT - 230.0 - t.x, 250.0)
	_bulle.pivot_offset = Vector2(t.x, t.y)
	Ui.pop(_bulle, 1.12, 0.25)
	_fond.queue_redraw()


func _process(delta: float) -> void:
	_fond.queue_redraw()
	if not pret or termine:
		return
	temps += delta
	if not _rush and EcharpesRegles.en_rush(temps):
		_ouvrir_les_portes()
	var reste := maxf(0.0, EcharpesRegles.DUREE - temps)
	_lbl_temps.text = "%d:%02d" % [int(ceil(reste)) / 60, int(ceil(reste)) % 60]
	_lbl_temps.add_theme_color_override("font_color", Ui.ROUGE if reste < 10.0 else Ui.BLANC)
	if reassort > 0.0:
		reassort -= delta
		_btn_carton.text = tr("Carton…\n%.1f s") % maxf(0.0, reassort)
		if reassort <= 0.0:
			_fin_du_carton()
	if not commande.is_empty():
		patience -= delta
		var r := clampf(patience / float(commande["patience"]), 0.0, 1.0)
		_barre_patience.value = r
		var c := Ui.VERT if r > 0.5 else (Ui.JAUNE if r > 0.25 else Ui.ROUGE)
		_barre_patience.add_theme_stylebox_override("fill", Ui.boite(c, 9, 0))
		if r <= 0.3 and _client and _client.action != &"huer":
			_client.jouer(&"huer", 0.0)
		if patience <= 0.0:
			_echec("Trop lent…")
		elif auto:
			_jouer_tout_seul(delta)
	if temps >= EcharpesRegles.DUREE:
		_finir()


func _ouvrir_les_portes() -> void:
	_rush = true
	en_rayon = EcharpesRegles.CLUBS_RUSH
	for i in _crochets.size():
		if not _crochets[i].visible:
			_crochets[i].visible = true
			_crochets[i].pivot_offset = _crochets[i].custom_minimum_size / 2.0
			Ui.pop(_crochets[i], 1.2, 0.3)
	_annonce("LES PORTES OUVRENT : LE RUSH !", Ui.ROSE)
	_sons.jouer("sifflet_court")
	_sons.ambiance("stade", 2)


func _jouer_tout_seul(delta: float) -> void:
	if reassort > 0.0:
		return
	_auto_prochain -= delta
	if _auto_prochain > 0.0:
		return
	_auto_prochain = randf_range(0.3, 0.6)
	for i in commande["echarpes"]:
		if i in remises:
			continue
		if int(stock[i]) <= 0:
			aller_au_carton()
			return
		tendre(i if randf() > 0.06 else randi() % en_rayon)
		return


func _unhandled_input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	var k: int = ev.physical_keycode
	if k in TOUCHES:
		tendre(TOUCHES.find(k))
	elif k in TOUCHES_PAVE:
		tendre(TOUCHES_PAVE.find(k))
	elif k == KEY_R:
		aller_au_carton()
	else:
		return
	get_viewport().set_input_as_handled()


## Tend au client l'écharpe du crochet `i`.
func tendre(i: int) -> void:
	if not pret or termine or reassort > 0.0 or commande.is_empty():
		return
	if i < 0 or i >= en_rayon:
		return
	if int(stock[i]) <= 0:
		_sons.jouer("ui_rate", {"volume_db": -8})
		_gain_flottant("Crochet vide : carton (R) !", Ui.JAUNE)
		Ui.pop(_btn_carton, 1.12, 0.2)
		return
	if i in remises:
		return
	stock[i] = int(stock[i]) - 1
	_crochets[i].queue_redraw()
	for n in _crochets[i].get_children():
		n.queue_redraw()
	Ui.pop(_crochets[i], 1.06, 0.15)
	if not i in commande["echarpes"]:
		_echec("Pas son club !")
		return
	remises.append(i)
	vendues += 1
	_sons.jouer("ui_clic")
	_maj_sac()
	if remises.size() >= commande["echarpes"].size():
		_reussite()


func aller_au_carton() -> void:
	if not pret or termine or reassort > 0.0:
		return
	var plein := true
	for i in en_rayon:
		if int(stock[i]) < EcharpesRegles.STOCK_CROCHET:
			plein = false
	if plein:
		return
	reassort = EcharpesRegles.DUREE_REASSORT
	_sons.jouer("ui_clic", {"hauteur": 0.7})
	Ui.colorer_bouton(_btn_carton, Ui.GRIS, true)


func _fin_du_carton() -> void:
	reassort = 0.0
	for i in stock.size():
		stock[i] = EcharpesRegles.STOCK_CROCHET
	for b in _crochets:
		for n in b.get_children():
			n.queue_redraw()
	_btn_carton.text = "Carton\n(R)"
	Ui.colorer_bouton(_btn_carton, Ui.JAUNE, true)
	_sons.jouer("ui_bien", {"volume_db": -6})


func _reussite() -> void:
	serie += 1
	serie_max = maxi(serie_max, serie)
	servis += 1
	var reste := clampf(patience / float(commande["patience"]), 0.0, 1.0)
	var p := EcharpesRegles.paye(commande["echarpes"].size(), reste, serie)
	salaire += p["salaire"]
	pourboires += p["pourboire"]
	bonus += p["bonus"]
	_sons.jouer("ui_parfait" if reste > 0.6 else "ui_bien")
	if p["pourboire"] > 0:
		_sons.jouer("clap", {"volume_db": -6})
	if p["bonus"] > 0:
		_gain_flottant(tr("+%d  SÉRIE x%d !") % [p["total"], serie], Ui.JAUNE)
		_sons.jouer("ui_combo_%d" % clampi(serie / EcharpesRegles.SERIE_BONUS, 1, 4))
	else:
		_gain_flottant("+%d" % p["total"], Ui.JAUNE)
	# Le client repart en agitant sa nouvelle écharpe.
	var club: Dictionary = clubs[commande["echarpes"][0]]
	_client.couleurs_echarpe = PackedColorArray([club["c1"], club["c2"]])
	_client.jouer(&"agiter_echarpe")
	_partir(true)


func _echec(texte: String) -> void:
	rates += 1
	serie = 0
	_sons.jouer("ui_rate")
	_gain_flottant(texte, Ui.ROUGE)
	if _client:
		_client.jouer(&"huer" if patience > 0.0 else &"depit")
	_partir(false)


func _partir(content: bool) -> void:
	commande = {}
	remises.clear()
	_maj_sac()
	_bulle.visible = false
	_maj_hud()
	var f := _client
	_client = null
	if f:
		var tw := f.create_tween()
		tw.tween_interval(0.45 if content else 0.2)
		tw.tween_property(f, "position:x", -320.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(f.queue_free)
	if not termine:
		get_tree().create_timer(0.35).timeout.connect(_client_suivant)


func _maj_sac() -> void:
	for c in _sac_box.get_children():
		c.queue_free()
	if remises.is_empty():
		_sac_box.add_child(Ui.label("Sac vide", 26, Color("#8f8ab8"), true))
		return
	for i in remises:
		var e := Echarpe.new()
		e.c1 = clubs[i]["c1"]
		e.c2 = clubs[i]["c2"]
		e.custom_minimum_size = Vector2(70, 84)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_sac_box.add_child(e)


func _maj_hud() -> void:
	_lbl_paye.text = str(salaire + pourboires + bonus)
	Ui.pop(_lbl_paye, 1.25, 0.2)
	_lbl_serie.text = tr("Série x%d") % serie
	_lbl_serie.add_theme_color_override("font_color", Ui.JAUNE if serie >= EcharpesRegles.SERIE_BONUS else Ui.BLANC)


func _gain_flottant(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 54, couleur, true, 12)
	l.position = Vector2(X_CLIENT - 160, 300)
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", 170.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _annonce(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 84, couleur, true, 18)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = -395
	add_child(l)
	await get_tree().process_frame
	l.pivot_offset = l.size / 2.0
	Ui.pop(l, 1.3, 0.35)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ fin

func _finir() -> void:
	termine = true
	_bulle.visible = false
	commande = {}
	if _client:
		_client.jouer(&"depit")
	_sons.jouer("sifflet_fin")
	_sons.ambiance("stade", 1)
	var brut := salaire + pourboires + bonus
	var deja := Game.services_boulot_du_jour("echarpes")
	var paye := EcharpesRegles.paye_finale(brut, deja)
	var record := paye > Game.record_boulot("echarpes") and paye > 0
	var xp := servis * EcharpesRegles.XP_PAR_CLIENT
	Game.finir_boulot("echarpes", paye)
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
	var t := Ui.label("LE STAND FERME !", 56, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if record:
		var r := Ui.pastille("NOUVEAU RECORD", Ui.ROSE, 22)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	var lignes := [
		["Clients servis", str(servis)],
		["Écharpes vendues", str(vendues)],
		["Clients ratés", str(rates)],
		["Meilleure série", "x%d" % serie_max],
		["Salaire", "+%d" % salaire],
		["Pourboires", "+%d" % pourboires],
		["Bonus de série", "+%d" % bonus],
	]
	if paye < brut:
		lignes.append([tr("Fatigue (%de service du jour)") % (deja + 1), tr(ListeBoulots.texte_fatigue(deja))])
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
	var rejouer := Ui.bouton("Nouveau service", Ui.VERT, 30)
	Ui.colorer_bouton(rejouer, Ui.VERT, true)
	rejouer.custom_minimum_size = Vector2(330, 90)
	var p: Dictionary = Game.params
	rejouer.pressed.connect(func(): Game.aller(ListeBoulots.par_id("echarpes")["scene"], p))
	hb.add_child(rejouer)
	v.add_child(hb)
	pan.pivot_offset = Vector2(460, 360)
	pan.scale = Vector2.ONE * 0.6
	pan.create_tween().tween_property(pan, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _retour() -> void:
	Game.aller(Game.SCENE_BOULOTS, Game.params)  # retour à la liste des petits boulots


# ================================================================== éléments dessinés

## Décor : couche 0 = parvis du stade (ciel, façade, grilles, auvent, enseigne) ;
## couche 1 = comptoir du stand, devant les clients.
class Decor extends Control:
	var stand: StandEcharpes
	var couche := 0

	func _draw() -> void:
		if couche == 0:
			_parvis()
		else:
			_comptoir()

	func _parvis() -> void:
		var w := size.x
		var rush := stand != null and stand._rush and not stand.termine
		var t := Time.get_ticks_msec() / 1000.0
		# ciel du soir
		draw_rect(Rect2(0, 0, w, StandEcharpes.COMPTOIR_Y), Color("#ff9a6b"))
		draw_rect(Rect2(0, 0, w, 330), Color("#7c5cd6"))
		draw_rect(Rect2(0, 330, w, 60), Color("#c46fb0"))
		# façade du stade et ses grilles
		var f := Rect2(80, 250, w - 160, 340)
		draw_style_box(Ui.boite(Color("#3a3290"), 30, 8), f)
		for i in 6:
			var g := Rect2(f.position.x + 70 + i * (f.size.x - 140) / 6.0, f.position.y + 90, (f.size.x - 140) / 6.0 - 50, f.size.y - 90)
			var ouverte := rush
			draw_rect(g, Color("#1a1640") if not ouverte else Color("#ffd23f").darkened(0.15))
			if not ouverte:
				for b in 7:
					var x := g.position.x + 8 + b * (g.size.x - 16) / 6.0
					draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), Color("#8f8ab8"), 5)
			draw_rect(g, Ui.CONTOUR, false, 6)
		# fanions le long de la façade
		var nb := 22
		for i in nb:
			var x := f.position.x + 30 + i * (f.size.x - 60) / (nb - 1)
			var c := Ui.ROSE if i % 3 == 0 else (Ui.JAUNE if i % 3 == 1 else Ui.BLEU)
			var y0 := f.position.y + 30 + sin(t * (5.0 if rush else 1.5) + i) * 3.0
			draw_colored_polygon(PackedVector2Array([Vector2(x - 18, y0), Vector2(x + 18, y0), Vector2(x, y0 + 36)]), c)
		draw_line(Vector2(f.position.x + 10, f.position.y + 30), Vector2(f.end.x - 10, f.position.y + 30), Ui.CONTOUR, 4)
		# sol du parvis
		draw_rect(Rect2(0, 580, w, StandEcharpes.COMPTOIR_Y - 580), Color("#4a428f"))
		# auvent rayé à festons
		var bandes := 16
		var lb := w / bandes
		for i in bandes:
			var c2 := Ui.VERT if i % 2 == 0 else Ui.BLANC
			draw_rect(Rect2(i * lb, 110, lb, 90), c2)
			draw_circle(Vector2(i * lb + lb / 2.0, 200), lb / 2.0, c2)
		draw_rect(Rect2(0, 0, w, 116), Ui.NUIT)
		draw_line(Vector2(0, 113), Vector2(w, 113), Ui.CONTOUR, 6)
		# enseigne
		var e := Rect2(w / 2.0 - 300, 18, 600, 112)
		draw_style_box(Ui.boite(Ui.JAUNE, 26, 6, 8), e)
		var police := Ui.police_titre()
		var txt := tr("ÉCHARPES")
		var fs := 76
		var tw := police.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(e.get_center().x - tw / 2.0, e.get_center().y + fs * 0.34)
		draw_string_outline(police, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Ui.CONTOUR)
		draw_string(police, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.BLANC)
		# pointe de la bulle, vers le client
		if stand and stand._bulle.visible:
			var b := stand._bulle.get_rect()
			var a := Vector2(b.end.x - 6, b.position.y + 50)
			draw_colored_polygon(PackedVector2Array([a, a + Vector2(0, 60), a + Vector2(80, 10)]), Ui.CONTOUR)
			draw_colored_polygon(PackedVector2Array([a + Vector2(-8, 10), a + Vector2(-8, 46), a + Vector2(62, 14)]), Ui.BLANC)

	func _comptoir() -> void:
		var w := size.x
		var y := StandEcharpes.COMPTOIR_Y
		draw_rect(Rect2(0, y - 6, w, 34), Ui.CONTOUR)
		draw_rect(Rect2(0, y, w, 22), Color("#9be7c0"))
		draw_rect(Rect2(0, y + 28, w, 140), Color("#2fa36b"))
		for i in 24:
			var x := i * w / 24.0
			draw_line(Vector2(x, y + 28), Vector2(x, y + 168), Color("#1f7a4e"), 4)
		draw_rect(Rect2(0, y + 166, w, 8), Ui.CONTOUR)
		draw_rect(Rect2(0, y + 174, w, size.y - y - 174), Color("#1a1640"))


## Une écharpe qui pend, à rayures des deux couleurs du club, franges en bas.
## Pas de nom ni de sigle : seules les couleurs permettent de la reconnaître.
class Echarpe extends Control:
	var c1 := Ui.BLEU
	var c2 := Ui.BLANC

	func _draw() -> void:
		var h := size.y
		var lw := maxf(3.0, size.x * 0.05)
		var larg := minf(size.x * 0.62, h * 0.5)
		var x0 := (size.x - larg) / 2.0
		var haut := h * 0.06
		var bas := h * 0.84
		# crochet
		draw_arc(Vector2(size.x / 2.0, haut), h * 0.05, PI, TAU, 10, Ui.CONTOUR, lw * 0.8)
		var r := Rect2(x0, haut, larg, bas - haut)
		draw_rect(r.grow(lw * 0.6), Ui.CONTOUR)
		var n := 6
		for i in n:
			var y := haut + i * (bas - haut) / n
			draw_rect(Rect2(x0, y, larg, (bas - haut) / n + 0.5), c1 if i % 2 == 0 else c2)
		# franges
		var nf := 6
		for i in nf:
			var x := x0 + larg * (i + 0.5) / nf
			draw_line(Vector2(x, bas + lw * 0.6), Vector2(x, h), Ui.CONTOUR, lw * 0.9)
			draw_line(Vector2(x, bas + lw * 0.6), Vector2(x, h - lw * 0.4), c2 if i % 2 else c1, lw * 0.45)


## Petites pastilles sous un crochet : écharpes qui restent.
class Stock extends Control:
	var stand: StandEcharpes
	var indice := 0

	func _draw() -> void:
		if stand == null:
			return
		var n := EcharpesRegles.STOCK_CROCHET
		var reste := int(stand.stock[indice])
		var r := size.y * 0.32
		var pas := r * 3.0
		var x0 := size.x / 2.0 - pas * (n - 1) / 2.0
		for i in n:
			var c := Vector2(x0 + i * pas, size.y / 2.0)
			draw_circle(c, r + 3, Ui.CONTOUR)
			draw_circle(c, r, Ui.JAUNE if i < reste else Color("#4a428f"))
		if reste == 0:
			var f := Ui.police_titre()
			var t := tr("VIDE")
			var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
			draw_string(f, Vector2(size.x - w - 10, size.y * 0.75), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.ROUGE)
