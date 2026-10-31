class_name Talents
extends RefCounted
## Talents du héros : le sphérier et les effets des talents en combat (talent.py).
##
## Le sphérier (nœuds, liens, amas, parties des talents clés) est construit par
## le jeu Python et exporté dans donnees/talents.json (outils/exporter_donnees.py) :
## mêmes identifiants, mêmes positions, mêmes bonus.

const POINTS_DE_DEPART := 0
const POINTS_PAR_NIVEAU := 1
const RACINE := "eveil"
const BRANCHES := ["Dégâts", "Défense", "Utilitaire"]
const PHYSIQUES := ["tranchant", "perforant", "contondant"]
const MAGIQUES := ["feu", "froid", "foudre", "arcane", "chaos", "ombre"]
const SEUIL_CIBLE_FAIBLE := 0.35
const PLAFOND_REDUCTION := 0.5
const PLAFOND_GRATUIT := 0.25
const PV_PAR_MANA := 4
const PLAFOND_VOL_DE_VIE := 0.75
const MANA_CRITIQUE_MAGIQUE := 0.10
const MANA_PAR_PV := 5
const MANA_PAR_PV_MIN := 1
const PLAFOND_IGNORE_ARMURE := 0.75
const ALTERATIONS_ATTAQUE := {"poison": "talent_chance_poison", "brulure": "talent_attaque_brulure",
	"saignement": "talent_attaque_saignement", "vulnérabilité": "talent_attaque_vulnerabilite",
	"affaiblissement": "talent_attaque_affaiblissement", "marque": "talent_attaque_marque",
	"terreur": "talent_attaque_terreur", "malédiction": "talent_attaque_malediction",
	"aveugler": "talent_attaque_aveuglement", "stun": "talent_attaque_stun"}
const ALTERATIONS_PAR_TYPE := {
	"tranchant": ["saignement", "talent_chance_saignement"],
	"perforant": ["destruction armure", "talent_chance_destruction_armure"],
	"contondant": ["stun", "talent_chance_stun"],
	"feu": ["brulure", "talent_chance_brulure"],
	"froid": ["gel", "talent_chance_gel"],
	"foudre": ["électrocution", "talent_chance_electrocution"],
}
const DEGATS_DOT := {"poison": "talent_degats_poison", "saignement": "talent_degats_saignement",
	"brulure": "talent_degats_brulure"}
const SOURCES_AJOUT := {"physique": PHYSIQUES, "magique": MAGIQUES}
const PAIRES_CRITIQUES := {
	"chance_de_coup_critique": ["chance_de_coup_critique_magique", "+{v} % de chance de coup critique (+{m} % magique)"],
	"degats_critique": ["degats_critique_magiques", "+{v} % de dégâts critiques (+{m} % magiques)"],
}

## Sphérier : {"noeuds": {ident: Talent}, "liens": [[a, b]], "amas": [...], "parties": {ident: [idents]}, "voisins": {ident: {voisin: true}}}
static var _spherier := {}
static var _libelles := {}


# ---------------------------------------------------------------------------
# Sphérier
# ---------------------------------------------------------------------------

static func spherier() -> Dictionary:
	if _spherier.is_empty():
		var donnees: Dictionary = U.charger_json("talents.json")
		var noeuds := {}
		var voisins := {}
		for n in donnees["noeuds"]:
			var t := Talent.depuis_donnees(n)
			noeuds[t.ident] = t
			voisins[t.ident] = {}
		for l in donnees["liens"]:
			voisins[l[0]][l[1]] = true
			voisins[l[1]][l[0]] = true
		_spherier = {"noeuds": noeuds, "liens": donnees["liens"], "amas": donnees["amas"],
			"parties": donnees["parties"], "voisins": voisins}
		for cle in donnees["libelles"]:
			_libelles[cle] = donnees["libelles"][cle]
	return _spherier


static func noeuds() -> Dictionary:
	return spherier()["noeuds"]


## Tous les talents du sphérier, dans l'ordre de création (get_liste_talents).
static func get_liste_talents() -> Array:
	return noeuds().values()


## Position d'une partie de talent clé : [numéro, nombre de parties], ou null.
static func partie(ident: String):
	var parties = spherier()["parties"].get(ident)
	if parties == null:
		return null
	return [parties.find(ident) + 1, parties.size()]


static func cle_a_malus(ident: String) -> bool:
	for p in spherier()["parties"].get(ident, [ident]):
		if noeuds()[p].a_un_malus():
			return true
	return false


## Un nœud peut être appris : non acquis et relié à un nœud acquis (acquis : {ident: true}).
static func accessible(ident: String, acquis: Dictionary) -> bool:
	if acquis.has(ident):
		return false
	for v in spherier()["voisins"].get(ident, {}):
		if acquis.has(v):
			return true
	return false


# ---------------------------------------------------------------------------
# Description des bonus
# ---------------------------------------------------------------------------

static func libelles() -> Dictionary:
	spherier()
	return _libelles


static func _nombre(valeur: float) -> String:
	return U.g(U.arrondi(valeur, 1))


static func _formater(gabarit: String, valeur: float) -> String:
	if valeur < 0 and gabarit.substr(0, 1) in ["+", "-"]:
		var signe := "-" if gabarit.substr(0, 1) == "+" else "+"
		return signe + gabarit.substr(1).replace("{v}", _nombre(-valeur))
	return gabarit.replace("{v}", _nombre(valeur))


## Décrit en clair une liste de bonus de talents (une ligne par bonus).
static func decrire_stats(stats: Dictionary) -> Array:
	var lignes := []
	var reunis := {}
	for attribut in PAIRES_CRITIQUES:
		var jumeau: String = PAIRES_CRITIQUES[attribut][0]
		if U.vrai(stats.get(attribut)) and absf(stats.get(attribut, 0) / 2.0 - stats.get(jumeau, 0)) < 1e-9:
			reunis[attribut] = true
			reunis[jumeau] = true
	for attribut in stats:
		var valeur = stats[attribut]
		if not U.vrai(valeur) or (reunis.has(attribut) and not PAIRES_CRITIQUES.has(attribut)):
			continue
		if reunis.has(attribut):
			var gab: String = PAIRES_CRITIQUES[attribut][1].replace("+{m}", ("-" if valeur < 0 else "+") + _nombre(absf(valeur) * 50))
			lignes.append(_formater(gab, valeur * 100))
			continue
		var entree = libelles().get(attribut, [attribut + " +{v}", 1])
		if entree[1] == null:
			lignes.append(entree[0])
		else:
			lignes.append(_formater(entree[0], valeur * entree[1]))
	return lignes


# ---------------------------------------------------------------------------
# Effets en combat
# ---------------------------------------------------------------------------

static func _val(combattant, attribut: String) -> float:
	return U.num(combattant, attribut)


static func a_un_malus_actif(cible) -> bool:
	var alterations = U.ga(cible, "alteration", null)
	if not (alterations is Dictionary):
		return false
	for nom in alterations:
		if not Alterations.est_bonus(nom):
			return true
	return false


## Multiplicateur des dégâts directs d'un coup dû aux talents du lanceur.
static func multiplicateur_degats(lanceur, cible) -> float:
	var mult := maxf(0.1, 1 + _val(lanceur, "talent_degats_infliges"))
	var bonus := _val(lanceur, "talent_bonus_cible_faible")
	if bonus and cible != null and cible.points_de_vie < SEUIL_CIBLE_FAIBLE * maxf(1, cible.points_de_vie_max):
		mult *= 1 + bonus
	var colere := _val(lanceur, "talent_colere")
	if colere:
		var manque: float = 1 - maxf(0, lanceur.points_de_vie) / maxf(1, lanceur.points_de_vie_max)
		mult *= 1 + colere * maxf(0.0, manque)
	bonus = _val(lanceur, "talent_bonus_vs_altere")
	if bonus and cible != null and a_un_malus_actif(cible):
		mult *= 1 + bonus
	return mult


static func multiplicateur_dot(lanceur, nom_alteration, type_degats) -> float:
	if lanceur == null:
		return 1.0
	var bonus := _val(lanceur, "talent_degats_dot") + _val(lanceur, DEGATS_DOT.get(nom_alteration, ""))
	if type_degats in ["brut", "poison"]:
		bonus += _val(lanceur, "talent_degats_brut")
	return maxf(0.0, 1 + bonus)


## Dégâts ajoutés par les talents : [[type ajouté, fraction, types sources], ...].
static func ajouts_de_degats(lanceur, competence) -> Array:
	var ajouts := []
	var types = U.ga(competence, "type_degats", null)
	if types == null:
		types = []
	for attribut in lanceur.attributs():
		var fraction = lanceur.lire(attribut)
		if not String(attribut).begins_with("talent_ajout__") or not U.vrai(fraction):
			continue
		var morceaux := String(attribut).split("__")
		var source := morceaux[1]
		var type_ajoute := morceaux[2]
		var sources := []
		for t in SOURCES_AJOUT.get(source, []):
			if t in types:
				sources.append(t)
		if not sources.is_empty():
			ajouts.append([type_ajoute, fraction, sources])
	return ajouts


static func vol_de_vie_talents(lanceur, type_degats) -> float:
	var vol := _val(lanceur, "talent_vol_de_vie")
	if type_degats in PHYSIQUES:
		vol += _val(lanceur, "talent_vol_de_vie_physique")
	return maxf(0.0, minf(PLAFOND_VOL_DE_VIE, vol))


static func mana_par_pv(cible) -> int:
	return maxi(MANA_PAR_PV_MIN, MANA_PAR_PV - int(_val(cible, "talent_reduction_cout_absorption")))


## « Esprit sur la matière » : renvoie les dégâts qui atteignent encore les PV.
static func absorber_par_mana(cible, degats) -> int:
	if degats <= 0 or not _val(cible, "talent_esprit_sur_matiere"):
		return degats
	var c := mana_par_pv(cible)
	var absorbes := int(mini(degats, int(floor(maxf(0, cible.mana) / c))))
	if absorbes:
		cible.mana -= absorbes * c
		print("Le mana de %s absorbe %d dégâts (%d mana)." % [cible.nom, absorbes, absorbes * c])
	return degats - absorbes


static func ignore_armure(lanceur, cible) -> float:
	var part := minf(PLAFOND_IGNORE_ARMURE, _val(lanceur, "talent_ignore_armure"))
	return part * maxf(0, U.ga(cible, "armure", 0)) if part > 0 else 0.0


static func facteur_reduction(cible) -> float:
	return 1 - minf(PLAFOND_REDUCTION, _val(cible, "talent_reduction_degats"))


static func chance_critique(lanceur, chance: float, type_degats) -> float:
	if type_degats in PHYSIQUES + ["brut"] and _val(lanceur, "talent_sans_critique_physique"):
		return 0.0
	return chance * maxf(0.0, 1 + _val(lanceur, "talent_mult_chance_critique"))


static func toucher_garanti(lanceur, competence) -> bool:
	if not _val(lanceur, "talent_toucher_garanti"):
		return false
	var types = U.ga(competence, "type_degats", null)
	if types == null:
		return false
	for t in types:
		if t in PHYSIQUES:
			return true
	return false


static func immunise(cible, nom_alteration) -> bool:
	return nom_alteration in Alterations.CONTROLES and U.vrai(_val(cible, "talent_immunite_controle"))


static func duree_bonus(lanceur, nom_alteration: String) -> int:
	var attribut := "talent_duree_bienfaits" if Alterations.est_bonus(nom_alteration) else "talent_duree_alterations"
	return int(_val(lanceur, attribut))


static func cout_mana(lanceur, competence) -> int:
	var c := maxf(0, U.ga(competence, "cout_mana", 0))
	var reduction := maxf(-2.0, minf(PLAFOND_REDUCTION, _val(lanceur, "talent_reduction_mana")))
	return int(floor(c * (1 - reduction) + 0.5))


static func paie_en_pv(lanceur) -> bool:
	return U.vrai(_val(lanceur, "talent_magie_du_sang"))


static func cout_ressource(lanceur, competence) -> int:
	var c := cout_mana(lanceur, competence)
	return c * PV_PAR_MANA if paie_en_pv(lanceur) else c


static func libelle_cout(lanceur, competence) -> String:
	return "%d %s" % [cout_ressource(lanceur, competence), "PV" if paie_en_pv(lanceur) else "mana"]


static func peut_payer(lanceur, competence) -> bool:
	var c := cout_ressource(lanceur, competence)
	if paie_en_pv(lanceur):
		return c == 0 or lanceur.points_de_vie > c
	return lanceur.mana >= c


## Fait payer une compétence ; renvoie true si le lancer a été gratuit.
static func payer(lanceur, competence) -> bool:
	var c := cout_ressource(lanceur, competence)
	if c and economise_mana(lanceur):
		print("%s lance %s sans rien dépenser." % [lanceur.nom, competence.nom])
		return true
	if paie_en_pv(lanceur):
		lanceur.points_de_vie -= c
	else:
		lanceur.mana -= c
	return false


static func economise_mana(lanceur) -> bool:
	var chance := minf(PLAFOND_GRATUIT, _val(lanceur, "talent_economie_mana"))
	return chance > 0 and randf() < chance


static func experience_competence(lanceur, base := 10) -> int:
	return int(round(base * (1 + _val(lanceur, "talent_experience_competences"))))


static func chance_initiative(personnage) -> float:
	return minf(0.9, 0.25 + _val(personnage, "talent_initiative"))


static func or_gagne(personnage, montant) -> int:
	return int(round(montant * (1 + _val(personnage, "talent_bonus_or"))))


static func experience_gagnee(personnage, montant) -> int:
	return int(round(montant * (1 + _val(personnage, "talent_bonus_experience"))))


static func facteur_prix(personnage) -> float:
	return 1 - minf(PLAFOND_REDUCTION, _val(personnage, "talent_reduction_prix"))


static func debut_combat(personnage, _combat = null) -> void:
	personnage._rempart_utilise = false


## Début du tour d'un combattant : PV et mana rendus par ses talents (ou les effets uniques de ses objets).
static func debut_tour(personnage, combat = null) -> void:
	var regen := _val(personnage, "talent_regen_tour")
	if regen and personnage.est_vivant() and personnage.points_de_vie < personnage.points_de_vie_max:
		var rendus := Alterations.soigner(personnage, ceilf(regen * personnage.points_de_vie_max), combat)
		if rendus:
			if U.ha(personnage, "arbre_de_talents"):
				print("Vos talents vous rendent %d PV." % rendus)
			else:
				print("%s récupère %d PV (objets)." % [personnage.nom, rendus])
	var mana := _val(personnage, "talent_mana_tour")
	if mana and personnage.mana < personnage.mana_max:
		personnage.mana = min(personnage.mana_max, personnage.mana + ceili(mana * personnage.mana_max))


## « Dernier rempart » : un coup mortel laisse la cible à 1 PV (une fois par combat).
static func dernier_rempart(cible) -> bool:
	if cible.points_de_vie > 0 or not _val(cible, "talent_dernier_rempart") or U.ga(cible, "_rempart_utilise", false):
		return false
	cible.points_de_vie = 1
	cible._rempart_utilise = true
	print("Dernier rempart : %s survit avec 1 PV !" % cible.nom)
	return true


## Effets de talents déclenchés par un événement de combat.
static func reagir(porteur, cible, evenement, combat = null) -> void:
	var type_degats = U.ga(porteur, "type_degats_en_cours", null)
	if evenement == "attaque_touchee":
		var competence = U.ga(combat, "_competence_en_cours", null) if combat != null else null
		if cible != null and cible != porteur and U.ga(competence, "type_competence", "") == "offensif":
			for nom in ALTERATIONS_ATTAQUE:
				var chance := _val(porteur, ALTERATIONS_ATTAQUE[nom])
				if chance and cible.est_vivant():
					Alterations.appliquer_alterations(cible, nom, porteur, 100 * chance, null, duree_bonus(porteur, nom))
	elif evenement == "coup_critique":
		var soin := _val(porteur, "talent_soin_critique")
		if soin and porteur.est_vivant():
			Alterations.soigner(porteur, ceilf(soin * porteur.points_de_vie_max), combat)
		var mana := _val(porteur, "talent_mana_critique")
		if mana:
			porteur.mana = min(porteur.mana_max, porteur.mana + ceili(mana * porteur.mana_max))
		if not (type_degats in PHYSIQUES + ["brut"]):
			var chance := _val(porteur, "talent_mana_critique_magique")
			if chance and randf() < chance:
				porteur.mana = min(porteur.mana_max, porteur.mana + ceili(MANA_CRITIQUE_MAGIQUE * porteur.mana_max))
				print("Le critique magique rend du mana à %s." % porteur.nom)
			chance = _val(porteur, "talent_remboursement_critique")
			if chance and combat != null and randf() < chance:
				combat._cout_rembourse = true
		var chance_m := _val(porteur, "talent_malediction_critique")
		if chance_m and cible != null and cible.est_vivant():
			Alterations.appliquer_alterations(cible, "malédiction", porteur, 100 * chance_m, null, duree_bonus(porteur, "malédiction"))
		var chance_s := _val(porteur, "talent_saignement_critique")
		if chance_s and cible != null and type_degats in PHYSIQUES:
			Alterations.appliquer_alterations(cible, "saignement", porteur, 100 * chance_s, null, duree_bonus(porteur, "saignement"))
	elif evenement == "degats_infliges" and ALTERATIONS_PAR_TYPE.has(type_degats):
		var nom: String = ALTERATIONS_PAR_TYPE[type_degats][0]
		var chance := _val(porteur, ALTERATIONS_PAR_TYPE[type_degats][1])
		if chance and cible != null and cible.est_vivant():
			Alterations.appliquer_alterations(cible, nom, porteur, 100 * chance, null, duree_bonus(porteur, nom))
