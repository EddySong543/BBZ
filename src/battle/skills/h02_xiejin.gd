extends HeroSkill

## h02 牛金【山岳为屏】被动 · 防御 · 坦克(HP7 = 14 半点·批④ 7→6 已于 2026-07-09 批⑤回滚：
##   大轮 60.7→35.3% 刀过头实锤——引擎全靠挨打次数驱动·HP 刀=身板+触发总量双重收敛砸太狠·轻刀另议)
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
##   旋钮：层值(1 半) / 发放面(批⑥起=随机一名·⛔最低血定向=智能瞄准已证不轻·可回"每名") / 触发(现 on_self_damaged 实际挨打)。

const SHIELD_LAYER := 1   # 每次卸给队友 1 半点 = 0.5HP 护盾


## 批⑥刀（2026-07-09·Eddy 批·同日二刀）：发放面「血量最低」→「随机一名」。
## 刀理：批⑤大轮 57.9%（n=107）实锤"最低血定向"是智能瞄准——盾全落在最需要的人身上，
## 效率补偿掉了总量减半（教训：给产出端减半时若附带智能定向=白砍）。随机=斩断定向、真减半。
## 随机源=battle.rng（§D7 可 seed·sim/录像/测试可复现）·零分配。
## 批⑤轻刀溯源：HP 刀双重收敛砸过头（60.7→35.3）→ 改砍产出端（全队总盾 1.0→0.5HP/打）·身板/触发口径不动。
func on_self_damaged(battle: BattleCore, player: int, slot: int, _dealt: int, _attacker_player: int) -> void:
	var count := 0
	for s in range(battle.hp[player].size()):
		if s != slot and battle.hp[player][s] > 0:
			count += 1
	if count == 0:
		return
	var pick: int = battle.rng.randi_range(0, count - 1)
	for s in range(battle.hp[player].size()):
		if s == slot or battle.hp[player][s] <= 0:
			continue
		if pick == 0:
			battle.shield[player][s] += SHIELD_LAYER
			return
		pick -= 1
