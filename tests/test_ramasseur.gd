extends SceneTree
## Tests sans écran du petit boulot de ramasseur de balles :
##   godot --headless --path . --script tests/test_ramasseur.gd

var _echecs := 0
var _verifs := 0


func _init() -> void:
	_tester_tirs()
	_tester_prise()
	_tester_paye()
	_tester_partie()
	print("Tests ramasseur : %d vérifications, %s" % [_verifs, "OK" if _echecs == 0 else "%d ÉCHEC(S)" % _echecs])
	quit(1 if _echecs > 0 else 0)


func _verifier(cond: bool, msg: String) -> void:
	_verifs += 1
	if not cond:
		_echecs += 1
		printerr("ÉCHEC : " + msg)


func _tester_tirs() -> void:
	var r := RamasseurRegles.new(42)
	var r2 := RamasseurRegles.new(42)
	_verifier(r.tir(5, false, 0.5) == r2.tir(5, false, 0.5), "même graine, même tir")
	for i in 3:
		var t := r.tir(i, false, 0.5)
		_verifier(not t["dore"], "pas de ballon du match pour commencer")
		_verifier(t["vol"] == RamasseurRegles.VOL_DEBUT, "les 3 premiers ballons volent lentement")
	var dores := 0
	for i in 500:
		var rush := i % 2 == 0
		var x0 := r.rng.randf()
		var t := r.tir(3 + i, rush, x0)
		if t["dore"]:
			dores += 1
		_verifier(t["x"] >= RamasseurRegles.BORD and t["x"] <= 1.0 - RamasseurRegles.BORD, "chute dans la touche (%.2f)" % t["x"])
		var dist := absf(t["x"] - x0)
		_verifier(dist <= RamasseurRegles.VITESSE * t["vol"] * RamasseurRegles.MARGE_COURSE + 0.001,
			"ballon atteignable (%.2f en %.2f s)" % [dist, t["vol"]])
		_verifier(dist >= RamasseurRegles.ECART_MIN - 0.001 or x0 < RamasseurRegles.BORD + RamasseurRegles.ECART_MIN
			or x0 > 1.0 - RamasseurRegles.BORD - RamasseurRegles.ECART_MIN, "il faut bouger (%.2f)" % dist)
		var base := RamasseurRegles.VOL_RUSH if rush else RamasseurRegles.VOL_CALME
		_verifier(is_equal_approx(t["vol"], base * (RamasseurRegles.VOL_DORE if t["dore"] else 1.0)), "durée de vol")
	_verifier(dores > 25 and dores < 100, "ballon du match de temps en temps (%d / 500)" % dores)
	_verifier(not RamasseurRegles.en_rush(29.9) and RamasseurRegles.en_rush(30.0), "le match s'emballe à 30 s")


func _tester_prise() -> void:
	_verifier(RamasseurRegles.attrape(0.5, 0.5), "pile dessous")
	_verifier(RamasseurRegles.attrape(0.5, 0.5 + RamasseurRegles.RAYON_PRISE * 0.9), "juste à côté")
	_verifier(not RamasseurRegles.attrape(0.5, 0.5 + RamasseurRegles.RAYON_PRISE * 1.2), "trop loin")


func _tester_paye() -> void:
	_verifier(RamasseurRegles.paye_prise(false, 1)["total"] == 1, "1 Jeton par ballon")
	_verifier(RamasseurRegles.paye_prise(true, 1)["total"] == 3, "ballon du match : +2")
	_verifier(RamasseurRegles.paye_prise(false, RamasseurRegles.SERIE_BONUS)["bonus"] == 1, "bonus de série")
	_verifier(RamasseurRegles.paye_prise(false, RamasseurRegles.SERIE_BONUS + 1)["bonus"] == 0, "bonus une fois par tranche")
	_verifier(RamasseurRegles.paye_remise(0.5) == 1, "remise rapide payée")
	_verifier(RamasseurRegles.paye_remise(RamasseurRegles.REMISE_RAPIDE + 0.1) == 0, "remise lente : rien")
	_verifier(RamasseurRegles.paye_finale(40, 0) == 40, "plein tarif à la 1re partie")
	_verifier(RamasseurRegles.paye_finale(41, RamasseurRegles.PARTIES_PLEIN_TARIF) == 21, "paye ÷ 2 après %d parties" % RamasseurRegles.PARTIES_PLEIN_TARIF)


## Partie simulée : un robot parfait, puis un joueur moyen (rate 1 ballon sur 4,
## relance lentement une fois sur deux). Même ordre de grandeur que la buvette.
func _tester_partie() -> void:
	for profil in ["parfait", "moyen"]:
		var r := RamasseurRegles.new(7)
		var aleat := RandomNumberGenerator.new()
		aleat.seed = 3
		var t := 0.0
		var n := 0
		var serie := 0
		var total := 0
		var x := 0.5
		while true:
			var b := r.tir(n, RamasseurRegles.en_rush(t), x)
			n += 1
			t += b["vol"]
			if t >= RamasseurRegles.DUREE:
				break
			var rate: bool = profil == "moyen" and aleat.randf() < 0.25
			if rate:
				serie = 0
				t += 0.8
				continue
			x = b["x"]
			serie += 1
			total += RamasseurRegles.paye_prise(b["dore"], serie)["total"]
			var attente := 0.4 if profil == "parfait" or aleat.randf() < 0.5 else 1.6
			total += RamasseurRegles.paye_remise(attente)
			t += attente + 0.5 + 0.6
		print("  partie %s simulée : %d ballons, %d Jetons" % [profil, n, total])
		if profil == "parfait":
			_verifier(total >= 30 and total <= 65, "paye d'une partie parfaite raisonnable (%d)" % total)
		else:
			_verifier(total >= 15 and total <= 40, "paye d'une partie moyenne raisonnable (%d)" % total)
