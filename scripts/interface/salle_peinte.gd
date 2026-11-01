class_name SallePeinte
extends Node2D
## Salle en décor peint où l'on marche (moteur du banc d'essai « test_salle », sans son éditeur).
##
## Le héros marche sur le sol de l'image, bute sur les obstacles, passe derrière les éléments de premier
## plan et rapetisse en s'éloignant. Les salles sont décrites par ``donnees/salles_peintes/<id>.json``
## (copiées de test_salle par ``outils/importer_salles.py``) ; coordonnées en pixels de l'image de fond.
## Quand le héros entre dans une sortie en marchant, ``sortie_atteinte(index)`` est émis ; c'est l'écran
## d'exploration qui décide où elle mène (plan du donjon) et appelle ``charger`` pour la salle suivante.
##
## Décor animé : la vidéo de la salle (``decor_video``, Theora 1088×720 en boucle, importée par
## ``outils/importer_salles.py``), lue par un VideoStreamPlayer caché dont la texture remplace l'image
## fixe dès la première image décodée (avant : 145 à 666 JPG compressés en DXT1, trop dégradés).
##
## Portes qui s'ouvrent (``portes_animees`` du .json) : une porte fermée s'ouvre seulement quand le
## joueur marche vers elle pour la franchir (son pas suivant entrerait dans la sortie de la porte) ;
## images transparentes posées sur la vidéo, à l'endroit de la porte. Tant qu'elle est fermée,
## sa sortie l'arrête comme un mur ; dès qu'elle commence à s'ouvrir, on peut passer sans attendre la fin ; passer à côté ou arriver près d'elle ne l'ouvre pas. Une porte ouverte le reste tant qu'on est dans la salle
## (``portes_ouvertes``) ; une porte condamnée (``definir_portes``) ne s'ouvre pas.
##
## Objets à fouiller (squelettes : ``Fouille``, images de ``images/objets_salles``), donnés
## à ``charger`` : chacun est posé sur son emplacement (``donnees/objets_salles.json``), mis à l'échelle de la
## perspective (``TAILLES`` × la hauteur du héros à cette profondeur), trié avec le héros par sa base, avec
## une ombre au sol et une emprise qui l'arrête. ``objet_proche`` : objet à portée de fouille.
## (Coffres et étagères, accrochées au mur, retirés le 2026-10-20 : ils juraient avec le décor.)

signal sortie_atteinte(index: int)

const DIRECTIONS := ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
const NOMBRE_IMAGES := 8
const IMAGES_RESPIRATION := 12
const MS_PAR_IMAGE := 70
const MS_PAR_IMAGE_MARCHE := 115
## Marche : fraction de la vitesse de course (« vitesse » de la salle).
const VITESSE_MARCHE := 0.45
## Mesures du héros dans ses images de 448 px : hauteur du corps et ligne des pieds.
const HAUTEUR_PERSO := 428.0
const PIEDS_PERSO := 442.0
const RESPIRATION_CALME := 3.6
const RESPIRATION_ESSOUFFLE := 1.1
const MONTEE_ESSOUFFLEMENT := 0.25
const DESCENTE_ESSOUFFLEMENT := 0.12
const DUREE_FONDU := 0.35
const ZONE_MORTE_STICK := 0.25
## Stick incliné au-delà : course (sinon marche).
const SEUIL_COURSE_STICK := 0.85
## Vitesse des portes : × les images par seconde de leur animation (24 : 97 images = 4 s ; × 1,5 = 2,7 s).
const VITESSE_PORTES := 1.5
## Le joueur pousse une porte quand, en marchant vers elle, la zone de sa sortie est à moins de
## PORTEE_POUSSEE hauteur du héros devant ses pieds (≈ 13 px au fond d'une salle).
const PORTEE_POUSSEE := 0.15

## Déplacements autorisés (faux pendant un fondu, un message, un sous-écran...).
var actif := true
## Course (vrai) ou marche, basculée par Maj.
var course := false
## Pilotage par le testeur automatique (``tests/testeur_etage.gd``) : si ``pilote_actif``, ``pilote`` remplace les
## touches et la manette (direction de l'image, longueur ≤ 1 ; au-delà de SEUIL_COURSE_STICK, c'est de la course).
var pilote_actif := false
var pilote := Vector2.ZERO
var ident := ""
## Salle affichée en miroir (gauche et droite échangées : image, zones, directions des sorties).
var miroir := false
var donnees: Dictionary = {}

var fond: Texture2D
var monde: Node2D
var tri: Node2D
var heros: Sprite2D
var sprite_fond: Sprite2D
var voile: ColorRect
var lecteur_son: AudioStreamPlayer
var avant_plans: Array = []
## Lecteur du décor animé (caché : on dessine sa texture dans sprite_fond).
var lecteur_video: VideoStreamPlayer
## Vrai quand la vidéo a remplacé l'image fixe.
var decor_pret := false
var direction := "up"
var image := 0
var temps := 0.0
var essoufflement := 0.0
var phase_souffle := 0.0
var en_mouvement := false
## Pacte « Voile » de la succube pour cet étage : le héros reste caché dans l'ombre même en marchant (pas en courant),
## et les ennemis voient deux fois moins loin (``PresencesSalle._percoit``). Réglé par l'écran d'exploration.
var pacte_voile := false
## Index de la sortie où se trouve le héros (-1 : aucune) : une sortie ne se déclenche qu'en y entrant.
var sortie_actuelle := -1
## Sorties fermées comme un mur (``murer``) : indices dans « sorties ».
var sorties_murees: Array = []
## Sorties qui ne mènent nulle part (porte ou passage condamnés, ``definir_portes``) : pas de lueur.
var sorties_condamnees: Array = []
## Lueur des sorties praticables (``_creer_lueurs``).
var lueurs: Node2D
var masque_piliers: Texture2D = null
## Même masque, lisible pixel par pixel (le héros est-il caché derrière un pilier ?).
var masque_image: Image = null
var piliers: Array = []
## Présences de la salle (ennemis qui rôdent, personnages, objets : PresencesSalle, donjon d'aventure).
var presences: PresencesSalle
## Image du décor, lisible pixel par pixel (zones sombres où l'on se cache), et seuil de l'ombre de la salle :
## luminosité sous laquelle se trouve la part PART_OMBRE du sol (calculé au chargement).
var image_fond: Image = null
var seuil_ombre := 0.0
const PART_OMBRE := 0.25
## Portes animées de la salle : {spec, sprite, etat ("fermee", "ouverture", "ouverte"), temps,
## images (Image, chargées par un fil de calcul), tache, pretes, condamnee}.
var portes: Array = []
## Chargements d'images de portes encore en cours d'une salle quittée (libérés quand ils finissent).
var _taches_orphelines: Array = []
## Objets posés dans la salle (Fouille.a_afficher : emplacement, type, image, fouillé) et leurs nœuds.
var objets: Array = []
var noeuds_objets: Array = []
## Teinte des objets (leurs images sont plus claires que les décors peints), plus sombre une fois fouillés.
const TEINTE_OBJETS := Color(0.62, 0.67, 0.72)
const TEINTE_FOUILLE := Color(0.42, 0.45, 0.5)
const OMBRE_OBJETS := 0.42
## Hauteur de chaque type d'objet, en hauteurs du héros à la même profondeur.
## Emprise au sol : [demi-largeur, demi-profondeur] en parts de la largeur affichée.
const TAILLES := {"squelette": 0.5}
const EMPRISES := {"squelette": [0.4, 0.1]}
## Portée de la fouille : distance au pied de l'objet, en hauteurs du héros.
const PORTEE_FOUILLE := 0.55

static var images_heros := {}
static var cache_textures := {}


# ---------------------------------------------------------------------------
# Chargement
# ---------------------------------------------------------------------------

## Dans l'éditeur : chemin dans le dossier du projet. Dans le jeu exporté : chemin à côté du .exe.
## Les dossiers lus ainsi (images/salles_peintes, images/objets_salles) ont un .gdignore : Godot ne les
## met pas dans le .pck, ils sont copiés à côté du .exe par exporter_windows.bat.
static func chemin(relatif: String) -> String:
	if OS.has_feature("editor"):
		return ProjectSettings.globalize_path("res://" + relatif)
	return OS.get_executable_path().get_base_dir().path_join(relatif)


static func lire_salle(id: String) -> Dictionary:
	var f := FileAccess.open("res://donnees/salles_peintes/%s.json" % id, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


## Salles disponibles (identifiants des .json importés).
static func salles_disponibles() -> Array:
	var liste := []
	for f in DirAccess.get_files_at("res://donnees/salles_peintes"):
		if f.get_extension() == "json":
			liste.append(f.get_basename())
	liste.sort()
	return liste


static func texture(fichier: String) -> Texture2D:
	if cache_textures.has(fichier):
		return cache_textures[fichier]
	var img := Image.load_from_file(fichier)
	if img == null or img.is_empty():
		push_error("Image manquante : " + fichier)
		return null
	var tex := ImageTexture.create_from_image(img)
	cache_textures[fichier] = tex
	return tex


static func _charger_heros() -> void:
	if not images_heros.is_empty():
		return
	for genre in ["marche", "course", "respiration"]:
		images_heros[genre] = {}
		for d in DIRECTIONS:
			var liste := []
			var nombre := IMAGES_RESPIRATION if genre == "respiration" else NOMBRE_IMAGES
			var prefixe: String = {"marche": "walk", "course": "run", "respiration": "idle"}[genre]
			for i in nombre:
				liste.append(texture(chemin("images/salles_peintes/heros/%s/%s/%s_%s_%d.png" % [genre, d, prefixe, d, i])))
			images_heros[genre][d] = liste


## Affiche la salle ``id`` (en miroir si ``avec_miroir``) ; le héros arrive à la sortie ``arrivee``
## (-1 : position de départ, de dos).
## ``objets_places`` : objets à fouiller de la salle (Fouille.a_afficher).
func charger(id: String, arrivee := -1, avec_miroir := false, objets_places := []) -> void:
	_charger_heros()
	ident = id
	sorties_murees = []
	sorties_condamnees = []
	donnees = lire_salle(id)
	for c in ["marche", "obstacles", "premier_plan", "sorties", "cachettes"]:
		var polys := []
		for poly in donnees.get(c, []):
			var pts := PackedVector2Array()
			for p in poly:
				pts.append(Vector2(p[0], p[1]))
			polys.append(pts)
		donnees[c] = polys
	objets = []
	for o in objets_places:
		var prepare := _preparer_objet(o)
		if prepare.is_empty():
			continue
		objets.append(prepare)
		if prepare.has("emprise"):
			donnees["obstacles"].append(_ellipse(Vector2(prepare["x"], prepare["y"]), prepare["emprise"][0], prepare["emprise"][1]))
	if presences != null:
		presences.entites = []  # leurs nœuds partent avec l'ancien monde ; placer_presences les recrée
	if monde != null:
		monde.queue_free()
	avant_plans.clear()
	fond = texture(chemin(String(donnees["fond"])))
	miroir = avec_miroir
	if miroir:
		_appliquer_miroir(float(fond.get_width()))
	monde = Node2D.new()
	var echelle := float(Ui.HAUTEUR) / fond.get_height()
	monde.scale = Vector2(echelle, echelle)
	monde.position = Vector2((Ui.LARGEUR - fond.get_width() * echelle) / 2, 0)
	add_child(monde)
	move_child(monde, 0)
	sprite_fond = Sprite2D.new()
	sprite_fond.texture = fond
	# Image agrandie par IA (grandes salles : ``fond_hd``) : c'est elle qu'on voit, les zones restent en pixels du fond
	if String(donnees.get("fond_hd", "")) != "" and FileAccess.file_exists(chemin(String(donnees["fond_hd"]))):
		var hd := texture(chemin(String(donnees["fond_hd"])))
		sprite_fond.texture = hd
		sprite_fond.scale = Vector2(fond.get_size()) / Vector2(hd.get_size())
	sprite_fond.centered = false
	sprite_fond.flip_h = miroir
	monde.add_child(sprite_fond)
	tri = Node2D.new()
	tri.y_sort_enabled = true
	monde.add_child(tri)
	heros = Sprite2D.new()
	heros.offset = Vector2(0, -(PIEDS_PERSO - 224))
	tri.add_child(heros)
	var ombre := Node2D.new()
	ombre.show_behind_parent = true
	ombre.draw.connect(func() -> void:
		ombre.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.22))
		for k in 4:
			ombre.draw_circle(Vector2.ZERO, 95.0 - k * 20, Color(0, 0, 0, 0.16)))
	heros.add_child(ombre)
	_charger_masque()
	_creer_objets()
	_creer_portes()
	_creer_lueurs()
	image_fond = Image.load_from_file(chemin(String(donnees["fond"])))
	_calculer_ombre()
	_reconstruire_avant_plans()
	_charger_son()
	_placer(arrivee)
	sortie_actuelle = _sortie_sous(heros.position)
	_lancer_video()
	if voile == null:
		voile = ColorRect.new()
		voile.color = Color.BLACK
		voile.size = Vector2(Ui.LARGEUR, Ui.HAUTEUR)
		voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		voile.modulate.a = 0.0
		add_child(voile)
	move_child(voile, get_child_count() - 1)
	_maj_heros(0.0)


# ---------------------------------------------------------------------------
# Lueur des sorties (2026-10-28, demande de l'utilisateur : « pour guider un peu le joueur »)
# ---------------------------------------------------------------------------

## Couleur, intensité et pulsation de la lueur des sorties praticables (lumière dorée, additive).
const COULEUR_LUEUR := Color(1.0, 0.82, 0.48)
const INTENSITE_LUEUR := 0.75
const PULSATION_LUEUR := 0.25
const PERIODE_LUEUR := 2.6
## Hauteur du rideau de lumière au-dessus du seuil, en hauteurs de héros à cette profondeur.
const HAUTEUR_LUEUR := 1.25


## Calque additif posé sur le décor (sous les personnages et le premier plan) : chaque sortie praticable (ni murée
## ni condamnée) a un rideau de lumière qui monte de son seuil (arche, porte, escalier) et une flaque au sol ; une
## sortie sur le bord de l'image luit le long du bord ; le bas de l'image (retour), plus discrètement.
func _creer_lueurs() -> void:
	lueurs = Node2D.new()
	var materiau := CanvasItemMaterial.new()
	materiau.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lueurs.material = materiau
	lueurs.draw.connect(_dessiner_lueurs)
	monde.add_child(lueurs)
	monde.move_child(lueurs, tri.get_index())


func sortie_praticable(i: int) -> bool:
	return not (i in sorties_murees) and not (i in sorties_condamnees)


func _dessiner_lueurs() -> void:
	var largeur_image := float(fond.get_width())
	var hauteur_image := float(fond.get_height())
	var force := INTENSITE_LUEUR * (1.0 - PULSATION_LUEUR + PULSATION_LUEUR * sin(TAU * temps_lueur / PERIODE_LUEUR))
	var polys: Array = donnees.get("sorties", [])
	for i in polys.size():
		if not sortie_praticable(i):
			continue
		var poly: PackedVector2Array = polys[i]
		if poly.size() < 3:
			continue
		var r := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			r = r.expand(p)
		var h := hauteur(r.end.y)
		var c := COULEUR_LUEUR
		if r.end.y >= hauteur_image - 2 and r.size.x > largeur_image * 0.5:
			# Bas de l'image (retour) : une bande basse, discrète
			_degrade(Rect2(r.position.x, hauteur_image - h * 0.35, r.size.x, h * 0.35), c, force * 0.45, true)
		elif r.position.x <= 1.0 or r.end.x >= largeur_image - 1.0:
			# Passage sur le bord de l'image : la lumière vient du bord
			var gauche := r.position.x <= 1.0
			var l := h * 0.45
			var x0 := 0.0 if gauche else largeur_image - l
			_degrade_lateral(Rect2(x0, r.position.y - h * 0.9, l, r.size.y + h * 0.9), c, force, gauche)
		else:
			# Arche, porte, escalier : rideau de lumière au-dessus du seuil et flaque au sol
			var haut := h * HAUTEUR_LUEUR
			_degrade(Rect2(r.position.x, r.end.y - haut, r.size.x, haut), c, force, true)
			var centre := Vector2(r.get_center().x, r.end.y - r.size.y * 0.35)
			_flaque(centre, Vector2(r.size.x * 0.62, maxf(r.size.y, h * 0.08)), c, force * 0.9)


## Rectangle dont la lumière est forte en bas et nulle en haut, adoucie sur les côtés.
func _degrade(r: Rect2, c: Color, force: float, bas_fort: bool) -> void:
	var bord := r.size.x * 0.22
	var xs := [r.position.x, r.position.x + bord, r.end.x - bord, r.end.x]
	var a_bas := force if bas_fort else 0.0
	var a_haut := 0.0 if bas_fort else force
	for k in 3:
		var cote := k != 1
		var gauche_a := 0.0 if k == 0 else 1.0
		var droite_a := 0.0 if k == 2 else 1.0
		var pts := PackedVector2Array([Vector2(xs[k], r.position.y), Vector2(xs[k + 1], r.position.y),
			Vector2(xs[k + 1], r.end.y), Vector2(xs[k], r.end.y)])
		var cols := PackedColorArray([Color(c, a_haut * gauche_a), Color(c, a_haut * droite_a),
			Color(c, a_bas * droite_a), Color(c, a_bas * gauche_a)])
		if not cote:
			cols = PackedColorArray([Color(c, a_haut), Color(c, a_haut), Color(c, a_bas), Color(c, a_bas)])
		lueurs.draw_polygon(pts, cols)


## Bande verticale dont la lumière est forte contre le bord de l'image.
func _degrade_lateral(r: Rect2, c: Color, force: float, gauche: bool) -> void:
	var a_g := force if gauche else 0.0
	var a_d := 0.0 if gauche else force
	var milieu := r.position.y + r.size.y * 0.35
	lueurs.draw_polygon(PackedVector2Array([Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y),
		Vector2(r.end.x, milieu), Vector2(r.position.x, milieu)]),
		PackedColorArray([Color(c, 0), Color(c, 0), Color(c, a_d), Color(c, a_g)]))
	lueurs.draw_polygon(PackedVector2Array([Vector2(r.position.x, milieu), Vector2(r.end.x, milieu),
		Vector2(r.end.x, r.end.y), Vector2(r.position.x, r.end.y)]),
		PackedColorArray([Color(c, a_g), Color(c, a_d), Color(c, a_d * 0.6), Color(c, a_g * 0.6)]))


## Flaque de lumière au sol (ellipse dégradée).
func _flaque(centre: Vector2, rayons: Vector2, c: Color, force: float) -> void:
	var n := 24
	var pts := PackedVector2Array([centre])
	var cols := PackedColorArray([Color(c, force)])
	for k in n + 1:
		var a := TAU * k / n
		pts.append(centre + Vector2(cos(a) * rayons.x, sin(a) * rayons.y))
		cols.append(Color(c, 0))
	for k in n:
		lueurs.draw_polygon(PackedVector2Array([pts[0], pts[k + 1], pts[k + 2]]),
			PackedColorArray([cols[0], cols[k + 1], cols[k + 2]]))


var temps_lueur := 0.0


## Fondu au noir (``vers`` = 1) ou retour à l'image (0).
func fondu(vers: float) -> void:
	if voile == null:
		return
	var t := create_tween()
	t.tween_property(voile, "modulate:a", vers, DUREE_FONDU)
	await t.finished


## Oublie les images gardées d'un écran à l'autre (à appeler avant de quitter le jeu).
static func liberer() -> void:
	images_heros.clear()
	cache_textures.clear()


func _exit_tree() -> void:
	for porte in portes:
		if porte["tache"] >= 0:
			_taches_orphelines.append(porte["tache"])
	portes = []
	for tache in _taches_orphelines:
		WorkerThreadPool.wait_for_task_completion(tache)
	_taches_orphelines = []
	if lecteur_son != null:
		lecteur_son.stop()
	if lecteur_video != null:
		lecteur_video.stop()


# ---------------------------------------------------------------------------
# Décors animés
# ---------------------------------------------------------------------------

## Lecteur vidéo en boucle du décor ``rel`` (chemin du .json), ou null s'il n'y en a pas.
## À ajouter à l'arbre puis ``play()`` ; sa texture (get_video_texture) se dessine où l'on veut.
static func nouveau_lecteur(rel: String) -> VideoStreamPlayer:
	if rel == "" or not FileAccess.file_exists(chemin(rel)):
		return null
	var flux := VideoStreamTheora.new()
	flux.file = chemin(rel)
	var lecteur := VideoStreamPlayer.new()
	lecteur.stream = flux
	lecteur.loop = true
	lecteur.visible = false  # seule sa texture sert
	return lecteur


## Vrai quand le lecteur a décodé sa première image (avant : texture vide, l'image fixe reste affichée).
static func video_prete(lecteur: VideoStreamPlayer) -> bool:
	if lecteur == null or not lecteur.is_playing() or lecteur.stream_position <= 0.0:
		return false
	var tex := lecteur.get_video_texture()
	return tex != null and tex.get_width() > 0


func _lancer_video() -> void:
	if lecteur_video != null:
		lecteur_video.stop()
		lecteur_video.queue_free()
	decor_pret = false
	lecteur_video = nouveau_lecteur(String(donnees.get("decor_video", "")))
	if lecteur_video == null:
		return
	add_child(lecteur_video)  # lancé par _animer_decor (la salle est souvent chargée avant d'être affichée)


func _animer_decor(_delta: float) -> void:
	if lecteur_video != null and not decor_pret and not lecteur_video.is_playing():
		lecteur_video.play()
	if decor_pret or not video_prete(lecteur_video):
		return
	# Première image décodée : la vidéo remplace l'image fixe (et le premier plan qui en est découpé)
	var tex := lecteur_video.get_video_texture()
	decor_pret = true
	sprite_fond.texture = tex
	sprite_fond.scale = Vector2(fond.get_size()) / Vector2(tex.get_size())
	_reconstruire_avant_plans()


# ---------------------------------------------------------------------------
# Objets posés dans la salle
# ---------------------------------------------------------------------------

## Taille, emprise et hauteur de dessin d'un objet sur son emplacement (coordonnées sans miroir).
func _preparer_objet(o: Dictionary) -> Dictionary:
	var tex := texture(chemin("images/objets_salles/%s.png" % o["objet"]))
	if tex == null:
		return {}
	var p := o.duplicate()
	var y := float(o["y"])
	var heros_ici := hauteur(y)
	var h: float = TAILLES.get(o["type"], 0.4) * heros_ici
	var largeur := h * tex.get_width() / tex.get_height()
	p["x"] = float(o["x"])
	p["y"] = y
	p["hauteur"] = h
	p["largeur"] = largeur
	p["texture"] = tex
	p["bas"] = y
	var e: Array = EMPRISES.get(o["type"], [0.4, 0.1])
	p["emprise"] = [largeur * e[0], largeur * e[1]]
	return p


static func _ellipse(centre: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		pts.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _creer_objets() -> void:
	noeuds_objets = []
	for o in objets:
		var tex: Texture2D = o["texture"]
		var x: float = o["x"]
		if miroir:
			x = fond.get_width() - x
		var tri_y: float = o["y"]
		var bas: float = o["bas"]
		var echelle: float = o["hauteur"] / tex.get_height()
		var retourne: bool = miroir != bool(o.get("retourne", false))
		var noeud := Node2D.new()
		noeud.position = Vector2(x, tri_y)
		var decalage := Vector2(-tex.get_width() / 2.0, (bas - tri_y) / echelle - tex.get_height())
		# Ombre de contact sous l'objet
		var rx: float = o["largeur"] * 0.5
		var ombre := Node2D.new()
		ombre.draw.connect(func() -> void:
			ombre.draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.18))
			for k in 4:
				ombre.draw_circle(Vector2.ZERO, rx * (1.0 - k * 0.18), Color(0, 0, 0, OMBRE_OBJETS / 4.0)))
		noeud.add_child(ombre)
		var sprite := Sprite2D.new()
		sprite.name = "image"
		sprite.texture = tex
		sprite.centered = false
		sprite.flip_h = retourne
		sprite.scale = Vector2(echelle, echelle)
		sprite.offset = decalage
		sprite.modulate = TEINTE_FOUILLE if o.get("fouille", false) else TEINTE_OBJETS
		noeud.add_child(sprite)
		tri.add_child(noeud)
		noeuds_objets.append(noeud)


## Point d'un objet où se tenir pour le fouiller (pied de l'objet, côté salle ; miroir appliqué).
func pied_objet(i: int) -> Vector2:
	var o: Dictionary = objets[i]
	var x: float = o["x"]
	if miroir:
		x = fond.get_width() - x
	return Vector2(x, o["y"] + (o["emprise"][1] if o.has("emprise") else 0.0))


## Objet non fouillé à portée du héros (-1 : aucun) : le plus proche de ses pieds.
func objet_proche() -> int:
	var meilleur := -1
	var distance := INF
	for i in objets.size():
		var o: Dictionary = objets[i]
		if o.get("fouille", false):
			continue
		var pied := pied_objet(i)
		var portee: float = hauteur(pied.y) * PORTEE_FOUILLE + o["largeur"] * 0.35
		var d := heros.position.distance_to(pied)
		if d < portee and d < distance:
			meilleur = i
			distance = d
	return meilleur


## L'objet ``i`` a été fouillé : il s'assombrit et n'est plus proposé.
func marquer_fouille(i: int) -> void:
	objets[i]["fouille"] = true
	var image := noeuds_objets[i].get_node_or_null("image") as Sprite2D
	if image != null:
		image.modulate = TEINTE_FOUILLE


## Haut d'un objet à l'écran (pour y afficher « Fouiller (E) »).
func haut_objet_ecran(i: int) -> Vector2:
	var o: Dictionary = objets[i]
	var x: float = o["x"]
	if miroir:
		x = fond.get_width() - x
	return vers_ecran(Vector2(x, o["bas"] - o["hauteur"]))


# ---------------------------------------------------------------------------
# Portes qui s'ouvrent
# ---------------------------------------------------------------------------

## Crée les portes animées de la salle (fermées) et lance le chargement de leurs images en arrière-plan.
func _creer_portes() -> void:
	for porte in portes:
		if porte["tache"] >= 0:
			_taches_orphelines.append(porte["tache"])
	portes = []
	for spec in donnees.get("portes_animees", []):
		var sprite := Sprite2D.new()
		sprite.centered = false
		sprite.flip_h = miroir
		sprite.visible = false
		monde.add_child(sprite)
		monde.move_child(sprite, sprite_fond.get_index() + 1)  # sur le décor, sous le héros et le premier plan
		var images := []
		var nombre := int(spec["nombre"])
		var modele := chemin(String(spec["images"]))
		var tache := WorkerThreadPool.add_task(func() -> void:
			for k in nombre:
				images.append(Image.load_from_file(modele % k)))
		portes.append({"spec": spec, "sprite": sprite, "etat": "fermee", "temps": 0.0, "images": images,
			"tache": tache, "pretes": false, "condamnee": false})


## Portes ouvertes dès l'arrivée (``ouvertes`` : indices de sorties, dont celle par où l'on arrive) et
## portes condamnées (``condamnees`` : sorties qui ne mènent nulle part, elles ne s'ouvrent pas).
func definir_portes(ouvertes: Array, condamnees: Array) -> void:
	sorties_condamnees = condamnees.duplicate()
	for porte in portes:
		var i := int(porte["spec"]["sortie"])
		porte["condamnee"] = i in condamnees
		if i in ouvertes and not porte["condamnee"]:
			porte["etat"] = "ouverte"
			var derniere := Image.load_from_file(chemin(String(porte["spec"]["images"])) % (int(porte["spec"]["nombre"]) - 1))
			_afficher_image_porte(porte, ImageTexture.create_from_image(derniere))


## Indices des sorties dont la porte est ouverte (ou en train de s'ouvrir).
func portes_ouvertes() -> Array:
	var liste := []
	for porte in portes:
		if porte["etat"] != "fermee":
			liste.append(int(porte["spec"]["sortie"]))
	return liste

## Vrai si la sortie ``i`` a une porte animée encore fermée (elle arrête le héros ; une porte qui s'ouvre laisse passer).
## Vrai si la sortie ``i`` a une porte animée qui n'est pas encore ouverte (elle arrête le héros).
func porte_fermee(i: int) -> bool:
	for porte in portes:
		if int(porte["spec"]["sortie"]) == i:
			return porte["etat"] == "fermee" and not porte["condamnee"]
	return false


func _afficher_image_porte(porte: Dictionary, tex: Texture2D) -> void:
	var spec: Dictionary = porte["spec"]
	var sprite: Sprite2D = porte["sprite"]
	var x := float(spec["x"])
	if miroir:
		x = fond.get_width() - x - float(spec["w"])
	sprite.texture = tex
	sprite.position = Vector2(x, float(spec["y"]))
	sprite.scale = Vector2(float(spec["w"]) / tex.get_width(), float(spec["h"]) / tex.get_height())
	sprite.visible = true


## Le héros marche de ``p`` vers ``p + v`` : si ce pas entre dans la sortie d'une porte fermée (et va
## vers elle), le joueur veut la franchir : elle commence à s'ouvrir.
func _pousser_porte(p: Vector2, v: Vector2) -> void:
	for porte in portes:
		if porte["etat"] != "fermee" or porte["condamnee"]:
			continue
		var i := int(porte["spec"]["sortie"])
		var poly: PackedVector2Array = donnees["sorties"][i]
		if v.dot(centre_sortie(i) - p) <= 0:
			continue
		# Le pas, allongé de PORTEE_POUSSEE hauteur du héros (le bord du sol arrête souvent ses pieds
		# quelques pixels avant la zone de sortie), touche la sortie de la porte : on teste tout le segment.
		var bout := v.normalized() * maxf(v.length(), hauteur(p.y) * PORTEE_POUSSEE)
		for k in range(1, 13):
			if Geometry2D.is_point_in_polygon(p + bout * (k / 12.0), poly):
				porte["etat"] = "ouverture"
				porte["temps"] = 0.0
				break


## Fait avancer l'animation des portes qui s'ouvrent.
func _animer_portes(delta: float) -> void:
	for tache in _taches_orphelines.duplicate():
		if WorkerThreadPool.is_task_completed(tache):
			WorkerThreadPool.wait_for_task_completion(tache)
			_taches_orphelines.erase(tache)
	for porte in portes:
		if porte["tache"] >= 0 and WorkerThreadPool.is_task_completed(porte["tache"]):
			WorkerThreadPool.wait_for_task_completion(porte["tache"])
			porte["tache"] = -1
			porte["pretes"] = true
		if porte["etat"] != "ouverture" or not porte["pretes"]:
			continue
		var spec: Dictionary = porte["spec"]
		var nombre := int(spec["nombre"])
		porte["temps"] += delta
		var k := mini(nombre - 1, int(porte["temps"] * float(spec["ips"]) * VITESSE_PORTES))
		var img: Image = porte["images"][k]
		if img != null and not img.is_empty():
			_afficher_image_porte(porte, ImageTexture.create_from_image(img))
		if k >= nombre - 1:
			porte["etat"] = "ouverte"
			porte["images"] = []  # seule la dernière image reste (sur le sprite)


func _charger_son() -> void:
	if lecteur_son != null:
		lecteur_son.stop()
		lecteur_son.queue_free()
		lecteur_son = null
	var nom := String(donnees.get("son", ""))
	if nom == "":
		return
	var flux := AudioStreamWAV.load_from_file(chemin(nom))
	if flux == null:
		return
	flux.loop_mode = AudioStreamWAV.LOOP_FORWARD
	flux.loop_end = int(flux.get_length() * flux.mix_rate)
	lecteur_son = AudioStreamPlayer.new()
	lecteur_son.stream = flux
	add_child(lecteur_son)
	lecteur_son.play()


# ---------------------------------------------------------------------------
# Premier plan (éléments qui passent devant le héros)
# ---------------------------------------------------------------------------

const SHADER_MASQUE := """
shader_type canvas_item;
uniform sampler2D masque : filter_nearest;
uniform vec4 couleur;
uniform float feu = 0.0;
void fragment() {
	vec4 m = texture(masque, UV);
	COLOR.a *= m.a * (1.0 - smoothstep(0.2, 0.4, distance(m.rgb, couleur.rgb)));
	if (feu > 0.0) {
		COLOR.a *= smoothstep(feu, feu + 0.15, max(COLOR.r, COLOR.g));
	}
}
"""


func _charger_masque() -> void:
	masque_piliers = null
	masque_image = null
	piliers = []
	var nom_masque := String(donnees.get("masque_piliers", ""))
	var nom_piliers := String(donnees.get("piliers", ""))
	if nom_masque == "" or nom_piliers == "" or not FileAccess.file_exists(chemin(nom_masque)):
		return
	masque_piliers = texture(chemin(nom_masque))
	masque_image = Image.load_from_file(chemin(nom_masque))
	piliers = JSON.parse_string(FileAccess.get_file_as_string(chemin(nom_piliers)))


func _reconstruire_avant_plans() -> void:
	for n in avant_plans:
		n.queue_free()
	avant_plans.clear()
	if masque_piliers != null:
		var shader := Shader.new()
		shader.code = SHADER_MASQUE
		for pilier in piliers:
			var base := float(pilier["base"]["y"])
			var morceau := Sprite2D.new()
			morceau.centered = false
			morceau.texture = sprite_fond.texture
			morceau.scale = sprite_fond.scale
			morceau.position = Vector2(0, base)
			morceau.offset = Vector2(0, -base / sprite_fond.scale.y)
			morceau.flip_h = miroir
			var materiau := ShaderMaterial.new()
			materiau.shader = shader
			materiau.set_shader_parameter("masque", masque_piliers)
			materiau.set_shader_parameter("couleur", Color.html(String(pilier["couleur"])))
			materiau.set_shader_parameter("feu", float(pilier.get("feu", 0.0)))
			morceau.material = materiau
			tri.add_child(morceau)
			avant_plans.append(morceau)
		return
	for poly in donnees["premier_plan"]:
		var base := 0.0
		for p in poly:
			base = maxf(base, p.y)
		var morceau := Polygon2D.new()
		morceau.texture = sprite_fond.texture
		morceau.polygon = poly
		var k := Vector2(sprite_fond.texture.get_size()) / Vector2(fond.get_size())
		var uv := PackedVector2Array()
		for p in poly:
			uv.append((Vector2(fond.get_width() - p.x, p.y) if miroir else p) * k)
		morceau.uv = uv
		morceau.position = Vector2(0, base)
		morceau.offset = Vector2(0, -base)
		tri.add_child(morceau)
		avant_plans.append(morceau)


# ---------------------------------------------------------------------------
# Déplacement
# ---------------------------------------------------------------------------

## Hauteur du héros (pixels de l'image) aux pieds en y : table de perspective interpolée, sinon l'horizon.
func hauteur(y: float) -> float:
	var persp: Dictionary = donnees["perspective"]
	var table: Array = persp.get("table_hauteur", [])
	if not table.is_empty():
		if y <= float(table[0][0]):
			return float(table[0][1])
		for i in range(1, table.size()):
			if y <= float(table[i][0]):
				var t := inverse_lerp(float(table[i - 1][0]), float(table[i][0]), y)
				return lerpf(float(table[i - 1][1]), float(table[i][1]), t)
		var a: Array = table[-2]
		var b: Array = table[-1]
		return float(b[1]) + (y - float(b[0])) * (float(b[1]) - float(a[1])) / (float(b[0]) - float(a[0]))
	return maxf(8.0, (y - float(persp["y_horizon"])) * float(persp["hauteur_par_pixel"]))


func _dans(p: Vector2, couche: String) -> bool:
	for poly in donnees[couche]:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func libre(p: Vector2) -> bool:
	var r := hauteur(p.y) * 0.1
	for d in [Vector2.ZERO, Vector2(-r, 0), Vector2(r, 0), Vector2(0, -r * 0.3)]:
		var q: Vector2 = p + d
		if not _dans(q, "marche") or _dans(q, "obstacles"):
			return false
		for i in sorties_murees:
			if Geometry2D.is_point_in_polygon(q, donnees["sorties"][i]):
				return false
		for porte in portes:
			if porte["etat"] == "fermee" and not porte["condamnee"] 					and Geometry2D.is_point_in_polygon(q, donnees["sorties"][int(porte["spec"]["sortie"])]):
				return false
	return true


## Ferme les sorties ``indices`` comme un mur (le bas de l'image quand aucune salle n'est derrière) :
## le héros s'arrête devant, sans message.
func murer(indices: Array) -> void:
	sorties_murees = indices
	sortie_actuelle = _sortie_sous(heros.position) if heros != null else -1


func _sortie_sous(p: Vector2) -> int:
	var polys: Array = donnees["sorties"]
	for i in polys.size():
		if i in sorties_murees:
			continue
		if Geometry2D.is_point_in_polygon(p, polys[i]):
			return i
	return -1


## Nombre de sorties et direction de chacune (« devant », « gauche », « droite », « bas »).
func directions_sorties() -> Array:
	return donnees.get("directions_sorties", [])


func nom_sortie(i: int) -> String:
	var noms: Array = donnees.get("noms_sorties", [])
	return String(noms[i]) if i >= 0 and i < noms.size() else String(donnees.get("nom_sortie", "porte"))


## Centre d'une sortie (pixels de l'image) : pour l'affichage d'une étiquette.
func centre_sortie(i: int) -> Vector2:
	var poly: PackedVector2Array = donnees["sorties"][i]
	var c := Vector2.ZERO
	for p in poly:
		c += p
	return c / poly.size()


## Point de l'image → point de l'écran (960 × 540).
func vers_ecran(p: Vector2) -> Vector2:
	return monde.position + p * monde.scale


## Place le héros : à la sortie ``arrivee`` (tourné vers l'intérieur), sinon à la position de départ.
func _placer(arrivee: int) -> void:
	var dirs := directions_sorties()
	var depart: Array = donnees["depart"]
	var p := Vector2(depart[0], depart[1])
	direction = "up"
	if arrivee >= 0 and arrivee < donnees["sorties"].size():
		var bas: bool = arrivee < dirs.size() and dirs[arrivee] == "bas"
		if bas and p.y >= 440:
			pass  # départ habituel, au bas de l'image
		elif arrivee == 0 and donnees.has("arrivee_porte"):
			var a: Array = donnees["arrivee_porte"]
			p = Vector2(a[0], a[1])
		elif donnees.get("arrivees", {}).has(nom_sortie(arrivee)):
			# Point d'arrivée choisi dans test_salle (portes de côté, recoins)
			var a: Array = donnees["arrivees"][nom_sortie(arrivee)]
			p = Vector2(a[0], a[1])
		else:
			p = _point_d_arrivee(arrivee)
		# Tourné vers l'intérieur de la salle
		var rel: String = dirs[arrivee] if arrivee < dirs.size() else "devant"
		direction = {"bas": "up", "gauche": "down_right", "droite": "down_left"}.get(rel, "down")
	heros.position = sur_le_sol(p)


## Retour dans une salle (2026-11-02) : le héros réapparaît là où il avait franchi la sortie ``i`` pour en partir
## (``p``, pixels de l'image), avancé juste assez vers l'intérieur pour ne plus être dans la sortie.
func placer_au_retour(p: Vector2, i: int) -> void:
	var but := point_entree(i)
	var q := p
	var pas := (but - p).normalized() * 4.0
	for _k in 120:
		if libre(q) and _sortie_sous(q) < 0:
			break
		if q.distance_to(but) <= 4.0:
			q = but
			break
		q += pas
	heros.position = q if libre(q) else but
	sortie_actuelle = _sortie_sous(heros.position)


## Miroir des données de la salle : abscisses x → largeur − x, gauche et droite des sorties échangées.
func _appliquer_miroir(largeur: float) -> void:
	for c in ["marche", "obstacles", "premier_plan", "sorties", "cachettes"]:
		var polys: Array = donnees[c]
		for i in polys.size():
			var poly: PackedVector2Array = polys[i]
			for k in poly.size():
				poly[k] = Vector2(largeur - poly[k].x, poly[k].y)
			polys[i] = poly
	for cle in ["depart", "arrivee_porte"]:
		if donnees.has(cle):
			donnees[cle] = [largeur - float(donnees[cle][0]), donnees[cle][1]]
	var arrivees: Dictionary = donnees.get("arrivees", {})
	for nom in arrivees:
		var a: Array = arrivees[nom].duplicate()
		a[0] = largeur - float(a[0])
		arrivees[nom] = a
	var dirs: Array = donnees.get("directions_sorties", []).duplicate()
	for i in dirs.size():
		dirs[i] = {"gauche": "droite", "droite": "gauche"}.get(dirs[i], dirs[i])
	donnees["directions_sorties"] = dirs


## Point libre juste à l'intérieur de la salle, devant la sortie ``i`` (vers le haut pour une sortie basse).
## Point où l'on se tient en entrant par la sortie ``i`` (devant elle, sur le sol) : sert aux chasseurs qui entrent.
func point_entree(i: int) -> Vector2:
	if i < 0 or i >= donnees["sorties"].size():
		return _point_d_arrivee(0) if not donnees["sorties"].is_empty() else heros.position
	if donnees.get("arrivees", {}).has(nom_sortie(i)):
		var a: Array = donnees["arrivees"][nom_sortie(i)]
		return sur_le_sol(Vector2(a[0], a[1]))
	return sur_le_sol(_point_d_arrivee(i))


## Point de sol libre le plus proche de ``p`` (``p`` lui-même s'il est libre) : les points d'arrivée relevés à la
## main peuvent tomber juste à côté du sol détouré automatiquement (outils/detourer_sols.py, 2026-10-27).
func sur_le_sol(p: Vector2) -> Vector2:
	if libre(p):
		return p
	for rayon in range(3, 240, 3):
		for k in 24:
			var q := p + Vector2.from_angle(TAU * k / 24.0) * Vector2(rayon, rayon * 0.6)
			if libre(q) and _sortie_sous(q) < 0:
				return q
	return p


func _point_d_arrivee(i: int) -> Vector2:
	var c := centre_sortie(i)
	var vers_haut := c.y > 440.0
	var pas := Vector2(0, -4 if vers_haut else 4)
	var p := c
	for _k in 80:
		p += pas
		if libre(p) and _sortie_sous(p) < 0 and _sortie_sous(p - pas * 3) < 0:
			return p
	var depart: Array = donnees["depart"]
	return Vector2(depart[0], depart[1])


func _direction_demandee() -> Vector2:
	if pilote_actif:  # testeur automatique (tests/testeur_etage.gd) : direction donnée comme un stick
		return pilote.limit_length(1.0)
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_A):
		dir.x -= 1
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		dir.x += 1
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_W):
		dir.y -= 1
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S):
		dir.y += 1
	var stick := Vector2.ZERO
	for appareil in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(appareil, JOY_BUTTON_DPAD_LEFT):
			dir.x -= 1
		if Input.is_joy_button_pressed(appareil, JOY_BUTTON_DPAD_RIGHT):
			dir.x += 1
		if Input.is_joy_button_pressed(appareil, JOY_BUTTON_DPAD_UP):
			dir.y -= 1
		if Input.is_joy_button_pressed(appareil, JOY_BUTTON_DPAD_DOWN):
			dir.y += 1
		stick += Vector2(Input.get_joy_axis(appareil, JOY_AXIS_LEFT_X), Input.get_joy_axis(appareil, JOY_AXIS_LEFT_Y))
	if dir == Vector2.ZERO and stick.length() > ZONE_MORTE_STICK:
		_course_stick = stick.length() > SEUIL_COURSE_STICK
		return stick.normalized()
	_course_stick = false
	return dir.normalized()


var _course_stick := false


func _process(delta: float) -> void:
	if monde == null or images_heros.is_empty():  # images libérées (fermeture du jeu)
		return
	temps_lueur += delta
	if lueurs != null:
		lueurs.queue_redraw()
	var dir := _direction_demandee() if actif else Vector2.ZERO
	en_mouvement = dir != Vector2.ZERO
	var courir := course or _course_stick
	if en_mouvement:
		direction = DIRECTIONS[posmod(roundi(dir.angle() / (PI / 4)), 8)]
		var persp: Dictionary = donnees["perspective"]
		var v := dir * float(persp["vitesse"]) * (1.0 if courir else VITESSE_MARCHE) * hauteur(heros.position.y) * delta
		v.y *= float(persp["compression_profondeur"])
		var p := heros.position
		if actif:
			_pousser_porte(p, v)
		# Glisse le long des obstacles : mouvement entier, sinon horizontal seul, sinon vertical seul
		for essai in [v, Vector2(v.x, 0), Vector2(0, v.y)]:
			if essai != Vector2.ZERO and libre(p + essai):
				heros.position = p + essai
				break
		temps += delta
		var duree_image := (MS_PAR_IMAGE if courir else MS_PAR_IMAGE_MARCHE) / 1000.0
		while temps >= duree_image:
			temps -= duree_image
			image = (image + 1) % NOMBRE_IMAGES
	else:
		image = 0
		temps = 0.0
	_respirer(delta, en_mouvement, courir)
	_maj_heros(delta)
	# Une sortie se déclenche quand le héros y entre en marchant
	var sortie := _sortie_sous(heros.position)
	if sortie != sortie_actuelle:
		sortie_actuelle = sortie
		if sortie >= 0 and en_mouvement and actif:
			sortie_atteinte.emit(sortie)
	_animer_decor(delta)
	_animer_portes(delta)


func _maj_heros(_delta: float) -> void:
	var courir := course or _course_stick
	if en_mouvement:
		heros.texture = images_heros["course" if courir else "marche"][direction][image]
	else:
		heros.texture = images_heros["respiration"][direction][int(phase_souffle * IMAGES_RESPIRATION) % IMAGES_RESPIRATION]
	heros.scale = Vector2.ONE * hauteur(heros.position.y) / HAUTEUR_PERSO


func _respirer(delta: float, bouge: bool, courir: bool) -> void:
	if bouge:
		if courir:
			essoufflement = minf(1.0, essoufflement + MONTEE_ESSOUFFLEMENT * delta)
		else:
			essoufflement = maxf(0.0, essoufflement - DESCENTE_ESSOUFFLEMENT * 0.5 * delta)
		phase_souffle = 0.0
	else:
		essoufflement = maxf(0.0, essoufflement - DESCENTE_ESSOUFFLEMENT * delta)
		phase_souffle = fmod(phase_souffle + delta / lerpf(RESPIRATION_CALME, RESPIRATION_ESSOUFFLE, essoufflement), 1.0)


## Place les présences de la salle (Aventure.presences), après ``charger``.
func placer_presences(liste: Array) -> void:
	if presences == null:
		presences = PresencesSalle.new(self)
		add_child(presences)
	presences.placer(liste)


## Le point du sol ``p`` est caché par le premier plan : le corps (à mi-hauteur) est derrière un pilier.
func point_cache(p: Vector2) -> bool:
	if fond == null:
		return false
	var q := p - Vector2(0, hauteur(p.y) * 0.45)
	if masque_image != null:
		var x := q.x if not miroir else fond.get_width() - q.x
		var mx := int(x * masque_image.get_width() / float(fond.get_width()))
		var my := int(q.y * masque_image.get_height() / float(fond.get_height()))
		if mx < 0 or my < 0 or mx >= masque_image.get_width() or my >= masque_image.get_height():
			return false
		var c := masque_image.get_pixel(mx, my)
		if c.a < 0.5:
			return false
		for pilier in piliers:
			var couleur := Color.html(String(pilier["couleur"]))
			var ecart := Vector3(c.r - couleur.r, c.g - couleur.g, c.b - couleur.b).length()
			if ecart < 0.3 and p.y < float(pilier["base"]["y"]):
				return true
		return false
	for poly in donnees["premier_plan"]:
		var base := 0.0
		for pt in poly:
			base = maxf(base, pt.y)
		if p.y < base and Geometry2D.is_point_in_polygon(q, poly):
			return true
	return false


## Luminosité (0 à 1) du décor autour du corps d'un personnage dont les pieds sont en ``p``.
func luminosite(p: Vector2) -> float:
	if image_fond == null:
		return 1.0
	var h := hauteur(p.y)
	var total := 0.0
	var n := 0
	for dx in [-0.12, 0.0, 0.12]:
		for dy in [0.2, 0.45, 0.7]:
			var x: float = p.x + dx * h
			var y: float = p.y - dy * h
			if miroir:
				x = fond.get_width() - x
			var ix := clampi(int(x * image_fond.get_width() / float(fond.get_width())), 0, image_fond.get_width() - 1)
			var iy := clampi(int(y * image_fond.get_height() / float(fond.get_height())), 0, image_fond.get_height() - 1)
			total += image_fond.get_pixel(ix, iy).get_luminance()
			n += 1
	return total / n


## Seuil de l'ombre : la part PART_OMBRE la plus sombre du sol libre de la salle.
func _calculer_ombre() -> void:
	var valeurs := []
	var boite := Rect2()
	var premier := true
	for poly in donnees["marche"]:
		for q in poly:
			boite = Rect2(q, Vector2.ZERO) if premier else boite.expand(q)
			premier = false
	var graine := RandomNumberGenerator.new()
	graine.seed = hash(ident)
	for _k in 400:
		var q := Vector2(graine.randf_range(boite.position.x, boite.end.x), graine.randf_range(boite.position.y, boite.end.y))
		if libre(q):
			valeurs.append(luminosite(q))
	valeurs.sort()
	seuil_ombre = valeurs[int(valeurs.size() * PART_OMBRE)] if not valeurs.is_empty() else 0.0


## Le point ``p`` est dans l'ombre (parmi les zones les plus sombres du sol de la salle).
func dans_ombre(p: Vector2) -> bool:
	return luminosite(p) <= seuil_ombre


## Le héros est dans l'ombre.
func heros_dans_ombre() -> bool:
	return heros != null and dans_ombre(heros.position)


## Le point ``p`` est dans une **cachette** (zones « cachettes » tracées avec l'éditeur de zones, 2026-11-01) : le
## héros n'y est ni vu ni entendu (PresencesSalle._percoit), et les ennemis ne l'y poursuivent pas.
func dans_cachette(p: Vector2) -> bool:
	return _dans(p, "cachettes")


func heros_en_cachette() -> bool:
	return heros != null and dans_cachette(heros.position)


## Le héros est caché : dans une cachette, derrière un élément du premier plan, ou immobile dans l'ombre (avec le
## Voile : il peut y marcher, pas y courir).
func heros_cache() -> bool:
	var discret := not en_mouvement or (pacte_voile and not (course or _course_stick))
	return heros != null and (heros_en_cachette() or point_cache(heros.position) or (heros_dans_ombre() and discret))


## Un obstacle (pilier, colonne, objet) coupe la vue entre les points du sol ``a`` et ``b``.
func vue_bouchee(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 4.0) + 1
	for k in range(1, n):
		var q := a.lerp(b, k / float(n))
		# Tout ce qui n'est pas du sol coupe la vue (piliers, rochers, murs) : depuis le sol détouré du 2026-10-27,
		# les piliers sont des creux du sol et plus seulement des « obstacles »
		if _dans(q, "obstacles") or not _dans(q, "marche"):
			return true
	return false


## Recule le héros d'un pas hors de la sortie où il se trouve (porte condamnée, passage refusé).
func reculer_de_la_sortie() -> void:
	if sortie_actuelle < 0:
		return
	var c := centre_sortie(sortie_actuelle)
	var pas := Vector2(0, -4 if c.y > 440.0 else 4)
	for _k in 30:
		if _sortie_sous(heros.position) < 0 and libre(heros.position):
			break
		heros.position += pas
	sortie_actuelle = _sortie_sous(heros.position)
	direction = "up" if c.y > 440.0 else "down"
