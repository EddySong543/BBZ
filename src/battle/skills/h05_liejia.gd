extends HeroSkill

## h05 辰龙【裂甲·破甲】被动 · 进攻
## 攻击命中敌方出战英雄时，给其附「破甲」：下次防御动作降一级（大防→防、防→无）。一次性。
## 引擎防御门读 "broken_armor" 状态、命中时消耗。

func on_deal_hit(battle: BattleCore, player: int, _slot: int, target_player: int, target_slot: int, _dealt: int, _action: int) -> void:
	battle.set_status(target_player, target_slot, "broken_armor", 1)
	battle._note_combo_proc(player)   # 鼠潮：破甲附着 = 一次 combo proc
