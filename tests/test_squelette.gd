extends SceneTree
## Tests sans écran du squelette 2D automatique des FANZZY :
##   godot --headless --path . --script tests/test_squelette.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_silhouette_dessinee()
	_tester_demo()
	await _tester_animation()
	print("Tests squelette : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


## Un bonhomme dessiné à la main : tête, torse, deux bras écartés, deux jambes.
func _tester_silhouette_dessinee() -> void:
	var img := Image.create(400, 800, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	img.fill_rect(Rect2i(160, 40, 80, 90), Color.WHITE)    # tête
	img.fill_rect(Rect2i(130, 140, 140, 300), Color.WHITE)  # torse : 130..270, jusqu'à y = 440
	img.fill_rect(Rect2i(90, 150, 30, 300), Color.WHITE)    # bras gauche : mains à y = 450
	img.fill_rect(Rect2i(280, 150, 30, 300), Color.WHITE)   # bras droit
	img.fill_rect(Rect2i(140, 440, 50, 340), Color.WHITE)   # jambe gauche : pieds à y = 780
	img.fill_rect(Rect2i(210, 440, 50, 340), Color.WHITE)   # jambe droite
	var s := SqueletteFanzzy.analyser(img)
	_verifier(s.detecte.jambes and s.detecte.bras_g and s.detecte.bras_d, "tout est repéré sur le bonhomme")
	_verifier(absf(s.pieds - 780.0) <= 4.0, "pieds à 780 (%s)" % s.pieds)
	_verifier(absf(s.hanche - 440.0) <= 12.0, "hanches à 440 (%s)" % s.hanche)
	_verifier(absf(s.entrejambe - 200.0) <= 8.0, "entrejambe au milieu (%s)" % s.entrejambe)
	_verifier(absf(s.jambes.x - 165.0) <= 8.0 and absf(s.jambes.y - 235.0) <= 8.0, "axes des jambes (%s)" % s.jambes)
	_verifier(absf(s.torse.x - 130.0) <= 6.0 and absf(s.torse.y - 270.0) <= 6.0, "bords du torse (%s)" % s.torse)
	_verifier(absf(s.epaule.x - 150.0) <= 10.0, "épaule gauche (%s)" % s.epaule)
	_verifier(absf(s.mains.y - 450.0) <= 10.0, "main droite (%s)" % s.mains)
	# une forme sans jambes ni bras (glacière, ballon) : proportions par défaut
	var bloc := Image.create(300, 600, false, Image.FORMAT_RGBA8)
	bloc.fill(Color(0, 0, 0, 0))
	bloc.fill_rect(Rect2i(50, 100, 200, 480), Color.WHITE)
	var b := SqueletteFanzzy.analyser(bloc)
	_verifier(not b.detecte.jambes and not b.detecte.bras_g, "bloc : rien de repéré, rien ne bougera")


func _tester_demo() -> void:
	var dossier := "res://assets/fanzzy/demo"
	var n := 0
	var jambes := 0
	for id in DirAccess.get_directories_at(dossier):
		var c := "%s/%s/e1/base/neutre.webp" % [dossier, id]
		if not ResourceLoader.exists(c):
			continue
		var s := SqueletteFanzzy.de_texture(load(c))
		n += 1
		if s.detecte.jambes:
			jambes += 1
		var h: float = s.pieds
		_verifier(s.hanche > h * 0.3 and s.hanche < h * 0.9, "%s : hanches plausibles" % id)
		_verifier(s.torse.x < s.torse.y, "%s : torse dans l'ordre" % id)
		_verifier(s.epaule.x < s.mains.x and s.epaule.y < s.mains.y, "%s : épaules au-dessus des mains" % id)
	_verifier(n >= 18, "18 FANZZY de démo analysés")
	_verifier(jambes >= n - 2, "jambes repérées sur presque tous (%d/%d)" % [jambes, n])


func _tester_animation() -> void:
	var f := FanzzyAnime.creer("AN2")
	root.add_child(f)
	await process_frame
	_verifier(not f.squelette.is_empty(), "squelette calculé au chargement")
	_verifier(f._morceaux.size() == 4 and f._morceaux[0].visible, "4 morceaux (jambes, bras) visibles")
	f.jouer(&"courir")
	var angles := {}
	for i in 30:
		await process_frame
		angles[snappedf(f._p.jg, 0.01)] = true
	_verifier(angles.size() > 5, "les jambes bougent en courant")
	f.squelette_actif = false
	f.jouer(&"repos")
	await process_frame
	f._appliquer_expression(f.expression())
	_verifier(not f._morceaux[0].visible, "squelette désactivable")
	f.queue_free()
