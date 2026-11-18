extends Control
## Déplacement du fan club vers le stade d'un vrai match (règles dans Deplacement).
##  1. Organiser : le convoi (membres du club), le transport, l'itinéraire, le prix.
##  2. En route : le convoi avance sur la carte ; à chaque événement, on choisit
##     quoi faire (touches 1, 2, 3 ou clic). La ferveur monte… ou pas.
##  3. Arrivée : prime de ferveur, puis le tampon du stade (écran Voyage).

var carte: CarteMonde
var _p: Dictionary
var _fiche: Dictionary
var _depart: Vector2
var _arrivee: Vector2
var _dist := 0.0
var _exterieur := false
var _convoi: Array = []
var _familles: Array = []
var _transport := "car"
var _itin := "direct"
var _etape: Dictionary = {}
var _panneau: PanelContainer
var _contenu: VBoxContainer
var _bouton_partir: Button

# voyage en cours
var _en_route := false
var _evenements: Array = []
var _etat: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _carte_evt: PanelContainer
var _choix_boutons: Array = []
var _evt_courant: Dictionary = {}
var _jauge: Jauge
var _info_retard: Label
var _attente_choix := false
var _fractions: Array = []   # où s'arrête le convoi pour chaque événement (0-1)


func _ready() -> void:
	_p = Game.params.duplicate()
	var m := Donnees.match_par_id(str(_p.get("match_id", "")))
	if m.is_empty():
		Game.aller(Game.SCENE_CARTE)
		return
	_fiche = FicheMatch.de(m)
	_depart = Vector2(float(Game.position_club["lon"]), float(Game.position_club["lat"]))
	_arrivee = Vector2(_fiche["lieu"]["lon"], _fiche["lieu"]["lat"])
	_dist = Geo.distance_km(_depart, _arrivee)
	_exterieur = str(_p.get("camp", "home")) == "away"
	_convoi = Game.convoi()
	_familles = Game.familles_convoi()
	_etape = Deplacement.etape(_depart, _arrivee, _candidats_etape())
	if _etape.is_empty():
		var dir := _arrivee - _depart
		_etape = {"nom": tr("Halte panoramique"), "pos": _depart.lerp(_arrivee, 0.5) + Vector2(-dir.y, dir.x) * 0.2}
	var possibles := Deplacement.transports(_dist)
	_transport = "car" if "car" in possibles else possibles[0]

	carte = CarteMonde.new()
	carte.set_anchors_preset(Control.PRESET_FULL_RECT)
	carte.interactive = false
	carte.avatar = Game.texture_fanzzy(str(Game.equipe[0]), true) if not Game.equipe.is_empty() else null
	add_child(carte)
	if _fiche["lieu"]["pays"] != "":
		carte.surligner([_fiche["lieu"]["pays"]], false)

	_panneau = Ui.panneau(Ui.NUIT, 28, 6)
	_panneau.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_panneau.offset_left = -700
	_panneau.offset_right = -24
	_panneau.offset_top = 24
	_panneau.offset_bottom = -24
	add_child(_panneau)
	_contenu = Ui.vbox(9)
	_panneau.add_child(_contenu)
	_cadrer.call_deferred()
	_afficher()
	if _p.get("auto", false):
		# démo : on choisit la balade en car et le convoi choisit tout seul
		if "balade" in Deplacement.itineraires(_transport):
			_itin = "balade"
			_afficher()
		get_tree().create_timer(1.5).timeout.connect(_partir)


func _cadrer() -> void:
	var droite := 740.0
	carte.centre_utile = Vector2((size.x - droite) / 2.0, size.y / 2.0 + 20.0)
	carte.largeur_utile = size.x - droite - 80.0
	var pts := [_depart, _arrivee, _etape["pos"]]
	var boite := Rect2(_depart, Vector2.ZERO)
	for q in pts:
		boite = boite.expand(q)
	var largeur := clampf(maxf(boite.size.x * 1.6, boite.size.y * 3.4) + 6.0, 14.0, 300.0)
	carte.voir(boite.get_center(), largeur, false)
	_tracer()


## Lieux où une balade peut faire étape : villes des clubs connus, capitales.
func _candidats_etape() -> Array:
	var res: Array = []
	var villes: Dictionary = Donnees.villes()
	for id in villes:
		var pays := str(Geo.pays_des_equipes.get(id, ""))
		if pays != "":
			res.append({"nom": str(villes[id]), "pos": Geo.position_stade(pays, str(id))})
	var tous: Dictionary = Geo._donnees().get("pays", {})
	for cle in tous:
		var info: Dictionary = tous[cle]
		res.append({"nom": Geo.nom_pays(cle), "pos": Vector2(float(info.get("lon", 0.0)), float(info.get("lat", 0.0)))})
	return res


func _trace(itin: String) -> PackedVector2Array:
	return Deplacement.trace(_depart, _arrivee, itin, _etape["pos"])


func _tracer() -> void:
	carte.route_points = _trace(_itin)
	carte.routes_autres = []
	if not _en_route:
		for i in Deplacement.itineraires(_transport):
			if i != _itin:
				carte.routes_autres.append(_trace(i))
	carte.etapes_route = [_etape] if _itin == "balade" else []


func _cout_trajet() -> int:
	return Deplacement.cout(_dist, _transport, _itin, _convoi.size())


func _cout_total() -> int:
	return Game.billet("stade", _fiche["m"]) + _cout_trajet()


# ------------------------------------------------------------------ organiser

func _afficher() -> void:
	for c in _contenu.get_children():
		c.queue_free()
	var v := _contenu
	var titre := "DÉPLACEMENT À L'EXTÉRIEUR" if _exterieur else "LE FAN CLUB VA AU STADE"
	v.add_child(Ui.label(titre, 38, Ui.JAUNE, true, 8))
	var match_txt := Ui.label("%s – %s · %s" % [_fiche["dom"]["nom"], _fiche["ext"]["nom"], _fiche["stade"]["nom"]], 19, Ui.BLANC)
	match_txt.clip_text = true
	match_txt.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(match_txt)
	v.add_child(Ui.label(tr("%s km depuis %s") % [_milliers(int(_dist)), str(Game.position_club.get("nom", ""))], 17, Ui.GRIS))

	# le convoi
	var hc := Ui.hbox(8)
	hc.add_child(Ui.label(tr("Le convoi : %d FANZZY") % _convoi.size(), 22, Ui.BLANC, true))
	if _exterieur:
		var pa := Ui.pastille(tr("Supporters visiteurs · +%d ferveur") % Deplacement.FERVEUR_EXTERIEUR, Ui.ROSE, 14)
		hc.add_child(pa)
	v.add_child(hc)
	var portraits := Ui.hbox(4)
	for i in mini(_convoi.size(), 10):
		portraits.add_child(_portrait(str(_convoi[i])))
	if _convoi.size() > 10:
		portraits.add_child(Ui.label("+%d" % (_convoi.size() - 10), 22, Ui.JAUNE, true))
	v.add_child(portraits)
	var red := Deplacement.reduction(_convoi.size())
	var txt_red := tr("Cagnotte du club : -%d %% sur le trajet") % int(round(red * 100.0)) if red > 0.0 else tr("Recrute des membres : la cagnotte du club allège le trajet")
	var nd := _familles.count("depl")
	if nd > 0:
		txt_red += tr(" · %d FANZZY Déplacement à bord") % nd
	var lr := Ui.label(txt_red, 15, Ui.GRIS)
	lr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lr)

	# transport
	v.add_child(Ui.label("Transport", 22, Ui.BLANC, true))
	var ht := Ui.hbox(10)
	for t in Deplacement.ORDRE_TRANSPORTS:
		ht.add_child(_carte_transport(t))
	v.add_child(ht)

	# itinéraire
	v.add_child(Ui.label("Itinéraire", 22, Ui.BLANC, true))
	for i in Deplacement.itineraires(_transport):
		v.add_child(_carte_itineraire(i))

	var esp := Control.new()
	esp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(esp)
	var aide := Ui.panneau(Ui.NUIT_CLAIR, 18, 3)
	var la := Ui.label(tr("En route, chaque choix fait monter ou baisser la ferveur du convoi. À l'arrivée : une prime de Jetons et d'XP du PASS, et jusqu'à ×%s sur les Jetons des duels de ce match aujourd'hui. Certains choix demandent un FANZZY d'une famille précise dans le convoi.") % Trad.decimal(1.0 + Deplacement.BONUS_DUEL_MAX), 15, Ui.GRIS)
	la.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aide.add_child(la)
	v.add_child(aide)
	var fd := Deplacement.ferveur_depart(_transport, _familles, _exterieur)
	v.add_child(Ui.label(tr("Ferveur au départ : %d / 100") % fd, 17, Ui.GRIS))
	var hprix := Ui.hbox(6)
	hprix.add_child(Ui.label(tr("Billet %d + trajet %d = ") % [Game.billet("stade", _fiche["m"]), _cout_trajet()], 20, Ui.BLANC, true))
	hprix.add_child(Ui.icone("jeton", 26))
	hprix.add_child(Ui.label(str(_cout_total()), 24, Ui.JAUNE if _cout_total() <= Game.jetons else Ui.ROUGE, true))
	v.add_child(hprix)

	var hb := Ui.hbox(12)
	var retour := Ui.bouton("Retour", Ui.NUIT_CLAIR, 26)
	retour.custom_minimum_size = Vector2(180, 76)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CARTE, {"niveau": _p.get("niveau", "monde"), "continent": _p.get("continent", ""), "pays": _p.get("pays", "")}))
	hb.add_child(retour)
	# texte fixe (traduit à l'affichage) : le tutoriel retrouve le bouton par son début
	_bouton_partir = Ui.bouton("EN ROUTE !", Ui.JAUNE, 30)
	Ui.colorer_bouton(_bouton_partir, Ui.JAUNE, true)
	_bouton_partir.custom_minimum_size = Vector2(0, 76)
	_bouton_partir.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bouton_partir.disabled = _cout_total() > Game.jetons
	if _bouton_partir.disabled:
		_bouton_partir.text = tr("Il manque %d Jetons") % (_cout_total() - Game.jetons)
	_bouton_partir.pressed.connect(_partir)
	hb.add_child(_bouton_partir)
	v.add_child(hb)
	_tracer()


func _portrait(id: String) -> Control:
	var z := Game.fanzzy_par_id(id)
	var cadre := Ui.panneau(Game.couleur_famille(str(z.get("famille", ""))), 30, 3)
	cadre.custom_minimum_size = Vector2(56, 56)
	cadre.tooltip_text = "%s · %s" % [str(z.get("nom", id)), Game.nom_famille(str(z.get("famille", "")))]
	var tex := Game.texture_fanzzy(id, true)
	if tex:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		r.custom_minimum_size = Vector2(44, 44)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cadre.add_child(r)
	return cadre


func _carte_transport(t: String) -> Control:
	var info: Dictionary = Deplacement.TRANSPORTS[t]
	var possible := Deplacement.transport_possible(t, _dist)
	var choisi := t == _transport
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 116)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_stylebox_override("normal", Ui.boite(Ui.BLEU if choisi else Ui.NUIT_CLAIR, 16, 4, 4, Ui.JAUNE if choisi else Ui.CONTOUR))
	b.add_theme_stylebox_override("hover", Ui.boite(Ui.NUIT_CLAIR.lightened(0.1), 16, 4, 4))
	b.add_theme_stylebox_override("pressed", Ui.boite(Ui.BLEU, 16, 4, 2))
	b.add_theme_stylebox_override("disabled", Ui.boite(Color("#2e2a58"), 16, 4, 2))
	b.disabled = not possible
	var vb := Ui.vbox(2)
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.offset_left = 10
	vb.offset_top = 8
	vb.offset_right = -6
	vb.add_child(Ui.icone(t, 40))
	vb.add_child(Ui.label(info["titre"], 17, Ui.BLANC if possible else Ui.GRIS, true))
	var sous: String = info["texte"] if possible else ("Trop loin pour ce transport" if _dist > float(info["max_km"]) else "Trop près pour prendre l'avion")
	var ls := Ui.label(sous, 12, Ui.GRIS)
	ls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(ls)
	for c in vb.find_children("*", "Control", true, false):  # sans_traduction
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(vb)
	b.pressed.connect(func():
		_transport = t
		if not _itin in Deplacement.itineraires(t):
			_itin = "direct"
		_afficher())
	return b


func _carte_itineraire(i: String) -> Control:
	var info: Dictionary = Deplacement.ITINERAIRES[i]
	var choisi := i == _itin
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 70)
	b.add_theme_stylebox_override("normal", Ui.boite(Ui.VIOLET if choisi else Ui.NUIT_CLAIR, 16, 4, 4, Ui.JAUNE if choisi else Ui.CONTOUR))
	b.add_theme_stylebox_override("hover", Ui.boite(Ui.NUIT_CLAIR.lightened(0.1), 16, 4, 4))
	b.add_theme_stylebox_override("pressed", Ui.boite(Ui.VIOLET, 16, 4, 2))
	var h := Ui.hbox(10)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 14
	h.offset_right = -14
	var vb := Ui.vbox(0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_child(Ui.label(Deplacement.titre_itineraire(i, _transport), 20, Ui.BLANC, true))
	var nb := Deplacement.nb_evenements(_transport, i)
	var details := (tr("%s · %d événements en route") if nb > 1 else tr("%s · %d événement en route")) % [Deplacement.duree_texte(Deplacement.duree(_dist, _transport, i)), nb]
	if i == "balade":
		details += tr(" · étape : %s") % str(_etape["nom"])
	else:
		details += " · " + tr(info["texte"])
	var ld := Ui.label(details, 14, Ui.GRIS)
	ld.clip_text = true
	ld.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	vb.add_child(ld)
	h.add_child(vb)
	var hp := Ui.hbox(4)
	hp.add_child(Ui.icone("jeton", 24))
	hp.add_child(Ui.label(str(Deplacement.cout(_dist, _transport, i, _convoi.size())), 22, Ui.JAUNE, true))
	h.add_child(hp)
	for c in h.find_children("*", "Control", true, false):  # sans_traduction
		(c as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	b.pressed.connect(func():
		_itin = i
		_afficher())
	return b


# ------------------------------------------------------------------ en route

func _partir() -> void:
	if _en_route or not Game.depenser(_cout_total()):
		return
	# Le déplacement est payé : le match compte comme suivi au stade, billet non remboursé.
	Game.noter_suivi_favori(_fiche["m"], str(_p.get("camp", "home")), "stade")
	_p["cout"] = 0
	_en_route = true
	var graine := Fiction.graine("%s|%s|%s|%s" % [_fiche["id"], _transport, _itin, Time.get_date_string_from_system()])
	_rng.seed = graine
	_evenements = Deplacement.tirer(graine, _transport, _itin, str(_etape["nom"]))
	_etat = Deplacement.nouvel_etat(Deplacement.ferveur_depart(_transport, _familles, _exterieur))
	_tracer()
	_fractions = _placer_evenements()
	var tw := create_tween()
	tw.tween_property(_panneau, "modulate:a", 0.0, 0.25)
	tw.tween_callback(_panneau.hide)

	var bandeau := Ui.panneau()
	bandeau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bandeau.offset_left = -560
	bandeau.offset_right = 560
	bandeau.offset_top = 24
	add_child(bandeau)
	var v := Ui.vbox(6)
	bandeau.add_child(v)
	var t := Ui.label(tr("En route vers %s") % _fiche["stade"]["nom"], 36, Ui.JAUNE, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var h := Ui.hbox(12)
	h.add_child(Ui.icone(_transport, 34))
	h.add_child(Ui.label("Ferveur", 20, Ui.BLANC, true))
	_jauge = Jauge.new()
	_jauge.custom_minimum_size = Vector2(0, 30)
	_jauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_jauge.valeur = int(_etat["ferveur"])
	h.add_child(_jauge)
	_info_retard = Ui.label("", 18, Ui.GRIS)
	_info_retard.custom_minimum_size = Vector2(230, 0)
	h.add_child(_info_retard)
	v.add_child(h)
	_maj_bandeau()
	# la carte des événements occupe le bas de l'écran : la route se voit au-dessus
	carte.centre_utile = Vector2(size.x / 2.0, 390.0)
	carte.largeur_utile = size.x - 200.0
	_cadrer_route()
	_etape_suivante.call_deferred(0)


func _cadrer_route() -> void:
	var boite := Rect2(_depart, Vector2.ZERO)
	for q in carte.route_points:
		boite = boite.expand(q)
	var largeur := clampf(maxf(boite.size.x * 1.5, boite.size.y * 5.0) + 6.0, 14.0, 300.0)
	carte.voir(boite.get_center(), largeur, true)


func _maj_bandeau() -> void:
	_jauge.valeur = int(_etat["ferveur"])
	_jauge.queue_redraw()
	var r := int(_etat["retard"])
	_info_retard.text = tr("Retard : %s") % Deplacement.duree_texte(r) if r > 0 else tr("Pile à l'heure")
	_info_retard.add_theme_color_override("font_color", Ui.ROUGE if r > Deplacement.MARGE_RETARD else Ui.GRIS)


## Fractions du trajet où ont lieu les événements : régulières, mais l'étape
## d'une balade tombe pile sur la ville étape.
func _placer_evenements() -> Array:
	var n := _evenements.size()
	var res: Array = []
	var k := -1
	for i in n:
		if _evenements[i]["id"] == "etape":
			k = i
	if k < 0 or carte.route_points.size() < 3:
		for i in n:
			res.append(float(i + 1) / float(n + 1))
		return res
	var pts := carte.route_points
	var l1 := pts[0].distance_to(pts[1])
	var fe := clampf(l1 / maxf(0.001, l1 + pts[1].distance_to(pts[2])), 0.2, 0.8)
	for i in n:
		if i < k:
			res.append(fe * float(i + 1) / float(k + 1))
		elif i == k:
			res.append(fe)
		else:
			res.append(fe + (1.0 - fe) * float(i - k) / float(n - k))
	return res


## Avance jusqu'à l'événement i (ou jusqu'au stade quand il n'y en a plus).
func _etape_suivante(i: int) -> void:
	var n := _evenements.size()
	var cible: float = _fractions[i] if i < n else 1.0
	var duree := clampf(1.2 + _dist / 2500.0, 1.2, 2.6) * (cible - carte.route_avance)
	var tw := create_tween()
	tw.tween_method(func(a: float):
		carte.route_avance = a, carte.route_avance, cible, maxf(0.3, duree * 1.6)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if i < n:
		tw.tween_callback(func(): _montrer_evenement(i))
	else:
		tw.tween_callback(_arriver)


func _montrer_evenement(i: int) -> void:
	_evt_courant = _evenements[i]
	_carte_evt = Ui.panneau(Ui.NUIT, 26, 6)
	_carte_evt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_carte_evt.offset_left = -560
	_carte_evt.offset_right = 560
	_carte_evt.offset_top = -40
	_carte_evt.offset_bottom = -40
	_carte_evt.grow_vertical = Control.GROW_DIRECTION_BEGIN  # la carte grandit vers le haut selon le texte
	add_child(_carte_evt)
	var v := Ui.vbox(10)
	_carte_evt.add_child(v)
	var h := Ui.hbox(10)
	h.add_child(Ui.pastille(tr("Événement %d / %d") % [i + 1, _evenements.size()], Ui.ROSE, 15))
	var t := Ui.label(Deplacement.titre_evenement(_evt_courant), 30, Ui.JAUNE, true, 6)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.add_child(t)
	v.add_child(h)
	var tx := Ui.label(tr(str(_evt_courant["texte"])), 19, Ui.BLANC)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tx)
	_choix_boutons = []
	var k := 0
	for c in _evt_courant["choix"]:
		var ok := Deplacement.choix_possible(c, _familles)
		var libelle := "%d. %s" % [k + 1, tr(str(c["texte"]))]
		if c.has("famille"):
			libelle += tr("  (FANZZY %s)") % Game.nom_famille(str(c["famille"]))
		var b := Ui.bouton(libelle, Ui.BLEU if ok else Ui.NUIT_CLAIR, 19)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 58)
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.disabled = not ok
		if c.has("famille"):
			b.tooltip_text = tr("Il faut un FANZZY %s dans le convoi") % Game.nom_famille(str(c["famille"])) if not ok else tr("Grâce à un FANZZY %s du convoi") % Game.nom_famille(str(c["famille"]))
			if ok:
				Ui.colorer_bouton(b, Game.couleur_famille(str(c["famille"])).darkened(0.25))
		var cc: Dictionary = c
		b.pressed.connect(func(): _choisir(i, cc))
		v.add_child(b)
		_choix_boutons.append(b)
		k += 1
	Ui.pop(_carte_evt, 1.05)
	_attente_choix = true
	if _p.get("auto", false):
		var meilleur := -1
		for j in _choix_boutons.size():
			if not _choix_boutons[j].disabled and (meilleur < 0 or int(_evt_courant["choix"][j].get("ferveur", 0)) > int(_evt_courant["choix"][meilleur].get("ferveur", 0))):
				meilleur = j
		var bouton: Button = _choix_boutons[meilleur]
		get_tree().create_timer(1.4).timeout.connect(func(): bouton.pressed.emit())


func _choisir(i: int, c: Dictionary) -> void:
	if not _attente_choix:
		return
	_attente_choix = false
	var r := Deplacement.resultat(c, _rng.randf())
	Deplacement.appliquer(_etat, _evt_courant, r)
	_maj_bandeau()
	for b in _choix_boutons:
		b.disabled = true
	var v: VBoxContainer = _carte_evt.get_child(0)
	var effets: Array = []
	if int(r["ferveur"]) != 0:
		effets.append(tr("%+d ferveur") % int(r["ferveur"]))
	if int(r["jetons"]) > 0:
		effets.append(tr("+%d Jetons") % int(r["jetons"]))
	if int(r["retard"]) > 0:
		effets.append(tr("+%d min") % int(r["retard"]))
	var lr := Ui.label(tr(str(r["res"])) + ("   " + " · ".join(effets) if not effets.is_empty() else ""), 22, Ui.VERT if r["ferveur"] >= 0 else Ui.ROSE, true, 5)
	lr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(lr)
	var carte_evt := _carte_evt
	var tw := create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(carte_evt, "modulate:a", 0.0, 0.25)
	tw.tween_callback(carte_evt.queue_free)
	tw.tween_callback(func(): _etape_suivante(i + 1))


func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo):
		return
	if _attente_choix:
		var idx := -1
		# touche physique : en AZERTY, « 1 » sans Maj donne « & »
		match (ev as InputEventKey).physical_keycode:
			KEY_1, KEY_KP_1:
				idx = 0
			KEY_2, KEY_KP_2:
				idx = 1
			KEY_3, KEY_KP_3:
				idx = 2
		if idx >= 0 and idx < _choix_boutons.size() and not _choix_boutons[idx].disabled:
			_choix_boutons[idx].pressed.emit()
			get_viewport().set_input_as_handled()
	elif not _en_route and (ev as InputEventKey).keycode == KEY_ESCAPE:
		Game.aller(Game.SCENE_CARTE, {"niveau": _p.get("niveau", "monde"), "continent": _p.get("continent", ""), "pays": _p.get("pays", "")})


func _arriver() -> void:
	var b := Deplacement.bilan(_etat)
	b["transport"] = _transport
	var r := Game.finir_deplacement(str(_fiche["id"]), b)
	_p["arrive"] = true
	_p["bilan"] = r
	Game.aller(Game.SCENE_VOYAGE, _p)


static func _milliers(n: int) -> String:
	var s := str(n)
	var res := ""
	while s.length() > 3:
		res = " " + s.substr(s.length() - 3) + res
		s = s.substr(0, s.length() - 3)
	return s + res


## Jauge de ferveur du convoi (0-100).
class Jauge extends Control:
	var valeur := 0

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_style_box(Ui.boite(Ui.CONTOUR, int(size.y / 2.0), 0), r)
		var w := (size.x - 8.0) * clampf(valeur / 100.0, 0.0, 1.0)
		if w > 4.0:
			var col := Ui.ROSE.lerp(Ui.JAUNE, clampf(valeur / 100.0, 0.0, 1.0))
			draw_style_box(Ui.boite(col, int(size.y / 2.0 - 4.0), 0), Rect2(Vector2(4, 4), Vector2(w, size.y - 8.0)))
		var f := Ui.police_titre()
		var txt := "%d" % valeur
		var tw := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var pos := Vector2(size.x / 2.0 - tw / 2.0, size.y / 2.0 + 7.0)
		draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 4, Ui.CONTOUR)
		draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.BLANC)
