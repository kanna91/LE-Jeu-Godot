class_name Ennemis
extends Dyn
## Classe de base des ennemis : statistiques, équipement,
## butin et intelligence artificielle (mecanique_ennemis).

const CHANCE_SOIN_IA := 1.0 / 3
const ATTAQUES_DE_SECOURS := {
	"combattant": ["Coup_d_epee"], "lancier": ["Coup_de_lance"], "archer": ["Tir"],
	"defenseur": ["Coup_de_gourdin"], "sorcier": ["Projectile_des_ombres"],
	"feticheur": ["Projectile_des_ombres"], "chaman": ["Boule_de_feu", "Projectile_des_ombres"],
}
## Orientation des objets lâchés (GenerationObjets) : guerrier physique, mage magique, chaman élémentaire.
const ORIENTATION_PAR_CLASSE := {"guerrier": "physique", "mage": "magique", "soutien": "elementaire", "soutient": "elementaire"}
## Réduction commune des dégâts des ennemis (×0,68 jusqu'au 2026-10-27) : retirée à la demande de l'utilisateur
## quand le héros est passé à 100 PV ; gardée à 1 pour pouvoir la remettre.
const MULTIPLICATEUR_DEGATS_ENNEMIS := 1.0
## Dégâts × 1,4 pour les élites et × 1,6 pour le boss (2026-11-01, × 0,8 avant).
## PV × 2,5 et × 6 depuis le 2026-11-04 (× 6 et × 14 avant) : les ennemis ordinaires ont ~3,7 fois plus de PV, les
## élites (~140 PV) et le boss (~330 PV) n'en gagnent qu'environ 1,5 fois (choix de Claude, à confirmer).
const MINI_BOSS := {"pv": 2.5, "degats": 1.4, "taille": 1.35, "pa": 1}
const BOSS := {"pv": 6.0, "degats": 1.6, "taille": 1.7, "pa": 1}
const IMAGES_GOBELINS_PAR_SOUS_CLASSE := {
	"archer": ["archer01.png", "archer02.png", "archer03.png", "archer04.png", "archer05.png"],
	"lancier": ["lancier01.png", "lancier02.png"],
	"combattant": ["combattant01.png", "combattant02.png"],
	"defenseur": ["defenseur01.png", "defenseur02.png"],
	"sorcier": ["sorcier01.png", "sorcier02.png"],
	"feticheur": ["feticheur01.png", "feticheur02.png"],
	"chaman": ["chaman01.png", "chaman02.png", "chaman03.png"],
}
const CHANCE_POTION_SOIN := 0.30

## PV max par tranche de 2 points d'endurance (héros et ennemis) : voir Caracteristiques (5 par tranche depuis le
## 2026-11-03 ; 10 par point depuis le 2026-10-29, 2 avant).
const PV_PAR_ENDURANCE := Caracteristiques.PV_PAR_ENDURANCE
## Les tables d'endurance des ennemis (Gobelin, Creatures, bonus des repos) restent écrites « 1 point = 10 PV » :
## chaque point y est multiplié par ENDURANCE_PAR_POINT_ENNEMI à la création (4 points = 2 tranches = 10 PV), pour
## que les ennemis gardent leurs PV quand l'endurance est passée à 5 PV tous les 2 points (choix de Claude,
## 2026-11-03, comme pour le mana le 2026-11-02).
const ENDURANCE_PAR_POINT_ENNEMI := 4
## Points de la caractéristique Mana des ennemis, bornes comprises (« 2 ou 3 », décision de l'utilisateur,
## 2026-10-29) : de quoi lancer leurs sorts en attendant la refonte des ennemis. Doublés le 2026-11-02 (choix de
## Claude) quand un point est passé de 10 à 5 mana, puis de nouveau le 2026-11-03 quand il faut 2 points pour 5 mana :
## les ennemis gardent leurs 20 à 30 mana.
const MANA_ENNEMIS := [8, 12]

## Bonus de caractéristiques (un par repos) appliqués à tous les ennemis créés ensuite.

static var bonus_globaux := {"niveau": 0, "force": 0, "dextérité": 0, "endurance": 0, "intelligence": 0, "sagesse": 0}


## Remplit les attributs (``Ennemis.__init__``).
func initialiser_ennemi(a: Dictionary, donjon) -> void:
	var d := _d
	d["nom"] = a["nom"]
	d["niveau"] = a["niveau"]
	d["est_deja_mort"] = false
	d["points_de_vie_max"] = a["points_de_vie_max"]
	d["points_de_vie"] = a["points_de_vie_max"]
	d["regen_de_points_de_vie"] = a.get("regen_de_points_de_vie", 0)
	d["regen_de_points_de_vie_combat"] = a.get("regen_de_points_de_vie_combat", 0)
	d["mana"] = a["mana_max"]
	d["mana_max"] = a["mana_max"]
	d["regen_de_mana"] = a.get("regen_de_mana", 0)
	for c in ["force", "dextérité", "endurance", "intelligence", "sagesse"]:
		d[c] = a[c] + bonus_globaux[c]
	d[Caracteristiques.MANA] = a.get(Caracteristiques.MANA, randi_range(MANA_ENNEMIS[0], MANA_ENNEMIS[1]))
	d["armure"] = a.get("armure", 0)
	d["coefficient_reduction_armure"] = 0.02
	d["puissance_magique"] = a.get("puissance_magique", 0)
	d["chance_de_coup_critique"] = a.get("chance_de_coup_critique", 0)
	d["degats_critique"] = a.get("degats_critique", 0)
	d["points_d_action_max"] = a["points_d_action_max"]
	d["points_d_action"] = a["points_d_action_max"]
	d["degats_base"] = a.get("degats_base", 0)
	for t in ["physique", "tranchant", "perforant", "contondant", "magique", "elementaire", "feu", "froid", "foudre",
			"arcane", "chaos", "ombre", "lumière"]:
		d["degats_" + t] = a.get("degats_" + t, 0)
	d["arme"] = a.get("arme", [])
	d["coefficient_reduction_armure"] = a.get("coefficient_reduction_armure", 0.02)
	# Défenses en points (2 points = 1 dégât bloqué, Degats) ; vulnérabilités et résistances en pourcentage à part
	for t in ["magique", "elementaire"] + Degats.TYPES:
		d["resistance_" + t] = a.get("resistance_" + t, 0)
	d["chance_esquive"] = a.get("chance_esquive", 0)
	d["chance_de_toucher"] = a.get("chance_de_toucher", 0)
	d["chance_de_parer"] = a.get("chance_de_parer", 0)
	d["donjon"] = donjon
	d["a_utilise_mecanique"] = false
	d["taux_de_loot"] = 100
	d["armure_equipee"] = null
	d["pourcentage_degats_physique"] = MULTIPLICATEUR_DEGATS_ENNEMIS
	for t in ["tranchant", "perforant", "contondant"]:
		d["pourcentage_degats_" + t] = 1
	d["pourcentage_degats_magique"] = MULTIPLICATEUR_DEGATS_ENNEMIS
	d["pourcentage_degats_elementaire"] = MULTIPLICATEUR_DEGATS_ENNEMIS
	d["taille_affichage"] = 1.0
	for t in ["feu", "froid", "foudre", "arcane", "chaos", "ombre"]:
		d["pourcentage_degats_" + t] = 1
	d["pourcentage_degats_lumière"] = 1 / MULTIPLICATEUR_DEGATS_ENNEMIS
	d["penetration_armure"] = a.get("penetration_armure", 0)
	d["penetration_resistance"] = a.get("penetration_resistance", 0)
	d["chance_de_coup_critique_magique"] = 0.025
	d["chance_de_coup_critique_elementaire"] = 0.025
	d["degats_critique_magiques"] = 1.25
	d["competences"] = a.get("competences", [])
	d["magies_apprises"] = a.get("magies_apprises", [])
	d["type_ennemi"] = a.get("type_ennemi")
	d["inventaire"] = []
	d["arme_equipee"] = null
	d["armures_equipees"] = []
	equiper_item()
	for t in Personnage._TYPES_ITEM:
		d["item_" + t] = 0
	d["magie"] = true
	d["alteration"] = {}
	d["alterations_actives"] = {}


## Recalcule les bonus dérivés des caractéristiques (mêmes règles que le héros : Caracteristiques).
func calculer_stats() -> void:
	if _d.has("bonus_sauvegardes"):
		var anciens: Dictionary = _d["bonus_sauvegardes"]
		for attr in anciens:
			set(attr, U.ga(self, attr, 0) - anciens[attr])
	var b := Caracteristiques.bonus(self)
	_d["bonus_sauvegardes"] = b
	for attr in b:
		set(attr, U.ga(self, attr, 0) + b[attr])



## Objet lâché : emplacement au hasard, orienté selon la classe de l'ennemi.
func generer_objet_butin():
	var cle: String = Objets.EMPLACEMENTS_EQUIPEMENT.pick_random()
	return GenerationObjets.generer_objet("anneau" if cle.begins_with("anneau") else cle, null, null,
		ORIENTATION_PAR_CLASSE.get(U.ga(self, "classe", null)))


func _tirer_potion(bonus := 0.0):
	if U.ga(self, "est_boss", false) or randf() < CHANCE_POTION_SOIN + bonus:
		return Consommable.creer_potion("pv", Consommable.niveau_potion_etage(), true)
	return null


## Tire au début du combat la potion du butin et la range dans l'inventaire (une seule fois).
func preparer_potion(bonus := 0.0) -> void:
	if U.ga(self, "potion_preparee", false):
		return
	_d["potion_preparee"] = true
	var potion = _tirer_potion(bonus)
	if potion != null:
		_d["inventaire"].append(potion)


## Équipe automatiquement l'inventaire : un objet par emplacement ; PV et mana remis au maximum.
func equiper_item() -> void:
	if not _d.has("emplacements_portes") or _d["emplacements_portes"] == null:
		var portes := {}
		for cle in Objets.EMPLACEMENTS_EQUIPEMENT:
			portes[cle] = null
		_d["emplacements_portes"] = portes
	var portes: Dictionary = _d["emplacements_portes"]
	for item in _d["inventaire"].duplicate():
		var cle = Objets.emplacement_pour(portes, item)
		if cle == null or portes[cle] != null:
			continue
		portes[cle] = item
		if cle == "arme":
			_d["arme_equipee"] = item
		else:
			_d["armures_equipees"].append(item)
		appliquer_bonus_item(item)
	_d["points_de_vie"] = _d["points_de_vie_max"]
	_d["mana"] = _d["mana_max"]


func retirer_bonus_item(item) -> void:
	if item is Arme or item is Armure:
		Objets.ajouter_bonus(self, item, -1)
		calculer_stats()


func appliquer_bonus_item(item) -> void:
	if item is Arme or item is Armure:
		Objets.ajouter_bonus(self, item, 1)
		calculer_stats()


## Première potion de soin (« pv » ou « mixte ») de l'inventaire.
func trouver_consommable():
	for item in _d["inventaire"]:
		if item is Consommable and U.ga(item, "effet", {}).get("type") in ["pv", "mixte"]:
			return item
	return null


## Boit un consommable (1 PA, comme le héros) puis le retire de l'inventaire.
func utiliser_consommable(consommable) -> void:
	var pv_avant = _d["points_de_vie"]
	consommable.utiliser(self)
	_d["deja_soigne"] = true
	_d["inventaire"].erase(consommable)
	_d["points_d_action"] = max(0, _d["points_d_action"] - 1)
	print("%s boit %s et récupère %s PV." % [_d["nom"], consommable.nom, U.f(_d["points_de_vie"] - pv_avant)])


## Bonus globaux aléatoires aux caractéristiques des futurs ennemis (un par repos).
static func bonus_ennemis(compteur_repos: int) -> void:
	for _i in compteur_repos:
		var c = ["force", "dextérité", "endurance", "intelligence", "sagesse"].pick_random()
		var bonus := randi_range(1, 3)
		if c == "endurance":
			bonus *= ENDURANCE_PAR_POINT_ENNEMI  # même gain de PV qu'avant le 2026-11-03
		bonus_globaux[c] += bonus
		print("Tous les nouveaux ennemis gagneront %d en %s." % [bonus, c])


func est_vivant() -> bool:
	return _d["points_de_vie"] > 0


## Traite la mort de l'ennemi (une seule fois). Les ennemis ne donnent ni expérience, ni or, ni butin (décision de
## l'utilisateur du 2026-10-26), sauf les rares qui portent un équipement (une élite : un objet garanti ; un
## porteur rend ses objets, Aventure.apres_victoire).
func mort_au_combat(donjon) -> void:
	if not _d["est_deja_mort"] and _d["points_de_vie"] <= 0:
		_d["est_deja_mort"] = true
		Statistiques.noter(donjon.personnage, "ennemis_tues")
		if U.ga(self, "est_boss", false):
			Statistiques.noter(donjon.personnage, "boss_vaincus")
		print("%s est mort." % _d["nom"])
		if U.ga(self, "butin_garanti", false):
			var objet = generer_objet_butin()
			donjon.personnage.ajouter_objet_inventaire(objet)
			print("%s a lâché %s" % [_d["nom"], objet.nom])
		lacher_butin(donjon)


## Butin réglé dans l'éditeur des ennemis (DonneesEnnemis, 2026-11-04) : chaque objet a sa chance (%) ; le héros le
## reçoit tout de suite (Fouille.ramasser). Renvoie les messages.
func lacher_butin(donjon) -> Array:
	var messages := []
	if donjon == null or donjon.personnage == null:
		return messages
	for b in DonneesEnnemis.butin_de(str(U.ga(self, "sous_classe", ""))):
		if b is Dictionary and randf() * 100.0 < float(b.get("chance", 0)):
			var m := Fouille.ramasser(b, donjon.personnage, maxi(1, Objet.compteur_etage_objet))
			messages.append(m)
			print("Butin de %s : %s" % [_d["nom"], m])
			EffetsCombat.signaler_texte(self, m.trim_prefix("Vous ramassez ").trim_suffix("."))
	return messages


func verifier_points_d_action_suffisants(cout_action) -> bool:
	return _d["points_d_action"] >= cout_action


func restaurer_points_d_action() -> void:
	_d["points_d_action"] = _d["points_d_action_max"]


## Compétence de l'ennemi d'une classe donnée (créée, mise à niveau et gardée si besoin).
func _competence(nom_classe: String):
	for competence in _d["competences"]:
		if competence.nom_classe == nom_classe:
			return competence
	var competence := Competences.creer(nom_classe)
	if competence == null:
		return null
	competence.niveau = int(U.ga(self, "niveau_competences", 0))
	_d["competences"].append(competence)
	return competence


func _utilisable(competence) -> bool:
	return (verifier_points_d_action_suffisants(competence.cout_action)
		and Talents.peut_payer(self, competence)
		and not Combat.est_bloquee_par_silence(competence, self))


## Niveau des compétences de l'ennemi (une seule fois) : 20 × (étage − 1) + 0 à 20. Il ne renforce plus les
## compétences depuis le 2026-11-03 (amélioration supprimée, à reforger par l'utilisateur).
func preparer_competences() -> void:
	if U.ga(self, "_competences_preparees", false):
		return
	_d["_competences_preparees"] = true
	var etage := maxi(1, Objet.compteur_etage_objet)
	_d["niveau_competences"] = mini(Competence.NIVEAU_MAX_COMPETENCE, 20 * (etage - 1) + randi_range(0, 20))
	var competences = U.ga(self, "competences", [])
	if competences == null:
		competences = []
	for competence in competences:
		competence.niveau = _d["niveau_competences"]


## Joue le tour de l'ennemi (intelligence artificielle).
func mecanique_ennemis(personnage, donjon, combat) -> void:
	while personnage.est_vivant() and est_vivant() and _d["points_d_action"] > 0 and not Statistiques.mort:
		if _d["points_de_vie"] <= _d["points_de_vie_max"] * 0.50 and peut_etre_soigne() and randf() < CHANCE_SOIN_IA:
			var consommable = trouver_consommable()
			if consommable != null:
				utiliser_consommable(consommable)
				continue
		var competence = null
		var cible_choisie = null
		var sous_classe = U.ga(self, "sous_classe", null)
		# Le Chevalier de la mort garde toujours sa Lame de la mort ; les autres suivent leurs règles d'IA (éditeur des
		# ennemis, DonneesEnnemis ; l'ancienne IA codée en dur y est traduite, 2026-11-04)
		if U.ga(self, "anim_combat", "") == "chevalier":
			competence = _competence("Coup_d_epee")
		else:
			var choix := choisir_par_regles(DonneesEnnemis.ia_de(str(sous_classe)), personnage, donjon)
			competence = choix[0]
			cible_choisie = choix[1]
		if competence == null or not _utilisable(competence):
			var secours: Array = ATTAQUES_DE_SECOURS.get(sous_classe, []) + ["Coup_de_baton"]
			for c in secours:
				var remplacante = _competence(c)
				if _utilisable(remplacante):
					competence = remplacante
					cible_choisie = null
					break
		if competence == null:
			print("Erreur : Aucune compétence trouvée ou utilisable.")
			return
		var cibles: Array
		if cible_choisie != null:
			cibles = [cible_choisie]
		else:
			cibles = combat.ciblage_pour_ennemis(competence, self, donjon, personnage)
		if cibles.is_empty():
			_d["points_d_action"] = 0
			break
		var pa_avant = _d["points_d_action"]
		combat.lancer(competence, self, donjon, personnage, [cible_choisie] if cible_choisie != null else null)
		if _d["points_d_action"] >= pa_avant:
			_d["points_d_action"] = 0


## Première règle d'IA qui passe (chance, conditions, compétence utilisable) : [compétence, cible ou null], ou
## [null, null] (l'attaque de secours sera jouée).
func choisir_par_regles(regles: Array, personnage, donjon) -> Array:
	for r in regles:
		if not (r is Dictionary) or randf() * 100.0 >= float(r.get("chance", 100)):
			continue
		var competence = _competence(String(r.get("competence", "")))
		if competence == null or not _utilisable(competence):
			continue
		var ok := true
		for cond in r.get("si", []):
			if cond is Array and not cond.is_empty() and not condition_ia(String(cond[0]), str(cond[1]) if cond.size() > 1 else "",
					competence, personnage, donjon):
				ok = false
				break
		if not ok:
			continue
		var cible = null
		if String(r.get("cible", "auto")) == "allie_blesse":
			cible = allie_le_plus_blesse(donjon)
		return [competence, cible]
	return [null, null]


## Une condition d'une règle d'IA (DonneesEnnemis.CONDITIONS).
func condition_ia(condition: String, valeur: String, competence, personnage, donjon) -> bool:
	var alt := Alterations.nom_canonique(valeur)
	match condition:
		"toujours", "":
			return true
		"soi_blesse":
			return _d["points_de_vie"] <= _d["points_de_vie_max"] * 0.50 and peut_etre_soigne()
		"allie_blesse":
			return allie_le_plus_blesse(donjon) != null
		"a_des_allies":
			return donjon.ennemis.any(func(e): return e != self and e.est_vivant())
		"heros_sans":
			return not personnage.a_l_alteration(alt)
		"heros_avec":
			return personnage.a_l_alteration(alt)
		"soi_sans":
			return not a_l_alteration(alt)
		"groupe_sans":
			return not donjon.ennemis.any(func(e): return e.est_vivant() and e.a_l_alteration(alt))
		"groupe_avec":
			return donjon.ennemis.any(func(e): return e.est_vivant() and e.a_l_alteration(alt))
		"heros_sans_ses_alterations":
			var noms := []
			var ta = U.ga(competence, "type_alteration", null)
			if ta is Dictionary:
				for nom in ta:
					if float(ta[nom]) > 0:
						noms.append(nom)
			return noms.is_empty() or noms.any(func(n): return not personnage.a_l_alteration(Alterations.nom_canonique(n)))
		"mana_au_moins":
			return float(_d["mana"]) >= float(valeur) if valeur.is_valid_float() else true
	return true


## Ennemi vivant (lui compris) sous la moitié de ses PV et qui peut encore être soigné, le plus blessé ; ou null.
func allie_le_plus_blesse(donjon):
	var blesses := []
	for e in donjon.ennemis:
		if e.est_vivant() and e.points_de_vie <= e.points_de_vie_max * 0.50 and e.peut_etre_soigne():
			blesses.append(e)
	if blesses.is_empty():
		return null
	return U.min_par(blesses, func(e): return e.points_de_vie / maxf(1, e.points_de_vie_max))


## Un ennemi ne peut être soigné qu'une fois par combat (potion ou compétence de soin) ; les ennemis
## sont créés pour chaque combat, la marque « deja_soigne » ne dure donc que le combat.
func peut_etre_soigne() -> bool:
	return not U.ga(self, "deja_soigne", false)


func a_l_alteration(nom_alteration: String) -> bool:
	return _d["alteration"].has(nom_alteration)


func _to_string() -> String:
	return str(_d.get("nom", "?"))
