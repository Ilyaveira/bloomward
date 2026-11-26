extends CharacterBody3D
## Personnage jouable. Chaque joueur contrôle le sien (autorité réseau locale) ;
## sa position est diffusée aux autres par un MultiplayerSynchronizer.

const SPEED := 5.0
const ACCEL := 12.0
const JUMP_VELOCITY := 5.2
const GRAVITY := 14.0
const PLAY_RADIUS := 26.0
const MOUSE_SENS := 0.0028

var peer_id := 1
var player_index := 0
var game: Node = null

var model: Node3D
var cam_yaw := 0.0
var cam_pitch := -0.32
var spring_arm: SpringArm3D
var camera: Camera3D
var _spawn_pos := Vector3.ZERO
var _anim_t := 0.0
var _last_pos := Vector3.ZERO
var _body: Node3D

const PALETTE := [
	Color(0.89, 0.45, 0.33),  # terracotta
	Color(0.26, 0.55, 0.62),  # bleu canard
	Color(0.85, 0.66, 0.24),  # safran
	Color(0.55, 0.42, 0.68),  # lavande
]

## Appelé par la fonction de spawn, avant l'entrée dans l'arbre de scène.
func setup(id: int, index: int, pos: Vector3) -> void:
	peer_id = id
	player_index = index
	name = str(id)
	position = pos
	_spawn_pos = pos
	_last_pos = pos

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	shape.shape = capsule
	shape.position.y = 0.8
	add_child(shape)

	model = Node3D.new()
	model.name = "Model"
	model.rotation.y = PI  # dos à la caméra au départ
	add_child(model)
	_build_model(PALETTE[index % PALETTE.size()])

	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	var cfg := SceneReplicationConfig.new()
	for p in [NodePath(".:position"), NodePath("Model:rotation")]:
		cfg.add_property(p)
		cfg.property_set_spawn(p, false)
		cfg.property_set_replication_mode(p, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	sync.replication_config = cfg
	sync.root_path = NodePath("..")
	add_child(sync)

	# Chaque joueur est maître de son propre personnage (et de ses enfants).
	set_multiplayer_authority(id, true)

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _scarf_tail: Node3D

func _build_model(cloak_color: Color) -> void:
	_body = Node3D.new()
	model.add_child(_body)
	var skin := Style.toon(Color(0.93, 0.80, 0.68))
	var cloak := Style.toon(cloak_color)
	var cloak_dark := Style.toon(cloak_color.darkened(0.22))
	var cloth := Style.toon(Color(0.30, 0.28, 0.30))
	var leather := Style.toon(Color(0.52, 0.36, 0.24))
	var scarf_mat := Style.toon(Color(0.96, 0.92, 0.84))
	var dark := Style.toon(Color(0.16, 0.14, 0.15))
	# Jambes (pivot à la hanche) et bottes
	for x in [-0.11, 0.11]:
		var hip := Node3D.new()
		hip.position = Vector3(x, 0.5, 0)
		hip.add_child(Style.mesh_instance(Style.cylinder(0.065, 0.075, 0.42, 8), cloth, Vector3(0, -0.21, 0)))
		hip.add_child(Style.mesh_instance(Style.box(Vector3(0.14, 0.12, 0.22)), leather, Vector3(0, -0.44, 0.03)))
		_body.add_child(hip)
		_legs.append(hip)
	# Tunique et cape évasée, ouverte devant
	_body.add_child(Style.mesh_instance(Style.cylinder(0.2, 0.26, 0.5, 12), cloth, Vector3(0, 0.75, 0)))
	var cape := Style.mesh_instance(Style.cylinder(0.24, 0.46, 0.82, 14), cloak, Vector3(0, 0.66, -0.04))
	cape.scale = Vector3(1.0, 1.0, 0.85)
	_body.add_child(cape)
	_body.add_child(Style.mesh_instance(Style.sphere(0.27, 14), cloak_dark, Vector3(0, 1.04, -0.02)))
	_body.get_child(-1).scale = Vector3(1.15, 0.55, 1.0)
	# Ceinture et sacoche
	_body.add_child(Style.mesh_instance(Style.cylinder(0.215, 0.215, 0.06, 12), leather, Vector3(0, 0.62, 0.02)))
	_body.add_child(Style.mesh_instance(Style.box(Vector3(0.14, 0.14, 0.08)), leather, Vector3(0.2, 0.56, 0.12)))
	# Bras (pivot à l'épaule) et mains
	for x in [-0.27, 0.27]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(x, 1.0, 0)
		shoulder.add_child(Style.mesh_instance(Style.cylinder(0.06, 0.075, 0.42, 8), cloak_dark, Vector3(0, -0.2, 0)))
		shoulder.add_child(Style.mesh_instance(Style.sphere(0.06, 8), skin, Vector3(0, -0.44, 0.01)))
		_body.add_child(shoulder)
		_arms.append(shoulder)
	# Tête, cheveux, capuche rabattue
	_body.add_child(Style.mesh_instance(Style.sphere(0.2, 16), skin, Vector3(0, 1.3, 0.02)))
	var hair := Style.mesh_instance(Style.sphere(0.21, 16), Style.toon(Color(0.36, 0.24, 0.18)), Vector3(0, 1.35, -0.02))
	hair.scale = Vector3(1.0, 0.85, 1.0)
	_body.add_child(hair)
	var hood := Style.mesh_instance(Style.sphere(0.2, 12), cloak_dark, Vector3(0, 1.12, -0.2))
	hood.scale = Vector3(1.2, 0.6, 0.8)
	_body.add_child(hood)
	for x in [-0.07, 0.07]:
		_body.add_child(Style.mesh_instance(Style.sphere(0.024, 6), dark, Vector3(x, 1.31, 0.195)))
	# Écharpe et son pan qui flotte
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.1
	scarf.outer_radius = 0.2
	_body.add_child(Style.mesh_instance(scarf, scarf_mat, Vector3(0, 1.12, 0.0)))
	_scarf_tail = Node3D.new()
	_scarf_tail.position = Vector3(0.1, 1.12, -0.14)
	_scarf_tail.add_child(Style.mesh_instance(Style.box(Vector3(0.09, 0.03, 0.4)), scarf_mat, Vector3(0, 0, -0.2)))
	_body.add_child(_scarf_tail)
	# Sac à dos avec couverture roulée
	_body.add_child(Style.mesh_instance(Style.box(Vector3(0.32, 0.36, 0.16)), leather, Vector3(0, 0.82, -0.3)))
	var roll := Style.mesh_instance(Style.cylinder(0.08, 0.08, 0.4, 10), Style.toon(Color(0.66, 0.30, 0.26)), Vector3(0, 1.04, -0.3))
	roll.rotation.z = PI / 2.0
	_body.add_child(roll)

func _ready() -> void:
	if is_multiplayer_authority():
		spring_arm = SpringArm3D.new()
		spring_arm.spring_length = 4.6
		spring_arm.margin = 0.2
		spring_arm.position = Vector3(0, 1.5, 0)
		spring_arm.add_excluded_object(get_rid())
		add_child(spring_arm)
		camera = Camera3D.new()
		camera.fov = 70.0
		spring_arm.add_child(camera)
		camera.current = true
		if not _is_headless():
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_headless() -> bool:
	return DisplayServer.get_name() == "headless"

func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		cam_yaw -= event.relative.x * MOUSE_SENS
		cam_pitch = clamp(cam_pitch - event.relative.y * MOUSE_SENS, -1.2, 0.35)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event.is_action_pressed("interact") and game:
		game.local_interact(self)

func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_control(delta)
	_animate(delta)

func _control(delta: float) -> void:
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (Basis(Vector3.UP, cam_yaw) * Vector3(input.x, 0, input.y))
	var target := dir * SPEED
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta * SPEED)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta * SPEED)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	move_and_slide()

	# Bord de la zone : on reste dans la clairière.
	var flat := Vector2(position.x, position.z)
	if flat.length() > PLAY_RADIUS:
		flat = flat.normalized() * PLAY_RADIUS
		position.x = flat.x
		position.z = flat.y
	if position.y < -10.0:
		position = _spawn_pos
		velocity = Vector3.ZERO

	if dir.length() > 0.1:
		var target_yaw := atan2(dir.x, dir.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_yaw, 10.0 * delta)
	if spring_arm:
		spring_arm.rotation = Vector3(cam_pitch, cam_yaw, 0)

## Petite animation procédurale de marche, calculée localement pour tous les joueurs.
func _animate(delta: float) -> void:
	var moved: float = Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / max(delta, 0.0001)
	_last_pos = position
	var walking := moved > 0.3
	if walking:
		_anim_t += delta * 9.5
	else:
		_anim_t = lerp(_anim_t, round(_anim_t / PI) * PI, 8.0 * delta)
	var swing := sin(_anim_t) * (0.55 if walking else 0.0)
	var k := 12.0 * delta
	_legs[0].rotation.x = lerp(_legs[0].rotation.x, swing, k)
	_legs[1].rotation.x = lerp(_legs[1].rotation.x, -swing, k)
	_arms[0].rotation.x = lerp(_arms[0].rotation.x, -swing * 0.7, k)
	_arms[1].rotation.x = lerp(_arms[1].rotation.x, swing * 0.7, k)
	_body.position.y = lerp(_body.position.y, absf(sin(_anim_t)) * 0.04 if walking else 0.0, k)
	# Respiration au repos, pan d'écharpe qui flotte
	var t := Time.get_ticks_msec() / 1000.0
	_body.scale.y = 1.0 + sin(t * 2.0) * 0.006
	_scarf_tail.rotation.x = lerp(_scarf_tail.rotation.x, -0.25 - (0.6 if walking else 0.0) + sin(t * 3.0) * 0.08, 6.0 * delta)
	_scarf_tail.rotation.y = sin(t * 2.3) * 0.15

## Téléportation (utilisée par le test automatique).
func teleport(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO
