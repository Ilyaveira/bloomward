extends CharacterBody3D
## Personnage jouable. Chaque joueur contrôle le sien (autorité réseau locale) ;
## sa position est diffusée aux autres par un MultiplayerSynchronizer.

const SPEED := 3.4
const SPRINT_SPEED := 6.2
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

## Personnages : modèles 3D libres de droits (Quaternius, licence CC0),
## voir assets/models/CREDITS.md.
const CHARACTER_MODELS := [
	"res://assets/models/quaternius/characters/Female_Casual.glb",
	"res://assets/models/quaternius/characters/Male_LongSleeve.glb",
	"res://assets/models/quaternius/characters/Female_Alternative.glb",
	"res://assets/models/quaternius/characters/Male_Casual.glb",
]
const MODEL_HEIGHT := 4.65   # hauteur du modèle source
const TARGET_HEIGHT := 1.72

var _anim: AnimationPlayer
var _anim_names := {}
var _current_anim := ""
var _airborne_time := 0.0
var _step_dist := 0.0

func _build_model(cloak_color: Color) -> void:
	_body = Node3D.new()
	model.add_child(_body)
	var scene: PackedScene = load(CHARACTER_MODELS[player_index % CHARACTER_MODELS.size()])
	var character := scene.instantiate()
	var s := TARGET_HEIGHT / MODEL_HEIGHT
	character.scale = Vector3(s, s, s)
	_body.add_child(character)
	# Matériaux réaccordés au style du jeu (ombrage doux) ; le haut prend la couleur du joueur.
	for node in character.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var col := Color(0.6, 0.6, 0.6)
			var name := ""
			if src is BaseMaterial3D:
				col = src.albedo_color
				name = src.resource_name
			if name == "Shirt":
				col = cloak_color
			elif name == "Skin":
				col = col.lightened(0.15)
			mi.set_surface_override_material(i, Style.toon(Color(col.r, col.g, col.b)))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var players := character.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		_anim = players[0]
		for n in _anim.get_animation_list():
			for key in ["Idle", "Walk", "Run", "Jump"]:
				if n.ends_with(key) and not n.ends_with("Running" + key):
					_anim_names[key] = n
					if key != "Jump":
						_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play("Idle")

func _play(key: String, blend: float = 0.2) -> void:
	if _anim == null or not _anim_names.has(key) or _current_anim == key:
		return
	_current_anim = key
	_anim.play(_anim_names[key], blend)

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
	var target := dir * (SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED)
	velocity.x = move_toward(velocity.x, target.x, ACCEL * delta * SPRINT_SPEED)
	velocity.z = move_toward(velocity.z, target.z, ACCEL * delta * SPRINT_SPEED)
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

## Animation : marche, course, repos et saut, déduits du déplacement (identique chez tous).
func _animate(delta: float) -> void:
	var moved: float = Vector2(position.x - _last_pos.x, position.z - _last_pos.z).length() / max(delta, 0.0001)
	var dy: float = (position.y - _last_pos.y) / max(delta, 0.0001)
	_last_pos = position
	if absf(dy) > 1.5:
		_airborne_time += delta
	else:
		_airborne_time = 0.0
	if _airborne_time > 0.12:
		_play("Jump", 0.1)
	elif moved > 4.5:
		_play("Run")
	elif moved > 0.3:
		_play("Walk")
	else:
		_play("Idle", 0.3)
	# Bruits de pas : un pas tous les ~1,5 m en marchant, plus espacés en courant.
	if _airborne_time == 0.0 and moved > 0.3 and moved < 15.0:
		_step_dist += moved * delta
		var stride := 2.3 if moved > 4.5 else 1.5
		if _step_dist >= stride:
			_step_dist = 0.0
			Son.play_at("pas_%d" % randi_range(1, 5), global_position, -9.0 if moved > 4.5 else -13.0, randf_range(0.9, 1.1))
	if _anim and _current_anim == "Walk":
		_anim.speed_scale = clampf(moved / 2.2, 0.8, 1.6)
	elif _anim:
		_anim.speed_scale = 1.0

## Téléportation (utilisée par le test automatique).
func teleport(pos: Vector3) -> void:
	position = pos
	velocity = Vector3.ZERO
