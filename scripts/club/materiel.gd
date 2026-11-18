class_name Materiel
extends RefCounted
## Matériel de tribune du fan club, sans écran (testable).
##
## Écharpes, grands drapeaux, tambours, bâche et confettis aux couleurs de
## l'équipe, dessinés dans notre tribune pendant les duels (Duel.Decor). C'est
## du décor : AUCUN effet sur la jauge, les points ou la Poussée. Il s'achète en
## Jetons (ce n'est pas un skin de FANZZY, qui reste réservé au PASS).
## Chaque objet a trois niveaux (plus nombreux, plus grands) et peut être rangé.
##
## État sauvegardé dans Game.materiel : {id: {"niveau": n, "actif": bool}}.

const OBJETS := [
	{"id": "echarpes", "nom": "Mur d'écharpes", "texte": "Les écharpes tendues au-dessus des têtes.", "prix": [150, 600, 2000]},
	{"id": "drapeaux", "nom": "Grands drapeaux", "texte": "Des drapeaux qui flottent dans la tribune.", "prix": [200, 800, 2500]},
	{"id": "tambours", "nom": "Tambours", "texte": "Ils battent plus vite quand la tribune s'enflamme.", "prix": [250, 1000, 3000]},
	{"id": "bache", "nom": "Bâche du club", "texte": "Le nom du fan club accroché à la balustrade.", "prix": [300, 1200, 3500]},
	{"id": "confettis", "nom": "Pluie de confettis", "texte": "Des confettis du club quand la tribune est à fond.", "prix": [400, 1600, 4500]},
]
const NIVEAU_MAX := 3


static func objet(id: String) -> Dictionary:
	for o in OBJETS:
		if o["id"] == id:
			return o
	return {}


static func ids() -> Array:
	return OBJETS.map(func(o): return o["id"])


static func reparer(v: Variant) -> Dictionary:
	var res := {}
	if not v is Dictionary:
		return res
	for id in v:
		var e: Variant = v[id]
		if objet(str(id)).is_empty() or not e is Dictionary:
			continue
		var n := clampi(int(e.get("niveau", 0)), 0, NIVEAU_MAX)
		if n > 0:
			res[str(id)] = {"niveau": n, "actif": bool(e.get("actif", true))}
	return res


static func niveau(etat: Dictionary, id: String) -> int:
	var e: Variant = etat.get(id, {})
	return int(e.get("niveau", 0)) if e is Dictionary else 0


static func actif(etat: Dictionary, id: String) -> bool:
	return niveau(etat, id) > 0 and bool(etat[id].get("actif", true))


## Prix du niveau suivant, -1 si l'objet est inconnu ou au maximum.
static func prix_suivant(etat: Dictionary, id: String) -> int:
	var o := objet(id)
	var n := niveau(etat, id)
	if o.is_empty() or n >= NIVEAU_MAX:
		return -1
	return int(o["prix"][n])


## Passe l'objet au niveau suivant (le paiement est fait par Game.acheter_materiel).
## Un objet acheté ou amélioré est installé dans la tribune.
static func monter(etat: Dictionary, id: String) -> void:
	if prix_suivant(etat, id) < 0:
		return
	etat[id] = {"niveau": niveau(etat, id) + 1, "actif": true}


static func basculer(etat: Dictionary, id: String) -> void:
	if niveau(etat, id) > 0:
		etat[id]["actif"] = not actif(etat, id)


## Ce que la tribune affiche : {id: niveau} des objets installés.
static func affiche(etat: Dictionary) -> Dictionary:
	var res := {}
	for id in ids():
		if actif(etat, id):
			res[id] = niveau(etat, id)
	return res


## Jetons déjà mis dans le matériel (pour l'équilibrage).
static func valeur(etat: Dictionary) -> int:
	var t := 0
	for o in OBJETS:
		for i in niveau(etat, o["id"]):
			t += int(o["prix"][i])
	return t
