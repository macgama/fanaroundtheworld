class_name Collection
extends RefCounted
## Règles de la collection, sans écran (testables) :
##  - le carnet de voyage : un tampon par stade visité (Game.tampons) ;
##  - l'album des FANZZY : un FANZZY y entre quand il a joué un duel dans ta
##    tribune, et chaque skin porté en duel entre dans sa garde-robe.
## Compléter une série (palier de stades, pays, continents, championnat entier,
## famille ou série de FANZZY) donne une prime en Jetons, à réclamer une fois.
## Les skins ne donnent jamais de Jetons et ne s'achètent jamais avec : la
## garde-robe est un simple souvenir (les skins viennent du PASS et des événements).
##
## L'état sauvegardé (Game.collection) :
##   {"fanzzy": {id: date}, "skins": {id_skin: date}, "primes": {id_serie: date}}

## [nombre à atteindre, prime en Jetons]
const PALIERS_STADES := [[1, 20], [5, 50], [10, 100], [25, 200], [50, 400], [100, 800]]
const PALIERS_PAYS := [[2, 40], [5, 120], [10, 250], [20, 500]]
const PALIERS_CONTINENTS := [[2, 100], [3, 200], [5, 500]]
## Championnat complet : tous les stades des clubs d'une ligue. Prime par stade.
const PRIME_PAR_STADE_LIGUE := 15
## Album des FANZZY.
const PRIME_FAMILLE := 80
const PRIME_SERIE := 60
const PRIME_ALBUM := 300
## Continents comptés pour le tour du monde.
const NOMS_CONTINENTS := {
	"Europe": "Europe", "South America": "Amérique du Sud", "North America": "Amérique du Nord",
	"Africa": "Afrique", "Asia": "Asie", "Oceania": "Océanie",
}


static func vide() -> Dictionary:
	return {"fanzzy": {}, "skins": {}, "primes": {}}


static func reparer(c: Variant) -> Dictionary:
	var base := vide()
	if not c is Dictionary:
		return base
	for k in base:
		if not c.get(k) is Dictionary:
			c[k] = {}
	return c


# ---------------------------------------------------------------- album

## Fin d'un duel : les FANZZY de la tribune et les skins qu'ils portent entrent
## dans l'album. Renvoie les FANZZY nouvellement ajoutés.
static func noter_duel(c: Dictionary, equipe: Array, skins_portes: Array, jour: String) -> Array:
	var nouveaux: Array = []
	for id in equipe:
		var k := str(id)
		if k != "" and not c["fanzzy"].has(k):
			c["fanzzy"][k] = jour
			nouveaux.append(k)
	for s in skins_portes:
		var k := str(s)
		if k != "" and not c["skins"].has(k):
			c["skins"][k] = jour
	return nouveaux


static func a_fanzzy(c: Dictionary, id: String) -> bool:
	return c["fanzzy"].has(id)


static func a_skin(c: Dictionary, id_skin: String) -> bool:
	return c["skins"].has(id_skin)


## Séries de l'album : une par famille, une par série du catalogue, l'album entier.
## `catalogue` : Game.fanzzy ; `familles`, `series` : noms et couleurs.
static func series_album(c: Dictionary, catalogue: Array, familles: Dictionary, series: Dictionary) -> Array:
	var par_famille: Dictionary = {}
	var par_serie: Dictionary = {}
	for z in catalogue:
		var f := str(z.get("famille", ""))
		var s := str(z.get("serie", ""))
		if not par_famille.has(f):
			par_famille[f] = []
		par_famille[f].append(z["id"])
		if not par_serie.has(s):
			par_serie[s] = []
		par_serie[s].append(z["id"])
	var res: Array = []
	for f in familles:
		if par_famille.has(f):
			res.append(_serie(c, "famille:" + f, Trad.t("Famille %s") % Trad.t(familles[f].get("nom", f)),
				"Tous les FANZZY de la famille", par_famille[f], PRIME_FAMILLE, "famille", familles[f].get("couleur", "#888888")))
	var cles_series := par_serie.keys()
	cles_series.sort()
	for s in cles_series:
		var info: Dictionary = series.get(s, {})
		res.append(_serie(c, "serie:" + s, Trad.t(str(info.get("nom", Trad.t("Série ") + s))),
			Trad.t(str(info.get("ligne", "Toute la série"))), par_serie[s], PRIME_SERIE, "serie", info.get("couleur", "#888888")))
	var tous: Array = catalogue.map(func(z): return z["id"])
	res.append(_serie(c, "album", "Album complet", "Chaque FANZZY a joué au moins un duel avec toi", tous, PRIME_ALBUM, "album", "#ffd23f"))
	return res


static func _serie(c: Dictionary, id: String, titre: String, texte: String, ids: Array, prime: int, groupe: String, couleur: String) -> Dictionary:
	var fait := ids.filter(func(x): return c["fanzzy"].has(str(x))).size()
	return _ligne(c, id, titre, texte, fait, ids.size(), prime, groupe, couleur)


# ---------------------------------------------------------------- carnet de voyage

## Pays d'un tampon (enregistré au voyage, sinon retrouvé par le club qui reçoit).
static func pays_tampon(cle: String, info: Dictionary, pays_des_equipes: Dictionary) -> String:
	var p := str(info.get("pays", ""))
	if p == "":
		p = str(pays_des_equipes.get(cle.trim_prefix("stade:"), ""))
	return p


## Pays et continents visités : {"pays": {cle: nb}, "continents": {nom: nb}}.
## `continent_de` : Callable(cle_pays) -> nom du continent (Geo.continent_de).
static func lieux_visites(tampons: Dictionary, pays_des_equipes: Dictionary, continent_de: Callable) -> Dictionary:
	var pays: Dictionary = {}
	var continents: Dictionary = {}
	for cle in tampons:
		var info: Dictionary = tampons[cle] if tampons[cle] is Dictionary else {}
		var p := pays_tampon(str(cle), info, pays_des_equipes)
		var cont := str(info.get("continent", ""))
		if p != "":
			pays[p] = int(pays.get(p, 0)) + 1
			if cont == "":
				cont = str(continent_de.call(p))
		if NOMS_CONTINENTS.has(cont):
			continents[cont] = int(continents.get(cont, 0)) + 1
	return {"pays": pays, "continents": continents}


## Séries du carnet : paliers de stades, de pays, de continents, puis un
## championnat par ligue (tous ses stades). `championnats` : {id ligue: {titre, clubs: [id]}}.
## Les ligues sans aucun tampon ne sont pas listées.
static func series_carnet(c: Dictionary, tampons: Dictionary, lieux: Dictionary, championnats: Dictionary) -> Array:
	var res: Array = []
	res.append_array(_paliers(c, "stades", "%d stades", "Tamponne des stades différents", tampons.size(), PALIERS_STADES, "#ff3d7f"))
	res.append_array(_paliers(c, "pays", "%d pays", "Visite des stades dans des pays différents", lieux["pays"].size(), PALIERS_PAYS, "#3ddc84"))
	res.append_array(_paliers(c, "continents", "%d continents", "Le tour du monde des tribunes", lieux["continents"].size(), PALIERS_CONTINENTS, "#8b5cff"))
	var ligues: Array = []
	for id in championnats:
		var clubs: Array = championnats[id].get("clubs", [])
		if clubs.is_empty():
			continue
		var fait := clubs.filter(func(e): return tampons.has("stade:" + str(e))).size()
		if fait == 0 and not c["primes"].has("ligue:" + str(id)):
			continue
		ligues.append(_ligne(c, "ligue:" + str(id), str(championnats[id].get("titre", id)),
			"Tous les stades du championnat", fait, clubs.size(), PRIME_PAR_STADE_LIGUE * clubs.size(), "ligue", "#1e6bff"))
	ligues.sort_custom(func(a, b): return float(a["fait"]) / a["total"] > float(b["fait"]) / b["total"])
	res.append_array(ligues)
	return res


## Un palier par seuil, mais seulement ceux déjà atteints et le suivant.
static func _paliers(c: Dictionary, groupe: String, titre: String, texte: String, n: int, paliers: Array, couleur: String) -> Array:
	var res: Array = []
	for p in paliers:
		var seuil: int = p[0]
		var t := (titre % seuil).replace(Trad.t("1 stades"), Trad.t("1 stade"))
		res.append(_ligne(c, "%s:%d" % [groupe, seuil], t, texte, mini(n, seuil), seuil, p[1], groupe, couleur))
		if n < seuil:
			break
	return res


static func _ligne(c: Dictionary, id: String, titre: String, texte: String, fait: int, total: int, prime: int, groupe: String, couleur: String) -> Dictionary:
	return {
		"id": id, "titre": titre, "texte": texte, "fait": fait, "total": total, "prime": prime,
		"groupe": groupe, "couleur": couleur,
		"complete": total > 0 and fait >= total,
		"reclamee": c["primes"].has(id),
	}


# ---------------------------------------------------------------- primes

static func pretes(series: Array) -> Array:
	return series.filter(func(s): return s["complete"] and not s["reclamee"])


## Marque la prime comme réclamée et renvoie les Jetons à verser (0 si impossible).
static func reclamer(c: Dictionary, serie: Dictionary, jour: String) -> int:
	if not serie.get("complete", false) or c["primes"].has(serie["id"]):
		return 0
	c["primes"][serie["id"]] = jour
	serie["reclamee"] = true
	return int(serie["prime"])
