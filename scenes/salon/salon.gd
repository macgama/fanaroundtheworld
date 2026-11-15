extends Control
## Salon en ligne : défier un ami ou trouver un adversaire, puis lancer le duel d'ambiance.
##   Avec Steam : invitation d'amis (fenêtre Steam) et recherche d'adversaire (salons publics).
##   Sans Steam : salon sur le réseau local (annoncé automatiquement) ou par adresse IP.
## L'hôte choisit le match (celui de « Ta tribune », sinon le prochain match) et son camp ;
## l'invité soutient l'autre équipe.
##
## Test : godot --path . -- --scene=salon --salon=hote --auto
##        godot --path . -- --scene=salon --salon=127.0.0.1 --auto

var _statut: Label
var _carte_moi: PanelContainer
var _carte_eux: PanelContainer
var _lbl_match: Label
var _actions: VBoxContainer
var _liste_lan: VBoxContainer
var _champ_ip: LineEdit
var _auto := false


func _ready() -> void:
	var p: Dictionary = Game.params
	_auto = bool(p.get("auto", false))
	var fond := ColorRect.new()
	fond.color = Color("#1e6bff")
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
	haut.add_child(Ui.label("JOUER EN LIGNE", 60, Ui.JAUNE, true, 10))
	var st := Ui.label("Réseau Steam : amis et adversaires du monde entier" if Reseau.steam_ok
		else "Réseau local (ou adresse IP). Steam arrivera avec la page du jeu.", 22, Ui.BLANC)
	st.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	haut.add_child(st)

	# toi · VS · l'adversaire
	var milieu := Ui.hbox(24)
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	racine.add_child(milieu)
	_carte_moi = Ui.panneau()
	_carte_moi.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milieu.add_child(_carte_moi)
	var centre := Ui.vbox(14)
	centre.custom_minimum_size = Vector2(420, 0)
	centre.alignment = BoxContainer.ALIGNMENT_CENTER
	milieu.add_child(centre)
	var vs := Ui.label("VS", 110, Ui.JAUNE, true, 14)
	vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre.add_child(vs)
	_lbl_match = Ui.label("", 24, Ui.BLANC, true, 6)
	_lbl_match.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_match.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centre.add_child(_lbl_match)
	_actions = Ui.vbox(12)
	centre.add_child(_actions)
	_carte_eux = Ui.panneau()
	_carte_eux.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milieu.add_child(_carte_eux)

	_statut = Ui.label("", 26, Ui.BLANC, true, 6)
	_statut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_statut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	racine.add_child(_statut)

	var bas := Ui.hbox(20)
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	racine.add_child(bas)
	var retour := Ui.bouton("Retour à la carte", Ui.NUIT, 28)
	retour.custom_minimum_size = Vector2(340, 84)
	retour.pressed.connect(func():
		Reseau.quitter()
		Game.aller(Game.SCENE_CARTE))
	bas.add_child(retour)

	Reseau.etat_change.connect(_maj)
	Reseau.salons_lan_trouves.connect(func(_l): _maj())
	Reseau.salons_steam_trouves.connect(_afficher_salons_steam)
	Reseau.message.connect(_sur_message)
	Reseau.adversaire_arrive.connect(func(_p): _sur_adversaire())

	# Hôte : le match de « Ta tribune », sinon le prochain match à venir.
	var salon := str(p.get("salon", ""))
	if salon == "hote":
		Reseau.creer_salon_lan()
	elif salon == "steam":
		Reseau.creer_salon_steam(false)  # test : salon d'amis Steam
	elif salon == "steam-trouver":
		Reseau.trouver_adversaire_steam()
	elif not salon.is_empty():
		Reseau.rejoindre_lan(salon)
	if Reseau.hote:
		Reseau.choisir_match(_match_par_defaut(), str(p.get("camp", "home")))
	_maj()


func _match_par_defaut() -> Dictionary:
	var p: Dictionary = Game.params
	var m := Donnees.match_par_id(str(p.get("match_id", "")))
	if not m.is_empty():
		return m
	if not Reseau.match_salon.is_empty():
		return Reseau.match_salon
	var liste := Donnees.matchs()
	for x in liste:
		if Donnees.en_direct(x):
			return x
	var maintenant := int(Time.get_unix_time_from_system())
	for x in liste:
		if Donnees.heure_unix(x) >= maintenant:
			return x
	return liste[0] if not liste.is_empty() else {}


func _bouton(texte: String, couleur: Color, action: Callable, sombre := false) -> Button:
	var b := Ui.bouton(texte, couleur, 28)
	if sombre:
		Ui.colorer_bouton(b, couleur, true)
	b.custom_minimum_size = Vector2(400, 80)
	b.pressed.connect(action)
	_actions.add_child(b)
	return b


func _maj() -> void:
	if not is_inside_tree():
		return
	_statut.text = Reseau.statut
	if "--journal" in OS.get_cmdline_user_args():
		print("SALON [%s%s] %s" % [Reseau.transport, " hôte" if Reseau.hote else "", Reseau.statut])
	_remplir_carte(_carte_moi, Game.fan_club_nom, Game.couleurs_club(), Game.equipe.map(func(id): return Game.skin_de(str(id))), "Toi · niveau %d" % Game.niveau())
	var adv := Reseau.adversaire
	if adv.is_empty():
		_remplir_carte(_carte_eux, "En attente…", [Ui.NUIT_CLAIR, Ui.GRIS], [], "")
	else:
		_remplir_carte(_carte_eux, adv["nom"], adv["couleurs"], adv["equipe"], "Adversaire · niveau %d" % adv["niveau"])
	var m := Reseau.match_salon
	if m.is_empty():
		_lbl_match.text = "Le match sera choisi par l'hôte"
	else:
		var f := FicheMatch.de(m)
		var nous: Dictionary = f["dom"] if Reseau.mon_camp() == "home" else f["ext"]
		_lbl_match.text = "%s – %s\nTu soutiens %s" % [f["dom"]["nom"], f["ext"]["nom"], nous["nom"]]

	for c in _actions.get_children():
		c.queue_free()
	if not Reseau.en_salon():
		if Reseau.steam_ok:
			_bouton("Défier un ami Steam", Ui.JAUNE, func():
				Reseau.creer_salon_steam(false)
				Reseau.choisir_match(_match_par_defaut(), str(Game.params.get("camp", "home"))), true)
			_bouton("Trouver un adversaire", Ui.VERT, func(): Reseau.trouver_adversaire_steam(), true)
		else:
			_bouton("Créer un salon", Ui.JAUNE, func():
				if Reseau.creer_salon_lan():
					Reseau.choisir_match(_match_par_defaut(), str(Game.params.get("camp", "home"))), true)
			_bouton("Trouver une partie", Ui.VERT, func():
				Reseau.chercher_lan()
				Reseau.statut = "On cherche les salons du réseau local…"
				_maj(), true)
			var h := Ui.hbox(8)
			_champ_ip = LineEdit.new()
			_champ_ip.placeholder_text = "Adresse IP de l'hôte"
			_champ_ip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_champ_ip.add_theme_font_size_override("font_size", 24)
			h.add_child(_champ_ip)
			var go := Ui.bouton("OK", Ui.BLEU, 26)
			go.pressed.connect(func(): Reseau.rejoindre_lan(_champ_ip.text))
			_champ_ip.text_submitted.connect(func(t): Reseau.rejoindre_lan(t))
			h.add_child(go)
			_actions.add_child(h)
			for s in Reseau.salons_lan():
				var ip: String = s["ip"]
				var port: int = s["port"]
				_bouton("Rejoindre %s\n%s" % [s["nom"], s["match"]], Ui.ROSE, func(): Reseau.rejoindre_lan(ip, port))
		return
	if Reseau.hote:
		if Reseau.connecte():
			_bouton("DUEL D'AMBIANCE\nrythme · 90 s", Ui.JAUNE, func(): _lancer("duel"), true)
			_bouton("POUSSÉE\ncartes et ballon · 3 min", Ui.VERT, func(): _lancer("poussee"), true)
		elif Reseau.transport == "steam":
			_bouton("Inviter un ami Steam", Ui.JAUNE, func(): Reseau.inviter_amis_steam(), true)
	elif Reseau.connecte():
		var l := Ui.label("L'hôte choisit le jeu et lance le duel", 24, Ui.JAUNE, true, 6)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_actions.add_child(l)
	_bouton("Quitter le salon", Ui.NUIT, func(): Reseau.quitter())


func _remplir_carte(pan: PanelContainer, nom: String, couleurs: Array, skins: Array, sous: String) -> void:
	for c in pan.get_children():
		c.queue_free()
	var v := Ui.vbox(10)
	pan.add_child(v)
	var h := Ui.hbox(12)
	h.add_child(Ui.ecusson(nom.substr(0, 2).to_upper() if not skins.is_empty() else "?", couleurs[0], couleurs[1], 64))
	var vn := Ui.vbox(2)
	var ln := Ui.label(nom.to_upper(), 34, Ui.BLANC, true, 8)
	ln.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ln.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vn.add_child(ln)
	if not sous.is_empty():
		vn.add_child(Ui.label(sous, 20, Ui.GRIS))
	vn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(vn)
	v.add_child(h)
	var hz := Ui.hbox(8)
	hz.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(hz)
	for s in skins:
		var chemin := "res://assets/fanzzy/sprites/%s.webp" % s
		var img := TextureRect.new()
		img.texture = load(chemin) if not str(s).is_empty() and ResourceLoader.exists(chemin) else null
		img.custom_minimum_size = Vector2(150, 220)
		img.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		img.size_flags_vertical = Control.SIZE_EXPAND_FILL
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hz.add_child(img)


func _afficher_salons_steam(liste: Array) -> void:
	for s in liste:
		var id: int = s["id"]
		_bouton("Rejoindre %s\n%s" % [s["nom"], s["match"]], Ui.ROSE, func(): Reseau.rejoindre_steam(id))


func _sur_adversaire() -> void:
	if _auto and Reseau.hote:
		await get_tree().create_timer(1.0).timeout
		if Reseau.connecte():
			_lancer(str(Game.params.get("jeu", "duel")))


## Hôte : les deux joueurs passent au duel (« duel » d'ambiance ou « poussee »).
func _lancer(jeu: String) -> void:
	if not Reseau.hote or not Reseau.connecte() or Reseau.match_salon.is_empty() or not jeu in Protocole.JEUX:
		return
	Reseau.envoyer(Protocole.msg("lancer", {"jeu": jeu}))
	_aller_au_duel(jeu)


func _sur_message(m: Dictionary) -> void:
	if m["t"] == "lancer" and not Reseau.hote and not Reseau.match_salon.is_empty():
		_aller_au_duel(str(m["jeu"]))


func _aller_au_duel(jeu: String) -> void:
	var p: Dictionary = Game.params
	var m := Reseau.match_salon
	Game.aller(Game.SCENE_POUSSEE if jeu == "poussee" else Game.SCENE_DUEL, {
		"en_ligne": true, "match": m, "match_id": str(m.get("id", "")), "camp": Reseau.mon_camp(),
		# l'invité suit le match « au pub » avec l'hôte : gains normaux, pas de billet
		"mode": str(p.get("mode", "stade")) if Reseau.hote else "pub",
		"auto": _auto, "cout": 0, "jeu": jeu,
	})
