class_name FanClub
extends RefCounted
## Règles du fan club, sans écran (testables) : membres, cotisations, buvette,
## atelier d'écharpes. Toutes les fonctions travaillent sur le dictionnaire
## sauvegardé dans Game.club et reçoivent l'heure (secondes Unix) en paramètre.
##
## Les recettes tombent en continu dans la caisse du club, qui garde au plus
## HEURES_CAISSE heures de recettes : il faut passer récolter.
## Plus le club a de membres, plus chaque source rapporte (bonus de taille).

## La caisse garde au plus ce nombre d'heures de recettes.
const HEURES_CAISSE := 8.0
## Chaque membre verse cette cotisation, en Jetons par heure.
## Équilibrage du 17 nov. 2026 (docs/equilibrage.md) : le fan club rapportait
## les trois quarts des Jetons d'un joueur ; il doit compléter les duels.
const COTISATION_HEURE := 0.25
## Bonus de taille : +2 % de recettes par membre au-delà du premier.
const BONUS_PAR_MEMBRE := 0.02
## Places : 3 au niveau 1, 2 de plus par niveau jusqu'au niveau 5, puis 1 par niveau.
const PLACES_DEPART := 3
const PLACES_PAR_NIVEAU := 2
const NIVEAU_PLACES_LENTES := 5
## La buvette rapporte double pendant ces heures après un duel (l'après-match).
const HEURES_APRES_MATCH := 3.0

## Améliorations du local, achetées avec des Jetons (c'est de l'équipement).
## « recette » : Jetons par heure de la buvette, écharpes par heure de l'atelier.
const LOCAL := {
	"buvette": {
		"titre": "Buvette",
		"recette": [0.0, 1.0, 1.5, 2.0, 3.0, 4.0],
		"cout": [40, 100, 220, 450, 900],
	},
	"atelier": {
		"titre": "Atelier d'écharpes",
		"recette": [0.0, 0.5, 0.75, 1.0, 1.25, 1.5],
		"cout": [30, 80, 180, 380, 800],
	},
}

## Paliers de renommée selon le nombre de membres.
const RENOMMEES := [
	[1, "Petit groupe"],
	[5, "Bande de potes"],
	[9, "Club de quartier"],
	[13, "Tribune entière"],
	[18, "Légende du virage"],
]

const COULEURS := ["#1e6bff", "#ff3d7f", "#ffd23f", "#3ddc84", "#8b5cff", "#ff4b4b", "#14112e", "#ffffff", "#ff8a2b", "#2fc6d6"]


static func nouveau(membres: Array, c1: String, c2: String, maintenant: int) -> Dictionary:
	return {
		"cree": true,
		"couleurs": [c1, c2],
		"membres": membres.duplicate(),
		"buvette": 0,
		"atelier": 0,
		"caisse_cotisations": 0.0,
		"caisse_buvette": 0.0,
		"echarpes": 0.0,
		"maj": maintenant,
		"dernier_duel": 0,
		"total_gagne": 0,
		"chant": {},  # composé dans le créateur de chants (ChantClub)
	}


static func vide() -> Dictionary:
	var c := nouveau([], COULEURS[0], COULEURS[7], 0)
	c["cree"] = false
	return c


## Complète une sauvegarde ancienne ou partielle avec les valeurs par défaut.
static func reparer(c: Variant) -> Dictionary:
	var base := vide()
	if not c is Dictionary:
		return base
	for k in base:
		if not c.has(k):
			c[k] = base[k]
	c["buvette"] = clampi(int(c["buvette"]), 0, niveau_max("buvette"))
	c["atelier"] = clampi(int(c["atelier"]), 0, niveau_max("atelier"))
	c["maj"] = int(c["maj"])
	c["dernier_duel"] = int(c["dernier_duel"])
	c["total_gagne"] = int(c["total_gagne"])
	c["chant"] = ChantClub.reparer(c["chant"])
	return c


static func sigle(nom: String) -> String:
	## Initiales du club pour l'écusson (« Ultras du Canal » -> « UC »).
	var mots := []
	for m in nom.strip_edges().split(" ", false):
		if m.length() > 2 or mots.is_empty():
			mots.append(m)
	var s := ""
	for m in mots.slice(0, 3):
		s += m.substr(0, 1).to_upper()
	return s if s != "" else "FC"  # sans_traduction


# ---------------------------------------------------------------- membres

static func places(niveau_club: int) -> int:
	var n := maxi(1, niveau_club)
	return PLACES_DEPART + PLACES_PAR_NIVEAU * (mini(n, NIVEAU_PLACES_LENTES) - 1) + maxi(0, n - NIVEAU_PLACES_LENTES)


static func nb_membres(c: Dictionary) -> int:
	return c["membres"].size()


static func est_membre(c: Dictionary, id: String) -> bool:
	return id in c["membres"]


static func peut_recruter(c: Dictionary, niveau_club: int) -> bool:
	return nb_membres(c) < places(niveau_club)


static func recruter(c: Dictionary, id: String, niveau_club: int, maintenant: int) -> bool:
	if id == "" or est_membre(c, id) or not peut_recruter(c, niveau_club):
		return false
	avancer(c, maintenant)  # les recettes passées gardent l'ancien effectif
	c["membres"].append(id)
	return true


static func renvoyer(c: Dictionary, id: String, maintenant: int) -> bool:
	## Un club garde toujours au moins un membre.
	if not est_membre(c, id) or nb_membres(c) <= 1:
		return false
	avancer(c, maintenant)
	c["membres"].erase(id)
	return true


static func multiplicateur_taille(n: int) -> float:
	return 1.0 + BONUS_PAR_MEMBRE * maxi(0, n - 1)


static func renommee(n: int) -> String:
	var r: String = RENOMMEES[0][1]
	for palier in RENOMMEES:
		if n >= palier[0]:
			r = palier[1]
	return r


# ---------------------------------------------------------------- recettes

static func cotisations_heure(c: Dictionary) -> float:
	var n := nb_membres(c)
	return n * COTISATION_HEURE * multiplicateur_taille(n)


static func buvette_heure(c: Dictionary) -> float:
	## Hors après-match.
	var r: Array = LOCAL["buvette"]["recette"]
	return r[c["buvette"]] * multiplicateur_taille(nb_membres(c))


static func echarpes_heure(c: Dictionary) -> float:
	return LOCAL["atelier"]["recette"][c["atelier"]]


static func stock_max(c: Dictionary) -> int:
	return 6 + 4 * int(c["atelier"])


static func prix_echarpe(c: Dictionary) -> int:
	## Plus le club est connu, plus ses écharpes se vendent cher.
	return 1 + nb_membres(c) / 6


static func apres_match(c: Dictionary, maintenant: int) -> bool:
	var d: int = c["dernier_duel"]
	return d > 0 and maintenant >= d and maintenant - d < int(HEURES_APRES_MATCH * 3600.0)


static func avancer(c: Dictionary, maintenant: int) -> void:
	## Fait tomber dans la caisse les recettes écoulées depuis la dernière mise à jour.
	var debut: int = c["maj"]
	if debut <= 0:
		c["maj"] = maintenant
		return
	if maintenant <= debut:
		return  # horloge reculée : on attend qu'elle rattrape
	var h_reel := float(maintenant - debut) / 3600.0
	var h := minf(h_reel, HEURES_CAISSE)
	var cot: float = c["caisse_cotisations"] + cotisations_heure(c) * h
	# Heures de l'intervalle passées en après-match (buvette x2).
	var boost := 0.0
	var d: int = c["dernier_duel"]
	if d > 0:
		var fin_boost := d + int(HEURES_APRES_MATCH * 3600.0)
		var a := maxi(maintenant - int(h * 3600.0), d)
		var b := mini(maintenant, fin_boost)
		boost = maxf(0.0, float(b - a) / 3600.0)
	var buv: float = c["caisse_buvette"] + buvette_heure(c) * (h + boost)
	# La caisse ne garde que HEURES_CAISSE heures de recettes.
	var plafond_cot := cotisations_heure(c) * HEURES_CAISSE
	var plafond_buv := buvette_heure(c) * (HEURES_CAISSE + HEURES_APRES_MATCH)
	c["caisse_cotisations"] = minf(cot, plafond_cot)
	c["caisse_buvette"] = minf(buv, plafond_buv)
	c["echarpes"] = minf(float(c["echarpes"]) + echarpes_heure(c) * h_reel, float(stock_max(c)))
	c["maj"] = maintenant


static func en_caisse(c: Dictionary) -> int:
	return int(floor(float(c["caisse_cotisations"]) + float(c["caisse_buvette"])))


static func recolter(c: Dictionary, maintenant: int) -> int:
	## Vide la caisse (cotisations + buvette) et renvoie les Jetons gagnés.
	avancer(c, maintenant)
	var total := en_caisse(c)
	# On garde les centimes pour la prochaine récolte.
	var reste: float = float(c["caisse_cotisations"]) + float(c["caisse_buvette"]) - total
	c["caisse_cotisations"] = reste
	c["caisse_buvette"] = 0.0
	c["total_gagne"] = int(c["total_gagne"]) + total
	return total


static func vendre_echarpes(c: Dictionary, maintenant: int) -> int:
	avancer(c, maintenant)
	var n := int(floor(float(c["echarpes"])))
	c["echarpes"] = float(c["echarpes"]) - n
	var gain := n * prix_echarpe(c)
	c["total_gagne"] = int(c["total_gagne"]) + gain
	return gain


static func noter_duel(c: Dictionary, maintenant: int) -> void:
	avancer(c, maintenant)
	c["dernier_duel"] = maintenant


# ---------------------------------------------------------------- local

static func niveau_max(type: String) -> int:
	return LOCAL[type]["cout"].size()


static func cout_amelioration(c: Dictionary, type: String) -> int:
	## -1 quand le niveau maximum est atteint.
	var n: int = c[type]
	var couts: Array = LOCAL[type]["cout"]
	return couts[n] if n < couts.size() else -1


static func ameliorer(c: Dictionary, type: String, maintenant: int) -> void:
	## Le paiement est fait par l'appelant (Game.depenser).
	if cout_amelioration(c, type) < 0:
		return
	avancer(c, maintenant)
	c[type] = int(c[type]) + 1
