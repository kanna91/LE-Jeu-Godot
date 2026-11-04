class_name GenerateurEtage
extends RefCounted
## Génération des étages.
##
## **Étage carré en 5 secteurs** (2026-11-04, décision de l'utilisateur ; avant : un long ruban, le boss au bout d'une
## voie de 35 à 40 salles) : un carré de COTE cases. Le **boss au centre**, le **départ au bas du secteur central**,
## une **prison à chaque coin**, les **complexes** (BlocsSalles : laboratoire, cuisine et jardin, bibliothèque) sur les
## côtés gauche, droit et haut (le bas reste libre pour d'autres complexes). Les salles ordinaires forment **5 secteurs de patrouille** (clé « secteur ») : un par
## coin (SALLES_COIN salles autour de sa prison, numéro du coin comme ``coins`` : 0 bas gauche, 1 bas droite, 2 haut
## gauche, 3 haut droite) et le secteur central (CENTRE, SALLES_CENTRE salles autour du boss, avec le départ). Un
## secteur de coin ne touche le centre que par FRONTIERES_PAR_COIN passages ; la salle du coin de chaque passage est une
## **salle frontière** (« frontiere ») où le geôlier du coin et le geôlier central peuvent se croiser. Aucun passage ne
## relie deux secteurs ailleurs (les complexes, fermés aux geôliers, relient les secteurs pour le héros).
## Le boss n'est plus éloigné du départ : il faut sa clé pour l'affronter (décision de l'utilisateur, 2026-11-04).
## Valeurs choisies par Claude, à valider.
##
## **Niveau des cryptes** (2026-11-03, demande de l'utilisateur) : un monde à part de SALLES_CRYPTES salles
## (generer_cryptes), dont ENTREES_CRYPTES entrées, aux 4 coins, mènent chacune au couloir d'une prison.

## Demi-côté du carré : x de -DEMI_COTE à DEMI_COTE, y de 0 à 2 × DEMI_COTE ; centre en (0, DEMI_COTE).
const DEMI_COTE := 9
const COTE := 2 * DEMI_COTE + 1
## Une case est dans le secteur d'un coin quand elle est à au moins BORD_COIN cases du centre en x et en y.
const BORD_COIN := 5
## Numéro du secteur central (les coins : 0 à 3).
const CENTRE := 4
## Salles ordinaires visées par secteur (sans la prison, le départ, le boss ni les salles bonus).
const SALLES_COIN := 9
const SALLES_CENTRE := 22
## Salle de départ : au bas du secteur central (rien en dessous : on y arrive par l'escalier).
const DEPART := Vector2i(0, DEMI_COTE - BORD_COIN + 1)
## Passages entre un secteur de coin et le centre.
const FRONTIERES_PAR_COIN := 1
## Cases hors du carré permises pour raccorder une entrée de complexe coincée contre le bord.
const MARGE := 2
## Longueur d'une branche, en salles.
const BRANCHE := Vector2i(1, 4)
## Grands cercles par secteur (salles voisines reliées alors que le chemin entre elles faisait au moins BOUCLE_MIN
## salles), et chance de relier deux salles voisines restantes du même secteur (petites boucles).
const GRANDES_BOUCLES := {CENTRE: 2, "coin": 1}
const BOUCLE_MIN := 6
const PETITES_BOUCLES := 0.12
## Prisons (demande de l'utilisateur, 2026-11-03) : une à chaque coin, faite de 2 grandes salles de prison puis d'un
## couloir dont le fond mène aux cryptes. Le couloir est au-dessus de la 2e grande salle sur la carte (on y entre par
## le bas de son image) ; la 1re grande salle est reliée à une salle du secteur du coin.
const PRISONS := 4
const SALLES_PAR_PRISON := 3
const SALLES_PRISONS := PRISONS * SALLES_PAR_PRISON
## Écart maximal (en cases) entre le couloir d'une prison et son coin (vérifié par les tests).
const PROCHE_COIN := 2
## Niveau des cryptes : nombre de salles, entrées (une par coin), cadre (cases) où elles tiennent, chance de relier
## deux salles voisines en plus du chemin qui les a fait pousser (petites boucles). Choix de Claude, à valider.
const SALLES_CRYPTES := 14
const ENTREES_CRYPTES := 4
const CADRE_CRYPTES := Vector2i(5, 4)
const BOUCLES_CRYPTES := 0.3
## Plans essayés au plus pour que tout trouve sa place (complexes, prisons, passages entre secteurs).
const ESSAIS := 30

const HAUT := Vector2i(0, 1)
const DROITE := Vector2i(1, 0)
const GAUCHE := Vector2i(-1, 0)
const BAS := Vector2i(0, -1)
const DIRECTIONS := [HAUT, DROITE, GAUCHE, BAS]


## Salles ordinaires « une par image » (2026-11-04) : nombre d'images ordinaires (ni bloc, ni prison, ni crypte).
static func salles_visees() -> int:
	var n := 0
	for image in PlanSalles.images():
		if not PlanSalles.reservee(String(image)):
			n += 1
	return n


static func _voisines(position: Vector2i) -> Array:
	var liste := []
	for d in DIRECTIONS:
		liste.append(position + d)
	return liste


## Secteur d'une case selon sa place dans le carré : 0 à 3 dans un coin, CENTRE ailleurs.
static func secteur_de(c: Vector2i) -> int:
	var dx := c.x
	var dy := c.y - DEMI_COTE
	if absi(dx) >= BORD_COIN and absi(dy) >= BORD_COIN:
		return (0 if dx < 0 else 1) + (0 if dy < 0 else 2)
	return CENTRE


static func dans_carre(c: Vector2i, marge := 0) -> bool:
	return absi(c.x) <= DEMI_COTE + marge and c.y >= 0 and c.y <= 2 * DEMI_COTE + marge


## Les 4 coins du carré, dans l'ordre de ``coins``.
static func coins_carre() -> Array:
	return [Vector2i(-DEMI_COTE, 0), Vector2i(DEMI_COTE, 0), Vector2i(-DEMI_COTE, 2 * DEMI_COTE), Vector2i(DEMI_COTE, 2 * DEMI_COTE)]


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Coins du cadre des positions : [bas gauche, bas droite, haut gauche, haut droite].
static func coins(positions: Array) -> Array:
	var bas := Vector2i(1 << 20, 1 << 20)
	var haut := -bas
	for p in positions:
		bas = Vector2i(mini(bas.x, p.x), mini(bas.y, p.y))
		haut = Vector2i(maxi(haut.x, p.x), maxi(haut.y, p.y))
	return [bas, Vector2i(haut.x, bas.y), Vector2i(bas.x, haut.y), haut]


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


## Nombre de salles à traverser pour aller de ``a`` à ``b`` (parcours en largeur).
static func _ecart(salles: Dictionary, a: int, b: int) -> int:
	return int(_distances_plan(salles, a).get(b, 1 << 20))


## Plan d'un étage : {id: {"position": Vector2i, "connexions": {id: true}, "role", "secteur", "frontiere",
## "effet_bonus", "evenement", ...}}. La salle 1 est le départ.
static func generer_plan(_etage: int) -> Dictionary:
	var plan := {}
	for _essai in ESSAIS:
		plan = _generer_plan()
		if not plan.is_empty() and blocs_complets(plan) and relie_sans_blocs(plan) and secteurs_complets(plan):
			break
	return plan


## Vrai si toutes les salles hors blocs se rejoignent sans traverser un bloc (les blocs sont fermés aux chasseurs).
static func relie_sans_blocs(plan: Dictionary) -> bool:
	var vus := {1: true}
	var file := [1]
	while not file.is_empty():
		var c: int = file.pop_front()
		for v in plan[c]["connexions"]:
			if not vus.has(v) and plan[v]["role"] != "bloc":
				vus[v] = true
				file.append(v)
	return vus.size() == plan.values().filter(func(s): return s["role"] != "bloc").size()


## Vrai si chaque bloc de BlocsSalles est posé autant de fois que voulu, en entier, dans le plan.
static func blocs_complets(plan: Dictionary) -> bool:
	var attendu := 0
	for nom in BlocsSalles.BLOCS:
		attendu += BlocsSalles.BLOCS[nom]["salles"].size() * int(BlocsSalles.BLOCS[nom].get("par_etage", 1))
	return plan.values().filter(func(s): return s["role"] == "bloc").size() == attendu


## Vrai si chaque coin a sa prison et ses FRONTIERES_PAR_COIN salles frontières, et qu'aucun passage ne relie deux
## secteurs ailleurs qu'à une frontière (les salles des blocs n'ont pas de secteur).
static func secteurs_complets(plan: Dictionary) -> bool:
	var prisons := {}
	var frontieres := {}
	for i in plan:
		var s: Dictionary = plan[i]
		if s["role"] == "prison":
			prisons[s["prison"]] = int(prisons.get(s["prison"], 0)) + 1
		if s.get("frontiere", false):
			frontieres[s["secteur"]] = int(frontieres.get(s["secteur"], 0)) + 1
		if not s.has("secteur"):
			continue
		for v in s["connexions"]:
			var t: Dictionary = plan[v]
			if t.has("secteur") and t["secteur"] != s["secteur"]:
				var coin: Dictionary = s if s["secteur"] != CENTRE else t
				var centre: Dictionary = t if s["secteur"] != CENTRE else s
				if centre["secteur"] != CENTRE or not coin.get("frontiere", false):
					return false
	for k in PRISONS:
		if int(prisons.get(k, 0)) != SALLES_PAR_PRISON or int(frontieres.get(k, 0)) != FRONTIERES_PAR_COIN:
			return false
	return true


## Salle où l'on peut accrocher un chemin, une branche ou une entrée de bloc.
static func _hote(s: Dictionary) -> bool:
	return s["role"] in ["branche", "principale"]


## Chemin à creuser : depuis la case libre ``depart`` jusqu'à une case voisine d'une des salles ``cibles`` ({id: true}),
## par des cases où ``permis`` est vrai. Coûts tirés au hasard (chemins sinueux) ; deux pas horizontaux de suite
## coûtent cher (PENALITE_HORIZONTALE) : une salle qui ne mène qu'à gauche et à droite a très peu d'images (8 apparences,
## contre 94 pour un couloir vertical), on préfère monter ou descendre en escalier. Renvoie [[cases du chemin, ``depart``
## en premier], id de la salle atteinte], ou [] sans chemin.
const PENALITE_HORIZONTALE := 4


static func _creuser(depart: Vector2i, cibles: Dictionary, par_case: Dictionary, permis: Callable) -> Array:
	# États : (x, y, 1 si on est arrivé par un pas horizontal)
	var e0 := Vector3i(depart.x, depart.y, 0)
	var cout := {e0: 0}
	var avant := {e0: null}
	var seaux := [[e0]]
	var k := 0
	while k < seaux.size():
		if seaux[k].is_empty():
			k += 1
			continue
		var e: Vector3i = seaux[k].pop_back()
		if int(cout[e]) != k:
			continue
		var c := Vector2i(e.x, e.y)
		for n in _voisines(c):
			var v: int = par_case.get(n, 0)
			if v and cibles.has(v):
				var chemin := []
				var q = e
				while q != null:
					var cq := Vector2i(q.x, q.y)
					# Un détour pour éviter deux pas horizontaux peut repasser par la même case : on coupe la boucle
					var deja := chemin.find(cq)
					if deja >= 0:
						chemin = chemin.slice(deja + 1)
					chemin.push_front(cq)
					q = avant[q]
				return [chemin, v]
		for d in DIRECTIONS:
			var n: Vector2i = c + d
			if par_case.has(n) or not permis.call(n):
				continue
			var horizontal := 1 if d.y == 0 else 0
			var nouveau := k + 1 + randi() % 2 + (PENALITE_HORIZONTALE if horizontal and e.z else 0)
			var en := Vector3i(n.x, n.y, horizontal)
			if cout.has(en) and int(cout[en]) <= nouveau:
				continue
			cout[en] = nouveau
			avant[en] = e
			while seaux.size() <= nouveau:
				seaux.append([])
			seaux[nouveau].append(en)
	return []


## Raison du dernier plan raté (pour les essais et les tests).
static var dernier_echec := ""


static func _echec(raison: String) -> Dictionary:
	dernier_echec = raison
	return {}


static func _generer_plan() -> Dictionary:
	var salles := {}
	var par_case := {}
	var ajouter := func(c: Vector2i, role: String, secteur: int) -> int:
		var ident: int = salles.size() + 1
		salles[ident] = {"position": c, "connexions": {}, "role": role}
		if secteur >= 0:
			salles[ident]["secteur"] = secteur
		par_case[c] = ident
		return ident
	var relier := func(a: int, b: int) -> void:
		salles[a]["connexions"][b] = true
		salles[b]["connexions"][a] = true
	var centre := Vector2i(0, DEMI_COTE)
	var depart: int = ajouter.call(DEPART, "depart", CENTRE)
	var boss: int = ajouter.call(centre, "boss", CENTRE)
	# Le boss n'a qu'un passage, par le bas ; rien sous le départ (on y arrive par l'escalier)
	var racine: int = ajouter.call(centre + BAS, "principale", CENTRE)
	relier.call(boss, racine)
	var interdites := [centre + GAUCHE, centre + DROITE, centre + HAUT, DEPART + BAS]
	var libre := func(c: Vector2i, marge: int) -> bool:
		return not par_case.has(c) and not (c in interdites) and dans_carre(c, marge)
	# 1. Complexes sur les côtés gauche, droit et haut (les plus grands d'abord), collés au bord
	var noms_blocs := BlocsSalles.BLOCS.keys()
	noms_blocs.sort_custom(func(a, b): return BlocsSalles.BLOCS[a]["salles"].size() > BlocsSalles.BLOCS[b]["salles"].size())
	var cotes := [GAUCHE, DROITE, HAUT]
	cotes.shuffle()
	var instance := 0
	var raccords := []  # [id de la salle du bloc, case de son entrée], raccordées à l'étape 5
	for nom in noms_blocs:
		for _k in int(BlocsSalles.BLOCS[nom].get("par_etage", 1)):
			instance += 1
			if not _poser_bloc(nom, instance, cotes, raccords, salles, par_case, interdites, ajouter, relier):
				return _echec("0")
	# Les cases des entrées restent libres jusqu'à leur raccordement
	for r in raccords:
		interdites.append(r[1])
	# 2. Prisons aux 4 coins : [hôte, grande A, grande B, couloir], le couloir au-dessus de la grande B
	var liste_coins := coins_carre()
	for k in PRISONS:
		var coin: Vector2i = liste_coins[k]
		var dedans := Vector2i(1 if coin.x < 0 else -1, 0)
		var grande_b: Vector2i = coin + (BAS if coin.y > 0 else Vector2i.ZERO)
		var couloir: Vector2i = grande_b + HAUT
		var grande_a: Vector2i = grande_b + dedans
		var hote_c: Vector2i = grande_a + dedans
		for c in [hote_c, grande_a, grande_b, couloir]:
			if par_case.has(c):
				return _echec("1")
		var hote: int = ajouter.call(hote_c, "branche", k)
		var precedente := hote
		var roles := ["grande_a", "grande_b", "couloir"]
		var cases := [grande_a, grande_b, couloir]
		for j in 3:
			var ident: int = ajouter.call(cases[j], "prison", k)
			salles[ident]["prison"] = k
			salles[ident]["prison_salle"] = roles[j]
			salles[ident]["coin"] = coin
			relier.call(precedente, ident)
			precedente = ident
	var hotes_de := func(secteur: int) -> Dictionary:
		var d := {}
		for i in salles:
			if _hote(salles[i]) and int(salles[i].get("secteur", -1)) == secteur:
				d[i] = true
		return d
	var creuser_dans := func(c: Vector2i, secteur: int, role: String) -> int:
		# Creuse depuis la case libre c jusqu'au secteur (cases de ce secteur seulement) ; renvoie la salle posée en c
		var r := _creuser(c, hotes_de.call(secteur), par_case,
			func(n: Vector2i) -> bool: return libre.call(n, 0) and secteur_de(n) == secteur)
		if r.is_empty():
			return 0
		var precedente: int = r[1]
		var chemin: Array = r[0]
		chemin.reverse()
		var premiere := 0
		for n in chemin:
			var ident: int = ajouter.call(n, role, secteur)
			relier.call(precedente, ident)
			precedente = ident
			premiere = ident
		return premiere
	# 3. Voie principale : du départ au boss, dans le secteur central
	var r0 := _creuser(DEPART + HAUT, {racine: true}, par_case,
		func(n: Vector2i) -> bool: return libre.call(n, 0) and secteur_de(n) == CENTRE)
	if r0.is_empty():
		return _echec("2")
	var precedente := depart
	for n in r0[0]:
		var ident: int = ajouter.call(n, "principale", CENTRE)
		relier.call(precedente, ident)
		precedente = ident
	relier.call(precedente, racine)
	# 4. Passages entre chaque coin et le centre (salles frontières), un par bord du coin si possible
	for k in PRISONS:
		var paires := []
		for x in range(-DEMI_COTE, DEMI_COTE + 1):
			for y in range(0, COTE):
				var a := Vector2i(x, y)
				if secteur_de(a) != k:
					continue
				for b in _voisines(a):
					if dans_carre(b) and secteur_de(b) == CENTRE:
						paires.append([a, b])
		# Les passages les plus courts d'abord (près des salles déjà posées du coin et du centre), un peu au hasard
		var proches := func(c: Vector2i, secteur: int) -> int:
			var m := 1 << 20
			for i in hotes_de.call(secteur):
				m = mini(m, _manhattan(c, salles[i]["position"]))
			return m
		for p in paires:
			p.append(proches.call(p[0], k) + 3 * proches.call(p[1], CENTRE) + randi() % 4)
		paires.sort_custom(func(x, y): return x[2] < y[2])
		var faites := []  # [case du coin, case du centre] des passages faits
		for strict in [true, false]:
			for p in paires:
				if faites.size() >= FRONTIERES_PAR_COIN:
					break
				var a: Vector2i = p[0]
				var b: Vector2i = p[1]
				if not libre.call(a, 0) or not libre.call(b, 0):
					continue
				# De préférence un passage par bord du coin (l'un horizontal, l'autre vertical), loin l'un de l'autre
				var trop_pres := false
				for f in faites:
					if _manhattan(a, f[0]) < 4 or (strict and ((a - b).x == 0) == ((f[0] - f[1]).x == 0)):
						trop_pres = true
				if trop_pres:
					continue
				# Le centre doit être joignable depuis b (une case coincée contre un complexe ne l'est pas)
				if _creuser(b, hotes_de.call(CENTRE), par_case,
						func(n: Vector2i) -> bool: return libre.call(n, 0) and secteur_de(n) == CENTRE).is_empty():
					continue
				par_case[b] = -1  # réservée le temps de creuser côté coin
				var sa: int = creuser_dans.call(a, k, "branche")
				par_case.erase(b)
				if not sa:
					continue
				var sb: int = creuser_dans.call(b, CENTRE, "branche")
				if not sb:
					return _echec("3")
				relier.call(sa, sb)
				salles[sa]["frontiere"] = true
				faites.append([a, b])
		if salles.values().filter(func(s): return s.get("frontiere", false) and s["secteur"] == k).size() < FRONTIERES_PAR_COIN:
			return _echec("4")
	# 5. Entrées des complexes : raccordées à la salle la plus proche (chemin dans la marge si besoin)
	for r in raccords:
		interdites.erase(r[1])
	for r in raccords:
		var bloc_id: int = r[0]
		var e: Vector2i = r[1]
		var deja: int = par_case.get(e, 0)
		if deja:
			if not _hote(salles[deja]):
				return _echec("5")
			relier.call(bloc_id, deja)
			continue
		var tous := {}
		for i in salles:
			if _hote(salles[i]):
				tous[i] = true
		var rr := _creuser(e, tous, par_case, func(n: Vector2i) -> bool: return libre.call(n, MARGE))
		if rr.is_empty():
			return _echec("6")
		var atteinte: int = rr[1]
		var secteur := int(salles[atteinte]["secteur"])
		var prec := atteinte
		var chemin: Array = rr[0]
		chemin.reverse()
		var premiere := 0
		for n in chemin:
			var ident: int = ajouter.call(n, "branche", secteur)
			relier.call(prec, ident)
			prec = ident
			premiere = ident
		relier.call(bloc_id, premiere)
	# 6. Branches : chaque secteur pousse jusqu'à sa taille, de préférence depuis des salles à 1 ou 2 passages
	for secteur in [CENTRE, 0, 1, 2, 3]:
		var visee := SALLES_CENTRE if secteur == CENTRE else SALLES_COIN
		var essais := 0
		while hotes_de.call(secteur).size() < visee and essais < 400:
			essais += 1
			var origines := []
			var poids := []
			for i in hotes_de.call(secteur):
				if i == racine:
					continue
				origines.append(i)
				poids.append(3.0 if salles[i]["connexions"].size() <= 2 else 0.5)
			if origines.is_empty():
				break
			var courante: int = U.choix_pondere(origines, poids)
			var direction := Vector2i.ZERO
			for _s in randi_range(BRANCHE.x, BRANCHE.y):
				if hotes_de.call(secteur).size() >= visee:
					break
				var libres := []
				for c in _voisines(salles[courante]["position"]):
					if libre.call(c, 0) and secteur_de(c) == secteur:
						libres.append(c)
				if libres.is_empty():
					break
				# Tout droit une fois sur deux à la verticale ; jamais deux pas horizontaux de suite si on peut l'éviter
				# (voir PENALITE_HORIZONTALE)
				var tout_droit: Vector2i = salles[courante]["position"] + direction
				var c: Vector2i
				if direction.y != 0 and tout_droit in libres and randf() < 0.5:
					c = tout_droit
				else:
					var poids_c := []
					for l in libres:
						var dl: Vector2i = l - salles[courante]["position"]
						poids_c.append(3.0 if dl.y != 0 else (0.15 if direction.y == 0 and direction != Vector2i.ZERO else 1.0))
					c = U.choix_pondere(libres, poids_c)
				direction = c - salles[courante]["position"]
				var nouvelle: int = ajouter.call(c, "branche", secteur)
				relier.call(courante, nouvelle)
				courante = nouvelle
	# 7. Boucles dans chaque secteur : grands cercles puis petites boucles (jamais entre deux secteurs)
	var paires_b := []
	for ident in salles:
		if not _hote(salles[ident]) or ident == racine:
			continue
		for c in _voisines(salles[ident]["position"]):
			var autre: int = par_case.get(c, 0)
			if autre > ident and _hote(salles[autre]) and autre != racine and not salles[ident]["connexions"].has(autre) \
					and salles[autre]["secteur"] == salles[ident]["secteur"]:
				paires_b.append([ident, autre])
	paires_b.shuffle()
	var grandes := {}
	for p in paires_b:
		var secteur := int(salles[p[0]]["secteur"])
		var maxi_s: int = GRANDES_BOUCLES[CENTRE] if secteur == CENTRE else GRANDES_BOUCLES["coin"]
		if int(grandes.get(secteur, 0)) < maxi_s and _ecart(salles, p[0], p[1]) >= BOUCLE_MIN:
			relier.call(p[0], p[1])
			grandes[secteur] = int(grandes.get(secteur, 0)) + 1
	for p in paires_b:
		if not salles[p[0]]["connexions"].has(p[1]) and randf() < PETITES_BOUCLES:
			relier.call(p[0], p[1])
	# 8. Marchand et salles bonus (dans le secteur de la salle qui y mène)
	var distances := _distances_plan(salles, depart)
	var candidats := []
	for i in salles:
		if salles[i]["role"] == "branche" and distances.get(i, 0) >= 4:
			candidats.append(i)
	if not candidats.is_empty():
		salles[candidats.pick_random()]["evenement"] = "marchand"
	var culs_de_sac := []
	var autres := []
	for i in salles:
		var s: Dictionary = salles[i]
		if s["role"] == "branche" and s["connexions"].size() == 1 and not s.has("evenement"):
			culs_de_sac.append(i)
		elif _hote(s) and i != racine:
			autres.append(i)
	culs_de_sac.shuffle()
	autres.shuffle()
	var places := []
	for effet_nombre in [["coffre", randi_range(2, 3)], ["soin", randi_range(1, 2)], ["choix_bonus", randi_range(1, 2)]]:
		for _n in effet_nombre[1]:
			for parent in culs_de_sac + autres:
				var libres := []
				for c in _voisines(salles[parent]["position"]):
					if not libre.call(c, 0):
						continue
					var loin := true
					for p in places:
						if _manhattan(c, p) < 2:
							loin = false
							break
					if loin:
						libres.append(c)
				if not libres.is_empty():
					var c: Vector2i = libres.pick_random()
					var bonus: int = ajouter.call(c, "bonus", int(salles[parent]["secteur"]))
					salles[bonus]["effet_bonus"] = effet_nombre[0]
					relier.call(parent, bonus)
					places.append(c)
					culs_de_sac.erase(parent)
					break
	if par_case.size() != salles.size():
		return _echec("deux salles sur la même case")
	return salles


## Pose le bloc ``nom`` (BlocsSalles) contre un des ``cotes`` libres (GAUCHE, DROITE, HAUT ; le côté pris est retiré) :
## ses salles (rôle « bloc », clés « bloc », « bloc_salle », « bloc_instance ») sur des cases libres du carré, hors des
## coins et à 2 cases au moins du boss, reliées par ses liens ; ses entrées vont dans ``raccords`` ([id, case]). Le bloc
## est collé au bord, ses entrées libres. Faux si aucun côté ne convient.
static func _poser_bloc(nom: String, instance: int, cotes: Array, raccords: Array, salles: Dictionary, par_case: Dictionary,
		interdites: Array, ajouter: Callable, relier: Callable) -> bool:
	var b: Dictionary = BlocsSalles.BLOCS[nom]
	for cote in cotes.duplicate():
		var meilleurs := []
		var meilleur_score := -(1 << 30)
		for ox in range(-DEMI_COTE - 8, DEMI_COTE + 9):
			for oy in range(-8, COTE + 8):
				var origine := Vector2i(ox, oy)
				var cases := BlocsSalles.cases(nom, origine)
				var score := 0
				var bon := true
				for c in cases.values():
					var dx: int = c.x
					var dy: int = c.y - DEMI_COTE
					if par_case.has(c) or c in interdites or not dans_carre(c) or secteur_de(c) != CENTRE \
							or absi(dx) + absi(dy) <= 2:
						bon = false
						break
					# Du bon côté : le bloc reste dans sa bande (vers le bord) ; le bas est pour le départ
					if (cote == GAUCHE and dx > -3) or (cote == DROITE and dx < 3) or (cote == HAUT and dy < 3):
						bon = false
						break
					score += -dx if cote == GAUCHE else (dx if cote == DROITE else dy)
				if not bon:
					continue
				for r in BlocsSalles.raccords(nom, origine):
					var e: Vector2i = r[1]
					if par_case.has(e) or e in interdites or e in cases.values() or e.y < 0:
						bon = false
						break
				if not bon:
					continue
				if score > meilleur_score:
					meilleur_score = score
					meilleurs = [origine]
				elif score == meilleur_score:
					meilleurs.append(origine)
		if meilleurs.is_empty():
			continue
		cotes.erase(cote)
		var origine: Vector2i = meilleurs.pick_random()
		var ids := {}
		for cle in b["salles"]:
			var ident: int = ajouter.call(origine + b["salles"][cle]["position"], "bloc", -1)
			salles[ident]["bloc"] = nom
			salles[ident]["bloc_salle"] = cle
			salles[ident]["bloc_instance"] = instance
			ids[cle] = ident
		for l in b["liens"]:
			relier.call(ids[l[0]], ids[l[2]])
		for r in BlocsSalles.raccords(nom, origine):
			raccords.append([ids[r[0]], r[1]])
		return true
	return false


## Plan du niveau des cryptes (2026-11-03) : {id: {"position", "connexions", "role": "crypte"}}, SALLES_CRYPTES
## salles d'un seul tenant dans un cadre de CADRE_CRYPTES cases, reliées par le chemin qui les a fait pousser et
## quelques boucles. Les ENTREES_CRYPTES entrées sont les salles les plus proches des 4 coins (« entree » : numéro du
## coin, comme ``coins`` ; « direction_passage » : côté sans salle, vers l'extérieur, où mène le passage vers la prison).
static func generer_cryptes() -> Dictionary:
	var cases := [Vector2i.ZERO]
	var parent := {Vector2i.ZERO: Vector2i.ZERO}
	while cases.size() < SALLES_CRYPTES:
		var options := []
		for c in cases:
			for d in DIRECTIONS:
				var n: Vector2i = c + d
				if parent.has(n):
					continue
				var cadre: Array = coins(cases + [n])
				var taille: Vector2i = cadre[3] - cadre[0] + Vector2i.ONE
				if taille.x <= CADRE_CRYPTES.x and taille.y <= CADRE_CRYPTES.y:
					options.append([c, n])
		if options.is_empty():
			break
		var choix: Array = options.pick_random()
		parent[choix[1]] = choix[0]
		cases.append(choix[1])
	var salles := {}
	var par_case := {}
	for c in cases:
		var ident := salles.size() + 1
		salles[ident] = {"position": c, "connexions": {}, "role": "crypte"}
		par_case[c] = ident
	for c in cases:
		if c != Vector2i.ZERO:
			salles[par_case[c]]["connexions"][par_case[parent[c]]] = true
			salles[par_case[parent[c]]]["connexions"][par_case[c]] = true
	for c in cases:
		for d in [DROITE, HAUT]:
			var n: Vector2i = c + d
			if par_case.has(n) and not salles[par_case[c]]["connexions"].has(par_case[n]) and randf() < BOUCLES_CRYPTES:
				salles[par_case[c]]["connexions"][par_case[n]] = true
				salles[par_case[n]]["connexions"][par_case[c]] = true
	# Entrées : la salle la plus proche de chaque coin, avec un côté libre vers l'extérieur
	var liste_coins := coins(cases)
	var exterieur := [[BAS, GAUCHE], [BAS, DROITE], [GAUCHE, HAUT], [DROITE, HAUT]]
	var prises := {}
	for k in mini(ENTREES_CRYPTES, liste_coins.size()):
		var tries := cases.duplicate()
		tries.sort_custom(func(a, b): return _manhattan(a, liste_coins[k]) < _manhattan(b, liste_coins[k]))
		for c in tries:
			if prises.has(c):
				continue
			var cote = null
			for d in exterieur[k] + DIRECTIONS:
				if not par_case.has(c + d):
					cote = d
					break
			if cote == null:
				continue
			prises[c] = true
			salles[par_case[c]]["entree"] = k
			salles[par_case[c]]["direction_passage"] = cote
			break
	return salles
