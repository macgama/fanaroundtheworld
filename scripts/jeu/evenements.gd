class_name Evenements
extends RefCounted
## Événements autour des vrais matchs, sans affichage : derbys, Grand Choc,
## finales, demi-finales, quarts et fêtes des nations.
##
## Tout est trouvé automatiquement dans le calendrier du relais :
##  - le tour du match (« Final », « Semi-finals »…) donne finales, demies et quarts ;
##  - deux clubs du même pays dont le stade est dans la même ville = derby
##    (ville lue dans teams.json) ;
##  - la table data/evenements/rivalites.json ajoute les derbys entre villes
##    voisines et les « Grand Choc » entre grands rivaux (un mod peut la compléter) ;
##  - deux grands clubs (noms choisis à la main) qui se croisent en coupe
##    continentale ou mondiale = Grand Choc ;
##  - les matchs des grandes compétitions de sélections = fête des nations.
##
## Pendant l'événement (de la veille du match à 6 h après le coup d'envoi),
## les duels joués sur ce match rapportent plus de Jetons, et le premier duel
## donne une prime fixe (XP de PASS + Jetons), une seule fois par match.
## Jamais de skin contre des Jetons : les récompenses sont des Jetons et de l'XP.

## Ordre = priorité quand un match a plusieurs raisons d'être spécial.
const TYPES := {
	"finale": {
		"court": "Finale", "titre": "Soirée de finale", "couleur": "#ffd23f", "sombre": true,
		"texte": "La finale ! Toutes les tribunes du monde ont les yeux sur ce match.",
		"mult": 2.0, "xp_pass": 400, "jetons": 50,
	},
	"derby": {
		"court": "Derby", "titre": "Derby", "couleur": "#ff3d7f", "sombre": false,
		"texte": "Deux clubs voisins : toute la ville choisit son camp.",
		"mult": 1.5, "xp_pass": 250, "jetons": 30,
	},
	"demi": {
		"court": "Demi-finale", "titre": "Demi-finale", "couleur": "#ff8a2b", "sombre": false,
		"texte": "Une place en finale se joue sur ce match.",
		"mult": 1.5, "xp_pass": 200, "jetons": 25,
	},
	"choc": {
		"court": "Grand Choc", "titre": "Grand Choc", "couleur": "#8b5cff", "sombre": false,
		"texte": "Deux grands rivaux se retrouvent : le match que tout le monde attend.",
		"mult": 1.4, "xp_pass": 200, "jetons": 25,
	},
	"nations": {
		"court": "Nations", "titre": "Fête des nations", "couleur": "#3ddc84", "sombre": true,
		"texte": "Les sélections jouent pour leur pays : sortez les drapeaux !",
		"mult": 1.3, "xp_pass": 150, "jetons": 20,
	},
	"quart": {
		"court": "Quart de finale", "titre": "Quart de finale", "couleur": "#1e6bff", "sombre": false,
		"texte": "Plus que huit équipes en course.",
		"mult": 1.25, "xp_pass": 100, "jetons": 15,
	},
}
const ORDRE := ["finale", "derby", "demi", "choc", "nations", "quart"]

## L'événement commence la veille du match et finit 6 h après le coup d'envoi.
const AVANT := 24 * 3600
const APRES := 6 * 3600
## Compétitions de sélections qui font une fête des nations (pas les amicaux).
const NATIONS := ["world-cup", "euro", "copa-america", "afcon", "nations-league"]
const STATUTS_SANS_FETE := ["POSTPONED", "CANCELLED", "SUSPENDED"]  # sans_traduction

## Noms français des villes les plus courantes dans le flux (sinon le nom reçu).
const VILLES_FR := {
	"london": "Londres", "milano": "Milan", "roma": "Rome", "torino": "Turin", "genova": "Gênes",  # sans_traduction
	"napoli": "Naples", "firenze": "Florence", "lisboa": "Lisbonne", "sevilla": "Séville",  # sans_traduction
	"münchen": "Munich", "köln": "Cologne", "wien": "Vienne", "praha": "Prague",  # sans_traduction
	"warszawa": "Varsovie", "athina": "Athènes", "athens": "Athènes", "moskva": "Moscou",  # sans_traduction
	"moscow": "Moscou", "københavn": "Copenhague", "copenhagen": "Copenhague",  # sans_traduction
	"bucureşti": "Bucarest", "bucuresti": "Bucarest", "beograd": "Belgrade", "belgrade": "Belgrade",  # sans_traduction
	"istanbul": "Istanbul", "rio de janeiro": "Rio", "capital federal": "Buenos Aires",  # sans_traduction
	"ciudad de buenos aires": "Buenos Aires", "ciudad de méxico": "Mexico", "cairo": "Caire",  # sans_traduction
	"al qahirah": "Caire", "riyadh": "Riyad", "edinburgh": "Édimbourg", "seville": "Séville",  # sans_traduction
	"lisbon": "Lisbonne", "brussels": "Bruxelles", "brussel": "Bruxelles", "antwerpen": "Anvers",  # sans_traduction
	"sofia": "Sofia", "kyiv": "Kiev", "tbilisi": "Tbilissi", "tehran": "Téhéran",  # sans_traduction
	"montevideo": "Montevideo", "asunción": "Asuncion", "lima": "Lima", "bogotá": "Bogota",  # sans_traduction
	"santiago de chile": "Santiago", "johannesburg": "Johannesburg", "seoul": "Séoul",  # sans_traduction
	"tokyo": "Tokyo", "osaka": "Osaka", "sydney": "Sydney", "melbourne": "Melbourne",  # sans_traduction
}
## Villes qui prennent « du » (« Derby du Caire »).
const VILLES_DU := ["Caire", "Cap", "Havre", "Mans", "Pirée"]  # sans_traduction

static var _rivalites: Dictionary = {}  # « id1|id2 » (triés) -> {type, nom}
static var _charge := false


# ------------------------------------------------------------------ table des rivalités

static func _cle_paire(a: String, b: String) -> String:
	return a + "|" + b if a < b else b + "|" + a


static func _charger() -> void:
	if _charge:
		return
	_charge = true
	for chemin in ["res://data/evenements/rivalites.json", "user://mods/rivalites.json"]:
		var f := FileAccess.open(chemin, FileAccess.READ)
		if f == null:
			continue
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary and d.get("rivalites") is Array:
			ajouter_rivalites(d["rivalites"])


## Ajoute des rivalités [{equipes: [id, id], type: derby|choc, nom?}] (mods, tests).
static func ajouter_rivalites(liste: Array) -> void:
	for r in liste:
		if not r is Dictionary or not r.get("equipes") is Array or r["equipes"].size() != 2:
			continue
		var type := str(r.get("type", "choc"))
		if not type in ["derby", "choc"]:
			continue
		_rivalites[_cle_paire(str(r["equipes"][0]), str(r["equipes"][1]))] = {"type": type, "nom": str(r.get("nom", ""))}


static func rivalite(a: String, b: String) -> Dictionary:
	_charger()
	return _rivalites.get(_cle_paire(a, b), {})


# ------------------------------------------------------------------ détection

## Tour du match → "finale", "demi", "quart" ou "".
static func type_tour(tour: Variant) -> String:
	if tour == null:
		return ""
	var r := str(tour).to_lower()
	if r == "" or "3rd" in r or "third" in r or "place" in r or "qualif" in r:
		return ""
	if "semi" in r or "halbfinal" in r or "demi" in r:
		return "demi"
	if "quarter" in r or "viertelfinal" in r or "quart" in r:
		return "quart"
	if "final" in r and not "1/" in r and not "round of" in r:  # sans_traduction
		return "finale"
	return ""


## Clé de ville comparable (« Manchester » = « manchester »).
static func cle_ville(ville: Variant) -> String:
	if ville == null:
		return ""
	return str(ville).split(",")[0].strip_edges().replace("İ", "I").to_lower()


## « Derby de Londres », « Derby d'Istanbul », « Derby du Caire ».
static func nom_derby(ville: String) -> String:
	if not Trad.est_source():
		# « London Derby » : le nom de ville reçu du flux, sans traduction
		return Trad.t("Derby de %s") % ville.split(",")[0].strip_edges()
	var v: String = VILLES_FR.get(cle_ville(ville), ville.split(",")[0].strip_edges())
	if v in VILLES_DU:
		return Trad.t("Derby du ") + v  # sans_traduction
	if v != "" and v.left(1).to_lower() in ["a", "e", "i", "o", "u", "é", "è", "h", "î", "ô"]:
		return Trad.t("Derby d'") + v  # sans_traduction
	return Trad.t("Derby de ") + v  # sans_traduction


## Événement d'un match, ou {} s'il n'a rien de spécial.
## `villes` : id d'équipe → ville du stade ; `pays` : id d'équipe → pays ;
## `grands` : ids des grands clubs (noms fictifs choisis à la main).
## Renvoie {type, court, titre, texte, couleur, sombre, mult, xp_pass, jetons, aussi: [courts]}.
static func detecter(m: Dictionary, villes: Dictionary = {}, pays: Dictionary = {}, grands: Dictionary = {}) -> Dictionary:
	if m.is_empty() or str(m.get("status", "")) in STATUTS_SANS_FETE:
		return {}
	var comp_id := str(m.get("competition", {}).get("id", ""))
	var info := Geo.info_competition(comp_id)
	var selections: bool = info.get("type", "") == "international"
	var dom := str(m.get("home", {}).get("id", ""))
	var ext := str(m.get("away", {}).get("id", ""))
	var trouves: Dictionary = {}  # type -> titre
	var tour := type_tour(m.get("round"))
	if tour != "":
		trouves[tour] = TYPES[tour]["titre"]
	if selections:
		if comp_id in NATIONS:
			trouves["nations"] = TYPES["nations"]["titre"]
	elif dom != "" and ext != "" and dom != ext:
		var r := rivalite(dom, ext)
		if not r.is_empty():
			var nom := str(r.get("nom", ""))
			trouves[r["type"]] = nom if nom != "" else TYPES[r["type"]]["titre"]
		if not trouves.has("derby"):
			var v1 := cle_ville(villes.get(dom))
			var meme_pays: bool = not (pays.has(dom) and pays.has(ext)) or pays[dom] == pays[ext]
			if v1 != "" and v1 == cle_ville(villes.get(ext)) and meme_pays:
				trouves["derby"] = nom_derby(str(villes[dom]))
		if not trouves.has("choc") and grands.has(dom) and grands.has(ext) and not info.has("pays"):
			trouves["choc"] = TYPES["choc"]["titre"]
	if trouves.is_empty():
		return {}
	var ev := {}
	var aussi: Array = []
	for type in ORDRE:
		if not trouves.has(type):
			continue
		if ev.is_empty():
			ev = TYPES[type].duplicate()
			ev["type"] = type
			ev["titre"] = trouves[type]
		else:
			aussi.append(trouves[type] if type == "derby" else TYPES[type]["court"])
	ev["aussi"] = aussi
	return ev


# ------------------------------------------------------------------ calendrier

## "a_venir", "actif" ou "fini" pour un match à l'heure `t` (unix).
static func etat(kickoff: int, t: int) -> String:
	if kickoff <= 0:
		return "fini"
	if t < kickoff - AVANT:
		return "a_venir"
	if t <= kickoff + APRES:
		return "actif"
	return "fini"


## Jetons en plus d'un duel joué pendant l'événement (arrondi, jamais négatif).
static func bonus_jetons(ev: Dictionary, jetons_duel: int) -> int:
	if ev.is_empty():
		return 0
	return maxi(0, int(round(float(jetons_duel) * (float(ev.get("mult", 1.0)) - 1.0))))


## « ×1,5 » pour l'affichage.
static func texte_mult(ev: Dictionary) -> String:
	var mult := float(ev.get("mult", 1.0))
	var s := str(mult) if mult != floorf(mult) else str(int(mult))
	return "×" + Trad.decimal(s)


## Oublie les primes des matchs d'il y a plus de 10 jours (sauvegarde légère).
static func nettoyer_primes(primes: Dictionary, t: int) -> void:
	for id in primes.keys():
		if t - int(primes[id]) > 10 * 86400:
			primes.erase(id)
