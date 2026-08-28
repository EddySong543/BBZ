extends SceneTree

const SCENE7 := preload("res://src/ui/scenes/scene7.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var stage := SCENE7.instantiate() as BattleStage
	root.add_child(stage)
	await process_frame
	stage.process_mode = Node.PROCESS_MODE_DISABLED
	var tortoise := stage.get_node("CrystalTortoise") as Node2D
	tortoise.call("set_random_seed_for_test", 74821)
	tortoise.call("start_visit")
	for _step: int in range(50):
		if bool(tortoise.call("is_looking")):
			break
		tortoise.call("_process", 0.05)

	var head_size := tortoise.call("head_pixel_size") as Vector2
	var glow_cells := int(tortoise.call("contour_glow_cell_count"))
	var shadow_cells := int(tortoise.call("contact_shadow_cell_count"))
	var glow_first := float(tortoise.call("current_glow_alpha"))
	tortoise.call("_process", PI / (2.0 * 1.8))
	var glow_peak := float(tortoise.call("current_glow_alpha"))
	var passed := head_size.x <= 32.0 and head_size.y <= 20.0 \
			and glow_cells >= 10 and glow_cells <= 24 \
			and shadow_cells >= 16 \
			and float(tortoise.call("contact_shadow_height_px")) <= 12.0 \
			and not bool(tortoise.call("contact_shadow_rotates_with_shell")) \
			and glow_peak - glow_first >= 0.035 \
			and bool(tortoise.call("is_looking"))
	print("SCENE7_CRYSTAL_TORTOISE_ART: ", "PASS" if passed else "FAIL",
			" head=", head_size,
			" contour_glow_cells=", glow_cells,
			" shadow_cells=", shadow_cells,
			" shadow_height=", tortoise.call("contact_shadow_height_px"),
			" glow_alpha=", Vector2(glow_first, glow_peak),
			" shadow_rotates=", tortoise.call("contact_shadow_rotates_with_shell"))
	quit(0 if passed else 1)
