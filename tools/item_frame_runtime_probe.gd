extends Node

## 无截图运行时验收：
## 1. 手调 262px 模板与四种正式 profile 的几何逐项等比例；
## 2. 临时场景、图鉴正式角标确实产生最终像素；
## 3. 图鉴左右页数字与调参台真实字形像素一致；
## 4. battle_screen8 空队列/已有攒动作/行动执行阶段的整按钮像素一致；
## 5. 战斗道具锁定态使用单一父组、中央封条和红色 x-1 最终像素。

const LAB := preload("res://src/ui/debug/item_frame_tuning_lab.tscn")
const GALLERY := preload("res://src/ui/item_gallery_screen.tscn")
const BATTLE8 := preload("res://src/ui/battle_screen8.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var metrics := {}
	var root_window := get_tree().root
	root_window.transparent_bg = false

	var lab := LAB.instantiate() as Control
	root_window.add_child(lab)
	await get_tree().process_frame
	await get_tree().process_frame
	var template := lab.get_node("ItemFrameTemplate") as Control
	var geometry_errors := _lab_geometry_errors(template)
	metrics["profile_max_geometry_error_px"] = geometry_errors
	for profile: String in geometry_errors:
		if float(geometry_errors[profile]) > 0.001:
			failures.append("%s geometry differs from saved lab" % profile)
	var lab_energy := template.get_node("EnergyBadge") as Control
	var lab_durability := template.get_node("DurabilityBadge") as Control
	var lab_energy_number := template.get_node(
		"EnergyBadge/EnergyNumberBox") as Label
	var lab_durability_number := template.get_node(
		"DurabilityBadge/DurabilityNumberBox") as Label
	metrics["lab_energy_changed_pixels"] = await _visible_pixel_delta(lab_energy)
	metrics["lab_durability_changed_pixels"] = await _visible_pixel_delta(lab_durability)
	if int(metrics["lab_energy_changed_pixels"]) < 500:
		failures.append("lab energy badge rendered too few pixels")
	if int(metrics["lab_durability_changed_pixels"]) < 100:
		failures.append("lab durability badge rendered too few pixels")
	lab.visible = false

	var gallery := GALLERY.instantiate()
	root_window.add_child(gallery)
	await get_tree().process_frame
	await get_tree().process_frame
	var card := gallery._cards[0] as Button
	var card_cost := card.get_node("UseCostBadge") as Control
	var card_durability := card.get_node("DurabilityBadge") as Control
	metrics["gallery_cost_changed_pixels"] = await _visible_pixel_delta(card_cost)
	metrics["gallery_durability_changed_pixels"] = await _visible_pixel_delta(card_durability)
	if int(metrics["gallery_cost_changed_pixels"]) < 40:
		failures.append("formal gallery energy badge rendered too few pixels")
	if int(metrics["gallery_durability_changed_pixels"]) < 20:
		failures.append("formal gallery durability badge rendered too few pixels")

	# 用相同底色、相同物理缩放逐帧替换真实 Label；0 像素差同时覆盖
	# 字体、字号、描边、数字盒位置与实际字形栅格，避免只比节点矩形的假通过。
	gallery.visible = false
	var detail_energy_number := gallery.get_node(
		"DetailArea/UseCostBadge/Num") as Label
	var detail_durability_number := gallery.get_node(
		"DetailArea/DurabilityBadge/Num") as Label
	var card_energy_number := card.get_node("UseCostBadge/Num") as Label
	var card_durability_number := card.get_node("DurabilityBadge/Num") as Label
	var detail_scale := (gallery.get_node(
		"DetailArea/UseCostBadge") as Control).scale
	var card_scale := card_cost.scale
	var right_energy_delta := await _label_render_delta(
		lab_energy_number, detail_energy_number, detail_scale)
	var right_durability_delta := await _label_render_delta(
		lab_durability_number, detail_durability_number, detail_scale)
	var left_energy_delta := await _label_render_delta(
		lab_energy_number, card_energy_number, card_scale)
	var left_durability_delta := await _label_render_delta(
		lab_durability_number, card_durability_number, card_scale)
	metrics["gallery_right_energy_glyph_delta"] = right_energy_delta
	metrics["gallery_right_durability_glyph_delta"] = right_durability_delta
	metrics["gallery_left_energy_glyph_delta"] = left_energy_delta
	metrics["gallery_left_durability_glyph_delta"] = left_durability_delta
	for result: Dictionary in [right_energy_delta, right_durability_delta,
			left_energy_delta, left_durability_delta]:
		if int(result["changed_pixels"]) > 0:
			failures.append("formal gallery number glyph differs from saved lab")
	root_window.remove_child(gallery)
	gallery.free()
	root_window.remove_child(lab)
	lab.free()

	BattleSetup.reset()
	var screen := BATTLE8.instantiate()
	root_window.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.state = screen.State.PLAYER_SELECT
	screen._set_buttons_active(true)
	for child: Node in screen.get_children():
		if child is CanvasItem and child != screen.buttons_ctrl:
			(child as CanvasItem).visible = false
	for child: Node in screen.buttons_ctrl.get_children():
		if child is CanvasItem and child != screen.btn_attack:
			(child as CanvasItem).visible = false
	var badge := screen.btn_attack.get_node("CostPips") as IconBadge
	var sample_rect: Rect2 = screen.btn_attack.get_global_rect().merge(
		badge.get_global_rect()).grow(8.0)
	screen.battle.energy[screen.PLAYER] = ActionDef.BASE_ACTION_DEF[
		ActionDef.Action.ATTACK]["cost"]
	screen._refresh_action_affordance()
	var normal := await _capture_frame()
	screen.battle.energy[screen.PLAYER] = 0
	screen._refresh_action_affordance()
	var insufficient := await _capture_frame()
	if screen.btn_attack.modulate != screen.ACTION_DISABLED_BUTTON_MODULATE:
		failures.append("insufficient energy did not modulate the whole button")
	if badge.modulate != Color.WHITE:
		failures.append("cost badge received a second gray layer")
	var queued_charge: bool = screen._dispatch_command_drop({
		kind = "action",
		action = ActionDef.Action.CHARGE,
		button = screen.btn_charge,
	})
	var insufficient_with_charge := await _capture_frame()
	var queued_delta := _pixel_delta_in_rect(
		insufficient, insufficient_with_charge, sample_rect)
	metrics["insufficient_to_queued_charge"] = queued_delta
	if not queued_charge or screen._turn_command_queue.is_empty():
		failures.append("charge was not queued for gray-state regression")
	if screen.btn_attack.modulate != screen.ACTION_DISABLED_BUTTON_MODULATE:
		failures.append("queued charge overwrote whole-button disabled visual")
	if int(queued_delta["changed_pixels"]) > 0:
		failures.append("queued charge changed pixels of another disabled button")
	screen.battle.energy[screen.PLAYER] = ActionDef.BASE_ACTION_DEF[
		ActionDef.Action.ATTACK]["cost"]
	screen._refresh_action_affordance()
	screen._set_buttons_active(false, true)
	var execution := await _capture_frame()
	var normal_delta := _pixel_delta_in_rect(normal, insufficient, sample_rect)
	var execution_delta := _pixel_delta_in_rect(
		insufficient_with_charge, execution, sample_rect)
	metrics["normal_to_insufficient"] = normal_delta
	metrics["insufficient_to_execution"] = execution_delta
	if int(normal_delta["changed_pixels"]) < 100:
		failures.append("insufficient-energy whole button change is not visible in pixels")
	if int(execution_delta["changed_pixels"]) > 0:
		failures.append("insufficient-energy pixels differ from execution-phase pixels")

	# 单独实例化真实 ItemSlotRow，不保存截图；对锁定父组、封条位置和最终红字像素取证。
	screen.visible = false
	var row := ItemSlotRow.new()
	row.position = Vector2(500.0, 420.0)
	root_window.add_child(row)
	await get_tree().process_frame
	var test_item := ItemCatalog.make("v2_t1_whetstone")
	screen.battle.item_v2_enabled = true
	screen.battle.slots[screen.PLAYER][0] = {
		state = BattleCore.SlotState.CHARGING,
		item = test_item,
		since = screen.battle.turn_number - 1,
		used = false,
		draft = [],
		upg_draft = [],
		draft_entry_uids = [],
		instance_uid = 2201,
		temporary = false,
		current_durability = 1,
		max_durability = 2,
		used_turn = screen.battle.turn_number,
		lifecycle = "REAL",
	}
	row.refresh(screen.battle, screen.PLAYER)
	var visual_group := row._visual_groups[0] as Control
	var lock_seal := row._mini_seals[0] as Control
	var durability := row._durability_badges[0] as IconBadge
	var durability_number := durability.get_node("Num") as Label
	var group_complete := true
	for node: CanvasItem in [row._cells[0], row._tex_frames[0], row._icon_shadows[0],
			row._icons[0], row._cost_badges[0], durability]:
		group_complete = group_complete and visual_group.is_ancestor_of(node)
	metrics["locked_visual_group_complete"] = group_complete
	metrics["locked_seal_center_error_px"] = lock_seal.position.distance_to(
		Vector2.ONE * (ItemSlotRow.SLOT_W * 0.5))
	metrics["locked_durability_text"] = durability_number.text
	if not group_complete:
		failures.append("locked item visuals do not share one parent modulation chain")
	if visual_group.modulate != ItemSlotRow.LOCKED_VISUAL_MODULATE:
		failures.append("locked item visual group has the wrong modulation")
	if float(metrics["locked_seal_center_error_px"]) > 0.001 or not lock_seal.visible:
		failures.append("locked item seal is not centered")
	if durability_number.text != "x-1" \
			or durability_number.get_theme_color("font_color") != ItemSlotRow.DURABILITY_USED_COLOR:
		failures.append("used durability is not rendered as red x-1")

	var row_rect := row.slot_global_rect(0).grow(32.0)
	lock_seal.visible = false
	var locked_group_image := await _capture_frame()
	visual_group.modulate = Color.WHITE
	var undimmed_group_image := await _capture_frame()
	var group_pixel_delta := _pixel_delta_in_rect(
		locked_group_image, undimmed_group_image, row_rect)
	metrics["locked_group_modulation_pixel_delta"] = group_pixel_delta
	if int(group_pixel_delta["changed_pixels"]) < 300:
		failures.append("locked parent modulation did not affect enough final pixels")
	visual_group.modulate = ItemSlotRow.LOCKED_VISUAL_MODULATE
	lock_seal.visible = true
	var used_image := await _capture_frame()
	var red_pixels := _red_pixel_count(used_image, durability.get_global_rect().grow(4.0))
	metrics["used_durability_red_pixels"] = red_pixels
	if red_pixels < 4:
		failures.append("red x-1 has no measurable final pixel footprint")
	root_window.remove_child(row)
	row.free()

	BattleSetup.reset()
	if failures.is_empty():
		print("ITEM_FRAME_RUNTIME_PROBE_OK ", JSON.stringify(metrics))
	else:
		push_error("ITEM_FRAME_RUNTIME_PROBE_FAILED %s metrics=%s" % [
			"; ".join(failures), JSON.stringify(metrics)])
	get_tree().quit(0 if failures.is_empty() else 1)


func _lab_geometry_errors(template: Control) -> Dictionary:
	var nodes := {
		"frame_rect": template.get_node("Frame"),
		"frame_shadow_rect": template.get_node("FrameDropShadow"),
		"cell_rect": template.get_node("BackgroundCell"),
		"item_art_rect": template.get_node("ItemArt"),
		"item_art_shadow_rect": template.get_node("ItemArtShadow"),
	}
	var energy := template.get_node("EnergyBadge") as Control
	var durability := template.get_node("DurabilityBadge") as Control
	var energy_icon := template.get_node("EnergyBadge/EnergyIcon") as Control
	var energy_number := template.get_node("EnergyBadge/EnergyNumberBox") as Control
	var durability_icon := template.get_node("DurabilityBadge/DurabilityIcon") as Control
	var durability_number := template.get_node(
		"DurabilityBadge/DurabilityNumberBox") as Control
	var result := {}
	for profile: StringName in [&"gallery_left", &"gallery_right", &"battle", &"sequence"]:
		var layout := ItemFrameStyle.item_frame_layout(profile)
		var factor: float = layout["scale"]
		var maximum := 0.0
		for key: String in nodes:
			var node := nodes[key] as Control
			maximum = maxf(maximum,
				_rect_error(layout[key], _scaled_rect(node.get_rect(), factor)))
		maximum = maxf(maximum, Vector2(layout["cost_position"]).distance_to(
			energy.position * factor))
		maximum = maxf(maximum, Vector2(layout["durability_position"]).distance_to(
			durability.position * factor))
		maximum = maxf(maximum, Vector2(layout["badge_scale"]).distance_to(
			energy.scale * factor))
		maximum = maxf(maximum, Vector2(layout["badge_scale"]).distance_to(
			durability.scale * factor))
		maximum = maxf(maximum, _rect_error(
			layout["energy_icon_rect"], energy_icon.get_rect()))
		maximum = maxf(maximum, _rect_error(
			layout["energy_number_rect"], energy_number.get_rect()))
		maximum = maxf(maximum, _rect_error(
			layout["durability_icon_rect"], durability_icon.get_rect()))
		maximum = maxf(maximum, _rect_error(
			layout["durability_number_rect"], durability_number.get_rect()))
		result[String(profile)] = maximum
	return result


func _label_render_delta(first: Label, second: Label,
		parent_scale: Vector2) -> Dictionary:
	var host := Control.new()
	host.position = Vector2(420.0, 300.0)
	host.size = Vector2(80.0, 80.0)
	host.scale = parent_scale
	get_tree().root.add_child(host)
	var first_copy := first.duplicate() as Label
	host.add_child(first_copy)
	var first_image := await _capture_frame()
	host.remove_child(first_copy)
	first_copy.free()
	var second_copy := second.duplicate() as Label
	host.add_child(second_copy)
	var second_image := await _capture_frame()
	var sample_rect := Rect2(host.position - Vector2(24.0, 24.0),
		Vector2(260.0, 260.0))
	var result := _pixel_delta_in_rect(first_image, second_image, sample_rect)
	get_tree().root.remove_child(host)
	host.free()
	return result


func _visible_pixel_delta(control: Control) -> int:
	var visible_image := await _capture_frame()
	var rect := control.get_global_rect().grow(3.0)
	control.visible = false
	var hidden_image := await _capture_frame()
	control.visible = true
	return int(_pixel_delta_in_rect(visible_image, hidden_image, rect)["changed_pixels"])


func _capture_frame() -> Image:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	return get_tree().root.get_texture().get_image()


func _pixel_delta_in_rect(first: Image, second: Image, rect: Rect2) -> Dictionary:
	var transform := get_tree().root.get_screen_transform()
	var start := transform * rect.position
	var finish := transform * rect.end
	var sample := Rect2i(Vector2i(floori(start.x), floori(start.y)),
		Vector2i(ceili(finish.x - start.x), ceili(finish.y - start.y)))
	sample = sample.intersection(Rect2i(Vector2i.ZERO, first.get_size()))
	var changed := 0
	var maximum := 0.0
	for y: int in range(sample.position.y, sample.end.y):
		for x: int in range(sample.position.x, sample.end.x):
			var a := first.get_pixel(x, y)
			var b := second.get_pixel(x, y)
			var delta := maxf(absf(a.r - b.r), maxf(absf(a.g - b.g),
				maxf(absf(a.b - b.b), absf(a.a - b.a))))
			maximum = maxf(maximum, delta)
			if delta > 0.01:
				changed += 1
	return {"changed_pixels": changed, "max_channel_delta": maximum}


func _red_pixel_count(image: Image, rect: Rect2) -> int:
	var transform := get_tree().root.get_screen_transform()
	var start := transform * rect.position
	var finish := transform * rect.end
	var sample := Rect2i(Vector2i(floori(start.x), floori(start.y)),
		Vector2i(ceili(finish.x - start.x), ceili(finish.y - start.y)))
	sample = sample.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var count := 0
	for y: int in range(sample.position.y, sample.end.y):
		for x: int in range(sample.position.x, sample.end.x):
			var color := image.get_pixel(x, y)
			if color.r > 0.18 and color.r > color.g * 1.45 and color.r > color.b * 1.25:
				count += 1
	return count


func _scaled_rect(rect: Rect2, factor: float) -> Rect2:
	return Rect2(rect.position * factor, rect.size * factor)


func _rect_error(first: Rect2, second: Rect2) -> float:
	return maxf(first.position.distance_to(second.position),
		first.size.distance_to(second.size))
