class_name Geo
extends RefCounted
## Place les matchs sur la carte du monde, en trois niveaux :
##   monde     : compétitions mondiales (Mondial, amicaux, Mondial des clubs…)
##   continent : compétitions continentales (coupes d'Europe, Copa Libertad…)
##   pays      : championnat national
## Les données de match ne donnent pas de coordonnées. On retrouve :
##  - le pays d'une compétition nationale (data/carte/pays.json) ;
##  - le pays d'un club grâce à son championnat (index rempli par Donnees) ;
##  - le pays d'une sélection grâce à son nom.
## Le stade est placé à un endroit fixe (tiré au hasard une fois pour toutes)
## à l'intérieur du pays, en attendant que le relais donne la vraie ville.

const CONTINENTS := ["Europe", "Africa", "Asia", "North America", "South America", "Oceania"]
const CENTRES_CONTINENTS := {
	"Europe": Vector2(12.0, 49.0), "Africa": Vector2(20.0, 3.0), "Asia": Vector2(95.0, 32.0),
	"North America": Vector2(-95.0, 35.0), "South America": Vector2(-60.0, -18.0), "Oceania": Vector2(140.0, -25.0),  # sans_traduction
}
## Vue (centre lon/lat, largeur en degrés) de chaque continent.
const VUES_CONTINENTS := {
	"Europe": [Vector2(12.0, 52.0), 60.0], "Africa": [Vector2(18.0, 2.0), 85.0], "Asia": [Vector2(95.0, 30.0), 110.0],
	"North America": [Vector2(-92.0, 33.0), 95.0], "South America": [Vector2(-60.0, -22.0), 70.0],  # sans_traduction
	"Oceania": [Vector2(150.0, -22.0), 75.0],  # sans_traduction
}

static var _d: Dictionary = {}
static var _formes: Dictionary = {}        # cle pays -> Array[PackedVector2Array] (lon, lat)
static var pays_des_equipes: Dictionary = {}  # id équipe -> cle pays (rempli par Donnees)
static var _cache_stades: Dictionary = {}
static var _re_suffixe: RegEx


static func _donnees() -> Dictionary:
	if _d.is_empty():
		var f := FileAccess.open("res://data/carte/pays.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_d = d
	return _d


static func formes() -> Dictionary:
	if _formes.is_empty():
		var f := FileAccess.open("res://data/carte/formes.json", FileAccess.READ)
		if f:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				for cle in d.get("pays", {}):
					var liste: Array = []
					for plat in d["pays"][cle]:
						var pts := PackedVector2Array()
						for i in range(0, plat.size() - 1, 2):
							pts.append(Vector2(plat[i], plat[i + 1]))
						liste.append(pts)
					_formes[cle] = liste
	return _formes


static func forme_pays(cle: String) -> Array:
	var p: Dictionary = _donnees().get("pays", {}).get(cle, {})
	return formes().get(p.get("forme", cle), [])


static func info_competition(id: String) -> Dictionary:
	return _donnees().get("competitions", {}).get(id, {})


static func info_pays(cle: String) -> Dictionary:
	return _donnees().get("pays", {}).get(cle, {})


## Noms de sélections propres au flux API-Football, absents de pays.json.
const ALIAS_FLUX := {
	"cape verde islands": "cape verde", "fyr macedonia": "republic of macedonia",  # sans_traduction
	"french guyana": "french guiana", "rep. of ireland": "ireland", "türkiye": "turkey",  # sans_traduction
	"korea republic": "south korea", "korea dpr": "north korea", "bonaire": "bonaire, sint eustatius and saba",  # sans_traduction
	"sint maarten": "sint maarten (dutch part)", "saint martin": "saint martin (french part)",  # sans_traduction
	"st. vincent / grenadines": "saint vincent and the grenadines", "chinese taipei": "taiwan",  # sans_traduction
}


## Sépare « France U20 » en ["France", " U20"] (sélections de jeunes, olympiques, féminines).
static func _separer_suffixe(nom: String) -> PackedStringArray:
	if _re_suffixe == null:
		_re_suffixe = RegEx.create_from_string("^(.*?)( (?:U-?\\d{2}|W|Women|Olympic))$")  # sans_traduction
	var res := _re_suffixe.search(nom.strip_edges())
	if res:
		return PackedStringArray([res.get_string(1), res.get_string(2)])
	return PackedStringArray([nom.strip_edges(), ""])


static func cle_pays(nom: String) -> String:
	var pays: Dictionary = _donnees().get("pays", {})
	var alias: Dictionary = _donnees().get("alias", {})
	var base := _separer_suffixe(nom)[0].to_lower()
	for k in [base, base.replace("-", " "), base.replace(" & ", " and "), base.replace("st. ", "saint ")]:  # sans_traduction
		if pays.has(k):
			return k
		if alias.has(k):
			return alias[k]
		if ALIAS_FLUX.has(k) and pays.has(ALIAS_FLUX[k]):
			return ALIAS_FLUX[k]
	return ""


static func nom_pays(cle: String) -> String:
	if not Trad.est_source():
		return nom_anglais(cle)
	return info_pays(cle).get("nom", cle.capitalize())


## Nom anglais d'un pays : sa clé (« south korea ») mise en forme.
static func nom_anglais(cle: String) -> String:
	if cle in ["usa", "uae"]:
		return cle.to_upper()
	var mots := []
	for m in cle.split(" "):
		if m in ["and", "of", "the", "da", "de"]:
			mots.append(m)
			continue
		var parts := []
		for x in m.split("-"):
			parts.append(x.left(1).to_upper() + x.substr(1))
		mots.append("-".join(parts))
	return " ".join(mots)


static func nom_pays_fr(nom_anglais: String) -> String:
	## « France U20 » -> « France U20 », « Denmark U20 » -> « Danemark U20 ».
	var k := cle_pays(nom_anglais)
	return nom_pays(k) + _separer_suffixe(nom_anglais)[1] if k != "" else nom_anglais


static func continent_de(cle_pays: String) -> String:
	return info_pays(cle_pays).get("continent", "World")  # sans_traduction


static func niveau_competition(id: String) -> String:
	## "pays", "continent" ou "monde".
	var info := info_competition(id)
	if info.has("pays"):
		return "pays"
	var r: String = info.get("region", "World")  # sans_traduction
	return "continent" if r in CONTINENTS else "monde"


static func lieu_match(m: Dictionary) -> Dictionary:
	## {niveau, continent, pays, lat, lon, stade} : où épingler le match.
	var comp_id := str(m.get("competition", {}).get("id", ""))
	var info := info_competition(comp_id)
	var niveau := niveau_competition(comp_id)
	var home: Dictionary = m.get("home", {})
	var id_home := str(home.get("id", ""))
	var pays := ""
	if info.has("pays"):
		pays = info["pays"]
	elif info.get("type", "") == "international":
		pays = cle_pays(str(home.get("name", "")))
	else:
		pays = pays_des_equipes.get(id_home, "")
	var continent: String = info.get("region", "World") if niveau == "continent" else continent_de(pays)  # sans_traduction
	var pos := position_stade(pays, id_home) if pays != "" else _repli(continent, id_home)
	return {"niveau": niveau, "continent": continent, "pays": pays, "lon": pos.x, "lat": pos.y, "stade": "stade:" + id_home}


static func _repli(continent: String, graine_txt: String) -> Vector2:
	var c: Vector2 = CENTRES_CONTINENTS.get(continent, Vector2(0, 20))
	var g := Fiction.graine(graine_txt)
	return c + Vector2(float(g % 1000) / 100.0 - 5.0, float((g / 1000) % 1000) / 100.0 - 5.0)


static func position_stade(cle: String, id_equipe: String) -> Vector2:
	## Point fixe à l'intérieur du pays (lon, lat), le même à chaque partie.
	var k := cle + "|" + id_equipe
	if _cache_stades.has(k):
		return _cache_stades[k]
	var p := info_pays(cle)
	var capitale := Vector2(float(p.get("lon", 0.0)), float(p.get("lat", 0.0)))
	var res := capitale
	var polys := forme_pays(cle)
	if not polys.is_empty():
		# le plus grand polygone du pays (évite les îles lointaines)
		var grand: PackedVector2Array = polys[0]
		var aire := 0.0
		for poly in polys:
			var r := Rect2(poly[0], Vector2.ZERO)
			for q in poly:
				r = r.expand(q)
			if r.get_area() > aire:
				aire = r.get_area()
				grand = poly
		var boite := Rect2(grand[0], Vector2.ZERO)
		for q in grand:
			boite = boite.expand(q)
		var g := Fiction.graine(id_equipe)
		for essai in 40:
			var u := float((g >> (essai % 8)) % 997) / 997.0
			var v := float((g / 997 + essai * 7919) % 991) / 991.0
			var cand := boite.position + Vector2(u * boite.size.x, v * boite.size.y)
			# reste près de la capitale pour les très grands pays
			cand = capitale.lerp(cand, 0.8 if boite.size.x < 15 else 0.45)
			if Geometry2D.is_point_in_polygon(cand, grand):
				res = cand
				break
			g = Fiction.graine(str(g))
	_cache_stades[k] = res
	return res


static func distance_km(a: Vector2, b: Vector2) -> float:
	## a et b en (lon, lat).
	var r := 6371.0
	var p1 := deg_to_rad(a.y)
	var p2 := deg_to_rad(b.y)
	var dp := p2 - p1
	var dl := deg_to_rad(b.x - a.x)
	var h := sin(dp / 2) ** 2 + cos(p1) * cos(p2) * sin(dl / 2) ** 2
	return 2 * r * asin(sqrt(clampf(h, 0.0, 1.0)))


static func centre_pays(cle: String) -> Vector2:
	var polys := forme_pays(cle)
	var p := info_pays(cle)
	if polys.is_empty():
		return Vector2(float(p.get("lon", 0.0)), float(p.get("lat", 0.0)))
	var grand: PackedVector2Array = polys[0]
	var b := Rect2(grand[0], Vector2.ZERO)
	var meilleur := 0.0
	for poly in polys:
		var r := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			r = r.expand(q)
		if r.get_area() > meilleur:
			meilleur = r.get_area()
			b = r
	return b.get_center()


static func taille_pays(cle: String) -> float:
	## Largeur en degrés de la partie principale du pays (pour zoomer dessus).
	var polys := forme_pays(cle)
	var meilleur := Rect2()
	for poly in polys:
		var r := Rect2(poly[0], Vector2.ZERO)
		for q in poly:
			r = r.expand(q)
		if r.get_area() > meilleur.get_area():
			meilleur = r
	return maxf(maxf(meilleur.size.x, meilleur.size.y * 1.6), 4.0)
