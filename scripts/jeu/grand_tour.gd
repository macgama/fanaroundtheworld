class_name GrandTour
extends RefCounted
## Grand Tour : un voyage organisé dans un pays, plusieurs stades d'affilée
## (visite guidée des stades, sans match), payé en Jetons. Sans écran (testable).
##
## - « Week-end des stades » : 3 étapes ; « Grande boucle » : 5 étapes.
## - Les étapes sont des stades PAS ENCORE tamponnés du pays : on part du plus
##   proche du fan club, puis on va toujours au plus proche (itinéraire court).
##   Il en faut au moins 2 pour qu'un Grand Tour soit proposé.
## - Prix : forfait + visite guidée par étape + trajets (même barème que le trajet
##   le moins cher d'un match au stade, cagnotte du club comprise).
## - Chaque étape donne son tampon et ouvre la boutique souvenirs au prix sur place
##   ce jour-là. Pas d'XP de PASS ni de mission : le PASS se gagne en jouant,
##   pas en Jetons (les primes de collection en Jetons, elles, comptent).
## - Un Grand Tour par jour.

const TAILLES := {
	"weekend": {"titre": "Week-end des stades", "etapes": 3},
	"boucle": {"titre": "Grande boucle", "etapes": 5},
}
const ORDRE_TAILLES := ["weekend", "boucle"]
const FORFAIT := 60
const PAR_ETAPE := 70
const MIN_ETAPES := 2


## Stades d'un pays : clubs [{id}] -> [{cle, id, nom, club, pos (lon, lat)}].
static func stades_pays(pays: String, clubs: Array) -> Array:
	var res: Array = []
	var vus := {}
	for e in clubs:
		var id := str(e.get("id", "")) if e is Dictionary else str(e)
		if id == "" or vus.has(id):
			continue
		vus[id] = true
		var eq := Fiction.equipe({"id": id})
		var st := Fiction.stade({"id": id}, eq["nom"])
		res.append({"cle": st["cle"], "id": id, "nom": st["nom"], "club": eq["nom"], "pos": Geo.position_stade(pays, id)})
	return res


## Itinéraire glouton : le plus proche du départ, puis toujours le plus proche.
static func itineraire(candidats: Array, depart: Vector2, n: int) -> Array:
	var reste := candidats.duplicate()
	var res: Array = []
	var ici := depart
	while res.size() < n and not reste.is_empty():
		var best := 0
		for i in reste.size():
			if Geo.distance_km(ici, reste[i]["pos"]) < Geo.distance_km(ici, reste[best]["pos"]):
				best = i
		res.append(reste[best])
		ici = reste[best]["pos"]
		reste.remove_at(best)
	return res


## Longueur de chaque tronçon (km), du départ à la dernière étape.
static func troncons(depart: Vector2, etapes: Array) -> Array:
	var res: Array = []
	var ici := depart
	for e in etapes:
		res.append(Geo.distance_km(ici, e["pos"]))
		ici = e["pos"]
	return res


static func prix(depart: Vector2, etapes: Array, taille_convoi: int) -> int:
	var p := FORFAIT + PAR_ETAPE * etapes.size()
	for km in troncons(depart, etapes):
		p += Deplacement.cout_min(km, taille_convoi)
	return p


## Le Grand Tour proposé dans ce pays ({} s'il reste moins de 2 stades à tamponner).
static func proposer(pays: String, clubs: Array, tampons: Dictionary, depart: Vector2, taille: String, taille_convoi: int) -> Dictionary:
	if not TAILLES.has(taille):
		return {}
	var nouveaux := stades_pays(pays, clubs).filter(func(s): return not tampons.has(s["cle"]))
	var etapes := itineraire(nouveaux, depart, int(TAILLES[taille]["etapes"]))
	if etapes.size() < MIN_ETAPES:
		return {}
	var km := 0.0
	for d in troncons(depart, etapes):
		km += d
	return {"pays": pays, "taille": taille, "etapes": etapes, "km": km, "prix": prix(depart, etapes, taille_convoi)}


## Nombre de stades du pays pas encore tamponnés.
static func a_tamponner(pays: String, clubs: Array, tampons: Dictionary) -> int:
	return stades_pays(pays, clubs).filter(func(s): return not tampons.has(s["cle"])).size()


static func fait_le(etat: Dictionary, jour: String) -> bool:
	return str(etat.get("jour", "")) == jour
