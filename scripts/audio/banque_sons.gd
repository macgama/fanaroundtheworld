class_name BanqueSons
extends RefCounted
## Le catalogue des sons (data/audio/catalogue_sons.json), chargé une fois.
##
## Statique : le lecteur de chants, l'autoload Sons et les tests le lisent
## sans dépendre les uns des autres.

const CHEMIN := "res://data/audio/catalogue_sons.json"

static var _cat: Dictionary = {}
static var _flux: Dictionary = {}


static func catalogue() -> Dictionary:
	if _cat.is_empty():
		var f := FileAccess.open(CHEMIN, FileAccess.READ)
		if f == null:
			push_warning("BanqueSons : %s introuvable" % CHEMIN)  # sans_traduction
			return {}
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_cat = d
	return _cat


## La fiche d'un son. `id` peut nommer un groupe (« tambour ») : on tire
## alors un de ses sons au hasard, pour que deux frappes ne sonnent jamais
## tout à fait pareil.
static func fiche(id: String) -> Dictionary:
	var c := catalogue()
	var groupes: Dictionary = c.get("groupes", {})
	if groupes.has(id):
		var liste: Array = groupes[id]
		id = String(liste[randi() % liste.size()])
	var sons: Dictionary = c.get("sons", {})
	if sons.has(id):
		var f: Dictionary = sons[id].duplicate()
		f["id"] = id
		return f
	return {}


static func fiche_ambiance(id: String) -> Dictionary:
	return catalogue().get("ambiances", {}).get(id, {})


static func fiche_musique(id: String) -> Dictionary:
	return catalogue().get("musiques", {}).get(id, {})


## L'ambiance d'un lieu (« stade », « pub », « maison », « ecran_geant ») à une
## intensité de 0 à 2 : {id, volume_db}.
static func ambiance_du_lieu(lieu: String, intensite: int) -> Dictionary:
	var c := catalogue()
	var lieux: Dictionary = c.get("lieux", {})
	if not lieux.has(lieu):
		return {}
	var liste: Array = lieux[lieu]
	var i := clampi(intensite, 0, liste.size() - 1)
	var vols: Array = c.get("lieux_volume_db", {}).get(lieu, [])
	return {"id": String(liste[i]), "volume_db": float(vols[i]) if i < vols.size() else 0.0}


## Le groupe de sons qui joue une voix de chant (« T » -> « tambour »).
static func son_de_voix(voix: String) -> String:
	return String(catalogue().get("voix_des_chants", {}).get(voix, ""))


static func flux(chemin: String, boucle := false) -> AudioStream:
	if _flux.has(chemin):
		return _flux[chemin]
	if not ResourceLoader.exists(chemin):
		push_warning("BanqueSons : fichier absent %s" % chemin)  # sans_traduction
		return null
	var s: AudioStream = load(chemin)
	if boucle:
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		elif s is AudioStreamWAV:
			var w := s as AudioStreamWAV
			w.loop_mode = AudioStreamWAV.LOOP_FORWARD
			w.loop_end = int(w.get_length() * w.mix_rate)
	_flux[chemin] = s
	return s


## Le bus voulu, ou Master si la disposition des bus n'est pas chargée.
static func bus(nom: String) -> StringName:
	return StringName(nom) if AudioServer.get_bus_index(nom) >= 0 else &"Master"


## Tous les chemins de fichiers cités (pour les tests et le préchargement).
static func tous_les_fichiers() -> Array:
	var c := catalogue()
	var res: Array = []
	for cle in ["sons", "ambiances", "musiques"]:
		for id in c.get(cle, {}):
			res.append(String(c[cle][id]["fichier"]))
	return res
