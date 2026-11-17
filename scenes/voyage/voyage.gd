extends Control
## Voyage vers le stade : le car du fan club traverse la carte,
## puis le stade est tamponné dans la collection (première visite).

var carte: CarteMonde
var _fiche: Dictionary
var _info: Label
var _depart: Vector2
var _arrivee: Vector2


func _ready() -> void:
	var p: Dictionary = Game.params
	var m := Donnees.match_par_id(str(p.get("match_id", "")))
	if m.is_empty():
		Game.aller(Game.SCENE_CARTE)
		return
	_fiche = FicheMatch.de(m)
	_depart = Vector2(float(Game.position_club["lon"]), float(Game.position_club["lat"]))
	_arrivee = Vector2(_fiche["lieu"]["lon"], _fiche["lieu"]["lat"])

	carte = CarteMonde.new()
	carte.set_anchors_preset(Control.PRESET_FULL_RECT)
	carte.interactive = false
	carte.avatar = Game.texture_fanzzy(str(Game.equipe[0]), true)
	add_child(carte)
	carte.route_de = _depart
	carte.route_vers = _arrivee
	var milieu := (_depart + _arrivee) / 2.0
	var dist := Geo.distance_km(_depart, _arrivee)
	var largeur := clampf(absf(_depart.x - _arrivee.x) * 1.8 + 8.0, 10.0, 300.0)
	largeur = maxf(largeur, absf(_depart.y - _arrivee.y) * 2.6)
	carte.voir(milieu, largeur, false)
	if _fiche["lieu"]["pays"] != "":
		carte.surligner([_fiche["lieu"]["pays"]], false)

	var bandeau := Ui.panneau()
	bandeau.set_anchors_preset(Control.PRESET_CENTER_TOP)
	bandeau.offset_left = -520
	bandeau.offset_right = 520
	bandeau.offset_top = 30
	add_child(bandeau)
	var v := Ui.vbox(4)
	bandeau.add_child(v)
	var titre := tr("Arrivés à %s") if p.get("arrive", false) else tr("En route vers %s")
	var t := Ui.label(titre % _fiche["stade"]["nom"], 40, Ui.JAUNE, true, 8)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	_info = Ui.label(tr("%s – %s · %d km") % [_fiche["dom"]["nom"], _fiche["ext"]["nom"], int(dist)], 22, Ui.BLANC)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_info)

	if p.get("arrive", false):
		# Le fan club arrive d'un déplacement organisé : tampon et bilan tout de suite.
		carte.route_avance = 1.0
		_arrive.call_deferred()
		return
	var duree := clampf(1.5 + dist / 1500.0, 1.5, 4.5)
	var tw := create_tween()
	tw.tween_method(func(a: float):
		carte.route_avance = a, 0.0, 1.0, duree).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(_arrive)


func _arrive() -> void:
	Game.position_club = {"nom": _fiche["stade"]["nom"], "lat": _arrivee.y, "lon": _arrivee.x}
	var nouveau := Game.tamponner(_fiche["stade"]["cle"], {
		"nom": _fiche["stade"]["nom"], "club": _fiche["dom"]["nom"],
		"date": Time.get_date_string_from_system(), "match": "%s – %s" % [_fiche["dom"]["nom"], _fiche["ext"]["nom"]],
		"pays": _fiche["lieu"]["pays"], "continent": _fiche["lieu"]["continent"],
		"competition": str(_fiche["m"].get("competition", {}).get("id", "")),
	})
	Game.sauver()
	var voile := ColorRect.new()
	voile.color = Color(0.08, 0.06, 0.2, 0.0)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(voile)
	create_tween().tween_property(voile, "color:a", 0.6, 0.3)

	var tampon := Tampon.new()
	tampon.nom = _fiche["stade"]["nom"]
	tampon.club = _fiche["dom"]["nom"]
	tampon.date = FicheMatch.date_texte(int(Time.get_unix_time_from_system()))
	var encre: Color = _fiche["dom"]["c1"]
	if encre.get_luminance() > 0.7:
		encre = _fiche["dom"]["c2"] if (_fiche["dom"]["c2"] as Color).get_luminance() <= 0.7 else Ui.ROSE
	tampon.couleur = encre
	tampon.size = Vector2(460, 460)
	tampon.pivot_offset = tampon.size / 2.0
	tampon.position = size / 2.0 - tampon.size / 2.0 - Vector2(0, 40)
	tampon.rotation = deg_to_rad(-12)
	tampon.scale = Vector2.ONE * 3.0
	tampon.modulate.a = 0.0
	add_child(tampon)
	var t := create_tween().set_parallel()
	t.tween_property(tampon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN).set_delay(0.2)
	t.tween_property(tampon, "modulate:a", 1.0, 0.2).set_delay(0.2)
	t.chain().tween_callback(func(): _secousse())

	var bas := Ui.vbox(14)
	bas.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bas.offset_top = -230
	bas.offset_bottom = -50
	bas.offset_left = -400
	bas.offset_right = 400
	bas.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(bas)
	var msg := Ui.label("NOUVEAU TAMPON !" if nouveau else "Stade déjà tamponné, content de revenir !", 44 if nouveau else 30, Ui.JAUNE, true, 10)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bas.add_child(msg)
	if nouveau and Game.primes_pretes() > 0:
		var pr := Ui.label("Prime de collection à réclamer sur la carte (compteur de tampons)", 22, Ui.BLANC, true, 6)
		pr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bas.add_child(pr)
	var bilan: Variant = Game.params.get("bilan")
	if bilan is Dictionary:
		bas.offset_top = -330
		bas.add_child(_ligne_bilan(bilan))
	var b := Ui.bouton("ENTRER DANS LE STADE", Ui.VERT, 36)
	Ui.colorer_bouton(b, Ui.VERT, true)
	b.custom_minimum_size = Vector2(560, 96)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func(): Game.aller(Game.SCENE_TRIBUNE, Game.params))
	bas.add_child(b)
	bas.modulate.a = 0.0
	create_tween().tween_property(bas, "modulate:a", 1.0, 0.3).set_delay(0.7)


## Résumé du déplacement : ferveur, arrivée à l'heure, primes, bonus des duels.
func _ligne_bilan(b: Dictionary) -> Control:
	var pan := Ui.panneau(Ui.NUIT, 20, 5)
	var v := Ui.vbox(4)
	pan.add_child(v)
	var t := tr("Ferveur du convoi : %d / 100") % int(b["ferveur"])
	t += tr(" · arrivés à l'heure") if b["a_l_heure"] else tr(" · arrivés pile pour le coup d'envoi (-%d)") % Deplacement.MALUS_RETARD
	var l1 := Ui.label(t, 22, Ui.JAUNE, true, 5)
	l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l1)
	var l2 := Ui.label(tr("Prime du déplacement : +%d Jetons · +%d XP PASS · duels de ce match aujourd'hui ×%s") % [
		int(b["jetons"]), int(b["xp_pass"]), Trad.decimal(b["mult"])], 18, Ui.BLANC)
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l2)
	return pan


func _secousse() -> void:
	var t := create_tween()
	for i in 6:
		t.tween_property(carte, "position", Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.03)
	t.tween_property(carte, "position", Vector2.ZERO, 0.03)


## Le tampon dessiné : double cercle, nom du stade, date.
class Tampon extends Control:
	var nom := ""
	var club := ""
	var date := ""
	var couleur := Ui.ROSE

	func _draw() -> void:
		var c := size / 2.0
		var r := size.x * 0.46
		var encre := couleur.darkened(0.1)
		draw_circle(c, r + 6, Color(1, 1, 1, 0.9))
		draw_arc(c, r, 0, TAU, 96, encre, 14.0, true)
		draw_arc(c, r * 0.72, 0, TAU, 96, encre, 6.0, true)
		var f := Ui.police_titre()
		# nom du stade en arc
		var txt := nom.to_upper()
		var fs := 34 if txt.length() < 22 else 26
		var largeur := 0.0
		for ch in txt:
			largeur += f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var rayon := r * 0.86
		var angle := -PI / 2.0 - (largeur / rayon) / 2.0
		for ch in txt:
			var w := f.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var a := angle + (w / 2.0) / rayon
			draw_set_transform(c + Vector2(cos(a), sin(a)) * rayon, a + PI / 2.0, Vector2.ONE)
			draw_string(f, Vector2(-w / 2.0, fs * 0.35), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, encre)
			angle += w / rayon
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		_centre(f, tr("VISITÉ"), c + Vector2(0, -20), 54, encre)
		_centre(f, date, c + Vector2(0, 40), 30, encre)
		_centre(Ui.police_texte(), club, c + Vector2(0, r * 0.88), 22, encre)

	func _centre(f: Font, t: String, p: Vector2, fs: int, col: Color) -> void:
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, p + Vector2(-w / 2.0, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
