class_name Competences
extends RefCounted
## Fabrique des compétences et des sorts à partir des données exportées du jeu Python.
##
## ``Competences.creer("Coup_d_epee")`` remplace ``Coup_d_epee()`` : les tirages
## au hasard des dégâts (``random.randint``) sont refaits à chaque création, puis la
## compétence est préparée (BasesCompetences.preparer : corrections de base et
## normalisation), comme ``__init_subclass__``.

static var _competences := {}
static var _sorts := {}
static var _ordre_sorts := []


static func _charger() -> void:
	if not _competences.is_empty():
		return
	for c in U.charger_json("competences.json"):
		_competences[c["classe"]] = c["args"]
	for s in U.charger_json("sorts.json"):
		_sorts[s["classe"]] = s
		_ordre_sorts.append(s["classe"])


## Noms de classe des sorts du grimoire, dans l'ordre des éléments puis des paliers (classes_de_sorts).
static func classes_de_sorts() -> Array:
	_charger()
	return _ordre_sorts


## Noms de classe des compétences, par ordre alphabétique.
static func classes_de_competences() -> Array:
	_charger()
	var noms := _competences.keys()
	noms.sort()
	return noms


static func _valeur(v):
	if v is Dictionary and v.has("alea"):
		return randi_range(int(v["alea"][0]), int(v["alea"][1]))
	return U.entiers(v)


## Crée une compétence ou un sort par le nom de sa classe Python.
## ``sans_editions`` : sans les réglages de l'éditeur des ennemis (pour montrer les valeurs d'origine).
static func creer(nom_classe: String, sans_editions := false) -> Competence:
	_charger()
	var demande := nom_classe
	# Nouvelle compétence de l'éditeur (DonneesEnnemis) : copie d'une compétence existante, puis ses réglages
	if not _sorts.has(nom_classe) and not _competences.has(nom_classe) and DonneesEnnemis.base_de(nom_classe) != "":
		nom_classe = DonneesEnnemis.base_de(nom_classe)
	var comp: Competence
	if _sorts.has(nom_classe):
		var s: Dictionary = _sorts[nom_classe]
		comp = Sort.new()
		comp.initialiser_sort(nom_classe, s["element"], int(s["palier"]), s["fiche"])
	elif _competences.has(nom_classe):
		var args := {}
		var brut: Dictionary = _competences[nom_classe]
		for cle in brut:
			args[cle] = _valeur(brut[cle])
		comp = Competence.new()
		comp.initialiser(nom_classe, args)
	else:
		push_error("Compétence inconnue : " + nom_classe)
		return null
	BasesCompetences.preparer(comp)
	if not sans_editions:
		DonneesEnnemis.appliquer_competence(comp, demande)  # réglages de l'éditeur des ennemis (2026-11-04)
	return comp
