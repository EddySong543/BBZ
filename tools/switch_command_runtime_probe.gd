extends Node

## 无截图切换指令验收：实例化真实 F6 battle_screen8，检查拖动/落槽两套构图，
## 再用显隐差分读取最终帧缓冲，确认落槽后只绘制目标头像且沿用通用槽位中心。

const BATTLE8 := preload("res://src/ui/battle_screen8.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene_root := get_tree().root
	var battle_setup := scene_root.get_node_or_null("BattleSetup")
	if battle_setup != null:
		battle_setup.call("reset")
	var screen := BATTLE8.instantiate()
	add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.state = screen.State.PLAYER_SELECT
	screen._set_buttons_active(true)
	screen._on_switch_main_pressed()
	var target_slot: int = screen.p1_frame_slots[1]
	var source := {kind = "switch_target", frame_idx = 1}
	var source_center: Vector2 = screen._switch_candidate_frames[0] \
		.get_global_rect().get_center()
	screen._command_drag_origin = source_center
	screen._show_command_drag(source, source_center)
	var preview := screen._command_drag_preview as Control
	var drag_has_portrait := preview != null \
		and preview.find_child("Portrait", true, false) != null
	var drag_has_marker := preview != null \
		and preview.find_child("SwitchMarker", true, false) != null
	var drag_has_button := preview != null \
		and preview.find_child("SwitchIcon", true, false) != null
	if not drag_has_portrait or drag_has_marker or drag_has_button:
		failures.append("drag preview is not portrait-only")
	if preview != null:
		screen.remove_child(preview)
		preview.free()
		screen._command_drag_preview = null
	screen._restore_command_drag_source()

	if not screen._dispatch_command_drop(source):
		failures.append("switch target drop was rejected")
	await get_tree().process_frame
	var slot := screen._command_order_row.get_node_or_null("Step0") as Control
	var art := screen._command_order_row.get_node_or_null("Step0/Visual/Art") as Control
	var target_frame := art as HeroFrame
	var settled_has_button := art != null \
		and (art.find_child("SwitchButton", true, false) != null \
			or art.find_child("SwitchIcon", true, false) != null)
	if target_frame == null or settled_has_button:
		failures.append("settled switch art is not portrait-only")
	if art == null or int(art.get_meta("switch_target_slot", -1)) != target_slot:
		failures.append("settled art target does not match selected hero")
	if target_frame != null and target_frame.find_child("SwitchMarker", true, false) != null:
		failures.append("settled target portrait still contains SwitchMarker")
	if art != null and art.has_meta("command_slot_anchor_rect"):
		failures.append("settled portrait still uses the removed downward anchor")
	var visual_center := art.position + art.size * art.scale * 0.5 \
		if art != null else Vector2.ZERO
	var expected_center: Vector2 = Vector2.ONE * (screen.COMMAND_SLOT_SIZE * 0.5) \
		+ Vector2(0.0, screen.COMMAND_SLOT_ART_OFFSET_Y)
	var slot_center_delta := visual_center.distance_to(expected_center)
	if slot_center_delta > 0.01:
		failures.append("settled portrait does not use the common command art center")

	screen.process_mode = Node.PROCESS_MODE_DISABLED
	RenderingServer.force_draw(true)
	var root_window := get_tree().root
	var portrait_rect := _physical_rect(target_frame, root_window) \
		if target_frame != null else Rect2()
	var slot_rect := _physical_rect(slot, root_window) if slot != null else Rect2()

	var visible_image := root_window.get_texture().get_image()
	if visible_image == null:
		failures.append("runtime framebuffer unavailable")
	var baseline_image: Image
	if art != null and visible_image != null:
		art.visible = false
		RenderingServer.force_draw(true)
		baseline_image = root_window.get_texture().get_image()
		art.visible = true
		RenderingServer.force_draw(true)
	var portrait_pixels := 0
	if visible_image != null and baseline_image != null:
		portrait_pixels = _changed_pixel_count(
			visible_image, baseline_image, portrait_rect)
		if portrait_pixels < 24:
			failures.append("target portrait pixel footprint is missing")

	var metrics := {
		"scene": screen.scene_file_path,
		"target_slot": target_slot,
		"drag_portrait_only": drag_has_portrait and not drag_has_marker and not drag_has_button,
		"settled_portrait_only": target_frame != null and not settled_has_button,
		"portrait_rect": _rect_array(portrait_rect),
		"slot_rect": _rect_array(slot_rect),
		"common_slot_center_delta": slot_center_delta,
		"portrait_changed_pixels": portrait_pixels,
	}
	if failures.is_empty():
		print("SWITCH_COMMAND_RUNTIME_PROBE_OK ", JSON.stringify(metrics))
	else:
		push_error("SWITCH_COMMAND_RUNTIME_PROBE_FAILED %s metrics=%s" % [
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
