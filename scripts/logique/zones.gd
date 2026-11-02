class_name Zones
extends RefCounted
## Zones de l'étage et leurs ennemis (2026-11-02, demande de l'utilisateur : « que chaque zone ait son propre type
## d'ennemi, que je pourrais changer comme bon me semble »).
##
## Tout est dans ``donnees/zones.json`` (mode d'emploi dans « _lisez_moi ») : une zone = les salles dont l'image
## commence par un préfixe (« crypte »), avec ses sortes d'ennemis, ses élites et ses chances. Les salles hors zone
## suivent « defaut ». Les groupes retiennent leur zone (clé « zone_ennemis » de la présence) : ``Aventure.membres`` tire
## leurs ennemis d'après elle, même s'ils sortent de leur zone pour poursuivre le héros.
##
## Première zone (décision de l'utilisateur) : les cryptes, regroupées en un seul quartier (PlanSalles.quartier_cryptes),
## n'ont que des squelettes, plus une seule élite : un féticheur.

## Classe de chaque sous-classe de gobelin (sortes possibles des tables « ennemis » et « elites »).
const CLASSES_GOBELINS := {"archer": "guerrier", "combattant": "guerrier", "lancier": "guerrier",
	"defenseur": "guerrier", "sorcier": "mage", "feticheur": "mage", "chaman": "soutien"}
## Valeurs de secours si zones.json manque (= le jeu d'avant le 2026-11-02).
const DEFAUT := {"nom": "Reste de l'étage", "ennemis": {"gobelin": 75, "squelette": 25}, "elites": {"gobelin": 1},
	"suite_elite": {"gobelin": 1}, "nombre_elites": null, "chance_elite": 0.12, "chance_pacifique": 0.15, "chance_loup": 0.5, "chance_feticheur": 0.2,
	"sans_ennemis": false}

static var _donnees := {}


static func donnees() -> Dictionary:
	if _donnees.is_empty():
		var lu = U.charger_json("zones.json")
		_donnees = lu if lu is Dictionary else {"defaut": DEFAUT, "zones": {}}
	return _donnees


## Identifiants des zones (sans « defaut »).
static func liste() -> Array:
	var ids: Array = donnees().get("zones", {}).keys()
	ids.sort()
	return ids


## Réglages complets d'une zone (``""`` ou inconnue : « defaut ») ; les champs absents viennent de « defaut ».
static func reglages(zone: String) -> Dictionary:
	var r: Dictionary = DEFAUT.duplicate(true)
	r.merge(donnees().get("defaut", {}), true)
	if zone != "" and donnees().get("zones", {}).has(zone):
		r.merge(donnees()["zones"][zone], true)
	return r


## Zone d'une image de salle (``""`` : hors zone).
static func zone_image(image: String) -> String:
	if image == "":
		return ""
	for id in liste():
		var prefixe := String(donnees()["zones"][id].get("images", ""))
		if prefixe != "" and image.begins_with(prefixe):
			return id
	return ""


## Zone d'une salle du plan, d'après son image.
static func zone_salle(salle: Dictionary) -> String:
	return zone_image(String(salle.get("salle_peinte", {}).get("image", "")))


## Refuge (« sans_ennemis » : la cuisine, décision de l'utilisateur du 2026-11-02) : aucun ennemi n'y est posé ni n'y
## entre ; seuls les personnages neutres y vont.
static func refuge(salle: Dictionary) -> bool:
	return bool(reglages(zone_salle(salle)).get("sans_ennemis", false))


## Vrai si la zone fixe elle-même son nombre d'élites (aucune élite de plus ne doit y apparaître).
static func elites_fixes(zone: String) -> bool:
	return reglages(zone).get("nombre_elites") != null


## Tirage pondéré d'une sorte dans une table {sorte: poids}.
static func tirer(table: Dictionary) -> String:
	var total := 0.0
	for s in table:
		total += maxf(0.0, float(table[s]))
	if total <= 0.0:
		return "gobelin"
	var t := randf() * total
	for s in table:
		t -= maxf(0.0, float(table[s]))
		if t < 0.0:
			return String(s)
	return String(table.keys().back())


## Un membre de groupe ({classe, sous_classe, image}) de la sorte ``sorte`` (« gobelin » : classe au hasard).
static func membre(sorte: String) -> Dictionary:
	if Creatures.est_creature(sorte):
		return Creatures.membre(sorte)
	var cs: Array = [CLASSES_GOBELINS[sorte], sorte] if CLASSES_GOBELINS.has(sorte) else Gobelin.definir_classe_gobelin()
	return {"classe": cs[0], "sous_classe": cs[1],
		"image": Ennemis.IMAGES_GOBELINS_PAR_SOUS_CLASSE.get(cs[1], ["gobelin_defaut.png"]).pick_random()}


## Vrai si la sorte est un gobelin (« gobelin » ou une classe de gobelin).
static func est_gobelin(sorte: String) -> bool:
	return sorte == "gobelin" or CLASSES_GOBELINS.has(sorte)
