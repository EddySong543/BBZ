extends SceneTree

const SCENE6 := preload("res://src/ui/scenes/scene6.tscn")


func _initialize() -> void:
	call_deferred("_run_probe")


func _run_probe() -> void:
	var stage := SCENE6.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	await process_frame
	var secrets := stage.get_node("MagmaSecrets") as Scene6MagmaSecrets
	secrets.reveal_cooldown_sec = 0.0
	secrets.legend_roll_override = 1.0
	secrets.rise_duration_sec = 0.02
	secrets.float_duration_sec = 0.04
	secrets.sink_duration_sec = 0.15
	for _click: int in secrets.clicks_per_reveal:
		secrets.register_molten_click(Vector2(420.0, 936.0))
	await create_timer(0.24).timeout
	var ordinary_closed := secrets.active_secret_count() == 0 \
			and secrets.get_return_contact_ripple_count() == 1 \
			and secrets.get_closure_bubble_spawn_count() == 1 \
			and secrets.active_closure_bubble_count() == 1

	secrets.legendary_rise_duration_sec = 0.02
	secrets.legendary_float_duration_sec = 0.04
	secrets.legendary_sink_duration_sec = 0.15
	secrets.legendary_hover_clearance_px = 32.0
	secrets.legend_roll_override = 0.0
	for _click: int in secrets.clicks_per_reveal:
		secrets.register_molten_click(Vector2(1420.0, 936.0))
	await process_frame
	var pocket := secrets.get_node_or_null("LegendaryPocketRuntime") as Control
	var platform := stage.get_node("BattlePlatform")
	var ordinary_occlusion_layer := pocket != null and pocket.get_parent() == secrets \
			and pocket.z_index == 0 \
			and secrets.get_index() < platform.get_index()
	var pocket_z := pocket.z_index if pocket != null else -99
	var secrets_index := secrets.get_index()
	var platform_index := platform.get_index()
	await create_timer(0.24).timeout
	var legendary_closed := secrets.active_secret_count() == 0 \
			and secrets.get_return_contact_ripple_count() == 2 \
			and secrets.get_closure_bubble_spawn_count() == 2 \
			and secrets.active_closure_bubble_count() == 2
	var passed := ordinary_closed and ordinary_occlusion_layer \
			and legendary_closed
	print("SCENE6_SECRET_LAYER_PROBE: ", "PASS" if passed else "FAIL",
			" ordinary_closed=", ordinary_closed,
			" ordinary_occlusion_layer=", ordinary_occlusion_layer,
			" pocket_z=", pocket_z,
			" secrets_index=", secrets_index,
			" platform_index=", platform_index,
			" return_contacts=", secrets.get_return_contact_ripple_count(),
			" closure_bubbles=", secrets.get_closure_bubble_spawn_count(),
			" legendary_closed=", legendary_closed)
	stage.queue_free()
	await process_frame
	quit(0 if passed else 1)
