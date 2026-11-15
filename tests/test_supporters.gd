extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_supporters.gd
## Équipes favorites (un club par pays + une sélection) et points de popularité.

const T0 := 1_800_000_000
const JOUR := 86400

var _echecs := 0


func _init() -> void:
	_tester_choix()
	_tester_points()
	_tester_prono_et_club()
	_tester_classement()
	print("Tests supporters : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _match_club(id := "m1") -> Dictionary:
	return {"id": id, "competition": {"id": "fr.1"}, "home": {"id": "af:85", "name": "x"}, "away": {"id": "af:81", "name": "y"}}


func _match_selection(dom := "France", ext := "Brazil") -> Dictionary:
	return {"id": "s1", "competition": {"id": "friendlies"}, "home": {"id": "af:2", "name": dom}, "away": {"id": "af:6", "name": ext}}


func _tester_choix() -> void:
	var s := Supporters.vide()
	_verifier(Supporters.choisir_club(s, "france", "af:85", T0), "premier club de France")
	_verifier(Supporters.choisir_club(s, "spain", "af:541", T0), "un club par pays : Espagne aussi")
	_verifier(not Supporters.choisir_club(s, "france", "af:81", T0 + JOUR), "pas de changement avant 7 jours")
	_verifier(Supporters.choisir_club(s, "france", "af:81", T0 + 7 * JOUR), "changement après 7 jours")
	_verifier(Supporters.club_du_pays(s, "france") == "af:81" and s["clubs"].size() == 2, "un seul club en France")
	_verifier(not Supporters.retirer_club(s, "france", T0 + 8 * JOUR), "retrait bloqué juste après un changement")
	_verifier(Supporters.retirer_club(s, "spain", T0 + 8 * JOUR), "retrait de l'Espagne")
	_verifier(Supporters.choisir_nation(s, "france", T0), "équipe nationale")
	_verifier(not Supporters.choisir_nation(s, "brazil", T0 + JOUR), "une seule équipe nationale, changement après 7 jours")
	_verifier(Supporters.est_favori(s, "nation:france") and not Supporters.est_favori(s, "nation:brazil"), "est_favori nation")
	_verifier(Supporters.cle_equipe({"name": "France U20"}, true) == "", "les sélections de jeunes ne comptent pas")
	_verifier(Supporters.cle_equipe({"name": "France"}, true) == "nation:france", "clé de sélection")
	_verifier(Supporters.camps_favoris(s, _match_selection()) == ["home"], "camp favori d'une sélection")
	_verifier(Supporters.camps_favoris(s, _match_club()) == ["away"], "camp favori d'un club")
	var r := Supporters.reparer({"clubs": "abîmé", "nation": {"pays": "italy", "depuis": 1}})
	_verifier(r["clubs"] is Dictionary and r["nation"]["pays"] == "italy", "réparation d'une vieille sauvegarde")


func _tester_points() -> void:
	var s := Supporters.vide()
	Supporters.choisir_club(s, "france", "af:85", T0)
	var m := _match_club()
	_verifier(Supporters.noter_duel(s, m, "away", true, 1.5, T0) == 0, "pas de points pour un camp non favori")
	_verifier(Supporters.noter_duel(s, m, "home", true, 1.5, T0) == 30, "duel gagné au stade : (10+10)×1,5")
	_verifier(Supporters.noter_duel(s, m, "home", false, 0.6, T0) == 6, "duel perdu à la maison : 10×0,6")
	_verifier(Supporters.noter_suivi(s, m, "home", "stade", T0) == 20, "déplacement au stade")
	_verifier(Supporters.noter_suivi(s, m, "home", "stade", T0) == 0, "un seul déplacement compté par match")
	_verifier(int(s["points"]["af:85"]) == 56, "total des points")
	_verifier(s["a_envoyer"].size() == 3, "file prête pour l'envoi en ligne")
	for i in 20:
		Supporters.noter_duel(s, _match_club("r%d" % i), "home", true, 1.5, T0)
	_verifier(int(s["du_jour"]["af:85"]) == Supporters.MAX_PAR_JOUR, "plafond du jour")
	_verifier(Supporters.noter_duel(s, m, "home", true, 1.5, T0 + JOUR) == 30, "le plafond repart le lendemain")


func _tester_prono_et_club() -> void:
	var s := Supporters.vide()
	Supporters.choisir_club(s, "france", "af:85", T0)
	Supporters.choisir_club(s, "germany", "af:157", T0)
	Supporters.choisir_nation(s, "france", T0)
	var p := _match_club()
	_verifier(Supporters.noter_prono(s, p, {"etat": "gagne", "resultat_ok": true, "score_ok": true}, T0) == 20, "prono exact : 3+7+10")
	_verifier(Supporters.noter_prono(s, p, {"etat": "perdu"}, T0) == 3, "prono raté : participation")
	_verifier(Supporters.noter_prono(s, p, {"etat": "annule"}, T0) == 0, "prono annulé : rien")
	_verifier(Supporters.noter_club(s, 95, T0) == 27, "récolte de 95 Jetons : 9 points pour chacun des 3 favoris")
	_verifier(Supporters.noter_club(s, 5, T0) == 0, "petite récolte : rien")


func _tester_classement() -> void:
	var t := Supporters.DEBUT_SAISON + 10 * JOUR
	var a := Supporters.base_communaute("af:1", false, t)
	_verifier(a == Supporters.base_communaute("af:1", false, t), "base stable")
	_verifier(Supporters.base_communaute("af:1", false, t + JOUR) > a, "la communauté grandit chaque jour")
	_verifier(Supporters.base_communaute("af:1", true, t) > a, "un club connu a plus de supporters")
	var eq := [{"cle": "a"}, {"cle": "b"}, {"cle": "c"}]
	var c := Supporters.classement(eq, {"a": 100, "b": 90, "c": 50}, {"b": 20})
	_verifier(c[0]["cle"] == "b" and c[0]["points"] == 110 and c[0]["a_toi"] == 20, "tes points font monter ton équipe")
	_verifier(c[2]["rang"] == 3, "rangs")
