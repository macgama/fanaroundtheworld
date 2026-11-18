extends SceneTree
## Tests sans écran du petit boulot « vendeur d'écharpes » :
##   godot --headless --path . --script tests/test_echarpes.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_portant()
	_tester_commandes()
	_tester_paye()
	print("Tests écharpes : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_portant() -> void:
	var connus := EcharpesRegles.clubs_connus()
	_verifier(connus.size() >= EcharpesRegles.CLUBS_RUSH * 2, "assez de clubs fictifs pour le portant (%d)" % connus.size())
	for c in connus:
		_verifier(c.has("nom") and c.has("sigle") and c["c1"] is Color and c["c2"] is Color, "club au format {nom, sigle, c1, c2}")
	var a := {"c1": Color("#1e3a8a"), "c2": Color("#e8384f")}
	_verifier(EcharpesRegles.se_confondent(a, a), "même écharpe")
	_verifier(EcharpesRegles.se_confondent(a, {"c1": a["c2"], "c2": a["c1"]}), "couleurs inversées : on confond")
	_verifier(not EcharpesRegles.se_confondent(a, {"c1": Color("#ffd23f"), "c2": Color("#3ddc84")}), "jaune et vert : on ne confond pas")
	for graine in 50:
		var r := EcharpesRegles.new(graine)
		var p := r.portant(connus)
		_verifier(p.size() == EcharpesRegles.CLUBS_RUSH, "6 clubs sur le portant")
		var ok := true
		for i in p.size():
			for j in range(i + 1, p.size()):
				if EcharpesRegles.se_confondent(p[i], p[j]) or p[i]["nom"] == p[j]["nom"]:
					ok = false
		_verifier(ok, "aucune écharpe du portant ne se confond avec une autre (graine %d)" % graine)
	_verifier(EcharpesRegles.new(3).portant(connus) == EcharpesRegles.new(3).portant(connus), "même graine, même portant")


func _tester_commandes() -> void:
	var r := EcharpesRegles.new(42)
	_verifier(r.commande(5, false, 4) == EcharpesRegles.new(42).commande(5, false, 4), "même graine, même commande")
	for i in 3:
		_verifier(r.commande(i, true, 6)["echarpes"].size() == 1, "les 3 premiers clients veulent 1 écharpe")
	var doubles := [0, 0]
	for i in 400:
		var rush := i % 2 == 0
		var rayon := EcharpesRegles.nb_clubs(rush)
		var c := r.commande(3 + i, rush, rayon)
		var l: Array = c["echarpes"]
		_verifier(l.size() >= 1 and l.size() <= 2, "1 ou 2 écharpes")
		if l.size() == 2:
			doubles[1 if rush else 0] += 1
			_verifier(l[0] != l[1], "jamais deux fois la même écharpe")
		for e in l:
			_verifier(e >= 0 and e < rayon, "on ne demande que des clubs accrochés (%d/%d)" % [e, rayon])
		_verifier(c["patience"] > 4.0, "assez de patience pour servir")
	_verifier(doubles[1] > doubles[0], "plus de commandes doubles au rush")
	var calme := r.commande(10, false, 4)
	var presse := r.commande(10, true, 6)
	var par := func(c): return c["patience"] / (3.5 + 2.2 * c["echarpes"].size())
	_verifier(par.call(presse) < par.call(calme), "le rush raccourcit la patience")
	_verifier(not EcharpesRegles.en_rush(29.9) and EcharpesRegles.en_rush(30.0), "le rush commence à 30 s")
	_verifier(EcharpesRegles.nb_clubs(false) == 4 and EcharpesRegles.nb_clubs(true) == 6, "4 clubs puis 6 au rush")


func _tester_paye() -> void:
	var vite := EcharpesRegles.paye(2, 1.0, 1)
	_verifier(vite["salaire"] == 2, "1 Jeton par écharpe")
	_verifier(vite["pourboire"] == EcharpesRegles.POURBOIRE_MAX, "pourboire plein si servi tout de suite")
	_verifier(EcharpesRegles.paye(1, 0.0, 1)["pourboire"] == 0, "pas de pourboire in extremis")
	_verifier(EcharpesRegles.paye(1, 0.5, EcharpesRegles.SERIE_BONUS)["bonus"] == 1, "bonus de série")
	_verifier(EcharpesRegles.paye(1, 0.5, EcharpesRegles.SERIE_BONUS + 1)["bonus"] == 0, "bonus une fois par tranche")
	var p := EcharpesRegles.paye(2, 0.7, 10)
	_verifier(p["total"] == p["salaire"] + p["pourboire"] + p["bonus"], "total = salaire + pourboire + bonus")
	_verifier(EcharpesRegles.paye_finale(41, 0) == 28, "plein tarif au 1er service")
	_verifier(EcharpesRegles.paye_finale(41, EcharpesRegles.SERVICES_PLEIN_TARIF) == 14, "paye ÷ 2 après %d services" % EcharpesRegles.SERVICES_PLEIN_TARIF)
	# Service parfait simulé (robot), avec les allers au carton : du même ordre que la buvette.
	var r := EcharpesRegles.new(7)
	var stock := [3, 3, 3, 3, 3, 3]
	var total := 0
	var t := 0.0
	var n := 0
	while t < EcharpesRegles.DUREE:
		var rush := EcharpesRegles.en_rush(t)
		var c := r.commande(n, rush, EcharpesRegles.nb_clubs(rush))
		var duree: float = 0.8 + 0.4 * c["echarpes"].size()
		for e in c["echarpes"]:
			if stock[e] == 0:
				duree += EcharpesRegles.DUREE_REASSORT
				stock = [3, 3, 3, 3, 3, 3]
			stock[e] -= 1
		t += duree + 0.8
		total += EcharpesRegles.paye(c["echarpes"].size(), 1.0 - duree / c["patience"], n + 1)["total"]
		n += 1
	print("  service parfait simulé : %d clients, %d Jetons" % [n, total])
	_verifier(total >= 20 and total <= 65, "paye d'un service parfait raisonnable (%d)" % total)
