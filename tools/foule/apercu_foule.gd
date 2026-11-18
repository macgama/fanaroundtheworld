extends Control
## Aperçu des supporters Quaternius : chaque geste (3 looks, 3 clubs) puis une
## tribune entière avec une ola toutes les 5 secondes.
##   godot --path . res://tools/foule/apercu_foule.tscn --write-movie apercu.avi --fixed-fps 30 --quit-after 300

const CLUBS := [[Color("#e8304a"), Color("#ffd23f")], [Color("#2f6fe0"), Color("#ffffff")], [Color("#27b35a"), Color("#111111")]]
const GESTES := [&"repos", &"sauter", &"applaudir", &"ola", &"echarpe", &"depit", &"danser"]
var _t := 0.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#5b3fd1"))
	var f := ThemeDB.fallback_font
	# haut : un geste par colonne, trois supporters par geste
	var lx := size.x / GESTES.size()
	for g in GESTES.size():
		var geste: StringName = GESTES[g]
		var tg := fmod(_t, 2.0) if geste == &"ola" else _t
		draw_string(f, Vector2(g * lx + 16, 40), str(geste), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		for k in 3:
			var club: Array = CLUBS[k]
			FouleSprites.dessiner(self, Vector2(g * lx + 50 + k * 75, 250), 150.0, geste, tg + k * 0.13,
				club[0], club[1], FouleSprites.PEAUX[(g + k * 2) % 5], k)
	# bas : une tribune
	var y0 := 330.0
	draw_rect(Rect2(0, y0, size.x, size.y - y0), Color("#3a3290"))
	var ola_t := fmod(_t, 5.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for j in 7:
		var ech := 1.0 + j * 0.08
		var y := y0 + 70.0 + j * 105.0
		var x := 20.0 + (30.0 if j % 2 else 0.0)
		while x < size.x:
			var club: Array = CLUBS[1] if rng.randf() < 0.85 else CLUBS[0]
			var graine := rng.randf()
			var ga := FouleSprites.geste_ambiance(0.85, graine, _t)
			var dans := ola_t - 1.0 - x / size.x * 1.6
			if dans >= 0.0 and dans < FouleSprites.duree(&"ola"):
				ga = [&"ola", dans]
			var c2: Color = club[1] if rng.randf() < 0.8 else club[0]
			FouleSprites.dessiner(self, Vector2(x, y + 60.0 * ech), 105.0 * ech, ga[0], ga[1],
				club[0], c2, FouleSprites.PEAUX[rng.randi() % 5], rng.randi() % 3)
			x += 62.0 * ech
		draw_rect(Rect2(0, y + 30.0 * ech, size.x, 70.0 * ech), Color("#2a2357", 0.92))
		draw_rect(Rect2(0, y + 30.0 * ech, size.x, 8.0 * ech), Color("#8b7dff", 0.9))
