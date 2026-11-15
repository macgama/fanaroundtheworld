extends Node
## Test du parcours complet dans le jeu (autoloads Game et Donnees chargés) :
## godot --headless --path . res://tests/test_pronostics_jeu.tscn -- --hors-ligne
## Pronostic sur un match à venir, direct observé, fin du match, Jetons crédités.
## La sauvegarde du joueur est remise en état à la fin.

var _echecs := 0


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _ready() -> void:
	await get_tree().process_frame  # laisse Game brancher la résolution
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var cache_live := FileAccess.get_file_as_string(Donnees.DOSSIER_CACHE + "live.json")
	Game.reinitialiser()
	# Match fictif dans 2 h (indépendant du cache et du réseau).
	var t := int(Time.get_unix_time_from_system()) + 7200
	var m := {
		"id": "test:1", "status": "SCHEDULED", "competition": {"id": "fr.1"},
		"kickoff_utc": Time.get_datetime_string_from_unix_time(t) + ".000Z",
		"home": {"id": "af:85"}, "away": {"id": "af:81"}, "score": {"current": null},
	}
	_verifier(Game.peut_pronostiquer(m) == "", "match à venir ouvert aux pronos")
	var avant := Game.jetons
	_verifier(Game.pronostiquer(m, 2, 1, "away"), "prono enregistré")
	_verifier(Game.jetons == avant, "pronostiquer ne coûte aucun Jeton")
	var resolus: Array = []
	Game.pronostics_resolus.connect(func(l): resolus.append_array(l))

	var vivant := m.duplicate(true)
	vivant["status"] = "LIVE"
	for sc in [[0, 0], [0, 1], [2, 1]]:
		vivant["score"] = {"current": {"home": sc[0], "away": sc[1]}}
		Donnees.injecter_live({"matches": [vivant.duplicate(true)]})
	_verifier(Game.pronos.has("test:1"), "pas résolu pendant le match")
	_verifier(Game.peut_pronostiquer(vivant) != "", "prono fermé pendant le match")
	var fin := vivant.duplicate(true)
	fin["status"] = "FINISHED"
	Donnees.injecter_live({"matches": [fin]})
	_verifier(resolus.size() == 1, "un prono résolu (%d)" % resolus.size())
	var attendu := Pronostics.RECOMPENSE_RESULTAT + Pronostics.RECOMPENSE_SCORE + Pronostics.RECOMPENSE_PREMIER_BUT
	_verifier(Game.jetons == avant + attendu, "Jetons crédités : %d au lieu de %d" % [Game.jetons - avant, attendu])
	_verifier(Game.serie_pronos == 1 and Game.pronos.is_empty() and Game.pronos_finis.size() == 1, "série et historique")
	Donnees.injecter_live({"matches": [fin]})
	_verifier(Game.jetons == avant + attendu, "jamais crédité deux fois")

	# Remet la sauvegarde du joueur et le cache du direct tels qu'ils étaient.
	_restaurer(Donnees.DOSSIER_CACHE + "live.json", cache_live)
	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	print("Tests pronostics (jeu) : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	get_tree().quit(1 if _echecs > 0 else 0)


func _restaurer(chemin: String, contenu: String) -> void:
	if contenu != "":
		var f := FileAccess.open(chemin, FileAccess.WRITE)
		f.store_string(contenu)
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
