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

## Butin posé à la main dans l'éditeur de zones (onglet « Butin », 2026-11-03) : clé « butins » du .json de la salle,
## [{x, y, categorie, objet, quantite, potion, rang}, ...] en pixels de l'image sans miroir. Il est là à chaque
## passage dans une salle qui utilise cette image (une fois par salle du plan) et se ramasse avec E.
## categorie : or, potion, arme, equipement, divers, nourriture, ingredient. objet : nom du catalogue (« » : au
## hasard ; equipement : « armure », « bijou » ou « »). quantite : or (0 : au hasard, comme un squelette) ou nombre
## d'objets. potion : pv, mana, mixte (« » : au hasard). rang : rang de l'arme ou de l'équipement (0 : selon l'étage).
## recette (2026-11-09) : recette d'amélioration d'arme (AmeliorationsArmes), apprise en la ramassant ; objet : son
## nom (« Recette d'alchimie (feu 1d3) »), « » : une que le héros ne connaît pas, au hasard.
const CATEGORIES_BUTIN := ["or", "potion", "arme", "equipement", "divers", "nourriture", "ingredient", "recette"]
const NOMS_BUTIN := {"or": "Or", "potion": "Potion", "arme": "Arme", "equipement": "Équipement", "divers": "Objet divers",
	"nourriture": "Nourriture", "ingredient": "Ingrédient", "recette": "Recette"}
## Image du butin au sol (images/objets_salles/butin_<image>.png) selon sa catégorie.
const IMAGES_BUTIN := {"or": "or", "potion": "potion"}
## Coffres et points de fouille posés dans l'éditeur de zones (2026-11-11, demande de l'utilisateur) : clés « coffres »
## et « fouilles » du .json de la salle. Coffre : {x, y, contenu} (image provisoire images/objets_salles/coffre.png en
## attendant la sienne ; il arrête le héros ; « Ouvrir (E) »). Point de fouille : {x, y, verbe, contenu}, invisible,
## posé sur un meuble peint (armoire, tonneau…) ; verbe « fouiller » ou « ouvrir » (« Fouiller (E) », « Ouvrir (E) »).
## contenu : liste de butins (mêmes réglages qu'un butin au sol, sans x ni y), tous reçus en une fois ; vide : rien.
## Chaque salle du plan les a une fois (comme le butin au sol).
const CONTENANTS := {"coffre": "coffres", "fouille": "fouilles"}
const VERBES := ["fouiller", "ouvrir"]
## Sorte de meuble d'un point de fouille (2026-11-11, demande de l'utilisateur ; clé « meuble », « divers » si absente) :
## nom dans l'éditeur, nom dans le jeu (« Fouiller la bibliothèque (E) », « Vous fouillez la bibliothèque… »).
const MEUBLES := ["bibliotheque", "tonneau", "caisse_nourriture", "alchimie", "forge", "debris", "divers"]
const NOMS_MEUBLES := {"bibliotheque": "Bibliothèque", "tonneau": "Tonneau", "caisse_nourriture": "Caisse de nourriture",
	"alchimie": "Fournitures d'alchimie", "forge": "Fournitures de forge", "debris": "Débris", "divers": "Divers"}
const MEUBLES_JEU := {"bibliotheque": "la bibliothèque", "tonneau": "le tonneau", "caisse_nourriture": "la caisse de nourriture",
	"alchimie": "les fournitures d'alchimie", "forge": "les fournitures de forge", "debris": "les débris", "divers": ""}


## Butin au hasard selon le meuble (2026-11-11, demande de l'utilisateur : « pas trop généreux ») : un point de fouille
## « hasard » tire une ligne de la table de son meuble dans ``donnees/fouilles.json`` (poids ; ligne sans catégorie =
## rien), en plus de son contenu réglé à la main. Les nouveaux points de fouille de l'éditeur sont « au hasard ».
static var _tables_meubles := {}


static func tables_meubles() -> Dictionary:
	if _tables_meubles.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://donnees/fouilles.json"))
		_tables_meubles = d.get("meubles", {}) if d is Dictionary else {}
		_tables_meubles["_charge"] = true
	return _tables_meubles


## Un butin tiré pour le meuble ``meuble`` (définition comme un butin posé ; {} : rien).
static func tirer_selon_meuble(meuble: String) -> Dictionary:
	var table = tables_meubles().get(meuble, tables_meubles().get("divers", []))
	if not (table is Array) or table.is_empty():
		return {}
	var total := 0.0
	for l in table:
		total += float(l.get("poids", 0))
	var r := randf() * total
	var ligne: Dictionary = table[-1]
	for l in table:
		r -= float(l.get("poids", 0))
		if r < 0:
			ligne = l
			break
	if not ligne.has("categorie"):
		return {}
	var b := {"categorie": String(ligne["categorie"]), "objet": String(ligne.get("objet", "")), "quantite": 0}
	if ligne.has("objets") and not ligne["objets"].is_empty():
		b["objet"] = String(ligne["objets"].pick_random())
	if ligne.has("min"):
		b["quantite"] = randi_range(int(ligne["min"]), int(ligne.get("max", ligne["min"])))
	if ligne.has("artisan"):
		b["artisan"] = String(ligne["artisan"])
	return b


## Ce que le héros fouille ou ouvre au point de fouille ``c`` (« la bibliothèque », « » pour divers).
static func nom_meuble(c: Dictionary) -> String:
	return String(MEUBLES_JEU.get(String(c.get("meuble", "divers")), ""))


## Butin posé à la main sur une image de salle (clé « butins » de son .json).
static func butins(image: String) -> Array:
	var d := SallePeinte.lire_salle(image)
	var liste = d.get("butins", [])
	return liste if liste is Array else []


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


## Loups (règle de l'utilisateur, 2026-11-04) : chaque loup du corps fouillé donne en plus 1 viande crue (ingrédient).
const VIANDE_PAR_LOUP := 1


static func fouiller_corps(joueur, donjon, pacifique: bool, membres := []) -> String:
	var viande := viande_des_loups(joueur, membres)
	var message := _fouiller_corps(joueur, donjon, pacifique)
	if viande == "":
		return message
	if message.ends_with("rien d'intéressant."):
		return "Vous fouillez le corps : %s." % viande
	return message.trim_suffix(".") + ", " + viande + "."


## Viande crue des loups parmi ``membres`` (``Aventure.membres``), donnée au héros : texte (« » s'il n'y en a pas).
static func viande_des_loups(joueur, membres: Array) -> String:
	var n := 0
	for m in membres:
		if m is Dictionary and String(m.get("sous_classe", "")) == "loup":
			n += VIANDE_PAR_LOUP
	if n == 0:
		return ""
	for _k in n:
		var o = ObjetsDivers.depuis_catalogue("Viande crue")
		if o != null:
			joueur.recevoir_objet(o)
	return "%d viande%s crue%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""]


static func _fouiller_corps(joueur, donjon, pacifique: bool) -> String:
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
			if RESULTATS.has(o.get("type", "")) or o.get("type", "") == "butin" or CONTENANTS.has(o.get("type", "")):
				gardes.append(o)  # types retirés depuis (coffre, étagère) : ils disparaissent
		salle["objets"] = gardes
		_ajouter_butins(gardes, image)
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
	_ajouter_butins(objets, image)
	salle["objets"] = objets
	salle["objets_image"] = image
	return objets


## Ajoute aux objets d'une salle le butin, les coffres et les points de fouille posés sur son image (un objet par
## pose, « fouille » : ramassé, ouvert ou fouillé) ; retire ceux qui n'existent plus. Fait à chaque affichage : ce qui
## est posé après une sauvegarde apparaît aussi.
static func _ajouter_butins(objets: Array, image: String) -> void:
	_ajouter_poses(objets, SallePeinte.lire_salle(image))


## Même chose d'après les données ``d`` d'une image de salle (clés « butins », « coffres », « fouilles »).
static func _ajouter_poses(objets: Array, d: Dictionary) -> void:
	for type in ["butin", "coffre", "fouille"]:
		var cle: String = "butins" if type == "butin" else CONTENANTS[type]
		var poses = d.get(cle, [])
		if not (poses is Array):
			poses = []
		var deja := {}
		for o in objets.duplicate():
			if o.get("type", "") != type:
				continue
			var k := int(o.get("butin", -1))
			if k < 0 or k >= poses.size() or deja.has(k):
				objets.erase(o)
			else:
				deja[k] = true
				o["definition"] = poses[k].duplicate(true)  # suit les retouches de l'éditeur
		for k in poses.size():
			if not deja.has(k):
				objets.append({"type": type, "butin": k, "fouille": false, "definition": poses[k].duplicate(true)})


## Description d'affichage d'un objet tiré (pour SallePeinte.charger) : emplacement + type + image.
static func a_afficher(objets: Array, image: String) -> Array:
	var places := emplacements(image)
	var liste := []
	var poses := butins(image)
	for o in objets:
		if CONTENANTS.has(o.get("type", "")):
			var c: Dictionary = o.get("definition", {})
			liste.append({"type": o["type"], "x": c.get("x", 0), "y": c.get("y", 0), "fouille": o.get("fouille", false),
				"objet": "coffre" if o["type"] == "coffre" else "", "verbe": String(c.get("verbe", "fouiller")),
				"meuble": String(c.get("meuble", "divers")), "nom_meuble": nom_meuble(c)})
			continue
		if o.get("type", "") == "butin":
			if int(o["butin"]) >= poses.size():
				continue
			var b: Dictionary = poses[int(o["butin"])]
			liste.append({"type": "butin", "x": b["x"], "y": b["y"], "categorie": b.get("categorie", "or"),
				"objet": "butin_%s" % IMAGES_BUTIN.get(b.get("categorie", "or"), "sac"), "fouille": o.get("fouille", false)})
			continue
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
	var etage: int = int(donjon.salle_actuelle[0])
	if objet.get("type", "") == "butin":
		return ramasser(objet.get("definition", {}), joueur, etage)
	if CONTENANTS.has(objet.get("type", "")):
		return ouvrir(objet["type"], objet.get("definition", {}), joueur, etage)
	Statistiques.noter(joueur, "objets_fouilles")
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


## Ouvre un coffre ou fouille un point de fouille (``type`` : « coffre » ou « fouille », ``c`` : sa définition) : le
## héros reçoit tout son contenu ; renvoie le message.
static func ouvrir(type: String, c: Dictionary, joueur, etage: int) -> String:
	Statistiques.noter(joueur, "objets_fouilles")
	var verbe := "ouvrir" if type == "coffre" else String(c.get("verbe", "fouiller"))
	var debut := "Vous ouvrez le coffre" if type == "coffre" else ("Vous ouvrez" if verbe == "ouvrir" else "Vous fouillez")
	if type == "fouille" and nom_meuble(c) != "":
		debut += " " + nom_meuble(c)
	var messages := []
	for b in c.get("contenu", []):
		if b is Dictionary:
			messages.append(ramasser(b, joueur, etage))
	if type == "fouille" and bool(c.get("hasard", false)):
		var tire := tirer_selon_meuble(String(c.get("meuble", "divers")))
		if not tire.is_empty():
			messages.append(ramasser(tire, joueur, etage))
	messages = messages.filter(func(m): return m != "Il n'y avait rien.")
	if messages.is_empty():
		return "%s : rien d'intéressant." % debut
	return "%s. %s" % [debut, " ".join(messages)]


## Ramasse un butin posé à la main (``b`` : sa définition, voir CATEGORIES_BUTIN) ; renvoie le message.
static func ramasser(b: Dictionary, joueur, etage: int) -> String:
	var categorie := String(b.get("categorie", "or"))
	var nom_objet := String(b.get("objet", ""))
	var quantite := maxi(0, int(b.get("quantite", 0)))
	var rang = int(b.get("rang", 0)) if int(b.get("rang", 0)) > 0 else clampi(etage, 1, 6)
	if categorie == "or":
		var gain := quantite
		if gain <= 0:
			gain = Karma.or_gagne(joueur, randi_range(OR["squelette"][0], OR["squelette"][1]) * maxi(1, etage))
		joueur.piece_or += gain
		return "Vous ramassez %d pièces d'or." % gain
	if categorie == "recette":
		return AmeliorationsArmes.apprendre(joueur, nom_objet, String(b.get("artisan", "")))
	var trouves := []
	for _i in maxi(1, quantite):
		var o = null
		match categorie:
			"potion":
				var sorte := String(b.get("potion", ""))
				o = Consommable.creer_potion(sorte if sorte in ["pv", "mana", "mixte"] else ["pv", "mana", "mixte"].pick_random(),
					Consommable.niveau_potion_etage(etage))
			"arme":
				o = GenerationObjets.generer_objet("arme", rang)
			"equipement":
				if nom_objet == "bijou":
					o = GenerationObjets.generer_bijou(rang)
				elif nom_objet == "armure":
					o = GenerationObjets.generer_armure(rang)
				else:
					o = GenerationObjets.generer_armure(rang) if randf() < 0.7 else GenerationObjets.generer_bijou(rang)
			_:
				o = ObjetsDivers.depuis_catalogue(nom_objet) if nom_objet != "" else null
				if o == null:
					o = ObjetsDivers.au_hasard(categorie)
		if o == null:
			continue
		var equipe = joueur.recevoir_objet(o)
		trouves.append(o.nom + (" (équipé)" if equipe else ""))
	if trouves.is_empty():
		return "Il n'y avait rien."
	# Objets identiques regroupés : « 3 × Pomme »
	var comptes := {}
	var ordre := []
	for t in trouves:
		if not comptes.has(t):
			ordre.append(t)
			comptes[t] = 0
		comptes[t] += 1
	var textes := []
	for t in ordre:
		textes.append(t if comptes[t] == 1 else "%d × %s" % [comptes[t], t])
	return "Vous ramassez : %s." % ", ".join(textes)
