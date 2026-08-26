extends GutTest

const UnifiedCodexScreen := preload("res://src/ui/codex_screen.gd")

const EXPECTED_EFFECTS: Array[String] = [
	"附加效果",
	"真实伤害",
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
	"毒素",
	"脆弱",
	"剑气",
]

const INSTALLED_EFFECT_ICONS: Array[StringName] = [
	&"bonus_effect",
	&"true_damage",
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
			"效果图鉴必须覆盖全部 8 项通过效果，而不是只收录毒素")
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
	assert_true((gallery.get_node("DetailArea/Description") as Label).text.contains("每层造成 0.5 点伤害"))
	assert_true(gallery.get_node("DetailArea/EffectIcon") is TextureRect,
			"效果详情只保留外部图标素材槽，不再使用程序化绘制组件")
	assert_false(ResourceLoader.exists("res://src/ui/components/effect_icon.gd"))
	var selected_entry := entries.get_child(5) as Button
	assert_true((selected_entry.get_node("SelectionPointer") as Control).visible,
			"效果页必须与英雄、道具页使用同款像素指针表达选中")
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


func test_effect_index_uses_requested_two_column_order_without_overlap() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var entries := gallery.get_node("EffectList") as Control
	var expected_columns: Array[float] = [24.0, 377.0]
	var expected_rows: Array[float] = [72.0, 208.0, 344.0, 480.0]
	var first_row_left: float = entries.position.x + expected_columns[0]
	var first_row_right: float = entries.position.x + expected_columns[1] + 310.0
	assert_almost_eq((first_row_left + first_row_right) * 0.5, 493.0, 0.5,
			"两列按钮主体必须以左书页中心为轴，不能被选中底纸制造的错觉掩盖真实偏移")
	for index: int in entries.get_child_count():
		var button := entries.get_child(index) as Button
		assert_eq(button.position.x, expected_columns[index % 2],
				"效果目录必须保持两列固定轨道")
		assert_eq(button.position.y, expected_rows[floori(index / 2.0)],
				"效果目录必须按指定顺序逐行排列")
		assert_eq(button.size, Vector2(310.0, 72.0))
		for previous_index: int in index:
			var previous := entries.get_child(previous_index) as Button
			assert_false(button.get_rect().intersects(previous.get_rect()),
					"任意两个效果目录点击行均不得重叠")
		var icon := button.get_node("Icon") as TextureRect
		var name_label := button.get_node("NameLabel") as Label
		assert_lte(icon.get_rect().end.x + 20.0, name_label.position.x,
				"效果目录必须严格保持图标在前、名称在后，并留下稳定间距")
		assert_true(name_label.get_theme_font("font") is FontVariation)
		assert_gte((name_label.get_theme_font("font") as FontVariation).variation_embolden, 0.5,
				"效果目录统一使用加粗文字，不再依赖状态换色强调")
		assert_eq(name_label.get_theme_color("font_color"), Color("3D301F"))


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
	assert_eq(indicator.text, "01 / 08")
	assert_true(previous.disabled)
	assert_false(next.disabled)
	next.pressed.emit()
	assert_eq(indicator.text, "02 / 08")
	assert_eq((gallery.get_node("DetailArea/EffectName") as Label).text, "护甲")


func test_effect_detail_uses_one_centered_vertical_axis() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var name_label := gallery.get_node("DetailArea/EffectName") as Label
	var wash := gallery.get_node("DetailArea/EffectIconWash") as TextureRect
	var icon := gallery.get_node("DetailArea/EffectIcon") as TextureRect
	var rule := gallery.get_node("DetailArea/Rule") as Control
	var description := gallery.get_node("DetailArea/Description") as Label
	var navigation := gallery.get_node("DetailArea/DetailNavigation") as Control
	var axis_x := name_label.get_rect().get_center().x
	assert_eq(icon.size, Vector2(192.0, 192.0),
			"效果详情图标必须成为右页主视觉，而不是旧版小图标")
	assert_eq(wash.texture.resource_path,
			"res://assets/ui/hero_codex_portrait_wash.png",
			"效果图标承托必须直接复用英雄详情已经通过的蓝灰笔刷")
	assert_lt(wash.get_index(), icon.get_index(),
			"蓝灰笔刷只作背景，不得覆盖效果图标")
	assert_almost_eq(wash.size.x / wash.size.y, 2.0, 0.001,
			"同源笔刷保持原始 2:1 轮廓，不得被拉成新形状")
	assert_almost_eq(wash.get_rect().get_center().x, axis_x, 0.01)
	assert_almost_eq(icon.get_rect().get_center().x, axis_x, 0.01)
	assert_almost_eq(rule.get_rect().get_center().x, axis_x, 0.01)
	assert_almost_eq(description.get_rect().get_center().x, axis_x, 0.01)
	assert_lte(name_label.get_rect().end.y, icon.position.y)
	assert_lte(icon.get_rect().end.y, rule.position.y)
	assert_lte(rule.get_rect().end.y, description.position.y)
	assert_lte(description.get_rect().end.y, navigation.position.y)
	assert_eq(description.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(rule.get_child_count(), 3,
			"右页分隔线恢复连续主线，并只保留两个像素端帽")
	var main_stroke := rule.get_node("MainStroke") as ColorRect
	var left_cap := rule.get_node("LeftCap") as ColorRect
	var right_cap := rule.get_node("RightCap") as ColorRect
	assert_eq(main_stroke.size, Vector2(216.0, 4.0))
	assert_eq(left_cap.size, Vector2(4.0, 8.0))
	assert_eq(right_cap.size, Vector2(4.0, 8.0))
	assert_eq(main_stroke.color, left_cap.color)
	assert_eq(main_stroke.color, right_cap.color)


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
			EffectTextFormatter.EMBOLDEN, 0.001,
			"英雄效果词与效果图鉴使用完全相同的仿粗参数")
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


func test_effect_icons_use_visible_content_bounds_for_uniform_scale() -> void:
	var packed := load("res://src/ui/effect_gallery_screen.tscn") as PackedScene
	var gallery := packed.instantiate() as Control
	add_child_autofree(gallery)
	await get_tree().process_frame
	var entries := gallery.get_node("EffectList") as Control
	for button_node: Node in entries.get_children():
		var button := button_node as Button
		var icon := button.get_node("Icon") as TextureRect
		assert_true(icon.texture is AtlasTexture,
				"每枚外部图标必须先裁掉透明留白，再进入统一尺寸槽")
		var atlas := icon.texture as AtlasTexture
		assert_gt(atlas.region.size.x, 0.0)
		assert_gt(atlas.region.size.y, 0.0)
		var visual_scale := minf(icon.size.x / atlas.region.size.x,
				icon.size.y / atlas.region.size.y)
		var visual_size := atlas.region.size * visual_scale
		assert_almost_eq(maxf(visual_size.x, visual_size.y), 48.0, 0.01,
				"左页图标的可见内容长边必须统一为 48px")


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


func test_item_descriptions_omit_full_stops_from_runtime_text() -> void:
	for item: ItemData in ItemCatalog.all():
		assert_false(item.description.contains("。"),
				"%s 的玩家可见说明不得保留句号" % item.item_name)
	assert_true(ItemCatalog.make("t1_jiedu_yaoshui").description.contains("；成功清除后"),
			"多句说明去掉句号后仍须以分号保留语义停顿")


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
	assert_eq(mirror_name.get_theme_color("font_color"), Color("3D301F"),
			"效果页进入清晰原生文字层后仍统一使用深墨色")
	var effect_list := effect_gallery.get_node("EffectList") as Control
	for button_node: Node in effect_list.get_children():
		var button := button_node as Button
		var source_label := button.get_node("NameLabel") as Label
		var mirror_label := native_layer.mirror_for_source(source_label)
		assert_not_null(mirror_label)
		if mirror_label == null:
			continue
		var icon_rect := _canvas_rect(button.get_node("Icon") as Control)
		var text_rect := _canvas_rect(mirror_label)
		assert_lte(icon_rect.end.x + 8.0, text_rect.position.x,
				"最终画布上的原生文字不得与左侧图标重叠")


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
