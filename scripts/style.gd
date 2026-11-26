class_name Style
extends RefCounted
## Matériaux partagés : ombrage « toon » doux + fins contours sombres.

const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

## Matériau stylisé : couleur unie, ombrage en aplats doux, contour optionnel.
static func toon(color: Color, outline_width: float = 0.025, roughness: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	m.roughness = roughness
	if outline_width > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("width", outline_width)
		m.next_pass = o
	return m

## Matériau lumineux semi-transparent (visions, reflets d'eau).
static func glow(color: Color, energy: float = 1.5, alpha: float = 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

static func mesh_instance(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	return mi

static func sphere(r: float, segments: int = 10) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segments
	s.rings = max(4, segments / 2)
	return s

static func cylinder(top: float, bottom: float, h: float, segments: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = segments
	return c

static func box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
