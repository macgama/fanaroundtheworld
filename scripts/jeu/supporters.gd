class_name Supporters
extends RefCounted
## Équipes favorites et popularité, sans affichage.
##
## Le joueur choisit UN club favori par pays et UNE équipe nationale.
## Quand il soutient une de ses équipes (duel, pronostic, déplacement) ou fait
## vivre son fan club, il lui rapporte des points de popularité. Le classement
## des équipes les plus suivies additionne les points de tous les supporters.
##
## Clés d'équipe (les mêmes partout, et plus tard sur le serveur) :
##   club : identifiant du flux de données, ex. « af:85 » ;
##   sélection : « nation: » + clé du pays, ex. « nation:france ».
##
## En attendant le jeu en ligne, les autres supporters sont simulés
## (base_communaute) et les points du joueur sont gardés dans une file
## (« a_envoyer ») prête à être envoyée au serveur.

## Délai avant de pouvoir remplacer un favori (les points donnés restent acquis).
const DELAI_CHANGEMENT := 7 * 24 * 3600
## Points au plus par équipe et par jour (évite de rejouer le même duel en boucle).
const MAX_PAR_JOUR := 200
const MAX_A_ENVOYER := 300
const MAX_MATCHS_SUIVIS := 120

## Points gagnés par l'équipe que tu soutiens.
const POINTS_DUEL := 10
const POINTS_DUEL_GAGNE := 10
const POINTS_SUIVI := {"stade": 20, "ecran": 8, "pub": 5, "maison": 2}
const POINTS_PRONO := 3
const POINTS_PRONO_RESULTAT := 7
const POINTS_PRONO_SCORE := 10
## Fan club : à chaque récolte, 1 point par tranche de 10 Jetons, pour chaque favori.
const JETONS_PAR_POINT_CLUB := 10
const MAX_POINTS_CLUB := 30

## Lancement de la saison simulée : la communauté grandit chaque jour depuis.
const DEBUT_SAISON := 1_793_491_200  # 2026-11-01 00:00 UTC

## Sélections qui partent avec plus de supporters dans le classement simulé.
const GRANDES_NATIONS := [
	"france", "brazil", "argentina", "germany", "spain", "italy", "england", "portugal",
	"netherlands", "belgium", "uruguay", "mexico", "united states", "japan", "morocco",
	"croatia", "colombia", "senegal", "south korea", "nigeria", "cameroon", "switzerland",
	"denmark", "algeria", "egypt", "ivory coast", "scotland", "turkey", "poland", "chile",
]

const RAISONS := {
	"duel": "Duel", "suivi": "Match suivi", "prono": "Pronostic", "club": "Fan club",
}


static func vide() -> Dictionary:
	return {
		"clubs": {},        # clé pays -> {"id", "depuis"}
		"nation": {},       # {"pays", "depuis"} ou vide
		"points": {},       # clé équipe -> points donnés par le joueur (total)
		"jour": "",         # date du compteur journalier
		"du_jour": {},      # clé équipe -> points donnés aujourd'hui
		"suivis": [],       # matchs déjà comptés comme « suivis »
		"a_envoyer": [],    # file envoyée au classement en ligne (autoload EnLigne)
		"envoye": {},       # clé équipe -> points déjà comptés par le serveur
	}


static func reparer(d: Variant) -> Dictionary:
	var r := vide()
	if d is Dictionary:
		for k in r:
			if d.has(k) and typeof(d[k]) == typeof(r[k]):
				r[k] = d[k]
	return r


# ------------------------------------------------------------------ clés

static func cle_nation(pays: String) -> String:
	return "nation:" + pays


static func est_nation(cle: String) -> bool:
	return cle.begins_with("nation:")


## Clé d'une équipe du flux. Les sélections de jeunes et féminines ne comptent pas
## (pas de favori possible) : renvoie "".
static func cle_equipe(e: Dictionary, est_selection: bool) -> String:
	if not est_selection:
		return str(e.get("id", ""))
	var nom := str(e.get("name", ""))
	if Geo._separer_suffixe(nom)[1] != "":
		return ""
	var pays := Geo.cle_pays(nom)
	return cle_nation(pays) if pays != "" else ""


# ------------------------------------------------------------------ favoris

static func cles_favorites(s: Dictionary) -> Array:
	var out: Array = []
	for p in s["clubs"]:
		out.append(str(s["clubs"][p]["id"]))
	if not s["nation"].is_empty():
		out.append(cle_nation(str(s["nation"]["pays"])))
	return out


static func est_favori(s: Dictionary, cle: String) -> bool:
	if cle == "":
		return false
	if est_nation(cle):
		return not s["nation"].is_empty() and cle_nation(str(s["nation"]["pays"])) == cle
	for p in s["clubs"]:
		if str(s["clubs"][p]["id"]) == cle:
			return true
	return false


static func club_du_pays(s: Dictionary, pays: String) -> String:
	return str(s["clubs"].get(pays, {}).get("id", ""))


## Secondes avant de pouvoir changer ce favori (0 = libre).
static func attente(choix: Dictionary, maintenant: int) -> int:
	if choix.is_empty():
		return 0
	return maxi(0, int(choix.get("depuis", 0)) + DELAI_CHANGEMENT - maintenant)


static func attente_club(s: Dictionary, pays: String, maintenant: int) -> int:
	return attente(s["clubs"].get(pays, {}), maintenant)


static func attente_nation(s: Dictionary, maintenant: int) -> int:
	return attente(s["nation"], maintenant)


## Choisit le club favori d'un pays (remplace l'ancien après le délai).
static func choisir_club(s: Dictionary, pays: String, id: String, maintenant: int) -> bool:
	if pays == "" or id == "" or id.begins_with("nation:"):
		return false
	if club_du_pays(s, pays) == id:
		return false
	if attente_club(s, pays, maintenant) > 0:
		return false
	s["clubs"][pays] = {"id": id, "depuis": maintenant}
	return true


## Retire le club favori d'un pays (même délai qu'un changement).
static func retirer_club(s: Dictionary, pays: String, maintenant: int) -> bool:
	if not s["clubs"].has(pays) or attente_club(s, pays, maintenant) > 0:
		return false
	s["clubs"].erase(pays)
	return true


static func choisir_nation(s: Dictionary, pays: String, maintenant: int) -> bool:
	if pays == "" or str(s["nation"].get("pays", "")) == pays:
		return false
	if attente_nation(s, maintenant) > 0:
		return false
	s["nation"] = {"pays": pays, "depuis": maintenant}
	return true


## Camps du match tenus par un favori : [] , ["home"], ["away"] ou les deux.
static func camps_favoris(s: Dictionary, m: Dictionary) -> Array:
	var sel := Fiction.est_selection(m)
	var out: Array = []
	for cote in ["home", "away"]:
		if est_favori(s, cle_equipe(m.get(cote, {}), sel)):
			out.append(cote)
	return out


# ------------------------------------------------------------------ points

static func jour_de(t: int) -> String:
	return Time.get_date_string_from_unix_time(t)


## Ajoute des points à une équipe favorite. Renvoie les points vraiment comptés
## (0 si ce n'est pas un favori ou si le plafond du jour est atteint).
static func donner(s: Dictionary, cle: String, points: int, raison: String, maintenant: int) -> int:
	if points <= 0 or not est_favori(s, cle):
		return 0
	var jour := jour_de(maintenant)
	if s["jour"] != jour:
		s["jour"] = jour
		s["du_jour"] = {}
	var deja := int(s["du_jour"].get(cle, 0))
	var n := mini(points, MAX_PAR_JOUR - deja)
	if n <= 0:
		return 0
	s["du_jour"][cle] = deja + n
	s["points"][cle] = int(s["points"].get(cle, 0)) + n
	s["a_envoyer"].append({"equipe": cle, "points": n, "raison": raison, "t": maintenant})
	if s["a_envoyer"].size() > MAX_A_ENVOYER:
		s["a_envoyer"] = s["a_envoyer"].slice(-MAX_A_ENVOYER)
	return n


## `gain` : multiplicateur du lieu où tu suis le match (Game.MODES_SUIVI, ×1,5 au stade).
static func points_duel(gagne: bool, gain: float) -> int:
	return int(round((POINTS_DUEL + (POINTS_DUEL_GAGNE if gagne else 0)) * gain))


## Duel joué pour le camp `camp` du match `m`.
static func noter_duel(s: Dictionary, m: Dictionary, camp: String, gagne: bool, gain: float, maintenant: int) -> int:
	var cle := cle_equipe(m.get(camp, {}), Fiction.est_selection(m))
	return donner(s, cle, points_duel(gagne, gain), "duel", maintenant)


## Départ pour suivre un match (stade, écran géant, pub, maison) : une fois par match.
static func noter_suivi(s: Dictionary, m: Dictionary, camp: String, mode_suivi: String, maintenant: int) -> int:
	var id := str(m.get("id", ""))
	if id == "" or id in s["suivis"]:
		return 0
	var cle := cle_equipe(m.get(camp, {}), Fiction.est_selection(m))
	var n := donner(s, cle, int(POINTS_SUIVI.get(mode_suivi, 0)), "suivi", maintenant)
	if n > 0:
		s["suivis"].append(id)
		if s["suivis"].size() > MAX_MATCHS_SUIVIS:
			s["suivis"] = s["suivis"].slice(-MAX_MATCHS_SUIVIS)
	return n


static func points_prono(r: Dictionary) -> int:
	if str(r.get("etat", "")) == "annule":
		return 0
	var n := POINTS_PRONO
	if r.get("resultat_ok", false):
		n += POINTS_PRONO_RESULTAT
	if r.get("score_ok", false):
		n += POINTS_PRONO_SCORE
	return n


## Pronostic résolu : chaque favori du match reçoit les points.
static func noter_prono(s: Dictionary, m: Dictionary, r: Dictionary, maintenant: int) -> int:
	var sel := Fiction.est_selection(m)
	var total := 0
	for cote in camps_favoris(s, m):
		total += donner(s, cle_equipe(m.get(cote, {}), sel), points_prono(r), "prono", maintenant)
	return total


## Récolte de la caisse du fan club : tes membres font parler de tes équipes.
static func noter_club(s: Dictionary, jetons_recoltes: int, maintenant: int) -> int:
	var n := clampi(jetons_recoltes / JETONS_PAR_POINT_CLUB, 0, MAX_POINTS_CLUB)
	var total := 0
	if n <= 0:
		return 0
	for cle in cles_favorites(s):
		total += donner(s, cle, n, "club", maintenant)
	return total


# ------------------------------------------------------------------ classement

## Points des autres supporters (simulés tant que le jeu n'est pas en ligne) :
## toujours les mêmes pour une équipe, et ils grandissent chaque jour.
## Les clubs connus (noms choisis à la main) ont plus de supporters.
static func base_communaute(cle: String, connu: bool, maintenant: int) -> int:
	var g := Fiction.graine(cle + "|pop")
	connu = connu or (est_nation(cle) and cle.trim_prefix("nation:") in GRANDES_NATIONS)
	var base := 300 + g % 2500
	if connu:
		base += 6000 + (g / 7) % 9000
	if est_nation(cle):
		base += 2000 + (g / 13) % 6000
	var jours := maxi(0, (maintenant - DEBUT_SAISON) / 86400)
	var par_jour := 5 + (g / 101) % 40 + (60 if connu else 0)
	return base + jours * par_jour


## Classement trié. `equipes` : [{"cle", "nom", ...}] ; `communaute` : clé ->
## points des autres (serveur plus tard) ; `joueur` : clé -> points du joueur.
## Ajoute "points", "rang" et "a_toi" (points du joueur) à chaque ligne.
static func classement(equipes: Array, communaute: Dictionary, joueur: Dictionary) -> Array:
	var lignes: Array = []
	for e in equipes:
		var l: Dictionary = e.duplicate()
		var cle := str(e["cle"])
		l["a_toi"] = int(joueur.get(cle, 0))
		l["points"] = int(communaute.get(cle, 0)) + l["a_toi"]
		lignes.append(l)
	lignes.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return str(a["cle"]) < str(b["cle"]))
	for i in lignes.size():
		lignes[i]["rang"] = i + 1
	return lignes
