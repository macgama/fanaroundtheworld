extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_soiree.gd
## Règles du mode « soir de match » : buts détectés, gains, plafonds, réussite.

var _echecs := 0


func _init() -> void:
	_detection()
	_ouverture()
	_gains()
	_reussite()
	_etat()
	print("Tests soir de match : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _v(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _detection() -> void:
	_v(SoireeMatch.detecter(Vector2i(-1, -1), Vector2i(1, 0)).is_empty(), "pas de score avant : rien")
	_v(SoireeMatch.detecter(Vector2i(0, 0), Vector2i(0, 0)).is_empty(), "même score : rien")
	var b := SoireeMatch.detecter(Vector2i(0, 0), Vector2i(1, 0))
	_v(b.size() == 1 and b[0]["cote"] == "home" and not b[0]["annule"], "but à domicile")
	b = SoireeMatch.detecter(Vector2i(1, 0), Vector2i(2, 1))
	_v(b.size() == 2 and b[0]["cote"] == "home" and b[1]["cote"] == "away", "deux buts d'un coup")
	b = SoireeMatch.detecter(Vector2i(2, 1), Vector2i(1, 1))
	_v(b.size() == 1 and b[0]["annule"] and b[0]["cote"] == "home", "but annulé")
	_v(SoireeMatch.cle_but(Vector2i(2, 1)) == "2-1", "clé du but")
	_v(SoireeMatch.score_de({"score": {"current": {"home": 3, "away": 2}}}) == Vector2i(3, 2), "score lu")
	_v(SoireeMatch.score_de({"score": {"current": null}}) == Vector2i(-1, -1), "pas de score")


func _ouverture() -> void:
	var t := int(Time.get_unix_time_from_system())
	var m := {"status": "LIVE"}
	_v(SoireeMatch.ouverte(m, t), "en direct : ouverte")
	_v(SoireeMatch.ouverte({"status": "HALFTIME"}, t), "mi-temps : ouverte")
	var k := func(dh: float) -> Dictionary:
		return {"status": "SCHEDULED", "kickoff_utc": Time.get_datetime_string_from_unix_time(t + int(dh * 3600)) + ".000Z"}
	_v(SoireeMatch.ouverte(k.call(0.25), t), "coup d'envoi dans 15 min : ouverte")
	_v(not SoireeMatch.ouverte(k.call(2.0), t), "dans 2 h : pas encore")
	_v(not SoireeMatch.ouverte({"status": "FINISHED"}, t), "fini : fermée")
	_v(SoireeMatch.finie({"status": "FINISHED"}) and SoireeMatch.finie({"status": "UNKNOWN"}), "fin du match")
	_v(SoireeMatch.minute({"status": "LIVE", "minute": 30}, 130.0) == 32, "minute avancée de 2")
	_v(SoireeMatch.minute({"status": "LIVE", "minute": 30}, 900.0) == 33, "minute avancée de 3 au plus")
	_v(SoireeMatch.minute({"status": "HALFTIME", "minute": 45}, 600.0) == 45, "mi-temps : minute figée")


func _gains() -> void:
	var r := SoireeMatch.recompense(1.0, true, 1.5, 100.0)
	_v(r["jetons"] == 29 and r["xp"] == 30 and r["xp_pass"] == 50, "but parfait au stade, ferveur max : %s" % str(r))
	r = SoireeMatch.recompense(0.0, true, 1.0, 50.0)
	_v(r["jetons"] == 6 and r["xp"] == 10 and r["xp_pass"] == 20, "but raté au pub : %s" % str(r))
	r = SoireeMatch.recompense(1.0, false, 1.0, 50.0)
	_v(r["jetons"] == 8 and r["xp"] == 15 and r["xp_pass"] == 25, "but adverse : moitié : %s" % str(r))
	_v(is_equal_approx(SoireeMatch.mult_ferveur(0.0), 0.8) and is_equal_approx(SoireeMatch.mult_ferveur(100.0), 1.2), "ferveur ×0,8 à ×1,2")
	_v(SoireeMatch.prime_fin(0.6)["jetons"] == 6, "prime à la maison")
	var e := {"buts": []}
	for i in SoireeMatch.MAX_BUTS:
		_v(SoireeMatch.peut_recompenser(e, "%d-0" % (i + 1)), "but %d payé" % (i + 1))
		e["buts"].append("%d-0" % (i + 1))
	_v(not SoireeMatch.peut_recompenser(e, "1-0"), "même but : pas deux fois")
	_v(not SoireeMatch.peut_recompenser(e, "9-0"), "plafond de %d buts" % SoireeMatch.MAX_BUTS)
	_v(is_equal_approx(SoireeMatch.ferveur_apres(50.0, 10.0, false), 44.0), "la ferveur retombe")
	_v(is_equal_approx(SoireeMatch.ferveur_apres(50.0, 10.0, true), 50.0), "mi-temps : elle tient")


func _reussite() -> void:
	_v(is_equal_approx(SoireeMatch.perf_chant(10, 0, 10), 1.0), "chant parfait")
	_v(is_equal_approx(SoireeMatch.perf_chant(0, 10, 10), 0.6), "chant « bien »")
	_v(SoireeMatch.perf_chant(0, 0, 0) == 0.0, "chant vide")
	_v(is_equal_approx(SoireeMatch.perf_tifo([0.0, 0.0, 0.0]), 1.0), "tifo pile")
	_v(is_equal_approx(SoireeMatch.perf_tifo([0.15, -0.15, 1.0]), 1.0 / 3.0), "tifo moyen")
	_v(SoireeMatch.perf_tifo([0.0]) < 0.34, "pans manquants comptés ratés")
	_v(is_equal_approx(SoireeMatch.perf_ola(6, 0, 0.0), 1.0), "ola complète")
	_v(is_equal_approx(SoireeMatch.perf_ola(3, 0, 2.0), 0.5), "ola à moitié")
	_v(is_equal_approx(SoireeMatch.perf_ola(6, 2, 3.0), 1.0 - 1.0 / 6.0 + 0.075), "erreurs et vitesse")
	_v(SoireeMatch.etoiles(0.9) == 3 and SoireeMatch.etoiles(0.6) == 2 and SoireeMatch.etoiles(0.3) == 1 and SoireeMatch.etoiles(0.1) == 0, "étoiles")


func _etat() -> void:
	var s := SoireeMatch.vide()
	var e := SoireeMatch.etat(s, "m1", 1000)
	_v(e["debut"] == 1000 and e["buts"].is_empty(), "nouvelle soirée")
	_v(SoireeMatch.etat(s, "m1", 5000)["debut"] == 1000, "la même soirée")
	SoireeMatch.nettoyer(s, 1000 + SoireeMatch.GARDE + 1)
	_v(s.is_empty(), "vieille soirée oubliée")
	var r := SoireeMatch.reparer({"m2": {"debut": "12", "buts": [1, "2-0"], "fil": "x"}, "m3": 4})
	_v(r.size() == 1 and r["m2"]["debut"] == 12 and r["m2"]["buts"] == ["1", "2-0"] and r["m2"]["fil"] == [], "sauvegarde réparée : %s" % str(r))
	_v(SoireeMatch.reparer(null).is_empty(), "rien à réparer")
