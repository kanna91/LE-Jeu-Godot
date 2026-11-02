class_name QuetesPrisonniers
extends RefCounted
## Quêtes des prisonniers des cellules (2026-11-02, textes et règles de l'utilisateur).
##
## Tout le contenu est dans ``donnees/prisonniers.json`` (clé « quetes », mode d'emploi dans « _lisez_moi ») : ce
## fichier est un petit moteur qui le joue, pour qu'on puisse changer les quêtes sans toucher au code.
##
## - ``assigner`` : à la préparation d'un étage, chaque quête pas encore posée dans la partie reçoit une cellule
##   (zone de dialogue « prisonniers ») d'une prison de cet étage, si l'étage est dans ses « etages ».
## - ``ecouter`` : le héros parle au prisonnier ; joue l'étape en cours (texte, actions, répliques répétées).
## - ``donner`` : le héros donne l'objet demandé ; passe à l'étape suivante et la joue.
## - ``evenement`` : quelque chose est arrivé (élite vaincu...) ; les étapes qui l'« attendent » avancent.
##
## Ce qui doit se passer à l'écran (un ennemi qui entre, un combat tout de suite) revient dans « suites » :
## l'écran d'exploration s'en charge (menu_navigation._suites_quete).
##
## L'avancement est rangé dans la présence du prisonnier (« quete », « etape », « vu », « rep ») et dans le donjon
## (« quetes_prisonniers » : quêtes posées, événements, élites porteurs), donc dans la sauvegarde.

## Rang d'un bijou de récompense : le meilleur rang des objets de l'étage (étage + 1 : commun à l'étage 1) +
## « rang_bonus » (plafonné à 6) ; +2 à l'étage 1 : rare (décision de l'utilisateur, 2026-11-02).
const RANG_MAX := 6
## PV d'un élite renforcé (« élite+ ») : × ce facteur.
const FACTEUR_RENFORCE := 1.5


static func definitions() -> Array:
	return Rencontres.textes_prisonniers().get("quetes", [])


static func definition(id: String) -> Dictionary:
	for q in definitions():
		if String(q.get("id", "")) == id:
			return q
	return {}


## Avancement global des quêtes : {places: {id: étage}, evenements: {nom: vrai}, porteurs: {objet: id de présence}}.
static func memoire(donjon) -> Dictionary:
	var m = U.ga(donjon, "quetes_prisonniers", null)
	if not (m is Dictionary):
		m = {"places": {}, "evenements": {}, "porteurs": {}}
		donjon._d["quetes_prisonniers"] = m
	return m


# ---------------------------------------------------------------------------
# Placement
# ---------------------------------------------------------------------------

## Donne leurs quêtes aux prisonniers de l'étage. ``cellules`` : [[présence, image], ...] (les prisonniers ordinaires
## posés par Aventure._poser_prisonniers). Les cellules des images de prison passent avant les autres zones.
## Une quête dont l'étage est passé sans cellule libre est posée au prochain étage qui en a.
static func assigner(donjon, etage: int, cellules: Array) -> void:
	var m := memoire(donjon)
	var libres := cellules.filter(func(c): return PlanSalles.est_prison(String(c[1])) and not c[0].has("quete"))
	if libres.is_empty():
		libres = cellules.filter(func(c): return not c[0].has("quete"))
	libres.shuffle()
	for q in definitions():
		var id := String(q.get("id", ""))
		if id == "" or m["places"].has(id) or libres.is_empty():
			continue
		var etages: Array = q.get("etages", [1])
		var plus_bas := 1 << 20
		for e in etages:
			plus_bas = mini(plus_bas, int(e))
		if not (etage in etages.map(func(e): return int(e))) and etage < plus_bas:
			continue
		var p: Dictionary = libres.pop_back()[0]
		p["quete"] = id
		p["etape"] = String(q.get("debut", ""))
		p["vu"] = false
		p["rep"] = 0
		m["places"][id] = etage


# ---------------------------------------------------------------------------
# Discussion
# ---------------------------------------------------------------------------

## Nouveau résultat de discussion : lignes à afficher, objet qu'on peut donner, suites pour l'écran.
static func _resultat() -> Dictionary:
	return {"lignes": [], "donner": "", "suites": []}


## Le héros parle au prisonnier ``p`` (qui a une « quete ») : joue l'étape en cours. Renvoie
## {lignes: [texte...], donner: nom de l'objet qu'il peut donner (« » sinon), suites: [...]}.
static func ecouter(donjon, p: Dictionary) -> Dictionary:
	var res := _resultat()
	var q := definition(String(p.get("quete", "")))
	if q.is_empty():
		return res
	var etape := _etape(q, p)
	var attente: Dictionary = etape.get("attendre", {})
	if not attente.is_empty() and a_eu_lieu(donjon, String(attente.get("evenement", ""))):
		_aller(p, String(attente.get("etape", "")))
		etape = _etape(q, p)
	if not p.get("vu", false):
		_jouer(donjon, p, q, res)
	else:
		var repete: Array = etape.get("repete", [])
		if not repete.is_empty():
			var k := int(p.get("rep", 0))
			res["lignes"].append(String(repete[k % repete.size()] if etape.get("boucle", false) else repete[mini(k, repete.size() - 1)]))
			p["rep"] = k + 1
		elif not etape.get("texte", []).is_empty():
			res["lignes"].append(String(etape["texte"][-1]))
		_actions(donjon, p, etape.get("actions_repete", []), res)
	_proposer_don(donjon, p, q, res)
	_remplacer(donjon, p, res)
	return res


## Le héros donne l'objet que demande l'étape en cours : il le perd, l'étape suivante est jouée. Même résultat
## qu'``ecouter`` (vide si le héros n'a plus l'objet).
static func donner(donjon, p: Dictionary) -> Dictionary:
	var res := _resultat()
	var q := definition(String(p.get("quete", "")))
	var don: Dictionary = _etape(q, p).get("donner", {}) if not q.is_empty() else {}
	var objet = objet_demande(donjon.personnage, don)
	if objet == null:
		return res
	retirer_du_heros(donjon.personnage, objet)
	_aller(p, String(don.get("etape", "")))
	_jouer(donjon, p, q, res)
	_proposer_don(donjon, p, q, res)
	_remplacer(donjon, p, res)
	return res


static func _etape(q: Dictionary, p: Dictionary) -> Dictionary:
	return q.get("etapes", {}).get(String(p.get("etape", "")), {})


static func _aller(p: Dictionary, etape: String) -> void:
	p["etape"] = etape
	p["vu"] = false
	p["rep"] = 0


## Première fois dans l'étape : son texte, ses actions, puis l'étape « suivant » pour la prochaine discussion.
static func _jouer(donjon, p: Dictionary, q: Dictionary, res: Dictionary) -> void:
	var etape := _etape(q, p)
	for l in etape.get("texte", []):
		res["lignes"].append(String(l))
	p["vu"] = true
	_actions(donjon, p, etape.get("actions", []), res)
	if etape.has("suivant") and p.get("etat", "actif") == "actif":
		_aller(p, String(etape["suivant"]))
		p["vu"] = false


static func _proposer_don(donjon, p: Dictionary, q: Dictionary, res: Dictionary) -> void:
	if p.get("etat", "actif") != "actif":
		return
	var don: Dictionary = _etape(q, p).get("donner", {})
	var objet = objet_demande(donjon.personnage, don) if not don.is_empty() else null
	res["donner"] = String(objet.nom) if objet != null else ""


## « {direction} » dans les textes : où se trouve l'élite qui porte l'objet de la quête.
static func _remplacer(donjon, p: Dictionary, res: Dictionary) -> void:
	for i in res["lignes"].size():
		var l: String = res["lignes"][i]
		if "{direction}" in l:
			res["lignes"][i] = l.replace("{direction}", direction_porteur(donjon, p))


# ---------------------------------------------------------------------------
# Actions
# ---------------------------------------------------------------------------

static func _actions(donjon, p: Dictionary, actions: Array, res: Dictionary) -> void:
	var joueur = donjon.personnage
	var etage := int(donjon.salle_actuelle[0])
	for a in actions:
		if not (a is Dictionary):
			continue
		if a.has("karma"):
			var n := int(a["karma"])
			var moralite = U.ga(donjon, "moralite", null)
			if not (moralite is Dictionary):
				moralite = {"clemence": 0, "cruaute": 0}
				donjon._d["moralite"] = moralite
			var cle := "clemence" if n > 0 else "cruaute"
			moralite[cle] = int(moralite.get(cle, 0)) + 1
			var suite := Karma.changer(donjon, n)
			res["lignes"].append(("Karma %s%d. %s" % ["+" if n > 0 else "", n, suite]).strip_edges())
		if a.get("sort_aleatoire", false):
			res["lignes"].append(apprendre_sort(joueur, etage))
		if a.has("placer_objet"):
			placer_objet(donjon, String(a["placer_objet"]), String(a.get("lieu", "")), p)
		if a.has("objet_sur_elite"):
			confier_a_elite(donjon, String(a["objet_sur_elite"]), String(a.get("lieu", "loin")))
		if a.has("elite_attaque"):
			var regle: Dictionary = a["elite_attaque"] if a["elite_attaque"] is Dictionary else {}
			var suite := {"faire_entrer": nouvel_elite(donjon, regle)}
			if regle.get("depuis_prisonnier", false) and p.get("pos") is Array:
				suite["depuis"] = p["pos"]  # le prisonnier était l'élite : il surgit de sa cellule
			res["suites"].append(suite)
		if a.has("chevalier"):
			var c := chevalier_ici(donjon)
			res["suites"].append({"combat" if String(a["chevalier"]) == "combat" else "faire_entrer": c})
		if a.has("donner_bijou"):
			var rang := clampi(etage + 1 + int(a.get("rang_bonus", 0)), 1, RANG_MAX)
			var bijou = GenerationObjets.generer_objet(String(a["donner_bijou"]), rang)
			var equipe = joueur.recevoir_objet(bijou)
			res["lignes"].append("Vous recevez %s%s." % [bijou.nom, " (équipé)" if equipe else ""])
		if a.has("disparaitre"):
			p["etat"] = "parti"
			if String(a["disparaitre"]) != "":
				res["lignes"].append(String(a["disparaitre"]))
		if a.has("message"):
			res["lignes"].append(String(a["message"]))


## Le héros apprend un sort au hasard parmi ceux qu'il peut apprendre (palier jusqu'à l'étage, comme un grimoire).
static func apprendre_sort(joueur, etage: int) -> String:
	var candidats := []
	for m in joueur.magies_disponibles:
		if Aventure._palier(m) <= clampi(etage, 1, 5):
			candidats.append(m)
	if candidats.is_empty():
		return "Il vous montre un sort... que vous connaissez déjà."
	var sort = candidats.pick_random()
	joueur.magies_disponibles.erase(sort)
	joueur.magies_apprises.append(sort)
	return "Vous apprenez le sort %s !" % sort.nom


## Pose l'objet de quête ``nom`` au sol de la salle ``lieu`` de l'étage (« cuisine » : la cuisine du bloc cuisine ;
## sinon, ou faute de cuisine, une salle ordinaire au hasard). À ramasser (Aventure.utiliser_objet).
static func placer_objet(donjon, nom: String, lieu: String, _prisonnier := {}) -> void:
	var etage := int(donjon.salle_actuelle[0])
	var salles: Dictionary = donjon.plan_donjon[etage]
	var choix := []
	if lieu == "cuisine":
		for i in salles:
			if String(salles[i].get("bloc_salle", "")) == "cuisine":
				choix.append(i)
	if choix.is_empty():
		choix = Aventure.salles_ordinaires(donjon, etage)
	if choix.is_empty():
		return
	var salle: Dictionary = salles[choix.pick_random()]
	if not salle.has("presences"):
		salle["presences"] = []
	salle["presences"].append({"id": Aventure._nouvel_id(Aventure.meta(donjon, etage)), "genre": "objet",
		"sous": "objet_quete", "objet": nom, "etat": "actif"})


## Confie l'objet ``nom`` à un élite de l'étage (« crypte » : dans une salle des catacombes s'il y en a ; « loin » :
## loin du héros), à prendre sur son corps. Un groupe ordinaire devient élite s'il n'y en a pas ; sinon un élite seul
## est créé.
static func confier_a_elite(donjon, nom: String, lieu: String) -> void:
	var etage := int(donjon.salle_actuelle[0])
	var salles: Dictionary = donjon.plan_donjon[etage]
	var ici := str(donjon.salle_actuelle[1])
	var dist := Aventure.distances_depuis(salles, ici)
	var ordinaires: Array = Aventure.salles_pour_ennemis(donjon, etage).filter(
		func(i): return str(i) != ici and not Aventure.salle_paisible(salles[i]))
	var choix := ordinaires
	if lieu == "crypte":
		var cryptes := ordinaires.filter(func(i): return Zones.zone_salle(salles[i]) == "crypte")
		if not cryptes.is_empty():
			choix = cryptes
	else:
		var loin := ordinaires.filter(func(i): return int(dist.get(i, 0)) >= 4)
		if not loin.is_empty():
			choix = loin
	if choix.is_empty():
		return
	var elites := []
	var groupes := []
	var sans_elite := []  # groupes d'une zone au nombre d'élites fixé (cryptes : un seul féticheur) : pas d'élite de plus
	for i in choix:
		for g in salles[i].get("presences", []):
			if g.get("genre") == "groupe" and g.get("etat", "actif") == "actif" and not g.get("pacifique", false):
				if g.get("elite", false):
					elites.append(g)
				elif Zones.elites_fixes(String(g.get("zone_ennemis", ""))):
					sans_elite.append(g)
				else:
					groupes.append(g)
	var porteur: Dictionary
	if not elites.is_empty():
		porteur = elites.pick_random()
	elif not groupes.is_empty():
		porteur = groupes.pick_random()
		porteur["elite"] = true
	elif not sans_elite.is_empty():
		porteur = sans_elite.pick_random()  # l'élite de la zone est déjà vaincue : un ennemi ordinaire le porte
	else:
		var salle: Dictionary = salles[choix.pick_random()]
		var zone := Zones.zone_salle(salle)
		porteur = {"id": Aventure._nouvel_id(Aventure.meta(donjon, etage)), "genre": "groupe", "etat": "actif",
			"nombre": 1, "elite": not Zones.elites_fixes(zone), "pacifique": false}
		if zone != "":
			porteur["zone_ennemis"] = zone
		if not salle.has("presences"):
			salle["presences"] = []
		salle["presences"].append(porteur)
	if not (porteur.get("objets_quete") is Array):
		porteur["objets_quete"] = []
	porteur["objets_quete"].append(nom)
	memoire(donjon)["porteurs"][nom] = [etage, int(porteur["id"])]


## « vers le nord-est, à 5 salles d'ici » : où est l'élite qui porte l'objet demandé par l'étape du prisonnier ``p``.
static func direction_porteur(donjon, p: Dictionary) -> String:
	var q := definition(String(p.get("quete", "")))
	var nom := ""
	for e in q.get("etapes", {}).values():
		for a in e.get("actions", []):
			if a is Dictionary and a.has("objet_sur_elite"):
				nom = String(a["objet_sur_elite"])
	var porteur = memoire(donjon)["porteurs"].get(nom, null)
	if not (porteur is Array):
		return "quelque part dans l'étage"
	var salles: Dictionary = donjon.plan_donjon.get(int(porteur[0]), {})
	var ici := str(donjon.salle_actuelle[1])
	for i in salles:
		for g in salles[i].get("presences", []):
			if int(g.get("id", -1)) == int(porteur[1]) and g.get("etat", "actif") == "actif":
				var d: Vector2i = salles[i].get("position", Vector2i.ZERO) - salles[ici].get("position", Vector2i.ZERO)
				var n := int(Aventure.distances_depuis(salles, ici).get(i, 0))
				return "%s, à %d salle%s d'ici" % [_cap(d), n, "s" if n > 1 else ""]
	return "quelque part dans l'étage"


## Direction lisible d'un écart sur la carte (haut de la carte = nord).
static func _cap(d: Vector2i) -> String:
	var ns := "nord" if d.y > 0 else ("sud" if d.y < 0 else "")
	var eo := "est" if d.x > 0 else ("ouest" if d.x < 0 else "")
	if ns != "" and eo != "" and (absi(d.x) * 3 < absi(d.y) or absi(d.y) * 3 < absi(d.x)):
		return "vers le " + (ns if absi(d.y) > absi(d.x) else eo)
	if ns != "" and eo != "":
		return "vers le %s-%s" % [ns, eo]
	return "vers le " + (ns + eo) if ns + eo != "" else "tout près"


## Un élite (ou élite+ avec ``regle.renforce``) qui vient attaquer le héros, posé dans la salle du héros ; il dira
## ``regle.evenement`` quand il sera vaincu ; ``regle.nom`` : son nom en combat. L'écran le fait entrer par une porte
## (ou surgir à la place du prisonnier : ``depuis_prisonnier``).
static func nouvel_elite(donjon, regle: Dictionary) -> Dictionary:
	var etage := int(donjon.salle_actuelle[0])
	var g := {"id": Aventure._nouvel_id(Aventure.meta(donjon, etage)), "genre": "groupe", "etat": "actif", "nombre": 1,
		"elite": true, "pacifique": false, "seul": true}
	if regle.get("renforce", false):
		g["renforce"] = true
	if String(regle.get("nom", "")) != "":
		g["nom_elite"] = String(regle["nom"])
	if String(regle.get("evenement", "")) != "":
		g["evenement_victoire"] = String(regle["evenement"])
	var salle: Dictionary = donjon.salle_courante()
	if not salle.has("presences"):
		salle["presences"] = []
	salle["presences"].append(g)
	return g


## Le Chevalier de la mort de l'étage (le plus proche) vient dans la salle du héros ; s'il n'y en a pas, un nouveau.
static func chevalier_ici(donjon) -> Dictionary:
	var etage := int(donjon.salle_actuelle[0])
	var salles: Dictionary = donjon.plan_donjon[etage]
	var ici := str(donjon.salle_actuelle[1])
	var dist := Aventure.distances_depuis(salles, ici)
	var meilleur := []
	for c in Aventure.chasseurs(donjon, etage):
		if c[0]["genre"] == "imbattable" and (meilleur.is_empty() or int(dist.get(c[1], 99)) < int(dist.get(meilleur[1], 99))):
			meilleur = c
	if meilleur.is_empty():
		var p := {"id": Aventure._nouvel_id(Aventure.meta(donjon, etage)), "genre": "imbattable", "etat": "actif"}
		if not salles[ici].has("presences"):
			salles[ici]["presences"] = []
		salles[ici]["presences"].append(p)
		return p
	if str(meilleur[1]) != ici:
		Aventure._deplacer(salles, meilleur[0], ici)
	meilleur[0].erase("but")
	return meilleur[0]


# ---------------------------------------------------------------------------
# Événements et objets
# ---------------------------------------------------------------------------

static func evenement(donjon, nom: String) -> void:
	if nom != "":
		memoire(donjon)["evenements"][nom] = true


static func a_eu_lieu(donjon, nom: String) -> bool:
	return nom != "" and memoire(donjon)["evenements"].has(nom)


## Crée l'objet de quête ``nom`` (clé « objets » de prisonniers.json) : objet divers ou bijou à bonus fixes.
static func creer_objet(nom: String):
	var d: Dictionary = Rencontres.textes_prisonniers().get("objets", {}).get(nom, {})
	if d.has("equipement"):
		var o := Armure.nouvelle(nom, "armure", String(d["equipement"]), String(d.get("description", "")), int(d.get("valeur", 0)))
		o.rang = 1
		o.famille = "offensif"
		o.orientation = "magique"
		o.option = "caracteristique"
		o.points = 0
		o.unique = null
		for c in Caracteristiques.LISTE:
			o.set(c, 0)
		var bonus: Dictionary = d.get("bonus", {})
		for c in bonus:
			o.set(String(c), int(bonus[c]))
		o._d["description"] = String(d.get("description", ""))
		o._d["objet_quete"] = true
		return o
	var o := ObjetsDivers.creer(nom, String(d.get("sorte", "quete")), int(d.get("valeur", 0)), String(d.get("description", "")))
	o._d["objet_quete"] = true
	return o


## Objets du héros (inventaire et équipement).
static func objets_du_heros(joueur) -> Array:
	var liste: Array = U.ga(joueur, "inventaire", []).duplicate()
	for e in U.ga(joueur, "equipements", {}).values():
		if e != null:
			liste.append(e)
	return liste


## Objet du héros qui répond à ``don`` ({objet: nom} ou {categorie: « nourriture » / « potion_soin »}), ou null.
static func objet_demande(joueur, don: Dictionary):
	for o in objets_du_heros(joueur):
		if don.has("objet") and String(o.nom) == String(don["objet"]):
			return o
		match String(don.get("categorie", "")):
			"nourriture":
				if U.ga(o, "type_objet", "") == "divers" and U.ga(o, "sorte", "") == "nourriture":
					return o
			"potion_soin":
				var effet = U.ga(o, "effet", null)
				if U.ga(o, "type_objet", "") == "consommable" and effet is Dictionary and effet.get("type") == "pv":
					return o
	return null


## Le héros perd ``objet`` (déséquipé d'abord s'il le porte).
static func retirer_du_heros(joueur, objet) -> void:
	for cle in joueur.equipements:
		if joueur.equipements[cle] == objet:
			joueur.desequiper_item(cle)
	joueur.retirer_objet_inventaire(objet)


## Objets de quête portés par une présence vaincue (élite) : donnés au héros ; renvoie le message (vide sinon).
static func prendre_objets(joueur, p: Dictionary) -> String:
	var noms: Array = p.get("objets_quete", [])
	if noms.is_empty():
		return ""
	var trouves := []
	for nom in noms:
		var o = creer_objet(String(nom))
		joueur.recevoir_objet(o)
		trouves.append(String(nom))
	p["objets_quete"] = []
	return "Vous trouvez : %s !" % ", ".join(trouves)
