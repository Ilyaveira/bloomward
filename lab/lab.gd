extends Node3D
## Laboratoire de styles : la même scène (sans aucun élément d'énigme), rendue
## dans trois directions artistiques. Lancement : -- --lab 0|1|2 [--lab-view 0|1]
##   0 = peinture   1 = épure graphique   2 = ligne claire

const SEED := 4242
const EXTENT := 60.0

var style := 0
var view := 0
var time := 0
var noise_tex: NoiseTexture2D
var ground_tex: ImageTexture
var pal := {}
var rng := RandomNumberGenerator.new()

## 3 = « atmosphère » : formes simples, lumière et brume très travaillées (références du moodboard).
const PALETTES := [
	{ # peinture
		"c1": Color(0.24, 0.50, 0.22), "c2": Color(0.44, 0.66, 0.24), "c3": Color(0.78, 0.76, 0.32),
		"sand": Color(0.80, 0.70, 0.50), "rock": Color(0.56, 0.52, 0.48), "tip": Color(0.74, 0.86, 0.36),
		"stone": Color(0.80, 0.74, 0.64), "stone_top": Color(0.90, 0.85, 0.74), "moss": Color(0.42, 0.58, 0.26),
		"trunk": Color(0.36, 0.25, 0.20), "trunk_top": Color(0.50, 0.38, 0.28),
		"leaf_dark": [Color(0.08, 0.30, 0.26), Color(0.12, 0.34, 0.20), Color(0.30, 0.26, 0.12)],
		"leaf_light": [Color(0.50, 0.74, 0.26), Color(0.66, 0.78, 0.28), Color(0.95, 0.66, 0.26)],
		"shallow": Color(0.42, 0.80, 0.80), "deep": Color(0.10, 0.40, 0.56), "foam": Color(0.96, 0.98, 1.0),
		"flowers": [Color(1.0, 0.97, 0.90), Color(0.98, 0.60, 0.68), Color(1.0, 0.82, 0.30), Color(0.70, 0.60, 0.95)],
		"shirt": Color(0.90, 0.42, 0.30),
	},
	{ # épure
		"c1": Color(0.62, 0.78, 0.56), "c2": Color(0.69, 0.83, 0.58), "c3": Color(0.69, 0.83, 0.58),
		"sand": Color(0.98, 0.91, 0.78), "rock": Color(0.93, 0.80, 0.70), "tip": Color(0.8, 0.9, 0.6),
		"stone": Color(0.97, 0.90, 0.80), "stone_top": Color(1.0, 0.96, 0.88), "moss": Color(0.6, 0.8, 0.6),
		"trunk": Color(0.42, 0.30, 0.34), "trunk_top": Color(0.42, 0.30, 0.34),
		"leaf_dark": [Color(0.14, 0.42, 0.40), Color(0.20, 0.50, 0.42), Color(0.92, 0.48, 0.36), Color(0.95, 0.74, 0.36)],
		"leaf_light": [Color(0.24, 0.56, 0.50), Color(0.34, 0.64, 0.50), Color(0.98, 0.62, 0.46), Color(1.0, 0.84, 0.48)],
		"shallow": Color(0.56, 0.84, 0.84), "deep": Color(0.30, 0.68, 0.74), "foam": Color(1.0, 1.0, 0.98),
		"flowers": [Color(1.0, 1.0, 0.96), Color(0.98, 0.52, 0.40), Color(1.0, 0.86, 0.45)],
		"shirt": Color(0.96, 0.46, 0.34),
	},
	{ # ligne claire
		"c1": Color(0.80, 0.86, 0.58), "c2": Color(0.87, 0.89, 0.64), "c3": Color(0.94, 0.88, 0.66),
		"sand": Color(0.97, 0.92, 0.76), "rock": Color(0.94, 0.78, 0.66), "tip": Color(0.3, 0.4, 0.3),
		"stone": Color(0.96, 0.90, 0.80), "stone_top": Color(0.98, 0.94, 0.86), "moss": Color(0.7, 0.8, 0.5),
		"trunk": Color(0.80, 0.60, 0.52), "trunk_top": Color(0.80, 0.60, 0.52),
		"leaf_dark": [Color(0.48, 0.74, 0.58), Color(0.62, 0.80, 0.52), Color(0.96, 0.66, 0.50)],
		"leaf_light": [Color(0.48, 0.74, 0.58), Color(0.62, 0.80, 0.52), Color(0.96, 0.66, 0.50)],
		"shallow": Color(0.66, 0.88, 0.90), "deep": Color(0.44, 0.76, 0.84), "foam": Color(1.0, 1.0, 1.0),
		"flowers": [Color(1.0, 1.0, 1.0), Color(0.98, 0.60, 0.55), Color(1.0, 0.88, 0.45)],
		"shirt": Color(0.94, 0.45, 0.38),
	},
	{ # atmosphère
		"c1": Color(0.26, 0.50, 0.24), "c2": Color(0.40, 0.62, 0.26), "c3": Color(0.62, 0.70, 0.30),
		"sand": Color(0.82, 0.70, 0.50), "rock": Color(0.56, 0.47, 0.44), "tip": Color(0.60, 0.76, 0.30),
		"stone": Color(0.80, 0.72, 0.62), "stone_top": Color(0.92, 0.86, 0.76), "moss": Color(0.40, 0.58, 0.26),
		"trunk": Color(0.30, 0.20, 0.18), "trunk_top": Color(0.44, 0.30, 0.24),
		"leaf_dark": [Color(0.20, 0.42, 0.20), Color(0.28, 0.48, 0.18), Color(0.74, 0.36, 0.14)],
		"leaf_light": [Color(0.52, 0.72, 0.26), Color(0.66, 0.78, 0.28), Color(0.98, 0.68, 0.26)],
		"pine_dark": Color(0.07, 0.25, 0.24), "pine_light": Color(0.20, 0.46, 0.32),
		"shallow": Color(0.40, 0.78, 0.78), "deep": Color(0.08, 0.36, 0.50), "foam": Color(0.96, 0.98, 1.0),
		"flowers": [Color(1.0, 0.97, 0.90), Color(0.98, 0.62, 0.50), Color(1.0, 0.84, 0.32), Color(0.72, 0.62, 0.96)],
		"shirt": Color(0.90, 0.40, 0.28),
	},
]

func _ready() -> void:
	pal = PALETTES[style]
	rng.seed = SEED
	RenderingServer.global_shader_parameter_set("bloom_radius", 500.0)
	var n := FastNoiseLite.new()
	n.seed = SEED
	n.frequency = 0.02
	n.fractal_octaves = 4
	noise_tex = NoiseTexture2D.new()
	noise_tex.width = 512
	noise_tex.height = 512
	noise_tex.seamless = true
	noise_tex.generate_mipmaps = true
	noise_tex.noise = n
	_build_ground_tex()
	_build_environment()
	_build_ground()
	_build_water()
	_build_ruins()
	_build_rocks()
	_build_trees()
	if style == 0 or style == 3:
		_build_grass()
	elif style == 2:
		_build_ink_tufts()
	_build_flowers()
	_build_character()
	_build_post()
	_build_camera()


# ---------------------------------------------------------------- matériaux

func solid(color: Color, top: Variant = null, low: float = 0.0, high: float = 1.0, moss_amount: float = 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://lab/solid.gdshader")
	m.set_shader_parameter("mode", style)
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("color_top", color if top == null else top)
	m.set_shader_parameter("grad_low", low)
	m.set_shader_parameter("grad_high", high)
	m.set_shader_parameter("moss", pal["moss"])
	m.set_shader_parameter("moss_amount", moss_amount if style == 0 else (moss_amount * 0.6 if style == 3 else 0.0))
	m.set_shader_parameter("noise_tex", noise_tex)
	m.set_shader_parameter("brush", 0.35 if style == 0 else (0.10 if style == 3 else 0.0))
	return m

func _set_ground_params(m: ShaderMaterial) -> void:
	m.set_shader_parameter("mode", style)
	m.set_shader_parameter("ground_mode", 0 if style == 3 else style)
	m.set_shader_parameter("ground_brush", 0.35 if style == 3 else 1.0)
	m.set_shader_parameter("noise_tex", noise_tex)
	for k in ["c1", "c2", "c3", "sand"]:
		m.set_shader_parameter(k, pal[k])

func gy(x: float, z: float) -> float:
	return Terrain.height(x, z)

func _add(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	add_child(mi)
	return mi


# ---------------------------------------------------------------- décor commun

func _build_ground_tex() -> void:
	var size := 384
	var img := Image.create(size, size, false, Image.FORMAT_RGF)
	for j in size:
		for i in size:
			var x := (float(i) + 0.5) / size * 2.0 * EXTENT - EXTENT
			var z := (float(j) + 0.5) / size * 2.0 * EXTENT - EXTENT
			var wet := 1.0 if (Vector2(x, z).length() < 3.6 or Terrain.river_dist(x, z) < 4.5) else 0.0
			img.set_pixel(i, j, Color(Terrain.height(x, z), wet, 0.0))
	ground_tex = ImageTexture.create_from_image(img)

func _build_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	if style == 0:
		sm.shader = preload("res://shaders/sky.gdshader")
		sm.set_shader_parameter("cloud_tex", noise_tex)
		sm.set_shader_parameter("top_color", Color(0.26, 0.52, 0.90))
		sm.set_shader_parameter("horizon_color", Color(1.0, 0.90, 0.72))
		sm.set_shader_parameter("cloud_cover", 0.56)
		env.ambient_light_color = Color(0.50, 0.58, 0.92)
		env.ambient_light_energy = 0.62
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_white = 1.3
		env.ssao_enabled = true
		env.ssao_radius = 1.6
		env.ssao_intensity = 1.8
		env.glow_enabled = true
		env.glow_intensity = 0.5
		env.glow_bloom = 0.05
		env.fog_enabled = true
		env.fog_light_color = Color(0.80, 0.86, 0.96)
		env.fog_density = 0.003
		env.fog_aerial_perspective = 0.3
		env.fog_sky_affect = 0.0
		env.volumetric_fog_enabled = true
		env.volumetric_fog_density = 0.012
		env.volumetric_fog_albedo = Color(1.0, 0.95, 0.86)
		env.volumetric_fog_anisotropy = 0.7
		env.volumetric_fog_length = 70.0
		env.volumetric_fog_sky_affect = 0.0
		env.adjustment_enabled = true
		env.adjustment_saturation = 1.12
		env.adjustment_contrast = 1.06
		sun.rotation_degrees = Vector3(-33, -48, 0)
		sun.light_color = Color(1.0, 0.90, 0.70)
		sun.light_energy = 1.25
		sun.shadow_blur = 2.5
		sun.light_volumetric_fog_energy = 1.8
	elif style == 3:
		sm.shader = preload("res://lab/sky_d.gdshader")
		sm.set_shader_parameter("cloud_tex", noise_tex)
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		env.tonemap_white = 1.5
		env.ssao_enabled = true
		env.ssao_radius = 2.2
		env.ssao_intensity = 2.2
		env.ssao_power = 1.3
		env.glow_enabled = true
		env.glow_intensity = 0.75
		env.glow_bloom = 0.10
		env.glow_hdr_threshold = 0.95
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_sky_affect = 0.0
		env.volumetric_fog_enabled = true
		env.volumetric_fog_anisotropy = 0.78
		env.volumetric_fog_length = 90.0
		env.volumetric_fog_sky_affect = 0.0
		env.volumetric_fog_ambient_inject = 0.2
		env.adjustment_enabled = true
		sun.shadow_blur = 2.0
		sun.directional_shadow_max_distance = 110.0
		if time == 0:
			# fin d'après-midi dorée, soleil bas presque en face
			sm.set_shader_parameter("top_color", Color(0.24, 0.42, 0.72))
			sm.set_shader_parameter("mid_color", Color(0.72, 0.74, 0.80))
			sm.set_shader_parameter("horizon_color", Color(1.0, 0.80, 0.52))
			sm.set_shader_parameter("cloud_light", Color(1.0, 0.86, 0.66))
			sm.set_shader_parameter("cloud_shade", Color(0.62, 0.56, 0.74))
			sm.set_shader_parameter("cloud_cover", 0.52)
			sm.set_shader_parameter("halo", 0.9)
			env.ambient_light_color = Color(0.60, 0.62, 0.90)
			env.ambient_light_energy = 0.95
			env.fog_light_color = Color(1.0, 0.78, 0.56)
			env.fog_density = 0.0045
			env.fog_aerial_perspective = 0.5
			env.fog_sun_scatter = 0.3
			env.volumetric_fog_density = 0.011
			env.volumetric_fog_albedo = Color(1.0, 0.86, 0.68)
			env.adjustment_saturation = 1.22
			env.adjustment_contrast = 1.10
			sun.rotation_degrees = Vector3(-18, 150, 0)
			sun.light_color = Color(1.0, 0.78, 0.50)
			sun.light_energy = 1.9
			sun.light_volumetric_fog_energy = 2.2
		else:
			# plein jour, air limpide, lointains bleutés
			sm.set_shader_parameter("top_color", Color(0.16, 0.44, 0.86))
			sm.set_shader_parameter("mid_color", Color(0.50, 0.74, 0.94))
			sm.set_shader_parameter("horizon_color", Color(0.86, 0.94, 0.96))
			sm.set_shader_parameter("cloud_light", Color(1.0, 0.99, 0.96))
			sm.set_shader_parameter("cloud_shade", Color(0.72, 0.78, 0.90))
			sm.set_shader_parameter("cloud_cover", 0.56)
			sm.set_shader_parameter("halo", 0.35)
			env.ambient_light_color = Color(0.55, 0.66, 0.95)
			env.ambient_light_energy = 0.80
			env.fog_light_color = Color(0.72, 0.86, 0.96)
			env.fog_density = 0.008
			env.fog_aerial_perspective = 0.6
			env.fog_sun_scatter = 0.15
			env.volumetric_fog_density = 0.010
			env.volumetric_fog_albedo = Color(0.92, 0.97, 1.0)
			env.adjustment_saturation = 1.18
			env.adjustment_contrast = 1.06
			sun.rotation_degrees = Vector3(-44, -52, 0)
			sun.light_color = Color(1.0, 0.94, 0.80)
			sun.light_energy = 1.12
			sun.light_volumetric_fog_energy = 1.5
	elif style == 1:
		sm.shader = preload("res://lab/sky_b.gdshader")
		env.ambient_light_color = Color(0.66, 0.72, 0.88)
		env.ambient_light_energy = 1.0
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(1.0, 0.87, 0.76)
		env.fog_depth_begin = 26.0
		env.fog_depth_end = 150.0
		env.fog_depth_curve = 0.9
		env.fog_density = 0.85
		env.fog_sky_affect = 0.0
		env.fog_sun_scatter = 0.0
		env.fog_aerial_perspective = 0.0
		sun.rotation_degrees = Vector3(-15, 169, 0)
		sun.light_color = Color(1.0, 0.90, 0.72)
		sun.light_energy = 0.62
		sun.shadow_blur = 1.4
	else:
		sm.shader = preload("res://shaders/sky.gdshader")
		sm.set_shader_parameter("cloud_tex", noise_tex)
		sm.set_shader_parameter("top_color", Color(0.62, 0.84, 0.92))
		sm.set_shader_parameter("horizon_color", Color(0.99, 0.95, 0.84))
		sm.set_shader_parameter("ground_color", Color(0.95, 0.90, 0.78))
		sm.set_shader_parameter("cloud_cover", 0.60)
		env.ambient_light_color = Color(0.70, 0.66, 0.90)
		env.ambient_light_energy = 0.95
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_DEPTH
		env.fog_light_color = Color(0.97, 0.94, 0.86)
		env.fog_depth_begin = 30.0
		env.fog_depth_end = 220.0
		env.fog_density = 0.6
		env.fog_sky_affect = 0.0
		env.fog_sun_scatter = 0.0
		env.fog_aerial_perspective = 0.0
		sun.rotation_degrees = Vector3(-38, -48, 0)
		sun.light_color = Color(1.0, 0.93, 0.80)
		sun.light_energy = 0.62
		sun.shadow_blur = 0.4
	sky.sky_material = sm
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	add_child(sun)
	var vp := get_viewport()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.use_debanding = true

func _build_ground() -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://lab/ground.gdshader")
	_set_ground_params(m)
	m.set_shader_parameter("rock", pal["rock"])
	Terrain.build(self, m)

func _build_water() -> void:
	var m := ShaderMaterial.new()
	m.shader = preload("res://lab/water.gdshader")
	m.set_shader_parameter("mode", 0 if style == 3 else style)
	m.set_shader_parameter("ground_tex", ground_tex)
	m.set_shader_parameter("extent", EXTENT)
	m.set_shader_parameter("noise_tex", noise_tex)
	for k in ["shallow", "deep", "foam"]:
		m.set_shader_parameter(k, pal[k])
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0 * EXTENT, 2.0 * EXTENT)
	plane.subdivide_width = 8
	plane.subdivide_depth = 8
	var mi := _add(plane, m, Vector3(0, -0.20, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _stone() -> ShaderMaterial:
	return solid(pal["stone"], pal["stone_top"], 0.0, 3.0, 0.8)

func _cyl(top: float, bottom: float, h: float, seg: int = 28) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c

func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

func _build_ruins() -> void:
	if style == 3:
		_build_ruins_worn()
		return
	var st := _stone()
	# margelle du bassin et vasque
	for i in 14:
		var a := TAU * i / 14.0
		var p := Vector3(sin(a) * 2.75, 0.0, cos(a) * 2.75)
		if p.z < -1.5 and absf(p.x) < 1.2:
			continue
		_add(_box(Vector3(1.12, 0.42, 0.55)), st, p + Vector3(0, gy(p.x, p.z) + 0.12, 0), Vector3(0, a, rng.randf_range(-0.05, 0.05)))
	var y0 := gy(0, 0)
	_add(_cyl(0.30, 0.44, 0.75), st, Vector3(0, y0 + 0.37, 0))
	_add(_cyl(0.66, 0.36, 0.24), st, Vector3(0, y0 + 0.86, 0))
	# arche
	var ap := Vector3(-6.2, 0, -4.6)
	var ay := 0.55
	var b := Basis(Vector3.UP, ay)
	for sx in [-1.5, 1.5]:
		var p2: Vector3 = ap + b * Vector3(sx, 0, 0)
		_add(_box(Vector3(0.8, 3.4, 0.8)), st, p2 + Vector3(0, gy(p2.x, p2.z) + 1.7, 0), Vector3(0, ay, 0))
		_add(_box(Vector3(1.0, 0.3, 1.0)), st, p2 + Vector3(0, gy(p2.x, p2.z) + 0.15, 0), Vector3(0, ay, 0))
	_add(_box(Vector3(4.3, 0.6, 0.95)), st, ap + Vector3(0, gy(ap.x, ap.z) + 3.65, 0), Vector3(0, ay, 0.0))
	_add(_box(Vector3(3.6, 0.28, 1.1)), st, ap + Vector3(0, gy(ap.x, ap.z) + 4.05, 0), Vector3(0, ay, 0.0))
	# colonnes, dont une brisée
	for c in [[Vector3(5.2, 0, -5.4), 3.6, true], [Vector3(7.4, 0, -2.6), 1.5, false], [Vector3(-9.0, 0, 0.6), 2.4, false]]:
		var cp: Vector3 = c[0]
		var h: float = c[1]
		var g := gy(cp.x, cp.z)
		_add(_box(Vector3(1.05, 0.3, 1.05)), st, cp + Vector3(0, g + 0.15, 0))
		_add(_cyl(0.36, 0.42, h), st, cp + Vector3(0, g + 0.3 + h * 0.5, 0), Vector3(0, 0, 0.0 if c[2] else 0.03))
		if c[2]:
			_add(_box(Vector3(1.0, 0.26, 1.0)), st, cp + Vector3(0, g + 0.43 + h, 0))
	# fût tombé et blocs épars
	_add(_cyl(0.36, 0.38, 2.2), st, Vector3(8.6, gy(8.6, -1.2) + 0.34, -1.2), Vector3(PI / 2, 0.7, 0))
	for bl in [Vector3(-3.4, 0, -6.6), Vector3(-8.4, 0, -6.4), Vector3(3.2, 0, -7.6), Vector3(6.3, 0, 4.2)]:
		_add(_box(Vector3(rng.randf_range(0.8, 1.4), 0.5, 0.7)), st, bl + Vector3(0, gy(bl.x, bl.z) + 0.2, 0), Vector3(rng.randf_range(-0.1, 0.1), rng.randf() * TAU, 0))

func _rock_mesh(seed_value: int) -> ArrayMesh:
	if style == 3:
		return _rock_cut_mesh(seed_value)
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 20
	s.rings = 10
	var arr := s.get_mesh_arrays()
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.55
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i].normalized()
		var d := 1.0 + n.get_noise_3dv(v * 1.6) * 0.45 + n.get_noise_3dv(v * 4.0) * 0.10
		verts[i] = v * d * Vector3(1.0, 0.72, 0.9)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	st.set_smooth_group(0)
	for i in verts.size():
		st.add_vertex(verts[i])
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	return st.commit()

func _build_rocks() -> void:
	var meshes := [_rock_mesh(1), _rock_mesh(2), _rock_mesh(3)]
	var mat := solid(pal["rock"].darkened(0.08) if style == 0 else pal["rock"], pal["rock"].lightened(0.12), -0.6, 0.7, 0.9)
	var spots := [[-4.2, 3.0, 0.7], [-5.0, 3.6, 0.4], [4.6, 1.6, 0.55], [9.5, -8.5, 1.5], [-12.5, -3.0, 1.2], [1.8, 9.4, 0.5], [-2.6, -9.0, 0.9], [12.5, 4.0, 1.1], [-7.2, 8.5, 0.8]]
	for sp in spots:
		_add(meshes[rng.randi() % 3], mat, Vector3(sp[0], gy(sp[0], sp[1]) + sp[2] * 0.25, sp[1]), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * sp[2])
		if style == 3:
			# un ou deux petits blocs au pied du rocher, pour composer un groupe
			for k in rng.randi_range(1, 2):
				var a2 := rng.randf() * TAU
				var s2: float = sp[2] * rng.randf_range(0.32, 0.5)
				var x2: float = sp[0] + sin(a2) * sp[2] * 1.05
				var z2: float = sp[1] + cos(a2) * sp[2] * 1.05
				_add(meshes[rng.randi() % 3], mat, Vector3(x2, gy(x2, z2) + s2 * 0.2, z2), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * s2)
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(24.0, 44.0)
		var x := sin(a) * r
		var z := cos(a) * r
		var sc := rng.randf_range(1.2, 3.2)
		_add(meshes[rng.randi() % 3], mat, Vector3(x, gy(x, z) + sc * 0.2, z), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * sc)


# ---------------------------------------------------------------- pierres usées (rendu « atmosphère »)

## Triangle orienté vers l'extérieur d'une forme étoilée autour de l'origine.
func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (c - a).cross(b - a).dot(a + b + c) < 0.0:
		var t := b
		b = c
		c = t
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)

func _axis_coords(hh: float, b: float) -> PackedFloat32Array:
	var out := PackedFloat32Array([-hh, -hh + b])
	var span := 2.0 * (hh - b)
	var cnt := maxi(1, int(ceil(span / 0.3)))
	for k in range(1, cnt):
		out.append(-hh + b + span * k / cnt)
	out.append(hh - b)
	out.append(hh)
	return out

func _block_point(p: Vector3, h: Vector3, b: float, n: FastNoiseLite, cuts: Array, size: Vector3, taper_y: float, taper_z: float) -> Vector3:
	var q := p.clamp(-(h - Vector3.ONE * b), h - Vector3.ONE * b)
	var dir := (p - q).normalized()
	var v := q + dir * b
	v += dir * n.get_noise_3dv(v * 1.4) * 0.028
	for c in cuts:
		var over: float = v.dot(c[0]) - c[1]
		if over > 0.0:
			v -= c[0] * over
	v.x *= 1.0 + taper_y * (v.y / size.y) + taper_z * (v.z / size.z)
	return v.snapped(Vector3.ONE * 0.0005)

## Bloc de pierre taillée : arêtes adoucies, faces légèrement irrégulières, coins ébréchés.
func _block_mesh(size: Vector3, seed_value: int, chips: int = 2, taper_y: float = 0.0, taper_z: float = 0.0) -> ArrayMesh:
	var h := size * 0.5
	var smallest := minf(size.x, minf(size.y, size.z))
	var b := minf(0.04, smallest * 0.16)
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.9
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 7919 + 13
	var cuts := []
	for i in chips:
		var corner := Vector3(-1.0 if r.randf() < 0.5 else 1.0, 1.0 if r.randf() < 0.8 else -1.0, -1.0 if r.randf() < 0.5 else 1.0)
		var nrm := (corner + Vector3(r.randf_range(-0.5, 0.5), r.randf_range(-0.3, 0.6), r.randf_range(-0.5, 0.5))).normalized()
		cuts.append([nrm, (corner * h).dot(nrm) - r.randf_range(0.12, 0.30) * smallest])
	var coords := [_axis_coords(h.x, b), _axis_coords(h.y, b), _axis_coords(h.z, b)]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for w in 3:
		var u := (w + 1) % 3
		var v := (w + 2) % 3
		var cu: PackedFloat32Array = coords[u]
		var cv: PackedFloat32Array = coords[v]
		for sgn in [-1.0, 1.0]:
			for i in cu.size() - 1:
				for j in cv.size() - 1:
					var quad: Array[Vector3] = []
					for d in [[0, 0], [1, 0], [1, 1], [0, 1]]:
						var p := Vector3.ZERO
						p[u] = cu[i + d[0]]
						p[v] = cv[j + d[1]]
						p[w] = sgn * h[w]
						quad.append(_block_point(p, h, b, n, cuts, size, taper_y, taper_z))
					_tri_out(st, quad[0], quad[1], quad[2])
					_tri_out(st, quad[0], quad[2], quad[3])
	st.generate_normals()
	return st.commit()

## Solide de révolution : le profil [rayon, hauteur] part du centre du dessus, descend par l'extérieur
## et revient au centre du dessous. `flute` creuse des cannelures, `cut` tranche le dessus en biais.
func _revolve(profile: Array, segments: int, flute: float = 0.0, cut: Variant = null) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	var rows := profile.size()
	var cols := segments + 1
	var n := FastNoiseLite.new()
	n.seed = 77
	n.frequency = 2.0
	for j in rows:
		for i in cols:
			var a := TAU * (i % segments) / segments
			var r: float = profile[j][0] * (1.0 - flute * (0.5 + 0.5 * cos(a * 14.0)))
			var v := Vector3(sin(a) * r, profile[j][1], -cos(a) * r)
			if cut != null:
				v.y = minf(v.y, cut[2] + cut[0] * v.x + cut[1] * v.z + n.get_noise_2d(v.x, v.z) * 0.06)
			st.add_vertex(v)
	for j in rows - 1:
		for i in segments:
			var a0 := j * cols + i
			var a1 := a0 + 1
			var b0 := a0 + cols
			var b1 := a1 + cols
			st.add_index(a0); st.add_index(b0); st.add_index(a1)
			st.add_index(a1); st.add_index(b0); st.add_index(b1)
	st.generate_normals()
	return st.commit()

## Rocher taillé par grands plans : silhouette franche, facettes larges, arêtes adoucies.
func _rock_cut_mesh(seed_value: int) -> ArrayMesh:
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 36
	s.rings = 18
	var arr := s.get_mesh_arrays()
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = 0.5
	var r := RandomNumberGenerator.new()
	r.seed = seed_value * 104729 + 7
	var cuts := [[Vector3.DOWN, 0.30]]
	for i in 10:
		var nrm := Vector3(r.randf_range(-1.0, 1.0), r.randf_range(-0.15, 1.0), r.randf_range(-1.0, 1.0)).normalized()
		cuts.append([nrm, r.randf_range(0.52, 0.80)])
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	for i in verts.size():
		var v := verts[i].normalized()
		v *= 1.0 + n.get_noise_3dv(v * 1.5) * 0.30
		for c in cuts:
			var over: float = v.dot(c[0]) - c[1]
			if over > 0.0:
				v -= c[0] * over
		st.add_vertex((v * Vector3(1.0, 0.85, 0.9)).snapped(Vector3.ONE * 0.0005))
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	return st.commit()

var _stone_mats: Array = []
var _block_seed := 100

func _blk(size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO, chips: int = 2, taper_y: float = 0.0, taper_z: float = 0.0) -> MeshInstance3D:
	_block_seed += 1
	return _add(_block_mesh(size, _block_seed, chips, taper_y, taper_z), _stone_mats[_block_seed % 3], pos, rot)

func _column_worn(cp: Vector3, h: float, complete: bool) -> void:
	var g := gy(cp.x, cp.z)
	_blk(Vector3(1.08, 0.30, 1.08), cp + Vector3(0, g + 0.11, 0), Vector3(0, rng.randf_range(-0.05, 0.05), 0), 1)
	_add(_revolve([[0.0, 0.17], [0.40, 0.17], [0.43, 0.14], [0.48, 0.10], [0.50, 0.06], [0.50, 0.02], [0.48, 0.0], [0.0, 0.0]], 56), _stone_mats[1], cp + Vector3(0, g + 0.26, 0))
	var nd := maxi(1, int(round(h / 0.85)))
	var hd := h / nd
	var y := g + 0.43
	for d in nd:
		var rb: float = lerpf(0.385, 0.325, (y - g) / 4.2)
		var rt: float = lerpf(0.385, 0.325, (y + hd - g) / 4.2)
		var cut: Variant = null
		if not complete and d == nd - 1:
			cut = [rng.randf_range(-0.5, 0.5), rng.randf_range(0.25, 0.6), hd * 0.78]
		var mesh := _revolve([[0.0, hd], [rt - 0.025, hd], [rt, hd - 0.025], [rb, 0.025], [rb - 0.025, 0.0], [0.0, 0.0]], 56, 0.05, cut)
		_add(mesh, _stone_mats[(d + nd) % 3], cp + Vector3(rng.randf_range(-0.012, 0.012), y, rng.randf_range(-0.012, 0.012)), Vector3(0, rng.randf() * TAU, 0))
		y += hd
	if complete:
		_add(_revolve([[0.0, 0.27], [0.50, 0.27], [0.515, 0.25], [0.50, 0.21], [0.44, 0.15], [0.36, 0.07], [0.335, 0.04], [0.335, 0.0], [0.0, 0.0]], 56), _stone_mats[0], Vector3(cp.x, y, cp.z))
		_blk(Vector3(1.10, 0.20, 1.10), Vector3(cp.x, y + 0.36, cp.z), Vector3(0, rng.randf_range(-0.04, 0.04), 0), 2)

func _build_ruins_worn() -> void:
	var base: Color = pal["stone"]
	var top: Color = pal["stone_top"]
	_stone_mats = [
		solid(base.darkened(0.07), top.darkened(0.05), -0.4, 0.5, 0.55),
		solid(base, top, -0.4, 0.5, 0.8),
		solid(base.lightened(0.05), top.lightened(0.04), -0.4, 0.5, 1.0),
	]
	# margelle du bassin : pierres taillées en éventail, inégales, une ou deux déplacées
	for i in 14:
		var a := TAU * i / 14.0
		var p := Vector3(sin(a) * 2.75, 0.0, cos(a) * 2.75)
		if p.z < -1.5 and absf(p.x) < 1.2:
			continue
		var hgt := rng.randf_range(0.36, 0.50)
		var out := rng.randf_range(-0.03, 0.05) + (0.22 if i == 5 else 0.0)
		p += p.normalized() * out
		var tilt := Vector3(rng.randf_range(-0.03, 0.03) - (0.16 if i == 5 else 0.0), a + rng.randf_range(-0.03, 0.03) + (0.12 if i == 5 else 0.0), rng.randf_range(-0.04, 0.04))
		_blk(Vector3(1.17, hgt, 0.56), p + Vector3(0, gy(p.x, p.z) + hgt * 0.5 - 0.10, 0), tilt, 2 if i % 3 == 0 else 1, 0.0, 0.2)
	# vasque sur pied
	_add(_revolve([[0.0, 0.90], [0.30, 0.91], [0.52, 0.97], [0.60, 1.02], [0.67, 1.03], [0.69, 1.00], [0.66, 0.95], [0.54, 0.86], [0.38, 0.78], [0.29, 0.74], [0.26, 0.68], [0.24, 0.42], [0.27, 0.24], [0.38, 0.14], [0.45, 0.10], [0.46, 0.0], [0.0, 0.0]], 48), _stone_mats[2], Vector3(0, gy(0, 0) - 0.02, 0))
	# arche en plein cintre : piliers en assises, claveaux, clef
	var ap := Vector3(-6.2, 0, -4.6)
	var ay := 0.55
	var ab := Basis(Vector3.UP, ay)
	var pl: Vector3 = ap + ab * Vector3(-1.55, 0, 0)
	var pr: Vector3 = ap + ab * Vector3(1.55, 0, 0)
	var g0 := minf(gy(pl.x, pl.z), gy(pr.x, pr.z)) - 0.06
	for sx in [-1.55, 1.55]:
		var y := g0
		var courses := [[0.32, 1.02], [0.60, 0.80], [0.52, 0.80], [0.66, 0.80], [0.56, 0.80], [0.20, 0.94]]
		for c in courses:
			var hgt: float = c[0]
			var w: float = c[1]
			var pp: Vector3 = ap + ab * Vector3(sx + rng.randf_range(-0.018, 0.018), 0, rng.randf_range(-0.018, 0.018))
			_blk(Vector3(w + rng.randf_range(-0.02, 0.02), hgt - 0.015, w + 0.06 + rng.randf_range(-0.02, 0.02)), Vector3(pp.x, y + hgt * 0.5, pp.z), Vector3(0, ay + rng.randf_range(-0.025, 0.025), 0), 1)
			y += hgt
	var spring := g0 + 2.86
	var r_mid := 1.55
	for k in 9:
		var phi := PI * (k + 0.5) / 9.0
		var key := k == 4
		var thick := 0.92 if key else 0.80
		var depth := 0.96 if key else 0.86
		var rr := r_mid + (0.06 if key else 0.0)
		var m := _blk(Vector3(2.0 * r_mid * tan(PI / 18.0) - 0.022, thick, depth), Vector3.ZERO, Vector3.ZERO, 1, (thick / r_mid) * 0.98)
		m.basis = ab * Basis(Vector3(0, 0, 1), phi - PI / 2.0)
		m.position = ap + ab * Vector3(cos(phi) * rr, 0, 0) + Vector3(0, spring + sin(phi) * rr, 0)
	# reste de mur à côté de l'arche, bloc tombé
	for wb in [[-2.42, 0.0, 0.62, 0.92], [-2.40, 0.62, 0.50, 0.86], [-3.34, 0.0, 0.56, 0.90], [2.44, 0.0, 0.58, 0.88]]:
		var wp: Vector3 = ap + ab * Vector3(wb[0], 0, rng.randf_range(-0.03, 0.03))
		_blk(Vector3(wb[3], wb[2] - 0.015, 0.84), Vector3(wp.x, g0 + wb[1] + wb[2] * 0.5, wp.z), Vector3(0, ay + rng.randf_range(-0.04, 0.04), 0), 2)
	var fp: Vector3 = ap + ab * Vector3(-3.0, 0, 1.5)
	_blk(Vector3(0.9, 0.55, 0.8), Vector3(fp.x, gy(fp.x, fp.z) + 0.16, fp.z), Vector3(0.22, 1.9, 0.12), 3)
	# colonnes en tambours, dont une complète avec son chapiteau
	_column_worn(Vector3(5.2, 0, -5.4), 3.6, true)
	_column_worn(Vector3(7.4, 0, -2.6), 1.5, false)
	_column_worn(Vector3(-9.0, 0, 0.6), 2.4, false)
	# fût tombé, en deux tambours
	var fa := Vector3(8.6, gy(8.6, -1.2) + 0.30, -1.2)
	for d in 2:
		var mesh := _revolve([[0.0, 1.05], [0.33, 1.05], [0.355, 1.025], [0.36, 0.025], [0.335, 0.0], [0.0, 0.0]], 56, 0.05, [0.3, -0.4, 0.9] if d == 1 else null)
		var fm := _add(mesh, _stone_mats[d + 1], Vector3.ZERO)
		fm.basis = Basis(Vector3.UP, 0.7 + d * 0.16) * Basis(Vector3.RIGHT, PI / 2.0)
		fm.position = fa + Basis(Vector3.UP, 0.7) * Vector3(0, 0, -1.1 + d * 1.2) + Vector3(d * 0.12, 0, 0)
	# blocs épars à demi enfouis et petits éclats
	for bl in [Vector3(-3.4, 0, -6.6), Vector3(-8.4, 0, -6.4), Vector3(3.2, 0, -7.6), Vector3(6.3, 0, 4.2)]:
		_blk(Vector3(rng.randf_range(0.8, 1.4), 0.55, 0.72), bl + Vector3(0, gy(bl.x, bl.z) + 0.14, 0), Vector3(rng.randf_range(-0.14, 0.14), rng.randf() * TAU, rng.randf_range(-0.10, 0.10)), 3)
	var chip_meshes := [_rock_cut_mesh(11), _rock_cut_mesh(12)]
	for c in [Vector3(-7.9, 0, -3.4), Vector3(-4.6, 0, -3.3), Vector3(-5.6, 0, -2.9), Vector3(5.9, 0, -4.7), Vector3(4.5, 0, -4.9), Vector3(7.9, 0, -1.8), Vector3(9.4, 0, -0.2), Vector3(-9.6, 0, 1.3), Vector3(-8.4, 0, 0.1), Vector3(3.5, 0, 1.4), Vector3(-3.3, 0, 1.6), Vector3(-2.9, 0, -3.4)]:
		var sc := rng.randf_range(0.10, 0.24)
		_add(chip_meshes[rng.randi() % 2], _stone_mats[rng.randi() % 3], c + Vector3(0, gy(c.x, c.z) + sc * 0.15, 0), Vector3(0, rng.randf() * TAU, 0), Vector3.ONE * sc)


# ---------------------------------------------------------------- arbres

func _trunk_mesh(h: float, r0: float, bend: Vector2) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings := 8
	var sides := 12
	for j in rings + 1:
		var t := float(j) / rings
		var c := Vector3(bend.x * sin(t * PI * 0.9) , t * h, bend.y * t * t)
		var r := lerpf(r0, r0 * 0.42, t) * (1.0 + 0.35 * pow(1.0 - t, 6.0))
		for i in sides + 1:
			var a := TAU * i / sides
			st.set_normal(Vector3(cos(a), 0.15, sin(a)).normalized())
			st.add_vertex(c + Vector3(cos(a), 0, sin(a)) * r)
	for j in rings:
		for i in sides:
			var a := j * (sides + 1) + i
			var b := a + sides + 1
			st.add_index(a); st.add_index(b); st.add_index(a + 1)
			st.add_index(a + 1); st.add_index(b); st.add_index(b + 1)
	return st.commit()

func _trunk_top(h: float, bend: Vector2) -> Vector3:
	return Vector3(bend.x * sin(PI * 0.9), h, bend.y)

## Feuillage peint : des touffes de feuilles posées sur des « boules », normales arrondies.
func _canopy_painted(blobs: Array, center: Vector3, density: float = 70.0, spread: float = 0.72) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blob in blobs:
		var bc: Vector3 = blob[0]
		var br: float = blob[1]
		for k in int(density * br):
			var dir := Vector3(rng.randfn(), rng.randfn() * 0.8 + 0.25, rng.randfn()).normalized()
			var p := bc + dir * br * rng.randf_range(spread, 1.02)
			var nrm := (p - center + Vector3(0, 0.6, 0)).normalized().lerp(dir, 0.35).normalized()
			var size := br * rng.randf_range(0.55, 0.85)
			# quadrilatère tourné vers l'extérieur, avec un peu de désordre
			var facing := (dir + Vector3(rng.randfn(), rng.randfn(), rng.randfn()) * 0.45).normalized()
			var right := facing.cross(Vector3.UP if absf(facing.y) < 0.9 else Vector3.RIGHT).normalized()
			var up := right.cross(facing).normalized()
			var roll := rng.randf() * TAU
			var r2 := right * cos(roll) + up * sin(roll)
			var u2 := up * cos(roll) - right * sin(roll)
			# plus sombre en bas et à l'intérieur, plus clair au sommet
			var shade := clampf(0.5 + 0.5 * nrm.y + rng.randf_range(-0.15, 0.15), 0.0, 1.0)
			var corners := [[-1, -1], [1, -1], [1, 1], [-1, -1], [1, 1], [-1, 1]]
			for c in corners:
				st.set_normal(nrm)
				st.set_uv(Vector2(c[0] * 0.5 + 0.5, c[1] * 0.5 + 0.5))
				st.set_color(Color(shade, 0, 0))
				st.add_vertex(p + (r2 * c[0] + u2 * c[1]) * size * 0.5)
	return st.commit()

func _sphere(r: float, seg: int = 28) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = seg / 2
	return s

func _tree(pos: Vector3, scale_f: float, kind: int) -> void:
	var root := Node3D.new()
	root.position = pos + Vector3(0, gy(pos.x, pos.z) - 0.1, 0)
	root.rotation.y = rng.randf() * TAU
	root.scale = Vector3.ONE * scale_f
	add_child(root)
	var h := rng.randf_range(2.8, 3.8)
	var bend := Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.4, 0.4))
	var k: int = kind % int(pal["leaf_dark"].size())
	var dark: Color = pal["leaf_dark"][k]
	var light: Color = pal["leaf_light"][k]
	var trunk_mat := solid(pal["trunk"], pal["trunk_top"], 0.0, h)
	if style == 3 and kind % 7 >= 2:
		_pine(root, trunk_mat)
		return
	if style == 1 and kind % 3 == 0:
		# épure : cyprès en cône
		var tm := MeshInstance3D.new()
		tm.mesh = _cyl(0.07, 0.10, 1.0, 12)
		tm.material_override = trunk_mat
		tm.position.y = 0.5
		root.add_child(tm)
		var cone := MeshInstance3D.new()
		var ch := rng.randf_range(5.0, 7.0)
		cone.mesh = _cyl(0.0, 1.15, ch, 40)
		cone.material_override = solid(dark, light, -ch * 0.5, ch * 0.5)
		cone.position.y = 0.8 + ch * 0.5
		root.add_child(cone)
		return
	var trunk := MeshInstance3D.new()
	trunk.mesh = _trunk_mesh(h, 0.26 if style != 1 else 0.11, bend if style != 1 else Vector2.ZERO)
	trunk.material_override = trunk_mat
	root.add_child(trunk)
	var top := _trunk_top(h, bend if style != 1 else Vector2.ZERO)
	if style == 1:
		# épure : une sphère parfaite, ou un ovale
		var ball := MeshInstance3D.new()
		var r := rng.randf_range(1.5, 2.0)
		ball.mesh = _sphere(r, 40)
		ball.material_override = solid(dark, light, -r * 0.6, r)
		ball.position = top + Vector3(0, r * 0.7, 0)
		if kind % 3 == 2:
			ball.scale = Vector3(0.8, 1.35, 0.8)
		root.add_child(ball)
		return
	var blobs := []
	var count := 6
	for i in count:
		var a := TAU * i / (count - 1) + rng.randf_range(-0.3, 0.3)
		var off := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.9, 1.5) if i > 0 else Vector3.ZERO
		blobs.append([top + off + Vector3(0, 0.5 + rng.randf_range(-0.2, 0.5) + (0.9 if i == 0 else 0.0), 0), rng.randf_range(1.0, 1.45)])
	if style == 3:
		# Houppier en paliers : de grosses masses bosselées en couronne, de plus petites
		# au-dessus, et une frange de feuilles qui découpe la silhouette.
		var crown := rng.randf_range(2.1, 2.7)
		var masses := []
		var ring := 5
		for i in ring:
			var a2 := TAU * i / ring + rng.randf_range(-0.35, 0.35)
			masses.append([top + Vector3(cos(a2), 0, sin(a2)) * crown * rng.randf_range(0.48, 0.62) + Vector3(0, rng.randf_range(0.1, 0.6), 0), crown * rng.randf_range(0.50, 0.62)])
		for i in 3:
			var a3 := TAU * i / 3.0 + rng.randf_range(-0.5, 0.5)
			masses.append([top + Vector3(cos(a3), 0, sin(a3)) * crown * 0.26 + Vector3(0, crown * rng.randf_range(0.42, 0.55), 0), crown * rng.randf_range(0.42, 0.50)])
		masses.append([top + Vector3(rng.randf_range(-0.2, 0.2), crown * 0.86, rng.randf_range(-0.2, 0.2)), crown * 0.34])
		var mass_mat := solid(dark, light, -0.35, 0.50)
		for ms in masses:
			var s3 := MeshInstance3D.new()
			s3.mesh = _blob_mesh(rng.randi() % 4)
			s3.material_override = mass_mat
			s3.position = ms[0]
			s3.rotation.y = rng.randf() * TAU
			s3.scale = Vector3.ONE * float(ms[1])
			root.add_child(s3)
		# branches maîtresses, visibles sous le feuillage
		for i in 3:
			var target: Vector3 = masses[i * 2 % ring][0] - Vector3(0, 0.25, 0)
			var from := top * 0.72
			var br3 := MeshInstance3D.new()
			var blen := from.distance_to(target)
			br3.mesh = _cyl(0.05, 0.11, blen, 8)
			br3.material_override = trunk_mat
			br3.position = (from + target) * 0.5
			br3.basis = _basis_along(target - from)
			root.add_child(br3)
		var fringe := MeshInstance3D.new()
		var fr_blobs := []
		for ms in masses:
			fr_blobs.append([ms[0] - Vector3(0, float(ms[1]) * 0.12, 0), float(ms[1]) * 0.98])
		fringe.mesh = _canopy_painted(fr_blobs, top + Vector3(0, crown * 0.3, 0), 22.0, 0.92)
		var fm := ShaderMaterial.new()
		fm.shader = preload("res://lab/leaves.gdshader")
		fm.set_shader_parameter("leaf_tex", preload("res://lab/leaf_clump.png"))
		fm.set_shader_parameter("col_dark", dark)
		fm.set_shader_parameter("col_light", light)
		fringe.material_override = fm
		root.add_child(fringe)
	elif style == 0:
		var inner_mat := solid(dark.darkened(0.25))
		for blob in blobs:
			var s := MeshInstance3D.new()
			s.mesh = _sphere(blob[1] * 0.70, 16)
			s.material_override = inner_mat
			s.position = blob[0]
			root.add_child(s)
		var leaves := MeshInstance3D.new()
		leaves.mesh = _canopy_painted(blobs, top + Vector3(0, 0.6, 0))
		var lm := ShaderMaterial.new()
		lm.shader = preload("res://lab/leaves.gdshader")
		lm.set_shader_parameter("leaf_tex", preload("res://lab/leaf_clump.png"))
		lm.set_shader_parameter("col_dark", dark)
		lm.set_shader_parameter("col_light", light)
		leaves.material_override = lm
		root.add_child(leaves)
	else:
		# ligne claire : feuillage en nuage, que le trait d'encre vient festonner
		var cm := solid(dark)
		for blob in blobs:
			var s := MeshInstance3D.new()
			s.mesh = _sphere(blob[1], 32)
			s.material_override = cm
			s.position = blob[0]
			root.add_child(s)

var _blob_cache := {}
## Masse de feuillage : boule aplatie et bosselée (4 variantes mises en cache).
func _blob_mesh(variant: int) -> ArrayMesh:
	if _blob_cache.has(variant):
		return _blob_cache[variant]
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 24
	s.rings = 12
	var arr := s.get_mesh_arrays()
	var n := FastNoiseLite.new()
	n.seed = 900 + variant
	n.frequency = 0.9
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i].normalized()
		var d := 1.0 + n.get_noise_3dv(v * 1.5) * 0.30 + n.get_noise_3dv(v * 3.6) * 0.12
		# dessous plus plat que le dessus
		verts[i] = v * d * Vector3(1.0, 0.66 if v.y > 0.0 else 0.42, 1.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	st.set_smooth_group(0)
	for i in verts.size():
		st.add_vertex(verts[i])
	for i in idx:
		st.add_index(i)
	st.generate_normals()
	_blob_cache[variant] = st.commit()
	return _blob_cache[variant]

var _tier_cache := {}
## Étage de sapin : cône dont le bord dessine des pointes de branches qui retombent.
func _pine_tier_mesh(points: int) -> ArrayMesh:
	if _tier_cache.has(points):
		return _tier_cache[points]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(0)
	st.add_vertex(Vector3(0, 1, 0))
	var n := points * 2
	for i in n:
		var a := TAU * i / n
		var tip := i % 2 == 0
		var r := 1.0 if tip else 0.62
		st.add_vertex(Vector3(cos(a) * r, 0.0 if tip else 0.20, sin(a) * r))
	st.add_vertex(Vector3(0, 0.30, 0))
	for i in n:
		var a1 := 1 + i
		var b1 := 1 + (i + 1) % n
		st.add_index(0); st.add_index(b1); st.add_index(a1)
		st.add_index(n + 1); st.add_index(a1); st.add_index(b1)
	st.generate_normals()
	_tier_cache[points] = st.commit()
	return _tier_cache[points]

## Base dont l'axe Y suit une direction (pour poser une branche).
func _basis_along(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))

## Sapin en étages : silhouette découpée, lisible de loin.
func _pine(root: Node3D, trunk_mat: Material) -> void:
	var total := rng.randf_range(6.5, 9.5)
	var tm := MeshInstance3D.new()
	tm.mesh = _cyl(0.10, 0.22, total * 0.5, 10)
	tm.material_override = trunk_mat
	tm.position.y = total * 0.25
	root.add_child(tm)
	var tiers := 8
	var mat := solid(pal["pine_dark"], pal["pine_light"], 0.05, 0.95)
	for i in tiers:
		var t := float(i) / (tiers - 1)
		var r := lerpf(2.1, 0.40, pow(t, 0.85)) * rng.randf_range(0.88, 1.12)
		var hh := lerpf(2.2, 1.2, t)
		var cone := MeshInstance3D.new()
		cone.mesh = _pine_tier_mesh(7 + (i % 2))
		cone.material_override = mat
		cone.position = Vector3(rng.randf_range(-0.08, 0.08), lerpf(total * 0.20, total - hh, t), rng.randf_range(-0.08, 0.08))
		cone.rotation = Vector3(rng.randf_range(-0.06, 0.06), rng.randf() * TAU, rng.randf_range(-0.06, 0.06))
		cone.scale = Vector3(r, hh, r)
		root.add_child(cone)

func _build_trees() -> void:
	var spots := [[-9.0, 3.4, 1.15, 0], [-12.5, -7.0, 1.3, 1], [9.6, -7.6, 1.25, 0], [12.0, 2.6, 1.0, 2], [-3.0, -13.5, 1.2, 1],
		[4.6, -15.0, 1.1, 0], [-15.5, -13.5, 1.4, 0], [15.0, -13.0, 1.3, 1], [-17.0, 4.0, 1.2, 0], [17.5, -3.5, 1.2, 0], [8.8, 8.6, 0.95, 1]]
	for sp in spots:
		if Terrain.river_dist(sp[0], sp[1]) < 3.0:
			continue
		_tree(Vector3(sp[0], 0, sp[1]), sp[2], sp[3])
	var far_count := 240 if style == 3 else 46
	for i in far_count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(22.0, 46.0 if style != 3 else 70.0)
		var x := sin(a) * r
		var z := cos(a) * r
		if Terrain.river_dist(x, z) < 4.0:
			continue
		_tree(Vector3(x, 0, z), rng.randf_range(1.0, 1.7), rng.randi() % 7)


# ---------------------------------------------------------------- herbe et fleurs

func _meadow(count: int, radius: float, focus: Vector3) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var tries := 0
	while pts.size() < count and tries < count * 6:
		tries += 1
		var p := Vector2(rng.randfn(), rng.randfn()) * radius * 0.5 + Vector2(focus.x, focus.z)
		if p.length() > 44.0:
			continue
		var y := gy(p.x, p.y)
		if y < -0.02 or Terrain.normal(p.x, p.y).y < 0.86:
			continue
		pts.append(Vector3(p.x, y, p.y))
	return pts

func _build_grass() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 7:
		var a := TAU * b / 7.0 + rng.randf_range(-0.3, 0.3)
		var lean := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-sin(a), 0, cos(a))
		var base := lean * rng.randf_range(0.02, 0.10)
		var hh := rng.randf_range(0.30, 0.52)
		var w := rng.randf_range(0.035, 0.055)
		var prev_l := base - side * w
		var prev_r := base + side * w
		var prev_t := 0.0
		for sgm in 3:
			var t := float(sgm + 1) / 3.0
			var c := base + lean * (0.16 * t * t) + Vector3(0, hh * t, 0)
			var ww := w * (1.0 - t * 0.92)
			var l := c - side * ww
			var r := c + side * ww
			for v in [[prev_l, prev_t], [prev_r, prev_t], [r, t], [prev_l, prev_t], [r, t], [l, t]]:
				st.set_color(Color(v[1], 0, 0))
				st.set_normal(Vector3.UP)
				st.add_vertex(v[0])
			prev_l = l
			prev_r = r
			prev_t = t
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://lab/grass.gdshader")
	_set_ground_params(mat)
	mat.set_shader_parameter("tip", pal["tip"])
	mesh.surface_set_material(0, mat)
	var pts := _meadow(110000 if style == 0 else 90000, 34.0, Vector3(1.5, 0, 3.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		var s := rng.randf_range(0.8, 1.4)
		var near := smoothstep(2.6, 7.0, Vector2(pts[i].x, pts[i].z).length())
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.45, 0.8) * lerpf(0.45, 1.0, near), s)), pts[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

## Ligne claire : quelques brins dessinés « à la plume », clairsemés.
func _build_ink_tufts() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for b in 3:
		var x := (b - 1) * 0.07
		var lean := (b - 1) * 0.10
		var hh := 0.26 if b == 1 else 0.18
		for v in [Vector3(x - 0.012, 0, 0), Vector3(x + 0.012, 0, 0), Vector3(x + lean, hh, 0)]:
			st.set_normal(Vector3.UP)
			st.add_vertex(v)
	var mesh := st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.24, 0.34, 0.30)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, m)
	var pts := _meadow(1100, 30.0, Vector3(1.5, 0, 3.0))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = pts.size()
	for i in pts.size():
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, rng.randf_range(-0.6, 0.6)).scaled(Vector3.ONE * rng.randf_range(0.55, 1.0)), pts[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_flowers() -> void:
	var tall := style == 0 or style == 3
	var mesh := _sphere((0.05 if style == 3 else 0.085) if tall else 0.07, 8)
	var mat := solid(Color.WHITE)
	mat.set_shader_parameter("use_instance_color", true)
	mat.set_shader_parameter("brush", 0.0)
	mesh.material = mat
	var cols: Array = pal["flowers"]
	var transforms := []
	var colors := []
	var clusters := (44 if style == 3 else 60) if tall else 34
	for c in clusters:
		var center := Vector2(rng.randfn() * 9.0 + 1.5, rng.randfn() * 8.0 + 3.0)
		var col: Color = cols[rng.randi() % cols.size()]
		var per_cluster: int = (rng.randi_range(6, 14) if style == 3 else rng.randi_range(8, 22)) if tall else rng.randi_range(4, 9)
		for k in per_cluster:
			var p := center + Vector2(rng.randfn(), rng.randfn()) * (0.7 if tall else 0.5)
			var y := gy(p.x, p.y)
			if y < 0.0 or p.length() > 40.0:
				continue
			var hgt := rng.randf_range(0.26, 0.40) if tall else 0.07
			transforms.append(Transform3D(Basis().scaled(Vector3(1, 0.7, 1) * rng.randf_range(0.8, 1.3)), Vector3(p.x, y + hgt, p.y)))
			colors.append(col)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


# ---------------------------------------------------------------- personnage, caméra, finition

## Vêtement en surface de révolution : profil [rayon, hauteur]. Les épaules sont élargies,
## le bas ondule (plis), et `gap` ouvre le devant en s'évasant vers le bas.
func _lathe(profile: Array, segments: int, wave: float, gap := 0.0, flip := false) -> ArrayMesh:
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

func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 16
	c.rings = 6
	return c

## Personnage d'essai original : silhouette adulte à cape ouverte, lisible de loin, visage réduit à deux yeux.
func _build_caped(pos: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.position = pos
	root.rotation.y = yaw
	add_child(root)
	var cloth: Color = pal["shirt"]
	var skin := Color(0.93, 0.76, 0.62)
	var dark := Color(0.20, 0.22, 0.30)
	var linen := Color(0.90, 0.86, 0.76)
	var leather := Color(0.42, 0.28, 0.20)
	var hair := Color(0.28, 0.19, 0.15)
	var parts := [
		# jambes et bottes
		[_capsule(0.062, 0.86), solid(dark), Vector3(-0.085, 0.45, 0), Vector3.ONE],
		[_capsule(0.062, 0.86), solid(dark), Vector3(0.085, 0.45, 0), Vector3.ONE],
		[_capsule(0.074, 0.36), solid(leather), Vector3(-0.085, 0.19, 0), Vector3.ONE],
		[_capsule(0.074, 0.36), solid(leather), Vector3(0.085, 0.19, 0), Vector3.ONE],
		[_sphere(0.09, 16), solid(leather), Vector3(-0.085, 0.06, 0.04), Vector3(0.9, 0.7, 1.5)],
		[_sphere(0.09, 16), solid(leather), Vector3(0.085, 0.06, 0.04), Vector3(0.9, 0.7, 1.5)],
		# bras le long du corps, mains
		[_capsule(0.042, 0.60), solid(linen.darkened(0.06)), Vector3(-0.205, 1.14, 0.0), Vector3.ONE],
		[_capsule(0.042, 0.60), solid(linen.darkened(0.06)), Vector3(0.205, 1.14, 0.0), Vector3.ONE],
		[_sphere(0.045, 12), solid(skin), Vector3(-0.205, 0.82, 0.01), Vector3(0.85, 1.2, 1.0)],
		[_sphere(0.045, 12), solid(skin), Vector3(0.205, 0.82, 0.01), Vector3(0.85, 1.2, 1.0)],
		# ceinture
		[_sphere(0.158, 20), solid(leather.darkened(0.15)), Vector3(0, 1.01, 0), Vector3(1.0, 0.20, 0.95)],
		# cou, tête, cheveux
		[_capsule(0.046, 0.16), solid(skin.darkened(0.06)), Vector3(0, 1.525, 0.0), Vector3.ONE],
		[_sphere(0.115, 24), solid(skin), Vector3(0, 1.675, 0.008), Vector3(0.92, 1.16, 0.98)],
		[_sphere(0.125, 24), solid(hair), Vector3(0, 1.715, -0.022), Vector3(0.97, 1.02, 1.02)],
		[_sphere(0.075, 16), solid(hair), Vector3(0, 1.66, -0.125), Vector3(1.0, 1.0, 0.9)],
		# deux yeux, seuls traits du visage
		[_sphere(0.011, 10), solid(Color(0.16, 0.14, 0.18)), Vector3(-0.040, 1.668, 0.112), Vector3(1.0, 1.3, 0.5)],
		[_sphere(0.011, 10), solid(Color(0.16, 0.14, 0.18)), Vector3(0.040, 1.668, 0.112), Vector3(1.0, 1.3, 0.5)],
		# capuche rabattue dans le dos
		[_sphere(0.13, 16), solid(cloth.darkened(0.10)), Vector3(0, 1.43, -0.125), Vector3(1.05, 0.62, 0.70)],
	]
	for p in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = p[0]
		mi.material_override = p[1]
		mi.position = p[2]
		mi.scale = p[3]
		(p[1] as ShaderMaterial).set_shader_parameter("brush", 0.0)
		root.add_child(mi)
	var cape_profile := [[0.066, 1.53], [0.11, 1.508], [0.15, 1.472], [0.18, 1.42], [0.20, 1.35], [0.212, 1.22], [0.22, 1.08], [0.238, 0.90], [0.262, 0.74], [0.29, 0.58], [0.305, 0.52]]
	var garments := [
		# tunique claire
		[_lathe([[0.05, 1.50], [0.125, 1.45], [0.15, 1.30], [0.135, 1.04], [0.15, 0.94], [0.17, 0.76]], 28, 0.03), solid(linen.darkened(0.14), linen, 0.76, 1.45), 1.0],
		# cape ouverte devant : extérieur, doublure, liseré
		[_lathe(cape_profile, 44, 0.07, 0.50), solid(cloth.darkened(0.22), cloth, 0.50, 1.45), 1.0],
		[_lathe(cape_profile, 44, 0.07, 0.50, true), solid(cloth.darkened(0.42)), 0.992],
		[_lathe([[0.288, 0.59], [0.306, 0.515]], 44, 0.07, 0.50), solid(cloth.lightened(0.5)), 1.012],
		# col clair
		[_lathe([[0.062, 1.545], [0.105, 1.50], [0.15, 1.47]], 28, 0.0), solid(cloth.lightened(0.38)), 1.02],
	]
	for g in garments:
		var mi := MeshInstance3D.new()
		mi.mesh = g[0]
		mi.material_override = g[1]
		mi.scale = Vector3(g[2], 1.0, g[2])
		(g[1] as ShaderMaterial).set_shader_parameter("brush", 0.0)
		root.add_child(mi)

func _build_character() -> void:
	if style == 3:
		_build_caped(Vector3(2.6, gy(2.6, 6.4), 6.4), PI + 0.35)
		return
	var scene: PackedScene = load("res://assets/models/quaternius/characters/Female_Casual.glb")
	var ch := scene.instantiate()
	var s := 1.72 / 4.65
	ch.scale = Vector3(s, s, s)
	ch.position = Vector3(2.6, gy(2.6, 6.4), 6.4)
	ch.rotation.y = PI + 0.35
	add_child(ch)
	for node in ch.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var col := Color(0.6, 0.6, 0.6)
			if src is BaseMaterial3D:
				col = src.albedo_color
				if src.resource_name == "Shirt":
					col = pal["shirt"]
				elif src.resource_name == "Skin":
					col = col.lightened(0.15)
			if style == 1 or style == 2:
				col = col.lightened(0.22)
			var m := solid(Color(col.r, col.g, col.b))
			m.set_shader_parameter("brush", 0.0)
			mi.set_surface_override_material(i, m)
	var players := ch.find_children("*", "AnimationPlayer", true, false)
	if players.size() > 0:
		var ap: AnimationPlayer = players[0]
		for n in ap.get_animation_list():
			if n.ends_with("Idle"):
				ap.play(n)

func _build_post() -> void:
	if style == 1 or style == 3:
		return
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://lab/post_a.gdshader") if style == 0 else preload("res://lab/post_c.gdshader")
	mat.set_shader_parameter("noise_tex", noise_tex)
	mat.render_priority = 50
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = 16384.0
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_camera() -> void:
	var cam := Camera3D.new()
	add_child(cam)
	if view == 0:
		cam.fov = 58.0
		cam.position = Vector3(4.6, gy(4.6, 11.6) + 2.3, 11.6)
		cam.look_at(Vector3(-0.8, 1.3, -3.0))
	elif view == 3:
		# personnage de face
		cam.fov = 38.0
		cam.position = Vector3(1.5, gy(1.5, 3.6) + 1.25, 3.6)
		cam.look_at(Vector3(2.6, gy(2.6, 6.4) + 1.05, 6.4))
	elif view == 2:
		# gros plan sur le personnage
		cam.fov = 40.0
		cam.position = Vector3(4.4, gy(4.4, 9.6) + 1.5, 9.6)
		cam.look_at(Vector3(2.6, gy(2.6, 6.4) + 1.0, 6.4))
	else:
		cam.fov = 50.0
		cam.position = Vector3(-5.6, gy(-5.6, 9.4) + 1.7, 9.4)
		cam.look_at(Vector3(1.6, 1.5, -5.0))
	if style == 3:
		# léger flou des lointains, comme sur une maquette
		var ca := CameraAttributesPractical.new()
		ca.dof_blur_far_enabled = true
		ca.dof_blur_far_distance = 55.0
		ca.dof_blur_far_transition = 50.0
		ca.dof_blur_amount = 0.05
		cam.attributes = ca
	cam.current = true
