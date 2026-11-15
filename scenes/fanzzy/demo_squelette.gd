extends Control
## Démo du squelette 2D automatique des FANZZY (modes Arène et Poussée).
## Rangée du haut : les repères trouvés sur la silhouette. En bas, les mêmes
## FANZZY qui marchent, courent, lancent, dansent et sautent.
##
## Pour enregistrer une vidéo :
##   godot --path . --resolution 1920x1080 --write-movie demo.avi --fixed-fps 30 \
##       --quit-after 900 res://scenes/fanzzy/demo_squelette.tscn

const IDS: PackedStringArray = ["AN2", "MT14", "AN22", "SU15", "GD17", "MT6", "AN57", "RP8"]
const SEQUENCE := [
	[4.0, "Marcher : jambes en ciseaux, genoux qui se plient, bras opposés", &"marcher"],
	[4.0, "Courir : foulées plus longues, coudes pliés, petits bonds", &"courir"],
	[4.0, "Lancer un ballon de confettis : élan, bras par-dessus l'épaule", &"lancer"],
	[4.0, "Danser sur le tempo", &"danser"],
	[3.5, "Sauter : genoux repliés en l'air", &"sauter"],
	[3.5, "Célébrer (bras levés de l'image + jambes)", &"celebrer"],
]

var _fanzzy: Array[FanzzyAnime] = []
var _legende: Label
var _etape := -1
var _reste := 0.0
var _relance := 0.0


func _ready() -> void:
	var fond := ColorRect.new()
	fond.color = Color("#3fae5b")
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fond)
	var titre := Ui.label("SQUELETTE 2D AUTOMATIQUE DES FANZZY", 44, Ui.JAUNE, true, 10)
	titre.position = Vector2(40, 20)
	add_child(titre)
	_legende = Ui.label("", 32, Ui.BLANC, true, 8)
	_legende.position = Vector2(40, 84)
	add_child(_legende)
	var x := 150.0
	for i in IDS.size():
		var f := FanzzyAnime.creer(IDS[i])
		var s := 420.0 / f._rect.size.y
		f.scale = Vector2(s, s)
		f.position = Vector2(x, 900)
		f.cap = 1.0 if i % 2 == 0 else -1.0
		f.couleurs_echarpe = [Color("1e6bff"), Color("ffffff")]
		add_child(f)
		_fanzzy.append(f)
		x += 232.0
	_suivante()


func _process(delta: float) -> void:
	_reste -= delta
	if _reste <= 0.0:
		_suivante()
	# le lancer se rejoue en boucle
	if SEQUENCE[_etape][2] == &"lancer":
		_relance -= delta
		if _relance <= 0.0:
			_relance = 0.9
			for i in _fanzzy.size():
				_fanzzy[i].jouer(&"lancer", -1.0, i * 0.06)


func _suivante() -> void:
	_etape = (_etape + 1) % SEQUENCE.size()
	var e: Array = SEQUENCE[_etape]
	_reste = e[0]
	_legende.text = e[1]
	_relance = 0.0
	if e[2] != &"lancer":
		for i in _fanzzy.size():
			_fanzzy[i].jouer(e[2], e[0] + 0.3, 0.05 * i)
