extends ItemEffect

## 夜明珠〔遗物〕：你切换登场的英雄，本回合攻击 +0.5 且登场冲撞 0.5（非免费切换，故不撞马）。
## 永久遗物；登场加成 + 冲撞逻辑走 relic_on_switch_in（BattleCore._perform_switch 遍历本方遗物调·2026-07-02 A4 由 core 硬编码搬来）。
const ATK_BONUS := 1     # 登场当回合攻击 +0.5 HP（_imod·本回合修正）
const CHARGE_DMG := 1    # 登场冲撞给敌方出战 0.5 HP 真伤


func relic_on_switch_in(battle: BattleCore, player: int, _slot: int, _data: ItemData, _state: Dictionary, events: Array) -> void:
	battle.add_item_mod(player, "atk_bonus", ATK_BONUS)
	var opp: int = 1 - player
	var oa: int = battle.active_index[opp]
	if battle.hp[opp][oa] > 0:
		battle.hp[opp][oa] -= CHARGE_DMG
		events.append({id = "yemingzhu_charge", player = player})
