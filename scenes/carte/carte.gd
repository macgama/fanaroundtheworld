extends Control
## Écran « Carte du monde » : trois niveaux de zoom.
##   Monde     -> compétitions mondiales + un repère par continent
##   Continent -> compétitions continentales + un repère par pays
##   Pays      -> championnat : un repère par stade
## À gauche : la liste des vrais matchs du niveau (filtrable par jour).
## À droite : la fiche du match choisi et le choix « où le suivre ».

const NOMS_CONTINENTS := {
	"Europe": "Europe", "Africa": "Afrique", "Asia": "Asie", "North America": "Amérique du Nord",
	"South America": "Amérique du Sud", "Oceania": "Océanie", "World": "Monde",
}
const MAX_LIGNES := 120

var niveau := "monde"     # "monde", "continent", "pays"
var continent := ""
var pays := ""
var jour_filtre := ""     # "" = toute la semaine, "direct" = en direct, sinon AAAA-MM-JJ
var match_choisi := ""
var camp := "home"
var mode_suivi := "stade"

var carte: CarteMonde
var _titre_liste: Label
var _sous_titre_liste: Label
var _jours: HBoxContainer
var _liste: VBoxContainer
var _fil: HBoxContainer
var _fiche: PanelContainer
var _fiche_contenu: VBoxContainer
var _etat_donnees: Label
var _jetons: Label
var _niveau_lbl: Label
var _barre_xp: ProgressBar


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	carte = CarteMonde.new()
	carte.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(carte)
	carte.position_joueur = Vector2(float(Game.position_club["lon"]), float(Game.position_club["lat"]))
	carte.avatar = Game.texture_fanzzy(str(Game.equipe[0]), true) if Game.equipe.size() > 0 else null
	carte.epingle_cliquee.connect(_sur_epingle)
	carte.pays_clique.connect(_sur_pays_clique)
	_construire_interface()
	Donnees.mis_a_jour.connect(_sur_donnees)
	resized.connect(_placer_vue)
	# Revenir là où on était (après un duel par exemple)
	var p: Dictionary = Game.params
	niveau = p.get("niveau", "monde")
	continent = p.get("continent", "")
	pays = p.get("pays", "")
	_rafraichir(false)
	if p.has("match_id") and not Donnees.match_par_id(p["match_id"]).is_empty():
		_choisir_match(p["match_id"])


func _placer_vue() -> void:
	# La carte est visible entre le panneau de gauche et celui de droite.
	var droite := 520.0 if _fiche.visible else 40.0
	carte.centre_utile = Vector2(500.0 + (size.x - 500.0 - droite) / 2.0, size.y / 2.0 + 10.0)
	carte.largeur_utile = size.x - 500.0 - droite
	_cadrer(false)


# ------------------------------------------------------------------ interface

func _construire_interface() -> void:
	# --- barre du haut
	var haut := Ui.hbox(16)
	haut.position = Vector2(28, 20)
	haut.size = Vector2(1860, 80)
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 28
	haut.offset_right = -28
	haut.offset_top = 18
	add_child(haut)

	var profil := Ui.panneau(Ui.NUIT, 20, 5)
	var hp := Ui.hbox(12)
	profil.add_child(hp)
	if Game.club_cree():
		var cc := Game.couleurs_club()
		hp.add_child(Ui.ecusson(FanClub.sigle(Game.fan_club_nom), cc[0], cc[1], 52))
	else:
		var tex := TextureRect.new()
		tex.texture = Game.texture_fanzzy(str(Game.equipe[0]), true) if Game.equipe.size() > 0 else null
		tex.custom_minimum_size = Vector2(56, 56)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hp.add_child(tex)
	var vp := Ui.vbox(2)
	hp.add_child(vp)
	var nom := Ui.label(Game.fan_club_nom.to_upper(), 26, Ui.BLANC, true, 6)
	vp.add_child(nom)
	var hl := Ui.hbox(8)
	vp.add_child(hl)
	_niveau_lbl = Ui.label("NIV. 1", 18, Ui.JAUNE, true)
	hl.add_child(_niveau_lbl)
	_barre_xp = ProgressBar.new()
	_barre_xp.custom_minimum_size = Vector2(180, 16)
	_barre_xp.show_percentage = false
	_barre_xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barre_xp.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 8, 3))
	_barre_xp.add_theme_stylebox_override("fill", Ui.boite(Ui.BLEU, 8, 0))
	hl.add_child(_barre_xp)
	haut.add_child(profil)

	haut.add_child(Ui.espace())
	_fil = Ui.hbox(8)
	_fil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(_fil)
	haut.add_child(Ui.espace())

	var etat := Ui.panneau(Ui.NUIT, 20, 5)
	_etat_donnees = Ui.label("", 18, Ui.GRIS)
	etat.add_child(_etat_donnees)
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(etat)
	var jet := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 36))
	_jetons = Ui.label("", 28, Ui.JAUNE, true, 6)
	hj.add_child(_jetons)
	jet.add_child(hj)
	jet.tooltip_text = "Jetons : gagnés en jouant, ils payent billets et trajets."
	haut.add_child(jet)
	var tamp := Ui.panneau(Ui.NUIT, 20, 5)
	var ht := Ui.hbox(8)
	ht.add_child(Ui.icone("tampon", 36))
	ht.add_child(Ui.label("%d" % Game.tampons.size(), 28, Ui.BLANC, true, 6))
	tamp.add_child(ht)
	tamp.tooltip_text = "Stades tamponnés"
	haut.add_child(tamp)

	# --- panneau de gauche : liste des matchs
	var gauche := Ui.panneau()
	gauche.position = Vector2(28, 122)
	gauche.size = Vector2(450, 0)
	gauche.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	gauche.offset_left = 28
	gauche.offset_top = 122
	gauche.offset_right = 478
	gauche.offset_bottom = -132
	add_child(gauche)
	var vg := Ui.vbox(8)
	gauche.add_child(vg)
	_titre_liste = Ui.label("", 34, Ui.BLANC, true, 6)
	_titre_liste.clip_text = true
	vg.add_child(_titre_liste)
	_sous_titre_liste = Ui.label("", 17, Ui.GRIS)
	_sous_titre_liste.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vg.add_child(_sous_titre_liste)
	var sj := ScrollContainer.new()
	sj.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sj.custom_minimum_size = Vector2(0, 52)
	_jours = Ui.hbox(6)
	sj.add_child(_jours)
	vg.add_child(sj)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_liste = Ui.vbox(8)
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_liste)
	vg.add_child(sc)

	# --- fiche du match (à droite)
	_fiche = Ui.panneau()
	_fiche.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_fiche.offset_left = -500
	_fiche.offset_right = -28
	_fiche.offset_top = 122
	_fiche.offset_bottom = -132
	_fiche.visible = false
	add_child(_fiche)
	var sf := ScrollContainer.new()
	sf.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fiche.add_child(sf)
	_fiche_contenu = Ui.vbox(12)
	_fiche_contenu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sf.add_child(_fiche_contenu)

	# --- barre du bas
	var bas := Ui.hbox(18)
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.offset_top = -112
	bas.offset_bottom = -20
	bas.offset_left = -470
	bas.offset_right = 470
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bas)
	var b_carte := Ui.bouton("Carte", Ui.JAUNE, 30)
	Ui.colorer_bouton(b_carte, Ui.JAUNE, true)
	b_carte.custom_minimum_size = Vector2(210, 88)
	b_carte.pressed.connect(func(): _aller_monde())
	bas.add_child(b_carte)
	var b_tribune := Ui.bouton("FANZZY", Ui.VIOLET, 30)
	b_tribune.custom_minimum_size = Vector2(210, 88)
	b_tribune.tooltip_text = "Choisir les FANZZY de ta tribune et leurs skins"
	b_tribune.pressed.connect(func(): Game.aller(Game.SCENE_TRIBUNE, {"retour": "carte", "niveau": niveau, "continent": continent, "pays": pays}))
	bas.add_child(b_tribune)
	var b_club := Ui.bouton("Fan Club", Ui.ROSE, 30)
	b_club.custom_minimum_size = Vector2(210, 88)
	b_club.tooltip_text = "Membres, cotisations, buvette et écharpes"
	b_club.pressed.connect(func(): Game.aller(Game.SCENE_CLUB if Game.club_cree() else Game.SCENE_CREATION_CLUB))
	bas.add_child(b_club)
	var b_pass := Ui.bouton("PASS", Ui.NUIT_CLAIR, 30)
	b_pass.custom_minimum_size = Vector2(210, 88)
	b_pass.disabled = true
	b_pass.tooltip_text = "Bientôt"
	bas.add_child(b_pass)

	_placer_vue()


# ------------------------------------------------------------------ navigation

func _aller_monde() -> void:
	niveau = "monde"
	continent = ""
	pays = ""
	_fermer_fiche()
	_rafraichir()


func _aller_continent(c: String) -> void:
	niveau = "continent"
	continent = c
	pays = ""
	_fermer_fiche()
	_rafraichir()


func _aller_pays(cle: String) -> void:
	niveau = "pays"
	pays = cle
	continent = Geo.continent_de(cle)
	_fermer_fiche()
	_rafraichir()


func _sur_pays_clique(cle: String) -> void:
	var c := Geo.continent_de(cle)
	if niveau == "monde" and c in Geo.CONTINENTS:
		_aller_continent(c)
	elif niveau != "monde":
		_aller_pays(cle)


func _sur_epingle(e: Dictionary) -> void:
	match e.get("type", ""):
		"continent":
			_aller_continent(e["cle"])
		"pays":
			_aller_pays(e["cle"])
		"stade":
			var ids: Array = e.get("matchs", [])
			if ids.size() > 0:
				_choisir_match(ids[0])


func _cadrer(anime := true) -> void:
	match niveau:
		"monde":
			carte.voir(Vector2(10, 25), 330.0, anime)
		"continent":
			var v: Array = Geo.VUES_CONTINENTS.get(continent, [Vector2(0, 20), 300.0])
			carte.voir(v[0], v[1], anime)
		"pays":
			carte.voir(Geo.centre_pays(pays), Geo.taille_pays(pays) * 1.5, anime)


func _sur_donnees() -> void:
	FicheMatch.oublier()
	_rafraichir(false)
	if match_choisi != "":
		_afficher_fiche()


# ------------------------------------------------------------------ contenu

func _matchs_du_niveau() -> Array:
	## Fiches des matchs à lister pour le niveau courant (tous jours confondus).
	var res: Array = []
	for m in Donnees.matchs():
		var f := FicheMatch.de(m)
		var l: Dictionary = f["lieu"]
		match niveau:
			"monde":
				if l["niveau"] == "monde":
					res.append(f)
			"continent":
				if l["niveau"] == "continent" and l["continent"] == continent:
					res.append(f)
			"pays":
				if l["pays"] == pays:
					res.append(f)
	return res


func _filtrer_jour(fiches: Array) -> Array:
	if jour_filtre == "":
		return fiches
	if jour_filtre == "direct":
		return fiches.filter(func(f): return Donnees.en_direct(f["m"]))
	return fiches.filter(func(f): return FicheMatch.jour_local(f["t"]) == jour_filtre)


func _rafraichir(anime := true) -> void:
	_niveau_lbl.text = "NIV. %d" % Game.niveau()
	_barre_xp.value = Game.xp_dans_niveau() * 100.0
	_jetons.text = "%d" % Game.jetons
	var src := Donnees.source
	if Donnees.hors_ligne and src != "en ligne":
		src += " · hors ligne"
	var nb_direct := Donnees.matchs().filter(func(m): return Donnees.en_direct(m)).size()
	_etat_donnees.text = "%d matchs · %d en direct · %s" % [Donnees.matchs().size(), nb_direct, src]
	_construire_fil()
	_construire_epingles()
	_construire_liste()
	_cadrer(anime)


func _construire_fil() -> void:
	for c in _fil.get_children():
		c.queue_free()
	var b := Ui.bouton("Monde", Ui.JAUNE if niveau == "monde" else Ui.NUIT, 24)
	if niveau == "monde":
		Ui.colorer_bouton(b, Ui.JAUNE, true)
	b.pressed.connect(_aller_monde)
	_fil.add_child(b)
	if niveau != "monde":
		_fil.add_child(Ui.label("›", 34, Ui.BLANC, true, 6))
		var bc := Ui.bouton(NOMS_CONTINENTS.get(continent, continent), Ui.NUIT, 24)
		if niveau == "continent":
			Ui.colorer_bouton(bc, Ui.JAUNE, true)
		var c := continent
		bc.pressed.connect(func(): _aller_continent(c))
		_fil.add_child(bc)
	if niveau == "pays":
		_fil.add_child(Ui.label("›", 34, Ui.BLANC, true, 6))
		var bp := Ui.bouton(Geo.nom_pays(pays), Ui.JAUNE, 24)
		Ui.colorer_bouton(bp, Ui.JAUNE, true)
		_fil.add_child(bp)


func _construire_epingles() -> void:
	var ep: Array = []
	var toutes: Array = Donnees.matchs().map(func(m): return FicheMatch.de(m))
	toutes = _filtrer_jour(toutes)
	match niveau:
		"monde":
			carte.surligner([])
			var par_continent := {}
			for f in toutes:
				var c: String = f["lieu"]["continent"]
				if not c in Geo.CONTINENTS:
					continue
				if not par_continent.has(c):
					par_continent[c] = {"n": 0, "direct": false}
				par_continent[c]["n"] += 1
				if Donnees.en_direct(f["m"]):
					par_continent[c]["direct"] = true
			for c in Geo.CONTINENTS:
				var d: Dictionary = par_continent.get(c, {"n": 0, "direct": false})
				ep.append({"type": "continent", "cle": c, "pos": Geo.CENTRES_CONTINENTS[c], "titre": NOMS_CONTINENTS[c],
					"sous_titre": "%d matchs" % d["n"], "nombre": str(d["n"]), "couleur": Ui.VIOLET, "direct": d["direct"]})
			_ajouter_stades(ep, toutes.filter(func(f): return f["lieu"]["niveau"] == "monde"))
		"continent":
			var cles: Array = []
			for cle in Geo.formes():
				if Geo.continent_de(cle) == continent:
					cles.append(cle)
			carte.surligner(cles)
			var par_pays := {}
			for f in toutes:
				var l: Dictionary = f["lieu"]
				if l["pays"] == "" or Geo.continent_de(l["pays"]) != continent:
					continue
				if not par_pays.has(l["pays"]):
					par_pays[l["pays"]] = {"n": 0, "direct": false}
				par_pays[l["pays"]]["n"] += 1
				if Donnees.en_direct(f["m"]):
					par_pays[l["pays"]]["direct"] = true
			for cle in par_pays:
				var info := Geo.info_pays(cle)
				ep.append({"type": "pays", "cle": cle, "pos": Vector2(float(info["lon"]), float(info["lat"])),
					"titre": "", "sous_titre": "", "nombre": str(par_pays[cle]["n"]), "couleur": Ui.ROSE,
					"direct": par_pays[cle]["direct"], "nom": Geo.nom_pays(cle)})
			# les pays avec beaucoup de matchs affichent leur nom
			ep.sort_custom(func(a, b): return int(a["nombre"]) < int(b["nombre"]))
			for i in ep.size():
				if i >= ep.size() - 8:
					ep[i]["titre"] = ep[i]["nom"]
			_ajouter_stades(ep, toutes.filter(func(f): return f["lieu"]["niveau"] == "continent" and f["lieu"]["continent"] == continent))
		"pays":
			carte.surligner([pays], true)
			_ajouter_stades(ep, toutes.filter(func(f): return f["lieu"]["pays"] == pays))
	carte.epingles = ep


func _ajouter_stades(ep: Array, fiches: Array) -> void:
	var par_stade := {}
	for f in fiches:
		var cle: String = f["lieu"]["stade"]
		if not par_stade.has(cle):
			par_stade[cle] = {"type": "stade", "cle": cle, "pos": Vector2(f["lieu"]["lon"], f["lieu"]["lat"]),
				"titre": f["stade"]["nom"], "sous_titre": "", "matchs": [], "couleur": Ui.JAUNE, "direct": false}
		var e: Dictionary = par_stade[cle]
		e["matchs"].append(f["id"])
		if Donnees.en_direct(f["m"]):
			e["direct"] = true
			e["couleur"] = Ui.ROUGE
		if e["sous_titre"] == "":
			e["sous_titre"] = "%s – %s · %s" % [f["dom"]["nom"], f["ext"]["nom"], FicheMatch.statut_court(f)]
		if f["id"] == match_choisi:
			e["choisie"] = true
	for e in par_stade.values():
		if Game.a_tampon(e["cle"]):
			e["couleur"] = Ui.VERT if not e["direct"] else e["couleur"]
		e["nombre"] = str(e["matchs"].size()) if e["matchs"].size() > 1 else ""
		ep.append(e)


func _construire_liste() -> void:
	for c in _liste.get_children():
		c.queue_free()
	for c in _jours.get_children():
		c.queue_free()
	var fiches := _matchs_du_niveau()
	match niveau:
		"monde":
			_titre_liste.text = "Matchs du monde"
			_sous_titre_liste.text = "Sélections et compétitions mondiales. Choisis un continent pour les coupes continentales, puis un pays pour son championnat."
		"continent":
			_titre_liste.text = "Coupes · " + NOMS_CONTINENTS.get(continent, continent)
			_sous_titre_liste.text = "Compétitions continentales. Clique sur un pays pour voir son championnat."
		"pays":
			_titre_liste.text = Geo.nom_pays(pays)
			var comps := {}
			for f in fiches:
				comps[f["competition"]] = true
			_sous_titre_liste.text = ", ".join(comps.keys()) if not comps.is_empty() else "Championnat national"

	# onglets des jours
	var jours := {}
	var nb_direct := 0
	for f in fiches:
		jours[FicheMatch.jour_local(f["t"])] = true
		if Donnees.en_direct(f["m"]):
			nb_direct += 1
	var aujourdhui := FicheMatch.jour_local(int(Time.get_unix_time_from_system()))
	_onglet_jour("Tous", "")
	if nb_direct > 0:
		_onglet_jour("Direct %d" % nb_direct, "direct", Ui.ROUGE)
	var liste_jours := jours.keys()
	liste_jours.sort()
	for j in liste_jours:
		if j < aujourdhui:
			continue
		var t := int(Time.get_unix_time_from_datetime_string(j + "T12:00:00"))
		var txt: String = "Auj." if j == aujourdhui else FicheMatch.JOURS[Time.get_datetime_dict_from_unix_time(t)["weekday"]] + " " + str(int(j.right(2)))
		_onglet_jour(txt, j)

	fiches = _filtrer_jour(fiches)
	if fiches.is_empty():
		var l := Ui.label("Aucun match ici pour ce filtre. Essaie un autre jour, ou un autre niveau de la carte.", 19, Ui.GRIS)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_liste.add_child(l)
		return
	# les matchs en direct d'abord, puis les prochains, puis les terminés
	var maintenant := int(Time.get_unix_time_from_system())
	fiches.sort_custom(func(a, b):
		var ra := _rang(a, maintenant)
		var rb := _rang(b, maintenant)
		return ra < rb if ra != rb else int(a["t"]) < int(b["t"]))
	for i in mini(fiches.size(), MAX_LIGNES):
		_liste.add_child(_carte_match(fiches[i]))
	if fiches.size() > MAX_LIGNES:
		_liste.add_child(Ui.label("… et %d autres matchs : filtre par jour ou zoome sur un pays." % (fiches.size() - MAX_LIGNES), 17, Ui.GRIS))


static func _rang(f: Dictionary, maintenant: int) -> int:
	if Donnees.en_direct(f["m"]):
		return 0
	if str(f["m"].get("status", "")) == "SCHEDULED" and int(f["t"]) > maintenant - 3 * 3600:
		return 1
	return 2


func _onglet_jour(texte: String, valeur: String, couleur := Ui.NUIT_CLAIR) -> void:
	var b := Ui.bouton(texte, couleur, 18)
	if jour_filtre == valeur:
		Ui.colorer_bouton(b, Ui.JAUNE, true)
	b.pressed.connect(func():
		jour_filtre = valeur
		_rafraichir(false))
	_jours.add_child(b)


func _carte_match(f: Dictionary) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var choisi: bool = f["id"] == match_choisi
	var fond := Ui.boite(Ui.JAUNE.darkened(0.55) if choisi else Ui.NUIT_CLAIR, 18, 4 if not choisi else 5, 4, Ui.JAUNE if choisi else Ui.CONTOUR)
	b.add_theme_stylebox_override("normal", fond)
	b.add_theme_stylebox_override("hover", Ui.boite(Ui.NUIT_CLAIR.lightened(0.1), 18, 4, 4))
	b.add_theme_stylebox_override("pressed", fond)
	var h := Ui.hbox(12)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -12
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ec := Ui.ecusson(f["dom"]["sigle"], f["dom"]["c1"], f["dom"]["c2"], 46)
	ec.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ec.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ec)
	var v := Ui.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(v)
	var noms := Ui.label("%s – %s" % [f["dom"]["nom"], f["ext"]["nom"]], 21, Ui.BLANC, true)
	noms.clip_text = true
	noms.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(noms)
	var comp := Ui.label("%s · %s" % [f["competition"], FicheMatch.date_texte(f["t"])], 15, Ui.GRIS)
	comp.clip_text = true
	comp.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(comp)
	var direct := Donnees.en_direct(f["m"])
	var statut := str(f["m"].get("status", ""))
	var droite := Ui.vbox(2)
	droite.alignment = BoxContainer.ALIGNMENT_CENTER
	droite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(droite)
	if direct or statut == "FINISHED":
		var sc := Ui.label(Donnees.score_texte(f["m"]), 24, Ui.BLANC, true, 5)
		sc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		droite.add_child(sc)
	var pas := Ui.pastille(FicheMatch.statut_court(f), Ui.ROUGE if direct else (Ui.VERT if statut == "SCHEDULED" else Color("#6b6699")), 15)
	pas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	droite.add_child(pas)
	for c in b.find_children("*", "Control", true, false):
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var id: String = f["id"]
	b.pressed.connect(func(): _choisir_match(id))
	return b


# ------------------------------------------------------------------ fiche du match

func _choisir_match(id: String) -> void:
	match_choisi = id
	camp = "home"
	var f := FicheMatch.de(Donnees.match_par_id(id))
	# Choisir un stade depuis le monde ou un continent ouvre le pays du match.
	if niveau != "pays" and f["lieu"]["pays"] != "" and f["lieu"]["niveau"] == "pays":
		niveau = "pays"
		pays = f["lieu"]["pays"]
		continent = Geo.continent_de(pays)
	_fiche.visible = true
	_placer_vue()
	_rafraichir()
	_afficher_fiche()
	Ui.pop(_fiche, 1.03)


func _fermer_fiche() -> void:
	match_choisi = ""
	_fiche.visible = false
	_placer_vue()


func _afficher_fiche() -> void:
	for c in _fiche_contenu.get_children():
		c.queue_free()
	var m := Donnees.match_par_id(match_choisi)
	if m.is_empty():
		_fermer_fiche()
		return
	var f := FicheMatch.de(m)
	var v := _fiche_contenu

	var fermer := Ui.bouton("X", Ui.NUIT_CLAIR, 20)
	fermer.size_flags_horizontal = Control.SIZE_SHRINK_END
	fermer.pressed.connect(func():
		_fermer_fiche()
		_rafraichir())
	var h0 := Ui.hbox(8)
	h0.add_child(Ui.label(f["competition"], 18, Ui.GRIS))
	h0.get_child(0).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h0.add_child(fermer)
	v.add_child(h0)

	var eq := Ui.hbox(10)
	eq.alignment = BoxContainer.ALIGNMENT_CENTER
	eq.add_child(_bloc_equipe(f["dom"]))
	var mil := Ui.vbox(4)
	mil.alignment = BoxContainer.ALIGNMENT_CENTER
	var direct := Donnees.en_direct(m)
	var statut := str(m.get("status", ""))
	mil.add_child(Ui.label(Donnees.score_texte(m) if direct or statut == "FINISHED" else "VS", 40, Ui.JAUNE, true, 8))
	var p := Ui.pastille(FicheMatch.statut_court(f), Ui.ROUGE if direct else Color("#6b6699"), 16)
	mil.add_child(p)
	eq.add_child(mil)
	eq.add_child(_bloc_equipe(f["ext"]))
	v.add_child(eq)

	v.add_child(_ligne("stade", f["stade"]["nom"], "%s places" % _milliers(f["stade"]["places"])))
	v.add_child(_ligne("calendrier", "Match réel", "%s · %s" % [FicheMatch.date_texte(f["t"]), FicheMatch.heure_texte(f["t"])]))
	v.add_child(_ligne("feu", "Ambiance prévue", "%d / 5" % FicheMatch.ambiance_prevue(f)))
	var tamp := Game.a_tampon(f["stade"]["cle"])
	v.add_child(_ligne("tampon", "Tampon du stade", "déjà dans ta collection" if tamp else "à gagner au stade"))

	# camp supporté
	v.add_child(Ui.label("Tu supportes", 22, Ui.BLANC, true))
	var hc := Ui.hbox(10)
	for cote in ["home", "away"]:
		var e: Dictionary = f["dom"] if cote == "home" else f["ext"]
		var b := Ui.bouton(e["nom"], Ui.BLEU if camp == cote else Ui.NUIT_CLAIR, 20)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		var cc: String = cote
		b.pressed.connect(func():
			camp = cc
			_afficher_fiche())
		hc.add_child(b)
	v.add_child(hc)

	# où suivre le match
	v.add_child(Ui.label("Où suivre le match ?", 22, Ui.BLANC, true))
	var pos_joueur := Vector2(float(Game.position_club["lon"]), float(Game.position_club["lat"]))
	var dist := Geo.distance_km(pos_joueur, Vector2(f["lieu"]["lon"], f["lieu"]["lat"]))
	var grille := GridContainer.new()
	grille.columns = 2
	grille.add_theme_constant_override("h_separation", 10)
	grille.add_theme_constant_override("v_separation", 10)
	for mode in Game.ORDRE_MODES:
		var info: Dictionary = Game.MODES_SUIVI[mode]
		var cout := Game.cout_suivi(mode, dist)
		var b := Button.new()
		b.custom_minimum_size = Vector2(205, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var choisi: bool = mode == mode_suivi
		b.add_theme_stylebox_override("normal", Ui.boite(Ui.BLEU if choisi else Ui.NUIT_CLAIR, 16, 4, 4, Ui.JAUNE if choisi else Ui.CONTOUR))
		b.add_theme_stylebox_override("hover", Ui.boite(Ui.NUIT_CLAIR.lightened(0.1), 16, 4, 4))
		b.add_theme_stylebox_override("pressed", Ui.boite(Ui.BLEU, 16, 4, 2))
		b.add_theme_stylebox_override("disabled", Ui.boite(Color("#3a3560"), 16, 4, 2))
		var vb := Ui.vbox(0)
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.offset_left = 12
		vb.offset_top = 6
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(Ui.label(info["titre"], 21, Ui.BLANC, true))
		vb.add_child(Ui.label(info["texte"], 13, Ui.GRIS))
		var hp := Ui.hbox(6)
		if cout > 0:
			hp.add_child(Ui.icone("jeton", 22))
		hp.add_child(Ui.label(str(cout) if cout > 0 else "Gratuit", 18, Ui.JAUNE if cout <= Game.jetons else Ui.ROUGE, true))
		vb.add_child(hp)
		for c in vb.find_children("*", "Control", true, false):
			(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(vb)
		b.disabled = cout > Game.jetons
		var md: String = mode
		b.pressed.connect(func():
			mode_suivi = md
			_afficher_fiche())
		grille.add_child(b)
	v.add_child(grille)
	if mode_suivi == "stade":
		var trajet := "Trajet : %s km" % _milliers(int(dist)) if dist >= 30 else "Tu es déjà sur place"
		v.add_child(Ui.label(trajet + " · gains ×%s" % str(Game.MODES_SUIVI[mode_suivi]["gain"]), 17, Ui.GRIS))
	else:
		v.add_child(Ui.label("Pas de trajet · gains ×%s · pas de tampon" % str(Game.MODES_SUIVI[mode_suivi]["gain"]), 17, Ui.GRIS))

	var cout_final := Game.cout_suivi(mode_suivi, dist)
	var go := Ui.bouton("C'EST PARTI !", Ui.JAUNE, 40)
	Ui.colorer_bouton(go, Ui.JAUNE, true)
	go.custom_minimum_size = Vector2(0, 96)
	go.disabled = not FicheMatch.jouable(f) or cout_final > Game.jetons
	if not FicheMatch.jouable(f):
		go.text = FicheMatch.STATUTS.get(statut, "Indisponible")
	go.pressed.connect(func(): _partir(f, cout_final))
	v.add_child(go)


func _partir(f: Dictionary, cout: int) -> void:
	if not Game.depenser(cout):
		return
	var p := {
		"match_id": f["id"], "camp": camp, "mode": mode_suivi, "cout": cout,
		"niveau": niveau, "continent": continent, "pays": pays,
	}
	if mode_suivi == "stade":
		Game.aller(Game.SCENE_VOYAGE, p)
	else:
		Game.aller(Game.SCENE_TRIBUNE, p)


func _bloc_equipe(e: Dictionary) -> Control:
	var v := Ui.vbox(4)
	v.custom_minimum_size = Vector2(150, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	var ec := Ui.ecusson(e["sigle"], e["c1"], e["c2"], 76)
	ec.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ec)
	var l := Ui.label(e["nom"], 21, Ui.BLANC, true, 5)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(150, 0)
	v.add_child(l)
	return v


func _ligne(icone: String, titre: String, valeur: String) -> Control:
	var h := Ui.hbox(8)
	h.add_child(Ui.icone(icone, 28))
	var t := Ui.label(titre, 18, Ui.BLANC)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(t)
	h.add_child(Ui.label(valeur, 18, Ui.JAUNE, true))
	return h


static func _milliers(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
