class_name TifoRegles
extends RefCounted
## Règles du petit boulot « peintre de tifo », sans affichage (testables).
##
## Avant le match, le capo du fan club confie au joueur une grande bâche à
## peindre d'après un modèle. Un service dure 60 secondes : on enchaîne les
## bâches, de plus en plus grandes. Chaque case de la bâche se peint au
## pinceau (case par case, en glissant) ou au seau (toute la zone de même
## couleur d'un coup). On présente la bâche au capo quand on veut :
##   - ressemblance < SEUIL_REFUS : le capo la refuse, on continue de peindre ;
##   - sinon la bâche est hissée en tribune et payée selon sa ressemblance,
##     avec un bonus si elle est parfaite (et toutes les SERIE_BONUS parfaites).
## Au-delà de SERVICES_PLEIN_TARIF services dans la journée, la paye est
## divisée par deux, comme à la buvette.

const DUREE := 60.0
const VIERGE := -1

## Les pots de peinture (touches 1 à 5).
const PEINTURES := [
	{"nom": "Blanc", "couleur": Color("#ffffff")},
	{"nom": "Rose", "couleur": Color("#ff3d7f")},
	{"nom": "Bleu", "couleur": Color("#1e6bff")},
	{"nom": "Jaune", "couleur": Color("#ffd23f")},
	{"nom": "Violet", "couleur": Color("#8b5cff")},
]

## Taille des bâches successives (colonnes x rangées) ; la dernière se répète.
const TAILLES := [Vector2i(8, 5), Vector2i(10, 6), Vector2i(12, 7), Vector2i(14, 8), Vector2i(16, 9)]

## Motifs : les deux premiers sont simples, les suivants tirés au sort.
const MOTIFS_FACILES := ["drapeau", "echarpe"]
const MOTIFS := ["coeur", "etoile", "ballon", "cible", "eclair", "damier", "bandes", "losange"]
const NOMS := {
	"drapeau": "Le drapeau", "echarpe": "L'écharpe", "coeur": "Le cœur", "etoile": "L'étoile",
	"ballon": "Le ballon", "cible": "La cible", "eclair": "L'éclair", "damier": "Le damier",
	"bandes": "Les bandes", "losange": "Le losange",
}

const CASES_PAR_JETON := 16      # salaire de base : 1 Jeton par tranche de 16 cases (arrondi au-dessus)
const SEUIL_REFUS := 0.75
const PALIERS := [[1.0, 1.0], [0.9, 0.6], [0.75, 0.3]]  # [ressemblance mini, part du salaire]
const BONUS_PARFAIT := 1
const SERIE_BONUS := 3           # +1 Jeton toutes les 3 bâches parfaites d'affilée
const XP_PAR_TIFO := 4
const SERVICES_PLEIN_TARIF := 3

var rng := RandomNumberGenerator.new()


func _init(graine := -1) -> void:
	if graine >= 0:
		rng.seed = graine
	else:
		rng.randomize()


static func taille(numero: int) -> Vector2i:
	return TAILLES[mini(numero, TAILLES.size() - 1)]


static func couleur(indice: int) -> Color:
	if indice < 0 or indice >= PEINTURES.size():
		return Color("#efe6cf")
	return PEINTURES[indice]["couleur"]


## Nouveau modèle pour la `numero`-ième bâche du service (0 = la première).
## Rend {"motif", "nom", "w", "h", "cases": PackedInt32Array (w*h, rangée par rangée)}.
func modele(numero: int) -> Dictionary:
	var t := taille(numero)
	var motif: String = MOTIFS_FACILES[numero] if numero < MOTIFS_FACILES.size() else MOTIFS[rng.randi() % MOTIFS.size()]
	# 2 ou 3 peintures différentes, tirées au sort
	var pots := range(PEINTURES.size())
	for i in range(pots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x: int = pots[i]
		pots[i] = pots[j]
		pots[j] = x
	return {"motif": motif, "nom": NOMS[motif], "w": t.x, "h": t.y, "cases": dessiner(motif, t.x, t.y, pots[0], pots[1], pots[2])}


## Dessine un motif sur une grille w x h avec les peintures a (forme), b (fond), c (détail).
static func dessiner(motif: String, w: int, h: int, a: int, b: int, c: int) -> PackedInt32Array:
	var cases := PackedInt32Array()
	cases.resize(w * h)
	var demi := h / 2.0
	var etoile := _polygone_etoile(5, 1.12, 0.52)
	var penta := _polygone_etoile(5, 0.36, 0.36 * cos(PI / 5.0))
	for j in h:
		for i in w:
			# coordonnées centrées, 1 = demi-hauteur de la bâche
			var x := (i + 0.5 - w / 2.0) / demi
			var y := (j + 0.5 - h / 2.0) / demi
			var v := b
			match motif:
				"drapeau":
					v = [a, b, c][mini(2, i * 3 / w)]
				"echarpe":
					v = c if j == 0 or j == h - 1 else (a if j % 2 == 1 else b)
				"coeur":
					var hx := x * 1.12
					var hy := -y * 1.15 + 0.2
					v = a if pow(hx * hx + hy * hy - 1.0, 3) - hx * hx * pow(hy, 3) <= 0.0 else b
				"etoile":
					v = a if Geometry2D.is_point_in_polygon(Vector2(x, y - 0.1), etoile) else b
				"ballon":
					var d := Vector2(x, y).length()
					if d > 0.95:
						v = b
					elif Geometry2D.is_point_in_polygon(Vector2(x, y), penta) or d > 0.78:
						v = c
					else:
						v = a
				"cible":
					var d2 := Vector2(x, y).length()
					v = a if d2 < 0.36 else (c if d2 < 0.68 else (a if d2 < 0.98 else b))
				"eclair":
					var zig := PackedVector2Array([Vector2(-0.1, -1.1), Vector2(0.75, -1.1), Vector2(0.3, -0.2), Vector2(0.85, -0.2), Vector2(-0.45, 1.1), Vector2(-0.1, 0.2), Vector2(-0.6, 0.2)])
					v = a if Geometry2D.is_point_in_polygon(Vector2(x, y), zig) else b
				"damier":
					var cote := maxi(2, h / 3)
					v = c if i == 0 or i == w - 1 or j == 0 or j == h - 1 else (a if ((i - 1) / cote + (j - 1) / cote) % 2 == 0 else b)
				"bandes":
					v = a if posmod(i + j, 4) < 2 else b
				"losange":
					v = a if absf(x) / (w / float(h)) + absf(y) <= 0.95 else b
					if v == a and absf(x) / (w / float(h)) + absf(y) <= 0.4:
						v = c
			cases[j * w + i] = v
	return cases


static func _polygone_etoile(branches: int, r_ext: float, r_int: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in branches * 2:
		var ang := -PI / 2.0 + k * PI / branches
		var r := r_ext if k % 2 == 0 else r_int
		p.append(Vector2(cos(ang), sin(ang)) * r)
	return p


static func bache_vierge(w: int, h: int) -> PackedInt32Array:
	var b := PackedInt32Array()
	b.resize(w * h)
	b.fill(VIERGE)
	return b


## Coup de seau : peint toute la zone (4-voisins) de même couleur que la case (x, y).
## Rend le nombre de cases changées ; `cases` est modifié sur place.
static func seau(cases: PackedInt32Array, w: int, h: int, x: int, y: int, peinture: int) -> int:
	if x < 0 or y < 0 or x >= w or y >= h:
		return 0
	var avant := cases[y * w + x]
	if avant == peinture:
		return 0
	var pile := [Vector2i(x, y)]
	var n := 0
	while not pile.is_empty():
		var p: Vector2i = pile.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or cases[p.y * w + p.x] != avant:
			continue
		cases[p.y * w + p.x] = peinture
		n += 1
		pile.append(p + Vector2i.RIGHT)
		pile.append(p + Vector2i.LEFT)
		pile.append(p + Vector2i.DOWN)
		pile.append(p + Vector2i.UP)
	return n


## Part des cases peintes comme sur le modèle (0 à 1).
static func ressemblance(bache: PackedInt32Array, modele: PackedInt32Array) -> float:
	if modele.is_empty() or bache.size() != modele.size():
		return 0.0
	var ok := 0
	for i in modele.size():
		if bache[i] == modele[i]:
			ok += 1
	return ok / float(modele.size())


static func salaire_de_base(nb_cases: int) -> int:
	return int(ceil(nb_cases / float(CASES_PAR_JETON)))


## Jetons gagnés pour une bâche présentée au capo.
## `serie` : bâches parfaites d'affilée, celle-ci comprise (0 si elle ne l'est pas).
## Rend {"accepte", "salaire", "bonus", "total"}.
static func paye(nb_cases: int, resse: float, serie: int) -> Dictionary:
	if resse < SEUIL_REFUS:
		return {"accepte": false, "salaire": 0, "bonus": 0, "total": 0}
	var part := 0.0
	for p in PALIERS:
		if resse >= p[0] - 0.00001:
			part = p[1]
			break
	var salaire := int(round(salaire_de_base(nb_cases) * part))
	var bonus := 0
	if resse >= 0.99999:
		bonus = BONUS_PARFAIT + (1 if serie > 0 and serie % SERIE_BONUS == 0 else 0)
	return {"accepte": true, "salaire": salaire, "bonus": bonus, "total": salaire + bonus}


## Mot du capo selon la ressemblance.
static func appreciation(resse: float) -> String:
	if resse >= 0.99999:
		return "PARFAIT !"
	if resse >= 0.9:
		return "Très beau !"
	if resse >= SEUIL_REFUS:
		return "Ça ira…"
	return "Pas encore !"


## Paye du service entier, selon le nombre de services déjà faits aujourd'hui.
static func paye_finale(brut: int, services_du_jour: int) -> int:
	if services_du_jour >= SERVICES_PLEIN_TARIF:
		return int(ceil(brut / 2.0))
	return brut
