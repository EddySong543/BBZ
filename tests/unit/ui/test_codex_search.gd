extends GutTest

const CODEX_PATH := "res://src/ui/codex_screen.tscn"


func _make_codex() -> CodexScreen:
	var packed := load(CODEX_PATH) as PackedScene
	assert_not_null(packed)
	var codex := packed.instantiate() as CodexScreen
	assert_almost_eq(codex.search_cat_easter_egg_chance, 0.10, 0.0001,
			"搜不到时的猫猫彩蛋默认有 10% 概率")
	codex.search_cat_easter_egg_chance = 0.0
	add_child_autofree(codex)
	return codex


func test_search_preserves_manual_geometry_and_curves_toward_the_book_spine() -> void:
	var codex := _make_codex()
	await get_tree().process_frame
	var search_control := codex.get_node("SearchControl") as Control
	var search_button := search_control.get_node("SearchButton") as Button
	var search_frame := search_control.get_node("SearchFieldFrame") as CodexSearchFieldFrame
	var search_input := search_control.get_node("SearchInput") as LineEdit
	var curved_text := search_control.get_node("SearchCurvedText") as CodexSearchCurvedText
	var clear_button := search_control.get_node("SearchClearButton") as Button
	assert_eq((search_button.get_node("Lens") as Line2D).position, Vector2(28.0, 5.0),
			"保留用户手调后的放大镜位置")
	assert_eq((search_button.get_node("Handle") as Line2D).position, Vector2(28.0, 5.0))
	assert_eq(search_input.position, Vector2(77.0, 5.0),
			"保留用户手调后的搜索文字位置")
	assert_eq(search_input.size, Vector2(603.0, 33.0))
	assert_eq(search_frame.position, search_input.position)
	assert_eq(search_frame.size, search_input.size,
			"弧形框与真实输入点击区完全重合")
	assert_eq(curved_text.position, search_input.position)
	assert_eq(curved_text.size, search_input.size,
			"曲线文字层与真实输入点击区完全重合")
	var top_curve: PackedVector2Array = search_frame.debug_top_curve()
	var bottom_curve: PackedVector2Array = search_frame.debug_bottom_curve()
	assert_eq(top_curve.size(), 13)
	assert_eq(bottom_curve.size(), 13)
	assert_lt(top_curve[6].y, top_curve[0].y,
			"搜索框与书页顶部内描边一致：中段拱起、外沿回落")
	assert_almost_eq(top_curve[0].y, top_curve[-1].y, 0.01,
			"左右两端不再使用旧版单向倾斜")
	assert_almost_eq(top_curve[0].y - top_curve[6].y,
			search_frame.page_curve_depth, 0.01)
	assert_true(search_frame.passive_color.is_equal_approx(
			Color(0.278431, 0.227451, 0.168627, 0.9)),
			"搜索框改用上一页/下一页的柔和墨色")
	assert_almost_eq(search_frame.line_width, 2.0, 0.001,
			"搜索框边宽调整为 2px")
	var placeholder_baselines := curved_text.debug_text_baselines("搜索...")
	var lowest_baseline := INF
	var highest_baseline := -INF
	for baseline: float in placeholder_baselines:
		lowest_baseline = minf(lowest_baseline, baseline)
		highest_baseline = maxf(highest_baseline, baseline)
	assert_gte(highest_baseline - lowest_baseline, 2.0,
			"短文字也必须在自身宽度内产生肉眼可见的整像素弧度")
	assert_lt(placeholder_baselines[floori(placeholder_baselines.size() * 0.5)],
			placeholder_baselines[0], "搜索文字中段拱起、首尾回落")
	var two_character_baselines := curved_text.debug_text_baselines("毒素")
	assert_gte(absf(two_character_baselines[1] - two_character_baselines[0]), 1.0,
			"两个汉字的常见搜索词也必须呈现至少 1px 的书页方向高差")
	assert_eq(search_input.get_theme_color("font_color").a, 0.0,
			"原生直线文字隐藏，只显示曲线绘制层")
	assert_eq((clear_button.get_node("StrokeA") as Line2D).points[0].y, 12.0,
			"小 X 下移以补偿右端回落的框线")
	assert_null(search_control.get_node_or_null("SearchResults"),
			"输入一个字不再生成备选框或备选答案")
	assert_eq(search_input.placeholder_text, "搜索...")
	assert_true(search_input.caret_blink, "输入竖线持续闪烁")
	assert_almost_eq(search_input.caret_blink_interval, 0.55, 0.001)
	assert_true(search_input.keep_editing_on_text_submit,
			"回车提交过滤后仍保持输入与光标")
	assert_false(clear_button.visible)


func test_enter_filters_hero_page_and_small_x_is_the_only_reset_action() -> void:
	var codex := _make_codex()
	await get_tree().process_frame
	codex.show_section(CodexScreen.Section.HERO)
	var search_input := codex.get_node("SearchControl/SearchInput") as LineEdit
	var clear_button := codex.get_node("SearchControl/SearchClearButton") as Button
	var hero_gallery := codex.get_gallery(CodexScreen.Section.HERO)
	assert_eq((hero_gallery.get("all_heroes") as Array).size(), 24)

	search_input.text = "鼠"
	search_input.text_changed.emit(search_input.text)
	await get_tree().process_frame
	assert_true(clear_button.visible,
			"输入任意文字后立即显示小 X，不必等到回车提交")
	assert_eq((hero_gallery.get("all_heroes") as Array).size(), 24,
			"只输入文字不即时弹答案，也不提前过滤书页")
	clear_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(search_input.text, "", "未提交的文字也能由小 X 直接清空")
	assert_false(clear_button.visible)
	search_input.text = "鼠"
	search_input.text_changed.emit(search_input.text)
	codex.call("_on_search_text_submitted", "鼠")
	await get_tree().process_frame
	var filtered_heroes := hero_gallery.get("all_heroes") as Array
	assert_eq(filtered_heroes.size(), 2)
	assert_eq(filtered_heroes.map(func(hero: HeroData) -> String: return hero.hero_id),
			["h01", "h13"], "搜索鼠后书页只保留两名鼠英雄")
	assert_eq(search_input.text, "鼠")
	assert_true(clear_button.visible, "提交过滤后在输入框内出现小 X")
	assert_eq(int(hero_gallery.get("_current_page")), 0)
	assert_eq((hero_gallery.get("card_cards") as Array).size(), 2,
			"匹配卡片重建并连续占用书页轨道，不保留空洞")

	search_input.release_focus()
	await get_tree().process_frame
	assert_eq((hero_gallery.get("all_heroes") as Array).size(), 2,
			"失焦或按回车都不能自动解除过滤")
	clear_button.pressed.emit()
	await get_tree().process_frame
	assert_eq(search_input.text, "")
	assert_false(clear_button.visible)
	assert_eq((hero_gallery.get("all_heroes") as Array).size(), 24,
			"只有点击小 X 才恢复完整英雄书页")


func test_search_only_matches_names_and_empty_state_spans_both_book_pages() -> void:
	var codex := _make_codex()
	await get_tree().process_frame
	codex.show_section(CodexScreen.Section.HERO)
	codex.call("_on_search_text_submitted", "h01")
	await get_tree().process_frame
	var hero_gallery := codex.get_gallery(CodexScreen.Section.HERO)
	assert_true((hero_gallery.get("all_heroes") as Array).is_empty(),
			"hxx 编号不再参与搜索，搜索源只包含名字")
	var empty_state := codex.get_node("SearchEmptyState") as Control
	assert_true(empty_state.visible)
	assert_eq((empty_state.get_node("LeftMessage") as Label).text,
			"没有找到对应的结果...")
	assert_eq((empty_state.get_node("RightMessage") as Label).text, "")
	assert_false((empty_state.get_node("RightMessage") as Label).visible,
			"普通无结果只占左页，右页完整留白")
	assert_false((empty_state.get_node("CatGroup") as Control).visible)

	codex.search_cat_easter_egg_chance = 1.0
	codex.call("_on_search_text_submitted", "仍然搜不到")
	await get_tree().process_frame
	assert_eq((empty_state.get_node("LeftMessage") as Label).text, "没搜到...")
	assert_false((empty_state.get_node("RightMessage") as Label).visible)
	var cat_group := empty_state.get_node("CatGroup") as Control
	assert_true(cat_group.visible)
	assert_eq((cat_group.get_node("Meow") as Label).text, "喵")
	var cat_head := cat_group.get_node("CatHead") as TextureRect
	assert_not_null(cat_head.texture)
	var cat_ink: Color = (cat_head.material as ShaderMaterial).get_shader_parameter("ink_color")
	assert_lt(Vector4(cat_ink.r, cat_ink.g, cat_ink.b, cat_ink.a).distance_to(
			Vector4(CodexScreen.CLOSE_IDLE_COLOR.r, CodexScreen.CLOSE_IDLE_COLOR.g,
					CodexScreen.CLOSE_IDLE_COLOR.b, CodexScreen.CLOSE_IDLE_COLOR.a)), 0.001,
			"猫猫头与小 X、放大镜共用同一墨色")


func test_submitted_query_filters_only_the_active_chapter_data_source() -> void:
	var codex := _make_codex()
	await get_tree().process_frame
	var search_input := codex.get_node("SearchControl/SearchInput") as LineEdit
	var item: ItemData = ItemCatalog.all_active_for_tier(1)[0]
	codex.show_section(CodexScreen.Section.ITEM)
	search_input.text = item.item_name
	codex.call("_on_search_text_submitted", item.item_name)
	await get_tree().process_frame
	var item_gallery := codex.get_gallery(CodexScreen.Section.ITEM)
	var filtered_items := item_gallery.get("_items") as Array
	assert_eq(filtered_items.size(), 1)
	assert_eq((filtered_items[0] as ItemData).item_id, item.item_id)
	assert_false((codex.get_node("BookmarkLayer/RarityBookmarks") as Control).visible,
			"跨三档搜索时暂时收起稀有度签，避免伪装成单一稀有度页")

	codex.show_section(CodexScreen.Section.HERO)
	await get_tree().process_frame
	var hero_gallery := codex.get_gallery(CodexScreen.Section.HERO)
	assert_true((hero_gallery.get("all_heroes") as Array).is_empty(),
			"同一关键词切到英雄章节后只搜索英雄数据，不跨章显示道具")
	assert_eq(search_input.text, item.item_name,
			"切换章节不清空已提交关键词")

	search_input.text = "毒素"
	codex.call("_on_search_text_submitted", "毒素")
	codex.show_section(CodexScreen.Section.EFFECT)
	await get_tree().process_frame
	var effect_gallery := codex.get_gallery(CodexScreen.Section.EFFECT)
	var filtered_indices := effect_gallery.get("_filtered_entry_indices") as Array
	assert_gt(filtered_indices.size(), 0)
	var entries := effect_gallery.get("_entries") as Array
	assert_true(filtered_indices.any(func(index: int) -> bool:
		return String((entries[index] as Dictionary).id) == "poison"))
