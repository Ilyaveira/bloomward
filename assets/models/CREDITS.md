# Crédits des modèles 3D

Tous les modèles du dossier `assets/models/quaternius/` sont de **Quaternius** (https://quaternius.com, https://www.patreon.com/quaternius), placés par l'auteur sous licence **CC0 1.0 Universal** (domaine public, https://creativecommons.org/publicdomain/zero/1.0/). Le texte de licence fourni avec les packs est copié dans `quaternius/License-Quaternius-CC0.txt`. La CC0 n'impose pas de mention ; on la fait quand même.

| Dossier | Pack d'origine (Quaternius) | Fichiers |
|---|---|---|
| `characters/` | Animated Women Characters (fév. 2019), Animated Men Characters (fév. 2019) | Female_Casual, Female_Alternative, Male_Casual, Male_LongSleeve |
| `rocks/` | Rocks, Flowers & Grass Pack (juil. 2016) | Rock1 à Rock8 |
| `bushes/` | Bush Pack (juin 2016) | Bush1, Bush2, MediumBush, SmallBush, SmallBush2, SmallBush3 |

## Provenance et conversion

- Les sites quaternius.com et kenney.nl n'étaient pas joignables depuis l'environnement de développement. Les fichiers sources (.fbx, .blend) ont été pris dans le dépôt public https://github.com/beep2bleep/FreeAssetsByKenneyNLandQuaternius (commit `dea756b`, 2019), qui redistribue les packs gratuits de Quaternius avec leur fichier `License.txt` d'origine.
- Conversion en `.glb` avec Blender (module Python `bpy` 5.2) : import, application des transformations, export glTF binaire avec animations. Les matériaux d'origine sont remplacés dans le jeu par l'ombrage maison (`scripts/style.gd`).
