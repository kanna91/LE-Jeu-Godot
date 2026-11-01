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
## tombent exactement sur les salles voisines. Critères, dans l'ordre :
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
const PENALITE_PORTE_CONDAMNEE := 30
const BONUS_IMAGE_PREFEREE := 15
## Grandes salles (``"grande_salle"`` du .json, images de l'utilisateur) réservées aux **carrefours** (décision de
## l'utilisateur, 2026-10-27) : bonus dans une salle à 3 ou 4 passages, malus ailleurs. Leurs passages de bord
## (type « bord ») sans salle derrière deviennent un mur invisible, sans malus, comme le bas de l'image.
const BONUS_CARREFOUR := 20
const PENALITE_GRANDE_HORS_CARREFOUR := 40
## Quartier des prisons (2026-10-30, décision de l'utilisateur) : les images « prison » vont dans la part de l'étage
## la plus loin du boss (PART_QUARTIER_PRISONS des salles, par le chemin) ; le cachot est pris parmi elles
## (Aventure.preparer_etage). Bonus inférieur à PENALITE_PORTE_CONDAMNEE : une prison ne condamne pas de porte en plus.
const PART_QUARTIER_PRISONS := 0.25
const PREFIXE_PRISON := "prison"
const BONUS_QUARTIER_PRISONS := 25
const PENALITE_PRISON_HORS_QUARTIER := 60
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
## Chaque apparence (image × miroir, 98 pour 49 images) ne sert qu'**une fois par étage** (2026-10-30, demande de
## l'utilisateur) : affectation globale au meilleur total des scores (_affectation, méthode hongroise) plutôt que
## salle par salle. Les apparences déjà prises par des salles gardées sont exclues. S'il y a plus de salles que
## d'apparences libres (jamais vu : ≈ 56 salles par étage), on revient au choix salle par salle.
static func attribuer(donjon, etage: int) -> void:
	var salles: Dictionary = donjon.plan_donjon.get(etage, {})
	if salles.is_empty() or images().is_empty():
		return
	var a_faire := []
	var prises := {}
	for id in salles:
		var info: Dictionary = salles[id].get("salle_peinte", {})
		if int(info.get("v", 0)) == VERSION and images().has(String(info.get("image", ""))):
			prises["%s|%s" % [info["image"], bool(info.get("miroir", false))]] = true
			continue
		a_faire.append(String(id))
	if a_faire.is_empty():
		return
	var quartier := quartier_prisons(salles)
	var libres := []
	var noms: Array = images().keys()
	noms.sort()
	for image in noms:
		if BlocsSalles.image_de_bloc(image):
			continue  # images des blocs : seulement dans leur bloc
		for miroir in [false, true]:
			if not prises.has("%s|%s" % [image, miroir]):
				libres.append([image, miroir])
	if a_faire.size() > libres.size():
		for id in a_faire:
			salles[id]["salle_peinte"] = _attribuer_salle(salles, id, etage, quartier)
		return
	var couts := []
	var infos := []
	for id in a_faire:
		var ligne := []
		var ligne_infos := []
		for l in libres:
			var e := _evaluer(salles, id, etage, l[0], l[1], quartier.has(id))
			ligne.append(-float(e[0]))
			ligne_infos.append(e[1])
		couts.append(ligne)
		infos.append(ligne_infos)
	var choix := _affectation(couts, a_faire.size(), libres.size())
	for k in a_faire.size():
		salles[a_faire[k]]["salle_peinte"] = infos[k][choix[k]]


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


## Salles du quartier des prisons : {id: true}, les PART_QUARTIER_PRISONS de l'étage les plus loin du boss par le
## chemin (sans la salle de départ, qui garde son image).
static func quartier_prisons(salles: Dictionary) -> Dictionary:
	var boss := ""
	for id in salles:
		if salles[id].get("boss", false):
			boss = String(id)
	if boss == "":
		return {}
	var dist := Aventure.distances_depuis(salles, boss)
	var ids := []
	for id in salles:
		if not salles[id].get("depart", false):
			ids.append(String(id))
	ids.sort_custom(func(a, b): return dist.get(a, 0) > dist.get(b, 0))
	var quartier := {}
	for k in ceili(salles.size() * PART_QUARTIER_PRISONS):
		if k < ids.size():
			quartier[ids[k]] = true
	return quartier


## Vrai si l'image est une prison (cellules, barreaux).
static func est_prison(image: String) -> bool:
	return image.begins_with(PREFIXE_PRISON)


## Meilleure apparence pour une salle seule (sans tenir compte des autres salles).
static func _attribuer_salle(salles: Dictionary, id: String, etage: int, quartier := {}) -> Dictionary:
	var meilleur := {}
	var meilleur_score := -1000000
	var noms: Array = images().keys()
	noms.sort()
	for image in noms:
		if BlocsSalles.image_de_bloc(image):
			continue
		for miroir in [false, true]:
			var e := _evaluer(salles, id, etage, image, miroir, quartier.has(id))
			if e[0] > meilleur_score:
				meilleur_score = e[0]
				meilleur = e[1]
	return meilleur


## [score, info « salle_peinte »] d'une apparence (image, miroir) pour une salle (critères de l'en-tête).
static func _evaluer(salles: Dictionary, id: String, etage: int, image: String, miroir: bool, dans_quartier := false) -> Array:
	var salle: Dictionary = salles[id]
	var voisines := voisines_carte(salles, id)
	var variation := absi(hash([etage, id, image, miroir])) % 10
	var sorties := []
	var utilisees := {}
	var score := variation
	var types := types_sorties(image)
	if grande_salle(image):
		score += BONUS_CARREFOUR if voisines.size() >= 3 else -PENALITE_GRANDE_HORS_CARREFOUR
	if est_prison(image):
		score += BONUS_QUARTIER_PRISONS if dans_quartier else -PENALITE_PRISON_HORS_QUARTIER
	var k := -1
	for rel in directions(image, miroir):
		k += 1
		var a := absolue(rel, FACE)
		# Deux portes du même côté (salle porte 2 : deux portes à gauche) mènent à la même voisine
		if voisines.has(a):
			sorties.append(voisines[a])
			utilisees[a] = true
		else:
			sorties.append(null)
			if rel != "bas" and not (k < types.size() and types[k] == "bord"):
				score -= PENALITE_PORTE_CONDAMNEE
	var sans_porte := []
	for a in voisines:
		if not utilisees.has(a):
			sans_porte.append(voisines[a])
	score -= PENALITE_SANS_PORTE * sans_porte.size()
	if (salle.get("depart", false) and image == IMAGE_DEPART) or (salle.get("boss", false) and image == IMAGE_BOSS):
		score += BONUS_IMAGE_PREFEREE
	return [score, {"v": VERSION, "image": image, "miroir": miroir, "face": [FACE.x, FACE.y],
		"sorties": sorties, "sans_porte": sans_porte}]


## Salles voisines d'une salle du plan : {direction de la carte : id}.
static func voisines_carte(salles: Dictionary, id: String) -> Dictionary:
	var ici := _position(salles[id])
	var voisines := {}
	for conn in salles[id].get("connections", []):
		if salles.has(str(conn)):
			voisines[_position(salles[str(conn)]) - ici] = str(conn)
	return voisines


## Directions de la carte où mène une image (sans doublon), avec et sans chaque sortie qui peut être fermée
## sans se voir : le bas de l'image, et les passages de bord des grandes salles. Ex. salle porte 5 :
## [[haut, gauche, bas], [haut, gauche]].
static func formes_couvertes(image: String, miroir: bool) -> Array:
	var obligatoires := []
	var facultatives := []
	var types := types_sorties(image)
	var dirs := directions(image, miroir)
	for k in dirs.size():
		var a := absolue(dirs[k], FACE)
		if dirs[k] == "bas" or (k < types.size() and types[k] == "bord"):
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
