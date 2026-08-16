@tool
extends Control

## Draws one complete wheat texture on a subdivided mesh. Wind materials move
## the real mesh vertices; no duplicate texture or alpha-split layer is needed.
@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
@export_range(4, 160, 1) var mesh_columns: int = 32:
	set(value):
		mesh_columns = maxi(value, 4)
		_mesh_signature = Vector3i.ZERO
		queue_redraw()
@export_range(2, 48, 1) var mesh_rows: int = 10:
	set(value):
		mesh_rows = maxi(value, 2)
		_mesh_signature = Vector3i.ZERO
		queue_redraw()

var _mesh: ArrayMesh = null
var _mesh_signature: Vector3i = Vector3i.ZERO


func _ready() -> void:
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_mesh_signature = Vector3i.ZERO
		queue_redraw()


func _draw() -> void:
	if texture == null or size.x <= 0.0 or size.y <= 0.0:
		return
	_ensure_mesh()
	if _mesh != null:
		draw_mesh(_mesh, texture)


func _ensure_mesh() -> void:
	var signature := Vector3i(
			roundi(size.x),
			roundi(size.y),
			mesh_columns * 100 + mesh_rows)
	if _mesh != null and signature == _mesh_signature:
		return
	_mesh_signature = signature
	_mesh = _build_grid_mesh(size, mesh_columns, mesh_rows)


func _build_grid_mesh(
		draw_size: Vector2,
		columns: int,
		rows: int) -> ArrayMesh:
	var vertex_count := (columns + 1) * (rows + 1)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	vertices.resize(vertex_count)
	uvs.resize(vertex_count)
	for row: int in range(rows + 1):
		var v := float(row) / float(rows)
		for column: int in range(columns + 1):
			var u := float(column) / float(columns)
			var index := row * (columns + 1) + column
			vertices[index] = Vector3(draw_size.x * u, draw_size.y * v, 0.0)
			uvs[index] = Vector2(u, v)

	var indices := PackedInt32Array()
	indices.resize(columns * rows * 6)
	var write_index := 0
	for row: int in range(rows):
		for column: int in range(columns):
			var top_left := row * (columns + 1) + column
			var top_right := top_left + 1
			var bottom_left := top_left + columns + 1
			var bottom_right := bottom_left + 1
			indices[write_index] = top_left
			indices[write_index + 1] = bottom_left
			indices[write_index + 2] = top_right
			indices[write_index + 3] = top_right
			indices[write_index + 4] = bottom_left
			indices[write_index + 5] = bottom_right
			write_index += 6

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result
