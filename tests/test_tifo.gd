extends SceneTree
## Tests sans écran du petit boulot de peintre de tifo :
##   godot --headless --path . --script tests/test_tifo.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_modeles()
	_tester_seau()
	_tester_ressemblance()
	_tester_paye()
	print("Tests tifo : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_modeles() -> void:
	var r := TifoRegles.new(7)
	var r2 := TifoRegles.new(7)
	_verifier(r.modele(4) == r2.modele(4), "même graine, même modèle")
	_verifier(r.modele(0)["motif"] == "drapeau" and r.modele(1)["motif"] == "echarpe", "les deux premières bâches sont simples")
	_verifier(TifoRegles.taille(0) == Vector2i(8, 5) and TifoRegles.taille(99) == TifoRegles.TAILLES[-1], "les bâches grandissent puis plafonnent")
	for motif in TifoRegles.MOTIFS_FACILES + TifoRegles.MOTIFS:
		for t in TifoRegles.TAILLES:
			var c := TifoRegles.dessiner(motif, t.x, t.y, 1, 2, 3)
			_verifier(c.size() == t.x * t.y, "%s %s : bonne taille" % [motif, t])
			var vues := {}
			for v in c:
				vues[v] = true
				_verifier(v >= 0 and v < TifoRegles.PEINTURES.size(), "%s : peinture valide" % motif)
			_verifier(vues.size() >= 2, "%s %s : au moins deux couleurs" % [motif, t])
	for i in 30:
		var m := r.modele(i)
		_verifier(m["cases"].size() == m["w"] * m["h"], "modèle %d complet" % i)


func _tester_seau() -> void:
	var b := TifoRegles.bache_vierge(4, 3)
	_verifier(TifoRegles.seau(b, 4, 3, 0, 0, 2) == 12, "le seau remplit toute la bâche vierge")
	_verifier(TifoRegles.seau(b, 4, 3, 1, 1, 2) == 0, "seau de la même couleur : rien ne change")
	# un mur vertical de rose sépare la bâche en deux
	for j in 3:
		b[j * 4 + 1] = 1
	_verifier(TifoRegles.seau(b, 4, 3, 0, 0, 3) == 3, "le seau s'arrête aux autres couleurs")
	_verifier(b[2] == 2 and b[0] == 3, "l'autre côté du mur est intact")
	_verifier(TifoRegles.seau(b, 4, 3, 9, 9, 3) == 0, "hors de la bâche : rien")


func _tester_ressemblance() -> void:
	var m := TifoRegles.dessiner("drapeau", 8, 5, 1, 2, 3)
	_verifier(is_equal_approx(TifoRegles.ressemblance(m.duplicate(), m), 1.0), "bâche identique = 100 %")
	_verifier(TifoRegles.ressemblance(TifoRegles.bache_vierge(8, 5), m) == 0.0, "bâche vierge = 0 %")
	var b := m.duplicate()
	for i in 4:
		b[i] = TifoRegles.VIERGE
	_verifier(is_equal_approx(TifoRegles.ressemblance(b, m), 0.9), "4 cases fausses sur 40 = 90 %")


func _tester_paye() -> void:
	_verifier(TifoRegles.salaire_de_base(40) == 3 and TifoRegles.salaire_de_base(144) == 9, "salaire de base selon la taille")
	_verifier(not TifoRegles.paye(40, 0.7, 0)["accepte"], "moins de 75 % : refusée")
	_verifier(TifoRegles.paye(40, 0.7, 0)["total"] == 0, "refusée : pas de paye")
	var p := TifoRegles.paye(144, 1.0, 1)
	_verifier(p["salaire"] == 9 and p["bonus"] == 1 and p["total"] == 10, "parfaite : salaire plein + bonus")
	_verifier(TifoRegles.paye(144, 1.0, 3)["bonus"] == 2, "3 parfaites d'affilée : bonus de série")
	_verifier(TifoRegles.paye(144, 0.92, 0)["total"] == 5, "90 % : 60 % du salaire")
	_verifier(TifoRegles.paye(144, 0.8, 0)["total"] == 3, "75 % : 30 % du salaire")
	_verifier(TifoRegles.paye_finale(40, 2) == 40, "3e service du jour : plein tarif")
	_verifier(TifoRegles.paye_finale(41, 3) == 21, "4e service du jour : paye ÷ 2")
