class_name Souvenirs
extends RefCounted
## Boutique souvenirs des stades et vitrine du club, sans écran (testable).
##
## Chaque stade tamponné a sa boutique : cinq souvenirs aux couleurs du club
## qui reçoit (fanion, écharpe, ballon dédicacé, maillot rétro, maquette du
## stade). Sur place (le jour où le fan club est au stade), ils sont au prix de
## la boutique ; ensuite, par correspondance, ils coûtent PRIX_CORRESPONDANCE fois
## plus cher. Ils s'achètent avec des Jetons : ce sont des objets de la vitrine du
## club, pas des skins de FANZZY, et ils ne changent rien en duel.
## Séries de la vitrine (primes en Jetons, réclamées une fois, comme le carnet) :
## un stade complet, et des paliers de souvenirs au total.
##
## État sauvegardé dans Game.collection["souvenirs"] : {cle_stade: {type: date}}.

const TYPES := [
	{"id": "fanion", "nom": "Fanion", "prix": 15},
	{"id": "echarpe", "nom": "Écharpe du club", "prix": 25},
	{"id": "ballon", "nom": "Ballon dédicacé", "prix": 40},
	{"id": "maillot", "nom": "Maillot rétro", "prix": 60},
	{"id": "maquette", "nom": "Maquette du stade", "prix": 120},
]
const PRIX_CORRESPONDANCE := 1.5
## Prime d'un stade dont on a les cinq souvenirs.
const PRIME_STADE_COMPLET := 40
## [nombre de souvenirs, prime en Jetons]
const PALIERS := [[5, 20], [15, 40], [30, 80], [60, 150], [120, 300], [250, 600]]


static func type_par_id(id: String) -> Dictionary:
	for t in TYPES:
		if t["id"] == id:
			return t
	return {}


static func ids() -> Array:
	return TYPES.map(func(t): return t["id"])


## Prix d'un souvenir, sur place ou par correspondance.
static func prix(type: String, sur_place: bool) -> int:
	var p := int(type_par_id(type).get("prix", 0))
	return p if sur_place else int(ceil(p * PRIX_CORRESPONDANCE / 5.0)) * 5


static func du_stade(c: Dictionary, cle: String) -> Dictionary:
	var s: Variant = c.get("souvenirs", {}).get(cle, {})
	return s if s is Dictionary else {}


static func a(c: Dictionary, cle: String, type: String) -> bool:
	return du_stade(c, cle).has(type)


static func nombre(c: Dictionary) -> int:
	var n := 0
	for cle in c.get("souvenirs", {}):
		n += du_stade(c, str(cle)).size()
	return n


static func stade_complet(c: Dictionary, cle: String) -> bool:
	return du_stade(c, cle).size() >= TYPES.size()


## Peut-on acheter ce souvenir ? Il faut avoir tamponné le stade.
static func achetable(c: Dictionary, tampons: Dictionary, cle: String, type: String) -> bool:
	return tampons.has(cle) and not type_par_id(type).is_empty() and not a(c, cle, type)


## Note l'achat (le paiement est fait par l'appelant, Game.acheter_souvenir).
static func ajouter(c: Dictionary, cle: String, type: String, jour: String) -> void:
	if not c.get("souvenirs") is Dictionary:
		c["souvenirs"] = {}
	if not c["souvenirs"].get(cle) is Dictionary:
		c["souvenirs"][cle] = {}
	c["souvenirs"][cle][type] = jour


## Séries de la vitrine, au format de Collection (lignes avec prime).
## Un stade complet par stade commencé, puis les paliers (atteints et le suivant).
static func series(c: Dictionary, tampons: Dictionary) -> Array:
	var res: Array = []
	var n := nombre(c)
	for p in PALIERS:
		var seuil: int = p[0]
		res.append(Collection._ligne(c, "souvenirs:%d" % seuil, Trad.t("%d souvenirs") % seuil,
			"Remplis la vitrine du club", mini(n, seuil), seuil, p[1], "souvenirs", "#ff8a2b"))
		if n < seuil:
			break
	for cle in c.get("souvenirs", {}):
		var k := str(cle)
		var fait := du_stade(c, k).size()
		if fait == 0:
			continue
		var nom := str(tampons.get(k, {}).get("nom", k)) if tampons.get(k) is Dictionary else k
		res.append(Collection._ligne(c, "vitrine:" + k, nom, "Les cinq souvenirs du stade",
			fait, TYPES.size(), PRIME_STADE_COMPLET, "vitrine", "#ffd23f"))
	return res
