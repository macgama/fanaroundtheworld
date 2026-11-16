extends Control
## « Mes équipes » : un club favori par pays, une équipe nationale, et le
## classement des équipes les plus suivies.
## Tes duels, pronos, déplacements et ton fan club donnent des points de
## popularité à tes favoris (règles dans scripts/jeu/supporters.gd).
## Les autres supporters viennent du classement en ligne (autoload EnLigne),
## ou sont simulés hors ligne.

const TOP := 30
const ONGLETS := [["clubs", "Clubs du monde"], ["pays", "Clubs du pays"], ["nations", "Sélections"]]

var _gauche: VBoxContainer
var _droite: VBoxContainer
var _onglet := "clubs"
var _pays_classement := ""
var _choix: Control         # fenêtre de choix (pays, puis club)
var _choix_liste: VBoxContainer
var _choix_titre: Label
var _recherche: LineEdit
var _choix_mode := ""       # "club" ou "nation"
var _choix_pays := ""       # pays choisi à la 1re étape (clubs)


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color("#1b8f5a")
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
	haut.add_child(Ui.label("MES ÉQUIPES", 60, Ui.JAUNE, true, 10))
	var st := Ui.label("Un club par pays et une équipe nationale. Fais-les monter au classement des plus suivies !", 22, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haut.add_child(st)

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)

	var pg := Ui.panneau()
	pg.custom_minimum_size = Vector2(800, 0)
	corps.add_child(pg)
	var sg := ScrollContainer.new()
	sg.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pg.add_child(sg)
	_gauche = Ui.vbox(12)
	_gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sg.add_child(_gauche)

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

	_construire_choix()
	Donnees.mis_a_jour.connect(_remplir)
	EnLigne.mis_a_jour.connect(_remplir)
	var p: Dictionary = Game.params
	if str(p.get("pays", "")) != "":
		_pays_classement = str(p["pays"])
	_remplir()
	# Tests : « -- --scene=favoris --choix=club:france » ouvre la fenêtre de choix.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--choix="):  # sans_traduction
			var c := arg.trim_prefix("--choix=").split(":")  # sans_traduction
			_ouvrir_choix(c[0], c[1] if c.size() > 1 else "")


# ------------------------------------------------------------------ infos d'équipe

## {cle, nom, sigle, c1, c2, pays, connu} pour une clé d'équipe.
static func info(cle: String) -> Dictionary:
	if Supporters.est_nation(cle):
		var pays := cle.trim_prefix("nation:")
		var g := Fiction.graine(cle)
		var nom := Geo.nom_pays(pays)
		var c1: Color = Fiction.PALETTE[g % Fiction.PALETTE.size()]
		var c2: Color = Fiction.PALETTE[(g / 7 + 3) % Fiction.PALETTE.size()]
		return {"cle": cle, "nom": nom, "sigle": nom.left(3).to_upper(), "c1": c1, "c2": c2 if c2 != c1 else Ui.BLANC, "pays": pays, "connu": false}
	var e := Fiction.equipe({"id": cle})
	e["cle"] = cle
	e["pays"] = str(Geo.pays_des_equipes.get(cle, ""))
	e["connu"] = Fiction._surcharges.has(cle)
	return e


## Points des autres supporters : ceux du classement en ligne quand le serveur
## a répondu, sinon les supporters simulés.
static func communaute(equipes: Array) -> Dictionary:
	if EnLigne.a_des_donnees() and not EnLigne.equipes.is_empty():
		return EnLigne.communaute()
	var t := Game.maintenant()
	var c := {}
	for e in equipes:
		c[e["cle"]] = Supporters.base_communaute(e["cle"], e["connu"], t)
	return c


func _clubs(pays: String) -> Array:
	var out: Array = []
	for e in Donnees.clubs_du_pays(pays):
		var i := info(str(e["id"]))
		i["pays"] = pays
		out.append(i)
	# Un favori reste visible même s'il n'est plus dans les listes.
	var fav := Supporters.club_du_pays(Game.supporters, pays)
	if fav != "" and not out.any(func(x): return x["cle"] == fav):
		var i := info(fav)
		i["pays"] = pays
		out.append(i)
	return out


func _tous_les_clubs() -> Array:
	var out: Array = []
	var pays := Donnees.pays_avec_clubs()
	for p in Game.supporters["clubs"]:
		if not p in pays:
			pays.append(p)
	for p in pays:
		out.append_array(_clubs(p))
	return out


func _nations() -> Array:
	var out: Array = []
	for pays in Geo._donnees().get("pays", {}):
		out.append(info(Supporters.cle_nation(pays)))
	return out


func _classement(equipes: Array) -> Array:
	return Supporters.classement(equipes, communaute(equipes), Game.supporters["points"])


func _rang(cle: String, equipes: Array) -> int:
	for l in _classement(equipes):
		if l["cle"] == cle:
			return int(l["rang"])
	return 0


# ------------------------------------------------------------------ remplissage

func _remplir() -> void:
	_remplir_gauche()
	_remplir_droite()


func _remplir_gauche() -> void:
	for c in _gauche.get_children():
		c.queue_free()
	var s := Game.supporters
	var t := Game.maintenant()
	_gauche.add_child(Ui.label("Équipe nationale", 32, Ui.BLANC, true, 6))
	if s["nation"].is_empty():
		_gauche.add_child(_case_vide("Choisis ton équipe nationale", func(): _ouvrir_choix("nation")))
	else:
		var cle := Supporters.cle_nation(str(s["nation"]["pays"]))
		_gauche.add_child(_carte_favori(info(cle), _rang(cle, _nations()), Supporters.attente_nation(s, t),
			func(): _ouvrir_choix("nation"), Callable()))

	_gauche.add_child(Ui.label(tr("Clubs favoris (%d)") % s["clubs"].size(), 32, Ui.BLANC, true, 6))
	var pays: Array = s["clubs"].keys()
	pays.sort_custom(func(a, b): return Geo.nom_pays(a) < Geo.nom_pays(b))
	for p in pays:
		var cle := Supporters.club_du_pays(s, p)
		var i := info(cle)
		i["pays"] = p
		var pp: String = p
		_gauche.add_child(_carte_favori(i, _rang(cle, _clubs(p)), Supporters.attente_club(s, p, t),
			func(): _ouvrir_choix("club", pp), func():
				Game.retirer_club_favori(pp)
				_remplir()))
	_gauche.add_child(_case_vide("+ Ajouter un club (un par pays)", func(): _ouvrir_choix("club")))

	_gauche.add_child(Ui.label("Comment gagner de la popularité", 26, Ui.BLANC, true))
	for ligne in [
		tr("Duel pour ton favori : +%d, +%d s'il est gagné (×1,5 au stade).") % [Supporters.POINTS_DUEL, Supporters.POINTS_DUEL_GAGNE],
		tr("Suivre son match : stade +%d, écran géant +%d, pub +%d, maison +%d.") % [
			Supporters.POINTS_SUIVI["stade"], Supporters.POINTS_SUIVI["ecran"], Supporters.POINTS_SUIVI["pub"], Supporters.POINTS_SUIVI["maison"]],
		tr("Prono sur son match : +%d, +%d si le résultat est bon, +%d de plus pour le score exact.") % [
			Supporters.POINTS_PRONO, Supporters.POINTS_PRONO_RESULTAT, Supporters.POINTS_PRONO_SCORE],
		tr("Récolte du fan club : tes membres en parlent, +1 par tranche de %d Jetons pour chaque favori.") % Supporters.JETONS_PAR_POINT_CLUB,
		tr("%d points au plus par équipe et par jour. Changer de favori : une fois par semaine, les points donnés restent.") % Supporters.MAX_PAR_JOUR,
	]:
		var l := Ui.label("• " + tr(ligne), 18, Ui.GRIS)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_gauche.add_child(l)


func _carte_favori(i: Dictionary, rang: int, attente: int, changer: Callable, retirer: Callable) -> Control:
	var cadre := Ui.panneau(Ui.NUIT_CLAIR, 18, 4)
	var h := Ui.hbox(12)
	cadre.add_child(h)
	h.add_child(Ui.ecusson(i["sigle"], i["c1"], i["c2"], 54))
	var v := Ui.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nom := Ui.label("★ " + i["nom"], 24, Ui.BLANC, true)
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nom)
	var lieu := "Sélection" if Supporters.est_nation(i["cle"]) else Geo.nom_pays(i["pays"])
	v.add_child(Ui.label(tr("%s · %de · tu lui as donné %d points") % [lieu, rang, int(Game.supporters["points"].get(i["cle"], 0))], 16, Ui.GRIS))
	if attente > 0:
		var j := ceili(attente / 86400.0)
		h.add_child(Ui.pastille(tr("Changement dans %d j") % j, Color("#6b6699"), 15))
		return cadre
	var b := Ui.bouton("Changer", Ui.BLEU, 18)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(changer)
	h.add_child(b)
	if retirer.is_valid():
		var r := Ui.bouton("Retirer", Ui.NUIT, 18)
		r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.pressed.connect(retirer)
		h.add_child(r)
	return cadre


func _case_vide(texte: String, action: Callable) -> Control:
	var b := Ui.bouton(texte, Ui.VIOLET, 22)
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(action)
	return b


func _remplir_droite() -> void:
	for c in _droite.get_children():
		c.queue_free()
	var h := Ui.hbox(10)
	h.add_child(Ui.label("Les plus suivies", 32, Ui.BLANC, true, 6))
	h.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for o in ONGLETS:
		var b := Ui.bouton(o[1], Ui.JAUNE if _onglet == o[0] else Ui.NUIT_CLAIR, 18)
		if _onglet == o[0]:
			Ui.colorer_bouton(b, Ui.JAUNE, true)
		var id: String = o[0]
		b.pressed.connect(func():
			_onglet = id
			_remplir_droite())
		h.add_child(b)
	_droite.add_child(h)

	var equipes: Array = []
	match _onglet:
		"clubs":
			equipes = _tous_les_clubs()
		"nations":
			equipes = _nations()
		"pays":
			var choix := _pays_du_classement()
			if choix.is_empty():
				_droite.add_child(Ui.label("Aucun club connu pour l'instant.", 20, Ui.GRIS))
				return
			if not _pays_classement in choix:
				_pays_classement = choix[0]
			var ob := OptionButton.new()
			ob.add_theme_font_size_override("font_size", 20)
			for k in choix:
				ob.add_item(Geo.nom_pays(k))
				if k == _pays_classement:
					ob.select(ob.item_count - 1)
			ob.item_selected.connect(func(idx: int):
				_pays_classement = choix[idx]
				_remplir_droite())
			_droite.add_child(ob)
			equipes = _clubs(_pays_classement)
	var en_ligne := not EnLigne.equipes.is_empty()
	var note := Ui.label("Points de tous les joueurs, classement en ligne." if en_ligne
		else "Hors ligne : les autres supporters sont simulés en attendant le classement en ligne.", 15, Ui.GRIS)
	_droite.add_child(note)

	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_droite.add_child(sc)
	var liste := Ui.vbox(6)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(liste)
	var lignes := _classement(equipes)
	if lignes.is_empty():
		liste.add_child(Ui.label("Aucune équipe connue pour l'instant : la liste se remplit avec les matchs.", 19, Ui.GRIS))
	for l in lignes:
		var fav := Supporters.est_favori(Game.supporters, l["cle"])
		if int(l["rang"]) <= TOP or fav:
			liste.add_child(_ligne_classement(l, fav))


func _pays_du_classement() -> Array:
	var choix := Donnees.pays_avec_clubs()
	for p in Game.supporters["clubs"]:
		if not p in choix:
			choix.append(p)
	choix.sort_custom(func(a, b): return Geo.nom_pays(a) < Geo.nom_pays(b))
	return choix


func _ligne_classement(l: Dictionary, fav: bool) -> Control:
	var cadre := Ui.panneau(Ui.JAUNE.darkened(0.5) if fav else Ui.NUIT_CLAIR, 14, 3)
	var h := Ui.hbox(10)
	cadre.add_child(h)
	var r := Ui.label("%d" % int(l["rang"]), 24, Ui.JAUNE if int(l["rang"]) <= 3 else Ui.BLANC, true, 5)
	r.custom_minimum_size = Vector2(56, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(r)
	h.add_child(Ui.ecusson(l["sigle"], l["c1"], l["c2"], 36))
	var nom := Ui.label(("★ " if fav else "") + l["nom"], 21, Ui.BLANC, true)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(nom)
	if not Supporters.est_nation(l["cle"]) and _onglet != "pays":
		h.add_child(Ui.label(Geo.nom_pays(l["pays"]), 16, Ui.GRIS))
	if int(l["a_toi"]) > 0:
		h.add_child(Ui.pastille(tr("dont toi : %d") % int(l["a_toi"]), Ui.ROSE, 14))
	h.add_child(Ui.label(_milliers(int(l["points"])), 22, Ui.JAUNE, true))
	return cadre


# ------------------------------------------------------------------ choix d'un favori

func _construire_choix() -> void:
	_choix = Control.new()
	_choix.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choix.visible = false
	add_child(_choix)
	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.7)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_choix.add_child(voile)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -560
	pan.offset_right = 560
	pan.offset_top = -440
	pan.offset_bottom = 440
	_choix.add_child(pan)
	var v := Ui.vbox(12)
	pan.add_child(v)
	var h := Ui.hbox(10)
	_choix_titre = Ui.label("", 34, Ui.JAUNE, true, 6)
	_choix_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_choix_titre)
	var fermer := Ui.bouton("X", Ui.NUIT_CLAIR, 22)
	fermer.pressed.connect(func(): _choix.visible = false)
	h.add_child(fermer)
	v.add_child(h)
	_recherche = LineEdit.new()
	_recherche.placeholder_text = "Rechercher…"
	_recherche.add_theme_font_size_override("font_size", 22)
	_recherche.text_changed.connect(func(_t): _remplir_choix())
	v.add_child(_recherche)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_choix_liste = Ui.vbox(8)
	_choix_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_choix_liste)


## mode "nation" : liste des pays. Mode "club" : un pays (ou le choisir d'abord).
func _ouvrir_choix(mode: String, pays := "") -> void:
	_choix_mode = mode
	_choix_pays = pays
	_recherche.text = ""
	_choix.visible = true
	_remplir_choix()
	_recherche.grab_focus()


func _remplir_choix() -> void:
	for c in _choix_liste.get_children():
		c.queue_free()
	var filtre := _recherche.text.strip_edges().to_lower()
	var grille := GridContainer.new()
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 10)
	grille.add_theme_constant_override("v_separation", 10)
	if _choix_mode == "club" and _choix_pays != "":
		_choix_titre.text = tr("Ton club favori · ") + Geo.nom_pays(_choix_pays)
		var retour := Ui.bouton("← Autre pays", Ui.NUIT_CLAIR, 18)
		retour.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		retour.pressed.connect(func():
			_choix_pays = ""
			_remplir_choix())
		_choix_liste.add_child(retour)
		var clubs := _clubs(_choix_pays)
		clubs.sort_custom(func(a, b): return a["nom"] < b["nom"])
		var actuel := Supporters.club_du_pays(Game.supporters, _choix_pays)
		for i in clubs:
			if filtre != "" and not filtre in i["nom"].to_lower():
				continue
			grille.add_child(_bouton_club(i, i["cle"] == actuel))
		if clubs.is_empty():
			_choix_liste.add_child(Ui.label("Aucun club connu dans ce pays pour l'instant.", 20, Ui.GRIS))
	else:
		_choix_titre.text = "Ton équipe nationale" if _choix_mode == "nation" else "Le pays de ton club"
		var liste: Array = _nations().map(func(i): return i["pays"]) if _choix_mode == "nation" else Donnees.pays_avec_clubs()
		liste.sort_custom(func(a, b): return Geo.nom_pays(a) < Geo.nom_pays(b))
		for p in liste:
			var nom := Geo.nom_pays(p)
			if filtre != "" and not filtre in nom.to_lower():
				continue
			var deja := ""
			if _choix_mode == "club" and Supporters.club_du_pays(Game.supporters, p) != "":
				deja = " ★"
			elif _choix_mode == "nation" and str(Game.supporters["nation"].get("pays", "")) == p:
				deja = " ★"
			var b := Ui.bouton(nom + deja, Ui.NUIT_CLAIR, 20)
			b.custom_minimum_size = Vector2(340, 60)
			b.clip_text = true
			b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			var pp: String = p
			b.pressed.connect(func(): _choisir_pays(pp))
			grille.add_child(b)
		if liste.is_empty():
			_choix_liste.add_child(Ui.label("Aucun club connu pour l'instant : ouvre la carte pour charger les matchs.", 20, Ui.GRIS))
	_choix_liste.add_child(grille)


func _choisir_pays(pays: String) -> void:
	if _choix_mode == "nation":
		Game.choisir_nation_favorite(pays)
		_choix.visible = false
		_remplir()
		return
	if Supporters.attente_club(Game.supporters, pays, Game.maintenant()) > 0:
		return  # le club de ce pays ne peut pas encore changer
	_choix_pays = pays
	_recherche.text = ""
	_remplir_choix()


func _bouton_club(i: Dictionary, actuel: bool) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(340, 76)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var fond := Ui.boite(Ui.JAUNE.darkened(0.5) if actuel else Ui.NUIT_CLAIR, 16, 4, 4)
	b.add_theme_stylebox_override("normal", fond)
	b.add_theme_stylebox_override("hover", Ui.boite(Ui.NUIT_CLAIR.lightened(0.12), 16, 4, 4))
	b.add_theme_stylebox_override("pressed", fond)
	var h := Ui.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	h.offset_right = -8
	b.add_child(h)
	var ec := Ui.ecusson(i["sigle"], i["c1"], i["c2"], 44)
	ec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ec)
	var l := Ui.label(("★ " if actuel else "") + i["nom"], 19, Ui.BLANC, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(l)
	for c in b.find_children("*", "Control", true, false):  # sans_traduction
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cle: String = i["cle"]
	b.pressed.connect(func():
		if Game.choisir_club_favori(_choix_pays, cle) or actuel:
			_choix.visible = false
			_remplir())
	return b


static func _milliers(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
