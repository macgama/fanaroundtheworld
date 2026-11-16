class_name Missions
extends RefCounted
## Missions du jour et de la semaine, sans affichage.
##
## Chaque jour, 3 missions courtes ; chaque semaine (du lundi au dimanche),
## 3 missions plus longues. Elles rapportent des Jetons et de l'XP de PASS.
## Le tirage dépend seulement de la date : le même jour donne les mêmes
## missions, même après un redémarrage.
##
## Pas de connexion obligatoire : une mission terminée mais pas encore
## récupérée est versée automatiquement au renouvellement, et les missions
## de la semaine rapportent le plus, pour qu'un joueur qui passe une ou deux
## fois par semaine avance quand même.
##
## Événements (Missions.noter) et leur « clé » facultative :
##   suivre         départ pour un match         clé = stade|ecran|pub|maison
##   suivre_pays    départ pour un match         clé = pays du match
##   nouveau_stade  premier tampon d'un stade
##   duel_joue      fin d'une partie             clé = duel|arene|poussee
##   duel_gagne     partie gagnée                clé = duel|arene|poussee
##   prono          nouveau pronostic
##   prono_bon      pronostic résolu avec le bon résultat
##   buvette        service à la buvette terminé
##   ramasseur      partie de ramasseur de balles terminée
##   boulot         partie d'un petit boulot terminée (clé = id du boulot)
##   tifo           service de peintre de tifo terminé
##   recolte        caisse du fan club récoltée
##   favori         une équipe favorite a gagné des points (duel ou match suivi)
##   evenement      duel joué pendant un événement   clé = finale|derby|demi|choc|nations|quart

const NB_JOUR := 3
const NB_SEMAINE := 3
## Une mission du jour peut être changée une fois par jour.
const CHANGEMENTS_PAR_JOUR := 1
## Bonus quand les 3 missions de la période sont récupérées.
const BONUS := {
	"jour": {"jetons": 10, "xp_pass": 50},
	"semaine": {"jetons": 50, "xp_pass": 250},
}

## Modèles de missions. « cle » : seuls les événements avec cette clé comptent.
## « distinct » : on compte des clés différentes (ex. 3 pays différents).
## « si » : condition pour proposer la mission (club = fan club créé,
## favoris = au moins une équipe favorite, evenements = un derby, une finale…
## au calendrier).
const JOUR := [
	{"id": "j_suivre1", "evt": "suivre", "n": 1, "titre": "Suis un match", "texte": "Au stade, au pub, sur écran géant ou à la maison.", "jetons": 15, "xp_pass": 50},
	{"id": "j_suivre3", "evt": "suivre", "n": 3, "titre": "Suis 3 matchs", "texte": "Peu importe où : l'important, c'est de chanter !", "jetons": 25, "xp_pass": 75},
	{"id": "j_ecran", "evt": "suivre", "cle": "ecran", "n": 1, "titre": "Rejoins une fan zone", "texte": "Suis un match sur l'écran géant d'une ville.", "jetons": 15, "xp_pass": 50},
	{"id": "j_pub", "evt": "suivre", "cle": "pub", "n": 1, "titre": "Ambiance au pub", "texte": "Suis un match au pub avec les supporters du coin.", "jetons": 15, "xp_pass": 50},
	{"id": "j_duel2", "evt": "duel_joue", "n": 2, "titre": "Joue 2 duels", "texte": "Jauge d'ambiance, Arène ou Poussée.", "jetons": 20, "xp_pass": 60},
	{"id": "j_gagne1", "evt": "duel_gagne", "n": 1, "titre": "Gagne un duel", "texte": "Fais plus de bruit que la tribune d'en face.", "jetons": 20, "xp_pass": 75},
	{"id": "j_ambiance", "evt": "duel_joue", "cle": "duel", "n": 1, "titre": "Lance la jauge d'ambiance", "texte": "Chant, tifo et ola : joue un duel d'ambiance.", "jetons": 15, "xp_pass": 50},
	{"id": "j_arene", "evt": "duel_joue", "cle": "arene", "n": 1, "titre": "Passe par l'Arène", "texte": "Joue une partie d'Arène, 3 FANZZY contre 3.", "jetons": 15, "xp_pass": 50},
	{"id": "j_poussee", "evt": "duel_joue", "cle": "poussee", "n": 1, "titre": "Tente une Poussée", "texte": "Pousse le ballon jusqu'à la tribune d'en face.", "jetons": 15, "xp_pass": 50},
	{"id": "j_prono2", "evt": "prono", "n": 2, "titre": "Fais 2 pronostics", "texte": "Gratuits et sans mise, sur les vrais matchs.", "jetons": 15, "xp_pass": 50},
	{"id": "j_buvette", "evt": "buvette", "n": 1, "titre": "Coup de main à la buvette", "texte": "Fais un service de vendeur.", "jetons": 15, "xp_pass": 50},
	{"id": "j_ramasseur", "evt": "ramasseur", "n": 1, "titre": "Ramasseur de balles", "texte": "Fais une partie de ramasseur de balles.", "jetons": 15, "xp_pass": 50},
	{"id": "j_tifo", "evt": "tifo", "n": 1, "titre": "Coup de pinceau", "texte": "Peins des tifos pour le capo.", "jetons": 15, "xp_pass": 50},
	{"id": "j_recolte", "evt": "recolte", "n": 1, "titre": "Passe à la caisse", "texte": "Récolte les recettes de ton fan club.", "jetons": 10, "xp_pass": 100, "si": "club"},
	{"id": "j_favori", "evt": "favori", "n": 1, "titre": "Soutiens tes couleurs", "texte": "Suis ou joue un duel pour une de tes équipes favorites.", "jetons": 20, "xp_pass": 120, "si": "favoris"},
]

const SEMAINE := [
	{"id": "s_stade", "evt": "nouveau_stade", "n": 1, "titre": "Visite un nouveau stade", "texte": "Va au stade dans une enceinte jamais tamponnée.", "jetons": 60, "xp_pass": 250},
	{"id": "s_stades2", "evt": "nouveau_stade", "n": 2, "titre": "Explorateur", "texte": "Ajoute 2 nouveaux tampons de stade à ton carnet.", "jetons": 90, "xp_pass": 300},
	{"id": "s_stade3", "evt": "suivre", "cle": "stade", "n": 3, "titre": "Abonné du virage", "texte": "Suis 3 matchs au stade.", "jetons": 80, "xp_pass": 250},
	{"id": "s_suivre7", "evt": "suivre", "n": 7, "titre": "Suis 7 matchs", "texte": "Une semaine bien remplie de football.", "jetons": 70, "xp_pass": 250},
	{"id": "s_pays3", "evt": "suivre_pays", "distinct": true, "n": 3, "titre": "Tour du monde", "texte": "Suis des matchs dans 3 pays différents.", "jetons": 80, "xp_pass": 300},
	{"id": "s_gagne5", "evt": "duel_gagne", "n": 5, "titre": "Gagne 5 duels", "texte": "Tous les modes comptent.", "jetons": 80, "xp_pass": 300},
	{"id": "s_modes", "evt": "duel_joue", "distinct": true, "n": 3, "titre": "Touche-à-tout", "texte": "Joue au moins une fois l'ambiance, l'Arène et la Poussée.", "jetons": 70, "xp_pass": 250},
	{"id": "s_duel10", "evt": "duel_joue", "n": 10, "titre": "Joue 10 duels", "texte": "Ta tribune ne s'arrête jamais !", "jetons": 70, "xp_pass": 250},
	{"id": "s_prono3", "evt": "prono_bon", "n": 3, "titre": "Devin de la semaine", "texte": "Trouve le bon résultat de 3 matchs.", "jetons": 70, "xp_pass": 250},
	{"id": "s_buvette5", "evt": "buvette", "n": 5, "titre": "Pilier de la buvette", "texte": "Fais 5 services de vendeur.", "jetons": 60, "xp_pass": 200},
	{"id": "s_recolte5", "evt": "recolte", "n": 5, "titre": "Trésorier du club", "texte": "Récolte 5 fois la caisse du fan club.", "jetons": 50, "xp_pass": 400, "si": "club"},
	{"id": "s_tournoi3", "evt": "tournoi", "n": 3, "titre": "Esprit de compétition", "texte": "Joue 3 duels du tournoi des fan clubs, le week-end.", "jetons": 60, "xp_pass": 300, "si": "tournoi"},
	{"id": "s_fete2", "evt": "evenement", "n": 2, "titre": "Soirs de fête", "texte": "Joue 2 duels sur des matchs spéciaux : derby, finale, Grand Choc…", "jetons": 70, "xp_pass": 250, "si": "evenements"},
	{"id": "s_favori5", "evt": "favori", "n": 5, "titre": "Fidèle au poste", "texte": "Soutiens 5 fois une de tes équipes favorites.", "jetons": 80, "xp_pass": 500, "si": "favoris"},
]


static func vide() -> Dictionary:
	return {
		"jour": "", "du_jour": [], "changements": 0, "bonus_jour": false,
		"semaine": "", "de_la_semaine": [], "bonus_semaine": false,
		"matchs_suivis": [],  # derniers matchs suivis (un match ne compte qu'une fois)
	}


static func reparer(d: Variant) -> Dictionary:
	var e := vide()
	if d is Dictionary:
		for k in e:
			if d.has(k) and typeof(d[k]) == typeof(e[k]):
				e[k] = d[k]
	for liste in [e["du_jour"], e["de_la_semaine"]]:
		for m in liste:
			m["progres"] = int(m.get("progres", 0))
			if not m.has("vus"):
				m["vus"] = []
	return e


# ------------------------------------------------------------------ dates

## Date locale « 2026-11-15 ». `t_local` = heure unix décalée au fuseau du joueur.
static func cle_jour(t_local: int) -> String:
	return Time.get_date_string_from_unix_time(t_local)


## Semaine du lundi au dimanche : « S2026-11-09 » (date de son lundi).
static func cle_semaine(t_local: int) -> String:
	var jours := floori(t_local / 86400.0)
	var lundi := jours - posmod(jours + 3, 7)  # le 1er janvier 1970 était un jeudi
	return "S" + Time.get_date_string_from_unix_time(lundi * 86400)


## Secondes avant le prochain renouvellement (minuit local ou lundi minuit).
static func avant_renouvellement(t_local: int, periode: String) -> int:
	var jours := floori(t_local / 86400.0)
	var fin := jours + 1
	if periode == "semaine":
		fin = jours - posmod(jours + 3, 7) + 7
	return fin * 86400 - t_local


# ------------------------------------------------------------------ tirage

static func _autorise(modele: Dictionary, ctx: Dictionary) -> bool:
	var si := str(modele.get("si", ""))
	return si == "" or bool(ctx.get(si, false))


static func _nouvelle(modele: Dictionary) -> Dictionary:
	return {
		"id": modele["id"], "evt": modele["evt"], "cle": str(modele.get("cle", "")),
		"distinct": bool(modele.get("distinct", false)), "n": int(modele["n"]),
		"titre": modele["titre"], "texte": modele["texte"],
		"jetons": int(modele["jetons"]), "xp_pass": int(modele["xp_pass"]),
		"progres": 0, "vus": [], "recuperee": false,
	}


## Ordre de tirage du jour/de la semaine : toujours le même pour une même date.
static func _ordre(modeles: Array, graine: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("missions:" + graine)
	var ordre := modeles.duplicate()
	for i in range(ordre.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = ordre[i]
		ordre[i] = ordre[j]
		ordre[j] = tmp
	return ordre


## Tire `nb` missions, sans deux missions sur le même événement si possible.
static func tirer(modeles: Array, graine: String, nb: int, ctx: Dictionary, exclure: Array = []) -> Array:
	var choisis: Array = []
	var evts: Array = []
	var ordre := _ordre(modeles, graine).filter(func(m): return _autorise(m, ctx) and not m["id"] in exclure)
	for passe in 2:
		for m in ordre:
			if choisis.size() >= nb:
				break
			if m in choisis or (passe == 0 and m["evt"] in evts):
				continue
			choisis.append(m)
			evts.append(m["evt"])
	return choisis.map(func(m): return _nouvelle(m))


static func _modele(modeles: Array, id: String) -> Dictionary:
	for m in modeles:
		if m["id"] == id:
			return m
	return {}


## Renouvelle les missions si le jour ou la semaine a changé.
## Renvoie les gains versés automatiquement pour les missions terminées
## mais pas récupérées : {"jetons", "xp_pass", "missions": [titres]}.
static func actualiser(e: Dictionary, t_local: int, ctx: Dictionary) -> Dictionary:
	var verse := {"jetons": 0, "xp_pass": 0, "missions": []}
	var jour := cle_jour(t_local)
	if e["jour"] != jour:
		_verser_restes(e["du_jour"], verse)
		e["jour"] = jour
		e["du_jour"] = tirer(JOUR, jour, NB_JOUR, ctx)
		e["changements"] = 0
		e["bonus_jour"] = false
	var sem := cle_semaine(t_local)
	if e["semaine"] != sem:
		_verser_restes(e["de_la_semaine"], verse)
		e["semaine"] = sem
		e["de_la_semaine"] = tirer(SEMAINE, sem, NB_SEMAINE, ctx)
		e["bonus_semaine"] = false
	return verse


static func _verser_restes(liste: Array, verse: Dictionary) -> void:
	for m in liste:
		if terminee(m) and not m["recuperee"]:
			m["recuperee"] = true
			verse["jetons"] += int(m["jetons"])
			verse["xp_pass"] += int(m["xp_pass"])
			verse["missions"].append(m["titre"])


# ------------------------------------------------------------------ progression

static func terminee(m: Dictionary) -> bool:
	return int(m["progres"]) >= int(m["n"])


## Compte un événement. Renvoie les missions qui viennent d'être terminées.
static func noter(e: Dictionary, evt: String, cle := "", n := 1) -> Array:
	var finies: Array = []
	for m in e["du_jour"] + e["de_la_semaine"]:
		if m["evt"] != evt or terminee(m):
			continue
		if m["cle"] != "" and m["cle"] != cle:
			continue
		if m["distinct"]:
			if cle == "" or cle in m["vus"]:
				continue
			m["vus"].append(cle)
			m["progres"] = m["vus"].size()
		else:
			m["progres"] = mini(int(m["progres"]) + n, int(m["n"]))
		if terminee(m):
			finies.append(m)
	return finies


## Récupère la récompense d'une mission terminée (periode = "jour" ou "semaine").
## Renvoie {"jetons", "xp_pass", "bonus": bool} ou {} si impossible.
static func recuperer(e: Dictionary, periode: String, index: int) -> Dictionary:
	var liste: Array = e["du_jour"] if periode == "jour" else e["de_la_semaine"]
	if index < 0 or index >= liste.size():
		return {}
	var m: Dictionary = liste[index]
	if not terminee(m) or m["recuperee"]:
		return {}
	m["recuperee"] = true
	var g := {"jetons": int(m["jetons"]), "xp_pass": int(m["xp_pass"]), "bonus": false}
	var cle_bonus := "bonus_" + periode
	if not e[cle_bonus] and liste.all(func(x): return x["recuperee"]):
		e[cle_bonus] = true
		g["bonus"] = true
		g["jetons"] += int(BONUS[periode]["jetons"])
		g["xp_pass"] += int(BONUS[periode]["xp_pass"])
	return g


## Nombre de récompenses prêtes à être récupérées (pour la pastille du bouton).
static func a_recuperer(e: Dictionary) -> int:
	var n := 0
	for m in e["du_jour"] + e["de_la_semaine"]:
		if terminee(m) and not m["recuperee"]:
			n += 1
	return n


## Remplace une mission du jour pas encore terminée (une fois par jour).
static func peut_changer(e: Dictionary, index: int) -> bool:
	if int(e["changements"]) >= CHANGEMENTS_PAR_JOUR:
		return false
	if index < 0 or index >= e["du_jour"].size():
		return false
	return not terminee(e["du_jour"][index])


static func changer(e: Dictionary, index: int, ctx: Dictionary) -> bool:
	if not peut_changer(e, index):
		return false
	var deja: Array = e["du_jour"].map(func(m): return m["id"])
	var evts: Array = e["du_jour"].map(func(m): return m["evt"])
	var candidats := tirer(JOUR, "%s/changement" % e["jour"], JOUR.size(), ctx, deja)
	if candidats.is_empty():
		return false
	var choix: Dictionary = candidats[0]
	for c in candidats:
		if not c["evt"] in evts:
			choix = c
			break
	e["du_jour"][index] = choix
	e["changements"] = int(e["changements"]) + 1
	return true


# ------------------------------------------------------------------ PASS

## Le PASS saisonnier : 100 paliers de 1 000 XP (voir docs/missions.md).
const XP_PAR_PALIER := 1000
const PALIERS := 100


static func palier(xp_pass: int) -> int:
	return mini(1 + xp_pass / XP_PAR_PALIER, PALIERS)


## XP déjà gagnée dans le palier en cours (pleine au dernier palier).
static func xp_dans_palier(xp_pass: int) -> int:
	if palier(xp_pass) >= PALIERS:
		return mini(xp_pass - (PALIERS - 1) * XP_PAR_PALIER, XP_PAR_PALIER)
	return xp_pass % XP_PAR_PALIER
