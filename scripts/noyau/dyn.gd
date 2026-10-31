class_name Dyn
extends RefCounted
## Objet à attributs dynamiques, comme un objet Python : toute propriété inconnue
## est lue et écrite dans le dictionnaire ``_d`` (``obj.force += 1`` fonctionne).
##
## Tout l'état d'un combattant, d'un objet ou d'une compétence vit dans ``_d`` :
## la sauvegarde (Sauvegarde) n'a qu'à enregistrer ce dictionnaire et le chemin du
## script. Règles pour les classes dérivées : aucune variable membre, et un
## ``_init()`` sans argument ni travail (la construction passe par une fonction
## statique ``nouveau(...)``), pour que ``script.new()`` donne une coquille vide.

var _d := {}


func _get(propriete):
	return _d.get(propriete)


func _set(propriete, valeur) -> bool:
	_d[propriete] = valeur
	return true


## ``getattr(obj, nom, defaut)`` de Python.
func lire(nom: String, defaut = null):
	return _d.get(nom, defaut)


## ``hasattr(obj, nom)`` de Python.
func possede(nom: String) -> bool:
	return _d.has(nom)


## ``delattr(obj, nom)`` de Python (sans erreur si absent).
func effacer(nom: String) -> void:
	_d.erase(nom)


## Noms des attributs (``vars(obj)`` de Python), dans l'ordre de création.
func attributs() -> Array:
	return _d.keys()


## ``copy.copy(obj)`` : même classe, dictionnaire copié en surface.
func copie_superficielle():
	var autre = get_script().new()
	autre._d = _d.duplicate()
	return autre
