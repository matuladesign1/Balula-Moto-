class_name MeshBatch
extends RefCounted
## Fusionne beaucoup de boîtes colorées dans UN SEUL maillage.
## Moins d'objets à dessiner = jeu plus fluide sur les téléphones Android modestes.

var _verts := PackedVector3Array()
var _norms := PackedVector3Array()
var _cols := PackedColorArray()

# Les 6 faces d'une boîte : indices des 4 coins (voir add_box) et direction de la normale.
const _FACES := [
	[[4, 5, 7, 6], Vector3(1, 0, 0)],
	[[0, 1, 3, 2], Vector3(-1, 0, 0)],
	[[2, 3, 7, 6], Vector3(0, 1, 0)],
	[[0, 1, 5, 4], Vector3(0, -1, 0)],
	[[1, 3, 7, 5], Vector3(0, 0, 1)],
	[[0, 2, 6, 4], Vector3(0, 0, -1)],
]


## Ajoute une boîte (centre, taille, couleur, rotation autour de l'axe vertical en radians).
func add_box(center: Vector3, size: Vector3, color: Color, yaw: float = 0.0) -> void:
	var h := size * 0.5
	var b := Basis(Vector3.UP, yaw)
	var corners: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				corners.append(center + b * Vector3(h.x * sx, h.y * sy, h.z * sz))
	for face in _FACES:
		var idx: Array = face[0]
		var n: Vector3 = b * (face[1] as Vector3)
		_tri(corners[idx[0]], corners[idx[1]], corners[idx[2]], n, color)
		_tri(corners[idx[0]], corners[idx[2]], corners[idx[3]], n, color)


func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, color: Color) -> void:
	# Godot dessine l'avant d'un triangle quand ses sommets tournent dans le sens des aiguilles
	# d'une montre vu de l'extérieur : on inverse l'ordre si nécessaire.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	_verts.append(a)
	_verts.append(b)
	_verts.append(c)
	for i in 3:
		_norms.append(n)
		_cols.append(color)


func is_empty() -> bool:
	return _verts.is_empty()


func build(material: Material) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _verts.is_empty():
		return mesh
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _norms
	arrays[Mesh.ARRAY_COLOR] = _cols
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh


static func make_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	return m
