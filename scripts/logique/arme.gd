class_name Arme
extends Objet
## Arme équipable. Générée par GenerationObjets.


static func nouvelle(nom: String, type_objet: String, type_arme: String, description := "", valeur = 0) -> Arme:
	var a := Arme.new()
	a.initialiser(nom, type_objet, description, valeur)
	a._d["type_arme"] = type_arme
	a._d["valeur"] = valeur
	a._d["regen_de_mana"] = 0
	a._d["regen_de_points_de_vie"] = 0
	a._d["equipee"] = false
	return a


## Génère une arme aléatoire (generation_objets.generer_objet).
static func generer_arme(_type_objet := "Arme", type_arme := "", _nom := "", rang = null) -> Arme:
	return GenerationObjets.generer_objet("arme", rang, type_arme if type_arme != "" else null)


## Lance de test de l'inventaire de départ (statistiques à 100, objets.Lance) : valeurs exportées du jeu Python.
static func lance_de_test() -> Arme:
	var a := Arme.new()
	var donnees: Dictionary = U.charger_json("divers.json")["lance_test"]
	for cle in donnees:
		a._d[cle] = U.entiers(donnees[cle])
	a._d["equipee"] = false
	a._d["lance_de_test"] = true
	return a


## Vrai pour la lance de test (« god mode » de l'utilisateur pour explorer le jeu) : jamais confisquée par le geôlier.
## Reconnue aussi sans la marque (parties enregistrées avant le 2026-10-29) : rang 0 et 100 dégâts perforants.
static func est_lance_de_test(objet) -> bool:
	if objet == null:
		return false
	if U.ga(objet, "lance_de_test", false):
		return true
	return objet is Arme and int(U.ga(objet, "rang", -1)) == 0 and U.num(objet, "degats_perforant") >= 100
