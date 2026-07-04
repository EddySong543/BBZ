extends HeroSkill

## h02 牛金【山岳为屏】被动 · 防御 · 坦克(HP7 = 14 半点)
## 牛金挨打时，把冲击卸给全队——每名【其他】存活队友获得 0.5HP 护盾（额外血量层）。
##
## 数值（半点制·1.0HP = 2 半点）：
##   护盾 1 层 = SHIELD_LAYER = 1 半点(0.5HP)（复用现有 shield 原语；原对齐的"房日护甲基准"已随 2026-07-04 h04 重做移除）；
##   触发 = on_self_damaged（牛金【实际挨打·落血】才卸·被挡不触发 → "诱饵盾"play）；
##   护盾无上限累积（2026-07-01 Eddy 废除封顶 SHIELD_CAP=1.0HP·受牛金落血次数天然限流）；不予自己（卸给队友）。
##   护盾规则照搬 §4.6：额外血量层·先扣盾后扣血·真伤无视·与"防挡不挡"正交。
##
## 设计依据（heroes-redesign / build-design-framework）：
##   维度 = 防御（护甲层 = 已有原语·从"保血/容错"子维度出发·非凭空造新名词/新资源）。
##   为何宽 combo：全队凭空 + 有效血 → 鼠/虎/蛇/龙/鸡/猴(全 HP4) 敢顶上去布毒/破甲/蓄剑意/双扑、
##     扛得住反打 → 解放整条 combo 线敢打（防御维度的"宽" = 解放整队·非放大某一类伤害）；与护盾道具叠。
##   agency / yomi：对手两难——打牛金 = 喂全队护盾(资敌)、不打 = 放着 HP7 肉墙挡路；
##     你主动把牛金当"诱饵盾"顶前面、用它肉身给后排 carry 攒安全窗。
##   维度修正史（2026-06-22 Eddy）：原牛金【卸力反震·反伤】机制【迁给暗牛 h14】；牛金改本设计。
##   不撞：与娄金（护主·替死碎掉）机制不同（这是给护盾层·非替死）；与室火（受击→能量）
##     同母题但输出不同维度（护盾 vs 能量）、角色不同（诱饵肉墙 vs 能量电池）。
##   旋钮：层值(1 半) / 含不含替补(现含) / 触发(现 on_self_damaged 实际挨打)。

const SHIELD_LAYER := 1   # 每次卸给队友 1 半点 = 0.5HP 护盾


func on_self_damaged(battle: BattleCore, player: int, slot: int, _dealt: int, _attacker_player: int) -> void:
	for s in range(battle.hp[player].size()):
		if s == slot or battle.hp[player][s] <= 0:
			continue
		battle.shield[player][s] += SHIELD_LAYER
