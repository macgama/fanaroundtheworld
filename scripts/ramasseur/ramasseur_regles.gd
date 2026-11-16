class_name RamasseurRegles
extends RefCounted
## Règles du petit boulot « ramasseur de balles », sans affichage (testables).
##
## Une partie dure 60 secondes au bord du terrain. Les ballons sortent du
## terrain les uns après les autres ; une ombre montre où chacun va tomber.
## Le joueur court le long de la touche pour l'attraper avant qu'il touche le
## sol, puis le relance au joueur qui attend la remise en jeu.
## Ballon attrapé = 1 Jeton. Relancé vite = +1. Le « ballon du match »
## (doré, plus rapide) vaut +2. +1 toutes les 5 prises d'affilée.
## À 30 s, le match s'emballe : les ballons volent moins longtemps.
## Les positions sont des fractions de la ligne de touche (0 = coin gauche,
## 1 = coin droit) ; l'écran les convertit en pixels.
## Au-delà de PARTIES_PLEIN_TARIF parties dans la journée, la paye est
## divisée par deux (le petit boulot complète les duels sans les remplacer).

const DUREE := 60.0
const DEBUT_RUSH := 30.0

const VITESSE := 0.55            # fractions de touche par seconde (course du ramasseur)
const RAYON_PRISE := 0.055       # distance max (fraction de touche) pour attraper le ballon
const BORD := 0.04               # les ballons ne tombent pas dans les coins extrêmes
const ECART_MIN := 0.12          # il faut toujours bouger un peu
const MARGE_COURSE := 0.8        # part du vol pendant laquelle on doit pouvoir arriver

const VOL_DEBUT := 2.6           # durée de vol des 3 premiers ballons (pour se mettre en jambes)
const VOL_CALME := 2.0
const VOL_RUSH := 1.45
const VOL_DORE := 0.85           # le ballon du match vole plus vite
const CHANCE_DORE := 0.12

const REMISE_RAPIDE := 1.2       # secondes pour relancer et toucher le bonus
const PAYE_PRISE := 1
const PAYE_REMISE := 1
const PAYE_DORE := 2
const SERIE_BONUS := 5
const XP_PAR_BALLE := 2
const PARTIES_PLEIN_TARIF := 3

var rng := RandomNumberGenerator.new()


func _init(graine := -1) -> void:
	if graine >= 0:
		rng.seed = graine
	else:
		rng.randomize()


static func en_rush(temps: float) -> bool:
	return temps >= DEBUT_RUSH


## Nouveau ballon pour le `numero`-ième tir (0 = le premier), le ramasseur
## étant à la position `x_joueur`. Rend {"x": point de chute, "vol": durée
## de vol en secondes, "dore": bool, "rush": bool}. Le point de chute est
## toujours atteignable à pleine course.
func tir(numero: int, rush: bool, x_joueur: float) -> Dictionary:
	var dore := numero >= 3 and rng.randf() < CHANCE_DORE
	var vol := VOL_DEBUT if numero < 3 else (VOL_RUSH if rush else VOL_CALME)
	if dore:
		vol *= VOL_DORE
	var portee := VITESSE * vol * MARGE_COURSE
	x_joueur = clampf(x_joueur, 0.0, 1.0)
	var x := x_joueur
	for i in 20:
		var dx := rng.randf_range(ECART_MIN, portee)
		var signe := -1.0 if rng.randf() < 0.5 else 1.0
		x = x_joueur + dx * signe
		if x < BORD or x > 1.0 - BORD:
			x = x_joueur - dx * signe
		if x >= BORD and x <= 1.0 - BORD:
			break
	x = clampf(x, BORD, 1.0 - BORD)
	return {"x": x, "vol": vol, "dore": dore, "rush": rush}


## Le ramasseur en `x_joueur` attrape-t-il le ballon qui tombe en `x_chute` ?
static func attrape(x_joueur: float, x_chute: float) -> bool:
	return absf(x_joueur - x_chute) <= RAYON_PRISE


## Jetons pour un ballon attrapé. `serie` : prises d'affilée, celle-ci comprise.
static func paye_prise(dore: bool, serie: int) -> Dictionary:
	var bonus := 1 if serie > 0 and serie % SERIE_BONUS == 0 else 0
	var d := PAYE_DORE if dore else 0
	return {"prise": PAYE_PRISE, "dore": d, "bonus": bonus, "total": PAYE_PRISE + d + bonus}


## Jetons pour la remise en jeu, selon le temps passé ballon en main.
static func paye_remise(attente: float) -> int:
	return PAYE_REMISE if attente <= REMISE_RAPIDE else 0


## Paye de la partie entière, selon le nombre de parties déjà faites aujourd'hui.
static func paye_finale(brut: int, parties_du_jour: int) -> int:
	if parties_du_jour >= PARTIES_PLEIN_TARIF:
		return int(ceil(brut / 2.0))
	return brut
