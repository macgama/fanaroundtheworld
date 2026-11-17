class_name Ligue
extends RefCounted
## Ligue des tribunes : une saison de duels en ligne par mois, sans écran ni réseau (testable).
##
##   - Saison = un mois (« 2026-11 »). Ses journées = les week-ends dont le vendredi
##     tombe dans le mois (4 ou 5), du vendredi 00:00 au lundi 12:00 (UTC), comme le
##     tournoi : on joue sur les vrais matchs du week-end.
##   - 5 divisions (1 = Ligue Étoile, la plus haute), en poules de 10 clubs. Les places
##     vides sont prises par des clubs du jeu dont les points avancent au fil des journées.
##   - Un duel en ligne contre un vrai joueur, pendant une journée et sur un match du
##     week-end, compte quand les DEUX joueurs ont envoyé le même résultat au serveur
##     (code du duel tiré par l'hôte). Sans adversaire en ligne, on peut défier un club
##     du jeu de sa poule (3 par journée).
##   - Points : victoire 3, nul 2, défaite 1, +1 si le vrai match est en direct.
##     6 duels par journée au plus, 2 au plus contre le même adversaire.
##   - Fin de saison : les 2 premiers montent, les 2 derniers descendent ; récompense
##     en Jetons et XP de PASS selon la division (jamais de skin).
## Le serveur (Worker, macgama/fanaroundtheworld-data, src/ligue.js) refait les mêmes
## calculs, clubs du jeu compris (même formule, sans aléatoire).

const DIVISIONS := 5
const TAILLE_POULE := 10
const MONTEES := 2
const DESCENTES := 2
const DUELS_JOURNEE := 6
const BOTS_JOURNEE := 3
const MEME_ADV_JOURNEE := 2
const POINTS_VICTOIRE := 3
const POINTS_NUL := 2
const POINTS_DEFAITE := 1
const BONUS_DIRECT := 1
const DUREE_S := 302400       # vendredi 00:00 -> lundi 12:00
const FIN_MATCHS_S := 280800  # matchs jusqu'au lundi 06:00
const PTS_BOT_JOURNEE := 12
const MOTS_BOTS := [16, 20]
const COULEURS_BOTS := 10
## Il faut au moins ce nombre de duels comptés dans la saison pour la récompense.
const DUELS_MIN_RECOMPENSE := 3

const NOMS_DIVISIONS := ["Ligue Étoile", "Ligue Or", "Ligue Argent", "Ligue Bronze", "Ligue Espoir"]
const COULEURS_DIVISIONS := ["#ffd23f", "#ffb02e", "#c9d3e6", "#d08a4e", "#3ddc84"]
## Récompense de fin de saison selon la division (index 0 = division 1).
const RECOMPENSES := [
	{"jetons": 200, "xp_pass": 500},
	{"jetons": 150, "xp_pass": 400},
	{"jetons": 110, "xp_pass": 320},
	{"jetons": 80, "xp_pass": 260},
	{"jetons": 50, "xp_pass": 200},
]
const BONUS_CHAMPION := 100
const BONUS_MONTEE := 50


static func vide() -> Dictionary:
	return {
		"saison": "",
		"inscrit": false,
		"inscrit_serveur": false,
		"nom": [0, 0],          # numéros dans Tournoi.TYPES / Tournoi.COMPLEMENTS
		"couleurs": [0, 7],     # numéros dans FanClub.COULEURS
		"division": DIVISIONS,
		"poule": 0,
		"duels": [],            # {code, adv, nom_adv, couleurs_adv, bot, gagne, direct, match, journee, t, envoye, etat, pts}
		"serveur": {},          # dernière réponse « club » du serveur
		"a_reclamer": {},
		"historique": [],       # dernières saisons {saison, division, rang, mouvement, points, jetons, xp_pass}
	}


static func reparer(d: Variant) -> Dictionary:
	var r := vide()
	if d is Dictionary:
		for k in r:
			if d.has(k) and typeof(d[k]) == typeof(r[k]):
				r[k] = d[k]
	r["nom"] = Tournoi.nom_valide(r["nom"])
	var c: Array = r["couleurs"]
	r["couleurs"] = [0, 7] if c.size() != 2 else [clampi(int(c[0]), 0, 63), clampi(int(c[1]), 0, 63)]
	r["division"] = clampi(int(r["division"]), 1, DIVISIONS)
	r["poule"] = maxi(0, int(r["poule"]))
	r["duels"] = (r["duels"] as Array).filter(func(x): return x is Dictionary and x.has("code"))
	return r


static func nom_division(d: int) -> String:
	return Trad.t(NOMS_DIVISIONS[clampi(d, 1, DIVISIONS) - 1])


static func couleur_division(d: int) -> Color:
	return Color(COULEURS_DIVISIONS[clampi(d, 1, DIVISIONS) - 1])


# ------------------------------------------------------------------ calendrier

static func _vendredi_de(t: int) -> int:
	var jour := floori(float(t) / 86400.0)
	return (jour - posmod(posmod(jour + 3, 7) - 4, 7)) * 86400


static func _mois(t: int) -> int:
	return int(Time.get_datetime_dict_from_unix_time(t)["month"])


## Journées de la saison « AAAA-MM » : [{n, id, debut, fin, fin_matchs}].
static func journees(saison: String) -> Array:
	var debut_mois := int(Time.get_unix_time_from_datetime_string(saison + "-01T00:00:00"))
	var mois := _mois(debut_mois)
	var v := _vendredi_de(debut_mois)
	if v < debut_mois:
		v += 7 * 86400
	var liste: Array = []
	while _mois(v) == mois:
		liste.append({"n": liste.size() + 1, "id": Time.get_date_string_from_unix_time(v),
			"debut": v, "fin": v + DUREE_S, "fin_matchs": v + FIN_MATCHS_S})
		v += 7 * 86400
	return liste


## {saison, etat: "journee"|"pause"|"finie", journee, journees, fin_saison, prochaine}
static func calendrier(t: int) -> Dictionary:
	var v := _vendredi_de(t)
	var saison := Time.get_date_string_from_unix_time(v).substr(0, 7)
	var js := journees(saison)
	var j: Dictionary = {}
	for x in js:
		if int(x["debut"]) == v:
			j = x
	var derniere: Dictionary = js[-1]
	var etat := "journee"
	if t >= int(j["fin"]):
		etat = "finie" if int(j["n"]) == js.size() else "pause"
	return {"saison": saison, "etat": etat, "journee": j, "journees": js, "fin_saison": int(derniere["fin"]),
		"prochaine": v if etat == "journee" else v + 7 * 86400}


static func saison_suivante(saison: String) -> String:
	var a := int(saison.substr(0, 4))
	var m := int(saison.substr(5, 2))
	return "%d-01" % (a + 1) if m == 12 else "%d-%02d" % [a, m + 1]


## Le match a-t-il lieu pendant la journée en cours ?
static func match_de_la_journee(kickoff: int, c: Dictionary) -> bool:
	if c["etat"] != "journee":
		return false
	var j: Dictionary = c["journee"]
	return kickoff >= int(j["debut"]) and kickoff < int(j["fin_matchs"])


## Avancée de la saison en millièmes de journée (une journée entière = 1000).
static func avancee(saison: String, t: int) -> int:
	var n := 0
	for j in journees(saison):
		n += clampi(floori(float(t - int(j["debut"])) * 1000.0 / float(DUREE_S)), 0, 1000)
	return n


# ------------------------------------------------------------------ clubs du jeu

## FNV-1a 32 bits, même calcul que le serveur.
static func fnv(texte: String) -> int:
	var h := 0x811c9dc5
	for b in texte.to_ascii_buffer():
		h = h ^ b
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h


## Produit sur 32 bits sans dépasser les entiers 64 bits de Godot.
static func _mul32(a: int, b: int) -> int:
	return (a * (b & 0xFFFF) + (((a * (b >> 16)) & 0xFFFF) << 16)) & 0xFFFFFFFF


## Mélange final (celui de MurmurHash3), même calcul que le serveur.
static func melange(h: int) -> int:
	h = h ^ (h >> 16)
	h = _mul32(h, 0x85ebca6b)
	h = h ^ (h >> 13)
	h = _mul32(h, 0xc2b2ae35)
	return h ^ (h >> 16)


static func bot(saison: String, division: int, poule: int, k: int) -> Dictionary:
	var h := melange(fnv("%s|%d|%d|%d" % [saison, division, poule, k]))
	var c1 := (h >> 4) % COULEURS_BOTS
	var c2 := (c1 + 1 + ((h >> 12) % (COULEURS_BOTS - 1))) % COULEURS_BOTS
	return {"id": "bot:%d" % k, "bot": true, "nom": [(h >> 16) % MOTS_BOTS[0], (h >> 20) % MOTS_BOTS[1]],
		"couleurs": [c1, c2], "force": 250 + ((h >> 8) % 650) + 40 * (DIVISIONS - division)}


static func points_bot(b: Dictionary, saison: String, t: int) -> int:
	return (int(b["force"]) * PTS_BOT_JOURNEE * avancee(saison, t)) / 1000000


static func points_duel(resultat: int, direct: bool) -> int:
	var p := POINTS_VICTOIRE if resultat > 0 else (POINTS_NUL if resultat == 0 else POINTS_DEFAITE)
	return p + (BONUS_DIRECT if direct else 0)


## -1 descente, 0 maintien, +1 montée.
static func mouvement(division: int, rang: int) -> int:
	if rang <= MONTEES and division > 1:
		return 1
	if rang > TAILLE_POULE - DESCENTES and division < DIVISIONS:
		return -1
	return 0


## Tri : points, puis les joueurs avant les clubs du jeu, puis l'identifiant.
static func trier(lignes: Array) -> Array:
	lignes.sort_custom(func(a, b):
		if int(a["points"]) != int(b["points"]):
			return int(a["points"]) > int(b["points"])
		if bool(a["bot"]) != bool(b["bot"]):
			return not bool(a["bot"])
		return str(a["id"]) < str(b["id"]))
	for i in lignes.size():
		lignes[i]["rang"] = i + 1
	return lignes


# ------------------------------------------------------------------ saison

## Change de saison si besoin : la saison finie passe dans « a_reclamer ».
## Renvoie true si l'état a changé.
static func actualiser(s: Dictionary, t: int) -> bool:
	var c := calendrier(t)
	if s["saison"] == c["saison"]:
		return false
	if s["saison"] != "" and bool(s["inscrit"]) and (s["a_reclamer"] as Dictionary).is_empty() and duels_comptes(s) > 0:
		s["a_reclamer"] = resume(s, int(journees(str(s["saison"]))[-1]["fin"]))
	var division := int(s["division"])
	if not (s["a_reclamer"] as Dictionary).is_empty() and str(s["a_reclamer"]["saison"]) == str(s["saison"]):
		division = clampi(division - int(s["a_reclamer"]["mouvement"]), 1, DIVISIONS)
	var garde := {"a_reclamer": s["a_reclamer"], "historique": s["historique"], "nom": s["nom"], "couleurs": s["couleurs"]}
	s.merge(vide(), true)
	s.merge(garde, true)
	s["division"] = division
	s["saison"] = c["saison"]
	return true


static func resume(s: Dictionary, t: int) -> Dictionary:
	var moi := ligne_moi(s, t)
	var rang := int(moi.get("rang", TAILLE_POULE))
	var sv: Dictionary = s["serveur"]
	if str(sv.get("saison", "")) == str(s["saison"]) and int(sv.get("rang", 0)) > 0:
		rang = int(sv["rang"])
	var div := int(s["division"])
	return {"saison": s["saison"], "division": div, "rang": rang, "mouvement": mouvement(div, rang),
		"points": points(s), "duels": duels_comptes(s)}


## Duels qui comptent (ou compteront) pour la saison.
static func _compte(d: Dictionary) -> bool:
	return str(d.get("etat", "")) in ["compte", "local", "attente"] and int(d.get("pts", 0)) > 0


static func duels_comptes(s: Dictionary) -> int:
	return (s["duels"] as Array).filter(func(d): return _compte(d) and str(d.get("etat", "")) != "attente").size()


## Points de la saison : ceux du serveur s'il a répondu, sinon le compte local.
static func points(s: Dictionary) -> int:
	var sv: Dictionary = s["serveur"]
	if str(sv.get("saison", "")) == str(s["saison"]) and sv.has("points"):
		return int(sv["points"])
	var n := 0
	for d in s["duels"]:
		if _compte(d):
			n += int(d["pts"])
	return n


## Duels de la journée `id` qui comptent : {n, bots, par_adv}
static func compteurs(s: Dictionary, journee_id: String) -> Dictionary:
	var r := {"n": 0, "bots": 0, "par_adv": {}}
	for d in s["duels"]:
		if str(d.get("journee", "")) != journee_id or not _compte(d):
			continue
		r["n"] += 1
		if bool(d.get("bot", false)):
			r["bots"] += 1
		r["par_adv"][d["adv"]] = int(r["par_adv"].get(d["adv"], 0)) + 1
	return r


## "" si un duel contre `adv` sur ce match peut compter, sinon la raison.
static func raison_refus(s: Dictionary, adv: String, kickoff: int, t: int) -> String:
	var c := calendrier(t)
	if not bool(s["inscrit"]) or s["saison"] != c["saison"]:
		return "Pas inscrit à la Ligue"
	if c["etat"] != "journee":
		return "Pas de journée de Ligue en cours"
	if not match_de_la_journee(kickoff, c):
		return "Match hors du week-end de la journée"
	var n := compteurs(s, str(c["journee"]["id"]))
	if int(n["n"]) >= DUELS_JOURNEE:
		return Trad.t("Les %d duels de la journée sont joués") % DUELS_JOURNEE
	if adv.begins_with("bot:") and int(n["bots"]) >= BOTS_JOURNEE:
		return Trad.t("%d duels contre les clubs du jeu par journée au plus") % BOTS_JOURNEE
	if int(n["par_adv"].get(adv, 0)) >= MEME_ADV_JOURNEE:
		return Trad.t("Déjà %d duels contre ce club cette journée") % MEME_ADV_JOURNEE
	return ""


## Enregistre un duel de ligue. `resultat` : 1 gagné, 0 nul, -1 perdu.
## Contre un vrai joueur, il reste « attente » jusqu'à la confirmation du serveur.
static func noter_duel(s: Dictionary, code: String, adv: Dictionary, match_id: String, kickoff: int, resultat: int, direct: bool, t: int) -> Dictionary:
	if raison_refus(s, str(adv["id"]), kickoff, t) != "":
		return {}
	var est_bot := bool(adv.get("bot", false))
	var d := {
		"code": code, "adv": str(adv["id"]), "nom_adv": adv.get("nom", [0, 0]), "couleurs_adv": adv.get("couleurs", [0, 7]),
		"bot": est_bot, "gagne": resultat > 0, "nul": resultat == 0, "direct": direct, "match": match_id,
		"journee": str(calendrier(t)["journee"]["id"]), "t": t, "envoye": false,
		"etat": "local" if est_bot else "attente", "pts": points_duel(resultat, direct),
	}
	s["duels"].append(d)
	return d


static func a_envoyer(s: Dictionary) -> Array:
	return (s["duels"] as Array).filter(func(d): return not bool(d.get("envoye", false)))


## Réponse « club » du serveur : points, rang, division, duels confirmés.
static func appliquer_serveur(s: Dictionary, club: Dictionary) -> void:
	if str(club.get("saison", "")) != str(s["saison"]):
		return
	s["serveur"] = {"saison": club["saison"], "points": int(club.get("points", 0)), "rang": int(club.get("rang", 0)),
		"mouvement": int(club.get("mouvement", 0)), "duels": int(club.get("duels", 0))}
	s["division"] = clampi(int(club.get("division", s["division"])), 1, DIVISIONS)
	s["poule"] = maxi(0, int(club.get("poule", s["poule"])))
	var comptes: Variant = club.get("comptes", {})
	if comptes is Dictionary:
		for d in s["duels"]:
			if comptes.has(d["code"]):
				d["envoye"] = true
				d["pts"] = int(comptes[d["code"]])
				d["etat"] = "compte" if int(d["pts"]) > 0 else "refuse"


## Duels en ligne jamais confirmés une fois la journée passée.
static func expirer(s: Dictionary, t: int) -> void:
	for d in s["duels"]:
		if str(d.get("etat", "")) != "attente":
			continue
		for j in journees(str(s["saison"])):
			if str(j["id"]) == str(d["journee"]) and t > int(j["fin"]) + 3600:
				d["etat"] = "non_confirme"


# ------------------------------------------------------------------ poule

## Poule locale (hors ligne) : toi + les clubs du jeu. [{rang, id, nom, couleurs, points, bot, moi}]
static func poule_locale(s: Dictionary, t: int) -> Array:
	var saison := str(s["saison"])
	var lignes: Array = [{"id": "moi", "bot": false, "nom": s["nom"], "couleurs": s["couleurs"], "points": points(s), "moi": true}]
	for k in TAILLE_POULE - 1:
		var b := bot(saison, int(s["division"]), int(s["poule"]), k)
		lignes.append({"id": b["id"], "bot": true, "nom": b["nom"], "couleurs": b["couleurs"], "points": points_bot(b, saison, t), "moi": false})
	return trier(lignes)


static func ligne_moi(s: Dictionary, t: int) -> Dictionary:
	for l in poule_locale(s, t):
		if l["moi"]:
			return l
	return {}


## Clubs du jeu de la poule qu'on peut défier (ceux de la poule du serveur s'il l'a envoyée).
static func bots_de_la_poule(s: Dictionary, poule_serveur: Dictionary, t: int) -> Array:
	var liste: Array = []
	if str(poule_serveur.get("saison", "")) == str(s["saison"]) and poule_serveur.get("clubs") is Array:
		for c in poule_serveur["clubs"]:
			if bool(c.get("bot", false)):
				liste.append(c)
		return liste
	for l in poule_locale(s, t):
		if l["bot"]:
			liste.append(l)
	return liste


# ------------------------------------------------------------------ récompenses

## {jetons, xp_pass, titres: [...]} d'une saison finie.
static func recompense(r: Dictionary) -> Dictionary:
	if int(r.get("duels", 0)) < DUELS_MIN_RECOMPENSE:
		return {"jetons": 0, "xp_pass": 0, "titres": []}
	var div := clampi(int(r.get("division", DIVISIONS)), 1, DIVISIONS)
	var base: Dictionary = RECOMPENSES[div - 1]
	var j := int(base["jetons"])
	var titres: Array = [Trad.t("Saison en %s") % nom_division(div)]
	if int(r.get("rang", 0)) == 1:
		j += BONUS_CHAMPION
		titres.append(Trad.t("Champion de poule"))
	if int(r.get("mouvement", 0)) > 0:
		j += BONUS_MONTEE
		titres.append(Trad.t("Montée en %s") % nom_division(div - 1))
	return {"jetons": j, "xp_pass": int(base["xp_pass"]), "titres": titres}


static func reclamer(s: Dictionary) -> Dictionary:
	var r: Dictionary = s["a_reclamer"]
	if r.is_empty():
		return {}
	var g := recompense(r)
	var h: Dictionary = r.duplicate()
	h["jetons"] = g["jetons"]
	h["xp_pass"] = g["xp_pass"]
	s["historique"].push_front(h)
	s["historique"] = (s["historique"] as Array).slice(0, 6)
	s["a_reclamer"] = {}
	return g


## « novembre 2026 » pour « 2026-11 ».
static func saison_texte(saison: String) -> String:
	var m := clampi(int(saison.substr(5, 2)), 1, 12)
	# « mars », « mai », « juin » et « août » servent aussi d'abréviations (dates
	# courtes) : leurs clés de traduction donnent « Mar », « May »… d'où les
	# noms anglais complets écrits ici.
	if not Trad.est_source():
		return "%s %s" % [["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"][m - 1], saison.substr(0, 4)]  # sans_traduction
	return "%s %s" % [["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"][m - 1], saison.substr(0, 4)]  # sans_traduction


## Code de duel : 16 chiffres hexadécimaux au hasard.
static func nouveau_code(rng: RandomNumberGenerator) -> String:
	return "%08x%08x" % [rng.randi(), rng.randi()]


static func code_valide(c: Variant) -> bool:
	return c is String and c.length() == 16 and c.is_valid_hex_number()
