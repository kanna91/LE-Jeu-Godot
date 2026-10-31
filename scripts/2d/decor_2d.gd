extends Node2D
## Décor 2D en calques : sprites découpés dans une image de référence, posés à leur place (coordonnées de l'image
## agrandie, voir assets_2d/<décor>/sprites/sprites.json). Ordre d'affichage = ordre des nœuds (un nœud par calque,
## du fond vers l'avant). Un personnage se place entre deux calques (ex. entre « Sol » et « PremierPlan ») ; les
## parties cachées derrière chaque calque ont été reconstituées.
## Scènes générées par C:\IA\pont-blender\decors_2d\scripts\decor2d.py (et entree_ruine\assets_2d\scripts\g_godot.py).

## Taille de l'image d'origine (agrandie x2).
@export var taille_image := Vector2(1536, 1024)
## true : toute l'image est visible (bandes noires si le format diffère) ; false : l'image remplit l'écran (bords rognés).
@export var image_entiere := true
## Animations (vent, flammes, particules). Désactivées, la scène redonne exactement l'image de référence.
@export var anime := true
## Sprites qui ondulent au vent (végétation). Vide : les enfants du nœud « Fougeres » s'il existe.
@export var sprites_vent := PackedStringArray()
## Sprites qui scintillent comme une flamme, avec un halo.
@export var sprites_flamme := PackedStringArray()
## Particules : "pollen" (points dorés dans la lumière), "poussiere" (poussière froide qui tombe lentement), "" (aucune).
@export var particules := "pollen"

const SHADER_VENT := preload("res://scripts/2d/vent_vegetation.gdshader")
const SHADER_FLAMME := preload("res://scripts/2d/flamme.gdshader")


func _ready() -> void:
	get_viewport().size_changed.connect(_cadrer)
	_cadrer()
	if anime:
		_animer()


func _cadrer() -> void:
	var camera: Camera2D = get_node_or_null("Camera2D")
	if camera == null:
		return
	var ecran := get_viewport_rect().size
	var k_l := ecran.x / taille_image.x
	var k_h := ecran.y / taille_image.y
	var k := minf(k_l, k_h) if image_entiere else maxf(k_l, k_h)
	camera.zoom = Vector2(k, k)
	queue_redraw()


func _draw() -> void:
	# bandes noires autour de l'image (dessinées sous tous les sprites)
	draw_rect(Rect2(-taille_image * 2.0, taille_image * 5.0), Color.BLACK)


func _sprite(nom: String) -> Sprite2D:
	return find_child(nom, true, false) as Sprite2D


func _animer() -> void:
	var vent: Array = []
	for nom in sprites_vent:
		vent.append(_sprite(nom))
	if vent.is_empty() and has_node("Fougeres"):
		vent = get_node("Fougeres").get_children()
	var phase := 0.0
	for sprite in vent:
		if sprite is Sprite2D:
			var m := ShaderMaterial.new()
			m.shader = SHADER_VENT
			m.set_shader_parameter("amplitude", 2.5)
			m.set_shader_parameter("phase", phase)
			sprite.material = m
			phase += 1.7
	for nom in sprites_flamme:
		var s := _sprite(nom)
		if s:
			_animer_flamme(s)
	if particules != "":
		_ajouter_particules()


func _animer_flamme(s: Sprite2D) -> void:
	var m := ShaderMaterial.new()
	m.shader = SHADER_FLAMME
	s.material = m
	# halo : lumière chaude additive qui vacille autour de la flamme
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.6, 0.25, 0.55))
	g.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	var halo := Sprite2D.new()
	halo.name = s.name + "_halo"
	halo.texture = tex
	halo.position = s.position + s.texture.get_size() * Vector2(0.5, 0.35)
	var additif := CanvasItemMaterial.new()
	additif.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	halo.material = additif
	s.get_parent().add_child(halo)
	var t := create_tween().set_loops()
	t.tween_property(halo, "modulate:a", 0.55, 0.13)
	t.tween_property(halo, "modulate:a", 0.9, 0.09)
	t.tween_property(halo, "modulate:a", 0.7, 0.17)
	t.tween_property(halo, "modulate:a", 1.0, 0.11)


func _ajouter_particules() -> void:
	var chaud := particules == "pollen"
	var teinte := Color(1.0, 0.95, 0.75) if chaud else Color(0.85, 0.92, 1.0)
	var g := Gradient.new()
	g.set_color(0, Color(teinte, 1.0))
	g.set_color(1, Color(teinte, 0.0))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 16
	tex.height = 16
	var p := CPUParticles2D.new()
	p.name = "Particules"
	p.texture = tex
	p.amount = 70 if chaud else 110
	p.lifetime = 9.0 if chaud else 12.0
	p.preprocess = p.lifetime
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	if chaud:   # zone éclairée de l'entrée en ruine : arcs du centre et de droite, dallage
		p.position = taille_image * Vector2(0.55, 0.5)
		p.emission_rect_extents = taille_image * Vector2(0.4, 0.35)
		p.direction = Vector2(-1, -0.3)
		p.spread = 60.0
		p.gravity = Vector2(0, -2)
		p.initial_velocity_min = 4.0
		p.initial_velocity_max = 12.0
	else:       # poussière : toute l'image, chute lente avec une légère dérive
		p.position = taille_image * Vector2(0.5, 0.45)
		p.emission_rect_extents = taille_image * Vector2(0.5, 0.5)
		p.direction = Vector2(0.3, 1)
		p.spread = 35.0
		p.gravity = Vector2(0, 3)
		p.initial_velocity_min = 6.0
		p.initial_velocity_max = 16.0
	p.scale_amount_min = 0.25
	p.scale_amount_max = 0.6
	var fondu := Gradient.new()
	fondu.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fondu.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0)])
	p.color_ramp = fondu
	var additif := CanvasItemMaterial.new()
	additif.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = additif
	add_child(p)
	# derrière le dernier calque (premier plan)
	var dernier := get_child(get_child_count() - 2)
	if dernier is Camera2D:
		dernier = get_child(get_child_count() - 3)
	move_child(p, dernier.get_index())
