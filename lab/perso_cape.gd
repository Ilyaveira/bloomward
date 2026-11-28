extends Node3D
## Personnage original à cape : silhouette adulte, visage réduit à deux yeux, marche animée par code.
## `setup` reçoit la fabrique de matériaux du décor, pour partager son éclairage.

const CAPE_SHADER := preload("res://lab/cape.gdshader")

var _solid: Callable
var _body: Node3D
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _cape_mats: Array[ShaderMaterial] = []
var _phase := 0.0
var _motion := 0.0

func setup(solid_fn: Callable, cloth: Color) -> void:
	_solid = solid_fn
	_body = Node3D.new()
	add_child(_body)
	var skin := Color(0.93, 0.76, 0.62)
	var dark := Color(0.20, 0.22, 0.30)
	var linen := Color(0.90, 0.86, 0.76)
	var leather := Color(0.42, 0.28, 0.20)
	var hair := Color(0.28, 0.19, 0.15)
	# jambes et bras pivotent autour de la hanche et de l'épaule
	_leg_l = _limb(Vector3(-0.085, 0.86, 0))
	_leg_r = _limb(Vector3(0.085, 0.86, 0))
	for leg in [_leg_l, _leg_r]:
		_part(leg, _capsule(0.062, 0.86), dark, Vector3(0, -0.41, 0))
		_part(leg, _capsule(0.074, 0.36), leather, Vector3(0, -0.67, 0))
		_part(leg, _sphere(0.09, 16), leather, Vector3(0, -0.80, 0.04), Vector3(0.9, 0.7, 1.5))
	_arm_l = _limb(Vector3(-0.205, 1.42, 0))
	_arm_r = _limb(Vector3(0.205, 1.42, 0))
	for arm in [_arm_l, _arm_r]:
		_part(arm, _capsule(0.042, 0.60), linen.darkened(0.06), Vector3(0, -0.28, 0))
		_part(arm, _sphere(0.045, 12), skin, Vector3(0, -0.60, 0.01), Vector3(0.85, 1.2, 1.0))
	# ceinture, cou, tête, cheveux, yeux, capuche rabattue
	_part(_body, _sphere(0.158, 20), leather.darkened(0.15), Vector3(0, 1.01, 0), Vector3(1.0, 0.20, 0.95))
	_part(_body, _capsule(0.046, 0.16), skin.darkened(0.06), Vector3(0, 1.525, 0))
	_part(_body, _sphere(0.115, 24), skin, Vector3(0, 1.675, 0.008), Vector3(0.92, 1.16, 0.98))
	_part(_body, _sphere(0.125, 24), hair, Vector3(0, 1.715, -0.022), Vector3(0.97, 1.02, 1.02))
	_part(_body, _sphere(0.075, 16), hair, Vector3(0, 1.66, -0.125), Vector3(1.0, 1.0, 0.9))
	for sx in [-0.040, 0.040]:
		_part(_body, _sphere(0.011, 10), Color(0.16, 0.14, 0.18), Vector3(sx, 1.668, 0.112), Vector3(1.0, 1.3, 0.5))
	_part(_body, _sphere(0.13, 16), cloth.darkened(0.10), Vector3(0, 1.43, -0.125), Vector3(1.05, 0.62, 0.70))
	# tunique claire et col
	_garment(_lathe([[0.05, 1.50], [0.125, 1.45], [0.15, 1.30], [0.135, 1.04], [0.15, 0.94], [0.17, 0.76]], 28, 0.03), _mat(linen.darkened(0.14), linen, 0.76, 1.45), 1.0)
	_garment(_lathe([[0.062, 1.545], [0.105, 1.50], [0.15, 1.47]], 28, 0.0), _mat(cloth.lightened(0.38)), 1.02)
	# cape ouverte devant : extérieur, doublure, liseré
	var profile := [[0.066, 1.53], [0.11, 1.508], [0.15, 1.472], [0.18, 1.42], [0.20, 1.35], [0.212, 1.22], [0.22, 1.08], [0.238, 0.90], [0.262, 0.74], [0.29, 0.58], [0.305, 0.52]]
	_garment(_lathe(profile, 44, 0.07, 0.50), _cape_mat(cloth.darkened(0.22), cloth, 0.50, 1.45), 1.0)
	_garment(_lathe(profile, 44, 0.07, 0.50, true), _cape_mat(cloth.darkened(0.42)), 0.992)
	_garment(_lathe([[0.288, 0.59], [0.306, 0.515]], 44, 0.07, 0.50), _cape_mat(cloth.lightened(0.5)), 1.012)

## Avance l'animation : `speed` en mètres par seconde (0 = immobile).
func animate(delta: float, speed: float) -> void:
	var target := clampf(speed / 3.4, 0.0, 1.5)
	_motion = lerpf(_motion, target, 1.0 - exp(-8.0 * delta))
	_phase = fmod(_phase + delta * speed * 2.1, TAU)
	pose(_phase, _motion)

## Pose figée : `phase` du pas (radians) et intensité (0 immobile, 1 marche, 1,5 course).
func pose(phase: float, amount: float) -> void:
	var swing := sin(phase) * 0.55 * minf(amount, 1.3)
	_leg_l.rotation.x = swing
	_leg_r.rotation.x = -swing
	_arm_l.rotation.x = -swing * 0.55
	_arm_r.rotation.x = swing * 0.55
	_body.position.y = (absf(cos(phase)) - 0.6) * 0.035 * amount
	_body.rotation.x = 0.06 * amount
	for m in _cape_mats:
		m.set_shader_parameter("motion", amount)
		m.set_shader_parameter("stride", phase)

func _limb(pivot: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	_body.add_child(n)
	return n

func _mat(color: Color, top: Variant = null, low: float = 0.0, high: float = 1.0) -> ShaderMaterial:
	var m: ShaderMaterial = _solid.call(color, top, low, high)
	m.set_shader_parameter("brush", 0.0)
	return m

func _cape_mat(color: Color, top: Variant = null, low: float = 0.0, high: float = 1.0) -> ShaderMaterial:
	var m := _mat(color, top, low, high)
	m.shader = CAPE_SHADER
	_cape_mats.append(m)
	return m

func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl: Vector3 = Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)

func _garment(mesh: Mesh, mat: ShaderMaterial, widen: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = Vector3(widen, 1.0, widen)
	mi.extra_cull_margin = 0.5
	_body.add_child(mi)

func _sphere(r: float, seg: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = maxi(6, seg / 2)
	return s

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return c

## Vêtement en surface de révolution : profil [rayon, hauteur]. Les épaules sont élargies,
## le bas ondule (plis), et `gap` ouvre le devant en s'évasant vers le bas.
func _lathe(profile: Array, segments: int, wave: float, gap: float = 0.0, flip: bool = false) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rows := profile.size()
	var cols := segments + 1
	for j in rows:
		var py: float = profile[j][1]
		var low: float = clampf((1.47 - py) / 0.97, 0.0, 1.0)
		var sh: float = smoothstep(0.95, 1.50, py)
		var g: float = gap * pow(low, 0.6)
		for i in cols:
			var a := PI + g + (TAU - 2.0 * g) * i / segments
			var r: float = profile[j][0] * (1.0 + wave * low * low * sin(a * 5.0 + 0.6))
			# le vêtement tombe un peu plus bas dans le dos
			var y: float = py - low * low * 0.05 * (0.5 + 0.5 * cos(a))
			st.add_vertex(Vector3(sin(a) * r * (1.0 + 0.34 * sh), y, -cos(a) * r * (1.0 - 0.14 * sh)))
	for j in rows - 1:
		for i in segments:
			var a0 := j * cols + i
			var a1 := a0 + 1
			var b0 := a0 + cols
			var b1 := a1 + cols
			if flip:
				st.add_index(a0); st.add_index(a1); st.add_index(b0)
				st.add_index(a1); st.add_index(b1); st.add_index(b0)
			else:
				st.add_index(a0); st.add_index(b0); st.add_index(a1)
				st.add_index(a1); st.add_index(b0); st.add_index(b1)
	st.generate_normals()
	return st.commit()
