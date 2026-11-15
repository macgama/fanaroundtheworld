@tool
class_name FanzzyAnime
extends Node2D
## Un FANZZY animé, prêt à poser dans une tribune ou un duel d'ambiance.
##
## Les FANZZY sont des images entières (pas de calques bras/jambes). Plutôt
## qu'un squelette à découper sur 1 600 personnages, on anime l'image entière
## avec une grille déformée par un shader (fanzzy_deformation.gdshader) :
## les pieds restent fixes, le buste se plie, s'écrase, saute ou ondule.
## On ajoute par-dessus des accessoires dessinés (écharpe, notes, confettis,
## nuage) et on change d'expression (neutre, pousse, joie, depit, colere)
## quand les images d'expression sont disponibles.
##
## Origine du nœud = entre les pieds. Tout est en pixels de l'image d'origine :
## on règle la taille à l'écran avec `scale`.
##
## Utilisation :
##     var f := FanzzyAnime.creer(&"MT14")      # ou instancier fanzzy_anime.tscn
##     add_child(f)
##     f.jouer(&"chanter")                      # boucle
##     f.jouer(&"celebrer", 2.5)                # 2,5 s puis retour au repos

signal action_terminee(action: StringName)

## Actions disponibles, avec l'expression utilisée et la durée par défaut
## (0 = en boucle jusqu'à la prochaine action).
const ACTIONS := {
	&"repos": {"etat": &"neutre", "duree": 0.0},
	&"sauter": {"etat": &"joie", "duree": 0.0},
	&"chanter": {"etat": &"pousse", "duree": 0.0},
	&"agiter_echarpe": {"etat": &"pousse", "duree": 0.0},
	&"applaudir": {"etat": &"joie", "duree": 0.0},
	&"encourager": {"etat": &"pousse", "duree": 0.0},
	&"celebrer": {"etat": &"joie", "duree": 3.0},
	&"depit": {"etat": &"depit", "duree": 3.0},
	&"huer": {"etat": &"colere", "duree": 2.5},
}
const ETATS: Array[StringName] = [&"neutre", &"pousse", &"joie", &"depit", &"colere"]
const DOSSIERS_PAR_DEFAUT: PackedStringArray = ["res://assets/fanzzy/sprites", "res://assets/fanzzy/demo"]
const SHADER := preload("res://scenes/fanzzy/fanzzy_deformation.gdshader")
const TRANSITION := 0.22 # secondes de fondu entre deux actions

## Identifiant de catalogue : si `texture` est vide, les images sont chargées
## au lancement (pratique pour poser un FANZZY dans une scène à la main).
@export var fanzzy_id := ""
@export var evolution := "e1"
@export var skin := "base"
@export var texture: Texture2D:
	set(v):
		texture = v
		_preparer()
## Images d'expression facultatives : clés = ETATS, plus &"cligne" (calque des
## yeux fermés, posé par-dessus l'expression neutre le temps d'un clignement).
@export var expressions: Dictionary = {}
## Action en cours (au lancement : action de départ). Pour en changer, appeler jouer().
@export var action: StringName = &"repos"
## Couleurs de l'écharpe (club). Deux couleurs alternées en rayures.
@export var couleurs_echarpe: PackedColorArray = [Color("1e6bff"), Color("ffffff")]
## Tempo des chants, en battements par minute. Partagé par toute une tribune.
@export_range(60, 200) var bpm := 120.0
## Énergie de 0 (tribune endormie) à 1 (bouillante) : amplitude des gestes.
@export_range(0.0, 1.5) var energie := 1.0
## Décalage personnel (secondes) pour que la foule ne bouge pas en bloc.
@export var decalage := 0.0
@export var ombre := true

var _corps: MeshInstance2D
var _paupieres: MeshInstance2D
var _effets: Node2D
var _mat: ShaderMaterial
var _rect := Rect2() # zone utile de l'image, origine aux pieds
var _t_action := 0.0
var _duree := 0.0
var _p := {} # paramètres de pose courants
var _p_depart := {} # pose au moment du changement d'action
var _fondu := 1.0
var _particules: Array[Dictionary] = []
var _emission := 0.0
var _cligne_dans := 3.0
var _rng := RandomNumberGenerator.new()
var _dernier_battement := -1

static var _grilles := {}
static var _rects := {}


## Crée un FANZZY à partir de son identifiant de catalogue (ex. "MT14"),
## de son évolution (e1, e2, e3) et de son skin (base, halloween...).
static func creer(id: String, evolution := "e1", skin := "base",
		dossiers: PackedStringArray = DOSSIERS_PAR_DEFAUT) -> FanzzyAnime:
	var f := FanzzyAnime.new()
	f.name = id
	f.fanzzy_id = id
	f.evolution = evolution
	f.skin = skin
	var images := charger_images(id, evolution, skin, dossiers)
	f.expressions = images
	f.texture = images.get(&"base", null)
	return f


## Cherche les images d'un FANZZY. Formats acceptés, du plus précis au plus simple :
## - <id>/<evolution>/<skin>/<etat>.webp (export TheBestFan), puis le skin « base » ;
## - <id>/<etat>.webp, <id>_<etat>.webp, <id>-<etat>.webp ;
## - <id>.webp pour l'image seule (vignette), utilisée si aucune expression n'existe.
## Les expressions partagent le même cadrage ; la vignette, non : quand l'expression
## « neutre » existe, c'est elle qui sert de base.
static func charger_images(id: String, evolution := "e1", skin := "base",
		dossiers: PackedStringArray = DOSSIERS_PAR_DEFAUT) -> Dictionary:
	var r := {}
	var noms: Array[StringName] = []
	noms.append_array(ETATS)
	noms.append(&"cligne")
	for etat in noms:
		var motifs: PackedStringArray = []
		for d in dossiers:
			motifs.append("%s/%s/%s/%s/%s" % [d, id, evolution, skin, etat])
			motifs.append("%s/%s/%s/base/%s" % [d, id, evolution, etat])
			motifs.append("%s/%s/%s" % [d, id, etat])
			motifs.append("%s/%s_%s" % [d, id, etat])
			motifs.append("%s/%s-%s" % [d, id, etat])
		var t := _premier_existant(motifs)
		if t:
			r[etat] = t
	if r.has(&"neutre"):
		r[&"base"] = r[&"neutre"]
	else:
		var motifs: PackedStringArray = []
		for d in dossiers:
			motifs.append("%s/%s" % [d, id])
		var t := _premier_existant(motifs)
		if t:
			r[&"base"] = t
	return r


static func _premier_existant(motifs: PackedStringArray) -> Texture2D:
	for m in motifs:
		for ext in ["webp", "png"]:
			var chemin := "%s.%s" % [m, ext]
			if ResourceLoader.exists(chemin):
				return load(chemin)
	return null


func _ready() -> void:
	if texture == null and fanzzy_id != "":
		expressions = charger_images(fanzzy_id, evolution, skin)
		texture = expressions.get(&"base", null)
	_rng.randomize()
	if decalage == 0.0:
		decalage = _rng.randf_range(0.0, 0.12)
	_cligne_dans = _rng.randf_range(1.0, 5.0)
	_preparer()
	_p = _pose(action, 0.0)
	jouer(action)


## Lance une action. `duree` < 0 : durée par défaut ; 0 : en boucle.
## `delai` permet d'échelonner une foule (ola, réaction à un but).
func jouer(nouvelle: StringName, duree := -1.0, delai := 0.0) -> void:
	if not ACTIONS.has(nouvelle):
		push_warning("FanzzyAnime : action inconnue « %s »" % nouvelle)
		return
	if delai > 0.0:
		get_tree().create_timer(delai).timeout.connect(jouer.bind(nouvelle, duree, 0.0))
		return
	_p_depart = _p.duplicate()
	_fondu = 0.0
	action = nouvelle
	_t_action = 0.0
	_duree = ACTIONS[nouvelle]["duree"] if duree < 0.0 else duree
	_appliquer_expression(ACTIONS[nouvelle]["etat"])


## Expression actuellement affichée (utile pour le duel).
func expression() -> StringName:
	return ACTIONS[action]["etat"]


func _preparer() -> void:
	if texture == null:
		return
	if _corps == null:
		_corps = MeshInstance2D.new()
		_corps.name = "Corps"
		add_child(_corps)
		_effets = Node2D.new()
		_effets.name = "Effets"
		add_child(_effets)
		_effets.draw.connect(_dessiner_effets)
		_mat = ShaderMaterial.new()
		_mat.shader = SHADER
		_corps.material = _mat
		# paupières : calque « cligne » (yeux fermés seuls) posé sur le corps
		_paupieres = MeshInstance2D.new()
		_paupieres.name = "Paupieres"
		_paupieres.material = _mat
		_paupieres.visible = false
		_corps.add_child(_paupieres)
	var brut := _zone_utile(texture)
	# origine entre les pieds : bas de la zone utile, milieu de l'image
	_rect = Rect2(brut.position.x - texture.get_size().x * 0.5, -brut.size.y, brut.size.x, brut.size.y)
	_corps.mesh = _grille(texture.get_size(), brut.end.y)
	_corps.texture = texture
	_paupieres.mesh = _corps.mesh
	_paupieres.texture = expressions.get(&"cligne", null)
	_mat.set_shader_parameter(&"hauteur", _rect.size.y)
	queue_redraw()


## Zone non transparente de l'image (en pixels de l'image), mise en cache.
static func _zone_utile(tex: Texture2D) -> Rect2:
	var cle := tex.resource_path if tex.resource_path != "" else str(tex.get_rid())
	if not _rects.has(cle):
		var img := tex.get_image()
		var u := Rect2(img.get_used_rect()) if img else Rect2(Vector2.ZERO, tex.get_size())
		_rects[cle] = u
	return _rects[cle]


## Grille 6 x 18 partagée par toutes les images de même taille.
static func _grille(taille: Vector2, pieds_y: float) -> ArrayMesh:
	var cle := "%d_%d_%d" % [taille.x, taille.y, pieds_y]
	if _grilles.has(cle):
		return _grilles[cle]
	var nx := 6
	var ny := 18
	var v := PackedVector2Array()
	var uv := PackedVector2Array()
	var idx := PackedInt32Array()
	for j in ny + 1:
		for i in nx + 1:
			var u := Vector2(float(i) / nx, float(j) / ny)
			uv.append(u)
			v.append(Vector2((u.x - 0.5) * taille.x, u.y * taille.y - pieds_y))
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			idx.append_array([a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_grilles[cle] = m
	return m


func _appliquer_expression(etat: StringName) -> void:
	if _corps == null:
		return
	var t: Texture2D = expressions.get(etat, null)
	if t == null:
		t = texture
	_corps.texture = t


func _process(delta: float) -> void:
	if _corps == null:
		return
	_t_action += delta
	if _duree > 0.0 and _t_action >= _duree:
		var finie := action
		jouer(&"repos")
		action_terminee.emit(finie)
	_fondu = minf(_fondu + delta / TRANSITION, 1.0)
	var cible := _pose(action, _t_action)
	if _fondu < 1.0:
		var k := smoothstep(0.0, 1.0, _fondu)
		for c in cible:
			if _p_depart.has(c) and typeof(cible[c]) == TYPE_FLOAT:
				cible[c] = lerpf(_p_depart[c], cible[c], k)
	_p = cible
	_corps.position = Vector2(_p.x, -_p.saut)
	_corps.modulate = _p.teinte
	_mat.set_shader_parameter(&"penche", _p.penche)
	_mat.set_shader_parameter(&"ecrase", Vector2(_p.sx, _p.sy))
	_mat.set_shader_parameter(&"onde_amp", _p.onde)
	_mat.set_shader_parameter(&"onde_phase", _p.onde_phase)
	_mat.set_shader_parameter(&"eclat", _p.eclat)
	_mat.set_shader_parameter(&"terne", _p.terne)
	_clignement(delta)
	_animer_particules(delta)
	queue_redraw()
	_effets.queue_redraw()


func _clignement(delta: float) -> void:
	if _paupieres.texture == null or expression() != &"neutre":
		_paupieres.visible = false
		return
	_cligne_dans -= delta
	_paupieres.visible = _cligne_dans <= 0.0
	if _cligne_dans < -0.12:
		_cligne_dans = _rng.randf_range(2.5, 6.0)


## Calcule la pose d'une action à l'instant t. Toutes les valeurs sont des
## fractions de la hauteur du personnage, sauf indication contraire.
func _pose(a: StringName, t: float) -> Dictionary:
	var h := _rect.size.y
	var e := energie
	var temps := Time.get_ticks_msec() / 1000.0 + decalage # horloge commune à la tribune
	var beat := 60.0 / bpm
	var ph := fposmod(temps / beat, 1.0) # phase dans le battement
	var p := {
		"x": 0.0, "saut": 0.0, "penche": 0.0, "sx": 1.0, "sy": 1.0,
		"onde": 0.0, "onde_phase": temps * 3.0, "eclat": 0.0, "terne": 0.0,
		"teinte": Color.WHITE, "echarpe": 0.0,
	}
	# respiration de fond, toujours présente
	var souffle := sin(temps * TAU * 0.35)
	p.sy = 1.0 + 0.012 * souffle
	p.sx = 1.0 - 0.006 * souffle
	p.penche = 0.012 * sin(temps * 0.9 + decalage * 40.0)
	match a:
		&"sauter":
			_saut(p, fposmod(temps / (beat * 2.0), 1.0), 0.14 * e, h)
		&"celebrer":
			_saut(p, fposmod(temps / (beat * 1.5), 1.0), 0.22 * e, h)
			p.penche += 0.06 * e * sin(temps * TAU / (beat * 3.0))
			p.onde = 0.025 * e
			p.onde_phase = temps * 14.0
			p.eclat = 0.5 + 0.5 * sin(temps * 9.0)
		&"chanter":
			var bal := sin(temps * PI / beat) # un balancement toutes les deux mesures
			p.penche = 0.05 * e * bal
			p.sy *= 1.0 + 0.03 * e * absf(sin(temps * PI / beat))
			p.x = 0.015 * h * e * bal
		&"agiter_echarpe":
			p.sy *= 1.0 + 0.025 * e * absf(sin(temps * TAU / beat))
			p.penche = 0.025 * e * sin(temps * TAU / beat)
			p.echarpe = 1.0
		&"applaudir":
			var choc := pow(1.0 - fposmod(temps / (beat * 0.5), 1.0), 3.0)
			p.sy *= 1.0 - 0.035 * e * choc
			p.sx *= 1.0 + 0.03 * e * choc
			p.saut = 0.015 * h * e * (1.0 - choc)
		&"encourager":
			var poing := pow(sin(ph * PI), 6.0) # coup de poing sur le temps
			p.sy *= 1.0 + 0.06 * e * poing
			p.sx *= 1.0 - 0.03 * e * poing
			p.penche = 0.03 * e * sin(temps * PI / beat)
			p.saut = 0.03 * h * e * poing
		&"depit":
			var k := smoothstep(0.0, 0.6, t)
			p.sy *= 1.0 - 0.07 * k
			p.sx *= 1.0 + 0.035 * k
			p.penche = 0.02 * sin(temps * 1.3) * k + 0.03 * k
			p.terne = 0.9 * k
		&"huer":
			p.x = 0.006 * h * sin(temps * 70.0) * e
			p.penche = 0.05 * e * sin(temps * PI / beat) + 0.008 * sin(temps * 47.0)
			p.sy *= 1.0 + 0.02 * e * absf(sin(temps * TAU / beat))
			p.teinte = Color(1.0, 0.82, 0.8)
	return p


## Saut cartoon : on s'écrase, on décolle en s'étirant, on atterrit en s'écrasant.
func _saut(p: Dictionary, c: float, hauteur: float, h: float) -> void:
	if c < 0.15:
		var k := sin(c / 0.15 * PI)
		p.sy *= 1.0 - 0.1 * k
		p.sx *= 1.0 + 0.07 * k
	elif c < 0.85:
		var k := (c - 0.15) / 0.7
		p.saut = h * hauteur * sin(k * PI)
		# étiré en montant et en descendant, rond au sommet
		var etire := absf(cos(k * PI))
		p.sy *= 1.0 + 0.06 * etire
		p.sx *= 1.0 - 0.04 * etire
	else:
		var k := sin((c - 0.85) / 0.15 * PI)
		p.sy *= 1.0 - 0.08 * k
		p.sx *= 1.0 + 0.06 * k


# --- Dessin : ombre, écharpe, effets -------------------------------------

func _draw() -> void:
	if not ombre or _corps == null:
		return
	var w := _rect.size.x * 0.42
	var k := 1.0 - clampf(_p.get("saut", 0.0) / (_rect.size.y * 0.3), 0.0, 0.6)
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(Vector2(cos(a) * w * k, sin(a) * w * 0.14 * k))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28 * k))


func _dessiner_effets() -> void:
	if _corps == null:
		return
	if _p.get("echarpe", 0.0) > 0.0:
		_dessiner_echarpe()
	if action == &"depit":
		_dessiner_nuage(smoothstep(0.2, 0.8, _t_action))
	for q in _particules:
		_dessiner_particule(q)


func _haut_tete() -> Vector2:
	return Vector2(_p.x + _p.penche * _rect.size.y * 1.0, -_rect.size.y * _p.sy - _p.saut)


## Écharpe tenue à bout de bras au-dessus de la tête, qui ondule et balance.
func _dessiner_echarpe() -> void:
	var h := _rect.size.y
	var temps := Time.get_ticks_msec() / 1000.0 + decalage
	var beat := 60.0 / bpm
	var centre := _haut_tete() + Vector2(0, -h * 0.035)
	var larg := clampf(_rect.size.x * 1.1, h * 0.45, h * 0.7)
	var ep := h * 0.055
	var bal := sin(temps * TAU / beat) * energie
	centre.x += bal * h * 0.06
	var n := 14
	var haut := PackedVector2Array()
	var bas := PackedVector2Array()
	for i in n + 1:
		var u := float(i) / n
		var x := (u - 0.5) * larg
		var y := sin(temps * 9.0 - u * 6.0) * h * 0.018 * energie + bal * (u - 0.5) * h * 0.08
		haut.append(centre + Vector2(x, y - ep * 0.5))
		bas.append(centre + Vector2(x, y + ep * 0.5))
	var c1 := couleurs_echarpe[0] if couleurs_echarpe.size() > 0 else Color.WHITE
	var c2 := couleurs_echarpe[1] if couleurs_echarpe.size() > 1 else c1.lightened(0.6)
	var contour := Color(0.08, 0.06, 0.12)
	# pans qui pendent aux deux extrémités
	for cote in [0, n]:
		var a: Vector2 = haut[cote]
		var dir := -1.0 if cote == 0 else 1.0
		var pend := PackedVector2Array()
		var flot := sin(temps * 7.0 + cote) * h * 0.02
		pend.append(a)
		pend.append(a + Vector2(dir * ep * 0.9, 0))
		pend.append(a + Vector2(dir * ep * 0.9 + flot, h * 0.22))
		pend.append(a + Vector2(flot, h * 0.22))
		_effets.draw_colored_polygon(pend, c1)
		_effets.draw_polyline(pend + PackedVector2Array([pend[0]]), contour, 3.0)
		for f in 4: # franges
			var fx := a.x + flot + dir * ep * 0.9 * (f + 0.5) / 4.0
			_effets.draw_line(Vector2(fx, a.y + h * 0.22), Vector2(fx, a.y + h * 0.25), c2, 4.0)
	for i in n:
		var quad := PackedVector2Array([haut[i], haut[i + 1], bas[i + 1], bas[i]])
		_effets.draw_colored_polygon(quad, c1 if (i / 2) % 2 == 0 else c2)
	var bord := haut.duplicate()
	for i in range(n, -1, -1):
		bord.append(bas[i])
	bord.append(haut[0])
	_effets.draw_polyline(bord, contour, 4.0)
	# poings qui tiennent l'écharpe
	for cote in [0, n]:
		var m: Vector2 = (haut[cote] + bas[cote]) * 0.5
		_effets.draw_circle(m, ep * 0.55, Color(0.98, 0.8, 0.66))
		_effets.draw_arc(m, ep * 0.55, 0, TAU, 16, contour, 3.0)


func _dessiner_nuage(k: float) -> void:
	if k <= 0.0:
		return
	var h := _rect.size.y
	var c := _haut_tete() + Vector2(0, -h * 0.12)
	var gris := Color(0.45, 0.48, 0.55, 0.92 * k)
	for b in [[-0.07, 0.0, 0.055], [0.0, -0.03, 0.07], [0.075, 0.0, 0.05], [0.02, 0.02, 0.055]]:
		_effets.draw_circle(c + Vector2(b[0], b[1]) * h, b[2] * h * k, gris)


# --- Particules simples (notes, confettis, gouttes, étincelles) ----------

func _animer_particules(delta: float) -> void:
	var h := _rect.size.y
	var taux := 0.0
	var genre := &""
	match action:
		&"chanter":
			taux = 2.2 * energie
			genre = &"note"
		&"celebrer":
			taux = 26.0
			genre = &"confetti"
		&"depit":
			taux = 9.0 if _t_action > 0.6 else 0.0
			genre = &"goutte"
		&"huer":
			taux = 1.6
			genre = &"colere"
		&"applaudir":
			var b := int(floor((Time.get_ticks_msec() / 1000.0 + decalage) / (30.0 / bpm)))
			if b != _dernier_battement:
				_dernier_battement = b
				_ajouter(&"etincelle", Vector2(_p.x, -h * 0.55 - _p.saut))
	_emission += taux * delta
	while _emission >= 1.0:
		_emission -= 1.0
		var tete := _haut_tete()
		match genre:
			&"note":
				_ajouter(genre, tete + Vector2(_rng.randf_range(-0.1, 0.1) * h, h * 0.08))
			&"confetti":
				_ajouter(genre, tete + Vector2(_rng.randf_range(-0.25, 0.25) * h, -h * _rng.randf_range(0.0, 0.2)))
			&"goutte":
				_ajouter(genre, tete + Vector2(_rng.randf_range(-0.08, 0.1) * h, -h * 0.1))
			&"colere":
				_ajouter(genre, tete + Vector2(_rng.randf_range(0.05, 0.12) * h * (1 if _rng.randf() < 0.5 else -1), h * 0.04))
	for i in range(_particules.size() - 1, -1, -1):
		var q := _particules[i]
		q.vie += delta
		if q.vie >= q.duree:
			_particules.remove_at(i)
			continue
		q.vel += q.grav * delta
		q.pos += q.vel * delta
		q.rot += q.vrot * delta


func _ajouter(genre: StringName, pos: Vector2) -> void:
	var h := _rect.size.y
	var q := {"genre": genre, "pos": pos, "vie": 0.0, "rot": 0.0, "vrot": 0.0,
		"vel": Vector2.ZERO, "grav": Vector2.ZERO, "duree": 1.2, "couleur": Color.WHITE,
		"taille": h * 0.035}
	match genre:
		&"note":
			q.vel = Vector2(_rng.randf_range(-0.05, 0.05), -0.22) * h
			q.duree = 1.6
			q.couleur = [Color("ffd23f"), Color("ffffff"), Color("ff3d7f")][_rng.randi() % 3]
			q.rot = _rng.randf_range(-0.3, 0.3)
		&"confetti":
			q.vel = Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.6, -0.2)) * h
			q.grav = Vector2(0, 0.9 * h)
			q.duree = 1.4
			q.vrot = _rng.randf_range(-12.0, 12.0)
			q.taille = h * 0.018
			q.couleur = [Color("1e6bff"), Color("ff3d7f"), Color("ffd23f"), Color("3ddc84"), Color("8b5cff")][_rng.randi() % 5]
		&"goutte":
			q.vel = Vector2(0, 0.5 * h)
			q.duree = 0.35
			q.couleur = Color(0.55, 0.75, 1.0, 0.9)
			q.taille = h * 0.012
		&"colere":
			q.vel = Vector2(0, -0.04 * h)
			q.duree = 0.8
			q.couleur = Color("e0402c")
		&"etincelle":
			q.duree = 0.25
			q.couleur = Color("ffd23f")
			q.taille = h * 0.06
	_particules.append(q)


func _dessiner_particule(q: Dictionary) -> void:
	var u: float = q.vie / q.duree
	var a := 1.0 - smoothstep(0.6, 1.0, u)
	var c: Color = q.couleur
	c.a *= a
	var s: float = q.taille
	var n := _effets
	var contour := Color(0.08, 0.06, 0.12, a)
	match q.genre:
		&"note":
			var p: Vector2 = q.pos + Vector2(sin(q.vie * 6.0) * s * 0.6, 0)
			var t := Transform2D(q.rot, p)
			n.draw_set_transform_matrix(t)
			n.draw_circle(Vector2.ZERO, s * 0.55, contour)
			n.draw_circle(Vector2.ZERO, s * 0.42, c)
			n.draw_line(Vector2(s * 0.42, 0), Vector2(s * 0.42, -s * 1.6), contour, s * 0.22)
			n.draw_line(Vector2(s * 0.42, -s * 1.6), Vector2(s * 1.1, -s * 1.1), contour, s * 0.22)
			n.draw_set_transform_matrix(Transform2D.IDENTITY)
		&"confetti":
			n.draw_set_transform(q.pos, q.rot, Vector2(1.0, absf(cos(q.rot * 0.7)) + 0.2))
			n.draw_rect(Rect2(-s * 0.5, -s * 0.3, s, s * 0.6), c)
			n.draw_set_transform_matrix(Transform2D.IDENTITY)
		&"goutte":
			n.draw_line(q.pos, q.pos + Vector2(0, s * 2.5), c, s * 0.5)
		&"colere":
			var k := 0.6 + 0.4 * sin(u * PI)
			n.draw_set_transform(q.pos, 0.0, Vector2.ONE * k)
			for i in 4:
				var r := Transform2D(i * PI * 0.5 + PI * 0.25, Vector2.ZERO)
				var a1 := r * Vector2(s * 0.25, 0)
				var a2 := r * Vector2(s * 0.8, s * 0.2)
				var a3 := r * Vector2(s * 0.8, -s * 0.2)
				n.draw_polyline(PackedVector2Array([a2, a1, a3]), c, s * 0.2)
			n.draw_set_transform_matrix(Transform2D.IDENTITY)
		&"etincelle":
			for i in 6:
				var dir := Vector2.from_angle(i * TAU / 6.0 + 0.3)
				n.draw_line(q.pos + dir * s * (0.3 + u), q.pos + dir * s * (0.6 + u), c, s * 0.12)
