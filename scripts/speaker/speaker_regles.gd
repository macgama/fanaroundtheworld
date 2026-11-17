class_name SpeakerRegles
extends RefCounted
## Règles du petit boulot « speaker du stade », sans affichage (testables).
##
## Le joueur tient le micro du stade pendant un match plein de buts. À chaque
## but de l'équipe locale, l'écran géant montre le numéro du buteur : il faut
## retrouver son nom dans la feuille de match (touches 1 à 4) et lancer
## l'annonce **dans le tempo**, comme au stade :
##     speaker : « LÉO ! »        tribune : « MARTIN ! »   (trois fois)
## Chaque appel est jugé comme une note de rythme (Rythme.juger_ecart) :
## parfait ou bien, et seulement si c'est le bon joueur. Les trois appels
## justes d'un même but donnent un bonus. Quand ce sont les visiteurs qui
## marquent, le speaker reste sobre : ne rien annoncer rapporte un petit plus.
## Le tempo monte d'un but à l'autre.
## Au-delà de SERVICES_PLEIN_TARIF matchs dans la journée, la paye baisse (÷ 2, puis ÷ 4) :
## voir ListeBoulots.part_du_jour.

const NB_BUTS := 7
const NB_BUTS_VISITEURS := 2
const NB_JOUEURS := 4          # joueurs de la feuille de match proposés au speaker
const APPELS_PAR_BUT := 3
const BPM_DEPART := 96.0
const BPM_PAR_BUT := 6.0       # le stade s'emballe : +6 BPM par but local
const BPM_MAX := 132.0
const TEMPS_PAR_MESURE := 4
## Mesures d'un but local : 1 de célébration (lire le numéro) + 1 par appel.
const MESURES_BUT := 1 + APPELS_PAR_BUT
const MESURES_BUT_VISITEURS := 2
const PAUSE_ENTRE_BUTS := 1.4  # secondes

const PAYE_APPEL := {"parfait": 3, "bien": 2}
const BONUS_TRIPLE := 2        # les trois appels d'un but justes
const PAYE_SILENCE := 1        # but des visiteurs, pas d'annonce
const XP_PAR_BUT := 2          # but local annoncé au moins une fois
const SERVICES_PLEIN_TARIF := ListeBoulots.PLEIN_TARIF

## Prénoms et noms des joueurs (inventés, courts pour être criés).
const PRENOMS := [
	"Léo", "Hugo", "Nina", "Sami", "Yanis", "Inès", "Malo", "Lina", "Théo", "Zoé",  # sans_traduction
	"Ilan", "Maé", "Enzo", "Jade", "Noah", "Lou", "Adam", "Rayan", "Tom", "Lisa",  # sans_traduction
	"Nael", "Kenzo", "Iris", "Milo", "Amir", "Sofia", "Elio", "Tess", "Liam", "Yara",  # sans_traduction
]
const NOMS := [
	"Martin", "Dubois", "Moreau", "Lefort", "Garnier", "Petitjean", "Rocher", "Ferrand",  # sans_traduction
	"Belmonte", "Kanté", "Diallo", "Navarro", "Okafor", "Silva", "Rossi", "Lambert",  # sans_traduction
	"Mercier", "Bonnet", "Traoré", "Costa", "Varenne", "Duval", "Ndiaye", "Marchetti",  # sans_traduction
	"Leroux", "Benali", "Fontaine", "Morel", "Santos", "Keita",  # sans_traduction
]
const NUMEROS := [7, 9, 10, 11, 14, 17, 19, 20, 21, 22, 23, 27]

var rng := RandomNumberGenerator.new()


func _init(graine := -1) -> void:
	if graine >= 0:
		rng.seed = graine
	else:
		rng.randomize()


## La feuille de match : NB_JOUEURS joueurs, numéros et prénoms tous différents.
## [{numero, prenom, nom}]
func feuille_de_match() -> Array:
	var numeros := NUMEROS.duplicate()
	var prenoms := PRENOMS.duplicate()
	var noms := NOMS.duplicate()
	_melanger(numeros)
	_melanger(prenoms)
	_melanger(noms)
	var res: Array = []
	for i in NB_JOUEURS:
		res.append({"numero": numeros[i], "prenom": prenoms[i], "nom": noms[i]})
	return res


## Le déroulé du match : NB_BUTS buts, le premier toujours pour les locaux.
## [{local: bool, buteur: indice dans la feuille (-1 pour les visiteurs),
##   ordre: ordre des boutons (indices de la feuille), bpm}]
func programme() -> Array:
	var camps: Array = []
	for i in NB_BUTS - NB_BUTS_VISITEURS:
		camps.append(true)
	for i in NB_BUTS_VISITEURS:
		camps.append(false)
	_melanger(camps)
	# Le premier but est local (on apprend avant d'être piégé), et jamais deux
	# buts des visiteurs d'affilée.
	for essai in 50:
		var ok: bool = camps[0]
		for i in range(1, camps.size()):
			if not camps[i] and not camps[i - 1]:
				ok = false
		if ok:
			break
		_melanger(camps)
	if not camps[0]:
		camps.erase(true)
		camps.push_front(true)
	var res: Array = []
	var locaux := 0
	var dernier := -1
	for local in camps:
		var b := {"local": local, "buteur": -1, "ordre": [], "bpm": bpm_du_but(locaux)}
		if local:
			var buteur := rng.randi_range(0, NB_JOUEURS - 1)
			if buteur == dernier and rng.randf() < 0.6:
				buteur = (buteur + 1 + rng.randi_range(0, NB_JOUEURS - 2)) % NB_JOUEURS
			b["buteur"] = buteur
			dernier = buteur
			locaux += 1
		var ordre: Array = range(NB_JOUEURS)
		# Les deux premiers buts gardent l'ordre de la feuille ; ensuite les
		# boutons sont mélangés à chaque but : il faut relire.
		if locaux > 2 or not local:
			_melanger(ordre)
		b["ordre"] = ordre
		res.append(b)
	return res


static func bpm_du_but(buts_locaux_avant: int) -> float:
	return minf(BPM_DEPART + BPM_PAR_BUT * buts_locaux_avant, BPM_MAX)


static func mesures_du_but(but: Dictionary) -> int:
	return MESURES_BUT if bool(but.get("local", true)) else MESURES_BUT_VISITEURS


static func duree_temps(bpm: float) -> float:
	return 60.0 / bpm


static func duree_but(but: Dictionary) -> float:
	return mesures_du_but(but) * TEMPS_PAR_MESURE * duree_temps(float(but["bpm"]))


## Ce qui se passe pendant un but, à partir de l'instant `debut` (s) :
##   frappes : [{t, son, force}] (tambour, clameur, réponse de la tribune…)
##   appels  : instants où le speaker doit annoncer (1er temps des mesures 1 à 3)
##   reponses: instants où la tribune répond le nom (3e temps)
##   fin     : instant de fin du but
static func chronologie(but: Dictionary, debut: float) -> Dictionary:
	var d := duree_temps(float(but["bpm"]))
	var frappes: Array = []
	var appels: Array = []
	var reponses: Array = []
	var nb := mesures_du_but(but)
	var local := bool(but.get("local", true))
	frappes.append({"t": debut, "son": "clameur_but" if local else "deception", "force": 1.0})
	for m in nb:
		for k in TEMPS_PAR_MESURE:
			var t := debut + (m * TEMPS_PAR_MESURE + k) * d
			if not local:
				# but des visiteurs : un tambour sourd, une mesure sur deux
				if k == 0:
					frappes.append({"t": t, "son": "tambour", "force": 0.5})
				continue
			frappes.append({"t": t, "son": "tambour", "force": 1.0 if k % 2 == 0 else 0.7})
			if m == 0:
				if k == 3:
					frappes.append({"t": t, "son": "clap", "force": 0.8})
				continue
			if k == 0:
				appels.append(t)
			elif k == 2:
				reponses.append(t)
				frappes.append({"t": t, "son": "cri_groupe", "force": 1.0})
			elif k == 3:
				frappes.append({"t": t, "son": "clap", "force": 0.8})
	frappes.sort_custom(func(a, b): return a["t"] < b["t"])
	return {"frappes": frappes, "appels": appels, "reponses": reponses, "fin": debut + nb * TEMPS_PAR_MESURE * d}


## Le jugement d'un appel : la justesse du tempo, et le bon joueur.
## Rend "parfait" | "bien" | "rate" (à côté du tempo) | "faux" (mauvais joueur)
## | "hors" (trop loin de l'appel pour compter).
static func juger(ecart: float, bon_joueur: bool) -> String:
	var note: String = Rythme.juger_ecart(ecart)["note"]
	if note == "hors":
		return "hors"
	if not bon_joueur:
		return "faux"
	return note


static func paye_appel(note: String) -> int:
	return int(PAYE_APPEL.get(note, 0))


## Paye d'un but local d'après les notes de ses appels.
static func paye_but(notes: Array) -> Dictionary:
	var appels := 0
	var justes := 0
	for n in notes:
		appels += paye_appel(String(n))
		if PAYE_APPEL.has(String(n)):
			justes += 1
	var bonus := BONUS_TRIPLE if justes >= APPELS_PAR_BUT else 0
	return {"appels": appels, "bonus": bonus, "justes": justes, "total": appels + bonus}


## Paye du match entier, selon le nombre de matchs déjà faits aujourd'hui.
static func paye_finale(brut: int, services_du_jour: int) -> int:
	return ListeBoulots.paye_du_jour(brut, services_du_jour)


## L'annonce d'un joueur, comme au stade : [prénom, NOM].
static func annonce(joueur: Dictionary) -> Array:
	return [String(joueur["prenom"]).to_upper() + " !", String(joueur["nom"]).to_upper() + " !"]


func _melanger(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var x = a[i]
		a[i] = a[j]
		a[j] = x
