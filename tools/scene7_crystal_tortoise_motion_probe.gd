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
	var entered_from_left := bool(tortoise.call("entered_from_left"))
	var entry_start := tortoise.call("visual_position") as Vector2

	tortoise.call("_process", 0.25)
	var rolling_first := tortoise.call("visual_position") as Vector2
	var first_rotation := float(tortoise.call("shell_rotation"))
	var first_ground_gap := float(tortoise.call("rolling_ground_gap_px"))
	tortoise.call("_process", 0.16)
	var rolling_second := tortoise.call("visual_position") as Vector2
	var second_rotation := float(tortoise.call("shell_rotation"))
	var second_ground_gap := float(tortoise.call("rolling_ground_gap_px"))

	for _step: int in range(40):
		if bool(tortoise.call("is_looking")):
			break
		tortoise.call("_process", 0.05)
	var reached_looking := bool(tortoise.call("is_looking"))
	var stop_position := tortoise.call("visual_position") as Vector2
	var first_look_direction := int(tortoise.call("look_direction"))
	tortoise.call("_process", float(tortoise.get("look_interval_sec")) + 0.05)
	var second_look_direction := int(tortoise.call("look_direction"))

	tortoise.call("request_exit", true)
	var exit_start := tortoise.call("visual_position") as Vector2
	tortoise.call("_process", 0.35)
	var rolling_out := tortoise.call("visual_position") as Vector2
	var exit_moves_to_entry_edge := rolling_out.x < exit_start.x \
			if entered_from_left else rolling_out.x > exit_start.x

	var passed := (entry_start.x < -32.0 or entry_start.x > 1952.0) \
			and entry_start.distance_to(rolling_first) >= 180.0 \
			and rolling_first.distance_to(rolling_second) >= 80.0 \
			and not is_equal_approx(first_rotation, second_rotation) \
			and absf(first_ground_gap) <= 0.01 \
			and absf(second_ground_gap) <= 0.01 \
			and reached_looking \
			and stop_position.x >= 800.0 and stop_position.x <= 1120.0 \
			and stop_position.y >= 760.0 and stop_position.y <= 788.0 \
			and first_look_direction != second_look_direction \
			and exit_start.distance_to(rolling_out) >= 40.0 \
			and exit_moves_to_entry_edge \
			and bool(tortoise.call("is_rolling_out"))
	print("SCENE7_CRYSTAL_TORTOISE_MOTION: ", "PASS" if passed else "FAIL",
			" side=", "left" if entered_from_left else "right",
			" entry_start=", entry_start,
			" rolling_delta=", rolling_first.distance_to(rolling_second),
			" rotations=", Vector2(first_rotation, second_rotation),
			" ground_gaps=", Vector2(first_ground_gap, second_ground_gap),
			" stop=", stop_position,
			" looks=", Vector2i(first_look_direction, second_look_direction),
			" exit_delta=", exit_start.distance_to(rolling_out))
	quit(0 if passed else 1)
