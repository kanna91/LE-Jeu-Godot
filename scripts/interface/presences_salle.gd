class_name PresencesSalle
extends Node
## Présences d'une salle peinte (Aventure) : ennemis qui rôdent, boss, personnages et choses à utiliser, dessinés
## en formes géométriques simples en attendant leurs animations (le diablotin est animé, les gobelins et les autres créatures ont leurs images), à la manière de Fear & Hunger.
##
## Les rôdeurs patrouillent dans la salle. S'ils voient le héros (cône de vue devant eux, coupé par les piliers et
## obstacles : ``SallePeinte.vue_bouchee``) ou l'entendent (il court, ou marche tout près), ils s'arrêtent un instant
## (« ! ») puis le poursuivent. Immobile dans l'ombre (les zones les plus sombres du sol de l'image,
## ``SallePeinte.dans_ombre``) ou derrière le premier plan, le héros est caché (``heros_cache``) ; s'il marche dans
## l'ombre, on le voit de moitié moins loin. Perdu de vue, un rôdeur cherche là où il l'a vu (« ? ») puis reprend
## sa ronde. Au contact, ``contact(presence)`` est émis : l'écran d'exploration lance le
## combat (ou la capture, pour un geôlier). Les gobelins pacifiques s'écartent du héros au lieu de le poursuivre.
## Les présences immobiles (personnages, pupitre, râtelier, cachette, coffre) proposent une action à portée (E).
##
## Distances en hauteurs du héros à la même profondeur (comme la marche du héros), vitesses en fraction de la
## vitesse de course de la salle. **Valeurs choisies par Claude, à valider.**

signal contact(presence: Dictionary)
## Un chasseur (chevalier, geôlier) a atteint la sortie par laquelle il quitte la salle pour la salle ``vers``.
## Courir n'alerte plus le reste de l'étage depuis le 2026-10-27 (décision de l'utilisateur) : seulement les ennemis
## de la salle, qui l'entendent de plus loin (OUIE_COURSE).
signal parti(presence: Dictionary, vers: String)

## Vitesse de ronde et de poursuite (× la vitesse de course du héros ; il marche à 0,45). Le Chevalier de la mort
## (« imbattable ») est plus lent que le héros qui marche (0,36, demande de l'utilisateur : « lentement »).
const VITESSE_RONDE := 0.22
## Depuis le 2026-10-27, le chevalier et le geôlier avancent dans les salles au rythme de leur marche animée
## (``vitesse_marche``) : leurs valeurs ici ne servent plus qu'au temps de traversée d'une salle hors de la vue du héros
## (Aventure.duree_salle, chevalier ≈ 9 s ; geôlier fixé à 6 s).
## Poursuite des gobelins qui ont une marche animée, en hauteurs de héros par seconde (le héros marche à 0,81, court
## à 1,8) : 0,85, décision de l'utilisateur (2026-10-28 : « trop facile » quand ils poursuivaient au pas, ≈ 0,15). Leur
## marche défile alors environ 5 fois plus vite (l'image suit la distance : pas de glissade). Ronde : au pas.
const COURSE_GOBELINS := 0.85
const VITESSE_POURSUITE := {"groupe": 0.58, "porteur": 0.5, "imbattable": 0.36, "geolier": 0.64, "boss": 0.48}
## Portée de la vue (devant, cône de ANGLE_VUE degrés au total), de l'ouïe (le héros court / marche / est caché).
const VUE := {"groupe": 2.4, "porteur": 2.4, "imbattable": 3.0, "geolier": 2.8, "boss": 1.6}
const ANGLE_VUE := 120.0
const OUIE_COURSE := 1.8
const OUIE_MARCHE := 0.7
const OUIE_CACHE := 0.45
## Durée de l'arrêt « ! » avant la poursuite ; temps sans voir le héros avant de le chercher ; durée de la recherche.
const DUREE_ALERTE := 0.6
const PERTE := {"groupe": 2.5, "porteur": 2.5, "imbattable": 5.0, "geolier": 3.5, "boss": 2.0}
const DUREE_RECHERCHE := 4.0
## Distance de contact (combat ou capture).
const CONTACT := 0.32
## Cachettes (2026-11-01, règle de l'utilisateur) : un ennemi qui poursuit le héros et qui est à moins de
## PROCHE_CACHETTE (hauteurs du héros) quand celui-ci entre dans une cachette l'a vu y entrer : il peut l'y suivre.
## Les autres ne le voient ni ne l'entendent plus, n'entrent pas dans la cachette et perdent sa trace.
## **Valeur choisie par Claude, à valider.**
const PROCHE_CACHETTE := 0.6
## Portée des actions sur une présence immobile (E).
const PORTEE_ACTION := 0.6
## Les rôdeurs apparaissent au moins à cette distance du héros.
const DISTANCE_APPARITION := 2.2
## Délai avant qu'un poursuivant qui a suivi le héros d'une salle à l'autre n'entre à son tour.
const DELAI_SUITE := 2.5
## Animations du diablotin faites par Grok (``outils/importer_animations_diablotin.py`` → ``images/pnj/diablotin_anim``) :
## « respiration » en boucle, « rire » joué une fois quand le héros s'approche, puis de temps en temps (choix de Claude).
const ANIMS_DIABLOTIN := {"respiration": 48, "rire": 73}
const FPS_DIABLOTIN := 12.0
## Distance (en hauteurs de héros) à laquelle le diablotin se met à rire, et attente entre deux rires (s).
const RIRE_DISTANCE := 1.5
const RIRE_ATTENTE := Vector2(8.0, 16.0)
static var _images_diablotin := {}
## Commis (2026-11-04) : animation de repos de l'utilisateur (``outils/importer_commis.py`` →
## ``images/pnj/commis_<role>_anim/repos_000.png``...), hauteur en hauteurs du héros (un jeune homme, un peu plus petit).
const TAILLE_COMMIS := 0.95
const FPS_COMMIS := 24.0
static var _images_commis := {}


static func images_commis(role: String) -> Array:
	if not _images_commis.has(role):
		var liste := []
		var dossier := "res://images/pnj/commis_%s_anim" % role
		var info = JSON.parse_string(FileAccess.get_file_as_string(dossier + "/animations.json"))
		if info is Dictionary:
			for k in int(info.get("images", 0)):
				liste.append(load("%s/repos_%03d.png" % [dossier, k]))
		_images_commis[role] = liste
	return _images_commis[role]


## Images de la succube (détourées par ``outils/importer_succube.py``), une variante par succube.
const IMAGES_SUCCUBE := [preload("res://images/pnj/succube_1.png"), preload("res://images/pnj/succube_2.png"),
	preload("res://images/pnj/succube_3.png")]
## Gobelins dessinés comme en combat : animation de repos (``images/combat_anime/gobelins``) des sortes animées,
## image fixe sinon (lancier, défenseur). Quand ils se déplacent : leur marche animée s'ils en ont une
## (``marche_gobelin``, 2026-10-28), et ils avancent alors au rythme de cette marche (``vitesse_gobelins``). Chaque gobelin est celui qu'on affrontera (``Aventure.membres``).
## Sortes pour le gobelin blessé (pas de combat) : tirée de son id.
const SORTES_GOBELINS := ["guerrier", "archer", "sorcier", "chaman", "feticheur"]
## Hauteur d'un gobelin dans la salle, en hauteurs du héros (0,55 avant le 2026-10-27, jugé trop petit) ; élite et
## porteur × MINI_BOSS.taille (1,35), boss × BOSS.taille (1,7), comme en combat.
const TAILLE_GOBELIN := 0.8
## Teinte des gobelins pacifiques (plus pâles).
const TEINTE_PACIFIQUE := Color(0.8, 1.0, 0.8, 0.9)
## Haut de la tête de chaque sorte de gobelin, en fraction de sa hauteur de corps (calculé une fois).
static var _haut_tete := {}
## Partie non transparente des images fixes de gobelins (pieds = bas de ce cadre).
static var _cadres := {}

var salle: SallePeinte
## Entités affichées : {p (présence), noeud, pos, etat, cible, regard, t, vu_pos, pause, retard, hors_champ}.
var entites: Array = []
## Rôdeurs figés (et sourds) jusqu'à cet instant : arrivée dans la salle, retour d'une fuite.
var gel_jusqu_a := 0.0
var temps := 0.0
## Point où apparaissent les poursuivants venus de la salle précédente (là où le héros est arrivé).
var point_arrivee := Vector2.ZERO
var _contact_emis := false


func _init(s: SallePeinte) -> void:
	salle = s


## Place les présences de la salle (``liste`` : dictionnaires d'Aventure). Les présences immobiles gardent leur
## place pour cette image (« pos », « pos_image ») ; les rôdeurs apparaissent loin du héros, ou arrivent en
## retard par la même porte que lui (« suit » : ils le poursuivaient dans la salle précédente).
func placer(liste: Array) -> void:
	for e in entites:
		if is_instance_valid(e["noeud"]):
			e["noeud"].queue_free()
	entites = []
	_contact_emis = false
	point_arrivee = salle.heros.position
	gel_jusqu_a = temps + 1.0
	var cle_image := "%s%s" % [salle.ident, "_m" if salle.miroir else ""]
	for p in liste:
		var e := {"p": p, "etat": "ronde", "t": 0.0, "pause": randf_range(0.0, 1.5), "retard": 0.0, "regard": Vector2(0, 1),
			"vu_pos": Vector2.ZERO, "hors_champ": false}
		if Aventure.est_rodeur(p) or p["genre"] == "boss":
			if p.get("suit", false):
				p.erase("suit")
				e["retard"] = float(p.get("retard_suite", DELAI_SUITE))
				p.erase("retard_suite")
				e["hors_champ"] = true
				e["pos"] = point_arrivee
				e["etat"] = "poursuite"
			else:
				e["pos"] = _point_libre(DISTANCE_APPARITION, p["genre"] == "boss")
		else:
			if p.get("pos_image", "") != cle_image:
				var q := _point_libre(1.2, false, true)
				p["pos"] = [q.x, q.y]
				p["pos_image"] = cle_image
			e["pos"] = Vector2(p["pos"][0], p["pos"][1])
			e["etat"] = "immobile"
		e["cible"] = e["pos"]
		var noeud := Node2D.new()
		noeud.position = e["pos"]
		noeud.visible = not e["hors_champ"]
		noeud.draw.connect(_dessiner.bind(noeud, e))
		salle.tri.add_child(noeud)
		e["noeud"] = noeud
		entites.append(e)


## Un chasseur entre dans la salle ``retard`` secondes plus tard, au point ``entree`` (devant la porte de la salle
## d'où il vient). ``cherche`` : il venait chercher le héros (combat, bruit) et sait où il est ; sinon il fait sa
## ronde (il erre au hasard dans l'étage).
func faire_venir(p: Dictionary, retard: float, entree := Vector2.INF, cherche := true) -> void:
	for e in entites:
		if e["p"] == p:
			return
	var point := point_arrivee if entree == Vector2.INF else entree
	var e := {"p": p, "etat": "poursuite" if cherche else "ronde", "t": 0.0, "pause": 0.5, "retard": retard,
		"regard": Vector2(0, 1), "vu_pos": salle.heros.position, "hors_champ": true, "pos": point, "cible": point,
		"entree": point}
	var noeud := Node2D.new()
	noeud.position = e["pos"]
	noeud.visible = false
	noeud.draw.connect(_dessiner.bind(noeud, e))
	salle.tri.add_child(noeud)
	e["noeud"] = noeud
	entites.append(e)


## Position (pixels de l'image) de la présence ``p`` affichée, ou null.
func position_de(p: Dictionary):
	for e in entites:
		if e["p"] == p:
			return e["pos"]
	return null


## Affiche une nouvelle présence immobile (corps d'un ennemi vaincu) à sa place, ``p["pos"]`` si elle en a une.
func ajouter_immobile(p: Dictionary) -> void:
	var cle_image := "%s%s" % [salle.ident, "_m" if salle.miroir else ""]
	if p.get("pos_image", "") != cle_image:
		var q := _point_libre(1.2, false, true)
		p["pos"] = [q.x, q.y]
		p["pos_image"] = cle_image
	var e := {"p": p, "etat": "immobile", "t": 0.0, "pause": 0.0, "retard": 0.0, "regard": Vector2(0, 1),
		"vu_pos": Vector2.ZERO, "hors_champ": false, "pos": Vector2(p["pos"][0], p["pos"][1])}
	e["cible"] = e["pos"]
	var noeud := Node2D.new()
	noeud.position = e["pos"]
	noeud.draw.connect(_dessiner.bind(noeud, e))
	salle.tri.add_child(noeud)
	e["noeud"] = noeud
	entites.append(e)


## Retire une présence de l'affichage (vaincue, utilisée...).
func retirer(p: Dictionary) -> void:
	for e in entites.duplicate():
		if e["p"] == p:
			e["noeud"].queue_free()
			entites.erase(e)


## Retire de l'affichage les présences qui ne sont plus actives (pacte scellé, Sans-Visage apaisé...).
func retirer_parties() -> void:
	for e in entites.duplicate():
		if e["p"].get("etat", "actif") != "actif" and e["p"]["genre"] != "objet":
			retirer(e["p"])


## Les rôdeurs se figent ``duree`` secondes (après une fuite, une conversation).
func geler(duree: float) -> void:
	gel_jusqu_a = temps + duree
	_contact_emis = false
	for e in entites:
		if e["etat"] in ["poursuite", "alerte"]:
			e["etat"] = "recherche"
			e["t"] = 0.0


## Un grand bruit : tous les ennemis de la salle accourent vers le héros.
func alerter() -> void:
	for e in entites:
		if Aventure.est_rodeur(e["p"]) and not e["p"].get("pacifique", false) and not e["hors_champ"]:
			e["etat"] = "poursuite"
			e["t"] = 0.0
			e["vu_pos"] = salle.heros.position


## Éloigne un rôdeur du héros (le héros vient de lui échapper).
func eloigner(p: Dictionary) -> void:
	for e in entites:
		if e["p"] == p:
			e["pos"] = _point_libre(DISTANCE_APPARITION)
			e["cible"] = e["pos"]
			e["etat"] = "ronde"
			e["pause"] = 1.5
			e["noeud"].position = e["pos"]


## Chasseurs (chevalier, geôliers) de la salle qui font leur ronde : ils peuvent repartir vers une autre salle.
func chasseurs_en_ronde() -> Array:
	var liste := []
	for e in entites:
		if e["p"].get("genre") in Aventure.CHASSEURS and e["etat"] == "ronde" and not e["hors_champ"]:
			liste.append(e["p"])
	return liste


## Le chasseur ``p`` quitte la salle : il marche jusqu'au point ``sortie`` puis disparaît (signal ``parti``).
func quitter(p: Dictionary, sortie: Vector2, vers: String) -> void:
	for e in entites:
		if e["p"] == p:
			e["etat"] = "depart"
			e["cible"] = sortie
			e["vers"] = vers
			e["t"] = 0.0


## Rôdeurs qui poursuivent le héros (pour le suivre dans la salle suivante). Un Chevalier de la mort qui le traque
## encore (« traque » > 0) le suit même s'il n'est pas encore entré dans la salle.
func poursuivants() -> Array:
	var liste := []
	for e in entites:
		var traque := int(e["p"].get("traque", 0)) > 0
		if (e["etat"] in ["poursuite", "alerte"] and not e["hors_champ"] or traque) and Aventure.est_rodeur(e["p"]):
			liste.append(e["p"])
	return liste


## Vrai si un ennemi poursuit le héros.
func repere() -> bool:
	for e in entites:
		if e["etat"] in ["poursuite", "alerte"] and not e["hors_champ"] and not e["p"].get("pacifique", false):
			return true
	return false


## Présence immobile à portée d'action du héros (vide : aucune).
func proche() -> Dictionary:
	var meilleure := {}
	var distance := INF
	for e in entites:
		if e["etat"] != "immobile":
			continue
		if e["p"].has("zone"):
			# Prisonnier peint dans l'image : on lui parle quand le héros est dans sa zone de dialogue
			var poly := PackedVector2Array()
			for q in e["p"]["zone"]:
				poly.append(Vector2(q[0], q[1]))
			if Geometry2D.is_point_in_polygon(salle.heros.position, poly):
				return e["p"]
			continue
		var d := _distance(e["pos"], salle.heros.position)
		if d < PORTEE_ACTION and d < distance:
			meilleure = e["p"]
			distance = d
	return meilleure


## Haut d'une présence à l'écran (pour l'étiquette d'action).
func haut_ecran(p: Dictionary) -> Vector2:
	for e in entites:
		if e["p"] == p:
			return salle.vers_ecran(e["pos"] - Vector2(0, salle.hauteur(e["pos"].y) * _hauteur_forme(p)))
	return Vector2.ZERO


# ---------------------------------------------------------------------------
# Géométrie
# ---------------------------------------------------------------------------

## Distance en hauteurs du héros (la profondeur compte moins, comme la marche : compression_profondeur).
func _distance(a: Vector2, b: Vector2) -> float:
	var c := float(salle.donnees["perspective"]["compression_profondeur"])
	var d := b - a
	d.y /= c
	return d.length() / maxf(1.0, salle.hauteur((a.y + b.y) / 2.0))


## Point libre du sol, à au moins ``eloigne`` hauteurs du héros ; ``au_fond`` : dans la moitié haute du sol (boss) ;
## ``pres_mur`` : plutôt au bord du sol (personnages, objets).
func _point_libre(eloigne: float, au_fond := false, pres_mur := false) -> Vector2:
	var boite := Rect2()
	var premier := true
	for poly in salle.donnees["marche"]:
		for q in poly:
			if premier:
				boite = Rect2(q, Vector2.ZERO)
				premier = false
			else:
				boite = boite.expand(q)
	var meilleur := Vector2(salle.donnees["depart"][0], salle.donnees["depart"][1])
	var score_max := -INF
	for _essai in 160:
		var q := Vector2(randf_range(boite.position.x, boite.end.x), randf_range(boite.position.y, boite.end.y))
		if au_fond:
			q.y = randf_range(boite.position.y, boite.position.y + boite.size.y * 0.4)
		if not salle.libre(q) or salle._sortie_sous(q) >= 0 or _pres_sortie(q):
			continue
		var d := _distance(q, salle.heros.position)
		var score := minf(d, eloigne * 1.5)
		if pres_mur:
			# Près d'un bord : un des quatre voisins proches n'est pas libre
			var h := salle.hauteur(q.y) * 0.35
			var bord := 0
			for v in [Vector2(h, 0), Vector2(-h, 0), Vector2(0, -h * 0.5), Vector2(0, h * 0.5)]:
				if not salle.libre(q + v):
					bord += 1
			score += bord * 0.5
		if d >= eloigne and randf() < 0.5:
			score += 1.0
		if score > score_max:
			score_max = score
			meilleur = q
	return meilleur


## Trop près d'une sortie (on ne bloque pas les passages).
func _pres_sortie(q: Vector2) -> bool:
	for i in salle.donnees["sorties"].size():
		if _distance(q, salle.centre_sortie(i)) < 0.9:
			return true
	return false


## Un pas de ``e`` vers ``but`` à la vitesse ``v`` (glisse le long des obstacles) ; faux s'il est bloqué.
func _avancer(e: Dictionary, but: Vector2, vitesse: float, delta: float, course := false) -> bool:
	var p: Vector2 = e["pos"]
	var dir := (but - p)
	if dir.length() < 1.0:
		return true
	dir = dir.normalized()
	e["regard"] = dir
	var persp: Dictionary = salle.donnees["perspective"]
	var pas := float(persp["vitesse"]) * vitesse * salle.hauteur(p.y) * delta
	var marcheur: String = MARCHES.get(e["p"]["genre"], "")
	if marcheur != "":
		# Chevalier, geôlier : toujours au rythme de leur marche animée (pieds qui ne glissent pas ; décision de
		# l'utilisateur, 2026-10-27), en ronde comme en poursuite
		pas = vitesse_marche(marcheur, e["p"]) * salle.hauteur(p.y) * delta
		# Chevalier de la mort : +5 % par point de karma négatif (Karma.facteur_vitesse_chevalier, 2026-11-03)
		pas *= float(e["p"].get("facteur_vitesse", 1.0))
	elif e["p"]["genre"] in ["groupe", "porteur", "boss"]:
		# Gobelins qui ont une marche animée : eux aussi au rythme de l'animation (décision de l'utilisateur,
		# 2026-10-28), en ronde comme en poursuite ; groupes sans marche (squelettes, loups seuls) : vitesse d'avant
		if not e.has("v_marche"):
			e["v_marche"] = vitesse_gobelins(e["p"])
		if float(e["v_marche"]) > 0.0:
			# Poursuite (``course``) : COURSE_GOBELINS ; l'animation suit la distance, elle défile donc plus vite
			pas = (COURSE_GOBELINS if course else float(e["v_marche"])) * salle.hauteur(p.y) * delta
	for angle in [0.0, 0.6, -0.6, 1.2, -1.2]:
		var v := dir.rotated(angle) * pas
		v.y *= float(persp["compression_profondeur"])
		for essai in [v, Vector2(v.x, 0), Vector2(0, v.y)]:
			if essai != Vector2.ZERO and salle.libre(p + essai) and salle._sortie_sous(p + essai) < 0 \
					and (e.get("vu_entrer", false) or not salle.dans_cachette(p + essai) or salle.dans_cachette(p)):
				e["pos"] = p + essai
				e["t_bouge"] = temps
				# Distance au sol (profondeur décompressée), en hauteurs de la forme : fait défiler la marche animée
				var sol := Vector2(essai.x, essai.y / float(persp["compression_profondeur"])).length()
				e["parcouru"] = float(e.get("parcouru", 0.0)) + sol / (salle.hauteur(p.y) * _hauteur_forme(e["p"]))
				return true
	return false


# ---------------------------------------------------------------------------
# Comportement
# ---------------------------------------------------------------------------

## Le rôdeur ``e`` perçoit-il le héros ?
func _percoit(e: Dictionary) -> bool:
	var genre: String = e["p"]["genre"]
	var h: Vector2 = salle.heros.position
	var d := _distance(e["pos"], h)
	if salle.heros_en_cachette():
		return e.get("vu_entrer", false)  # dans une cachette : seul celui qui l'a vu y entrer sait où il est
	var cache := salle.heros_cache()
	var bouge := salle.en_mouvement
	var court := bouge and (salle.course or salle._course_stick)
	if cache:
		return bouge and d < OUIE_CACHE
	if court and d < OUIE_COURSE:
		return true
	if bouge and d < OUIE_MARCHE:
		return true
	# Vue : coupée par un pilier ou un obstacle ; réduite de moitié quand le héros marche dans l'ombre
	var portee: float = VUE.get(genre, 2.4) * (0.5 if salle.heros_dans_ombre() else 1.0) * (0.5 if salle.pacte_voile else 1.0)
	if d < portee and not salle.vue_bouchee(e["pos"], h):
		if e["etat"] in ["poursuite", "alerte"]:
			return true
		var vers: Vector2 = (h - e["pos"]).normalized()
		return rad_to_deg(absf(e["regard"].angle_to(vers))) <= ANGLE_VUE / 2.0
	return false


func _process(delta: float) -> void:
	temps += delta
	if salle == null or salle.heros == null or not salle.actif:
		return
	var fige := temps < gel_jusqu_a
	_suivre_cachette()
	for e in entites:
		if e["etat"] == "immobile":
			if e["p"].get("sous") == "diablotin":
				_rire_diablotin(e)
			e["noeud"].queue_redraw()
			continue
		if e["hors_champ"]:
			e["retard"] -= delta
			if e["retard"] <= 0.0:
				e["hors_champ"] = false
				e["pos"] = e.get("entree", point_arrivee)
				e["cible"] = e["pos"]
				e["noeud"].visible = true
			continue
		if not fige:
			_comportement(e, delta)
		e["noeud"].position = e["pos"]
		e["noeud"].queue_redraw()
		# Pas de contact tant que le héros n'a pas la main (fondu d'entrée, passage, menu) : sinon le contact était
		# perdu et plus aucun ennemi de la salle ne lançait de combat (bug trouvé par le testeur d'étage, 2026-10-28)
		var a_l_abri: bool = salle.heros_en_cachette() and not e.get("vu_entrer", false)
		if not fige and not _contact_emis and salle.actif and not e["p"].get("pacifique", false) and not a_l_abri \
				and _distance(e["pos"], salle.heros.position) < CONTACT:
			_contact_emis = true
			contact.emit(e["p"])
		elif not fige and not _contact_emis and salle.actif and e["p"].get("pacifique", false) \
				and _distance(e["pos"], salle.heros.position) < CONTACT and salle.en_mouvement:
			_contact_emis = true
			contact.emit(e["p"])
	# Chasseurs arrivés à leur sortie : ils quittent la salle
	for e in entites.duplicate():
		if e.get("sorti", false):
			retirer(e["p"])
			parti.emit(e["p"], String(e["vers"]))


## Le héros entre dans une cachette : les ennemis qui le poursuivaient tout près de lui l'ont vu y entrer
## (``vu_entrer``) ; il en sort : plus personne n'a ce privilège.
var _en_cachette := false


func _suivre_cachette() -> void:
	var dedans := salle.heros_en_cachette()
	if dedans and not _en_cachette:
		for e in entites:
			e["vu_entrer"] = e["etat"] in ["poursuite", "alerte"] and not e["hors_champ"] \
				and _distance(e["pos"], salle.heros.position) < PROCHE_CACHETTE
	elif not dedans and _en_cachette:
		for e in entites:
			e.erase("vu_entrer")
	_en_cachette = dedans


## Images de l'animation ``nom`` du diablotin (chargées une fois).
static func images_diablotin(nom: String) -> Array:
	if not _images_diablotin.has(nom):
		var liste := []
		for k in ANIMS_DIABLOTIN[nom]:
			liste.append(load("res://images/pnj/diablotin_anim/%s_%03d.png" % [nom, k]))
		_images_diablotin[nom] = liste
	return _images_diablotin[nom]


## Le diablotin rit quand le héros arrive près de lui, puis de temps en temps (``e.rire`` : début du rire).
func _rire_diablotin(e: Dictionary) -> void:
	var duree: float = ANIMS_DIABLOTIN["rire"] / FPS_DIABLOTIN
	if not e.has("prochain_rire"):
		e["prochain_rire"] = temps + randf_range(3.0, RIRE_ATTENTE.y)
	if e.get("rire", -INF) + duree > temps:
		return
	var proche := _distance(e["pos"], salle.heros.position) < RIRE_DISTANCE
	if (proche and not e.get("proche", false)) or temps >= e["prochain_rire"]:
		e["rire"] = temps
		e["prochain_rire"] = temps + duree + randf_range(RIRE_ATTENTE.x, RIRE_ATTENTE.y)
	e["proche"] = proche


## Image du diablotin à afficher maintenant : le rire s'il est en cours, sinon la respiration (décalée selon l'id).
func image_diablotin(e: Dictionary) -> Texture2D:
	var t := temps - float(e.get("rire", -INF))
	if t >= 0.0 and t * FPS_DIABLOTIN < ANIMS_DIABLOTIN["rire"]:
		return images_diablotin("rire")[int(t * FPS_DIABLOTIN)]
	var k := int((temps + int(e["p"].get("id", 0)) * 0.7) * FPS_DIABLOTIN) % ANIMS_DIABLOTIN["respiration"]
	return images_diablotin("respiration")[k]


func _comportement(e: Dictionary, delta: float) -> void:
	var p: Dictionary = e["p"]
	var genre: String = p["genre"]
	var voit := _percoit(e)
	e["t"] += delta
	if p.get("pacifique", false):
		# Les pacifiques s'écartent du héros qui s'approche
		if voit:
			var loin: Vector2 = e["pos"] + (e["pos"] - salle.heros.position).normalized() * salle.hauteur(e["pos"].y)
			_avancer(e, loin, VITESSE_RONDE * 1.6, delta)
		else:
			_ronde(e, delta)
		return
	match e["etat"]:
		"depart":
			# Un chasseur qui s'en va : il s'arrête s'il voit le héros ; sinon il sort (porte atteinte ou bloqué)
			if voit:
				e["etat"] = "alerte"
				e["t"] = 0.0
				e["regard"] = (salle.heros.position - e["pos"]).normalized()
			elif e["pos"].distance_to(e["cible"]) < salle.hauteur(e["pos"].y) * 0.15 or e["t"] > 20.0 \
					or not _avancer(e, e["cible"], float(e["p"].get("vitesse_poursuite", VITESSE_POURSUITE.get(genre, 0.5))), delta):
				e["sorti"] = true  # retiré après la boucle de _process
		"ronde":
			if voit:
				e["etat"] = "alerte"
				e["t"] = 0.0
				e["regard"] = (salle.heros.position - e["pos"]).normalized()
			elif genre == "boss":
				pass  # le gardien attend dans sa salle
			else:
				_ronde(e, delta)
		"alerte":
			if e["t"] >= DUREE_ALERTE:
				e["etat"] = "poursuite"
				e["t"] = 0.0
				e["vu_pos"] = salle.heros.position
				if genre == "imbattable":
					p["traque"] = Aventure.TRAQUE_SALLES
		"poursuite":
			# Le chevalier qui traque sait toujours où est le héros... sauf s'il s'est glissé dans une cachette sans être vu
			var traque: bool = int(p.get("traque", 0)) > 0 and (not salle.heros_en_cachette() or e.get("vu_entrer", false))
			if voit or traque:
				e["vu_pos"] = salle.heros.position
				e["t"] = 0.0
			if e["t"] > PERTE.get(genre, 2.5):
				e["etat"] = "recherche"
				e["t"] = 0.0
			else:
				_avancer(e, e["vu_pos"] if not voit else salle.heros.position, float(e["p"].get("vitesse_poursuite", VITESSE_POURSUITE.get(genre, 0.7))), delta, true)
		"recherche":
			if voit:
				e["etat"] = "alerte"
				e["t"] = 0.0
			elif e["t"] > DUREE_RECHERCHE:
				e["etat"] = "ronde"
				e["t"] = 0.0
			else:
				if not _avancer(e, e["vu_pos"], VITESSE_RONDE * 1.3, delta) or e["pos"].distance_to(e["vu_pos"]) < 4.0:
					var h := salle.hauteur(e["pos"].y)
					e["vu_pos"] = e["pos"] + Vector2(randf_range(-h, h), randf_range(-h, h) * 0.4)


## Ronde : va vers un point libre au hasard, s'y arrête un moment, repart.
func _ronde(e: Dictionary, delta: float) -> void:
	if e["pause"] > 0.0:
		e["pause"] -= delta
		return
	if e["pos"].distance_to(e["cible"]) < 3.0 or not _avancer(e, e["cible"], VITESSE_RONDE, delta):
		e["cible"] = _point_libre(0.0)
		e["pause"] = randf_range(0.8, 2.5)


# ---------------------------------------------------------------------------
# Dessin (formes géométriques en attendant les animations)
# ---------------------------------------------------------------------------

## Hauteur de la forme, en hauteurs du héros.
static func _hauteur_forme(p: Dictionary) -> float:
	match p["genre"]:
		"groupe":
			return TAILLE_GOBELIN * (Ennemis.MINI_BOSS["taille"] if p.get("elite", false) else 1.0)
		"porteur":
			return TAILLE_GOBELIN * Ennemis.MINI_BOSS["taille"]
		"imbattable":
			return 1.3
		"geolier":
			return 1.15
		"boss":
			return TAILLE_GOBELIN * Ennemis.BOSS["taille"]
		"pnj":
			return {"succube": 1.3, "diablotin": 0.5, "gobelin_blesse": TAILLE_GOBELIN * 0.4, "prisonnier": 0.65,
				"prisonnier_cellule": 0.9, "autel": 0.45, "commis": TAILLE_COMMIS}.get(p["sous"], 0.6)
	return {"pupitre": 0.55, "ratelier": 0.7, "cachette": 0.2, "coffre_confisque": 0.35, "coffre_gardien": 0.35,
		"cadavre": TAILLE_GOBELIN * 0.4, "objet_quete": 0.18}.get(p.get("sous", ""), 0.5)


func _dessiner(n: Node2D, e: Dictionary) -> void:
	var p: Dictionary = e["p"]
	var h := salle.hauteur(e["pos"].y)
	var hf := h * _hauteur_forme(p)
	var genre: String = p["genre"]
	var sous: String = p.get("sous", "")
	var utilise: bool = p.get("etat") != "actif"
	if p.has("zone"):
		return  # prisonnier peint dans l'image : rien à dessiner
	# Ombre au sol
	if sous != "cachette":
		n.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.25))
		n.draw_circle(Vector2.ZERO, hf * 0.32, Color(0, 0, 0, 0.35))
		n.draw_set_transform(Vector2.ZERO)
	match genre:
		"groupe":
			var membres := Aventure.membres(p)
			var nombre := membres.size()
			var teinte := TEINTE_PACIFIQUE if p.get("pacifique", false) else Color.WHITE
			var ecart := h * TAILLE_GOBELIN * 0.6
			for k in nombre:
				var x := (k - (nombre - 1) / 2.0) * ecart
				var t := hf if (k == 0 and p.get("elite", false)) else h * TAILLE_GOBELIN
				var tete := _gobelin(n, e, membres[k], k, Vector2(x, 0), t, teinte)
				if k == 0 and p.get("elite", false):
					_couronne(n, Vector2(x, -tete), t * 0.18, Color8(230, 180, 60))
		"porteur":
			_gobelin(n, e, Aventure.membres(p)[0], 0, Vector2.ZERO, hf, Color.WHITE)
			n.draw_rect(Rect2(Vector2(hf * 0.1, -hf * 0.7), Vector2(hf * 0.3, hf * 0.34)), Color8(120, 85, 45))
			n.draw_rect(Rect2(Vector2(hf * 0.1, -hf * 0.7), Vector2(hf * 0.3, hf * 0.34)), Color8(60, 40, 20), false, maxf(1.0, hf * 0.02))
		"imbattable", "geolier":
			_marche_animee(n, e, hf, MARCHES[genre])
		"boss":
			var tete := _gobelin(n, e, Aventure.membres(p)[0], 0, Vector2.ZERO, hf, Color.WHITE)
			_couronne(n, Vector2(0, -tete), hf * 0.16, Color8(200, 60, 40))
		"pnj":
			match sous:
				"diablotin":
					# Animation de Grok (respiration, rire), pieds au sol, tourné vers le héros
					var tex := image_diablotin(e)
					var taille := Vector2(hf * tex.get_width() / float(tex.get_height()), hf)
					var sens := -1.0 if salle.heros.position.x < e["pos"].x else 1.0
					n.draw_set_transform(Vector2.ZERO, 0, Vector2(sens, 1))
					n.draw_texture_rect(tex, Rect2(Vector2(-taille.x / 2.0, -taille.y), taille), false)
					n.draw_set_transform(Vector2.ZERO)
				"commis":
					# Animation de repos de l'utilisateur (images/pnj/commis_<role>_anim), en boucle, pieds au sol
					var images := images_commis(String(p.get("role", "cuisine")))
					if not images.is_empty():
						var k := int((temps + int(p.get("id", 0)) * 0.7) * FPS_COMMIS) % images.size()
						var tex: Texture2D = images[k]
						var taille := Vector2(hf * tex.get_width() / float(tex.get_height()), hf)
						n.draw_texture_rect(tex, Rect2(Vector2(-taille.x / 2.0, -taille.y), taille), false)
				"succube":
					# Image détourée (une des trois variantes selon l'id), qui respire doucement
					var tex: Texture2D = IMAGES_SUCCUBE[int(p.get("id", 0)) % IMAGES_SUCCUBE.size()]
					var souffle := 1.0 + 0.012 * sin(temps * 1.8 + int(p.get("id", 0)))
					var taille := Vector2(hf * tex.get_width() / float(tex.get_height()), hf * souffle)
					n.draw_texture_rect(tex, Rect2(Vector2(-taille.x / 2.0, -taille.y), taille), false)
				"gobelin_blesse":
					# Gobelin à terre : dernière image de sa mort, une flaque de sang dessous
					n.draw_set_transform(Vector2(hf * 0.3, -hf * 0.05), 0, Vector2(1, 0.3))
					n.draw_circle(Vector2.ZERO, hf * 0.8, Color(0.45, 0.03, 0.03, 0.8))
					n.draw_set_transform(Vector2.ZERO)
					var sorte: String = SORTES_GOBELINS[int(p.get("id", 0)) * 7 % SORTES_GOBELINS.size()]
					_gobelin(n, e, {"sous_classe": CombatAnime.TYPES.find_key(sorte)}, 0, Vector2.ZERO, h * TAILLE_GOBELIN, Color.WHITE, "mort")
				"prisonnier":
					_capsule(n, Vector2.ZERO, hf * 0.25, hf, Color8(170, 160, 140))
					n.draw_line(Vector2(-hf * 0.2, -hf * 0.4), Vector2(-hf * 0.7, -hf * 0.9), Color8(110, 110, 120), maxf(1.0, hf * 0.04))
				"autel":
					n.draw_rect(Rect2(Vector2(-hf * 0.5, -hf), Vector2(hf, hf)), Color8(95, 90, 88))
					n.draw_set_transform(Vector2(0, -hf), 0, Vector2(1, 0.35))
					n.draw_circle(Vector2.ZERO, hf * 0.35, Color8(120, 10, 10) if not utilise else Color8(60, 40, 40))
					n.draw_set_transform(Vector2.ZERO)
		"objet":
			match sous:
				"pupitre":
					n.draw_rect(Rect2(Vector2(-hf * 0.08, -hf * 0.75), Vector2(hf * 0.16, hf * 0.75)), Color8(90, 60, 35))
					n.draw_colored_polygon(PackedVector2Array([Vector2(-hf * 0.35, -hf * 0.75), Vector2(hf * 0.35, -hf * 0.75),
						Vector2(hf * 0.3, -hf), Vector2(-hf * 0.3, -hf)]), Color8(110, 75, 40))
					if not utilise:
						n.draw_rect(Rect2(Vector2(-hf * 0.25, -hf * 0.98), Vector2(hf * 0.5, hf * 0.12)), Color8(230, 220, 190))
				"ratelier":
					n.draw_rect(Rect2(Vector2(-hf * 0.4, -hf * 0.15), Vector2(hf * 0.8, hf * 0.08)), Color8(100, 70, 40))
					n.draw_rect(Rect2(Vector2(-hf * 0.4, -hf * 0.85), Vector2(hf * 0.8, hf * 0.08)), Color8(100, 70, 40))
					if not utilise:
						for k in 3:
							var x := (k - 1) * hf * 0.22
							n.draw_line(Vector2(x, -hf * 0.05), Vector2(x, -hf), Color8(170, 170, 180), maxf(1.0, hf * 0.04))
				"objet_quete":
					# Objet d'une quête de prisonnier, posé au sol (bol de soupe, ou petit paquet) ; il luit doucement
					var a := 0.25 + 0.2 * sin(temps * 3.0 + int(p.get("id", 0)))
					n.draw_circle(Vector2(0, -hf * 0.4), hf * 0.9, Color(1, 0.9, 0.6, a * 0.4))
					if "soupe" in String(p.get("objet", "")).to_lower():
						n.draw_colored_polygon(PackedVector2Array([Vector2(-hf * 0.7, -hf * 0.55), Vector2(hf * 0.7, -hf * 0.55),
							Vector2(hf * 0.45, 0), Vector2(-hf * 0.45, 0)]), Color8(120, 80, 45))
						n.draw_set_transform(Vector2(0, -hf * 0.55), 0, Vector2(1, 0.3))
						n.draw_circle(Vector2.ZERO, hf * 0.7, Color8(175, 120, 55))
						n.draw_set_transform(Vector2.ZERO)
					else:
						n.draw_rect(Rect2(Vector2(-hf * 0.5, -hf), Vector2(hf, hf)), Color8(140, 110, 70))
				"coffre_confisque":
					n.draw_rect(Rect2(Vector2(-hf * 0.55, -hf), Vector2(hf * 1.1, hf)), Color8(105, 70, 35) if not utilise else Color8(70, 50, 30))
					n.draw_rect(Rect2(Vector2(-hf * 0.55, -hf * 0.62), Vector2(hf * 1.1, hf * 0.12)), Color8(200, 160, 60))
				"coffre_gardien":
					# Coffre ancien, cerclé de fer, avec un sceau rouge tant qu'il n'est pas ouvert
					n.draw_rect(Rect2(Vector2(-hf * 0.55, -hf), Vector2(hf * 1.1, hf)), Color8(70, 72, 80) if not utilise else Color8(45, 45, 50))
					n.draw_rect(Rect2(Vector2(-hf * 0.55, -hf * 0.62), Vector2(hf * 1.1, hf * 0.12)), Color8(150, 155, 165))
					if not utilise:
						n.draw_circle(Vector2(0, -hf * 0.56), hf * 0.1, Color8(170, 25, 25))
				"cadavre":
					# Corps à terre (dernière image de la mort de chaque gobelin), flaque de sang ; une âme pâle flotte
					# au-dessus tant qu'elle n'est pas siphonnée
					if p.get("humain", false):
						# Corps d'un humain (prisonnier) : silhouette couchée dans une flaque de sang
						n.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.3))
						n.draw_circle(Vector2.ZERO, h * 0.35, Color(0.45, 0.03, 0.03, 0.8))
						n.draw_set_transform(Vector2(-h * 0.3, -h * 0.06), PI / 2.0, Vector2.ONE)
						_capsule(n, Vector2.ZERO, h * 0.12, h * 0.6, Color8(120, 112, 98))
						n.draw_set_transform(Vector2.ZERO)
						return
					var liste: Array = p.get("membres", [{}])
					n.draw_set_transform(Vector2(hf * 0.3, -hf * 0.05), 0, Vector2(1, 0.3))
					n.draw_circle(Vector2.ZERO, hf * (0.8 + 0.35 * (liste.size() - 1)), Color(0.45, 0.03, 0.03, 0.8))
					n.draw_set_transform(Vector2.ZERO)
					var ecart := h * TAILLE_GOBELIN * 0.5
					for k in liste.size():
						var x := (k - (liste.size() - 1) / 2.0) * ecart
						_gobelin(n, e, liste[k], k, Vector2(x, 0), h * TAILLE_GOBELIN, Color.WHITE, "mort")
					var a := 0.35 + 0.25 * sin(temps * 2.5 + int(p.get("id", 0)))
					n.draw_circle(Vector2(0, -h * 0.55), h * 0.05, Color(0.75, 0.85, 1.0, a))
				"cachette":
					# Invisible ; une lueur discrète quand le héros passe tout près
					var d := _distance(e["pos"], salle.heros.position)
					if not utilise and d < 1.2:
						var a := (1.2 - d) / 1.2 * (0.5 + 0.5 * sin(temps * 5.0))
						n.draw_circle(Vector2(0, -h * 0.1), h * 0.035, Color(1, 1, 0.85, a))
	# Marques d'état
	if e["etat"] == "alerte" or (e["etat"] == "poursuite" and not p.get("pacifique", false)):
		_marque(n, "!", Vector2(0, -hf - h * 0.12), h, Color8(255, 70, 50))
	elif e["etat"] == "recherche":
		_marque(n, "?", Vector2(0, -hf - h * 0.12), h, Color8(255, 220, 90))


## Un gobelin ``membre`` ({sous_classe, image}, voir ``Aventure.membres``) dessiné comme en combat : pieds en
## ``pieds``, corps de ``hauteur`` px, tourné vers où il regarde. Sortes animées (``CombatAnime.TYPES``) :
## respiration « attente » (``anim`` « mort » : dernière image de la mort) ; autres : image fixe du combat.
## ``k`` : rang dans le groupe (décale la respiration). Renvoie la hauteur du haut de la tête au-dessus des pieds.
func _gobelin(n: Node2D, e: Dictionary, membre: Dictionary, k: int, pieds: Vector2, hauteur: float, teinte: Color,
		anim := "attente") -> float:
	var decalage := int(e["p"].get("id", 0)) * 0.37 + k * 0.81
	var sens := -1.0 if e["regard"].x < -0.2 else 1.0
	var sorte: String = CombatAnime.TYPES.get(str(membre.get("sous_classe", "")), "")
	var nom_marche := marche_gobelin(sorte)
	if anim == "attente" and nom_marche != "" and temps - float(e.get("t_bouge", -INF)) < 0.2:
		return _gobelin_en_marche(n, e, nom_marche, sorte, k, pieds, hauteur, teinte)
	var jeu: Dictionary = CombatAnime.donnees()["gobelins"].get(sorte, {})
	if jeu.is_empty() or not jeu["anims"].has(anim):
		# Sans animation de mort (squelette, loup, gobelin sans animation) : son image de base, couchée sur le dos
		return _gobelin_fixe(n, str(membre.get("image", "")), pieds, hauteur, teinte, sens, decalage, anim == "mort")
	var defn: Dictionary = jeu["anims"][anim]
	var image := int(defn["images"]) - 1
	if anim == "mort":
		image = image_mort(e["p"], int(defn["images"]), defn.get("ms", []))
	if anim == "attente":
		var ms: Array = defn["ms"]
		var total := 0.0
		for v in ms:
			total += float(v) / 1000.0
		var t := fposmod(temps + decalage, total)
		image = 0
		while image < ms.size() - 1 and t >= float(ms[image]) / 1000.0:
			t -= float(ms[image]) / 1000.0
			image += 1
	var tex := Ui.texture("combat_anime/gobelins/%s/%s_%02d.png" % [sorte, anim, image])
	if tex == null:
		return hauteur
	var s := hauteur / float(jeu["corps"])
	var ancre: Array = defn["pieds"]
	n.draw_set_transform(pieds, 0, Vector2(sens * s, s))
	n.draw_texture_rect(tex, Rect2(-Vector2(ancre[0], ancre[1]), tex.get_size()), false, teinte)
	n.draw_set_transform(Vector2.ZERO)
	if anim != "attente":
		return hauteur * 0.3
	return hauteur * haut_tete(sorte)


## Haut de la tête (arme comprise) d'une sorte animée au repos, en fraction de son corps : première ligne non
## transparente de la première image de repos.
static func haut_tete(sorte: String) -> float:
	if not _haut_tete.has(sorte):
		var jeu: Dictionary = CombatAnime.donnees()["gobelins"][sorte]
		var ancre: Array = jeu["anims"]["attente"]["pieds"]
		var premiere := Ui.texture("combat_anime/gobelins/%s/attente_00.png" % sorte)
		_haut_tete[sorte] = (float(ancre[1]) - premiere.get_image().get_used_rect().position.y) / float(jeu["corps"])
	return float(_haut_tete[sorte])


## Marches des gobelins (Grok, 2026-10-28 : guerrier, archer, chaman, féticheur ; pas le sorcier) :
## ``images/pnj/gobelin_<sorte>_anim`` (``outils/importer_animations_marche.py``). Nom de la marche de la sorte, ou
## "" si elle n'en a pas (sorcier, lancier, défenseur, squelette, loup : ils gardent leur image de repos).
static var _a_marche := {}


static func marche_gobelin(sorte: String) -> String:
	if sorte == "":
		return ""
	var nom := "gobelin_" + sorte
	if not _a_marche.has(nom):
		_a_marche[nom] = FileAccess.file_exists("res://images/pnj/%s_anim/animations.json" % nom)
	return nom if _a_marche[nom] else ""


## Hauteur de l'image de marche d'un gobelin dont le corps fait 1 : sa silhouette (part « visible » de l'image) a la
## même hauteur que son image de repos du combat, arme comprise.
static func rapport_marche_gobelin(nom: String, sorte: String) -> float:
	return haut_tete(sorte) / float(infos_marche(nom).get("visible", 1.0))


## Taille (hauteurs de héros) du ``k``-ième gobelin de ``p``, comme dans ``_dessiner``.
static func taille_membre(p: Dictionary, k: int) -> float:
	if p["genre"] != "groupe" or (k == 0 and p.get("elite", false)):
		return _hauteur_forme(p)
	return TAILLE_GOBELIN


## Vitesse (hauteurs de héros par seconde) d'un groupe de gobelins au rythme de leur marche, hors poursuite (voir
## COURSE_GOBELINS) : celle du plus lent de
## ceux qui ont une marche animée (les autres suivent) ; -1 si aucun n'en a. Guerrier ≈ 0,15, archer ≈ 0,25.
static func vitesse_gobelins(p: Dictionary) -> float:
	var v := INF
	var liste := Aventure.membres(p)
	for k in liste.size():
		var sorte: String = CombatAnime.TYPES.get(str(liste[k].get("sous_classe", "")), "")
		var nom := marche_gobelin(sorte)
		if nom == "":
			continue
		var info := infos_marche(nom)
		v = minf(v, float(info["foulee"]) * float(info["fps"]) * taille_membre(p, k) * rapport_marche_gobelin(nom, sorte))
	return v if v != INF else -1.0


## Gobelin en marche : vue selon la direction (comme le geôlier), image selon la distance parcourue (pieds qui ne
## glissent pas). Renvoie le haut de la tête.
func _gobelin_en_marche(n: Node2D, e: Dictionary, nom: String, sorte: String, k: int, pieds: Vector2, hauteur: float,
		teinte: Color) -> float:
	var v := vue_marche(e["regard"])
	var images := images_marche(nom, v[0])
	var haut_image := hauteur * rapport_marche_gobelin(nom, sorte)
	# Distance parcourue (hauteurs de héros) / foulée (en hauteurs de héros de cette image)
	var h := salle.hauteur(e["pos"].y)
	var distance := float(e.get("parcouru", 0.0)) * _hauteur_forme(e["p"])
	var foulee := float(infos_marche(nom)["foulee"]) * haut_image / h
	var i := int(distance / foulee + int(e["p"].get("id", 0)) * 7 + k * 5) % images.size()
	var tex: Texture2D = images[i]
	var taille := Vector2(haut_image * tex.get_width() / float(tex.get_height()), haut_image)
	n.draw_set_transform(pieds, 0, Vector2(-1.0 if v[1] else 1.0, 1))
	n.draw_texture_rect(tex, Rect2(Vector2(-taille.x / 2.0, -taille.y), taille), false, teinte)
	n.draw_set_transform(Vector2.ZERO)
	return hauteur * haut_tete(sorte)


## Gobelin sans animation (lancier, défenseur) : son image fixe du combat (``images/gobelins``), à la même échelle
## qu'en combat (corps = CombatAnime.PROPORTION_CORPS de l'image), qui respire. Renvoie le haut de la tête.
## Image de l'animation de mort à montrer pour la présence ``p`` : le gobelin blessé est en train de s'effondrer
## (MORT_BLESSE de l'animation) ; achevé (``t_mort``), l'animation reprend jusqu'au bout ; un corps : la dernière.
const MORT_BLESSE := 0.45


func image_mort(p: Dictionary, images: int, ms: Array) -> int:
	var depart := int(round((images - 1) * MORT_BLESSE))
	if p.get("sous") == "gobelin_blesse":
		return depart
	if p.has("t_mort"):
		var duree := 0.0
		var k := depart
		var ecoule := Animations.temps() - float(p["t_mort"])  # même horloge que Rencontres (t_mort)
		while k < images - 1:
			duree += (float(ms[k]) / 1000.0) if k < ms.size() else 0.08
			if ecoule < duree:
				return k
			k += 1
	return images - 1


func _gobelin_fixe(n: Node2D, fichier: String, pieds: Vector2, hauteur: float, teinte: Color, sens: float,
		decalage: float, couche := false) -> float:
	var tex := Ui.texture("gobelins/" + (fichier if fichier != "" else "defaut.png"))
	if tex == null:
		_capsule(n, pieds, hauteur * 0.26, hauteur, Color8(70, 95, 45) * teinte)
		return hauteur
	if not _cadres.has(fichier):
		_cadres[fichier] = tex.get_image().get_used_rect()
	var cadre: Rect2i = _cadres[fichier]
	var s := hauteur / CombatAnime.PROPORTION_CORPS / float(tex.get_height())
	if couche:
		# Couché sur le dos : l'image tournée d'un quart de tour, posée à plat sur le sol, sans respiration
		var largeur := float(cadre.size.x) * s
		var long := float(cadre.size.y) * s
		n.draw_set_transform(pieds + Vector2(-sens * long / 2.0, -largeur * 0.45), sens * PI / 2.0, Vector2(s, s))
		n.draw_texture_rect(tex, Rect2(-Vector2(cadre.get_center().x, cadre.end.y), tex.get_size()), false, teinte.darkened(0.2))
		n.draw_set_transform(Vector2.ZERO)
		return largeur
	var souffle := 0.5 - 0.5 * cos(TAU * fposmod(Animations.temps() / Animations.PERIODE_RESPIRATION + decalage, 1.0))
	var echelle := Vector2(sens * s * (1 - Animations.AMPLITUDE_RESPIRATION / 3 * souffle), s * (1 + Animations.AMPLITUDE_RESPIRATION * souffle))
	n.draw_set_transform(pieds, 0, echelle)
	n.draw_texture_rect(tex, Rect2(-Vector2(cadre.get_center().x, cadre.end.y), tex.get_size()), false, teinte)
	n.draw_set_transform(Vector2.ZERO)
	return float(cadre.end.y - cadre.position.y) * echelle.y


## Marches animées de Grok (``outils/importer_animations_marche.py`` → ``images/pnj/<nom>_anim``) : Chevalier de la
## mort et geôlier (depuis le 2026-10-27). La vue suit la direction où il va (de dos s'il s'éloigne, de face s'il vient
## vers le spectateur, profil ou trois-quarts sur les côtés, miroir pour la gauche) ; immobile, il garde la première
## image de sa vue. Nombre d'images, cadence et foulée : ``animations.json`` du dossier. Il avance au rythme de sa
## marche (``vitesse_marche``) et l'image suit la distance parcourue (``parcouru``) : pas de glissade.
const MARCHES := {"imbattable": "chevalier", "geolier": "geolier"}
static var _images_marche := {}
static var _infos_marche := {}


static func infos_marche(nom: String) -> Dictionary:
	if not _infos_marche.has(nom):
		_infos_marche[nom] = JSON.parse_string(FileAccess.get_file_as_string("res://images/pnj/%s_anim/animations.json" % nom))
	return _infos_marche[nom]


static func images_marche(nom: String, vue: String) -> Array:
	var cle := nom + "/" + vue
	if not _images_marche.has(cle):
		var liste := []
		for k in int(infos_marche(nom)["vues"][vue]["images"]):
			liste.append(load("res://images/pnj/%s_anim/%s_%03d.png" % [nom, vue, k]))
		_images_marche[cle] = liste
	return _images_marche[cle]


## Vue (et miroir) d'un marcheur qui regarde dans la direction ``r`` (image : y vers le bas).
## Vitesse d'un marcheur au rythme de son animation, en hauteurs de héros par seconde : foulée (hauteurs de son image
## par image) × images par seconde × sa taille (hauteurs de héros). Geôlier ≈ 0,19, chevalier ≈ 0,18 (le héros marche à 0,81).
static func vitesse_marche(nom: String, p: Dictionary) -> float:
	var info := infos_marche(nom)
	return float(info.get("foulee", 0.012)) * float(info.get("fps", 12)) * _hauteur_forme(p)


static func vue_marche(r: Vector2) -> Array:
	var a := rad_to_deg(atan2(r.y, absf(r.x)))  # -90 : s'éloigne ; 0 : de côté ; 90 : vient vers nous
	var vue := "dos" if a < -55.0 else ("profil" if a < 25.0 else ("trois_quarts" if a < 65.0 else "face"))
	return [vue, r.x < -0.05 and vue in ["profil", "trois_quarts"]]


func _marche_animee(n: Node2D, e: Dictionary, hauteur: float, nom: String) -> void:
	var v := vue_marche(e["regard"])
	var images := images_marche(nom, v[0])
	# Image selon la distance parcourue (une foulée par image) : les pieds suivent le sol
	var foulee := float(infos_marche(nom).get("foulee", 0.012))
	var bouge := temps - float(e.get("t_bouge", -INF)) < 0.2
	var k := int(float(e.get("parcouru", 0.0)) / foulee + int(e["p"].get("id", 0)) * 7) % images.size() if bouge else 0
	var tex: Texture2D = images[k]
	var taille := Vector2(hauteur * tex.get_width() / float(tex.get_height()), hauteur)
	n.draw_set_transform(Vector2.ZERO, 0, Vector2(-1.0 if v[1] else 1.0, 1))
	n.draw_texture_rect(tex, Rect2(Vector2(-taille.x / 2.0, -taille.y), taille), false)
	n.draw_set_transform(Vector2.ZERO)


func _capsule(n: Node2D, base: Vector2, rayon: float, haut: float, couleur: Color) -> void:
	n.draw_rect(Rect2(base + Vector2(-rayon, -haut + rayon), Vector2(rayon * 2, haut - rayon)), couleur)
	n.draw_circle(base + Vector2(0, -haut + rayon), rayon, couleur)


func _couronne(n: Node2D, sommet: Vector2, taille: float, couleur: Color) -> void:
	var pts := PackedVector2Array([sommet + Vector2(-taille, 0), sommet + Vector2(-taille, -taille * 0.8),
		sommet + Vector2(-taille * 0.4, -taille * 0.3), sommet + Vector2(0, -taille), sommet + Vector2(taille * 0.4, -taille * 0.3),
		sommet + Vector2(taille, -taille * 0.8), sommet + Vector2(taille, 0)])
	n.draw_colored_polygon(pts, couleur)


func _marque(n: Node2D, signe: String, pos: Vector2, h: float, couleur: Color) -> void:
	var taille := int(maxf(10.0, h * 0.28))
	var police := Ui.police(true)
	var largeur := police.get_string_size(signe, HORIZONTAL_ALIGNMENT_LEFT, -1, taille).x
	n.draw_string(police, pos + Vector2(-largeur / 2.0 + 1, 1), signe, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, Color(0, 0, 0, 0.7))
	n.draw_string(police, pos + Vector2(-largeur / 2.0, 0), signe, HORIZONTAL_ALIGNMENT_LEFT, -1, taille, couleur)
