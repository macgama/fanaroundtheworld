class_name Fiction
extends RefCounted
## Transforme les vraies équipes et compétitions en noms fictifs.
## Le jeu n'affiche jamais les vrais noms de clubs (ni logos) :
##  1. la table data/clubs/noms_fictifs.json (modifiable par les mods Workshop)
##     donne un nom choisi à la main pour certains clubs ;
##  2. sinon, un nom est inventé à partir de l'identifiant de l'équipe,
##     toujours le même pour un même club.
## Les sélections nationales gardent le nom de leur pays (en français).

const ANIMAUX := [
	"Lions", "Aigles", "Loups", "Requins", "Taureaux", "Corsaires", "Dragons", "Faucons",
	"Ours", "Tigres", "Pirates", "Titans", "Sangliers", "Béliers", "Renards", "Hiboux",
	"Cobras", "Condors", "Jaguars", "Bisons", "Phénix", "Vikings", "Mammouths", "Rhinos",
	"Gladiateurs", "Mousquetaires", "Volcans", "Ouragans", "Météores", "Pélicans",
	"Crocodiles", "Albatros", "Lynx", "Frelons", "Castors", "Cerfs",
]
const QUALITES := [
	"Dorés", "Bleus", "Rouges", "Verts", "Noirs", "Blancs", "Violets", "Jaunes",
	"Rugissants", "Volants", "Sauvages", "Fous", "Célestes", "Électriques", "Écarlates",
	"Indomptables", "Royaux", "Glacés", "Brûlants", "du Port", "des Collines", "du Nord",
	"du Sud", "de la Vallée", "des Sables", "du Fleuve", "de l'Est", "de l'Ouest",
	"des Montagnes", "de la Côte",
]
const PALETTE := [
	Color("#1e6bff"), Color("#ff3d7f"), Color("#ffd23f"), Color("#3ddc84"), Color("#8b5cff"),
	Color("#ff8a2b"), Color("#17c3d6"), Color("#e8384f"), Color("#2e2a6b"), Color("#f2f2f2"),
	Color("#1b9e5a"), Color("#a3165b"),
]

## Compétitions dont le nom fictif est connu (maquettes validées).
const LIGUES := {
	"fr.1": "Ligue Hexagone", "es.1": "Liga Ibérica", "de.1": "Liga Germania", "it.1": "Serie Azzurra",
	"en.1": "Premier Albion", "pt.1": "Liga Lusitana", "nl.1": "Eredivisie Orange", "be.1": "Pro Ligue Belge",
	"br.1": "Série Samba", "ar.1": "Liga Pampa", "us.1": "Ligue des Étoiles", "mx.1": "Liga Azteca",
	"jp.1": "J-Ligue du Soleil", "tr.1": "Süper Bosphore", "sco.1": "Ligue des Highlands",
	"sa.1": "Ligue du Désert",
	"ucl": "Coupe des Étoiles", "uel": "Coupe Continentale", "uecl": "Coupe Horizon",
	"libertadores": "Copa Libertad", "sudamericana": "Copa del Sur", "caf-cl": "Coupe des Champions d'Afrique",
	"afc-cl": "Coupe des Champions d'Asie", "concacaf-cc": "Coupe des Champions Nord-Américains",
	"club-world-cup": "Mondial des Clubs", "world-cup": "Mondial des Nations", "euro": "Championnat des Nations d'Europe",
	"nations-league": "Ligue des Nations d'Europe", "copa-america": "Coupe des Amériques",
	"afcon": "Coupe des Nations d'Afrique", "friendlies": "Matchs amicaux de sélections",
}
const REGIONS_FR := {
	"Europe": "Europe", "South America": "Amérique du Sud", "North America": "Amérique du Nord",
	"Africa": "Afrique", "Asia": "Asie", "Oceania": "Océanie", "World": "Monde",
}

static var _surcharges: Dictionary = {}
static var _charge := false


static func _charger() -> void:
	if _charge:
		return
	_charge = true
	var f := FileAccess.open("res://data/clubs/noms_fictifs.json", FileAccess.READ)
	if f:
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_surcharges = d.get("clubs", {})
	# Un mod peut ajouter user://mods/noms_fictifs.json pour renommer d'autres clubs.
	var m := FileAccess.open("user://mods/noms_fictifs.json", FileAccess.READ)
	if m:
		var d2: Variant = JSON.parse_string(m.get_as_text())
		if d2 is Dictionary:
			_surcharges.merge(d2.get("clubs", {}), true)


static func graine(texte: String) -> int:
	# Hachage stable (identique sur toutes les machines et versions).
	var h := 2166136261
	for c in texte.to_utf8_buffer():
		h = ((h ^ c) * 16777619) & 0xFFFFFFFF
	return h


static func equipe(e: Dictionary, est_selection := false) -> Dictionary:
	## Renvoie {nom, sigle, c1, c2} pour une équipe du flux de données.
	_charger()
	var id := str(e.get("id", "?"))
	var g := graine(id)
	var c1: Color = PALETTE[g % PALETTE.size()]
	var c2: Color = PALETTE[(g / 7 + 3) % PALETTE.size()]
	if c2 == c1:
		c2 = Ui.BLANC
	var nom := ""
	if _surcharges.has(id):
		var s: Dictionary = _surcharges[id]
		nom = s.get("nom", "")
		if s.has("c1"):
			c1 = Color(s["c1"])
		if s.has("c2"):
			c2 = Color(s["c2"])
	elif est_selection:
		nom = Geo.nom_pays_fr(str(e.get("name", "")))
	if nom == "":
		nom = "%s %s" % [ANIMAUX[g % ANIMAUX.size()], QUALITES[(g / ANIMAUX.size()) % QUALITES.size()]]
	return {"nom": nom, "sigle": sigle(nom), "c1": c1, "c2": c2}


static func sigle(nom: String) -> String:
	var mots := nom.replace("'", " ").split(" ", false)
	var utiles: Array = []
	for m in mots:
		if m.length() > 2 and not m.to_lower() in ["des", "les", "del", "der", "the"]:
			utiles.append(m)
	if utiles.size() >= 2:
		return (utiles[0].left(1) + utiles[1].left(1)).to_upper()
	return nom.left(3).to_upper()


static func stade(e_domicile: Dictionary, nom_club: String) -> Dictionary:
	## Stade fictif du club qui reçoit. La clé sert aux tampons.
	_charger()
	var id := str(e_domicile.get("id", "?"))
	var nom := ""
	if _surcharges.has(id):
		nom = _surcharges[id].get("stade", "")
	if nom == "":
		var g := graine(id + "stade")
		var formes := ["Stade des %s", "Arène des %s", "Le Chaudron des %s", "Parc des %s", "Enceinte des %s"]
		nom = formes[g % formes.size()] % nom_club
	return {"cle": "stade:" + id, "nom": nom, "places": 12000 + (graine(id) % 70) * 1000}


static func competition(c: Dictionary) -> String:
	var id := str(c.get("id", ""))
	if LIGUES.has(id):
		return LIGUES[id]
	var info := Geo.info_competition(id)
	if info.has("pays"):
		return "D1 · " + Geo.nom_pays(info["pays"])
	var region: String = REGIONS_FR.get(info.get("region", "World"), "Monde")
	if info.get("type", "") == "international":
		return "Sélections · " + region
	return "Coupe continentale · " + region


static func est_selection(match: Dictionary) -> bool:
	var info := Geo.info_competition(str(match.get("competition", {}).get("id", "")))
	return info.get("type", "") == "international"
