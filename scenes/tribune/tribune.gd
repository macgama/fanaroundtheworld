extends Control
## « Ta tribune » : les trois FANZZY qui mènent le duel d'ambiance.
##   Chant (Voix ou Percussion), Tifo (Tifo ou Fidélité), Ola (Pyro ou Déplacement).
## Le FANZZY choisi apporte le geste de sa famille et ses petits bonus.
## Le skin (variante) est purement cosmétique.

var _colonnes: HBoxContainer


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color("#5b3fd1")
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
	var titre := Ui.label("TA TRIBUNE", 60, Ui.JAUNE, true, 10)
	haut.add_child(titre)
	var st := Ui.label("Trois FANZZY mènent ton duel. Le skin ne change que le look.", 22, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(st)

	var p: Dictionary = Game.params
	var m := Donnees.match_par_id(str(p.get("match_id", "")))
	if not m.is_empty():
		var f := FicheMatch.de(m)
		var info := Ui.panneau(Ui.NUIT, 18, 5)
		var mode: Dictionary = Game.MODES_SUIVI.get(p.get("mode", "stade"), {})
		info.add_child(Ui.label("%s – %s · %s" % [f["dom"]["nom"], f["ext"]["nom"], mode.get("titre", "")], 22, Ui.BLANC, true))
		haut.add_child(info)

	_colonnes = Ui.hbox(24)
	_colonnes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(_colonnes)

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var vers_club: bool = p.get("retour", "") == "club"
	var retour := Ui.bouton("Retour au fan club" if vers_club else "Retour à la carte", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(func():
		# Partir avant le duel rembourse le billet.
		if not m.is_empty():
			Game.gagner_jetons(int(p.get("cout", 0)))
		Game.aller(Game.SCENE_CLUB if vers_club else Game.SCENE_CARTE, p))
	bas.add_child(retour)
	if not m.is_empty():
		# trois façons de jouer le duel, avec la même tribune
		for mode_jeu in [
			["DUEL D'AMBIANCE", "rythme · 90 s", Game.SCENE_DUEL, Ui.JAUNE],
			["ARÈNE", "action 3 contre 3 · 2 min", Game.SCENE_ARENE, Ui.ROSE],
			["POUSSÉE", "cartes et ballon · 3 min", Game.SCENE_POUSSEE, Ui.VERT],
		]:
			var go := Ui.bouton("%s\n%s" % [mode_jeu[0], mode_jeu[1]], mode_jeu[3], 30)
			Ui.colorer_bouton(go, mode_jeu[3], true)
			go.custom_minimum_size = Vector2(330, 96)
			var scene: String = mode_jeu[2]
			go.pressed.connect(func():
				_noter_suivi(m, p)
				Game.aller(scene, p))
			bas.add_child(go)
		# le duel d'ambiance contre un vrai joueur (ami ou adversaire en ligne)
		var en_ligne := Ui.bouton("CONTRE UN JOUEUR\nami ou en ligne", Ui.BLEU, 30)
		en_ligne.custom_minimum_size = Vector2(330, 96)
		en_ligne.tooltip_text = "Duel d'ambiance contre un ami ou un autre joueur, sur ce match"
		en_ligne.pressed.connect(func():
			_noter_suivi(m, p)
			Game.aller(Game.SCENE_SALON, p))
		bas.add_child(en_ligne)
	_construire()


## Premier duel lancé : le match compte comme suivi (missions, popularité)
## et le billet n'est plus remboursable.
func _noter_suivi(m: Dictionary, p: Dictionary) -> void:
	if p.get("suivi_a_noter", false):
		p.erase("suivi_a_noter")
		Game.noter_suivi_favori(m, str(p.get("camp", "home")), str(p.get("mode", "pub")))
	p["cout"] = 0


func _construire() -> void:
	for c in _colonnes.get_children():
		c.queue_free()
	for i in Game.ORDRE_POSTES.size():
		_colonnes.add_child(_colonne(i))


func _colonne(i: int) -> Control:
	var poste: String = Game.ORDRE_POSTES[i]
	var info: Dictionary = Game.POSTES[poste]
	var z := Game.fanzzy_par_id(str(Game.equipe[i]))
	var pan := Ui.panneau()
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ui.vbox(8)
	pan.add_child(v)
	var h := Ui.hbox(10)
	h.add_child(Ui.label(info["titre"].to_upper(), 40, Ui.BLANC, true, 8))
	var touche := Ui.pastille("touche " + info["touche"], Ui.NUIT_CLAIR, 16)
	touche.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(touche)
	v.add_child(h)
	var fams: Array = info["familles"]
	v.add_child(Ui.label(" ou ".join(fams.map(func(fa): return Game.nom_famille(fa))), 18, Ui.GRIS))

	var hz := Ui.hbox(12)
	hz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(hz)
	var img := TextureRect.new()
	img.texture = Game.texture_fanzzy(z["id"])
	img.custom_minimum_size = Vector2(190, 340)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hz.add_child(img)
	var vd := Ui.vbox(6)
	vd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hz.add_child(vd)
	var nom := Ui.label(_nom_skin(z), 26, Ui.JAUNE, true, 6)
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vd.add_child(nom)
	vd.add_child(Ui.pastille(Game.nom_famille(z["famille"]), Game.couleur_famille(z["famille"]), 16, z["famille"] in ["voix", "fide"]))
	var cri := Ui.label("Cri : « %s »" % z["cri"]["label"], 18, Ui.BLANC, true)
	cri.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vd.add_child(cri)
	for e in Duel.effets_texte(z):
		var l := Ui.label("+ " + e, 17, Ui.VERT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vd.add_child(l)
	var hist := Ui.label(z.get("histoire", ""), 15, Ui.GRIS)
	hist.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vd.add_child(hist)

	# skins (cosmétiques)
	var hs := Ui.hbox(8)
	hs.alignment = BoxContainer.ALIGNMENT_CENTER
	var skins: Array = z["skins"]
	var idx := skins.map(func(s): return s["id"]).find(Game.skin_de(z["id"]))
	var g := Ui.bouton("<", Ui.NUIT_CLAIR, 24)
	var d := Ui.bouton(">", Ui.NUIT_CLAIR, 24)
	var lbl := Ui.label("Skin %d / %d" % [idx + 1, skins.size()], 20, Ui.BLANC, true)
	g.pressed.connect(func(): _changer_skin(z, -1))
	d.pressed.connect(func(): _changer_skin(z, 1))
	hs.add_child(g)
	hs.add_child(lbl)
	hs.add_child(d)
	v.add_child(hs)

	# autres FANZZY possibles à ce poste
	var grille := GridContainer.new()
	grille.columns = 6
	grille.add_theme_constant_override("h_separation", 6)
	grille.add_theme_constant_override("v_separation", 6)
	for autre in Game.fanzzy_pour_poste(poste):
		var b := Button.new()
		b.custom_minimum_size = Vector2(76, 76)
		b.tooltip_text = "%s (%s)" % [autre["nom"], Game.nom_famille(autre["famille"])]
		var choisi: bool = autre["id"] == z["id"]
		b.add_theme_stylebox_override("normal", Ui.boite(Game.couleur_famille(autre["famille"]).darkened(0.2), 14, 4 if not choisi else 5, 0, Ui.JAUNE if choisi else Ui.CONTOUR))
		b.add_theme_stylebox_override("hover", Ui.boite(Game.couleur_famille(autre["famille"]), 14, 4, 0))
		b.add_theme_stylebox_override("pressed", Ui.boite(Ui.JAUNE, 14, 4, 0))
		b.icon = Game.texture_fanzzy(autre["id"], true)
		b.expand_icon = true
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var id: String = autre["id"]
		b.pressed.connect(func():
			Game.equipe[i] = id
			Game.sauver()
			_construire())
		grille.add_child(b)
	v.add_child(grille)
	return pan


func _nom_skin(z: Dictionary) -> String:
	var s := Game.skin_de(z["id"])
	for sk in z["skins"]:
		if sk["id"] == s:
			return sk["nom"]
	return z["nom"]


func _changer_skin(z: Dictionary, sens: int) -> void:
	var ids: Array = z["skins"].map(func(s): return s["id"])
	var i := ids.find(Game.skin_de(z["id"]))
	Game.skins[z["id"]] = ids[posmod(i + sens, ids.size())]
	Game.sauver()
	_construire()
