extends Control
## « Classement » : les meilleurs fans et les équipes les plus soutenues, en ligne.
## Les points viennent du serveur (autoload EnLigne). Ce sont les points de
## popularité que les joueurs donnent à leurs équipes favorites (duels, pronos,
## matchs suivis, fan club). Les Jetons n'y sont pour rien.
## Tests : « -- --onglet=clubs --periode=total ».

const Favoris := preload("res://scenes/favoris/favoris.gd")
const ONGLETS := [["fans", "Fans"], ["clubs", "Clubs"], ["nations", "Sélections"]]
const PERIODES := [["semaine", "Cette semaine"], ["total", "Depuis le début"]]

var _onglet := "fans"
var _periode := "semaine"
var _gauche: VBoxContainer
var _droite: VBoxContainer


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--onglet="):
			_onglet = arg.trim_prefix("--onglet=")
		elif arg.begins_with("--periode="):
			_periode = arg.trim_prefix("--periode=")
	var fond := ColorRect.new()
	fond.color = Color("#1e4fa8")
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
	haut.add_child(Ui.label("CLASSEMENT", 60, Ui.JAUNE, true, 10))
	var st := Ui.label("Les supporters du monde entier font monter leurs équipes. Où en sont les tiennes ?", 22, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haut.add_child(st)

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)
	var pg := Ui.panneau()
	pg.custom_minimum_size = Vector2(620, 0)
	corps.add_child(pg)
	_gauche = Ui.vbox(14)
	pg.add_child(_gauche)
	var pd := Ui.panneau()
	pd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(pd)
	_droite = Ui.vbox(10)
	pd.add_child(_droite)

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CARTE, Game.params))
	bas.add_child(retour)
	var equipes := Ui.bouton("Mes équipes", Ui.VERT, 28)
	Ui.colorer_bouton(equipes, Ui.VERT, true)
	equipes.custom_minimum_size = Vector2(340, 84)
	equipes.pressed.connect(func(): Game.aller(Game.SCENE_FAVORIS, Game.params))
	bas.add_child(equipes)

	EnLigne.mis_a_jour.connect(_remplir)
	EnLigne.envoyer()
	EnLigne.rafraichir_equipes()
	EnLigne.rafraichir_fans(_periode)
	_remplir()


func _remplir() -> void:
	_remplir_gauche()
	_remplir_droite()


# ------------------------------------------------------------------ ta carte de fan

func _remplir_gauche() -> void:
	for c in _gauche.get_children():
		c.queue_free()
	_gauche.add_child(Ui.label("Ta carte de fan", 32, Ui.BLANC, true, 6))
	var carte := Ui.panneau(Ui.NUIT_CLAIR, 22, 4)
	_gauche.add_child(carte)
	var v := Ui.vbox(8)
	carte.add_child(v)
	var h := Ui.hbox(14)
	v.add_child(h)
	if Game.equipe.size() > 0:
		var tex := TextureRect.new()
		tex.texture = Game.texture_fanzzy(str(Game.equipe[0]), true)
		tex.custom_minimum_size = Vector2(84, 84)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tex)
	var vn := Ui.vbox(2)
	vn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vn)
	vn.add_child(Ui.label(EnLigne.pseudo(), 34, Ui.JAUNE, true, 6))
	vn.add_child(Ui.label("Fan club : %s" % Game.fan_club_nom, 18, Ui.GRIS))

	var m := EnLigne.moi
	var stats := Ui.hbox(12)
	v.add_child(stats)
	stats.add_child(_case_stat("Cette semaine", m.get("points_semaine", 0), m.get("rang_semaine")))
	stats.add_child(_case_stat("Depuis le début", m.get("points_total", 0), m.get("rang_total")))
	var attente := (Game.supporters.get("a_envoyer", []) as Array).size()
	var etat := ""
	if EnLigne.desactive:
		etat = "Classement en ligne désactivé (mode test)."
	elif not EnLigne.joignable and m.is_empty():
		etat = "Hors ligne : tes points t'attendent, ils partiront à la prochaine connexion."
	elif attente > 0:
		etat = "En ligne · %d gain%s en route vers le classement." % [attente, "" if attente == 1 else "s"]
	else:
		etat = "En ligne · %s fans au classement." % _milliers(int(m.get("fans", 0)))
	var le := Ui.label(etat, 17, Ui.GRIS)
	le.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(le)

	# Nom de fan : deux mots des listes du jeu et un numéro (pas de texte libre).
	_gauche.add_child(Ui.label("Ton nom de fan", 26, Ui.BLANC, true, 4))
	var p: Array = EnLigne.identite["pseudo"]
	var hp := Ui.hbox(10)
	_gauche.add_child(hp)
	var ob_nom := _choix_mot(ClassementFans.NOMS, int(p[0]))
	var ob_qual := _choix_mot(ClassementFans.QUALITES, int(p[1]))
	hp.add_child(ob_nom)
	hp.add_child(ob_qual)
	var de := Ui.bouton("N° %d" % int(p[2]), Ui.VIOLET, 20)
	de.tooltip_text = "Tirer un autre numéro"
	hp.add_child(de)
	ob_nom.item_selected.connect(func(i: int): _pseudo(i, int(p[1]), int(p[2])))
	ob_qual.item_selected.connect(func(i: int): _pseudo(int(p[0]), i, int(p[2])))
	de.pressed.connect(func(): _pseudo(int(p[0]), int(p[1]), randi() % 100))

	var vis := CheckButton.new()
	vis.text = "Apparaître dans le classement des fans"
	vis.button_pressed = bool(EnLigne.identite["visible"])
	vis.add_theme_font_size_override("font_size", 20)
	vis.tooltip_text = "Décoché, tes points comptent toujours pour tes équipes, mais ton nom n'est pas affiché."
	vis.toggled.connect(func(on: bool):
		EnLigne.changer_visible(on)
		_remplir())
	_gauche.add_child(vis)

	_gauche.add_child(Ui.espace())
	for ligne in [
		"Tes points de fan, ce sont les points de popularité que tu donnes à tes équipes favorites : duels, pronos, matchs suivis, fan club.",
		"%d points au plus par équipe et par jour. Le classement de la semaine repart à zéro chaque lundi." % Supporters.MAX_PAR_JOUR,
		"Aucune donnée personnelle : seulement ton nom de fan et tes points.",
	]:
		var l := Ui.label("• " + ligne, 17, Ui.GRIS)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_gauche.add_child(l)


func _pseudo(nom: int, qualite: int, nombre: int) -> void:
	EnLigne.changer_pseudo(nom, qualite, nombre)
	_remplir()


func _case_stat(titre: String, points: Variant, rang: Variant) -> Control:
	var c := Ui.panneau(Ui.NUIT, 16, 3)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ui.vbox(0)
	c.add_child(v)
	v.add_child(Ui.label(titre, 16, Ui.GRIS))
	v.add_child(Ui.label(_ordinal(int(rang)) if rang != null and int(rang) > 0 else "—", 36, Ui.BLANC, true, 5))
	v.add_child(Ui.label("%s points" % _milliers(int(points)), 18, Ui.JAUNE, true))
	return c


func _choix_mot(mots: Array, choisi: int) -> OptionButton:
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 20)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in mots:
		ob.add_item(m)
	ob.select(clampi(choisi, 0, mots.size() - 1))
	return ob


# ------------------------------------------------------------------ listes

func _remplir_droite() -> void:
	for c in _droite.get_children():
		c.queue_free()
	var h := Ui.hbox(10)
	_droite.add_child(h)
	for o in ONGLETS:
		h.add_child(_bouton_choix(o[1], _onglet == o[0], func():
			_onglet = o[0]
			_remplir_droite()))
	h.add_child(Ui.espace())
	for o in PERIODES:
		h.add_child(_bouton_choix(o[1], _periode == o[0], func():
			_periode = o[0]
			if _onglet == "fans":
				EnLigne.rafraichir_fans(_periode)
			_remplir_droite()))

	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_droite.add_child(sc)
	var liste := Ui.vbox(6)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(liste)

	if _onglet == "fans":
		_liste_fans(liste)
	else:
		_liste_equipes(liste)


func _bouton_choix(texte: String, actif: bool, action: Callable) -> Button:
	var b := Ui.bouton(texte, Ui.JAUNE if actif else Ui.NUIT_CLAIR, 19)
	if actif:
		Ui.colorer_bouton(b, Ui.JAUNE, true)
	b.pressed.connect(action)
	return b


func _vide(liste: VBoxContainer, texte: String) -> void:
	var l := Ui.label(texte, 20, Ui.GRIS)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	liste.add_child(l)


func _liste_fans(liste: VBoxContainer) -> void:
	if not EnLigne.fans.has(_periode):
		if EnLigne.desactive:
			_vide(liste, "Classement en ligne désactivé (mode test).")
		else:
			_vide(liste, "Chargement du classement…" if EnLigne.joignable else "Classement indisponible pour l'instant. Réessaie un peu plus tard !")
		return
	var lignes: Array = EnLigne.fans[_periode]
	if lignes.is_empty():
		_vide(liste, "Personne encore cette semaine : joue un duel pour ton club favori et prends la tête !"
			if _periode == "semaine" else "Personne encore : sois le premier fan du classement !")
		return
	var moi_dedans := false
	for f in lignes:
		var c_moi: bool = str(f.get("id", "")) == str(EnLigne.identite["id"])
		moi_dedans = moi_dedans or c_moi
		liste.add_child(_ligne_fan(int(f.get("rang", 0)), ClassementFans.pseudo_texte(f.get("pseudo")), str(f.get("equipe", "")), int(f.get("points", 0)), c_moi))
	var m := EnLigne.moi
	var rang: Variant = m.get("rang_semaine" if _periode == "semaine" else "rang_total")
	if not moi_dedans and rang != null and int(rang) > 0:
		liste.add_child(Ui.label("…", 22, Ui.GRIS, true))
		liste.add_child(_ligne_fan(int(rang), EnLigne.pseudo(), str(m.get("equipe", "")),
			int(m.get("points_semaine" if _periode == "semaine" else "points_total", 0)), true))


func _ligne_fan(rang: int, nom: String, equipe: String, points: int, c_moi: bool) -> Control:
	var cadre := Ui.panneau(Ui.JAUNE.darkened(0.5) if c_moi else Ui.NUIT_CLAIR, 14, 3)
	var h := Ui.hbox(10)
	cadre.add_child(h)
	h.add_child(_rang(rang))
	var n := Ui.label(("★ " if c_moi else "") + nom, 22, Ui.BLANC, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(n)
	if equipe != "":
		var i := Favoris.info(equipe)
		h.add_child(Ui.ecusson(i["sigle"], i["c1"], i["c2"], 34))
		var ne := Ui.label(i["nom"], 17, Ui.GRIS)
		ne.custom_minimum_size = Vector2(260, 0)
		ne.clip_text = true
		ne.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(ne)
	var p := Ui.label(_milliers(points), 22, Ui.JAUNE, true)
	p.custom_minimum_size = Vector2(110, 0)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(p)
	return cadre


func _liste_equipes(liste: VBoxContainer) -> void:
	if EnLigne.equipes.is_empty():
		_vide(liste, "Classement indisponible pour l'instant. Réessaie un peu plus tard !" if not EnLigne.desactive
			else "Classement en ligne désactivé (mode test).")
		return
	var nations := _onglet == "nations"
	var lignes := ClassementFans.lignes_equipes(EnLigne.equipes, "s" if _periode == "semaine" else "p",
		func(cle: String): return Supporters.est_nation(cle) == nations)
	if lignes.is_empty():
		_vide(liste, "Aucun point encore %s : à toi de lancer ton équipe !" % ("cette semaine" if _periode == "semaine" else "pour l'instant"))
		return
	var n := 0
	for l in lignes:
		var fav := Supporters.est_favori(Game.supporters, l["cle"])
		n += 1
		if n <= Favoris.TOP or fav:
			liste.add_child(_ligne_equipe(l, fav))


func _ligne_equipe(l: Dictionary, fav: bool) -> Control:
	var i := Favoris.info(l["cle"])
	var cadre := Ui.panneau(Ui.JAUNE.darkened(0.5) if fav else Ui.NUIT_CLAIR, 14, 3)
	var h := Ui.hbox(10)
	cadre.add_child(h)
	h.add_child(_rang(int(l["rang"])))
	h.add_child(Ui.ecusson(i["sigle"], i["c1"], i["c2"], 36))
	var nom := Ui.label(("★ " if fav else "") + i["nom"], 21, Ui.BLANC, true)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nom)
	if not Supporters.est_nation(l["cle"]) and str(i.get("pays", "")) != "":
		h.add_child(Ui.label(Geo.nom_pays(i["pays"]), 16, Ui.GRIS))
	h.add_child(Ui.pastille("%s fan%s" % [_milliers(int(l["fans"])), "" if int(l["fans"]) == 1 else "s"], Ui.BLEU, 14))
	var p := Ui.label(_milliers(int(l["points"])), 22, Ui.JAUNE, true)
	p.custom_minimum_size = Vector2(110, 0)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(p)
	return cadre


func _rang(rang: int) -> Label:
	var r := Ui.label("%d" % rang, 24, Ui.JAUNE if rang <= 3 else Ui.BLANC, true, 5)
	r.custom_minimum_size = Vector2(64, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return r


static func _ordinal(n: int) -> String:
	return "1er" if n == 1 else "%se" % _milliers(n)


static func _milliers(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if n < 0 else "") + s + out
