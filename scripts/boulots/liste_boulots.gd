class_name ListeBoulots
extends RefCounted
## Les petits boulots de supporter, montrés dans l'écran « Petits boulots »
## (bouton « Boulots » de la carte). Chaque mini-jeu ajoute ici UNE entrée :
##   id      : clé courte (sert aussi à --scene=<id>)
##   titre   : nom affiché
##   texte   : une phrase qui dit ce qu'on fait
##   scene   : chemin de la scène du mini-jeu
##   couleur : couleur de la carte (code hexadécimal)
## Les mini-jeux rapportent des Jetons ; leur paye baisse après quelques
## parties dans la journée pour compléter les duels sans les remplacer :
## plein tarif pour les PLEIN_TARIF premières parties d'un même boulot, puis
## moitié jusqu'à DEMI_TARIF parties, puis quart (docs/equilibrage.md).
const PLEIN_TARIF := 2
const DEMI_TARIF := 5

const LISTE := [
	{"id": "buvette", "titre": "Vendeur à la buvette", "texte": "Sers les commandes des supporters avant qu'ils perdent patience.",
		"scene": "res://scenes/buvette/buvette.tscn", "couleur": "#ff3d7f"},
	{"id": "ramasseur", "titre": "Ramasseur de balles", "texte": "Cours le long de la touche, attrape les ballons qui sortent et relance-les vite.",
		"scene": "res://scenes/ramasseur/ramasseur.tscn", "couleur": "#1e6bff"},
	{"id": "speaker", "titre": "Speaker du stade", "texte": "Annonce les buteurs au micro, dans le tempo, et fais répondre toute la tribune.",
		"scene": "res://scenes/speaker/speaker.tscn", "couleur": "#ff8a2b"},
	{"id": "tifo", "titre": "Peintre de tifo", "texte": "Peins les grandes bâches du capo d'après son modèle, avant l'entrée des joueurs.",
		"scene": "res://scenes/tifo/tifo.tscn", "couleur": "#8b5cff"},
	{"id": "echarpes", "titre": "Stand d'écharpes", "texte": "Tends à chaque supporter l'écharpe aux couleurs de son club.",
		"scene": "res://scenes/echarpes/echarpes.tscn", "couleur": "#3ddc84"},
]


static func par_id(id: String) -> Dictionary:
	for b in LISTE:
		if b["id"] == id:
			return b
	return {}


## Part de la paye selon le nombre de parties de ce boulot déjà faites aujourd'hui.
static func part_du_jour(deja: int) -> float:
	if deja < PLEIN_TARIF:
		return 1.0
	return 0.5 if deja < DEMI_TARIF else 0.25


## Paye des petits boulots × 2/3 (choix de Gaël le 18 nov. 2026 : trop de Jetons).
const FACTEUR_PAYE := 0.67


## Paye d'une partie, arrondie au-dessus (une partie rapporte toujours au moins 1 Jeton si brut > 0).
static func paye_du_jour(brut: int, deja: int) -> int:
	return int(ceil(brut * part_du_jour(deja) * FACTEUR_PAYE))


## Ligne « Fatigue » du panneau de fin (texte à passer à tr()).
static func texte_fatigue(deja: int) -> String:
	return "paye ÷ 2" if part_du_jour(deja) >= 0.5 else "paye ÷ 4"
