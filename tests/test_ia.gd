extends SceneTree
## Tests sans écran de l'adversaire ordi (niveaux, décisions de la Poussée) :
##   godot --headless --path . --script tests/test_ia.gd
## Les matchs simulés ordi contre ordi : tests/sim_ia.tscn.

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_niveaux()
	_tester_poussee()
	print("Tests IA : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_niveaux() -> void:
	_verifier(IaNiveau.valide("n'importe") == IaNiveau.PAR_DEFAUT, "niveau inconnu : normal")
	for n in IaNiveau.NIVEAUX:
		_verifier(IaNiveau.NOMS.has(n) and IaNiveau.AIDES.has(n), "nom et aide du niveau " + n)
	var f := IaNiveau.params("facile")
	var m := IaNiveau.params("normal")
	var d := IaNiveau.params("difficile")
	_verifier(f["erreur_tir"] > m["erreur_tir"] and m["erreur_tir"] > d["erreur_tir"], "Arène : plus le niveau monte, plus l'ordi vise juste")
	_verifier(f["reaction"][0] > d["reaction"][0], "Arène : l'ordi difficile réagit plus vite")
	_verifier(f["esquive"] < m["esquive"] and m["esquive"] < d["esquive"], "Arène : l'ordi esquive plus souvent en montant de niveau")
	_verifier(f["pense"][0] > m["pense"][0] and m["pense"][0] > d["pense"][0], "Poussée : l'ordi difficile réfléchit plus vite")
	_verifier(not f["malin"] and m["malin"] and d["malin"], "Poussée : facile garde l'ancienne IA")
	_verifier(IaNiveau.valide(Reglages.difficulte()) == Reglages.difficulte(), "le réglage des Options est un niveau valide")


## Une fausse scène Poussée : juste ce que l'IA lit.
class FauxJeu extends RefCounted:
	var TERRAIN := Rect2(150, 176, 1620, 630)
	var ferveur := [10.0, 10.0]
	var piles := [[], []]
	var ballon := {"pos": Vector2(960, 491), "vel": Vector2.ZERO}
	var unites: Array = []
	var temps := 30.0
	var tribune := [PousseeRegles.TRIBUNE_PV, PousseeRegles.TRIBUNE_PV]


class FausseUnite extends RefCounted:
	var actif := true
	var equipe := 0
	var cle := ""
	var carte: Dictionary
	var pv := 100.0
	var position := Vector2.ZERO

	func _init(e: int, k: String, p: Vector2) -> void:
		equipe = e
		cle = k
		carte = PousseeRegles.CARTES[k]
		pv = carte["pv"]
		position = p


func _jeu(main: Array) -> FauxJeu:
	var j := FauxJeu.new()
	var reste := PousseeRegles.ORDRE.filter(func(c): return not c in main)
	j.piles[1] = main + reste
	return j


func _tester_poussee() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var p := IaNiveau.params("difficile")
	# l'ordi joue l'équipe 1 (à droite) : son but et sa tribune sont à droite
	var j := _jeu(["drapeau", "serpentins", "canon", "chorale"])
	j.ballon["pos"] = Vector2(1650, 490)
	j.ballon["vel"] = Vector2(80, 0)
	j.unites.append(FausseUnite.new(0, "drapeau", Vector2(1600, 490)))
	var d := IaPoussee.decider(j, 1, p, rng)
	_verifier(not d.is_empty(), "ballon tout près de son but : l'ordi réagit")
	if not d.is_empty():
		var cle: String = j.piles[1][d["i"]]
		_verifier(float(PousseeRegles.CARTES[cle]["poussee"]) >= 0.8, "ballon en danger : un pousseur (%s)" % cle)
		_verifier(d["pos"].x > j.ballon["pos"].x, "posé entre le ballon et son but")
	# une mascotte adverse chante contre sa tribune
	j = _jeu(["tambour", "canon", "ola", "chorale"])
	j.unites.append(FausseUnite.new(0, "mascotte", Vector2(1690, 300)))
	d = IaPoussee.decider(j, 1, p, rng)
	_verifier(not d.is_empty() and j.piles[1][d["i"]] in ["canon", "chorale"], "mascotte chez lui : canon ou chorale")
	if not d.is_empty():
		_verifier(d["pos"].x > j.TERRAIN.get_center().x, "posé dans sa moitié")
	# rien ne presse et peu de Ferveur : il attend pour lancer une vraie vague
	j = _jeu(["mascotte", "drapeau", "chorale", "canon"])
	j.ferveur[1] = 5.0
	d = IaPoussee.decider(j, 1, p, rng)
	_verifier(d.is_empty(), "rien ne presse : l'ordi garde sa Ferveur")
	# Ferveur pleine : il ne la laisse pas déborder
	j.ferveur[1] = PousseeRegles.FERVEUR_MAX
	d = IaPoussee.decider(j, 1, p, rng)
	_verifier(not d.is_empty(), "Ferveur pleine : l'ordi joue")
	# jamais une carte trop chère
	j = _jeu(["mascotte", "chorale", "canon", "drapeau"])
	j.ferveur[1] = 2.5
	j.ballon["pos"] = Vector2(1650, 490)
	d = IaPoussee.decider(j, 1, p, rng)
	_verifier(d.is_empty(), "pas assez de Ferveur pour ses cartes : il attend")
