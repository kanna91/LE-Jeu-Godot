class_name Animations
extends RefCounted
## Animations procédurales : respiration des sprites et réglages
## des particules de feu (voir CoucheParticules).

const EMISSION_PAR_SECONDE := 14.0
const EMISSION_MIN := 5.0
const EMISSION_MAX := 30.0
const PROPORTION_BRAISES := 0.3
const POUSSEE := 35.0
const FROTTEMENT := 0.9
const COURANT_AIR := 30.0
const PRECHAUFFAGE := 2.5
const PERIODE_RESPIRATION := 3.4
const AMPLITUDE_RESPIRATION := 0.022
const DEGRADE_FEU := [[0.0, Color8(255, 245, 200)], [0.25, Color8(255, 190, 80)], [0.6, Color8(240, 110, 30)], [1.0, Color8(140, 30, 10)]]
const DEGRADE_MAGIE := [[0.0, Color8(220, 245, 255)], [0.25, Color8(120, 210, 255)], [0.6, Color8(60, 130, 255)], [1.0, Color8(20, 40, 150)]]

static var _foyers = null
static var _points := {}


static func temps() -> float:
	return Time.get_ticks_msec() / 1000.0


## Foyers d'une image de fond (détectés par le jeu Python : donnees/foyers.json).
static func foyers(chemin: String) -> Array:
	if _foyers == null:
		_foyers = U.charger_json("foyers.json")
		if _foyers == null:
			_foyers = {}
	return _foyers.get(chemin, [])


## Point lumineux blanc dégradé (cœur net, bord doux), à teinter et dessiner en mode additif.
static func point_lumineux(taille: float) -> Texture2D:
	var cle := roundf(taille * 2) / 2
	if not _points.has(cle):
		var rayon := int(ceil(cle * 2.5)) + 1
		var img := Image.create(2 * rayon, 2 * rayon, false, Image.FORMAT_RGBA8)
		for i in 2 * rayon:
			for j in 2 * rayon:
				var dx := i - rayon + 0.5
				var dy := j - rayon + 0.5
				var d := sqrt(dx * dx + dy * dy)
				var force := clampf(1.2 - d / cle, 0, 1) * 0.85 + exp(-pow(d / (cle * 1.8), 2)) * 0.35
				var v := clampf(force, 0, 1)
				img.set_pixel(i, j, Color(v, v, v, 1))
		_points[cle] = ImageTexture.create_from_image(img)
	return _points[cle]


## Phase de respiration stable propre à un objet (0 à 2π).
static func phase_de(objet) -> float:
	return float(objet.get_instance_id() % 997) / 997 * TAU


## Dessine un sprite qui respire : étiré en hauteur, un peu resserré en largeur, ancré sur ses pieds.
static func dessiner_respirant(ci: CanvasItem, tex: Texture2D, r: Rect2, phase := 0.0, teinte := Color(1, 1, 1, 1)) -> void:
	if tex == null:
		return
	var avancement := fposmod(temps() / PERIODE_RESPIRATION + phase / TAU, 1.0)
	var souffle := 0.5 - 0.5 * cos(TAU * avancement)
	var ey := 1 + AMPLITUDE_RESPIRATION * souffle
	var ex := 1 - AMPLITUDE_RESPIRATION / 3 * souffle
	var l := r.size.x * ex
	var h := r.size.y * ey
	ci.draw_texture_rect(tex, Rect2(r.position.x + (r.size.x - l) / 2, r.end.y - h, l, h), false, teinte)
