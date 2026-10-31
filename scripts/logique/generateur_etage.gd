class_name GenerateurEtage
extends RefCounted
## Génération des étages.
##
## **Grands étages** (demande de l'utilisateur, 2026-10-27 : « les étages doivent être grands », croisements,
## cercles) : environ TAILLE_ETAGE salles (29 avant). Une voie principale du départ au gardien, puis des
## **branches** qui partent de préférence des salles à 1 ou 2 passages (elles deviennent des **carrefours** à 3 ou
## 4 passages, où le jeu met les grandes salles), puis des **cercles** : des tours de salles en rectangle qui
## partent d'une salle et y reviennent (on peut tourner en rond et semer un poursuivant), puis des **boucles** :
## deux salles voisines sur la carte mais éloignées d'au moins BOUCLE_MIN salles par le chemin sont reliées, et
## quelques autres voisines au hasard. Enfin les salles bonus et le marchand, comme avant.
## Valeurs choisies par Claude, à valider.

## Nombre de salles visé par étage, salles bonus comprises (décision de l'utilisateur : environ 80 depuis le 2026-10-30, 50 avant).
const TAILLE_ETAGE := 80
## Longueur de la voie principale (départ → gardien) : VOIE_BASE + étage − 1, au plus VOIE_BASE + 8.
const VOIE_BASE := 16
## Longueur d'une branche, en salles.
const BRANCHE := Vector2i(2, 6)
## Grands cercles par étage, et écart minimal (en salles, par le chemin) entre les deux salles qu'ils relient.
const GRANDES_BOUCLES := 4
const BOUCLE_MIN := 6
## Chance de relier deux salles voisines restantes (petites boucles).
const PETITES_BOUCLES := 0.12
## Salles bonus prévues (coffres, soins, choix de bonus) : 4 à 7.
const BONUS_PREVUS := 6
## Salles réservées aux cercles : des tours en rectangle de CERCLE cases de long sur 1 ou 2 de large (26 depuis le
## 2026-10-30, 16 avant : même part de l'étage).
const SALLES_CERCLES := 26
const CERCLE := Vector2i(1, 3)

const HAUT := Vector2i(0, 1)
const DROITE := Vector2i(1, 0)
const GAUCHE := Vector2i(-1, 0)
const BAS := Vector2i(0, -1)
const DIRECTIONS := [HAUT, DROITE, GAUCHE, BAS]
const LARGEUR_MAX := 8


static func _voisines(position: Vector2i) -> Array:
	var liste := []
	for d in DIRECTIONS:
		liste.append(position + d)
	return liste


## Voie principale, de la salle de départ (0, 0) à la salle du boss : marche qui monte surtout.
static func _voie_principale(longueur: int) -> Array:
	var meilleure := []
	for _essai in 300:
		var chemin := [Vector2i(0, 0)]
		var direction = null
		var alignees := 0
		while chemin.size() < longueur:
			var options := []
			var poids := []
			for dp in [[HAUT, 2.0], [DROITE, 1.0], [GAUCHE, 1.0]]:
				var d: Vector2i = dp[0]
				if direction != null and d == -direction:
					continue
				if alignees >= 3 and direction != null and d == direction:
					continue
				var c: Vector2i = chemin[-1] + d
				if c in chemin or absi(c.x) > LARGEUR_MAX:
					continue
				var touche := false
				for v in _voisines(c):
					if v in chemin.slice(0, chemin.size() - 1):
						touche = true
						break
				if touche:
					continue
				options.append([d, c])
				poids.append(dp[1])
			if options.is_empty():
				break
			var choisie: Array = U.choix_pondere(options, poids)
			alignees = alignees + 1 if (direction != null and choisie[0] == direction) else 1
			direction = choisie[0]
			chemin.append(choisie[1])
		if chemin.size() > meilleure.size():
			meilleure = chemin
		if chemin.size() == longueur and chemin[-1].y >= longueur / 2:
			return chemin
	return meilleure


## Cases du tour d'un rectangle de ``l`` × ``h`` cases (sens ``sx``, ``sy``) dont ``p`` est un coin, dans l'ordre,
## en commençant par ``p``.
static func _rectangle(p: Vector2i, l: int, h: int, sx: int, sy: int) -> Array:
	var cases := []
	for k in l:
		cases.append(p + Vector2i(k * sx, 0))
	for k in h:
		cases.append(p + Vector2i(l * sx, k * sy))
	for k in l:
		cases.append(p + Vector2i((l - k) * sx, h * sy))
	for k in h:
		cases.append(p + Vector2i(0, (h - k) * sy))
	return cases


## Nombre de salles à traverser pour aller de ``a`` à ``b`` (parcours en largeur).
static func _ecart(salles: Dictionary, a: int, b: int) -> int:
	var distances := {a: 0}
	var file := [a]
	while not file.is_empty():
		var c: int = file.pop_front()
		if c == b:
			return distances[c]
		for v in salles[c]["connexions"]:
			if not distances.has(v):
				distances[v] = distances[c] + 1
				file.append(v)
	return 1 << 20


## Plan d'un étage : {id: {"position": Vector2i, "connexions": {id: true}, "role", "effet_bonus", "evenement"}}.
static func generer_plan(etage: int) -> Dictionary:
	var longueur := VOIE_BASE + mini(8, etage - 1)
	var voie := _voie_principale(longueur)
	var salles := {}
	var par_case := {}
	var ajouter := func(c: Vector2i, role: String) -> int:
		var ident: int = salles.size() + 1
		salles[ident] = {"position": c, "connexions": {}, "role": role}
		par_case[c] = ident
		return ident
	var relier := func(a: int, b: int) -> void:
		salles[a]["connexions"][b] = true
		salles[b]["connexions"][a] = true
	for i in voie.size():
		var role := "depart" if i == 0 else ("boss" if i == voie.size() - 1 else "principale")
		var ident: int = ajouter.call(voie[i], role)
		if i:
			relier.call(ident - 1, ident)
	var boss := voie.size()
	var interdites := _voisines(voie[-1]) + [Vector2i(0, -1)]
	# Branches jusqu'à la taille visée, de préférence depuis des salles à 1 ou 2 passages (futurs carrefours)
	var essais := 0
	while salles.size() < TAILLE_ETAGE - BONUS_PREVUS - SALLES_CERCLES and essais < 400:
		essais += 1
		var origines := []
		var poids := []
		for i in salles:
			var role: String = salles[i]["role"]
			if role == "branche" or (role == "principale" and 2 <= i and i <= boss - 2):
				var n: int = salles[i]["connexions"].size()
				origines.append(i)
				poids.append(3.0 if n <= 2 else 0.5)
		if origines.is_empty():
			break
		var courante: int = U.choix_pondere(origines, poids)
		var direction := Vector2i.ZERO
		for _s in randi_range(BRANCHE.x, BRANCHE.y):
			if salles.size() >= TAILLE_ETAGE - BONUS_PREVUS - SALLES_CERCLES:
				break
			var libres := []
			for c in _voisines(salles[courante]["position"]):
				if not par_case.has(c) and not (c in interdites) and c.y >= 0:
					libres.append(c)
			if libres.is_empty():
				break
			# Tout droit une fois sur deux (couloirs), sinon au hasard
			var tout_droit: Vector2i = salles[courante]["position"] + direction
			var c: Vector2i = tout_droit if (direction != Vector2i.ZERO and tout_droit in libres and randf() < 0.5) else libres.pick_random()
			direction = c - salles[courante]["position"]
			var nouvelle: int = ajouter.call(c, "branche")
			relier.call(courante, nouvelle)
			courante = nouvelle
	# Cercles : un tour de salles en rectangle qui part d'une salle existante et y revient
	essais = 0
	while salles.size() < TAILLE_ETAGE - BONUS_PREVUS and essais < 300:
		essais += 1
		var depuis := []
		for i in salles:
			if salles[i]["role"] in ["branche", "principale"] and i != 1 and i != boss:
				depuis.append(i)
		var a: int = depuis.pick_random()
		var tour := _rectangle(salles[a]["position"], randi_range(CERCLE.x, CERCLE.y), randi_range(1, 2),
			[-1, 1].pick_random(), [-1, 1].pick_random())
		if tour.size() - 1 > TAILLE_ETAGE - BONUS_PREVUS - salles.size() + 2:
			continue
		var possible := true
		for c in tour.slice(1):
			if par_case.has(c) or c in interdites or c.y < 0:
				possible = false
				break
		if not possible:
			continue
		var precedente := a
		for c in tour.slice(1):
			var nouvelle: int = ajouter.call(c, "branche")
			relier.call(precedente, nouvelle)
			precedente = nouvelle
		relier.call(precedente, a)
	# Boucles : grands cercles (salles voisines mais loin l'une de l'autre par le chemin), puis petites boucles
	var exclues := [1, boss]
	var paires := []
	for ident in salles:
		for c in _voisines(salles[ident]["position"]):
			var autre: int = par_case.get(c, 0)
			if autre > ident and not salles[ident]["connexions"].has(autre) and not (ident in exclues) and not (autre in exclues):
				paires.append([ident, autre])
	paires.shuffle()
	var grandes := 0
	for p in paires:
		if grandes >= GRANDES_BOUCLES:
			break
		if _ecart(salles, p[0], p[1]) >= BOUCLE_MIN:
			relier.call(p[0], p[1])
			grandes += 1
	for p in paires:
		if not salles[p[0]]["connexions"].has(p[1]) and randf() < PETITES_BOUCLES:
			relier.call(p[0], p[1])
	var distances := {1: 0}
	var file := [1]
	while not file.is_empty():
		var courante: int = file.pop_front()
		for voisine in salles[courante]["connexions"]:
			if not distances.has(voisine):
				distances[voisine] = distances[courante] + 1
				file.append(voisine)
	var candidats := []
	for i in salles:
		if salles[i]["role"] == "branche" and distances.get(i, 0) >= 4:
			candidats.append(i)
	if candidats.is_empty():
		for i in salles:
			if salles[i]["role"] == "principale" and distances.get(i, 0) >= 4:
				candidats.append(i)
	if not candidats.is_empty():
		salles[candidats.pick_random()]["evenement"] = "marchand"
	var culs_de_sac := []
	for i in salles:
		var s: Dictionary = salles[i]
		if s["role"] == "branche" and s["connexions"].size() == 1 and not s.has("evenement"):
			culs_de_sac.append(i)
	var autres := []
	for i in salles:
		if salles[i]["role"] in ["branche", "principale"] and not (i in culs_de_sac):
			autres.append(i)
	culs_de_sac.shuffle()
	autres.shuffle()
	var places := []
	for effet_nombre in [["coffre", randi_range(2, 3)], ["soin", randi_range(1, 2)], ["choix_bonus", randi_range(1, 2)]]:
		for _n in effet_nombre[1]:
			for parent in culs_de_sac + autres:
				var libres := []
				for c in _voisines(salles[parent]["position"]):
					if par_case.has(c) or c in interdites or c.y < 0:
						continue
					var loin := true
					for p in places:
						if absi(c.x - p.x) + absi(c.y - p.y) < 2:
							loin = false
							break
					if loin:
						libres.append(c)
				if not libres.is_empty():
					var c: Vector2i = libres.pick_random()
					var bonus: int = ajouter.call(c, "bonus")
					salles[bonus]["effet_bonus"] = effet_nombre[0]
					relier.call(parent, bonus)
					places.append(c)
					if parent in culs_de_sac:
						culs_de_sac.erase(parent)
					break
	return salles
