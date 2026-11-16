extends Node
## Langue du jeu. Le français est la langue source : chaque texte du code est
## écrit en français et sert de clé. Les traductions sont des fichiers JSON
## { "texte français": "traduction" } rangés par langue :
##   res://data/langues/<code>/*.json   (ex. data/langues/en/carte.json)
## Tous les fichiers d'un dossier sont fusionnés, donc chaque écran peut avoir
## le sien : un nouvel écran ajoute simplement son fichier, sans toucher aux
## autres. Les Label, Button, infobulles… dont le texte est exactement une clé
## sont traduits tout seuls par Godot ; un texte construit (avec % ou +) passe
## par tr("…") dans le code (ou Trad.t("…") dans une fonction static).
## tests/test_langues.gd vérifie qu'aucun texte n'a été oublié.

const DOSSIER := "res://data/langues"
const SOURCE := "fr"
## nom affiché dans le choix de langue (dans sa propre langue)
const NOMS := {"fr": "Français", "en": "English", "es": "Español", "de": "Deutsch",  # sans_traduction
	"it": "Italiano", "pt": "Português", "nl": "Nederlands"}  # sans_traduction

var _traductions := {}  # code -> Translation


func _ready() -> void:
	for code in disponibles():
		if code != SOURCE:
			_charger(code)
	TranslationServer.set_locale(_au_lancement())


## « -- --langue=en » force une langue sans la sauvegarder ; les tests
## (res://tests/…) restent en français sauf demande contraire.
func _au_lancement() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--langue="):  # sans_traduction
			return a.trim_prefix("--langue=")  # sans_traduction
	for a in OS.get_cmdline_args():
		if a.begins_with("res://tests/") or a.begins_with("tests/"):
			return SOURCE
	return actuelle()


## Codes des langues proposées, la langue source en premier.
func disponibles() -> Array:
	var l := [SOURCE]
	for d in DirAccess.get_directories_at(DOSSIER):
		if d != SOURCE and not d.begins_with("_"):
			l.append(d)
	return l


func nom(code: String) -> String:
	return NOMS.get(code, code)


## Langue choisie dans les options ; au premier lancement, celle du système
## si on la propose, sinon l'anglais (le français pour un système francophone).
func actuelle() -> String:
	var c := ConfigFile.new()
	c.load(Reglages.CHEMIN)
	var code := str(c.get_value("jeu", "langue", ""))
	if code in disponibles():
		return code
	var sys := OS.get_locale_language()
	if sys in disponibles():
		return sys
	return "en" if "en" in disponibles() else SOURCE


func changer(code: String) -> void:
	if not code in disponibles():
		return
	var c := ConfigFile.new()
	c.load(Reglages.CHEMIN)
	c.set_value("jeu", "langue", code)
	c.save(Reglages.CHEMIN)
	essayer(code)


## Pour les tests : change la langue sans la sauvegarder.
func essayer(code: String) -> void:
	TranslationServer.set_locale(code)
	# noms de stades et de compétitions recalculés (chargé ici : FicheMatch
	# dépend d'autres autoloads)
	load("res://scripts/donnees/fiche_match.gd").oublier()


## Toutes les paires d'une langue (pour les tests et les outils).
func paires(code: String) -> Dictionary:
	var tout := {}
	var dossier := DOSSIER + "/" + code
	for f in DirAccess.get_files_at(dossier):
		if not f.ends_with(".json"):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(dossier + "/" + f))
		if d is Dictionary:
			for k in d:
				if not str(k).begins_with("_"):
					tout[str(k)] = str(d[k])
		else:
			push_error(tr("Traduction illisible : %s/%s") % [dossier, f])  # sans_traduction
	return tout


func _charger(code: String) -> void:
	var tra := Translation.new()
	tra.locale = code
	var p := paires(code)
	for k in p:
		if p[k] != "":
			tra.add_message(k, p[k])
	TranslationServer.add_translation(tra)
	_traductions[code] = tra
