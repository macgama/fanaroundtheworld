class_name AreneRegles
extends RefCounted
## Règles du mode Arène (3 contre 3, vue de dessus), sans affichage :
## utilisées par scenes/arene/arene.gd et testées par tests/test_modes.gd.
##
## Ton familial : on lance des ballons de confettis. Un FANZZY couvert de
## confettis (jauge « propreté » vide) retourne à son banc se secouer.

const DUREE := 120.0
const BANDEROLE_MAX := 100.0
const VITESSE_BANDEROLE := 3.5       # % par seconde avec un seul FANZZY au mégaphone
const BONUS_PAR_FANZZY := 1.0        # % par seconde par FANZZY en plus
const RAYON_MEGAPHONE := 130.0
const TEMPS_BANC := 3.0
const PV := 100.0
const VITESSE := 330.0
const MUNITIONS := 3
const RECHARGE_MUNITION := 0.9       # secondes pour récupérer un ballon
const DEGAT_BALLON := 22.0
const PORTEE_BALLON := 640.0
const VITESSE_BALLON := 900.0
const CHARGE_SUPER_PAR_TOUCHE := 0.25
const NIVEAU_ROULADE := 3
const NIVEAU_TIR_CHARGE := 5

## Le super de chaque famille (le « geste » du FANZZY dans l'arène).
const SUPERS := {
	"voix": {"nom": "Onde de chant", "texte": "repousse les adversaires devant toi"},
	"perc": {"nom": "Roulement de tambour", "texte": "étourdit tout le monde autour de toi"},
	"tifo": {"nom": "Grand tifo", "texte": "déploie un mur qui arrête les ballons"},
	"fide": {"nom": "Écharpe de soutien", "texte": "nettoie les confettis de tes alliés proches"},
	"pyro": {"nom": "Fumigène coloré", "texte": "nuage qui ralentit les adversaires"},
	"depl": {"nom": "Sprint du déplacement", "texte": "tu cours et lances plus vite 3 s"},
}


## Actions disponibles selon le niveau du fan club (jamais achetées en Jetons).
static func actions_debloquees(niveau: int) -> Array:
	var a := ["lancer", "super"]
	if niveau >= NIVEAU_ROULADE:
		a.append("roulade")
	if niveau >= NIVEAU_TIR_CHARGE:
		a.append("tir_charge")
	return a


## Nouvelle valeur de la banderole d'une équipe. Le mégaphone ne compte que
## s'il n'est pas disputé (aucun adversaire dans la zone).
static func remplir(valeur: float, nous: int, eux: int, delta: float) -> float:
	if nous <= 0 or eux > 0:
		return valeur
	var vitesse := VITESSE_BANDEROLE + BONUS_PAR_FANZZY * (nous - 1)
	return minf(valeur + vitesse * delta, BANDEROLE_MAX)


## Résultat : 1 = victoire, 0 = égalité, -1 = défaite.
static func resultat(banderole_nous: float, banderole_eux: float, touches_nous: int, touches_eux: int) -> int:
	if absf(banderole_nous - banderole_eux) > 0.01:
		return 1 if banderole_nous > banderole_eux else -1
	if touches_nous != touches_eux:
		return 1 if touches_nous > touches_eux else -1
	return 0


## Performance 0..1 pour les gains.
static func performance(banderole_nous: float, touches: int, nettoyes: int) -> float:
	return clampf(banderole_nous / BANDEROLE_MAX * 0.6 + touches / 40.0 * 0.25 + nettoyes / 8.0 * 0.15, 0.0, 1.0)
