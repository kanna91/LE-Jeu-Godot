class_name CoucheParticules
extends Node2D
## Particules de feu qui s'échappent des foyers d'un fond d'écran (animations.py :
## SystemeParticules), dessinées en mélange additif.
##
## Un système par image de fond, conservé : en revenant sur un écran, les
## particules reprennent là où elles en étaient.

## Image de fond dont on anime les foyers (chemin dans images/), vide pour aucune.
var fond := ""

static var _systemes := {}


class Particule:
	var x: float
	var y: float
	var vx: float
	var vy: float
	var age := 0.0
	var duree: float
	var taille: float
	var eclat: float
	var scintille: bool
	var derive: float
	var degrade: Array


class Systeme:
	var sources: Array = []
	var particules: Array = []
	var reliquats: Array = []
	var temps := 0.0
	var dernier_tick := -1

	func _init(foyers: Array) -> void:
		for f in foyers:
			var r := Rect2(f["rect"][0], f["rect"][1], f["rect"][2], f["rect"][3])
			var c: Array = f["couleur"]
			sources.append({"rect": r, "degrade": Animations.DEGRADE_MAGIE if c[2] > c[0] else Animations.DEGRADE_FEU,
				"debit": minf(Animations.EMISSION_MAX, maxf(Animations.EMISSION_MIN, Animations.EMISSION_PAR_SECONDE * r.size.x / 20))})
			reliquats.append(randf())
		for _i in int(Animations.PRECHAUFFAGE * 30):
			avancer(1.0 / 30)

	func _naitre(source: Dictionary) -> Particule:
		var r: Rect2 = source["rect"]
		var p := Particule.new()
		p.x = r.get_center().x + randfn(0, r.size.x * 0.22)
		p.y = r.position.y + r.size.y * randf_range(0.05, 0.45)
		p.scintille = randf() < Animations.PROPORTION_BRAISES
		if p.scintille:
			p.vx = randfn(0, 8)
			p.vy = -randf_range(18, 40)
			p.duree = randf_range(1.6, 3.2)
			p.taille = randf_range(1.8, 2.8)
			p.eclat = randf_range(0.55, 0.85)
		else:
			p.vx = randfn(0, 18)
			p.vy = -randf_range(45, 95)
			p.duree = randf_range(0.7, 1.8)
			p.taille = randf_range(1.0, 1.8)
			p.eclat = randf_range(0.8, 1.0)
		p.derive = randf_range(0, 1000)
		p.degrade = source["degrade"]
		return p

	func avancer(dt: float) -> void:
		temps += dt
		for i in sources.size():
			reliquats[i] += sources[i]["debit"] * dt * randf_range(0.6, 1.4)
			while reliquats[i] >= 1:
				reliquats[i] -= 1
				particules.append(_naitre(sources[i]))
		var vivantes := []
		for p in particules:
			p.age += dt
			if p.age >= p.duree:
				continue
			var vent := sin(temps * 1.7 + p.derive) + 0.5 * sin(temps * 3.9 + 2.3 * p.derive)
			p.vx += vent * Animations.COURANT_AIR * dt
			p.vy -= Animations.POUSSEE * dt
			var amorti := maxf(0.0, 1.0 - Animations.FROTTEMENT * dt)
			p.vx *= amorti
			p.vy *= amorti
			p.x += p.vx * dt
			p.y += p.vy * dt
			vivantes.append(p)
		particules = vivantes

	func mettre_a_jour() -> void:
		var maintenant := Time.get_ticks_msec()
		if dernier_tick < 0:
			dernier_tick = maintenant
			return
		var ecoule := minf((maintenant - dernier_tick) / 1000.0, 0.1)
		dernier_tick = maintenant
		while ecoule > 1e-6:
			var pas := minf(ecoule, 1.0 / 20)
			avancer(pas)
			ecoule -= pas

	static func couleur(p: Particule) -> Color:
		var vie := p.age / p.duree
		var base: Color = p.degrade[-1][1]
		for i in p.degrade.size() - 1:
			var a: float = p.degrade[i][0]
			var b: float = p.degrade[i + 1][0]
			if vie <= b:
				base = p.degrade[i][1].lerp(p.degrade[i + 1][1], (vie - a) / (b - a))
				break
		var force := p.eclat * minf(1.0, vie / 0.08) * pow(1 - vie, 1.3)
		if p.scintille:
			force *= 0.7 + 0.3 * sin(p.age * 23 + p.derive)
		return Color(base.r * force, base.g * force, base.b * force, 1)


func _init() -> void:
	var materiau := CanvasItemMaterial.new()
	materiau.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = materiau


func _draw() -> void:
	if fond == "":
		return
	var systeme = _systemes.get(fond)
	if systeme == null:
		systeme = Systeme.new(Animations.foyers(fond))
		_systemes[fond] = systeme
	if systeme.sources.is_empty():
		return
	systeme.mettre_a_jour()
	for p in systeme.particules:
		var c := Systeme.couleur(p)
		if maxf(c.r, maxf(c.g, c.b)) < 4.0 / 255:
			continue
		var t := Animations.point_lumineux(p.taille)
		draw_texture(t, Vector2(p.x, p.y) - t.get_size() / 2, c)
