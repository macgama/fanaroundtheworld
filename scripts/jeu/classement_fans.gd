class_name ClassementFans
extends RefCounted
## Classement en ligne, sans affichage ni réseau (le réseau est dans l'autoload EnLigne).
##
## Le serveur (Worker Cloudflare, macgama/fanaroundtheworld-data, src/classement.js)
## additionne les points de popularité de tous les joueurs. Il refait les contrôles
## du jeu (barème, 200 points par équipe et par jour).
##
## Identité : un identifiant public et une clé secrète tirés au hasard, aucune
## donnée personnelle. Le pseudo est fait de deux mots de ces listes et d'un
## nombre : aucun texte libre ne part sur le serveur, le classement reste familial.
## Le serveur garde seulement les numéros [nom, qualité, nombre].

## Le serveur accepte au plus 64 mots par liste : on peut en ajouter à la fin,
## jamais en retirer ni en changer l'ordre (les pseudos déjà choisis changeraient).
const NOMS := [
	"Tambour", "Fanion", "Mégaphone", "Supporter", "Tifo", "Capo", "Sifflet", "Klaxon",
	"Drapeau", "Maillot", "Ballon", "Crampon", "Gradin", "Virage", "Chant", "Tonnerre",
	"Lion", "Aigle", "Renard", "Dragon", "Requin", "Ours", "Loup", "Tigre",  # sans_traduction
	"Phénix", "Bison", "Faucon", "Lynx", "Cyclone", "Volcan", "Météore", "Comète",  # sans_traduction
]
const QUALITES := [
	"Joyeux", "Fidèle", "Survolté", "Infatigable", "Magique", "Géant", "Rapide", "Vaillant",  # sans_traduction
	"Endiablé", "Flamboyant", "Malin", "Rugissant", "Électrique", "Cosmique", "Légendaire", "Intrépide",  # sans_traduction
	"Bondissant", "Tonitruant", "Étincelant", "Rusé", "Courageux", "Souriant", "Puissant", "Agile",  # sans_traduction
	"Brillant", "Sonore", "Enflammé", "Têtu", "Généreux", "Supersonique", "Inarrêtable", "Radieux",  # sans_traduction
]

const URL := "https://fanaroundtheworld-live.gael-manigley.workers.dev/classement/"
const MAX_LIGNES := 300


static func vide() -> Dictionary:
	return {
		"id": "",          # 16 caractères hexadécimaux (public)
		"cle": "",         # 32 caractères hexadécimaux (secret, jamais affiché)
		"pseudo": [0, 0, 0],
		"visible": true,   # apparaître dans le classement des fans
	}


static func reparer(d: Variant) -> Dictionary:
	var r := vide()
	if d is Dictionary:
		for k in r:
			if d.has(k) and typeof(d[k]) == typeof(r[k]):
				r[k] = d[k]
	var p: Array = r["pseudo"]
	if p.size() != 3:
		r["pseudo"] = [0, 0, 0]
	else:
		r["pseudo"] = [clampi(int(p[0]), 0, NOMS.size() - 1), clampi(int(p[1]), 0, QUALITES.size() - 1), clampi(int(p[2]), 0, 99)]
	return r


static func _hexa(rng: RandomNumberGenerator, n: int) -> String:
	var s := ""
	for i in n:
		s += "0123456789abcdef"[rng.randi() % 16]
	return s


## Identité neuve (au premier lancement), avec un pseudo tiré au hasard.
static func identite_neuve(rng: RandomNumberGenerator) -> Dictionary:
	var d := vide()
	d["id"] = _hexa(rng, 16)
	d["cle"] = _hexa(rng, 32)
	d["pseudo"] = [rng.randi() % NOMS.size(), rng.randi() % QUALITES.size(), rng.randi() % 100]
	return d


static func identite_valide(d: Dictionary) -> bool:
	return str(d.get("id", "")).length() == 16 and str(d.get("cle", "")).length() == 32


## « Tambour Joyeux 42 ». Un numéro inconnu (liste plus récente) reste lisible.
static func pseudo_texte(p: Variant) -> String:
	if not p is Array or p.size() != 3:
		return "Supporter mystère"
	var a := int(p[0])
	var b := int(p[1])
	var nom: String = NOMS[a] if a >= 0 and a < NOMS.size() else "Supporter"  # sans_traduction
	var qual: String = QUALITES[b] if b >= 0 and b < QUALITES.size() else "Mystère"  # sans_traduction
	return "%s %s %d" % [nom, qual, int(p[2])]


## Corps de l'envoi et nombre de lignes de la file qu'il contient.
static func preparer_envoi(supporters: Dictionary, ident: Dictionary) -> Dictionary:
	var file: Array = supporters.get("a_envoyer", [])
	var lignes := file.slice(0, MAX_LIGNES)
	var points: Array = []
	for l in lignes:
		points.append({"equipe": str(l.get("equipe", "")), "points": int(l.get("points", 0)),
			"raison": str(l.get("raison", "")), "t": int(l.get("t", 0))})
	return {
		"n": lignes.size(),
		"corps": {"v": 1, "id": ident["id"], "cle": ident["cle"], "pseudo": ident["pseudo"],
			"visible": bool(ident["visible"]), "points": points},
	}


## Après une réponse du serveur : retire les `n` lignes envoyées de la file
## (acceptées ou refusées, on ne les renvoie pas) et note ce qu'il a compté.
static func appliquer_reponse(supporters: Dictionary, n: int, acceptes: Dictionary) -> void:
	var file: Array = supporters.get("a_envoyer", [])
	supporters["a_envoyer"] = file.slice(mini(n, file.size()))
	var envoye: Dictionary = supporters.get("envoye", {})
	for cle in acceptes:
		envoye[str(cle)] = int(envoye.get(str(cle), 0)) + int(acceptes[cle])
	supporters["envoye"] = envoye


## Points des autres supporters, d'après le serveur : son total moins ce qu'il a
## déjà compté pour toi (tes points sont ajoutés à part, avec ceux pas encore envoyés).
## `equipes` : contenu de equipes.json ; `periode` : "p" (total) ou "s" (semaine).
static func communaute(equipes: Dictionary, envoye: Dictionary, periode := "p") -> Dictionary:
	var c := {}
	for cle in equipes:
		var e: Variant = equipes[cle]
		if not e is Dictionary:
			continue
		var n := int(e.get(periode, 0))
		if periode == "p":
			n -= int(envoye.get(cle, 0))
		c[cle] = maxi(0, n)
	return c


## Classement d'une période ("p" total, "s" semaine) à partir de equipes.json,
## limité aux clés acceptées par `filtre` s'il est donné. [{cle, points, fans, rang}]
static func lignes_equipes(equipes: Dictionary, periode: String, filtre: Callable = Callable()) -> Array:
	var out: Array = []
	for cle in equipes:
		var e: Variant = equipes[cle]
		if not e is Dictionary or (filtre.is_valid() and not filtre.call(str(cle))):
			continue
		var n := int(e.get(periode, 0))
		if n > 0:
			out.append({"cle": str(cle), "points": n, "fans": int(e.get("f", 0))})
	out.sort_custom(func(a, b):
		if a["points"] != b["points"]:
			return a["points"] > b["points"]
		return a["cle"] < b["cle"])
	for i in out.size():
		out[i]["rang"] = i + 1
	return out
