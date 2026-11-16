class_name Rythme
extends RefCounted
## Le rythme d'un chant : BPM, grille des temps, fenêtres de jugement.
##
## Aucun nœud, aucun son : que des calculs, testables sans écran. Un duel s'en
## sert pour savoir où tombent les notes et juger un appui ; le ChantLecteur
## s'en sert pour savoir quand frapper.
##
##   var r := Rythme.depuis_chant(Rythme.chant("contretemps"))
##   var notes := r.notes_joueur(4)          # instants (s) des appuis attendus
##   var j := r.juger(0.27, notes[0])        # {"note": "parfait", "ecart": 0.01}
##
## Les temps sont en secondes depuis le début du chant (le premier temps de la
## première mesure tombe à `debut`).

const CHEMIN_CHANTS := "res://data/audio/chants.json"

## Les fenêtres par défaut, les mêmes que le prototype du duel.
const FENETRE_PARFAIT := 0.055
const FENETRE_BIEN := 0.13
## Au-delà de bien × ce facteur, un appui ne compte pas comme une tentative
## sur cette note (le joueur visait autre chose).
const FACTEUR_HORS := 2.2

const FORCES := {"X": 1.0, "x": 0.75, "o": 0.45}

var bpm := 112.0
## Accélération : BPM ajoutés à chaque mesure, et le plafond.
var bpm_par_mesure := 0.0
var bpm_max := 220.0
var temps_par_mesure := 4
var pas_par_temps := 4
## Instant (s) du premier temps.
var debut := 0.0
## Fenêtres de jugement (s), et un multiplicateur (bonus d'équipe, réglage
## d'accessibilité) qui les élargit ou les resserre.
var fenetre_parfait := FENETRE_PARFAIT
var fenetre_bien := FENETRE_BIEN
var tolerance := 1.0
## Les pistes : voix -> PackedFloat32Array de forces, une par pas (0 = rien).
var pistes: Dictionary = {}

static var _chants_cache: Dictionary = {}


# ------------------------------------------------------------- construire

static func depuis_chant(chant: Dictionary, bpm_force := 0.0, debut_s := 0.0) -> Rythme:
	var r := Rythme.new()
	r.bpm = bpm_force if bpm_force > 0.0 else float(chant.get("bpm", 112.0))
	r.bpm_par_mesure = float(chant.get("bpm_par_mesure", 0.0))
	r.bpm_max = float(chant.get("bpm_max", 220.0))
	r.temps_par_mesure = int(chant.get("temps_par_mesure", 4))
	r.pas_par_temps = int(chant.get("pas_par_temps", 4))
	r.debut = debut_s
	var p: Dictionary = chant.get("pistes", {})
	for voix in p:
		r.pistes[voix] = Rythme.lire_piste(String(p[voix]), r.pas_par_mesure())
	return r


## « X..x » -> [1.0, 0, 0, 0.75], répété ou coupé à `longueur` pas.
static func lire_piste(motif: String, longueur: int) -> PackedFloat32Array:
	var propre := motif.replace(" ", "").replace("|", "")
	var res := PackedFloat32Array()
	res.resize(longueur)
	if propre.is_empty():
		return res
	for i in longueur:
		res[i] = float(FORCES.get(propre[i % propre.length()], 0.0))
	return res


## Tous les chants de data/audio/chants.json, par identifiant.
static func chants() -> Dictionary:
	if _chants_cache.is_empty():
		var f := FileAccess.open(CHEMIN_CHANTS, FileAccess.READ)
		if f == null:
			push_warning("Rythme : %s introuvable" % CHEMIN_CHANTS)  # sans_traduction
			return {}
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			for c in d.get("chants", []):
				_chants_cache[String(c["id"])] = c
	return _chants_cache


static func chant(id: String) -> Dictionary:
	return chants().get(id, {})


# ------------------------------------------------------------- la grille

func pas_par_mesure() -> int:
	return temps_par_mesure * pas_par_temps


## Le BPM de la mesure `m` (accélération comprise).
func bpm_de_mesure(m: int) -> float:
	return minf(bpm + bpm_par_mesure * m, maxf(bpm, bpm_max))


func duree_temps(m := 0) -> float:
	return 60.0 / bpm_de_mesure(m)


func duree_mesure(m := 0) -> float:
	return duree_temps(m) * temps_par_mesure


## L'instant (s) où commence la mesure `m`.
func debut_mesure(m: int) -> float:
	if bpm_par_mesure == 0.0:
		return debut + m * duree_mesure()
	var t := debut
	for k in m:
		t += duree_mesure(k)
	return t


## L'instant (s) du pas `pas` (0..pas_par_mesure-1) de la mesure `m`.
func instant_pas(m: int, pas: int) -> float:
	return debut_mesure(m) + pas * duree_temps(m) / pas_par_temps


## L'instant (s) du temps `i`, compté depuis le début.
func instant_temps(i: int) -> float:
	var m := floori(float(i) / temps_par_mesure)
	return debut_mesure(m) + (i - m * temps_par_mesure) * duree_temps(m)


## Où en est-on, en temps (fractionnaires), à l'instant `t` ? (tempo fixe)
func temps_a(t: float) -> float:
	return (t - debut) / duree_temps()


## Les frappes (hors piste J) de la mesure `m` : [{t, voix, force, mesure, pas}].
func frappes_de_mesure(m: int, voix_voulues: Array = []) -> Array:
	var res: Array = []
	for voix in pistes:
		if voix == "J" or (not voix_voulues.is_empty() and not voix in voix_voulues):
			continue
		var p: PackedFloat32Array = pistes[voix]
		for i in p.size():
			if p[i] > 0.0:
				res.append({"t": instant_pas(m, i), "voix": voix, "force": p[i], "mesure": m, "pas": i})
	res.sort_custom(func(a, b): return a["t"] < b["t"])
	return res


## Toutes les frappes sur `mesures` mesures, triées dans le temps.
func frappes(mesures: int, voix_voulues: Array = []) -> Array:
	var res: Array = []
	for m in mesures:
		res.append_array(frappes_de_mesure(m, voix_voulues))
	res.sort_custom(func(a, b): return a["t"] < b["t"])
	return res


## Les instants (s) où le joueur doit appuyer (piste « J »), sur `mesures`
## mesures. Sans piste J : chaque temps.
func notes_joueur(mesures: int) -> PackedFloat32Array:
	var res := PackedFloat32Array()
	var p: PackedFloat32Array = pistes.get("J", PackedFloat32Array())
	for m in mesures:
		if p.is_empty():
			for k in temps_par_mesure:
				res.append(instant_pas(m, k * pas_par_temps))
		else:
			for i in p.size():
				if p[i] > 0.0:
					res.append(instant_pas(m, i))
	return res


func duree(mesures: int) -> float:
	return debut_mesure(mesures) - debut


# ------------------------------------------------------------- le jugement

## Juge un appui à l'instant `t_appui` contre la note `t_cible`.
## Rend {"note": "parfait"|"bien"|"rate"|"hors", "ecart": s (négatif = en avance)}.
## « hors » : trop loin pour être une tentative sur cette note.
func juger(t_appui: float, t_cible: float) -> Dictionary:
	return Rythme.juger_ecart(t_appui - t_cible, fenetre_parfait * tolerance, fenetre_bien * tolerance)


static func juger_ecart(ecart: float, parfait := FENETRE_PARFAIT, bien := FENETRE_BIEN) -> Dictionary:
	var a := absf(ecart)
	var note := "hors"
	if a <= parfait:
		note = "parfait"
	elif a <= bien:
		note = "bien"
	elif a <= bien * FACTEUR_HORS:
		note = "rate"
	return {"note": note, "ecart": ecart}


## L'indice de la note la plus proche de `t` dans `notes` (triées), ou -1.
static func plus_proche(notes: PackedFloat32Array, t: float, a_partir_de := 0) -> int:
	var meilleur := -1
	var e := INF
	for i in range(a_partir_de, notes.size()):
		var d := absf(notes[i] - t)
		if d < e:
			e = d
			meilleur = i
		elif notes[i] > t:
			break
	return meilleur


# ------------------------------------------------------------- l'horloge

## Ce qui sépare l'instant où l'on demande un son de l'instant où il
## s'entend : la latence de sortie, plus le paquet que le mixeur prépare.
## À retrancher de l'horloge du jeu pour juger sur ce que le joueur entend.
static func latence_sortie() -> float:
	return AudioServer.get_output_latency() + AudioServer.get_time_to_next_mix()


## L'instant entendu d'un lecteur en cours (méthode de la documentation de
## Godot, « Sync the gameplay with audio and music ») : à utiliser quand un
## morceau sert d'horloge.
static func position_entendue(lecteur: AudioStreamPlayer) -> float:
	return lecteur.get_playback_position() + AudioServer.get_time_since_last_mix() \
		- AudioServer.get_output_latency()
