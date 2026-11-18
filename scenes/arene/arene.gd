extends Control
## Mode Arène : 3 FANZZY contre 3, vue de dessus, 2 minutes.
##   Déplacement : ZQSD / WASD ou flèches · Viser : souris
##   Clic gauche : lancer un ballon de confettis (3 en réserve)
##   Clic droit ou E : super de la famille (se charge en touchant)
##   ESPACE : roulade (niveau 3) · maintenir le clic : tir chargé (niveau 5)
##   TAB : changer de FANZZY
## Sur téléphone : joystick à gauche, boutons Tir / Super / Roulade / Changer à
## droite (visée automatique sur l'adversaire le plus proche), ou toucher le
## terrain pour tirer à cet endroit.
## Tenir le mégaphone au centre remplit ta banderole. 100 % = victoire.
## Règles chiffrées : scripts/duel/arene_regles.gd.

const TERRAIN := Rect2(160, 150, 1600, 860)
const OBSTACLES := [
	Rect2(560, 300, 90, 180), Rect2(560, 690, 90, 180),
	Rect2(1270, 300, 90, 180), Rect2(1270, 690, 90, 180),
	Rect2(880, 190, 160, 64), Rect2(880, 916, 160, 64),
]
const RAYON := 30.0
const HAUTEUR_FANZZY := 135.0

var fiche: Dictionary
var _ecran := 0.0 # secousse de l'écran en cours
var _ecran_decal := Vector2.ZERO
var camp := "home"
var mode_suivi := "stade"
var actions: Array = []

var temps := 0.0
var en_cours := false
var termine := false
var banderole := [0.0, 0.0]
var touches := [0, 0]
var nettoyes := [0, 0]    # alliés soignés par l'écharpe
var couleurs := [Ui.BLEU, Ui.ROUGE]
var noms := ["", ""]

var joueurs: Array = []     # Joueur
var controle: Joueur
var ballons: Array = []     # {pos, vel, equipe, degat, rayon, reste, tireur}
var murs: Array = []        # {a, b, equipe, reste}  (grand tifo)
var nuages: Array = []      # {pos, rayon, equipe, reste}  (fumigène)
var ondes: Array = []       # {pos, dir, rayon, reste, type, equipe}
var confettis: Array = []   # {pos, vel, col, vie}
var textes: Array = []      # {pos, texte, col, vie}

var _monde: Node2D
var _sol: Sol
var _ciel: Ciel
var _lbl_temps: Label
var _lbl_aide: Label
var _lbl_annonce: Label
var _hud_bas: HudBas
var _barres: Array = []
var _appui_tir := -1.0
var _auto := false             # démo : ton FANZZY joue tout seul
var _rng := RandomNumberGenerator.new()
var _tactile: CommandesTactiles  # téléphone seulement
var niveaux_ia := [IaNiveau.PAR_DEFAUT, IaNiveau.PAR_DEFAUT]  # ton équipe (coéquipiers, démo --auto), l'adversaire

# --- en ligne : l'hôte simule tout (équipe 0 chez lui), l'invité dirige un FANZZY de
# l'équipe 1. L'invité voit le terrain retourné : ses FANZZY sont à gauche (équipe 0 chez lui).
var en_ligne := false
var _invite := false
var _ctl_adv: Joueur            # hôte : le FANZZY dirigé par l'invité
var _actions_adv: Array = []    # hôte : actions débloquées de l'invité (son niveau)
var _ack := 0                   # hôte : dernière commande reçue
var _num := 0                   # invité : numéro de sa dernière commande
var _en_vol: Array = []         # invité : [numéro, déplacement] pas encore confirmés
var _t_reseau := 0.0
var _depart_envoye := false
var _attente_fin := false
var _cibles: Array = []         # invité : position donnée par l'hôte, pour chaque FANZZY


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
	actions = AreneRegles.actions_debloquees(Game.niveau())
	if not en_ligne:
		niveaux_ia = p.get("ia", [IaNiveau.moi(), IaNiveau.adversaire()])
	_rng.seed = hash(str(fiche["id"]))
	var dom: Dictionary = fiche["dom"]
	var ext: Dictionary = fiche["ext"]
	var nous: Dictionary = dom if camp == "home" else ext
	var eux: Dictionary = ext if camp == "home" else dom
	couleurs[0] = Duel._vive(nous["c1"], nous["c2"], Ui.BLEU)
	couleurs[1] = Duel._vive(eux["c1"], eux["c2"], Ui.ROUGE)
	couleurs[1] = Ui.couleur_distincte(couleurs[0], couleurs[1])
	noms[0] = Game.fan_club_nom
	noms[1] = str(Reseau.adversaire.get("nom", "?")) if en_ligne else FinDuel.nom_adverse(fiche["m"], str(eux["nom"]))
	if en_ligne:
		_actions_adv = AreneRegles.actions_debloquees(int(Reseau.adversaire.get("niveau", 1)))
	_construire()
	if en_ligne:
		_preparer_en_ligne()
	else:
		_compte_a_rebours()


# ------------------------------------------------------------------ construction

func _construire() -> void:
	# l'écran entier laisse passer les clics jusqu'à _unhandled_input (tir, super)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fond := ColorRect.new()
	fond.color = Color("#1b5e3a")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)
	_sol = Sol.new()
	_sol.arene = self
	add_child(_sol)
	_monde = Node2D.new()
	_monde.y_sort_enabled = true
	add_child(_monde)
	_ciel = Ciel.new()
	_ciel.arene = self
	add_child(_ciel)

	var adverses := _equipe_adverse()
	var skins_adv: Array = adverses.duplicate()
	if en_ligne:
		# les vrais FANZZY de l'adversaire (et leurs skins)
		var ids: Array = Reseau.adversaire.get("ids", [])
		var sk: Array = Reseau.adversaire.get("equipe", [])
		for i in 3:
			if i < ids.size() and not Game.fanzzy_par_id(str(ids[i])).is_empty():
				adverses[i] = str(ids[i])
				skins_adv[i] = str(sk[i]) if i < sk.size() and not str(sk[i]).is_empty() else adverses[i]
	for e in 2:
		for i in 3:
			var id: String = str(Game.equipe[i]) if e == 0 else adverses[i]
			var j := Joueur.new()
			j.arene = self
			j.equipe = e
			j.z = Game.fanzzy_par_id(id)
			j.famille = str(j.z.get("famille", "voix"))
			j.spawn = Vector2(TERRAIN.position.x + 110 if e == 0 else TERRAIN.end.x - 110, 380 + i * 210)
			j.position = j.spawn
			j.couleur = couleurs[e]
			j.creer_corps(Game.skin_de(id) if e == 0 else skins_adv[i])
			_monde.add_child(j)
			joueurs.append(j)
	controle = joueurs[0]
	if en_ligne:
		_ctl_adv = joueurs[3]
		for j in joueurs:
			_cibles.append(j.position)

	# HUD du haut : deux banderoles et le chrono
	var haut := Ui.hbox(18)
	haut.set_anchors_preset(Control.PRESET_CENTER_TOP)
	haut.offset_left = -820
	haut.offset_right = 820
	haut.offset_top = 16
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
		var b := Barre.new()
		b.couleur = couleurs[e]
		b.inverse = e == 1
		b.custom_minimum_size = Vector2(600, 34)
		v.add_child(b)
		_barres.append(b)
		haut.add_child(v)
		if e == 0:
			var c := Ui.vbox(0)
			c.add_child(Ui.label("ARÈNE", 26, Ui.JAUNE, true, 8))
			_lbl_temps = Ui.label("2:00", 44, Ui.BLANC, true, 10)
			_lbl_temps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			c.add_child(_lbl_temps)
			haut.add_child(c)

	_hud_bas = HudBas.new()
	_hud_bas.arene = self
	_hud_bas.position = Vector2(30, 1080 - 64)
	add_child(_hud_bas)
	var aide := "ZQSD/flèches : bouger · clic : ballon · clic droit/E : super · TAB : changer"
	if "roulade" in actions:
		aide += tr(" · ESPACE : roulade")
	if "tir_charge" in actions:
		aide += tr(" · maintenir le clic : tir chargé")
	_lbl_aide = Ui.label(aide, 18, Ui.BLANC, false, 6)
	_lbl_aide.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_lbl_aide.offset_left = -1100
	_lbl_aide.offset_right = -24
	_lbl_aide.offset_top = -44
	_lbl_aide.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_lbl_aide)

	if Mobile.actif:
		_ajouter_commandes_tactiles()
		_lbl_aide.text = tr("Joystick : bouger · Tir : vise le plus proche · touche le terrain : tir visé")

	_lbl_annonce = Ui.label("", 90, Ui.JAUNE, true, 14)
	_lbl_annonce.set_anchors_preset(Control.PRESET_CENTER)
	_lbl_annonce.offset_left = -700
	_lbl_annonce.offset_right = 700
	_lbl_annonce.offset_top = -80
	_lbl_annonce.offset_bottom = 80
	_lbl_annonce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_annonce.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lbl_annonce.pivot_offset = Vector2(700, 80)
	add_child(_lbl_annonce)


## Trois FANZZY adverses, un par poste, différents des tiens.
func _equipe_adverse() -> Array:
	var res: Array = []
	for poste in Game.ORDRE_POSTES:
		var liste: Array = Game.fanzzy_pour_poste(poste).filter(func(z): return not z["id"] in Game.equipe)
		if liste.is_empty():
			liste = Game.fanzzy_pour_poste(poste)
		res.append(str(liste[_rng.randi_range(0, liste.size() - 1)]["id"]) if not liste.is_empty() else str(Game.equipe[0]))
	return res


func _compte_a_rebours() -> void:
	for t in ["3", "2", "1", "AU MÉGAPHONE !"]:
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


# ------------------------------------------------------------------ boucle

func _process(delta: float) -> void:
	_trembler_ecran(delta)
	_maj_commandes_tactiles()
	if not en_cours or termine:
		_animer_effets(delta)
		_sol.queue_redraw()
		_ciel.queue_redraw()
		return
	if _invite:
		_tour_invite(delta)
	else:
		temps += delta
		if not _auto:
			_commandes_joueur(delta)
		for j in joueurs:
			if (j != controle or _auto) and j != _ctl_adv and j.actif():
				_ia(j, delta)
			j.mettre_a_jour(delta)
		_ballons(delta)
		_effets_zone(delta)
		_megaphone(delta)
		if en_ligne:
			if not _ctl_adv.actif():
				var autre := _prochain(_ctl_adv)
				if autre:
					_ctl_adv = autre
			_t_reseau -= delta
			if _t_reseau <= 0.0:
				_t_reseau = 0.05
				Reseau.envoyer_vite(_instant())
	_animer_effets(delta)
	var reste := maxf(AreneRegles.DUREE - temps, 0.0)
	_lbl_temps.text = "%d:%02d" % [int(reste) / 60, int(reste) % 60]
	_lbl_temps.add_theme_color_override("font_color", Ui.ROSE if reste < 15.0 else Ui.BLANC)
	for e in 2:
		_barres[e].valeur = banderole[e] / AreneRegles.BANDEROLE_MAX
		_barres[e].queue_redraw()
	_hud_bas.queue_redraw()
	_sol.queue_redraw()
	_ciel.queue_redraw()
	if _invite:
		if temps >= AreneRegles.DUREE or banderole[0] >= AreneRegles.BANDEROLE_MAX or banderole[1] >= AreneRegles.BANDEROLE_MAX:
			_attendre_fin()
	elif banderole[0] >= AreneRegles.BANDEROLE_MAX or banderole[1] >= AreneRegles.BANDEROLE_MAX or temps >= AreneRegles.DUREE:
		_finir()


func _commandes_joueur(_delta: float) -> void:
	if not controle.actif():
		var autre := _prochain_allie(controle)
		if autre:
			controle = autre
		return
	var d := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		d.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		d.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		d.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		d.y += 1
	if _tactile:
		d += _tactile.direction
		controle.direction = d.limit_length(1.0)
		controle.visee = cible_auto(controle)
		return
	controle.direction = d.normalized()
	controle.visee = get_global_mouse_position()


func _unhandled_input(ev: InputEvent) -> void:
	if not en_cours or termine:
		return
	if ev.is_action_pressed("ui_cancel"):
		if _tactile:
			_tactile.relacher_tout()
		FinDuel.pause(self, en_ligne)
		get_viewport().set_input_as_handled()
		return
	if _tactile and ev is InputEventMouse and ev.device == InputEvent.DEVICE_ID_EMULATION:
		return  # souris imitée par le doigt : déjà traité par les commandes tactiles
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if "tir_charge" in actions:
				if mb.pressed:
					_appui_tir = temps
				elif _appui_tir >= 0.0:
					tirer(controle, get_global_mouse_position(), temps - _appui_tir >= 0.6)
					_appui_tir = -1.0
			elif mb.pressed:
				tirer(controle, get_global_mouse_position(), false)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			super_geste(controle, get_global_mouse_position())
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		var k := ev as InputEventKey
		if k.physical_keycode == KEY_E:
			super_geste(controle, get_global_mouse_position())
		elif k.keycode == KEY_SPACE and "roulade" in actions:
			if _invite:
				_action_invite("roulade", controle.position)
			else:
				controle.rouler()
		elif k.keycode == KEY_TAB:
			var autre := _prochain_allie(controle)
			if autre:
				controle = autre
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ téléphone

func _ajouter_commandes_tactiles() -> void:
	_tactile = CommandesTactiles.new()
	_tactile.ajouter_bouton("tir", "Tir", Ui.JAUNE, Vector2(-110, -130), 100.0)
	_tactile.ajouter_bouton("super", "Super", Ui.ROSE, Vector2(-310, -80))
	if "roulade" in actions:
		_tactile.ajouter_bouton("roulade", "Roulade", Ui.VERT, Vector2(-130, -350))
	_tactile.ajouter_bouton("changer", "Changer", Ui.VIOLET, Vector2(-300, -260), 56.0)
	_tactile.appui.connect(_sur_appui_tactile)
	_tactile.relache.connect(_sur_relache_tactile)
	_tactile.toucher_libre.connect(func(p: Vector2):
		if en_cours and not termine:
			tirer(controle, p, false))
	add_child(_tactile)


func _sur_appui_tactile(id: String) -> void:
	if not en_cours or termine:
		return
	match id:
		"tir":
			if "tir_charge" in actions:
				_appui_tir = temps
			else:
				tirer(controle, cible_auto(controle), false)
		"super":
			super_geste(controle, cible_auto(controle))
		"roulade":
			if _invite:
				_action_invite("roulade", controle.position)
			else:
				controle.rouler()
		"changer":
			var autre := _prochain_allie(controle)
			if autre:
				controle = autre


func _sur_relache_tactile(id: String) -> void:
	if id == "tir" and _appui_tir >= 0.0:
		if en_cours and not termine:
			tirer(controle, cible_auto(controle), temps - _appui_tir >= 0.6)
		_appui_tir = -1.0


## Visée automatique : l'adversaire le plus proche (en vue de préférence),
## sinon droit devant.
func cible_auto(j: Joueur) -> Vector2:
	var meilleur := 1e9
	var cible := Vector2.INF
	for o in _adversaires(j):
		var d: float = j.position.distance_to(o.position)
		if not vue_libre(j.position, o.position):
			d += 400.0
		if d < meilleur:
			meilleur = d
			cible = o.position
	if cible == Vector2.INF:
		var devant := j.direction if j.direction != Vector2.ZERO else (Vector2.RIGHT if j.equipe == 0 else Vector2.LEFT)
		cible = j.position + devant * 300.0
	return cible


func _maj_commandes_tactiles() -> void:
	if not _tactile or not controle:
		return
	_tactile.regler_bouton("tir", controle.munitions >= 1.0, clampf(controle.munitions / float(AreneRegles.MUNITIONS), 0.0, 1.0))
	_tactile.regler_bouton("super", controle.charge_super >= 1.0, clampf(controle.charge_super, 0.0, 1.0))


func _prochain_allie(j: Joueur) -> Joueur:
	return _prochain(j, 0)


func _prochain(j: Joueur, equipe := -1) -> Joueur:
	var e := j.equipe if equipe < 0 else equipe
	var allies := joueurs.filter(func(x): return x.equipe == e and x.actif())
	if allies.is_empty():
		return null
	var i := allies.find(j)
	return allies[(i + 1) % allies.size()]


## L'appui de tir chargé en cours (pour le HUD), 0..1.
func charge_tir() -> float:
	return clampf((temps - _appui_tir) / 0.6, 0.0, 1.0) if _appui_tir >= 0.0 else 0.0


# ------------------------------------------------------------------ actions

func tirer(j: Joueur, cible: Vector2, charge: bool) -> void:
	if _invite:
		if j == controle:
			_action_invite("tir_charge" if charge else "tir", cible)
		return
	if not j.actif() or j.recharge > 0.0:
		return
	var cout := 2 if charge else 1
	if j.munitions < float(cout):
		charge = false
		cout = 1
		if j.munitions < 1.0:
			return
	j.munitions -= cout
	j.recharge = 0.28 if j.sprint > 0.0 else 0.4
	var dir := (cible - j.position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if j.equipe == 0 else Vector2.LEFT
	ballons.append({"pos": j.position + dir * 36 + Vector2(0, -40), "vel": dir * AreneRegles.VITESSE_BALLON * (0.85 if charge else 1.0),
		"equipe": j.equipe, "degat": AreneRegles.DEGAT_BALLON * (2.0 if charge else 1.0), "rayon": 22.0 if charge else 13.0,
		"reste": AreneRegles.PORTEE_BALLON, "tireur": j})
	j.lancer(dir.x)


func super_geste(j: Joueur, cible: Vector2) -> void:
	if _invite:
		if j == controle and j.charge_super >= 1.0:
			_action_invite("super", cible)
		return
	if not j.actif() or j.charge_super < 1.0:
		return
	j.charge_super = 0.0
	var dir := (cible - j.position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT if j.equipe == 0 else Vector2.LEFT
	var sup: Dictionary = AreneRegles.SUPERS.get(j.famille, AreneRegles.SUPERS["voix"])
	texte(j.position + Vector2(0, -170), sup["nom"].to_upper(), couleurs[j.equipe])
	j.celebrer_court()
	secouer_ecran(0.45)
	match j.famille:
		"voix":
			ondes.append({"pos": j.position, "dir": dir, "rayon": 0.0, "max": 400.0, "reste": 0.5, "type": "cone", "equipe": j.equipe})
			for o in _adversaires(j):
				var v: Vector2 = o.position - j.position
				if v.length() < 400.0 and absf(v.angle_to(dir)) < 0.6:
					o.pousser(v.normalized() * 300.0)
					toucher(o, 15.0, j)
		"perc":
			ondes.append({"pos": j.position, "dir": dir, "rayon": 0.0, "max": 230.0, "reste": 0.45, "type": "cercle", "equipe": j.equipe})
			for o in _adversaires(j):
				if o.position.distance_to(j.position) < 230.0:
					o.etourdi = 1.3
					toucher(o, 10.0, j)
		"tifo":
			var centre := j.position + dir * 110.0
			var n := dir.orthogonal() * 120.0
			murs.append({"a": centre - n, "b": centre + n, "equipe": j.equipe, "reste": 4.0})
		"fide":
			ondes.append({"pos": j.position, "dir": dir, "rayon": 0.0, "max": 320.0, "reste": 0.6, "type": "soin", "equipe": j.equipe})
			for a in joueurs:
				if a.equipe == j.equipe and a.actif() and a.position.distance_to(j.position) < 320.0:
					a.pv = minf(a.pv + 45.0, AreneRegles.PV)
					if a != j:
						nettoyes[j.equipe] += 1
					_pluie(a.position + Vector2(0, -60), Ui.BLANC, 14)
		"pyro":
			var pos := j.position + (cible - j.position).limit_length(450.0)
			nuages.append({"pos": pos, "rayon": 170.0, "equipe": j.equipe, "reste": 4.0})
		"depl":
			j.sprint = 3.0


func toucher(o: Joueur, degat: float, par: Joueur) -> void:
	if not o.actif() or o.invulnerable > 0.0:
		return
	o.pv -= degat
	touches[par.equipe] += 1
	par.charge_super = minf(par.charge_super + AreneRegles.CHARGE_SUPER_PAR_TOUCHE * degat / AreneRegles.DEGAT_BALLON, 1.0)
	_pluie(o.position + Vector2(0, -60), couleurs[par.equipe], 10)
	o.secouer(par.global_position)
	if o == controle or par == controle:
		secouer_ecran(0.25)
	if o.pv <= 0.0:
		o.aller_au_banc()
		secouer_ecran(0.7)
		texte(o.position + Vector2(0, -150), tr("PLEIN DE CONFETTIS !"), couleurs[par.equipe])
		_pluie(o.position + Vector2(0, -60), couleurs[par.equipe], 60)


func _adversaires(j: Joueur) -> Array:
	return joueurs.filter(func(o): return o.equipe != j.equipe and o.actif())


# ------------------------------------------------------------------ simulation

func _ballons(delta: float) -> void:
	var restants: Array = []
	for b in ballons:
		var pas: Vector2 = b["vel"] * delta
		var depart: Vector2 = b["pos"] + Vector2(0, 40)
		b["pos"] += pas
		b["reste"] -= pas.length()
		var sol: Vector2 = b["pos"] + Vector2(0, 40)
		var fini := false
		# test sur tout le trajet de l'image : un ballon rapide ne traverse personne
		for o in joueurs:
			if o.equipe != b["equipe"] and o.actif() and _distance_segment(o.position, depart, sol) < RAYON + b["rayon"]:
				toucher(o, b["degat"], b["tireur"])
				o.pousser((b["vel"] as Vector2).normalized() * 60.0)
				fini = true
				break
		if b["reste"] <= 0.0 or not TERRAIN.grow(20).has_point(b["pos"]):
			fini = true
		for r in OBSTACLES:
			if (r as Rect2).grow(b["rayon"] * 0.5).has_point(sol):
				fini = true
		for m in murs:
			if m["equipe"] != b["equipe"] and _distance_segment(sol, m["a"], m["b"]) < b["rayon"] + 10.0:
				fini = true
		if fini:
			_pluie(b["pos"], couleurs[b["equipe"]], 8)
		else:
			restants.append(b)
	ballons = restants


func _effets_zone(delta: float) -> void:
	for m in murs:
		m["reste"] -= delta
	murs = murs.filter(func(m): return m["reste"] > 0.0)
	for n in nuages:
		n["reste"] -= delta
		for o in joueurs:
			if o.equipe != n["equipe"] and o.actif() and o.position.distance_to(n["pos"]) < n["rayon"]:
				o.ralenti = 0.3
				o.pv -= 6.0 * delta
				if o.pv <= 0.0:
					o.aller_au_banc()
	nuages = nuages.filter(func(n): return n["reste"] > 0.0)
	for o in ondes:
		o["reste"] -= delta
		o["rayon"] = lerpf(float(o["rayon"]), float(o["max"]), 1.0 - exp(-delta * 9.0))
	ondes = ondes.filter(func(o): return o["reste"] > 0.0)


func _megaphone(delta: float) -> void:
	var dans := [0, 0]
	for j in joueurs:
		if j.actif() and j.position.distance_to(TERRAIN.get_center()) < AreneRegles.RAYON_MEGAPHONE:
			dans[j.equipe] += 1
	for e in 2:
		banderole[e] = AreneRegles.remplir(banderole[e], dans[e], dans[1 - e], delta)
	_sol.dispute = dans[0] > 0 and dans[1] > 0
	_sol.tenu = -1 if _sol.dispute or (dans[0] == 0 and dans[1] == 0) else (0 if dans[0] > 0 else 1)


## Déplacement avec collisions (bords du terrain et obstacles).
func deplacer(j: Joueur, v: Vector2) -> void:
	var p := j.position + v
	for r in OBSTACLES:
		p = _hors_rect(p, r, RAYON)
	for m in murs:
		var d := _distance_segment(p, m["a"], m["b"])
		if d < RAYON:
			var proche := Geometry2D.get_closest_point_to_segment(p, m["a"], m["b"])
			p = proche + (p - proche).normalized() * RAYON
	p.x = clampf(p.x, TERRAIN.position.x + RAYON, TERRAIN.end.x - RAYON)
	p.y = clampf(p.y, TERRAIN.position.y + RAYON + 30, TERRAIN.end.y - RAYON)
	j.position = p


static func _hors_rect(p: Vector2, r: Rect2, rayon: float) -> Vector2:
	var proche := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	var d := p - proche
	if d.length() >= rayon:
		return p
	if d == Vector2.ZERO:
		# au centre du rectangle : sortir par le côté le plus proche
		var c := r.get_center()
		var dx := (r.size.x * 0.5 - absf(p.x - c.x))
		var dy := (r.size.y * 0.5 - absf(p.y - c.y))
		if dx < dy:
			return Vector2(c.x + signf(p.x - c.x) * (r.size.x * 0.5 + rayon), p.y)
		return Vector2(p.x, c.y + signf(p.y - c.y) * (r.size.y * 0.5 + rayon))
	return proche + d.normalized() * rayon


static func _distance_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	return p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b))


func vue_libre(a: Vector2, b: Vector2) -> bool:
	for r in OBSTACLES:
		var rr: Rect2 = r
		var pts := [rr.position, Vector2(rr.end.x, rr.position.y), rr.end, Vector2(rr.position.x, rr.end.y)]
		for i in 4:
			if Geometry2D.segment_intersects_segment(a, b, pts[i], pts[(i + 1) % 4]) != null:
				return false
	return true


# ------------------------------------------------------------------ IA

## Un FANZZY dirigé par l'ordi, selon son niveau (IaNiveau). Facile : vise le
## plus proche, lentement et pas très juste. Normal et difficile : choisissent
## leur cible (affaiblie, au mégaphone, en vue), visent là où elle va, esquivent
## les ballons, se partagent le mégaphone et reculent pour souffler.
func _ia(j: Joueur, delta: float) -> void:
	j.pense -= delta
	var p := IaNiveau.params(str(niveaux_ia[j.equipe]))
	if not p["choix_cible"]:
		_ia_simple(j, p)
		return
	var centre := TERRAIN.get_center()
	var vers_centre := centre - j.position
	var adv := _adversaires(j)
	# --- la cible : proche, en vue, affaiblie, au mégaphone
	var cible: Joueur = null
	var meilleur := 1e9
	var d_cible := 1e9
	for o in adv:
		var d: float = j.position.distance_to(o.position)
		var note: float = d - (AreneRegles.PV - o.pv) * 2.5
		if not vue_libre(j.position, o.position):
			note += 350.0
		if o.position.distance_to(centre) < AreneRegles.RAYON_MEGAPHONE:
			note -= 140.0
		if o.invulnerable > 0.0:
			note += 300.0
		if note < meilleur:
			meilleur = note
			cible = o
			d_cible = d
	# --- le mégaphone : qui le tient, qui y va
	var dans := [0, 0]
	for x in joueurs:
		if x.actif() and x.position.distance_to(centre) < AreneRegles.RAYON_MEGAPHONE:
			dans[x.equipe] += 1
	var e := j.equipe
	var en_retard: bool = banderole[1 - e] > banderole[e] + 8.0
	var reste := AreneRegles.DUREE - temps
	# le coéquipier le plus près du centre en est le porteur ; les autres le couvrent
	var porteur := true
	for x in joueurs:
		if x != j and x.equipe == e and x.actif() and x.position.distance_to(centre) < j.position.distance_to(centre) - 20.0:
			porteur = false
	var poids_centre := 1.0 if porteur else 0.4
	if dans[1 - e] > 0 and dans[e] == 0:
		poids_centre += 0.5  # ils le tiennent seuls : aller le disputer
	if en_retard or reste < 20.0:
		poids_centre += 0.4
	var dir := Vector2.ZERO
	if cible and d_cible < 600.0:
		var v: Vector2 = cible.position - j.position
		var ideal := 320.0
		var fatigue := j.pv < 35.0 and not porteur
		if fatigue or j.munitions < 1.0:
			ideal = 520.0  # souffler un peu en attendant ses ballons
		dir = v.normalized() * clampf((v.length() - ideal) / 120.0, -1.0, 1.0)
		dir += v.normalized().orthogonal() * sin(temps * 1.6 + j.graine) * 0.8
		if vers_centre.length() > AreneRegles.RAYON_MEGAPHONE * (0.55 if porteur else 1.6):
			dir += vers_centre.normalized() * poids_centre
		var vue := vue_libre(j.position, cible.position)
		if not vue:
			dir += v.normalized().orthogonal() * (1.0 if sin(j.graine) > 0.0 else -1.0)
		# niveau difficile : ne pas gaspiller ses ballons sur une cible lointaine qui peut esquiver
		var bon_tir: bool = not p.get("economie", false) or d_cible < 430.0 or j.munitions >= AreneRegles.MUNITIONS - 0.2 \
			or cible.etourdi > 0.0 or cible.ralenti > 0.0 or cible.position.distance_to(centre) < AreneRegles.RAYON_MEGAPHONE
		if vue and bon_tir and j.pense <= 0.0 and d_cible < AreneRegles.PORTEE_BALLON * 0.9:
			var charge: bool = p["tir_charge"] and "tir_charge" in _actions_de(j) and j.munitions >= 2.0 \
				and (cible.etourdi > 0.0 or cible.ralenti > 0.0 or d_cible < 300.0)
			tirer(j, _viser(j, cible, p, charge), charge)
			j.pense = _rng.randf_range(p["reaction"][0], p["reaction"][1]) * (0.6 if j.munitions >= 2.0 else 1.0)
		if j.charge_super >= 1.0 and _super_malin(j, cible, d_cible):
			super_geste(j, _cible_super(j, cible))
	else:
		if vers_centre.length() > AreneRegles.RAYON_MEGAPHONE * (0.5 if porteur else 0.9):
			dir = vers_centre.normalized()
		else:
			dir = Vector2.from_angle(temps * 0.8 + j.graine) * 0.4
		if j.famille == "fide" and j.charge_super >= 1.0:
			for a in joueurs:
				if a.equipe == j.equipe and a.actif() and a.pv < 55.0 and a.position.distance_to(j.position) < 300.0:
					super_geste(j, a.position)
					break
	dir += _esquive(j, p) * 1.8
	j.direction = dir.limit_length(1.0)


## L'ancienne IA, gardée pour le niveau facile.
func _ia_simple(j: Joueur, p: Dictionary) -> void:
	var centre := TERRAIN.get_center()
	var cible: Joueur = null
	var meilleur := 1e9
	for o in _adversaires(j):
		var d: float = j.position.distance_to(o.position)
		if d < meilleur:
			meilleur = d
			cible = o
	var dir := Vector2.ZERO
	var vers_centre := centre - j.position
	if cible and meilleur < 560.0:
		var v: Vector2 = cible.position - j.position
		# garder une distance de tir, en tournant autour de la cible
		var ideal := 330.0 if j.pv > 40.0 else 480.0
		dir = v.normalized() * clampf((v.length() - ideal) / 120.0, -1.0, 1.0)
		dir += v.normalized().orthogonal() * sin(temps * 1.3 + j.graine) * 0.8
		# le mégaphone reste l'objectif
		if vers_centre.length() > AreneRegles.RAYON_MEGAPHONE * 0.7:
			dir += vers_centre.normalized() * 0.45
		var vue := vue_libre(j.position, cible.position)
		if not vue:
			dir += v.normalized().orthogonal() * 0.9
		if vue and j.pense <= 0.0 and meilleur < AreneRegles.PORTEE_BALLON * 0.9:
			tirer(j, _viser(j, cible, p, false), false)
			j.pense = _rng.randf_range(p["reaction"][0], p["reaction"][1])
		if j.charge_super >= 1.0 and _super_utile(j, cible, meilleur):
			super_geste(j, cible.position)
	else:
		if vers_centre.length() > AreneRegles.RAYON_MEGAPHONE * 0.5:
			dir = vers_centre.normalized()
		else:
			dir = Vector2.from_angle(temps * 0.8 + j.graine) * 0.4
		if j.famille == "fide" and j.charge_super >= 1.0:
			for a in joueurs:
				if a.equipe == j.equipe and a.actif() and a.pv < 55.0 and a.position.distance_to(j.position) < 300.0:
					super_geste(j, a.position)
					break
	j.direction = dir.limit_length(1.0)


## Actions débloquées du camp de j (en ligne, l'adversaire a les siennes).
func _actions_de(j: Joueur) -> Array:
	return _actions_adv if en_ligne and j.equipe == 1 else actions


## Où lancer pour toucher la cible qui bouge : là où elle sera quand le
## ballon arrivera (part « anticipe » du niveau), plus une petite erreur.
func _viser(j: Joueur, cible: Joueur, p: Dictionary, charge: bool) -> Vector2:
	var vb := AreneRegles.VITESSE_BALLON * (0.85 if charge else 1.0)
	var vc: Vector2 = cible.direction * AreneRegles.VITESSE * cible.vitesse_actuelle()
	var t := j.position.distance_to(cible.position) / vb
	for _k in 3:
		t = j.position.distance_to(cible.position + vc * t) / vb
	var pt: Vector2 = cible.position + vc * t * float(p["anticipe"])
	var err := float(p["erreur_tir"]) * clampf(j.position.distance_to(cible.position) / 450.0, 0.4, 1.4)
	return pt + Vector2(_rng.randf_range(-err, err), _rng.randf_range(-err, err))


## Un pas de côté (ou une roulade) devant un ballon qui arrive droit sur j.
## Chaque ballon n'est vu qu'une fois : le niveau dit la chance de l'esquiver.
func _esquive(j: Joueur, p: Dictionary) -> Vector2:
	if float(p["esquive"]) <= 0.0:
		return Vector2.ZERO
	var res := Vector2.ZERO
	for b in ballons:
		if b["equipe"] == j.equipe or not b.has("vel"):
			continue
		var v: Vector2 = b["vel"]
		var d: Vector2 = j.position - (b["pos"] + Vector2(0, 40))
		var t := clampf(d.dot(v) / maxf(v.length_squared(), 1.0), 0.0, 0.7)
		if t <= 0.0:
			continue
		var ecart := d - v * t
		if ecart.length() > RAYON + float(b["rayon"]) + 18.0:
			continue
		var vus: Dictionary = b.get("vu", {})
		b["vu"] = vus
		var id := j.get_instance_id()
		if not vus.has(id):
			vus[id] = _rng.randf() < float(p["esquive"])
		if not vus[id]:
			continue
		var cote := ecart.normalized() if ecart.length() > 1.0 else v.normalized().orthogonal()
		res += cote
		if p["roulade"] and "roulade" in _actions_de(j) and t < 0.22 and j.recharge_roulade <= 0.0:
			j.direction = cote
			j.rouler()
	return res.limit_length(1.0)


## Le super vaut-il le coup maintenant (niveaux normal et difficile) ?
func _super_malin(j: Joueur, cible: Joueur, d: float) -> bool:
	var adv := _adversaires(j)
	match j.famille:
		"voix":
			var dir := (cible.position - j.position).normalized()
			return adv.filter(func(o): var v: Vector2 = o.position - j.position; return v.length() < 380.0 and absf(v.angle_to(dir)) < 0.55).size() >= 1
		"perc":
			return adv.filter(func(o): return o.position.distance_to(j.position) < 210.0).size() >= 1
		"fide":
			var blesses := joueurs.filter(func(a): return a.equipe == j.equipe and a.actif() and a.pv < 60.0 and a.position.distance_to(j.position) < 320.0)
			return blesses.size() >= 2 or j.pv < 45.0
		"tifo":
			# un mur quand des ballons arrivent, ou pour garder le mégaphone
			var arrivent := ballons.filter(func(b): return b["equipe"] != j.equipe and (b["pos"] as Vector2).distance_to(j.position) < 450.0).size()
			return arrivent >= 1 or (d < 450.0 and j.position.distance_to(TERRAIN.get_center()) < AreneRegles.RAYON_MEGAPHONE * 1.5)
		"pyro":
			return d < 450.0 or _megaphone_adverse(j)
		_:
			return d < 520.0 or cible.position.distance_to(TERRAIN.get_center()) < AreneRegles.RAYON_MEGAPHONE


## Vers où lancer le super : le fumigène sur le mégaphone s'ils le tiennent.
func _cible_super(j: Joueur, cible: Joueur) -> Vector2:
	if j.famille == "pyro" and _megaphone_adverse(j):
		return TERRAIN.get_center()
	return cible.position


func _megaphone_adverse(j: Joueur) -> bool:
	for o in _adversaires(j):
		if o.position.distance_to(TERRAIN.get_center()) < AreneRegles.RAYON_MEGAPHONE:
			return true
	return false


func _super_utile(j: Joueur, cible: Joueur, d: float) -> bool:
	match j.famille:
		"voix":
			return d < 360.0
		"perc":
			return d < 200.0
		"fide":
			return j.pv < 55.0
		"tifo":
			return d < 500.0
		"pyro":
			return d < 450.0
		_:
			return d < 520.0 or cible.position.distance_to(TERRAIN.get_center()) < AreneRegles.RAYON_MEGAPHONE


# ------------------------------------------------------------------ en ligne

func _preparer_en_ligne() -> void:
	Reseau.message.connect(_sur_message)
	Reseau.adversaire_parti.connect(_sur_adversaire_parti)
	annoncer(tr("En attente de %s…") % Reseau.adversaire.get("nom", tr("l'adversaire")), Ui.BLANC)
	Reseau.envoyer(Protocole.msg("pret"))


func _mx(p: Vector2) -> Vector2:
	return Vector2(Protocole.miroir_x(p.x, TERRAIN), p.y)


func _sur_message(m: Dictionary) -> void:
	match m["t"]:
		"pret":
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
		"cmd":
			if not _invite:
				_ack = maxi(_ack, int(m["n"]))
				var c: Joueur = joueurs[3 + int(m["c"])]
				if c != _ctl_adv and c.actif():
					_ctl_adv.direction = Vector2.ZERO
					_ctl_adv = c
				_ctl_adv.direction = Vector2(-float(m["d"][0]), float(m["d"][1])).limit_length(1.0)
				_ctl_adv.visee = _mx(Vector2(float(m["v"][0]), float(m["v"][1])))
		"act":
			if not _invite and en_cours and not termine:
				var cible := _mx(Vector2(float(m["x"]), float(m["y"])))
				match m["a"]:
					"tir":
						tirer(_ctl_adv, cible, false)
					"tir_charge":
						tirer(_ctl_adv, cible, "tir_charge" in _actions_adv)
					"super":
						super_geste(_ctl_adv, cible)
					"roulade":
						if "roulade" in _actions_adv:
							_ctl_adv.rouler()
		"arene":
			if _invite and not termine:
				_appliquer(m)
		"fin_a":
			if _invite:
				banderole = [float(m["bd"][1]), float(m["bd"][0])]
				touches = [int(m["to"][1]), int(m["to"][0])]
				nettoyes = [int(m["ne"][1]), int(m["ne"][0])]
				_finir()


func _sur_adversaire_parti() -> void:
	if termine:
		return
	if not en_cours:
		Game.aller(Game.SCENE_SALON, Game.params)
		return
	annoncer("L'ADVERSAIRE EST PARTI !", Ui.JAUNE)
	# victoire par forfait : ta banderole est déclarée pleine
	banderole[0] = AreneRegles.BANDEROLE_MAX
	en_ligne = false
	_finir()


## Hôte : l'arène vue par l'invité (20 fois par seconde).
func _instant() -> Dictionary:
	var js: Array = []
	for j in joueurs:
		var drapeaux := (1 if j.banc > 0.0 else 0) + (2 if j.etourdi > 0.0 else 0) + (4 if j.invulnerable > 0.0 else 0) \
			+ (8 if j.ralenti > 0.0 else 0) + (16 if j.sprint > 0.0 else 0)
		js.append([snappedf(j.position.x, 0.1), snappedf(j.position.y, 0.1), snappedf(j.pv, 0.1), snappedf(j.munitions, 0.01),
			snappedf(j.charge_super, 0.01), drapeaux, j.lancers, j.coups, j.supers, snappedf(j.recharge_roulade, 0.1)])
	var bl: Array = []
	for b in ballons:
		bl.append([snappedf(b["pos"].x, 0.1), snappedf(b["pos"].y, 0.1), b["equipe"], b["rayon"]])
	var mu: Array = []
	for m in murs:
		mu.append([m["a"].x, m["a"].y, m["b"].x, m["b"].y, m["equipe"], m["reste"]])
	var nu: Array = []
	for n in nuages:
		nu.append([n["pos"].x, n["pos"].y, n["rayon"], n["equipe"], n["reste"]])
	var on: Array = []
	for o in ondes:
		on.append([o["pos"].x, o["pos"].y, o["dir"].x, o["dir"].y, o["rayon"], o["max"], o["type"], o["equipe"], o["reste"]])
	return Protocole.msg("arene", {"tps": temps, "bd": banderole, "to": touches, "ack": _ack, "ctl": joueurs.find(_ctl_adv) - 3,
		"j": js, "bl": bl, "mu": mu, "nu": nu, "on": on})


## Invité : on retourne l'instantané. Ses FANZZY (équipe 1 chez l'hôte) sont les n° 0 à 2 ici.
func _appliquer(m: Dictionary) -> void:
	temps = float(m["tps"])
	banderole = [float(m["bd"][1]), float(m["bd"][0])]
	touches = [int(m["to"][1]), int(m["to"][0])]
	for k in 6:
		var d: Array = m["j"][(k + 3) % 6]
		var j: Joueur = joueurs[k]
		_cibles[k] = _mx(Vector2(float(d[0]), float(d[1])))
		j.pv = float(d[2])
		j.munitions = float(d[3])
		j.charge_super = float(d[4])
		var f := int(d[5])
		var revient := j.banc > 0.0 and f & 1 == 0
		j.banc = 1.0 if f & 1 else 0.0
		j.etourdi = 1.0 if f & 2 else 0.0
		j.invulnerable = 1.0 if f & 4 else 0.0
		j.ralenti = 1.0 if f & 8 else 0.0
		j.sprint = 1.0 if f & 16 else 0.0
		j.recharge_roulade = float(d[9])
		if revient:
			j.position = _cibles[k]
		if int(d[6]) > j.lancers:
			j.lancer((_cibles[k] - j.position).x if j != controle else (j.visee - j.position).x)
			j.lancers = int(d[6])
		if int(d[7]) > j.coups:
			j.secouer()
			j.coups = int(d[7])
			_pluie(j.position + Vector2(0, -60), couleurs[1 - j.equipe], 10)
		if int(d[8]) > j.supers:
			j.celebrer_court()
			j.supers = int(d[8])
			texte(j.position + Vector2(0, -170), str(AreneRegles.SUPERS.get(j.famille, {}).get("nom", "")).to_upper(), couleurs[j.equipe])
	# le FANZZY dirigé : celui de l'hôte s'il a changé (le tien est au banc)
	var ctl := int(m["ctl"])
	if ctl >= 0 and ctl < 3 and not controle.actif() and joueurs[ctl] != controle:
		controle = joueurs[ctl]
		_en_vol.clear()
	ballons = []
	for b in m["bl"]:
		ballons.append({"pos": _mx(Vector2(float(b[0]), float(b[1]))), "equipe": 1 - int(b[2]), "rayon": float(b[3])})
	murs = []
	for x in m["mu"]:
		murs.append({"a": _mx(Vector2(float(x[0]), float(x[1]))), "b": _mx(Vector2(float(x[2]), float(x[3]))), "equipe": 1 - int(x[4]), "reste": float(x[5])})
	nuages = []
	for n in m["nu"]:
		nuages.append({"pos": _mx(Vector2(float(n[0]), float(n[1]))), "rayon": float(n[2]), "equipe": 1 - int(n[3]), "reste": float(n[4])})
	ondes = []
	for o in m["on"]:
		ondes.append({"pos": _mx(Vector2(float(o[0]), float(o[1]))), "dir": Vector2(-float(o[2]), float(o[3])), "rayon": float(o[4]),
			"max": float(o[5]), "type": o[6], "equipe": 1 - int(o[7]), "reste": float(o[8])})
	# ton FANZZY : la position de l'hôte + tes déplacements qu'il n'a pas encore reçus
	var ack := int(m["ack"])
	_en_vol = _en_vol.filter(func(g): return g[0] > ack)
	var i := joueurs.find(controle)
	var p: Vector2 = _cibles[i]
	for g in _en_vol:
		p += g[1]
	_cibles[i] = p


## Invité, à chaque image : commandes, prédiction de ton FANZZY, glissement des autres.
func _tour_invite(delta: float) -> void:
	if _auto:
		_ia(controle, delta)
	else:
		_commandes_joueur(delta)
	var pas := Vector2.ZERO
	if controle.actif():
		pas = controle.direction * AreneRegles.VITESSE * controle.vitesse_actuelle() * delta
		var avant := controle.position
		deplacer(controle, pas)
		pas = controle.position - avant
	# une commande par image, numérotée : l'hôte renvoie le numéro de la dernière reçue
	_num += 1
	_en_vol.append([_num, pas])
	if _en_vol.size() > 120:
		_en_vol.pop_front()
	Reseau.envoyer_vite(Protocole.msg("cmd", {"d": [controle.direction.x, controle.direction.y],
		"v": [controle.visee.x, controle.visee.y], "c": joueurs.find(controle), "n": _num}))
	var k := minf(1.0, delta * 12.0)
	for idx in joueurs.size():
		var j: Joueur = joueurs[idx]
		var avant := j.position
		if j == controle and j.actif():
			# petite correction vers la position confirmée + prédite
			j.position = j.position.lerp(_cibles[idx], minf(1.0, delta * 6.0))
			j.animer(delta, pas / maxf(delta, 0.001) / AreneRegles.VITESSE)
		else:
			j.position = j.position.lerp(_cibles[idx], k)
			j.animer(delta, (j.position - avant) / maxf(delta, 0.001) / AreneRegles.VITESSE)
	_megaphone_vu()


## Invité : le mégaphone change de couleur selon qui le tient (calculé à partir des positions).
func _megaphone_vu() -> void:
	var dans := [0, 0]
	for j in joueurs:
		if j.actif() and j.position.distance_to(TERRAIN.get_center()) < AreneRegles.RAYON_MEGAPHONE:
			dans[j.equipe] += 1
	_sol.dispute = dans[0] > 0 and dans[1] > 0
	_sol.tenu = -1 if _sol.dispute or (dans[0] == 0 and dans[1] == 0) else (0 if dans[0] > 0 else 1)


func _action_invite(a: String, cible: Vector2) -> void:
	if en_cours and not termine and controle.actif():
		Reseau.envoyer(Protocole.msg("act", {"a": a, "x": cible.x, "y": cible.y}))


## Invité : temps écoulé ou banderole pleine, on attend le résultat de l'hôte (3 s au plus).
func _attendre_fin() -> void:
	if _attente_fin or termine:
		return
	_attente_fin = true
	await get_tree().create_timer(3.0).timeout
	if not termine:
		_finir()


# ------------------------------------------------------------------ effets

func _pluie(pos: Vector2, couleur: Color, n: int) -> void:
	var cols := [couleur, Ui.JAUNE, Ui.BLANC, Ui.ROSE, Ui.VERT]
	for i in n:
		confettis.append({"pos": pos, "vel": Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(80, 340) + Vector2(0, -120),
			"col": cols[i % cols.size()], "vie": _rng.randf_range(0.5, 1.1), "rot": _rng.randf() * TAU})


## Secousse de l'écran (KO, super, coup reçu par ton FANZZY), 0..1.
func secouer_ecran(force: float) -> void:
	_ecran = maxf(_ecran, force)


func _trembler_ecran(delta: float) -> void:
	if _ecran <= 0.0 and _ecran_decal == Vector2.ZERO:
		return
	_ecran = maxf(_ecran - delta * 2.2, 0.0)
	var d := Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 16.0 * _ecran * _ecran
	position += d - _ecran_decal
	_ecran_decal = d


func texte(pos: Vector2, t: String, couleur: Color) -> void:
	textes.append({"pos": pos, "texte": t, "col": couleur, "vie": 1.3})


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


# ------------------------------------------------------------------ fin

func _finir() -> void:
	if termine:
		return
	termine = true
	ballons.clear()
	if en_ligne and not _invite:
		Reseau.envoyer(Protocole.msg("fin_a", {"bd": banderole, "to": touches, "ne": nettoyes}))
	var res := AreneRegles.resultat(banderole[0], banderole[1], touches[0], touches[1])
	var gagne := res > 0
	for j in joueurs:
		j.fin(j.equipe == 0 and gagne or j.equipe == 1 and res < 0)
	if gagne:
		for i in 6:
			_pluie(Vector2(_rng.randf_range(300, 1600), _rng.randf_range(200, 500)), couleurs[0], 50)
	var perf := AreneRegles.performance(banderole[0], touches[0], nettoyes[0])
	print("Arène : %s à %.0f s, banderoles %d/%d, touches %d/%d" % [["défaite", "égalité", "victoire"][res + 1], temps, banderole[0], banderole[1], touches[0], touches[1]])
	var g := FinDuel.enregistrer(gagne, perf, fiche, camp, mode_suivi, "arene")
	await get_tree().create_timer(1.6).timeout
	var titre := "VICTOIRE DANS L'ARÈNE !" if gagne else ("ÉGALITÉ !" if res == 0 else "L'ARÈNE EST À EUX…")
	FinDuel.panneau(self, titre, gagne, [
		["Ta banderole", "%d %%" % int(banderole[0])],
		["Banderole adverse", "%d %%" % int(banderole[1])],
		["Ballons qui ont touché", str(touches[0])],
		["Alliés nettoyés", str(nettoyes[0])],
		["Bonus « ton équipe gagne vraiment »", "x1,3" if g["equipe_gagne"] else "non"],
		[Game.libelle_rejeu(g["part"]), "+%d" % g["jetons"]],
		["XP du fan club", "+%d" % g["xp"]],
		["XP du PASS", "+%d" % g["xp_pass"]],
	] + FinDuel.ligne_deplacement(g["mult_depl"], g["bonus_depl"]) + FinDuel.ligne_popularite(g) + FinDuel.lignes_evenement(g["evenement"]) + FinDuel.ligne_tournoi(g["tournoi"]) + FinDuel.ligne_ligue(g["ligue"]) + FinDuel.lignes_kop(g["kop"]), Game.SCENE_SALON if en_ligne and Reseau.connecte() else Game.SCENE_ARENE)


# ================================================================== classes

## Un FANZZY dans l'arène : position, état et son corps animé.
class Joueur extends Node2D:
	var arene
	var equipe := 0
	var z: Dictionary
	var famille := "voix"
	var couleur := Ui.BLEU
	var spawn := Vector2.ZERO
	var corps: FanzzyAnime
	var direction := Vector2.ZERO
	var visee := Vector2.ZERO
	var pv := AreneRegles.PV
	var munitions := float(AreneRegles.MUNITIONS)
	var recharge := 0.0
	var charge_super := 0.0
	var etourdi := 0.0
	var ralenti := 0.0
	var sprint := 0.0
	var invulnerable := 0.0
	var roulade := 0.0
	var recharge_roulade := 0.0
	var banc := 0.0
	var pense := 0.0
	var graine := randf() * 10.0
	var _poussee := Vector2.ZERO
	var _cap := 1.0
	var _action := &""
	var _secousse := 0.0
	var lancers := 0              # compteurs envoyés à l'invité pour rejouer les animations
	var coups := 0
	var supers := 0

	func creer_corps(id: String) -> void:
		corps = FanzzyAnime.creer(id)
		corps.couleurs_echarpe = PackedColorArray([couleur, Ui.BLANC])
		add_child(corps)
		var h := corps._rect.size.y if corps._rect.size.y > 0.0 else 900.0
		corps.scale = Vector2.ONE * (HAUTEUR_FANZZY / h)
		corps.couleur_trainee = couleur
		_cap = 1.0 if equipe == 0 else -1.0
		_jouer(&"repos")

	func actif() -> bool:
		return banc <= 0.0

	func vitesse_actuelle() -> float:
		var v := 1.0
		if ralenti > 0.0:
			v *= 0.5
		if sprint > 0.0:
			v *= 1.7
		if etourdi > 0.0:
			v = 0.0
		return v

	func mettre_a_jour(delta: float) -> void:
		if banc > 0.0:
			banc -= delta
			if banc <= 0.0:
				position = spawn
				pv = AreneRegles.PV
				munitions = AreneRegles.MUNITIONS
				invulnerable = 1.2
				modulate.a = 1.0
				corps.jouer(&"lever_bras", 0.8)
				corps.rebondir(1.3)
				corps.trainee = 0.2
			return
		for k in ["recharge", "etourdi", "ralenti", "sprint", "invulnerable", "recharge_roulade", "_secousse"]:
			set(k, maxf(get(k) - delta, 0.0))
		munitions = minf(munitions + delta / AreneRegles.RECHARGE_MUNITION, AreneRegles.MUNITIONS)
		var v := direction * AreneRegles.VITESSE * vitesse_actuelle()
		if roulade > 0.0:
			roulade -= delta
			v = _poussee
		else:
			v += _poussee
			_poussee = _poussee.move_toward(Vector2.ZERO, 900.0 * delta)
		arene.deplacer(self, v * delta)
		# le buste penche dans le sens de la course, l'image se retourne
		if absf(direction.x) > 0.2:
			_cap = signf(direction.x)
		corps.cap = _cap
		corps.scale.x = absf(corps.scale.x) * (-1.0 if _cap < 0.0 and _image_regarde_droite() else 1.0)
		corps.vitesse_course = 0.8 + 0.6 * vitesse_actuelle()
		if _action != &"lancer" or corps.action != &"lancer":
			if etourdi > 0.0:
				_jouer(&"depit")
			elif direction.length() > 0.1:
				_jouer(&"courir" if vitesse_actuelle() >= 1.0 else &"marcher")
			else:
				_jouer(&"repos")
		modulate.a = 0.55 if invulnerable > 0.0 and int(invulnerable * 10.0) % 2 == 0 else 1.0
		corps.position.x = sin(_secousse * 60.0) * 6.0 * _secousse * 4.0
		_jus_etats()
		queue_redraw()

	## Étoiles d'étourdissement et traînée de sprint, suivant l'état.
	func _jus_etats() -> void:
		if etourdi > 0.0 and corps._etourdi <= 0.05:
			corps.etourdir(maxf(etourdi, 0.3))
		if sprint > 0.0 and direction.length() > 0.1:
			corps.trainee = maxf(corps.trainee, 0.06)

	## Les FANZZY sont dessinés de face : on ne les retourne pas (le texte
	## des écharpes serait à l'envers), seule la penche indique la direction.
	func _image_regarde_droite() -> bool:
		return false

	func _jouer(a: StringName) -> void:
		if corps.action != a:
			corps.jouer(a)
		_action = a

	func lancer(dx: float) -> void:
		lancers += 1
		if absf(dx) > 0.05:
			_cap = signf(dx)
		corps.cap = _cap
		corps.jouer(&"lancer")
		_action = &"lancer"

	func celebrer_court() -> void:
		supers += 1
		corps.jouer(&"celebrer", 0.6)
		_action = &"lancer"

	func pousser(v: Vector2) -> void:
		_poussee += v

	func secouer(depuis := Vector2.INF) -> void:
		coups += 1
		_secousse = 0.25
		corps.impact(depuis, 0.9)

	## Invité : seulement l'animation, la position vient de l'hôte.
	func animer(delta: float, v: Vector2) -> void:
		_secousse = maxf(_secousse - delta, 0.0)
		if absf(v.x) > 0.3:
			_cap = signf(v.x)
		corps.cap = _cap
		if _action != &"lancer" or corps.action != &"lancer":
			if etourdi > 0.0:
				_jouer(&"depit")
			elif v.length() > 0.6:
				_jouer(&"courir")
			elif actif():
				_jouer(&"repos")
		modulate.a = 0.0 if banc > 0.0 else (0.55 if invulnerable > 0.0 and int(Time.get_ticks_msec() / 100) % 2 == 0 else 1.0)
		corps.position.x = sin(_secousse * 60.0) * 6.0 * _secousse * 4.0
		if etourdi > 0.0 and corps._etourdi <= 0.05:
			corps.etourdir(0.5)
		if sprint > 0.0 and v.length() > 0.6:
			corps.trainee = maxf(corps.trainee, 0.06)
		queue_redraw()

	func rouler() -> void:
		if not actif() or recharge_roulade > 0.0:
			return
		var d := direction if direction != Vector2.ZERO else Vector2(_cap, 0)
		_poussee = d.normalized() * 900.0
		corps.trainee = 0.3
		corps.poussiere(4, 1.0, -signf(d.x) if absf(d.x) > 0.1 else 0.0)
		corps.pop(1.2)
		roulade = 0.24
		invulnerable = 0.3
		recharge_roulade = 3.0

	func aller_au_banc() -> void:
		banc = AreneRegles.TEMPS_BANC
		pv = 0.0
		direction = Vector2.ZERO
		corps.impact(Vector2.INF, 1.6)
		corps.etourdir(0.8)
		corps.jouer(&"depit")
		create_tween().tween_property(self, "modulate:a", 0.0, 0.6)

	func fin(victoire: bool) -> void:
		direction = Vector2.ZERO
		if banc > 0.0:
			banc = 0.0
			position = spawn
			modulate.a = 1.0
		corps.jouer(&"celebrer" if victoire else &"depit", 30.0)

	func _draw() -> void:
		if banc > 0.0:
			return
		var anneau := couleur
		draw_arc(Vector2(0, 4), 40, 0, TAU, 40, anneau.darkened(0.3), 7)
		draw_arc(Vector2(0, 4), 40, 0, TAU, 40, anneau, 4)
		if self == arene.controle:
			draw_arc(Vector2(0, 4), 50, 0, TAU, 40, Ui.JAUNE, 4)
			# repère de visée
			var dir := (visee - position).normalized()
			draw_line(dir * 56, dir * 90, Ui.JAUNE, 5)
		var y := -HAUTEUR_FANZZY - 26
		draw_rect(Rect2(-40, y, 80, 12), Ui.CONTOUR)
		draw_rect(Rect2(-38, y + 2, 76 * pv / AreneRegles.PV, 8), Ui.VERT if equipe == 0 else Ui.ROSE)
		if charge_super >= 1.0:
			draw_circle(Vector2(50, y + 6), 9, Ui.JAUNE)
		if etourdi > 0.0:
			for i in 3:
				var a := Time.get_ticks_msec() / 200.0 + i * TAU / 3.0
				draw_circle(Vector2(cos(a) * 34, y - 14 + sin(a) * 8), 6, Ui.JAUNE)


## Le terrain, dessiné sous les FANZZY : pelouse, mégaphone, obstacles, nuages.
class Sol extends Node2D:
	var arene
	var dispute := false
	var tenu := -1

	func _draw() -> void:
		var t: Rect2 = TERRAIN
		draw_rect(t.grow(14), Ui.CONTOUR)
		for i in 10:
			var r := Rect2(t.position.x + i * t.size.x / 10.0, t.position.y, t.size.x / 10.0, t.size.y)
			draw_rect(r, Color("#3fae5b") if i % 2 == 0 else Color("#38a052"))
		draw_rect(t, Color(1, 1, 1, 0.75), false, 5)
		draw_line(Vector2(t.get_center().x, t.position.y), Vector2(t.get_center().x, t.end.y), Color(1, 1, 1, 0.6), 5)
		# bancs des deux équipes
		for e in 2:
			var x := t.position.x + 20 if e == 0 else t.end.x - 200
			draw_rect(Rect2(x, t.end.y - 40, 180, 26), Color(arene.couleurs[e], 0.7))
		# mégaphone central
		var c := t.get_center()
		var col: Color = Ui.BLANC if tenu < 0 else arene.couleurs[tenu]
		if dispute:
			col = Ui.JAUNE.lerp(Ui.BLANC, 0.5 + 0.5 * sin(Time.get_ticks_msec() / 90.0))
		draw_circle(c, AreneRegles.RAYON_MEGAPHONE, Color(col, 0.22))
		draw_arc(c, AreneRegles.RAYON_MEGAPHONE, 0, TAU, 64, col, 6)
		# le mégaphone lui-même (pavillon + poignée)
		var pts := PackedVector2Array([c + Vector2(-34, -14), c + Vector2(26, -40), c + Vector2(26, 40), c + Vector2(-34, 14)])
		draw_colored_polygon(pts, Ui.CONTOUR)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-30, -10), c + Vector2(22, -33), c + Vector2(22, 33), c + Vector2(-30, 10)]), Ui.JAUNE)
		draw_rect(Rect2(c + Vector2(-48, -12), Vector2(18, 24)), Ui.ROSE)
		# obstacles : caisses de ballons et panneaux
		for r in OBSTACLES:
			var rr: Rect2 = r
			draw_rect(rr.grow(5), Ui.CONTOUR)
			draw_rect(rr, Color("#f2a33a"))
			for k in int(rr.size.y / 30.0):
				draw_rect(Rect2(rr.position.x, rr.position.y + k * 30 + 4, rr.size.x, 10), Color("#d9822b"))
			draw_rect(Rect2(rr.position, Vector2(rr.size.x, 14)), Color("#ffc965"))
		# fumigènes
		for n in arene.nuages:
			var a: float = clampf(n["reste"], 0.0, 1.0)
			for k in 7:
				var o: Vector2 = Vector2.from_angle(k * TAU / 7.0 + Time.get_ticks_msec() / 1500.0) * n["rayon"] * 0.45
				draw_circle(n["pos"] + o, n["rayon"] * 0.55, Color(arene.couleurs[n["equipe"]].lightened(0.4), 0.18 * a))
		# grands tifos
		for m in arene.murs:
			var a: Vector2 = m["a"]
			var b: Vector2 = m["b"]
			draw_line(a, b, Ui.CONTOUR, 30)
			draw_line(a, b, arene.couleurs[m["equipe"]], 22)
			for k in 6:
				var q := a.lerp(b, (k + 0.5) / 6.0)
				draw_circle(q, 6, Ui.BLANC if k % 2 == 0 else Ui.JAUNE)
		# ondes (dessinées au sol)
		for o in arene.ondes:
			var col2: Color = Ui.VERT if o["type"] == "soin" else arene.couleurs[o["equipe"]]
			var al: float = clampf(o["reste"] * 2.0, 0.0, 1.0)
			if o["type"] == "cone":
				var ang: float = (o["dir"] as Vector2).angle()
				draw_arc(o["pos"], o["rayon"], ang - 0.6, ang + 0.6, 24, Color(col2, al), 14)
				draw_arc(o["pos"], o["rayon"] * 0.7, ang - 0.6, ang + 0.6, 24, Color(Ui.BLANC, al * 0.7), 8)
			else:
				draw_arc(o["pos"], o["rayon"], 0, TAU, 48, Color(col2, al), 12)


## Par-dessus les FANZZY : ballons, confettis, textes.
class Ciel extends Node2D:
	var arene

	func _draw() -> void:
		var f := Ui.police_titre()
		for b in arene.ballons:
			var p: Vector2 = b["pos"]
			var r: float = b["rayon"]
			draw_circle(p + Vector2(0, 40), r * 0.8, Color(0, 0, 0, 0.25))
			draw_circle(p, r + 3, Ui.CONTOUR)
			draw_circle(p, r, arene.couleurs[b["equipe"]])
			draw_arc(p, r * 0.6, 0.3, 2.4, 10, Ui.BLANC, 3)
			draw_circle(p + Vector2(-r * 0.35, -r * 0.35), r * 0.25, Color(1, 1, 1, 0.7))
		for c in arene.confettis:
			var p: Vector2 = c["pos"]
			var x := Vector2.from_angle(c["rot"]) * 6
			draw_line(p - x, p + x, Color(c["col"], clampf(c["vie"] * 2.0, 0.0, 1.0)), 6)
		for t in arene.textes:
			var al: float = clampf(t["vie"], 0.0, 1.0)
			var taille := 34
			var w := f.get_string_size(t["texte"], HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
			draw_string_outline(f, t["pos"] - Vector2(w * 0.5, 0), t["texte"], HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 14, Color(Ui.CONTOUR, al))
			draw_string_outline(f, t["pos"] - Vector2(w * 0.5, 0), t["texte"], HORIZONTAL_ALIGNMENT_LEFT, -1, taille, 6, Color(t["col"], al))
			draw_string(f, t["pos"] - Vector2(w * 0.5, 0), t["texte"], HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(Ui.BLANC, al))


## Barre de banderole (0..1), qui se remplit depuis le centre de l'écran.
class Barre extends Control:
	var valeur := 0.0
	var couleur := Ui.BLEU
	var inverse := false

	func _draw() -> void:
		draw_style_box(Ui.boite(Ui.NUIT, 14, 4, 0), Rect2(Vector2.ZERO, size))
		var w := (size.x - 12) * valeur
		var x := 6.0 if not inverse else size.x - 6 - w
		if w > 1.0:
			draw_rect(Rect2(x, 6, w, size.y - 12), couleur)
			draw_rect(Rect2(x, 6, w, (size.y - 12) * 0.35), Color(1, 1, 1, 0.25))


## Bas de l'écran : ballons en réserve, super, roulade du FANZZY dirigé.
class HudBas extends Node2D:
	var arene

	func _draw() -> void:
		var j = arene.controle
		if j == null:
			return
		var f := Ui.police_titre()
		var sup: Dictionary = AreneRegles.SUPERS.get(j.famille, {})
		draw_string_outline(f, Vector2(0, -10), str(j.z.get("nom", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Ui.CONTOUR)
		draw_string(f, Vector2(0, -10), str(j.z.get("nom", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Ui.JAUNE)
		for i in AreneRegles.MUNITIONS:
			var plein: float = clampf(j.munitions - i, 0.0, 1.0)
			var p := Vector2(16 + i * 40, 22)
			draw_circle(p, 16, Ui.CONTOUR)
			draw_circle(p, 13, Ui.NUIT_CLAIR)
			if plein > 0.0:
				draw_circle(p, 13 * plein, j.couleur if plein >= 1.0 else j.couleur.darkened(0.4))
		var x := 150.0
		var pret: bool = j.charge_super >= 1.0
		draw_circle(Vector2(x + 20, 22), 22, Ui.CONTOUR)
		draw_arc(Vector2(x + 20, 22), 17, -PI / 2, -PI / 2 + TAU * j.charge_super, 32, Ui.JAUNE, 7)
		var t := tr("SUPER : %s") % sup.get("nom", "") if pret else tr("super %d %%") % int(j.charge_super * 100)
		draw_string_outline(f, Vector2(x + 52, 32), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 8, Ui.CONTOUR)
		draw_string(f, Vector2(x + 52, 32), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Ui.JAUNE if pret else Ui.BLANC)
		if "roulade" in arene.actions:
			var txt_roulade := tr("roulade prête") if j.recharge_roulade <= 0.0 else tr("roulade %.1f s") % j.recharge_roulade
			# après le nom du FANZZY (les noms longs le chevauchaient)
			var xr := maxf(x + 52, f.get_string_size(str(j.z.get("nom", "")).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x + 24)
			draw_string_outline(f, Vector2(xr, -10), txt_roulade, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 6, Ui.CONTOUR)
			draw_string(f, Vector2(xr, -10), txt_roulade, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Ui.BLANC if j.recharge_roulade <= 0.0 else Ui.GRIS)
		var c: float = arene.charge_tir()
		if c > 0.0:
			draw_rect(Rect2(0, 48, 120 * c, 8), Ui.JAUNE if c >= 1.0 else Ui.BLANC)
