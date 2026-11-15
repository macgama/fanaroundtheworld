extends SceneTree
## Tests sans écran ni réseau du jeu en ligne (Protocole) :
##   godot --headless --path . --script tests/test_reseau.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_messages()
	_tester_profil()
	_tester_jauge()
	_tester_annonces()
	_tester_poussee()
	_tester_arene()
	print("Tests réseau : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_messages() -> void:
	_verifier(Protocole.valide(Protocole.msg("pret")), "message simple valide")
	_verifier(not Protocole.valide("pret"), "une chaîne n'est pas un message")
	_verifier(not Protocole.valide({"t": "inconnu"}), "type inconnu refusé")
	_verifier(not Protocole.valide({"t": "pousse", "d": 1.0}), "champ manquant refusé")
	_verifier(Protocole.valide(Protocole.msg("pousse", {"d": 2.5, "n": 1})), "geste valide")
	_verifier(not Protocole.valide(Protocole.msg("pousse", {"d": 500.0, "n": 1})), "geste énorme refusé (triche)")
	_verifier(not Protocole.valide(Protocole.msg("pousse", {"d": NAN, "n": 1})), "geste NaN refusé")
	_verifier(not Protocole.valide(Protocole.msg("pousse", {"d": "12", "n": 1})), "geste texte refusé")
	_verifier(Protocole.valide(Protocole.msg("evt", {"e": "tifo"})), "évènement tifo valide")
	_verifier(not Protocole.valide(Protocole.msg("evt", {"e": "insulte"})), "évènement inconnu refusé")
	_verifier(not Protocole.valide(Protocole.msg("match", {"m": {}, "camp_hote": "milieu"})), "camp inconnu refusé")
	_verifier(Protocole.camp_oppose("home") == "away" and Protocole.camp_oppose("away") == "home", "camps opposés")


func _tester_profil() -> void:
	var p := Protocole.profil("Les Ultras", [Color.RED, Color.WHITE], ["AN1", "MT14B", "GD8"], 4)
	_verifier(Protocole.valide(p), "profil valide")
	var q := Protocole.profil_propre(p)
	_verifier(q["nom"] == "Les Ultras", "nom gardé")
	_verifier(q["equipe"] == ["AN1", "MT14B", "GD8"], "équipe gardée")
	_verifier(q["couleurs"][0].is_equal_approx(Color.RED), "couleur gardée")
	_verifier(Protocole.meme_version(q), "même version")
	var sale := {"t": "profil", "nom": "  " + "x".repeat(200), "couleurs": ["pas une couleur"],
		"equipe": ["../../secret", "AN1", "B2", "C3", "D4"], "niveau": -5, "v": 99}
	var r := Protocole.profil_propre(sale)
	_verifier(r["nom"].length() <= Protocole.NOM_MAX, "nom coupé")
	_verifier(r["couleurs"].size() == 2, "deux couleurs même si une seule reçue")
	_verifier(r["equipe"].size() == 3 and r["equipe"][0] == "", "chemin suspect refusé, 3 FANZZY au plus")
	_verifier(r["niveau"] == 1, "niveau ramené à 1")
	_verifier(not Protocole.meme_version(r), "autre version détectée")
	_verifier(Protocole.profil_propre({"nom": "   "})["nom"] != "", "nom vide remplacé")


func _tester_jauge() -> void:
	var hote := Protocole.JaugePartagee.new(true)
	var invite := Protocole.JaugePartagee.new(false)
	_verifier(hote.local(10.0).is_empty(), "l'hôte n'envoie pas ses gestes")
	var g1 := invite.local(4.0)
	var g2 := invite.local(3.0)
	_verifier(invite.jauge == 7.0, "l'invité voit tout de suite ses gestes")
	_verifier(invite.en_attente() == 2, "deux gestes en vol")
	hote.distant(g1)
	_verifier(hote.jauge == 6.0, "geste de l'invité retiré chez l'hôte (10 - 4)")
	# l'état part avant que g2 arrive : l'invité rejoue g2 par-dessus
	_verifier(Protocole.valide(hote.etat(1.0)), "le message d'état est valide")
	_verifier(Protocole.valide(g1), "le message de geste est valide")
	invite.recaler(hote.etat(1.0))
	_verifier(invite.jauge == -3.0, "invité recalé : -6 + 3 en vol = -3")
	_verifier(invite.en_attente() == 1, "g1 confirmé")
	hote.distant(g2)
	hote.distant(g2)  # doublon ignoré
	_verifier(hote.jauge == 3.0, "doublon ignoré")
	invite.recaler(hote.etat(1.1))
	_verifier(invite.jauge == -3.0 and invite.en_attente() == 0, "les deux jauges sont d'accord (+3 / -3)")
	# plafonds
	for i in 30:
		hote.local(10.0)
	_verifier(hote.jauge == 100.0, "jauge plafonnée à +100")
	invite.recaler(hote.etat(2.0))
	_verifier(invite.jauge == -100.0, "l'invité voit -100")
	_verifier(hote.finale(Protocole.msg("fin", {"j": 42.0})) == 42.0, "fin : l'hôte garde sa jauge")
	_verifier(invite.finale(Protocole.msg("fin", {"j": 42.0})) == -42.0, "fin : l'invité voit l'inverse")


func _tester_annonces() -> void:
	var a := Protocole.annonce_lan("Club du Port", "Rouges – Bleus", 24680)
	var l := Protocole.lire_annonce(a)
	_verifier(l.get("nom") == "Club du Port" and l.get("port") == 24680, "annonce relue")
	_verifier(Protocole.lire_annonce("bonjour".to_utf8_buffer()).is_empty(), "paquet quelconque ignoré")
	var autre := JSON.stringify({"jeu": "autre", "v": 1, "port": 24680}).to_utf8_buffer()
	_verifier(Protocole.lire_annonce(autre).is_empty(), "autre jeu ignoré")
	var vieux := JSON.stringify({"jeu": Protocole.JEU, "v": 0, "port": 24680}).to_utf8_buffer()
	_verifier(Protocole.lire_annonce(vieux).is_empty(), "autre version ignorée")
	var port := JSON.stringify({"jeu": Protocole.JEU, "v": Protocole.VERSION, "port": 22}).to_utf8_buffer()
	_verifier(Protocole.lire_annonce(port).is_empty(), "port bizarre ignoré")


func _tester_poussee() -> void:
	_verifier(Protocole.valide(Protocole.msg("lancer", {"jeu": "poussee"})), "lancer la Poussée")
	_verifier(not Protocole.valide(Protocole.msg("lancer", {"jeu": "foot"})), "jeu inconnu refusé")
	_verifier(Protocole.valide(Protocole.msg("carte", {"i": 2, "x": 300.0, "y": 400.0})), "carte valide")
	_verifier(not Protocole.valide(Protocole.msg("carte", {"i": 7, "x": 300.0, "y": 400.0})), "carte hors de la main refusée")
	_verifier(not Protocole.valide(Protocole.msg("carte", {"i": 1, "x": INF, "y": 400.0})), "position infinie refusée")
	var inst := Protocole.msg("instant", {"tps": 12.5, "f": [3.0, 4.5], "tr": [1200.0, 980.0], "b": [960.0, 490.0, 0.3],
		"m": ["tambour", "drapeau", "chorale", "canon", "serpentins"], "z": [[500.0, 400.0, "fumigene", 1, 3.2]],
		"u": [[1, "tambour", 0, 400.0, 300.0, 0.8, 2, 1], [2, "canon", 1, 1500.0, 500.0, 1.0, 0, 0]]})
	_verifier(Protocole.valide(inst), "instantané valide")
	var faux := inst.duplicate(true)
	faux["u"][0][1] = "bazooka"
	_verifier(not Protocole.valide(faux), "unité inconnue refusée")
	faux = inst.duplicate(true)
	faux["m"] = ["tambour", 5]
	_verifier(not Protocole.valide(faux), "main bizarre refusée")
	_verifier(Protocole.valide(Protocole.msg("fin_p", {"res": -1, "r": "tribune"})), "fin de Poussée valide")
	_verifier(not Protocole.valide(Protocole.msg("fin_p", {"res": 3, "r": "tribune"})), "résultat bizarre refusé")
	var t := Rect2(150, 176, 1620, 630)
	_verifier(is_equal_approx(Protocole.miroir_x(200.0, t), 1720.0), "terrain retourné pour l'invité")
	_verifier(is_equal_approx(Protocole.miroir_x(Protocole.miroir_x(321.0, t), t), 321.0), "retourner deux fois = rien")


func _tester_arene() -> void:
	_verifier(Protocole.valide(Protocole.msg("lancer", {"jeu": "arene"})), "lancer l'Arène")
	_verifier(Protocole.valide(Protocole.msg("cmd", {"d": [1.0, 0.0], "v": [900.0, 500.0], "c": 1, "n": 42})), "commande valide")
	_verifier(not Protocole.valide(Protocole.msg("cmd", {"d": [1.0, 0.0], "v": [900.0, 500.0], "c": 5, "n": 42})), "FANZZY dirigé inconnu refusé")
	_verifier(Protocole.valide(Protocole.msg("act", {"a": "super", "x": 1.0, "y": 2.0})), "action valide")
	_verifier(not Protocole.valide(Protocole.msg("act", {"a": "teleporter", "x": 1.0, "y": 2.0})), "action inconnue refusée")
	var j := [800.0, 500.0, 100.0, 3.0, 0.5, 0, 2, 1, 0, 0.0]
	var inst := Protocole.msg("arene", {"tps": 30.0, "bd": [10.0, 20.0], "to": [3, 4], "ack": 120, "ctl": 0,
		"j": [j, j, j, j, j, j], "bl": [[500.0, 400.0, 1, 13.0]], "mu": [[1.0, 2.0, 3.0, 4.0, 0, 2.5]],
		"nu": [[600.0, 600.0, 170.0, 1, 3.0]], "on": [[700.0, 500.0, 1.0, 0.0, 50.0, 400.0, "cone", 0, 0.3]]})
	_verifier(Protocole.valide(inst), "instantané d'Arène valide")
	var faux := inst.duplicate(true)
	faux["j"] = [j, j, j]
	_verifier(not Protocole.valide(faux), "il faut 6 FANZZY")
	faux = inst.duplicate(true)
	faux["on"][0][6] = "laser"
	_verifier(not Protocole.valide(faux), "onde inconnue refusée")
	_verifier(Protocole.valide(Protocole.msg("fin_a", {"bd": [100.0, 40.0], "to": [9, 7], "ne": [1, 0]})), "fin d'Arène valide")
	var p := Protocole.profil_propre(Protocole.profil("A", [Color.RED, Color.BLUE], ["AN1B"], 3, ["AN1", "../x"]))
	_verifier(p["ids"] == ["AN1", ""], "FANZZY de l'adversaire filtrés")
