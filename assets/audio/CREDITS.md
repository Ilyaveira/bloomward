# Crédits du son

## Musique
Composition originale écrite pour Bloomward (partition sous forme de code : `tools/audio/compose.py`). Elle est rendue en deux pistes synchronisées, `musique_base.ogg` et `musique_eclosion.ogg`, que le jeu mélange selon l'état de la zone.

Les instruments sont des échantillons de **VSCO 2: Community Edition** de Versilian Studios (Sam Gossner) : https://versilian-studios.com/vsco-community/, dépôt https://github.com/sgossner/VSCO-2-CE (commit `4403009`), sous licence **CC0 1.0** (fichier `LICENSE` du dépôt). La CC0 n'impose pas de mention ; les auteurs demandent un crédit, le voici.

## Bruitages et ambiances
Tous fabriqués pour le jeu par `tools/audio/sfx.py` :
- synthèse pure (bruit filtré, sinusoïdes) : pas, pierre, vent, feuillage, oiseaux, eau ;
- notes des mêmes instruments VSCO 2 CE : `clic`, `dalle`, `refus`, `accord`, `eclosion`.

## Refaire les fichiers
`pip install numpy scipy soundfile`, récupérer VSCO 2 CE, puis `VSCO=/chemin/VSCO-2-CE python tools/audio/compose.py sortie/` et `python tools/audio/sfx.py sortie/`. Conversion en Ogg Vorbis avec ffmpeg (`-c:a libvorbis -q:a 5`).
