extends Control
## Collection : le carnet de voyage (un tampon par stade visité) et l'album
## des FANZZY (ceux qui ont joué un duel avec toi, et les skins portés).
## À droite, les séries : chaque série complète donne une prime en Jetons.
## Règles dans scripts/jeu/collection.gd.

const Voyage := preload("res://scenes/voyage/voyage.gd")
const SonsScript := preload("res://scripts/audio/sons.gd")
const ONGLETS := [["carnet", "Carnet de voyage"], ["album", "Album FANZZY"]]

var _onglet := "carnet"
var _boutons_onglets: Dictionary = {}
var _titre: Label
var _gauche: VBoxContainer
var _droite: VBoxContainer
var _jetons: Label
var _sons: Node


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color("#5b3fd6")
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
	haut.add_child(Ui.label("COLLECTION", 60, Ui.JAUNE, true, 10))
	for o in ONGLETS:
		var b := Ui.bouton(o[1], Ui.NUIT, 26)
		b.custom_minimum_size = Vector2(280, 70)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _choisir(o[0]))
		_boutons_onglets[o[0]] = b
		haut.add_child(b)
	haut.add_child(Ui.espace())
	var jet := Ui.panneau(Ui.NUIT, 20, 5)
	jet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 36))
	_jetons = Ui.label("", 28, Ui.JAUNE, true, 6)
	hj.add_child(_jetons)
	jet.add_child(hj)
	haut.add_child(jet)

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)

	var pg := Ui.panneau()
	pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(pg)
	var vg := Ui.vbox(12)
	pg.add_child(vg)
	_titre = Ui.label("", 34, Ui.BLANC, true, 6)
	vg.add_child(_titre)
	var sg := ScrollContainer.new()
	sg.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vg.add_child(sg)
	_gauche = Ui.vbox(14)
	_gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sg.add_child(_gauche)

	var pd := Ui.panneau()
	pd.custom_minimum_size = Vector2(660, 0)
	corps.add_child(pd)
	var vd := Ui.vbox(12)
	pd.add_child(vd)
	vd.add_child(Ui.label("SÉRIES ET PRIMES", 34, Ui.JAUNE, true, 6))
	var sd := ScrollContainer.new()
	sd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vd.add_child(sd)
	_droite = Ui.vbox(10)
	_droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sd.add_child(_droite)

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CARTE, Game.params))
	bas.add_child(retour)

	_sons = SonsScript.new()
	add_child(_sons)
	Donnees.mis_a_jour.connect(_remplir)
	if str(Game.params.get("onglet", "")) in ["carnet", "album"]:
		_onglet = str(Game.params["onglet"])
	_choisir(_onglet)


func _choisir(o: String) -> void:
	_onglet = o
	for k in _boutons_onglets:
		var b: Button = _boutons_onglets[k]
		Ui.colorer_bouton(b, Ui.JAUNE if k == o else Ui.NUIT, k == o)
		if k != o:
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.remove_theme_color_override(c)
	_remplir()


func _vider(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _remplir() -> void:
	_jetons.text = "%d" % Game.jetons
	_vider(_gauche)
	_vider(_droite)
	var series: Array
	if _onglet == "carnet":
		_remplir_carnet()
		series = Game.series_carnet()
	else:
		_remplir_album()
		series = Game.series_album()
	# Les primes prêtes d'abord, puis en cours, puis réclamées.
	var rang := func(s): return 0 if s["complete"] and not s["reclamee"] else (2 if s["reclamee"] else 1)
	var tri := series.duplicate()
	tri.sort_custom(func(a, b): return rang.call(a) < rang.call(b))
	for s in tri:
		_droite.add_child(_ligne_serie(s))
	if _onglet == "album":
		var note := Ui.label("Les skins sont cosmétiques : ils viennent du PASS et des événements, jamais des Jetons. La garde-robe garde ceux que tes FANZZY ont portés en duel.", 18, Ui.GRIS)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_droite.add_child(note)


# ---------------------------------------------------------------- carnet

func _remplir_carnet() -> void:
	var lieux := Game.lieux_visites()
	_titre.text = tr("CARNET DE VOYAGE · %d stade%s · %d pays") % [Game.tampons.size(), "" if Game.tampons.size() == 1 else "s", lieux["pays"].size()]
	if Game.tampons.is_empty():
		var vide := Ui.label("Aucun stade tamponné pour l'instant.\nChoisis un match sur la carte et va le voir « Au stade » : le stade du club qui reçoit rejoint ton carnet.", 24, Ui.GRIS)
		vide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_gauche.add_child(vide)
		return
	# Un groupe par pays, les plus visités d'abord.
	var groupes: Dictionary = {}
	for cle in Game.tampons:
		var info: Dictionary = Game.tampons[cle] if Game.tampons[cle] is Dictionary else {}
		var p := Collection.pays_tampon(str(cle), info, Geo.pays_des_equipes)
		if not groupes.has(p):
			groupes[p] = []
		groupes[p].append(info)
	var pays := groupes.keys()
	pays.sort_custom(func(a, b): return groupes[a].size() > groupes[b].size() or (groupes[a].size() == groupes[b].size() and str(a) < str(b)))
	for p in pays:
		var nom := Geo.nom_pays(p) if p != "" else "Ailleurs"
		_gauche.add_child(Ui.label("%s · %d" % [nom, groupes[p].size()], 26, Ui.JAUNE, true, 6))
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", 14)
		flux.add_theme_constant_override("v_separation", 14)
		var liste: Array = groupes[p]
		liste.sort_custom(func(a, b): return str(a.get("date", "")) > str(b.get("date", "")))
		for info in liste:
			flux.add_child(_carte_tampon(info))
		_gauche.add_child(flux)


func _carte_tampon(info: Dictionary) -> Control:
	var pan := Ui.panneau(Color("#f6efe0"), 18, 4)
	pan.custom_minimum_size = Vector2(236, 0)
	pan.tooltip_text = "%s\n%s\n%s" % [info.get("nom", ""), info.get("match", ""), info.get("date", "")]
	var v := Ui.vbox(2)
	pan.add_child(v)
	var cadre := Control.new()
	cadre.custom_minimum_size = Vector2(200, 200)
	cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t: Control = Voyage.Tampon.new()
	t.set("nom", str(info.get("nom", "")))
	t.set("club", str(info.get("club", "")))
	t.set("date", _date_courte(str(info.get("date", ""))))
	t.set("couleur", Fiction.PALETTE[Fiction.graine(str(info.get("club", ""))) % 8])
	t.size = Vector2(460, 460)
	t.scale = Vector2.ONE * (200.0 / 460.0)
	t.rotation = deg_to_rad(float(Fiction.graine(str(info.get("nom", ""))) % 17) - 8.0)
	t.pivot_offset = Vector2(230, 230)
	t.position = Vector2(100, 100) - t.pivot_offset  # centre du tampon au centre du cadre
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(t)
	v.add_child(cadre)
	var l := Ui.label(str(info.get("club", "")), 18, Ui.CONTOUR, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size = Vector2(200, 0)
	v.add_child(l)
	return pan


func _date_courte(d: String) -> String:
	## « 2026-11-15 » -> « 15/11/26 ».
	var p := d.split("-")
	if p.size() != 3:
		return d
	return "%s/%s/%s" % [p[2], p[1], p[0].right(2)]


# ---------------------------------------------------------------- album

func _remplir_album() -> void:
	var c: Dictionary = Game.collection
	var nb := Game.fanzzy.filter(func(z): return Collection.a_fanzzy(c, z["id"])).size()
	_titre.text = tr("ALBUM FANZZY · %d / %d") % [nb, Game.fanzzy.size()]
	var aide := Ui.label("Un FANZZY rejoint l'album quand il joue un duel dans ta tribune (bouton FANZZY de la carte).", 20, Ui.GRIS)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_gauche.add_child(aide)
	for f in Game.familles:
		var membres := Game.fanzzy.filter(func(z): return z["famille"] == f)
		if membres.is_empty():
			continue
		var faits := membres.filter(func(z): return Collection.a_fanzzy(c, z["id"])).size()
		var h := Ui.hbox(10)
		h.add_child(Ui.pastille(Game.nom_famille(f), Game.couleur_famille(f), 22, true))
		h.add_child(Ui.label("%d / %d" % [faits, membres.size()], 24, Ui.BLANC, true, 4))
		_gauche.add_child(h)
		var flux := HFlowContainer.new()
		flux.add_theme_constant_override("h_separation", 14)
		flux.add_theme_constant_override("v_separation", 14)
		for z in membres:
			flux.add_child(_carte_fanzzy(z, c))
		_gauche.add_child(flux)


func _carte_fanzzy(z: Dictionary, c: Dictionary) -> Control:
	var vu := Collection.a_fanzzy(c, z["id"])
	var coul := Game.couleur_famille(z["famille"])
	var pan := Ui.panneau(coul.darkened(0.35) if vu else Color("#1a1640"), 18, 4)
	pan.custom_minimum_size = Vector2(236, 0)
	var v := Ui.vbox(4)
	pan.add_child(v)
	var img := TextureRect.new()
	img.texture = Game.texture_fanzzy(z["id"], true)
	img.custom_minimum_size = Vector2(200, 150)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not vu:
		img.modulate = Color(0.12, 0.1, 0.25)
	v.add_child(img)
	var n := Ui.label(z["nom"] if vu else "???", 19, Ui.BLANC, true, 4)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.clip_text = true
	n.custom_minimum_size = Vector2(200, 0)
	v.add_child(n)
	# Garde-robe : un rond par skin, plein s'il a été porté en duel.
	var hs := Ui.hbox(6)
	hs.alignment = BoxContainer.ALIGNMENT_CENTER
	var skins: Array = z.get("skins", [])
	var portes := 0
	for sk in skins:
		var a := Collection.a_skin(c, sk["id"])
		portes += 1 if a else 0
		var rond := Ui.label("●" if a else "○", 22, Ui.JAUNE if a else Ui.GRIS)
		rond.tooltip_text = sk["nom"] if a else "Skin pas encore porté en duel"
		rond.mouse_filter = Control.MOUSE_FILTER_PASS
		hs.add_child(rond)
	v.add_child(hs)
	if vu:
		pan.tooltip_text = tr("%s\nSérie : %s\nDans l'album depuis le %s\nGarde-robe : %d / %d skins portés") % [
			z["nom"], Game.series_fanzzy.get(z.get("serie", ""), {}).get("nom", z.get("serie", "")),
			c["fanzzy"][z["id"]], portes, skins.size()]
	else:
		pan.tooltip_text = "Pas encore vu en duel"
	return pan


# ---------------------------------------------------------------- séries

func _ligne_serie(s: Dictionary) -> Control:
	var prete: bool = s["complete"] and not s["reclamee"]
	var pan := Ui.panneau(Ui.NUIT_CLAIR if not prete else Color("#24603f"), 18, 4)
	var h := Ui.hbox(12)
	pan.add_child(h)
	var v := Ui.vbox(4)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Ui.label(s["titre"], 24, Ui.BLANC, true, 4))
	var t := Ui.label(s["texte"], 16, Ui.GRIS)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	var hb := Ui.hbox(8)
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(0, 16)
	barre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	barre.show_percentage = false
	barre.max_value = s["total"]
	barre.value = s["fait"]
	barre.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 8, 3))
	barre.add_theme_stylebox_override("fill", Ui.boite(Color(s["couleur"]), 8, 0))
	hb.add_child(barre)
	hb.add_child(Ui.label("%d / %d" % [s["fait"], s["total"]], 18, Ui.BLANC, true))
	v.add_child(hb)
	if s["reclamee"]:
		var l := Ui.label("Prime reçue", 20, Ui.VERT, true)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(l)
	elif prete:
		var b := Ui.bouton("+%d J" % s["prime"], Ui.JAUNE, 26)
		Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.custom_minimum_size = Vector2(150, 64)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.tooltip_text = "Réclamer la prime"
		b.pressed.connect(func(): _reclamer(s["id"], b))
		h.add_child(b)
	else:
		var hp := Ui.hbox(4)
		hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		hp.add_child(Ui.icone("jeton", 26))
		hp.add_child(Ui.label("%d" % s["prime"], 22, Ui.GRIS, true))
		h.add_child(hp)
	return pan


func _reclamer(id: String, b: Button) -> void:
	var n := Game.reclamer_prime(id)
	if n <= 0:
		return
	_sons.jouer("ui_parfait")
	b.disabled = true
	b.text = "+%d !" % n
	Ui.pop(b, 1.25, 0.3)
	_jetons.text = "%d" % Game.jetons
	Ui.pop(_jetons)
	get_tree().create_timer(0.6).timeout.connect(_remplir)
