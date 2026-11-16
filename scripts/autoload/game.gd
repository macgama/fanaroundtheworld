extends Node
## État global du jeu, chargé automatiquement (autoload « Game »).
## Contient le fan club du joueur, sa position, ses tampons de stades,
## sa tribune de FANZZY et la navigation entre les écrans.

signal pronostics_resolus(liste: Array)
## Une équipe favorite a gagné des points de popularité (pour les petites annonces).
signal popularite_gagnee(cle: String, points: int, raison: String)
## Des missions du jour ou de la semaine viennent d'être terminées.
signal missions_terminees(liste: Array)

const VERSION := "0.3.0"
const CHEMIN_SAUVEGARDE := "user://sauvegarde.json"

const SCENE_TITRE := "res://scenes/main/main.tscn"
const SCENE_CARTE := "res://scenes/carte/carte.tscn"
const SCENE_VOYAGE := "res://scenes/voyage/voyage.tscn"
const SCENE_TRIBUNE := "res://scenes/tribune/tribune.tscn"
const SCENE_DUEL := "res://scenes/duel/duel.tscn"
const SCENE_ARENE := "res://scenes/arene/arene.tscn"
const SCENE_POUSSEE := "res://scenes/poussee/poussee.tscn"
const SCENE_BUVETTE := "res://scenes/buvette/buvette.tscn"
const SCENE_BOULOTS := "res://scenes/boulots/boulots.tscn"
const SCENE_SPEAKER := "res://scenes/speaker/speaker.tscn"
const SCENE_TIFO := "res://scenes/tifo/tifo.tscn"
const SCENE_CLUB := "res://scenes/club/club.tscn"
const SCENE_CREATION_CLUB := "res://scenes/club/creation_club.tscn"
const SCENE_PRONOS := "res://scenes/pronostics/pronostics.tscn"
const SCENE_FAVORIS := "res://scenes/favoris/favoris.tscn"
const SCENE_SALON := "res://scenes/salon/salon.tscn"
const SCENE_MISSIONS := "res://scenes/missions/missions.tscn"
const SCENE_COLLECTION := "res://scenes/collection/collection.tscn"
const SCENE_CLASSEMENT := "res://scenes/classement/classement.tscn"

## Paramètres passés d'un écran à l'autre (match choisi, camp supporté…).
var params: Dictionary = {}

# --- Fan club du joueur (sauvegardé) ---
var fan_club_nom := "Ultras du Canal"
var xp := 0
var position_club := {"nom": "Paris", "lat": 48.86, "lon": 2.35}
var tampons: Dictionary = {}       # clé stade -> {nom, ville, date, match}
var equipe: Array = []             # 3 identifiants de FANZZY (chant, tifo, ola)
var skins: Dictionary = {}         # id FANZZY -> id du skin choisi (cosmétique)
var duels_gagnes := 0
var duels_joues := 0
## Jetons : gagnés en jouant, dépensés en billets et trajets (jamais pour des skins).
var jetons := 150
## Petit boulot à la buvette : meilleure paye et services faits aujourd'hui.
var buvette_record := 0
var buvette_jour := ""
var buvette_services := 0
## Autres petits boulots (voir ListeBoulots) : id → {record, jour, services}.
var boulots: Dictionary = {}
## Membres, local et caisse du fan club (règles dans FanClub).
var club: Dictionary = FanClub.vide()
## Pronostics sans mise (voir scripts/jeu/pronostics.gd).
var pronos: Dictionary = {}        # id du match -> pronostic en attente
var pronos_finis: Array = []       # derniers pronostics résolus (les plus récents d'abord)
var serie_pronos := 0              # bons résultats d'affilée
var meilleure_serie := 0
const MAX_HISTORIQUE_PRONOS := 40
## Équipes favorites (un club par pays + une sélection) et popularité (voir Supporters).
var supporters: Dictionary = Supporters.vide()
## Missions du jour et de la semaine (voir Missions) et XP du PASS saisonnier.
var missions: Dictionary = Missions.vide()
var xp_pass := 0
## Carnet de voyage et album des FANZZY : primes réclamées, FANZZY et skins vus en duel (voir Collection).
var collection: Dictionary = Collection.vide()
## Duels joués par match aujourd'hui (id -> {jour, n}) : rejouer le même match rapporte de moins en moins.
var duels_par_match: Dictionary = {}
## Part des Jetons selon le rang du duel sur ce match dans la journée : 100 %, 50 %, 25 %, puis rien.
const RENDEMENT_REJEU := [1.0, 0.5, 0.25]
## Événements autour des vrais matchs (voir Evenements) : primes déjà gagnées, par match.
var evenements: Dictionary = {"primes": {}}
## Matchs du calendrier avec un événement en cours ou à venir (recalculé à chaque mise à jour).
var nb_evenements := 0

## Où suivre le match. Au stade : billet + trajet, tampon du stade, plus de Jetons.
const MODES_SUIVI := {
	"stade": {"titre": "Au stade", "texte": "Billet + trajet · tampon du stade", "gain": 1.5, "billet": 20},
	"ecran": {"titre": "Écran géant", "texte": "Fan zone de la ville", "gain": 1.2, "billet": 8},
	"pub": {"titre": "Au pub", "texte": "Avec les supporters du coin", "gain": 1.0, "billet": 4},
	"maison": {"titre": "À la maison", "texte": "Gratuit, entre amis", "gain": 0.6, "billet": 0},
}
const ORDRE_MODES := ["stade", "ecran", "pub", "maison"]

# --- Catalogue FANZZY (échantillon du prototype) ---
var familles: Dictionary = {}
var series_fanzzy: Dictionary = {}  # id de série -> {nom, ligne, couleur}
var fanzzy: Array = []
var _fanzzy_par_id: Dictionary = {}

## Les trois postes de la tribune et les familles qui peuvent les tenir.
const POSTES := {
	"chant": {"titre": "Chant", "familles": ["voix", "perc"], "touche": "ESPACE"},
	"tifo": {"titre": "Tifo", "familles": ["tifo", "fide"], "touche": "T"},
	"ola": {"titre": "Ola", "familles": ["pyro", "depl"], "touche": "O"},
}
const ORDRE_POSTES := ["chant", "tifo", "ola"]


func _ready() -> void:
	get_tree().root.theme = Ui.creer_theme()
	_charger_fanzzy()
	charger()
	if equipe.size() != 3:
		equipe = equipe_par_defaut()
	_brancher_pronostics.call_deferred()
	_outils_de_test()


## Options de ligne de commande pour les tests automatiques (après « -- ») :
##   --scene=carte|voyage|tribune|duel|arene|poussee|buvette|boulots|tifo   ouvre directement un écran
##   --capture=chemin.png --apres=3      enregistre une capture puis quitte
func _outils_de_test() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else ""
	if args.has("scene"):
		var p := {}
		if args.has("pays"):
			p = {"niveau": "pays", "pays": args["pays"], "continent": "Europe"}
		if args.has("continent"):
			p = {"niveau": "continent", "continent": args["continent"]}
		if args.has("match"):
			p = {"match_id": args["match"], "camp": "home", "mode": args.get("mode", "stade"), "cout": 0}
			if args.has("auto"):
				p["auto"] = true  # Arène / Poussée : ton camp joue tout seul (démo)
		var scenes := {"carte": SCENE_CARTE, "voyage": SCENE_VOYAGE, "tribune": SCENE_TRIBUNE, "duel": SCENE_DUEL,
			"arene": SCENE_ARENE, "poussee": SCENE_POUSSEE,
			"pronos": SCENE_PRONOS, "missions": SCENE_MISSIONS, "favoris": SCENE_FAVORIS, "club": SCENE_CLUB, "creation": SCENE_CREATION_CLUB, "buvette": SCENE_BUVETTE, "boulots": SCENE_BOULOTS, "speaker": SCENE_SPEAKER, "tifo": SCENE_TIFO,
			"salon": SCENE_SALON, "collection": SCENE_COLLECTION, "classement": SCENE_CLASSEMENT}
		for b in ListeBoulots.LISTE:
			scenes[b["id"]] = b["scene"]  # chaque petit boulot : --scene=<id>
		if args.has("onglet"):
			p["onglet"] = args["onglet"]  # collection : « carnet » ou « album »
		if args.has("salon"):
			p["salon"] = args["salon"]  # test en ligne : « hote » ou l'adresse de l'hôte
			if args.has("auto"):
				p["auto"] = true
			p["jeu"] = args.get("jeu", "duel")  # jeu lancé tout seul par l'hôte en test
		aller.call_deferred(scenes.get(args["scene"], SCENE_TITRE), p)
	if args.has("vitesse"):
		Engine.time_scale = float(args["vitesse"])  # accélère une partie de démo
	if args.has("capture"):
		await get_tree().create_timer(float(args.get("apres", "3"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["capture"])
		get_tree().quit()


# ---------------------------------------------------------------- navigation

func aller(scene: String, p: Dictionary = {}) -> void:
	params = p
	get_tree().change_scene_to_file(scene)


# ---------------------------------------------------------------- progression

func niveau() -> int:
	return 1 + xp / 200


func xp_dans_niveau() -> float:
	return float(xp % 200) / 200.0


func ajouter_xp(n: int) -> void:
	xp += n
	sauver()


func gain_suivi(mode: String) -> float:
	return float(MODES_SUIVI.get(mode, {}).get("gain", 1.0))


func cout_suivi(mode: String, distance_km: float) -> int:
	var c: int = MODES_SUIVI[mode]["billet"]
	if mode == "stade":
		c += cout_trajet(distance_km)
	return c


func cout_trajet(distance_km: float) -> int:
	if distance_km < 30.0:
		return 0
	return clampi(int(round(distance_km / 120.0)) + 5, 5, 80)


func depenser(n: int) -> bool:
	if n > jetons:
		return false
	jetons -= n
	sauver()
	return true


## Note un duel joué sur ce match et renvoie la part des Jetons à verser :
## 100 % la 1re fois du jour, 50 % la 2e, 25 % la 3e, puis 0 (l'XP ne change pas).
func noter_duel_match(match_id: String) -> float:
	if match_id == "":
		return 1.0
	var jour := Time.get_date_string_from_system()
	var e: Variant = duels_par_match.get(match_id, {})
	var n := 1
	if e is Dictionary and str(e.get("jour", "")) == jour:
		n = int(e.get("n", 0)) + 1
	duels_par_match.erase(match_id)
	duels_par_match[match_id] = {"jour": jour, "n": n}  # en dernier : les plus anciens partent d'abord
	while duels_par_match.size() > 60:
		duels_par_match.erase(duels_par_match.keys()[0])
	return RENDEMENT_REJEU[n - 1] if n <= RENDEMENT_REJEU.size() else 0.0


## Libellé de la ligne « Jetons gagnés » quand le match a déjà été joué aujourd'hui.
static func libelle_rejeu(part: float) -> String:
	if part >= 1.0:
		return "Jetons gagnés"
	if part <= 0.0:
		return "Jetons gagnés (match déjà joué 3 fois aujourd'hui)"
	return "Jetons gagnés (match rejoué : %d %%)" % int(round(part * 100.0))


func gagner_jetons(n: int) -> void:
	jetons += n
	sauver()


## Services de buvette déjà faits aujourd'hui (date du système).
func services_buvette_du_jour() -> int:
	return buvette_services if buvette_jour == Time.get_date_string_from_system() else 0


## Note la fin d'un service de buvette et sa paye.
func finir_service_buvette(paye: int) -> void:
	var jour := Time.get_date_string_from_system()
	buvette_services = services_buvette_du_jour() + 1
	buvette_jour = jour
	buvette_record = maxi(buvette_record, paye)
	noter_mission("buvette")
	noter_mission("boulot", "buvette")
	gagner_jetons(paye)


## Parties d'un petit boulot déjà faites aujourd'hui (date du système).
func services_boulot_du_jour(id: String) -> int:
	if id == "buvette":
		return services_buvette_du_jour()
	var b: Dictionary = boulots.get(id, {})
	return int(b.get("services", 0)) if str(b.get("jour", "")) == Time.get_date_string_from_system() else 0


## Meilleure paye obtenue à un petit boulot.
func record_boulot(id: String) -> int:
	if id == "buvette":
		return buvette_record
	return int(boulots.get(id, {}).get("record", 0))


## Note la fin d'une partie d'un petit boulot, verse la paye et compte la
## mission « <id> » et la mission générique « boulot » (clé = id).
func finir_boulot(id: String, paye: int) -> void:
	if id == "buvette":
		finir_service_buvette(paye)
		return
	var n := services_boulot_du_jour(id) + 1
	boulots[id] = {"record": maxi(record_boulot(id), paye), "jour": Time.get_date_string_from_system(), "services": n}
	noter_mission(id)
	noter_mission("boulot", id)
	gagner_jetons(paye)


func a_tampon(cle: String) -> bool:
	return tampons.has(cle)


func tamponner(cle: String, info: Dictionary) -> bool:
	## Ajoute le tampon du stade. Renvoie true si c'est une première visite.
	if tampons.has(cle):
		return false
	tampons[cle] = info
	noter_mission("nouveau_stade", cle)
	sauver()
	return true


# ---------------------------------------------------------------- fan club

static func maintenant() -> int:
	return int(Time.get_unix_time_from_system())


func club_cree() -> bool:
	return bool(club.get("cree", false))


func creer_club(nom: String, c1: String, c2: String) -> void:
	## Les trois FANZZY de la tribune sont les membres fondateurs.
	fan_club_nom = nom.strip_edges().substr(0, 28)
	var fondateurs := equipe.filter(func(id): return not fanzzy_par_id(str(id)).is_empty())
	club = FanClub.nouveau(fondateurs, c1, c2, maintenant())
	sauver()


func couleurs_club() -> Array:
	var c: Array = club.get("couleurs", [FanClub.COULEURS[0], FanClub.COULEURS[7]])
	return [Color(c[0]), Color(c[1])]


func recruter(id: String) -> bool:
	var ok := FanClub.recruter(club, id, niveau(), maintenant())
	if ok:
		sauver()
	return ok


func renvoyer(id: String) -> bool:
	var ok := FanClub.renvoyer(club, id, maintenant())
	if ok:
		sauver()
	return ok


func recolter_caisse() -> int:
	var n := FanClub.recolter(club, maintenant())
	_annoncer(Supporters.noter_club(supporters, n, maintenant()), "club")
	if n > 0:
		noter_mission("recolte")
	gagner_jetons(n)
	return n


func vendre_echarpes() -> int:
	var n := FanClub.vendre_echarpes(club, maintenant())
	gagner_jetons(n)
	return n


func ameliorer_local(type: String) -> bool:
	var cout := FanClub.cout_amelioration(club, type)
	if cout < 0 or not depenser(cout):
		return false
	FanClub.ameliorer(club, type, maintenant())
	sauver()
	return true


# ---------------------------------------------------------------- pronostics

func _brancher_pronostics() -> void:
	Donnees.mis_a_jour.connect(resoudre_pronostics)
	Donnees.mis_a_jour.connect(_compter_evenements)
	resoudre_pronostics()
	_compter_evenements()


func prono_de(match_id: String) -> Dictionary:
	if pronos.has(match_id):
		return pronos[match_id]
	for p in pronos_finis:
		if p["match_id"] == match_id:
			return p
	return {}


func peut_pronostiquer(m: Dictionary) -> String:
	## "" si c'est possible, sinon la raison à afficher.
	var maintenant := int(Time.get_unix_time_from_system())
	if not Pronostics.ouvert(m, maintenant):
		return "Pronostics fermés : le match a commencé"
	if not pronos.has(str(m.get("id", ""))) and pronos.size() >= Pronostics.MAX_EN_ATTENTE:
		return "%d pronostics en attente au maximum" % Pronostics.MAX_EN_ATTENTE
	return ""


func pronostiquer(m: Dictionary, dom: int, ext: int, premier_but: String) -> bool:
	## Gratuit : aucun Jeton n'est dépensé. Modifiable jusqu'au coup d'envoi.
	if peut_pronostiquer(m) != "":
		return false
	var maintenant := int(Time.get_unix_time_from_system())
	var nouveau := not pronos.has(str(m["id"]))
	pronos[str(m["id"])] = Pronostics.creer(m, dom, ext, premier_but, maintenant)
	if nouveau:
		noter_mission("prono")
	sauver()
	return true


## Appelé à la fin de chaque duel (ambiance, Arène, Poussée, en ligne ou non).
func noter_duel_club() -> void:
	if club_cree():
		FanClub.noter_duel(club, maintenant())
	noter_duel_collection()


func annuler_prono(match_id: String) -> void:
	var m := Donnees.match_par_id(match_id)
	if pronos.has(match_id) and (m.is_empty() or Pronostics.ouvert(m, int(Time.get_unix_time_from_system()))):
		pronos.erase(match_id)
		sauver()


func resoudre_pronostics() -> void:
	if pronos.is_empty():
		return
	var maintenant := int(Time.get_unix_time_from_system())
	var resolus: Array = []
	var change := false
	# Du plus ancien au plus récent coup d'envoi, pour que la série suive l'ordre des matchs.
	var ids := pronos.keys()
	ids.sort_custom(func(a, b): return int(pronos[a]["kickoff"]) < int(pronos[b]["kickoff"]))
	for id in ids:
		var p: Dictionary = pronos[id]
		var m := Donnees.match_par_id(id)
		if not m.is_empty():
			var avant: Variant = p.get("vu")
			Pronostics.observer(p, m)
			change = change or p.get("vu") != avant
		var r := Pronostics.resoudre(p, m, serie_pronos, maintenant)
		if not r["fini"]:
			continue
		p.merge(r, true)
		p.erase("fini")
		p["resolu"] = maintenant
		serie_pronos = int(r["serie"])
		meilleure_serie = maxi(meilleure_serie, serie_pronos)
		jetons += int(r["jetons"])
		var pop := Supporters.noter_prono(supporters, p, r, maintenant)
		p["popularite"] = pop
		_annoncer(pop, "prono")
		if bool(r.get("resultat_ok", false)):
			noter_mission("prono_bon")
		pronos.erase(id)
		pronos_finis.push_front(p)
		resolus.append(p)
	if resolus.is_empty():
		if change:
			sauver()
		return
	pronos_finis = pronos_finis.slice(0, MAX_HISTORIQUE_PRONOS)
	sauver()
	pronostics_resolus.emit(resolus)


# ---------------------------------------------------------------- équipes favorites

func choisir_club_favori(pays: String, id: String) -> bool:
	var ok := Supporters.choisir_club(supporters, pays, id, maintenant())
	if ok:
		sauver()
	return ok


func retirer_club_favori(pays: String) -> bool:
	var ok := Supporters.retirer_club(supporters, pays, maintenant())
	if ok:
		sauver()
	return ok


func choisir_nation_favorite(pays: String) -> bool:
	var ok := Supporters.choisir_nation(supporters, pays, maintenant())
	if ok:
		sauver()
	return ok


## Camps du match tenus par une de tes équipes favorites.
func camps_favoris(m: Dictionary) -> Array:
	return Supporters.camps_favoris(supporters, m)


## Fin d'un duel (tous modes) : points pour l'équipe soutenue si c'est un favori.
func noter_duel_favori(m: Dictionary, camp: String, gagne: bool, mode_suivi: String) -> int:
	var n := Supporters.noter_duel(supporters, m, camp, gagne, gain_suivi(mode_suivi), maintenant())
	_annoncer(n, "duel", Supporters.cle_equipe(m.get(camp, {}), Fiction.est_selection(m)))
	# Appelée à la fin de chaque partie, dans les trois modes : on en profite pour les missions.
	var jeu := _jeu_en_cours()
	noter_mission("duel_joue", jeu)
	if gagne:
		noter_mission("duel_gagne", jeu)
	if n > 0:
		noter_mission("favori")
	return n


## Départ pour suivre un match (stade, écran, pub, maison).
func noter_suivi_favori(m: Dictionary, camp: String, mode_suivi: String) -> int:
	var n := Supporters.noter_suivi(supporters, m, camp, mode_suivi, maintenant())
	_annoncer(n, "suivi", Supporters.cle_equipe(m.get(camp, {}), Fiction.est_selection(m)))
	# Un même match suivi deux fois ne compte qu'une fois pour « Suis 3 matchs ».
	var id := str(m.get("id", ""))
	if id != "" and not id in missions["matchs_suivis"]:
		missions["matchs_suivis"].append(id)
		missions["matchs_suivis"] = missions["matchs_suivis"].slice(-60)
		noter_mission("suivre", mode_suivi)
		noter_mission("suivre_pays", str(Geo.lieu_match(m).get("pays", "")))
	if n > 0:
		noter_mission("favori")
	return n


func _annoncer(points: int, raison: String, cle := "") -> void:
	if points > 0:
		sauver()
		popularite_gagnee.emit(cle, points, raison)


# ---------------------------------------------------------------- missions

func _ctx_missions() -> Dictionary:
	return {"club": club_cree(), "favoris": not Supporters.cles_favorites(supporters).is_empty(),
		"evenements": nb_evenements > 0}


static func heure_locale() -> int:
	return maintenant() + FicheMatch.decalage_local()


## Duel d'ambiance, Arène ou Poussée, d'après l'écran ouvert.
func _jeu_en_cours() -> String:
	var sc := get_tree().current_scene
	var chemin := sc.scene_file_path if sc else ""
	for jeu in ["arene", "poussee", "duel"]:
		if chemin.ends_with("/%s.tscn" % jeu):
			return jeu
	return "duel"


## Renouvelle les missions si besoin ; verse les récompenses oubliées de la veille.
func actualiser_missions() -> Dictionary:
	var verse := Missions.actualiser(missions, heure_locale(), _ctx_missions())
	if int(verse["jetons"]) > 0 or int(verse["xp_pass"]) > 0:
		jetons += int(verse["jetons"])
		xp_pass += int(verse["xp_pass"])
		sauver()
	return verse


func noter_mission(evt: String, cle := "", n := 1) -> void:
	actualiser_missions()
	var finies := Missions.noter(missions, evt, cle, n)
	if finies.is_empty():
		return
	sauver()
	missions_terminees.emit(finies)
	_annonce_missions(finies)


func recuperer_mission(periode: String, index: int) -> Dictionary:
	actualiser_missions()
	var g := Missions.recuperer(missions, periode, index)
	if not g.is_empty():
		jetons += int(g["jetons"])
		xp_pass += int(g["xp_pass"])
		sauver()
	return g


func changer_mission(index: int) -> bool:
	var ok := Missions.changer(missions, index, _ctx_missions())
	if ok:
		sauver()
	return ok


## Petite annonce par-dessus n'importe quel écran quand une mission est terminée.
func _annonce_missions(finies: Array) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var couche := CanvasLayer.new()
	couche.layer = 50
	add_child(couche)
	var toast := Ui.panneau(Ui.VERT, 20, 5)
	var h := Ui.hbox(10)
	h.add_child(Ui.icone("cible", 34))
	var txt := "Mission terminée : %s" % finies[0]["titre"] if finies.size() == 1 else "%d missions terminées !" % finies.size()
	var l := Ui.label(txt + " · à récupérer dans Missions", 22, Ui.CONTOUR, true)
	h.add_child(l)
	toast.add_child(h)
	toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.grow_vertical = Control.GROW_DIRECTION_BEGIN
	toast.offset_bottom = -130
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(toast)
	Ui.pop(toast, 1.1)
	var tw := toast.create_tween()
	tw.tween_interval(3.5)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(couche.queue_free)


# ---------------------------------------------------------------- événements

## Derby, finale, Grand Choc… du match, ou {} (voir Evenements.detecter).
func evenement_de(m: Dictionary) -> Dictionary:
	Fiction._charger()
	return Evenements.detecter(m, Donnees.villes(), Geo.pays_des_equipes, Fiction._surcharges)


## "a_venir", "actif" (bonus en cours) ou "fini".
func etat_evenement(m: Dictionary) -> String:
	return Evenements.etat(Donnees.heure_unix(m), maintenant())


func prime_evenement_gagnee(match_id: String) -> bool:
	return evenements.get("primes", {}).has(match_id)


func _compter_evenements() -> void:
	var n := 0
	for m in Donnees.matchs():
		if etat_evenement(m) != "fini" and not evenement_de(m).is_empty():
			n += 1
	nb_evenements = n


## Fin d'un duel sur un match spécial : Jetons en plus (multiplicateur de
## l'événement) et, au premier duel sur ce match, la prime fixe (XP de PASS + Jetons).
## Renvoie {} hors événement, sinon {titre, texte_mult, bonus, prime_xp, prime_jetons}.
func recompense_evenement(m: Dictionary, jetons_duel: int) -> Dictionary:
	var ev := evenement_de(m)
	if ev.is_empty() or etat_evenement(m) != "actif":
		return {}
	var id := str(m.get("id", ""))
	var r := {
		"type": ev["type"], "titre": ev["titre"], "texte_mult": Evenements.texte_mult(ev),
		"bonus": Evenements.bonus_jetons(ev, jetons_duel), "prime_xp": 0, "prime_jetons": 0,
	}
	var primes: Dictionary = evenements.get("primes", {})
	if id != "" and not primes.has(id):
		primes[id] = maintenant()
		r["prime_xp"] = int(ev["xp_pass"])
		r["prime_jetons"] = int(ev["jetons"])
	Evenements.nettoyer_primes(primes, maintenant())
	evenements["primes"] = primes
	jetons += int(r["bonus"]) + int(r["prime_jetons"])
	xp_pass += int(r["prime_xp"])
	noter_mission("evenement", str(ev["type"]))
	sauver()
	return r


# ---------------------------------------------------------------- collection

## Les FANZZY de la tribune (et leurs skins) entrent dans l'album.
func noter_duel_collection() -> Array:
	var ids := equipe.filter(func(id): return not fanzzy_par_id(str(id)).is_empty())
	var nouveaux := Collection.noter_duel(collection, ids, ids.map(func(id): return skin_de(str(id))), Time.get_date_string_from_system())
	sauver()
	return nouveaux


func lieux_visites() -> Dictionary:
	return Collection.lieux_visites(tampons, Geo.pays_des_equipes, Geo.continent_de)


func series_carnet() -> Array:
	return Collection.series_carnet(collection, tampons, lieux_visites(), Donnees.championnats())


func series_album() -> Array:
	return Collection.series_album(collection, fanzzy, familles, series_fanzzy)


## Nombre de primes de collection prêtes à réclamer (pastille sur la carte).
func primes_pretes() -> int:
	return Collection.pretes(series_carnet()).size() + Collection.pretes(series_album()).size()


## Réclame la prime d'une série complète. Renvoie les Jetons gagnés (0 sinon).
func reclamer_prime(id: String) -> int:
	for s in series_carnet() + series_album():
		if s["id"] == id:
			var n := Collection.reclamer(collection, s, Time.get_date_string_from_system())
			if n > 0:
				gagner_jetons(n)
			return n
	return 0


# ---------------------------------------------------------------- FANZZY

func _charger_fanzzy() -> void:
	var f := FileAccess.open("res://assets/fanzzy/fanzzy.json", FileAccess.READ)
	if f == null:
		push_error("Catalogue FANZZY introuvable")
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		familles = d.get("familles", {})
		series_fanzzy = d.get("series", {})
		fanzzy = d.get("fanzzy", [])
		for z in fanzzy:
			_fanzzy_par_id[z["id"]] = z


func fanzzy_par_id(id: String) -> Dictionary:
	return _fanzzy_par_id.get(id, {})


func fanzzy_pour_poste(poste: String) -> Array:
	var fams: Array = POSTES[poste]["familles"]
	return fanzzy.filter(func(z): return z["famille"] in fams)


func equipe_par_defaut() -> Array:
	var e: Array = []
	for p in ORDRE_POSTES:
		var liste := fanzzy_pour_poste(p)
		e.append(liste[0]["id"] if liste.size() > 0 else "")
	return e


func skin_de(id: String) -> String:
	return skins.get(id, id)


func texture_fanzzy(id: String, buste := false) -> Texture2D:
	var chemin := "res://assets/fanzzy/sprites/%s%s.webp" % [skin_de(id), "-buste" if buste else ""]
	if ResourceLoader.exists(chemin):
		return load(chemin)
	return null


func couleur_famille(fam: String) -> Color:
	return Color(familles.get(fam, {}).get("couleur", "#888888"))


func nom_famille(fam: String) -> String:
	return familles.get(fam, {}).get("nom", fam)


# ---------------------------------------------------------------- sauvegarde

func sauver() -> void:
	var d := {
		"version": VERSION,
		"fan_club_nom": fan_club_nom,
		"xp": xp,
		"position": position_club,
		"tampons": tampons,
		"equipe": equipe,
		"skins": skins,
		"duels_gagnes": duels_gagnes,
		"duels_joues": duels_joues,
		"jetons": jetons,
		"buvette": {"record": buvette_record, "jour": buvette_jour, "services": buvette_services},
		"boulots": boulots,
		"club": club,
		"pronos": pronos,
		"pronos_finis": pronos_finis,
		"serie_pronos": serie_pronos,
		"meilleure_serie": meilleure_serie,
		"supporters": supporters,
		"missions": missions,
		"xp_pass": xp_pass,
		"collection": collection,
		"duels_par_match": duels_par_match,
		"evenements": evenements,
	}
	var f := FileAccess.open(CHEMIN_SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d, "\t"))


func charger() -> void:
	if not FileAccess.file_exists(CHEMIN_SAUVEGARDE):
		return
	var f := FileAccess.open(CHEMIN_SAUVEGARDE, FileAccess.READ)
	var d: Variant = JSON.parse_string(f.get_as_text())
	if not d is Dictionary:
		return
	fan_club_nom = d.get("fan_club_nom", fan_club_nom)
	xp = int(d.get("xp", 0))
	position_club = d.get("position", position_club)
	tampons = d.get("tampons", {})
	equipe = d.get("equipe", [])
	skins = d.get("skins", {})
	duels_gagnes = int(d.get("duels_gagnes", 0))
	duels_joues = int(d.get("duels_joues", 0))
	jetons = int(d.get("jetons", jetons))
	var bv: Variant = d.get("buvette", {})
	if bv is Dictionary:
		buvette_record = int(bv.get("record", 0))
		buvette_jour = str(bv.get("jour", ""))
		buvette_services = int(bv.get("services", 0))
	var bo: Variant = d.get("boulots", {})
	boulots = bo if bo is Dictionary else {}
	club = FanClub.reparer(d.get("club", null))
	club["membres"] = club["membres"].filter(func(id): return not fanzzy_par_id(str(id)).is_empty())
	pronos = d.get("pronos", {})
	pronos_finis = d.get("pronos_finis", [])
	serie_pronos = int(d.get("serie_pronos", 0))
	meilleure_serie = int(d.get("meilleure_serie", 0))
	supporters = Supporters.reparer(d.get("supporters", null))
	missions = Missions.reparer(d.get("missions", null))
	xp_pass = int(d.get("xp_pass", 0))
	collection = Collection.reparer(d.get("collection", null))
	var dm: Variant = d.get("duels_par_match", {})
	duels_par_match = dm if dm is Dictionary else {}
	var ev: Variant = d.get("evenements", null)
	evenements = ev if ev is Dictionary and ev.get("primes") is Dictionary else {"primes": {}}
	# Un FANZZY retiré du catalogue ne doit pas casser la tribune.
	for i in equipe.size():
		if fanzzy_par_id(str(equipe[i])).is_empty():
			equipe = []
			break


func reinitialiser() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN_SAUVEGARDE))
	fan_club_nom = "Ultras du Canal"
	xp = 0
	position_club = {"nom": "Paris", "lat": 48.86, "lon": 2.35}
	tampons = {}
	skins = {}
	duels_gagnes = 0
	duels_joues = 0
	jetons = 150
	buvette_record = 0
	buvette_jour = ""
	buvette_services = 0
	boulots = {}
	club = FanClub.vide()
	pronos = {}
	pronos_finis = []
	serie_pronos = 0
	meilleure_serie = 0
	supporters = Supporters.vide()
	missions = Missions.vide()
	xp_pass = 0
	collection = Collection.vide()
	duels_par_match = {}
	evenements = {"primes": {}}
	equipe = equipe_par_defaut()
