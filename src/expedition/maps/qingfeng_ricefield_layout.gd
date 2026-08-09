## 晴风稻田固定地图灰盒。
## 这里只描述永久不变的地形和合法内容锚点；每局启用哪些对象由 MapState 决定。
extends RefCounted

const WIDTH: int = 18
const HEIGHT: int = 14
const START: Vector2i = Vector2i(9, 13)

enum GroundTerrain { GRASS, RICE, DIRT }

## 检修院后侧、旧收割场后侧。启用后从开局起常开，但不会越过迷雾主动标记。
const EXIT_CANDIDATES: Array[Vector2i] = [Vector2i(3, 1), Vector2i(15, 1)]
const REPAIR_GUARD_ANCHOR: Vector2i = Vector2i(3, 2)
const BOSS_ANCHOR: Vector2i = Vector2i(15, 2)

## 灰盒敌人锚点；具体敌人、队伍与最终数量以后按子区域单独设计。
const MONSTER_ANCHORS: Array[Vector2i] = [
	Vector2i(5, 11), Vector2i(12, 11),
	Vector2i(4, 9), Vector2i(10, 9),
	Vector2i(3, 5), Vector2i(9, 5), Vector2i(14, 5),
	Vector2i(3, 2), Vector2i(15, 2),
]

## 灰盒搜索锚点；当前仍沿用旧宝箱交互，仅用于验证路线密度。
const SEARCH_ANCHORS: Array[Vector2i] = [
	Vector2i(2, 11), Vector2i(15, 11),
	Vector2i(6, 9), Vector2i(13, 9),
	Vector2i(3, 7), Vector2i(11, 7),
	Vector2i(5, 3), Vector2i(14, 3),
]

## # = 不可通行边界/大型建筑，. = 可通行格，S = 南部田口。
## 上方两块院落分别形成检修院与收割场；中部横向开口维持三条可互换路线。
const TERRAIN_ROWS: Array[String] = [
	"##################",
	"#.....#....#.....#",
	"#.....#....#.....#",
	"#..........#.....#",
	"###.###..........#",
	"#................#",
	"#....####..####..#",
	"#................#",
	"#..##....##....#.#",
	"#................#",
	"#....##....##....#",
	"#................#",
	"#................#",
	"#########S########",
]

## 地表只决定最底层纹理，不改变通行、敌人或交互规则。
## 每一格（包括墙格与入口格）都必须明确为 g=草地、r=稻田或 d=土路；
## 不可通行田界和搜索目标由独立物体层根据 TERRAIN_ROWS / 运行状态覆盖。
const GROUND_ROWS: Array[String] = [
	"gggggggggggggggggg",
	"grrrrrgddddgrrrrrg",
	"grrrrrgdggdgrrrrrg",
	"grrrggddggggrrrrrg",
	"gggdgggddddddddddg",
	"gggggddddddddggggg",
	"grrrrggggddggggggg",
	"grrrrggddddggrrrrg",
	"gddggrrrrggrrrrgdg",
	"gddddddddddddddddg",
	"gggggggddddggggggg",
	"grrrrggddddggrrrrg",
	"gggggggddddggggggg",
	"gggggggggggggggggg",
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
