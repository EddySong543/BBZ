extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var packed := load("res://src/ui/battle_screen5.tscn") as PackedScene
	var screen := packed.instantiate() as Control
	get_root().add_child(screen)
	await process_frame
	var stage := screen.get_node("StageSlot/Stage") as BattleStage
	var near_material := (
			stage.get_node("NearWheatLeft") as Control
			).material as ShaderMaterial
	var far_material := (
			stage.get_node("FarWheat") as Control
			).material as ShaderMaterial
	var occluder_material := (
			screen.get_node("WorldGroup/WorldForegroundOccluder") as Control
			).material as ShaderMaterial
	var gust_particles := stage.get_node("GustChaff") as GPUParticles2D
	var ambient_particles := stage.get_node("AmbientChaff") as GPUParticles2D
	var wind_field := stage.get_node("WindField")
	var curve_start := float(wind_field.call("response_strength_at", 0.0))
	var curve_early := float(wind_field.call("response_strength_at", 0.2))
	var curve_middle := float(wind_field.call("response_strength_at", 0.4))
	if curve_start - curve_early <= curve_early - curve_middle:
		failures.append("battle response does not use a fast-start slow-tail curve")
	stage.shake(16.0, -1.0)
	var immediate := float(
			near_material.get_shader_parameter("gust_strength"))
	var occluder_immediate := float(
			occluder_material.get_shader_parameter("gust_strength"))
	var direction := float(
			near_material.get_shader_parameter("gust_direction"))
	var far_immediate := float(
			far_material.get_shader_parameter("gust_strength"))
	if immediate < 0.99:
		failures.append("near wheat did not reach a readable gust peak")
	if occluder_immediate < 0.99:
		failures.append("foreground occluder did not share the gust peak")
	if far_immediate < 0.99:
		failures.append("complete far/mid wheat mesh did not share the gust peak")
	if direction != -1.0:
		failures.append("battle gust did not preserve hit direction")
	if not gust_particles.emitting:
		failures.append("battle gust did not emit chaff")
	var gust_process := gust_particles.process_material as ParticleProcessMaterial
	if gust_particles.position.x < 1500.0 \
			or gust_process.direction.x != -1.0 \
			or gust_process.gravity.x >= 0.0:
		failures.append("P2 gust did not originate at the right edge and travel left")
	if ambient_particles.speed_scale >= 0.3:
		failures.append("ambient rightward chaff still competes with battle gust")

	await _wait_real_msec(1480)
	var recovered := float(
			near_material.get_shader_parameter("gust_strength"))
	var occluder_recovered := float(
			occluder_material.get_shader_parameter("gust_strength"))
	if recovered > 0.01 or occluder_recovered > 0.01:
		failures.append(
				"battle gust did not recover within its contract "
				+ "(near=%.4f occluder=%.4f)"
				% [recovered, occluder_recovered])
	if not is_equal_approx(ambient_particles.speed_scale, 1.0):
		failures.append("ambient chaff speed was not restored after battle gust")
	stage.shake(16.0, 0.0)
	var dual_direction := float(
			near_material.get_shader_parameter("gust_direction"))
	if dual_direction != 0.0 \
			or gust_particles.position.x < 900.0 \
			or gust_particles.position.x > 1020.0:
		failures.append("equal waves did not produce a centered dual-side response")
	await _wait_real_msec(1480)

	if failures.is_empty():
		print(
				"SCENE5_WIND_VALIDATION: PASS",
				" immediate=", immediate,
				" occluder_immediate=", occluder_immediate,
				" recovered=", recovered,
				" curve=", Vector3(curve_start, curve_early, curve_middle),
				" direction=", direction,
				" dual_direction=", dual_direction,
				" gust_amount=", gust_particles.amount)
		screen.queue_free()
		await process_frame
		quit(0)
		return

	for failure: String in failures:
		push_error("SCENE5_WIND_VALIDATION: %s" % failure)
	screen.queue_free()
	await process_frame
	quit(1)


func _wait_real_msec(duration_msec: int) -> void:
	var deadline := Time.get_ticks_msec() + duration_msec
	while Time.get_ticks_msec() < deadline:
		await process_frame
