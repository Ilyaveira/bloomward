# Bloomward

Jeu vidéo original de soin et de restauration d'un monde, zone par zone, jouable seul ou à plusieurs en réseau. Développé avec Claude, sous Godot 4.

> **Envie de garder la surprise ?** Contente-toi de ce fichier. Les scripts du dossier `scripts/` (surtout `game.gd`) contiennent la logique de l'énigme.

## État actuel : prototype v0.4

- une clairière en relief (place en ruine, source, rivière qui file par une gorge, collines) à faire revivre ;
- des personnages animés (marche, course avec Maj, saut), caméra derrière eux ;
- une énigme qui se résout **à deux** (chaque joueur voit des choses que l'autre ne voit pas) ;
- une restauration en vague depuis la source : herbe, fleurs, feuillage, eau, papillons ;
- rendu 3D stylisé : ombrage en aplats doux, fins contours en post-traitement, ciel et nuages, herbe et arbres animés par le vent ;
- éclairage avancé : lumière qui rebondit sur les surfaces (SDFGI), brume volumétrique où se dessinent les rayons du soleil, reflets dans l'eau, lissage des bords, étalonnage des couleurs, flou de profondeur sur le menu ;
- partie solo, ou à deux en réseau (même réseau, ou à distance via Tailscale) ;
- de la musique qui évolue avec la restauration de la zone, des ambiances et des bruitages, avec deux réglages de volume dans le menu ;
- un « mode léger » dans le menu pour les PC moins puissants (il coupe l'éclairage avancé, les reflets et une partie de l'herbe).

Le terrain, l'eau, le ciel, l'herbe, les arbres et les ruines sont fabriqués par le code. Les personnages, rochers et buissons sont des modèles 3D libres de droits (CC0) de Quaternius : voir [assets/models/CREDITS.md](assets/models/CREDITS.md). La musique (originale) et les bruitages sont décrits dans [assets/audio/CREDITS.md](assets/audio/CREDITS.md).

## Le plus simple : la version Windows prête à lancer

1. Récupère `Bloomward-Windows-v0.4.zip` (fourni dans le fil du projet), décompresse-le, double-clique sur `Bloomward.exe`. Rien à installer.
2. Le fichier n'est pas signé numériquement : Windows peut afficher « Windows a protégé votre ordinateur ». Clique sur **Informations complémentaires**, puis **Exécuter quand même**.
3. La première fois que tu héberges, Windows peut demander d'autoriser Bloomward sur le réseau : accepte pour les **réseaux privés**.

Le menu et l'écran de jeu indiquent ensuite quoi faire (héberger, rejoindre, commandes).

## Lancer depuis le code source (avec Godot)

1. **Télécharger Godot 4.5.1** (gratuit, sans installation) : sur la [page de la version 4.5.1](https://github.com/godotengine/godot/releases/tag/4.5.1-stable), prends `Godot_v4.5.1-stable_win64.exe.zip` (la version « .NET » n'est pas nécessaire).
2. **Télécharger le projet** : sur GitHub, bouton vert **Code → Download ZIP**, puis décompresse.
3. **Ouvrir** : lance Godot, **Importer**, choisis `project.godot`, puis **Importer et modifier**.
4. **Jouer** : **F5**.
5. **Refaire le .exe** : menu **Projet → Exporter… → Windows → Exporter le projet** (Godot propose d'abord de télécharger les « modèles d'export », une seule fois).

### Commandes

| Action | Touche |
|---|---|
| Marcher | ZQSD (clavier AZERTY) ou flèches |
| Courir | Maj (en marchant) |
| Regarder autour | souris |
| Sauter | Espace |
| Interagir | E |
| Libérer la souris | Échap (un clic la reprend) |

## Jouer à deux

### Sur le même réseau (même box ou même Wi-Fi)

1. Sur le PC qui **héberge** : **Héberger une partie à deux**. L'adresse à donner s'affiche en grand (par exemple `192.168.1.20`).
2. Sur l'autre PC : taper cette adresse dans le champ, puis **Rejoindre**. L'adresse est mémorisée pour la fois suivante.

Le jeu utilise le port **7777** (UDP). Si la connexion échoue : vérifier l'adresse, que l'hôte a bien lancé la partie, et le pare-feu de l'hôte.

### À distance (chacun chez soi)

Le jeu ne passe par aucun serveur en ligne : il faut que les deux PC se « voient » comme s'ils étaient sur le même réseau. Le plus simple est [Tailscale](https://tailscale.com/), un réseau privé entre vos appareils (une formule personnelle gratuite existe, voir leur [page tarifs](https://tailscale.com/pricing)) :

1. Installer Tailscale sur les deux PC et s'y connecter (l'hôte partage son appareil avec l'autre personne, ou vous utilisez le même compte).
2. Lancer Bloomward : l'hôte voit alors aussi une adresse en `100.x.x.x` marquée « Tailscale ». C'est celle-là qu'il faut donner.

L'autre solution (ouvrir le port 7777 UDP sur la box de l'hôte) marche aussi, mais elle est plus technique et expose un port sur Internet.

### Tester à deux sur un seul PC

Dans Godot : menu **Debug → Customize Run Instances…** (*Débogage* si l'éditeur est en français), coche **Enable Multiple Instances** et mets **2**. F5 ouvre alors deux fenêtres : héberge dans l'une, rejoins `127.0.0.1` dans l'autre.

## Pour le développement

- Moteur : Godot 4.5.1, GDScript, rendu Forward+.
- Réseau : ENet (API multijoueur haut niveau de Godot). L'hôte fait autorité sur l'état de l'énigme ; chaque joueur ne reçoit que les indices qui lui sont destinés.
- Test automatique de bout en bout (solo, puis hôte + client sur la même machine) : `GODOT=/chemin/vers/godot tools/test_auto.sh`. Il tourne aussi sur GitHub à chaque envoi (`.github/workflows/tests.yml`).

Références : [documentation Godot — multijoueur haut niveau](https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html), [MultiplayerSpawner](https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html), [MultiplayerSynchronizer](https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html).
