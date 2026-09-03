extends GutTest

const BiteFxScript := preload("res://src/ui/components/h11_bite_fx.gd")


func _make_effect() -> Control:
	var effect := BiteFxScript.new()
	effect.size = Vector2(208, 208)
	add_child_autofree(effect)
	return effect


func test_uses_generated_fixed_pixel_sprite_sheet() -> void:
	var effect: Control = _make_effect()
	var profile: Dictionary = effect.debug_sprite_sheet_profile()
	assert_eq(profile["path"],
			"res://assets/effects/h11_bite/h11_bite_sheet.png")
	assert_eq(profile["frame_count"], 8)
	assert_eq(profile["cell_size"], Vector2i(208, 208))
	assert_eq(profile["sheet_size"], Vector2i(1664, 208))
	assert_eq(profile["open_pixel_block"], 1)
	assert_eq(profile["closed_pixel_block"], 1)
	assert_false(profile["mixed_native_pixel_grids"])
	assert_true(profile["generated_from_references"])
	assert_false(profile["runtime_shader_pixelation"],
			"像素形状必须固化在 Sprite Sheet，不再依赖运行时着色器")


func test_sprite_sheet_uses_the_approved_baked_shadow_energy_palette() -> void:
	var texture := load("res://assets/effects/h11_bite/h11_bite_sheet.png") as Texture2D
	assert_not_null(texture)
	var sheet: Image = texture.get_image()
	var audit: Dictionary = BiteFxScript.audit_sheet_palette(sheet)
	assert_eq(audit["warm_pixels"], 0, "所有帧禁止红色优势像素")
	assert_eq(int(audit["opaque_color_count"]), 3,
			"正式七帧直接沿用静态验收通过的暗芯、主体、能量三色")
	assert_true((audit["colors"] as Array).has("08070b"))
	assert_true((audit["colors"] as Array).has("17131d"))
	assert_true((audit["colors"] as Array).has("5b4968"))
	assert_eq(int(audit["semi_transparent_pixels"]), 0,
			"能量来自牙面定向亮纹，不再用半透明粉雾包裹牙床")
	assert_gte(float(audit["accent_ratio"]), 0.005,
			"保留少量紫灰能量纹理，避免黑色主体完全糊死")
	assert_lte(float(audit["accent_ratio"]), 0.08,
			"能量色必须克制，禁止重新读成大片高光")


func test_all_structural_frames_share_one_pixel_exact_centerline() -> void:
	var texture := load("res://assets/effects/h11_bite/h11_bite_sheet.png") as Texture2D
	assert_not_null(texture)
	var geometry: Dictionary = BiteFxScript.audit_sheet_geometry(texture.get_image())
	assert_lte(float(geometry["max_center_error"]), 5.0,
			"沿用已通过张开锚点时，结构帧中心最多保留其原生4像素偏差")
	assert_lte(float(geometry["max_adjacent_center_jump"]), 5.0,
			"相邻结构帧禁止横向跳动")
	assert_gte(int(geometry["open_width"]), 184)
	assert_eq(int(geometry["closed_width"]), 142,
			"命中帧严格保持bite_pixel的142像素原生有效宽度")


func test_open_frame_preserves_individual_teeth_with_tight_reference_spacing() -> void:
	var texture := load("res://assets/effects/h11_bite/h11_bite_sheet.png") as Texture2D
	assert_not_null(texture)
	var structure: Dictionary = BiteFxScript.audit_tooth_structure(texture.get_image())
	assert_gte(int(structure["open_component_count"]), 12,
			"104格逻辑分辨率下至少保留十二块独立亮牙面，不能合成整片牙床")
	assert_lte(float(structure["largest_open_component_ratio"]), 0.30,
			"任一连通块都不能占据整副牙床的大部分面积")
	assert_eq(int(structure["release_powder_components"]), 0,
			"最后一帧必须完全清空，禁止描边或粉末残留")


func test_sprite_sheet_has_seven_structural_frames_and_blank_release() -> void:
	var texture := load("res://assets/effects/h11_bite/h11_bite_sheet.png") as Texture2D
	assert_not_null(texture)
	var sheet: Image = texture.get_image()
	var frames: Array = BiteFxScript.audit_sheet_frames(sheet)
	assert_eq(frames.size(), 8)
	for index: int in 7:
		assert_gt(int((frames[index] as Dictionary)["opaque_pixels"]), 20,
				"第 %d 帧不能为空" % index)
		if index > 0:
			assert_ne((frames[index] as Dictionary)["hash"],
					(frames[index - 1] as Dictionary)["hash"],
					"相邻帧必须呈现真实动作变化")
	assert_eq(int((frames[7] as Dictionary)["opaque_pixels"]), 0,
			"闭合后直接消失，不再显示最终残留描边")


func test_approved_static_frames_are_pixel_exact_animation_anchors() -> void:
	var formal_texture := load(
			"res://assets/effects/h11_bite/h11_bite_sheet.png") as Texture2D
	var stage_texture := load(
			"res://assets/effects/h11_bite/h11_bite_stage1_sheet.png") as Texture2D
	assert_not_null(formal_texture)
	assert_not_null(stage_texture)
	if formal_texture == null or stage_texture == null:
		return
	var formal: Image = formal_texture.get_image()
	var stage: Image = stage_texture.get_image()
	var formal_open: Image = formal.get_region(Rect2i(2 * 208, 0, 208, 208))
	var formal_closed: Image = formal.get_region(Rect2i(6 * 208, 0, 208, 208))
	var approved_open: Image = stage.get_region(Rect2i(0, 0, 208, 208))
	var approved_closed: Image = stage.get_region(Rect2i(208, 0, 208, 208))
	assert_eq(formal_open.get_data(), approved_open.get_data(),
			"第2帧必须逐像素沿用已通过的张开帧")
	assert_eq(formal_closed.get_data(), approved_closed.get_data(),
			"第6帧必须逐像素沿用bite_pixel闭合帧")


func test_preimpact_jaw_gap_closes_monotonically_without_redrawing_teeth() -> void:
	var texture := load("res://assets/effects/h11_bite/h11_bite_sheet.png") as Texture2D
	assert_not_null(texture)
	if texture == null:
		return
	var sheet: Image = texture.get_image()
	var gaps: Array[int] = []
	for frame_index in range(2, 6):
		var frame: Image = sheet.get_region(Rect2i(frame_index * 208, 0, 208, 208))
		gaps.append(_center_jaw_gap(frame))
	for index in range(1, gaps.size()):
		assert_lt(gaps[index], gaps[index - 1],
				"第2到第5帧的上下颌间隙必须逐帧收紧")
	assert_eq(gaps, [36, 24, 12, 0],
			"当前节奏固定为蓄势、两段收紧、贴合预备，再落入闭合帧")


func test_playback_emits_bite_on_closed_frame_and_keeps_nearest_filter() -> void:
	var effect: Control = _make_effect()
	var playback: Dictionary = effect.debug_playback_profile()
	assert_eq(playback["closed_frame"], 6)
	assert_eq(playback["vanish_frame"], 7)
	assert_eq(playback["texture_filter"], CanvasItem.TEXTURE_FILTER_NEAREST)
	assert_eq(playback["appear_scale"], 1.0,
			"缩放过程已经固化在图集帧内，运行时不得再次缩放软化")
	assert_false(playback["baked_fragment_release"])
	assert_true(playback["blank_release_frame"],
			"闭合后切换为空白占位帧，彻底去掉最终描边")
	assert_eq(playback["close_frame_weights"],
			[0.08, 0.10, 0.25, 0.25, 0.18, 0.14])
	assert_almost_eq(float(playback["appearance_share"]), 0.18, 0.001,
			"刚出现只占少量时间，禁止慢慢显形")
	assert_almost_eq(float(playback["anticipation_share"]), 0.68, 0.001,
			"完全出现到即将合拢必须占主要展示时间")
	assert_almost_eq(float(playback["snap_share"]), 0.14, 0.001,
			"最后闭拢必须短促，形成力量感")
	assert_eq(playback["default_close_duration"], 0.22)
	assert_eq(playback["default_impact_hold"], 0.04)
	assert_eq(playback["default_release_duration"], 0.08)


func test_approved_palette_is_baked_without_runtime_recoloring() -> void:
	var effect: Control = _make_effect()
	var profile: Dictionary = effect.debug_palette_filter_profile()
	assert_false(profile["active"])
	assert_eq(profile["shader_path"], "")
	assert_eq(profile["strength"], 0.0)
	assert_false(profile["geometry_affecting"],
			"黑色化只能重映射RGB，禁止修改UV、顶点或帧结构")
	assert_true(profile["alpha_passthrough"],
			"滤镜必须原样保留母版透明度")
	assert_eq(profile["material_cue"], "shadow_energy")
	assert_true(profile["compressed_specular_contrast"],
			"缩小中间调和高光跨度，去掉钢铁式硬反射")
	assert_eq(profile["dark_outline"], Color("08070b"))
	assert_eq(profile["black_body"], Color("17131d"))
	assert_eq(profile["energy_highlight"], Color("5b4968"))
	var sprite: AnimatedSprite2D = effect.get_node("PixelBiteFrames") as AnimatedSprite2D
	assert_not_null(sprite)
	assert_null(sprite.material,
			"静态验收颜色已经烘焙，运行时不得再次压暗能量纹理")


func test_reference_inputs_remain_exact_and_generator_is_reproducible() -> void:
	var effect: Control = _make_effect()
	var source: Dictionary = effect.debug_source_profile()
	assert_eq(source["reference_open_path"], "res://res/open_pixel.png")
	assert_eq(source["reference_closed_path"], "res://res/bite_pixel.png")
	assert_eq(source["runtime_open_path"],
			"res://assets/effects/h11_bite/open_pixel.png")
	assert_eq(source["runtime_closed_path"],
			"res://assets/effects/h11_bite/bite_pixel.png")
	assert_eq(source["generator_path"], "res://tools/generate_h11_bite_sheet.gd")
	assert_true(source["source_uv_locked"])
	assert_false(source["horizontal_mirror"])
	assert_false(source["used_bounds_reframed"])
	assert_false(source["silhouette_union"])
	assert_false(source["procedural_tooth_redraw"])
	assert_true(source["direct_native_pixel_copy"])
	assert_eq(source["tooth_gap_expansion_pixels"], 0,
			"牙缝必须完全来自母版，不允许人为扩宽")
	assert_eq(source["impact_frame_reference"], "res://res/bite_pixel.png",
			"闭合撞击帧严格沿用已通过的bite_pixel")
	assert_eq(source["open_frame_reference"], "res://res/open_pixel.png",
			"完全张开帧严格沿用open_pixel，不得重新分散牙齿")
	assert_eq(source["release_frame_reference"], "none",
			"用户已否决最终描边，第7帧不得再采样任何形状母版")
	assert_true(source["release_frame_blank"])
	assert_eq(source["approved_static_sheet"],
			"res://assets/effects/h11_bite/h11_bite_stage1_sheet.png")


func _center_jaw_gap(frame: Image) -> int:
	var upper_bottom := -1
	var lower_top := frame.get_height()
	for y in frame.get_height():
		var occupied := false
		for x in frame.get_width():
			if frame.get_pixel(x, y).a > 0.01:
				occupied = true
				break
		if not occupied:
			continue
		if y < frame.get_height() / 2:
			upper_bottom = maxi(upper_bottom, y)
		else:
			lower_top = mini(lower_top, y)
	return maxi(0, lower_top - upper_bottom - 1)
