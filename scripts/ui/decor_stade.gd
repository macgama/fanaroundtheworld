class_name DecorStade
extends Control
## Fond animé de l'écran d'accueil : ciel du soir, projecteurs qui balaient,
## tribunes pleines de supporters qui sautillent, pelouse et confettis.

const COULEURS_FOULE := [Ui.ROSE, Ui.JAUNE, Ui.VERT, Ui.VIOLET, Ui.BLANC, Ui.OCEAN]

var _t := 0.0
var _foule: Array = []      # [x relatif 0..1, rang, couleur, phase]
var _confettis: Array = []  # [pos, vitesse, couleur, angle, tourne]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for rang in 4:
		var n := 38 + rang * 6
		for i in n:
			_foule.append([(i + rng.randf() * 0.6) / float(n), rang, COULEURS_FOULE[rng.randi() % COULEURS_FOULE.size()], rng.randf() * TAU])
	for i in 70:
		_confettis.append(_nouveau_confetti(rng, true))


func _nouveau_confetti(rng: RandomNumberGenerator, partout := false) -> Array:
	var x := rng.randf() * maxf(size.x, 1920.0)
	var y := rng.randf() * 1080.0 if partout else -20.0
	return [Vector2(x, y), Vector2(rng.randf_range(-30, 30), rng.randf_range(60, 140)),
		COULEURS_FOULE[rng.randi() % 4], rng.randf() * TAU, rng.randf_range(-4, 4)]


func _process(delta: float) -> void:
	_t += delta
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for i in _confettis.size():
		var c: Array = _confettis[i]
		c[0] += c[1] * delta + Vector2(sin(_t * 2.0 + i) * 20.0 * delta, 0)
		c[3] += c[4] * delta
		if c[0].y > size.y + 20:
			_confettis[i] = _nouveau_confetti(rng)
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	# ciel du soir en bandes
	var bandes := [Color("#1a1550"), Color("#221b6b"), Color("#2b2390"), Color("#3a2db0"), Color("#4b3acb")]
	for i in bandes.size():
		draw_rect(Rect2(0, h * 0.11 * i, w, h * 0.11 + 2), bandes[i])
	# projecteurs qui balaient
	for k in 2:
		var pied := Vector2(w * (0.12 if k == 0 else 0.88), h * 0.08)
		var ang := PI / 2.0 + (0.35 if k == 0 else -0.35) + sin(_t * 0.6 + k * 1.7) * 0.25
		var dir := Vector2.from_angle(ang)
		var lat := dir.orthogonal()
		var loin := pied + dir * h * 1.1
		draw_colored_polygon(PackedVector2Array([pied, loin + lat * 260.0, loin - lat * 260.0]), Color(1, 0.95, 0.7, 0.07))
		draw_colored_polygon(PackedVector2Array([pied, loin + lat * 120.0, loin - lat * 120.0]), Color(1, 0.95, 0.7, 0.06))
		_mat(pied)
	# tribunes : 4 rangs courbés, du fond vers l'avant
	var tribunes := [Color("#5a2fa8"), Color("#6a35c0"), Color("#7b3dd6"), Color("#8b5cff")]
	var sprites := FouleSprites.disponible()
	for rang in 4:
		var y0 := h * (0.47 + rang * 0.075)
		var pts := PackedVector2Array()
		for i in 33:
			var x := w * i / 32.0
			pts.append(Vector2(x, y0 - sin(PI * i / 32.0) * h * 0.05))
		pts.append(Vector2(w, h))
		pts.append(Vector2(0, h))
		draw_colored_polygon(pts, tribunes[rang])
		draw_polyline(pts.slice(0, 33), Ui.CONTOUR, 5.0, true)
		for f in _foule:
			if f[1] != rang:
				continue
			var x: float = f[0] * w
			var saut := maxf(0.0, sin(_t * 5.0 + f[3])) * (6.0 + rang * 2.0)
			var y := y0 - sin(PI * f[0]) * h * 0.05 + h * 0.035 - saut
			var r := 7.0 + rang * 2.0
			if sprites:
				# supporters Quaternius : chacun son geste, écharpe d'une autre couleur
				var ga := FouleSprites.geste_ambiance(0.8, f[3] / TAU, _t)
				var autre: Color = COULEURS_FOULE[int(f[3] * 10.0) % COULEURS_FOULE.size()]
				FouleSprites.dessiner(self, Vector2(x, y + saut + r * 3.9), r * 5.4, ga[0], ga[1], f[2], autre,
					FouleSprites.PEAUX[int(f[3] * 31.0) % FouleSprites.PEAUX.size()], int(f[3] * 17.0) % 3)
				continue
			draw_circle(Vector2(x, y + r * 1.4), r * 1.1, f[2].darkened(0.25))
			draw_circle(Vector2(x, y), r, Color("#f2c9a0"))
			if sin(_t * 2.0 + f[3] * 3.0) > 0.6:  # bras levés
				draw_line(Vector2(x - r, y + r), Vector2(x - r * 1.6, y - r * 1.4), f[2], r * 0.5, true)
				draw_line(Vector2(x + r, y + r), Vector2(x + r * 1.6, y - r * 1.4), f[2], r * 0.5, true)
	# pelouse
	var py := h * 0.80
	var herbe := PackedVector2Array([Vector2(0, py), Vector2(w, py), Vector2(w, h), Vector2(0, h)])
	draw_colored_polygon(herbe, Color("#2fb35a"))
	for i in 12:
		if i % 2 == 0:
			draw_rect(Rect2(w * i / 12.0, py, w / 12.0, h - py), Color("#35c264"))
	draw_line(Vector2(0, py), Vector2(w, py), Ui.CONTOUR, 6.0)
	draw_line(Vector2(0, py + 40), Vector2(w, py + 40), Color(1, 1, 1, 0.6), 4.0)
	# confettis
	for c in _confettis:
		var xf := Transform2D(c[3], c[0])
		draw_set_transform_matrix(xf)
		draw_rect(Rect2(-7, -4, 14, 8), c[2])
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _mat(pied: Vector2) -> void:
	draw_rect(Rect2(pied.x - 5, pied.y, 10, size.y * 0.32), Color("#14112e"))
	draw_rect(Rect2(pied.x - 46, pied.y - 30, 92, 40), Ui.CONTOUR)
	for i in 3:
		draw_circle(Vector2(pied.x - 28 + i * 28, pied.y - 10), 11, Color("#fff6c8"))
