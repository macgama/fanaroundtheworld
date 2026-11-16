class_name FicheMatch
extends RefCounted
## Tout ce que l'interface affiche pour un match : noms fictifs, stade,
## lieu sur la carte, heure locale, statut. Calculé une fois par match.

const JOURS := ["Dim", "Lun", "Mar", "Mer", "Jeu", "Ven", "Sam"]
const MOIS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
const STATUTS := {
	"SCHEDULED": "À venir", "LIVE": "En direct", "HALFTIME": "Mi-temps", "FINISHED": "Terminé",
	"POSTPONED": "Reporté", "SUSPENDED": "Interrompu", "CANCELLED": "Annulé", "UNKNOWN": "Résultat inconnu",
}

static var _cache: Dictionary = {}


static func de(m: Dictionary) -> Dictionary:
	var id := str(m.get("id", ""))
	var c: Dictionary = _cache.get(id, {})
	if c.is_empty():
		var sel := Fiction.est_selection(m)
		var dom := Fiction.equipe(m.get("home", {}), sel)
		var ext := Fiction.equipe(m.get("away", {}), sel)
		var lieu := Geo.lieu_match(m)
		var stade := Fiction.stade(m.get("home", {}), dom["nom"])
		if sel:
			stade["nom"] = Trad.t("Stade national · ") + dom["nom"]
		c = {
			"id": id, "dom": dom, "ext": ext, "lieu": lieu, "stade": stade,
			"competition": Fiction.competition(m.get("competition", {})),
			"t": Donnees.heure_unix(m),
		}
		_cache[id] = c
	c["m"] = m  # toujours la version la plus récente (live)
	return c


static func oublier() -> void:
	_cache.clear()


static func decalage_local() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func jour_local(t: int) -> String:
	## « 2026-11-15 » dans le fuseau du joueur.
	return Time.get_date_string_from_unix_time(t + decalage_local())


static func heure_texte(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t + decalage_local())
	return "%02d:%02d" % [d["hour"], d["minute"]]


static func date_texte(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t + decalage_local())
	return "%s %d %s" % [Trad.t(JOURS[d["weekday"]]), d["day"], Trad.t(MOIS[d["month"] - 1])]


static func statut_court(f: Dictionary) -> String:
	## « Sam 21:00 », « EN DIRECT 67' », « Terminé ».
	var m: Dictionary = f["m"]
	var s := str(m.get("status", ""))
	match s:
		"LIVE":  # sans_traduction
			var mi: Variant = m.get("minute")
			return Trad.t("EN DIRECT %s'") % str(int(mi)) if mi != null else Trad.t("EN DIRECT")
		"HALFTIME":  # sans_traduction
			return Trad.t("MI-TEMPS")
		"SCHEDULED":  # sans_traduction
			return "%s %s" % [Trad.t(JOURS[Time.get_datetime_dict_from_unix_time(int(f["t"]) + decalage_local())["weekday"]]), heure_texte(f["t"])]
	return Trad.t(STATUTS.get(s, s))


static func ambiance_prevue(f: Dictionary) -> int:
	## Nombre d'étoiles (1 à 5) : grosses compétitions et clubs connus = plus d'ambiance.
	var comp_id := str(f["m"].get("competition", {}).get("id", ""))
	var etoiles := 2
	if Fiction.LIGUES.has(comp_id):
		etoiles = 4
	if Geo.niveau_competition(comp_id) != "pays":
		etoiles += 1
	if Fiction._surcharges.has(str(f["m"].get("home", {}).get("id", ""))) and Fiction._surcharges.has(str(f["m"].get("away", {}).get("id", ""))):
		etoiles = 5
	return clampi(etoiles, 1, 5)


static func jouable(f: Dictionary) -> bool:
	return not str(f["m"].get("status", "")) in ["POSTPONED", "CANCELLED", "SUSPENDED"]  # sans_traduction
