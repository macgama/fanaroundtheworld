extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_tournoi.gd
## Règles du tournoi des fan clubs : fenêtre du week-end, duels, récompenses.

var _echecs := 0
# Vendredi 13 nov. 2026 00:00 UTC.
var VEN := int(Time.get_unix_time_from_datetime_string("2026-11-13T00:00:00"))


func _init() -> void:
	_fenetre()
	_duels()
	_recompenses()
	_passage()
	print("Tests tournoi : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _v(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _fenetre() -> void:
	var f := Tournoi.fenetre(VEN + 3600)
	_v(f["etat"] == "actif" and f["id"] == "2026-11-13", "vendredi : actif")
	f = Tournoi.fenetre(VEN + 3 * 86400 + 11 * 3600)  # lundi 11:00
	_v(f["etat"] == "actif" and f["id"] == "2026-11-13", "lundi 11 h : encore actif")
	f = Tournoi.fenetre(VEN + 3 * 86400 + 12 * 3600)  # lundi 12:00
	_v(f["etat"] == "attente" and f["prochain"] == VEN + 7 * 86400, "lundi midi : fini")
	f = Tournoi.fenetre(VEN - 3600)  # jeudi 23:00
	_v(f["etat"] == "attente" and f["id"] == "2026-11-06", "jeudi : attente")
	f = Tournoi.fenetre(VEN + 86400)
	_v(Tournoi.match_du_week_end(VEN + 86400, f), "match du samedi")
	_v(not Tournoi.match_du_week_end(VEN - 60, f), "match du jeudi refusé")
	_v(not Tournoi.match_du_week_end(VEN + 3 * 86400 + 7 * 3600, f), "match du lundi 7 h refusé")


func _duels() -> void:
	var t := VEN + 86400
	var s := Tournoi.vide()
	Tournoi.actualiser(s, t)
	_v(s["id"] == "2026-11-13", "id posé")
	_v(Tournoi.noter_duel(s, "af:1", t, true, false, false, t).is_empty(), "pas inscrit : rien")
	s["inscrit"] = true
	var d := Tournoi.noter_duel(s, "af:1", t, true, true, true, t)
	_v(int(d.get("pts", 0)) == 5 and d["adv"] == "bot:0", "victoire au stade sur un derby : 5 pts contre un club du jeu")
	_v(Tournoi.noter_duel(s, "af:1", t, true, false, false, t).is_empty(), "même match : ne compte qu'une fois")
	s["adversaire"] = {"id": "abcdef0123456789", "nom": [1, 2], "couleurs": [0, 1], "niveau": 3, "bot": false}
	d = Tournoi.noter_duel(s, "af:2", t, false, false, false, t)
	_v(int(d["pts"]) == 1 and d["adv"] == "abcdef0123456789", "défaite contre un club de joueur : 1 pt")
	_v(Tournoi.adversaire(s)["id"] == "bot:1", "adversaire suivant : club du jeu suivant")
	for i in 10:
		Tournoi.noter_duel(s, "af:%d" % (10 + i), t, true, false, false, t)
	_v((s["duels"] as Array).size() == Tournoi.DUELS_MAX, "7 duels au plus")
	s["defense"] = 40
	_v(Tournoi.points(s) == 5 + 1 + 5 * 3 + Tournoi.DEFENSE_MAX, "points avec défense plafonnée")
	_v(Tournoi.a_envoyer(s).size() == 7, "7 résultats à envoyer")


func _recompenses() -> void:
	_v(Tournoi.recompense({"points": 4}).jetons == 0, "sous le premier palier")
	_v(Tournoi.recompense({"points": 12}).jetons == 60, "palier 12")
	_v(Tournoi.recompense({"points": 30, "rang": 1, "clubs": 5}).jetons == 150, "pas de bonus de rang à 5 clubs")
	_v(Tournoi.recompense({"points": 30, "rang": 1, "clubs": 50}).jetons == 300, "champion")
	_v(Tournoi.recompense({"points": 5, "rang": 12, "clubs": 50}).jetons == 50, "top 25 %")
	_v(Tournoi.recompense({"points": 5, "rang": 30, "clubs": 50}).jetons == 30, "rien en plus au-delà du quart")


func _passage() -> void:
	var t := VEN + 86400
	var s := Tournoi.vide()
	Tournoi.actualiser(s, t)
	s["inscrit"] = true
	s["nom"] = [3, 4]
	Tournoi.noter_duel(s, "af:1", t, true, false, false, t)
	Tournoi.noter_duel(s, "af:2", t, true, false, false, t)
	var lundi := VEN + 3 * 86400 + 13 * 3600
	_v(Tournoi.actualiser(s, lundi), "lundi : changement")
	_v(s["id"] == "" and not s["inscrit"] and (s["duels"] as Array).is_empty(), "remis à zéro")
	_v(int(s["a_reclamer"].get("points", 0)) == 6 and s["nom"] == [3, 4], "récompense en attente, nom gardé")
	var g := Tournoi.reclamer(s)
	_v(g["jetons"] == 30 and (s["a_reclamer"] as Dictionary).is_empty(), "récompense prise")
	_v(Tournoi.reclamer(s).is_empty(), "une seule fois")
	_v((s["historique"] as Array).size() == 1, "historique")
	Tournoi.actualiser(s, VEN + 7 * 86400 + 60)
	_v(s["id"] == "2026-11-20", "vendredi suivant : nouveau tournoi")
	var r := Tournoi.reparer(JSON.parse_string(JSON.stringify(s)))
	_v(r["id"] == "2026-11-20" and r["nom"] == [3, 4], "sauvegarde relue")
	var c := Tournoi.classement_simule(s, VEN + 7 * 86400 + 86400)
	_v(c.size() > 0 and int(c[0]["rang"]) == 1, "classement d'entraînement")
	_v(Tournoi.bot("2026-11-13", 2) == Tournoi.bot("2026-11-13", 2), "clubs du jeu stables")
