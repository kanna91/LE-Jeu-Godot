class_name Marchand
extends Dyn
## Marchand itinérant : vend, achète et rachète des objets.

const MAJORATION_ACHAT := 1.35
const RANG_MAX_LOT := 5


static func nouveau(nom := "marchand en fuite", donjon = "") -> Marchand:
	var m := Marchand.new()
	m._d["nom"] = nom
	m._d["inventaire"] = null
	m._d["donjon"] = donjon
	return m


## Nouveau stock : 2 à 4 armes, 2 à 4 armures, 1 à 3 bijoux, potions de soin et de mana, 1 à 3 potions au hasard.
func generer_inventaire() -> void:
	_d["inventaire"] = []
	for _i in randi_range(2, 4):
		_d["inventaire"].append(Arme.generer_arme())
	for _i in randi_range(2, 4):
		_d["inventaire"].append(Armure.generer_armure())
	for _i in randi_range(1, 3):
		_d["inventaire"].append(GenerationObjets.generer_bijou())
	ajouter_potion("pv", 1)
	ajouter_potion("mana", 1)
	for _i in randi_range(1, 3):
		ajouter_potion()


func ajouter_potion(type_potion = null, niveau = null) -> void:
	if type_potion == null:
		type_potion = ["pv", "mana", "mixte"].pick_random()
	if niveau == null:
		niveau = randi_range(1, 3)
	_d["inventaire"].append(Consommable.creer_potion(type_potion, niveau))


## Ouvre l'écran du marchand (stock généré à la première visite).
func menu_marchand(donjon, personnage) -> void:
	if _d["inventaire"] == null:
		generer_inventaire()
	await Ecrans.menu_marchand(U.ga(donjon, "fenetre", null), self, personnage)


## Prix de vente du marchand : valeur + 35 %, moins les talents de marchandage.
static func prix_achat(objet, acheteur = null) -> int:
	return int(objet.valeur * MAJORATION_ACHAT * Talents.facteur_prix(acheteur))


## Prix de rachat d'un objet au joueur : sa valeur.
static func prix_vente(objet) -> int:
	return int(objet.valeur)


func acheter(objet, personnage) -> bool:
	var prix := prix_achat(objet, personnage)
	if personnage.piece_or < prix:
		print("Or insuffisant.")
		return false
	if objet in _d["inventaire"]:
		personnage.piece_or -= prix
		Statistiques.noter(personnage, "or_depense", prix)
		_d["inventaire"].erase(objet)
		personnage.recevoir_objet(objet)
		print("%s a acheté %s pour %d or." % [personnage.nom, objet.nom, prix])
		return true
	print("L'objet n'est plus disponible chez le marchand.")
	return false


func racheter(objet, personnage) -> bool:
	var proposes: Array = U.ga(self, "objets_a_racheter", [])
	var prix := prix_vente(objet)
	if not (objet in proposes):
		return false
	if personnage.piece_or < prix:
		print("Or insuffisant.")
		return false
	personnage.piece_or -= prix
	Statistiques.noter(personnage, "or_depense", prix)
	proposes.erase(objet)
	personnage.recevoir_objet(objet)
	print("%s a racheté %s pour %d or." % [personnage.nom, objet.nom, prix])
	return true


func vendre(objet, personnage) -> bool:
	if objet in personnage.inventaire:
		personnage.inventaire.erase(objet)
		personnage.piece_or += prix_vente(objet)
		print("%s a vendu %s pour %d or." % [personnage.nom, objet.nom, prix_vente(objet)])
		if not personnage.possede("vente_historique"):
			personnage.vente_historique = []
		personnage.vente_historique.append(objet)
		if not possede("objets_a_racheter"):
			_d["objets_a_racheter"] = []
		_d["objets_a_racheter"].append(objet)
		return true
	print("L'objet n'est pas dans l'inventaire du joueur.")
	return false


## Équipements d'une liste qu'une vente en lot jusqu'à un rang vendrait (jamais au-delà de RANG_MAX_LOT).
static func objets_en_lot(liste: Array, rang_max: int) -> Array:
	rang_max = mini(rang_max, RANG_MAX_LOT)
	var resultat := []
	for o in liste:
		var r := int(U.num(o, "rang"))
		if not o.est_consommable() and 1 <= r and r <= rang_max:
			resultat.append(o)
	return resultat


## Vend plusieurs objets : [nombre vendu, or gagné].
func vendre_lot(liste: Array, personnage) -> Array:
	var nombre := 0
	var gain := 0
	for objet in liste.duplicate():
		var prix := prix_vente(objet)
		if vendre(objet, personnage):
			nombre += 1
			gain += prix
	return [nombre, gain]
