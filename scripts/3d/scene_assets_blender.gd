extends Node3D
## Racine des scènes 3D générées depuis Blender (ex. scenes/3d/entree_ruine.tscn).
## Les assets exportés portent leur teinte, la variation par bloc et la mousse dans les couleurs de sommet
## (COLOR_0) ; le matériau importé du glTF ne les utilise pas comme albédo : on l'active au chargement
## (une fois par matériau, partagé par toutes les instances).

func _ready() -> void:
	_activer(self)


func _activer(n: Node) -> void:
	if n is MeshInstance3D and n.mesh:
		for i in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(i)
			if m is StandardMaterial3D and not m.vertex_color_use_as_albedo:
				m.vertex_color_use_as_albedo = true
				m.vertex_color_is_srgb = false
	for c in n.get_children():
		_activer(c)
