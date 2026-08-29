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
##   - 被动 +1 能/回合已恢复（2026-07-03·Eddy 决策·sim 实锤攒-only=互龟死锁）：收入=被动+1 + 攒额外+1（攒=爆发加速器）
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

const ENERGY_UNIT := 2          # 1 能 = 2 半能（支持 0.5 能）
const INITIAL_ENERGY := 2       # = 1.0 能
const MAX_ENERGY := 20          # = 10 能
const PASSIVE_ENERGY_GAIN := 2  # 被动 +1 能/回合（2026-07-03 Eddy 决策恢复·A2 原值）：sim 实锤无被动收入 → 最优解=互龟死锁（攒=唯一收入且露破绽·防免费）→ 90% 对局打满上限。恢复后攒=爆发加速器（蓄大波/养道具）。观察项=攒使用率勿归零。

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
	PIERCE_DEF,     # 穿防：防挡不住、大防挡得住（大波 / 鸡 2 层飞洒天星）
	PIERCE_BIGDEF,  # 穿大防：连大防都挡不住（仅授公开慢蓄 payoff，如鸡满 4 层）
	TRUE_DMG,       # 真伤：无视一切防御 + 护甲（如娄金追击、心脏掌握魔法）
}

## 基础攻击的穿透等级：大波 = 穿防、其余 = 普通。
static func base_penetration(action: int) -> int:
	return Pen.PIERCE_DEF if action == Action.BIG_ATTACK else Pen.NORMAL


static func is_attack(action: int) -> bool:
	return action in ATTACK_ACTIONS


static func get_base_damage(action: int) -> int:
	if action in BASE_ACTION_DEF:
		return BASE_ACTION_DEF[action]["damage"]
	return 0
