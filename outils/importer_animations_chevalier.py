"""Ancien importeur de la marche du Chevalier de la mort : remplacé le 2026-10-27 par ``importer_animations_marche.py``
(même méthode, pour le chevalier et le geôlier). Garde ce nom pour les anciennes notes : il importe le chevalier.

Usage : ``python outils/importer_animations_chevalier.py``.
"""
import sys

import importer_animations_marche

if __name__ == "__main__":
    importer_animations_marche.importer("chevalier")
