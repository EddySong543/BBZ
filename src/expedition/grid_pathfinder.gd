class_name GridPathfinder
extends RefCounted

## 等权四方向格子最短路。返回的路径不包含起点，包含终点。

const CARDINAL_DIRECTIONS: Array[Vector2i] = [
	Vector2i.UP,
	Vector2i.LEFT,
	Vector2i.RIGHT,
	Vector2i.DOWN,
]


static func find_path(start: Vector2i, goal: Vector2i, bounds: Rect2i,
		can_enter: Callable) -> Array[Vector2i]:
	var empty_path: Array[Vector2i] = []
	if start == goal:
		return empty_path
	if not bounds.has_point(start) or not bounds.has_point(goal):
		return empty_path
	if not bool(can_enter.call(goal)):
		return empty_path

	var frontier: Array[Vector2i] = [start]
	var frontier_index: int = 0
	var came_from: Dictionary = {start: start}
	while frontier_index < frontier.size():
		var current: Vector2i = frontier[frontier_index]
		frontier_index += 1
		for direction: Vector2i in CARDINAL_DIRECTIONS:
			var neighbor: Vector2i = current + direction
			if not bounds.has_point(neighbor) or came_from.has(neighbor):
				continue
			if not bool(can_enter.call(neighbor)):
				continue
			came_from[neighbor] = current
			if neighbor == goal:
				return _reconstruct_path(start, goal, came_from)
			frontier.append(neighbor)
	return empty_path


static func _reconstruct_path(start: Vector2i, goal: Vector2i,
		came_from: Dictionary) -> Array[Vector2i]:
	var reversed_path: Array[Vector2i] = []
	var cursor: Vector2i = goal
	while cursor != start:
		reversed_path.append(cursor)
		cursor = Vector2i(came_from[cursor])
	reversed_path.reverse()
	return reversed_path
