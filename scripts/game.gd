extends Node3D
## La zone jouable : construction du décor, joueurs, énigme et restauration.
##
## Réseau : le serveur (l'hôte) fait autorité sur l'état de l'énigme.
## Les clients demandent une action, le serveur valide puis diffuse le résultat.
## Chaque joueur ne reçoit QUE les indices qui lui sont destinés : l'information
## est réellement répartie entre les joueurs (pas de partage d'écran).
##
## ATTENTION SURPRISE : ce fichier contient la logique de l'énigme.

const PlayerScript := preload("res://scripts/player.gd")
const WorldScript := preload("res://scripts/world.gd")

const STONE_COUNT := 4
const SYMBOL_COUNT := 4
const STONE_RING := 7.5
const INTERACT_DIST := 2.4
const PAD_RADIUS := 1.2
const PAD_POSITIONS := [Vector3(-3.6, 0.0, 3.6), Vector3(3.6, 0.0, -3.6)]
const WORLD_SEED := 20261126

const SYMBOL_COLORS := [
	Color(0.45, 0.78, 0.38),  # feuille
	Color(0.35, 0.66, 0.95),  # goutte
	Color(1.0, 0.78, 0.25),   # soleil
	Color(0.92, 0.95, 1.0),   # souffle
]
const STONE_BANDS := [
	Color(0.93, 0.45, 0.40),  # corail
	Color(0.30, 0.72, 0.70),  # turquoise
	Color(0.62, 0.48, 0.80),  # violet
	Color(0.95, 0.70, 0.30),  # ambre
]


var autotest := false
var solo := false
var info_text := ""
var host_banner_text := ""

# --- État partagé (copie locale, l'hôte fait foi) ---
var stone_state: Array[int] = [0, 0, 0, 0]
var aligned := false
var solved := false
var my_hints: Dictionary = {}       # index pierre -> symbole visible par MOI
var my_turnable: Dictionary = {}    # index pierre -> true si JE peux la tourner

# --- État serveur uniquement ---
var _solution: Array[int] = []
var _join_order: Array[int] = []
var _pad_last := [false, false]

# --- Décor ---
var players_root: Node3D
var spawner: MultiplayerSpawner
var stones: Array = []          # [{root, emblem_holder, hint_holder}]
var pads: Array = []            # MeshInstance3D
var world: Node3D
var restore_t := 0.0

# --- Interface ---
var hud: CanvasLayer
var prompt_label: Label
var info_label: Label
var message_label: Label
var banner_label: Label
var _message_tween: Tween
var _t := 0.0


func _ready() -> void:
	world = Node3D.new()
	world.set_script(WorldScript)
	world.name = "World"
	add_child(world)
	_build_pads()
	_build_stones()
	_build_hud()

	players_root = Node3D.new()
	players_root.name = "Players"
	add_child(players_root)
	spawner = MultiplayerSpawner.new()
	spawner.name = "Spawner"
	add_child(spawner)
	spawner.spawn_path = spawner.get_path_to(players_root)
	spawner.spawn_function = _spawn_player
	_apply_restore(0.0)


# =====================================================================
#  Réseau : démarrage, arrivées et départs
# =====================================================================

func server_begin() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_solution.clear()
	for i in STONE_COUNT:
		_solution.append(rng.randi_range(0, SYMBOL_COUNT - 1))
	# On évite une solution déjà réalisée au départ.
	for i in STONE_COUNT:
		stone_state[i] = (_solution[i] + 1 + rng.randi_range(0, SYMBOL_COUNT - 2)) % SYMBOL_COUNT
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	_add_player(1)
	_refresh_stones()

func _on_peer_connected(id: int) -> void:
	_add_player(id)
	_sync_state.rpc_id(id, stone_state, aligned, solved)

func _on_peer_disconnected(id: int) -> void:
	_join_order.erase(id)
	var p := players_root.get_node_or_null(str(id))
	if p:
		p.queue_free()
	_assign_roles()
	_show_message.rpc("Un voyageur est reparti.")

func _add_player(id: int) -> void:
	_join_order.append(id)
	var index := _join_order.size() - 1
	var angle := index * 0.9
	var pos := Vector3(sin(angle) * 3.0, 0.0, 16.0 + cos(angle) * 1.5)
	pos.y = Terrain.height(pos.x, pos.z) + 0.4
	spawner.spawn({"id": id, "index": index, "pos": pos})
	_assign_roles()
	if id != 1:
		_show_message.rpc("Un second voyageur vous rejoint.")

func _spawn_player(data: Variant) -> Node:
	var p := CharacterBody3D.new()
	p.set_script(PlayerScript)
	p.setup(data["id"], data["index"], data["pos"])
	p.game = self
	return p

## Répartition des rôles : pour chaque pierre, un joueur VOIT l'indice
## et un AUTRE joueur peut la tourner. Seul, on fait tout.
func _assign_roles() -> void:
	var n := _join_order.size()
	if n == 0:
		return
	for k in n:
		var id := _join_order[k]
		var hints := {}
		var turnable := []
		for i in STONE_COUNT:
			if i % n == k:
				hints[i] = _solution[i]
			if (i + 1) % n == k:
				turnable.append(i)
		if id == 1:
			_receive_roles(hints, turnable)
		else:
			_receive_roles.rpc_id(id, hints, turnable)
	_check_aligned()

@rpc("authority", "call_remote", "reliable")
func _receive_roles(hints: Dictionary, turnable: Array) -> void:
	my_hints = hints
	my_turnable.clear()
	for i in turnable:
		my_turnable[i] = true
	_refresh_hints()
	if autotest:
		_autotest_roles_received()

@rpc("authority", "call_remote", "reliable")
func _sync_state(states: Array, is_aligned: bool, is_solved: bool) -> void:
	for i in STONE_COUNT:
		stone_state[i] = states[i]
	aligned = is_aligned
	_refresh_stones()
	if is_solved and not solved:
		solved = true
		_apply_restore(1.0)


# =====================================================================
#  Énigme
# =====================================================================

## Appelé par le personnage local quand on appuie sur E.
func local_interact(player: Node3D) -> void:
	var idx := _nearest_stone(player.global_position)
	if idx < 0 or solved:
		return
	if not my_turnable.has(idx):
		_show_message("Cette pierre reste sourde à ta main.")
		Son.play("refus", -4.0)
		return
	if multiplayer.is_server():
		_server_turn(idx, multiplayer.get_unique_id())
	else:
		_request_turn.rpc_id(1, idx)

@rpc("any_peer", "call_remote", "reliable")
func _request_turn(idx: int) -> void:
	if multiplayer.is_server():
		_server_turn(idx, multiplayer.get_remote_sender_id())

func _server_turn(idx: int, sender: int) -> void:
	if solved or idx < 0 or idx >= STONE_COUNT:
		return
	# Vérification côté serveur : ce joueur a-t-il le droit de tourner cette pierre ?
	var n := _join_order.size()
	var k := _join_order.find(sender)
	if k < 0 or (idx + 1) % n != k:
		if autotest:
			print("AUTOTEST: demande refusée par l'hôte (pair %d, pierre %d)" % [sender, idx])
		return
	stone_state[idx] = (stone_state[idx] + 1) % SYMBOL_COUNT
	_set_stone.rpc(idx, stone_state[idx])
	_check_aligned()

@rpc("authority", "call_local", "reliable")
func _set_stone(idx: int, symbol: int) -> void:
	stone_state[idx] = symbol
	_refresh_stones()
	var holder: Node3D = stones[idx]["emblem_holder"]
	Son.play_at("pierre", holder.global_position, 2.0, randf_range(0.92, 1.08))
	var tw := create_tween()
	holder.scale = Vector3.ONE * 0.6
	tw.tween_property(holder, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _check_aligned() -> void:
	if not multiplayer.is_server() or _solution.is_empty():
		return
	var ok := true
	for i in STONE_COUNT:
		if stone_state[i] != _solution[i]:
			ok = false
	if ok != aligned:
		_set_aligned.rpc(ok)

@rpc("authority", "call_local", "reliable")
func _set_aligned(value: bool) -> void:
	aligned = value
	if value and not solved:
		Son.play("accord", -3.0)
		_show_message("Les pierres vibrent à l'unisson…")

func _physics_process(delta: float) -> void:
	_t += delta
	_animate_world(delta)
	_update_prompt()
	if multiplayer.multiplayer_peer == null or not multiplayer.is_server() or solved:
		return
	# Le serveur surveille les dalles : il faut autant de dalles occupées
	# que de joueurs (au maximum deux).
	var occupied := [false, false]
	for p in players_root.get_children():
		for j in 2:
			var d := Vector2(p.position.x - PAD_POSITIONS[j].x, p.position.z - PAD_POSITIONS[j].z).length()
			if d < PAD_RADIUS and p.position.y - Terrain.height(PAD_POSITIONS[j].x, PAD_POSITIONS[j].z) < 1.5:
				occupied[j] = true
	if occupied != _pad_last:
		_pad_last = occupied
		_set_pads.rpc(occupied)
	var needed := mini(_join_order.size(), 2)
	var count := int(occupied[0]) + int(occupied[1])
	if aligned and count >= needed:
		_on_solved.rpc()

@rpc("authority", "call_local", "reliable")
func _set_pads(occupied: Array) -> void:
	for j in 2:
		if occupied[j] and not pads[j].get_meta("occupied", false):
			Son.play_at("dalle", pads[j].global_position, 0.0)
		pads[j].set_meta("occupied", occupied[j])

@rpc("authority", "call_local", "reliable")
func _on_solved() -> void:
	if solved:
		return
	solved = true
	Son.play("eclosion", -1.0)
	_show_message("La source s'éveille.", 6.0)
	var tw := create_tween()
	tw.tween_method(_apply_restore, 0.0, 1.0, 9.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(func(): _show_message("La clairière respire à nouveau.\nFin du prototype — merci d'avoir joué !", 8.0))
	if autotest:
		tw.tween_callback(func():
			print("AUTOTEST OK: zone restaurée (pair %d)" % multiplayer.get_unique_id())
			get_tree().create_timer(1.5).timeout.connect(func(): get_tree().quit(0)))

func _nearest_stone(pos: Vector3) -> int:
	var best := -1
	var best_d := INTERACT_DIST
	for i in STONE_COUNT:
		var sp: Vector3 = stones[i]["root"].global_position
		var d := Vector2(pos.x - sp.x, pos.z - sp.z).length()
		if d < best_d:
			best_d = d
			best = i
	return best

func _local_player() -> Node3D:
	if multiplayer.multiplayer_peer == null:
		return null
	return players_root.get_node_or_null(str(multiplayer.get_unique_id()))


# =====================================================================
#  Construction du décor (déterministe : identique chez tous les joueurs)
# =====================================================================

func _build_pads() -> void:
	# Dalles gravées, de part et d'autre de la source
	var slab := Style.toon(Color(0.80, 0.76, 0.68))
	var groove := Style.toon(Color(0.66, 0.62, 0.56))
	for j in 2:
		var p: Vector3 = PAD_POSITIONS[j]
		var pad := Style.mesh_instance(Style.cylinder(PAD_RADIUS, PAD_RADIUS + 0.12, 0.16, 8), slab, p + Vector3(0, Terrain.height(p.x, p.z) + 0.06, 0))
		pad.rotation.y = PI / 8.0
		pad.set_meta("occupied", false)
		var inlay := TorusMesh.new()
		inlay.inner_radius = PAD_RADIUS * 0.58
		inlay.outer_radius = PAD_RADIUS * 0.68
		var engraved := Style.mesh_instance(inlay, groove, Vector3(0, 0.07, 0))
		engraved.scale = Vector3(1, 0.15, 1)
		pad.add_child(engraved)
		var ring := TorusMesh.new()
		ring.inner_radius = PAD_RADIUS * 0.6
		ring.outer_radius = PAD_RADIUS * 0.72
		var glow := Style.mesh_instance(ring, Style.glow(Color(1.0, 0.85, 0.5), 2.2, 0.9), Vector3(0, 0.1, 0))
		glow.name = "Glow"
		pad.add_child(glow)
		add_child(pad)
		pads.append(pad)

func _build_stones() -> void:
	# Monolithes taillés, chacun repérable par sa bande de couleur
	var stone_mat := Style.toon(Color(0.82, 0.78, 0.70))
	var dark := Style.toon(Color(0.66, 0.62, 0.56))
	for i in STONE_COUNT:
		var a := TAU * i / STONE_COUNT + PI / 4.0
		var root := Node3D.new()
		var x := sin(a) * STONE_RING
		var z := cos(a) * STONE_RING
		root.position = Vector3(x, Terrain.height(x, z), z)
		root.rotation.y = a
		root.add_child(Style.mesh_instance(Style.cylinder(1.0, 1.15, 0.25, 8), dark, Vector3(0, 0.08, 0)))
		var body := Style.mesh_instance(Style.cylinder(0.36, 0.55, 2.3, 4), stone_mat, Vector3(0, 1.3, 0))
		body.rotation.y = PI / 4.0
		body.rotation.z = 0.03 * (i - 1.5)
		root.add_child(body)
		root.add_child(Style.mesh_instance(Style.cylinder(0.5, 0.42, 0.22, 4), dark, Vector3(0, 2.52, 0)))
		root.get_child(-1).rotation.y = PI / 4.0
		var band_mat := Style.toon(STONE_BANDS[i])
		band_mat.emission_enabled = true
		band_mat.emission = STONE_BANDS[i]
		band_mat.emission_energy_multiplier = 0.35
		var band := Style.mesh_instance(Style.cylinder(0.53, 0.56, 0.2, 4), band_mat, Vector3(0, 0.55, 0))
		band.rotation.y = PI / 4.0
		root.add_child(band)
		var emblem_holder := Node3D.new()
		emblem_holder.position = Vector3(0, 3.05, 0)
		root.add_child(emblem_holder)
		var hint_holder := Node3D.new()
		hint_holder.position = Vector3(0, 4.2, 0)
		hint_holder.visible = false
		root.add_child(hint_holder)
		add_child(root)
		stones.append({"root": root, "emblem_holder": emblem_holder, "hint_holder": hint_holder})

## Fabrique la forme d'un symbole (forme ET couleur distinctes, pour la lisibilité).
func _make_emblem(symbol: int, ghost: bool) -> Node3D:
	var n := Node3D.new()
	var c: Color = SYMBOL_COLORS[symbol]
	var mat: Material = Style.glow(c, 1.6, 0.55) if ghost else Style.toon(c)
	match symbol:
		0:  # feuille
			var leaf := Style.mesh_instance(Style.sphere(0.32, 12), mat)
			leaf.scale = Vector3(0.7, 1.3, 0.25)
			leaf.rotation.z = 0.5
			n.add_child(leaf)
		1:  # goutte
			n.add_child(Style.mesh_instance(Style.sphere(0.26, 12), mat, Vector3(0, -0.08, 0)))
			n.add_child(Style.mesh_instance(Style.cylinder(0.0, 0.25, 0.4, 12), mat, Vector3(0, 0.22, 0)))
		2:  # soleil
			var t := TorusMesh.new()
			t.inner_radius = 0.2
			t.outer_radius = 0.34
			var ring := Style.mesh_instance(t, mat)
			ring.rotation.x = PI / 2.0
			n.add_child(ring)
			n.add_child(Style.mesh_instance(Style.sphere(0.13, 10), mat))
		3:  # souffle
			for k in 3:
				var arc := TorusMesh.new()
				arc.inner_radius = 0.1 + k * 0.09
				arc.outer_radius = 0.14 + k * 0.09
				var m := Style.mesh_instance(arc, mat, Vector3(0, k * 0.12 - 0.12, 0))
				m.scale = Vector3(1, 0.5, 1)
				n.add_child(m)
	return n

func _refresh_stones() -> void:
	for i in STONE_COUNT:
		var holder: Node3D = stones[i]["emblem_holder"]
		for c in holder.get_children():
			c.queue_free()
		holder.add_child(_make_emblem(stone_state[i], false))

func _refresh_hints() -> void:
	for i in STONE_COUNT:
		var holder: Node3D = stones[i]["hint_holder"]
		for c in holder.get_children():
			c.queue_free()
		holder.visible = my_hints.has(i)
		if my_hints.has(i):
			holder.add_child(_make_emblem(int(my_hints[i]), true))

## Applique l'état de restauration t (0 = flétri, 1 = restauré). Identique chez tous.
func _apply_restore(t: float) -> void:
	restore_t = t
	world.apply_restore(t)
	Son.set_bloom(t)


# =====================================================================
#  Animation et interface
# =====================================================================

func _animate_world(delta: float) -> void:
	for i in stones.size():
		var e: Node3D = stones[i]["emblem_holder"]
		e.rotation.y += delta * 0.8
		var h: Node3D = stones[i]["hint_holder"]
		h.rotation.y -= delta * 0.6
		h.position.y = 4.2 + sin(_t * 1.6 + i) * 0.12
	for pad in pads:
		var g: MeshInstance3D = pad.get_node("Glow")
		var on: bool = aligned and not solved
		g.visible = on
		if on:
			var s := 1.0 + sin(_t * 3.0) * 0.06
			if pad.get_meta("occupied"):
				s = 1.15
			g.scale = Vector3(s, 1, s)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	info_label = Label.new()
	info_label.position = Vector2(20, 16)
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_color", Color(0.18, 0.16, 0.15))
	info_label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.8))
	info_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(info_label)

	prompt_label = _centered_label(26)
	prompt_label.anchor_top = 0.82
	prompt_label.anchor_bottom = 0.82
	hud.add_child(prompt_label)

	message_label = _centered_label(32)
	message_label.anchor_top = 0.11
	message_label.anchor_bottom = 0.11
	message_label.modulate.a = 0.0
	hud.add_child(message_label)

	banner_label = _centered_label(34)
	banner_label.anchor_top = 0.27
	banner_label.anchor_bottom = 0.27
	banner_label.visible = false
	hud.add_child(banner_label)
	get_tree().create_timer(1.2).timeout.connect(func():
		if not solved:
			_show_message("Explore la clairière.\nQuelque chose ici attend d'être réveillé.", 5.0))

	var help := Label.new()
	help.text = "ZQSD / flèches : marcher   ·   Souris : regarder   ·   Maj : courir   ·   Espace : sauter   ·   E : interagir   ·   Échap : libérer la souris"
	help.anchor_top = 1.0
	help.anchor_bottom = 1.0
	help.offset_top = -40
	help.offset_left = 20
	help.add_theme_font_size_override("font_size", 16)
	help.add_theme_color_override("font_color", Color(0.18, 0.16, 0.15, 0.85))
	help.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.7))
	help.add_theme_constant_override("outline_size", 5)
	hud.add_child(help)

func _centered_label(size: int) -> Label:
	var l := Label.new()
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.15, 0.13, 0.12))
	l.add_theme_color_override("font_outline_color", Color(1, 0.98, 0.94, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l

func _update_prompt() -> void:
	var count := players_root.get_child_count()
	info_label.text = "%s\nVoyageurs présents : %d" % [info_text, count]
	banner_label.visible = host_banner_text != "" and count < 2
	banner_label.text = host_banner_text
	var p := _local_player()
	prompt_label.text = ""
	if p == null or solved:
		return
	var idx := _nearest_stone(p.global_position)
	if idx >= 0:
		prompt_label.text = "E : tourner la pierre" if my_turnable.has(idx) else "Cette pierre ne répond pas à ta main"

@rpc("authority", "call_local", "reliable")
func _show_message(text: String, duration: float = 3.5) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message_label, "modulate:a", 1.0, 0.4)
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.8)


# =====================================================================
#  Test automatique (lancé avec --autotest) : deux joueurs simulés
#  se transmettent leurs indices, tournent les pierres, puis montent sur les dalles.
# =====================================================================

var _autotest_known: Dictionary = {}
var _autotest_started := false

func _autotest_roles_received() -> void:
	# Sur l'hôte, on attend l'arrivée du second joueur (sauf en solo).
	if multiplayer.is_server() and not solo and _join_order.size() < 2:
		return
	for k in my_hints:
		_autotest_known[k] = my_hints[k]
	_autotest_share.rpc(my_hints)
	if not _autotest_started:
		_autotest_started = true
		get_tree().create_timer(2.0).timeout.connect(_autotest_act)

## Simule la voix : « au-dessus de la pierre X, je vois tel symbole ».
@rpc("any_peer", "call_remote", "reliable")
func _autotest_share(hints: Dictionary) -> void:
	for k in hints:
		_autotest_known[k] = hints[k]

func _autotest_act() -> void:
	# 1) Essai interdit : l'hôte doit refuser qu'on tourne une pierre non attribuée.
	for i in STONE_COUNT:
		if not my_turnable.has(i):
			if multiplayer.is_server():
				_server_turn(i, multiplayer.get_unique_id())
			else:
				_request_turn.rpc_id(1, i)
			break
	await get_tree().create_timer(0.5).timeout
	# 2) Tourner nos pierres jusqu'au symbole indiqué par l'autre joueur.
	var me := _local_player()
	for i in my_turnable:
		if not _autotest_known.has(i):
			push_error("AUTOTEST: indice manquant pour la pierre %d" % i)
			continue
		me.teleport(stones[i]["root"].global_position + Vector3(0, 0.2, 1.5).rotated(Vector3.UP, stones[i]["root"].rotation.y))
		var guard := 0
		while stone_state[i] != int(_autotest_known[i]) and guard < 8:
			local_interact(me)
			guard += 1
			await get_tree().create_timer(0.3).timeout
	print("AUTOTEST: pierres réglées par le pair %d : %s" % [multiplayer.get_unique_id(), str(stone_state)])
	# 3) Monter sur une dalle.
	var pad_i := 0 if multiplayer.is_server() else 1
	me.teleport(PAD_POSITIONS[pad_i] + Vector3(0, Terrain.height(PAD_POSITIONS[pad_i].x, PAD_POSITIONS[pad_i].z) + 0.4, 0))
