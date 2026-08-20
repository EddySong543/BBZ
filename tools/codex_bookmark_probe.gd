extends Node

const CODEX_SCENE := preload("res://src/ui/codex_screen.tscn")
const CODEX_SCRIPT := preload("res://src/ui/codex_screen.gd")

var _failures: Array[String] = []


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	await get_tree().process_frame
	await get_tree().process_frame
	var codex := CODEX_SCENE.instantiate() as Control
	add_child(codex)
	await get_tree().process_frame

	_expect(codex.size == Vector2(1920, 1080), "统一图鉴根节点为 1920x1080")
	var backdrop := codex.get_node("Backdrop") as TextureRect
	_expect(backdrop.texture != null
			and backdrop.texture.resource_path
			== "res://assets/ui/codex/codex_smoky_brown_backdrop.png",
			"统一图鉴加载低饱和烟褐背景")
	_expect(backdrop.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"烟褐背景保持比例覆盖全屏")
	var backdrop_material := backdrop.material as ShaderMaterial
	_expect(backdrop_material != null
			and backdrop_material.shader.resource_path
			== "res://assets/shaders/canvas_ui_codex_backdrop_motion.gdshader",
			"背景只使用克制的专用微动效 shader")
	if backdrop_material != null:
		_expect(float(backdrop_material.get_shader_parameter("moving_mix")) <= 0.1,
				"背景移动纹理占比不超过一成")
	var shadow := codex.get_node("BookContactShadow") as ColorRect
	_expect(shadow.position == CODEX_SCRIPT.BOOK_ORIGIN + Vector2(14, 14),
			"书本接触影只向右下偏移 14px")
	var host := codex.get_node("GalleryHost") as Control
	_expect(host.position == CODEX_SCRIPT.BOOK_ORIGIN, "书页容器释放左侧签位")
	_expect(host.size == Vector2(1920, 1080), "书页内部保持原始设计坐标")
	_expect(host.scale == CODEX_SCRIPT.BOOK_SCALE, "书本统一缩放到通过构图")
	_expect(host.position == Vector2(230, 130) and host.scale == Vector2(0.76, 0.76),
			"书本按通过预览回到约 76% 的居中占比")
	_expect(shadow.size == host.size * host.scale, "书本接触影匹配 1459.2x820.8 显示尺寸")
	var hero := codex.call("get_gallery", 0) as Control
	_expect(hero.position == Vector2.ZERO and hero.scale == Vector2.ONE,
			"英雄图鉴在缩放容器内保持原始位置与比例")
	var hero_book := hero.find_child("CodexBook", true, false) as TextureRect
	_expect(hero_book != null and hero_book.size == Vector2(1920, 1080),
			"英雄书本资产仍完整覆盖设计画布")
	var hero_tab := codex.get_node("BookmarkLayer/HeroBookmark") as Button
	var item_tab := codex.get_node("BookmarkLayer/ItemBookmark") as Button
	var hero_idle := hero_tab.get_node("IdleArt") as TextureRect
	var hero_selected := hero_tab.get_node("SelectedArt") as TextureRect
	var item_idle := item_tab.get_node("IdleArt") as TextureRect
	var item_selected := item_tab.get_node("SelectedArt") as TextureRect
	_expect(not hero_idle.visible and hero_selected.visible,
			"英雄选中签使用独立加宽亮纸资产")
	_expect(item_idle.visible and not item_selected.visible,
			"道具未选签使用独立缩短暗纸资产")
	var resting_x := hero_tab.position.x
	_expect(not hero_tab.button_down.get_connections().is_empty(), "主签 button_down 已连接压入反馈")
	codex.call("_on_bookmark_down", hero_tab)
	await get_tree().create_timer(0.07).timeout
	_expect(hero_tab.position.x > resting_x,
			"侧签按下先向书页内压入 (rest=%.2f pressed=%.2f)" % [resting_x, hero_tab.position.x])
	codex.call("_on_bookmark_up", hero_tab)
	await get_tree().create_timer(0.2).timeout
	_expect(is_equal_approx(hero_tab.position.x, resting_x), "松开后侧签平滑回到选中终态")

	codex.call("show_section", 1)
	await get_tree().create_timer(0.28).timeout
	var item := codex.call("get_gallery", 1) as Control
	_expect(item.position == Vector2.ZERO and item.scale == Vector2.ONE,
			"道具图鉴在缩放容器内保持原始位置与比例")
	var item_book := item.find_child("CodexBook", true, false) as TextureRect
	_expect(item_book != null and item_book.size == Vector2(1920, 1080),
			"道具书本资产仍完整覆盖设计画布")
	var rarity := codex.get_node("BookmarkLayer/RarityBookmarks") as Control
	_expect(rarity.visible, "道具章节展开稀有度侧签")
	_expect(item_selected.visible and not item_idle.visible,
			"切入道具后切换为加宽加高的选中纸签")
	_expect(hero_idle.visible and not hero_selected.visible,
			"英雄同步切回较短未选中纸签")
	_expect((rarity.get_node("Normal") as Button).position.y == 0.0, "普通二级签展开到紧凑首位")
	_expect((rarity.get_node("Rare") as Button).position.y == 52.0, "稀有二级签保持 4px 间隔")
	_expect((rarity.get_node("Legendary") as Button).position.y == 104.0,
			"传说二级签保持 4px 间隔")
	(rarity.get_node("Legendary") as Button).pressed.emit()
	_expect(int(item.get("_tier")) == 3, "传说侧签可直接跳转")
	var saved_index := int(item.get("_sel_idx"))
	codex.call("show_section", 0)
	await get_tree().create_timer(0.22).timeout
	_expect(not rarity.visible, "回到英雄章节后二级签完成反向收起")
	codex.call("show_section", 1)
	await get_tree().create_timer(0.24).timeout
	_expect(int(item.get("_sel_idx")) == saved_index, "章节切换保留道具选中状态")
	_expect(codex.call("get_gallery", 1) == item, "章节切换复用缓存实例")

	if _failures.is_empty():
		print("CODEX_BOOKMARK_PROBE_OK: backdrop=subpixel_smoky_brown book=1459.2x820.8 tabs=dual_state cache=ok rarity_jump=ok animation=ok")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error("CODEX_BOOKMARK_PROBE: %s" % failure)
		get_tree().quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
