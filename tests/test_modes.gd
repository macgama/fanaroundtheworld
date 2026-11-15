extends SceneTree
## Tests sans écran des modes Arène et Poussée :
##   godot --headless --path . --script tests/test_modes.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_arene()
	_tester_poussee()
	_tester_couleurs()
	print("Tests modes : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_arene() -> void:
	var a1 := AreneRegles.actions_debloquees(1)
	_verifier(a1 == ["lancer", "super"], "niveau 1 : lancer + super seulement")
	_verifier("roulade" in AreneRegles.actions_debloquees(3), "roulade au niveau 3")
	_verifier(not "tir_charge" in AreneRegles.actions_debloquees(4), "pas de tir chargé avant le niveau 5")
	_verifier("tir_charge" in AreneRegles.actions_debloquees(5), "tir chargé au niveau 5")
	_verifier(AreneRegles.remplir(10.0, 1, 0, 1.0) > 10.0, "le mégaphone tenu remplit la banderole")
	_verifier(AreneRegles.remplir(10.0, 2, 1, 1.0) == 10.0, "mégaphone disputé : rien ne bouge")
	_verifier(AreneRegles.remplir(10.0, 0, 0, 1.0) == 10.0, "mégaphone vide : rien ne bouge")
	_verifier(AreneRegles.remplir(10.0, 3, 0, 1.0) > AreneRegles.remplir(10.0, 1, 0, 1.0), "plus de FANZZY = plus vite")
	_verifier(AreneRegles.remplir(99.0, 3, 0, 5.0) == AreneRegles.BANDEROLE_MAX, "banderole plafonnée à 100")
	_verifier(AreneRegles.resultat(60.0, 40.0, 0, 9) == 1, "la banderole décide d'abord")
	_verifier(AreneRegles.resultat(50.0, 50.0, 3, 5) == -1, "égalité de banderole : les touches départagent")
	_verifier(AreneRegles.resultat(50.0, 50.0, 4, 4) == 0, "égalité parfaite")
	for f in ["voix", "perc", "tifo", "fide", "pyro", "depl"]:
		_verifier(AreneRegles.SUPERS.has(f), "super pour la famille " + f)
	_verifier(AreneRegles.performance(100.0, 40, 8) == 1.0, "performance plafonnée à 1")


func _tester_poussee() -> void:
	var c1 := PousseeRegles.cartes_debloquees(1)
	_verifier(c1.size() == 6 and not "fumigene" in c1 and not "ola" in c1, "niveau 1 : 6 cartes de supporters")
	_verifier("fumigene" in PousseeRegles.cartes_debloquees(2), "fumigène au niveau 2")
	_verifier(PousseeRegles.cartes_debloquees(4).size() == 8, "les 8 cartes au niveau 4")
	for k in PousseeRegles.ORDRE:
		var c: Dictionary = PousseeRegles.CARTES[k]
		_verifier(c["cout"] >= 1 and c["cout"] <= PousseeRegles.FERVEUR_MAX, "coût de %s entre 1 et 10" % k)
	_verifier(PousseeRegles.ferveur(9.8, 0.0, 1.0) == PousseeRegles.FERVEUR_MAX, "Ferveur plafonnée")
	var lent := PousseeRegles.ferveur(0.0, 10.0, 1.0)
	var rush := PousseeRegles.ferveur(0.0, PousseeRegles.DUREE - 10.0, 1.0)
	_verifier(is_equal_approx(rush, lent * 2.0), "Ferveur x2 la dernière minute")
	var t := Rect2(0, 0, 1000, 600)
	_verifier(PousseeRegles.but(Vector2(1000, 300), t) == 1, "but à droite")
	_verifier(PousseeRegles.but(Vector2(0, 320), t) == -1, "but à gauche")
	_verifier(PousseeRegles.but(Vector2(1000, 50), t) == 0, "à côté du but")
	_verifier(PousseeRegles.but(Vector2(500, 300), t) == 0, "milieu du terrain")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var pile := PousseeRegles.nouvelle_pile(PousseeRegles.cartes_debloquees(4), rng)
	_verifier(pile.size() == 8, "pile de 8 cartes")
	var suivante: String = pile[PousseeRegles.TAILLE_MAIN]
	var jouee: String = pile[1]
	var apres := PousseeRegles.jouer_carte(pile, 1)
	_verifier(apres[1] == suivante, "la carte suivante prend la place de la carte jouée")
	_verifier(apres[-1] == jouee, "la carte jouée repart sous la pile")
	_verifier(apres.size() == pile.size(), "aucune carte perdue")
	_verifier(PousseeRegles.resultat_temps(800.0, 300.0) == 1, "la tribune la moins entamée gagne")
	_verifier(PousseeRegles.resultat_temps(500.0, 500.5) == 0, "égalité au temps")


func _tester_couleurs() -> void:
	var bleu := Color("#1e3a8a")
	var bleu_clair := Color("#5ec8f0")
	_verifier(Ui.couleur_distincte(bleu, bleu_clair) != bleu_clair, "deux bleus : l'adversaire change de couleur")
	_verifier(Ui.couleur_distincte(bleu, Color("#e03030")) == Color("#e03030"), "bleu contre rouge : on garde")
