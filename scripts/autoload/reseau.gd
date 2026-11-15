extends Node
## Jeu en ligne (autoload « Reseau ») : deux joueurs, un hôte et un invité.
##
## Deux transports, le reste du jeu ne voit pas la différence (MultiplayerPeer de Godot) :
##  - "steam" : réseau Steam (salons, invitations d'amis, recherche d'adversaire,
##    connexion pair à pair relayée par Valve, gratuit). Actif seulement si l'extension
##    GodotSteam est installée et que Steam tourne (voir docs/multijoueur.md).
##  - "lan" : ENet en direct (même réseau local, ou adresse IP). Toujours disponible,
##    sert aussi aux tests.
##
## Les messages sont des Dictionary vérifiés par Protocole.valide() avant usage.
## L'hôte fait foi pour la jauge du duel (Protocole.JaugePartagee).

signal etat_change                       # pour rafraîchir le salon
signal adversaire_arrive(profil: Dictionary)
signal adversaire_parti
signal message(m: Dictionary)            # message valide de l'adversaire
signal salons_lan_trouves(liste: Array)  # [{nom, match, ip, port}]
signal salons_steam_trouves(liste: Array)  # [{id, nom, match}]

const PORT := 24680
const PORT_ANNONCE := 24681
## App ID Steam : 480 (« Spacewar », l'appli de test de Valve) tant que le jeu n'a pas le sien.
const APP_ID_STEAM := 480

var transport := ""          # "", "lan" ou "steam"
var hote := false
var adversaire: Dictionary = {}   # profil propre de l'autre joueur, vide s'il n'y en a pas
var match_salon: Dictionary = {}  # le match du duel, envoyé par l'hôte
var camp_hote := "home"
var statut := ""                  # phrase à afficher dans le salon

var _pair := 0                    # identifiant réseau de l'adversaire
var _annonce: PacketPeerUDP
var _ecoute: PacketPeerUDP
var _salons_lan: Dictionary = {}  # "ip:port" -> {…, vu}
var _t_annonce := 0.0
var _texte_annonce := ""

var _steam: Object = null
var steam_ok := false
var _lobby := 0
var _recherche_auto := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_sur_pair_connecte)
	multiplayer.peer_disconnected.connect(_sur_pair_deconnecte)
	multiplayer.connected_to_server.connect(_sur_connecte_au_serveur)
	multiplayer.connection_failed.connect(func(): _echec("Connexion impossible."))
	multiplayer.server_disconnected.connect(func(): _sur_pair_deconnecte(1))
	_initialiser_steam()


func _process(delta: float) -> void:
	if steam_ok:
		_steam.call("run_callbacks")
	if _annonce:
		_t_annonce -= delta
		if _t_annonce <= 0.0:
			_t_annonce = 1.0
			_annonce.put_packet(Protocole.annonce_lan(Game.fan_club_nom, _texte_annonce, PORT))
	if _ecoute:
		var change := false
		while _ecoute.get_available_packet_count() > 0:
			var p := _ecoute.get_packet()
			var ip := _ecoute.get_packet_ip()
			var a := Protocole.lire_annonce(p)
			if not a.is_empty():
				a["ip"] = ip
				var cle := "%s:%d" % [ip, a["port"]]
				change = change or not _salons_lan.has(cle)
				a["vu"] = Time.get_ticks_msec()
				_salons_lan[cle] = a
		for cle in _salons_lan.keys():
			if Time.get_ticks_msec() - int(_salons_lan[cle]["vu"]) > 4000:
				_salons_lan.erase(cle)
				change = true
		if change:
			salons_lan_trouves.emit(salons_lan())


func connecte() -> bool:
	return _pair != 0 and not adversaire.is_empty()


func en_salon() -> bool:
	return multiplayer.multiplayer_peer != null and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer


# ---------------------------------------------------------------- envoi / réception

func envoyer(m: Dictionary) -> void:
	if _pair != 0:
		_recevoir.rpc_id(_pair, m)


## Pour ce qui est renvoyé souvent (l'état de la jauge) : une perte ne gêne pas.
func envoyer_vite(m: Dictionary) -> void:
	if _pair != 0:
		_recevoir_vite.rpc_id(_pair, m)


@rpc("any_peer", "call_remote", "reliable")
func _recevoir(m: Variant) -> void:
	_traiter(m)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _recevoir_vite(m: Variant) -> void:
	_traiter(m)


func _traiter(m: Variant) -> void:
	var de := multiplayer.get_remote_sender_id()
	if de != _pair or not Protocole.valide(m):
		return
	var d: Dictionary = m
	match d["t"]:
		"profil":
			var p := Protocole.profil_propre(d)
			if not Protocole.meme_version(p):
				statut = "L'autre joueur n'a pas la même version du jeu."
				quitter()
				return
			var nouveau := adversaire.is_empty()
			adversaire = p
			statut = "%s est là !" % p["nom"]
			if nouveau:
				adversaire_arrive.emit(p)
			etat_change.emit()
		"match":
			if not hote:
				match_salon = d["m"]
				camp_hote = d["camp_hote"]
				etat_change.emit()
	message.emit(d)


func _envoyer_profil() -> void:
	var skins: Array = Game.equipe.map(func(id): return Game.skin_de(str(id)))
	envoyer(Protocole.profil(Game.fan_club_nom, Game.couleurs_club(), skins, Game.niveau()))


## Hôte : choisit le match du duel et l'envoie à l'invité.
func choisir_match(m: Dictionary, camp: String) -> void:
	match_salon = m
	camp_hote = camp
	_texte_annonce = "%s – %s" % [FicheMatch.de(m)["dom"]["nom"], FicheMatch.de(m)["ext"]["nom"]] if not m.is_empty() else ""
	if hote:
		envoyer(Protocole.msg("match", {"m": m, "camp_hote": camp}))
		if steam_ok and _lobby != 0:
			_steam.call("setLobbyData", _lobby, "match", _texte_annonce)


func mon_camp() -> String:
	return camp_hote if hote else Protocole.camp_oppose(camp_hote)


# ---------------------------------------------------------------- connexions

func _sur_pair_connecte(id: int) -> void:
	if hote:
		if _pair != 0:
			return  # un seul adversaire ; ENet refuse déjà les suivants
		_pair = id
		_arreter_annonce()
		if steam_ok and _lobby != 0:
			_steam.call("setLobbyJoinable", _lobby, false)
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.refuse_new_connections = true
		statut = "Un joueur arrive…"
		_envoyer_profil()
		if not match_salon.is_empty():
			envoyer(Protocole.msg("match", {"m": match_salon, "camp_hote": camp_hote}))
	elif id == 1:
		_pair = 1
	etat_change.emit()


func _sur_connecte_au_serveur() -> void:
	_pair = 1
	statut = "Connecté, on se présente…"
	_envoyer_profil()
	etat_change.emit()


func _sur_pair_deconnecte(id: int) -> void:
	if id != _pair:
		return
	var nom: String = adversaire.get("nom", "L'autre joueur")
	_pair = 0
	adversaire = {}
	if hote:
		statut = "%s est parti. Le salon reste ouvert." % nom
		if multiplayer.multiplayer_peer:
			multiplayer.multiplayer_peer.refuse_new_connections = false
		if transport == "lan":
			_demarrer_annonce()
		elif steam_ok and _lobby != 0:
			_steam.call("setLobbyJoinable", _lobby, true)
	else:
		statut = "%s a fermé le salon." % nom
		_fermer_peer()
	adversaire_parti.emit()
	etat_change.emit()


func _echec(texte: String) -> void:
	statut = texte
	_fermer_peer()
	etat_change.emit()


func quitter() -> void:
	_arreter_annonce()
	arreter_recherche_lan()
	if steam_ok and _lobby != 0:
		_steam.call("leaveLobby", _lobby)
	_lobby = 0
	_recherche_auto = false
	_fermer_peer()
	adversaire = {}
	match_salon = {}
	etat_change.emit()


func _fermer_peer() -> void:
	if multiplayer.multiplayer_peer and not multiplayer.multiplayer_peer is OfflineMultiplayerPeer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_pair = 0
	hote = false
	transport = ""


# ---------------------------------------------------------------- réseau local (ENet)

func creer_salon_lan() -> bool:
	quitter()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, 1)
	if err != OK:
		statut = "Impossible d'ouvrir le salon (port %d déjà pris ?)." % PORT
		etat_change.emit()
		return false
	multiplayer.multiplayer_peer = peer
	hote = true
	transport = "lan"
	statut = "Salon ouvert. Ton adresse : %s" % ", ".join(adresses_locales())
	_demarrer_annonce()
	etat_change.emit()
	return true


func rejoindre_lan(ip: String, port := PORT) -> bool:
	quitter()
	ip = ip.strip_edges()
	if ip.is_empty() or not (ip.is_valid_ip_address() or ip == "localhost"):
		statut = "Adresse invalide (exemple : 192.168.1.20)."
		etat_change.emit()
		return false
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		statut = "Connexion impossible."
		etat_change.emit()
		return false
	multiplayer.multiplayer_peer = peer
	hote = false
	transport = "lan"
	statut = "Connexion à %s…" % ip
	etat_change.emit()
	return true


static func adresses_locales() -> Array:
	var res: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			res.append(a)
	return res if not res.is_empty() else ["127.0.0.1"]


func _demarrer_annonce() -> void:
	_arreter_annonce()
	_annonce = PacketPeerUDP.new()
	_annonce.set_broadcast_enabled(true)
	_annonce.set_dest_address("255.255.255.255", PORT_ANNONCE)
	_t_annonce = 0.0


func _arreter_annonce() -> void:
	if _annonce:
		_annonce.close()
	_annonce = null


func chercher_lan() -> void:
	if _ecoute:
		return
	_ecoute = PacketPeerUDP.new()
	if _ecoute.bind(PORT_ANNONCE) != OK:
		_ecoute = null
		statut = "Recherche impossible : un autre jeu écoute déjà le réseau local."
		etat_change.emit()


func arreter_recherche_lan() -> void:
	if _ecoute:
		_ecoute.close()
	_ecoute = null
	_salons_lan.clear()


func salons_lan() -> Array:
	return _salons_lan.values().map(func(a): return {"nom": a["nom"], "match": a["match"], "ip": a["ip"], "port": a["port"]})


# ---------------------------------------------------------------- Steam (GodotSteam)

## Steam n'est utilisé que si l'extension GodotSteam (singleton « Steam ») et sa
## SteamMultiplayerPeer sont là, et que le client Steam tourne. Sinon : réseau local.
func _initialiser_steam() -> void:
	if not Engine.has_singleton("Steam") or not ClassDB.class_exists("SteamMultiplayerPeer"):
		return
	_steam = Engine.get_singleton("Steam")
	OS.set_environment("SteamAppId", str(APP_ID_STEAM))
	OS.set_environment("SteamGameId", str(APP_ID_STEAM))
	var r: Variant = _steam.call("steamInitEx")
	steam_ok = r is Dictionary and int(r.get("status", 1)) == 0
	if not steam_ok:
		push_warning("Steam pas disponible : %s" % str(r))
		return
	_steam.connect("lobby_created", _sur_lobby_cree)
	_steam.connect("lobby_joined", _sur_lobby_rejoint)
	_steam.connect("lobby_match_list", _sur_liste_lobbies)
	_steam.connect("join_requested", func(lobby_id: int, _ami: int): rejoindre_steam(lobby_id))
	# Lancé depuis une invitation Steam : « +connect_lobby <id> »
	var args := OS.get_cmdline_args()
	var i := args.find("+connect_lobby")
	if i >= 0 and i + 1 < args.size() and args[i + 1].is_valid_int():
		rejoindre_steam.call_deferred(int(args[i + 1]))


func nom_steam() -> String:
	return str(_steam.call("getPersonaName")) if steam_ok else ""


## Salon Steam. `public` : visible par la recherche d'adversaire ; sinon amis seulement.
func creer_salon_steam(public: bool) -> void:
	quitter()
	hote = true
	transport = "steam"
	statut = "Ouverture du salon Steam…"
	_steam.call("createLobby", 2 if public else 1, 2)  # LOBBY_TYPE_PUBLIC / FRIENDS_ONLY, 2 places
	etat_change.emit()


func inviter_amis_steam() -> void:
	if steam_ok and _lobby != 0:
		_steam.call("activateGameOverlayInviteDialog", _lobby)


func _sur_lobby_cree(resultat: int, lobby_id: int) -> void:
	if resultat != 1:  # k_EResultOK
		_echec("Steam n'a pas pu créer le salon (code %d)." % resultat)
		return
	_lobby = lobby_id
	_steam.call("setLobbyData", lobby_id, "jeu", Protocole.JEU)
	_steam.call("setLobbyData", lobby_id, "v", str(Protocole.VERSION))
	_steam.call("setLobbyData", lobby_id, "nom", Game.fan_club_nom)
	_steam.call("setLobbyData", lobby_id, "match", _texte_annonce)
	var peer: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: Variant = peer.call("create_host", 0)
	if err != OK:
		_echec("Steam n'a pas pu ouvrir la connexion (%s)." % str(err))
		return
	multiplayer.multiplayer_peer = peer
	statut = "Salon Steam ouvert. Invite un ami ou attends un adversaire."
	etat_change.emit()


func rejoindre_steam(lobby_id: int) -> void:
	if not steam_ok:
		return
	quitter()
	hote = false
	transport = "steam"
	statut = "On rejoint le salon Steam…"
	_steam.call("joinLobby", lobby_id)
	etat_change.emit()


func _sur_lobby_rejoint(lobby_id: int, _permissions: int, _verrouille: bool, reponse: int) -> void:
	if hote:
		return  # l'hôte reçoit aussi ce signal en créant son salon
	if reponse != 1:  # k_EChatRoomEnterResponseSuccess
		_lobby = 0
		_echec("Salon plein ou fermé.")
		if _recherche_auto:
			creer_salon_steam(true)
		return
	_lobby = lobby_id
	var proprio: int = _steam.call("getLobbyOwner", lobby_id)
	var peer: Object = ClassDB.instantiate("SteamMultiplayerPeer")
	var err: Variant = peer.call("create_client", proprio, 0)
	if err != OK:
		_echec("Connexion Steam impossible (%s)." % str(err))
		return
	multiplayer.multiplayer_peer = peer
	statut = "Connexion à l'hôte…"
	etat_change.emit()


## Liste des salons publics de ce jeu (même version), partout dans le monde.
func chercher_steam() -> void:
	if not steam_ok:
		return
	_steam.call("addRequestLobbyListStringFilter", "jeu", Protocole.JEU, 0)  # LOBBY_COMPARISON_EQUAL
	_steam.call("addRequestLobbyListStringFilter", "v", str(Protocole.VERSION), 0)
	_steam.call("addRequestLobbyListFilterSlotsAvailable", 1)
	_steam.call("addRequestLobbyListDistanceFilter", 3)  # LOBBY_DISTANCE_FILTER_WORLDWIDE
	_steam.call("requestLobbyList")


## Recherche d'adversaire : rejoint le premier salon public libre, sinon en ouvre un.
func trouver_adversaire_steam() -> void:
	quitter()
	_recherche_auto = true
	statut = "Recherche d'un adversaire…"
	etat_change.emit()
	chercher_steam()


func _sur_liste_lobbies(lobbies: Array) -> void:
	var liste: Array = []
	for id in lobbies:
		liste.append({"id": int(id), "nom": str(_steam.call("getLobbyData", id, "nom")).substr(0, Protocole.NOM_MAX),
			"match": str(_steam.call("getLobbyData", id, "match")).substr(0, 80)})
	if _recherche_auto:
		_recherche_auto = false
		if liste.is_empty():
			statut = "Personne pour l'instant : ton salon est ouvert, un adversaire peut te trouver."
			creer_salon_steam(true)
		else:
			rejoindre_steam(liste[0]["id"])
		return
	salons_steam_trouves.emit(liste)
