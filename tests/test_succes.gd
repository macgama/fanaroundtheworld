extends SceneTree
## Tests sans écran des succès et du choix de sauvegarde (ce PC ou Steam Cloud) :
##   godot --headless --path . --script tests/test_succes.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_liste()
	_tester_deblocage()
	_tester_compteurs()
	_tester_reparer()
	_tester_choix_sauvegarde()
	print("Tests succès : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


## Ids d'API Steam valides et uniques, textes FR et EN présents.
func _tester_liste() -> void:
	var vus := {}
	var re := RegEx.create_from_string("^[A-Z0-9_]+$")
	for s in Succes.LISTE:
		var id: String = s["id"]
		_verifier(re.search(id) != null and id.length() <= 64, "id d'API Steam valide : %s" % id)
		_verifier(not vus.has(id), "id unique : %s" % id)
		vus[id] = true
		for k in ["titre", "texte", "titre_en", "texte_en", "cle", "icone", "couleur"]:
			_verifier(str(s.get(k, "")) != "", "%s a « %s »" % [id, k])
		_verifier(Succes.seuil(s) >= 1, "%s : seuil ≥ 1" % id)
	_verifier(Succes.LISTE.size() >= 20, "au moins 20 succès (%d)" % Succes.LISTE.size())
	_verifier(Succes.seuil(Succes.par_id("BOULOTS_TOUS")) == ListeBoulots.LISTE.size(), "« tous les boulots » suit la liste des boulots")


func _tester_deblocage() -> void:
	var gagnes := {}
	var r := Succes.noter(gagnes, {}, 100)
	_verifier(r.is_empty(), "rien au départ")
	r = Succes.noter(gagnes, {"duels_joues": 1, "duels_gagnes": 1}, 200)
	var ids := r.map(func(s): return s["id"])
	_verifier("PREMIER_DUEL" in ids and "PREMIERE_VICTOIRE" in ids and ids.size() == 2, "premier duel gagné : 2 succès (%s)" % str(ids))
	_verifier(int(gagnes["PREMIER_DUEL"]) == 200, "date de déblocage notée")
	r = Succes.noter(gagnes, {"duels_joues": 1, "duels_gagnes": 1}, 300)
	_verifier(r.is_empty(), "un succès ne se gagne qu'une fois")
	r = Succes.noter(gagnes, {}, 400)
	_verifier(gagnes.has("PREMIER_DUEL"), "un succès gagné ne se perd pas")
	var p := Succes.progres(Succes.par_id("VICTOIRES_25"), {"duels_gagnes": 7})
	_verifier(p == Vector2i(7, 25), "progrès 7 / 25 (%s)" % p)
	p = Succes.progres(Succes.par_id("VICTOIRES_25"), {"duels_gagnes": 70})
	_verifier(p == Vector2i(25, 25), "progrès borné au seuil (%s)" % p)
	var tous := {}
	for s in Succes.LISTE:
		tous[s["cle"]] = 1000
	_verifier(Succes.noter({}, tous, 1).size() == Succes.LISTE.size(), "tout est atteignable")


func _tester_compteurs() -> void:
	var st := {}
	Succes.compter(st, "duel_gagne", "arene", 1)
	Succes.compter(st, "duel_gagne", "duel", 2)
	Succes.compter(st, "nouveau_stade", "psg", 1)
	_verifier(st.get("duel_gagne") == 3 and st.get("duel_gagne:arene") == 1, "compteur total et par jeu (%s)" % str(st))
	_verifier(not st.has("nouveau_stade:psg") and st.get("nouveau_stade") == 1, "pas de clé pour les autres événements")
	var r := Succes.noter({}, st, 1).map(func(s): return s["id"])
	_verifier("ARENE_VICTOIRE" in r and not "POUSSEE_VICTOIRE" in r, "victoire dans l'Arène seulement (%s)" % str(r))


func _tester_reparer() -> void:
	var r := Succes.reparer({"PREMIER_DUEL": 5.0, "INCONNU": 3, 7: 1})
	_verifier(r == {"PREMIER_DUEL": 5}, "réparation : ids connus et dates entières (%s)" % str(r))
	_verifier(Succes.reparer(null).is_empty() and Succes.reparer([1]).is_empty(), "réparation d'une sauvegarde sans succès")
	_verifier(Succes.reparer_stats({"a": 2.0}) == {"a": 2}, "réparation des compteurs")


func _tester_choix_sauvegarde() -> void:
	var loc := {"sauve_le": 100, "jetons": 1}
	var cl := {"sauve_le": 200, "jetons": 2}
	_verifier(SauvegardeCloud.choisir(loc, cl) == cl, "Steam Cloud plus récent : il gagne")
	_verifier(SauvegardeCloud.choisir(cl, loc) == cl, "ce PC plus récent : il gagne")
	_verifier(SauvegardeCloud.choisir(loc, {"sauve_le": 100, "jetons": 9}) == loc, "égalité : ce PC")
	_verifier(SauvegardeCloud.choisir(null, cl) == cl, "rien sur ce PC : Steam Cloud")
	_verifier(SauvegardeCloud.choisir(loc, null) == loc, "rien dans le Cloud : ce PC")
	_verifier(SauvegardeCloud.choisir({"jetons": 3}, cl) == cl, "ancienne sauvegarde sans date : le Cloud daté gagne")
	_verifier(SauvegardeCloud.choisir("illisible", "x") == null, "rien de lisible : nouvelle partie")
