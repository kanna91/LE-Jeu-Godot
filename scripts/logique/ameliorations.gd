class_name Ameliorations
extends RefCounted
## Arbres d'amélioration des compétences : 10 niveaux, 3 options équilibrées par
## niveau (puissance, technique, affliction/soutien) — ameliorations.py.
##
## Les options calculées pour chaque compétence sont lues dans
## donnees/ameliorations.json (exporté du jeu Python) ; une compétence absente du
## fichier est calculée à la volée avec Equilibrage.

const NIVEAU_MAX := 10
const GENRES_EVOLUTIFS := ["degats", "soin", "pen"]
const INTENSITE_ENNEMIS := 0.6

# Élément (« » pour aucun) → adjectif, altérations, élément secondaire, bienfait sur soi
const THEMES := {
	"tranchant": {"adj": "affûté", "alt": "saignement", "alt2": "usure", "alt3": "désarmement", "second": "ombre", "soi": "soif de sang"},
	"perforant": {"adj": "perçant", "alt": "destruction armure", "alt2": "marque", "alt3": "lenteur", "second": "foudre", "soi": "concentration"},
	"contondant": {"adj": "écrasant", "alt": "stun", "alt2": "vulnérabilité", "alt3": "trauma", "second": "froid", "soi": "protection"},
	"feu": {"adj": "ardent", "alt": "brulure", "alt2": "vulnérabilité", "alt3": "inflammabilité", "second": "chaos", "soi": "rage"},
	"froid": {"adj": "glacial", "alt": "gel", "alt2": "épuisement", "alt3": "engelure", "second": "arcane", "soi": "barrière"},
	"foudre": {"adj": "foudroyant", "alt": "électrocution", "alt2": "usure magique", "alt3": "paralysie", "second": "feu", "soi": "hâte"},
	"arcane": {"adj": "arcanique", "alt": "usure magique", "alt2": "silence", "alt3": "brûlure de mana", "second": "foudre", "soi": "clarté"},
	"chaos": {"adj": "chaotique", "alt": "corruption", "alt2": "vulnérabilité", "alt3": "peste", "second": "ombre", "soi": "soif de sang"},
	"ombre": {"adj": "ténébreux", "alt": "terreur", "alt2": "malédiction", "alt3": "siphon de vie", "second": "chaos", "soi": "évasion"},
	"": {"adj": "mystique", "alt": "affaiblissement", "alt2": "vulnérabilité", "alt3": "décrépitude", "second": "arcane", "soi": "concentration"},
}
const NOMS_VOIES := {
	"puissance": ["Élan", "Impact", "Assaut", "Ravage", "Déchaînement", "Fléau", "Carnage", "Anéantissement", "Cataclysme", "Apogée"],
	"technique": ["Geste", "Doigté", "Savoir", "Art", "Instinct", "Calcul", "Dessein", "Talent", "Génie", "Absolu"],
	"affliction": ["Présage", "Stigmate", "Tourment", "Maléfice", "Supplice", "Sortilège", "Augure", "Châtiment", "Martyre", "Néant"],
}
const NOMS_SOUTIEN := {
	"puissance": ["Souffle", "Élan", "Réconfort", "Ferveur", "Miracle", "Grâce", "Salut", "Renouveau", "Sanctuaire", "Apothéose"],
	"technique": ["Geste", "Rituel", "Savoir", "Art", "Litanie", "Psaume", "Dessein", "Talent", "Génie", "Absolu"],
	"affliction": ["Serment", "Bienfait", "Rempart", "Vœu", "Égide", "Bénédiction", "Bastion", "Hymne", "Oracle", "Firmament"],
}
const BASES := {
	"Perforation": {"alterations": {"saignement": 60}},
	"Tir_empoisonne": {"alterations": {"poison": 70, "peste": 20}},
	"Enflammer": {"alterations": {"brulure": 75, "inflammabilité": 40}},
	"Caresse_des_ombres": {"alterations": {"destruction armure": 50, "destruction résistance": 50,
		"décrépitude": 25, "esprit embrumé": 25}},
	"Silence": {"alterations": {"silence": 60, "brûlure de mana": 30}},
	"Recupe": {"alterations": {"régénération": 100}, "degats_lumière": 12, "soin_pourcentage_pv": 0.05},
	"Soin_mineur": {"degats_lumière": 15, "soin_pourcentage_pv": 0.08},
	"Soin": {"degats_lumière": 50, "soin_pourcentage_pv": 0.12},
	"Soin_majeur": {"degats_lumière": 60, "soin_pourcentage_pv": 0.20},
	"Coup_de_poing": {"alterations": {"stun": 25}},
	"Fracasser": {"alterations": {"stun": 15}},
	"Grand_coup_de_gourdin": {"alterations": {"stun": 20, "affaiblissement": 25, "trauma": 25}},
	"Coup_de_gourdin": {"alterations": {"trauma": 20}},
	"Botte_secrete": {"alterations": {"saignement": 20, "désarmement": 15}},
	"Laceration": {"alterations": {"saignement": 25}},
	"Tir_precis": {"alterations": {"marque": 30, "lenteur": 20}},
	"Rafale_de_lance": {"alterations": {"lenteur": 15}},
	"Blizzard": {"alterations": {"gel": 15, "engelure": 20, "morsure du givre": 20}},
	"Eclair": {"alterations": {"électrocution": 15, "conductivité": 20, "paralysie": 10}},
	"Tempete_de_feu": {"alterations": {"brulure": 20}},
	"Trait_des_Ombres": {"alterations": {"terreur": 15, "siphon de vie": 20}},
	"Projectile_des_ombres": {"alterations": {"corruption": 15, "condamnation": 10}},
	"Coup_de_baton": {"alterations": {"aveugler": 20, "sommeil": 10}},
	"Tir_rapide": {"alterations": {"aveugler": 15}},
	"Cri_de_guerre": {"alterations": {"rage": 100}, "nombre_attaque": 1, "nombre_cible": 6,
		"description": "Pousse un cri qui met tous les alliés en rage (+25 % de dégâts, +25 % de dégâts critiques)."},
	"Protection": {"alterations": {"protection": 100}, "nombre_attaque": 1,
		"description": "Protège un allié : dégâts physiques reçus -40 % pendant 3 tours."},
	"Précision": {"alterations": {"précis": 100, "concentration": 100}, "nombre_attaque": 1, "type_degats": [], "degats_lumière": 0,
		"description": "Aiguise la visée d'un allié : chance de toucher +35 % et de critique +15 % pendant 3 tours."},
}
const PAS_ALTERATION := [5, 15]
const PLAFOND_ALTERATION := 35
const PLAFOND_SPECIALITE := 60
const CONTROLES_PLAFONNES := {"stun": {"plafond": 35, "plafond_specialise": 50, "niveau_specialise": 9}}
const PREFERENCES := {"guerrier": [5, 3, 2], "mage": [3.5, 2.5, 4], "soutien": [3, 3, 4]}
const SOUTIENS_SOIN := ["régénération", "bouclier", "bénédiction", "clarté", "protection", "évasion", "barrière",
	"concentration", "régénération", "bouclier"]
const RENFORT_A := ["bouclier", "protection", "barrière"]
const RENFORT_B := ["concentration", "précis", "hâte", "évasion"]
const RENFORT_C := ["régénération", "épines", "soif de sang", "clarté", "bénédiction"]
const UNE_FOIS_PAR_VOIE := ["vol", "second"]
const GENRES_CHANCE := ["alt", "buff", "soi", "alt_duree", "duree_buff", "fleau"]
const LIMITES := {
	"degats": [0.5, 400, 0.5], "soin": [0.5, 400, 0.5], "mult": [0.01, 6.0, 0.01], "frappe": [0.01, 1.0, 0.01],
	"pen": [0.5, 40, 0.5], "crit": [0.01, 0.6, 0.01], "crit_combo": [0.01, 0.4, 0.01], "execution": [0.01, 3.0, 0.01],
	"alt": [5, 15, 1], "buff": [5, 15, 1], "soi": [5, 15, 1], "alt_duree": [0, 15, 1], "second": [0.05, 1.0, 0.01],
	"vol": [0.01, 0.4, 0.01], "fleau": [0, 15, 1], "maitrise": [0.01, 0.4, 0.01],
	"puissance_alt": [1, 60, 1], "duree_buff": [0, 15, 1],
}

static var _specifications := {}
static var _fichier_charge := false


static func profil(comp) -> String:
	if comp.type_competence == "heal":
		return "soin"
	if str(comp.type_competence).begins_with("renforcement"):
		return "renfort"
	return "physique" if comp.type_attaque == "physique" else "magique"


## Élément principal (premier type de dégâts), « » sans type.
static func element(comp) -> String:
	var types = comp.type_degats
	if types == null:
		return ""
	for t in types:
		if U.vrai(t):
			return t
	return ""


static func _de(elem: String) -> String:
	return {"tranchant": "tranchants", "perforant": "perforants", "contondant": "contondants", "feu": "de feu",
		"froid": "de froid", "foudre": "de foudre", "arcane": "d'arcane", "chaos": "de chaos",
		"ombre": "d'ombre", "lumière": "de lumière"}.get(elem, elem)


static func _libelle(nom: String) -> String:
	return Alterations.libelle(nom).to_lower()


static func _chance_de(nom: String) -> String:
	var texte := _libelle(nom)
	return ("d'" if texte.substr(0, 1) in "aeiouyéèêàâîôûh" else "de ") + texte


## 0.12 → « 12 », 0.015 → « 1.5 ».
static func _pct(x: float) -> String:
	if absf(x) >= 0.1:
		return U.f(x * 100, 0)
	return U.f(x * 100, 1).rstrip("0").rstrip(".")


# ---------------------------------------------------------------------------
# Effets et descriptions
# ---------------------------------------------------------------------------

## Croissance des bonus plats avec l'étage (≈ 1 ; 1,5 ; 2,2 ; 3 ; 4,1).
static func facteur_etage(etage = null) -> float:
	var e := clampi(int(Objet.compteur_etage_objet if etage == null else etage), 1, 5)
	var moyenne := func(n: int) -> float:
		var rangs := [n, n + 1] if n < 5 else [5, 6]
		var total := 0.0
		for r in rangs:
			var b: Array = GenerationObjets.BUDGETS[r]
			total += (b[0] + b[1]) / 2.0
		return total / 2.0
	return moyenne.call(e) / moyenne.call(1)


static func _evolutif(c, attribut: String, valeur: float) -> void:
	if not c.possede("bonus_evolutifs"):
		c.bonus_evolutifs = {}
	var bonus: Dictionary = c.bonus_evolutifs
	bonus[attribut] = bonus.get(attribut, 0) + valeur


## Ajuste les bonus plats des améliorations à l'étage (fonction idempotente).
static func actualiser(comp, etage = null) -> void:
	var bonus = U.ga(comp, "bonus_evolutifs", null)
	if not U.vrai(bonus):
		return
	var facteur := facteur_etage(etage)
	if not comp.possede("_evolutif_applique"):
		comp._evolutif_applique = {}
	var applique: Dictionary = comp._evolutif_applique
	for attribut in bonus:
		var voulu: float = bonus[attribut] * (facteur - 1)
		var ecart: float = voulu - applique.get(attribut, 0)
		if absf(ecart) > 1e-9:
			comp.set(attribut, U.ga(comp, attribut, 0) + ecart)
			applique[attribut] = voulu


static func _ajout(c, attribut: String, valeur) -> void:
	c.set(attribut, U.ga(c, attribut, 0) + valeur)


static func _chance(table: Dictionary, nom: String, valeur: float) -> void:
	var actuel = table.get(nom, 0)
	var nouveau := minf(100, U.arrondi(actuel + valeur, 1))
	if CONTROLES_PLAFONNES.has(nom):
		nouveau = maxf(actuel, minf(CONTROLES_PLAFONNES[nom]["plafond_specialise"], nouveau))
	table[nom] = nouveau


static func est_specialite(comp, nom: String, sur_soi := false) -> bool:
	if sur_soi:
		return nom in U.ga(comp, "bienfaits_de_base", comp.alterations_lanceur)
	if nom in U.ga(comp, "alterations_de_base", comp.type_alteration):
		return true
	if profil(comp) in ["soin", "renfort"]:
		return true
	return theme(comp)["alt"] == nom


## Chance qu'une option peut encore ajouter à une altération (plafonds).
static func marge_alteration(comp, nom: String, niveau: int, deja_accorde := 0.0, sur_soi := false) -> float:
	var table: Dictionary = comp.alterations_lanceur if sur_soi else comp.type_alteration
	var regle = CONTROLES_PLAFONNES.get(nom)
	var plafond: float
	if regle != null and not sur_soi:
		var specialise: bool = theme(comp)["alt"] == nom
		plafond = regle["plafond_specialise"] if specialise and niveau >= regle["niveau_specialise"] else regle["plafond"]
	else:
		plafond = PLAFOND_SPECIALITE if est_specialite(comp, nom, sur_soi) else PLAFOND_ALTERATION
	var reste: float = plafond - table.get(nom, 0) - deja_accorde
	return maxf(0, minf(PAS_ALTERATION[1], reste))


## Applique l'effet d'une spécification d'option (× ``intensite_ameliorations``).
static func appliquer_spec(c, spec: Dictionary) -> void:
	var intensite = U.ga(c, "intensite_ameliorations", 1.0)
	var g: String = spec["genre"]
	var v = spec.get("valeur", 0) * intensite
	if g == "degats":
		_ajout(c, "degats_" + spec["element"], v)
		_evolutif(c, "degats_" + spec["element"], v)
	elif g == "soin":
		_ajout(c, "degats_lumière", v)
		_evolutif(c, "degats_lumière", v)
	elif g == "mult":
		_ajout(c, "multiplicateur_degats", v)
	elif g == "frappe":
		c.chance_frappe_bonus = minf(1.0, c.chance_frappe_bonus + v)
	elif g == "pen":
		_ajout(c, spec["attribut"], v)
		_evolutif(c, spec["attribut"], v)
	elif g == "crit":
		_ajout(c, "bonus_critique", v)
	elif g == "crit_combo":
		_ajout(c, "bonus_critique", v)
		_ajout(c, "bonus_degats_critique", 3 * v)
	elif g == "execution":
		_ajout(c, "bonus_execution", v)
	elif g in ["alt", "buff"]:
		_chance(c.type_alteration, spec["nom"], v)
	elif g == "soi":
		_chance(c.alterations_lanceur, spec["nom"], v)
	elif g == "alt_duree":
		_chance(c.type_alteration, spec["nom"], v)
		c.duree_bonus += 1
	elif g == "second":
		# +x % aux dégâts de cet élément, seulement quand la compétence en inflige (n'ajoute pas de type).
		var pourcentages: Dictionary = U.ga(c, "pourcentage_types", {})
		pourcentages[spec["element"]] = pourcentages.get(spec["element"], 0.0) + v
		c.set("pourcentage_types", pourcentages)
	elif g == "vol":
		_ajout(c, "vol_de_vie", v)
	elif g == "fleau":
		_chance(c.type_alteration, spec["nom"], v)
		_chance(c.type_alteration, spec["nom2"], 0.7 * v)
		c.duree_bonus += 1
	elif g == "puissance_alt":
		var defaut = Alterations.definition(spec["nom"]).get("puissance", 0)
		c.puissance_alterations[spec["nom"]] = c.puissance_alterations.get(spec["nom"], defaut) + v
	elif g == "duree_buff":
		_chance(c.type_alteration, spec["nom"], v)
		c.duree_bonus += 1
	elif g == "maitrise":
		_ajout(c, spec["attribut"], U.arrondi(30 * v, 2))
		_ajout(c, "bonus_critique", v)
		_ajout(c, "bonus_execution", 2 * v)
	if U.vrai(spec.get("complement")):
		_ajout(c, "multiplicateur_degats", spec["complement"] * intensite)


## Applique une part du bonus d'une option (améliorations point par point).
static func appliquer_fraction(comp, amel: Dictionary, fraction: float, remplie: bool) -> void:
	var spec = amel.get("spec")
	if not U.vrai(spec):
		return
	var intensite = U.ga(comp, "intensite_ameliorations", 1.0)
	var duree = comp.duree_bonus
	comp.intensite_ameliorations = intensite * fraction
	appliquer_spec(comp, spec)
	comp.intensite_ameliorations = intensite
	if not remplie:
		comp.duree_bonus = duree


## Hausse relative des dégâts (ou soins) d'un coup apportée par une option.
static func _hausse_coup(comp, spec: Dictionary) -> float:
	var camp := Equilibrage.camp(comp)
	var lanceur = camp[0]
	var adversaire = camp[1]
	var soin: bool = spec["genre"] == "soin"
	var cible = lanceur if soin else adversaire
	var total := func(c) -> float:
		var s := 0.0
		for r in Formules.estimer_degats(lanceur, c, cible, false):
			if soin and r[2] < 0:
				s -= r[2]
			elif not soin and r[2] > 0:
				s += r[2]
		return s
	var avant: float = total.call(comp)
	if avant <= 0:
		return 0.0
	var copie_c = Equilibrage.copie_competence(comp)
	appliquer_spec(copie_c, spec)
	return total.call(copie_c) / avant - 1


## Décrit en clair l'effet d'une spécification d'option.
static func decrire_spec(spec: Dictionary, soin := false, comp = null) -> String:
	var g: String = spec["genre"]
	var v = spec.get("valeur", 0)
	var chance_utile: bool = spec.get("valeur_pleine", v) >= 2
	var quoi := "soins" if soin else "dégâts"
	var texte: String
	if g in ["degats", "soin"]:
		texte = ("+%s dégâts %s" % [U.g(v), _de(spec["element"])]) if g == "degats" else ("+%s PV soignés" % U.g(v))
		var hausse := _hausse_coup(comp, spec) if comp != null else 0.0
		if hausse >= 0.01:
			texte += " (≈ +%s %% par coup)" % _pct(hausse)
		texte += ", croît avec l'étage"
	elif g == "mult":
		texte = "+%s %% de %s de la compétence" % [_pct(v), quoi]
	elif g == "frappe":
		texte = "%s %% de chance de frapper une fois de plus" % _pct(v)
	elif g == "pen":
		texte = "+%s de pénétration %s, croît avec l'étage" % [U.g(v), "d’armure" if spec["attribut"] == "penetration_armure" else "de résistance"]
	elif g == "crit":
		texte = "+%s %% de chance de critique" % _pct(v)
	elif g == "crit_combo":
		texte = "+%s %% de chance de critique et +%s %% de %s critiques" % [_pct(v), _pct(3 * v), quoi]
	elif g == "execution":
		texte = "+%s %% de %s sur une cible sous 50 %% de ses PV" % [_pct(v), quoi]
	elif g == "alt":
		texte = "+%s %% de chance %s" % [U.g(v), _chance_de(spec["nom"])]
	elif g == "buff":
		texte = "%s %% de chance d'accorder %s" % [U.g(v), _libelle(spec["nom"])]
	elif g == "soi":
		texte = "%s %% de chance de vous donner %s à chaque utilisation" % [U.g(v), _libelle(spec["nom"])]
	elif g == "alt_duree":
		texte = ("+%s %% de chance %s ; altérations +1 tour" % [U.g(v), _chance_de(spec["nom"])]) if chance_utile else "Altérations +1 tour"
	elif g == "second":
		texte = "+%s %% de dégâts %s (seulement si la compétence en inflige)" % [_pct(v), _de(spec["element"])]
	elif g == "vol":
		texte = "Vol de vie : %s %% des dégâts infligés rendus en PV" % _pct(v)
	elif g == "fleau":
		if chance_utile:
			texte = "Fléau : %s +%s %%, %s +%s %%, altérations +1 tour" % [_libelle(spec["nom"]), U.g(v),
				_libelle(spec["nom2"]), U.g(U.arrondi(0.7 * v, 1))]
		else:
			texte = "Fléau : altérations +1 tour"
	elif g == "puissance_alt":
		texte = "%s renforcée : +%s de puissance" % [U.majuscule(_libelle(spec["nom"])), U.g(v)]
	elif g == "duree_buff":
		texte = "Bienfaits +1 tour, et %s %% de chance d'accorder %s" % [U.g(v), _libelle(spec["nom"])]
	elif g == "maitrise":
		texte = "Maîtrise : pénétration +%s, critique +%s %%, exécution +%s %%" % [U.g(U.arrondi(30 * v, 1)), _pct(v), _pct(2 * v)]
	else:
		texte = g
	if U.vrai(spec.get("complement")):
		texte += " (et +%s %% de %s)" % [_pct(spec["complement"]), quoi]
	return texte


## Part d'une option réellement accordée par des points investis (fraction de 0 à 1).
static func decrire_part(spec: Dictionary, fraction: float, soin := false, etage = null) -> String:
	var partielle := spec.duplicate()
	var facteur := facteur_etage(etage) if spec["genre"] in GENRES_EVOLUTIFS else 1.0
	partielle["valeur_pleine"] = spec.get("valeur", 0)
	var valeur: float = spec.get("valeur", 0) * fraction * facteur
	var plat: bool = spec["genre"] in GENRES_EVOLUTIFS or spec["genre"] in ["alt", "buff", "soi", "alt_duree", "fleau",
		"puissance_alt", "duree_buff"]
	partielle["valeur"] = U.arrondi(valeur, 1) if plat else valeur
	if U.vrai(spec.get("complement")):
		partielle["complement"] = spec["complement"] * fraction
	var texte := decrire_spec(partielle, soin).replace(", croît avec l'étage", "")
	if fraction < 1:
		texte = texte.replace("+1 tour", "+1 tour à 10/10")
	return texte


static func _option(spec: Dictionary, soin: bool, comp = null) -> Dictionary:
	return {"nom": spec.get("titre", spec.get("nom", "")), "description": decrire_spec(spec, soin, comp),
		"voie": spec["voie"], "valeur": spec.get("gain", 0), "points": spec.get("points", 0), "spec": spec,
		"debloquee": false}


# ---------------------------------------------------------------------------
# Plan des options et calibrage
# ---------------------------------------------------------------------------

static func theme(comp) -> Dictionary:
	var t: Dictionary = THEMES.get(element(comp), THEMES[""]).duplicate()
	if U.vrai(U.ga(comp, "renforcer_propres", false)):
		var base: Dictionary = U.ga(comp, "alterations_de_base", comp.type_alteration)
		var noms := []
		for n in base:
			var c = base[n]
			if 0 < c and c < 100 and Alterations.definition(n).get("nature") == "malus" and not (n in noms):
				noms.append(n)
		for n in [t["alt"], t["alt2"], t["alt3"]]:
			if not (n in noms):
				noms.append(n)
		t["alt"] = noms[0]
		t["alt2"] = noms[1]
		t["alt3"] = noms[2]
	return t


static func _plan_attaque(comp) -> Array:
	var elem := element(comp)
	var t := theme(comp)
	var pen := "penetration_armure" if profil(comp) == "physique" else "penetration_resistance"
	var second: String = t["second"] if t["second"] != elem else "arcane"
	var deg := ["degats", {"element": elem}] if elem != "" else ["mult", {}]
	var a := [deg, deg, ["mult", {}], deg, ["frappe", {}], deg, ["mult", {}], deg, deg, ["mult", {}]]
	var b := [["pen", {"attribut": pen}], ["crit", {}], ["execution", {}], ["crit_combo", {}], ["pen", {"attribut": pen}],
		["execution", {}], ["crit_combo", {}], ["pen", {"attribut": pen}], ["crit", {}], ["maitrise", {"attribut": pen}]]
	var c := [["alt", {"nom": t["alt"]}], ["alt", {"nom": t["alt2"]}], ["soi", {"nom": t["soi"]}],
		["alt_duree", {"nom": t["alt"]}], ["second", {"element": second}], ["alt", {"nom": t["alt3"]}],
		["vol", {}], ["alt_duree", {"nom": t["alt2"]}], ["alt", {"nom": t["alt"]}], ["fleau", {"nom": t["alt"], "nom2": t["alt2"]}]]
	var plan := []
	for i in NIVEAU_MAX:
		plan.append([["puissance"] + a[i], ["technique"] + b[i], ["affliction"] + c[i]])
	return plan


static func _plan_soin(_comp) -> Array:
	var a := [["soin", {}], ["soin", {}], ["mult", {}], ["soin", {}], ["mult", {}], ["soin", {}], ["mult", {}],
		["soin", {}], ["soin", {}], ["mult", {}]]
	var b := [["crit", {}], ["execution", {}], ["crit_combo", {}], ["execution", {}], ["crit_combo", {}], ["crit", {}],
		["execution", {}], ["crit_combo", {}], ["crit", {}], ["crit_combo", {}]]
	var plan := []
	for i in NIVEAU_MAX:
		plan.append([["puissance"] + a[i], ["technique"] + b[i], ["affliction", "buff", {"nom": SOUTIENS_SOIN[i]}]])
	return plan


static func _plan_renfort(comp) -> Array:
	var deja := []
	for n in comp.type_alteration:
		if comp.type_alteration[n] >= 100:
			deja.append(n)
	var choisir := func(liste: Array, i: int) -> String:
		var possibles := []
		for n in liste:
			if not (n in deja):
				possibles.append(n)
		if possibles.is_empty():
			possibles = liste
		return possibles[i % possibles.size()]
	var plan := []
	for i in NIVEAU_MAX:
		plan.append([["puissance", "buff", {"nom": choisir.call(RENFORT_A, i)}],
			["technique", "buff", {"nom": choisir.call(RENFORT_B, i)}],
			["affliction", "buff", {"nom": choisir.call(RENFORT_C, i)}]])
	return plan


static func _remplacants(comp, voie: String) -> Array:
	var p := profil(comp)
	if p == "renfort":
		var familles := {"puissance": RENFORT_A + ["régénération"], "technique": RENFORT_B + ["bénédiction"],
			"affliction": RENFORT_C + ["bouclier", "hâte"]}
		var candidats := []
		for n in familles[voie]:
			candidats.append(["buff", {"nom": n}])
		for n in comp.type_alteration:
			if comp.type_alteration[n] >= 100 and U.vrai(Alterations.definition(n).get("puissance")):
				candidats.append(["puissance_alt", {"nom": n}])
		for n in familles[voie]:
			candidats.append(["duree_buff", {"nom": n}])
		var autres := []
		for f in familles:
			for n in familles[f]:
				if not (n in familles[voie]) and not (n in autres):
					autres.append(n)
		for n in autres:
			candidats.append(["buff", {"nom": n}])
		return candidats
	if p == "soin":
		if voie == "affliction":
			var liste := []
			for n in SOUTIENS_SOIN + ["épines", "hâte", "rage"]:
				var c := ["buff", {"nom": n}]
				var deja := false
				for x in liste:
					if x[1]["nom"] == n:
						deja = true
				if not deja:
					liste.append(c)
			return liste
		return [["mult", {}], ["crit", {}], ["execution", {}]]
	var t := theme(comp)
	var pen := "penetration_armure" if p == "physique" else "penetration_resistance"
	if voie == "puissance":
		return [["mult", {}]]
	if voie == "technique":
		return [["crit", {}], ["pen", {"attribut": pen}], ["execution", {}], ["crit_combo", {}]]
	var second: String = t["second"] if t["second"] != element(comp) else "arcane"
	var propres := []
	for n in comp.type_alteration:
		var chance = comp.type_alteration[n]
		if 0 < chance and chance < 100 and not (n in [t["alt"], t["alt2"], t["alt3"]]):
			propres.append(n)
	var candidats := [["alt", {"nom": t["alt"]}], ["alt", {"nom": t["alt2"]}], ["alt", {"nom": t["alt3"]}]]
	for n in propres:
		candidats.append(["alt", {"nom": n}])
	candidats.append(["soi", {"nom": t["soi"]}])
	var durees := []
	for n in [t["alt"], t["alt2"]] + propres:
		if not (n in durees):
			durees.append(n)
	for n in durees:
		candidats.append(["alt_duree", {"nom": n}])
	return candidats + [["second", {"element": second}], ["vol", {}]]


static func _contexte(comp) -> Dictionary:
	var p := profil(comp)
	var plan: Array
	if p == "soin":
		plan = _plan_soin(comp)
	elif p == "renfort":
		plan = _plan_renfort(comp)
	else:
		plan = _plan_attaque(comp)
	var noms: Dictionary = NOMS_SOUTIEN if p in ["soin", "renfort"] else NOMS_VOIES
	var adj: String
	if p == "soin":
		adj = "radieux"
	elif p == "renfort":
		adj = "martial"
	else:
		adj = THEMES.get(element(comp), THEMES[""])["adj"]
	return {"plan": plan, "noms": noms, "adj": adj, "complement": p != "renfort"}


static func _deja_pris(comp, genre: String, params: Dictionary, cumul: Dictionary) -> bool:
	if not (genre in UNE_FOIS_PAR_VOIE):
		return false
	if U.vrai(cumul.get("__" + genre)):
		return true
	if genre == "vol":
		return comp.vol_de_vie > 0
	var types = comp.type_degats
	return types != null and params.get("element") in types


static func _options_niveau(comp, niveau: int, budget: float, contexte: Dictionary, cumul_voie: Dictionary, etat) -> Array:
	var noms: Dictionary = contexte["noms"]
	var adj: String = contexte["adj"]
	var options := []
	var deja := []
	for prevu in contexte["plan"][niveau - 1]:
		var voie: String = prevu[0]
		var budget_voie: float = budget * Equilibrage.BUDGET_VOIE.get(voie, 1.0)
		if not cumul_voie.has(voie):
			cumul_voie[voie] = {}
		var cumul: Dictionary = cumul_voie[voie]
		var meilleure = null
		var ecart_min = null
		var essais := [[prevu[1], prevu[2]]] + _remplacants(comp, voie)
		for essai in essais:
			var genre_essai: String = essai[0]
			var params_essai: Dictionary = essai[1]
			var nom_alt = params_essai.get("nom")
			if [genre_essai, nom_alt] in deja and genre_essai in ["buff", "alt", "soi"]:
				continue
			if _deja_pris(comp, genre_essai, params_essai, cumul):
				continue
			if genre_essai in ["alt", "buff", "soi"]:
				var marge := marge_alteration(comp, nom_alt, niveau, cumul.get(nom_alt, 0), genre_essai == "soi")
				if marge < PAS_ALTERATION[0]:
					continue
			var spec := _calibrer_spec(comp, voie, "%s %s" % [noms[voie][niveau - 1], adj], genre_essai, params_essai,
				budget_voie, contexte["complement"], cumul.get(nom_alt, 0) if nom_alt != null else 0, niveau, cumul, etat)
			var ecart: float = absf(spec["gain"] - budget_voie) / budget_voie
			if genre_essai == "pen" and U.vrai(spec.get("complement")):
				ecart += 0.2
			if U.vrai(spec.get("complement")) and spec["valeur"] <= LIMITES[genre_essai][0]:
				ecart += 0.25
			if ecart_min == null or ecart < ecart_min:
				meilleure = spec
				ecart_min = ecart
			if ecart <= 0.10:
				break
		if meilleure == null:
			meilleure = _calibrer_spec(comp, voie, "%s %s" % [noms[voie][niveau - 1], adj], "mult", {}, budget_voie,
				contexte["complement"], 0, 1, null, etat)
		if meilleure["genre"] in UNE_FOIS_PAR_VOIE:
			cumul["__" + meilleure["genre"]] = 1
		deja.append([meilleure["genre"], meilleure.get("nom")])
		if meilleure["genre"] in GENRES_CHANCE:
			cumul[meilleure["nom"]] = cumul.get(meilleure["nom"], 0) + meilleure["valeur"]
			if meilleure["genre"] == "fleau":
				cumul[meilleure["nom2"]] = cumul.get(meilleure["nom2"], 0) + 0.7 * meilleure["valeur"]
		options.append(meilleure)
	return options


## Les 10 × 3 options équilibrées d'une compétence.
static func calculer_specifications(comp) -> Array:
	var contexte := _contexte(comp)
	var camp := Equilibrage.camp(comp)
	var plancher := 0.5 * Equilibrage.degats_par_tour(camp[0], camp[1])
	var base := maxf(plancher, Equilibrage.valeur(comp))
	var niveaux := []
	var etat = Equilibrage.copie_competence(comp)
	var cumul_voie := {}
	for niveau in range(1, NIVEAU_MAX + 1):
		var options := _options_niveau(comp, niveau, Equilibrage.BUDGETS[niveau] * base, contexte, cumul_voie, etat)
		niveaux.append(options)
		_avancer_etat(etat, options)
	return niveaux


## Recalcule les options d'un niveau sur la compétence telle qu'elle est (héros).
static func recalibrer_niveau(comp, index: int) -> void:
	if U.ga(comp, "intensite_ameliorations", 1.0) != 1.0:
		return
	if not (0 <= index and index < comp.ameliorations_possibles.size()):
		return
	var actuelles: Array = comp.ameliorations_possibles[index]
	for o in actuelles:
		if U.vrai(o.get("debloquee")) or U.vrai(o.get("investi")):
			return
	var spec0 = actuelles[0].get("spec")
	if spec0 == null:
		spec0 = {}
	if not U.vrai(spec0.get("budget")):
		return
	var budget: float = spec0["budget"] / Equilibrage.BUDGET_VOIE.get(spec0.get("voie"), 1.0)
	var specs := _options_niveau(comp, index + 1, budget, _contexte(comp), {}, comp)
	var soin := profil(comp) == "soin"
	var nouvelles := []
	for spec in specs:
		nouvelles.append(_option(spec, soin, comp))
	comp.ameliorations_possibles[index] = nouvelles


static func _avancer_etat(etat, options: Array) -> void:
	var duree = etat.duree_bonus
	var intensite = U.ga(etat, "intensite_ameliorations", 1.0)
	etat.intensite_ameliorations = intensite / float(options.size())
	for spec in options:
		appliquer_spec(etat, spec)
	etat.intensite_ameliorations = intensite
	etat.duree_bonus = duree


static func _calibrer_spec(comp, voie: String, nom: String, genre: String, params: Dictionary, budget: float,
		complement_possible: bool, deja_accorde = 0, niveau := 1, cumul = null, etat = null) -> Dictionary:
	var spec := {"voie": voie, "titre": nom, "genre": genre}
	spec.merge(params)
	var limites: Array = LIMITES[genre]
	var mini: float = limites[0]
	var maxi: float = limites[1]
	var pas: float = limites[2]
	if genre in GENRES_CHANCE:
		var marge := marge_alteration(comp, params["nom"], niveau, deja_accorde, genre == "soi")
		if genre in ["alt", "buff", "soi"]:
			maxi = maxf(mini, marge)
		else:
			maxi = marge if marge >= PAS_ALTERATION[0] else 0.0
	if genre == "fleau":
		var c2 = cumul if cumul != null else {}
		var marge2 := marge_alteration(comp, params["nom2"], niveau, c2.get(params["nom2"], 0))
		maxi = minf(maxi, int(marge2 / 0.7) if marge2 >= PAS_ALTERATION[0] else 0)
	var spec_fixe := spec.duplicate()
	var fabrique := func(x: float) -> Callable:
		var essai := spec_fixe.duplicate()
		essai["valeur"] = x
		return func(c): appliquer_spec(c, essai)
	if etat == null:
		etat = comp
	var resultat := Equilibrage.calibrer(etat, fabrique, budget, mini, maxi, pas)
	spec["valeur"] = resultat[0]
	var gain: float = resultat[1]
	if gain < 0.9 * budget and complement_possible:
		var spec_complete := spec.duplicate()
		var fabrique_complement := func(x: float) -> Callable:
			var essai := spec_complete.duplicate()
			essai["complement"] = x
			return func(c): appliquer_spec(c, essai)
		var r2 := Equilibrage.calibrer(etat, fabrique_complement, budget, 0.0, 3.0, 0.01)
		if r2[0] > 0:
			spec["complement"] = r2[0]
			gain = r2[1]
	spec["gain"] = U.arrondi(gain, 2)
	spec["budget"] = U.arrondi(budget, 2)
	spec["points"] = U.arrondi(ValeurCompetences.en_points(comp, gain), 1)
	return spec


static func _charger_fichier() -> void:
	if _fichier_charge:
		return
	_fichier_charge = true
	var donnees = U.charger_json("ameliorations.json")
	if donnees is Dictionary:
		_specifications.merge(donnees)


## Spécifications d'options d'une compétence (fichier, cache, ou calcul).
static func specifications(comp) -> Array:
	_charger_fichier()
	var cle: String = comp.nom_classe
	if not _specifications.has(cle):
		_specifications[cle] = calculer_specifications(comp)
	return _specifications[cle]


static func generer_arbre(comp) -> Array:
	var soin := profil(comp) == "soin"
	var arbre := []
	for niveau in specifications(comp):
		var options := []
		for spec in niveau:
			options.append(_option(spec.duplicate(), soin, comp))
		arbre.append(options)
	return arbre


## Termine la création d'une compétence : corrections de base, normalisation, arbre d'amélioration.
static func preparer(comp) -> void:
	var base: Dictionary = BASES.get(comp.nom_classe, {})
	var alterations: Dictionary = base.get("alterations", {})
	for nom in alterations:
		comp.type_alteration[nom] = alterations[nom]
	for attribut in ["nombre_attaque", "nombre_cible", "type_degats", "degats_lumière", "soin_pourcentage_pv", "description"]:
		if base.has(attribut):
			comp.set(attribut, base[attribut].duplicate() if base[attribut] is Array else base[attribut])
	var nettoyees := {}
	for k in comp.type_alteration:
		if U.vrai(comp.type_alteration[k]):
			nettoyees[k] = comp.type_alteration[k]
	comp.type_alteration = nettoyees
	ValeurCompetences.normaliser(comp)
	comp.alterations_de_base = comp.type_alteration.duplicate()
	comp.bienfaits_de_base = comp.alterations_lanceur.duplicate()
	comp.ameliorations_anciennes = []
	comp.ameliorations_possibles = generer_arbre(comp)


## Fait monter une compétence d'ennemi à un niveau et répartit ses points d'amélioration.
static func niveler(comp, niveau, classe = null) -> void:
	niveau = clampi(int(niveau), 0, Competence.NIVEAU_MAX_COMPETENCE)
	var poids: Array = PREFERENCES.get(classe, [1, 1, 1])
	comp.intensite_ameliorations = INTENSITE_ENNEMIS
	while comp.niveau < niveau:
		comp.niveau += 1
		comp.set("points_amélioration", comp.lire("points_amélioration") + Competence.POINTS_PAR_NIVEAU)
	while comp.lire("points_amélioration") > 0:
		var index: int = comp.dernier_niveau_ouvert()
		if index < 0:
			break
		var options: Array = comp.ameliorations_possibles[index]
		var libres := []
		for j in options.size():
			if Competence.points_investis(options[j]) < Competence.POINTS_PAR_OPTION:
				libres.append(j)
		if libres.is_empty():
			break
		var poids_libres := []
		for j in libres:
			poids_libres.append(poids[j] if j < poids.size() else 1)
		var choix = U.choix_pondere(libres, poids_libres)
		if not comp.améliorer_compétence(choix, index, 1, false):
			break


## Options d'une compétence qui ont reçu des points : [[niveau, option], ...].
static func ameliorations_choisies(comp) -> Array:
	var liste := []
	for i in comp.ameliorations_possibles.size():
		for opt in comp.ameliorations_possibles[i]:
			if Competence.points_investis(opt) > 0:
				liste.append([i + 1, opt])
	return liste
