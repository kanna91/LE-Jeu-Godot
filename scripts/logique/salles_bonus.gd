class_name SallesBonus
extends RefCounted
## Contenu des salles bonus (logique de menu_coffre.py, menu_bonus.py et menu_soin.py).

const CHANCE_POTION_COFFRE := 0.6

# [libellé, attribut, valeur ajoutée, format (« pourcent » ou « plat »), explication]
# Armure, résistance magique et pénétrations ramenées à 4 le 2026-10-30 (10, 5, 15 et 20 avant) avec la règle
# « 2 points = 1 dégât » : proposé par Claude, validé par l'utilisateur.
const OPTIONS_BONUS := [
	["+10 % de dégâts physiques", "pourcentage_degats_physique", 0.10, "pourcent", "Multiplie tous vos dégâts physiques."],
	["+4 de pénétration d'armure", "penetration_armure", 4, "plat", "Ignore 4 points d'armure des ennemis (jusqu'à 2 dégâts de plus)."],
	["+5 % de chances de critique", "chance_de_coup_critique", 0.05, "pourcent", "Plus de coups critiques."],
	["+25 % de dégâts de feu", "pourcentage_degats_feu", 0.25, "pourcent", "Vos attaques de feu frappent plus fort."],
	["+4 d'armure", "armure", 4, "plat", "Bloque 2 dégâts physiques par coup (2 points = 1 dégât)."],
	["+4 de résistance magique", "resistance_magique", 4, "plat", "Bloque 2 dégâts d'arcane, d'ombre ou de chaos par coup."],
	["+15 % de dégâts d'arcane", "pourcentage_degats_arcane", 0.15, "pourcent", "Vos attaques d'arcane frappent plus fort."],
	["+5 % de chances d'esquive", "chance_esquive", 0.05, "pourcent", "Les ennemis vous touchent moins souvent."],
	["+15 % de dégâts critiques", "degats_critique", 0.15, "pourcent", "Vos coups critiques font plus mal."],
	["+4 de pénétration de résistance", "penetration_resistance", 4, "plat", "Ignore 4 points de résistance des ennemis (jusqu'à 2 dégâts de plus)."],
]
const POURCENTAGES_SOIN := [0.45, 0.65, 0.85]
const NOMS_SOIN := {"pv": "des PV max", "mana": "du mana max", "tout": "des PV et du mana max"}


# ---------------------------------------------------------------------------
# Coffre
# ---------------------------------------------------------------------------

## Contenu du coffre, tiré à la première ouverture : or, objet de rang étage + 1 (étage + 2 avant le 2026-10-30,
## décision de l'utilisateur), potion (60 %).
static func contenu_coffre(salle: Dictionary) -> Dictionary:
	if not salle.has("contenu"):
		# Salle verrouillée (donjon d'aventure, Aventure) : « qualite » rangs de plus et 50 % d'or en plus par rang
		var qualite := int(salle.get("qualite", 0))
		var or_gagne := int(randi_range(200, 500) * Objet.compteur_etage_objet * (1.0 + 0.5 * qualite))
		var rang := mini(Objet.compteur_etage_objet + 1 + qualite, 6)
		var objet = GenerationObjets.generer_objet(null, rang)
		var potion = Consommable.creer_potion("pv", Consommable.niveau_potion_etage()) if randf() < CHANCE_POTION_COFFRE else null
		salle["contenu"] = {"or": or_gagne, "objet": objet, "potion": potion}
		salle["coffre_ouvert"] = false
	return salle["contenu"]


## « Prendre » : or, objet (équipé si son emplacement est vide), potion ; le coffre est vidé.
static func prendre_coffre(joueur, salle: Dictionary) -> void:
	var contenu := contenu_coffre(salle)
	joueur.piece_or += contenu["or"]
	Statistiques.noter(joueur, "or_gagne", contenu["or"])
	if joueur.recevoir_objet(contenu["objet"]):
		print("%s équipé automatiquement." % contenu["objet"].nom)
	if contenu.get("potion") != null:
		joueur.inventaire.append(contenu["potion"])
	salle["coffre_ouvert"] = true
	salle["effet_utilise"] = true
	salle["image"] = "image_coffre_vide01.png"


# ---------------------------------------------------------------------------
# Bonus mystique
# ---------------------------------------------------------------------------

## Les trois bonus proposés (tirés une seule fois par salle).
static func choix_bonus(salle: Dictionary) -> Array:
	if not salle.has("choix_bonus"):
		var indices := []
		for i in OPTIONS_BONUS.size():
			indices.append(i)
		salle["choix_bonus"] = U.echantillon(indices, 3)
	var choix := []
	for i in salle["choix_bonus"]:
		choix.append(OPTIONS_BONUS[int(i)])
	return choix


static func valeur_bonus(personnage, attribut: String, mode: String) -> String:
	var v = U.ga(personnage, attribut, 0)
	return ("%s %%" % U.f(v * 100)) if mode == "pourcent" else U.g(v)


static func appliquer_bonus(personnage, salle: Dictionary, option: Array) -> void:
	personnage.set(option[1], personnage.get(option[1]) + option[2])
	salle["effet_utilise"] = true
	print("✅ Vous avez reçu : %s" % option[0])


# ---------------------------------------------------------------------------
# Source de soin
# ---------------------------------------------------------------------------

## [type, pourcentage] de la source (tirés une seule fois par salle).
static func tirer_soin(salle: Dictionary) -> Array:
	if not salle.has("soin_tirage"):
		salle["soin_tirage"] = [["pv", "mana", "tout"].pick_random(), POURCENTAGES_SOIN.pick_random()]
	return salle["soin_tirage"]


## [PV, mana] que rendrait la source (sans dépasser les maximums).
static func gains_soin(personnage, type_soin: String, pourcent: float) -> Array:
	var pv := int(personnage.points_de_vie_max * pourcent) if type_soin in ["pv", "tout"] else 0
	var mana := int(personnage.mana_max * pourcent) if type_soin in ["mana", "tout"] else 0
	pv = maxi(0, mini(pv, int(personnage.points_de_vie_max - personnage.points_de_vie)))
	mana = maxi(0, mini(mana, int(personnage.mana_max - personnage.mana)))
	return [pv, mana]


static func boire_source(personnage, salle: Dictionary) -> void:
	var tirage := tirer_soin(salle)
	var gains := gains_soin(personnage, tirage[0], tirage[1])
	personnage.points_de_vie += gains[0]
	personnage.mana += gains[1]
	var morceaux := []
	if gains[0]:
		morceaux.append("+%d PV" % gains[0])
	if gains[1]:
		morceaux.append("+%d mana" % gains[1])
	salle["soin"] = " · ".join(morceaux)
	print("✅ Soin appliqué : %s" % (salle["soin"] if salle["soin"] != "" else "déjà au maximum"))
	salle["soin_utilise"] = true
	salle["effet_utilise"] = true
