## 晴风稻田固定地图灰盒。
## 这里只描述永久不变的地形和合法内容锚点；每局启用哪些对象由 MapState 决定。
extends RefCounted

const WIDTH: int = 32
const HEIGHT: int = 18
const START: Vector2i = Vector2i(16, 17)

enum GroundTerrain { GRASS, RICE, DIRT }

## 以下锚点只为后续恢复地图内容时保留；当前纯地表版本不生成对应对象。
const CURRENT_DYNAMIC_CONTENT_ENABLED: bool = false
const EXIT_CANDIDATES: Array[Vector2i] = [Vector2i(5, 1), Vector2i(26, 1)]
const REPAIR_GUARD_ANCHOR: Vector2i = Vector2i(3, 2)
const BOSS_ANCHOR: Vector2i = Vector2i(28, 2)

## 灰盒敌人锚点；具体敌人、队伍与最终数量以后按子区域单独设计。
const MONSTER_ANCHORS: Array[Vector2i] = [
	Vector2i(6, 15), Vector2i(25, 15),
	Vector2i(8, 11), Vector2i(23, 11),
	Vector2i(5, 7), Vector2i(16, 7), Vector2i(27, 7),
	REPAIR_GUARD_ANCHOR, BOSS_ANCHOR,
]

## 灰盒搜索锚点；当前仍沿用旧宝箱交互，仅用于验证路线密度。
const SEARCH_ANCHORS: Array[Vector2i] = [
	Vector2i(3, 15), Vector2i(28, 15),
	Vector2i(9, 12), Vector2i(22, 12),
	Vector2i(4, 8), Vector2i(27, 8),
	Vector2i(8, 3), Vector2i(23, 3),
]

## 当前构图只保留可通行方格：. = 可通行格，S = 南部田口。
## 墙、田界、容器、敌人和不可见碰撞全部暂时移出正式地图。
const TERRAIN_ROWS: Array[String] = [
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................................",
	"................S...............",
]

## 地表只决定最底层纹理，不改变通行、敌人或交互规则。
## 每一格都明确为 g=草地、r=金色麦浪或 d=黄土路。
## 两格宽南北主路串起三条横路；大块麦田由草地缓冲带分区，避免碎片化。
const GROUND_ROWS: Array[String] = [
	"gggggggggggggggggggggggggggggggg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"ggggddddddddddddddddddddddddgggg",
	"gggggggggggggggddggggggggggggggg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"ggddddddddddddddddddddddddddddgg",
	"gggggggggggggggddggggggggggggggg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"ggggddddddddddddddddddddddddgggg",
	"gggggggggggggggddggggggggggggggg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"grrrrrrrrrrrrrgddgrrrrrrrrrrrrrg",
	"gggggggggggggggddggggggggggggggg",
]


static func ground_terrain_at(cell: Vector2i) -> int:
	match GROUND_ROWS[cell.y][cell.x]:
		"r":
			return GroundTerrain.RICE
		"d":
			return GroundTerrain.DIRT
		_:
			return GroundTerrain.GRASS


static func build_grid(wall_tile: int, floor_tile: int, start_tile: int) -> Array:
	var grid: Array = []
	for row_text: String in TERRAIN_ROWS:
		var row: Array = []
		for x: int in WIDTH:
			match row_text[x]:
				"#":
					row.append(wall_tile)
				"S":
					row.append(start_tile)
				_:
					row.append(floor_tile)
		grid.append(row)
	return grid
