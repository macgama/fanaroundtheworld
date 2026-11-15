class_name CarteMonde
extends Control
## Carte du monde dessinée (style cartoon), avec épingles cliquables.
## Projection de Mercator. Les pays viennent de data/carte/formes.json.
## Glisser pour déplacer, molette pour zoomer, clic sur une épingle ou un pays.

signal epingle_cliquee(epingle: Dictionary)
signal pays_clique(cle: String)
signal mer_cliquee

const K := 10.0           # pixels « monde » par degré de longitude
const LAT_MAX := 82.0

## Épingles : {pos: Vector2(lon, lat), titre, sous_titre, nombre, couleur, direct, type, cle, choisie}
var epingles: Array = []
var interactive := true
## Point de l'écran (dans ce Control) où centrer la vue, et largeur utile en pixels.
var centre_utile := Vector2(-1, -1)
var largeur_utile := -1.0

var position_joueur := Vector2(2.35, 48.86)
var avatar: Texture2D
var route_de := Vector2.INF
var route_vers := Vector2.INF
var route_avance := 0.0

var _monde: Node2D
var _calque: Control
var _zoom := 0.5
var _centre := Vector2.ZERO          # en pixels monde
var _polys: Array = []               # [{cle, pts: PackedVector2Array (monde)}]
var _polygones_noeuds: Dictionary = {}  # cle -> Array[Polygon2D]
var _surbrillance: Array = []
var _attenues := false
var _glisse := false
var _depart_glisse := Vector2.ZERO
var _a_bouge := false
var _survol := -1
var _tween: Tween
var _temps := 0.0


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_monde = Node2D.new()
	add_child(_monde)
	_construire_pays()
	_calque = Control.new()
	_calque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_calque.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_calque)
	_calque.draw.connect(_dessiner_calque)
	resized.connect(_appliquer)
	_appliquer()


func _process(delta: float) -> void:
	_temps += delta
	# les épingles « en direct » pulsent
	_calque.queue_redraw()


# ------------------------------------------------------------------ projection

static func projeter(lonlat: Vector2) -> Vector2:
	var lat := clampf(lonlat.y, -LAT_MAX, LAT_MAX)
	var y := rad_to_deg(log(tan(PI / 4.0 + deg_to_rad(lat) / 2.0)))
	var y_max := rad_to_deg(log(tan(PI / 4.0 + deg_to_rad(LAT_MAX) / 2.0)))
	return Vector2((lonlat.x + 180.0) * K, (y_max - y) * K)


func vers_ecran(lonlat: Vector2) -> Vector2:
	return _monde.position + projeter(lonlat) * _zoom


func _centre_utile() -> Vector2:
	return centre_utile if centre_utile.x >= 0 else size / 2.0


func _largeur_utile() -> float:
	return largeur_utile if largeur_utile > 0 else size.x


# ------------------------------------------------------------------ construction

func _construire_pays() -> void:
	var formes := Geo.formes()
	for cle in formes:
		var noeuds: Array = []
		for pts_ll in formes[cle]:
			var pts := PackedVector2Array()
			for q in pts_ll:
				pts.append(projeter(q))
			var p := Polygon2D.new()
			p.polygon = pts
			p.color = Ui.TERRE
			p.antialiased = false
			_monde.add_child(p)
			noeuds.append(p)
			_polys.append({"cle": cle, "pts": pts})
		_polygones_noeuds[cle] = noeuds
	_monde.draw.connect(_dessiner_frontieres)


func _dessiner_frontieres() -> void:
	# Frontières fines (largeur -1 = 1 pixel écran quel que soit le zoom).
	for p in _polys:
		var pts: PackedVector2Array = p["pts"]
		var ferme := pts.duplicate()
		ferme.append(pts[0])
		_monde.draw_polyline(ferme, Color(0.08, 0.3, 0.12, 0.55), -1.0)


# ------------------------------------------------------------------ vue

func voir(centre_lonlat: Vector2, largeur_deg: float, anime := true) -> void:
	var z := _largeur_utile() / (largeur_deg * K)
	var c := projeter(centre_lonlat)
	if _tween:
		_tween.kill()
	if not anime or not is_inside_tree():
		_zoom = z
		_centre = c
		_appliquer()
		return
	var z0 := _zoom
	var c0 := _centre
	_tween = create_tween()
	_tween.tween_method(func(t: float):
		_zoom = exp(lerpf(log(z0), log(z), t))
		_centre = c0.lerp(c, t)
		_appliquer(), 0.0, 1.0, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)


func _appliquer() -> void:
	if _monde == null:
		return
	_zoom = clampf(_zoom, 0.05, 40.0)
	_monde.scale = Vector2.ONE * _zoom
	_monde.position = _centre_utile() - _centre * _zoom
	_monde.queue_redraw()
	queue_redraw()


func surligner(cles: Array, attenuer_autres := true) -> void:
	_surbrillance = cles
	_attenues = attenuer_autres and not cles.is_empty()
	for cle in _polygones_noeuds:
		var c := Ui.TERRE
		if cle in cles:
			c = Color("#8ff07a")
		elif _attenues:
			c = Color("#5fbf5f")
		for p in _polygones_noeuds[cle]:
			p.color = c
	_calque.queue_redraw()


# ------------------------------------------------------------------ dessin

func _draw() -> void:
	# Océan + petites vagues
	draw_rect(Rect2(Vector2.ZERO, size), Ui.OCEAN)
	var pas := 120.0
	var dec := fposmod(_monde.position.x * 0.3, pas)
	var y := 40.0
	var ligne := 0
	while y < size.y:
		var x := -pas + dec + (pas / 2.0 if ligne % 2 == 1 else 0.0)
		while x < size.x + pas:
			draw_arc(Vector2(x, y), 14, PI * 1.15, PI * 1.85, 8, Color(1, 1, 1, 0.18), 3.0, true)
			x += pas
		y += 70.0
		ligne += 1


func _dessiner_calque() -> void:
	# contour épais des pays mis en avant
	for p in _polys:
		if p["cle"] in _surbrillance:
			var pts := PackedVector2Array()
			for q in p["pts"]:
				pts.append(_monde.position + q * _zoom)
			pts.append(pts[0])
			_calque.draw_polyline(pts, Ui.CONTOUR, 3.0, true)

	# route du voyage (pointillés en arc)
	if route_de != Vector2.INF and route_vers != Vector2.INF:
		var a := vers_ecran(route_de)
		var b := vers_ecran(route_vers)
		var ctrl := (a + b) / 2.0 + Vector2(0, -maxf(60.0, a.distance_to(b) * 0.25))
		var n := 40
		for i in n:
			if i % 2 == 0:
				var t0 := float(i) / n
				var t1 := float(i + 1) / n
				_calque.draw_line(_bezier(a, ctrl, b, t0), _bezier(a, ctrl, b, t1), Ui.CONTOUR, 7.0, true)
				_calque.draw_line(_bezier(a, ctrl, b, t0), _bezier(a, ctrl, b, t1), Ui.JAUNE, 4.0, true)
		_dessiner_avatar(_bezier(a, ctrl, b, route_avance), 34.0)
	else:
		_dessiner_avatar(vers_ecran(position_joueur), 30.0)

	var f := Ui.police_titre()
	for i in epingles.size():
		var e: Dictionary = epingles[i]
		var p := vers_ecran(e["pos"])
		if not Rect2(Vector2(-60, -60), size + Vector2(120, 120)).has_point(p):
			continue
		var grand: bool = e.get("type", "") != "stade"
		var r := 26.0 if grand else 17.0
		if e.get("choisie", false) or i == _survol:
			r *= 1.2
		var coul: Color = e.get("couleur", Ui.ROSE)
		var pointe := p
		var centre := p - Vector2(0, r * 1.5)
		if e.get("direct", false):
			var pulse := 0.5 + 0.5 * sin(_temps * 5.0)
			_calque.draw_circle(centre, r + 6 + pulse * 6, Color(1, 0.2, 0.2, 0.35 * (1.0 - pulse) + 0.1))
		# ombre
		_calque.draw_circle(pointe + Vector2(0, 2), r * 0.35, Color(0, 0, 0, 0.3))
		var tri := PackedVector2Array([centre + Vector2(-r * 0.7, r * 0.5), centre + Vector2(r * 0.7, r * 0.5), pointe])
		_calque.draw_colored_polygon(tri, Ui.CONTOUR)
		_calque.draw_circle(centre, r + 4, Ui.CONTOUR)
		var tri2 := PackedVector2Array([centre + Vector2(-r * 0.55, r * 0.45), centre + Vector2(r * 0.55, r * 0.45), pointe + Vector2(0, -6)])
		_calque.draw_colored_polygon(tri2, coul)
		_calque.draw_circle(centre, r, coul)
		var nb := str(e.get("nombre", ""))
		if nb != "":
			var fs := int(r * 0.95)
			var tw := f.get_string_size(nb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var pos := centre + Vector2(-tw / 2.0, fs * 0.35)
			_calque.draw_string_outline(f, pos, nb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Ui.CONTOUR)
			_calque.draw_string(f, pos, nb, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.BLANC)
		if e.get("direct", false):
			_calque.draw_circle(centre + Vector2(r * 0.75, -r * 0.75), 8, Ui.CONTOUR)
			_calque.draw_circle(centre + Vector2(r * 0.75, -r * 0.75), 6, Ui.ROUGE)
		# étiquette : toujours pour les grandes épingles, au survol pour les stades
		if grand or i == _survol or e.get("choisie", false):
			_etiquette(centre + Vector2(0, -r - 14), str(e.get("titre", "")), str(e.get("sous_titre", "")), e.get("choisie", false))


func _etiquette(bas: Vector2, titre: String, sous: String, active: bool) -> void:
	if titre == "":
		return
	var f := Ui.police_titre()
	var f2 := Ui.police_texte()
	var w1 := f.get_string_size(titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	var w2 := f2.get_string_size(sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x if sous != "" else 0.0
	var w := maxf(w1, w2) + 24
	var h := 34.0 if sous == "" else 54.0
	var r := Rect2(bas - Vector2(w / 2.0, h), Vector2(w, h))
	var s := Ui.boite(Ui.JAUNE if active else Ui.BLANC, 12, 3)
	_calque.draw_style_box(s, r)
	_calque.draw_string(f, r.position + Vector2(12, 26), titre, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Ui.CONTOUR)
	if sous != "":
		_calque.draw_string(f2, r.position + Vector2((w - w2) / 2.0, 46), sous, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#4a4470"))


func _dessiner_avatar(p: Vector2, r: float) -> void:
	_calque.draw_circle(p + Vector2(0, 3), r + 5, Color(0, 0, 0, 0.3))
	_calque.draw_circle(p, r + 5, Ui.CONTOUR)
	_calque.draw_circle(p, r, Ui.JAUNE)
	if avatar:
		var tr := Rect2(p - Vector2(r, r) * 0.95, Vector2(r, r) * 1.9)
		_calque.draw_texture_rect(avatar, tr, false)


static func _bezier(a: Vector2, c: Vector2, b: Vector2, t: float) -> Vector2:
	return a.lerp(c, t).lerp(c.lerp(b, t), t)


# ------------------------------------------------------------------ souris / tactile

func _gui_input(ev: InputEvent) -> void:
	if not interactive:
		return
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_glisse = true
				_a_bouge = false
				_depart_glisse = mb.position
			else:
				_glisse = false
				if not _a_bouge:
					_clic(mb.position)
		elif mb.pressed and mb.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var facteur := 1.15 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
			_zoomer(facteur, mb.position)
		accept_event()
	elif ev is InputEventMouseMotion:
		var mm := ev as InputEventMouseMotion
		if _glisse:
			if mm.position.distance_to(_depart_glisse) > 6:
				_a_bouge = true
			if _a_bouge:
				if _tween:
					_tween.kill()
				_centre -= mm.relative / _zoom
				_appliquer()
		else:
			var s := _epingle_sous(mm.position)
			if s != _survol:
				_survol = s
				mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if s >= 0 else Control.CURSOR_ARROW
	elif ev is InputEventMagnifyGesture:
		_zoomer((ev as InputEventMagnifyGesture).factor, (ev as InputEventMagnifyGesture).position)


func _zoomer(facteur: float, autour: Vector2) -> void:
	if _tween:
		_tween.kill()
	var avant := (autour - _monde.position) / _zoom
	_zoom = clampf(_zoom * facteur, 0.05, 40.0)
	_centre = avant - (autour - _centre_utile()) / _zoom
	_appliquer()


func _epingle_sous(p: Vector2) -> int:
	for i in range(epingles.size() - 1, -1, -1):
		var e: Dictionary = epingles[i]
		var grand: bool = e.get("type", "") != "stade"
		var r := 30.0 if grand else 22.0
		var centre := vers_ecran(e["pos"]) - Vector2(0, r * 1.4)
		if p.distance_to(centre) < r + 6:
			return i
	return -1


func _clic(p: Vector2) -> void:
	var i := _epingle_sous(p)
	if i >= 0:
		epingle_cliquee.emit(epingles[i])
		return
	var m := (p - _monde.position) / _zoom
	for poly in _polys:
		var pts: PackedVector2Array = poly["pts"]
		if Geometry2D.is_point_in_polygon(m, pts):
			pays_clique.emit(poly["cle"])
			return
	mer_cliquee.emit()
