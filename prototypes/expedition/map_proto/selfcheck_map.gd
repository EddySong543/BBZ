## 地图逻辑 headless 自检：
## godot --headless --path <项目根> --script res://prototypes/expedition/map_proto/selfcheck_map.gd
extends SceneTree

const MapState := preload("res://prototypes/expedition/map_proto/map_state.gd")

var fails: int = 0

func _check(name: String, ok: bool) -> void:
	print(("  ✓ " if ok else "  ✗ ") + name)
	if not ok:
		fails += 1

func _init() -> void:
	print("=== 地图原型自检 ===")
	# 多种子生成健壮性
	for seed_v: int in [1, 777, 31337, 20260706]:
		var s: MapState = MapState.new()
		s.setup(seed_v)
		var ok_gen: bool = s.ext_pos.size() == 3 and s.monsters.size() > 0 and s.team.size() == 1
		_check("种子 %d：生成完整（撤离点 3/怪 %d/事件 %d/宝箱 %d）" % [seed_v, s.monsters.size(), s.events.size(), s.chests.size()], ok_gen)
		# 同种子复现
		var s2: MapState = MapState.new()
		s2.setup(seed_v)
		_check("种子 %d：同种子同图" % seed_v, s2.monsters.keys() == s.monsters.keys() and s2.ext_pos[MapState.Tile.EXT3] == s.ext_pos[MapState.Tile.EXT3])
	var s: MapState = MapState.new()
	s.setup(777)
	# 迷雾：起点周边已探明
	_check("迷雾：起点已探明", s.revealed.has(s.start_pos))
	var before: int = s.revealed.size()
	# 随机走 60 步
	var moved: int = 0
	var dirs: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
	var walk_rng := RandomNumberGenerator.new()
	walk_rng.seed = 42
	for i: int in 200:
		if s.over or moved >= 60:
			break
		var res: Dictionary = s.try_move(dirs[walk_rng.randi_range(0, 3)])
		if bool(res["moved"]):
			moved += 1
			# 走上内容格就地处理（战斗全打·事件跳过=直接清）
			match String(res["kind"]):
				"monster":
					s.fight(s.player)
				"wanderer":
					s.fight_wanderer()
				"chest":
					s.open_chest(s.player)
				"event":
					s.events.erase(s.player)
					s.grid[s.player.y][s.player.x] = MapState.Tile.FLOOR
	_check("移动 %d 步：迷雾扩张（%d → %d 格）" % [moved, before, s.revealed.size()], s.revealed.size() > before)
	_check("刻计量：刻(%.1f) = 步(%d) + 战斗拍×0.5 且 ≥ 步数" % [s.ticks(), s.steps], absf(s.ticks() - (float(s.steps) + s.battle_beats * 0.5)) < 0.01 and s.ticks() >= float(s.steps))
	_check("补给递减：%d = S0 - 步数（或已触发饥饿钳制）" % s.supplies, s.supplies == MapState.S0 - s.steps or s.supplies == 0)
	# 危险度公式
	_check("危险度：D=%d = floor(刻/30) 封顶 5" % s.danger(), s.danger() == mini(5, int(floor(s.ticks() / 30.0))))
	# 撤离窗口
	var w: MapState = MapState.new()
	w.setup(31337)
	_check("撤离窗口 t=0：撤1 开·撤2 未开·撤3 开", w.ext_open(MapState.Tile.EXT1) and not w.ext_open(MapState.Tile.EXT2) and w.ext_open(MapState.Tile.EXT3))
	w.battle_beats = 70.0  # 刻=35
	_check("撤离窗口 t=35：撤1 开·撤2 开", w.ext_open(MapState.Tile.EXT1) and w.ext_open(MapState.Tile.EXT2))
	w.battle_beats = 130.0  # 刻=65
	_check("撤离窗口 t=65：撤1 关·撤2 开", not w.ext_open(MapState.Tile.EXT1) and w.ext_open(MapState.Tile.EXT2))
	w.battle_beats = 200.0  # 刻=100
	_check("撤离窗口 t=100：撤1/撤2 关·撤3 永开（无死锁）", not w.ext_open(MapState.Tile.EXT1) and not w.ext_open(MapState.Tile.EXT2) and w.ext_open(MapState.Tile.EXT3))
	# 遭遇不回溯：D=0 结算的怪·时钟拉高后血量不变
	var e: MapState = MapState.new()
	e.setup(777)
	var mc: Vector2i = e.monsters.keys()[0]
	var m0: Dictionary = e.resolve_encounter(mc)
	var hp_at_d0: float = float(m0["hp"])
	e.battle_beats = 400.0  # D=5
	var m1: Dictionary = e.resolve_encounter(mc)
	_check("遭遇结算不回溯：D0 定 HP %.0f·D5 重看不变" % hp_at_d0, absf(float(m1["hp"]) - hp_at_d0) < 0.01)
	# 新遭遇吃强化
	var mc2: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in e.monsters:
		if not bool(e.monsters[c]["resolved"]):
			mc2 = c
			break
	if mc2.x >= 0:
		var base_hp: float = float(e.monsters[mc2]["hp_max"])
		var m2: Dictionary = e.resolve_encounter(mc2)
		_check("D5 新遭遇强化：HP %.0f ≥ 基础 %.0f×1.75" % [float(m2["hp"]), base_hp], float(m2["hp"]) >= ceilf(base_hp * 1.75) - 0.01 or int(m2["tier"]) == 2)
	# 饥饿行军
	var h: MapState = MapState.new()
	h.setup(1)
	h.supplies = 0
	var hp_before: float = float(h.team[0]["hp"])
	for d: Vector2i in dirs:
		var res: Dictionary = h.try_move(d)
		if bool(res["moved"]):
			break
	_check("饥饿行军：补给 0 后移动全队 -0.5", absf(float(h.team[0]["hp"]) - (hp_before - 0.5)) < 0.01)
	# 死亡结算：金币 30%
	var dd: MapState = MapState.new()
	dd.setup(2)
	dd.gold = 105
	dd.team[0]["hp"] = 0.5
	dd.supplies = 0
	while not dd.over:
		var any: bool = false
		for d: Vector2i in dirs:
			var res: Dictionary = dd.try_move(d)
			if bool(res["moved"]):
				any = true
				break
		if not any:
			break
	_check("走死→死亡结算：金币保底 31 = floor(105×0.3)", dd.over and int(dd.result["gold_saved"]) == 31)
	# 撤离结算
	var x: MapState = MapState.new()
	x.setup(3)
	x.gold = 88
	x.extract()
	_check("撤离结算：金币全带出", int(x.result["gold_saved"]) == 88 and String(x.result["outcome"]) == "extract")
	print("=== 自检结束：%s ===" % ("全部通过" if fails == 0 else "%d 项失败" % fails))
	quit(0 if fails == 0 else 1)
