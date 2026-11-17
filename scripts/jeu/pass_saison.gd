class_name PassSaison
extends RefCounted
## PASS saisonnier, sans affichage (testable).
##
## Une saison suit la vraie saison de foot : du 1er août au dernier week-end
## de mai, en 4 chapitres de 25 paliers. 100 paliers de 1 000 XP. Piste
## gratuite (recrues FANZZY jouables, Jetons, quelques skins) et piste Premium
## (7,99 € en DLC Steam, uniquement de l'apparence : skins, écharpes, décors…).
## Règles (doc « PASS saisonnier », validé le 15 nov. 2026) :
## - aucun palier ni boost d'XP à acheter : tout le monde avance au même rythme ;
## - chaque récompense est connue à l'avance (pas de hasard) ;
## - Premium acheté en cours de saison : les paliers déjà atteints sont débloqués ;
## - rattrapage : en retard sur le rythme de la saison, les missions donnent double XP ;
## - après le palier 100, des paliers bonus donnent des Jetons ;
## - en juin-juillet (intersaison), l'XP est mise de côté pour la saison
##   suivante, jusqu'à 10 paliers d'avance.
##
## Les paliers d'une saison sont dans data/pass/saison-<id>.json
## (fabriqués par tools/pass/generer_pass.py).
##
## État sauvegardé (Game.pass) :
##   saison       id de la saison en cours (« 2026-27 »)
##   premium      PASS Premium de cette saison acheté
##   recus        {gratuit: [paliers], premium: [paliers]} déjà récupérés
##   bonus_recus  paliers bonus déjà récupérés
##   report       XP gagnée pendant l'intersaison, pour la saison suivante
##   skins        skins gagnés (gardés pour toujours) : [{skin, fanzzy, nom}]
##   fanzzy       recrues FANZZY débloquées (ids)
##   objets       objets d'apparence gagnés : [{type, nom}]
##   titres       titres de profil gagnés

const XP_PAR_PALIER := 1000
const PALIERS := 100
const REPORT_MAX := 10 * XP_PAR_PALIER
const JETONS_PALIER_BONUS := 100
const DOSSIER := "res://data/pass/"
## Prix affiché : le Premium est un DLC Steam payé en euros (pas de monnaie virtuelle).
const PRIX := "7,99 €"

## XP de PASS hors missions (valeurs de départ, à régler en test).
## Un duel rejoué sur le même match le même jour suit la règle des Jetons (100 %, 50 %, 25 %, 0).
## XP de PASS des actions : réglées le 17 nov. 2026 pour qu'un joueur régulier (1 h par jour)
## finisse le PASS vers avril, pas en trois mois (docs/equilibrage.md).
const XP_DUEL := 12
const XP_DUEL_PERF := 6      # selon la performance (0 à 1)
const XP_DUEL_GAGNE := 6
const XP_NOUVEAU_STADE := 100
const XP_PRONO_BON := 15
const XP_PRONO_EXACT := 50

## Types d'objets d'apparence et leur libellé.
const TYPES_OBJETS := {
	"echarpe": "Écharpe", "drapeau": "Drapeau", "tifo": "Motif de tifo", "decor": "Décor du local",
	"emote": "Émote", "son": "Son de tribune", "couverture": "Couverture de carnet", "titre": "Titre de profil",
}


static func vide() -> Dictionary:
	return {"saison": "", "premium": false, "recus": {"gratuit": [], "premium": []}, "bonus_recus": 0,
		"report": 0, "skins": [], "fanzzy": [], "objets": [], "titres": []}


static func reparer(e: Variant) -> Dictionary:
	var base := vide()
	if not e is Dictionary:
		return base
	for k in base:
		if not e.has(k) or typeof(e[k]) != typeof(base[k]):
			e[k] = base[k]
	for piste in ["gratuit", "premium"]:
		if not e["recus"].get(piste) is Array:
			e["recus"][piste] = []
		e["recus"][piste] = e["recus"][piste].map(func(p): return int(p))
	return e


# ---------------------------------------------------------------- saisons et dates

## Saison qui contient ce jour : « 2026-27 » du 1er août 2026 au 31 juillet 2027.
static func saison_de(t: int) -> String:
	var d := Time.get_date_dict_from_unix_time(t)
	var a: int = d["year"] if d["month"] >= 8 else d["year"] - 1
	return "%d-%02d" % [a, (a + 1) % 100]


## Paliers et récompenses d'une saison, ou {} si elle n'est pas encore prête.
static func charger(saison: String) -> Dictionary:
	var chemin := DOSSIER + "saison-%s.json" % saison
	if not FileAccess.file_exists(chemin):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	if not d is Dictionary or not d.get("paliers") is Array:
		return {}
	return d


static func _jour(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date + "T00:00:00")


static func debut(data: Dictionary) -> int:
	return _jour(str(data["debut"]))


## Fin de la saison : le soir du dernier jour.
static func fin(data: Dictionary) -> int:
	return _jour(str(data["fin"])) + 86400


static func en_intersaison(data: Dictionary, t: int) -> bool:
	return not data.is_empty() and t >= fin(data)


static func jours_restants(data: Dictionary, t: int) -> int:
	return maxi(0, ceili(float(fin(data) - t) / 86400.0))


## Chapitre (0 à 3) d'après la date : la saison est coupée en 4 parts égales.
static func chapitre_du_jour(data: Dictionary, t: int) -> int:
	var duree := float(fin(data) - debut(data))
	return clampi(int(4.0 * float(t - debut(data)) / duree), 0, 3)


## Chapitre (0 à 3) d'un palier.
static func chapitre_du_palier(p: int) -> int:
	return clampi((p - 1) / 25, 0, 3)


# ---------------------------------------------------------------- paliers et XP

## Palier atteint (le palier 1 est acquis dès le départ).
static func palier(xp: int) -> int:
	return mini(1 + xp / XP_PAR_PALIER, PALIERS)


## XP déjà gagnée vers le palier suivant (pleine au dernier palier).
static func xp_dans_palier(xp: int) -> int:
	if palier(xp) >= PALIERS:
		return mini(xp - (PALIERS - 1) * XP_PAR_PALIER, XP_PAR_PALIER)
	return xp % XP_PAR_PALIER


## Paliers bonus atteints après le palier 100 (1 000 XP chacun).
static func paliers_bonus(xp: int) -> int:
	return maxi(0, (xp - (PALIERS - 1) * XP_PAR_PALIER) / XP_PAR_PALIER)


## Palier qu'un joueur régulier devrait avoir atteint à cette date.
static func palier_attendu(data: Dictionary, t: int) -> int:
	if data.is_empty():
		return 1
	var f := clampf(float(t - debut(data)) / float(fin(data) - debut(data)), 0.0, 1.0)
	return clampi(ceili(PALIERS * f), 1, PALIERS)


## Rattrapage : le joueur est en retard sur le rythme de la saison.
static func rattrapage(data: Dictionary, xp: int, t: int) -> bool:
	return not data.is_empty() and not en_intersaison(data, t) and palier(xp) < palier_attendu(data, t)


## XP de PASS d'un duel. `part` : part des gains après les duels rejoués sur ce match.
static func xp_duel(gagne: bool, perf: float, part := 1.0) -> int:
	var n := XP_DUEL + XP_DUEL_PERF * clampf(perf, 0.0, 1.0) + (XP_DUEL_GAGNE if gagne else 0)
	return int(round(n * part))


# ---------------------------------------------------------------- récompenses

static func recompense(data: Dictionary, p: int, piste: String) -> Dictionary:
	if data.is_empty() or p < 1 or p > data["paliers"].size():
		return {}
	var r: Variant = data["paliers"][p - 1].get(piste)
	return r if r is Dictionary else {}


static func recue(etat: Dictionary, p: int, piste: String) -> bool:
	return int(p) in etat["recus"][piste]


## La récompense peut-elle être récupérée maintenant ?
static func disponible(data: Dictionary, etat: Dictionary, xp: int, p: int, piste: String) -> bool:
	if recompense(data, p, piste).is_empty() or p > palier(xp) or recue(etat, p, piste):
		return false
	return piste == "gratuit" or bool(etat["premium"])


## Toutes les récompenses prêtes : [[palier, piste], …].
static func a_recuperer(data: Dictionary, etat: Dictionary, xp: int) -> Array:
	var res: Array = []
	if data.is_empty():
		return res
	for p in range(1, palier(xp) + 1):
		for piste in ["gratuit", "premium"]:
			if disponible(data, etat, xp, p, piste):
				res.append([p, piste])
	return res


static func nb_a_recuperer(data: Dictionary, etat: Dictionary, xp: int) -> int:
	return a_recuperer(data, etat, xp).size() + bonus_a_recuperer(etat, xp)


static func bonus_a_recuperer(etat: Dictionary, xp: int) -> int:
	return maxi(0, paliers_bonus(xp) - int(etat["bonus_recus"]))


## Récupère une récompense. Renvoie ce qui est gagné :
## {jetons, skins: [...], fanzzy: [ids], objets: [...], titres: [...]}, ou {} si rien.
static func recuperer(data: Dictionary, etat: Dictionary, xp: int, p: int, piste: String) -> Dictionary:
	if not disponible(data, etat, xp, p, piste):
		return {}
	etat["recus"][piste].append(p)
	var g := _gain_vide()
	_ajouter(etat, recompense(data, p, piste), g)
	return g


## Récupère tout ce qui est prêt, paliers bonus compris.
static func recuperer_tout(data: Dictionary, etat: Dictionary, xp: int) -> Dictionary:
	var g := _gain_vide()
	for pp in a_recuperer(data, etat, xp):
		var gi := recuperer(data, etat, xp, pp[0], pp[1])
		for k in g:
			if k == "jetons":
				g[k] += int(gi.get(k, 0))
			else:
				g[k].append_array(gi.get(k, []))
	var nb := bonus_a_recuperer(etat, xp)
	if nb > 0:
		etat["bonus_recus"] = int(etat["bonus_recus"]) + nb
		g["jetons"] += nb * JETONS_PALIER_BONUS
	return g


static func _gain_vide() -> Dictionary:
	return {"jetons": 0, "skins": [], "fanzzy": [], "objets": [], "titres": []}


static func _ajouter(etat: Dictionary, r: Dictionary, g: Dictionary) -> void:
	match str(r.get("type", "")):
		"jetons":
			g["jetons"] += int(r["n"])
		"skin":
			var s := {"skin": str(r["skin"]), "fanzzy": str(r["fanzzy"]), "nom": str(r["nom"])}
			if not possede_skin(etat, s["skin"]):
				etat["skins"].append(s)
			g["skins"].append(s)
		"tribune":
			for s in r.get("skins", []):
				_ajouter(etat, s, g)
			if r.has("titre"):
				_ajouter(etat, {"type": "titre", "nom": r["titre"]}, g)
		"recrue":
			var id := str(r["fanzzy"])
			if not id in etat["fanzzy"]:
				etat["fanzzy"].append(id)
			g["fanzzy"].append(id)
		"titre":
			if not r["nom"] in etat["titres"]:
				etat["titres"].append(str(r["nom"]))
			g["titres"].append(str(r["nom"]))
		var t:
			if TYPES_OBJETS.has(t):
				var o := {"type": t, "nom": str(r["nom"])}
				if not o in etat["objets"]:
					etat["objets"].append(o)
				g["objets"].append(o)


static func possede_skin(etat: Dictionary, skin: String) -> bool:
	for s in etat["skins"]:
		if s["skin"] == skin:
			return true
	return false


## Skins de PASS gagnés pour ce FANZZY : [{skin, fanzzy, nom}].
static func skins_de(etat: Dictionary, fanzzy_id: String) -> Array:
	return etat["skins"].filter(func(s): return s["fanzzy"] == fanzzy_id)


## Phrase courte qui résume un gain (annonce à l'écran).
static func resume(g: Dictionary) -> String:
	var morceaux: Array = []
	if g["fanzzy"].size() > 0:
		morceaux.append(Trad.t("%d recrue%s FANZZY") % [g["fanzzy"].size(), "s" if g["fanzzy"].size() > 1 else ""])
	if g["skins"].size() > 0:
		morceaux.append(Trad.t("%d skin%s") % [g["skins"].size(), "s" if g["skins"].size() > 1 else ""])
	if g["objets"].size() > 0:
		morceaux.append(Trad.t("%d objet%s") % [g["objets"].size(), "s" if g["objets"].size() > 1 else ""])
	if g["titres"].size() > 0:
		morceaux.append(Trad.t("titre « %s »") % g["titres"][0])
	if int(g["jetons"]) > 0:
		morceaux.append(Trad.t("%d Jetons") % int(g["jetons"]))
	return ", ".join(morceaux)


# ---------------------------------------------------------------- changement de saison

## Passe à la saison `saison` si besoin. Renvoie l'XP de départ de la nouvelle
## saison (l'XP mise de côté pendant l'intersaison), ou -1 si rien ne change.
static func changer_saison(etat: Dictionary, saison: String) -> int:
	if etat["saison"] == saison:
		return -1
	var premiere := str(etat["saison"]) == ""
	var report := mini(int(etat["report"]), REPORT_MAX)
	etat["saison"] = saison
	etat["premium"] = false
	etat["recus"] = {"gratuit": [], "premium": []}
	etat["bonus_recus"] = 0
	etat["report"] = 0
	return -1 if premiere else report
