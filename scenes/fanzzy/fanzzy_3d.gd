class_name Fanzzy3D
extends Node2D
## Un FANZZY en 3D (modèle .glb fait dans Blender, voir docs/fanzzy-3d.md),
## affiché dans une scène 2D comme FanzzyAnime : même interface (creer, jouer,
## action, cap, vitesse_course, _rect), origine du nœud entre les pieds.
##
## Le modèle est rendu dans un SubViewport à fond transparent, caméra en
## légère plongée (vue 3/4 des modes Arène et Poussée). Il se tourne vraiment
## vers sa direction de course (orienter), au lieu de seulement se pencher.
##
## Utilisation :
##     var f := Fanzzy3D.creer_corps(&"AN1")   # Fanzzy3D si le .glb existe, sinon FanzzyAnime
##     add_child(f)
##     f.jouer(&"courir")

signal action_terminee(action: StringName)

const DOSSIER := "res://assets/fanzzy/3d"
## Actions de FanzzyAnime → animation du modèle (nom, boucle).
const ANIMS := {
	&"repos": [&"attente", true],
	&"marcher": [&"course", true],
	&"courir": [&"course", true],
	&"lancer": [&"lancer", false],
	&"celebrer": [&"victoire", true],
	&"sauter": [&"victoire", true],
	&"lever_bras": [&"victoire", true],
	&"applaudir": [&"victoire", true],
	&"danser": [&"victoire", true],
	&"chanter": [&"lancer", false],
	&"encourager": [&"lancer", false],
	&"agiter_echarpe": [&"victoire", true],
	&"depit": [&"depit", false],
	&"huer": [&"depit", false],
}
const TAILLE_VUE := Vector2i(300, 400)
const HAUTEUR_VUE := 2.6 # mètres couverts par la hauteur de la vue
const HAUTEUR_MODELE := 1.75 # mètres (taille d'un FANZZY dans Blender)
const PLONGEE := 25.0 # degrés
const TRANSITION := 0.15

var fanzzy_id := ""
var action: StringName = &"repos"
## -1 = regarde vers la gauche de l'écran, 1 = vers la droite (si pas d'orienter).
var cap := 1.0:
	set(v):
		cap = v
		if not _dir_libre:
			_cap_cible = deg_to_rad(90.0 if v >= 0.0 else -90.0) * 0.55
var vitesse_course := 1.0
var couleurs_echarpe: PackedColorArray = [] # compatibilité FanzzyAnime (l'écharpe est dans la texture)
var _rect := Rect2() # en pixels de la vue, origine aux pieds (comme FanzzyAnime)

var _vue: SubViewport
var _modele: Node3D
var _anim: AnimationPlayer
var _sprite: Sprite2D
var _cap_cible := 0.0
var _dir_libre := false
var _minuteur := 0.0


static func chemin_modele(id: String) -> String:
	return "%s/%s.glb" % [DOSSIER, id]


static func existe(id: String) -> bool:
	return ResourceLoader.exists(chemin_modele(id))


## Le corps à poser dans une scène : 3D si le modèle existe, sinon l'image animée.
static func creer_corps(id: String) -> Node2D:
	if existe(id):
		return creer(id)
	return FanzzyAnime.creer(id)


static func creer(id: String) -> Fanzzy3D:
	var f := Fanzzy3D.new()
	f.name = id
	f.fanzzy_id = id
	f._construire()
	return f


## Pour une interface (salon, fiches) : un TextureRect qui montre le FANZZY
## 3D en attente, face à la caméra. Null si le modèle n'existe pas.
static func vignette(id: String, action_depart := &"repos") -> TextureRect:
	if not existe(id):
		return null
	var f := creer(id)
	f._sprite.visible = false
	f.jouer(action_depart)
	var img := TextureRect.new()
	img.texture = f._vue.get_texture()
	img.add_child(f)
	return img


func _construire() -> void:
	_vue = SubViewport.new()
	_vue.size = TAILLE_VUE
	_vue.transparent_bg = true
	_vue.own_world_3d = true
	_vue.msaa_3d = Viewport.MSAA_4X
	_vue.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vue)

	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.88, 1.0)
	e.ambient_light_energy = 0.75
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	_vue.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 30, 0)
	soleil.light_energy = 1.25
	_vue.add_child(soleil)
	var contre := DirectionalLight3D.new()
	contre.rotation_degrees = Vector3(-30, 200, 0)
	contre.light_energy = 0.45
	_vue.add_child(contre)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = HAUTEUR_VUE
	cam.rotation_degrees = Vector3(-PLONGEE, 0, 0)
	var cible := Vector3(0, 0.95, 0)
	cam.position = cible + Vector3(0, sin(deg_to_rad(PLONGEE)), cos(deg_to_rad(PLONGEE))) * 6.0
	_vue.add_child(cam)

	var scene: PackedScene = load(chemin_modele(fanzzy_id))
	_modele = scene.instantiate()
	_vue.add_child(_modele)
	_anim = _modele.find_child("AnimationPlayer", true, false)
	if _anim:
		for nom in [&"attente", &"course", &"victoire"]:
			if _anim.has_animation(nom):
				_anim.get_animation(nom).loop_mode = Animation.LOOP_LINEAR
		_anim.animation_finished.connect(_sur_fin)

	# pixel des pieds et du sommet de la tête dans la vue → décalage du sprite
	var pieds := _projeter(cam, Vector3.ZERO)
	var tete := _projeter(cam, Vector3(0, HAUTEUR_MODELE, 0))
	_sprite = Sprite2D.new()
	_sprite.texture = _vue.get_texture()
	_sprite.centered = false
	_sprite.offset = -pieds
	add_child(_sprite)
	var h := pieds.y - tete.y
	_rect = Rect2(-h * 0.3, -h, h * 0.6, h)
	jouer(action)


## Projection orthographique faite à la main (la caméra n'est pas encore dans l'arbre).
func _projeter(cam: Camera3D, p: Vector3) -> Vector2:
	var b := cam.transform.basis
	var rel := p - cam.position
	var k := TAILLE_VUE.y / HAUTEUR_VUE
	return Vector2(TAILLE_VUE.x * 0.5 + rel.dot(b.x) * k, TAILLE_VUE.y * 0.5 - rel.dot(b.y) * k)


## Tourne le FANZZY vers une direction de l'écran (x à droite, y vers le bas
## = vers la caméra). Vector2.ZERO : garde l'orientation actuelle.
func orienter(dir: Vector2) -> void:
	if dir.length() < 0.05:
		return
	_dir_libre = true
	_cap_cible = atan2(dir.x, dir.y)


## Joue une action (voir ANIMS). duree > 0 : revient au repos après ce temps.
func jouer(a: StringName, duree := 0.0) -> void:
	action = a
	_minuteur = duree
	if _anim == null:
		return
	var def: Array = ANIMS.get(a, ANIMS[&"repos"])
	var nom: StringName = def[0]
	if not _anim.has_animation(nom):
		return
	var vitesse := vitesse_course * (0.65 if a == &"marcher" else 1.0) if nom == &"course" else 1.0
	_anim.play(nom, TRANSITION, vitesse)
	if _anim.current_animation == nom and not def[1]:
		_anim.seek(0.0, true)


func _sur_fin(nom: StringName) -> void:
	var def: Array = ANIMS.get(action, ANIMS[&"repos"])
	if def[0] == nom and _minuteur <= 0.0 and nom == &"lancer":
		var a := action
		jouer(&"repos")
		action_terminee.emit(a)


func _process(delta: float) -> void:
	if _modele == null:
		return
	_modele.rotation.y = lerp_angle(_modele.rotation.y, _cap_cible, minf(delta * 12.0, 1.0))
	if _anim and action in [&"courir", &"marcher"]:
		_anim.speed_scale = vitesse_course * (0.65 if action == &"marcher" else 1.0)
	elif _anim:
		_anim.speed_scale = 1.0
	if _minuteur > 0.0:
		_minuteur -= delta
		if _minuteur <= 0.0:
			var a := action
			jouer(&"repos")
			action_terminee.emit(a)
