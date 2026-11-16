extends Control
## Démo du « jus » des FANZZY : élastique, bonds, impacts, traînées,
## poussière, étourdissement. La séquence tourne en boucle.
##
## Pour enregistrer une vidéo :
##   godot --path . --write-movie jus.avi --fixed-fps 30 --quit-after 900 \
##       res://scenes/fanzzy/demo_jus.tscn

const IDS: PackedStringArray = ["AN2", "AN57", "GD17", "MT33", "AN22"]
const COULEURS := [Color("1e6bff"), Color("ff3d7f"), Color("ffd23f"), Color("3ddc84"), Color("8b5cff")]

var _f: Array[FanzzyAnime] = []
var _legende: Label
var _t := 0.0
var _etape := -1

## [secondes, légende, fonction]
var _sequence: Array = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var ciel := ColorRect.new()
	ciel.color = Color("142a6b")
	ciel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(ciel)
	var sol := ColorRect.new()
	sol.color = Color("2a8c4a")
	sol.position = Vector2(0, 760)
	sol.size = Vector2(1920, 320)
	add_child(sol)
	_legende = Label.new()
	_legende.position = Vector2(0, 40)
	_legende.size = Vector2(1920, 90)
	_legende.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legende.add_theme_font_size_override("font_size", 52)
	_legende.add_theme_constant_override("outline_size", 16)
	_legende.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.1))
	add_child(_legende)
	for i in IDS.size():
		var f := FanzzyAnime.creer(IDS[i])
		f.position = Vector2(260 + i * 350, 900)
		f.couleurs_echarpe = PackedColorArray([COULEURS[i], Color.WHITE])
		f.couleur_trainee = COULEURS[i]
		f.decalage = i * 0.06
		add_child(f)
		f.scale = Vector2.ONE * 420.0 / maxf(f._rect.size.y, 1.0)
		_f.append(f)
	_sequence = [
		[3.0, "Ils arrivent : bond, élastique, poussière", _arrivee],
		[3.5, "Sur chaque temps : un coup d'élastique", _tempo],
		[3.5, "Touchés ! Éclair, recul et étoiles", _impacts],
		[3.0, "Sonnés : les étoiles tournent", _sonnes],
		[3.5, "Sprint : traînée et poussière", _sprint],
		[4.0, "BUT ! Célébration et confettis", _but],
		[3.0, "Dépit : on s'affaisse", _depit],
	]


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_etape = (_etape + 1) % _sequence.size()
		var e: Array = _sequence[_etape]
		_t = e[0]
		_legende.text = e[1]
		(e[2] as Callable).call()
	if _etape == 1:
		var b := int(Time.get_ticks_msec() / 500)
		if b != get_meta("b", -1):
			set_meta("b", b)
			for f in _f:
				f.pop(0.6)
	if _etape == 4:
		var k := 3.5 - _t
		for i in _f.size():
			var f := _f[i]
			f.position.x = 260 + i * 350 + sin(k * 2.4 + i) * 140.0
			f.cap = signf(cos(k * 2.4 + i))
			f.trainee = 0.05


func _arrivee() -> void:
	for i in _f.size():
		_f[i].jouer(&"lever_bras", 2.0, i * 0.12)
		_f[i].rebondir(1.4, i * 0.12)


func _tempo() -> void:
	for f in _f:
		f.jouer(&"chanter")


func _impacts() -> void:
	for f in _f:
		f.jouer(&"repos")
	for k in 3:
		for i in _f.size():
			var f := _f[i]
			var cote := -1.0 if (i + k) % 2 == 0 else 1.0
			get_tree().create_timer(0.3 + k * 0.9 + i * 0.08).timeout.connect(func() -> void:
				f.impact(f.global_position + Vector2(cote * 200, -150), 1.0, Color.WHITE if k < 2 else Color("ff7b7b")))


func _sonnes() -> void:
	for f in _f:
		f.impact(Vector2.INF, 1.5)
		f.etourdir(2.6)
		f.jouer(&"depit", 2.6)


func _sprint() -> void:
	for f in _f:
		f.vitesse_course = 1.8
		f.jouer(&"courir")


func _but() -> void:
	for i in _f.size():
		var f := _f[i]
		f.position.x = 260 + i * 350
		f.trainee = 0.0
		f.jouer(&"celebrer", 3.8, i * 0.05)


func _depit() -> void:
	for f in _f:
		f.jouer(&"depit", 3.0)
