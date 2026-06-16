extends HeroSkill

## h02 丑牛【磐牛·卸力反震】被动 · 防御 · 坦克(HP7)
## 防/大防成功挡下时，向攻击者反弹被挡伤害的 50%（挡波反 0.5、挡大波反 1.0）。
## 反弹 = 纯结算真伤、不触发 on-hit（不喂毒/剑气）；引擎 on_block 在防御门挡下时调用。

func on_block(battle: BattleCore, _player: int, _slot: int, attacker_player: int, _attack_action: int, raw: int) -> void:
	var reflect: int = roundi(raw * 0.5)   # 半点：挡波 raw=2→反1(0.5HP)、挡大波 raw=4→反2(1.0HP)
	if reflect <= 0:
		return
	var aslot: int = battle.active_index[attacker_player]
	battle.hp[attacker_player][aslot] -= reflect
