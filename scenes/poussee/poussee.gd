extends Control
## Mode Poussée : pose tes supporters avec des cartes, pousse le ballon
## jusqu'au but adverse ou conquiers la tribune d'en face. 3 minutes.
##   Choisir une carte : clic ou touches 1 à 4 · la poser : clic dans ta moitié
##   (les effets Fumigène et Ola se posent partout).
## La Ferveur remonte toute seule (deux fois plus vite la dernière minute).
## Règles chiffrées : scripts/duel/poussee_regles.gd.

const TERRAIN := Rect2(150, 176, 1620, 630)
const HAUTEUR_UNITE := 92.0
const RAYON_UNITE := 20.0

var fiche: Dictionary
var camp := "home"
var mode_suivi := "stade"

var temps := 0.0
var en_cours := false
var termine := false
var couleurs := [Ui.BLEU, Ui.ROUGE]
var noms := ["", ""]
var ferveur := [PousseeRegles.FERVEUR_DEPART, PousseeRegles.FERVEUR_DEPART]
var tribune := [PousseeRegles.TRIBUNE_PV, PousseeRegles.TRIBUNE_PV]
var piles := [[], []]
var posees := [0, 0]
var unites: Array = []          # Unite
var zones: Array = []           # {pos, rayon, type, equipe, reste, duree}
var notes: Array = []           # {de, a, col, t}  (chants lancés de loin)
var confettis: Array = []
var textes: Array = []
var ballon := {"pos": Vector2.ZERO, "vel": Vector2.ZERO}
var selection := -1
var vainqueur := 0              # 1 = toi, -1 = eux, 0 = égalité
var raison := ""

var _monde: Node2D
var _sol: Sol
var _ciel: Ciel
var _lbl_temps: Label
var _lbl_annonce: Label
var _barres: Array = []
var _main: HBoxContainer
var _suivante: TextureRect
var _ferveur_barre: BarreFerveur
var _rng := RandomNumberGenerator.new()
var _ia_pense := [1.5, 1.5]
var _auto := false             # démo : ton camp joue tout seul
var _visuels := {}              # [equipe, famille] -> id FANZZY

# --- en ligne : l'hôte simule tout (il est l'équipe 0 chez lui, l'invité l'équipe 1) ;
# l'invité voit le terrain retourné (lui à gauche), envoie ses cartes et affiche les instantanés.
var en_ligne := false
var _invite := false            # vrai chez l'invité : pas de simulation locale
var _uid := 0
var _par_id := {}               # invité : id d'unité -> Unite
var _t_instant := 0.0
var _adv_pret := false
var _depart_envoye := false
var _ballon_cible := Vector2.ZERO
var _main_vue := []


func _ready() -> void:
	var p: Dictionary = Game.params
	en_ligne = bool(p.get("en_ligne", false)) and Reseau.connecte()
	_invite = en_ligne and not Reseau.hote
	var m: Dictionary = p.get("match", {}) if en_ligne else Donnees.match_par_id(str(p.get("match_id", "")))
	if m.is_empty():
		Game.aller(Game.SCENE_CARTE)
		return
	fiche = FicheMatch.de(m)
	camp = p.get("camp", "home")
	mode_suivi = p.get("mode", "stade")
	_auto = p.get("auto", false)
	_rng.seed = hash(str(fiche["id"])) + Time.get_ticks_msec()
	var dom: Dictionary = fiche["dom"]
	var ext: Dictionary = fiche["ext"]
	var nous: Dictionary = dom if camp == "home" else ext
	var eux: Dictionary = ext if camp == "home" else dom
	couleurs[0] = Duel._vive(nous["c1"], nous["c2"], Ui.BLEU)
	couleurs[1] = Duel._vive(eux["c1"], eux["c2"], Ui.ROUGE)
	couleurs[1] = Ui.couleur_distincte(couleurs[0], couleurs[1])
	noms[0] = Game.fan_club_nom
	noms[1] = str(Reseau.adversaire.get("nom", "?")) if en_ligne else FinDuel.nom_adverse(fiche["m"], str(eux["nom"]))
	var cartes := PousseeRegles.cartes_debloquees(Game.niveau())
	piles[0] = PousseeRegles.nouvelle_pile(cartes, _rng)
	# l'adversaire a le même jeu que toi : la partie reste équitable
	piles[1] = PousseeRegles.nouvelle_pile(cartes, _rng)
	ballon["pos"] = TERRAIN.get_center()
	_ballon_cible = ballon["pos"]
	if _invite:
		piles[0] = []  # la main de l'invité arrive avec les instantanés de l'hôte
	_choisir_visuels()
	_construire()
	if en_ligne:
		_preparer_en_ligne()
	else:
		_compte_a_rebours()


## Quel FANZZY représente chaque carte : les tiens d'abord, sinon le catalogue.
func _choisir_visuels() -> void:
	for fam in Game.familles:
		var liste: Array = Game.fanzzy.filter(func(z): return z["famille"] == fam)
		if liste.is_empty():
			continue
		var a: String = liste[0]["id"]
		for id in Game.equipe:
			if Game.fanzzy_par_id(str(id)).get("famille", "") == fam:
				a = str(id)
		var autres := liste.filter(func(z): return z["id"] != a)
		_visuels[[0, fam]] = Game.skin_de(a)
		_visuels[[1, fam]] = str(autres[_rng.randi_range(0, autres.size() - 1)]["id"]) if not autres.is_empty() else a


# ------------------------------------------------------------------ construction

func _construire() -> void:
	# l'écran entier laisse passer les clics : sinon il les garde pour lui et
	# le clic sur le terrain (poser un FANZZY) n'arrive jamais à _unhandled_input
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := ColorRect.new()
	fond.color = Color("#2a2266")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)
	_sol = Sol.new()
	_sol.jeu = self
	add_child(_sol)
	_monde = Node2D.new()
	_monde.y_sort_enabled = true
	add_child(_monde)
	var bal := Ballon.new()
	bal.jeu = self
	bal.position = ballon["pos"]
	_monde.add_child(bal)
	_ciel = Ciel.new()
	_ciel.jeu = self
	add_child(_ciel)

	# haut : tribunes et chrono
	var haut := Ui.hbox(18)
	haut.set_anchors_preset(Control.PRESET_CENTER_TOP)
	haut.offset_left = -820
	haut.offset_right = 820
	haut.offset_top = 12
	add_child(haut)
	for e in 2:
		var v := Ui.vbox(2)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var l := Ui.label(noms[e].to_upper(), 26, Ui.BLANC, true, 8)
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if e == 1:
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(l)
		var b := Arene_Barre.new()
		b.couleur = couleurs[e]
		b.inverse = e == 1
		b.valeur = 1.0
		b.custom_minimum_size = Vector2(600, 30)
		v.add_child(b)
		_barres.append(b)
		haut.add_child(v)
		if e == 0:
			var c := Ui.vbox(0)
			c.add_child(Ui.label("POUSSÉE", 26, Ui.JAUNE, true, 8))
			_lbl_temps = Ui.label("3:00", 44, Ui.BLANC, true, 10)
			_lbl_temps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(_lbl_temps)
			haut.add_child(c)

	# bas : la main de cartes et la Ferveur
	var bas := Ui.hbox(14)
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.offset_left = -760
	bas.offset_right = 760
	bas.offset_top = -258
	bas.offset_bottom = -14
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bas)
	var vs := Ui.vbox(4)
	vs.add_child(Ui.label("SUIVANTE", 18, Ui.GRIS, true))
	_suivante = TextureRect.new()
	_suivante.custom_minimum_size = Vector2(110, 140)
	_suivante.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_suivante.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_suivante.modulate = Color(1, 1, 1, 0.7)
	vs.add_child(_suivante)
	bas.add_child(vs)
	var vm := Ui.vbox(8)
	_main = Ui.hbox(12)
	vm.add_child(_main)
	_ferveur_barre = BarreFerveur.new()
	_ferveur_barre.custom_minimum_size = Vector2(4 * 216 + 36, 34)
	vm.add_child(_ferveur_barre)
	bas.add_child(vm)
	var aide := Ui.label("Clic sur une carte (ou 1-4)\npuis clic dans ta moitié.\nPousse le ballon dans le but\nou conquiers la tribune !", 18, Ui.BLANC)
	aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bas.add_child(aide)
	_maj_main()

	_lbl_annonce = Ui.label("", 90, Ui.JAUNE, true, 14)
	_lbl_annonce.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_annonce.offset_left = -800
	_lbl_annonce.offset_right = 800
	_lbl_annonce.offset_top = -200
	_lbl_annonce.offset_bottom = -40
	_lbl_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_annonce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_annonce.pivot_offset = Vector2(800, 80)
	_lbl_annonce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_lbl_annonce)


func _maj_main() -> void:
	for c in _main.get_children():
		c.queue_free()
	var pile: Array = piles[0]
	for i in mini(PousseeRegles.TAILLE_MAIN, pile.size()):
		var cle: String = pile[i]
		var c: Dictionary = PousseeRegles.CARTES[cle]
		var b := Button.new()
		b.custom_minimum_size = Vector2(216, 196)
		b.focus_mode = Control.FOCUS_NONE
		var choisie := i == selection
		var assez: bool = ferveur[0] >= float(c["cout"])
		var fond := Game.couleur_famille(c["famille"]).darkened(0.25 if assez else 0.6)
		b.add_theme_stylebox_override("normal", Ui.boite(fond, 18, 6 if choisie else 4, 6, Ui.JAUNE if choisie else Ui.CONTOUR))
		b.add_theme_stylebox_override("hover", Ui.boite(fond.lightened(0.15), 18, 6 if choisie else 4, 6, Ui.JAUNE if choisie else Ui.CONTOUR))
		b.add_theme_stylebox_override("pressed", Ui.boite(fond.darkened(0.1), 18, 6, 2, Ui.JAUNE))
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var v := Ui.vbox(0)
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 8
		v.offset_right = -8
		v.offset_top = 6
		v.offset_bottom = -6
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var img := TextureRect.new()
		img.texture = _icone(cle)
		img.custom_minimum_size = Vector2(0, 104)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(img)
		var n := Ui.label(c["nom"], 20, Ui.BLANC, true, 6)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		v.add_child(n)
		var t := Ui.label(c["texte"], 14, Ui.BLANC)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(t)
		b.add_child(v)
		var cout := Ui.pastille(str(c["cout"]), Ui.ROSE, 24)
		cout.position = Vector2(-10, -12)
		cout.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(cout)
		if not assez:
			b.modulate = Color(0.75, 0.75, 0.8)
		var idx := i
		b.pressed.connect(func(): _selectionner(idx))
		_main.add_child(b)
	if pile.size() > PousseeRegles.TAILLE_MAIN:
		_suivante.texture = _icone(pile[PousseeRegles.TAILLE_MAIN])


func _icone(cle: String) -> Texture2D:
	var c: Dictionary = PousseeRegles.CARTES[cle]
	return Game.texture_fanzzy(str(_visuels.get([0, c["famille"]], "")), true)


func _selectionner(i: int) -> void:
	selection = -1 if selection == i else i
	_maj_main()


func _compte_a_rebours() -> void:
	for t in ["3", "2", "1", "POUSSEZ !"]:
		annoncer(t, Ui.JAUNE)
		await get_tree().create_timer(0.75).timeout
		if not is_inside_tree():
			return  # écran quitté pendant le compte à rebours
	en_cours = true
	_lbl_annonce.text = ""


func annoncer(texte: String, couleur: Color) -> void:
	_lbl_annonce.text = texte
	_lbl_annonce.add_theme_color_override("font_color", couleur)
	Ui.pop(_lbl_annonce, 1.3, 0.25)


# ------------------------------------------------------------------ commandes

func _unhandled_input(ev: InputEvent) -> void:
	if not en_cours or termine:
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		var k := (ev as InputEventKey).keycode
		# chiffres : touche physique (en AZERTY, « 1 » sans Maj donne « & »)
		var kp := (ev as InputEventKey).physical_keycode
		if kp >= KEY_1 and kp <= KEY_4:
			_selectionner(kp - KEY_1)
		elif kp >= KEY_KP_1 and kp <= KEY_KP_4:
			_selectionner(kp - KEY_KP_1)
		elif k == KEY_ESCAPE:
			if selection >= 0:
				selection = -1
				_maj_main()
			else:
				FinDuel.pause(self, en_ligne)
	elif ev is InputEventMouseButton and ev.pressed:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			selection = -1
			_maj_main()
		elif mb.button_index == MOUSE_BUTTON_LEFT and selection >= 0:
			var pos := get_global_mouse_position()
			if TERRAIN.has_point(pos):
				var cle: String = piles[0][selection]
				if not zone_permise(0, cle, pos):
					texte(pos, "DANS TA MOITIÉ !", Ui.ROSE)
				elif not _jouer(selection, pos):
					texte(pos, "PAS ASSEZ DE FERVEUR", Ui.ROSE)
				else:
					selection = -1
				_maj_main()


func zone_permise(e: int, cle: String, pos: Vector2) -> bool:
	if PousseeRegles.CARTES[cle]["type"] == "effet":
		return TERRAIN.has_point(pos)
	var cx := TERRAIN.get_center().x
	return pos.x < cx - 10 if e == 0 else pos.x > cx + 10


## Joue la carte n° i de la main de l'équipe e. Renvoie false sans Ferveur.
func poser(e: int, i: int, pos: Vector2) -> bool:
	var cle: String = piles[e][i]
	var c: Dictionary = PousseeRegles.CARTES[cle]
	if ferveur[e] < float(c["cout"]):
		return false
	ferveur[e] -= float(c["cout"])
	piles[e] = PousseeRegles.jouer_carte(piles[e], i)
	posees[e] += 1
	pos.x = clampf(pos.x, TERRAIN.position.x + 20, TERRAIN.end.x - 20)
	pos.y = clampf(pos.y, TERRAIN.position.y + 20, TERRAIN.end.y - 10)
	if c["type"] == "effet":
		zones.append({"pos": pos, "rayon": c["rayon"], "type": cle, "equipe": e, "reste": c["duree"], "duree": c["duree"]})
		_pluie(pos, couleurs[e], 20)
		return true
	var nb: int = c["nb"]
	for k in nb:
		_uid += 1
		_creer_unite(_uid, e, cle, pos + (Vector2.from_angle(k * TAU / nb) * 34.0 if nb > 1 else Vector2.ZERO))
	_pluie(pos, couleurs[e], 14)
	return true


func _creer_unite(uid: int, e: int, cle: String, pos: Vector2) -> Unite:
	var c: Dictionary = PousseeRegles.CARTES[cle]
	var u := Unite.new()
	u.jeu = self
	u.uid = uid
	u.equipe = e
	u.cle = cle
	u.carte = c
	u.pv = c["pv"]
	u.position = pos
	u.cible = pos
	u.couleur = couleurs[e]
	u.creer(str(_visuels.get([e, c["famille"]], "")))
	_monde.add_child(u)
	unites.append(u)
	return u


## Ta carte n° i : posée tout de suite, ou envoyée à l'hôte si tu es l'invité.
func _jouer(i: int, pos: Vector2) -> bool:
	if not _invite:
		return poser(0, i, pos)
	var cout := float(PousseeRegles.CARTES[piles[0][i]]["cout"])
	if ferveur[0] < cout:
		return false
	ferveur[0] -= cout  # en attendant l'instantané de l'hôte
	posees[0] += 1
	Reseau.envoyer(Protocole.msg("carte", {"i": i, "x": pos.x, "y": pos.y}))
	_pluie(pos, couleurs[0], 10)
	_maj_main()
	return true


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_animer_effets(delta)
	_sol.queue_redraw()
	_ciel.queue_redraw()
	if not en_cours or termine:
		return
	if _invite:
		_suivre_hote(delta)
		_maj_hud()
		return
	temps += delta
	for e in 2:
		var avant: int = int(ferveur[e])
		ferveur[e] = PousseeRegles.ferveur(ferveur[e], temps, delta)
		if e == 0 and int(ferveur[0]) != avant:
			_maj_main()
	if temps >= PousseeRegles.DUREE - PousseeRegles.RUSH and temps - delta < PousseeRegles.DUREE - PousseeRegles.RUSH:
		annoncer("DERNIÈRE MINUTE : FERVEUR x2 !", Ui.ROSE)
		get_tree().create_timer(1.5).timeout.connect(func(): if not termine: _lbl_annonce.text = "")
	if not en_ligne:
		_ia(1, delta)
	if _auto:
		_ia(0, delta)
	for u in unites.duplicate():
		if is_instance_valid(u) and u.actif:
			_unite(u, delta)
	_separer()
	_ballon(delta)
	for z in zones:
		z["reste"] -= delta
	zones = zones.filter(func(z): return z["reste"] > 0.0)
	if en_ligne:
		_t_instant -= delta
		if _t_instant <= 0.0:
			_t_instant = 0.05
			Reseau.envoyer_vite(_instant())
	_maj_hud()
	if tribune[1] <= 0.0:
		_finir(1, "TRIBUNE CONQUISE !")
	elif tribune[0] <= 0.0:
		_finir(-1, "ILS ONT CONQUIS TA TRIBUNE…")
	elif temps >= PousseeRegles.DUREE:
		var res := PousseeRegles.resultat_temps(tribune[0], tribune[1])
		_finir(res, "FIN DU TEMPS !")


func _maj_hud() -> void:
	var reste := maxf(PousseeRegles.DUREE - temps, 0.0)
	_lbl_temps.text = "%d:%02d" % [int(reste) / 60, int(reste) % 60]
	_lbl_temps.add_theme_color_override("font_color", Ui.ROSE if reste < 20.0 else Ui.BLANC)
	for e in 2:
		_barres[e].valeur = tribune[e] / PousseeRegles.TRIBUNE_PV
		_barres[e].queue_redraw()
	_ferveur_barre.valeur = ferveur[0]
	_ferveur_barre.queue_redraw()


func _sens(e: int) -> float:
	return 1.0 if e == 0 else -1.0


func _but_adverse(e: int) -> Vector2:
	var cy := TERRAIN.get_center().y
	return Vector2(TERRAIN.end.x + 30, cy) if e == 0 else Vector2(TERRAIN.position.x - 30, cy)


func _modif(u: Unite) -> Dictionary:
	var m := {"vitesse": 1.0, "force": 1.0}
	for z in zones:
		if u.position.distance_to(z["pos"]) > z["rayon"]:
			continue
		if z["type"] == "fumigene" and z["equipe"] != u.equipe:
			m["vitesse"] *= 0.4
		elif z["type"] == "ola" and z["equipe"] == u.equipe:
			m["vitesse"] *= 1.6
			m["force"] *= 1.5
	return m


func _unite(u: Unite, delta: float) -> void:
	var c: Dictionary = u.carte
	var m := _modif(u)
	u.recharge = maxf(u.recharge - delta, 0.0)
	for z in zones:
		if z["type"] == "fumigene" and z["equipe"] != u.equipe and u.position.distance_to(z["pos"]) < z["rayon"]:
			u.pv -= 10.0 * delta
	if c["type"] == "batiment":
		u.pv -= float(c["pv"]) / float(c["vie"]) * delta
		var cible := _ennemi_proche(u, float(c["portee"]))
		if cible:
			_attaquer(u, cible, m)
		if u.pv <= 0.0:
			u.s_asseoir()
		return
	var vers_tribune: bool = c.get("cible", "") == "tribune"
	var cible: Unite = null if vers_tribune else _ennemi_proche(u, maxf(float(c["portee"]) + 80.0, 210.0))
	var dest := u.position
	var bouge := true
	var bord := TERRAIN.end.x if u.equipe == 0 else TERRAIN.position.x
	var dans_portee_tribune := absf(bord - u.position.x) <= float(c["portee"]) + 25.0
	if cible:
		if u.position.distance_to(cible.position) <= float(c["portee"]) + RAYON_UNITE * 2.0:
			bouge = false
			_attaquer(u, cible, m)
		else:
			dest = cible.position
	elif not vers_tribune and float(c["poussee"]) >= 0.8 and u.position.distance_to(ballon["pos"]) < 460.0:
		# se placer derrière le ballon, côté de son propre camp, puis pousser
		var b: Vector2 = ballon["pos"]
		var vers_but := (_but_adverse(u.equipe) - b).normalized()
		dest = b - vers_but * (PousseeRegles.BALLON_RAYON + RAYON_UNITE)
		if (u.position.x - b.x) * _sens(u.equipe) > -8.0 and absf(u.position.y - b.y) < PousseeRegles.BALLON_RAYON + RAYON_UNITE + 6:
			# devant le ballon : le contourner par le côté
			dest = b + Vector2(-_sens(u.equipe) * 30.0, (1.0 if u.position.y >= b.y else -1.0) * (PousseeRegles.BALLON_RAYON + RAYON_UNITE + 20))
	elif dans_portee_tribune:
		bouge = false
		if u.recharge <= 0.0:
			tribune[1 - u.equipe] -= float(c["puissance"]) * m["force"]
			u.recharge = c["cadence"]
			u.chanter()
			notes.append({"de": u.position + Vector2(0, -60), "a": Vector2(bord + _sens(u.equipe) * 60, u.position.y - 40), "col": couleurs[u.equipe], "t": 0.0})
	else:
		dest = Vector2(bord, lerpf(u.position.y, TERRAIN.get_center().y, 0.15))
	if bouge:
		var v := dest - u.position
		var pas: float = float(c["vitesse"]) * m["vitesse"] * delta
		u.avancer(v.limit_length(pas), v.length() > 2.0)
	else:
		u.avancer(Vector2.ZERO, false)
	# pousser le ballon au contact
	var d: Vector2 = ballon["pos"] - u.position
	var contact := PousseeRegles.BALLON_RAYON + RAYON_UNITE
	if d.length() < contact:
		var n := d.normalized() if d != Vector2.ZERO else Vector2(_sens(u.equipe), 0)
		ballon["vel"] += n * float(c["poussee"]) * m["force"] * 30.0 * delta
		u.position = ballon["pos"] - n * contact
	u.position.y = clampf(u.position.y, TERRAIN.position.y + 10, TERRAIN.end.y - 4)
	u.position.x = clampf(u.position.x, TERRAIN.position.x + 10, TERRAIN.end.x - 10)
	if u.pv <= 0.0:
		u.s_asseoir()


func _ennemi_proche(u: Unite, portee: float) -> Unite:
	var meilleur: Unite = null
	var dmin := portee
	for o in unites:
		if o.equipe != u.equipe and o.actif:
			var d: float = u.position.distance_to(o.position)
			if d < dmin:
				dmin = d
				meilleur = o
	return meilleur


func _attaquer(u: Unite, cible: Unite, m: Dictionary) -> void:
	u.avancer(Vector2.ZERO, false)
	u.regarder(cible.position.x - u.position.x)
	if u.recharge > 0.0:
		return
	u.recharge = u.carte["cadence"]
	cible.pv -= float(u.carte["puissance"]) * m["force"]
	cible.secouer()
	u.chanter()
	if float(u.carte["portee"]) > 100.0:
		notes.append({"de": u.position + Vector2(0, -50), "a": cible.position + Vector2(0, -40), "col": couleurs[u.equipe], "t": 0.0})
	if cible.pv <= 0.0:
		cible.s_asseoir()


func _separer() -> void:
	for i in unites.size():
		var a: Unite = unites[i]
		if not a.actif or a.carte["type"] == "batiment":
			continue
		for j in range(i + 1, unites.size()):
			var b: Unite = unites[j]
			if not b.actif:
				continue
			var d := b.position - a.position
			var l := d.length()
			var mini := RAYON_UNITE * (2.0 if a.equipe == b.equipe else 1.6)
			if l < mini and l > 0.01:
				var k := (mini - l) * 0.5
				if b.carte["type"] != "batiment":
					b.position += d / l * k
				a.position -= d / l * k


func _ballon(delta: float) -> void:
	var v: Vector2 = ballon["vel"]
	v *= exp(-PousseeRegles.BALLON_FROTTEMENT * delta)
	v = v.limit_length(PousseeRegles.BALLON_VITESSE_MAX)
	var p: Vector2 = ballon["pos"] + v * delta
	var r := PousseeRegles.BALLON_RAYON
	if p.y < TERRAIN.position.y + r or p.y > TERRAIN.end.y - r:
		v.y = -v.y * 0.7
		p.y = clampf(p.y, TERRAIN.position.y + r, TERRAIN.end.y - r)
	var b := PousseeRegles.but(p, TERRAIN)
	if b != 0:
		ballon["pos"] = p
		_finir(b, "BUUUUT !")
		return
	if absf(p.y - TERRAIN.get_center().y) > PousseeRegles.BUT_DEMI_HAUTEUR and (p.x < TERRAIN.position.x + r or p.x > TERRAIN.end.x - r):
		v.x = -v.x * 0.7
		p.x = clampf(p.x, TERRAIN.position.x + r, TERRAIN.end.x - r)
	ballon["vel"] = v
	ballon["pos"] = p
	ballon["rot"] = float(ballon.get("rot", 0.0)) + v.x * delta / r


# ------------------------------------------------------------------ IA

## L'adversaire (et ton camp en mode démo --auto) : défend quand le ballon
## ou des supporters entrent dans sa moitié, sinon attaque.
func _ia(e: int, delta: float) -> void:
	_ia_pense[e] -= delta
	if _ia_pense[e] > 0.0:
		return
	_ia_pense[e] = _rng.randf_range(0.6, 1.2)
	var s := _sens(e)
	var main: Array = piles[e].slice(0, PousseeRegles.TAILLE_MAIN)
	var cx := TERRAIN.get_center().x
	var b: Vector2 = ballon["pos"]
	var menace := (b.x - cx) * -s > 120.0
	var envahisseurs := unites.filter(func(u): return u.equipe != e and u.actif and (u.position.x - cx) * -s > 0.0)
	var urgence := menace or envahisseurs.size() > 0
	if ferveur[e] < (4.0 if urgence else 7.5):
		return
	var choix := -1
	var pos := Vector2.ZERO
	var x_min := cx - s * 30.0   # limite de sa moitié
	if menace:
		# défendre : un pousseur entre le ballon et son but
		for k in ["drapeau", "tambour", "chorale", "mascotte"]:
			if k in main and ferveur[e] >= float(PousseeRegles.CARTES[k]["cout"]):
				choix = main.find(k)
				pos = Vector2(b.x - s * 70.0, b.y)
				break
	if choix < 0 and envahisseurs.size() > 0:
		var cible: Unite = envahisseurs[0]
		for k in ["canon", "serpentins", "chorale", "fumigene", "tambour"]:
			if k in main and ferveur[e] >= float(PousseeRegles.CARTES[k]["cout"]):
				choix = main.find(k)
				pos = cible.position if PousseeRegles.CARTES[k]["type"] == "effet" else Vector2(cible.position.x - s * 160.0, cible.position.y)
				break
	if choix < 0:
		# attaquer : une carte au hasard, derrière le ballon ou devant sa tribune
		var jouables: Array = []
		for i in main.size():
			if ferveur[e] >= float(PousseeRegles.CARTES[main[i]]["cout"]) and PousseeRegles.CARTES[main[i]]["type"] != "effet":
				jouables.append(i)
		if jouables.is_empty():
			return
		choix = jouables[_rng.randi_range(0, jouables.size() - 1)]
		var k: String = main[choix]
		if PousseeRegles.CARTES[k]["poussee"] >= 0.8 and (b.x - cx) * s < 200.0:
			pos = Vector2(b.x - s * 60.0, b.y + _rng.randf_range(-40, 40))
		else:
			var bord := TERRAIN.position.x + 60.0 if e == 0 else TERRAIN.end.x - 60.0
			pos = Vector2(_rng.randf_range(minf(bord, cx - s * 300.0), maxf(bord, cx - s * 300.0)), _rng.randf_range(TERRAIN.position.y + 60, TERRAIN.end.y - 60))
	# ramener la position dans sa moitié
	if PousseeRegles.CARTES[main[choix]]["type"] != "effet":
		pos.x = minf(pos.x, x_min) if e == 0 else maxf(pos.x, x_min)
	if zone_permise(e, main[choix], pos):
		if e == 0:
			_jouer(choix, pos)
		else:
			poser(e, choix, pos)


# ------------------------------------------------------------------ en ligne

const RAISONS_CODE := {"BUUUUT !": "but", "TRIBUNE CONQUISE !": "tribune", "ILS ONT CONQUIS TA TRIBUNE…": "tribune",
	"FIN DU TEMPS !": "temps", "L'ADVERSAIRE EST PARTI !": "forfait"}


func _preparer_en_ligne() -> void:
	Reseau.message.connect(_sur_message)
	Reseau.adversaire_parti.connect(_sur_adversaire_parti)
	annoncer(tr("En attente de %s…") % Reseau.adversaire.get("nom", tr("l'adversaire")), Ui.BLANC)
	Reseau.envoyer(Protocole.msg("pret"))


func _sur_message(m: Dictionary) -> void:
	match m["t"]:
		"pret":
			_adv_pret = true
			if _invite:
				Reseau.envoyer(Protocole.msg("pret"))  # l'hôte est arrivé après : on le redit
			elif not _depart_envoye:
				_depart_envoye = true
				Reseau.envoyer(Protocole.msg("depart"))
				_compte_a_rebours()
		"depart":
			if _invite and not _depart_envoye:
				_depart_envoye = true
				_compte_a_rebours()
		"carte":
			# hôte : carte de l'invité, position dans SA vue (retournée)
			if not _invite and en_cours and not termine:
				var pos := Vector2(Protocole.miroir_x(float(m["x"]), TERRAIN), float(m["y"]))
				var i := int(m["i"])
				if i < piles[1].size() and zone_permise(1, piles[1][i], pos):
					poser(1, i, pos)
		"instant":
			if _invite and not termine:
				_appliquer(m)
		"fin_p":
			if _invite:
				var res := -int(m["res"])
				var textes := {"but": "BUUUUT !", "temps": "FIN DU TEMPS !", "forfait": "L'ADVERSAIRE EST PARTI !",
					"tribune": "TRIBUNE CONQUISE !" if res > 0 else "ILS ONT CONQUIS TA TRIBUNE…"}
				if m["r"] == "tribune":
					tribune[1 if res > 0 else 0] = 0.0  # le dernier instantané a pu partir juste avant
				en_cours = true
				_finir(res, textes[m["r"]])


func _sur_adversaire_parti() -> void:
	if termine:
		return
	if not en_cours:
		Game.aller(Game.SCENE_SALON, Game.params)
		return
	_finir(1, "L'ADVERSAIRE EST PARTI !")


## Hôte : tout ce que l'invité doit afficher (20 fois par seconde).
func _instant() -> Dictionary:
	var us: Array = []
	for u in unites:
		if u.actif:
			us.append([u.uid, u.cle, u.equipe, snappedf(u.position.x, 0.1), snappedf(u.position.y, 0.1),
				snappedf(clampf(u.pv / float(u.carte["pv"]), 0.0, 1.0), 0.01), u.chants, u.coups])
	var zs: Array = []
	for z in zones:
		zs.append([z["pos"].x, z["pos"].y, z["type"], z["equipe"], snappedf(z["reste"], 0.1)])
	var b: Vector2 = ballon["pos"]
	return Protocole.msg("instant", {"tps": temps, "f": [ferveur[0], ferveur[1]], "tr": [tribune[0], tribune[1]],
		"b": [b.x, b.y, float(ballon.get("rot", 0.0))], "m": piles[1].slice(0, PousseeRegles.TAILLE_MAIN + 1), "z": zs, "u": us})


## Invité : on retourne l'instantané (l'hôte devient l'équipe 1, à droite).
func _appliquer(m: Dictionary) -> void:
	temps = float(m["tps"])
	var f0 := int(ferveur[0])
	ferveur = [float(m["f"][1]), float(m["f"][0])]
	tribune = [float(m["tr"][1]), float(m["tr"][0])]
	_ballon_cible = Vector2(Protocole.miroir_x(float(m["b"][0]), TERRAIN), float(m["b"][1]))
	ballon["rot"] = -float(m["b"][2])
	if m["m"] != piles[0] or int(ferveur[0]) != f0:
		piles[0] = m["m"]
		if selection >= mini(piles[0].size(), PousseeRegles.TAILLE_MAIN):
			selection = -1
		_maj_main()
	zones = []
	for z in m["z"]:
		var c: Dictionary = PousseeRegles.CARTES[z[2]]
		zones.append({"pos": Vector2(Protocole.miroir_x(float(z[0]), TERRAIN), float(z[1])), "rayon": c.get("rayon", 100.0),
			"type": z[2], "equipe": 1 - int(z[3]), "reste": float(z[4]), "duree": c.get("duree", 1.0)})
	var vus := {}
	for d in m["u"]:
		var uid := int(d[0])
		var e := 1 - int(d[2])
		var pos := Vector2(Protocole.miroir_x(float(d[3]), TERRAIN), float(d[4]))
		vus[uid] = true
		var u: Unite = _par_id.get(uid)
		if u == null:
			u = _creer_unite(uid, e, str(d[1]), pos)
			_par_id[uid] = u
		u.cible = pos
		u.pv = float(d[5]) * float(u.carte["pv"])
		if int(d[6]) > u.chants:
			u.chanter()
			u.chants = int(d[6])
		if int(d[7]) > u.coups:
			u.secouer()
			u.coups = int(d[7])
	for uid in _par_id.keys():
		if not vus.has(uid):
			var u: Unite = _par_id[uid]
			_par_id.erase(uid)
			if is_instance_valid(u):
				u.s_asseoir()


## Invité : les unités et le ballon glissent vers les positions de l'hôte.
func _suivre_hote(delta: float) -> void:
	var k := minf(1.0, delta * 14.0)
	for u in unites:
		if u.actif:
			var v: Vector2 = (u.cible - u.position) * k
			u.avancer(v, v.length() > 0.4)
	ballon["pos"] = (ballon["pos"] as Vector2).lerp(_ballon_cible, k)
	if _auto:
		_ia(0, delta)


# ------------------------------------------------------------------ effets

func _pluie(pos: Vector2, couleur: Color, n: int) -> void:
	var cols := [couleur, Ui.JAUNE, Ui.BLANC, Ui.ROSE, Ui.VERT]
	for i in n:
		confettis.append({"pos": pos, "vel": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(60, 300) + Vector2(0, -120),
			"col": cols[i % cols.size()], "vie": _rng.randf_range(0.5, 1.1), "rot": _rng.randf() * TAU})


func texte(pos: Vector2, t: String, couleur: Color) -> void:
	textes.append({"pos": pos, "texte": t, "col": couleur, "vie": 1.2})


func _animer_effets(delta: float) -> void:
	for c in confettis:
		c["vel"] += Vector2(0, 420) * delta
		c["vel"] *= exp(-delta * 1.5)
		c["pos"] += c["vel"] * delta
		c["vie"] -= delta
		c["rot"] += delta * 8.0
	confettis = confettis.filter(func(c): return c["vie"] > 0.0)
	for t in textes:
		t["pos"] += Vector2(0, -50) * delta
		t["vie"] -= delta
	textes = textes.filter(func(t): return t["vie"] > 0.0)
	for n in notes:
		n["t"] += delta * 4.0
	notes = notes.filter(func(n): return n["t"] < 1.0)


# ------------------------------------------------------------------ fin

func _finir(res: int, pourquoi: String) -> void:
	if termine:
		return
	termine = true
	vainqueur = res
	raison = pourquoi
	if en_ligne and not _invite:
		Reseau.envoyer(Protocole.msg("fin_p", {"res": res, "r": RAISONS_CODE.get(pourquoi, "temps")}))
	selection = -1
	var gagne := res > 0
	annoncer(pourquoi, Ui.JAUNE if gagne else (Ui.BLANC if res == 0 else Ui.ROSE))
	for u in unites:
		if u.actif:
			u.fin(u.equipe == 0 and gagne or u.equipe == 1 and res < 0)
	for i in 8 if gagne else 2:
		_pluie(Vector2(_rng.randf_range(300, 1600), _rng.randf_range(200, 600)), couleurs[0 if gagne else 1], 40)
	var perf := PousseeRegles.performance(gagne, maxf(tribune[1], 0.0), posees[0])
	print("Poussée : %s (%s) à %.0f s, tribunes %d/%d, cartes %d/%d" % [["défaite", "égalité", "victoire"][res + 1], pourquoi, temps, tribune[0], tribune[1], posees[0], posees[1]])
	var g := FinDuel.enregistrer(gagne, perf, fiche, camp, mode_suivi)
	await get_tree().create_timer(2.0).timeout
	_lbl_annonce.text = ""
	var titre := "VICTOIRE !" if gagne else ("ÉGALITÉ !" if res == 0 else "PERDU DE PEU…")
	FinDuel.panneau(self, titre, gagne, [
		["Comment", (pourquoi.substr(0, 1) + pourquoi.substr(1).to_lower()).trim_suffix(" !").trim_suffix("…")],
		["Ta tribune", "%d %%" % int(100.0 * maxf(tribune[0], 0.0) / PousseeRegles.TRIBUNE_PV)],
		["Tribune adverse", "%d %%" % int(100.0 * maxf(tribune[1], 0.0) / PousseeRegles.TRIBUNE_PV)],
		["Cartes jouées", str(posees[0])],
		["Bonus « ton équipe gagne vraiment »", "x1,3" if g["equipe_gagne"] else "non"],
		[Game.libelle_rejeu(g["part"]), "+%d" % g["jetons"]],
		["XP du fan club", "+%d" % g["xp"]],
		["XP du PASS", "+%d" % g["xp_pass"]],
	] + FinDuel.ligne_deplacement(g["mult_depl"], g["bonus_depl"]) + FinDuel.ligne_popularite(g) + FinDuel.lignes_evenement(g["evenement"]) + FinDuel.ligne_tournoi(g["tournoi"]) + FinDuel.ligne_ligue(g["ligue"]), Game.SCENE_SALON if en_ligne and Reseau.connecte() else Game.SCENE_POUSSEE)


# ================================================================== classes

## Un supporter posé sur le terrain (ou un canon à confettis).
class Unite extends Node2D:
	var jeu
	var uid := 0
	var cible := Vector2.ZERO     # invité : position donnée par l'hôte
	var chants := 0               # compteurs envoyés à l'invité pour rejouer les animations
	var coups := 0
	var equipe := 0
	var cle := ""
	var carte: Dictionary
	var pv := 100.0
	var recharge := 0.0
	var actif := true
	var couleur := Ui.BLEU
	var corps: FanzzyAnime
	var _secousse := 0.0
	var _action := &""

	func creer(id: String) -> void:
		if carte["type"] == "batiment":
			return
		corps = FanzzyAnime.creer(id)
		corps.couleurs_echarpe = PackedColorArray([couleur, Ui.BLANC])
		add_child(corps)
		var h := corps._rect.size.y if corps._rect.size.y > 0.0 else 900.0
		var haut := HAUTEUR_UNITE * (1.8 if cle == "mascotte" else 1.0)
		corps.scale = Vector2.ONE * (haut / h)
		corps.cap = 1.0 if equipe == 0 else -1.0
		corps.couleur_trainee = couleur
		corps.jouer(&"lever_bras", 0.5)
		# arrivée sur le terrain : petit bond, poussière
		corps.rebondir(0.8)
		corps.trainee = 0.15

	func avancer(v: Vector2, bouge: bool) -> void:
		position += v
		if corps == null:
			return
		if absf(v.x) > 0.05:
			regarder(v.x)
		var a := &"courir" if bouge and float(carte["vitesse"]) >= 100.0 else (&"marcher" if bouge else &"")
		if a != &"" and corps.action != a and corps.action != &"chanter":
			corps.jouer(a)
		elif a == &"" and corps.action in [&"courir", &"marcher"]:
			corps.jouer(&"repos")
		_secousse = maxf(_secousse - 0.016, 0.0)
		corps.position.x = sin(_secousse * 60.0) * 5.0 * _secousse * 5.0
		queue_redraw()

	func regarder(dx: float) -> void:
		if corps and absf(dx) > 0.01:
			corps.cap = signf(dx)

	func chanter() -> void:
		chants += 1
		if corps:
			corps.jouer(&"lancer" if float(carte["portee"]) > 100.0 else &"chanter", 0.45)
		else:
			queue_redraw()

	func secouer() -> void:
		coups += 1
		_secousse = 0.2
		if corps:
			corps.impact(Vector2.INF, 0.7)

	func s_asseoir() -> void:
		if not actif:
			return
		actif = false
		jeu.texte(position + Vector2(0, -110), "va s'asseoir", Ui.GRIS)
		if corps:
			corps.impact(Vector2.INF, 1.3)
			corps.jouer(&"depit")
			corps.etourdir(0.9)
		var tw := create_tween()
		tw.tween_interval(0.5)
		tw.tween_property(self, "modulate:a", 0.0, 0.5)
		tw.tween_callback(func():
			jeu.unites.erase(self)
			queue_free())

	func fin(victoire: bool) -> void:
		if corps:
			corps.jouer(&"celebrer" if victoire else &"depit", 30.0)

	func _draw() -> void:
		if not actif:
			return
		var c := couleur
		if carte["type"] == "batiment":
			# canon à confettis : socle + tube orienté vers l'adversaire
			var s := 1.0 if equipe == 0 else -1.0
			draw_circle(Vector2(0, 6), 34, Color(0, 0, 0, 0.25))
			draw_rect(Rect2(-30, -30, 60, 36), Ui.CONTOUR)
			draw_rect(Rect2(-26, -26, 52, 28), c)
			var tube := PackedVector2Array([Vector2(-8 * s, -24), Vector2(46 * s, -52), Vector2(54 * s, -36), Vector2(4 * s, -8)])
			draw_colored_polygon(tube, Ui.CONTOUR)
			draw_circle(Vector2(50 * s, -44), 10, Ui.JAUNE)
			var vie: float = clampf(pv / float(carte["pv"]), 0.0, 1.0)
			draw_rect(Rect2(-30, -70, 60, 9), Ui.CONTOUR)
			draw_rect(Rect2(-28, -68, 56 * vie, 5), Ui.VERT if equipe == 0 else Ui.ROSE)
			return
		draw_arc(Vector2(0, 2), 24 if cle != "mascotte" else 40, 0, TAU, 32, c.darkened(0.3), 6)
		draw_arc(Vector2(0, 2), 24 if cle != "mascotte" else 40, 0, TAU, 32, c, 3)
		var hh := HAUTEUR_UNITE * (1.8 if cle == "mascotte" else 1.0)
		var vie2: float = clampf(pv / float(carte["pv"]), 0.0, 1.0)
		draw_rect(Rect2(-24, -hh - 18, 48, 9), Ui.CONTOUR)
		draw_rect(Rect2(-22, -hh - 16, 44 * vie2, 5), Ui.VERT if equipe == 0 else Ui.ROSE)


## Le terrain : pelouse, buts, tribunes (qui changent de couleur quand on les
## conquiert), zones de placement, effets au sol.
class Sol extends Node2D:
	var jeu

	func _draw() -> void:
		var t: Rect2 = TERRAIN
		var cy := t.get_center().y
		var ms := Time.get_ticks_msec() / 1000.0
		# tribunes derrière chaque but
		for e in 2:
			var r := Rect2(10, t.position.y - 30, t.position.x - 30, t.size.y + 60) if e == 0 else Rect2(t.end.x + 20, t.position.y - 30, 1910 - t.end.x - 20, t.size.y + 60)
			draw_rect(r.grow(6), Ui.CONTOUR)
			draw_rect(r, Color("#3a3290"))
			var conquis: float = 1.0 - clampf(jeu.tribune[e] / PousseeRegles.TRIBUNE_PV, 0.0, 1.0)
			var n := 0
			for yy in range(int(r.position.y) + 18, int(r.end.y) - 8, 26):
				for xx in range(int(r.position.x) + 16, int(r.end.x) - 8, 26):
					n += 1
					var h := fposmod(sin(n * 12.9898) * 43758.5453, 1.0)
					var col: Color = jeu.couleurs[1 - e] if h < conquis else jeu.couleurs[e]
					var saut := absf(sin(ms * 6.0 + n)) * 4.0
					draw_circle(Vector2(xx, yy - saut), 9, col.darkened(0.15 * fposmod(h * 7.0, 1.0)))
		draw_rect(t.grow(10), Ui.CONTOUR)
		for i in 12:
			var bande := Rect2(t.position.x + i * t.size.x / 12.0, t.position.y, t.size.x / 12.0, t.size.y)
			draw_rect(bande, Color("#3fae5b") if i % 2 == 0 else Color("#38a052"))
		var blanc := Color(1, 1, 1, 0.75)
		draw_rect(t, blanc, false, 5)
		draw_line(Vector2(t.get_center().x, t.position.y), Vector2(t.get_center().x, t.end.y), blanc, 5)
		draw_arc(t.get_center(), 90, 0, TAU, 48, blanc, 5)
		# buts
		var bh := PousseeRegles.BUT_DEMI_HAUTEUR
		for e in 2:
			var x := t.position.x if e == 0 else t.end.x
			var s := -1.0 if e == 0 else 1.0
			var cage := Rect2(minf(x, x + s * 44), cy - bh, 44, bh * 2)
			draw_rect(cage, Color(1, 1, 1, 0.25))
			for k in 8:
				draw_line(Vector2(cage.position.x, cage.position.y + k * bh * 2 / 8.0), Vector2(cage.end.x, cage.position.y + k * bh * 2 / 8.0), Color(1, 1, 1, 0.35), 2)
			draw_line(Vector2(x, cy - bh), Vector2(x + s * 44, cy - bh), Ui.BLANC, 8)
			draw_line(Vector2(x, cy + bh), Vector2(x + s * 44, cy + bh), Ui.BLANC, 8)
			draw_line(Vector2(x + s * 44, cy - bh), Vector2(x + s * 44, cy + bh), Ui.BLANC, 6)
		# zone de placement quand une carte est choisie
		if jeu.selection >= 0 and not jeu.termine:
			var cle: String = jeu.piles[0][jeu.selection]
			if PousseeRegles.CARTES[cle]["type"] != "effet":
				draw_rect(Rect2(t.position, Vector2(t.size.x * 0.5 - 10, t.size.y)), Color(jeu.couleurs[0], 0.22 + 0.08 * sin(ms * 6.0)))
				draw_rect(Rect2(t.get_center().x + 10, t.position.y, t.size.x * 0.5 - 10, t.size.y), Color(0, 0, 0, 0.25))
			var souris: Vector2 = get_global_mouse_position()
			if t.has_point(souris):
				var rr: float = PousseeRegles.CARTES[cle].get("rayon", 34.0)
				draw_arc(souris, rr, 0, TAU, 40, Ui.JAUNE, 4)
		# fumigènes et olas
		for z in jeu.zones:
			var a: float = clampf(z["reste"], 0.0, 1.0)
			var col2: Color = Color("#c8c8d8") if z["type"] == "fumigene" else Ui.JAUNE
			if z["type"] == "fumigene":
				col2 = jeu.couleurs[z["equipe"]].lightened(0.5)
				for k in 7:
					var o: Vector2 = Vector2.from_angle(k * TAU / 7.0 + ms * 0.6) * z["rayon"] * 0.45
					draw_circle(z["pos"] + o, z["rayon"] * 0.55, Color(col2, 0.2 * a))
			else:
				var vague := fposmod(ms * 1.5, 1.0)
				draw_arc(z["pos"], z["rayon"] * vague, 0, TAU, 48, Color(col2, 0.8 * a * (1.0 - vague)), 10)
				draw_arc(z["pos"], z["rayon"], 0, TAU, 48, Color(col2, 0.6 * a), 5)


## Le ballon, rangé avec les supporters (il passe devant ou derrière eux).
class Ballon extends Node2D:
	var jeu

	func _process(_delta: float) -> void:
		position = jeu.ballon["pos"]
		queue_redraw()

	func _draw() -> void:
		var b := Vector2.ZERO
		var r := PousseeRegles.BALLON_RAYON
		draw_circle(b + Vector2(4, 8), r, Color(0, 0, 0, 0.3))
		draw_circle(b, r + 3, Ui.CONTOUR)
		draw_circle(b, r, Ui.BLANC)
		var rot: float = jeu.ballon.get("rot", 0.0)
		for k in 5:
			draw_circle(b + Vector2.from_angle(rot + k * TAU / 5.0) * r * 0.55, r * 0.22, Ui.CONTOUR)
		draw_circle(b, r * 0.25, Ui.CONTOUR)


## Par-dessus : notes de chant, confettis, textes.
class Ciel extends Node2D:
	var jeu

	func _draw() -> void:
		var f := Ui.police_titre()
		for n in jeu.notes:
			var p: Vector2 = (n["de"] as Vector2).lerp(n["a"], n["t"]) + Vector2(0, -sin(n["t"] * PI) * 40.0)
			draw_circle(p, 10, Ui.CONTOUR)
			draw_circle(p, 7, n["col"])
			draw_line(p + Vector2(7, 0), p + Vector2(7, -22), Ui.CONTOUR, 4)
		for c in jeu.confettis:
			var p: Vector2 = c["pos"]
			var x := Vector2.from_angle(c["rot"]) * 6
			draw_line(p - x, p + x, Color(c["col"], clampf(c["vie"] * 2.0, 0.0, 1.0)), 6)
		for t in jeu.textes:
			var al: float = clampf(t["vie"], 0.0, 1.0)
			var w := f.get_string_size(t["texte"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28).x
			draw_string_outline(f, t["pos"] - Vector2(w * 0.5, 0), t["texte"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, 8, Color(Ui.CONTOUR, al))
			draw_string(f, t["pos"] - Vector2(w * 0.5, 0), t["texte"], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(t["col"], al))


## Barre d'entrain d'une tribune (0..1).
class Arene_Barre extends Control:
	var valeur := 1.0
	var couleur := Ui.BLEU
	var inverse := false

	func _draw() -> void:
		draw_style_box(Ui.boite(Ui.NUIT, 14, 4, 0), Rect2(Vector2.ZERO, size))
		var w := (size.x - 12) * clampf(valeur, 0.0, 1.0)
		var x := 6.0 if not inverse else size.x - 6 - w
		if w > 1.0:
			draw_rect(Rect2(x, 6, w, size.y - 12), couleur)
			draw_rect(Rect2(x, 6, w, (size.y - 12) * 0.35), Color(1, 1, 1, 0.25))


## Ferveur : 10 cases qui se remplissent.
class BarreFerveur extends Control:
	var valeur := 0.0

	func _draw() -> void:
		draw_style_box(Ui.boite(Ui.NUIT, 14, 4, 0), Rect2(Vector2.ZERO, size))
		var n := int(PousseeRegles.FERVEUR_MAX)
		var w := (size.x - 60) / n
		for i in n:
			var r := Rect2(54 + i * w, 6, w - 4, size.y - 12)
			var plein := clampf(valeur - i, 0.0, 1.0)
			draw_rect(r, Ui.NUIT_CLAIR)
			if plein > 0.0:
				draw_rect(Rect2(r.position, Vector2(r.size.x * plein, r.size.y)), Ui.ROSE if plein >= 1.0 else Ui.ROSE.darkened(0.4))
		var f := Ui.police_titre()
		draw_string(f, Vector2(14, size.y - 8), str(int(valeur)), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Ui.JAUNE)
