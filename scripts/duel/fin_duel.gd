class_name FinDuel
extends RefCounted
## Fin de partie commune aux modes Arène et Poussée : gains (Jetons + XP du
## fan club, mêmes règles que le duel d'ambiance) et panneau de résultats.


## Jetons et XP d'une partie. `perf` va de 0 (rien fait) à 1 (partie parfaite).
static func gains(gagne: bool, perf: float, mode_suivi: String, equipe_gagne := false) -> Dictionary:
	perf = clampf(perf, 0.0, 1.0)
	var gain_mode: float = Game.MODES_SUIVI.get(mode_suivi, {}).get("gain", 1.0)
	var jetons := int(round((10.0 + 20.0 * perf + (15.0 if gagne else 0.0)) * gain_mode * (1.3 if equipe_gagne else 1.0)))
	var xp := 40 + int(round(60.0 * perf)) + (40 if gagne else 0)
	return {"jetons": jetons, "xp": xp}


## Le vrai match : ton équipe mène-t-elle (ou a-t-elle gagné) ?
static func equipe_gagne(fiche: Dictionary, camp: String) -> bool:
	var m: Dictionary = fiche.get("m", {})
	var sc: Variant = m.get("score", {}).get("current")
	if not sc is Dictionary or not str(m.get("status", "")) in ["LIVE", "HALFTIME", "FINISHED"]:  # sans_traduction
		return false
	var h := int(sc.get("home", 0))
	var a := int(sc.get("away", 0))
	return h > a if camp == "home" else a > h


## Enregistre la partie (sauvegarde comprise) et renvoie les gains.
static func enregistrer(gagne: bool, perf: float, fiche: Dictionary, camp: String, mode_suivi: String) -> Dictionary:
	var eg := equipe_gagne(fiche, camp)
	var g := gains(gagne, perf, mode_suivi, eg)
	g["part"] = Game.noter_duel_match(str(fiche.get("id", fiche.get("m", {}).get("id", ""))))
	g["jetons"] = int(round(g["jetons"] * g["part"]))
	g["equipe_gagne"] = eg
	Game.duels_joues += 1
	if gagne:
		Game.duels_gagnes += 1
	Game.noter_duel_club()
	g["popularite"] = Game.noter_duel_favori(fiche.get("m", {}), camp, gagne, mode_suivi)
	g["equipe"] = fiche.get("dom" if camp == "home" else "ext", {}).get("nom", "")
	Game.gagner_jetons(g["jetons"])
	Game.ajouter_xp(g["xp"])
	g["xp_pass"] = Game.xp_pass_duel(gagne, perf, g["part"])
	g["evenement"] = Game.recompense_evenement(fiche.get("m", {}), int(g["jetons"]))
	g["tournoi"] = Game.noter_duel_tournoi(fiche.get("m", {}), gagne, mode_suivi)
	return g


## Ligne « Tournoi du week-end » du panneau de fin, ou [] si le duel n'y comptait pas.
static func ligne_tournoi(d: Variant) -> Array:
	if not d is Dictionary or d.is_empty():
		return []
	return [[Trad.t("Tournoi · %s contre %s") % ["victoire" if d["gagne"] else Trad.t("défaite"), Tournoi.nom_texte(d["nom_adv"])], Trad.t("+%d pt%s") % [int(d["pts"]), "" if int(d["pts"]) == 1 else "s"]]]


## Nom affiché pour la tribune d'en face : le club adverse du tournoi, sinon celle de l'équipe.
static func nom_adverse(m: Dictionary, equipe: String) -> String:
	var adv := Game.adversaire_tournoi(m)
	return Tournoi.nom_texte(adv["nom"]) if not adv.is_empty() else Trad.t("Tribune ") + equipe


## Lignes « Bonus Derby » et « Prime de la soirée » du panneau de fin, ou [].
static func lignes_evenement(ev: Dictionary) -> Array:
	if ev.is_empty():
		return []
	var lignes := [[Trad.t("Bonus %s (%s)") % [Trad.t(ev["titre"]), ev["texte_mult"]], Trad.t("+%d Jetons") % int(ev["bonus"])]]
	if int(ev.get("prime_xp", 0)) > 0:
		lignes.append(["Prime de la soirée", Trad.t("+%d XP PASS · +%d Jetons") % [int(ev["prime_xp"]), int(ev["prime_jetons"])]])
	return lignes


## Ligne « Popularité » du panneau de fin, ou [] si l'équipe n'est pas un favori.
static func ligne_popularite(g: Dictionary) -> Array:
	if int(g.get("popularite", 0)) <= 0:
		return []
	return [[Trad.t("Popularité · %s (favori)") % g.get("equipe", ""), "+%d" % int(g["popularite"])]]


## Panneau de fin : titre, lignes [libellé, valeur], boutons Retour / Rejouer.
static func panneau(parent: Control, titre: String, gagne: bool, lignes: Array, scene_rejouer: String) -> void:
	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.65, 0.4)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -460
	pan.offset_right = 460
	var demi_h := 300 + 24 * maxi(0, lignes.size() - 8)  # lignes en plus : derby, prime…
	pan.offset_top = -demi_h
	pan.offset_bottom = demi_h
	parent.add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label(titre, 50 if gagne else 38, Ui.JAUNE if gagne else Ui.ROSE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	for l in lignes:
		var h := Ui.hbox(10)
		var a := Ui.label(l[0], 24, Ui.BLANC)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Ui.label(l[1], 26, Ui.JAUNE, true))
		v.add_child(h)
	var hb := Ui.hbox(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var p: Dictionary = Game.params
	var retour := Ui.bouton("Retour à la carte", Ui.BLEU, 30)
	retour.custom_minimum_size = Vector2(380, 90)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CARTE, {"niveau": p.get("niveau", "monde"), "continent": p.get("continent", ""), "pays": p.get("pays", "")}))
	hb.add_child(retour)
	var rejouer := Ui.bouton("Rejouer", Ui.VERT, 30)
	Ui.colorer_bouton(rejouer, Ui.VERT, true)
	rejouer.custom_minimum_size = Vector2(260, 90)
	rejouer.pressed.connect(func(): Game.aller(scene_rejouer, p))
	hb.add_child(rejouer)
	v.add_child(Ui.espace())
	v.add_child(hb)
	pan.scale = Vector2(0.6, 0.6)
	pan.pivot_offset = Vector2(460, demi_h)
	pan.create_tween().tween_property(pan, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Échap pendant une partie : pause (contre l'IA) ou « Quitter la partie ? » (en ligne,
## où le jeu continue). Abandonner ramène à la carte, sans gains ; en ligne,
## l'adversaire gagne par forfait. Renvoie le panneau (ou null s'il était déjà ouvert : il se ferme).
static func pause(parent: Control, en_ligne: bool) -> Control:
	var deja := parent.get_node_or_null("PausePartie")  # sans_traduction
	if deja:
		_reprendre(deja)
		return null
	var voile := VoilePause.new()
	voile.name = "PausePartie"  # sans_traduction
	voile.color = Color(0.05, 0.03, 0.15, 0.65)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.process_mode = Node.PROCESS_MODE_ALWAYS
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(voile)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -360
	pan.offset_right = 360
	pan.offset_top = -170
	pan.offset_bottom = 170
	voile.add_child(pan)
	var v := Ui.vbox(16)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label("Quitter la partie ?" if en_ligne else "PAUSE", 46, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var st := Ui.label("La partie continue pendant ce temps. Ton adversaire gagnera par forfait." if en_ligne
		else "Abandonner ne rapporte ni Jetons ni XP.", 22, Ui.BLANC)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(st)
	var hb := Ui.hbox(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var reprendre := Ui.bouton("Reprendre", Ui.VERT, 30)
	Ui.colorer_bouton(reprendre, Ui.VERT, true)
	reprendre.custom_minimum_size = Vector2(260, 84)
	reprendre.pressed.connect(func(): _reprendre(voile))
	hb.add_child(reprendre)
	var abandon := Ui.bouton("Abandonner", Ui.ROSE, 30)
	abandon.custom_minimum_size = Vector2(260, 84)
	abandon.pressed.connect(func():
		var tree := voile.get_tree()
		tree.paused = false
		if en_ligne:
			Reseau.quitter()
		var p: Dictionary = Game.params
		Game.aller(Game.SCENE_CARTE, {"niveau": p.get("niveau", "monde"), "continent": p.get("continent", ""), "pays": p.get("pays", "")}))
	hb.add_child(abandon)
	v.add_child(hb)
	if not en_ligne:
		parent.get_tree().paused = true
	reprendre.grab_focus.call_deferred()
	return voile


static func _reprendre(voile: Node) -> void:
	if is_instance_valid(voile):
		voile.get_tree().paused = false
		voile.queue_free()


## Le voile de la pause : Échap le referme (il reçoit les touches même jeu en pause).
class VoilePause extends ColorRect:
	func _unhandled_input(ev: InputEvent) -> void:
		if ev.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			FinDuel._reprendre(self)
