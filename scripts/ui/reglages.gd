class_name Reglages
extends RefCounted
## Options du joueur (volumes, plein écran, niveau de l'adversaire ordi), gardées dans user://options.cfg,
## à part de la sauvegarde de la partie.

const CHEMIN := "user://options.cfg"

static var _base_db := {}  # volume de chaque bus dans le mixage d'origine

## curseur affiché -> bus audio réglés ensemble
const VOLUMES := [
	["general", "Volume général", ["Master"]],
	["musique", "Musique", ["Musique"]],  # sans_traduction
	["ambiance", "Ambiance et chants", ["Ambiance", "Chants"]],
	["effets", "Effets", ["Effets", "Interface"]],
]


static func _fichier() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(CHEMIN)
	return c


static func volume(cle: String) -> float:
	return float(_fichier().get_value("son", cle, 1.0))


static func plein_ecran() -> bool:
	return bool(_fichier().get_value("ecran", "plein_ecran", false))


## Niveau de l'adversaire ordi (Arène, Poussée) : voir IaNiveau.
static func difficulte() -> String:
	return IaNiveau.valide(str(_fichier().get_value("jeu", "difficulte", IaNiveau.PAR_DEFAUT)))


static func regler_difficulte(n: String) -> void:
	var c := _fichier()
	c.set_value("jeu", "difficulte", IaNiveau.valide(n))
	c.save(CHEMIN)


## Cortège : petite marche en rythme entre les arrêts (activée par défaut).
static func marche_rythme() -> bool:
	return bool(_fichier().get_value("jeu", "marche_rythme", true))


static func regler_marche_rythme(oui: bool) -> void:
	var c := _fichier()
	c.set_value("jeu", "marche_rythme", oui)
	c.save(CHEMIN)


static func regler_volume(cle: String, v: float) -> void:
	var c := _fichier()
	c.set_value("son", cle, clampf(v, 0.0, 1.0))
	c.save(CHEMIN)
	_appliquer_volume(cle, v)


static func regler_plein_ecran(oui: bool) -> void:
	var c := _fichier()
	c.set_value("ecran", "plein_ecran", oui)
	c.save(CHEMIN)
	_appliquer_ecran(oui)


static func appliquer() -> void:
	## Au lancement du jeu.
	for v in VOLUMES:
		_appliquer_volume(v[0], volume(v[0]))
	if plein_ecran():
		_appliquer_ecran(true)


static func _appliquer_volume(cle: String, v: float) -> void:
	for ligne in VOLUMES:
		if ligne[0] != cle:
			continue
		for bus in ligne[2]:
			var i := AudioServer.get_bus_index(bus)
			if i < 0:
				continue
			if not _base_db.has(bus):
				_base_db[bus] = AudioServer.get_bus_volume_db(i)
			# au carré : un curseur à mi-course sonne vraiment à mi-volume ;
			# le mixage d'origine (musique un peu plus basse…) est gardé
			AudioServer.set_bus_mute(i, v <= 0.001)
			AudioServer.set_bus_volume_db(i, float(_base_db[bus]) + linear_to_db(maxf(v * v, 0.0001)))


static func _appliquer_ecran(oui: bool) -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if oui else DisplayServer.WINDOW_MODE_WINDOWED)
