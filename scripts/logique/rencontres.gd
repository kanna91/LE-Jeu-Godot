class_name Rencontres
extends RefCounted
## Personnages du donjon d'aventure et leurs dialogues (Aventure : présences de genre « pnj »).
##
## - **Diablotin** (demande de l'utilisateur, 2026-10-27) : il transmet au compte-gouttes des informations sur les
##   mécaniques du jeu, le Chevalier de la mort, l'étage et, après une capture, l'endroit où sont les affaires du
##   héros. Il peut **mentir, mais seulement sur le donjon, jamais sur les ennemis** (fiche de l'utilisateur) : une
##   réponse à « Cet étage ? » sur trois (CHANCE_MENSONGE) est un mensonge (``mensonges_diablotin``), noté au journal
##   comme une vraie information. Tout ce qui touche les ennemis et les affaires confisquées reste vrai.
##   **Aucun diablotin ne dit deux fois la même chose dans une partie** (``donjon.diablotins_dits``), ni jamais,
##   même dans une autre partie, une information sur un ennemi (glossaire du compte : ``Compte``)
##   ; chacun répond à DIABLOTIN_REPONSES questions au plus puis disparaît ; chaque réponse va dans le **journal**
##   du joueur (``noter_journal``, écran ``journal.gd``, touche J). Le lore viendra dans ``LORE``.
## - **Gobelin blessé** (choix moral) : le soigner avec une potion (il donne une clé ou un grimoire), l'épargner
##   (il dit un secret vrai), ou l'achever (c'est un ennemi qu'on ne doit pas tuer : un Sans-Visage de plus).
## - **Prisonnier** (choix moral) : briser ses chaînes (bruyant : les ennemis de la salle accourent ; il donne une
##   clé), lui demander ce qu'il sait (il dit vrai), ou le laisser.
## - **Autel de sang** : offrir son sang (PV) contre un point de caractéristique, ou refuser.
## - **Succube** (un étage sur deux, pas de combat) : un pacte contre une part des PV max, pour toujours
##   (``Aventure.PACTES``), puis elle disparaît ; on peut refuser et revenir.
## Chaque choix est un acte de Karma.ACTES (karma ±, compté dans ``donjon.moralite`` : clémence, cruauté).
## **Textes** : ``donnees/dialogues.json`` (``Dialogues``, modifiables dans l'éditeur de zones, bouton « Dialogues »,
## 2026-11-04). Commis de la cuisine et du cellier (2026-11-04) : ils expliquent la cuisine et où trouver des ingrédients.

## Autel : part des PV max offerts, et caractéristiques possibles.
const SANG_AUTEL := 0.4
## Mana ajoutée le 2026-10-29 (demande de l'utilisateur).
const CARACTERISTIQUES := Caracteristiques.NOMS
const COULEUR_DIABLOTIN := Color8(190, 120, 230)
## Questions auxquelles répond un diablotin avant de disparaître (choix de Claude).
const DIABLOTIN_REPONSES := 2
## Part des réponses à « Cet étage ? » qui sont des mensonges sur le donjon (décision de l'utilisateur, 2026-10-27).
const CHANCE_MENSONGE := 1.0 / 3.0
## Ce que les diablotins disent du Chevalier de la mort, dans cet ordre, **un élément à la fois** (demande de
## l'utilisateur, 2026-10-31 : avant, la première réponse listait toutes ses résistances d'un coup) : [clé, texte]
## (``diablotin/chevalier`` de dialogues.json, dans l'ordre du fichier).
## Ces informations vont au **glossaire du compte** (``Compte``) : elles ne sont jamais redites, même dans une autre
## partie. Fiche de l'utilisateur « chevalier de la mort.odt » ; règles dans ``Aventure.CHEVALIER``. Sa limite de
## dégâts subis (1 ou 2 par coup) reste **secrète** : aucun diablotin n'en parle (décision de l'utilisateur).
static func infos_chevalier() -> Array:
	var t := Dialogues.table("diablotin/chevalier")
	return t.keys().map(func(k): return [k, String(t[k])])


const NOM_CHEVALIER := "Chevalier de la mort"
## Conseils sur les mécaniques du jeu : [clé, texte, ennemi] (``diablotin/conseils`` de dialogues.json). Un conseil
## qui parle d'un ennemi (ENNEMIS_CONSEILS) est une information générale sur lui : il va aussi au glossaire du compte
## et n'est jamais redit, même dans une autre partie ; les autres ne valent que pour la partie.
const ENNEMIS_CONSEILS := {"course": "Gobelins", "pacifiques": "Gobelins", "geolier": "Geôlier"}


static func astuces() -> Array:
	var t := Dialogues.table("diablotin/conseils")
	return t.keys().map(func(k): return [k, String(t[k]), ENNEMIS_CONSEILS.get(k, "")])


## Lore du jeu et des personnages, raconté par les diablotins : [clé, texte] (``diablotin/lore``, à écrire par
## l'utilisateur ; clé : numéro de la ligne).
static func lore() -> Array:
	var l := Dialogues.liste("diablotin/lore")
	var r := []
	for k in l.size():
		if String(l[k]).strip_edges() != "":
			r.append([str(k), String(l[k])])
	return r


const COULEUR_SUCCUBE := Color8(215, 120, 210)
## Ce que fait chaque pacte, dit au joueur (``succube/effets_pactes``).
static func effet_pacte(cle: String) -> String:
	return Dialogues.texte("succube/effets_pactes/" + cle)


## Sorties d'une salle peinte, vues par le héros (toujours tourné vers le nord, comme la carte).
const SORTIES := {"nord": "la sortie du fond (nord)", "sud": "la sortie du bas (sud)", "est": "la sortie de droite (est)",
	"ouest": "la sortie de gauche (ouest)"}


## Chemin vers la salle ``vers`` depuis la salle actuelle (2026-10-30 : « l'est, l'ouest » était trop vague, demande de
## l'utilisateur) : nombre de salles et sortie à prendre ici (« à 3 salles d'ici, en partant par la sortie de gauche
## (ouest) »). Plus court chemin par les passages (Aventure.distances_depuis).
static func direction(donjon, vers: String) -> String:
	var etage := int(donjon.salle_actuelle[0])
	var salles: Dictionary = donjon.plan_donjon[etage]
	var ici := str(donjon.salle_actuelle[1])
	if vers == ici or not salles.has(vers) or not salles.has(ici):
		return "ici même"
	var dist := Aventure.distances_depuis(salles, vers)
	if not dist.has(ici):
		var la: Vector2i = salles[vers].get("position", Vector2i.ZERO)
		return _texte_direction(la - salles[ici].get("position", Vector2i.ZERO))
	var n: int = dist[ici]
	var pas := ""
	for v in salles[ici].get("connections", []):
		if dist.get(str(v), 1 << 20) == n - 1:
			pas = str(v)
			break
	return _texte_chemin(n, _sortie(salles, ici, pas))


## Sortie (« nord », « sud », « est », « ouest ») de la salle ``ici`` qui mène à la salle voisine ``voisin``.
static func _sortie(salles: Dictionary, ici: String, voisin: String) -> String:
	var d: Vector2i = salles.get(voisin, {}).get("position", Vector2i.ZERO) - salles[ici].get("position", Vector2i.ZERO)
	if absi(d.x) > absi(d.y):
		return "est" if d.x > 0 else "ouest"
	return "nord" if d.y >= 0 else "sud"


static func _texte_chemin(n: int, sortie: String) -> String:
	if n <= 1:
		return "juste à côté, par " + SORTIES.get(sortie, sortie)
	return "à %d salles d'ici, en partant par %s" % [n, SORTIES.get(sortie, sortie)]


static func _texte_direction(d: Vector2i) -> String:
	if d == Vector2i.ZERO:
		return "ici même"
	var ns := "nord" if d.y > 0 else "sud"
	var eo := "est" if d.x > 0 else "ouest"
	if absi(d.x) > absi(d.y) * 2:
		return "à l'" + eo
	if absi(d.y) > absi(d.x) * 2:
		return "au " + ns
	return "au %s-%s" % [ns, eo]


## Fausse indication, du même genre que la vraie : une sortie de la salle actuelle et 1 à 6 salles.
static func _direction_fausse(donjon, vraie: String) -> String:
	var etage := int(donjon.salle_actuelle[0])
	var salles: Dictionary = donjon.plan_donjon[etage]
	var ici := str(donjon.salle_actuelle[1])
	var sorties := []
	if salles.has(ici):
		for v in salles[ici].get("connections", []):
			sorties.append(_sortie(salles, ici, str(v)))
	if sorties.is_empty():
		sorties = SORTIES.keys()
	for _k in 20:
		var t := _texte_chemin(randi_range(1, 6), sorties.pick_random())
		if t != vraie:
			return t
	return _texte_chemin(randi_range(7, 9), sorties.pick_random())


## Salle (id) de l'étage qui contient une présence vérifiant ``filtre`` (vide : aucune).
static func _salle_avec(donjon, filtre: Callable) -> String:
	var etage := int(donjon.salle_actuelle[0])
	var trouvees := []
	for i in donjon.plan_donjon[etage]:
		for p in donjon.plan_donjon[etage][i].get("presences", []):
			if p.get("etat") == "actif" and filtre.call(p):
				trouvees.append(i)
	return trouvees.pick_random() if not trouvees.is_empty() else ""


# ---------------------------------------------------------------------------
# Diablotin
# ---------------------------------------------------------------------------

## Une réponse du diablotin sur ``sujet`` (« boss », « etage », « ennemis ») : vraie si ``vraie``.
static func phrase(donjon, sujet: String, vraie: bool) -> String:
	var m := Aventure.meta(donjon, int(donjon.salle_actuelle[0]))
	match sujet:
		"gardien":
			var faible: String = m.get("boss_faiblesse", "feu")
			var fort: String = m.get("boss_force", "froid")
			if not vraie:
				var autres := Aventure.ELEMENTS_BOSS.duplicate()
				autres.erase(faible)
				fort = faible
				faible = autres.pick_random()
			return Dialogues.texte("rumeurs/gardien", {"faible": Aventure.NOMS_ELEMENTS[faible],
				"fort": Aventure.NOMS_ELEMENTS_DE[fort]})
		"etage":
			var sujets := [
				["geolier", func(p): return p["genre"] == "geolier"],
				["verrou", func(_p): return false],
				["pupitre", func(p): return p.get("sous") == "pupitre"],
				["cachette", func(p): return p.get("sous") == "cachette"],
				["chevalier", func(p): return p["genre"] == "imbattable"],
			]
			sujets.shuffle()
			for s in sujets:
				var cible := ""
				if s[0] == "verrou":
					for i in donjon.plan_donjon[int(donjon.salle_actuelle[0])]:
						if donjon.plan_donjon[int(donjon.salle_actuelle[0])][i].get("verrouillee", false):
							cible = i
				else:
					cible = _salle_avec(donjon, s[1])
				if cible == "":
					continue
				var dir := direction(donjon, cible)
				return Dialogues.texte("rumeurs/etage/" + s[0], {"direction": dir if vraie else _direction_fausse(donjon, dir)})
			return Dialogues.texte("rumeurs/rien")
		_:
			var faits := Dialogues.liste("rumeurs/faits")
			if faits.is_empty():
				return Dialogues.texte("rumeurs/rien")
			var f: Dictionary = faits.pick_random()
			return String(f.get("vrai" if vraie else "faux", ""))


## Ajoute une information au journal du joueur (écran Journal) : ``sujet`` (titre de la rubrique), ``texte``.
## ``mensonge`` est gardé pour les tests et les effets futurs ; l'écran Journal ne l'affiche pas.
static func noter_journal(donjon, sujet: String, texte: String, mensonge := false) -> void:
	var joueur = donjon.personnage
	if not (U.ga(joueur, "journal", null) is Array):
		joueur._d["journal"] = []
	joueur._d["journal"].append({"etage": int(donjon.salle_actuelle[0]), "sujet": sujet, "texte": texte, "mensonge": mensonge})


## Ce que les diablotins ont déjà dit dans la partie : {clé : vrai}.
static func _dits(donjon) -> Dictionary:
	if not (U.ga(donjon, "diablotins_dits", null) is Dictionary):
		donjon._d["diablotins_dits"] = {}
	return donjon._d["diablotins_dits"]


## Informations encore à dire sur ``sujet`` : [[clé, texte, rubrique du journal], ...] (vrai, jamais déjà dit).
static func infos_diablotin(donjon, sujet: String) -> Array:
	var dits := _dits(donjon)
	var etage := int(donjon.salle_actuelle[0])
	var liste := []
	match sujet:
		"chevalier":
			# Un élément à la fois, dans l'ordre ; ce que le compte sait déjà n'est jamais redit
			for info in infos_chevalier():
				var cle: String = "chevalier/" + info[0]
				if not dits.has(cle) and not Compte.connu(cle):
					liste.append([cle, info[1], NOM_CHEVALIER])
					break
		"autre":
			for a in astuces():
				var cle: String = "astuce/" + a[0]
				if not dits.has(cle) and not (a[2] != "" and Compte.connu(cle)):
					liste.append([cle, a[1], "Conseils"])
			for l in lore():
				if not dits.has("lore/" + l[0]):
					liste.append(["lore/" + l[0], l[1], "Histoires du donjon"])
		"affaires":
			for i in donjon.plan_donjon[etage]:
				for p in donjon.plan_donjon[etage][i].get("presences", []):
					if p.get("etat") != "actif":
						continue
					var cle := "affaires/%d/%s" % [etage, p.get("id")]
					if p.get("sous") == "coffre_confisque" and not dits.has(cle):
						liste.append([cle, Dialogues.texte("diablotin/affaires/coffre", {"direction": direction(donjon, i)}), "Tes affaires"])
					elif p.get("genre") == "porteur" and not p.get("objets", []).is_empty() and not dits.has(cle):
						liste.append([cle, Dialogues.texte("diablotin/affaires/porteur", {"direction": direction(donjon, i)}), "Tes affaires"])
		"etage":
			var m := Aventure.meta(donjon, etage)
			var rubrique := "Étage %d" % etage
			var faits := []
			if m.has("boss_faiblesse"):
				faits.append(["gardien_faible", Dialogues.texte("diablotin/etage/gardien_faible", {"element": Aventure.NOMS_ELEMENTS[m["boss_faiblesse"]]})])
				faits.append(["gardien_fort", Dialogues.texte("diablotin/etage/gardien_fort", {"element": Aventure.NOMS_ELEMENTS_DE[m["boss_force"]]})])
			var reperes := [
				["geolier", func(p): return p["genre"] == "geolier"],
				["pupitre", func(p): return p.get("sous") == "pupitre"],
				["cachette", func(p): return p.get("sous") == "cachette"],
				["chevalier", func(p): return p["genre"] == "imbattable"],
				["succube", func(p): return p.get("sous") == "succube"],
				["cle_boss", func(p): return p.has("cle_boss") and p["genre"] == "groupe" and p.get("etat") == "actif"],
				["cle_boss_corps", func(p): return p.has("cle_boss") and p.get("sous") == "cadavre" and not p.get("cle_prise", false)],
			]
			for r in reperes:
				var salle := _salle_avec(donjon, r[1])
				if salle != "":
					faits.append([r[0], Dialogues.texte("diablotin/etage/" + r[0], {"direction": direction(donjon, salle)})])
			for i in donjon.plan_donjon[etage]:
				if donjon.plan_donjon[etage][i].get("verrouillee", false) and not donjon.plan_donjon[etage][i].get("cle_boss", false):
					faits.append(["verrou", Dialogues.texte("diablotin/etage/verrou", {"direction": direction(donjon, i)})])
					break
			for f in faits:
				var cle := "etage/%d/%s" % [etage, f[0]]
				if not dits.has(cle):
					liste.append([cle, f[1], rubrique])
	return liste


## Mensonges encore possibles sur le donjon (jamais sur les ennemis) : [[clé, texte, rubrique, clés vraies
## qu'il rend caduques], ...]. Une fausse direction pour la cachette ou le pupitre remplace l'information vraie,
## qui ne sera plus jamais donnée (le diablotin ne se contredit pas).
static func mensonges_diablotin(donjon) -> Array:
	var dits := _dits(donjon)
	var etage := int(donjon.salle_actuelle[0])
	var rubrique := "Étage %d" % etage
	var liste := []
	for r in [["pupitre", func(p): return p.get("sous") == "pupitre"],
			["cachette", func(p): return p.get("sous") == "cachette"]]:
		var cle := "etage/%d/%s" % [etage, r[0]]
		var salle := _salle_avec(donjon, r[1])
		if salle != "" and not dits.has(cle):
			liste.append(["mensonge/%d/%s" % [etage, r[0]], Dialogues.texte("diablotin/etage/" + r[0],
				{"direction": _direction_fausse(donjon, direction(donjon, salle))}), rubrique, [cle]])
	for r in ["salle_secrete", "coffre"]:
		var cle := "mensonge/%d/%s" % [etage, r]
		if not dits.has(cle):
			liste.append([cle, Dialogues.texte("diablotin/mensonges/" + r, {"direction": _direction_fausse(donjon, "")}), rubrique, []])
	if not dits.has("mensonge/arme_chevalier"):
		liste.append(["mensonge/arme_chevalier", Dialogues.texte("diablotin/mensonges/arme_chevalier"), rubrique, []])
	return liste


## Une réponse du diablotin sur ``sujet`` : tirée (mensonge une fois sur trois pour l'étage), retenue comme dite
## et notée au journal. Renvoie [clé, texte, rubrique, ...].
static func repondre(donjon, sujet: String) -> Array:
	var infos := infos_diablotin(donjon, sujet)
	var mensonges := mensonges_diablotin(donjon) if sujet == "etage" else []
	var info: Array
	if not mensonges.is_empty() and (infos.is_empty() or randf() < Karma.chance_mensonge(donjon.personnage, CHANCE_MENSONGE)):
		info = mensonges.pick_random()
		for cle in info[3]:
			_dits(donjon)[cle] = true
	else:
		info = infos.pick_random() if sujet != "chevalier" else infos[0]
	_dits(donjon)[info[0]] = true
	noter_journal(donjon, info[2], info[1], str(info[0]).begins_with("mensonge/"))
	var ennemi := ennemi_de(info[0])
	if ennemi != "":
		Compte.apprendre(ennemi, info[0], info[1])
	return info


## Vrai si l'information ``cle`` sur un ennemi fait toujours partie du jeu (le glossaire d'un compte peut garder
## une information retirée depuis, comme la limite de dégâts du Chevalier, apprise en v0.3 : elle n'est plus montrée).
static func info_ennemi_valide(cle: String) -> bool:
	for info in infos_chevalier():
		if "chevalier/" + info[0] == cle:
			return true
	for a in astuces():
		if "astuce/" + a[0] == cle and a[2] != "":
			return true
	return false


## Ennemi dont parle l'information ``cle`` (« » si elle ne parle pas d'un ennemi) : elle va alors au glossaire.
static func ennemi_de(cle: String) -> String:
	if cle.begins_with("chevalier/"):
		return NOM_CHEVALIER
	if cle.begins_with("astuce/"):
		return ENNEMIS_CONSEILS.get(cle.trim_prefix("astuce/"), "")
	return ""


## Accueil du diablotin selon le karma du héros (les habitants sont plus froids avec un héros cruel).
static func accueil_diablotin(joueur) -> String:
	var k := Karma.valeur(joueur)
	if k <= -Karma.PALIER:
		return Dialogues.texte("diablotin/accueil/cruel")
	if k < 0:
		return Dialogues.texte("diablotin/accueil/mefiant")
	if k >= Karma.PALIER:
		return Dialogues.texte("diablotin/accueil/bon")
	return Dialogues.texte("diablotin/accueil/neutre")


## Conversation avec un diablotin : il répond à DIABLOTIN_REPONSES questions au plus (une information nouvelle
## à chaque fois, notée dans le journal), puis disparaît. Renvoie le message de fin.
static func diablotin(donjon, p: Dictionary) -> String:
	var texte := accueil_diablotin(donjon.personnage)
	var reponses := 0
	while reponses < DIABLOTIN_REPONSES:
		var sujets := []
		for sujet in ["affaires", "chevalier", "etage", "autre"]:
			if not infos_diablotin(donjon, sujet).is_empty() or (sujet == "etage" and not mensonges_diablotin(donjon).is_empty()):
				sujets.append(sujet)
		if sujets.is_empty():
			texte = Dialogues.texte("diablotin/rien_a_dire")
			await Ecrans.dialogue("Diablotin", texte, ["Partir"], COULEUR_DIABLOTIN)
			break
		sujets = sujets.slice(0, 3)
		var boutons := []
		for sujet in sujets:
			boutons.append(Dialogues.texte("diablotin/sujets/" + sujet))
		boutons.append("Partir")
		var choix := await Ecrans.dialogue("Diablotin", texte, boutons, COULEUR_DIABLOTIN)
		if choix >= sujets.size():
			break
		var info := repondre(donjon, sujets[choix])
		reponses += 1
		texte = "« %s »" % info[1]
		if reponses >= DIABLOTIN_REPONSES:
			await Ecrans.dialogue("Diablotin", texte + "\n" + Dialogues.texte("diablotin/note_journal"), ["..."], COULEUR_DIABLOTIN)
		else:
			texte += "\n" + Dialogues.texte("diablotin/note_journal")
		if Ecrans.auto:
			break
	if reponses == 0:
		return Dialogues.texte("diablotin/reste")
	p["etat"] = "utilise"
	return Dialogues.texte("diablotin/disparait")


## Conversation avec une succube : petits pactes (25 % des PV max) ou grands (50 %), confirmation, puis elle
## disparaît. Renvoie le message de fin.
static func succube(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var texte := Dialogues.texte("succube/accueil", {"pv": joueur.points_de_vie_max})
	var boutons_accueil := Dialogues.liste("succube/boutons")
	if boutons_accueil.size() != 3:
		boutons_accueil = ["Petits pactes (25 % de vie)", "Grands pactes (50 % de vie)", "Partir"]
	while true:
		var choix := await Ecrans.dialogue("Succube", texte, boutons_accueil, COULEUR_SUCCUBE)
		if choix == 2:
			break
		var liste: Array = ["voile", "carte", "baiser"] if choix == 0 else ["apaisement", "mort"]
		var lignes := []
		var boutons := []
		for cle in liste:
			lignes.append("%s (−%d PV max) : %s." % [Aventure.NOMS_PACTES[cle], Aventure.prix_pacte(joueur, cle), effet_pacte(cle)])
			var raison := Aventure.pacte_impossible(donjon, cle)
			boutons.append(Aventure.NOMS_PACTES[cle] + ("" if raison == "" else " (%s)" % raison))
		boutons.append("Retour")
		var pacte := await Ecrans.dialogue("Succube", "\n".join(lignes), boutons, COULEUR_SUCCUBE)
		if pacte < liste.size():
			var cle: String = liste[pacte]
			var raison := Aventure.pacte_impossible(donjon, cle)
			if raison != "":
				texte = Dialogues.texte("succube/" + {"déjà scellé": "deja_scelle", "aucun Chevalier de la mort ici": "aucun_chevalier",
					"pas assez de vie": "pas_assez_de_vie"}.get(raison, "alors"))
			else:
				var oui := await Ecrans.dialogue("Succube", Dialogues.texte("succube/confirmation", {"pacte": Aventure.NOMS_PACTES[cle],
					"prix": Aventure.prix_pacte(joueur, cle)}), ["Sceller le pacte", "Renoncer"], COULEUR_SUCCUBE)
				if oui == 0:
					p["etat"] = "utilise"
					return Aventure.sceller_pacte(donjon, cle) + " " + Dialogues.texte("succube/scelle")
				texte = Dialogues.texte("succube/hesite")
		else:
			texte = Dialogues.texte("succube/alors")
		if Ecrans.auto:
			break
	return Dialogues.texte("succube/partir")


# ---------------------------------------------------------------------------
# Choix moraux
# ---------------------------------------------------------------------------

static func _potion(joueur):
	for o in joueur.inventaire:
		if U.ga(o, "type_objet", "") == "consommable":
			return o
	return null


static func _cle_ou_livre(joueur, etage := 1) -> String:
	if randf() >= Aventure.CHANCE_LIVRE_GOBELIN:
		joueur._d["cles"] = int(U.ga(joueur, "cles", 0)) + 1
		return "une clé rouillée (clés : %d)" % joueur.cles
	return "un vieux grimoire. " + Aventure.lire_livre(joueur, etage)


## Gobelin blessé ; renvoie le message de fin.
static func gobelin_blesse(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var potion = _potion(joueur)
	var choix := await Ecrans.dialogue("Gobelin blessé", Dialogues.texte("gobelin_blesse/presentation"),
		["Le soigner (une potion)" if potion != null else "Le soigner (aucune potion)", "L'épargner et partir", "L'achever"])
	if choix == 0 and potion != null:
		joueur.retirer_objet_inventaire(potion)
		p["etat"] = "utilise"
		Karma.acte(donjon, "soigner_gobelin_blesse")
		return Dialogues.texte("gobelin_blesse/soigne", {"cadeau": _cle_ou_livre(joueur, int(donjon.salle_actuelle[0]))})
	if choix == 0:
		return Dialogues.texte("gobelin_blesse/sans_potion")
	if choix == 1:
		p["etat"] = "utilise"
		Karma.acte(donjon, "epargner_gobelin_blesse")
		return Dialogues.texte("gobelin_blesse/epargne", {"rumeur": phrase(donjon, "etage", true)})
	Statistiques.noter(joueur, "pacifiques_tues")
	# Son corps reste là : on peut le fouiller et siphonner son âme
	var sorte: String = PresencesSalle.SORTES_GOBELINS[int(p.get("id", 0)) * 7 % PresencesSalle.SORTES_GOBELINS.size()]
	p["genre"] = "objet"
	p["sous"] = "cadavre"
	p["etat"] = "actif"
	p["ames"] = 1
	p["pacifique"] = true
	p["nom_corps"] = "le gobelin"
	p["membres"] = [{"sous_classe": CombatAnime.TYPES.find_key(sorte)}]
	p["t_mort"] = Animations.temps()  # son animation de mort reprend là où il s'était effondré
	return (Dialogues.texte("gobelin_blesse/acheve") + " " + Karma.acte(donjon, "achever_gobelin_blesse")).strip_edges()


# ---------------------------------------------------------------------------
# Prisonniers des cellules (ébauche du 2026-11-01, textes et quêtes à venir de l'utilisateur)
# ---------------------------------------------------------------------------

static var _textes_prisonniers := {}


## Textes des prisonniers (``donnees/prisonniers.json`` : accueil, informations, quêtes ; à remplir par l'utilisateur).
static func textes_prisonniers() -> Dictionary:
	if _textes_prisonniers.is_empty():
		var lu = U.charger_json("prisonniers.json")
		_textes_prisonniers = lu if lu is Dictionary else {}
	return _textes_prisonniers


## Prisonnier dans sa cellule (peint dans l'image ; on lui parle depuis sa zone de dialogue) : parler (une petite
## information, jamais deux fois dans la partie), le tuer (karma −1 : son âme se siphonne depuis la même zone ; l'image
## ne change pas), ou partir. Un prisonnier à quête (« quete ») joue sa quête : ``prisonnier_a_quete``.
## Renvoie [message, bruit] (ou [message, bruit, suites] pour une quête).
static func prisonnier_cellule(donjon, p: Dictionary) -> Array:
	if p.has("quete"):
		return await prisonnier_a_quete(donjon, p)
	return [await _prisonnier_ordinaire(donjon, p), false]


## Prisonnier à quête (QuetesPrisonniers, textes de donnees/prisonniers.json) : sa présentation, puis Parler (l'étape
## en cours de sa quête, une bulle par ligne ; « Donner ... » s'il attend un objet que le héros a), Le tuer, Partir.
## Renvoie [message, bruit, suites] (suites : ce que l'écran doit faire, voir QuetesPrisonniers).
static func prisonnier_a_quete(donjon, p: Dictionary) -> Array:
	var q := QuetesPrisonniers.definition(String(p["quete"]))
	var nom := String(q.get("nom", "Prisonnier"))
	var c: Array = q.get("couleur", [170, 160, 140])
	var teinte := Color8(int(c[0]), int(c[1]), int(c[2]))
	var choix := await Ecrans.dialogue(nom, String(q.get("presentation", "Un prisonnier vous regarde à travers les barreaux.")),
		["Parler", "Le tuer", "Partir"], teinte)
	if choix == 1:
		return [_tuer_prisonnier(donjon, p), false, []]
	if choix != 0:
		return ["Vous laissez %s à sa cellule." % nom.to_lower(), false, []]
	var res := QuetesPrisonniers.ecouter(donjon, p)
	var suites: Array = res["suites"].duplicate()
	while true:
		var lignes: Array = res["lignes"] if not res["lignes"].is_empty() else ["« … »"]
		for k in lignes.size() - 1:
			await Ecrans.dialogue(nom, String(lignes[k]), ["…"], teinte)
		var boutons := ["Partir"]
		if res["donner"] != "":
			boutons = ["Donner : %s" % res["donner"], "Partir"]
		var r := await Ecrans.dialogue(nom, String(lignes[-1]), boutons, teinte)
		if res["donner"] == "" or r != 0:
			break
		res = QuetesPrisonniers.donner(donjon, p)
		suites.append_array(res["suites"])
	return ["", false, suites]


static func _prisonnier_ordinaire(donjon, p: Dictionary) -> String:
	var t := textes_prisonniers()
	var accueil: Array = t.get("accueil", [])
	var texte: String = accueil.pick_random() if not accueil.is_empty() else Dialogues.texte("prisonnier_cellule/presentation")
	var choix := await Ecrans.dialogue("Prisonnier", texte, ["Parler", "Le tuer", "Partir"], Color8(170, 160, 140))
	if choix == 0:
		var dits := _dits(donjon)
		for k in t.get("informations", []).size():
			var cle := "prisonnier/info/%d" % k
			if not dits.has(cle):
				dits[cle] = true
				var info := String(t["informations"][k])
				noter_journal(donjon, "Prisonniers", info)
				return "« %s »" % info
		return Dialogues.texte("prisonnier_cellule/rien_a_dire")
	if choix == 1:
		return _tuer_prisonnier(donjon, p)
	return Dialogues.texte("prisonnier_cellule/laisse")


## Le héros tue le prisonnier entre ses barreaux (karma −1) : il devient un corps dont l'âme se siphonne.
static func _tuer_prisonnier(donjon, p: Dictionary) -> String:
	Statistiques.noter(donjon.personnage, "prisonniers_tues")
	p["genre"] = "objet"
	p["sous"] = "cadavre"
	p["etat"] = "actif"
	p["ames"] = 1
	p["humain"] = true
	p["nom_corps"] = "le prisonnier"
	p["t_mort"] = Animations.temps()
	return (Dialogues.texte("prisonnier_cellule/tue") + " " + Karma.acte(donjon, "tuer_prisonnier_cellule")).strip_edges()


## Prisonnier enchaîné ; renvoie [message, bruit] (bruit : les ennemis de la salle accourent).
static func prisonnier(donjon, p: Dictionary) -> Array:
	var joueur = donjon.personnage
	var choix := await Ecrans.dialogue("Prisonnier", Dialogues.texte("prisonnier_enchaine/presentation"), ["Briser ses chaînes (bruyant)", "Lui demander ce qu'il sait", "Le laisser"])
	if choix == 0:
		p["etat"] = "utilise"
		Karma.acte(donjon, "liberer_prisonnier")
		joueur._d["cles"] = int(U.ga(joueur, "cles", 0)) + 1
		return [Dialogues.texte("prisonnier_enchaine/libere", {"cles": joueur.cles, "rumeur": phrase(donjon, "gardien", true)}), true]
	if choix == 1:
		return [Dialogues.texte("prisonnier_enchaine/renseigne", {"rumeur": phrase(donjon, ["gardien", "etage"].pick_random(), true)}), false]
	return [Dialogues.texte("prisonnier_enchaine/laisse"), false]


## Autel de sang ; renvoie le message de fin.
static func autel(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var perte := int(ceil(joueur.points_de_vie_max * SANG_AUTEL))
	var choix := await Ecrans.dialogue("Autel de sang", Dialogues.texte("autel/presentation", {"pv": perte}), ["Offrir votre sang", "Refuser"], Color8(200, 60, 60))
	if choix != 0:
		return Dialogues.texte("autel/refus")
	if joueur.points_de_vie <= perte:
		return Dialogues.texte("autel/trop_faible")
	joueur.points_de_vie -= perte
	Statistiques.noter(joueur, "degats_subis", perte)
	var cle: String = CARACTERISTIQUES.keys().pick_random()
	joueur._d[cle] = int(U.ga(joueur, cle, 0)) + 1
	joueur.calculer_stats()
	p["etat"] = "utilise"
	return Dialogues.texte("autel/offrande", {"caracteristique": CARACTERISTIQUES[cle]})


## Parle à un personnage ; renvoie [message, bruit].
static func parler(donjon, p: Dictionary) -> Array:
	match p.get("sous", ""):
		"diablotin":
			return [await diablotin(donjon, p), false]
		"gobelin_blesse":
			return [await gobelin_blesse(donjon, p), false]
		"prisonnier":
			return await prisonnier(donjon, p)
		"prisonnier_cellule":
			return await prisonnier_cellule(donjon, p)
		"succube":
			return [await succube(donjon, p), false]
		"commis":
			return [await commis(donjon, p), false]
		"autel":
			if p.get("etat") != "actif":
				return [Dialogues.texte("autel/sec"), false]
			return [await autel(donjon, p), false]
	return ["", false]


## Ce que donnent des gobelins pacifiques épargnés (règles de l'utilisateur, 2026-10-31 ; valeurs validées) : un peu
## d'or (× étage), parfois une potion, plus rarement un équipement ; puis ils disparaissent (karma +1).
const PACIFIQUES_EPARGNES := {"or": [5, 15], "potion": 0.20, "equipement": 0.05}


## Le héros épargne le groupe de pacifiques ``p`` : il reçoit leur cadeau, ils s'en vont. Renvoie le message.
static func epargner_pacifiques(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var etage := int(donjon.salle_actuelle[0])
	var n := Aventure.membres(p).size()
	p["etat"] = "parti"
	Statistiques.noter(joueur, "pacifiques_epargnes", n)
	var cadeaux := []
	var gain := Karma.or_gagne(joueur, randi_range(PACIFIQUES_EPARGNES["or"][0], PACIFIQUES_EPARGNES["or"][1]) * maxi(1, etage))
	joueur.piece_or += gain
	cadeaux.append("%d pièces d'or" % gain)
	if randf() < PACIFIQUES_EPARGNES["potion"]:
		var potion := Consommable.creer_potion("pv", Consommable.niveau_potion_etage(etage))
		joueur.recevoir_objet(potion)
		cadeaux.append(potion.nom)
	if randf() < PACIFIQUES_EPARGNES["equipement"]:
		var objet = GenerationObjets.generer_objet(null, clampi(etage, 1, 6))
		joueur.recevoir_objet(objet)
		cadeaux.append(objet.nom)
	var texte := "%s vous remercie%s et vous laisse%s %s avant de disparaître dans l'ombre." % [
		"Le gobelin" if n == 1 else "Les gobelins", "" if n == 1 else "nt", "" if n == 1 else "nt", ", ".join(cadeaux)]
	return (texte + " " + Karma.acte(donjon, "epargner_pacifiques")).strip_edges()


## Groupe de gobelins pacifiques touché : [attaquer ?]. Vrai : le joueur choisit de les attaquer.
static func pacifiques(_donjon, p: Dictionary) -> bool:
	var n := int(p.get("nombre", 1))
	var choix := await Ecrans.dialogue("Gobelins pacifiques", Dialogues.texte("pacifiques/un") if n == 1 \
		else Dialogues.texte("pacifiques/plusieurs", {"nombre": n}), ["Les laisser partir", "Les attaquer"])
	return choix == 1


# ---------------------------------------------------------------------------
# Commis (2026-11-04, animations de l'utilisateur)
# ---------------------------------------------------------------------------

const COULEUR_COMMIS := Color8(205, 170, 120)


## Commis de la cuisine (comment on cuisine) ou du cellier (où trouver des ingrédients) : sa présentation, puis
## « Comment on cuisine ? » / « Où trouver des ingrédients ? » : ses explications, une bulle par ligne
## (``commis_<role>`` de dialogues.json). On peut lui reparler autant qu'on veut. Renvoie le message de fin.
static func commis(_donjon, p: Dictionary) -> String:
	var role := "commis_" + String(p.get("role", "cuisine"))
	var nom := Dialogues.texte(role + "/nom")
	var boutons := Dialogues.liste(role + "/boutons")
	if boutons.size() < 2:
		boutons = ["Parler", "Partir"]
	var choix := await Ecrans.dialogue(nom, Dialogues.texte(role + "/presentation"), boutons, COULEUR_COMMIS)
	if choix != 0:
		return ""
	var lignes := Dialogues.liste(role + "/explications")
	for k in lignes.size():
		var r := await Ecrans.dialogue(nom, String(lignes[k]), ["…" if k < lignes.size() - 1 else "Merci", "Partir"], COULEUR_COMMIS)
		if r != 0 or Ecrans.auto:
			break
	return Dialogues.texte(role + "/fin")
