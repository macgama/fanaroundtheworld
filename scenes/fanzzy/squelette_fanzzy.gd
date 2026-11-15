class_name SqueletteFanzzy
extends RefCounted
## Squelette 2D d'un FANZZY, retrouvé automatiquement sur sa silhouette.
##
## Les FANZZY sont dessinés d'une seule pièce, de face, bras le long du corps
## et jambes écartées. Sans rien découper, on repère sur le masque de
## transparence :
##   - les deux jambes (le vide entre elles) et l'entrejambe (= les hanches) ;
##   - le torse et les deux bras qui pendent de chaque côté, jusqu'aux mains
##     (un objet tenu en main, pelle ou sac, suit donc le bras) ;
##   - les épaules, en remontant chaque bras depuis la main.
## Le shader fanzzy_deformation fait ensuite pivoter jambes et bras autour de
## ces articulations (marcher, courir, lancer, célébrer).
##
## Tout se calcule au chargement, pour chaque image, en quelques millisecondes :
## aucun fichier à produire, et chaque nouveau FANZZY ou skin marche tout seul.
## Si la silhouette ne s'y prête pas (macareux, glacière...), des proportions
## par défaut prennent le relais.
##
## Résultat en pixels de l'image d'origine :
##   pieds (y), hanche (y), entrejambe (x), jambes (Vector2 : x des deux jambes),
##   jambes_ext (Vector2 : bords extérieurs des jambes),
##   torse (Vector2 : bords gauche et droit), epaule (Vector2 : y gauche, droite),
##   mains (Vector2 : y gauche, droite), detecte {jambes, bras_g, bras_d}

const PAS := 4 # on lit un pixel sur 4 dans chaque sens

static var _cache := {}


static func de_texture(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {}
	var cle := tex.resource_path if tex.resource_path != "" else str(tex.get_rid())
	if not _cache.has(cle):
		var img := tex.get_image()
		_cache[cle] = analyser(img) if img else {}
	return _cache[cle]


static func analyser(source: Image) -> Dictionary:
	var img := source
	if img.is_compressed():
		img = source.duplicate()
		img.decompress()
	var W := img.get_width() / PAS
	var H := img.get_height() / PAS
	var m := PackedByteArray()
	m.resize(W * H)
	var haut := H
	var bas := -1
	var gauche := W
	var droite := -1
	for y in H:
		for x in W:
			if img.get_pixel(x * PAS + PAS / 2, y * PAS + PAS / 2).a > 0.5:
				m[y * W + x] = 1
				haut = mini(haut, y)
				bas = maxi(bas, y)
				gauche = mini(gauche, x)
				droite = maxi(droite, x)
	if bas < 0:
		return {}
	var hb := float(bas - haut)
	var wb := float(droite - gauche)
	# axe du corps : moyenne des pixels opaques au niveau du ventre
	var somme := 0.0
	var n := 0
	for y in range(haut + int(hb * 0.35), haut + int(hb * 0.6)):
		for x in W:
			if m[y * W + x]:
				somme += x
				n += 1
	var cx := somme / maxf(n, 1)

	# --- jambes : le vide entre elles, en remontant depuis les pieds
	var hanche := -1
	var entre := cx
	var jg := -1.0
	var jd := -1.0
	var lignes_vide := 0
	var dernier_vide := -1
	for y in range(bas - 1, haut + int(hb * 0.35), -1):
		var trou := _trou_central(m, W, y, cx, wb * 0.14)
		if trou.x >= 0.0:
			lignes_vide += 1
			dernier_vide = y
			if lignes_vide == 3:
				entre = (trou.x + trou.y) * 0.5
		elif lignes_vide > 0:
			if dernier_vide - y > 2: # le trou s'est refermé pour de bon
				break
	var jambes_ok := lignes_vide >= int(hb * 0.08)
	if jambes_ok:
		hanche = dernier_vide
		entre = _centre_trou(m, W, mini(hanche + 2, bas), cx, wb * 0.14, entre)
		var y_mi := (hanche + bas) / 2
		var runs := _segments(m, W, y_mi)
		for r in runs:
			if r.y < entre and (jg < 0.0 or r.y > jg):
				jg = (r.x + r.y) * 0.5
			if r.x > entre and jd < 0.0:
				jd = (r.x + r.y) * 0.5
	if not jambes_ok or jg < 0.0 or jd < 0.0:
		hanche = bas - int(hb * 0.42)
		entre = cx
		jg = cx - wb * 0.12
		jd = cx + wb * 0.12
	hanche = clampi(hanche, haut + int(hb * 0.35), bas - int(hb * 0.15))
	# largeur des jambes (pieds compris) : ce qui est plus loin sur les côtés
	# (pelle posée au sol, pans d'écharpe) ne suit pas les jambes
	var ext := Vector2(jg - wb * 0.1, jd + wb * 0.1)
	if jambes_ok:
		ext = Vector2(entre, entre)
		for y in [(hanche + bas) / 2, bas - int(hb * 0.06), bas - 1]:
			for r in _segments(m, W, y):
				var centre: float = (r.x + r.y) * 0.5
				if centre < entre and centre > jg - wb * 0.15:
					ext.x = minf(ext.x, r.x)
				if centre > entre and centre < jd + wb * 0.15:
					ext.y = maxf(ext.y, r.y + 1)
		ext += Vector2(-2, 2)

	# --- torse et bras qui pendent : lignes où le bras est séparé du torse
	var bords_g: Array = []
	var bords_d: Array = []
	for y in range(haut + int(hb * 0.2), mini(hanche + int(hb * 0.1), bas)):
		var runs := _segments(m, W, y)
		var t := -1
		for i in runs.size():
			if runs[i].x <= cx and runs[i].y >= cx:
				t = i
		if t < 0:
			continue
		if t > 0 and runs[t].x - runs[t - 1].y > 1 and runs[t].x - runs[t - 1].y < wb * 0.2:
			bords_g.append(runs[t].x)
		if t < runs.size() - 1 and runs[t + 1].x - runs[t].y > 1 and runs[t + 1].x - runs[t].y < wb * 0.2:
			bords_d.append(runs[t].y)
	var bras_g := bords_g.size() >= int(hb * 0.05)
	var bras_d := bords_d.size() >= int(hb * 0.05)
	# un « bord du torse » collé à l'axe du corps est une erreur de lecture
	# (bras posé sur le ventre, objet tenu devant soi) : ce bras restera fixe
	if bras_g and cx - _mediane(bords_g) < wb * 0.14:
		bras_g = false
	if bras_d and _mediane(bords_d) - cx < wb * 0.14:
		bras_d = false
	var demi_torse := maxf(wb * 0.2, (jd - jg) * 0.5 + wb * 0.1)
	var tg := float(_mediane(bords_g)) if bras_g else cx - demi_torse
	var td := float(_mediane(bords_d)) + 1.0 if bras_d else cx + demi_torse

	# mains : la ligne la plus basse avec de la matière dehors du torse ;
	# épaules : en remontant le bras depuis la main
	var mains := Vector2.ZERO
	var epaules := Vector2.ZERO
	for c in 2:
		var bord := tg if c == 0 else td
		var sens := -1 if c == 0 else 1
		var largeur := int(wb * 0.3)
		# le bras est une bande de matière continue dehors du torse :
		# on part du niveau des hanches et on la suit vers le bas puis vers le haut
		var y0 := hanche - int(hb * 0.08)
		while y0 > hanche - int(hb * 0.3) and not _matiere(m, W, y0, bord, sens, largeur):
			y0 -= 1
		var main := y0
		while main < bas - int(hb * 0.1) and _matiere(m, W, main + 1, bord, sens, largeur):
			main += 1
		var ep := y0
		while ep > haut + int(hb * 0.12) and _matiere(m, W, ep - 1, bord, sens, largeur):
			ep -= 1
		main = mini(main, hanche + int(hb * 0.2)) # un objet tenu peut descendre plus bas
		if main - ep < hb * 0.12: # rien de visible : proportions par défaut
			ep = haut + int(hb * 0.24)
			main = maxi(main, hanche)
		if c == 0:
			mains.x = main
			epaules.x = ep
		else:
			mains.y = main
			epaules.y = ep
	var p := float(PAS)
	return {
		"pieds": (bas + 1) * p,
		"hanche": hanche * p,
		"entrejambe": entre * p + p * 0.5,
		"jambes": Vector2(jg, jd) * p + Vector2.ONE * p * 0.5,
		"jambes_ext": ext * p,
		"torse": Vector2(tg, td) * p,
		"epaule": epaules * p,
		"mains": (mains + Vector2.ONE) * p,
		"detecte": {"jambes": jambes_ok, "bras_g": bras_g, "bras_d": bras_d},
	}


## Segments opaques d'une ligne : Vector2i(x début, x fin).
static func _segments(m: PackedByteArray, W: int, y: int) -> Array:
	var r: Array = []
	var debut := -1
	for x in W:
		var plein := m[y * W + x] == 1
		if plein and debut < 0:
			debut = x
		elif not plein and debut >= 0:
			r.append(Vector2i(debut, x - 1))
			debut = -1
	if debut >= 0:
		r.append(Vector2i(debut, W - 1))
	return r


## Vide entre deux segments près de l'axe : Vector2(x début, x fin) ou (-1, -1).
static func _trou_central(m: PackedByteArray, W: int, y: int, cx: float, tolerance: float) -> Vector2:
	var runs := _segments(m, W, y)
	for i in runs.size() - 1:
		var a: int = runs[i].y + 1
		var b: int = runs[i + 1].x - 1
		if b >= a and (a + b) * 0.5 > cx - tolerance and (a + b) * 0.5 < cx + tolerance:
			return Vector2(a, b)
	return Vector2(-1, -1)


static func _centre_trou(m: PackedByteArray, W: int, y: int, cx: float, tol: float, defaut: float) -> float:
	var t := _trou_central(m, W, y, cx, tol)
	return (t.x + t.y) * 0.5 if t.x >= 0.0 else defaut


## Y a-t-il de la matière à l'extérieur du torse (côté sens) sur cette ligne ?
static func _matiere(m: PackedByteArray, W: int, y: int, bord: float, sens: int, largeur: int) -> bool:
	var x0 := int(bord) + sens * 2
	for k in largeur:
		var x := x0 + sens * k
		if x < 0 or x >= W:
			break
		if m[y * W + x] == 1:
			return true
	return false


static func _mediane(a: Array) -> int:
	if a.is_empty():
		return 0
	var b := a.duplicate()
	b.sort()
	return b[b.size() / 2]
