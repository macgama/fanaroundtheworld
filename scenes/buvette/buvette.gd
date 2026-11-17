class_name Buvette
extends Control
## Petit boulot de supporter : vendeur à la buvette du stade (60 secondes).
##   1 à 4 (ou clic) : poser une boisson, un hot-dog, des frites, une gaufre
##   ENTRÉE ou ESPACE : servir le plateau · RETOUR ARRIÈRE : vider le plateau
## Les FANZZY font la queue au comptoir, chacun avec sa commande et sa
## patience. Commande juste = Jetons (salaire + pourboire si rapide).
## À 30 s, c'est la mi-temps : le rush. Règles dans BuvetteRegles.
## Option « --auto » (tests, captures) : le service se joue tout seul.

const SonsScript := preload("res://scripts/audio/sons.gd")

const COMPTOIR_Y := 650.0     # haut du comptoir : cache les jambes des clients
const X_CLIENT := 1060.0
const PIEDS_CLIENT := 760.0
const HAUTEUR_CLIENT := 470.0 # hauteur à l'écran du FANZZY au comptoir (pieds à la tête)
const PLACES_FILE := [Vector2(1470, 640), Vector2(1680, 630)]
const HAUTEUR_FILE := 300.0
const COULEURS := {"boisson": Ui.BLEU, "hotdog": Ui.ROSE, "frites": Ui.JAUNE, "gaufre": Ui.VIOLET}

var regles := BuvetteRegles.new()
var temps := 0.0
var pret := false
var termine := false
var auto := "--auto" in OS.get_cmdline_user_args()

var plateau := {}
var commande := {}
var patience := 0.0
var numero := 0
var serie := 0
var serie_max := 0
var servis := 0
var rates := 0
var salaire := 0
var pourboires := 0
var bonus := 0

var _client: FanzzyAnime
var _file: Array = []         # FanzzyAnime qui attendent
var _ids: Array = []
var _rush := false
var _auto_prochain := 0.0
var _sons: Node

var _fond: Decor
var _clients: Node2D
var _comptoir: Decor
var _bulle: PanelContainer
var _bulle_articles: HBoxContainer
var _barre_patience: ProgressBar
var _plateau_box: HBoxContainer
var _lbl_temps: Label
var _lbl_paye: Label
var _lbl_serie: Label
var _lbl_info: Label
var _boutons := {}
var _btn_servir: Button


func _ready() -> void:
	_sons = SonsScript.new()
	_sons.name = "Sons"
	add_child(_sons)
	_ids = Buvette.ids_clients()
	_ids.shuffle()
	_construire()
	_sons.ambiance("stade", 0)
	_compte_a_rebours()


## FANZZY qui viennent à la buvette : d'abord ceux qui ont leurs expressions
## (dossier de démo), puis le reste du catalogue.
static func ids_clients() -> Array:
	var res: Array = []
	var d := DirAccess.open("res://assets/fanzzy/demo")
	if d:
		for n in d.get_directories():
			res.append(n)
	for z in Game.fanzzy:
		if not z["id"] in res:
			res.append(z["id"])
	return res


# ------------------------------------------------------------------ construction

func _construire() -> void:
	_fond = Decor.new()
	_fond.buvette = self
	_fond.couche = 0
	_fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fond)
	_clients = Node2D.new()
	_clients.name = "Clients"
	add_child(_clients)
	_comptoir = Decor.new()
	_comptoir.buvette = self
	_comptoir.couche = 1
	_comptoir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_comptoir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_comptoir)

	# --- plateau posé sur le comptoir
	var pl := PanelContainer.new()
	var sp := Ui.boite(Color("#d9d6ee"), 26, 5, 6)
	sp.content_margin_left = 24
	sp.content_margin_right = 24
	pl.add_theme_stylebox_override("panel", sp)
	pl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	pl.offset_left = -330
	pl.offset_right = 330
	pl.offset_top = COMPTOIR_Y + 22
	pl.offset_bottom = COMPTOIR_Y + 132
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pl)
	_plateau_box = Ui.hbox(14)
	_plateau_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pl.add_child(_plateau_box)

	# --- bulle de commande
	_bulle = PanelContainer.new()
	_bulle.add_theme_stylebox_override("panel", Ui.boite(Ui.BLANC, 30, 6, 8))
	_bulle.visible = false
	_bulle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bulle)
	var vb := Ui.vbox(8)
	_bulle.add_child(vb)
	_bulle_articles = Ui.hbox(18)
	_bulle_articles.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(_bulle_articles)
	_barre_patience = ProgressBar.new()
	_barre_patience.custom_minimum_size = Vector2(0, 18)
	_barre_patience.show_percentage = false
	_barre_patience.max_value = 1.0
	_barre_patience.add_theme_stylebox_override("background", Ui.boite(Color("#e4e1f5"), 9, 3))
	vb.add_child(_barre_patience)

	# --- haut : temps, paye, série
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
	var ps := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_serie = Ui.label("Série x0", 30, Ui.BLANC, true, 6)
	ps.add_child(_lbl_serie)
	ps.tooltip_text = tr("Commandes justes d'affilée : +1 Jeton toutes les %d") % BuvetteRegles.SERIE_BONUS
	haut.add_child(ps)
	var pj := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 40))
	_lbl_paye = Ui.label("0", 34, Ui.JAUNE, true, 6)
	hj.add_child(_lbl_paye)
	pj.add_child(hj)
	pj.tooltip_text = "Paye du service (versée à la fin)"
	haut.add_child(pj)

	# --- bas : les quatre articles, servir, vider
	var bas := Ui.hbox(20)
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.offset_left = -900
	bas.offset_right = 900
	bas.offset_top = -250
	bas.offset_bottom = -58
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bas)
	for p in BuvetteRegles.PRODUITS:
		var b := _bouton_produit(p)
		bas.add_child(b)
		_boutons[p["id"]] = b
	var sep := Control.new()
	sep.custom_minimum_size = Vector2(20, 0)
	bas.add_child(sep)
	var vs := Ui.vbox(14)
	bas.add_child(vs)
	_btn_servir = Ui.bouton("SERVIR", Ui.VERT, 44)
	Ui.colorer_bouton(_btn_servir, Ui.VERT, true)
	_btn_servir.custom_minimum_size = Vector2(330, 118)
	_btn_servir.focus_mode = Control.FOCUS_NONE
	_btn_servir.tooltip_text = "ENTRÉE ou ESPACE"
	_btn_servir.pressed.connect(servir)
	vs.add_child(_btn_servir)
	var vider := Ui.bouton("Vider le plateau", Ui.ROUGE, 24)
	vider.custom_minimum_size = Vector2(330, 60)
	vider.focus_mode = Control.FOCUS_NONE
	vider.tooltip_text = "RETOUR ARRIÈRE"
	vider.pressed.connect(vider_plateau)
	vs.add_child(vider)

	_lbl_info = Ui.label("1 à 4 : poser un article  ·  ENTRÉE : servir  ·  RETOUR ARRIÈRE : vider", 20, Ui.GRIS)
	_lbl_info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_info.offset_left = -600
	_lbl_info.offset_right = 600
	_lbl_info.offset_top = -46
	_lbl_info.offset_bottom = -14
	add_child(_lbl_info)

	for i in PLACES_FILE.size():
		_file.append(_nouveau_client(PLACES_FILE[i], HAUTEUR_FILE, true))
	_maj_plateau()


func _bouton_produit(p: Dictionary) -> Button:
	var c: Color = COULEURS[p["id"]]
	var b := Ui.bouton("", c, 26)
	Ui.colorer_bouton(b, c)
	b.custom_minimum_size = Vector2(250, 192)
	b.focus_mode = Control.FOCUS_NONE
	b.tooltip_text = tr("%s (touche %s)") % [tr(p["nom"]), p["touche"]]
	b.pressed.connect(poser.bind(p["id"]))
	var v := Ui.vbox(0)
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var ic := Buvette.icone_produit(p["id"], 104)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l := Ui.label(p["nom"], 28, Ui.BLANC, true, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(l)
	var touche := Ui.pastille(p["touche"], Ui.CONTOUR, 18)
	touche.position = Vector2(14, 12)
	touche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(touche)
	return b


## Échelle pour que le personnage (sans le vide autour de l'image) mesure `hauteur` pixels.
static func echelle(f: FanzzyAnime, hauteur: float) -> float:
	if f.texture == null:
		return 0.5
	return hauteur / maxf(1.0, FanzzyAnime._zone_utile(f.texture).size.y)


static func icone_produit(id: String, taille := 80) -> Control:
	var i := Produit.new()
	i.type = id
	i.custom_minimum_size = Vector2(taille, taille)
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


func _nouveau_client(place: Vector2, hauteur: float, depuis_dehors: bool) -> FanzzyAnime:
	var id: String = _ids[numero % _ids.size()] if not _ids.is_empty() else ""
	numero += 1
	var f := FanzzyAnime.creer(id)
	f.couleurs_echarpe = PackedColorArray([Ui.ROSE, Ui.BLANC]) if randf() < 0.5 else PackedColorArray([Ui.BLEU, Ui.JAUNE])
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
	for t in ["3", "2", "1", "SERVICE !"]:
		l.text = t
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
	# la file avance et un nouveau supporter arrive au bout
	for i in _file.size():
		_file[i].create_tween().tween_property(_file[i], "position", PLACES_FILE[i], 0.5).set_trans(Tween.TRANS_SINE)
	_file.append(_nouveau_client(PLACES_FILE[PLACES_FILE.size() - 1], HAUTEUR_FILE, true))
	await tw.finished
	if termine or not is_instance_valid(f):
		return
	commande = regles.commande(servis + rates, _rush)
	patience = commande["patience"]
	_afficher_commande()
	_auto_prochain = randf_range(0.8, 2.2)
	f.jouer(&"encourager", 0.6)


func _afficher_commande() -> void:
	for c in _bulle_articles.get_children():
		c.queue_free()
	for id in BuvetteRegles.ids():
		var n := int(commande["articles"].get(id, 0))
		if n == 0:
			continue
		var h := Ui.hbox(2)
		h.add_child(Buvette.icone_produit(id, 92))
		if n > 1:
			var l := Ui.label("x%d" % n, 40, Ui.CONTOUR, true)
			l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(l)
		_bulle_articles.add_child(h)
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
	if not _rush and BuvetteRegles.en_rush(temps):
		_rush = true
		_annonce("MI-TEMPS : LE RUSH !", Ui.ROSE)
		_sons.jouer("sifflet_court")
		_sons.ambiance("stade", 2)
	var reste := maxf(0.0, BuvetteRegles.DUREE - temps)
	_lbl_temps.text = "%d:%02d" % [int(ceil(reste)) / 60, int(ceil(reste)) % 60]
	_lbl_temps.add_theme_color_override("font_color", Ui.ROUGE if reste < 10.0 else Ui.BLANC)
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
	if temps >= BuvetteRegles.DUREE:
		_finir()


func _jouer_tout_seul(delta: float) -> void:
	_auto_prochain -= delta
	if _auto_prochain > 0.0:
		return
	_auto_prochain = randf_range(0.25, 0.5)
	for id in BuvetteRegles.ids():
		if int(plateau.get(id, 0)) < int(commande["articles"].get(id, 0)):
			poser(id if randf() > 0.06 else BuvetteRegles.ids().pick_random())
			return
	servir()


func _unhandled_input(ev: InputEvent) -> void:
	if not ev is InputEventKey or not ev.pressed or ev.echo:
		return
	var k: int = ev.physical_keycode
	var touches := {KEY_1: 0, KEY_2: 1, KEY_3: 2, KEY_4: 3, KEY_KP_1: 0, KEY_KP_2: 1, KEY_KP_3: 2, KEY_KP_4: 3}
	if touches.has(k):
		poser(BuvetteRegles.PRODUITS[touches[k]]["id"])
	elif k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		servir()
	elif k in [KEY_BACKSPACE, KEY_DELETE]:
		vider_plateau()
	else:
		return
	get_viewport().set_input_as_handled()


func poser(id: String) -> void:
	if not pret or termine:
		return
	if int(plateau.get(id, 0)) >= BuvetteRegles.MAX_PAR_ARTICLE:
		_sons.jouer("ui_rate", {"volume_db": -8})
		return
	plateau[id] = int(plateau.get(id, 0)) + 1
	_sons.jouer("ui_clic")
	Ui.pop(_boutons[id], 1.06, 0.15)
	_maj_plateau()


func vider_plateau() -> void:
	if plateau.is_empty():
		return
	plateau.clear()
	_sons.jouer("ui_clic", {"hauteur": 0.8})
	_maj_plateau()


func servir() -> void:
	if not pret or termine or commande.is_empty() or plateau.is_empty():
		return
	if not BuvetteRegles.conforme(plateau, commande["articles"]):
		_echec("Pas ce qu'il a commandé !")
		return
	serie += 1
	serie_max = maxi(serie_max, serie)
	servis += 1
	var reste := clampf(patience / float(commande["patience"]), 0.0, 1.0)
	var p := BuvetteRegles.paye(commande["articles"], reste, serie)
	salaire += p["salaire"]
	pourboires += p["pourboire"]
	bonus += p["bonus"]
	_sons.jouer("ui_parfait" if reste > 0.6 else "ui_bien")
	if p["pourboire"] > 0:
		_sons.jouer("clap", {"volume_db": -6})
	if p["bonus"] > 0:
		_gain_flottant(tr("+%d  SÉRIE x%d !") % [p["total"], serie], Ui.JAUNE)
		_sons.jouer("ui_combo_%d" % clampi(serie / BuvetteRegles.SERIE_BONUS, 1, 4))
	else:
		_gain_flottant("+%d" % p["total"], Ui.JAUNE)
	_client.jouer(&"celebrer")
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
	plateau.clear()
	_maj_plateau()
	_bulle.visible = false
	_maj_hud()
	var f := _client
	_client = null
	if f:
		var tw := f.create_tween()
		tw.tween_interval(0.35 if content else 0.2)
		tw.tween_property(f, "position:x", -320.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(f.queue_free)
	if not termine:
		get_tree().create_timer(0.35).timeout.connect(_client_suivant)


func _maj_plateau() -> void:
	for c in _plateau_box.get_children():
		c.queue_free()
	if plateau.is_empty():
		var l := Ui.label("Plateau vide", 26, Color("#8f8ab8"), true)
		_plateau_box.add_child(l)
		return
	for id in BuvetteRegles.ids():
		for i in int(plateau.get(id, 0)):
			_plateau_box.add_child(Buvette.icone_produit(id, 78))


func _maj_hud() -> void:
	_lbl_paye.text = str(salaire + pourboires + bonus)
	Ui.pop(_lbl_paye, 1.25, 0.2)
	_lbl_serie.text = tr("Série x%d") % serie
	_lbl_serie.add_theme_color_override("font_color", Ui.JAUNE if serie >= BuvetteRegles.SERIE_BONUS else Ui.BLANC)



func _gain_flottant(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 54, couleur, true, 12)
	l.position = Vector2(X_CLIENT - 120, 300)
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
	var deja := Game.services_buvette_du_jour()
	var paye := BuvetteRegles.paye_finale(brut, deja)
	var record := paye > Game.buvette_record and paye > 0
	var xp := servis * BuvetteRegles.XP_PAR_CLIENT
	Game.finir_service_buvette(paye)
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
	pan.offset_top = -350
	pan.offset_bottom = 350
	add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label("FIN DU SERVICE !", 56, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if record:
		var r := Ui.pastille("NOUVEAU RECORD", Ui.ROSE, 22)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	var lignes := [
		["Clients servis", str(servis)],
		["Commandes ratées", str(rates)],
		["Meilleure série", "x%d" % serie_max],
		["Salaire", "+%d" % salaire],
		["Pourboires", "+%d" % pourboires],
		["Bonus de série", "+%d" % bonus],
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
	var retour := Ui.bouton("Retour à la carte", Ui.BLEU, 30)
	retour.custom_minimum_size = Vector2(380, 90)
	retour.pressed.connect(_retour_carte)
	hb.add_child(retour)
	var rejouer := Ui.bouton("Nouveau service", Ui.VERT, 30)
	Ui.colorer_bouton(rejouer, Ui.VERT, true)
	rejouer.custom_minimum_size = Vector2(330, 90)
	var p: Dictionary = Game.params
	rejouer.pressed.connect(func(): Game.aller(Game.SCENE_BUVETTE, p))
	hb.add_child(rejouer)
	v.add_child(hb)
	pan.pivot_offset = Vector2(460, 350)
	pan.scale = Vector2.ONE * 0.6
	pan.create_tween().tween_property(pan, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _retour_carte() -> void:
	var p: Dictionary = Game.params
	Game.aller(Game.SCENE_CARTE, {"niveau": p.get("niveau", "monde"), "continent": p.get("continent", ""), "pays": p.get("pays", "")})


# ================================================================== éléments dessinés

## Le décor : couche 0 = coursive du stade (mur, ouverture sur la tribune,
## auvent, enseigne) ; couche 1 = comptoir et plan de travail, devant les clients.
class Decor extends Control:
	var buvette: Buvette
	var couche := 0

	func _draw() -> void:
		if couche == 0:
			_coursive()
		else:
			_comptoir()

	func _coursive() -> void:
		var w := size.x
		var rush := buvette != null and buvette._rush and not buvette.termine
		draw_rect(Rect2(0, 0, w, Buvette.COMPTOIR_Y), Color("#2d2670"))
		# ouverture sur la tribune et le terrain
		var o := Rect2(120, 250, w - 240, 330)
		draw_style_box(Ui.boite(Ui.CONTOUR, 34, 0), o.grow(10))
		draw_style_box(Ui.boite(Color("#7fc4ff"), 30, 0), o)
		var t := Time.get_ticks_msec() / 1000.0
		for rang in 5:
			var y := o.position.y + 40 + rang * 44
			draw_rect(Rect2(o.position.x + 20, y + 18, o.size.x - 40, 30), Color("#3a3290").lerp(Color("#5a4fc0"), rang / 5.0))
			var n := 46
			for i in n:
				var x := o.position.x + 40 + i * (o.size.x - 80) / (n - 1)
				var saut := sin(t * (6.0 if rush else 2.0) + i * 0.7 + rang) * (8.0 if rush else 2.5)
				var c := Ui.ROSE if (i + rang) % 3 == 0 else (Ui.BLANC if (i + rang) % 3 == 1 else Ui.JAUNE)
				draw_circle(Vector2(x, y + 12 + saut), 11, c.darkened(0.15 * rang))
		draw_rect(Rect2(o.position.x, o.end.y - 46, o.size.x, 46), Color("#3ddc84").darkened(0.1))
		for i in 8:
			draw_rect(Rect2(o.position.x + i * o.size.x / 8.0, o.end.y - 46, o.size.x / 16.0, 46), Color(1, 1, 1, 0.08))
		# sol de la coursive
		draw_rect(Rect2(0, 580, w, Buvette.COMPTOIR_Y - 580), Color("#4a428f"))
		# auvent rayé à festons
		var bandes := 16
		var lb := w / bandes
		for i in bandes:
			var c2 := Ui.ROSE if i % 2 == 0 else Ui.BLANC
			draw_rect(Rect2(i * lb, 110, lb, 90), c2)
			draw_circle(Vector2(i * lb + lb / 2.0, 200), lb / 2.0, c2)
		draw_rect(Rect2(0, 0, w, 116), Ui.NUIT)
		draw_line(Vector2(0, 113), Vector2(w, 113), Ui.CONTOUR, 6)
		# enseigne
		var e := Rect2(w / 2.0 - 260, 18, 520, 112)
		draw_style_box(Ui.boite(Ui.JAUNE, 26, 6, 8), e)
		var f := Ui.police_titre()
		var txt := tr("BUVETTE")
		var fs := 76
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(e.get_center().x - tw / 2.0, e.get_center().y + fs * 0.34)
		draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 14, Ui.CONTOUR)
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.BLANC)
		# pointe de la bulle de commande, vers le client
		if buvette and buvette._bulle.visible:
			var b := buvette._bulle.get_rect()
			var a := Vector2(b.end.x - 6, b.position.y + 50)
			var pts := PackedVector2Array([a, a + Vector2(0, 60), a + Vector2(80, 10)])
			draw_colored_polygon(pts, Ui.CONTOUR)
			var pts2 := PackedVector2Array([a + Vector2(-8, 10), a + Vector2(-8, 46), a + Vector2(62, 14)])
			draw_colored_polygon(pts2, Ui.BLANC)

	func _comptoir() -> void:
		var w := size.x
		var y := Buvette.COMPTOIR_Y
		# plateau du comptoir
		draw_rect(Rect2(0, y - 6, w, 34), Ui.CONTOUR)
		draw_rect(Rect2(0, y, w, 22), Color("#f6a255"))
		# façade en planches
		draw_rect(Rect2(0, y + 28, w, 140), Color("#d9732f"))
		for i in 24:
			var x := i * w / 24.0
			draw_line(Vector2(x, y + 28), Vector2(x, y + 168), Color("#b65a20"), 4)
		draw_rect(Rect2(0, y + 166, w, 8), Ui.CONTOUR)
		# plan de travail du vendeur
		draw_rect(Rect2(0, y + 174, w, size.y - y - 174), Color("#1a1640"))


## Un article de la buvette, dessiné (pas d'image ni d'emoji).
class Produit extends Control:
	var type := "boisson"

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var o := (size - Vector2(s, s)) / 2.0
		var lw := maxf(3.0, s * 0.05)
		match type:
			"boisson":
				var paille := PackedVector2Array([o + Vector2(s * 0.52, s * 0.22), o + Vector2(s * 0.62, s * 0.02), o + Vector2(s * 0.78, s * 0.02)])
				draw_polyline(paille, Ui.CONTOUR, lw * 2.2)
				draw_polyline(paille, Ui.ROUGE, lw)
				var g := PackedVector2Array([o + Vector2(s * 0.22, s * 0.2), o + Vector2(s * 0.78, s * 0.2), o + Vector2(s * 0.68, s * 0.95), o + Vector2(s * 0.32, s * 0.95)])
				_forme(g, Ui.BLANC, lw)
				var bande := PackedVector2Array([o + Vector2(s * 0.26, s * 0.45), o + Vector2(s * 0.74, s * 0.45), o + Vector2(s * 0.71, s * 0.66), o + Vector2(s * 0.29, s * 0.66)])
				draw_colored_polygon(bande, Ui.ROUGE)
				draw_rect(Rect2(o + Vector2(s * 0.16, s * 0.14), Vector2(s * 0.68, s * 0.1)), Ui.CONTOUR)
				draw_rect(Rect2(o + Vector2(s * 0.19, s * 0.155), Vector2(s * 0.62, s * 0.07)), Color("#d9d6ee"))
			"hotdog":
				_forme(_ovale(o + Vector2(s * 0.5, s * 0.6), Vector2(s * 0.46, s * 0.22)), Color("#f2b45a"), lw)
				_forme(_ovale(o + Vector2(s * 0.5, s * 0.47), Vector2(s * 0.48, s * 0.11)), Color("#c8452c"), lw)
				var zz := PackedVector2Array()
				for i in 9:
					zz.append(o + Vector2(s * (0.14 + i * 0.09), s * (0.44 if i % 2 == 0 else 0.5)))
				draw_polyline(zz, Ui.JAUNE, lw * 1.1, true)
				_forme(_ovale(o + Vector2(s * 0.5, s * 0.36), Vector2(s * 0.44, s * 0.1)), Color("#f7c878"), lw)
			"frites":
				for i in 6:
					var x := s * (0.27 + i * 0.09)
					var h := s * (0.36 + 0.08 * ((i * 7) % 3))
					var r := Rect2(o + Vector2(x, s * 0.6 - h), Vector2(s * 0.08, h))
					draw_rect(r.grow(lw * 0.5), Ui.CONTOUR)
					draw_rect(r, Ui.JAUNE)
				var boite := PackedVector2Array([o + Vector2(s * 0.18, s * 0.42), o + Vector2(s * 0.82, s * 0.42), o + Vector2(s * 0.7, s * 0.96), o + Vector2(s * 0.3, s * 0.96)])
				_forme(boite, Ui.ROUGE, lw)
				draw_circle(o + Vector2(s * 0.5, s * 0.66), s * 0.1, Ui.BLANC)
			"gaufre":
				var r2 := Rect2(o + Vector2(s * 0.12, s * 0.2), Vector2(s * 0.76, s * 0.62))
				draw_style_box(Ui.boite(Color("#f0b040"), int(s * 0.1), int(lw), 0), r2)
				for i in range(1, 4):
					var x2 := r2.position.x + r2.size.x * i / 4.0
					draw_line(Vector2(x2, r2.position.y + lw), Vector2(x2, r2.end.y - lw), Color("#b97a14"), lw * 0.8)
				for j in range(1, 3):
					var y2 := r2.position.y + r2.size.y * j / 3.0
					draw_line(Vector2(r2.position.x + lw, y2), Vector2(r2.end.x - lw, y2), Color("#b97a14"), lw * 0.8)
				for k in 5:
					draw_circle(o + Vector2(s * (0.22 + k * 0.14), s * (0.16 + 0.04 * (k % 2))), s * 0.06, Ui.BLANC)

	func _forme(pts: PackedVector2Array, c: Color, lw: float) -> void:
		draw_colored_polygon(pts, c)
		var ferme := pts.duplicate()
		ferme.append(pts[0])
		draw_polyline(ferme, Ui.CONTOUR, lw, true)

	func _ovale(c: Vector2, r: Vector2) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return p
