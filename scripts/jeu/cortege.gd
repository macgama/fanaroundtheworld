class_name Cortege
extends RefCounted
## Le cortège : la marche à pied du fan club jusqu'au stade, juste avant le
## match (règles sans écran, testées par tests/test_cortege.gd).
##
## Il complète le déplacement sans le doubler : le déplacement, c'est le trajet
## de ville à ville (car, train, avion) ; le cortège, c'est le dernier
## kilomètre, dans les rues autour du stade.
##  - À domicile : départ du local du club.
##  - À l'extérieur : départ de la gare, du parking des cars ou de la navette
##    de l'aéroport ; la ferveur du déplacement continue dans le cortège.
##
## 3 arrêts (parfois 4, quand un FANZZY marche avec vous), 2 ou 3 choix chacun.
## Les choix jouent sur la ferveur, les nouveaux supporters du kop, le temps
## avant le coup d'envoi et l'humeur de la tribune d'en face. Entre deux arrêts,
## une petite marche en rythme (en option) ajoute de la ferveur.
##
## Jamais de Jetons perdus, jamais de skin. Le cortège compte une fois par vrai match.

## Minutes avant le coup d'envoi au départ du cortège, et minutes de marche.
const MINUTES := 55
const MARCHE := 25
## Arrivée après l'échauffement : ferveur perdue, et pas de bonus de départ.
const MALUS_RETARD := 8
## Ferveur au départ sans déplacement le jour même.
const FERVEUR_BASE := 25
const FERVEUR_PAR_MEMBRE := 3
const FERVEUR_MEMBRES_MAX := 24
const FERVEUR_PAR_PALIER := 2     # palier de renommée du kop
## Chance qu'un FANZZY rejoigne la marche (s'il reste quelqu'un à rencontrer).
const CHANCE_RENCONTRE := 0.6
## Marche en rythme : 8 pas par passage, ferveur +1 par pas parfait, +0,5 par pas bien.
const PAS_RYTHME := 8
const RYTHME_FERVEUR_MAX := 6
## La tribune d'en face, chambrée pendant le cortège, pousse plus fort en duel.
const CHAMBRAGE_PRESSION := 1.15

const DEPARTS := {
	"domicile": "le local du club",
	"car": "le parking des cars",
	"train": "la gare",
	"avion": "la navette de l'aéroport",
}

## Arrêts du cortège. « pour » : domicile, exterieur (les deux par défaut).
## Effets d'un choix : ferveur, recrues (supporters du kop, avant
## bouche-à-oreille), minutes (négatif : on gagne du temps), chambre (la
## tribune d'en face sera remontée), rencontre (un FANZZY à convaincre au local).
const EVENEMENTS := [
	{"id": "adverses", "titre": "Les supporters d'en face",
		"texte": "Un groupe aux couleurs adverses arrive au même carrefour que vous.",
		"choix": [
			{"texte": "Échange d'écharpes et photo souvenir", "ferveur": 8, "recrues": 6, "minutes": 5, "res": "Une belle photo qui fera le tour du quartier."},
			{"texte": "Chambrage en chanson", "ferveur": 16, "recrues": 3, "minutes": 0, "chambre": true, "res": "Ils répondent… et ils seront remontés en tribune !"},
			{"texte": "Petit détour pour laisser passer", "ferveur": 0, "minutes": 10, "res": "Tout se passe dans le calme, mais c'est un peu long."},
		]},
	{"id": "carrefour", "titre": "Le grand carrefour",
		"texte": "Deux chemins mènent au stade.",
		"choix": [
			{"texte": "La grande avenue, devant tout le monde", "ferveur": 6, "recrues": 12, "minutes": 12, "res": "Les passants s'arrêtent pour vous filmer."},
			{"texte": "Le raccourci par les petites rues", "ferveur": 2, "recrues": 2, "minutes": -5, "res": "Cinq minutes de gagnées !"},
			{"texte": "Le chemin des anciens, connu des fidèles", "famille": "fide", "ferveur": 10, "recrues": 6, "minutes": -5, "res": "Plus court ET plus beau : merci les anciens !"},
		]},
	{"id": "balcon", "titre": "Une mamie au balcon",
		"texte": "Au troisième étage, une dame agite un torchon aux couleurs du club !",
		"choix": [
			{"texte": "Une chanson rien que pour elle", "ferveur": 10, "recrues": 5, "minutes": 5, "res": "Tout l'immeuble sort aux fenêtres."},
			{"texte": "Un grand salut et on avance", "ferveur": 4, "minutes": 0, "res": "Elle vous envoie des bisous."},
			{"texte": "Les voix entonnent une sérénade", "famille": "voix", "ferveur": 16, "recrues": 10, "minutes": 5, "res": "Elle descend vous rejoindre, en chaussons !"},
		]},
	{"id": "cafe", "pour": ["domicile"], "titre": "Le café du coin",
		"texte": "Le patron sort sur le trottoir : chocolat chaud offert au cortège !",
		"choix": [
			{"texte": "On s'arrête trinquer (au chocolat)", "ferveur": 10, "recrues": 4, "minutes": 10, "res": "Moustaches de chocolat pour tout le monde."},
			{"texte": "Merci, mais on file", "ferveur": 2, "minutes": 0, "res": "Il vous souhaite bonne chance."},
			{"texte": "On l'invite à marcher avec nous", "chance": 0.5, "ferveur": 8, "recrues": 12, "minutes": 5, "res": "Il ferme boutique et vous suit avec ses habitués !",
				"rate": {"ferveur": 3, "minutes": 5, "res": "Il ne peut pas laisser sa terrasse… la prochaine fois !"}},
		]},
	{"id": "averse", "titre": "Averse soudaine",
		"texte": "Le ciel se vide d'un coup sur le cortège.",
		"choix": [
			{"texte": "On chante sous la pluie", "ferveur": 12, "recrues": 2, "minutes": 0, "res": "Trempés, mais heureux !"},
			{"texte": "Abri sous l'arrêt de bus", "ferveur": -2, "minutes": 10, "res": "Au sec, mais l'ambiance retombe un peu."},
			{"texte": "La grande bâche du tifo devient un parapluie", "famille": "tifo", "ferveur": 16, "recrues": 4, "minutes": 5, "res": "Le plus grand parapluie de la ville !"},
		]},
	{"id": "travaux", "titre": "Rue en travaux",
		"texte": "Des barrières bloquent la moitié de la rue.",
		"choix": [
			{"texte": "On contourne par le parc", "ferveur": 4, "minutes": 10, "res": "Une jolie balade entre les arbres."},
			{"texte": "On passe en file indienne", "ferveur": 0, "minutes": 5, "res": "Un peu serrés, mais ça passe."},
			{"texte": "Les tambours font danser les ouvriers", "famille": "perc", "ferveur": 14, "recrues": 6, "minutes": 5, "res": "Les marteaux-piqueurs suivent le tempo !"},
		]},
	{"id": "tele", "titre": "La télé locale",
		"texte": "Une équipe de télé filme l'arrivée des supporters.",
		"choix": [
			{"texte": "Le capo répond au micro", "ferveur": 8, "recrues": 15, "minutes": 5, "res": "Vu par toute la ville ce soir !"},
			{"texte": "Tout le cortège fait coucou à la caméra", "ferveur": 10, "recrues": 8, "minutes": 0, "res": "Des centaines de mains à l'écran."},
			{"texte": "Pluie de confettis pour la caméra", "famille": "pyro", "ferveur": 14, "recrues": 12, "minutes": 5, "res": "L'image passera en boucle !"},
		]},
	{"id": "enfants", "titre": "L'école de foot du quartier",
		"texte": "Des enfants en maillot regardent passer le cortège, les yeux grands ouverts.",
		"choix": [
			{"texte": "On leur offre des écharpes du club", "ferveur": 10, "recrues": 14, "minutes": 5, "res": "Les futurs du virage !"},
			{"texte": "On leur apprend le refrain", "ferveur": 12, "recrues": 10, "minutes": 10, "res": "Ils le chantent mieux que vous."},
			{"texte": "Tape-m'en cinq pour tout le monde", "ferveur": 6, "recrues": 4, "minutes": 0, "res": "Des dizaines de mains tapées !"},
		]},
	{"id": "fanfare", "pour": ["exterieur"], "titre": "Une fanfare de la ville",
		"texte": "Une fanfare répète sur la place, juste sur votre chemin.",
		"choix": [
			{"texte": "On joue un air ensemble", "ferveur": 14, "recrues": 6, "minutes": 10, "res": "Les habitants applaudissent les visiteurs."},
			{"texte": "On l'écoute en marchant", "ferveur": 6, "minutes": 0, "res": "Une belle musique pour avancer."},
			{"texte": "Les tambours rejoignent la fanfare", "famille": "perc", "ferveur": 20, "recrues": 8, "minutes": 5, "res": "Un concert que la ville n'oubliera pas !"},
		]},
	{"id": "habitants", "pour": ["exterieur"], "titre": "Les habitants vous regardent",
		"texte": "Ici, c'est vous les visiteurs. Faites bonne impression !",
		"choix": [
			{"texte": "Saluer et remercier la ville", "ferveur": 6, "recrues": 8, "minutes": 0, "res": "Applaudissements polis… et sincères."},
			{"texte": "Chanter fort pour qu'on vous entende au stade", "ferveur": 14, "recrues": 2, "minutes": 0, "chambre": true, "res": "Le stade sait que vous êtes là !"},
			{"texte": "Les déplaceurs offrent des écharpes d'échange", "famille": "depl", "ferveur": 14, "recrues": 10, "minutes": 5, "res": "De nouveaux amis dans chaque ville."},
		]},
	{"id": "stewards", "titre": "Les stewards du stade",
		"texte": "Au point de rendez-vous, ils vérifient que tout le cortège reste groupé.",
		"choix": [
			{"texte": "On se range bien, deux par deux", "ferveur": 4, "minutes": -5, "res": "Merci ! On vous fait passer en premier."},
			{"texte": "On leur fait chanter le refrain", "chance": 0.5, "ferveur": 12, "recrues": 3, "minutes": 5, "res": "Même les stewards chantent !",
				"rate": {"ferveur": 2, "minutes": 10, "res": "Ils préfèrent rester sérieux… et vérifient tout deux fois."}},
			{"texte": "Les fidèles saluent les stewards qu'ils connaissent", "famille": "fide", "ferveur": 10, "minutes": -5, "res": "Des années qu'ils se connaissent !"},
		]},
	{"id": "mascotte", "pour": ["domicile"], "titre": "La mascotte du club",
		"texte": "Elle attend le cortège devant la boulangerie.",
		"choix": [
			{"texte": "Elle prend la tête du cortège !", "ferveur": 14, "recrues": 8, "minutes": 5, "res": "Elle danse en tête, le quartier adore."},
			{"texte": "Une photo avec elle et on repart", "ferveur": 6, "recrues": 4, "minutes": 5, "res": "La photo du jour !"},
		]},
	{"id": "banderole", "titre": "La banderole se déchire !",
		"texte": "Un coup de vent, et la grande banderole se fend en deux.",
		"choix": [
			{"texte": "On la répare avec du scotch", "ferveur": 4, "minutes": 10, "res": "Comme neuve… ou presque."},
			{"texte": "On la porte en deux morceaux", "ferveur": 6, "minutes": 0, "res": "Deux moitiés de banderole : tout le monde rigole."},
			{"texte": "Les tifosi en peignent une nouvelle en marchant", "famille": "tifo", "ferveur": 14, "recrues": 4, "minutes": 5, "res": "Encore plus belle que l'ancienne !"},
		]},
]

## Arrêt spécial : un FANZZY marche avec le cortège (« %s » : son nom).
const EVENEMENT_RENCONTRE := {"id": "rencontre", "titre": "Un FANZZY vous suit !",
	"texte": "%s marche à côté du cortège depuis deux rues et connaît tous vos chants.",
	"choix": [
		{"texte": "L'inviter au local après le match", "rencontre": true, "ferveur": 4, "recrues": 1, "minutes": 0, "res": "Rendez-vous au local : à toi de le convaincre !"},
		{"texte": "Lui prêter une écharpe pour la marche", "rencontre": true, "ferveur": 8, "recrues": 2, "minutes": 5, "res": "Il marche avec vous jusqu'au stade. Il passera au local !"},
	]}


static func lieu(depuis_deplacement: bool) -> String:
	return "exterieur" if depuis_deplacement else "domicile"


## D'où part le cortège : « domicile », ou le transport du déplacement.
static func depart_texte(transport: String) -> String:
	return Trad.t(str(DEPARTS.get(transport, DEPARTS["domicile"])))


## Ferveur au départ : celle du déplacement du jour s'il y en a eu un pour ce
## match, sinon la base + 3 par FANZZY + 2 par palier de renommée du kop.
static func ferveur_depart(nb_fanzzy: int, palier_kop: int, ferveur_deplacement := -1) -> int:
	if ferveur_deplacement >= 0:
		return clampi(ferveur_deplacement, 0, 100)
	var f := FERVEUR_BASE + mini(nb_fanzzy * FERVEUR_PAR_MEMBRE, FERVEUR_MEMBRES_MAX) + palier_kop * FERVEUR_PAR_PALIER
	return clampi(f, 0, 100)


## Les arrêts du cortège, toujours les mêmes pour une même graine. `nom_rencontre`
## non vide : un FANZZY peut marcher avec vous (arrêt en plus, au milieu).
static func tirer(graine: int, lieu_cortege: String, nom_rencontre := "") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var pool: Array = []
	for e in EVENEMENTS:
		if not e.has("pour") or lieu_cortege in e["pour"]:
			pool.append(e)
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	var res: Array = pool.slice(0, 3)
	if nom_rencontre != "" and rng.randf() < CHANCE_RENCONTRE:
		var e: Dictionary = EVENEMENT_RENCONTRE.duplicate(true)
		e["nom"] = nom_rencontre
		res.insert(1 + rng.randi_range(0, 1), e)
	return res


static func texte_evenement(e: Dictionary) -> String:
	if e.get("id", "") == "rencontre":
		return Trad.t(str(e["texte"])) % str(e.get("nom", ""))
	return Trad.t(str(e["texte"]))


static func choix_possible(c: Dictionary, familles: Array) -> bool:
	return not c.has("famille") or str(c["famille"]) in familles


## Résultat d'un choix. `tirage` entre 0 et 1 (pour les choix à « chance »).
static func resultat(c: Dictionary, tirage: float) -> Dictionary:
	var src: Dictionary = c
	var reussi := true
	if c.has("chance") and tirage >= float(c["chance"]):
		src = c["rate"]
		reussi = false
	return {
		"ferveur": int(src.get("ferveur", 0)), "recrues": int(src.get("recrues", 0)),
		"minutes": int(src.get("minutes", 0)), "chambre": bool(src.get("chambre", false)),
		"rencontre": bool(src.get("rencontre", false)), "res": str(src.get("res", "")), "reussi": reussi,
	}


static func nouvel_etat(ferveur: int) -> Dictionary:
	return {"ferveur": clampi(ferveur, 0, 100), "recrues": 0, "minutes": MARCHE, "chambre": false, "rencontre": false, "journal": []}


static func appliquer(etat: Dictionary, e: Dictionary, r: Dictionary) -> void:
	etat["ferveur"] = clampi(int(etat["ferveur"]) + int(r["ferveur"]), 0, 100)
	etat["recrues"] = int(etat["recrues"]) + maxi(0, int(r["recrues"]))
	etat["minutes"] = maxi(0, int(etat["minutes"]) + int(r["minutes"]))
	etat["chambre"] = bool(etat["chambre"]) or bool(r["chambre"])
	etat["rencontre"] = bool(etat["rencontre"]) or bool(r["rencontre"])
	etat["journal"].append({"id": str(e.get("id", "")), "res": r["res"], "ferveur": r["ferveur"]})


## Marche en rythme entre deux arrêts : ferveur et quelques passants de plus.
static func rythme(parfaits: int, biens: int) -> Dictionary:
	parfaits = clampi(parfaits, 0, PAS_RYTHME)
	biens = clampi(biens, 0, PAS_RYTHME - parfaits)
	return {"ferveur": mini(RYTHME_FERVEUR_MAX, int(floor(parfaits + biens * 0.5))), "recrues": parfaits / 2}


static func appliquer_rythme(etat: Dictionary, r: Dictionary) -> void:
	etat["ferveur"] = clampi(int(etat["ferveur"]) + int(r["ferveur"]), 0, 100)
	etat["recrues"] = int(etat["recrues"]) + int(r["recrues"])


## Minutes qui restent avant le coup d'envoi (négatif : en retard).
static func marge(etat: Dictionary) -> int:
	return MINUTES - int(etat["minutes"])


## Bilan à l'arrivée au stade. `kop` : taille du kop avant le cortège
## (bouche-à-oreille sur les nouveaux supporters).
static func bilan(etat: Dictionary, kop: int) -> Dictionary:
	var a_l_heure := marge(etat) >= 0
	var ferveur := int(etat["ferveur"])
	if not a_l_heure:
		ferveur = maxi(0, ferveur - MALUS_RETARD)
	return {
		"ferveur": ferveur,
		"a_l_heure": a_l_heure,
		"recrues": Kop.recrues(float(etat["recrues"]), kop),
		"bonus": bonus_jauge(ferveur) if a_l_heure else 0,
		"chambre": bool(etat["chambre"]),
		"rencontre": bool(etat["rencontre"]),
		"jetons": int(round(ferveur / 10.0)),
		"xp_pass": ferveur / 2,
		"xp": 10 + ferveur / 10,
	}


## Points de jauge d'ambiance au départ du duel : 0 à 10 selon la ferveur.
static func bonus_jauge(ferveur: int) -> int:
	return clampi(int(round(ferveur / 10.0)), 0, 10)
