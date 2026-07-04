extends ItemEffect

## 周天罡气（🔄 2026-07-04 重做·Eddy 定）：我方本回合无敌——不受到任何【敌源】伤害。
## 旧版【气·2 个纸扎替身·2/3 概率落空】废除（T3 投资配高方差=情绪账算不平·Eddy 裁定不合适）。
## 免疫面（全库 8 个扣血点逐一 gate·见 battle_core.damage_immune 注释）：
##   动作攻击（含穿防/穿大防/真伤·整发"落空"含其 on-hit）/ 道具直伤（飞镖等走 _apply_damage）/
##   延迟灼烧（pending·当回合清零不顺延）/ 溅射（乌骓踏替补）/ 穷追（娄金）/ 反震（蚩尤）/
##   冲撞（夜明珠·星日冲撞走管线）/ 死亡反击（尾后针）。
## ⛔ 不拦：自付代价（凶药自损 = 主动支付、非"受到伤害"）。
## 博弈：一次性·T3 双升级投资·格子里躺着 = 明牌电报 → 对手可先甩小波骗罡气、或攒过这回合。
## flavor：无敌是多么寂寞。
func apply_pre(battle: BattleCore, player: int, _target: int, _data: ItemData) -> void:
	battle.set_item_mod(player, "damage_immune", 1)
