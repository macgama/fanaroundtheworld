class_name Kop
extends RefCounted
## Le kop : les supporters anonymes qui suivent le fan club (la foule de la
## tribune, aux couleurs du club). Les FANZZY sont le noyau du club ; le kop,
## c'est tous ceux qui chantent derrière eux.
##
## Le compteur est gardé dans Game.club["kop"]. Il ne baisse JAMAIS : un duel
## perdu ou un mauvais choix rapporte simplement moins de nouveaux supporters.
## Plus le kop est grand, plus il attire de monde (bouche-à-oreille).
##
## Effets : la renommée du club, le remplissage de la tribune en duel, un petit
## bonus de départ sur la jauge d'ambiance, et un peu de cotisations.

## Supporters d'un club tout neuf (les copains des fondateurs).
const DEPART := 20
## Supporters de plus par FANZZY au-delà des 3 fondateurs (sauvegardes d'avant le kop).
const PAR_MEMBRE_ANCIEN := 15

## Paliers de renommée : [supporters, nom, bonus de jauge au départ du duel].
const PALIERS := [
	[0, "Petit groupe", 0],
	[50, "Bande de potes", 1],
	[200, "Club de quartier", 2],
	[1000, "Tribune entière", 4],
	[3000, "Virage plein", 6],
	[10000, "Légende du virage", 8],
]

## Nouveaux supporters après un duel (avant bouche-à-oreille), selon où l'on suit le match.
const DUEL := 2
const DUEL_GAGNE := 3
const MODE := {"stade": 1.5, "ecran": 1.0, "pub": 1.0, "maison": 0.5}
## Déplacement : un supporter de plus par tranche de 10 de ferveur à l'arrivée.
const FERVEUR_PAR_RECRUE := 10
## Bouche-à-oreille : ×(1 + kop / BOUCHE_A_OREILLE).
const BOUCHE_A_OREILLE := 1000.0
## Tribune du duel : remplie à 30 % au départ, pleine à partir de PLEIN supporters.
const REMPLISSAGE_MIN := 0.3
const PLEIN := 3000.0
## Cotisations du kop : COTISATION × racine(kop) Jetons par heure (2,5 J/h à 10 000).
const COTISATION := 0.025


static func valeur(c: Dictionary) -> int:
	return maxi(0, int(c.get("kop", DEPART)))


## Valeur de départ pour une sauvegarde qui n'avait pas encore de kop.
static func depuis_membres(nb_membres: int) -> int:
	return DEPART + PAR_MEMBRE_ANCIEN * maxi(0, nb_membres - 3)


static func facteur(kop: int) -> float:
	return 1.0 + maxi(0, kop) / BOUCHE_A_OREILLE


## Nouveaux supporters pour une base donnée, bouche-à-oreille compris.
static func recrues(base: float, kop: int) -> int:
	if base <= 0.0:
		return 0
	return maxi(1, int(round(base * facteur(kop))))


## Ajoute des supporters (jamais de retrait). Rend le nombre ajouté.
static func ajouter(c: Dictionary, n: int) -> int:
	n = maxi(0, n)
	c["kop"] = valeur(c) + n
	return n


static func base_duel(gagne: bool, part: float, mode_suivi: String) -> float:
	return (DUEL + (DUEL_GAGNE if gagne else 0)) * float(MODE.get(mode_suivi, 1.0)) * clampf(part, 0.0, 1.0)


static func base_deplacement(ferveur: int) -> float:
	return float(maxi(0, ferveur) / FERVEUR_PAR_RECRUE)


static func palier(kop: int) -> int:
	var i := 0
	for k in PALIERS.size():
		if kop >= int(PALIERS[k][0]):
			i = k
	return i


static func renommee(kop: int) -> String:
	return str(PALIERS[palier(kop)][1])


## Prochain palier : [supporters, nom], ou [] au dernier.
static func prochain(kop: int) -> Array:
	var i := palier(kop) + 1
	return [] if i >= PALIERS.size() else [int(PALIERS[i][0]), str(PALIERS[i][1])]


## Bonus de départ sur la jauge d'ambiance (points sur 100).
static func bonus_jauge(kop: int) -> int:
	return int(PALIERS[palier(kop)][2])


## Part des places de notre tribune occupées en duel (0,3 à 1).
static func remplissage(kop: int) -> float:
	var r := log(1.0 + maxi(0, kop) / 20.0) / log(1.0 + PLEIN / 20.0)
	return clampf(REMPLISSAGE_MIN + (1.0 - REMPLISSAGE_MIN) * r, REMPLISSAGE_MIN, 1.0)


static func cotisations_heure(kop: int) -> float:
	return COTISATION * sqrt(float(maxi(0, kop)))


## « 12 345 » : les grands nombres avec une espace entre les milliers.
static func texte(n: int) -> String:
	var s := str(absi(n))
	var res := ""
	while s.length() > 3:
		res = " " + s.substr(s.length() - 3) + res
		s = s.substr(0, s.length() - 3)
	return s + res
