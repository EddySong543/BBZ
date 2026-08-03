extends HeroSkill

## h20 触邪【罪已昭】被动 · 状态 · HP5（獬豸断罪·持续易伤放大）
## 触邪攻击命中敌方出战英雄 → 附「罪已昭印」(vuln·持续)：被印英雄受到的伤害 +0.5，直到换下场。
##
## 引擎：_apply_damage 落伤时 dmg += vuln（不消耗·只在没被挡住时生效）；_perform_switch 换下场清 vuln。
## 收束放大器：全队每一击对被印目标都 +0.5 → 配白额雷音抢先跨击杀线 / 龙破绽穿防 / 蛇毒引爆 / 马冲撞 / 队友 / 道具
##   = 系间乘算最宽的 payoff 面（每一点铺垫都被放大）。
##
## 设计依据：斩杀 / 处决线机制已禁英雄（2026-07-01 Eddy·见 memory hero-design-exclusions），
##   触邪由旧【罪者伏诛·处决】重设计为持续易伤放大。獬豸断罪 = 被判有罪者受罚更重。
##   维度=状态（持续 debuff 印记·跨回合），触发面 =「持续易伤印」——区别于蛇毒(储存引爆) /
##   鸡剑意(自身蓄势) / 缠绕(锁切换)；区别于道具猎物印记(一次性加伤) / 龙破绽(下一次基础攻击穿防)。
##   agency/yomi：你烙对手 carry → 全队集火；对手换人甩印(暂避) / 回血硬扛 / 抢杀羊。旋钮 = VULN(加伤量)。

const VULN := 1   # 被印敌人受伤 +0.5HP = 1 半点·易伤放大量（主旋钮·强了再降 / 弱了再抬）


func on_deal_hit(battle: BattleCore, player: int, _slot: int, target_player: int, target_slot: int, _dealt: int, _action: int) -> void:
	battle.set_status(target_player, target_slot, "vuln", VULN)
	battle.note_combo_proc(player)   # 罪已昭附着 = 一次 combo proc（喂鼠潮 h13·同龙破绽附着）
