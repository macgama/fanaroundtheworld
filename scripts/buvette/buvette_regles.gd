class_name BuvetteRegles
extends RefCounted
## Règles du petit boulot « vendeur à la buvette », sans affichage (testables).
##
## Un service dure 60 secondes, comme une mi-temps vue depuis la buvette.
## Les FANZZY arrivent au comptoir avec une commande ; le joueur pose les
## articles sur le plateau puis sert. Commande exacte = salaire + pourboire
## (plus il a été rapide, plus le pourboire est gros). Erreur ou client
## lassé = rien, et la série repart de zéro.
## À 30 s, la mi-temps du vrai match : c'est le rush, commandes plus
## grosses (donc mieux payées) et patience plus courte.
## Au-delà de SERVICES_PLEIN_TARIF services dans la journée, la paye baisse (÷ 2, puis ÷ 4) :
## voir ListeBoulots.part_du_jour.

const DUREE := 60.0
const DEBUT_RUSH := 30.0

const PRODUITS := [
	{"id": "boisson", "nom": "Boisson", "touche": "1"},
	{"id": "hotdog", "nom": "Hot-dog", "touche": "2"},
	{"id": "frites", "nom": "Frites", "touche": "3"},
	{"id": "gaufre", "nom": "Gaufre", "touche": "4"},
]
const MAX_PAR_ARTICLE := 3
const SALAIRE_PAR_CLIENT := 1
const ARTICLES_PAR_JETON_EN_PLUS := 3   # +1 Jeton de salaire par tranche de 3 articles
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


static func ids() -> Array:
	return PRODUITS.map(func(p): return p["id"])


static func nom(id: String) -> String:
	for p in PRODUITS:
		if p["id"] == id:
			return p["nom"]
	return id


static func en_rush(temps: float) -> bool:
	return temps >= DEBUT_RUSH


## Nouvelle commande pour le `numero`-ième client (0 = le premier).
## Rend {"articles": {id: quantité}, "patience": secondes, "rush": bool}.
func commande(numero: int, rush: bool) -> Dictionary:
	var nb: int
	if numero < 3:
		nb = 1
	elif rush:
		nb = rng.randi_range(2, 4)
	else:
		nb = rng.randi_range(1, 3)
	var articles := {}
	var liste := ids()
	while nb > 0:
		var id: String = liste[rng.randi() % liste.size()]
		if int(articles.get(id, 0)) >= MAX_PAR_ARTICLE:
			continue
		articles[id] = int(articles.get(id, 0)) + 1
		nb -= 1
	var patience := 5.0 + 1.6 * nombre_articles(articles)
	if rush:
		patience *= 0.85
	return {"articles": articles, "patience": patience, "rush": rush}


static func nombre_articles(articles: Dictionary) -> int:
	var n := 0
	for id in articles:
		n += int(articles[id])
	return n


## Le plateau correspond-il exactement à la commande ?
static func conforme(plateau: Dictionary, articles: Dictionary) -> bool:
	for id in ids():
		if int(plateau.get(id, 0)) != int(articles.get(id, 0)):
			return false
	return true


## Jetons gagnés pour une commande servie juste.
## `reste` : part de patience restante (1 = servi tout de suite, 0 = in extremis).
## `serie` : nombre de commandes justes d'affilée, celle-ci comprise.
static func paye(articles: Dictionary, reste: float, serie: int) -> Dictionary:
	var salaire := SALAIRE_PAR_CLIENT + nombre_articles(articles) / ARTICLES_PAR_JETON_EN_PLUS
	var pourboire := int(round(clampf(reste, 0.0, 1.0) * POURBOIRE_MAX))
	var bonus := 1 if serie > 0 and serie % SERIE_BONUS == 0 else 0
	return {"salaire": salaire, "pourboire": pourboire, "bonus": bonus, "total": salaire + pourboire + bonus}


## Paye du service entier, selon le nombre de services déjà faits aujourd'hui.
static func paye_finale(brut: int, services_du_jour: int) -> int:
	return ListeBoulots.paye_du_jour(brut, services_du_jour)
