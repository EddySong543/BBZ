extends SceneTree

## 无截图背包验收：主菜单内覆盖层、连续 6×6 格面、运行时道具映射与关闭生命周期。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var battle_setup := root.get_node("BattleSetup")
	battle_setup.p1_item_backpack.clear()
	battle_setup.p1_item_backpack.append("t1_feibiao")
	var packed := load("res://src/ui/main_menu.tscn") as PackedScene
	if packed == null:
		push_error("BACKPACK_SCREEN_PROBE: main menu failed to load")
		quit(1)
		return
	var menu := packed.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame
	var failures: Array[String] = []
	var overlay := menu.get_node_or_null("BackpackOverlay") as BackpackScreen
	if overlay == null:
		failures.append("main menu did not own a backpack overlay")
	else:
		if overlay.visible or overlay.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("closed overlay did not start hidden and disabled")
		overlay.open()
		await process_frame
		var grid := overlay.get_node("Panel/Grid") as BackpackGridView
		var backpack_asset := overlay.get_node("Panel/BackpackAsset") as TextureRect
		var player_token := menu.find_child("PlayerToken", true, false) as CanvasItem
		if not overlay.visible or overlay.process_mode != Node.PROCESS_MODE_INHERIT:
			failures.append("overlay did not open over the existing main menu")
		if backpack_asset.texture == null or backpack_asset.texture.resource_path \
				!= "res://assets/ui/icons/backpack.png":
			failures.append("generated backpack asset is not the container body")
		if overlay.get_node_or_null("Panel/TopFlap") != null \
				or overlay.get_node_or_null("Panel/BottomPocket") != null:
			failures.append("overlay still reconstructs the bag from code shapes")
		if overlay.z_index != RenderingServer.CANVAS_ITEM_Z_MAX \
				or (player_token != null and overlay.z_index <= player_token.z_index):
			failures.append("overlay does not render above the player and portal stones")
		var backdrop_alpha := (overlay.get_node("Backdrop") as ColorRect).color.a
		if backdrop_alpha < 0.15 or backdrop_alpha > 0.45:
			failures.append("popup backdrop does not preserve a readable main-menu context")
		var menu_world := menu.get_node_or_null("MenuWorld") as CanvasItem
		if menu_world != null and not menu_world.visible:
			failures.append("opening backpack hides the main-menu world instead of overlaying it")
		if grid.rows != 6 or grid.columns != 6 or grid.size != Vector2(528, 528):
			failures.append("continuous grid is not a pixel-aligned 6 by 6 surface")
		if grid.item_name_at(0) != "生锈的暗器":
			failures.append("existing battle backpack item did not map into the first cell")
		if grid.occupied_cell_count() != 1 or grid.placements.size() != 1:
			failures.append("runtime item did not become a shape placement")
		var state: Variant = overlay.get("backpack_state")
		if state == null or int(state.rows) != 6 or int(state.cols) != 6:
			failures.append("overlay did not reuse the backpack state dimensions")
		overlay.close()
		if overlay.visible or overlay.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("closing overlay did not stop its node tree")
	battle_setup.p1_item_backpack.clear()
	if not failures.is_empty():
		push_error("BACKPACK_SCREEN_PROBE: %s" % "; ".join(failures))
		quit(1)
		return
	print("BACKPACK_SCREEN_PROBE_OK: host=main_menu overlay=translucent_popup container=generated_asset_896px layer=above_world grid=front_integrated_6x6_528px runtime_items=shape_placements")
	quit(0)
