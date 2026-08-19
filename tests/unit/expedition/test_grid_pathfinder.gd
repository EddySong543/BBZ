extends GutTest

const GridPathfinderScript := preload("res://src/expedition/grid_pathfinder.gd")


func test_finds_shortest_cardinal_path_around_walls() -> void:
	var walls: Dictionary = {
		Vector2i(1, 0): true,
		Vector2i(1, 1): true,
	}
	var path: Array[Vector2i] = GridPathfinderScript.find_path(
			Vector2i(0, 0), Vector2i(2, 0), Rect2i(0, 0, 4, 4),
			func(cell: Vector2i) -> bool: return not walls.has(cell))
	assert_eq(path, [
		Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2),
		Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0),
	])


func test_returns_empty_path_when_goal_is_blocked_or_outside_bounds() -> void:
	var blocked: Array[Vector2i] = GridPathfinderScript.find_path(
			Vector2i.ZERO, Vector2i.RIGHT, Rect2i(0, 0, 3, 3),
			func(cell: Vector2i) -> bool: return cell != Vector2i.RIGHT)
	var outside: Array[Vector2i] = GridPathfinderScript.find_path(
			Vector2i.ZERO, Vector2i(-1, 0), Rect2i(0, 0, 3, 3),
			func(_cell: Vector2i) -> bool: return true)
	assert_true(blocked.is_empty())
	assert_true(outside.is_empty())
