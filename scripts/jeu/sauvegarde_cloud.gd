class_name SauvegardeCloud
extends RefCounted
## Choix entre la sauvegarde de ce PC (user://) et celle de Steam Cloud, sans
## écran (testable). Game.charger() s'en sert ; Plateforme fait les accès Steam.


## La plus récente des deux sauvegardes (champ « sauve_le », date unix), ou
## celle qui existe. À égalité, celle de ce PC. Une sauvegarde illisible ne compte pas.
static func choisir(locale: Variant, cloud: Variant) -> Variant:
	if not cloud is Dictionary:
		return locale if locale is Dictionary else null
	if not locale is Dictionary:
		return cloud
	return cloud if int(cloud.get("sauve_le", 0)) > int(locale.get("sauve_le", 0)) else locale
