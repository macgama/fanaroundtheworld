class_name Trad
extends RefCounted
## Raccourcis de traduction utilisables partout, même dans une fonction static
## ou un script lancé avant les autoloads (tests --script). Le chargement des
## langues et le choix dans les options sont dans l'autoload Langue.

## tr() pour une fonction static : Trad.t("Texte %d") % n
static func t(texte: String) -> String:
	return String(TranslationServer.translate(texte))


## Vrai quand le jeu est en français (la langue des textes du code), ou
## tant qu'aucune traduction n'est chargée pour la langue en cours.
static func est_source() -> bool:
	var loc := TranslationServer.get_locale()
	return loc.begins_with("fr") or TranslationServer.get_translation_object(loc) == null


## Nombre à virgule dans la langue du jeu : « 1,5 » en français, « 1.5 » en anglais.
static func decimal(x: Variant) -> String:
	var s := str(x)
	return s.replace(".", ",") if est_source() else s
