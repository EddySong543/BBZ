extends ItemEffect

## 末日火种：你仅剩 1 名英雄存活时，其攻击与防御各 +1.0（独木撑天）。
## 攻 = 本回合攻击 +1.0；防 = +1.0 甲（额外血量层）。其余情况无效。
func apply_pre(battle: BattleCore, player: int, target: int, data: ItemData) -> void:
	var alive := 0
	for h in battle.hp[player]:
		if h > 0:
			alive += 1
	if alive == 1:
		battle.add_item_mod(player, "atk_bonus", int(data.params.get("atk", 2)))
		battle.shield[player][target] += int(data.params.get("armor", 2))
