class_name Armure
extends Objet
## Pièce d'armure ou bijou (objets.py : Armure ; ``type_armure`` « anneau » / « amulette » pour un bijou).


static func nouvelle(nom: String, type_objet: String, type_armure: String, description := "", valeur = 0) -> Armure:
	var a := Armure.new()
	a.initialiser(nom, type_objet, description, valeur)
	a._d["type_armure"] = type_armure
	a._d["valeur"] = valeur
	a._d["regen_de_mana"] = 0
	a._d["regen_de_points_de_vie"] = 0
	a._d["equipee"] = false
	return a


## Génère une pièce d'armure (emplacement imposé, ou casque, plastron, jambières, bottes, ceinture, gants).
static func generer_armure(_type_objet := "Armure", type_armure := "", _nom := "", rang = null) -> Armure:
	if type_armure != "":
		return GenerationObjets.generer_objet(type_armure, rang)
	return GenerationObjets.generer_armure(rang)
