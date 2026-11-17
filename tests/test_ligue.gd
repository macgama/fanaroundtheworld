extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_ligue.gd
## Règles de la Ligue des tribunes : calendrier, clubs du jeu (mêmes valeurs que le
## serveur, test/ligue.test.js), duels, plafonds, fin de saison et récompenses.

var _echecs := 0
var VEN := int(Time.get_unix_time_from_datetime_string("2026-11-13T00:00:00"))  # 2e journée de novembre
var SAM := VEN + 86400


func _init() -> void:
	_calendrier()
	_clubs_du_jeu()
	_duels()
	_serveur()
	_fin_de_saison()
	_protocole()
	print("Tests ligue : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _v(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _t(iso: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(iso))


func _calendrier() -> void:
	var nov := Ligue.journees("2026-11")
	_v(nov.map(func(j): return j["id"]) == ["2026-11-06", "2026-11-13", "2026-11-20", "2026-11-27"], "4 journées en novembre 2026")
	_v(Ligue.journees("2027-01").size() == 5, "5 journées en janvier 2027")
	var c := Ligue.calendrier(SAM)
	_v(c["saison"] == "2026-11" and c["etat"] == "journee" and int(c["journee"]["n"]) == 2, "samedi : 2e journée")
	_v(Ligue.calendrier(VEN + 4 * 86400)["etat"] == "pause", "mardi : pause")
	_v(Ligue.calendrier(_t("2026-11-30T12:00:00"))["etat"] == "finie", "lundi midi de la dernière journée : finie")
	_v(Ligue.calendrier(_t("2026-12-03T10:00:00"))["saison"] == "2026-11", "jeudi 3 déc. : encore novembre")
	_v(Ligue.calendrier(_t("2026-12-04T00:00:00"))["saison"] == "2026-12", "vendredi 4 déc. : décembre")
	_v(Ligue.saison_suivante("2026-12") == "2027-01", "saison suivante")
	_v(Ligue.avancee("2026-11", VEN) == 1000 and Ligue.avancee("2026-11", _t("2026-12-01T00:00:00")) == 4000, "avancée")
	_v(Ligue.match_de_la_journee(SAM + 3600, c) and not Ligue.match_de_la_journee(VEN - 60, c), "match du week-end")


func _clubs_du_jeu() -> void:
	_v(Ligue.fnv("") == 0x811c9dc5 and Ligue.fnv("a") == 0xe40c292c, "FNV-1a")
	_v(Ligue.fnv("2026-11|5|0|3") == 317649862 and Ligue.melange(317649862) == 1099028920, "même empreinte que le serveur")
	var b := Ligue.bot("2026-11", 5, 0, 3)
	_v(b["nom"] == [1, 8] and b["couleurs"] == [7, 8] and int(b["force"]) == 731, "même club du jeu que le serveur")
	_v(Ligue.points_bot(b, "2026-11", SAM) == (731 * 12 * 1285) / 1000000, "mêmes points que le serveur")
	_v(Ligue.points_duel(1, true) == 4 and Ligue.points_duel(0, false) == 2 and Ligue.points_duel(-1, false) == 1, "points d'un duel")
	_v(Ligue.mouvement(5, 1) == 1 and Ligue.mouvement(1, 1) == 0 and Ligue.mouvement(3, 9) == -1 and Ligue.mouvement(5, 10) == 0, "montées et descentes")


func _inscrit() -> Dictionary:
	var s := Ligue.vide()
	Ligue.actualiser(s, SAM)
	s["inscrit"] = true
	return s


func _duels() -> void:
	var s := Ligue.vide()
	Ligue.actualiser(s, SAM)
	_v(s["saison"] == "2026-11", "saison posée")
	var b0 := {"id": "bot:0", "bot": true, "nom": [1, 1], "couleurs": [0, 1]}
	_v(Ligue.noter_duel(s, "0000000000000001", b0, "af:1", SAM, 1, false, SAM).is_empty(), "pas inscrit : rien")
	s = _inscrit()
	_v(Ligue.noter_duel(s, "0000000000000001", b0, "af:1", VEN - 3600, 1, false, SAM).is_empty(), "match du jeudi : refusé")
	_v(Ligue.noter_duel(s, "0000000000000001", b0, "af:1", SAM, 1, false, VEN + 4 * 86400).is_empty(), "mardi : refusé")
	var d := Ligue.noter_duel(s, "0000000000000001", b0, "af:1", SAM, 1, true, SAM)
	_v(int(d["pts"]) == 4 and d["etat"] == "local", "victoire en direct contre un club du jeu : 4 pts")
	Ligue.noter_duel(s, "0000000000000002", b0, "af:2", SAM, -1, false, SAM)
	_v(Ligue.noter_duel(s, "0000000000000003", b0, "af:3", SAM, 1, false, SAM).is_empty(), "2 duels au plus contre le même club")
	Ligue.noter_duel(s, "0000000000000004", {"id": "bot:1", "bot": true}, "af:4", SAM, 1, false, SAM)
	_v(Ligue.raison_refus(s, "bot:2", SAM, SAM) != "", "3 clubs du jeu par journée")
	var joueur := {"id": "abcdef0123456789", "bot": false, "nom": [2, 3], "couleurs": [1, 2]}
	d = Ligue.noter_duel(s, "0000000000000005", joueur, "af:5", SAM, 0, false, SAM)
	_v(d["etat"] == "attente" and int(d["pts"]) == 2, "nul en ligne : en attente du serveur")
	_v(Ligue.points(s) == 4 + 1 + 3 + 2, "points locaux (attente comprise)")
	_v(Ligue.duels_comptes(s) == 3, "duels comptés (sans l'attente)")
	for i in 5:
		Ligue.noter_duel(s, "00000000000001%02d" % i, {"id": "%016x" % (100 + i), "bot": false}, "af:9", SAM, 1, false, SAM)
	_v(Ligue.compteurs(s, "2026-11-13")["n"] == Ligue.DUELS_JOURNEE, "6 duels par journée")
	_v(Ligue.a_envoyer(s).size() == Ligue.DUELS_JOURNEE, "6 résultats à envoyer")
	var s2 := _inscrit()
	Ligue.noter_duel(s2, "00000000000000aa", joueur, "af:5", SAM, 1, false, SAM)
	Ligue.expirer(s2, VEN + 4 * 86400)
	_v(s2["duels"][0]["etat"] == "non_confirme" and Ligue.points(s2) == 0, "jamais confirmé : ne compte pas")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var code := Ligue.nouveau_code(rng)
	_v(Ligue.code_valide(code) and not Ligue.code_valide("xyz") and not Ligue.code_valide(12), "codes de duel")


func _serveur() -> void:
	var s := _inscrit()
	var joueur := {"id": "abcdef0123456789", "bot": false}
	Ligue.noter_duel(s, "00000000000000aa", joueur, "af:5", SAM, 1, false, SAM)
	Ligue.noter_duel(s, "00000000000000bb", joueur, "af:6", SAM, 1, false, SAM)
	Ligue.appliquer_serveur(s, {"saison": "2026-11", "points": 3, "rang": 4, "division": 4, "poule": 2, "mouvement": 0,
		"comptes": {"00000000000000aa": 3, "00000000000000bb": 0}})
	_v(s["duels"][0]["etat"] == "compte" and s["duels"][1]["etat"] == "refuse", "confirmations du serveur")
	_v(Ligue.points(s) == 3 and int(s["division"]) == 4 and int(s["poule"]) == 2, "points et division du serveur")
	Ligue.appliquer_serveur(s, {"saison": "2026-10", "points": 99})
	_v(Ligue.points(s) == 3, "réponse d'une autre saison ignorée")
	var p := Ligue.poule_locale(s, SAM)
	_v(p.size() == Ligue.TAILLE_POULE and p.filter(func(l): return l["moi"]).size() == 1, "poule locale de 10")
	_v(Ligue.bots_de_la_poule(s, {}, SAM).size() == Ligue.TAILLE_POULE - 1, "9 clubs du jeu hors ligne")
	_v(Ligue.bots_de_la_poule(s, {"saison": "2026-11", "clubs": [{"id": "bot:0", "bot": true}, {"id": "x", "bot": false}]}, SAM).size() == 1, "clubs du jeu de la poule du serveur")


func _fin_de_saison() -> void:
	var s := _inscrit()
	s["division"] = 3
	for j in Ligue.journees("2026-11"):
		var t := int(j["debut"]) + 3600
		for k in 3:
			Ligue.noter_duel(s, "%016x" % (t + k), {"id": "bot:%d" % k, "bot": true}, "af:%d" % k, t, 1, true, t)
	_v(Ligue.points(s) == 3 * 4 * 4, "48 points en 4 journées")
	var dec := _t("2026-12-05T10:00:00")
	_v(Ligue.actualiser(s, dec), "nouvelle saison")
	var r: Dictionary = s["a_reclamer"]
	_v(r["saison"] == "2026-11" and int(r["rang"]) == 1 and int(r["mouvement"]) == 1, "1er : montée")
	_v(int(s["division"]) == 2 and s["saison"] == "2026-12" and (s["duels"] as Array).is_empty() and not bool(s["inscrit"]), "décembre en Ligue Or")
	var g := Ligue.recompense(r)
	_v(int(g["jetons"]) == 110 + Ligue.BONUS_CHAMPION + Ligue.BONUS_MONTEE and int(g["xp_pass"]) == 320, "récompense Ligue Argent + champion + montée")
	_v(int(Ligue.reclamer(s)["jetons"]) == 260 and Ligue.reclamer(s).is_empty(), "une seule fois")
	_v((s["historique"] as Array).size() == 1, "historique")
	_v(Ligue.recompense({"division": 1, "duels": 2}).get("jetons") == 0, "moins de 3 duels : rien")
	# Saison jouée sans duel : rien à réclamer, même division.
	var vide := _inscrit()
	vide["division"] = 4
	Ligue.actualiser(vide, dec)
	_v((vide["a_reclamer"] as Dictionary).is_empty() and int(vide["division"]) == 4, "saison sans duel")
	_v(Ligue.saison_texte("2026-11") == "novembre 2026", "nom de saison")


func _protocole() -> void:
	var p := Protocole.profil("Les Testeurs", [Color.RED, Color.BLUE], ["a", "b", "c"], 3, [], {"fan": "abcdef0123456789", "nom": [4, 5]})
	_v(Protocole.valide(p), "profil avec la Ligue : valide")
	var q := Protocole.profil_propre(p)
	_v(q["fan"] == "abcdef0123456789" and q["ligue_nom"] == [4, 5], "identité de Ligue lue")
	p["fan"] = "ABCDEF0123456789"
	_v(Protocole.profil_propre(p)["fan"] == "", "identité mal formée : ignorée")
	var ancien := Protocole.profil("Ancien", [Color.RED, Color.BLUE], [], 1)
	_v(Protocole.profil_propre(ancien)["fan"] == "" and not ancien.has("fan"), "ancienne version : pas de Ligue")
	_v(Protocole.code_ligue({"t": "lancer", "jeu": "duel", "code": "00000000000000ab"}) == "00000000000000ab", "code du duel lu")
	_v(Protocole.code_ligue({"t": "lancer", "jeu": "duel", "code": "zz"}) == "" and Protocole.code_ligue({"t": "lancer", "jeu": "duel"}) == "", "code absent ou mal formé")
