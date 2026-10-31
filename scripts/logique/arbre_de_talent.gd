class_name ArbreDeTalent
extends Dyn
## Talents appris par un personnage.
## La sauvegarde n'enregistre que les identifiants (``talents_ids``) : les talents
## redeviennent ceux du sphérier au chargement.


static func nouvel_arbre() -> ArbreDeTalent:
	var a := ArbreDeTalent.new()
	a._d["talents"] = []
	return a


func ajouter_talent(t) -> void:
	if not (t in _d["talents"]):
		_d["talents"].append(t)


## Bonus cumulés de tous les talents appris.
func bilan() -> Dictionary:
	var total := {}
	for t in _d["talents"]:
		for attribut in t.stats:
			total[attribut] = total.get(attribut, 0) + t.stats[attribut]
	return total


## Déclenche les effets conditionnels des talents pour un événement de combat.
func appliquer_talents(personnage, cible = null, evenement = null, combat = null) -> void:
	personnage.evenement_talent = evenement
	Talents.reagir(personnage, cible, evenement, combat)


## État enregistré : les identifiants des talents (``__getstate__``).
func etat_sauvegarde() -> Dictionary:
	var ids := []
	for t in _d["talents"]:
		ids.append(t.ident)
	return {"talents_ids": ids}


## Restaure l'arbre à partir des identifiants (``__setstate__``).
func restaurer(etat: Dictionary) -> void:
	var talents := []
	var noeuds := Talents.noeuds()
	for i in etat.get("talents_ids", []):
		if noeuds.has(i):
			talents.append(noeuds[i])
	_d = {"talents": talents}
