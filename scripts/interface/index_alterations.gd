class_name IndexAlterations
extends RefCounted
## Onglet « Altérations » du grimoire : toutes les
## altérations avec leur nature, durée, cumul, effet et les compétences qui les
## appliquent d'emblée. Filtre malus / bonus, défilement.

const HAUTEUR_CARTE := 78

static var _sources := {}

var zone: Rect2
var filtre := "Toutes"
var defilement := 0.0
var filtres := {}
var liste: Rect2
var cartes := []


## Compétences capables d'appliquer chaque altération (calculé une seule fois).
static func sources_alterations() -> Dictionary:
	if not _sources.is_empty():
		return _sources
	var defs := Alterations.defs()
	for nom in defs:
		_sources[nom] = {"base": []}
	var classes: Array = Competences.classes_de_competences() + Competences.classes_de_sorts()
	for classe in classes:
		var comp = Competences.creer(classe)
		if comp == null:
			continue
		for table in [comp.type_alteration, comp.alterations_lanceur]:
			for nom in table:
				var chance = table[nom]
				var canon := Alterations.nom_canonique(nom)
				if _sources.has(canon) and U.vrai(chance):
					_sources[canon]["base"].append("%s (%s %%)" % [comp.nom, U.g(chance)])
	return _sources


static func ligne_meta(d: Dictionary) -> String:
	var morceaux := ["Malus" if d["nature"] == "malus" else "Bonus", "%s tour(s)" % str(d["duree"])]
	if d.get("cumul_max", 1) > 1:
		morceaux.append("cumulable %s fois" % str(d["cumul_max"]))
	return " · ".join(morceaux)


func _init(z: Rect2) -> void:
	zone = z
	var x := zone.end.x - 14
	for nom in ["Bonus", "Malus", "Toutes"]:
		var r := Rect2(x - 104, zone.position.y + 8, 104, 28)
		filtres[nom] = r
		x = r.position.x - 8
	liste = Rect2(zone.position.x + 10, zone.position.y + 44, zone.size.x - 20, zone.size.y - 52)


## Altérations retenues par le filtre, malus d'abord puis par libellé.
func noms() -> Array:
	var defs := Alterations.defs()
	var tous := defs.keys()
	tous.sort_custom(func(a, b):
		var ka = [defs[a]["nature"] != "malus", defs[a]["libelle"]]
		var kb = [defs[b]["nature"] != "malus", defs[b]["libelle"]]
		if ka[0] != kb[0]:
			return kb[0]
		return ka[1] < kb[1])
	var resultat := []
	for n in tous:
		if filtre == "Toutes" or defs[n]["nature"] == ("malus" if filtre == "Malus" else "bonus"):
			resultat.append(n)
	return resultat


func evenement(ev: Dictionary) -> void:
	if ev["type"] == "molette":
		defilement -= ev["sens"] * 40
	elif ev["type"] == "clic" and ev["bouton"] == 1:
		for nom in filtres:
			if filtres[nom].has_point(ev["pos"]) and nom != filtre:
				filtre = nom
				defilement = 0


## Met à jour la liste (défilement borné, suivi de la sélection manette).
func mettre_a_jour(cle_selectionnee) -> void:
	var n := noms()
	var defilement_max := maxf(0, n.size() * HAUTEUR_CARTE - liste.size.y + 4)
	defilement = clampf(defilement, 0, defilement_max)
	cartes = []
	for i in n.size():
		cartes.append([n[i], Rect2(liste.position.x, liste.position.y + i * HAUTEUR_CARTE - defilement, liste.size.x - 12, HAUTEUR_CARTE - 6)])
	for c in cartes:
		if cle_selectionnee == ["alteration", c[0]]:
			if c[1].end.y > liste.end.y:
				defilement += c[1].end.y - liste.end.y
			elif c[1].position.y < liste.position.y:
				defilement -= liste.position.y - c[1].position.y


## Panneau, titre, filtres et ascenseur ; renvoie les zones de la manette.
func dessiner(ci: CanvasItem, souris: Vector2) -> Array:
	var defs := Alterations.defs()
	Ui.panneau(ci, zone)
	var nb_malus := 0
	for d in defs.values():
		if d["nature"] == "malus":
			nb_malus += 1
	Ui.texte(ci, "Index des altérations (%d : %d malus, %d bonus)" % [defs.size(), nb_malus, defs.size() - nb_malus],
		zone.position + Vector2(14, 12), Ui.OR, 18, true)
	for nom in filtres:
		Ui.onglet(ci, filtres[nom], nom, nom == filtre, filtres[nom].has_point(souris), 14)
	var defilement_max := maxf(0, cartes.size() * HAUTEUR_CARTE - liste.size.y + 4)
	Ui.ascenseur(ci, liste, defilement, defilement_max, liste.end.x - 6)
	var z := []
	for nom in filtres:
		z.append([["filtre", nom], filtres[nom]])
	for c in cartes:
		z.append([["alteration", c[0]], c[1]])
	return z


## Cartes des altérations (couche découpée à ``liste``).
func dessiner_cartes(ci: CanvasItem, souris: Vector2) -> void:
	var defs := Alterations.defs()
	var sources := sources_alterations()
	for c in cartes:
		var nom: String = c[0]
		var r: Rect2 = c[1]
		if r.end.y < liste.position.y or r.position.y > liste.end.y:
			continue
		var d: Dictionary = defs[nom]
		var couleur := Ui.VERT if d["nature"] == "bonus" else Ui.ROUGE
		var survol := r.has_point(souris) and liste.has_point(souris)
		Ui.rect(ci, r, Ui.LIGNE_SURVOL if survol else Ui.LIGNE, 0, 6)
		Ui.rect(ci, Rect2(r.position, Vector2(5, r.size.y)), couleur, 0, 2)
		Ui.texte(ci, d["libelle"], r.position + Vector2(14, 6), couleur, 16, true)
		Ui.texte(ci, ligne_meta(d), Vector2(r.end.x - 12, r.position.y + 8), Ui.DETAIL, 13, false, null, "topright")
		Ui.texte(ci, Alterations.description(nom), r.position + Vector2(14, 28), Ui.TEXTE, 14, false, r.size.x - 28)
		var s: Dictionary = sources.get(nom, {"base": []})
		var morceaux := []
		if not s["base"].is_empty():
			morceaux.append("D'emblée : " + ", ".join(s["base"]))
		var texte := " · ".join(morceaux) if not morceaux.is_empty() else "Aucune compétence ne l'applique pour l'instant."
		Ui.texte(ci, texte, r.position + Vector2(14, 50), Ui.DETAIL, 12, false, r.size.x - 28)
