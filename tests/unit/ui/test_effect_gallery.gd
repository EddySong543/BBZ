extends GutTest

const UnifiedCodexScreen := preload("res://src/ui/codex_screen.gd")

const EXPECTED_EFFECTS: Array[String] = [
	"附加效果",
	"真实伤害",
	"玄金不动相",
	"不坠神言",
	"穿防",
	"穿大防",
	"护甲",
	"毒素",
	"脆弱",
	"剑气",
]

const EXPECTED_GALLERY_ORDER: Array[String] = [
	"附加效果",
	"护甲",
	"穿防",
	"穿大防",
	"真实伤害",
	"玄金不动相",
	"不坠神言",
	"毒素",
	"脆弱",
	"剑气",
]

const INSTALLED_EFFECT_ICONS: Array[StringName] = [
	&"bonus_effect",
	&"true_damage",
	&"h02_wave_upgrade",
	&"h08_retained_big_defend",
	&"pierce_defense",
	&"pierce_guard",
	&"armor",
	&"poison",
	&"vulnerable",
	&"sword_qi",
]


func test_effect_catalog_contains_every_current_shared_effect() -> void:
	var catalog := load("res://src/battle/effect_catalog.gd")
	assert_not_null(catalog)
	if catalog == null:
		return
	var entries: Array = catalog.call("all")
	assert_eq(entries.size(), EXPECTED_EFFECTS.size(),
			"效果图鉴必须覆盖全部 10 项已接入效果")
	var names: Array[String] = []
	var colors: Dictionary = {}
	for entry: Dictionary in entries:
		names.append(String(entry.name))
		colors[(entry.ink as Color).to_html()] = true
		assert_gte(_contrast_ratio(entry.ink, Color("D0B088")), 4.5,
				"%s 的语义深色在羊皮纸上保持正文级可读性" % entry.name)
	assert_eq(names, EXPECTED_EFFECTS)
	assert_eq(colors.size(), EXPECTED_EFFECTS.size(),
			"首批效果各自保留可复用的语义色，不把所有状态压成毒素绿")
	assert_eq(String(entries[0].description),
			"像毒素，剑气等都属于附加效果。附加效果只会被「波」或「大波」命中触发，道具无法触发。",
			"附加效果必须直接说明波/大波与道具的触发边界")
	assert_eq(String(entries[7].description),
			"可叠加。中毒英雄被「大波」命中时，引爆并清除全部毒素，每层造成 0.5 点伤害。",
			"毒素效果图鉴必须明确只有大波命中才能引爆")
	assert_eq(String(entries[9].description),
			"最多积累4点，昴日【鸡】发动「飞洒天星」时消耗全部剑气。",
			"剑气图鉴必须复用最新主动技能名，并由文案显式补全书名号")
	var h10 := load("res://assets/data/heroes/h10.tres") as HeroData
	assert_eq(h10.skill_description, "飞洒天星")
	assert_eq(h10.skill_detail,
			"我方每次攻击命中，积累1点剑气，昴日【鸡】可消耗全部剑气发动强力一击（每点造成0.5点伤害。2点穿防，4点穿大防）。",
			"图鉴与战斗共用的 h10 资源必须完整包含伤害与穿透阈值")


func test_effect_gallery_previews_all_entries_and_selects_poison() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	assert_not_null(packed)
	if packed == null:
		return
	var gallery := packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	var entries := gallery.get_node("EffectList") as Control
	assert_eq(entries.get_child_count(), EXPECTED_EFFECTS.size())
	for index: int in EXPECTED_GALLERY_ORDER.size():
		var button := entries.get_child(index) as Button
		assert_true(button.text.is_empty(),
				"效果名必须脱离 Button 内部排版，避免原生文字层再次挤占图标区域")
		assert_eq((button.get_node("NameLabel") as Label).text, EXPECTED_GALLERY_ORDER[index])
		assert_true(button.get_rect().end.x <= entries.size.x)
		assert_true(button.get_rect().end.y <= entries.size.y,
				"效果索引完整落在左页内容区内")
	gallery.call("select_effect", &"poison")
	assert_eq((gallery.get_node("DetailArea/EffectName") as Label).text, "毒素")
	var poison_description := (gallery.get_node("DetailArea/Description") as Label).text
	assert_true(EffectTextFormatter.strip_line_break_controls(poison_description).contains(
			"每层造成 0.5 点伤害"))
	assert_true(gallery.get_node("DetailArea/EffectIcon") is TextureRect,
			"效果详情只保留外部图标素材槽，不再使用程序化绘制组件")
	assert_false(ResourceLoader.exists("res://src/ui/components/effect_icon.gd"))
	var selected_entry := entries.get_child(7) as Button
	assert_true((selected_entry.get_node("SelectionPointer") as Control).visible,
			"效果页必须与英雄、道具页使用同款像素指针表达选中")
	assert_null(selected_entry.get_node_or_null("SelectionPaper"),
			"效果目录不得再用整行淡色矩形制造左右漂移错觉")
	assert_null(selected_entry.get_node_or_null("CatalogAccent"),
			"效果页采用英雄同款正式外框后，不再叠加独有的印谱底图")
	assert_not_null(selected_entry.get_node_or_null("EffectFrame/GalleryItemFrame"),
			"效果图标必须进入英雄、道具页同款正式外框")
	assert_null(selected_entry.get_node_or_null("SelectionBar"),
			"效果页不再保留独有的竖色条选中语言")


func test_effect_detail_changes_only_after_click() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var entries := gallery.get_node("EffectList") as Control
	var second := entries.get_child(1) as Button
	var detail_name := gallery.get_node("DetailArea/EffectName") as Label
	assert_eq(detail_name.text, "附加效果")
	second.mouse_entered.emit()
	await get_tree().process_frame
	assert_eq(detail_name.text, "附加效果",
			"悬停只允许显示鼠标反馈，不得预览或改写右页内容")
	second.pressed.emit()
	assert_eq(detail_name.text, "护甲",
			"右页内容只在左键点击后切换")


func test_effect_index_uses_fixed_hero_style_three_row_tracks_without_overlap() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var entries := gallery.get_node("EffectList") as Control
	var expected_columns: Array[float] = [0.0, 170.0, 340.0, 510.0]
	var expected_rows: Array[float] = [0.0, 196.0, 392.0]
	assert_eq(entries.position, Vector2(188.0, 255.0),
			"效果目录必须从英雄、道具页同一条首行轨道开始")
	assert_eq(entries.size.y, 693.0,
			"目录保留完整三行高度，后续效果不得触发整体自动居中")
	for index: int in entries.get_child_count():
		var button := entries.get_child(index) as Button
		assert_eq(button.position.x, expected_columns[index % 4],
				"效果网格必须与英雄页使用 4 列固定轨道")
		assert_eq(button.position.y, expected_rows[floori(index / 4.0)],
				"10 个效果按英雄页行距排成三行")
		assert_eq(button.size, Vector2(104.0, 140.0))
		for previous_index: int in index:
			var previous := entries.get_child(previous_index) as Button
			assert_false(button.get_rect().intersects(previous.get_rect()),
					"任意两个效果外框点击区均不得重叠")
		var icon := button.get_node("EffectFrame/Icon") as TextureRect
		var name_label := button.get_node("NameLabel") as Label
		assert_lte(icon.get_rect().end.y, name_label.position.y,
				"效果名必须像英雄名一样位于外框下方")
		assert_eq(name_label.get_theme_font_size("font_size"), 17)
		var frame_art := button.get_node("EffectFrame/GalleryItemFrame") as TextureRect
		assert_eq(frame_art.texture.resource_path, "res://assets/ui/item_frame.png")
		if index == 0:
			assert_eq(name_label.get_theme_color("font_color"), Color("9A6828"),
					"当前选中项仅以更深目录墨色辅助识别")
		else:
			assert_eq(name_label.get_theme_color("font_color"), Color("2E2922"))


func test_effect_detail_navigation_matches_other_codex_pages() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var navigation := gallery.get_node_or_null("DetailArea/DetailNavigation") as Control
	assert_not_null(navigation,
			"效果详情页必须补齐英雄、道具页同款逐项导航")
	if navigation == null:
		return
	var previous := navigation.get_node("PreviousItem") as Button
	var indicator := navigation.get_node("ItemIndicator") as Label
	var next := navigation.get_node("NextItem") as Button
	assert_eq(indicator.text, "01 / 10")
	assert_true(previous.disabled)
	assert_false(next.disabled)
	next.pressed.emit()
	assert_eq(indicator.text, "02 / 10")
	assert_eq((gallery.get_node("DetailArea/EffectName") as Label).text, "护甲")


func test_effect_detail_uses_one_centered_vertical_axis() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var name_label := gallery.get_node("DetailArea/EffectName") as Label
	var wash := gallery.get_node("DetailArea/EffectIconWash") as TextureRect
	var icon := gallery.get_node("DetailArea/EffectIcon") as TextureRect
	var rule := gallery.get_node("DetailArea/DetailRule") as ColorRect
	var pin := gallery.get_node("DetailArea/DetailPin") as ColorRect
	var description := gallery.get_node("DetailArea/Description") as Label
	var navigation := gallery.get_node("DetailArea/DetailNavigation") as Control
	var axis_x := name_label.get_rect().get_center().x
	assert_almost_eq(icon.size.x, 160.0, 0.01,
			"效果图标宽度要在英雄同尺寸笔刷内留下稳定承托边界")
	assert_almost_eq(icon.size.y, 160.0, 0.01,
			"效果图标要在英雄同尺寸笔刷内留下稳定承托边界")
	assert_eq(wash.texture.resource_path,
			"res://assets/ui/hero_codex_portrait_wash.png",
			"效果图标承托必须直接复用英雄详情已经通过的蓝灰笔刷")
	assert_eq(wash.position, Vector2(1051.0, 270.0))
	assert_eq(wash.size, Vector2(720.0, 360.0),
			"蓝灰笔刷的大小和英雄图鉴完全一致，本轮不得缩放")
	assert_lt(wash.get_index(), icon.get_index(),
			"蓝灰笔刷只作背景，不得覆盖效果图标")
	assert_almost_eq(wash.size.x / wash.size.y, 2.0, 0.001,
			"同源笔刷保持原始 2:1 轮廓，不得被拉成新形状")
	assert_almost_eq(wash.get_rect().get_center().x, axis_x, 0.01)
	assert_almost_eq(icon.get_rect().get_center().x, axis_x, 0.01)
	assert_lt(rule.position.x, description.position.x)
	assert_lt(pin.position.x, description.position.x)
	assert_lte(name_label.get_rect().end.y, icon.position.y)
	assert_lte(icon.get_rect().end.y, description.position.y)
	assert_lte(description.get_rect().end.y, navigation.position.y)
	assert_eq(description.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(rule.size, Vector2(2.0, 60.0),
			"效果说明改用英雄技能正文同款左侧竖线")
	assert_eq(pin.size, Vector2(6.0, 6.0))
	assert_null(gallery.get_node_or_null("DetailArea/Rule"),
			"效果右页不再保留横向中分割线")
	assert_true(description.get_theme_font("font") is FontVariation)
	assert_lt((description.get_theme_font("font") as FontVariation).variation_embolden, 0.5,
			"右页解释保持正常正文重量，不得再与标题一样加粗")


func test_effect_selection_reuses_hero_frame_palette_and_detail_motion() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var entries := gallery.get_node("EffectList") as Control
	var armor := entries.get_child(1) as Button
	armor.pressed.emit()
	var frame_material := (armor.get_node("EffectFrame/GalleryItemFrame") as TextureRect).material \
			as ShaderMaterial
	assert_eq(frame_material.get_shader_parameter("mid_color"), Color("C99032"),
			"效果选中态与英雄页一样把真实外框转为金色")
	var detail_icon := gallery.get_node("DetailArea/EffectIcon") as TextureRect
	assert_gt(detail_icon.scale.x, 1.0,
			"点击切换后效果图标应从轻微放大状态回落，补齐内部切换反馈")
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(detail_icon.scale.x, 1.0, 0.001)
	assert_almost_eq(detail_icon.scale.y, 1.0, 0.001)
	var unselected := entries.get_child(0) as Button
	var cell_material := (unselected.get_node("EffectFrame/EffectCell") as ColorRect).material \
			as ShaderMaterial
	var frame_material_unselected := (unselected.get_node(
			"EffectFrame/GalleryItemFrame") as TextureRect).material as ShaderMaterial
	assert_true((cell_material.get_shader_parameter("fill_color") as Color).is_equal_approx(
			Color("71685D")),
			"效果图鉴格底回退为既有暖褐暗阶")
	assert_true((cell_material.get_shader_parameter("inner_color") as Color).is_equal_approx(
			Color("8C7C68")),
			"效果图鉴格底回退为既有暖褐亮阶")
	assert_true((frame_material_unselected.get_shader_parameter("shadow_color") as Color).is_equal_approx(
			Color("49372B")))
	assert_true((frame_material_unselected.get_shader_parameter("mid_color") as Color).is_equal_approx(
			Color("8B765D")))
	assert_true((frame_material_unselected.get_shader_parameter("highlight_color") as Color).is_equal_approx(
			Color("D7BD91")))


func test_hero_gallery_bolds_effect_keywords_without_repeating_glossaries() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	gallery.call("_select", 5)
	var detail := gallery.find_child("SkillDetail", true, false) as Label
	assert_false(detail.visible,
			"原文 Label 只保留布局与可测试文本，不再和分段字形重复绘制")
	assert_false(detail.text.contains("毒素："),
			"英雄页不再重复效果图鉴已经承担的毒素百科说明")
	assert_true(detail.text.contains("1层毒素"),
			"英雄自身如何施加效果的技能句必须保留")
	var keyword_labels := gallery.get("_d_keyword_labels") as Array
	assert_eq(keyword_labels.size(), 1)
	var poison_keyword := keyword_labels[0] as Label
	assert_eq(poison_keyword.text, "毒素")
	assert_eq(poison_keyword.get_theme_color("font_color"), detail.get_theme_color("font_color"),
			"关键词只加粗，不再通过换色强调")
	assert_true(poison_keyword.get_theme_font("font") is FontVariation)
	assert_almost_eq(
			(poison_keyword.get_theme_font("font") as FontVariation).variation_embolden,
			0.32, 0.001,
			"关键词只增加克制的小幅字重，不再使用重影式粗体")
	var spark := poison_keyword.get_node_or_null("KeywordSpark") as Control
	assert_not_null(spark,
			"效果词末字右上角必须绘制不占字宽的四向星芒")
	if spark != null:
		assert_eq(spark.size, Vector2(7.0, 7.0))
		assert_gt(spark.position.x, poison_keyword.size.x * 0.5,
				"星芒应贴近关键词末字，不能回到词首或独占一格")
		assert_lt(spark.position.y, 0.0,
				"星芒作为右上角标，不得落回文字基线或下方")
		assert_gte(spark.position.x, poison_keyword.size.x - 1.0,
				"星芒不得再向左压进关键词末字")
	var detail_segments := gallery.get("_d_detail_segment_labels") as Array
	var reconstructed := ""
	for segment_variant: Variant in detail_segments:
		reconstructed += (segment_variant as Label).text
	assert_eq(reconstructed, detail.text,
			"正文由互斥片段完整重建，每个字不再先画全文再叠绘")
	gallery.call("_select", 10)
	keyword_labels = gallery.get("_d_keyword_labels") as Array
	assert_eq(keyword_labels.size(), 1)
	assert_eq((keyword_labels[0] as Label).text, "真实伤害",
			"英雄页对其他已通过效果使用相同的粗体规则")
	gallery.call("_select", 9)
	keyword_labels = gallery.get("_d_keyword_labels") as Array
	assert_eq(keyword_labels.size(), 2)
	for keyword_variant: Variant in keyword_labels:
		assert_eq((keyword_variant as Label).text, "剑气",
				"昴日正文中的剑气使用同一效果词加粗规则")


func test_effect_keyword_emphasis_exclusions_and_spacing_are_global() -> void:
	for excluded: String in ["附加效果", "护甲", "穿防", "穿大防"]:
		var runs := EffectTextFormatter.split_runs("获得%s，然后继续" % excluded)
		assert_false(runs.any(func(run: Dictionary) -> bool:
			return bool(run.bold) and String(run.text) == excluded),
			"%s 不得加粗或生成星芒角标" % excluded)

	var h20_runs := EffectTextFormatter.split_runs("直到下回合结束，使其获得脆弱。")
	var keyword_index := -1
	for index: int in h20_runs.size():
		if bool(h20_runs[index].bold):
			keyword_index = index
			break
	assert_gt(keyword_index, 0)
	assert_eq(String(h20_runs[keyword_index - 1].text), "直到下回合结束，使其获得",
			"h20 关键词前的正文不得被改写")
	assert_eq(EffectTextFormatter.KEYWORD_GAP_BEFORE, 0.0,
			"连续中文短语在关键词前不得插入人工间距")
	assert_eq(EffectTextFormatter.KEYWORD_SPARK_OFFSET.x, 1.0,
			"星芒从关键词末字外侧开始，修复 h11/h20 贴字")
	assert_gte(EffectTextFormatter.KEYWORD_GAP_AFTER,
			EffectKeywordSpark.MARK_SIZE.x + EffectTextFormatter.KEYWORD_SPARK_OFFSET.x,
			"h10 后文必须排在完整星芒占位之后")


func test_h10_h11_h20_keyword_geometry_uses_one_shared_formula() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	for hero_index: int in [9, 10, 19]:
		gallery.call("_select", hero_index)
		await get_tree().process_frame
		var segments := gallery.get("_d_detail_segment_labels") as Array
		for segment_variant: Variant in segments:
			var keyword := segment_variant as Label
			if not bool(keyword.get_meta(EffectTextFormatter.META_IS_KEYWORD, false)):
				continue
			var spark := keyword.get_node_or_null("KeywordSpark") as Control
			assert_not_null(spark)
			if spark == null:
				continue
			var keyword_width := keyword.get_theme_font("font").get_string_size(
					keyword.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					keyword.get_theme_font_size("font_size")).x
			assert_gte(spark.position.x, keyword_width + 0.99,
					"h10/h11/h20 星芒均从关键词末字外侧开始")
			var line_id := String(keyword.get_meta(EffectTextFormatter.META_LINE_ID))
			var run_order := int(keyword.get_meta(EffectTextFormatter.META_RUN_ORDER))
			for neighbor_variant: Variant in segments:
				var neighbor := neighbor_variant as Label
				if String(neighbor.get_meta(EffectTextFormatter.META_LINE_ID, "")) != line_id:
					continue
				var neighbor_order := int(neighbor.get_meta(
						EffectTextFormatter.META_RUN_ORDER, -1))
				if neighbor_order == run_order - 1:
					var previous_width := neighbor.get_theme_font("font").get_string_size(
							neighbor.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
							neighbor.get_theme_font_size("font_size")).x
					assert_lte(keyword.position.x - (neighbor.position.x + previous_width), 0.01,
							"h20 的“获得/脆弱”等连续中文不得在关键词前插空")
				elif neighbor_order == run_order + 1:
					var spark_right := keyword.position.x + spark.position.x \
							+ EffectKeywordSpark.MARK_SIZE.x
					assert_lte(spark_right, neighbor.position.x,
							"h10/h11/h20 星芒不得再侵入后续文字或标点")


func test_long_hero_skill_detail_keeps_h01_left_rule_clearance() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	var rule := gallery.get("_d_detail_rule") as ColorRect
	var detail := gallery.find_child("SkillDetail", true, false) as Label
	gallery.call("_select", 0)
	await get_tree().process_frame
	var h01_segments := gallery.get("_d_detail_segment_labels") as Array
	var h01_left := INF
	for segment_variant: Variant in h01_segments:
		h01_left = minf(h01_left, (segment_variant as Label).position.x)
	var h01_clearance := h01_left - rule.get_rect().end.x
	gallery.call("_select", 9)
	await get_tree().process_frame
	var h10_segments := gallery.get("_d_detail_segment_labels") as Array
	var h10_left := INF
	for segment_variant: Variant in h10_segments:
		h10_left = minf(h10_left, (segment_variant as Label).position.x)
	var h10_clearance := h10_left - rule.get_rect().end.x
	assert_gte(h01_clearance, 38.0,
			"h01 在统一安全区内不得低于原有 38px 的舒适竖线净距")
	assert_gte(h10_clearance, 38.0,
			"h10 等长文案不得退回统一安全区修复前的贴线状态")
	assert_eq(detail.size.x, 666.0,
			"所有英雄共用固定左右安全区，不给 h10 写特例")


func test_h11_uses_the_same_safe_track_and_never_orphans_its_full_stop() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	gallery.call("_select", 9)
	await get_tree().process_frame
	var h10_left := INF
	for segment_variant: Variant in gallery.get("_d_detail_segment_labels") as Array:
		h10_left = minf(h10_left, (segment_variant as Label).position.x)
	gallery.call("_select", 10)
	await get_tree().process_frame
	var h11_left := INF
	var h11_lines: Dictionary = {}
	var h11_line_heights: Dictionary = {}
	var h11_line_tops: Dictionary = {}
	for segment_variant: Variant in gallery.get("_d_detail_segment_labels") as Array:
		var segment := segment_variant as Label
		h11_left = minf(h11_left, segment.position.x)
		var line_id := String(segment.get_meta(EffectTextFormatter.META_LINE_ID))
		h11_lines[line_id] = String(h11_lines.get(line_id, "")) + segment.text
		h11_line_heights[line_id] = segment.size.y
		h11_line_tops[line_id] = segment.position.y
	assert_gte(h11_left, h10_left - 1.0,
			"h11 不得因关键词数量较少而获得更宽轨道、向竖线方向突出")
	for line_text: String in h11_lines.values():
		assert_ne(line_text, "。", "h11 句号必须跟随前一个中文短语，不能独占一行")
	assert_eq(h11_line_heights.size(), 2, "h11 正文应稳定排成两行")
	var heights := h11_line_heights.values()
	assert_almost_eq(float(heights[0]), float(heights[1]), 0.01,
			"禁则移字后第二行必须按正文真实字体重算高度，不得沿用标点孤行的矮行框")
	var tops := h11_line_tops.values()
	tops.sort()
	assert_gte(float(tops[1]) - float(tops[0]), float(heights[0]) + 4.0,
			"换行后必须保留完整行高和明确行间距，不得贴住第一行")


func test_every_hero_description_obeys_cjk_line_start_and_end_rules() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	var heroes: Array = gallery.get("all_heroes") as Array
	for hero_index: int in heroes.size():
		gallery.call("_select", hero_index)
		await get_tree().process_frame
		var lines: Dictionary = {}
		for segment_variant: Variant in gallery.get("_d_detail_segment_labels") as Array:
			var segment := segment_variant as Label
			var line_id := String(segment.get_meta(EffectTextFormatter.META_LINE_ID))
			lines[line_id] = String(lines.get(line_id, "")) + segment.text
		for line_text_variant: Variant in lines.values():
			var line_text := String(line_text_variant)
			assert_false(EffectTextFormatter.line_starts_with_forbidden(line_text),
					"%s 的说明行首不得出现闭合符号：%s" % [
							String(heroes[hero_index].hero_id), line_text])
			assert_false(EffectTextFormatter.line_ends_with_forbidden(line_text),
					"%s 的说明行尾不得留下开放符号：%s" % [
							String(heroes[hero_index].hero_id), line_text])


func test_hero_skill_section_moves_as_one_group_toward_hp() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate()
	add_child_autofree(gallery)
	await get_tree().process_frame
	var skill_name := gallery.get("_d_skill_name") as Label
	var skill_icon := gallery.get("_d_skill_icon") as TextureRect
	var skill_tag := gallery.get("_d_tag_group") as Control
	var detail := gallery.find_child("SkillDetail", true, false) as Label
	var rule := gallery.get("_d_detail_rule") as ColorRect
	var pin := gallery.get("_d_detail_pin") as ColorRect
	var hp_group := gallery.get_node("DetailArea/HPGroup") as Control
	assert_eq(skill_name.position.y, 728.0)
	assert_true(not skill_icon.visible or skill_icon.position.y == 728.0)
	assert_eq(skill_tag.position.y, 727.0)
	assert_eq(detail.position.y, 788.0)
	assert_eq(rule.position.y, 798.0)
	assert_eq(pin.position.y, 792.0)
	assert_eq(skill_name.position.y - hp_group.get_rect().end.y, 30.0,
			"技能名、图标、类型签、正文、竖线和端点必须整体靠近血量区")


func test_unified_codex_reflows_effect_segments_at_final_font_size() -> void:
	var packed := load("res://src/ui/codex_screen.tscn") as PackedScene
	var codex := packed.instantiate()
	add_child_autofree(codex)
	await get_tree().process_frame
	var gallery := codex.call("get_gallery", UnifiedCodexScreen.Section.HERO) as Control
	var native_layer := codex.get_node("NativeTextLayer") as CodexNativeTextLayer
	for hero_index: int in [5, 9]:
		gallery.call("_select", hero_index)
		await get_tree().process_frame
		native_layer.sync_now()
		var line_ends: Dictionary = {}
		var detail_segments := gallery.get("_d_detail_segment_labels") as Array
		for segment_variant: Variant in detail_segments:
			var segment := segment_variant as Label
			var mirror := native_layer.mirror_for_source(segment)
			assert_not_null(mirror)
			if mirror == null:
				continue
			var line_id := String(segment.get_meta(EffectTextFormatter.META_LINE_ID))
			var advance := mirror.get_theme_font("font").get_string_size(
					mirror.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
					mirror.get_theme_font_size("font_size")).x
			if line_ends.has(line_id):
				assert_gte(mirror.position.x, float(line_ends[line_id]),
						"最终19px文字层必须重新排流，后段不得压回前段")
			line_ends[line_id] = mirror.position.x + advance
			if String(segment.name).begins_with("SkillKeyword_"):
				var spark: Control = native_layer.keyword_spark_for_source(segment)
				assert_not_null(spark)
				if spark != null:
					var spark_rect := _canvas_rect(spark)
					assert_lt(spark_rect.position.y, mirror.get_global_rect().get_center().y,
							"原生文字层的星芒必须保持右上角标位置")


func test_effect_icons_use_visible_content_bounds_for_uniform_scale() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var entries := gallery.get_node("EffectList") as Control
	for button_node: Node in entries.get_children():
		var button := button_node as Button
		var icon := button.get_node("EffectFrame/Icon") as TextureRect
		assert_true(icon.texture is AtlasTexture,
				"每枚外部图标必须先裁掉透明留白，再进入统一尺寸槽")
		var atlas := icon.texture as AtlasTexture
		assert_gt(atlas.region.size.x, 0.0)
		assert_gt(atlas.region.size.y, 0.0)
		var visual_scale := minf(icon.size.x / atlas.region.size.x,
				icon.size.y / atlas.region.size.y)
		var visual_size := atlas.region.size * visual_scale
		assert_almost_eq(maxf(visual_size.x, visual_size.y), 64.0, 0.01,
				"进入英雄同款外框后，左页效果图标的可见内容长边统一为 64px")


func test_imported_effect_icons_are_available_to_the_gallery() -> void:
	var catalog := load("res://src/battle/effect_catalog.gd")
	for effect_id: StringName in INSTALLED_EFFECT_ICONS:
		var entry: Dictionary = catalog.call("get_by_id", effect_id)
		var icon_path := String(entry.get("icon_path", ""))
		assert_false(icon_path.is_empty(), "%s 必须配置图标路径" % effect_id)
		assert_true(ResourceLoader.exists(icon_path),
				"%s 的外部图标必须已导入并可被图鉴加载" % effect_id)
		assert_not_null(load(icon_path) as Texture2D,
				"%s 的图标路径必须能加载为 Texture2D" % effect_id)


func test_armor_rename_keeps_item_names_and_matching_art_paths() -> void:
	var worn_armor := ItemCatalog.make("t1_jiudun")
	var sturdy_armor := ItemCatalog.make("t2_jiandun")
	assert_eq(worn_armor.item_name, "破旧的护甲")
	assert_eq(sturdy_armor.item_name, "坚固的护甲")
	assert_eq(ItemCatalog.icon_path("t1_jiudun"),
			"res://assets/sprites/items/破旧的护甲.png")
	assert_eq(ItemCatalog.icon_path("t2_jiandun"),
			"res://assets/sprites/items/坚固的护甲.png")
	assert_true(ResourceLoader.exists(ItemCatalog.icon_path("t1_jiudun")))
	assert_true(ResourceLoader.exists(ItemCatalog.icon_path("t2_jiandun")))


func test_item_descriptions_restore_full_stops_in_runtime_text() -> void:
	for item: ItemData in ItemCatalog.all():
		assert_true(item.description.ends_with("。"),
				"%s 的玩家可见说明必须以完整句号收尾" % item.item_name)
	assert_true(ItemCatalog.make("t1_jiedu_yaoshui").description.contains("。成功清除后"),
			"多句说明恢复句号，不再改写成分号")


func test_unified_codex_exposes_effect_as_third_chapter() -> void:
	var packed := load("res://src/ui/codex_screen.tscn") as PackedScene
	var codex := packed.instantiate()
	add_child_autofree(codex)
	await get_tree().process_frame
	var effect_bookmark := codex.get_node("BookmarkLayer/EffectBookmark") as Button
	var item_bookmark := codex.get_node("BookmarkLayer/ItemBookmark") as Button
	var rarity_bookmarks := codex.get_node("BookmarkLayer/RarityBookmarks") as Control
	assert_eq((effect_bookmark.get_node("StateText") as Label).text, "效果")
	assert_eq(effect_bookmark.position.y - item_bookmark.get_rect().end.y, 6.0,
			"稀有度收起时，效果是紧跟道具的第三枚正式侧签")
	assert_not_null(codex.get_node_or_null("GalleryHost/EffectGallery"))
	codex.call("show_section", 1)
	assert_eq(effect_bookmark.position.y - rarity_bookmarks.get_rect().end.y, 6.0,
			"道具二级签展开时只把效果签顺排到其下方，不产生重叠")
	codex.call("show_section", 2)
	await get_tree().create_timer(0.22).timeout
	assert_eq(int(codex.get("current_section")), 2)
	assert_true((codex.call("get_gallery", 2) as Control).visible)
	assert_false(rarity_bookmarks.visible,
			"普通、稀有、传说只属于道具章节")
	assert_eq(effect_bookmark.position.y - item_bookmark.get_rect().end.y, 6.0)
	var native_layer := codex.get_node("NativeTextLayer") as CodexNativeTextLayer
	native_layer.sync_now()
	var effect_gallery := codex.call("get_gallery", 2) as Control
	var source_name := effect_gallery.get_node("DetailArea/EffectName") as Label
	var mirror_name := native_layer.mirror_for_source(source_name)
	assert_not_null(mirror_name)
	assert_eq(mirror_name.get_theme_color("font_color"), Color("2E2922"),
			"效果页进入清晰原生文字层后仍统一使用深墨色")
	var effect_list := effect_gallery.get_node("EffectList") as Control
	for button_node: Node in effect_list.get_children():
		var button := button_node as Button
		var source_label := button.get_node("NameLabel") as Label
		var mirror_label := native_layer.mirror_for_source(source_label)
		assert_not_null(mirror_label)
		if mirror_label == null:
			continue
		var icon_rect := _canvas_rect(button.get_node("EffectFrame/Icon") as Control)
		var text_rect := _canvas_rect(mirror_label)
		assert_lte(icon_rect.end.y + 4.0, text_rect.position.y,
				"最终画布上的效果名必须像英雄名一样稳定落在外框下方")


func _canvas_rect(control: Control) -> Rect2:
	var transform := control.get_global_transform_with_canvas()
	var top_left := transform * Vector2.ZERO
	var bottom_right := transform * control.size
	return Rect2(top_left.min(bottom_right), (bottom_right - top_left).abs())


func _contrast_ratio(a: Color, b: Color) -> float:
	var a_luminance := _relative_luminance(a)
	var b_luminance := _relative_luminance(b)
	return (maxf(a_luminance, b_luminance) + 0.05) \
			/ (minf(a_luminance, b_luminance) + 0.05)


func _relative_luminance(color: Color) -> float:
	return 0.2126 * _linear_channel(color.r) \
			+ 0.7152 * _linear_channel(color.g) \
			+ 0.0722 * _linear_channel(color.b)


func _linear_channel(value: float) -> float:
	return value / 12.92 if value <= 0.04045 \
			else pow((value + 0.055) / 1.055, 2.4)
