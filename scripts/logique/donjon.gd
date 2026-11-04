class_name Donjon
extends Dyn
## État et logique d'exploration du donjon : étages, salles, position, rencontres.
##
## ``plan_donjon`` : {étage (int): {id de salle (String): salle (Dictionary)}} ;
## ``salle_actuelle`` : [étage, id de salle (int)]. Les méthodes qui ouvrent un
## écran (combat, coffre, marchand...) sont des coroutines (``await``).

const CHANCE_MINI_BOSS := 0.2
## Chance qu'une salle soit piégée en y entrant (1 sur 15 avant ; désactivées par l'utilisateur le 2026-10-31).
## ``salle_piege`` reste prête si on les remet.
const CHANCE_PIEGE := 0.0
const RENCONTRES_ENTRE_MINI_BOSS := 3
const TYPES_SALLE := ["physique", "tranchante", "perforante", "contondante", "magique", "élémentaire", "feu", "froid",
	"foudre", "arcane", "chaos", "spirituel", "ombre", "lumière"]


static func nouveau(personnage, fenetre = null) -> Donjon:
	var d := Donjon.new()
	d._d["personnage"] = personnage
	d._d["fenetre"] = fenetre
	d._d["ennemis"] = []
	d._d["message_evenement"] = ""
	d._d["marchand"] = []
	var noms: Array = U.charger_json("divers.json")["noms_salles"]
	d._d["noms_possibles"] = noms.duplicate()
	d._d["noms_initiaux"] = noms.duplicate()
	d._d["noms_enregistres"] = []
	d._d["plan_donjon"] = {1: {"1": {"nom": "salle_debut", "type": "départ", "connections": [], "visitee": false}}}
	d._d["types_salle"] = TYPES_SALLE.duplicate()
	d._d["compteur_repos"] = 0
	d._d["salle_actuelle"] = [1, 1]
	d._d["niveau_joueur"] = 1
	d._d["marchand_rencontre"] = false
	# Tout le donjon est généré au lancement de la partie (2026-10-30, demande de l'utilisateur) : NOMBRE_ETAGES étages
	for e in range(1, NOMBRE_ETAGES + 1):
		d.generer_etage(e)
	d.generer_cryptes(1)
	return d


## Nombre d'étages du donjon, tous générés au lancement (décision de l'utilisateur, 2026-10-30) ; vaincre le boss
## du dernier étage et « Monter » termine la partie (écran de victoire). **1 seul** depuis le 2026-11-03 (demande de
## l'utilisateur : « on construit un niveau », les autres étages sont désactivés pour l'instant ; 5 avant).
const NOMBRE_ETAGES := 1
## Niveaux uniques (2026-11-03, demande de l'utilisateur : des niveaux « dans leur monde à part ») : rangés dans
## ``plan_donjon`` sous un numéro au-delà de 100, ils ne comptent pas comme des étages (pas de départ, de boss, de
## cachot ni de montée). On y entre par un passage (clé « passage_niveau » d'une salle). Le premier : les cryptes,
## sous les 4 prisons de l'étage 1.
const NIVEAU_CRYPTES := 101
## Plans des cryptes essayés : on garde celui que les images des cryptes habillent le mieux.
const ESSAIS_CRYPTES := 30


## Vrai pour un niveau unique (cryptes...), faux pour un étage.
static func est_niveau_unique(etage) -> bool:
	return int(etage) > 100


## Nom d'un étage ou d'un niveau unique, pour les messages : « l'étage 1 », « les cryptes ».
static func nom_niveau(etage) -> String:
	if int(etage) == NIVEAU_CRYPTES:
		return "les cryptes"
	return "l'étage %d" % int(etage)


## Vrai sur le dernier étage (sa montée est la sortie du donjon).
func est_dernier_etage() -> bool:
	return int(_d["salle_actuelle"][0]) >= NOMBRE_ETAGES


func salle_courante() -> Dictionary:
	return _d["plan_donjon"][_d["salle_actuelle"][0]][str(_d["salle_actuelle"][1])]


## Chances (en %) d'avoir 1, 2 ou 3 ennemis par étage ; au-delà du dernier étage listé, on garde le dernier.
const ENNEMIS_PAR_ETAGE := {
	1: [75, 25, 0],
	2: [50, 40, 10],
	3: [25, 50, 25],
	4: [20, 45, 35],
}


## Nombre de gobelins d'une rencontre, tiré selon l'étage (ENNEMIS_PAR_ETAGE).
func tirer_nombre_ennemis(etage = null) -> int:
	if etage == null:
		etage = _d["salle_actuelle"][0]
	# Niveau unique (cryptes) : comme le premier étage pour l'instant (2026-11-03)
	var cle: int = 1 if est_niveau_unique(etage) else clampi(int(etage), 1, ENNEMIS_PAR_ETAGE.keys().max())
	return U.choix_pondere([1, 2, 3], ENNEMIS_PAR_ETAGE[cle])


## Groupe de 1 à 3 gobelins selon l'étage ; une rencontre sur cinq est un mini-boss (s'il y en a eu assez depuis le dernier).
func generer_nombre_ennemis() -> Array:
	var ennemis := []
	var nombre := tirer_nombre_ennemis()
	var depuis: int = U.ga(self, "rencontres_depuis_mini_boss", 0)
	if depuis >= RENCONTRES_ENTRE_MINI_BOSS and randf() < CHANCE_MINI_BOSS:
		_d["rencontres_depuis_mini_boss"] = 0
		ennemis.append(Gobelin.nouveau(self, _d["niveau_joueur"]).generer_mini_boss_gobelin(self, _d["niveau_joueur"]))
		nombre = [0, 1].pick_random()
	else:
		_d["rencontres_depuis_mini_boss"] = depuis + 1
	for _i in nombre:
		ennemis.append(Gobelin.nouveau(self, _d["niveau_joueur"]).generer_gobelin(self, _d["niveau_joueur"]))
	return ennemis


func creer_boss_gobelin() -> Array:
	return [Gobelin.nouveau(self, _d["niveau_joueur"]).generer_boss_gobelin(self, _d["niveau_joueur"])]


## Événement de la salle actuelle : piège (CHANCE_PIEGE, désactivés) ou marchand. Pas de combat d'office : les ennemis rôdent dans
## la salle (Aventure, PresencesSalle) et le boss garde la sienne.
func generer_rencontre() -> void:
	var etage = _d["salle_actuelle"][0]
	var salle_id = _d["salle_actuelle"][1]
	var salle = _d["plan_donjon"][etage].get(str(salle_id))
	if salle != null and salle.get("visitee", false):
		print("[INFO] Salle déjà visitée — aucune rencontre.")
		return
	if est_salle_boss(etage, salle_id):
		return
	if salle != null and salle.get("type") == "bonus":
		print("[INFO] Salle bonus détectée — aucune menace générée.")
		return
	if CHANCE_PIEGE > 0 and randf() < CHANCE_PIEGE and not salle.get("cachot", false):
		print("[⚠️] Vous entrez dans une salle piégée...")
		salle_piege()
		return
	if salle != null and salle.get("evenement") == "marchand" and salle.get("type") != "marchand":
		await rencontre_marchand()
		_d["marchand_rencontre"] = true


## La salle devient celle du marchand, et son menu s'ouvre.
func rencontre_marchand() -> void:
	var salle := salle_courante()
	salle["type"] = "marchand"
	salle["effet_utilise"] = true
	print("Vous avez rencontré un marchand !")
	var marchand := Marchand.nouveau()
	salle["marchand"] = marchand
	await marchand.menu_marchand(self, _d["personnage"])


## Le repos n'est possible que dans une salle qui contient un lit (clé « lit » de la salle).
## Aucun lit n'est encore placé dans le donjon : ils viendront plus tard.
func peut_se_reposer() -> bool:
	return salle_courante().get("lit", false)


## Repos : PV et mana au maximum, et renforcement des futurs ennemis (seulement dans un lit).
func se_reposer() -> void:
	if not peut_se_reposer():
		print("Il n'y a pas de lit ici.")
		return
	var p = _d["personnage"]
	p.points_de_vie = p.points_de_vie_max
	p.mana = p.mana_max
	print("%s a récupéré tous ses points de vie." % p.nom)
	_d["compteur_repos"] += 1
	Statistiques.noter(p, "repos")
	Ennemis.bonus_ennemis(_d["compteur_repos"])


## Déplace le joueur (« t » haut, « g » gauche, « d » droite, « r » bas) puis génère la rencontre.
func avancer(direction: String) -> void:
	var etage = _d["salle_actuelle"][0]
	var actuelle := salle_courante()
	actuelle["visitee"] = true
	var pos: Vector2i = actuelle.get("position", Vector2i(0, 0))
	var mouvements := {}
	for conn in actuelle["connections"]:
		var voisine: Dictionary = _d["plan_donjon"][etage][str(conn)]
		var vp: Vector2i = voisine.get("position", Vector2i(0, 0))
		var ecart := vp - pos
		if ecart == Vector2i(0, 1):
			mouvements["t"] = conn
		elif ecart == Vector2i(-1, 0):
			mouvements["g"] = conn
		elif ecart == Vector2i(1, 0):
			mouvements["d"] = conn
		elif ecart == Vector2i(0, -1):
			mouvements["r"] = conn
	if not mouvements.has(direction):
		print("Direction invalide ou indisponible.")
		return
	var suivante = mouvements[direction]
	_d["salle_actuelle"] = [etage, int(suivante)]
	var salle: Dictionary = _d["plan_donjon"][etage][str(suivante)]
	if salle.get("type") == "bonus" and not salle.get("effet_utilise", false):
		await activer_effet_salle_bonus(salle)
	await generer_rencontre()


## Monte à l'étage suivant, depuis la salle du boss uniquement.
func monter_etage() -> void:
	if not est_salle_boss() or not boss_vaincu():
		print("Vous ne pouvez monter d'étage qu'à partir de la salle du boss.")
		return
	# La salle quittée est visitée : sans cela, redescendre ferait réapparaître le boss.
	salle_courante()["visitee"] = true
	var nouvel_etage: int = _d["salle_actuelle"][0] + 1
	if not _d["plan_donjon"].has(nouvel_etage):
		generer_etage(nouvel_etage)
	_d["salle_actuelle"] = [nouvel_etage, 1]
	Objet.compteur_etage_objet += 1
	print("Vous montez à l'étage %d." % nouvel_etage)
	_d["marchand_rencontre"] = false
	await generer_rencontre()


## Le boss de l'étage a été vaincu (il garde sa salle tant qu'il est actif).
func boss_vaincu(etage = null) -> bool:
	if etage == null:
		etage = _d["salle_actuelle"][0]
	var salle: Dictionary = _d["plan_donjon"].get(etage, {}).get(str(salle_boss(etage)), {})
	for p in salle.get("presences", []):
		if p.get("genre") == "boss" and p.get("etat") == "actif":
			return false
	return true


## On ne redescend que depuis la salle de départ d'un étage, hors premier étage.
func peut_descendre() -> bool:
	var etage: int = _d["salle_actuelle"][0]
	return etage > 1 and _d["plan_donjon"].has(etage - 1) and est_salle_depart()


## Redescend à l'étage précédent, dans la salle de son boss (depuis la salle de départ).
func descendre_etage() -> void:
	if not peut_descendre():
		print("On ne descend que depuis la salle de départ d'un étage, hors premier étage.")
		return
	var etage: int = _d["salle_actuelle"][0]
	salle_courante()["visitee"] = true
	_d["salle_actuelle"] = [etage - 1, salle_boss(etage - 1)]
	# On n'a pu monter que depuis cette salle : son boss est déjà vaincu (vaut aussi pour les anciennes sauvegardes).
	salle_courante()["visitee"] = true
	Objet.compteur_etage_objet -= 1
	print("Vous descendez à l'étage %d." % _d["salle_actuelle"][0])
	await generer_rencontre()


## Piège : PV, mana, or, ou PV et mana (message dans ``message_evenement``).
func salle_piege() -> void:
	var salle := salle_courante()
	salle["type"] = "piege"
	salle["effet_utilise"] = true
	var p = _d["personnage"]
	var type_piege = ["pv", "mana", "or", "mixte"].pick_random()
	var niveau: int = [1, 2, 3].pick_random()
	if type_piege == "pv":
		var perte := int(p.points_de_vie_max * [0.15, 0.25, 0.35][niveau - 1])
		p.points_de_vie -= perte
		Statistiques.noter(p, "degats_subis", perte)
		_d["message_evenement"] = "Piège ! Vous perdez %d PV." % perte
	elif type_piege == "mana":
		var perte = min(p.mana, int(p.mana_max * [0.35, 0.45, 0.55][niveau - 1]))
		p.mana -= perte
		_d["message_evenement"] = "Un piège magique vous draine %d points de mana." % perte
	elif type_piege == "or":
		var perte := int(p.piece_or * [0.15, 0.25, 0.35][niveau - 1])
		p.piece_or = max(0, p.piece_or - perte)
		_d["message_evenement"] = "Un piège sournois vous coûte %d pièces d'or." % perte
	else:
		var perte_pv := int(p.points_de_vie_max * [0.10, 0.15, 0.25][niveau - 1])
		var perte_mana = min(p.mana, int(p.mana_max * [0.15, 0.20, 0.35][niveau - 1]))
		p.points_de_vie -= perte_pv
		p.mana -= perte_mana
		Statistiques.noter(p, "degats_subis", perte_pv)
		_d["message_evenement"] = "Double piège ! Vous perdez %d PV et %d mana." % [perte_pv, perte_mana]
	print(_d["message_evenement"])
	Statistiques.verifier_mort(p, "piège")


## Action disponible dans la salle actuelle : [libellé, Callable (coroutine)], ou null.
func action_salle():
	var salle := salle_courante()
	if salle.get("type") == "bonus" and not salle.get("effet_utilise", false):
		var libelles := {"coffre": "Ouvrir le coffre", "soin": "Boire à la source", "choix_bonus": "Choisir un bonus"}
		var libelle = libelles.get(salle.get("effet_bonus"))
		if libelle != null:
			return [libelle, func(): await activer_effet_salle_bonus(salle)]
	var marchand = salle.get("marchand")
	if salle.get("type") == "marchand" and marchand != null:
		return ["Commercer", func(): await marchand.menu_marchand(self, _d["personnage"])]
	return null


## Ouvre le menu de l'effet d'une salle bonus (coffre, choix de bonus, source de soin).
func activer_effet_salle_bonus(salle: Dictionary) -> void:
	var effet = salle.get("effet_bonus")
	print("\n🌀 Salle bonus : %s" % String(effet).to_upper())
	if effet == "coffre":
		await Ecrans.menu_coffre(_d["fenetre"], _d["personnage"], self, salle)
	elif effet == "choix_bonus":
		await Ecrans.menu_bonus(_d["fenetre"], _d["personnage"], salle)
	elif effet == "soin":
		await Ecrans.menu_soin(_d["fenetre"], _d["personnage"], salle)


## Données de base d'une salle, nom réservé (les noms se réutilisent quand le stock est épuisé).
func _create_room_data(nom = null) -> Dictionary:
	if nom == null and _d["noms_possibles"].is_empty():
		_d["noms_possibles"] = U.ga(self, "noms_initiaux", _d["noms_enregistres"]).duplicate()
	if nom == null:
		nom = _d["noms_possibles"].pick_random()
	if nom in _d["noms_possibles"]:
		_d["noms_possibles"].erase(nom)
	_d["noms_enregistres"].append(nom)
	return {"nom": "%s (type %s)" % [nom, _d["types_salle"].pick_random()], "connections": [], "visitee": false}


## Génère un étage (generer_plan) et nomme ses salles ; la salle de départ est déjà visitée.
func generer_etage(etage: int) -> void:
	var plan := GenerateurEtage.generer_plan(etage)
	var salles := {}
	for ident in plan:
		var salle: Dictionary = plan[ident]
		var data: Dictionary
		if salle["role"] == "bonus":
			data = _create_room_data("Salle bonus")
			data["type"] = "bonus"
			data["nom"] = "Salle bonus (type bonus)"
			data["effet_bonus"] = salle["effet_bonus"]
		elif salle["role"] == "depart":
			data = _create_room_data("salle_debut")
			data["visitee"] = true
			data["depart"] = true
		elif salle["role"] == "boss":
			data = _create_room_data("Antre du boss")
			data["boss"] = true
		elif salle["role"] == "prison":
			data = _create_room_data("Couloir de la prison" if salle["prison_salle"] == "couloir" else "Prison")
			data["prison"] = salle["prison"]
			data["prison_salle"] = salle["prison_salle"]
			data["coin"] = salle["coin"]
			if salle["prison_salle"] == "couloir":
				# Le fond du couloir mène aux cryptes (salle d'arrivée posée par generer_cryptes)
				data["passage_niveau"] = {"niveau": NIVEAU_CRYPTES, "salle": "", "direction": [0, 1]}
		elif salle["role"] == "bloc":
			data = _create_room_data(BlocsSalles.BLOCS[salle["bloc"]]["salles"][salle["bloc_salle"]]["nom"])
			data["bloc"] = salle["bloc"]
			data["bloc_salle"] = salle["bloc_salle"]
			data["bloc_instance"] = salle["bloc_instance"]
		else:
			data = _create_room_data()
		if salle.has("evenement"):
			data["evenement"] = salle["evenement"]
		# Secteur de patrouille (étage carré, 2026-11-04) : 0 à 3 = coins, GenerateurEtage.CENTRE = centre
		if salle.has("secteur"):
			data["secteur"] = salle["secteur"]
		if salle.get("frontiere", false):
			data["frontiere"] = true
		data["position"] = salle["position"]
		var connexions: Array = salle["connexions"].keys()
		connexions.sort()
		var textes := []
		for c in connexions:
			textes.append(str(c))
		data["connections"] = textes
		salles[str(ident)] = data
	_d["plan_donjon"][etage] = salles
	_habiller_blocs(salles)
	# Un étage refait repart de zéro (sinon ses anciens réglages, « prepare », empêcheraient de le peupler)
	var reglages = U.ga(self, "aventure", null)
	if reglages is Dictionary:
		reglages.erase(etage)
	PlanSalles.attribuer(self, etage)  # images des salles d'abord : le cachot est choisi parmi les prisons
	Aventure.preparer_etage(self, etage)


## Niveau des cryptes (2026-11-03) : ESSAIS_CRYPTES plans (GenerateurEtage.generer_cryptes), on garde celui que les
## 14 images des cryptes habillent le mieux (PlanSalles.attribuer_salles). Chaque entrée (un coin) est reliée au
## couloir de la prison du même coin de l'étage ``etage`` : le fond du couloir y mène, et une sortie de l'entrée
## ramène au couloir. Une entrée sans prison (coin sans place sur l'étage) n'a pas de passage.
func generer_cryptes(etage := 1) -> void:
	var couloirs := {}
	for id in _d["plan_donjon"].get(etage, {}):
		var s: Dictionary = _d["plan_donjon"][etage][id]
		if s.get("prison_salle", "") == "couloir":
			couloirs[int(s["prison"])] = id
	var meilleur := {}
	var meilleur_score := -(1 << 40)
	for _essai in ESSAIS_CRYPTES:
		var plan := GenerateurEtage.generer_cryptes()
		var salles := {}
		for ident in plan:
			var data := _create_room_data("Crypte")
			data["crypte"] = true
			data["position"] = plan[ident]["position"]
			var connexions: Array = plan[ident]["connexions"].keys()
			connexions.sort()
			data["connections"] = connexions.map(func(c): return str(c))
			if plan[ident].has("entree") and couloirs.has(int(plan[ident]["entree"])):
				var d: Vector2i = plan[ident]["direction_passage"]
				data["entree_cryptes"] = int(plan[ident]["entree"])
				data["passage_niveau"] = {"niveau": etage, "salle": str(couloirs[int(plan[ident]["entree"])]),
					"direction": [d.x, d.y]}
			salles[str(ident)] = data
		var score := PlanSalles.attribuer_salles(salles, NIVEAU_CRYPTES, salles.keys())
		if score > meilleur_score:
			meilleur_score = score
			meilleur = salles
	_d["plan_donjon"][NIVEAU_CRYPTES] = meilleur
	for id in meilleur:
		if meilleur[id].has("entree_cryptes"):
			var couloir: Dictionary = _d["plan_donjon"][etage][str(couloirs[int(meilleur[id]["entree_cryptes"])])]
			couloir["passage_niveau"]["salle"] = id
	var reglages = U.ga(self, "aventure", null)
	if reglages is Dictionary:
		reglages.erase(NIVEAU_CRYPTES)
	Aventure.preparer_etage(self, NIVEAU_CRYPTES)


## Images et sorties des salles des blocs (BlocsSalles.salles_peintes), avant l'attribution des autres images :
## les liens porte à porte du bloc, et ses entrées vers la salle extérieure voisine.
func _habiller_blocs(salles: Dictionary) -> void:
	var instances := {}
	for id in salles:
		if salles[id].has("bloc_instance"):
			var k = salles[id]["bloc_instance"]
			if not instances.has(k):
				instances[k] = {"nom": salles[id]["bloc"], "ids": {}}
			instances[k]["ids"][salles[id]["bloc_salle"]] = id
	for k in instances:
		var nom: String = instances[k]["nom"]
		var ids: Dictionary = instances[k]["ids"]
		var exterieurs := {}
		for e in BlocsSalles.BLOCS[nom]["entrees"]:
			var ici: Dictionary = salles[ids[e[0]]]
			var cible: Vector2i = ici["position"] + e[2]
			for conn in ici["connections"]:
				if salles.has(conn) and salles[conn]["position"] == cible:
					exterieurs[e[0]] = conn
		var infos := BlocsSalles.salles_peintes(nom, ids, exterieurs)
		for cle in infos:
			salles[ids[cle]]["salle_peinte"] = infos[cle]


## Identifiant de la salle du boss d'un étage (15 pour un étage sans boss marqué, -1 pour un niveau unique).
func salle_boss(etage = null) -> int:
	if etage == null:
		etage = _d["salle_actuelle"][0]
	var salles: Dictionary = _d["plan_donjon"].get(etage, {})
	for i in salles:
		if salles[i].get("boss", false):
			return int(i)
	return -1 if est_niveau_unique(etage) else 15


## Salle de départ (première salle) d'un étage : clé « depart », ou nom « salle_debut »
## pour les étages générés avant l'ajout de cette clé.
func est_salle_depart(etage = null, salle_id = null) -> bool:
	if etage == null or salle_id == null:
		etage = _d["salle_actuelle"][0]
		salle_id = _d["salle_actuelle"][1]
	var salle: Dictionary = _d["plan_donjon"].get(etage, {}).get(str(salle_id), {})
	return salle.get("depart", false) or str(salle.get("nom", "")).begins_with("salle_debut")


func est_salle_boss(etage = null, salle_id = null) -> bool:
	if etage == null or salle_id == null:
		etage = _d["salle_actuelle"][0]
		salle_id = _d["salle_actuelle"][1]
	return int(salle_id) == salle_boss(etage)
