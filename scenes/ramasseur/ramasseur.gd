class_name Ramasseur
extends Control
## Petit boulot de supporter : ramasseur de balles au bord du terrain (60 s).
##   ← → (ou Q D, A D) ou souris : courir le long de la touche
##   ESPACE, ENTRÉE ou clic : relancer le ballon au joueur qui attend
## Les ballons sortent du terrain ; leur ombre montre où ils tombent.
## Attrapé = Jetons, relancé vite = bonus. Le ballon du match (doré) vaut plus.
## À 30 s, le match s'emballe. Règles dans RamasseurRegles.
## Option « --auto » (tests, captures) : la partie se joue toute seule.

const SonsScript := preload("res://scripts/audio/sons.gd")

const ID := "ramasseur"
const X_GAUCHE := 150.0        # coin gauche de la touche (pixels)
const X_DROITE := 1770.0       # coin droit
const Y_TOUCHE := 620.0        # ligne de touche (bas du terrain)
const Y_TERRAIN := 250.0       # haut du terrain dessiné
const Y_PANNEAUX := 636.0
const Y_SOL := 965.0           # pieds du ramasseur
const HAUTEUR_RAMASSEUR := 250.0
const Y_MAINS := Y_SOL - 150.0 # hauteur où l'on attrape le ballon
const HAUTEUR_ARC := 330.0
const DELAI_CALME := 0.55      # pause avant le ballon suivant
const DELAI_RUSH := 0.35
const DUREE_RELANCE := 0.45

var regles := RamasseurRegles.new()
var temps := 0.0
var pret := false
var termine := false
var en_pause := false
var auto := "--auto" in OS.get_cmdline_user_args()

## Position du ramasseur, en fraction de la touche (0 = gauche, 1 = droite).
var x_joueur := 0.5
var ballon := {}               # ballon en vol : {x, vol, dore, t, depart}
var en_main := false
var ballon_dore_en_main := false
var attente := 0.0             # secondes ballon en main
var numero := 0
var serie := 0
var serie_max := 0
var attrapes := 0
var rates := 0
var dores := 0
var remises_rapides := 0
var paye_prises := 0
var paye_remises := 0
var paye_dores := 0
var bonus := 0

var _rush := false
var _prochain := 0.0           # secondes avant le prochain tir (-1 = rien de prévu)
var _gauche := false
var _droite := false
var _cible_souris := -1.0
var _auto_cible := 0.5
var _auto_relance := 0.0
var _relance := {}             # ballon relancé : {de, vers, t}
var _rebond := {}              # ballon raté qui roule : {pos, vit, t}
var _receveur_x := -1.0        # joueur qui attend la remise en jeu (pixels), -1 = personne
var _joueurs: Array = []       # joueurs du terrain : {pos, cible, couleur}
var _sons: Node

var _decor: Decor
var _avant: Decor
var _perso: FanzzyAnime
var _lbl_temps: Label
var _lbl_paye: Label
var _lbl_serie: Label
var _pause: Control


func _ready() -> void:
	_sons = SonsScript.new()
	_sons.name = "Sons"
	add_child(_sons)
	_creer_joueurs()
	_construire()
	_sons.ambiance("stade", 1)
	_compte_a_rebours()


static func px(f: float) -> float:
	return X_GAUCHE + f * (X_DROITE - X_GAUCHE)


static func frac(x: float) -> float:
	return (x - X_GAUCHE) / (X_DROITE - X_GAUCHE)


## Le FANZZY qui fait le ramasseur : le premier de la tribune du joueur.
static func id_ramasseur() -> String:
	if not Game.equipe.is_empty():
		return str(Game.equipe[0])
	var ids := Buvette.ids_clients()
	return str(ids[0]) if not ids.is_empty() else ""


# ------------------------------------------------------------------ construction

func _creer_joueurs() -> void:
	for i in 10:
		var p := Vector2(randf_range(X_GAUCHE + 60, X_DROITE - 60), randf_range(Y_TERRAIN + 70, Y_TOUCHE - 50))
		_joueurs.append({"pos": p, "cible": p, "couleur": Ui.ROSE if i % 2 == 0 else Ui.BLEU})


func _construire() -> void:
	_decor = Decor.new()
	_decor.jeu = self
	_decor.couche = 0
	_decor.set_anchors_preset(Control.PRESET_FULL_RECT)
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_decor)

	_perso = FanzzyAnime.creer(Ramasseur.id_ramasseur())
	_perso.couleurs_echarpe = PackedColorArray([Ui.JAUNE, Ui.CONTOUR])
	add_child(_perso)
	_perso.scale = Vector2.ONE * Buvette.echelle(_perso, HAUTEUR_RAMASSEUR)
	_perso.position = Vector2(px(x_joueur), Y_SOL)
	_perso.jouer(&"repos")

	_avant = Decor.new()
	_avant.jeu = self
	_avant.couche = 1
	_avant.set_anchors_preset(Control.PRESET_FULL_RECT)
	_avant.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avant)

	# --- haut : quitter, temps, série, paye
	var haut := Ui.hbox(16)
	haut.set_anchors_preset(Control.PRESET_TOP_WIDE)
	haut.offset_left = 28
	haut.offset_right = -28
	haut.offset_top = 18
	add_child(haut)
	var quitter := Ui.bouton("Quitter", Ui.NUIT_CLAIR, 24)
	quitter.tooltip_text = "Rentrer sans finir la partie (pas de paye)"
	quitter.custom_minimum_size = Vector2(170, 70)
	quitter.focus_mode = Control.FOCUS_NONE
	quitter.pressed.connect(_retour)
	haut.add_child(quitter)
	var pt := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_temps = Ui.label("1:00", 40, Ui.BLANC, true, 6)
	_lbl_temps.custom_minimum_size = Vector2(110, 0)
	_lbl_temps.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pt.add_child(_lbl_temps)
	haut.add_child(pt)
	haut.add_child(Ui.espace())
	var ps := Ui.panneau(Ui.NUIT, 20, 5)
	_lbl_serie = Ui.label("Série x0", 30, Ui.BLANC, true, 6)
	ps.add_child(_lbl_serie)
	ps.tooltip_text = "Ballons attrapés d'affilée : +1 Jeton tous les %d" % RamasseurRegles.SERIE_BONUS
	haut.add_child(ps)
	var pj := Ui.panneau(Ui.NUIT, 20, 5)
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 40))
	_lbl_paye = Ui.label("0", 34, Ui.JAUNE, true, 6)
	hj.add_child(_lbl_paye)
	pj.add_child(hj)
	pj.tooltip_text = "Paye de la partie (versée à la fin)"
	haut.add_child(pj)

	var info := Ui.label("← → ou souris : courir  ·  ESPACE ou clic : relancer le ballon  ·  ÉCHAP : pause", 22, Ui.BLANC, false, 6)
	info.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.offset_left = -700
	info.offset_right = 700
	info.offset_top = -48
	info.offset_bottom = -14
	add_child(info)


# ------------------------------------------------------------------ déroulé

func _compte_a_rebours() -> void:
	var l := Ui.label("3", 200, Ui.JAUNE, true, 24)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.grow_vertical = Control.GROW_DIRECTION_BOTH
	l.offset_top = -160
	add_child(l)
	for t in ["3", "2", "1", "COUP D'ENVOI !"]:
		l.text = t
		l.pivot_offset = l.size / 2.0
		Ui.pop(l, 1.4, 0.3)
		_sons.jouer("ui_decompte_go" if t.length() > 1 else "ui_decompte")
		await get_tree().create_timer(0.7).timeout
	l.queue_free()
	if not is_inside_tree():
		return
	_sons.jouer("sifflet_court")
	pret = true
	_prochain = 0.4


func _process(delta: float) -> void:
	_decor.queue_redraw()
	_avant.queue_redraw()
	_bouger_joueurs(delta)
	if not pret or termine or en_pause:
		return
	temps += delta
	if not _rush and RamasseurRegles.en_rush(temps):
		_rush = true
		_annonce("LE MATCH S'EMBALLE !", Ui.ROSE)
		_sons.jouer("clameur_but", {"volume_db": -6})
		_sons.ambiance("stade", 2)
	var reste := maxf(0.0, RamasseurRegles.DUREE - temps)
	_lbl_temps.text = "%d:%02d" % [int(ceil(reste)) / 60, int(ceil(reste)) % 60]
	_lbl_temps.add_theme_color_override("font_color", Ui.ROUGE if reste < 10.0 else Ui.BLANC)

	if auto:
		_jouer_tout_seul(delta)
	_courir(delta)

	if en_main:
		attente += delta
	if not ballon.is_empty():
		ballon["t"] += delta
		if ballon["t"] >= ballon["vol"]:
			_chute()
	if not _relance.is_empty():
		_relance["t"] += delta
		if _relance["t"] >= DUREE_RELANCE:
			_relance = {}
			_receveur_x = -1.0
			_prochain = DELAI_RUSH if _rush else DELAI_CALME
	if not _rebond.is_empty():
		_rebond["t"] += delta
		_rebond["vit"].y += 1800.0 * delta
		_rebond["pos"] += _rebond["vit"] * delta
		if _rebond["pos"].y > Y_SOL + 10.0:
			_rebond["pos"].y = Y_SOL + 10.0
			_rebond["vit"].y *= -0.45
		if _rebond["t"] > 1.1:
			_rebond = {}
	if _prochain > 0.0:
		_prochain -= delta
		if _prochain <= 0.0:
			_prochain = -1.0
			_tirer()
	if temps >= RamasseurRegles.DUREE:
		_finir()


func _courir(delta: float) -> void:
	var dir := 0.0
	if _droite != _gauche:
		dir = 1.0 if _droite else -1.0
	elif _cible_souris >= 0.0 and absf(_cible_souris - x_joueur) > 0.01:
		dir = signf(_cible_souris - x_joueur)
	var pas := RamasseurRegles.VITESSE * delta
	if _cible_souris >= 0.0 and _droite == _gauche:
		pas = minf(pas, absf(_cible_souris - x_joueur))
	x_joueur = clampf(x_joueur + dir * pas, 0.0, 1.0)
	_perso.position.x = px(x_joueur)
	if dir != 0.0:
		_perso.cap = dir
		if _perso.action != &"courir" and _perso.action != &"lancer":
			_perso.jouer(&"courir")
	elif _perso.action == &"courir":
		_perso.jouer(&"repos")


func _jouer_tout_seul(delta: float) -> void:
	_gauche = false
	_droite = false
	if not ballon.is_empty():
		_cible_souris = _auto_cible
	if en_main:
		_auto_relance -= delta
		if _auto_relance <= 0.0:
			relancer()


func _bouger_joueurs(delta: float) -> void:
	for j in _joueurs:
		var p: Vector2 = j["pos"]
		if p.distance_to(j["cible"]) < 8.0:
			j["cible"] = Vector2(randf_range(X_GAUCHE + 60, X_DROITE - 60), randf_range(Y_TERRAIN + 70, Y_TOUCHE - 50))
		j["pos"] = p.move_toward(j["cible"], (160.0 if _rush else 90.0) * delta)


## Un joueur dégage le ballon en touche.
func _tirer() -> void:
	if termine:
		return
	var b := regles.tir(numero, _rush, x_joueur)
	numero += 1
	var cible := Vector2(px(b["x"]), Y_TOUCHE - 90.0)
	var tireur: Dictionary = _joueurs[0]
	for j in _joueurs:
		if j["pos"].distance_to(cible) < tireur["pos"].distance_to(cible):
			tireur = j
	b["depart"] = tireur["pos"] + Vector2(0, -20)
	b["t"] = 0.0
	ballon = b
	_auto_cible = b["x"] + (randf_range(-0.12, 0.12) if randf() < 0.1 else randf_range(-0.02, 0.02))
	_sons.jouer("tambour", {"volume_db": -8, "hauteur": 1.4})
	if b["dore"]:
		_gain_flottant(b["depart"] + Vector2(-140, -60), "BALLON DU MATCH !", Ui.JAUNE)


## Position du ballon en vol, à la part `u` du trajet (0 = tir, 1 = dans les mains).
func position_ballon(u: float) -> Vector2:
	var fin := Vector2(px(ballon["x"]), Y_MAINS)
	var p: Vector2 = ballon["depart"].lerp(fin, u)
	return p + Vector2(0, -HAUTEUR_ARC * 4.0 * u * (1.0 - u))


func _chute() -> void:
	var b := ballon
	ballon = {}
	if RamasseurRegles.attrape(x_joueur, b["x"]):
		_attraper(b)
	else:
		_rater(b)


func _attraper(b: Dictionary) -> void:
	serie += 1
	serie_max = maxi(serie_max, serie)
	attrapes += 1
	en_main = true
	ballon_dore_en_main = b["dore"]
	attente = 0.0
	_auto_relance = randf_range(0.25, 0.7)
	var p := RamasseurRegles.paye_prise(b["dore"], serie)
	paye_prises += p["prise"]
	paye_dores += p["dore"]
	bonus += p["bonus"]
	if b["dore"]:
		dores += 1
	_receveur_x = clampf(px(b["x"]) + randf_range(-140, 140), X_GAUCHE + 40, X_DROITE - 40)
	var ici := Vector2(px(x_joueur) - 60, Y_MAINS - 120)
	if p["bonus"] > 0:
		_gain_flottant(ici, "+%d  SÉRIE x%d !" % [p["total"], serie], Ui.JAUNE)
		_sons.jouer("ui_combo_%d" % clampi(serie / RamasseurRegles.SERIE_BONUS, 1, 4))
	else:
		_gain_flottant(ici, "+%d" % p["total"], Ui.JAUNE)
	_sons.jouer("ui_parfait" if b["dore"] else "ui_bien")
	_sons.jouer("clap", {"volume_db": -8})
	_maj_hud()


func _rater(b: Dictionary) -> void:
	rates += 1
	serie = 0
	var sol := Vector2(px(b["x"]), Y_SOL + 10.0)
	_rebond = {"pos": sol + Vector2(0, -60), "vit": Vector2(signf(b["x"] - x_joueur) * 420.0, -380.0), "t": 0.0}
	_gain_flottant(sol + Vector2(-80, -260), "Raté !", Ui.ROUGE)
	_sons.jouer("ui_rate")
	_sons.jouer("deception", {"volume_db": -12})
	_prochain = 0.9
	_maj_hud()


## Relance le ballon tenu en main au joueur qui attend la remise en jeu.
func relancer() -> void:
	if not pret or termine or en_pause or not en_main:
		return
	en_main = false
	var r := RamasseurRegles.paye_remise(attente)
	paye_remises += r
	if r > 0:
		remises_rapides += 1
		_gain_flottant(Vector2(_receveur_x - 120, Y_TOUCHE - 200), "Remise rapide +%d" % r, Ui.VERT)
	_relance = {"de": Vector2(px(x_joueur), Y_MAINS - 20), "vers": Vector2(_receveur_x, Y_TOUCHE - 70), "t": 0.0}
	_perso.cap = signf(_receveur_x - px(x_joueur)) if absf(_receveur_x - px(x_joueur)) > 1.0 else 1.0
	_perso.jouer(&"lancer")
	_sons.jouer("ui_clic", {"hauteur": 1.3})
	_maj_hud()


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and not ev.echo:
		var k: int = ev.physical_keycode
		if k in [KEY_LEFT, KEY_A, KEY_Q]:
			_gauche = ev.pressed
			if ev.pressed:
				_cible_souris = -1.0
		elif k in [KEY_RIGHT, KEY_D]:
			_droite = ev.pressed
			if ev.pressed:
				_cible_souris = -1.0
		elif ev.pressed and k in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_UP, KEY_W, KEY_Z]:
			relancer()
		elif ev.pressed and k == KEY_ESCAPE:
			_basculer_pause()
		else:
			return
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if en_pause or termine:
			return
		if ev.pressed:
			if en_main:
				relancer()
			elif ev.position.y > Y_TERRAIN:
				_cible_souris = clampf(frac(ev.position.x), 0.0, 1.0)
		elif not auto:
			_cible_souris = -1.0
	elif ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT and not en_pause:
		_cible_souris = clampf(frac(ev.position.x), 0.0, 1.0)


func _basculer_pause() -> void:
	if termine or not pret:
		return
	en_pause = not en_pause
	if en_pause:
		_gauche = false
		_droite = false
		_pause = ColorRect.new()
		(_pause as ColorRect).color = Color(0.05, 0.03, 0.15, 0.6)
		_pause.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(_pause)
		var v := Ui.vbox(20)
		v.set_anchors_preset(Control.PRESET_CENTER)
		v.grow_horizontal = Control.GROW_DIRECTION_BOTH
		v.grow_vertical = Control.GROW_DIRECTION_BOTH
		_pause.add_child(v)
		var t := Ui.label("PAUSE", 90, Ui.JAUNE, true, 14)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var reprendre := Ui.bouton("Reprendre", Ui.VERT, 32)
		Ui.colorer_bouton(reprendre, Ui.VERT, true)
		reprendre.custom_minimum_size = Vector2(400, 90)
		reprendre.pressed.connect(_basculer_pause)
		v.add_child(reprendre)
		var abandon := Ui.bouton("Abandonner (pas de paye)", Ui.ROUGE, 26)
		abandon.custom_minimum_size = Vector2(400, 76)
		abandon.pressed.connect(_retour)
		v.add_child(abandon)
	elif _pause:
		_pause.queue_free()
		_pause = null


func _maj_hud() -> void:
	_lbl_paye.text = str(brut())
	Ui.pop(_lbl_paye, 1.25, 0.2)
	_lbl_serie.text = "Série x%d" % serie
	_lbl_serie.add_theme_color_override("font_color", Ui.JAUNE if serie >= RamasseurRegles.SERIE_BONUS else Ui.BLANC)


func brut() -> int:
	return paye_prises + paye_remises + paye_dores + bonus


func _gain_flottant(pos: Vector2, texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 48, couleur, true, 12)
	l.position = pos
	add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", pos.y - 120.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _annonce(texte: String, couleur: Color) -> void:
	var l := Ui.label(texte, 84, couleur, true, 18)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	l.offset_top = -395
	add_child(l)
	await get_tree().process_frame
	l.pivot_offset = l.size / 2.0
	Ui.pop(l, 1.3, 0.35)
	var tw := l.create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


# ------------------------------------------------------------------ fin

func _finir() -> void:
	termine = true
	ballon = {}
	_gauche = false
	_droite = false
	_cible_souris = -1.0
	_perso.jouer(&"celebrer" if attrapes > rates else &"depit")
	_sons.jouer("sifflet_fin")
	_sons.ambiance("stade", 1)
	var total := brut()
	var deja := Game.services_boulot_du_jour(ID)
	var paye := RamasseurRegles.paye_finale(total, deja)
	var record := paye > Game.record_boulot(ID) and paye > 0
	var xp := attrapes * RamasseurRegles.XP_PAR_BALLE
	Game.finir_boulot(ID, paye)
	Game.ajouter_xp(xp)
	if paye > 0:
		_sons.jouer("applaudissements", {"volume_db": -4})

	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
	voile.create_tween().tween_property(voile, "color:a", 0.65, 0.4)
	var pan := Ui.panneau()
	pan.set_anchors_preset(Control.PRESET_CENTER)
	pan.offset_left = -460
	pan.offset_right = 460
	pan.offset_top = -370
	pan.offset_bottom = 370
	add_child(pan)
	var v := Ui.vbox(12)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	pan.add_child(v)
	var t := Ui.label("FIN DU MATCH !", 56, Ui.JAUNE, true, 10)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	if record:
		var r := Ui.pastille("NOUVEAU RECORD", Ui.ROSE, 22)
		r.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		v.add_child(r)
	var lignes := [
		["Ballons attrapés", str(attrapes)],
		["Ballons ratés", str(rates)],
		["Meilleure série", "x%d" % serie_max],
		["Prises", "+%d" % paye_prises],
		["Remises rapides", "+%d" % paye_remises],
		["Ballons du match", "+%d" % paye_dores],
		["Bonus de série", "+%d" % bonus],
	]
	if paye < total:
		lignes.append(["Fatigue (%de partie du jour)" % (deja + 1), "paye ÷ 2"])
	lignes.append(["Jetons gagnés", "+%d" % paye])
	lignes.append(["XP du fan club", "+%d" % xp])
	for l in lignes:
		var h := Ui.hbox(10)
		var a := Ui.label(l[0], 24, Ui.BLANC)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(Ui.label(l[1], 26, Ui.JAUNE, true))
		v.add_child(h)
	var hb := Ui.hbox(16)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var retour := Ui.bouton("Petits boulots", Ui.BLEU, 30)
	retour.custom_minimum_size = Vector2(360, 90)
	retour.pressed.connect(_retour)
	hb.add_child(retour)
	var rejouer := Ui.bouton("Nouvelle partie", Ui.VERT, 30)
	Ui.colorer_bouton(rejouer, Ui.VERT, true)
	rejouer.custom_minimum_size = Vector2(340, 90)
	var p: Dictionary = Game.params
	rejouer.pressed.connect(func(): Game.aller(Game.SCENE_RAMASSEUR, p))
	hb.add_child(rejouer)
	v.add_child(hb)
	pan.pivot_offset = Vector2(460, 370)
	pan.scale = Vector2.ONE * 0.6
	pan.create_tween().tween_property(pan, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _retour() -> void:
	Game.aller(Game.SCENE_BOULOTS, Game.params)


# ================================================================== éléments dessinés

## Couche 0 : tribune, terrain, joueurs, panneaux, bord de touche et ombre du
## ballon. Couche 1 (devant le ramasseur) : le ballon lui-même.
class Decor extends Control:
	var jeu: Ramasseur
	var couche := 0

	func _draw() -> void:
		if jeu == null:
			return
		if couche == 0:
			_fond()
		else:
			_ballons()

	func _fond() -> void:
		var w := size.x
		var t := Time.get_ticks_msec() / 1000.0
		var rush := jeu._rush and not jeu.termine
		# tribune d'en face
		draw_rect(Rect2(0, 0, w, Ramasseur.Y_TERRAIN), Color("#2d2670"))
		for rang in 4:
			var y := 120.0 + rang * 32.0
			for i in 60:
				var x := 16.0 + i * (w - 32.0) / 59.0
				var saut := sin(t * (6.0 if rush else 2.0) + i * 0.6 + rang) * (6.0 if rush else 2.0)
				var c := Ui.ROSE if (i + rang) % 3 == 0 else (Ui.BLANC if (i + rang) % 3 == 1 else Ui.BLEU)
				draw_circle(Vector2(x, y + saut), 11, c.darkened(0.25 - 0.05 * rang))
		# terrain
		var yt := Ramasseur.Y_TERRAIN
		var yb := Ramasseur.Y_TOUCHE
		draw_rect(Rect2(0, yt, w, Ramasseur.Y_PANNEAUX - yt + 70), Color("#2fb36b"))
		for i in 12:
			if i % 2 == 0:
				draw_rect(Rect2(i * w / 12.0, yt, w / 12.0, yb - yt + 16), Color("#38c477"))
		var blanc := Color(1, 1, 1, 0.85)
		var xg := Ramasseur.X_GAUCHE
		var xd := Ramasseur.X_DROITE
		draw_line(Vector2(xg, yb), Vector2(xd, yb), blanc, 6)
		draw_line(Vector2(xg, yt + 30), Vector2(xd, yt + 30), blanc, 4)
		draw_line(Vector2(xg, yt + 30), Vector2(xg, yb), blanc, 5)
		draw_line(Vector2(xd, yt + 30), Vector2(xd, yb), blanc, 5)
		draw_line(Vector2(w / 2.0, yt + 30), Vector2(w / 2.0, yb), blanc, 4)
		draw_arc(Vector2(w / 2.0, (yt + 30 + yb) / 2.0), 90, 0, TAU, 40, blanc, 4)
		for cote in [xg, xd]:
			var s := 1.0 if cote == xg else -1.0
			draw_rect(Rect2(minf(cote, cote + s * 220), yt + 110, 220, yb - yt - 160), blanc, false, 4)
		# joueurs (de loin), triés de haut en bas
		var js: Array = jeu._joueurs.duplicate()
		js.sort_custom(func(a, b): return a["pos"].y < b["pos"].y)
		for j in js:
			_joueur(j["pos"], j["couleur"], 0.0)
		# le joueur qui attend la remise en jeu, bras levés
		if jeu._receveur_x >= 0.0:
			_joueur(Vector2(jeu._receveur_x, yb - 4), Ui.ROSE, sin(t * 10.0))
		# panneaux publicitaires (marques imaginaires)
		var yp := Ramasseur.Y_PANNEAUX
		var pubs := ["FAN AROUND THE WORLD", "GAUFRES DU STADE", "RADIO TRIBUNE", "ÉCHARPES & CO", "LIMONADE PÉTILLE"]
		var couleurs := [Ui.NUIT, Ui.JAUNE, Ui.BLEU, Ui.ROSE, Ui.VERT]
		var lp := w / 5.0
		var f := Ui.police_titre()
		for i in 5:
			var r := Rect2(i * lp, yp, lp, 62)
			draw_rect(r, couleurs[i])
			draw_rect(r, Ui.CONTOUR, false, 4)
			var fs := 26
			var tw := f.get_string_size(pubs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := Vector2(r.get_center().x - tw / 2.0, r.get_center().y + fs * 0.36)
			var sombre: bool = couleurs[i] == Ui.JAUNE or couleurs[i] == Ui.VERT
			draw_string(f, pos, pubs[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.CONTOUR if sombre else Ui.BLANC)
		# bord de touche : pelouse plus sombre où court le ramasseur
		var yr := yp + 62
		draw_rect(Rect2(0, yr, w, size.y - yr), Color("#24894f"))
		for i in 30:
			draw_rect(Rect2(i * w / 30.0, Ramasseur.Y_SOL + 26, w / 60.0, 6), Color(1, 1, 1, 0.35))
		# ombre et zone de prise du ballon en vol
		if not jeu.ballon.is_empty():
			var u: float = clampf(jeu.ballon["t"] / jeu.ballon["vol"], 0.0, 1.0)
			var cx := Ramasseur.px(jeu.ballon["x"])
			var rayon := RamasseurRegles.RAYON_PRISE * (xd - xg)
			var dedans := RamasseurRegles.attrape(jeu.x_joueur, jeu.ballon["x"])
			var c := Ui.VERT if dedans else (Ui.JAUNE if jeu.ballon["dore"] else Ui.BLANC)
			_ellipse(Vector2(cx, Ramasseur.Y_SOL + 8), Vector2(rayon, rayon * 0.28), Color(c, 0.25))
			_ellipse_contour(Vector2(cx, Ramasseur.Y_SOL + 8), Vector2(rayon, rayon * 0.28), c, 5)
			# l'anneau se resserre : il tombe bientôt
			_ellipse_contour(Vector2(cx, Ramasseur.Y_SOL + 8), Vector2(rayon, rayon * 0.28) * (1.0 + 1.6 * (1.0 - u)), Color(c, 0.6), 3)
			_ellipse(Vector2(cx, Ramasseur.Y_SOL + 8), Vector2(20, 7) * (0.5 + u), Color(0, 0, 0, 0.35))
		# ombre du ramasseur
		_ellipse(Vector2(jeu._perso.position.x, Ramasseur.Y_SOL + 4), Vector2(70, 14), Color(0, 0, 0, 0.25))

	func _ballons() -> void:
		if not jeu.ballon.is_empty():
			var u: float = clampf(jeu.ballon["t"] / jeu.ballon["vol"], 0.0, 1.0)
			_ballon(jeu.position_ballon(u), lerpf(16.0, 32.0, u), jeu.ballon["dore"], u * 9.0)
		if jeu.en_main:
			_ballon(Vector2(jeu._perso.position.x, Ramasseur.Y_MAINS - 20), 30.0, jeu.ballon_dore_en_main, 0.0)
		if not jeu._relance.is_empty():
			var u2: float = clampf(jeu._relance["t"] / Ramasseur.DUREE_RELANCE, 0.0, 1.0)
			var p: Vector2 = jeu._relance["de"].lerp(jeu._relance["vers"], u2) + Vector2(0, -160.0 * 4.0 * u2 * (1.0 - u2))
			_ballon(p, lerpf(30.0, 16.0, u2), false, u2 * 6.0)
		if not jeu._rebond.is_empty():
			var a := clampf(1.0 - (jeu._rebond["t"] - 0.6) / 0.5, 0.0, 1.0)
			_ballon(jeu._rebond["pos"], 26.0, false, jeu._rebond["t"] * 12.0, a)

	func _ballon(c: Vector2, r: float, dore: bool, rot: float, alpha := 1.0) -> void:
		if dore:
			draw_circle(c, r * 1.5, Color(Ui.JAUNE, 0.3 * alpha))
		draw_circle(c, r + 4, Color(Ui.CONTOUR, alpha))
		draw_circle(c, r, Color(Ui.JAUNE if dore else Ui.BLANC, alpha))
		var motif := Color(Color("#b97a14") if dore else Ui.CONTOUR, alpha)
		draw_circle(c, r * 0.32, motif)
		for i in 5:
			var a := rot + TAU * i / 5.0
			draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.72, r * 0.2, motif)

	func _joueur(pied: Vector2, couleur: Color, bras: float) -> void:
		_ellipse(pied + Vector2(0, 2), Vector2(18, 5), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(pied + Vector2(-9, -18), Vector2(7, 18)), Ui.CONTOUR)
		draw_rect(Rect2(pied + Vector2(2, -18), Vector2(7, 18)), Ui.CONTOUR)
		draw_style_box(Ui.boite(couleur, 8, 3), Rect2(pied + Vector2(-14, -48), Vector2(28, 32)))
		if bras != 0.0:
			var h := pied + Vector2(0, -44)
			draw_line(h + Vector2(-12, 0), h + Vector2(-22, -26 - 4 * bras), Ui.CONTOUR, 6)
			draw_line(h + Vector2(12, 0), h + Vector2(22, -26 + 4 * bras), Ui.CONTOUR, 6)
		draw_circle(pied + Vector2(0, -58), 12, Ui.CONTOUR)
		draw_circle(pied + Vector2(0, -58), 9, Color("#f1c27d"))

	func _ellipse(c: Vector2, r: Vector2, couleur: Color) -> void:
		draw_colored_polygon(_points(c, r), couleur)

	func _ellipse_contour(c: Vector2, r: Vector2, couleur: Color, lw: float) -> void:
		var p := _points(c, r)
		p.append(p[0])
		draw_polyline(p, couleur, lw, true)

	func _points(c: Vector2, r: Vector2) -> PackedVector2Array:
		var p := PackedVector2Array()
		for i in 32:
			var a := TAU * i / 32.0
			p.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
		return p
