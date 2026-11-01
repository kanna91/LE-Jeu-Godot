class_name GenerateurEtage
extends RefCounted
## Génération des étages.
##
## **Grands étages** (demande de l'utilisateur, 2026-10-27 : « les étages doivent être grands », croisements,
## cercles) : environ TAILLE_ETAGE salles (29 avant). Une voie principale du départ au boss, puis des
## **branches** qui partent de préférence des salles à 1 ou 2 passages (elles deviennent des **carrefours** à 3 ou
## 4 passages, où le jeu met les grandes salles), puis des **cercles** : des tours de salles en rectangle qui
## partent d'une salle et y reviennent (on peut tourner en rond et semer un poursuivant), puis des **boucles** :
## deux salles voisines sur la carte mais éloignées d'au moins BOUCLE_MIN salles par le chemin sont reliées, et
## quelques autres voisines au hasard. Enfin les salles bonus et le marchand, comme avant.
## Valeurs choisies par Claude, à valider.

## Nombre de salles visé par étage, salles bonus comprises (décision de l'utilisateur : environ 80 depuis le 2026-10-30, 50 avant).
const TAILLE_ETAGE := 80
## Distance du boss au départ (en salles, par le plus court chemin) : de DISTANCE_BOSS.x à l'étage 1 à
## DISTANCE_BOSS.y au dernier étage (décision de l'utilisateur, 2026-11-01 : « 35 à 40 salles » ; 15 à 24 avant).
## La voie principale fait cette longueur, et **rien ne la raccourcit** : les boucles et les entrées des blocs qui
## créeraient un chemin plus court vers le boss sont refusées (``_raccourcit``).
const DISTANCE_BOSS := Vector2i(35, 40)
## Ancienne longueur de base de la voie principale (gardée pour les outils qui la lisent).
const VOIE_BASE := 35
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


## Distance voulue du boss au départ à l'étage ``etage`` (DISTANCE_BOSS, réparti sur les Donjon.NOMBRE_ETAGES étages).
static func distance_boss(etage: int) -> int:
	var n := maxi(1, Donjon.NOMBRE_ETAGES - 1)
	var t := clampf(float(etage - 1) / n, 0.0, 1.0)
	return int(round(lerpf(DISTANCE_BOSS.x, DISTANCE_BOSS.y, t)))


## Distances (en salles) de toutes les salles du plan à la salle ``depuis``.
static func _distances_plan(salles: Dictionary, depuis: int) -> Dictionary:
	var d := {depuis: 0}
	var file := [depuis]
	while not file.is_empty():
		var c: int = file.pop_front()
		for v in salles[c]["connexions"]:
			if not d.has(v):
				d[v] = d[c] + 1
				file.append(v)
	return d


## Vrai si relier ``a`` et ``b`` par un chemin de ``longueur`` passages raccourcirait le trajet du départ au boss
## (``ds`` : distances au départ, ``db`` : distances au boss, ``voulu`` : distance à garder).
static func _raccourcit(ds: Dictionary, db: Dictionary, a: int, b: int, longueur: int, voulu: int) -> bool:
	if not (ds.has(a) and ds.has(b) and db.has(a) and db.has(b)):
		return false
	return ds[a] + longueur + db[b] < voulu or ds[b] + longueur + db[a] < voulu


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


## Pose le bloc ``nom`` (BlocsSalles) dans le plan : ses salles (rôle « bloc », clés « bloc », « bloc_salle »,
## « bloc_instance ») sur des cases libres, reliées par ses liens, et ses entrées raccordées à des salles existantes
## (branche ou voie principale, ni départ ni boss). On préfère un emplacement où **toutes** les entrées tombent
## sur une salle existante ; une entrée sans salle derrière reçoit une nouvelle salle de branche. Sans aucun
## emplacement possible, le bloc n'est pas posé.
static func _poser_bloc(nom: String, instance: int, salles: Dictionary, par_case: Dictionary, interdites: Array,
		boss: int, ajouter: Callable, relier: Callable) -> bool:
	var b: Dictionary = BlocsSalles.BLOCS[nom]
	var hotes := []
	for i in salles:
		if salles[i]["role"] in ["branche", "principale"] and i != 1 and i != boss:
			hotes.append(i)
	var meilleurs := []
	var meilleur_score := -1
	var ds := _distances_plan(salles, 1)
	var db := _distances_plan(salles, boss)
	var voulu: int = ds.get(boss, 1 << 20)
	# Longueur du chemin à travers le bloc d'une entrée à l'autre (en passages)
	var traversee := 0
	if b["entrees"].size() >= 2:
		var cases_rel := {}
		for cle in b["salles"]:
			cases_rel[cle] = b["salles"][cle]["position"]
		var d_bloc := {b["entrees"][0][0]: 0}
		var file := [b["entrees"][0][0]]
		while not file.is_empty():
			var c: String = file.pop_front()
			for l in b["liens"]:
				for paire in [[l[0], l[2]], [l[2], l[0]]]:
					if paire[0] == c and not d_bloc.has(paire[1]):
						d_bloc[paire[1]] = d_bloc[c] + 1
						file.append(paire[1])
		traversee = int(d_bloc.get(b["entrees"][1][0], 0)) + 2
	for h in hotes:
		for e in b["entrees"]:
			var origine: Vector2i = salles[h]["position"] - b["salles"][e[0]]["position"] - e[2]
			var cases := BlocsSalles.cases(nom, origine)
			var libre := true
			for c in cases.values():
				if par_case.has(c) or c in interdites or c.y < 0:
					libre = false
					break
			if not libre:
				continue
			var score := 0
			for r in BlocsSalles.raccords(nom, origine):
				var autre: int = par_case.get(r[1], 0)
				if autre and salles[autre]["role"] in ["branche", "principale"] and autre != 1 and autre != boss:
					score += 1
				elif autre or r[1] in interdites or r[1].y < 0 or r[1] in cases.values():
					score = -100  # entrée bouchée (salle spéciale, case interdite) : emplacement refusé
			# Les deux entrées ne doivent pas faire un raccourci vers le boss
			var r := BlocsSalles.raccords(nom, origine)
			if r.size() >= 2 and score >= 2:
				var h1: int = par_case.get(r[0][1], 0)
				var h2: int = par_case.get(r[1][1], 0)
				if _raccourcit(ds, db, h1, h2, traversee, voulu):
					continue
			if score > meilleur_score:
				meilleur_score = score
				meilleurs = [origine]
			elif score == meilleur_score and not origine in meilleurs:
				meilleurs.append(origine)
	if meilleurs.is_empty() or meilleur_score < 1:
		return false
	var origine: Vector2i = meilleurs.pick_random()
	var ids := {}
	for cle in b["salles"]:
		var ident: int = ajouter.call(origine + b["salles"][cle]["position"], "bloc")
		salles[ident]["bloc"] = nom
		salles[ident]["bloc_salle"] = cle
		salles[ident]["bloc_instance"] = instance
		ids[cle] = ident
	for l in b["liens"]:
		relier.call(ids[l[0]], ids[l[2]])
	for r in BlocsSalles.raccords(nom, origine):
		var autre: int = par_case.get(r[1], 0)
		if not autre:
			autre = ajouter.call(r[1], "branche")
		relier.call(ids[r[0]], autre)
	return true


## Plan d'un étage : {id: {"position": Vector2i, "connexions": {id: true}, "role", "effet_bonus", "evenement"}}.
static func generer_plan(etage: int) -> Dictionary:
	var longueur := distance_boss(etage) + 1
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
	# Blocs de salles (BlocsSalles, 2026-10-31) : posés après les branches, avant les cercles
	var instance := 0
	for nom in BlocsSalles.BLOCS:
		for _k in int(BlocsSalles.BLOCS[nom].get("par_etage", 1)):
			instance += 1
			_poser_bloc(nom, instance, salles, par_case, interdites, boss, ajouter, relier)
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
	for ident in salles:
		if salles[ident]["role"] == "bloc":
			exclues.append(ident)  # un bloc n'a que ses liens et ses entrées
	var paires := []
	for ident in salles:
		for c in _voisines(salles[ident]["position"]):
			var autre: int = par_case.get(c, 0)
			if autre > ident and not salles[ident]["connexions"].has(autre) and not (ident in exclues) and not (autre in exclues):
				paires.append([ident, autre])
	paires.shuffle()
	var grandes := 0
	var voulu := voie.size() - 1
	var ds := _distances_plan(salles, 1)
	var db := _distances_plan(salles, boss)
	for p in paires:
		if grandes >= GRANDES_BOUCLES:
			break
		if _ecart(salles, p[0], p[1]) >= BOUCLE_MIN and not _raccourcit(ds, db, p[0], p[1], 1, voulu):
			relier.call(p[0], p[1])
			grandes += 1
			ds = _distances_plan(salles, 1)
			db = _distances_plan(salles, boss)
	for p in paires:
		if not salles[p[0]]["connexions"].has(p[1]) and randf() < PETITES_BOUCLES and not _raccourcit(ds, db, p[0], p[1], 1, voulu):
			relier.call(p[0], p[1])
			ds = _distances_plan(salles, 1)
			db = _distances_plan(salles, boss)
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
