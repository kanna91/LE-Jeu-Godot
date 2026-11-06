class_name Combat
extends Dyn
## Combat au tour par tour entre le héros et un groupe d'ennemis.
##
## mener_combat() est une coroutine : le tour du joueur attend l'écran de combat
## (``await Ecrans.menu_combat(...)``). La mort du héros lève le drapeau
## Statistiques.mort (au lieu de l'exception MortDuHeros) : les boucles s'arrêtent.


## Le silence bloque les sorts offensifs et les soins magiques.
static func est_bloquee_par_silence(competence, lanceur) -> bool:
	return (not U.ga(lanceur, "magie", true) and competence.type_attaque == "magique"
		and competence.type_competence in ["offensif", "heal", "invocation"])


## Invocations (2026-11-06, demande de l'utilisateur) : compétence -> sorte appelée (Creatures). Au plus
## INVOCATIONS_MAX en vie par invocateur ; elles tombent en poussière quand leur invocateur meurt.
const INVOCATIONS := {"Invocation_squelette": "squelette_invoque"}
const INVOCATIONS_MAX := 2


## Sorte qu'appelle une compétence (« » : ce n'est pas une invocation). Une copie faite dans l'éditeur compte aussi.
static func invocation_de(competence) -> String:
	var classe := String(U.ga(competence, "nom_classe", ""))
	if not INVOCATIONS.has(classe):
		classe = DonneesEnnemis.base_de(classe)
	return String(INVOCATIONS.get(classe, ""))


## Nombre d'invocations encore en vie d'un invocateur.
static func invocations_de(invocateur, ennemis: Array) -> int:
	return ennemis.filter(func(e): return e.est_vivant() and U.ga(e, "invocateur", null) == invocateur).size()


static func nouveau(personnage, fenetre, ennemis: Array, donjon) -> Combat:
	var c := Combat.new()
	c._d["personnage"] = personnage
	c._d["fenetre"] = fenetre
	c._d["ennemis"] = ennemis
	c._d["donjon"] = donjon
	if donjon != null:
		donjon.ennemis = ennemis
	c._d["tour"] = 0
	## Issue du combat : « » (en cours), « victoire », « fuite » ou « defaite ».
	c._d["issue"] = ""
	c._d["joueur_passe"] = false
	c._d["ennemis_passe"] = true
	var bonus_butin := U.num(personnage, "talent_butin")
	for ennemi in ennemis:
		if ennemi.has_method("preparer_competences"):
			ennemi.preparer_competences()
		if ennemi.has_method("preparer_potion"):
			ennemi.preparer_potion(bonus_butin)
	return c


## Termine le combat si tous les ennemis sont morts (altérations retirées, expérience des compétences).
func verification_des_vivants() -> void:
	var personnage = _d["personnage"]
	if not personnage.est_vivant():
		condition_defaite()
	maj_liste_ennemis()
	var vivants := false
	for e in _d["ennemis"]:
		if e.est_vivant():
			vivants = true
	if not vivants:
		print("Tous les ennemis ont été vaincus.")
		personnage.restaurer_points_d_action()
		# Plus de régénération en fin de combat : elle se fait en minutes réelles pendant l'exploration
		# (Personnage.regenerer, décision de l'utilisateur, 2026-10-29).
		personnage.fin_alteration()
		personnage.magie = true
		for competence in personnage.competence_de_base.values():
			competence.recevoir_experience()
		for magie in personnage.magies_apprises:
			magie.recevoir_experience()


## La mort du héros termine la partie (drapeau Statistiques.mort).
func condition_defaite() -> void:
	if not _d["personnage"].est_vivant():
		print("Vous avez été vaincu !")
		Statistiques.lever_mort("combat")


## Appelle une invocation (Creatures) aux côtés du lanceur : coût payé, PA dépensé. Au plus INVOCATIONS_MAX en vie.
## L'écran de combat la place avec les autres (MenuCombat : positions refaites quand un ennemi n'en a pas).
func invoquer(competence, lanceur) -> void:
	var sorte := invocation_de(competence)
	if invocations_de(lanceur, _d["ennemis"]) >= INVOCATIONS_MAX:
		print("%s ne peut pas invoquer plus de %d squelettes." % [lanceur.nom, INVOCATIONS_MAX])
		return
	var e := Creatures.creer(_d["donjon"], sorte)
	e._d["invocateur"] = lanceur
	e._d["nom"] = String(e.nom)
	if e.has_method("preparer_competences"):
		e.preparer_competences()
	e.points_d_action = 0  # il agit au tour suivant
	_d["ennemis"].append(e)
	print("%s lance %s : %s rejoint le combat." % [lanceur.nom, competence.nom, e.nom])
	EffetsCombat.signaler_texte(e, "Invoqué !")
	Statistiques.noter(lanceur, "competences_utilisees")
	Talents.payer(lanceur, competence)
	lanceur.points_d_action -= competence.cout_action


## Les invocations dont l'invocateur est mort tombent en poussière.
func _poussiere_des_invocations() -> void:
	for e in _d["ennemis"]:
		var invocateur = U.ga(e, "invocateur", null)
		if e.est_vivant() and invocateur != null and not invocateur.est_vivant():
			e.points_de_vie = 0
			e._d["est_deja_mort"] = true  # pas compté comme un ennemi tué, pas de butin
			print("%s tombe en poussière." % e.nom)
			EffetsCombat.signaler_texte(e, "Poussière")


## Retire les ennemis morts (la liste est modifiée sur place, partagée avec le donjon).
func maj_liste_ennemis() -> void:
	_poussiere_des_invocations()
	var ennemis: Array = _d["ennemis"]
	var vivants := []
	for e in ennemis:
		if e.est_vivant():
			vivants.append(e)
	ennemis.clear()
	ennemis.append_array(vivants)


## Le joueur passe son tour : les ennemis jouent, puis ses PA sont restaurés.
func passer_son_tour() -> void:
	tour_ennemis()
	_d["personnage"].passer_son_tour()
	_d["joueur_passe"] = true
	verification_des_vivants()


func epuise() -> void:
	if _d["personnage"].points_d_action <= 0:
		print("%s est épuisé et passe son tour." % _d["personnage"].nom)
		passer_son_tour()


## Attaques de base du joueur selon son arme : [nom rapide, compétence rapide, nom puissante, compétence puissante].
func attaques_de_base() -> Array:
	var p = _d["personnage"]
	var type_arme = p.get_type_arme()
	var base: Dictionary = p.competence_de_base
	if type_arme == "Epée":
		return ["Coup d'épée", base["Coup_d_epee"], "Frénésie", base["Frénésie"]]
	if type_arme == "Lance":
		return ["Coup de lance", base["Coup_de_lance"], "Balayage", base["Balayage"]]
	if type_arme == "Marteau":
		return ["Coup de marteau", base["Coup_de_marteau"], "Fracasser", base["Fracasser"]]
	return ["Coup de poing", base["Coup_de_poing"], "Enchainement", base["Enchainement"]]


## Action de combat du joueur venant de l'interface.
## Mode 1 (compétence et cibles) : lance ; mode 2 (compétence seule) : renvoie si elle est utilisable ;
## mode 3 (choix_externe : « 1 » attaque rapide, « 2 » puissante, « 5 » passer son tour).
func logique_menu_combat(choix_externe = null, competence = null, cibles = null):
	var personnage = _d["personnage"]
	if competence != null and U.vrai(cibles):
		print("🎯 Compétence %s déclenchée avec %d cible(s)" % [competence.nom, cibles.size()])
		var finales := choisir_cible(personnage, competence, competence.type_ciblage, competence.nombre_cible, cibles)
		lancer(competence, personnage, _d["donjon"], personnage, finales)
		return null
	if competence != null:
		if not personnage.verifier_points_d_action_suffisants(competence.cout_action):
			print("%s n’a pas assez de PA pour %s." % [personnage.nom, competence.nom])
			return false
		if not Talents.peut_payer(personnage, competence):
			print("%s n’a pas assez de mana pour %s." % [personnage.nom, competence.nom])
			return false
		if est_bloquee_par_silence(competence, personnage):
			print("%s est réduit au silence." % personnage.nom)
			return false
		return true
	if _d["ennemis"].is_empty():
		return null
	var attaques := attaques_de_base()
	if choix_externe != null and str(choix_externe).is_valid_int():
		var choix := int(choix_externe)
		if choix == 5:
			print("Vous passez votre tour.")
			passer_son_tour()
		elif choix == 1 or choix == 2:
			lancer(attaques[1] if choix == 1 else attaques[3], personnage, _d["donjon"], personnage)
			verification_des_vivants()
			epuise()
	return null


## Cibles d'une compétence lancée par un ennemi.
func ciblage_pour_ennemis(competence, lanceur, donjon, personnage) -> Array:
	var cibles := []
	var genre = competence.type_competence
	var ciblage = competence.type_ciblage
	var ennemis: Array = donjon.ennemis
	if genre == "offensif":
		if ciblage == "aléatoire" or ciblage == "choix":
			cibles.append(personnage)
		elif ciblage == "all":
			cibles.append(personnage)
			cibles.append_array(ennemis)
	elif genre == "invocation":
		cibles.append(lanceur)
	elif genre == "heal":
		if ciblage == "self":
			cibles.append(lanceur)
		elif ciblage == "aléatoire":
			if not ennemis.is_empty():
				cibles.append(ennemis.pick_random())
		elif ciblage == "choix":
			if not ennemis.is_empty():
				cibles.append(U.min_par(ennemis, func(e): return e.points_de_vie))
	elif genre == "renforcement defensif":
		if ciblage == "aléatoire":
			if not ennemis.is_empty():
				cibles.append(ennemis.pick_random())
		elif ciblage == "choix":
			var boss := []
			var elite := []
			for e in ennemis:
				if U.ga(e, "est_boss", false):
					boss.append(e)
				if U.ga(e, "est_mini_boss", false):
					elite.append(e)
			if not boss.is_empty():
				cibles.append(boss.pick_random())
			elif not elite.is_empty():
				cibles.append(elite.pick_random())
			elif not ennemis.is_empty():
				cibles.append(ennemis.pick_random())
	elif str(genre).begins_with("renforcement") and ciblage in ["tous_les_ennemis", "toute", "all"]:
		if ennemis.is_empty():
			cibles.append(lanceur)
		else:
			cibles.append_array(ennemis)
	elif genre == "renforcement offensif physique":
		if ciblage == "aléatoire":
			var guerriers := []
			for e in ennemis:
				if U.ga(e, "classe", null) == "guerrier":
					guerriers.append(e)
			cibles.append(guerriers.pick_random() if not guerriers.is_empty() else lanceur)
	elif genre == "renforcement offensif magique":
		if ciblage == "aléatoire":
			var mages := []
			for e in ennemis:
				if U.ga(e, "classe", null) == "mage":
					mages.append(e)
			cibles.append(mages.pick_random() if not mages.is_empty() else lanceur)
	return cibles


## Cibles d'une compétence lancée par le joueur.
func choisir_cible(lanceur, competence, _type_ciblage, nb_cible, cibles_gui = null) -> Array:
	var ciblage = competence.type_ciblage
	var ennemis: Array = _d["ennemis"]
	if ciblage == "choix":
		return cibles_gui if U.vrai(cibles_gui) else []
	elif ciblage == "aléatoire":
		var cibles := []
		for _i in int(nb_cible):
			cibles.append(ennemis.pick_random())
		return cibles
	elif ciblage == "toute":
		if lanceur is Ennemis and competence.type_attaque != "bonus":
			return [_d["personnage"]]
		return ennemis
	elif ciblage == "all":
		return [_d["personnage"]] + ennemis
	elif ciblage == "self":
		return [lanceur]
	elif ciblage == "personnage":
		return [_d["personnage"]]
	push_error("Ciblage inconnu : %s" % ciblage)
	return []


## Boucle principale du combat (coroutine : attend l'écran de combat au tour du joueur).
func mener_combat() -> void:
	var personnage = _d["personnage"]
	var tour := 1
	Talents.debut_combat(personnage, self)
	var priorite := tour_de_combat()
	print("Priorité définie pour le combat : %s\n" % priorite)
	while personnage.est_vivant() and not _d["ennemis"].is_empty() and not Statistiques.mort and _d["issue"] != "fuite":
		_d["joueur_passe"] = false
		_d["ennemis_passe"] = false
		if priorite == "joueur":
			debut_tour_joueur()
			if not _d["joueur_passe"] and not Statistiques.mort:
				await Ecrans.menu_combat(_d["fenetre"], personnage, self)
				await tour_joueur()
			if _d["joueur_passe"] and not Statistiques.mort:
				tour_ennemis()
		else:
			tour_ennemis()
			if _d["ennemis_passe"] and not _d["ennemis"].is_empty() and not Statistiques.mort:
				debut_tour_joueur()
				if not _d["joueur_passe"] and not Statistiques.mort:
					await Ecrans.menu_combat(_d["fenetre"], personnage, self)
					await tour_joueur()
		if Statistiques.mort or _d["issue"] == "fuite":
			break
		personnage.restaurer_points_d_action()
		for ennemi in _d["ennemis"]:
			ennemi.restaurer_points_d_action()
		if _d["joueur_passe"] or _d["ennemis_passe"]:
			tour += 1
		verification_des_vivants()
	if _d["issue"] == "fuite":
		personnage.restaurer_points_d_action()
		personnage.fin_alteration()
		personnage.magie = true
	elif personnage.est_vivant() and not Statistiques.mort:
		_d["issue"] = "victoire"
		Statistiques.noter(personnage, "combats_gagnes")
	else:
		_d["issue"] = "defaite"


## Début du tour du joueur : talents puis altérations (une fois par tour).
func debut_tour_joueur() -> void:
	var personnage = _d["personnage"]
	Talents.debut_tour(personnage, self)
	personnage.set("cause_tour_perdu", null)
	Alterations.mise_a_jour(personnage, self)
	verification_des_vivants()
	if personnage.points_d_action <= 0:
		print("%s ne peut pas agir ce tour-ci." % personnage.nom)
		_signaler_tour_perdu(personnage)
		_d["joueur_passe"] = true


## Affiche à l'écran qu'un combattant perd son tour (altération qui lui retire ses PA).
func _signaler_tour_perdu(combattant) -> void:
	if combattant.est_vivant() and combattant.points_d_action <= 0:
		var cause = U.ga(combattant, "cause_tour_perdu", null)
		EffetsCombat.signaler_texte(combattant, "Tour perdu" + ((" (%s)" % cause) if cause != null else ""))


## Tour du joueur : l'écran de combat s'affiche tant qu'il n'a pas passé.
func tour_joueur() -> void:
	verification_des_vivants()
	while not _d["joueur_passe"] and not _d["ennemis"].is_empty() and not Statistiques.mort and _d["issue"] != "fuite":
		await Ecrans.menu_combat(_d["fenetre"], _d["personnage"], self)
		maj_liste_ennemis()
		verification_des_vivants()


## Chaque ennemi vivant ayant des PA joue (altérations, effets de ses objets, IA).
func tour_ennemis() -> void:
	var personnage = _d["personnage"]
	for ennemi in _d["ennemis"].duplicate():
		if not ennemi.est_vivant() or not personnage.est_vivant() or Statistiques.mort:
			continue
		if ennemi.points_d_action > 0:
			ennemi.set("cause_tour_perdu", null)
			Alterations.mise_a_jour(ennemi, self)
			_signaler_tour_perdu(ennemi)
			if ennemi.est_vivant():
				Talents.debut_tour(ennemi, self)
			verification_des_vivants()
			if ennemi.est_vivant():
				ennemi.mecanique_ennemis(personnage, _d["donjon"], self)
				verification_des_vivants()
			fin_de_tour()
	_d["ennemis_passe"] = true


## Le héros, qui entre dans la salle, joue toujours en premier : les ennemis ne peuvent pas le tuer
## avant qu'il ait agi. (L'ancienne règle, 25 % + talents d'initiative, est dans Talents.chance_initiative.)
func tour_de_combat() -> String:
	return "joueur"


func fin_de_tour() -> void:
	for ennemi in _d["ennemis"].duplicate():
		if ennemi.points_d_action == 0:
			print("Fin du tour pour %s." % ennemi.nom)
			ennemi.a_utilise_mecanique = false
			verification_des_vivants()


## Chance de fuir ce combat (Aventure.chance_fuite).
func chance_fuite() -> float:
	return Aventure.chance_fuite(_d["personnage"], _d["ennemis"])


## Tentative de fuite (l'action du tour) : réussie, le combat s'arrête (issue « fuite ») ; ratée, le tour est perdu.
func tenter_fuite() -> bool:
	if randf() < chance_fuite():
		_d["issue"] = "fuite"
		Statistiques.noter(_d["personnage"], "fuites")
		print("Vous prenez la fuite !")
		return true
	print("La fuite échoue !")
	EffetsCombat.signaler_texte(_d["personnage"], "Fuite ratée !")
	return false


## Lance une compétence : coûts, cibles, attaques, frappe supplémentaire, paiement.
func lancer(competence, lanceur, donjon, personnage, cibles_gui = null) -> void:
	if competence == null:
		print("Compétence non trouvée pour %s" % lanceur.nom)
		return
	var nb_cible = competence.nombre_cible
	var nb_attaque = competence.nombre_attaque
	if not lanceur.verifier_points_d_action_suffisants(competence.cout_action):
		print("%s n'a pas assez de points d'action" % lanceur.nom)
		return
	if not Talents.peut_payer(lanceur, competence):
		print("%s n'a pas assez de mana" % lanceur.nom)
		return
	if est_bloquee_par_silence(competence, lanceur):
		print("%s est réduit au silence et ne peut pas lancer %s." % [lanceur.nom, competence.nom])
		return
	if invocation_de(competence) != "":
		invoquer(competence, lanceur)
		return
	var cibles: Array
	if lanceur is Ennemis:
		if U.vrai(cibles_gui):
			cibles = cibles_gui.duplicate()
		else:
			cibles = ciblage_pour_ennemis(competence, lanceur, donjon, personnage)
	else:
		cibles = choisir_cible(lanceur, competence, competence.type_ciblage, nb_cible, cibles_gui)
		maj_liste_ennemis()
	if lanceur is Ennemis and competence.type_competence == "heal":
		# Un ennemi ne peut être soigné qu'une fois par combat.
		var soignables := []
		for c in cibles:
			if not (c is Ennemis) or c.peut_etre_soigne():
				soignables.append(c)
		if soignables.is_empty():
			print("%s a déjà été soigné pendant ce combat." % cibles[0].nom)
			return
		cibles = soignables
		for c in cibles.slice(0, int(nb_cible)):
			if c is Ennemis:
				c.set("deja_soigne", true)
	if cibles.is_empty():
		print("⚠️ Pas de cibles valides trouvées. Annulation de l’action.")
		return
	_d["_cout_rembourse"] = false
	var cibles_attaque := cibles.slice(0, int(nb_cible))
	if lanceur == personnage and competence.type_competence == "offensif" and randf() < U.num(lanceur, "talent_cible_supplementaire"):
		var autres := []
		for e in _d["ennemis"]:
			if e.est_vivant() and not (e in cibles_attaque):
				autres.append(e)
		if not autres.is_empty():
			cibles_attaque.append(autres.pick_random())
			print("%s touche aussi %s !" % [lanceur.nom, cibles_attaque[-1].nom])
	for i in int(nb_attaque):
		for cible in cibles_attaque:
			if Statistiques.mort:
				break
			print("%s lance %s (%d/%d) sur %s" % [lanceur.nom, competence.nom, i + 1, nb_attaque, cible.nom])
			infliger_degats(lanceur, competence, cible, personnage)
	var chance_frappe := U.num(competence, "chance_frappe_bonus") + U.num(lanceur, "talent_frappe_supplementaire")
	if randf() < chance_frappe:
		var vivantes := []
		for c in cibles_attaque:
			if c.est_vivant():
				vivantes.append(c)
		if not vivantes.is_empty():
			print("%s frappe une fois de plus !" % lanceur.nom)
			infliger_degats(lanceur, competence, vivantes[0], personnage)
	Statistiques.noter(lanceur, "competences_utilisees")
	if _d["_cout_rembourse"]:
		print("Coût de %s remboursé par un critique magique !" % competence.nom)
	else:
		Talents.payer(lanceur, competence)
	_d["_cout_rembourse"] = false
	lanceur.points_d_action -= competence.cout_action
	competence.gagner_experience(Talents.experience_competence(lanceur))
	if lanceur == personnage:
		epuise()


func _declencher_talents(lanceur, cible, evenement: String, attaque_reussie = null, est_critique = null) -> void:
	if evenement == "coup_critique":
		EffetsCombat.critique = true
	elif evenement == "coup_non_critique":
		EffetsCombat.critique = false
	elif evenement == "attaque_ratee":
		EffetsCombat.signaler(cible, "rate", 0, cible == _d["personnage"])
	if attaque_reussie != null:
		lanceur.attaque_reussie = bool(attaque_reussie)
	if est_critique != null:
		lanceur.a_fait_critique = bool(est_critique)
	if U.ha(lanceur, "arbre_de_talents"):
		lanceur.arbre_de_talents.appliquer_talents(lanceur, cible, evenement, self)
	else:
		Talents.reagir(lanceur, cible, evenement, self)


## Applique des dégâts d'un type en déclenchant les talents à chaque étape (critique, modificateurs, exécution).
func _appliquer_pipeline_degats(lanceur, cible, type_degats: String, degats_base: float, recevoir_fn: Callable,
		attaque_reussie := true, penetration_armure = null, penetration_resistance = null) -> void:
	var competence = U.ga(self, "_competence_en_cours", null)
	var bases = U.ga(self, "_bases_coup", null)
	if bases != null:
		bases[type_degats] = bases.get(type_degats, 0) + degats_base
	lanceur.degats_en_cours = degats_base
	lanceur.type_degats_en_cours = type_degats
	_declencher_talents(lanceur, cible, "avant_critique", attaque_reussie, false)
	var degats: float = U.ga(lanceur, "degats_en_cours", degats_base)
	var est_crit := false
	var s := Formules.stats_critique(lanceur, type_degats)
	var chance := minf(Formules.PLAFOND_CRITIQUE, Talents.chance_critique(
		lanceur, s[0] + U.ga(competence, "bonus_critique", 0) + Alterations.chance_critique_contre(cible), type_degats))
	if randf() < chance:
		est_crit = true
		degats *= s[1] + U.ga(competence, "bonus_degats_critique", 0)
		_declencher_talents(lanceur, cible, "coup_critique", null, true)
	else:
		_declencher_talents(lanceur, cible, "coup_non_critique", null, false)
	lanceur.degats_en_cours = degats
	lanceur.type_degats_en_cours = type_degats
	_declencher_talents(lanceur, cible, "apres_critique", attaque_reussie, est_crit)
	degats = U.ga(lanceur, "degats_en_cours", degats)
	if U.vrai(U.ga(competence, "bonus_execution", 0)) and cible.points_de_vie < cible.points_de_vie_max * 0.5:
		degats *= 1 + competence.bonus_execution
	if type_degats == "lumière":
		degats *= Alterations.multiplicateur_soins(cible)
	else:
		degats *= Alterations.modificateur_degats(lanceur, cible)
		degats *= Talents.multiplicateur_degats(lanceur, cible) * Talents.facteur_reduction(cible)
		if type_degats in Talents.PHYSIQUES and U.ga(self, "_parade_en_cours", false):
			degats *= 0.5
		if U.ga(self, "_coup_partiel", false):
			degats *= Formules.DEGATS_MAGIE_ESQUIVEE
		degats = Alterations.absorber(cible, degats)
	if type_degats in Talents.PHYSIQUES and penetration_armure != null:
		penetration_armure += Talents.ignore_armure(lanceur, cible)
	var pv_avant = cible.points_de_vie
	recevoir_fn.call(degats, penetration_armure, penetration_resistance)
	if type_degats != "lumière":
		var inflige = pv_avant - maxf(0, cible.points_de_vie)
		if cible != lanceur:
			Statistiques.noter(lanceur, "degats_infliges", inflige)
			Statistiques.noter_maximum(lanceur, "plus_gros_coup", inflige)
			if est_crit:
				Statistiques.noter(lanceur, "coups_critiques")
		Alterations.apres_coup(lanceur, cible, type_degats, pv_avant - cible.points_de_vie, self,
			U.ga(competence, "vol_de_vie", 0.0))
		var vol_critique := U.num(lanceur, "talent_vol_de_vie_critique")
		if est_crit and vol_critique and lanceur.est_vivant() and pv_avant > cible.points_de_vie:
			lanceur.points_de_vie = min(lanceur.points_de_vie_max,
				lanceur.points_de_vie + ceili((pv_avant - maxf(0, cible.points_de_vie)) * vol_critique))
		var seuil := U.num(lanceur, "seuil_execution")
		if seuil > 0 and cible.est_vivant() and cible.points_de_vie <= seuil * cible.points_de_vie_max:
			print("%s est exécuté par %s !" % [cible.nom, lanceur.nom])
			Degats.recevoir_degats_brut(cible, cible.points_de_vie, self)
	_declencher_talents(lanceur, cible, "degats_infliges", attaque_reussie, est_crit)
	lanceur.effacer("degats_en_cours")
	lanceur.effacer("type_degats_en_cours")


## Dégâts ajoutés par les talents (« Vos attaques infligent en plus x % en feu »...).
func _ajouter_degats_talents(lanceur, competence, cible, bases) -> void:
	if not U.vrai(bases) or not cible.est_vivant():
		return
	for ajout in Talents.ajouts_de_degats(lanceur, competence):
		var type_ajoute: String = ajout[0]
		var base := 0.0
		for t in ajout[2]:
			base += bases.get(t, 0)
		base *= ajout[1]
		if type_ajoute == "brut":
			base *= 1 + U.num(lanceur, "talent_degats_brut")
		else:
			base *= U.ga(lanceur, "pourcentage_degats_" + type_ajoute, 1)
		if base <= 0 or not cible.est_vivant():
			continue
		var pen_res = lanceur.penetration_resistance + competence.penetration_resistance
		var pen_arm = lanceur.penetration_armure + competence.penetration_armure
		var recevoir := func(d, pa, pr): Degats.recevoir(type_ajoute, cible, d, pa, pr, self, lanceur)
		_appliquer_pipeline_degats(lanceur, cible, type_ajoute, base, recevoir, true, pen_arm, pen_res)


## Résout une attaque d'une compétence sur une cible (toucher, parade, dégâts par type, altérations).
func infliger_degats(lanceur, competence, cible, personnage) -> void:
	EffetsCombat.debut_coup(lanceur)
	_infliger_degats(lanceur, competence, cible, personnage)
	EffetsCombat.fin_coup()


func _infliger_degats(lanceur, competence, cible, personnage) -> void:
	var attaque_reussie := true
	_d["_competence_en_cours"] = competence
	var offensive: bool = competence.type_competence == "offensif"
	var reel_chance := Formules.chance_toucher(lanceur, competence, cible)
	var rate: bool = (offensive and not Talents.toucher_garanti(lanceur, competence)
		and randi_range(1, 100) / 100.0 > reel_chance)
	var coup_partiel: bool = rate and competence.type_attaque == "magique"
	_d["_coup_partiel"] = coup_partiel
	if coup_partiel:
		print("%s esquive en partie %s (%d%% des dégâts)." % [cible.nom, competence.nom, int(Formules.DEGATS_MAGIE_ESQUIVEE * 100)])
		rate = false
	if rate:
		print("%s donne un grand coup dans le vide." % lanceur.nom)
		_declencher_talents(lanceur, cible, "attaque_ratee", false, false)
		return
	var physique := false
	for t in competence.type_degats:
		if t in Talents.PHYSIQUES:
			physique = true
	_d["_parade_en_cours"] = offensive and physique and randf() < Formules.parade(cible)
	if _d["_parade_en_cours"]:
		print("%s pare le coup !" % cible.nom)
	_declencher_talents(lanceur, cible, "attaque_touchee", true)
	_d["_bases_coup"] = {}
	var types: Array = competence.type_degats
	var pen_res = lanceur.penetration_resistance + competence.penetration_resistance
	var pen_arm = lanceur.penetration_armure + competence.penetration_armure
	# Chaque type de dégâts de la compétence lance ses dés (Formules.DES_TYPES) : dés + caractéristique ÷ 2
	# + dégâts plats du lanceur, × pourcentages. Le dé bonus d'arme d'un autre type ajoute un coup de ce type.
	var coups := []
	for t in Formules.TYPES_PHYSIQUES + Formules.TYPES_MAGIQUES + Formules.TYPES_SPECIAUX:
		if t in types:
			coups.append([t, Formules.degats_competence(lanceur, competence, t, Formules.valeur_jet(lanceur, competence, t))
				+ Formules.bonus_pv_cible(lanceur, competence, cible, t)])
	var bonus := Formules.de_bonus_autre_type(lanceur, types, competence)
	if not bonus.is_empty():
		coups.append([bonus[0], Formules.base_de_bonus(lanceur, bonus[0], randi_range(1, bonus[1]))])
	for coup in coups:
		var t: String = coup[0]
		var base: float = coup[1]
		var recevoir := func(d, pa, pr): Degats.recevoir(t, cible, d, pa, pr, self, lanceur)
		_appliquer_pipeline_degats(lanceur, cible, t, base, recevoir, true,
			pen_arm if t in Formules.TYPES_PHYSIQUES else null, pen_res)
		if t == "lumière":
			print(" %s reçoit %s de dégats de lumière" % [cible.nom, U.g(base)])
	var bases = _d["_bases_coup"]
	_d["_bases_coup"] = null
	if offensive:
		_ajouter_degats_talents(lanceur, competence, cible, bases)
	# Mana retiré à la cible par un coup qui touche (Chevalier de la mort : « vol_mana_des », dés à lancer, plus
	# « vol_mana_part » du mana max de la cible) ; « ombre_par_mana » de ce mana retiré devient des dégâts d'ombre
	# (arrondis en dessous, 2026-11-01).
	var vol_mana = U.ga(lanceur, "vol_mana_des", null)
	if vol_mana is Array and offensive and attaque_reussie and not coup_partiel and cible.est_vivant():
		var voulu := Formules.jet(vol_mana) + floori(U.num(lanceur, "vol_mana_part") * U.num(cible, "mana_max"))
		var perte := mini(int(cible.mana), voulu)
		if perte > 0:
			cible.mana -= perte
			print("%s perd %d points de mana." % [cible.nom, perte])
			EffetsCombat.signaler_texte(cible, "−%d mana" % perte, Color8(120, 170, 255), true)
			var ombre := floori(perte * U.num(lanceur, "ombre_par_mana"))
			if ombre > 0 and cible.est_vivant():
				Degats.recevoir("ombre", cible, ombre, 0, pen_res, self, lanceur)
	if attaque_reussie and not coup_partiel:
		for nom in competence.type_alteration:
			Alterations.appliquer_alterations(cible, nom, lanceur, competence.type_alteration[nom],
				competence.puissance_alterations.get(nom), competence.duree_bonus + Talents.duree_bonus(lanceur, nom))
		var lanceur_alt = U.ga(competence, "alterations_lanceur", {})
		for nom in lanceur_alt:
			Alterations.appliquer_alterations(lanceur, nom, lanceur, lanceur_alt[nom],
				competence.puissance_alterations.get(nom), competence.duree_bonus + Talents.duree_bonus(lanceur, nom))
		if U.vrai(U.ga(competence, "purification", 0)) and not offensive:
			Alterations.purifier(cible, competence.purification)
	_d["_coup_partiel"] = false
