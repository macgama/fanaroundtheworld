class_name ChantClub
extends RefCounted
## Le chant du fan club : composé dans le créateur de chants, chanté en duel.
##
## Une composition, c'est un nom, un tempo et 4 à 8 mesures. Chaque mesure
## prend un **morceau** (un motif rythmique d'une mesure) et une **parole**
## (une ligne courte, affichée façon karaoké pendant le duel). Les briques
## sont dans data/audio/morceaux_chant.json ; les morceaux, paroles et
## tempos se débloquent avec le niveau du joueur (jamais contre des Jetons).
##
##   var c := ChantClub.par_defaut()
##   c["mesures"][1]["morceau"] = "echo"
##   if ChantClub.erreurs(c, Game.niveau()).is_empty():
##       Game.club["chant"] = c
##
## Aucun nœud, aucun son : que des règles, testables sans écran.
## Le ChantLecteur joue `vers_fiche(c)` ; le duel suit `programme(c, nom)`.

const CHEMIN := "res://data/audio/morceaux_chant.json"
const NOM_MAX := 28
const PAS := 8                 # pas par mesure (deux par temps)
const TEMPS := 4               # temps par mesure

## En duel, le chant du club rapporte un peu plus que les motifs au hasard…
const BONUS_POINTS := 1.05
## … et chaque couplet complet sans erreur charge le tifo et donne des points.
const BONUS_COUPLET_TIFO := 20.0
const BONUS_COUPLET_POINTS := 60

static var _cache: Dictionary = {}


# ------------------------------------------------------------- catalogue

static func catalogue() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(CHEMIN, FileAccess.READ)
		if f == null:
			push_warning("ChantClub : %s introuvable" % CHEMIN)  # sans_traduction
			return {}
		var d: Variant = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_cache = d
	return _cache


static func morceaux() -> Array:
	return catalogue().get("morceaux", [])


static func paroles() -> Array:
	return catalogue().get("paroles", [])


static func tempos() -> Array:
	return catalogue().get("tempos", [])


static func mesures_min() -> int:
	return int(catalogue().get("mesures_min", 4))


static func mesures_max() -> int:
	return int(catalogue().get("mesures_max", 8))


static func _par_id(liste: Array, id: String) -> Dictionary:
	for e in liste:
		if String(e.get("id", "")) == id:
			return e
	return {}


static func morceau(id: String) -> Dictionary:
	return _par_id(morceaux(), id)


static func parole(id: String) -> Dictionary:
	return _par_id(paroles(), id)


static func tempo(id: String) -> Dictionary:
	return _par_id(tempos(), id)


## Une brique (morceau, parole ou tempo) est-elle ouverte à ce niveau ?
static func debloque(brique: Dictionary, niveau: int) -> bool:
	return not brique.is_empty() and int(brique.get("niveau", 1)) <= niveau


# ------------------------------------------------------------- composition

## Le premier chant proposé : tout est ouvert dès le niveau 1.
static func par_defaut() -> Dictionary:
	return {
		"nom": "Le chant du club",
		"tempo": "entrainant",
		"mesures": [
			{"morceau": "quatre_temps", "parole": "allez_club"},
			{"morceau": "marche", "parole": "on_est_la"},
			{"morceau": "quatre_temps", "parole": "allez_club"},
			{"morceau": "appel", "parole": "hey"},
		],
	}


## Remet d'aplomb une composition lue dans une sauvegarde : {} si elle
## n'a pas la bonne forme (le duel reprend alors les motifs au hasard).
static func reparer(c: Variant) -> Dictionary:
	if not c is Dictionary or c.is_empty():
		return {}
	var mesures: Variant = c.get("mesures", [])
	if not mesures is Array:
		return {}
	var propres: Array = []
	for m in mesures:
		if not m is Dictionary:
			continue
		var mo := String(m.get("morceau", ""))
		if morceau(mo).is_empty():
			continue
		var pa := String(m.get("parole", ""))
		propres.append({"morceau": mo, "parole": pa if not parole(pa).is_empty() else ""})
	if propres.size() < mesures_min():
		return {}
	propres.resize(mini(propres.size(), mesures_max()))
	var t := String(c.get("tempo", "entrainant"))
	return {
		"nom": String(c.get("nom", "")).strip_edges().left(NOM_MAX),
		"tempo": t if not tempo(t).is_empty() else "entrainant",
		"mesures": propres,
	}


## Ce qui empêche d'enregistrer ce chant, en clair. Vide : tout va bien.
static func erreurs(c: Dictionary, niveau: int) -> Array:
	var res: Array = []
	var nom := String(c.get("nom", "")).strip_edges()
	if nom.is_empty():
		res.append("Donne un nom à ton chant.")
	elif nom.length() > NOM_MAX:
		res.append(Trad.t("Le nom est trop long (%d lettres au plus).") % NOM_MAX)
	var t := tempo(String(c.get("tempo", "")))
	if t.is_empty():
		res.append("Choisis un tempo.")
	elif not debloque(t, niveau):
		res.append(Trad.t("Le tempo « %s » s'ouvre au niveau %d.") % [Trad.t(t["nom"]), int(t["niveau"])])
	var mesures: Array = c.get("mesures", [])
	if mesures.size() < mesures_min():
		res.append(Trad.t("Il faut au moins %d mesures.") % mesures_min())
	elif mesures.size() > mesures_max():
		res.append(Trad.t("Pas plus de %d mesures.") % mesures_max())
	for i in mesures.size():
		var m: Dictionary = mesures[i]
		var mo := morceau(String(m.get("morceau", "")))
		if mo.is_empty():
			res.append(Trad.t("Mesure %d : choisis un morceau.") % (i + 1))
		elif not debloque(mo, niveau):
			res.append(Trad.t("Mesure %d : « %s » s'ouvre au niveau %d.") % [i + 1, Trad.t(mo["nom"]), int(mo["niveau"])])
		var pid := String(m.get("parole", ""))
		if pid != "":
			var pa := parole(pid)
			if pa.is_empty():
				res.append(Trad.t("Mesure %d : parole inconnue.") % (i + 1))
			elif not debloque(pa, niveau):
				res.append(Trad.t("Mesure %d : cette parole s'ouvre au niveau %d.") % [i + 1, int(pa["niveau"])])
	if not mesures.is_empty() and nb_appuis(c) == 0:
		res.append("Ton chant n'a aucun clap pour la tribune.")
	return res


static func bpm(c: Dictionary) -> float:
	return float(tempo(String(c.get("tempo", ""))).get("bpm", 112.0))


## Les pas (0..7) où le joueur doit frapper dans ce morceau.
static func appuis(morceau_id: String) -> Array:
	var res: Array = []
	var j := String(morceau(morceau_id).get("pistes", {}).get("J", ""))
	for i in mini(j.length(), PAS):
		if Rythme.FORCES.has(j[i]):
			res.append(i)
	return res


static func nb_appuis(c: Dictionary) -> int:
	var n := 0
	for m in c.get("mesures", []):
		n += appuis(String(m.get("morceau", ""))).size()
	return n


## Durée d'un couplet complet (s).
static func duree(c: Dictionary) -> float:
	return c.get("mesures", []).size() * TEMPS * 60.0 / bpm(c)


## Difficulté de 1 à 5 étoiles : la moyenne des morceaux, relevée par le
## tempo et par le nombre de claps.
static func etoiles(c: Dictionary) -> int:
	var mesures: Array = c.get("mesures", [])
	if mesures.is_empty():
		return 1
	var somme := 0.0
	for m in mesures:
		somme += float(morceau(String(m.get("morceau", ""))).get("difficulte", 1))
	var moy := somme / mesures.size()                      # 1..3
	var densite := float(nb_appuis(c)) / mesures.size()    # claps par mesure
	var score := moy + (bpm(c) - 112.0) / 24.0 + maxf(0.0, densite - 3.0) * 0.4
	return clampi(int(round(score * 1.6 - 0.6)), 1, 5)


# ------------------------------------------------------------- paroles

## Le nom du club tel qu'on le crie : les noms longs passent au sigle.
static func nom_crie(nom_club: String) -> String:
	var n := nom_club.strip_edges()
	if n.is_empty():
		return "le club"
	return n if n.length() <= 14 else FanClub.sigle(n)


static func texte_parole(id: String, nom_club: String) -> String:
	var p := parole(id)
	if p.is_empty():
		return ""
	return Trad.t(String(p["texte"])).replace("{club}", nom_crie(nom_club))  # sans_traduction


## Répartit les mots d'une ligne sur `n` claps : un mot par clap, et quand
## il y a plus de mots que de claps, les derniers sont regroupés.
## Les claps sans mot reçoivent "".
static func mots_sur_appuis(texte: String, n: int) -> Array:
	var res: Array = []
	if n <= 0:
		return res
	var mots := Array(texte.split(" ", false))
	for i in n:
		res.append("")
	if mots.is_empty():
		return res
	if mots.size() <= n:
		for i in mots.size():
			res[i] = mots[i]
	else:
		for i in n - 1:
			res[i] = mots[i]
		res[n - 1] = " ".join(mots.slice(n - 1))
	return res


# ------------------------------------------------------------- lecture

## La fiche « chant » que lisent Rythme et ChantLecteur : tout le couplet en
## une seule grande mesure de 4 × N temps. `avec_claps` : la tribune claque
## aussi les appuis J (pour l'écoute ; en duel, c'est le joueur qui claque).
static func vers_fiche(c: Dictionary, avec_claps := true) -> Dictionary:
	var mesures: Array = c.get("mesures", [])
	var voix := {}
	for m in mesures:
		for v in morceau(String(m.get("morceau", ""))).get("pistes", {}):
			voix[v] = true
	if avec_claps:
		voix["C"] = true
	var pistes := {}
	for v in voix:
		var s := ""
		for m in mesures:
			var p: Dictionary = morceau(String(m.get("morceau", ""))).get("pistes", {})
			var motif := String(p.get("J" if v == "C" else v, ""))
			s += (motif + "........").left(PAS)
		pistes[v] = s
	return {
		"id": "club",
		"nom": String(c.get("nom", "")),
		"bpm": bpm(c),
		"temps_par_mesure": TEMPS * mesures.size(),
		"pas_par_temps": PAS / TEMPS,
		"pistes": pistes,
	}


## Le couplet mesure par mesure, pour le duel :
## [{morceau, texte, appuis: [pas], mots: [un par appui], frappes: [{pas, voix, force}]}]
static func programme(c: Dictionary, nom_club: String) -> Array:
	var res: Array = []
	for m in c.get("mesures", []):
		var id := String(m.get("morceau", ""))
		var mo := morceau(id)
		var ap := appuis(id)
		var texte := texte_parole(String(m.get("parole", "")), nom_club)
		var frappes: Array = []
		var pistes: Dictionary = mo.get("pistes", {})
		for v in pistes:
			if v == "J":
				continue
			var motif := String(pistes[v])
			for i in mini(motif.length(), PAS):
				if Rythme.FORCES.has(motif[i]):
					frappes.append({"pas": i, "voix": String(v), "force": float(Rythme.FORCES[motif[i]])})
		res.append({"morceau": id, "nom": Trad.t(String(mo.get("nom", id))), "texte": texte, "appuis": ap,
			"mots": mots_sur_appuis(texte, ap.size()), "frappes": frappes})
	return res
