extends Control
## Grand Tour : le car du fan club fait le tour des stades d'un pays
## (3 ou 5 étapes), un tampon à chaque arrêt. Règles dans scripts/jeu/grand_tour.gd.
## Paramètres : {"pays": cle, "retour_params": {...} (pour revenir sur la carte)}.

const Voyage := preload("res://scenes/voyage/voyage.gd")
const SonsScript := preload("res://scripts/audio/sons.gd")

var carte: CarteMonde
var _pays := ""
var _taille := "weekend"
var _tours: Dictionary = {}
var _panneau: PanelContainer
var _contenu: VBoxContainer
var _tampons: HBoxContainer
var _depart := Vector2.ZERO
var _sons: Node
var _en_route := false


func _ready() -> void:
	_pays = str(Game.params.get("pays", ""))
	_depart = Vector2(float(Game.position_club.get("lon", 0.0)), float(Game.position_club.get("lat", 0.0)))
	for t in GrandTour.ORDRE_TAILLES:
		_tours[t] = Game.proposer_grand_tour(_pays, t)
	if _tours["weekend"].is_empty():
		_taille = "boucle"

	carte = CarteMonde.new()
	carte.set_anchors_preset(Control.PRESET_FULL_RECT)
	carte.interactive = false
	carte.avatar = Game.texture_fanzzy(str(Game.equipe[0]), true) if not Game.equipe.is_empty() else null
	add_child(carte)
	if _pays != "":
		carte.surligner([_pays], false)

	_panneau = Ui.panneau(Ui.NUIT, 28, 6)
	_panneau.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panneau.offset_left = -700
	_panneau.offset_right = -24
	_panneau.offset_top = 24
	_panneau.offset_bottom = -24
	add_child(_panneau)
	_contenu = Ui.vbox(10)
	_panneau.add_child(_contenu)

	_tampons = Ui.hbox(8)
	_tampons.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_tampons.offset_left = 30
	_tampons.offset_top = -250
	_tampons.offset_bottom = -20
	_tampons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tampons)

	_sons = SonsScript.new()
	add_child(_sons)
	_afficher()
	_cadrer.call_deferred()


func _tour() -> Dictionary:
	return _tours.get(_taille, {})


func _cadrer() -> void:
	var droite := 740.0
	carte.centre_utile = Vector2((size.x - droite) / 2.0, size.y / 2.0 + 20.0)
	carte.largeur_utile = size.x - droite - 80.0
	var t := _tour()
	var boite := Rect2(Geo.centre_pays(_pays), Vector2.ZERO)
	if not t.is_empty():
		boite = Rect2(_depart, Vector2.ZERO)
		for e in t["etapes"]:
			boite = boite.expand(e["pos"])
	var largeur := clampf(maxf(boite.size.x * 1.5, boite.size.y * 3.0) + 4.0, maxf(8.0, Geo.taille_pays(_pays) * 1.2), 300.0)
	carte.voir(boite.get_center(), largeur, false)
	_tracer()


func _tracer() -> void:
	var t := _tour()
	var pts := PackedVector2Array([_depart])
	carte.etapes_route = []
	if not t.is_empty():
		for e in t["etapes"]:
			pts.append(e["pos"])
			carte.etapes_route.append({"pos": e["pos"], "nom": e["nom"]})
		carte.etapes_route.pop_back()  # la dernière étape a son propre rond vert
	carte.route_points = pts if pts.size() >= 2 else PackedVector2Array()
	carte.route_avance = 0.0
	carte.queue_redraw()


func _vider() -> void:
	for c in _contenu.get_children():
		_contenu.remove_child(c)
		c.queue_free()


func _afficher() -> void:
	_vider()
	var titre := Ui.label(tr("GRAND TOUR · %s") % Geo.nom_pays(_pays).to_upper(), 40, Ui.JAUNE, true, 8)
	titre.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenu.add_child(titre)
	var aide := Ui.label("Un voyage organisé : le car du fan club visite les stades du pays que tu n'as pas encore tamponnés, avec visite guidée.", 19, Ui.GRIS)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenu.add_child(aide)

	var choix := Ui.hbox(12)
	_contenu.add_child(choix)
	for k in GrandTour.ORDRE_TAILLES:
		var t: Dictionary = _tours[k]
		var b := Ui.bouton("", Ui.NUIT_CLAIR, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 80)
		var info: Dictionary = GrandTour.TAILLES[k]
		b.text = "%s\n%s" % [tr(info["titre"]), tr("%d stades") % (t["etapes"].size() if not t.is_empty() else info["etapes"])]
		b.disabled = t.is_empty() or (k == "boucle" and t["etapes"].size() <= _tours["weekend"].get("etapes", []).size())
		if k == _taille and not b.disabled:
			Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.pressed.connect(func():
			_taille = k
			_afficher()
			_cadrer())
		choix.add_child(b)

	var t := _tour()
	if t.is_empty():
		var rien := Ui.label("Tous les stades connus de ce pays sont déjà tamponnés (ou presque). Essaie un autre pays !", 22, Ui.BLANC)
		rien.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_contenu.add_child(rien)
	else:
		var liste := Ui.vbox(6)
		_contenu.add_child(liste)
		for i in t["etapes"].size():
			var e: Dictionary = t["etapes"][i]
			var l := Ui.label("%d. %s · %s" % [i + 1, e["nom"], e["club"]], 21, Ui.BLANC)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			liste.add_child(l)
		var det := Ui.label(tr("%d km · %d tampons · boutiques souvenirs au prix sur place aujourd'hui") % [int(t["km"]), t["etapes"].size()], 19, Ui.JAUNE)
		det.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_contenu.add_child(det)
		var note := Ui.label("Payé en Jetons : pas d'XP de PASS pour ces tampons (les primes du carnet comptent).", 17, Ui.GRIS)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_contenu.add_child(note)

	_contenu.add_child(Ui.espace())
	var partir := Ui.bouton("", Ui.VERT, 32)
	Ui.colorer_bouton(partir, Ui.VERT, true)
	partir.custom_minimum_size = Vector2(0, 92)
	if t.is_empty():
		partir.text = tr("Rien à visiter")
		partir.disabled = true
	elif Game.grand_tour_fait_aujourdhui():
		partir.text = tr("Un Grand Tour par jour : reviens demain")
		partir.disabled = true
	else:
		partir.text = tr("PARTIR · %d Jetons") % int(t["prix"])
		partir.disabled = int(t["prix"]) > Game.jetons
		if partir.disabled:
			partir.tooltip_text = tr("Il te faut %d Jetons (tu en as %d)") % [int(t["prix"]), Game.jetons]
	partir.pressed.connect(_partir)
	_contenu.add_child(partir)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT_CLAIR, 26)
	retour.custom_minimum_size = Vector2(0, 72)
	retour.pressed.connect(_retour)
	_contenu.add_child(retour)


func _retour() -> void:
	var p: Variant = Game.params.get("retour_params", {})
	Game.aller(Game.SCENE_CARTE, p if p is Dictionary else {})


func _partir() -> void:
	if _en_route:
		return
	var t := _tour()
	if t.is_empty() or Game.grand_tour_fait_aujourdhui():
		return
	var nouveaux := Game.partir_grand_tour(t)
	if not Game.grand_tour_fait_aujourdhui():
		return  # pas assez de Jetons
	_en_route = true
	_sons.jouer("ui_parfait")
	_vider()
	_contenu.add_child(Ui.label(tr("GRAND TOUR · %s") % Geo.nom_pays(_pays).to_upper(), 40, Ui.JAUNE, true, 8))
	var etat := Ui.label("En route !", 26, Ui.BLANC, true, 6)
	etat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenu.add_child(etat)
	# fraction du chemin (à l'écran) où se trouve chaque étape
	var ch := carte._chemin(carte.route_points)
	var cumul := [0.0]
	for i in ch.size() - 1:
		cumul.append(cumul[i] + ch[i].distance_to(ch[i + 1]))
	var total: float = maxf(cumul[cumul.size() - 1], 1.0)
	var tw := create_tween()
	var avant := 0.0
	for i in t["etapes"].size():
		var idx := mini(16 * (i + 1), cumul.size() - 1)
		var f: float = cumul[idx] / total
		var e: Dictionary = t["etapes"][i]
		tw.tween_method(func(a: float): carte.route_avance = a, avant, f, clampf(0.6 + (f - avant) * 3.0, 0.8, 2.2)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_callback(func():
			etat.text = tr("Étape %d : %s") % [i + 1, e["nom"]]
			_poser_tampon(e, e["cle"] in nouveaux))
		tw.tween_interval(0.7)
		avant = f
	tw.tween_callback(func(): _bilan(t, nouveaux))


func _poser_tampon(e: Dictionary, nouveau: bool) -> void:
	var tampon := Voyage.Tampon.new()
	tampon.nom = e["nom"]
	tampon.club = e["club"]
	tampon.date = FicheMatch.date_texte(int(Time.get_unix_time_from_system()))
	var eq := Fiction.equipe({"id": e["id"]})
	var encre: Color = eq["c1"]
	if encre.get_luminance() > 0.7:
		encre = eq["c2"] if (eq["c2"] as Color).get_luminance() <= 0.7 else Ui.ROSE
	tampon.couleur = encre
	# le tampon est dessiné pour 460 px : réduit dans une boite de 210 px
	var boite := Control.new()
	boite.custom_minimum_size = Vector2(210, 210)
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tampons.add_child(boite)
	tampon.size = Vector2(460, 460)
	tampon.pivot_offset = tampon.size / 2.0
	tampon.position = Vector2(105, 105) - tampon.pivot_offset
	tampon.rotation = deg_to_rad(randf_range(-14, 10))
	tampon.modulate.a = 0.0
	tampon.scale = Vector2.ONE
	tampon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.add_child(tampon)
	var tw := create_tween().set_parallel()
	tw.tween_property(tampon, "scale", Vector2.ONE * 0.45, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(tampon, "modulate:a", 1.0 if nouveau else 0.55, 0.2)
	_sons.jouer("ui_bien")


func _bilan(t: Dictionary, nouveaux: Array) -> void:
	_vider()
	_contenu.add_child(Ui.label("GRAND TOUR TERMINÉ !", 40, Ui.JAUNE, true, 8))
	var msg := Ui.label(tr("%d nouveaux tampons dans le carnet de voyage.") % nouveaux.size() if nouveaux.size() != 1
		else tr("1 nouveau tampon dans le carnet de voyage."), 24, Ui.BLANC, true, 5)
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenu.add_child(msg)
	if Game.primes_pretes() > 0:
		var pr := Ui.label("Des primes de collection t'attendent (carnet de voyage).", 20, Ui.JAUNE)
		pr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_contenu.add_child(pr)
	var aide := Ui.label("Les boutiques souvenirs de ces stades sont au prix sur place jusqu'à ce soir.", 19, Ui.GRIS)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_contenu.add_child(aide)
	_contenu.add_child(Ui.espace())
	var boutique := Ui.bouton("BOUTIQUES SOUVENIRS", Ui.JAUNE, 30)
	Ui.colorer_bouton(boutique, Ui.JAUNE, true)
	boutique.custom_minimum_size = Vector2(0, 88)
	var premier: String = t["etapes"][0]["cle"]
	boutique.pressed.connect(func(): Game.aller(Game.SCENE_COLLECTION, {"onglet": "vitrine", "stade": premier}))  # sans_traduction
	_contenu.add_child(boutique)
	var carnet := Ui.bouton("Carnet de voyage", Ui.ROSE, 26)
	carnet.custom_minimum_size = Vector2(0, 72)
	carnet.pressed.connect(func(): Game.aller(Game.SCENE_COLLECTION, {"onglet": "carnet"}))  # sans_traduction
	_contenu.add_child(carnet)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT_CLAIR, 26)
	retour.custom_minimum_size = Vector2(0, 72)
	retour.pressed.connect(_retour)
	_contenu.add_child(retour)
