extends SceneTree

const TILESET_PATH := "res://assets/tilesets/qingfeng_ricefield/qingfeng_ground_tileset.tres"
const MAP_SCENE_PATH := "res://src/expedition/maps/qingfeng_ricefield_visual_map.tscn"
const Layout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")
const WIDTH: int = Layout.WIDTH
const HEIGHT: int = Layout.HEIGHT
const START: Vector2i = Layout.START
const GROUND_ROWS: Array[String] = Layout.GROUND_ROWS

const TILE_DEFS: Array[Dictionary] = [
	{
		"id": 0, "asset_id": "grass_plain", "ground_type": 0,
		"path": "res://assets/tilesets/qingfeng_ricefield/grass_ref37_ref39_plain_v1.png",
	},
	{
		"id": 1, "asset_id": "dirt_plain", "ground_type": 2,
		"path": "res://assets/tilesets/qingfeng_ricefield/dirt_ref37_ref39_plain_v1.png",
	},
	{
		"id": 2, "asset_id": "rice_golden_wave", "ground_type": 1,
		"path": "res://assets/tilesets/qingfeng_ricefield/golden_wave_ground_v1.png",
	},
	{
		"id": 3, "asset_id": "teleport_qingfeng", "ground_type": 2,
		"path": "res://assets/tilesets/qingfeng_ricefield/qingfeng_teleport_v1.png",
	},
	{
		"id": 4, "asset_id": "overlay_flower_white", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_flower_white_v1.png",
	},
	{
		"id": 5, "asset_id": "overlay_flower_yellow", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_flower_yellow_v1.png",
	},
	{
		"id": 6, "asset_id": "overlay_flower_pink", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_flower_pink_v1.png",
	},
	{
		"id": 7, "asset_id": "overlay_short_grass", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_short_grass_v1.png",
	},
	{
		"id": 8, "asset_id": "overlay_clover", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_clover_v1.png",
	},
	{
		"id": 9, "asset_id": "overlay_stone_chips_pale", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_stone_chips_pale_v1.png",
	},
	{
		"id": 10, "asset_id": "overlay_straw_fragments", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_straw_fragments_v1.png",
	},
	{
		"id": 11, "asset_id": "overlay_green_leaves", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_green_leaves_v1.png",
	},
	{
		"id": 12, "asset_id": "overlay_dirt_crack", "ground_type": -1,
		"path": "res://assets/tilesets/qingfeng_ricefield/overlays/overlay_dirt_crack_v1.png",
	},
]


func _init() -> void:
	var tile_set := _build_tile_set()
	var tile_set_error := ResourceSaver.save(tile_set, TILESET_PATH)
	if tile_set_error != OK:
		push_error("Failed to save Qingfeng TileSet: %s" % tile_set_error)
		quit(1)
		return
	var saved_tile_set := load(TILESET_PATH) as TileSet
	if saved_tile_set == null:
		push_error("Failed to reload Qingfeng TileSet")
		quit(1)
		return

	var root := Node2D.new()
	root.name = "QingfengRicefieldVisualMap"
	root.set_meta("editor_note", "在2D面板选择图层并用下方TileMap画笔刷格；Ground只管地表美术，不改变通行。")
	for layer_name: String in [
		"Ground", "GroundDetail", "LowDecoration",
		"BlockingObjects", "Containers", "MarkerGuides",
	]:
		var layer := TileMapLayer.new()
		layer.name = layer_name
		layer.tile_set = saved_tile_set
		layer.scale = Vector2(2.0, 2.0)
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.z_index = _layer_z_index(layer_name)
		root.add_child(layer)
		layer.owner = root

	var ground := root.get_node("Ground") as TileMapLayer
	for y: int in HEIGHT:
		for x: int in WIDTH:
			var cell := Vector2i(x, y)
			ground.set_cell(cell, _source_id_for_cell(cell), Vector2i.ZERO, 0)

	var packed := PackedScene.new()
	var pack_error := packed.pack(root)
	if pack_error != OK:
		push_error("Failed to pack Qingfeng visual map: %s" % pack_error)
		quit(1)
		return
	var scene_error := ResourceSaver.save(packed, MAP_SCENE_PATH)
	if scene_error != OK:
		push_error("Failed to save Qingfeng visual map: %s" % scene_error)
		quit(1)
		return
	print("Saved visual TileSet: ", TILESET_PATH)
	print("Saved visual map: ", MAP_SCENE_PATH)
	quit()


func _build_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(60, 60)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(0, "ground_type")
	tile_set.set_custom_data_layer_type(0, TYPE_INT)
	tile_set.add_custom_data_layer()
	tile_set.set_custom_data_layer_name(1, "asset_id")
	tile_set.set_custom_data_layer_type(1, TYPE_STRING)
	for definition: Dictionary in TILE_DEFS:
		var source := TileSetAtlasSource.new()
		source.texture = load(String(definition["path"])) as Texture2D
		source.texture_region_size = Vector2i(60, 60)
		source.use_texture_padding = true
		source.create_tile(Vector2i.ZERO)
		tile_set.add_source(source, int(definition["id"]))
		var tile_data := source.get_tile_data(Vector2i.ZERO, 0)
		tile_data.set_custom_data("ground_type", int(definition["ground_type"]))
		tile_data.set_custom_data("asset_id", String(definition["asset_id"]))
	return tile_set


func _source_id_for_cell(cell: Vector2i) -> int:
	if cell == START:
		return 3
	match GROUND_ROWS[cell.y][cell.x]:
		"r":
			return 2
		"d":
			return 1
		_:
			return 0


func _layer_z_index(layer_name: String) -> int:
	match layer_name:
		"Ground": return 0
		"GroundDetail": return 1
		"LowDecoration": return 2
		"BlockingObjects": return 3
		"Containers": return 4
		_: return 5
