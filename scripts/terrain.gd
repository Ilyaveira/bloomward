class_name Terrain
extends RefCounted
## Relief de la zone, calculé par une fonction déterministe (même résultat chez
## tous les joueurs) : place centrale plate, bassin de la source, lit de rivière
## qui s'échappe par une gorge, collines qui ferment la clairière.

const SEED := 20261126
const FINE_HALF := 50.0      # le maillage fin couvre [-50, 50]²
const FINE_STEP := 0.5
const RIVER_DEPTH := -0.6

static var _cache := {}
static var _noise: FastNoiseLite
static var _noise_hills: FastNoiseLite

static func _ensure() -> void:
	if _noise:
		return
	_noise = FastNoiseLite.new()
	_noise.seed = SEED
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise.frequency = 0.03
	_noise.fractal_octaves = 3
	_noise_hills = FastNoiseLite.new()
	_noise_hills.seed = SEED + 7
	_noise_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_hills.frequency = 0.018
	_noise_hills.fractal_octaves = 4

## Abscisse du milieu de la rivière à une profondeur z donnée (z < 0).
static func river_x(z: float) -> float:
	var start := smoothstep(-2.0, -12.0, z)
	return (sin(z * 0.11) * 3.2 + sin(z * 0.27 + 1.3) * 0.8) * start

static func river_dist(x: float, z: float) -> float:
	if z > -1.5:
		return 999.0
	return absf(x - river_x(z))

static func height(x: float, z: float) -> float:
	_ensure()
	var r := sqrt(x * x + z * z)
	var h := _noise.get_noise_2d(x, z) * 1.8 * smoothstep(9.0, 20.0, r)
	h += _noise.get_noise_2d(x * 4.0, z * 4.0) * 0.06
	var hills := 0.5 + 0.5 * _noise_hills.get_noise_2d(x, z)
	h += smoothstep(23.0, 38.0, r) * (6.0 + hills * 10.0)
	# Bassin de la source
	h -= (1.0 - smoothstep(1.4, 2.7, r)) * 0.65
	# Lit de la rivière (devient une gorge en traversant les collines)
	var rd := river_dist(x, z)
	if rd < 4.0:
		var carve := 1.0 - smoothstep(0.7, 1.9 + smoothstep(20.0, 40.0, r) * 1.5, rd)
		h = lerpf(h, minf(h, RIVER_DEPTH), carve)
	return h

static func normal(x: float, z: float) -> Vector3:
	var e := 0.25
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()

## Maillage du sol (fin au centre, grossier au loin) + collision.
static func build(parent: Node3D, mat: Material) -> void:
	# Le calcul est fait une fois puis réutilisé (menu puis partie).
	if not _cache.has("fine"):
		_cache["fine"] = _grid_mesh(FINE_HALF, FINE_STEP, 0.0)
		_cache["far"] = _grid_mesh(220.0, 4.0, -0.35)
		_cache["shape"] = _height_shape()
	for key in ["fine", "far"]:
		var mi := MeshInstance3D.new()
		mi.mesh = _cache[key]
		mi.material_override = mat
		parent.add_child(mi)
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	col.shape = _cache["shape"]
	body.add_child(col)
	parent.add_child(body)

## Collision : carte de hauteurs au pas de 1 m.
static func _height_shape() -> HeightMapShape3D:
	var shape := HeightMapShape3D.new()
	var n := int(FINE_HALF * 2.0) + 1
	shape.map_width = n
	shape.map_depth = n
	var data := PackedFloat32Array()
	data.resize(n * n)
	for j in n:
		for i in n:
			data[j * n + i] = height(i - FINE_HALF, j - FINE_HALF)
	shape.map_data = data
	return shape

static func _grid_mesh(half: float, step: float, y_offset: float) -> ArrayMesh:
	var n := int(half * 2.0 / step)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var idx := PackedInt32Array()
	verts.resize((n + 1) * (n + 1))
	norms.resize((n + 1) * (n + 1))
	for j in n + 1:
		for i in n + 1:
			var x := -half + i * step
			var z := -half + j * step
			var k := j * (n + 1) + i
			verts[k] = Vector3(x, height(x, z) + y_offset, z)
			norms[k] = normal(x, z)
	for j in n:
		for i in n:
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			idx.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
