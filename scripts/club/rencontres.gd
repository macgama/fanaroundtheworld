class_name Rencontres
extends RefCounted
## Recruter un FANZZY : on ne le choisit plus dans une liste, on le RENCONTRE
## (au stade après un duel, pendant le cortège, en déplacement…), puis on le
## convainc de rejoindre le club avec un petit défi sur le geste de sa famille.
##
## Rien ne se paie en Jetons. Un défi raté ne fait rien perdre : le FANZZY
## reste dans la liste et l'on peut retenter un peu plus tard.
## Les recrues du PASS rejoignent le club sans défi (c'est une récompense).
##
## État : Game.club["rencontres"] = [{id, lieu, quand, retente}].

## FANZZY rencontrés en attente, au plus.
const MAX_EN_ATTENTE := 3
## Après un défi raté, on peut retenter au bout de ce délai (secondes).
const ATTENTE_APRES_ECHEC := 30 * 60
## Rencontres offertes à la création du club (et aux sauvegardes d'avant les rencontres).
const RENCONTRES_DEPART := 2

## Où l'on croise les FANZZY. « familles » : celles qu'on y croise le plus souvent.
const LIEUX := {
	"quartier": {"texte": "dans le quartier du local", "familles": []},
	"stade": {"texte": "au stade, après un duel", "familles": ["tifo", "pyro", "fide"]},
	"tribune": {"texte": "devant l'écran, après un duel", "familles": ["voix", "perc"]},
	"cortege": {"texte": "pendant le cortège", "familles": ["voix", "perc", "depl"]},
	"deplacement": {"texte": "en déplacement", "familles": ["depl", "fide"]},
}
## Chance d'une rencontre à la fin d'un duel, selon où l'on suit le match.
const CHANCE_DUEL := {"stade": 0.3, "ecran": 0.12, "pub": 0.12, "maison": 0.0}
const CHANCE_DEPLACEMENT := 0.5

## Le défi de chaque famille : rythme (taper au tempo), mémoire (refaire la
## mosaïque de couleurs) ou précision (arrêter le curseur dans la zone).
const DEFIS := {
	"voix": "rythme", "perc": "rythme",
	"tifo": "memoire", "depl": "memoire",
	"fide": "precision", "pyro": "precision",
}
const TITRES_DEFI := {
	"rythme": "Chante dans le tempo",
	"memoire": "Refais la mosaïque",
	"precision": "Le geste parfait",
}
## Ce que dit le FANZZY avant le défi.
const PHRASES := {
	"voix": "Si ton club chante juste, je viens avec vous !",
	"perc": "Montre-moi que vous tenez le rythme !",
	"tifo": "Un club sans beaux tifos ? Prouve-moi le contraire !",
	"depl": "Je retiens tous les stades. Et toi, tu as de la mémoire ?",
	"fide": "Je suis fidèle, mais exigeant : un geste parfait, et je signe.",
	"pyro": "Confettis, ballons, lanternes : tout est dans le timing !",
}
## Réussite : nombre de bons coups demandés, sur le nombre d'essais.
## Les FANZZY légendaires demandent un coup de plus.
const REUSSITE := {"rythme": [6, 8], "memoire": [2, 3], "precision": [3, 5]}


static func liste(c: Dictionary) -> Array:
	var l: Variant = c.get("rencontres", [])
	return l if l is Array else []


static func defi(famille: String) -> String:
	return str(DEFIS.get(famille, "rythme"))


## Bons coups demandés pour ce FANZZY : [à réussir, essais].
static func objectif(z: Dictionary) -> Array:
	var r: Array = REUSSITE[defi(str(z.get("famille", "")))].duplicate()
	if str(z.get("rarete", "")) == "legendaire":
		r[0] = mini(int(r[0]) + 1, int(r[1]))
	return r


static func reussi(z: Dictionary, bons: int) -> bool:
	return bons >= int(objectif(z)[0])


static func en_attente(c: Dictionary, id: String) -> bool:
	for r in liste(c):
		if str(r.get("id", "")) == id:
			return true
	return false


static func entree(c: Dictionary, id: String) -> Dictionary:
	for r in liste(c):
		if str(r.get("id", "")) == id:
			return r
	return {}


## Les recrues du PASS débloquées rejoignent sans défi.
static func sans_defi(z: Dictionary) -> bool:
	return z.has("pass")


## FANZZY qu'on peut encore croiser : jouables, pas membres, pas déjà rencontrés.
## `fanzzy` : les FANZZY jouables (Game.fanzzy). Les recrues du PASS n'ont pas
## besoin d'être rencontrées : elles ne sont pas proposées ici.
static func candidats(c: Dictionary, fanzzy: Array) -> Array:
	var membres: Array = c.get("membres", [])
	return fanzzy.filter(func(z): return not sans_defi(z) and not str(z["id"]) in membres and not en_attente(c, str(z["id"])))


## Choisit qui l'on croise à cet endroit (les familles du lieu sont 3 fois plus
## probables). {} si personne ou si la liste est pleine.
static func tirer(c: Dictionary, fanzzy: Array, lieu: String, tirage: float) -> Dictionary:
	if liste(c).size() >= MAX_EN_ATTENTE:
		return {}
	var cands := candidats(c, fanzzy)
	if cands.is_empty():
		return {}
	var fams: Array = LIEUX.get(lieu, {}).get("familles", [])
	var poids: Array = []
	var total := 0.0
	for z in cands:
		var p := 3.0 if str(z["famille"]) in fams else 1.0
		poids.append(p)
		total += p
	var cible := clampf(tirage, 0.0, 0.9999) * total
	for i in cands.size():
		cible -= poids[i]
		if cible < 0.0:
			return cands[i]
	return cands[-1]


## Ajoute une rencontre. Rend false si la liste est pleine ou s'il y est déjà.
static func ajouter(c: Dictionary, id: String, lieu: String, maintenant: int) -> bool:
	if id == "" or en_attente(c, id) or liste(c).size() >= MAX_EN_ATTENTE or id in c.get("membres", []):
		return false
	if not c.has("rencontres") or not c["rencontres"] is Array:
		c["rencontres"] = []
	c["rencontres"].append({"id": id, "lieu": lieu, "quand": maintenant, "retente": 0})
	return true


static func retirer(c: Dictionary, id: String) -> void:
	c["rencontres"] = liste(c).filter(func(r): return str(r.get("id", "")) != id)


## Secondes avant de pouvoir retenter le défi (0 : tout de suite).
static func attente(c: Dictionary, id: String, maintenant: int) -> int:
	return maxi(0, int(entree(c, id).get("retente", 0)) - maintenant)


## Défi raté : il reviendra plus tard.
static func noter_echec(c: Dictionary, id: String, maintenant: int) -> void:
	for r in liste(c):
		if str(r.get("id", "")) == id:
			r["retente"] = maintenant + ATTENTE_APRES_ECHEC


static func lieu_texte(lieu: String) -> String:
	return Trad.t(str(LIEUX.get(lieu, LIEUX["quartier"])["texte"]))


## Nettoie une sauvegarde : entrées valides, pas de membres, pas de doublon.
static func reparer(c: Dictionary, existe: Callable) -> void:
	var propre: Array = []
	var vus := {}
	for r in liste(c):
		if not r is Dictionary:
			continue
		var id := str(r.get("id", ""))
		if id == "" or vus.has(id) or id in c.get("membres", []) or not existe.call(id):
			continue
		vus[id] = true
		propre.append({"id": id, "lieu": str(r.get("lieu", "quartier")), "quand": int(r.get("quand", 0)), "retente": int(r.get("retente", 0))})
	c["rencontres"] = propre.slice(0, MAX_EN_ATTENTE)
