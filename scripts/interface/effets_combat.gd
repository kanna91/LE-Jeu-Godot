class_name EffetsCombat
extends RefCounted
## Animations de dégâts en combat (effets_combat.py) — enregistrement des coups.
##
## Le module observe les dégâts sans changer les calculs : Degats signale chaque
## coup (PV avant et après), Combat les critiques, les coups ratés et le
## regroupement des types d'un même coup, Alterations les altérations qui prennent.
## L'écran de combat rejoue ensuite la file (EffetsDessin).

const ECART_COUPS := 0.38
const ECART_COUPS_RAPIDE := 0.2
const SEUIL_FILE_LONGUE := 6
const DUREE_CHIFFRE := 1.15
const DUREE_MORT := 0.9
const DEBUT_MORT := 0.35
const ECHELLE_JOUEUR := 1.6
const TAILLE_FILE_MAX := 150
const AGE_MAX_ATTENTE := 3.0
## Pause (s) entre le dernier coup du héros et le début de l'attaque d'un ennemi qui le suit : la
## cible finit de réagir (touché) avant de riposter.
const PAUSE_RIPOSTE := 1.5
const DUREES := {
	"tranchant": 0.55, "perforant": 0.55, "contondant": 0.7, "feu": 0.9, "froid": 0.9,
	"foudre": 0.7, "arcane": 0.9, "chaos": 0.9, "ombre": 0.9, "lumière": 1.0,
	"saignement": 0.8, "poison": 0.9, "rate": 0.5, "etat": 0.0,
}
const COULEURS := {
	"tranchant": Color8(235, 235, 245), "perforant": Color8(255, 225, 160), "contondant": Color8(225, 175, 115),
	"feu": Color8(255, 140, 40), "froid": Color8(150, 215, 255), "foudre": Color8(255, 245, 120),
	"arcane": Color8(195, 120, 255), "chaos": Color8(235, 45, 95), "ombre": Color8(150, 80, 200),
	"lumière": Color8(255, 230, 120), "saignement": Color8(225, 30, 40), "poison": Color8(120, 225, 70),
	"rate": Color8(200, 200, 200), "etat": Color8(255, 255, 255),
}
const SECOUSSES := {
	"tranchant": 5, "perforant": 5, "contondant": 11, "feu": 4, "froid": 4, "foudre": 7,
	"arcane": 4, "chaos": 6, "ombre": 4, "lumière": 0, "saignement": 2, "poison": 2, "rate": 0, "etat": 0,
}

static var file: Array = []
static var groupe := 0
static var pile_groupes: Array = []
static var critique := false
static var dernier_debut := -1.0
static var dernier_groupe = null
static var dernier_coup_heros := -1.0   # instant du dernier coup affiché dont le héros est la source
static var combat = null
## Lanceur de l'attaque en cours (pile, comme les groupes) : source des coups, pour les animations.
static var pile_sources: Array = []
## Durée à l'écran d'un coup mortel, par cible (gobelins animés : animation de mort ; CombatAnime).
static var durees_mort := {}


class Impact:
	var cible
	var type: String
	var montant: float
	var est_joueur: bool
	var critique: bool
	var mortel: bool
	var groupe: int
	var cree: float
	var debut = null
	var rang := 0
	var graine: int
	var particules: Array = []
	var forme: Dictionary = {}
	var texte = null
	var prepare := false
	var source = null          # lanceur de l'attaque (null : altération, début de tour...)
	var anim_source := ""      # animation d'attaque de la source calée sur ce coup (CombatAnime)

	func duree() -> float:
		var d := maxf(EffetsCombat.DUREES.get(type, 0.8), EffetsCombat.DUREE_CHIFFRE)
		if mortel:
			d = maxf(d, EffetsCombat.durees_mort.get(cible, EffetsCombat.DEBUT_MORT + EffetsCombat.DUREE_MORT + 0.1))
		return d


static func maintenant() -> float:
	return Time.get_ticks_usec() / 1000000.0


static func _groupe_courant() -> int:
	if not pile_groupes.is_empty():
		return pile_groupes[-1]
	groupe += 1
	return groupe


## Ajoute un coup à la file des animations.
static func signaler(cible, type_degats: String, montant, est_joueur: bool, mortel := false) -> void:
	var imp := Impact.new()
	imp.cible = cible
	imp.type = type_degats
	imp.montant = float(montant)
	imp.est_joueur = est_joueur
	imp.critique = critique and type_degats != "rate"
	critique = false
	imp.mortel = mortel
	imp.groupe = _groupe_courant()
	imp.source = null if pile_sources.is_empty() else pile_sources[-1]
	imp.cree = maintenant()
	imp.graine = randi()
	file.append(imp)
	if file.size() > TAILLE_FILE_MAX:
		file = file.slice(file.size() - TAILLE_FILE_MAX)


## Affiche le nom d'une altération qui vient de frapper un combattant (« Brûlure ! »).
static func signaler_alteration(cible, nom: String) -> void:
	if combat == null:
		return
	signaler(cible, "etat", 0, cible == combat.personnage)
	file[-1].texte = [Alterations.libelle(nom) + " !",
		Color8(120, 235, 130) if Alterations.est_bonus(nom) else Color8(255, 120, 100)]


## Affiche un court texte au-dessus d'un combattant (« Tour perdu (Gel) »). ``pres_mana`` : pour le héros, au-dessus
## de son orbe de mana plutôt que de son orbe de vie (mana retiré par le Chevalier de la mort).
static func signaler_texte(cible, texte: String, couleur := Color8(255, 200, 90), pres_mana := false) -> void:
	if combat == null:
		return
	signaler(cible, "etat", 0, cible == combat.personnage)
	file[-1].texte = [texte, couleur]
	if pres_mana:
		file[-1].forme["pres_mana"] = true


## Début et fin d'une attaque (Combat.infliger_degats) : ses dégâts partagent un groupe ;
## ``lanceur`` devient la source de ses coups.
static func debut_coup(lanceur = null) -> void:
	groupe += 1
	pile_groupes.append(groupe)
	pile_sources.append(lanceur)


static func fin_coup() -> void:
	if not pile_groupes.is_empty():
		pile_groupes.pop_back()
	if not pile_sources.is_empty():
		pile_sources.pop_back()


## Prépare les animations pour l'écran d'un combat (oublie celles d'un combat précédent).
static func nouveau_combat(c) -> void:
	if combat == c:
		return
	combat = c
	var t := maintenant()
	var gardes := []
	for imp in file:
		if imp.debut == null and t - imp.cree < AGE_MAX_ATTENTE and (imp.cible == c.personnage or imp.cible in c.ennemis):
			gardes.append(imp)
	file = gardes
	dernier_debut = -1.0
	dernier_groupe = null
	dernier_coup_heros = -1.0
	durees_mort.clear()
	CombatAnime.nouveau_combat(c)


## Donne un instant de départ aux coups en attente, l'un après l'autre.
static func planifier(t: float) -> void:
	var en_attente := []
	var groupes := {}
	for imp in file:
		if imp.debut == null:
			en_attente.append(imp)
		if imp.debut == null or imp.debut > t:
			groupes[imp.groupe] = true
	if en_attente.is_empty():
		return
	var ecart := ECART_COUPS if groupes.size() <= SEUIL_FILE_LONGUE else ECART_COUPS_RAPIDE
	for imp in en_attente:
		if imp.groupe == dernier_groupe and dernier_debut >= 0:
			imp.debut = dernier_debut
		else:
			# Premier coup d'une attaque d'un combattant animé : retardé jusqu'à l'image d'impact
			# de son animation, qui démarre d'autant plus tôt (CombatAnime).
			var avance := CombatAnime.avance(imp)
			var debut := maxf(t + avance, dernier_debut + ecart)
			# Attaque d'un ennemi après celle du héros : PAUSE_RIPOSTE avant le début de son animation.
			if combat != null and imp.source != null and imp.source != combat.personnage and dernier_coup_heros >= 0.0:
				debut = maxf(debut, dernier_coup_heros + PAUSE_RIPOSTE + avance)
			imp.debut = debut
			dernier_debut = imp.debut
			dernier_groupe = imp.groupe
			if avance > 0.0:
				CombatAnime.demarrer(imp, avance)
			if combat != null and imp.source != null and imp.source == combat.personnage:
				dernier_coup_heros = imp.debut
		var rang := 0
		var index_imp := file.find(imp)
		for i in index_imp:
			var autre = file[i]
			if autre != imp and autre.groupe == imp.groupe and autre.cible == imp.cible and autre.debut != null and autre.rang >= 0:
				rang += 1
		imp.rang = rang


## Des animations restent à jouer.
static func en_cours() -> bool:
	var t := maintenant()
	for imp in file:
		if imp.debut == null or t < imp.debut + imp.duree():
			return true
	return false


## PV à afficher, en retard sur les coups pas encore montrés.
static func pv_affiches(cible) -> float:
	var t := maintenant()
	var pv: float = cible.points_de_vie
	for imp in file:
		if imp.cible == cible and (imp.debut == null or t < imp.debut):
			pv += imp.montant
	return clampf(pv, 0, cible.points_de_vie_max)


## Recul (ou esquive) du sprite d'un ennemi : Vector2.
static func decalage(ennemi) -> Vector2:
	var t := maintenant()
	var dx := 0.0
	var dy := 0.0
	for imp in file:
		if imp.cible != ennemi or imp.debut == null:
			continue
		var age: float = t - imp.debut
		if imp.type == "rate":
			if 0 <= age and age < 0.35:
				dx -= sin(PI * age / 0.35) * 16
		elif 0 <= age and age < 0.25:
			var amplitude: float = SECOUSSES.get(imp.type, 4) * (1.5 if imp.critique else 1.0) * (1 - age / 0.25)
			dx += sin(age * 70) * amplitude
			dy += absf(sin(age * 45)) * amplitude * 0.3
	return Vector2(int(dx), int(dy))


## Oublie les coups terminés (appelé par l'écran de combat).
static func nettoyer() -> void:
	var t := maintenant()
	var restants := []
	for imp in file:
		if imp.debut == null or t < imp.debut + imp.duree() + 0.05:
			restants.append(imp)
	file = restants
