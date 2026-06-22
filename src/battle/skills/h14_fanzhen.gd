extends HeroSkill

## h14 黑暗丑牛【卸力反震】被动 · 防御 · HP6
## 防/大防成功挡下时，向攻击者反弹被挡伤害的 50%（挡波反 0.5、挡大波反 1.0）。
## 反弹 = 纯结算真伤、不触发 on-hit（不喂毒/剑气）；引擎 on_block 在防御门挡下时调用。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   机制【迁自原丑牛·磐牛卸力反震】（2026-06-22 Eddy 拍板）——维度修正：暗牛继承丑牛的【防御】维度，
##     旧【劈穿·溢杀】(进攻·维度漂移·偏自给) 已弃用（连同 carry_overkill_to_next 一并移除）。
##   dark 味 = 撞这头牛鬼者业报反噬（以牙还牙）。
##   共享原语 = 反伤（攻击者所受反弹可喂虎处决 / on-hit 收割端）；攻防双向 yomi
##     （攻牛 = 自伤、大波砸牛反弹更疼 → 逼对手不攻/换人/绕道，把"防"变陷阱）。
##   维度 = 防御（与丑牛 h02 卸劲、未羊 h08 致死救援 同维不同机制）。

func on_block(battle: BattleCore, player: int, _slot: int, attacker_player: int, _attack_action: int, raw: int) -> void:
	var reflect: int = roundi(raw * 0.5)   # 半点：挡波 raw=2→反1(0.5HP)、挡大波 raw=4→反2(1.0HP)
	if reflect <= 0:
		return
	var aslot: int = battle.active_index[attacker_player]
	battle.hp[attacker_player][aslot] -= reflect
	battle._note_combo_proc(player)   # 鼠潮：卸力反震 = 一次 combo proc（归防御方）
