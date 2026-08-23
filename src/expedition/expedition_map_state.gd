## 远征模式 — 地图探索状态（纯逻辑·无 UI·可单元测试）。规则源：design/expedition-map.md。
##
## 晴风稻田只生成已确认的固定地形、撤离点与搜索目标；正式敌人设计完成前不生成敌人。
## Tile.MONSTER 与 inject/resolve/apply 接口保留为通用遭遇边界，不绑定具体敌人、策略或掉落表。
##
## 用法示例：
##   const MapState := preload("res://src/expedition/expedition_map_state.gd")
##   var m: MapState = MapState.new(); m.setup(777)
##   var res: Dictionary = m.try_move(Vector2i.RIGHT)   # res.kind: move|wall|monster|event|chest|ext
extends RefCounted

const Loot := preload("res://src/expedition/expedition_loot.gd")
const QingfengLayout := preload("res://src/expedition/maps/qingfeng_ricefield_layout.gd")
const FogReveal := preload("res://src/expedition/expedition_fog_reveal.gd")

# ── 调优旋钮（子文档 B §9）──
const WIDTH: int = QingfengLayout.WIDTH
const HEIGHT: int = QingfengLayout.HEIGHT
const PLAYER_VISION_RADIUS: int = FogReveal.HORIZONTAL_RADIUS # 兼容旧调用名。
const PLAYER_VISION_HALF_WIDTH: int = FogReveal.HORIZONTAL_RADIUS
const PLAYER_VISION_HALF_HEIGHT: int = FogReveal.VERTICAL_RADIUS

enum Tile { FLOOR, WALL, START, EXT1, EXT2, EXT3, MONSTER, EVENT, CHEST }

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var grid: Array = []                # grid[y][x] = Tile
var revealed: Dictionary = {}       # Vector2i -> true（永久探索记录，供未来地图/任务使用）
var visible: Dictionary = {}        # Vector2i -> true（兼容旧接口；与revealed一样累计清雾）
var player: Vector2i
var start_pos: Vector2i
var ext_pos: Dictionary = {}        # Tile.EXT1.. -> Vector2i
var monsters: Dictionary = {}       # Vector2i -> 通用遭遇 Dictionary（允许 opponents:Array）
var events: Dictionary = {}         # Vector2i -> 事件名（一次性·行商回访例外）
var chests: Dictionary = {}         # Vector2i -> {revealed_by_map,egg}
var steps: int = 0
## 队伍（1 开局 → 篝火招募至 3）：[{hero_id, name, hp, hp_max}]
var team: Array = []
var battles_won: int = 0
var over: bool = false
var result: Dictionary = {}         # {outcome:extract|death, cause, steps, battles}

const EVENT_POOL: Array = ["篝火", "岔路赌局", "清泉", "行商", "陷阱", "神龛", "藏宝图", "修补匠", "兽踪"]
const INITIAL_TEAM_PLACEHOLDER := {
	"hero_id": "",
	"name": "待选英雄",
	"hp": 1.0,
	"hp_max": 1.0,
}


## 初始化一局（同种子同图·可复现）。
func setup(p_seed: int) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	revealed.clear()
	visible.clear()
	ext_pos.clear()
	monsters.clear()
	events.clear()
	chests.clear()
	steps = 0
	battles_won = 0
	over = false
	result = {}
	team = [INITIAL_TEAM_PLACEHOLDER.duplicate(true)]
	_generate()
	_reveal_around(player)


## 本局启用的撤离点始终开放；是否已经被玩家发现只由 revealed 决定。
func ext_open(tile: int) -> bool:
	return ext_pos.has(tile)


## 尝试移动一步。返回 {moved:bool, kind:String, msgs:Array}。
## kind: wall|move|monster|event|chest|ext|over。
func try_move(dir: Vector2i) -> Dictionary:
	if over:
		return {"moved": false, "kind": "over", "msgs": []}
	var target: Vector2i = player + dir
	if target.x < 0 or target.y < 0 or target.x >= WIDTH or target.y >= HEIGHT:
		return {"moved": false, "kind": "wall", "msgs": []}
	if grid[target.y][target.x] == Tile.WALL:
		return {"moved": false, "kind": "wall", "msgs": []}
	steps += 1
	player = target
	_reveal_around(player)
	var out := {"moved": true, "kind": "move", "msgs": []}
	match grid[target.y][target.x]:
		Tile.MONSTER: out["kind"] = "monster"
		Tile.EVENT: out["kind"] = "event"
		Tile.CHEST: out["kind"] = "chest"
		Tile.EXT1, Tile.EXT2, Tile.EXT3: out["kind"] = "ext"
	return out


## 手工注入一个正式遭遇。正常晴风生成不会调用此接口。
## encounter 由敌人设计层拥有，可携带 opponents:Array、loot:Array 与任意区域规则数据。
func inject_encounter(c: Vector2i, encounter: Dictionary) -> bool:
	if c.x < 0 or c.y < 0 or c.x >= WIDTH or c.y >= HEIGHT:
		return false
	if grid[c.y][c.x] == Tile.WALL or encounter.is_empty():
		return false
	monsters[c] = encounter.duplicate(true)
	grid[c.y][c.x] = Tile.MONSTER
	return true


## 返回已注入的遭遇；没有遭遇时返回空字典，不进行旧版危险度强化或随机替换。
func resolve_encounter(c: Vector2i) -> Dictionary:
	return monsters.get(c, {})


## 开宝箱：格子转空地，返回掉落（兽踪蛋附加）。
func open_chest(c: Vector2i) -> Array:
	var loot: Array = prepare_chest_contents(c)
	deplete_chest(c)
	return loot


## 首次打开时一次性生成并固定内容；中断、重开或跨战斗恢复均不得重掷。
## 返回深拷快照，容器系统不能反向污染地图真相源。
func prepare_chest_contents(c: Vector2i) -> Array:
	if not chests.has(c):
		return []
	var chest: Dictionary = chests[c]
	if not chest.has("contents"):
		var generated: Array = Loot.roll_drop(rng, "chest")
		if bool(chest.get("egg", false)):
			generated.append({"id": "egg", "name": "宠物蛋", "cat": "rare", "tier": 0,
					"shape": Loot.SHAPE_2X2, "gold": 0, "note": "兽踪", "icon": "egg"})
		chest["contents"] = generated.duplicate(true)
		chests[c] = chest
	return (chest["contents"] as Array).duplicate(true)


## 容器中所有已揭示物品均被拿走后才移除地图对象；地表保持不变。
func deplete_chest(c: Vector2i) -> bool:
	if not chests.has(c):
		return false
	chests.erase(c)
	grid[c.y][c.x] = Tile.FLOOR
	return true


## 搜索/拾取等非移动地图行动的统一回合钩子。
## 后续敌人地图 AI 接入时从本入口推进敌人行动；基础行动本身不额外扣资源。
func advance_world_action(action: String) -> Dictionary:
	if over:
		return {"ok": false, "kind": "over", "action": action, "msgs": []}
	steps += 1
	return {"ok": true, "kind": action, "action": action, "msgs": []}


## 篝火招募：只接受带稳定 hero_id 的真实英雄快照，避免 PvE 再次生成白板角色。
func recruit(hero_entry: Dictionary = {}) -> String:
	if team.size() >= 3 or String(hero_entry.get("hero_id", "")).strip_edges().is_empty():
		return ""
	var hero_name: String = String(hero_entry.get("name", "")).strip_edges()
	var hp_max: float = maxf(1.0, float(hero_entry.get("hp_max", 1.0)))
	if hero_name.is_empty():
		return ""
	team.append({
		"hero_id": String(hero_entry["hero_id"]),
		"name": hero_name,
		"hp": clampf(float(hero_entry.get("hp", hp_max)), 0.0, hp_max),
		"hp_max": hp_max,
	})
	return hero_name


## 全队回复（不超上限·倒下者不吃）。
func heal_all(amount: float) -> void:
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + amount)


## 前排（首个存活英雄）回复。
func heal_front(amount: float) -> void:
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + amount)
			return


## 前排承受明确的地图伤害；仅具体事件调用，不形成通用随时间衰减。
func damage_front(amount: float, cause: String) -> void:
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			h["hp"] = maxf(0.0, float(h["hp"]) - amount)
			break
	if _team_dead():
		_die(cause)


## 藏宝图：探明一处未知宝箱，返回坐标（无则 (-1,-1)）。
func reveal_random_chest() -> Vector2i:
	for c: Vector2i in chests:
		if not bool(chests[c]["revealed_by_map"]):
			chests[c]["revealed_by_map"] = true
			revealed[c] = true
			visible[c] = true
			return c
	return Vector2i(-1, -1)


## 兽踪：标记距玩家最远的宝箱为蛋箱并探明，返回坐标（无则 (-1,-1)）。
func mark_egg_chest() -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = -1
	for c: Vector2i in chests:
		var d: int = absi(c.x - player.x) + absi(c.y - player.y)
		if d > best_d:
			best_d = d
			best = c
	if best != Vector2i(-1, -1):
		chests[best]["egg"] = true
		chests[best]["revealed_by_map"] = true
		revealed[best] = true
		visible[best] = true
	return best


# ── 通用真战斗交接（战斗结算在 battle_screen，此处只管地图状态回写）──

## outcome: win|lose|flee；team_hp/opponent_hp 均为 BattleCore 半点数组。
## 胜利奖励来自遭遇自身的 loot，不再读取旧版 T 级掉落表。
func apply_battle_result(c: Vector2i, outcome: String, _beats: int, team_hp: Array, opponent_hp: Array, back_to: Vector2i) -> Dictionary:
	# 回写对位：进战快照只含【存活者】（前排先死=死者是队列前缀）→ 按存活顺序回写。
	var idx: int = 0
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			if idx < team_hp.size():
				h["hp"] = float(int(team_hp[idx])) / 2.0
			idx += 1
	var out := {"loot": []}
	var encounter: Dictionary = monsters.get(c, {})
	if encounter.is_empty():
		return out
	match outcome:
		"win":
			battles_won += 1
			var encounter_loot: Variant = encounter.get("loot", [])
			if encounter_loot is Array:
				out["loot"] = (encounter_loot as Array).duplicate(true)
			monsters.erase(c)
			grid[c.y][c.x] = Tile.FLOOR
		"flee":
			_write_opponent_hp(encounter, opponent_hp)
			player = back_to
			_reveal_around(player)
		"lose":
			_write_opponent_hp(encounter, opponent_hp)
		_:
			push_warning("未知远征战斗结果：%s" % outcome)
	if _team_dead():
		_die("战死于 %s" % String(encounter.get("name", "敌人")))
	return out


func _write_opponent_hp(encounter: Dictionary, opponent_hp: Array) -> void:
	var opponents_value: Variant = encounter.get("opponents", [])
	if not opponents_value is Array:
		return
	var opponents: Array = opponents_value as Array
	var result_index: int = 0
	for opponent_value: Variant in opponents:
		if not opponent_value is Dictionary:
			continue
		var opponent: Dictionary = opponent_value as Dictionary
		if float(opponent.get("hp", 0.0)) <= 0.0:
			continue
		if result_index >= opponent_hp.size():
			break
		opponent["hp"] = float(int(opponent_hp[result_index])) / 2.0
		result_index += 1


## 撤离结算：终局并写 result（金币/货品由背包层负责）。
func extract() -> void:
	over = true
	result = {"outcome": "extract", "cause": "", "steps": steps, "battles": battles_won}


# ── 内部 ──


func _generate() -> void:
	grid = QingfengLayout.build_grid(Tile.WALL, Tile.FLOOR, Tile.START)
	start_pos = QingfengLayout.START
	player = start_pos
	if not QingfengLayout.CURRENT_DYNAMIC_CONTENT_ENABLED:
		return

	var exit_candidates: Array[Vector2i] = QingfengLayout.EXIT_CANDIDATES.duplicate()
	_shuffle_with_rng(exit_candidates)
	var exit_count: int = 1 + rng.randi_range(0, 1)
	for index: int in exit_count:
		var exit_tile: int = Tile.EXT1 + index
		var exit_cell: Vector2i = exit_candidates[index]
		grid[exit_cell.y][exit_cell.x] = exit_tile
		ext_pos[exit_tile] = exit_cell

	var search_anchors: Array[Vector2i] = QingfengLayout.SEARCH_ANCHORS.duplicate()
	_shuffle_with_rng(search_anchors)
	var search_count: int = mini(search_anchors.size(), 4 + rng.randi_range(0, 2))
	for index: int in search_count:
		var cell: Vector2i = search_anchors[index]
		grid[cell.y][cell.x] = Tile.CHEST
		chests[cell] = {"revealed_by_map": false, "egg": false}

func _bfs_dist(from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= WIDTH or n.y >= HEIGHT:
				continue
			if grid[n.y][n.x] == Tile.WALL or dist.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist


func _shuffle_with_rng(values: Array[Vector2i]) -> void:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var held: Vector2i = values[index]
		values[index] = values[swap_index]
		values[swap_index] = held


func _reveal_around(c: Vector2i) -> void:
	var footprint: Dictionary = FogReveal.compute_footprint(
			c, Rect2i(Vector2i.ZERO, Vector2i(WIDTH, HEIGHT)))
	for cell: Vector2i in footprint:
		revealed[cell] = true
		visible[cell] = true


## 兼容已有调用名；这里描述的是一次清雾印章，不是随身可见范围。
static func vision_contains_delta(delta: Vector2i) -> bool:
	return FogReveal.contains_delta(delta)


func _team_dead() -> bool:
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			return false
	return true


func _die(cause: String) -> void:
	over = true
	result = {"outcome": "death", "cause": cause, "steps": steps, "battles": battles_won}
