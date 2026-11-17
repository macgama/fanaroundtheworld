extends Control
## « Ligue des tribunes » : la saison du mois (règles dans scripts/jeu/ligue.gd).
## À gauche : ton club (division, rang, points), le match choisi pour jouer, les
## boutons « en ligne » et « contre un club du jeu », la récompense de fin de saison.
## À droite : ta poule, les matchs du week-end, le calendrier, tes duels, les règles.
## Tests : « -- --onglet=matchs|calendrier|duels|regles ».

const Classement := preload("res://scenes/classement/classement.gd")
const ONGLETS := [["poule", "Ma poule"], ["matchs", "Matchs du week-end"], ["calendrier", "Calendrier"], ["duels", "Mes duels"], ["regles", "Règles"]]

var _onglet := "poule"
var _gauche: VBoxContainer
var _droite: VBoxContainer
var _sous_titre: Label
var _match_id := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--onglet="):  # sans_traduction
			_onglet = arg.trim_prefix("--onglet=")  # sans_traduction
	Game.actualiser_ligue()
	var fond := ColorRect.new()
	fond.color = Color("#0f7a5c")
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
	haut.add_child(Ui.label("LIGUE DES TRIBUNES", 56, Ui.JAUNE, true, 10))
	_sous_titre = Ui.label("", 22, Ui.BLANC)
	_sous_titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sous_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sous_titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	haut.add_child(_sous_titre)

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)
	var pg := Ui.panneau()
	pg.custom_minimum_size = Vector2(660, 0)
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
	var tour := Ui.bouton("Tournoi du week-end", Ui.ROSE, 28)
	tour.custom_minimum_size = Vector2(340, 84)
	tour.pressed.connect(func(): Game.aller(Game.SCENE_TOURNOI))
	bas.add_child(tour)

	EnLigne.mis_a_jour.connect(_remplir)
	EnLigne.rafraichir_ligue()
	_remplir()


func _remplir() -> void:
	if not is_inside_tree():
		return
	var c := Game.actualiser_ligue()
	var l: Dictionary = Game.ligue
	var js: Array = c["journees"]
	match c["etat"]:
		"journee":
			_sous_titre.text = tr("Saison de %s · journée %d sur %d, jusqu'à %s %s. Joue sur les vrais matchs du week-end !") % [
				Ligue.saison_texte(str(c["saison"])), int(c["journee"]["n"]), js.size(),
				FicheMatch.date_texte(int(c["journee"]["fin"])), FicheMatch.heure_texte(int(c["journee"]["fin"]))]
		"pause":
			_sous_titre.text = tr("Saison de %s · prochaine journée %s à %s.") % [
				Ligue.saison_texte(str(c["saison"])), FicheMatch.date_texte(int(c["prochaine"])), FicheMatch.heure_texte(int(c["prochaine"]))]
		_:
			_sous_titre.text = tr("La saison de %s est finie. La suivante commence %s à %s.") % [
				Ligue.saison_texte(str(c["saison"])), FicheMatch.date_texte(int(c["prochaine"])), FicheMatch.heure_texte(int(c["prochaine"]))]
	if _match_id == "" or Donnees.match_par_id(_match_id).is_empty():
		_match_id = _meilleur_match(c)
	_remplir_gauche(c, l)
	_remplir_droite(c, l)


## Match du week-end proposé : en direct d'abord, sinon le prochain.
func _meilleur_match(c: Dictionary) -> String:
	var liste := _matchs_du_week_end(c)
	return str(liste[0]["id"]) if not liste.is_empty() else ""


func _matchs_du_week_end(c: Dictionary) -> Array:
	if c["etat"] != "journee":
		return []
	var now := Game.maintenant()
	var matchs: Array = []
	for m in Donnees.matchs():
		var k := Donnees.heure_unix(m)
		if not Ligue.match_de_la_journee(k, c) or not FicheMatch.jouable(FicheMatch.de(m)):
			continue
		if str(m.get("status", "")) == "FINISHED" and k < now - 6 * 3600:
			continue
		matchs.append(m)
	matchs.sort_custom(func(a, b):
		var ea := Donnees.en_direct(a)
		var eb := Donnees.en_direct(b)
		if ea != eb:
			return ea
		var fa: bool = str(a.get("status", "")) == "FINISHED"
		var fb: bool = str(b.get("status", "")) == "FINISHED"
		if fa != fb:
			return fb
		return Donnees.heure_unix(a) < Donnees.heure_unix(b))
	return matchs


# ------------------------------------------------------------------ ton club

func _remplir_gauche(c: Dictionary, l: Dictionary) -> void:
	for x in _gauche.get_children():
		x.queue_free()
	if not (l["a_reclamer"] as Dictionary).is_empty():
		_gauche.add_child(_carte_recompense(l["a_reclamer"]))
	if not Game.club_cree():
		_texte(_gauche, "Crée d'abord ton fan club : c'est lui qui joue la Ligue.", 22, Ui.BLANC)
		var b := Ui.bouton("Créer mon fan club", Ui.JAUNE, 26)
		Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.pressed.connect(func(): Game.aller(Game.SCENE_CREATION_CLUB))
		_gauche.add_child(b)
		return
	_gauche.add_child(_carte_club(l))
	if not bool(l["inscrit"]):
		_texte(_gauche, tr("Ton club commence en %s. Chaque mois, les 2 premiers de la poule montent, les 2 derniers descendent.") % Ligue.nom_division(int(l["division"])), 19, Ui.BLANC)
		var go := Ui.bouton("ENTRER DANS LA LIGUE", Ui.JAUNE, 30)
		Ui.colorer_bouton(go, Ui.JAUNE, true)
		go.custom_minimum_size = Vector2(0, 84)
		go.pressed.connect(func():
			if Game.inscrire_ligue():
				EnLigne.rafraichir_ligue()
				_remplir())
		_gauche.add_child(go)
		_texte(_gauche, "Gratuit. Ton nom de ligue est ton nom de tournoi (ou un nom tiré pour ton fan club).", 17, Ui.GRIS)
		_historique(l)
		return
	_stats(c, l)
	if c["etat"] == "journee":
		_jouer(c, l)
	else:
		_texte(_gauche, tr("Les duels de Ligue se jouent le week-end, du vendredi %s au lundi %s (heure locale), sur les vrais matchs.") % [
			FicheMatch.heure_texte(int(c["prochaine"])), FicheMatch.heure_texte(int(c["prochaine"]) + Ligue.DUREE_S)], 19, Ui.GRIS)
	_historique(l)


func _carte_club(l: Dictionary) -> Control:
	var carte := Ui.panneau(Ui.NUIT_CLAIR, 22, 4)
	var h := Ui.hbox(14)
	carte.add_child(h)
	var nom := Tournoi.nom_texte(l["nom"])
	h.add_child(Ui.ecusson(FanClub.sigle(nom), Tournoi.couleur(l["couleurs"][0]), Tournoi.couleur(l["couleurs"][1]), 84))
	var v := Ui.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var n := Ui.label(nom, 30, Ui.JAUNE, true, 6)
	n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(n)
	v.add_child(Ui.label(tr("Fan club : %s · niv. %d") % [Game.fan_club_nom, Game.niveau()], 18, Ui.GRIS))
	var div := int(l["division"])
	var p := Ui.pastille(tr("Division %d · %s") % [div, Ligue.nom_division(div)], Ligue.couleur_division(div), 17, true)
	p.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(p)
	return carte


func _ma_ligne(l: Dictionary) -> Dictionary:
	for x in _poule(l):
		if bool(x.get("moi", false)):
			return x
	return {}


func _stats(c: Dictionary, l: Dictionary) -> void:
	var hs := Ui.hbox(12)
	_gauche.add_child(hs)
	var moi := _ma_ligne(l)
	var rang := int(moi.get("rang", 0))
	var mvt := Ligue.mouvement(int(l["division"]), rang) if rang > 0 else 0
	hs.add_child(_case("Points", str(Ligue.points(l)), tr("%d duels comptés") % Ligue.duels_comptes(l)))
	hs.add_child(_case("Rang", Classement._ordinal(rang) if rang > 0 else "—",
		tr("zone de montée") if mvt > 0 else (tr("zone de descente") if mvt < 0 else tr("sur %d") % Ligue.TAILLE_POULE)))
	var js: Array = c["journees"]
	var n := int(c["journee"]["n"])
	hs.add_child(_case("Journée", "%d/%d" % [n, js.size()], tr("en cours") if c["etat"] == "journee" else tr("pause")))


func _jouer(c: Dictionary, l: Dictionary) -> void:
	var cpt := Ligue.compteurs(l, str(c["journee"]["id"]))
	_texte(_gauche, tr("Cette journée : %d duel%s sur %d") % [int(cpt["n"]), "" if int(cpt["n"]) == 1 else "s", Ligue.DUELS_JOURNEE], 24, Ui.BLANC, true)
	var m := Donnees.match_par_id(_match_id)
	if m.is_empty():
		_texte(_gauche, "Aucun match du week-end dans le calendrier pour l'instant.", 19, Ui.GRIS)
		return
	var fi := FicheMatch.de(m)
	var carte := Ui.panneau(Ui.NUIT, 18, 4)
	_gauche.add_child(carte)
	var h := Ui.hbox(10)
	carte.add_child(h)
	var v := Ui.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(Ui.label("Match choisi", 15, Ui.GRIS))
	var nm := Ui.label("%s – %s" % [fi["dom"]["nom"], fi["ext"]["nom"]], 22, Ui.BLANC, true)
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nm)
	v.add_child(Ui.label(FicheMatch.statut_court(fi) + (tr(" · +1 point : en direct !") if Donnees.en_direct(m) else ""), 16, Ui.ROSE if Donnees.en_direct(m) else Ui.GRIS))
	var ch := Ui.bouton("Changer", Ui.NUIT_CLAIR, 18)
	ch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ch.pressed.connect(func():
		_onglet = "matchs"
		_remplir())
	h.add_child(ch)

	var plein := int(cpt["n"]) >= Ligue.DUELS_JOURNEE
	var en_ligne := Ui.bouton("JOUER EN LIGNE\ncontre un autre fan club", Ui.JAUNE, 26)
	Ui.colorer_bouton(en_ligne, Ui.JAUNE, true)
	en_ligne.custom_minimum_size = Vector2(0, 92)
	en_ligne.disabled = plein
	en_ligne.tooltip_text = "Ouvre le salon en ligne sur ce match : le duel compte quand vous avez tous les deux envoyé le résultat"
	en_ligne.pressed.connect(func(): Game.aller(Game.SCENE_SALON, {"match_id": _match_id, "camp": _camp(m), "mode": "maison"}))
	_gauche.add_child(en_ligne)

	var reste := Ligue.BOTS_JOURNEE - int(cpt["bots"])
	_texte(_gauche, tr("Personne en ligne ? Défie un club du jeu de ta poule (encore %d cette journée).") % maxi(0, reste), 18, Ui.GRIS)
	var bots := Ligue.bots_de_la_poule(l, EnLigne.ligue_poule, Game.maintenant())
	var vus := 0
	for b in bots:
		if vus >= 4:
			break
		var id := str(b["id"])
		var raison := Ligue.raison_refus(l, id, Donnees.heure_unix(m), Game.maintenant())
		if raison != "" and int(cpt["par_adv"].get(id, 0)) >= Ligue.MEME_ADV_JOURNEE:
			continue  # déjà affronté deux fois : on en montre un autre
		vus += 1
		var ligne := Ui.panneau(Ui.NUIT_CLAIR, 14, 3)
		var hb := Ui.hbox(10)
		ligne.add_child(hb)
		var nom := Tournoi.nom_texte(b["nom"])
		hb.add_child(Ui.ecusson(FanClub.sigle(nom), Tournoi.couleur(b["couleurs"][0]), Tournoi.couleur(b["couleurs"][1]), 40))
		var lb := Ui.label(nom, 20, Ui.BLANC, true)
		lb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lb.clip_text = true
		lb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		hb.add_child(lb)
		hb.add_child(Ui.label(tr("%d pts") % int(b.get("points", 0)), 18, Ui.JAUNE, true))
		var go := Ui.bouton("Défier", Ui.VERT, 18)
		Ui.colorer_bouton(go, Ui.VERT, true)
		go.disabled = raison != ""
		go.tooltip_text = raison if raison != "" else "Choisis ton jeu (ambiance, Arène ou Poussée) dans ta tribune"
		var k := int(id.trim_prefix("bot:"))
		go.pressed.connect(func(): Game.aller(Game.SCENE_TRIBUNE, {"match_id": _match_id, "camp": _camp(m), "mode": "maison", "cout": 0, "ligue_bot": k}))
		hb.add_child(go)
		_gauche.add_child(ligne)


## Ton camp : celui de ton équipe favorite si elle joue, sinon l'équipe à domicile.
func _camp(m: Dictionary) -> String:
	var camps := Game.camps_favoris(m)
	return str(camps[0]) if not camps.is_empty() else "home"


func _carte_recompense(r: Dictionary) -> Control:
	var g := Ligue.recompense(r)
	var rien: bool = int(g["jetons"]) == 0
	var carte := Ui.panneau(Ui.JAUNE.darkened(0.45), 22, 5)
	var v := Ui.vbox(8)
	carte.add_child(v)
	v.add_child(Ui.label(tr("Saison de %s terminée !") % Ligue.saison_texte(str(r["saison"])), 28, Ui.JAUNE, true, 6))
	var div := int(r["division"])
	var details := tr("%s · %s de la poule · %d points") % [Ligue.nom_division(div), Classement._ordinal(int(r["rang"])), int(r["points"])]
	v.add_child(Ui.label(details, 20, Ui.BLANC))
	var mvt := int(r.get("mouvement", 0))
	if mvt > 0:
		v.add_child(Ui.label(tr("Montée ! Le mois prochain : %s") % Ligue.nom_division(div - 1), 21, Ui.VERT, true))
	elif mvt < 0:
		v.add_child(Ui.label(tr("Descente en %s. On remonte le mois prochain !") % Ligue.nom_division(div + 1), 20, Ui.ROSE, true))
	if rien:
		v.add_child(Ui.label(tr("Il fallait %d duels comptés pour la récompense.") % Ligue.DUELS_MIN_RECOMPENSE, 17, Ui.GRIS))
	else:
		v.add_child(Ui.label(" + ".join(g["titres"]), 18, Ui.BLANC, true))
	var b := Ui.bouton("OK" if rien else tr("Récupérer : %d Jetons · %d XP PASS") % [g["jetons"], g["xp_pass"]], Ui.VERT, 24)
	Ui.colorer_bouton(b, Ui.VERT, true)
	if not bool(r.get("verifie", false)) and EnLigne.joignable and not rien:
		b.disabled = true
		b.text = "Calcul du classement final…"
	b.pressed.connect(func():
		Game.reclamer_ligue()
		_remplir())
	v.add_child(b)
	return carte


func _historique(l: Dictionary) -> void:
	var h: Array = l["historique"]
	if h.is_empty():
		return
	_texte(_gauche, "Tes dernières saisons", 24, Ui.BLANC, true)
	for r in h:
		var mvt := int(r.get("mouvement", 0))
		_texte(_gauche, tr("• %s : %s, %s%s · +%d Jetons") % [Ligue.saison_texte(str(r["saison"])), Ligue.nom_division(int(r["division"])),
			Classement._ordinal(int(r["rang"])), tr(" · montée") if mvt > 0 else (tr(" · descente") if mvt < 0 else ""), int(r.get("jetons", 0))], 18, Ui.GRIS)


# ------------------------------------------------------------------ à droite

func _remplir_droite(c: Dictionary, l: Dictionary) -> void:
	for x in _droite.get_children():
		x.queue_free()
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
			_liste_matchs(liste, c)
		"calendrier":
			_calendrier(liste, c)
		"duels":
			_liste_duels(liste, l)
		"regles":
			_regles(liste)
		_:
			_table(liste, l)


## Poule à afficher : celle du serveur (avec les autres joueurs), sinon la poule locale.
func _poule(l: Dictionary) -> Array:
	var d: Dictionary = EnLigne.ligue_poule
	if bool(l["inscrit"]) and str(d.get("saison", "")) == str(l["saison"]) and d.get("clubs") is Array:
		var lignes: Array = []
		for x in d["clubs"]:
			var y: Dictionary = x.duplicate()
			y["moi"] = str(x.get("id", "")) == str(EnLigne.identite["id"])
			if y["moi"]:
				y["points"] = maxi(int(y["points"]), Ligue.points(l))  # duels joués depuis la dernière réponse
			lignes.append(y)
		return Ligue.trier(lignes) if lignes.size() > 0 else lignes
	return Ligue.poule_locale(l, Game.maintenant())


func _table(liste: VBoxContainer, l: Dictionary) -> void:
	var div := int(l["division"])
	_texte(liste, tr("%s · poule %d · les %d premiers montent, les %d derniers descendent") % [Ligue.nom_division(div), int(l["poule"]) + 1, Ligue.MONTEES, Ligue.DESCENTES], 18, Ui.GRIS)
	if not bool(l["inscrit"]):
		_texte(liste, "Entre dans la Ligue pour rejoindre une poule.", 20, Ui.BLANC)
	elif EnLigne.ligue_poule.is_empty():
		_texte(liste, "Classement en ligne désactivé (mode test) : poule d'entraînement." if EnLigne.desactive
			else "Hors ligne : poule d'entraînement contre les clubs du jeu. La vraie poule revient avec la connexion.", 16, Ui.GRIS)
	for x in _poule(l):
		var rang := int(x["rang"])
		var mvt := Ligue.mouvement(div, rang)
		liste.add_child(_ligne_club(rang, x.get("nom"), x.get("couleurs", [0, 7]), int(x["points"]), bool(x.get("bot", false)), bool(x.get("moi", false)) and bool(l["inscrit"]), mvt))


func _ligne_club(rang: int, nom_v: Variant, couleurs: Variant, points: int, bot: bool, c_moi: bool, mvt: int) -> Control:
	var cadre := Ui.panneau(Ui.JAUNE.darkened(0.5) if c_moi else Ui.NUIT_CLAIR, 14, 3)
	var h := Ui.hbox(10)
	cadre.add_child(h)
	var zone := ColorRect.new()
	zone.custom_minimum_size = Vector2(8, 0)
	zone.color = Ui.VERT if mvt > 0 else (Ui.ROSE if mvt < 0 else Color(0, 0, 0, 0))
	h.add_child(zone)
	var r := Ui.label("%d" % rang, 24, Ui.JAUNE if rang <= Ligue.MONTEES else Ui.BLANC, true, 5)
	r.custom_minimum_size = Vector2(50, 0)
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
	h.add_child(Ui.pastille("club du jeu" if bot else "joueur", Ui.NUIT if bot else Ui.BLEU, 14))
	var p := Ui.label(tr("%d pts") % points, 22, Ui.JAUNE, true)
	p.custom_minimum_size = Vector2(110, 0)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(p)
	return cadre


func _liste_matchs(liste: VBoxContainer, c: Dictionary) -> void:
	if c["etat"] != "journee":
		_texte(liste, "Les matchs de la prochaine journée apparaîtront ici vendredi.", 20, Ui.GRIS)
		return
	var matchs := _matchs_du_week_end(c)
	if matchs.is_empty():
		_texte(liste, "Aucun match du week-end dans le calendrier pour l'instant.", 20, Ui.GRIS)
		return
	_texte(liste, "Choisis le vrai match de ton duel. En direct, une victoire rapporte un point de plus.", 17, Ui.GRIS)
	for m in matchs.slice(0, 60):
		var fi := FicheMatch.de(m)
		var cadre := Ui.panneau(Ui.JAUNE.darkened(0.5) if str(m["id"]) == _match_id else Ui.NUIT_CLAIR, 14, 3)
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
		if str(m["id"]) == _match_id:
			h.add_child(Ui.pastille("Choisi", Ui.JAUNE, 16, true))
		else:
			var b := Ui.bouton("Choisir", Ui.VERT, 20)
			Ui.colorer_bouton(b, Ui.VERT, true)
			var id := str(m["id"])
			b.pressed.connect(func():
				_match_id = id
				_remplir())
			h.add_child(b)
		liste.add_child(cadre)


func _calendrier(liste: VBoxContainer, c: Dictionary) -> void:
	_texte(liste, tr("Saison de %s : une journée par week-end, du vendredi au lundi midi.") % Ligue.saison_texte(str(c["saison"])), 18, Ui.GRIS)
	var now := Game.maintenant()
	for j in c["journees"]:
		var cadre := Ui.panneau(Ui.NUIT_CLAIR, 14, 3)
		var h := Ui.hbox(10)
		cadre.add_child(h)
		h.add_child(Ui.label(tr("Journée %d") % int(j["n"]), 22, Ui.JAUNE, true))
		var d := Ui.label(tr("%s %s → %s %s") % [FicheMatch.date_texte(int(j["debut"])), FicheMatch.heure_texte(int(j["debut"])),
			FicheMatch.date_texte(int(j["fin"])), FicheMatch.heure_texte(int(j["fin"]))], 18, Ui.BLANC)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(d)
		var n := int(Ligue.compteurs(Game.ligue, str(j["id"]))["n"])
		if now >= int(j["fin"]):
			h.add_child(Ui.pastille(tr("jouée · %d duels") % int(n), Ui.NUIT, 15))
		elif now >= int(j["debut"]):
			h.add_child(Ui.pastille(tr("en cours · %d/%d") % [int(n), Ligue.DUELS_JOURNEE], Ui.VERT, 15, true))
		else:
			h.add_child(Ui.pastille("à venir", Ui.BLEU, 15))
		liste.add_child(cadre)
	_texte(liste, tr("Fin de saison %s à %s : montées, descentes et récompenses.") % [FicheMatch.date_texte(int(c["fin_saison"])), FicheMatch.heure_texte(int(c["fin_saison"]))], 18, Ui.BLANC)


const ETATS := {
	"compte": ["Compté", "#3ddc84"], "local": ["Compté", "#3ddc84"], "attente": ["À confirmer", "#ffd23f"],
	"refuse": ["Pas compté", "#ff3d7f"], "non_confirme": ["Pas confirmé", "#ff3d7f"],
}


func _liste_duels(liste: VBoxContainer, l: Dictionary) -> void:
	var d: Array = l["duels"]
	if d.is_empty():
		_texte(liste, "Pas encore de duel de Ligue ce mois-ci.", 20, Ui.GRIS)
		return
	_texte(liste, "Un duel en ligne compte quand ton adversaire a aussi envoyé son résultat (quelques minutes).", 17, Ui.GRIS)
	for i in range(d.size() - 1, -1, -1):
		var x: Dictionary = d[i]
		var cadre := Ui.panneau(Ui.NUIT_CLAIR, 14, 3)
		var h := Ui.hbox(10)
		cadre.add_child(h)
		var res := "Nul" if bool(x.get("nul", false)) else ("Victoire" if x["gagne"] else "Défaite")
		h.add_child(Ui.pastille(res, Ui.VERT if x["gagne"] else Ui.ROSE, 16, true))
		var v := Ui.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		var qui: String = str(x.get("nom_texte", "")) if str(x.get("nom_texte", "")) != "" else Tournoi.nom_texte(x["nom_adv"])
		v.add_child(Ui.label(tr("contre %s") % qui, 21, Ui.BLANC, true))
		var m := Donnees.match_par_id(str(x["match"]))
		var sous := tr("club du jeu") if bool(x.get("bot", false)) else tr("en ligne")
		if not m.is_empty():
			var fi := FicheMatch.de(m)
			sous += " · %s – %s" % [fi["dom"]["nom"], fi["ext"]["nom"]]
		if bool(x.get("direct", false)):
			sous += tr(" · en direct")
		v.add_child(Ui.label(sous, 15, Ui.GRIS))
		var e: Array = ETATS.get(str(x.get("etat", "")), ["?", "#888888"])
		h.add_child(Ui.pastille(e[0], Color(e[1]), 13, true))
		h.add_child(Ui.label("+%d" % int(x["pts"]), 24, Ui.JAUNE, true))
		liste.add_child(cadre)


func _regles(liste: VBoxContainer) -> void:
	for ligne in [
		"Une saison par mois. Chaque week-end du mois est une journée, du vendredi au lundi midi : on joue sur les vrais matchs du week-end.",
		tr("5 divisions, de la Ligue Espoir à la Ligue Étoile, en poules de %d clubs. Les places libres sont prises par des clubs du jeu.") % Ligue.TAILLE_POULE,
		"Un duel en ligne (ambiance, Arène ou Poussée) contre un autre fan club compte quand les deux joueurs ont envoyé le même résultat. Un duel abandonné ne compte pas.",
		tr("Personne en ligne ? Tu peux défier les clubs du jeu de ta poule, %d fois par journée.") % Ligue.BOTS_JOURNEE,
		tr("Victoire : %d points. Nul : %d. Défaite : %d. Vrai match en direct : +%d.") % [Ligue.POINTS_VICTOIRE, Ligue.POINTS_NUL, Ligue.POINTS_DEFAITE, Ligue.BONUS_DIRECT],
		tr("%d duels par journée au plus, et %d au plus contre le même club.") % [Ligue.DUELS_JOURNEE, Ligue.MEME_ADV_JOURNEE],
		tr("Fin du mois : les %d premiers montent, les %d derniers descendent.") % [Ligue.MONTEES, Ligue.DESCENTES],
		tr("Récompense de saison (au moins %d duels comptés) : de %d Jetons en Ligue Espoir à %d en Ligue Étoile, plus de l'XP de PASS. Champion de poule : +%d Jetons. Montée : +%d Jetons.") % [
			Ligue.DUELS_MIN_RECOMPENSE, Ligue.RECOMPENSES[-1]["jetons"], Ligue.RECOMPENSES[0]["jetons"], Ligue.BONUS_CHAMPION, Ligue.BONUS_MONTEE],
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
