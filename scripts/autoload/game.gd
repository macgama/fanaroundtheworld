extends Node
## État global du jeu, chargé automatiquement (autoload « Game »).
## Contient le fan club du joueur, sa position, ses tampons de stades,
## sa tribune de FANZZY et la navigation entre les écrans.

signal pronostics_resolus(liste: Array)
## Une équipe favorite a gagné des points de popularité (pour les petites annonces).
signal popularite_gagnee(cle: String, points: int, raison: String)
## Des missions du jour ou de la semaine viennent d'être terminées.
signal missions_terminees(liste: Array)
## Nouveaux succès gagnés (voir Succes.LISTE).
signal succes_gagnes(liste: Array)

const VERSION := "0.3.0"
## La démo garde sa propre sauvegarde (user://demo_sauvegarde.json, voir Demo).
var CHEMIN_SAUVEGARDE := Demo.fichier("user://sauvegarde.json")
## Nom du fichier dans Steam Cloud (même contenu que la sauvegarde locale).
const FICHIER_CLOUD := "sauvegarde.json"

const SCENE_TITRE := "res://scenes/main/main.tscn"
const SCENE_CARTE := "res://scenes/carte/carte.tscn"
const SCENE_VOYAGE := "res://scenes/voyage/voyage.tscn"
const SCENE_DEPLACEMENT := "res://scenes/deplacement/deplacement.tscn"
const SCENE_TRIBUNE := "res://scenes/tribune/tribune.tscn"
const SCENE_DUEL := "res://scenes/duel/duel.tscn"
const SCENE_ARENE := "res://scenes/arene/arene.tscn"
const SCENE_POUSSEE := "res://scenes/poussee/poussee.tscn"
const SCENE_BUVETTE := "res://scenes/buvette/buvette.tscn"
const SCENE_BOULOTS := "res://scenes/boulots/boulots.tscn"
const SCENE_RAMASSEUR := "res://scenes/ramasseur/ramasseur.tscn"
const SCENE_SPEAKER := "res://scenes/speaker/speaker.tscn"
const SCENE_TIFO := "res://scenes/tifo/tifo.tscn"
const SCENE_CLUB := "res://scenes/club/club.tscn"
const SCENE_CREATION_CLUB := "res://scenes/club/creation_club.tscn"
const SCENE_CHANT := "res://scenes/chant/createur_chant.tscn"
const SCENE_PRONOS := "res://scenes/pronostics/pronostics.tscn"
const SCENE_FAVORIS := "res://scenes/favoris/favoris.tscn"
const SCENE_SALON := "res://scenes/salon/salon.tscn"
const SCENE_MISSIONS := "res://scenes/missions/missions.tscn"
const SCENE_COLLECTION := "res://scenes/collection/collection.tscn"
const SCENE_CLASSEMENT := "res://scenes/classement/classement.tscn"
const SCENE_PASS := "res://scenes/pass/pass.tscn"
const SCENE_TOURNOI := "res://scenes/tournoi/tournoi.tscn"
const SCENE_LIGUE := "res://scenes/ligue/ligue.tscn"
const SCENE_SOIREE := "res://scenes/soiree/soiree.tscn"
const SCENE_LOCAL := "res://scenes/local/local.tscn"
const SCENE_GRAND_TOUR := "res://scenes/grand_tour/grand_tour.tscn"

## Paramètres passés d'un écran à l'autre (match choisi, camp supporté…).
var params: Dictionary = {}

# --- Fan club du joueur (sauvegardé) ---
var fan_club_nom := "Ultras du Canal"  # sans_traduction
var xp := 0
var position_club := {"nom": "Paris", "lat": 48.86, "lon": 2.35}  # sans_traduction
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
## PASS saisonnier (voir PassSaison) : saison, Premium, récompenses récupérées, skins et recrues gagnés.
var etat_pass: Dictionary = PassSaison.vide()
## Paliers de la saison en cours (data/pass/), ou {} si elle n'est pas prête.
var pass_data: Dictionary = {}
## Identifiant Steam du DLC « PASS Premium » (0 tant qu'il n'est pas créé dans Steamworks).
const DLC_PASS_PREMIUM := 0
## Carnet de voyage et album des FANZZY : primes réclamées, FANZZY et skins vus en duel (voir Collection).
var collection: Dictionary = Collection.vide()
## Duels joués par match aujourd'hui (id -> {jour, n}) : rejouer le même match rapporte de moins en moins.
var duels_par_match: Dictionary = {}
## Part des Jetons selon le rang du duel sur ce match dans la journée : 100 %, 50 %, 25 %, puis rien.
const RENDEMENT_REJEU := [1.0, 0.5, 0.25]
## Événements autour des vrais matchs (voir Evenements) : primes déjà gagnées, par match.
var evenements: Dictionary = {"primes": {}}
## Succès gagnés : id -> date unix (gardés ici même hors Steam, voir Plateforme).
var succes: Dictionary = {}
## Compteurs d'événements pour les succès (voir Succes.compter).
var stats: Dictionary = {}
## Moment de la dernière sauvegarde (unix) : départage ce PC et Steam Cloud.
var sauve_le := 0
## Matchs du calendrier avec un événement en cours ou à venir (recalculé à chaque mise à jour).
var nb_evenements := 0
## Tournoi des fan clubs du week-end (règles dans Tournoi, réseau dans EnLigne).
var tournoi: Dictionary = Tournoi.vide()
## Démo : écran « fin de la démo » déjà montré.
var demo_fin_vue := false
## Dernier déplacement fait (voir Deplacement) : {match, jour, mult, ferveur}.
## Ses Jetons de duel sont multipliés par « mult » le jour même.
var deplacement: Dictionary = {}
## Stade où se trouve le fan club aujourd'hui (arrivée au stade) : {cle, jour}.
## Sert à la boutique souvenirs (prix sur place, voir Souvenirs).
var stade_du_jour: Dictionary = {}
## Matériel de tribune (voir Materiel) : {id: {niveau, actif}}. Décor seulement.
var materiel: Dictionary = {}
## Local agrandi et décoré (voir LocalClub) : {salles, deco}. Décor seulement.
var local_club: Dictionary = LocalClub.vide()
## Dernier Grand Tour (voir GrandTour) : {jour, pays, taille, cles}. Un par jour.
var grand_tour: Dictionary = {}
## Ligue des tribunes (saison du mois, scripts/jeu/ligue.gd).
var ligue: Dictionary = Ligue.vide()
## Soirs de match : buts déjà récompensés et fil des buts, par match (SoireeMatch).
var soirees: Dictionary = SoireeMatch.vide()
## Dernier score vu de chaque match en direct d'une équipe favorite (alerte « BUT ! »).
var _scores_favoris: Dictionary = {}

## Où suivre le match. Au stade : billet + trajet, tampon du stade, plus de Jetons.
const MODES_SUIVI := {
	"stade": {"titre": "Au stade", "texte": "Billet + déplacement · tampon", "gain": 1.5, "billet": 25},
	"ecran": {"titre": "Écran géant", "texte": "Fan zone de la ville", "gain": 1.2, "billet": 8},
	"pub": {"titre": "Au pub", "texte": "Avec les supporters du coin", "gain": 1.0, "billet": 4},
	"maison": {"titre": "À la maison", "texte": "Gratuit, entre amis", "gain": 0.6, "billet": 0},
}
const ORDRE_MODES := ["stade", "ecran", "pub", "maison"]

# --- Catalogue FANZZY (échantillon du prototype) ---
var familles: Dictionary = {}
var series_fanzzy: Dictionary = {}  # id de série -> {nom, ligne, couleur}
var fanzzy: Array = []             # FANZZY jouables (les recrues du PASS une fois débloquées)
var _fanzzy_tous: Array = []
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
	actualiser_pass()
	if equipe.size() != 3:
		equipe = equipe_par_defaut()
	_brancher_pronostics.call_deferred()
	# Succès déjà mérités (ancienne sauvegarde) et succès gagnés hors Steam : envoyés à Steam.
	Succes.noter(succes, etat_succes(), maintenant())
	Plateforme.synchroniser_succes(succes.keys())
	_outils_de_test()


## Options de ligne de commande pour les tests automatiques (après « -- ») :
##   --scene=carte|voyage|tribune|duel|arene|poussee|buvette|boulots|tifo|ramasseur   ouvre directement un écran
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
			p = {"match_id": args["match"], "camp": args.get("camp", "home"), "mode": args.get("mode", "stade"), "cout": 0}
			if args.has("auto"):
				p["auto"] = true  # Arène / Poussée : ton camp joue tout seul (démo)
			if args.has("chant"):
				p["chant"] = ChantClub.par_defaut()  # duel : essayer le chant par défaut
			if args.has("simuler"):
				p["simuler"] = true  # soir de match : buts simulés (démo, captures)
		var scenes := {"carte": SCENE_CARTE, "voyage": SCENE_VOYAGE, "deplacement": SCENE_DEPLACEMENT, "tribune": SCENE_TRIBUNE, "duel": SCENE_DUEL,
			"arene": SCENE_ARENE, "poussee": SCENE_POUSSEE,
			"pronos": SCENE_PRONOS, "missions": SCENE_MISSIONS, "favoris": SCENE_FAVORIS, "club": SCENE_CLUB, "creation": SCENE_CREATION_CLUB, "chant": SCENE_CHANT, "buvette": SCENE_BUVETTE, "boulots": SCENE_BOULOTS, "speaker": SCENE_SPEAKER, "tifo": SCENE_TIFO,
			"salon": SCENE_SALON, "collection": SCENE_COLLECTION, "classement": SCENE_CLASSEMENT, "pass": SCENE_PASS,
			"tournoi": SCENE_TOURNOI, "ligue": SCENE_LIGUE, "soiree": SCENE_SOIREE, "local": SCENE_LOCAL, "grand_tour": SCENE_GRAND_TOUR}
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
	if args.has("depuis"):
		var ll: PackedStringArray = str(args["depuis"]).split(",")  # --depuis=lon,lat : point de départ du fan club
		position_club = {"nom": "Test", "lon": float(ll[0]), "lat": float(ll[1])}  # sans_traduction
	if args.has("xp-pass"):
		xp_pass = int(args["xp-pass"])  # captures et tests du PASS
	if args.has("premium"):
		etat_pass["premium"] = true
	if args.has("vitesse"):
		Engine.time_scale = float(args["vitesse"])  # accélère une partie de démo
	if args.has("capture"):
		await get_tree().create_timer(float(args.get("apres", "3"))).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(args["capture"])
		get_tree().quit()


# ---------------------------------------------------------------- navigation

func aller(scene: String, p: Dictionary = {}) -> void:
	var ferme := Demo.ecran_ferme(scene)
	if ferme != "":
		Demo.montrer_ferme(ferme)  # démo : « dans le jeu complet »
		return
	params = p
	get_tree().change_scene_to_file(scene)


# ---------------------------------------------------------------- progression

func niveau() -> int:
	return niveau_de(xp)


func xp_dans_niveau() -> float:
	var n := niveau()
	return float(xp - xp_debut_niveau(n)) / float(xp_pour_niveau(n))


## Courbe du niveau du fan club (docs/equilibrage.md) : 200 XP par niveau jusqu'au
## niveau 6 (tout ce qui se débloque arrive vite), puis 100 XP de plus à chaque niveau.
const XP_NIVEAU := 200
const NIVEAU_COURBE := 5
const XP_NIVEAU_EN_PLUS := 100


## XP à gagner pour passer du niveau n au niveau n + 1.
static func xp_pour_niveau(n: int) -> int:
	return XP_NIVEAU + XP_NIVEAU_EN_PLUS * maxi(0, n - NIVEAU_COURBE)


## XP totale au début du niveau n.
static func xp_debut_niveau(n: int) -> int:
	var t := 0
	for k in range(1, maxi(1, n)):
		t += xp_pour_niveau(k)
	return t


static func niveau_de(points: int) -> int:
	var n := 1
	var reste := maxi(0, points)
	while reste >= xp_pour_niveau(n):
		reste -= xp_pour_niveau(n)
		n += 1
	return n


func ajouter_xp(n: int) -> void:
	xp = Demo.xp_limitee(xp + n)  # la démo s'arrête au niveau Demo.NIVEAU_MAX
	sauver()


## Démo : vrai quand le joueur a fini la démo et n'a pas encore vu l'écran de fin.
func fin_demo_a_montrer() -> bool:
	return Demo.actif() and not demo_fin_vue and niveau() >= Demo.NIVEAU_MAX


func montrer_fin_demo() -> void:
	demo_fin_vue = true
	sauver()
	Demo.montrer_fin()


func gain_suivi(mode: String) -> float:
	return float(MODES_SUIVI.get(mode, {}).get("gain", 1.0))


## Prix du billet pour suivre ce match. Au stade, il suit l'importance du match
## (derby, finale, coupe continentale… voir Evenements.facteur_billet) ; à l'écran
## géant, au plus ×2 ; au pub et à la maison, il ne change pas.
func billet(mode: String, m: Dictionary = {}) -> int:
	var base := int(MODES_SUIVI[mode]["billet"])
	if m.is_empty() or base == 0 or mode == "pub":
		return base
	var comp := str(m.get("competition", {}).get("id", ""))
	# Compétition inconnue ou matchs amicaux : prix d'un match de championnat.
	var portee := "pays" if Geo.info_competition(comp).is_empty() or "friend" in comp else Geo.niveau_competition(comp)  # sans_traduction
	var f := Evenements.facteur_billet(evenement_de(m), portee)
	if mode == "ecran":
		f = minf(f, 2.0)
	return int(round(base * f / 5.0)) * 5 if f > 1.0 else base


func cout_suivi(mode: String, distance_km: float, m: Dictionary = {}) -> int:
	var c := billet(mode, m)
	if mode == "stade":
		c += cout_trajet(distance_km)
	return c


## Trajet le moins cher (car ou train, cagnotte du club comprise) : prix affiché « dès ».
func cout_trajet(distance_km: float) -> int:
	return Deplacement.cout_min(distance_km, convoi().size())


# ---------------------------------------------------------------- déplacements

## Les FANZZY du convoi : les membres du fan club, ou la tribune s'il n'est pas encore créé.
func convoi() -> Array:
	var res: Array = []
	for id in club.get("membres", []):
		if not fanzzy_par_id(str(id)).is_empty() and not str(id) in res:
			res.append(str(id))
	for id in equipe:
		if not fanzzy_par_id(str(id)).is_empty() and not str(id) in res:
			res.append(str(id))
	return res


func familles_convoi() -> Array:
	var res: Array = []
	for id in convoi():
		res.append(str(fanzzy_par_id(id).get("famille", "")))
	return res


## Arrivée au stade : verse la prime du déplacement et garde le bonus de duel du jour.
func finir_deplacement(match_id: String, b: Dictionary) -> Dictionary:
	var r := b.duplicate()
	jetons += int(b["jetons"])
	xp += int(b["xp"])
	r["xp_pass"] = gagner_xp_pass(int(b["xp_pass"]))
	deplacement = {"match": match_id, "jour": Time.get_date_string_from_system(), "mult": float(b["mult"]), "ferveur": int(b["ferveur"])}
	Succes.compter(stats, "deplacement", str(b.get("transport", "")), 1)
	sauver()
	return r


## Multiplicateur des Jetons de duel sur ce match (×1 sans déplacement le jour même).
func bonus_deplacement(match_id: String) -> float:
	if match_id == "" or str(deplacement.get("match", "")) != match_id:
		return 1.0
	if str(deplacement.get("jour", "")) != Time.get_date_string_from_system():
		return 1.0
	return maxf(1.0, float(deplacement.get("mult", 1.0)))


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
	return Trad.t("Jetons gagnés (match rejoué : %d %%)") % int(round(part * 100.0))


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


func tamponner(cle: String, info: Dictionary, en_jouant := true) -> bool:
	## Ajoute le tampon du stade. Renvoie true si c'est une première visite.
	## en_jouant faux (Grand Tour payé en Jetons) : ni XP de PASS, ni mission.
	if tampons.has(cle):
		return false
	tampons[cle] = info
	if en_jouant:
		gagner_xp_pass(PassSaison.XP_NOUVEAU_STADE)
		noter_mission("nouveau_stade", cle)
	sauver()
	return true


# ---------------------------------------------------------------- fan club

static var _decalage_test := 0
static var _decalage_lu := false


## Heure du jeu (secondes UTC). Tests : « -- --maintenant=2026-11-21T15:00:00 » fait comme si c'était ce moment.
static func maintenant() -> int:
	if not _decalage_lu:
		_decalage_lu = true
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--maintenant="):  # sans_traduction
				_decalage_test = int(Time.get_unix_time_from_datetime_string(a.trim_prefix("--maintenant="))) - int(Time.get_unix_time_from_system())  # sans_traduction
	return int(Time.get_unix_time_from_system()) + _decalage_test


func club_cree() -> bool:
	return bool(club.get("cree", false))


func creer_club(nom: String, c1: String, c2: String) -> void:
	## Les trois FANZZY de la tribune sont les membres fondateurs.
	fan_club_nom = nom.strip_edges().substr(0, 28)
	var fondateurs := equipe.filter(func(id): return not fanzzy_par_id(str(id)).is_empty())
	club = FanClub.nouveau(fondateurs, c1, c2, maintenant())
	sauver()


## Le chant composé par le fan club ({} tant qu'il n'y en a pas).
func chant_club() -> Dictionary:
	return club.get("chant", {})


## Enregistre le chant du club. Rend les erreurs (vide : enregistré).
func enregistrer_chant(c: Dictionary) -> Array:
	var propre := ChantClub.reparer(c.duplicate(true))
	var err := ChantClub.erreurs(propre if not propre.is_empty() else c, niveau())
	if not err.is_empty():
		return err
	var premier := chant_club().is_empty()
	club["chant"] = propre
	sauver()
	if premier:
		noter_mission("chant")
	return []


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


# ---------------------------------------------------------------- soir de match

## État de la soirée d'un match : {debut, buts, fil, prime}.
func soiree_de(match_id: String) -> Dictionary:
	SoireeMatch.nettoyer(soirees, maintenant())
	return SoireeMatch.etat(soirees, match_id, maintenant())


## Une mini-ambiance jouée après un vrai but : verse les gains (une fois par
## but, MAX_BUTS par match) et renvoie {jetons, xp, xp_pass}, ou {} si ce but
## a déjà rapporté.
func recompenser_but_soiree(m: Dictionary, cle: String, perf: float, pour_nous: bool, mode_suivi: String, ferveur: float) -> Dictionary:
	var e := soiree_de(str(m.get("id", "")))
	if not SoireeMatch.peut_recompenser(e, cle):
		return {}
	e["buts"].append(cle)
	var r := SoireeMatch.recompense(perf, pour_nous, gain_suivi(mode_suivi), ferveur)
	jetons += int(r["jetons"])
	xp += int(r["xp"])
	r["xp_pass"] = gagner_xp_pass(int(r["xp_pass"]))
	noter_mission("soiree_but", "nous" if pour_nous else "eux")
	sauver()
	return r


## Prime de fin de soirée (présent au coup de sifflet final depuis 30 min), une fois.
func prime_fin_soiree(m: Dictionary, mode_suivi: String) -> Dictionary:
	var e := soiree_de(str(m.get("id", "")))
	if bool(e["prime"]) or maintenant() - int(e["debut"]) < SoireeMatch.PRESENCE_PRIME:
		return {}
	e["prime"] = true
	var r := SoireeMatch.prime_fin(gain_suivi(mode_suivi))
	jetons += int(r["jetons"])
	xp += int(r["xp"])
	r["xp_pass"] = gagner_xp_pass(int(r["xp_pass"]))
	sauver()
	return r


## Un vrai but d'une équipe favorite, où qu'on soit dans le jeu : petite alerte
## qui propose de vivre la fin du match en soir de match.
func _surveiller_buts_favoris() -> void:
	var vus: Dictionary = {}
	for m in Donnees.matchs():
		if not Donnees.en_direct(m):
			continue
		var favs := camps_favoris(m)
		if favs.is_empty():
			continue
		var id := str(m.get("id", ""))
		var sc := SoireeMatch.score_de(m)
		vus[id] = sc
		if not _scores_favoris.has(id):
			continue
		for b in SoireeMatch.detecter(_scores_favoris[id], sc):
			if not b["annule"]:
				_alerte_but(m, str(favs[0]), str(b["cote"]) in favs)
	_scores_favoris = vus


func _alerte_but(m: Dictionary, camp_favori: String, pour_nous: bool) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree():
		return
	var sc := get_tree().current_scene
	if sc and sc.scene_file_path in [SCENE_SOIREE, SCENE_DUEL, SCENE_ARENE, SCENE_POUSSEE]:
		return  # déjà dans un match : l'écran s'en occupe
	var f := FicheMatch.de(m)
	var couche := CanvasLayer.new()
	couche.layer = 51
	add_child(couche)
	var toast := Ui.panneau(Ui.JAUNE if pour_nous else Ui.NUIT_CLAIR, 20, 5)
	var h := Ui.hbox(14)
	var nom: String = (f["dom"] if camp_favori == "home" else f["ext"])["nom"]
	var titre := tr("BUT ! %s") % nom if pour_nous else tr("But encaissé par %s") % nom
	h.add_child(Ui.label("%s · %s %s %s" % [titre, f["dom"]["sigle"], Donnees.score_texte(m), f["ext"]["sigle"]], 24, Ui.CONTOUR if pour_nous else Ui.BLANC, true))
	var b := Ui.bouton("Vivre le match", Ui.ROSE, 22)
	b.pressed.connect(func():
		couche.queue_free()
		aller(SCENE_SOIREE, {"match_id": str(m.get("id", "")), "camp": camp_favori, "mode": "maison", "cout": 0, "suivi_a_noter": true}))
	h.add_child(b)
	toast.add_child(h)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 128  # sous la barre du haut de la carte
	couche.add_child(toast)
	Ui.pop(toast, 1.15)
	var tw := toast.create_tween()
	tw.tween_interval(8.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(couche.queue_free)


# ---------------------------------------------------------------- pronostics

func _brancher_pronostics() -> void:
	Donnees.mis_a_jour.connect(resoudre_pronostics)
	Donnees.mis_a_jour.connect(_compter_evenements)
	Donnees.mis_a_jour.connect(_surveiller_buts_favoris)
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
		return tr("%d pronostics en attente au maximum") % Pronostics.MAX_EN_ATTENTE
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
			p["xp_pass"] = gagner_xp_pass(PassSaison.XP_PRONO_EXACT if bool(r.get("score_ok", false)) else PassSaison.XP_PRONO_BON)
			noter_mission("prono_bon")
		if bool(r.get("score_ok", false)):
			Succes.compter(stats, "prono_exact", "", 1)
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
	if gagne and Reseau.connecte():
		Succes.compter(stats, "duel_gagne_en_ligne", "", 1)
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
		"evenements": nb_evenements > 0, "tournoi": club_cree()}


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
		verse["xp_pass"] = gagner_xp_pass(int(verse["xp_pass"]), true)
		sauver()
	return verse


func noter_mission(evt: String, cle := "", n := 1) -> void:
	Succes.compter(stats, evt, cle, n)  # toutes les actions passent ici : compteurs des succès
	actualiser_missions()
	var finies := Missions.noter(missions, evt, cle, n)
	if finies.is_empty():
		if not Succes.nouveaux(succes, etat_succes()).is_empty():
			sauver()  # un succès tout juste mérité : gagné et sauvegardé tout de suite
		return
	sauver()
	missions_terminees.emit(finies)
	_annonce_missions(finies)


func recuperer_mission(periode: String, index: int) -> Dictionary:
	actualiser_missions()
	var g := Missions.recuperer(missions, periode, index)
	if not g.is_empty():
		Succes.compter(stats, "missions_recuperees", "", 1)
		jetons += int(g["jetons"])
		g["xp_pass"] = gagner_xp_pass(int(g["xp_pass"]), true)
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
	var txt := tr("Mission terminée : %s") % tr(finies[0]["titre"]) if finies.size() == 1 else tr("%d missions terminées !") % finies.size()
	var l := Ui.label(txt + tr(" · à récupérer dans Missions"), 22, Ui.CONTOUR, true)
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
	r["prime_xp"] = gagner_xp_pass(int(r["prime_xp"]))
	noter_mission("evenement", str(ev["type"]))
	sauver()
	return r


# ---------------------------------------------------------------- PASS saisonnier

## Change de saison si besoin (l'XP mise de côté pendant l'intersaison passe à
## la nouvelle saison) et lit les paliers de la saison en cours.
func actualiser_pass() -> void:
	var saison := PassSaison.saison_de(heure_locale())
	var report := PassSaison.changer_saison(etat_pass, saison)
	if report >= 0:
		xp_pass = report
	if pass_data.get("saison", "") != saison:
		pass_data = PassSaison.charger(saison)
	if not bool(etat_pass["premium"]) and _dlc_premium_installe():
		etat_pass["premium"] = true
	if report >= 0 or bool(etat_pass["premium"]):
		sauver()


func _dlc_premium_installe() -> bool:
	if DLC_PASS_PREMIUM <= 0 or not Plateforme.steam_ok:
		return false
	return bool(Plateforme.steam.call("isDLCInstalled", DLC_PASS_PREMIUM))  # sans_traduction


## Ajoute de l'XP de PASS et renvoie celle vraiment gagnée. Missions : double
## pendant le rattrapage. Intersaison : mise de côté pour la saison suivante.
func gagner_xp_pass(n: int, mission := false) -> int:
	if n <= 0:
		return 0
	var t := heure_locale()
	if PassSaison.en_intersaison(pass_data, t):
		etat_pass["report"] = mini(int(etat_pass["report"]) + n, PassSaison.REPORT_MAX)
		return n
	if mission and PassSaison.rattrapage(pass_data, xp_pass, t):
		n *= 2
	xp_pass += n
	return n


## XP de PASS d'une partie (duel d'ambiance, Arène, Poussée), déjà versée.
func xp_pass_duel(gagne: bool, perf: float, part: float) -> int:
	var n := gagner_xp_pass(PassSaison.xp_duel(gagne, perf, part))
	sauver()
	return n


func rattrapage_pass() -> bool:
	return PassSaison.rattrapage(pass_data, xp_pass, heure_locale())


func pass_a_recuperer() -> int:
	return PassSaison.nb_a_recuperer(pass_data, etat_pass, xp_pass)


## Récupère une récompense du PASS (ou toutes si `p` vaut 0).
func recuperer_pass(p := 0, piste := "") -> Dictionary:
	var g := PassSaison.recuperer_tout(pass_data, etat_pass, xp_pass) if p <= 0 else PassSaison.recuperer(pass_data, etat_pass, xp_pass, p, piste)
	if g.is_empty():
		return g
	jetons += int(g["jetons"])
	if g["fanzzy"].size() > 0:
		_filtrer_fanzzy()
	sauver()
	return g


# ---------------------------------------------------------------- tournoi des fan clubs

## Passe au tournoi du week-end en cours (le précédent attend sa récompense).
func actualiser_tournoi() -> Dictionary:
	if Tournoi.actualiser(tournoi, maintenant()):
		sauver()
	return Tournoi.fenetre(maintenant())


func inscrire_tournoi(nom: Array, couleurs: Array) -> bool:
	var f := actualiser_tournoi()
	if f["etat"] != "actif" or not club_cree():
		return false
	tournoi["nom"] = Tournoi.nom_valide(nom)
	tournoi["couleurs"] = [clampi(int(couleurs[0]), 0, FanClub.COULEURS.size() - 1), clampi(int(couleurs[1]), 0, FanClub.COULEURS.size() - 1)]
	tournoi["inscrit"] = true
	tournoi["inscrit_serveur"] = false
	sauver()
	return true


## Couleurs du fan club en numéros de FanClub.COULEURS (pour le nom de tournoi).
func couleurs_club_index() -> Array:
	var c: Array = club.get("couleurs", [FanClub.COULEURS[0], FanClub.COULEURS[7]])
	return [Tournoi.index_couleur(str(c[0])), Tournoi.index_couleur(str(c[1]))]


## Le club adverse si un duel sur ce match compte pour le tournoi, sinon {}.
## Les duels en ligne contre un vrai joueur ne comptent pas (ils ont leur salon).
func adversaire_tournoi(m: Dictionary) -> Dictionary:
	if m.is_empty() or bool(params.get("en_ligne", false)) or params.has("ligue_bot"):
		return {}
	actualiser_tournoi()
	if Tournoi.raison_refus(tournoi, str(m.get("id", "")), Donnees.heure_unix(m), maintenant()) != "":
		return {}
	return Tournoi.adversaire(tournoi)


## Fin d'un duel (trois modes) : compte pour le tournoi si le match est du week-end.
## Renvoie la ligne du duel {nom_adv, pts, gagne…} ou {}.
func noter_duel_tournoi(m: Dictionary, gagne: bool, mode_suivi: String) -> Dictionary:
	if adversaire_tournoi(m).is_empty():
		return {}
	var ev := not evenement_de(m).is_empty() and etat_evenement(m) == "actif"
	var d := Tournoi.noter_duel(tournoi, str(m.get("id", "")), Donnees.heure_unix(m), gagne, mode_suivi == "stade", ev, maintenant())
	if d.is_empty():
		return {}
	sauver()
	noter_mission("tournoi")
	EnLigne.synchroniser_tournoi()
	return d


## Récompense du tournoi fini (Jetons + XP de PASS). {} s'il n'y en a pas.
func reclamer_tournoi() -> Dictionary:
	var g := Tournoi.reclamer(tournoi)
	if g.is_empty():
		return {}
	jetons += int(g["jetons"])
	g["xp_pass"] = gagner_xp_pass(int(g["xp_pass"]))
	sauver()
	return g


# ---------------------------------------------------------------- Ligue des tribunes

## Passe à la saison du mois (la précédente attend sa récompense). Renvoie le calendrier.
func actualiser_ligue() -> Dictionary:
	var t := maintenant()
	var change := Ligue.actualiser(ligue, t)
	var avant := (ligue["duels"] as Array).map(func(d): return d["etat"])
	Ligue.expirer(ligue, t)
	if change or avant != (ligue["duels"] as Array).map(func(d): return d["etat"]):
		sauver()
	return Ligue.calendrier(t)


## Entrée dans la saison : nom de tournoi (ou un nom tiré du fan club) et couleurs.
func inscrire_ligue(nom: Variant = null, couleurs: Variant = null) -> bool:
	actualiser_ligue()
	if not club_cree():
		return false
	if nom == null:
		nom = tournoi["nom"] if bool(tournoi["inscrit"]) or not (tournoi["historique"] as Array).is_empty() else ligue["nom"]
		if not bool(ligue["inscrit"]) and nom == [0, 0]:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash(fan_club_nom)
			nom = Tournoi.nom_au_hasard(rng)
	if couleurs == null:
		couleurs = couleurs_club_index()
	ligue["nom"] = Tournoi.nom_valide(nom)
	ligue["couleurs"] = [clampi(int(couleurs[0]), 0, FanClub.COULEURS.size() - 1), clampi(int(couleurs[1]), 0, FanClub.COULEURS.size() - 1)]
	ligue["inscrit"] = true
	ligue["inscrit_serveur"] = false
	sauver()
	return true


## Club du jeu de ta poule affronté dans ce duel (Game.params["ligue_bot"]), sinon {}.
func bot_ligue() -> Dictionary:
	if not params.has("ligue_bot") or bool(params.get("en_ligne", false)):
		return {}
	var k := int(params["ligue_bot"])
	for b in Ligue.bots_de_la_poule(ligue, EnLigne.ligue_poule, maintenant()):
		if str(b["id"]) == "bot:%d" % k:
			return b
	return {}


## Fin d'un duel (trois modes). Compte pour la Ligue si c'est un duel en ligne
## (code de l'hôte, adversaire connu du serveur) ou contre un club du jeu de ta poule,
## pendant une journée et sur un match du week-end. Renvoie la ligne du duel ou {}.
## `resultat` : 1 gagné, 0 nul, -1 perdu.
func noter_duel_ligue(m: Dictionary, resultat: int) -> Dictionary:
	if m.is_empty():
		return {}
	var c := actualiser_ligue()
	if c["etat"] != "journee" or not Ligue.match_de_la_journee(Donnees.heure_unix(m), c):
		return {}
	var adv := {}
	var code := ""
	if bool(params.get("en_ligne", false)):
		var fan := str(Reseau.adversaire.get("fan", ""))
		code = str(params.get("code_ligue", ""))
		if fan == "" or not Ligue.code_valide(code) or fan == str(EnLigne.identite["id"]):
			return {}
		adv = {"id": fan, "bot": false, "nom": Reseau.adversaire.get("ligue_nom", [0, 0]), "couleurs": [0, 7],
			"nom_texte": str(Reseau.adversaire.get("nom", ""))}
	else:
		adv = bot_ligue()
		if adv.is_empty():
			return {}
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		code = Ligue.nouveau_code(rng)
	if not bool(ligue["inscrit"]) and not inscrire_ligue():
		return {}
	var d := Ligue.noter_duel(ligue, code, adv, str(m.get("id", "")), Donnees.heure_unix(m), resultat, Donnees.en_direct(m), maintenant())
	if d.is_empty():
		return {}
	if adv.has("nom_texte"):
		d["nom_texte"] = adv["nom_texte"]
	sauver()
	EnLigne.synchroniser_ligue()
	return d


## Ce duel en ligne comptera-t-il pour la Ligue ? "" si oui, sinon la raison (pour le salon).
func raison_hors_ligue(m: Dictionary) -> String:
	var c := actualiser_ligue()
	if not club_cree():
		return "Crée ton fan club pour jouer la Ligue des tribunes"
	if c["etat"] != "journee":
		return "Pas de journée de Ligue en ce moment (du vendredi au lundi midi)"
	if m.is_empty() or not Ligue.match_de_la_journee(Donnees.heure_unix(m), c):
		return "Ce match n'est pas un match du week-end de la journée"
	if str(Reseau.adversaire.get("fan", "")) == "" and Reseau.connecte():
		return "L'adversaire n'a pas encore d'identité en ligne"
	var r := Ligue.raison_refus(ligue if bool(ligue["inscrit"]) else _ligue_essai(), str(Reseau.adversaire.get("fan", "?")), Donnees.heure_unix(m), maintenant())
	return r


func _ligue_essai() -> Dictionary:
	var s: Dictionary = ligue.duplicate(true)
	s["inscrit"] = true
	return s


## Récompense de la saison finie (Jetons + XP de PASS). {} s'il n'y en a pas.
func reclamer_ligue() -> Dictionary:
	var g := Ligue.reclamer(ligue)
	if g.is_empty():
		return {}
	jetons += int(g["jetons"])
	g["xp_pass"] = gagner_xp_pass(int(g["xp_pass"]))
	sauver()
	return g


## Bouton « PASS » de la barre du bas (carte, fan club) : passe au jaune avec
## le nombre de récompenses à récupérer. `p` : paramètres du retour.
func preparer_bouton_pass(b: Button, p: Dictionary) -> void:
	var n := pass_a_recuperer()
	if n > 0:
		b.text = tr("PASS · %d") % n
		Ui.colorer_bouton(b, Ui.JAUNE, true)
	b.tooltip_text = "PASS saisonnier : 100 paliers de récompenses"
	b.pressed.connect(func(): aller(SCENE_PASS, p))


## Ouvre la page du DLC dans Steam. Renvoie false si l'achat n'est pas encore possible.
func acheter_premium() -> bool:
	if DLC_PASS_PREMIUM <= 0 or not Plateforme.steam_ok:
		return false
	Plateforme.steam.call("activateGameOverlayToStore", DLC_PASS_PREMIUM, 0)  # sans_traduction
	return true


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


func series_vitrine() -> Array:
	return Souvenirs.series(collection, tampons)


## Nombre de primes de collection prêtes à réclamer (pastille sur la carte).
func primes_pretes() -> int:
	return Collection.pretes(series_carnet()).size() + Collection.pretes(series_album()).size() + Collection.pretes(series_vitrine()).size()


## Le fan club est-il passé dans ce stade aujourd'hui ? (plusieurs avec un Grand Tour)
func au_stade(cle: String) -> bool:
	if cle == "" or str(stade_du_jour.get("jour", "")) != Time.get_date_string_from_system():
		return false
	return str(stade_du_jour.get("cle", "")) == cle or cle in stade_du_jour.get("cles", [])


func noter_arrivee_stade(cle: String) -> void:
	var jour := Time.get_date_string_from_system()
	var cles: Array = []
	if str(stade_du_jour.get("jour", "")) == jour:
		cles = stade_du_jour.get("cles", []).duplicate() if stade_du_jour.get("cles") is Array else []
		if str(stade_du_jour.get("cle", "")) != "" and not str(stade_du_jour["cle"]) in cles:
			cles.append(str(stade_du_jour["cle"]))
	if not cle in cles:
		cles.append(cle)
	stade_du_jour = {"cle": cle, "jour": jour, "cles": cles}


## Grand Tour proposé dans ce pays (voir GrandTour), depuis la position du fan club.
func proposer_grand_tour(pays: String, taille: String) -> Dictionary:
	var depart := Vector2(float(position_club.get("lon", 0.0)), float(position_club.get("lat", 0.0)))
	return GrandTour.proposer(pays, Donnees.clubs_du_pays(pays), tampons, depart, taille, convoi().size())


func grand_tour_fait_aujourdhui() -> bool:
	return GrandTour.fait_le(grand_tour, Time.get_date_string_from_system())


## Paie le Grand Tour et tamponne ses étapes. Renvoie les clés des nouveaux tampons
## ([] si impossible : déjà fait aujourd'hui, ou pas assez de Jetons).
func partir_grand_tour(tour: Dictionary) -> Array:
	if tour.is_empty() or grand_tour_fait_aujourdhui() or not depenser(int(tour["prix"])):
		return []
	var jour := Time.get_date_string_from_system()
	var nouveaux: Array = []
	var pays := str(tour["pays"])
	for e in tour["etapes"]:
		if tamponner(e["cle"], {"nom": e["nom"], "club": e["club"], "date": jour,
				"match": Trad.t("Grand Tour"), "pays": pays, "continent": Geo.continent_de(pays), "competition": ""}, false):
			nouveaux.append(e["cle"])
		noter_arrivee_stade(e["cle"])
	var fin: Dictionary = tour["etapes"][tour["etapes"].size() - 1]
	position_club = {"nom": fin["nom"], "lat": fin["pos"].y, "lon": fin["pos"].x}
	grand_tour = {"jour": jour, "pays": pays, "taille": tour["taille"], "cles": tour["etapes"].map(func(e): return e["cle"])}
	Succes.compter(stats, "grand_tour", "", 1)
	sauver()
	return nouveaux


## Prix d'un souvenir de ce stade (sur place aujourd'hui, ou par correspondance).
func prix_souvenir(cle: String, type: String) -> int:
	return Souvenirs.prix(type, au_stade(cle))


## Achète un souvenir pour la vitrine du club. Renvoie false si impossible ou trop cher.
func acheter_souvenir(cle: String, type: String) -> bool:
	if not Souvenirs.achetable(collection, tampons, cle, type):
		return false
	if not depenser(prix_souvenir(cle, type)):
		return false
	Souvenirs.ajouter(collection, cle, type, Time.get_date_string_from_system())
	Succes.compter(stats, "souvenir", type, 1)
	sauver()
	return true


## Achète (ou améliore) un objet de matériel de tribune. false si impossible ou trop cher.
func acheter_materiel(id: String) -> bool:
	var mois := int(Time.get_date_dict_from_system()["month"])
	var p := Materiel.prix_suivant(materiel, id, mois)
	if p < 0 or not depenser(p):
		return false
	Materiel.monter(materiel, id, mois)
	Succes.compter(stats, "materiel", id, 1)
	sauver()
	return true


## Construit ou agrandit une salle du local. false si impossible ou trop cher.
func acheter_salle(id: String) -> bool:
	var p := LocalClub.prix_salle(local_club, id)
	if p < 0 or not depenser(p):
		return false
	LocalClub.construire(local_club, id)
	Succes.compter(stats, "local", id, 1)
	sauver()
	return true


## Achète une déco du local. false si impossible ou trop cher.
func acheter_deco(id: String) -> bool:
	var p := LocalClub.prix_deco(local_club, id)
	if p < 0 or not depenser(p):
		return false
	LocalClub.poser(local_club, id, Time.get_date_string_from_system())
	Succes.compter(stats, "local", "", 1)
	sauver()
	return true


## Range ou ressort un objet de matériel déjà acheté.
func basculer_materiel(id: String) -> void:
	Materiel.basculer(materiel, id)
	sauver()


## Réclame la prime d'une série complète. Renvoie les Jetons gagnés (0 sinon).
func reclamer_prime(id: String) -> int:
	for s in series_carnet() + series_album() + series_vitrine():
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
		push_error("Catalogue FANZZY introuvable")  # sans_traduction
		return
	var d: Variant = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		familles = d.get("familles", {})
		series_fanzzy = d.get("series", {})
		_fanzzy_tous = d.get("fanzzy", [])
		for z in _fanzzy_tous:
			_fanzzy_par_id[z["id"]] = z
		_filtrer_fanzzy()


## Les recrues du PASS ne sont jouables qu'une fois récupérées sur la piste gratuite.
func _filtrer_fanzzy() -> void:
	fanzzy = _fanzzy_tous.filter(func(z): return not z.has("pass") or z["id"] in etat_pass["fanzzy"])


## Tous les FANZZY du catalogue, recrues du PASS encore bloquées comprises.
func fanzzy_catalogue() -> Array:
	return _fanzzy_tous


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


## Skins qu'on peut choisir pour ce FANZZY : ses évolutions, puis les skins gagnés dans le PASS.
func skins_possibles(z: Dictionary) -> Array:
	var res: Array = z["skins"].duplicate()
	for s in PassSaison.skins_de(etat_pass, z["id"]):
		res.append({"id": s["skin"], "nom": s["nom"]})
	return res


func texture_fanzzy(id: String, buste := false) -> Texture2D:
	return texture_skin(skin_de(id), buste)


## Image d'un skin précis (skin de base, évolution ou skin du PASS).
func texture_skin(skin: String, buste := false) -> Texture2D:
	var chemin := "res://assets/fanzzy/sprites/%s%s.webp" % [skin, "-buste" if buste else ""]
	if not skin.is_empty() and ResourceLoader.exists(chemin):
		return load(chemin)
	return null


func couleur_famille(fam: String) -> Color:
	return Color(familles.get(fam, {}).get("couleur", "#888888"))


func nom_famille(fam: String) -> String:
	return tr(familles.get(fam, {}).get("nom", fam))


# ---------------------------------------------------------------- succès

## Ce que les succès regardent (clés de Succes.LISTE).
func etat_succes() -> Dictionary:
	var lieux := lieux_visites()
	var modes := 0
	for m in ORDRE_MODES:
		if int(stats.get("suivre:" + m, 0)) > 0:
			modes += 1
	var boulots_faits := 0
	for b in ListeBoulots.LISTE:
		if record_boulot(b["id"]) > 0 or int(stats.get("boulot:" + b["id"], 0)) > 0:
			boulots_faits += 1
	var e := stats.duplicate()
	e.merge({
		"duels_joues": duels_joues, "duels_gagnes": duels_gagnes,
		"club_cree": 1 if club_cree() else 0, "membres": FanClub.nb_membres(club) if club_cree() else 0,
		"favoris": Supporters.cles_favorites(supporters).size(), "niveau": niveau(),
		"stades": tampons.size(), "pays": lieux["pays"].size(), "continents": lieux["continents"].size(),
		"modes_suivi": modes, "meilleure_serie": meilleure_serie,
		"boulots_differents": boulots_faits, "boulots": int(stats.get("boulot", 0)),
		"album": collection["fanzzy"].size(), "primes": collection["primes"].size(),
	}, true)
	return e


## Petite annonce par-dessus n'importe quel écran quand un succès est gagné.
func _annonce_succes(liste: Array) -> void:
	if DisplayServer.get_name() == "headless" or not is_inside_tree() or liste.is_empty():
		return
	var couche := CanvasLayer.new()
	couche.layer = 51
	add_child(couche)
	var toast := Ui.panneau(Color(Ui.NUIT, 0.96), 20, 5)
	var h := Ui.hbox(14)
	h.add_child(Ui.icone(str(liste[0]["icone"]), 44))
	var v := Ui.vbox(0)
	v.add_child(Ui.label("SUCCÈS DÉBLOQUÉ" if liste.size() == 1 else tr("%d SUCCÈS DÉBLOQUÉS") % liste.size(), 18, Ui.JAUNE, true))
	var noms := ", ".join(liste.map(func(s): return str(s["titre"])))
	v.add_child(Ui.label(noms, 24, Ui.BLANC, true))
	h.add_child(v)
	toast.add_child(h)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	toast.offset_top = 24
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	couche.add_child(toast)
	Ui.pop(toast, 1.1)
	var tw := toast.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)
	tw.tween_callback(couche.queue_free)


# ---------------------------------------------------------------- sauvegarde

func sauver() -> void:
	sauve_le = maintenant()
	var gagnes := Succes.noter(succes, etat_succes(), sauve_le)
	if not gagnes.is_empty():
		for s in gagnes:
			Plateforme.debloquer(str(s["id"]))
		succes_gagnes.emit(gagnes)
		_annonce_succes.call_deferred(gagnes)
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
		"pass": etat_pass,
		"collection": collection,
		"duels_par_match": duels_par_match,
		"evenements": evenements,
		"succes": succes,
		"stats": stats,
		"sauve_le": sauve_le,
		"tournoi": tournoi,
		"demo_fin_vue": demo_fin_vue,
		"deplacement": deplacement,
		"stade_du_jour": stade_du_jour,
		"materiel": materiel,
		"grand_tour": grand_tour,
		"local": local_club,
		"ligue": ligue,
		"soirees": soirees,
	}
	var texte := JSON.stringify(d, "\t")
	var f := FileAccess.open(CHEMIN_SAUVEGARDE, FileAccess.WRITE)
	if f:
		f.store_string(texte)
		f.close()
	Plateforme.cloud_ecrire(FICHIER_CLOUD, texte)


## Lit la sauvegarde la plus récente entre ce PC (user://) et Steam Cloud.
## Si celle du Cloud gagne (partie jouée sur un autre PC), elle remplace la locale.
func charger() -> void:
	var locale: Variant = null
	if FileAccess.file_exists(CHEMIN_SAUVEGARDE):
		locale = JSON.parse_string(FileAccess.get_file_as_string(CHEMIN_SAUVEGARDE))
	var texte_cloud := Plateforme.cloud_lire(FICHIER_CLOUD)
	var cloud: Variant = JSON.parse_string(texte_cloud) if texte_cloud != "" else null
	var d: Variant = SauvegardeCloud.choisir(locale, cloud)
	if not d is Dictionary:
		return
	if d == cloud and cloud != locale:
		print("Sauvegarde : version Steam Cloud plus récente, reprise sur ce PC")
		var f := FileAccess.open(CHEMIN_SAUVEGARDE, FileAccess.WRITE)
		if f:
			f.store_string(texte_cloud)
			f.close()
	_appliquer(d)


func _appliquer(d: Dictionary) -> void:
	fan_club_nom = d.get("fan_club_nom", fan_club_nom)
	xp = Demo.xp_limitee(int(d.get("xp", 0)))
	demo_fin_vue = bool(d.get("demo_fin_vue", false))
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
	etat_pass = PassSaison.reparer(d.get("pass", null))
	_filtrer_fanzzy()
	# Un skin du PASS retiré ou un FANZZY bloqué ne doit pas casser la tribune.
	for id in skins.keys():
		if texture_skin(str(skins[id])) == null:
			skins.erase(id)
	collection = Collection.reparer(d.get("collection", null))
	var dm: Variant = d.get("duels_par_match", {})
	duels_par_match = dm if dm is Dictionary else {}
	var ev: Variant = d.get("evenements", null)
	evenements = ev if ev is Dictionary and ev.get("primes") is Dictionary else {"primes": {}}
	succes = Succes.reparer(d.get("succes", null))
	stats = Succes.reparer_stats(d.get("stats", null))
	sauve_le = int(d.get("sauve_le", 0))
	tournoi = Tournoi.reparer(d.get("tournoi", null))
	var dp: Variant = d.get("deplacement", {})
	deplacement = dp if dp is Dictionary else {}
	var sj: Variant = d.get("stade_du_jour", {})
	stade_du_jour = sj if sj is Dictionary else {}
	materiel = Materiel.reparer(d.get("materiel", null))
	local_club = LocalClub.reparer(d.get("local", null))
	var gt: Variant = d.get("grand_tour", {})
	grand_tour = gt if gt is Dictionary else {}
	ligue = Ligue.reparer(d.get("ligue", null))
	soirees = SoireeMatch.reparer(d.get("soirees", null))
	# Un FANZZY retiré du catalogue ne doit pas casser la tribune.
	for i in equipe.size():
		if fanzzy_par_id(str(equipe[i])).is_empty():
			equipe = []
			break


func reinitialiser() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CHEMIN_SAUVEGARDE))
	Plateforme.cloud_effacer(FICHIER_CLOUD)
	fan_club_nom = "Ultras du Canal"  # sans_traduction
	xp = 0
	position_club = {"nom": "Paris", "lat": 48.86, "lon": 2.35}  # sans_traduction
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
	etat_pass = PassSaison.vide()
	_filtrer_fanzzy()
	actualiser_pass()
	collection = Collection.vide()
	duels_par_match = {}
	evenements = {"primes": {}}
	# Les succès déjà envoyés à Steam y restent ; ici on repart de zéro.
	succes = {}
	stats = {}
	sauve_le = 0
	tournoi = Tournoi.vide()
	demo_fin_vue = false
	deplacement = {}
	stade_du_jour = {}
	materiel = {}
	grand_tour = {}
	local_club = LocalClub.vide()
	ligue = Ligue.vide()
	soirees = SoireeMatch.vide()
	equipe = equipe_par_defaut()
