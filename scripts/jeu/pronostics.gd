class_name Pronostics
extends RefCounted
## Règles des pronostics sur les vrais matchs (logique pure, sans état).
##
## Pronostics SANS MISE : le joueur ne risque rien. Un bon pronostic rapporte
## des Jetons en récompense fixe, un mauvais ne coûte rien. Pas de cote, pas de
## mise, et les Jetons ne s'achètent pas et ne se revendent pas. C'est ce qui
## tient le jeu hors du « jeu d'argent » (et du descripteur PEGI « jeu de hasard »).
##
## Un pronostic = un score (domicile, extérieur) + l'équipe qui marque en premier.
## Récompenses :
##   - bon résultat (victoire / nul / défaite)   : RECOMPENSE_RESULTAT
##   - score exact (en plus du résultat)         : RECOMPENSE_SCORE
##   - premier but (équipe, ou « aucun but »)    : RECOMPENSE_PREMIER_BUT
## Série : chaque bon résultat d'affilée augmente le multiplicateur des
## récompenses (+25 % par pronostic réussi, plafonné à ×2). Un mauvais
## résultat remet la série à zéro, rien d'autre.
##
## Le score retenu est celui de la fin du match, prolongation comprise,
## sans les tirs au but. Les buteurs ne sont jamais nommés (personnes réelles).

const RECOMPENSE_RESULTAT := 10
const RECOMPENSE_SCORE := 30
const RECOMPENSE_PREMIER_BUT := 10
const PAS_SERIE := 0.25
const MULTI_MAX := 2.0
## Nombre de pronostics en attente en même temps (évite de pronostiquer les
## 300 matchs du week-end pour « farmer » des Jetons).
const MAX_EN_ATTENTE := 12
const SCORE_MAX := 9
## Un match introuvable longtemps après son coup d'envoi est annulé.
const DELAI_ABANDON := 3 * 86400

const PREMIER_BUT := {"home": "Domicile", "away": "Extérieur", "aucun": "Aucun but"}


static func heure(m: Dictionary) -> int:
	## Même calcul que Donnees.heure_unix (sans dépendre de l'autoload, pour les tests).
	var s := str(m.get("kickoff_utc", ""))
	if s.length() < 19:
		return 0
	return int(Time.get_unix_time_from_datetime_string(s.left(19)))


static func multiplicateur(serie: int) -> float:
	## serie = nombre de bons résultats d'affilée AVANT ce pronostic.
	return minf(1.0 + PAS_SERIE * maxi(serie, 0), MULTI_MAX)


static func resultat(dom: int, ext: int) -> String:
	if dom > ext:
		return "1"
	if dom < ext:
		return "2"
	return "N"


static func premier_but_impose(dom: int, ext: int) -> String:
	## Le score pronostiqué fixe parfois le premier but : 0-0 => aucun, 2-0 => domicile.
	if dom == 0 and ext == 0:
		return "aucun"
	if ext == 0:
		return "home"
	if dom == 0:
		return "away"
	return ""


static func premier_but_coherent(dom: int, ext: int, pb: String) -> String:
	var impose := premier_but_impose(dom, ext)
	if impose != "":
		return impose
	return pb if pb in ["home", "away"] else "home"


static func ouvert(m: Dictionary, maintenant: int) -> bool:
	## On pronostique jusqu'au coup d'envoi, jamais pendant le match.
	if str(m.get("status", "")) != "SCHEDULED":
		return false
	var t := heure(m)
	return t > 0 and maintenant < t


static func creer(m: Dictionary, dom: int, ext: int, pb: String, maintenant: int) -> Dictionary:
	dom = clampi(dom, 0, SCORE_MAX)
	ext = clampi(ext, 0, SCORE_MAX)
	return {
		"match_id": str(m.get("id", "")),
		"dom": dom,
		"ext": ext,
		"premier_but": premier_but_coherent(dom, ext, pb),
		"kickoff": heure(m),
		"cree": maintenant,
		"etat": "attente",
		# Copie de ce qu'il faut pour afficher le pronostic après la disparition du match.
		"home": m.get("home", {}),
		"away": m.get("away", {}),
		"competition": m.get("competition", {}),
	}


static func observer(p: Dictionary, m: Dictionary) -> void:
	## Suit le score vu en direct : passer de 0-0 à 1-0 dit qui a marqué le premier.
	## Complète l'information du relais (first_goal) si le joueur était connecté.
	var sc: Variant = m.get("score", {}).get("current")
	if not sc is Dictionary:
		return
	var d := int(sc.get("home", 0))
	var e := int(sc.get("away", 0))
	var avant: Variant = p.get("vu")
	if avant is Dictionary and not p.has("premier_but_vu"):
		if int(avant["home"]) + int(avant["away"]) == 0 and d + e > 0:
			if d > 0 and e == 0:
				p["premier_but_vu"] = "home"
			elif e > 0 and d == 0:
				p["premier_but_vu"] = "away"
	p["vu"] = {"home": d, "away": e}


static func premier_but_reel(m: Dictionary, p: Dictionary) -> String:
	## "home", "away", "aucun", ou "" si on ne peut pas savoir.
	var sc: Variant = m.get("score", {}).get("current")
	if not sc is Dictionary:
		return ""
	var d := int(sc.get("home", 0))
	var e := int(sc.get("away", 0))
	if d == 0 and e == 0:
		return "aucun"
	if e == 0:
		return "home"
	if d == 0:
		return "away"
	var fg: Variant = m.get("first_goal")
	if fg is Dictionary and str(fg.get("team", "")) in ["home", "away"]:
		return str(fg["team"])
	return str(p.get("premier_but_vu", ""))


static func resoudre(p: Dictionary, m: Dictionary, serie: int, maintenant: int) -> Dictionary:
	## Renvoie {"fini": bool, "etat", "jetons", "resultat_ok", "score_ok", "premier_but_ok", "serie"}.
	## Ne modifie pas `p` : c'est l'appelant qui enregistre le résultat.
	var r := {"fini": false, "etat": "attente", "jetons": 0, "serie": serie}
	if m.is_empty():
		if maintenant - int(p.get("kickoff", maintenant)) > DELAI_ABANDON:
			r["fini"] = true
			r["etat"] = "annule"
		return r
	var statut := str(m.get("status", ""))
	if statut in ["CANCELLED", "POSTPONED"]:
		r["fini"] = true
		r["etat"] = "annule"
		return r
	if statut != "FINISHED":
		if statut == "UNKNOWN" and maintenant - int(p.get("kickoff", maintenant)) > DELAI_ABANDON:
			r["fini"] = true
			r["etat"] = "annule"
		return r
	var sc: Variant = m.get("score", {}).get("current")
	if not sc is Dictionary:
		return r  # terminé mais score pas encore publié : on attend
	var d := int(sc.get("home", 0))
	var e := int(sc.get("away", 0))
	var res_ok := resultat(int(p["dom"]), int(p["ext"])) == resultat(d, e)
	var score_ok := int(p["dom"]) == d and int(p["ext"]) == e
	var pb_reel := premier_but_reel(m, p)
	var pb_ok := pb_reel != "" and pb_reel == str(p["premier_but"])
	var base := 0
	if res_ok:
		base += RECOMPENSE_RESULTAT
	if score_ok:
		base += RECOMPENSE_SCORE
	if pb_ok:
		base += RECOMPENSE_PREMIER_BUT
	r["fini"] = true
	r["etat"] = "gagne" if base > 0 else "perdu"
	r["jetons"] = int(round(base * multiplicateur(serie)))
	r["multi"] = multiplicateur(serie)
	r["resultat_ok"] = res_ok
	r["score_ok"] = score_ok
	r["premier_but_ok"] = pb_ok
	r["premier_but_reel"] = pb_reel
	r["score_reel"] = {"home": d, "away": e}
	r["serie"] = serie + 1 if res_ok else 0
	return r
