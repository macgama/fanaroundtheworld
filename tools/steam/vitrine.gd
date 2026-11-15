extends Node
## Captures d'écran pour la page Steam, prises dans le vrai jeu (autoloads chargés).
##
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . --resolution 1920x1080 \
##       res://tools/steam/vitrine.tscn -- --hors-ligne --auto --sortie=/chemin/captures
##
## Option « --seule=nom » : ne prend qu'une capture (pour régler un cadrage).
## Une partie « vitrine » est préparée (fan club fondé, niveau 7, stades tamponnés,
## album entamé) ; la sauvegarde et le tutoriel du joueur sont remis en place à la fin.

const CLUB := "Ultras du Canal"

var _sortie := "user://captures_steam"
var _seule := ""


func _ready() -> void:
	# La scène est remplacée à chaque écran : le pilote vit à côté, dans la racine.
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteVitrine"
		get_tree().root.add_child.call_deferred(pilote)
		return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			_sortie = a.trim_prefix("--sortie=")
		if a.begins_with("--seule="):
			_seule = a.trim_prefix("--seule=")
	DirAccess.make_dir_recursive_absolute(_sortie)
	await _attendre(0.5)
	var sauvegarde := FileAccess.get_file_as_string(Game.CHEMIN_SAUVEGARDE)
	var tuto := FileAccess.get_file_as_string(Tutoriel.CHEMIN)
	_preparer_partie()

	for c in _captures():
		if _seule != "" and c["nom"] != _seule:
			continue
		Game.aller(c["scene"], c.get("params", {}))
		await _attendre(0.4)
		if c.has("action"):
			await c["action"].call()
		# « attente » : un délai, ou plusieurs (une image à chaque, suffixe -1, -2…)
		var attentes: Array = c["attente"] if c.get("attente") is Array else [c.get("attente", 1.5)]
		var deja := 0.0
		for i in attentes.size():
			await _attendre(float(attentes[i]) - deja)
			deja = float(attentes[i])
			await RenderingServer.frame_post_draw
			var suffixe := "" if attentes.size() == 1 else "-%d" % (i + 1)
			var chemin := "%s/%s%s.png" % [_sortie, c["nom"], suffixe]
			get_viewport().get_texture().get_image().save_png(chemin)
			print("capture : ", chemin)

	_restaurer(Game.CHEMIN_SAUVEGARDE, sauvegarde)
	_restaurer(Tutoriel.CHEMIN, tuto)
	get_tree().quit()


## Les écrans à capturer, dans l'ordre de la page Steam.
func _captures() -> Array:
	# Matchs de tools/steam/calendrier_vitrine.py (sinon, matchs d'exemple du jeu)
	var direct := "vit:madrid" if not Donnees.match_par_id("vit:madrid").is_empty() else "ex:2"
	var classique := "vit:classique" if not Donnees.match_par_id("vit:classique").is_empty() else "ex:1"
	var a_venir := "vit:milan" if not Donnees.match_par_id("vit:milan").is_empty() else "ex:4"
	var duel := {"match_id": direct, "camp": "home", "mode": "stade", "cout": 0, "auto": true}
	return [
		{"nom": "01-duel-ambiance", "scene": Game.SCENE_DUEL, "params": duel, "attente": [12.0, 18.0, 24.0, 32.0, 40.0, 50.0, 60.0]},
		{"nom": "02-carte-monde", "scene": Game.SCENE_CARTE, "params": {"niveau": "monde"}, "attente": 2.5},
		{"nom": "02b-carte-europe", "scene": Game.SCENE_CARTE, "params": {"niveau": "continent", "continent": "Europe"}, "attente": 2.5},
		{"nom": "03-carte-match", "scene": Game.SCENE_CARTE,
			"params": {"niveau": "pays", "pays": "france", "continent": "Europe", "match_id": classique}, "attente": 2.5},
		{"nom": "04-arene", "scene": Game.SCENE_ARENE, "params": duel, "attente": [15.0, 25.0, 35.0, 45.0]},
		{"nom": "05-poussee", "scene": Game.SCENE_POUSSEE, "params": duel, "attente": [25.0, 40.0, 55.0, 70.0]},
		{"nom": "06-voyage", "scene": Game.SCENE_VOYAGE,
			"params": {"match_id": a_venir, "camp": "home", "mode": "stade", "cout": 0}, "attente": [1.0, 1.6, 2.4]},
		{"nom": "07-tribune", "scene": Game.SCENE_TRIBUNE, "params": duel, "attente": 1.5},
		{"nom": "08-buvette", "scene": Game.SCENE_BUVETTE, "params": {}, "attente": [8.0, 14.0, 20.0]},
		{"nom": "09-fan-club", "scene": Game.SCENE_CLUB, "params": {}, "attente": 1.5},
		{"nom": "10-collection-carnet", "scene": Game.SCENE_COLLECTION, "params": {"onglet": "carnet"}, "attente": 1.5},
		{"nom": "11-collection-album", "scene": Game.SCENE_COLLECTION, "params": {"onglet": "album"}, "attente": 1.5},
		{"nom": "12-pronostics", "scene": Game.SCENE_PRONOS, "params": {}, "attente": 1.5},
		{"nom": "13-missions", "scene": Game.SCENE_MISSIONS, "params": {}, "attente": 1.5},
		{"nom": "14-accueil", "scene": Game.SCENE_TITRE, "params": {}, "attente": 2.5},
	]


## Une partie bien avancée, pour montrer tout ce que le jeu propose.
func _preparer_partie() -> void:
	Game.reinitialiser()
	Tutoriel.passer()
	Game.equipe = ["TR1", "TR3", "TR34"]
	Game.skins = {"TR1": "TR1B", "TR3": "TR3C", "TR34": "TR34B"}
	Game.creer_club(CLUB, FanClub.COULEURS[0], FanClub.COULEURS[2])
	Game.xp = 6 * 200 + 130  # niveau 7
	Game.jetons = 1240
	Game.xp_pass = 2600
	Game.duels_joues = 38
	Game.duels_gagnes = 27
	for id in ["AN6", "MS31", "AN5", "GD8", "TR33", "AN2", "MS30"]:
		Game.recruter(id)
	# Stades déjà visités : une quinzaine, dans plusieurs pays (pas celui du voyage)
	var pays_vus := {}
	for m in Donnees.matchs():
		if str(m["id"]) in ["ex:4", "vit:milan"] or Game.tampons.size() >= 16:
			continue
		var f := FicheMatch.de(m)
		var p := str(f["lieu"]["pays"])
		if int(pays_vus.get(p, 0)) >= (3 if p == "france" else 1):
			continue
		pays_vus[p] = int(pays_vus.get(p, 0)) + 1
		Game.tampons[f["stade"]["cle"]] = {
			"nom": f["stade"]["nom"], "club": f["dom"]["nom"], "date": "2026-11-0%d" % (1 + Game.tampons.size() % 9),
			"match": "%s – %s" % [f["dom"]["nom"], f["ext"]["nom"]],
			"pays": f["lieu"]["pays"], "continent": f["lieu"]["continent"],
			"competition": str(m.get("competition", {}).get("id", "")),
		}
	# Album : la plupart des FANZZY déjà vus en duel, avec quelques skins
	var ids: Array = []
	var skins_vus: Array = []
	for i in Game.fanzzy.size():
		var z: Dictionary = Game.fanzzy[i]
		if i % 6 == 5:
			continue
		ids.append(z["id"])
		var sk: Array = z.get("skins", [])
		for j in mini(sk.size(), 1 + i % 3):
			skins_vus.append(sk[j]["id"])
	Collection.noter_duel(Game.collection, ids, skins_vus, "2026-11-10")
	# Équipes favorites
	Game.choisir_club_favori("france", "af:85")
	Game.choisir_club_favori("spain", "af:541")
	Game.choisir_nation_favorite("france")
	# Quelques pronostics en attente
	var n := 0
	for m in Donnees.matchs():
		if n < 6 and Game.peut_pronostiquer(m) == "":
			Game.pronostiquer(m, 1 + n % 3, n % 2, "home" if n % 3 else "away")
			n += 1
	Game.position_club = {"nom": "Paris", "lat": 48.86, "lon": 2.35}
	Game.sauver()
	# Calendrier vitrine en cache : afficher ce que voit un joueur connecté.
	if Donnees.source == "cache":
		Donnees.source = "en ligne"
		Donnees.hors_ligne = false


func _attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _restaurer(chemin: String, contenu: String) -> void:
	if contenu == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(chemin))
		return
	var f := FileAccess.open(chemin, FileAccess.WRITE)
	f.store_string(contenu)
