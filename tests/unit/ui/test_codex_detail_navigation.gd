extends GutTest


func _make_gallery(path: String):
	var packed := load(path) as PackedScene
	var gallery = packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	return gallery


func test_hero_right_page_navigation_matches_left_row_and_tracks_selection() -> void:
	var gallery = await _make_gallery("res://src/ui/hero_gallery_screen.tscn")
	var page_navigation := gallery.get_node("PoolArea/PageNavigation") as Control
	var detail_navigation := gallery.get_node("DetailArea/DetailNavigation") as Control
	var previous := detail_navigation.get_node("PreviousItem") as Button
	var indicator := detail_navigation.get_node("ItemIndicator") as Label
	var next := detail_navigation.get_node("NextItem") as Button
	assert_eq(detail_navigation.position.y, page_navigation.position.y,
			"右页逐个浏览行与左页分页行共用同一基线")
	assert_eq(previous.text, "上一个")
	assert_eq(next.text, "下一个")
	assert_eq(indicator.text, "01 / 24")
	assert_true(previous.disabled)
	assert_false(next.disabled)
	gallery.call("_turn_detail", 1)
	assert_eq(int(gallery.get("_sel_idx")), 1)
	assert_eq(indicator.text, "02 / 24")


func test_item_right_page_navigation_is_global_across_rarity_tiers() -> void:
	var gallery = await _make_gallery("res://src/ui/item_gallery_screen.tscn")
	var detail_navigation := gallery.get_node("DetailArea/DetailNavigation") as Control
	var indicator := detail_navigation.get_node("ItemIndicator") as Label
	var total := int(gallery.call("_catalog_item_count"))
	assert_gt(total, 1)
	assert_eq(indicator.text, "%02d / %02d" % [1, total])
	var common_count := ItemCatalog.all_for_tier(1).size()
	for step: int in common_count:
		gallery.call("_turn_detail", 1)
	assert_eq(int(gallery.call("get_current_tier")), 2,
			"右页下一个可连续跨过普通末件进入稀有首件")
	assert_eq(indicator.text, "%02d / %02d" % [common_count + 1, total])


func test_item_description_keeps_a_fixed_first_line_origin() -> void:
	var gallery = await _make_gallery("res://src/ui/item_gallery_screen.tscn")
	var description := gallery.get_node("DetailArea/Description") as Label
	assert_eq(description.vertical_alignment, VERTICAL_ALIGNMENT_TOP,
			"不同换行数都从同一顶边起笔，不再整段居中造成首行跳高")
	assert_eq(description.text, description.text.strip_edges(),
			"运行时清理简介两端空白，防止数据空行改变首行基线")
	assert_lte(description.get_rect().end.y,
			gallery.get_node("DetailArea/DetailNavigation").position.y,
			"简介区为右页逐个浏览行保留独立底部空间")


func test_codex_native_text_layer_mirrors_right_navigation_without_resampling() -> void:
	var codex = await _make_gallery("res://src/ui/codex_screen.tscn")
	var hero_gallery := codex.call("get_gallery", 0) as Control
	var native_layer := codex.get_node("NativeTextLayer") as CodexNativeTextLayer
	native_layer.sync_now()
	var source_previous := hero_gallery.get_node(
			"DetailArea/DetailNavigation/PreviousItem") as Button
	var source_indicator := hero_gallery.get_node(
			"DetailArea/DetailNavigation/ItemIndicator") as Label
	var source_next := hero_gallery.get_node(
			"DetailArea/DetailNavigation/NextItem") as Button
	var previous_mirror := native_layer.mirror_for_source(source_previous)
	var indicator_mirror := native_layer.mirror_for_source(source_indicator)
	var next_mirror := native_layer.mirror_for_source(source_next)
	assert_not_null(previous_mirror)
	assert_not_null(indicator_mirror)
	assert_not_null(next_mirror)
	assert_eq(previous_mirror.get_theme_font_size("font_size"),
			CodexNativeTextLayer.PAGE_NAVIGATION_FONT_SIZE)
	assert_not_null(previous_mirror.get_node_or_null("NavArrow"))
	assert_not_null(next_mirror.get_node_or_null("NavArrow"),
			"右页逐项浏览沿用清晰原生文字层与单枚方向箭头")
