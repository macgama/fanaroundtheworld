extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_classement.gd
## Classement en ligne : identité, pseudo, file d'envoi, points des autres supporters.
## (Le serveur a ses propres tests : macgama/fanaroundtheworld-data, test/classement.test.js.)

var _echecs := 0


func _init() -> void:
	_tester_identite()
	_tester_envoi()
	_tester_communaute()
	print("Tests classement : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_identite() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var a := ClassementFans.identite_neuve(rng)
	var b := ClassementFans.identite_neuve(rng)
	_verifier(ClassementFans.identite_valide(a), "identité valide")
	_verifier(a["id"] != b["id"] and a["cle"] != b["cle"], "deux identités différentes")
	var hexa := RegEx.create_from_string("^[0-9a-f]+$")
	_verifier(hexa.search(a["id"]) != null and hexa.search(a["cle"]) != null, "hexadécimal (format du serveur)")
	_verifier(ClassementFans.NOMS.size() <= 64 and ClassementFans.QUALITES.size() <= 64, "listes de 64 mots au plus (limite du serveur)")
	_verifier(ClassementFans.pseudo_texte([0, 0, 42]) == "Tambour Joyeux 42", "pseudo lisible")
	_verifier(ClassementFans.pseudo_texte([63, 63, 1]) == "Supporter Mystère 1", "mot inconnu : pseudo de secours")
	_verifier(ClassementFans.pseudo_texte(null) == "Supporter mystère", "pseudo absent")
	# Fichier abîmé ou relu depuis JSON (nombres flottants).
	var r := ClassementFans.reparer({"id": a["id"], "cle": a["cle"], "pseudo": [3.0, 500.0, -2.0], "visible": "oui"})
	_verifier(r["pseudo"] == [3, ClassementFans.QUALITES.size() - 1, 0], "pseudo ramené dans les listes")
	_verifier(r["visible"] == true, "visibilité par défaut si le type est faux")
	_verifier(not ClassementFans.identite_valide(ClassementFans.reparer(null)), "fichier absent : identité à créer")
	# Les mots doivent rester familiaux et uniques.
	var vus := {}
	for m in ClassementFans.NOMS + ClassementFans.QUALITES:
		_verifier(not vus.has(m), "mot en double : %s" % m)
		vus[m] = true


func _tester_envoi() -> void:
	var s := Supporters.vide()
	var t := 1_800_000_000
	Supporters.choisir_club(s, "france", "af:85", t)
	Supporters.donner(s, "af:85", 20, "duel", t)
	Supporters.donner(s, "af:85", 5, "suivi", t + 10)
	var ident := ClassementFans.identite_neuve(RandomNumberGenerator.new())
	var env := ClassementFans.preparer_envoi(s, ident)
	_verifier(env["n"] == 2, "deux lignes à envoyer")
	var c: Dictionary = env["corps"]
	_verifier(c["id"] == ident["id"] and c["cle"] == ident["cle"] and c["v"] == 1, "identité dans l'envoi")
	_verifier(c["points"][0] == {"equipe": "af:85", "points": 20, "raison": "duel", "t": t}, "ligne au format du serveur")
	_verifier(JSON.stringify(c).find("Ultras") == -1, "aucun texte libre (nom du fan club) dans l'envoi")
	# Un gain arrive pendant l'envoi : il reste dans la file.
	Supporters.donner(s, "af:85", 3, "prono", t + 20)
	ClassementFans.appliquer_reponse(s, env["n"], {"af:85": 25})
	_verifier(s["a_envoyer"].size() == 1 and s["a_envoyer"][0]["raison"] == "prono", "seules les lignes envoyées sont retirées")
	_verifier(s["envoye"] == {"af:85": 25}, "points comptés par le serveur notés")
	ClassementFans.appliquer_reponse(s, 1, {"af:85": 3})
	_verifier(s["a_envoyer"].is_empty() and s["envoye"]["af:85"] == 28, "file vide, total envoyé")
	# File plus longue que la limite du serveur : envoi en plusieurs fois.
	for i in 400:
		s["a_envoyer"].append({"equipe": "af:85", "points": 1, "raison": "duel", "t": t})
	_verifier(ClassementFans.preparer_envoi(s, ident)["n"] == ClassementFans.MAX_LIGNES, "300 lignes au plus par envoi")
	# Ancienne sauvegarde sans « envoye ».
	var vieille := Supporters.reparer({"points": {"af:85": 10}})
	_verifier(vieille["envoye"] == {}, "ancienne sauvegarde réparée")


func _tester_communaute() -> void:
	var eq := {"af:85": {"p": 120, "s": 30, "f": 4}, "af:81": {"p": 10, "s": 0, "f": 1}, "nation:france": {"p": 50, "s": 50, "f": 2}}
	var c := ClassementFans.communaute(eq, {"af:85": 25, "af:81": 40})
	_verifier(c["af:85"] == 95, "les autres = total du serveur moins tes points déjà comptés")
	_verifier(c["af:81"] == 0, "jamais négatif")
	# Mes équipes : tes points s'ajoutent aux autres (pas comptés deux fois).
	var lignes := Supporters.classement([{"cle": "af:85"}, {"cle": "af:81"}], c, {"af:85": 30})
	_verifier(lignes[0]["cle"] == "af:85" and lignes[0]["points"] == 125, "classement avec tes points non encore envoyés")
	var clubs := ClassementFans.lignes_equipes(eq, "p", func(k: String): return not Supporters.est_nation(k))
	_verifier(clubs.size() == 2 and clubs[0]["cle"] == "af:85" and clubs[0]["rang"] == 1 and clubs[0]["fans"] == 4, "clubs triés")
	var sem := ClassementFans.lignes_equipes(eq, "s")
	_verifier(sem.size() == 2 and sem[0]["cle"] == "nation:france", "semaine : équipes sans point retirées")
