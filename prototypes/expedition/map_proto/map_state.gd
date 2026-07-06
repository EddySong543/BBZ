## 地图探索逻辑层（无 UI·可 headless 自检）——子文档 B 规则
## 原型代码·可丢弃。战斗=占位自动结算（先知效率 0.7-0.9 伤/拍·README 有说明）。
extends RefCounted

const LootGen := preload("res://prototypes/expedition/loot_gen.gd")

const SIZE: int = 12
const WALL_RATE: float = 0.2
const S0: int = 40                  # 初始补给
const HUNGER_DMG: float = 0.5       # 补给 0 后每步全队各扣
const D_DIVISOR: float = 30.0
const D_CAP: int = 5
const HP_SCALE_PER_D: float = 0.15
const EXT1_CLOSE: float = 60.0
const EXT2_OPEN: float = 30.0
const EXT2_CLOSE: float = 90.0
const MONSTER_COUNT: int = 12
const EVENT_COUNT: int = 7
const CHEST_COUNT: int = 6
const SOLVE_EFF_MIN: float = 0.7    # 先知拆解效率带（原型研究发现）
const SOLVE_EFF_MAX: float = 0.9

enum Tile { FLOOR, WALL, START, EXT1, EXT2, EXT3, MONSTER, EVENT, CHEST }

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var grid: Array = []                # grid[y][x] = Tile
var revealed: Dictionary = {}       # Vector2i -> true（永久探明）
var player: Vector2i
var start_pos: Vector2i
var ext_pos: Dictionary = {}        # Tile.EXT1.. -> Vector2i
var monsters: Dictionary = {}       # Vector2i -> {key,name,tier,hp,hp_max,resolved:bool}
var events: Dictionary = {}         # Vector2i -> 事件名（触发即删·行商回访保留）
var chests: Dictionary = {}         # Vector2i -> {revealed_by_map:bool, egg:bool}
var wanderer: Vector2i = Vector2i(-1, -1)   # D=5 游荡怪·(-1,-1)=未出
## 资源与时钟
var supplies: int = S0
var steps: int = 0
var battle_beats: float = 0.0
var gold: int = 0
var rations: int = 0
var potions: int = 0
var combat_items: int = 0           # 战斗道具占位计数（背包拼图在 B 原型）
var rare_names: Array = []
## 队伍（1 开局 → 招募至 3）：[{name, hp, hp_max}]
var team: Array = []
var battles_won: int = 0
var over: bool = false              # 死亡或已撤离
var result: Dictionary = {}         # 结算数据
var monster_defs: Array = []        # 按 tier 分桶前的全量 JSON

const EVENT_POOL: Array = ["篝火", "岔路赌局", "清泉", "行商", "陷阱", "神龛", "藏宝图", "巢穴", "修补匠", "兽踪"]
const HERO_NAMES: Array = ["先锋·占位", "游侠·占位", "术士·占位", "斥候·占位"]

func setup(p_seed: int) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	team = [{"name": HERO_NAMES[0], "hp": 5.0, "hp_max": 5.0}]
	_load_monster_defs()
	_generate()
	_reveal_around(player)

func _load_monster_defs() -> void:
	monster_defs = []
	var txt: String = FileAccess.get_file_as_string("res://prototypes/expedition/expedition_monsters.json")
	var data: Variant = JSON.parse_string(txt)
	if data is Dictionary:
		for key: String in data:
			var m: Dictionary = data[key]
			monster_defs.append({"key": key, "name": String(m["name"]), "tier": int(m["tier"]), "hp": int(m["hp"])})

func _pick_monster(tier: int) -> Dictionary:
	var pool: Array = monster_defs.filter(func(m: Dictionary) -> bool: return int(m["tier"]) == tier)
	if pool.is_empty():
		return {"key": "?", "name": "怪·占位", "tier": tier, "hp": tier * 6}
	return pool[rng.randi_range(0, pool.size() - 1)]

func _generate() -> void:
	# 1) 地形：随机墙 → BFS 从起点·不可达格全转墙（保证连通）
	grid = []
	for y: int in SIZE:
		var row: Array = []
		for x: int in SIZE:
			row.append(Tile.WALL if rng.randf() < WALL_RATE else Tile.FLOOR)
		grid.append(row)
	start_pos = Vector2i(0, SIZE / 2)
	grid[start_pos.y][start_pos.x] = Tile.START
	player = start_pos
	var dist := _bfs_dist(start_pos)
	for y: int in SIZE:
		for x: int in SIZE:
			var c := Vector2i(x, y)
			if grid[y][x] != Tile.WALL and not dist.has(c):
				grid[y][x] = Tile.WALL
	# 2) 撤离点：近(2-5)/中(7-12)/深(最远带)
	var cells_by_dist: Array = dist.keys()
	cells_by_dist.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(dist[a]) < int(dist[b]))
	_place_ext(Tile.EXT1, dist, 2, 5, cells_by_dist)
	_place_ext(Tile.EXT2, dist, 7, 12, cells_by_dist)
	var deepest: Vector2i = cells_by_dist[cells_by_dist.size() - 1]
	grid[deepest.y][deepest.x] = Tile.EXT3
	ext_pos[Tile.EXT3] = deepest
	# 3) 怪物（近 T1 / 中偏 T2 / 深 T2-T3）、事件、宝箱
	var free: Array = dist.keys().filter(func(c: Vector2i) -> bool: return grid[c.y][c.x] == Tile.FLOOR and int(dist[c]) >= 2)
	# 种子化洗牌（Fisher-Yates·保证同种子同图）
	for i: int in range(free.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = free[i]
		free[i] = free[j]
		free[j] = tmp
	var max_d: int = int(dist[deepest])
	for i: int in MONSTER_COUNT:
		if free.is_empty():
			break
		var c: Vector2i = free.pop_back()
		var band: float = float(dist[c]) / float(maxi(1, max_d))
		var tier: int = 1
		if band > 0.66:
			tier = 3 if rng.randf() < 0.35 else 2
		elif band > 0.33:
			tier = 2 if rng.randf() < 0.5 else 1
		var def: Dictionary = _pick_monster(tier)
		grid[c.y][c.x] = Tile.MONSTER
		monsters[c] = {"key": def["key"], "name": def["name"], "tier": tier, "hp": float(def["hp"]), "hp_max": float(def["hp"]), "resolved": false}
	for i: int in EVENT_COUNT:
		if free.is_empty():
			break
		var c: Vector2i = free.pop_back()
		grid[c.y][c.x] = Tile.EVENT
		events[c] = EVENT_POOL[rng.randi_range(0, EVENT_POOL.size() - 1)]
	for i: int in CHEST_COUNT:
		if free.is_empty():
			break
		var c: Vector2i = free.pop_back()
		grid[c.y][c.x] = Tile.CHEST
		chests[c] = {"revealed_by_map": false, "egg": false}

func _place_ext(tile: int, dist: Dictionary, d_min: int, d_max: int, sorted_cells: Array) -> void:
	var band: Array = sorted_cells.filter(func(c: Vector2i) -> bool:
		return int(dist[c]) >= d_min and int(dist[c]) <= d_max and grid[c.y][c.x] == Tile.FLOOR)
	var c: Vector2i
	if band.is_empty():
		c = sorted_cells[mini(sorted_cells.size() - 1, d_min * 2)]
	else:
		c = band[rng.randi_range(0, band.size() - 1)]
	grid[c.y][c.x] = tile
	ext_pos[tile] = c

func _bfs_dist(from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= SIZE or n.y >= SIZE:
				continue
			if grid[n.y][n.x] == Tile.WALL or dist.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist

# ---------- 时钟与压力源 ----------

func ticks() -> float:
	return float(steps) + battle_beats * 0.5

func danger() -> int:
	return mini(D_CAP, int(floor(ticks() / D_DIVISOR)))

func ext_open(tile: int) -> bool:
	match tile:
		Tile.EXT1: return ticks() < EXT1_CLOSE
		Tile.EXT2: return ticks() >= EXT2_OPEN and ticks() < EXT2_CLOSE
		Tile.EXT3: return true
	return false

func _reveal_around(c: Vector2i) -> void:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE:
				revealed[n] = true

## 尝试移动。返回事件描述 Dictionary：{moved, kind, ...}（kind: wall|move|monster|event|chest|ext|wanderer）
func try_move(dir: Vector2i) -> Dictionary:
	if over:
		return {"moved": false, "kind": "over"}
	var target: Vector2i = player + dir
	if target.x < 0 or target.y < 0 or target.x >= SIZE or target.y >= SIZE:
		return {"moved": false, "kind": "wall"}
	if grid[target.y][target.x] == Tile.WALL:
		return {"moved": false, "kind": "wall"}
	# 走一步的代价先结（走上格子才触发内容）
	steps += 1
	supplies -= 1
	var hunger_msgs: Array = []
	if supplies < 0:
		supplies = 0 if supplies == -1 else supplies  # 首次归 0 不再负数化显示
		supplies = maxi(supplies, 0)
		for h: Dictionary in team:
			if float(h["hp"]) > 0.0:
				h["hp"] = float(h["hp"]) - HUNGER_DMG
		hunger_msgs.append("饥饿行军：全队 -%.1f HP" % HUNGER_DMG)
		if _team_dead():
			_die("饿死在途中")
			return {"moved": true, "kind": "death", "msgs": hunger_msgs}
	player = target
	_reveal_around(player)
	var out := {"moved": true, "kind": "move", "msgs": hunger_msgs}
	# 游荡怪逼近（D=5 出没）
	_wanderer_tick()
	if wanderer == player:
		out["kind"] = "wanderer"
		return out
	match grid[target.y][target.x]:
		Tile.MONSTER: out["kind"] = "monster"
		Tile.EVENT: out["kind"] = "event"
		Tile.CHEST: out["kind"] = "chest"
		Tile.EXT1, Tile.EXT2, Tile.EXT3: out["kind"] = "ext"
	return out

func _wanderer_tick() -> void:
	if danger() >= D_CAP and wanderer == Vector2i(-1, -1):
		wanderer = Vector2i(ext_pos[Tile.EXT3])
	if wanderer == Vector2i(-1, -1) or wanderer == player:
		return
	# 贪心走向玩家（撞墙则试另一轴·再不行原地）
	var diff: Vector2i = player - wanderer
	var options: Array = []
	if absi(diff.x) >= absi(diff.y):
		options = [Vector2i(signi(diff.x), 0), Vector2i(0, signi(diff.y))]
	else:
		options = [Vector2i(0, signi(diff.y)), Vector2i(signi(diff.x), 0)]
	for d: Vector2i in options:
		if d == Vector2i.ZERO:
			continue
		var n: Vector2i = wanderer + d
		if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE and grid[n.y][n.x] != Tile.WALL:
			wanderer = n
			return

# ---------- 战斗占位 ----------

## 遭遇结算尺（不回溯）：首次遭遇时按当时 D 强化 HP、并处理 D≥3 的 T1→T2 替换
func resolve_encounter(c: Vector2i) -> Dictionary:
	var m: Dictionary = monsters[c]
	if not bool(m["resolved"]):
		var d: int = danger()
		if d >= 3 and int(m["tier"]) == 1 and rng.randf() < 0.4:
			var up: Dictionary = _pick_monster(2)
			m["key"] = up["key"]
			m["name"] = String(up["name"]) + "(替)"
			m["tier"] = 2
			m["hp"] = float(up["hp"])
			m["hp_max"] = float(up["hp"])
		var scaled: float = ceilf(float(m["hp_max"]) * (1.0 + HP_SCALE_PER_D * float(d)))
		m["hp"] = scaled
		m["hp_max"] = scaled
		m["resolved"] = true
	return m

## 自动战斗（先知效率占位模型）。返回战报。
func fight(c: Vector2i) -> Dictionary:
	var m: Dictionary = resolve_encounter(c)
	var eff: float = rng.randf_range(SOLVE_EFF_MIN, SOLVE_EFF_MAX)
	var beats: int = int(ceilf(float(m["hp"]) / eff))
	battle_beats += float(beats)
	# 受伤占位：按 tier 带·0.5 步进
	var dmg_bands: Dictionary = {1: [0.0, 1.0], 2: [1.0, 2.5], 3: [2.5, 4.5]}
	var band: Array = dmg_bands[int(m["tier"])]
	var dmg: float = snappedf(rng.randf_range(float(band[0]), float(band[1])), 0.5)
	_apply_team_damage(dmg)
	var report := {"name": m["name"], "tier": int(m["tier"]), "beats": beats, "dmg": dmg, "loot": []}
	if _team_dead():
		_die("战死于 %s" % String(m["name"]))
		report["death"] = true
		return report
	battles_won += 1
	monsters.erase(c)
	grid[c.y][c.x] = Tile.FLOOR
	if wanderer == c:
		wanderer = Vector2i(-1, -1)
	var loot: Array = LootGen.roll_drop(rng, "t%d" % int(m["tier"]))
	for it: Dictionary in loot:
		_gain_item(it)
	report["loot"] = loot
	return report

## 逃跑：敌方免费命中一拍（占位=0.5×tier）·退回原格·怪保留血量
func flee(c: Vector2i, back_to: Vector2i) -> Dictionary:
	var m: Dictionary = resolve_encounter(c)
	var dmg: float = 0.5 * float(m["tier"])
	_apply_team_damage(dmg)
	battle_beats += 1.0
	player = back_to
	var report := {"name": m["name"], "dmg": dmg}
	if _team_dead():
		_die("逃跑时被 %s 击倒" % String(m["name"]))
		report["death"] = true
	return report

## 游荡怪强制遭遇（不可拒绝·战斗中可逃=原型简化为同一逃跑模型）
func fight_wanderer() -> Dictionary:
	var def: Dictionary = _pick_monster(2)
	var d: int = danger()
	var hp: float = ceilf(float(def["hp"]) * (1.0 + HP_SCALE_PER_D * float(d)))
	var eff: float = rng.randf_range(SOLVE_EFF_MIN, SOLVE_EFF_MAX)
	var beats: int = int(ceilf(hp / eff))
	battle_beats += float(beats)
	var dmg: float = snappedf(rng.randf_range(1.5, 3.0), 0.5)
	_apply_team_damage(dmg)
	var report := {"name": "游荡·" + String(def["name"]), "tier": 2, "beats": beats, "dmg": dmg, "loot": []}
	if _team_dead():
		_die("被游荡怪追上")
		report["death"] = true
		return report
	battles_won += 1
	wanderer = Vector2i(-1, -1)
	var loot: Array = LootGen.roll_drop(rng, "t2")
	for it: Dictionary in loot:
		_gain_item(it)
	report["loot"] = loot
	return report

func _apply_team_damage(dmg: float) -> void:
	# 前排先扣·溢出下一位
	var remain: float = dmg
	for h: Dictionary in team:
		if remain <= 0.0:
			break
		if float(h["hp"]) <= 0.0:
			continue
		var take: float = minf(float(h["hp"]), remain)
		h["hp"] = float(h["hp"]) - take
		remain -= take

func _team_dead() -> bool:
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			return false
	return true

func _die(cause: String) -> void:
	over = true
	result = {"outcome": "death", "cause": cause, "gold_saved": int(floor(float(gold) * 0.3)),
		"ticks": ticks(), "steps": steps, "battles": battles_won}

# ---------- 拾取 / 事件 / 撤离 ----------

func _gain_item(it: Dictionary) -> void:
	match String(it["cat"]):
		"gold": gold += int(it["gold"])
		"consumable":
			match String(it["id"]):
				"ration": rations += 1
				"potion": potions += 1
				"soup":
					for h: Dictionary in team:
						if float(h["hp"]) > 0.0:
							h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + 0.5)
		"combat": combat_items += 1
		"rare": rare_names.append(String(it["name"]))

func open_chest(c: Vector2i) -> Array:
	var egg: bool = bool(chests[c].get("egg", false))
	var loot: Array = LootGen.roll_drop(rng, "chest")
	if egg:
		loot.append({"id": "egg", "name": "宠物蛋（兽踪）", "cat": "rare", "tier": 0, "shape": [], "gold": 0})
	for it: Dictionary in loot:
		_gain_item(it)
	chests.erase(c)
	grid[c.y][c.x] = Tile.FLOOR
	return loot

func use_ration() -> bool:
	if rations <= 0:
		return false
	rations -= 1
	supplies += 10
	return true

func use_potion() -> bool:
	if potions <= 0:
		return false
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0 and float(h["hp"]) < float(h["hp_max"]):
			h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + 1.0)
			potions -= 1
			return true
	return false

func recruit() -> String:
	if team.size() >= 3:
		return ""
	var name: String = HERO_NAMES[team.size()]
	team.append({"name": name, "hp": 5.0, "hp_max": 5.0})
	return name

func heal_all(amount: float) -> void:
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + amount)

func heal_front(amount: float) -> void:
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			h["hp"] = minf(float(h["hp_max"]), float(h["hp"]) + amount)
			return

func reveal_random_chest() -> Vector2i:
	for c: Vector2i in chests:
		if not bool(chests[c]["revealed_by_map"]):
			chests[c]["revealed_by_map"] = true
			revealed[c] = true
			return c
	return Vector2i(-1, -1)

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
	return best

func extract() -> void:
	over = true
	result = {"outcome": "extract", "gold_saved": gold, "ticks": ticks(), "steps": steps,
		"battles": battles_won, "combat_items": combat_items, "rares": rare_names.duplicate(),
		"in_band": ticks() >= 60.0 and ticks() <= 100.0}
