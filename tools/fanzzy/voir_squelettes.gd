extends SceneTree
## Planche de contrôle du squelette automatique des FANZZY :
##   godot --headless --path . --script tools/fanzzy/voir_squelettes.gd -- sortie.png [dossier_etats [nombre]]
## Dessine hanches, jambes, torse, épaules et mains repérés sur chaque image.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var sortie: String = args[0] if args.size() > 0 else "user://squelettes.png"
	var images: Array = []
	var dossier := "res://assets/fanzzy/demo"
	for id in DirAccess.get_directories_at(dossier):
		var c := "%s/%s/e1/base/neutre.webp" % [dossier, id]
		if ResourceLoader.exists(c):
			images.append(c)
	if args.size() > 1:
		# dossier d'export TheBestFan : <id>/<evolution>/<skin>/neutre.webp
		images.clear()
		var maxi := int(args[2]) if args.size() > 2 else 36
		for id in DirAccess.get_directories_at(args[1]):
			for evo in DirAccess.get_directories_at(args[1].path_join(id)):
				for skin in DirAccess.get_directories_at(args[1].path_join(id).path_join(evo)):
					var c := args[1].path_join(id).path_join(evo).path_join(skin).path_join("neutre.webp")
					if FileAccess.file_exists(c) and images.size() < maxi:
						images.append(c)
	var cote := 280
	var colonnes := 9
	var lignes := int(ceil(images.size() / float(colonnes)))
	var planche := Image.create(cote * colonnes, int(cote * 1.72) * lignes, false, Image.FORMAT_RGBA8)
	planche.fill(Color("#3c8c50"))
	var t0 := Time.get_ticks_msec()
	var compte := {}
	for i in images.size():
		var img: Image
		if images[i].begins_with("res://"):
			img = (load(images[i]) as Texture2D).get_image()
		else:
			img = Image.load_from_file(images[i])
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var s := SqueletteFanzzy.analyser(img)
		_marquer(img, s)
		var k := float(cote) / img.get_width()
		img.resize(cote, int(img.get_height() * k))
		planche.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((i % colonnes) * cote, (i / colonnes) * int(cote * 1.72)))
		var d: Dictionary = s.get("detecte", {})
		for cle in d:
			if d[cle]:
				compte[cle] = compte.get(cle, 0) + 1
		if images.size() <= 40:
			print(images[i].get_base_dir().get_base_dir().get_base_dir().get_file(), " ", d)
	print("%d images analysées en %d ms, repérés : %s" % [images.size(), Time.get_ticks_msec() - t0, compte])
	planche.save_png(sortie)
	quit()


func _marquer(img: Image, s: Dictionary) -> void:
	if s.is_empty():
		return
	var w := img.get_width()
	_ligne_h(img, int(s.hanche), 0, w, Color.YELLOW)
	_croix(img, Vector2(s.entrejambe, s.hanche), Color.YELLOW)
	_croix(img, Vector2(s.jambes.x, s.hanche), Color.ORANGE)
	_croix(img, Vector2(s.jambes.y, s.hanche), Color.ORANGE)
	_ligne_v(img, int(s.torse.x), int(s.epaule.x), int(s.mains.x), Color.CYAN)
	_ligne_v(img, int(s.torse.y), int(s.epaule.y), int(s.mains.y), Color.MAGENTA)
	_croix(img, Vector2(s.torse.x, s.epaule.x), Color.CYAN)
	_croix(img, Vector2(s.torse.y, s.epaule.y), Color.MAGENTA)
	_ligne_h(img, int(s.mains.x), int(s.torse.x) - 60, int(s.torse.x), Color.CYAN)
	_ligne_h(img, int(s.mains.y), int(s.torse.y), int(s.torse.y) + 60, Color.MAGENTA)


func _ligne_h(img: Image, y: int, x0: int, x1: int, c: Color) -> void:
	for x in range(maxi(x0, 0), mini(x1, img.get_width())):
		for e in 4:
			if y + e < img.get_height():
				img.set_pixel(x, y + e, c)


func _ligne_v(img: Image, x: int, y0: int, y1: int, c: Color) -> void:
	for y in range(maxi(y0, 0), mini(y1, img.get_height())):
		for e in 4:
			if x + e < img.get_width():
				img.set_pixel(x + e, y, c)


func _croix(img: Image, p: Vector2, c: Color) -> void:
	for d in range(-14, 15):
		for e in 4:
			for q in [Vector2i(int(p.x) + d, int(p.y) + e - 2), Vector2i(int(p.x) + e - 2, int(p.y) + d)]:
				if q.x >= 0 and q.y >= 0 and q.x < img.get_width() and q.y < img.get_height():
					img.set_pixel(q.x, q.y, c)
