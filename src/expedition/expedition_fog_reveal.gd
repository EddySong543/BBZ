## 远征地图迷雾的纯逻辑清除笔刷。
##
## 它记录角色实际探索过的地图范围，不表达角色当前视力。调用方把每次
## compute/add得到的格子永久并入 revealed，角色走远后不得重新覆盖。
extends RefCounted

const HORIZONTAL_RADIUS: int = 2
const VERTICAL_RADIUS: int = 2
const CORNER_DISTANCE_LIMIT: int = 3


static func compute_footprint(origin: Vector2i, bounds: Rect2i) -> Dictionary:
	var result: Dictionary = {}
	add_footprint(result, origin, bounds)
	return result


static func add_footprint(target: Dictionary, origin: Vector2i, bounds: Rect2i) -> void:
	if not bounds.has_point(origin):
		return
	for dy: int in range(-VERTICAL_RADIUS, VERTICAL_RADIUS + 1):
		for dx: int in range(-HORIZONTAL_RADIUS, HORIZONTAL_RADIUS + 1):
			var delta := Vector2i(dx, dy)
			if not contains_delta(delta):
				continue
			var cell: Vector2i = origin + delta
			if bounds.has_point(cell):
				target[cell] = true


## 5x5整格印章，裁掉四个2x2角；相邻脚印自然连接成连续探索路径。
static func contains_delta(delta: Vector2i) -> bool:
	return absi(delta.x) <= HORIZONTAL_RADIUS \
			and absi(delta.y) <= VERTICAL_RADIUS \
			and absi(delta.x) + absi(delta.y) <= CORNER_DISTANCE_LIMIT
