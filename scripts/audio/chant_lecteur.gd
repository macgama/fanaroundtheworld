class_name ChantLecteur
extends Node
## Joue un chant rythmé (data/audio/chants.json) et juge les appuis du joueur.
##
## Autonome : il crée ses propres lecteurs sur le bus « Chants » et lit le
## catalogue lui-même. L'autoload Sons n'est pas nécessaire.
##
##   var chant := ChantLecteur.new()
##   add_child(chant)
##   chant.appui_juge.connect(func(r): print(r.note))
##   chant.lancer("contretemps", 0.0, 8)        # BPM du chant, 8 mesures
##   ...
##   func _unhandled_input(e): if e.is_action_pressed("ui_accept"): chant.juger_appui()
##
## L'horloge est celle du système (Time.get_ticks_usec), pas les `delta` des
## images qui dérivent. Le jugement se fait sur ce que le joueur **entend** :
## la latence de sortie est retranchée (voir Rythme.latence_sortie).

signal frappe(voix: String, force: float, t: float)
signal mesure(numero: int)
## Rendu de chaque appui : {note, ecart, index, t}.
signal appui_juge(resultat: Dictionary)
## Une note attendue est passée sans appui.
signal note_manquee(index: int, t: float)
signal fini

@export var bus := "Chants"  # sans_traduction
@export var polyphonie := 12
## Correction manuelle de latence (s), pour un réglage « calibrer » du joueur.
@export var calibrage := 0.0
## Multiplie les fenêtres de jugement (bonus d'équipe, accessibilité).
@export var tolerance := 1.0
## Joue les sons des voix. Faux : le chant ne fait que battre la mesure
## (signaux) et c'est le jeu qui décide quoi faire entendre.
@export var sonore := true
## Voix à ne pas jouer (par exemple « C » quand c'est le joueur qui claque).
@export var voix_muettes: Array[String] = []

var rythme: Rythme
var chant_id := ""
var mesures := 0  ## 0 : sans fin, jusqu'à arreter()
var notes := PackedFloat32Array()
var en_cours := false

var _lecteurs: Array[AudioStreamPlayer] = []
var _suivant := 0
var _depart_us := 0
var _pause_us := 0
var _en_pause := false
var _a_jouer: Array = []
var _mesure_preparee := -1
var _jugees: Dictionary = {}
var _premiere_ouverte := 0


func _ready() -> void:
	_creer_lecteurs()


func _creer_lecteurs() -> void:
	if not _lecteurs.is_empty():
		return
	for i in polyphonie:
		var p := AudioStreamPlayer.new()
		p.bus = BanqueSons.bus(bus)
		add_child(p)
		_lecteurs.append(p)


## Lance un chant. `chant` : un identifiant de chants.json ou une fiche.
## `delai` : secondes avant le premier temps (le temps de lire la piste).
func lancer(chant: Variant, bpm := 0.0, nb_mesures := 8, delai := 1.0) -> bool:
	var fiche: Dictionary = chant if chant is Dictionary else Rythme.chant(String(chant))
	if fiche.is_empty():
		push_warning("ChantLecteur : chant inconnu %s" % str(chant))  # sans_traduction
		return false
	chant_id = String(fiche.get("id", ""))
	rythme = Rythme.depuis_chant(fiche, bpm, delai)
	rythme.tolerance = tolerance
	mesures = nb_mesures
	_a_jouer.clear()
	_jugees.clear()
	_premiere_ouverte = 0
	_mesure_preparee = -1
	notes = PackedFloat32Array()
	_preparer_jusqua(1 if mesures <= 0 else mini(mesures, 2))
	_depart_us = Time.get_ticks_usec()
	_pause_us = 0
	_en_pause = false
	en_cours = true
	set_process(true)
	return true


func arreter() -> void:
	en_cours = false
	set_process(false)
	_a_jouer.clear()


func mettre_en_pause(oui: bool) -> void:
	if oui == _en_pause or not en_cours:
		return
	_en_pause = oui
	if oui:
		_pause_us = Time.get_ticks_usec()
	else:
		_depart_us += Time.get_ticks_usec() - _pause_us


## L'horloge du chant (s) : 0 au lancement, le premier temps à `delai`.
func temps() -> float:
	if not en_cours:
		return 0.0
	var maintenant := _pause_us if _en_pause else Time.get_ticks_usec()
	return float(maintenant - _depart_us) / 1_000_000.0


## L'instant que le joueur entend en ce moment.
func temps_entendu() -> float:
	return temps() - Rythme.latence_sortie() - calibrage


## Juge un appui, maintenant. Rend {note, ecart, index, t} ; « hors » quand
## aucune note n'est assez proche (l'appui ne consomme alors aucune note).
func juger_appui() -> Dictionary:
	var t := temps_entendu()
	var i := -1
	var meilleur := INF
	for k in range(_premiere_ouverte, notes.size()):
		if notes[k] > t + 1.0:
			break
		if not _jugees.has(k) and absf(notes[k] - t) < meilleur:
			meilleur = absf(notes[k] - t)
			i = k
	var r := {"note": "hors", "ecart": 0.0, "index": -1, "t": t}
	if i >= 0:
		var j := rythme.juger(t, notes[i])
		r = {"note": j["note"], "ecart": j["ecart"], "index": i, "t": t}
		if j["note"] != "hors":
			_jugees[i] = j["note"]
	appui_juge.emit(r)
	return r


## Les notes à venir dans les `horizon` prochaines secondes : de quoi
## dessiner la piste. [{index, t}]
func notes_a_venir(horizon := 2.0) -> Array:
	var t := temps_entendu()
	var res: Array = []
	for i in range(_premiere_ouverte, notes.size()):
		if notes[i] > t + horizon:
			break
		if not _jugees.has(i):
			res.append({"index": i, "t": notes[i]})
	return res


func _process(_delta: float) -> void:
	if not en_cours or _en_pause:
		return
	var t := temps()
	# Préparer une mesure d'avance.
	var m_courante := _mesure_a(t)
	var voulue := m_courante + 2
	if mesures > 0:
		voulue = mini(voulue, mesures)
	_preparer_jusqua(voulue)
	# Frapper ce qui est dû.
	while not _a_jouer.is_empty() and _a_jouer[0]["t"] <= t:
		var f: Dictionary = _a_jouer.pop_front()
		if t - float(f["t"]) < 0.1:  # trop en retard (fenêtre cachée) : on se tait
			_frapper(f)
		frappe.emit(f["voix"], f["force"], f["t"])
	# Les notes manquées.
	var te := temps_entendu()
	var limite := rythme.fenetre_bien * rythme.tolerance
	while _premiere_ouverte < notes.size() and notes[_premiere_ouverte] < te - limite:
		if not _jugees.has(_premiere_ouverte):
			_jugees[_premiere_ouverte] = "manquee"
			note_manquee.emit(_premiere_ouverte, notes[_premiere_ouverte])
		_premiere_ouverte += 1
	if mesures > 0 and _a_jouer.is_empty() and te > rythme.debut_mesure(mesures) + limite:
		arreter()
		fini.emit()


func _mesure_a(t: float) -> int:
	var m := 0
	while rythme.debut_mesure(m + 1) <= t and m < 100000:
		m += 1
	return m


func _preparer_jusqua(nb: int) -> void:
	while _mesure_preparee + 1 < nb:
		_mesure_preparee += 1
		var m := _mesure_preparee
		mesure.emit(m)
		_a_jouer.append_array(rythme.frappes_de_mesure(m))
		var p: PackedFloat32Array = rythme.pistes.get("J", PackedFloat32Array())
		if p.is_empty():
			for k in rythme.temps_par_mesure:
				notes.append(rythme.instant_pas(m, k * rythme.pas_par_temps))
		else:
			for i in p.size():
				if p[i] > 0.0:
					notes.append(rythme.instant_pas(m, i))
	_a_jouer.sort_custom(func(a, b): return a["t"] < b["t"])


func _frapper(f: Dictionary) -> void:
	if not sonore or String(f["voix"]) in voix_muettes:
		return
	var groupe := BanqueSons.son_de_voix(String(f["voix"]))
	if groupe.is_empty():
		return
	var fiche := BanqueSons.fiche(groupe)
	if fiche.is_empty():
		return
	var s := BanqueSons.flux(String(fiche["fichier"]))
	if s == null:
		return
	_creer_lecteurs()
	var p := _lecteurs[_suivant]
	_suivant = (_suivant + 1) % _lecteurs.size()
	p.bus = BanqueSons.bus(bus)
	p.stream = s
	p.volume_db = float(fiche.get("volume_db", 0.0)) + linear_to_db(maxf(float(f["force"]), 0.01))
	var v := float(fiche.get("variation_hauteur", 0.0))
	p.pitch_scale = 1.0 + randf_range(-v, v)
	p.play()
