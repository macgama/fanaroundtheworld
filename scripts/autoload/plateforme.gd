extends Node
## Steam pour tout le jeu (autoload « Plateforme », chargé en premier) :
##  - ouvre Steam une seule fois (le réseau en ligne s'en sert aussi, voir Reseau) ;
##  - succès Steam : `debloquer(id)` ;
##  - sauvegarde Steam Cloud : `cloud_ecrire()` / `cloud_lire()`.
##
## Hors Steam (extension absente, Steam fermé, tests), tout marche quand même :
## les succès sont gardés dans la sauvegarde locale (Game.succes) et renvoyés à
## Steam au prochain lancement avec Steam ; la sauvegarde reste dans user://.
## Les appels passent par `call()` pour que le jeu se lance sans l'extension.

## App ID Steam : 480 (« Spacewar », l'appli de test de Valve) tant que le jeu n'a pas le sien.
## Avec 480, les succès du jeu n'existent pas chez Steam : les appels échouent
## sans bruit et seul le suivi local compte. Voir docs/succes-et-cloud.md.
const APP_ID_STEAM := 480
## Écriture dans Steam Cloud au plus toutes les N secondes (et toujours en quittant).
const DELAI_CLOUD := 20.0

## App ID utilisé : celui de la démo dans la version démo (s'il existe déjà).
static func app_id() -> int:
	return Demo.APP_ID_DEMO if Demo.actif() and Demo.APP_ID_DEMO > 0 else APP_ID_STEAM


var steam: Object = null
var steam_ok := false

var _cloud_en_attente: Dictionary = {}  # nom de fichier -> texte à écrire
var _t_cloud := 0.0
var _stats_a_envoyer := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialiser_steam()


func _initialiser_steam() -> void:
	# Pas de Steam sur téléphone (l'extension GodotSteam n'est pas dans l'APK).
	if OS.has_feature("mobile") or "--sans-steam" in OS.get_cmdline_user_args() or not Engine.has_singleton("Steam"):
		return
	steam = Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(app_id()))  # sans_traduction
	OS.set_environment("SteamGameId", str(app_id()))  # sans_traduction
	var r: Variant = steam.call("steamInitEx")  # sans_traduction
	steam_ok = r is Dictionary and int(r.get("status", 1)) == 0
	print("Steam : %s" % str(r))
	if not steam_ok:
		push_warning("Steam pas disponible : %s" % str(r))  # sans_traduction


func _process(delta: float) -> void:
	if not steam_ok:
		return
	steam.call("run_callbacks")
	_t_cloud -= delta
	if _t_cloud <= 0.0:
		_t_cloud = DELAI_CLOUD
		_vider_cloud()
		if _stats_a_envoyer:
			_stats_a_envoyer = false
			steam.call("storeStats")  # sans_traduction


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		_vider_cloud()
		if steam_ok and _stats_a_envoyer:
			_stats_a_envoyer = false
			steam.call("storeStats")  # sans_traduction


func nom_joueur() -> String:
	return str(steam.call("getPersonaName")) if steam_ok else ""  # sans_traduction


# ---------------------------------------------------------------- succès

## Débloque un succès chez Steam (sans effet hors Steam ou s'il l'est déjà).
## L'envoi à Steam (storeStats) est groupé ; `tout_de_suite` le fait maintenant.
func debloquer(id: String, tout_de_suite := false) -> bool:
	if not steam_ok or Demo.actif():  # pas de succès Steam dans la démo
		return false
	var deja: Variant = steam.call("getAchievement", id)  # sans_traduction
	if deja is Dictionary and bool(deja.get("ret", false)) and bool(deja.get("achieved", false)):
		return true
	var ok := bool(steam.call("setAchievement", id))  # sans_traduction
	if ok:
		_stats_a_envoyer = true
		if tout_de_suite:
			_stats_a_envoyer = false
			steam.call("storeStats")  # sans_traduction
	return ok


## Renvoie à Steam les succès gagnés hors Steam (au lancement).
func synchroniser_succes(ids: Array) -> int:
	if not steam_ok:
		return 0
	var n := 0
	for id in ids:
		if debloquer(str(id)):
			n += 1
	if _stats_a_envoyer:
		_stats_a_envoyer = false
		steam.call("storeStats")  # sans_traduction
	return n


# ---------------------------------------------------------------- Steam Cloud

## Vrai si Steam Cloud est utilisable : Steam lancé, et le Cloud activé pour le
## compte (réglage du joueur) et pour le jeu (réglage Steamworks).
func cloud_actif() -> bool:
	return steam_ok and bool(steam.call("isCloudEnabledForAccount")) and bool(steam.call("isCloudEnabledForApp"))  # sans_traduction


## Garde le texte pour Steam Cloud ; il part au plus tard dans DELAI_CLOUD secondes.
func cloud_ecrire(nom: String, texte: String) -> void:
	if not cloud_actif():
		return
	_cloud_en_attente[nom] = texte


## Écrit tout de suite ce qui attend (appelé en quittant).
func _vider_cloud() -> void:
	if _cloud_en_attente.is_empty() or not cloud_actif():
		_cloud_en_attente.clear()
		return
	for nom in _cloud_en_attente:
		var octets: PackedByteArray = str(_cloud_en_attente[nom]).to_utf8_buffer()
		if not bool(steam.call("fileWrite", nom, octets, octets.size())):  # sans_traduction
			push_warning("Steam Cloud : écriture de %s refusée (quota ?)" % nom)  # sans_traduction
	_cloud_en_attente.clear()


## Texte du fichier dans Steam Cloud, ou "" s'il n'y est pas.
func cloud_lire(nom: String) -> String:
	if _cloud_en_attente.has(nom):
		return str(_cloud_en_attente[nom])
	if not cloud_actif() or not bool(steam.call("fileExists", nom)):  # sans_traduction
		return ""
	var taille := int(steam.call("getFileSize", nom))  # sans_traduction
	if taille <= 0:
		return ""
	var r: Variant = steam.call("fileRead", nom, taille)  # sans_traduction
	if not r is Dictionary or not bool(r.get("ret", false)):
		return ""
	var buf: Variant = r.get("buf", PackedByteArray())
	return (buf as PackedByteArray).get_string_from_utf8() if buf is PackedByteArray else ""


## Efface le fichier de Steam Cloud (« Recommencer à zéro »).
func cloud_effacer(nom: String) -> void:
	_cloud_en_attente.erase(nom)
	if cloud_actif() and bool(steam.call("fileExists", nom)):  # sans_traduction
		steam.call("fileDelete", nom)  # sans_traduction


## Phrase pour les options.
func texte_sauvegarde() -> String:
	if cloud_actif():
		return "Sauvegarde : sur ce PC et dans Steam Cloud (ta progression te suit sur tes autres PC)."
	if steam_ok:
		return "Sauvegarde : sur ce PC. Active Steam Cloud dans Steam pour la retrouver sur tes autres PC."
	if OS.has_feature("mobile"):
		return "Sauvegarde : sur cet appareil."
	return "Sauvegarde : sur ce PC (Steam n'est pas lancé)."
