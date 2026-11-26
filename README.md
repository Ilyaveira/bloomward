# Bloomward

Jeu vidéo original de soin et de restauration d'un monde, zone par zone, jouable seul ou à plusieurs en réseau. Développé avec Claude, sous Godot 4.

> **Envie de garder la surprise ?** Contente-toi de ce fichier. Les scripts du dossier `scripts/` (surtout `game.gd`) contiennent la logique de l'énigme.

## État actuel : premier prototype

- une petite clairière à faire revivre ;
- un personnage, caméra derrière lui ;
- une énigme qui se résout **à deux** (chaque joueur voit des choses que l'autre ne voit pas) ;
- la restauration visible de la zone une fois l'énigme résolue ;
- partie solo, ou à deux en réseau local (même box / même Wi-Fi).

Tout le décor est fabriqué par le code (formes simples, couleurs, fins contours) : il n'y a encore ni graphismes définitifs, ni musique, ni sons.

## Lancer le jeu sur ton PC (Windows)

1. **Télécharger Godot 4.5.1** (gratuit, sans installation) : sur la [page de la version 4.5.1](https://github.com/godotengine/godot/releases/tag/4.5.1-stable), prends le fichier `Godot_v4.5.1-stable_win64.exe.zip`. Décompresse-le où tu veux.
   *La version « .NET / mono » n'est pas nécessaire.*
2. **Télécharger le projet** : sur la page GitHub du dépôt, bouton vert **Code → Download ZIP**, puis décompresse le dossier.
3. **Ouvrir le projet** : lance `Godot_v4.5.1-stable_win64.exe`, clique sur **Importer**, choisis le fichier `project.godot` du dossier décompressé, puis **Importer et modifier**. La première ouverture prend quelques secondes.
4. **Jouer** : appuie sur **F5** (ou le bouton ▶ en haut à droite).

### Commandes

| Action | Touche |
|---|---|
| Marcher | ZQSD (clavier AZERTY) ou flèches |
| Regarder autour | souris |
| Sauter | Espace |
| Interagir | E |
| Libérer la souris | Échap (un clic la reprend) |

## Jouer à deux en réseau local

Les deux PC doivent être sur le même réseau (même box ou même Wi-Fi) et avoir chacun Godot et le projet (étapes 1 à 3 ci-dessus).

1. Sur le PC qui **héberge** : F5, puis **Héberger une partie à deux**. L'adresse à communiquer s'affiche en haut à gauche (par exemple `192.168.1.20`).
   La première fois, Windows peut demander d'autoriser Godot sur le réseau : accepte pour les **réseaux privés**.
2. Sur l'autre PC : F5, tape cette adresse dans le champ, puis **Rejoindre**.

Le jeu utilise le port **7777** (UDP). Si la connexion échoue : vérifie l'adresse, que l'hôte a bien lancé la partie, et le pare-feu de l'hôte.

### Tester à deux sur un seul PC

Dans Godot : menu **Debug → Customize Run Instances…** (*Débogage* si l'éditeur est en français), coche **Enable Multiple Instances** et mets **2**. F5 ouvre alors deux fenêtres : héberge dans l'une, rejoins `127.0.0.1` dans l'autre.

## Pour le développement

- Moteur : Godot 4.5.1, GDScript, rendu Forward+.
- Réseau : ENet (API multijoueur haut niveau de Godot). L'hôte fait autorité sur l'état de l'énigme ; chaque joueur ne reçoit que les indices qui lui sont destinés.
- Test automatique de bout en bout (solo, puis hôte + client sur la même machine) : `GODOT=/chemin/vers/godot tools/test_auto.sh`. Il tourne aussi sur GitHub à chaque envoi (`.github/workflows/tests.yml`).

Références : [documentation Godot — multijoueur haut niveau](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html), [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html).
