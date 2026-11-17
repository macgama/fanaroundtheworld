class_name IaPoussee
extends RefCounted
## Adversaire ordi « malin » de la Poussée (niveaux normal et difficile ;
## le niveau facile garde l'ancienne IA, dans scenes/poussee/poussee.gd).
## À chaque réflexion, chaque carte jouable reçoit une note pour le meilleur
## rôle qu'elle peut tenir maintenant :
##   pousser   : un pousseur derrière le ballon quand il menace notre but, ou
##               pour l'accompagner chez eux quand on pousse plus fort ;
##   défendre  : la bonne réponse aux supporters entrés chez nous (canon ou
##               chorale contre la mascotte, fumigène sur un groupe…) ;
##   attaquer  : une vague (gros supporter devant, chanteurs derrière, Ola sur
##               le groupe), en gardant sa Ferveur tant que rien ne presse.
## La meilleure note est jouée si elle est assez haute ; sinon l'ordi attend,
## sauf si sa Ferveur va déborder.
## Lit les règles chiffrées dans PousseeRegles.CARTES (rien n'est codé en dur ici).

const SEUIL := 0.55


## jeu : la scène Poussée. e : équipe jouée. p : IaNiveau.params(…).
## Renvoie {"i": n° de carte dans la main, "pos": Vector2} ou {} pour attendre.
static func decider(jeu, e: int, p: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var C: Dictionary = PousseeRegles.CARTES
	var T: Rect2 = jeu.TERRAIN
	var s := 1.0 if e == 0 else -1.0
	var cx := T.get_center().x
	var cy := T.get_center().y
	var f: float = jeu.ferveur[e]
	var main: Array = jeu.piles[e].slice(0, PousseeRegles.TAILLE_MAIN)
	var b: Vector2 = jeu.ballon["pos"]
	var bv: Vector2 = jeu.ballon["vel"]
	var notre_bord := T.position.x if e == 0 else T.end.x
	var reste: float = PousseeRegles.DUREE - jeu.temps
	var rush: bool = jeu.temps >= PousseeRegles.DUREE - PousseeRegles.RUSH

	# --- lecture du terrain
	var nous: Array = []
	var eux: Array = []
	for u in jeu.unites:
		if u.actif:
			(nous if u.equipe == e else eux).append(u)
	# avancée du ballon : 0 = sur notre ligne, 1 = sur la leur (et dans 1,5 s)
	var av := (b.x - notre_bord) * s / T.size.x
	var av_futur := clampf(((b + bv * 1.5).x - notre_bord) * s / T.size.x, 0.0, 1.0)
	var pousse := [0.0, 0.0]  # nous, eux : force de poussée autour du ballon
	for u in nous:
		if u.carte["type"] == "unite" and u.carte.get("cible", "") != "tribune" and u.position.distance_to(b) < 260.0:
			pousse[0] += float(u.carte["poussee"])
	for u in eux:
		if u.carte["type"] == "unite" and u.carte.get("cible", "") != "tribune" and u.position.distance_to(b) < 260.0:
			pousse[1] += float(u.carte["poussee"])
	# danger du ballon : il approche de notre but et ils poussent plus que nous
	var danger_ballon := clampf((0.5 - minf(av, av_futur)) * 2.4, 0.0, 1.2)
	if absf(b.y - cy) > PousseeRegles.BUT_DEMI_HAUTEUR + 120.0:
		danger_ballon *= 0.6  # loin de l'ouverture du but
	if pousse[0] > pousse[1] + 1.5:
		danger_ballon *= 0.35
	# envahisseurs : leurs supporters dans notre moitié, plus dangereux près de notre tribune
	var envahisseurs: Array = []
	var menace := 0.0
	var valeur_menace := 0.0  # Ferveur qu'ils ont dépensée pour ces supporters
	for u in eux:
		var prof: float = (cx - u.position.x) * s / (T.size.x * 0.5)  # 0 au milieu, 1 sur notre ligne
		if prof > 0.05 or (u.carte.get("cible", "") == "tribune" and prof > -0.25):
			var poids: float = float(u.pv) * (0.5 + maxf(prof, 0.0)) * (1.5 if u.carte.get("cible", "") == "tribune" else 1.0)
			if prof > 0.85:
				poids *= 1.6  # il chante déjà contre notre tribune
			if u.carte["type"] == "batiment":
				poids *= 0.3
			envahisseurs.append({"u": u, "poids": poids})
			menace += poids
			valeur_menace += float(u.carte["cout"]) / float(u.carte.get("nb", 1))
	envahisseurs.sort_custom(func(x, y): return x["poids"] > y["poids"])
	var foyer := Vector2.ZERO  # centre de la menace principale (et ses voisins)
	var foyer_n := 0
	var foyer_cle := ""
	if not envahisseurs.is_empty():
		var tete = envahisseurs[0]["u"]
		foyer_cle = tete.cle
		var somme := 0.0
		for x in envahisseurs:
			if x["u"].position.distance_to(tete.position) < 170.0:
				foyer += x["u"].position * float(x["poids"])
				somme += float(x["poids"])
				foyer_n += 1
		foyer /= maxf(somme, 0.001)
		# nos défenseurs déjà sur place
		var deja := 0.0
		for u in nous:
			if u.position.distance_to(foyer) < float(u.carte["portee"]) + 160.0:
				deja += float(u.pv) * (2.0 if u.carte["type"] == "batiment" else 1.0)
		menace = maxf(menace - deja, 0.0)
	var urgence_def := clampf(menace / 260.0, 0.0, 2.5)
	# notre vague en cours (pour la soutenir)
	var tete_vague = null
	for u in nous:
		if u.carte["type"] == "unite" and float(u.pv) >= 200.0:
			if tete_vague == null or (u.position.x - tete_vague.position.x) * s > 0.0:
				tete_vague = u
	# tribunes : en fin de match, on protège une avance ou on force
	var ecart: float = jeu.tribune[e] - jeu.tribune[1 - e]
	var mode_fin := 0  # 1 = protéger, -1 = tout donner
	if reste < 35.0:
		mode_fin = 1 if ecart > 80.0 else (-1 if ecart < -1.0 else 0)

	# --- note de chaque carte jouable
	var meilleur := {}
	var note_max := -1.0
	for i in main.size():
		var cle: String = main[i]
		var c: Dictionary = C[cle]
		if f < float(c["cout"]):
			continue
		var choix := _noter(cle, c, e, s, T, b, av, danger_ballon, pousse, envahisseurs, foyer, foyer_n, foyer_cle,
			urgence_def, valeur_menace, nous, eux, tete_vague, mode_fin, rush, f, p)
		if choix.is_empty():
			continue
		var note: float = choix["note"] * rng.randf_range(1.0 - float(p.get("distrait", 0.0)), 1.0 + float(p.get("distrait", 0.0)))
		# chaque point de Ferveur dépensé doit rapporter : à note égale, la moins chère
		note -= float(c["cout"]) * 0.03
		if note > note_max:
			note_max = note
			meilleur = {"i": i, "pos": choix["pos"], "attaque": choix.get("attaque", false)}
	if meilleur.is_empty():
		return {}
	var deborde := f >= PousseeRegles.FERVEUR_MAX - 0.6
	# en attaque, garder sa Ferveur pour lancer une vraie vague (sauf dernière minute)
	if meilleur["attaque"] and f < float(p.get("reserve", 6.0)) and not rush and not deborde and mode_fin >= 0:
		return {}
	if note_max < SEUIL and not deborde:
		return {}
	var pos: Vector2 = meilleur["pos"]
	var err := float(p.get("erreur_pose", 0.0))
	pos += Vector2(rng.randf_range(-err, err), rng.randf_range(-err, err))
	if C[main[meilleur["i"]]]["type"] != "effet":
		pos.x = minf(pos.x, cx - 30.0) if e == 0 else maxf(pos.x, cx + 30.0)
	pos.x = clampf(pos.x, T.position.x + 30.0, T.end.x - 30.0)
	pos.y = clampf(pos.y, T.position.y + 30.0, T.end.y - 20.0)
	return {"i": meilleur["i"], "pos": pos}


## Meilleur rôle de la carte maintenant : {"note", "pos", "attaque"} ou {}.
static func _noter(cle: String, c: Dictionary, e: int, s: float, T: Rect2, b: Vector2, av: float, danger_ballon: float,
		pousse: Array, envahisseurs: Array, foyer: Vector2, foyer_n: int, foyer_cle: String, urgence_def: float, valeur_menace: float,
		nous: Array, eux: Array, tete_vague, mode_fin: int, rush: bool, f: float, _p: Dictionary) -> Dictionary:
	var cx := T.get_center().x
	var milieu := cx - s * 40.0
	var options: Array = []
	var vers_tribune: bool = c.get("cible", "") == "tribune"
	var type: String = c["type"]

	# 1) pousser le ballon
	if type == "unite" and not vers_tribune and float(c["poussee"]) >= 0.8:
		var besoin := 0.0
		var pos := Vector2.ZERO
		if av < 0.5:
			besoin = 0.3 + danger_ballon * 1.6
			pos = Vector2(b.x - s * 70.0, b.y)
		else:
			# chez eux : l'accompagner si on n'y pousse pas déjà assez fort
			besoin = 0.75 if pousse[0] < pousse[1] + 1.0 else 0.2
			besoin += 0.35 if av > 0.72 else 0.0   # tout près de leur but
			pos = Vector2(milieu, b.y)
		if mode_fin == -1:
			besoin += 0.3
		# chez eux, accompagner le ballon fait partie d'une attaque (sauf s'il est tout près du but)
		options.append({"note": besoin * float(c["poussee"]) / 2.0 + (0.15 if cle == "drapeau" else 0.0), "pos": pos,
			"attaque": av >= 0.5 and av <= 0.72})

	# 2) défendre contre les envahisseurs
	if urgence_def > 0.0 and not vers_tribune:
		var bonus := 1.0
		match foyer_cle:
			"mascotte":
				bonus = {"canon": 1.5, "chorale": 1.4, "serpentins": 1.25, "drapeau": 0.9, "tambour": 0.7, "fumigene": 0.6}.get(cle, 0.5)
			"chorale":
				bonus = {"fumigene": 1.5, "canon": 1.3, "serpentins": 1.1, "tambour": 0.9, "drapeau": 1.0}.get(cle, 0.5)
			"serpentins":
				bonus = {"tambour": 1.4, "drapeau": 1.1, "canon": 1.1, "chorale": 1.0, "fumigene": 0.8}.get(cle, 0.5)
			"drapeau":
				bonus = {"chorale": 1.3, "serpentins": 1.3, "canon": 1.3, "tambour": 0.8, "fumigene": 0.9}.get(cle, 0.5)
			_:
				bonus = {"canon": 1.1, "serpentins": 1.1, "tambour": 1.1, "chorale": 1.0, "drapeau": 0.9, "fumigene": 0.8}.get(cle, 0.5)
		if cle == "ola":
			bonus = 0.0
		if cle == "fumigene":
			bonus *= 0.6 + 0.4 * foyer_n  # vaut surtout contre un groupe
		var notre_bord := T.position.x if e == 0 else T.end.x
		var pos := foyer
		if type == "batiment":
			# entre eux et notre tribune : ils passent dans sa portée
			pos = foyer.move_toward(Vector2(notre_bord, foyer.y), 140.0)
		elif type == "unite":
			var recul := clampf(float(c["portee"]) * 0.75, 40.0, 200.0)
			pos = Vector2(foyer.x - s * recul, foyer.y)
			if absf(pos.x - notre_bord) < 40.0:
				pos.x = notre_bord + s * 40.0
		# rendre coup pour coup : ne pas dépenser 5 de Ferveur contre un supporter à 2
		var rentable := clampf((valeur_menace + 1.5) / float(c["cout"]), 0.4, 1.2)
		options.append({"note": urgence_def * bonus * rentable * 0.7, "pos": pos})

	# 3) attaquer
	var att := 0.0
	var soutien := false  # renfort d'une vague déjà lancée : pas besoin d'attendre
	var pos_att := Vector2(milieu, b.y)
	match cle:
		"mascotte":
			# le gros coup : la tribune. Plus utile s'il ne reste plus de temps à perdre
			att = 1.0 + (0.4 if rush else 0.0) + (0.5 if mode_fin == -1 else 0.0)
			pos_att = Vector2(milieu, clampf(T.get_center().y + (b.y - T.get_center().y) * -0.5, T.position.y + 80, T.end.y - 80))
		"drapeau":
			att = 0.8
		"serpentins", "chorale":
			# derrière notre gros supporter, à portée de ses adversaires
			if tete_vague != null:
				att = 1.0 if cle == "chorale" else 0.9
				pos_att = Vector2(tete_vague.position.x - s * 110.0, tete_vague.position.y)
				soutien = true
			else:
				att = 0.45
		"tambour":
			att = 0.5
		"canon":
			att = 0.2
		"ola":
			# sur le plus gros groupe de nos supporters qui avance
			var g := _groupe(nous, 180.0, func(u): return u.carte["type"] == "unite")
			if g["n"] >= 2:
				var chez_eux: bool = (g["pos"].x - cx) * s > -150.0
				att = 0.35 * g["n"] + (0.4 if chez_eux else 0.0)
				pos_att = g["pos"] + Vector2(s * 50.0, 0.0)
		"fumigene":
			# sur leurs défenseurs groupés devant notre vague
			var g := _groupe(eux, 160.0, func(u): return u.carte["type"] == "unite" and (u.position.x - cx) * s > -100.0)
			if g["n"] >= 2:
				att = 0.4 * g["n"]
				pos_att = g["pos"]
	if mode_fin == 1:
		att *= 0.5
	elif mode_fin == -1:
		att *= 1.4
	if att > 0.0:
		options.append({"note": att * 0.8, "pos": pos_att, "attaque": not soutien})

	var best := {}
	for o in options:
		if best.is_empty() or float(o["note"]) > float(best["note"]):
			best = o
	return best


## Le plus gros groupe d'unités (filtre) : {"n", "pos"}.
static func _groupe(liste: Array, rayon: float, filtre: Callable) -> Dictionary:
	var res := {"n": 0, "pos": Vector2.ZERO}
	for u in liste:
		if not filtre.call(u):
			continue
		var n := 0
		var somme := Vector2.ZERO
		for o in liste:
			if filtre.call(o) and o.position.distance_to(u.position) < rayon:
				n += 1
				somme += o.position
		if n > res["n"]:
			res = {"n": n, "pos": somme / n}
	return res
