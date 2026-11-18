extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_club.gd
## Vérifie les règles du fan club : places, recettes, plafond de la caisse,
## après-match, écharpes et améliorations du local.

const H := 3600
const T0 := 1_800_000_000

var _echecs := 0


func _init() -> void:
	_tester_membres()
	_tester_recettes()
	_tester_taille()
	_tester_buvette_et_echarpes()
	_tester_sauvegarde()
	print("Tests fan club : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _proche(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _tester_membres() -> void:
	var c := FanClub.nouveau(["A", "B", "C"], "#1e6bff", "#ffffff", T0)
	_verifier(FanClub.places(1) == 3 and FanClub.places(4) == 9, "places par niveau")
	_verifier(not FanClub.recruter(c, "D", 1, T0), "club plein au niveau 1")
	_verifier(FanClub.recruter(c, "D", 2, T0), "recrutement au niveau 2")
	_verifier(not FanClub.recruter(c, "D", 2, T0), "pas deux fois le même membre")
	_verifier(FanClub.nb_membres(c) == 4, "4 membres")
	_verifier(FanClub.renvoyer(c, "D", T0) and FanClub.nb_membres(c) == 3, "renvoi")
	var seul := FanClub.nouveau(["A"], "#000000", "#ffffff", T0)
	_verifier(not FanClub.renvoyer(seul, "A", T0), "un club garde au moins un membre")
	_verifier(FanClub.sigle("Ultras du Canal") == "UC", "sigle UC (%s)" % FanClub.sigle("Ultras du Canal"))
	_verifier(FanClub.sigle("  ") == "FC", "sigle par défaut")


func _tester_recettes() -> void:
	var c := FanClub.nouveau(["A", "B", "C"], "#1e6bff", "#ffffff", T0)
	c["kop"] = 0  # sans kop : seulement les cotisations des FANZZY
	# 3 membres : 3 x 0,17 J/h x 1,04 = 0,53 J/h
	_verifier(_proche(FanClub.cotisations_heure(c), 0.5304), "cotisations de 3 membres")
	FanClub.avancer(c, T0 + 8 * H)
	_verifier(FanClub.en_caisse(c) == 4, "8 h de cotisations (%d)" % FanClub.en_caisse(c))
	var g := FanClub.recolter(c, T0 + 8 * H)
	_verifier(g == 4 and FanClub.en_caisse(c) == 0, "récolte vide la caisse")
	# La caisse plafonne à HEURES_CAISSE heures.
	FanClub.avancer(c, T0 + 2 * H + 100 * H)
	_verifier(FanClub.en_caisse(c) <= int(FanClub.cotisations_heure(c) * FanClub.HEURES_CAISSE) + 1, "plafond de la caisse")
	# Horloge reculée : rien ne bouge.
	var avant := FanClub.en_caisse(c)
	FanClub.avancer(c, T0)
	_verifier(FanClub.en_caisse(c) == avant, "horloge reculée sans effet")


func _tester_taille() -> void:
	var petit := FanClub.nouveau(["A", "B", "C"], "#1e6bff", "#ffffff", T0)
	var grand := FanClub.nouveau(["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L"], "#1e6bff", "#ffffff", T0)
	_verifier(FanClub.cotisations_heure(grand) / 12.0 > FanClub.cotisations_heure(petit) / 3.0, "un grand club rapporte plus par membre")
	petit["buvette"] = 2
	grand["buvette"] = 2
	_verifier(FanClub.buvette_heure(grand) > FanClub.buvette_heure(petit), "la buvette rapporte plus dans un grand club")
	_verifier(FanClub.prix_echarpe(grand) > FanClub.prix_echarpe(petit), "écharpes plus chères dans un grand club")
	_verifier(FanClub.renommee(1) == "Petit groupe" and FanClub.renommee(18) == "Légende du virage", "renommée")


func _tester_buvette_et_echarpes() -> void:
	var c := FanClub.nouveau(["A", "B", "C"], "#1e6bff", "#ffffff", T0)
	_verifier(FanClub.cout_amelioration(c, "buvette") == 40, "ouverture de la buvette : 40 Jetons")
	FanClub.ameliorer(c, "buvette", T0)
	FanClub.ameliorer(c, "atelier", T0)
	_verifier(c["buvette"] == 1 and c["atelier"] == 1, "améliorations")
	# Après-match : 1 h de duel en plein dans l'intervalle -> buvette x2 sur 1 h.
	var sans := c.duplicate(true)
	FanClub.noter_duel(c, T0)
	FanClub.avancer(c, T0 + H)
	FanClub.avancer(sans, T0 + H)
	_verifier(_proche(float(c["caisse_buvette"]), 2.0 * float(sans["caisse_buvette"])), "après-match double la buvette")
	_verifier(FanClub.apres_match(c, T0 + H) and not FanClub.apres_match(c, T0 + 4 * H), "fenêtre d'après-match de 3 h")
	# Écharpes : 0,35 par heure avec l'atelier niveau 1 (1 toutes les 3 h), stock limité.
	FanClub.avancer(c, T0 + 3 * H)
	_verifier(int(c["echarpes"]) == 1, "1 écharpe après 3 h (%s)" % str(c["echarpes"]))
	FanClub.avancer(c, T0 + 50 * H)
	_verifier(int(c["echarpes"]) == FanClub.stock_max(c), "stock d'écharpes plafonné")
	var gain := FanClub.vendre_echarpes(c, T0 + 50 * H)
	_verifier(gain == FanClub.stock_max(c) * FanClub.prix_echarpe(c) and int(c["echarpes"]) == 0, "vente des écharpes")
	for i in 10:
		FanClub.ameliorer(c, "atelier", T0 + 50 * H)
	_verifier(c["atelier"] == FanClub.niveau_max("atelier") and FanClub.cout_amelioration(c, "atelier") == -1, "niveau max de l'atelier")


func _tester_sauvegarde() -> void:
	var r := FanClub.reparer({"cree": true, "membres": ["A"], "buvette": 99})
	_verifier(r["buvette"] == FanClub.niveau_max("buvette"), "niveau réparé")
	_verifier(r.has("caisse_cotisations") and r.has("echarpes"), "champs manquants ajoutés")
	_verifier(not FanClub.reparer(null)["cree"], "pas de club dans une vieille sauvegarde")
	var j: Variant = JSON.parse_string(JSON.stringify(FanClub.nouveau(["A"], "#1e6bff", "#ffffff", T0)))
	var c := FanClub.reparer(j)
	c["kop"] = 0
	FanClub.avancer(c, T0 + 8 * H)
	_verifier(FanClub.en_caisse(c) == 1, "club relu depuis le JSON")
	# kop : départ, sauvegarde d'avant le kop, cotisations du kop
	_verifier(int(FanClub.nouveau(["A"], "#1e6bff", "#ffffff", T0)["kop"]) == Kop.DEPART, "kop de départ")
	var ancien := FanClub.reparer({"cree": true, "membres": ["A", "B", "C", "D", "E"]})
	_verifier(int(ancien["kop"]) == Kop.DEPART + 2 * Kop.PAR_MEMBRE_ANCIEN, "kop d'une ancienne sauvegarde (%d)" % int(ancien["kop"]))
	_verifier(ancien["rencontres"] is Array and ancien.get("rencontres_offertes", true) == false, "rencontres à offrir à une ancienne sauvegarde")
	var gros := FanClub.nouveau(["A", "B", "C"], "#1e6bff", "#ffffff", T0)
	gros["kop"] = 10000
	_verifier(_proche(FanClub.cotisations_heure(gros), 0.5304 + 1.7), "le kop cotise aussi")
