extends SceneTree

var _codex_scene: PackedScene
var _codex_script: Script
var _battle_codex_overlay: Script
var _native_text_script: Script

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	# --script 早于 AutoLoad 初始化编译当前文件；依赖在运行期再载入，避免
	# FontManager 被探针启动顺序误报为未知标识符。
	_codex_scene = load("res://src/ui/codex_screen.tscn") as PackedScene
	_codex_script = load("res://src/ui/codex_screen.gd") as Script
	_battle_codex_overlay = load("res://src/ui/components/battle_codex_overlay.gd") as Script
	_native_text_script = load("res://src/ui/components/codex_native_text_layer.gd") as Script
	root.size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	var codex := _codex_scene.instantiate() as Control
	root.add_child(codex)
	await process_frame

	_expect(codex.size == Vector2(1920, 1080), "统一图鉴根节点为 1920x1080")
	var backdrop := codex.get_node("Backdrop") as TextureRect
	_expect(backdrop.texture != null
			and backdrop.texture.resource_path
			== "res://assets/ui/codex/codex_smoky_brown_backdrop.png",
			"统一图鉴加载低饱和烟褐背景")
	_expect(backdrop.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"烟褐背景保持比例覆盖全屏")
	_expect(backdrop.material == null, "静态烟褐底图不依赖 shader，避免黑屏")
	var backdrop_motion := codex.get_node("BackdropMotion") as ColorRect
	var backdrop_material := backdrop_motion.material as ShaderMaterial
	_expect(backdrop_material != null
			and backdrop_material.shader.resource_path
			== "res://assets/shaders/canvas_ui_codex_backdrop_motion.gdshader",
			"微动效由独立透明层承担")
	if backdrop_material != null:
		_expect(float(backdrop_material.get_shader_parameter("motion_alpha")) <= 0.035,
				"背景移动层透明度不超过 3.5%")
	var shadow := codex.get_node("BookContactShadow") as ColorRect
	_expect(shadow.position.is_equal_approx(_codex_script.BOOK_ORIGIN + Vector2(14, 14)),
			"书本接触影只向右下偏移 14px")
	var shadow_mid := shadow.get_node("MidFade") as ColorRect
	var shadow_outer := shadow.get_node("OuterFade") as ColorRect
	_expect(shadow_outer.color.a < shadow_mid.color.a
			and shadow_mid.color.a < shadow.color.a
			and shadow_mid.position == Vector2(-5, -5)
			and shadow_outer.position == Vector2(-10, -10),
			"书影使用由内向外递减的三层像素柔边")
	var host := codex.get_node("GalleryHost") as Control
	_expect(host.position.is_equal_approx(_codex_script.BOOK_ORIGIN), "书页容器使用全局居中坐标")
	_expect(host.size.is_equal_approx(Vector2(1920, 1080)), "书页内部保持原始设计坐标")
	_expect(host.scale == _codex_script.BOOK_SCALE, "书本统一缩放到通过构图")
	var close_button := codex.get_node_or_null("CloseButton") as Button
	_expect(close_button != null
			and close_button.position == Vector2(1643, 140)
			and close_button.size == Vector2(40, 40)
			and not close_button.pressed.get_connections().is_empty()
			and close_button.tooltip_text.is_empty()
			and close_button.has_node("StrokeA") and close_button.has_node("StrokeB")
			and is_equal_approx((close_button.get_node("StrokeA") as Line2D).width, 3.0)
			and is_equal_approx((close_button.get_node("StrokeB") as Line2D).width, 3.0)
			and close_button.get_node_or_null("ShadowA") == null
			and close_button.get_node_or_null("ShadowB") == null
			and "Inspector" in close_button.editor_description,
			"放大的手绘 X 保持原中心，Inspector 移动会同步点击区")
	_expect((close_button.get_node("StrokeA") as Line2D).position == Vector2.ZERO
			and (close_button.get_node("StrokeB") as Line2D).position == Vector2.ZERO,
			"X 笔画不再脱离按钮本体单独偏移")
	_expect(close_button.flat, "图鉴 X 的按钮命中区不绘制装饰")
	for style_state: StringName in _codex_script.CLOSE_STYLE_STATES:
		_expect(close_button.has_theme_stylebox_override(style_state)
				and close_button.get_theme_stylebox(style_state) is StyleBoxEmpty,
				"图鉴 X 状态样式为空：%s" % style_state)
	codex.call("_on_close_down")
	_expect(close_button.offset_transform_position == Vector2.ZERO
			and (close_button.get_node("StrokeA") as Line2D).default_color
			== _codex_script.CLOSE_PRESSED_COLOR,
			"图鉴 X 按下时只变色，不产生位移阴影")
	codex.call("_on_close_up")
	_expect(close_button.offset_transform_position == Vector2.ZERO,
			"图鉴 X 松开后回到原位")
	var displayed_book_size := host.size * host.scale
	var expected_book_origin := (Vector2(1920, 1080) - displayed_book_size) * 0.5
	_expect(host.position.is_equal_approx(expected_book_origin)
			and host.scale == Vector2(0.84, 0.84),
			"书本保持 84% 可读尺寸并严格全局居中")
	_expect(is_equal_approx(shadow.size.x, displayed_book_size.x)
			and is_equal_approx(shadow.size.y, displayed_book_size.y),
			"书本接触影匹配 1612.8x907.2 显示尺寸")
	var hero := codex.call("get_gallery", 0) as Control
	_expect(hero == host.get_node_or_null("HeroGallery")
			and hero.scene_file_path == "res://src/ui/hero_gallery_screen.tscn"
			and hero.position == Vector2.ZERO and hero.scale == Vector2.ONE,
			"英雄页作为编辑器可见 PackedScene 实例保存在 GalleryHost 内")
	_expect((hero.get_node("PoolArea/PortraitGrid") as Control).position.y == 255.0,
			"英雄头像名录整体轻微上移")
	var hero_book := hero.find_child("CodexBook", true, false) as TextureRect
	_expect(hero_book != null and hero_book.size.is_equal_approx(Vector2(1920, 1080)),
			"英雄书本资产仍完整覆盖设计画布")
	var hero_tab := codex.get_node("BookmarkLayer/HeroBookmark") as Button
	var item_tab := codex.get_node("BookmarkLayer/ItemBookmark") as Button
	var bookmark_layer := codex.get_node("BookmarkLayer") as Control
	_expect(bookmark_layer.position == Vector2.ZERO
			and bookmark_layer.position == _codex_script.BOOKMARK_LAYER_ORIGIN,
			"侧签直接使用最终画布坐标")
	_expect(bookmark_layer.scale == Vector2.ONE
			and bookmark_layer.scale == _codex_script.BOOKMARK_LAYER_SCALE,
			"侧签层不再缩放文字与点击区")
	var chapter_canvas_left := (bookmark_layer.position.x
			+ hero_tab.position.x * bookmark_layer.scale.x)
	var selected_visible_right := chapter_canvas_left + 144.0 * bookmark_layer.scale.x
	_expect(is_equal_approx(chapter_canvas_left, 9.6)
			and is_equal_approx(selected_visible_right, _codex_script.BOOK_ORIGIN.x),
			"选中主签的可见右缘与书封左缘精确接缝")
	var hero_idle := hero_tab.get_node("IdleArt") as TextureRect
	var hero_selected := hero_tab.get_node("SelectedArt") as TextureRect
	var item_idle := item_tab.get_node("IdleArt") as TextureRect
	var item_selected := item_tab.get_node("SelectedArt") as TextureRect
	var hero_idle_shadow := hero_tab.get_node("IdleShadow") as TextureRect
	var hero_selected_shadow := hero_tab.get_node("SelectedShadow") as TextureRect
	var hero_state_text := hero_tab.get_node("StateText") as Label
	var item_state_text := item_tab.get_node("StateText") as Label
	_expect(not hero_idle.visible and hero_selected.visible,
			"选中英雄签只显示 selected 资产")
	_expect(item_idle.visible and not item_selected.visible,
			"未选中道具签恢复为返回签同源的 idle 资产")
	_expect(hero_tab.position.is_equal_approx(Vector2(9.6, 190.75))
			and hero_tab.size == Vector2(150, 82),
			"英雄与道具签组整体下移 20px")
	_expect(item_tab.position.is_equal_approx(Vector2(9.6, 278.75))
			and item_tab.size == Vector2(150, 82),
			"英雄与道具主签收紧至 6px 间距")
	var rarity := codex.get_node("BookmarkLayer/RarityBookmarks") as Control
	_expect(is_equal_approx(
			rarity.position.y - (item_tab.position.y + item_tab.size.y), 12.0),
			"道具主签与普通子签同样保持 12px 间距")
	_expect(hero_tab.get_node_or_null("ChapterIcon") == null
			and item_tab.get_node_or_null("ChapterIcon") == null,
			"主签只显示 Godot 文字，不再叠加图案")
	_expect(hero_idle.texture.resource_path
			== "res://assets/ui/codex/bookmark_chapter_idle.png"
			and hero_selected.texture.resource_path
			== "res://assets/ui/codex/bookmark_chapter_selected.png",
			"运行态只引用两张精修母纹理")
	_expect(not hero_idle_shadow.visible and hero_selected_shadow.visible,
			"选中端点只显示 selected 资产对应投影")
	_expect(hero_tab.text.is_empty() and hero_state_text.text == "英雄",
			"侧签使用一份固定文字层")
	_expect(item_tab.text.is_empty() and item_state_text.text == "道具",
			"未选中侧签不再保留第二份文字")
	_expect(is_equal_approx(
			hero_state_text.position.x + hero_state_text.size.x * 0.5, 88.0)
			and is_equal_approx(
			item_state_text.position.x + item_state_text.size.x * 0.5, 88.0),
			"主签文字统一居中于固定纸面")
	_expect(hero_tab.get_node_or_null("SelectionMarkerMask") == null
			and item_tab.get_node_or_null("SelectionMarkerMask") == null,
			"正式侧签彻底取消金色索引")
	_expect(hero_selected.material == null
			and item_idle.material == null and item_selected.material == null
			and is_equal_approx(hero_selected.scale.x, 1.0)
			and is_equal_approx(item_idle.scale.x, 1.0),
			"静态端点始终直绘各自原资产")
	_expect(hero_selected.material == null and item_idle.material == null,
			"运行态不再加载会产生浑浊中间色的纹理混合材质")
	_expect(hero_selected_shadow.texture == hero_selected.texture
			and hero_selected_shadow.position == _codex_script.BOOKMARK_SHADOW_OFFSET
			and hero_selected_shadow.self_modulate == _codex_script.BOOKMARK_SHADOW_COLOR,
			"Godot 投影复用纹理 Alpha 并保持固定右下偏移")
	var resting_x := hero_tab.position.x
	_expect(not hero_tab.button_down.get_connections().is_empty(), "主签 button_down 已连接压入反馈")
	codex.call("_on_bookmark_down", hero_tab)
	await create_timer(0.07).timeout
	_expect(is_equal_approx(hero_tab.position.x, resting_x)
			and hero_tab.offset_transform_position.x > 0.0,
			"侧签按下只做 visual-only 压入，不改变点击矩形与书封接缝")
	codex.call("_on_bookmark_up", hero_tab)
	await create_timer(0.2).timeout
	_expect(is_equal_approx(hero_tab.position.x, resting_x)
			and hero_tab.offset_transform_position.is_zero_approx(),
			"松开后侧签独立回弹，不覆盖选中态 Tween")
	var idle_resting_x := item_tab.position.x
	codex.call("_on_bookmark_hover", item_tab, true)
	await create_timer(0.2).timeout
	_expect(is_equal_approx(item_tab.position.x, idle_resting_x),
			"悬停不再把未选中签从书封向左拉开")
	codex.call("_on_bookmark_hover", item_tab, false)

	item_tab.pressed.emit()
	_expect(rarity.visible, "点击道具主签后立即显示二级签组")
	_expect(item_idle.visible and not item_selected.visible,
			"切入首帧从真实 idle 资产开始")
	for index: int in 3:
		var opening_button := rarity.get_child(index) as Button
		_expect(opening_button.position.y == _codex_script.RARITY_TARGET_Y[index]
				and is_equal_approx(opening_button.self_modulate.a, 1.0)
				and not opening_button.visible,
				"二级签固定在终点并按顺序离散显现")
	var item_transition := (codex.get("_tab_tweens") as Dictionary).get(item_tab) as Tween
	codex.call("_on_bookmark_hover", item_tab, true)
	_expect(item_transition != null and item_transition.is_valid(),
			"悬停不会杀掉正在执行的纸签状态过渡")
	await create_timer(0.035).timeout
	var collapse_scale := item_idle.scale.x
	var fold_min_scale := float(codex.get("bookmark_fold_min_scale"))
	_expect(not item_selected.visible and item_idle.visible
			and collapse_scale > fold_min_scale
			and collapse_scale < 1.0
			and item_idle.material == null and item_selected.material == null
			and item_tab.position.is_equal_approx(Vector2(9.6, 278.75))
			and item_tab.size == Vector2(150, 82),
			"旧纸面向书缝连续收窄，按钮位置与点击矩形保持不动")
	await create_timer(0.08).timeout
	_expect(item_selected.visible and not item_idle.visible
			and item_selected.scale.x > fold_min_scale
			and item_selected.scale.x < 1.0,
			"纸面在最窄处换面后连续展开，不生成混色中间帧")
	await create_timer(0.12).timeout
	var item := codex.call("get_gallery", 1) as Control
	_expect(item == host.get_node_or_null("ItemGallery")
			and item.scene_file_path == "res://src/ui/item_gallery_screen.tscn"
			and item.position == Vector2.ZERO and item.scale == Vector2.ONE,
			"道具页同样是编辑器可见 PackedScene 实例")
	_expect((item.get_node("PoolArea/ItemGrid") as Control).position.y == 255.0,
			"道具头像名录与英雄页同步上移")
	var item_book := item.find_child("CodexBook", true, false) as TextureRect
	_expect(item_book != null and item_book.size.is_equal_approx(Vector2(1920, 1080)),
			"道具书本资产仍完整覆盖设计画布")
	_expect(bool(hero.get("embedded_in_codex")) and bool(item.get("embedded_in_codex")),
			"两个章节都以统一图鉴嵌入模式预热")
	_expect(is_equal_approx((hero.get_node("BookLayer") as Control).modulate.a, 1.0)
			and is_equal_approx((item.get_node("BookLayer") as Control).modulate.a, 1.0),
			"章节切换首帧书页保持不透明，不再黑闪")
	_expect(not (hero.get_node("TopBand/BackButton") as Button).visible
			and not (item.get_node("TopBand/BackButton") as Button).visible,
			"子图鉴旧返回入口已由统一返回按钮替代")
	var native_text_layer := codex.get_node("NativeTextLayer") as Control
	native_text_layer.call("set_source_root", hero)
	native_text_layer.call("sync_now")
	_expect(native_text_layer.scale == Vector2.ONE
			and int(native_text_layer.call("mirror_count")) > 0,
			"书页文字在最终画布原生绘制，不继承 0.84 缩放")
	var source_previous := hero.get_node("PoolArea/PageNavigation/PreviousPage") as Button
	var source_indicator := hero.get_node("PoolArea/PageNavigation/PageIndicator") as Label
	var source_next := hero.get_node("PoolArea/PageNavigation/NextPage") as Button
	var native_previous := native_text_layer.call("mirror_for_source", source_previous) as Label
	var native_indicator := native_text_layer.call("mirror_for_source", source_indicator) as Label
	var native_next := native_text_layer.call("mirror_for_source", source_next) as Label
	_expect(native_previous != null and native_indicator != null and native_next != null
			and native_previous.position.y == native_indicator.position.y
			and native_next.position.y == native_indicator.position.y
			and native_previous.get_theme_font_size("font_size") == 18
			and native_indicator.get_theme_font_size("font_size") == 18
			and native_next.get_theme_font_size("font_size") == 18
			and source_previous.text == "上一页"
			and source_next.text == "下一页"
			and source_previous.get_parent().position.x
			== hero.get_node("PoolArea/PortraitGrid").position.x
			and native_indicator.get_theme_color("font_color")
			== _native_text_script.PAGE_NAVIGATION_COLOR
			and native_next.get_theme_color("font_color")
			== _native_text_script.PAGE_NAVIGATION_COLOR
			and native_previous.has_node("NavArrow")
			and native_next.has_node("NavArrow")
			and _native_text_script.PAGE_ARROW_GAP == 8.0,
			"分页三项对齐头像内容，统一字号墨色并只保留单枚像素箭头")
	var source_hero_name := hero.find_child("HeroName", true, false) as Label
	var native_hero_name := native_text_layer.call("mirror_for_source", source_hero_name) as Label
	var portrait_frame := source_hero_name.get_parent().get_node("HeroPortraitFrame") as Control
	var frame_center_global := portrait_frame.get_global_transform_with_canvas() \
			* (portrait_frame.size * 0.5)
	var frame_center_local := native_text_layer.get_global_transform_with_canvas() \
			.affine_inverse() * frame_center_global
	_expect(native_hero_name != null
			and absf(native_hero_name.position.x + native_hero_name.size.x * 0.5
			- roundf(frame_center_local.x)
			- _native_text_script.HERO_NAME_OPTICAL_OFFSET_X) <= 0.5
			and native_hero_name.vertical_alignment == VERTICAL_ALIGNMENT_TOP,
			"头像名完成三个最终像素的右向字面补偿并保留顶部排版")
	var source_skill_detail := hero.find_child("SkillDetail", true, false) as Label
	var native_skill_detail := native_text_layer.call("mirror_for_source", source_skill_detail) as Label
	var expected_skill_top := native_text_layer.get_global_transform_with_canvas() \
			.affine_inverse() * (source_skill_detail.get_global_transform_with_canvas() \
			* Vector2.ZERO)
	_expect(native_skill_detail != null
			and native_skill_detail.vertical_alignment == VERTICAL_ALIGNMENT_TOP
			and absf(native_skill_detail.position.y - roundf(expected_skill_top.y)) <= 1.0,
			"右页技能正文保留原版顶部对齐，不再下沉")
	var skill_name := hero.get("_d_skill_name") as Label
	var skill_icon := hero.get("_d_skill_icon") as TextureRect
	var skill_tag := hero.get("_d_tag_group") as Control
	var skill_rule := hero.get("_d_detail_rule") as ColorRect
	var skill_pin := hero.get("_d_detail_pin") as ColorRect
	_expect(skill_name.position.y == 744.0
			and (not skill_icon.visible or skill_icon.position.y == 744.0)
			and skill_tag.position.y == 743.0
			and source_skill_detail.position.y == 804.0
			and skill_rule.position.y == 814.0
			and skill_pin.position.y == 808.0,
			"技能名、图标、类型签、正文与引导线作为完整区块统一上移 24px")
	native_text_layer.call("set_source_root", item)
	native_text_layer.call("sync_now")
	var item_previous := item.get_node("PoolArea/PageNavigation/PreviousPage") as Button
	var item_indicator := item.get_node("PoolArea/PageNavigation/PageIndicator") as Label
	var item_next := item.get_node("PoolArea/PageNavigation/NextPage") as Button
	var native_item_previous := native_text_layer.call(
			"mirror_for_source", item_previous) as Label
	var native_item_indicator := native_text_layer.call(
			"mirror_for_source", item_indicator) as Label
	var native_item_next := native_text_layer.call("mirror_for_source", item_next) as Label
	_expect(item_previous.text == "上一页" and item_next.text == "下一页"
			and item_previous.get_parent().position.x
			== item.get_node("PoolArea/ItemGrid").position.x
			and native_item_previous != null and native_item_indicator != null
			and native_item_next != null
			and native_item_previous.get_theme_font_size("font_size") == 18
			and native_item_indicator.get_theme_font_size("font_size") == 18
			and native_item_next.get_theme_font_size("font_size") == 18
			and native_item_previous.has_node("NavArrow")
			and native_item_next.has_node("NavArrow"),
			"道具图鉴分页与英雄图鉴共享文案、对齐、字号和原生像素箭头")
	var back_button := codex.get_node("BackButton") as Button
	var back_art := back_button.get_node("BackArt") as TextureRect
	var back_shadow := back_button.get_node("BackShadow") as TextureRect
	var back_text := back_button.get_node("BackText") as Label
	var back_arrow := back_button.get_node("BackArrow") as Polygon2D
	var arrow_min_y := INF
	var arrow_max_y := -INF
	for point: Vector2 in back_arrow.polygon:
		arrow_min_y = minf(arrow_min_y, point.y)
		arrow_max_y = maxf(arrow_max_y, point.y)
	var arrow_center_y := back_arrow.position.y + (arrow_min_y + arrow_max_y) * 0.5
	var back_atlas := back_art.texture as AtlasTexture
	_expect(back_button.text.is_empty()
			and back_button.position.x < _codex_script.BOOK_ORIGIN.x
			and is_equal_approx(back_button.position.x + back_button.size.x,
					_codex_script.BOOK_ORIGIN.x)
			and back_button.position.y >= _codex_script.BOOK_ORIGIN.y
			and back_button.position.y + back_button.size.y < hero_tab.position.y
			and hero_tab.position.y - (back_button.position.y + back_button.size.y) == 48.0
			and item_tab.position.y - (hero_tab.position.y + hero_tab.size.y) == 6.0
			and back_button.size.is_equal_approx(Vector2(112, 54))
			and back_atlas != null
			and back_atlas.atlas == hero_idle.texture
			and back_atlas.region == Rect2(32, 12, 112, 54)
			and back_art.material == null
			and back_shadow.texture == back_art.texture
			and back_shadow.position == _codex_script.BOOKMARK_SHADOW_OFFSET
			and back_text.text == "返回"
			and back_text.get_theme_font_size("font_size") == 18
			and is_equal_approx(arrow_center_y, back_button.size.y * 0.5),
			"返回短签以资产原色留在书页内，并以 48px/6px 两档间距建立层级")
	_expect(rarity.visible, "道具章节展开稀有度侧签")
	_expect(item_selected.visible and not item_idle.visible,
			"切入道具后只显示 selected 资产")
	_expect(hero_idle.visible and not hero_selected.visible,
			"英雄同步恢复为返回签同源的 idle 资产")
	_expect((rarity.get_node("Normal") as Button).position.y == 0.0, "普通二级签展开到紧凑首位")
	_expect((rarity.get_node("Rare") as Button).position.y == 50.0, "稀有二级签保持紧凑纸签节距")
	_expect((rarity.get_node("Legendary") as Button).position.y == 100.0,
			"传说二级签保持紧凑纸签节距")
	var normal := rarity.get_node("Normal") as Button
	_expect(normal.size == Vector2(100, 54), "稀有度签缩至主签约三分之二")
	var expected_rarity_palette: Array[Color] = [
		Color("3E77BD"), Color("6048A2"), Color("D49332")]
	_expect(_codex_script.RARITY_STRIPE_COLORS == expected_rarity_palette,
			"稀有度侧签使用通过的 C 宝石高识别方案")
	var item_catalog := load("res://src/battle/item_catalog.gd")
	var item_frame_style := load("res://src/ui/components/item_frame_style.gd")
	var item_gallery_script := load("res://src/ui/item_gallery_screen.gd")
	var item_draft_script := load("res://src/ui/components/item_draft_popup.gd")
	var expedition_script := load("res://src/expedition/expedition_screen.gd")
	_expect([item_catalog.RARITY_NORMAL, item_catalog.RARITY_RARE,
			item_catalog.RARITY_LEGENDARY] == expected_rarity_palette,
			"道具目录是 C 方案唯一基准色源")
	_expect(item_frame_style.CELL_TOP[1] == expected_rarity_palette[0]
			and item_frame_style.CELL_TOP[2] == expected_rarity_palette[1]
			and item_frame_style.FRAME_MID[3] == expected_rarity_palette[2],
			"图鉴/战斗栏/三选一的道具框主色同源 C 方案")
	_expect([item_gallery_script.TIER_TAG_COLOR[1], item_gallery_script.TIER_TAG_COLOR[2],
			item_gallery_script.TIER_TAG_COLOR[3]] == expected_rarity_palette,
			"道具图鉴详情标签同步 C 方案")
	_expect(item_draft_script.TIER_INK[1] == Color("3769A6")
			and item_draft_script.TIER_INK[2] == Color("543F8F")
			and item_draft_script.TIER_INK[3] == Color("BB812C"),
			"抽取/升级卡名使用 C 宝石方案的墨色档")
	_expect(expedition_script.COL_COMBAT_ITEM == expected_rarity_palette[0]
			and expedition_script.COL_RARE_ITEM == expected_rarity_palette[1]
			and expedition_script.COL_CHEST == expected_rarity_palette[2],
			"远征中的道具语义色同步 C 方案")
	for index: int in 3:
		var rarity_button := rarity.get_child(index) as Button
		var idle_art := rarity_button.get_node("IdleArt") as TextureRect
		var selected_art := rarity_button.get_node("SelectedArt") as TextureRect
		var idle_stripe := rarity_button.get_node("IdleStripe") as TextureRect
		var selected_stripe := rarity_button.get_node("SelectedStripe") as TextureRect
		var idle_material := idle_stripe.material as ShaderMaterial
		var selected_material := selected_stripe.material as ShaderMaterial
		_expect(idle_art.texture == hero_idle.texture
				and selected_art.texture == hero_selected.texture,
				"稀有度签不引入第三套纹理")
		_expect(idle_material != null and selected_material != null
				and idle_material.shader.resource_path
				== "res://assets/shaders/canvas_ui_codex_rarity_edge.gdshader"
				and selected_material.shader == idle_material.shader,
				"稀有度贴边由纸张染边材质承担")
		_expect(idle_material.get_shader_parameter("rarity_color")
				== _codex_script.RARITY_STRIPE_COLORS[index]
				and selected_material.get_shader_parameter("rarity_color")
				== _codex_script.RARITY_STRIPE_COLORS[index],
				"蓝紫金颜色由代码色板同步")
		_expect(idle_stripe.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED
				and selected_stripe.clip_children == CanvasItem.CLIP_CHILDREN_DISABLED
				and idle_stripe.texture == idle_art.texture
				and selected_stripe.texture == selected_art.texture,
				"染边本体保持可绘制，并由对应纸签纹理自身 Alpha 收住轮廓")
		_expect(is_equal_approx(float(idle_material.get_shader_parameter("edge_end_uv")), 0.32)
				and is_equal_approx(float(selected_material.get_shader_parameter("edge_end_uv")), 0.16)
				and is_equal_approx(float(idle_material.get_shader_parameter("blend_width_uv")), 0.035)
				and is_equal_approx(idle_stripe.offset_left, 1.0)
				and is_equal_approx(selected_stripe.offset_left, 1.0)
				and idle_stripe.get_node_or_null("Fill") == null
				and selected_stripe.get_node_or_null("Fill") == null,
				"染边沿资产真实 Alpha 成形、内收 1px，并以更窄范围向纸面渐融")
		_expect(rarity_button.has_node("IdleShadow")
				and rarity_button.has_node("SelectedShadow"),
				"稀有度签同样使用 Godot 投影")
		_expect(rarity_button.get_node_or_null("SelectionMarkerMask") == null,
				"稀有度签不再生成会伸缩的矩形索引")
		var selected_rarity := index == 0
		_expect(selected_art.visible == selected_rarity
				and idle_art.visible != selected_rarity
				and selected_stripe.visible == selected_rarity
				and idle_stripe.visible != selected_rarity,
				"稀有度纸面与贴边色条共用同一静态端点")
		_expect(is_equal_approx(rarity_button.self_modulate.a, 1.0),
				"二级签展开终态完全显现")
		_expect(not rarity_button.pressed.get_connections().is_empty()
				and not rarity_button.button_down.get_connections().is_empty(),
				"二级签保留快速跳转与按压反馈")
	(rarity.get_node("Legendary") as Button).pressed.emit()
	_expect(int(item.get("_tier")) == 3, "传说侧签可直接跳转")
	hero_tab.pressed.emit()
	for closing_button: Button in [
			rarity.get_node("Normal") as Button,
			rarity.get_node("Rare") as Button,
			rarity.get_node("Legendary") as Button,
	]:
		_expect(closing_button.mouse_filter == Control.MOUSE_FILTER_IGNORE,
				"反向收起期间二级签不会误触")
	await create_timer(0.22).timeout
	_expect(not rarity.visible, "回到英雄章节后二级签完成反向收起")
	item_tab.pressed.emit()
	await create_timer(0.24).timeout
	_expect(int(item.get("_tier")) == 1
			and int(item.get("_current_page")) == 0
			and int(item.get("_sel_idx")) == 0,
			"重新进入道具章节固定回到普通第一页首件")
	_expect(codex.call("get_gallery", 1) == item, "章节切换复用缓存实例")

	codex.visible = false
	var battle_overlay := _battle_codex_overlay.new() as Control
	root.add_child(battle_overlay)
	battle_overlay.call("open")
	var battle_codex := battle_overlay.get_node_or_null("CodexScreen") as Control
	_expect(battle_codex != null
			and battle_codex.scene_file_path == "res://src/ui/codex_screen.tscn",
			"战斗入口实例化同一个全局 CodexScreen")
	_expect(battle_overlay.get_node_or_null("Tab0") == null
			and battle_overlay.get_node_or_null("Tab1") == null,
			"战斗入口不残留旧版独立章节页签")
	_expect(not (battle_codex.get_node("BackButton") as Button).visible
			and (battle_codex.get_node("CloseButton") as Button).visible
			and (battle_codex.get_node("GalleryHost") as Control)
					.offset_transform_position.y > 0.0,
			"场景内图鉴取消返回签，并从轻微下移的淡入首帧开始")
	await create_timer(0.22).timeout
	_expect(is_equal_approx((battle_codex.get_node("Backdrop") as TextureRect)
				.self_modulate.a, _codex_script.OVERLAY_BACKDROP_ALPHA)
			and (battle_codex.get_node("GalleryHost") as Control)
					.offset_transform_position.is_zero_approx()
			and is_equal_approx((battle_codex.get_node("GalleryHost") as Control)
					.modulate.a, 1.0),
			"图鉴 180ms 上浮淡入完成后恢复通过布局坐标与半透明衬底")
	battle_overlay.call("close")
	await create_timer(0.05).timeout
	_expect(battle_overlay.visible
			and (battle_codex.get_node("GalleryHost") as Control).modulate.a < 1.0,
			"图鉴关闭后先播放下沉淡出，而不是首帧消失")
	await create_timer(_codex_script.OVERLAY_CLOSE_DURATION + 0.03).timeout
	_expect(not battle_overlay.visible
			and battle_codex.process_mode == Node.PROCESS_MODE_DISABLED,
			"战斗关闭图鉴后整棵共享实例停止输入")

	if _failures.is_empty():
		print("CODEX_BOOKMARK_PROBE_OK: book=editor_visible_instances shadow=three_step_soft_edge entrance=lift_fade_180ms exit=drop_fade_140ms close=flat_all_states_x_strokes_only tabs=low_amplitude_seam_fold rarity=paper_alpha_dyed_edge portraits=up10 paper_color=source_exact overlay=translucent_no_back native_text=optically_aligned battle=shared_scene cache=ok clicks=ok")
		quit(0)
	else:
		for failure: String in _failures:
			push_error("CODEX_BOOKMARK_PROBE: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
