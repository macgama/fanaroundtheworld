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
## parties dans la journée pour compléter les duels sans les remplacer.

const LISTE := [
	{"id": "buvette", "titre": "Vendeur à la buvette", "texte": "Sers les commandes des supporters avant qu'ils perdent patience.",
		"scene": "res://scenes/buvette/buvette.tscn", "couleur": "#ff3d7f"},
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
