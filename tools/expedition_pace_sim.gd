## 远征节奏校准 bot（任务 I·headless）：自动打 N 局，验单局刻数落 60-100 带（≈15-25 分钟目标的刻代理）。
##   godot --headless --path <项目根> --script res://tools/expedition_pace_sim.gd -- [局数=15] [基础种子=9000]
## 输出：控制台 + res://tools/sim/out_expedition_pace.md
##
## bot 策略（"贪但会跑"的中等玩家代理·全知寻路=节奏上界偏快·README 有口径说明）：
##   探索期=清最近的怪/箱/事件；补给≤12 或 刻≥70 或 清完 或 残血 → 直奔最近开放撤离点。
##   干粮补给≤10 自动吃；药瓶前排≤2 自动用；事件从简（篝火/清泉/陷阱实义·其余略过）。
extends SceneTree

const MapState := preload("res://src/expedition/expedition_map_state.gd")

const DIRS: Array = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

var rations: int = 0
var potions: int = 0
var gold: int = 0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() >= 1 else 15
	var base_seed: int = int(args[1]) if args.size() >= 2 else 9000
	var lines: Array = []
	var ticks_list: Array = []
	var deaths: int = 0
	var in_band: int = 0
	print("=== 远征节奏校准：%d 局（种子 %d 起）===" % [runs, base_seed])
	for i: int in runs:
		var r: Dictionary = _play_one(base_seed + i)
		ticks_list.append(float(r["ticks"]))
		if String(r["outcome"]) == "death":
			deaths += 1
		if float(r["ticks"]) >= 60.0 and float(r["ticks"]) <= 100.0:
			in_band += 1
		var line: String = "局 %02d（种子 %d）：%s ｜ 刻 %.1f ｜ 步 %d ｜ 战 %d ｜ 金 %d ｜ 队 %d 人" % [
			i + 1, base_seed + i, "撤离" if String(r["outcome"]) == "extract" else "全灭",
			float(r["ticks"]), int(r["steps"]), int(r["battles"]), int(r["gold"]), int(r["team"])]
		print(line)
		lines.append(line)
	ticks_list.sort()
	var median: float = float(ticks_list[ticks_list.size() / 2])
	var summary: String = "\n中位刻数 %.1f（目标带 60-100）｜ 落带 %d/%d ｜ 死亡 %d/%d ｜ 刻分布 [%.1f .. %.1f]" % [
		median, in_band, runs, deaths, runs, float(ticks_list[0]), float(ticks_list[ticks_list.size() - 1])]
	print(summary)
	var md: String = "# 远征节奏校准（任务 I·%d 局·bot=全知贪婪代理）\n\n" % runs
	md += "> ⚠ bot 全知寻路=刻数偏快的上界；真人探索有迷雾折返，实际会更长。判读用相对带宽非绝对值。\n\n"
	for l: String in lines:
		md += "- %s\n" % l
	md += "\n**%s**\n" % summary.strip_edges()
	var f := FileAccess.open("res://tools/sim/out_expedition_pace.md", FileAccess.WRITE)
	f.store_string(md)
	f.close()
	print("报告已写 res://tools/sim/out_expedition_pace.md")
	quit(0)


func _play_one(seed_v: int) -> Dictionary:
	var m: MapState = MapState.new()
	m.setup(seed_v)
	rations = 0
	potions = 0
	gold = 0
	var guard: int = 0
	while not m.over and guard < 500:
		guard += 1
		_auto_consume(m)
		var target: Vector2i = _pick_target(m)
		if target == Vector2i(-1, -1):
			break
		var step: Vector2i = _next_step(m, target)
		if step == Vector2i.ZERO:
			break
		var res: Dictionary = m.try_move(step)
		if not bool(res["moved"]):
			break
		match String(res["kind"]):
			"monster":
				_collect(m.fight(m.player))
			"wanderer":
				_collect(m.fight_wanderer())
			"chest":
				_collect_loot(m.open_chest(m.player))
			"event":
				_handle_event(m)
			"ext":
				if _want_extract(m) and m.ext_open(m.grid[m.player.y][m.player.x]):
					m.extract()
	if not m.over:
		m.extract()  # 保底收束（卡死/无目标）
	return {"outcome": m.result["outcome"], "ticks": m.result["ticks"], "steps": m.result["steps"],
		"battles": m.result["battles"], "gold": gold, "team": m.team.size()}


func _want_extract(m: MapState) -> bool:
	var hp_sum: float = 0.0
	for h: Dictionary in m.team:
		hp_sum += maxf(0.0, float(h["hp"]))
	return m.supplies <= 12 or m.ticks() >= 70.0 or hp_sum <= 1.5 or _loot_targets(m).is_empty()


## 可打目标：怪只挑「明牌 tier ≤ 队伍人数」的（读牌避险=真人行为）；行商不消格·排除防原地卡死。
func _loot_targets(m: MapState) -> Array:
	var out: Array = []
	for c: Vector2i in m.monsters:
		if int(m.monsters[c]["tier"]) <= m.team.size():
			out.append(c)
	out.append_array(m.chests.keys())
	for c: Vector2i in m.events:
		if String(m.events[c]) != "行商" and c != m.player:
			out.append(c)
	return out


func _pick_target(m: MapState) -> Vector2i:
	var cands: Array
	if _want_extract(m):
		cands = []
		for tile: int in [MapState.Tile.EXT1, MapState.Tile.EXT2, MapState.Tile.EXT3]:
			if m.ext_open(tile):
				cands.append(m.ext_pos[tile])
	else:
		cands = _loot_targets(m)
	var dist: Dictionary = _bfs(m, m.player)
	var best: Vector2i = Vector2i(-1, -1)
	var best_d: int = 99999
	for c: Vector2i in cands:
		if dist.has(c) and int(dist[c]) < best_d:
			best_d = int(dist[c])
			best = c
	return best


## 从玩家到 target 的下一步方向（BFS 反溯）。
func _next_step(m: MapState, target: Vector2i) -> Vector2i:
	var dist: Dictionary = _bfs(m, target)
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = int(dist.get(m.player, 99999))
	for d: Vector2i in DIRS:
		var n: Vector2i = m.player + d
		if dist.has(n) and int(dist[n]) < best_d:
			best_d = int(dist[n])
			best = d
	return best


func _bfs(m: MapState, from: Vector2i) -> Dictionary:
	var dist: Dictionary = {from: 0}
	var queue: Array = [from]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d: Vector2i in DIRS:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= MapState.SIZE or n.y >= MapState.SIZE:
				continue
			if m.grid[n.y][n.x] == MapState.Tile.WALL or dist.has(n):
				continue
			dist[n] = int(dist[c]) + 1
			queue.append(n)
	return dist


func _collect(report: Dictionary) -> void:
	if bool(report.get("death", false)):
		return
	_collect_loot(report.get("loot", []))


func _collect_loot(loot: Array) -> void:
	for it: Dictionary in loot:
		match String(it.get("id", "")):
			"ration": rations += 1
			"potion": potions += 1
			_:
				gold += int(it.get("gold", 0))


func _auto_consume(m: MapState) -> void:
	if m.supplies <= 10 and rations > 0:
		rations -= 1
		m.add_supplies(10)
	if potions > 0 and not m.team.is_empty() and float(m.team[0]["hp"]) <= 2.0 and float(m.team[0]["hp"]) > 0.0:
		potions -= 1
		m.heal_front(1.0)


func _handle_event(m: MapState) -> void:
	var c: Vector2i = m.player
	var ev: String = String(m.events.get(c, ""))
	match ev:
		"篝火":
			if m.recruit() == "":
				m.heal_all(0.5)
		"清泉":
			m.heal_front(1.0)
		"陷阱":
			m.supplies = maxi(0, m.supplies - 5)
	if ev != "行商":
		m.events.erase(c)
		m.grid[c.y][c.x] = MapState.Tile.FLOOR
