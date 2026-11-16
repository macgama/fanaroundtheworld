extends Control
## Démo des animations FANZZY : deux tribunes face à face et quatre FANZZY
## en gros plan. La séquence se rejoue en boucle ; les boutons du bas
## permettent de tester chaque action à la main.
##
## Pour enregistrer une vidéo :
##   godot --path . --write-movie demo.avi --fixed-fps 30 --quit-after 1130 \
##       res://scenes/fanzzy/demo_animations.tscn

const IDS_BLEUS: PackedStringArray = ["AN22", "SU16", "MT14", "MT46", "AN57", "SU12", "AN40", "SU15", "AN2"]
const IDS_JAUNES: PackedStringArray = ["MT6", "MT47", "RP8", "AN1", "GD17", "VP13", "AN19", "GD8", "MT33"]
const GROS_PLANS: PackedStringArray = ["AN2", "AN57", "GD17", "MT33"]

## [secondes, légende, action bleus, action jaunes]. "ola" et "but" sont spéciaux.
const SEQUENCE := [
	[3.0, "Repos : respiration et petits balancements", &"repos", &"repos"],
	[3.0, "Lever les bras : ils montent, les poings tremblent", &"lever_bras", &"lever_bras"],
	[4.5, "Agiter l'écharpe : tendue entre les poings, bras qui balancent", &"agiter_echarpe", &"agiter_echarpe"],
	[3.5, "Applaudir au-dessus de la tête, sur le tempo", &"applaudir", &"applaudir"],
	[3.5, "Chanter : le bras levé suit le balancement", &"chanter", &"chanter"],
	[3.0, "Encourager : poing levé sur le temps", &"encourager", &"encourager"],
	[4.5, "La ola traverse les deux tribunes", &"ola", &"ola"],
	[4.0, "BUT ! Célébration d'un côté, dépit de l'autre", &"celebrer", &"depit"],
	[3.0, "Les visiteurs huent l'arbitre", &"repos", &"huer"],
	[3.5, "Tout le stade saute", &"sauter", &"sauter"],
]

var _bleus: TribuneFanzzy
var _jaunes: TribuneFanzzy
var _gros_plans: Array[FanzzyAnime] = []
var _legende: Label
var _etape := -1
var _reste := 0.0
var _auto := true


func _ready() -> void:
	_legende = $Legende
	_bleus = _tribune(IDS_BLEUS, [Color("1e6bff"), Color("ffffff")], Vector2(490, 570))
	_jaunes = _tribune(IDS_JAUNES, [Color("ffd23f"), Color("1a1a1a")], Vector2(1430, 570))
	var x := 300.0
	for id in GROS_PLANS:
		var f := FanzzyAnime.creer(id)
		var s := 300.0 / f._rect.size.y
		f.scale = Vector2(s, s)
		f.position = Vector2(x, 1010)
		f.couleurs_echarpe = [Color("1e6bff"), Color("ffffff")] if x < 960 else [Color("ffd23f"), Color("1a1a1a")]
		$GrosPlans.add_child(f)
		_gros_plans.append(f)
		x += 440.0
	for b: Button in $Boutons.get_children():
		b.pressed.connect(_manuel.bind(StringName(b.name)))
	_suivante()


func _tribune(ids: PackedStringArray, couleurs: PackedColorArray, pos: Vector2) -> TribuneFanzzy:
	var t := TribuneFanzzy.new()
	t.fanzzy_ids = ids
	t.couleurs = couleurs
	t.largeur = 820.0
	t.places_par_rangee = 6
	t.rangees = 3
	t.taille_fanzzy = 170.0
	t.hauteur_rangee = 105.0
	t.position = pos
	$Tribunes.add_child(t)
	return t


func _process(delta: float) -> void:
	if not _auto:
		return
	_reste -= delta
	if _reste <= 0.0:
		_suivante()


func _suivante() -> void:
	_etape = (_etape + 1) % SEQUENCE.size()
	var e: Array = SEQUENCE[_etape]
	_reste = e[0]
	_legende.text = e[1]
	_lancer(e[2], e[3], e[0])


func _lancer(bleus: StringName, jaunes: StringName, duree: float) -> void:
	if bleus == &"ola":
		# la vague part de la gauche des bleus et continue chez les jaunes
		_bleus.ola(&"celebrer", 0.9, 1.4)
		get_tree().create_timer(1.4).timeout.connect(_jaunes.ola.bind(&"celebrer", 0.9, 1.4))
		for i in _gros_plans.size():
			_gros_plans[i].jouer(&"celebrer", 0.9, 0.4 + i * 0.6)
		return
	_bleus.jouer_tous(bleus, duree + 0.3, 0.25 if bleus == &"celebrer" else 0.1)
	_jaunes.jouer_tous(jaunes, duree + 0.3, 0.4 if jaunes == &"depit" else 0.1)
	for i in _gros_plans.size():
		_gros_plans[i].jouer(bleus if i < 2 else jaunes, duree + 0.3, 0.05 * i)


func _manuel(action: StringName) -> void:
	_auto = action == &"auto"
	if _auto:
		_etape = -1
		_suivante()
		return
	_legende.text = tr("Action : %s") % action
	if action == &"ola":
		_lancer(&"ola", &"ola", 4.0)
	else:
		_lancer(action, action, 0.0)
