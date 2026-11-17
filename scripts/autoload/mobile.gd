extends Node
## Téléphones et tablettes (autoload « Mobile ») :
##  - `actif` : le jeu tourne sur Android/iOS (ou `-- --mobile` pour l'essayer sur PC) ;
##  - `tactile` : on joue au doigt (mobile, ou écran tactile sur PC) ;
##  - agrandit l'interface sur les petits écrans (écrans de menus seulement :
##    les terrains de jeu sont dessinés pour 1920×1080 et gardent leur échelle) ;
##  - le bouton « retour » d'Android fait comme Échap (pause, fermer, revenir) ;
##  - un bouton pause à l'écran dans les modes qui se mettent en pause avec Échap.
##
## Sur PC sans écran tactile, rien ne change.

## Écrans de jeu : échelle d'origine (positions fixes en 1920×1080).
const SCENES_FIXES := [
	"res://scenes/duel/duel.tscn", "res://scenes/arene/arene.tscn", "res://scenes/poussee/poussee.tscn",
	"res://scenes/buvette/buvette.tscn", "res://scenes/ramasseur/ramasseur.tscn",
	"res://scenes/speaker/speaker.tscn", "res://scenes/tifo/tifo.tscn", "res://scenes/echarpes/echarpes.tscn",
	"res://scenes/tribune/tribune.tscn", "res://scenes/voyage/voyage.tscn",
]
## Modes où Échap met en pause sans bouton à l'écran : un bouton pause est
## ajouté au doigt (position du coin haut gauche, à côté de l'interface du mode).
const SCENES_PAUSE := {
	"res://scenes/duel/duel.tscn": Vector2(24, 150),
	"res://scenes/arene/arene.tscn": Vector2(16, 16),
	"res://scenes/poussee/poussee.tscn": Vector2(16, 16),
}

## Taille de texte minimale sur téléphone (en pixels du jeu 1920×1080).
const TAILLE_TEXTE_MINI := 18

var actif := false
var tactile := false
## Agrandissement des écrans de menus (1 sur PC).
var echelle_menus := 1.0

var _scene_vue: Node = null
var _calque: CanvasLayer = null
var _btn_pause: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args := OS.get_cmdline_user_args()
	actif = OS.has_feature("mobile") or "--mobile" in args
	tactile = actif or DisplayServer.is_touchscreen_available() or "--tactile" in args
	if not actif:
		return
	get_tree().quit_on_go_back = false
	Ui.taille_mini = TAILLE_TEXTE_MINI
	Ui.petit_ecran = true
	echelle_menus = _echelle_ecran()
	if "--mobile" in args and OS.has_feature("pc"):
		# essai sur PC : comme un téléphone de la taille de la fenêtre
		var fenetre := DisplayServer.window_get_size()
		echelle_menus = clampf(floorf(float(fenetre.x) / fenetre.y / (16.0 / 9.0) * 20.0) / 20.0, 1.0, 1.25)
	for a in args:
		if a.begins_with("--echelle="):  # sans_traduction
			echelle_menus = float(a.get_slice("=", 1))
	print("Mobile : interface ×%.2f" % echelle_menus)  # sans_traduction
	_calque = CanvasLayer.new()
	_calque.layer = 90
	add_child(_calque)
	_btn_pause = Button.new()
	_btn_pause.text = "II"  # sans_traduction
	_btn_pause.focus_mode = Control.FOCUS_NONE
	_btn_pause.custom_minimum_size = Vector2(96, 96)
	_btn_pause.add_theme_font_size_override("font_size", 40)
	_btn_pause.add_theme_font_override("font", Ui.police_titre())
	for etat in ["normal", "hover", "pressed", "focus"]:
		_btn_pause.add_theme_stylebox_override(etat, Ui.boite(Color(Ui.NUIT, 0.8), 48, 4))
	_btn_pause.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_btn_pause.position = Vector2(16, 16)
	_btn_pause.visible = false
	_btn_pause.pressed.connect(appuyer_echap)
	_calque.add_child(_btn_pause)


## Agrandissement selon la taille physique de l'écran : un téléphone (≈ 7 cm de
## haut en paysage) affiche les menus en 864 lignes au lieu de 1080 (×1,25 ;
## au-delà, les écrans dessinés pour 1080 lignes débordent).
func _echelle_ecran() -> float:
	var ecran := DisplayServer.screen_get_size()
	var dpi := maxf(DisplayServer.screen_get_dpi(), 96.0)
	var hauteur_pouces := minf(ecran.x, ecran.y) / dpi
	var lignes := clampf(1080.0 * hauteur_pouces / 6.0, 864.0, 1080.0)
	# garder au moins 1920 colonnes : un écran 16:9 reste à ×1, un 20:9 va jusqu'à ×1,25
	var format := float(maxi(ecran.x, ecran.y)) / float(maxi(mini(ecran.x, ecran.y), 1))
	var echelle := minf(1080.0 / lignes, format / (16.0 / 9.0))
	return maxf(1.0, floorf(echelle * 20.0) / 20.0)


func _process(_delta: float) -> void:
	if not actif:
		return
	var scene := get_tree().current_scene
	if scene == _scene_vue:
		return
	_scene_vue = scene
	var chemin := scene.scene_file_path if scene else ""
	get_window().content_scale_factor = 1.0 if chemin in SCENES_FIXES else echelle_menus
	_btn_pause.visible = SCENES_PAUSE.has(chemin)
	if _btn_pause.visible:
		_btn_pause.position = SCENES_PAUSE[chemin]


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		appuyer_echap()


## Envoie une touche Échap au jeu (bouton retour d'Android, bouton pause).
func appuyer_echap() -> void:
	appuyer_touche(KEY_ESCAPE)


## Simule l'appui (puis le relâchement) d'une touche du clavier.
func appuyer_touche(touche: Key) -> void:
	for presse in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = touche
		ev.physical_keycode = touche
		ev.pressed = presse
		Input.parse_input_event(ev)

