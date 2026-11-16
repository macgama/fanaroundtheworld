extends SceneTree
## Tests sans écran : godot --headless --path . --script tests/test_langues.gd
## Vérifie les traductions (data/langues/<code>/*.json) :
##  - chaque texte affichable du code (chaîne entre guillemets qui ressemble à
##    du texte) a une entrée dans chaque langue ; une valeur "" garde le texte
##    tel quel (noms propres…) ;
##  - les %d / %s / %.1f… sont les mêmes, dans le même ordre ;
##  - le changement de langue traduit bien tr() et les Label.
## Une ligne de code qui ne contient que des identifiants ou des noms propres
## peut porter le commentaire « # sans_traduction » pour être ignorée.
## « -- --manquants » écrit les textes manquants au format JSON, prêts à
## coller dans un fichier de data/langues/en/.

const IGNORES := ["res://tests", "res://tools", "res://addons", "res://.godot"]

var _echecs := 0
var _re_chaine := RegEx.create_from_string("\"((?:[^\"\\\\\\n]|\\\\.)*)\"")
var _re_ident := RegEx.create_from_string("^[a-z0-9_:./%-]+$")
var _re_couleur := RegEx.create_from_string("^#?[0-9a-fA-F]{6,8}$")
var _re_lettres := RegEx.create_from_string("[A-Za-zÀ-ÿ]{2}")
var _re_format := RegEx.create_from_string("%[-+0-9.]*[dsfxX%]")


func _init() -> void:
	await process_frame
	var Langue: Node = root.get_node("/root/Langue")
	var textes := {}  # texte -> "fichier:ligne"
	_parcourir("res://", textes)
	_verifier(textes.size() > 500, "textes du jeu trouvés (%d)" % textes.size())
	var manquants_json := OS.get_cmdline_user_args().has("--manquants")
	for code in Langue.disponibles():
		if code == Langue.SOURCE:
			continue
		var paires: Dictionary = Langue.paires(code)
		var manquants := []
		for t in textes:
			if not paires.has(t):
				manquants.append(t)
		if manquants_json and not manquants.is_empty():
			var d := {}
			for t in manquants:
				d[t] = ""
			print(JSON.stringify(d, "\t"))
		for t in manquants.slice(0, 40):
			printerr("  [%s] sans traduction : %s  (%s)" % [code, JSON.stringify(t), textes[t]])
		_verifier(manquants.is_empty(), "[%s] %d texte(s) sans traduction (ajoute-les dans data/langues/%s/<écran>.json)" % [code, manquants.size(), code])
		for k in paires:
			if paires[k] != "" and _bords(k) != _bords(paires[k]):
				_verifier(false, "[%s] espaces au début ou à la fin différents : %s -> %s" % [code, JSON.stringify(k), JSON.stringify(paires[k])])
			if paires[k] != "" and _formats(k) != _formats(paires[k]):
				_verifier(false, "[%s] formats différents : %s -> %s" % [code, JSON.stringify(k), JSON.stringify(paires[k])])
	# la traduction s'applique bien
	if "en" in Langue.disponibles():
		Langue.essayer("en")
		_verifier(TranslationServer.translate("Retour à la carte") == "Back to the map", "tr() en anglais")
		var l := Label.new()
		l.text = "Fermer"
		root.add_child(l)
		await process_frame
		_verifier(l.text == "Fermer", "le texte du Label reste la clé française")
		_verifier(load("res://scripts/donnees/geo.gd").nom_pays("south korea") == "South Korea", "pays en anglais")
		_verifier(load("res://scripts/donnees/fiche_match.gd").date_texte(0).begins_with("Thu"), "jours en anglais")
		Langue.essayer("fr")
		_verifier(TranslationServer.translate("Retour à la carte") == "Retour à la carte", "retour au français")
		_verifier(load("res://scripts/donnees/fiche_match.gd").date_texte(0).begins_with("Jeu"), "jours en français")
		l.queue_free()
	print("Tests langues : %s" % ("OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs))
	quit(1 if _echecs > 0 else 0)


func _bords(t: String) -> Array:
	return [t.length() - t.lstrip(" ").length(), t.length() - t.rstrip(" ").length()]


func _formats(t: String) -> Array:
	var r := []
	for m in _re_format.search_all(t):
		r.append(m.get_string())
	return r


func _parcourir(dossier: String, textes: Dictionary) -> void:
	for i in IGNORES:
		if dossier.trim_suffix("/") == i:
			return
	for d in DirAccess.get_directories_at(dossier):
		_parcourir(dossier.path_join(d), textes)
	for f in DirAccess.get_files_at(dossier):
		if f.ends_with(".gd") and not f.begins_with("demo_"):
			_lire(dossier.path_join(f), textes)


static func _decoder(t: String) -> String:
	return t.replace("\\n", "\n").replace("\\t", "\t").replace("\\\"", "\"").replace("\\\\", "\\")


func _ressemble_a_du_texte(t: String) -> bool:
	if _re_lettres.search(t) == null:
		return false
	if t.begins_with("res://") or t.begins_with("user://") or t.begins_with("http"):
		return false
	return _re_ident.search(t) == null and _re_couleur.search(t) == null


func _lire(chemin: String, textes: Dictionary) -> void:
	var lignes := FileAccess.get_file_as_string(chemin).split("\n")
	for n in lignes.size():
		var ligne := lignes[n]
		if ligne.contains("sans_traduction") or ligne.strip_edges().begins_with("#") or ligne.contains("\"\"\""):
			continue
		# on coupe le commentaire de fin de ligne (un # hors guillemets)
		var dans := false
		var fin := ligne.length()
		var i := 0
		while i < ligne.length():
			var c := ligne[i]
			if c == "\\" and dans:
				i += 2
				continue
			if c == "\"":
				dans = not dans
			elif c == "#" and not dans:
				fin = i
				break
			i += 1
		var code := ligne.substr(0, fin)
		for m in _re_chaine.search_all(code):
			var debut := m.get_start()
			if debut > 0 and code[debut - 1] in ["&", "^"]:
				continue
			var t := _decoder(m.get_string(1))
			if _ressemble_a_du_texte(t) and not textes.has(t):
				textes[t] = "%s:%d" % [chemin.trim_prefix("res://"), n + 1]


func _verifier(cond: bool, msg: String) -> void:
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)
