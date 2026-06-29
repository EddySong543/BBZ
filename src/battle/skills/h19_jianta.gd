extends HeroSkill

## h19 乌骓【奔雷】被动 · 进攻 · HP5（骑兵冲锋·首个"打到后排"）
## 乌骓攻击命中敌方出战时，这一击【超过 1.0 HP 的溢出部分】碾穿到一名敌方替补（最高血那个）——
##   力大才碾穿：普通波(1.0)停在出战、更猛的一击把"多出来的力"踏到后排。
##   溢出 = dealt − 1.0HP(2 半点)，封顶 TRAMPLE_CAP；波(1.0)→0 不踏 / 大波(2.0)→踏 1.0 / 被加伤的波(1.5)→踏 0.5。
##   替补伤走 shield 先吸 + 触发 on_self_damaged；被挡(dealt=0)不触发。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   维度 = 进攻（暗批 round 2 进攻位；roster 首个"打到后排"机制·与暗虎穿防/虎多段/龙破甲全异）。
##   为何宽 combo：把对局从 1v1 磨血变成【压制对手整队】——
##     ① 破对手头号防御=换人重置（替补也被踏血·换上来的也是残的→可 race 整队）；
##     ② 配暗蛇缠绕 ⭐（锁住切换·残血替补换不出又一直挨踏→对手整队枯萎）；③ 配集火/收割清场。
##   "把伤害顶过 1.0"= 明确 combo 目标（奖励一切加伤/破甲窗/buff·框架"条件超标·自成核"）。
##   agency / yomi：你持续踏后排、逼对手"换残血上来 vs 不换被困"；对手要护替补 / 抢杀马。
##   §4.4：溢出封顶 1.0 + 需命中(被挡不触发) + 只一名替补 自限。马味=骑兵冲锋践踏一片。HP5 中坚。

const TRAMPLE_CAP := 2   # 踏后排封顶 = 2 半点(1.0HP)·主旋钮（嫌强可降到 1=0.5）


func on_deal_hit(battle: BattleCore, _player: int, _slot: int, target_player: int, _target_slot: int, dealt: int, _action: int) -> void:
	var overflow: int = dealt - ActionDef.HP_UNIT   # 超过 1.0HP(2 半点) 的部分
	if overflow <= 0:
		return
	battle._splash_to_reserve(target_player, mini(overflow, TRAMPLE_CAP))
