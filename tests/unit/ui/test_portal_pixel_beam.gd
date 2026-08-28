extends GutTest

const PortalPixelBeamScene := preload("res://src/ui/components/portal_pixel_beam.gd")


func test_ref44_beam_uses_connected_purple_outline_and_ivory_core() -> void:
	var beam: PortalPixelBeam = PortalPixelBeamScene.new()
	beam.size = Vector2(1920.0, 1080.0)
	add_child_autofree(beam)
	beam.set_portal_base_rect(Rect2(Vector2(720.0, 300.0), Vector2(480.0, 480.0)))
	beam.set_beam_progress(1.0)
	beam.set_anim_time(3.0)
	await get_tree().process_frame
	await get_tree().process_frame

	var contract: Dictionary = beam.get_visual_contract()
	assert_eq(contract["implementation"],
			"ref44_contoured_pixel_portal_beam")
	assert_eq(contract["reference_profile"], "ref44")
	assert_true(bool(contract["uses_ref44_contour"]))
	assert_true(bool(contract["uses_single_connected_column"]))
	assert_true(bool(contract["uses_colored_outline"]))
	assert_true(bool(contract["uses_ivory_core"]))
	assert_false(bool(contract["uses_internal_cutouts"]))
	assert_eq(contract["color_mode"], "ref44_purple_ivory")
	assert_eq(contract["outline_color"], Color("822B85"))
	assert_eq(contract["core_color"], Color("FDFCF7"))
	assert_between(float(contract["top_width_ratio"]), 0.52, 0.66)
	assert_true(bool(contract["uses_connected_profile"]))
	assert_true(bool(contract["base_spans_configured_rect"]))
	assert_false(contract.has("base_spans_nine_cells"))
	assert_false(bool(contract["uses_full_body_rect"]))
	assert_false(bool(contract["uses_flat_top_cap"]))
	assert_false(bool(contract["uses_full_frame_additive_blend"]))
	assert_true(bool(contract["uses_controlled_value_layers"]))
	assert_eq(int(contract["leading_prong_count"]), 1)
	assert_eq(int(contract["edge_tongue_count"]), 0)
	assert_eq(int(contract["silhouette_state_count"]), 6)
	assert_true(bool(contract["reaches_screen_top"]))

	var metrics_a: Dictionary = beam.get_runtime_pixel_metrics()
	beam.set_anim_time(3.25)
	await get_tree().process_frame
	await get_tree().process_frame
	var metrics_b: Dictionary = beam.get_runtime_pixel_metrics()
	var logical_body := Rect2i(contract["main_body_rect_logical"])
	assert_true(bool(metrics_a["image_ready"]))
	assert_true(bool(metrics_a["base_spans_full_rect"]))
	assert_between(float(metrics_a["base_coverage_ratio"]), 0.90, 1.0)
	assert_eq(int(metrics_a["covered_column_rows"]), logical_body.size.y)
	assert_between(float(metrics_a["column_fill_ratio"]), 0.85, 0.99)
	assert_gte(int(metrics_a["distinct_row_width_count"]), 4)
	assert_gt(int(metrics_a["bright_pixel_count"]), 0)
	assert_ne(int(metrics_a["frame_signature"]), int(metrics_b["frame_signature"]))
