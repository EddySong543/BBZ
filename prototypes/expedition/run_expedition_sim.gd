extends SceneTree

## 远征原型·PvE 战斗 headless 校准（prototypes 隔离区·可丢弃）
## 用法：godot --headless --path <proj> --script res://prototypes/expedition/run_expedition_sim.gd
## 每只怪 × FIGHTS 场 × 两种玩家（白板 HP5 单英雄·无道具无技能=纯动作层）：
##   先知玩家 = 读明牌的理想解题者（考官系完全读循环·博弈系只读明牌分布做最优回应）→ 上界
##   搜索玩家 = BattleAI v1 depth2（不读牌的猜拳 AI）→ 下界；真人落在两者之间
## 验收（design/expedition-monsters.md §8）：
##   ① 明牌真实性：显示概率（逐拍期望累加）vs 实际采样 ≤2pp（先知场次统计）
##   ② 遭遇拍数带（按先知判）：T1 6-12 / T2 12-18 / T3 18-25（中位·±20% 容差）
##   ③ 先知胜率：T1 必须 >50%（教学关卡·玩家最弱态=单白板必须能过）；T2/T3 胜率仅参考——
##      正式口径需"多英雄+道具"玩家模型（招募/装备后的中后期玩家），本原型不建模、README 标注
## 输出：res://prototypes/expedition/out_calibration.md

const MonsterPolicy := preload("res://prototypes/expedition/monster_policy.gd")

const FIGHTS := 80
const FIGHT_CAP := 60          # 单场拍数安全阀
const PLAYER_HP := 5
const BASE_SEED := 20260705
const BANDS := {1: [6, 12], 2: [12, 18], 3: [18, 25]}


func _initialize() -> void:
	var f := FileAccess.open("res://prototypes/expedition/expedition_monsters.json", FileAccess.READ)
	var defs: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var lines: Array[String] = []
	lines.append("# 远征 PvE 战斗校准报告（原型·%d 场/怪/玩家档·白板 HP%d）" % [FIGHTS, PLAYER_HP])
	lines.append("")
	lines.append("| 怪 | 层 | 先知:拍中位(带) | 先知胜率 | 搜索AI:拍/胜率 | 明牌最大偏差 | 表采样拍 | fallback | 判定 |")
	lines.append("|----|----|-----------------|----------|----------------|--------------|----------|----------|------|")
	var ids: Array = defs.keys()
	ids.sort()
	var all_pass := true
	for id in ids:
		var d: Dictionary = defs[id]
		var ro: Dictionary = _calibrate_monster(id, d, true)    # 先知（含明牌对账）
		var rs: Dictionary = _calibrate_monster(id, d, false)   # 搜索 AI
		var band: Array = BANDS[int(d["tier"])]
		var band_ok: bool = ro["median"] >= int(band[0]) * 0.8 and ro["median"] <= int(band[1]) * 1.2
		# 原型阈 4pp：引擎从显示表直接采样=诚实性是结构保证，此检查是管线冒烟；
		# 500-1000 拍的采样方差本身 ~2pp（1σ）·正式验收 2pp 口径需 ≥2000 拍（回写设计文档 §5.4）。
		var odds_ok: bool = ro["maxDiff"] <= 4.0
		var win_ok: bool = int(d["tier"]) > 1 or 100.0 * ro["playerWins"] / FIGHTS > 50.0
		var ok: bool = band_ok and odds_ok and win_ok and int(ro["fallback"]) == 0
		if not ok:
			all_pass = false
		lines.append("| %s %s | T%d | %d (%d-%d)%s | %.0f%%%s | %d拍/%.0f%% | %.1fpp%s | %d | %d | %s |" % [
			id, d["name"], d["tier"], ro["median"], band[0], band[1], "✓" if band_ok else "✗",
			100.0 * ro["playerWins"] / FIGHTS, "✓" if win_ok else "✗",
			rs["median"], 100.0 * rs["playerWins"] / FIGHTS,
			ro["maxDiff"], "✓" if odds_ok else "✗", ro["oddsBeats"], ro["fallback"], "✅" if ok else "⚠"])
	lines.append("")
	var verdict: String = "✅ 全部通过" if all_pass else "⚠ 有未过项·见上表"
	lines.append("总判定：" + verdict + "（带宽含 ±20 百分比容差；明牌偏差阈 4pp(原型·正式 2pp@≥2000 拍)；先知=上界·搜索 AI=下界·真人居中）")
	var out := FileAccess.open("res://prototypes/expedition/out_calibration.md", FileAccess.WRITE)
	out.store_string("\n".join(lines) + "\n")
	out.close()
	print("\n".join(lines))
	quit(0)


func _calibrate_monster(id: String, d: Dictionary, oracle: bool) -> Dictionary:
	var beats_list: Array[int] = []
	var player_wins: int = 0
	var fallback: int = 0
	var exp_cnt: Dictionary = {}
	var act_cnt: Dictionary = {}
	var odds_beats: int = 0
	for fi in range(FIGHTS):
		var seed_f: int = BASE_SEED + id.hash() % 100000 + fi * 7 + (1000000 if oracle else 0)
		var b := BattleCore.new()
		b.setup([_vanilla("player", PLAYER_HP)], [_vanilla(String(d["name"]), int(d["hp"]))], seed_f)
		var ai := BattleAI.new(seed_f + 1, 2)
		var policy: RefCounted = MonsterPolicy.new(d, seed_f + 2)
		while not b.game_over and b.turn_number < FIGHT_CAP:
			var m: Dictionary = policy.pick(b, 1)   # 怪先定招（同时结算·信息只给先知）
			var shown: Dictionary = m["odds"]
			if not shown.is_empty():
				odds_beats += 1
				for k in shown:
					exp_cnt[k] = float(exp_cnt.get(k, 0.0)) + float(shown[k]) / 100.0
				act_cnt[String(m["chosenKey"])] = int(act_cnt.get(String(m["chosenKey"]), 0)) + 1
			if oracle:
				b.select_action(0, _oracle_choose(b, m))
			else:
				var c0: Dictionary = ai.choose_action(b, 0)
				if not b.apply_choice(0, c0):
					b.select_action(0, ActionDef.Action.CHARGE)
			b.select_action(1, int(m["action"]))
			b.resolve()
		beats_list.append(b.turn_number)
		if b.winner == BattleCore.WINNER_P1:
			player_wins += 1
		fallback += int(policy.fallback_count)
	beats_list.sort()
	var max_diff: float = 0.0
	if odds_beats > 0:
		var keys: Dictionary = {}
		for k in exp_cnt:
			keys[k] = true
		for k in act_cnt:
			keys[k] = true
		for k in keys:
			var e: float = 100.0 * float(exp_cnt.get(k, 0.0)) / odds_beats
			var a: float = 100.0 * float(act_cnt.get(k, 0)) / odds_beats
			max_diff = maxf(max_diff, absf(e - a))
	return {
		median = beats_list[beats_list.size() / 2], playerWins = player_wins,
		maxDiff = max_diff, oddsBeats = odds_beats, fallback = fallback,
	}


## 先知玩家：考官系（无表拍）= 完全读到本拍动作；博弈系 = 只读明牌分布 → 对最可能一手回应。
func _oracle_choose(b: BattleCore, m: Dictionary) -> int:
	var odds: Dictionary = m["odds"]
	var ea: int
	if odds.is_empty():
		ea = int(m["action"])
	else:
		var best_k: String = ""
		var best_p: float = -1.0
		for k in odds:
			if float(odds[k]) > best_p:
				best_p = float(odds[k])
				best_k = k
		ea = int(MonsterPolicy.ACTIONS[best_k])
	return _best_response(b, ea, String(m.get("next", "")))


## 对已知/最可能的敌方动作做规则式最优回应（解题玩家的简化代理·非穷举最优）。
## v5 修正：防御不回血（动作层无 heal·核查 battle_core）→ 编织无进账，对纯攻怪的
## 人类赢法 = 防-防-大波经济循环（防挡白攒被动能 → 大波 4 半点·每循环净赚血差）。
## next = 循环怪可预读的下一拍（"" = 不可预读）。
func _best_response(b: BattleCore, enemy_action: int, next_key: String) -> int:
	var my_hp: int = b.hp[0][b.active_index[0]]
	var e_hp: int = b.hp[1][b.active_index[1]]
	var kill_beats: int = (e_hp + 1) / 2       # 我打死它还需几拍（波 2 半点/拍）
	var die_beats: int = (my_hp + 1) / 2       # 它波我打死我还需几拍
	match enemy_action:
		ActionDef.Action.BIG_ATTACK:
			if e_hp <= 2 and b.can_afford(0, ActionDef.Action.ATTACK):
				return ActionDef.Action.ATTACK          # 斩杀线：换血也把它带走
			if b.can_afford(0, ActionDef.Action.BIG_DEFEND):
				return ActionDef.Action.BIG_DEFEND      # 大波穿防·只有大防挡得住
			return ActionDef.Action.ATTACK
		ActionDef.Action.ATTACK:
			if e_hp <= 2 and my_hp > 2 and b.can_afford(0, ActionDef.Action.ATTACK):
				return ActionDef.Action.ATTACK          # 收头：换一下也活
			if my_hp <= 2:
				return ActionDef.Action.DEFEND          # 读到致命拍 → 必挡
			if kill_beats < die_beats and b.can_afford(0, ActionDef.Action.ATTACK):
				return ActionDef.Action.ATTACK          # 严格更快才对拼（平手对拼=同拍双死）
			if b.can_afford(0, ActionDef.Action.BIG_ATTACK):
				return ActionDef.Action.BIG_ATTACK      # 经济循环兑现：4 半点换挨 2
			return ActionDef.Action.DEFEND              # 挡 + 白攒被动能（向大波储蓄）
		ActionDef.Action.DEFEND:
			if b.can_afford(0, ActionDef.Action.BIG_ATTACK):
				return ActionDef.Action.BIG_ATTACK      # 穿防惩罚
			return ActionDef.Action.CHARGE              # 攒着·别把波送进盾里
		ActionDef.Action.BIG_DEFEND:
			return ActionDef.Action.CHARGE              # 什么都进不去 → 攒
		_:
			# 它在攒：预读到下一拍是大波且大防钱不够且血量吃不起（≤3.0）→ 提前攒够大防钱
			if next_key == "bigAttack" and b.energy[0] < 4 and my_hp <= 6:
				return ActionDef.Action.CHARGE
			if b.can_afford(0, ActionDef.Action.ATTACK):
				return ActionDef.Action.ATTACK          # 白打一拍
			return ActionDef.Action.CHARGE


func _vanilla(display_name: String, hp: int) -> HeroData:
	var h := HeroData.new()
	h.hero_id = ""          # 空 id = 不注册技能组件（白板）
	h.hero_name = display_name
	h.max_hp = hp
	return h
