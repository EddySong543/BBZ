extends SceneTree

## 无截图验收：验证远征左键选格会经过地图状态逐格移动。

const HeroDataScript := preload("res://src/battle/hero_data.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://src/expedition/expedition_screen.tscn") as PackedScene
	if packed == null:
		_fail("scene load failed")
		return
	var screen := packed.instantiate()
	root.add_child(screen)
	await process_frame
	screen._on_hero_selected(HeroDataScript.create_launch_pool()[0])
	await process_frame

	var start: Vector2i = screen.map.player
	var target := Vector2i(-1, -1)
	for direction: Vector2i in [Vector2i.UP, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.DOWN]:
		if screen._is_walkable_map_cell(start + direction):
			target = start + direction
			break
	if target == Vector2i(-1, -1):
		_fail("no walkable neighbor at start")
		return
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = screen._map_view_position_for_cell(target)
	if screen._cell_from_map_view_position(click.position) != target:
		_fail("view-to-cell conversion mismatch")
		return
	screen._on_map_view_gui_input(click)
	var movement_deadline: int = Time.get_ticks_msec() + 3000
	while (screen.map.player != target or screen._click_route_active) \
			and Time.get_ticks_msec() < movement_deadline:
		await process_frame
	if screen.map.player != target or screen.map.steps != 1:
		_fail("click route did not use one map step")
		return
	print("EXPEDITION_CLICK_MOVE_PROBE_OK ", JSON.stringify({
		"start": start,
		"target": target,
		"steps": screen.map.steps,
		"camera_settled": not screen._camera_is_moving(),
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error("EXPEDITION_CLICK_MOVE_PROBE: %s" % message)
	quit(1)
