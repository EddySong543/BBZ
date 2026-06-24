extends ItemEffect

## 占卜龟壳：你下次 3 选 1 不满意，可整批重抽一次。
## 给自己挂 draft_reroll 令牌；下次 draft（抽卡界面）消费它允许整批重抽一次（界面联动·非战斗结算项）。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.item_buffs[player]["draft_reroll"] = int(battle.item_buffs[player].get("draft_reroll", 0)) + 1
