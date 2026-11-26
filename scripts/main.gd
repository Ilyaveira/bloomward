extends Node
## Point d'entrée : menu d'accueil et mise en place du réseau (ENet, réseau local).
##
## Options de ligne de commande (après « -- ») utiles pour les tests :
##   --solo            lance directement une partie seule
##   --host            héberge directement une partie
##   --join <ip>       rejoint directement une partie
##   --autotest        joue automatiquement l'énigme (test de bout en bout)
##   --quit-after <s>  quitte au bout de s secondes (garde-fou des tests)
##   --screenshot <fichier.png>  enregistre une capture d'écran après 4 s
##   --debug-restore   affiche directement la zone restaurée (pour les captures)

const GameScript := preload("res://scripts/game.gd")
const PORT := 7777
const MAX_CLIENTS := 3

var menu: Control
var status_label: Label
var ip_edit: LineEdit
var game: Node3D
var autotest := false


func _ready() -> void:
	_setup_inputs()
	_build_menu()
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var args := OS.get_cmdline_user_args()
	autotest = "--autotest" in args
	var qi := args.find("--quit-after")
	if qi >= 0 and qi + 1 < args.size():
		get_tree().create_timer(float(args[qi + 1])).timeout.connect(func():
			print("Délai écoulé, fermeture.")
			get_tree().quit(1))
	var si := args.find("--screenshot")
	if si >= 0 and si + 1 < args.size():
		var path: String = args[si + 1]
		get_tree().create_timer(4.0).timeout.connect(func():
			get_viewport().get_texture().get_image().save_png(path)
			print("Capture enregistrée : ", path)
			get_tree().quit(0))
	if "--solo" in args:
		_start_solo()
	elif "--host" in args:
		_start_host()
	elif "--join" in args:
		var ji := args.find("--join")
		_start_join(args[ji + 1] if ji + 1 < args.size() else "127.0.0.1")


## Commandes définies ici avec des touches « physiques » : ZQSD sur clavier AZERTY,
## WASD sur clavier QWERTY, sans rien changer.
func _setup_inputs() -> void:
	var actions := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE],
		"interact": [KEY_E],
	}
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in actions[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# =====================================================================
#  Menu
# =====================================================================

func _build_menu() -> void:
	menu = Control.new()
	menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(menu)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.96, 0.92, 0.84)
	menu.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu.add_child(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	var title := Label.new()
	title.text = "Bloomward"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.24, 0.42, 0.30))
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Prototype — une clairière à faire revivre"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.40, 0.34, 0.28))
	box.add_child(sub)
	box.add_child(_spacer(18))

	box.add_child(_button("Jouer seul", _start_solo))
	box.add_child(_button("Héberger une partie à deux", _start_host))
	box.add_child(_spacer(6))

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 10)
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "Adresse de l'hôte (ex. 192.168.1.20)"
	ip_edit.text = "127.0.0.1"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ip_edit.custom_minimum_size = Vector2(0, 48)
	ip_edit.add_theme_font_size_override("font_size", 20)
	join_row.add_child(ip_edit)
	var join_btn := _button("Rejoindre", func(): _start_join(ip_edit.text.strip_edges()))
	join_btn.custom_minimum_size = Vector2(150, 48)
	join_row.add_child(join_btn)
	box.add_child(join_row)

	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color(0.55, 0.30, 0.22))
	box.add_child(status_label)

	var quit := _button("Quitter", func(): get_tree().quit())
	box.add_child(quit)

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 52)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(cb)
	return b

func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


# =====================================================================
#  Réseau
# =====================================================================

func _create_game(info: String, solo: bool) -> void:
	game = Node3D.new()
	game.set_script(GameScript)
	game.name = "Game"
	game.autotest = autotest
	game.solo = solo
	game.info_text = info
	add_child(game)
	menu.visible = false

func _start_solo() -> void:
	if game:
		return
	# Pas de connexion : Godot utilise un « pair hors ligne » qui est son propre serveur.
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_create_game("Partie solo", true)
	game.server_begin()
	if "--debug-restore" in OS.get_cmdline_user_args():
		game.solved = true
		game._apply_restore(1.0)

func _start_host() -> void:
	if game:
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status_label.text = "Impossible d'héberger (port %d déjà utilisé ?). Code : %s" % [PORT, error_string(err)]
		return
	multiplayer.multiplayer_peer = peer
	_create_game("Partie hébergée — adresse à donner : %s" % ", ".join(_local_ips()), false)
	game.server_begin()
	print("Serveur prêt sur le port %d. Adresses locales : %s" % [PORT, ", ".join(_local_ips())])

func _start_join(ip: String) -> void:
	if game:
		return
	if ip.is_empty():
		status_label.text = "Indique l'adresse de l'ordinateur qui héberge."
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		status_label.text = "Connexion impossible : %s" % error_string(err)
		return
	status_label.text = "Connexion à %s…" % ip
	# Le décor doit exister AVANT l'arrivée des données du serveur.
	_create_game("Connecté à %s" % ip, false)
	menu.visible = true
	game.visible = false
	multiplayer.multiplayer_peer = peer

func _on_connected() -> void:
	status_label.text = ""
	menu.visible = false
	game.visible = true
	print("Connecté au serveur (identifiant %d)." % multiplayer.get_unique_id())

func _on_connection_failed() -> void:
	_back_to_menu("La connexion a échoué. Vérifie l'adresse, que l'hôte a bien lancé la partie, et le pare-feu.")

func _on_server_disconnected() -> void:
	_back_to_menu("L'hôte a quitté la partie.")

func _back_to_menu(msg: String) -> void:
	multiplayer.multiplayer_peer = null
	if game:
		game.queue_free()
		game = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu.visible = true
	status_label.text = msg
	if autotest:
		push_error("AUTOTEST: " + msg)
		get_tree().quit(1)

## Adresses IPv4 du réseau local (celles qu'un autre PC de la maison peut joindre).
func _local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.split(".").size() == 4 and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			out.append(a)
	if out.is_empty():
		out.append("127.0.0.1 (ce PC uniquement)")
	return out
