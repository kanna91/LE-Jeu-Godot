class_name Consommable
extends Objet
## Objet à usage unique (potion) qui rend des PV et/ou du mana (objets.py : Consommable).
## ``effet`` : {"type": "pv" | "mana" | "mixte", "valeur": fraction du maximum}.


static func nouveau_consommable(nom: String, effet: Dictionary, description := "", valeur = 0) -> Consommable:
	var c := Consommable.new()
	c.initialiser(nom, "consommable", description, valeur)
	c._d["effet"] = effet
	return c


## Applique l'effet au personnage (la potion n'est pas retirée de l'inventaire).
func utiliser(personnage) -> void:
	var effet: Dictionary = _d["effet"]
	var t = effet["type"]
	var stats = U.ga(personnage, "statistiques", null)
	if stats is Dictionary:
		stats["potions_bues"] = stats.get("potions_bues", 0) + 1
	var v = effet["valeur"] * (1 + U.num(personnage, "talent_efficacite_potions"))
	var sans_pv := U.vrai(U.ga(personnage, "talent_sans_potion_pv", 0))
	if t == "pv":
		var gain := 0 if sans_pv else int(personnage.points_de_vie_max * v)
		personnage.points_de_vie = min(personnage.points_de_vie + gain, personnage.points_de_vie_max)
		print("🧪 Vous récupérez %d PV." % gain)
	elif t == "mana":
		var gain := int(personnage.mana_max * v)
		personnage.mana = min(personnage.mana + gain, personnage.mana_max)
		print("🔮 Vous récupérez %d mana." % gain)
	elif t == "mixte":
		var gain_pv := 0 if sans_pv else int(personnage.points_de_vie_max * v)
		var gain_mana := int(personnage.mana_max * v)
		personnage.points_de_vie = min(personnage.points_de_vie + gain_pv, personnage.points_de_vie_max)
		personnage.mana = min(personnage.mana + gain_mana, personnage.mana_max)
		print("✨ Vous récupérez %d PV et %d mana." % [gain_pv, gain_mana])


## Potion prédéfinie : « pv », « mana » ou « mixte », niveau 1 à 3.
static func creer_potion(type_potion: String, niveau: int) -> Consommable:
	var i := niveau - 1
	if type_potion == "pv":
		var pourcentage: float = [0.35, 0.45, 0.65][i]
		return nouveau_consommable("Potion de soin niv.%d" % niveau, {"type": "pv", "valeur": pourcentage},
			"Rend %d%% des PV max" % int(pourcentage * 100), [60, 150, 400][i])
	elif type_potion == "mana":
		var pourcentage: float = [0.35, 0.45, 0.65][i]
		return nouveau_consommable("Potion de mana niv.%d" % niveau, {"type": "mana", "valeur": pourcentage},
			"Rend %d%% du mana max" % int(pourcentage * 100), [60, 150, 400][i])
	elif type_potion == "mixte":
		var pourcentage: float = [0.25, 0.35, 0.45][i]
		return nouveau_consommable("Potion de régénération niv.%d" % niveau, {"type": "mixte", "valeur": pourcentage},
			"Rend %d%% PV et mana" % int(pourcentage * 100), [700, 1400, 3800][i])
	return null


## Niveau des potions trouvées à un étage : 1 (étages 1 à 3), 2 (4 à 6), 3 ensuite.
static func niveau_potion_etage(etage = null) -> int:
	var e: int = Objet.compteur_etage_objet if etage == null else int(etage)
	return maxi(1, mini(3, (e + 2) / 3))
