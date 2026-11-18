extends Control
## Le local du club : ce que le fan club achète avec ses Jetons pour lui-même.
## Onglet « Le local » : construire la salle des chants, la salle des trophées et
## le parking du car, puis les décorer (règles dans scripts/club/local_club.gd).
## Onglet « Matériel de tribune » : écharpes, drapeaux, tambours, bâche,
## confettis, dessinés dans notre tribune en duel (aucun effet sur le score ;
## règles dans scripts/club/materiel.gd). À gauche, un aperçu de la tribune.

const Duel := preload("res://scenes/duel/duel.gd")
const SonsScript := preload("res://scripts/audio/sons.gd")
const ONGLETS := [["local", "Le local"], ["materiel", "Matériel de tribune"]]


## Faux duel pour l'aperçu : Duel.Decor lit seulement `jauge` (et `fiche` hors stade).
class Apercu extends RefCounted:
	var jauge := 60.0
	var fiche := {}


var _onglet := "local"
var _boutons_onglets: Dictionary = {}
var _jetons: Label
var _liste: VBoxContainer
var _cadre: Control
var _decor: Control
var _dessin: LocalDessin
var _titre_gauche: Label
var _aide: Label
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
	_titre_gauche = Ui.label("", 34, Ui.BLANC, true, 6)
	vg.add_child(_titre_gauche)
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
	_dessin = LocalDessin.new()
	_dessin.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dessin.c1 = cc[0]
	_dessin.c2 = cc[1]
	_dessin.nom_club = Game.fan_club_nom
	_cadre.add_child(_dessin)
	_cadre.resized.connect(_placer_apercu)
	_aide = Ui.label("", 19, Ui.GRIS)
	_aide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vg.add_child(_aide)

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
	if str(Game.params.get("onglet", "")) in ["local", "materiel"]:
		_onglet = str(Game.params["onglet"])
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
	for c in _liste.get_children():
		_liste.remove_child(c)
		c.queue_free()
	var local := _onglet == "local"
	_decor.visible = not local
	_dessin.visible = local
	if local:
		_titre_gauche.text = tr("LE LOCAL DES %s") % Game.fan_club_nom.to_upper() if Game.fan_club_nom != "" else tr("LE LOCAL")
		_aide.text = tr("Pur décor : agrandir et décorer le local ne change ni les duels, ni les gains. Jetons déjà mis dans le local : %d") % LocalClub.valeur(Game.local_club)
		_dessin.etat = Game.local_club
		_dessin.chiffres = {"tampons": Game.tampons.size(), "souvenirs": Souvenirs.nombre(Game.collection), "succes": Game.succes.size()}
		_remplir_local()
		return
	_titre_gauche.text = tr("TA TRIBUNE EN DUEL")
	_aide.text = tr("Pur décor : le matériel ne change ni la jauge, ni les points. En duel, il prend les couleurs de l'équipe que tu soutiens.")
	_decor.materiel = Materiel.affiche(Game.materiel)
	_liste.add_child(_carte_saison())
	_liste.add_child(Ui.label("MATÉRIEL DE TRIBUNE", 34, Ui.JAUNE, true, 6))
	for o in Materiel.OBJETS:
		_liste.add_child(_carte_objet(o))


## Guirlande du mois (seulement ce mois-ci) et guirlandes déjà achetées.
func _carte_saison() -> Control:
	var mois := int(Time.get_date_dict_from_system()["month"])
	var o := Materiel.du_mois(mois)
	var p := Ui.panneau(Color("#3a2a7a"), 18, 4)
	var v := Ui.vbox(6)
	p.add_child(v)
	v.add_child(Ui.label("GUIRLANDE DU MOIS", 26, Ui.JAUNE, true, 6))
	var h := Ui.hbox(10)
	v.add_child(h)
	var nom := Ui.label(o["nom"], 22, Ui.BLANC, true, 4)
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nom)
	var prix := Materiel.prix_suivant(Game.materiel, o["id"], mois)
	var b := Ui.bouton(tr("Acheter · %d Jetons") % prix if prix >= 0 else tr("Dans ta collection"), Ui.VERT, 20)
	if prix >= 0:
		Ui.colorer_bouton(b, Ui.VERT, true)
	b.disabled = prix < 0 or prix > Game.jetons
	b.pressed.connect(func(): _acheter(o["id"], p))
	h.add_child(b)
	var txt := Ui.label("En vente seulement ce mois-ci, puis à toi pour toujours. Une guirlande à la fois dans la tribune.", 16, Ui.GRIS)
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(txt)
	var miennes := Materiel.guirlandes(Game.materiel)
	if not miennes.is_empty():
		var grille := GridContainer.new()
		grille.columns = 2
		grille.add_theme_constant_override("h_separation", 8)
		grille.add_theme_constant_override("v_separation", 8)
		v.add_child(grille)
		for g in miennes:
			var gid: String = g["id"]
			var on := Materiel.actif(Game.materiel, gid)
			var bg := Ui.bouton(("✓ " if on else "") + tr(g["nom"]), Ui.BLEU if on else Ui.NUIT, 17)  # sans_traduction
			bg.custom_minimum_size = Vector2(318, 48)
			bg.tooltip_text = "Ranger ou ressortir ce matériel dans la tribune"
			bg.pressed.connect(func():
				Game.basculer_materiel(gid)
				_remplir())
			grille.add_child(bg)
	return p


func _remplir_local() -> void:
	for s in LocalClub.SALLES:
		var id: String = s["id"]
		var n := LocalClub.niveau(Game.local_club, id)
		var p := Ui.panneau(Ui.NUIT_CLAIR, 18, 4)
		_liste.add_child(p)
		var v := Ui.vbox(6)
		p.add_child(v)
		var h := Ui.hbox(10)
		v.add_child(h)
		var titre := Ui.label(s["nom"], 26, Ui.BLANC if n > 0 else Ui.GRIS, true, 6)
		titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(titre)
		var prix := LocalClub.prix_salle(Game.local_club, id)
		if prix >= 0:
			var b := Ui.bouton(tr("Construire · %d") % prix if n == 0 else tr("Agrandir · %d") % prix, Ui.VERT, 20)
			Ui.colorer_bouton(b, Ui.VERT, true)
			b.disabled = prix > Game.jetons
			if b.disabled:
				b.tooltip_text = tr("Il te faut %d Jetons") % prix
			b.pressed.connect(func():
				if Game.acheter_salle(id):
					_achat(p))
			h.add_child(b)
		elif n == LocalClub.NIVEAU_MAX:
			h.add_child(Ui.label("★★", 24, Ui.JAUNE, true, 4))  # sans_traduction
		var txt := Ui.label(s["texte"], 17, Ui.GRIS)
		txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(txt)
		if n == 0:
			continue
		var grille := GridContainer.new()
		grille.columns = 2
		grille.add_theme_constant_override("h_separation", 8)
		grille.add_theme_constant_override("v_separation", 8)
		v.add_child(grille)
		for o in LocalClub.deco_de(id):
			var did: String = o["id"]
			var pd := LocalClub.prix_deco(Game.local_club, did)
			var bd := Ui.bouton("", Ui.BLEU, 18)
			bd.custom_minimum_size = Vector2(318, 52)
			if pd < 0:
				bd.text = "✓ " + tr(o["nom"])  # sans_traduction
				bd.disabled = true
			else:
				bd.text = tr("%s · %d") % [tr(o["nom"]), pd]
				bd.disabled = pd > Game.jetons
				if bd.disabled:
					bd.tooltip_text = tr("Il te faut %d Jetons") % pd
			bd.pressed.connect(func():
				if Game.acheter_deco(did):
					_achat(p))
			grille.add_child(bd)


func _achat(carte: Control) -> void:
	_sons.jouer("ui_parfait")
	Ui.pop(carte, 1.05, 0.25)
	Ui.pop(_jetons)
	_remplir()


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
