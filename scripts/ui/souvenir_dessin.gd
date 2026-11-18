class_name SouvenirDessin
extends Control
## Un souvenir de stade dessiné aux couleurs du club (voir Souvenirs.TYPES).
## `possede` faux : silhouette grise (place vide de la vitrine).

var type := "fanion"
var c1 := Ui.BLEU
var c2 := Ui.BLANC
var possede := true
var sigle := ""


func _init() -> void:
	custom_minimum_size = Vector2(96, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var a := c1 if possede else Color(1, 1, 1, 0.16)
	var b := c2 if possede else Color(1, 1, 1, 0.08)
	var trait_c := Ui.CONTOUR if possede else Color(1, 1, 1, 0.25)
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	match type:
		"fanion":
			draw_line(p.call(0.2, 0.08), p.call(0.2, 0.95), trait_c, s * 0.05)
			var tri := PackedVector2Array([p.call(0.22, 0.12), p.call(0.9, 0.38), p.call(0.22, 0.64)])
			draw_colored_polygon(tri, a)
			draw_colored_polygon(PackedVector2Array([p.call(0.22, 0.3), p.call(0.52, 0.38), p.call(0.22, 0.46)]), b)
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), trait_c, s * 0.035, true)
		"echarpe":
			var bandes := 6
			for i in bandes:
				var x0 := 0.08 + i * 0.84 / bandes
				var x1 := x0 + 0.84 / bandes
				var poly := PackedVector2Array([p.call(x0, 0.36 + 0.06 * sin(i)), p.call(x1, 0.36 + 0.06 * sin(i + 1)),
					p.call(x1, 0.62 + 0.06 * sin(i + 1)), p.call(x0, 0.62 + 0.06 * sin(i))])
				draw_colored_polygon(poly, a if i % 2 == 0 else b)
			for k in 5:
				draw_line(p.call(0.08, 0.4 + k * 0.05), p.call(0.0, 0.42 + k * 0.05), trait_c, s * 0.02)
				draw_line(p.call(0.92, 0.42 + k * 0.05), p.call(1.0, 0.44 + k * 0.05), trait_c, s * 0.02)
			draw_rect(Rect2(p.call(0.08, 0.36), Vector2(0.84, 0.27) * s), trait_c, false, s * 0.03)
		"ballon":
			var c: Vector2 = p.call(0.5, 0.52)
			draw_circle(c, s * 0.38, Color.WHITE if possede else a)
			draw_circle(c, s * 0.12, Ui.CONTOUR if possede else b)
			for k in 5:
				var ang := -PI / 2.0 + k * TAU / 5.0
				draw_circle(c + Vector2.from_angle(ang) * s * 0.3, s * 0.07, a)
			draw_arc(c, s * 0.38, 0, TAU, 48, trait_c, s * 0.035, true)
			# la dédicace
			draw_polyline(PackedVector2Array([c + Vector2(-0.22, 0.12) * s, c + Vector2(-0.1, 0.02) * s,
				c + Vector2(0.0, 0.14) * s, c + Vector2(0.12, 0.04) * s, c + Vector2(0.24, 0.1) * s]), b.darkened(0.3) if possede else b, s * 0.025, true)
		"maillot":
			var m := PackedVector2Array([p.call(0.32, 0.12), p.call(0.42, 0.16), p.call(0.58, 0.16), p.call(0.68, 0.12),
				p.call(0.94, 0.3), p.call(0.84, 0.46), p.call(0.76, 0.4), p.call(0.76, 0.9), p.call(0.24, 0.9),
				p.call(0.24, 0.4), p.call(0.16, 0.46), p.call(0.06, 0.3)])
			draw_colored_polygon(m, a)
			draw_rect(Rect2(p.call(0.44, 0.16), Vector2(0.12, 0.74) * s), b)
			var ferme := m.duplicate()
			ferme.append(m[0])
			draw_polyline(ferme, trait_c, s * 0.035, true)
			if possede and sigle != "":
				var f := Ui.police_titre()
				var fs := int(s * 0.16)
				var w := f.get_string_size(sigle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, p.call(0.5, 0.66) - Vector2(w / 2.0, 0), sigle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Ui.BLANC)
		"maquette":
			draw_rect(Rect2(p.call(0.06, 0.78), Vector2(0.88, 0.1) * s), b)
			var tribune := PackedVector2Array([p.call(0.1, 0.78), p.call(0.18, 0.4), p.call(0.82, 0.4), p.call(0.9, 0.78)])
			draw_colored_polygon(tribune, a)
			draw_colored_polygon(PackedVector2Array([p.call(0.28, 0.78), p.call(0.32, 0.58), p.call(0.68, 0.58), p.call(0.72, 0.78)]),
				Ui.VERT if possede else b)
			for k in 4:
				draw_line(p.call(0.2 + k * 0.2, 0.4), p.call(0.2 + k * 0.2, 0.18), trait_c, s * 0.025)
				draw_circle(p.call(0.2 + k * 0.2, 0.16), s * 0.035, Ui.JAUNE if possede else b)
			var ferme := tribune.duplicate()
			ferme.append(tribune[0])
			draw_polyline(ferme, trait_c, s * 0.035, true)
