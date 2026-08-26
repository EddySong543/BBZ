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
	assert_eq(item_grid.position.y, 255.0, "道具头像框组轻微上移 10px")
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
	assert_eq(previous.text, "上一页")
	assert_eq(next.text, "下一页", "道具图鉴移除旧三重箭头，与英雄图鉴分页文案一致")
	assert_eq(navigation.position.x, grid.position.x,
			"道具图鉴分页行与四列道具内容使用同一水平起点")
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
	assert_eq(description.vertical_alignment, VERTICAL_ALIGNMENT_TOP,
			"效果描述从固定区域顶边开始排版")
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


func test_item_gallery_keeps_black_detail_name_and_unified_full_gradient() -> void:
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
	assert_null(card_shadow, "左页道具框不再向书页投射外部轮廓阴影")
	assert_null(screen.get_node_or_null("DetailArea/DetailShadow"),
			"右页大号道具框同步移除书页投影")
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
	assert_eq(float(legendary_material.get_shader_parameter("use_tex")), 0.0,
			"传说道具停用旧金色底图")
	assert_eq(float(legendary_material.get_shader_parameter("vertical_gradient")), 1.0,
			"传说与普通、稀有统一使用完整纵向渐变")
	assert_eq(legendary_material.get_shader_parameter("fill_color"),
			ItemFrameStyle.CELL_TOP[3], "传说顶部色读取共享方案 2")
	assert_eq(legendary_material.get_shader_parameter("inner_color"),
			ItemFrameStyle.CELL_BOTTOM[3], "传说底部色读取共享方案 2")


func test_all_item_tiers_use_static_fill_and_shared_directional_shadow() -> void:
	var shader_source := FileAccess.get_file_as_string(
			"res://assets/shaders/canvas_ui_item_cell_bg.gdshader")
	assert_false(shader_source.contains("gradient_anim") or shader_source.contains("TIME * gradient_anim"),
			"共享道具格完全移除渐变动画路径")
	for tier: int in range(1, 4):
		var material := ItemFrameStyle.make_cell_material(tier, 24.0)
		assert_eq(float(material.get_shader_parameter("vertical_gradient")), 1.0,
				"阶级 %d 统一使用静态完整渐变" % tier)
		assert_eq(float(material.get_shader_parameter("use_tex")), 0.0,
				"阶级 %d 不叠加旧底图" % tier)
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
	assert_eq(ItemGalleryScreen.TIER_TAG_COLOR[1], ItemCatalog.RARITY_NORMAL,
			"普通标签使用全局方案 2 高识别蓝")
	assert_eq(ItemGalleryScreen.TIER_TAG_COLOR[2], ItemCatalog.RARITY_RARE,
			"稀有标签使用全局方案 2 高识别紫")
	assert_eq(ItemGalleryScreen.TIER_TAG_COLOR[3], ItemCatalog.RARITY_LEGENDARY,
			"传说标签使用全局方案 2 高识别金")
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


func test_item_gallery_selection_keeps_rarity_frame_and_uses_pointer() -> void:
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
			ItemGalleryScreen.FRAME_SHADOW[1], "选中普通道具使用方案 2 蓝色暗阶")
	assert_eq(first_material.get_shader_parameter("mid_color"),
			ItemGalleryScreen.FRAME_MID[1], "选中普通道具使用方案 2 蓝色主体")
	assert_eq(first_material.get_shader_parameter("highlight_color"),
			ItemGalleryScreen.FRAME_HIGHLIGHT[1], "选中普通道具使用方案 2 蓝色高光")
	assert_eq((first_card.get_node("ItemName") as Label).get_theme_color("font_color"),
			HeroGalleryScreen.SELECTED_NAME_INK, "选中道具名使用英雄图鉴同款克制赭色")
	screen._select(1)
	assert_false(first_pointer.visible, "切换道具后旧箭头立即隐藏")
	assert_eq(first_material.get_shader_parameter("mid_color"),
			ItemGalleryScreen.FRAME_MID[1], "旧道具框持续保留自身稀有度配色")
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
	assert_eq(screen.btn_switch.text, "", "切换主按钮不再残留文字")
	var switch_icon := screen.btn_switch.get_node_or_null("SwitchIcon") as HoverIcon
	assert_not_null(switch_icon, "切换主按钮使用正式图标")
	assert_eq(switch_icon.sheet.resource_path, "res://assets/ui/icons/switch_hover_sheet.png",
			"切换图标使用 import 素材规范化后的正式悬停图集")
	assert_eq(switch_icon.sheet.get_size(), Vector2(512, 256),
			"新版 4×2 图集使用原生 128px 整数帧")
	assert_eq(switch_icon.hframes, 4)
	assert_eq(switch_icon.vframes, 2)
	assert_eq(switch_icon.playback_frames, PackedInt32Array([0, 1, 2]),
			"播放序列排除第一行第四帧、第二行第一帧和新版透明尾格")
	assert_gt(switch_icon.fps, 0.0,
			"悬停图集保持可播放；具体帧率属于人工调节的表现参数")
	assert_eq(switch_icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
			"切换像素图标保持最近邻采样")
	screen.btn_switch.mouse_entered.emit()
	assert_true(bool(switch_icon.get("_hovering")), "悬停切换按钮后开始播放图集")
	switch_icon.call("_process", 0.70)
	assert_eq(switch_icon.call("_source_frame_index", int(switch_icon.get("_frame"))), 2,
			"悬停序列只经过三个有效帧，不进入排除帧或透明尾格")
	screen.btn_switch.mouse_exited.emit()
	assert_eq(int(switch_icon.get("_frame")), switch_icon.rest_frame,
			"移出按钮后回到静止帧")
	assert_ne(switch_icon.self_modulate, Color.WHITE,
			"待提交态以图标提金代替已选文字")
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
	assert_eq(grid.position.y, 255.0, "英雄头像框组轻微上移 10px")
	assert_eq(grid.get("cards_per_page"), 12, "英雄图鉴每页只展示 12 位英雄")
	assert_lte(float(grid.get("step_x")), 170.0, "头像列距收紧，不在左页横向松散铺开")
	assert_lte(float(grid.get("row_height")), 196.0, "头像行距收紧，形成完整名录组块")
	assert_eq(screen.card_cards.filter(func(card: Button) -> bool: return card.visible).size(), 12,
			"第一页运行时只显示 12 个头像")
	assert_eq(previous.text, "上一页", "上一页移除视觉重量过大的三重箭头")
	assert_eq(next.text, "下一页", "下一页移除视觉重量过大的三重箭头")
	assert_eq(navigation.position.x, grid.position.x,
			"分页行与四列头像内容使用同一水平起点")
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


func test_battle_codex_overlay_uses_shared_unified_codex() -> void:
	var overlay := BattleCodexOverlay.new()
	add_child_autofree(overlay)
	var codex := overlay.get_node_or_null("CodexScreen") as Control
	assert_not_null(codex, "战斗入口直接实例化全局统一图鉴")
	assert_null(overlay.get_node_or_null("Tab0"), "战斗浮层不再维护旧版独立英雄页签")
	assert_null(overlay.get_node_or_null("Tab1"), "战斗浮层不再维护旧版独立道具页签")
	if codex == null:
		return
	assert_eq(codex.scene_file_path, "res://src/ui/codex_screen.tscn",
			"所有入口共享同一个 PackedScene，后续图鉴更新自动全局生效")
	assert_eq(codex.get_script(), UnifiedCodexScreen)
	assert_not_null(codex.get_node_or_null("GalleryHost/HeroGallery"),
			"英雄页作为场景实例保存在统一图鉴中，编辑器无需 F6 即可看到资产")
	assert_not_null(codex.get_node_or_null("GalleryHost/ItemGallery"),
			"道具页作为场景实例保存在统一图鉴中")
	assert_not_null(codex.get_node_or_null("BookmarkLayer/HeroBookmark"))
	assert_not_null(codex.get_node_or_null("BookmarkLayer/ItemBookmark"))
	codex.call("show_section", 1)
	var item_gallery := codex.call("get_gallery", 1) as Control
	item_gallery.call("select_tier", 3)
	overlay.close()
	overlay.open()
	assert_eq(int(item_gallery.call("get_current_tier")), 1,
			"战斗图鉴复用实例再次打开时，道具章节重置为普通")
	assert_eq(int(item_gallery.get("_current_page")), 0,
			"战斗图鉴再次打开时回到普通第一页")


func test_battle_codex_overlay_stays_non_pausing_and_closes_cleanly() -> void:
	var overlay := BattleCodexOverlay.new()
	add_child_autofree(overlay)
	overlay.open()
	assert_true(overlay.visible, "战斗图鉴仍可正常打开")
	var codex := overlay.get_node("CodexScreen") as Control
	assert_false((codex.get_node("BackButton") as Button).visible,
			"浮层图鉴由暗部或 ESC 关闭，不再显示返回侧签")
	assert_true((codex.get_node("CloseButton") as Button).visible,
			"右页描边内显示手绘 X 关闭键")
	assert_gt((codex.get_node("GalleryHost") as Control).offset_transform_position.y, 0.0,
			"呼出首帧从轻微下移位置开始")
	var entrance := codex.get("_overlay_open_tween") as Tween
	if entrance != null and entrance.is_valid():
		await entrance.finished
	assert_almost_eq((codex.get_node("Backdrop") as TextureRect).self_modulate.a,
			UnifiedCodexScreen.OVERLAY_BACKDROP_ALPHA, 0.001,
			"场景内容仍透过图鉴外围半透明背景可见")
	assert_eq(overlay.z_index, RenderingServer.CANVAS_ITEM_Z_MAX)
	assert_ne(codex.process_mode, Node.PROCESS_MODE_DISABLED,
			"打开后统一图鉴恢复输入")
	assert_false(get_tree().paused, "打开战斗图鉴不暂停对局计时")
	overlay.close()
	await get_tree().create_timer(UnifiedCodexScreen.OVERLAY_CLOSE_DURATION + 0.03).timeout
	assert_false(overlay.visible, "战斗图鉴仍可正常关闭")
	assert_eq(codex.process_mode, Node.PROCESS_MODE_DISABLED,
			"隐藏后整棵统一图鉴停止接收 ESC 与方向键")
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
	var book_shadow_mid := book_shadow.get_node("MidFade") as ColorRect
	var book_shadow_outer := book_shadow.get_node("OuterFade") as ColorRect
	var host := screen.get_node("GalleryHost") as Control
	var bookmark_layer := screen.get_node("BookmarkLayer") as Control
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
	assert_null(backdrop.material, "静态烟褐底图不挂 shader，材质失效时也绝不变黑")
	var backdrop_motion := screen.get_node("BackdropMotion") as ColorRect
	var backdrop_material := backdrop_motion.material as ShaderMaterial
	assert_not_null(backdrop_material, "背景微动效放在独立透明覆盖层")
	if backdrop_material != null:
		assert_eq(backdrop_material.shader.resource_path,
				"res://assets/shaders/canvas_ui_codex_backdrop_motion.gdshader")
		assert_lte(float(backdrop_material.get_shader_parameter("motion_alpha")), 0.035,
				"微动层透明度保持在 3.5% 以内")
		assert_lte(float(backdrop_material.get_shader_parameter("drift_speed")), 0.04,
				"背景暖雾保持极慢漂移")
	assert_eq(backdrop_motion.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	var backdrop_image := backdrop.texture.get_image()
	var backdrop_center := backdrop_image.get_pixel(
			int(backdrop_image.get_width() / 2.0), int(backdrop_image.get_height() / 2.0))
	var backdrop_corner := backdrop_image.get_pixel(10, 10)
	assert_gt(backdrop_center.r, backdrop_center.g,
			"烟褐中心保持暖红分量高于绿色")
	assert_gt(backdrop_center.g, backdrop_center.b,
			"烟褐中心不偏蓝灰")
	assert_gt(backdrop_corner.r + backdrop_corner.g + backdrop_corner.b, 0.3,
			"背景边缘仍是可见烟褐色而不是纯黑")
	assert_gt(backdrop_center.r + backdrop_center.g + backdrop_center.b,
			backdrop_corner.r + backdrop_corner.g + backdrop_corner.b,
			"书本背后仅做克制的中心提亮")
	assert_almost_eq(host.position.x, UnifiedCodexScreen.BOOK_ORIGIN.x, 0.001,
			"书本使用全局居中横坐标")
	assert_almost_eq(host.position.y, UnifiedCodexScreen.BOOK_ORIGIN.y, 0.001,
			"书本使用全局居中纵坐标")
	assert_almost_eq(host.size.x, 1920.0, 0.001,
			"内部书页继续使用原始设计宽度")
	assert_almost_eq(host.size.y, 1080.0, 0.001,
			"内部书页继续使用原始设计高度")
	assert_eq(host.scale, UnifiedCodexScreen.BOOK_SCALE,
			"英雄与道具共享同一缩书比例")
	assert_eq(book_shadow_mid.position, Vector2(-5, -5))
	assert_eq(book_shadow_outer.position, Vector2(-10, -10))
	assert_lt(book_shadow_outer.color.a, book_shadow_mid.color.a)
	assert_lt(book_shadow_mid.color.a, book_shadow.color.a,
			"书本接触影由内向外逐层降低透明度，避免硬切边缘")
	var expected_book_origin := (Vector2(1920, 1080) - host.size * host.scale) * 0.5
	assert_almost_eq(UnifiedCodexScreen.BOOK_ORIGIN.x, expected_book_origin.x, 0.001,
			"书本本体严格以 1920x1080 画布水平中心为准，不再为侧签右移")
	assert_almost_eq(UnifiedCodexScreen.BOOK_ORIGIN.y, expected_book_origin.y, 0.001,
			"书本本体严格以 1920x1080 画布垂直中心为准")
	assert_eq(UnifiedCodexScreen.BOOK_SCALE, Vector2(0.84, 0.84),
			"书本放大到 84%，保证原书页文字可读")
	assert_eq(UnifiedCodexScreen.BOOKMARK_LAYER_ORIGIN, Vector2.ZERO,
			"侧签直接使用最终画布坐标，不再依靠负位移换算")
	assert_eq(UnifiedCodexScreen.BOOKMARK_LAYER_SCALE, Vector2.ONE,
			"静态 UI 不再整体缩放 Control，文字与输入区保持最终像素尺寸")
	assert_eq(bookmark_layer.position, UnifiedCodexScreen.BOOKMARK_LAYER_ORIGIN)
	assert_eq(bookmark_layer.scale, UnifiedCodexScreen.BOOKMARK_LAYER_SCALE)
	assert_almost_eq((host.size * host.scale).x, 1612.8, 0.01)
	assert_almost_eq((host.size * host.scale).y, 907.2, 0.01)
	assert_almost_eq(book_shadow.position.x,
			UnifiedCodexScreen.BOOK_ORIGIN.x + 14.0, 0.001,
			"接触影按居中书本克制右移")
	assert_almost_eq(book_shadow.position.y,
			UnifiedCodexScreen.BOOK_ORIGIN.y + 14.0, 0.001,
			"接触影按居中书本克制下移")
	assert_almost_eq(book_shadow.size.x, (host.size * host.scale).x, 0.01,
			"接触影宽度与放大后的书本边界一致")
	assert_almost_eq(book_shadow.size.y, (host.size * host.scale).y, 0.01,
			"接触影高度与放大后的书本边界一致")
	assert_gt(book_shadow.color.a, 0.0, "烟褐背景上保留克制的书本接触影")
	assert_eq(chapter_hero.text, "", "按钮本体不再横移同一份文字")
	assert_eq(chapter_item.text, "")
	var hero_state_text := chapter_hero.get_node("StateText") as Label
	var item_state_text := chapter_item.get_node("StateText") as Label
	assert_eq(hero_state_text.text, "英雄")
	assert_eq(item_state_text.text, "道具")
	assert_eq(chapter_hero.size, Vector2(150, 82),
			"主章节点击区按精修母纹理 150x82 一比一显示")
	assert_eq(chapter_item.size, Vector2(150, 82))
	assert_eq(chapter_hero.position, Vector2(9.6, 190.75),
			"主签改用最终画布坐标并与居中书封接缝")
	assert_eq(chapter_item.position, Vector2(9.6, 278.75))
	assert_eq(chapter_item.position.y - (chapter_hero.position.y + chapter_hero.size.y), 6.0,
			"英雄与道具主签整体下移并把组内间距收紧为 6px")
	assert_eq(rarity_group.position.y - (chapter_item.position.y + chapter_item.size.y), 12.0,
			"道具主签与普通子签间距同步收紧为 12px")
	var hero_idle_art := chapter_hero.get_node("IdleArt") as TextureRect
	var hero_selected_art := chapter_hero.get_node("SelectedArt") as TextureRect
	var item_idle_art := chapter_item.get_node("IdleArt") as TextureRect
	var item_selected_art := chapter_item.get_node("SelectedArt") as TextureRect
	assert_false(hero_idle_art.visible, "选中英雄签不显示 idle 资产")
	assert_true(hero_selected_art.visible, "选中英雄签使用 selected 资产")
	assert_true(item_idle_art.visible, "未选中道具签使用返回签同源的 idle 资产")
	assert_false(item_selected_art.visible, "未选中道具签不调用 selected 资产")
	assert_eq(hero_selected_art.texture.resource_path,
			"res://assets/ui/codex/bookmark_chapter_selected.png")
	assert_eq(hero_idle_art.texture.resource_path,
			"res://assets/ui/codex/bookmark_chapter_idle.png")
	assert_null(chapter_hero.get_node_or_null("ChapterIcon"),
			"主章节侧签只保留文字，不再添加英雄或道具图案")
	assert_null(chapter_item.get_node_or_null("ChapterIcon"))
	var hero_idle_shadow := chapter_hero.get_node("IdleShadow") as TextureRect
	var hero_selected_shadow := chapter_hero.get_node("SelectedShadow") as TextureRect
	assert_false(hero_idle_shadow.visible)
	assert_true(hero_selected_shadow.visible)
	assert_eq(hero_idle_shadow.texture, hero_idle_art.texture,
			"Godot 投影复用纸签 Alpha，不烘焙第三张阴影素材")
	assert_eq(hero_selected_shadow.texture, hero_selected_art.texture)
	assert_eq(hero_selected_shadow.position, UnifiedCodexScreen.BOOKMARK_SHADOW_OFFSET)
	assert_eq(hero_selected_shadow.self_modulate, UnifiedCodexScreen.BOOKMARK_SHADOW_COLOR)
	assert_lt(normal.size.x, chapter_item.size.x, "稀有度子标签比主章节标签更小")
	assert_gt(normal.position.x + rarity_group.position.x, chapter_item.position.x,
			"稀有度子标签向书页内缩，形成二级层级")
	var chapter_canvas_left := (bookmark_layer.position.x
			+ chapter_hero.position.x * bookmark_layer.scale.x)
	var selected_visible_right := (chapter_canvas_left
			+ 144.0 * bookmark_layer.scale.x)
	var rarity_visible_right := (bookmark_layer.position.x
			+ (rarity_group.position.x + 144.0 / 150.0 * normal.size.x)
			* bookmark_layer.scale.x)
	assert_almost_eq(chapter_canvas_left, 9.6, 0.01,
			"主签在居中书本左侧安全区内完整露出")
	assert_almost_eq(selected_visible_right, UnifiedCodexScreen.BOOK_ORIGIN.x, 0.01,
			"选中主签精修纹理的可见右缘与书封左缘精确接缝")
	assert_almost_eq(rarity_visible_right, UnifiedCodexScreen.BOOK_ORIGIN.x, 1.0,
			"稀有度小侧签同样只把根部藏入书封")
	assert_almost_eq(chapter_hero.size.x * bookmark_layer.scale.x, 150.0, 0.01,
			"主签恢复母纹理一比一显示，适配居中书本边距")
	assert_almost_eq(normal.size.x * bookmark_layer.scale.x, 100.0, 0.01,
			"二级签缩至主签三分之二宽度")
	assert_false(rarity_group.visible, "英雄图鉴中稀有度标签保持收起")
	assert_eq(chapter_hero.position.x, chapter_item.position.x,
			"主签点击区域与纸张轮廓在所有状态下固定")
	assert_eq(chapter_hero.scale, Vector2.ONE,
			"侧签按钮与点击区域本体始终保持原尺寸")
	assert_eq(screen.bookmark_fold_min_scale, 0.78)
	assert_eq(screen.bookmark_fold_collapse_duration, 0.075)
	assert_eq(screen.bookmark_fold_expand_duration, 0.09,
			"低幅书缝换面由 Inspector 暴露参数，不再使用夸张收缩")
	assert_null(hero_selected_art.material)
	assert_null(item_idle_art.material)
	assert_null(item_selected_art.material,
			"静态与动画过程均直接绘制原资产，不再套纹理混合 shader")
	assert_eq(hero_selected_art.scale, Vector2.ONE)
	assert_eq(item_idle_art.scale, Vector2.ONE)
	assert_almost_eq(hero_state_text.position.x + hero_state_text.size.x * 0.5,
			88.0, 0.01, "单层文字严格居中于固定纸面")
	assert_almost_eq(item_state_text.position.x + item_state_text.size.x * 0.5,
			88.0, 0.01)
	assert_null(chapter_hero.get_node_or_null("SelectionMarkerMask"),
			"正式英雄签取消金色索引")
	assert_null(chapter_item.get_node_or_null("SelectionMarkerMask"),
			"正式道具签取消金色索引")
	var idle_rest_x := chapter_item.position.x
	screen.call("_on_bookmark_hover", chapter_item, true)
	await get_tree().create_timer(0.2).timeout
	assert_almost_eq(chapter_item.position.x, idle_rest_x, 0.01,
			"悬停只做轻微明暗反馈，不再把侧签从书封向左拉出空隙")
	screen.call("_on_bookmark_hover", chapter_item, false)
	var hero_gallery := screen.call("get_gallery", 0) as Control
	assert_not_null(hero_gallery)
	assert_eq(hero_gallery.position, Vector2.ZERO)
	assert_eq(hero_gallery.scale, Vector2.ONE,
			"英雄图鉴内部不二次缩放，由统一书本容器负责构图")
	var prewarmed_item_gallery := screen.call("get_gallery", 1) as Control
	assert_false(prewarmed_item_gallery.visible, "未激活章节已预热但首帧保持隐藏")
	for gallery: Control in [hero_gallery, prewarmed_item_gallery]:
		assert_true(bool(gallery.get("embedded_in_codex")))
		assert_almost_eq((gallery.get_node("BookLayer") as Control).modulate.a, 1.0, 0.001,
				"嵌入章节不重复播放透明入场，切换首帧保持完整书页")
		assert_eq((gallery.get_node("BookLayer") as Control).position, Vector2.ZERO)
		assert_false((gallery.get_node("TopBand/BackButton") as Button).visible,
				"子页旧返回入口在统一外壳内隐藏")
	var native_text_layer := screen.get_node("NativeTextLayer") as CodexNativeTextLayer
	native_text_layer.sync_now()
	assert_eq(native_text_layer.scale, Vector2.ONE,
			"原生文字层不继承 0.84 书页缩放")
	assert_gt(native_text_layer.mirror_count(), 0, "当前书页文字已复制到原生画布层")
	var source_page_indicator := hero_gallery.get_node("PoolArea/PageNavigation/PageIndicator") as Label
	var source_previous_page := hero_gallery.get_node("PoolArea/PageNavigation/PreviousPage") as Button
	var source_next_page := hero_gallery.get_node("PoolArea/PageNavigation/NextPage") as Button
	assert_almost_eq(source_page_indicator.self_modulate.a, 0.0, 0.001,
			"缩放书页仅保留布局来源，不再重复绘制文字")
	var native_page_indicator := native_text_layer.mirror_for_source(source_page_indicator)
	var native_previous_page := native_text_layer.mirror_for_source(source_previous_page)
	var native_next_page := native_text_layer.mirror_for_source(source_next_page)
	assert_not_null(native_page_indicator)
	assert_not_null(native_previous_page)
	assert_not_null(native_next_page)
	if native_page_indicator != null and native_previous_page != null and native_next_page != null:
		assert_eq(native_page_indicator.scale, Vector2.ONE)
		assert_eq(native_page_indicator.position, native_page_indicator.position.round(),
				"原生文字落在整数画布坐标")
		assert_eq(native_previous_page.get_theme_font_size("font_size"), 18,
				"上一页不再沿用更粗大的 24px 源字号")
		assert_eq(native_page_indicator.get_theme_font_size("font_size"), 18)
		assert_eq(native_next_page.get_theme_font_size("font_size"), 18,
				"上一页、页码、下一页使用同一最终字号与字重")
		assert_eq(native_previous_page.position.y, native_page_indicator.position.y)
		assert_eq(native_next_page.position.y, native_page_indicator.position.y,
				"分页三项共享同一纵向中心，不再上下错位")
		assert_eq(source_previous_page.text, "上一页")
		assert_eq(source_next_page.text, "下一页",
				"翻页文案不再使用视觉重量过大的三重箭头")
		assert_eq(source_previous_page.get_parent().position.x,
				hero_gallery.get_node("PoolArea/PortraitGrid").position.x,
				"分页行源布局与四列头像内容使用同一水平起点")
		assert_eq(native_page_indicator.get_theme_color("font_color"),
				CodexNativeTextLayer.PAGE_NAVIGATION_COLOR)
		assert_eq(native_next_page.get_theme_color("font_color"),
				CodexNativeTextLayer.PAGE_NAVIGATION_COLOR,
				"可用翻页文案与页码使用相同墨色和透明度")
		assert_eq(native_previous_page.get_theme_color("font_color"),
				CodexNativeTextLayer.PAGE_NAVIGATION_DISABLED_COLOR,
				"仅不可用的上一页降低透明度")
		assert_eq(native_previous_page.get_theme_constant("outline_size"), 0)
		assert_eq(native_page_indicator.get_theme_constant("outline_size"), 0)
		assert_eq(native_next_page.get_theme_constant("outline_size"), 0,
				"翻页文案与页码不再继承不同的描边粗细")
		assert_not_null(native_previous_page.get_node_or_null("NavArrow"))
		assert_not_null(native_next_page.get_node_or_null("NavArrow"),
				"翻页方向改由单枚原生像素三角表达")
		assert_eq(CodexNativeTextLayer.PAGE_ARROW_GAP, 8.0,
				"翻页箭头与相邻文字保留 8px 清晰间距")
		var cards: Array = hero_gallery.get("card_cards") as Array
		var first_frame := (cards[0] as Control).get_node("HeroPortraitFrame") as Control
		var last_frame := (cards[3] as Control).get_node("HeroPortraitFrame") as Control
		var first_center := native_text_layer.get_global_transform_with_canvas() \
				.affine_inverse() * (first_frame.get_global_transform_with_canvas() \
				* (first_frame.size * 0.5))
		var last_center := native_text_layer.get_global_transform_with_canvas() \
				.affine_inverse() * (last_frame.get_global_transform_with_canvas() \
				* (last_frame.size * 0.5))
		var previous_arrow := native_previous_page.get_node("NavArrow") as Polygon2D
		var previous_group_left := native_previous_page.position.x \
				+ previous_arrow.position.x
		var previous_group_right := native_previous_page.position.x \
				+ native_previous_page.size.x
		var next_arrow := native_next_page.get_node("NavArrow") as Polygon2D
		var next_group_left := native_next_page.position.x
		var next_group_right := native_next_page.position.x \
				+ next_arrow.position.x + CodexNativeTextLayer.PAGE_ARROW_WIDTH
		assert_almost_eq((previous_group_left + previous_group_right) * 0.5,
				first_center.x, 0.5, "上一页视觉组严格对齐第一列头像中心")
		assert_almost_eq(native_page_indicator.position.x
				+ native_page_indicator.size.x * 0.5,
				(first_center.x + last_center.x) * 0.5, 0.5,
				"页码严格对齐四列头像的视觉中心")
		assert_almost_eq((next_group_left + next_group_right) * 0.5,
				last_center.x, 0.5, "下一页视觉组严格对齐第四列头像中心")
	var source_hero_name := hero_gallery.find_child("HeroName", true, false) as Label
	assert_eq(source_hero_name.position.y,
			HeroGalleryScreen.BOX + HeroGalleryScreen.NAME_TOP_GAP,
			"英雄名与头像框增加 3px 克制留白，不改变已通过的水平补偿")
	var native_hero_name := native_text_layer.mirror_for_source(source_hero_name)
	var portrait_frame := source_hero_name.get_parent().get_node("HeroPortraitFrame") as Control
	var frame_center_global := portrait_frame.get_global_transform_with_canvas() \
			* (portrait_frame.size * 0.5)
	var frame_center_local := native_text_layer.get_global_transform_with_canvas() \
			.affine_inverse() * frame_center_global
	assert_not_null(native_hero_name)
	if native_hero_name != null:
		assert_lte(absf(native_hero_name.position.x + native_hero_name.size.x * 0.5
				- roundf(frame_center_local.x)
				- CodexNativeTextLayer.HERO_NAME_OPTICAL_OFFSET_X), 0.5,
				"头像名在几何居中后统一增加三个最终像素的右向字面补偿")
		assert_eq(native_hero_name.vertical_alignment, VERTICAL_ALIGNMENT_TOP,
				"头像名恢复原版顶部落字，不再被强制垂直居中")
		assert_eq(native_hero_name.get_theme_font_size("font_size"), 15,
				"头像名使用清晰但不过度放大的原生 15px")
	var source_skill_detail := hero_gallery.find_child("SkillDetail", true, false) as Label
	assert_false(source_skill_detail.visible,
			"完整正文源不参与绘制，避免与粗体效果词发生重复像素")
	var detail_segments := hero_gallery.get("_d_detail_segment_labels") as Array
	assert_gt(detail_segments.size(), 0,
			"右页技能正文必须拆成可进入原生文字层的互斥片段")
	var first_skill_segment := detail_segments[0] as Label
	var native_skill_detail := native_text_layer.mirror_for_source(first_skill_segment)
	assert_not_null(native_skill_detail)
	if native_skill_detail != null:
		var expected_skill_top := native_text_layer.get_global_transform_with_canvas() \
				.affine_inverse() * (first_skill_segment.get_global_transform_with_canvas() \
				* Vector2.ZERO)
		assert_eq(native_skill_detail.vertical_alignment, VERTICAL_ALIGNMENT_TOP,
				"右页技能正文分段仍从说明区域顶边落字")
		assert_lte(absf(native_skill_detail.position.y - roundf(expected_skill_top.y)), 1.0,
				"技能正文分段原生层保持说明区域顶边")
	var skill_name := hero_gallery.get("_d_skill_name") as Label
	var skill_icon := hero_gallery.get("_d_skill_icon") as TextureRect
	var skill_tag := hero_gallery.get("_d_tag_group") as Control
	var skill_rule := hero_gallery.get("_d_detail_rule") as ColorRect
	var skill_pin := hero_gallery.get("_d_detail_pin") as ColorRect
	var hp_group := hero_gallery.get_node("DetailArea/HPGroup") as Control
	assert_eq(skill_name.position.y, 728.0)
	assert_true(not skill_icon.visible or skill_icon.position.y == 728.0)
	assert_eq(skill_tag.position.y, 727.0)
	assert_eq(source_skill_detail.position.y, 788.0)
	assert_eq(skill_rule.position.y, 798.0)
	assert_eq(skill_pin.position.y, 792.0,
			"技能行、正文与引导线必须作为一个完整区块同步上移")
	assert_eq(skill_name.position.y - hp_group.get_rect().end.y, 30.0,
			"血量组与技能组只保留清楚分区所需的 30px 间距")
	var unified_back := screen.get_node("BackButton") as Button
	assert_false(unified_back.visible, "图鉴改为场景内浮层后彻底停用返回侧签")
	var unified_close := screen.get_node("CloseButton") as Button
	assert_true(unified_close.visible)
	assert_eq(unified_close.position, Vector2(1643, 140),
			"放大后的手绘 X 保持通过位置的视觉中心")
	assert_eq(unified_close.size, Vector2(40, 40))
	assert_true(unified_close.tooltip_text.is_empty())
	assert_true("Inspector" in unified_close.editor_description)
	assert_eq((unified_close.get_node("StrokeA") as Line2D).width, 3.0)
	assert_eq((unified_close.get_node("StrokeB") as Line2D).width, 3.0)
	assert_null(unified_close.get_node_or_null("ShadowA"))
	assert_null(unified_close.get_node_or_null("ShadowB"))
	assert_eq((unified_close.get_node("StrokeA") as Line2D).position, Vector2.ZERO)
	assert_eq((unified_close.get_node("StrokeB") as Line2D).position, Vector2.ZERO,
			"X 笔画不得单独偏移，否则视觉与点击区会分离")
	assert_true(unified_close.flat, "关闭键命中区不得绘制 Button 装饰")
	for style_state: StringName in UnifiedCodexScreen.CLOSE_STYLE_STATES:
		assert_true(unified_close.has_theme_stylebox_override(style_state))
		assert_true(unified_close.get_theme_stylebox(style_state) is StyleBoxEmpty,
				"包括 hover_pressed 在内的关闭键状态必须全部透明：%s" % style_state)
	screen.call("_on_close_down")
	assert_eq(unified_close.offset_transform_position, Vector2.ZERO)
	assert_eq((unified_close.get_node("StrokeA") as Line2D).default_color,
			UnifiedCodexScreen.CLOSE_PRESSED_COLOR,
			"关闭键按下只改变笔画颜色，不产生位移阴影")
	screen.call("_on_close_up")
	assert_eq(unified_close.offset_transform_position, Vector2.ZERO,
			"关闭键拥有按下与松开反馈")
	assert_false(unified_close.pressed.get_connections().is_empty())
	assert_eq(unified_back.text, "")
	assert_lt(unified_back.position.x, UnifiedCodexScreen.BOOK_ORIGIN.x)
	assert_almost_eq(unified_back.position.x + unified_back.size.x,
			UnifiedCodexScreen.BOOK_ORIGIN.x, 0.01,
			"返回短签右缘精确止于书封接缝，点击区不压入书页")
	assert_gte(unified_back.position.y, UnifiedCodexScreen.BOOK_ORIGIN.y,
			"返回短签不得越出书本顶部")
	assert_lt(unified_back.position.y + unified_back.size.y, chapter_hero.position.y,
			"返回短签位于章节签上方并形成独立操作层级")
	assert_true(unified_back.size.is_equal_approx(Vector2(112, 54)))
	assert_eq(chapter_hero.position.y - (unified_back.position.y + unified_back.size.y), 48.0,
			"整体下移后返回签到英雄签为 48px，正式侧签组内为 6px")
	var back_art := unified_back.get_node("BackArt") as TextureRect
	var back_shadow := unified_back.get_node("BackShadow") as TextureRect
	var back_text := unified_back.get_node("BackText") as Label
	assert_true(back_art.texture is AtlasTexture,
			"返回短签从现有章节纸签裁切，不新增贴图")
	var back_atlas := back_art.texture as AtlasTexture
	assert_eq(back_atlas.atlas.resource_path,
			"res://assets/ui/codex/bookmark_chapter_idle.png")
	assert_eq(back_atlas.region, Rect2(32, 12, 112, 54))
	assert_null(back_art.material,
			"返回签直接绘制原资产颜色，不再参与纸色归一")
	assert_eq(back_shadow.texture, back_art.texture)
	assert_eq(back_shadow.position, UnifiedCodexScreen.BOOKMARK_SHADOW_OFFSET)
	assert_eq(back_text.text, "返回")
	assert_eq(back_text.get_theme_font_size("font_size"), 18)
	var back_arrow := unified_back.get_node_or_null("BackArrow") as Polygon2D
	assert_not_null(back_arrow, "返回侧签使用代码绘制的单枚像素箭头，无新增资产")
	if back_arrow != null:
		var arrow_min_y := INF
		var arrow_max_y := -INF
		for point: Vector2 in back_arrow.polygon:
			arrow_min_y = minf(arrow_min_y, point.y)
			arrow_max_y = maxf(arrow_max_y, point.y)
		var arrow_center_y := back_arrow.position.y + (arrow_min_y + arrow_max_y) * 0.5
		assert_almost_eq(arrow_center_y, unified_back.size.y * 0.5, 0.01,
				"箭头与返回文字共享按钮纵向中心")
	assert_false(unified_back.pressed.get_connections().is_empty())

	screen.call("show_section", 1)
	assert_true(rarity_group.visible, "进入道具图鉴后展开普通/稀有/传说快速索引")
	assert_false(item_selected_art.visible)
	assert_true(item_idle_art.visible,
			"切换首帧从真实 idle 资产开始")
	assert_eq(item_idle_art.self_modulate, Color.WHITE)
	assert_eq(hero_idle_art.self_modulate, Color.WHITE,
			"两张资产保持原色，不使用状态染色")
	assert_almost_eq((prewarmed_item_gallery.get_node("BookLayer") as Control).modulate.a,
			1.0, 0.001, "英雄切道具的首帧不再露出黑色衬底")
	var item_transition := (screen.get("_tab_tweens") as Dictionary).get(chapter_item) as Tween
	screen.call("_on_bookmark_hover", chapter_item, true)
	assert_true(item_transition != null and item_transition.is_valid(),
			"悬停反馈不再杀掉正在执行的选中状态 Tween")
	for index: int in 3:
		var opening_button := rarity_group.get_child(index) as Button
		assert_eq(opening_button.position.y, UnifiedCodexScreen.RARITY_TARGET_Y[index],
				"二级签不再位移，只按固定位置逐枚显现")
		assert_almost_eq(opening_button.self_modulate.a, 1.0, 0.001)
		assert_false(opening_button.visible)
		assert_eq(opening_button.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	screen.call("_kill_button_tween", chapter_item)
	screen.call("_set_bookmark_fold_scale", 0.82, chapter_item)
	assert_true(item_idle_art.visible)
	assert_false(item_selected_art.visible,
			"收窄阶段仍只显示旧纸面，不叠加两张纸签")
	assert_almost_eq(item_idle_art.scale.x, 0.82, 0.001)
	assert_eq(item_idle_art.material, null)
	assert_null(item_selected_art.material)
	screen.call("_apply_bookmark_endpoint", chapter_item, true)
	screen.call("_set_bookmark_fold_scale", 1.0, chapter_item)
	screen.call("_kill_button_tween", chapter_hero)
	screen.call("_apply_bookmark_endpoint", chapter_hero, false)
	screen.call("_set_bookmark_fold_scale", 1.0, chapter_hero)
	screen.call("_kill_rarity_group_tween")
	for opening_button: Button in [
		rarity_group.get_node("Normal") as Button,
		rarity_group.get_node("Rare") as Button,
		rarity_group.get_node("Legendary") as Button,
	]:
		screen.call("_set_rarity_button_visible", opening_button, true)
	assert_true(item_selected_art.visible)
	assert_false(item_idle_art.visible)
	assert_true(hero_idle_art.visible, "英雄签同步切回较短的未选中纸签")
	assert_false(hero_selected_art.visible)
	for index: int in 3:
		var opened_button := rarity_group.get_child(index) as Button
		assert_true(opened_button.visible)
		assert_eq(opened_button.mouse_filter, Control.MOUSE_FILTER_STOP)
	assert_eq((rarity_group.get_node("Normal") as Button).position.y, 0.0)
	assert_eq((rarity_group.get_node("Rare") as Button).position.y, 50.0)
	assert_eq((rarity_group.get_node("Legendary") as Button).position.y, 100.0)
	assert_eq((rarity_group.get_node("Rare") as Button).position.y
			- (rarity_group.get_node("Normal") as Button).position.y, 50.0,
			"只收紧层级间距，子签彼此节距保持不变")
	assert_eq((rarity_group.get_node("Normal") as Button).size, Vector2(100, 54),
			"稀有度签缩至主签约三分之二，不再与章节签抢层级")
	var rare_button := rarity_group.get_node("Rare") as Button
	var normal_state_text := normal.get_node("StateText") as Label
	var rare_state_text := rare_button.get_node("StateText") as Label
	assert_almost_eq(normal_state_text.position.x + normal_state_text.size.x * 0.5,
			58.5, 0.01, "稀有度文字统一居中于固定纸面")
	assert_almost_eq(rare_state_text.position.x + rare_state_text.size.x * 0.5,
			58.5, 0.01, "未选中稀有度文字居中于缩短后的可见纸面")
	var normal_selected_art := normal.get_node("SelectedArt") as TextureRect
	var normal_idle_art := normal.get_node("IdleArt") as TextureRect
	var rare_idle_art := rare_button.get_node("IdleArt") as TextureRect
	assert_eq(normal_selected_art.texture.resource_path,
			"res://assets/ui/codex/bookmark_chapter_selected.png")
	assert_eq(rare_idle_art.texture.resource_path,
			"res://assets/ui/codex/bookmark_chapter_idle.png")
	assert_true(normal_selected_art.visible, "普通选中态使用 selected 纸面")
	assert_false(normal_idle_art.visible)
	assert_true(rare_idle_art.visible, "其余稀有度保持较短未选中状态")
	var expected_stripe_colors: Array[Color] = UnifiedCodexScreen.RARITY_STRIPE_COLORS
	for index: int in 3:
		var rarity_button := rarity_group.get_child(index) as Button
		var idle_stripe := rarity_button.get_node("IdleStripe") as TextureRect
		var selected_stripe := rarity_button.get_node("SelectedStripe") as TextureRect
		var idle_material := idle_stripe.material as ShaderMaterial
		var selected_material := selected_stripe.material as ShaderMaterial
		assert_not_null(idle_material)
		assert_not_null(selected_material)
		assert_eq(idle_material.shader.resource_path,
				"res://assets/shaders/canvas_ui_codex_rarity_edge.gdshader")
		assert_eq(selected_material.shader, idle_material.shader)
		assert_eq(idle_material.get_shader_parameter("rarity_color"), expected_stripe_colors[index],
				"三级颜色仍由代码统一写入蓝紫金色板")
		assert_eq(selected_material.get_shader_parameter("rarity_color"),
				expected_stripe_colors[index])
		assert_eq(idle_stripe.clip_children, CanvasItem.CLIP_CHILDREN_DISABLED,
				"稀有度染边 TextureRect 自身必须参与绘制，不能误设为仅供子节点裁切的遮罩")
		assert_eq(selected_stripe.clip_children, CanvasItem.CLIP_CHILDREN_DISABLED,
				"选中染边同样必须保持可见")
		assert_eq(idle_stripe.texture, rarity_button.get_node("IdleArt").texture)
		assert_eq(selected_stripe.texture, rarity_button.get_node("SelectedArt").texture)
		assert_almost_eq(float(idle_material.get_shader_parameter("edge_end_uv")), 0.32, 0.001)
		assert_almost_eq(float(selected_material.get_shader_parameter("edge_end_uv")), 0.16, 0.001)
		assert_almost_eq(float(idle_material.get_shader_parameter("blend_width_uv")), 0.035, 0.001)
		assert_almost_eq(idle_stripe.offset_left, 1.0, 0.001)
		assert_almost_eq(selected_stripe.offset_left, 1.0, 0.001,
				"染边整体内收 1px，避免最左侧越过纸签轮廓")
		assert_null(idle_stripe.get_node_or_null("Fill"))
		assert_null(selected_stripe.get_node_or_null("Fill"),
				"贴边颜色直接染入纸签纹理，不再叠加独立线条或色块")
		assert_not_null(rarity_button.get_node_or_null("IdleShadow"),
				"稀有度签同样使用 Godot 投影节点")
		assert_not_null(rarity_button.get_node_or_null("SelectedShadow"))
		assert_null(rarity_button.get_node_or_null("SelectionMarkerMask"),
				"普通稀有传说不再生成伸缩矩形索引")
		assert_almost_eq(rarity_button.self_modulate.a, 1.0, 0.001,
				"分层展开结束后纸签完全显现")
		assert_false(rarity_button.pressed.get_connections().is_empty(),
				"二级签保留稀有度快速跳转")
		assert_false(rarity_button.button_down.get_connections().is_empty(),
				"二级签保留按压反馈")
	assert_false(chapter_hero.mouse_entered.get_connections().is_empty(),
			"主章节签保留克制悬停反馈")
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
	var rare_selected_art := rare_button.get_node("SelectedArt") as TextureRect
	var rare_idle_transition_art := rare_button.get_node("IdleArt") as TextureRect
	assert_false(rare_selected_art.visible)
	assert_true(rare_idle_transition_art.visible,
			"稀有度切换也始终只有一层纸面")
	screen.call("_on_bookmark_hover", rare_button, true)
	screen.call("_kill_button_tween", rare_button)
	screen.call("_set_bookmark_fold_scale", 0.82, rare_button)
	assert_true(rare_idle_transition_art.visible)
	assert_false(rare_selected_art.visible,
			"稀有度收窄阶段同样只显示旧纸面")
	assert_true((rare_button.get_node("IdleStripe") as TextureRect).visible)
	assert_false((rare_button.get_node("SelectedStripe") as TextureRect).visible)
	assert_almost_eq(rare_idle_transition_art.scale.x, 0.82, 0.001)
	var rare_idle_edge_material := \
			(rare_button.get_node("IdleStripe") as TextureRect).material as ShaderMaterial
	var rare_selected_edge_material := \
			(rare_button.get_node("SelectedStripe") as TextureRect).material as ShaderMaterial
	assert_not_null(rare_idle_edge_material)
	assert_not_null(rare_selected_edge_material)
	assert_eq(rare_idle_edge_material.shader.resource_path,
			"res://assets/shaders/canvas_ui_codex_rarity_edge.gdshader")
	assert_eq(rare_selected_edge_material.shader, rare_idle_edge_material.shader,
			"纸签收窄动画不得清除或替换融入式染边材质")
	screen.call("_apply_bookmark_endpoint", rare_button, true)
	screen.call("_set_bookmark_fold_scale", 1.0, rare_button)
	assert_false((rare_button.get_node("IdleStripe") as TextureRect).visible)
	assert_true((rare_button.get_node("SelectedStripe") as TextureRect).visible)
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
	for closing_button: Button in [
			rarity_group.get_node("Normal") as Button,
			rarity_group.get_node("Rare") as Button,
			rarity_group.get_node("Legendary") as Button,
	]:
		assert_eq(closing_button.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"收起动效期间禁用二级签点击")
	await get_tree().create_timer(0.22).timeout
	assert_false(rarity_group.visible, "反向收起完成后隐藏二级签组")
	hero_gallery.call("_turn_page", 1)
	var hero_page := int(hero_gallery.get("_current_page"))
	screen.call("show_section", 1)
	assert_eq(int(item_gallery.get("_tier")), 1, "返回道具章节时重置为普通")
	assert_eq(int(item_gallery.get("_current_page")), 0, "返回道具章节时重置为第一页")
	assert_eq(int(item_gallery.get("_sel_idx")), 0, "返回道具章节时选中普通第一页首件")
	screen.call("show_section", 0)
	assert_eq(int(hero_gallery.get("_current_page")), hero_page,
			"返回英雄章节时保留上次页码")


func test_codex_bookmark_assets_are_hard_edge_true_pixel_pngs() -> void:
	var specs := {
		"res://assets/ui/codex/bookmark_chapter_idle.png": {
			"size": Vector2i(150, 82),
			"sha256": "A6448B554629E206DBB7FDC46359AC785A0DE6F6B4796A70D0986830AAE46AEC",
		},
		"res://assets/ui/codex/bookmark_chapter_selected.png": {
			"size": Vector2i(150, 82),
			"sha256": "8C81DD81C768888A5AF60A779236247A836DA5D4B45A6EDE03FBCA76FB369B7A",
		},
	}
	for path: String in specs:
		assert_true(FileAccess.file_exists(path), "%s 存在" % path)
		if not FileAccess.file_exists(path):
			continue
		var image := Image.new()
		assert_eq(image.load_png_from_buffer(FileAccess.get_file_as_bytes(path)), OK)
		var spec: Dictionary = specs[path]
		assert_eq(image.get_size(), spec["size"], "%s 使用锁定显示尺寸" % path)
		assert_eq(FileAccess.get_sha256(path).to_upper(), spec["sha256"],
				"%s 必须逐字节复用修正任务2通过母纹理" % path)
		assert_eq(image.get_pixel(0, 0).a, 0.0, "%s 外露左上角削角" % path)
		assert_eq(image.get_pixel(0, image.get_height() - 1).a, 0.0,
				"%s 外露左下角削角" % path)
		var selected_asset := path.ends_with("selected.png")
		var first_opaque_x := image.get_width()
		for x: int in image.get_width():
			if image.get_pixel(x, int(image.get_height() / 2.0)).a > 0.0:
				first_opaque_x = x
				break
		if selected_asset:
			assert_eq(first_opaque_x, 5, "%s 选中态完整向左抽出" % path)
		else:
			assert_eq(first_opaque_x, 31, "%s 未选中态明显藏入书页" % path)
		var hard_alpha := true
		var opaque_colors := {}
		for y: int in image.get_height():
			for x: int in image.get_width():
				var pixel := image.get_pixel(x, y)
				var alpha := pixel.a
				if alpha != 0.0 and alpha != 1.0:
					hard_alpha = false
				if alpha == 1.0:
					opaque_colors[pixel.to_html(false)] = true
		assert_true(hard_alpha, "%s 不保留半透明毛边" % path)
		assert_gte(opaque_colors.size(), 20,
				"%s 保留外部美术源的纸纹与明暗层次，不再由少量色块模拟" % path)
