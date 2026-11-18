extends Control
## Le local du club : ce que le fan club achète avec ses Jetons pour lui-même.
## Onglet « Matériel de tribune » : écharpes, drapeaux, tambours, bâche,
## confettis, dessinés dans notre tribune en duel (aucun effet sur le score ;
## règles dans scripts/club/materiel.gd). À gauche, un aperçu de la tribune.

const Duel := preload("res://scenes/duel/duel.gd")
const SonsScript := preload("res://scripts/audio/sons.gd")
const ONGLETS := [["materiel", "Matériel de tribune"]]


## Faux duel pour l'aperçu : Duel.Decor lit seulement `jauge` (et `fiche` hors stade).
class Apercu extends RefCounted:
	var jauge := 60.0
	var fiche := {}


var _onglet := "materiel"
var _boutons_onglets: Dictionary = {}
var _jetons: Label
var _liste: VBoxContainer
var _cadre: Control
var _decor: Control
var _apercu := Apercu.new()
var _sons: Node
var _t := 0.0


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color("#2f6bd8")
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
	haut.add_child(Ui.label("LE LOCAL DU CLUB", 60, Ui.JAUNE, true, 10))
	for o in ONGLETS:
		var b := Ui.bouton(o[1], Ui.NUIT, 26)
		b.custom_minimum_size = Vector2(300, 70)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func(): _choisir(o[0]))
		_boutons_onglets[o[0]] = b
		haut.add_child(b)
	haut.add_child(Ui.espace())
	var jet := Ui.panneau(Ui.NUIT, 20, 5)
	jet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var hj := Ui.hbox(8)
	hj.add_child(Ui.icone("jeton", 36))
	_jetons = Ui.label("", 28, Ui.JAUNE, true, 6)
	hj.add_child(_jetons)
	jet.add_child(hj)
	haut.add_child(jet)

	var corps := Ui.hbox(24)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(corps)

	# aperçu de la tribune (le décor du duel, en petit)
	var pg := Ui.panneau()
	pg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	corps.add_child(pg)
	var vg := Ui.vbox(12)
	pg.add_child(vg)
	vg.add_child(Ui.label("TA TRIBUNE EN DUEL", 34, Ui.BLANC, true, 6))
	_cadre = Control.new()
	_cadre.clip_contents = true
	_cadre.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cadre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vg.add_child(_cadre)
	_decor = Duel.Decor.new()
	_decor.duel = _apercu
	_decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_decor.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var cc := Game.couleurs_club()
	_decor.c_nous = Duel._vive(cc[0], cc[1], Ui.BLEU)
	_decor.c_nous2 = cc[1]
	_decor.c_eux = Ui.ROUGE if not _decor.c_nous.is_equal_approx(Ui.ROUGE) else Ui.JAUNE
	_decor.c_eux2 = Ui.BLANC
	_decor.texte_tifo = Game.fan_club_nom.to_upper()
	_decor.size = Vector2(1920, 1080)
	_cadre.add_child(_decor)
	_cadre.resized.connect(_placer_apercu)
	var aide := Ui.label("Pur décor : le matériel ne change ni la jauge, ni les points. En duel, il prend les couleurs de l'équipe que tu soutiens.", 19, Ui.GRIS)
	aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vg.add_child(aide)

	var pd := Ui.panneau()
	pd.custom_minimum_size = Vector2(700, 0)
	corps.add_child(pd)
	var sd := ScrollContainer.new()
	sd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pd.add_child(sd)
	_liste = Ui.vbox(12)
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sd.add_child(_liste)

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour au fan club", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(func(): Game.aller(Game.SCENE_CLUB))
	bas.add_child(retour)

	_sons = SonsScript.new()
	add_child(_sons)
	_choisir(_onglet)


func _process(delta: float) -> void:
	# l'ambiance monte et redescend : tambours plus ou moins vite, confettis à fond
	_t += delta
	_apercu.jauge = 35.0 + 55.0 * sin(_t * 0.5)


func _placer_apercu() -> void:
	var k := minf(_cadre.size.x / 1920.0, _cadre.size.y / 1080.0)
	_decor.scale = Vector2(k, k)
	_decor.position = (_cadre.size - Vector2(1920, 1080) * k) / 2.0


func _choisir(o: String) -> void:
	_onglet = o
	for k in _boutons_onglets:
		var b: Button = _boutons_onglets[k]
		Ui.colorer_bouton(b, Ui.JAUNE if k == o else Ui.NUIT, k == o)
		if k != o:
			for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.remove_theme_color_override(c)
	_remplir()


func _remplir() -> void:
	_jetons.text = "%d" % Game.jetons
	_decor.materiel = Materiel.affiche(Game.materiel)
	for c in _liste.get_children():
		_liste.remove_child(c)
		c.queue_free()
	_liste.add_child(Ui.label("MATÉRIEL DE TRIBUNE", 34, Ui.JAUNE, true, 6))
	for o in Materiel.OBJETS:
		_liste.add_child(_carte_objet(o))


func _carte_objet(o: Dictionary) -> Control:
	var id: String = o["id"]
	var n := Materiel.niveau(Game.materiel, id)
	var p := Ui.panneau(Ui.NUIT_CLAIR, 18, 4)
	var v := Ui.vbox(6)
	p.add_child(v)
	var h := Ui.hbox(10)
	v.add_child(h)
	var titre := Ui.label(o["nom"], 26, Ui.BLANC, true, 6)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(titre)
	var etoiles := ""
	for i in Materiel.NIVEAU_MAX:
		etoiles += "★" if i < n else "☆"  # sans_traduction
	h.add_child(Ui.label(etoiles, 26, Ui.JAUNE, true, 4))
	var txt := Ui.label(o["texte"], 18, Ui.GRIS)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(txt)
	var hb := Ui.hbox(10)
	v.add_child(hb)
	var prix := Materiel.prix_suivant(Game.materiel, id)
	var b := Ui.bouton("", Ui.VERT, 22)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if prix < 0:
		b.text = tr("Niveau max")
		b.disabled = true
	else:
		b.text = tr("Acheter · %d Jetons") % prix if n == 0 else tr("Niveau %d · %d Jetons") % [n + 1, prix]
		b.disabled = prix > Game.jetons
		if prix > Game.jetons:
			b.tooltip_text = tr("Il te faut %d Jetons") % prix
		Ui.colorer_bouton(b, Ui.VERT, true)
	b.pressed.connect(func(): _acheter(id, p))
	hb.add_child(b)
	if n > 0:
		var on := Materiel.actif(Game.materiel, id)
		var t := Ui.bouton(tr("Installé") if on else tr("Rangé"), Ui.BLEU if on else Ui.NUIT, 22)
		t.custom_minimum_size = Vector2(170, 0)
		t.tooltip_text = "Ranger ou ressortir ce matériel dans la tribune"
		t.pressed.connect(func():
			Game.basculer_materiel(id)
			_remplir())
		hb.add_child(t)
	return p


func _acheter(id: String, carte: Control) -> void:
	if not Game.acheter_materiel(id):
		return
	_sons.jouer("ui_parfait")
	Ui.pop(carte, 1.05, 0.25)
	Ui.pop(_jetons)
	_remplir()
