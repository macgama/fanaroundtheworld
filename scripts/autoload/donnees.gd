extends Node
## Vrais matchs de foot (autoload « Donnees »).
##
## Lit les fichiers publiés par le relais macgama/fanaroundtheworld-data :
##  - index.json puis days/AAAA-MM-JJ.json : calendrier, de la veille à J+7 (toutes les 3 h) ;
##  - live.json : matchs en cours, relu chaque minute ;
##  - teams.json : clubs de chaque championnat (relu une fois par jour au plus),
##    pour choisir son club favori même s'il ne joue pas cette semaine.
## Un match a le même `id` partout : la version live remplace celle du calendrier.
## Tout est gardé en cache (user://cache) pour jouer hors ligne. Sans réseau ni
## cache, un petit jeu d'exemple (data/exemple) permet quand même de tester.

signal mis_a_jour

const URL_BASE := "https://macgama.github.io/fanaroundtheworld-data/"
const URL_LIVE := "https://fanaroundtheworld-live.gael-manigley.workers.dev/live.json"
const DOSSIER_CACHE := "user://cache/"
const PERIODE_LIVE := 60.0
const PERIODE_CALENDRIER := 30.0 * 60.0
const STATUTS_EN_JEU := ["LIVE", "HALFTIME"]
## Un match commencé depuis plus longtemps ne peut plus être en cours.
const DUREE_MAX_MATCH := 3 * 3600
## Le live est jugé à jour s'il a été relu il y a moins de 5 minutes.
const FRAICHEUR_LIVE := 5 * 60

var source := "aucune"          # "en ligne", "cache" ou "exemple"
var attribution := ""
var derniere_maj_live := 0.0     # heure unix de la dernière lecture réussie du live
var en_chargement := false
var hors_ligne := false

var _calendrier: Dictionary = {}  # id -> match (fichiers days/)
var _live: Dictionary = {}        # id -> match (live.json)
var _fusion: Array = []           # liste triée, recalculée à chaque mise à jour
var _fusion_par_id: Dictionary = {}
var _requetes_en_cours := 0
var _jours_recus: Dictionary = {}
var _equipes: Dictionary = {}     # id compétition -> [{id, name}] (teams.json)
const PERIODE_EQUIPES := 24 * 3600


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER_CACHE)
	_charger_cache()
	if _calendrier.is_empty():
		_charger_exemple()
	var t_live := Timer.new()
	t_live.wait_time = PERIODE_LIVE
	t_live.autostart = true
	t_live.timeout.connect(rafraichir_live)
	add_child(t_live)
	var t_cal := Timer.new()
	t_cal.wait_time = PERIODE_CALENDRIER
	t_cal.autostart = true
	t_cal.timeout.connect(rafraichir_calendrier)
	add_child(t_cal)
	if not OS.has_feature("hors_ligne") and not "--hors-ligne" in OS.get_cmdline_user_args():
		rafraichir_calendrier()
		rafraichir_live()
		rafraichir_equipes()


# ------------------------------------------------------------------ lecture

func matchs() -> Array:
	return _fusion


func match_par_id(id: String) -> Dictionary:
	return _fusion_par_id.get(id, {})


static func en_direct(m: Dictionary) -> bool:
	return str(m.get("status", "")) in STATUTS_EN_JEU


static func heure_unix(m: Dictionary) -> int:
	var s := str(m.get("kickoff_utc", ""))
	if s.length() < 19:
		return 0
	return int(Time.get_unix_time_from_datetime_string(s.left(19)))


static func score_texte(m: Dictionary) -> String:
	var sc: Variant = m.get("score", {}).get("current")
	if sc is Dictionary:
		return "%d – %d" % [int(sc.get("home", 0)), int(sc.get("away", 0))]
	return "– : –"


# ------------------------------------------------------------------ réseau

func rafraichir_calendrier() -> void:
	_requete(URL_BASE + "index.json", _sur_index)


func rafraichir_live() -> void:
	_requete(URL_LIVE + "?t=%d" % int(Time.get_unix_time_from_system() / 30), _sur_live)


func rafraichir_equipes() -> void:
	var t := FileAccess.get_modified_time(DOSSIER_CACHE + "teams.json")
	if t > 0 and Time.get_unix_time_from_system() - t < PERIODE_EQUIPES:
		return
	_requete(URL_BASE + "teams.json", _sur_equipes, true)


func _sur_equipes(d: Dictionary) -> void:
	_ecrire_cache("teams.json", d)
	_lire_equipes(d)
	mis_a_jour.emit()


func _lire_equipes(d: Variant) -> void:
	if d is Dictionary and d.get("competitions") is Dictionary:
		_equipes = d["competitions"]


## Clubs connus d'un pays : liste du relais + clubs vus dans les matchs.
## Renvoie [{id, name}] (name = vrai nom, jamais affiché : utiliser Fiction).
func clubs_du_pays(pays: String) -> Array:
	var vus: Dictionary = {}
	for comp_id in _equipes:
		if str(Geo.info_competition(comp_id).get("pays", "")) == pays:
			for e in _equipes[comp_id]:
				vus[str(e.get("id", ""))] = e
	for id in Geo.pays_des_equipes:
		if Geo.pays_des_equipes[id] == pays and not vus.has(id):
			vus[id] = {"id": id, "name": ""}
	vus.erase("")
	return vus.values()


## Pays qui ont au moins un club connu.
func pays_avec_clubs() -> Array:
	var p: Dictionary = {}
	for comp_id in _equipes:
		var k := str(Geo.info_competition(comp_id).get("pays", ""))
		if k != "" and not _equipes[comp_id].is_empty():
			p[k] = true
	for id in Geo.pays_des_equipes:
		p[Geo.pays_des_equipes[id]] = true
	return p.keys()


## Championnats nationaux connus : {id ligue: {titre (fictif), pays, clubs: [id]}}.
## Sert au carnet de voyage (tamponner tous les stades d'une ligue).
func championnats() -> Dictionary:
	var res: Dictionary = {}
	for comp_id in _equipes:
		var pays := str(Geo.info_competition(comp_id).get("pays", ""))
		if pays == "":
			continue
		var clubs: Array = []
		for e in _equipes[comp_id]:
			if str(e.get("id", "")) != "":
				clubs.append(str(e["id"]))
		res[comp_id] = {"titre": Fiction.competition({"id": comp_id}), "pays": pays, "clubs": clubs}
	return res


## Pour les tests : remplace la liste des clubs.
func injecter_equipes(d: Dictionary) -> void:
	_lire_equipes(d)


func _requete(url: String, rappel: Callable, discret := false) -> void:
	var r := HTTPRequest.new()
	r.timeout = 20.0
	add_child(r)
	_requetes_en_cours += 1
	en_chargement = true
	r.request_completed.connect(func(res: int, code: int, _h: PackedStringArray, corps: PackedByteArray):
		_requetes_en_cours -= 1
		en_chargement = _requetes_en_cours > 0
		r.queue_free()
		if res != HTTPRequest.RESULT_SUCCESS or code != 200:
			if discret:
				return  # fichier facultatif : ne change pas l'état « hors ligne »
			hors_ligne = true
			push_warning("Données : échec %s (résultat %d, code %d)" % [url, res, code])
			mis_a_jour.emit()
			return
		var d: Variant = JSON.parse_string(corps.get_string_from_utf8())
		if d is Dictionary:
			hors_ligne = false
			rappel.call(d)
	)
	var err := r.request(url, ["Accept: application/json"])
	if err != OK:
		_requetes_en_cours -= 1
		r.queue_free()


func _sur_index(d: Dictionary) -> void:
	attribution = str(d.get("attribution", ""))
	_ecrire_cache("index.json", d)
	_jours_recus.clear()
	var jours: Array = d.get("days", [])
	for j in jours:
		var chemin := str(j.get("path", ""))
		if chemin != "":
			_requete(URL_BASE + chemin, _sur_jour.bind(jours.size()))


func _sur_jour(d: Dictionary, attendus: int) -> void:
	var jour := str(d.get("day", ""))
	_jours_recus[jour] = d.get("matches", [])
	_ecrire_cache("jour-%s.json" % jour, d)
	if _jours_recus.size() >= attendus:
		# Tous les jours sont arrivés : on remplace le calendrier d'un coup.
		_calendrier.clear()
		for liste in _jours_recus.values():
			for m in liste:
				_calendrier[str(m["id"])] = m
		source = "en ligne"
		_nettoyer_cache()
		_fusionner()


func _sur_live(d: Dictionary) -> void:
	_live.clear()
	for m in d.get("matches", []):
		_live[str(m["id"])] = m
	derniere_maj_live = Time.get_unix_time_from_system()
	_ecrire_cache("live.json", d)
	_fusionner()


func _fusionner() -> void:
	var tous: Dictionary = {}
	var maintenant := int(Time.get_unix_time_from_system())
	var live_a_jour := maintenant - derniere_maj_live < FRAICHEUR_LIVE
	for id in _calendrier:
		tous[id] = _corriger_statut(_calendrier[id], live_a_jour, maintenant)
	for id in _live:
		# Un live.json resté en cache (hors ligne) vieillit comme le calendrier.
		tous[id] = _live[id] if live_a_jour else _corriger_statut(_live[id], false, maintenant)
	_fusion_par_id = tous
	_fusion = tous.values()
	# Le championnat de chaque club donne son pays (utile pour les coupes d'Europe…).
	for m in _fusion:
		var info := Geo.info_competition(str(m.get("competition", {}).get("id", "")))
		if info.has("pays"):
			Geo.pays_des_equipes[str(m.get("home", {}).get("id", ""))] = info["pays"]
			Geo.pays_des_equipes[str(m.get("away", {}).get("id", ""))] = info["pays"]
	_fusion.sort_custom(func(a, b): return heure_unix(a) < heure_unix(b))
	mis_a_jour.emit()


static func _corriger_statut(m: Dictionary, live_a_jour: bool, maintenant: int) -> Dictionary:
	## Le calendrier n'est publié que toutes les 3 h : il peut encore dire « en direct »
	## (ou « à venir ») pour un match fini depuis. Le live fait foi pour les matchs en cours.
	var s := str(m.get("status", ""))
	var t := heure_unix(m)
	var trop_vieux := t > 0 and maintenant - t > DUREE_MAX_MATCH
	if (s in STATUTS_EN_JEU and (live_a_jour or trop_vieux)) or (s == "SCHEDULED" and trop_vieux):
		var c := m.duplicate()
		c["status"] = "UNKNOWN"
		return c
	return m


# ------------------------------------------------------------------ cache

func _ecrire_cache(nom: String, d: Dictionary) -> void:
	var f := FileAccess.open(DOSSIER_CACHE + nom, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _lire_json(chemin: String) -> Variant:
	var f := FileAccess.open(chemin, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


func _charger_cache() -> void:
	var idx: Variant = _lire_json(DOSSIER_CACHE + "index.json")
	if idx is Dictionary:
		attribution = str(idx.get("attribution", ""))
	var dir := DirAccess.open(DOSSIER_CACHE)
	if dir == null:
		return
	for nom in dir.get_files():
		if nom.begins_with("jour-"):
			var d: Variant = _lire_json(DOSSIER_CACHE + nom)
			if d is Dictionary:
				for m in d.get("matches", []):
					_calendrier[str(m["id"])] = m
	_lire_equipes(_lire_json(DOSSIER_CACHE + "teams.json"))
	var live: Variant = _lire_json(DOSSIER_CACHE + "live.json")
	if live is Dictionary:
		for m in live.get("matches", []):
			_live[str(m["id"])] = m
	if not _calendrier.is_empty():
		source = "cache"
		_fusionner()


func _nettoyer_cache() -> void:
	# Garde seulement les jours encore publiés par le relais.
	var dir := DirAccess.open(DOSSIER_CACHE)
	if dir == null:
		return
	for nom in dir.get_files():
		if nom.begins_with("jour-") and not nom.trim_prefix("jour-").trim_suffix(".json") in _jours_recus:
			dir.remove(nom)


func _charger_exemple() -> void:
	## Matchs d'exemple recalés sur l'heure actuelle (aucun réseau ni cache).
	var d: Variant = _lire_json("res://data/exemple/matchs.json")
	if not d is Dictionary:
		return
	var maintenant := int(Time.get_unix_time_from_system())
	for m in d.get("matches", []):
		var t := maintenant + int(float(m.get("decalage_h", 0)) * 3600.0)
		t -= t % 900  # coups d'envoi au quart d'heure
		m["kickoff_utc"] = Time.get_datetime_string_from_unix_time(t) + ".000Z"
		_calendrier[str(m["id"])] = m
	attribution = str(d.get("attribution", ""))
	source = "exemple"
	_fusionner()


## Pour les tests : remplace le live par un dictionnaire donné.
func injecter_live(d: Dictionary) -> void:
	_sur_live(d)
