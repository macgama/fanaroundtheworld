extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_pass.gd
## PASS saisonnier : paliers, dates, rattrapage, récompenses, Premium, saisons.

const JOUR := 86400

var _echecs := 0


func _init() -> void:
	var data := PassSaison.charger("2026-27")
	_verifier(not data.is_empty(), "saison 2026-27 chargée")
	if data.is_empty():
		quit(1)
		return
	_tester_fichier(data)
	_tester_paliers()
	_tester_dates(data)
	_tester_recompenses(data)
	_tester_saisons()
	print("Tests PASS : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _t(date: String) -> int:
	return Time.get_unix_time_from_datetime_string(date + "T12:00:00")


func _tester_fichier(data: Dictionary) -> void:
	var paliers: Array = data["paliers"]
	_verifier(paliers.size() == 100, "100 paliers")
	var premium := 0
	var gratuits := 0
	var skins_premium := 0
	for p in paliers:
		var g: Variant = p["gratuit"]
		var pr: Variant = p["premium"]
		if g is Dictionary:
			gratuits += 1
		if pr is Dictionary:
			premium += 1
			_verifier(pr["type"] != "recrue" and pr["type"] != "jetons", "palier %d : le Premium ne donne ni FANZZY jouable ni Jetons" % p["palier"])
			skins_premium += 1 if pr["type"] == "skin" else pr.get("skins", []).size()
		for r in [g, pr]:
			if not r is Dictionary:
				continue
			var skins: Array = [r] if r["type"] == "skin" else r.get("skins", [])
			for s in skins:
				_verifier(ResourceLoader.exists("res://assets/fanzzy/sprites/%s.webp" % s["skin"]), "image du skin %s" % s["skin"])
				_verifier(ResourceLoader.exists("res://assets/fanzzy/sprites/%s-buste.webp" % s["skin"]), "buste du skin %s" % s["skin"])
			if r["type"] == "recrue":
				_verifier(ResourceLoader.exists("res://assets/fanzzy/sprites/%s.webp" % r["fanzzy"]), "image de la recrue %s" % r["fanzzy"])
	_verifier(premium == 100, "une récompense Premium par palier (%d)" % premium)
	_verifier(gratuits >= 50, "au moins 50 récompenses gratuites (%d)" % gratuits)
	_verifier(skins_premium >= 40, "au moins 40 skins Premium (%d)" % skins_premium)
	_verifier(data["paliers"][99]["gratuit"]["type"] == "recrue", "palier 100 gratuit : le légendaire")


func _tester_paliers() -> void:
	_verifier(PassSaison.palier(0) == 1, "palier 1 au départ")
	_verifier(PassSaison.palier(999) == 1 and PassSaison.palier(1000) == 2, "1 000 XP par palier")
	_verifier(PassSaison.palier(99_000) == 100 and PassSaison.palier(500_000) == 100, "100 paliers au plus")
	_verifier(PassSaison.xp_dans_palier(1_250) == 250, "XP dans le palier")
	_verifier(PassSaison.paliers_bonus(99_999) == 0 and PassSaison.paliers_bonus(100_000) == 1 and PassSaison.paliers_bonus(102_500) == 3, "paliers bonus")
	_verifier(PassSaison.xp_duel(false, 0.0) == 12 and PassSaison.xp_duel(true, 1.0) == 24, "XP d'un duel")
	_verifier(PassSaison.xp_duel(true, 1.0, 0.5) == 12 and PassSaison.xp_duel(true, 1.0, 0.0) == 0, "duel rejoué : XP réduite comme les Jetons")


func _tester_dates(data: Dictionary) -> void:
	_verifier(PassSaison.saison_de(_t("2026-11-16")) == "2026-27", "novembre 2026 : saison 2026-27")
	_verifier(PassSaison.saison_de(_t("2027-07-31")) == "2026-27", "fin juillet : encore la saison d'avant")
	_verifier(PassSaison.saison_de(_t("2027-08-01")) == "2027-28", "1er août : nouvelle saison")
	_verifier(not PassSaison.en_intersaison(data, _t("2027-05-30")), "30 mai : dernier jour de la saison")
	_verifier(PassSaison.en_intersaison(data, _t("2027-06-02")), "juin : intersaison")
	_verifier(PassSaison.chapitre_du_jour(data, _t("2026-08-10")) == 0 and PassSaison.chapitre_du_jour(data, _t("2027-05-20")) == 3, "chapitres d'après la date")
	_verifier(PassSaison.chapitre_du_palier(25) == 0 and PassSaison.chapitre_du_palier(26) == 1 and PassSaison.chapitre_du_palier(100) == 3, "chapitres d'après le palier")
	var attendu := PassSaison.palier_attendu(data, _t("2026-11-16"))
	_verifier(attendu > 30 and attendu < 40, "rythme de mi-novembre (%d)" % attendu)
	_verifier(PassSaison.rattrapage(data, 0, _t("2026-11-16")), "en retard : rattrapage")
	_verifier(not PassSaison.rattrapage(data, 50_000, _t("2026-11-16")), "en avance : pas de rattrapage")
	_verifier(not PassSaison.rattrapage(data, 0, _t("2027-06-15")), "pas de rattrapage pendant l'intersaison")


func _tester_recompenses(data: Dictionary) -> void:
	var e := PassSaison.vide()
	var xp := 4_500  # palier 5
	var pretes := PassSaison.a_recuperer(data, e, xp)
	_verifier(pretes.all(func(x): return x[1] == "gratuit"), "sans Premium : piste gratuite seulement")
	_verifier(pretes.size() == 3, "paliers 1, 3, 5 gratuits (%s)" % str(pretes))
	_verifier(not PassSaison.disponible(data, e, xp, 7, "gratuit"), "palier pas encore atteint")
	var g := PassSaison.recuperer(data, e, xp, 1, "gratuit")
	_verifier(g["fanzzy"].size() == 1 and g["fanzzy"][0] in e["fanzzy"], "recrue du palier 1 débloquée")
	_verifier(PassSaison.recuperer(data, e, xp, 1, "gratuit").is_empty(), "une seule fois")
	_verifier(PassSaison.recuperer(data, e, xp, 1, "premium").is_empty(), "Premium bloqué sans achat")
	# Premium acheté en cours de saison : les paliers déjà atteints sont prêts.
	e["premium"] = true
	_verifier(PassSaison.a_recuperer(data, e, xp).size() == 2 + 5, "Premium : paliers 1 à 5 débloqués (%d)" % PassSaison.a_recuperer(data, e, xp).size())
	var tout := PassSaison.recuperer_tout(data, e, xp)
	_verifier(PassSaison.a_recuperer(data, e, xp).is_empty(), "tout récupéré")
	_verifier(tout["skins"].size() >= 2 and int(tout["jetons"]) >= 200, "skins et Jetons gagnés (%s)" % PassSaison.resume(tout))
	var s0: Dictionary = tout["skins"][0]
	_verifier(PassSaison.possede_skin(e, s0["skin"]) and PassSaison.skins_de(e, s0["fanzzy"]).size() >= 1, "skin rangé avec son FANZZY")
	# Paliers bonus après le 100.
	var e2 := PassSaison.vide()
	e2["premium"] = true
	var g2 := PassSaison.recuperer_tout(data, e2, 102_000)
	_verifier(int(e2["bonus_recus"]) == 3 and PassSaison.bonus_a_recuperer(e2, 102_000) == 0, "3 paliers bonus récupérés")
	_verifier(e2["recus"]["premium"].size() == 100 and e2["titres"].size() >= 1, "saison complète : titre gagné (%s)" % str(e2["titres"]))
	_verifier(e2["fanzzy"].size() == 8, "8 recrues sur la saison (%d)" % e2["fanzzy"].size())
	_verifier(int(g2["jetons"]) >= 3 * PassSaison.JETONS_PALIER_BONUS, "Jetons des paliers bonus")


func _tester_saisons() -> void:
	var e := PassSaison.vide()
	_verifier(PassSaison.changer_saison(e, "2026-27") == -1 and e["saison"] == "2026-27", "première saison : l'XP ne change pas")
	_verifier(PassSaison.changer_saison(e, "2026-27") == -1, "même saison : rien ne change")
	e["premium"] = true
	e["recus"]["gratuit"] = [1, 3]
	e["skins"] = [{"skin": "X_dore", "fanzzy": "X", "nom": "X"}]
	e["report"] = 25_000
	var depart := PassSaison.changer_saison(e, "2027-28")
	_verifier(depart == PassSaison.REPORT_MAX, "report limité à 10 paliers (%d)" % depart)
	_verifier(not e["premium"] and e["recus"]["gratuit"].is_empty() and e["report"] == 0, "nouvelle saison remise à zéro")
	_verifier(e["skins"].size() == 1, "les skins gagnés restent")
	var r := PassSaison.reparer({"premium": true, "recus": {"gratuit": [1.0]}})
	_verifier(r["premium"] and r["recus"]["gratuit"] == [1] and r["recus"]["premium"] == [], "sauvegarde réparée")
