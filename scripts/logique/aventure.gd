class_name Aventure
extends RefCounted
## Le donjon d'aventure (FEUILLE_DE_ROUTE_AVENTURE.md, liste de l'utilisateur du 2026-10-26) : ce qui se trouve
## dans chaque salle d'un étage, et les règles de l'exploration.
##
## Chaque salle du plan a une liste « presences » (enregistrée avec la partie) : ennemis qui rôdent (groupes de
## gobelins, imbattables, geôliers, porteurs), boss qui garde sa salle, personnages à qui parler, et choses à utiliser
## (pupitre, râtelier, cachette, coffre des confiscations). Une présence est un dictionnaire :
##   {"id", "genre", "sous", "etat": "actif" | "vaincu" | "utilise", ... (données propres au genre)}.
## L'étage garde ses réglages tirés une fois (``meta`` : salle du cachot, faiblesse du boss, colère...) dans
## ``donjon.aventure[etage]``.
##
## Décisions de l'utilisateur : les ennemis ne donnent plus rien (sauf les rares qui portent un équipement), plus de
## niveaux (supprimés le 2026-10-31), deux sortes d'imbattables (imbattable : il faut fuir ; geôlier : capture),
## toute défaite = la mort, fuite de combat avec une chance d'échec, ennemis visibles qui rôdent (Fear & Hunger).
## **Toutes les valeurs chiffrées ci-dessous sont choisies par Claude, à valider par l'utilisateur.**


# --- Population des salles (valeurs choisies par Claude) -------------------------------------------------
## Groupes de gobelins qui rôdent dans une salle ordinaire : {nombre : chance en %}. « Très peu » d'ennemis pour
## laisser explorer (décision de l'utilisateur, 2026-10-30 ; {0: 35, 1: 50, 2: 15} avant).
const GROUPES_PAR_SALLE := {0: 80, 1: 20}
## Ennemis par groupe au plus, loup compris (décision de l'utilisateur, 2026-10-30 ; 3 + un loup avant).
const MAX_PAR_GROUPE := 2
## Ennemis isolés (décision de l'utilisateur, 2026-11-01 : plus d'ennemis, sans plus de groupes) : dans une salle
## ordinaire sans groupe, chance qu'un ennemi rôde seul (jamais d'élite, de pacifique ni de loup ; valeur proposée
## par Claude et retenue par l'utilisateur).
const CHANCE_ISOLE := 1.0 / 6.0
## Clé du boss (décision de l'utilisateur, 2026-11-01) : la salle du boss est fermée ; sa clé, unique, est portée par
## une élite de l'étage (il faut la vaincre et fouiller son corps ; les diablotins aident à la trouver). L'élite qui
## la porte est au moins à DISTANCE_CLE_BOSS salles du départ.
const DISTANCE_CLE_BOSS := 8
## Sortes d'ennemis, élites, pacifiques, loups et féticheurs menant des squelettes : par **zone**, dans
## ``donnees/zones.json`` (Zones, 2026-11-02 ; CHANCE_ELITE 0,12, CHANCE_PACIFIQUE 0,15, CHANCE_GROUPE_SQUELETTES
## 0,25, CHANCE_FETICHEUR_SQUELETTES 0,2 et CHANCE_LOUP 0,5 y sont devenus la zone « defaut »). Élite : ancien
## « chef » / mini-boss, porte un équipement qu'elle lâche (renommée le 2026-10-31 à la demande de l'utilisateur).
## Vitesse de poursuite d'un groupe de squelettes dans les salles (gobelins : 0,58 ; choix de Claude).
const VITESSE_SQUELETTES := 0.45
## Chevaliers de la mort (« imbattables ») et geôliers par étage (décision de l'utilisateur, 2026-10-27 : 1 et 2).
## La colère (gobelins pacifiques tués) ajoute des chevaliers.
const CHEVALIERS_PAR_ETAGE := 1
const GEOLIERS_PAR_ETAGE := 2
## Diablotins par étage : [min, max] (7, décision de l'utilisateur, 2026-10-27 ; 1 à 2 avant).
const DIABLOTINS_PAR_ETAGE := [7, 7]
## Rencontres à choix moral par étage (gobelin blessé, prisonnier, autel).
const EVENEMENTS_PAR_ETAGE := 2
## Cachettes secrètes par étage (clés, livres, or) : au moins une par salle verrouillée.
const CACHETTES_PAR_ETAGE := [2, 3]
## Grimoires (moins nombreux depuis le 2026-10-26, demande de l'utilisateur) : chance d'un pupitre par étage, contenu
## des cachettes en plus des clés ({contenu : poids}), chance qu'un gobelin soigné donne un grimoire plutôt qu'une clé.
const CHANCE_PUPITRE := 0.5
const CONTENUS_CACHETTES := {"or": 45, "objet": 40, "livre": 15}
const CHANCE_LIVRE_GOBELIN := 0.25
## Part des salles bonus (coffre, choix de bonus) verrouillées.
const PART_VERROUILLEES := 0.5
## Chance qu'un ennemi qui poursuit le héros le suive dans la salle suivante (il entre peu après lui).
const CHANCE_SUIVRE := {"groupe": 0.5, "porteur": 0.4, "imbattable": 1.0, "geolier": 0.8}
## Éloignement minimal (en salles) du cachot à la salle de départ (choix de Claude).
const CACHOT_DEPART := 3
## Éloignement minimal (en salles) de la salle de départ pour les imbattables et les geôliers.
const DISTANCE_MENACES := 3

# --- Fuite de combat ------------------------------------------------------------------------------------
## Chance de fuir : base + par point de dextérité − par ennemi au-delà du premier ; bornée.
const FUITE_BASE := 0.45
const FUITE_PAR_DEXTERITE := 0.03
const FUITE_PAR_ENNEMI := 0.10
const FUITE_BORNES := [0.15, 0.9]
## Chance de fuir un boss (fixe).
const FUITE_BOSS := 0.15

# --- Capture par un geôlier -------------------------------------------------------------------------------
## Le coffre des confiscations est à 3 salles au plus du cachot (``salle_du_coffre``, demande de l'utilisateur).
const COFFRE_PRES_DU_CACHOT := 3
## Répartition des objets confisqués : coffre des confiscations, perdus, portés par un ennemi « porteur ».
const CONFISCATION := {"coffre": 50, "perdu": 25, "porteur": 25}
## Objets au plus par porteur (au-delà, un second porteur).
const OBJETS_PAR_PORTEUR := 3

# --- Succubes et pactes (décidé par l'utilisateur le 2026-10-27) ------------------------------------------------
## Une succube un étage sur deux : sur les étages 1, 3, 5... (le premier étage choisi par Claude, à valider).
const ETAGES_SUCCUBE := 2
## Pactes de la succube : prix en part des PV max du moment, retirés pour toujours (arrondi au-dessus).
## voile : les ennemis voient 2 fois moins loin et le héros est caché dans l'ombre même en marchant, jusqu'à la fin
## de l'étage ; carte : tout l'étage révélé (salles, cachettes, geôliers et Sans-Visage), jusqu'à la fin de l'étage ;
## baiser : la prochaine capture par un geôlier échoue ; apaisement : un Sans-Visage de l'étage disparaît ;
## mort : la prochaine mort est annulée (réveil au cachot, 1 PV, sans rien perdre).
const PACTES := {"voile": 0.25, "carte": 0.25, "baiser": 0.25, "apaisement": 0.5, "mort": 0.5}
const NOMS_PACTES := {"voile": "Voile", "carte": "Carte de chair", "baiser": "Baiser du geôlier",
	"apaisement": "Apaisement", "mort": "Pacte de mort"}

# --- Chevalier de la mort (l'« imbattable », ex-Sans-Visage ; règles de l'utilisateur, 2026-10-27) -------------
## 300 PV ; chaque coup qu'il subit est ramené à 1 ou 2 dégâts (3 sur un coup critique) ; il frappe **12d2 tranchant
## + 6d2 ombre** (demande de l'utilisateur, 2026-10-27 au soir : 18 à 36 dégâts, 27 en moyenne, très réguliers ;
## avant : 2d12 + 1d2, et à l'origine 2d6 + 1d6 ; but : « que le joueur réalise que c'est un combat ingagnable »).
## Dés fixes, pas réduits d'un cran comme ceux des gobelins ; l'armure et les résistances du héros s'appliquent ensuite.
## Chaque coup qui touche : une chance sur deux de poser **Usure** et **6d2 de mana retirés** au héros (demande de
## l'utilisateur, 2026-10-27).
const CHEVALIER := {"pv": 300, "plafond": [1, 2], "plafond_critique": 3,
	"des": {"tranchant": [[13, 2]]}, "taille_combat": 1.6, "usure": 50, "vol_mana": [[6, 2]],
	"pv_cible": 0.15, "vol_mana_part": 0.15, "ombre_par_mana": 0.5}
## Lame de la mort (2026-11-01, valeurs de l'utilisateur) : 13d2 tranchant + 15 % des PV max de la cible ; chaque coup
## qui touche retire 6d2 + 15 % du mana max de la cible, et la moitié du mana retiré (arrondie en dessous) inflige
## autant de dégâts d'ombre.
## Il suit le héros sur au moins TRAQUE_SALLES salles une fois lancé à sa poursuite (sans perdre sa trace).
const TRAQUE_SALLES := 2

# --- Chasseurs : le Chevalier de la mort et les geôliers parcourent l'étage (règles de l'utilisateur, 2026-10-27) ---
## Toutes les salles vivent : le chevalier part du **milieu de l'étage**, les geôliers loin du départ, puis ils vont
## de salle en salle **au hasard** à la recherche du héros, à leur vitesse, même dans les salles où il n'est pas
## (seul l'affichage est réservé à sa salle). Un **combat** les attire tous : ils apprennent où est le héros et s'y
## rendent. Une **action bruyante** (chaînes brisées) : le chevalier, s'il est à plus de ECART_VACARME salles, se
## téléporte à ECART_VACARME salles du héros et apprend où il est ; les geôliers ne se téléportent pas, ils se
## dirigent vers la salle du bruit. **Courir n'alerte que les ennemis de la salle** (décision de l'utilisateur).
const CHASSEURS := ["imbattable", "geolier"]
const ECART_VACARME := 3
## Temps pour traverser une salle : TRAVERSEE hauteurs de héros à leur vitesse de poursuite dans les salles
## (PresencesSalle.VITESSE_POURSUITE × la vitesse de la salle, 1,8) : chevalier ≈ 9 s (choix de Claude, validé),
## sauf durée fixée dans DUREE_SALLE (geôlier : 6 s, décision de l'utilisateur, 2026-10-27).
const TRAVERSEE := 6.0
const VITESSE_SALLE := 1.8
const DUREE_SALLE := {"geolier": 6.0}

## Éléments possibles pour la faiblesse et la force du boss (révélées, vraies ou fausses, par les diablotins).
const ELEMENTS_BOSS := ["feu", "froid", "foudre", "tranchant", "perforant", "contondant"]
const NOMS_ELEMENTS := {"feu": "le feu", "froid": "le froid", "foudre": "la foudre", "tranchant": "les lames",
	"perforant": "les pointes", "contondant": "les coups de masse"}
const NOMS_ELEMENTS_DE := {"feu": "du feu", "froid": "du froid", "foudre": "de la foudre", "tranchant": "des lames",
	"perforant": "des pointes", "contondant": "des coups de masse"}
## Faiblesse et force du boss, en pourcentage (Degats.multiplicateur) : vulnérabilité +50 % et résistance 60 %
## (gardées telles quelles en attendant la refonte des ennemis, décision de l'utilisateur, 2026-10-30).
const FAIBLESSE_BOSS := 0.50
const FORCE_BOSS := 0.60

## Type de dégâts du boss, pour le message du coffre ancien.
const NOMS_DEGATS_ANTI_BOSS := {"tranchant": "tranchants", "perforant": "perforants", "contondant": "contondants",
	"feu": "de feu", "froid": "de froid", "foudre": "de foudre", "arcane": "d'arcane", "ombre": "d'ombre", "chaos": "de chaos"}

## Genres de présences qui se déplacent (rôdeurs).
const RODEURS := ["groupe", "imbattable", "geolier", "porteur"]
const NOMS := {"groupe": "Gobelins", "imbattable": "Chevalier de la mort", "geolier": "Geôlier", "porteur": "Porteur",
	"boss": "Boss de l'étage", "diablotin": "Diablotin", "prisonnier_cellule": "Prisonnier", "gobelin_blesse": "Gobelin blessé", "prisonnier": "Prisonnier",
	"autel": "Autel de sang", "pupitre": "Pupitre", "ratelier": "Râtelier d'armes", "cachette": "Cachette",
	"coffre_confisque": "Coffre des confiscations", "coffre_gardien": "Coffre ancien", "succube": "Succube",
	"objet_quete": "Objet"}


# ---------------------------------------------------------------------------
# Tirages
# ---------------------------------------------------------------------------

static func _pondere(table: Dictionary) -> int:
	var total := 0
	for k in table:
		total += int(table[k])
	var r := randi_range(1, maxi(1, total))
	for k in table:
		r -= int(table[k])
		if r <= 0:
			return int(k)
	return int(table.keys()[0])


static func _nouvel_id(meta: Dictionary) -> int:
	meta["prochain_id"] = int(meta.get("prochain_id", 0)) + 1
	return meta["prochain_id"]


# ---------------------------------------------------------------------------
# Étage
# ---------------------------------------------------------------------------

## Réglages de l'étage (tirés une fois) : {cachot, boss_faiblesse, boss_force, colere, prochain_id, prepare}.
static func meta(donjon, etage: int) -> Dictionary:
	var tout = U.ga(donjon, "aventure", null)
	if not (tout is Dictionary):
		tout = {}
		donjon._d["aventure"] = tout
	if not tout.has(etage):
		tout[etage] = {}
	return tout[etage]


## Distances (en salles) depuis la salle de départ.
static func distances(salles: Dictionary) -> Dictionary:
	var depart := "1"
	for i in salles:
		if salles[i].get("depart", false):
			depart = i
	var dist := {depart: 0}
	var file := [depart]
	while not file.is_empty():
		var c: String = file.pop_front()
		for v in salles[c].get("connections", []):
			var vs := str(v)
			if not dist.has(vs) and salles.has(vs):
				dist[vs] = dist[c] + 1
				file.append(vs)
	return dist


## Salles ordinaires (ni départ, ni boss, ni bonus, ni marchand, ni cachot).
static func salles_ordinaires(donjon, etage: int) -> Array:
	var salles: Dictionary = donjon.plan_donjon[etage]
	var liste := []
	for i in salles:
		var s: Dictionary = salles[i]
		if s.get("depart", false) or s.get("boss", false) or s.get("type") == "bonus" or s.has("evenement") or s.get("cachot", false):
			continue
		liste.append(i)
	return liste


## Salle « paisible » : un diablotin ou une succube y attend. Aucun autre ennemi n'y est posé ni ne peut y entrer,
## sauf les chasseurs (Chevalier de la mort, geôliers), qui vont partout (demande de l'utilisateur, 2026-10-28).
const PAISIBLES := ["diablotin", "succube"]
const ENNEMIS_ECARTES := ["groupe", "porteur"]
## Refuges (Zones.refuge : la cuisine) : aucun de ces ennemis n'y entre, pas même les chasseurs (décision de
## l'utilisateur, 2026-11-02 : « aucun ennemi dans la cuisine, seuls les PNJ neutres peuvent y aller »).
const ENNEMIS := ["groupe", "porteur", "imbattable", "geolier"]
## Personnages qui ne vont pas dans un refuge (le gobelin blessé est un gobelin).
const PNJ_HORS_REFUGE := ["gobelin_blesse"]


## Salles ordinaires où un ennemi peut être posé ou aller (pas les refuges).
static func salles_pour_ennemis(donjon, etage: int) -> Array:
	var salles: Dictionary = donjon.plan_donjon[etage]
	return salles_ordinaires(donjon, etage).filter(func(i): return not Zones.refuge(salles[i]))


static func salle_paisible(salle: Dictionary) -> bool:
	for p in salle.get("presences", []):
		if p.get("genre", "") == "pnj" and p.get("sous", "") in PAISIBLES and p.get("etat", "actif") == "actif":
			return true
	return false


## Déplace les groupes de gobelins et les porteurs des salles paisibles de l'étage vers d'autres salles ordinaires
## (pas de perte d'ennemis : l'étage garde sa densité), et **tous** les ennemis des refuges (cuisine), chasseurs
## compris. Aussi appelé à chaque lecture d'une salle (anciennes parties).
static func ecarter_des_salles_paisibles(donjon, etage: int) -> void:
	var salles: Dictionary = donjon.plan_donjon[etage]
	var cachot := String(meta(donjon, etage).get("cachot", ""))
	var accueil := salles_pour_ennemis(donjon, etage).filter(func(i): return i != cachot and not salle_paisible(salles[i]))
	if accueil.is_empty():
		return
	for i in salles:
		var refuge := Zones.refuge(salles[i])
		if not salle_paisible(salles[i]) and not refuge:
			continue
		for p in salles[i].get("presences", []).duplicate():
			if p.get("genre", "") in (ENNEMIS if refuge else ENNEMIS_ECARTES) and p.get("etat", "actif") == "actif":
				# Dans la même zone (un squelette des cryptes reste dans les cryptes)
				var zone := String(p.get("zone_ennemis", ""))
				var meme_zone := accueil.filter(func(j): return Zones.zone_salle(salles[j]) == zone)
				salles[i]["presences"].erase(p)
				salles[(meme_zone if not meme_zone.is_empty() else accueil).pick_random()]["presences"].append(p)


## Peuple un étage (une seule fois) : rôdeurs, boss, cachot, personnages, objets, salles verrouillées.
static func preparer_etage(donjon, etage: int) -> void:
	if not donjon.plan_donjon.has(etage):
		return
	var m := meta(donjon, etage)
	if m.get("prepare", false):
		return
	m["prepare"] = true
	m["colere"] = int(m.get("colere", 0))
	var salles: Dictionary = donjon.plan_donjon[etage]
	var dist := distances(salles)
	# Cachot : un cul-de-sac (une seule voisine), le plus loin possible de la salle du boss (une capture ne doit
	# pas rapprocher le héros du boss, demande de l'utilisateur 2026-10-27 ; avant : le plus loin du départ, donc
	# souvent tout près du boss), à au moins CACHOT_DEPART salles du départ
	var dist_boss := {}
	for i in salles:
		if salles[i].get("boss", false):
			dist_boss = distances_depuis(salles, i)
	# Depuis le 2026-10-30 (décision de l'utilisateur) : le cachot est une salle à image de prison, la plus loin du
	# boss (quartier des prisons, PlanSalles.quartier_prisons) ; sinon, comme avant, un cul-de-sac loin du boss.
	PlanSalles.attribuer(donjon, etage)
	var cellules := []
	for i in salles_ordinaires(donjon, etage):
		if PlanSalles.est_prison(String(salles[i].get("salle_peinte", {}).get("image", ""))) and dist.get(i, 0) >= CACHOT_DEPART:
			cellules.append(i)
	var candidats := []
	for i in salles_ordinaires(donjon, etage):
		if salles[i].get("connections", []).size() == 1 and dist.get(i, 0) >= CACHOT_DEPART:
			candidats.append(i)
	if candidats.is_empty():
		candidats = salles_ordinaires(donjon, etage)
	if not cellules.is_empty():
		cellules.sort_custom(func(a, b): return dist_boss.get(a, 0) > dist_boss.get(b, 0))
		m["cachot"] = cellules[0]
		salles[cellules[0]]["cachot"] = true
	elif not candidats.is_empty():
		candidats.sort_custom(func(a, b): return dist_boss.get(a, 0) > dist_boss.get(b, 0))
		# Tous les culs-de-sac sont près du boss (plus près que la moitié des salles) : le cachot va dans la salle
		# ordinaire la plus loin du boss, même si ce n'est pas un cul-de-sac (cas rare, 2026-10-28)
		# (« plus près » au sens strict : avec la médiane, les salles à égalité de distance faisaient passer un cachot à
		# la limite, vu sur les étages de 80 salles, 2026-10-30)
		var d_cachot := int(dist_boss.get(candidats[0], 0))
		var plus_pres := salles.keys().filter(func(i): return int(dist_boss.get(i, 0)) < d_cachot).size()
		if plus_pres < salles.size() / 2:
			var repli := salles_ordinaires(donjon, etage).filter(func(i): return dist.get(i, 0) >= CACHOT_DEPART)
			if not repli.is_empty():
				repli.sort_custom(func(a, b): return dist_boss.get(a, 0) > dist_boss.get(b, 0))
				if int(dist_boss.get(repli[0], 0)) > int(dist_boss.get(candidats[0], 0)):
					candidats = repli
		m["cachot"] = candidats[0]
		salles[candidats[0]]["cachot"] = true
	# Boss : faiblesse et force tirées une fois (les diablotins en parlent)
	var elements := ELEMENTS_BOSS.duplicate()
	elements.shuffle()
	m["boss_faiblesse"] = elements[0]
	m["boss_force"] = elements[1]
	for i in salles:
		var s: Dictionary = salles[i]
		if not s.has("presences"):
			s["presences"] = []
		if s.get("boss", false):
			# Classe du boss tirée dès la création de l'étage (2026-10-30) : l'armure anti-boss en dépend
			var gardien := {"id": _nouvel_id(m), "genre": "boss", "etat": "actif"}
			var mb: Dictionary = membres(gardien)[0]
			m["boss_type_degats"] = Gobelin.type_degats_principal(mb["classe"], mb["sous_classe"])
			s["presences"].append(gardien)
	var ordinaires := salles_ordinaires(donjon, etage)
	var pour_ennemis := salles_pour_ennemis(donjon, etage)  # sans les refuges (cuisine)
	# Groupes d'ennemis (sortes selon la zone de la salle : Zones)
	for i in pour_ennemis:
		for _g in _pondere(GROUPES_PAR_SALLE):
			salles[i]["presences"].append(nouveau_groupe(donjon, m, etage, Zones.zone_salle(salles[i])))
	# Ennemis isolés : dans les salles ordinaires sans groupe
	for i in pour_ennemis:
		var deja: bool = salles[i]["presences"].any(func(q): return q["genre"] == "groupe")
		if not deja and randf() < CHANCE_ISOLE:
			var isole := {"id": _nouvel_id(m), "genre": "groupe", "etat": "actif", "nombre": 1,
				"elite": false, "pacifique": false, "seul": true}
			if Zones.zone_salle(salles[i]) != "":
				isole["zone_ennemis"] = Zones.zone_salle(salles[i])
			salles[i]["presences"].append(isole)
	# Imbattables et geôliers, loin du départ, hors des zones (cryptes...) : ils n'y partent pas, mais peuvent y passer
	var loin := []
	for i in pour_ennemis:
		if dist.get(i, 0) >= DISTANCE_MENACES and Zones.zone_salle(salles[i]) == "":
			loin.append(i)
	if loin.is_empty():
		loin = pour_ennemis.duplicate()
	# Le chevalier part du milieu de l'étage ; ceux de la colère, loin du départ
	var milieu := centre_etage(donjon, etage)
	if milieu != "" and Zones.zone_salle(salles[milieu]) != "":
		milieu = ""
	for k in CHEVALIERS_PAR_ETAGE + m["colere"]:
		ajouter_menace(donjon, etage, "imbattable", [milieu] if k < CHEVALIERS_PAR_ETAGE and milieu != "" else loin)
	for _k in GEOLIERS_PAR_ETAGE:
		ajouter_menace(donjon, etage, "geolier", loin)
	# Personnages et choses : chacun dans une salle ordinaire différente si possible
	var places := ordinaires.duplicate()
	places.shuffle()
	var poser := func(presence: Dictionary) -> void:
		if ordinaires.is_empty():
			return
		var ici = places.pop_back() if not places.is_empty() else ordinaires.pick_random()
		if Zones.refuge(salles[ici]) and presence.get("sous", "") in PNJ_HORS_REFUGE and not pour_ennemis.is_empty():
			places.push_front(ici)  # la cuisine reste libre pour un autre personnage
			ici = pour_ennemis.pick_random()
		salles[ici]["presences"].append(presence)
	for _k in randi_range(DIABLOTINS_PAR_ETAGE[0], DIABLOTINS_PAR_ETAGE[1]):
		poser.call({"id": _nouvel_id(m), "genre": "pnj", "sous": "diablotin", "etat": "actif"})
	if (etage - 1) % ETAGES_SUCCUBE == 0:
		poser.call({"id": _nouvel_id(m), "genre": "pnj", "sous": "succube", "etat": "actif"})
	var evenements := ["gobelin_blesse", "prisonnier", "autel"]
	evenements.shuffle()
	for k in mini(EVENEMENTS_PAR_ETAGE, evenements.size()):
		poser.call({"id": _nouvel_id(m), "genre": "pnj", "sous": evenements[k], "etat": "actif"})
	if randf() < CHANCE_PUPITRE:
		poser.call({"id": _nouvel_id(m), "genre": "objet", "sous": "pupitre", "etat": "actif"})
	poser.call({"id": _nouvel_id(m), "genre": "objet", "sous": "ratelier", "etat": "actif"})
	# Coffre du boss : l'armure anti-boss de l'étage (GenerationObjets.generer_anti_boss)
	if m.has("boss_type_degats"):
		poser.call({"id": _nouvel_id(m), "genre": "objet", "sous": "coffre_gardien", "type_degats": m["boss_type_degats"],
			"etat": "actif"})
	# Salles verrouillées et clés (dans les cachettes)
	var bonus := []
	for i in salles:
		if salles[i].get("type") == "bonus" and salles[i].get("effet_bonus") in ["coffre", "choix_bonus"]:
			bonus.append(i)
	bonus.shuffle()
	var nb_verrous := int(round(bonus.size() * PART_VERROUILLEES))
	if nb_verrous == 0 and not bonus.is_empty():
		nb_verrous = 1
	for k in nb_verrous:
		salles[bonus[k]]["verrouillee"] = true
		salles[bonus[k]]["qualite"] = 1  # rang supplémentaire pour le coffre
	var contenus := []
	for _k in nb_verrous:
		contenus.append("cle")
	var total_cachettes := randi_range(CACHETTES_PAR_ETAGE[0], CACHETTES_PAR_ETAGE[1])
	var poids := {0: CONTENUS_CACHETTES["or"], 1: CONTENUS_CACHETTES["objet"], 2: CONTENUS_CACHETTES["livre"]}
	while contenus.size() < total_cachettes:
		contenus.append(["or", "objet", "livre"][_pondere(poids)])
	for c in contenus:
		poser.call({"id": _nouvel_id(m), "genre": "objet", "sous": "cachette", "contenu": c, "etat": "actif"})
	ecarter_des_salles_paisibles(donjon, etage)
	_fixer_elites(donjon, etage, m)
	_poser_prisonniers(donjon, etage, m)
	_poser_cle_boss(donjon, etage, m, salles_pour_ennemis(donjon, etage), dist)  # après : l'élite à la clé ne bouge plus
	Karma.synchroniser(donjon)  # chevaliers du karma sur ce nouvel étage


## Prisonniers des cellules (ébauche, 2026-11-01) : un prisonnier par **zone de dialogue** « prisonniers » de l'image
## de la salle (tracées avec l'éditeur de zones, touche 5). Le prisonnier est peint dans l'image : la présence n'est
## pas dessinée, elle sert à parler quand le héros entre dans sa zone (``zone``, retournée si la salle est en miroir).
static func _poser_prisonniers(donjon, etage: int, m: Dictionary) -> void:
	var salles: Dictionary = donjon.plan_donjon[etage]
	var cellules := []  # [présence, image] : pour les quêtes des prisonniers (QuetesPrisonniers)
	for i in salles:
		var info: Dictionary = salles[i].get("salle_peinte", {})
		var image := String(info.get("image", ""))
		if image == "" or salles[i].get("boss", false):
			continue
		var miroir := bool(info.get("miroir", false))
		for z in SallePeinte.lire_salle(image).get("prisonniers", []):
			if not (z is Array) or z.size() < 3 or not (z[0] is Array):
				continue  # anciens points d'essai : ignorés
			var zone := []
			var centre := Vector2.ZERO
			for p in z:
				var q := Vector2(768.0 - float(p[0]) if miroir else float(p[0]), float(p[1]))  # fonds de 768 px
				zone.append([q.x, q.y])
				centre += q
			centre /= z.size()
			if not salles[i].has("presences"):
				salles[i]["presences"] = []
			var prisonnier := {"id": _nouvel_id(m), "genre": "pnj", "sous": "prisonnier_cellule", "etat": "actif",
				"zone": zone, "pos": [centre.x, centre.y], "pos_image": "%s%s" % [image, "_m" if miroir else ""]}
			salles[i]["presences"].append(prisonnier)
			cellules.append([prisonnier, image])
	QuetesPrisonniers.assigner(donjon, etage, cellules)


## La salle du boss est fermée ; sa clé est confiée à une élite loin du départ (une élite existante, sinon un groupe
## hostile qui en devient une, sinon une nouvelle élite).
static func _poser_cle_boss(donjon, etage: int, m: Dictionary, ordinaires: Array, dist: Dictionary) -> void:
	var salles: Dictionary = donjon.plan_donjon[etage]
	var boss := ""
	for i in salles:
		if salles[i].get("boss", false):
			boss = i
	if boss == "":
		return
	salles[boss]["verrouillee"] = true
	salles[boss]["cle_boss"] = true
	var loin := ordinaires.filter(func(i): return int(dist.get(i, 0)) >= DISTANCE_CLE_BOSS and not salle_paisible(salles[i]))
	if loin.is_empty():
		loin = ordinaires.duplicate()
	var elites := []
	var hostiles := []
	for i in loin:
		for p in salles[i]["presences"]:
			if p["genre"] == "groupe" and not p.get("pacifique", false) and not p.get("seul", false):
				if p.get("elite", false):
					elites.append(p)
				elif not Zones.elites_fixes(String(p.get("zone_ennemis", ""))):  # pas d'élite de plus dans les cryptes
					hostiles.append(p)
	var porteur: Dictionary = {}
	var hors_zones := loin.filter(func(i): return not Zones.elites_fixes(Zones.zone_salle(salles[i])))
	if not elites.is_empty():
		porteur = elites.pick_random()
	elif not hostiles.is_empty():
		porteur = hostiles.pick_random()
		porteur["elite"] = true
		porteur.erase("membres")
	elif not hors_zones.is_empty():
		porteur = {"id": _nouvel_id(m), "genre": "groupe", "etat": "actif", "nombre": 1, "elite": true, "pacifique": false}
		var ici: String = hors_zones.pick_random()
		if Zones.zone_salle(salles[ici]) != "":
			porteur["zone_ennemis"] = Zones.zone_salle(salles[ici])
		salles[ici]["presences"].append(porteur)
	if not porteur.is_empty():
		porteur["cle_boss"] = etage


## Le héros a-t-il la clé du boss de l'étage ``etage`` ?
static func a_cle_boss(joueur, etage: int) -> bool:
	return etage in U.ga(joueur, "cles_boss", [])


## Donne au héros la clé du boss de l'étage ``etage`` ; renvoie le message.
static func donner_cle_boss(joueur, etage: int) -> String:
	if not (U.ga(joueur, "cles_boss", null) is Array):
		joueur._d["cles_boss"] = []
	if not etage in joueur._d["cles_boss"]:
		joueur._d["cles_boss"].append(etage)
	return "Vous trouvez la **clé du boss** de l'étage %d !" % etage


## Groupe d'ennemis qui rôde : 1 ou 2 selon l'étage (Donjon.ENNEMIS_PAR_ETAGE, plafonné à MAX_PAR_GROUPE), parfois
## un élite ou pacifique, selon les réglages de sa ``zone`` (Zones ; ``""`` : hors zone). Une zone au nombre d'élites
## fixé n'en tire pas au hasard (_fixer_elites les pose).
static func nouveau_groupe(donjon, m: Dictionary, etage: int, zone := "") -> Dictionary:
	var r := Zones.reglages(zone)
	var g := {"id": _nouvel_id(m), "genre": "groupe", "etat": "actif",
		"nombre": mini(donjon.tirer_nombre_ennemis(etage), MAX_PAR_GROUPE),
		"elite": not Zones.elites_fixes(zone) and randf() < float(r["chance_elite"]), "pacifique": false}
	if zone != "":
		g["zone_ennemis"] = zone
	if not g["elite"] and randf() < float(r["chance_pacifique"]):
		g["pacifique"] = true
	return g


## Zones au nombre d'élites fixé (« nombre_elites » de zones.json ; cryptes : 1) : exactement ce nombre d'élites parmi
## leurs groupes. Des groupes hostiles en deviennent (plutôt ceux qui ne sont pas des isolés) ; s'il en manque, de
## nouveaux groupes sont posés dans la zone.
static func _fixer_elites(donjon, etage: int, m: Dictionary) -> void:
	var salles: Dictionary = donjon.plan_donjon[etage]
	for zone in Zones.liste():
		if not Zones.elites_fixes(zone):
			continue
		var voulu := int(Zones.reglages(zone)["nombre_elites"])
		var pieces := salles_ordinaires(donjon, etage).filter(
			func(i): return Zones.zone_salle(salles[i]) == zone and not salle_paisible(salles[i]))
		if pieces.is_empty():
			continue
		var groupes := []
		var isoles := []
		for i in pieces:
			for p in salles[i]["presences"]:
				if p["genre"] == "groupe" and String(p.get("zone_ennemis", "")) == zone:
					p["elite"] = false
					if not p.get("pacifique", false):
						(isoles if p.get("seul", false) else groupes).append(p)
		groupes.shuffle()
		isoles.shuffle()
		var choix: Array = groupes + isoles
		for k in voulu:
			var g: Dictionary
			if k < choix.size():
				g = choix[k]
			else:
				g = nouveau_groupe(donjon, m, etage, zone)
				salles[pieces.pick_random()]["presences"].append(g)
			g["elite"] = true
			g["pacifique"] = false
			g.erase("membres")


## Ajoute un imbattable ou un geôlier dans une des salles ``parmi`` (toutes les ordinaires si vide).
static func ajouter_menace(donjon, etage: int, genre: String, parmi := []) -> Dictionary:
	var m := meta(donjon, etage)
	var tout: Dictionary = donjon.plan_donjon[etage]
	var liste: Array = (parmi if not parmi.is_empty() else salles_ordinaires(donjon, etage)).filter(
		func(i): return not Zones.refuge(tout[i]))
	if liste.is_empty():
		return {}
	var p := {"id": _nouvel_id(m), "genre": genre, "etat": "actif"}
	var salle: Dictionary = donjon.plan_donjon[etage][liste.pick_random()]
	if not salle.has("presences"):
		salle["presences"] = []
	salle["presences"].append(p)
	return p


## Présences encore là d'une salle (prépare l'étage si besoin).
static func presences(donjon, salle: Dictionary) -> Array:
	preparer_etage(donjon, int(donjon.salle_actuelle[0]))
	if salle_paisible(salle) or Zones.refuge(salle):
		ecarter_des_salles_paisibles(donjon, int(donjon.salle_actuelle[0]))
	var liste := []
	for p in salle.get("presences", []):
		if p.get("etat", "actif") == "actif" or (p["genre"] == "objet" and not p["sous"] in ["cachette", "cadavre", "objet_quete"]):
			liste.append(p)
	return liste


## Vrai si la présence se déplace dans la salle.
static func est_rodeur(p: Dictionary) -> bool:
	return p.get("genre", "") in RODEURS


# ---------------------------------------------------------------------------
# Combats
# ---------------------------------------------------------------------------

## Gobelins d'une présence (groupe, porteur, boss) : [{classe, sous_classe, image}], l'élite en premier.
## Tirés une fois et gardés dans la présence (« membres ») : la salle les dessine et le combat les affronte,
## pour que l'image corresponde à l'ennemi. Les présences d'avant le 2026-10-27 les reçoivent à la première lecture.
static func membres(p: Dictionary) -> Array:
	if not p.has("membres"):
		var liste := []
		var groupe: bool = p.get("genre", "") == "groupe"
		var nombre := maxi(1, int(p.get("nombre", 1))) if groupe else 1
		var r := Zones.reglages(String(p.get("zone_ennemis", "")))
		var elite: bool = groupe and p.get("elite", false)
		# Une seule sorte par groupe (zones.json, « ennemis ») ; boss, porteurs et pacifiques : gobelins
		var sorte := Zones.tirer(r["ennemis"]) if groupe and not p.get("pacifique", false) else "gobelin"
		for _k in nombre:
			liste.append(Zones.membre(sorte))
		if elite:
			# L'élite et son escorte (« suite_elite » : gobelins hors zone, comme avant ; squelettes dans les cryptes)
			sorte = Zones.tirer(r["suite_elite"])
			for k in range(1, nombre):
				liste[k] = Zones.membre(sorte)
			liste[0] = Zones.membre(Zones.tirer(r["elites"]))
		elif sorte == "squelette" and nombre >= 2 and randf() < float(r["chance_feticheur"]):
			liste[0] = Zones.membre("feticheur")  # squelettes menés par un féticheur gobelin (pas une élite)
		if sorte == "squelette":
			p["vitesse_poursuite"] = VITESSE_SQUELETTES
		# Un loup n'est jamais seul : il accompagne un archer ou un chaman
		var dresseur := liste.any(func(mb): return mb["sous_classe"] in ["archer", "chaman"])
		if groupe and dresseur and Zones.est_gobelin(sorte) and not p.get("seul", false) and liste.size() < MAX_PAR_GROUPE \
				and randf() < float(r["chance_loup"]):
			liste.append(Creatures.membre("loup"))
		p["membres"] = liste
	return p["membres"]


## Ennemis d'une présence (au moment du contact), d'après ses ``membres``.
static func ennemis_de(donjon, p: Dictionary) -> Array:
	var n := int(donjon.niveau_joueur)
	var genre: String = p["genre"]
	var liste := []
	if genre == "boss":
		var mb: Dictionary = membres(p)[0]
		var boss := Gobelin.nouveau(donjon, n).generer_boss_gobelin(donjon, n, [mb["classe"], mb["sous_classe"]])
		boss._d["image"] = mb["image"]
		var m := meta(donjon, int(donjon.salle_actuelle[0]))
		if m.has("boss_faiblesse"):
			Degats.ajouter_pourcentages(boss, {String(m["boss_faiblesse"]): FAIBLESSE_BOSS}, {String(m["boss_force"]): FORCE_BOSS})
		liste.append(boss)
	elif genre == "imbattable":
		liste.append(creer_imbattable(donjon))
	elif genre == "porteur":
		var mp: Dictionary = membres(p)[0]
		var porteur := Gobelin.nouveau(donjon, n).generer_mini_boss_gobelin(donjon, n, [mp["classe"], mp["sous_classe"]])
		porteur._d["image"] = mp["image"]
		porteur._d["nom"] = "Porteur " + String(porteur._d["nom"]).trim_prefix("Élite ")
		porteur._d["points_de_vie_max"] = int(porteur._d["points_de_vie_max"] * 1.5)
		porteur._d["points_de_vie"] = porteur._d["points_de_vie_max"]
		porteur._d["objets_portes"] = p.get("objets", [])
		liste.append(porteur)
	else:
		var tous := membres(p)
		for k in tous.size():
			var mg: Dictionary = tous[k]
			var cs := [mg["classe"], mg["sous_classe"]]
			var g: Gobelin
			if Creatures.est_creature(mg["sous_classe"]):
				g = Creatures.creer(donjon, mg["sous_classe"])
			elif k == 0 and p.get("elite", false):
				g = Gobelin.nouveau(donjon, n).generer_mini_boss_gobelin(donjon, n, cs)
				g._d["butin_garanti"] = true
				if p.has("nom_elite"):  # élite d'une quête de prisonnier (« Faux prisonnier »)
					g._d["nom"] = String(p["nom_elite"])
				if p.get("renforce", false):  # élite+ d'une quête de prisonnier
					g._d["nom"] = String(g._d["nom"]) + "+"
					g._d["points_de_vie_max"] = int(g._d["points_de_vie_max"] * QuetesPrisonniers.FACTEUR_RENFORCE)
					g._d["points_de_vie"] = g._d["points_de_vie_max"]
			else:
				g = Gobelin.nouveau(donjon, n).generer_gobelin(donjon, n, cs)
			g._d["image"] = mg["image"]
			liste.append(g)
		if p.get("pacifique", false):
			for g in liste:
				g._d["pacifique"] = true
				g._d["nom"] = String(g._d["nom"]) + " (pacifique)"
	return liste


## Le Chevalier de la mort (CHEVALIER) : 300 PV, coups subis ramenés à 1-2 (3 en critique), frappe 12d2 tranchant
## + 6d2 ombre ; mieux vaut le fuir.
static func creer_imbattable(donjon) -> Gobelin:
	var n := int(donjon.niveau_joueur)
	var e := Gobelin.nouveau(donjon, n)
	e._d["nom"] = "Chevalier de la mort"
	e._d["classe"] = "guerrier"
	e._d["sous_classe"] = "combattant"  # son IA : Coup d'épée
	e._d["sans_animation"] = true  # pas les images du gobelin combattant...
	e._d["anim_combat"] = "chevalier"  # ...mais les siennes (CombatAnime : deux attaques, deux parades)
	e._d["centre_combat"] = true  # seul face au héros, au milieu de l'écran
	e._d["stats_cachees"] = true  # fiche et info-bulle : « ??? » partout (demande de l'utilisateur, 2026-10-31)
	var lame = Competences.creer("Coup_d_epee")
	lame._d["nom"] = "Lame de la mort"
	lame._d["type_degats"] = ["tranchant"]
	lame._d["cout_mana"] = 0
	lame._d["type_alteration"] = {"usure": CHEVALIER["usure"]}
	e._d["competences"] = [lame]
	e._d["vol_mana_des"] = CHEVALIER["vol_mana"].duplicate(true)
	e._d["vol_mana_part"] = CHEVALIER["vol_mana_part"]
	e._d["ombre_par_mana"] = CHEVALIER["ombre_par_mana"]
	e._d["pourcentage_pv_cible"] = {"tranchant": CHEVALIER["pv_cible"]}
	e._d["des_fixes"] = CHEVALIER["des"].duplicate(true)
	# Ses dés comptent en entier, même si la réduction commune des ennemis revenait (Ennemis.MULTIPLICATEUR_DEGATS_ENNEMIS)
	e._d["pourcentage_degats_physique"] = 1.0
	e._d["pourcentage_degats_magique"] = 1.0
	e._d["pourcentage_degats_elementaire"] = 1.0
	e._d["plafond_degats"] = CHEVALIER["plafond"].duplicate()
	e._d["plafond_degats_critique"] = CHEVALIER["plafond_critique"]
	e._d["points_de_vie_max"] = CHEVALIER["pv"]
	e._d["points_de_vie"] = CHEVALIER["pv"]
	e._d["image"] = "chevalier_de_la_mort.png"
	e._d["taille_affichage"] = CHEVALIER["taille_combat"]
	return e


## Distances (en salles) depuis la salle ``depuis``.
static func distances_depuis(salles: Dictionary, depuis: String) -> Dictionary:
	var dist := {depuis: 0}
	var file := [depuis]
	while not file.is_empty():
		var c: String = file.pop_front()
		for v in salles[c].get("connections", []):
			var vs := str(v)
			if not dist.has(vs) and salles.has(vs):
				dist[vs] = dist[c] + 1
				file.append(vs)
	return dist


## Salle ordinaire au milieu de l'étage : celle d'où la salle la plus éloignée est la plus proche.
static func centre_etage(donjon, etage: int) -> String:
	var salles: Dictionary = donjon.plan_donjon[etage]
	var meilleure := ""
	var meilleur_ecart := 1 << 20
	for i in salles_ordinaires(donjon, etage):
		var ecart: int = distances_depuis(salles, i).values().max()
		if ecart < meilleur_ecart or (ecart == meilleur_ecart and randf() < 0.5):
			meilleur_ecart = ecart
			meilleure = i
	return meilleure


## Chasseurs encore actifs de l'étage : [[présence, salle], ...].
static func chasseurs(donjon, etage: int) -> Array:
	var liste := []
	var salles: Dictionary = donjon.plan_donjon.get(etage, {})
	for i in salles:
		for p in salles[i].get("presences", []):
			if p.get("genre") in CHASSEURS and p.get("etat", "actif") == "actif":
				liste.append([p, i])
	return liste


## Secondes que met le chasseur ``p`` pour traverser une salle.
static func duree_salle(p: Dictionary) -> float:
	if DUREE_SALLE.has(p["genre"]):
		return DUREE_SALLE[p["genre"]]
	return TRAVERSEE / (PresencesSalle.VITESSE_POURSUITE.get(p["genre"], 0.5) * VITESSE_SALLE)


## Salle suivante du chasseur ``p`` qui est dans ``ici`` : un pas vers sa destination (« but ») s'il en a une, sinon
## une voisine au hasard (pas celle d'où il vient, sauf impasse ; jamais la salle du boss).
static func prochaine_salle(donjon, p: Dictionary, ici: String) -> String:
	var salles: Dictionary = donjon.plan_donjon[int(donjon.salle_actuelle[0])]
	if p.has("but") and str(p["but"]) == ici:
		p.erase("but")
	if p.has("but") and salles.has(str(p["but"])):
		var dist := distances_depuis(salles, str(p["but"]))
		var pas := ""
		for v in salles[ici].get("connections", []):
			if salles.has(str(v)) and Zones.refuge(salles[str(v)]):
				continue  # jamais dans un refuge (cuisine) : il s'arrête à la porte
			if pas == "" or dist.get(str(v), 1 << 20) < dist.get(pas, 1 << 20):
				pas = str(v)
		if pas != "" and dist.get(pas, 1 << 20) < dist.get(ici, 1 << 20):
			return pas
		p.erase("but")  # le but est dans un refuge (ou hors d'atteinte) : il renonce et erre
	var voisines := []
	for v in salles[ici].get("connections", []):
		if salles.has(str(v)) and not salles[str(v)].get("boss", false) and not Zones.refuge(salles[str(v)]):
			voisines.append(str(v))
	if voisines.size() > 1:
		voisines.erase(str(p.get("venu_de", "")))
	return voisines.pick_random() if not voisines.is_empty() else ici


## Fait passer le chasseur ``p`` de la salle ``de`` à la salle ``vers`` (données seulement).
static func changer_de_salle(donjon, p: Dictionary, de: String, vers: String) -> void:
	var salles: Dictionary = donjon.plan_donjon[int(donjon.salle_actuelle[0])]
	_deplacer(salles, p, vers)
	p["venu_de"] = de
	p["marche"] = 0.0
	if str(p.get("but", "")) == vers:
		p.erase("but")


## Fait avancer de ``delta`` secondes les chasseurs qui ne sont pas dans la salle du héros (eux, l'écran les fait
## marcher). Renvoie ceux qui entrent dans la salle du héros : [[présence, salle d'où il vient], ...].
static func avancer_chasseurs(donjon, delta: float) -> Array:
	var etage := int(donjon.salle_actuelle[0])
	var ici := str(donjon.salle_actuelle[1])
	var entrants := []
	for c in chasseurs(donjon, etage):
		var p: Dictionary = c[0]
		if c[1] == ici:
			continue
		p["marche"] = float(p.get("marche", 0.0)) + delta
		if p["marche"] < duree_salle(p):
			continue
		var vers := prochaine_salle(donjon, p, c[1])
		if vers == c[1]:
			p["marche"] = 0.0
			continue
		var cherche := p.has("but")
		changer_de_salle(donjon, p, c[1], vers)
		if vers == ici:
			p["cherche"] = cherche  # il venait chercher le héros : il sait où il est en entrant
			entrants.append([p, c[1]])
	return entrants


## Un combat commence dans la salle du héros : tous les chasseurs de l'étage apprennent où il est et s'y rendent.
static func attirer(donjon) -> void:
	for c in chasseurs(donjon, int(donjon.salle_actuelle[0])):
		if c[1] != str(donjon.salle_actuelle[1]):
			c[0]["but"] = str(donjon.salle_actuelle[1])


## Action bruyante du héros (chaînes brisées) : le chevalier à plus de ECART_VACARME salles se téléporte à
## ECART_VACARME salles du héros ; chevaliers et geôliers se dirigent vers la salle du bruit. Renvoie le nombre de
## chevaliers alertés.
static func vacarme(donjon) -> int:
	var etage := int(donjon.salle_actuelle[0])
	var salles: Dictionary = donjon.plan_donjon[etage]
	var ici := str(donjon.salle_actuelle[1])
	var dist := distances_depuis(salles, ici)
	var a_portee := []
	for i in dist:
		if dist[i] == ECART_VACARME and not salles[i].get("boss", false) and not Zones.refuge(salles[i]):
			a_portee.append(i)
	var chevaliers := 0
	for c in chasseurs(donjon, etage):
		var p: Dictionary = c[0]
		if c[1] == ici:
			continue
		p["but"] = ici
		if p["genre"] == "imbattable":
			chevaliers += 1
			if dist.get(c[1], 1 << 20) > ECART_VACARME and not a_portee.is_empty():
				_deplacer(salles, p, a_portee.pick_random())
				p["marche"] = 0.0
				p.erase("venu_de")
	return chevaliers


## Chance de fuir le combat en cours.
static func chance_fuite(joueur, ennemis: Array) -> float:
	for e in ennemis:
		if U.ga(e, "est_boss", false):
			return FUITE_BOSS
	var c := FUITE_BASE + FUITE_PAR_DEXTERITE * float(U.num(joueur, "dextérité")) - FUITE_PAR_ENNEMI * maxi(0, ennemis.size() - 1)
	return clampf(c, FUITE_BORNES[0], FUITE_BORNES[1])


## Après un combat gagné contre la présence ``p`` : elle disparaît (son corps reste : ``laisser_cadavre``) ; tuer
## des pacifiques est un acte de cruauté (karma −1, Karma) ; un porteur rend les objets qu'il portait.
## Renvoie le message à afficher.
static func apres_victoire(donjon, p: Dictionary) -> String:
	p["etat"] = "vaincu"
	var messages := []
	if p.get("pacifique", false):
		Statistiques.noter(donjon.personnage, "pacifiques_tues", membres(p).size())
		messages.append("Ils ne voulaient pas se battre...")
		messages.append(Karma.acte(donjon, "tuer_pacifiques"))
	if p["genre"] == "porteur":
		for objet in p.get("objets", []):
			donjon.personnage.recevoir_objet(objet)
		messages.append("Vous récupérez %d objet(s) confisqué(s)." % p.get("objets", []).size())
		p["objets"] = []
	if p["genre"] == "boss":
		Statistiques.noter(donjon.personnage, "boss_vaincus")
	if p.has("evenement_victoire"):  # élite envoyé par un prisonnier (QuetesPrisonniers)
		QuetesPrisonniers.evenement(donjon, String(p["evenement_victoire"]))
	return " ".join(messages.filter(func(x): return x != ""))


# ---------------------------------------------------------------------------
# Cadavres et âmes (règles de l'utilisateur, 2026-10-31)
# ---------------------------------------------------------------------------

## Âmes d'un ennemi vaincu : 1 par ennemi ; une **élite** en vaut AMES_ELITE, le **boss** de
## l'étage AMES_BOSS (décision de l'utilisateur).
const AMES_ELITE := 3
const AMES_BOSS := 5


static func ames_de(p: Dictionary) -> int:
	if p["genre"] == "boss":
		return AMES_BOSS
	var n := membres(p).size()
	if p.get("elite", false):
		return AMES_ELITE + maxi(0, n - 1)
	return maxi(1, n)


## Laisse le corps de la présence vaincue ``p`` dans la salle actuelle, à ``pos`` (pixels de l'image, ou rien) :
## une présence « objet / cadavre » à fouiller, qui ne disparaît que quand on siphonne son âme. Renvoie le corps.
static func laisser_cadavre(donjon, p: Dictionary, pos = null, cle_image := "") -> Dictionary:
	if not p["genre"] in ["groupe", "porteur", "boss"]:
		return {}
	var etage := int(donjon.salle_actuelle[0])
	var m := meta(donjon, etage)
	var corps := {"id": _nouvel_id(m), "genre": "objet", "sous": "cadavre", "etat": "actif", "ames": ames_de(p),
		"pacifique": p.get("pacifique", false), "fouille": false, "membres": membres(p).duplicate(true),
		"nom_corps": "le boss" if p["genre"] == "boss" else ("les corps" if membres(p).size() > 1 else "le corps")}
	if p.has("cle_boss"):
		corps["cle_boss"] = p["cle_boss"]
	if not p.get("objets_quete", []).is_empty():
		corps["objets_quete"] = p["objets_quete"].duplicate()
	if pos is Vector2:
		corps["pos"] = [pos.x, pos.y]
		corps["pos_image"] = cle_image
	var salle: Dictionary = donjon.salle_courante()
	if not salle.has("presences"):
		salle["presences"] = []
	salle["presences"].append(corps)
	return corps


## Le héros s'approche d'un corps : le fouiller (une fois), siphonner son âme (il disparaît), ou partir.
## Renvoie le message à afficher.
static func cadavre(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var messages := []
	while p.get("etat") == "actif":
		var n := int(p.get("ames", 1))
		var boutons := []
		if not p.get("fouille", false):
			boutons.append("Fouiller %s" % p.get("nom_corps", "le corps"))
		boutons.append("Siphonner %s (%d)" % ["son âme" if n == 1 else "leurs âmes", n])
		boutons.append("Partir")
		var texte: String = "Le corps gît sur les dalles." if messages.is_empty() else messages[-1]
		var choix := await Ecrans.dialogue("Cadavre", texte, boutons, Color8(150, 120, 170))
		var action: String = boutons[choix] if choix < boutons.size() else "Partir"
		if action.begins_with("Fouiller"):
			p["fouille"] = true
			messages.append(Fouille.fouiller_corps(joueur, donjon, p.get("pacifique", false)))
			if p.has("cle_boss") and not p.get("cle_prise", false):
				p["cle_prise"] = true
				messages.append(donner_cle_boss(joueur, int(p["cle_boss"])))
			var quete := QuetesPrisonniers.prendre_objets(joueur, p)
			if quete != "":
				messages.append(quete)
		elif action.begins_with("Siphonner"):
			p["etat"] = "siphonne"
			if not p.get("objets_quete", []).is_empty():
				messages.append("Le corps se dissipe... il laisse quelque chose derrière lui. " + QuetesPrisonniers.prendre_objets(joueur, p))
			if p.has("cle_boss") and not p.get("cle_prise", false):
				# La clé ne disparaît pas avec le corps : elle tombe à terre
				p["cle_prise"] = true
				messages.append("Le corps se dissipe... et une clé tinte sur les dalles. " + donner_cle_boss(joueur, int(p["cle_boss"])))
			var points: int = joueur.gagner_ames(n)
			var texte_ames := "Vous aspirez %d âme%s. Une force froide vous traverse (âmes : %d / %d)." % [
				n, "s" if n > 1 else "", int(U.num(joueur, "ames")), Personnage.AMES_PAR_POINT]
			if points > 0:
				texte_ames += " +%d point%s de caractéristique à répartir (touche C)." % [points, "s" if points > 1 else ""]
			messages.append(texte_ames)
		else:
			break
	return " ".join(messages)


# ---------------------------------------------------------------------------
# Capture par un geôlier
# ---------------------------------------------------------------------------

## Le geôlier emmène le héros au cachot : tous ses objets et son or sont confisqués (coffre des confiscations,
## perdus, ou portés par un porteur), il se réveille dans la salle du cachot. Le geôlier repart dans une autre salle.
## Renvoie le message à afficher.
static func capturer(donjon, geolier: Dictionary) -> String:
	var etage := int(donjon.salle_actuelle[0])
	preparer_etage(donjon, etage)
	var m := meta(donjon, etage)
	var joueur = donjon.personnage
	var salles: Dictionary = donjon.plan_donjon[etage]
	# Tout l'équipement revient dans l'inventaire, puis l'inventaire est confisqué. L'arme portée n'est jamais perdue
	# ni portée par un porteur : elle est toujours dans le coffre des confiscations (demande de l'utilisateur).
	var arme = U.ga(joueur, "arme_equipee", null)  # absente si une capture précédente l'a déjà prise
	if Arme.est_lance_de_test(arme):
		arme = null
	# La lance de test n'est jamais confisquée (demande de l'utilisateur, 2026-10-29) : portée, elle le reste ;
	# dans le sac, elle y reste.
	for cle in joueur.equipements.keys():
		if not Arme.est_lance_de_test(joueur.equipements[cle]):
			joueur.desequiper_item(cle)
	var objets: Array = joueur.inventaire.filter(func(o): return not Arme.est_lance_de_test(o))
	var gardes: Array = joueur.inventaire.filter(func(o): return Arme.est_lance_de_test(o))
	joueur.inventaire.clear()
	joueur.inventaire.append_array(gardes)
	var or_confisque := int(joueur.piece_or)
	joueur.piece_or = 0
	var coffre := []
	var portes := []
	var perdus := 0
	for objet in objets:
		if objet == arme:
			coffre.push_front(objet)  # rendue en premier à l'ouverture du coffre : c'est elle qui est rééquipée
			continue
		var sort := _pondere({0: CONFISCATION["coffre"], 1: CONFISCATION["perdu"], 2: CONFISCATION["porteur"]})
		if sort == 0:
			coffre.append(objet)
		elif sort == 1:
			perdus += 1
		else:
			portes.append(objet)
	var cachot := String(m.get("cachot", "1"))
	var ailleurs := []
	for i in salles_ordinaires(donjon, etage):
		if i != cachot:
			ailleurs.append(i)
	if ailleurs.is_empty():
		ailleurs = [cachot]
	# Les porteurs ne vont pas dans une salle paisible (diablotin, succube) ni dans un refuge (cuisine)
	var pour_porteurs := ailleurs.filter(func(i): return not salle_paisible(salles[i]) and not Zones.refuge(salles[i]))
	if pour_porteurs.is_empty():
		pour_porteurs = ailleurs
	if not coffre.is_empty() or or_confisque > 0:
		salles[salle_du_coffre(salles, cachot, ailleurs)]["presences"].append({"id": _nouvel_id(m), "genre": "objet", "sous": "coffre_confisque",
			"etat": "actif", "objets": coffre, "or": or_confisque})
	while not portes.is_empty():
		var lot := portes.slice(0, OBJETS_PAR_PORTEUR)
		portes = portes.slice(OBJETS_PAR_PORTEUR)
		salles[pour_porteurs.pick_random()]["presences"].append({"id": _nouvel_id(m), "genre": "porteur", "etat": "actif", "objets": lot})
	# Le geôlier quitte sa salle pour une autre (jamais le cachot ni un refuge)
	var pour_geolier := ailleurs.filter(func(i): return not Zones.refuge(salles[i]))
	_deplacer(salles, geolier, (pour_geolier if not pour_geolier.is_empty() else ailleurs).pick_random())
	donjon.salle_actuelle = [etage, int(cachot)]
	salles[cachot]["visitee"] = true
	joueur.points_de_vie = maxf(joueur.points_de_vie, 1)
	Statistiques.noter(joueur, "captures")
	return ("Le geôlier vous assomme. Vous vous réveillez au cachot, dépouillé de tout. " +
		"Vos affaires sont quelque part dans l'étage... certaines sont même portées par des gobelins.%s" % (
		" (%d objet(s) perdus pour de bon)" % perdus if perdus > 0 else ""))


## Salle du coffre des confiscations (objets et or) : à COFFRE_PRES_DU_CACHOT salles au plus du cachot, là où le
## héros se réveille (demande de l'utilisateur, 2026-10-31 ; avant : n'importe où dans l'étage). Une salle paisible
## (diablotin, succube) convient aussi. S'il n'y en a aucune assez près, la plus proche.
static func salle_du_coffre(salles: Dictionary, cachot: String, parmi: Array) -> String:
	var d := distances_depuis(salles, cachot)
	# Jamais dans une salle fermée à clé : le coffre doit rester accessible sans clé
	var proches := parmi.filter(func(i): return d.has(i) and int(d[i]) >= 1 and int(d[i]) <= COFFRE_PRES_DU_CACHOT \
		and not salles[i].get("verrouillee", false))
	if not proches.is_empty():
		return proches.pick_random()
	var tries := parmi.filter(func(i): return d.has(i))
	if tries.is_empty():
		return parmi.pick_random()
	tries.sort_custom(func(a, b): return int(d[a]) < int(d[b]))
	return tries[0]


## Retire la présence ``p`` de sa salle et la pose dans la salle ``vers``.
static func _deplacer(salles: Dictionary, p: Dictionary, vers: String) -> void:
	for i in salles:
		salles[i]["presences"] = salles[i].get("presences", []).filter(func(q): return q.get("id") != p.get("id"))
	salles[vers]["presences"].append(p)


# ---------------------------------------------------------------------------
# Pactes de la succube
# ---------------------------------------------------------------------------

## Prix d'un pacte en PV max pour le héros (arrondi au-dessus).
static func prix_pacte(joueur, cle: String) -> int:
	return int(ceil(float(joueur.points_de_vie_max) * PACTES[cle]))


## Pactes en cours du héros (baiser, mort : jusqu'à leur usage) : dictionnaire enregistré avec lui.
static func _pactes(joueur) -> Dictionary:
	if not (U.ga(joueur, "pactes", null) is Dictionary):
		joueur._d["pactes"] = {}
	return joueur._d["pactes"]


## Le pacte ``cle`` agit : voile et carte pour l'étage actuel, baiser et mort jusqu'à leur usage.
static func pacte_actif(donjon, cle: String) -> bool:
	if cle in ["voile", "carte"]:
		return bool(meta(donjon, int(donjon.salle_actuelle[0])).get(cle, false))
	return bool(_pactes(donjon.personnage).get(cle, false))


## Chevaliers de la mort encore présents dans l'étage actuel.
static func sans_visage_etage(donjon) -> Array:
	var liste := []
	for s in donjon.plan_donjon[int(donjon.salle_actuelle[0])].values():
		for p in s.get("presences", []):
			if p.get("genre") == "imbattable" and p.get("etat", "actif") == "actif":
				liste.append(p)
	return liste


## Pourquoi le pacte ``cle`` ne peut pas être scellé maintenant ("" : il le peut).
static func pacte_impossible(donjon, cle: String) -> String:
	var joueur = donjon.personnage
	if pacte_actif(donjon, cle):
		return "déjà scellé"
	if cle == "apaisement" and sans_visage_etage(donjon).is_empty():
		return "aucun Chevalier de la mort ici"
	if prix_pacte(joueur, cle) >= int(joueur.points_de_vie_max):
		return "pas assez de vie"
	return ""


## Scelle le pacte ``cle`` : le héros perd pour toujours sa part de PV max, le pacte agit. Renvoie le message.
static func sceller_pacte(donjon, cle: String) -> String:
	var joueur = donjon.personnage
	var prix := prix_pacte(joueur, cle)
	joueur._d["points_de_vie_max"] = int(joueur.points_de_vie_max) - prix
	joueur._d["points_de_vie"] = mini(int(joueur.points_de_vie), int(joueur.points_de_vie_max))
	joueur._d["pv_cedes"] = int(U.ga(joueur, "pv_cedes", 0)) + prix
	Statistiques.noter(joueur, "pactes")
	var perte := "Vous perdez %d PV max (il vous en reste %d). " % [prix, joueur.points_de_vie_max]
	match cle:
		"voile", "carte":
			meta(donjon, int(donjon.salle_actuelle[0]))[cle] = true
		"baiser", "mort":
			_pactes(joueur)[cle] = true
		"apaisement":
			var p: Dictionary = sans_visage_etage(donjon).pick_random()
			p["etat"] = "apaise"
			for s in donjon.plan_donjon[int(donjon.salle_actuelle[0])].values():
				s["presences"] = s.get("presences", []).filter(func(q): return q.get("id") != p.get("id"))
	return perte + {
		"voile": "Une ombre tiède se pose sur vous. Jusqu'à ce que vous quittiez l'étage, les yeux glissent sur vous.",
		"carte": "Des images brûlantes envahissent votre esprit : tout l'étage, ses secrets et ceux qui y rôdent (carte).",
		"baiser": "Ses lèvres sont glacées. « La prochaine main de fer qui te touchera se brûlera. »",
		"apaisement": "Quelque part dans l'étage, un pas de fer s'arrête net. Un Chevalier de la mort se dissout dans l'ombre.",
		"mort": "« Ta mort m'appartient, maintenant. Je ne la laisserai pas à un autre... une fois. »",
	}[cle]


## Retire le pacte ``cle`` du héros s'il l'avait (baiser, mort) ; vrai s'il l'avait.
static func consommer_pacte(joueur, cle: String) -> bool:
	var pactes := _pactes(joueur)
	if not pactes.get(cle, false):
		return false
	pactes.erase(cle)
	return true


## Baiser du geôlier : la capture échoue, le geôlier part dans une autre salle de l'étage. Renvoie le message.
static func repousser_geolier(donjon, geolier: Dictionary) -> String:
	var etage := int(donjon.salle_actuelle[0])
	var ici := str(donjon.salle_actuelle[1])
	var cachot := String(meta(donjon, etage).get("cachot", ""))
	var ailleurs := salles_pour_ennemis(donjon, etage).filter(func(i): return i != ici and i != cachot)
	if not ailleurs.is_empty():
		_deplacer(donjon.plan_donjon[etage], geolier, ailleurs.pick_random())
	return "Sa main de fer se pose sur vous... et se retire dans un cri : le baiser de la succube l'a brûlé. Le geôlier s'enfuit."


## Pacte de mort : la mort est annulée, le héros se réveille au cachot de l'étage avec 1 PV, sans rien perdre.
## Faux si le héros n'avait pas ce pacte.
static func relever_par_pacte(donjon) -> bool:
	var joueur = donjon.personnage
	if not consommer_pacte(joueur, "mort"):
		return false
	Statistiques.mort = false
	Statistiques.cause_mort = ""
	joueur._d["points_de_vie"] = 1
	joueur.fin_alteration()
	joueur.restaurer_points_d_action()
	joueur.magie = true
	var etage := int(donjon.salle_actuelle[0])
	preparer_etage(donjon, etage)
	var cachot := String(meta(donjon, etage).get("cachot", str(donjon.salle_actuelle[1])))
	donjon.salle_actuelle = [etage, int(cachot)]
	donjon.plan_donjon[etage][cachot]["visitee"] = true
	return true


# ---------------------------------------------------------------------------
# Objets à utiliser
# ---------------------------------------------------------------------------

## Libellé de l'action proposée près d'une présence immobile (« Parler », « Lire »...).
static func action(p: Dictionary) -> String:
	if p["genre"] == "pnj":
		return {"autel": "Examiner l'autel", "gobelin_blesse": "S'approcher"}.get(p["sous"], "Parler")
	if p.get("sous") == "objet_quete":
		return "Ramasser : %s" % String(p.get("objet", "l'objet"))
	return {"pupitre": "Lire", "ratelier": "Fouiller le râtelier", "cachette": "Examiner",
		"coffre_confisque": "Ouvrir le coffre", "coffre_gardien": "Ouvrir le coffre", "cadavre": "Examiner le corps"}.get(p["sous"], "Utiliser")


## Un grimoire : le héros apprend un sort tiré au hasard (palier 0 à l'étage, 5 au plus).
## Le joueur ne choisit son sort qu'au tout début de la partie ; ensuite, les sorts viennent des grimoires.
## Le sort n'est plus « déjà amélioré » depuis le 2026-11-03 (amélioration supprimée, à reforger).
static func lire_livre(joueur, etage := 1) -> String:
	Statistiques.noter(joueur, "livres_lus")
	var palier_max := clampi(etage, 1, 5)
	var candidats := []
	for m in joueur.magies_disponibles:
		if _palier(m) <= palier_max:
			candidats.append(m)
	if candidats.is_empty():
		return "Ce grimoire ne vous apprend rien de neuf."
	var sort = candidats.pick_random()
	joueur.magies_disponibles.erase(sort)
	joueur.magies_apprises.append(sort)
	return "Vous déchiffrez un grimoire : vous apprenez %s !" % sort.nom


## Palier d'un sort (0 pour une compétence sans palier).
static func _palier(sort) -> int:
	return int(sort.PALIER) if sort is Sort and sort.PALIER != null else 0


## Utilise un pupitre, un râtelier, une cachette ou le coffre des confiscations ; renvoie le message.
static func utiliser_objet(donjon, p: Dictionary) -> String:
	var joueur = donjon.personnage
	var etage := int(donjon.salle_actuelle[0])
	if p.get("etat") != "actif":
		return {"pupitre": "Le pupitre est vide.", "ratelier": "Le râtelier est vide.",
			"coffre_confisque": "Le coffre est vide.", "coffre_gardien": "Le coffre est vide."}.get(p["sous"], "Il n'y a plus rien ici.")
	p["etat"] = "utilise"
	match p["sous"]:
		"objet_quete":
			var o = QuetesPrisonniers.creer_objet(String(p.get("objet", "")))
			joueur.recevoir_objet(o)
			return "Vous ramassez : %s." % o.nom
		"pupitre":
			return "Sur le pupitre, un vieux livre. " + lire_livre(joueur, etage)
		"ratelier":
			var arme = GenerationObjets.generer_objet("arme", clampi(etage, 1, 6))
			var equipe = joueur.recevoir_objet(arme)
			return "Dans le râtelier : %s%s." % [arme.nom, " (équipé)" if equipe else ""]
		"coffre_gardien":
			var type_degats := String(p.get("type_degats", "tranchant"))
			var armure = GenerationObjets.generer_anti_boss(type_degats, clampi(etage, 1, 6))
			var porte = joueur.recevoir_objet(armure)
			return "Dans un vieux coffre : %s%s. Elle protège des dégâts %s du boss de l'étage." % [
				armure.nom, " (équipé)" if porte else "", NOMS_DEGATS_ANTI_BOSS.get(type_degats, type_degats)]
		"coffre_confisque":
			for objet in p.get("objets", []):
				joueur.recevoir_objet(objet)
			joueur.piece_or += int(p.get("or", 0))
			var n: int = p.get("objets", []).size()
			p["objets"] = []
			return "Vos affaires ! Vous récupérez %d objet(s) et %d pièces d'or." % [n, int(p.get("or", 0))]
		"cachette":
			Statistiques.noter(joueur, "secrets_trouves")
			match p.get("contenu", "or"):
				"cle":
					joueur._d["cles"] = int(U.ga(joueur, "cles", 0)) + 1
					return "Une pierre descellée... derrière, une clé rouillée ! (clés : %d)" % joueur.cles
				"livre":
					return "Un livre caché dans une niche. " + lire_livre(joueur, etage)
				"objet":
					var trouve = GenerationObjets.generer_objet(null, clampi(etage + 1, 1, 6))
					var equipe = joueur.recevoir_objet(trouve)
					return "Une cache secrète : %s%s !" % [trouve.nom, " (équipé)" if equipe else ""]
				_:
					var gain := Karma.or_gagne(joueur, randi_range(20, 50) * maxi(1, etage))
					joueur.piece_or += gain
					return "Une bourse oubliée dans une fissure : %d pièces d'or." % gain
	return ""


# ---------------------------------------------------------------------------
# Salles verrouillées
# ---------------------------------------------------------------------------

## La salle ``dest`` de l'étage est-elle encore verrouillée ?
static func verrouillee(donjon, dest: String) -> bool:
	var salle: Dictionary = donjon.plan_donjon[int(donjon.salle_actuelle[0])].get(dest, {})
	return salle.get("verrouillee", false)


## Essaie d'ouvrir la salle ``dest`` avec une clé : [ouverte, message].
static func ouvrir_verrou(donjon, dest: String) -> Array:
	var etage := int(donjon.salle_actuelle[0])
	var salle: Dictionary = donjon.plan_donjon[etage].get(dest, {})
	var joueur = donjon.personnage
	if salle.get("cle_boss", false):
		# La salle du boss ne s'ouvre qu'avec sa clé, portée par une élite de l'étage
		if not a_cle_boss(joueur, etage):
			return [false, "La porte de la salle du boss est scellée. Sa clé est portée par une élite de l'étage."]
		joueur._d["cles_boss"].erase(etage)
		salle["verrouillee"] = false
		return [true, "La clé du boss tourne dans la serrure. La porte s'ouvre lentement..."]
	if int(U.ga(joueur, "cles", 0)) <= 0:
		return [false, "Cette porte est verrouillée. Il vous faudrait une clé."]
	joueur._d["cles"] = int(joueur.cles) - 1
	salle["verrouillee"] = false
	return [true, "Vous ouvrez la porte avec une clé (clés restantes : %d)." % joueur.cles]
