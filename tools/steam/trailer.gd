extends "res://tools/steam/vitrine.gd"
## Plans du trailer Steam, filmés dans le vrai jeu avec le Movie Maker de Godot.
## Un plan par lancement :
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##       --write-movie plan.avi --fixed-fps 30 res://tools/steam/trailer.tscn \
##       -- --hors-ligne --auto --plan=duel
##
## Le pilote écrit « DEBUT_PLAN <image> » au début du plan (à couper au montage)
## puis quitte tout seul. Montage : tools/steam/monter_trailer.sh.

const PLANS := ["titre", "carte", "voyage", "tribune", "duel", "arene", "poussee", "buvette", "club", "album", "carnet"]


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteTrailer"
		get_tree().root.add_child.call_deferred(pilote)
		return
	var plan := "duel"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plan="):
			plan = a.trim_prefix("--plan=")
	await _attendre(0.3)
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var tuto := FileAccess.get_file_as_string(Tutoriel.CHEMIN)
	_preparer_partie()
	await call("_plan_" + plan)
	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	_restaurer(Tutoriel.CHEMIN, tuto)
	get_tree().quit()


func _debut() -> void:
	await RenderingServer.frame_post_draw
	print("DEBUT_PLAN %d" % Engine.get_frames_drawn())


func _id(vitrine: String, exemple: String) -> String:
	return vitrine if not Donnees.match_par_id(vitrine).is_empty() else exemple


func _params_duel() -> Dictionary:
	return {"match_id": _id("vit:madrid", "ex:2"), "camp": "home", "mode": "stade", "cout": 0, "auto": true}


# ------------------------------------------------------------------ plans

func _plan_titre() -> void:
	Game.aller(Game.SCENE_TITRE)
	await _debut()
	await _attendre(5.0)


## Monde → Europe → France → le match en direct.
func _plan_carte() -> void:
	Game.aller(Game.SCENE_CARTE, {"niveau": "monde"})
	await _debut()
	await _attendre(2.2)
	var carte := get_tree().current_scene
	carte._aller_continent("Europe")
	await _attendre(2.2)
	carte._aller_pays("france")
	await _attendre(2.0)
	carte._choisir_match(_id("vit:classique", "ex:1"))
	await _attendre(3.0)


func _plan_voyage() -> void:
	Game.aller(Game.SCENE_VOYAGE, {"match_id": _id("vit:milan", "ex:4"), "camp": "home", "mode": "stade", "cout": 0})
	await _debut()
	await _attendre(6.0)


func _plan_tribune() -> void:
	Game.aller(Game.SCENE_TRIBUNE, _params_duel())
	await _debut()
	await _attendre(3.0)


func _plan_duel() -> void:
	Game.aller(Game.SCENE_DUEL, _params_duel())
	await _debut()
	await _attendre(30.0)
	var duel := get_tree().current_scene
	duel._but(true)
	await _attendre(8.0)


func _plan_arene() -> void:
	Game.aller(Game.SCENE_ARENE, _params_duel())
	await _debut()
	await _attendre(34.0)


func _plan_poussee() -> void:
	Game.aller(Game.SCENE_POUSSEE, _params_duel())
	await _debut()
	await _attendre(60.0)


func _plan_buvette() -> void:
	Game.aller(Game.SCENE_BUVETTE)
	await _debut()
	await _attendre(16.0)


func _plan_club() -> void:
	Game.aller(Game.SCENE_CLUB)
	await _debut()
	await _attendre(3.0)


func _plan_album() -> void:
	Game.aller(Game.SCENE_COLLECTION, {"onglet": "album"})
	await _debut()
	await _attendre(3.0)


func _plan_carnet() -> void:
	Game.aller(Game.SCENE_COLLECTION, {"onglet": "carnet"})
	await _debut()
	await _attendre(3.0)
