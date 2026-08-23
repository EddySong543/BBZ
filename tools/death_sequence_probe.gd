extends SceneTree

## 无截图死亡链验收：真实倒地结束事件、末帧停留、硬切像素侵蚀、无淡出与新人入场复位。


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var setup := root.get_node("BattleSetup")
	setup.reset()
	var screen := (load("res://src/ui/battle_screen1.tscn") as PackedScene).instantiate()
	root.add_child(screen)
	await process_frame
	await process_frame

	if screen.get_node_or_null("Buttons/BtnCodex") != null:
		failures.append("battle codex button still exists")
	if screen.btn_confirm.position != Vector2(1772.0, 46.0) \
			or screen.btn_backpack.position != Vector2(1652.0, 46.0):
		failures.append("backpack/end bottom-right layout is incorrect")

	var battle: Variant = screen.battle
	var player := 1
	var active := int(battle.active_index[player])
	var original_hp := int(battle.hp[player][active])
	battle.hp[player][active] = 0
	screen.death_final_frame_hold_duration = 0.16
	screen.death_dissolve_duration = 0.16
	screen.death_dissolve_steps = 12
	screen.death_entry_duration = 0.06
	var display: CharacterDisplay = screen.p2_char_display
	if display.material != null:
		failures.append("alive character still owns the death dissolve material")

	screen.call("_play_defeat", player)
	var deadline := Time.get_ticks_msec() + 3000
	while int(screen._defeat_contact_at_ms[player]) <= 0 \
			and Time.get_ticks_msec() < deadline:
		await process_frame
	if int(screen._defeat_contact_at_ms[player]) <= 0:
		failures.append("defeat animation never reached its contact event")
	if display.offset_transform_position.length() > 0.1:
		failures.append("short fatal recoil did not return to the authored anchor")
	if not bool(screen._defeat_dissolve_started[player]):
		failures.append("dissolve was not scheduled from the real defeat contact")
	if display.material != null:
		failures.append("bright final-frame hold attached the death material too early")
	if not display.modulate.is_equal_approx(Color.WHITE):
		failures.append("death contact changed the final frame brightness")

	# 末帧必须以原亮度完全静止，不能暗化，也不能提前侵蚀。
	await create_timer(0.07).timeout
	if display.material != null:
		failures.append("erosion material appeared during the bright still hold")
	if not display.modulate.is_equal_approx(Color.WHITE):
		failures.append("final frame faded from bright to dark during the hold")

	await create_timer(0.14).timeout
	var death_material := display.material as ShaderMaterial
	if death_material == null or death_material.shader.resource_path \
			!= "res://assets/shaders/canvas_ui_character_death_dissolve.gdshader":
		failures.append("death dissolve material was not attached when erosion began")
		setup.reset()
		quit(1)
		return
	var stepped_progress := float(death_material.get_shader_parameter("dissolve_progress"))
	if stepped_progress <= 0.0 or stepped_progress >= 1.0:
		failures.append("four-side erosion did not enter an observable intermediate phase")
	if not display.modulate.is_equal_approx(Color.WHITE):
		failures.append("death erosion still changes whole-character brightness or alpha")
	if int(death_material.get_shader_parameter("dissolve_steps")) != 12:
		failures.append("shader did not receive the configured hard-cut step count")
	if not is_equal_approx(float(screen.DEATH_DISSOLVE_OPEN_PROGRESS), 0.25) \
			or not is_equal_approx(float(screen.DEATH_DISSOLVE_MIDDLE_PROGRESS), 0.83) \
			or not is_equal_approx(float(screen.DEATH_DISSOLVE_OPEN_SHARE), 0.30) \
			or not is_equal_approx(float(screen.DEATH_DISSOLVE_MIDDLE_SHARE), 0.42) \
			or not is_equal_approx(float(screen.DEATH_DISSOLVE_CLOSE_SHARE), 0.28):
		failures.append("three-phase erosion cadence is not configured")

	await screen.call("_wait_for_death_dissolve", player)
	if not bool(screen._defeat_dissolve_completed[player]):
		failures.append("death erosion did not report completion")
	if float(death_material.get_shader_parameter("dissolve_progress")) < 0.999:
		failures.append("death erosion did not fully remove the defeated body")
	if not display.modulate.is_equal_approx(Color.WHITE):
		failures.append("fully eroded body was hidden by tint/fade instead of hard discard")

	# 探针不真换英雄：恢复生命，让已瓦解期刷新能走与实际替补相同的活人路径。
	battle.hp[player][active] = original_hp
	await screen.call("_death_switch_transition", player)
	if not display.offset_transform_position.is_zero_approx():
		failures.append("replacement entry did not settle without residual transform")
	if display.modulate.a < 0.99:
		failures.append("replacement entry did not restore full opacity")
	if display.material != null:
		failures.append("death dissolve pass remained on the replacement hero")
	if float(death_material.get_shader_parameter("dissolve_progress")) > 0.001:
		failures.append("detached death material did not reset its progress")

	setup.reset()
	if failures.is_empty():
		print("DEATH_SEQUENCE_PROBE_OK: alive_pass=unloaded contact=animation_finished hold=bright_still_160ms_probe erosion=lazy_four_side_12_step_three_phase reset=unloaded entry=cubic_no_bounce buttons=backpack_plus_end_bottom_right")
		quit(0)
		return
	push_error("DEATH_SEQUENCE_PROBE: %s" % "; ".join(failures))
	quit(1)
