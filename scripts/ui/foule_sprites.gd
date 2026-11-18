class_name FouleSprites
## Supporters de tribune en sprites 2D, rendus depuis le mannequin animé de la
## « Universal Animation Library » de Quaternius (CC0, voir assets/foule/).
##
## Chaque image a quatre calques : la base (contour, jean, baskets, cheveux)
## puis la peau, le maillot et l'écharpe en niveaux de gris, que l'on teinte
## aux couleurs du club. Trois variantes : cheveux courts, longs, bonnet.
##
##   FouleSprites.dessiner(self, pied, 60.0, &"sauter", t, maillot, echarpe, peau, variante)
##
## Les gestes : repos, sauter, applaudir, ola (une seule fois), echarpe,
## depit, danser. Outils de rendu : tools/foule/.

const DOSSIER := "res://assets/foule/"
const PEAUX := [Color("#f2c9a0"), Color("#d9a273"), Color("#a86b3c"), Color("#6b4226"), Color("#ffe0bd")]

static var _meta: Dictionary = {}
static var _textures: Array[Texture2D] = []


static func _charger() -> bool:
	if not _meta.is_empty():
		return not _textures.is_empty()
	var f := FileAccess.open(DOSSIER + "foule.json", FileAccess.READ)
	if f == null:
		_meta = {"vide": true}
		return false
	_meta = JSON.parse_string(f.get_as_text())
	for nom in _meta["variantes"]:
		var tex := load(DOSSIER + str(nom)) as Texture2D
		if tex:
			_textures.append(tex)
	return not _textures.is_empty()


static func disponible() -> bool:
	return _charger()


static func nb_variantes() -> int:
	return _textures.size() if _charger() else 0


## Durée d'un geste joué une fois (secondes), ex. la ola.
static func duree(geste: StringName) -> float:
	if not _charger():
		return 1.0
	var g: Dictionary = _meta["gestes"].get(str(geste), {})
	return float(g.get("n", 8)) / float(g.get("fps", 8))


## Dessine un supporter debout, les pieds en `pied`, haut de `hauteur` pixels
## (de la tête aux baskets, au repos). `t` = temps écoulé dans le geste.
static func dessiner(ci: CanvasItem, pied: Vector2, hauteur: float, geste: StringName, t: float,
		maillot: Color, echarpe: Color, peau: Color, variante := 0, alpha := 1.0) -> void:
	if not _charger():
		return
	var g: Dictionary = _meta["gestes"].get(str(geste), _meta["gestes"]["repos"])
	var n := int(g["n"])
	var i := int(floor(t * float(g["fps"])))
	i = posmod(i, n) if g["boucle"] else clampi(i, 0, n - 1)
	var taille := Vector2(_meta["taille"][0], _meta["taille"][1])
	var tete := float(_meta["tete"])
	var bas := float(_meta["pied"])
	var ech := hauteur / (bas - tete)
	var saut := 0.0
	if geste == &"sauter":  # l'élan du sprite + un vrai décollage
		saut = sin(PI * float(i) / float(n)) * hauteur * 0.16
	var dest := Rect2(pied - Vector2(taille.x * 0.5, bas + saut / ech) * ech, taille * ech)
	var tex: Texture2D = _textures[posmod(variante, _textures.size())]
	var ligne := int(g["ligne"])
	var couleurs := [Color(1, 1, 1, alpha), Color(peau, alpha), Color(maillot, alpha), Color(echarpe, alpha)]
	for c in 4:
		if c == 3 and geste != &"echarpe" and variante % 3 != 2:
			continue  # pas d'écharpe ni de pompon sur cette image
		var src := Rect2(Vector2(i * taille.x, (ligne + c) * taille.y), taille)
		ci.draw_texture_rect_region(tex, dest, src, couleurs[c])


## Un geste d'ambiance pour le supporter `graine` (0..1) selon la ferveur
## (0..1) ; il en change toutes les quelques secondes. Renvoie [geste, t local].
static func geste_ambiance(ferveur: float, graine: float, temps: float) -> Array:
	var periode := 3.0 + graine * 2.5
	var tranche: float = floor((temps + graine * 7.0) / periode)
	var h := fposmod(sin(tranche * 12.9898 + graine * 78.233) * 43758.5453, 1.0)
	var local := temps + graine * 5.0
	if h > ferveur + 0.15:
		return [&"repos", local]
	if ferveur < 0.5:
		return [&"applaudir" if h < 0.6 * ferveur else &"repos", local]
	var choix := [&"sauter", &"applaudir", &"echarpe", &"sauter", &"danser"]
	return [choix[int(h * 97.0) % choix.size()], local]
