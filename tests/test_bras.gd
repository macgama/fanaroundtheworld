extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_bras.gd
## Vérifie que les bras levés des FANZZY de démo sont repérés et bougent.

var _echecs := 0


func _init() -> void:
	var f := FanzzyAnime.creer("AN2")
	root.add_child(f)
	await process_frame
	var bras: Dictionary = f.expressions.get(&"bras", {})
	_verifier(bras.has("joie"), "bras.json lu pour AN2")
	f.jouer(&"agiter_echarpe")
	_verifier(f.expression() == &"joie", "agiter l'écharpe se fait bras levés")
	_verifier(f._bras.has("g") and f._bras.has("d"), "deux bras repérés en joie")
	for i in 20:
		await process_frame
	var poing: Vector2 = f._bras.g.poing
	f._p.bg = 0.4
	var bouge := f._deformer(poing)
	f._p.bg = 0.0
	var fixe := f._deformer(poing)
	_verifier(bouge.distance_to(fixe) > 20.0, "le poing gauche suit l'angle du bras")
	# sous les épaules, rien ne bouge
	var ventre: Vector2 = f._bras.tete + Vector2(-f._bras.demi * 2.0, 60.0)
	var avant := f._deformer(ventre)
	f._p.bg = 0.4
	_verifier(f._deformer(ventre).distance_to(avant) < 0.01, "le corps sous l'épaule ne bouge pas")
	f._p.bg = 0.0
	# un FANZZY sans repères garde ses bras immobiles
	var g := FanzzyAnime.new()
	g.texture = f.expressions[&"neutre"]
	root.add_child(g)
	await process_frame
	g.jouer(&"celebrer")
	_verifier(g._bras.is_empty(), "sans bras.json : pas de pliage")
	print("Tests bras : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)
