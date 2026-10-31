class_name Rencontres
extends RefCounted
## Personnages du donjon d'aventure et leurs dialogues (Aventure : présences de genre « pnj »).
##
## - **Diablotin** (demande de l'utilisateur, 2026-10-27) : il transmet au compte-gouttes des informations sur les
##   mécaniques du jeu, le Chevalier de la mort, l'étage et, après une capture, l'endroit où sont les affaires du
##   héros. Il peut **mentir, mais seulement sur le donjon, jamais sur les ennemis** (fiche de l'utilisateur) : une
##   réponse à « Cet étage ? » sur trois (CHANCE_MENSONGE) est un mensonge (``mensonges_diablotin``), noté au journal
##   comme une vraie information. Tout ce qui touche les ennemis et les affaires confisquées reste vrai.
##   **Aucun diablotin ne dit deux fois la même chose dans une partie** (``donjon.diablotins_dits``)
##   ; chacun répond à DIABLOTIN_REPONSES questions au plus puis disparaît ; chaque réponse va dans le **journal**
##   du joueur (``noter_journal``, écran ``journal.gd``, touche J). Le lore viendra dans ``LORE``.
## - **Gobelin blessé** (choix moral) : le soigner avec une potion (il donne une clé ou un grimoire), l'épargner
##   (il dit un secret vrai), ou l'achever (c'est un ennemi qu'on ne doit pas tuer : un Sans-Visage de plus).
## - **Prisonnier** (choix moral) : briser ses chaînes (bruyant : les ennemis de la salle accourent ; il donne une
##   clé), lui demander ce qu'il sait (il dit vrai), ou le laisser.
## - **Autel de sang** : offrir son sang (PV) contre un point de caractéristique, ou refuser.
## - **Succube** (un étage sur deux, pas de combat) : un pacte contre une part des PV max, pour toujours
##   (``Aventure.PACTES``), puis elle disparaît ; on peut refuser et revenir.
## Les choix sont comptés (``donjon.moralite`` : clémence, cruauté) pour de futures conséquences.
## **Textes et valeurs choisis par Claude, à valider.**

const CHANCE_VERITE := 0.5
## Autel : part des PV max offerts, et caractéristiques possibles.
const SANG_AUTEL := 0.4
## Mana ajoutée le 2026-10-29 (demande de l'utilisateur).
const CARACTERISTIQUES := Caracteristiques.NOMS
const COULEUR_DIABLOTIN := Color8(190, 120, 230)
## Questions auxquelles répond un diablotin avant de disparaître (choix de Claude).
const DIABLOTIN_REPONSES := 2
## Part des réponses à « Cet étage ? » qui sont des mensonges sur le donjon (décision de l'utilisateur, 2026-10-27).
const CHANCE_MENSONGE := 1.0 / 3.0
## Ce que les diablotins disent du Chevalier de la mort, dans cet ordre, une information à la fois (fiche de
## l'utilisateur « chevalier de la mort.odt »).
const INFOS_CHEVALIER := [
	"Le Chevalier de la mort ? Il résiste à tout : lames, pointes, masses, feu, froid, foudre, chaos, arcane, ombre... Tes coups l'effleurent à peine.",
	"Il frappe avec sa grande lame... mais pas seulement avec elle. Hé hé.",
	"Sa lame est trempée dans l'ombre : elle te blesse aussi avec des ténèbres.",
	"Inutile de chercher à l'affronter. Fuis. Il vaut toujours mieux fuir.",
	"Et surtout, pas de bruit ! Le bruit l'attire : cours trop longtemps, brise des chaînes... et il arrive.",
]
## Conseils sur les mécaniques du jeu : [clé, texte] (textes de Claude, à valider).
const ASTUCES := [
	["ombre", "Reste immobile dans les coins les plus sombres : personne ne te verra. Marche dans l'ombre, et on te verra de moitié moins loin."],
	["course", "Courir, c'est bruyant. Les gobelins t'entendent de loin... et pas seulement eux."],
	["piliers", "Les piliers et les obstacles coupent la vue. Mets-les entre toi et ceux qui te cherchent."],
	["pacifiques", "Les gobelins qui lèvent les mains ne veulent pas se battre. Tue-les, et un Chevalier de la mort de plus se mettra à errer."],
	["geolier", "Le geôlier ne tue pas : il t'assomme et t'enferme au cachot. Tes affaires finissent dans un coffre, perdues, ou dans les poches de gobelins... sauf ton arme, toujours dans le coffre."],
	["cachettes", "Certains murs cachent des choses : une petite lueur quand tu passes tout près. Les clés des salles fermées y dorment souvent."],
	["succube", "Si tu croises une dame aux ailes de cuir, elle te vendra ce que tu veux. Le prix, c'est ta vie. Pour toujours."],
	["fuite", "Un combat qui tourne mal ? Fuis. Ça ne marche pas toujours, mais c'est mieux que mourir."],
	["suivre", "Ceux qui te poursuivent peuvent te suivre d'une salle à l'autre. Une porte ne suffit pas toujours."],
]
## Lore du jeu et des personnages, raconté par les diablotins : [clé, texte] (à écrire par l'utilisateur).
const LORE := []
const SUJETS_DIABLOTIN := {"affaires": "Mes affaires ?", "chevalier": "Le Chevalier de la mort ?", "etage": "Cet étage ?",
	"autre": "Autre chose ?"}
const COULEUR_SUCCUBE := Color8(215, 120, 210)
## Ce que fait chaque pacte, dit au joueur.
const EFFETS_PACTES := {
	"voile": "jusqu'à la fin de l'étage, les ennemis voient deux fois moins loin, et vous restez caché dans l'ombre même en marchant",
	"carte": "tout l'étage apparaît sur la carte, avec ses cachettes, ses geôliers et ses Chevaliers de la mort, jusqu'à la fin de l'étage",
	"baiser": "la prochaine fois qu'un geôlier vous attrape, il vous lâche et s'enfuit",
	"apaisement": "un Chevalier de la mort de cet étage disparaît",
	"mort": "la prochaine fois que vous mourez, vous vous réveillez au cachot avec 1 PV, sans rien perdre",
}


static func _noter_moralite(donjon, cle: String) -> void:
	var m = U.ga(donjon, "moralite", null)
	if not (m is Dictionary):
		m = {"clemence": 0, "cruaute": 0}
		donjon._d["moralite"] = m
	m[cle] = int(m.get(cle, 0)) + 1


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

## Une réponse du diablotin sur ``sujet`` (« gardien », « etage », « ennemis ») : vraie si ``vraie``.
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
			return "Le gardien de cet étage craint %s... mais il se moque %s. Hé hé." % [
				Aventure.NOMS_ELEMENTS[faible], Aventure.NOMS_ELEMENTS_DE[fort]]
		"etage":
			var sujets := [
				["Le geôlier rôde %s.", func(p): return p["genre"] == "geolier"],
				["Une salle fermée à clé se trouve %s.", func(_p): return false],
				["Les livres du savoir dorment %s.", func(p): return p.get("sous") == "pupitre"],
				["Une cachette secrète attend %s. Regarde bien les murs !", func(p): return p.get("sous") == "cachette"],
				["Un Chevalier de la mort erre %s. Ne fais pas de bruit.", func(p): return p["genre"] == "imbattable"],
			]
			sujets.shuffle()
			for s in sujets:
				var cible := ""
				if s[0].begins_with("Une salle fermée"):
					for i in donjon.plan_donjon[int(donjon.salle_actuelle[0])]:
						if donjon.plan_donjon[int(donjon.salle_actuelle[0])][i].get("verrouillee", false):
							cible = i
				else:
					cible = _salle_avec(donjon, s[1])
				if cible == "":
					continue
				var dir := direction(donjon, cible)
				return s[0] % (dir if vraie else _direction_fausse(donjon, dir))
			return "Cet étage ? Rien d'intéressant, rien du tout... ou peut-être que si."
		_:
			var faits := [
				["Les gobelins qui lèvent les mains ne veulent pas se battre. Tue-les, et les Sans-Visage se multiplieront.",
					"Les gobelins qui lèvent les mains cachent de l'or. Tue-les sans hésiter !"],
				["Les Sans-Visage ne meurent pas. Fuis-les, toujours.",
					"Les Sans-Visage craignent l'acier : frappe-les de toutes tes forces !"],
				["Derrière un pilier, le geôlier ne te voit pas.",
					"Le geôlier voit à travers la pierre. Te cacher ne sert à rien."],
				["Qui court se fait entendre de loin. Marche, si tu veux rester discret.",
					"Les gobelins sont sourds comme des pots. Cours tant que tu veux !"],
			]
			var f: Array = faits.pick_random()
			return f[0] if vraie else f[1]


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
			# Une à la fois, dans l'ordre
			for k in INFOS_CHEVALIER.size():
				if not dits.has("chevalier/%d" % k):
					liste.append(["chevalier/%d" % k, INFOS_CHEVALIER[k], "Chevalier de la mort"])
					break
		"autre":
			for a in ASTUCES:
				if not dits.has("astuce/" + a[0]):
					liste.append(["astuce/" + a[0], a[1], "Conseils"])
			for l in LORE:
				if not dits.has("lore/" + l[0]):
					liste.append(["lore/" + l[0], l[1], "Histoires du donjon"])
		"affaires":
			for i in donjon.plan_donjon[etage]:
				for p in donjon.plan_donjon[etage][i].get("presences", []):
					if p.get("etat") != "actif":
						continue
					var cle := "affaires/%d/%s" % [etage, p.get("id")]
					if p.get("sous") == "coffre_confisque" and not dits.has(cle):
						liste.append([cle, "Tes affaires ? Le geôlier les a jetées dans un coffre, %s. Ton or aussi. Hé hé." % direction(donjon, i), "Tes affaires"])
					elif p.get("genre") == "porteur" and not p.get("objets", []).is_empty() and not dits.has(cle):
						liste.append([cle, "Un gobelin se promène avec certaines de tes affaires, %s. Il faudra les lui reprendre." % direction(donjon, i), "Tes affaires"])
		"etage":
			var m := Aventure.meta(donjon, etage)
			var rubrique := "Étage %d" % etage
			var faits := []
			if m.has("boss_faiblesse"):
				faits.append(["gardien_faible", "Le gardien de cet étage craint %s." % Aventure.NOMS_ELEMENTS[m["boss_faiblesse"]]])
				faits.append(["gardien_fort", "Le gardien de cet étage se moque %s. Garde-les pour un autre." % Aventure.NOMS_ELEMENTS_DE[m["boss_force"]]])
			var reperes := [
				["geolier", "Le geôlier rôde %s. Évite-le si tu tiens à tes affaires.", func(p): return p["genre"] == "geolier"],
				["pupitre", "Les livres du savoir dorment %s.", func(p): return p.get("sous") == "pupitre"],
				["cachette", "Une cachette secrète attend %s. Regarde bien les murs !", func(p): return p.get("sous") == "cachette"],
				["chevalier", "Un Chevalier de la mort erre %s. Ne fais pas de bruit.", func(p): return p["genre"] == "imbattable"],
				["succube", "Une dame aux ailes de cuir attend %s.", func(p): return p.get("sous") == "succube"],
			]
			for r in reperes:
				var salle := _salle_avec(donjon, r[2])
				if salle != "":
					faits.append([r[0], r[1] % direction(donjon, salle)])
			for i in donjon.plan_donjon[etage]:
				if donjon.plan_donjon[etage][i].get("verrouillee", false):
					faits.append(["verrou", "Une salle fermée à clé se trouve %s." % direction(donjon, i)])
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
	for r in [["pupitre", "Les livres du savoir dorment %s.", func(p): return p.get("sous") == "pupitre"],
			["cachette", "Une cachette secrète attend %s. Regarde bien les murs !", func(p): return p.get("sous") == "cachette"]]:
		var cle := "etage/%d/%s" % [etage, r[0]]
		var salle := _salle_avec(donjon, r[2])
		if salle != "" and not dits.has(cle):
			liste.append(["mensonge/%d/%s" % [etage, r[0]], r[1] % _direction_fausse(donjon, direction(donjon, salle)), rubrique, [cle]])
	var inventes := [
		["salle_secrete", "Il y a une salle secrète %s, derrière un mur qui sonne creux. Un trésor y dort depuis toujours."],
		["coffre", "Un coffre plein d'or t'attend %s. Personne ne l'a encore ouvert. Hé hé."],
	]
	for r in inventes:
		var cle := "mensonge/%d/%s" % [etage, r[0]]
		if not dits.has(cle):
			liste.append([cle, r[1] % _direction_fausse(donjon, ""), rubrique, []])
	if not dits.has("mensonge/arme_chevalier"):
		liste.append(["mensonge/arme_chevalier", "Quelque part dans ce donjon dort une lame bénie, la seule qui blesse " + \
			"vraiment le Chevalier de la mort. Trouve-la, et il tremblera devant toi !", rubrique, []])
	return liste


## Une réponse du diablotin sur ``sujet`` : tirée (mensonge une fois sur trois pour l'étage), retenue comme dite
## et notée au journal. Renvoie [clé, texte, rubrique, ...].
static func repondre(donjon, sujet: String) -> Array:
	var infos := infos_diablotin(donjon, sujet)
	var mensonges := mensonges_diablotin(donjon) if sujet == "etage" else []
	var info: Array
	if not mensonges.is_empty() and (infos.is_empty() or randf() < CHANCE_MENSONGE):
		info = mensonges.pick_random()
		for cle in info[3]:
			_dits(donjon)[cle] = true
	else:
		info = infos.pick_random() if sujet != "chevalier" else infos[0]
	_dits(donjon)[info[0]] = true
	noter_journal(donjon, info[2], info[1], str(info[0]).begins_with("mensonge/"))
	return info


## Conversation avec un diablotin : il répond à DIABLOTIN_REPONSES questions au plus (une information nouvelle
## à chaque fois, notée dans le journal), puis disparaît. Renvoie le message de fin.
static func diablotin(donjon, p: Dictionary) -> String:
	var texte := "Un petit diablotin rouge ricane en voletant. « Tu veux savoir des choses, hein ? Pose tes questions... " + \
		"mais pas trop. »"
	var reponses := 0
	while reponses < DIABLOTIN_REPONSES:
		var sujets := []
		for sujet in ["affaires", "chevalier", "etage", "autre"]:
			if not infos_diablotin(donjon, sujet).is_empty() or (sujet == "etage" and not mensonges_diablotin(donjon).is_empty()):
				sujets.append(sujet)
		if sujets.is_empty():
			texte = "« Je n'ai plus rien à t'apprendre... pour l'instant. »"
			await Ecrans.dialogue("Diablotin", texte, ["Partir"], COULEUR_DIABLOTIN)
			break
		sujets = sujets.slice(0, 3)
		var boutons := []
		for sujet in sujets:
			boutons.append(SUJETS_DIABLOTIN[sujet])
		boutons.append("Partir")
		var choix := await Ecrans.dialogue("Diablotin", texte, boutons, COULEUR_DIABLOTIN)
		if choix >= sujets.size():
			break
		var info := repondre(donjon, sujets[choix])
		reponses += 1
		texte = "« %s »" % info[1]
		if reponses >= DIABLOTIN_REPONSES:
			await Ecrans.dialogue("Diablotin", texte + "\n(Noté dans votre journal : touche J.)", ["..."], COULEUR_DIABLOTIN)
		else:
			texte += "\n(Noté dans votre journal : touche J.)"
		if Ecrans.auto:
			break
	if reponses == 0:
		return "Le diablotin hausse les épaules et reste là, à ricaner."
	p["etat"] = "utilise"
	return "Le diablotin disparaît dans un nuage de soufre... avec un petit rire. (Journal : J)"


## Conversation avec une succube : petits pactes (25 % des PV max) ou grands (50 %), confirmation, puis elle
## disparaît. Renvoie le message de fin.
static func succube(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var texte := "Une femme aux ailes de cuir vous sourit dans la pénombre. « Pas d'épée entre nous... Je peux te " + \
		"donner ce que tu désires. Il me faut seulement un peu de ta vie. » (PV max : %d)" % joueur.points_de_vie_max
	while true:
		var choix := await Ecrans.dialogue("Succube", texte, ["Petits pactes (25 % de vie)", "Grands pactes (50 % de vie)",
			"Partir"], COULEUR_SUCCUBE)
		if choix == 2:
			break
		var liste: Array = ["voile", "carte", "baiser"] if choix == 0 else ["apaisement", "mort"]
		var lignes := []
		var boutons := []
		for cle in liste:
			lignes.append("%s (−%d PV max) : %s." % [Aventure.NOMS_PACTES[cle], Aventure.prix_pacte(joueur, cle), EFFETS_PACTES[cle]])
			var raison := Aventure.pacte_impossible(donjon, cle)
			boutons.append(Aventure.NOMS_PACTES[cle] + ("" if raison == "" else " (%s)" % raison))
		boutons.append("Retour")
		var pacte := await Ecrans.dialogue("Succube", "\n".join(lignes), boutons, COULEUR_SUCCUBE)
		if pacte < liste.size():
			var cle: String = liste[pacte]
			var raison := Aventure.pacte_impossible(donjon, cle)
			if raison != "":
				texte = {"déjà scellé": "« Ce pacte, tu l'as déjà. Je ne vends pas deux fois la même chose. »",
					"aucun Chevalier de la mort ici": "« Il n'y a rien de tel à apaiser dans cet étage... pas encore. »",
					"pas assez de vie": "« Il ne te reste pas assez de vie pour ça. Je ne veux pas d'un cadavre. »"}[raison]
			else:
				var oui := await Ecrans.dialogue("Succube", "« %s, contre %d PV max. Pour toujours. Tu acceptes ? »" % [
					Aventure.NOMS_PACTES[cle], Aventure.prix_pacte(joueur, cle)], ["Sceller le pacte", "Renoncer"], COULEUR_SUCCUBE)
				if oui == 0:
					p["etat"] = "utilise"
					return Aventure.sceller_pacte(donjon, cle) + " La succube s'efface dans un rire doux."
				texte = "« Tu hésites... Je suis patiente. »"
		else:
			texte = "« Alors ? »"
		if Ecrans.auto:
			break
	return "La succube vous regarde partir. « Tu reviendras. »"


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
	var choix := await Ecrans.dialogue("Gobelin blessé", "Un gobelin gît contre le mur, une plaie ouverte au flanc. " + \
		"Il lève une main tremblante : « Pitié... pas moi... »",
		["Le soigner (une potion)" if potion != null else "Le soigner (aucune potion)", "L'épargner et partir", "L'achever"])
	if choix == 0 and potion != null:
		joueur.retirer_objet_inventaire(potion)
		p["etat"] = "utilise"
		_noter_moralite(donjon, "clemence")
		return "Le gobelin se relève, incrédule. Avant de filer, il vous glisse %s." % _cle_ou_livre(joueur, int(donjon.salle_actuelle[0]))
	if choix == 0:
		return "Vous n'avez rien pour le soigner. Il vous regarde partir."
	if choix == 1:
		p["etat"] = "utilise"
		_noter_moralite(donjon, "clemence")
		return "« Merci... » souffle-t-il. « %s »" % phrase(donjon, "etage", true)
	p["etat"] = "vaincu"
	_noter_moralite(donjon, "cruaute")
	var etage := int(donjon.salle_actuelle[0])
	var m := Aventure.meta(donjon, etage)
	m["colere"] = int(m.get("colere", 0)) + 1
	Aventure.ajouter_menace(donjon, etage, "imbattable")
	Statistiques.noter(joueur, "pacifiques_tues")
	return "Vous l'achevez. Quelque part dans l'étage, un Chevalier de la mort se met en marche."


## Prisonnier enchaîné ; renvoie [message, bruit] (bruit : les ennemis de la salle accourent).
static func prisonnier(donjon, p: Dictionary) -> Array:
	var joueur = donjon.personnage
	var choix := await Ecrans.dialogue("Prisonnier", "Un homme maigre est enchaîné au mur. « Libérez-moi, par pitié... " + \
		"Je sais des choses sur ce donjon. »", ["Briser ses chaînes (bruyant)", "Lui demander ce qu'il sait", "Le laisser"])
	if choix == 0:
		p["etat"] = "utilise"
		_noter_moralite(donjon, "clemence")
		joueur._d["cles"] = int(U.ga(joueur, "cles", 0)) + 1
		return ["Les chaînes cèdent dans un fracas qui résonne dans tout l'étage ! L'homme vous donne une clé volée aux " +
			"gardes (clés : %d) et s'enfuit. « %s »" % [joueur.cles, phrase(donjon, "gardien", true)], true]
	if choix == 1:
		return ["« %s »" % phrase(donjon, ["gardien", "etage"].pick_random(), true), false]
	return ["Vous le laissez à son sort.", false]


## Autel de sang ; renvoie le message de fin.
static func autel(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var perte := int(ceil(joueur.points_de_vie_max * SANG_AUTEL))
	var choix := await Ecrans.dialogue("Autel de sang", "Un autel couvert de sang séché. Une voix murmure dans votre tête : " + \
		"« Ton sang... contre ma force. » (%d PV)" % perte, ["Offrir votre sang", "Refuser"], Color8(200, 60, 60))
	if choix != 0:
		return "Vous vous détournez de l'autel."
	if joueur.points_de_vie <= perte:
		return "Vous êtes trop faible : l'autel prendrait votre vie."
	joueur.points_de_vie -= perte
	Statistiques.noter(joueur, "degats_subis", perte)
	var cle: String = CARACTERISTIQUES.keys().pick_random()
	joueur._d[cle] = int(U.ga(joueur, cle, 0)) + 1
	joueur.calculer_stats()
	p["etat"] = "utilise"
	return "Le sang coule sur la pierre... et une force nouvelle vous envahit : %s +1." % CARACTERISTIQUES[cle]


## Parle à un personnage ; renvoie [message, bruit].
static func parler(donjon, p: Dictionary) -> Array:
	match p.get("sous", ""):
		"diablotin":
			return [await diablotin(donjon, p), false]
		"gobelin_blesse":
			return [await gobelin_blesse(donjon, p), false]
		"prisonnier":
			return await prisonnier(donjon, p)
		"succube":
			return [await succube(donjon, p), false]
		"autel":
			if p.get("etat") != "actif":
				return ["L'autel est sec. Il a eu ce qu'il voulait.", false]
			return [await autel(donjon, p), false]
	return ["", false]


## Groupe de gobelins pacifiques touché : [attaquer ?]. Vrai : le joueur choisit de les attaquer.
static func pacifiques(_donjon, p: Dictionary) -> bool:
	var n := int(p.get("nombre", 1))
	var choix := await Ecrans.dialogue("Gobelins pacifiques", ("Le gobelin" if n == 1 else "Les %d gobelins" % n) + \
		" lève%s les mains, terrorisé%s. « Pas de combat ! Pas de combat ! »" % ["" if n == 1 else "nt", "" if n == 1 else "s"],
		["Les laisser partir", "Les attaquer"])
	return choix == 1
