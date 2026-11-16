extends Control
## « Crée ton fan club » : nom, deux couleurs, écusson dessiné.
## Les trois FANZZY de la tribune deviennent les membres fondateurs.

const IDEES := [
	"Ultras du Canal", "Les Gosiers d'Acier", "Brigade du Kop", "Les Écharpes Folles",  # sans_traduction
	"Tribune du Phare", "Les Tambours du Port", "Virage Soleil", "Les Insomniaques",  # sans_traduction
	"Club des Cent Voix", "Les Rugissants", "Kop des Ruelles", "Les Mouettes Hurlantes",  # sans_traduction
]

var _nom: LineEdit
var _c1 := FanClub.COULEURS[0]
var _c2 := FanClub.COULEURS[7]
var _ecusson: Ui.Ecusson
var _banniere: PanelContainer
var _titre_banniere: Label
var _nuanciers: Array = []
var _fonder: Button


func _ready() -> void:
	if Game.club_cree():
		var cc: Array = Game.club["couleurs"]
		_c1 = cc[0]
		_c2 = cc[1]
	var fond := ColorRect.new()
	fond.color = Color("#5b3fd1")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)

	var racine := Ui.vbox(22)
	racine.set_anchors_preset(Control.PRESET_FULL_RECT)
	racine.offset_left = 80
	racine.offset_right = -80
	racine.offset_top = 40
	racine.offset_bottom = -40
	add_child(racine)

	var titre := Ui.label("CRÉE TON FAN CLUB", 72, Ui.JAUNE, true, 12)
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(titre)
	var st := Ui.label("Choisis un nom et tes couleurs. Tes trois FANZZY de tribune seront les membres fondateurs.", 24, Ui.BLANC)
	st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	racine.add_child(st)

	var milieu := Ui.hbox(40)
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(milieu)

	# --- à gauche : le formulaire
	var form := Ui.panneau()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milieu.add_child(form)
	var vf := Ui.vbox(16)
	form.add_child(Ui.marge(vf, 12, 8, 12, 8))
	vf.add_child(Ui.label("Nom du club", 30, Ui.BLANC, true, 6))
	var hn := Ui.hbox(12)
	vf.add_child(hn)
	_nom = LineEdit.new()
	_nom.text = Game.fan_club_nom
	_nom.max_length = 28
	_nom.placeholder_text = "Ex. : Ultras du Canal"
	_nom.custom_minimum_size = Vector2(0, 76)
	_nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_nom.add_theme_font_override("font", Ui.police_titre())
	_nom.add_theme_font_size_override("font_size", 34)
	_nom.add_theme_color_override("font_color", Ui.CONTOUR)
	_nom.add_theme_stylebox_override("normal", Ui.boite(Ui.BLANC, 16, 5))
	_nom.add_theme_stylebox_override("focus", Ui.boite(Ui.BLANC, 16, 5, 0, Ui.JAUNE))
	_nom.text_changed.connect(func(_t): _maj_apercu())
	hn.add_child(_nom)
	var idee := Ui.bouton("Une idée ?", Ui.VIOLET, 24)
	idee.custom_minimum_size = Vector2(200, 76)
	idee.pressed.connect(func():
		var choix := IDEES.filter(func(n): return n != _nom.text)
		_nom.text = choix.pick_random()
		_maj_apercu())
	hn.add_child(idee)

	for i in 2:
		vf.add_child(Ui.label("Couleur principale" if i == 0 else "Deuxième couleur", 26, Ui.BLANC, true, 6))
		var hc := Ui.hbox(12)
		vf.add_child(hc)
		var boutons: Array = []
		for col in FanClub.COULEURS:
			var b := Button.new()
			b.custom_minimum_size = Vector2(64, 64)
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.tooltip_text = col
			var c: String = col
			var rang := i
			b.pressed.connect(func(): _choisir(rang, c))
			hc.add_child(b)
			boutons.append(b)
		_nuanciers.append(boutons)

	vf.add_child(Ui.espace())
	vf.add_child(Ui.label("Membres fondateurs", 26, Ui.BLANC, true, 6))
	var hm := Ui.hbox(16)
	vf.add_child(hm)
	for id in Game.equipe:
		var z := Game.fanzzy_par_id(str(id))
		if z.is_empty():
			continue
		var carte := Ui.panneau(Ui.NUIT_CLAIR, 18, 4)
		var vm := Ui.vbox(4)
		carte.add_child(vm)
		var t := TextureRect.new()
		t.texture = Game.texture_fanzzy(z["id"], true)
		t.custom_minimum_size = Vector2(120, 120)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		vm.add_child(t)
		var n := Ui.label(z["nom"], 16, Ui.BLANC, true)
		n.custom_minimum_size = Vector2(150, 0)
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vm.add_child(n)
		hm.add_child(carte)

	# --- à droite : l'aperçu
	var apercu := Ui.vbox(24)
	apercu.custom_minimum_size = Vector2(620, 0)
	apercu.alignment = BoxContainer.ALIGNMENT_CENTER
	milieu.add_child(apercu)
	_ecusson = Ui.ecusson("UC", Color(_c1), Color(_c2), 260) as Ui.Ecusson  # sans_traduction
	_ecusson.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	apercu.add_child(_ecusson)
	_banniere = PanelContainer.new()
	apercu.add_child(_banniere)
	_titre_banniere = Ui.label("", 44, Ui.BLANC, true, 10)
	_titre_banniere.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titre_banniere.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banniere.add_child(_titre_banniere)

	# --- en bas
	var bas := Ui.hbox(24)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(260, 92)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CLUB if Game.club_cree() else Game.SCENE_TITRE))
	bas.add_child(retour)
	_fonder = Ui.bouton("FONDER LE CLUB !" if not Game.club_cree() else "ENREGISTRER", Ui.JAUNE, 40)
	Ui.colorer_bouton(_fonder, Ui.JAUNE, true)
	_fonder.custom_minimum_size = Vector2(560, 92)
	_fonder.pressed.connect(_valider)
	bas.add_child(_fonder)
	_maj_apercu()


func _choisir(rang: int, couleur: String) -> void:
	if rang == 0:
		_c1 = couleur
	else:
		_c2 = couleur
	_maj_apercu()


func _maj_apercu() -> void:
	var nom := _nom.text.strip_edges()
	_ecusson.sigle = FanClub.sigle(nom)
	_ecusson.c1 = Color(_c1)
	_ecusson.c2 = Color(_c2)
	_ecusson.queue_redraw()
	_titre_banniere.text = nom.to_upper() if nom != "" else "TON CLUB"
	_banniere.add_theme_stylebox_override("panel", Ui.boite(Color(_c1), 22, 6, 8, Color(_c2) if _c2 != _c1 else Ui.CONTOUR))
	for i in _nuanciers.size():
		var choisi := _c1 if i == 0 else _c2
		for b in _nuanciers[i]:
			var sel: bool = b.tooltip_text == choisi
			var col := Color(b.tooltip_text)
			b.add_theme_stylebox_override("normal", Ui.boite(col, 32, 7 if sel else 4, 0, Ui.JAUNE if sel else Ui.CONTOUR))
			b.add_theme_stylebox_override("hover", Ui.boite(col.lightened(0.15), 32, 5, 0))
			b.add_theme_stylebox_override("pressed", Ui.boite(col, 32, 7, 0, Ui.JAUNE))
	_fonder.disabled = nom.length() < 3


func _valider() -> void:
	var nom := _nom.text.strip_edges()
	if nom.length() < 3:
		return
	if Game.club_cree():
		Game.fan_club_nom = nom
		Game.club["couleurs"] = [_c1, _c2]
		Game.sauver()
	else:
		Game.creer_club(nom, _c1, _c2)
	Game.aller(Game.SCENE_CLUB)
