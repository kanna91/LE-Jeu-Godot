class_name Fouille
extends RefCounted
## Objets à fouiller dans les salles peintes (idée 1 de IDEES_GAMEPLAY.md, règles validées le 2026-10-20).
##
## Chaque image de salle a des emplacements prévus (``donnees/objets_salles.json``, clé « emplacements » :
## sol contre un mur ou un pilier). À sa
## première visite, chaque salle du plan tire 0 à 2 objets parmi ces emplacements (``NOMBRE_OBJETS``),
## chacun d'un type permis par l'emplacement et d'une des 4 variantes d'image. Le tirage est enregistré
## dans la salle du plan (clé « objets », avec l'image pour laquelle il a été fait), donc dans la
## sauvegarde. Un objet ne se fouille qu'une fois (« fouille » : vrai) et le reste.
##
## Résultats (``RESULTATS``, en %) : squelette : 50 rien, 35 or, 15 objet qu'il portait (équipement).
## Les coffres et les étagères ont été retirés le 2026-10-20 (ils juraient avec le décor) ; ceux d'une
## ancienne sauvegarde disparaissent au chargement de la salle (``objets_salle``).

## Nombre d'objets d'une salle : {nombre : chance en %} (valeurs choisies par Claude, à ajuster).
const NOMBRE_OBJETS := {0: 30, 1: 45, 2: 25}
const VARIANTES := 4
const RESULTATS := {
	"squelette": [["rien", 50], ["or", 35], ["objet", 15]],
}
## Or trouvé : [minimum, maximum] × l'étage (valeurs choisies par Claude ; un gobelin en donne ~30).
const OR := {"squelette": [10, 30]}
const NOMS := {"squelette": "le squelette"}

static var _emplacements := {}


## Emplacements d'une image de salle : [{types, x, y, mur?}, ...] (coordonnées de l'image sans miroir).
static func emplacements(image: String) -> Array:
	if _emplacements.is_empty():
		var f := FileAccess.open("res://donnees/objets_salles.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f != null else null
		_emplacements = d.get("emplacements", {}) if d is Dictionary else {}
		_emplacements["_charge"] = true
	return _emplacements.get(image, [])


static func _tirer_pondere(table) -> Variant:
	var total := 0
	for ligne in table:
		total += int(ligne[1])
	var r := randi_range(1, total)
	for ligne in table:
		r -= int(ligne[1])
		if r <= 0:
			return ligne[0]
	return table[0][0]


## Fouille d'un corps d'ennemi vaincu (Aventure.cadavre, 2026-10-31) : comme un squelette (RESULTATS, OR) ; celui
## d'un gobelin pacifique tué rapporte moins (CORPS_PACIFIQUE : un peu d'or, parfois une potion, rarement un
## équipement). Renvoie le message.
const CORPS_PACIFIQUE := {"or": [2, 6], "potion": 0.10, "equipement": 0.02}


static func fouiller_corps(joueur, donjon, pacifique: bool) -> String:
	var etage: int = int(donjon.salle_actuelle[0])
	Statistiques.noter(joueur, "objets_fouilles")
	if pacifique:
		var trouve := []
		var gain := Karma.or_gagne(joueur, randi_range(CORPS_PACIFIQUE["or"][0], CORPS_PACIFIQUE["or"][1]) * maxi(1, etage))
		joueur.piece_or += gain
		trouve.append("%d pièces d'or" % gain)
		if randf() < CORPS_PACIFIQUE["potion"]:
			var potion := Consommable.creer_potion("pv", Consommable.niveau_potion_etage(etage))
			joueur.recevoir_objet(potion)
			trouve.append(potion.nom)
		if randf() < CORPS_PACIFIQUE["equipement"]:
			var objet = GenerationObjets.generer_objet(null, clampi(etage, 1, 6))
			joueur.recevoir_objet(objet)
			trouve.append(objet.nom)
		return "Vous fouillez le corps : " + ", ".join(trouve) + "."
	var resultat = _tirer_pondere(RESULTATS["squelette"])
	if resultat == "or":
		var gain := Karma.or_gagne(joueur, randi_range(OR["squelette"][0], OR["squelette"][1]) * maxi(1, etage))
		joueur.piece_or += gain
		return "Vous fouillez le corps : %d pièces d'or." % gain
	if resultat == "objet":
		var objet = GenerationObjets.generer_objet(null, clampi(etage, 1, 6))
		var equipe = joueur.recevoir_objet(objet)
		return "Vous fouillez le corps : %s%s." % [objet.nom, " (équipé)" if equipe else ""]
	return "Vous fouillez le corps : rien d'intéressant."


## Objets de la salle du plan ``salle`` affichée avec l'image ``image`` (tirés à la première visite).
static func objets_salle(salle: Dictionary, image: String) -> Array:
	if salle.get("objets_image", "") == image and salle.get("objets") is Array:
		var gardes := []
		for o in salle["objets"]:
			if RESULTATS.has(o.get("type", "")):
				gardes.append(o)  # types retirés depuis (coffre, étagère) : ils disparaissent
		salle["objets"] = gardes
		return gardes
	var places := emplacements(image)
	var lignes := []
	for n in NOMBRE_OBJETS:
		lignes.append([n, NOMBRE_OBJETS[n]])
	var nombre := mini(int(_tirer_pondere(lignes)), places.size())
	var indices := range(places.size())
	indices.shuffle()
	var objets := []
	for i in indices.slice(0, nombre):
		var types: Array = places[i]["types"]
		objets.append({"emplacement": i, "type": types.pick_random(), "variante": randi_range(1, VARIANTES),
			"retourne": randf() < 0.5, "fouille": false})
	salle["objets"] = objets
	salle["objets_image"] = image
	return objets


## Description d'affichage d'un objet tiré (pour SallePeinte.charger) : emplacement + type + image.
static func a_afficher(objets: Array, image: String) -> Array:
	var places := emplacements(image)
	var liste := []
	for o in objets:
		if int(o["emplacement"]) >= places.size():
			continue
		var p: Dictionary = places[int(o["emplacement"])].duplicate()
		p["type"] = o["type"]
		p["objet"] = "%s_%d" % [o["type"], int(o["variante"])]
		p["retourne"] = o.get("retourne", false)
		p["fouille"] = o.get("fouille", false)
		liste.append(p)
	return liste


## Fouille un objet : applique le résultat et renvoie le message à afficher.
static func fouiller(objet: Dictionary, joueur, donjon) -> String:
	if objet.get("fouille", false):
		return "Vous avez déjà fouillé %s." % NOMS.get(objet["type"], "cet objet")
	objet["fouille"] = true
	Statistiques.noter(joueur, "objets_fouilles")
	var etage: int = int(donjon.salle_actuelle[0])
	var genre: String = objet["type"]
	var resultat = _tirer_pondere(RESULTATS.get(genre, [["rien", 1]]))
	var nom: String = NOMS.get(genre, "l'objet")
	if resultat == "or":
		var bornes: Array = OR.get(genre, [10, 30])
		var gain := Karma.or_gagne(joueur, randi_range(bornes[0], bornes[1]) * maxi(1, etage))
		joueur.piece_or += gain
		return "Vous fouillez %s : %d pièces d'or !" % [nom, gain]
	if resultat == "objet":
		var trouve = GenerationObjets.generer_objet(null, clampi(etage, 1, 6))
		var equipe = joueur.recevoir_objet(trouve)
		return "Le squelette portait encore %s%s." % [trouve.nom, " (équipé)" if equipe else ""]
	return "Vous fouillez %s : rien d'intéressant." % nom
