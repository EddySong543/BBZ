class_name BattleEval
extends RefCounted

## 战局启发式评估 —— AI 决策用。从 player 视角返回分数，越大越有利。
##
## v1 权重（2026-05-30 锁定）。单位 = 半点（1 HP = 2 半点）。
## 设计依据：杀一人 = 去一具身体 + 一套 kit，故 W_ALIVE 远超其残血价值；
##   能量按"2 能 ≈ 一记大波(4 半点伤)"折现 tempo；护甲约半个 HP 价值。
## 仅 1-ply 评估（看一回合后局面），后续按 batch 平衡数据调权重。

const W_WIN := 1000000.0     # 终局胜/负（绝对优先）
const W_ALIVE := 600.0       # 每多存活 1 英雄
const W_HP := 10.0           # 每半点 HP 差（1 HP = 2 半点 = 20 分）
const W_SHIELD := 6.0        # 每半点护甲差
const W_ACTIVE_HP := 4.0     # 出战位 HP 差额外加权（前线存活更重要）

## 能量边际递减：前 ENERGY_FULL_CAP 能（够一记大波）满价 W_ENERGY，
## 之后每点仅 W_ENERGY_EXTRA → 抑制 1-ply 短视下的"无意义屯能不出手"。
const W_ENERGY := 12.0       # 前 2 能每点价值
const W_ENERGY_MAX := 5.0    # 每半能的永久上限差；让搜索能识别 h23 的长期资源压制

## 状态资产项总开关/缩放（任务#7·2026-07-03）：铺垫型主动技/技能挂出的状态（沉默/毒/易伤/破甲/剑气…）
## 此前评估恒 0 分 → AI 视铺垫为纯亏能量、几乎不用铺垫型主动技（主动技率 0.7%·仅攻击型在用）。
## 本项给这些"未来会兑现的资产"记账。0.0 = 关闭（旧行为·A/B 对照 --ab status_off）。
const W_STATUS_SCALE := 1.0
const W_RETAINED_BIG_DEFEND := 18.0 # 不坠神言：下一回合有效的一次团队大防资产
const W_SCHEDULED_ENERGY_DEBT := 8.0 # 魔晶待偿还半能的折现负债（当前即时能量仍可创造节奏）
const W_SCHEDULED_ITEM_SEAL := 22.0  # 下回合第一件合法道具失效的一次公开干扰资产
const W_FATAL_IMMUNITY := 28.0        # 还魂丹基础保护：一次性保命，但不按等额生命硬折现
const W_FATAL_IMMUNITY_ACTIVE := 10.0 # 保护当前出战者更容易改变下一拍行动选择
const W_FATAL_IMMUNITY_LOW_HP := 16.0 # 低血保护更接近实际兑现
const W_FATAL_IMMUNITY_LAST_ALIVE := 18.0 # 最后一名存活英雄的保命价值更高
const FATAL_IMMUNITY_LOW_HP_LINE := 4 # 半点制：2 HP 及以下
const W_RELIC_BUDONG_CHARGE := 16.0   # 一次成功防御把整次攻击转为同量护甲，需对手配合
const W_RELIC_HEDING_LAYER := 16.0    # 下次毒爆每层额外1点伤害，按敌方当前毒层折现
const W_RELIC_JUDING_CHARGE := 12.0   # 一次额外附加效果机会，不把它误算成第二次攻击伤害
const W_RELIC_YEMING_CHARGE := 20.0   # 一次主动切换同时提供伤害与新英雄护甲，需支付切换机会
const W_RELIC_QING_TURN := 18.0       # 每剩余回合 1.5 能，按延迟资源折价
const W_RELIC_XUMING_HALF_HEAL := 10.0 # 只按当前出战实际缺血估值，避免满血时虚高
const W_RELIC_MORIHUO_DORMANT := 8.0
const W_RELIC_MORIHUO_LAST_ALIVE := 48.0
const W_RELIC_SHIXIN_ATTACK_READY := 24.0
const W_RELIC_SHIXIN_BACKLASH_HALF := 14.0 # 不能继续攻击时，3 点反噬接近 HP+前线价值
const W_FREE_BIG_ATTACK := 42.0       # 下一回合首个免费大波：明确但有期限的节奏资产
const W_RELIC_JUBAO := 42.0           # 每回合空槽补一件T1；强长期经济，但需要持续腾槽
const W_EXHAUSTED_TURN := 72.0        # 赊命券下一回合只能攒：完整行动机会负债
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
	var w_en_max: float = w.get("W_ENERGY_MAX", W_ENERGY_MAX)

	var s := 0.0
	s += w_alive * float(b.alive_count(player) - b.alive_count(opp))
	s += w_hp * float(_hp_sum(b, player) - _hp_sum(b, opp))
	s += _energy_value(b.energy[player], w_en, w_en_x) - _energy_value(b.energy[opp], w_en, w_en_x)
	s += w_en_max * float(b.energy_max[player] - b.energy_max[opp])
	s += w_shield * float(_shield_sum(b, player) - _shield_sum(b, opp))
	s += w_active * float(_active_hp(b, player) - _active_hp(b, opp))
	var w_status: float = w.get("W_STATUS_SCALE", W_STATUS_SCALE)
	if w_status != 0.0:
		s += w_status * (_status_assets(b, player) - _status_assets(b, opp))

	return s


## player 的"状态资产"（半点量纲·≈10 分/半点）：己方增益层 + 挂在敌方身上的待兑现状态。
## 权重按"预期兑现的半点当量"手拍：毒层命中即爆(8)>易伤持续(6)>破甲/印记一次性(5/4)；
## 剑气=己方攒的穿透资源(6/层)；沉默=对手 unique 停摆(10/回合·封顶 2)。
static func _status_assets(b: BattleCore, p: int) -> float:
	var t := 0.0
	if b.has_retained_big_defend(p):
		t += W_RETAINED_BIG_DEFEND
	# 这两项已经排入后续选择阶段，不能让 AI 把魔晶当无代价永久产能、把封印当纯白板。
	t -= W_SCHEDULED_ENERGY_DEBT * float(_scheduled_amount(
			b.item_buffs[p].get("energy_debt_turns", []), "amount"))
	t -= W_SCHEDULED_ITEM_SEAL * float(_scheduled_amount(
			b.item_buffs[p].get("sealed_item_turns", []), "charges"))
	t += _relic_assets(b, p)
	if int(b.item_buffs[p].get("free_big_attack_until_turn", -1)) == b.turn_number:
		t += W_FREE_BIG_ATTACK
	if int(b.item_buffs[p].get("exhausted_turn", -1)) >= b.turn_number:
		t -= W_EXHAUSTED_TURN
	for s in range(b.heroes[p].size()):
		if b.hp[p][s] > 0:
			t += 6.0 * float(b.get_status(p, s, "jianqi", 0))          # 剑气层（昴日线团队资源）
			# 还魂丹每名英雄整局限用一次，不存在同英雄多层保险。
			# 低血、在场、最后存活者更容易在下一轮真正兑现，因此只给有限情境加成。
			var immunity_charges: int = maxi(
				int(b.get_status(p, s, "fatal_damage_immunity", 0)), 0)
			if immunity_charges > 0:
				t += W_FATAL_IMMUNITY
				if s == b.active_index[p]:
					t += W_FATAL_IMMUNITY_ACTIVE
				if b.hp[p][s] <= FATAL_IMMUNITY_LOW_HP_LINE:
					t += W_FATAL_IMMUNITY_LOW_HP
				if b.alive_count(p) == 1:
					t += W_FATAL_IMMUNITY_LAST_ALIVE
	var e: int = 1 - p
	for s2 in range(b.heroes[e].size()):
		if b.hp[e][s2] <= 0:
			continue
		t += 8.0 * float(b.get_status(e, s2, "poison", 0))             # 毒层（命中引爆）
		t += 6.0 * float(b.get_status(e, s2, "vuln", 0))               # 脆弱（罪已昭限时；道具来源可持续）
		t += 8.0 * float(b.get_status(e, s2, "marked", 0))             # 猎物印记（本回合一次性易伤·命中兑现）
		t += 5.0 * float(b.get_status(e, s2, "broken_armor", 0))       # 破甲（下次防御失效）
		t += 10.0 * minf(float(b.get_status(e, s2, "silenced", 0)), 2.0)  # 沉默（unique 停摆/回合）
	return t


## 已激活 T3 遗物是公开局面资产。次数只取权威 state，不从玩家文案或目录 EV 反推。
static func _relic_assets(b: BattleCore, p: int) -> float:
	var total := 0.0
	for relic_variant in b.relics[p]:
		var relic: Dictionary = relic_variant
		var data: ItemData = relic.get("data", null)
		if data == null:
			continue
		var state: Dictionary = relic.get("state", {})
		var charges: int = maxi(int(state.get("charges", 0)), 0)
		var remaining_turns: int = maxi(int(state.get("remaining_turns", 0)), 0)
		match data.item_id:
			"t3_budongmingwang":
				total += W_RELIC_BUDONG_CHARGE * float(charges)
			"t3_hedinghong":
				var enemy: int = 1 - p
				var poison_layers: int = maxi(int(b.get_status(
					enemy, b.active_index[enemy], "poison", 0)), 0)
				total += W_RELIC_HEDING_LAYER * float(poison_layers * charges)
			"t3_judingsanhua":
				total += W_RELIC_JUDING_CHARGE * float(charges)
			"t3_jubao_pen":
				total += W_RELIC_JUBAO
			"t3_morihuozhong":
				total += W_RELIC_MORIHUO_LAST_ALIVE if b.alive_count(p) == 1 \
					else W_RELIC_MORIHUO_DORMANT
			"t3_qingyuanbaolian":
				total += W_RELIC_QING_TURN * float(remaining_turns)
			"t3_shixinding":
				if _can_continue_base_attack(b, p):
					total += W_RELIC_SHIXIN_ATTACK_READY
				else:
					total -= W_RELIC_SHIXIN_BACKLASH_HALF * 6.0
			"t3_xumingxiang":
				var active: int = b.active_index[p]
				var missing_hp: int = maxi(b.max_hp[p][active] - b.hp[p][active], 0)
				var expected_heal: int = mini(missing_hp, remaining_turns * 3)
				total += W_RELIC_XUMING_HALF_HEAL * float(expected_heal)
			"t3_yemingzhu":
				if not b.living_reserves(p).is_empty():
					total += W_RELIC_YEMING_CHARGE * float(charges)
	return total


static func _can_continue_base_attack(b: BattleCore, p: int) -> bool:
	for action: int in [ActionDef.Action.ATTACK, ActionDef.Action.BIG_ATTACK]:
		if b.can_afford(p, action) or b.can_pay_action_with_blood(p, action) \
				or b.can_use_energy_cap_discount(p, action):
			return true
	return false


static func _scheduled_amount(entries: Variant, key: String) -> int:
	if not entries is Array:
		return 0
	var total := 0
	for entry_variant in entries:
		if entry_variant is Dictionary:
			total += maxi(int((entry_variant as Dictionary).get(key, 0)), 0)
	return total


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
