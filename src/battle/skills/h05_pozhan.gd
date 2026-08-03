extends HeroSkill

## h05 亢金【龙御极】被动 · 进攻 · HP5
## 基础「波 / 大波」被目标成功防御时，给该英雄留下「破绽」。
##
## 破绽是逐英雄、持续、不叠加的团队进攻窗口：换下场不清除；目标下一次受到
## 任意队友的基础攻击时，该攻击至少升为穿防并消费破绽。「防」挡不住，「大防」仍能挡住。
## 道具伤害、攻击型主动技、反击、冲撞和持续伤害既不触发，也不消费。
##
## 幻想因果：「御极」取登临极位之意。亢金生来居于龙相之顶，其势即使被完整挡下，
## 仍会在对方守势中留下可供全队利用的一线后手。

func on_base_attack_blocked(battle: BattleCore, player: int, _slot: int,
		target_player: int, target_slot: int, _attack_action: int,
		_defense_action: int, _raw: int, events: Array) -> void:
	battle.set_status(target_player, target_slot, "opening", 1)
	events.append({id = "opening_applied", player = target_player, slot = target_slot})
	battle.note_combo_proc(player)   # 鼠潮：破绽附着 = 一次 combo proc
