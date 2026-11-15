class_name PousseeRegles
extends RefCounted
## Règles du mode Poussée (cartes de supporters), sans affichage :
## utilisées par scenes/poussee/poussee.gd et testées par tests/test_modes.gd.
##
## Un ballon au milieu. Tes supporters le poussent vers le but adverse,
## chantent contre les supporters d'en face (qui finissent par aller s'asseoir)
## et chantent devant la tribune adverse pour la conquérir.
## Victoire : un but, ou la tribune adverse conquise.

const DUREE := 180.0
const RUSH := 60.0                 # dernière minute : la Ferveur remonte deux fois plus vite
const FERVEUR_MAX := 10.0
const FERVEUR_DEPART := 5.0
const FERVEUR_PAR_SECONDE := 0.5
const TAILLE_MAIN := 4
const TRIBUNE_PV := 1200.0
const BUT_DEMI_HAUTEUR := 110.0
const BALLON_RAYON := 22.0
const BALLON_FROTTEMENT := 1.1
const BALLON_VITESSE_MAX := 260.0

## Les cartes. type : unite, batiment ou effet. Les PV sont l'« entrain » :
## un supporter sans entrain va s'asseoir. famille : FANZZY qui le représente.
const CARTES := {
	"tambour": {"nom": "Petit Tambour", "cout": 2, "type": "unite", "famille": "perc", "nb": 1,
		"pv": 70.0, "vitesse": 125.0, "portee": 55.0, "puissance": 12.0, "cadence": 0.6, "poussee": 1.0,
		"texte": "Rapide, pousse le ballon"},
	"drapeau": {"nom": "Porte-Drapeau", "cout": 3, "type": "unite", "famille": "fide", "nb": 1,
		"pv": 240.0, "vitesse": 70.0, "portee": 55.0, "puissance": 10.0, "cadence": 1.0, "poussee": 2.4,
		"texte": "Costaud, gros pousseur"},
	"serpentins": {"nom": "Lanceur de serpentins", "cout": 3, "type": "unite", "famille": "tifo", "nb": 1,
		"pv": 75.0, "vitesse": 90.0, "portee": 260.0, "puissance": 14.0, "cadence": 0.9, "poussee": 0.5,
		"texte": "Chante de loin"},
	"chorale": {"nom": "Chorale", "cout": 5, "type": "unite", "famille": "voix", "nb": 3,
		"pv": 55.0, "vitesse": 95.0, "portee": 160.0, "puissance": 8.0, "cadence": 0.7, "poussee": 0.8,
		"texte": "Trois chanteurs d'un coup"},
	"mascotte": {"nom": "Mascotte géante", "cout": 6, "type": "unite", "famille": "depl", "nb": 1,
		"pv": 650.0, "vitesse": 55.0, "portee": 70.0, "puissance": 45.0, "cadence": 1.2, "poussee": 3.0,
		"cible": "tribune", "texte": "Ne vise que la tribune"},
	"canon": {"nom": "Canon à confettis", "cout": 4, "type": "batiment", "famille": "pyro", "nb": 1,
		"pv": 320.0, "vitesse": 0.0, "portee": 320.0, "puissance": 16.0, "cadence": 0.8, "poussee": 0.0,
		"vie": 30.0, "texte": "Défend une zone 30 s"},
	"fumigene": {"nom": "Fumigène", "cout": 3, "type": "effet", "famille": "pyro", "rayon": 160.0,
		"duree": 4.0, "niveau": 2, "texte": "Ralentit et fatigue les adversaires"},
	"ola": {"nom": "Ola", "cout": 2, "type": "effet", "famille": "depl", "rayon": 180.0,
		"duree": 5.0, "niveau": 4, "texte": "Alliés plus rapides et plus forts"},
}
const ORDRE := ["tambour", "drapeau", "serpentins", "chorale", "mascotte", "canon", "fumigene", "ola"]


## Cartes du jeu selon le niveau du fan club (jamais achetées en Jetons).
static func cartes_debloquees(niveau: int) -> Array:
	return ORDRE.filter(func(c): return niveau >= int(CARTES[c].get("niveau", 1)))


static func ferveur(valeur: float, temps: float, delta: float) -> float:
	var vitesse := FERVEUR_PAR_SECONDE * (2.0 if temps >= DUREE - RUSH else 1.0)
	return minf(valeur + vitesse * delta, FERVEUR_MAX)


## Le ballon est-il entré dans un but ? terrain = rectangle du terrain.
## Renvoie 1 si but à droite (pour l'équipe de gauche), -1 à gauche, 0 sinon.
static func but(pos: Vector2, terrain: Rect2) -> int:
	var cy := terrain.get_center().y
	if absf(pos.y - cy) > BUT_DEMI_HAUTEUR:
		return 0
	if pos.x >= terrain.end.x:
		return 1
	if pos.x <= terrain.position.x:
		return -1
	return 0


## Pile de cartes : la main de 4, puis la carte suivante, en cycle.
static func nouvelle_pile(cartes: Array, rng: RandomNumberGenerator) -> Array:
	var p := cartes.duplicate()
	for i in range(p.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = p[i]
		p[i] = p[j]
		p[j] = t
	return p


## Joue la carte n° i de la main : la carte suivante prend sa place dans la
## main, et la carte jouée repart sous la pile.
static func jouer_carte(pile: Array, i: int) -> Array:
	var p := pile.duplicate()
	var c = p[i]
	if p.size() > TAILLE_MAIN:
		p[i] = p[TAILLE_MAIN]
		p.remove_at(TAILLE_MAIN)
		p.append(c)
	return p


## Résultat à la fin du temps (1 / 0 / -1) : la tribune la moins entamée gagne.
static func resultat_temps(tribune_nous: float, tribune_eux: float) -> int:
	if absf(tribune_nous - tribune_eux) < 1.0:
		return 0
	return 1 if tribune_nous > tribune_eux else -1


static func performance(gagne: bool, tribune_eux_pv: float, posees: int) -> float:
	return clampf((0.5 if gagne else 0.0) + (1.0 - tribune_eux_pv / TRIBUNE_PV) * 0.35 + posees / 40.0 * 0.15, 0.0, 1.0)
