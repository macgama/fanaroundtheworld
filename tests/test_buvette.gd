extends SceneTree
## Tests sans écran du petit boulot de buvette :
##   godot --headless --path . --script tests/test_buvette.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_commandes()
	_tester_conformite()
	_tester_paye()
	print("Tests buvette : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_commandes() -> void:
	var r := BuvetteRegles.new(42)
	var r2 := BuvetteRegles.new(42)
	_verifier(r.commande(5, false) == r2.commande(5, false), "même graine, même commande")
	for i in 3:
		_verifier(BuvetteRegles.nombre_articles(r.commande(i, false)["articles"]) == 1, "les 3 premiers clients commandent 1 article")
	for i in 200:
		var rush := i % 2 == 0
		var c := r.commande(3 + i, rush)
		var n := BuvetteRegles.nombre_articles(c["articles"])
		_verifier(n >= (2 if rush else 1) and n <= (4 if rush else 3), "taille de commande (%d, rush %s)" % [n, rush])
		for id in c["articles"]:
			_verifier(id in BuvetteRegles.ids(), "article connu")
			_verifier(int(c["articles"][id]) <= BuvetteRegles.MAX_PAR_ARTICLE, "pas plus de %d fois le même article" % BuvetteRegles.MAX_PAR_ARTICLE)
		_verifier(c["patience"] > 4.0, "assez de patience pour servir")
	var calme := r.commande(10, false)
	var presse := r.commande(10, true)
	var par_article := func(c): return c["patience"] / (5.0 + 1.6 * BuvetteRegles.nombre_articles(c["articles"]))
	_verifier(par_article.call(presse) < par_article.call(calme), "le rush raccourcit la patience")
	_verifier(not BuvetteRegles.en_rush(29.9) and BuvetteRegles.en_rush(30.0), "le rush commence à la mi-temps (30 s)")


func _tester_conformite() -> void:
	var cmd := {"boisson": 2, "frites": 1}
	_verifier(BuvetteRegles.conforme({"boisson": 2, "frites": 1}, cmd), "plateau exact accepté")
	_verifier(BuvetteRegles.conforme({"frites": 1, "boisson": 2, "gaufre": 0}, cmd), "l'ordre et les zéros ne comptent pas")
	_verifier(not BuvetteRegles.conforme({"boisson": 1, "frites": 1}, cmd), "il manque une boisson")
	_verifier(not BuvetteRegles.conforme({"boisson": 2, "frites": 1, "hotdog": 1}, cmd), "un article en trop")
	_verifier(not BuvetteRegles.conforme({}, cmd), "plateau vide refusé")


func _tester_paye() -> void:
	var cmd := {"boisson": 2, "hotdog": 1}
	var vite := BuvetteRegles.paye(cmd, 1.0, 1)
	_verifier(vite["salaire"] == 2, "1 Jeton par client, +1 pour 3 articles")
	_verifier(BuvetteRegles.paye({"frites": 1}, 1.0, 1)["salaire"] == 1, "1 Jeton pour un seul article")
	_verifier(vite["pourboire"] == BuvetteRegles.POURBOIRE_MAX, "pourboire plein si servi tout de suite")
	_verifier(BuvetteRegles.paye(cmd, 0.0, 1)["pourboire"] == 0, "pas de pourboire in extremis")
	_verifier(BuvetteRegles.paye(cmd, 0.5, BuvetteRegles.SERIE_BONUS)["bonus"] == 1, "bonus de série")
	_verifier(BuvetteRegles.paye(cmd, 0.5, BuvetteRegles.SERIE_BONUS - 1)["bonus"] == 0, "pas de bonus avant la série")
	_verifier(BuvetteRegles.paye(cmd, 0.5, BuvetteRegles.SERIE_BONUS + 1)["bonus"] == 0, "bonus une fois par tranche de série")
	_verifier(BuvetteRegles.paye(cmd, 0.5, BuvetteRegles.SERIE_BONUS * 2)["bonus"] == 1, "bonus à chaque tranche")
	var p := BuvetteRegles.paye(cmd, 0.7, 10)
	_verifier(p["total"] == p["salaire"] + p["pourboire"] + p["bonus"], "total = salaire + pourboire + bonus")
	_verifier(BuvetteRegles.paye_finale(41, 0) == 28, "plein tarif au 1er service")
	_verifier(BuvetteRegles.paye_finale(41, BuvetteRegles.SERVICES_PLEIN_TARIF) == 14, "paye ÷ 2 après %d services" % BuvetteRegles.SERVICES_PLEIN_TARIF)
	# Ordre de grandeur : même un service parfait (robot) rapporte moins qu'un bon duel au stade.
	var r := BuvetteRegles.new(7)
	var total := 0
	var t := 0.0
	var n := 0
	while t < BuvetteRegles.DUREE:
		var rush := BuvetteRegles.en_rush(t)
		var c := r.commande(n, rush)
		var duree_service := 0.9 + 0.45 * BuvetteRegles.nombre_articles(c["articles"])
		t += duree_service + 0.8
		total += BuvetteRegles.paye(c["articles"], 1.0 - duree_service / c["patience"], n + 1)["total"]
		n += 1
	print("  service parfait simulé : %d clients, %d Jetons" % [n, total])
	_verifier(total >= 20 and total <= 65, "paye d'un service parfait raisonnable (%d)" % total)
