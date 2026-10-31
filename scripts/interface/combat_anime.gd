class_name CombatAnime
extends RefCounted
## Animations image par image du combat (images de Grok, voir outils/importer_animations.py) :
## le héros vu de dos au premier plan (garde de son arme, attaque, coup reçu) et les gobelins
## combattant / archer / sorcier / chaman / féticheur (attente, attaque, touché, mort). Les autres sous-classes gardent
## leur image fixe qui respire.
##
## Les règles ne changent pas : le combat calcule les coups tout de suite et EffetsCombat les rejoue.
## Ce module se branche sur ce rejeu :
## - EffetsCombat.planifier demande une « avance » au premier coup de chaque attaque d'un combattant
##   animé (avance) : le coup est retardé du temps qui sépare le début de l'animation d'attaque de son
##   image d'impact, et l'animation démarre ce temps-là avant (demarrer) ;
## - à l'instant où un coup s'affiche (mettre_a_jour), la cible joue « touché » ou « mort ».
## Chevalier de la mort (jeu « chevalier », ``outils/importer_combat_chevalier.py``) : deux attaques, et à la place de
## « touché » une **parade** (touche1 / touche2) lancée avant le coup, pour que la garde soit levée à l'impact (son
## ``impact``) ; pas d'animation de mort (il garde son image fixe s'il tombe).

const DONNEES := "combat_anime.json"
## Sous-classe du jeu → jeu d'images animées.
const TYPES := {"combattant": "guerrier", "archer": "archer", "sorcier": "sorcier", "chaman": "chaman", "feticheur": "feticheur"}
const ARMES := {"Epée": "epee", "Lance": "lance", "Marteau": "marteau"}
## Gobelin animé : hauteur du corps (oreilles comprises) / hauteur du cadre du sprite fixe.
const PROPORTION_CORPS := 0.9
## Héros au premier plan, de dos : position des pieds (au milieu, sous le bas de l'écran) et hauteur du corps.
const PIEDS_HEROS := Vector2(480, 715)
const HAUTEUR_HEROS := 380.0
## Fondu d'un gobelin mort après la dernière image de son animation de mort.
const FONDU_MORT := 0.6
## Coups qui ne font pas réagir la cible.
const SANS_REACTION := ["rate", "etat", "lumière"]

static var _donnees = null
## Combattant → {"anim": nom, "debut": instant, "prochaines": [[instant, nom]]}
static var _etats := {}
static var _vus := {}
static var _attaque_heros = null      # attaque demandée par l'écran, en attente de son premier coup
static var _derniere_attaque := {}    # combattant → instant d'impact de sa dernière attaque animée
static var _gardes := {}              # coups déjà parés d'avance (Chevalier de la mort)
static var _fin_garde := {}           # combattant → fin de sa parade en cours
static var _parade_prevue := {}       # coup → [parade, durée de la montée] (lancée par demarrer)
static var _avance_propre := {}       # coup → avance de l'animation du lanceur (sans l'attente de la parade)


static func donnees() -> Dictionary:
	if _donnees == null:
		_donnees = U.charger_json(DONNEES)
		if _donnees == null:
			_donnees = {"gobelins": {}, "heros": {"armes": {}}}
	return _donnees


static func maintenant() -> float:
	return EffetsCombat.maintenant()


## Jeu d'images d'un ennemi ("guerrier", "archer", "sorcier") ou "" s'il n'est pas animé.
static func type_gobelin(ennemi) -> String:
	var propre := str(U.ga(ennemi, "anim_combat", ""))  # jeu d'images propre (Chevalier de la mort : « chevalier »)
	if propre != "":
		return propre if donnees()["gobelins"].has(propre) else ""
	if U.ga(ennemi, "sans_animation", false):
		return ""
	var t: String = TYPES.get(str(U.ga(ennemi, "sous_classe", "")), "")
	return t if donnees()["gobelins"].has(t) else ""


static func est_heros(combattant) -> bool:
	return EffetsCombat.combat != null and combattant == EffetsCombat.combat.personnage


static func est_anime(combattant) -> bool:
	return type_gobelin(combattant) != "" or est_heros(combattant)


static func arme_heros(joueur) -> String:
	var a: String = ARMES.get(str(joueur.get_type_arme()), "")
	return a if donnees()["heros"]["armes"].has(a) else ""


## Définition d'une animation : {"images", "ms", "pieds", "impact", "boucle", "garder"} et son dossier.
static func _definition(combattant, anim: String) -> Array:
	var t := type_gobelin(combattant)
	if t != "":
		return [donnees()["gobelins"][t]["anims"].get(anim), "gobelins/%s/%s" % [t, anim], float(donnees()["gobelins"][t]["corps"])]
	var h: Dictionary = donnees()["heros"]
	var corps := float(h["corps"])
	if anim in ["touche", "repos", "sort"]:
		return [h[anim], "heros/%s/%s" % [anim, anim], corps]
	var a := arme_heros(combattant)
	if a == "":
		return [h["repos"], "heros/repos/repos", corps]
	return [h["armes"][a][anim], "heros/%s/%s" % [a, anim], corps]


static func _repos(combattant) -> String:
	return "attente" if type_gobelin(combattant) != "" else "garde"


static func _duree(defn: Dictionary, jusqu_a: int = -1) -> float:
	var ms: Array = defn["ms"]
	var n := ms.size() if jusqu_a < 0 else jusqu_a
	var total := 0.0
	for i in n:
		total += float(ms[i])
	return total / 1000.0


## Programme une animation à l'instant ``debut`` (dans le futur ou maintenant).
static func jouer(combattant, anim: String, debut: float) -> void:
	var e := _etat(combattant)
	e["prochaines"].append([debut, anim])
	e["prochaines"].sort_custom(func(a, b): return a[0] < b[0])


static func _etat(combattant) -> Dictionary:
	if not _etats.has(combattant):
		# Attente décalée d'un combattant à l'autre (comme la phase de respiration). La phase peut être
		# négative (identifiant d'objet négatif) : ramenée entre 0 et 2π pour que l'attente parte du
		# passé, sinon l'animation resterait figée sur sa première image jusqu'à ce départ.
		var decalage := fposmod(Animations.phase_de(combattant), TAU)
		_etats[combattant] = {"anim": _repos(combattant), "debut": maintenant() - decalage, "prochaines": []}
	return _etats[combattant]


## Animation et image courantes : [nom, index, définition, dossier, corps].
static func image_courante(combattant) -> Array:
	var t := maintenant()
	var e := _etat(combattant)
	while not e["prochaines"].is_empty() and e["prochaines"][0][0] <= t:
		var p: Array = e["prochaines"].pop_front()
		e["anim"] = p[1]
		e["debut"] = p[0]
	var d := _definition(combattant, e["anim"])
	var defn = d[0]
	if defn == null:
		e["anim"] = _repos(combattant)
		d = _definition(combattant, e["anim"])
		defn = d[0]
	var ecoule: float = t - e["debut"]
	var total := _duree(defn)
	if ecoule >= total:
		if defn.get("boucle", false):
			ecoule = fmod(ecoule, total)
		elif defn.get("garder", false):
			return [e["anim"], int(defn["images"]) - 1, defn, d[1], d[2]]
		else:
			# Fin d'une animation jouée une fois : retour à l'attente, sans saut d'image.
			if float(defn.get("fondu_fin", 0.0)) > 0.0:
				# Pas d'images de retour à la pose de repos (Chevalier de la mort) : fondu depuis la dernière image
				e["fondu"] = {"dossier": d[1], "index": _fichier(defn, int(defn["images"]) - 1), "corps": d[2],
					"pieds": defn["pieds"], "debut": e["debut"] + total, "duree": float(defn["fondu_fin"])}
			e["debut"] = e["debut"] + total
			e["anim"] = _repos(combattant)
			return image_courante(combattant)
	var ms: Array = defn["ms"]
	var i := 0
	var cumul := 0.0
	while i < ms.size() - 1 and ecoule >= cumul + float(ms[i]) / 1000.0:
		cumul += float(ms[i]) / 1000.0
		i += 1
	return [e["anim"], i, defn, d[1], d[2]]


## Fichier de l'image n° ``i`` d'une animation (``ordre`` : images réutilisées, par exemple une garde qui redescend).
static func _fichier(defn: Dictionary, i: int) -> int:
	var ordre = defn.get("ordre", null)
	return int(ordre[i]) if ordre is Array and i < ordre.size() else i


## Dessine l'image courante d'un combattant animé : pieds au milieu du bas de ``r`` (gobelin) ou
## au point ``pieds`` (héros), corps de ``hauteur`` px.
static func _dessiner(ci: CanvasItem, combattant, pieds: Vector2, hauteur: float, teinte: Color) -> void:
	var c := image_courante(combattant)
	var tex := Ui.texture("combat_anime/%s_%02d.png" % [c[3], _fichier(c[2], c[1])])
	if tex == null:
		return
	# Fondu de fin (Chevalier de la mort) : la pose de repos, pleine, puis par-dessus la dernière image qui s'efface
	var fondu = _etat(combattant).get("fondu", null)
	var ancienne: Array = []
	if fondu is Dictionary:
		var k := (maintenant() - float(fondu["debut"])) / float(fondu["duree"])
		if k >= 1.0 or c[0] != _repos(combattant):
			_etat(combattant).erase("fondu")
		else:
			ancienne = [fondu, clampf(1.0 - k, 0.0, 1.0)]
	var s: float = hauteur / float(c[4])
	var p: Array = c[2]["pieds"]
	var echelle := Vector2(s, s)
	if int(c[2]["images"]) == 1 and c[2].get("boucle", false):
		# Pose d'une seule image (garde de la lance, sans idle fourni) : elle respire comme les images
		# fixes (Animations.dessiner_respirant), ancrée aux pieds.
		var avancement := fposmod(Animations.temps() / Animations.PERIODE_RESPIRATION, 1.0)
		var souffle := 0.5 - 0.5 * cos(TAU * avancement)
		echelle *= Vector2(1 - Animations.AMPLITUDE_RESPIRATION / 3 * souffle, 1 + Animations.AMPLITUDE_RESPIRATION * souffle)
	ci.draw_texture_rect(tex, Rect2(pieds - Vector2(p[0], p[1]) * echelle, tex.get_size() * echelle), false, teinte)
	if not ancienne.is_empty():
		var f: Dictionary = ancienne[0]
		var tex0 := Ui.texture("combat_anime/%s_%02d.png" % [f["dossier"], int(f["index"])])
		var s0: float = hauteur / float(f["corps"])
		var p0: Array = f["pieds"]
		if tex0 != null:
			ci.draw_texture_rect(tex0, Rect2(pieds - Vector2(p0[0], p0[1]) * s0, tex0.get_size() * s0), false,
				Color(teinte, teinte.a * float(ancienne[1])))


## Dessine un gobelin animé dans le cadre de son sprite fixe ; faux s'il n'est pas animé.
static func dessiner_gobelin(ci: CanvasItem, ennemi, r: Rect2, teinte := Color(1, 1, 1, 1)) -> bool:
	if type_gobelin(ennemi) == "":
		return false
	_dessiner(ci, ennemi, Vector2(r.get_center().x, r.end.y), r.size.y * PROPORTION_CORPS, teinte)
	return true


## Dessine un gobelin animé qui meurt (coup mortel ``imp``) : animation de mort puis fondu.
## Faux s'il n'est pas animé.
static func dessiner_mourant(ci: CanvasItem, imp, r: Rect2) -> bool:
	if type_gobelin(imp.cible) == "" or not a_l_anim(imp.cible, "mort"):
		return false
	var alpha := 1.0
	if imp.debut != null:
		var defn = _definition(imp.cible, "mort")[0]
		var fin_anim: float = imp.debut + _duree(defn, int(defn["images"]) - 1)
		alpha = clampf(1.0 - (maintenant() - fin_anim) / FONDU_MORT, 0.0, 1.0)
	if alpha > 0.0:
		dessiner_gobelin(ci, imp.cible, r, Color(1, 1, 1, alpha))
	return true


## Le jeu d'images du combattant a l'animation ``anim``.
static func a_l_anim(combattant, anim: String) -> bool:
	var t := type_gobelin(combattant)
	return t != "" and donnees()["gobelins"][t]["anims"].has(anim)


## Parades du combattant (animations « touche1 », « touche2 »... avec une image d'impact = garde levée).
static func parades(combattant) -> Array:
	var t := type_gobelin(combattant)
	if t == "":
		return []
	var liste := []
	for a in donnees()["gobelins"][t]["anims"]:
		var defn: Dictionary = donnees()["gobelins"][t]["anims"][a]
		if String(a).begins_with("touche") and int(defn.get("impact", -1)) >= 0:
			liste.append(a)
	return liste


## Durée pendant laquelle un coup mortel reste à l'écran (EffetsCombat.durees_mort).
static func duree_mort(ennemi) -> float:
	var defn = _definition(ennemi, "mort")[0]
	return _duree(defn, int(defn["images"]) - 1) + FONDU_MORT + 0.1


## Le héros, de dos, au premier plan.
static func dessiner_heros(ci: CanvasItem, joueur) -> void:
	_dessiner(ci, joueur, PIEDS_HEROS, HAUTEUR_HEROS, Color(1, 1, 1, 1))


# ---------------------------------------------------------------------------
# Calage sur les coups (appelé par EffetsCombat et l'écran de combat)
# ---------------------------------------------------------------------------

## Nouveau combat : oublie les états (les combattants d'un combat précédent).
static func nouveau_combat(c) -> void:
	_etats.clear()
	_vus.clear()
	_derniere_attaque.clear()
	_attaque_heros = null
	_gardes.clear()
	_fin_garde.clear()
	_parade_prevue.clear()
	_avance_propre.clear()
	for e in c.ennemis:
		if type_gobelin(e) != "" and a_l_anim(e, "mort"):
			EffetsCombat.durees_mort[e] = duree_mort(e)
	precharger(c)


## Charge d'avance toutes les images du héros et des gobelins animés du combat : chargées à leur
## première apparition, elles feraient saccader la première attaque (Ui garde les textures en cache).
static func precharger(c) -> void:
	var dossiers := ["heros/touche/touche", "heros/repos/repos", "heros/sort/sort"]
	var a := arme_heros(c.personnage)
	if a != "":
		dossiers += ["heros/%s/garde" % a, "heros/%s/attaque" % a]
	for e in c.ennemis:
		var t := type_gobelin(e)
		if t != "":
			for anim in donnees()["gobelins"][t]["anims"]:
				dossiers.append("gobelins/%s/%s" % [t, anim])
	for d in dossiers:
		var i := 0
		while ResourceLoader.exists("res://images/combat_anime/%s_%02d.png" % [d, i]):
			Ui.texture("combat_anime/%s_%02d.png" % [d, i])
			i += 1


## Le héros vient de lancer une compétence d'arme : son premier coup jouera l'attaque de l'arme.
static func demander_attaque_heros(joueur) -> void:
	_attaque_heros = "attaque" if arme_heros(joueur) != "" else null


## Le héros vient de lancer une magie : son premier coup jouera le lancer de sort.
static func demander_sort_heros() -> void:
	_attaque_heros = "sort" if donnees()["heros"].has("sort") else null


## Oublie une attaque demandée qui n'a donné aucun coup (nouvel écran de combat).
static func annuler_attaque_heros() -> void:
	_attaque_heros = null


## Avance (s) à donner au premier coup d'une attaque de ``imp.source`` : temps entre le début de son
## animation d'attaque et l'image d'impact ; 0 si pas d'animation (ou déjà jouée pour cette attaque).
## Choisit aussi l'animation (imp.anim_source).
static func avance(imp) -> float:
	var src = imp.source
	if src == null or not est_anime(src):
		return 0.0
	var anim := ""
	if est_heros(src):
		if _attaque_heros == null:
			return 0.0
		anim = _attaque_heros
		_attaque_heros = null
	else:
		# Plusieurs coups de la même action (plusieurs cibles) : une seule animation.
		if maintenant() < float(_derniere_attaque.get(src, -10.0)) + 0.8:
			return 0.0
		var attaques := []
		for a in donnees()["gobelins"][type_gobelin(src)]["anims"]:
			if String(a).begins_with("attaque"):
				attaques.append(a)
		if attaques.is_empty():
			return 0.0
		anim = attaques.pick_random()
	var defn = _definition(src, anim)[0]
	if defn == null or int(defn.get("impact", -1)) < 0:
		return 0.0
	imp.anim_source = anim
	var propre := _duree(defn, int(defn["impact"]))
	_avance_propre[imp] = propre
	# La cible pare (Chevalier de la mort) : le coup attend que sa garde soit levée
	var choix := parades(imp.cible)
	if not choix.is_empty() and not (imp.type in SANS_REACTION) and not _en_garde(imp.cible, maintenant()):
		var parade: String = choix.pick_random()
		var dp: Dictionary = _definition(imp.cible, parade)[0]
		var montee := _duree(dp, int(dp["impact"]))
		_parade_prevue[imp] = [parade, montee]
		return maxf(propre, montee)
	return propre


## Le premier coup est planifié à ``imp.debut`` : l'attaque démarre ``avance`` secondes avant.
static func demarrer(imp, avance_s: float) -> void:
	var propre: float = _avance_propre.get(imp, avance_s)
	_avance_propre.erase(imp)
	if imp.anim_source != "":
		jouer(imp.source, imp.anim_source, imp.debut - propre)
	_derniere_attaque[imp.source] = imp.debut
	if _parade_prevue.has(imp):
		var p: Array = _parade_prevue[imp]
		_parade_prevue.erase(imp)
		_gardes[imp] = true
		jouer(imp.cible, p[0], imp.debut - float(p[1]))
		_fin_garde[imp.cible] = imp.debut - float(p[1]) + _duree(_definition(imp.cible, p[0])[0])


## La cible est déjà en garde (parade en cours) à l'instant ``t``.
static func _en_garde(cible, t: float) -> bool:
	return t < float(_fin_garde.get(cible, -10.0))


## Réactions des cibles au moment où chaque coup s'affiche (à appeler à chaque image).
static func mettre_a_jour(joueur) -> void:
	var t := maintenant()
	# Parades (Chevalier de la mort) : la garde commence assez tôt pour être levée quand le coup arrive
	for imp in EffetsCombat.file:
		if imp.debut == null or _gardes.has(imp) or imp.cible == null:
			continue
		var choix := parades(imp.cible)
		if choix.is_empty() or imp.type in SANS_REACTION:
			continue
		if t < float(_fin_garde.get(imp.cible, -10.0)) and imp.debut < float(_fin_garde[imp.cible]):
			_gardes[imp] = true  # déjà en garde pour ce coup (coup multiple)
			continue
		var anim: String = choix.pick_random()
		var defn: Dictionary = _definition(imp.cible, anim)[0]
		var montee := _duree(defn, int(defn["impact"]))
		if t >= imp.debut - montee:
			# Coup annoncé sans attente (cas rare : la parade est d'habitude prévue par avance/demarrer) : la garde
			# part du début, quitte à être levée un peu après le coup (pas de saut d'image)
			_gardes[imp] = true
			var debut: float = maxf(imp.debut - montee, t)
			jouer(imp.cible, anim, debut)
			_fin_garde[imp.cible] = debut + _duree(defn)
	for imp in EffetsCombat.file:
		if imp.debut == null or imp.debut > t or _vus.has(imp):
			continue
		_vus[imp] = true
		var cible = imp.cible
		if imp.mortel and type_gobelin(cible) != "":
			jouer(cible, "mort", imp.debut)
		elif imp.type in SANS_REACTION or imp.montant <= 0:
			continue
		elif not parades(cible).is_empty():
			continue  # il pare (ci-dessus) au lieu d'accuser le coup
		elif type_gobelin(cible) != "" and _etat(cible)["anim"] != "mort":
			jouer(cible, "touche", imp.debut)
		elif cible == joueur:
			jouer(cible, "touche", imp.debut)
	for imp in _vus.keys():
		if not imp in EffetsCombat.file:
			_vus.erase(imp)
	for imp in _gardes.keys():
		if not imp in EffetsCombat.file:
			_gardes.erase(imp)
