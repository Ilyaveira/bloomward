extends Node3D
## Décor de la zone : lumière, ciel, relief, végétation, ruines, eau, vie.
## Tout est généré par le code, de façon déterministe (identique chez tous les joueurs).
## La restauration est pilotée par deux paramètres globaux de shader :
## bloom_center (la source) et bloom_radius (le front de la vague).

const SEED := 20261126
const MAX_BLOOM := 70.0

static var _cache := {}
## Mode léger (PC moins puissants) : moins d'herbe, ombres et occlusion simplifiées.
static var light_mode := false

var env: Environment
var sky_mat: ShaderMaterial
var noise_tex: NoiseTexture2D
var pollen: GPUParticles3D
var butterflies: GPUParticles3D
var spring_bubbles: GPUParticles3D
var restore_t := 0.0


func _ready() -> void:
	RenderingServer.global_shader_parameter_set("bloom_center", Vector3.ZERO)
	RenderingServer.global_shader_parameter_set("bloom_radius", 0.0)
	noise_tex = _make_noise_tex(SEED, 0.02)
	_build_environment()
	_build_terrain()
	_build_post_outline()
	_build_spring()
	_build_ruins()
	_build_rocks()
	_build_trees()
	_build_grass()
	_build_flowers()
	_build_life()
	apply_restore(0.0)


## t = 0 : zone flétrie ; t = 1 : zone restaurée (la vague a tout recouvert).
func apply_restore(t: float) -> void:
	restore_t = t
	RenderingServer.global_shader_parameter_set("bloom_radius", t * MAX_BLOOM)
	env.adjustment_saturation = lerpf(0.78, 1.04, t)
	env.fog_light_color = Color(0.93, 0.86, 0.76).lerp(Color(0.86, 0.90, 0.92), t)
	sky_mat.set_shader_parameter("top_color", Color(0.52, 0.64, 0.80).lerp(Color(0.34, 0.58, 0.90), t))
	pollen.emitting = t > 0.35
	butterflies.emitting = t > 0.55
	spring_bubbles.emitting = t > 0.02


static func ground_y(x: float, z: float) -> float:
	return Terrain.height(x, z)


# =====================================================================
#  Lumière, ciel, contours
# =====================================================================

func _make_noise_tex(seed_value: int, freq: float, size: int = 256) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.generate_mipmaps = true
	t.noise = n
	return t

func _build_environment() -> void:
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = preload("res://shaders/sky.gdshader")
	sky_mat.set_shader_parameter("cloud_tex", _make_noise_tex(SEED + 3, 0.012, 512))
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.ambient_light_sky_contribution = 0.85
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.tonemap_white = 1.2
	env.ssao_enabled = not light_mode
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.6
	env.ssao_light_affect = 0.15
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_density = 0.0025
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.15
	env.fog_height = 2.0
	env.fog_height_density = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36, -42, 0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 80.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS if light_mode else DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

	# Lumière de rebond douce et froide depuis le côté opposé (relief des ombres).
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 140, 0)
	fill.light_color = Color(0.70, 0.80, 1.0)
	fill.light_energy = 0.18
	fill.light_specular = 0.0
	add_child(fill)

func _build_terrain() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex)
	Terrain.build(self, mat)

func _build_post_outline() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/outline_post.gdshader")
	mat.render_priority = 10
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "OutlinePost"
	add_child(mi)


# =====================================================================
#  Source et rivière
# =====================================================================

func _water_material() -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water.gdshader")
	m.set_shader_parameter("noise_tex", noise_tex)
	m.render_priority = 20
	return m

func _build_spring() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 10
	var rim_mat := Style.toon(Color(0.76, 0.72, 0.64))
	var moss_mat := Style.toon(Color(0.64, 0.62, 0.55))
	# Margelle de pierres taillées, interrompue là où la rivière s'échappe
	for i in 14:
		var a := TAU * i / 14.0
		var p := Vector3(sin(a) * 2.75, 0.0, cos(a) * 2.75)
		if p.z < -1.5 and absf(p.x) < 1.2:
			continue
		var block := Style.mesh_instance(Style.box(Vector3(1.1, 0.42, 0.55)), rim_mat if i % 3 else moss_mat, p + Vector3(0, ground_y(p.x, p.z) + 0.12, 0))
		block.rotation.y = a
		block.rotation.z = rng.randf_range(-0.05, 0.05)
		add_child(block)
	# Vasque centrale d'où jaillira l'eau
	var stone := Style.toon(Color(0.80, 0.76, 0.68))
	var y0 := ground_y(0, 0)
	add_child(Style.mesh_instance(Style.cylinder(0.32, 0.45, 0.7, 10), stone, Vector3(0, y0 + 0.35, 0)))
	add_child(Style.mesh_instance(Style.cylinder(0.62, 0.38, 0.22, 14), stone, Vector3(0, y0 + 0.8, 0)))
	# Eau du bassin
	var basin := Style.cylinder(2.6, 2.6, 0.02, 32)
	add_child(Style.mesh_instance(basin, _water_material(), Vector3(0, -0.22, 0)))
	# Ruban d'eau qui suit le lit de la rivière
	add_child(_river_mesh())

func _river_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var z := -1.6
	var dist := 0.0
	var prev := Vector3(Terrain.river_x(z), -0.22, z)
	var half_w := 1.6
	var rows := []
	while z > -50.0:
		var c := Vector3(Terrain.river_x(z), -0.22, z)
		dist += c.distance_to(prev)
		prev = c
		var w := half_w + smoothstep(-20.0, -40.0, z) * 1.2
		rows.append([c + Vector3(-w, 0, 0), c + Vector3(w, 0, 0), dist])
		z -= 0.5
	for i in rows.size() - 1:
		var a: Array = rows[i]
		var b: Array = rows[i + 1]
		var quad := [[a[0], 0.0, a[2]], [a[1], 1.0, a[2]], [b[0], 0.0, b[2]], [a[1], 1.0, a[2]], [b[1], 1.0, b[2]], [b[0], 0.0, b[2]]]
		for v in quad:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(v[1], v[2]))
			st.add_vertex(v[0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _water_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# =====================================================================
#  Ruines, rochers
# =====================================================================

func _build_ruins() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 20
	var stone := Style.toon(Color(0.78, 0.73, 0.65))
	var stone_dark := Style.toon(Color(0.68, 0.63, 0.57))
	# Muret circulaire en ruine autour de la place
	var segs := 26
	for i in segs:
		var a := TAU * i / segs
		var p := Vector3(sin(a) * 11.5, 0, cos(a) * 11.5)
		if Terrain.river_dist(p.x, p.z) < 2.6:
			continue
		if rng.randf() < 0.3:
			continue  # pans effondrés
		var h := rng.randf_range(0.25, 0.9)
		var w := Style.mesh_instance(Style.box(Vector3(2.4, h, 0.55)), stone if i % 2 else stone_dark, p + Vector3(0, ground_y(p.x, p.z) + h * 0.5 - 0.05, 0))
		w.rotation.y = a
		w.rotation.x = rng.randf_range(-0.04, 0.04)
		add_child(w)
		if rng.randf() < 0.35:
			var b := Style.mesh_instance(Style.box(Vector3(0.5, 0.35, 0.45)), stone_dark, p + Vector3(rng.randf_range(-1, 1), ground_y(p.x, p.z) + 0.15, rng.randf_range(0.6, 1.2)))
			b.rotation = Vector3(rng.randf() * 0.4, rng.randf() * TAU, rng.randf() * 0.3)
			add_child(b)
	# Arches d'entrée
	for a in [0.0, PI * 0.5, PI * 1.5]:
		_arch(Vector3(sin(a) * 11.5, 0, cos(a) * 11.5), a, stone, a == PI * 1.5)
	# Colonnes isolées, dont une couchée
	for k in 5:
		var a := rng.randf() * TAU
		var r := rng.randf_range(13.0, 19.0)
		var p := Vector3(sin(a) * r, 0, cos(a) * r)
		if Terrain.river_dist(p.x, p.z) < 3.0:
			continue
		if k == 0:
			var c := Style.mesh_instance(Style.cylinder(0.32, 0.32, 3.2, 12), stone, p + Vector3(0, ground_y(p.x, p.z) + 0.3, 0))
			c.rotation = Vector3(0, a, PI / 2.0 - 0.08)
			add_child(c)
		else:
			_column(p, rng.randf_range(1.2, 3.4), stone, stone_dark)

func _column(p: Vector3, h: float, mat: Material, mat2: Material) -> void:
	var y := ground_y(p.x, p.z)
	add_child(Style.mesh_instance(Style.box(Vector3(0.9, 0.3, 0.9)), mat2, p + Vector3(0, y + 0.1, 0)))
	add_child(Style.mesh_instance(Style.cylinder(0.3, 0.34, h, 12), mat, p + Vector3(0, y + 0.25 + h * 0.5, 0)))
	if h > 2.6:
		add_child(Style.mesh_instance(Style.box(Vector3(0.8, 0.22, 0.8)), mat2, p + Vector3(0, y + 0.3 + h, 0)))

func _arch(p: Vector3, angle: float, mat: Material, broken: bool) -> void:
	var y := ground_y(p.x, p.z)
	var root := Node3D.new()
	root.position = Vector3(p.x, y, p.z)
	root.rotation.y = angle
	add_child(root)
	for side in [-1.3, 1.3]:
		var h := 2.9 if not (broken and side > 0) else 1.6
		root.add_child(Style.mesh_instance(Style.box(Vector3(0.7, h, 0.75)), mat, Vector3(side, h * 0.5, 0)))
		root.add_child(Style.mesh_instance(Style.box(Vector3(0.85, 0.25, 0.9)), mat, Vector3(side, h + 0.1, 0)))
	if not broken:
		root.add_child(Style.mesh_instance(Style.box(Vector3(3.6, 0.45, 0.8)), mat, Vector3(0, 3.25, 0)))
	else:
		var fallen := Style.mesh_instance(Style.box(Vector3(3.2, 0.45, 0.8)), mat, Vector3(1.0, 0.25, 1.4))
		fallen.rotation = Vector3(0.1, 0.5, 0.05)
		root.add_child(fallen)

func _build_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 30
	var mats := [Style.toon(Color(0.66, 0.62, 0.57)), Style.toon(Color(0.58, 0.55, 0.52)), Style.toon(Color(0.72, 0.66, 0.58))]
	for i in 40:
		var a := rng.randf() * TAU
		var r := rng.randf_range(9.0, 34.0)
		var p := Vector3(sin(a) * r, 0, cos(a) * r)
		if Terrain.river_dist(p.x, p.z) < 1.2:
			continue
		var s := rng.randf_range(0.3, 1.1) * (1.0 + smoothstep(22.0, 34.0, r) * 1.5)
		var rock := Style.mesh_instance(Style.sphere(1.0, 6), mats[i % 3], p + Vector3(0, ground_y(p.x, p.z) - s * 0.2, 0))
		rock.scale = Vector3(s * rng.randf_range(1.0, 1.6), s * rng.randf_range(0.5, 0.9), s)
		rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf() * TAU, rng.randf_range(-0.2, 0.2))
		add_child(rock)
	# Galets dans le lit de la rivière
	for i in 30:
		var z := rng.randf_range(-4.0, -30.0)
		var x := Terrain.river_x(z) + rng.randf_range(-1.0, 1.0)
		var g := Style.mesh_instance(Style.sphere(0.18, 6), mats[i % 3], Vector3(x, ground_y(x, z) + 0.03, z))
		g.scale = Vector3(1.4, 0.5, 1.0) * rng.randf_range(0.7, 1.5)
		add_child(g)


# =====================================================================
#  Arbres
# =====================================================================

func _foliage_material() -> ShaderMaterial:
	if not _cache.has("foliage_mat"):
		var m := ShaderMaterial.new()
		m.shader = preload("res://shaders/foliage.gdshader")
		_cache["foliage_mat"] = m
	return _cache["foliage_mat"]

func _build_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 40
	var bark := Style.toon(Color(0.50, 0.38, 0.30))
	var greens := [Color(0.36, 0.58, 0.28), Color(0.46, 0.66, 0.30), Color(0.30, 0.52, 0.36), Color(0.56, 0.68, 0.30), Color(0.40, 0.60, 0.42)]
	var placed := 0
	var tries := 0
	while placed < 46 and tries < 400:
		tries += 1
		var a := rng.randf() * TAU
		var r := rng.randf_range(13.5, 40.0)
		var p := Vector3(sin(a) * r, 0, cos(a) * r)
		if Terrain.river_dist(p.x, p.z) < 3.2:
			continue
		if absf(r - 11.5) < 1.5:
			continue
		p.y = ground_y(p.x, p.z)
		var green: Color = greens[rng.randi() % greens.size()]
		if r > 26.0 and rng.randf() < 0.6:
			_conifer(p, rng, bark, green.darkened(0.12))
		else:
			_broadleaf(p, rng, bark, green)
		placed += 1

func _broadleaf(p: Vector3, rng: RandomNumberGenerator, bark: Material, green: Color) -> void:
	var tree := Node3D.new()
	tree.position = p
	tree.rotation.y = rng.randf() * TAU
	add_child(tree)
	var h := rng.randf_range(2.6, 4.2)
	var lean := Vector3(rng.randf_range(-0.08, 0.08), 0, rng.randf_range(-0.08, 0.08))
	var trunk := Style.mesh_instance(Style.cylinder(0.14, 0.28, h, 9), bark, Vector3(0, h * 0.5, 0))
	trunk.rotation = lean
	tree.add_child(trunk)
	var top := Basis.from_euler(lean) * Vector3(0, h, 0)
	var crowns := [top + Vector3(0, 0.4, 0)]
	var nb := rng.randi_range(2, 4)
	for b in nb:
		var start_h := h * rng.randf_range(0.5, 0.85)
		var start := Basis.from_euler(lean) * Vector3(0, start_h, 0)
		var dir := Vector3(sin(TAU * b / nb + rng.randf()), rng.randf_range(0.6, 1.0), cos(TAU * b / nb + rng.randf())).normalized()
		var length := rng.randf_range(0.9, 1.6)
		var branch := Style.mesh_instance(Style.cylinder(0.05, 0.11, length, 7), bark, start + dir * length * 0.5)
		branch.basis = Basis(Quaternion(Vector3.UP, dir))
		tree.add_child(branch)
		crowns.append(start + dir * length)
	var mat := _foliage_material()
	for c in crowns:
		for k in 2:
			var rad := rng.randf_range(0.75, 1.25)
			var blob := Style.mesh_instance(Style.sphere(rad, 9), mat, c + Vector3(rng.randf_range(-0.35, 0.35), rng.randf_range(-0.1, 0.35), rng.randf_range(-0.35, 0.35)))
			blob.scale = Vector3(1.0, rng.randf_range(0.75, 0.95), 1.0)
			blob.set_instance_shader_parameter("lush_color", green.lightened(rng.randf_range(-0.04, 0.1)))
			tree.add_child(blob)

func _conifer(p: Vector3, rng: RandomNumberGenerator, bark: Material, green: Color) -> void:
	var tree := Node3D.new()
	tree.position = p
	add_child(tree)
	var h := rng.randf_range(4.0, 6.5)
	tree.add_child(Style.mesh_instance(Style.cylinder(0.1, 0.2, h * 0.5, 7), bark, Vector3(0, h * 0.25, 0)))
	var mat := _foliage_material()
	for k in 3:
		var t := float(k) / 3.0
		var cone := Style.mesh_instance(Style.cylinder(0.0, lerpf(1.5, 0.7, t) * h / 5.0, h * 0.45, 9), mat, Vector3(0, h * (0.35 + t * 0.3), 0))
		cone.set_instance_shader_parameter("lush_color", green.lightened(t * 0.08))
		tree.add_child(cone)


# =====================================================================
#  Herbe et fleurs (instanciées en masse, animées par les shaders)
# =====================================================================

func _blade_mesh() -> ArrayMesh:
	var w := 0.035
	var h := 0.42
	var pts := [Vector3(-w, 0, 0), Vector3(w, 0, 0), Vector3(-w * 0.7, h * 0.45, 0.02), Vector3(w * 0.7, h * 0.45, 0.02), Vector3(0, h, 0.07)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[0, 2, 1], [1, 2, 3], [2, 4, 3]]:
		for i in tri:
			st.set_normal(Vector3.UP)
			st.add_vertex(pts[i])
	return st.commit()

func _meadow_points(count: int, max_r: float, seed_value: int) -> PackedVector3Array:
	var key := "pts_%d_%d" % [count, seed_value]
	if _cache.has(key):
		return _cache[key]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out := PackedVector3Array()
	while out.size() < count:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * max_r
		var x := sin(a) * r
		var z := cos(a) * r
		if r < 3.1 or Terrain.river_dist(x, z) < 1.0:
			continue
		var y := ground_y(x, z)
		if y > 6.0:
			continue
		out.append(Vector3(x, y, z))
	_cache[key] = out
	return out

func _build_grass() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/grass.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex)
	var mesh := _blade_mesh()
	mesh.surface_set_material(0, mat)
	var pts := _meadow_points(70000, 34.0, SEED + 50)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 51
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.3))
		mm.set_instance_transform(i, Transform3D(b, pts[i]))
	if light_mode:
		mm.visible_instance_count = mm.instance_count * 2 / 5
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _flower_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.append_from(Style.box(Vector3(0.015, 0.3, 0.015)), 0, Transform3D(Basis(), Vector3(0, 0.15, 0)))
	for k in 5:
		var a := TAU * k / 5.0
		var petal := Style.sphere(0.05, 6)
		st.append_from(petal, 0, Transform3D(Basis(Vector3.UP, a).scaled(Vector3(1.0, 0.35, 0.6)), Vector3(sin(a) * 0.045, 0.31, cos(a) * 0.045)))
	st.append_from(Style.sphere(0.028, 6), 0, Transform3D(Basis(), Vector3(0, 0.33, 0)))
	return st.commit()

func _build_flowers() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/flower.gdshader")
	var mesh := _flower_mesh()
	mesh.surface_set_material(0, mat)
	var pts := _meadow_points(1800, 30.0, SEED + 60)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 61
	var petals := [Color(0.98, 0.62, 0.70), Color(1.0, 0.97, 0.92), Color(1.0, 0.84, 0.35), Color(0.74, 0.62, 0.96), Color(0.98, 0.52, 0.40), Color(0.55, 0.75, 1.0)]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = pts.size()
	# Les fleurs poussent en petits massifs d'une même couleur.
	for i in pts.size():
		var cluster := int(floor(pts[i].x / 4.0) * 7 + floor(pts[i].z / 4.0) * 13)
		var col: Color = petals[posmod(cluster, petals.size())]
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.4)), pts[i]))
		mm.set_instance_color(i, col)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# =====================================================================
#  Vie : pollen, papillons, bouillonnement de la source
# =====================================================================

func _build_life() -> void:
	# Pollen lumineux
	pollen = GPUParticles3D.new()
	pollen.amount = 260
	pollen.lifetime = 8.0
	pollen.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 10, 60))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(24, 1.5, 24)
	pm.gravity = Vector3(0, 0.03, 0)
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.2
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.6
	pm.turbulence_noise_scale = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.3
	pollen.process_material = pm
	var dot := Style.sphere(0.03, 6)
	dot.material = Style.glow(Color(1.0, 0.94, 0.7), 2.5, 0.9)
	pollen.draw_pass_1 = dot
	pollen.position = Vector3(0, 1.6, 0)
	pollen.emitting = false
	add_child(pollen)

	# Papillons
	butterflies = GPUParticles3D.new()
	butterflies.amount = 40
	butterflies.lifetime = 14.0
	butterflies.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 10, 60))
	var bm := ParticleProcessMaterial.new()
	bm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	bm.emission_box_extents = Vector3(20, 0.8, 20)
	bm.gravity = Vector3.ZERO
	bm.initial_velocity_min = 0.3
	bm.initial_velocity_max = 0.8
	bm.direction = Vector3(1, 0.1, 0)
	bm.spread = 180.0
	bm.turbulence_enabled = true
	bm.turbulence_noise_strength = 2.5
	bm.turbulence_noise_scale = 6.0
	bm.particle_flag_align_y = false
	bm.hue_variation_min = -0.5
	bm.hue_variation_max = 0.5
	bm.color = Color(1.0, 0.75, 0.45)
	butterflies.process_material = bm
	butterflies.draw_pass_1 = _butterfly_mesh()
	butterflies.position = Vector3(0, 1.2, 0)
	butterflies.emitting = false
	add_child(butterflies)

	# Bouillonnement de la vasque
	spring_bubbles = GPUParticles3D.new()
	spring_bubbles.amount = 40
	spring_bubbles.lifetime = 1.2
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 0.25
	sm.direction = Vector3(0, 1, 0)
	sm.spread = 25.0
	sm.initial_velocity_min = 1.2
	sm.initial_velocity_max = 2.0
	sm.gravity = Vector3(0, -5, 0)
	sm.scale_min = 0.5
	sm.scale_max = 1.0
	spring_bubbles.process_material = sm
	var drop := Style.sphere(0.06, 6)
	drop.material = Style.glow(Color(0.75, 0.92, 1.0), 0.8, 0.85)
	spring_bubbles.draw_pass_1 = drop
	spring_bubbles.position = Vector3(0, ground_y(0, 0) + 0.95, 0)
	spring_bubbles.emitting = false
	add_child(spring_bubbles)

func _butterfly_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s := 0.09
	for side in [-1.0, 1.0]:
		for v in [Vector3(0, 0, -s * 0.6), Vector3(side * s * 1.4, 0, -s), Vector3(side * s * 1.2, 0, s * 0.9), Vector3(0, 0, -s * 0.6), Vector3(side * s * 1.2, 0, s * 0.9), Vector3(0, 0, s * 0.5)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/butterfly.gdshader")
	mesh.surface_set_material(0, mat)
	return mesh
