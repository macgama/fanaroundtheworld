class_name SoireeMatch
extends RefCounted
## Mode « soir de match » : les règles, sans écran (testables avec --script).
##
## Pendant un vrai match en cours, le joueur s'installe au stade, devant
## l'écran géant, au pub ou à la maison. Le relais publie le score chaque
## minute (live.json) : chaque changement de score est un but vécu en direct.
## À chaque but, le joueur lance une mini-ambiance (chant du club, tifo ou ola)
## qui rapporte des Jetons selon sa réussite. Un but adverse, c'est l'occasion
## de relever la tribune (gains réduits).
##
## Anti-abus :
##  - seuls les buts vus pendant la soirée comptent (le score à l'arrivée sert de point de départ) ;
##  - un but n'est payé qu'une fois (clé = score après le but), au plus MAX_BUTS par match ;
##  - rien sans mini-ambiance jouée (rester devant l'écran sans rien faire ne rapporte pas) ;
##  - buts simulés (démo hors ligne) : aucune récompense.

const AVANT_MATCH := 30 * 60          # on peut s'installer 30 min avant le coup d'envoi
const MAX_BUTS := 6                   # buts récompensés par match
const PRESENCE_PRIME := 30 * 60       # présent au coup de sifflet final depuis 30 min : prime
const GARDE := 3 * 24 * 3600          # on oublie les soirées de plus de 3 jours
const DUREE_MAX_MATCH := 3 * 3600
const STATUTS_EN_JEU := ["LIVE", "HALFTIME"]  # sans_traduction
const STATUTS_FINIS := ["FINISHED", "UNKNOWN"]  # sans_traduction

## Ferveur de la tribune (0 à 100) : elle retombe doucement, les réactions la
## relancent, et elle multiplie les gains d'un but (×0,8 à ×1,2).
const FERVEUR_DEPART := 40.0
const FERVEUR_BAISSE := 0.6           # par seconde de jeu
const FERVEUR_BUT := 25.0
const FERVEUR_BUT_ADVERSE := -15.0

## Réactions entre les buts (touches 1, 2, 3) : le geste des FANZZY et de la foule.
const REACTIONS := [
	{"id": "allez", "titre": "Allez !", "touche": "1", "action": &"encourager", "foule": &"pression", "ferveur": 7.0, "recharge": 3.0, "son": "cri_groupe"},
	{"id": "applaudir", "titre": "Applaudir", "touche": "2", "action": &"applaudir", "foule": &"occasion", "ferveur": 5.0, "recharge": 2.0, "son": "applaudissements"},
	{"id": "echarpe", "titre": "Écharpe", "touche": "3", "action": &"agiter_echarpe", "foule": &"tifo", "ferveur": 9.0, "recharge": 5.0, "son": "hey"},
]

## Les trois mini-ambiances, une par poste de la tribune (mêmes touches que le duel).
const AMBIANCES := [
	{"id": "chant", "titre": "Chant du club", "touche": "ESPACE", "texte": "Chante le début de ton chant en rythme"},
	{"id": "tifo", "titre": "Tifo", "touche": "T", "texte": "Lève les 3 pans du tifo : relâche T dans la zone dorée"},
	{"id": "ola", "titre": "Ola", "touche": "O", "texte": "Enchaîne les flèches pour lancer la vague"},
]
const DUREE_CHOIX := 10.0             # secondes pour choisir la mini-ambiance
const MESURES_CHANT := 4              # le début du chant (4 mesures)
const PANS_TIFO := 3
const FLECHES_OLA := 6
const DUREE_OLA := 6.0


# ------------------------------------------------------------------ état sauvegardé

static func vide() -> Dictionary:
	return {}


static func reparer(d: Variant) -> Dictionary:
	if not d is Dictionary:
		return {}
	var res: Dictionary = {}
	for id in d:
		var e: Variant = d[id]
		if e is Dictionary:
			res[str(id)] = {
				"debut": int(e.get("debut", 0)),
				"buts": (e.get("buts", []) as Array).map(func(x): return str(x)) if e.get("buts") is Array else [],
				"fil": e.get("fil", []) if e.get("fil") is Array else [],
				"prime": bool(e.get("prime", false)),
			}
	return res


## L'état de la soirée de ce match (créé au besoin).
static func etat(soirees: Dictionary, match_id: String, maintenant: int) -> Dictionary:
	if not soirees.has(match_id):
		soirees[match_id] = {"debut": maintenant, "buts": [], "fil": [], "prime": false}
	return soirees[match_id]


static func nettoyer(soirees: Dictionary, maintenant: int) -> void:
	for id in soirees.keys():
		if maintenant - int(soirees[id].get("debut", 0)) > GARDE:
			soirees.erase(id)


# ------------------------------------------------------------------ le match

## Score (domicile, extérieur) ou (-1, -1) si le match n'a pas de score.
static func score_de(m: Dictionary) -> Vector2i:
	var sc: Variant = m.get("score", {}).get("current")
	if not sc is Dictionary:
		return Vector2i(-1, -1)
	return Vector2i(int(sc.get("home", 0)), int(sc.get("away", 0)))


## Peut-on s'installer pour ce match ? En direct, ou coup d'envoi dans moins de 30 min.
static func ouverte(m: Dictionary, maintenant: int) -> bool:
	var s := str(m.get("status", ""))
	if s in STATUTS_EN_JEU:
		return true
	if s != "SCHEDULED":  # sans_traduction
		return false
	var k := str(m.get("kickoff_utc", ""))
	var t := int(Time.get_unix_time_from_datetime_string(k.left(19))) if k.length() >= 19 else 0
	return t > 0 and t - maintenant <= AVANT_MATCH and maintenant - t < DUREE_MAX_MATCH


static func finie(m: Dictionary) -> bool:
	return str(m.get("status", "")) in STATUTS_FINIS


## Les buts entre deux lectures du score : [{cote: "home"|"away", annule: bool}].
## Plusieurs buts d'un coup (relais en retard) donnent plusieurs entrées ;
## un score qui baisse, c'est un but annulé (arbitrage vidéo).
static func detecter(avant: Vector2i, apres: Vector2i) -> Array:
	var res: Array = []
	if avant.x < 0 or apres.x < 0:
		return res
	for i in maxi(0, apres.x - avant.x):
		res.append({"cote": "home", "annule": false})
	for i in maxi(0, apres.y - avant.y):
		res.append({"cote": "away", "annule": false})
	if apres.x < avant.x:
		res.append({"cote": "home", "annule": true})
	if apres.y < avant.y:
		res.append({"cote": "away", "annule": true})
	return res


## Clé d'un but : le score juste après lui. « 2-1 » ne se paie qu'une fois,
## même si un but annulé puis redonné fait revenir le même score.
static func cle_but(score: Vector2i) -> String:
	return "%d-%d" % [score.x, score.y]


static func peut_recompenser(e: Dictionary, cle: String) -> bool:
	var buts: Array = e.get("buts", [])
	return not cle in buts and buts.size() < MAX_BUTS


## Minute à afficher : celle du relais, avancée du temps passé depuis sa
## dernière lecture (au plus 3 minutes, le relais peut être en retard).
static func minute(m: Dictionary, secondes_depuis_maj: float) -> int:
	var mi: Variant = m.get("minute")
	if mi == null:
		return -1
	if str(m.get("status", "")) != "LIVE":  # sans_traduction
		return int(mi)
	return int(mi) + clampi(int(secondes_depuis_maj / 60.0), 0, 3)


# ------------------------------------------------------------------ ferveur et gains

static func ferveur_apres(ferveur: float, delta: float, mi_temps: bool) -> float:
	if mi_temps:
		return ferveur
	return clampf(ferveur - FERVEUR_BAISSE * delta, 0.0, 100.0)


static func mult_ferveur(ferveur: float) -> float:
	return 0.8 + 0.4 * clampf(ferveur, 0.0, 100.0) / 100.0


## Gains d'une mini-ambiance. `perf` de 0 à 1 ; `gain_mode` = gain du mode de
## suivi (stade ×1,5 … maison ×0,6). Un but adverse rapporte deux fois moins.
static func recompense(perf: float, pour_nous: bool, gain_mode: float, ferveur: float) -> Dictionary:
	perf = clampf(perf, 0.0, 1.0)
	var moitie := 1.0 if pour_nous else 0.5
	var base := (6.0 + 10.0 * perf) if pour_nous else (3.0 + 5.0 * perf)
	return {
		"jetons": int(round(base * gain_mode * mult_ferveur(ferveur))),
		"xp": int(round((10.0 + 20.0 * perf) * moitie)),
		"xp_pass": int(round((20.0 + 30.0 * perf) * moitie)),
	}


## Prime « soirée complète » : présent au coup de sifflet final depuis au moins 30 min.
static func prime_fin(gain_mode: float) -> Dictionary:
	return {"jetons": int(round(10.0 * gain_mode)), "xp": 30, "xp_pass": 60}


static func etoiles(perf: float) -> int:
	if perf >= 0.85:
		return 3
	if perf >= 0.55:
		return 2
	if perf >= 0.2:
		return 1
	return 0


# ------------------------------------------------------------------ réussite des mini-ambiances

static func perf_chant(parfaits: int, biens: int, total: int) -> float:
	if total <= 0:
		return 0.0
	return clampf((parfaits + 0.6 * biens) / float(total), 0.0, 1.0)


## Tifo : chaque pan est jugé sur l'écart entre le relâchement et le centre de
## la zone dorée (0 = pile au centre ; 0,3 ou plus = raté).
static func perf_tifo(ecarts: Array) -> float:
	if ecarts.is_empty():
		return 0.0
	var s := 0.0
	for e in ecarts:
		s += clampf(1.0 - absf(float(e)) / 0.3, 0.0, 1.0)
	return s / float(PANS_TIFO)


## Ola : flèches justes, moins les erreurs, avec un petit bonus de vitesse.
static func perf_ola(justes: int, erreurs: int, temps_restant: float) -> float:
	var p := (justes - 0.5 * erreurs) / float(FLECHES_OLA)
	if justes >= FLECHES_OLA:
		p += 0.15 * clampf(temps_restant / DUREE_OLA, 0.0, 1.0)
	return clampf(p, 0.0, 1.0)
