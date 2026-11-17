class_name EcharpesRegles
extends RefCounted
## Règles du petit boulot « vendeur d'écharpes », sans affichage (testables).
##
## Un service dure 60 secondes, devant les grilles du stade avant le match.
## Les FANZZY font la queue au stand ; chacun montre l'écusson de son club
## (ou de deux clubs : une écharpe pour lui, une pour un ami). Le joueur
## décroche du portant l'écharpe AUX BONNES COULEURS (les écharpes n'ont
## pas de nom, seulement les deux couleurs du club). Mauvaise écharpe ou
## client lassé = rien, et la série repart de zéro.
## Chaque crochet du portant tient STOCK_CROCHET écharpes : quand il est
## vide, il faut aller au carton (réassort, quelques secondes perdues).
## À 30 s, l'ouverture des portes : c'est le rush, deux clubs de plus sur le
## portant, des commandes plus grosses et moins de patience.
## Au-delà de SERVICES_PLEIN_TARIF services dans la journée, la paye baisse (÷ 2, puis ÷ 4) :
## voir ListeBoulots.part_du_jour.

const DUREE := 60.0
const DEBUT_RUSH := 30.0

const CLUBS_CALME := 4
const CLUBS_RUSH := 6
const STOCK_CROCHET := 3
const DUREE_REASSORT := 1.4
const SALAIRE_PAR_ECHARPE := 1
const POURBOIRE_MAX := 1
const SERIE_BONUS := 5          # +1 Jeton toutes les 5 commandes justes d'affilée
const XP_PAR_CLIENT := 2
const SERVICES_PLEIN_TARIF := ListeBoulots.PLEIN_TARIF

var rng := RandomNumberGenerator.new()


func _init(graine := -1) -> void:
	if graine >= 0:
		rng.seed = graine
	else:
		rng.randomize()


static func en_rush(temps: float) -> bool:
	return temps >= DEBUT_RUSH


static func nb_clubs(rush: bool) -> int:
	return CLUBS_RUSH if rush else CLUBS_CALME


## Les clubs fictifs connus (table des noms fictifs), au format {nom, sigle, c1, c2}.
static func clubs_connus() -> Array:
	var res: Array = []
	var f := FileAccess.open("res://data/clubs/noms_fictifs.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for id in d.get("clubs", {}):
				res.append(Fiction.equipe({"id": id}))
	# Toujours de quoi remplir le portant, même sans la table.
	var i := 0
	while res.size() < CLUBS_RUSH * 2:
		res.append(Fiction.equipe({"id": "stand:%d" % i}))
		i += 1
	return res


## Deux écharpes se confondent-elles ? (mêmes couleurs, dans un sens ou dans l'autre,
## ou des teintes trop proches pour qu'on s'y retrouve sur un portant).
static func se_confondent(a: Dictionary, b: Dictionary) -> bool:
	var direct := _ecart(a["c1"], b["c1"]) + _ecart(a["c2"], b["c2"])
	var croise := _ecart(a["c1"], b["c2"]) + _ecart(a["c2"], b["c1"])
	return minf(direct, croise) < 0.5


static func _ecart(x: Color, y: Color) -> float:
	return Vector3(x.r - y.r, x.g - y.g, x.b - y.b).length()


## Choisit les clubs du portant : CLUBS_RUSH clubs qu'on ne peut pas confondre.
## Les CLUBS_CALME premiers sont accrochés dès le début, les autres au rush.
func portant(clubs: Array) -> Array:
	var tas := clubs.duplicate()
	for i in range(tas.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t: Variant = tas[i]
		tas[i] = tas[j]
		tas[j] = t
	var res: Array = []
	for c in tas:
		if res.size() >= CLUBS_RUSH:
			break
		var ok := true
		for d in res:
			if se_confondent(c, d):
				ok = false
				break
		if ok:
			res.append(c)
	# Table trop pauvre : on complète quand même (ne doit pas arriver).
	for c in tas:
		if res.size() >= CLUBS_RUSH:
			break
		if not c in res:
			res.append(c)
	return res


## Nouvelle commande pour le `numero`-ième client (0 = le premier).
## `en_rayon` : nombre de clubs accrochés (on ne demande que ceux-là).
## Rend {"echarpes": [indices du portant], "patience": secondes, "rush": bool}.
## Deux écharpes au plus, jamais deux fois la même.
func commande(numero: int, rush: bool, en_rayon: int) -> Dictionary:
	var nb := 1
	if numero >= 3:
		nb = 2 if rng.randf() < (0.45 if rush else 0.25) else 1
	var liste: Array = []
	while liste.size() < nb:
		var i := rng.randi() % en_rayon
		if not i in liste:
			liste.append(i)
	var patience := 3.5 + 2.2 * nb
	if rush:
		patience *= 0.85
	return {"echarpes": liste, "patience": patience, "rush": rush}


## Jetons gagnés pour une commande servie juste.
## `reste` : part de patience restante (1 = servi tout de suite, 0 = in extremis).
## `serie` : nombre de commandes justes d'affilée, celle-ci comprise.
static func paye(nb_echarpes: int, reste: float, serie: int) -> Dictionary:
	var salaire := SALAIRE_PAR_ECHARPE * nb_echarpes
	var pourboire := int(round(clampf(reste, 0.0, 1.0) * POURBOIRE_MAX))
	var bonus := 1 if serie > 0 and serie % SERIE_BONUS == 0 else 0
	return {"salaire": salaire, "pourboire": pourboire, "bonus": bonus, "total": salaire + pourboire + bonus}


## Paye du service entier, selon le nombre de services déjà faits aujourd'hui.
static func paye_finale(brut: int, services_du_jour: int) -> int:
	return ListeBoulots.paye_du_jour(brut, services_du_jour)
