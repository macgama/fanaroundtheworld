extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_evenements.gd
## Événements autour des vrais matchs : détection, priorités, fenêtre de fête, bonus.

const T0 := 1_800_000_000

var _echecs := 0


func _init() -> void:
	_tester_tours()
	_tester_derbys()
	_tester_chocs()
	_tester_nations()
	_tester_priorite()
	_tester_fenetre()
	_tester_bonus()
	_tester_textes()
	print("Tests événements : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _m(comp: String, dom: String, ext: String, tour: Variant = null, statut := "SCHEDULED") -> Dictionary:
	return {
		"id": "af:1", "status": statut, "round": tour,
		"kickoff_utc": Time.get_datetime_string_from_unix_time(T0) + ".000Z",
		"competition": {"id": comp}, "home": {"id": dom, "name": "A"}, "away": {"id": ext, "name": "B"},
	}


func _type(m: Dictionary, villes := {}, pays := {}, grands := {}) -> String:
	return str(Evenements.detecter(m, villes, pays, grands).get("type", ""))


func _tester_tours() -> void:
	_verifier(Evenements.type_tour("Final") == "finale", "Final = finale")
	_verifier(Evenements.type_tour("Finale") == "finale", "Finale (allemand) = finale")
	_verifier(Evenements.type_tour("Semi-finals") == "demi", "Semi-finals = demi")
	_verifier(Evenements.type_tour("Halbfinale") == "demi", "Halbfinale = demi")
	_verifier(Evenements.type_tour("Quarter-finals") == "quart", "Quarter-finals = quart")
	_verifier(Evenements.type_tour("3rd Place Final") == "", "petite finale : rien")
	_verifier(Evenements.type_tour("Round of 16") == "", "huitièmes : rien")
	_verifier(Evenements.type_tour("Regular Season - 12") == "", "championnat : rien")
	_verifier(Evenements.type_tour(null) == "", "pas de tour : rien")
	_verifier(_type(_m("ucl", "af:1", "af:2", "Final")) == "finale", "finale de coupe repérée")


func _tester_derbys() -> void:
	var villes := {"af:10": "Manchester", "af:11": "manchester, Greater Manchester", "af:12": "Leeds"}
	_verifier(_type(_m("en.1", "af:10", "af:11"), villes) == "derby", "même ville = derby")
	var ev := Evenements.detecter(_m("en.1", "af:10", "af:11"), villes)
	_verifier(ev.get("titre") == "Derby de Manchester", "nom du derby d'après la ville : %s" % ev.get("titre"))
	_verifier(_type(_m("en.1", "af:10", "af:12"), villes) == "", "villes différentes : rien")
	_verifier(_type(_m("en.1", "af:10", "af:11"), villes, {"af:10": "england", "af:11": "usa"}) == "", "même nom de ville dans deux pays : pas de derby")
	_verifier(_type(_m("en.1", "af:10", "af:99"), villes) == "", "ville inconnue : rien")
	# Table des rivalités : derby entre deux villes voisines (Ruhr), sans ville connue.
	var ruhr := Evenements.detecter(_m("de.1", "af:165", "af:174"))
	_verifier(ruhr.get("type") == "derby" and ruhr.get("titre") == "Derby de la Ruhr", "derby de la table, dans les deux sens")
	_verifier(Evenements.nom_derby("İstanbul") == "Derby d'Istanbul", "élision : %s" % Evenements.nom_derby("İstanbul"))
	_verifier(Evenements.nom_derby("Cairo") == "Derby du Caire", "« du » : %s" % Evenements.nom_derby("Cairo"))
	_verifier(Evenements.nom_derby("London") == "Derby de Londres", "ville en français")
	_verifier(Evenements.nom_derby("Rosario") == "Derby de Rosario", "ville inconnue gardée")


func _tester_chocs() -> void:
	_verifier(_type(_m("es.1", "af:541", "af:529")) == "choc", "Grand Choc de la table")
	_verifier(Evenements.detecter(_m("es.1", "af:541", "af:529")).get("titre") == "Grand Choc", "titre Grand Choc")
	var grands := {"af:50": true, "af:496": true}
	_verifier(_type(_m("ucl", "af:50", "af:496"), {}, {}, grands) == "choc", "deux grands clubs en coupe d'Europe = Grand Choc")
	_verifier(_type(_m("en.1", "af:50", "af:496"), {}, {}, grands) == "", "deux grands en championnat : seulement la table")
	Evenements.ajouter_rivalites([{"equipes": ["af:700", "af:701"], "type": "choc"}, {"equipes": ["af:1"], "type": "choc"}, {"equipes": ["af:2", "af:3"], "type": "fete"}])
	_verifier(_type(_m("xx.1", "af:701", "af:700")) == "choc", "rivalité ajoutée par un mod")
	_verifier(_type(_m("xx.1", "af:2", "af:3")) == "", "type inconnu ignoré")


func _tester_nations() -> void:
	_verifier(_type(_m("world-cup", "af:2", "af:3")) == "nations", "Mondial = fête des nations")
	_verifier(_type(_m("friendlies", "af:2", "af:3")) == "", "amical : rien")
	_verifier(_type(_m("euro", "af:2", "af:3", "Final")) == "finale", "finale de l'Euro = finale")
	# Des clubs qui partagent une ville ne font pas de derby en sélection.
	_verifier(_type(_m("friendlies", "af:10", "af:11"), {"af:10": "X", "af:11": "X"}) == "", "pas de derby entre sélections")


func _tester_priorite() -> void:
	# Finale de Coupe des Étoiles entre deux clubs de Madrid : finale d'abord, derby en plus.
	var ev := Evenements.detecter(_m("ucl", "af:541", "af:530", "Final"))
	_verifier(ev.get("type") == "finale", "finale prioritaire sur le derby")
	_verifier("Derby de Madrid" in ev.get("aussi", []), "le derby est rappelé : %s" % str(ev.get("aussi")))
	_verifier(_type(_m("es.1", "af:541", "af:530", null, "POSTPONED")) == "", "match reporté : pas de fête")
	_verifier(Evenements.detecter({}).is_empty(), "match vide : rien")


func _tester_fenetre() -> void:
	_verifier(Evenements.etat(T0, T0 - Evenements.AVANT - 1) == "a_venir", "trop tôt : à venir")
	_verifier(Evenements.etat(T0, T0 - Evenements.AVANT) == "actif", "la veille : actif")
	_verifier(Evenements.etat(T0, T0 + 3600) == "actif", "pendant le match : actif")
	_verifier(Evenements.etat(T0, T0 + Evenements.APRES + 1) == "fini", "6 h après : fini")
	_verifier(Evenements.etat(0, T0) == "fini", "heure inconnue : fini")


func _tester_bonus() -> void:
	var finale := Evenements.TYPES["finale"]
	_verifier(Evenements.bonus_jetons(finale, 40) == 40, "finale ×2 : +40 sur 40")
	_verifier(Evenements.bonus_jetons(Evenements.TYPES["derby"], 33) == 17, "derby ×1,5 : +17 sur 33 (arrondi)")
	_verifier(Evenements.bonus_jetons({}, 40) == 0, "hors événement : 0")
	for t in Evenements.TYPES:
		var e: Dictionary = Evenements.TYPES[t]
		_verifier(float(e["mult"]) > 1.0 and float(e["mult"]) <= 2.0, "%s : multiplicateur raisonnable" % t)
		_verifier(int(e["xp_pass"]) <= 400 and int(e["jetons"]) <= 50, "%s : prime modeste" % t)
		_verifier(t in Evenements.ORDRE, "%s : dans l'ordre de priorité" % t)
	var primes := {"a": T0 - 11 * 86400, "b": T0 - 86400}
	Evenements.nettoyer_primes(primes, T0)
	_verifier(not primes.has("a") and primes.has("b"), "vieilles primes oubliées")


func _tester_textes() -> void:
	_verifier(Evenements.texte_mult(Evenements.TYPES["derby"]) == "×1,5", "×1,5")
	_verifier(Evenements.texte_mult(Evenements.TYPES["finale"]) == "×2", "×2")
	_verifier(Evenements.texte_mult(Evenements.TYPES["quart"]) == "×1,25", "×1,25")
	# Aucun nom officiel : les titres sont « Derby de… », « Grand Choc » ou génériques.
	for t in Evenements.TYPES:
		var titre := str(Evenements.TYPES[t]["titre"]).to_lower()
		for interdit in ["clasico", "clásico", "klassiker", "classique", "old firm", "superclasico", "champions"]:
			_verifier(not interdit in titre, "%s : pas de nom de marque (%s)" % [t, interdit])
