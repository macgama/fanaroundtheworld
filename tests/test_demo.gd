extends Node
## La version démo dans le vrai jeu (autoloads chargés) :
##   godot --headless --path . res://tests/test_demo.tscn -- --hors-ligne
## Vérifie : sauvegarde à part, écrans fermés (fenêtre « dans le jeu complet »
## au lieu de changer d'écran), continents fermés sur la carte, petits boulots
## ouverts ou non, XP arrêtée au niveau de fin et écran de fin de démo, et que
## le jeu complet n'est pas touché. La sauvegarde du joueur est remise en place.

var _echecs := 0
var _verifs := 0


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteDemo"
		get_tree().root.add_child.call_deferred(pilote)
		return
	await _attendre(0.3)
	var etait_demo := Demo.actif()
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)

	# --- jeu complet : rien de fermé
	Demo.forcer(false)
	_verifier(Demo.fichier("user://sauvegarde.json") == "user://sauvegarde.json", "jeu complet : sauvegarde normale")
	_verifier(Demo.ecran_ferme(Game.SCENE_PASS) == "", "jeu complet : PASS ouvert")
	_verifier(Demo.continent_ouvert("Asia"), "jeu complet : Asie ouverte")
	_verifier(Demo.boulot_ouvert("tifo"), "jeu complet : tifo ouvert")
	_verifier(Demo.xp_limitee(99999) == 99999, "jeu complet : XP sans limite")

	# --- démo
	Demo.forcer(true)
	_verifier(Demo.fichier("user://sauvegarde.json") == "user://demo_sauvegarde.json", "démo : sauvegarde à part")
	for scene in Demo.ECRANS_FERMES:
		_verifier(ResourceLoader.exists(scene), "écran fermé qui existe : " + scene)
	for id in Demo.BOULOTS_OUVERTS:
		_verifier(not ListeBoulots.par_id(id).is_empty(), "petit boulot ouvert qui existe : " + id)
	_verifier(Demo.ecran_ferme(Game.SCENE_DUEL) == "", "démo : duel ouvert")
	_verifier(Demo.ecran_ferme(Game.SCENE_ARENE) == "" and Demo.ecran_ferme(Game.SCENE_POUSSEE) == "", "démo : Arène et Poussée ouvertes")
	_verifier(Demo.ecran_ferme(Game.SCENE_BUVETTE) == "" and Demo.ecran_ferme(Game.SCENE_SPEAKER) == "", "démo : buvette et speaker ouverts")
	_verifier(Demo.ecran_ferme(Game.SCENE_PASS) != "", "démo : PASS fermé")
	_verifier(Demo.continent_ouvert("Europe") and not Demo.continent_ouvert("Asia"), "démo : Europe seulement")
	_verifier(Demo.url_magasin().begins_with("https://store.steampowered.com/"), "lien Steam")

	# Un écran fermé : on reste où on est, une fenêtre s'ouvre.
	Game.aller(Game.SCENE_CARTE)
	await _attendre(0.8)
	Game.aller(Game.SCENE_PASS)
	await _attendre(0.4)
	_verifier(get_tree().current_scene.scene_file_path == Game.SCENE_CARTE, "PASS fermé : on reste sur la carte")
	_verifier(_fenetres() == 1, "fenêtre « dans le jeu complet » ouverte")
	# Elle part quand on change d'écran.
	Game.aller(Game.SCENE_CARTE, {"niveau": "monde"})
	await _attendre(0.8)
	_verifier(_fenetres() == 0, "fenêtre fermée au changement d'écran")
	# Continent fermé sur la carte.
	var carte := get_tree().current_scene
	carte._aller_continent("Asia")
	await _attendre(0.2)
	_verifier(carte.niveau == "monde" and _fenetres() == 1, "Asie fermée : fenêtre, la carte ne bouge pas")
	_fermer_fenetres()
	carte._aller_continent("Europe")
	_verifier(carte.niveau == "continent", "Europe ouverte")

	# Petits boulots : boutons « Y aller » seulement pour ceux de la démo.
	Game.aller(Game.SCENE_BOULOTS)
	await _attendre(0.6)
	var ouverts := 0
	var fermes := 0
	for b in get_tree().current_scene.find_children("*", "Button", true, false):
		if (b as Button).text == "Y aller":
			ouverts += 1
		elif (b as Button).text == "Dans le jeu complet":
			fermes += 1
	_verifier(ouverts == Demo.BOULOTS_OUVERTS.size(), "boulots ouverts : %d" % ouverts)
	_verifier(fermes == ListeBoulots.LISTE.size() - Demo.BOULOTS_OUVERTS.size(), "boulots fermés : %d" % fermes)

	# XP arrêtée au niveau de fin, puis l'écran de fin de démo sur la carte (une fois).
	Game.reinitialiser()
	_verifier(Game.CHEMIN_SAUVEGARDE == "user://sauvegarde.json" or etait_demo, "Game garde le chemin choisi au lancement")
	Game.ajouter_xp(50000)
	_verifier(Game.xp == Demo.xp_max() and Game.niveau() == Demo.NIVEAU_MAX, "XP limitée au niveau %d" % Demo.NIVEAU_MAX)
	_verifier(Game.fin_demo_a_montrer(), "fin de démo à montrer")
	Game.aller(Game.SCENE_CARTE)
	await _attendre(0.8)
	_verifier(_fenetres() == 1, "écran de fin de démo sur la carte")
	_verifier(not Game.fin_demo_a_montrer(), "fin de démo montrée une seule fois")
	_fermer_fenetres()

	# Accueil : bouton liste de souhaits.
	Game.aller(Game.SCENE_TITRE)
	await _attendre(0.8)
	var souhaits := get_tree().current_scene.find_children("*", "Button", true, false).filter(
		func(b): return (b as Button).text == "Ajouter à ma liste de souhaits")
	_verifier(souhaits.size() == 1, "accueil : bouton liste de souhaits")

	Demo.forcer(etait_demo)
	Game.reinitialiser()
	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	print("Tests démo : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	get_tree().quit(1 if _echecs else 0)


func _fenetres() -> int:
	return get_tree().root.get_children().filter(func(n): return n.name.begins_with("FenetreDemo") and not n.is_queued_for_deletion()).size()


func _fermer_fenetres() -> void:
	for n in get_tree().root.get_children():
		if n.name.begins_with("FenetreDemo"):
			n.queue_free()


func _restaurer(chemin: String, texte: String) -> void:
	if texte == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
		return
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(texte)


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout
