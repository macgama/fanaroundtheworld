class_name IaNiveau
extends RefCounted
## Niveaux de l'adversaire ordi en Arène et en Poussée (réglés dans les Options).
##   facile    : réagit lentement, vise mal, joue ses cartes un peu au hasard ;
##   normal    : lit le terrain (ballon, menaces, mégaphone) avec un peu d'erreur ;
##   difficile : réagit vite, vise juste, esquive, garde sa Ferveur pour des attaques groupées.
## Tests et matchs simulés : --difficulte=<niveau> (adversaire), --difficulte-moi=<niveau>
## (ton camp : coéquipiers ordi de l'Arène, et toi en démo --auto ; par défaut le même niveau).

const NIVEAUX := ["facile", "normal", "difficile"]
const NOMS := {"facile": "Facile", "normal": "Normal", "difficile": "Difficile"}
const AIDES := {
	"facile": "Pour découvrir : l'ordi réagit lentement et vise mal",
	"normal": "L'ordi lit le terrain, avec quelques erreurs",
	"difficile": "L'ordi réagit vite, vise juste et prépare ses attaques",
}
const PAR_DEFAUT := "normal"

const PARAMS := {
	"facile": {
		# Poussée
		"malin": false, "pense": [1.1, 1.9], "erreur_pose": 90.0,
		# Arène
		"reaction": [0.8, 1.4], "erreur_tir": 75.0, "anticipe": 0.3, "esquive": 0.0,
		"roulade": false, "tir_charge": false, "choix_cible": false,
	},
	"normal": {
		"malin": true, "pense": [0.55, 0.95], "erreur_pose": 30.0, "distrait": 0.15, "reserve": 8.0,
		"reaction": [0.5, 0.9], "erreur_tir": 38.0, "anticipe": 0.85, "esquive": 0.35,
		"roulade": true, "tir_charge": false, "choix_cible": true,
	},
	"difficile": {
		"malin": true, "pense": [0.35, 0.65], "erreur_pose": 15.0, "distrait": 0.0, "reserve": 9.5,
		"reaction": [0.4, 0.75], "erreur_tir": 16.0, "anticipe": 1.0, "esquive": 0.75, "economie": true,
		"roulade": true, "tir_charge": true, "choix_cible": true,
	},
}


static func valide(n: String) -> String:
	return n if n in NIVEAUX else PAR_DEFAUT


static func params(n: String) -> Dictionary:
	return PARAMS[valide(n)]


## Niveau de l'adversaire : --difficulte=… sinon les Options.
static func adversaire() -> String:
	var a := _arg("difficulte")
	return valide(a) if a != "" else Reglages.difficulte()


## Niveau de ton camp : tes coéquipiers ordi de l'Arène, et toi-même en démo --auto.
## Par défaut celui de l'adversaire : à niveau égal, c'est toi qui fais la différence.
static func moi() -> String:
	var a := _arg("difficulte-moi")
	return valide(a) if a != "" else adversaire()


static func _arg(nom: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % nom):
			return a.split("=", true, 1)[1]
	return ""
