class_name Tournoi
extends RefCounted
## Tournoi des fan clubs du week-end, sans écran ni réseau (testable).
##
## Chaque week-end, du vendredi 00:00 au lundi 12:00 (UTC), les fan clubs des
## joueurs s'affrontent sur les vrais matchs du week-end :
##   - on s'inscrit avec un nom de tournoi (deux mots des listes, pas de texte
##     libre : le classement reste familial sans modération) et ses couleurs ;
##   - chaque duel joué (ambiance, Arène ou Poussée, contre l'ordinateur) sur un
##     match du week-end compte comme un duel contre un autre fan club : le
##     serveur tire l'adversaire parmi les clubs inscrits (ou un club du jeu) ;
##   - au plus DUELS_MAX duels, chacun sur un match différent et contre un club
##     différent : rejouer le même match ne rapporte pas de points de tournoi
##     (et ses Jetons suivent la règle 100 % / 50 % / 25 % / 0 des matchs rejoués) ;
##   - quand un club perd contre le tien, ta tribune « tient bon » : +1 point
##     (au plus DEFENSE_MAX par week-end) ;
##   - le lundi, chaque club réclame sa récompense : un palier selon ses points,
##     et un bonus de classement s'il y a assez de clubs.
## Le serveur (Worker, macgama/fanaroundtheworld-data, src/tournoi.js) refait
## les mêmes contrôles. Hors ligne, on joue contre les clubs du jeu.

const DUELS_MAX := 7
const DEFENSE_MAX := 6
const POINTS_VICTOIRE := 3
const POINTS_DEFAITE := 1
const BONUS_STADE := 1      # duel joué en suivant le match au stade
const BONUS_EVENEMENT := 1  # derby, finale, Grand Choc…

## Fenêtre : vendredi 00:00 UTC + 3,5 jours (fin le lundi 12:00 UTC).
## Les matchs comptent jusqu'au lundi 06:00 (le dimanche soir des Amériques).
const DUREE_S := 302400
const FIN_MATCHS_S := 280800
const SEMAINE_S := 604800

## Paliers de récompense selon les points (le plus haut atteint).
const PALIERS := [
	{"points": 28, "titre": "Tribune de légende", "jetons": 150, "xp_pass": 400},
	{"points": 20, "titre": "Tribune en feu", "jetons": 100, "xp_pass": 300},
	{"points": 12, "titre": "Tribune solide", "jetons": 60, "xp_pass": 200},
	{"points": 5, "titre": "Tribune engagée", "jetons": 30, "xp_pass": 100},
]
## Bonus de classement : seulement avec au moins CLUBS_MIN_BONUS clubs classés.
const CLUBS_MIN_BONUS := 10
const BONUS_RANG := [
	{"rang": 1, "titre": "Champion du week-end", "jetons": 150},
	{"rang": 2, "titre": "2e du week-end", "jetons": 100},
	{"rang": 3, "titre": "3e du week-end", "jetons": 75},
	{"rang": 10, "titre": "Top 10", "jetons": 40},
]
const BONUS_QUART := {"titre": "Top 25 %", "jetons": 20}

## Noms de tournoi : « Kop » + « du Tonnerre ». Le serveur reçoit les numéros.
## On peut ajouter des mots à la fin (64 au plus), jamais en retirer ni réordonner.
const TYPES := [
	"Ultras", "Kop", "Brigade", "Fanfare", "Tribune", "Légion", "Clan", "Bande",
	"Virage", "Meute", "Tempête", "Armada", "Cohorte", "Escouade", "Caravane", "Tornade",
]
const COMPLEMENTS := [
	"du Canal", "des Volcans", "du Tonnerre", "de la Lune", "des Sommets", "du Port",  # sans_traduction
	"des Étoiles", "du Grand Nord", "de la Vallée", "des Remparts", "du Phare", "des Comètes",  # sans_traduction
	"de l'Océan", "du Désert", "de la Forêt", "des Collines", "du Soleil", "des Marais",  # sans_traduction
	"du Métro", "des Dunes",  # sans_traduction
]
const NB_BOTS := 15


static func vide() -> Dictionary:
	return {
		"id": "",               # vendredi du tournoi, « 2026-11-13 »
		"inscrit": false,
		"inscrit_serveur": false,
		"nom": [0, 0],          # [TYPES, COMPLEMENTS]
		"couleurs": [0, 7],     # numéros dans FanClub.COULEURS
		"duels": [],            # {match, adv, nom_adv, gagne, stade, evenement, pts, t, envoye}
		"adversaire": {},       # prochain adversaire {id, nom, couleurs, niveau, bot}
		"defense": 0,           # points « tribune qui tient bon » (d'après le serveur)
		"rang": 0,              # d'après le serveur (0 = inconnu)
		"clubs": 0,
		"a_reclamer": {},       # tournoi fini, récompense pas encore prise
		"historique": [],       # derniers tournois {id, points, rang, clubs, jetons, xp_pass}
	}


static func reparer(d: Variant) -> Dictionary:
	var r := vide()
	if d is Dictionary:
		for k in r:
			if d.has(k) and typeof(d[k]) == typeof(r[k]):
				r[k] = d[k]
	r["nom"] = nom_valide(r["nom"])
	var c: Array = r["couleurs"]
	if c.size() != 2:
		r["couleurs"] = [0, 7]
	else:
		r["couleurs"] = [clampi(int(c[0]), 0, 63), clampi(int(c[1]), 0, 63)]
	r["duels"] = (r["duels"] as Array).filter(func(x): return x is Dictionary and x.has("match"))
	return r


static func nom_valide(n: Variant) -> Array:
	if not n is Array or n.size() != 2:
		return [0, 0]
	return [clampi(int(n[0]), 0, TYPES.size() - 1), clampi(int(n[1]), 0, COMPLEMENTS.size() - 1)]


## « Kop du Tonnerre ». Un numéro inconnu (liste plus récente) reste lisible.
static func nom_texte(n: Variant) -> String:
	if not n is Array or n.size() != 2:
		return "Club mystère"
	var a := int(n[0])
	var b := int(n[1])
	var t: String = TYPES[a] if a >= 0 and a < TYPES.size() else "Club"  # sans_traduction
	var c: String = COMPLEMENTS[b] if b >= 0 and b < COMPLEMENTS.size() else "mystère"  # sans_traduction
	return "%s %s" % [t, c]


## Nom de départ proposé : tiré de la graine (le fan club n'a qu'un nom libre).
static func nom_au_hasard(rng: RandomNumberGenerator) -> Array:
	return [rng.randi() % TYPES.size(), rng.randi() % COMPLEMENTS.size()]


static func couleur(i: Variant) -> Color:
	var n := int(i)
	return Color(FanClub.COULEURS[n]) if n >= 0 and n < FanClub.COULEURS.size() else Color("#888888")


## Numéro d'une couleur du fan club dans FanClub.COULEURS (0 si absente).
static func index_couleur(hexa: String) -> int:
	var c := Color(hexa)
	for i in FanClub.COULEURS.size():
		if Color(FanClub.COULEURS[i]).is_equal_approx(c):
			return i
	return 0


# ------------------------------------------------------------------ calendrier

## Le tournoi qui court (ou le dernier fini) à l'heure `t` (secondes UTC).
## {etat: "actif"|"attente", id, debut, fin, fin_matchs, prochain}
static func fenetre(t: int) -> Dictionary:
	var jour := floori(float(t) / 86400.0)
	var depuis_vendredi := posmod(posmod(jour + 3, 7) - 4, 7)  # lundi = 0 … vendredi = 4
	var debut := (jour - depuis_vendredi) * 86400
	var fin := debut + DUREE_S
	return {
		"etat": "actif" if t < fin else "attente",
		"id": Time.get_date_string_from_unix_time(debut),
		"debut": debut, "fin": fin, "fin_matchs": debut + FIN_MATCHS_S,
		"prochain": debut + SEMAINE_S,
	}


## Le match a-t-il lieu pendant le week-end du tournoi ?
static func match_du_week_end(kickoff: int, f: Dictionary) -> bool:
	return kickoff >= int(f["debut"]) and kickoff < int(f["fin_matchs"])


## Change de tournoi si besoin. Le tournoi fini passe dans « a_reclamer »
## (s'il a rapporté des points). Renvoie true si l'état a changé.
static func actualiser(s: Dictionary, t: int) -> bool:
	var f := fenetre(t)
	var change := false
	var courant := str(f["id"]) if f["etat"] == "actif" else ""
	if s["id"] != "" and s["id"] != courant:
		if bool(s["inscrit"]) and points(s) > 0 and (s["a_reclamer"] as Dictionary).is_empty():
			s["a_reclamer"] = resume(s)
		var garde: Dictionary = s["a_reclamer"]
		var hist: Array = s["historique"]
		var nom: Array = s["nom"]
		var coul: Array = s["couleurs"]
		s.merge(vide(), true)
		s["a_reclamer"] = garde
		s["historique"] = hist
		s["nom"] = nom
		s["couleurs"] = coul
		change = true
	if courant != "" and s["id"] == "":
		s["id"] = courant
		change = true
	return change


static func resume(s: Dictionary) -> Dictionary:
	var gagnes := (s["duels"] as Array).filter(func(d): return bool(d.get("gagne", false))).size()
	return {"id": s["id"], "points": points(s), "rang": int(s["rang"]), "clubs": int(s["clubs"]),
		"duels": (s["duels"] as Array).size(), "gagnes": gagnes, "nom": s["nom"]}


# ------------------------------------------------------------------ duels

static func points_duel(gagne: bool, stade: bool, evenement: bool) -> int:
	return (POINTS_VICTOIRE if gagne else POINTS_DEFAITE) + (BONUS_STADE if stade else 0) + (BONUS_EVENEMENT if evenement else 0)


static func points(s: Dictionary) -> int:
	var n := 0
	for d in s["duels"]:
		n += int(d.get("pts", 0))
	return n + clampi(int(s.get("defense", 0)), 0, DEFENSE_MAX)


static func match_deja_joue(s: Dictionary, match_id: String) -> bool:
	for d in s["duels"]:
		if str(d["match"]) == match_id:
			return true
	return false


## "" si un duel sur ce match peut compter pour le tournoi, sinon la raison.
static func raison_refus(s: Dictionary, match_id: String, kickoff: int, t: int) -> String:
	var f := fenetre(t)
	if f["etat"] != "actif":
		return "Pas de tournoi en cours"
	if not bool(s["inscrit"]) or s["id"] != f["id"]:
		return "Pas inscrit au tournoi"
	if not match_du_week_end(kickoff, f):
		return "Match hors du week-end du tournoi"
	if match_deja_joue(s, match_id):
		return "Match déjà joué pour le tournoi"
	if (s["duels"] as Array).size() >= DUELS_MAX:
		return Trad.t("Les %d duels du tournoi sont joués") % DUELS_MAX
	return ""


## Adversaire du prochain duel : celui tiré par le serveur, sinon un club du jeu.
static func adversaire(s: Dictionary) -> Dictionary:
	var a: Dictionary = s["adversaire"]
	if not a.is_empty() and not deja_affronte(s, str(a.get("id", ""))):
		return a
	return prochain_bot(s)


static func deja_affronte(s: Dictionary, id: String) -> bool:
	for d in s["duels"]:
		if str(d.get("adv", "")) == id:
			return true
	return false


## Enregistre un duel du tournoi. Renvoie la ligne ajoutée, ou {} s'il ne compte pas.
static func noter_duel(s: Dictionary, match_id: String, kickoff: int, gagne: bool, stade: bool, evenement: bool, t: int) -> Dictionary:
	if raison_refus(s, match_id, kickoff, t) != "":
		return {}
	var adv := adversaire(s)
	var d := {
		"match": match_id, "adv": str(adv["id"]), "nom_adv": adv["nom"], "couleurs_adv": adv["couleurs"],
		"gagne": gagne, "stade": stade, "evenement": evenement,
		"pts": points_duel(gagne, stade, evenement), "t": t, "envoye": false,
	}
	s["duels"].append(d)
	s["adversaire"] = {}
	return d


static func a_envoyer(s: Dictionary) -> Array:
	return (s["duels"] as Array).filter(func(d): return not bool(d.get("envoye", false)))


# ------------------------------------------------------------------ clubs du jeu

## Club du jeu n° k pour ce tournoi (même résultat sur toutes les machines).
static func bot(id_tournoi: String, k: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s#%d" % [id_tournoi, k])
	var c1 := rng.randi() % FanClub.COULEURS.size()
	var c2 := (c1 + 1 + rng.randi() % (FanClub.COULEURS.size() - 1)) % FanClub.COULEURS.size()
	return {"id": "bot:%d" % k, "nom": [rng.randi() % TYPES.size(), rng.randi() % COMPLEMENTS.size()],
		"couleurs": [c1, c2], "niveau": 1 + rng.randi() % 12, "bot": true,
		"force": rng.randf_range(0.35, 1.0)}


static func prochain_bot(s: Dictionary) -> Dictionary:
	var k := 0
	while deja_affronte(s, "bot:%d" % k):
		k += 1
	return bot(str(s["id"]), k)


## Classement d'entraînement hors ligne : les clubs du jeu marquent au fil du week-end.
## [{rang, id, nom, couleurs, points, moi}]
static func classement_simule(s: Dictionary, t: int) -> Array:
	var f := fenetre(t)
	var avance := clampf(float(t - int(f["debut"])) / float(DUREE_S), 0.0, 1.0)
	var lignes: Array = []
	for k in NB_BOTS:
		var b := bot(str(f["id"]), k)
		var pts := int(round(float(b["force"]) * 28.0 * avance))
		if pts > 0:
			lignes.append({"id": b["id"], "nom": b["nom"], "couleurs": b["couleurs"], "points": pts, "moi": false})
	if bool(s["inscrit"]):
		lignes.append({"id": "moi", "nom": s["nom"], "couleurs": s["couleurs"], "points": points(s), "moi": true})
	lignes.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return a["moi"] and not b["moi"])
	for i in lignes.size():
		lignes[i]["rang"] = i + 1
	return lignes


# ------------------------------------------------------------------ récompenses

static func palier(pts: int) -> Dictionary:
	for p in PALIERS:
		if pts >= int(p["points"]):
			return p
	return {}


static func bonus_classement(rang: int, clubs: int) -> Dictionary:
	if rang <= 0 or clubs < CLUBS_MIN_BONUS:
		return {}
	for b in BONUS_RANG:
		if rang <= int(b["rang"]):
			return b
	if rang <= int(ceil(clubs * 0.25)):
		return BONUS_QUART
	return {}


## {jetons, xp_pass, palier, bonus} pour un tournoi fini.
static func recompense(r: Dictionary) -> Dictionary:
	var p := palier(int(r.get("points", 0)))
	var b := bonus_classement(int(r.get("rang", 0)), int(r.get("clubs", 0)))
	return {
		"jetons": int(p.get("jetons", 0)) + int(b.get("jetons", 0)),
		"xp_pass": int(p.get("xp_pass", 0)),
		"palier": str(p.get("titre", "")), "bonus": str(b.get("titre", "")),
	}


## Prend la récompense du tournoi fini (une seule fois). Renvoie {} s'il n'y en a pas.
static func reclamer(s: Dictionary) -> Dictionary:
	var r: Dictionary = s["a_reclamer"]
	if r.is_empty():
		return {}
	var g := recompense(r)
	var h: Dictionary = r.duplicate()
	h["jetons"] = g["jetons"]
	h["xp_pass"] = g["xp_pass"]
	s["historique"].push_front(h)
	s["historique"] = (s["historique"] as Array).slice(0, 5)
	s["a_reclamer"] = {}
	return g


## Points du prochain palier à atteindre (0 si le plus haut est atteint).
static func prochain_palier(pts: int) -> Dictionary:
	var suivant := {}
	for p in PALIERS:
		if pts < int(p["points"]):
			suivant = p
	return suivant
