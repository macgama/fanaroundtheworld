extends SceneTree
## Tests sans écran du petit boulot de speaker du stade :
##   godot --headless --path . --script tests/test_speaker.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_feuille()
	_tester_programme()
	_tester_chronologie()
	_tester_jugement()
	_tester_paye()
	print("Tests speaker : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_feuille() -> void:
	_verifier(SpeakerRegles.new(3).feuille_de_match() == SpeakerRegles.new(3).feuille_de_match(), "même graine, même feuille")
	for g in 50:
		var f := SpeakerRegles.new(g).feuille_de_match()
		_verifier(f.size() == SpeakerRegles.NB_JOUEURS, "4 joueurs sur la feuille")
		var numeros := {}
		var prenoms := {}
		for j in f:
			numeros[j["numero"]] = true
			prenoms[j["prenom"]] = true
		_verifier(numeros.size() == f.size() and prenoms.size() == f.size(), "numéros et prénoms tous différents")
	var a := SpeakerRegles.annonce({"prenom": "Léo", "nom": "Martin"})
	_verifier(a == ["LÉO !", "MARTIN !"], "annonce prénom puis nom (%s)" % str(a))


func _tester_programme() -> void:
	for g in 100:
		var p := SpeakerRegles.new(g).programme()
		_verifier(p.size() == SpeakerRegles.NB_BUTS, "nombre de buts")
		_verifier(p[0]["local"], "le premier but est pour les locaux")
		var visiteurs := 0
		var bpm_avant := 0.0
		for i in p.size():
			var b: Dictionary = p[i]
			if not b["local"]:
				visiteurs += 1
				_verifier(b["buteur"] == -1, "pas de buteur à annoncer chez les visiteurs")
				_verifier(i == 0 or p[i - 1]["local"], "jamais deux buts des visiteurs d'affilée")
			else:
				_verifier(b["buteur"] >= 0 and b["buteur"] < SpeakerRegles.NB_JOUEURS, "buteur dans la feuille")
				_verifier(b["bpm"] >= bpm_avant, "le tempo ne redescend pas")
				bpm_avant = b["bpm"]
			var ordre: Array = b["ordre"].duplicate()
			ordre.sort()
			_verifier(ordre == range(SpeakerRegles.NB_JOUEURS), "les 4 boutons, chacun une fois")
			_verifier(b["bpm"] <= SpeakerRegles.BPM_MAX, "tempo plafonné")
		_verifier(visiteurs == SpeakerRegles.NB_BUTS_VISITEURS, "buts des visiteurs (%d)" % visiteurs)
		_verifier(p[0]["ordre"] == range(SpeakerRegles.NB_JOUEURS), "1er but : boutons dans l'ordre de la feuille")
	# Durée du match : autour d'une minute, comme la buvette.
	var p2 := SpeakerRegles.new(11).programme()
	var t := 0.0
	for b in p2:
		t += SpeakerRegles.duree_but(b) + SpeakerRegles.PAUSE_ENTRE_BUTS
	print("  durée d'un match : %.1f s" % t)
	_verifier(t > 45.0 and t < 75.0, "un match dure environ une minute (%.1f s)" % t)


func _tester_chronologie() -> void:
	var but := {"local": true, "bpm": 120.0}
	var c := SpeakerRegles.chronologie(but, 10.0)
	_verifier(c["appels"].size() == SpeakerRegles.APPELS_PAR_BUT, "3 appels par but")
	_verifier(c["reponses"].size() == SpeakerRegles.APPELS_PAR_BUT, "3 réponses de la tribune")
	# 120 BPM : 0,5 s par temps, 2 s par mesure ; 1er appel au début de la 2e mesure.
	_verifier(is_equal_approx(c["appels"][0], 12.0), "1er appel après la mesure du but (%.2f)" % c["appels"][0])
	_verifier(is_equal_approx(c["reponses"][0], 13.0), "la tribune répond au 3e temps")
	_verifier(is_equal_approx(c["appels"][2] - c["appels"][1], 2.0), "un appel par mesure")
	_verifier(is_equal_approx(c["fin"], 18.0), "fin après 4 mesures")
	_verifier(c["frappes"][0]["son"] == "clameur_but", "le but commence par la clameur")
	var tri := true
	for i in range(1, c["frappes"].size()):
		tri = tri and c["frappes"][i]["t"] >= c["frappes"][i - 1]["t"]
	_verifier(tri, "frappes triées dans le temps")
	var v := SpeakerRegles.chronologie({"local": false, "bpm": 120.0}, 0.0)
	_verifier(v["appels"].is_empty(), "rien à annoncer pour les visiteurs")
	_verifier(v["frappes"][0]["son"] == "deception", "but des visiteurs : la tribune soupire")
	_verifier(is_equal_approx(v["fin"], 4.0), "but des visiteurs plus court")
	for f in c["frappes"] + v["frappes"]:
		_verifier(f["son"] in ["clameur_but", "deception", "tambour", "clap", "cri_groupe"], "son connu (%s)" % f["son"])


func _tester_jugement() -> void:
	_verifier(SpeakerRegles.juger(0.0, true) == "parfait", "pile dans le tempo : parfait")
	_verifier(SpeakerRegles.juger(-0.1, true) == "bien", "un peu en avance : bien")
	_verifier(SpeakerRegles.juger(0.2, true) == "rate", "trop en retard : raté")
	_verifier(SpeakerRegles.juger(0.0, false) == "faux", "mauvais joueur : faux, même dans le tempo")
	_verifier(SpeakerRegles.juger(1.0, true) == "hors", "loin de l'appel : ne compte pas")
	_verifier(SpeakerRegles.juger(1.0, false) == "hors", "loin de l'appel, mauvais joueur : ne compte pas")


func _tester_paye() -> void:
	var parfait := SpeakerRegles.paye_but(["parfait", "parfait", "parfait"])
	_verifier(parfait["total"] == 3 * 3 + SpeakerRegles.BONUS_TRIPLE, "but parfait : 9 + bonus (%d)" % parfait["total"])
	var mixte := SpeakerRegles.paye_but(["bien", "faux", "parfait"])
	_verifier(mixte["bonus"] == 0 and mixte["total"] == 5, "pas de bonus si un appel est faux")
	_verifier(SpeakerRegles.paye_but(["bien", "bien", "bien"])["bonus"] == SpeakerRegles.BONUS_TRIPLE, "bonus avec trois « bien »")
	_verifier(SpeakerRegles.paye_but([])["total"] == 0, "rien annoncé, rien gagné")
	_verifier(SpeakerRegles.paye_but(["rate", "manque", "hors"])["total"] == 0, "appels ratés : rien")
	_verifier(SpeakerRegles.paye_finale(40, 0) == 40, "plein tarif au 1er match")
	_verifier(SpeakerRegles.paye_finale(41, SpeakerRegles.SERVICES_PLEIN_TARIF) == 21, "paye ÷ 2 après %d matchs" % SpeakerRegles.SERVICES_PLEIN_TARIF)
	# Ordre de grandeur, comme la buvette : parfait ≈ 45 à 60, joueur moyen ≈ 25 à 35.
	var p := SpeakerRegles.new(5).programme()
	var robot := 0
	var moyen := 0
	var notes_moyennes := ["parfait", "bien", "bien", "faux", "parfait", "bien", "rate", "bien", "parfait", "bien", "manque", "bien", "bien", "parfait", "bien"]
	var k := 0
	for b in p:
		if not b["local"]:
			robot += SpeakerRegles.PAYE_SILENCE
			continue
		robot += SpeakerRegles.paye_but(["parfait", "parfait", "parfait"])["total"]
		moyen += SpeakerRegles.paye_but(notes_moyennes.slice(k, k + 3))["total"]
		k += 3
	moyen += SpeakerRegles.PAYE_SILENCE
	print("  match parfait : %d Jetons, joueur moyen : %d Jetons" % [robot, moyen])
	_verifier(robot >= 45 and robot <= 60, "paye d'un match parfait raisonnable (%d)" % robot)
	_verifier(moyen >= 22 and moyen <= 38, "paye d'un joueur moyen raisonnable (%d)" % moyen)
