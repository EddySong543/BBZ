extends GutTest

const BATTLE1_PATH := "res://src/ui/battle_screen1.tscn"
const BATTLE8_PATH := "res://src/ui/battle_screen8.tscn"
const TUNING_LAB_PATH := "res://src/ui/debug/buff_tuning_lab.tscn"
const NUMBER_TUNING_PATH := "res://src/ui/components/battle_status_number_tuning.tres"
const BattleStatusRowScript := preload("res://src/ui/components/battle_status_row.gd")


func _entry(effect_id: StringName, value: int) -> Dictionary:
	var entry: Dictionary = EffectCatalog.get_by_id(effect_id)
	entry["value"] = value
	return entry


func test_status_row_reflows_around_the_same_center_when_count_changes() -> void:
	var row: Control = BattleStatusRowScript.new()
	add_child_autofree(row)
	assert_eq(row.slot_size, Vector2(52.0, 42.0))
	assert_eq(row.number_tuning.count_font_size, 18)
	assert_eq(row.number_tuning.count_symbol_gap, 2.0)
	assert_true(row.number_tuning.use_per_icon_count_offsets)
	assert_eq(row.number_tuning.poison_count_offset, Vector2(7.0, 37.0))
	assert_eq(row.number_tuning.vulnerable_count_offset, Vector2(7.0, 37.0))
	assert_eq(row.number_tuning.sword_qi_count_offset, Vector2(7.0, 37.0),
			"正式组件必须读取临时场景编辑的共用数字资源")
	row.call("refresh", [_entry(&"poison", 1)])
	var one_rects: Array[Rect2] = row.call("debug_slot_rects")
	assert_eq(one_rects.size(), 1)
	assert_almost_eq(float(row.call("icon_alignment_center_x")), 17.0, 0.01,
			"单个效果以34px图标中心对齐，右侧数字不参与")
	assert_ne(float(row.call("icon_alignment_center_x")), row.size.x * 0.5,
			"数字仍保留防遮挡排版宽度，但不得再决定战斗锚点")
	assert_eq(row.call("effect_ids"), [&"poison"])

	row.call("refresh", [_entry(&"poison", 1), _entry(&"vulnerable", 2)])
	var two_rects: Array[Rect2] = row.call("debug_slot_rects")
	assert_eq(two_rects.size(), 2)
	var two_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(float(row.call("icon_alignment_center_x")),
			two_icon_rect.get_center().x, 0.01,
			"从一个增加到两个效果时只使用图标联合边界重新居中")
	assert_eq(row.call("effect_ids"), [&"poison", &"vulnerable"])
	assert_true(row.find_children("*", "ColorRect", true, false).is_empty(),
			"战斗状态整行不得残留任何底板或边框填充")
	for slot: Node in row.get_children():
		assert_false(slot.has_node("Border"),
				"战斗状态直接显示图标，不保留效果色边框")
		assert_false(slot.has_node("Plate"),
				"战斗状态直接显示图标，不保留黑色底板")
		assert_false(slot.has_node("CountPlate"),
				"层数只以描边数字叠在图标上，不保留黑色数字底板")
		assert_true(slot.has_node("Icon"))
		assert_true(slot.has_node("Count"))
	for icon: TextureRect in row.call("debug_icons"):
		assert_eq(icon.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST,
				"效果素材必须使用点采样")
		assert_true(icon.texture is AtlasTexture,
				"效果素材先裁掉不一致的透明留白，再缩入统一图标格")
		assert_eq(icon.size, Vector2(34.0, 34.0),
				"每种 buff 的裁边素材都占用相同的 34px 可见框")
		assert_eq(icon.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_CENTERED,
				"毒素、脆弱、剑气共用同一光学框，但不得被强拉成相同长宽比")

	row.call("refresh", [_entry(&"poison", 3), _entry(&"vulnerable", 1),
			_entry(&"sword_qi", 4)])
	var formal_sword_icon := row.get_node("Status_sword_qi/Icon") as TextureRect
	assert_almost_eq(formal_sword_icon.size.x, 40.8, 0.001,
			"正式战斗组件默认将纵向窄剑气等比放大20%")
	assert_almost_eq(formal_sword_icon.size.y, 40.8, 0.001)
	for slot: Control in row.get_children():
		var icon := slot.get_node("Icon") as TextureRect
		var icon_shadow := slot.get_node("IconShadow") as TextureRect
		var contour := slot.get_node_or_null("IconContour") as Control
		var count := slot.get_node("Count") as Control
		assert_not_null(icon_shadow, "每个 buff 图标都有同形像素阴影")
		assert_eq(icon_shadow.texture, icon.texture)
		assert_eq(icon_shadow.position, icon.position + row.icon_shadow_offset)
		assert_eq(icon_shadow.self_modulate, row.icon_shadow_color)
		assert_not_null(contour, "每个 buff 图标都必须有不依赖场景底色的贴形轮廓")
		assert_eq(contour.position, icon.position)
		assert_eq(contour.size, icon.size)
		assert_eq(contour.get_child_count(), 9,
				"八方向深色外沿加一层暖色迎光边，不得用矩形底板代替")
		var expected_offsets: Array[Vector2] = [
			Vector2(-1.0, -1.0), Vector2(0.0, -1.0), Vector2(1.0, -1.0),
			Vector2(-1.0, 0.0), Vector2(1.0, 0.0),
			Vector2(-1.0, 1.0), Vector2(0.0, 1.0), Vector2(1.0, 1.0),
		]
		for outline_index: int in expected_offsets.size():
			var outline := contour.get_node("Dark_%d" % outline_index) as TextureRect
			assert_not_null(outline)
			assert_eq(outline.position, expected_offsets[outline_index])
			assert_eq(outline.size, icon.size)
			assert_eq(outline.texture, icon.texture)
			assert_eq(outline.self_modulate, row.icon_contour_dark_color)
			assert_true(outline.material is ShaderMaterial,
					"轮廓必须只读取素材透明度，不能被原图颜色污染")
		var warm_rim := contour.get_node("WarmRim") as TextureRect
		assert_eq(warm_rim.position, row.icon_contour_rim_offset)
		assert_eq(warm_rim.size, icon.size)
		assert_eq(warm_rim.texture, icon.texture)
		assert_eq(warm_rim.self_modulate, row.icon_contour_rim_color)
		assert_eq(warm_rim.material, (contour.get_node("Dark_0") as TextureRect).material,
				"深色外沿与暖色迎光边共用同一轻量透明轮廓材质")
		var effect_id := StringName(slot.get_meta("effect_id"))
		assert_true(count.visible, "毒素、按回合脆弱与剑气都显示当前数值")
		var prefix := count.get_node("Prefix") as Label
		var value_label := count.get_node("Value") as Label
		var expected_values := {
			&"poison": "3", &"vulnerable": "1", &"sword_qi": "4"}
		assert_eq(prefix.text, "x", "可计数 buff 使用小写 x 前缀")
		assert_eq(value_label.text, expected_values[effect_id])
		assert_almost_eq(value_label.position.x - prefix.get_rect().end.x,
				row.number_tuning.count_symbol_gap, 0.01,
				"x 与数字使用可调像素间距")
		assert_true(prefix.get_theme_font("font") is FontVariation)
		assert_almost_eq(
				(prefix.get_theme_font("font") as FontVariation).variation_embolden,
				0.6, 0.001, "层数沿用顶部数字的加粗强度")
		assert_eq(prefix.get_theme_color("font_shadow_color"),
				Color(0.0, 0.0, 0.0, 0.32))
		assert_eq(prefix.get_theme_constant("shadow_offset_x"), 1)
		assert_eq(prefix.get_theme_constant("shadow_offset_y"), 1)
		assert_eq(prefix.get_theme_constant("shadow_outline_size"), 0)
	row.call("refresh", [_entry(&"poison", 4), _entry(&"vulnerable", 1),
			_entry(&"sword_qi", 4)])
	var poison_count := row.get_node("Status_poison/Count") as Control
	assert_true(bool(poison_count.get_meta("count_increase_motion_played", false)),
			"Buff 数值上涨时必须提供独立的轻量反馈")
	assert_lt(poison_count.scale.x, 1.0,
			"上涨数字从略小尺寸开始收稳")
	assert_almost_eq(poison_count.position.y,
			row.number_tuning.poison_count_offset.y
					+ row.number_tuning.count_increase_lift, 0.01,
			"上涨数字从下方轻抬，不推动图标或整行")
	await get_tree().create_timer(0.18).timeout
	assert_almost_eq(poison_count.scale.x, 1.0, 0.01,
			"层数反馈在 0.14 秒后稳定回到原尺寸")
	assert_almost_eq(poison_count.position.y,
			row.number_tuning.poison_count_offset.y, 0.01)
	row.call("refresh", [_entry(&"poison", 2), _entry(&"vulnerable", 1),
			_entry(&"sword_qi", 4)])
	poison_count = row.get_node("Status_poison/Count") as Control
	assert_false(bool(poison_count.get_meta("count_increase_motion_played", false)),
			"数值下降只更新结果，不播放误导性的上涨动画")
	assert_eq(poison_count.scale, Vector2.ONE)
	assert_almost_eq(poison_count.position.y,
			row.number_tuning.poison_count_offset.y, 0.01)
	row.call("refresh", [_entry(&"poison", 12)])
	poison_count = row.get_node("Status_poison/Count") as Control
	var double_digit_value := poison_count.get_node("Value") as Label
	var double_digit_visible_end := poison_count.position.x \
			+ double_digit_value.get_rect().end.x \
			+ float(row.number_tuning.count_outline_size
					+ maxi(row.number_tuning.count_shadow_offset.x, 0))
	assert_lt(double_digit_visible_end, row.slot_size.x,
			"x12 等两位数层数自动向左收，不能伸进下一固定槽")
	assert_eq(row.size, Vector2(52.0, 56.0),
			"正下方数字扩展固定行高，但层数位数不得改变 Buff 行宽高")

	var three_entries: Array[Dictionary] = [
		_entry(&"poison", 1), _entry(&"vulnerable", 2), _entry(&"sword_qi", 4)]
	row.call("refresh", three_entries)
	var three_rects: Array[Rect2] = row.call("debug_slot_rects")
	assert_eq(three_rects.size(), 3)
	var three_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(float(row.call("icon_alignment_center_x")),
			three_icon_rect.get_center().x, 0.01,
			"三个效果仍只以可见图标联合边界确定中心轴")
	row.visible = false
	row.call("refresh", three_entries)
	assert_true(row.visible,
			"换人交接中暂时隐藏后，即使新旧效果值相同也要恢复显示")


func test_only_new_buffs_play_the_pixel_stamp_enter_motion() -> void:
	var row: Control = BattleStatusRowScript.new()
	add_child_autofree(row)
	row.call("refresh", [_entry(&"poison", 1)])
	var new_poison := row.get_node("Status_poison") as Control
	assert_true(bool(new_poison.get_meta("enter_motion_played", false)))
	assert_almost_eq(row.enter_duration, 0.24, 0.001)
	assert_almost_eq(new_poison.position.x, -row.enter_travel, 0.01,
			"P1 Buff 从玩家名方向横向落入，而不是继续从下方浮入")
	assert_almost_eq(new_poison.position.y, 0.0, 0.01)
	assert_almost_eq(new_poison.scale.x, row.enter_scale, 0.01)
	assert_almost_eq(new_poison.modulate.a, 0.0, 0.01)
	assert_almost_eq(float(new_poison.get_meta("enter_stamp_scale", 0.0)),
			row.enter_stamp_scale, 0.001,
			"落印先短促压到106%，随后只收稳一次")
	var new_count := new_poison.get_node("Count") as Control
	assert_almost_eq(new_count.modulate.a, 0.0, 0.01,
			"数字必须比图标晚一拍出现")
	assert_almost_eq(new_count.scale.x, row.enter_count_scale, 0.01)
	var stamp_flash := new_poison.get_node("StampFlash") as TextureRect
	assert_eq(stamp_flash.self_modulate, row.enter_stamp_flash_color)
	assert_almost_eq(stamp_flash.modulate.a, 0.0, 0.01,
			"独立落印亮边从零开始，不会抬亮常驻轮廓")
	await get_tree().create_timer(row.enter_duration + 0.05).timeout
	new_poison = row.get_node("Status_poison") as Control
	assert_almost_eq(new_poison.position.y, 0.0, 0.01)
	assert_almost_eq(new_poison.position.x, 0.0, 0.01)
	assert_almost_eq(new_poison.scale.x, 1.0, 0.01)
	assert_almost_eq(new_poison.modulate.a, 1.0, 0.01)
	assert_almost_eq(new_count.modulate.a, 1.0, 0.01)
	assert_almost_eq(new_count.scale.x, 1.0, 0.01)
	assert_almost_eq(stamp_flash.modulate.a, 0.0, 0.01,
			"落印亮边只闪一次，不形成持续发光")
	assert_almost_eq((new_poison.get_node(
			"IconContour/WarmRim") as TextureRect).modulate.a, 1.0, 0.01,
			"闪光结束后仅保留低强度常驻暖色轮廓")

	row.call("refresh", [_entry(&"poison", 2)])
	var updated_poison := row.get_node("Status_poison") as Control
	assert_false(bool(updated_poison.get_meta("enter_motion_played", false)),
			"已有 buff 仅更新数字，不得重播整枚图标入场")
	assert_eq(updated_poison.position, Vector2.ZERO)
	assert_eq(updated_poison.scale, Vector2.ONE)
	assert_almost_eq(updated_poison.modulate.a, 1.0, 0.01)

	row.call("refresh", [_entry(&"poison", 2), _entry(&"vulnerable", 2)])
	assert_false(bool((row.get_node("Status_poison") as Control).get_meta(
			"enter_motion_played", false)))
	assert_true(bool((row.get_node("Status_vulnerable") as Control).get_meta(
			"enter_motion_played", false)),
			"新增第二个 buff 时只动画新图标")


func test_every_buff_uses_the_same_fixed_icon_slot_without_hidden_placeholders() -> void:
	var row: Control = BattleStatusRowScript.new()
	row.enter_motion_enabled = false
	add_child_autofree(row)
	assert_eq(row.slot_size, Vector2(52.0, 42.0))
	row.call("refresh", [
			_entry(&"h02_wave_upgrade", 1),
			_entry(&"h08_retained_big_defend", 1),
	])
	var h02_slot := row.get_node("Status_h02_wave_upgrade") as Control
	var h08_slot := row.get_node("Status_h08_retained_big_defend") as Control
	var h02_icon := h02_slot.get_node("Icon") as TextureRect
	var h08_icon := h08_slot.get_node("Icon") as TextureRect
	var contour_width := float(row.icon_contour_width) if row.icon_contour_enabled else 0.0
	var h02_visual_end := h02_slot.position.x + h02_icon.get_rect().end.x + contour_width
	var h08_visual_start := h08_slot.position.x + h08_icon.get_rect().position.x \
			- contour_width
	assert_almost_eq(h08_visual_start - h02_visual_end, 16.0, 0.01,
			"固定 52px 槽位令两枚标准图标轮廓之间保持 16px")
	var team_pitch := h08_icon.get_global_rect().get_center().x \
			- h02_icon.get_global_rect().get_center().x
	assert_almost_eq(team_pitch, 52.0, 0.01,
			"有无数字都只能影响槽内装饰，不得改变图标中心距")
	var h02_bounds: Rect2 = row.call("_visible_layout_bounds", _entry(&"h02_wave_upgrade", 1))
	var h08_bounds: Rect2 = row.call("_visible_layout_bounds", _entry(&"h08_retained_big_defend", 1))
	assert_almost_eq(h08_slot.position.x + h08_bounds.position.x \
			- (h02_slot.position.x + h02_bounds.end.x), 15.0, 0.01)
	for effect_id: StringName in [&"h02_wave_upgrade", &"h08_retained_big_defend"]:
		var hidden_count := row.get_node("Status_%s/Count" % effect_id) as Control
		assert_false(hidden_count.visible)
		assert_eq(String(hidden_count.get_meta("formatted_text")), "x1")

	var mixed_row: Control = BattleStatusRowScript.new()
	mixed_row.enter_motion_enabled = false
	add_child_autofree(mixed_row)
	var poison_entry := _entry(&"poison", 2)
	var h02_entry := _entry(&"h02_wave_upgrade", 1)
	mixed_row.call("refresh", [poison_entry, h02_entry])
	var poison_slot := mixed_row.get_node("Status_poison") as Control
	var next_slot := mixed_row.get_node("Status_h02_wave_upgrade") as Control
	var poison_bounds: Rect2 = mixed_row.call("_visible_layout_bounds", poison_entry)
	var next_bounds: Rect2 = mixed_row.call("_visible_layout_bounds", h02_entry)
	var poison_icon := poison_slot.get_node("Icon") as TextureRect
	var next_icon := next_slot.get_node("Icon") as TextureRect
	assert_almost_eq(next_icon.get_global_rect().get_center().x \
			- poison_icon.get_global_rect().get_center().x, 52.0, 0.01,
			"带数字与无数字 Buff 仍使用同一图标中心距")
	var poison_count := poison_slot.get_node("Count") as Control
	var poison_value := poison_count.get_node("Value") as Label
	var count_visible_end := poison_count.position.x + poison_value.get_rect().end.x \
			+ float(row.number_tuning.count_outline_size
					+ maxi(row.number_tuning.count_shadow_offset.x, 0))
	assert_lt(count_visible_end, row.slot_size.x,
			"xN 锁在本图标正下方，不得伸进下一图标槽")
	assert_lt(poison_count.position.x, poison_icon.get_rect().end.x,
			"计数必须留在所属图标的横向投影内，不能成为横向独立文字单元")
	assert_eq(mixed_row.size.x, 104.0,
			"两个 Buff 的排版宽度只由两个固定槽决定")

	var mirrored_row: Control = BattleStatusRowScript.new()
	mirrored_row.enter_motion_enabled = false
	mirrored_row.right_to_left = true
	add_child_autofree(mirrored_row)
	mirrored_row.call("refresh", [
			_entry(&"h02_wave_upgrade", 1),
			_entry(&"h08_retained_big_defend", 1),
	])
	var mirrored_h02 := mirrored_row.get_node("Status_h02_wave_upgrade") as Control
	var mirrored_h08 := mirrored_row.get_node("Status_h08_retained_big_defend") as Control
	var mirrored_h02_bounds: Rect2 = mirrored_row.call(
			"_visible_layout_bounds", _entry(&"h02_wave_upgrade", 1))
	var mirrored_h08_bounds: Rect2 = mirrored_row.call(
			"_visible_layout_bounds", _entry(&"h08_retained_big_defend", 1))
	assert_almost_eq(mirrored_h02.position.x + mirrored_h02_bounds.position.x \
			- (mirrored_h08.position.x + mirrored_h08_bounds.end.x), 15.0, 0.01,
			"P2 镜像展开也保持完全相同的固定槽节奏")


func test_single_row_fixed_slots_fit_current_five_and_one_future_buff() -> void:
	var row: Control = BattleStatusRowScript.new()
	row.enter_motion_enabled = false
	add_child_autofree(row)
	var entries: Array[Dictionary] = [
		_entry(&"poison", 1), _entry(&"vulnerable", 1),
		_entry(&"sword_qi", 1), _entry(&"h02_wave_upgrade", 1),
		_entry(&"h08_retained_big_defend", 1),
	]
	row.call("refresh", entries)
	assert_eq(row.size, Vector2(260.0, 56.0),
			"当前五种 Buff 固定为五个 52px 槽；正下方数字只扩展统一行高")
	var five_icons: Array[TextureRect] = row.call("debug_icons")
	for index: int in range(1, five_icons.size()):
		assert_almost_eq(five_icons[index].get_global_rect().get_center().x \
				- five_icons[index - 1].get_global_rect().get_center().x,
				52.0, 0.01, "五种 Buff 无论有无数字都保持同一图标中心距")
	for slot: Control in row.get_children():
		assert_almost_eq(slot.position.y, 0.0, 0.01,
				"换行方案未确认前，所有 Buff 必须严格停留在单行，避免撞入道具栏")
	var sixth: Dictionary = _entry(&"h02_wave_upgrade", 1)
	sixth["id"] = &"future_sixth_buff"
	sixth["instance_key"] = &"future_sixth_buff"
	entries.append(sixth)
	row.call("refresh", entries)
	assert_eq(row.size, Vector2(312.0, 56.0),
			"不换行状态下仍为第六种 Buff 预留一个完整槽位")
	assert_lte((row.call("debug_icon_alignment_rect") as Rect2).size.x, 338.0,
			"六枚 Buff 的图标联合边界仍位于当前 HUD 安全宽度内")


func test_pixel_stamp_staggers_multiple_new_buffs_and_mirrors_from_player_name() -> void:
	var entries: Array[Dictionary] = [
		_entry(&"poison", 1), _entry(&"vulnerable", 2), _entry(&"sword_qi", 3)]
	var p1_row: Control = BattleStatusRowScript.new()
	add_child_autofree(p1_row)
	p1_row.call("refresh", entries)
	for index: int in entries.size():
		var effect_id := StringName(entries[index].id)
		var slot := p1_row.get_node("Status_%s" % effect_id) as Control
		assert_almost_eq(float(slot.get_meta("enter_motion_delay", -1.0)),
				p1_row.enter_stagger * index, 0.001,
				"换人或同时出现多个 Buff 时按获得顺序错峰落印")
		assert_eq(int(slot.get_meta("enter_motion_direction", 0)), -1)

	var p2_row: Control = BattleStatusRowScript.new()
	p2_row.right_to_left = true
	add_child_autofree(p2_row)
	p2_row.call("refresh", entries)
	for index: int in entries.size():
		var effect_id := StringName(entries[index].id)
		var slot := p2_row.get_node("Status_%s" % effect_id) as Control
		var resting_x: float = p2_row.debug_slot_rects()[index].position.x
		assert_almost_eq(slot.position.x, resting_x + p2_row.enter_travel, 0.01,
				"P2 从右侧玩家名方向向左落入，与 P1 完整镜像")
		assert_eq(int(slot.get_meta("enter_motion_direction", 0)), 1)


func test_new_statuses_append_after_existing_acquisition_order() -> void:
	var row: Control = BattleStatusRowScript.new()
	add_child_autofree(row)
	row.call("set_owner_key", &"p1:h10")
	row.call("refresh", [_entry(&"sword_qi", 2), _entry(&"poison", 1)])
	assert_eq(row.call("effect_ids"), [&"sword_qi", &"poison"])
	# EffectCatalog 会按 poison/vulnerable/sword_qi 返回；组件必须保留已显示顺序，
	# 并把本次新获得的脆弱追加到末尾，不能插进中间。
	row.call("refresh", [
			_entry(&"poison", 1), _entry(&"vulnerable", 2),
			_entry(&"sword_qi", 2)])
	assert_eq(row.call("effect_ids"), [&"sword_qi", &"poison", &"vulnerable"])
	assert_true(bool((row.get_node("Status_vulnerable") as Control).get_meta(
			"enter_motion_played", false)))
	assert_false(bool((row.get_node("Status_sword_qi") as Control).get_meta(
			"enter_motion_played", false)))


func test_right_side_layout_mirrors_every_icon_order_around_the_same_anchor() -> void:
	var permutations: Array[Array] = [
		[&"sword_qi"], [&"poison"], [&"vulnerable"],
		[&"sword_qi", &"poison"], [&"sword_qi", &"vulnerable"],
		[&"poison", &"sword_qi"], [&"poison", &"vulnerable"],
		[&"vulnerable", &"sword_qi"], [&"vulnerable", &"poison"],
		[&"sword_qi", &"poison", &"vulnerable"],
		[&"sword_qi", &"vulnerable", &"poison"],
		[&"poison", &"sword_qi", &"vulnerable"],
		[&"poison", &"vulnerable", &"sword_qi"],
		[&"vulnerable", &"sword_qi", &"poison"],
		[&"vulnerable", &"poison", &"sword_qi"],
	]
	for permutation: Array in permutations:
		var row: Control = BattleStatusRowScript.new()
		row.right_to_left = true
		row.enter_motion_enabled = false
		add_child_autofree(row)
		var entries: Array[Dictionary] = []
		for effect_id: StringName in permutation:
			entries.append(_entry(effect_id, 2))
		row.call("refresh", entries)
		assert_eq(row.call("effect_ids"), permutation,
				"镜像排版不得反转状态的获得顺序")
		var union_rect: Rect2 = row.call("debug_icon_alignment_rect")
		row.position = Vector2(-union_rect.end.x, -union_rect.get_center().y).round()
		assert_almost_eq(row.position.x + union_rect.end.x, 0.0, 0.51,
				"右侧任意状态组合都以可见图标右缘贴齐锚点")
		var first_slot := row.get_node("Status_%s" % String(permutation[0])) as Control
		var first_icon := first_slot.get_node("Icon") as TextureRect
		var first_icon_end: float = first_slot.position.x \
				+ first_icon.get_rect().end.x + float(row.icon_contour_width)
		assert_almost_eq(first_icon_end, union_rect.end.x, 0.01,
				"右侧第一个获得的状态必须始终最靠近玩家名")
		for effect_id: StringName in permutation:
			var slot := row.get_node("Status_%s" % String(effect_id)) as Control
			var icon := slot.get_node("Icon") as TextureRect
			var count := slot.get_node("Count") as Control
			var resolved_offset: Vector2 = row.call("_count_offset_for", effect_id)
			assert_almost_eq(count.position.x,
					resolved_offset.x, 0.01,
					"P2 只镜像整组展开方向，单个 Buff 的正下方数字坐标不变")
			assert_almost_eq(count.get_rect().get_center().x,
					icon.get_rect().get_center().x, 3.0,
					"数字整体在图标下方光学居中，不再形成 x1毒素的横向错序")


func test_buff_tuning_lab_uses_the_real_component_and_live_tuning_geometry() -> void:
	var packed := load(TUNING_LAB_PATH) as PackedScene
	assert_not_null(packed, "临时 Buff 调整场景必须可直接打开或 F6 运行")
	var lab := packed.instantiate() as Control
	add_child_autofree(lab)
	await get_tree().process_frame
	var preview := lab.get_node("BuffPreview") as BattleStatusRow
	assert_true(preview.preview_enabled)
	assert_eq(preview.number_tuning.resource_path, NUMBER_TUNING_PATH,
			"临时场景必须直接编辑正式战斗使用的 Buff 数字资源")
	assert_eq(preview.slot_size, Vector2(52.0, 42.0))
	assert_eq(preview.number_tuning.count_font_size, 18)
	assert_eq(preview.number_tuning.poison_count_offset, Vector2(7.0, 37.0))
	assert_eq(preview.number_tuning.vulnerable_count_offset, Vector2(7.0, 37.0))
	assert_eq(preview.number_tuning.sword_qi_count_offset, Vector2(7.0, 37.0),
			"共用资源保留用户在 Inspector 中保存的独立数字偏移")
	assert_eq(preview.number_tuning.count_symbol_gap, 2.0)
	assert_eq(preview.number_tuning.count_shadow_color,
			Color(0.0, 0.0, 0.0, 0.32))
	assert_eq(preview.effect_ids(), [&"poison", &"vulnerable", &"sword_qi"],
			"调试场景直接预览正式毒素、脆弱、剑气组件")
	assert_almost_eq(preview.position.x + float(preview.call(
			"icon_alignment_center_x")), lab.preview_center.x, 0.51,
			"临时场景与正式战斗都忽略数字，只用图标联合边界居中")
	preview.icon_box_size = Vector2(42.0, 38.0)
	preview.number_tuning = preview.number_tuning.duplicate(true)
	preview.number_tuning.count_offset = Vector2(5.0, 12.0)
	preview.number_tuning.use_per_icon_count_offsets = true
	preview.number_tuning.poison_count_offset = Vector2(2.0, 14.0)
	preview.number_tuning.vulnerable_count_offset = Vector2(1.0, 13.0)
	preview.number_tuning.sword_qi_count_offset = Vector2(-4.0, 11.0)
	preview.number_tuning.count_font_size = 17
	preview.number_tuning.count_symbol_gap = 6.0
	preview.sword_qi_icon_scale = 1.25
	await get_tree().process_frame
	var poison_icon := preview.get_node("Status_poison/Icon") as TextureRect
	assert_eq(poison_icon.size, Vector2(42.0, 38.0),
			"Inspector 调整图标框后真实组件立即重建")
	var sword_icon := preview.get_node("Status_sword_qi/Icon") as TextureRect
	assert_eq(sword_icon.size, Vector2(52.5, 47.5),
			"纵向剑气可用独立等比滑杆补偿较小的可见面积")
	var poison_count := preview.get_node("Status_poison/Count") as Control
	assert_eq(poison_count.position, Vector2(2.0, 14.0))
	var poison_prefix := poison_count.get_node("Prefix") as Label
	var poison_value := poison_count.get_node("Value") as Label
	assert_eq(poison_prefix.get_theme_font_size("font_size"), 17)
	assert_eq(poison_prefix.text, "x")
	assert_eq(poison_value.text, "3")
	assert_almost_eq(poison_value.position.x - poison_prefix.get_rect().end.x,
			6.0, 0.01)
	var vulnerable_count := preview.get_node("Status_vulnerable/Count") as Control
	assert_eq(vulnerable_count.position, Vector2(1.0, 13.0))
	assert_eq((vulnerable_count.get_node("Value") as Label).text, "2",
			"脆弱预览显示当前剩余回合数")
	var sword_count := preview.get_node("Status_sword_qi/Count") as Control
	assert_eq(sword_count.position, Vector2(-4.0, 11.0),
			"纵向剑气拥有独立光学修正，不需要旋转素材来迁就数字")
	var sword_font := (sword_count.get_node("Value") as Label).get_theme_font(
			"font") as FontVariation
	assert_not_null(sword_font)
	assert_eq(sword_font.base_font.resource_path,
			"res://assets/font/zlabs_pixel_ui.tres",
			"编辑器预览直接加载正式字体资源，不再依赖运行时 Autoload")


func test_battle_screen8_runtime_counts_share_the_lab_tuning_source() -> void:
	BattleSetup.reset()
	var lab := (load(TUNING_LAB_PATH) as PackedScene).instantiate() as Control
	add_child_autofree(lab)
	var screen := (load(BATTLE8_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var preview := lab.get_node("BuffPreview") as BattleStatusRow
	for player: int in 2:
		var slot: int = screen.battle.active_index[player]
		screen.battle.set_status(player, slot, "poison", 3)
		screen.battle.set_status(player, slot, "vuln", 2)
		screen.battle.set_team_status(player, "jianqi", 4)
	screen._refresh_battle_status_rows()
	await get_tree().process_frame
	for player: int in 2:
		var runtime_row := screen._battle_status_rows[player] as BattleStatusRow
		assert_eq(runtime_row.number_tuning.resource_path, NUMBER_TUNING_PATH,
				"battle_screen8 双方运行时不得退回脚本默认值或另一份手抄坐标")
		assert_eq(runtime_row.number_tuning, preview.number_tuning,
				"调校场景与真实 F6 场景双方必须持有同一个只读 Resource 实例")
		for effect_id: StringName in [&"poison", &"vulnerable", &"sword_qi"]:
			var preview_count := preview.get_node(
					"Status_%s/Count" % effect_id) as Control
			var runtime_count := runtime_row.get_node(
					"Status_%s/Count" % effect_id) as Control
			assert_eq(runtime_count.position, preview_count.position,
					"P%d %s 的战斗数字位置必须直接复用 lab 参数" % [
						player + 1, effect_id])
			assert_eq(runtime_count.size, preview_count.size,
					"P%d %s 的战斗数字尺寸必须直接复用 lab 参数" % [
						player + 1, effect_id])
			for glyph_name: String in ["Prefix", "Value"]:
				var preview_glyph := preview_count.get_node(glyph_name) as Label
				var runtime_glyph := runtime_count.get_node(glyph_name) as Label
				assert_eq(runtime_glyph.position, preview_glyph.position)
				assert_eq(runtime_glyph.size, preview_glyph.size)
				assert_eq(runtime_glyph.get_theme_font_size("font_size"),
						preview_glyph.get_theme_font_size("font_size"))
				assert_eq(runtime_glyph.get_theme_color("font_color"),
						preview_glyph.get_theme_color("font_color"))
				assert_eq(runtime_glyph.get_theme_constant("outline_size"),
						preview_glyph.get_theme_constant("outline_size"))
	BattleSetup.reset()


func test_core_status_keys_map_to_catalog_ids_in_a_stable_order() -> void:
	var entries: Array[Dictionary] = EffectCatalog.battle_status_entries({
		"poison": 1,
		"vuln": 2,
		"silenced": 9,
	}, {
		"jianqi": 4,
		"upgrade_next_wave": true,
		"retained_big_defend": true,
	}, 2)
	assert_eq(entries.map(func(entry: Dictionary) -> StringName:
		return StringName(entry.id)), [
			&"poison", &"vulnerable", &"sword_qi", &"h02_wave_upgrade",
			&"h08_retained_big_defend"])
	assert_eq(entries.map(func(entry: Dictionary) -> int:
		return int(entry.value)), [1, 2, 4, 1, 1])
	assert_eq(entries.map(func(entry: Dictionary) -> bool:
		return bool(entry.get("show_stack_count", false))),
			[true, true, true, false, false],
			"h02、h08 是无计数队伍 Buff；其余状态继续显示数值")
	assert_eq(String(entries[0].instance_key), "hero:2:poison")
	assert_eq(String(entries[2].instance_key), "team:jianqi")
	assert_eq(String(entries[0].scope), "hero")
	assert_eq(String(entries[2].scope), "team")
	assert_true(EffectCatalog.battle_status_entries({
		"poison": 0, "vuln": -1}, {"jianqi": 0}).is_empty(),
			"零值、负值和无关状态不生成战斗状态图标")


func test_battle_status_rows_anchor_after_player_names_and_hide_on_death() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	assert_eq(screen._battle_status_rows.size(), 2,
			"双方出战英雄各有一个独立的 HUD 效果队列")
	var p1_anchor := screen.get_node("P1Hud/P1StatusAnchor") as Control
	var p2_anchor := screen.get_node("P2Hud/P2StatusAnchor") as Control
	assert_not_null(p1_anchor, "P1 状态锚点必须能在共享战斗场景中可视化调整")
	assert_not_null(p2_anchor, "P2 状态锚点必须能在共享战斗场景中可视化调整")
	assert_eq(p1_anchor.position, Vector2(28.0, 171.0),
			"P1 Buff 接管旧道具横排区域，图标左缘从 x=28 开始")
	assert_almost_eq(p2_anchor.position.x, screen.SCREEN_W - p1_anchor.position.x,
			0.1, "P2 状态锚点必须镜像 P1")
	assert_almost_eq(p2_anchor.position.y, p1_anchor.position.y,
			0.1, "双方 Buff 共用旧道具区域的垂直中心线")

	var player: int = screen.PLAYER
	var slot: int = screen.battle.active_index[player]
	screen.battle.set_status(player, slot, "poison", 1)
	screen._update_all()
	await get_tree().process_frame
	var row: Control = screen._battle_status_rows[player]
	assert_true(row.visible)
	assert_eq(row.get_parent(), p1_anchor)
	assert_eq(row.call("effect_ids"), [&"poison"])
	var one_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(row.position.x + one_icon_rect.position.x, 0.0, 0.51,
			"P1 从锚点向右展开，左边界只取图标而不取数字")
	assert_almost_eq(row.position.y + one_icon_rect.get_center().y, 0.0, 0.51,
			"状态图标中心锁定在旧道具区域锚点")
	assert_false(row.right_to_left)
	var initial_position := row.global_position
	screen.p1_char_display.offset_transform_position = Vector2(18.0, 6.0)
	screen._position_battle_status_rows()
	assert_eq(row.global_position, initial_position,
			"角色攻击或换人演出不得再拖动固定 HUD 状态栏")
	screen.p1_char_display.offset_transform_position = Vector2.ZERO

	screen.battle.set_status(player, slot, "vuln", 2)
	screen._update_all()
	await get_tree().process_frame
	assert_eq(row.call("effect_ids"), [&"poison", &"vulnerable"])
	var vulnerable_count := row.get_node("Status_vulnerable/Count") as Control
	assert_true(vulnerable_count.visible)
	assert_eq((vulnerable_count.get_node("Value") as Label).text, "2",
			"正式战斗中的脆弱显示当前回合数")
	var two_icon_rect: Rect2 = row.call("debug_icon_alignment_rect")
	assert_almost_eq(row.position.x + two_icon_rect.position.x, 0.0, 0.51,
			"新增第二个效果后仍忽略数字宽度，从玩家名后固定起点展开")

	var enemy: int = screen.AI
	var enemy_slot: int = screen.battle.active_index[enemy]
	screen.battle.set_team_status(enemy, "jianqi", 4)
	screen.battle.upgrade_next_wave[enemy] = true
	screen.battle.retained_big_defend[enemy] = true
	screen.battle.retained_big_defend_until_turn[enemy] = screen.battle.turn_number
	screen._update_all()
	await get_tree().process_frame
	var enemy_row: Control = screen._battle_status_rows[enemy]
	assert_eq(enemy_row.call("effect_ids"), [
			&"sword_qi", &"h02_wave_upgrade", &"h08_retained_big_defend"])
	assert_eq(enemy_row.get_parent(), p2_anchor)
	assert_true(enemy_row.right_to_left,
			"P2 状态组件必须使用真正的镜像排版，不得只把整行右对齐")
	var enemy_icon_rect: Rect2 = enemy_row.call("debug_icon_alignment_rect")
	assert_almost_eq(enemy_row.position.x + enemy_icon_rect.end.x, 0.0, 0.51,
			"P2 从镜像锚点向左展开，右边界只取图标而不取数字")
	assert_almost_eq(enemy_row.position.y + enemy_icon_rect.get_center().y,
			0.0, 0.51, "P2 状态图标同样与玩家名中心对齐")

	screen.battle.hp[player][slot] = 0
	screen._update_all()
	assert_false(row.visible, "出战英雄死亡时隐藏对应 HUD 状态图标")
	BattleSetup.reset()


func test_owner_switch_replays_status_motion_even_when_values_match() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var player: int = screen.PLAYER
	var old_slot: int = screen.battle.active_index[player]
	var reserve_slot: int = 0 if old_slot != 0 else 1
	screen.battle.set_status(player, old_slot, "poison", 1)
	screen.battle.set_status(player, reserve_slot, "poison", 1)
	screen.battle.set_team_status(player, "jianqi", 2)
	screen._refresh_battle_status_rows()
	var row: Control = screen._battle_status_rows[player]
	await get_tree().create_timer(row.enter_duration + 0.04).timeout
	screen.battle.active_index[player] = reserve_slot
	screen._refresh_battle_status_rows()
	var switched_poison := row.get_node("Status_poison") as Control
	var shared_sword_qi := row.get_node("Status_sword_qi") as Control
	assert_true(bool(switched_poison.get_meta("enter_motion_played", false)),
			"行动切换时即使新旧英雄拥有同值 Buff，也必须重播状态入场")
	assert_almost_eq(switched_poison.modulate.a, 0.0, 0.01)
	assert_almost_eq(switched_poison.position.x,
			row.debug_slot_rects()[0].position.x - row.enter_travel, 0.01)
	assert_almost_eq(switched_poison.position.y,
			row.debug_slot_rects()[0].position.y, 0.01)
	assert_false(bool(shared_sword_qi.get_meta("enter_motion_played", false)),
			"切换只重播新英雄自己的状态；队伍剑气不得消失或重新入场")
	BattleSetup.reset()


func test_team_buffs_survive_death_and_switch_without_reentering() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var player: int = screen.PLAYER
	var old_slot: int = screen.battle.active_index[player]
	var reserve_slot: int = 0 if old_slot != 0 else 1
	screen.battle.set_status(player, old_slot, "poison", 1)
	screen.battle.set_team_status(player, "jianqi", 2)
	screen.battle.upgrade_next_wave[player] = true
	screen.battle.retained_big_defend[player] = true
	screen.battle.retained_big_defend_until_turn[player] = screen.battle.turn_number
	screen._refresh_battle_status_rows()
	var row: Control = screen._battle_status_rows[player]
	await get_tree().create_timer(row.enter_duration + 0.04).timeout

	screen.battle.hp[player][old_slot] = 0
	screen._refresh_battle_status_rows()
	assert_eq(row.call("effect_ids"), [
			&"sword_qi", &"h02_wave_upgrade", &"h08_retained_big_defend"],
			"死亡待换阶段只撤下英雄槽毒素，三种队伍 Buff 必须持续显示")
	for effect_id: StringName in row.call("effect_ids"):
		assert_false(bool((row.get_node("Status_%s" % effect_id) as Control).get_meta(
				"enter_motion_played", false)), "持续状态不得因英雄死亡重新落印")

	screen.battle.active_index[player] = reserve_slot
	screen._refresh_battle_status_rows()
	assert_eq(row.call("effect_ids"), [
			&"sword_qi", &"h02_wave_upgrade", &"h08_retained_big_defend"],
			"剑气、玄金不动相与不坠神言都不绑定具体英雄，切换后继续存在")
	BattleSetup.reset()


func test_status_icon_hover_uses_skill_description_tip_layout() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var player: int = screen.PLAYER
	var slot_index: int = screen.battle.active_index[player]
	screen.battle.set_status(player, slot_index, "poison", 3)
	screen._update_all()
	await get_tree().process_frame
	var row: Control = screen._battle_status_rows[player]
	var poison_slot := row.get_node("Status_poison") as Control
	assert_eq(poison_slot.mouse_filter, Control.MOUSE_FILTER_STOP,
			"Buff 图标必须接收悬停输入")
	screen._on_hero_skill_tip(player, 0)
	await get_tree().process_frame
	var skill_tip_size: Vector2 = screen._tip_panel.size
	var skill_icon_rect: Rect2 = screen._tip_skill_icon.get_rect()
	var skill_text_rect: Rect2 = screen._tip_rich.get_rect()
	poison_slot.mouse_entered.emit()
	await get_tree().process_frame
	assert_true(screen._tip_panel.visible)
	assert_lt(screen._tip_panel.size.distance_to(screen.tip_size_l), 0.01)
	assert_lt(screen._tip_panel.size.distance_to(skill_tip_size), 0.01,
			"Buff 说明框必须与技能说明框使用完全相同的尺寸")
	assert_eq(screen._tip_skill_icon.get_rect(), skill_icon_rect,
			"Buff 图标必须沿用技能说明框的垂直中心，不得被标题下推")
	var buff_text_rect: Rect2 = screen._tip_rich.get_rect()
	assert_eq(buff_text_rect.position.x, skill_text_rect.position.x,
			"Buff 正文与技能说明使用同一横向版心")
	assert_eq(buff_text_rect.size.x, skill_text_rect.size.x)
	assert_almost_eq(buff_text_rect.get_center().y, skill_text_rect.get_center().y, 0.51,
			"正文只允许为消除半像素取整收窄 1px，不得被标题整体下推")
	var body_ink_top: float = screen._tip_rich.position.y \
			+ (screen._tip_rich.size.y - screen._tip_rich.get_content_height()) * 0.5
	assert_almost_eq(body_ink_top, roundf(body_ink_top), 0.01,
			"Buff 正文字形必须落在整数像素基线上")
	assert_false(screen._tip_item_header.visible,
			"Buff 说明不得再生成道具图标+标题头")
	assert_false(screen._tip_item_rule.visible,
			"Buff 说明不得再生成道具分割线")
	assert_true(screen._tip_skill_icon.visible,
			"Buff 说明下半部分与头像技能一致，左侧显示对应图标")
	assert_eq(screen._tip_rich.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	assert_eq(screen._tip_keyword_alignment, HORIZONTAL_ALIGNMENT_LEFT,
			"Buff 说明正文与头像技能一样位于图标右侧并左对齐")
	assert_true(screen._tip_buff_title.visible)
	assert_eq(screen._tip_buff_title.size.y, 31.0,
			"奇数标题轨道消除 17px 字形的半像素居中偏差")
	assert_eq(screen._tip_buff_name.text.replace("\u2060", ""), "毒素")
	assert_eq(screen._tip_buff_count.text, "x3")
	assert_true(screen._tip_buff_count.visible)
	assert_almost_eq(screen._tip_buff_title.get_rect().get_center().x,
			screen._tip_content.size.x * 0.5, 0.51,
			"Buff 名、星号角标与计数作为整体在顶部正中")
	var visible_tip_text: String = screen._tip_rich.get_parsed_text().replace("\u2060", "")
	assert_true(visible_tip_text.contains("每层造成"),
			"悬停说明直接复用效果目录的正式解释")
	assert_false(visible_tip_text.contains("毒素 x3"),
			"Buff 名与计数必须只在独立顶部标题轨道出现")
	poison_slot.mouse_exited.emit()
	assert_false(screen._tip_panel.visible)
	BattleSetup.reset()


func test_team_buff_tooltips_use_skill_icons_and_hide_count_when_not_applicable() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var player: int = screen.PLAYER
	screen.battle.upgrade_next_wave[player] = true
	screen.battle.retained_big_defend[player] = true
	screen.battle.retained_big_defend_until_turn[player] = screen.battle.turn_number
	screen._update_all()
	await get_tree().process_frame
	var row: Control = screen._battle_status_rows[player]
	assert_eq(row.call("effect_ids"), [&"h02_wave_upgrade", &"h08_retained_big_defend"])
	var h02_slot := row.get_node("Status_h02_wave_upgrade") as Control
	assert_false((h02_slot.get_node("Count") as Control).visible)
	h02_slot.mouse_entered.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(screen._tip_buff_name.text.replace("\u2060", ""), "玄金不动相")
	assert_false(screen._tip_buff_count.visible)
	assert_true(screen._tip_skill_icon.visible)
	assert_eq(screen._tip_skill_icon.texture.resource_path,
			"res://assets/sprites/heroes/h02/h02_skill.png")
	var h02_text: String = screen._tip_rich.get_parsed_text().replace("\u2060", "")
	assert_eq(h02_text, "我方下一次的波升级为大波。")
	var h02_text_rect: Rect2 = screen._tip_rich.get_rect()
	var h02_title_rect: Rect2 = screen._tip_buff_title.get_rect()
	var h08_slot := row.get_node("Status_h08_retained_big_defend") as Control
	h08_slot.mouse_entered.emit()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(screen._tip_buff_name.text.replace("\u2060", ""), "不坠神言")
	assert_false(screen._tip_buff_count.visible)
	assert_eq(screen._tip_skill_icon.texture.resource_path,
			"res://assets/sprites/heroes/h08/h08_skill.png")
	assert_eq(screen._tip_rich.get_parsed_text().replace("\u2060", ""),
			"大防直到下回合结束。")
	var h08_text_rect: Rect2 = screen._tip_rich.get_rect()
	assert_lt(h08_text_rect.position.distance_to(h02_text_rect.position), 0.01)
	assert_lt(h08_text_rect.size.distance_to(h02_text_rect.size), 0.01,
			"同为单行的 h02/h08 Buff 正文使用完全相同的像素轨道")
	assert_eq(screen._tip_buff_title.get_rect().position.y, h02_title_rect.position.y)
	assert_eq(screen._tip_buff_title.get_rect().size.y, h02_title_rect.size.y,
			"Buff 名称无论字数多少都不得改变标题垂直位置")
	BattleSetup.reset()


func test_every_buff_tooltip_uses_one_pixel_aligned_vertical_system() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var expected_panel_size: Vector2 = screen.tip_size_l
	var expected_icon_rect := Rect2()
	for effect_id: StringName in [
			&"poison", &"vulnerable", &"sword_qi",
			&"h02_wave_upgrade", &"h08_retained_big_defend"]:
		screen._on_battle_status_hovered(effect_id, 2, Rect2(600.0, 500.0, 34.0, 34.0))
		await get_tree().process_frame
		await get_tree().process_frame
		assert_lt(screen._tip_panel.size.distance_to(expected_panel_size), 0.01,
				"所有 Buff 共用技能 L 框尺寸")
		var icon_rect: Rect2 = screen._tip_skill_icon.get_rect()
		if expected_icon_rect.size == Vector2.ZERO:
			expected_icon_rect = icon_rect
		else:
			assert_lt(icon_rect.position.distance_to(expected_icon_rect.position), 0.01)
			assert_lt(icon_rect.size.distance_to(expected_icon_rect.size), 0.01,
					"所有 Buff 图标共用同一垂直中心")
		var title_rect: Rect2 = screen._tip_buff_title.get_rect()
		assert_almost_eq(title_rect.position.y, 3.0, 0.01,
				"连续查看任意 Buff 时，名称、星芒与计数固定在同一条 Y=3px 基线")
		assert_almost_eq(title_rect.size.y, 31.0, 0.01,
				"名称字数和有无计数都不能改变标题轨道")
		assert_almost_eq(title_rect.get_center().x,
				screen._tip_content.size.x * 0.5, 0.51)
		var ink_top: float = screen._tip_rich.position.y \
				+ (screen._tip_rich.size.y - screen._tip_rich.get_content_height()) * 0.5
		assert_almost_eq(ink_top, roundf(ink_top), 0.01,
				"不同正文行数都必须落在整数像素基线")
		assert_almost_eq(screen._tip_rich.get_rect().get_center().y,
				screen._tip_content.size.y * 0.5, 0.51,
				"奇偶行正文只做像素取整，不得产生可见上下漂移")
	BattleSetup.reset()


func test_resolution_switch_handoff_defers_final_status_until_action_finishes() -> void:
	BattleSetup.reset()
	var screen := (load(BATTLE1_PATH) as PackedScene).instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	var enemy: int = screen.AI
	var old_slot: int = screen.battle.active_index[enemy]
	var new_slot: int = 0 if old_slot != 0 else 1
	var row: Control = screen._battle_status_rows[enemy]
	screen.battle.set_team_status(enemy, "jianqi", 2)
	screen._refresh_battle_status_rows()
	await get_tree().create_timer(row.enter_duration + 0.04).timeout
	screen.battle.active_index[enemy] = new_slot
	screen.battle.set_status(enemy, new_slot, "poison", 1)
	var switched_players: Array[int] = [enemy]
	await screen._play_switch_handoff(switched_players, false)
	assert_true(row.visible,
			"结算动作中的换人必须继续显示不依附英雄槽的队伍剑气")
	assert_false(row.has_node("Status_poison"),
			"h06 命中表现完成前不得构建毒素图标")
	assert_true(row.has_node("Status_sword_qi"),
			"剑气与施加在新英雄身上的毒素分属两种生命周期")
	screen._refresh_battle_status_rows()
	assert_true(row.visible)
	assert_true(row.has_node("Status_poison"),
			"攻击动画结束后的统一刷新才显示新获得的 Buff")
	assert_false(bool((row.get_node("Status_sword_qi") as Control).get_meta(
			"enter_motion_played", false)), "持续剑气不应随换人重新播放进场")
	BattleSetup.reset()
