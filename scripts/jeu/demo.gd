class_name Demo
extends RefCounted
## Version démo du jeu (Steam Next Fest). La même base de code que le jeu
## complet : la démo est le jeu exporté avec l'étiquette « demo »
## (préréglage d'export « Windows Démo », voir docs/demo.md), ou lancé avec
## `-- --demo` pour l'essayer depuis l'éditeur.
##
## Contenu de la démo :
##  - tout le tutoriel (fan club, équipes favorites, prono, voyage, premier duel) ;
##  - les trois modes de duel contre l'ordinateur (ambiance, Arène, Poussée) ;
##  - la carte : compétitions mondiales et Europe (les autres continents sont fermés) ;
##  - deux petits boulots sur cinq (buvette, speaker) ;
##  - fan club, pronostics, missions, équipes favorites, collection ;
##  - la progression jusqu'au niveau NIVEAU_MAX, puis l'écran de fin de démo.
## Fermé (fenêtre « Dans le jeu complet » + bouton liste de souhaits) :
## en ligne, classement, tournoi, PASS, créateur de chants, trois petits boulots.
##
## Sauvegarde à part (user://demo_*.json) : la démo n'écrase jamais une
## partie du jeu complet. Rien n'est envoyé au classement en ligne.

## Dernier niveau de la démo : l'XP s'arrête là et la fin de démo s'affiche.
const NIVEAU_MAX := 6
const CONTINENTS_OUVERTS := ["Europe"]
const BOULOTS_OUVERTS := ["buvette", "speaker"]

## App ID Steam du jeu complet (pour « Ajouter à ma liste de souhaits »).
## 0 tant que Gaël n'a pas payé le Steam Direct : on ouvre alors une recherche Steam.
const APP_ID_JEU := 0
## App ID Steam de la démo (créée dans Steamworks à partir du jeu). 0 = test (480).
const APP_ID_DEMO := 0

## Écrans fermés dans la démo -> ce qu'ils offrent dans le jeu complet.
const ECRANS_FERMES := {
	"res://scenes/salon/salon.tscn": "Défie tes amis et d'autres fans en ligne, en duel d'ambiance ou en Poussée.",
	"res://scenes/classement/classement.tscn": "Grimpe au classement mondial des fans et pousse ton équipe tout en haut.",
	"res://scenes/tournoi/tournoi.tscn": "Chaque week-end, le tournoi des fan clubs sur les vrais matchs.",
	"res://scenes/pass/pass.tscn": "Le PASS saisonnier : 100 paliers, nouvelles recrues FANZZY et skins.",
	"res://scenes/chant/createur_chant.tscn": "Compose le chant de ton fan club et chante-le en duel, en karaoké.",
	"res://scenes/ramasseur/ramasseur.tscn": "Petit boulot : ramasseur de balles au bord du terrain.",
	"res://scenes/tifo/tifo.tscn": "Petit boulot : peintre des grands tifos du capo.",
	"res://scenes/echarpes/echarpes.tscn": "Petit boulot : le stand d'écharpes aux couleurs des clubs.",
}

const TEXTE_CONTINENTS := "Dans la démo, tu voyages en Europe et suis les compétitions mondiales. Le jeu complet t'ouvre les stades des cinq autres continents."

static var _actif := -1


## Vrai dans la version démo.
static func actif() -> bool:
	if _actif < 0:
		_actif = 1 if OS.has_feature("demo") or "--demo" in OS.get_cmdline_user_args() else 0  # sans_traduction
	return _actif == 1


## Pour les tests : passer en démo (ou en sortir) sans relancer le jeu.
static func forcer(oui: bool) -> void:
	_actif = 1 if oui else 0


## Chemin d'un fichier user:// : la démo garde ses propres fichiers.
static func fichier(chemin: String) -> String:
	if not actif():
		return chemin
	return "user://demo_" + chemin.trim_prefix("user://")  # sans_traduction


## Texte « dans le jeu complet » si l'écran est fermé dans la démo, sinon "".
static func ecran_ferme(scene: String) -> String:
	if not actif():
		return ""
	return str(ECRANS_FERMES.get(scene, ""))


static func continent_ouvert(c: String) -> bool:
	return not actif() or c == "" or c in CONTINENTS_OUVERTS


static func boulot_ouvert(id: String) -> bool:
	return not actif() or id in BOULOTS_OUVERTS


## XP maximum de la démo (début du niveau NIVEAU_MAX).
static func xp_max() -> int:
	return (NIVEAU_MAX - 1) * 200


static func xp_limitee(xp: int) -> int:
	return mini(xp, xp_max()) if actif() else xp


static func url_magasin() -> String:
	if APP_ID_JEU > 0:
		return "https://store.steampowered.com/app/%d/" % APP_ID_JEU  # sans_traduction
	return "https://store.steampowered.com/search/?term=Fan+Around+The+World"  # sans_traduction


## Ouvre la page Steam du jeu complet (dans Steam si possible).
static func ouvrir_magasin() -> void:
	if DisplayServer.get_name() == "headless":  # sans_traduction
		return  # tests
	if APP_ID_JEU > 0 and Engine.has_singleton("Steam"):
		var s := Engine.get_singleton("Steam")
		if bool(s.call("isSteamRunning")):  # sans_traduction
			s.call("activateGameOverlayToStore", APP_ID_JEU, 0)  # sans_traduction
			return
	OS.shell_open(url_magasin())


# ---------------------------------------------------------------- fenêtres

## « Dans le jeu complet » : ce que l'écran fermé propose, et la liste de souhaits.
static func montrer_ferme(texte: String) -> CanvasLayer:
	return _fenetre(Trad.t("Dans le jeu complet"), Trad.t(texte), Trad.t("Continuer la démo"))


## Fin de la démo (niveau NIVEAU_MAX atteint).
static func montrer_fin() -> CanvasLayer:
	var texte := Trad.t("Bravo, ton fan club a atteint le niveau %d : c'est la fin de la démo !") % NIVEAU_MAX
	texte += "\n\n" + Trad.t("Dans le jeu complet : le monde entier, le PASS saisonnier, les duels en ligne, le tournoi du week-end, le créateur de chants et tous les petits boulots.")
	texte += "\n\n" + Trad.t("Tu peux continuer à jouer à la démo, mais ton XP ne monte plus.")
	return _fenetre(Trad.t("Fin de la démo"), texte, Trad.t("Continuer à jouer"))


static func _fenetre(titre: String, texte: String, texte_retour: String) -> CanvasLayer:
	var arbre := Engine.get_main_loop() as SceneTree
	if arbre == null or arbre.root == null:
		return null
	var couche := CanvasLayer.new()
	couche.layer = 90
	couche.name = "FenetreDemo"  # sans_traduction
	var voile := ColorRect.new()
	voile.color = Color(0.05, 0.03, 0.15, 0.75)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	couche.add_child(voile)
	var c := CenterContainer.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(c)
	var p := Ui.panneau(Ui.NUIT, 32, 6)
	p.custom_minimum_size = Vector2(820, 0)
	c.add_child(p)
	var v := Ui.vbox(22)
	p.add_child(Ui.marge(v, 24, 16, 24, 16))
	var bandeau := Ui.pastille(Trad.t("DÉMO"), Ui.ROSE, 22)
	bandeau.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(bandeau)
	v.add_child(Ui.label(titre, 48, Ui.JAUNE, true, 8))
	var l := Ui.label(texte, 26, Ui.BLANC)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 760
	v.add_child(l)
	var h := Ui.hbox(16)
	v.add_child(h)
	var souhaits := Ui.bouton(Trad.t("Ajouter à ma liste de souhaits"), Ui.JAUNE, 28)
	Ui.colorer_bouton(souhaits, Ui.JAUNE, true)
	souhaits.custom_minimum_size.y = 84
	souhaits.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	souhaits.pressed.connect(func(): ouvrir_magasin())
	h.add_child(souhaits)
	var retour := Ui.bouton(texte_retour, Ui.NUIT_CLAIR, 26)
	retour.custom_minimum_size.y = 84
	retour.pressed.connect(func(): couche.queue_free())
	h.add_child(retour)
	arbre.root.add_child(couche)
	# La fenêtre part avec l'écran qui l'a ouverte.
	arbre.scene_changed.connect(couche.queue_free, CONNECT_ONE_SHOT)
	Ui.pop(p, 1.05)
	souhaits.grab_focus.call_deferred()
	# Échap ferme la fenêtre
	voile.gui_input.connect(func(e: InputEvent):
		if e.is_action_pressed("ui_cancel"):
			couche.queue_free())
	return couche


## Ruban « DÉMO » + bouton liste de souhaits, pour l'accueil.
static func ruban_accueil() -> Control:
	var v := Ui.vbox(10)
	var r := Ui.pastille(Trad.t("DÉMO · Steam Next Fest"), Ui.ROSE, 26)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(r)
	var b := Ui.bouton(Trad.t("Ajouter à ma liste de souhaits"), Ui.JAUNE, 26)
	Ui.colorer_bouton(b, Ui.JAUNE, true)
	b.custom_minimum_size = Vector2(0, 72)
	b.pressed.connect(func(): ouvrir_magasin())
	v.add_child(b)
	return v
