extends HeroSkill

## h20 触邪【罪已昭】被动 · 状态 · HP5（獬豸断罪·持续脆弱放大）
## 触邪攻击命中敌方出战英雄 → 使其获得脆弱（vuln·持续）：受到的伤害 +0.5，直到下场。
##
## 引擎：_apply_damage 落伤时 dmg += vuln（不消耗·只在没被挡住时生效）；_perform_switch 换下场清 vuln。
## 收束放大器：全队每一击对被印目标都 +0.5 → 配白额雷音抢先跨击杀线 / 龙御极强化波 / 蛇毒引爆 / 马冲撞 / 队友 / 道具
##   = 系间乘算最宽的 payoff 面（每一点铺垫都被放大）。
##
## 设计依据：斩杀 / 处决线机制已禁英雄（2026-07-01 Eddy·见 memory hero-design-exclusions），
##   触邪由旧【罪者伏诛·处决】重设计为持续脆弱放大。獬豸断罪 = 被判有罪者受罚更重。
##   维度=状态（持续 debuff·跨回合），触发面 =「持续脆弱」——区别于蛇毒(储存引爆) /
##   鸡剑意(自身蓄势)；区别于道具猎物印记(一次性加伤) / 龙御极(为波主动追加能量和伤害)。
##   agency/yomi：你烙对手 carry → 全队集火；对手换人甩印(暂避) / 回血硬扛 / 抢杀羊。旋钮 = VULN(加伤量)。

const VULN := 1   # 脆弱目标受伤 +0.5HP = 1 半点·伤害放大量（主旋钮·强了再降 / 弱了再抬）


func on_deal_hit(battle: BattleCore, player: int, _slot: int, target_player: int, target_slot: int, _dealt: int, _action: int) -> void:
	# 断罪只保证至少 1 层脆弱，不应覆盖猎物印记施加的更多层数。
	var current_vuln := int(battle.get_status(target_player, target_slot, "vuln", 0))
	battle.set_status(target_player, target_slot, "vuln", maxi(current_vuln, VULN))
