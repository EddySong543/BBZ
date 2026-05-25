class_name ActionDefV4
extends RefCounted

## Battle v4 动作定义 —— 新数值框架 (ADR-002 §D10) + 半点伤害 (§D3)。
##
## 半点制：内部 1 HP = HP_UNIT(2) 半点，最小伤害 0.5 = 1 半点。
##   本表 damage 字段以【半点】为单位（波 = 2 半点 = 1.0 HP）。
##   能量（cost / energy_gain）是独立整数资源，不走半点。
##
## 与 v3 (src/battle/action_def.gd) 的差异：
##   - 大波消耗 3 能 → 2 能
##   - 切换消耗 1 能 → 0 能（占动作槽，h07 唯一例外，在引擎处理）
##   - 初始能量 0 → 1
##   - 英雄专属主动技【不再】塞进全局 Action enum；改由英雄组件声明 (§D9)。
##
## ⚠️ 临时位于 v4/，swap 后替换 src/battle/action_def.gd。

enum Action {
	CHARGE,      # 攒：+能量
	ATTACK,      # 波
	DEFEND,      # 防
	BIG_ATTACK,  # 大波
	BIG_DEFEND,  # 大防
	SWITCH,      # 切换
}

## 英雄主动技哨兵动作（§D9）：玩家选"用本英雄主动技"。
## 每个英雄至多 1 个主动技，故单一哨兵即可；具体效果/费用由英雄组件声明。
## 取值远离 Action enum，避免与基础动作冲突。
const ACTIVE := 100

const HP_UNIT := 2       # 1 HP = 2 半点
const MIN_DAMAGE := 1    # 最小伤害 = 1 半点 = 0.5 HP

const INITIAL_ENERGY := 1
const MAX_ENERGY := 20

## key = Action enum int；damage 单位为半点。
const BASE_ACTION_DEF := {
	Action.CHARGE:     {id = "charge",     cost = 0, damage = 0, energy_gain = 1},
	Action.ATTACK:     {id = "attack",     cost = 1, damage = 2, energy_gain = 0},  # 1.0 HP
	Action.DEFEND:     {id = "defend",     cost = 0, damage = 0, energy_gain = 0},
	Action.BIG_ATTACK: {id = "big_attack", cost = 2, damage = 4, energy_gain = 0},  # 2.0 HP
	Action.BIG_DEFEND: {id = "big_defend", cost = 2, damage = 0, energy_gain = 0},
	Action.SWITCH:     {id = "switch",     cost = 0, damage = 0, energy_gain = 0},
}

## 攻击类动作（用于压制/防御判定）。
const ATTACK_ACTIONS := [Action.ATTACK, Action.BIG_ATTACK]
const DEFEND_ACTIONS := [Action.DEFEND, Action.BIG_DEFEND]


static func is_attack(action: int) -> bool:
	return action in ATTACK_ACTIONS


static func get_action_id(action: int) -> String:
	if action in BASE_ACTION_DEF:
		return BASE_ACTION_DEF[action]["id"]
	return "unknown"


static func get_base_damage(action: int) -> int:
	if action in BASE_ACTION_DEF:
		return BASE_ACTION_DEF[action]["damage"]
	return 0
