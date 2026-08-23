extends SceneTree

## 无截图背包验收：主菜单内覆盖层、适配资产留白的 7×10 格面、运行时道具与关闭生命周期。


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
		var backpack_atlas := backpack_asset.texture as AtlasTexture
		if backpack_atlas == null or backpack_atlas.atlas.resource_path \
				!= "res://assets/ui/backpack/backpack_open.png" \
				or backpack_atlas.region != Rect2(128, 32, 384, 448):
			failures.append("new opened backpack asset is not the cropped container body")
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
		if not backpack_asset.size.is_equal_approx(Vector2(864, 1008)):
			failures.append("new opened backpack asset does not use the enlarged popup body: %s" \
					% backpack_asset.size)
		if grid.rows != 10 or grid.columns != 7 or grid.size != Vector2(364, 520):
			failures.append("continuous grid does not fit the backpack's tall central panel")
		if grid.position != Vector2(246, 357) \
				or not grid.cell_rect(0).size.is_equal_approx(Vector2(52, 52)):
			failures.append("grid is not optically centered on the opening with smaller square cells")
		var optical_opening_center := Vector2(428.0, 617.0)
		if grid.get_rect().get_center().distance_to(optical_opening_center) > 1.0:
			failures.append("grid center is offset from the backpack asset's usable visual opening")
		if BackpackGridView.GRID_FILL != Color("211713") \
				or BackpackGridView.GRID_CELL != Color("4B352B") \
				or BackpackGridView.GRID_CELL_LINE != Color("6A5042"):
			failures.append("grid is not using the approved shape with the restrained chestnut palette")
		if BackpackGridView.GRID_FIBER_LIGHT.a > 0.15 \
				or BackpackGridView.GRID_FIBER_DARK.a > 0.18:
			failures.append("cell fiber texture is too strong for the approved flat grid")
		if overlay.get_node_or_null("Panel/GridCornerRestore") != null \
				or ResourceLoader.exists(
						"res://assets/shaders/canvas_ui_backpack_grid_corner_restore.gdshader"):
			failures.append("obsolete corner restore can still draw a black square above the grid")
		if not "Inspector" in grid.editor_description:
			failures.append("grid position is not documented for Inspector adjustment")
		var close_button := overlay.get_node_or_null("Panel/CloseButton") as Button
		if overlay.get_node_or_null("Panel/BackButton") != null:
			failures.append("obsolete text collapse button still exists")
		if close_button == null or close_button.position != Vector2(831, 90) \
				or close_button.pressed.get_connections().is_empty() \
				or not "Inspector" in close_button.editor_description \
				or not close_button.tooltip_text.is_empty():
			failures.append("backpack close patch is missing or detached from the bag")
		if close_button.get_node_or_null("PatchShadow") != null:
			failures.append("backpack close patch still owns the rejected black shadow")
		if not close_button.flat:
			failures.append("backpack close hitbox is not decoration-free")
		for style_state: StringName in BackpackScreen.CLOSE_STYLE_STATES:
			if not close_button.has_theme_stylebox_override(style_state) \
					or not close_button.get_theme_stylebox(style_state) is StyleBoxEmpty:
				failures.append("backpack close hitbox leaks theme style: %s" % style_state)
		var patch_color_before_press := (close_button.get_node("Patch") as Polygon2D).color
		overlay.call("_on_close_down")
		if close_button.offset_transform_position != Vector2.ZERO \
				or (close_button.get_node("Patch") as Polygon2D).color != patch_color_before_press \
				or (close_button.get_node("StrokeA") as Line2D).default_color \
				!= BackpackScreen.CLOSE_PRESSED_COLOR:
			failures.append("backpack close press changes something other than the X strokes")
		overlay.call("_on_close_up")
		if close_button.offset_transform_position != Vector2.ZERO \
				or (close_button.get_node("Patch") as Polygon2D).color \
				!= BackpackScreen.CLOSE_PATCH_IDLE:
			failures.append("backpack close patch did not restore its idle color")
		await create_timer(0.22).timeout
		if not is_equal_approx((overlay.get_node("Backdrop") as ColorRect).modulate.a, 1.0) \
				or not is_equal_approx((overlay.get_node("Panel") as Control).modulate.a, 1.0):
			failures.append("backpack entrance did not settle from lift and fade")
		var panel := overlay.get_node("Panel") as Control
		var panel_shadow := overlay.get_node("PanelShadow") as TextureRect
		var initial_panel_position := panel.position
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		overlay.call("_on_panel_gui_input", press)
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(32, 18)
		overlay.call("_input", motion)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		overlay.call("_input", release)
		if not panel.position.is_equal_approx(initial_panel_position + Vector2(32, 18)) \
				or not panel_shadow.position.is_equal_approx(panel.position + Vector2(12, 12)):
			failures.append("left mouse drag did not move the bag, grid, close patch and shadow together: panel=%s expected=%s shadow=%s" % [
				panel.position,
				initial_panel_position + Vector2(32, 18),
				panel_shadow.position,
			])
		if grid.item_name_at(0) != "生锈的暗器":
			failures.append("existing battle backpack item did not map into the first cell")
		if grid.occupied_cell_count() != 1 or grid.placements.size() != 1:
			failures.append("runtime item did not become a shape placement")
		var state: Variant = overlay.get("backpack_state")
		if state == null or int(state.rows) != 10 or int(state.cols) != 7:
			failures.append("overlay did not reuse the backpack state dimensions")
		overlay.close()
		await create_timer(0.05).timeout
		if not overlay.visible or panel.modulate.a >= 1.0:
			failures.append("backpack close did not begin with a visible fade/drop phase")
		await create_timer(BackpackScreen.CLOSE_DURATION + 0.03).timeout
		if overlay.visible or overlay.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("closing animation did not stop the overlay node tree")
	var codex_overlay := menu.get_node_or_null("CodexOverlay") as Control
	if codex_overlay == null:
		failures.append("main menu did not own the shared codex overlay")
	else:
		menu.call("_on_codex_pressed")
		await process_frame
		var codex := codex_overlay.get_node_or_null("CodexScreen") as Control
		if not codex_overlay.visible or codex_overlay.process_mode != Node.PROCESS_MODE_INHERIT:
			failures.append("main-menu codex did not open as an in-scene overlay")
		if codex == null or (codex.get_node("BackButton") as Button).visible:
			failures.append("overlay codex still exposes the obsolete return bookmark")
		if codex_overlay.z_index != RenderingServer.CANVAS_ITEM_Z_MAX:
			failures.append("main-menu codex overlay is not above the world")
		if menu.get_node("MenuWorld") == null or not (menu.get_node("MenuWorld") as CanvasItem).visible:
			failures.append("opening codex replaced the main menu instead of overlaying it")
		var outside_click := InputEventMouseButton.new()
		outside_click.button_index = MOUSE_BUTTON_LEFT
		outside_click.pressed = true
		outside_click.position = Vector2(1880, 120)
		(codex.get_node("Backdrop") as TextureRect).gui_input.emit(outside_click)
		await create_timer(0.05).timeout
		if not codex_overlay.visible:
			failures.append("codex disappeared before its close animation could play")
		await create_timer(0.13).timeout
		if codex_overlay.visible or codex_overlay.process_mode != Node.PROCESS_MODE_DISABLED:
			failures.append("clicking the dim area did not close the main-menu codex overlay")
	battle_setup.p1_item_backpack.clear()
	if not failures.is_empty():
		push_error("BACKPACK_SCREEN_PROBE: %s" % "; ".join(failures))
		quit(1)
		return
	print("BACKPACK_SCREEN_PROBE_OK: host=main_menu overlays=backpack_and_codex entrance=lift_fade_180ms exit=drop_fade_140ms container=new_opened_asset_864x1008 draggable=true close=flat_all_states_x_strokes_only grid=7x10_cell52_chestnut_brown_position_inspector runtime_items=shape_placements")
	quit(0)
