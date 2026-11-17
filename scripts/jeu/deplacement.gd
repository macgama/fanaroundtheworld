class_name Deplacement
extends RefCounted
## Déplacements à l'extérieur, sans affichage (testable).
##
## Pour aller voir un match au stade, le fan club organise le voyage ensemble :
##  - le convoi = les membres du fan club (au moins les 3 FANZZY de la tribune) ;
##    plus il y a de monde, plus la cagnotte du club allège le prix du trajet ;
##  - on choisit un transport (car, train, ou avion pour les longs voyages)
##    et un itinéraire (direct, économique, ou balade avec une étape) ;
##  - en route, des événements demandent un choix : ils font monter (ou
##    descendre) la ferveur du convoi et peuvent coûter du temps ;
##  - certains choix demandent un FANZZY d'une famille précise dans le convoi ;
##  - à l'arrivée, la ferveur donne une prime (Jetons, XP du PASS) et un bonus
##    sur les Jetons des duels de ce match, le jour même.
## Ton familial : on chante, on aide, on échange des écharpes. Jamais de bagarre.

const TRANSPORTS := {
	"car": {
		"titre": "Car du fan club", "texte": "Pas cher, de l'ambiance à bord, mais lent",
		"vitesse": 75.0, "prix": 0.8, "max_km": 2500.0, "min_km": 0.0, "ferveur": 10, "evenements": 1,
	},
	"train": {
		"titre": "Train des supporters", "texte": "Rapide et confortable",
		"vitesse": 170.0, "prix": 1.25, "max_km": 2200.0, "min_km": 0.0, "ferveur": 5, "evenements": 0,
	},
	"avion": {
		"titre": "Vol charter", "texte": "Pour les très longs voyages",
		"vitesse": 750.0, "prix": 1.5, "max_km": 100000.0, "min_km": 800.0, "ferveur": 0, "evenements": 0,
	},
}
const ORDRE_TRANSPORTS := ["car", "train", "avion"]

## « lenteur » allonge la durée, « detour » la distance parcourue (et le prix).
const ITINERAIRES := {
	"direct": {
		"titres": {"car": "Autoroute directe", "train": "Train direct", "avion": "Vol direct"},
		"texte": "Le plus rapide", "detour": 1.0, "prix": 1.0, "lenteur": 1.0, "evenements": 1,
	},
	"eco": {
		"titres": {"car": "Petites routes", "train": "Trains régionaux"},
		"texte": "Moins cher, plus long, plus d'imprévus", "detour": 1.12, "prix": 0.6, "lenteur": 1.45, "evenements": 2,
	},
	"balade": {
		"titres": {"car": "Route panoramique", "train": "Ligne touristique"},
		"texte": "Une étape en chemin, une carte postale à la clé", "detour": 1.3, "prix": 1.1, "lenteur": 1.2, "evenements": 2,
	},
}
const ORDRE_ITINERAIRES := ["direct", "eco", "balade"]

## Retard toléré (minutes) : au-delà, on arrive pile au coup d'envoi.
const MARGE_RETARD := 60
const MALUS_RETARD := 10
## Ferveur de départ.
const FERVEUR_BASE := 20
const FERVEUR_PAR_MEMBRE := 3
const FERVEUR_MEMBRES_MAX := 24
const FERVEUR_EXTERIEUR := 8      # on soutient l'équipe qui joue à l'extérieur
const FERVEUR_PAR_DEPL := 5       # FANZZY de la famille Déplacement dans le convoi
const FERVEUR_DEPL_MAX := 15
## Cagnotte du club : -3 % par membre au-delà des 3 fondateurs, au plus -30 %.
const REDUCTION_PAR_MEMBRE := 0.03
const REDUCTION_MAX := 0.3
const PRIX_MIN := 3
## Prime d'arrivée.
const PRIME_CARTE_POSTALE := 10
## Bonus sur les Jetons des duels du match : ×1 à ×1,2 selon la ferveur.
const BONUS_DUEL_MAX := 0.2

## Événements en route. « pour » : transports concernés ; « itin » : seulement
## sur ces itinéraires. Un choix peut demander une famille de FANZZY dans le
## convoi, ou dépendre de la chance (« chance » + « rate »).
const EVENEMENTS := [
	{"id": "aire", "pour": ["car"], "titre": "Pause sur l'aire d'autoroute",
		"texte": "Le car s'arrête, tout le monde descend se dégourdir les jambes.",
		"choix": [
			{"texte": "Concours de chants sur le parking", "ferveur": 12, "retard": 10, "res": "Les routiers applaudissent !"},
			{"texte": "Pause rapide, on repart", "ferveur": 3, "retard": 0, "res": "Pas de temps perdu."},
			{"texte": "Le capo lance un chant que toute l'aire reprend", "famille": "voix", "ferveur": 20, "retard": 10, "res": "Même la caissière chante avec vous !"},
		]},
	{"id": "bouchon", "pour": ["car"], "titre": "Bouchon géant",
		"texte": "Plus rien n'avance sur la route. Il faut s'occuper !",
		"choix": [
			{"texte": "Une ola dans le car pour passer le temps", "ferveur": 10, "retard": 30, "res": "La voiture d'à côté fait la ola aussi."},
			{"texte": "Le chauffeur tente un raccourci", "chance": 0.5, "ferveur": 6, "retard": 5, "res": "Bien vu, chauffeur !",
				"rate": {"ferveur": -4, "retard": 40, "res": "Raté : on a fait le tour du village…"}},
			{"texte": "Concert de tambours au rythme des clignotants", "famille": "perc", "ferveur": 18, "retard": 30, "res": "Les klaxons suivent le tempo !"},
		]},
	{"id": "crevaison", "pour": ["car"], "titre": "Un pneu crevé !",
		"texte": "Pssssh… le car s'arrête sur le bas-côté.",
		"choix": [
			{"texte": "Tout le monde aide à changer la roue", "ferveur": 12, "retard": 25, "res": "Travail d'équipe, roue changée !"},
			{"texte": "On attend la dépanneuse", "ferveur": -3, "retard": 45, "res": "Ça a été long…"},
			{"texte": "Les fidèles ont toujours une roue de secours", "famille": "fide", "ferveur": 10, "retard": 10, "res": "Prévoyants, ces anciens !"},
		]},
	{"id": "mascotte", "pour": ["car"], "titre": "Une mascotte fait du stop",
		"texte": "Au bord de la route, une grosse mascotte en peluche lève le pouce.",
		"choix": [
			{"texte": "On la fait monter !", "ferveur": 14, "retard": 5, "res": "Elle danse dans l'allée du car."},
			{"texte": "Un petit coucou par la fenêtre", "ferveur": 3, "retard": 0, "res": "Elle vous fait coucou aussi."},
		]},
	{"id": "decor", "pour": ["car", "train"], "titre": "Décorer le convoi",
		"texte": "Il reste des drapeaux et des écharpes dans les sacs.",
		"choix": [
			{"texte": "Drapeaux à toutes les fenêtres", "ferveur": 8, "retard": 0, "res": "On vous voit de loin !"},
			{"texte": "Les vieilles écharpes de collection sortent du sac", "famille": "depl", "ferveur": 16, "retard": 0, "res": "Des écharpes de tous les stades visités !"},
			{"texte": "Une banderole géante au nom du club", "famille": "tifo", "ferveur": 15, "retard": 5, "res": "Le club en lettres géantes."},
		]},
	{"id": "adverses", "pour": ["car", "train"], "titre": "Les supporters d'en face !",
		"texte": "Un groupe de fans de l'autre équipe fait la même pause que vous.",
		"choix": [
			{"texte": "Échanger des écharpes, entre fans", "ferveur": 10, "retard": 10, "res": "Une nouvelle amitié entre tribunes."},
			{"texte": "Battle de chants, dans la bonne humeur", "ferveur": 15, "retard": 15, "res": "Match nul aux points, rendez-vous au stade !"},
			{"texte": "Grande photo commune derrière une banderole", "famille": "tifo", "ferveur": 20, "retard": 15, "res": "La photo fait le tour des réseaux."},
		]},
	{"id": "radio", "pour": ["car", "train", "avion"], "titre": "La radio locale vous appelle",
		"texte": "Une émission veut parler aux supporters qui font le déplacement.",
		"choix": [
			{"texte": "Le président du club répond aux questions", "ferveur": 8, "retard": 0, "res": "Belle interview !"},
			{"texte": "Chanter en direct à l'antenne", "famille": "voix", "ferveur": 16, "jetons": 8, "retard": 0, "res": "La radio vous offre une petite prime !"},
		]},
	{"id": "averse", "pour": ["car", "train"], "titre": "Grosse averse",
		"texte": "Il pleut des cordes au moment de changer de quai.",
		"choix": [
			{"texte": "Chanter sous la pluie", "ferveur": 10, "retard": 10, "res": "Trempés mais heureux."},
			{"texte": "Attendre à l'abri", "ferveur": 0, "retard": 20, "res": "Au sec, au moins."},
			{"texte": "Les bâches du tifo font un parapluie géant", "famille": "tifo", "ferveur": 16, "retard": 5, "res": "Tout le monde à l'abri, en couleurs !"},
		]},
	{"id": "controleur", "pour": ["train"], "titre": "Contrôle des billets",
		"texte": "Le contrôleur passe… et c'est son anniversaire !",
		"choix": [
			{"texte": "Lui chanter « Joyeux anniversaire »", "ferveur": 12, "retard": 0, "res": "Il en a les larmes aux yeux."},
			{"texte": "Montrer les billets sagement", "ferveur": 2, "retard": 0, "res": "Tout est en règle."},
		]},
	{"id": "wagon_bar", "pour": ["train"], "titre": "Le wagon-bar",
		"texte": "Le serveur propose un quiz foot pour animer le voyage.",
		"choix": [
			{"texte": "Participer au quiz", "chance": 0.6, "ferveur": 8, "jetons": 12, "retard": 0, "res": "Vous gagnez le quiz !",
				"rate": {"ferveur": 3, "retard": 0, "res": "Perdu de peu, mais quelle rigolade."}},
			{"texte": "Chocolats chauds pour tout le monde", "ferveur": 9, "retard": 0, "res": "Ça réchauffe les voix."},
		]},
	{"id": "fanfare", "pour": ["train"], "titre": "Une fanfare en gare",
		"texte": "Sur le quai, une fanfare joue en attendant le train.",
		"choix": [
			{"texte": "Se joindre à la fanfare", "ferveur": 14, "retard": 10, "res": "Toute la gare danse."},
			{"texte": "Applaudir depuis la fenêtre", "ferveur": 5, "retard": 0, "res": "Ils vous saluent avec les trompettes."},
			{"texte": "Les tambours du club prennent la tête du cortège", "famille": "perc", "ferveur": 22, "retard": 10, "res": "Un concert inoubliable !"},
		]},
	{"id": "arret", "pour": ["train"], "titre": "Arrêt en pleine campagne",
		"texte": "Le train s'arrête : des vaches traversent la voie !",
		"choix": [
			{"texte": "Partie de cartes géante dans le wagon", "ferveur": 8, "retard": 25, "res": "Le temps passe vite."},
			{"texte": "Rythme sur les porte-bagages", "famille": "perc", "ferveur": 15, "retard": 25, "res": "Même les vaches écoutent."},
			{"texte": "Faire une ola pour les vaches", "ferveur": 11, "retard": 25, "res": "Meuh ! (elles ont aimé)"},
		]},
	{"id": "correspondance", "pour": ["train"], "itin": ["eco"], "titre": "Correspondance serrée",
		"texte": "Le train suivant part dans deux minutes, à l'autre bout de la gare.",
		"choix": [
			{"texte": "Sprint sur le quai, drapeaux au vent", "chance": 0.6, "ferveur": 12, "retard": 0, "res": "Montés de justesse !",
				"rate": {"ferveur": -4, "retard": 45, "res": "Les portes se ferment sous votre nez…"}},
			{"texte": "Prendre le suivant tranquillement", "ferveur": 0, "retard": 40, "res": "Pas de stress."},
			{"texte": "Un habitué des déplacements connaît le passage", "famille": "depl", "ferveur": 10, "retard": 0, "res": "Par ici, raccourci !"},
		]},
	{"id": "fete_village", "pour": ["car", "train"], "itin": ["eco", "balade"], "titre": "Fête de village",
		"texte": "Un village en fête, des guirlandes partout, on entend de la musique.",
		"choix": [
			{"texte": "S'arrêter danser", "ferveur": 15, "retard": 30, "res": "Les habitants vous adoptent."},
			{"texte": "Saluer en passant", "ferveur": 5, "retard": 0, "res": "Coucou le village !"},
			{"texte": "Les anciens du club vendent des écharpes", "famille": "fide", "ferveur": 12, "jetons": 10, "retard": 20, "res": "Toutes vendues !"},
		]},
	{"id": "turbulences", "pour": ["avion"], "titre": "Turbulences",
		"texte": "L'avion secoue un peu. Certains ne sont pas rassurés.",
		"choix": [
			{"texte": "Une ola assise pour détendre tout le monde", "ferveur": 10, "retard": 0, "res": "Les passagers rigolent."},
			{"texte": "Rester sage, ceinture attachée", "ferveur": 4, "retard": 0, "res": "Ça se calme vite."},
		]},
	{"id": "equipage", "pour": ["avion"], "titre": "Annonce du commandant",
		"texte": "Le commandant souhaite bonne chance aux supporters à bord.",
		"choix": [
			{"texte": "Applaudir l'équipage", "ferveur": 8, "retard": 0, "res": "L'équipage applaudit aussi."},
			{"texte": "Chant tout doux dans l'allée", "famille": "voix", "ferveur": 16, "retard": 0, "res": "Tout l'avion fredonne."},
		]},
]

## Événement de l'étape (itinéraire « balade ») : %s = nom de l'étape.
const EVENEMENT_ETAPE := {"id": "etape", "titre": "Étape : %s",
	"texte": "Le convoi s'arrête pour visiter. Que fait-on ?",
	"choix": [
		{"texte": "Photo de groupe pour la carte postale", "ferveur": 10, "jetons": PRIME_CARTE_POSTALE, "retard": 15, "res": "La carte postale part au local du club."},
		{"texte": "Goûter les spécialités du coin", "ferveur": 14, "retard": 30, "res": "Tout le monde repart le ventre plein."},
		{"texte": "Les déplaceurs tamponnent leur carnet de route", "famille": "depl", "ferveur": 18, "retard": 15, "res": "Une étape de plus dans la légende du club."},
	]}


## Coût de base d'un trajet, en Jetons (même barème que l'ancien trajet direct).
static func cout_base(distance_km: float) -> int:
	if distance_km < 30.0:
		return 0
	return clampi(int(round(distance_km / 120.0)) + 5, 5, 80)


static func transport_possible(transport: String, distance_km: float) -> bool:
	var t: Dictionary = TRANSPORTS.get(transport, {})
	return not t.is_empty() and distance_km <= float(t["max_km"]) and distance_km >= float(t["min_km"])


## Transports proposés pour cette distance (au moins un).
static func transports(distance_km: float) -> Array:
	var res: Array = []
	for t in ORDRE_TRANSPORTS:
		if transport_possible(t, distance_km):
			res.append(t)
	if res.is_empty():
		res.append("avion")
	return res


## Itinéraires proposés pour un transport (l'avion ne fait que du direct).
static func itineraires(transport: String) -> Array:
	var res: Array = []
	for i in ORDRE_ITINERAIRES:
		if ITINERAIRES[i]["titres"].has(transport):
			res.append(i)
	return res


static func titre_itineraire(itin: String, transport: String) -> String:
	return str(ITINERAIRES.get(itin, {}).get("titres", {}).get(transport, ""))


## Réduction de la cagnotte du club (0 à REDUCTION_MAX).
static func reduction(nb_membres: int) -> float:
	return clampf((nb_membres - 3) * REDUCTION_PAR_MEMBRE, 0.0, REDUCTION_MAX)


static func distance_parcourue(distance_km: float, itin: String) -> float:
	return distance_km * float(ITINERAIRES.get(itin, ITINERAIRES["direct"])["detour"])


## Prix du trajet pour le joueur (sans le billet du match).
static func cout(distance_km: float, transport: String, itin: String, nb_membres: int) -> int:
	if distance_km < 30.0:
		return 0
	var t: Dictionary = TRANSPORTS[transport]
	var i: Dictionary = ITINERAIRES[itin]
	var brut := cout_base(distance_parcourue(distance_km, itin)) * float(t["prix"]) * float(i["prix"])
	return maxi(PRIX_MIN, int(round(brut * (1.0 - reduction(nb_membres)))))


## Trajet le moins cher possible (pour l'afficher sur la fiche du match).
static func cout_min(distance_km: float, nb_membres: int) -> int:
	if distance_km < 30.0:
		return 0
	var m := -1
	for t in transports(distance_km):
		for i in itineraires(t):
			var c := cout(distance_km, t, i, nb_membres)
			if m < 0 or c < m:
				m = c
	return m


## Durée prévue, en minutes (sans les retards des événements).
static func duree(distance_km: float, transport: String, itin: String) -> int:
	var t: Dictionary = TRANSPORTS[transport]
	var i: Dictionary = ITINERAIRES[itin]
	var h := distance_parcourue(distance_km, itin) / float(t["vitesse"]) * float(i["lenteur"])
	if transport == "avion":
		h += 1.5  # embarquement
	return maxi(15, int(round(h * 60.0 / 5.0)) * 5)


static func duree_texte(minutes: int) -> String:
	if minutes < 60:
		return "%d min" % minutes
	if minutes % 60 == 0:
		return "%d h" % (minutes / 60)
	return "%d h %02d" % [minutes / 60, minutes % 60]


static func nb_evenements(transport: String, itin: String) -> int:
	return int(ITINERAIRES[itin]["evenements"]) + int(TRANSPORTS[transport]["evenements"]) + (1 if itin == "balade" else 0)


## Ferveur au départ (0-100). `familles` : la famille de chaque FANZZY du convoi.
static func ferveur_depart(transport: String, familles: Array, exterieur: bool) -> int:
	var f := FERVEUR_BASE + int(TRANSPORTS[transport]["ferveur"])
	f += mini(familles.size() * FERVEUR_PAR_MEMBRE, FERVEUR_MEMBRES_MAX)
	f += mini(familles.count("depl") * FERVEUR_PAR_DEPL, FERVEUR_DEPL_MAX)
	if exterieur:
		f += FERVEUR_EXTERIEUR
	return clampi(f, 0, 100)


## Tire les événements du voyage, toujours les mêmes pour une même graine.
## L'étape (balade) se place au milieu ; `etape_nom` est le nom de la ville.
static func tirer(graine: int, transport: String, itin: String, etape_nom := "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var pool: Array = []
	for e in EVENEMENTS:
		if transport in e["pour"] and (not e.has("itin") or itin in e["itin"]):
			pool.append(e)
	# mélange stable
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var n := nb_evenements(transport, itin) - (1 if itin == "balade" else 0)
	var res: Array = pool.slice(0, mini(n, pool.size()))
	if itin == "balade":
		var e: Dictionary = EVENEMENT_ETAPE.duplicate(true)
		e["etape"] = etape_nom
		res.insert(res.size() / 2, e)
	return res


static func titre_evenement(e: Dictionary) -> String:
	if e.get("id", "") == "etape":
		return Trad.t(str(e["titre"])) % str(e.get("etape", ""))
	return Trad.t(str(e["titre"]))


## Le choix est-il possible avec ce convoi ?
static func choix_possible(c: Dictionary, familles: Array) -> bool:
	return not c.has("famille") or str(c["famille"]) in familles


## Résultat d'un choix : {ferveur, jetons, retard, res, reussi}. `tirage` entre 0 et 1.
static func resultat(c: Dictionary, tirage: float) -> Dictionary:
	var src: Dictionary = c
	var reussi := true
	if c.has("chance") and tirage >= float(c["chance"]):
		src = c["rate"]
		reussi = false
	return {
		"ferveur": int(src.get("ferveur", 0)), "jetons": int(src.get("jetons", 0)),
		"retard": int(src.get("retard", 0)), "res": str(src.get("res", "")), "reussi": reussi,
	}


## État du voyage en cours.
static func nouvel_etat(ferveur: int) -> Dictionary:
	return {"ferveur": clampi(ferveur, 0, 100), "retard": 0, "jetons": 0, "journal": []}


static func appliquer(etat: Dictionary, e: Dictionary, r: Dictionary) -> void:
	etat["ferveur"] = clampi(int(etat["ferveur"]) + int(r["ferveur"]), 0, 100)
	etat["retard"] = int(etat["retard"]) + int(r["retard"])
	etat["jetons"] = int(etat["jetons"]) + int(r["jetons"])
	etat["journal"].append({"titre": titre_evenement(e), "res": r["res"], "ferveur": r["ferveur"]})


## Bilan de l'arrivée : ferveur finale, à l'heure ou pas, primes et bonus de duel.
static func bilan(etat: Dictionary) -> Dictionary:
	var ferveur := int(etat["ferveur"])
	var a_l_heure := int(etat["retard"]) <= MARGE_RETARD
	if not a_l_heure:
		ferveur = maxi(0, ferveur - MALUS_RETARD)
	return {
		"ferveur": ferveur,
		"a_l_heure": a_l_heure,
		"retard": int(etat["retard"]),
		"jetons": int(etat["jetons"]) + int(round(ferveur / 4.0)),
		"xp_pass": ferveur * 2,
		"xp": 20 + ferveur / 5,
		"mult": multiplicateur(ferveur),
	}


## Bonus des Jetons de duel selon la ferveur : ×1,00 à ×1,20.
static func multiplicateur(ferveur: int) -> float:
	return 1.0 + snappedf(clampf(ferveur / 100.0, 0.0, 1.0) * BONUS_DUEL_MAX, 0.01)


## Choisit l'étape d'une balade parmi des lieux candidats [{nom, pos (lon, lat)}] :
## le plus proche du milieu du trajet, sans trop s'écarter. {} si aucun ne va.
static func etape(depart: Vector2, arrivee: Vector2, candidats: Array) -> Dictionary:
	var d := depart.distance_to(arrivee)
	if d < 0.05:
		return {}
	var milieu := (depart + arrivee) / 2.0
	var meilleur: Dictionary = {}
	var score_min := INF
	for c in candidats:
		var p: Vector2 = c["pos"]
		var t := (p - depart).dot(arrivee - depart) / (d * d)
		if t < 0.2 or t > 0.8:
			continue
		var ecart := p.distance_to(depart.lerp(arrivee, t))
		if ecart > d * 0.4 or ecart < d * 0.04:
			continue
		var s := p.distance_to(milieu) + ecart * 0.5
		if s < score_min:
			score_min = s
			meilleur = c
	return meilleur


## Points de passage (lon, lat) dessinés sur la carte pour un itinéraire.
static func trace(depart: Vector2, arrivee: Vector2, itin: String, etape_pos := Vector2.INF) -> PackedVector2Array:
	var pts := PackedVector2Array([depart])
	if itin == "balade" and etape_pos != Vector2.INF:
		pts.append(etape_pos)
	elif itin == "eco":
		# un petit crochet par les routes de campagne
		var dir := arrivee - depart
		var normale := Vector2(-dir.y, dir.x) * 0.12
		pts.append(depart.lerp(arrivee, 0.35) + normale)
		pts.append(depart.lerp(arrivee, 0.7) - normale * 0.6)
	pts.append(arrivee)
	return pts
