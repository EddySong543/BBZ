extends Node

## 任务5无截图验收：实例化真实 F6 battle_screen8，核对统一放大后的槽位、
## 内容和间距；用节点身份与运行状态证明稳定高亮不会呼吸或被强制刷新重建，
## 再从最终帧缓冲读取十字星和行动图案的实际像素 footprint。

const BATTLE8 := preload("res://src/ui/battle_screen8.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var root_window := get_tree().root
	root_window.transparent_bg = true
	RenderingServer.set_default_clear_color(Color.TRANSPARENT)
	var battle_setup := root_window.get_node_or_null("BattleSetup")
	if battle_setup != null:
		battle_setup.call("reset")
	var screen := BATTLE8.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.state = screen.State.PLAYER_SELECT
	screen._set_buttons_active(true)
	var strip := screen._command_order_strip as Control
	for child: Node in screen.get_children():
		if child is CanvasItem and child != strip:
			(child as CanvasItem).visible = false
	strip.visible = true
	strip.modulate = Color.WHITE
	var button_top: float = screen.btn_charge.get_global_rect().position.y
	if screen.COMMAND_SLOT_SIZE != 76.0 or screen.COMMAND_SLOT_GAP != 16.0:
		failures.append("slot size or spacing is not the task5 layout")
	if screen.COMMAND_STRIP_RECT.size != Vector2(880.0, 104.0):
		failures.append("command strip was not enlarged as one system")
	if screen.COMMAND_STRIP_RECT.end.y >= button_top:
		failures.append("enlarged strip overlaps the bottom action buttons")

	var idle_slot := screen._command_next_slot as Control
	var idle_skin := screen._command_next_slot_skin as Control
	var idle_geometry: Dictionary = idle_skin.debug_geometry()
	var idle_slot_rect := _physical_rect(idle_slot, root_window)
	# 十字星是底座而不是槽内图案，尖端和右下投影允许越过 76px Control 边界。
	# 像素验收必须覆盖实际绘制区，不能被父槽的逻辑矩形截短。
	var idle_draw_rect := idle_slot_rect.grow(24.0)
	if idle_slot.size != Vector2.ONE * screen.COMMAND_SLOT_SIZE:
		failures.append("runtime next slot is not 76x76")
	if idle_skin.scale != Vector2.ONE * screen.COMMAND_SLOT_SCALE:
		failures.append("cross star does not use the common uniform scale")
	if bool(idle_geometry["processing"]):
		failures.append("idle cross star still runs a breathing process")
	if bool(idle_skin.get("hot")):
		failures.append("empty slot starts highlighted without a pending choice")
	var physical_transform: Transform2D = root_window.get_screen_transform() \
		* idle_skin.get_global_transform_with_canvas()
	var physical_star_center: Vector2 = physical_transform \
		* (idle_geometry["star_center"] as Vector2)
	if absf(physical_star_center.x - floorf(physical_star_center.x) - 0.5) > 0.01 \
			or absf(physical_star_center.y - floorf(physical_star_center.y) - 0.5) > 0.01:
		failures.append("scaled cross star lost its half-pixel sampling phase")
	await RenderingServer.frame_post_draw
	var idle_image: Image = root_window.get_texture().get_image()
	var idle_alpha_sum := _alpha_sum(idle_image, idle_draw_rect)
	var idle_bounds := _alpha_bounds_in_rect(idle_image, idle_draw_rect, 0.02)
	if idle_bounds.size.x < 29 or idle_bounds.size.y < 25:
		failures.append("enlarged cross star pixel footprint is smaller than expected")

	screen._dispatch_command_click({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	await get_tree().process_frame
	var hot_slot := screen._command_next_slot as Control
	var hot_skin := screen._command_next_slot_skin as Control
	var hot_instance_id := hot_slot.get_instance_id()
	if not bool(hot_skin.get("hot")):
		failures.append("pending action does not keep the next slot highlighted")
	if hot_skin.is_processing():
		failures.append("highlighted slot still runs a repeating process")
	await RenderingServer.frame_post_draw
	var hot_image: Image = root_window.get_texture().get_image()
	var hot_alpha_sum := _alpha_sum(
		hot_image, _physical_rect(hot_slot, root_window).grow(24.0))
	if hot_alpha_sum <= idle_alpha_sum * 1.5:
		failures.append("framebuffer does not show a materially brighter pending slot")
	for _frame: int in range(12):
		await get_tree().process_frame
	screen._refresh_command_order_strip()
	await RenderingServer.frame_post_draw
	var steady_slot := screen._command_next_slot as Control
	var steady_skin := screen._command_next_slot_skin as Control
	var steady_image: Image = root_window.get_texture().get_image()
	var steady_alpha_sum := _alpha_sum(
		steady_image, _physical_rect(steady_slot, root_window).grow(24.0))
	var unchanged_refresh_reused_slot: bool = \
		steady_slot.get_instance_id() == hot_instance_id
	var steady_highlight_processing: bool = steady_skin.is_processing()
	if not unchanged_refresh_reused_slot:
		failures.append("unchanged refresh rebuilt the next slot")
	if absf(steady_alpha_sum - hot_alpha_sum) > 0.05:
		failures.append("pending highlight changed brightness across idle frames")
	if steady_skin.is_processing():
		failures.append("steady pending highlight unexpectedly processes frames")

	var accepted: bool = screen._dispatch_command_drop({
		kind = "action", action = ActionDef.Action.CHARGE, button = screen.btn_charge,
	})
	await get_tree().process_frame
	var step := screen._command_order_row.get_node_or_null("Step0") as Control
	var next_slot := screen._command_next_slot as Control
	var next_skin := screen._command_next_slot_skin as Control
	if not accepted or step == null:
		failures.append("selected action was not placed into the sequence")
	if bool(next_skin.get("hot")):
		failures.append("accepted placement did not clear the next-slot highlight")
	# 真正的内容变化允许一次 0.14s 的克制重排；检查其最终落位，不把过渡帧
	# 错判为间距偏移。
	await get_tree().create_timer(0.18).timeout
	if step != null and absf(next_slot.position.x - step.position.x - step.size.x \
			- screen.COMMAND_SLOT_GAP) > 0.01:
		failures.append("runtime sequence gap differs from the 16px common gap")
	var art := step.get_node_or_null("Visual/Art") as Control if step != null else null
	var rendered_art_size := art.size * art.scale if art != null else Vector2.ZERO
	var available: float = screen.COMMAND_SLOT_SIZE \
		- screen.COMMAND_SLOT_ART_INSET * 2.0
	if art == null or absf(maxf(rendered_art_size.x, rendered_art_size.y) - available) > 0.01:
		failures.append("placed action art does not fill the 68px common content area")

	var art_pixels := 0
	if art != null:
		RenderingServer.force_draw(true)
		var visible_image: Image = root_window.get_texture().get_image()
		var art_rect := _physical_rect(art, root_window)
		art.visible = false
		RenderingServer.force_draw(true)
		var hidden_image: Image = root_window.get_texture().get_image()
		art.visible = true
		RenderingServer.force_draw(true)
		art_pixels = _changed_pixel_count(visible_image, hidden_image, art_rect)
		if art_pixels < 48:
			failures.append("placed action art has no measurable pixel footprint")

	var landing_start := {}
	var landing_end := {}
	if step != null:
		screen._play_command_slot_land(step)
		landing_start = (step.get_node("SlotSkin") as Control).debug_geometry()
		await get_tree().create_timer(screen.COMMAND_SLOT_LAND_DURATION + 0.06).timeout
		landing_end = (step.get_node("SlotSkin") as Control).debug_geometry()
		if float(landing_start["lock_progress"]) != 0.0 \
				or float(landing_start["flash_peak"]) < 1.0:
			failures.append("true content change did not start the restrained landing feedback")
		if absf(float(landing_end["lock_progress"]) - 1.0) > 0.01:
			failures.append("landing feedback did not settle exactly once")

	var metrics := {
		"scene": screen.scene_file_path,
		"slot_size": screen.COMMAND_SLOT_SIZE,
		"slot_gap": screen.COMMAND_SLOT_GAP,
		"strip_rect": _rect_array(screen.COMMAND_STRIP_RECT),
		"button_clearance": button_top - screen.COMMAND_STRIP_RECT.end.y,
		"cross_star_uniform_scale": screen.COMMAND_SLOT_SCALE,
		"cross_star_center": [physical_star_center.x, physical_star_center.y],
		"idle_pixel_bounds": _recti_array(idle_bounds),
		"idle_alpha_sum": idle_alpha_sum,
		"hot_alpha_sum": hot_alpha_sum,
		"steady_alpha_sum": steady_alpha_sum,
		"unchanged_refresh_reused_slot": unchanged_refresh_reused_slot,
		"steady_highlight_processing": steady_highlight_processing,
		"placed_art_size": [rendered_art_size.x, rendered_art_size.y],
		"placed_art_changed_pixels": art_pixels,
		"landing_start_lock": landing_start.get("lock_progress", -1.0),
		"landing_end_lock": landing_end.get("lock_progress", -1.0),
	}
	if failures.is_empty():
		print("COMMAND_ORDER_UI_RUNTIME_PROBE_OK ", JSON.stringify(metrics))
	else:
		push_error("COMMAND_ORDER_UI_RUNTIME_PROBE_FAILED %s metrics=%s" % [
			"; ".join(failures), JSON.stringify(metrics)])
	if battle_setup != null:
		battle_setup.call("reset")
	get_tree().quit(0 if failures.is_empty() else 1)


func _physical_rect(control: Control, root_window: Window) -> Rect2:
	var transform := root_window.get_screen_transform() \
		* control.get_global_transform_with_canvas()
	var points := [
		transform * Vector2.ZERO,
		transform * Vector2(control.size.x, 0.0),
		transform * control.size,
		transform * Vector2(0.0, control.size.y),
	]
	var minimum: Vector2 = points[0]
	var maximum: Vector2 = points[0]
	for point: Vector2 in points:
		minimum.x = minf(minimum.x, point.x)
		minimum.y = minf(minimum.y, point.y)
		maximum.x = maxf(maximum.x, point.x)
		maximum.y = maxf(maximum.y, point.y)
	return Rect2(minimum, maximum - minimum)


func _alpha_sum(image: Image, sample_rect: Rect2) -> float:
	var rect := Rect2i(sample_rect).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var total := 0.0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			total += image.get_pixel(x, y).a
	return total


func _alpha_bounds_in_rect(image: Image, sample_rect: Rect2,
		threshold: float) -> Rect2i:
	var rect := Rect2i(sample_rect).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var minimum := rect.end
	var maximum := Vector2i(-1, -1)
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a < threshold:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	return Rect2i() if maximum.x < minimum.x else Rect2i(
		minimum, maximum - minimum + Vector2i.ONE)


func _changed_pixel_count(before: Image, after: Image, sample_rect: Rect2) -> int:
	var rect := Rect2i(sample_rect).intersection(Rect2i(Vector2i.ZERO, before.get_size()))
	var changed := 0
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) \
					+ absf(a.a - b.a) > 0.04:
				changed += 1
	return changed


func _rect_array(rect: Rect2) -> Array[float]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func _recti_array(rect: Rect2i) -> Array[int]:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
