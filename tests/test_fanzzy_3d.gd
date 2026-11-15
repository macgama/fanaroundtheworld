extends SceneTree
## Tests sans écran des FANZZY 3D (modèles .glb de assets/fanzzy/3d) :
##   godot --headless --path . --script tests/test_fanzzy_3d.gd

const ANIMATIONS := [&"attente", &"course", &"lancer", &"victoire", &"depit"]
const OS_ATTENDUS := ["racine", "hanches", "torse", "tete", "bras.L", "avantbras.L", "bras.R",
		"avantbras.R", "cuisse.L", "tibia.L", "cuisse.R", "tibia.R"]

var _echecs := 0
var _verifs := 0


func _init() -> void:
	var ids := _modeles()
	_verifier(ids.size() >= 3, "au moins une famille de modèles (%d)" % ids.size())
	for id in ids:
		_tester_modele(id)
	await _tester_noeud(ids[0] if not ids.is_empty() else "")
	_verifier(Fanzzy3D.creer_corps("ZZZ999") is FanzzyAnime, "sans modèle : retour à l'image animée")
	print("Tests FANZZY 3D : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _modeles() -> PackedStringArray:
	var r := PackedStringArray()
	for f in DirAccess.get_files_at(Fanzzy3D.DOSSIER):
		if f.ends_with(".glb"):
			r.append(f.get_basename())
	return r


func _tester_modele(id: String) -> void:
	var scene: PackedScene = load(Fanzzy3D.chemin_modele(id))
	_verifier(scene != null, "%s : modèle chargé" % id)
	if scene == null:
		return
	var m := scene.instantiate()
	var anim: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	_verifier(anim != null, "%s : AnimationPlayer" % id)
	if anim:
		for a in ANIMATIONS:
			_verifier(anim.has_animation(a), "%s : animation %s" % [id, a])
	var sq: Skeleton3D = m.find_child("*", true, false) as Skeleton3D
	for n in m.find_children("*", "Skeleton3D", true, false):
		sq = n
	_verifier(sq != null, "%s : squelette" % id)
	if sq:
		for o in OS_ATTENDUS:
			_verifier(sq.find_bone(o) >= 0, "%s : os %s" % [id, o])
	var mailles := m.find_children("*", "MeshInstance3D", true, false)
	_verifier(mailles.size() == 3, "%s : corps + 2 bras (%d)" % [id, mailles.size()])
	m.free()


func _tester_noeud(id: String) -> void:
	if id.is_empty():
		return
	var f := Fanzzy3D.creer(id)
	root.add_child(f)
	_verifier(f._rect.size.y > 100.0, "hauteur utile en pixels (%s)" % f._rect.size.y)
	for a in Fanzzy3D.ANIMS:
		f.jouer(a)
		await process_frame
		_verifier(f.action == a, "action %s" % a)
	f.jouer(&"celebrer", 0.05)
	await create_timer(0.2).timeout
	_verifier(f.action == &"repos", "retour au repos après la durée")
	f.orienter(Vector2(1, 0))
	for i in 30:
		await process_frame
	_verifier(absf(f._modele.rotation.y - PI / 2) < 0.2, "se tourne vers la droite (%s)" % f._modele.rotation.y)
	var v := Fanzzy3D.vignette(id)
	_verifier(v != null and v.texture != null, "vignette du salon")
	if v:
		v.free()
	f.free()
