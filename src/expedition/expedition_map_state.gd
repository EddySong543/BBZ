## 远征模式 — 地图探索状态（纯逻辑·无 UI·可单元测试）。规则源：design/expedition-map.md。
##
## 覆盖：网格生成（BFS 保连通·同种子同图）/ 迷雾 / 三压力源（补给·危险度时钟·撤离关窗）/
## 遭遇结算尺（强化不回溯）/ 游荡怪 / 事件格 / 双结算。
## ⚠ 本文件的占位自动结算（先知效率带 0.7-0.9 伤/拍·校准 v6）现仅剩巢穴怪回退在用——
##   常规踩怪已接真战斗（2026-07-06 D 批·expedition_screen→battle_screen pve_* 交接）。
##
## 用法示例：
##   const MapState := preload("res://src/expedition/expedition_map_state.gd")
##   var m: MapState = MapState.new(); m.setup(777)
##   var res: Dictionary = m.try_move(Vector2i.RIGHT)   # res.kind: move|wall|monster|event|chest|ext|wanderer|death
extends RefCounted

const Loot := preload("res://src/expedition/expedition_loot.gd")

const MONSTER_DATA_PATH := "res://assets/data/expedition/monsters.json"

# ── 调优旋钮（子文档 B §9）──
const SIZE: int = 12
const WALL_RATE: float = 0.2
const S0: int = 40                  # 初始补给
const HUNGER_DMG: float = 0.5       # 补给 0 后每步全队各扣
const D_DIVISOR: float = 30.0       # 危险度分母：D = floor(刻/30)
const D_CAP: int = 5
const HP_SCALE_PER_D: float = 0.15  # 新遭遇怪物 HP +15%/级
const EXT1_CLOSE: float = 60.0      # 撤1 关闭刻
const EXT2_OPEN: float = 30.0       # 撤2 开放刻
const EXT2_CLOSE: float = 90.0      # 撤2 关闭刻
const MONSTER_COUNT: int = 12
const EVENT_COUNT: int = 7
const CHEST_COUNT: int = 6
const SOLVE_EFF_MIN: float = 0.7    # 先知拆解效率带（原型研究发现）
const SOLVE_EFF_MAX: float = 0.9

enum Tile { FLOOR, WALL, START, EXT1, EXT2, EXT3, MONSTER, EVENT, CHEST }

var rng := RandomNumberGenerator.new()
var seed_value: int = 0
var grid: Array = []                # grid[y][x] = Tile
var revealed: Dictionary = {}       # Vector2i -> true（到过/看过永久探明）
var player: Vector2i
var start_pos: Vector2i
var ext_pos: Dictionary = {}        # Tile.EXT1.. -> Vector2i
var monsters: Dictionary = {}       # Vector2i -> {key,name,tier,hp,hp_max,resolved}
var events: Dictionary = {}         # Vector2i -> 事件名（一次性·行商回访例外）
var chests: Dictionary = {}         # Vector2i -> {revealed_by_map,egg}
var wanderer: Vector2i = Vector2i(-1, -1)   # D=5 游荡怪·(-1,-1)=未出
var supplies: int = S0
var steps: int = 0
var battle_beats: float = 0.0
## 队伍（1 开局 → 篝火招募至 3）：[{name, hp, hp_max}]
var team: Array = []
var battles_won: int = 0
var over: bool = false
var result: Dictionary = {}         # {outcome:extract|death, cause, ticks, steps, battles}
var monster_defs: Array = []

const EVENT_POOL: Array = ["篝火", "岔路赌局", "清泉", "行商", "陷阱", "神龛", "藏宝图", "巢穴", "修补匠", "兽踪"]
const HERO_NAMES: Array = ["先锋·占位", "游侠·占位", "术士·占位", "斥候·占位"]


## 初始化一局（同种子同图·可复现）。
func setup(p_seed: int) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	team = [{"name": HERO_NAMES[0], "hp": 5.0, "hp_max": 5.0}]
	_load_monster_defs()
	_generate()
	_reveal_around(player)


## 当前时钟：刻 = 步数×1 + 战斗拍×0.5。
func ticks() -> float:
	return float(steps) + battle_beats * 0.5


## 危险度等级 D = floor(刻/30)，封顶 5。
func danger() -> int:
	return mini(D_CAP, int(floor(ticks() / D_DIVISOR)))


## 撤离点当前是否开放（撤1: 0-60 / 撤2: 30-90 / 撤3: 永开）。
func ext_open(tile: int) -> bool:
	match tile:
		Tile.EXT1: return ticks() < EXT1_CLOSE
		Tile.EXT2: return ticks() >= EXT2_OPEN and ticks() < EXT2_CLOSE
		Tile.EXT3: return true
	return false


## 尝试移动一步。返回 {moved:bool, kind:String, msgs:Array}。
## kind: wall|move|monster|event|chest|ext|wanderer|death|over。
func try_move(dir: Vector2i) -> Dictionary:
	if over:
		return {"moved": false, "kind": "over", "msgs": []}
	var target: Vector2i = player + dir
	if target.x < 0 or target.y < 0 or target.x >= SIZE or target.y >= SIZE:
		return {"moved": false, "kind": "wall", "msgs": []}
	if grid[target.y][target.x] == Tile.WALL:
		return {"moved": false, "kind": "wall", "msgs": []}
	steps += 1
	supplies -= 1
	var msgs: Array = []
	if supplies < 0:
		supplies = 0
		for h: Dictionary in team:
			if float(h["hp"]) > 0.0:
				h["hp"] = float(h["hp"]) - HUNGER_DMG
		msgs.append("饥饿行军：全队 -%.1f HP" % HUNGER_DMG)
		if _team_dead():
			_die("饿死在途中")
			return {"moved": true, "kind": "death", "msgs": msgs}
	player = target
	_reveal_around(player)
	var out := {"moved": true, "kind": "move", "msgs": msgs}
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


## 遭遇结算尺（🔒不回溯）：首次遭遇按当时 D 强化 HP，并处理 D≥3 的 T1→T2 替换（40%）。
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
			m["def"] = up.get("def", {})
		var scaled: float = ceilf(float(m["hp_max"]) * (1.0 + HP_SCALE_PER_D * float(d)))
		m["hp"] = scaled
		m["hp_max"] = scaled
		m["resolved"] = true
	return m


## 占位自动战斗。eff_bonus = 装备加成（每件 +0.05 效率·占位钩子）。
## 返回 {name,tier,beats,dmg,loot:Array[,death]}。胜利后怪物格转空地、掉落由调用方入包。
func fight(c: Vector2i, eff_bonus: float = 0.0) -> Dictionary:
	var m: Dictionary = resolve_encounter(c)
	var eff: float = rng.randf_range(SOLVE_EFF_MIN, SOLVE_EFF_MAX) + eff_bonus
	var beats: int = int(ceilf(float(m["hp"]) / eff))
	battle_beats += float(beats)
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
	report["loot"] = Loot.roll_drop(rng, "t%d" % int(m["tier"]))
	return report


## 逃跑：敌方免费命中一拍（占位=0.5×tier）·退回 back_to·怪驻留血量。
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


## D=5 游荡怪强制遭遇（不可拒绝）。
func fight_wanderer(eff_bonus: float = 0.0) -> Dictionary:
	var def: Dictionary = _pick_monster(2)
	var hp: float = ceilf(float(def["hp"]) * (1.0 + HP_SCALE_PER_D * float(danger())))
	var eff: float = rng.randf_range(SOLVE_EFF_MIN, SOLVE_EFF_MAX) + eff_bonus
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
	report["loot"] = Loot.roll_drop(rng, "t2")
	return report


## 开宝箱：格子转空地，返回掉落（兽踪蛋附加）。
func open_chest(c: Vector2i) -> Array:
	var egg: bool = bool(chests[c].get("egg", false))
	var loot: Array = Loot.roll_drop(rng, "chest")
	if egg:
		loot.append({"id": "egg", "name": "宠物蛋", "cat": "rare", "tier": 0, "shape": Loot.SHAPE_2X2, "gold": 0, "note": "兽踪", "icon": "egg"})
	chests.erase(c)
	grid[c.y][c.x] = Tile.FLOOR
	return loot


## 补给 +amount（干粮/行商）。
func add_supplies(amount: int) -> void:
	supplies += amount


## 篝火招募：队伍 <3 时加入新英雄并返回其名，满员返回 ""。
func recruit() -> String:
	if team.size() >= 3:
		return ""
	var hero_name: String = HERO_NAMES[team.size()]
	team.append({"name": hero_name, "hp": 5.0, "hp_max": 5.0})
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


## 藏宝图：探明一处未知宝箱，返回坐标（无则 (-1,-1)）。
func reveal_random_chest() -> Vector2i:
	for c: Vector2i in chests:
		if not bool(chests[c]["revealed_by_map"]):
			chests[c]["revealed_by_map"] = true
			revealed[c] = true
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
	return best


# ── 真战斗交接（任务 D·2026-07-06·战斗结算在 battle_screen·此处只管状态回写）──

var wanderer_monster: Dictionary = {}   # 游荡怪遭遇实体（首遇生成·被打跑保留血量·击杀清空）


## 游荡怪遭遇实体（真战斗用）：首遇按当时 D 强化生成 T2·驻留至被击杀。
func wanderer_encounter() -> Dictionary:
	if wanderer_monster.is_empty():
		var def: Dictionary = _pick_monster(2)
		var hp_scaled: float = ceilf(float(def["hp"]) * (1.0 + HP_SCALE_PER_D * float(danger())))
		wanderer_monster = {"key": def["key"], "name": "游荡·" + String(def["name"]), "tier": 2,
			"hp": hp_scaled, "hp_max": hp_scaled, "resolved": true, "def": def.get("def", {})}
	return wanderer_monster


## 真战斗结果回写（battle_screen 打完回来调）。
## outcome: win|lose|flee；beats=战斗拍数（刻=×0.5 由 ticks() 统一算）；team_hp=半点数组（按出战顺序）；
## monster_hp=怪物剩余半点。返回 {loot:Array}（win 时按 tier 掉落·其余空）。
func apply_battle_result(c: Vector2i, is_wanderer: bool, outcome: String, beats: int, team_hp: Array, monster_hp: int, back_to: Vector2i) -> Dictionary:
	battle_beats += float(beats)
	# 回写对位：进战快照只含【存活者】（前排先死=死者是队列前缀）→ 按存活顺序回写。
	var idx: int = 0
	for h: Dictionary in team:
		if float(h["hp"]) > 0.0:
			if idx < team_hp.size():
				h["hp"] = float(int(team_hp[idx])) / 2.0
			idx += 1
	var out := {"loot": []}
	var m: Dictionary = wanderer_monster if is_wanderer else monsters.get(c, {})
	if m.is_empty():
		return out
	match outcome:
		"win":
			battles_won += 1
			out["loot"] = Loot.roll_drop(rng, "t%d" % int(m["tier"]))
			if is_wanderer:
				wanderer_monster = {}
				wanderer = Vector2i(-1, -1)
			else:
				monsters.erase(c)
				grid[c.y][c.x] = Tile.FLOOR
				if wanderer == c:
					wanderer = Vector2i(-1, -1)
		"flee":
			m["hp"] = maxf(0.5, float(monster_hp) / 2.0)   # 怪物驻留血量（至少半点·防 0 血活怪）
			player = back_to                               # 退回进入前的格子
		"lose":
			pass   # 死亡结算由调用方走 _team_dead 判定
	if _team_dead():
		_die("战死于 %s" % String(m["name"]))
	return out


## 撤离结算：终局并写 result（金币/货品由背包层负责·此处只记时钟战报）。
func extract() -> void:
	over = true
	result = {"outcome": "extract", "cause": "", "ticks": ticks(), "steps": steps,
		"battles": battles_won, "in_band": ticks() >= 60.0 and ticks() <= 100.0}


# ── 内部 ──

func _load_monster_defs() -> void:
	monster_defs = []
	var txt: String = FileAccess.get_file_as_string(MONSTER_DATA_PATH)
	var data: Variant = JSON.parse_string(txt)
	if data is Dictionary:
		for key: String in data:
			var m: Dictionary = data[key]
			# def = 完整 JSON 定义（真战斗的怪物驾驶员要读策略表·任务 D）
			monster_defs.append({"key": key, "name": String(m["name"]), "tier": int(m["tier"]), "hp": int(m["hp"]), "def": m})


func _pick_monster(tier: int) -> Dictionary:
	var pool: Array = monster_defs.filter(func(m: Dictionary) -> bool: return int(m["tier"]) == tier)
	if pool.is_empty():
		return {"key": "?", "name": "怪", "tier": tier, "hp": tier * 6}
	return pool[rng.randi_range(0, pool.size() - 1)]


func _generate() -> void:
	grid = []
	for y: int in SIZE:
		var row: Array = []
		for x: int in SIZE:
			row.append(Tile.WALL if rng.randf() < WALL_RATE else Tile.FLOOR)
		grid.append(row)
	start_pos = Vector2i(0, SIZE / 2)
	grid[start_pos.y][start_pos.x] = Tile.START
	player = start_pos
	# 软锁保底（2026-07-17 审计修复·≈0.8%/局）：起点在左边界、三邻各 20% 独立成墙——
	# 三墙同出=BFS 只剩起点·三个撤离点还会连环盖到起点，而撤离只在「移动进入」触发
	# =既动不了也撤不了。确定性凿开右邻（固定方向·只影响中招的种子·其余图纹丝不动）。
	if grid[start_pos.y][start_pos.x + 1] == Tile.WALL \
			and grid[start_pos.y - 1][start_pos.x] == Tile.WALL \
			and grid[start_pos.y + 1][start_pos.x] == Tile.WALL:
		grid[start_pos.y][start_pos.x + 1] = Tile.FLOOR
	var dist := _bfs_dist(start_pos)
	for y: int in SIZE:
		for x: int in SIZE:
			var c := Vector2i(x, y)
			if grid[y][x] != Tile.WALL and not dist.has(c):
				grid[y][x] = Tile.WALL
	var cells_by_dist: Array = dist.keys()
	cells_by_dist.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return int(dist[a]) < int(dist[b]))
	_place_ext(Tile.EXT1, dist, 2, 5, cells_by_dist)
	_place_ext(Tile.EXT2, dist, 7, 12, cells_by_dist)
	var deepest: Vector2i = cells_by_dist[cells_by_dist.size() - 1]
	grid[deepest.y][deepest.x] = Tile.EXT3
	ext_pos[Tile.EXT3] = deepest
	var free: Array = dist.keys().filter(func(c: Vector2i) -> bool: return grid[c.y][c.x] == Tile.FLOOR and int(dist[c]) >= 2)
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
		monsters[c] = {"key": def["key"], "name": def["name"], "tier": tier, "hp": float(def["hp"]), "hp_max": float(def["hp"]), "resolved": false, "def": def.get("def", {})}
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


func _reveal_around(c: Vector2i) -> void:
	for dy: int in range(-1, 2):
		for dx: int in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if n.x >= 0 and n.y >= 0 and n.x < SIZE and n.y < SIZE:
				revealed[n] = true


func _wanderer_tick() -> void:
	if danger() >= D_CAP and wanderer == Vector2i(-1, -1):
		wanderer = Vector2i(ext_pos[Tile.EXT3])
	if wanderer == Vector2i(-1, -1) or wanderer == player:
		return
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


func _apply_team_damage(dmg: float) -> void:
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
	result = {"outcome": "death", "cause": cause, "ticks": ticks(), "steps": steps, "battles": battles_won}
