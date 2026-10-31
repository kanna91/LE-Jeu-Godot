class_name Personnage
extends Dyn
## Personnage joueur : statistiques, progression, équipement, magies et talents (personnage.py).

const _TYPES_ITEM := ["degats_tranchant", "degats_perforant", "degats_contondant", "degats_feu", "degats_froid",
	"degats_foudre", "degats_arcane", "degats_chaos", "degats_ombre", "degats_lumière", "penetration_resistance",
	"chance_de_coup_critique", "degats_critique", "force", "puissance_magique", "mana_max", "regen_mana",
	"chance_esquive", "chance_de_toucher", "chance_de_parer", "points_de_vie_max", "regen_de_points_de_vie",
	"points_d_action_max", "resistance_magique", "resistance_elementaire", "resistance_feu", "resistance_froid", "resistance_foudre",
	"resistance_arcane", "resistance_chaos", "armure", "resistance_tranchant", "resistance_perforant",
	"resistance_contondant", "resistance_spirituel", "resistance_ombre", "resistance_lumière", "degats_base",
	"pourcentage_degats_physique", "pourcentage_degats_tranchant", "pourcentage_degats_perforant",
	"pourcentage_degats_contondant", "pourcentage_degats_magique", "pourcentage_degats_feu", "pourcentage_degats_froid",
	"pourcentage_degats_foudre", "pourcentage_degats_arcane", "pourcentage_degats_chaos", "pourcentage_degats_spirituel",
	"pourcentage_degats_ombre", "pourcentage_degats_lumière"]


## Crée le héros avec ses statistiques de départ (``Personnage.__init__`` avec les valeurs par défaut).
static func nouveau(nom := "Héro") -> Personnage:
	var p := Personnage.new()
	p._initialiser(nom)
	return p


## PV de base du héros, en plus de l'endurance (Caracteristiques.PV_PAR_ENDURANCE par point) : 70 PV au départ,
## toutes les caractéristiques étant à 0 (décision de l'utilisateur, 2026-10-29 ; 100 PV avec 15 d'endurance avant).
const PV_BASE_HEROS := 70


func _initialiser(nom: String) -> void:
	# Arme de départ : rang 1, sans bonus (2026-10-30), équipée à la fin.
	var arme = GenerationObjets.generer_arme_nue()
	var d := _d
	d["nom"] = nom
	# PV : une base (PV_BASE_HEROS) + endurance × bonus_pv_par_endurance + objets et talents.
	d["points_de_vie_max"] = PV_BASE_HEROS
	d["points_de_vie"] = PV_BASE_HEROS
	# Régénérations de base, par minute d'exploration (regenerer) ; les caractéristiques s'y ajoutent.
	d["regen_de_points_de_vie"] = 5
	d["regen_de_points_de_vie_combat"] = 0
	d["mana_max"] = 10
	d["mana"] = 10
	d["regen_de_mana"] = 2
	# Toutes les caractéristiques partent de 0 (décision de l'utilisateur, 2026-10-29).
	for c in Caracteristiques.LISTE:
		d[c] = 0
	d["puissance_magique"] = 24
	d["degats_base"] = 5
	d["mult_bonus_armure_par_force"] = 1
	d["mult_bonus_resmag_par_intel"] = 1
	d["bonus_pv_par_endurance"] = Caracteristiques.PV_PAR_ENDURANCE
	d["multiplicateur_pv_max"] = 1
	d["seuil_execution"] = 0.0
	d["bonus_pourcentage_pv_max"] = 0.0
	d["bonus_pourcentage_armure"] = 0.0
	d["bonus_pourcentage_resistance_magique"] = 0.0
	d["bonus_pourcentage_mana_max"] = 0.0
	d["bonus_pourcentage_puissance_magique"] = 0.0
	d["coefficient_reduction_magique"] = 0.02
	d["bonus_pourcentage_regen_pv"] = 0.0
	d["bonus_pourcentage_regen_mana"] = 0.0
	for t in ["physique", "tranchant", "perforant", "contondant", "magique", "elementaire", "feu", "froid", "foudre",
			"arcane", "chaos", "ombre", "lumière"]:
		d["pourcentage_degats_" + t] = 1
		d["degats_" + t] = 0
	d["chance_de_toucher"] = 0.95
	d["chance_de_parer"] = 0.02
	d["armure"] = 0
	d["coefficient_reduction_armure"] = 0.02
	# Défenses en points (2 points = 1 dégât bloqué, Degats) ; vulnérabilités et résistances en pourcentage à part
	for t in ["magique", "elementaire"] + Degats.TYPES:
		d["resistance_" + t] = 0
	d["chance_esquive"] = 0.05
	d["penetration_armure"] = 0
	d["penetration_resistance"] = 0
	d["chance_de_coup_critique"] = 5 / 100.0
	d["chance_de_coup_critique_magique"] = 2.5 / 100
	d["chance_de_coup_critique_elementaire"] = 2.5 / 100  # comme le critique magique, dont il est tiré (2026-10-29)
	d["degats_critique"] = 1.65
	d["degats_critique_magiques"] = 1.40
	d["chance_de_toucher"] = 0.85
	d["chance_esquive"] = 0.05
	d["niveau"] = 1
	d["experience_combat"] = 0
	d["experience"] = 0
	d["piece_or"] = 0
	d["piece_or_combat"] = 0
	d["bonus_armure"] = 0
	for t in _TYPES_ITEM:
		d["item_" + t] = 0
	for b in ["penetration_armure", "penetration_resistance", "chance_de_coup_critique", "degats_critique", "force",
			"puissance_magique", "mana_max"]:
		d["bonus_de_" + b] = 0
	d["points_a_distribuer"] = 0
	d["points_competence_passive_a_distribuer"] = 0
	d["points_competence_a_distribuer"] = 0
	d["nouvelle_magie_a_apprendre"] = 1
	d["magies_apprises"] = []
	d["magies_disponibles"] = [Competences.creer("Boule_de_feu"), Competences.creer("Soin"),
		Competences.creer("Tempete_de_feu"), Competences.creer("Eclair")]
	Sorts.completer_catalogue(self)
	# Soin est connu dès le départ, sans point de magie
	var soin = null
	for m in d["magies_disponibles"]:
		if m.nom_classe == "Soin":
			soin = m
			break
	d["magies_disponibles"].erase(soin)
	d["magies_apprises"].append(soin)
	d["points_d_action_max"] = 1
	d["points_d_action"] = 1
	d["attaque_physique"] = true
	d["attaque_magique"] = true
	d["peut_recuperer_points_d_action"] = true
	d["points_action_recuperes_ce_tour"] = 0
	d["inventaire"] = [Arme.lance_de_test()]  # objet de test (statistiques à 100), gardé pendant le développement
	d["magie"] = true
	d["arme_equipee"] = null
	d["inventaire"].append(arme)
	d["arbre_de_talents"] = ArbreDeTalent.nouvel_arbre()
	d["points_de_talent"] = Talents.POINTS_DE_DEPART
	d["talents_picked_keys"] = {Talents.RACINE: true}
	d["statistiques"] = Statistiques.nouvelles()
	print("[Init] %s reçoit : %s" % [nom, arme.nom])
	var equipements := {}
	for cle in Objets.EMPLACEMENTS_EQUIPEMENT:
		equipements[cle] = null
	d["equipements"] = equipements
	d["competence_de_base"] = {
		"Coup_d_epee": Competences.creer("Coup_d_epee"),
		"Frénésie": Competences.creer("Frenesie"),
		"Coup_de_marteau": Competences.creer("Coup_de_marteau"),
		"Fracasser": Competences.creer("Fracasser"),
		"Coup_de_poing": Competences.creer("Coup_de_poing"),
		"Enchainement": Competences.creer("Enchainement"),
		"Coup_de_lance": Competences.creer("Coup_de_lance"),
		"Balayage": Competences.creer("Balayage"),
	}
	d["alteration"] = {}
	d["alterations_actives"] = {}
	equiper_item(arme)


func a_deja_noeud_talent(node_key) -> bool:
	return node_key != null and U.ga(self, "talents_picked_keys", {}).has(node_key)


func peut_apprendre_talent(talent_noeud) -> bool:
	var acquis: Dictionary = U.ga(self, "talents_picked_keys", {Talents.RACINE: true})
	return _d["points_de_talent"] > 0 and Talents.accessible(talent_noeud.ident, acquis)


## Apprend un talent du sphérier (bonus ajoutés une fois pour toutes).
func debloquer_talent(talent_noeud, node_key = null) -> bool:
	if node_key != null and node_key != talent_noeud.ident:
		return false
	if not peut_apprendre_talent(talent_noeud):
		return false
	talent_noeud.appliquer(self)
	_d["arbre_de_talents"].ajouter_talent(talent_noeud)
	_d["points_de_talent"] -= 1
	_d["talents_picked_keys"][talent_noeud.ident] = true
	calculer_stats()
	_d["points_de_vie"] = min(_d["points_de_vie"], _d["points_de_vie_max"])
	_d["mana"] = min(_d["mana"], _d["mana_max"])
	return true


## Recalcule les bonus dérivés des caractéristiques (retire les anciens, ajoute les nouveaux) :
## Caracteristiques.bonus, puis les bonus en pourcentage des talents.
func calculer_stats() -> void:
	_migrer_caracteristiques()
	if _d.has("bonus_sauvegardes"):
		var anciens: Dictionary = _d["bonus_sauvegardes"]
		for attr in anciens:
			set(attr, U.ga(self, attr, 0) - anciens[attr])
	var b := Caracteristiques.bonus(self, float(_d["bonus_pv_par_endurance"]) * float(_d["multiplicateur_pv_max"]))
	for attr in ["armure", "resistance_magique", "puissance_magique", "regen_de_points_de_vie", "regen_de_mana"]:
		b[attr] = b.get(attr, 0)
	for paire in [["points_de_vie_max", "bonus_pourcentage_pv_max"], ["armure", "bonus_pourcentage_armure"],
			["resistance_magique", "bonus_pourcentage_resistance_magique"], ["mana_max", "bonus_pourcentage_mana_max"],
			["regen_de_points_de_vie", "bonus_pourcentage_regen_pv"], ["regen_de_mana", "bonus_pourcentage_regen_mana"],
			["puissance_magique", "bonus_pourcentage_puissance_magique"]]:
		var attr: String = paire[0]
		var pourcentage = U.ga(self, paire[1], 0)
		if U.vrai(pourcentage):
			var supplement := int((U.ga(self, attr, 0) + b[attr]) * pourcentage)
			b[attr] += supplement
			if attr in ["points_de_vie_max", "mana_max"]:
				var cle := "points_de_vie" if attr == "points_de_vie_max" else "mana"
				b[cle] = b.get(cle, 0) + supplement
	_d["bonus_sauvegardes"] = b
	for attr in b:
		set(attr, U.ga(self, attr, 0) + b[attr])


## Partie enregistrée avant le 2026-10-29 (pas de caractéristique Mana) : ajoute ce qui manque aux nouvelles règles.
## Les caractéristiques déjà acquises sont gardées.
func _migrer_caracteristiques() -> void:
	if _d.has(Caracteristiques.MANA):
		return
	_d[Caracteristiques.MANA] = 0
	_d["chance_de_coup_critique_elementaire"] = 0.025
	if U.ga(self, "bonus_pv_par_endurance", 2) == 2:
		_d["bonus_pv_par_endurance"] = Caracteristiques.PV_PAR_ENDURANCE


## Régénération pendant l'exploration : ``regen_de_points_de_vie`` et ``regen_de_mana`` sont des quantités par minute
## réelle. Appelée à chaque image par l'écran de navigation, qui est en pause pendant les combats et les menus.
func regenerer(secondes: float) -> void:
	for paire in [["points_de_vie", "points_de_vie_max", "regen_de_points_de_vie", "reste_regen_pv"],
			["mana", "mana_max", "regen_de_mana", "reste_regen_mana"]]:
		var actuel = _d[paire[0]]
		var maximum = _d[paire[1]]
		if actuel >= maximum or not est_vivant():
			_d[paire[3]] = 0.0
			continue
		var reste: float = float(_d.get(paire[3], 0.0)) + maxf(0.0, float(U.num(self, paire[2]))) * secondes / 60.0
		var gagne := floori(reste + 1e-6)  # 0,1 s × 600 doit bien faire une minute entière
		_d[paire[3]] = maxf(0.0, reste - gagne)
		if gagne > 0:
			_d[paire[0]] = min(actuel + gagne, maximum)


## ``x // n`` de Python : entier si ``x`` est entier, plancher flottant sinon.
static func _division_entiere(x, n: int):
	if x is int:
		return int(floor(float(x) / n))
	return floor(float(x) / n)


## PV que rendrait un sort de soin lancé sur soi (formules du combat, sans critique).
func soin_estime(competence) -> int:
	var rendus := 0.0
	for r in Formules.estimer_degats(self, competence, self):
		if r[0] == "lumière":
			rendus -= r[2]
	return int(rendus * maxi(1, int(U.ga(competence, "nombre_attaque", 1))))


## Lance un sort de soin sur soi en dehors des combats ; renvoie le message pour le joueur.
func lancer_soin_hors_combat(competence) -> String:
	if U.ga(competence, "type_competence", "") != "heal":
		return "%s n'est pas un sort de soin." % competence.nom
	if _d["points_de_vie"] >= _d["points_de_vie_max"]:
		return "Vos PV sont déjà au maximum."
	if not Talents.peut_payer(self, competence):
		return "Pas assez de %s pour lancer %s." % ["PV" if Talents.paie_en_pv(self) else "mana", competence.nom]
	var soin := soin_estime(competence)
	var gratuit := Talents.payer(self, competence)
	var avant = _d["points_de_vie"]
	_d["points_de_vie"] = min(_d["points_de_vie_max"], _d["points_de_vie"] + soin)
	competence.gagner_experience(Talents.experience_competence(self))
	Statistiques.noter(self, "competences_utilisees")
	var rendus := int(_d["points_de_vie"] - avant)
	return "%s : +%d PV%s." % [competence.nom, rendus, " (sans rien dépenser)" if gratuit else ""]


func a_l_alteration(nom_alteration: String) -> bool:
	return _d["alteration"].has(nom_alteration)


func fin_alteration() -> void:
	Alterations.retirer_tout(self)


func ajouter_magie(magie) -> void:
	if not (magie in _d["magies_apprises"]):
		_d["magies_apprises"].append(magie)
	print("magie '%s' ajoutée." % magie.nom)


func restaurer_mana(quantite) -> void:
	_d["mana"] = min(_d["mana"] + quantite, _d["mana_max"])
	print("%s a restauré %s points de mana." % [_d["nom"], str(quantite)])


func recuperation_mana() -> void:
	if _d["mana"] < _d["mana_max"]:
		_d["mana"] += _d["regen_de_mana"]
		if _d["mana"] > _d["mana_max"]:
			_d["mana"] = _d["mana_max"]


func est_vivant() -> bool:
	return _d["points_de_vie"] > 0


func recuperation_points_de_vie() -> void:
	if _d["points_de_vie"] < _d["points_de_vie_max"]:
		_d["points_de_vie"] += _d["regen_de_points_de_vie"]
		if _d["points_de_vie"] > _d["points_de_vie_max"]:
			_d["points_de_vie"] = _d["points_de_vie_max"]


func restaurer_points_d_action() -> void:
	_d["points_d_action"] = _d["points_d_action_max"]


func verifier_points_d_action_suffisants(cout_action) -> bool:
	return _d["points_d_action"] >= cout_action


## Encaisse l'or gagné pendant le combat.
func recevoir_piece_or(piece_or_combat) -> void:
	_d["piece_or"] += _d["piece_or_combat"]
	print("%s a gagné %s pieces d'or." % [_d["nom"], str(piece_or_combat)])
	_d["piece_or_combat"] = 0


func recevoir_piece_or_combat(piece_or_combat) -> void:
	var gain := Talents.or_gagne(self, piece_or_combat)
	_d["piece_or_combat"] += gain
	Statistiques.noter(self, "or_gagne", gain)


func utiliser_piece_or(montant) -> void:
	if montant > 0:
		if _d["piece_or"] >= montant:
			_d["piece_or"] -= montant
			Statistiques.noter(self, "or_depense", montant)


func recevoir_experience_combat(experience_combat) -> void:
	var gain := Talents.experience_gagnee(self, experience_combat)
	_d["experience_combat"] += gain
	Statistiques.noter(self, "experience_recue", gain)


func recevoir_experience(experience_combat) -> void:
	_d["experience"] += _d["experience_combat"]
	print("%s a gagné %s points d'expérience." % [_d["nom"], str(experience_combat)])
	_d["experience_combat"] = 0
	verifier_montee_niveau()


## Monte d'autant de niveaux que l'expérience le permet (seuil 100 × niveau, expérience non consommée).
func verifier_montee_niveau() -> void:
	if not Aventure.PROGRESSION_NIVEAUX:
		return  # niveaux désactivés (donjon d'aventure, décision de l'utilisateur du 2026-10-26)
	while _d["experience"] >= 100 * _d["niveau"]:
		_d["niveau"] += 1
		_d["points_a_distribuer"] += 2
		_d["points_de_talent"] += Talents.POINTS_PAR_NIVEAU
		print("Félicitations ! Vous êtes passé au niveau %d. Vous avez %d points à distribuer." % [_d["niveau"], _d["points_a_distribuer"]])
		Ennemis.suivre_le_hero()
		if _d["niveau"] % 3 == 0:
			_d["points_competence_passive_a_distribuer"] += 1
		if _d["niveau"] % 6 == 0:
			_d["nouvelle_magie_a_apprendre"] += 1


## Dépense un point de caractéristique : 1 endurance, 2 force, 3 dextérité, 4 intelligence, 5 sagesse.
func distribuer_points(choix) -> void:
	if _d["points_a_distribuer"] <= 0:
		return
	var c := str(choix)
	if c == "1":
		_d["endurance"] += 1
	elif c == "2":
		_d["force"] += 1
	elif c == "3":
		_d["dextérité"] += 1
	elif c == "4":
		_d["intelligence"] += 1
	elif c == "5":
		_d["sagesse"] += 1
	elif c == "6":
		_d[Caracteristiques.MANA] = int(U.ga(self, Caracteristiques.MANA, 0)) + 1
	else:
		return
	_d["points_a_distribuer"] -= 1
	calculer_stats()


## Point de compétence passive : pourcentage de dégâts (1 physique +5 %... 9 lumière +15 %).
func distribuer_points_competence_passive(choix) -> bool:
	if _d["points_competence_passive_a_distribuer"] <= 0:
		return false
	var table := {"1": ["pourcentage_degats_physique", 0.05], "2": ["pourcentage_degats_tranchant", 0.08],
		"3": ["pourcentage_degats_perforant", 0.08], "4": ["pourcentage_degats_contondant", 0.08],
		"5": ["pourcentage_degats_magique", 0.05], "6": ["pourcentage_degats_feu", 0.08],
		"7": ["pourcentage_degats_foudre", 0.08], "8": ["pourcentage_degats_ombre", 0.08],
		"9": ["pourcentage_degats_lumière", 0.15]}
	var c := str(choix)
	if not table.has(c):
		return false
	_d[table[c][0]] += table[c][1]
	_d["points_competence_passive_a_distribuer"] -= 1
	return true


## Apprend une magie disponible (point de magie et prérequis du sort).
func apprendre_magie(magie) -> bool:
	if not (magie in _d["magies_disponibles"]) or _d["nouvelle_magie_a_apprendre"] <= 0:
		return false
	if not Sorts.peut_apprendre(self, magie):
		return false
	if not (magie in _d["magies_apprises"]):
		_d["magies_apprises"].append(magie)
	_d["magies_disponibles"].erase(magie)
	_d["nouvelle_magie_a_apprendre"] -= 1
	return true


func get_type_arme():
	if _d["arme_equipee"] != null:
		return _d["arme_equipee"].type_arme
	return null


## Équipe une arme, une armure ou un bijou (l'objet déjà porté revient dans l'inventaire).
func equiper_item(armure):
	var emplacement = Objets.emplacement_pour(_d["equipements"], armure)
	if emplacement == null:
		print("%s n'est pas un type d'équipement valide." % armure.nom)
		return null
	if _d["equipements"].get(emplacement) != null:
		desequiper_item(emplacement)
	_d["equipements"][emplacement] = armure
	if emplacement == "arme":
		_d["arme_equipee"] = armure
	armure.equiper()
	appliquer_bonus_item(armure)
	if armure in _d["inventaire"]:
		_d["inventaire"].erase(armure)
	print("%s équipé (%s)." % [armure.nom, emplacement])
	return emplacement


func emplacement_pour(objet):
	return Objets.emplacement_pour(_d["equipements"], objet)


func desequiper_item(type_item: String) -> void:
	var item = _d["equipements"].get(type_item)
	if item == null:
		return
	_d["equipements"][type_item] = null
	if type_item == "arme":
		_d["arme_equipee"] = null
	item.desequiper()
	retirer_bonus_item(item)
	_d["inventaire"].append(item)
	print("%s déséquipé (%s) et ajouté à l'inventaire." % [item.nom, type_item])


func retirer_bonus_item(item) -> void:
	if item is Arme or item is Armure:
		Objets.ajouter_bonus(self, item, -1)
		calculer_stats()


func appliquer_bonus_item(item) -> void:
	if item is Arme or item is Armure:
		Objets.ajouter_bonus(self, item, 1)
		calculer_stats()


## Range un objet obtenu et l'équipe aussitôt si son emplacement est vide.
func recevoir_objet(objet):
	_d["inventaire"].append(objet)
	var emplacement = emplacement_pour(objet)
	if emplacement != null and _d["equipements"].get(emplacement) == null:
		return equiper_item(objet)
	return null


func ajouter_item(item) -> void:
	var equipe = recevoir_objet(item)
	print("Item ajouté à l'inventaire : %s%s" % [item.nom, " (équipé)" if equipe else ""])


func ajouter_objet_inventaire(objet) -> void:
	var equipe = recevoir_objet(objet)
	print("%s a été ajouté à votre inventaire.%s" % [objet.nom, (" Équipé automatiquement (%s)." % equipe) if equipe else ""])


func retirer_objet_inventaire(objet) -> void:
	if objet in _d["inventaire"]:
		_d["inventaire"].erase(objet)


## Utilise un consommable de l'inventaire, désigné par son nom (1 PA).
func utiliser_objet_inventaire(nom_objet: String) -> void:
	for objet in _d["inventaire"]:
		if String(objet.nom).to_lower() == nom_objet.to_lower():
			if U.ga(objet, "type_objet", "") == "consommable":
				if _d["points_d_action"] >= 1:
					objet.utiliser(self)
					_d["points_d_action"] -= 1
					_d["inventaire"].erase(objet)
					print("🧪 Vous avez utilisé %s." % objet.nom)
				else:
					print("⚠️ Pas assez de points d'action pour utiliser un objet.")
				return
			else:
				print("❌ Cet objet n’est pas un consommable utilisable.")
				return
	print("❓ Objet non trouvé dans l’inventaire.")


## Passe le tour : restaure tous les points d'action.
func passer_son_tour() -> void:
	print("%s passe son tour." % _d["nom"])
	restaurer_points_d_action()


func _to_string() -> String:
	return "<Personnage: %s>" % _d.get("nom")
