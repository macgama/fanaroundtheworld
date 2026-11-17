class_name Ui
extends RefCounted
## Style « cartoon épais » des maquettes : contours sombres, coins ronds,
## ombre portée sous les boutons. Tous les écrans passent par ces fonctions
## pour garder la même allure.

const BLEU := Color("#1e6bff")
const ROSE := Color("#ff3d7f")
const JAUNE := Color("#ffd23f")
const VERT := Color("#3ddc84")
const VIOLET := Color("#8b5cff")
const ROUGE := Color("#ff4b4b")
const NUIT := Color("#2a2266")        # fond des panneaux
const NUIT_CLAIR := Color("#3a3290")  # cartes dans les panneaux
const CONTOUR := Color("#14112e")     # contour noir bleuté
const BLANC := Color("#ffffff")
const GRIS := Color("#b9b5e0")
const OCEAN := Color("#2f8cff")
const TERRE := Color("#6ee36a")

static var _police_titre: Font
## Taille de texte minimale (réglée par l'autoload Mobile sur téléphone, 0 sur PC).
static var taille_mini := 0
## Vrai sur téléphone (réglé par l'autoload Mobile) : voir `defilement`.
static var petit_ecran := false
static var _police_texte: Font


static func police_titre() -> Font:
	if _police_titre == null:
		_police_titre = load("res://assets/fonts/LilitaOne.woff2")
	return _police_titre


static func police_texte() -> Font:
	if _police_texte == null:
		_police_texte = load("res://assets/fonts/Nunito-ExtraBold.woff2")
	return _police_texte


static func boite(fond: Color, rayon := 22, contour := 5, ombre := 0, couleur_contour := CONTOUR) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.set_corner_radius_all(rayon)
	s.set_border_width_all(contour)
	s.border_color = couleur_contour
	if ombre > 0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, ombre)
		s.expand_margin_bottom = 0
	s.content_margin_left = 16
	s.content_margin_right = 16
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.anti_aliasing = true
	return s


static func creer_theme() -> Theme:
	var t := Theme.new()
	t.default_font = police_texte()
	t.default_font_size = 22
	t.set_color("font_color", "Label", BLANC)  # sans_traduction
	t.set_color("font_outline_color", "Label", CONTOUR)  # sans_traduction
	t.set_constant("outline_size", "Label", 0)  # sans_traduction

	t.set_font("font", "Button", police_titre())  # sans_traduction
	t.set_font_size("font_size", "Button", 26)  # sans_traduction
	t.set_color("font_color", "Button", BLANC)  # sans_traduction
	t.set_color("font_hover_color", "Button", BLANC)  # sans_traduction
	t.set_color("font_pressed_color", "Button", BLANC)  # sans_traduction
	t.set_color("font_focus_color", "Button", BLANC)  # sans_traduction
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.45))  # sans_traduction
	t.set_color("font_outline_color", "Button", CONTOUR)  # sans_traduction
	t.set_constant("outline_size", "Button", 6)  # sans_traduction
	t.set_stylebox("normal", "Button", boite(BLEU, 18, 5, 6))  # sans_traduction
	t.set_stylebox("hover", "Button", boite(BLEU.lightened(0.15), 18, 5, 6))  # sans_traduction
	t.set_stylebox("pressed", "Button", boite(BLEU.darkened(0.15), 18, 5, 2))  # sans_traduction
	t.set_stylebox("disabled", "Button", boite(Color("#55507f"), 18, 5, 4))  # sans_traduction
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())  # sans_traduction

	t.set_stylebox("panel", "PanelContainer", boite(NUIT, 28, 6, 8))  # sans_traduction
	t.set_stylebox("panel", "Panel", boite(NUIT, 28, 6, 8))  # sans_traduction

	var fond_scroll := StyleBoxFlat.new()
	fond_scroll.bg_color = Color(1, 1, 1, 0.25)
	fond_scroll.set_corner_radius_all(6)
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(1, 1, 1, 0.7)
	grab.set_corner_radius_all(6)
	t.set_stylebox("scroll", "VScrollBar", fond_scroll)  # sans_traduction
	t.set_stylebox("grabber", "VScrollBar", grab)  # sans_traduction
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)  # sans_traduction
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)  # sans_traduction

	t.set_stylebox("panel", "TooltipPanel", boite(NUIT, 12, 3))  # sans_traduction
	t.set_color("font_color", "TooltipLabel", BLANC)  # sans_traduction
	return t


static func label(texte: String, taille := 22, couleur := BLANC, titre := false, contour := 0) -> Label:
	var l := Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", maxi(taille, taille_mini))
	l.add_theme_color_override("font_color", couleur)
	if titre:
		l.add_theme_font_override("font", police_titre())
	if contour > 0:
		l.add_theme_constant_override("outline_size", contour)
		l.add_theme_color_override("font_outline_color", CONTOUR)
	return l


static func bouton(texte: String, couleur := BLEU, taille := 26) -> Button:
	var b := Button.new()
	b.text = texte
	b.add_theme_font_size_override("font_size", maxi(taille, taille_mini))
	colorer_bouton(b, couleur)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func colorer_bouton(b: Button, couleur: Color, texte_sombre := false) -> void:
	b.add_theme_stylebox_override("normal", boite(couleur, 18, 5, 6))
	b.add_theme_stylebox_override("hover", boite(couleur.lightened(0.15), 18, 5, 6))
	b.add_theme_stylebox_override("pressed", boite(couleur.darkened(0.15), 18, 5, 2))
	if texte_sombre:
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, CONTOUR)
		b.add_theme_constant_override("outline_size", 0)


static func panneau(couleur := NUIT, rayon := 28, contour := 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", boite(couleur, rayon, contour, 8))
	return p


static func pastille(texte: String, couleur: Color, taille := 18, texte_sombre := false) -> PanelContainer:
	## Petite étiquette arrondie (« EN DIRECT », « Derby »…).
	var p := PanelContainer.new()
	var s := boite(couleur, 12, 3)
	s.content_margin_left = 10
	s.content_margin_right = 10
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", s)
	var l := label(texte, taille, CONTOUR if texte_sombre else BLANC, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p.add_child(l)
	return p


static func ecusson(sigle: String, couleur: Color, couleur2: Color, taille := 56) -> Control:
	## Écusson fictif dessiné (aucun logo officiel) : un blason aux couleurs du club.
	var e := Ecusson.new()
	e.sigle = sigle
	e.c1 = couleur
	e.c2 = couleur2
	e.custom_minimum_size = Vector2(taille, taille * 1.1)
	return e


## Sur téléphone, met `enfant` dans une liste qui défile de haut en bas (pour
## les panneaux trop hauts pour l'écran) ; sur PC, rend `enfant` tel quel.
static func defilement(enfant: Control) -> Control:
	if not petit_ecran:
		return enfant
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	enfant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enfant.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.add_child(enfant)
	return sc


static func marge(enfant: Control, g := 0, h := 0, d := 0, b := 0) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", g)
	m.add_theme_constant_override("margin_top", h)
	m.add_theme_constant_override("margin_right", d)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(enfant)
	return m


static func vbox(sep := 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func hbox(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func espace() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func pop(n: CanvasItem, echelle := 1.15, duree := 0.18) -> void:
	## Petit rebond « cartoon » sur un élément.
	if not is_instance_valid(n):
		return
	var t := n.create_tween()
	t.tween_property(n, "scale", Vector2.ONE * echelle, duree * 0.4).set_trans(Tween.TRANS_BACK)
	t.tween_property(n, "scale", Vector2.ONE, duree * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


class Ecusson extends Control:
	var sigle := "FC"  # sans_traduction
	var c1 := Ui.BLEU
	var c2 := Ui.BLANC

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var pts := PackedVector2Array([
			Vector2(w * 0.08, h * 0.06), Vector2(w * 0.92, h * 0.06), Vector2(w * 0.92, h * 0.52),
			Vector2(w * 0.78, h * 0.78), Vector2(w * 0.5, h * 0.96), Vector2(w * 0.22, h * 0.78),
			Vector2(w * 0.08, h * 0.52),
		])
		draw_colored_polygon(pts, c1)
		# bande diagonale de la 2e couleur
		var bande := PackedVector2Array([
			Vector2(w * 0.08, h * 0.62), Vector2(w * 0.92, h * 0.30), Vector2(w * 0.92, h * 0.46), Vector2(w * 0.12, h * 0.76),
		])
		draw_colored_polygon(Geometry2D.intersect_polygons(bande, pts)[0] if not Geometry2D.intersect_polygons(bande, pts).is_empty() else bande, c2)
		var contour := pts.duplicate()
		contour.append(pts[0])
		draw_polyline(contour, Ui.CONTOUR, maxf(3.0, w * 0.07), true)
		var f := Ui.police_titre()
		var fs := int(h * 0.34)
		var tw := f.get_string_size(sigle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2((w - tw) / 2.0, h * 0.5 + fs * 0.3)
		draw_string_outline(f, pos, sigle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(fs * 0.3), Ui.CONTOUR)
		draw_string(f, pos, sigle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.BLANC)


static func icone(type: String, taille := 32) -> Control:
	var i := Icone.new()
	i.type = type
	i.custom_minimum_size = Vector2(taille, taille)
	i.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	i.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return i


## Petites icônes dessinées (pas d'emoji : toutes les machines n'ont pas la police).
class Icone extends Control:
	var type := "jeton"

	func _draw() -> void:
		var s := minf(size.x, size.y)
		var c := size / 2.0
		var lw := maxf(2.0, s * 0.09)
		match type:
			"jeton":
				draw_circle(c, s * 0.48, Ui.CONTOUR)
				draw_circle(c, s * 0.40, Ui.JAUNE)
				draw_circle(c, s * 0.27, Color("#f0b400"))
				_texte("J", c, s * 0.42, Ui.CONTOUR)
			"stade":
				var r := Rect2(c - Vector2(s * 0.46, s * 0.3), Vector2(s * 0.92, s * 0.6))
				draw_style_box(_ovale(Ui.CONTOUR), r)
				draw_style_box(_ovale(Ui.ROSE), r.grow(-lw))
				draw_style_box(_ovale(Ui.VERT), r.grow(-s * 0.15))
			"monde":
				draw_circle(c, s * 0.48, Ui.CONTOUR)
				draw_circle(c, s * 0.40, Ui.OCEAN)
				draw_circle(c + Vector2(-s * 0.12, -s * 0.08), s * 0.16, Ui.TERRE)
				draw_circle(c + Vector2(s * 0.14, s * 0.14), s * 0.12, Ui.TERRE)
			"calendrier":
				var r2 := Rect2(c - Vector2(s * 0.42, s * 0.4), Vector2(s * 0.84, s * 0.82))
				draw_rect(r2, Ui.CONTOUR)
				draw_rect(r2.grow(-lw), Ui.BLANC)
				draw_rect(Rect2(r2.position, Vector2(r2.size.x, s * 0.26)), Ui.ROUGE)
				_texte("17", c + Vector2(0, s * 0.1), s * 0.38, Ui.CONTOUR)
			"feu":
				var pts := PackedVector2Array([c + Vector2(0, -s * 0.48), c + Vector2(s * 0.34, s * 0.05), c + Vector2(s * 0.3, s * 0.32),
					c + Vector2(0, s * 0.46), c + Vector2(-s * 0.3, s * 0.32), c + Vector2(-s * 0.34, s * 0.05)])
				draw_colored_polygon(pts, Color("#ff8a2b"))
				draw_circle(c + Vector2(0, s * 0.2), s * 0.18, Ui.JAUNE)
			"tampon":
				draw_circle(c, s * 0.48, Ui.CONTOUR)
				draw_circle(c, s * 0.40, Ui.ROSE)
				draw_arc(c, s * 0.28, 0, TAU, 24, Ui.BLANC, lw, true)
			"pin":
				draw_circle(c - Vector2(0, s * 0.1), s * 0.34, Ui.CONTOUR)
				draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.3, 0), c + Vector2(s * 0.3, 0), c + Vector2(0, s * 0.48)]), Ui.CONTOUR)
				draw_circle(c - Vector2(0, s * 0.1), s * 0.25, Ui.ROSE)
				draw_circle(c - Vector2(0, s * 0.1), s * 0.1, Ui.BLANC)
			"cible":
				draw_circle(c, s * 0.48, Ui.CONTOUR)
				draw_circle(c, s * 0.40, Ui.BLANC)
				draw_circle(c, s * 0.29, Ui.ROSE)
				draw_circle(c, s * 0.18, Ui.BLANC)
				draw_circle(c, s * 0.08, Ui.ROSE)
			"direct":
				draw_circle(c, s * 0.3, Ui.CONTOUR)
				draw_circle(c, s * 0.22, Ui.ROUGE)
			"car":
				var r3 := Rect2(c - Vector2(s * 0.46, s * 0.3), Vector2(s * 0.92, s * 0.5))
				draw_style_box(Ui.boite(Ui.ROSE, int(s * 0.12), int(maxf(2.0, lw * 0.8))), r3)
				for k in 3:
					draw_rect(Rect2(r3.position + Vector2(s * (0.08 + 0.27 * k), s * 0.08), Vector2(s * 0.2, s * 0.16)), Ui.BLANC)
				draw_circle(c + Vector2(-s * 0.24, s * 0.22), s * 0.12, Ui.CONTOUR)
				draw_circle(c + Vector2(s * 0.24, s * 0.22), s * 0.12, Ui.CONTOUR)
			"train":
				var r4 := Rect2(c - Vector2(s * 0.3, s * 0.44), Vector2(s * 0.6, s * 0.72))
				draw_style_box(Ui.boite(Ui.BLEU, int(s * 0.16), int(maxf(2.0, lw * 0.8))), r4)
				draw_rect(Rect2(r4.position + Vector2(s * 0.1, s * 0.1), Vector2(s * 0.4, s * 0.22)), Ui.BLANC)
				draw_circle(c + Vector2(-s * 0.15, s * 0.12), s * 0.06, Ui.JAUNE)
				draw_circle(c + Vector2(s * 0.15, s * 0.12), s * 0.06, Ui.JAUNE)
				draw_line(c + Vector2(-s * 0.2, s * 0.3), c + Vector2(-s * 0.34, s * 0.48), Ui.CONTOUR, lw)
				draw_line(c + Vector2(s * 0.2, s * 0.3), c + Vector2(s * 0.34, s * 0.48), Ui.CONTOUR, lw)
			"avion":
				var corps := PackedVector2Array([c + Vector2(-s * 0.46, s * 0.04), c + Vector2(s * 0.36, -s * 0.06), c + Vector2(s * 0.48, 0),
					c + Vector2(s * 0.36, s * 0.06), c + Vector2(-s * 0.46, s * 0.12)])
				var ailes := PackedVector2Array([c + Vector2(-s * 0.05, 0), c + Vector2(s * 0.12, 0), c + Vector2(-s * 0.12, s * 0.42), c + Vector2(-s * 0.24, s * 0.42)])
				var ailes2 := PackedVector2Array([c + Vector2(-s * 0.05, 0), c + Vector2(s * 0.12, 0), c + Vector2(-s * 0.12, -s * 0.38), c + Vector2(-s * 0.24, -s * 0.38)])
				draw_colored_polygon(ailes, Ui.CONTOUR)
				draw_colored_polygon(ailes2, Ui.CONTOUR)
				draw_colored_polygon(corps, Ui.BLANC)
				draw_polyline(corps + PackedVector2Array([corps[0]]), Ui.CONTOUR, lw * 0.7, true)

	func _ovale(col: Color) -> StyleBoxFlat:
		var b := StyleBoxFlat.new()
		b.bg_color = col
		b.set_corner_radius_all(int(size.y))
		return b

	func _texte(t: String, centre: Vector2, fs: float, col: Color) -> void:
		var f := Ui.police_titre()
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x
		draw_string(f, centre + Vector2(-w / 2.0, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs), col)


## Couleur adverse assez différente de la tienne pour qu'on s'y retrouve
## (deux bleus proches deviennent bleu contre rose).
static func couleur_distincte(nous: Color, eux: Color) -> Color:
	var d := Vector3(nous.r - eux.r, nous.g - eux.g, nous.b - eux.b).length()
	var dh := absf(nous.h - eux.h)
	dh = minf(dh, 1.0 - dh)
	var meme_teinte := dh < 0.12 and nous.s > 0.3 and eux.s > 0.3
	if d >= 0.45 and not meme_teinte:
		return eux
	for c in [Ui.ROSE, Ui.JAUNE, Ui.VERT]:
		var h := absf(nous.h - c.h)
		if Vector3(nous.r - c.r, nous.g - c.g, nous.b - c.b).length() >= 0.45 and minf(h, 1.0 - h) >= 0.12:
			return c
	return Ui.ROUGE
