extends CanvasLayer
## Tutoriel guidé du premier lancement : une bulle avec ton premier FANZZY
## qui t'accompagne d'écran en écran, et un cadre clignotant sur le bouton
## à presser.
##
## Parcours : fonder son fan club → visiter le QG → choisir ses équipes
## favorites → choisir un match → faire un prono → choisir où le suivre →
## voyage → tribune → premier duel → cadeau de bienvenue.
##
## Il ne touche à aucun écran : il regarde la scène en cours et l'état du jeu
## (Game) pour savoir où en est le joueur, et retrouve les boutons par leur
## texte. Son état est dans user://tutoriel.json, à part de la sauvegarde.
##
## Tutoriel.demarrer()  lance (ou relance) le tutoriel
## Tutoriel.passer()    l'arrête sans la récompense
## Tutoriel.actif()     vrai pendant le tutoriel

signal etape_changee(id: String)
signal termine(recompense: int)

const CHEMIN := "user://tutoriel.json"
const RECOMPENSE := 50

const SC_CREATION := "res://scenes/club/creation_club.tscn"
const SC_CLUB := "res://scenes/club/club.tscn"
const SC_FAVORIS := "res://scenes/favoris/favoris.tscn"
const SC_CARTE := "res://scenes/carte/carte.tscn"
const SC_VOYAGE := "res://scenes/voyage/voyage.tscn"
const SC_TRIBUNE := "res://scenes/tribune/tribune.tscn"
const SC_DUELS := ["res://scenes/duel/duel.tscn", "res://scenes/arene/arene.tscn", "res://scenes/poussee/poussee.tscn"]

## Les étapes, dans l'ordre. « scenes » : où la bulle s'affiche.
## « cible » : début du texte du bouton à montrer (ou « LineEdit »).
const ETAPES := [
	{"id": "club", "scenes": [SC_CREATION], "titre": "Ton fan club",
		"texte": "Salut, moi c'est %s ! Je vais t'aider à démarrer. D'abord, fonde ton fan club : donne-lui un nom, choisis deux couleurs, puis appuie sur FONDER LE CLUB !"},
	{"id": "qg", "scenes": [SC_CLUB], "titre": "Ton QG",
		"texte": "Bienvenue au QG ! Tes membres versent une petite cotisation, et la buvette rapporte des Jetons. Reviens souvent récolter la caisse.",
		"bouton": "Suivant"},
	{"id": "favoris", "scenes": [SC_FAVORIS], "titre": "Tes équipes",
		"texte": "Choisis ton club favori dans un pays, et ton équipe nationale. Chaque duel et chaque prono pour elles leur donne de la popularité !",
		"bouton": "Vers la carte"},
	{"id": "match", "scenes": [SC_CARTE], "titre": "Choisis un match",
		"texte": "Voici la carte du monde. Les épingles, ce sont les vrais matchs de la semaine ! Choisis un match dans la liste à gauche, ou clique sur un continent pour en voir d'autres."},
	{"id": "prono", "scenes": [SC_CARTE], "titre": "Ton prono",
		"texte": "Avant le coup d'envoi, fais ton prono : le score et l'équipe qui marque en premier. C'est gratuit, et un bon prono rapporte des Jetons !",
		"cible": "Valider mon prono", "bouton": "Plus tard"},
	{"id": "lieu", "scenes": [SC_CARTE], "titre": "Où suivre le match ?",
		"texte": "Choisis ton camp et où suivre le match : au stade, tu gagnes le tampon du stade ; à la maison, c'est gratuit. Puis appuie sur C'EST PARTI !",
		"cible": "C'EST PARTI"},
	{"id": "voyage", "scenes": [SC_VOYAGE], "titre": "En route !",
		"texte": "Le car du fan club file vers le stade. Une fois arrivé, entre dans le stade !",
		"cible": "ENTRER DANS LE STADE"},
	{"id": "tribune", "scenes": [SC_TRIBUNE], "titre": "Ta tribune",
		"texte": "Voici tes 3 FANZZY : un pour le Chant, un pour le Tifo, un pour l'Ola. Pour ton premier duel, lance le DUEL D'AMBIANCE !",
		"cible": "DUEL D'AMBIANCE"},
	{"id": "duel", "scenes": SC_DUELS, "titre": "Le duel d'ambiance",
		"texte": "ESPACE quand la note arrive dans le cercle, T quand le tifo est prêt, O pour l'ola puis les flèches. Fais plus de bruit que la tribune d'en face !",
		"bas": true},
	{"id": "bravo", "scenes": [], "titre": "Bravo !",
		"texte": "Ton premier duel est joué ! Maintenant, à toi : suis d'autres matchs, tamponne des stades, gagne des Jetons à la Buvette. Voici %d Jetons pour bien commencer !",
		"bouton": "Merci !"},
]

var etape := ""          # id de l'étape en cours ("" : pas de tutoriel)
var fini := false        # déjà terminé ou passé
var _ref_duels := 0      # duels joués au début de l'étape « duel »
var _ref_pronos := 0
var _reduit := false
var _scene_vue: Node = null
var _cible: Control = null

var _bulle: PanelContainer
var _portrait: TextureRect
var _titre: Label
var _texte: Label
var _bouton: Button
var _passer: Button
var _projecteur: Projecteur
var _deja_dit := ""
var _replace := false


func _ready() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construire()
	charger()
	_bulle.visible = false


# ---------------------------------------------------------------- état

func actif() -> bool:
	return etape != "" and not fini


func demarrer() -> void:
	fini = false
	_reduit = false
	_aller_a(ETAPES[0]["id"])


func passer() -> void:
	fini = true
	etape = ""
	_maj_affichage()
	sauver()


func terminer() -> int:
	## Fin normale : cadeau de bienvenue (une seule fois).
	var deja := fini
	fini = true
	etape = ""
	sauver()
	_maj_affichage()
	if deja:
		return 0
	Game.gagner_jetons(RECOMPENSE)
	termine.emit(RECOMPENSE)
	return RECOMPENSE


func index_etape(id: String) -> int:
	for i in ETAPES.size():
		if ETAPES[i]["id"] == id:
			return i
	return -1


func _aller_a(id: String) -> void:
	etape = id
	_reduit = false
	if id == "duel":
		_ref_duels = Game.duels_joues
		_replier_plus_tard()
	if id == "prono":
		_ref_pronos = Game.pronos.size() + Game.pronos_finis.size()
	sauver()
	etape_changee.emit(id)
	_maj_affichage()


## Pendant le duel, la bulle se replie après quelques secondes pour laisser jouer.
func _replier_plus_tard() -> void:
	await get_tree().create_timer(9.0).timeout
	if etape == "duel" and not _reduit:
		_reduit = true
		_texte.visible = false
		_placer()


func _suivante() -> void:
	var i := index_etape(etape)
	if i < 0 or i + 1 >= ETAPES.size():
		terminer()
	else:
		_aller_a(ETAPES[i + 1]["id"])


func _fiche() -> Dictionary:
	var i := index_etape(etape)
	return ETAPES[i] if i >= 0 else {}


func sauver() -> void:
	var f := FileAccess.open(CHEMIN, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"etape": etape, "fini": fini, "ref_duels": _ref_duels}))


func charger() -> void:
	etape = ""
	fini = false
	if not FileAccess.file_exists(CHEMIN):
		return
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN))
	if d is Dictionary:
		fini = bool(d.get("fini", false))
		etape = str(d.get("etape", ""))
		_ref_duels = int(d.get("ref_duels", 0))
		if index_etape(etape) < 0:
			etape = ""


func effacer() -> void:
	## Pour « Recommencer la partie » : le tutoriel sera reproposé.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN))
	etape = ""
	fini = false
	_maj_affichage()


# ---------------------------------------------------------------- suivi du joueur

func _process(_delta: float) -> void:
	if not actif():
		if _bulle.visible:
			_maj_affichage()
		return
	var sc := get_tree().current_scene
	if sc != _scene_vue:
		_scene_vue = sc
		_maj_affichage()
	_avancer_si_fait()
	_suivre_cible()


func _scene() -> String:
	var sc := get_tree().current_scene
	return sc.scene_file_path if sc else ""


## Passe à l'étape suivante quand le joueur a fait ce qu'on lui demandait,
## ou quand il est déjà plus loin (il n'a pas attendu la bulle).
func _avancer_si_fait() -> void:
	for _garde in ETAPES.size():
		var avant := etape
		if _etape_faite():
			_suivante()
		else:
			# déjà sur l'écran d'une étape plus loin : on rattrape
			var i := index_etape(etape)
			var sc := _scene()
			# revenu sur la carte sans finir le duel : on reprend au choix du match
			if sc == SC_CARTE and i > index_etape("lieu") and etape != "bravo":
				_aller_a("match")
				return
			for j in range(i + 1, ETAPES.size()):
				if sc in ETAPES[j]["scenes"] and not sc in ETAPES[i]["scenes"]:
					_aller_a(ETAPES[j]["id"])
					break
		if etape == avant or not actif():
			return


func _etape_faite() -> bool:
	var sc := _scene()
	match etape:
		"club":
			return Game.club_cree()
		"match":
			return sc == SC_CARTE and _trouver("C'EST PARTI") != null
		"prono":
			if Game.pronos.size() + Game.pronos_finis.size() > _ref_pronos:
				return true
			# match déjà commencé : pas de prono possible, on passe
			return sc == SC_CARTE and _trouver("C'EST PARTI") != null and _trouver("Valider mon prono") == null \
				and _trouver("Modifier mon prono") == null
		"lieu":
			return sc == SC_VOYAGE or sc == SC_TRIBUNE
		"voyage":
			return sc == SC_TRIBUNE
		"tribune":
			return sc in SC_DUELS
		"duel":
			return Game.duels_joues > _ref_duels
	return false


# ---------------------------------------------------------------- recherche des boutons

func _trouver(debut: String) -> Control:
	var sc := get_tree().current_scene
	if sc == null:
		return null
	return _chercher(sc, debut)


func _chercher(n: Node, debut: String) -> Control:
	if n is Control and not (n as Control).is_visible_in_tree():
		return null
	if debut == "LineEdit" and n is LineEdit:
		return n
	if n is Button and (n as Button).text.begins_with(debut):
		return n
	for c in n.get_children():
		var r := _chercher(c, debut)
		if r:
			return r
	return null


func _suivre_cible() -> void:
	var f := _fiche()
	var cible: Control = null
	if not _bulle.visible:
		cible = null
	elif etape == "club":
		var champ := _trouver("LineEdit") as LineEdit
		cible = champ if champ and champ.text.strip_edges().length() < 3 else _trouver("FONDER")
	elif f.has("cible"):
		cible = _trouver(f["cible"])
	_cible = cible
	_projecteur.cible = cible
	# Un tutoriel qui parle de prono sans fiche ouverte : on rappelle d'ouvrir un match.
	if etape == "prono" or etape == "lieu":
		var fiche_ouverte := _trouver("C'EST PARTI") != null
		_ecrire(f["texte"] if fiche_ouverte else "Rouvre un match dans la liste à gauche pour continuer.")


# ---------------------------------------------------------------- affichage

func _maj_affichage() -> void:
	if _bulle == null:
		return
	var f := _fiche()
	var sc := _scene()
	var montrer: bool = actif() and not f.is_empty() and (f["scenes"].is_empty() or sc in f["scenes"])
	# la bulle de fin attend un écran calme (pas en plein duel)
	if etape == "bravo":
		montrer = actif() and sc != "" and sc != "res://scenes/main/main.tscn"
	_bulle.visible = montrer
	_projecteur.visible = montrer
	if not montrer:
		_projecteur.cible = null
		return
	var guide := _guide()
	var id_guide: String = guide.get("id", "")
	_portrait.texture = Game.texture_fanzzy(id_guide, true) if id_guide != "" else null
	_titre.text = f["titre"]
	var t: String = f["texte"]
	if etape == "club":
		t = t % str(guide.get("nom", "ton premier supporter"))
	elif etape == "bravo":
		t = t % RECOMPENSE
	_ecrire(t)
	_bouton.visible = f.has("bouton")
	_bouton.text = f.get("bouton", "")
	if etape == "favoris":
		var a_choisi: bool = not Game.supporters.get("clubs", {}).is_empty() or not Game.supporters.get("nation", {}).is_empty()
		_bouton.text = "Vers la carte" if a_choisi else "Plus tard"
	_passer.visible = etape != "bravo"
	_placer()


func _ecrire(t: String) -> void:
	if _deja_dit == t and _texte.text == t:
		return
	_deja_dit = t
	_texte.text = t
	_texte.visible = not _reduit


func _guide() -> Dictionary:
	if Game.equipe.size() > 0:
		var z := Game.fanzzy_par_id(str(Game.equipe[0]))
		if not z.is_empty():
			return z
	return Game.fanzzy[0] if Game.fanzzy.size() > 0 else {}


func _placer() -> void:
	var f := _fiche()
	var vp := get_viewport().get_visible_rect().size
	var sc := _scene()
	var largeur := 300.0 if _reduit else 700.0
	if etape == "bravo":
		largeur = 560.0
	elif sc == SC_CREATION or (etape == "duel" and not _reduit):
		largeur = 500.0
	elif sc == SC_CARTE and not _reduit:
		largeur = 620.0  # à côté d'un panneau qu'il ne faut pas cacher
	_bulle.custom_minimum_size.x = largeur
	_bulle.size = Vector2.ZERO
	_bulle.reset_size()
	var taille := _bulle.get_combined_minimum_size()
	var x := (vp.x - taille.x) / 2.0
	var y := vp.y - taille.y - 140.0
	if f.get("bas", false):
		x = 24.0
		y = vp.y - taille.y - 24.0
	elif etape == "bravo":
		x = vp.x - taille.x - 30.0  # à droite des résultats du duel
		y = (vp.y - taille.y) / 2.0
	elif sc == SC_CREATION:
		x = vp.x - taille.x - 20.0  # sous l'aperçu de l'écusson
		y = vp.y - taille.y - 20.0
	elif sc == SC_TRIBUNE:
		y = vp.y - taille.y - 300.0  # laisse voir la flèche sur les boutons
	elif sc == SC_CARTE:
		x = 500.0  # entre la liste des matchs et la fiche
	_bulle.position = Vector2(x, maxf(20.0, y))
	_bulle.size = taille
	if not _replace:
		# le texte replié n'a sa vraie hauteur qu'à l'image suivante
		_replace = true
		await get_tree().process_frame
		_replace = false
		if _bulle.visible:
			_bulle.size = Vector2.ZERO
			_bulle.reset_size()
			var t2 := _bulle.size
			if t2.y != taille.y:
				_bulle.position.y += taille.y - t2.y


func _construire() -> void:
	_projecteur = Projecteur.new()
	_projecteur.set_anchors_preset(Control.PRESET_FULL_RECT)
	_projecteur.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_projecteur)

	_bulle = PanelContainer.new()
	var st := Ui.boite(Ui.BLANC, 26, 6, 8)
	st.content_margin_left = 18
	st.content_margin_right = 22
	st.content_margin_top = 14
	st.content_margin_bottom = 14
	_bulle.add_theme_stylebox_override("panel", st)
	add_child(_bulle)
	var h := Ui.hbox(16)
	_bulle.add_child(h)
	var cadre := Ui.panneau(Ui.JAUNE, 60, 5)
	cadre.custom_minimum_size = Vector2(108, 108)
	cadre.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	cadre.mouse_filter = Control.MOUSE_FILTER_STOP
	cadre.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cadre.tooltip_text = "Réduire / agrandir la bulle"
	cadre.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			_reduit = not _reduit
			_texte.visible = not _reduit
			_placer.call_deferred())
	h.add_child(cadre)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.custom_minimum_size = Vector2(84, 84)
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cadre.add_child(_portrait)
	var v := Ui.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_titre = Ui.label("", 30, Ui.ROSE, true)
	v.add_child(_titre)
	_texte = Ui.label("", 21, Ui.CONTOUR)
	_texte.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texte.custom_minimum_size.x = 200
	v.add_child(_texte)
	var bas := Ui.hbox(12)
	bas.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bas)
	_passer = Ui.bouton("Passer le tutoriel", Ui.NUIT_CLAIR, 17)
	_passer.pressed.connect(passer)
	bas.add_child(_passer)
	_bouton = Ui.bouton("Suivant", Ui.VERT, 24)
	_bouton.custom_minimum_size.x = 170
	_bouton.pressed.connect(_sur_bouton)
	bas.add_child(_bouton)


func _sur_bouton() -> void:
	match etape:
		"qg":
			_suivante()
			Game.aller(Game.SCENE_FAVORIS)
		"favoris":
			_suivante()
			Game.aller(Game.SCENE_CARTE, Game.params)
		"prono":
			_suivante()
		"bravo":
			terminer()
		_:
			_suivante()


## Cadre jaune qui clignote autour du bouton à presser, et une flèche qui
## rebondit au-dessus. Ne capte pas la souris.
class Projecteur extends Control:
	var cible: Control = null
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if cible == null or not is_instance_valid(cible) or not cible.is_visible_in_tree():
			return
		var r := cible.get_global_rect().grow(10.0 + sin(_t * 6.0) * 4.0)
		var a := 0.65 + 0.35 * sin(_t * 6.0)
		var sb := StyleBoxFlat.new()
		sb.draw_center = false
		sb.set_border_width_all(7)
		sb.border_color = Color(Ui.JAUNE, a)
		sb.set_corner_radius_all(24)
		sb.anti_aliasing = true
		draw_style_box(sb, r)
		# flèche au-dessus (ou en dessous si le bouton est tout en haut)
		var dessus := r.position.y > 120.0
		var bout := Vector2(r.get_center().x, r.position.y - 8.0 if dessus else r.end.y + 8.0)
		var sens := -1.0 if dessus else 1.0
		bout.y += sens * (absf(sin(_t * 5.0)) * 16.0)
		var pts := PackedVector2Array([bout, bout + Vector2(-30, sens * 40), bout + Vector2(-12, sens * 40),
			bout + Vector2(-12, sens * 78), bout + Vector2(12, sens * 78), bout + Vector2(12, sens * 40), bout + Vector2(30, sens * 40)])
		var contour := pts.duplicate()
		contour.append(pts[0])
		draw_colored_polygon(pts, Ui.JAUNE)
		draw_polyline(contour, Ui.CONTOUR, 5.0, true)
