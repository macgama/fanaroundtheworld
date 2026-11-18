class_name LocalDessin
extends Control
## Le local du fan club vu en coupe : salle principale, salle des chants,
## salle des trophées, parking du car (voir LocalClub). Dessiné sur un canevas
## de 1200 × 660, mis à l'échelle de la place disponible.
## Une salle pas construite est un terrain à bâtir en pointillés.

const W := 1200.0
const H := 660.0
const SOL := 580.0
## x de début et largeur de chaque salle
const PLAN := {"principale": [40.0, 380.0], "chants": [420.0, 280.0], "trophees": [700.0, 280.0], "parking": [980.0, 200.0]}

var etat: Dictionary = LocalClub.vide()
var c1 := Ui.BLEU
var c2 := Ui.BLANC
var nom_club := ""
## Chiffres de la salle des trophées : {tampons, souvenirs, succes}.
var chiffres := {"tampons": 0, "souvenirs": 0, "succes": 0}
var _t := 0.0
var _k := 1.0
var _o := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _k


func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(_p(x, y), Vector2(w, h) * _k)


func _draw() -> void:
	_k = minf(size.x / W, size.y / H)
	if _k <= 0.01:
		return  # pas encore de place (premier affichage)
	_o = (size - Vector2(W, H) * _k) / 2.0
	# ciel et sol
	draw_rect(_r(0, 0, W, SOL), Color("#8fd3ff"))
	draw_circle(_p(1100, 90), 46 * _k, Color("#ffe27a"))
	for i in 3:
		var x := fmod(150.0 + i * 420.0 + _t * 12.0, W + 200.0) - 100.0
		_nuage(Vector2(x, 70.0 + i * 30.0))
	draw_rect(_r(0, SOL, W, H - SOL), Color("#5bbf5a"))
	draw_rect(_r(0, SOL, W, 10), Color("#3f9a45"))
	for id in ["principale", "chants", "trophees", "parking"]:
		var n := LocalClub.niveau(etat, id)
		if n == 0:
			_terrain(id)
		else:
			_salle(id, n)


func _nuage(c: Vector2) -> void:
	for d in [Vector2(0, 0), Vector2(34, -12), Vector2(64, 4), Vector2(30, 10)]:
		draw_circle(_p(c.x + d.x, c.y + d.y), 26 * _k, Color(1, 1, 1, 0.85))


func _haut(n: int) -> float:
	return 300.0 if n == 1 else 400.0


func _terrain(id: String) -> void:
	var x: float = PLAN[id][0]
	var w: float = PLAN[id][1]
	var r := _r(x + 6, SOL - 220, w - 12, 220)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	draw_dashed_line(pts[0], pts[1], Color(1, 1, 1, 0.8), 3.0 * _k, 12.0 * _k)
	draw_dashed_line(pts[1], pts[2], Color(1, 1, 1, 0.8), 3.0 * _k, 12.0 * _k)
	draw_dashed_line(pts[3], pts[0], Color(1, 1, 1, 0.8), 3.0 * _k, 12.0 * _k)
	# panneau « à construire »
	var pied := _p(x + w / 2.0, SOL)
	draw_line(pied, pied + Vector2(0, -90) * _k, Color("#7a4a22"), 6 * _k)
	var pan := Rect2(pied + Vector2(-80, -150) * _k, Vector2(160, 64) * _k)
	draw_rect(pan, Color("#ffd23f"))
	draw_rect(pan, Ui.CONTOUR, false, 3 * _k)
	_texte(tr(LocalClub.salle(id)["nom"]), pan.get_center() + Vector2(0, -8) * _k, 15, Ui.CONTOUR, 150)
	_texte(tr("À construire"), pan.get_center() + Vector2(0, 16) * _k, 14, Ui.CONTOUR, 150)


func _salle(id: String, n: int) -> void:
	var x: float = PLAN[id][0]
	var w: float = PLAN[id][1]
	var h := _haut(n)
	var y := SOL - h
	var murs := {"principale": Color("#f4b26b"), "chants": Color("#9b7bea"), "trophees": Color("#5d8bf0"), "parking": Color("#9aa3b5")}
	var mur: Color = murs[id]
	draw_rect(_r(x, y, w, h), mur.darkened(0.25))  # façade
	draw_rect(_r(x + 14, y + 40, w - 28, h - 40), mur)  # intérieur
	draw_rect(_r(x + 14, SOL - 14, w - 28, 14), mur.darkened(0.45))  # plancher
	# toit aux couleurs du club
	draw_rect(_r(x - 6, y - 4, w + 12, 44), c1)
	for i in int(w / 40.0):
		draw_rect(_r(x - 6 + i * 40 + 20, y - 4, 20, 44), c2 if c2 != c1 else c1.lightened(0.3))
	draw_rect(_r(x - 6, y - 4, w + 12, 44), Ui.CONTOUR, false, 3 * _k)
	if n == 2:
		draw_rect(_r(x + 14, y + 150, w - 28, 8), mur.darkened(0.35))  # mezzanine
	match id:
		"principale":
			_principale(x, y, w)
		"chants":
			_chants(x, y, w, n)
		"trophees":
			_trophees(x, y, w, n)
		"parking":
			_parking(x, y, w, n)


func _a(id: String) -> bool:
	return LocalClub.a(etat, id)


func _principale(x: float, y: float, w: float) -> void:
	# enseigne
	var ens := _r(x + 40, y - 60, w - 80, 46)
	draw_rect(ens, Ui.NUIT)
	draw_rect(ens, Ui.JAUNE, false, 3 * _k)
	_texte(nom_club.to_upper() if nom_club != "" else tr("LE LOCAL"), ens.get_center(), 22, Ui.JAUNE, w - 100)
	# porte et fenêtre
	draw_rect(_r(x + 24, SOL - 130, 60, 116), Color("#7a4a22"))
	draw_circle(_p(x + 74, SOL - 70), 4 * _k, Ui.JAUNE)
	draw_rect(_r(x + 110, y + 70, 90, 70), Color("#cdeeff"))
	draw_rect(_r(x + 110, y + 70, 90, 70), Ui.CONTOUR, false, 3 * _k)
	if _a("guirlande"):
		var pts := PackedVector2Array()
		for i in 13:
			var u := float(i) / 12.0
			pts.append(_p(x + 20 + u * (w - 40), y + 52 + sin(u * PI) * 22))
		draw_polyline(pts, Ui.CONTOUR, 2 * _k)
		for i in 12:
			var q := pts[i].lerp(pts[i + 1], 0.5)
			draw_colored_polygon(PackedVector2Array([q, q + Vector2(-9, 0) * _k, q + Vector2(0, 16) * _k]), c1 if i % 2 == 0 else c2)
	if _a("poster"):
		var r := _r(x + 230, y + 66, 64, 86)
		draw_rect(r, c1)
		draw_rect(_r(x + 240, y + 76, 44, 44), c2)
		draw_rect(r, Ui.CONTOUR, false, 3 * _k)
	if _a("ecran"):
		var r := _r(x + 120, y + 150, 150, 76)
		draw_rect(r.grow(5 * _k), Ui.CONTOUR)
		draw_rect(r, Color("#2fa64a"))
		draw_line(_p(x + 195, y + 150), _p(x + 195, y + 226), Color(1, 1, 1, 0.7), 2 * _k)
		var balle := _p(x + 140 + 110 * (0.5 + 0.5 * sin(_t * 1.3)), y + 188 + 20 * sin(_t * 2.1))
		draw_circle(balle, 5 * _k, Ui.BLANC)
	if _a("canape"):
		draw_rect(_r(x + 120, SOL - 56, 170, 40), c1.darkened(0.15))
		draw_rect(_r(x + 112, SOL - 76, 186, 26), c1)
		draw_rect(_r(x + 104, SOL - 64, 22, 50), c1.darkened(0.3))
		draw_rect(_r(x + 284, SOL - 64, 22, 50), c1.darkened(0.3))
		draw_rect(_r(x + 150, SOL - 72, 36, 20), c2)
	if _a("babyfoot"):
		var bx := x + 312.0
		draw_rect(_r(bx, SOL - 64, 52, 34), Color("#2fa64a"))
		draw_rect(_r(bx, SOL - 64, 52, 34), Ui.CONTOUR, false, 3 * _k)
		draw_rect(_r(bx + 4, SOL - 30, 6, 30), Color("#7a4a22"))
		draw_rect(_r(bx + 42, SOL - 30, 6, 30), Color("#7a4a22"))
		for i in 3:
			draw_line(_p(bx - 8, SOL - 58 + i * 11), _p(bx + 60, SOL - 58 + i * 11), Color("#cccccc"), 2 * _k)


func _chants(x: float, y: float, w: float, n: int) -> void:
	# notes de musique qui flottent
	for i in 3:
		var ph := fmod(_t * 0.4 + i * 0.33, 1.0)
		var q := _p(x + 40 + i * 80, y + 250 - ph * 160)
		var col := Color(1, 1, 1, 1.0 - ph)
		draw_circle(q, 7 * _k, col)
		draw_line(q + Vector2(6, 0) * _k, q + Vector2(6, -24) * _k, col, 3 * _k)
	if n == 2:
		# petite scène et projecteurs sur la mezzanine
		draw_rect(_r(x + 30, y + 120, w - 60, 30), Color("#3a2a7a"))
		for i in 3:
			var s := _p(x + 60 + i * 80, y + 52)
			draw_circle(s, 10 * _k, Ui.JAUNE)
			draw_colored_polygon(PackedVector2Array([s, s + Vector2(-26, 70) * _k, s + Vector2(26, 70) * _k]), Color(1, 0.95, 0.5, 0.25))
	if _a("partitions"):
		for i in 2:
			var r := _r(x + 40 + i * 70, SOL - 270 if n == 1 else y + 180, 50, 64)
			draw_rect(r, Ui.BLANC)
			for l in 4:
				draw_line(r.position + Vector2(6, 12 + l * 12) * _k, r.position + Vector2(44, 12 + l * 12) * _k, Ui.CONTOUR, 1.5 * _k)
			draw_rect(r, Color("#7a4a22"), false, 4 * _k)
	if _a("piano"):
		var px := x + 30.0
		draw_rect(_r(px, SOL - 110, 130, 80), Ui.CONTOUR)
		draw_rect(_r(px + 6, SOL - 74, 118, 18), Ui.BLANC)
		for i in 8:
			draw_rect(_r(px + 12 + i * 14, SOL - 74, 7, 10), Ui.CONTOUR)
		draw_rect(_r(px + 8, SOL - 30, 10, 30), Ui.CONTOUR)
		draw_rect(_r(px + 112, SOL - 30, 10, 30), Ui.CONTOUR)
	if _a("micros"):
		var mx := x + w - 70.0
		draw_line(_p(mx, SOL - 14), _p(mx, SOL - 120), Color("#444444"), 4 * _k)
		draw_circle(_p(mx, SOL - 126), 9 * _k, Color("#555555"))
		draw_rect(_r(mx + 16, SOL - 96, 36, 82), Color("#2a2550"))
		draw_circle(_p(mx + 34, SOL - 72), 11 * _k, Color("#555555"))
		draw_circle(_p(mx + 34, SOL - 36), 13 * _k + sin(_t * 8.0) * 1.5 * _k, Color("#555555"))


func _trophees(x: float, y: float, w: float, n: int) -> void:
	# étagère avec les vrais chiffres de la collection
	var ey := SOL - 250.0 if n == 1 else y + 90.0
	draw_rect(_r(x + 26, ey + 60, w - 52, 8), Color("#7a4a22"))
	var nt := int(chiffres["tampons"])
	_texte(tr("%d tampons") % nt if nt != 1 else tr("1 tampon"), _p(x + w / 2.0, ey + 20), 17, Ui.BLANC, w - 40)
	_texte(tr("%d souvenirs · %d succès") % [int(chiffres["souvenirs"]), int(chiffres["succes"])], _p(x + w / 2.0, ey + 44), 14, Ui.BLANC, w - 40)
	if _a("mur_tampons"):
		var nb := mini(int(chiffres["tampons"]), 18 if n == 2 else 10)
		var cols := [Ui.ROSE, Ui.BLEU, Ui.VERT, Ui.VIOLET, Color("#ff8a2b")]
		for i in nb:
			var q := _p(x + 46 + (i % 6) * 38, (SOL - 170 if n == 1 else y + 200) + (i / 6) * 38)
			draw_arc(q, 14 * _k, 0, TAU, 20, cols[i % cols.size()], 3 * _k)
	if _a("vitrine"):
		var r := _r(x + w - 120, SOL - 120, 96, 106)
		draw_rect(r, Color(0.8, 0.95, 1.0, 0.45))
		draw_rect(r, Color("#d7d7d7"), false, 4 * _k)
		draw_rect(_r(x + w - 120, SOL - 68, 96, 4), Color("#d7d7d7"))
		draw_colored_polygon(PackedVector2Array([_p(x + w - 104, SOL - 112), _p(x + w - 70, SOL - 98), _p(x + w - 104, SOL - 84)]), c1)
		draw_circle(_p(x + w - 60, SOL - 38), 13 * _k, Ui.BLANC)
		draw_rect(_r(x + w - 120, SOL - 124, 96, 6), Color(1, 1, 0.7, 0.8 + 0.2 * sin(_t * 3.0)))
	if _a("coupe"):
		var c := _p(x + 70, SOL - 64)
		draw_rect(Rect2(c + Vector2(-26, 30) * _k, Vector2(52, 14) * _k), Color("#7a4a22"))
		draw_rect(Rect2(c + Vector2(-6, 6) * _k, Vector2(12, 26) * _k), Color("#d9a520"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-30, -40) * _k, c + Vector2(30, -40) * _k, c + Vector2(14, 8) * _k, c + Vector2(-14, 8) * _k]), Color("#ffcf33"))
		draw_arc(c + Vector2(-30, -24) * _k, 12 * _k, PI / 2, PI * 1.5, 12, Color("#ffcf33"), 4 * _k)
		draw_arc(c + Vector2(30, -24) * _k, 12 * _k, -PI / 2, PI / 2, 12, Color("#ffcf33"), 4 * _k)
		var brille := 0.5 + 0.5 * sin(_t * 2.0)
		draw_circle(c + Vector2(-12, -28) * _k, 4 * _k, Color(1, 1, 1, brille))


func _parking(x: float, y: float, w: float, n: int) -> void:
	# porte de garage relevée
	draw_rect(_r(x + 14, y + 40, w - 28, 26), mur_garage())
	for i in 3:
		draw_line(_p(x + 14, y + 46 + i * 8), _p(x + w - 14, y + 46 + i * 8), Color(0, 0, 0, 0.2), 2 * _k)
	var car_c := c1 if _a("car_club") else Color("#e8e8e8")
	var car_c2 := c2 if _a("car_club") else Color("#9aa3b5")
	var cx := x + 16.0
	var cy := SOL - 120.0
	draw_rect(_r(cx, cy, w - 40, 92), car_c)
	draw_rect(_r(cx, cy + 56, w - 40, 14), car_c2)
	for i in 3:
		draw_rect(_r(cx + 12 + i * 46, cy + 12, 34, 30), Color("#cdeeff"))
	draw_rect(_r(cx, cy, w - 40, 92), Ui.CONTOUR, false, 3 * _k)
	for wx in [cx + 32, cx + w - 72]:
		draw_circle(_p(wx, SOL - 22), 17 * _k, Ui.CONTOUR)
		draw_circle(_p(wx, SOL - 22), 7 * _k, Color("#bbbbbb"))
	if _a("fanions_car"):
		draw_line(_p(cx + 10, cy), _p(cx + 10, cy - 40), Ui.CONTOUR, 2 * _k)
		draw_line(_p(cx + w - 50, cy), _p(cx + w - 50, cy - 40), Ui.CONTOUR, 2 * _k)
		for i in 6:
			var a := _p(cx + 10 + i * (w - 60) / 6.0, cy - 40 + sin(i * 0.9) * 3)
			draw_colored_polygon(PackedVector2Array([a, a + Vector2((w - 60) / 6.0, 0) * _k, a + Vector2((w - 60) / 12.0, 18) * _k]), c1 if i % 2 == 0 else c2)
	if n == 2:
		# lampadaire et place réservée
		draw_rect(_r(x + 20, SOL - 4, w - 40, 4), Ui.JAUNE)
		draw_line(_p(x + w - 22, y + 160), _p(x + w - 22, y + 230), Color("#444444"), 4 * _k)
		draw_circle(_p(x + w - 22, y + 156), 8 * _k, Color(1, 0.95, 0.6))
	if _a("barbecue"):
		var b := _p(x + w + 6, SOL - 40)
		draw_rect(Rect2(b + Vector2(-2, 0), Vector2(4, 40) * _k), Ui.CONTOUR)
		draw_arc(b, 18 * _k, 0, PI, 12, Ui.CONTOUR, 5 * _k)
		for i in 3:
			var ph := fmod(_t * 0.6 + i * 0.33, 1.0)
			draw_circle(b + Vector2(-8 + i * 8 + sin(ph * 6.0) * 4, -10 - ph * 60) * _k, (6 + ph * 8) * _k, Color(0.9, 0.9, 0.9, 0.6 * (1.0 - ph)))


func mur_garage() -> Color:
	return Color("#c6ccd8")


func _texte(t: String, centre: Vector2, fs: int, col: Color, largeur_max: float) -> void:
	var f := Ui.police_titre()
	var taille := maxi(8, int(fs * _k))
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	var lim := largeur_max * _k
	if w > lim:
		taille = maxi(8, int(taille * lim / w))
		w = f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	draw_string(f, centre + Vector2(-w / 2.0, taille * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, col)
