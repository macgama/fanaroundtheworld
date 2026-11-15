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
