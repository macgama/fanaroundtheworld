class_name Protocole
extends RefCounted
## Règles du jeu en ligne, sans réseau ni écran (testables) :
##  - forme et validation des messages échangés entre les deux joueurs ;
##  - profil d'un joueur (fan club, couleurs, tribune) nettoyé avant affichage ;
##  - jauge d'ambiance partagée : l'hôte fait foi, l'invité prédit ses propres gestes.
##
## Un message est un Dictionary avec une clé "t" (son type). Tout ce qui vient
## de l'autre joueur est vérifié ici avant d'être utilisé.

## Change dès que le format des messages change : deux versions différentes
## refusent de jouer ensemble.
const VERSION := 1
const JEU := "fanaroundtheworld"

const TYPES := {
	"profil": ["nom", "couleurs", "equipe", "niveau", "v"],
	"match": ["m", "camp_hote"],   # l'hôte envoie le match et son camp
	"pret": [],                    # écran du duel chargé
	"depart": [],                  # l'hôte lance le compte à rebours
	"pousse": ["d", "n"],          # geste de l'invité : variation de jauge + numéro
	"evt": ["e"],                  # effet à montrer chez l'autre (tifo, ola, combo…)
	"etat": ["j", "ack", "t"],     # l'hôte : jauge (son point de vue), dernier geste reçu, temps
	"fin": ["j"],                  # l'hôte : jauge finale
	"lancer": [],                  # l'hôte, dans le salon : on passe au duel
}
const EVENEMENTS := ["tifo", "ola", "ola_ratee", "combo", "but"]
## Un geste ne peut pas bouger la jauge de plus que ça (le tifo fait +17 au mieux).
const POUSSE_MAX := 25.0
const NOM_MAX := 28


static func msg(t: String, donnees: Dictionary = {}) -> Dictionary:
	var m := donnees.duplicate()
	m["t"] = t
	return m


## Vrai si le message est bien formé (type connu, champs présents, valeurs raisonnables).
static func valide(m: Variant) -> bool:
	if not m is Dictionary:
		return false
	var t: Variant = m.get("t")
	if not t is String or not TYPES.has(t):
		return false
	for k in TYPES[t]:
		if not m.has(k):
			return false
	match t:
		"pousse":
			return _nombre(m["d"]) and absf(float(m["d"])) <= POUSSE_MAX and _nombre(m["n"])
		"etat":
			return _nombre(m["j"]) and _nombre(m["ack"]) and _nombre(m["t"])
		"fin":
			return _nombre(m["j"])
		"evt":
			return m["e"] is String and m["e"] in EVENEMENTS
		"match":
			return m["m"] is Dictionary and m["camp_hote"] in ["home", "away"]
		"profil":
			return m["equipe"] is Array and m["couleurs"] is Array and _nombre(m["v"])
	return true


static func _nombre(v: Variant) -> bool:
	return (v is float or v is int) and is_finite(float(v))


# ---------------------------------------------------------------- profil

## Ce que l'autre joueur voit de toi. `equipe` : les skins affichés (noms d'image).
static func profil(nom: String, couleurs: Array, equipe: Array, niveau: int) -> Dictionary:
	return msg("profil", {
		"nom": nom, "couleurs": couleurs.map(func(c): return c.to_html(false) if c is Color else str(c)),
		"equipe": equipe.map(func(id): return str(id)), "niveau": niveau, "v": VERSION,
	})


## Profil reçu, nettoyé : nom coupé, couleurs valides, au plus 3 FANZZY.
static func profil_propre(m: Dictionary) -> Dictionary:
	var nom := str(m.get("nom", "")).strip_edges().strip_escapes().substr(0, NOM_MAX)
	if nom.is_empty():
		nom = "Tribune mystère"
	var couleurs: Array = []
	for c in m.get("couleurs", []).slice(0, 2):
		couleurs.append(Color.from_string(str(c), Color("#ff4b4b")))
	while couleurs.size() < 2:
		couleurs.append(Color("#ff4b4b") if couleurs.is_empty() else Color.WHITE)
	var equipe: Array = []
	var re := RegEx.create_from_string("^[A-Za-z0-9_]{1,16}$")
	for id in m.get("equipe", []).slice(0, 3):
		var s := str(id)
		equipe.append(s if re.search(s) else "")
	return {"nom": nom, "couleurs": couleurs, "equipe": equipe,
		"niveau": clampi(int(m.get("niveau", 1)), 1, 999), "v": int(m.get("v", 0))}


static func meme_version(p: Dictionary) -> bool:
	return int(p.get("v", 0)) == VERSION


static func camp_oppose(camp: String) -> String:
	return "away" if camp == "home" else "home"


# ---------------------------------------------------------------- jauge partagée

## La jauge va de -100 à +100. Chez l'hôte : + = l'hôte domine.
## L'invité voit la même jauge retournée (+ = l'invité domine).
##
## Hôte : chaque geste local est ajouté, chaque geste de l'invité est retiré, dans
## l'ordre d'arrivée. Il renvoie régulièrement la jauge et le numéro du dernier
## geste de l'invité qu'il a pris en compte (ack).
## Invité : il montre tout de suite l'effet de ses gestes (prédiction), puis se cale
## sur l'état de l'hôte en rejouant les gestes que l'hôte n'a pas encore reçus.
class JaugePartagee:
	extends RefCounted
	var hote := true
	var jauge := 0.0          # toujours du point de vue du joueur local
	var _numero := 0          # invité : numéro du dernier geste envoyé
	var _en_vol: Array = []   # invité : [numéro, variation] pas encore confirmés
	var _ack := 0             # hôte : dernier geste de l'invité appliqué

	func _init(est_hote: bool) -> void:
		hote = est_hote

	## Geste du joueur local. Renvoie le message à envoyer (vide chez l'hôte).
	func local(d: float) -> Dictionary:
		jauge = clampf(jauge + d, -100.0, 100.0)
		if hote:
			return {}
		_numero += 1
		_en_vol.append([_numero, d])
		return Protocole.msg("pousse", {"d": d, "n": _numero})

	## Hôte : geste reçu de l'invité (il fait baisser la jauge de l'hôte).
	func distant(m: Dictionary) -> void:
		if not hote or int(m["n"]) <= _ack:
			return
		_ack = int(m["n"])
		jauge = clampf(jauge - float(m["d"]), -100.0, 100.0)

	## Hôte : message d'état à envoyer à l'invité.
	func etat(temps: float) -> Dictionary:
		return Protocole.msg("etat", {"j": jauge, "ack": _ack, "t": temps})

	## Invité : état reçu de l'hôte.
	func recaler(m: Dictionary) -> void:
		if hote:
			return
		var ack := int(m["ack"])
		_en_vol = _en_vol.filter(func(g): return g[0] > ack)
		var j := -float(m["j"])
		for g in _en_vol:
			j = clampf(j + g[1], -100.0, 100.0)
		jauge = j

	## Fin du duel : la jauge finale de l'hôte fait foi.
	func finale(m: Dictionary) -> float:
		jauge = float(m["j"]) if hote else -float(m["j"])
		_en_vol.clear()
		return jauge

	func en_attente() -> int:
		return _en_vol.size()


# ---------------------------------------------------------------- salons

## Annonce d'un salon sur le réseau local (diffusée en UDP).
static func annonce_lan(nom: String, match_texte: String, port: int) -> PackedByteArray:
	return JSON.stringify({"jeu": JEU, "v": VERSION, "nom": nom.substr(0, NOM_MAX),
		"match": match_texte.substr(0, 80), "port": port}).to_utf8_buffer()


## Annonce reçue : {} si ce n'est pas un salon de ce jeu dans la même version.
static func lire_annonce(paquet: PackedByteArray) -> Dictionary:
	if paquet.size() > 1024:
		return {}
	var json := JSON.new()  # parse() ne remplit pas la console si le paquet n'est pas du JSON
	if json.parse(paquet.get_string_from_utf8()) != OK:
		return {}
	var d: Variant = json.data
	if not d is Dictionary or d.get("jeu") != JEU or int(d.get("v", 0)) != VERSION:
		return {}
	var port := int(d.get("port", 0))
	if port < 1024 or port > 65535:
		return {}
	return {"nom": str(d.get("nom", "?")).substr(0, NOM_MAX), "match": str(d.get("match", "")).substr(0, 80), "port": port}
