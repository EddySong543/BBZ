extends GutTest

const HeroGalleryScreen := preload("res://src/ui/hero_gallery_screen.gd")
const ItemGalleryScreen := preload("res://src/ui/item_gallery_screen.gd")
const ItemGalleryGridPreview := preload("res://src/ui/components/item_gallery_grid_preview.gd")
const ItemAvatarFrameScript := preload("res://src/ui/components/item_avatar_frame.gd")
const BattleCodexOverlay := preload("res://src/ui/components/battle_codex_overlay.gd")
const ItemFrameStyle := preload("res://src/ui/components/item_frame_style.gd")
const UnifiedCodexScreen := preload("res://src/ui/codex_screen.gd")
const MAIN_FONT_PATH := "res://assets/font/zlabs_pixel_ui.tres"
const BASE_FONT_PATH := "res://assets/font/ZLabsPixel_12px_M_CN.ttf"

## 回归守卫：关键 screen 脚本在含 autoload 的 GUT 环境能编译。
## （裸 --check-only 无 autoload（FontManager 等）会误报，故用 GUT 环境 load 触发编译。）
## bp_screen：2026-07-03 任务#5 接入 DraftAI 后的引用解析守卫。

func test_bp_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/bp_screen.gd"), "bp_screen.gd 编译通过（DraftAI 接线）")


func test_hero_gallery_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/hero_gallery_screen.gd"), "hero_gallery_screen.gd 编译通过")


func test_item_gallery_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/item_gallery_screen.gd"), "item_gallery_screen.gd 编译通过")


func test_unified_codex_screen_compiles() -> void:
	assert_not_null(load("res://src/ui/codex_screen.gd"), "codex_screen.gd 编译通过")
	assert_not_null(load("res://src/ui/codex_screen.tscn"), "codex_screen.tscn 可加载")


func test_runtime_ui_uses_weighted_flattened_zlabs_cn_font() -> void:
	assert_eq(FontManager.f12.resource_path, MAIN_FONT_PATH,
			"FontManager 的完整 UI 字体切换到统一 Z工坊预设")
	assert_same(FontManager.f16, FontManager.f12,
			"原 f16 调用兼容别名也由同一个 CN 字体承担")
	var ui_font := FontManager.f12 as FontVariation
	assert_not_null(ui_font, "运行时字体使用可统一调形的 FontVariation")
	assert_almost_eq(ui_font.variation_embolden, 0.28, 0.001,
			"全局轻度加粗，修复 Regular 字重偏瘦")
	assert_almost_eq(ui_font.variation_transform.y.y, 0.94, 0.001,
			"字形纵向压缩 6%，降低瘦高感而不改控件几何")
	var base_font := ui_font.base_font as FontFile
	assert_eq(base_font.resource_path, BASE_FONT_PATH,
			"统一预设仍以完整 CN 字库作为基础")
	assert_eq(base_font.antialiasing, TextServer.FONT_ANTIALIASING_GRAY,
			"非 12px 整数倍字号使用灰度抗锯齿改善笔画取整")
	var theme := load("res://assets/themes/default_theme.tres") as Theme
	assert_eq(theme.default_font.resource_path, MAIN_FONT_PATH,
			"默认 Theme 同步使用加粗压扁后的统一预设")


func test_item_gallery_uses_shared_parchment_book_assets() -> void:
	var packed := load("res://src/ui/item_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var book := screen.find_child("CodexBook", true, false) as TextureRect
	var badge := screen.get_node("DetailArea/RarityBadge") as Control
	var badge_mark := badge.get_node("TypeMark") as Control
	assert_not_null(book, "道具图鉴使用与英雄图鉴一致的正式二维羊皮纸书素材")
	assert_eq(book.texture.resource_path, "res://assets/ui/hero_codex_book.png",
			"英雄与道具图鉴共享已通过的外框和纸张")
	assert_eq(book.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"书页素材不吞道具卡、标签与返回按钮点击")
	assert_null(screen.get_node_or_null("PoolArea/TierNavigation"),
			"左页不再保留可点击稀有度标签")
	assert_not_null(badge, "稀有度标签移动到右页道具图案下方")
	assert_eq(badge_mark.get_script().resource_path,
			"res://src/ui/components/hero_gallery_skill_type_mark.gd",
			"稀有度标签复用英雄图鉴主被动长方形印签组件")
	assert_null(badge.get_node_or_null("BadgeArt"), "不再叠加花哨的稀有度纸签贴图")
	assert_false(badge is Button, "右页稀有度标签只展示信息，不承担点击交互")
	assert_null(screen.find_child("Scroll", true, false), "旧手卷实体已移除")
	assert_null(screen.find_child("Backdrop", true, false), "旧山水衬底已移除")
	assert_null(screen.find_child("InkCloudsTop", true, false), "旧顶部墨云已移除")
	assert_null(screen.find_child("InkCloudsBottom", true, false), "旧底部墨云已移除")
	assert_null(screen.find_child("Plaque", true, false), "旧回纹牌匾已移除")
	assert_null(screen.find_child("Plate", true, false), "返回按钮不再叠加旧导航牌底")


func test_item_gallery_rarity_tabs_are_exact_three_x_pixel_assets() -> void:
	for tier: int in [1, 2, 3]:
		for state: String in ["idle", "selected"]:
			var path := "res://assets/ui/item_codex/rarity_tabs/tier_tab_t%d_%s.png" % [tier, state]
			var image := Image.new()
			assert_eq(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)), OK,
					"%s 源 PNG 可直接解码" % path)
			assert_eq(image.get_size(), Vector2i(150, 54), "%s 使用 150x54 显示尺寸" % path)
			assert_eq(image.get_pixel(0, 0).a, 0.0, "%s 保留透明外缘" % path)
			var exact_three_x := true
			for logical_y: int in 18:
				for logical_x: int in 50:
					var expected := image.get_pixel(logical_x * 3, logical_y * 3)
					for dy: int in 3:
						for dx: int in 3:
							if image.get_pixel(logical_x * 3 + dx, logical_y * 3 + dy) != expected:
								exact_three_x = false
			assert_true(exact_three_x, "%s 每个逻辑像素均为无插值的 3x3 色块" % path)


func test_item_gallery_first_batch_is_scene_backed_and_page_native() -> void:
	var item_packed := load("res://src/ui/item_gallery_screen.tscn") as PackedScene
	var item_screen := item_packed.instantiate()
	add_child_autofree(item_screen)
	var hero_packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var hero_screen := hero_packed.instantiate()
	add_child_autofree(hero_screen)
	var item_back := item_screen.get_node("TopBand/BackButton") as Button
	var hero_back := hero_screen.get_node("TopBand/BackButton") as Button
	assert_eq(item_back.text, hero_back.text, "两套图鉴使用同一返回文案")
	assert_eq(item_back.position, hero_back.position, "两套图鉴返回入口位置一致")
	assert_eq(item_back.size, hero_back.size, "两套图鉴返回入口尺寸一致")
	assert_eq(item_back.get_theme_font_size("font_size"),
			hero_back.get_theme_font_size("font_size"), "两套图鉴返回字号一致")
	assert_true(item_back.get_theme_stylebox("normal") is StyleBoxEmpty,
			"道具图鉴返回入口没有矩形底板")
	assert_false((item_screen.get_node("TopBand/Title") as Label).visible,
			"道具图鉴删除书脊上的重复总标题")
	assert_false((item_screen.get_node("TopBand/CountLabel") as Label).visible,
			"道具图鉴删除左页数量统计")
	var book_layer := item_screen.get_node("BookLayer") as Control
	var item_grid := item_screen.get_node("PoolArea/ItemGrid") as Control
	var page_navigation := item_screen.get_node("PoolArea/PageNavigation") as Control
	var rarity_badge := item_screen.get_node("DetailArea/RarityBadge") as Control
	assert_eq(book_layer.owner, item_screen, "书本根节点由场景承载")
	assert_eq(item_grid.owner, item_screen, "道具网格根节点由场景承载")
	assert_null(item_screen.get_node_or_null("PoolArea/TierNavigation"),
			"左页可点击稀有度索引已移除")
	assert_eq(rarity_badge.owner, item_screen, "右页只读稀有度纸签由场景承载")
	assert_eq(page_navigation.owner, item_screen, "分页入口由场景承载")
	assert_true(page_navigation.visible, "第二批启用超过一页时的书页导航")
	assert_eq(item_screen._cards[0].get_parent(), item_grid,
			"运行时道具卡只填入场景网格根节点")
	for node_path: String in [
		"DetailArea/ItemName", "DetailArea/DetailCell", "DetailArea/DetailFrame",
		"DetailArea/ItemIcon", "DetailArea/RarityBadge", "DetailArea/Description",
		"DetailArea/Flavor"]:
		assert_eq(item_screen.get_node(node_path).owner, item_screen,
				"详情节点由场景承载: %s" % node_path)
	assert_null(item_screen.find_child("ItemGalleryHint", true, false),
			"删除底部快捷键小字")


func test_item_gallery_second_batch_uses_twelve_card_pages() -> void:
	var packed := load("res://src/ui/item_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var grid := screen.get_node("PoolArea/ItemGrid") as Control
	var navigation := screen.get_node("PoolArea/PageNavigation") as Control
	var previous := navigation.get_node("PreviousPage") as Button
	var indicator := navigation.get_node("PageIndicator") as Label
	var next := navigation.get_node("NextPage") as Button
	var page_size: int = 12
	var page_count: int = screen._catalog_page_count()
	var tier_page_count: int = ceili(screen._items.size() / float(page_size))
	assert_eq(grid.get("columns"), 4, "道具图鉴每页使用 4 列")
	assert_eq(grid.get("cards_per_page"), page_size, "道具图鉴每页只展示 12 件")
	assert_true(navigation.visible, "完整道具图鉴超过一页时显示翻页导航")
	assert_eq(screen._cards.filter(func(card: Button) -> bool: return card.visible).size(),
			mini(page_size, screen._items.size()), "第一页只显示本页道具")
	assert_eq(indicator.text, "%02d / %02d" % [1, page_count], "页码使用两位图鉴编号")
	assert_true(previous.disabled, "第一页禁用上一页")
	assert_false(next.disabled, "存在下一页时允许翻页")
	next.pressed.emit()
	assert_eq(screen.get("_current_page"), 1, "下一页按钮进入第二页")
	assert_eq(screen._sel_idx, page_size, "翻页后保留当前格位并选择下一页首件")
	assert_eq(indicator.text, "%02d / %02d" % [2, page_count], "翻页后同步页码")
	assert_false(previous.disabled, "第二页允许返回")
	assert_false(next.disabled, "普通池仍有后续页面或稀有档时允许继续翻页")
	for expected_page: int in range(2, tier_page_count):
		next.pressed.emit()
		assert_eq(screen._tier, 1, "普通池扩充后应先遍历全部普通页面")
		assert_eq(screen.get("_current_page"), expected_page,
				"普通池扩充后进入对应档内页面")
	assert_eq(screen.get("_current_page"), tier_page_count - 1,
			"跨稀有度前停在普通最后一页")
	next.pressed.emit()
	assert_eq(screen._tier, 2, "普通最后一页继续点击下一页进入稀有档")
	assert_eq(screen.get("_current_page"), 0, "跨稀有度后进入新档第一页")
	assert_eq(screen._sel_idx, 0, "跨稀有度分页后保留第一页首格")
	assert_eq(indicator.text, "%02d / %02d" % [tier_page_count + 1, page_count],
			"跨稀有度后页码继续使用全图鉴序号")
	previous.pressed.emit()
	assert_eq(screen._tier, 1, "稀有第一页点击上一页返回普通最后一页")
	assert_eq(screen.get("_current_page"), tier_page_count - 1,
			"返回普通最后一页时恢复档内页码")
	assert_eq(screen._sel_idx, (tier_page_count - 1) * page_size,
			"返回上一档时保留当前格位")
	screen._select(screen._items.size() - 1)
	var right := InputEventAction.new()
	right.action = "ui_right"
	right.pressed = true
	screen._unhandled_input(right)
	assert_eq(screen._tier, 2, "方向键可从普通末件连续进入稀有首件")
	assert_eq(screen._sel_idx, 0, "方向键跨稀有度后选择新档首件")
	assert_eq(screen.get("_current_page"), 0, "方向键跨稀有度时同步档内页码")


func test_item_gallery_third_batch_uses_clean_right_page_hierarchy() -> void:
	var packed := load("res://src/ui/item_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var name_label := screen.get_node("DetailArea/ItemName") as Label
	var frame := screen.get_node("DetailArea/DetailFrame") as TextureRect
	var icon := screen.get_node("DetailArea/ItemIcon") as TextureRect
	var rarity_badge := screen.get_node("DetailArea/RarityBadge") as Control
	var description := screen.get_node("DetailArea/Description") as Label
	var flavor := screen.get_node("DetailArea/Flavor") as Label
	assert_null(screen.get_node_or_null("DetailArea/TierGroup"),
			"右页不恢复旧的阶级信息组")
	assert_not_null(rarity_badge, "右页道具图案下方展示单个只读稀有度纸签")
	assert_null(screen.get_node_or_null("DetailArea/DetailRule"),
			"右页使用留白而非突兀水平分割线")
	assert_lte(name_label.position.y + name_label.size.y, frame.position.y,
			"右页按道具名到大图标排列")
	assert_lte(frame.position.y + frame.size.y, rarity_badge.position.y,
			"稀有度纸签位于大图标下方")
	assert_lte(rarity_badge.position.y + rarity_badge.size.y, description.position.y,
			"效果描述位于稀有度纸签下方且保留留白")
	assert_lte(description.position.y + description.size.y, flavor.position.y,
			"风味文字独立位于效果描述下方")
	var page_center_x: float = ItemGalleryScreen.PAGE_R.position.x \
			+ ItemGalleryScreen.PAGE_R.size.x * 0.5
	for node: Control in [name_label, frame, icon, rarity_badge, description, flavor]:
		assert_almost_eq(node.position.x + node.size.x * 0.5, page_center_x, 0.01,
				"右页主轴节点保持居中: %s" % node.name)
	assert_eq(description.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"效果描述居中")
	assert_eq(description.vertical_alignment, VERTICAL_ALIGNMENT_CENTER,
			"效果描述在固定区域内垂直居中")
	assert_eq(description.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART,
			"效果描述按词智能换行")
	assert_gte(description.get_theme_constant("line_spacing"), 6,
			"多行效果描述保留清晰行距")
	assert_eq(flavor.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"风味文字居中")
	assert_eq(flavor.vertical_alignment, VERTICAL_ALIGNMENT_CENTER,
			"风味文字在固定区域内垂直居中")
	assert_gte(flavor.get_theme_font_size("font_size"), 18,
			"风味文字字号不再过小")
	assert_gte(flavor.get_theme_color("font_color").a, 0.8,
			"风味文字保持足够可读性")


func test_item_gallery_fill_overdraws_new_frame_inner_edge() -> void:
	assert_eq(ItemGalleryScreen.CELL_INSET_RATIO, 5.5 / 68.0,
			"道具图鉴格底轻微压到新框下，不再露出顶部纸色细缝")


func test_item_gallery_keeps_black_detail_name_and_legendary_asset() -> void:
	assert_eq(ItemGalleryScreen.CARDS_PER_PAGE, 12, "道具图鉴继续保持每页 12 件")
	assert_eq(ItemGalleryScreen.DETAIL_NAME_INK, Color("302820"),
			"右页道具名统一使用书页墨黑色")
	assert_eq(ItemGalleryScreen.CELL_FILL[1], ItemSlotRow.CELL_FILL_T[1],
			"普通格底与战斗道具栏使用同一蓝色外层")
	assert_eq(ItemGalleryScreen.CELL_FILL[2], ItemSlotRow.CELL_FILL_T[2],
			"稀有格底与战斗道具栏使用同一紫色外层")
	assert_eq(ItemGalleryScreen.CELL_CENTER[1], ItemSlotRow.CELL_CENTER_T[1],
			"普通格底中心色与战斗道具栏一致")
	assert_eq(ItemGalleryScreen.CELL_CENTER[2], ItemSlotRow.CELL_CENTER_T[2],
			"稀有格底中心色与战斗道具栏一致")
	for tier: int in range(1, 4):
		assert_eq(ItemGalleryScreen.FRAME_SHADOW[tier], ItemSlotRow.FRAME_SHADOW_T[tier],
				"图鉴阶级 %d 外框阴影与战斗道具栏一致" % tier)
		assert_eq(ItemGalleryScreen.FRAME_MID[tier], ItemSlotRow.FRAME_MID_T[tier],
				"图鉴阶级 %d 外框主体与战斗道具栏一致" % tier)
		assert_eq(ItemGalleryScreen.FRAME_HIGHLIGHT[tier], ItemSlotRow.FRAME_HIGHLIGHT_T[tier],
				"图鉴阶级 %d 外框高光与战斗道具栏一致" % tier)
	assert_eq(ItemGalleryGridPreview.PREVIEW_CELL_FILL, ItemSlotRow.CELL_FILL_T[1],
			"编辑器网格预览同步战斗道具栏普通格底")
	assert_eq(ItemGalleryGridPreview.PREVIEW_CELL_CENTER, ItemSlotRow.CELL_CENTER_T[1],
			"编辑器网格预览同步战斗道具栏普通中心层")

	var packed := load("res://src/ui/item_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var normal_cell := screen._cards[0].get_node_or_null("Cell") as ColorRect
	assert_not_null(normal_cell, "运行时道具格底有稳定节点名供可视化验证")
	if normal_cell == null:
		return
	var normal_material := normal_cell.material as ShaderMaterial
	assert_eq(normal_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_item_cell_bg.gdshader",
			"道具图鉴恢复战斗道具栏使用的共享格底 shader")
	assert_eq(float(normal_material.get_shader_parameter("vertical_gradient")), 1.0,
			"道具图鉴普通卡片使用静态上暗下亮渐变")
	var card_shadow := screen._cards[0].get_node_or_null("BottomShadow") as TextureRect
	assert_not_null(card_shadow, "图鉴中的每件道具都有右下轮廓阴影")
	assert_eq(card_shadow.position,
			(screen._cards[0].get_node("Frame") as TextureRect).position
			+ ItemFrameStyle.DROP_SHADOW_OFFSET,
			"图鉴道具阴影沿统一右下方向偏移")
	assert_not_null(screen.get_node_or_null("DetailArea/DetailShadow"),
			"右页大号道具同样保留右下轮廓阴影")
	var card_art_shadow := screen._cards[0].get_node_or_null("ItemArtShadow") as TextureRect
	assert_not_null(card_art_shadow, "图鉴卡片的道具美术补上右下 alpha 投影")
	assert_lt(card_art_shadow.get_index(),
			(screen._cards[0].get_node("Frame") as TextureRect).get_index(),
			"图鉴图案投影压在填充上且由金属框收边")
	assert_not_null(screen.get_node_or_null("DetailArea/ItemArtShadow"),
			"右页大号道具美术同步使用图案投影")
	assert_eq(screen._d_name.get_theme_color("font_color"),
			ItemGalleryScreen.DETAIL_NAME_INK, "普通道具名使用统一墨黑")

	screen._select_tier(2)
	assert_eq(screen._d_name.get_theme_color("font_color"),
			ItemGalleryScreen.DETAIL_NAME_INK, "稀有道具名仍使用统一墨黑")
	screen._select_tier(3)
	assert_eq(screen._d_name.get_theme_color("font_color"),
			ItemGalleryScreen.DETAIL_NAME_INK, "传说道具名仍使用统一墨黑")
	var legendary_cell := screen._cards[0].get_node("Cell") as ColorRect
	var legendary_material := legendary_cell.material as ShaderMaterial
	assert_eq(float(legendary_material.get_shader_parameter("use_tex")), 1.0,
			"传说道具继续启用原有底层贴图")
	assert_eq((legendary_material.get_shader_parameter("bg_tex") as Texture2D).resource_path,
			"res://assets/ui/gold_bottom.png", "传说底层资产保持不变")


func test_all_item_tiers_use_static_fill_and_shared_directional_shadow() -> void:
	var shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
	assert_false(shader_source.contains("gradient_anim") or shader_source.contains("TIME * gradient_anim"),
			"共享道具格完全移除渐变动画路径")
	for tier: int in range(1, 4):
		var material := ItemFrameStyle.make_cell_material(tier, 24.0)
		assert_eq(float(material.get_shader_parameter("vertical_gradient")),
				0.0 if tier == 3 else 1.0,
				"阶级 %d 保留静态填充配方" % tier)
	var shadow := ItemFrameStyle.make_frame_shadow(Vector2(10.0, 20.0), Vector2(68.0, 68.0))
	assert_eq(shadow.position, Vector2(10.0, 20.0) + ItemFrameStyle.DROP_SHADOW_OFFSET,
			"共享阴影固定向右下偏移")
	assert_eq(shadow.self_modulate.a, ItemFrameStyle.DROP_SHADOW_COLOR.a,
			"共享阴影透明度与战斗界面一致")
	shadow.free()
	var art_shadow := ItemFrameStyle.make_item_art_shadow(
			null, Vector2(10.0, 20.0), Vector2(192.0, 192.0))
	assert_eq(art_shadow.position, Vector2(14.0, 26.0),
			"大号道具图案投影按比例放大但封顶为 2 倍偏移")
	assert_eq(art_shadow.self_modulate, ItemFrameStyle.ITEM_ART_SHADOW_COLOR,
			"所有道具图案复用统一投影色")
	art_shadow.free()


func test_item_gallery_rarity_badge_tracks_selected_item_without_click_behavior() -> void:
	var packed := load("res://src/ui/item_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var badge := screen.get_node("DetailArea/RarityBadge") as Control
	var mark := badge.get_node("TypeMark") as Control
	var label := badge.get_node("BadgeLabel") as Label
	assert_eq(badge.size, Vector2(80.0, 34.0), "右页复用英雄图鉴主被动标签尺寸")
	assert_eq(label.text, "普通", "默认选择普通道具时显示普通")
	assert_eq(ItemGalleryScreen.TIER_TAG_COLOR[1], Color("7FA4B2"),
			"普通标签使用提亮后的书页蓝")
	assert_eq(ItemGalleryScreen.TIER_TAG_COLOR[2], Color("A08AAC"),
			"稀有标签使用提亮后的柔紫")
	assert_eq(ItemGalleryScreen.TIER_TAG_COLOR[3], Color("C39A4B"),
			"传说标签使用提亮后的古金")
	assert_almost_eq(float(mark.get("edge_alpha")), 0.55, 0.001,
			"道具稀有度标签暗边减淡，但不改英雄标签默认值")
	assert_eq(mark.get("passive_color"), ItemGalleryScreen.TIER_TAG_COLOR[1],
			"普通道具使用明度更高的蓝色长方形印签")
	assert_eq(badge.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"只读稀有度标签不拦截输入")
	screen._select_tier(2)
	assert_eq(label.text, "稀有", "选择稀有道具时标签文字同步更新")
	assert_eq(mark.get("passive_color"), ItemGalleryScreen.TIER_TAG_COLOR[2],
			"稀有道具使用克制紫色长方形印签")
	screen._select_tier(3)
	assert_eq(label.text, "传说", "选择传说道具时标签文字同步更新")
	assert_eq(mark.get("passive_color"), ItemGalleryScreen.TIER_TAG_COLOR[3],
			"传说道具使用克制金色长方形印签")


func test_item_gallery_selection_matches_hero_gallery_pointer_and_gold_frame() -> void:
	var packed := load("res://src/ui/item_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var first_card := screen._cards[0] as Button
	var first_pointer := first_card.get_node("SelectionPointer") as Control
	var first_frame := first_card.get_node("Frame") as TextureRect
	var first_material := first_frame.material as ShaderMaterial
	assert_true(first_pointer.visible, "默认选中道具显示英雄图鉴同款侧签箭头")
	assert_eq(first_pointer.get_script().resource_path,
			"res://src/ui/components/hero_gallery_selection_marker.gd",
			"选中箭头直接复用英雄图鉴粗像素三角组件")
	assert_eq(first_pointer.get("color"), HeroGalleryScreen.POINTER_COLOR,
			"道具箭头与英雄箭头使用同一书页棕色")
	assert_null(first_card.get_node_or_null("SelRing"), "移除道具图鉴旧金色呼吸外环")
	assert_eq(first_material.get_shader_parameter("shadow_color"),
			HeroGalleryScreen.FRAME_SELECTED_SHADOW, "选中道具框使用英雄图鉴同款金色阴影")
	assert_eq(first_material.get_shader_parameter("mid_color"),
			HeroGalleryScreen.FRAME_SELECTED_MID, "选中道具框使用英雄图鉴同款金色主体")
	assert_eq(first_material.get_shader_parameter("highlight_color"),
			HeroGalleryScreen.FRAME_SELECTED_HIGHLIGHT, "选中道具框使用英雄图鉴同款金色高光")
	assert_eq((first_card.get_node("ItemName") as Label).get_theme_color("font_color"),
			HeroGalleryScreen.SELECTED_NAME_INK, "选中道具名使用英雄图鉴同款克制赭色")
	screen._select(1)
	assert_false(first_pointer.visible, "切换道具后旧箭头立即隐藏")
	assert_eq(first_material.get_shader_parameter("mid_color"),
			ItemGalleryScreen.FRAME_MID[1], "旧道具框恢复自身稀有度配色")
	assert_eq((first_card.get_node("ItemName") as Label).get_theme_color("font_color"),
			ItemGalleryScreen.INK, "切换后旧道具名恢复书页墨色")
	assert_true(screen._cards[1].get_node("SelectionPointer").visible,
			"切换道具后箭头移动到新道具框")


func test_battle_switch_module_expands_right_and_owns_active_switch() -> void:
	# 普通切换迁移到左下独立模块；顶部头像保留悬停说明和道具选人职责。
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen1.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.state = 1   # BattleScreen.State.PLAYER_SELECT
	screen._refresh_switch_module()
	assert_false(screen.btn_switch.disabled, "存在存活替补时左下切换按钮可用")
	screen.btn_switch.pressed.emit()
	assert_true(screen._switch_tray.visible, "切换候选从左下主按钮展开")
	assert_eq(screen._switch_candidate_frames.size(), 2, "三人队伍显示两名替补候选")
	var first_candidate: HeroFrame = screen._switch_candidate_frames[0]
	var second_candidate: HeroFrame = screen._switch_candidate_frames[1]
	assert_not_null(first_candidate.get_node_or_null("Portrait"),
			"切换候选实例化正式 HeroFrame 场景而不是无头像空壳")
	assert_not_null((first_candidate.get_node("Portrait") as TextureRect).texture,
			"左侧第一候选显示与顶部对应的英雄头像")
	assert_gt(screen._switch_candidate_frames[1].position.x,
			screen._switch_candidate_frames[0].position.x,
			"第二名候选位于第一名右侧，展开方向符合阅读惯性")
	assert_false(Rect2(first_candidate.position, first_candidate.size).intersects(
			Rect2(second_candidate.position, second_candidate.size)),
			"展开动画首帧两张候选点击区域也不重叠")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	screen.p1_frames[1].gui_input.emit(click)
	assert_eq(screen._armed_switch_frame, -1, "顶部替补头像不再触发普通切换")
	var expected_left_slot: int = screen.p1_frame_slots[1]
	var right_slot: int = screen.p1_frame_slots[2]
	first_candidate.gui_input.emit(click)
	assert_eq(screen._armed_switch_frame, 1, "左下候选头像进入对应替补的切换态")
	assert_eq(screen.selected_switch, expected_left_slot,
			"底部左侧第一候选严格对应顶部左侧第一名队友")
	assert_ne(screen.selected_switch, right_slot,
			"左侧候选不会再被右侧第二候选覆盖并误选")
	assert_eq(screen.selected_action, ActionDef.Action.SWITCH,
			"新模块继续复用成熟的切换动作提交语义")
	assert_true(screen._switch_tray.visible, "选定候选后保持展开层，避免选择反馈瞬间消失")
	assert_true(first_candidate.is_selected, "已选候选持续高亮")
	assert_eq(screen.btn_switch.text, "已选", "切换主按钮同步表达待提交状态")
	assert_true(bool(screen.btn_switch.get_meta("switch_selected", false)),
			"切换主按钮保留明确的选中态")
	BattleSetup.reset()


func test_dead_battle_hero_uses_grayscale_and_cracked_existing_frame() -> void:
	var frame := (load("res://src/ui/components/hero_frame.tscn") as PackedScene).instantiate() as HeroFrame
	add_child_autofree(frame)
	frame.diamond_mode = true
	frame.portrait_path = "res://assets/sprites/heroes/h01/h01_portrait.png"
	frame.is_dead = true
	await get_tree().process_frame
	assert_null(frame.get_node_or_null("DeathCross"), "淘汰态不再用大红叉覆盖角色")
	assert_null(frame.get_node_or_null("DeathFracture"), "淘汰态不再叠加底部断角或额外裂痕节点")
	var diamond := frame.get_node("DiamondFrame") as ColorRect
	var diamond_material := diamond.material as ShaderMaterial
	assert_eq(bool(diamond_material.get_shader_parameter("fractured")), true,
			"裂痕直接启用在现有菱形边框材质内")
	var portrait := frame.get_node("Portrait") as TextureRect
	var material := portrait.material as ShaderMaterial
	assert_almost_eq(float(material.get_shader_parameter("desaturation")), 0.90, 0.001,
			"淘汰头像大幅去饱和但保留身份轮廓")
	assert_almost_eq(float(material.get_shader_parameter("brightness")), 0.48, 0.001,
			"淘汰头像压暗而非完全抹黑")
	frame.is_dead = false
	assert_eq(bool(diamond_material.get_shader_parameter("fractured")), false,
			"英雄恢复可用时边框裂痕同步清除")


func test_battle_hud_only_shows_reduced_dynamic_energy_cap() -> void:
	BattleSetup.reset()
	var packed := load("res://src/ui/battle_screen1.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.battle.energy_max.assign([20, 17])
	screen.battle.energy.assign([20, 20])
	screen._update_energy_labels()
	assert_false(screen.p1_energy_cap_label.visible,
			"默认 10 点上限不额外占用 HUD 空间")
	assert_true(screen.p2_energy_cap_label.visible,
			"被天狗压低后应持续显示敌方动态上限")
	assert_eq(screen.p2_energy_cap_label.text, "能量上限 8.5",
			"半能上限按玩家单位显示")
	assert_eq(screen.battle.energy[1], 20,
			"刷新 HUD 不得删除高于新上限的既有能量")
	BattleSetup.reset()


func test_death_switch_uses_battle_diamond_frame_and_slant_hp() -> void:
	var packed := load("res://src/ui/components/death_switch_overlay.tscn") as PackedScene
	var overlay := packed.instantiate()
	add_child_autofree(overlay)
	var hero := load("res://assets/data/heroes/h01.tres") as HeroData
	overlay.show_selection(0, [[1, hero, 4.5]])
	var avatar := overlay.find_child("HeroFrame", true, false) as HeroFrame
	var hp_row := overlay.find_child("HpRow", true, false)
	assert_not_null(avatar, "被迫换人头像复用战斗 UI 的 HeroFrame")
	assert_true(avatar.diamond_mode, "被迫换人头像使用战斗 UI 菱形模式")
	assert_not_null(avatar.get_node_or_null("DiamondFrame"), "菱形框已真实建立")
	assert_not_null(hp_row, "被迫换人使用平行四边形+数字血量")
	assert_true(hp_row is ReserveHpRow, "血量展示复用现役 ReserveHpRow")
	assert_eq(hp_row.size, DeathSwitchOverlay.HP_ROW_SIZE,
			"被迫换人血量行同步顶部替补的 92x28 最新版心")
	assert_almost_eq(hp_row.get_rect().get_center().x, DeathSwitchOverlay.FRAME_SIZE * 0.5,
			0.01, "死亡换人血量行与头像严格居中")
	assert_almost_eq(hp_row.icon_w / hp_row.icon_h, 26.0 / 9.0, 0.01,
			"死亡换人同步细长血条比例")
	assert_eq(absf(hp_row.icon_slant), 3.0,
			"死亡换人同步最新版血条斜率")
	assert_true(hp_row.bottom_shadow_enabled,
			"死亡换人血条和数字启用现役右下投影")
	assert_eq(hp_row.number_shadow_offset, Vector2(2.0, 3.0),
			"死亡换人数字同步整数像素投影")
	watch_signals(overlay)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	avatar.gui_input.emit(click)
	assert_signal_emitted_with_parameters(overlay, "selection_made", [1])


func test_main_menu_profile_avatar_uses_item_frame() -> void:
	var packed := load("res://src/ui/main_menu.tscn") as PackedScene
	var menu := packed.instantiate()
	add_child_autofree(menu)
	var avatar := menu.get_node("UI/IdentityButton/AvatarFrame")
	assert_eq(avatar.get_script(), ItemAvatarFrameScript,
			"主菜单个人资料头像使用新版 item_frame 组件")
	assert_null(avatar.get_node_or_null("Bg"), "主菜单头像不存在旧 HeroFrame 边框层")
	assert_eq(avatar.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"头像区域继续把点击交给个人资料入口按钮")


func test_hero_gallery_uses_new_item_frame_geometry() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var small := screen.find_child("GalleryItemFrame", true, false) as TextureRect
	var wash := screen.find_child("HeroPortraitWash", true, false) as TextureRect
	assert_not_null(small, "英雄列表使用新版道具框")
	assert_not_null(wash, "英雄详情使用透明蓝灰笔刷衬底")
	var portrait_root := small.get_parent()
	assert_eq(portrait_root.name, "HeroPortraitFrame", "英雄缩略图使用图鉴专用节点，不覆盖旧组件")
	assert_null(portrait_root.get_node_or_null("Bg"), "英雄缩略图节点中不存在旧 HeroFrame 边框层")
	assert_not_null(portrait_root.get_node_or_null("HeroThumbCell"), "英雄缩略图拥有独立填充层")
	assert_not_null(portrait_root.get_node_or_null("HeroPortrait"), "英雄缩略图拥有独立头像层")
	assert_eq(small.size, Vector2(HeroGalleryScreen.BOX, HeroGalleryScreen.BOX) * HeroGalleryScreen.FRAME_ART_SCALE,
			"英雄列表框补偿新素材透明边")
	assert_null(screen.find_child("HeroDetailItemFrame", true, false),
			"英雄详情不再使用带包角感的大号道具框")
	assert_null(screen.find_child("HeroDetailStage", true, false),
			"英雄详情不再保留旧灰色矩形展示台")


func test_hero_gallery_uses_parchment_book_assets() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var book := screen.find_child("CodexBook", true, false) as TextureRect
	var wash := screen.find_child("HeroPortraitWash", true, false) as TextureRect
	assert_not_null(book, "英雄图鉴使用正式二维羊皮纸书素材")
	assert_eq(book.texture.resource_path, "res://assets/ui/hero_codex_book.png",
			"英雄图鉴书页引用已通过的正式素材")
	assert_not_null(wash, "英雄详情使用独立透明笔刷素材")
	assert_eq(wash.texture.resource_path, "res://assets/ui/hero_codex_portrait_wash.png",
			"角色衬底引用已通过的无噪点笔刷")
	assert_eq(book.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"书页素材不吞头像与返回按钮点击")
	assert_eq(wash.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"角色笔刷不吞详情区输入")
	assert_null(screen.find_child("OuterShell", true, false),
			"英雄图鉴彻底移除旧蓝灰程序化外壳")
	assert_null(screen.find_child("CodexPaper", true, false),
			"英雄图鉴不在正式书页素材上叠加旧纸板")
	assert_null(screen.find_child("Scroll", true, false),
			"英雄图鉴彻底移除旧手卷实体")
	assert_null(screen.find_child("Plaque", true, false),
			"英雄图鉴彻底移除旧回纹牌匾")
	assert_null(screen.find_child("Plate", true, false),
			"返回按钮不再叠加旧导航牌皮")


func test_hero_gallery_header_uses_page_native_navigation() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var title := screen.get_node("TopBand/Title") as Label
	var back := screen.get_node("TopBand/BackButton") as Button
	assert_false(title.visible, "书脊上不再悬浮重复的英雄图鉴总标题")
	assert_true(back.get_theme_stylebox("normal") is StyleBoxEmpty,
			"返回入口默认无矩形底板和边框")
	assert_eq(back.text, "<<< 返回", "返回入口使用与翻页一致的三段书页导航符号")
	var previous := screen.get_node("PoolArea/PageNavigation/PreviousPage") as Button
	var next := screen.get_node("PoolArea/PageNavigation/NextPage") as Button
	assert_eq(back.size, previous.size, "返回与上一页拥有相同点击尺寸")
	assert_eq(previous.size, next.size, "上一页与下一页拥有相同点击尺寸")
	assert_eq(back.get_theme_font_size("font_size"), previous.get_theme_font_size("font_size"),
			"返回与翻页文字字号统一")
	assert_eq(previous.global_position.y, next.global_position.y, "上一页和下一页处于同一基线")
	assert_lt(back.global_position.y, 150.0, "返回入口固定在左页顶部")
	assert_gt(previous.global_position.y, 850.0, "翻页入口固定在左页底部")
	assert_null(back.get_node_or_null("ReturnUnderline"), "返回入口移除突兀的独立下划线")
	assert_null(back.get_node_or_null("Plate"), "返回入口不恢复旧导航牌皮")


func test_hero_gallery_uses_twelve_card_pages_with_scene_backed_navigation() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var grid := screen.get_node("PoolArea/PortraitGrid") as Control
	var navigation := screen.get_node("PoolArea/PageNavigation") as Control
	var previous := screen.get_node("PoolArea/PageNavigation/PreviousPage") as Button
	var indicator := screen.get_node("PoolArea/PageNavigation/PageIndicator") as Label
	var next := screen.get_node("PoolArea/PageNavigation/NextPage") as Button
	assert_eq(grid.get("columns"), 4, "英雄图鉴每页使用 4 列")
	assert_eq(grid.get("cards_per_page"), 12, "英雄图鉴每页只展示 12 位英雄")
	assert_lte(float(grid.get("step_x")), 170.0, "头像列距收紧，不在左页横向松散铺开")
	assert_lte(float(grid.get("row_height")), 196.0, "头像行距收紧，形成完整名录组块")
	assert_eq(screen.card_cards.filter(func(card: Button) -> bool: return card.visible).size(), 12,
			"第一页运行时只显示 12 个头像")
	assert_eq(previous.text, "<<< 上一页", "上一页与返回入口使用同一导航语言")
	assert_eq(next.text, "下一页 >>>", "下一页与返回入口使用同一导航语言")
	assert_true(previous.disabled, "第一页禁用上一页")
	assert_false(next.disabled, "第一页允许进入下一页")
	assert_eq(indicator.text, "01 / 02", "页码使用图鉴式两位编号")
	assert_eq(indicator.get_theme_font_size("font_size"), 22, "页码放大后仍略小于翻页文字")
	screen._turn_page(1)
	assert_eq(screen._sel_idx, 12, "下一页保留当前格位并选择第 13 位英雄")
	assert_eq(screen.card_cards.filter(func(card: Button) -> bool: return card.visible).size(), 12,
			"第二页运行时只显示 12 个头像")
	assert_false(screen.card_cards[0].visible, "翻页后隐藏第一页头像")
	assert_true(screen.card_cards[12].visible, "翻页后显示第二页对应格位")
	assert_eq(indicator.text, "02 / 02", "翻页后同步两位页码")
	assert_false(previous.disabled, "第二页允许返回上一页")
	assert_true(next.disabled, "最后一页禁用下一页")


func test_hero_gallery_selection_uses_book_pointer_and_gold_outer_frame() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var first_card := screen.card_cards[0] as Button
	var first_pointer := first_card.get_node("SelectionPointer") as Control
	var first_frame := screen.card_frames[0].get_node("GalleryItemFrame") as TextureRect
	var first_material := first_frame.material as ShaderMaterial
	assert_true(first_pointer.visible, "默认选中英雄显示书页侧签指针")
	assert_eq(first_pointer.get("color"), HeroGalleryScreen.POINTER_COLOR,
			"侧签指针使用书本棕色而不是金色")
	assert_eq(first_pointer.get_script().resource_path,
			"res://src/ui/components/hero_gallery_selection_marker.gd",
			"侧签使用完整双色像素组件而不是散乱色块")
	assert_null(first_card.get_node_or_null("SelRing"), "删除不贴合真实框形的金色方框高光")
	assert_eq(first_material.get_shader_parameter("mid_color"),
			HeroGalleryScreen.FRAME_SELECTED_MID, "选中时真实头像框材质转为金色")
	assert_eq(screen.card_name_labels[0].get_theme_color("font_color"),
			HeroGalleryScreen.SELECTED_NAME_INK, "选中英雄名使用克制赭色")
	screen._select(1)
	assert_eq(first_material.get_shader_parameter("mid_color"), HeroGalleryScreen.FRAME_MID,
			"切换后旧头像框恢复书页暖褐色")
	assert_false(first_pointer.visible, "切换英雄后旧侧签立即隐藏")
	assert_true(screen.card_cards[1].get_node("SelectionPointer").visible,
			"切换英雄后侧签移动到新头像")


func test_hero_gallery_detail_uses_authored_skill_type_and_page_rule() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var mark := screen.get_node("DetailArea/SkillTypeGroup/TypeMark") as Control
	var tag := screen.get_node("DetailArea/SkillTypeGroup/TypeLabel") as Label
	var tag_group := screen.get_node("DetailArea/SkillTypeGroup") as Control
	var rule := screen.find_child("DetailRule", true, false) as ColorRect
	assert_eq(mark.get_script().resource_path,
			"res://src/ui/components/hero_gallery_skill_type_mark.gd",
			"主被动类型使用独立像素印记组件")
	assert_true(bool(mark.get("passive")), "默认英雄显示靛蓝空心被动印")
	assert_eq(tag.text, "被动", "类型文字跟在技能名后方")
	screen._select(4)
	assert_false(bool(mark.get("passive")), "h05 龙御极属于玩家主动选择的行动强化")
	assert_eq(tag.text, "主动", "h05 英雄图鉴标签显示主动")
	screen._select(12)
	assert_false(bool(mark.get("passive")), "h13 暗潮属于玩家主动选择的行动强化")
	assert_eq(tag.text, "主动", "h13 英雄图鉴标签显示主动")
	screen._select(13)
	assert_false(bool(mark.get("passive")), "主动英雄切换为朱砂实心动印")
	assert_eq(tag.text, "主动", "主动印仍保留明确文字，不只依赖抽象图案")
	var tag_center_y: float = tag_group.position.y + tag_group.size.y * 0.5
	var skill_center_y: float = \
			screen._d_skill_name.position.y + screen._d_skill_name.size.y * 0.5
	assert_almost_eq(tag_center_y, skill_center_y, 0.5,
			"主被动标签与技能名称保持同一视觉中心")
	assert_not_null(rule, "技能说明使用书页细竖线建立层级")
	assert_eq(rule.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"说明装饰线不参与输入")


	var detail := screen.find_child("SkillDetail", true, false) as Label
	assert_eq(detail.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"skill detail is centered on the right page")


func test_hero_gallery_hp_and_idle_shadow_are_scene_editable() -> void:
	var packed := load("res://src/ui/hero_gallery_screen.tscn") as PackedScene
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var hp_group := screen.get_node("DetailArea/HPGroup") as Control
	var heart := hp_group.get_node("Heart") as TextureRect
	var number := hp_group.get_node("Number") as Label
	var shadow := screen.get_node("DetailArea/HeroIdleShadow") as Polygon2D
	var heart_number_gap := number.position.x - (heart.position.x + heart.size.x)
	assert_gt(heart_number_gap, 18.0, "爱心和数字保留清楚的横向间距")
	assert_lt(number.position.y, heart.position.y, "数字向上校正，不再低于爱心")
	assert_true(heart.texture is AtlasTexture, "血量爱心恢复为静态首帧")
	var hp_group_position := hp_group.position
	var heart_position := heart.position
	var number_position := number.position
	screen._select(1)
	assert_eq(hp_group.position, hp_group_position, "换英雄不覆盖手动调整的血量组位置")
	assert_eq(heart.position, heart_position, "换英雄不覆盖手动调整的爱心位置")
	assert_eq(number.position, number_position, "换英雄不覆盖手动调整的数字位置")
	assert_gt(shadow.polygon.size(), 8, "角色脚下使用简洁的扁平像素阴影")
	assert_gt(shadow.color.a, 0.0, "角色阴影在运行时可见")


func test_battle_codex_tabs_use_flat_neutral_buttons() -> void:
	var overlay := BattleCodexOverlay.new()
	add_child_autofree(overlay)
	var hero_tab := overlay.get_node("Tab0") as Button
	var item_tab := overlay.get_node("Tab1") as Button
	assert_true(hero_tab.get_theme_stylebox("normal") is StyleBoxFlat,
			"英雄页签使用平面几何按钮")
	assert_true(item_tab.get_theme_stylebox("normal") is StyleBoxFlat,
			"道具页签使用同一套平面几何按钮")
	assert_null(hero_tab.find_child("Plaque", true, false),
			"共享页签不再包含回纹牌匾节点")


func test_battle_codex_overlay_stays_non_pausing_and_closes_cleanly() -> void:
	var overlay := BattleCodexOverlay.new()
	add_child_autofree(overlay)
	overlay.open()
	assert_true(overlay.visible, "战斗图鉴仍可正常打开")
	assert_false(get_tree().paused, "打开战斗图鉴不暂停对局计时")
	overlay.close()
	assert_false(overlay.visible, "战斗图鉴仍可正常关闭")
	assert_false(get_tree().paused, "关闭战斗图鉴后对局仍保持运行")


func test_unified_codex_frames_reduced_book_on_smoky_backdrop() -> void:
	var packed := load("res://src/ui/codex_screen.tscn") as PackedScene
	assert_not_null(packed, "统一图鉴场景存在")
	if packed == null:
		return
	var screen := packed.instantiate()
	add_child_autofree(screen)
	var backdrop := screen.get_node("Backdrop") as TextureRect
	var book_shadow := screen.get_node("BookContactShadow") as ColorRect
	var host := screen.get_node("GalleryHost") as Control
	var chapter_hero := screen.get_node("BookmarkLayer/HeroBookmark") as Button
	var chapter_item := screen.get_node("BookmarkLayer/ItemBookmark") as Button
	var rarity_group := screen.get_node("BookmarkLayer/RarityBookmarks") as Control
	var normal := rarity_group.get_node("Normal") as Button
	assert_eq(backdrop.texture.resource_path,
			"res://assets/ui/codex/codex_smoky_brown_backdrop.png",
			"统一图鉴使用通过方向的低饱和烟褐背景")
	assert_eq(backdrop.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"烟褐背景保持比例覆盖 1920x1080")
	assert_eq(backdrop.mouse_filter, Control.MOUSE_FILTER_IGNORE,
			"背景不拦截书页与侧签输入")
	assert_eq(host.position, UnifiedCodexScreen.BOOK_ORIGIN,
			"书本左侧留出真实侧签空间")
	assert_eq(host.size, Vector2(1920, 1080), "内部书页继续使用原始设计坐标")
	assert_eq(host.scale, UnifiedCodexScreen.BOOK_SCALE,
			"英雄与道具共享同一缩书比例")
	assert_eq(host.size * host.scale, Vector2(1680, 945),
			"书本显示尺寸锁定为 1680x945")
	assert_eq(book_shadow.position, UnifiedCodexScreen.BOOK_ORIGIN + Vector2(12, 12),
			"接触影只向右下偏移 12px")
	assert_eq(book_shadow.size, Vector2(1680, 945),
			"接触影与缩小后的书本边界一致")
	assert_gt(book_shadow.color.a, 0.0, "烟褐背景上保留克制的书本接触影")
	assert_eq(chapter_hero.text, "英雄")
	assert_eq(chapter_item.text, "道具")
	assert_lt(normal.size.x, chapter_item.size.x, "稀有度子标签比主章节标签更小")
	assert_gt(normal.position.x + rarity_group.position.x, chapter_item.position.x,
			"稀有度子标签向书页内缩，形成二级层级")
	assert_lt(chapter_hero.position.x, UnifiedCodexScreen.BOOK_ORIGIN.x,
			"章节签主体位于缩书后释放的左侧背景区")
	assert_lte(chapter_hero.position.x + chapter_hero.size.x,
			UnifiedCodexScreen.BOOK_ORIGIN.x + 40.0,
			"选中章节签只有根部插入书封，不挤占左页内容")
	assert_lte(chapter_item.position.x + chapter_item.size.x,
			UnifiedCodexScreen.BOOK_ORIGIN.x + 60.0,
			"未选章节签向书内收起，但仍停在封皮区")
	assert_lte(normal.position.x + rarity_group.position.x + normal.size.x,
			UnifiedCodexScreen.BOOK_ORIGIN.x + 24.0,
			"稀有度小侧签保持在背景边距，只让根部藏入封皮")
	assert_false(rarity_group.visible, "英雄图鉴中稀有度标签保持收起")
	assert_lt(chapter_hero.position.x, chapter_item.position.x,
			"选中主签向左抽出，未选中主签向右藏入书页")
	assert_eq(chapter_hero.scale, Vector2.ONE, "侧签切换不使用破坏真像素的缩放动效")
	var hero_gallery := screen.call("get_gallery", 0) as Control
	assert_not_null(hero_gallery)
	assert_eq(hero_gallery.position, Vector2.ZERO)
	assert_eq(hero_gallery.scale, Vector2.ONE,
			"英雄图鉴内部不二次缩放，由统一书本容器负责构图")

	screen.call("show_section", 1)
	assert_true(rarity_group.visible, "进入道具图鉴后展开普通/稀有/传说快速索引")
	await get_tree().create_timer(0.28).timeout
	assert_lt(chapter_item.position.x, chapter_hero.position.x,
			"切到道具后，道具签向左抽出、英雄签向右收回")
	assert_eq((rarity_group.get_node("Normal") as Button).position.y, 0.0)
	assert_eq((rarity_group.get_node("Rare") as Button).position.y, 34.0)
	assert_eq((rarity_group.get_node("Legendary") as Button).position.y, 68.0)
	assert_eq((rarity_group.get_node("Normal") as Button).size.y, 30.0,
			"稀有度签收紧为连续的页码索引组")
	var item_gallery := screen.call("get_gallery", 1) as Control
	assert_not_null(item_gallery)
	assert_eq(item_gallery.position, Vector2.ZERO)
	assert_eq(item_gallery.scale, Vector2.ONE,
			"道具图鉴内部不二次缩放并保持与英雄图鉴一致")
	(rarity_group.get_node("Rare") as Button).pressed.emit()
	assert_eq(int(item_gallery.get("_tier")), 2, "稀有侧签跳到稀有道具第一页")
	assert_eq(int(item_gallery.get("_current_page")), 0)
	assert_true(bool((rarity_group.get_node("Rare") as Button).button_pressed),
			"快速导航后选中态同步到稀有侧签")
	(rarity_group.get_node("Normal") as Button).pressed.emit()
	var crossing_guard := 0
	while int(item_gallery.get("_tier")) == 1 and crossing_guard < 20:
		item_gallery.call("_turn_page", 1)
		crossing_guard += 1
	assert_eq(int(item_gallery.get("_tier")), 2,
			"普通最后一页继续下一页会自动进入稀有第一页")
	assert_true(bool((rarity_group.get_node("Rare") as Button).button_pressed),
			"底部分页跨稀有度时，侧签选中态自动跟随")

	item_gallery.call("_select", 1)
	screen.call("show_section", 0)
	hero_gallery.call("_turn_page", 1)
	var hero_page := int(hero_gallery.get("_current_page"))
	screen.call("show_section", 1)
	assert_eq(int(item_gallery.get("_sel_idx")), 1, "返回道具章节时保留上次选中道具")
	screen.call("show_section", 0)
	assert_eq(int(hero_gallery.get("_current_page")), hero_page,
			"返回英雄章节时保留上次页码")


func test_codex_bookmark_assets_are_hard_edge_true_pixel_pngs() -> void:
	var specs := {
		"res://assets/ui/codex/bookmark_chapter_left.png": Vector2i(148, 48),
		"res://assets/ui/codex/bookmark_rarity_left.png": Vector2i(102, 32),
	}
	for path: String in specs:
		assert_true(FileAccess.file_exists(path), "%s 存在" % path)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.new()
		assert_eq(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)), OK)
		assert_eq(image.get_size(), specs[path], "%s 使用锁定显示尺寸" % path)
		assert_eq(image.get_pixel(0, 0).a, 0.0, "%s 外露左上角削角" % path)
		assert_eq(image.get_pixel(0, image.get_height() - 1).a, 0.0,
				"%s 外露左下角削角" % path)
		assert_eq(image.get_pixel(image.get_width() - 1, 0).a, 1.0,
				"%s 插入书页的右上角保持平直实心" % path)
		assert_eq(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a, 1.0,
				"%s 插入书页的右下角保持平直实心" % path)
		var hard_alpha := true
		for y: int in image.get_height():
			for x: int in image.get_width():
				var alpha := image.get_pixel(x, y).a
				if alpha != 0.0 and alpha != 1.0:
					hard_alpha = false
		assert_true(hard_alpha, "%s 不保留半透明毛边" % path)
		var exact_two_x := true
		for logical_y: int in int(image.get_height() / 2.0):
			for logical_x: int in int(image.get_width() / 2.0):
				var expected := image.get_pixel(logical_x * 2, logical_y * 2)
				for dy: int in 2:
					for dx: int in 2:
						if image.get_pixel(logical_x * 2 + dx, logical_y * 2 + dy) != expected:
							exact_two_x = false
		assert_true(exact_two_x, "%s 每个逻辑像素为无插值的 2x2 色块" % path)
