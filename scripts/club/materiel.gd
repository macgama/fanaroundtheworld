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

## Guirlandes de la saison : une par mois, achetable SEULEMENT pendant son mois,
## gardée pour toujours. Une seule à la fois dans la tribune. (Achats qui reviennent,
## choix de Gaël le 18 nov. 2026.) motif : flocon, coeur, fleur, soleil, feuille, etoile.
const PRIX_SAISON := 1500
const SAISON := [
	{"id": "saison_01", "mois": 1, "nom": "Guirlande des neiges", "motif": "flocon", "couleur": "#bfe6ff"},
	{"id": "saison_02", "mois": 2, "nom": "Guirlande des cœurs", "motif": "coeur", "couleur": "#ff6f9c"},
	{"id": "saison_03", "mois": 3, "nom": "Guirlande du printemps", "motif": "fleur", "couleur": "#ffd23f"},
	{"id": "saison_04", "mois": 4, "nom": "Guirlande des bourgeons", "motif": "feuille", "couleur": "#7ddc6a"},
	{"id": "saison_05", "mois": 5, "nom": "Guirlande des finales", "motif": "etoile", "couleur": "#ffcf33"},
	{"id": "saison_06", "mois": 6, "nom": "Guirlande de l'été", "motif": "soleil", "couleur": "#ff9a2b"},
	{"id": "saison_07", "mois": 7, "nom": "Guirlande des vacances", "motif": "soleil", "couleur": "#2fc6d6"},
	{"id": "saison_08", "mois": 8, "nom": "Guirlande de la reprise", "motif": "etoile", "couleur": "#3ddc84"},
	{"id": "saison_09", "mois": 9, "nom": "Guirlande de la rentrée", "motif": "feuille", "couleur": "#ffb347"},
	{"id": "saison_10", "mois": 10, "nom": "Guirlande d'automne", "motif": "feuille", "couleur": "#e0662a"},
	{"id": "saison_11", "mois": 11, "nom": "Guirlande des brumes", "motif": "fleur", "couleur": "#b39ddb"},
	{"id": "saison_12", "mois": 12, "nom": "Guirlande des fêtes", "motif": "flocon", "couleur": "#ff4b4b"},
]


static func objet(id: String) -> Dictionary:
	for o in OBJETS + SAISON:
		if o["id"] == id:
			return o
	return {}


static func est_saison(id: String) -> bool:
	return id.begins_with("saison_")


static func du_mois(mois: int) -> Dictionary:
	for o in SAISON:
		if int(o["mois"]) == mois:
			return o
	return {}


static func niveau_max(id: String) -> int:
	return 1 if est_saison(id) else NIVEAU_MAX


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
		var n := clampi(int(e.get("niveau", 0)), 0, niveau_max(str(id)))
		if n > 0:
			res[str(id)] = {"niveau": n, "actif": bool(e.get("actif", true))}
	return res


static func niveau(etat: Dictionary, id: String) -> int:
	var e: Variant = etat.get(id, {})
	return int(e.get("niveau", 0)) if e is Dictionary else 0


static func actif(etat: Dictionary, id: String) -> bool:
	return niveau(etat, id) > 0 and bool(etat[id].get("actif", true))


## Prix du niveau suivant, -1 si l'objet est inconnu ou au maximum, ou si c'est une
## guirlande de la saison hors de son mois (mois = mois du jour, 1-12).
static func prix_suivant(etat: Dictionary, id: String, mois := 0) -> int:
	var o := objet(id)
	var n := niveau(etat, id)
	if o.is_empty() or n >= niveau_max(id):
		return -1
	if est_saison(id):
		return PRIX_SAISON if int(o["mois"]) == mois else -1
	return int(o["prix"][n])


## Passe l'objet au niveau suivant (le paiement est fait par Game.acheter_materiel).
## Un objet acheté ou amélioré est installé dans la tribune.
static func monter(etat: Dictionary, id: String, mois := 0) -> void:
	if prix_suivant(etat, id, mois) < 0:
		return
	etat[id] = {"niveau": niveau(etat, id) + 1, "actif": true}
	if est_saison(id):
		_une_seule_guirlande(etat, id)


static func basculer(etat: Dictionary, id: String) -> void:
	if niveau(etat, id) > 0:
		etat[id]["actif"] = not actif(etat, id)
		if est_saison(id) and actif(etat, id):
			_une_seule_guirlande(etat, id)


static func _une_seule_guirlande(etat: Dictionary, garder: String) -> void:
	for o in SAISON:
		if o["id"] != garder and niveau(etat, o["id"]) > 0:
			etat[o["id"]]["actif"] = false


## Guirlandes de la saison possédées.
static func guirlandes(etat: Dictionary) -> Array:
	return SAISON.filter(func(o): return niveau(etat, o["id"]) > 0)


## Ce que la tribune affiche : {id: niveau} des objets installés.
static func affiche(etat: Dictionary) -> Dictionary:
	var res := {}
	for id in ids():
		if actif(etat, id):
			res[id] = niveau(etat, id)
	for o in SAISON:
		if actif(etat, o["id"]):
			res["guirlande"] = o["id"]  # la guirlande de la saison affichée
	return res


## Jetons déjà mis dans le matériel (pour l'équilibrage).
static func valeur(etat: Dictionary) -> int:
	var t := 0
	for o in OBJETS:
		for i in niveau(etat, o["id"]):
			t += int(o["prix"][i])
	return t + guirlandes(etat).size() * PRIX_SAISON
