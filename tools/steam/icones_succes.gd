extends Node
## Icônes des succès pour Steamworks (256×256, PNG) : une « gagnée » en couleur
## et une « pas encore gagnée » grisée par succès de Succes.LISTE.
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . res://tools/steam/icones_succes.tscn \
##       -- --sortie=docs/steam/succes
## Fichiers : <ID>.png et <ID>_gris.png (à téléverser dans Steamworks, voir docs/succes-et-cloud.md).

const TAILLE := 256


func _ready() -> void:
	var sortie := "res://docs/steam/succes"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
	if not sortie.begins_with("res://") and not sortie.begins_with("/"):
		sortie = "res://" + sortie
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(sortie))
	var vp := SubViewport.new()
	vp.size = Vector2i(TAILLE, TAILLE)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var n := 0
	for s in Succes.LISTE:
		for gris in [false, true]:
			for c in vp.get_children():
				c.queue_free()
			vp.add_child(_dessin(s, gris))
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			var nom := "%s%s.png" % [s["id"], "_gris" if gris else ""]
			img.save_png(ProjectSettings.globalize_path(sortie.path_join(nom)))
			n += 1
	print("Icônes des succès : %d fichiers dans %s" % [n, sortie])
	get_tree().quit()


func _dessin(s: Dictionary, gris: bool) -> Control:
	var coul := Color(s["couleur"])
	var fond := Ui.panneau(Color("#4a4580") if gris else coul, TAILLE / 2, 14)
	fond.position = Vector2.ZERO
	fond.size = Vector2(TAILLE, TAILLE)
	var cercle := Ui.panneau(Color("#2a2560") if gris else coul.darkened(0.35), 90, 8)
	cercle.custom_minimum_size = Vector2(180, 180)
	cercle.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cercle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ic := Ui.icone(str(s["icone"]), 120)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if gris:
		ic.modulate = Color(0.75, 0.75, 0.8, 0.45)
	cercle.add_child(ic)
	fond.add_child(cercle)
	return fond
