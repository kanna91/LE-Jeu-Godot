extends SceneTree
## Testeur automatique de l'étage 1 (demande de l'utilisateur, 2026-10-28) : combien de temps faut-il à un joueur
## pour trouver et vaincre le gardien ? Objectif de l'utilisateur : environ une heure pour un joueur moyen.
##
## Le testeur joue comme un joueur, dans le vrai jeu (écran d'exploration, salles peintes, ennemis qui rôdent) :
## - il se déplace dans chaque salle en donnant une direction au héros (``SallePeinte.pilote``, comme un stick), en
##   courant, sur un chemin calculé entre les obstacles (grille de PAS_GRILLE px), puis pousse vers la sortie ;
## - il ne connaît pas la carte : seulement les salles visitées et les sorties qu'il y a vues (ce que montre la
##   mini-carte) ; il va toujours vers la salle inconnue la plus proche, jusqu'à trouver le gardien, puis il l'attaque ;
## - un ennemi qui le touche lance le combat, joué par le joueur automatique (Auto : il fuit le Chevalier de la mort) ;
##   un geôlier peut le capturer (réveil au cachot, sans ses affaires) ; il ne parle pas aux diablotins, ne fouille
##   pas, ne ramasse rien ;
## - le joueur automatique joue mal (il frappe et se soigne au hasard) : pour mesurer le temps jusqu'au gardien, le
##   héros qui meurt **se relève** au cachot, soigné (comme le Pacte de mort de la succube, offert à chaque fois) ;
##   chaque mort est comptée dans le rapport. Option ``sans-relever`` : la première mort termine la partie ;
## - les sorties qu'il n'arrive pas à prendre sont listées (salle, sortie) : elles signalent des zones mal tracées.
## Temps : le jeu tourne à cadence fixe (``--fixed-fps 60`` : 1 image = 1/60 s de jeu, calculée aussi vite que
## possible), donc les déplacements et les fondus sont mesurés comme en vraie partie. Les combats du joueur automatique
## sont instantanés : leur durée est **estimée** (TEMPS_ACTION_COMBAT par action du héros, choix et animations des deux
## camps compris), comme le temps de lecture des personnages croisés (TEMPS_PERSONNAGE). Ces hypothèses sont dans le
## rapport ; le temps d'un vrai joueur est plus long (hésitations, carte consultée, fouilles, menus).
##
## Lancer (depuis le dossier godot ; ``testeur_etage.bat``) :
##   Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . -s tests/testeur_etage.gd -- [parties] [graine]
## Rapport : ``tests/rapports/testeur_etage.txt`` (et la console). « BILAN testeur d'étage : N partie(s) ».

const PARTIES := 3
## Hypothèses du temps estimé (secondes).
const TEMPS_ACTION_COMBAT := 6.0
const TEMPS_PERSONNAGE := 20.0
## Temps qu'un joueur passe à découvrir une salle où il entre pour la première fois (regarder, chercher les sorties).
const TEMPS_DECOUVERTE := 8.0
## Limite d'une partie (temps de jeu mesuré, en secondes) : au-delà, la partie est abandonnée.
const LIMITE := 3600.0
const PAS_GRILLE := 6.0
## Sans progrès pendant BLOCAGE secondes : nouveau chemin ; ESSAIS fois de suite sur la même sortie : on l'oublie.
const BLOCAGE := 6.0
## Défaites contre le gardien avant d'arrêter la partie (le joueur automatique ne sait pas le battre).
const DEFAITES_GARDIEN := 3
const ESSAIS := 3

var racine: Control
var horloge: Horloge
var nav
var joueur
var donjon
var lignes_rapport := []
var relever := true
## Options : « trace » (état toutes les 30 s de jeu), « limite=N » (minutes de jeu au plus par partie).
var trace := false
var limite := LIMITE
var _derniere_trace := 0.0


class Horloge extends Node:
	var temps := 0.0

	func _process(delta: float) -> void:
		temps += delta


func _initialize() -> void:
	racine = Control.new()
	racine.size = Vector2(960, 540)
	root.add_child(racine)
	horloge = Horloge.new()
	root.add_child(horloge)
	Ecrans.racine = racine
	Ecrans.auto = true
	lancer()


func attendre(n: int) -> void:
	for _i in n:
		await process_frame


func rapporter(t: String) -> void:
	print(t)
	lignes_rapport.append(t)
	# Écrit au fur et à mesure : un lancement interrompu garde ses parties finies
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://tests/rapports"))
	var f := FileAccess.open("res://tests/rapports/testeur_etage.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(lignes_rapport) + "\n")
		f.close()


static func duree(s: float) -> String:
	return "%d min %02d s" % [int(s) / 60, int(s) % 60]


func lancer() -> void:
	var args := OS.get_cmdline_user_args()
	var parties := int(args[0]) if args.size() > 0 and args[0].is_valid_int() else PARTIES
	var graine := int(args[1]) if args.size() > 1 and args[1].is_valid_int() else 1000
	relever = not ("sans-relever" in args)
	trace = "trace" in args
	for a in args:
		if a.begins_with("limite="):
			limite = float(a.trim_prefix("limite=")) * 60.0
	rapporter("Testeur d'étage — %s — %d partie(s), graine %d" % [Time.get_datetime_string_from_system(), parties, graine])
	rapporter(("Hypothèses : %d s par action de combat du héros, %d s par personnage croisé (lecture), %d s pour découvrir "
		+ "chaque nouvelle salle ; course permanente ; pas de fouille ni de dialogue.") % [int(TEMPS_ACTION_COMBAT),
		int(TEMPS_PERSONNAGE), int(TEMPS_DECOUVERTE)])
	var resultats := []
	for k in parties:
		resultats.append(await partie(graine + k))
	# Résumé
	var finies := resultats.filter(func(r): return r["gardien"])
	rapporter("")
	rapporter("== RÉSUMÉ : gardien vaincu dans %d partie(s) sur %d" % [finies.size(), resultats.size()])
	if not finies.is_empty():
		var totaux: Array = finies.map(func(r): return r["total"])
		totaux.sort()
		var somme := 0.0
		for t in totaux:
			somme += t
		rapporter("   temps estimé jusqu'au gardien vaincu : moyenne %s (de %s à %s)" % [duree(somme / totaux.size()),
			duree(totaux[0]), duree(totaux[-1])])
	var trouves: Array = resultats.filter(func(r): return r["atteint"] >= 0).map(func(r): return r["atteint"])
	if not trouves.is_empty():
		trouves.sort()
		var s := 0.0
		for t in trouves:
			s += t
		rapporter("   GARDIEN TROUVÉ dans %d partie(s) sur %d : après %s en moyenne (estimé ; de %s à %s)" % [trouves.size(),
			resultats.size(), duree(s / trouves.size()), duree(trouves[0]), duree(trouves[-1])])
	var nb_morts := 0
	var nb_captures := 0
	var nb_fuites := 0
	var toutes_abandonnees := {}
	for r in resultats:
		nb_captures += int(r["captures"])
		nb_fuites += int(r["evitements"])
		nb_morts += int(r["morts"])
		for a in r["abandonnees"]:
			toutes_abandonnees[a] = int(toutes_abandonnees.get(a, 0)) + 1
	rapporter("   morts du héros (joueur automatique) : %d ; captures par un geôlier : %d ; fuites devant un chasseur : %d (en %d partie(s))"
		% [nb_morts, nb_captures, nb_fuites, resultats.size()])
	for a in toutes_abandonnees:
		rapporter("   sortie abandonnée %d fois : %s" % [toutes_abandonnees[a], a])
	for r in resultats:
		if not r["gardien"]:
			rapporter("   partie %d : %s" % [r["graine"], r["fin"]])
	print("BILAN testeur d'étage : %d partie(s), gardien vaincu dans %d" % [resultats.size(), finies.size()])
	quit()


# ---------------------------------------------------------------------------
# Une partie
# ---------------------------------------------------------------------------

func partie(graine: int) -> Dictionary:
	seed(graine)
	Sauvegarde.reinitialiser_monde()
	Statistiques.mort = false
	Auto.actions_combat = 0
	Auto.journal_combats = []
	joueur = Personnage.nouveau()
	donjon = Donjon.nouveau(joueur)
	for e in Ecrans.pile:
		if is_instance_valid(e):
			e.queue_free()
	Ecrans.pile.clear()
	nav = Ecrans._ecran("menu_navigation").preparer(joueur, donjon)
	Ecrans.pile.append(nav)
	racine.add_child(nav)
	await attendre(20)
	var debut := horloge.temps
	var visitees := {}
	var aretes := {}          # salle → {sortie : salle voisine}
	var oubliees := {}        # "salle/sortie" → vrai (sortie impossible à prendre)
	var personnages := {}     # présences de personnages croisées (lecture)
	var passages := 0
	var morts := 0
	var salle_gardien := ""
	var evitements := 0
	var atteint := -1.0           # temps estimé quand le gardien est trouvé (première fois vu)
	var defaites_gardien := 0
	var abandonnees := []
	if relever:
		Aventure._pactes(joueur)["mort"] = true
	var fin := ""
	var gardien := false
	var temps_gardien := 0.0
	while true:
		# Au moins une image de jeu par décision : sinon, collé au gardien sans combat, la boucle tournait sans fin
		await process_frame
		if not is_instance_valid(nav) or nav._ferme or Statistiques.mort:
			fin = "mort du héros (%s)" % Statistiques.cause_mort if Statistiques.mort else "écran fermé"
			break
		if horloge.temps - debut > limite:
			fin = "abandon : plus de %s de jeu" % duree(limite)
			break
		if trace and horloge.temps - _derniere_trace > 30.0:
			_derniere_trace = horloge.temps
			print("TRACE %s : salle %s (%s), héros %s, gardien vu en %s, PV %d" % [duree(horloge.temps - debut),
				donjon.salle_actuelle[1], nav.salle_peinte.ident if nav.salle_peinte != null else "?",
				nav.salle_peinte.heros.position if nav.salle_peinte != null else Vector2.ZERO, salle_gardien,
				int(joueur.points_de_vie)])
		if nav.passage_en_cours:
			_piloter(Vector2.ZERO)
			await process_frame
			continue
		if relever and not Aventure._pactes(joueur).get("mort", false):
			# Le héros est mort et s'est relevé au cachot : soigné, et un nouveau pacte pour la prochaine fois
			morts += 1
			if not Auto.journal_combats.is_empty() and Auto.journal_combats[-1].get("boss", false):
				defaites_gardien += 1
				if defaites_gardien >= DEFAITES_GARDIEN:
					fin = "le joueur automatique ne bat pas le gardien (%d défaites)" % defaites_gardien
					break
			joueur._d["points_de_vie"] = joueur.points_de_vie_max
			joueur._d["mana"] = joueur.mana_max
			Aventure._pactes(joueur)["mort"] = true
		var sp: SallePeinte = nav.salle_peinte
		var salle: Dictionary = donjon.salle_courante()
		var ici := str(donjon.salle_actuelle[1])
		if int(donjon.salle_actuelle[0]) != 1:
			fin = "a quitté l'étage 1"
			break
		if not visitees.has(ici):
			visitees[ici] = true
		var info: Dictionary = salle.get("salle_peinte", {})
		aretes[ici] = {}
		for i in info.get("sorties", []).size():
			var dest = info["sorties"][i]
			if dest != null and sp.sortie_praticable(i) and not oubliees.has("%s/%d" % [ici, i]):
				aretes[ici][i] = str(dest)
		for p in salle.get("presences", []):
			if p.get("genre", "") == "pnj" and p.get("etat", "actif") == "actif":
				personnages[p.get("id", 0)] = true
		# Un geôlier ou le Chevalier de la mort le poursuit dans la salle : il sort par la sortie la plus loin de lui
		var chasseur := _chasseur_menacant(sp)
		if not chasseur.is_empty():
			var loin := _sortie_loin_de(sp, info, chasseur["pos"])
			if loin >= 0:
				evitements += 1
				var avant_f: Array = donjon.salle_actuelle.duplicate()
				await _prendre_sortie(sp, loin)
				if donjon.salle_actuelle != avant_f:
					passages += 1
				continue
		# Le gardien est ici : on va à lui
		var boss := _entite(sp, "boss")
		if not boss.is_empty():
			if salle_gardien == "":
				atteint = horloge.temps - debut + Auto.actions_combat * TEMPS_ACTION_COMBAT 					+ personnages.size() * TEMPS_PERSONNAGE + visitees.size() * TEMPS_DECOUVERTE
			salle_gardien = ici
			await _aller_vers(sp, func(): return boss["pos"], 0.0)
			continue
		if _gardien_vaincu():
			gardien = true
			temps_gardien = horloge.temps - debut
			fin = "gardien vaincu"
			break
		# Gardien déjà vu (et pas vaincu) : on y retourne ; sinon la salle inconnue la plus proche
		var cible := _premier_pas(ici, aretes, visitees, salle_gardien)
		if cible < 0 and salle_gardien != "":
			# Chemin vers le gardien inconnu (réveil au cachot, loin de ce qu'il connaît) : il explore pour le retrouver
			cible = _premier_pas(ici, aretes, visitees)
		if cible < 0:
			fin = "plus aucune salle à explorer (gardien introuvable)"
			break
		var avant: Array = donjon.salle_actuelle.duplicate()
		var ok := await _prendre_sortie(sp, cible)
		if donjon.salle_actuelle != avant:
			passages += 1
		elif not ok:
			oubliees["%s/%d" % [ici, cible]] = true
			var noms: Array = sp.donnees.get("noms_sorties", [])
			abandonnees.append("%s%s : %s" % [sp.ident, " (miroir)" if sp.miroir else "",
				noms[cible] if cible < noms.size() else "sortie %d" % cible])
	_piloter(Vector2.ZERO)
	var mesure := horloge.temps - debut
	var actions := Auto.actions_combat
	var stats: Dictionary = U.ga(joueur, "statistiques", {})
	var combats := int(stats.get("combats_gagnes", 0)) + int(stats.get("fuites", 0))
	var total := mesure + actions * TEMPS_ACTION_COMBAT + personnages.size() * TEMPS_PERSONNAGE 		+ visitees.size() * TEMPS_DECOUVERTE
	var r := {"graine": graine, "gardien": gardien, "fin": fin, "mesure": mesure, "total": total, "morts": morts,
		"abandonnees": abandonnees, "evitements": evitements, "captures": int(stats.get("captures", 0)), "atteint": atteint}
	rapporter("")
	rapporter("== Partie %d : %s" % [graine, fin])
	rapporter("   temps mesuré (déplacements, fondus) : %s ; combats estimés : %s (%d actions) ; lecture estimée : %s (%d personnages) ; découverte des salles : %s"
		% [duree(mesure), duree(actions * TEMPS_ACTION_COMBAT), actions, duree(personnages.size() * TEMPS_PERSONNAGE),
			personnages.size(), duree(visitees.size() * TEMPS_DECOUVERTE)])
	rapporter("   GARDIEN TROUVÉ après (estimé) : %s" % (duree(atteint) if atteint >= 0 else "jamais"))
	rapporter("   TOTAL ESTIMÉ : %s%s ; morts (relevé au cachot) : %d ; fuites devant un chasseur : %d" % [duree(total),
		"" if gardien else " (sans avoir vaincu le gardien)", morts, evitements])
	for a in abandonnees:
		rapporter("   SORTIE ABANDONNÉE (zones à revoir ?) : %s" % a)
	if not gardien:
		var connues := {}
		for s in aretes:
			for i in aretes[s]:
				connues[aretes[s][i]] = s
		for id in donjon.plan_donjon[1]:
			var s := str(id)
			if visitees.has(s):
				continue
			var sd: Dictionary = donjon.plan_donjon[1][id]
			rapporter("   non visitée : salle %s%s%s%s" % [s, " (GARDIEN)" if sd.get("boss", false) else "",
				" (verrouillée)" if Aventure.verrouillee(donjon, s) else "",
				(" — entrée vue depuis la salle %s" % connues[s]) if connues.has(s) else " — aucune entrée vue"])
	rapporter("   salles visitées : %d sur %d ; passages : %d ; combats : %d (%d gagnés, %d fuites) ; captures : %d ; PV : %d/%d"
		% [visitees.size(), donjon.plan_donjon[1].size(), passages, combats, int(stats.get("combats_gagnes", 0)),
			int(stats.get("fuites", 0)), int(stats.get("captures", 0)), int(joueur.points_de_vie), int(joueur.points_de_vie_max)])
	for c in Auto.journal_combats:
		var issue: String = String(c["combat"].issue) if is_instance_valid(c["combat"]) or c["combat"] != null else "?"
		rapporter("   combat : %s — %d action(s), %s" % [", ".join(c["ennemis"]), c["actions"],
			{"victoire": "gagné", "fuite": "fui", "defaite": "perdu (mort du héros)", "": "interrompu"}.get(issue, issue)])
	if is_instance_valid(nav):
		nav.queue_free()
	await attendre(5)
	return r


## Chasseur (geôlier, Chevalier) qui poursuit le héros, ou à moins de 2,5 hauteurs de héros de lui.
func _chasseur_menacant(sp: SallePeinte) -> Dictionary:
	if sp.presences == null:
		return {}
	for e in sp.presences.entites:
		if not (e["p"].get("genre", "") in Aventure.CHASSEURS) or e.get("hors_champ", false):
			continue
		if e["etat"] in ["alerte", "poursuite"] or sp.presences._distance(e["pos"], sp.heros.position) < 2.5:
			return e
	return {}


## Sortie praticable dont le seuil est le plus loin de ``danger`` (-1 s'il n'y en a pas).
func _sortie_loin_de(sp: SallePeinte, info: Dictionary, danger: Vector2) -> int:
	var meilleure := -1
	var dist := -1.0
	var polys: Array = sp.donnees.get("sorties", [])
	for i in polys.size():
		if i >= info.get("sorties", []).size() or info["sorties"][i] == null or not sp.sortie_praticable(i):
			continue
		var centre := Vector2.ZERO
		for p in polys[i]:
			centre += p
		centre /= polys[i].size()
		var d := centre.distance_to(danger) - centre.distance_to(sp.heros.position) * 0.5
		if d > dist:
			dist = d
			meilleure = i
	return meilleure


func _gardien_vaincu() -> bool:
	return int(U.ga(joueur, "statistiques", {}).get("boss_vaincus", 0)) > 0


func _entite(sp: SallePeinte, genre: String) -> Dictionary:
	if sp.presences == null:
		return {}
	for e in sp.presences.entites:
		if e["p"].get("genre", "") == genre and e["p"].get("etat", "actif") == "actif":
			return e
	return {}


## Sortie à prendre dans ``ici`` pour aller vers la salle inconnue la plus proche (-1 : plus rien à explorer).
func _premier_pas(ici: String, aretes: Dictionary, visitees: Dictionary, but := "") -> int:
	var file := [[ici, -1]]
	var vues := {ici: true}
	while not file.is_empty():
		var courant: Array = file.pop_front()
		var salle: String = courant[0]
		for i in aretes.get(salle, {}):
			var dest: String = aretes[salle][i]
			if vues.has(dest):
				continue
			vues[dest] = true
			var premier: int = i if courant[1] < 0 else courant[1]
			if but != "" and dest == but:
				return premier
			if but == "" and not visitees.has(dest) and not Aventure.verrouillee(donjon, dest):
				return premier
			file.append([dest, premier])
	return -1


# ---------------------------------------------------------------------------
# Déplacements dans une salle
# ---------------------------------------------------------------------------

func _piloter(d: Vector2) -> void:
	if is_instance_valid(nav) and nav.salle_peinte != null:
		nav.salle_peinte.pilote_actif = true
		nav.salle_peinte.course = true
		nav.salle_peinte.pilote = d


## Va jusqu'à la sortie ``i`` et la franchit. Faux si on n'y arrive pas.
func _prendre_sortie(sp: SallePeinte, i: int) -> bool:
	var avant: Array = donjon.salle_actuelle.duplicate()
	var poly: PackedVector2Array = sp.donnees["sorties"][i]
	var centre := Vector2.ZERO
	for p in poly:
		centre += p
	centre /= poly.size()
	for essai in ESSAIS:
		await _aller_vers(sp, func(): return centre, 4.0, poly)
		if not is_instance_valid(nav) or donjon.salle_actuelle != avant or nav.passage_en_cours:
			while is_instance_valid(nav) and nav.passage_en_cours and not Statistiques.mort:
				await process_frame
			return true
		# Au seuil : pousser vers le centre de la sortie (porte qui s'ouvre, passage)
		var t0 := horloge.temps
		while horloge.temps - t0 < 3.0 and is_instance_valid(nav) and donjon.salle_actuelle == avant \
				and not nav.passage_en_cours and not Statistiques.mort:
			_piloter((centre - sp.heros.position).normalized())
			await process_frame
		if not is_instance_valid(nav) or donjon.salle_actuelle != avant or nav.passage_en_cours:
			while is_instance_valid(nav) and nav.passage_en_cours and not Statistiques.mort:
				await process_frame
			return true
		if "verrouill" in String(nav.message_nav):
			return false
	return false


## Va vers ``cible`` (fonction qui renvoie un point, l'entité peut bouger) en suivant un chemin libre. ``arret`` :
## distance d'arrivée (px). ``zone`` : polygone d'arrivée (une sortie : on s'arrête au point libre le plus proche).
func _aller_vers(sp: SallePeinte, cible: Callable, arret: float, zone := PackedVector2Array()) -> void:
	var salle_depart: Array = donjon.salle_actuelle.duplicate()
	var chemin := _chemin(sp, sp.heros.position, cible.call(), zone)
	var t_progres := horloge.temps
	var meilleure := INF
	var replans := 0
	while is_instance_valid(nav) and not nav.passage_en_cours and donjon.salle_actuelle == salle_depart \
			and not Statistiques.mort:
		var pos: Vector2 = sp.heros.position
		if chemin.is_empty():
			break
		var but: Vector2 = chemin[0]
		if pos.distance_to(but) < 5.0:
			chemin.remove_at(0)
			if chemin.is_empty() and pos.distance_to(cible.call()) <= maxf(arret, 6.0):
				break
			continue
		_piloter((but - pos).normalized())
		var reste := pos.distance_to(chemin[-1])
		if reste < meilleure - 2.0:
			meilleure = reste
			t_progres = horloge.temps
		elif horloge.temps - t_progres > BLOCAGE:
			replans += 1
			if replans > ESSAIS:
				break
			chemin = _chemin(sp, pos, cible.call(), zone)
			meilleure = INF
			t_progres = horloge.temps
		await process_frame
		# Cible qui bouge (gardien) : chemin refait de temps en temps ; un chasseur arrive : on arrête pour fuir
		if not _chasseur_menacant(sp).is_empty() and zone.is_empty():
			break
		if zone.is_empty() and arret == 0.0 and Engine.get_process_frames() % 30 == 0:
			chemin = _chemin(sp, sp.heros.position, cible.call(), zone)
	_piloter(Vector2.ZERO)


## Chemin libre (liste de points) de ``depart`` vers ``but`` sur une grille ; si ``zone`` est donnée, le but est la
## première case libre dans la zone ou à moins de 10 px d'elle.
func _chemin(sp: SallePeinte, depart: Vector2, but: Vector2, zone: PackedVector2Array) -> Array:
	var l := float(sp.fond.get_width())
	var h := float(sp.fond.get_height())
	var cle := func(p: Vector2) -> Vector2i: return Vector2i(int(p.x / PAS_GRILLE), int(p.y / PAS_GRILLE))
	var point := func(c: Vector2i) -> Vector2: return Vector2((c.x + 0.5) * PAS_GRILLE, (c.y + 0.5) * PAS_GRILLE)
	var d0: Vector2i = cle.call(depart)
	var arrivee := Vector2i(-1, -1)
	var b: Vector2i = cle.call(but)
	var precedent := {d0: d0}
	var file := [d0]
	var libre := {}
	# Les autres sorties sont évitées (on ne quitte pas la salle par erreur en chemin)
	var autres := []
	var polys: Array = sp.donnees.get("sorties", [])
	for k in polys.size():
		if polys[k] != zone:
			autres.append(polys[k])
	var dans_sortie := func(p: Vector2) -> bool:
		for q in autres:
			if Geometry2D.is_point_in_polygon(p, q):
				return true
		return false
	var est_but := func(c: Vector2i) -> bool:
		var p: Vector2 = point.call(c)
		if zone.is_empty():
			return c == b or p.distance_to(but) < PAS_GRILLE * 1.5
		if Geometry2D.is_point_in_polygon(p, zone):
			return true
		for k in zone.size():
			if Geometry2D.get_closest_point_to_segment(p, zone[k], zone[(k + 1) % zone.size()]).distance_to(p) < 10.0:
				return true
		return false
	while not file.is_empty():
		var c: Vector2i = file.pop_front()
		if est_but.call(c):
			arrivee = c
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1),
				Vector2i(1, -1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if precedent.has(n):
				continue
			var p: Vector2 = point.call(n)
			if p.x < 0 or p.y < 0 or p.x > l or p.y > h:
				continue
			if not libre.has(n):
				libre[n] = sp.libre(p) and not dans_sortie.call(p)
			if not libre[n]:
				continue
			precedent[n] = c
			file.append(n)
	if arrivee == Vector2i(-1, -1):
		return [but]
	var cases := []
	var c := arrivee
	while c != d0:
		cases.push_front(point.call(c))
		c = precedent[c]
	# Raccourcis : on saute les points tant que la ligne droite reste libre
	var lisse := []
	var i := 0
	var pos := depart
	while i < cases.size():
		var j := cases.size() - 1
		while j > i and not _ligne_libre(sp, pos, cases[j]):
			j -= 1
		lisse.append(cases[j])
		pos = cases[j]
		i = j + 1
	if zone.is_empty():
		lisse.append(but)
	return lisse


func _ligne_libre(sp: SallePeinte, a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 4.0) + 1
	for k in n + 1:
		if not sp.libre(a.lerp(b, float(k) / n)):
			return false
	return true
