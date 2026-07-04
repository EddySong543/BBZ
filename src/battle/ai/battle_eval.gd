class_name BattleEval
extends RefCounted

## 战局启发式评估 —— AI 决策用。从 player 视角返回分数，越大越有利。
##
## v1 权重（2026-05-30 锁定）。单位 = 半点（1 HP = 2 半点）。
## 设计依据：杀一人 = 去一具身体 + 一套 kit，故 W_ALIVE 远超其残血价值；
##   能量按"2 能 ≈ 一记大波(4 半点伤)"折现 tempo；护盾约半个 HP 价值。
## 仅 1-ply 评估（看一回合后局面），后续按 batch 平衡数据调权重。

const W_WIN := 1000000.0     # 终局胜/负（绝对优先）
const W_ALIVE := 600.0       # 每多存活 1 英雄
const W_HP := 10.0           # 每半点 HP 差（1 HP = 2 半点 = 20 分）
const W_SHIELD := 6.0        # 每半点护盾差
const W_ACTIVE_HP := 4.0     # 出战位 HP 差额外加权（前线存活更重要）

## 能量边际递减：前 ENERGY_FULL_CAP 能（够一记大波）满价 W_ENERGY，
## 之后每点仅 W_ENERGY_EXTRA → 抑制 1-ply 短视下的"无意义屯能不出手"。
const W_ENERGY := 12.0       # 前 2 能每点价值

## 状态资产项总开关/缩放（任务#7·2026-07-03）：铺垫型主动技/技能挂出的状态（沉默/毒/易伤/破甲/剑气…）
## 此前评估恒 0 分 → AI 视铺垫为纯亏能量、几乎不用铺垫型主动技（主动技率 0.7%·仅攻击型在用）。
## 本项给这些"未来会兑现的资产"记账。0.0 = 关闭（旧行为·A/B 对照 --ab status_off）。
const W_STATUS_SCALE := 1.0
## 2026-07-03 校准（#3·被动能量恢复 + 道具经济免费化后旧值 3.0 过时——压死囤能 → 大波近绝迹、防 37% 龟态）：
## 3.0→6.5。A/B 实测（60 局小轮·交替先后手）：6.5/8.0 对旧值 3.0 均 ~63% 碾压；6.5 vs 8.0 五五开，
## 取生态更贴目标带的 6.5（攒 18.2%/波 31.7%/均 53 回合·数据=tools/sim/out_w_extra65_eco）。
const W_ENERGY_EXTRA := 6.5  # 超过 2 能后每点价值（边际递减·2026-07-03 校准 3.0→6.5）
const ENERGY_FULL_CAP := 2   # 满价能量上限（= 大波费用）


## w（可选）= 权重覆盖字典（键同上方常量名）→ 校准用；缺省走常量默认（T1）。
static func score(b: BattleCore, player: int, w: Dictionary = {}) -> float:
	var opp: int = 1 - player

	# 终局：压倒一切（W_WIN 不参与校准，恒定）
	if b.game_over:
		if b.winner == player + 1:
			return W_WIN
		if b.winner == opp + 1:
			return -W_WIN
		return 0.0  # 平局

	var w_alive: float = w.get("W_ALIVE", W_ALIVE)
	var w_hp: float = w.get("W_HP", W_HP)
	var w_shield: float = w.get("W_SHIELD", W_SHIELD)
	var w_active: float = w.get("W_ACTIVE_HP", W_ACTIVE_HP)
	var w_en: float = w.get("W_ENERGY", W_ENERGY)
	var w_en_x: float = w.get("W_ENERGY_EXTRA", W_ENERGY_EXTRA)

	var s := 0.0
	s += w_alive * float(b.alive_count(player) - b.alive_count(opp))
	s += w_hp * float(_hp_sum(b, player) - _hp_sum(b, opp))
	s += _energy_value(b.energy[player], w_en, w_en_x) - _energy_value(b.energy[opp], w_en, w_en_x)
	s += w_shield * float(_shield_sum(b, player) - _shield_sum(b, opp))
	s += w_active * float(_active_hp(b, player) - _active_hp(b, opp))
	var w_status: float = w.get("W_STATUS_SCALE", W_STATUS_SCALE)
	if w_status != 0.0:
		s += w_status * (_status_assets(b, player) - _status_assets(b, opp))

	return s


## player 的"状态资产"（半点量纲·≈10 分/半点）：己方增益层 + 挂在敌方身上的债/破绽。
## 权重按"预期兑现的半点当量"手拍：毒层命中即爆(8)>易伤持续(6)>破甲/印记一次性(5/4)；
## 剑气=己方攒的穿透资源(6/层)；沉默=对手 unique 停摆(10/回合·封顶 2)。
static func _status_assets(b: BattleCore, p: int) -> float:
	var t := 0.0
	for s in range(b.heroes[p].size()):
		if b.hp[p][s] > 0:
			t += 6.0 * float(b.get_status(p, s, "jianqi", 0))          # 剑气层（昴日线团队资源）
	var e: int = 1 - p
	for s2 in range(b.heroes[e].size()):
		if b.hp[e][s2] <= 0:
			continue
		t += 8.0 * float(b.get_status(e, s2, "poison", 0))             # 毒层（命中引爆）
		t += 6.0 * float(b.get_status(e, s2, "vuln", 0))               # 罪已昭易伤（持续·换下场才清）
		t += 4.0 * float(b.get_status(e, s2, "marked", 0))             # 猎物印记（一次性易伤）
		t += 5.0 * float(b.get_status(e, s2, "broken_armor", 0))       # 破甲（下次防御失效）
		t += 10.0 * minf(float(b.get_status(e, s2, "silenced", 0)), 2.0)  # 沉默（unique 停摆/回合）
	# 护主可用（天狗 h23·2026-07-04 Eddy 批③②）：替补席存活 + 御凶未用 = 一次"免死保险"资产（40 分）。
	#   只在【替补席】计分 → 搜索自然学会把天狗留板凳待命（此前 DraftAI 按 HP6 当坦克顶前排=被动作废·26.8% 病因之一）。
	for s3 in range(b.heroes[p].size()):
		if s3 != b.active_index[p] and b.hp[p][s3] > 0:
			var gsk: HeroSkill = b.get_skill(p, s3)
			if gsk != null and gsk.is_lethal_guardian() and int(b.get_status(p, s3, "huzhu_uses", 0)) < BattleCore.HUZHU_CAP:
				t += 40.0
	return t


## 能量的边际递减价值：前 2 能满价，之后廉价（权重可由 w 覆盖）。
static func _energy_value(e: int, w_energy: float, w_extra: float) -> float:
	var full: int = mini(e, ENERGY_FULL_CAP)
	var extra: int = maxi(e - ENERGY_FULL_CAP, 0)
	return w_energy * float(full) + w_extra * float(extra)


static func _hp_sum(b: BattleCore, p: int) -> int:
	var t := 0
	for v in b.hp[p]:
		t += maxi(int(v), 0)   # 溢杀负血不放大对方亏空
	return t


static func _shield_sum(b: BattleCore, p: int) -> int:
	var t := 0
	for v in b.shield[p]:
		t += int(v)
	return t


static func _active_hp(b: BattleCore, p: int) -> int:
	return maxi(b.hp[p][b.active_index[p]], 0)
