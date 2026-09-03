extends GutTest

const BATTLE_SCENE := preload("res://src/ui/battle_screen1.tscn")
const COMMAND_SLOT_SKIN := preload(
	"res://src/ui/components/command_sequence_slot_skin.gd")
const COMMAND_CANCEL_GLYPH := preload(
	"res://src/ui/components/command_sequence_cancel_glyph.gd")
const BATTLE_VARIANT_PATHS := [
	"res://src/ui/battle_screen1.tscn",
	"res://src/ui/battle_screen2.tscn",
	"res://src/ui/battle_screen3.tscn",
	"res://src/ui/battle_screen4.tscn",
	"res://src/ui/battle_screen5.tscn",
	"res://src/ui/battle_screen6.tscn",
	"res://src/ui/battle_screen7.tscn",
	"res://src/ui/battle_screen8.tscn",
	"res://src/ui/battle_screen9.tscn",
]


func _screen(p1_heroes: Array[HeroData] = []) -> Control:
	BattleSetup.reset()
	if not p1_heroes.is_empty():
		BattleSetup.p1_heroes = p1_heroes
	var screen := BATTLE_SCENE.instantiate()
	add_child_autofree(screen)
	screen.state = screen.State.PLAYER_SELECT
	screen._set_buttons_active(true)
	return screen


func _ready_item_slot(item_id: String) -> Dictionary:
	var item: ItemData = ItemCatalog.make(item_id)
	return {
		state = BattleCore.SlotState.CHARGING,
		item = item,
		since = -1,
		used = false,
		draft = [],
		upg_draft = [],
		draft_entry_uids = [],
		instance_uid = absi(item_id.hash()) + 1,
		temporary = false,
		current_durability = item.max_durability,
		max_durability = item.max_durability,
		used_turn = -1,
		lifecycle = "REAL",
	}


func _drag(screen: Control, source: Vector2, target: Vector2,
		inspect_preview: Callable = Callable()) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = source
	screen._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = target
	screen._input(motion)
	if inspect_preview.is_valid():
		inspect_preview.call()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = target
	screen._input(release)


func _click(screen: Control, point: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = point
	screen._input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	screen._input(release)


func test_clicking_an_action_only_selects_it_without_queuing() -> void:
	var screen: Control = _screen()
	var point: Vector2 = screen.btn_charge.get_global_rect().get_center()
	_click(screen, point)
	assert_eq(screen._turn_command_queue, [], "单击只进入预选态，不得直接编入顺序栏")
	assert_eq(screen.selected_action, ActionDef.Action.CHARGE)
	var juice := screen.btn_charge.get_node_or_null("ButtonJuice") as ButtonJuice
	assert_true(bool(juice.get("_selected")), "预选按钮保留原有选中反馈")


func test_h05_click_reveals_branch_and_dragging_selected_branch_commits_it() -> void:
	var screen: Control = _screen([
		load("res://assets/data/heroes/h05.tres") as HeroData,
		load("res://assets/data/heroes/h01.tres") as HeroData,
		load("res://assets/data/heroes/h02.tres") as HeroData,
	])
	screen.battle.energy[screen.PLAYER] = ActionDef.MAX_ENERGY
	screen._update_all()
	_click(screen, screen.btn_attack.get_global_rect().get_center())
	assert_eq(screen.selected_action, ActionDef.Action.ATTACK)
	assert_true(screen.longyuji_picker.visible, "点击波后应像旧版一样展开龙御极按钮")
	assert_true(screen._turn_command_queue.is_empty())
	_click(screen, screen.btn_longyuji_branch.get_global_rect().get_center())
	assert_true(screen._empowered_wave_armed, "点击上方技能只预选变体")
	assert_true(screen._turn_command_queue.is_empty(), "预选龙御极仍不等于使用")
	_drag(screen, screen.btn_longyuji_branch.get_global_rect().get_center(),
		screen._command_next_slot.get_global_rect().get_center())
	assert_true(screen._empowered_wave_armed, "拖入已预选分支不得反向取消龙御极")
	assert_eq(screen._turn_command_queue.size(), 1)
	assert_eq(String(screen._turn_command_queue[0]["kind"]), "action")


func test_dragging_action_to_next_slot_queues_once_and_uses_button_art() -> void:
	var screen: Control = _screen()
	screen._refresh_command_order_strip()
	var source: Vector2 = screen.btn_charge.get_global_rect().get_center()
	var target: Vector2 = screen._command_next_slot.get_global_rect().get_center()
	_drag(screen, source, target, func() -> void:
		assert_not_null(screen._command_drag_preview)
		assert_true(bool(screen._command_drag_preview.get_meta("uses_source_art", false)))
		assert_not_null(screen._command_drag_preview.find_child("HoverIcon", true, false),
			"拖动实体必须复用攒按钮图案，不能再退回纯文字标签")
	)
	assert_eq(screen._turn_command_queue.size(), 1)
	assert_eq(String(screen._turn_command_queue[0]["kind"]), "action")
	assert_eq(screen.selected_action, ActionDef.Action.CHARGE)
	assert_true(screen._command_order_strip.visible)
	assert_eq(screen._command_drag_preview, null)
	assert_not_null(screen._command_order_row.get_node_or_null("Step0"))
	assert_not_null(screen._command_order_row.get_node_or_null("NextSlot"))
	var juice := screen.btn_charge.get_node_or_null("ButtonJuice") as ButtonJuice
	var icon := screen.btn_charge.get_node_or_null("HoverIcon") as HoverIcon
	assert_true(bool(juice.get("_selected")), "来源按钮保留预选反馈，顺序槽表达是否已真正入队")
	assert_true(bool(icon.get("_selected_play")), "预选后的按钮图标继续沿用旧版选中播放")


func test_center_release_is_invalid_and_near_slot_drag_is_magnetized() -> void:
	var screen: Control = _screen()
	screen._refresh_command_order_strip()
	var source: Vector2 = screen.btn_attack.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = source
	screen._input(press)
	var slot_center: Vector2 = screen._command_next_slot.get_global_rect().get_center()
	var near_slot := slot_center + Vector2(92.0, 0.0)
	var motion := InputEventMouseMotion.new()
	motion.position = near_slot
	screen._input(motion)
	var preview_center: Vector2 = screen._command_drag_preview.position \
		+ screen._command_drag_preview.size * screen._command_drag_preview.scale * 0.5
	assert_lt(preview_center.distance_to(slot_center), near_slot.distance_to(slot_center),
		"进入吸附半径后，按钮虚影必须主动向末端空槽收束；slot=%s near=%s preview=%s scale=%s" \
		% [slot_center, near_slot, preview_center, screen._command_drag_preview.scale])
	motion.position = slot_center
	screen._input(motion)
	var slot_skin: Control = screen._command_next_slot.get_node("SlotSkin")
	assert_true(bool(slot_skin.get("hot")), "进入合法落点后只提亮并展开十字星底座")
	var hot_geometry: Dictionary = slot_skin.debug_geometry()
	var star_preview := screen.get_node("CommandSequenceStarPreview") as Control
	assert_almost_eq(float(hot_geometry["star_radius"]), maxf(
		float(star_preview.get("tuning_horizontal_radius")),
		float(star_preview.get("tuning_vertical_radius"))), 0.01,
		"吸附只提亮 Base 十字星，不得改变手调轮廓")
	assert_almost_eq(screen._command_next_slot.modulate.a, 1.0, 0.001,
		"拖到合法位置后底座必须由低亮转为全亮")
	assert_eq(screen._command_next_slot.scale, Vector2.ONE,
		"吸附反馈不得把整个空槽放大成按钮")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = Vector2(960.0, 540.0)
	screen._input(release)
	assert_true(screen._turn_command_queue.is_empty(), "屏幕中央松手不得再生成指令")
	assert_eq(screen.selected_action, -1)


func test_item_drag_uses_only_item_art_without_frame_or_fill() -> void:
	var screen: Control = _screen()
	screen.battle.slots[0][0] = _ready_item_slot("v2_t1_silver_coin")
	screen._update_all()
	screen._refresh_command_order_strip()
	var source: Vector2 = screen.p1_item_row.slot_global_rect(0).get_center()
	var target: Vector2 = screen._command_next_slot.get_global_rect().get_center()
	_drag(screen, source, target, func() -> void:
		assert_not_null(screen._command_drag_preview.find_child("ItemIcon", true, false))
		assert_null(screen._command_drag_preview.find_child("ItemFrame", true, false))
		assert_null(screen._command_drag_preview.find_child("ItemCell", true, false))
		assert_almost_eq(screen._command_drag_preview.size.x,
			screen.p1_item_row.slot_global_rect(0).size.x, 0.5,
			"道具拖动虚影必须按当前屏幕槽位大小生成，不能再次错位放大")
	)
	assert_eq(screen._turn_command_queue.size(), 1)
	assert_eq(String(screen._turn_command_queue[0]["kind"]), "item")
	var settled_icon := screen._command_order_row.get_node_or_null(
		"Step0/Visual/Art/ItemIcon") as TextureRect
	assert_not_null(settled_icon)
	assert_not_null(screen._command_order_row.get_node_or_null("Step0/Visual/Art/ItemFrame"),
		"道具一旦落入顺序槽，必须恢复图鉴同源的完整道具外框")
	assert_not_null(screen._command_order_row.get_node_or_null("Step0/Visual/Art/ItemCell"),
		"落槽道具必须恢复稀有度底色，拖动虚影才保持纯 icon")
	var settled_cost := screen._command_order_row.get_node_or_null(
		"Step0/Visual/Art/UseCostBadge") as IconBadge
	var settled_durability := screen._command_order_row.get_node_or_null(
		"Step0/Visual/Art/DurabilityBadge") as IconBadge
	assert_not_null(settled_cost, "战斗顺序槽中的道具显示使用费")
	assert_not_null(settled_durability, "战斗顺序槽中的道具显示当前耐久")
	if settled_icon != null:
		var target_rect: Rect2 = settled_icon.get_meta("item_art_target_rect")
		var visible_rect: Rect2 = settled_icon.get_meta("visible_alpha_rect")
		assert_true(target_rect.encloses(visible_rect), "战斗顺序槽道具美术不得越框")
	if settled_cost != null and settled_durability != null:
		assert_eq(settled_cost.number, 0)
		assert_eq(settled_durability.number, 1)
		assert_almost_eq(
			maxf(settled_cost.debug_icon_visible_rect().size.x,
				settled_cost.debug_icon_visible_rect().size.y),
			maxf(settled_durability.debug_icon_visible_rect().size.x,
				settled_durability.debug_icon_visible_rect().size.y), 0.01,
			"战斗顺序槽两枚属性图标保持同一可见尺度")
	screen._discard_ai_precomputed()


func test_command_slots_use_one_cross_star_without_any_wrapper() -> void:
	var screen: Control = _screen()
	screen._refresh_command_order_strip()
	var skin: Control = screen._command_next_slot.get_node("SlotSkin") as Control
	var preview := screen.get_node("CommandSequenceStarPreview") as Control
	assert_false(screen._command_next_slot is Container,
		"正式十字星不得再作为 Container 直系子节点，避免运行时布局改写 Base 几何")
	assert_eq(skin.get_script(), COMMAND_SLOT_SKIN)
	assert_null(screen._command_next_slot.get_node_or_null("SlotBg"),
		"十字星底座不得叠加背包按钮的果冻背景")
	assert_true(skin.material is ShaderMaterial,
		"十字星必须由随物理像素 footprint 重采样的专用 SSAA 材质绘制")
	assert_eq((skin.material as ShaderMaterial).shader.resource_path,
		"res://assets/shaders/canvas_ui_command_cross_star_ssaa.gdshader")
	assert_null(skin.get_node_or_null("SmoothStar"),
		"不得保留旧版硬填充 Polygon2D 与外扩羽化的双重绘制")
	assert_null(skin.get_node_or_null("SmoothStarFeather"))
	var geometry: Dictionary = skin.debug_geometry()
	assert_false(geometry.has("corner_guides"), "新方案必须彻底移除准星式四角卡榫")
	assert_false(geometry.has("ghost_outline"), "空槽不得保留任何包裹轮廓")
	assert_false(geometry.has("support_segments"), "单格不得保留底部托片")
	assert_false(geometry.has("star_segments"),
		"不得再用方块段拼成占满单格的巨大加号")
	var star_points: PackedVector2Array = geometry["star_points"]
	assert_gte(star_points.size(), 96,
		"底座必须用足够密的采样形成连续内凹曲线，而不是像素折线")
	assert_gte(int(geometry["curve_samples"]), 96)
	var expected_center := Vector2(33.0, 64.5) \
		+ (preview.get("tuning_center_offset") as Vector2)
	assert_eq(geometry["star_center"], expected_center,
		"微型底座位于按钮底部中央，不得回到单格正中心抢夺图案")
	var configured_radii := Vector2(
		float(preview.get("tuning_horizontal_radius")),
		float(preview.get("tuning_vertical_radius")))
	assert_eq(geometry["base_radii"], configured_radii,
		"正式槽位必须逐值复用 Base 预览节点的横纵比例")
	var live_radii: Vector2 = geometry["star_radii"]
	assert_eq(live_radii, configured_radii,
		"等待、吸附和落印不得改写 Base 中手调完成的十字星轮廓")
	assert_true(bool(geometry["geometry_locked_to_preview"]))
	assert_true(bool(geometry["smooth_vector_rendering"]),
		"Base 与正式场景必须共用平滑连续曲线，不得再走逐像素补边分支")
	assert_true(bool(geometry["analytic_antialiasing"]),
		"每个最终屏幕像素必须按数学轮廓的真实覆盖面积计算透明度")
	assert_false(bool(geometry["geometry_antialiasing"]),
		"不得退回硬多边形加外扩渐变带的近似方案")
	assert_eq(int(geometry["ssaa_samples_per_axis"]), 9,
		"Base 与 F6 均使用包含轴心的 9×9 子像素面积采样")
	assert_eq(String(geometry["render_path"]), "analytic_ssaa_9x9")
	assert_true(bool(skin.get_meta("uses_base_preview_template", false)),
		"正式顺序槽必须直接复制 Base 预览节点，禁止再创建近似形状")
	var quarter_index := star_points.size() / 4
	assert_eq(star_points[0], expected_center + Vector2(live_radii.x, 0.0))
	assert_eq(star_points[quarter_index],
		expected_center + Vector2(0.0, live_radii.y))
	assert_eq(star_points[quarter_index * 2],
		expected_center - Vector2(live_radii.x, 0.0))
	assert_eq(star_points[quarter_index * 3],
		expected_center - Vector2(0.0, live_radii.y))
	var diagonal_profile: float = pow(sqrt(0.5),
		float(preview.get("tuning_waist_power")))
	var diagonal_index := star_points.size() / 8
	assert_almost_eq(star_points[diagonal_index].x,
		expected_center.x + live_radii.x * diagonal_profile, 0.01)
	assert_almost_eq(star_points[diagonal_index].y,
		expected_center.y + live_radii.y * diagonal_profile, 0.01,
		"45 度截面必须逐值复用 Base 中手调的收腰参数")
	assert_almost_eq(float(geometry["pulse_duration"]), 6.0, 0.01)
	assert_true(bool(preview.get("editor_preview")))
	assert_almost_eq(float(geometry["profile_power"]),
		float(preview.get("tuning_waist_power")), 0.01,
		"十字星比例、位置、收腰和闪烁必须全部由可视预览节点 Inspector 驱动")
	assert_false(preview.visible, "F6 时只隐藏编辑器预览本体，动态顺序槽继续使用其参数")
	var original_vertical := float(preview.get("tuning_vertical_radius"))
	preview.set("tuning_vertical_radius", original_vertical + 2.0)
	var live_geometry: Dictionary = skin.debug_geometry()
	assert_almost_eq((live_geometry["base_radii"] as Vector2).y,
		original_vertical + 2.0, 0.01,
		"Remote Inspector 修改预览参数后，窗口内已生成的底座必须同步刷新")
	preview.set("tuning_vertical_radius", original_vertical)
	skin.set("pulse_strength", 0.0)
	preview.set("pulse_strength", 0.0)
	var runtime_points: PackedVector2Array = skin.debug_geometry()["star_points"]
	var preview_points: PackedVector2Array = preview.debug_geometry()["star_points"]
	assert_eq(runtime_points, preview_points,
		"Base 与正式战斗槽必须共享同一组局部顶点，横向拉伸不得被二次放大")
	assert_eq(skin.size, preview.size)
	assert_eq(skin.scale, Vector2.ONE,
		"正式绘制节点必须锁定 1:1 变换，禁止 PanelContainer 二次拉伸")
	var runtime_transform: Transform2D = skin.get_global_transform_with_canvas()
	var preview_transform: Transform2D = preview.get_global_transform_with_canvas()
	var runtime_center: Vector2 = skin.debug_geometry()["star_center"]
	var preview_center: Vector2 = preview.debug_geometry()["star_center"]
	var runtime_global_center: Vector2 = runtime_transform * runtime_center
	assert_almost_eq(fposmod(runtime_global_center.x, 1.0),
		fposmod(runtime_global_center.y, 1.0), 0.001,
		"十字星横纵轴必须落在相同半像素相位，禁止同形状再次产生横向权重偏差")
	for point_index: int in range(runtime_points.size()):
		var runtime_vector: Vector2 = runtime_transform.basis_xform(
			runtime_points[point_index] - runtime_center)
		var preview_vector: Vector2 = preview_transform.basis_xform(
			preview_points[point_index] - preview_center)
		assert_lt(runtime_vector.distance_to(preview_vector), 0.001,
			"正式场景的屏幕轮廓必须逐点复刻 Base，不能只保证局部参数相同")
	var star_color: Color = geometry["star_color"]
	assert_almost_eq(star_color.r, screen.countdown_ornament_color.r, 0.001)
	assert_almost_eq(star_color.g, screen.countdown_ornament_color.g, 0.001)
	assert_almost_eq(star_color.b, screen.countdown_ornament_color.b, 0.001,
		"十字星主色直接复用顶部倒计时菱形，而不是另配近似米白")
	assert_false(bool(geometry["outline_enabled"]), "十字星不得再绘制近黑环绕描边")
	assert_eq(geometry["underlay_color"], Color.TRANSPARENT)
	assert_almost_eq(float(geometry["underlay_width"]), 0.0, 0.001)
	assert_true(bool(geometry["processing"]), "末端空槽必须持续运行轻柔闪烁提示")
	skin.set("pulse_phase", 0.0)
	skin._process(3.0)
	var pulse_peak: Dictionary = skin.debug_geometry()
	assert_almost_eq(float(pulse_peak["pulse_strength"]), 1.0, 0.01)
	assert_almost_eq(float(pulse_peak["star_radius"]),
		maxf(configured_radii.x, configured_radii.y), 0.01,
		"6 秒慢闪只改变亮度，峰值也必须保持 Base 的精确宽高")
	assert_eq(pulse_peak["star_points"], runtime_points,
		"慢闪峰值不得让正式十字星相对 Base 发生任何几何变形")
	assert_eq(pulse_peak["star_color"], screen.countdown_ornament_color,
		"闪烁峰值必须达到有按钮时的完整米白色，不能再被空槽父透明度压暗")
	assert_eq(pulse_peak["bottom_shadow_offset"], preview.get("tuning_shadow_offset"))
	assert_eq(pulse_peak["bottom_shadow_color"], preview.get("tuning_shadow_color"))
	assert_almost_eq(float(pulse_peak["bottom_shadow_expand"]),
		float(preview.get("tuning_shadow_expand")), 0.001,
		"十字星投影位置、颜色和扩张必须全部来自 Inspector")
	assert_null(screen._command_order_row.get_node_or_null("RailSkin"),
		"十字星方案不再保留公共轨道")
	screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	var filled_skin := screen._command_order_row.get_node("Step0/SlotSkin") as Control
	var filled_geometry: Dictionary = filled_skin.debug_geometry()
	assert_gte((filled_geometry["star_points"] as PackedVector2Array).size(), 96,
		"空槽与已填槽共用同一个十字星，不另造第二层容器")
	assert_false(bool(filled_geometry["processing"]), "已放入的槽位停止提示闪烁")
	assert_false(filled_geometry.has("ghost_outline"))
	assert_false(filled_geometry.has("support_segments"))
	assert_gt(screen._command_order_strip.position.y, 790.0, "顺序栏需要比上一版稍向下")


func test_all_battle_variants_keep_command_star_at_one_to_one_transform() -> void:
	for scene_path: String in BATTLE_VARIANT_PATHS:
		BattleSetup.reset()
		var packed := load(scene_path) as PackedScene
		assert_not_null(packed, "%s 必须能加载" % scene_path)
		if packed == null:
			continue
		var screen := packed.instantiate() as Control
		add_child(screen)
		screen._refresh_command_order_strip()
		var preview := screen.get_node("CommandSequenceStarPreview") as Control
		var skin := screen._command_next_slot.get_node("SlotSkin") as Control
		var runtime_transform: Transform2D = skin.get_global_transform_with_canvas()
		var preview_transform: Transform2D = preview.get_global_transform_with_canvas()
		var global_center: Vector2 = runtime_transform \
			* (skin.debug_geometry()["star_center"] as Vector2)
		assert_almost_eq(fposmod(global_center.x, 1.0),
			fposmod(global_center.y, 1.0), 0.001,
			"%s 十字星横纵轴必须共享同一半像素相位" % scene_path)
		assert_lt(runtime_transform.x.distance_to(preview_transform.x), 0.001,
			"%s 正式十字星的横轴不得被场景变体二次拉伸" % scene_path)
		assert_lt(runtime_transform.y.distance_to(preview_transform.y), 0.001,
			"%s 正式十字星的纵轴不得被场景变体二次拉伸" % scene_path)
		assert_eq(skin.size, preview.size,
			"%s 必须逐值复用 Base 预览绘制尺寸" % scene_path)
		remove_child(screen)
		screen.free()


func test_direct_f6_battle_screen8_applies_the_shared_canvas_scaling() -> void:
	var root := get_tree().root
	var old_mode: Window.ContentScaleMode = root.content_scale_mode
	var old_aspect: Window.ContentScaleAspect = root.content_scale_aspect
	var old_size: Vector2i = root.content_scale_size
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
	root.content_scale_size = Vector2i.ZERO
	var packed := load("res://src/ui/battle_screen8.tscn") as PackedScene
	var screen := packed.instantiate() as Control
	add_child(screen)
	assert_eq(root.content_scale_mode, Window.CONTENT_SCALE_MODE_CANVAS_ITEMS,
		"直接 F6 battle_screen8 也必须采用与 Boot 相同的高质量 2D 目标分辨率渲染")
	assert_eq(root.content_scale_aspect, Window.CONTENT_SCALE_ASPECT_KEEP,
		"F6 与正式启动都必须等比缩放，禁止再次横向拉伸十字星")
	assert_eq(root.content_scale_size, Vector2i(1920, 1080),
		"F6 必须复用正式启动的设计画布，不能走编辑器默认窗口缩放")
	remove_child(screen)
	screen.free()
	root.content_scale_mode = old_mode
	root.content_scale_aspect = old_aspect
	root.content_scale_size = old_size


func test_filled_slot_lands_on_the_cross_star_with_a_short_stamp() -> void:
	var screen: Control = _screen()
	screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	var slot := screen._command_order_row.get_node("Step0") as Control
	var skin: Control = slot.get_node("SlotSkin")
	var visual := slot.get_node("Visual") as Control
	screen._play_command_slot_land(slot)
	var lock_value: Variant = skin.get("lock_progress")
	assert_not_null(lock_value, "令牌皮肤必须公开十字星展开进度")
	if lock_value == null:
		return
	assert_almost_eq(float(lock_value), 0.0, 0.01,
		"落位开始时十字星尖臂尚未完全展开")
	assert_lt(visual.modulate.a, 0.8, "内容先淡入，不能在放入首帧直接完全显现")
	assert_lt(visual.position.y,
		(slot.get_meta("command_visual_base_position") as Vector2).y,
		"行动令牌从上方 2px 轻落，不能做按钮按压")
	assert_eq(slot.scale, Vector2.ONE, "令牌落位不得缩放整格")
	assert_almost_eq(float(slot.get_meta("command_land_duration")), 0.12, 0.001)
	var landing_tween := slot.get_meta("command_land_tween") as Tween
	await landing_tween.finished
	assert_almost_eq(float(skin.get("lock_progress")), 1.0, 0.02,
		"落位结束后十字星保持完整展开")
	assert_almost_eq(float(skin.get("flash_strength")), 0.0, 0.02,
		"轨道节点落印只脉冲一次，结束后不常亮")
	assert_gte(float(skin.get("flash_peak")), 0.95,
		"十字星落定时必须真正达到一次可读落印峰值")
	assert_almost_eq(visual.modulate.a, 1.0, 0.02, "内容落在十字星上后完全显现")
	assert_almost_eq(visual.position.y,
		(slot.get_meta("command_visual_base_position") as Vector2).y, 0.02)
	var art := slot.get_node("Visual/Art") as Control
	var art_bottom: float = art.position.y + art.size.y * art.scale.y
	var settled_geometry: Dictionary = skin.debug_geometry()
	var star_top: float = (settled_geometry["star_center"] as Vector2).y \
		- (settled_geometry["star_radii"] as Vector2).y
	assert_lte(art_bottom, star_top,
		"放大的行动素材必须停在十字星上方，不能再轻微盖住星尖")
	assert_eq(slot.scale, Vector2.ONE)


func test_empty_slot_uses_internal_slow_pulse_and_filled_slot_stays_opaque() -> void:
	var screen: Control = _screen()
	screen._refresh_command_order_strip()
	assert_almost_eq(screen._command_next_slot.modulate.a, 1.0, 0.001,
		"空槽父节点保持全亮，避免把慢闪峰值二次压暗")
	var empty_skin := screen._command_next_slot.get_node("SlotSkin") as Control
	assert_lt((empty_skin.debug_geometry()["star_color"] as Color).a, 1.0,
		"等待状态的暗部仍由十字星自身透明度表达")
	screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	var filled := screen._command_order_row.get_node("Step0") as Control
	assert_almost_eq(filled.modulate.a, 1.0, 0.001, "落位后的当前格恢复完全不透明")
	assert_almost_eq(screen._command_next_slot.modulate.a, 1.0, 0.001,
		"新衍生空槽同样保留完整高光上限")


func test_changed_command_sequence_refreshes_with_one_subtle_settle() -> void:
	var screen: Control = _screen()
	screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	var refresh_tween := screen._command_refresh_tween as Tween
	assert_not_null(refresh_tween, "队列内容变化后需要一次简约刷新缓动")
	assert_almost_eq(screen._command_order_row.position.y,
		screen.COMMAND_REFRESH_OFFSET_Y, 0.01)
	assert_lt(screen._command_order_row.modulate.a, 1.0,
		"刷新首帧只做轻淡入，不能硬切完整亮度")
	assert_almost_eq(float(screen._command_order_row.get_meta("command_refresh_duration")),
		screen.COMMAND_REFRESH_DURATION, 0.001)
	await refresh_tween.finished
	assert_almost_eq(screen._command_order_row.position.y, 0.0, 0.01)
	assert_almost_eq(screen._command_order_row.modulate.a, 1.0, 0.01)
	var completed_tween: Tween = screen._command_refresh_tween
	screen._refresh_command_order_strip()
	assert_eq(screen._command_refresh_tween, completed_tween,
		"队列内容未变化时不得重复播放刷新动画")


func test_command_strip_matches_bottom_button_dimming_during_resolution() -> void:
	var screen: Control = _screen()
	screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	screen.state = screen.State.RESOLVING
	screen._set_buttons_active(false)
	assert_true(screen._command_order_strip.visible,
		"结算阶段顺序栏必须和底部按钮一样保留显示，不能消失一段时间")
	assert_almost_eq(screen._command_order_strip.modulate.a,
		screen.buttons_ctrl.modulate.a, 0.001,
		"顺序栏必须与底部按钮共用结算降透明度")
	var cancel := screen._command_order_row.find_child("Cancel", true, false) as Button
	assert_true(cancel.disabled, "结算时顺序槽只展示，不再允许撤销")


func test_empty_command_strip_stays_visible_and_dims_during_intro_and_resolution() -> void:
	var screen: Control = _screen()
	screen._turn_command_queue.clear()
	screen._refresh_command_order_strip()
	for inactive_state: int in [screen.State.TURN_INTRO, screen.State.RESOLVING]:
		screen.state = inactive_state
		screen._set_buttons_active(false, true)
		assert_true(screen._command_order_strip.visible,
			"即使本轮序列为空，F6 开场与播放动画时也只能降透明度，不能消失")
		assert_almost_eq(screen._command_order_strip.modulate.a,
			screen.buttons_ctrl.modulate.a, 0.001)
		assert_not_null(screen._command_order_row.get_node_or_null("NextSlot"),
			"降暗期间仍应保留末端待放入空槽")


func test_each_filled_slot_has_engraved_line_cancel_glyph_that_removes_the_step() -> void:
	var screen: Control = _screen()
	screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	var cancel := screen._command_order_row.find_child("Cancel", true, false) as Button
	assert_not_null(cancel)
	var glyph := cancel.get_node_or_null("CancelGlyph") as Control
	var cancel_preview := screen.get_node("CommandSequenceCancelPreview") as Control
	assert_not_null(glyph, "撤销键使用与丝滑十字星同源的自绘 x，而不是字体或方块拼接")
	assert_eq(glyph.get_script(), COMMAND_CANCEL_GLYPH)
	var glyph_geometry: Dictionary = glyph.debug_geometry()
	assert_eq(glyph_geometry["center"],
		Vector2(10.0, 10.0) + cancel_preview.get("tuning_center_offset"))
	assert_almost_eq(float(glyph_geometry["line_length"]),
		float(cancel_preview.get("tuning_line_length")), 0.01)
	assert_almost_eq(float(glyph_geometry["main_width"]),
		float(cancel_preview.get("tuning_line_width")), 0.01)
	assert_false(bool(glyph_geometry["underlay_enabled"]),
		"撤销 x 不再叠加宽暗压边，避免 20px 下形成模糊边")
	assert_almost_eq(float(glyph_geometry["underlay_width"]), 0.0, 0.01)
	assert_eq(glyph_geometry["bottom_shadow_offset"],
		cancel_preview.get("tuning_shadow_offset"))
	assert_eq(glyph_geometry["bottom_shadow_color"],
		cancel_preview.get("tuning_shadow_color"))
	assert_almost_eq(float(glyph_geometry["bottom_shadow_width"]),
		float(cancel_preview.get("tuning_shadow_width")), 0.01,
		"撤销 x 的投影位置、颜色和粗度必须由 Inspector 独立调整")
	assert_false(bool(glyph_geometry["antialiased"]),
		"小 x 保留双斜线形状，但不能再因三层抗锯齿叠加而发糊")
	assert_eq(cancel.position, Vector2(60.0, -15.0) \
		+ cancel_preview.get("tuning_slot_offset"),
		"撤销键向右上移开按钮角部，避免几乎碰上行动素材")
	var original_length := float(cancel_preview.get("tuning_line_length"))
	cancel_preview.set("tuning_line_length", original_length + 1.0)
	assert_almost_eq(float(glyph.debug_geometry()["line_length"]),
		original_length + 1.0, 0.01,
		"Remote Inspector 修改小 x 后，现有顺序槽必须立即同步")
	cancel_preview.set("tuning_line_length", original_length)
	assert_true(cancel.get_theme_stylebox("normal") is StyleBoxEmpty,
		"撤销 x 必须与十字星底座解耦，不保留额外按钮底板")
	assert_false(cancel.pressed.get_connections().is_empty())
	screen._on_command_cancel_pressed(0)
	assert_true(screen._turn_command_queue.is_empty())
	assert_eq(screen.selected_action, -1)
	screen._discard_ai_precomputed()


func test_action_and_item_order_is_the_submit_order() -> void:
	var screen: Control = _screen()
	screen.battle.slots[0][0] = _ready_item_slot("v2_t1_silver_coin")
	screen._update_all()
	screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	screen._dispatch_command_drop({kind = "item", slot = 0})
	var sequence: Array[Dictionary] = screen._command_sequence_for_submit()
	assert_eq(String(sequence[0]["kind"]), "action")
	assert_eq(String(sequence[1]["kind"]), "item")
	assert_eq(int(sequence[1]["slot"]), 0)
	screen._discard_ai_precomputed()


func test_replacing_the_only_action_is_a_valid_drop_even_when_queue_shape_is_unchanged() -> void:
	var screen: Control = _screen()
	assert_true(screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	}))
	assert_true(screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.ATTACK, button = screen.btn_attack,
	}), "动作条目仍是同一个字典槽时，也必须把更换动作视为合法落印")
	assert_eq(screen.selected_action, ActionDef.Action.ATTACK)
	assert_eq(screen._turn_command_queue.size(), 1)
	assert_eq(screen._command_drop_landing_index, 0)


func test_next_slot_is_the_only_drop_target_and_stays_clear_of_buttons() -> void:
	var screen: Control = _screen()
	screen._refresh_command_order_strip()
	assert_null(screen.get_node_or_null("CommandDropZone"), "中央大方框必须彻底移除")
	assert_not_null(screen._command_next_slot)
	var slot_rect: Rect2 = screen._command_next_slot.get_global_rect()
	assert_false(slot_rect.has_point(Vector2(960.0, 540.0)), "屏幕中央不再是落点")
	assert_false(slot_rect.intersects(screen.btn_confirm.get_global_rect()))
	assert_true(screen.COMMAND_STRIP_RECT.end.y < screen.btn_charge.get_global_rect().position.y,
		"顺序条在五个行动按钮上方，不遮挡拖拽源")
	var skin: Control = screen._command_next_slot.get_node("SlotSkin") as Control
	var geometry: Dictionary = skin.debug_geometry()
	assert_gte((geometry["star_points"] as PackedVector2Array).size(), 96,
		"末端空槽只显示一个十字星底座，不出现任何包裹轮廓")


func test_long_command_row_stays_centered_on_one_line() -> void:
	var screen: Control = _screen()
	for index: int in range(7):
		screen._turn_command_queue.append({kind = "item", slot = index % 3})
	screen._refresh_command_order_strip()
	await get_tree().create_timer(0.24).timeout
	var first := screen._command_order_row.get_node("Step0") as Control
	var last := screen._command_order_row.get_node("Step6") as Control
	var next := screen._command_next_slot as Control
	assert_almost_eq(first.position.y, last.position.y, 0.01, "指令增多后不得换行")
	assert_almost_eq(last.position.y, next.position.y, 0.01)
	assert_gte(first.position.x, 0.0)
	assert_lte(next.position.x + next.size.x, screen.COMMAND_STRIP_RECT.size.x)
	var occupied_center := (first.position.x + next.position.x + next.size.x) * 0.5
	assert_almost_eq(occupied_center, screen.COMMAND_STRIP_RECT.size.x * 0.5, 0.5,
		"已填槽和末端空槽作为一个整体严格居中")


func test_switch_button_opens_targets_and_target_drop_queues_switch() -> void:
	var screen: Control = _screen()
	screen._on_switch_main_pressed()
	assert_true(screen._switch_tray_open)
	assert_true(screen._turn_command_queue.is_empty(), "打开候选层还不是指令")
	var switch_source: Dictionary = screen._command_source_at(
		screen.btn_switch.get_global_rect().get_center())
	assert_true(switch_source.is_empty(),
		"切换主按钮只负责点击展开，不再作为可拖入指令；实际命中=%s" % str(switch_source))
	var source: Vector2 = screen._switch_candidate_frames[0].get_global_rect().get_center()
	var target: Vector2 = screen._command_next_slot.get_global_rect().get_center()
	_drag(screen, source, target, func() -> void:
		assert_not_null(screen._command_drag_preview.find_child("Portrait", true, false),
			"切换拖动实体必须是实际英雄头像框")
	)
	assert_eq(screen.selected_action, ActionDef.Action.SWITCH)
	assert_eq(screen._turn_command_queue.size(), 1)
	assert_eq(String(screen._turn_command_queue[0]["kind"]), "action")
	var switch_icon := screen._command_order_row.find_child("SwitchIcon", true, false) as HoverIcon
	var art := screen._command_order_row.get_node("Step0/Visual/Art") as Control
	var queued_bg := art.get_node_or_null("Bg") as ColorRect
	var source_bg := screen.btn_switch.get_node("Bg") as ColorRect
	assert_not_null(switch_icon, "切换顺序条目应直接显示与基础按钮同级的切换 icon")
	assert_not_null(queued_bg, "切换顺序条目必须带上正式按钮的蓝色填充与外框")
	assert_eq((queued_bg.material as ShaderMaterial).shader,
		(source_bg.material as ShaderMaterial).shader,
		"顺序条切换按钮与正式切换按钮复用同一果冻边框 shader")
	assert_eq((queued_bg.material as ShaderMaterial).get_shader_parameter("fill_top"),
		(source_bg.material as ShaderMaterial).get_shader_parameter("fill_top"),
		"蓝色填充不得在顺序条中另配一套近似色")
	assert_null(art.find_child("Portrait", true, false),
		"切换落入顺序条后不得继续携带英雄头像框")
	assert_null(art.find_child("SwitchMarker", true, false),
		"纯 icon 方案不再使用头像右下角的小标记")
	assert_eq(art.size, screen.btn_switch.size,
		"切换 icon 与其他基础按钮使用同一来源按钮画布比例")
	var sequence: Array[Dictionary] = screen._command_sequence_for_submit()
	assert_eq(int(sequence[0]["action"]), ActionDef.Action.SWITCH)
	assert_eq(int(sequence[0]["target"]), screen.selected_switch)


func test_targeted_item_keeps_its_original_queue_position_until_target_is_chosen() -> void:
	var screen: Control = _screen()
	screen.battle.slots[0] = [
		_ready_item_slot("v2_t1_healing_salve"),
		_ready_item_slot("v2_t1_silver_coin"),
		_ready_item_slot("v2_t1_cracked_shield"),
	]
	screen._update_all()
	screen._dispatch_command_drop({kind = "item", slot = 0})
	assert_eq(screen._pending_item_hero_target_slot, 0)
	assert_eq(String(screen._turn_command_queue[0]["kind"]), "item")
	assert_eq(int(screen._turn_command_queue[0]["slot"]), 0)
	var target_slot: int = screen.p1_frame_slots[1]
	assert_true(screen._select_friendly_item_target(1))
	assert_eq(screen.selected_item_hero_targets, {0: target_slot})
	var sequence: Array[Dictionary] = screen._command_sequence_for_submit()
	assert_eq(String(sequence[0]["kind"]), "item")
	assert_eq(int(sequence[0]["target"]), target_slot)
	screen._discard_ai_precomputed()
