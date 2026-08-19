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
##   hits       —— 伤害相位：本件产生的独立伤害 hit；不算攻击命中，也不引爆毒素。
##   on_attack_connect —— 使用者本回合【动作攻击命中】时的旧骑乘接口；每段调用，正式件优先使用整次攻击回调。


## S 相位·第一遍。保护性预设，必须先于任何 debuff 施加（免疫 / 信息扭曲）。
func setup_pre(_battle: BattleCore, _player: int, _data: ItemData) -> void:
	pass


## S 阶段·裁定后预设。天罗已取消无效道具后、普通 apply_pre 之前运行。
## 用于必须无视玩家点击顺序的本回合全局规则（治疗转换/禁疗/双方伤害上限）。
func prepare_pre(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> void:
	pass


## 回照镜类效果提供的敌向道具反制次数。核心在天罗裁定后统一汇总，
## 再按敌方提交顺序移除明确以对手为目标的道具，组件本身不持有运行时状态。
func hostile_item_counter_charges(_data: ItemData) -> int:
	return 0


## 少数更早层级完成裁定的道具不进入回照镜筛选（当前仅天罗地网）。
## 这不是强度免疫，而是避免已经结算的 setup 效果又消耗一次较晚的反制。
func resolves_before_hostile_item_counters() -> bool:
	return false


## 选择阶段的纯合法性查询。用于“每名英雄限用一次”等按目标限制；不得改写战局状态。
func can_use(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> bool:
	return true


## 一件合法道具被实际提交并消耗时调用；即使效果随后被封印或天罗抵消也不会撤销。
func on_consumed(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> void:
	pass


## S 相位·第二遍。主施放：自身向效果 / 对敌 debuff / 写 _imod 动作修正器。
func apply_pre(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> void:
	pass


## 连环鼓第二行动开始前的阶段钩子。此时 selected_action 已临时切到双方第二行动；
## 只用于必须按同阶段动作配对的效果，避免第一阶段的修正误套到第二阶段或反之。
func apply_second_pre(_battle: BattleCore, _player: int, _target: int,
		_data: ItemData, _events: Array) -> void:
	pass


## 选择阶段立即结算的道具（例如上等法力药水）。天罗地网的事务快照会回滚其效果，
## 但道具来源仍照常消耗。默认仍进入本回合 item_uses。
func resolves_on_submit() -> bool:
	return false


## 少数道具需要“选择期立即产生资源，同时在揭示后结算代价”（借命灯）。
## true 时，BattleCore 在 apply_on_submit 后仍把本件放入 item_uses；天罗事务重放同样遵守。
func queues_after_submit() -> bool:
	return false


func apply_on_submit(_battle: BattleCore, _player: int, _target: int, _data: ItemData,
		_events: Array) -> void:
	pass


## 选择阶段可查询的行动费用修正。必须是纯查询，不得改写 battle 或 data。
## BattleCore 会从本回合已提交的 item_uses 汇总，并让选招预览、血量支付、能量上限折扣与最终扣费共用。
func action_cost_delta(_battle: BattleCore, _player: int, _action: int, _data: ItemData) -> int:
	return 0


## 伤害相位。本件【自身产生】的伤害 hit 列表（生锈的飞镖 / 闪电 / 幸运四叶草）。
## 返回 Array[{damage:int, kind:int, pen:int}]；走 _apply_damage（过防御门 + on-hit·D1）。默认无。
func hits(_battle: BattleCore, _player: int, _target: int, _data: ItemData) -> Array:
	return []


## 骑乘在【使用者本回合动作攻击命中（穿过防御门连接）】上的效果。
## 吸血鬼的獠牙（回血）/ 毒刺（下毒）。dealt = 该次实际落 HP 半点。默认 no-op。
func on_attack_connect(_battle: BattleCore, _player: int, _target_player: int, _target_slot: int, _dealt: int, _data: ItemData) -> void:
	pass


## 一次【基础攻击】（「波」/「大波」）完整结算后的道具回调。
## context = {executed, source_slot, target_slot, connected, damage_total, hp_damage_total,
##   target_defeated, hit_effect_triggers}。道具附带效果每次攻击最多结算一次，
## hit_effect_triggers 固定为 1；双生咒符、聚鼎三花的额外触发只进入英雄技能 hook。
## h13 的双波仍是一整次攻击，故只回调一次；攻击型主动技、道具伤害与追击不进入本入口。
func on_base_attack_resolved(_battle: BattleCore, _player: int, _context: Dictionary,
		_data: ItemData, _events: Array) -> void:
	pass


## 【遗物·Phase IS】每回合注入本回合的被动修正器（写 _imod，每回合刷新）。
## state = 该遗物的持久状态（充能计数 / 累加层 等），随战局存活、可在 relic_end 改写。
func relic_on_activate(_battle: BattleCore, _player: int, _data: ItemData,
		_state: Dictionary, _events: Array) -> void:
	pass


func relic_pre(_battle: BattleCore, _player: int, _data: ItemData, _state: Dictionary,
		_events: Array) -> void:
	pass


## 连环鼓第二行动的遗物阶段钩子。默认不重复 relic_pre，避免回合型攻击加成被叠加两次。
func relic_second_pre(_battle: BattleCore, _player: int, _data: ItemData,
		_state: Dictionary, _events: Array) -> void:
	pass


## 一整次基础攻击结算后回调一次。h13 双段大波不会逐段调用。
func relic_on_attack_resolved(_battle: BattleCore, _player: int, _context: Dictionary,
		_data: ItemData, _state: Dictionary, _events: Array) -> void:
	pass


## 对手一整次基础攻击结算后回调防守方遗物一次。
func relic_on_defense_resolved(_battle: BattleCore, _player: int, _context: Dictionary,
		_data: ItemData, _state: Dictionary, _events: Array) -> void:
	pass


## 【遗物·Phase 6】每回合末 tick（产出 HP/能量 / 计数 / 充能；可读 selected_action 判断本回合动作）。
## 返回 false = 遗物耗尽（碎 / 到期）→ BattleCore 将其移除。默认永久持有（返回 true）。
func relic_end(_battle: BattleCore, _player: int, _data: ItemData, _state: Dictionary,
		_events: Array) -> bool:
	return true


## 道具经济清空已用槽之后的遗物回调。聚宝盆在这里看最终空位，避免刚使用的来源槽
## 在回调发生后才清空而漏补，也避免同一回合补入的道具立即可用。
func relic_after_economy(_battle: BattleCore, _player: int, _data: ItemData,
		_state: Dictionary, _events: Array) -> void:
	pass


## 【遗物·登场】持有本遗物的一方【切换登场】时触发（夜明珠 = 登场者攻击加成 + 登场冲撞）。
## slot = 登场英雄槽；events 供追加可视事件（如冲撞）。BattleCore._perform_switch 遍历本方遗物调。默认 no-op。
func relic_on_switch_in(_battle: BattleCore, _player: int, _slot: int, _data: ItemData, _state: Dictionary, _events: Array) -> void:
	pass


## 【遗物·毒爆】持有本遗物的一方【引爆毒】时，返回额外伤害（半点·鹤顶红 = +2）。
## BattleCore 毒引爆处遍历本方遗物累加。默认 0。
func relic_poison_detonate_bonus(_battle: BattleCore, _player: int, _layers: int,
		_data: ItemData, _state: Dictionary, _events: Array) -> int:
	return 0
