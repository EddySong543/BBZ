extends HeroSkill

## h02 丑牛【磐 · 卸劲】被动 · 防御 · 坦克(HP7 = 14 半点)
## 丑牛挨打时，把冲击卸给全队——每名【其他】存活队友获得 0.5HP 护盾（额外血量层）。
##
## 数值（半点制·1.0HP = 2 半点）：
##   护盾 1 层 = SHIELD_LAYER = 1 半点(0.5HP)（对齐卯兔护甲基准·复用现有 shield 原语）；
##   触发 = on_self_damaged（丑牛【实际挨打·落血】才卸·被挡不触发 → "诱饵盾"play）；
##   每名队友护盾封顶 SHIELD_CAP = 2 半点(1.0HP)（防滚雪球·反"无脑堆叠"）；不予自己（卸给队友）。
##   护盾规则照搬 §4.6：额外血量层·先扣盾后扣血·真伤无视·与"防挡不挡"正交。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   维度 = 防御（护甲层 = 已有原语·从"保血/容错"子维度出发·非凭空造新名词/新资源）。
##   为何宽 combo：全队凭空 + 有效血 → 鼠/虎/蛇/龙/鸡/猴(全 HP4) 敢顶上去布毒/破甲/蓄剑意/双扑、
##     扛得住反打 → 解放整条 combo 线敢打（防御维度的"宽" = 解放整队·非放大某一类伤害）；与卯兔护甲、护盾道具叠。
##   agency / yomi：对手两难——打丑牛 = 喂全队护盾(资敌)、不打 = 放着 HP7 肉墙挡路；
##     你主动把丑牛当"诱饵盾"顶前面、用它肉身给后排 carry 攒安全窗。
##   维度修正史（2026-06-22 Eddy）：原丑牛【卸力反震·反伤】机制【迁给暗牛 h14】；丑牛改本设计。
##   不撞：与未羊（致死救援·替补顶替挨打）机制不同（这是给护盾层·非顶替）；与亥猪（受击→能量）
##     同母题但输出不同维度（护盾 vs 能量）、角色不同（诱饵肉墙 vs 能量电池）。
##   旋钮：层值(1 半) / 上限(2 半) / 含不含替补(现含) / 触发(现 on_self_damaged 实际挨打)。

const SHIELD_LAYER := 1   # 每次卸给队友 1 半点 = 0.5HP 护盾（= 卯兔护甲基准）
const SHIELD_CAP := 2     # 卸劲给每名队友的护盾封顶 2 半点 = 1.0HP（防滚雪球）


func on_self_damaged(battle: BattleCore, player: int, slot: int, _dealt: int, _attacker_player: int) -> void:
	for s in range(battle.hp[player].size()):
		if s == slot or battle.hp[player][s] <= 0:
			continue
		if battle.shield[player][s] < SHIELD_CAP:
			battle.shield[player][s] = mini(battle.shield[player][s] + SHIELD_LAYER, SHIELD_CAP)
