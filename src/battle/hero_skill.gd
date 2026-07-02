@abstract
class_name HeroSkill
extends RefCounted

## 英雄技能组件基类 (ADR-002 §D2 / §D6)。
## 每个英雄 = src/battle/skills/hXX_*.gd 继承本类、override 所需 hook。
##
## 【组件无状态】：所有 per-hero 运行时状态（毒层 / 剑意 / 护甲 / 破甲标记…）
##   存在 BattleCore 的容器里（statuses 等）。组件只是纯逻辑，
##   读写传入的 battle。→ 可序列化、利联机复制 / 录像 / 存档 (§D2)。
##
## 【两类接口】
##   ① 被动 hook —— 全部 no-op 默认，子类按需 override。
##   ② 主动技 —— 默认 has_active()=false；主动技英雄 override 下方主动接口。
##
## 约定：所有 dmg / hp 数值为【半点】(§D3)。
##   player / slot = 本组件所属英雄的位置；battle = 引擎实例（读写状态）。
##
## hook 全集按 12 生肖真实需求定，无投机抽象（部分 hook 现无人 override，留作扩展接口）。
## 多数 hook 仅对【出战英雄】触发；团队级 hook（on_team_deal_hit 等）
##   会对含替补的全 3 槽扫描 —— 由引擎决定触发范围。


# ============================================================
# ① 被动 hook（no-op 默认）
# ============================================================

## 开局一次性（建立初始绑定/状态等）。当前 12 生肖无人 override，留作扩展接口。
func on_setup(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 出伤计算：修改本英雄【造成】的伤害（半点）。返回修改后的值。
## 当前 12 生肖无人 override（造成伤害的调整改走 on-hit / 团队 hook / 主动技），留作扩展接口。
func modify_outgoing_damage(dmg: int, _action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return dmg


## 攻击判定类型覆盖（防御门用）：出战英雄发起基础攻击(波/大波)时调用，
## 返回该次攻击在防御门里按哪种类型判定（ATTACK=被"防"挡 / BIG_ATTACK=穿"防"被"大防"挡）。
## 默认按原动作判定。当前 12 生肖无人 override（穿透档改由 attack_penetration 表达），留作扩展接口。
func override_attack_kind(action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return action


## 受伤管线：修改本英雄【受到】的伤害（半点，已过防御门）。返回修改后的值（下限 0）。
## 当前 12 生肖无人 override，留作扩展接口（延迟 / 转移类伤害由引擎在管线后续相位处理，不走本 hook）。
func modify_incoming_damage(dmg: int, _action: int, _battle: BattleCore, _player: int, _slot: int, _attacker_player: int) -> int:
	return dmg


## 团队层出伤修正：本队任一英雄（含本英雄）攻击时调用。引擎对攻击方全 3 槽（含替补）
## 各调一次本 hook，让团队层 buff 源（可能在替补席）对队友的【造成】伤害加成。
## attacker_(player/slot) = 正在攻击的队友；self_(player/slot) = 本组件所属英雄。
## 当前 12 生肖无人 override，留作扩展接口（团队级伤害加成的范例 hook）。
func modify_team_outgoing_damage(dmg: int, _action: int, _battle: BattleCore, _attacker_player: int, _attacker_slot: int, _self_player: int, _self_slot: int) -> int:
	return dmg


## 本英雄击杀对手某英雄后。overkill = 造成伤害 − 被杀者击杀前剩余 HP（半点，≥0）。
## 当前 12 生肖无人 override，留作扩展接口。
func on_kill(_victim_player: int, _victim_slot: int, _overkill: int, _battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 本英雄阵亡时。当前 12 生肖无人 override，留作扩展接口。
func on_death(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 队友阵亡时（dead_slot = 同队阵亡者槽位）。
## 当前 12 生肖无人 override，留作扩展接口。
func on_ally_death(_dead_slot: int, _battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 致死拦截：本英雄本次将致死时调用。返回 true = 存活（实现内自行改写 HP / 清状态）。
## 当前 12 生肖无人 override，留作扩展接口。默认 false（正常死亡）。
func on_before_death(_battle: BattleCore, _player: int, _slot: int) -> bool:
	return false


## 本英雄登场（开局首发 + 每次切换上场）。房日 h04(登场 + 护甲) / 星日 h07(登场冲撞)。
func on_switch_in(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 本英雄切换下场。当前 12 生肖无人 override，留作扩展接口。
func on_switch_out(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 对手出战英雄切换下场时（enemy_slot = 对手下场者槽位）。h11 穷追(追击 1 伤)。
func on_enemy_switch_out(_enemy_slot: int, _battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 本回合结算末尾（伤害/死亡都处理完后）。当前 12 生肖无人 override，留作扩展接口。
func on_resolve_end(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 攻击穿透等级（二元铁则·防御门用）：本英雄发起攻击时返回穿透档（ActionDef.Pen）。
## 默认按动作基础穿透（波=NORMAL / 大波=PIERCE_DEF）。
## 昴日 h10（剑气 2 层→穿防、4 层→穿大防）override。（娄金 h11 追击真伤走 on_enemy_switch_out，不经本 hook。）
func attack_penetration(base_pen: int, _action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return base_pen


## 本英雄一次攻击算作几次"命中"（on-hit 触发次数）。默认 1。尾火连扑返回 2（整体挡下、落地双 proc）。
func hit_count(_action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return 1


## 本英雄攻击【命中（穿过防御门、连接到目标）】后触发：施加自身 on-hit 效果。
## 翼火 h06(叠毒) / 亢金 h05(破甲) / 紫火 h09(碎能)。引擎按 hit_count 次调用。
func on_deal_hit(_battle: BattleCore, _player: int, _slot: int, _target_player: int, _target_slot: int, _dealt: int, _action: int) -> void:
	pass


## 己方任一英雄攻击命中敌方时，对本队所有英雄（含替补席）触发：团队级 on-hit 监听。
## 昴日（全队命中 → +1 剑气）。引擎按 hit_count 次调用。
func on_team_deal_hit(_battle: BattleCore, _player: int, _slot: int, _attacker_slot: int, _target_player: int, _target_slot: int, _dealt: int) -> void:
	pass


## 本英雄（出战）成功防御挡下一次攻击时触发（raw = 被挡攻击的伤害半点）。
## 牛金（卸力反震：反弹被挡伤害的 50% 给攻击者）。
func on_block(_battle: BattleCore, _player: int, _slot: int, _attacker_player: int, _attack_action: int, _raw: int) -> void:
	pass


## 本英雄受到伤害落 HP 后触发（dealt = 实际掉的半点血）。
## 室火（纳福：受伤 → 己方能量 += 等量）。
func on_self_damaged(_battle: BattleCore, _player: int, _slot: int, _dealt: int, _attacker_player: int) -> void:
	pass


## 本英雄（出战时）给己方每次"获得能量"事件的额外加成（半能）。虚日囤鼠 override 返 1 半能（= 每次得能 +0.5）。
func energy_gain_bonus(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0


## 「顶替承伤」型守护者（天狗 h23）：在替补席存活时，我方英雄受【致命伤害】→ 本英雄立刻登场顶替，
## 原 carry 退居替补获救、这一击改落到本英雄身上（本英雄吃这下·可能被打死；每局一次）。
## 默认 false；天狗 override。
func is_lethal_guardian() -> bool:
	return false


## 「牧养 / 休养生息」型（光版鬼金 h08）：本英雄在场（含替补·存活）时，你方退到【替补席】的存活英雄
## 每回合回本值（半点）HP（退下火线休养；出战英雄不回）。引擎在 resolve Phase 5.6 走 _heal 入账。
## 默认 0（不产出）；鬼金 override 返回 1（= +0.5 HP/回合）。共享原语 = 轮换续航（配星日免费切换）。
func reserve_heal_per_turn() -> int:
	return 0


## 「饕餮」型（并封 h24）：本英雄在场（含替补·存活）时，战场上【任一】英雄阵亡（敌我皆可）
## → 本英雄所属队【团队】能量 +本值（半能）。引擎在 _resolve_deaths 每个死亡点扫双方存活英雄累计。
## 默认 0（不产出）；并封 override 返回 4（= +2.0 能/死）。
func death_energy_bonus() -> int:
	return 0


## 免费切换次数上限（仅 has_free_switch()=true 时有意义）；-1 = 无限。星日当先 = -1（不限次）。
func free_switch_cap() -> int:
	return -1


## 本英雄（出战时）是否可以使用「防 / 大防」。默认 true。
## 穷奇 h15【血勇】= false（嗜杀红温·有进无退·彻底放弃防御）。
## 引擎在 can_afford() 统一 gate：返 false 时防/大防变不合法（legal_actions 不列、UI 按钮禁用、AI 不选）。
func can_defend() -> bool:
	return true


## 「鼠潮」型（玄冥 h13）：本英雄在场（含替补·存活）时，己方每触发一次 combo 效果
## （毒爆 / 易伤 / 破甲 / 碎能 / 剑意 / 反震 / 冲撞 / 溢杀…），团队能量额外 +本值（半能）。
## 引擎在每个 combo 结算点调 BattleCore._note_combo_proc() 累计（2026-07-01 去每回合封顶）。
## 默认 0（不产出）；玄冥 override 返回 1（= +0.5 能/proc）。这是"combo→能量"共享原语的产出端。
func combo_proc_energy() -> int:
	return 0


## 「疾风」型（广寒 h16）：本英雄在场（含替补·存活）时，己方每局可 N 次把【同一个动作】
## 再做一次（附加动作·波/大波/攒可双·技能/切换/防御除外）。返回每局上限 N（0 = 不提供）。
## 引擎在 can_double()/select_double()/resolve() 处理；cap 计在本英雄 slot 的 "jifeng_uses"。
func double_action_cap() -> int:
	return 0


## 「缠绕」型（相柳 h18）：本英雄【出战·存活】时，对手【无法主动切换】（含星日免费切换）。
## 死亡换人 / 紫火调虎离山 / 道具强制切换等"被动·触发"切换不受影响。引擎在 can_afford(SWITCH) +
## is_free_switch_target 统一 gate（_can_switch）。默认 false。
func locks_enemy_switch() -> bool:
	return false


# ============================================================
# ② 主动技接口（默认无主动技；主动技英雄 override）
# ============================================================

## 本英雄是否有主动技。被动英雄保持 false。
func has_active() -> bool:
	return false


## 主动技能量消耗。可依赖当前状态。
func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0


## 每局使用上限；-1 = 无上限。引擎统一计数 (§D9)。
func active_per_game_cap() -> int:
	return -1


## 当前是否可用（能量 / cap / 自定义前置）。引擎已查能量与 cap，
## 子类只需补【额外】前置条件。
func can_use_active(_battle: BattleCore, _player: int, _slot: int) -> bool:
	return true


## 本主动技是否需要玩家指定【敌方替补】目标（枭阳 h21 调虎离山 = true）。
## true → UI 在选中主动技后点亮敌方存活替补框供点选；玩家未选则引擎按技能默认处理（如枭阳随机揪）。默认 false。
func active_needs_enemy_target() -> bool:
	return false


## 执行主动技（即时效果型）。扣能 / cap 计数由引擎处理；此处只写效果。
## 注意：攻击型主动技（active_is_attack()=true）不走本方法，改走下方攻击接口。
func execute_active(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


# --- 攻击型主动技（伤害走伤害管线，§D9）。昴日 h10 拔剑一闪 = 当前唯一攻击型主动技 ---

## 本主动技是否是一次"攻击"（造成伤害、走 _apply_damage 管线）。默认 false（即时型）。
func active_is_attack() -> bool:
	return false

## 攻击型主动技造成的伤害（半点）。仅 active_is_attack()=true 时调用。
func active_attack_damage(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0

## 攻击型主动技在防御门里按哪种基础攻击判定：
##   ATTACK = 被"防"挡；BIG_ATTACK = 穿"防"、被"大防"挡。
func active_attack_kind() -> int:
	return ActionDef.Action.ATTACK

## 攻击型主动技命中结算后回调（dealt = 实际落在 HP 上的半点）。预留给攻击型主动技按需追加效果。
func on_active_attack_resolved(_battle: BattleCore, _player: int, _slot: int, _dealt: int) -> void:
	pass


## 本英雄是否拥有"免费切换（不占动作槽）"能力。默认 false。h07 当先返回 true。
## 引擎通过 free_switch() 处理；cap 由引擎计数（statuses["dangxian_uses"]）。
func has_free_switch() -> bool:
	return false
