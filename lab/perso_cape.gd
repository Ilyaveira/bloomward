extends Node3D
## Personnage original à cape : silhouette adulte, marche animée par code (genoux, appuis, rebond).
## `setup` reçoit la fabrique de matériaux du décor, pour partager son éclairage.

const CAPE_SHADER := preload("res://lab/cape.gdshader")
const HIP_Y := 0.88
const THIGH := 0.43
const SHIN := 0.37

var _solid: Callable
var _body: Node3D
var _hips: Node3D
var _torso: Node3D
var _head: Node3D
var _thigh := {}
var _shin := {}
var _arm := {}
var _fore := {}
var _cape_mats: Array[ShaderMaterial] = []
var _phase := 0.0
var _motion := 0.0
var _clock := 0.0

func setup(solid_fn: Callable, cloth: Color) -> void:
	_solid = solid_fn
	_body = _node(self, Vector3.ZERO)
	_hips = _node(_body, Vector3.ZERO)
	_torso = _node(_body, Vector3.ZERO)
	var skin := Color(0.90, 0.72, 0.58)
	var trousers := Color(0.22, 0.25, 0.33)
	var linen := Color(0.88, 0.84, 0.74)
	var leather := Color(0.40, 0.27, 0.19)
	var hair := Color(0.26, 0.18, 0.14)
	var gold := Color(0.86, 0.68, 0.32)
	var ink := Color(0.15, 0.13, 0.16)
	# jambes : cuisse, genou, tibia, botte
	for s in [-1, 1]:
		var th := _node(_hips, Vector3(0.088 * s, HIP_Y, 0))
		_part(th, _capsule(0.074, THIGH + 0.12), trousers, Vector3(0, -THIGH * 0.5, 0))
		var sh := _node(th, Vector3(0, -THIGH, 0))
		_part(sh, _capsule(0.058, SHIN + 0.10), trousers, Vector3(0, -SHIN * 0.5, 0))
		_part(sh, _capsule(0.068, 0.30), leather, Vector3(0, -SHIN + 0.10, 0))
		_part(sh, _sphere(0.074, 14), leather.lightened(0.10), Vector3(0, -SHIN + 0.235, 0), Vector3(1.0, 0.28, 1.0))
		_part(sh, _sphere(0.085, 16), leather, Vector3(0, -SHIN - 0.025, 0.05), Vector3(0.92, 0.62, 1.7))
		_part(sh, _sphere(0.085, 16), leather.darkened(0.35), Vector3(0, -SHIN - 0.062, 0.05), Vector3(0.95, 0.22, 1.74))
		_thigh[s] = th
		_shin[s] = sh
	# bras : épaule, coude, avant-bras, main
	for s in [-1, 1]:
		var ar := _node(_torso, Vector3(0.185 * s, 1.42, 0))
		_part(ar, _capsule(0.046, 0.33), linen.darkened(0.05), Vector3(0, -0.14, 0))
		var fo := _node(ar, Vector3(0, -0.28, 0))
		_part(fo, _capsule(0.040, 0.30), linen.darkened(0.05), Vector3(0, -0.12, 0))
		_part(fo, _sphere(0.046, 12), leather, Vector3(0, -0.235, 0), Vector3(1.0, 0.5, 1.0))
		_part(fo, _sphere(0.040, 12), skin, Vector3(0, -0.30, 0.004), Vector3(0.72, 1.25, 0.95))
		_part(fo, _sphere(0.016, 8), skin, Vector3(-0.022 * s, -0.285, 0.022), Vector3(0.9, 1.5, 0.9))
		_arm[s] = ar
		_fore[s] = fo
	# tête : cou, crâne, mâchoire, nez, oreilles, regard, cheveux noués
	_head = _node(_torso, Vector3(0, 1.53, 0))
	_part(_head, _capsule(0.044, 0.15), skin.darkened(0.07), Vector3(0, 0.02, 0))
	_part(_head, _sphere(0.112, 28), skin, Vector3(0, 0.158, 0.0), Vector3(0.90, 1.08, 1.0))
	_part(_head, _sphere(0.085, 20), skin, Vector3(0, 0.094, 0.020), Vector3(0.84, 0.92, 0.96))
	_part(_head, _sphere(0.017, 10), skin.darkened(0.05), Vector3(0, 0.128, 0.106), Vector3(0.75, 1.35, 1.0))
	for s in [-1, 1]:
		_part(_head, _sphere(0.026, 10), skin.darkened(0.04), Vector3(0.097 * s, 0.142, -0.006), Vector3(0.45, 1.0, 0.75))
		_part(_head, _sphere(0.0105, 10), ink, Vector3(0.039 * s, 0.158, 0.099), Vector3(1.15, 1.0, 0.5))
		_part(_head, _sphere(0.011, 8), hair, Vector3(0.040 * s, 0.184, 0.100), Vector3(1.5, 0.22, 0.5))
		_part(_head, _sphere(0.05, 12), hair, Vector3(0.088 * s, 0.185, 0.02), Vector3(0.5, 1.25, 1.0))
	_part(_head, _sphere(0.010, 8), skin.darkened(0.22), Vector3(0, 0.086, 0.097), Vector3(1.5, 0.22, 0.5))
	_part(_head, _sphere(0.122, 28), hair, Vector3(0, 0.190, -0.022), Vector3(0.97, 1.0, 1.04))
	_part(_head, _sphere(0.09, 16), hair, Vector3(0.012, 0.238, 0.050), Vector3(1.05, 0.50, 0.80))
	_part(_head, _sphere(0.058, 16), hair, Vector3(0, 0.215, -0.135), Vector3(1.0, 1.0, 0.9))
	_part(_head, _sphere(0.02, 8), cloth.lightened(0.3), Vector3(0, 0.205, -0.105), Vector3(1.6, 1.0, 0.8))
	# tunique, ceinture à boucle, sacoche en bandoulière
	_garment(_lathe([[0.05, 1.50], [0.125, 1.45], [0.15, 1.30], [0.135, 1.04], [0.15, 0.94], [0.172, 0.74]], 32, 0.035), _mat(linen.darkened(0.16), linen, 0.74, 1.45, 0.08), 1.0)
	_garment(_lathe([[0.168, 0.775], [0.176, 0.735]], 32, 0.035), _mat(cloth.darkened(0.05)), 1.01)
	_garment(_lathe([[0.143, 1.036], [0.150, 1.03], [0.150, 0.988], [0.143, 0.982]], 32, 0.0), _mat(leather.darkened(0.12)), 1.0)
	_part(_torso, _sphere(0.022, 10), gold, Vector3(0, 1.008, 0.142), Vector3(1.0, 1.15, 0.4))
	var strap := TorusMesh.new()
	strap.inner_radius = 0.268
	strap.outer_radius = 0.292
	strap.rings = 40
	strap.ring_segments = 8
	var sm := _part(_torso, strap, leather, Vector3(-0.02, 1.215, 0.0), Vector3(1.0, 1.6, 0.56))
	sm.rotation.z = deg_to_rad(-58.0)
	_part(_torso, _sphere(0.085, 14), leather.lightened(0.05), Vector3(-0.185, 0.93, 0.03), Vector3(0.55, 1.0, 1.15))
	_part(_torso, _sphere(0.085, 14), leather.darkened(0.12), Vector3(-0.192, 0.965, 0.03), Vector3(0.56, 0.62, 1.18))
	_part(_torso, _sphere(0.012, 8), gold, Vector3(-0.238, 0.935, 0.03))
	# cape ouverte devant : extérieur, doublure, deux liserés, col, capuche, fermoir
	var profile := [[0.066, 1.53], [0.11, 1.508], [0.15, 1.472], [0.18, 1.42], [0.202, 1.35], [0.218, 1.22], [0.230, 1.08], [0.246, 0.90], [0.268, 0.74], [0.294, 0.58], [0.308, 0.52]]
	_garment(_lathe(profile, 48, 0.08, 0.50), _cape_mat(cloth.darkened(0.25), cloth, 0.50, 1.45), 1.0)
	_garment(_lathe(profile, 48, 0.08, 0.50, true), _cape_mat(cloth.darkened(0.45)), 0.992)
	_garment(_lathe([[0.290, 0.60], [0.309, 0.515]], 48, 0.08, 0.50), _cape_mat(cloth.lightened(0.45)), 1.012)
	_garment(_lathe([[0.281, 0.655], [0.286, 0.628]], 48, 0.08, 0.50), _cape_mat(gold.darkened(0.05)), 1.014)
	_garment(_lathe([[0.062, 1.548], [0.105, 1.503], [0.152, 1.468]], 32, 0.0), _mat(cloth.lightened(0.32)), 1.02)
	_part(_torso, _sphere(0.14, 18), cloth.darkened(0.12), Vector3(0, 1.435, -0.13), Vector3(1.12, 0.66, 0.78))
	_part(_torso, _sphere(0.10, 14), cloth.darkened(0.30), Vector3(0, 1.46, -0.135), Vector3(1.0, 0.45, 0.7))
	_part(_torso, _sphere(0.024, 12), gold, Vector3(0, 1.462, 0.118), Vector3(1.0, 1.0, 0.45))
	pose(0.0, 0.0)

## Avance l'animation : `speed` en mètres par seconde (0 = immobile).
func animate(delta: float, speed: float) -> void:
	_clock += delta
	var target := clampf(speed / 3.4, 0.0, 1.5)
	_motion = lerpf(_motion, target, 1.0 - exp(-8.0 * delta))
	# un pas tous les 1,15 m environ : les pieds ne glissent presque plus
	_phase = fmod(_phase + delta * speed * 2.73, TAU)
	pose(_phase, _motion)

## Pose figée : `phase` du pas (radians) et intensité (0 immobile, 1 marche, 1,5 course).
func pose(phase: float, amount: float) -> void:
	var a := minf(amount, 1.4)
	for s in [-1, 1]:
		var ph := phase + (0.0 if s == -1 else PI)
		var fwd := sin(ph)
		# la jambe qui revient vers l'avant plie le genou et décolle le pied
		var air := pow(maxf(cos(ph), 0.0), 1.2)
		_thigh[s].rotation.x = -a * (0.50 * fwd + 0.10 + 0.22 * air)
		_shin[s].rotation.x = a * (0.12 + 1.10 * air) + a * 0.18 * maxf(-fwd, 0.0)
		# bras opposé à la jambe, coude plié
		var sw := -fwd
		_arm[s].rotation.x = -a * (0.46 * sw if sw > 0.0 else 0.20 * sw)
		_arm[s].rotation.z = 0.05 * s
		_fore[s].rotation.x = -(0.22 + a * (0.30 + 0.40 * maxf(sw, 0.0)))
	# le corps monte sur la jambe d'appui et retombe à chaque pose du pied
	var up := pow(absf(cos(phase)), 0.8)
	var breath := sin(_clock * 1.7) * 0.004 * (1.0 - minf(a, 1.0))
	_body.position.y = -0.075 * a * (1.0 - up) - 0.012 * a + breath
	_body.position.x = 0.024 * a * cos(phase)
	_body.position.z = 0.020 * a * sin(2.0 * phase + 0.6)
	_body.rotation.x = 0.07 * a
	_body.rotation.z = 0.022 * a * cos(phase)
	_hips.rotation.y = 0.11 * a * sin(phase)
	_torso.rotation.y = -0.09 * a * sin(phase)
	_torso.rotation.z = -0.018 * a * cos(phase)
	_head.rotation.x = -0.05 * a + 0.02 * a * cos(2.0 * phase)
	_head.rotation.y = 0.05 * a * sin(phase)
	for m in _cape_mats:
		m.set_shader_parameter("motion", a)
		m.set_shader_parameter("stride", phase)

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _mat(color: Color, top: Variant = null, low: float = 0.0, high: float = 1.0, grain: float = 0.0) -> ShaderMaterial:
	var m: ShaderMaterial = _solid.call(color, top, low, high)
	m.set_shader_parameter("brush", grain)
	return m

func _cape_mat(color: Color, top: Variant = null, low: float = 0.0, high: float = 1.0) -> ShaderMaterial:
	var m := _mat(color, top, low, high)
	m.shader = CAPE_SHADER
	_cape_mats.append(m)
	return m

func _part(parent: Node3D, mesh: Mesh, color: Color, pos: Vector3, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(color)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi

func _garment(mesh: Mesh, mat: ShaderMaterial, widen: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.scale = Vector3(widen, 1.0, widen)
	mi.extra_cull_margin = 0.5
	_torso.add_child(mi)

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
			# épaules tombantes plutôt que carrées
			y -= 0.055 * sh * pow(absf(sin(a)), 2.0) * smoothstep(0.08, 0.20, float(profile[j][0]))
			st.add_vertex(Vector3(sin(a) * r * (1.0 + 0.28 * sh), y, -cos(a) * r * (1.0 - 0.14 * sh)))
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
