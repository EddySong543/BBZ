class_name ActionDef
extends RefCounted

## Battle 动作定义 — id / 能量消耗 / 伤害值
## 从 battle_core.gd 拆出 (P1-E2: god class 缓解)
##
## 说明：dict key 是 BattleCore.Action enum 的 int 值。直接用 int 字面量
## 避免循环依赖 (BattleCore 引用 ActionDef.* 而 ActionDef 不引用 BattleCore.Action)。
## 如修改 BattleCore.Action enum 顺序，同步此处：
##   0=CHARGE   1=ATTACK    2=DEFEND     3=BIG_ATTACK  4=BIG_DEFEND  5=SWITCH
##   6=FAN_GE   7=BAI_SHOU  8=JIAO_TU    9=SHE_TUI    10=SHE_SHEN
##  11=SHEN_WAI 12=CAI_JIN  13=YU_ZHE

const BASE_ACTION_DEF := {
	0: {id="charge",     cost=0, damage=0, energy_gain=1},  # CHARGE
	1: {id="attack",     cost=1, damage=1, energy_gain=0},  # ATTACK
	2: {id="defend",     cost=0, damage=0, energy_gain=0},  # DEFEND
	3: {id="big_attack", cost=3, damage=2, energy_gain=0},  # BIG_ATTACK
	4: {id="big_defend", cost=2, damage=0, energy_gain=0},  # BIG_DEFEND
	5: {id="switch",     cost=1, damage=0, energy_gain=0},  # SWITCH
}

const EXTRA_ACTION_DEF := {
	6:  {id="fange",   cost=2, damage=0},   # FAN_GE
	7:  {id="baishou", cost=-1, damage=0},  # BAI_SHOU
	8:  {id="jiaotu",  cost=3, damage=0},   # JIAO_TU
	9:  {id="shetui",  cost=2, damage=0},   # SHE_TUI
	10: {id="sheshen", cost=0, damage=0},   # SHE_SHEN
	11: {id="shenwai", cost=3, damage=0},   # SHEN_WAI
	12: {id="caijin",  cost=0, damage=0},   # CAI_JIN
	13: {id="yuzhe",   cost=0, damage=0},   # YU_ZHE
}


## 返回 action 对应的 id (string)，UI 显示由 EventFormatter.action_name(id) 翻译。
static func get_action_id(action: int) -> String:
	if action in BASE_ACTION_DEF:
		return BASE_ACTION_DEF[action]["id"]
	if action in EXTRA_ACTION_DEF:
		return EXTRA_ACTION_DEF[action]["id"]
	return "unknown"
