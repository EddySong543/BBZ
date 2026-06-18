@abstract
class_name HeroSkill
extends RefCounted

## 英雄技能组件基类 (ADR-002 §D2 / §D6)。
## 每个英雄 = src/battle/skills/hXX_*.gd 继承本类、override 所需 hook。
##
## 【组件无状态】：所有 per-hero 运行时状态（窟层/连段/燃烧/变身 form/契约 link…）
##   存在 BattleCore 的容器里（statuses / form / link …）。组件只是纯逻辑，
##   读写传入的 battle。→ 可序列化、利联机复制 / 录像 / 存档 (§D2)。
##
## 【两类接口】
##   ① 被动 hook —— 全部 no-op 默认，子类按需 override。
##   ② 主动技 —— 默认 has_active()=false；主动技英雄 override 下方主动接口。
##
## 约定：所有 dmg / hp 数值为【半点】(§D3)。
##   player / slot = 本组件所属英雄的位置；battle = 引擎实例（读写状态）。
##
## hook 全集来自 hero-mechanics-hook-matrix.md §3（按 34 英雄真实需求定，无投机抽象）。
## 多数 hook 仅对【出战英雄】触发；团队级 hook（on_ally_take_damage 后排分担、
##   契约扣血）会对含替补的全 3 槽扫描 —— 由引擎决定触发范围。


# ============================================================
# ① 被动 hook（no-op 默认）
# ============================================================

## 开局一次性。建立绑定关系等（h19 指定挚爱 / h28 缔约）。
func on_setup(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 出伤计算：修改本英雄【造成】的伤害（半点）。返回修改后的值。
## h02 怒目 / h03 渴血 / h05 天威 / h09 凶兽 / h10 啼晓 / h13 孤注 / h22 / h25 蓄势 /
## h26 收割形态 / h28 契约队友 / h31 月相(造成) / h13 孤注(翻倍 buff)。
func modify_outgoing_damage(dmg: int, _action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return dmg


## 攻击判定类型覆盖（防御门用）：出战英雄发起基础攻击(波/大波)时调用，
## 返回该次攻击在防御门里按哪种类型判定（ATTACK=被"防"挡 / BIG_ATTACK=穿"防"被"大防"挡）。
## 默认按原动作判定。h10 啼晓：第 3/6/9… 回合把"波"升级为大波判定（伤害另由 modify_outgoing 给到）。
func override_attack_kind(action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return action


## 受伤管线：修改本英雄【受到】的伤害（半点，已过防御门）。返回修改后的值（下限 0）。
## h04 三窟(消层) / h18 教皇 / h21 力量 / h22(防点) / h31 月相(受到)。
## 延迟(h27)、转移(h30) 由引擎在管线后续相位处理，不走本 hook。
func modify_incoming_damage(dmg: int, _action: int, _battle: BattleCore, _player: int, _slot: int, _attacker_player: int) -> int:
	return dmg


## 团队层出伤修正：本队任一英雄（含本英雄）攻击时调用。引擎对攻击方全 3 槽（含替补）
## 各调一次本 hook，让团队层 buff 源（可能在替补席）对队友的【造成】伤害加成。
## attacker_(player/slot) = 正在攻击的队友；self_(player/slot) = 本组件所属英雄。
## h03 渴血（寅虎存活时全队"波"+stacks）。
func modify_team_outgoing_damage(dmg: int, _action: int, _battle: BattleCore, _attacker_player: int, _attacker_slot: int, _self_player: int, _self_slot: int) -> int:
	return dmg


## 后排参战：出战队友受伤时，本英雄（在替补席）可重定向其伤害。
## 返回【应留在该队友身上的伤害】（半点）；重定向到自身的部分由实现内写 battle。
## h30 北辰守望（替补存活时分担出战队友一半伤害）。
func on_ally_take_damage(dmg: int, _ally_slot: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return dmg


## 本英雄击杀对手某英雄后。overkill = 造成伤害 − 被杀者击杀前剩余 HP（半点，≥0）。
## h03 渴血(团队 +1) / h26 死神(回 2HP) / h29 塔(溢出 splash)。
func on_kill(_victim_player: int, _victim_slot: int, _overkill: int, _battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 本英雄阵亡时。h03 寅虎(清零团队渴血) / h28 恶魔(解约)。
func on_death(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 队友阵亡时（dead_slot = 同队阵亡者槽位）。
## h19 恋人(挚爱死殉情) / h22 隐者(死亡叠加) / h28(契约目标死解约)。
func on_ally_death(_dead_slot: int, _battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 致死拦截：本英雄本次将致死时调用。返回 true = 存活（实现内自行改写 HP / 清状态）。
## h06 蛇蜕（首次致死重生 2HP）。默认 false（正常死亡）。
func on_before_death(_battle: BattleCore, _player: int, _slot: int) -> bool:
	return false


## 本英雄登场（开局首发 + 每次切换上场）。h23 周而复始(抽祝福)。
func on_switch_in(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 本英雄切换下场。h04 三窟(+1 窟层)。
func on_switch_out(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 对手出战英雄切换下场时（enemy_slot = 对手下场者槽位）。h11 穷追(追击 1 伤)。
func on_enemy_switch_out(_enemy_slot: int, _battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 本回合结算末尾（伤害/死亡都处理完后）。h09 凶兽(更新连段) / h25 倒吊人(置蓄势)。
func on_resolve_end(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


## 攻击穿透等级（二元铁则·防御门用）：本英雄发起攻击时返回穿透档（ActionDef.Pen）。
## 默认按动作基础穿透（波=NORMAL / 大波=PIERCE_DEF）。
## 酉鸡（剑气 2 层→穿防、4 层→穿大防）/ 戌狗追击（真伤）等 override。
func attack_penetration(base_pen: int, _action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return base_pen


## 本英雄一次攻击算作几次"命中"（on-hit 触发次数）。默认 1。寅虎连扑返回 2（整体挡下、落地双 proc）。
func hit_count(_action: int, _battle: BattleCore, _player: int, _slot: int) -> int:
	return 1


## 本英雄攻击【命中（穿过防御门、连接到目标）】后触发：施加自身 on-hit 效果。
## 巳蛇(叠毒) / 辰龙(破甲) / 申猴(碎能) / 午马(冲撞触发) / 愚者(随机 proc)。引擎按 hit_count 次调用。
func on_deal_hit(_battle: BattleCore, _player: int, _slot: int, _target_player: int, _target_slot: int, _dealt: int, _action: int) -> void:
	pass


## 己方任一英雄攻击命中敌方时，对本队所有英雄（含替补席）触发：团队级 on-hit 监听。
## 酉鸡（全队命中 → +1 剑气）。引擎按 hit_count 次调用。
func on_team_deal_hit(_battle: BattleCore, _player: int, _slot: int, _attacker_slot: int, _target_player: int, _target_slot: int, _dealt: int) -> void:
	pass


## 本英雄（出战）成功防御挡下一次攻击时触发（raw = 被挡攻击的伤害半点）。
## 丑牛（卸力反震：反弹被挡伤害的 50% 给攻击者）。
func on_block(_battle: BattleCore, _player: int, _slot: int, _attacker_player: int, _attack_action: int, _raw: int) -> void:
	pass


## 本英雄受到伤害落 HP 后触发（dealt = 实际掉的半点血）。
## 亥猪（纳福：受伤 → 己方能量 += 等量）。
func on_self_damaged(_battle: BattleCore, _player: int, _slot: int, _dealt: int, _attacker_player: int) -> void:
	pass


## 本英雄（出战时）给己方每次"获得能量"事件的额外加成（半能）。子鼠囤鼠 = ENERGY_UNIT（每次 +1 能）。
func energy_gain_bonus(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0


## 本英雄是否为"致死救援"守护者（替补席存活时，可替将死的出战队友顶伤上场）。未羊 = true。
func is_lethal_guardian() -> bool:
	return false


## 免费切换次数上限（仅 has_free_switch()=true 时有意义）；-1 = 无限。午马当先 = -1（不限次）。
func free_switch_cap() -> int:
	return -1


# ============================================================
# ② 主动技接口（默认无主动技；主动技英雄 override）
# ============================================================

## 本英雄是否有主动技。被动英雄保持 false。
func has_active() -> bool:
	return false


## 主动技动作 id（字符串，UI 文案由 battle_screen 内联翻译）。仅 has_active() 为 true 时有意义。
func active_action_id() -> String:
	return ""


## 主动技能量消耗。可依赖当前状态（如 h20 倾力 = 全部能量）。
func active_cost(_battle: BattleCore, _player: int, _slot: int) -> int:
	return 0


## 每局使用上限；-1 = 无上限。引擎统一计数 (§D9)。
func active_per_game_cap() -> int:
	return -1


## 当前是否可用（能量 / cap / 自定义前置如 h08 HP>1）。引擎已查能量与 cap，
## 子类只需补【额外】前置条件。
func can_use_active(_battle: BattleCore, _player: int, _slot: int) -> bool:
	return true


## 执行主动技（即时效果型）。扣能 / cap 计数由引擎处理；此处只写效果。
## 注意：攻击型主动技（active_is_attack()=true）不走本方法，改走下方攻击接口。
func execute_active(_battle: BattleCore, _player: int, _slot: int) -> void:
	pass


# --- 攻击型主动技（伤害走伤害管线，§D9）。h20 倾力（h12 吞噬 / h13 孤注 已改 buff 型，见各自文件）---

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
