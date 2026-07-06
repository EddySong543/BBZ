## 远征模式 — 怪物驾驶员（生产版·移植自 prototypes/expedition/monster_policy.gd·校准 v6 十怪全过）。
## 规则源：design/expedition-monsters.md §2/§3/§5.1。按怪物定义逐拍出招，五种策略：
##   odds       博弈系概率表：触发器选表 → 可支付归一化（§5.1 硬规：显示=采样·付不起的行归零）→ 采样
##   cycle      考官系固定循环（付不起当拍动作 → 改攒·计 fallback=设计异味信号）
##   turtleRule 铁壳龟：能量 ≥2 能必大防、否则防、从不攻击
##   multiTable 千面傀：每拍明牌抽 1 张表（HP≤enrageHpLe 换凶池）
##   phased     六艺宗师：HP 阈值分阶段·各阶段引用上述任一种
##
## pick() 返回 {action:int, tableId:String, odds:Dictionary[, chosenKey, next]}：
##   odds = 本拍展示给玩家的明牌概率表（可支付归一化后·百分数）·空 = 考官系无表拍；
##   next = 循环怪可预读的下一拍动作名（人类学会循环后的信息量）。
## 诚实性结构保证：引擎从显示表直接采样 → 显示 vs 实际偏差仅剩采样方差（校准 ≤2pp@≥2000 拍）。
##
## 用法：
##   const Policy := preload("res://src/expedition/expedition_monster_policy.gd")
##   var p: Policy = Policy.new(monster_def, seed)
##   var m: Dictionary = p.pick(battle, 1)   # 怪物 = battle 的 player 1
extends RefCounted

const ACTIONS := {
	"attack": ActionDef.Action.ATTACK,
	"defend": ActionDef.Action.DEFEND,
	"charge": ActionDef.Action.CHARGE,
	"bigAttack": ActionDef.Action.BIG_ATTACK,
	"bigDefend": ActionDef.Action.BIG_DEFEND,
}

var def: Dictionary
var rng := RandomNumberGenerator.new()
var _cycle_pos: int = 0
var _phase_idx: int = -1
var fallback_count: int = 0   # 循环拍付不起改攒的次数（>0 = 数值/循环设计要复查）


func _init(monster_def: Dictionary, seed_value: int) -> void:
	def = monster_def
	rng.seed = seed_value


## 本拍出招（player = 怪物在 battle 里的座位号）。
func pick(b: BattleCore, player: int) -> Dictionary:
	return _pick_kind(b, player, def)


func _pick_kind(b: BattleCore, player: int, d: Dictionary) -> Dictionary:
	match String(d["kind"]):
		"odds":
			return _pick_odds(b, player, d)
		"cycle":
			return _pick_cycle(b, player, d)
		"turtleRule":
			return _pick_turtle(b, player)
		"multiTable":
			return _pick_multi(b, player, d)
		"phased":
			return _pick_phased(b, player, d)
	return {action = ActionDef.Action.CHARGE, tableId = "unknown", odds = {}}


func _pick_odds(b: BattleCore, player: int, d: Dictionary) -> Dictionary:
	var table: Dictionary = _select_table(b, player, d["tables"] as Array)
	return _sample_table(b, player, table)


## 从上到下第一条触发命中的表生效（base 恒命中·须放末位）。
func _select_table(b: BattleCore, player: int, tables: Array) -> Dictionary:
	for t in tables:
		var trig: Dictionary = (t as Dictionary).get("trigger", {"type": "base"})
		match String(trig["type"]):
			"base":
				return t
			"energyGe":
				if b.energy[player] >= int(trig["value"]) * 2:
					return t
			"hpLe":
				if b.hp[player][b.active_index[player]] <= int(trig["value"]) * 2:
					return t
	return tables[tables.size() - 1]


## 可支付归一化（§5.1）：p'_i = p_i·avail_i / Σ(p_j·avail_j)。全部归零 → 兜底 100% 攒。
func _sample_table(b: BattleCore, player: int, table: Dictionary) -> Dictionary:
	var raw: Dictionary = table["odds"]
	var weights: Dictionary = {}
	var total: float = 0.0
	for k in raw:
		var w: float = float(raw[k]) if b.can_afford(player, int(ACTIONS[k])) else 0.0
		if w > 0.0:
			weights[k] = w
			total += w
	if total <= 0.0:
		return {action = ActionDef.Action.CHARGE, tableId = String(table["id"]) + "!empty", odds = {"charge": 100.0}}
	var shown: Dictionary = {}
	for k in weights:
		shown[k] = 100.0 * float(weights[k]) / total
	var r: float = rng.randf() * total
	var acc: float = 0.0
	var chosen: String = weights.keys()[0]
	for k in weights:
		acc += float(weights[k])
		if r < acc:
			chosen = k
			break
	return {action = int(ACTIONS[chosen]), tableId = String(table["id"]), odds = shown, chosenKey = chosen}


func _pick_cycle(b: BattleCore, player: int, d: Dictionary) -> Dictionary:
	var seq: Array = d["cycle"]
	var key: String = String(seq[_cycle_pos % seq.size()])
	_cycle_pos += 1
	var next_key: String = String(seq[_cycle_pos % seq.size()])
	var act: int = int(ACTIONS[key])
	if not b.can_afford(player, act):
		fallback_count += 1
		return {action = ActionDef.Action.CHARGE, tableId = "cycle!fallback", odds = {}, next = next_key}
	return {action = act, tableId = "cycle", odds = {}, next = next_key}


func _pick_turtle(b: BattleCore, player: int) -> Dictionary:
	if b.energy[player] >= 4:
		return {action = ActionDef.Action.BIG_DEFEND, tableId = "turtle", odds = {}}
	return {action = ActionDef.Action.DEFEND, tableId = "turtle", odds = {}}


func _pick_multi(b: BattleCore, player: int, d: Dictionary) -> Dictionary:
	var enraged: bool = b.hp[player][b.active_index[player]] <= int(d["enrageHpLe"]) * 2
	var pool: Array = (d["enragedTables"] if enraged else d["tables"]) as Array
	var table: Dictionary = pool[rng.randi_range(0, pool.size() - 1)]
	return _sample_table(b, player, table)


func _pick_phased(b: BattleCore, player: int, d: Dictionary) -> Dictionary:
	var phases: Array = d["phases"]
	var cur: int = 0
	var cur_hp: int = b.hp[player][b.active_index[player]]
	for i in range(phases.size()):
		var ph: Dictionary = phases[i]
		if not ph.has("hpLe") or cur_hp <= int(ph["hpLe"]) * 2:
			cur = i
	if cur != _phase_idx:
		_phase_idx = cur
		_cycle_pos = 0
	return _pick_kind(b, player, phases[cur])
