class_name ActionDef
extends RefCounted

## Battle 动作定义 —— 数值框架 (ADR-002 §D10) + 半点伤害 (§D3)。
##
## 半点制：内部 1 HP = HP_UNIT(2) 半点，最小伤害 0.5 = 1 半点。
##   本表 damage 字段以【半点】为单位（波 = 2 半点 = 1.0 HP）。
##   能量同样走半点（ENERGY_UNIT=2）：内部 1 能 = 2 半能，支持 0.5 能（B·2026-06-16）。
##   cost / energy_gain 字段以【半能】为单位（波 = 2 半能 = 1.0 能）。
##
## 数值要点（A2·2026-06-16 起）：
##   - 大波消耗 3 能（= 6 半能；穿防），大防 2 能（= 4 半能）
##   - 被动能量已去除（2026-06-24·PASSIVE_ENERGY_GAIN=0）：能量收入仅靠「攒」(+1，鼠额外+1) → 攒回归核心反龟手段
##   - 切换 0 能（占动作槽，h07 唯一例外，在引擎处理）
##   - 初始能量 1.0 能（= 2 半能）
##   - 英雄专属主动技不进全局 Action enum；改由英雄组件声明 (§D9)。

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

const ENERGY_UNIT := 2          # 1 能 = 2 半能（支持 0.5 能）
const INITIAL_ENERGY := 2       # = 1.0 能
const MAX_ENERGY := 20          # = 10 能
const PASSIVE_ENERGY_GAIN := 0  # 被动能量已去除（2026-06-24·去被动+1·让「攒」回归核心反龟，见纲领 §4.5 修订）；旧 A2 = 2 半能

## key = Action enum int；damage 单位为半点；cost / energy_gain 单位为【半能】(=能×2)。
const BASE_ACTION_DEF := {
	Action.CHARGE:     {id = "charge",     cost = 0, damage = 0, energy_gain = 2},  # +1.0 能
	Action.ATTACK:     {id = "attack",     cost = 2, damage = 2, energy_gain = 0},  # 1.0 能 / 1.0 HP
	Action.DEFEND:     {id = "defend",     cost = 0, damage = 0, energy_gain = 0},
	Action.BIG_ATTACK: {id = "big_attack", cost = 6, damage = 4, energy_gain = 0},  # 3.0 能 / 2.0 HP 穿防
	Action.BIG_DEFEND: {id = "big_defend", cost = 4, damage = 0, energy_gain = 0},  # 2.0 能
	Action.SWITCH:     {id = "switch",     cost = 0, damage = 0, energy_gain = 0},
}

## 攻击类动作（用于压制/防御判定）。
const ATTACK_ACTIONS := [Action.ATTACK, Action.BIG_ATTACK]
const DEFEND_ACTIONS := [Action.DEFEND, Action.BIG_DEFEND]

## 穿透等级（二元铁则·2026-06-16）：防御门按此判定，取代旧的"按动作类型判定"。
enum Pen {
	NORMAL,         # 防 / 大防 都挡得住（波）
	PIERCE_DEF,     # 穿防：防挡不住、大防挡得住（大波 / 鸡 2 层一闪）
	PIERCE_BIGDEF,  # 穿大防：连大防都挡不住（仅授公开慢蓄 payoff，如鸡满 4 层）
	TRUE_DMG,       # 真伤：无视一切防御 + 护甲（仅戌狗）
}

## 基础攻击的穿透等级：大波 = 穿防、其余 = 普通。
static func base_penetration(action: int) -> int:
	return Pen.PIERCE_DEF if action == Action.BIG_ATTACK else Pen.NORMAL


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
