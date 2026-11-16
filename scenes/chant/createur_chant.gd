extends Control
## Créateur de chants du fan club.
##   Choisis une mesure dans la partition, puis un morceau (le rythme) et une
##   parole. Le tempo règle la vitesse de tout le chant.
##   Écouter (E) : la tribune joue le chant ; ESPACE pour claquer avec elle.
##   ← → : mesure précédente / suivante. Échap : retour au club.
## Le chant enregistré est celui que la tribune chante en duel d'ambiance.
## Règles dans ChantClub. Option « --auto » (captures) : écoute lancée seule.

var compo: Dictionary
var choisie := 0
var modifie := false
var auto := "--auto" in OS.get_cmdline_user_args() or bool(Game.params.get("auto", false))

var _lecteur: ChantLecteur
var _nom: LineEdit
var _etoiles: Label
var _infos: Label
var _boutons_tempo: Dictionary = {}
var _partition: HBoxContainer
var _cartes: Array = []
var _grille_morceaux: GridContainer
var _grille_paroles: GridContainer
var _titre_morceaux: Label
var _titre_paroles: Label
var _karaoke: RichTextLabel
var _verdict: Label
var _btn_ecouter: Button
var _btn_enregistrer: Button
var _btn_moins: Button
var _btn_plus: Button
var _message: Label
var _programme: Array = []


func _ready() -> void:
	var existant := Game.chant_club()
	compo = existant.duplicate(true) if not existant.is_empty() else ChantClub.par_defaut()
	if existant.is_empty():
		compo["nom"] = "Le chant de %s" % ChantClub.nom_crie(Game.fan_club_nom)
		compo["nom"] = String(compo["nom"]).left(ChantClub.NOM_MAX)
		modifie = true
	_lecteur = ChantLecteur.new()
	add_child(_lecteur)
	_lecteur.appui_juge.connect(_sur_appui)
	_lecteur.fini.connect(_sur_fin_ecoute)
	_construire()
	_rafraichir()
	if auto:
		_ecouter.call_deferred()


# ------------------------------------------------------------------ construction

func _construire() -> void:
	var cc := Game.couleurs_club()
	var fond := ColorRect.new()
	fond.color = Color("#1d1850")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var bande := ColorRect.new()
	bande.color = Color(cc[0], 0.35)
	bande.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bande.offset_bottom = 150
	add_child(bande)

	var racine := Ui.vbox(16)
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.offset_left = 32
	racine.offset_right = -32
	racine.offset_top = 22
	racine.offset_bottom = -22
	add_child(racine)

	# --- haut : écusson, titre, nom du chant, difficulté
	var haut := Ui.hbox(18)
	racine.add_child(haut)
	haut.add_child(Ui.ecusson(FanClub.sigle(Game.fan_club_nom), cc[0], cc[1], 84))
	var vt := Ui.vbox(2)
	vt.add_child(Ui.label("LE CHANT DU CLUB", 50, Ui.JAUNE, true, 10))
	vt.add_child(Ui.label("Assemble des morceaux de rythme et des paroles : ta tribune le chantera en duel.", 20, Ui.GRIS))
	haut.add_child(vt)
	haut.add_child(Ui.espace())
	var vn := Ui.vbox(4)
	vn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vn.add_child(Ui.label("Nom du chant", 18, Ui.GRIS))
	_nom = LineEdit.new()
	_nom.max_length = ChantClub.NOM_MAX
	_nom.custom_minimum_size = Vector2(460, 58)
	_nom.add_theme_font_size_override("font_size", 28)
	_nom.text = String(compo.get("nom", ""))
	_nom.text_changed.connect(func(t):
		compo["nom"] = t
		_marquer())
	vn.add_child(_nom)
	haut.add_child(vn)
	var pe := Ui.panneau(Ui.NUIT, 20, 5)
	pe.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pe.tooltip_text = "Difficulté : morceaux choisis, tempo et nombre de claps."
	_etoiles = Ui.label("", 34, Ui.JAUNE, true, 6)
	pe.add_child(_etoiles)
	haut.add_child(pe)

	# --- tempo et nombre de mesures
	var lt := Ui.hbox(12)
	racine.add_child(lt)
	var l_tempo := Ui.label("Tempo", 26, Ui.BLANC, true, 6)
	l_tempo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lt.add_child(l_tempo)
	for t in ChantClub.tempos():
		var b := Ui.bouton("%s · %d" % [t["nom"], int(t["bpm"])], Ui.NUIT_CLAIR, 22)
		b.custom_minimum_size = Vector2(0, 60)
		var id := String(t["id"])
		b.pressed.connect(func(): _choisir_tempo(id))
		if not ChantClub.debloque(t, Game.niveau()):
			b.disabled = true
			b.text = "%s · niv. %d" % [t["nom"], int(t["niveau"])]
			b.tooltip_text = "S'ouvre au niveau %d" % int(t["niveau"])
		lt.add_child(b)
		_boutons_tempo[id] = b
	lt.add_child(Ui.espace())
	_infos = Ui.label("", 22, Ui.GRIS)
	_infos.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lt.add_child(_infos)
	_btn_moins = Ui.bouton("− Mesure", Ui.NUIT_CLAIR, 22)
	_btn_moins.custom_minimum_size = Vector2(0, 60)
	_btn_moins.pressed.connect(_retirer_mesure)
	lt.add_child(_btn_moins)
	_btn_plus = Ui.bouton("+ Mesure", Ui.VIOLET, 22)
	_btn_plus.custom_minimum_size = Vector2(0, 60)
	_btn_plus.pressed.connect(_ajouter_mesure)
	lt.add_child(_btn_plus)

	# --- la partition
	var pp := Ui.panneau(Color(0.1, 0.08, 0.28, 0.95), 26, 5)
	racine.add_child(pp)
	var vp := Ui.vbox(10)
	pp.add_child(vp)
	_karaoke = RichTextLabel.new()
	_karaoke.bbcode_enabled = true
	_karaoke.fit_content = true
	_karaoke.scroll_active = false
	_karaoke.autowrap_mode = TextServer.AUTOWRAP_OFF
	_karaoke.custom_minimum_size = Vector2(0, 52)
	_karaoke.add_theme_font_override("normal_font", Ui.police_titre())
	_karaoke.add_theme_font_size_override("normal_font_size", 38)
	_karaoke.add_theme_constant_override("outline_size", 8)
	_karaoke.add_theme_color_override("font_outline_color", Ui.CONTOUR)
	_karaoke.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vp.add_child(_karaoke)
	_partition = Ui.hbox(12)
	_partition.alignment = BoxContainer.ALIGNMENT_CENTER
	_partition.custom_minimum_size = Vector2(0, 210)
	vp.add_child(_partition)

	# --- les briques : morceaux | paroles
	var bas := Ui.hbox(20)
	bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(bas)
	var pm := Ui.panneau()
	pm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pm.size_flags_stretch_ratio = 1.25
	bas.add_child(pm)
	var vm := Ui.vbox(10)
	pm.add_child(vm)
	_titre_morceaux = Ui.label("", 28, Ui.JAUNE, true, 6)
	vm.add_child(_titre_morceaux)
	var sm := ScrollContainer.new()
	sm.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vm.add_child(sm)
	_grille_morceaux = GridContainer.new()
	_grille_morceaux.columns = 3
	_grille_morceaux.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grille_morceaux.add_theme_constant_override("h_separation", 10)
	_grille_morceaux.add_theme_constant_override("v_separation", 10)
	sm.add_child(_grille_morceaux)

	var pa := Ui.panneau()
	pa.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bas.add_child(pa)
	var va := Ui.vbox(10)
	pa.add_child(va)
	_titre_paroles = Ui.label("", 28, Ui.JAUNE, true, 6)
	va.add_child(_titre_paroles)
	var sp := ScrollContainer.new()
	sp.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	va.add_child(sp)
	_grille_paroles = GridContainer.new()
	_grille_paroles.columns = 2
	_grille_paroles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grille_paroles.add_theme_constant_override("h_separation", 10)
	_grille_paroles.add_theme_constant_override("v_separation", 10)
	sp.add_child(_grille_paroles)

	# --- actions
	var ba := Ui.hbox(18)
	ba.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(ba)
	var b_retour := Ui.bouton("Fan Club", Ui.NUIT_CLAIR, 28)
	b_retour.custom_minimum_size = Vector2(220, 84)
	b_retour.pressed.connect(_retour)
	ba.add_child(b_retour)
	var b_hasard := Ui.bouton("Au hasard", Ui.VIOLET, 28)
	b_hasard.custom_minimum_size = Vector2(220, 84)
	b_hasard.tooltip_text = "Un chant tiré au hasard parmi tes morceaux et paroles"
	b_hasard.pressed.connect(_hasard)
	ba.add_child(b_hasard)
	_btn_ecouter = Ui.bouton("Écouter (E)", Ui.BLEU, 28)
	_btn_ecouter.custom_minimum_size = Vector2(260, 84)
	_btn_ecouter.focus_mode = Control.FOCUS_NONE
	_btn_ecouter.pressed.connect(_ecouter)
	ba.add_child(_btn_ecouter)
	_verdict = Ui.label("", 30, Ui.BLANC, true, 8)
	_verdict.custom_minimum_size = Vector2(190, 0)
	_verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_verdict.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ba.add_child(_verdict)
	_btn_enregistrer = Ui.bouton("Enregistrer", Ui.VERT, 28)
	Ui.colorer_bouton(_btn_enregistrer, Ui.VERT, true)
	_btn_enregistrer.custom_minimum_size = Vector2(260, 84)
	_btn_enregistrer.pressed.connect(_enregistrer)
	ba.add_child(_btn_enregistrer)

	_message = Ui.label("", 28, Ui.BLANC, true, 8)
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.offset_top = 160
	_message.offset_left = -700
	_message.offset_right = 700
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message.modulate.a = 0.0
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)


# ------------------------------------------------------------------ affichage

func _rafraichir() -> void:
	var mesures: Array = compo["mesures"]
	choisie = clampi(choisie, 0, mesures.size() - 1)
	_programme = ChantClub.programme(compo, Game.fan_club_nom)
	# partition
	for c in _cartes:
		c.queue_free()
	_cartes.clear()
	for i in mesures.size():
		var carte := CarteMesure.new()
		carte.index = i
		carte.mesure = _programme[i]
		carte.custom_minimum_size = Vector2(218, 200)
		carte.choisie = i == choisie
		carte.clic.connect(_choisir_mesure)
		_partition.add_child(carte)
		_cartes.append(carte)
	# tempo
	for id in _boutons_tempo:
		var b: Button = _boutons_tempo[id]
		var actif: bool = String(id) == String(compo["tempo"])
		Ui.colorer_bouton(b, Ui.JAUNE if actif else Ui.NUIT_CLAIR, actif)
	_btn_moins.disabled = mesures.size() <= ChantClub.mesures_min()
	_btn_plus.disabled = mesures.size() >= ChantClub.mesures_max()
	var e := ChantClub.etoiles(compo)
	_etoiles.text = "★".repeat(e) + "☆".repeat(5 - e)
	_infos.text = "%d mesures · %d claps · %.1f s par couplet" % [mesures.size(), ChantClub.nb_appuis(compo), ChantClub.duree(compo)]
	_construire_briques()
	_afficher_karaoke(choisie, -1)
	_btn_enregistrer.text = "Enregistrer" if modifie else "Enregistré ✓"


func _construire_briques() -> void:
	var m: Dictionary = compo["mesures"][choisie]
	_titre_morceaux.text = "MORCEAUX · mesure %d" % (choisie + 1)
	_titre_paroles.text = "PAROLES · mesure %d" % (choisie + 1)
	for c in _grille_morceaux.get_children():
		c.queue_free()
	for mo in ChantClub.morceaux():
		var id := String(mo["id"])
		var ouvert := ChantClub.debloque(mo, Game.niveau())
		var actif := id == String(m["morceau"])
		var b := Ui.bouton("", Ui.JAUNE if actif else Ui.NUIT_CLAIR, 20)
		if actif:
			Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.custom_minimum_size = Vector2(0, 74)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%s\n%s" % [mo["nom"], "★".repeat(int(mo["difficulte"]))] if ouvert else "%s\nniveau %d" % [mo["nom"], int(mo["niveau"])]
		b.tooltip_text = String(mo["description"])
		b.disabled = not ouvert
		b.pressed.connect(func(): _choisir_morceau(id))
		_grille_morceaux.add_child(b)
	for c in _grille_paroles.get_children():
		c.queue_free()
	var sans := Ui.bouton("(sans parole)", Ui.JAUNE if String(m["parole"]) == "" else Ui.NUIT_CLAIR, 20)
	if String(m["parole"]) == "":
		Ui.colorer_bouton(sans, Ui.JAUNE, true)
	sans.custom_minimum_size = Vector2(0, 56)
	sans.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sans.pressed.connect(func(): _choisir_parole(""))
	_grille_paroles.add_child(sans)
	for pa in ChantClub.paroles():
		var id := String(pa["id"])
		var ouvert := ChantClub.debloque(pa, Game.niveau())
		var actif := id == String(m["parole"])
		var b := Ui.bouton("", Ui.NUIT_CLAIR, 20)
		if actif:
			Ui.colorer_bouton(b, Ui.JAUNE, true)
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		b.text = ChantClub.texte_parole(id, Game.fan_club_nom) if ouvert else "niveau %d" % int(pa["niveau"])
		b.disabled = not ouvert
		b.pressed.connect(func(): _choisir_parole(id))
		_grille_paroles.add_child(b)


## La ligne de la mesure `i` ; `mot` : l'index du clap en cours (-1 : aucun).
func _afficher_karaoke(i: int, mot: int) -> void:
	if i < 0 or i >= _programme.size():
		_karaoke.text = ""
		return
	var mots: Array = _programme[i]["mots"]
	var parts: Array = []
	for k in mots.size():
		if String(mots[k]) == "":
			continue
		var c := "#ffd23f" if k == mot else ("#ffffff" if k < mot or mot < 0 else "#b9b5e0")
		parts.append("[color=%s]%s[/color]" % [c, mots[k]])
	var ligne := " ".join(parts) if not parts.is_empty() else "[color=#b9b5e0](on frappe sans paroles)[/color]"
	_karaoke.text = "[center]♪  %s  ♪[/center]" % ligne


# ------------------------------------------------------------------ actions

func _marquer() -> void:
	modifie = true
	_btn_enregistrer.text = "Enregistrer"


func _choisir_mesure(i: int) -> void:
	choisie = i
	for c in _cartes:
		c.choisie = c.index == i
		c.queue_redraw()
	_construire_briques()
	_afficher_karaoke(choisie, -1)


func _choisir_morceau(id: String) -> void:
	compo["mesures"][choisie]["morceau"] = id
	_marquer()
	_arreter_ecoute()
	_rafraichir()
	_cartes[choisie].pivot_offset = _cartes[choisie].custom_minimum_size / 2.0
	Ui.pop(_cartes[choisie], 1.06)


func _choisir_parole(id: String) -> void:
	compo["mesures"][choisie]["parole"] = id
	_marquer()
	_arreter_ecoute()
	_rafraichir()


func _choisir_tempo(id: String) -> void:
	compo["tempo"] = id
	_marquer()
	_arreter_ecoute()
	_rafraichir()


func _ajouter_mesure() -> void:
	var mesures: Array = compo["mesures"]
	if mesures.size() >= ChantClub.mesures_max():
		return
	mesures.insert(choisie + 1, (mesures[choisie] as Dictionary).duplicate())
	choisie += 1
	_marquer()
	_arreter_ecoute()
	_rafraichir()


func _retirer_mesure() -> void:
	var mesures: Array = compo["mesures"]
	if mesures.size() <= ChantClub.mesures_min():
		return
	mesures.remove_at(choisie)
	_marquer()
	_arreter_ecoute()
	_rafraichir()


func _hasard() -> void:
	var n := Game.niveau()
	var mo := ChantClub.morceaux().filter(func(x): return ChantClub.debloque(x, n))
	var pa := ChantClub.paroles().filter(func(x): return ChantClub.debloque(x, n))
	var nb: int = compo["mesures"].size()
	var mesures: Array = []
	for i in nb:
		var m: Dictionary = mo[randi() % mo.size()]
		# On finit le couplet sur un morceau qui respire ou qui appelle.
		if i == nb - 1:
			var fins := mo.filter(func(x): return ChantClub.appuis(String(x["id"])).size() <= 2)
			if not fins.is_empty():
				m = fins[randi() % fins.size()]
		mesures.append({"morceau": String(m["id"]), "parole": String(pa[randi() % pa.size()]["id"])})
	compo["mesures"] = mesures
	_marquer()
	_arreter_ecoute()
	_rafraichir()


func _enregistrer() -> void:
	compo["nom"] = _nom.text.strip_edges()
	var err := Game.enregistrer_chant(compo)
	if not err.is_empty():
		_annoncer(String(err[0]), Ui.ROUGE)
		return
	compo = Game.chant_club().duplicate(true)
	modifie = false
	_rafraichir()
	_annoncer("« %s » est le chant du club ! Ta tribune le chantera en duel." % compo["nom"], Ui.VERT)


func _retour() -> void:
	_arreter_ecoute()
	Game.aller(Game.SCENE_CLUB)


func _ecouter() -> void:
	if _lecteur.en_cours:
		_arreter_ecoute()
		return
	_lecteur.lancer(ChantClub.vers_fiche(compo, true), 0.0, 2, 0.6)
	_btn_ecouter.text = "Arrêter (E)"
	_verdict.text = "ESPACE !"
	_verdict.add_theme_color_override("font_color", Ui.GRIS)


func _arreter_ecoute() -> void:
	if _lecteur.en_cours:
		_lecteur.arreter()
	_sur_fin_ecoute()


func _sur_fin_ecoute() -> void:
	_btn_ecouter.text = "Écouter (E)"
	_verdict.text = ""
	for c in _cartes:
		c.lecture = -1.0
		c.queue_redraw()
	_afficher_karaoke(choisie, -1)


func _sur_appui(r: Dictionary) -> void:
	var textes := {"parfait": ["PARFAIT !", Ui.JAUNE], "bien": ["BIEN", Ui.VERT], "rate": ["RATÉ", Ui.ROUGE], "hors": ["…", Ui.GRIS]}
	var v: Array = textes.get(String(r["note"]), textes["hors"])
	_verdict.text = v[0]
	_verdict.add_theme_color_override("font_color", v[1])
	_verdict.pivot_offset = _verdict.size / 2.0
	Ui.pop(_verdict, 1.2)


func _process(_d: float) -> void:
	if not _lecteur.en_cours or _lecteur.rythme == null:
		return
	var r := _lecteur.rythme
	var d_mesure := r.duree_temps() * ChantClub.TEMPS
	var t := _lecteur.temps_entendu() - r.debut
	if t < 0.0:
		return
	var nb := _cartes.size()
	var tour := t / d_mesure
	var i := int(tour) % nb
	var avance := fmod(tour, 1.0)
	for c in _cartes:
		c.lecture = avance if c.index == i else -1.0
		c.queue_redraw()
	# le mot en cours : le dernier clap passé de cette mesure
	var pas := int(avance * ChantClub.PAS)
	var ap: Array = _programme[i]["appuis"]
	var mot := -1
	for k in ap.size():
		if int(ap[k]) <= pas:
			mot = k
	_afficher_karaoke(i, mot)


func _unhandled_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_cancel"):
		_retour()
		get_viewport().set_input_as_handled()
		return
	if _nom.has_focus():
		return
	if ev is InputEventKey and ev.pressed and not ev.echo:
		match (ev as InputEventKey).keycode:
			KEY_SPACE:
				if _lecteur.en_cours:
					_lecteur.juger_appui()
				else:
					_ecouter()
			KEY_E:
				_ecouter()
			KEY_LEFT:
				_choisir_mesure(maxi(0, choisie - 1))
			KEY_RIGHT:
				_choisir_mesure(mini(_cartes.size() - 1, choisie + 1))
			_:
				return
		get_viewport().set_input_as_handled()


func _annoncer(texte: String, couleur: Color) -> void:
	_message.text = texte
	_message.add_theme_color_override("font_color", couleur)
	var t := create_tween()
	_message.modulate.a = 1.0
	t.tween_interval(2.4)
	t.tween_property(_message, "modulate:a", 0.0, 0.5)


# ------------------------------------------------------------------ carte d'une mesure

## Une mesure de la partition : son numéro, le nom du morceau, la grille des
## 8 pas (gros ronds = les claps de la tribune, traits = le tambour) et la parole.
class CarteMesure extends Control:
	signal clic(index: int)
	var index := 0
	var mesure: Dictionary = {}
	var choisie := false
	var lecture := -1.0   # 0..1 pendant l'écoute de cette mesure
	const FOND := Color("#3a3290")

	func _gui_input(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			clic.emit(index)
			accept_event()

	func _ready() -> void:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func _draw() -> void:
		var r := Rect2(Vector2(4, 4), size - Vector2(8, 8))
		var fond := FOND.lightened(0.12) if lecture >= 0.0 else FOND
		draw_style_box(Ui.boite(fond, 20, 5, 0, Ui.JAUNE if choisie else Ui.CONTOUR), r)
		var ft := Ui.police_titre()
		var fx := Ui.police_texte()
		draw_string_outline(ft, Vector2(18, 44), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, 6, Ui.CONTOUR)
		draw_string(ft, Vector2(18, 44), str(index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Ui.JAUNE if choisie else Ui.BLANC)
		draw_string(fx, Vector2(52, 40), String(mesure.get("nom", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 60, 16, Ui.BLANC)
		# grille des pas
		var x0 := 20.0
		var w := (size.x - 40.0) / ChantClub.PAS
		var y := 100.0
		var tambour := {}
		for f in mesure.get("frappes", []):
			if f["voix"] == "T":
				tambour[int(f["pas"])] = float(f["force"])
		for p in ChantClub.PAS:
			var cx := x0 + w * (p + 0.5)
			if p % 2 == 0:
				draw_line(Vector2(cx, y - 30), Vector2(cx, y + 30), Color(1, 1, 1, 0.12), 2)
			if tambour.has(p):
				draw_rect(Rect2(cx - 4, y + 20, 8, 12 * tambour[p] + 4), Color("#ff8a2b"))
			if p in mesure.get("appuis", []):
				draw_circle(Vector2(cx, y), 11, Ui.CONTOUR)
				draw_circle(Vector2(cx, y), 8, Ui.BLEU.lightened(0.25))
			else:
				draw_circle(Vector2(cx, y), 3, Color(1, 1, 1, 0.25))
		if lecture >= 0.0:
			var lx := x0 + (size.x - 40.0) * lecture
			draw_line(Vector2(lx, y - 36), Vector2(lx, y + 36), Ui.JAUNE, 4)
		# parole
		var texte := String(mesure.get("texte", ""))
		if texte == "":
			texte = "—"
		draw_string(fx, Vector2(16, size.y - 30), texte, HORIZONTAL_ALIGNMENT_CENTER, size.x - 32, 18, Ui.GRIS if not choisie else Ui.BLANC)
