extends HeroSkill

## h06 翼火【神打】被动 · 状态
## 翼火命中敌方英雄时，使其获得 1 层「毒素」（可叠加、平时不 tick）。
## 中毒英雄被「大波」命中时，引爆并清除全部毒素（每层 +0.5）。
## 叠毒素的那一击本身不引爆（引擎先结算已有毒素，再由本 hook 叠加新毒素）。

func on_deal_hit(battle: BattleCore, _player: int, _slot: int, target_player: int, target_slot: int, _dealt: int, _action: int) -> void:
	var p: int = int(battle.get_status(target_player, target_slot, "poison", 0))
	battle.set_status(target_player, target_slot, "poison", p + 1)
