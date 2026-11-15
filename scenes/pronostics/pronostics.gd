extends Control
## « Mes pronos » : pronostics en attente, résultats récents, série en cours.
## Les pronostics sont gratuits et sans mise : un bon prono rapporte des
## Jetons, un mauvais ne coûte rien (il remet seulement la série à zéro).

var _liste: VBoxContainer
var _jetons: Label
var _serie: Label


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color("#c2306b")
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
	haut.add_child(Ui.label("MES PRONOS", 60, Ui.JAUNE, true, 10))
	var st := Ui.label("Gratuits, sans mise : devine les vrais matchs et gagne des Jetons.", 22, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	st.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	haut.add_child(st)
	var jet := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 36))
	_jetons = Ui.label("", 28, Ui.JAUNE, true, 6)
	hj.add_child(_jetons)
	jet.add_child(hj)
	jet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(jet)

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)

	# --- à gauche : série et règles
	var gauche := Ui.panneau()
	gauche.custom_minimum_size = Vector2(560, 0)
	corps.add_child(gauche)
	var vg := Ui.vbox(14)
	gauche.add_child(vg)
	vg.add_child(Ui.label("Ta série", 34, Ui.BLANC, true, 6))
	_serie = Ui.label("", 26, Ui.JAUNE, true, 6)
	_serie.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vg.add_child(_serie)
	vg.add_child(Ui.label("Comment ça marche", 26, Ui.BLANC, true))
	for ligne in [
		"Choisis un match à venir sur la carte, puis un score et l'équipe qui marque en premier.",
		"Bon résultat (victoire, nul ou défaite) : +%d Jetons." % Pronostics.RECOMPENSE_RESULTAT,
		"Score exact : +%d de plus." % Pronostics.RECOMPENSE_SCORE,
		"Premier but trouvé : +%d." % Pronostics.RECOMPENSE_PREMIER_BUT,
		"Chaque bon résultat d'affilée ajoute +%d %% à tes gains, jusqu'à ×%s." % [int(Pronostics.PAS_SERIE * 100), str(Pronostics.MULTI_MAX)],
		"Rien à miser, rien à perdre : un mauvais prono remet juste la série à zéro.",
		"Score de fin de match, prolongation comprise, sans les tirs au but. Modifiable jusqu'au coup d'envoi.",
		"%d pronos en attente au maximum." % Pronostics.MAX_EN_ATTENTE,
	]:
		var l := Ui.label("• " + ligne, 19, Ui.GRIS)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vg.add_child(l)

	# --- à droite : la liste
	var droite := Ui.panneau()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(droite)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	droite.add_child(sc)
	_liste = Ui.vbox(10)
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_liste)

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CARTE, Game.params))
	bas.add_child(retour)

	Game.pronostics_resolus.connect(func(_l): _remplir())
	Donnees.mis_a_jour.connect(_remplir)
	_remplir()


func _remplir() -> void:
	_jetons.text = "%d" % Game.jetons
	var multi := Pronostics.multiplicateur(Game.serie_pronos)
	_serie.text = "%d bon%s résultat%s d'affilée · gains ×%s\nMeilleure série : %d" % [
		Game.serie_pronos, "s" if Game.serie_pronos > 1 else "", "s" if Game.serie_pronos > 1 else "",
		str(multi), Game.meilleure_serie]
	for c in _liste.get_children():
		c.queue_free()
	var attente := Game.pronos.values()
	attente.sort_custom(func(a, b): return int(a["kickoff"]) < int(b["kickoff"]))
	_liste.add_child(Ui.label("En attente (%d / %d)" % [attente.size(), Pronostics.MAX_EN_ATTENTE], 28, Ui.BLANC, true, 6))
	if attente.is_empty():
		var l := Ui.label("Aucun prono en cours. Ouvre un match à venir sur la carte pour en faire un.", 19, Ui.GRIS)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_liste.add_child(l)
	for p in attente:
		_liste.add_child(_ligne(p))
	if not Game.pronos_finis.is_empty():
		_liste.add_child(Ui.label("Résultats", 28, Ui.BLANC, true, 6))
		for p in Game.pronos_finis:
			_liste.add_child(_ligne(p))


func _ligne(p: Dictionary) -> Control:
	var sel := Fiction.est_selection(p)
	var dom := Fiction.equipe(p.get("home", {}), sel)
	var ext := Fiction.equipe(p.get("away", {}), sel)
	var etat := str(p.get("etat", "attente"))
	var couleur := Ui.NUIT_CLAIR
	if etat == "gagne":
		couleur = Color("#2e7d5b")
	elif etat == "perdu" or etat == "annule":
		couleur = Color("#3a3560")
	var cadre := Ui.panneau(couleur, 18, 4)
	var h := Ui.hbox(12)
	cadre.add_child(h)
	h.add_child(Ui.ecusson(dom["sigle"], dom["c1"], dom["c2"], 46))
	var v := Ui.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var noms := Ui.label("%s – %s" % [dom["nom"], ext["nom"]], 21, Ui.BLANC, true)
	noms.clip_text = true
	noms.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(noms)
	v.add_child(Ui.label("%s · %s %s" % [Fiction.competition(p.get("competition", {})),
		FicheMatch.date_texte(int(p.get("kickoff", 0))), FicheMatch.heure_texte(int(p.get("kickoff", 0)))], 15, Ui.GRIS))
	v.add_child(Ui.label("Ton prono : " + PronoTexte.resume(p, dom["nom"], ext["nom"]), 18, Ui.JAUNE, true))
	var e := Ui.label(PronoTexte.etat(p), 16, Ui.BLANC)
	e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(e)
	h.add_child(Ui.ecusson(ext["sigle"], ext["c1"], ext["c2"], 46))
	if etat == "gagne":
		var hp := Ui.hbox(4)
		hp.add_child(Ui.icone("jeton", 28))
		hp.add_child(Ui.label("+%d" % int(p.get("jetons", 0)), 26, Ui.JAUNE, true, 6))
		h.add_child(hp)
	return cadre
