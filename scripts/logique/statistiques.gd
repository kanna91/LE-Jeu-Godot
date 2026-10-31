class_name Statistiques
extends RefCounted
## Statistiques de la partie du héros et signal de fin de partie (statistiques.py).
##
## Le héros porte un dictionnaire ``statistiques`` (créé par nouvelles()),
## alimenté au fil du jeu par noter() ; les ennemis n'en ont pas.
##
## En Python, la mort du héros levait l'exception MortDuHeros. GDScript n'a pas
## d'exceptions : verifier_mort() lève un drapeau (``mort``) que les boucles du
## combat et de l'exploration consultent pour s'arrêter.

## (clé, libellé, format) : « entier », « or », « duree »
const COMPTEURS := [
	["ennemis_tues", "Ennemis tués", "entier"],
	["boss_vaincus", "Boss vaincus", "entier"],
	["combats_gagnes", "Combats gagnés", "entier"],
	["degats_infliges", "Dégâts infligés", "entier"],
	["plus_gros_coup", "Plus gros coup", "entier"],
	["coups_critiques", "Coups critiques", "entier"],
	["competences_utilisees", "Compétences et sorts lancés", "entier"],
	["degats_subis", "Dégâts subis", "entier"],
	["degats_absorbes_mana", "Dégâts absorbés par le mana", "entier"],
	["potions_bues", "Potions bues", "entier"],
	["or_gagne", "Or gagné", "or"],
	["or_depense", "Or dépensé", "or"],
	["experience_recue", "Expérience reçue", "entier"],
	["repos", "Repos", "entier"],
	["objets_fouilles", "Objets fouillés", "entier"],
	["fuites", "Fuites réussies", "entier"],
	["captures", "Captures par un geôlier", "entier"],
	["pacifiques_tues", "Gobelins pacifiques tués", "entier"],
	["secrets_trouves", "Cachettes trouvées", "entier"],
	["livres_lus", "Grimoires lus", "entier"],
	["pactes", "Pactes scellés", "entier"],
	["temps_de_jeu", "Temps de jeu", "duree"],
]

## Drapeau de fin de partie (équivalent de l'exception MortDuHeros).
static var mort := false
## Cause de la mort (« combat », « piège »...).
static var cause_mort := ""


## Statistiques vierges : chaque compteur à 0.
static func nouvelles() -> Dictionary:
	var stats := {}
	for c in COMPTEURS:
		stats[c[0]] = 0
	return stats


## Ajoute une valeur à un compteur du combattant (sans effet s'il n'a pas de statistiques).
static func noter(combattant, cle: String, valeur = 1) -> void:
	var stats = U.ga(combattant, "statistiques", null)
	if stats is Dictionary and U.vrai(valeur):
		stats[cle] = stats.get(cle, 0) + valeur


## Garde la plus grande valeur d'un compteur (ex. le plus gros coup).
static func noter_maximum(combattant, cle: String, valeur) -> void:
	var stats = U.ga(combattant, "statistiques", null)
	if stats is Dictionary and valeur > stats.get(cle, 0):
		stats[cle] = valeur


## Lève le drapeau de mort si les PV du héros sont tombés à 0 ou moins.
static func verifier_mort(personnage, cause := "combat") -> void:
	if personnage.points_de_vie <= 0:
		lever_mort(cause)


## Signale la mort du héros (``raise MortDuHeros(cause)``).
static func lever_mort(cause := "combat") -> void:
	if not mort:
		mort = true
		cause_mort = cause
		print("Le héros est mort (%s)" % cause)


static func _formater(valeur, genre: String) -> String:
	if genre == "duree":
		var secondes := int(valeur)
		var heures := secondes / 3600
		var reste := secondes % 3600
		if heures:
			return "%d h %02d min" % [heures, reste / 60]
		return "%d min %02d s" % [reste / 60, reste % 60]
	var texte := U.milliers(valeur)
	return texte + " PO" if genre == "or" else texte


## Statistiques de la partie, prêtes à afficher : [[libellé, valeur], ...].
static func bilan(joueur, donjon) -> Array:
	var stats = U.ga(joueur, "statistiques", {})
	if stats == null:
		stats = {}
	var etage = donjon.salle_actuelle[0]
	var salle_id = donjon.salle_actuelle[1]
	var actuelle = donjon.plan_donjon.get(etage, {}).get(str(salle_id), {})
	var explorees := 0
	var etages := []
	# La salle de départ de chaque étage est « visitée » dès sa création, et tout le donjon est créé au lancement
	# (2026-10-30) : un étage ne compte que si on y a visité une autre salle, ou si on s'y trouve (ou le premier).
	for e in donjon.plan_donjon:
		var visitees := 0
		var depart_visite := false
		for salle in donjon.plan_donjon[e].values():
			if salle.get("visitee", false):
				if salle.get("depart", false):
					depart_visite = true
				else:
					visitees += 1
		if visitees > 0 or int(e) == int(etage) or int(e) == 1:
			etages.append(e)
			explorees += visitees + (1 if depart_visite else 0)
	explorees += 0 if actuelle.get("visitee", false) else 1  # la salle où l'on se trouve
	etages.append(donjon.salle_actuelle[0])
	var lignes := [["Niveau atteint", str(joueur.niveau)],
		["Étage le plus haut", str(etages.max())],
		["Salles explorées", str(explorees)],
		["Talents appris", str(maxi(0, U.ga(joueur, "talents_picked_keys", {}).size() - 1))]]
	for c in COMPTEURS:
		lignes.append([c[1], _formater(stats.get(c[0], 0), c[2])])
	return lignes
