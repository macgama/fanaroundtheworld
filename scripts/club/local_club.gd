class_name LocalClub
extends RefCounted
## Agrandir le local du fan club, sans écran (testable).
##
## Le local a une salle principale ; on peut construire la salle des chants,
## la salle des trophées et le parking du car (deux niveaux chacune), puis les
## décorer. Tout s'achète en Jetons et c'est du décor : aucun effet sur les
## duels, les gains ou le PASS. La salle des trophées montre la vraie collection
## (tampons, souvenirs, succès). Dessin : scripts/ui/local_dessin.gd.
##
## État sauvegardé dans Game.local : {"salles": {id: niveau}, "deco": {id: jour}}.

const SALLES := [
	{"id": "principale", "nom": "Salle principale", "texte": "Là où tout a commencé.", "prix": []},
	{"id": "chants", "nom": "Salle des chants", "texte": "Pour répéter les chants du club.", "prix": [300, 2000]},
	{"id": "trophees", "nom": "Salle des trophées", "texte": "Tampons, souvenirs et succès exposés.", "prix": [400, 2500]},
	{"id": "parking", "nom": "Parking du car", "texte": "Le car du fan club a enfin sa place.", "prix": [500, 3000]},
]
const NIVEAU_MAX := 2

## Déco : une fois chacune, dans une salle déjà construite.
const DECO := [
	{"id": "guirlande", "salle": "principale", "nom": "Guirlande aux couleurs", "prix": 100},
	{"id": "poster", "salle": "principale", "nom": "Poster géant", "prix": 150},
	{"id": "canape", "salle": "principale", "nom": "Canapé du club", "prix": 250},
	{"id": "babyfoot", "salle": "principale", "nom": "Baby-foot", "prix": 350},
	{"id": "ecran", "salle": "principale", "nom": "Écran géant", "prix": 600},
	{"id": "partitions", "salle": "chants", "nom": "Partitions encadrées", "prix": 150},
	{"id": "micros", "salle": "chants", "nom": "Micros et enceintes", "prix": 450},
	{"id": "piano", "salle": "chants", "nom": "Piano", "prix": 900},
	{"id": "mur_tampons", "salle": "trophees", "nom": "Mur des tampons", "prix": 300},
	{"id": "vitrine", "salle": "trophees", "nom": "Vitrine éclairée", "prix": 500},
	{"id": "coupe", "salle": "trophees", "nom": "Coupe en or", "prix": 1200},
	{"id": "fanions_car", "salle": "parking", "nom": "Fanions sur le car", "prix": 200},
	{"id": "barbecue", "salle": "parking", "nom": "Barbecue d'avant-match", "prix": 400},
	{"id": "car_club", "salle": "parking", "nom": "Car aux couleurs du club", "prix": 1500},
]


static func vide() -> Dictionary:
	return {"salles": {"principale": 1}, "deco": {}}


static func reparer(v: Variant) -> Dictionary:
	var res := vide()
	if not v is Dictionary:
		return res
	var s: Variant = v.get("salles", {})
	if s is Dictionary:
		for id in s:
			if not salle(str(id)).is_empty() and str(id) != "principale":
				var n := clampi(int(s[id]), 0, NIVEAU_MAX)
				if n > 0:
					res["salles"][str(id)] = n
	var d: Variant = v.get("deco", {})
	if d is Dictionary:
		for id in d:
			var o := deco(str(id))
			if not o.is_empty() and niveau(res, o["salle"]) > 0:
				res["deco"][str(id)] = str(d[id])
	return res


static func salle(id: String) -> Dictionary:
	for s in SALLES:
		if s["id"] == id:
			return s
	return {}


static func deco(id: String) -> Dictionary:
	for o in DECO:
		if o["id"] == id:
			return o
	return {}


static func deco_de(salle_id: String) -> Array:
	return DECO.filter(func(o): return o["salle"] == salle_id)


static func niveau(etat: Dictionary, salle_id: String) -> int:
	return int(etat.get("salles", {}).get(salle_id, 0))


static func a(etat: Dictionary, deco_id: String) -> bool:
	return etat.get("deco", {}).has(deco_id)


## Prix pour construire / agrandir la salle, -1 si impossible (inconnue ou au maximum).
static func prix_salle(etat: Dictionary, salle_id: String) -> int:
	var s := salle(salle_id)
	var n := niveau(etat, salle_id)
	if s.is_empty() or n >= NIVEAU_MAX or n >= s["prix"].size() + (1 if salle_id == "principale" else 0):
		return -1
	return int(s["prix"][n])


## Prix d'une déco, -1 si déjà achetée, inconnue ou si sa salle n'est pas construite.
static func prix_deco(etat: Dictionary, deco_id: String) -> int:
	var o := deco(deco_id)
	if o.is_empty() or a(etat, deco_id) or niveau(etat, o["salle"]) == 0:
		return -1
	return int(o["prix"])


## Note les achats (le paiement est fait par Game).
static func construire(etat: Dictionary, salle_id: String) -> void:
	if prix_salle(etat, salle_id) >= 0:
		etat["salles"][salle_id] = niveau(etat, salle_id) + 1


static func poser(etat: Dictionary, deco_id: String, jour: String) -> void:
	if prix_deco(etat, deco_id) >= 0:
		etat["deco"][deco_id] = jour


## Jetons déjà mis dans le local (pour l'équilibrage).
static func valeur(etat: Dictionary) -> int:
	var t := 0
	for s in SALLES:
		for i in mini(niveau(etat, s["id"]), s["prix"].size()):
			t += int(s["prix"][i])
	for id in etat.get("deco", {}):
		t += int(deco(str(id)).get("prix", 0))
	return t


## Tout est construit et décoré ?
static func complet(etat: Dictionary) -> bool:
	for s in SALLES:
		if prix_salle(etat, s["id"]) >= 0:
			return false
	for o in DECO:
		if not a(etat, o["id"]):
			return false
	return true
