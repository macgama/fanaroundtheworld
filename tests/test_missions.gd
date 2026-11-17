extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_missions.gd
## Missions du jour et de la semaine : tirage, progression, récompenses.

const LUNDI := 1_794_787_200  # 2026-11-16 00:00 (lundi), heure locale
const JOUR := 86400
const CTX := {"club": true, "favoris": true}

var _echecs := 0


func _init() -> void:
	_tester_dates()
	_tester_tirage()
	_tester_progression()
	_tester_recompenses()
	_tester_renouvellement()
	_tester_changement()
	_tester_pass()
	print("Tests missions : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_dates() -> void:
	_verifier(Missions.cle_jour(LUNDI) == "2026-11-16", "date du lundi")
	_verifier(Missions.cle_semaine(LUNDI) == "S2026-11-16", "semaine commence le lundi")
	_verifier(Missions.cle_semaine(LUNDI + 6 * JOUR + 86399) == "S2026-11-16", "dimanche soir : même semaine")
	_verifier(Missions.cle_semaine(LUNDI + 7 * JOUR) == "S2026-11-23", "lundi suivant : nouvelle semaine")
	_verifier(Missions.cle_semaine(LUNDI - 1) == "S2026-11-09", "dimanche d'avant : semaine d'avant")
	_verifier(Missions.avant_renouvellement(LUNDI + 3600, "jour") == 23 * 3600, "23 h avant minuit")
	_verifier(Missions.avant_renouvellement(LUNDI + 2 * JOUR, "semaine") == 5 * JOUR, "5 jours avant lundi")


func _tester_tirage() -> void:
	var a := Missions.tirer(Missions.JOUR, "2026-11-16", 3, CTX)
	var b := Missions.tirer(Missions.JOUR, "2026-11-16", 3, CTX)
	_verifier(a.size() == 3, "3 missions du jour")
	_verifier(a.map(func(m): return m["id"]) == b.map(func(m): return m["id"]), "même date, mêmes missions")
	var evts := {}
	for m in a:
		evts[m["evt"]] = true
	_verifier(evts.size() == 3, "trois événements différents")
	# Sans fan club ni favori, ces missions ne sont jamais proposées.
	for g in 40:
		for m in Missions.tirer(Missions.JOUR, "g%d" % g, 3, {}) + Missions.tirer(Missions.SEMAINE, "g%d" % g, 3, {}):
			_verifier(not m["evt"] in ["recolte", "favori"], "mission conditionnelle sans condition : " + m["id"])
	var differents := false
	for g in 10:
		var c := Missions.tirer(Missions.JOUR, "2026-11-%02d" % (g + 1), 3, CTX)
		if c.map(func(m): return m["id"]) != a.map(func(m): return m["id"]):
			differents = true
	_verifier(differents, "les missions changent d'un jour à l'autre")


func _etat_avec(jour: Array, semaine: Array) -> Dictionary:
	var e := Missions.vide()
	e["jour"] = "2026-11-16"
	e["semaine"] = "S2026-11-16"
	for id in jour:
		e["du_jour"].append(Missions._nouvelle(Missions._modele(Missions.JOUR, id)))
	for id in semaine:
		e["de_la_semaine"].append(Missions._nouvelle(Missions._modele(Missions.SEMAINE, id)))
	return e


func _tester_progression() -> void:
	var e := _etat_avec(["j_suivre3", "j_arene", "j_gagne1"], ["s_pays3", "s_modes", "s_stade3"])
	var f := Missions.noter(e, "suivre", "maison")
	_verifier(f.is_empty() and e["du_jour"][0]["progres"] == 1, "1 match suivi sur 3")
	_verifier(e["de_la_semaine"][2]["progres"] == 0, "à la maison ne compte pas pour le stade")
	Missions.noter(e, "suivre", "stade")
	f = Missions.noter(e, "suivre", "pub")
	_verifier(f.size() == 1 and f[0]["id"] == "j_suivre3", "3e match : mission terminée")
	Missions.noter(e, "suivre", "pub")
	_verifier(e["du_jour"][0]["progres"] == 3, "la progression ne dépasse pas l'objectif")
	_verifier(e["de_la_semaine"][2]["progres"] == 1, "1 match au stade")
	# Pays différents
	Missions.noter(e, "suivre_pays", "france")
	Missions.noter(e, "suivre_pays", "france")
	_verifier(e["de_la_semaine"][0]["progres"] == 1, "le même pays ne compte qu'une fois")
	Missions.noter(e, "suivre_pays", "")
	_verifier(e["de_la_semaine"][0]["progres"] == 1, "pays inconnu : rien")
	Missions.noter(e, "suivre_pays", "spain")
	f = Missions.noter(e, "suivre_pays", "brazil")
	_verifier(f.size() == 1 and f[0]["id"] == "s_pays3", "3 pays différents")
	# Modes de duel
	Missions.noter(e, "duel_joue", "duel")
	_verifier(not Missions.terminee(e["du_jour"][1]), "un duel d'ambiance ne compte pas pour l'Arène")
	f = Missions.noter(e, "duel_joue", "arene")
	_verifier(f.size() == 1 and f[0]["id"] == "j_arene", "partie d'Arène")
	f = Missions.noter(e, "duel_joue", "poussee")
	_verifier(f.size() == 1 and f[0]["id"] == "s_modes", "les trois modes joués")
	_verifier(Missions.a_recuperer(e) == 4, "4 récompenses à récupérer")


func _tester_recompenses() -> void:
	var e := _etat_avec(["j_suivre1", "j_gagne1", "j_prono2"], ["s_stade"])
	_verifier(Missions.recuperer(e, "jour", 0).is_empty(), "pas de récompense avant la fin")
	Missions.noter(e, "suivre", "pub")
	var g := Missions.recuperer(e, "jour", 0)
	_verifier(g.get("jetons") == 15 and g.get("xp_pass") == 25 and not g["bonus"], "récompense de « Suis un match »")
	_verifier(Missions.recuperer(e, "jour", 0).is_empty(), "une seule fois")
	Missions.noter(e, "duel_gagne", "duel")
	Missions.noter(e, "prono")
	Missions.noter(e, "prono")
	Missions.recuperer(e, "jour", 1)
	g = Missions.recuperer(e, "jour", 2)
	_verifier(g["bonus"] and g["jetons"] == 15 + Missions.BONUS["jour"]["jetons"], "bonus avec la 3e mission")
	_verifier(e["bonus_jour"], "bonus noté")
	_verifier(Missions.recuperer(e, "jour", 9).is_empty(), "index hors liste")


func _tester_renouvellement() -> void:
	var e := Missions.vide()
	var v := Missions.actualiser(e, LUNDI + 10 * 3600, CTX)
	_verifier(e["du_jour"].size() == 3 and e["de_la_semaine"].size() == 3, "premier tirage")
	_verifier(v["jetons"] == 0, "rien à verser au début")
	var ids: Array = e["de_la_semaine"].map(func(m): return m["id"])
	var m0: Dictionary = e["du_jour"][0]
	m0["progres"] = m0["n"]  # terminée mais oubliée
	Missions.actualiser(e, LUNDI + 20 * 3600, CTX)
	_verifier(e["du_jour"][0] == m0, "même jour : rien ne change")
	v = Missions.actualiser(e, LUNDI + JOUR + 60, CTX)
	_verifier(v["jetons"] == m0["jetons"] and v["xp_pass"] == m0["xp_pass"], "mission oubliée versée le lendemain")
	_verifier(e["jour"] == "2026-11-17" and e["changements"] == 0, "nouveau jour")
	_verifier(e["de_la_semaine"].map(func(m): return m["id"]) == ids, "même semaine : missions gardées")
	Missions.actualiser(e, LUNDI + 7 * JOUR, CTX)
	_verifier(e["semaine"] == "S2026-11-23", "nouvelle semaine")
	# Sauvegarde : JSON aller-retour
	var r := Missions.reparer(JSON.parse_string(JSON.stringify(e)))
	_verifier(r["du_jour"].size() == 3 and r["du_jour"][0]["progres"] is int, "relu depuis la sauvegarde")
	_verifier(Missions.reparer(null)["du_jour"].is_empty(), "sauvegarde sans missions")


func _tester_changement() -> void:
	var e := _etat_avec(["j_suivre1", "j_gagne1", "j_prono2"], [])
	Missions.noter(e, "suivre", "pub")
	_verifier(not Missions.peut_changer(e, 0), "mission terminée : pas de changement")
	_verifier(Missions.changer(e, 1, CTX), "change une mission")
	var ids: Array = e["du_jour"].map(func(m): return m["id"])
	_verifier(not "j_gagne1" in ids and ids.size() == 3, "mission remplacée")
	var ids_uniques := {}
	for id in ids:
		ids_uniques[id] = true
	_verifier(ids_uniques.size() == 3, "pas de doublon après changement")
	_verifier(not Missions.changer(e, 2, CTX), "une seule fois par jour")


func _tester_pass() -> void:
	_verifier(Missions.palier(0) == 1 and Missions.palier(999) == 1 and Missions.palier(1000) == 2, "paliers de 1 000 XP")
	_verifier(Missions.xp_dans_palier(1450) == 450, "XP dans le palier")
	_verifier(Missions.palier(10_000_000) == Missions.PALIERS, "100 paliers au plus")
	_verifier(Missions.xp_dans_palier(10_000_000) == Missions.XP_PAR_PALIER, "dernier palier plein")
