extends SceneTree

## 无截图主界面验收：运行时验证世界、完整格、角色脚锚和入口几何。

const ProfileStore := preload("res://src/core/player_profile.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	ProfileStore.save_enabled = false
	var packed := load("res://src/ui/main_menu.tscn") as PackedScene
	if packed == null:
		push_error("MAIN_MENU_PROBE: scene load failed")
		quit(1)
		return
	var menu := packed.instantiate() as Control
	root.add_child(menu)
	await process_frame
	await process_frame
	await create_timer(1.1).timeout
	var world := menu.get_node_or_null("MenuWorld") as MainMenuWorld
	if world == null:
		push_error("MAIN_MENU_PROBE: MenuWorld missing")
		quit(1)
		return
	var contract: Dictionary = world.get_visual_contract()
	var failures: Array[String] = []
	if not bool(contract.get("presentation_only", false)):
		failures.append("world is not presentation-only")
	if not bool(contract.get("uniform_grass_only", false)):
		failures.append("main menu ground is not uniform grass")
	if not bool(contract.get("click_to_move", false)):
		failures.append("main menu click-to-move is not connected")
	if not bool(contract.get("shared_movement_controller", false)):
		failures.append("main menu is not using shared expedition movement")
	if String(contract.get("movement_controller_script", "")) \
			!= "res://src/expedition/grid_movement_controller.gd":
		failures.append("main menu movement controller path mismatch")
	var view_size := Vector2(contract.get("view_size", Vector2.ZERO))
	var rendered_cell_size := Vector2(
			contract.get("rendered_cell_size", Vector2.ZERO))
	if view_size != Vector2(1920.0, 1080.0):
		failures.append("map viewport does not cover the 1920 by 1080 design frame")
	if not rendered_cell_size.is_equal_approx(Vector2(1920.0 / 19.0, 1080.0 / 11.0)):
		failures.append("rendered cell does not match the 19 by 11 full-screen grid")
	if not (view_size / rendered_cell_size).is_equal_approx(Vector2(19.0, 11.0)):
		failures.append("viewport is not a complete 19 by 11 grid")
	if world.map_view.position != Vector2.ZERO:
		failures.append("map viewport still exposes an outer fallback ring")
	var render_scale := Vector2(contract.get("render_scale", Vector2.ZERO))
	var screen_token_scale: Vector2 = world.player_token.scale * render_scale
	if not is_equal_approx(absf(screen_token_scale.x), absf(screen_token_scale.y)):
		failures.append("character aspect ratio is distorted by rectangular cells")
	var spawn_cell := Vector2i(contract.get("spawn_cell", Vector2i(-1, -1)))
	var hub_center := Vector2i(contract.get("hub_center_cell", Vector2i(-1, -1)))
	if spawn_cell != hub_center or hub_center != Vector2i(16, 9):
		failures.append("spawn is not the unique hub center cell")
	if Vector2i(contract.get("current_cell", Vector2i(-1, -1))) != spawn_cell:
		failures.append("initial cell does not match this load's spawn")
	if not world._view_position_for_cell(hub_center).is_equal_approx(view_size * 0.5):
		failures.append("hub center cell is not at exact screen center")
	if world._cell_from_view_position(Vector2(0.5, 0.5)) != Vector2i(7, 4):
		failures.append("top-left screen edge cuts a grid cell")
	if world._cell_from_view_position(Vector2(1919.5, 1079.5)) != Vector2i(25, 14):
		failures.append("bottom-right screen edge cuts a grid cell")
	if int(contract.get("ground_cell_count", 0)) != 576:
		failures.append("ground cell count mismatch")
	if int(contract.get("hero_frame_count", 0)) <= 0:
		failures.append("hero idle frames missing")
	if int(contract.get("destination_count", -1)) != 0:
		failures.append("obsolete match or expedition destination grid is still drawn")
	if int(contract.get("portal_stone_count", 0)) != 4:
		failures.append("four portal stones are not attached")
	if int(contract.get("portal_stone_shadow_count", 0)) != 4:
		failures.append("four portal stone ground shadows are not attached")
	if contract.get("portal_stone_cells", []) != [
		Vector2i(15, 8), Vector2i(17, 8),
		Vector2i(15, 10), Vector2i(17, 10),
	]:
		failures.append("portal stones are not on the four corner cells")
	var stone_positions: Array[Vector2] = []
	for stone: TextureRect in world.portal_stones:
		stone_positions.append(stone.position)
	await create_timer(0.3).timeout
	var floating_stones: int = 0
	for index: int in world.portal_stones.size():
		if not world.portal_stones[index].position.is_equal_approx(stone_positions[index]):
			floating_stones += 1
	if floating_stones == 0:
		failures.append("portal stone position idle is not running")
	for index: int in world.portal_stones.size():
		var expected_foot: Vector2 = Vector2(MainMenuWorld.PORTAL_STONE_CELLS[index]) \
				* MainMenuWorld.MAP_CELL + MainMenuWorld.TOKEN_CELL_FOOT_POINT
		var actual_foot: Vector2 = world._portal_stone_home_positions[index] \
				+ MainMenuWorld.PORTAL_STONE_FOOT_ANCHORS[index]
		if actual_foot != expected_foot:
			failures.append("portal stone foot anchor mismatch at index %d" % index)
		if world.portal_stones[index].scale != MainMenuWorld.TOKEN_ASPECT_COMPENSATION \
				* MainMenuWorld.PORTAL_STONE_SCALE:
			failures.append("portal stone scale mismatch at index %d" % index)
	world.play_portal_activation(
			MainMenuWorld.PORTAL_ENERGY_GOLD, MainMenuWorld.PORTAL_ACTIVATION_DURATION)
	if not is_zero_approx(float(world.get("_portal_energy_mix"))):
		failures.append("portal activation does not start from the white idle state")
	await create_timer(0.18).timeout
	var ordered_levels: Array[float] = world.get("_portal_energy_levels")
	if ordered_levels[0] <= 0.0 or ordered_levels[1] > 0.0 \
			or ordered_levels[2] > 0.0 or ordered_levels[3] > 0.0:
		failures.append("portal activation is not ordered TL TR BL BR")
	await create_timer(MainMenuWorld.PORTAL_ACTIVATION_DURATION).timeout
	for stone: TextureRect in world.portal_stones:
		var stone_material := stone.material as ShaderMaterial
		if stone_material.get_shader_parameter("energy_color") \
				!= MainMenuWorld.PORTAL_ENERGY_GOLD:
			failures.append("expedition gold energy is not applied")
		if not is_equal_approx(float(stone_material.get_shader_parameter("energy_mix")), 1.0):
			failures.append("portal energy mix is not active")
	world.begin_portal_search(MainMenuWorld.PORTAL_ENERGY_BLUE)
	await create_timer(1.15).timeout
	var search_levels: Array[float] = world.get("_portal_energy_levels")
	if search_levels[0] < 0.99 or search_levels[1] < 0.99 \
			or search_levels[2] < 0.99 or search_levels[3] > 0.0:
		failures.append("match search must reserve the fourth stone for connection success")
	world.complete_portal_connection(MainMenuWorld.PORTAL_ENERGY_BLUE)
	for stone: TextureRect in world.portal_stones:
		if (stone.material as ShaderMaterial).get_shader_parameter("energy_color") \
				!= MainMenuWorld.PORTAL_ENERGY_BLUE:
			failures.append("match blue energy is not applied")
	await world.play_portal_beam(MainMenuWorld.PORTAL_ENERGY_BLUE, 0.12)
	if world.portal_beam == null or not world.portal_beam.visible:
		failures.append("connected portal does not raise the center beam")
	else:
		var beam_rect := Rect2(world.portal_beam.position, world.portal_beam.size)
		var base_rect := Rect2(view_size * 0.5 - rendered_cell_size * 1.5,
				rendered_cell_size * 3.0)
		if not is_zero_approx(beam_rect.position.y) or not beam_rect.encloses(base_rect):
			failures.append("portal beam does not reach screen top from the center nine cells")
		var beam_contract: Dictionary = world.portal_beam.get_visual_contract()
		if String(beam_contract.get("implementation", "")) \
				!= "ref44_contoured_pixel_portal_beam" \
				or String(beam_contract.get("reference_profile", "")) != "ref44":
			failures.append("portal beam is not using the ref44 contour")
		if not bool(beam_contract.get("uses_subviewport", false)) \
				or not bool(beam_contract.get("uses_runtime_viewport_texture", false)) \
				or bool(beam_contract.get("uses_external_texture", true)) \
				or bool(beam_contract.get("uses_shader", true)) \
				or bool(beam_contract.get("uses_sprite_sheet", true)):
			failures.append("portal beam runtime source contract mismatch")
		if bool(beam_contract.get("uses_antialiasing", true)) \
				or bool(beam_contract.get("uses_continuous_gradients", true)) \
				or bool(beam_contract.get("uses_tapered_staircase_edges", true)):
			failures.append("portal beam is not built from hard rectangular pixels")
		if bool(beam_contract.get("uses_full_frame_additive_blend", true)) \
				or not bool(beam_contract.get("uses_controlled_value_layers", false)) \
				or not bool(beam_contract.get("uses_connected_profile", false)) \
				or not bool(beam_contract.get("uses_single_connected_column", false)) \
				or not bool(beam_contract.get("uses_colored_outline", false)) \
				or not bool(beam_contract.get("uses_ivory_core", false)) \
				or bool(beam_contract.get("uses_internal_cutouts", true)) \
				or bool(beam_contract.get("uses_full_body_rect", true)) \
				or bool(beam_contract.get("uses_flat_top_cap", true)) \
				or not bool(beam_contract.get("uses_coherent_upward_streams", false)) \
				or bool(beam_contract.get("uses_hash_mosaic", true)) \
				or bool(beam_contract.get("uses_isolated_noise_chunks", true)):
			failures.append("portal beam still uses a flat additive rectangle instead of a connected value-layered profile")
		if not bool(beam_contract.get("core_rises_before_body", false)) \
				or int(beam_contract.get("beam_stage_count", 0)) < 5 \
				or int(beam_contract.get("column_layer_count", 0)) < 4:
			failures.append("portal beam has no readable ignition, rise, sustain and peak hierarchy")
		if String(beam_contract.get("color_mode", "")) != "ref44_purple_ivory" \
				or beam_contract.get("outline_color", Color.TRANSPARENT) != Color("822B85") \
				or beam_contract.get("core_color", Color.TRANSPARENT) != Color("FDFCF7"):
			failures.append("portal beam does not use the ref44 purple and ivory palette")
		if int(beam_contract.get("leading_prong_count", 0)) != 1 \
				or int(beam_contract.get("silhouette_state_count", 0)) != 6:
			failures.append("portal beam does not have the single-front six-state silhouette")
		if Vector2i(beam_contract.get("logical_canvas_size", Vector2i.ZERO)) \
				!= Vector2i(240, 135) or int(beam_contract.get("integer_scale", 0)) != 8:
			failures.append("portal beam is not rendered at 240 by 135 then enlarged 8x")
		if not bool(beam_contract.get("texture_filter_nearest", false)):
			failures.append("portal beam runtime texture is not nearest filtered")
		if not bool(beam_contract.get("profile_spans_portal_width", false)) \
				or not bool(beam_contract.get("base_spans_nine_cells", false)):
			failures.append("portal beam profile does not span the center three columns and nine-cell base")
		var logical_base := Rect2i(beam_contract.get("logical_base_rect", Rect2i()))
		var logical_body := Rect2i(beam_contract.get("main_body_rect_logical", Rect2i()))
		if logical_body.position.x > logical_base.position.x \
				or logical_body.end.x < logical_base.end.x \
				or logical_body.position.y != 0:
			failures.append("portal beam profile bounds do not cover all three center columns to the top")
		if int(beam_contract.get("visible_upward_stream_count", 0)) <= 0 \
				or int(beam_contract.get("visible_edge_tongue_count", -1)) != 0:
			failures.append("portal beam does not use clean ref44 edges and internal upward glints")
		if not bool(beam_contract.get("reaches_screen_top", false)):
			failures.append("portal beam does not reach the top edge")
		world.set_process(false)
		world.portal_beam.set_anim_time(4.0)
		await process_frame
		await process_frame
		var beam_pixels_a: Dictionary = world.portal_beam.get_runtime_pixel_metrics()
		world.portal_beam.set_anim_time(4.25)
		await process_frame
		await process_frame
		var beam_pixels_b: Dictionary = world.portal_beam.get_runtime_pixel_metrics()
		world.set_process(true)
		if not bool(beam_pixels_a.get("image_ready", false)) \
				or not bool(beam_pixels_a.get("base_spans_full_rect", false)) \
				or float(beam_pixels_a.get("base_coverage_ratio", 0.0)) < 0.90 \
				or float(beam_pixels_a.get("base_coverage_ratio", 1.0)) > 1.0 \
				or int(beam_pixels_a.get("covered_column_rows", 0)) != logical_body.size.y \
				or float(beam_pixels_a.get("column_fill_ratio", 0.0)) < 0.85 \
				or float(beam_pixels_a.get("column_fill_ratio", 1.0)) > 0.99 \
				or int(beam_pixels_a.get("distinct_row_width_count", 0)) < 4 \
				or int(beam_pixels_a.get("bright_pixel_count", 0)) <= 0:
			failures.append("portal beam integer-canvas profile metrics are outside the approved range")
		if int(beam_pixels_a.get("frame_signature", 0)) \
				== int(beam_pixels_b.get("frame_signature", 0)):
			failures.append("portal beam sustain frame is static")
	if menu.get_node_or_null("UI/ModeMatch") != null \
			or menu.get_node_or_null("UI/ModeTower") != null:
		failures.append("obsolete dual mode buttons still exist")
	var banner_button := menu.get_node_or_null("UI/ModeBanner") as Button
	var switch_button := menu.get_node_or_null("UI/ModeSwitch") as Button
	var bottom_ui_contract: Dictionary = menu.call("get_bottom_ui_layout_contract")
	var expected_banner_rect := Rect2(Vector2(788.0, 916.0), Vector2(344.0, 108.0))
	var expected_switch_rect := Rect2(Vector2(1156.0, 934.0), Vector2(72.0, 72.0))
	if String(bottom_ui_contract.get("implementation", "")) \
			!= "single_banner_bottom_dock" \
			or bool(bottom_ui_contract.get("uses_continuous_bottom_bar", true)) \
			or not bool(bottom_ui_contract.get("uses_separate_ui_islands", false)) \
			or bool(bottom_ui_contract.get(
					"secondary_tabs_partially_offscreen", true)) \
			or not bool(bottom_ui_contract.get("reuses_battle_ui_palette", false)) \
			or bool(bottom_ui_contract.get("uses_grid_anchor_outline", true)):
		failures.append("bottom UI is not restored to the pre-grid-anchor dock")
	if banner_button == null \
			or not Rect2(banner_button.position, banner_button.size).is_equal_approx(
					expected_banner_rect):
		failures.append("single mode banner geometry mismatch")
	elif banner_button.get_node_or_null("Banner") == null \
			or (banner_button.get_node("Banner") as TextureRect).texture.resource_path \
			!= "res://assets/ui/main_menu/battle_banner.png":
		failures.append("battle banner is not the initial single mode artwork")
	else:
		var banner_art := banner_button.get_node("Banner") as TextureRect
		var banner_bg := banner_button.get_node_or_null("Bg") as ColorRect
		if banner_bg == null \
				or (banner_bg.material as ShaderMaterial).shader.resource_path \
				!= "res://assets/shaders/canvas_button_jelly.gdshader" \
				or not is_equal_approx(float((banner_bg.material as ShaderMaterial) \
						.get_shader_parameter("aspect")), expected_banner_rect.size.aspect()) \
				or (banner_bg.material as ShaderMaterial).get_shader_parameter("fill_top") \
				!= Color(0.92, 0.87, 0.70):
			failures.append("single mode banner does not reuse the pixel button frame")
		if banner_button.get_node_or_null("BottomShadow") == null \
				or banner_button.get_node_or_null("BannerShadow") != null:
			failures.append("single mode banner frame shadow contract mismatch")
		var frame_overlay := banner_button.get_node_or_null("FrameOverlay") as ColorRect
		if banner_bg.visible or frame_overlay == null \
				or (frame_overlay.material as ShaderMaterial).shader.resource_path \
				!= "res://assets/shaders/canvas_button_jelly.gdshader" \
				or not is_zero_approx(float((frame_overlay.material as ShaderMaterial) \
						.get_shader_parameter("fill_alpha"))) \
				or banner_button.get_child(banner_button.get_child_count() - 1) \
				!= frame_overlay:
			failures.append("single mode banner does not use a visible frame over a filled artwork")
		if banner_art.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_COVERED \
				or banner_art.offset_left != 0.0 or banner_art.offset_top != 0.0 \
				or banner_art.offset_right != 0.0 or banner_art.offset_bottom != 0.0 \
				or banner_art.material == null \
				or (banner_art.material as ShaderMaterial).shader.resource_path \
				!= "res://assets/shaders/canvas_mode_banner_frame.gdshader":
			failures.append("single mode banner artwork is not clipped into its pixel frame")
	if switch_button == null \
			or not Rect2(switch_button.position, switch_button.size).is_equal_approx(
					expected_switch_rect):
		failures.append("mode carousel rail geometry mismatch")
	else:
		var carousel_glyph := switch_button.get_node_or_null("CarouselGlyph") as Control
		if switch_button.get_node_or_null("Icon") != null or carousel_glyph == null \
				or int(carousel_glyph.get("selected_index")) != 0:
			failures.append("mode carousel rail still uses the rejected switch icon")
		switch_button.pressed.emit()
		if (banner_button.get_node("Banner") as TextureRect).texture.resource_path \
				!= "res://assets/ui/main_menu/expedition_banner.png":
			failures.append("mode switch does not replace the single banner artwork")
		if carousel_glyph != null and int(carousel_glyph.get("selected_index")) != 1:
			failures.append("mode carousel direction and page state did not update")
	if menu.get_node_or_null("UI/NavShop") != null:
		failures.append("shop placeholder still exists")
	var backpack_button := menu.get_node_or_null("UI/NavBackpack") as Button
	if backpack_button == null or not backpack_button.size.is_equal_approx(Vector2(108, 108)) \
			or backpack_button.position != Vector2(1640.0, 916.0) \
			or backpack_button.get_node_or_null("GridAnchor") != null:
		failures.append("backpack dock entry missing")
	elif (backpack_button.get_node("Icon") as TextureRect).texture.resource_path \
			!= "res://assets/ui/icons/backpack.png":
		failures.append("backpack dock entry does not use imported asset")
	var codex_button := menu.get_node_or_null("UI/NavHeroes") as Button
	if codex_button == null or codex_button.position != Vector2(48.0, 916.0) \
			or codex_button.get_node_or_null("GridAnchor") != null:
		failures.append("codex entry is not at bottom left")
	var warehouse_button := menu.get_node_or_null("UI/NavWarehouse") as Button
	if warehouse_button == null or warehouse_button.position != Vector2(1772.0, 916.0) \
			or warehouse_button.get_node_or_null("GridAnchor") != null:
		failures.append("warehouse placeholder is not the rightmost bottom entry")
	if codex_button != null and codex_button.position.y + codex_button.size.y > view_size.y:
		failures.append("pre-grid-anchor codex button is not fully visible")
	var net_button := menu.get_node_or_null("UI/NetLobbyButton") as Button
	if net_button == null or net_button.position != Vector2(1652.0, 108.0):
		failures.append("online battle entry is not below settings")
	for path: String in ["UI/ModeBanner", "UI/ModeSwitch", "UI/NavHeroes",
			"UI/NavBackpack", "UI/NavWarehouse"]:
		var dock_button := menu.get_node(path) as Button
		if dock_button.text != "" or dock_button.get_node_or_null("Caption") != null:
			failures.append("dock button is not icon-only: %s" % path)
	var target: Vector2i = spawn_cell + Vector2i.LEFT * 2
	var hover := InputEventMouseMotion.new()
	hover.position = world._view_position_for_cell(target)
	world._on_map_view_gui_input(hover)
	await process_frame
	var route_contract: Dictionary = GridRoutePreview.get_style_contract()
	if String(route_contract.get("implementation", "")) \
			!= "full_route_alternating_footprint_stream":
		failures.append("main menu route preview is not using the full-route footprint stream")
	if not bool(route_contract.get("uses_footprints", false)) \
			or not bool(route_contract.get("alternates_left_right", false)) \
			or not bool(route_contract.get("covers_full_route", false)) \
			or not bool(route_contract.get("count_scales_with_route_length", false)) \
			or bool(route_contract.get("uses_fixed_visible_count", true)) \
			or bool(route_contract.get("uses_footprint_count_cap", true)) \
			or not bool(route_contract.get("moves_continuously_forward", false)) \
			or float(route_contract.get("stream_speed_cells_per_second", 1.0)) >= 0.55 \
			or not bool(route_contract.get("uses_distance_sampling", false)) \
			or bool(route_contract.get("uses_loop_gap", true)) \
			or bool(route_contract.get("fills_every_path_cell", true)) \
			or bool(route_contract.get("lights_individual_footprints", true)) \
			or bool(route_contract.get("uses_ground_shadow", true)) \
			or bool(route_contract.get("uses_inner_core", true)) \
			or bool(route_contract.get("uses_glow", true)) \
			or bool(route_contract.get("uses_inset_edge_bars", true)) \
			or bool(route_contract.get("uses_arrows", true)) \
			or bool(route_contract.get("uses_continuous_ribbon", true)) \
			or bool(route_contract.get("uses_chevrons", true)) \
			or bool(route_contract.get("uses_dashes", true)) \
			or bool(route_contract.get("uses_nodes", true)) \
			or bool(route_contract.get("uses_toe_details", true)):
		failures.append("main menu route preview still uses a rejected route family")
	if Vector2i(world.get("_hovered_cell")) != target \
			or (world.get("_hovered_path") as Array).is_empty():
		failures.append("main menu footprint stream did not receive the hover route")
	var runtime_route_cells: Array[Vector2i] = [Vector2i(world.get("_current_cell"))]
	for path_cell: Vector2i in world.get("_hovered_path"):
		runtime_route_cells.append(path_cell)
	var runtime_footprints_a: Array[Dictionary] = \
			GridRoutePreview.build_stream_footprints(
					runtime_route_cells, MainMenuWorld.MAP_CELL, 0.0)
	var runtime_footprints_b: Array[Dictionary] = \
			GridRoutePreview.build_stream_footprints(
					runtime_route_cells, MainMenuWorld.MAP_CELL, 0.25)
	if runtime_footprints_a.is_empty():
		failures.append("main menu full-route footprint stream is empty")
	if runtime_footprints_a.size() != runtime_footprints_b.size():
		failures.append("main menu footprint stream changes count during ordinary motion")
	var long_route_cells: Array[Vector2i] = []
	for route_index: int in 10:
		long_route_cells.append(Vector2i(route_index, 0))
	if GridRoutePreview.build_stream_footprints(
			long_route_cells, MainMenuWorld.MAP_CELL, 0.0).size() \
			<= runtime_footprints_a.size():
		failures.append("main menu footprint count does not scale with route length")
	for index: int in mini(runtime_footprints_a.size(), runtime_footprints_b.size()):
		var footprint_a: Dictionary = runtime_footprints_a[index]
		var footprint_b: Dictionary = runtime_footprints_b[index]
		var parts: Array[PackedVector2Array] = footprint_a["parts"]
		if parts.size() != 2 or parts[0].size() != 6 or parts[1].size() != 4:
			failures.append("main menu footprint does not use the forefoot and heel sole")
			break
		if int(footprint_a["stream_index"]) != int(footprint_b["stream_index"]) \
				or float(footprint_b["path_distance"]) \
				<= float(footprint_a["path_distance"]):
			failures.append("main menu footprint train does not move continuously forward")
			break
		if String(footprint_a["side"]) \
				!= ("left" if int(footprint_a["stream_index"]) % 2 == 0 else "right"):
			failures.append("main menu footprint stream does not alternate left and right")
			break
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = world._view_position_for_cell(target)
	world._on_map_view_gui_input(click)
	var movement_deadline: int = Time.get_ticks_msec() + 3000
	while Vector2i(world.get("_current_cell")) != target \
			and Time.get_ticks_msec() < movement_deadline:
		await process_frame
	if Vector2i(world.get("_current_cell")) != target:
		failures.append("main menu click route did not reach target")
	while world._grid_movement.is_moving() and Time.get_ticks_msec() < movement_deadline:
		await process_frame
	if world._grid_movement.is_moving():
		failures.append("main menu click route did not visually settle")
	var keyboard_origin: Vector2i = Vector2i(world.get("_current_cell"))
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_W
	key_event.pressed = true
	Input.parse_input_event(key_event)
	await process_frame
	if Vector2i(world.get("_current_cell")) != keyboard_origin:
		failures.append("main menu still accepts WASD movement")
	contract["mouse_only_verified"] = Vector2i(world.get("_current_cell")) == keyboard_origin
	contract["final_cell"] = Vector2i(world.get("_current_cell"))
	contract["bottom_ui"] = bottom_ui_contract
	if not failures.is_empty():
		push_error("MAIN_MENU_PROBE: %s" % "; ".join(failures))
		quit(1)
		return
	print("MAIN_MENU_PROBE_OK ", JSON.stringify(contract))
	quit(0)
