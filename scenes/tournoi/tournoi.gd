extends Control
## « Tournoi des fan clubs » du week-end (règles dans scripts/jeu/tournoi.gd).
## À gauche : ton club (inscription, points, prochain adversaire, récompense).
## À droite : classement des clubs, matchs du week-end, tes duels, règles.
## Tests : « -- --onglet=matchs|duels|regles ».

const Classement := preload("res://scenes/classement/classement.gd")
const ONGLETS := [["classement", "Classement"], ["matchs", "Matchs du week-end"], ["duels", "Mes duels"], ["regles", "Règles"]]

var _onglet := "classement"
var _gauche: VBoxContainer
var _droite: VBoxContainer
var _sous_titre: Label
var _nom: Array = []
var _couleurs: Array = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--onglet="):  # sans_traduction
			_onglet = arg.trim_prefix("--onglet=")  # sans_traduction
	Game.actualiser_tournoi()
	var t: Dictionary = Game.tournoi
	if bool(t["inscrit"]) or not (t["historique"] as Array).is_empty():
		_nom = (t["nom"] as Array).duplicate()
		_couleurs = (t["couleurs"] as Array).duplicate()
	else:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Game.fan_club_nom)
		_nom = Tournoi.nom_au_hasard(rng)
		_couleurs = Game.couleurs_club_index()

	var fond := ColorRect.new()
	fond.color = Color("#7a2fd1")
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
	haut.add_child(Ui.label("TOURNOI DES FAN CLUBS", 56, Ui.JAUNE, true, 10))
	_sous_titre = Ui.label("", 22, Ui.BLANC)
	_sous_titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sous_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sous_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haut.add_child(_sous_titre)

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)
	var pg := Ui.panneau()
	pg.custom_minimum_size = Vector2(640, 0)
	corps.add_child(pg)
	var sg := ScrollContainer.new()
	sg.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pg.add_child(sg)
	_gauche = Ui.vbox(14)
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
	var club := Ui.bouton("Fan Club", Ui.ROSE, 28)
	club.custom_minimum_size = Vector2(340, 84)
	club.pressed.connect(func(): Game.aller(Game.SCENE_CLUB if Game.club_cree() else Game.SCENE_CREATION_CLUB))
	bas.add_child(club)

	EnLigne.mis_a_jour.connect(_remplir)
	EnLigne.rafraichir_tournoi()
	_remplir()


func _remplir() -> void:
	if not is_inside_tree():
		return
	var f := Game.actualiser_tournoi()
	if f["etat"] == "actif":
		_sous_titre.text = tr("Ce week-end, ton fan club affronte ceux des autres joueurs sur les vrais matchs. Fin %s à %s.") % [
			FicheMatch.date_texte(int(f["fin"])), FicheMatch.heure_texte(int(f["fin"]))]
	else:
		_sous_titre.text = tr("Prochain tournoi : %s à %s. Prépare ta tribune !") % [
			FicheMatch.date_texte(int(f["prochain"])), FicheMatch.heure_texte(int(f["prochain"]))]
	_remplir_gauche(f)
	_remplir_droite(f)


# ------------------------------------------------------------------ ton club

func _remplir_gauche(f: Dictionary) -> void:
	for c in _gauche.get_children():
		c.queue_free()
	var t: Dictionary = Game.tournoi
	if not (t["a_reclamer"] as Dictionary).is_empty():
		_gauche.add_child(_carte_recompense(t["a_reclamer"]))
	if not Game.club_cree():
		_texte(_gauche, "Crée d'abord ton fan club : c'est lui qui part en tournoi.", 22, Ui.BLANC)
		var b := Ui.bouton("Créer mon fan club", Ui.JAUNE, 26)
		Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.pressed.connect(func(): Game.aller(Game.SCENE_CREATION_CLUB))
		_gauche.add_child(b)
		return
	_gauche.add_child(_carte_club(t))
	if f["etat"] != "actif":
		_texte(_gauche, tr("Le tournoi ouvre chaque vendredi à %s et se termine le lundi à %s (heure locale). Les inscriptions ouvrent avec lui.") % [
			FicheMatch.heure_texte(int(f["prochain"])), FicheMatch.heure_texte(int(f["prochain"]) + Tournoi.DUREE_S)], 19, Ui.GRIS)
		_historique(t)
		return
	if not bool(t["inscrit"]):
		_inscription()
		return
	_stats(t)
	_adversaire(t)


func _carte_club(t: Dictionary) -> Control:
	var carte := Ui.panneau(Ui.NUIT_CLAIR, 22, 4)
	var h := Ui.hbox(14)
	carte.add_child(h)
	var nom := Tournoi.nom_texte(_nom)
	h.add_child(Ui.ecusson(FanClub.sigle(nom), Tournoi.couleur(_couleurs[0]), Tournoi.couleur(_couleurs[1]), 84))
	var v := Ui.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var l := Ui.label(nom, 32, Ui.JAUNE, true, 6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	v.add_child(Ui.label(tr("Fan club : %s · niv. %d") % [Game.fan_club_nom, Game.niveau()], 18, Ui.GRIS))
	if bool(t["inscrit"]):
		var p := Ui.pastille("Inscrit ce week-end", Ui.VERT, 16, true)
		p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		v.add_child(p)
	return carte


func _inscription() -> void:
	_texte(_gauche, "Ton nom de tournoi", 26, Ui.BLANC, true)
	_texte(_gauche, "Choisi dans les listes du jeu : tous les joueurs le verront au classement.", 17, Ui.GRIS)
	var hn := Ui.hbox(10)
	_gauche.add_child(hn)
	var ob_t := _choix(Tournoi.TYPES, int(_nom[0]))
	var ob_c := _choix(Tournoi.COMPLEMENTS, int(_nom[1]))
	hn.add_child(ob_t)
	hn.add_child(ob_c)
	ob_t.item_selected.connect(func(i: int):
		_nom[0] = i
		_remplir())
	ob_c.item_selected.connect(func(i: int):
		_nom[1] = i
		_remplir())
	_texte(_gauche, "Couleurs (celles de ton fan club au départ)", 20, Ui.BLANC, true)
	for k in 2:
		var hc := Ui.hbox(6)
		_gauche.add_child(hc)
		for i in FanClub.COULEURS.size():
			var b := Button.new()
			b.custom_minimum_size = Vector2(44, 44)
			var choisi := int(_couleurs[k]) == i
			b.add_theme_stylebox_override("normal", Ui.boite(Color(FanClub.COULEURS[i]), 12, 5 if choisi else 3, 0, Ui.JAUNE if choisi else Ui.CONTOUR))
			b.add_theme_stylebox_override("hover", Ui.boite(Color(FanClub.COULEURS[i]).lightened(0.2), 12, 3))
			b.add_theme_stylebox_override("pressed", Ui.boite(Ui.JAUNE, 12, 3))
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.tooltip_text = tr("Couleur %d") % (k + 1)
			var kk := k
			var ii := i
			b.pressed.connect(func():
				_couleurs[kk] = ii
				_remplir())
			hc.add_child(b)
	var go := Ui.bouton("S'INSCRIRE AU TOURNOI", Ui.JAUNE, 30)
	Ui.colorer_bouton(go, Ui.JAUNE, true)
	go.custom_minimum_size = Vector2(0, 84)
	go.pressed.connect(func():
		if Game.inscrire_tournoi(_nom, _couleurs):
			EnLigne.synchroniser_tournoi()
			_remplir())
	_gauche.add_child(go)
	_texte(_gauche, "Gratuit. Ensuite, chaque duel sur un match du week-end compte contre un autre fan club.", 17, Ui.GRIS)


func _stats(t: Dictionary) -> void:
	var pts := Tournoi.points(t)
	var nb := (t["duels"] as Array).size()
	var hs := Ui.hbox(12)
	_gauche.add_child(hs)
	var rang := int(t["rang"])
	var clubs := int(t["clubs"])
	if rang <= 0 and not EnLigne.joignable:
		for l in Tournoi.classement_simule(t, Game.maintenant()):
			if l["moi"]:
				rang = int(l["rang"])
	hs.add_child(_case("Points", str(pts), tr("%d duel%s sur %d") % [nb, "" if nb == 1 else "s", Tournoi.DUELS_MAX]))
	hs.add_child(_case("Classement", Classement._ordinal(rang) if rang > 0 else "—",
		tr("sur %d clubs") % clubs if clubs > 0 else (tr("entraînement") if not EnLigne.joignable else "")))
	hs.add_child(_case("Tribune solide", "+%d" % clampi(int(t["defense"]), 0, Tournoi.DEFENSE_MAX), tr("max %d") % Tournoi.DEFENSE_MAX))
	var suivant := Tournoi.prochain_palier(pts)
	var p := Tournoi.palier(pts)
	var txt := tr("Palier atteint : %s (%d Jetons, %d XP PASS).") % [p["titre"], p["jetons"], p["xp_pass"]] if not p.is_empty() else tr("Pas encore de palier.")
	if not suivant.is_empty():
		txt += tr(" Prochain : %s à %d points.") % [suivant["titre"], suivant["points"]]
	_texte(_gauche, txt, 18, Ui.BLANC)
	var barre := ProgressBar.new()
	barre.custom_minimum_size = Vector2(0, 18)
	barre.show_percentage = false
	barre.max_value = float(Tournoi.PALIERS[0]["points"])
	barre.value = float(pts)
	barre.add_theme_stylebox_override("background", Ui.boite(Color("#1a1640"), 8, 3))
	barre.add_theme_stylebox_override("fill", Ui.boite(Ui.JAUNE, 8, 0))
	_gauche.add_child(barre)


func _adversaire(t: Dictionary) -> void:
	if (t["duels"] as Array).size() >= Tournoi.DUELS_MAX:
		_texte(_gauche, tr("Tes %d duels sont joués ! Reviens lundi chercher ta récompense.") % Tournoi.DUELS_MAX, 22, Ui.VERT, true)
		return
	var a := Tournoi.adversaire(t)
	_texte(_gauche, "Prochain adversaire", 26, Ui.BLANC, true)
	var carte := Ui.panneau(Ui.NUIT, 20, 4)
	_gauche.add_child(carte)
	var h := Ui.hbox(12)
	carte.add_child(h)
	var nom := Tournoi.nom_texte(a["nom"])
	h.add_child(Ui.ecusson(FanClub.sigle(nom), Tournoi.couleur(a["couleurs"][0]), Tournoi.couleur(a["couleurs"][1]), 60))
	var v := Ui.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Ui.label(nom, 26, Ui.JAUNE, true, 5))
	v.add_child(Ui.label(("Club du jeu" if bool(a.get("bot", false)) else "Fan club d'un joueur") + tr(" · niv. %d") % int(a.get("niveau", 1)), 17, Ui.GRIS))
	var b := Ui.bouton("Choisir un match", Ui.VERT, 22)
	Ui.colorer_bouton(b, Ui.VERT, true)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func():
		_onglet = "matchs"
		_remplir())
	h.add_child(b)
	_texte(_gauche, "Joue un duel (ambiance, Arène ou Poussée) sur un match du week-end pas encore joué pour le tournoi.", 17, Ui.GRIS)


func _carte_recompense(r: Dictionary) -> Control:
	var g := Tournoi.recompense(r)
	var rien: bool = g["jetons"] == 0 and g["xp_pass"] == 0
	var carte := Ui.panneau(Ui.JAUNE.darkened(0.45), 22, 5)
	var v := Ui.vbox(8)
	carte.add_child(v)
	v.add_child(Ui.label(tr("Tournoi terminé (%s) !") % _date_id(str(r["id"])), 28, Ui.JAUNE, true, 6))
	var rang := int(r.get("rang", 0))
	var details := tr("%d points · %d duels") % [int(r["points"]), int(r.get("duels", 0))]
	if rang > 0:
		details += tr(" · %s sur %d clubs") % [Classement._ordinal(rang), int(r.get("clubs", 0))]
	v.add_child(Ui.label(details, 20, Ui.BLANC))
	var quoi: Array = []
	if g["palier"] != "":
		quoi.append(g["palier"])
	if g["bonus"] != "":
		quoi.append(g["bonus"])
	if not quoi.is_empty():
		v.add_child(Ui.label(" + ".join(quoi), 20, Ui.BLANC, true))
	if rien:
		v.add_child(Ui.label(tr("Il fallait %d points pour le premier palier. Au week-end prochain !") % int(Tournoi.PALIERS[-1]["points"]), 17, Ui.GRIS))
	var b := Ui.bouton("OK" if rien else tr("Récupérer : %d Jetons · %d XP PASS") % [g["jetons"], g["xp_pass"]], Ui.VERT, 24)
	Ui.colorer_bouton(b, Ui.VERT, true)
	# En ligne, on attend le rang final (bonus de classement) avant de verser.
	if not bool(r.get("verifie", false)) and EnLigne.joignable and not rien:
		b.disabled = true
		b.text = "Calcul du classement final…"
	b.pressed.connect(func():
		Game.reclamer_tournoi()
		_remplir())
	v.add_child(b)
	return carte


func _historique(t: Dictionary) -> void:
	var h: Array = t["historique"]
	if h.is_empty():
		return
	_texte(_gauche, "Tes derniers tournois", 24, Ui.BLANC, true)
	for r in h:
		var rang := int(r.get("rang", 0))
		_texte(_gauche, tr("• %s : %d points%s · +%d Jetons") % [_date_id(str(r["id"])), int(r["points"]),
			" · %s" % Classement._ordinal(rang) if rang > 0 else "", int(r.get("jetons", 0))], 18, Ui.GRIS)


# ------------------------------------------------------------------ à droite

func _remplir_droite(f: Dictionary) -> void:
	for c in _droite.get_children():
		c.queue_free()
	var h := Ui.hbox(10)
	_droite.add_child(h)
	for o in ONGLETS:
		var b := Ui.bouton(o[1], Ui.JAUNE if _onglet == o[0] else Ui.NUIT_CLAIR, 19)
		if _onglet == o[0]:
			Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.pressed.connect(func():
			_onglet = o[0]
			_remplir())
		h.add_child(b)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_droite.add_child(sc)
	var liste := Ui.vbox(6)
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(liste)
	match _onglet:
		"matchs":
			_liste_matchs(liste, f)
		"duels":
			_liste_duels(liste)
		"regles":
			_regles(liste, f)
		_:
			_classement(liste, f)


func _classement(liste: VBoxContainer, f: Dictionary) -> void:
	var t: Dictionary = Game.tournoi
	var d: Dictionary = EnLigne.tournoi_classement
	if not d.is_empty() and str(d.get("tournoi", "")) == str(f["id"]):
		var top: Array = d["clubs"]
		if top.is_empty():
			_texte(liste, "Aucun club n'a encore marqué ce week-end : à toi d'ouvrir le score !", 20, Ui.GRIS)
			return
		_texte(liste, tr("%d fan clubs inscrits") % int(d.get("inscrits", top.size())), 18, Ui.GRIS)
		var moi_dedans := false
		for c in top:
			var c_moi: bool = str(c.get("id", "")) == str(EnLigne.identite["id"])
			moi_dedans = moi_dedans or c_moi
			liste.add_child(_ligne_club(int(c["rang"]), c.get("nom"), c.get("couleurs", [0, 7]), int(c["points"]), int(c.get("duels", 0)), c_moi))
		if not moi_dedans and int(t["rang"]) > 0 and f["etat"] == "actif":
			liste.add_child(Ui.label("…", 22, Ui.GRIS, true))
			liste.add_child(_ligne_club(int(t["rang"]), t["nom"], t["couleurs"], Tournoi.points(t), (t["duels"] as Array).size(), true))
		return
	if f["etat"] != "actif":
		_texte(liste, "Le classement du prochain tournoi s'affichera dès vendredi.", 20, Ui.GRIS)
		return
	_texte(liste, "Classement en ligne désactivé (mode test) : clubs du jeu." if EnLigne.desactive
		else "Hors ligne : classement d'entraînement contre les clubs du jeu. Le vrai classement revient avec la connexion.", 17, Ui.GRIS)
	for l in Tournoi.classement_simule(t, Game.maintenant()):
		liste.add_child(_ligne_club(int(l["rang"]), l["nom"], l["couleurs"], int(l["points"]), -1, l["moi"]))


func _ligne_club(rang: int, nom_v: Variant, couleurs: Variant, points: int, duels: int, c_moi: bool) -> Control:
	var cadre := Ui.panneau(Ui.JAUNE.darkened(0.5) if c_moi else Ui.NUIT_CLAIR, 14, 3)
	var h := Ui.hbox(10)
	cadre.add_child(h)
	var r := Ui.label("%d" % rang, 24, Ui.JAUNE if rang <= 3 else Ui.BLANC, true, 5)
	r.custom_minimum_size = Vector2(64, 0)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(r)
	var nom := Tournoi.nom_texte(nom_v)
	var c: Array = couleurs if couleurs is Array and couleurs.size() == 2 else [0, 7]
	h.add_child(Ui.ecusson(FanClub.sigle(nom), Tournoi.couleur(c[0]), Tournoi.couleur(c[1]), 36))
	var n := Ui.label(("★ " if c_moi else "") + nom, 22, Ui.BLANC, true)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(n)
	if duels >= 0:
		h.add_child(Ui.pastille(tr("%d duel%s") % [duels, "" if duels == 1 else "s"], Ui.BLEU, 14))
	var p := Ui.label(tr("%d pts") % points, 22, Ui.JAUNE, true)
	p.custom_minimum_size = Vector2(110, 0)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(p)
	return cadre


## Matchs du calendrier qui comptent pour le tournoi (week-end, pas annulés).
func _liste_matchs(liste: VBoxContainer, f: Dictionary) -> void:
	if f["etat"] != "actif":
		_texte(liste, "Les matchs du prochain week-end apparaîtront ici vendredi.", 20, Ui.GRIS)
		return
	var t: Dictionary = Game.tournoi
	var now := Game.maintenant()
	var matchs: Array = []
	for m in Donnees.matchs():
		var k := Donnees.heure_unix(m)
		if not Tournoi.match_du_week_end(k, f) or not FicheMatch.jouable(FicheMatch.de(m)):
			continue
		if str(m.get("status", "")) == "FINISHED" and k < now - 6 * 3600:
			continue  # fini depuis longtemps : on garde la liste courte
		matchs.append(m)
	matchs.sort_custom(func(a, b):
		var ea := Donnees.en_direct(a)
		var eb := Donnees.en_direct(b)
		if ea != eb:
			return ea
		return Donnees.heure_unix(a) < Donnees.heure_unix(b))
	if matchs.is_empty():
		_texte(liste, "Aucun match du week-end dans le calendrier pour l'instant.", 20, Ui.GRIS)
		return
	_texte(liste, tr("Chaque match ne compte qu'une fois. Au stade : +%d point. Derby, finale, Grand Choc : +%d point.") % [Tournoi.BONUS_STADE, Tournoi.BONUS_EVENEMENT], 17, Ui.GRIS)
	for m in matchs.slice(0, 60):
		liste.add_child(_ligne_match(m, t))


func _ligne_match(m: Dictionary, t: Dictionary) -> Control:
	var fi := FicheMatch.de(m)
	var joue := Tournoi.match_deja_joue(t, str(m["id"]))
	var cadre := Ui.panneau(Ui.NUIT_CLAIR, 14, 3)
	var h := Ui.hbox(10)
	cadre.add_child(h)
	var st := Ui.label(FicheMatch.statut_court(fi), 18, Ui.ROSE if Donnees.en_direct(m) else Ui.GRIS, true)
	st.custom_minimum_size = Vector2(150, 0)
	h.add_child(st)
	var v := Ui.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nm := Ui.label("%s – %s" % [fi["dom"]["nom"], fi["ext"]["nom"]], 21, Ui.BLANC, true)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	v.add_child(Ui.label("%s · %s" % [str(fi["competition"]), FicheMatch.date_texte(int(fi["t"]))], 15, Ui.GRIS))
	var ev := Game.evenement_de(m)
	if not ev.is_empty():
		h.add_child(Ui.pastille(str(ev.get("court", ev.get("titre", ""))), Color(ev.get("couleur", "#ff3d7f")), 14, bool(ev.get("sombre", false))))
	if joue:
		h.add_child(Ui.pastille("Joué", Ui.VERT, 16, true))
	else:
		var b := Ui.bouton("Jouer", Ui.VERT, 20)
		Ui.colorer_bouton(b, Ui.VERT, true)
		b.disabled = not bool(t["inscrit"]) or (t["duels"] as Array).size() >= Tournoi.DUELS_MAX
		b.tooltip_text = "Ouvre le match sur la carte : choisis où le suivre, puis lance ton duel"
		b.pressed.connect(func(): Game.aller(Game.SCENE_CARTE, {"match_id": str(m["id"]), "niveau": "monde"}))
		h.add_child(b)
	return cadre


func _liste_duels(liste: VBoxContainer) -> void:
	var t: Dictionary = Game.tournoi
	var d: Array = t["duels"]
	if d.is_empty():
		_texte(liste, "Pas encore de duel de tournoi ce week-end.", 20, Ui.GRIS)
		return
	for x in d:
		var m := Donnees.match_par_id(str(x["match"]))
		var cadre := Ui.panneau(Ui.NUIT_CLAIR, 14, 3)
		var h := Ui.hbox(10)
		cadre.add_child(h)
		h.add_child(Ui.pastille("Victoire" if x["gagne"] else "Défaite", Ui.VERT if x["gagne"] else Ui.ROSE, 16, true))
		var v := Ui.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(Ui.label(tr("contre %s") % Tournoi.nom_texte(x["nom_adv"]), 21, Ui.BLANC, true))
		var sous := ""
		if not m.is_empty():
			var fi := FicheMatch.de(m)
			sous = "%s – %s" % [fi["dom"]["nom"], fi["ext"]["nom"]]
		var bonus: Array = []
		if x.get("stade", false):
			bonus.append("au stade")
		if x.get("evenement", false):
			bonus.append("match spécial")
		if not bonus.is_empty():
			sous += (" · " if sous != "" else "") + ", ".join(bonus)
		v.add_child(Ui.label(sous, 15, Ui.GRIS))
		if not bool(x.get("envoye", false)) and not EnLigne.desactive:
			h.add_child(Ui.pastille("en attente d'envoi", Ui.NUIT, 13))
		h.add_child(Ui.label("+%d" % int(x["pts"]), 24, Ui.JAUNE, true))
		liste.add_child(cadre)


func _regles(liste: VBoxContainer, f: Dictionary) -> void:
	for ligne in [
		tr("Le tournoi dure du vendredi %s au lundi %s (heure locale). Inscription gratuite, avec ton fan club.") % [
			FicheMatch.heure_texte(int(f["debut"])), FicheMatch.heure_texte(int(f["fin"]))],
		"Chaque duel (ambiance, Arène ou Poussée, contre l'ordinateur) joué sur un match du week-end compte contre un autre fan club, tiré au sort parmi les clubs inscrits.",
		tr("Victoire : %d points. Défaite : %d point. Au stade : +%d. Derby, finale ou Grand Choc : +%d.") % [Tournoi.POINTS_VICTOIRE, Tournoi.POINTS_DEFAITE, Tournoi.BONUS_STADE, Tournoi.BONUS_EVENEMENT],
		tr("%d duels au plus, chacun sur un match différent et contre un club différent. Rejouer un match ne rapporte pas de point de tournoi, et ses Jetons baissent comme d'habitude (100 %%, 50 %%, 25 %%, puis rien).") % Tournoi.DUELS_MAX,
		tr("Quand un club perd contre le tien, ta tribune a tenu bon : +1 point (%d au plus).") % Tournoi.DEFENSE_MAX,
		tr("Lundi, récupère ta récompense : %s.") % ", ".join(Tournoi.PALIERS.map(func(p): return tr("%d pts = %d Jetons") % [p["points"], p["jetons"]])),
		tr("Bonus de classement s'il y a au moins %d clubs : 1er +150, 2e +100, 3e +75, top 10 +40, top 25 %% +20 Jetons.") % Tournoi.CLUBS_MIN_BONUS,
		"Les duels en ligne contre un vrai joueur ne comptent pas : ils ont leur propre salon.",
	]:
		_texte(liste, "• " + ligne, 19, Ui.BLANC)


# ------------------------------------------------------------------ outils

func _texte(parent: Control, texte: String, taille := 20, couleur := Ui.BLANC, titre := false) -> Label:
	var l := Ui.label(texte, taille, couleur, titre)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(l)
	return l


func _case(titre: String, valeur: String, sous: String) -> Control:
	var c := Ui.panneau(Ui.NUIT, 16, 3)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := Ui.vbox(0)
	c.add_child(v)
	v.add_child(Ui.label(titre, 16, Ui.GRIS))
	v.add_child(Ui.label(valeur, 34, Ui.BLANC, true, 5))
	v.add_child(Ui.label(sous, 15, Ui.JAUNE, true))
	return c


func _choix(mots: Array, choisi: int) -> OptionButton:
	var ob := OptionButton.new()
	ob.add_theme_font_size_override("font_size", 20)
	ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for m in mots:
		ob.add_item(m)
	ob.select(clampi(choisi, 0, mots.size() - 1))
	return ob


## « 2026-11-13 » (vendredi du tournoi) -> « week-end du 13 nov. ».
static func _date_id(id: String) -> String:
	var t := int(Time.get_unix_time_from_datetime_string(id + "T12:00:00"))
	var d := Time.get_datetime_dict_from_unix_time(t)
	return Langue.t("week-end du %d %s") % [d["day"], FicheMatch.MOIS[d["month"] - 1]]
