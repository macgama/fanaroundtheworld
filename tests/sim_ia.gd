extends Node
## Matchs simulés entre ordis, pour régler les niveaux de l'adversaire (IaNiveau) :
##   godot --headless --path . --fixed-fps 30 res://tests/sim_ia.tscn -- --hors-ligne \
##     --jeu=poussee --n=20 --a=difficile --b=normal
## --a : ton camp (équipe de gauche), --b : l'adversaire. --fixed-fps : le temps du jeu
## avance image par image, aussi vite que la machine le permet.
## Affiche le bilan (victoires de A / nuls / victoires de B) et comment les matchs finissent.

var _args := {}


func _ready() -> void:
	if get_tree().current_scene == self:
		var pilote: Node = load(get_script().resource_path).new()
		pilote.name = "PiloteSimIa"
		get_tree().root.add_child.call_deferred(pilote)
		return
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() > 1 else ""
	var jeu := str(_args.get("jeu", "poussee"))
	var n := int(_args.get("n", "10"))
	var a := str(_args.get("a", "normal"))
	var b := str(_args.get("b", "normal"))
	var bilan := {1: 0, 0: 0, -1: 0}
	var raisons := {}
	var duree := 0.0
	var ecarts := 0.0
	for k in n:
		Game.aller(Game.SCENE_POUSSEE if jeu == "poussee" else Game.SCENE_ARENE,
			{"match_id": "ex:1", "camp": "home" if k % 2 == 0 else "away", "mode": "pub", "cout": 0, "auto": true, "ia": [a, b]})
		await get_tree().process_frame
		await get_tree().process_frame
		var sc := get_tree().current_scene
		if sc == null or not "termine" in sc:
			printerr("SIM ÉCHEC : la scène du jeu ne s'est pas chargée")
			get_tree().quit(1)
			return
		while not sc.termine:
			await get_tree().process_frame
		var res := 0
		var r := ""
		if jeu == "poussee":
			res = sc.vainqueur
			r = {"BUUUUT !": "but", "TRIBUNE CONQUISE !": "tribune", "ILS ONT CONQUIS TA TRIBUNE…": "tribune"}.get(sc.raison, "temps")
			ecarts += (sc.tribune[0] - sc.tribune[1])
		else:
			res = AreneRegles.resultat(sc.banderole[0], sc.banderole[1], sc.touches[0], sc.touches[1])
			r = "banderole" if maxf(sc.banderole[0], sc.banderole[1]) >= AreneRegles.BANDEROLE_MAX else "temps"
			ecarts += sc.banderole[0] - sc.banderole[1]
		duree += sc.temps
		bilan[res] += 1
		raisons[r] = int(raisons.get(r, 0)) + 1
	print("SIM %s  A=%s contre B=%s  (%d matchs) : A gagne %d · nuls %d · B gagne %d · fins %s · durée moy. %.0f s · écart moy. %+.0f" % [
		jeu, a, b, n, bilan[1], bilan[0], bilan[-1], str(raisons), duree / maxf(n, 1), ecarts / maxf(n, 1)])
	get_tree().quit()
