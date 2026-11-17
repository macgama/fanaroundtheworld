extends Node
## Banc d'essai de l'équilibrage des cartes de la Poussée (sans affichage) :
##   godot --headless --path . res://tools/equilibrage/simuler_poussee.tscn -- --hors-ligne [--parties=N] [--duels=N]
## 1. Duels de cartes à coût égal : un groupe de cartes A contre un groupe de
##    cartes B pour le même budget de Ferveur (12), sans ballon ni IA.
##    On compte qui reste debout (en Ferveur encore sur le terrain).
## 2. Parties complètes IA contre IA : jeu entier contre jeu privé d'une carte.
##    Si retirer une carte fait gagner plus souvent, elle était trop faible.
## Les chiffres sont écrits dans docs/equilibrage.md (à la main).

const PAS := 1.0 / 30.0
const SCENE := "res://scenes/poussee/poussee.tscn"

var _parties := 60
var _duels := 6


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--parties="):
			_parties = int(a.trim_prefix("--parties="))
		if a.begins_with("--duels="):
			_duels = int(a.trim_prefix("--duels="))
	Game.xp = 99 * 200  # toutes les cartes ouvertes
	await get_tree().process_frame
	if _duels > 0:
		await _duels_de_cartes()
	if _parties > 0:
		await _parties_completes()
	get_tree().quit(0)


func _scene() -> Node:
	Game.params = {"match_id": "ex:1", "camp": "home", "mode": "pub", "cout": 0}  # sans_traduction
	var sc: Node = load(SCENE).instantiate()
	add_child(sc)
	sc.set_process(false)
	sc.set_process_unhandled_input(false)
	return sc


func _valeur_restante(sc: Node, e: int) -> float:
	var v := 0.0
	for u in sc.unites:
		if u.actif and u.equipe == e:
			var c: Dictionary = u.carte
			v += float(c["cout"]) / float(c["nb"]) * maxf(u.pv, 0.0) / float(c["pv"])
	return v


func _duels_de_cartes() -> void:
	var unites := ["tambour", "drapeau", "serpentins", "chorale", "canon"]
	var budgets := [12.0, 15.0, 18.0, 20.0]
	print("\n== Duels à coût égal (budgets %s de Ferveur) : %% de la Ferveur posée encore debout, A / B ==" % str(budgets))
	var score := {}
	for k in unites:
		score[k] = 0.0
	for a in unites:
		var ligne := "%-11s" % a
		for b in unites:
			var ra := 0.0
			var rb := 0.0
			for essai in _duels:
				var sc := _scene()
				sc.ballon["pos"] = Vector2(-99999, -99999)
				var cy: float = sc.TERRAIN.get_center().y
				var cx: float = sc.TERRAIN.get_center().x
				var ea := essai % 2  # A joue à gauche puis à droite : pas d'avantage de camp
				var budget: float = budgets[(essai / 2) % budgets.size()]
				var pose := [0.0, 0.0]
				for e in 2:
					var cle: String = a if e == ea else b
					var c: Dictionary = PousseeRegles.CARTES[cle]
					var n := maxi(1, int(round(budget / float(c["cout"]))))
					pose[e] = n * float(c["cout"])
					for i in n:
						var y := cy + (i - (n - 1) / 2.0) * 70.0 + randf_range(-5, 5)
						var x := cx + (-1.0 if e == 0 else 1.0) * (180.0 + (60.0 if c["type"] == "batiment" else 0.0))
						sc.piles[e] = [cle, cle, cle, cle, cle]
						sc.ferveur[e] = 99.0
						sc.poser(e, 0, Vector2(x, y))
				sc.temps = 1.0
				for t in 600:  # 20 s (le canon dure 30 s)
					for u in sc.unites.duplicate():
						if is_instance_valid(u) and u.actif:
							sc._unite(u, PAS)
					sc._separer()
				ra += _valeur_restante(sc, ea) / pose[ea]
				rb += _valeur_restante(sc, 1 - ea) / pose[1 - ea]
				sc.free()
				await get_tree().process_frame
			ra = 100.0 * ra / _duels
			rb = 100.0 * rb / _duels
			score[a] += ra - rb
			ligne += "  %-9s" % ("%d/%d" % [int(ra), int(rb)])
		print(ligne)
	print("Bilan (moyenne de l'écart contre chaque carte, en points de %) :")
	for k in unites:
		print("  %-11s %+.0f" % [k, score[k] / unites.size()])


func _partie(cartes_0: Array, cartes_1: Array, graine: int) -> int:
	var sc := _scene()
	sc._auto = true
	sc._rng.seed = graine
	sc.piles[0] = PousseeRegles.nouvelle_pile(cartes_0, sc._rng)
	sc.piles[1] = PousseeRegles.nouvelle_pile(cartes_1, sc._rng)
	sc.en_cours = true
	var n := 0
	while not sc.termine and n < int(PousseeRegles.DUREE / PAS) + 10:
		sc._process(PAS)
		n += 1
	var res: int = sc.vainqueur
	sc.free()
	await get_tree().process_frame  # vide la file des appels différés entre deux parties
	return res


func _parties_completes() -> void:
	var tout: Array = PousseeRegles.ORDRE.duplicate()
	print("\n== Parties IA contre IA (%d par ligne) : jeu sans la carte (gauche) contre jeu complet ==" % _parties)
	var temoin: Array = await _serie(tout, tout)
	print("  %-11s V %3d %%  N %3d %%  D %3d %%" % ["(témoin)", temoin[0], temoin[1], temoin[2]])
	for k in tout:
		var sans := tout.filter(func(c): return c != k)
		var r: Array = await _serie(sans, tout)
		print("  sans %-6s V %3d %%  N %3d %%  D %3d %%" % [k, r[0], r[1], r[2]])


func _serie(a: Array, b: Array) -> Array:
	var v := 0
	var nul := 0
	var d := 0
	for i in _parties:
		var r: int = await _partie(a, b, 1000 + i)
		if r > 0:
			v += 1
		elif r < 0:
			d += 1
		else:
			nul += 1
	return [100 * v / _parties, 100 * nul / _parties, 100 * d / _parties]
