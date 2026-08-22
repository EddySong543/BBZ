extends Node

const BATTLE_SCREEN4_PATH := "res://src/ui/battle_screen4.tscn"


func _ready() -> void:
	get_window().size = Vector2i(1920, 1080)
	get_window().position = Vector2i.ZERO
	BattleSetup.reset()
	var screen := (load(BATTLE_SCREEN4_PATH) as PackedScene).instantiate() as Control
	add_child(screen)
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(screen):
		get_tree().quit(1)
		return

	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var interaction := stage.get_node("ClickInteraction")
	# Compress only the probe's achievement presentation so it can verify both
	# the active and restored states without changing authored scene defaults.
	interaction.achievement_sync_rise_sec = 0.08
	interaction.achievement_sync_hold_sec = 0.25
	interaction.achievement_sync_fall_sec = 0.15
	interaction.achievement_glow_rise_sec = 0.12
	interaction.achievement_glow_hold_sec = 0.35
	interaction.achievement_glow_fall_sec = 0.15
	interaction.achievement_cooldown_sec = 2.0
	# Input.parse_input_event teleports the synthetic cursor in one frame. Freeze
	# only the probe's parallax baseline so a target cannot move after its opaque
	# pixel is resolved; material Tweens and child animation remain active.
	stage.pointer_parallax = false
	stage.set("_pnx", 0.0)
	stage.call("_process", 0.0)
	stage.set_process(false)
	var triggered_names: Array[StringName] = []
	interaction.interaction_triggered.connect(
			func(target_name: StringName) -> void:
				triggered_names.append(target_name))

	var authored_transforms: Dictionary[StringName, Array] = {}
	for target_name: StringName in [
		&"LeftTree2",
		&"RightTree2",
		&"BackgroundTopLeaves2",
		&"RuinStone1",
		&"RuinStone2",
		&"RuinStone3",
		&"RuinStone4",
	]:
		var target := stage.get_node(NodePath(target_name)) as TextureRect
		authored_transforms[target_name] = [target.position, target.scale]

	var all_targets_clicked := true
	var single_click_flash_readable := true
	var target_results: Dictionary[StringName, int] = {}
	var hovered_results: Dictionary[StringName, String] = {}
	for target_name: StringName in [
		&"RuinStone1",
		&"RuinStone2",
		&"RuinStone3",
		&"RuinStone4",
	]:
		var point := _find_visible_click_point(stage, interaction, target_name)
		if point.is_equal_approx(Vector2.INF):
			all_targets_clicked = false
			target_results[target_name] = -1
			continue
		await _click(point)
		await get_tree().create_timer(0.08).timeout
		var target := stage.get_node(NodePath(target_name)) as TextureRect
		var hovered := get_viewport().gui_get_hovered_control()
		hovered_results[target_name] = (
				str(hovered.get_path()) if hovered != null else "<none>")
		target_results[target_name] = int(
				interaction.call("get_trigger_count", target_name))
		var material := target.material as ShaderMaterial
		single_click_flash_readable = single_click_flash_readable and (
				float(material.get_shader_parameter("interaction_flash")) > 0.9
				and float(material.get_shader_parameter(
						"interaction_flash_gain")) >= 1.15)
		all_targets_clicked = all_targets_clicked and (
				target_results[target_name] == 1)

	var top_leaves := stage.get_node("BackgroundTopLeaves2") as TextureRect
	var spirits := stage.get_node("AchievementLeafSpirits")
	var old_leaf_spirits_removed := not stage.has_node("LeafSpirits")
	var ambient_timer_running := bool(
			spirits.call("is_ambient_timer_running"))
	var ambient_triggered := bool(spirits.call("trigger_ambient_swarm"))
	var ambient_spirit_count := int(
			spirits.call("get_active_spirit_count"))
	var ambient_spirits_restored := (
			ambient_timer_running
			and ambient_triggered
			and ambient_spirit_count >= 2
			and ambient_spirit_count <= 3
			and String(spirits.call("get_active_swarm_kind")) == "ambient")
	var top_leaves_static := (
			top_leaves.get_script() == null
			and top_leaves.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and not bool(interaction.call(
					"trigger_target", &"BackgroundTopLeaves2"))
			and int(interaction.call(
					"get_trigger_count", &"BackgroundTopLeaves2")) == 0)

	var achievement_clicks_worked := true
	for target_name: StringName in [
		&"RuinStone4",
		&"RuinStone2",
		&"RuinStone3",
		&"RuinStone1",
	]:
		var point := _find_visible_click_point(stage, interaction, target_name)
		if point.is_equal_approx(Vector2.INF):
			achievement_clicks_worked = false
			continue
		await _click(point)
	await get_tree().create_timer(0.2).timeout
	var achievement_completed := bool(
			interaction.call("is_achievement_completed"))
	var active_spirit_count := int(spirits.call("get_active_spirit_count"))
	var achievement_swarm_started := (
			active_spirit_count >= 18
			and active_spirit_count <= 24
			and String(spirits.call("get_active_swarm_kind")) == "achievement")

	var transforms_preserved := true
	for target_name: StringName in authored_transforms:
		var target := stage.get_node(NodePath(target_name)) as TextureRect
		var authored := authored_transforms[target_name] as Array
		transforms_preserved = transforms_preserved \
				and target.position == authored[0] \
				and target.scale == authored[1]

	var charge_button := screen.get_node("Buttons/BtnCharge") as Button
	screen.state = 1  # BattleScreen.State.PLAYER_SELECT
	screen.call("_set_buttons_active", true)
	await get_tree().process_frame
	var button_press_state := {"count": 0}
	charge_button.pressed.connect(
			func() -> void: button_press_state["count"] += 1)
	var interactions_before_button := triggered_names.size()
	await _click(charge_button.get_global_rect().get_center())
	var ui_keeps_priority := (
			int(button_press_state["count"]) == 1
			and triggered_names.size() == interactions_before_button
			and charge_button.mouse_filter == Control.MOUSE_FILTER_STOP)

	var top_material := top_leaves.material as ShaderMaterial
	top_leaves_static = top_leaves_static and (
			not top_material.shader.code.contains("click_impulse"))
	var relic_flash_started := true
	var achievement_energy_active := true
	for stone_name: StringName in [
		&"RuinStone1", &"RuinStone2", &"RuinStone3", &"RuinStone4"
	]:
		var material := (
				stage.get_node(NodePath(stone_name)) as TextureRect
		).material as ShaderMaterial
		relic_flash_started = relic_flash_started and (
				float(material.get_shader_parameter("interaction_flash")) > 0.65)
		achievement_energy_active = achievement_energy_active and (
				float(material.get_shader_parameter("achievement_glow")) == 1.0
				and float(material.get_shader_parameter("achievement_sync")) > 0.95)
	await get_tree().create_timer(0.8).timeout
	var visible_spirit_count := int(spirits.call("get_visible_spirit_count"))
	achievement_swarm_started = achievement_swarm_started \
			and visible_spirit_count >= 8
	var achievement_energy_restored := true
	for stone_name: StringName in [
		&"RuinStone1", &"RuinStone2", &"RuinStone3", &"RuinStone4"
	]:
		var material := (
				stage.get_node(NodePath(stone_name)) as TextureRect
		).material as ShaderMaterial
		achievement_energy_restored = achievement_energy_restored and (
				float(material.get_shader_parameter("achievement_glow")) < 0.05
				and float(material.get_shader_parameter("achievement_sync")) < 0.05)
	var cooldown_active := bool(
			interaction.call("is_achievement_on_cooldown"))
	for target_name: StringName in [
		&"RuinStone4", &"RuinStone2", &"RuinStone3", &"RuinStone1",
	]:
		interaction.call("trigger_target", target_name)
	var cooldown_blocks_repeat := (
			int(interaction.call("get_achievement_trigger_count")) == 1
			and int(interaction.call("get_achievement_progress")) == 0)

	var passed := (
			all_targets_clicked
			and single_click_flash_readable
			and old_leaf_spirits_removed
			and ambient_spirits_restored
			and achievement_clicks_worked
			and achievement_completed
			and achievement_swarm_started
			and top_leaves_static
			and transforms_preserved
			and ui_keeps_priority
			and relic_flash_started
			and achievement_energy_active
			and achievement_energy_restored
			and cooldown_active
			and cooldown_blocks_repeat)
	print(
			"SCENE4_CLICK_INTERACTION_PROBE: ",
			"PASS" if passed else "FAIL",
			" all_targets_clicked=", all_targets_clicked,
			" single_click_flash_readable=", single_click_flash_readable,
			" target_results=", target_results,
			" hovered_results=", hovered_results,
			" old_leaf_spirits_removed=", old_leaf_spirits_removed,
			" ambient_timer_running=", ambient_timer_running,
			" ambient_triggered=", ambient_triggered,
			" ambient_spirit_count=", ambient_spirit_count,
			" ambient_spirits_restored=", ambient_spirits_restored,
			" achievement_clicks_worked=", achievement_clicks_worked,
			" achievement_completed=", achievement_completed,
			" active_spirits=", active_spirit_count,
			" visible_spirits=", visible_spirit_count,
			" top_leaves_static=", top_leaves_static,
			" transforms_preserved=", transforms_preserved,
			" ui_keeps_priority=", ui_keeps_priority,
			" relic_flash_started=", relic_flash_started,
			" achievement_energy_active=", achievement_energy_active,
			" achievement_energy_restored=", achievement_energy_restored,
			" cooldown_active=", cooldown_active,
			" cooldown_blocks_repeat=", cooldown_blocks_repeat)
	BattleSetup.reset()
	get_tree().quit(0 if passed else 1)


func _find_visible_click_point(
		stage: Control,
		interaction: Node,
		target_name: StringName
) -> Vector2:
	var target := stage.get_node(NodePath(target_name)) as TextureRect
	var image := target.texture.get_image()
	if image == null or image.is_empty():
		return Vector2.INF
	var step_x := maxi(1, image.get_width() / 64)
	var step_y := maxi(1, image.get_height() / 64)
	for image_y: int in range(0, image.get_height(), step_y):
		for image_x: int in range(0, image.get_width(), step_x):
			if image.get_pixel(image_x, image_y).a < 0.2:
				continue
			var uv := Vector2(
					(float(image_x) + 0.5) / float(image.get_width()),
					(float(image_y) + 0.5) / float(image.get_height()))
			if target.flip_h:
				uv.x = 1.0 - uv.x
			if target.flip_v:
				uv.y = 1.0 - uv.y
			var screen_point := target.get_global_transform_with_canvas() \
					* (uv * target.size)
			if StringName(interaction.call(
					"get_hit_target_at", screen_point)) == target_name:
				return screen_point
	return Vector2.INF


func _click(position: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		event.global_position = position
		Input.parse_input_event(event)
		await get_tree().process_frame
