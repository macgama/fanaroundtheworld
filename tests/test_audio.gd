extends SceneTree
## Tests sans écran du son : godot --headless --path . --script tests/test_audio.gd
## Vérifie le module de rythme, le catalogue, les chants et les bus.

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_pistes()
	_tester_grille()
	_tester_acceleration()
	_tester_jugement()
	_tester_chants()
	_tester_catalogue()
	_tester_bus()
	print("Tests audio : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _proche(a: float, b: float, eps := 0.0001) -> bool:
	return absf(a - b) <= eps


func _tester_pistes() -> void:
	var p := Rythme.lire_piste("X..x", 8)
	_verifier(p.size() == 8, "une piste a la longueur de la mesure")
	_verifier(_proche(p[0], 1.0) and _proche(p[3], 0.75) and _proche(p[1], 0.0), "X fort, x normal, . rien")
	_verifier(_proche(p[4], 1.0) and _proche(p[7], 0.75), "une piste courte se répète")
	_verifier(_proche(Rythme.lire_piste("o| .", 2)[0], 0.45), "o léger, espaces et barres ignorés")


func _tester_grille() -> void:
	var r := Rythme.depuis_chant({"bpm": 120, "temps_par_mesure": 4, "pas_par_temps": 4,
		"pistes": {"T": "x...x...x...x...", "C": "..x...x...x...x.", "J": "..x...x...x...x."}}, 0.0, 1.0)
	_verifier(_proche(r.duree_temps(), 0.5), "120 BPM : un temps dure 0,5 s")
	_verifier(_proche(r.instant_temps(0), 1.0), "le premier temps tombe au début")
	_verifier(_proche(r.instant_temps(5), 3.5), "le sixième temps tombe à 3,5 s")
	_verifier(_proche(r.instant_pas(0, 2), 1.25), "un contretemps tombe à mi-temps")
	_verifier(_proche(r.temps_a(2.0), 2.0), "à 2 s on est au troisième temps")
	var n := r.notes_joueur(2)
	_verifier(n.size() == 8, "deux mesures de contretemps : 8 appuis")
	_verifier(_proche(n[0], 1.25) and _proche(n[7], 4.75), "les appuis du contretemps")
	var f := r.frappes(1)
	_verifier(f.size() == 8, "une mesure : 4 tambours et 4 claps")
	for i in range(1, f.size()):
		_verifier(f[i]["t"] >= f[i - 1]["t"], "les frappes sont triées")
	_verifier(_proche(r.duree(2), 4.0), "deux mesures à 120 BPM durent 4 s")
	var sans_j := Rythme.depuis_chant({"bpm": 60, "pistes": {"T": "x..."}})
	_verifier(sans_j.notes_joueur(1).size() == 4, "sans piste J, chaque temps est une note")


func _tester_acceleration() -> void:
	var r := Rythme.depuis_chant({"bpm": 60, "bpm_par_mesure": 30, "bpm_max": 120,
		"temps_par_mesure": 4, "pas_par_temps": 1, "pistes": {"T": "X..."}})
	_verifier(_proche(r.bpm_de_mesure(0), 60) and _proche(r.bpm_de_mesure(1), 90), "le BPM monte à chaque mesure")
	_verifier(_proche(r.bpm_de_mesure(5), 120), "le BPM plafonne")
	_verifier(_proche(r.debut_mesure(1), 4.0), "la première mesure à 60 BPM dure 4 s")
	_verifier(_proche(r.debut_mesure(2), 4.0 + 4 * 60.0 / 90.0), "la deuxième est plus courte")
	var f := r.frappes(3)
	_verifier(f.size() == 3 and f[2]["t"] > f[1]["t"], "une frappe par mesure, dans l'ordre")


func _tester_jugement() -> void:
	_verifier(Rythme.juger_ecart(0.0)["note"] == "parfait", "pile : parfait")
	_verifier(Rythme.juger_ecart(-0.05)["note"] == "parfait", "50 ms d'avance : parfait")
	_verifier(Rythme.juger_ecart(0.1)["note"] == "bien", "100 ms de retard : bien")
	_verifier(Rythme.juger_ecart(0.2)["note"] == "rate", "200 ms : raté")
	_verifier(Rythme.juger_ecart(0.5)["note"] == "hors", "500 ms : ce n'était pas pour cette note")
	var r := Rythme.new()
	r.tolerance = 1.5
	_verifier(r.juger(1.08, 1.0)["note"] == "parfait", "la tolérance élargit les fenêtres")
	_verifier(_proche(r.juger(0.9, 1.0)["ecart"], -0.1), "l'écart est signé (négatif = en avance)")
	var notes := PackedFloat32Array([0.5, 1.0, 1.5, 2.0])
	_verifier(Rythme.plus_proche(notes, 1.2) == 1, "la note la plus proche de 1,2 s est la deuxième")
	_verifier(Rythme.plus_proche(notes, 1.3) == 2, "celle de 1,3 s est la troisième")
	_verifier(Rythme.plus_proche(PackedFloat32Array(), 1.0) == -1, "pas de note : -1")


func _tester_chants() -> void:
	var c := Rythme.chants()
	_verifier(c.size() >= 6, "au moins six chants")
	var voix_connues: Dictionary = BanqueSons.catalogue().get("voix_des_chants", {})
	for id in c:
		var ch: Dictionary = c[id]
		var r := Rythme.depuis_chant(ch)
		_verifier(r.bpm >= 50 and r.bpm <= 200, "%s : BPM raisonnable" % id)
		_verifier(r.notes_joueur(1).size() > 0, "%s : au moins un appui par mesure" % id)
		_verifier(not r.frappes(1).is_empty(), "%s : au moins une frappe par mesure" % id)
		for v in ch.get("pistes", {}):
			_verifier(v == "J" or voix_connues.has(v), "%s : la voix %s a un son" % [id, v])
			var lg := String(ch["pistes"][v]).length()
			_verifier(lg == r.pas_par_mesure(), "%s : la piste %s fait une mesure (%d pas)" % [id, v, lg])
		var n := r.notes_joueur(4)
		for i in range(1, n.size()):
			_verifier(n[i] - n[i - 1] > Rythme.FENETRE_BIEN, "%s : deux appuis ne se chevauchent pas" % id)


func _tester_catalogue() -> void:
	var cat := BanqueSons.catalogue()
	_verifier(cat.get("version", 0) == 1, "le catalogue se lit")
	for chemin in BanqueSons.tous_les_fichiers():
		_verifier(ResourceLoader.exists(chemin), "fichier présent : %s" % chemin)
	for g in cat.get("groupes", {}):
		for id in cat["groupes"][g]:
			_verifier(cat["sons"].has(id), "le groupe %s cite un son connu (%s)" % [g, id])
	for lieu in ["stade", "pub", "maison", "ecran_geant"]:
		for i in 3:
			var a := BanqueSons.ambiance_du_lieu(lieu, i)
			_verifier(cat["ambiances"].has(a.get("id", "")), "%s/%d a une ambiance" % [lieu, i])
	_verifier(BanqueSons.fiche("tambour").get("id", "").begins_with("tambour_"), "un groupe tire un de ses sons")
	_verifier(BanqueSons.fiche("inexistant").is_empty(), "un son inconnu rend une fiche vide")
	var s := BanqueSons.flux(BanqueSons.fiche_ambiance("pub")["fichier"], true)
	_verifier(s is AudioStreamOggVorbis and (s as AudioStreamOggVorbis).loop, "une ambiance boucle")
	var t := BanqueSons.flux(BanqueSons.fiche("tambour_1")["fichier"])
	_verifier(t is AudioStreamWAV and t.get_length() > 0.2, "un tambour se charge en WAV")
	for id in cat["sons"]:
		var o: String = String(cat["sons"][id].get("origine", ""))
		_verifier(o in ["synthese", "gael", "cc0"], "%s : origine connue et sans licence à suivre" % id)


func _tester_bus() -> void:
	var layout: AudioBusLayout = load("res://default_bus_layout.tres")
	_verifier(layout != null, "la disposition des bus se charge")
	AudioServer.set_bus_layout(layout)
	for b in ["Musique", "Ambiance", "Chants", "Effets", "Interface"]:
		_verifier(AudioServer.get_bus_index(b) > 0, "le bus %s existe" % b)
		_verifier(BanqueSons.bus(b) == StringName(b), "BanqueSons trouve le bus %s" % b)
	_verifier(BanqueSons.bus("Absent") == &"Master", "un bus absent retombe sur Master")
