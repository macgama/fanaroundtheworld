extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_jus.gd
## Vérifie le « jus » des FANZZY : ressorts, impact, bond, traînée, poussière.

var _echecs := 0


func _init() -> void:
	var f := FanzzyAnime.creer("AN2")
	f.position = Vector2(400, 800)
	f.scale = Vector2.ONE * 0.3
	root.add_child(f)
	for i in 5:
		await process_frame

	# pop : écrase puis revient au repos
	f.pop(2.0)
	for i in 4:
		await process_frame
	_verifier(f._ressort > 0.02, "pop écrase le FANZZY")
	await _attendre(1.2)
	_verifier(absf(f._ressort) < 0.01 and absf(f._ressort_v) < 0.2, "le ressort se calme")

	# impact venant de la gauche : éclair, recule vers la droite, étoiles
	f.impact(f.global_position + Vector2(-100, 0), 1.0)
	_verifier(f._flash > 0.9, "l'impact allume l'éclair")
	var avant := f._particules.size()
	_verifier(avant >= 5, "étoiles d'impact")
	for i in 4:
		await process_frame
	_verifier(f._recul > 0.01, "touché à gauche, il recule vers la droite")
	await _attendre(0.5)
	_verifier(f._flash == 0.0, "l'éclair s'éteint")

	# bond : décolle puis retombe avec de la poussière
	await _attendre(1.0)
	f.rebondir(1.0)
	var haut := 0.0
	var fin := Time.get_ticks_msec() + 450
	while Time.get_ticks_msec() < fin:
		await process_frame
		haut = maxf(haut, f._p.saut)
	_verifier(haut > f._rect.size.y * 0.05, "le bond décolle")
	await _attendre(0.6)
	_verifier(f._bond < 0.0, "le bond se termine")

	# poussière posée dans la scène
	f.poussiere(6)
	_verifier(f._nuages_poussiere.size() >= 6, "poussière créée")
	var p0: Vector2 = f._nuages_poussiere[0].pos
	f.position.x += 200
	await process_frame
	_verifier((f._nuages_poussiere[0].pos as Vector2).distance_to(p0) < 30.0, "la poussière ne suit pas le FANZZY")

	# traînée
	f.trainee = 0.3
	for i in 8:
		await process_frame
		f.position.x += 15
	_verifier(f._fantomes.size() >= 2, "la traînée laisse des fantômes")
	await _attendre(0.6)
	_verifier(f._fantomes.is_empty(), "les fantômes s'effacent")

	# étourdi
	f.etourdir(0.3)
	_verifier(f._etourdi > 0.0, "étoiles d'étourdissement")
	await _attendre(0.5)
	_verifier(f._etourdi == 0.0, "l'étourdissement passe")

	# changer d'action donne un coup d'élastique
	f.jouer(&"celebrer")
	await process_frame
	await process_frame
	_verifier(absf(f._ressort) > 0.005 or absf(f._ressort_v) > 0.5, "célébrer démarre d'un coup d'élastique")

	print("test_jus : ", "OK" if _echecs == 0 else "%d échec(s)" % _echecs)
	quit(1 if _echecs else 0)


func _attendre(s: float) -> void:
	await create_timer(s).timeout


func _verifier(ok: bool, nom: String) -> void:
	if not ok:
		_echecs += 1
		printerr("ÉCHEC : ", nom)
