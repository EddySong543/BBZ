class_name ItemEffect
extends RefCounted

## 道具逻辑组件基类（ADR-003 D1/D4）。每件 = src/battle/items/<id>.gd 继承本类、override 所需方法。
##
## 【组件无状态】（同 HeroSkill §D2）：所有运行时状态进 BattleCore 容器（statuses / _imod /
##   pending_damage / info_distortion / item_buffs …）。组件只是纯逻辑，读写传入的 battle。
##
## 约定：所有 dmg / hp / 能量数值为【半点】。player = 使用者；target = 已解析指向（D6）；
##   data = 该道具 ItemData（读 data.params 取数值）。
##
## 【结算时机】（ADR-003 D3 相位）：
##   setup_pre  —— S 相位第一遍（先于任何 debuff）：免疫 / 信息扭曲等保护性预设。
##   apply_pre  —— S 相位第二遍：自身 buff/治疗/护甲/能量 · 对敌 debuff · 设动作修正器(_imod)。
##   hits       —— 伤害相位：本件产生的伤害 hit（按使用顺序汇入 hit-list，走 _apply_damage）。
##   on_attack_connect —— 使用者本回合【动作攻击命中】时的骑乘效果（吸血 / 下毒）。


## S 相位·第一遍。保护性预设，必须先于任何 debuff 施加（免疫 / 信息扭曲）。
func setup_pre(_battle: BattleCore, _player: int, _data: ItemData) -> void:
	pass


## S 相位·第二遍。主施放：自身向效果 / 对敌 debuff / 写 _imod 动作修正器。
func apply_pre(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> void:
	pass


## 伤害相位。本件【自身产生】的伤害 hit 列表（生锈的飞镖 / 闪电 / 幸运四叶草）。
## 返回 Array[{damage:int, kind:int, pen:int}]；走 _apply_damage（过防御门 + on-hit·D1）。默认无。
func hits(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> Array:
	return []


## 骑乘在【使用者本回合动作攻击命中（穿过防御门连接）】上的效果。
## 吸血鬼的獠牙（回血）/ 毒刺（下毒）。dealt = 该次实际落 HP 半点。默认 no-op。
func on_attack_connect(_battle: BattleCore, _player: int, _target_player: int, _target_slot: int, _dealt: int, _data: ItemData) -> void:
	pass


## 【遗物·Phase IS】每回合注入本回合的被动修正器（写 _imod，每回合刷新）。
## state = 该遗物的持久状态（充能计数 / 累加层 等），随战局存活、可在 relic_end 改写。
func relic_pre(_battle: BattleCore, _player: int, _data: ItemData, _state: Dictionary) -> void:
	pass


## 【遗物·Phase 6】每回合末 tick（产出 HP/能量 / 计数 / 充能；可读 selected_action 判断本回合动作）。
## 返回 false = 遗物耗尽（碎 / 到期）→ BattleCore 将其移除。默认永久持有（返回 true）。
func relic_end(_battle: BattleCore, _player: int, _data: ItemData, _state: Dictionary) -> bool:
	return true
