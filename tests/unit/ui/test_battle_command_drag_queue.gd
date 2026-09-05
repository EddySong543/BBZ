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
		var sequence_layout := ItemFrameStyle.item_frame_layout(&"sequence")
		assert_eq(settled_cost.debug_icon_visible_rect(),
			sequence_layout["energy_icon_rect"])
		assert_eq(settled_durability.debug_icon_visible_rect(),
			sequence_layout["durability_icon_rect"],
			"战斗顺序槽保留调参台中两枚属性图标各自的矩形")
		var row_frame := screen.p1_item_row._tex_frames[0] as TextureRect
		var row_cost := screen.p1_item_row._cost_badges[0] as IconBadge
		var row_durability := screen.p1_item_row._durability_badges[0] as IconBadge
		var sequence_frame := screen._command_order_row.get_node(
			"Step0/Visual/Art/ItemFrame") as TextureRect
		var row_cost_anchor := (row_cost.position - row_frame.position) / row_frame.size.x
		var row_durability_anchor := (
			row_durability.position - row_frame.position) / row_frame.size.x
		var sequence_cost_anchor := (
			settled_cost.position - sequence_frame.position) / sequence_frame.size.x
		var sequence_durability_anchor := (
			settled_durability.position - sequence_frame.position) / sequence_frame.size.x
		assert_almost_eq(sequence_cost_anchor.x, row_cost_anchor.x, 0.0001)
		assert_almost_eq(sequence_cost_anchor.y, row_cost_anchor.y, 0.0001)
		assert_almost_eq(sequence_durability_anchor.x, row_durability_anchor.x, 0.0001)
		assert_almost_eq(sequence_durability_anchor.y, row_durability_anchor.y, 0.0001,
			"道具进入顺序槽后，能量与耐久角标只能随完整框等比缩放，不能相对漂移")
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
	var runtime_points: PackedVector2Array = skin.debug_geometry()["star_points"]
	var preview_points: PackedVector2Array = preview.debug_geometry()["star_points"]
	assert_eq(runtime_points, preview_points,
		"Base 与正式战斗槽必须共享同一组局部顶点，整体只允许统一等比放大")
	assert_eq(skin.size, preview.size)
	assert_eq(skin.scale, Vector2.ONE * screen.COMMAND_SLOT_SCALE,
		"任务5只允许统一等比放大十字星，不能改变横纵比例")
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
			preview_points[point_index] - preview_center) * screen.COMMAND_SLOT_SCALE
		assert_lt(runtime_vector.distance_to(preview_vector), 0.001,
			"正式场景必须逐点等比放大 Base 轮廓，不能独立改写横纵轴")
	var star_color: Color = geometry["star_color"]
	assert_almost_eq(star_color.r, screen.countdown_ornament_color.r, 0.001)
	assert_almost_eq(star_color.g, screen.countdown_ornament_color.g, 0.001)
	assert_almost_eq(star_color.b, screen.countdown_ornament_color.b, 0.001,
		"十字星主色直接复用顶部倒计时菱形，而不是另配近似米白")
	assert_false(bool(geometry["outline_enabled"]), "十字星不得再绘制近黑环绕描边")
	assert_eq(geometry["underlay_color"], Color.TRANSPARENT)
	assert_almost_eq(float(geometry["underlay_width"]), 0.0, 0.001)
	assert_false(bool(geometry["processing"]),
		"任务5移除空槽循环呼吸，空闲与高亮都必须是稳定状态")
	var static_empty: Dictionary = skin.debug_geometry()
	assert_almost_eq(float(static_empty["pulse_strength"]), 0.0, 0.01)
	assert_almost_eq(float(static_empty["star_radius"]),
		maxf(configured_radii.x, configured_radii.y), 0.01,
		"稳定明暗状态不能改变 Base 的精确宽高")
	assert_eq(static_empty["star_points"], runtime_points,
		"移除呼吸后不得改变十字星局部几何")
	assert_lt((static_empty["star_color"] as Color).a, 1.0,
		"没有待放入内容时空槽保持稳定低亮")
	assert_eq(static_empty["bottom_shadow_offset"], preview.get("tuning_shadow_offset"))
	assert_eq(static_empty["bottom_shadow_color"], preview.get("tuning_shadow_color"))
	assert_almost_eq(float(static_empty["bottom_shadow_expand"]),
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


func test_all_battle_variants_keep_command_star_at_one_uniform_scale() -> void:
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
		assert_lt(runtime_transform.x.distance_to(
				preview_transform.x * screen.COMMAND_SLOT_SCALE), 0.001,
			"%s 正式十字星横轴必须只做统一等比放大" % scene_path)
		assert_lt(runtime_transform.y.distance_to(
				preview_transform.y * screen.COMMAND_SLOT_SCALE), 0.001,
			"%s 正式十字星纵轴必须只做统一等比放大" % scene_path)
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
	var star_top: float = skin.position.y + (
		(settled_geometry["star_center"] as Vector2).y
		- (settled_geometry["star_radii"] as Vector2).y) * skin.scale.y
	assert_lte(art_bottom, star_top,
		"放大的行动素材必须停在十字星上方，不能再轻微盖住星尖")
	assert_eq(slot.scale, Vector2.ONE)


func test_next_slot_is_static_dim_then_stays_hot_while_waiting_for_a_drop() -> void:
	var screen: Control = _screen()
	screen._refresh_command_order_strip()
	assert_almost_eq(screen._command_next_slot.modulate.a, 1.0, 0.001,
		"空槽父节点保持全亮，明暗只由十字星自身表达")
	var empty_skin := screen._command_next_slot.get_node("SlotSkin") as Control
	assert_false(bool(empty_skin.get("hot")))
	assert_false(bool(empty_skin.debug_geometry()["processing"]),
		"空闲槽不再运行循环呼吸")
	assert_lt((empty_skin.debug_geometry()["star_color"] as Color).a, 1.0,
		"没有预选内容时维持稳定低亮")
	screen._dispatch_command_click({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	empty_skin = screen._command_next_slot.get_node("SlotSkin") as Control
	assert_true(bool(empty_skin.get("hot")),
		"点击底部行动按钮后，下一个空十字星槽必须持续高亮")
	assert_eq((empty_skin.debug_geometry()["star_color"] as Color).a, 1.0)
	assert_false(bool(empty_skin.debug_geometry()["processing"]),
		"持续高亮是稳定状态，不得换成循环呼吸")
	assert_true(screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	}))
	var filled := screen._command_order_row.get_node("Step0") as Control
	assert_almost_eq(filled.modulate.a, 1.0, 0.001, "落位后的当前格恢复完全不透明")
	var next_skin := screen._command_next_slot.get_node("SlotSkin") as Control
	assert_false(bool(next_skin.get("hot")), "动作放入后解除下一空槽高亮")
	assert_almost_eq(screen._command_next_slot.modulate.a, 1.0, 0.001,
		"新衍生空槽保持正常父透明度")


func test_switch_choice_opens_and_closes_the_same_steady_slot_highlight() -> void:
	var screen: Control = _screen()
	screen._on_switch_main_pressed()
	var skin := screen._command_next_slot.get_node("SlotSkin") as Control
	assert_true(screen._switch_tray_open)
	assert_true(bool(skin.get("hot")),
		"点击底部切换按钮进入候选态时也要提示下一空槽")
	screen._on_switch_main_pressed()
	assert_false(screen._switch_tray_open)
	assert_false(bool(skin.get("hot")), "取消切换候选后解除高亮")


func test_unchanged_refresh_reuses_nodes_and_only_landing_owns_feedback() -> void:
	var screen: Control = _screen()
	var original_next: Control = screen._command_next_slot
	screen._refresh_command_order_strip()
	assert_same(screen._command_next_slot, original_next,
		"队列内容未变化时必须复用整排节点，禁止强制重建")
	assert_true(screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	}))
	assert_almost_eq(screen._command_order_row.position.y, 0.0, 0.01)
	assert_almost_eq(screen._command_order_row.modulate.a, 1.0, 0.01)
	assert_false(screen._command_order_row.has_meta("command_refresh_duration"),
		"整排不再叠加下落淡入，落槽只由单格反馈承担")
	var step := screen._command_order_row.get_node("Step0") as Control
	screen._play_command_slot_land(step)
	assert_true(step.has_meta("command_land_tween"),
		"序列真正变化后只允许一次克制的单槽落位反馈")
	var rebuilt_next: Control = screen._command_next_slot
	screen._refresh_command_order_strip()
	assert_same(screen._command_next_slot, rebuilt_next,
		"落位后的常规刷新不得再次替换节点或重播动画")


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
	assert_eq(cancel.position, Vector2(screen.COMMAND_SLOT_SIZE - 6.0, -15.0) \
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


func test_insufficient_energy_uses_the_execution_phase_whole_button_gray() -> void:
	var screen: Control = _screen()
	screen.battle.energy[screen.PLAYER] = 0
	screen._refresh_action_affordance()
	var badge := screen.btn_attack.get_node("CostPips") as IconBadge
	assert_true(screen.btn_attack.disabled)
	assert_eq(screen.btn_attack.modulate, screen.ACTION_DISABLED_BUTTON_MODULATE,
		"能量不足必须从按钮根节点统一压暗，边框与角标不能分裂")
	assert_eq(badge.modulate, Color.WHITE,
		"费用角标不得额外叠加第二层灰度")
	assert_true(badge.is_ancestor_of(badge.get_node("Icon")))
	assert_true(screen.btn_attack.is_ancestor_of(badge),
		"费用角标必须留在整按钮调制链内")
	screen.battle.energy[screen.PLAYER] = ActionDef.BASE_ACTION_DEF[
		ActionDef.Action.ATTACK]["cost"]
	screen._refresh_action_affordance()
	assert_false(screen.btn_attack.disabled)
	assert_eq(screen.btn_attack.modulate, Color.WHITE,
		"重新具备能量后按钮边框和内容一起恢复原色")
	assert_eq(badge.modulate, Color.WHITE,
		"重新具备能量后费用角标必须与按钮同步恢复原色")


func test_queued_charge_cannot_overwrite_other_disabled_action_visuals() -> void:
	var screen: Control = _screen()
	screen.battle.energy[screen.PLAYER] = 0
	screen._refresh_action_affordance()
	var disabled_buttons: Array[Button] = [
		screen.btn_attack,
		screen.btn_big_attack,
		screen.btn_big_defend,
	]
	for button: Button in disabled_buttons:
		assert_true(button.disabled)
		assert_eq(button.modulate, screen.ACTION_DISABLED_BUTTON_MODULATE)

	assert_true(screen._dispatch_command_drop({
		kind = "action",
		action = ActionDef.Action.CHARGE,
		button = screen.btn_charge,
	}), "0能量时攒仍可正常进入顺序序列")
	assert_eq(screen._turn_command_queue.size(), 1)
	for button: Button in disabled_buttons:
		var badge := button.get_node("CostPips") as IconBadge
		assert_true(button.disabled, "攒入槽后不可支付动作仍须保持禁用")
		assert_eq(button.modulate, screen.ACTION_DISABLED_BUTTON_MODULATE,
			"队列刷新和选中态重置不得覆盖整按钮灰态")
		assert_eq(badge.modulate, Color.WHITE,
			"费用角标只继承按钮根节点灰态，不能叠加或脱离")

	# 直接覆盖曾触发回归的公共重置入口，防止后续新路径再次写回旧白色。
	screen._reset_button_styles()
	for button: Button in disabled_buttons:
		assert_eq(button.modulate, screen.ACTION_DISABLED_BUTTON_MODULATE)

	screen._on_command_cancel_pressed(0)
	assert_true(screen._turn_command_queue.is_empty())
	for button: Button in disabled_buttons:
		assert_eq(button.modulate, screen.ACTION_DISABLED_BUTTON_MODULATE,
			"取消入槽动作后也必须由同一状态合成入口恢复灰态")


func test_task5_enlarges_slots_content_and_spacing_as_one_system() -> void:
	var screen: Control = _screen()
	assert_eq(screen.COMMAND_SLOT_SIZE, 76.0)
	assert_eq(screen.COMMAND_SLOT_GAP, 16.0)
	assert_eq(screen.COMMAND_STRIP_RECT.size, Vector2(880.0, 104.0))
	assert_true(screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	}))
	var first := screen._command_order_row.get_node("Step0") as Control
	var art := first.get_node("Visual/Art") as Control
	var rendered_size := art.size * art.scale
	var available: float = screen.COMMAND_SLOT_SIZE \
		- screen.COMMAND_SLOT_ART_INSET * 2.0
	assert_almost_eq(maxf(rendered_size.x, rendered_size.y), available, 0.01,
		"行动按钮内容必须随槽位净区统一放大到 68px")
	var skin := first.get_node("SlotSkin") as Control
	assert_eq(skin.scale, Vector2.ONE * screen.COMMAND_SLOT_SCALE,
		"底座只做与槽位一致的等比放大")
	screen.battle.slots[0][0] = _ready_item_slot("v2_t1_silver_coin")
	screen._update_all()
	assert_true(screen._dispatch_command_drop({kind = "item", slot = 0}))
	first = screen._command_order_row.get_node("Step0") as Control
	var second := screen._command_order_row.get_node("Step1") as Control
	assert_almost_eq(second.position.x - first.position.x - first.size.x,
		screen.COMMAND_SLOT_GAP, 0.01,
		"放大后的槽间距必须统一为 16px")
	assert_true(screen.COMMAND_STRIP_RECT.end.y < screen.btn_charge.get_global_rect().position.y,
		"放大后的顺序栏仍不得压到下方行动按钮")


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
	var expected_target_frame: HeroFrame = screen._switch_candidate_frames[0]
	_drag(screen, source, target, func() -> void:
		assert_not_null(screen._command_drag_preview.find_child("Portrait", true, false),
			"切换拖动实体必须是实际英雄头像框")
		assert_null(screen._command_drag_preview.find_child("SwitchMarker", true, false),
			"拖动阶段只显示目标头像框，右下角不得额外叠加切换标记")
		assert_null(screen._command_drag_preview.find_child("SwitchIcon", true, false),
			"拖动阶段不得提前带入落槽后才出现的切换按钮")
	)
	assert_eq(screen.selected_action, ActionDef.Action.SWITCH)
	assert_eq(screen._turn_command_queue.size(), 1)
	assert_eq(String(screen._turn_command_queue[0]["kind"]), "action")
	var art := screen._command_order_row.get_node("Step0/Visual/Art") as Control
	var target_frame := art as HeroFrame
	assert_not_null(target_frame, "切换落槽后必须只保留目标英雄头像框")
	assert_eq(target_frame.portrait_path, expected_target_frame.portrait_path,
		"顺序槽上方头像必须对应实际选中的目标英雄")
	assert_null(art.find_child("SwitchButton", true, false),
		"补充方案要求顺序槽不再显示下方切换按钮")
	assert_null(art.find_child("SwitchIcon", true, false),
		"顺序槽只显示头像框，不得混入切换 icon")
	assert_null(art.find_child("SwitchMarker", true, false),
		"头像框右下角不得恢复小切换标记")
	assert_eq(int(art.get_meta("switch_target_slot", -1)), screen.selected_switch,
		"落槽视觉必须记录并跟随本次实际切换目标")
	assert_false(art.has_meta("command_slot_anchor_rect"),
		"切换头像必须走与其他按钮相同的通用槽位定位，不得再使用向下锚点")
	var visual_center := art.position + art.size * art.scale * 0.5
	var expected_center: Vector2 = Vector2.ONE * (screen.COMMAND_SLOT_SIZE * 0.5) \
		+ Vector2(0.0, screen.COMMAND_SLOT_ART_OFFSET_Y)
	var rendered_avatar_size := art.size * art.scale
	var available: float = screen.COMMAND_SLOT_SIZE \
		- screen.COMMAND_SLOT_ART_INSET * 2.0
	assert_almost_eq(maxf(rendered_avatar_size.x, rendered_avatar_size.y), available, 0.01,
		"切换头像也必须服从 68px 通用内容净区，不能保留旧尺寸")
	assert_almost_eq(visual_center.x, expected_center.x, 0.01,
		"切换头像与其他按钮使用同一水平槽位中心")
	assert_almost_eq(visual_center.y, expected_center.y, 0.01,
		"切换头像与其他按钮使用同一纵向槽位中心")
	var sequence: Array[Dictionary] = screen._command_sequence_for_submit()
	assert_eq(int(sequence[0]["action"]), ActionDef.Action.SWITCH)
	assert_eq(int(sequence[0]["target"]), screen.selected_switch)


func test_free_switch_queue_art_keeps_target_portrait_after_target_becomes_active() -> void:
	var screen: Control = _screen()
	var active_slot: int = screen.battle.active_index[screen.PLAYER]
	var active_source := screen.p1_frames[screen.p1_frame_slots.find(active_slot)] as HeroFrame
	var art: Control = screen._make_command_queue_art({
		kind = "free_switch",
		target = active_slot,
	})
	add_child_autofree(art)
	var target_frame := art as HeroFrame
	assert_not_null(target_frame,
		"免费切换完成预览换位后，顺序槽仍须从当前出战框解析目标头像")
	assert_eq(target_frame.portrait_path, active_source.portrait_path)
	assert_eq(int(art.get_meta("switch_target_slot", -1)), active_slot)


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
