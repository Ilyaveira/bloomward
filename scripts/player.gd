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

func _build_model(cloak_color: Color) -> void:
	_body = Node3D.new()
	model.add_child(_body)
	var skin := Color(0.95, 0.84, 0.72)
	var dark := Color(0.25, 0.22, 0.24)
	# Cape longue évasée
	_body.add_child(Style.mesh_instance(Style.cylinder(0.2, 0.42, 1.05, 12), Style.toon(cloak_color), Vector3(0, 0.55, 0)))
	# Écharpe
	var scarf := TorusMesh.new()
	scarf.inner_radius = 0.13
	scarf.outer_radius = 0.26
	_body.add_child(Style.mesh_instance(scarf, Style.toon(cloak_color.lightened(0.45), 0.015), Vector3(0, 1.08, 0)))
	# Tête + capuche
	_body.add_child(Style.mesh_instance(Style.sphere(0.22, 14), Style.toon(skin), Vector3(0, 1.32, 0.02)))
	var hood := Style.mesh_instance(Style.sphere(0.25, 14), Style.toon(cloak_color.darkened(0.15)), Vector3(0, 1.38, -0.06))
	hood.scale = Vector3(1.0, 1.0, 1.05)
	_body.add_child(hood)
	# Yeux (indiquent la direction du regard)
	for x in [-0.075, 0.075]:
		_body.add_child(Style.mesh_instance(Style.sphere(0.028, 6), Style.toon(dark, 0.0), Vector3(x, 1.35, 0.205)))
	# Sacoche de voyage
	_body.add_child(Style.mesh_instance(Style.box(Vector3(0.3, 0.32, 0.16)), Style.toon(Color(0.55, 0.38, 0.25), 0.015), Vector3(0, 0.75, -0.36)))

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
	if moved > 0.3:
		_anim_t += delta * 11.0
		_body.position.y = abs(sin(_anim_t)) * 0.06
		_body.rotation.z = sin(_anim_t) * 0.05
	else:
		_anim_t = 0.0
		_body.position.y = lerp(_body.position.y, 0.0, 10.0 * delta)
		_body.rotation.z = lerp(_body.rotation.z, 0.0, 10.0 * delta)

## Téléportation (utilisée par le test automatique).
func teleport(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO
