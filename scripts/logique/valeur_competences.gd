class_name ValeurCompetences
extends RefCounted
## Valeur des compétences en points : 10 points = un coup
## de l'attaque de base du lanceur de référence ; normalisation à la création.

const POINTS_PAR_ATTAQUE := 10.0
const VALEUR_PALIER := {0: 10, 1: 14, 2: 19, 3: 25, 4: 32, 5: 40}
const POINTS_PAR_MANA := 1
const POINTS_PAR_PA := 12
const PALIERS_COMPETENCES := {
	"Coup_d_epee": 0, "Coup_de_lance": 0, "Coup_de_marteau": 0, "Coup_de_poing": 0, "Boule_de_feu": 0, "Eclair": 0,
	"Fracasser": 1, "Frenesie": 2, "Enchainement": 2, "Balayage": 3, "Soin": 5,
	"Coup_de_baton": 0, "Tir": 0, "Tir_precis": 0,
	"Cri_de_guerre": 0, "Protection": 0, "Caresse_des_ombres": 0, "Silence": 0, "Précision": 0,
	"Coup_de_gourdin": 1, "Soin_mineur": 1, "Recupe": 1,
	"Rafale_de_lance": 2,
	"Grand_coup_de_gourdin": 3, "Trait_des_Ombres": 3,
	"Botte_secrete": 4, "Projectile_des_ombres": 4,
	"Perforation": 5, "Tir_empoisonne": 5, "Enflammer": 5,
}
const FACTEUR_MIN := 0.3
const FACTEUR_MAX := 2.5
const FACTEUR_MAX_RENFORT := 1.5
const LIBELLES_TYPES := {"tranchant": "tranchants", "perforant": "perforants", "contondant": "contondants", "feu": "de feu",
	"froid": "de froid", "foudre": "de foudre", "arcane": "d'arcane", "chaos": "de chaos",
	"ombre": "d'ombre", "lumière": "de lumière", "poison": "de poison"}

static var _normalisations := {}
static var _fichier_charge := false


static func palier(comp) -> int:
	var pal = U.ga(comp, "PALIER", null)
	if pal == null:
		pal = PALIERS_COMPETENCES.get(U.ga(comp, "nom_classe", ""), 0)
	return clampi(int(pal), 0, 5)


static func valeur_cible(comp) -> float:
	return VALEUR_PALIER[palier(comp)] + POINTS_PAR_MANA * comp.cout_mana + POINTS_PAR_PA * maxi(0, int(comp.cout_action) - 1)


static func unite(comp) -> float:
	var c := Equilibrage.camp(comp)
	return Equilibrage.degats_coup(c[0], Equilibrage.attaque_ref(), c[1]) / POINTS_PAR_ATTAQUE


static func en_points(comp, valeur: float) -> float:
	return valeur / unite(comp)


static func points(comp) -> float:
	var total := 0.0
	for ligne in detail(comp):
		total += ligne[1]
	return total


## Valeur de chaque attribut en points, du plus grand au plus petit : [[libellé, points], ...].
static func detail(comp) -> Array:
	var u := unite(comp)
	var lignes := {}
	for part in Equilibrage.composantes(comp):
		var genre: String = part[0]
		var cle = part[1]
		var libelle: String
		if genre == "degats":
			libelle = "Dégâts " + str(LIBELLES_TYPES.get(cle, cle))
		elif genre == "alteration":
			libelle = Alterations.libelle(cle)
		elif genre == "lanceur":
			libelle = Alterations.libelle(cle) + " (sur vous)"
		else:
			libelle = {"frappe": "Frappe supplémentaire", "execution": "Exécution", "vol": "Vol de vie",
				"soin": "Soins"}.get(genre, genre)
		lignes[libelle] = lignes.get(libelle, 0) + part[2] / u
	var liste := []
	for l in lignes:
		liste.append([l, lignes[l]])
	return U.trie_par(liste, func(x): return -x[1])


static func _plafond(nom: String, chance: float) -> float:
	var regle = BasesCompetences.CONTROLES_PLAFONNES.get(nom)
	return regle["plafond"] if regle != null else maxf(chance, BasesCompetences.PLAFOND_SPECIALITE)


static func _mettre_a_l_echelle(comp, k: float, arrondi := false) -> Dictionary:
	var chance := func(nom: String, c):
		if c >= 100:
			return c
		var nouvelle := minf(_plafond(nom, c), c * k)
		return maxf(1, round(nouvelle)) if arrondi else nouvelle
	var resultat := {}
	if comp.type_competence in ["offensif", "heal"] and U.vrai(comp.type_degats):
		var m = U.ga(comp, "multiplicateur_degats", 1.0) * k
		resultat["multiplicateur_degats"] = U.arrondi(m, 2) if arrondi else m
	var ta := {}
	for n in comp.type_alteration:
		if comp.type_alteration[n]:
			ta[n] = chance.call(n, comp.type_alteration[n])
	resultat["type_alteration"] = ta
	var al := {}
	for n in comp.alterations_lanceur:
		if comp.alterations_lanceur[n]:
			al[n] = chance.call(n, comp.alterations_lanceur[n])
	resultat["alterations_lanceur"] = al
	var puissances: Dictionary = comp.puissance_alterations.duplicate()
	if not (comp.type_competence in ["offensif", "heal"]):
		for n in comp.type_alteration:
			var c = comp.type_alteration[n]
			var defaut = Alterations.definition(Alterations.nom_canonique(n)).get("puissance")
			if c >= 100 and U.vrai(defaut):
				var p = puissances.get(n, defaut) * k
				puissances[n] = U.arrondi(p, 1) if arrondi else p
	resultat["puissance_alterations"] = puissances
	return resultat


static func _appliquer(comp, valeurs: Dictionary) -> void:
	if valeurs.has("multiplicateur_degats"):
		comp.multiplicateur_degats = valeurs["multiplicateur_degats"]
	comp.type_alteration = U.entiers(valeurs.get("type_alteration", comp.type_alteration)).duplicate()
	comp.alterations_lanceur = U.entiers(valeurs.get("alterations_lanceur", comp.alterations_lanceur)).duplicate()
	comp.puissance_alterations = U.entiers(valeurs.get("puissance_alterations", comp.puissance_alterations)).duplicate()


static func calculer_normalisation(comp) -> Dictionary:
	var cible := valeur_cible(comp)
	var valeur_k := func(k: float, arrondi := false) -> float:
		var copie_c = Equilibrage.copie_competence(comp)
		_appliquer(copie_c, _mettre_a_l_echelle(comp, k, arrondi))
		return points(copie_c)
	var avant := points(comp)
	var renfort: bool = not (comp.type_competence in ["offensif", "heal"])
	var bas := FACTEUR_MIN
	var haut := FACTEUR_MAX_RENFORT if renfort else FACTEUR_MAX
	var k: float
	if avant <= 0:
		k = 1.0
	elif valeur_k.call(haut) < cible:
		k = haut if valeur_k.call(haut) > avant * 1.01 else 1.0
	elif valeur_k.call(bas) > cible:
		k = bas
	else:
		for _i in 40:
			var milieu := sqrt(bas * haut)
			if valeur_k.call(milieu) < cible:
				bas = milieu
			else:
				haut = milieu
		k = sqrt(bas * haut)
	var resultat := _mettre_a_l_echelle(comp, k, true)
	resultat["facteur"] = U.arrondi(k, 4)
	resultat["valeur_avant"] = U.arrondi(avant, 2)
	resultat["valeur_cible"] = U.arrondi(cible, 2)
	resultat["valeur_atteinte"] = U.arrondi(valeur_k.call(k, true), 2)
	return resultat


static func _charger_fichier() -> void:
	if _fichier_charge:
		return
	_fichier_charge = true
	var donnees = U.charger_json("valeurs_competences.json")
	if donnees is Dictionary:
		_normalisations.merge(donnees)


## Donne à une compétence qui vient d'être créée sa valeur de base (fichier, cache, ou calcul).
static func normaliser(comp) -> void:
	_charger_fichier()
	var cle: String = comp.nom_classe
	if not _normalisations.has(cle):
		_normalisations[cle] = calculer_normalisation(comp)
	_appliquer(comp, _normalisations[cle])
	comp.valeur_base = _normalisations[cle]["valeur_cible"]
	_ajuster_instance(comp)


static func _ajuster_instance(comp) -> void:
	if not (comp.type_competence in ["offensif", "heal"]) or not U.vrai(comp.type_degats):
		return
	var u := unite(comp)
	var variable := 0.0
	var fixe := 0.0
	for part in Equilibrage.composantes(comp):
		if part[0] in ["alteration", "lanceur"]:
			fixe += part[2] / u
		else:
			variable += part[2] / u
	var cible: float = comp.valeur_base
	if variable <= 0 or absf(variable + fixe - cible) <= 0.02 * cible:
		return
	var facteur := maxf(FACTEUR_MIN, minf(FACTEUR_MAX, (cible - fixe) / variable))
	comp.multiplicateur_degats = U.arrondi(comp.multiplicateur_degats * facteur, 2)
