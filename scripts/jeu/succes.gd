class_name Succes
extends RefCounted
## Les succès du jeu, sans écran (testables).
##
## Chaque succès a un identifiant d'API Steam (`id`, à recopier tel quel dans
## Steamworks), un nom et une phrase en français et en anglais, une icône
## (Ui.icone) et une condition : la valeur `cle` de l'état du joueur doit
## atteindre `seuil`. L'état est un simple Dictionary fait par Game.etat_succes().
##
## Le jeu garde les succès gagnés dans sa sauvegarde (Game.succes : {id: date
## unix}) et les envoie à Steam quand Steam est là (autoload Plateforme). Un
## succès gagné ne se perd jamais, même si la valeur redescend ensuite.
## Ajouter un succès : une ligne ici, puis le créer dans Steamworks (voir
## docs/succes-et-cloud.md) et relancer tools/steam/icones_succes.tscn.

const LISTE := [
	# Duels
	{"id": "PREMIER_DUEL", "cle": "duels_joues", "seuil": 1, "icone": "feu", "couleur": "#ff8a2b",  # sans_traduction
		"titre": "Premier coup de chant", "texte": "Joue ton premier duel.",
		"titre_en": "First Chant", "texte_en": "Play your first duel."},  # sans_traduction
	{"id": "PREMIERE_VICTOIRE", "cle": "duels_gagnes", "seuil": 1, "icone": "cible", "couleur": "#3ddc84",  # sans_traduction
		"titre": "Victoire en tribune", "texte": "Gagne ton premier duel.",
		"titre_en": "Stand Victory", "texte_en": "Win your first duel."},  # sans_traduction
	{"id": "VICTOIRES_25", "cle": "duels_gagnes", "seuil": 25, "icone": "cible", "couleur": "#1e6bff",  # sans_traduction
		"titre": "Tribune redoutée", "texte": "Gagne 25 duels.",
		"titre_en": "Feared Stand", "texte_en": "Win 25 duels."},  # sans_traduction
	{"id": "VICTOIRES_100", "cle": "duels_gagnes", "seuil": 100, "icone": "cible", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Voix d'or", "texte": "Gagne 100 duels.",
		"titre_en": "Golden Voice", "texte_en": "Win 100 duels."},  # sans_traduction
	{"id": "ARENE_VICTOIRE", "cle": "duel_gagne:arene", "seuil": 1, "icone": "feu", "couleur": "#ff4b4b",  # sans_traduction
		"titre": "Roi de l'arène", "texte": "Gagne une partie dans l'Arène.",
		"titre_en": "King of the Arena", "texte_en": "Win a match in the Arena."},  # sans_traduction
	{"id": "POUSSEE_VICTOIRE", "cle": "duel_gagne:poussee", "seuil": 1, "icone": "stade", "couleur": "#8b5cff",  # sans_traduction
		"titre": "Jusqu'au but", "texte": "Gagne une partie de Poussée.",
		"titre_en": "All the Way", "texte_en": "Win a Push match."},  # sans_traduction
	{"id": "EN_LIGNE_VICTOIRE", "cle": "duel_gagne_en_ligne", "seuil": 1, "icone": "monde", "couleur": "#2fc6d6",  # sans_traduction
		"titre": "Plus fort que les autres", "texte": "Gagne contre un vrai joueur en ligne.",
		"titre_en": "Louder Than the Rest", "texte_en": "Beat a real player online."},  # sans_traduction
	{"id": "EN_LIGNE_10", "cle": "duel_gagne_en_ligne", "seuil": 10, "icone": "monde", "couleur": "#1e6bff",  # sans_traduction
		"titre": "Terreur des virages", "texte": "Gagne 10 parties en ligne.",
		"titre_en": "Terror of the Stands", "texte_en": "Win 10 online matches."},  # sans_traduction
	# Fan club
	{"id": "CLUB_CREE", "cle": "club_cree", "seuil": 1, "icone": "pin", "couleur": "#ff3d7f",  # sans_traduction
		"titre": "Le club est né", "texte": "Fonde ton fan club.",
		"titre_en": "A Club Is Born", "texte_en": "Found your fan club."},  # sans_traduction
	{"id": "CLUB_QUARTIER", "cle": "membres", "seuil": 9, "icone": "pin", "couleur": "#ff8a2b",  # sans_traduction
		"titre": "Club de quartier", "texte": "Réunis 9 FANZZY dans ton fan club.",
		"titre_en": "Neighbourhood Club", "texte_en": "Gather 9 FANZZY in your fan club."},  # sans_traduction
	{"id": "CLUB_LEGENDE", "cle": "membres", "seuil": 18, "icone": "pin", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Légende du virage", "texte": "Réunis 18 FANZZY dans ton fan club.",
		"titre_en": "Legend of the Stands", "texte_en": "Gather 18 FANZZY in your fan club."},  # sans_traduction
	{"id": "FAVORI", "cle": "favoris", "seuil": 1, "icone": "feu", "couleur": "#ff3d7f",  # sans_traduction
		"titre": "Un cœur, un club", "texte": "Choisis une équipe favorite.",
		"titre_en": "One Heart, One Club", "texte_en": "Pick a favourite team."},  # sans_traduction
	{"id": "NIVEAU_10", "cle": "niveau", "seuil": 10, "icone": "jeton", "couleur": "#3ddc84",  # sans_traduction
		"titre": "Supporter confirmé", "texte": "Atteins le niveau 10.",
		"titre_en": "True Supporter", "texte_en": "Reach level 10."},  # sans_traduction
	{"id": "NIVEAU_25", "cle": "niveau", "seuil": 25, "icone": "jeton", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Pilier de tribune", "texte": "Atteins le niveau 25.",
		"titre_en": "Pillar of the Stand", "texte_en": "Reach level 25."},  # sans_traduction
	# Voyages
	{"id": "STADE_1", "cle": "stades", "seuil": 1, "icone": "tampon", "couleur": "#ff3d7f",  # sans_traduction
		"titre": "Premier tampon", "texte": "Visite ton premier stade.",
		"titre_en": "First Stamp", "texte_en": "Visit your first stadium."},  # sans_traduction
	{"id": "STADES_10", "cle": "stades", "seuil": 10, "icone": "tampon", "couleur": "#1e6bff",  # sans_traduction
		"titre": "Globe-trotteur", "texte": "Visite 10 stades.",
		"titre_en": "Globetrotter", "texte_en": "Visit 10 stadiums."},  # sans_traduction
	{"id": "STADES_50", "cle": "stades", "seuil": 50, "icone": "tampon", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Grand voyageur", "texte": "Visite 50 stades.",
		"titre_en": "Great Traveller", "texte_en": "Visit 50 stadiums."},  # sans_traduction
	{"id": "PAYS_5", "cle": "pays", "seuil": 5, "icone": "pin", "couleur": "#2fc6d6",  # sans_traduction
		"titre": "Passeport bien rempli", "texte": "Visite des stades dans 5 pays.",
		"titre_en": "Stamped Passport", "texte_en": "Visit stadiums in 5 countries."},  # sans_traduction
	{"id": "CONTINENTS_3", "cle": "continents", "seuil": 3, "icone": "monde", "couleur": "#3ddc84",  # sans_traduction
		"titre": "Tour du monde", "texte": "Visite des stades sur 3 continents.",
		"titre_en": "Around the World", "texte_en": "Visit stadiums on 3 continents."},  # sans_traduction
	{"id": "CONTINENTS_5", "cle": "continents", "seuil": 5, "icone": "monde", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Fan sans frontières", "texte": "Visite des stades sur 5 continents.",
		"titre_en": "Fan Without Borders", "texte_en": "Visit stadiums on 5 continents."},  # sans_traduction
	{"id": "SUIVI_PARTOUT", "cle": "modes_suivi", "seuil": 4, "icone": "direct", "couleur": "#8b5cff",  # sans_traduction
		"titre": "Fan partout", "texte": "Suis un match au stade, sur écran géant, au pub et à la maison.",
		"titre_en": "Fan Everywhere", "texte_en": "Follow a match at the stadium, on a big screen, at the pub and at home."},  # sans_traduction
	{"id": "DERBY", "cle": "evenement:derby", "seuil": 1, "icone": "feu", "couleur": "#ff3d7f",  # sans_traduction
		"titre": "Toute la ville en parle", "texte": "Joue un duel sur un derby.",
		"titre_en": "The Whole Town Is Talking", "texte_en": "Play a duel on a derby."},  # sans_traduction
	{"id": "FINALE", "cle": "evenement:finale", "seuil": 1, "icone": "feu", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Soir de finale", "texte": "Joue un duel sur une finale.",
		"titre_en": "Final Night", "texte_en": "Play a duel on a final."},  # sans_traduction
	# Pronostics
	{"id": "PRONO_EXACT", "cle": "prono_exact", "seuil": 1, "icone": "calendrier", "couleur": "#1e6bff",  # sans_traduction
		"titre": "Voyant", "texte": "Trouve le score exact d'un match.",
		"titre_en": "Fortune Teller", "texte_en": "Predict the exact score of a match."},  # sans_traduction
	{"id": "PRONO_SERIE_5", "cle": "meilleure_serie", "seuil": 5, "icone": "calendrier", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Série en or", "texte": "Trouve 5 bons résultats d'affilée.",
		"titre_en": "Golden Streak", "texte_en": "Get 5 correct results in a row."},  # sans_traduction
	# Petits boulots et missions
	{"id": "BOULOTS_TOUS", "cle": "boulots_differents", "seuil": -1, "icone": "jeton", "couleur": "#ff8a2b",  # sans_traduction
		"titre": "Touche-à-tout", "texte": "Essaie chacun des petits boulots.",
		"titre_en": "Jack of All Trades", "texte_en": "Try every odd job."},  # sans_traduction
	{"id": "BOULOTS_50", "cle": "boulots", "seuil": 50, "icone": "jeton", "couleur": "#3ddc84",  # sans_traduction
		"titre": "Gros bosseur", "texte": "Fais 50 parties de petits boulots.",
		"titre_en": "Hard Worker", "texte_en": "Play 50 odd jobs."},  # sans_traduction
	{"id": "MISSIONS_20", "cle": "missions_recuperees", "seuil": 20, "icone": "cible", "couleur": "#8b5cff",  # sans_traduction
		"titre": "Toujours partant", "texte": "Récupère 20 récompenses de missions.",
		"titre_en": "Always Up For It", "texte_en": "Claim 20 mission rewards."},  # sans_traduction
	# Collection
	{"id": "ALBUM_25", "cle": "album", "seuil": 25, "icone": "tampon", "couleur": "#8b5cff",  # sans_traduction
		"titre": "Album bien garni", "texte": "Fais entrer 25 FANZZY dans ton album.",
		"titre_en": "Full Album", "texte_en": "Add 25 FANZZY to your album."},  # sans_traduction
	{"id": "PRIMES_10", "cle": "primes", "seuil": 10, "icone": "jeton", "couleur": "#ffd23f",  # sans_traduction
		"titre": "Chasseur de primes", "texte": "Réclame 10 primes de collection.",
		"titre_en": "Bounty Hunter", "texte_en": "Claim 10 collection rewards."},  # sans_traduction
]


static func par_id(id: String) -> Dictionary:
	for s in LISTE:
		if s["id"] == id:
			return s
	return {}


## Seuil réel (−1 = « tous les petits boulots » : la taille de ListeBoulots).
static func seuil(s: Dictionary) -> int:
	var n := int(s["seuil"])
	return ListeBoulots.LISTE.size() if n < 0 else n


## [valeur atteinte (bornée au seuil), seuil]
static func progres(s: Dictionary, etat: Dictionary) -> Vector2i:
	var total := seuil(s)
	return Vector2i(clampi(int(etat.get(s["cle"], 0)), 0, total), total)


## Les succès qui viennent d'être atteints (pas encore dans `gagnes`).
static func nouveaux(gagnes: Dictionary, etat: Dictionary) -> Array:
	var r: Array = []
	for s in LISTE:
		if not gagnes.has(s["id"]) and int(etat.get(s["cle"], 0)) >= seuil(s):
			r.append(s)
	return r


## Note les nouveaux succès dans `gagnes` ({id: date unix}) et les renvoie.
static func noter(gagnes: Dictionary, etat: Dictionary, maintenant: int) -> Array:
	var r := nouveaux(gagnes, etat)
	for s in r:
		gagnes[s["id"]] = maintenant
	return r


## Nettoie une sauvegarde : seulement des ids connus, avec une date entière.
static func reparer(d: Variant) -> Dictionary:
	var r: Dictionary = {}
	if d is Dictionary:
		for id in d:
			if not par_id(str(id)).is_empty():
				r[str(id)] = int(d[id])
	return r


## Compteurs d'événements (Game.stats) : seuls ces événements gardent leur clé
## (« duel_gagne:arene »), les autres comptent juste leur total.
const EVTS_AVEC_CLE := ["duel_joue", "duel_gagne", "suivre", "evenement", "boulot"]

static func compter(stats: Dictionary, evt: String, cle: String, n: int) -> void:
	stats[evt] = int(stats.get(evt, 0)) + n
	if cle != "" and evt in EVTS_AVEC_CLE:
		var k := evt + ":" + cle
		stats[k] = int(stats.get(k, 0)) + n


static func reparer_stats(d: Variant) -> Dictionary:
	var r: Dictionary = {}
	if d is Dictionary:
		for k in d:
			r[str(k)] = int(d[k])
	return r
