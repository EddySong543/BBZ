extends HeroSkill

## h06 翼火【灵蚀噬魂】被动 · 状态
## 攻击命中敌方出战时，叠 1 层「毒」（可叠、平时不 tick）。
## 中毒目标每次被攻击命中时引爆全部毒层（每层 +0.5、随后清空）——引爆在引擎 _apply_damage(B3a)。
## 叠毒那一击本身不引爆（引擎先结算引爆、再由本 hook 叠新毒）。

func on_deal_hit(battle: BattleCore, _player: int, _slot: int, target_player: int, target_slot: int, _dealt: int, _action: int) -> void:
	var p: int = int(battle.get_status(target_player, target_slot, "poison", 0))
	battle.set_status(target_player, target_slot, "poison", p + 1)
