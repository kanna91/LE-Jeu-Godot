class_name PlanSalles
extends RefCounted
## Attribution des salles peintes (``donnees/salles_peintes``) aux salles du plan du donjon.
##
## Orientation fixe (2026-10-18, demande de l'utilisateur) : le haut de l'image est toujours le haut de
## la mini-carte. Aller vers le fond de l'image = monter sur la carte, reculer (bas de l'image) = descendre,
## la porte de gauche = la salle de gauche. Les sorties d'une image sont donc des directions de la carte :
## « devant » = haut (0, 1), « bas » = bas (0, -1), « gauche » = (-1, 0), « droite » = (1, 0).
## Une image peut être affichée en miroir (gauche et droite échangées).
##
## Pour chaque salle du plan, on essaie toutes les images × miroir et on garde celle dont les sorties
## tombent exactement sur les salles voisines.
##
## **Sorties potentielles** (2026-11-03, demande de l'utilisateur ; touche O de l'éditeur de zones, clé
## « sorties_potentielles » du .json) : une image peut avoir plusieurs sorties possibles d'un même côté (gauche,
## droite, fond). À l'habillage de l'étage, s'il y a une salle de ce côté, **une seule** de ces sorties y mène (tirage
## stable) ; les autres, et toutes si aucune salle n'est de ce côté, deviennent un mur invisible, sans malus. Une
## sortie ordinaire du même côté passe avant elles. Une même image sert ainsi à beaucoup plus de formes de salles.
##
## Critères, dans l'ordre :
## 1. aucun passage sans porte peinte (sinon flèche de secours) ;
## 2. le moins de portes visibles sans salle derrière (porte condamnée). Le bas de l'image ne compte
##    pas : il est hors de l'image (derrière le spectateur), on le ferme simplement (mur invisible) ;
## 3. salle 1 pour la salle de départ, salle 2 pour le boss ; puis un tirage stable pour varier.
##
## Enregistré dans la salle (clé « salle_peinte », sauvegardée avec la partie) :
## { "v": 5, "image": "porte3", "miroir": false, "face": [0, 1],
##   "sorties": [id ou null, ...] (une par sortie de l'image), "sans_porte": [id, ...] }
## L'écran d'exploration y ajoute « portes_ouvertes » et « sortie_prise » ({id voisine : sortie}).

## 3 : portes de côté ajoutées aux salles porte 1 à 4 et 6 (2026-10-18) : sorties renumérotées.
## 4 : porte de gauche de la salle porte 1 retirée (cachée dans l'ombre : la salle semblait un couloir).
## 5 : orientation fixe (image = mini-carte) et salles cul-de-sac 1 à 7.
## 6 : grandes salles (carrefours des grands étages, 2026-10-27).
## 7 : chaque apparence (image × miroir) une seule fois par étage (2026-10-30, demande de l'utilisateur).
const VERSION := 7
## Image préférée de la salle de départ et de la salle du boss.
const IMAGE_DEPART := "salle1"
const IMAGE_BOSS := "salle2"
## Poids du choix (voir l'en-tête).
const PENALITE_SANS_PORTE := 1000
## En plus, pour un passage sans porte vers l'entrée d'un bloc (2026-11-04, étage carré) : la salle devant un complexe
## garde toujours sa porte vers lui, quitte à perdre une autre porte.
const PENALITE_SANS_PORTE_BLOC := 2000
const PENALITE_PORTE_CONDAMNEE := 30
const BONUS_IMAGE_PREFEREE := 15
## Grandes salles (``"grande_salle"`` du .json, images de l'utilisateur) réservées aux **carrefours** (décision de
## l'utilisateur, 2026-10-27) : bonus dans une salle à 3 ou 4 passages, malus ailleurs. Leurs passages de bord
## (type « bord ») sans salle derrière deviennent un mur invisible, sans malus, comme le bas de l'image.
const BONUS_CARREFOUR := 20
const PENALITE_GRANDE_HORS_CARREFOUR := 40
## Prisons (2026-11-03, demande de l'utilisateur) : 4 prisons aux 4 coins de l'étage (GenerateurEtage._poser_prisons),
## chacune faite de 2 grandes salles de prison (images « prison », clé « prison_salle » : « grande_a », « grande_b ») et
## d'un couloir (images « couloir_prison », « prison_salle » : « couloir ») dont le fond mène au niveau des cryptes.
## Ces images ne servent que là, chacune une fois par étage ; le cachot est pris parmi les grandes salles de prison
## (Aventure.preparer_etage). Avant (2026-10-30) : un « quartier des prisons » loin du boss.
const PREFIXE_PRISON := "prison"
const PREFIXE_COULOIR_PRISON := "couloir_prison"
## Cryptes (2026-11-03) : toutes les images « crypte » forment le **niveau des cryptes**, un monde à part de 14 salles
## (Donjon.NIVEAU_CRYPTES, clé « crypte » de ses salles), et ne servent plus sur l'étage (avant : un quartier des
## cryptes dans chaque étage, 2026-11-02). Les ennemis y suivent la zone « crypte » de donnees/zones.json (Zones).
const PREFIXE_CRYPTE := "crypte"
## Passage vers un autre niveau (clé « passage_niveau » d'une salle : {niveau, salle, direction}) : pendant
## l'habillage, il compte comme une salle voisine dans sa direction, pour qu'une sortie de l'image y mène ; cette sortie
## est ensuite notée « passage » dans « salle_peinte » (son entrée dans « sorties » reste null).
const PASSAGE := "__passage__"
## Le héros regarde toujours vers le haut de la carte (la lettre t de donjon.avancer = (0, 1), le nord).
const FACE := Vector2i(0, 1)
## Noms des directions de la carte (catalogue, tests).
const NOMS_DIRECTIONS := {Vector2i(0, 1): "haut", Vector2i(0, -1): "bas", Vector2i(-1, 0): "gauche",
	Vector2i(1, 0): "droite"}

static var _images := {}


## Directions des sorties de chaque image (sans miroir) : {id: ["devant", "bas"], ...}.
static func images() -> Dictionary:
	if _images.is_empty():
		for id in SallePeinte.salles_disponibles():
			_images[id] = SallePeinte.lire_salle(id).get("directions_sorties", [])
	return _images


## Directions des sorties d'une image, gauche et droite échangées en miroir.
static func directions(image: String, miroir: bool) -> Array:
	var liste: Array = images().get(image, []).duplicate()
	if miroir:
		for i in liste.size():
			liste[i] = {"gauche": "droite", "droite": "gauche"}.get(liste[i], liste[i])
	return liste


## Direction de la carte d'une sortie relative (« devant », « gauche »...) pour un héros tourné vers ``face``.
static func absolue(relative: String, face: Vector2i) -> Vector2i:
	match relative:
		"devant":
			return face
		"gauche":
			return Vector2i(-face.y, face.x)
		"droite":
			return Vector2i(face.y, -face.x)
	return -face


## Attribue une salle peinte aux salles de l'étage qui n'en ont pas encore (ou d'une ancienne version).
## Chaque apparence (image × miroir) ne sert qu'**une fois par étage** (2026-10-30, demande de l'utilisateur) :
## affectation globale au meilleur total des scores (_affectation, méthode hongroise) plutôt que salle par salle.
## Les apparences déjà prises par des salles gardées sont exclues. Les salles réservées (prisons, couloirs des
## prisons, cryptes : groupes_reserves) prennent leurs propres images. S'il y a plus de salles que d'apparences
## libres (depuis que les cryptes et les prisons ne servent plus ailleurs, 2026-11-03), chaque apparence peut servir
## une fois de plus, autant de fois qu'il faut.
static func attribuer(donjon, etage: int) -> void:
	var salles: Dictionary = donjon.plan_donjon.get(etage, {})
	if salles.is_empty() or images().is_empty():
		return
	var a_faire := []
	var prises := {}
	for id in salles:
		var info: Dictionary = salles[id].get("salle_peinte", {})
		# Gardée si elle est à jour et que l'image a toujours le même nombre de sorties (l'éditeur de zones peut en
		# ajouter ou en retirer depuis le 2026-11-01)
		if int(info.get("v", 0)) == VERSION and images().has(String(info.get("image", ""))) \
				and info.get("sorties", []).size() == images()[String(info["image"])].size():
			prises["%s|%s" % [info["image"], bool(info.get("miroir", false))]] = true
			continue
		a_faire.append(String(id))
	if a_faire.is_empty():
		return
	attribuer_salles(salles, etage, a_faire, prises)


## Habille les salles ``a_faire`` (voir attribuer) ; renvoie le total des scores (plus haut = mieux).
static func attribuer_salles(salles: Dictionary, etage: int, a_faire: Array, prises := {}) -> int:
	var total := 0
	for groupe in groupes_reserves(salles):
		var r := _attribuer_groupe(salles, etage, a_faire, groupe[0], groupe[1], prises)
		a_faire = r[0]
		total += r[1]
	if a_faire.is_empty():
		return total
	return total + _attribuer_ordinaires(salles, etage, a_faire, prises)


## Pénalité d'une salle qui reçoit le miroir d'une image déjà utilisée (2e et dernière fois), plutôt qu'une image neuve.
const PENALITE_DEUXIEME := 25


## Salles ordinaires (2026-11-04, règle de l'utilisateur) : **chaque image une seule fois** ; s'il y a plus de salles
## que d'images, les salles en trop reçoivent le **miroir** d'une image déjà utilisée (au plus une fois par image :
## jamais deux fois la même apparence, jamais trois fois la même image). Deux affectations globales (méthode
## hongroise) : 1) une image par salle (à l'endroit ou en miroir, le mieux) ; les salles en trop prennent une colonne
## « attendre » dont le coût est leur meilleur score moins PENALITE_DEUXIEME ; 2) ces salles reçoivent l'apparence
## restante (l'autre sens) d'une image utilisée. Renvoie le total des scores.
static func _attribuer_ordinaires(salles: Dictionary, etage: int, a_faire: Array, prises: Dictionary) -> int:
	var noms: Array = images().keys().filter(func(i): return not reservee(String(i)))
	noms.sort()
	var usages := {}  # image → [miroirs déjà utilisés]
	for cle in prises:
		var morceaux: PackedStringArray = String(cle).split("|")
		if not reservee(morceaux[0]):
			if not usages.has(morceaux[0]):
				usages[morceaux[0]] = []
			usages[morceaux[0]].append(morceaux[1] == "true")
	# Scores de chaque salle pour chaque apparence
	var evals := {}
	for id in a_faire:
		for image in noms:
			for miroir in [false, true]:
				evals["%s|%s|%s" % [id, image, miroir]] = _evaluer(salles, id, etage, image, miroir)
	var total := 0
	# 1) images neuves
	var neuves: Array = noms.filter(func(i): return not usages.has(i))
	var rangs := a_faire.duplicate()
	var en_trop := maxi(0, rangs.size() - neuves.size())
	var couts := []
	for id in rangs:
		var ligne := []
		var meilleur := -INF
		for image in noms:
			for miroir in [false, true]:
				meilleur = maxf(meilleur, float(evals["%s|%s|%s" % [id, image, miroir]][0]))
		for image in neuves:
			ligne.append(-float(maxi(evals["%s|%s|false" % [id, image]][0], evals["%s|%s|true" % [id, image]][0])))
		for _k in en_trop:
			ligne.append(-(meilleur - PENALITE_DEUXIEME))
		couts.append(ligne)
	var reste := []
	if not rangs.is_empty() and neuves.size() + en_trop > 0:
		var choix := _affectation(couts, rangs.size(), neuves.size() + en_trop)
		for k in rangs.size():
			if choix[k] >= neuves.size():
				reste.append(rangs[k])
				continue
			var image: String = neuves[choix[k]]
			var a: Array = evals["%s|%s|false" % [rangs[k], image]]
			var b: Array = evals["%s|%s|true" % [rangs[k], image]]
			var e: Array = a if a[0] >= b[0] else b
			salles[rangs[k]]["salle_peinte"] = e[1]
			usages[image] = [bool(e[1]["miroir"])]
			total += int(e[0])
	else:
		reste = rangs
	if reste.is_empty():
		return total
	# 2) l'autre sens d'une image déjà utilisée une seule fois
	var libres := []
	for image in noms:
		var u: Array = usages.get(image, [])
		if u.size() == 0:
			libres.append([image, false])
			libres.append([image, true])
		elif u.size() == 1:
			libres.append([image, not bool(u[0])])
	if reste.size() > libres.size():
		push_warning("PlanSalles : plus de salles ordinaires (%d) que d'apparences libres (%d) : des images reviennent" % [reste.size(), libres.size()])
		var une_fois := []
		for image in noms:
			une_fois.append([image, false])
			une_fois.append([image, true])
		while reste.size() > libres.size():
			libres += une_fois
	couts = []
	for id in reste:
		var ligne := []
		for l in libres:
			ligne.append(-float(evals["%s|%s|%s" % [id, l[0], l[1]]][0]))
		couts.append(ligne)
	var choix2 := _affectation(couts, reste.size(), libres.size())
	for k in reste.size():
		var e: Array = evals["%s|%s|%s" % [reste[k], libres[choix2[k]][0], libres[choix2[k]][1]]]
		salles[reste[k]]["salle_peinte"] = e[1]
		total += int(e[0])
	return total


## Groupes de salles réservées : [[{id: true}, [images]], ...] : grandes salles des prisons, couloirs des prisons,
## salles des cryptes.
static func groupes_reserves(salles: Dictionary) -> Array:
	var grandes := {}
	var couloirs := {}
	var cryptes := {}
	for id in salles:
		var s: Dictionary = salles[id]
		var role := String(s.get("prison_salle", ""))
		if role in ["grande_a", "grande_b"]:
			grandes[String(id)] = true
		elif role == "couloir":
			couloirs[String(id)] = true
		elif s.get("crypte", false):
			cryptes[String(id)] = true
	return [[grandes, _images_prefixe(PREFIXE_PRISON)], [couloirs, _images_prefixe(PREFIXE_COULOIR_PRISON)],
		[cryptes, images_cryptes()]]


static func _images_prefixe(prefixe: String) -> Array:
	var liste := images().keys().filter(func(i): return String(i).begins_with(prefixe) and not BlocsSalles.image_de_bloc(String(i)))
	liste.sort()
	return liste


## Vrai si l'image ne sert que dans des salles réservées (blocs, prisons, couloirs des prisons, cryptes).
static func reservee(image: String) -> bool:
	return BlocsSalles.image_de_bloc(image) or est_crypte(image) or est_prison(image) or est_couloir_prison(image)


## Images ``colonnes`` pour les salles ``ids`` de ``a_faire`` : chaque image une seule fois (miroir ou non, le
## meilleur), affectation globale ; s'il y a plus de salles que d'images, chaque image peut resservir. Renvoie
## [salles de ``a_faire`` qui restent à habiller, total des scores].
static func _attribuer_groupe(salles: Dictionary, etage: int, a_faire: Array, ids: Dictionary, colonnes: Array, prises: Dictionary) -> Array:
	var lignes := a_faire.filter(func(id): return ids.has(id))
	if lignes.is_empty() or colonnes.is_empty():
		return [a_faire, 0]
	var libres := colonnes.filter(func(image): return not prises.has("%s|false" % image) and not prises.has("%s|true" % image))
	if libres.is_empty():
		libres = colonnes.duplicate()
	var une_fois := libres.duplicate()
	while lignes.size() > libres.size():
		libres += une_fois
	var couts := []
	var infos := []
	for id in lignes:
		var ligne := []
		var ligne_infos := []
		for image in libres:
			var a := _evaluer(salles, id, etage, image, false)
			var b := _evaluer(salles, id, etage, image, true)
			var e: Array = a if a[0] >= b[0] else b
			ligne.append(-float(e[0]))
			ligne_infos.append(e[1])
		couts.append(ligne)
		infos.append(ligne_infos)
	var choix := _affectation(couts, lignes.size(), libres.size())
	var total := 0
	for k in lignes.size():
		var info: Dictionary = infos[k][choix[k]]
		salles[lignes[k]]["salle_peinte"] = info
		prises["%s|%s" % [info["image"], info["miroir"]]] = true
		total -= int(couts[k][choix[k]])
	return [a_faire.filter(func(id): return not ids.has(id)), total]


## Affectation de coût minimal (méthode hongroise, n lignes ≤ m colonnes) : colonne choisie pour chaque ligne,
## toutes différentes.
static func _affectation(cout: Array, n: int, m: int) -> Array:
	var infini := 1e18
	var u := []
	u.resize(n + 1)
	u.fill(0.0)
	var v := []
	v.resize(m + 1)
	v.fill(0.0)
	var p := []
	p.resize(m + 1)
	p.fill(0)
	var chemin := []
	chemin.resize(m + 1)
	chemin.fill(0)
	for i in range(1, n + 1):
		p[0] = i
		var j0 := 0
		var minv := []
		minv.resize(m + 1)
		minv.fill(infini)
		var vu := []
		vu.resize(m + 1)
		vu.fill(false)
		while true:
			vu[j0] = true
			var i0: int = p[j0]
			var delta := infini
			var j1 := 0
			for j in range(1, m + 1):
				if not vu[j]:
					var cur: float = cout[i0 - 1][j - 1] - u[i0] - v[j]
					if cur < minv[j]:
						minv[j] = cur
						chemin[j] = j0
					if minv[j] < delta:
						delta = minv[j]
						j1 = j
			for j in range(m + 1):
				if vu[j]:
					u[p[j]] += delta
					v[j] -= delta
				else:
					minv[j] -= delta
			j0 = j1
			if p[j0] == 0:
				break
		while true:
			var j2: int = chemin[j0]
			p[j0] = p[j2]
			j0 = j2
			if j0 == 0:
				break
	var res := []
	res.resize(n)
	res.fill(0)
	for j in range(1, m + 1):
		if p[j] != 0:
			res[p[j] - 1] = j - 1
	return res


static func _position(salle: Dictionary) -> Vector2i:
	var p = salle.get("position", Vector2i.ZERO)
	return p if p is Vector2i else Vector2i(int(p[0]), int(p[1]))


## Images « crypte » utilisables (hors blocs), triées.
static func images_cryptes() -> Array:
	var liste := images().keys().filter(func(i): return est_crypte(String(i)) and not BlocsSalles.image_de_bloc(String(i)))
	liste.sort()
	return liste


## Vrai si l'image est une crypte.
static func est_crypte(image: String) -> bool:
	return image.begins_with(PREFIXE_CRYPTE)


## Vrai si l'image est une prison (cellules, barreaux).
static func est_prison(image: String) -> bool:
	return image.begins_with(PREFIXE_PRISON)


## Vrai si l'image est un couloir de prison (menant aux cryptes).
static func est_couloir_prison(image: String) -> bool:
	return image.begins_with(PREFIXE_COULOIR_PRISON)


## Meilleure apparence pour une salle seule (sans tenir compte des autres salles).
static func _attribuer_salle(salles: Dictionary, id: String, etage: int) -> Dictionary:
	var meilleur := {}
	var meilleur_score := -1000000
	var noms: Array = images().keys()
	noms.sort()
	for image in noms:
		if reservee(image):
			continue
		for miroir in [false, true]:
			var e := _evaluer(salles, id, etage, image, miroir)
			if e[0] > meilleur_score:
				meilleur_score = e[0]
				meilleur = e[1]
	return meilleur


## [score, info « salle_peinte »] d'une apparence (image, miroir) pour une salle (critères de l'en-tête).
static func _evaluer(salles: Dictionary, id: String, etage: int, image: String, miroir: bool) -> Array:
	var salle: Dictionary = salles[id]
	var voisines := voisines_carte(salles, id)
	var passage = salle.get("passage_niveau", null)
	if passage is Dictionary:
		var dp = passage.get("direction", [0, 1])
		voisines[Vector2i(int(dp[0]), int(dp[1]))] = PASSAGE
	var variation := absi(hash([etage, id, image, miroir])) % 10
	var score := variation
	var types := types_sorties(image)
	if grande_salle(image):
		score += BONUS_CARREFOUR if voisines.size() >= 3 else -PENALITE_GRANDE_HORS_CARREFOUR
	var dirs := directions(image, miroir)
	var sorties := []
	sorties.resize(dirs.size())
	# Sorties de chaque direction de la carte : [ordinaires, potentielles]
	var par_direction := {}
	for k in dirs.size():
		var a := absolue(dirs[k], FACE)
		if not par_direction.has(a):
			par_direction[a] = [[], []]
		par_direction[a][1 if est_potentielle(image, k) else 0].append(k)
	var utilisees := {}
	for a in par_direction:
		var ordinaires: Array = par_direction[a][0]
		var potentielles: Array = par_direction[a][1]
		if voisines.has(a):
			utilisees[a] = true
			# Deux portes du même côté (salle porte 2 : deux portes à gauche) mènent à la même voisine ; parmi des
			# sorties potentielles, une seule (tirage stable)
			if not ordinaires.is_empty():
				for k in ordinaires:
					sorties[k] = voisines[a]
			else:
				sorties[potentielles[absi(hash([etage, id, image, miroir, a])) % potentielles.size()]] = voisines[a]
		else:
			for k in ordinaires:
				if dirs[k] != "bas" and not (k < types.size() and types[k] == "bord"):
					score -= PENALITE_PORTE_CONDAMNEE
	var sans_porte := []
	for a in voisines:
		if not utilisees.has(a):
			sans_porte.append(voisines[a])
	score -= PENALITE_SANS_PORTE * sans_porte.size()
	if not salle.has("bloc"):
		for v in sans_porte:
			if v is String and v != PASSAGE and salles.has(v) and salles[v].has("bloc"):
				score -= PENALITE_SANS_PORTE_BLOC
	sans_porte.erase(PASSAGE)
	var index_passage := -1
	for k in sorties.size():
		if sorties[k] is String and sorties[k] == PASSAGE:
			if index_passage < 0:
				index_passage = k
			sorties[k] = null
	if (salle.get("depart", false) and image == IMAGE_DEPART) or (salle.get("boss", false) and image == IMAGE_BOSS):
		score += BONUS_IMAGE_PREFEREE
	var info := {"v": VERSION, "image": image, "miroir": miroir, "face": [FACE.x, FACE.y],
		"sorties": sorties, "sans_porte": sans_porte}
	if passage is Dictionary:
		info["passage"] = index_passage
	return [score, info]


## Salles voisines d'une salle du plan : {direction de la carte : id}.
static func voisines_carte(salles: Dictionary, id: String) -> Dictionary:
	var ici := _position(salles[id])
	var voisines := {}
	for conn in salles[id].get("connections", []):
		if salles.has(str(conn)):
			voisines[_position(salles[str(conn)]) - ici] = str(conn)
	return voisines


## Directions de la carte où mène une image (sans doublon), avec et sans chaque sortie qui peut être fermée
## sans se voir : le bas de l'image, les passages de bord des grandes salles et les sorties potentielles. Ex. salle porte 5 :
## [[haut, gauche, bas], [haut, gauche]].
static func formes_couvertes(image: String, miroir: bool) -> Array:
	var obligatoires := []
	var facultatives := []
	var types := types_sorties(image)
	var dirs := directions(image, miroir)
	for k in dirs.size():
		var a := absolue(dirs[k], FACE)
		if dirs[k] == "bas" or (k < types.size() and types[k] == "bord") or est_potentielle(image, k):
			if not a in facultatives:
				facultatives.append(a)
		elif not a in obligatoires:
			obligatoires.append(a)
	for a in obligatoires:
		facultatives.erase(a)
	var resultat := []
	for masque in 1 << facultatives.size():
		var forme := obligatoires.duplicate()
		for k in facultatives.size():
			if masque & (1 << k):
				forme.append(facultatives[k])
		if not forme.is_empty():
			resultat.append(forme)
	return resultat


## Index de la sortie de ``salle`` qui mène à la salle ``vers`` (-1 si aucune porte : passage par flèche).
## Plusieurs sorties peuvent mener à la même salle (deux ouvertures du même côté) : on prend celle par
## laquelle le héros était sorti vers elle (« sortie_prise », retenue par l'écran d'exploration), sinon
## une vraie porte plutôt qu'un passage (« types_sorties » du .json de la salle : salle porte 6, porte de
## gauche plutôt que passage de gauche), sinon la première.
static func sortie_vers(salle: Dictionary, vers: String) -> int:
	var info: Dictionary = salle.get("salle_peinte", {})
	if "/" in vers:  # salle d'un autre niveau (« niveau/salle », Aventure.autre_niveau) : la sortie du passage
		return int(info.get("passage", -1)) if salle.has("passage_niveau") else -1
	var sorties: Array = info.get("sorties", [])
	var candidates := []
	for i in sorties.size():
		if sorties[i] != null and str(sorties[i]) == vers:
			candidates.append(i)
	if candidates.is_empty():
		return -1
	var prise = info.get("sortie_prise", {}).get(vers, -1)
	if int(prise) in candidates:
		return int(prise)
	var types: Array = types_sorties(String(info.get("image", "")))
	for i in candidates:
		if i < types.size() and types[i] == "porte":
			return i
	return candidates[0]


static var _types := {}
static var _grandes := {}
static var _potentielles := {}


## Sorties potentielles d'une image (un booléen par sortie, « sorties_potentielles » du .json ; voir l'en-tête).
static func sorties_potentielles(image: String) -> Array:
	if not _potentielles.has(image):
		_potentielles[image] = SallePeinte.lire_salle(image).get("sorties_potentielles", [])
	return _potentielles[image]


## Vrai si la sortie ``k`` de l'image est potentielle.
static func est_potentielle(image: String, k: int) -> bool:
	var liste := sorties_potentielles(image)
	return k < liste.size() and bool(liste[k])


## Vrai si la sortie ``k`` d'une image peut rester fermée sans se voir (mur invisible) : bas de l'image, passage de
## bord d'une grande salle, sortie potentielle.
static func fermee_sans_se_voir(image: String, k: int, direction: String) -> bool:
	var types := types_sorties(image)
	return direction == "bas" or (k < types.size() and types[k] == "bord") or est_potentielle(image, k)


## Vrai si l'image est une grande salle (carrefour).
static func grande_salle(image: String) -> bool:
	if not _grandes.has(image):
		_grandes[image] = bool(SallePeinte.lire_salle(image).get("grande_salle", false))
	return _grandes[image]


## Type de chaque sortie d'une image (« porte », « passage » ou « bord » : passage sur le bord du sol d'une
## grande salle), d'après son .json.
static func types_sorties(image: String) -> Array:
	if not _types.has(image):
		_types[image] = SallePeinte.lire_salle(image).get("types_sorties", [])
	return _types[image]


## Direction de la carte de chaque sortie de la salle peinte attribuée (pour les contrôles).
static func directions_carte(info: Dictionary) -> Array:
	var face := Vector2i(int(info["face"][0]), int(info["face"][1]))
	var liste := []
	for rel in directions(String(info["image"]), bool(info.get("miroir", false))):
		liste.append(absolue(rel, face))
	return liste
