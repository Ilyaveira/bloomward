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
const WorldScript := preload("res://scripts/world.gd")
const PORT := 7777
const MAX_CLIENTS := 3

var menu: Control
var status_label: Label
var ip_edit: LineEdit
var game: Node3D
var autotest := false
var preview: Node3D
var preview_cam: Camera3D
var _orbit := 0.0


func _ready() -> void:
	_setup_inputs()
	WorldScript.light_mode = _load_setting("mode_leger", false)
	if not "--autotest" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
		_build_preview()
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

	menu.theme = _make_theme()
	# Voile léger à gauche pour la lisibilité du panneau
	var veil := ColorRect.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.98, 0.95, 0.88, 0.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(veil)

	var holder := MarginContainer.new()
	holder.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	holder.add_theme_constant_override("margin_left", 70)
	holder.add_theme_constant_override("margin_top", 60)
	holder.add_theme_constant_override("margin_bottom", 60)
	menu.add_child(holder)
	var center := CenterContainer.new()
	holder.add_child(center)

	var panel := PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.99, 0.96, 0.90, 0.88)
	ps.set_corner_radius_all(22)
	ps.set_content_margin_all(34)
	ps.shadow_color = Color(0.25, 0.18, 0.10, 0.18)
	ps.shadow_size = 18
	ps.border_color = Color(0.82, 0.72, 0.56, 0.6)
	ps.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", ps)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

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
	ip_edit.text = _load_last_ip()
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

	var how := Label.new()
	how.text = "À deux : l'un clique « Héberger » et son adresse s'affiche en grand à l'écran.\nL'autre tape cette adresse dans le champ ci-dessus, puis clique « Rejoindre »."
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.add_theme_font_size_override("font_size", 16)
	how.add_theme_color_override("font_color", Color(0.40, 0.34, 0.28))
	box.add_child(how)

	var light := CheckBox.new()
	light.text = "Mode léger (si le jeu saccade)"
	light.add_theme_font_size_override("font_size", 17)
	light.add_theme_color_override("font_color", Color(0.30, 0.26, 0.22))
	light.add_theme_color_override("font_hover_color", Color(0.20, 0.16, 0.12))
	light.button_pressed = _load_setting("mode_leger", false)
	WorldScript.light_mode = light.button_pressed
	light.toggled.connect(func(on: bool):
		WorldScript.light_mode = on
		_save_setting("mode_leger", on))
	box.add_child(light)

	var quit := _button("Quitter", func(): get_tree().quit())
	box.add_child(quit)

func _make_theme() -> Theme:
	var t := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.36, 0.52, 0.38)
	normal.set_corner_radius_all(14)
	normal.set_content_margin_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.43, 0.61, 0.44)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.29, 0.43, 0.31)
	var focus := normal.duplicate()
	focus.draw_center = false
	focus.border_color = Color(0.96, 0.80, 0.45)
	focus.set_border_width_all(2)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.99, 0.97, 0.92))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_pressed_color", "Button", Color(0.95, 0.92, 0.85))
	var field := StyleBoxFlat.new()
	field.bg_color = Color(1, 0.99, 0.96)
	field.border_color = Color(0.76, 0.66, 0.52)
	field.set_border_width_all(1)
	field.set_corner_radius_all(12)
	field.set_content_margin_all(10)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field)
	t.set_color("font_color", "LineEdit", Color(0.22, 0.18, 0.15))
	for st in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(c, "CheckBox", Color(0.30, 0.26, 0.22))
	return t

## Décor du menu : la clairière vue de loin, caméra en lent travelling circulaire.
func _build_preview() -> void:
	preview = Node3D.new()
	preview.name = "Preview"
	var w := Node3D.new()
	w.set_script(WorldScript)
	preview.add_child(w)
	preview_cam = Camera3D.new()
	preview_cam.fov = 55.0
	preview.add_child(preview_cam)
	add_child(preview)
	preview_cam.current = true

func _process(delta: float) -> void:
	if preview and preview_cam:
		_orbit += delta * 0.03
		var r := 21.0
		preview_cam.position = Vector3(sin(_orbit) * r, 5.5, cos(_orbit) * r)
		preview_cam.look_at(Vector3(0, 1.2, 0))

func _free_preview() -> void:
	if preview:
		preview.queue_free()
		preview = null
		preview_cam = null

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
	_free_preview()
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
	var dargs := OS.get_cmdline_user_args()
	if "--debug-restore" in dargs:
		game.solved = true
		game._apply_restore(1.0)
	var vi := dargs.find("--debug-spot")
	if vi >= 0 and vi + 3 < dargs.size():
		var p: Node3D = game._local_player()
		var x := float(dargs[vi + 1])
		var z := float(dargs[vi + 2])
		p.teleport(Vector3(x, Terrain.height(x, z) + 0.3, z))
		p.cam_yaw = deg_to_rad(float(dargs[vi + 3]))
	var bi := dargs.find("--debug-bloom")
	if bi >= 0 and bi + 1 < dargs.size():
		game._apply_restore(float(dargs[bi + 1]))

func _start_host() -> void:
	if game:
		return
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		status_label.text = "Impossible d'héberger (port %d déjà utilisé ?). Code : %s" % [PORT, error_string(err)]
		return
	multiplayer.multiplayer_peer = peer
	var ips := _local_ips()
	_create_game("Partie hébergée — adresse : %s" % ", ".join(ips), false)
	game.host_banner_text = "En attente de ton partenaire…\nAdresse à lui donner :\n%s" % "\n".join(ips)
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
	_save_last_ip(ip)
	# Garde-fou : sans réponse au bout de 12 s, on abandonne avec un message clair.
	get_tree().create_timer(12.0).timeout.connect(func():
		if game and not game.visible and multiplayer.multiplayer_peer == peer:
			_on_connection_failed())
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
	if not autotest:
		_build_preview()
	menu.visible = true
	status_label.text = msg
	if autotest:
		push_error("AUTOTEST: " + msg)
		get_tree().quit(1)

const SETTINGS_PATH := "user://reglages.cfg"

func _load_setting(key: String, default: Variant) -> Variant:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return cfg.get_value("affichage", key, default)
	return default

func _save_setting(key: String, value: Variant) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("affichage", key, value)
	cfg.save(SETTINGS_PATH)

func _load_last_ip() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return str(cfg.get_value("reseau", "derniere_adresse", "127.0.0.1"))
	return "127.0.0.1"

func _save_last_ip(ip: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("reseau", "derniere_adresse", ip)
	cfg.save(SETTINGS_PATH)

## Adresses IPv4 du réseau local (celles qu'un autre PC de la maison peut joindre).
func _local_ips() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.begins_with("192.168.") or a.begins_with("10.") or (a.begins_with("172.") and a.split(".").size() == 4 and int(a.split(".")[1]) >= 16 and int(a.split(".")[1]) <= 31):
			out.append(a + "  (même réseau)")
		elif a.begins_with("100.") and a.split(".").size() == 4 and int(a.split(".")[1]) >= 64 and int(a.split(".")[1]) <= 127:
			# Plage 100.64.0.0/10 : celle qu'utilise Tailscale pour jouer à distance.
			out.append(a + "  (Tailscale, à distance)")
	if out.is_empty():
		out.append("127.0.0.1 (ce PC uniquement)")
	return out
