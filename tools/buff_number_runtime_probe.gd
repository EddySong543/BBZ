extends Node

## 无截图 Buff 数字验收：直接加载用户 F6 的 battle_screen8，核对调校资源、
## 三种计数数字的运行时几何，并以显隐差分统计最终像素字形占用。

const BATTLE8_PATH := "res://src/ui/battle_screen8.tscn"
const TUNING_LAB_PATH := "res://src/ui/debug/buff_tuning_lab.tscn"
const NUMBER_TUNING_PATH := "res://src/ui/components/battle_status_number_tuning.tres"
const EFFECT_IDS: Array[StringName] = [&"poison", &"vulnerable", &"sword_qi"]


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var scene_root := get_tree().root
	var battle_setup := scene_root.get_node_or_null("BattleSetup")
	if battle_setup == null:
		push_error("BUFF_NUMBER_RUNTIME_PROBE: BattleSetup autoload missing")
		get_tree().quit(1)
		return
	battle_setup.call("reset")

	var lab_packed := load(TUNING_LAB_PATH) as PackedScene
	var battle_packed := load(BATTLE8_PATH) as PackedScene
	if lab_packed == null or battle_packed == null:
		push_error("BUFF_NUMBER_RUNTIME_PROBE: required scene failed to load")
		get_tree().quit(1)
		return

	var lab := lab_packed.instantiate() as Control
	scene_root.add_child(lab)
	await get_tree().process_frame
	var preview := lab.get_node("BuffPreview") as BattleStatusRow
	var lab_geometry := _number_geometry(preview)
	if preview.number_tuning.resource_path != NUMBER_TUNING_PATH:
		failures.append("lab does not reference authoritative number tuning")
	scene_root.remove_child(lab)
	lab.free()

	var screen := battle_packed.instantiate()
	scene_root.add_child(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	for player: int in 2:
		var slot: int = screen.battle.active_index[player]
		screen.battle.set_status(player, slot, "poison", 3)
		screen.battle.set_status(player, slot, "vuln", 2)
		screen.battle.set_team_status(player, "jianqi", 4)
		(screen._battle_status_rows[player] as BattleStatusRow).enter_motion_enabled = false
	screen._refresh_battle_status_rows()
	await get_tree().process_frame
	screen.process_mode = Node.PROCESS_MODE_DISABLED

	var runtime_geometries: Array[Dictionary] = []
	var pixel_metrics_by_player: Array[Dictionary] = []
	for player: int in 2:
		var row := screen._battle_status_rows[player] as BattleStatusRow
		if row.number_tuning.resource_path != NUMBER_TUNING_PATH:
			failures.append(
					"battle_screen8 P%d row does not reference authoritative tuning" \
					% (player + 1))
		var runtime_geometry := _number_geometry(row)
		runtime_geometries.append(runtime_geometry)
		for effect_id: StringName in EFFECT_IDS:
			if runtime_geometry.get(effect_id) != lab_geometry.get(effect_id):
				failures.append("P%d %s runtime geometry differs from lab: %s vs %s" % [
					player + 1,
					effect_id,
					str(runtime_geometry.get(effect_id)),
					str(lab_geometry.get(effect_id)),
				])
		var pixel_metrics := await _capture_count_pixel_metrics(row)
		pixel_metrics_by_player.append(pixel_metrics)
		for effect_id: StringName in EFFECT_IDS:
			var metric: Dictionary = pixel_metrics.get(effect_id, {})
			var changed_pixels := int(metric.get("changed_pixels", 0))
			var used_rect := metric.get("used_rect", Rect2i()) as Rect2i
			if changed_pixels < 18:
				failures.append("P%d %s count glyph footprint too small: %d" % [
					player + 1, effect_id, changed_pixels])
			if used_rect.size.x < 8 or used_rect.size.y < 8:
				failures.append("P%d %s count glyph bounds unreadable: %s" % [
					player + 1, effect_id, str(used_rect)])

	if not failures.is_empty():
		push_error("BUFF_NUMBER_RUNTIME_PROBE: %s" % "; ".join(failures))
		battle_setup.call("reset")
		get_tree().quit(1)
		return

	var summaries: Array[String] = []
	for player: int in 2:
		var runtime_geometry: Dictionary = runtime_geometries[player]
		var pixel_metrics: Dictionary = pixel_metrics_by_player[player]
		for effect_id: StringName in EFFECT_IDS:
			var metric: Dictionary = pixel_metrics[effect_id]
			summaries.append("P%d/%s pos=%s pixels=%d bounds=%s" % [
				player + 1,
				effect_id,
				str((runtime_geometry[effect_id] as Dictionary)["position"]),
				int(metric["changed_pixels"]),
				str(metric["used_rect"]),
			])
	print("BUFF_NUMBER_RUNTIME_PROBE_OK: scene=battle_screen8 source=%s %s" % [
		NUMBER_TUNING_PATH,
		" | ".join(summaries),
	])
	battle_setup.call("reset")
	get_tree().quit(0)


func _number_geometry(row: BattleStatusRow) -> Dictionary:
	var result: Dictionary = {}
	for effect_id: StringName in EFFECT_IDS:
		var count := row.get_node("Status_%s/Count" % effect_id) as Control
		var prefix := count.get_node("Prefix") as Label
		var value := count.get_node("Value") as Label
		result[effect_id] = {
			"position": count.position,
			"size": count.size,
			"prefix_position": prefix.position,
			"prefix_size": prefix.size,
			"value_position": value.position,
			"value_size": value.size,
			"font_size": prefix.get_theme_font_size("font_size"),
			"outline_size": prefix.get_theme_constant("outline_size"),
			"shadow_offset": Vector2i(
				prefix.get_theme_constant("shadow_offset_x"),
				prefix.get_theme_constant("shadow_offset_y")),
		}
	return result


func _capture_count_pixel_metrics(row: BattleStatusRow) -> Dictionary:
	var sample_rects: Dictionary = {}
	var counts: Array[Control] = []
	var padding := row.number_tuning.count_outline_size \
			+ row.number_tuning.count_shadow_outline_size + 2
	for effect_id: StringName in EFFECT_IDS:
		var count := row.get_node("Status_%s/Count" % effect_id) as Control
		counts.append(count)
		sample_rects[effect_id] = _clamped_rect(
			Rect2i(count.get_global_rect()).grow(padding))
	# Probe 使用真实渲染后端；force_draw(true) 同步刷新，随后只读取内存像素，
	# 不保存、不展示任何截图。
	RenderingServer.force_draw(true)
	var visible_image := get_viewport().get_texture().get_image()
	for count: Control in counts:
		count.visible = false
	RenderingServer.force_draw(true)
	var baseline_image := get_viewport().get_texture().get_image()
	var metrics: Dictionary = {}
	for effect_id: StringName in EFFECT_IDS:
		var rect := sample_rects[effect_id] as Rect2i
		var changed := 0
		var minimum := Vector2i(rect.size.x, rect.size.y)
		var maximum := Vector2i(-1, -1)
		for local_y: int in rect.size.y:
			for local_x: int in rect.size.x:
				var point := rect.position + Vector2i(local_x, local_y)
				var visible_color := visible_image.get_pixelv(point)
				var baseline_color := baseline_image.get_pixelv(point)
				var delta := absf(visible_color.r - baseline_color.r) \
						+ absf(visible_color.g - baseline_color.g) \
						+ absf(visible_color.b - baseline_color.b) \
						+ absf(visible_color.a - baseline_color.a)
				if delta <= 0.04:
					continue
				changed += 1
				minimum.x = mini(minimum.x, local_x)
				minimum.y = mini(minimum.y, local_y)
				maximum.x = maxi(maximum.x, local_x)
				maximum.y = maxi(maximum.y, local_y)
		var used_rect := Rect2i()
		if changed > 0:
			used_rect = Rect2i(minimum, maximum - minimum + Vector2i.ONE)
		metrics[effect_id] = {
			"changed_pixels": changed,
			"used_rect": used_rect,
			"sample_rect": rect,
		}
	return metrics


func _clamped_rect(rect: Rect2i) -> Rect2i:
	return rect.intersection(Rect2i(
		Vector2i.ZERO, get_viewport().get_texture().get_size()))
