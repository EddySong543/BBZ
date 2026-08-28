extends GutTest

const WarehouseStoreScript := preload("res://src/core/warehouse_store.gd")

var _test_path: String


func before_each() -> void:
	_test_path = "D:/Game/BoBoZan/_probe_output/warehouse_test_%d.cfg" % get_instance_id()
	if FileAccess.file_exists(_test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path))
	BattleSetup.p1_item_backpack.clear()


func after_each() -> void:
	BattleSetup.p1_item_backpack.clear()
	if FileAccess.file_exists(_test_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_test_path))


func test_warehouse_store_starts_empty_and_persists_item_placements() -> void:
	var store: WarehouseStore = WarehouseStoreScript.new(_test_path)
	assert_true((store.state.get("placements") as Array).is_empty(),
			"B 方案仓库首次创建必须为空")
	assert_true(store.add_item("t1_feibiao"))
	var reloaded: WarehouseStore = WarehouseStoreScript.new(_test_path)
	var placements := reloaded.state.get("placements") as Array
	assert_eq(placements.size(), 1)
	assert_eq(String(((placements[0] as Dictionary).get("item", {}) as Dictionary).get(
			"combat_id", "")), "t1_feibiao")


func test_warehouse_overlay_keeps_backpack_left_and_warehouse_right() -> void:
	var packed := load("res://src/ui/warehouse_screen.tscn") as PackedScene
	var screen := packed.instantiate() as WarehouseScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_lt(screen.backpack_panel.get_rect().end.x, screen.warehouse_panel.position.x,
			"仓库浮层必须保持背包在左、仓库在右")
	assert_eq(screen.backpack_grid.rows, 10)
	assert_eq(screen.backpack_grid.columns, 7)
	assert_eq(screen.warehouse_grid.rows, 10)
	assert_eq(screen.warehouse_grid.columns, 12)
	assert_true(screen.warehouse_empty.visible)
	assert_eq(screen.warehouse_empty.text, "仓库为空")


func test_click_transfer_is_atomic_and_syncs_battle_backpack() -> void:
	var store: WarehouseStore = WarehouseStoreScript.new(_test_path)
	assert_true(store.add_item("t1_feibiao"))
	var packed := load("res://src/ui/warehouse_screen.tscn") as PackedScene
	var screen := packed.instantiate() as WarehouseScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.set_store(store)
	var placement := (store.state.get("placements") as Array)[0] as Dictionary
	var anchor := Vector2i(placement.get("anchor", Vector2i.ZERO))
	var source_index := anchor.y * WarehouseStore.COLUMNS + anchor.x
	screen.call("_on_cell_pressed", source_index, "warehouse")
	assert_true((store.state.get("placements") as Array).is_empty())
	assert_eq(BattleSetup.p1_item_backpack, ["t1_feibiao"],
			"仓库转入背包后必须同步真实战备数据")
	screen.call("_on_cell_pressed", 0, "backpack")
	assert_eq((store.state.get("placements") as Array).size(), 1)
	assert_true(BattleSetup.p1_item_backpack.is_empty(),
			"背包转回仓库后必须从真实战备数据移除")


func test_drag_transfer_uses_target_grid_cell_and_invalid_drop_keeps_source() -> void:
	var store: WarehouseStore = WarehouseStoreScript.new(_test_path)
	assert_true(store.add_item("t3_tinglong"))
	var packed := load("res://src/ui/warehouse_screen.tscn") as PackedScene
	var screen := packed.instantiate() as WarehouseScreen
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.set_store(store)
	var placement := (store.state.get("placements") as Array)[0] as Dictionary
	var anchor := Vector2i(placement.get("anchor", Vector2i.ZERO))
	var source_index := anchor.y * WarehouseStore.COLUMNS + anchor.x
	var target_index := 2 * screen.backpack_grid.columns + 3
	screen.call("_on_item_drop_requested",
			"warehouse", source_index, "backpack", target_index, Vector2i.ZERO)
	var backpack_placement := (screen.backpack_state.get("placements") as Array)[0] \
			as Dictionary
	assert_eq(Vector2i(backpack_placement.get("anchor", Vector2i.ZERO)), Vector2i(3, 2),
			"拖动转移必须使用目标格，而不是退回自动首格")
	var before_anchor := Vector2i(backpack_placement.get("anchor", Vector2i.ZERO))
	var bottom_right := screen.backpack_grid.rows * screen.backpack_grid.columns - 1
	screen.call("_on_item_drop_requested",
			"backpack", target_index, "backpack", bottom_right, Vector2i.ZERO)
	backpack_placement = (screen.backpack_state.get("placements") as Array)[0] as Dictionary
	assert_eq(Vector2i(backpack_placement.get("anchor", Vector2i.ZERO)), before_anchor,
			"越界落位失败时必须原地保留来源物品")
