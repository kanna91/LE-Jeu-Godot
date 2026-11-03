extends Ecran
## Écran d'exploration (menu_navigation.explorer) : salle, mini-carte, boules de vie
## et de mana, menus, déplacements, actions de la salle, sorts de soin hors combat.
## Résultat : « quitter », « menu », ["charger", nom] ou ["mort", cause].
##
## La salle est une salle peinte où l'on marche (SallePeinte, sous l'interface) : chaque salle du plan
## reçoit une des salles peintes (PlanSalles), et marcher dans une de ses portes mène à la salle voisine
## correspondante (fondu au noir, puis donjon.avancer : combats, coffres, pièges...). Les passages sans
## porte peinte (salles à 4 passages) gardent une flèche. Une porte sans salle derrière est condamnée.

## Tuiles des menus (l'écran du sphérier, touche T, a été retiré le 2026-10-31 avec le sphérier).
const ICONES := [["magie", "Grimoire", "Grimoire", "M"],
	["caracteristiques", "Stats", "Caractéristiques", "C"], ["inventaire", "Sac", "Inventaire", "I"]]
const TUILE := Vector2(78, 62)
const X_TUILES := 704
const Y_TUILES := 8
const COULEUR_PICTO := Color8(232, 190, 110)
const COULEUR_PICTO_SURVOL := Color8(255, 226, 150)
const BOUTON_MENU := Rect2(556, 22, 58, 32)
const RECT_CARTE := Rect2(740, 76, 210, 165)
const DIRECTIONS := ["Gauche", "Tout droit", "Droite", "Reculer"]
const IMAGES_DIRECTIONS := {"Gauche": "fleche_gauche", "Droite": "fleche_droite", "Tout droit": "fleche_haut", "Reculer": "fleche_bas"}
const POSITIONS_FLECHES := {"Gauche": Vector2(360, 400), "Tout droit": Vector2(460, 400), "Droite": Vector2(560, 400),
	"Reculer": Vector2(460, 460)}
const ACTIONS_DROITE := ["Se reposer", "Monter", "Descendre"]
const AIDES_ACTIONS := {
	"Se reposer": "Dormir dans ce lit : PV et mana au maximum, mais tous les ennemis à venir deviennent plus forts.",
	"Monter": "Passer à l'étage supérieur.",
	"Descendre": "Revenir à l'étage précédent (salle du boss).",
}
const OFFSETS_DIRECTIONS := {"Tout droit": Vector2i(0, 1), "Gauche": Vector2i(-1, 0), "Droite": Vector2i(1, 0), "Reculer": Vector2i(0, -1)}

var joueur
var donjon
var message_nav := ""
var message_fin := 0.0
var dernier_instant := 0.0
var rect_action_salle := Rect2(Ui.LARGEUR / 2 - 110, 470, 220, 40)
## Salle peinte affichée sous l'interface, et salle du plan qu'elle montre ([étage, id]).
var salle_peinte: SallePeinte
## Mort par un mal persistant déjà signalée (fin de partie demandée une seule fois).
var _mort_signalee := false
var salle_affichee := []
## Vrai pendant le passage d'une salle à l'autre (fondu, événements de la salle).
var passage_en_cours := false
## Objets à fouiller de la salle affichée (dictionnaires du plan, dans l'ordre de salle_peinte.objets).
var objets_salle: Array = []
## Le stick gauche fait marcher le héros ; le stick droit choisit les boutons (Manette.stick).
var stick_heros := true
## Un contact avec un ennemi est en cours de traitement (combat, capture).
var _occupe_contact := false


func preparer(j, d) -> Ecran:
	joueur = j
	donjon = d
	dernier_instant = Animations.temps()
	particules_fond = false
	salle_peinte = SallePeinte.new()
	add_child(salle_peinte)
	move_child(salle_peinte, 0)
	salle_peinte.sortie_atteinte.connect(_sortie_atteinte)
	_afficher_salle(-1)
	if salle_peinte.presences != null:
		salle_peinte.presences.contact.connect(_contact)
		salle_peinte.presences.parti.connect(_chasseur_parti)
	return self


## Montre la salle peinte de la salle actuelle du plan ; le héros arrive à la sortie ``arrivee``
## (-1 : en bas de l'image).
func _afficher_salle(arrivee: int) -> void:
	var etage: int = donjon.salle_actuelle[0]
	PlanSalles.attribuer(donjon, etage)
	var s: Dictionary = donjon.salle_courante()
	salle_affichee = [etage, int(donjon.salle_actuelle[1])]
	var info: Dictionary = s.get("salle_peinte", {})
	# Objets à fouiller : tirés à la première visite de la salle (Fouille), enregistrés dans le plan
	var image := String(info.get("image", "salle1"))
	objets_salle = Fouille.objets_salle(s, image) if not info.is_empty() else []
	salle_peinte.charger(image, arrivee, bool(info.get("miroir", false)), Fouille.a_afficher(objets_salle, image))
	var feu_ici := Cuisine.feu(joueur, s)
	if not feu_ici.is_empty():
		salle_peinte.afficher_feu_camp(Vector2(float(feu_ici["x"]), float(feu_ici["y"])))
	# Bas de l'image (hors de l'image), passage sur le bord du sol d'une grande salle (type « bord ») ou sortie
	# potentielle (2026-11-03) sans salle derrière : mur invisible, pas de porte condamnée. Le passage vers un autre
	# niveau (fond d'un couloir de prison, entrée des cryptes) reste ouvert.
	var murees := []
	var condamnees := []
	var sorties: Array = info.get("sorties", [])
	var dirs := salle_peinte.directions_sorties()
	var passage := int(info.get("passage", -1))
	for i in mini(sorties.size(), dirs.size()):
		if i == passage:
			continue
		if sorties[i] == null and PlanSalles.fermee_sans_se_voir(image, i, dirs[i]):
			murees.append(i)
		elif sorties[i] == null:
			condamnees.append(i)
	salle_peinte.murer(murees)
	# Portes qui s'ouvrent : celles déjà ouvertes restent ouvertes, comme celle par où l'on arrive ;
	# une porte condamnée ne s'ouvre pas.
	var ouvertes: Array = info.get("portes_ouvertes", []).duplicate()
	if arrivee >= 0:
		ouvertes.append(arrivee)
	salle_peinte.definir_portes(ouvertes, condamnees)
	# Donjon d'aventure : ennemis qui rôdent, personnages, objets (Aventure, PresencesSalle)
	if not info.is_empty():
		salle_peinte.placer_presences(Aventure.presences(donjon, s))
	salle_peinte.pacte_voile = Aventure.pacte_actif(donjon, "voile")


## Retient les portes ouvertes de la salle affichée (dans le plan du donjon, donc dans la sauvegarde).
func _retenir_portes_ouvertes() -> void:
	var info = donjon.salle_courante().get("salle_peinte", null)
	if info is Dictionary and not salle_peinte.portes_ouvertes().is_empty():
		info["portes_ouvertes"] = salle_peinte.portes_ouvertes()


## Lettre de direction du plan (t, g, d, r) vers la salle voisine ``dest``.
func _lettre_vers(dest: String) -> String:
	var etage = donjon.salle_actuelle[0]
	var ici: Vector2i = donjon.salle_courante().get("position", Vector2i.ZERO)
	var la: Vector2i = donjon.plan_donjon[etage].get(dest, {}).get("position", Vector2i.ZERO)
	return {Vector2i(0, 1): "t", Vector2i(-1, 0): "g", Vector2i(1, 0): "d", Vector2i(0, -1): "r"}.get(la - ici, "")


## Le héros est entré dans une sortie de la salle peinte.
func _sortie_atteinte(i: int) -> void:
	if passage_en_cours or _occupe or _ferme:
		return
	var info_salle: Dictionary = donjon.salle_courante().get("salle_peinte", {})
	if i == int(info_salle.get("passage", -1)) and donjon.salle_courante().has("passage_niveau"):
		await _changer_de_niveau()
		return
	var sorties: Array = info_salle.get("sorties", [])
	var dest = sorties[i] if i < sorties.size() else null
	if dest == null:
		message_nav = "Cette porte est condamnée."
		message_fin = Animations.temps() + 2.5
		salle_peinte.reculer_de_la_sortie()
		return
	await _franchir(str(dest), i)


## Passe dans la salle voisine ``dest`` : fondu au noir, événements de la salle (combat, coffre,
## piège...), puis la nouvelle salle peinte, le héros devant la porte par laquelle il est entré.
## ``sortie`` : la sortie prise (-1 : flèche d'un passage sans porte) ; retenue pour revenir par elle.
func _franchir(dest: String, sortie := -1) -> void:
	var lettre := _lettre_vers(dest)
	if lettre == "" or passage_en_cours:
		return
	if Aventure.verrouillee(donjon, dest):
		var verrou := Aventure.ouvrir_verrou(donjon, dest)
		message_nav = verrou[1]
		message_fin = Animations.temps() + 3.5
		if not verrou[0]:
			if sortie >= 0:
				salle_peinte.reculer_de_la_sortie()
			return
	passage_en_cours = true
	salle_peinte.actif = false
	var origine := str(donjon.salle_actuelle[1])
	# Les ennemis qui poursuivent le héros peuvent le suivre dans la salle suivante (Aventure.CHANCE_SUIVRE)
	var suiveurs := []
	if salle_peinte.presences != null:
		for p in salle_peinte.presences.poursuivants():
			if randf() < Aventure.CHANCE_SUIVRE.get(p["genre"], 0.0):
				suiveurs.append(p)
	_retenir_portes_ouvertes()
	var info = donjon.salle_courante().get("salle_peinte", null)
	if info is Dictionary and sortie >= 0:
		var prises: Dictionary = info.get("sortie_prise", {})
		prises[dest] = sortie
		info["sortie_prise"] = prises
		# Endroit exact où il franchit la sortie : il y réapparaîtra en revenant de ``dest``
		var lieux: Dictionary = info.get("lieu_sortie", {})
		lieux[dest] = [salle_peinte.heros.position.x, salle_peinte.heros.position.y]
		info["lieu_sortie"] = lieux
	await salle_peinte.fondu(1.0)
	var etage_depart: int = donjon.salle_actuelle[0]
	await donjon.avancer(lettre)
	if _apres_action():
		passage_en_cours = false
		return
	if not suiveurs.is_empty() and donjon.salle_actuelle[0] == etage_depart:
		var quittee: Dictionary = donjon.plan_donjon[etage_depart][origine]
		# Salle paisible (diablotin, succube) : seuls le chevalier et les geôliers y suivent le héros
		if Aventure.salle_paisible(donjon.salle_courante()):
			suiveurs = suiveurs.filter(func(p): return not (p["genre"] in Aventure.ENNEMIS_ECARTES))
		# Refuge (cuisine) : aucun ennemi ne suit le héros, pas même le chevalier ou un geôlier
		if Zones.refuge(donjon.salle_courante()):
			suiveurs = []
		for p in suiveurs:
			quittee["presences"].erase(p)
			p["suit"] = true
			if int(p.get("traque", 0)) > 0:  # Chevalier de la mort : une salle de traque en moins
				p["traque"] = int(p["traque"]) - 1
			if not donjon.salle_courante().has("presences"):
				donjon.salle_courante()["presences"] = []
			donjon.salle_courante()["presences"].append(p)
	var arrivee := PlanSalles.sortie_vers(donjon.salle_courante(), origine)
	_afficher_salle(arrivee)
	# De retour dans une salle déjà quittée par cette sortie : là où le héros l'avait franchie
	var ici_info: Dictionary = donjon.salle_courante().get("salle_peinte", {})
	var lieu = ici_info.get("lieu_sortie", {}).get(origine, null)
	if arrivee >= 0 and lieu is Array and int(ici_info.get("sortie_prise", {}).get(origine, -1)) == arrivee:
		salle_peinte.placer_au_retour(Vector2(float(lieu[0]), float(lieu[1])), arrivee)
	await salle_peinte.fondu(0.0)
	salle_peinte.actif = true
	passage_en_cours = false


## Passe par le passage de la salle (« passage_niveau ») vers un autre niveau : du fond d'un couloir de prison aux
## cryptes, ou d'une entrée des cryptes au couloir de sa prison (2026-11-03). Le héros arrive devant le passage de
## l'autre côté ; les ennemis ne le suivent pas.
func _changer_de_niveau() -> void:
	var lien: Dictionary = donjon.salle_courante().get("passage_niveau", {})
	var niveau := int(lien.get("niveau", 0))
	var dest := String(lien.get("salle", ""))
	if passage_en_cours or dest == "" or not donjon.plan_donjon.get(niveau, {}).has(dest):
		message_nav = "Le passage est obstrué."
		message_fin = Animations.temps() + 2.5
		salle_peinte.reculer_de_la_sortie()
		return
	passage_en_cours = true
	salle_peinte.actif = false
	_retenir_portes_ouvertes()
	await salle_peinte.fondu(1.0)
	donjon.salle_courante()["visitee"] = true
	donjon._d["salle_actuelle"] = [niveau, int(dest)]
	Aventure.preparer_etage(donjon, niveau)
	await donjon.generer_rencontre()
	if _apres_action():
		passage_en_cours = false
		return
	_afficher_salle(int(donjon.salle_courante().get("salle_peinte", {}).get("passage", -1)))
	message_nav = "Vous descendez dans les cryptes." if Donjon.est_niveau_unique(niveau) else "Vous remontez dans la prison."
	message_fin = Animations.temps() + 3.0
	await salle_peinte.fondu(0.0)
	salle_peinte.actif = true
	passage_en_cours = false


## Passages sans porte peinte (salles à 4 passages) : {direction : id de la salle voisine}.
func passages_sans_porte() -> Dictionary:
	var sans_porte: Array = donjon.salle_courante().get("salle_peinte", {}).get("sans_porte", [])
	var resultat := {}
	for d in DIRECTIONS:
		for dest in sans_porte:
			if _lettre_vers(str(dest)) == directions_possibles().get(d, "?"):
				resultat[d] = str(dest)
	return resultat


# ---------------------------------------------------------------------------
# Données de l'écran
# ---------------------------------------------------------------------------

## « salle_debut (type froid) » → « Salle de départ · froid ».
static func nom_lisible(nom: String) -> String:
	var base := nom
	var reste := ""
	var i := nom.find(" (type ")
	if i >= 0:
		base = nom.substr(0, i)
		reste = nom.substr(i + 7)
	base = "Salle de départ" if base.strip_edges() == "salle_debut" else base.strip_edges()
	var type_salle := reste.rstrip(")").strip_edges()
	return "%s · %s" % [base, type_salle] if type_salle != "" else base


## Directions accessibles : {« Tout droit » : « t », « Gauche » : « g », ...}.
func directions_possibles() -> Dictionary:
	var etage = donjon.salle_actuelle[0]
	var salle: Dictionary = donjon.salle_courante()
	var pos: Vector2i = salle.get("position", Vector2i(0, 0))
	var directions := {}
	for conn in salle["connections"]:
		var cible: Dictionary = donjon.plan_donjon[etage][str(conn)]
		var ecart: Vector2i = cible.get("position", Vector2i(0, 0)) - pos
		if ecart == Vector2i(0, 1):
			directions["Tout droit"] = "t"
		elif ecart == Vector2i(-1, 0):
			directions["Gauche"] = "g"
		elif ecart == Vector2i(1, 0):
			directions["Droite"] = "d"
		elif ecart == Vector2i(0, -1):
			directions["Reculer"] = "r"
	return directions


func rect_fleche(direction: String) -> Rect2:
	return Rect2(POSITIONS_FLECHES[direction], Vector2(40, 40))


## Boutons de droite empilés sous la mini-carte : seules les actions possibles ici sont affichées.
func rect_action(i: int) -> Rect2:
	return Rect2(745, 250 + i * 40, 200, 34)


func actions_visibles() -> Array:
	var liste := []
	for action in ACTIONS_DROITE:
		if action_possible(action):
			liste.append(action)
	return liste


func sorts_de_soin() -> Array:
	var liste := []
	for m in joueur.magies_apprises:
		if U.ga(m, "type_competence", "") == "heal":
			liste.append(m)
	return liste


func rects_soins() -> Array:
	var liste := []
	var soins := sorts_de_soin()
	for i in soins.size():
		liste.append([soins[i], Rect2(126, Ui.HAUTEUR - 54 - i * 40, 200, 34)])
	return liste


func tuiles_menus() -> Dictionary:
	var tuiles := {}
	for i in ICONES.size():
		tuiles[ICONES[i][0]] = Rect2(X_TUILES + i * (TUILE.x + 4), Y_TUILES, TUILE.x, TUILE.y)
	return tuiles


## Points à dépenser dans un menu (pastille sur la tuile).
func points_a_depenser(cle: String) -> int:
	if cle == "magie":
		var noms := {}
		for m in joueur.magies_apprises:
			noms[m.nom] = true
		var a_apprendre := 0
		for m in U.ga(joueur, "magies_disponibles", []):
			if not noms.has(m.nom) and Sorts.peut_apprendre(joueur, m):
				a_apprendre += 1
		return mini(int(U.num(joueur, "nouvelle_magie_a_apprendre")), a_apprendre)
	if cle == "caracteristiques":
		return int(U.num(joueur, "points_a_distribuer"))
	return 0


## Monter : salle du boss. Descendre : salle de départ, hors premier étage. Se reposer : salle avec un lit.
func action_possible(action: String) -> bool:
	if action == "Monter":
		return donjon.est_salle_boss() and donjon.boss_vaincu()
	if action == "Descendre":
		return donjon.peut_descendre()
	if action == "Se reposer":
		return donjon.peut_se_reposer()
	return false


# ---------------------------------------------------------------------------
# Dessin
# ---------------------------------------------------------------------------

func _mise_a_jour(_delta: float) -> void:
	var maintenant := Animations.temps()
	Statistiques.noter(joueur, "temps_de_jeu", maintenant - dernier_instant)
	dernier_instant = maintenant
	# Régénération en minutes réelles : cet écran est en pause pendant les combats et les menus (Ecrans).
	joueur.regenerer(_delta)
	# Cuisine (brandons, feux de camp) et maux persistants (intoxication : peut tuer), au même rythme
	var message_cuisine := Cuisine.avancer(joueur, _delta)
	if message_cuisine != "":
		message_nav = message_cuisine
		message_fin = maintenant + 4
	if salle_peinte.feu_camp != null and Cuisine.feu(joueur, donjon.salle_courante()).is_empty():
		salle_peinte.afficher_feu_camp(null)
		message_nav = "Le feu de camp s'est éteint."
		message_fin = maintenant + 4
	Maux.avancer(joueur, _delta)
	if Statistiques.mort and not _mort_signalee:
		_mort_signalee = true
		_apres_action()
		return
	if U.vrai(U.ga(donjon, "message_evenement", "")):
		message_nav = donjon.message_evenement
		message_fin = maintenant + 4
		donjon.message_evenement = ""
	fond_ecran = ""
	# La salle a changé sans passer par une porte (monter, descendre, chargement) : nouvelle salle peinte
	if not passage_en_cours and salle_affichee != [int(donjon.salle_actuelle[0]), int(donjon.salle_actuelle[1])]:
		_afficher_salle(-1)
	salle_peinte.actif = not passage_en_cours
	if not passage_en_cours and salle_peinte.presences != null and salle_peinte.actif:
		_faire_vivre_l_etage(_delta)


func _dessiner_tuile(ci: Control, cle: String, court: String, touche: String, r: Rect2, survol: bool) -> void:
	Ui.rect(ci, r, Color8(70, 62, 92, 225) if survol else Color8(22, 19, 30, 225), 0, 10)
	Ui.rect(ci, r, Ui.OR if survol else Ui.BRONZE, 2 if survol else 1, 10)
	Icones.dessiner(ci, cle, Vector2(r.get_center().x - 16, r.position.y + 6), 32, COULEUR_PICTO_SURVOL if survol else COULEUR_PICTO)
	Ui.texte(ci, court, Vector2(r.get_center().x, r.end.y - 5), Ui.TEXTE if survol else Ui.DETAIL, 12, survol, null, "midbottom")
	Ui.texte(ci, touche, r.position + Vector2(6, 3), Ui.GRISE, 11, true)
	var points := points_a_depenser(cle)
	if points > 0:
		var centre := Vector2(r.end.x - 9, r.position.y + 9)
		Ui.cercle(ci, centre, 9, Color8(190, 45, 40))
		Ui.cercle(ci, centre, 9, Ui.OR, 1)
		Ui.texte(ci, str(points) if points < 10 else "9+", centre, Ui.BLANC, 11, true, null, "center")


## « Fouiller (E) » au-dessus de l'objet à portée du héros (ou l'action de la présence à portée : « Parler (E) »...).
func _dessiner_fouille(ci: Control) -> void:
	if passage_en_cours or salle_peinte == null or not salle_peinte.actif:
		return
	var p := _presence_proche()
	if not p.is_empty():
		var haut_p := salle_peinte.presences.haut_ecran(p)
		var libelle := "%s (E)" % Aventure.action(p)
		var largeur := Ui.taille_texte(libelle, 15, true).x + 24
		var cadre_p := Rect2(haut_p.x - largeur / 2, haut_p.y - 34, largeur, 26)
		Ui.panneau(ci, cadre_p, 210)
		Ui.texte(ci, libelle, cadre_p.get_center(), Ui.OR, 15, true, null, "center")
		return
	var i := salle_peinte.objet_proche()
	if i < 0:
		return
	var haut := salle_peinte.haut_objet_ecran(i)
	var cadre := Rect2(haut.x - 62, haut.y - 34, 124, 26)
	Ui.panneau(ci, cadre, 210)
	var libelle := "Ramasser (E)" if salle_peinte.objets[i].get("type", "") == "butin" else "Fouiller (E)"
	Ui.texte(ci, libelle, cadre.get_center(), Ui.OR, 15, true, null, "center")


## Contexte de la cuisine ici : torche à portée, foyer de la cuisine, salle du plan, place du héros.
func contexte_cuisine() -> Dictionary:
	var image := String(donjon.salle_courante().get("salle_peinte", {}).get("image", ""))
	return {"torche": salle_peinte.torche_proche(), "cuisine": image in Cuisine.donnees().get("lieux_foyer", []),
		"salle": donjon.salle_courante(), "pos": [salle_peinte.heros.position.x, salle_peinte.heros.position.y]}


## Ouvre l'écran de cuisine (touche K) ; le feu de camp allumé ou éteint est montré au retour.
func cuisiner() -> void:
	if passage_en_cours or salle_peinte == null:
		return
	await Ecrans.ouvrir(Ecrans._ecran("menu_cuisine").preparer(joueur, contexte_cuisine()))
	dernier_instant = Animations.temps()
	var f := Cuisine.feu(joueur, donjon.salle_courante())
	salle_peinte.afficher_feu_camp(null if f.is_empty() else Vector2(float(f["x"]), float(f["y"])))


## Fouille l'objet à portée du héros (touche E, bouton X de la manette).
func _fouiller() -> void:
	if passage_en_cours or salle_peinte == null:
		return
	var i := salle_peinte.objet_proche()
	if i < 0 or i >= objets_salle.size():
		return
	message_nav = Fouille.fouiller(objets_salle[i], joueur, donjon)
	message_fin = Animations.temps() + 4
	salle_peinte.marquer_fouille(i)


func _dessiner(ci: Control) -> void:
	var s := souris()
	var etage = donjon.salle_actuelle[0]
	var salle_id = donjon.salle_actuelle[1]
	var salle: Dictionary = donjon.salle_courante()
	Ui.panneau(ci, Rect2(8, 8, 540, 58), 190)
	Ui.texte(ci, "Or %d  ·  Clés %d  ·  PA %d/%d  ·  Âmes %d/%d  ·  %s" % [int(joueur.piece_or), int(U.ga(joueur, "cles", 0)),
		joueur.points_d_action, joueur.points_d_action_max, int(U.num(joueur, "ames")), Personnage.AMES_PAR_POINT,
		Karma.texte(joueur)],
		Vector2(20, 15), Ui.TEXTE, 15, false, 520)
	var nom_salle := nom_lisible(salle.get("nom", ""))
	# « (miroir) » : la salle peinte est affichée retournée (gauche et droite échangées, PlanSalles)
	Ui.texte(ci, "Étage %d — Salle %d%s%s" % [etage, salle_id, (" : " + nom_salle) if nom_salle != "" else "",
		" (miroir)" if salle_peinte != null and salle_peinte.miroir else ""],
		Vector2(20, 38), Ui.OR, 16, true, 520)
	Dessins.sphere(ci, Vector2(60, Ui.HAUTEUR - 60), Color8(200, 0, 0), joueur.points_de_vie / maxf(1, joueur.points_de_vie_max),
		"%d/%d" % [int(joueur.points_de_vie), int(joueur.points_de_vie_max)])
	Dessins.sphere(ci, Vector2(Ui.LARGEUR - 60, Ui.HAUTEUR - 60), Color8(0, 0, 200), joueur.mana / maxf(1, joueur.mana_max),
		"%d/%d" % [int(joueur.mana), int(joueur.mana_max)])
	var tuiles := tuiles_menus()
	var icone_survolee = null
	for icone in ICONES:
		var r: Rect2 = tuiles[icone[0]]
		var survol := r.has_point(s)
		if survol:
			icone_survolee = icone
		_dessiner_tuile(ci, icone[0], icone[1], icone[3], r, survol)
	var directions := passages_sans_porte()
	var direction_survolee = null
	for d in DIRECTIONS:
		var r := rect_fleche(d)
		if directions.has(d):
			Ui.image(ci, IMAGES_DIRECTIONS[d] + ".png", r)
			if r.has_point(s):
				direction_survolee = d
	_dessiner_fouille(ci)
	_dessiner_discretion(ci)
	var maux := Maux.resume(joueur)
	if maux != "":
		Ui.texte(ci, maux, Vector2(20, 72), Ui.ROUGE, 15, true)
	Ui.texte(ci, "Flèches ou ZQSD : marcher · Maj : %s · H : soin · E : fouiller, parler · K : cuisiner · J : journal" % ("marcher" if salle_peinte.course else "courir"),
		Vector2(Ui.LARGEUR / 2, Ui.HAUTEUR - 8), Ui.DETAIL, 12, false, null, "midbottom")
	var action_salle = donjon.action_salle()
	if action_salle != null:
		Ui.bouton(ci, rect_action_salle, action_salle[0], Color8(150, 110, 40), rect_action_salle.has_point(s))
	var action_survolee = null
	var actions := actions_visibles()
	for i in actions.size():
		var r := rect_action(i)
		var survol := r.has_point(s)
		Ui.bouton(ci, r, actions[i], Ui.BOUTON_NEUTRE, survol, true, 15)
		if survol:
			action_survolee = [actions[i], r]
	Ui.bouton(ci, BOUTON_MENU, "Menu", Ui.BOUTON_NEUTRE, BOUTON_MENU.has_point(s), true, 14)
	Carte.dessiner_mini_carte(ci, donjon, RECT_CARTE)
	var soin_survole = null
	for sr in rects_soins():
		var sort = sr[0]
		var r: Rect2 = sr[1]
		var possible: bool = Talents.peut_payer(joueur, sort) and joueur.points_de_vie < joueur.points_de_vie_max
		Ui.bouton(ci, r, "%s · %s" % [sort.nom, Talents.libelle_cout(joueur, sort)], Color8(40, 110, 70), r.has_point(s), possible, 14)
		if r.has_point(s):
			soin_survole = sr
	if icone_survolee != null:
		var lignes := ["Raccourci : touche %s" % icone_survolee[3]]
		var points := points_a_depenser(icone_survolee[0])
		if points:
			lignes.append({"magie": "%d magie(s) à apprendre" % points,
				"caracteristiques": "%d point(s) à répartir" % points}.get(icone_survolee[0], ""))
		Ui.infobulle(ci, icone_survolee[2], lignes, tuiles[icone_survolee[0]], 230)
	elif direction_survolee != null:
		var cible: Dictionary = donjon.plan_donjon[etage].get(str(salle["connections"][0]), {})
		for conn in salle["connections"]:
			var voisine: Dictionary = donjon.plan_donjon[etage][str(conn)]
			if voisine["position"] - salle["position"] == OFFSETS_DIRECTIONS[direction_survolee]:
				cible = voisine
				break
		var details := ["Déjà visitée" if cible.get("visitee", false) else "Inconnue"]
		if cible.get("type") == "bonus" and not cible.get("effet_utilise", false):
			details.append("Salle bonus")
		Ui.infobulle(ci, nom_lisible(cible.get("nom", direction_survolee)), details, rect_fleche(direction_survolee), 240)
	elif action_survolee != null:
		Ui.infobulle(ci, action_survolee[0], [AIDES_ACTIONS[action_survolee[0]]], action_survolee[1], 240)
	elif soin_survole != null:
		Ui.infobulle(ci, soin_survole[0].nom, ["Soin hors combat (touche H) : environ %d PV" % joueur.soin_estime(soin_survole[0]),
			"Coût : %s" % Talents.libelle_cout(joueur, soin_survole[0])], soin_survole[1], 260)
	if message_nav != "" and Animations.temps() < message_fin:
		Ui.message(ci, message_nav, Vector2(Ui.LARGEUR / 2, 330))
	var z := []
	for cle in tuiles:
		z.append([["icone", cle], tuiles[cle]])
	z.append([["menu"], BOUTON_MENU])
	z.append([["carte"], RECT_CARTE])
	for sr in rects_soins():
		z.append([["soin", sr[0].nom], sr[1]])
	var defaut = null
	for d in DIRECTIONS:
		if directions.has(d):
			z.append([["direction", d], rect_fleche(d)])
			if defaut == null:
				defaut = ["direction", d]
	if action_salle != null:
		z.append([["action", "salle"], rect_action_salle])
	for i in actions.size():
		z.append([["action", actions[i]], rect_action(i)])
	definir_zones(z, defaut if defaut != null else ["menu"], true)


# ---------------------------------------------------------------------------
# Donjon d'aventure : discrétion, personnages, contacts avec les ennemis
# ---------------------------------------------------------------------------

## L'étage vit hors de la salle du héros (Aventure, « chasseurs ») : le chevalier et les geôliers vont de salle en
## salle. Ceux qui entrent dans sa salle apparaissent devant la porte de la salle d'où ils viennent ; ceux de sa salle
## qui font leur ronde repartent au bout d'une traversée (Aventure.duree_salle), ou tout de suite s'ils ont une
## destination ailleurs, par la porte qui y mène.
func _faire_vivre_l_etage(delta: float) -> void:
	var ici: Dictionary = donjon.salle_courante()
	for c in Aventure.avancer_chasseurs(donjon, delta):
		var p: Dictionary = c[0]
		var entree := salle_peinte.point_entree(PlanSalles.sortie_vers(ici, str(c[1])))
		salle_peinte.presences.faire_venir(p, 0.0, entree, bool(p.get("cherche", false)))
		p.erase("cherche")
	for p in salle_peinte.presences.chasseurs_en_ronde():
		p["marche"] = float(p.get("marche", 0.0)) + delta
		var ailleurs: bool = p.has("but") and str(p["but"]) != str(donjon.salle_actuelle[1])
		if p.has("but") and not ailleurs:
			p.erase("but")
		if p["marche"] < Aventure.duree_salle(p) and not ailleurs:
			continue
		var vers := Aventure.prochaine_salle(donjon, p, str(donjon.salle_actuelle[1]))
		var sortie := PlanSalles.sortie_vers(ici, vers)
		if vers == str(donjon.salle_actuelle[1]) or sortie < 0:
			p["marche"] = 0.0
			continue
		salle_peinte.presences.quitter(p, salle_peinte.centre_sortie(sortie), vers)


## Un chasseur a quitté la salle du héros par une porte : il est maintenant dans la salle ``vers``.
func _chasseur_parti(p: Dictionary, vers: String) -> void:
	Aventure.changer_de_salle(donjon, p, str(donjon.salle_actuelle[1]), vers)


## Action bruyante (chaînes brisées) : le chevalier se rapproche (téléporté à 3 salles s'il était plus loin) et
## sait où est le héros ; les geôliers se dirigent vers la salle du bruit (Aventure.vacarme).
func _bruit() -> void:
	if salle_peinte == null:
		return
	if Aventure.vacarme(donjon) > 0:
		message_nav = "Quelque part, un pas de fer se met en marche... vers vous."
		message_fin = Animations.temps() + 4


## Discrétion : « Repéré ! » quand un ennemi poursuit le héros, « Caché » (immobile dans l'ombre ou derrière le premier
## plan), « Dans l'ombre » (il y marche : on le voit de moins loin).
func _dessiner_discretion(ci: Control) -> void:
	if salle_peinte == null or salle_peinte.presences == null or passage_en_cours:
		return
	if salle_peinte.presences.repere():
		Ui.panneau(ci, Rect2(8, 72, 112, 26), 200)
		Ui.texte(ci, "Repéré !", Vector2(64, 85), Ui.ROUGE, 15, true, null, "center")
	elif salle_peinte.heros_cache():
		Ui.panneau(ci, Rect2(8, 72, 112, 26), 200)
		Ui.texte(ci, "Caché", Vector2(64, 85), Ui.VERT, 15, true, null, "center")
	elif salle_peinte.heros_dans_ombre():
		Ui.panneau(ci, Rect2(8, 72, 112, 26), 200)
		Ui.texte(ci, "Dans l'ombre", Vector2(64, 85), Ui.DETAIL, 14, true, null, "center")


## Présence immobile à portée (personnage, pupitre...) ; vide sinon.
func _presence_proche() -> Dictionary:
	if salle_peinte == null or salle_peinte.presences == null:
		return {}
	return salle_peinte.presences.proche()


## Touche E : parle au personnage ou utilise la chose à portée, sinon fouille l'objet à portée.
func _interagir() -> void:
	if passage_en_cours or salle_peinte == null:
		return
	var p := _presence_proche()
	if p.is_empty():
		_fouiller()
		return
	passage_en_cours = true
	salle_peinte.actif = false
	var message := ""
	var suites := []
	if p["genre"] == "pnj":
		var r: Array = await Rencontres.parler(donjon, p)
		message = r[0]
		if r[1]:
			salle_peinte.presences.alerter()
			_bruit()
		if r.size() > 2:
			suites = r[2]
	elif p.get("sous") == "cadavre":
		message = await Aventure.cadavre(donjon, p)
	else:
		message = Aventure.utiliser_objet(donjon, p)
	if p.get("etat") != "actif" and (p["genre"] == "pnj" or p.get("sous") in ["cachette", "cadavre", "objet_quete"]):
		salle_peinte.presences.retirer(p)
	salle_peinte.presences.retirer_parties()  # Sans-Visage apaisé par la succube
	if not suites.is_empty():
		var issue := await _suites_quete(suites)
		message = (message + " " + issue).strip_edges()
	salle_peinte.pacte_voile = Aventure.pacte_actif(donjon, "voile")
	if _apres_action():
		return
	message_nav = message
	message_fin = Animations.temps() + 5
	salle_peinte.actif = true
	passage_en_cours = false


## Suites d'une discussion avec un prisonnier à quête (QuetesPrisonniers) : un ennemi entre par une porte et
## poursuit le héros (« faire_entrer »), ou un combat commence tout de suite (« combat »). Renvoie le message.
func _suites_quete(suites: Array) -> String:
	var messages := []
	for s in suites:
		var p: Dictionary = s.get("faire_entrer", s.get("combat", {}))
		if p.is_empty():
			continue
		var entree := _entree_au_hasard()
		var retard := 0.6 if s.has("faire_entrer") else 0.0
		if s.get("depuis") is Array:  # il surgit à la place du prisonnier, tout de suite
			entree = salle_peinte.sur_le_sol(Vector2(float(s["depuis"][0]), float(s["depuis"][1])))
			retard = 0.0
		salle_peinte.presences.faire_venir(p, retard, entree, true)
		if s.has("combat"):
			messages.append(await _combattre(p))
			if Statistiques.mort:
				break
	return " ".join(messages)


## Point d'entrée devant une porte au hasard de la salle (une sortie qui mène quelque part).
func _entree_au_hasard() -> Vector2:
	var sorties: Array = donjon.salle_courante().get("salle_peinte", {}).get("sorties", [])
	var portes := []
	for i in sorties.size():
		if sorties[i] != null and not i in salle_peinte.sorties_murees:
			portes.append(i)
	return salle_peinte.point_interieur(portes.pick_random() if not portes.is_empty() else -1)


## Un ennemi touche le héros : combat (ou capture par un geôlier ; les pacifiques demandent grâce).
func _contact(p: Dictionary) -> void:
	if passage_en_cours or _ferme or _occupe_contact:
		# Contact ignoré : il pourra se redéclencher (sinon plus aucun ennemi de la salle ne lançait de combat)
		if salle_peinte != null and salle_peinte.presences != null:
			salle_peinte.presences._contact_emis = false
		return
	_occupe_contact = true
	passage_en_cours = true
	salle_peinte.actif = false
	var message := ""
	if p["genre"] == "geolier" and Aventure.consommer_pacte(joueur, "baiser"):
		# Baiser du geôlier (pacte de la succube) : la capture échoue, le geôlier part ailleurs
		message = Aventure.repousser_geolier(donjon, p)
		await Ecrans.dialogue("Geôlier", message, ["..."], Rencontres.COULEUR_SUCCUBE)
		salle_peinte.presences.retirer(p)
		salle_peinte.presences.geler(2.0)
	elif p["genre"] == "geolier":
		await Ecrans.dialogue("Geôlier", "Une main de fer s'abat sur votre épaule. Le geôlier lève sa matraque...",
			["..."], Color8(170, 170, 190))
		message = Aventure.capturer(donjon, p)
		await salle_peinte.fondu(1.0)
		_afficher_salle(-1)
		await salle_peinte.fondu(0.0)
	elif p.get("pacifique", false) and not await Rencontres.pacifiques(donjon, p):
		message = Rencontres.epargner_pacifiques(donjon, p)
		salle_peinte.presences.retirer(p)
		salle_peinte.presences.retirer_parties()  # chevalier du karma reparti
		salle_peinte.presences.geler(2.0)
	else:
		message = await _combattre(p)
		if _apres_action():
			_occupe_contact = false
			return
	message_nav = message
	message_fin = Animations.temps() + 5
	salle_peinte.actif = true
	passage_en_cours = false
	_occupe_contact = false


## Combat contre la présence ``p`` ; renvoie le message à afficher.
func _combattre(p: Dictionary) -> String:
	# Le bruit du combat attire le Chevalier de la mort et les geôliers de l'étage vers cette salle
	Aventure.attirer(donjon)
	var combat := Combat.nouveau(joueur, U.ga(donjon, "fenetre", null), Aventure.ennemis_de(donjon, p), donjon)
	await combat.mener_combat()
	if Statistiques.mort:
		return ""
	if combat.issue == "fuite":
		salle_peinte.presences.eloigner(p)
		salle_peinte.presences.geler(2.5)
		return "Vous parvenez à fuir !"
	var pos = salle_peinte.presences.position_de(p)
	var suite := Aventure.apres_victoire(donjon, p)
	salle_peinte.presences.retirer(p)
	salle_peinte.presences.retirer_parties()
	# Le corps reste là : à fouiller, et son âme à siphonner (2026-10-31)
	var corps := Aventure.laisser_cadavre(donjon, p, pos, "%s%s" % [salle_peinte.ident, "_m" if salle_peinte.miroir else ""])
	if not corps.is_empty():
		salle_peinte.presences.ajouter_immobile(corps)
	salle_peinte.presences.geler(1.0)
	return ("Victoire ! " + suite).strip_edges()


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

## Après une action : vrai s'il faut s'arrêter là. Mort du héros : fin de partie, sauf s'il a le Pacte de mort de la
## succube (il se réveille au cachot avec 1 PV : la salle est réaffichée et l'exploration reprend).
func _apres_action() -> bool:
	if Statistiques.mort:
		if Aventure.relever_par_pacte(donjon):
			_relever.call_deferred()
			return true
		fermer(["mort", Statistiques.cause_mort])
		return true
	return false


## Pacte de mort : la salle du cachot s'affiche, l'exploration reprend.
func _relever() -> void:
	passage_en_cours = true
	salle_peinte.actif = false
	await salle_peinte.fondu(1.0)
	_afficher_salle(-1)
	await salle_peinte.fondu(0.0)
	await Ecrans.dialogue("Succube", "Le noir... puis une voix douce : « Pas encore. Tu es à moi, souviens-toi. » " +
		"Vous vous réveillez au cachot, vivant, avec toutes vos affaires.", ["..."], Rencontres.COULEUR_SUCCUBE)
	message_nav = "Le pacte de mort est rompu : vous ne l'avez plus."
	message_fin = Animations.temps() + 5
	salle_peinte.actif = true
	passage_en_cours = false
	_occupe_contact = false


func ouvrir_icone(cle: String) -> void:
	if cle == "inventaire":
		await Ecrans.menu_inventaire(joueur)
	elif cle == "caracteristiques":
		await Ecrans.menu_caracteristique(joueur)
	elif cle == "magie":
		await Ecrans.menu_magie(donjon.personnage)


func faire_action(action: String) -> String:
	if not action_possible(action):
		return {"Monter": "On ne monte que depuis la salle du boss, une fois le boss vaincu (voir la carte : Tab).",
			"Descendre": "On ne descend que depuis la salle de départ, hors premier étage.",
			"Se reposer": "Il faut un lit pour se reposer."}.get(action, "Impossible ici.")
	if action == "Se reposer":
		donjon.se_reposer()
		return "Vous vous reposez : PV et mana au maximum. Les ennemis se renforcent…"
	if action == "Monter" and donjon.est_dernier_etage():
		fermer(["victoire"])
		return "Vous quittez le donjon."
	if action == "Monter":
		await donjon.monter_etage()
		return "Vous montez à l'étage %d." % donjon.salle_actuelle[0]
	await donjon.descendre_etage()
	return "Vous descendez à l'étage %d." % donjon.salle_actuelle[0]


func _pause() -> void:
	var choix = await Ecrans.menu_pause(joueur, donjon)
	dernier_instant = Animations.temps()
	if choix != "reprendre":
		fermer(choix)


func _evenement(ev: Dictionary) -> void:
	if ev["type"] == "touche":
		var touche: int = ev["touche"]
		if passage_en_cours:
			return
		if touche == KEY_SHIFT:
			salle_peinte.course = not salle_peinte.course
		elif touche == KEY_I:
			await ouvrir_icone("inventaire")
		elif touche == KEY_C:
			await ouvrir_icone("caracteristiques")
		elif touche == KEY_M:
			await ouvrir_icone("magie")
		elif touche == KEY_TAB:
			await Ecrans.carte_complete(donjon)
		elif touche == KEY_J:
			await Ecrans.journal(joueur)
		elif touche == KEY_E:
			await _interagir()
		elif touche == KEY_K:
			await cuisiner()
		elif touche == KEY_H and not sorts_de_soin().is_empty():
			message_nav = joueur.lancer_soin_hors_combat(sorts_de_soin()[0])
			message_fin = Animations.temps() + 3
		elif touche == KEY_ESCAPE:
			await _pause()
		return
	if ev["type"] == "clic" and ev["bouton"] == 2 and not passage_en_cours:  # bouton X de la manette
		await _interagir()
		return
	if ev["type"] != "clic" or ev["bouton"] != 1 or passage_en_cours:
		return
	var pos: Vector2 = ev["pos"]
	if RECT_CARTE.has_point(pos):
		await Ecrans.carte_complete(donjon)
		return
	for sr in rects_soins():
		if sr[1].has_point(pos):
			message_nav = joueur.lancer_soin_hors_combat(sr[0])
			message_fin = Animations.temps() + 3
			return
	if BOUTON_MENU.has_point(pos):
		await _pause()
		return
	var tuiles := tuiles_menus()
	for cle in tuiles:
		if tuiles[cle].has_point(pos):
			await ouvrir_icone(cle)
			break
	var sans_porte := passages_sans_porte()
	for d in sans_porte:
		if rect_fleche(d).has_point(pos):
			await _franchir(sans_porte[d])
			if _ferme:
				return
			break
	var action_salle = donjon.action_salle()
	if action_salle != null and rect_action_salle.has_point(pos):
		await action_salle[1].call()
		if _apres_action():
			return
	var actions := actions_visibles()
	for i in actions.size():
		if rect_action(i).has_point(pos):
			message_nav = await faire_action(actions[i])
			message_fin = Animations.temps() + 3
			_apres_action()
			break
